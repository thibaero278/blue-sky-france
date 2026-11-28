-- Moteur des scénarios hors jeu (site/tools/scenarios/*.lua) : rejoue une chronologie sur le vrai script dans le faux DCS.
-- Un scénario (fichier Lua) renvoie :
--   { description = "...", steps = { ... },
--     mission = function(M) M.remove("s-croix-5") end,  -- optionnel : mission modifiée (mocks/mission_defaut.lua)
--     scores = { Dex = { points = 10 } },                -- optionnel : Scores.lua de départ
--     load_error = "texte",                              -- optionnel : le chargement du script doit planter ainsi
--     errors = { "motif" }, warnings = { "motif" } }     -- erreurs / avertissements dcs.log attendus (sinon : échec)
-- Chaque étape : t = secondes depuis le lancement de la mission, une action et/ou check = { ... }.
-- Actions : spawn, crew, takeoff, move, kill, destroy, capture, land, leave, die, menu, join, refuel, mission_end, lua.
-- Vérifications : menu, points, pending, flying, grounded, stats, message, sound, scores_file, ops, log, ok.
-- Paramètres : en commentaire au-dessus de chaque fonction ci-dessous. Exemples : site/tools/scenarios/*.lua.
Sc = {}
local F = Fake

local function fail(msg) Sc.failures[#Sc.failures + 1] = string.format("t=%gs : %s", F.now, msg) end

local function unitOf(player)
    return F.unitOf(player) or error("joueur " .. tostring(player) .. " dans aucun avion", 0)
end

local function target(name)
    return F.units[name] or F.statics[name] or F.airbases[name] or error("cible inconnue : " .. tostring(name), 0)
end

local function nearestAirbase(u)
    local best, bd
    for _, a in ipairs(F.airbaseList) do
        local d = F.dist(a, u)
        if not bd or d < bd then best, bd = a, d end
    end
    return best
end

------------------------------------------------------------
-- ACTIONS
------------------------------------------------------------
local A = {}

-- { player, slot = groupe joueur de la mission, air = true (départ en vol), alt, speed }
function A.spawn(a)
    local g = F.groups[a.slot] or error("slot inconnu : " .. tostring(a.slot), 0)
    local u = g.units[1]
    if u.exists then error("slot déjà occupé : " .. a.slot, 0) end
    u.exists, u.active, u.player, u.seats, u.life = true, true, a.player, { a.player }, u.life0
    u.x, u.z, u.air, u.y, u.speed = g.def.x, g.def.z, a.air or false, a.alt or 0, a.speed or 0
    F.event("Birth", { initiator = u })
end

-- { pilot, seats = { pilote, place 2... } (vu par le bot), dcs_pilot = nom que DCS donne comme pilote (fantôme) }
function A.crew(a)
    local u = unitOf(a.pilot)
    u.seats = a.seats
    if a.dcs_pilot then u.player = a.dcs_pilot end
end

-- { player, alt, speed, event = false (DCS n'envoie pas le décollage) }
function A.takeoff(a)
    local u = unitOf(a.player)
    u.air, u.y, u.speed = true, a.alt or 500, a.speed or 100
    if a.event ~= false then F.event("Takeoff", { initiator = u, place = nearestAirbase(u) }) end
end

-- { player, x, z, alt, speed }
function A.move(a)
    local u = unitOf(a.player)
    u.x, u.z, u.y, u.speed = a.x or u.x, a.z or u.z, a.alt or u.y, a.speed or u.speed
end

-- { by, target, distance = m (le tireur est placé à cette distance), weapon, locked = false (bombe), gun = true (canon) }
-- Comme DCS : tir, coup au but, kill, puis mort de la cible
function A.kill(a)
    local u, t = unitOf(a.by), target(a.target)
    if a.distance then u.x, u.z = t.x - a.distance, t.z end
    local w
    if not a.gun then
        w = F.weapon(a.weapon or "AGM_114K", a.locked ~= false and t or nil, u)
        F.event("Shot", { initiator = u, weapon = w })
    end
    F.event("Hit", { initiator = u, weapon = w, target = t })
    if w then w.exists = false end
    t.life = 0
    F.event("Kill", { initiator = u, weapon = w, target = t })
    F.event("Dead", { initiator = t })
    if t.objcat ~= Object.Category.BASE then t.exists = false end
end

-- { targets = { noms } } : détruits sans tireur connu (événement Dead seul, comme les derricks)
-- shortcut: un aérodrome / héliport détruit reste un objet DCS (isExist vrai), à revoir si le jeu montre l'inverse
function A.destroy(a)
    for _, name in ipairs(a.targets) do
        local o = target(name)
        o.life = 0
        F.event("Dead", { initiator = o })
        if o.objcat ~= Object.Category.BASE then o.exists = false end
    end
end

-- { base = aérodrome, by, distance, radius = 8000 } : zone capturée = toutes les unités au sol rouges actives
-- autour de la base abattues par le joueur
function A.capture(a)
    local ab = F.airbases[a.base] or error("base inconnue : " .. tostring(a.base), 0)
    for _, u in ipairs(F.unitList) do
        if u.exists and u.active and u.coal == 1 and u.cat == Unit.Category.GROUND_UNIT and F.dist(u, ab) <= (a.radius or 8000) then
            A.kill({ by = a.by, target = u.name, distance = a.distance or 3000, weapon = a.weapon })
        end
    end
end

-- { player, at = aérodrome ou { x, z }, dx, dz, place = false (DCS ne donne pas la base), speed }
function A.land(a)
    local u = unitOf(a.player)
    local ab = type(a.at) == "string" and (F.airbases[a.at] or error("base inconnue : " .. a.at, 0)) or nil
    local p = ab or a.at
    u.x, u.z, u.air, u.y, u.speed = p.x + (a.dx or 0), p.z + (a.dz or 0), false, 0, a.speed or 0
    F.event("Land", { initiator = u, place = (ab and a.place ~= false) and ab or nil })
end

-- { player } : moteur coupé (série, 20/11)
function A.shutdown(a) F.event("EngineShutdown", { initiator = unitOf(a.player) }) end

-- { player } : il quitte son avion (changement de slot, déco) ; l'avion disparaît, DCS envoie aussi Dead
function A.leave(a)
    local u = unitOf(a.player)
    F.event("PlayerLeaveUnit", { initiator = u })
    u.player, u.seats = nil, nil
    F.event("Dead", { initiator = u })
    u.exists, u.air = false, false
end

-- { player, how = "Crash" ou "Ejection" }
function A.die(a)
    local u = unitOf(a.player)
    F.event(a.how or "Crash", { initiator = u })
    F.event("PilotDead", { initiator = u })
    F.event("Dead", { initiator = u })
    u.player, u.seats, u.exists, u.air = nil, nil, false, false
end

-- { player, path = "MISSIONS > STRIKE > Petrol Strike" } : clic dans F10
function A.menu(a)
    if not F.click(a.player, a.path) then fail("menu F10 absent pour " .. a.player .. " : " .. a.path) end
end

-- { player, op = "Petrol Strike" } : compose le code de la mission dans F10 > CODE
function A.join(a)
    local op = F.env.Ops[a.op]
    if not op then fail("mission " .. a.op .. " pas en cours, rien à rejoindre") return end
    A.menu({ player = a.player, path = "CODE > " .. op.code:sub(1, 1) .. "_ > " .. op.code })
end

-- { player, stop = true }
function A.refuel(a) F.event(a.stop and "RefuelingStop" or "Refueling", { initiator = unitOf(a.player) }) end

function A.mission_end() F.event("MissionEnd", {}) end

-- lua = function(Fake, env) ... end (env = globales du script)
function A.lua(fn) fn(F, F.env) end

------------------------------------------------------------
-- VÉRIFICATIONS
------------------------------------------------------------
local C = {}

local function list(v) return (type(v) == "table" and v[1] == nil and next(v) ~= nil) and { v } or v end

-- { player, has = { chemins }, lacks = { chemins }, once = { chemins présents une seule fois } }
function C.menu(c)
    local set = {}
    for _, p in ipairs((F.menuOf(c.player))) do set[p] = (set[p] or 0) + 1 end
    for _, p in ipairs(c.has or {}) do if not set[p] then fail(c.player .. " : menu F10 absent : " .. p) end end
    for _, p in ipairs(c.lacks or {}) do if set[p] then fail(c.player .. " : menu F10 en trop : " .. p) end end
    for _, p in ipairs(c.once or {}) do
        if set[p] ~= 1 then fail(c.player .. " : menu F10 « " .. p .. " » présent " .. (set[p] or 0) .. " fois au lieu de 1") end
    end
end

-- { pilote = points validés }
function C.points(c)
    for name, v in pairs(c) do
        local s = (F.env.Scores or {})[name]
        if (s and s.points) ~= v then fail("points validés de " .. name .. " : " .. tostring(s and s.points) .. " au lieu de " .. v) end
    end
end

-- { pilote = points du vol en cours (en attente de l'atterrissage) }
function C.pending(c)
    for name, v in pairs(c) do
        local f = F.env.Flights[name]
        local got = f and f.active and f.points
        if got ~= v then fail("points en vol de " .. name .. " : " .. tostring(got) .. " au lieu de " .. v) end
    end
end

-- { pilote, ... } : vol en cours / { pilote, ... } : aucun vol en cours
function C.flying(c)
    for _, name in ipairs(c) do
        local f = F.env.Flights[name]
        if not (f and f.active) then fail(name .. " devrait avoir un vol en cours") end
    end
end
function C.grounded(c)
    for _, name in ipairs(c) do
        local f = F.env.Flights[name]
        if f and f.active then fail(name .. " ne devrait pas avoir de vol en cours") end
    end
end

-- { pilote = { champ = valeur } } dans Scores (en mémoire)
function C.stats(c)
    for name, fields in pairs(c) do
        local s = (F.env.Scores or {})[name] or {}
        for k, v in pairs(fields) do
            if s[k] ~= v then fail("stat " .. k .. " de " .. name .. " : " .. tostring(s[k]) .. " au lieu de " .. tostring(v)) end
        end
    end
end

-- Messages reçus depuis la vérification précédente (all = true : depuis le début)
-- { player, has = "texte" } ou { player, lacks = "texte" }, ou une liste de ces tables
local function received(m, player)
    for _, n in ipairs(m.to) do if n == player then return true end end
    return false
end
function C.message(c)
    for _, e in ipairs(list(c)) do
        local hit
        for i = e.all and 1 or Sc.msgMark + 1, #F.msgs do
            local m = F.msgs[i]
            if received(m, e.player) and m.text:find(e.has or e.lacks, 1, true) then hit = m end
        end
        if e.has and not hit then fail(e.player .. " n'a pas reçu de message contenant « " .. e.has .. " »") end
        if e.lacks and hit then fail(e.player .. " a reçu un message contenant « " .. e.lacks .. " » : " .. hit.text) end
    end
end

-- { player, file } (ou une liste) : son entendu depuis la vérification précédente
function C.sound(c)
    for _, e in ipairs(list(c)) do
        local hit = false
        for i = Sc.soundMark + 1, #F.sounds do
            if received(F.sounds[i], e.player) and F.sounds[i].file == e.file then hit = true end
        end
        if not hit then fail(e.player .. " n'a pas entendu " .. e.file) end
    end
end

-- { pilote = { champ = valeur } } dans le fichier Scores.lua écrit par le script (absent = { "pilote" })
function C.scores_file(c)
    local ok, t = pcall(dofile, F.writedir .. "Scores.lua")
    if not ok or type(t) ~= "table" then fail("Scores.lua illisible : " .. tostring(t)) return end
    for name, fields in pairs(c) do
        if name == "absent" then
            for _, n in ipairs(fields) do if t[n] then fail("Scores.lua contient " .. n) end end
        else
            local s = t[name]
            if not s then fail("Scores.lua sans " .. name) else
                for k, v in pairs(fields) do
                    if s[k] ~= v then fail("Scores.lua, " .. name .. "." .. k .. " = " .. tostring(s[k]) .. " au lieu de " .. tostring(v)) end
                end
            end
        end
    end
end

-- { ["Petrol Strike"] = { left = 2 } } ou { ["Petrol Strike"] = false } (pas en cours)
function C.ops(c)
    for label, fields in pairs(c) do
        local op = F.env.Ops[label]
        if fields == false then
            if op then fail("mission " .. label .. " encore en cours") end
        elseif not op then fail("mission " .. label .. " pas en cours")
        else
            for k, v in pairs(fields) do
                if op[k] ~= v then fail("mission " .. label .. ", " .. k .. " = " .. tostring(op[k]) .. " au lieu de " .. tostring(v)) end
            end
        end
    end
end

-- { has = "texte" } dans les env.info / warning / error
function C.log(c)
    for _, l in ipairs(F.log) do if l.text:find(c.has, 1, true) then return end end
    fail("dcs.log sans « " .. c.has .. " »")
end

-- ok = function(Fake, env) return vrai, "message si faux" end
function C.ok(fn)
    local good, msg = fn(F, F.env)
    if not good then fail(msg or "vérification libre en échec") end
end

------------------------------------------------------------
-- DÉROULÉ
------------------------------------------------------------
local function matches(text, patterns)
    for _, p in ipairs(patterns or {}) do if text:find(p, 1, true) then return true end end
    return false
end

-- def = scénario, M = mission (mission_defaut), chunk = script compilé ; renvoie la liste des échecs
function Sc.run(def, M, chunk, writedir)
    F.reset(writedir)
    math.randomseed(def.seed or 1)
    if def.mission then def.mission(M) end
    F.build(M)
    if def.scores then F.writeScores(def.scores) end
    Sc.failures, Sc.msgMark, Sc.soundMark = {}, 0, 0
    -- at_start = { { player, slot } } : en solo, l'avion du joueur existe avant le script (son Birth n'est vu par personne)
    for _, s in ipairs(def.at_start or {}) do A.spawn(s) end

    local ok, err = F.loadScript(chunk)
    if def.load_error then
        if ok then fail("le script devait s'arrêter au chargement (« " .. def.load_error .. " »)")
        elseif not err:find(def.load_error, 1, true) then fail("chargement arrêté par une autre erreur : " .. err) end
    elseif not ok then
        fail("chargement du script : " .. err)
    end

    for i, step in ipairs(def.steps or {}) do
        local t = step.t or F.now
        if t < F.now then fail("étape " .. i .. " : t=" .. t .. " avant le temps courant") end
        F.runUntil(t)
        for k, v in pairs(step) do
            if A[k] then
                local good, e = pcall(A[k], v)
                if not good then fail("étape " .. i .. " (" .. k .. ") : " .. tostring(e)) end
            elseif k ~= "t" and k ~= "check" and k ~= "note" then
                fail("étape " .. i .. " : mot inconnu « " .. k .. " »")
            end
        end
        if step.check then
            for k, v in pairs(step.check) do
                if C[k] then C[k](v) else fail("étape " .. i .. " : vérification inconnue « " .. k .. " »") end
            end
            Sc.msgMark, Sc.soundMark = #F.msgs, #F.sounds
        end
    end

    -- Erreurs attrapées (timers, événements, F10) et avertissements du script (ses pcall l'écrivent en env.warning)
    for _, e in ipairs(F.errors) do
        if not matches(e.msg, def.errors) then fail("erreur attrapée par DCS (" .. e.where .. ", t=" .. e.t .. ") : " .. e.msg) end
    end
    for _, l in ipairs(F.log) do
        if l.level ~= "info" and not matches(l.text, def.warnings) then fail("dcs.log, " .. l.level .. " : " .. l.text) end
    end
    for _, p in ipairs(def.errors or {}) do
        local seen = false
        for _, e in ipairs(F.errors) do seen = seen or e.msg:find(p, 1, true) ~= nil end
        if not seen then fail("erreur attendue jamais vue : " .. p) end
    end
    return Sc.failures
end

-- Derniers messages, pour comprendre un échec
function Sc.trace(n)
    local out = {}
    for i = math.max(1, #F.msgs - (n or 12) + 1), #F.msgs do
        local m = F.msgs[i]
        out[#out + 1] = string.format("  t=%g -> %s : %s", m.t, table.concat(m.to, ","), (m.text:gsub("\n", " | ")))
    end
    return table.concat(out, "\n")
end

-- Charge le script dans la mission sans l'objet "name" : renvoie vrai si F10 > SPAWN > HOST A/A AERA existe, et l'erreur
function Sc.probe(M, chunk, name, path)
    F.reset(F.writedir)
    M.remove(name)
    F.build(M)
    local _, err = F.loadScript(chunk)
    local paths = F.menuPaths(coalition.side.BLUE)
    for _, p in ipairs(paths) do if p == path then return true, err end end
    return false, err
end
