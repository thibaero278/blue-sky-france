-----------------------------------------------------
-- Blue Sky - environnement mission
-- Lit la position des avions des joueurs (carte live du site).
-----------------------------------------------------
local base      = _G
dcsbot          = base.dcsbot

local M_TO_FT   = 3.28084
local MS_TO_KT  = 1.94384

-- Rôle pour l'icône du site (attributs DCS)
local function roleOf(unit)
    for _, r in ipairs({ { 'AWACS', 'awacs' }, { 'Tankers', 'tanker' }, { 'Helicopters', 'heli' },
                         { 'Bombers', 'heavy' }, { 'Transports', 'heavy' } }) do
        if unit:hasAttribute(r[1]) then return r[2] end
    end
    return 'jet'
end

-- Vol en cours du pilote (table Flights de script Caucase.lua) : kills et points en attente, validés à l'atterrissage
local function currentFlight(name)
    local f = Flights and Flights[name]
    if not (f and f.active and f.startTime) then return nil end
    return { time = math.floor(timer.getTime() - f.startTime), points = f.points or 0, refuel = math.floor(f.refuelTime or 0),
             airair = f.airair or 0, airsol = f.airsol or 0, airmer = f.airmer or 0 }
end

local function playerUnit(unit)
    if not unit or not unit:isExist() then return nil end
    local name = unit:getPlayerName()
    if not name then return nil end
    -- occupants réels vus par le serveur (lua/commands.lua). Prudent : sans info sur cet avion, on garde le nom DCS
    -- (le 05/11, cacher par défaut a fait disparaître tous les joueurs du serveur de Weefe)
    local uname = unit:getName()
    local seats = BSCrew and BSCrew[uname]
    if seats and seats[1] then
        name = seats[1]
    else
        -- pilote fantôme (DCS garde un pilote parti des multi-places) : caché seulement s'il est vu assis ailleurs
        for u, names in pairs(BSCrew or {}) do
            for _, n in ipairs(names) do
                if n == name and u ~= uname then return nil end
            end
        end
    end
    local p = unit:getPoint()
    local lat, lon = coord.LOtoLL(p)
    local pos = unit:getPosition()
    local hdg = math.deg(math.atan2(pos.x.z, pos.x.x))
    if hdg < 0 then hdg = hdg + 360 end
    local v = unit:getVelocity()
    local air = unit:inAir()
    local base_name = ''
    if not air then
        -- terrain le plus proche (< 5 km) pour « au sol a ... »
        local best
        for _, ab in ipairs(world.getAirbases() or {}) do
            local ap = ab:getPoint()
            local d = math.sqrt((ap.x - p.x) ^ 2 + (ap.z - p.z) ^ 2)
            if d < 5000 and (not best or d < best) then best, base_name = d, ab:getName() end
        end
    end
    return {
        callsign = name,
        aircraft = unit:getTypeName(),
        role     = roleOf(unit),
        side     = unit:getCoalition(),
        air      = air,
        lat      = lat,
        lon      = lon,
        hdg      = math.floor(hdg + 0.5),
        alt      = math.floor(p.y * M_TO_FT + 0.5),
        spd      = math.floor(math.sqrt(v.x ^ 2 + v.y ^ 2 + v.z ^ 2) * MS_TO_KT + 0.5),
        base     = base_name,
        flight   = currentFlight(name),
        bs       = (BSMode and BSMode[name]) and true or nil,  -- mode Blue Sky (script Caucase.lua) : icône spéciale sur le site
        crew     = seats and #seats > 1 and { unpack(seats, 2) } or nil,  -- autres places (multi-équipage)
    }
end

-- Porte-avions affichés sur la carte (type DCS → silhouette du site)
local CARRIERS = { CVN_71 = 'cvn', CVN_72 = 'cvn', CVN_73 = 'cvn', CVN_75 = 'cvn', Stennis = 'cvn', Forrestal = 'cvn',
                   KUZNECOW = 'kuz', CV_1143_5 = 'kuz', LHA_Tarawa = 'lha' }

-- Fréquence, TACAN, ICLS et Link 4 des groupes IA, lus une fois dans le .miz (clé = nom du groupe modèle)
local AI_INFO
local function findTask(t, id, depth)
    if type(t) ~= 'table' or depth > 8 then return nil end
    if t.id == id and t.params then return t.params end
    for _, v in pairs(t) do
        local b = findTask(v, id, depth + 1)
        if b then return b end
    end
end
local function aiInfo()
    if AI_INFO then return AI_INFO end
    AI_INFO = {}
    for _, coal in pairs(env.mission.coalition or {}) do
        for _, country in ipairs(coal.country or {}) do
            for _, cat in ipairs({ 'plane', 'helicopter', 'ship' }) do
                for _, g in ipairs((country[cat] or {}).group or {}) do
                    local info = {}
                    -- avions : MHz sur le groupe ; navires : Hz sur l'unité
                    local u1 = (g.units or {})[1] or {}
                    local f, mod = g.frequency or u1.frequency, g.modulation or u1.modulation
                    if f and f > 0 then
                        if f > 100000 then f = f / 1000000 end
                        info.freq = string.format('%.3f %s', f, mod == 1 and 'FM' or 'AM')
                    end
                    local b = findTask(g.route, 'ActivateBeacon', 0)
                    if b and b.channel then
                        info.tacan = tostring(b.channel) .. (b.modeChannel or 'X') .. (b.callsign and (' ' .. b.callsign) or '')
                    end
                    local icls = findTask(g.route, 'ActivateICLS', 0)
                    if icls and icls.channel then info.icls = tostring(icls.channel) end
                    local l4 = findTask(g.route, 'ActivateLink4', 0)
                    if l4 and l4.frequency then info.link4 = string.format('%.3f', l4.frequency / 1000000) end
                    AI_INFO[g.name or ''] = info
                end
            end
        end
    end
    return AI_INFO
end

local function unitState(unit)
    local p = unit:getPoint()
    local lat, lon = coord.LOtoLL(p)
    local pos, v = unit:getPosition(), unit:getVelocity()
    local hdg = math.deg(math.atan2(pos.x.z, pos.x.x))
    if hdg < 0 then hdg = hdg + 360 end
    return lat, lon, math.floor(hdg + 0.5), math.floor(p.y * M_TO_FT + 0.5),
           math.floor(math.sqrt(v.x ^ 2 + v.y ^ 2 + v.z ^ 2) * MS_TO_KT + 0.5)
end

-- Avions IA en vol et porte-avions. Les ennemis (pas bleus) partent sans nom ni radio.
-- Activation retardée : l'unité existe déjà mais n'est pas active, on l'ignore.
local function aiUnits()
    local list, info = {}, aiInfo()
    for _, side in ipairs({ coalition.side.RED, coalition.side.BLUE, coalition.side.NEUTRAL }) do
        local friend = side == coalition.side.BLUE
        for _, cat in ipairs({ Group.Category.AIRPLANE, Group.Category.HELICOPTER, Group.Category.SHIP }) do
            for _, g in ipairs(coalition.getGroups(side, cat) or {}) do
                -- MOOSE nomme les copies « modèle#001 »
                local gi = info[(g:getName() or ''):gsub('#%d+$', '')] or {}
                for _, unit in ipairs(g:getUnits() or {}) do
                    local ship = cat == Group.Category.SHIP and CARRIERS[unit:getTypeName()]
                    local wanted = ship or (cat ~= Group.Category.SHIP and unit:inAir() and not unit:getPlayerName())
                    if wanted and unit:isExist() and unit:isActive() then
                        local lat, lon, hdg, alt, spd = unitState(unit)
                        list[#list + 1] = {
                            id       = (ship and 'sh' or 'ai') .. tostring(unit:getID()),
                            callsign = friend and (ship and unit:getName() or unit:getCallsign()) or nil,
                            aircraft = unit:getTypeName(),
                            role     = not ship and roleOf(unit) or nil,
                            ship     = ship or nil,
                            side     = side,
                            lat = lat, lon = lon, air = not ship, hdg = hdg, alt = alt, spd = spd,
                            freq     = friend and gi.freq or nil,
                            tacan    = friend and gi.tacan or nil,
                            icls     = friend and gi.icls or nil,
                            link4    = friend and gi.link4 or nil,
                        }
                    end
                end
            end
        end
    end
    return list
end

-- Météo de la mission (vent réel au sol du premier terrain, le reste lu dans le .miz)
local function weather()
    local w = env.mission.weather or {}
    local out = {}
    local ab = (world.getAirbases() or {})[1]
    if ab then
        local p = ab:getPoint()
        p.y = land.getHeight({ x = p.x, y = p.z }) + 10
        local v = atmosphere.getWind(p)
        local spd = math.sqrt(v.x ^ 2 + v.z ^ 2) * MS_TO_KT
        -- le vecteur va où souffle le vent : la provenance est à l'opposé
        local from = (math.deg(math.atan2(v.z, v.x)) + 180) % 360
        out.wind = spd < 1 and 'Calme' or string.format('%03d° / %d kt', math.floor(from + 0.5), math.floor(spd + 0.5))
    end
    local vis = w.visibility and w.visibility.distance
    if vis then out.visibility = vis >= 10000 and '10 km +' or string.format('%.1f km', vis / 1000) end
    local c = w.clouds or {}
    if c.preset then
        out.clouds = c.preset:gsub('Preset', 'Préréglage ') .. (c.base and string.format(' · base %d ft', math.floor(c.base * M_TO_FT / 100 + 0.5) * 100) or '')
    elseif (c.density or 0) == 0 then
        out.clouds = 'Ciel clair'
    else
        out.clouds = string.format('%d/10 · base %d ft', c.density, math.floor((c.base or 0) * M_TO_FT / 100 + 0.5) * 100)
    end
    if w.season and w.season.temperature then out.temp = string.format('%d °C', w.season.temperature) end
    if w.qnh then
        local hpa = w.qnh * 1.33322
        out.qnh = string.format('%d hPa · %.2f inHg', math.floor(hpa + 0.5), hpa * 0.02953)
    end
    return out
end

-- Total fusionné reçu de R2D2 : remplace les scores du script de mission (script Caucase.lua), puis Scores.lua.
-- Les tables des pilotes sont modifiées sur place : le script garde ses références.
-- removeJson : pilotes supprimés (RGPD) sur R2D2, retirés du fichier.
-- id, part, parts : envoi en plusieurs morceaux, appliqué d'un coup quand tous sont arrivés.
function dcsbot.bsSetScores(json, removeJson, id, part, parts)
    local all = net.json2lua(json)
    if type(all) ~= 'table' or not InitPlayer or not SaveScores then return end
    if (parts or 1) > 1 then
        if not BS_PUSH or BS_PUSH.id ~= id then BS_PUSH = { id = id, got = 0, parts = {} } end
        if not BS_PUSH.parts[part] then BS_PUSH.got = BS_PUSH.got + 1 end
        BS_PUSH.parts[part] = all
        if removeJson then BS_PUSH.remove = removeJson end
        if BS_PUSH.got < parts then return end
        all, removeJson = {}, BS_PUSH.remove
        for _, chunk in pairs(BS_PUSH.parts) do
            for name, p in pairs(chunk) do all[name] = p end
        end
        BS_PUSH = nil
    end
    for name, p in pairs(all) do
        local s = InitPlayer(name)
        for k, v in pairs(p) do s[k] = v end
    end
    local removed = removeJson and net.json2lua(removeJson)
    if type(removed) == 'table' and Scores then
        for _, name in ipairs(removed) do Scores[name] = nil end
    end
    SaveScores()
    BS_SCORES_SYNCED = (id and id ~= '') and id or true  -- le bot vérifie que c'est bien son dernier envoi
    env.info('BlueSky : scores fusionnes recus de R2D2')
end

-- Places 2, 3... de chaque avion (lua/commands.lua, toutes les 5 s) → script de mission (BSCrew)
function dcsbot.bsSetCrew(json)
    local crew = net.json2lua(json)
    if type(crew) ~= 'table' then return end
    for k in pairs(BSCrew or {}) do BSCrew[k] = nil end  -- même table : le script garde sa référence
    BSCrew = BSCrew or {}
    for unit, names in pairs(crew) do BSCrew[unit] = names end
end

function dcsbot.bsGetLive(channel)
    local players = {}
    for _, side in ipairs({ coalition.side.NEUTRAL, coalition.side.RED, coalition.side.BLUE }) do
        for _, unit in ipairs(coalition.getPlayers(side) or {}) do
            local ok, data = pcall(playerUnit, unit)
            if ok and data then players[#players + 1] = data end
        end
    end
    local okAi, ai = pcall(aiUnits)
    local okWx, wx = pcall(weather)
    if not okAi then env.warning('BlueSky live : IA ignorées : ' .. tostring(ai)) end
    if not okWx then env.warning('BlueSky live : météo ignorée : ' .. tostring(wx)) end
    dcsbot.sendBotTable({ command = 'bsGetLive', time = timer.getAbsTime(), players = players,
                          ai = okAi and ai or {}, weather = okWx and wx or nil,
                          scoresReady = (InitPlayer and SaveScores and Scores) ~= nil, scoresSynced = BS_SCORES_SYNCED or false }, channel)
end

env.info('DCSServerBot - BlueSky: mission.lua charge')
