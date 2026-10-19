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
-- (Rien a voir avec s.grade = ROOKIE/INTERMEDIATE/EXPERT, choisi dans le menu F10.)
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
    "traps", "airair", "airsol", "airmer", "points",
    "teamkills", "deaths", "flights",
    "maxFlightTime", "totalFlightTime", "completedFlightTime", "refuelTime",
}

local KIND_LABEL = { airair = "A/A", airsol = "A/S", airmer = "A/M" }

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
    return { active = false, startTime = nil, airair = 0, airsol = 0, airmer = 0, points = 0, refuelTime = 0 }
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
    return duration
end

-- Ferme le vol actif : ajoute le temps au cumul (qu'il finisse bien ou mal).
-- Renvoie la duree (nil si aucun vol actif) et les stats du vol.
local function CloseFlight(playerName)
    StopRefuel(playerName)

    local f = Flights[playerName]
    Flights[playerName] = nil
    if not f or not f.active then return nil, f end

    local elapsed = timer.getTime() - f.startTime
    local s = InitPlayer(playerName)
    s.totalFlightTime = s.totalFlightTime + elapsed
    s.flights = s.flights + 1
    if elapsed > s.maxFlightTime then
        s.maxFlightTime = math.floor(elapsed)
    end
    return elapsed, f
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
    s.points = s.points + f.points
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
           "\nScore de ce vol : " .. f.points ..
           "\nTemps de vol : " .. FormatFlightTime(elapsed) ..
           (f.refuelTime > 0 and ("\nRavitaillement : " .. FormatFlightTime(f.refuelTime)) or "")
end

------------------------------------------------------------
-- NAISSANCE (spawn dans un slot) + MENU STATISTIQUES
------------------------------------------------------------
PlayerScoreMenus = PlayerScoreMenus or {}

local function GroupPlayerName(group)
    local units = group and group:GetUnits()
    if not units then return nil end
    for _, u in pairs(units) do
        local name = u and u:GetPlayerName()
        if name then return name end
    end
    return nil
end

ScoreMenuHandler = EVENTHANDLER:New()
ScoreMenuHandler:HandleEvent(EVENTS.Birth)

function ScoreMenuHandler:OnEventBirth(EventData)
    local unit = EventData.IniUnit
    if not unit or not unit:IsAlive() then return end

    -- Nouvelle vie du pilote
    local playerName = EventData.IniPlayerName
    if playerName then
        UnitPlayer[EventData.IniUnitName] = playerName
        PlayerLife[playerName] = { dead = false }
        RefuelStart[playerName] = nil
        Flights[playerName] = nil
        InitPlayer(playerName)
        -- Slot en vol (air start) : pas d'event decollage, on lance le timer ici
        if unit:InAir() then
            StartFlight(playerName)
        end
    end

    local group = unit:GetGroup()
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

    StartFlight(playerName)
    MessageToPlayer(UnitIDFromEvent(EventData), "DECOLLAGE DETECTE\nTimer de vol lance.\nScore de vol remis a 0.", 5)
end

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

    local base = tostring(EventData.PlaceName)
    local unitID = dcsUnit:getID()
    local elapsed, f = CloseFlight(playerName)
    local s = InitPlayer(playerName)
    local carrier = CARRIERS[base]

    -- Base terrestre : on valide tout de suite
    if not carrier then
        CommitFlightKills(playerName, f, elapsed)
        SaveScores()
        MessageToPlayer(unitID, "Bienvenue a " .. base .. ", " .. playerName .. FlightSummary(f, elapsed), 10)
        trigger.action.outSoundForUnit(unitID, "PA.ogg")
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
            trigger.action.outSoundForUnit(unitID, "troll.ogg")
            return nil
        end

        s.traps = s.traps + 1
        SaveScores()
        MessageToPlayer(unitID,
            "AIRBOSS - " .. carrier .. "\nBienvenue a bord, " .. playerName ..
            "\nAppontages total : " .. s.traps .. FlightSummary(f, elapsed), 10)
        trigger.action.outSoundForUnit(unitID, "PA.ogg")
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
    local playerName = PlayerFromEvent(EventData)
    if not playerName then return end

    local life = PlayerLife[playerName]
    if life and life.dead then return end -- deja compte pour cette vie
    if life then life.dead = true else PlayerLife[playerName] = { dead = true } end

    local unitID = UnitIDFromEvent(EventData)
    local elapsed = CloseFlight(playerName) -- temps ajoute, kills du vol jetes
    local s = InitPlayer(playerName)
    s.deaths = s.deaths + 1
    SaveScores()

    trigger.action.outText(
        playerName .. " est tombe au combat (morts : " .. s.deaths .. ")" ..
        (elapsed and ("\nTemps de vol ajoute : " .. FormatFlightTime(elapsed)) or "") ..
        "\nKills et points de ce vol perdus.", 8)
    -- unitID peut etre nil (avion detruit) : le message global suffit
    if unitID then trigger.action.outSoundForUnit(unitID, "troll.ogg") end
end

function LifeHandler:OnEventCrash(EventData) OnPlayerDeath(EventData) end
function LifeHandler:OnEventEjection(EventData) OnPlayerDeath(EventData) end
function LifeHandler:OnEventPilotDead(EventData) OnPlayerDeath(EventData) end
function LifeHandler:OnEventDead(EventData) OnPlayerDeath(EventData) end

-- Le pilote quitte son avion (changement de slot, deco) en plein vol :
-- temps ajoute, kills du vol perdus, pas de mort.
function LifeHandler:OnEventPlayerLeaveUnit(EventData)
    local playerName = PlayerFromEvent(EventData)
    if not playerName then return end

    if CloseFlight(playerName) then SaveScores() end
    -- L'avion abandonne ne doit plus etre attribue au pilote
    if EventData.IniUnitName then UnitPlayer[EventData.IniUnitName] = nil end
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
    local playerName = PlayerFromEvent(EventData)
    if not playerName or RefuelStart[playerName] then return end
    RefuelStart[playerName] = timer.getTime()
end

function RefuelHandler:OnEventRefuelingStop(EventData)
    local playerName = PlayerFromEvent(EventData)
    if not playerName then return end

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

    -- TEAMKILL : compteur seul, aucun point
    if EventData.TgtCoalition and EventData.IniCoalition and EventData.TgtCoalition == EventData.IniCoalition then
        s.teamkills = s.teamkills + 1
        SaveScores()
        MessageToPlayer(unitID, "TEAMKILL !\nAucun point.\nTeamkills total : " .. s.teamkills, 8)
        return
    end

    local kind, points, title, typeLabel = ClassifyKill(EventData)
    if not kind then return end

    -- En vol : en attente jusqu'a l'atterrissage. Au sol : valide direct.
    local f = Flights[playerName]
    local pending = f and f.active
    if pending then
        f[kind] = f[kind] + 1
        f.points = f.points + points
    else
        f = NewFlight()
        f[kind], f.points = 1, points
        CommitFlightKills(playerName, f)
        SaveScores()
    end

    local targetPoint = GetTargetPoint(EventData)
    local shooterPoint = EventData.IniDCSUnit:isExist() and EventData.IniDCSUnit:getPoint() or nil

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

function ShowPlayerScores(GroupObject, playerName)
    if not GroupObject or not GroupObject:IsAlive() or not playerName then return end

    local s = InitPlayer(playerName)
    local f = Flights[playerName] or NewFlight()

    local txt =
        "==========[ SCORES PILOTE ]==========\n\n" ..
        "Pilote : " .. playerName .. "  (" .. s.grade .. ")\n" ..
        RankLine(s.points) .. "\n\n" ..
        "KILLS | VOL | TOTAL\n" ..
        string.format("A/A   | %2d  | %3d\n", f.airair, s.airair) ..
        string.format("A/S   | %2d  | %3d\n", f.airsol, s.airsol) ..
        string.format("A/M   | %2d  | %3d\n", f.airmer, s.airmer) ..
        "\n" ..
        string.format("PTS VOL    : %3d\n", f.points) ..
        string.format("PTS TOTAL  : %3d\n", s.points) ..
        string.format("APPONTAGES : %3d\n", s.traps) ..
        string.format("MORTS      : %3d\n", s.deaths) ..
        string.format("TEAMKILLS  : %3d\n", s.teamkills) ..
        string.format("VOLS       : %3d\n", s.flights) ..
        "\n" ..
        "TEMPS VOL ACTUEL : " .. FormatFlightTime(GetCurrentFlightTime(playerName)) .. "\n" ..
        "HEURES DE VOL    : " .. FormatFlightTimeLong(s.totalFlightTime) .. "  (morts compris)\n" ..
        "HEURES COMPLETES : " .. FormatFlightTimeLong(s.completedFlightTime) .. "  (atterri)\n" ..
        "VOL LE PLUS LONG : " .. FormatFlightTime(s.maxFlightTime) .. "\n" ..
        "RAVITAILLEMENT   : " .. FormatFlightTime(s.refuelTime)

    MESSAGE:New(txt, 15):ToGroup(GroupObject)
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
function ShowRankScale(GroupObject, playerName)
    if not GroupObject or not GroupObject:IsAlive() or not playerName then return end
    local s = InitPlayer(playerName)
    local current = GetRank(s.points)

    local lines = { "=== ECHELLE DES GRADES ===\n" }
    for i, rank in ipairs(RANKS) do
        lines[#lines + 1] = string.format("%s%5d pts  %s", i == current and ">> " or "   ", rank.min, rank.name)
    end
    lines[#lines + 1] = "\n" .. RankLine(s.points)
    MESSAGE:New(table.concat(lines, "\n"), 15):ToGroup(GroupObject)
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

------------------------------------------------------------
-- GRADES + MENU F10 STATISTIQUES
------------------------------------------------------------
local GRADES = {
    { value = "ROOKIE", label = "Rookie" },
    { value = "INTERMEDIATE", label = "Intermediate" },
    { value = "EXPERT", label = "Expert" },
}

function SetPlayerGrade(GroupObject, playerName, newGrade)
    if not GroupObject or not GroupObject:IsAlive() or not playerName or not newGrade then return end

    InitPlayer(playerName).grade = newGrade
    SaveScores()

    -- On reconstruit le menu pour deplacer la coche
    local groupName = GroupObject:GetName()
    if groupName and PlayerScoreMenus[groupName] then
        PlayerScoreMenus[groupName]:Remove()
        PlayerScoreMenus[groupName] = nil
    end
    AddScoreMenuForGroup(GroupObject)

    MESSAGE:New("Grade selectionne : " .. newGrade, 8):ToGroup(GroupObject)
end

function AddScoreMenuForGroup(GroupObject)
    if not GroupObject or not GroupObject:IsAlive() then return end

    local groupName = GroupObject:GetName()
    if not groupName or PlayerScoreMenus[groupName] then return end

    local playerName = GroupPlayerName(GroupObject)
    if not playerName then return end
    local s = InitPlayer(playerName)

    local root = MENU_GROUP:New(GroupObject, "STATISTIQUES")
    MENU_GROUP_COMMAND:New(GroupObject, "Mes scores", root, ShowPlayerScores, GroupObject, playerName)
    MENU_GROUP_COMMAND:New(GroupObject, "Echelle des grades", root, ShowRankScale, GroupObject, playerName)
    MENU_GROUP_COMMAND:New(GroupObject, "Top 10 global", root, ShowGlobalRanking, GroupObject)
    MENU_GROUP_COMMAND:New(GroupObject, "Top 10 vol en cours", root, ShowFlightRanking, GroupObject)
    MENU_GROUP_COMMAND:New(GroupObject, "Top 10 heures de vol", root, ShowTotalFlightTimeRanking, GroupObject)
    MENU_GROUP_COMMAND:New(GroupObject, "Top 10 heures completes", root, ShowCompletedFlightTimeRanking, GroupObject)
    MENU_GROUP_COMMAND:New(GroupObject, "Top 10 vol le plus long", root, ShowFlightTimeRanking, GroupObject)
    MENU_GROUP_COMMAND:New(GroupObject, "Top 10 ravitaillement", root, ShowRefuelRanking, GroupObject)

    local gradeMenu = MENU_GROUP:New(GroupObject, "GRADES", root)
    for _, g in ipairs(GRADES) do
        local label = (s.grade == g.value) and ("✓ " .. g.label) or g.label
        MENU_GROUP_COMMAND:New(GroupObject, label, gradeMenu, SetPlayerGrade, GroupObject, playerName, g.value)
    end

    PlayerScoreMenus[groupName] = root
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
