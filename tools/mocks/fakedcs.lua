-- Faux DCS + MOOSE partagé des tests hors jeu de "site/mission/script Caucase.lua" (Lua 5.1 comme DCS, chargé par fakedcs.py).
-- Inventaire (15/11) de ce que le script appelle :
--   DCS   : timer (getTime, scheduleFunction), env (info, warning, error), trigger.action (outText, outTextForUnit,
--           outTextForCoalition, outSound, outSoundForUnit), trigger.misc.getZone, coalition (side, getPlayers,
--           getStaticObjects, getGroups), world (event, addEventHandler, getAirbases, removeJunk, VolumeType),
--           land (getIP, getSurfaceType, getHeight, SurfaceType), Object / Unit / Group / StaticObject / Airbase
--           (getByName, Category, méthodes des objets), Weapon.Category, country.id, lfs (writedir, attributes) ;
--           io et dofile = les vrais (Scores.lua écrit dans un dossier temporaire).
--   MOOSE : EVENTHANDLER + EVENTS, GROUP:FindByName (+ méthodes GROUP), _DATABASE (AddGroup, Templates.Groups,
--           GetStaticUnitTemplate, GetGroupTemplate), SPAWN, SPAWNSTATIC, ZONE (New, FindByName), MESSAGE,
--           MENU_GROUP, MENU_GROUP_COMMAND, MENU_COALITION, MENU_COALITION_COMMAND.
-- Comme le vrai jeu : SPAWN:New et SPAWNSTATIC:NewFromStatic plantent si le modèle manque, ZONE:New renvoie nil ;
-- une erreur dans un événement, un timer ou une commande F10 est attrapée et notée dans Fake.errors (DCS et MOOSE
-- l'écrivent dans dcs.log) ; os est bloqué (MissionScripting.lua) ; les places 2, 3 d'un multi-places ne sont vues
-- que par le bot, recopiées dans BSCrew toutes les 5 s (bot BS/plugins/bluesky/lua/commands.lua).

Fake = {}
local F = Fake
local sqrt, unpack = math.sqrt, unpack
local io_open = io.open
os = nil

function F.dist(a, b) return sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) end

function F.reset(writedir)
    F.now, F.seq, F.nextId = 0, 0, 1000
    F.queue = {}
    F.units, F.unitList, F.groups, F.groupList = {}, {}, {}, {}
    F.statics, F.staticList, F.airbases, F.airbaseList, F.zones = {}, {}, {}, {}, {}
    F.templates, F.staticTemplates, F.spawnCount = {}, {}, {}
    F.moose, F.rawHandlers, F.wrapped = {}, {}, {}
    F.msgs, F.sounds, F.errors, F.log = {}, {}, {}, {}
    F.menus = { coalition = {}, group = {} }
    F.writedir = writedir or ""
    F.env, F.loadError = nil, nil
    _DATABASE = setmetatable({ Templates = { Groups = {} } }, { __index = F.DB })
end

-- Comme DCS / MOOSE : l'erreur ne remonte pas, elle est notée (où, quand, message)
function F.try(where, fn, ...)
    local res = { pcall(fn, ...) }
    if not res[1] then
        F.errors[#F.errors + 1] = { t = F.now, where = where, msg = tostring(res[2]) }
        return nil
    end
    return unpack(res, 2, table.maxn(res))
end

------------------------------------------------------------
-- CONSTANTES DCS
------------------------------------------------------------
coalition = { side = { NEUTRAL = 0, RED = 1, BLUE = 2 } }
country = { id = { RUSSIA = 0, USA = 2 } }
Object = { Category = { UNIT = 1, WEAPON = 2, STATIC = 3, BASE = 4, SCENERY = 5, CARGO = 6 } }
Unit = { Category = { AIRPLANE = 0, HELICOPTER = 1, GROUND_UNIT = 2, SHIP = 3, STRUCTURE = 4 } }
Group = { Category = { AIRPLANE = 0, HELICOPTER = 1, GROUND = 2, SHIP = 3, TRAIN = 4 } }
StaticObject = {}
Airbase = { Category = { AIRDROME = 0, HELIPAD = 1, SHIP = 2 } }
Weapon = { Category = { SHELL = 0, MISSILE = 1, ROCKET = 2, BOMB = 3 } }
land = { SurfaceType = { LAND = 1, SHALLOW_WATER = 2, WATER = 3, ROAD = 4, RUNWAY = 5 } }
local EVENT_IDS = { Shot = 1, Hit = 2, Takeoff = 3, Land = 4, Crash = 5, Ejection = 6, Refueling = 7, Dead = 8,
    PilotDead = 9, MissionEnd = 12, RefuelingStop = 14, Birth = 15, EngineShutdown = 19, PlayerEnterUnit = 20, PlayerLeaveUnit = 21,
    Kill = 28, UnitLost = 30 }
world = { event = {}, VolumeType = { SEGMENT = 0, BOX = 1, SPHERE = 2, PYRAMID = 3 } }
EVENTS = {}
for name, id in pairs(EVENT_IDS) do
    EVENTS[name] = name
    world.event["S_EVENT_" .. name:gsub("(%l)(%u)", "%1_%2"):upper()] = id
end

------------------------------------------------------------
-- OBJETS DCS (unités, statiques, aérodromes, armes : même classe) ET GROUPES
------------------------------------------------------------
local Obj = {}
Obj.__index = Obj
function Obj:isExist() return self.exists end
function Obj:getName() return self.name end
function Obj:getID() return self.id end
function Obj:getTypeName() return self.type end
function Obj:getCoalition() return self.coal end
function Obj:getCategory() return self.objcat end
function Obj:getPoint() return { x = self.x, y = self.y, z = self.z } end
function Obj:getPosition()
    local h = self.heading or 0 -- radians, 0 = nord (x)
    return { p = self:getPoint(), x = { x = math.cos(h), y = 0, z = math.sin(h) }, y = { x = 0, y = 1, z = 0 },
             z = { x = -math.sin(h), y = 0, z = math.cos(h) } }
end
function Obj:getVelocity()
    local f, v = self:getPosition().x, self.speed or 0
    return { x = f.x * v, y = 0, z = f.z * v }
end
function Obj:getLife() return self.life end
function Obj:getLife0() return self.life0 end
function Obj:getDesc() return { category = self.cat, typeName = self.type, life = self.life0, displayName = self.type } end
function Obj:getGroup() return self.group end
function Obj:getPlayerName() return self.player end
function Obj:inAir() return self.air or false end
function Obj:isActive() return self.active end
function Obj:getFuel() return self.fuel or 1 end
function Obj:getAmmo() return self.ammo end
function Obj:getDrawArgumentValue() return self.gear or 1 end
function Obj:getTarget() return self.target end
function Obj:getCallsign() return self.name end
function Obj:destroy() self.exists = false end -- comme DCS : aucun événement
-- aérodromes (23/11, capture) : couleur imposée par le script, capture native de DCS coupée
function Obj:setCoalition(side) self.coal = side end
function Obj:autoCapture(on) self.auto = on end

local Grp = {}
Grp.__index = Grp
function Grp:getUnits()
    local list = {}
    for _, u in ipairs(self.units) do if u.exists then list[#list + 1] = u end end
    return list
end
function Grp:isExist() return #self:getUnits() > 0 end
function Grp:getUnit(i) return self:getUnits()[i] end
function Grp:getSize() return #self:getUnits() end
function Grp:getName() return self.name end
function Grp:getID() return self.id end
function Grp:getCoalition() return self.coal end
function Grp:getCategory() return self.cat end
function Grp:destroy() for _, u in ipairs(self:getUnits()) do u.exists = false end end
function Grp:activate() -- activation retardée : DCS envoie Birth pour chaque unité
    for _, u in ipairs(self:getUnits()) do
        if not u.active then
            u.active = true
            F.event("Birth", { initiator = u })
        end
    end
end

local function newId() F.nextId = F.nextId + 1 return F.nextId end
local UNIT_CAT = { AIRPLANE = 0, HELICOPTER = 1, GROUND = 2, SHIP = 3, TRAIN = 2 }

-- d (groupe) : name, kind (AIRPLANE, HELICOPTER, GROUND, SHIP, TRAIN), coal, x, z, alt, late, client, units = { { name, type, x, z, life } }
function F.addGroup(d)
    d.name = d.name or ("groupe " .. (F.nextId + 1)) -- sans nom : nom unique (tests)
    local g = setmetatable({ name = d.name, kind = d.kind or "GROUND", coal = d.coal or 1, id = newId(), units = {}, def = d },
        Grp)
    g.cat = Group.Category[g.kind]
    local flying = (g.kind == "AIRPLANE" or g.kind == "HELICOPTER") and not d.client and (d.alt or 0) > 0
    for i, ud in ipairs(d.units or { {} }) do
        local u = setmetatable({ name = ud.name or (d.name .. "-" .. i), type = ud.type or "?", id = newId(),
            objcat = Object.Category.UNIT, cat = UNIT_CAT[g.kind], coal = g.coal, group = g,
            x = ud.x or d.x or 0, z = ud.z or d.z or 0, y = d.alt or 0, heading = ud.heading or 0,
            speed = flying and (d.speed or 200) or 0, life = ud.life or 10, life0 = ud.life or 10, fuel = 1,
            ammo = ud.ammo or { { count = 2, desc = { category = Weapon.Category.MISSILE } } },
            air = flying, active = not d.late, exists = not d.client, gear = 1 }, Obj)
        F.units[u.name] = u
        F.unitList[#F.unitList + 1] = u
        g.units[i] = u
    end
    F.groups[g.name] = g
    F.groupList[#F.groupList + 1] = g
    F.templates[g.name] = d
    local first = (d.units and d.units[1]) or {}
    _DATABASE.Templates.Groups[g.name] = { Template = { name = g.name, route = { points = { {
        alt = d.alt or 0, x = first.x or d.x or 0, y = first.z or d.z or 0, task = d.task } } } } }
    return g
end

-- d : name, type, coal, x, z, life
function F.addStatic(d)
    local s = setmetatable({ name = d.name, type = d.type or "?", id = newId(), objcat = Object.Category.STATIC,
        cat = Unit.Category.STRUCTURE, coal = d.coal or 1, x = d.x or 0, z = d.z or 0, y = 0, life = d.life or 10,
        life0 = d.life or 10, exists = true, active = true }, Obj)
    F.statics[s.name] = s
    F.staticList[#F.staticList + 1] = s
    F.staticTemplates[s.name] = d
    return s
end

-- d : name, type, coal, x, z, kind (AIRDROME, HELIPAD, SHIP), life, runway (rayon en m de la piste autour du centre)
function F.addAirbase(d)
    local kind = d.kind or "AIRDROME"
    local a = setmetatable({ name = d.name, type = d.type or d.name, id = newId(), objcat = Object.Category.BASE,
        cat = Airbase.Category[kind], coal = d.coal or 0, x = d.x, z = d.z, y = 0, life = d.life or 3600,
        life0 = d.life or 3600, exists = true, active = true, runway = d.runway or (kind == "AIRDROME" and 1500 or nil) }, Obj)
    F.airbases[a.name] = a
    F.airbaseList[#F.airbaseList + 1] = a
    return a
end

-- d : name, x, z, r (cercle) ou name, quad = { { x, z }, ... }
function F.addZone(d) F.zones[d.name] = d end

function F.weapon(typeName, target, from)
    local w = setmetatable({ name = typeName, type = typeName, id = newId(), objcat = Object.Category.WEAPON,
        exists = true, x = from.x, y = from.y, z = from.z, target = target }, Obj)
    w.id_ = w.id
    return w
end

-- Mission : { airbases, zones, groups, statics } (mocks/mission_defaut.lua)
function F.build(M)
    for _, a in ipairs(M.airbases) do F.addAirbase(a) end
    for _, z in ipairs(M.zones) do F.addZone(z) end
    for _, g in ipairs(M.groups) do F.addGroup(g) end
    for _, s in ipairs(M.statics) do F.addStatic(s) end
end

------------------------------------------------------------
-- FONCTIONS DCS
------------------------------------------------------------
function Unit.getByName(n) local u = F.units[n] return u and u.exists and u or nil end
function Group.getByName(n) local g = F.groups[n] return g and g:isExist() and g or nil end
function StaticObject.getByName(n) local s = F.statics[n] return s and s.exists and s or nil end
function Airbase.getByName(n) return F.airbases[n] end
function Object.getCategory(o) return o.objcat end

function coalition.getPlayers(side)
    local list = {}
    for _, u in ipairs(F.unitList) do
        if u.exists and u.player and u.coal == side then list[#list + 1] = u end
    end
    return list
end
function coalition.getStaticObjects(side)
    local list = {}
    for _, s in ipairs(F.staticList) do if s.exists and s.coal == side then list[#list + 1] = s end end
    return list
end
-- Groupe créé par le script (23/11 : troupes, transports et CAP achetés) : pays bleu (USA) ou rouge, unités à leur position
-- ; DCS envoie Birth pour chaque unité. Garde les données reçues dans Fake.added (vérifications des scénarios).
F.added = {}
local KIND_OF = { [0] = "AIRPLANE", [1] = "HELICOPTER", [2] = "GROUND", [3] = "SHIP" }
function coalition.addGroup(countryId, cat, data)
    assert(type(data.name) == "string" and data.units and #data.units > 0, "addGroup : nom et unités obligatoires")
    for _, u in ipairs(data.units) do assert(u.name and u.type and u.x and u.y, "addGroup : unité sans nom, type ou position") end
    F.added[#F.added + 1] = { country = countryId, cat = cat, data = data }
    local units = {}
    for i, u in ipairs(data.units) do units[i] = { name = u.name, type = u.type, x = u.x, z = u.y } end
    local g = F.addGroup({ name = data.name, kind = KIND_OF[cat], coal = countryId == country.id.USA and 2 or 1,
        alt = data.units[1].alt, speed = data.units[1].speed, units = units })
    for _, u in ipairs(g.units) do F.event("Birth", { initiator = u }) end
    return g
end
function coalition.getGroups(side, cat)
    local list = {}
    for _, g in ipairs(F.groupList) do
        if g.coal == side and (cat == nil or g.cat == cat) and g:isExist() then list[#list + 1] = g end
    end
    return list
end

function world.getAirbases()
    local list = {}
    for _, a in ipairs(F.airbaseList) do if a.exists then list[#list + 1] = a end end
    return list
end
function world.addEventHandler(h) F.rawHandlers[#F.rawHandlers + 1] = h end
function world.removeJunk() return 0 end

function land.getIP() return nil end
function land.getHeight() return 0 end
function land.getSurfaceType(p) -- p = { x, y = z }
    for _, a in ipairs(F.airbaseList) do
        if a.runway and F.dist(a, { x = p.x, z = p.y }) <= a.runway then return land.SurfaceType.RUNWAY end
    end
    return land.SurfaceType.LAND
end

timer = {}
function timer.getTime() return F.now end
function timer.getAbsTime() return F.now + 8 * 3600 end
function timer.scheduleFunction(fn, arg, t)
    F.seq = F.seq + 1
    F.queue[#F.queue + 1] = { fn = fn, arg = arg, t = t, id = F.seq }
    return F.seq
end
function timer.removeFunction(id)
    for i, e in ipairs(F.queue) do if e.id == id then table.remove(F.queue, i) return end end
end

-- Fait tourner l'horloge jusqu'à T : chaque fonction programmée part à son heure (ordre d'inscription à heure égale)
function F.runUntil(T)
    while true do
        local best, bi
        for i, e in ipairs(F.queue) do
            if e.t <= T and (not best or e.t < best.t or (e.t == best.t and e.id < best.id)) then best, bi = e, i end
        end
        if not best then break end
        table.remove(F.queue, bi)
        if best.t > F.now then F.now = best.t end
        local nxt = F.try("timer", best.fn, best.arg, F.now)
        if type(nxt) == "number" then timer.scheduleFunction(best.fn, best.arg, math.max(nxt, F.now + 0.01)) end
    end
    if T > F.now then F.now = T end
end

env = {}
for _, level in ipairs({ "info", "warning", "error" }) do
    env[level] = function(text) F.log[#F.log + 1] = { t = F.now, level = level, text = tostring(text) } end
end

lfs = {}
function lfs.writedir() return F.writedir end
function lfs.attributes(path)
    local f = io_open(path, "r")
    if not f then return nil end
    f:close()
    return { mode = "file" }
end

-- Qui est dans l'avion : places vues par le bot (pilote en premier), sinon le pilote vu par DCS
local function occupants(u) return u.seats or { u.player } end
F.occupants = occupants

function F.unitOf(player)
    for _, u in ipairs(F.unitList) do
        if u.exists then
            for _, n in ipairs(occupants(u)) do if n == player then return u end end
        end
    end
end

local function recipients(kind, target)
    local names = {}
    for _, u in ipairs(F.unitList) do
        local hit = kind == "all" or (kind == "coalition" and u.coal == target) or (kind == "group" and u.group.name == target)
            or (kind == "unit" and u.id == target)
        if hit and u.exists then
            for _, n in ipairs(occupants(u)) do names[#names + 1] = n end
        end
    end
    return names
end
function F.message(kind, target, text)
    F.msgs[#F.msgs + 1] = { t = F.now, kind = kind, target = target, text = tostring(text), to = recipients(kind, target) }
end
function F.sound(kind, target, file)
    F.sounds[#F.sounds + 1] = { t = F.now, kind = kind, target = target, file = file, to = recipients(kind, target) }
end

trigger = { action = {}, misc = {} }
function trigger.action.outText(text) F.message("all", nil, text) end
function trigger.action.outTextForUnit(id, text) F.message("unit", id, text) end
function trigger.action.outTextForCoalition(side, text) F.message("coalition", side, text) end
function trigger.action.outSoundForUnit(id, file) F.sound("unit", id, file) end
function trigger.action.outSound(file) F.sound("all", nil, file) end
function trigger.misc.getZone(name)
    local z = F.zones[name]
    return z and { point = { x = z.x or 0, y = 0, z = z.z or 0 }, radius = z.r or 0 }
end

------------------------------------------------------------
-- ÉVÉNEMENTS : MOOSE d'abord (son dispatcher est inscrit avant le script), puis world.addEventHandler du script
------------------------------------------------------------
local function describe(d, prefix, o) -- champs EventData de MOOSE (Ini... / Tgt...)
    if not o then return end
    local cat = Object.getCategory(o)
    d[prefix .. "ObjectCategory"] = cat
    d[prefix .. "DCSUnit"], d[prefix .. "DCSUnitName"], d[prefix .. "UnitName"] = o, o:getName(), o:getName()
    d[prefix .. "Coalition"], d[prefix .. "TypeName"], d[prefix .. "Category"] = o:getCoalition(), o:getTypeName(), o:getDesc().category
    if cat == Object.Category.UNIT then
        local g = o:getGroup()
        d[prefix .. "DCSGroup"], d[prefix .. "DCSGroupName"], d[prefix .. "GroupName"] = g, g:getName(), g:getName()
        d[prefix .. "PlayerName"] = o:getPlayerName()
    end
end

-- MOOSE range la base d'un atterrissage dans un AIRBASE (méthodes MOOSE seulement, pas isExist / getName de DCS)
local function mooseAirbase(ab)
    return { AirbaseName = ab:getName(), GetName = function() return ab:getName() end, GetDCSObject = function() return ab end }
end

function F.event(name, ev)
    ev = ev or {}
    ev.id, ev.time = EVENT_IDS[name] or error("événement inconnu : " .. tostring(name)), F.now
    local d = { id = ev.id, time = ev.time, weapon = ev.weapon, Weapon = ev.weapon }
    describe(d, "Ini", ev.initiator)
    describe(d, "Tgt", ev.target)
    if ev.weapon then d.WeaponName = ev.weapon:getTypeName() end
    if ev.place then d.Place, d.PlaceName = mooseAirbase(ev.place), ev.place:getName() end
    for _, h in ipairs(F.moose[name] or {}) do
        local fn = h["OnEvent" .. name]
        if fn then F.try("MOOSE OnEvent" .. name, fn, h, d) end
    end
    for _, h in ipairs(F.rawHandlers) do F.try("onEvent " .. name, h.onEvent, h, ev) end
end

------------------------------------------------------------
-- MOOSE
------------------------------------------------------------
EVENTHANDLER = {}
function EVENTHANDLER:New()
    local h = {}
    function h:HandleEvent(name)
        F.moose[name] = F.moose[name] or {}
        table.insert(F.moose[name], self)
        return self
    end
    return h
end

local GroupW = {}
GroupW.__index = GroupW
local function wrapGroup(name)
    local w = F.wrapped[name]
    if not w then
        w = setmetatable({ GroupName = name, tasks = {} }, GroupW)
        F.wrapped[name] = w
    end
    return w
end
F.wrapGroup = wrapGroup

GROUP = {}
function GROUP:FindByName(name) return F.groups[name] and wrapGroup(name) or nil end
F.DB = {}
function F.DB:AddGroup(name) return F.groups[name] and wrapGroup(name) or nil end
function F.DB:GetStaticUnitTemplate(name)
    local s = F.staticTemplates[name]
    return s and { x = s.x, y = s.z, type = s.type, name = s.name }
end
function F.DB:GetGroupTemplate(name)
    local d = F.templates[name]
    if not d then return nil end
    local units = {}
    for i, u in ipairs(d.units or { {} }) do units[i] = { x = u.x or d.x or 0, y = u.z or d.z or 0, type = u.type } end
    return { name = name, units = units, route = { points = { { x = d.x or 0, y = d.z or 0, alt = d.alt or 0 } } } }
end

function GroupW:GetName() return self.GroupName end
function GroupW:GetDCSObject() return Group.getByName(self.GroupName) end
function GroupW:IsAlive() -- comme MOOSE : nil si le groupe n'existe pas, false s'il n'est pas encore activé
    local g = self:GetDCSObject()
    if not g then return nil end
    local u = g:getUnit(1)
    return u and u:isActive() or false
end
function GroupW:Destroy() local g = self:GetDCSObject() if g then g:destroy() end end
function GroupW:GetVec3() local g = self:GetDCSObject() local u = g and g:getUnit(1) return u and u:getPoint() end
function GroupW:GetCoalition() local g = self:GetDCSObject() return g and g:getCoalition() end
function GroupW:SetTask(task) self.tasks[#self.tasks + 1] = task return self end
function GroupW:TaskEscort(follow, offset, lastWp, dist, types)
    return { id = "Escort", params = { group = follow, pos = offset, lastWptIndex = lastWp, engagementDistMax = dist, targetTypes = types } }
end
function GroupW:TaskBombing(p, groupAttack, expend, qty, dir, alt, wtype)
    return { id = "Bombing", params = { point = p, groupAttack = groupAttack, expend = expend, weaponType = wtype } }
end
function GroupW:EnRouteTaskEngageTargets(dist, types, prio)
    return { id = "EngageTargets", params = { maxDist = dist, targetTypes = types, priority = prio } }
end
function GroupW:OptionROEWeaponFree() self.roe = "free" return self end
function GroupW:OptionROEHoldFire() self.roe = "hold" return self end

-- Copie d'un modèle de la mission, noms comme MOOSE : "21-1#001", unités "21-1#001-01"
local function spawnCopy(prefix, p, speed)
    local t = F.templates[prefix]
    local n = (F.spawnCount[prefix] or 0) + 1
    F.spawnCount[prefix] = n
    local name = prefix .. string.format("#%03d", n)
    local air = t.kind == "AIRPLANE" or t.kind == "HELICOPTER"
    local units = {}
    for i, ud in ipairs(t.units or { {} }) do
        units[i] = { name = name .. string.format("-%02d", i), type = ud.type, life = ud.life, ammo = ud.ammo,
                     x = p and p.x, z = p and p.z }
    end
    local g = F.addGroup({ name = name, kind = t.kind, coal = t.coal, x = p and p.x or t.x, z = p and p.z or t.z,
        alt = (p and p.y) or t.alt or (air and 6000 or 0), speed = speed, units = units })
    for _, u in ipairs(g.units) do F.event("Birth", { initiator = u }) end
    return wrapGroup(name)
end

SPAWN = {}
SPAWN.__index = SPAWN
function SPAWN:New(prefix)
    if not F.templates[prefix] then
        error("SPAWN:New: There is no group declared in the mission editor with SpawnTemplatePrefix = '" .. tostring(prefix) .. "'", 2)
    end
    return setmetatable({ prefix = prefix }, SPAWN)
end
function SPAWN:InitRandomizeZones(zones) self.zones = zones return self end
function SPAWN:InitHeading(h) self.heading = h return self end
function SPAWN:InitSpeedMps(v) self.speed = v return self end
function SPAWN:Spawn()
    local p
    if self.zones and self.zones[1] then
        local v = self.zones[1]:GetRandomVec2()
        p = { x = v.x, z = v.y }
    end
    return spawnCopy(self.prefix, p, self.speed)
end
function SPAWN:SpawnFromVec3(p) return spawnCopy(self.prefix, p, self.speed) end

SPAWNSTATIC = {}
SPAWNSTATIC.__index = SPAWNSTATIC
function SPAWNSTATIC:NewFromStatic(name)
    if not F.staticTemplates[name] then
        error("SPAWNSTATIC:New: There is no static declared in the mission editor with SpawnTemplatePrefix = '" .. tostring(name) .. "'", 2)
    end
    return setmetatable({ tpl = name, n = 0 }, SPAWNSTATIC)
end
function SPAWNSTATIC:Spawn()
    self.n = self.n + 1
    local t = F.staticTemplates[self.tpl]
    local s = F.addStatic({ name = self.tpl .. "#" .. self.n, type = t.type, coal = t.coal, x = t.x, z = t.z })
    return { IsAlive = function() return s.exists end, Destroy = function() s.exists = false end, GetName = function() return s.name end }
end

local ZoneW = {}
ZoneW.__index = ZoneW
local function center(z)
    if not z.quad then return { x = z.x, z = z.z } end
    local x, zz = 0, 0
    for _, p in ipairs(z.quad) do x, zz = x + p[1], zz + p[2] end
    return { x = x / #z.quad, z = zz / #z.quad }
end
local function inPolygon(poly, x, z)
    local inside, j = false, #poly
    for i = 1, #poly do
        local xi, zi, xj, zj = poly[i][1], poly[i][2], poly[j][1], poly[j][2]
        if (zi > z) ~= (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi) + xi then inside = not inside end
        j = i
    end
    return inside
end
ZONE = {}
function ZONE:New(name)
    if not F.zones[name] then env.error("ERROR: Zone " .. tostring(name) .. " does not exist!") return nil end
    return setmetatable({ name = name, z = F.zones[name] }, ZoneW)
end
function ZONE:FindByName(name) return F.zones[name] and setmetatable({ name = name, z = F.zones[name] }, ZoneW) or nil end
function ZoneW:GetName() return self.name end
function ZoneW:GetVec2() local c = center(self.z) return { x = c.x, y = c.z } end
function ZoneW:GetRandomVec2() return self:GetVec2() end -- shortcut: centre de la zone (scénarios reproductibles), un vrai tirage si un test en a besoin
function ZoneW:IsVec2InZone(v)
    local z = self.z
    if z.quad then return inPolygon(z.quad, v.x, v.y) end
    return (v.x - z.x) ^ 2 + (v.y - z.z) ^ 2 <= z.r ^ 2
end

MESSAGE = {}
MESSAGE.__index = MESSAGE
function MESSAGE:New(text) return setmetatable({ text = text }, MESSAGE) end
function MESSAGE:ToAll() F.message("all", nil, self.text) return self end
function MESSAGE:ToGroup(g) if g and g.GetName then F.message("group", g:GetName(), self.text) end return self end
function MESSAGE:ToCoalition(side) F.message("coalition", side, self.text) return self end

-- Menus F10 : un arbre par coalition et par groupe. Même texte sous le même parent = même menu (MENU_INDEX de MOOSE).
local Menu = {}
Menu.__index = Menu
function Menu:Remove()
    local p = self.parent
    if p then
        for i, c in ipairs(p.children) do if c == self then table.remove(p.children, i) break end end
    end
    self.parent = nil
    return self
end
function Menu:RemoveSubMenus() self.children = {} return self end
function Menu:Refresh() return self end

local function addMenu(scope, key, text, parent, fn, ...)
    local p = parent
    if not p then
        p = F.menus[scope][key] or setmetatable({ text = "F10", children = {} }, Menu)
        F.menus[scope][key] = p
    end
    text = tostring(text)
    for _, c in ipairs(p.children) do
        if c.text == text then
            if fn then c.fn, c.args, c.n = fn, { ... }, select("#", ...) end
            return c
        end
    end
    local m = setmetatable({ text = text, children = {}, parent = p, fn = fn, args = { ... }, n = select("#", ...) }, Menu)
    p.children[#p.children + 1] = m
    return m
end
MENU_COALITION, MENU_COALITION_COMMAND, MENU_GROUP, MENU_GROUP_COMMAND = {}, {}, {}, {}
function MENU_COALITION:New(side, text, parent) return addMenu("coalition", side, text, parent) end
function MENU_COALITION_COMMAND:New(side, text, parent, fn, ...) return addMenu("coalition", side, text, parent, fn, ...) end
function MENU_GROUP:New(g, text, parent) return addMenu("group", g:GetName(), text, parent) end
function MENU_GROUP_COMMAND:New(g, text, parent, fn, ...) return addMenu("group", g:GetName(), text, parent, fn, ...) end

local function walk(node, prefix, out, cmds)
    for _, c in ipairs(node.children) do
        local path = prefix and (prefix .. " > " .. c.text) or c.text
        out[#out + 1] = path
        if c.fn then cmds[path] = c end
        walk(c, path, out, cmds)
    end
end
-- Arbre F10 vu par un joueur : menus de sa coalition, puis ceux de son groupe ("SPAWN > HOST A/A AERA > Mig21")
function F.menuPaths(side, groupName)
    local out, cmds = {}, {}
    if side and F.menus.coalition[side] then walk(F.menus.coalition[side], nil, out, cmds) end
    if groupName and F.menus.group[groupName] then walk(F.menus.group[groupName], nil, out, cmds) end
    return out, cmds
end
function F.menuOf(player)
    local u = F.unitOf(player)
    if not u then return {}, {} end
    return F.menuPaths(u.coal, u.group.name)
end
-- Clic dans F10 ; false si la commande n'existe pas pour ce joueur
function F.click(player, path)
    local _, cmds = F.menuOf(player)
    local c = cmds[path]
    if not c then return false end
    F.try("F10 " .. path, c.fn, unpack(c.args, 1, c.n))
    return true
end

------------------------------------------------------------
-- CHARGEMENT DU SCRIPT (environnement neuf : ses globales restent dans Fake.env) + BOT (BSCrew toutes les 5 s)
------------------------------------------------------------
function F.botCrewTick()
    local crew = F.env and F.env.BSCrew
    if crew then
        for k in pairs(crew) do crew[k] = nil end -- même table : le script garde sa référence (mission.lua)
        for _, u in ipairs(F.unitList) do
            if u.exists and u.seats and #u.seats > 0 then
                local c = {}
                for i, n in ipairs(u.seats) do c[i] = n end
                crew[u.name] = c
            end
        end
    end
    return F.now + 5
end

function F.loadScript(chunk)
    F.env = setmetatable({}, { __index = _G })
    setfenv(chunk, F.env)
    local ok, err = pcall(chunk)
    F.loadError = not ok and tostring(err) or nil
    timer.scheduleFunction(F.botCrewTick, nil, F.now + 5)
    return ok, F.loadError
end

-- Scores.lua de départ (table pilote -> champs)
function F.writeScores(scores)
    local f = assert(io_open(F.writedir .. "Scores.lua", "w"))
    f:write("return {\n")
    for name, s in pairs(scores) do
        f:write(string.format("    [%q] = {\n", name))
        for k, v in pairs(s) do
            f:write(string.format("        %s = %s,\n", k, type(v) == "number" and tostring(v) or string.format("%q", v)))
        end
        f:write("    },\n")
    end
    f:write("}\n")
    f:close()
end

F.reset()
