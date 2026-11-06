------------------------------------------------------------
-- BLUE SKY - Script mission multi (base : Weefe)
-- Necessite MOOSE charge avant ce script.
--
-- Regles de score :
--  * Les kills/points d'un vol sont EN ATTENTE pendant le vol et
--    valides uniquement a l'atterrissage.
--  * Mort / crash / ejection : temps de vol ajoute au cumul,
--    +1 mort, kills et points du vol PERDUS.
--  * Teamkill : +1 teamkill, aucun point.
--  * Temps de ravitaillement en vol cumule (toujours conserve).
------------------------------------------------------------

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------
local SAVE_FILE = lfs.writedir() .. "Scores.lua"

local CARRIERS = {
    ["CVN-74 John C. Stennis"] = "CVN-74",
    ["CVN-75 Harry S. Truman"] = "CVN-75",
}

local POINTS = {
    AIRPLANE    = 3,
    HELICOPTER  = 2,
    SHIP        = 5,
    GROUND      = 1,
    AIR_DEFENCE = 3,
    STATIC      = 1,
}

-- Grades Armee de l'Air, attribues automatiquement selon les points valides.
-- Pour regler : changer "min" (points a atteindre). Garder l'ordre croissant.
-- (Rien a voir avec s.grade = ROOKIE/INTERMEDIATE/EXPERT, ancien choix du menu F10, retire le 03/11.)
local RANKS = {
    { min = 0,    name = "Aspirant" },
    { min = 10,   name = "Sous-lieutenant" },
    { min = 30,   name = "Lieutenant" },
    { min = 60,   name = "Capitaine" },
    { min = 120,  name = "Commandant" },
    { min = 200,  name = "Lieutenant-colonel" },
    { min = 350,  name = "Colonel" },
    { min = 600,  name = "General de brigade aerienne" },
    { min = 1000, name = "General de division aerienne" },
    { min = 1800, name = "General de corps aerien" },
    { min = 3000, name = "General d'armee aerienne" },
}

local AIR_DEFENCE_KEYWORDS = {
    "sa-", "sam", "buk", "tor 9a331", "hawk", "patriot", "roland", "strela",
    "tunguska", "shilka", "gepard", "avenger", "radar", "ewr",
}

-- Champs numeriques sauvegardes dans Scores.lua
local SCORE_FIELDS = {
    "traps", "landings", "airair", "airsol", "airmer", "points",
    "teamkills", "deaths", "flights",
    "maxFlightTime", "totalFlightTime", "completedFlightTime", "refuelTime",
    "bsFlightTime", "maxRefuel", "maxKillsFlight", "maxKillDistance", "minKillDistance", "maxAltitude", "maxSpeed",
}

local KIND_LABEL = { airair = "A/A", airsol = "A/S", airmer = "A/M" }

local TIME_PTS_S = 300 -- 1 point de score par tranche de 5 min de vol
local TRACK_INTERVAL = 0.05
local IP_DISTANCE = 50

------------------------------------------------------------
-- DONNEES
------------------------------------------------------------
Scores = Scores or {}     -- persistant (Scores.lua)
Flights = {}              -- vol en cours par pilote
RefuelStart = {}          -- debut du contact ravitaillement par pilote
UnitPlayer = {}           -- nom d'unite -> pilote (pour les events ou l'unite est deja morte)
PlayerLife = {}           -- pilote -> { dead = bool } (evite de compter 2 morts)
BSMode = {}               -- pilote -> true : mode Blue Sky active au sol (lu aussi par la carte live du bot)
BSCrew = {}               -- unite -> places 2, 3... occupees (pseudos), envoye toutes les 5 s par le bot (mission.lua)
CrewUnit = {}             -- membre d'equipage en vol -> unite ou son vol a commence

function InitPlayer(playerName)
    local s = Scores[playerName] or {}
    for _, field in ipairs(SCORE_FIELDS) do
        s[field] = s[field] or 0
    end
    s.grade = s.grade or "ROOKIE"
    Scores[playerName] = s
    return s
end

-- Grade (RANKS) correspondant a un total de points : index, palier, palier suivant
function GetRank(points)
    local index = 1
    for i, rank in ipairs(RANKS) do
        if (points or 0) >= rank.min then index = i end
    end
    return index, RANKS[index], RANKS[index + 1]
end

local function NewFlight()
    -- killFar / killNear : distances avion-cible du vol en m (0 = aucune)
    return { active = false, startTime = nil, airair = 0, airsol = 0, airmer = 0, points = 0, refuelTime = 0,
             killFar = 0, killNear = 0 }
end

local function GetFlight(playerName)
    Flights[playerName] = Flights[playerName] or NewFlight()
    return Flights[playerName]
end

------------------------------------------------------------
-- SAUVEGARDE / CHARGEMENT
------------------------------------------------------------
-- Pseudos par defaut de DCS : jamais sauvegardes
local IGNORED_PLAYERS = { ["player"] = true, ["joueur"] = true, ["new callsign"] = true }

-- Ecrit d'abord un fichier temporaire puis remplace Scores.lua : un crash pendant l'ecriture
-- (ou le hook du site qui lit en meme temps) ne tombe jamais sur un fichier a moitie ecrit.
function SaveScores()
    local names = {}
    for playerName in pairs(Scores) do
        if not IGNORED_PLAYERS[string.lower(playerName)] then names[#names + 1] = playerName end
    end
    -- Tri par points puis par nom : fichier lisible et stable d'une sauvegarde a l'autre
    table.sort(names, function(a, b)
        local pa, pb = Scores[a].points or 0, Scores[b].points or 0
        if pa ~= pb then return pa > pb end
        return string.lower(a) < string.lower(b)
    end)

    local out = { "return {\n" }
    for _, playerName in ipairs(names) do
        local s = Scores[playerName]
        out[#out + 1] = string.format("    [%q] = {\n", playerName)
        for _, field in ipairs(SCORE_FIELDS) do
            out[#out + 1] = string.format("        %s = %d,\n", field, math.floor(s[field] or 0))
        end
        out[#out + 1] = string.format("        grade = %q,\n", s.grade or "ROOKIE")
        local _, rank = GetRank(s.points)
        out[#out + 1] = string.format("        rang = %q,\n", rank.name)
        out[#out + 1] = "    },\n"
    end
    out[#out + 1] = "}\n"

    -- Sans le module os (MissionScripting.lua le bloque par defaut) : ecriture directe
    local atomic = os and os.rename and os.remove
    local tmp = atomic and (SAVE_FILE .. ".tmp") or SAVE_FILE
    local file = io.open(tmp, "w")
    if not file then
        env.error("BLUESKY : echec sauvegarde " .. tmp)
        trigger.action.outText("ECHEC sauvegarde Scores.lua", 10)
        return
    end
    file:write(table.concat(out))
    file:close()
    if not atomic then return end

    -- Sous Windows, os.rename echoue si la cible existe : on la retire juste avant
    os.remove(SAVE_FILE)
    local ok, err = os.rename(tmp, SAVE_FILE)
    if not ok then
        env.error("BLUESKY : echec remplacement Scores.lua : " .. tostring(err))
        trigger.action.outText("ECHEC sauvegarde Scores.lua", 10)
    end
end

function LoadScores()
    -- Crash entre la suppression et le renommage : la derniere sauvegarde est restee en .tmp
    if lfs.attributes(SAVE_FILE .. ".tmp") and not lfs.attributes(SAVE_FILE) and os and os.rename then
        os.rename(SAVE_FILE .. ".tmp", SAVE_FILE)
    end

    local file = io.open(SAVE_FILE, "r")
    if not file then
        Scores = {}
        trigger.action.outText("Aucun fichier de score, nouveau tableau", 10)
        return
    end
    file:close()

    local ok, loaded = pcall(dofile, SAVE_FILE)
    if ok and type(loaded) == "table" then
        Scores = loaded
        -- Ajoute les nouveaux champs aux anciens profils
        for playerName in pairs(Scores) do
            InitPlayer(playerName)
        end
        trigger.action.outText("Scores charges", 10)
    else
        Scores = {}
        trigger.action.outText("Erreur chargement Scores.lua", 10)
    end
end

LoadScores()

------------------------------------------------------------
-- OUTILS
------------------------------------------------------------
-- 3725 s -> "01:02:05" (ou "02:05" sous l'heure)
function FormatFlightTime(seconds)
    if not seconds then return "NON DISPONIBLE" end
    local t = math.floor(seconds)
    local h, m, s = math.floor(t / 3600), math.floor(t / 60) % 60, t % 60
    if h > 0 then
        return string.format("%02d:%02d:%02d", h, m, s)
    end
    return string.format("%02d:%02d", m, s)
end

-- 3725 s -> "01h02m"
function FormatFlightTimeLong(seconds)
    local t = math.floor(seconds or 0)
    return string.format("%02dh%02dm", math.floor(t / 3600), math.floor(t / 60) % 60)
end

------------------------------------------------------------
-- RECORDS DU SERVEUR : le record perso du pilote est mis a jour ; s'il bat le record du serveur, annonce a tous.
-- 0 = pas encore de record (pas d'annonce pour un tout premier record, sinon spam au deploiement).
------------------------------------------------------------
local function FormatDistance(m)
    return m >= 1000 and string.format("%.1f km", m / 1000) or (math.floor(m) .. " m")
end

local RECORDS = {
    maxFlightTime   = { "Vol le plus long", FormatFlightTime },
    maxRefuel       = { "Ravitaillement le plus long", FormatFlightTime },
    maxKillsFlight  = { "Plus de kills en un vol", function(v) return v .. " kills" end },
    maxKillDistance = { "Kill le plus loin", FormatDistance },
    minKillDistance = { "Kill le plus proche", FormatDistance, true },
    maxAltitude     = { "Altitude max", function(v) return math.floor(v * 3.28084) .. " ft" end },
    maxSpeed        = { "Vitesse max", function(v) return math.floor(v * 3.6) .. " km/h" end },
}

local function Better(field, a, b) -- a bat b ?
    if a <= 0 then return false end
    if RECORDS[field][3] then return b <= 0 or a < b end
    return a > b
end

function SetRecord(playerName, s, field, value)
    value = math.floor(value or 0)
    if not Better(field, value, s[field] or 0) then return end
    local holder, best = nil, 0
    for name, p in pairs(Scores) do
        if Better(field, p[field] or 0, best) then holder, best = name, p[field] end
    end
    s[field] = value
    if best > 0 and Better(field, value, best) then
        local label, fmt = RECORDS[field][1], RECORDS[field][2]
        MESSAGE:New("*** RECORD BATTU ***\n\n" .. label .. " : " .. playerName .. "\n" .. fmt(value) ..
            "\n(ancien : " .. fmt(best) .. (holder ~= playerName and (" par " .. holder) or "") .. ")", 12):ToAll()
    end
end

local function PlayerFromEvent(EventData)
    if EventData.IniPlayerName then return EventData.IniPlayerName end
    local unitName = EventData.IniUnitName or EventData.IniDCSUnitName
    return unitName and UnitPlayer[unitName]
end

local function UnitIDFromEvent(EventData)
    local u = EventData.IniDCSUnit
    if u and u.isExist and u:isExist() then return u:getID() end
    return nil
end

local function MessageToPlayer(unitID, text, duration)
    if unitID then
        trigger.action.outTextForUnit(unitID, text, duration)
    end
end

function GetCurrentFlightTime(playerName)
    local f = Flights[playerName]
    if not f or not f.active or not f.startTime then return nil end
    return timer.getTime() - f.startTime
end

------------------------------------------------------------
-- VOL : DEBUT / FIN / RAVITAILLEMENT
------------------------------------------------------------
local function StartFlight(playerName)
    InitPlayer(playerName)
    local f = NewFlight()
    f.active = true
    f.startTime = timer.getTime()
    Flights[playerName] = f
end

-- Termine un contact ravitaillement en cours, renvoie sa duree
local function StopRefuel(playerName)
    local t0 = RefuelStart[playerName]
    if not t0 then return nil end
    RefuelStart[playerName] = nil

    local duration = timer.getTime() - t0
    local s = InitPlayer(playerName)
    s.refuelTime = s.refuelTime + duration
    local f = Flights[playerName]
    if f then f.refuelTime = f.refuelTime + duration end
    SetRecord(playerName, s, "maxRefuel", duration) -- record : le contact le plus long, pas le cumul
    return duration
end

-- Ferme le vol actif : ajoute le temps au cumul (qu'il finisse bien ou mal).
-- Renvoie la duree (nil si aucun vol actif) et les stats du vol.
FlightClosedAt = FlightClosedAt or {} -- fin du dernier vol, par pilote (detection de decollage de secours)

local function CloseFlight(playerName)
    StopRefuel(playerName)
    FlightClosedAt[playerName] = timer.getTime()
    CrewUnit[playerName] = nil
    -- Fin du vol (atterrissage, mort, ejection, changement de slot) : le mode Blue Sky s'arrete aussi
    local bs = BSMode[playerName]
    BSMode[playerName] = nil

    local f = Flights[playerName]
    Flights[playerName] = nil
    if not f or not f.active then return nil, f end

    local elapsed = timer.getTime() - f.startTime
    local s = InitPlayer(playerName)
    s.totalFlightTime = s.totalFlightTime + elapsed
    if bs then
        s.bsFlightTime = s.bsFlightTime + elapsed
        f.bsTime = elapsed
    end
    s.flights = s.flights + 1
    SetRecord(playerName, s, "maxFlightTime", elapsed)
    -- records relevés pendant le vol (SampleFlights), gardés comme le vol le plus long, même si le vol finit mal
    SetRecord(playerName, s, "maxAltitude", f.maxAlt)
    SetRecord(playerName, s, "maxSpeed", f.maxSpeed)
    return elapsed, f
end

------------------------------------------------------------
-- MULTI-EQUIPAGE (Apache, F-14...) : DCS n'envoie les events qu'au nom du pilote (place 1).
-- Les autres places (BSCrew) ont chacune leur vol, demarre, ferme et valide comme celui du pilote :
-- heures, kills, points, atterrissages, morts, ravitaillement, mode Blue Sky.
------------------------------------------------------------
-- { pilote, place 2, place 3... } de l'unite
local function Crew(unitName, playerName)
    local list = { playerName }
    for _, c in ipairs(unitName and BSCrew[unitName] or {}) do
        if c ~= playerName then list[#list + 1] = c end
    end
    return list
end

local function EventUnitName(EventData)
    return EventData.IniUnitName or EventData.IniDCSUnitName
end

local function StartCrewFlight(name, unitName)
    StartFlight(name)
    CrewUnit[name] = unitName
    PlayerLife[name] = { dead = false }
end

-- Valide les kills/points d'un vol dans le total.
-- elapsed (atterrissage uniquement) : ajoute au temps de vol complete.
local function CommitFlightKills(playerName, f, elapsed)
    if not f then return end
    local s = InitPlayer(playerName)
    local oldIndex = GetRank(s.points)
    s.airair = s.airair + f.airair
    s.airsol = s.airsol + f.airsol
    s.airmer = s.airmer + f.airmer
    -- temps de vol : 1 pt / 5 min, seulement a l'atterrissage (elapsed absent = kill valide hors atterrissage)
    if elapsed then f.timePts = math.floor(elapsed / TIME_PTS_S); f.points = f.points + f.timePts end
    s.points = s.points + f.points
    -- record : le plus de kills valides sur un seul vol (A/A + A/S + A/M)
    SetRecord(playerName, s, "maxKillsFlight", f.airair + f.airsol + f.airmer)
    SetRecord(playerName, s, "maxKillDistance", f.killFar)
    SetRecord(playerName, s, "minKillDistance", f.killNear)
    if elapsed then s.completedFlightTime = s.completedFlightTime + elapsed end

    local newIndex, rank = GetRank(s.points)
    if newIndex > oldIndex then
        MESSAGE:New("*** PROMOTION ***\n\n" .. playerName .. " est promu " .. rank.name ..
            " !\n(" .. s.points .. " pts)", 12):ToAll()
    end
end

local function FlightSummary(f, elapsed)
    f = f or NewFlight()
    return "\nKills A/A ce vol : " .. f.airair ..
           "\nKills A/S ce vol : " .. f.airsol ..
           "\nKills A/M ce vol : " .. f.airmer ..
           "\nScore de ce vol : " .. f.points .. ((f.timePts or 0) > 0 and (" (dont " .. f.timePts .. " pour le temps de vol)") or "") ..
           "\nTemps de vol : " .. FormatFlightTime(elapsed) ..
           (f.refuelTime > 0 and ("\nRavitaillement : " .. FormatFlightTime(f.refuelTime)) or "") ..
           (f.bsTime and ("\nMode Blue Sky : +" .. FormatFlightTime(f.bsTime) .. " (termine, a reactiver au sol)") or "")
end

------------------------------------------------------------
-- NAISSANCE (spawn dans un slot) + MENU STATISTIQUES
------------------------------------------------------------
PlayerScoreMenus = PlayerScoreMenus or {}
PlayerBSMenus = PlayerBSMenus or {}

-- Unites DCS du groupe, lues directement dans DCS : MOOSE (GROUP:GetUnits) ne connait pas
-- toujours les avions des slots dynamiques des bases
local function GroupDCSUnits(group)
    local g = group and group:GetDCSObject()
    return g and g:isExist() and g:getUnits() or {}
end

local function GroupPlayerName(group)
    for _, u in ipairs(GroupDCSUnits(group)) do
        local name = u:isExist() and u:getPlayerName()
        if name then return name end
    end
    return nil
end

-- Appelle fn(unitID, playerName, dcsUnit) pour chaque joueur du groupe, equipage compris.
-- DCS ne dit pas qui a clique dans un menu F10 de groupe : chacun recoit donc ses propres infos.
local function ForEachGroupPlayer(group, fn)
    for _, u in ipairs(GroupDCSUnits(group)) do
        local pilot = u:isExist() and u:getPlayerName()
        if pilot then
            for _, name in ipairs(Crew(u:getName(), pilot)) do fn(u:getID(), name, u) end
        end
    end
end

ScoreMenuHandler = EVENTHANDLER:New()
ScoreMenuHandler:HandleEvent(EVENTS.Birth)

function ScoreMenuHandler:OnEventBirth(EventData)
    -- Objet DCS plutot que MOOSE (EventData.IniUnit) : marche aussi pour les slots dynamiques
    local dcsUnit = EventData.IniDCSUnit
    if not dcsUnit or not dcsUnit.isExist or not dcsUnit:isExist() then return end
    if Object.getCategory(dcsUnit) ~= Object.Category.UNIT then return end

    -- Nouvelle vie du pilote
    local playerName = EventData.IniPlayerName or dcsUnit:getPlayerName()
    if playerName then
        UnitPlayer[dcsUnit:getName()] = playerName
        PlayerLife[playerName] = { dead = false }
        RefuelStart[playerName] = nil
        Flights[playerName] = nil
        BSMode[playerName] = nil -- a reactiver a chaque apparition
        InitPlayer(playerName)
        -- Slot en vol (air start) : pas d'event decollage, on lance le timer ici
        if dcsUnit:inAir() then
            StartFlight(playerName)
        end

        -- Message d'accueil, au joueur seul, a chaque apparition
        local s = InitPlayer(playerName)
        local _, rank = GetRank(s.points)
        MessageToPlayer(dcsUnit:getID(),
            "Bienvenue sur Blue Sky, " .. playerName .. " !\n" ..
            "GRADE : " .. rank.name .. " (" .. s.points .. " pts)\n" ..
            "Frequences PA / tankers : sur le kneeboard\n" ..
            "Tes stats : F10 > STATISTIQUES\n" ..
            "Vol Blue Sky : F10 > MODE BLUE SKY (au sol)\n" ..
            "Discord : discord.gg/zVEsRbm8h2", 15)
    end

    local dcsGroup = dcsUnit:getGroup()
    local groupName = dcsGroup and dcsGroup:getName()
    if not groupName then return end
    -- groupe ne en cours de mission (slot dynamique) : on l'ajoute a la base MOOSE pour MENU_GROUP
    local group = GROUP:FindByName(groupName) or _DATABASE:AddGroup(groupName)
    if not group then return end

    local tries = 0
    local function TryBuildMenu()
        tries = tries + 1
        if not group:IsAlive() then return nil end

        if GroupPlayerName(group) then
            local groupName = group:GetName()
            if groupName and PlayerScoreMenus[groupName] then
                PlayerScoreMenus[groupName]:Remove()
                PlayerScoreMenus[groupName] = nil
            end
            if groupName and PlayerBSMenus[groupName] then
                PlayerBSMenus[groupName]:Remove()
                PlayerBSMenus[groupName] = nil
            end
            AddScoreMenuForGroup(group)
            return nil
        end

        if tries < 10 then return timer.getTime() + 1 end
        return nil
    end

    timer.scheduleFunction(TryBuildMenu, nil, timer.getTime() + 1)
end

------------------------------------------------------------
-- DECOLLAGE
------------------------------------------------------------
TakeoffHandler = EVENTHANDLER:New()
TakeoffHandler:HandleEvent(EVENTS.Takeoff)

function TakeoffHandler:OnEventTakeoff(EventData)
    local playerName = PlayerFromEvent(EventData)
    if not playerName then return end -- IA : on ignore
    local unitName = EventUnitName(EventData)
    for i, name in ipairs(Crew(unitName, playerName)) do
        local f = Flights[name]
        if not (f and f.active) then -- sinon deja lance par la detection ci-dessous
            if i == 1 then
                StartFlight(name)
                MessageToPlayer(UnitIDFromEvent(EventData), "DECOLLAGE DETECTE\nTimer de vol lance.\nScore de vol remis a 0.", 5)
            else
                StartCrewFlight(name, unitName)
            end
        end
    end
end

-- Secours : DCS n'envoie pas toujours le decollage (constate le 03/11 en slot dynamique, F-5E a Kobuleti).
-- Toutes les 5 s, un joueur en l'air sans vol en cours demarre son vol
-- (pas dans les 10 s apres la fin d'un vol : rebond a l'atterrissage).
local function CheckAirbornePlayers()
    local now = timer.getTime()
    for _, side in ipairs({ coalition.side.RED, coalition.side.BLUE, coalition.side.NEUTRAL }) do
        for _, u in ipairs(coalition.getPlayers(side) or {}) do
            local name = u:isExist() and u:getPlayerName()
            local f = name and Flights[name]
            if name and u:inAir() and not (f and f.active) and not (PlayerLife[name] and PlayerLife[name].dead)
               and now - (FlightClosedAt[name] or -100) > 10 then
                UnitPlayer[u:getName()] = name
                StartFlight(name)
                MessageToPlayer(u:getID(), "DECOLLAGE DETECTE\nTimer de vol lance.\nScore de vol remis a 0.", 5)
            end
            -- equipage monte en vol (ou decollage rate) : son vol commence maintenant
            if name and u:inAir() then
                for i, c in ipairs(Crew(u:getName(), name)) do
                    local fc = Flights[c]
                    if i > 1 and not (fc and fc.active) and now - (FlightClosedAt[c] or -100) > 10 then
                        StartCrewFlight(c, u:getName())
                    end
                end
            end
        end
    end
    -- place quittee en vol : temps ajoute, kills du vol perdus (comme un pilote qui change de slot)
    for c, unitName in pairs(CrewUnit) do
        local still = false
        for _, n in ipairs(BSCrew[unitName] or {}) do
            if n == c then still = true end
        end
        if not still and CloseFlight(c) then SaveScores() end
    end
end

timer.scheduleFunction(function()
    local ok, err = pcall(CheckAirbornePlayers)
    if not ok then env.warning("BlueSky : detection decollage : " .. tostring(err)) end
    return timer.getTime() + 5
end, nil, timer.getTime() + 5)
timer.scheduleFunction(CheckAirbornePlayers, nil, timer.getTime() + 5)

-- Records d'altitude (m, au-dessus de la mer) et de vitesse (m/s, vitesse sol) : relevés chaque seconde
-- pour chaque vol en cours, équipage compris. shortcut: un pic plus court qu'1 s peut être manqué, réduire l'intervalle si besoin.
local function SampleFlights()
    for _, side in ipairs({ coalition.side.RED, coalition.side.BLUE, coalition.side.NEUTRAL }) do
        for _, u in ipairs(coalition.getPlayers(side) or {}) do
            local name = u:isExist() and u:getPlayerName()
            if name and u:inAir() then
                local alt = u:getPoint().y
                local v = u:getVelocity()
                local speed = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
                for _, c in ipairs(Crew(u:getName(), name)) do
                    local f = Flights[c]
                    if f and f.active then
                        f.maxAlt = math.max(f.maxAlt or 0, alt)
                        f.maxSpeed = math.max(f.maxSpeed or 0, speed)
                    end
                end
            end
        end
    end
end

timer.scheduleFunction(function()
    local ok, err = pcall(SampleFlights)
    if not ok then env.warning("BlueSky : records altitude/vitesse : " .. tostring(err)) end
    return timer.getTime() + 1
end, nil, timer.getTime() + 1)

------------------------------------------------------------
-- ATTERRISSAGE / APPONTAGE
------------------------------------------------------------
function IsGearStateSuspicious(dcsUnit)
    if not dcsUnit or not dcsUnit:isExist() then return false end
    local nose = dcsUnit:getDrawArgumentValue(0) or 0
    local right = dcsUnit:getDrawArgumentValue(3) or 0
    local left = dcsUnit:getDrawArgumentValue(5) or 0
    return nose < 0.99 or right < 0.99 or left < 0.99
end

local TROLL_MESSAGES = {
    "AIRBOSS : T'as apponte ou t'as jete un fer a repasser ?",
    "AIRBOSS : Le train etait en option aujourd'hui apparemment.",
    "AIRBOSS : Magnifique. La piste va bien, ton avion un peu moins.",
    "AIRBOSS : C'est un atterrissage ou une procedure d'ecrasement controle ?",
    "AIRBOSS : Meme la ferraille avait l'air plus confiante que toi en finale.",
    "AIRBOSS : On a vu des crashs plus elegants que ca.",
    "AIRBOSS : Je note l'effort. Pas le talent.",
    "AIRBOSS : Le LSO demande si c'etait volontaire.",
    "AIRBOSS : Prochaine fois essaye d'atterrir avec tout l'avion.",
    "AIRBOSS : Le train a demissionne en voyant ton approche.",
}

CarrierHandler = EVENTHANDLER:New()
CarrierHandler:HandleEvent(EVENTS.Land)

function CarrierHandler:OnEventLand(EventData)
    local playerName = EventData.IniPlayerName
    local dcsUnit = EventData.IniDCSUnit
    if not playerName or not dcsUnit then return end

    for i, name in ipairs(Crew(dcsUnit:getName(), playerName)) do
        local elapsed, f = CloseFlight(name)
        -- Pas de vol en cours : faux Land envoye par DCS au spawn (pont du PA en multi), on ignore
        if elapsed then LandFlight(name, f, elapsed, EventData, dcsUnit, i == 1) end
    end
end

-- Atterrissage d'un membre de l'equipage (sound : son joue une seule fois par avion)
function LandFlight(playerName, f, elapsed, EventData, dcsUnit, sound)
    local base = tostring(EventData.PlaceName)
    local unitID = dcsUnit:getID()
    local s = InitPlayer(playerName)
    local carrier = CARRIERS[base]
    local function Sound(file) if sound then trigger.action.outSoundForUnit(unitID, file) end end

    -- Base terrestre : on valide tout de suite
    if not carrier then
        CommitFlightKills(playerName, f, elapsed)
        s.landings = s.landings + 1
        SaveScores()
        MessageToPlayer(unitID, "Bienvenue a " .. base .. ", " .. playerName ..
            "\nAtterrissages total : " .. s.landings .. FlightSummary(f, elapsed), 10)
        Sound("PA.ogg")
        return
    end

    -- Porte-avions : on attend 1 s pour verifier l'etat du train
    local life = PlayerLife[playerName]
    timer.scheduleFunction(function()
        -- Mort entre-temps (crash sur le pont) : rien n'est valide
        if life and life.dead then return nil end

        CommitFlightKills(playerName, f, elapsed)

        if IsGearStateSuspicious(dcsUnit) then
            SaveScores()
            MessageToPlayer(unitID, TROLL_MESSAGES[math.random(#TROLL_MESSAGES)] .. FlightSummary(f, elapsed), 10)
            Sound("troll.ogg")
            return nil
        end

        s.traps = s.traps + 1
        SaveScores()
        MessageToPlayer(unitID,
            "AIRBOSS - " .. carrier .. "\nBienvenue a bord, " .. playerName ..
            "\nAppontages total : " .. s.traps .. FlightSummary(f, elapsed), 10)
        Sound("PA.ogg")
        return nil
    end, nil, timer.getTime() + 1)
end

------------------------------------------------------------
-- MORT / CRASH / EJECTION / DECONNEXION
------------------------------------------------------------
LifeHandler = EVENTHANDLER:New()
LifeHandler:HandleEvent(EVENTS.Crash)
LifeHandler:HandleEvent(EVENTS.Ejection)
LifeHandler:HandleEvent(EVENTS.PilotDead)
LifeHandler:HandleEvent(EVENTS.Dead)
LifeHandler:HandleEvent(EVENTS.PlayerLeaveUnit)
LifeHandler:HandleEvent(EVENTS.MissionEnd)

local function OnPlayerDeath(EventData)
    local pilot = PlayerFromEvent(EventData)
    if not pilot then return end

    for _, playerName in ipairs(Crew(EventUnitName(EventData), pilot)) do
        local life = PlayerLife[playerName]
        if not (life and life.dead) then -- sinon deja compte pour cette vie
            if life then life.dead = true else PlayerLife[playerName] = { dead = true } end

            local elapsed = CloseFlight(playerName) -- temps ajoute, kills du vol jetes
            local s = InitPlayer(playerName)
            s.deaths = s.deaths + 1
            SaveScores()

            trigger.action.outText(
                playerName .. " est tombe au combat (morts : " .. s.deaths .. ")" ..
                (elapsed and ("\nTemps de vol ajoute : " .. FormatFlightTime(elapsed)) or "") ..
                "\nKills et points de ce vol perdus.", 8)
        end
    end
    -- Pas de troll.ogg ici : reserve au train casse sur PA (DCS envoie aussi Dead en quittant le slot)
end

function LifeHandler:OnEventCrash(EventData) OnPlayerDeath(EventData) end
function LifeHandler:OnEventEjection(EventData) OnPlayerDeath(EventData) end
function LifeHandler:OnEventPilotDead(EventData) OnPlayerDeath(EventData) end
function LifeHandler:OnEventDead(EventData) OnPlayerDeath(EventData) end

-- Le pilote quitte son avion (changement de slot, deco) en plein vol :
-- temps ajoute, kills du vol perdus, pas de mort.
function LifeHandler:OnEventPlayerLeaveUnit(EventData)
    local pilot = PlayerFromEvent(EventData)
    if not pilot then return end

    -- l'equipage descend avec le pilote (DCS vide l'avion)
    for _, playerName in ipairs(Crew(EventUnitName(EventData), pilot)) do
        if CloseFlight(playerName) then SaveScores() end
        -- Vie terminee : DCS envoie ensuite Dead/PilotDead pour l'avion retire (briefing, respawn),
        -- a ignorer jusqu'au prochain Birth (sinon troll.ogg + mort comptee a tort)
        if PlayerLife[playerName] then PlayerLife[playerName].dead = true else PlayerLife[playerName] = { dead = true } end
    end
    -- L'avion abandonne ne doit plus etre attribue au pilote
    if EventData.IniUnitName and UnitPlayer[EventData.IniUnitName] == pilot then UnitPlayer[EventData.IniUnitName] = nil end
end

-- Fin de mission : temps de vol des pilotes en l'air ajoute
function LifeHandler:OnEventMissionEnd(EventData)
    for playerName in pairs(Flights) do
        CloseFlight(playerName)
    end
    SaveScores()
end

------------------------------------------------------------
-- RAVITAILLEMENT EN VOL
------------------------------------------------------------
RefuelHandler = EVENTHANDLER:New()
RefuelHandler:HandleEvent(EVENTS.Refueling)
RefuelHandler:HandleEvent(EVENTS.RefuelingStop)

function RefuelHandler:OnEventRefueling(EventData)
    local pilot = PlayerFromEvent(EventData)
    if not pilot then return end
    for _, playerName in ipairs(Crew(EventUnitName(EventData), pilot)) do
        RefuelStart[playerName] = RefuelStart[playerName] or timer.getTime()
    end
end

function RefuelHandler:OnEventRefuelingStop(EventData)
    local playerName = PlayerFromEvent(EventData)
    if not playerName then return end

    for i, name in ipairs(Crew(EventUnitName(EventData), playerName)) do
        if i > 1 then StopRefuel(name) end
    end
    local duration = StopRefuel(playerName)
    if not duration then return end
    SaveScores()

    MessageToPlayer(UnitIDFromEvent(EventData),
        "RAVITAILLEMENT TERMINE\nDuree : " .. FormatFlightTime(duration) ..
        "\nTotal ravitaillement : " .. FormatFlightTimeLong(Scores[playerName].refuelTime), 6)
end

------------------------------------------------------------
-- TRACKING DES ARMES (joueurs uniquement) + IMPACT ESTIME
------------------------------------------------------------
TrackedWeapons = {}
LastImpact = {} -- pilote -> point d'impact estime de sa derniere arme

local function TrackWeapons(_, now)
    for id, data in pairs(TrackedWeapons) do
        local weapon = data.weapon
        if weapon:isExist() then
            local pos = weapon:getPosition()
            data.lastIP = land.getIP(pos.p, pos.x, IP_DISTANCE) or data.lastIP
        else
            if data.lastIP then
                LastImpact[data.shooterName] = data.lastIP
            end
            TrackedWeapons[id] = nil
        end
    end
    return now + TRACK_INTERVAL
end

timer.scheduleFunction(TrackWeapons, nil, timer.getTime() + TRACK_INTERVAL)

WeaponTrackerHandler = {}

function WeaponTrackerHandler:onEvent(event)
    if event.id ~= world.event.S_EVENT_SHOT or not event.weapon or not event.initiator then return end
    if not event.initiator.getPlayerName then return end

    local shooterName = event.initiator:getPlayerName()
    if not shooterName then return end -- les tirs IA ne sont plus suivis

    TrackedWeapons[tostring(event.weapon)] = {
        weapon = event.weapon,
        shooterName = shooterName,
    }
end

world.addEventHandler(WeaponTrackerHandler)

------------------------------------------------------------
-- KILLS
------------------------------------------------------------
local function Distance2D(p1, p2)
    if not p1 or not p2 then return nil end
    local dx, dz = p1.x - p2.x, p1.z - p2.z
    return math.sqrt(dx * dx + dz * dz)
end

local function GetTargetPoint(EventData)
    for _, obj in ipairs({ EventData.TgtDCSUnit, EventData.TgtDCSObject }) do
        if obj and obj.isExist and obj:isExist() then return obj:getPoint() end
    end
    if EventData.TgtObject and EventData.TgtObject.GetPointVec3 then
        local p = EventData.TgtObject:GetPointVec3()
        if p then return { x = p.x, y = p.y, z = p.z } end
    end
    return nil
end

local function IsAirDefence(typeName)
    for _, keyword in ipairs(AIR_DEFENCE_KEYWORDS) do
        if string.find(typeName, keyword, 1, true) then return true end
    end
    return false
end

-- Renvoie : categorie de kill, points, titre, type affiche
local function ClassifyKill(EventData)
    if EventData.TgtObjectCategory == Object.Category.STATIC then
        return "airsol", POINTS.STATIC, "GROUND KILL CONFIRMED", nil
    end
    if EventData.TgtObjectCategory ~= Object.Category.UNIT or not EventData.TgtCategory then return nil end

    local cat = EventData.TgtCategory
    if cat == Unit.Category.AIRPLANE then
        return "airair", POINTS.AIRPLANE, "AIR KILL CONFIRMED", "AVION"
    elseif cat == Unit.Category.HELICOPTER then
        return "airair", POINTS.HELICOPTER, "AIR KILL CONFIRMED", "HELICO"
    elseif cat == Unit.Category.SHIP then
        return "airmer", POINTS.SHIP, "SEA KILL CONFIRMED", nil
    elseif cat == Unit.Category.GROUND_UNIT or cat == Unit.Category.STRUCTURE then
        local typeName = string.lower(EventData.TgtTypeName or "")
        if IsAirDefence(typeName) then
            return "airsol", POINTS.AIR_DEFENCE, "AIR DEFENCE DESTROYED", typeName
        end
        return "airsol", POINTS.GROUND, "GROUND TARGET", typeName
    end
    return nil
end

KillHandler = EVENTHANDLER:New()
KillHandler:HandleEvent(EVENTS.Kill)

function KillHandler:OnEventKill(EventData)
    local playerName = EventData.IniPlayerName
    if not playerName or not EventData.IniDCSUnit then return end

    local unitID = EventData.IniDCSUnit:getID()
    local s = InitPlayer(playerName)
    local crew = Crew(EventData.IniDCSUnit:isExist() and EventData.IniDCSUnit:getName() or EventUnitName(EventData), playerName)

    -- TEAMKILL : compteur seul, aucun point (compte pour tout l'equipage)
    if EventData.TgtCoalition and EventData.IniCoalition and EventData.TgtCoalition == EventData.IniCoalition then
        for _, name in ipairs(crew) do
            local sc = InitPlayer(name)
            sc.teamkills = sc.teamkills + 1
        end
        SaveScores()
        MessageToPlayer(unitID, "TEAMKILL !\nAucun point.\nTeamkills total : " .. s.teamkills, 8)
        return
    end

    local kind, points, title, typeLabel = ClassifyKill(EventData)
    if not kind then return end

    local targetPoint = GetTargetPoint(EventData)
    local shooterPoint = EventData.IniDCSUnit:isExist() and EventData.IniDCSUnit:getPoint() or nil
    -- distance avion-cible pour les records (meme calcul que le message), au moins 1 m (0 = pas de record)
    local killDist = Distance2D(shooterPoint, targetPoint)
    killDist = killDist and math.max(1, math.floor(killDist))

    -- En vol : en attente jusqu'a l'atterrissage. Au sol : valide direct. Chaque membre d'equipage a le kill entier.
    local f, pending
    for i, name in ipairs(crew) do
        local fc = Flights[name]
        local pend = fc and fc.active
        if not pend then fc = NewFlight() end
        fc[kind] = fc[kind] + 1
        fc.points = fc.points + points
        if killDist then
            fc.killFar = math.max(fc.killFar or 0, killDist)
            if (fc.killNear or 0) == 0 or killDist < fc.killNear then fc.killNear = killDist end
        end
        if not pend then
            CommitFlightKills(name, fc)
            SaveScores()
        end
        if i == 1 then f, pending = fc, pend end
    end

    -- Petit delai pour laisser le tracker enregistrer l'impact
    timer.scheduleFunction(function()
        local impact = LastImpact[playerName]
        local target = targetPoint or impact
        local impactDist = Distance2D(impact, target)
        local shooterDist = Distance2D(shooterPoint, target)
        local label = KIND_LABEL[kind]

        MessageToPlayer(unitID,
            title .. "\n" ..
            (typeLabel and typeLabel ~= "" and ("Type : " .. typeLabel .. "\n") or "") ..
            "Valeur : " .. points .. " pt" .. (points > 1 and "s" or "") .. "\n" ..
            "Kills " .. label .. " ce vol : " .. f[kind] ..
            "\nKills " .. label .. " valides : " .. s[kind] ..
            "\nPoints ce vol : " .. f.points ..
            "\nPoints valides : " .. s.points ..
            (pending and "\n(valides a l'atterrissage)" or "") ..
            (impactDist and ("\nDistance impact-cible : " .. math.floor(impactDist) .. " m") or "") ..
            (shooterDist and ("\nDistance avion-cible : " .. math.floor(shooterDist) .. " m") or ""),
            8)
        return nil
    end, nil, timer.getTime() + 0.3)
end

------------------------------------------------------------
-- AFFICHAGE SCORES / CLASSEMENTS
------------------------------------------------------------
-- "GRADE : Sergent  (Sergent-chef a 100 pts, encore 37)"
function RankLine(points)
    local _, rank, nextRank = GetRank(points)
    local line = "GRADE : " .. rank.name
    if nextRank then
        line = line .. "  (" .. nextRank.name .. " a " .. nextRank.min ..
               " pts, encore " .. (nextRank.min - points) .. ")"
    else
        line = line .. "  (grade maximum)"
    end
    return line
end

local function PlayerScoresText(playerName)
    local s = InitPlayer(playerName)
    local f = Flights[playerName] or NewFlight()

    local txt =
        "==========[ SCORES PILOTE ]==========\n\n" ..
        "Pilote : " .. playerName .. "\n" ..
        RankLine(s.points) .. "\n\n" ..
        "KILLS | VOL | TOTAL\n" ..
        string.format("A/A   | %2d  | %3d\n", f.airair, s.airair) ..
        string.format("A/S   | %2d  | %3d\n", f.airsol, s.airsol) ..
        string.format("A/M   | %2d  | %3d\n", f.airmer, s.airmer) ..
        "\n" ..
        string.format("PTS VOL    : %3d\n", f.points) ..
        string.format("PTS TOTAL  : %3d\n", s.points) ..
        string.format("APPONTAGES : %3d\n", s.traps) ..
        string.format("ATTERRIS.  : %3d\n", s.landings) ..
        string.format("MORTS      : %3d\n", s.deaths) ..
        string.format("TEAMKILLS  : %3d\n", s.teamkills) ..
        string.format("VOLS       : %3d\n", s.flights) ..
        "\n" ..
        "TEMPS VOL ACTUEL : " .. FormatFlightTime(GetCurrentFlightTime(playerName)) .. "\n" ..
        "HEURES DE VOL    : " .. FormatFlightTimeLong(s.totalFlightTime) .. "  (morts compris)\n" ..
        "HEURES COMPLETES : " .. FormatFlightTimeLong(s.completedFlightTime) .. "  (atterri)\n" ..
        "VOL LE PLUS LONG : " .. FormatFlightTime(s.maxFlightTime) .. "\n" ..
        "RAVITAILLEMENT   : " .. FormatFlightTime(s.refuelTime) .. "\n" ..
        "HEURES BLUE SKY  : " .. FormatFlightTimeLong(s.bsFlightTime) ..
        "  (mode " .. (BSMode[playerName] and "ACTIF" or "inactif") .. ")"
    return txt
end

function ShowPlayerScores(GroupObject)
    if not GroupObject or not GroupObject:IsAlive() then return end
    ForEachGroupPlayer(GroupObject, function(unitID, playerName)
        MessageToPlayer(unitID, PlayerScoresText(playerName), 15)
    end)
end

-- Classement generique : source = table de stats, field = champ a trier
local function ShowRanking(GroupObject, title, source, field, formatter)
    local ranking = {}
    for name, data in pairs(source) do
        ranking[#ranking + 1] = { name = name, value = data[field] or 0 }
    end
    table.sort(ranking, function(a, b) return a.value > b.value end)

    local lines = { "=== " .. title .. " ===\n" }
    for i = 1, math.min(10, #ranking) do
        lines[#lines + 1] = i .. ". " .. ranking[i].name .. " - " .. formatter(ranking[i].value)
    end
    MESSAGE:New(table.concat(lines, "\n"), 12):ToGroup(GroupObject)
end

local function FormatPts(v) return v .. " pts" end

-- Echelle des grades, avec une fleche sur le grade du pilote
function ShowRankScale(GroupObject)
    if not GroupObject or not GroupObject:IsAlive() then return end
    ForEachGroupPlayer(GroupObject, function(unitID, playerName)
        local s = InitPlayer(playerName)
        local current = GetRank(s.points)

        local lines = { "=== ECHELLE DES GRADES ===\n" }
        for i, rank in ipairs(RANKS) do
            lines[#lines + 1] = string.format("%s%5d pts  %s", i == current and ">> " or "   ", rank.min, rank.name)
        end
        lines[#lines + 1] = "\n" .. RankLine(s.points)
        MessageToPlayer(unitID, table.concat(lines, "\n"), 15)
    end)
end

function ShowGlobalRanking(GroupObject)
    ShowRanking(GroupObject, "CLASSEMENT GLOBAL", Scores, "points", FormatPts)
end

function ShowFlightRanking(GroupObject)
    ShowRanking(GroupObject, "CLASSEMENT VOL EN COURS", Flights, "points", FormatPts)
end

function ShowTotalFlightTimeRanking(GroupObject)
    ShowRanking(GroupObject, "TOP 10 HEURES DE VOL", Scores, "totalFlightTime", FormatFlightTimeLong)
end

function ShowCompletedFlightTimeRanking(GroupObject)
    ShowRanking(GroupObject, "TOP 10 HEURES COMPLETES", Scores, "completedFlightTime", FormatFlightTimeLong)
end

function ShowFlightTimeRanking(GroupObject)
    ShowRanking(GroupObject, "TOP 10 VOL LE PLUS LONG", Scores, "maxFlightTime", FormatFlightTimeLong)
end

function ShowRefuelRanking(GroupObject)
    ShowRanking(GroupObject, "TOP 10 RAVITAILLEMENT", Scores, "refuelTime", FormatFlightTime)
end

function ShowBlueSkyRanking(GroupObject)
    ShowRanking(GroupObject, "TOP 10 HEURES BLUE SKY", Scores, "bsFlightTime", FormatFlightTimeLong)
end

------------------------------------------------------------
-- MODE BLUE SKY : active au sol, compte les heures du vol jusqu'a l'atterrissage.
-- Coupe par CloseFlight (atterrissage, mort, ejection, changement de slot), par le bouton, et a chaque Birth.
-- DCS ne dit pas qui a clique : le clic vaut pour tous les joueurs du groupe.
------------------------------------------------------------
local function SetBlueSkyMode(GroupObject, on)
    if not GroupObject or not GroupObject:IsAlive() then return end
    -- equipage compris : chaque place a son mode
    ForEachGroupPlayer(GroupObject, function(id, name, u)
        if on and u:inAir() then
            MessageToPlayer(id, "MODE BLUE SKY\nA activer au sol, avant le decollage.", 8)
        elseif on and not BSMode[name] then
            BSMode[name] = true
            MessageToPlayer(id, "MODE BLUE SKY ACTIF (" .. name .. ")\nTon prochain vol compte dans tes heures Blue Sky.\n" ..
                "Il s'arrete a l'atterrissage, si tu meurs, t'ejectes ou changes de slot.", 10)
        elseif not on and BSMode[name] then
            -- coupe en vol : le temps deja vole compte
            local elapsed = GetCurrentFlightTime(name)
            BSMode[name] = nil
            if elapsed then
                local s = InitPlayer(name)
                s.bsFlightTime = s.bsFlightTime + elapsed
                SaveScores()
            end
            MessageToPlayer(id, "MODE BLUE SKY DESACTIVE (" .. name .. ")" ..
                (elapsed and ("\nTemps compte : " .. FormatFlightTime(elapsed)) or ""), 8)
        else
            MessageToPlayer(id, "MODE BLUE SKY deja " .. (on and "actif." or "inactif.") .. " (" .. name .. ")", 5)
        end
    end)
end

function ActivateBlueSky(GroupObject) SetBlueSkyMode(GroupObject, true) end
function DeactivateBlueSky(GroupObject) SetBlueSkyMode(GroupObject, false) end

------------------------------------------------------------
-- MENU F10 STATISTIQUES (un par groupe ; "Mes scores" et l'echelle sont envoyes a chaque joueur)
-- Sous-menu GRADES (ROOKIE/INTERMEDIATE/EXPERT) retire le 03/11 : ne servait a rien. s.grade reste dans Scores.lua.
------------------------------------------------------------
function AddScoreMenuForGroup(GroupObject)
    if not GroupObject or not GroupObject:IsAlive() then return end

    local groupName = GroupObject:GetName()
    if not groupName or PlayerScoreMenus[groupName] then return end
    if not GroupPlayerName(GroupObject) then return end

    local root = MENU_GROUP:New(GroupObject, "STATISTIQUES")
    MENU_GROUP_COMMAND:New(GroupObject, "Mes scores", root, ShowPlayerScores, GroupObject)
    MENU_GROUP_COMMAND:New(GroupObject, "Echelle des grades", root, ShowRankScale, GroupObject)
    MENU_GROUP_COMMAND:New(GroupObject, "Top 10 global", root, ShowGlobalRanking, GroupObject)
    MENU_GROUP_COMMAND:New(GroupObject, "Top 10 vol en cours", root, ShowFlightRanking, GroupObject)
    MENU_GROUP_COMMAND:New(GroupObject, "Top 10 heures de vol", root, ShowTotalFlightTimeRanking, GroupObject)
    MENU_GROUP_COMMAND:New(GroupObject, "Top 10 heures completes", root, ShowCompletedFlightTimeRanking, GroupObject)
    MENU_GROUP_COMMAND:New(GroupObject, "Top 10 vol le plus long", root, ShowFlightTimeRanking, GroupObject)
    MENU_GROUP_COMMAND:New(GroupObject, "Top 10 ravitaillement", root, ShowRefuelRanking, GroupObject)
    MENU_GROUP_COMMAND:New(GroupObject, "Top 10 heures Blue Sky", root, ShowBlueSkyRanking, GroupObject)

    local bs = MENU_GROUP:New(GroupObject, "MODE BLUE SKY")
    MENU_GROUP_COMMAND:New(GroupObject, "Activer (au sol)", bs, ActivateBlueSky, GroupObject)
    MENU_GROUP_COMMAND:New(GroupObject, "Desactiver", bs, DeactivateBlueSky, GroupObject)

    PlayerScoreMenus[groupName] = root
    PlayerBSMenus[groupName] = bs
end

------------------------------------------------------------
-- SPAWNS
-- Un seul objet SPAWN par template (reutilise a chaque appel) :
-- evite que MOOSE reprenne les memes noms de groupe (#001) a chaque spawn.
------------------------------------------------------------
local Spawners = {}

local function GetSpawner(template, randomZones)
    local sp = Spawners[template]
    if not sp then
        sp = SPAWN:New(template)
        if randomZones then
            sp:InitRandomizeZones({ ZONE:New("Spawn Air") })
        end
        Spawners[template] = sp
    end
    return sp
end

local function DestroyAll(list)
    for _, obj in ipairs(list) do
        if obj and obj:IsAlive() then obj:Destroy() end
    end
end

-- AIR-AIR : groupes hostiles
local HOSTILES = {
    { menu = "Mig21", prefix = "21-" },
    { menu = "Mig29", prefix = "29-" },
    { menu = "Su27",  prefix = "27-" },
}
HostileGroups = {}

local function SpawnHostile(template)
    local group = GetSpawner(template, true):Spawn()
    if group then HostileGroups[#HostileGroups + 1] = group end
end

-- Detruit TOUS les hostiles spawnes (l'original ne detruisait que le dernier de chaque)
function Clear()
    DestroyAll(HostileGroups)
    HostileGroups = {}
end

-- TANKERS
local TANKERS = {
    { label = "S3-B",        template = "S3B" },
    { label = "KC-135 MPRS", template = "MPRS" },
    { label = "KC-135",      template = "KC135" },
    { label = "KC-130",      template = "KC130" },
    { label = "IL-78",       template = "IL78" },
}

local function SpawnTanker(template)
    GetSpawner(template):Spawn()
end

-- AIR-SOL : Croix
local CROIX_GROUP_COUNT = 6
local CROIX_STATIC_COUNT = 12

local CroixStaticSpawners = {}
for i = 1, CROIX_STATIC_COUNT do
    CroixStaticSpawners[i] = SPAWNSTATIC:NewFromStatic("s-croix-" .. i, country.id.RUSSIA)
end
CroixGroups, CroixStatics = {}, {}

function Croix()
    DestroyAll(CroixStatics)
    DestroyAll(CroixGroups)
    CroixStatics, CroixGroups = {}, {}

    for i = 1, CROIX_GROUP_COUNT do
        CroixGroups[#CroixGroups + 1] = GetSpawner("croix-" .. i):Spawn()
    end
    for i = 1, CROIX_STATIC_COUNT do
        CroixStatics[#CroixStatics + 1] = CroixStaticSpawners[i]:Spawn()
    end
end

-- AIR-SOL : Convoi aleatoire
local CONVOIS = { "conv-1", "conv-2", "conv-3", "conv-4", "conv-5", "conv-6", "conv-7", "conv-8" }

function Convoi()
    GetSpawner(CONVOIS[math.random(#CONVOIS)]):Spawn()
end

------------------------------------------------------------
-- MENUS F10 COALITION BLEUE
------------------------------------------------------------
local BLUE = coalition.side.BLUE

local MenuAirAir = MENU_COALITION:New(BLUE, "AIR-AIR")
for _, h in ipairs(HOSTILES) do
    local sub = MENU_COALITION:New(BLUE, h.menu, MenuAirAir)
    for i = 1, 4 do
        MENU_COALITION_COMMAND:New(BLUE, h.menu .. "-" .. i, sub, SpawnHostile, h.prefix .. i)
    end
end
MENU_COALITION_COMMAND:New(BLUE, "Clear hostile", MenuAirAir, Clear)

local MenuTankers = MENU_COALITION:New(BLUE, "TANKERS")
for _, t in ipairs(TANKERS) do
    MENU_COALITION_COMMAND:New(BLUE, t.label, MenuTankers, SpawnTanker, t.template)
end

local MenuAirSol = MENU_COALITION:New(BLUE, "AIR-SOL")
MENU_COALITION_COMMAND:New(BLUE, "Reset Croix", MenuAirSol, Croix)
MENU_COALITION_COMMAND:New(BLUE, "Spawn Convoi", MenuAirSol, Convoi)
