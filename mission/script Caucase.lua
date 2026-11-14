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
    SHIP        = 8,
    GROUND      = 2,
    AIR_DEFENCE = 5,
    LOCOMOTIVE  = 3,
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
    "bsFlightTime", "maxRefuel", "maxKillsFlightAA", "maxKillsFlightAS", "maxKillDistance", "minKillDistance", "maxAltitude", "maxSpeed",
    "maxKillDistanceAS", "minKillDistanceAS", -- kills air-sol (bateaux compris) ; maxKillDistance / minKillDistance = air-air
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
WelcomeVoiced = {}        -- pilote -> true : voix d'accueil deja jouee depuis le lancement de la mission
WELCOME_VOICE_DELAY_S = 10 -- s apres l'apparition avant la voix d'accueil (cockpit charge chez le joueur)
BSCrew = {}               -- unite -> places 2, 3... occupees (pseudos), envoye toutes les 5 s par le bot (mission.lua)
CrewUnit = {}             -- membre d'equipage en vol -> unite ou son vol a commence
SeatUnit = {}             -- joueur -> unite ou le serveur le voit assis (BSCrew), pour detecter qu'il change de place

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
             killFar = 0, killNear = 0, killFarAS = 0, killNearAS = 0 }
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
    return m >= 1852 and string.format("%.1f NM", m / 1852) or (math.floor(m) .. " m")
end

local RECORDS = {
    maxFlightTime   = { "Vol le plus long", FormatFlightTime },
    maxRefuel       = { "Ravitaillement le plus long", FormatFlightTime },
    maxKillsFlightAA = { "Plus de kills air-air en un vol", function(v) return v .. " kills" end },
    maxKillsFlightAS = { "Plus de kills air-sol en un vol", function(v) return v .. " kills" end },
    maxKillDistance = { "Kill air-air le plus loin", FormatDistance },
    minKillDistance = { "Kill air-air le plus proche", FormatDistance, true },
    maxKillDistanceAS = { "Kill air-sol le plus loin", FormatDistance },
    minKillDistanceAS = { "Kill air-sol le plus proche", FormatDistance, true },
    maxAltitude     = { "Altitude max", function(v) return math.floor(v * 3.28084) .. " ft / " .. string.format("%.1f km", v / 1000) end },
    -- shortcut: Mach calcule avec le son en haute altitude (295 m/s), stocker le Mach du vol pour la valeur exacte
    maxSpeed        = { "Vitesse max", function(v) return math.floor(v * 3.6) .. " km/h / Mach " .. string.format("%.1f", v / 295) end },
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
    local f = Flights[playerName]
    Flights[playerName] = nil
    if not f or not f.active then return nil, f end

    -- Fin du vol (atterrissage, mort, ejection, changement de slot) : le mode Blue Sky s'arrete aussi.
    -- Apres le test du vol actif : un faux Land au sol (pont du PA) coupait le mode avant le decollage.
    local bs = BSMode[playerName]
    BSMode[playerName] = nil

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
    -- diagnostic du bug « records comptes seulement apres un crash » : a retirer une fois resolu
    env.info(string.format("BlueSky records : fin de vol %s, alt %d m (record %d), vitesse %d m/s (record %d), mode BS %s",
        playerName, f.maxAlt or 0, s.maxAltitude or 0, f.maxSpeed or 0, s.maxSpeed or 0, bs and "oui" or "non"))
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
    env.info("BlueSky equipage : vol demarre pour " .. name .. " dans " .. tostring(unitName))
end

-- Valide les kills/points d'un vol dans le total.
-- elapsed (atterrissage uniquement) : ajoute au temps de vol complete.
-- divisor (atterrissage hors aeroport, 13/11) : les points du vol sont divises, f.offFieldLoss = points perdus
local function CommitFlightKills(playerName, f, elapsed, divisor)
    if not f then return end
    local s = InitPlayer(playerName)
    local oldIndex = GetRank(s.points)
    s.airair = s.airair + f.airair
    s.airsol = s.airsol + f.airsol
    s.airmer = s.airmer + f.airmer
    -- temps de vol : 1 pt / 5 min, seulement a l'atterrissage (elapsed absent = kill valide hors atterrissage)
    if elapsed then f.timePts = math.floor(elapsed / TIME_PTS_S); f.points = f.points + f.timePts end
    if divisor and f.points > 0 then
        f.offFieldLoss = f.points - math.floor(f.points / divisor)
        f.points = f.points - f.offFieldLoss
    end
    s.points = s.points + f.points
    -- records : le plus de kills valides sur un seul vol, air-air d'un cote, air-sol (bateaux compris) de l'autre
    SetRecord(playerName, s, "maxKillsFlightAA", f.airair)
    SetRecord(playerName, s, "maxKillsFlightAS", f.airsol + f.airmer)
    SetRecord(playerName, s, "maxKillDistance", f.killFar)
    SetRecord(playerName, s, "minKillDistance", f.killNear)
    SetRecord(playerName, s, "maxKillDistanceAS", f.killFarAS)
    SetRecord(playerName, s, "minKillDistanceAS", f.killNearAS)
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
           (f.offFieldLoss and ("\nPose hors aeroport : points divises par " .. OFFFIELD_DIVISOR .. " (-" .. f.offFieldLoss .. ")") or "") ..
           "\nTemps de vol : " .. FormatFlightTime(elapsed) ..
           (f.refuelTime > 0 and ("\nRavitaillement : " .. FormatFlightTime(f.refuelTime)) or "") ..
           (f.bsTime and ("\nMode Blue Sky : +" .. FormatFlightTime(f.bsTime) .. " (termine, a reactiver au sol)") or "")
end

------------------------------------------------------------
-- NAISSANCE (spawn dans un slot) + MENU STATISTIQUES
------------------------------------------------------------
PlayerScoreMenus = PlayerScoreMenus or {}
PlayerBSMenus = PlayerBSMenus or {}
PlayerMissionMenus = PlayerMissionMenus or {}
PlayerCodeMenus = PlayerCodeMenus or {}

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
        -- Voix d'accueil (commandement) : seulement a la premiere apparition depuis le lancement de la mission.
        -- Lancee WELCOME_VOICE_DELAY_S apres l'apparition : a +2 s elle etait coupee au milieu (11/11, au mot
        -- « kneeboard »), sans doute par la fin du chargement du cockpit chez le joueur.
        if not WelcomeVoiced[playerName] then
            WelcomeVoiced[playerName] = true
            local id, unitName = dcsUnit:getID(), dcsUnit:getName()
            timer.scheduleFunction(function()
                local u = Unit.getByName(unitName)
                if u and u:isExist() and u:getPlayerName() == playerName then
                    trigger.action.outSoundForUnit(id, "c00_accueil.ogg")
                else
                    WelcomeVoiced[playerName] = nil -- avion quitte avant : la voix passera a la prochaine apparition
                end
            end, nil, timer.getTime() + WELCOME_VOICE_DELAY_S)
        end
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
            for _, menus in ipairs({ PlayerScoreMenus, PlayerBSMenus, PlayerDebugMenus, PlayerMissionMenus, PlayerCodeMenus }) do
                if groupName and menus[groupName] then
                    menus[groupName]:Remove()
                    menus[groupName] = nil
                end
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
    -- Monter dans un multi-places = nouvelle vie : DCS n'envoie pas de Birth a celui qui monte.
    -- Sans ca, sa mort ou son changement de slot d'avant (dead = true) bloquait son vol quand
    -- DCS le donne comme pilote (getPlayerName) d'un avion deja en l'air.
    local seated = {}
    for unitName, seats in pairs(BSCrew) do
        for _, n in ipairs(seats) do
            seated[n] = true
            if SeatUnit[n] ~= unitName then
                SeatUnit[n] = unitName
                PlayerLife[n] = { dead = false }
                env.info("BlueSky equipage : " .. n .. " assis dans " .. unitName)
            end
        end
    end
    for n in pairs(SeatUnit) do
        if not seated[n] then SeatUnit[n] = nil end
    end
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

-- Records d'altitude (m, au-dessus de la mer) et de vitesse (m/s, vitesse sol) : relevés toutes les 0,5 s
-- pour chaque vol en cours, équipage compris. Garde-fou (Mach 4 en F-18 le 11/11) : une valeur ne compte que
-- si elle est tenue au moins RECORD_HOLD_S, c.-à-d. le minimum des relevés de la dernière seconde.
RECORD_SAMPLE_S = 0.5
RECORD_HOLD_S = 1

-- Valeur tenue pendant RECORD_HOLD_S d'après l'historique h (relevés { t, v }), ou nil si trop court
function HeldValue(h, now, value)
    h[#h + 1] = { t = now, v = value }
    while #h > 1 and now - h[2].t >= RECORD_HOLD_S do table.remove(h, 1) end  -- garde juste de quoi couvrir 1 s
    if now - h[1].t < RECORD_HOLD_S then return nil end
    local low = value
    for _, s in ipairs(h) do low = math.min(low, s.v) end
    return low
end

local function SampleFlights()
    local now = timer.getTime()
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
                        -- trou dans les relevés (au sol, slot changé) : on repart de zéro
                        if f.sampleAt and now - f.sampleAt > RECORD_SAMPLE_S * 2.5 then f.altHist, f.spdHist = nil, nil end
                        f.sampleAt = now
                        f.altHist, f.spdHist = f.altHist or {}, f.spdHist or {}
                        local heldAlt, heldSpd = HeldValue(f.altHist, now, alt), HeldValue(f.spdHist, now, speed)
                        if heldAlt then f.maxAlt = math.max(f.maxAlt or 0, heldAlt) end
                        if heldSpd then f.maxSpeed = math.max(f.maxSpeed or 0, heldSpd) end
                    end
                end
            end
        end
    end
end

timer.scheduleFunction(function()
    local ok, err = pcall(SampleFlights)
    if not ok then env.warning("BlueSky : records altitude/vitesse : " .. tostring(err)) end
    return timer.getTime() + RECORD_SAMPLE_S
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

    local base, onField = LandPlace(dcsUnit, EventData.Place)
    for i, name in ipairs(Crew(dcsUnit:getName(), playerName)) do
        local elapsed, f = CloseFlight(name)
        -- Pas de vol en cours : faux Land envoye par DCS au spawn (pont du PA en multi), on ignore
        if elapsed then LandFlight(name, f, elapsed, base, onField, dcsUnit, i == 1) end
    end
end

-- ATTERRISSAGE HORS AEROPORT (13/11) : points du vol divises par OFFFIELD_DIVISOR si pose ni sur une base
-- (aeroport, FARP, navire : Place de DCS), ni sur une piste, ni a moins de LAND_FIELD_M du centre d'une base.
OFFFIELD_DIVISOR = 2
LAND_FIELD_M = 3000

-- Renvoie le nom du lieu (base la plus proche) et true si le poser compte comme sur un aeroport
function LandPlace(dcsUnit, place)
    if place and place.isExist and place:isExist() then return place:getName(), true end
    local p = dcsUnit:getPoint()
    local best, bestD
    for _, ab in ipairs(world.getAirbases() or {}) do
        local q = ab:getPoint()
        local d = math.sqrt((q.x - p.x) ^ 2 + (q.z - p.z) ^ 2)
        if not bestD or d < bestD then best, bestD = ab:getName(), d end
    end
    local runway = land.getSurfaceType({ x = p.x, y = p.z }) == land.SurfaceType.RUNWAY
    return best or "terrain", runway or (bestD ~= nil and bestD < LAND_FIELD_M)
end

-- Atterrissage d'un membre de l'equipage (sound : son joue une seule fois par avion)
function LandFlight(playerName, f, elapsed, base, onField, dcsUnit, sound)
    local unitID = dcsUnit:getID()
    local s = InitPlayer(playerName)
    local carrier = CARRIERS[base]
    local function Sound(file) if sound then trigger.action.outSoundForUnit(unitID, file) end end

    -- Base terrestre : on valide tout de suite
    if not carrier then
        CommitFlightKills(playerName, f, elapsed, not onField and OFFFIELD_DIVISOR or nil)
        s.landings = s.landings + 1
        SaveScores()
        MessageToPlayer(unitID, (onField and ("Bienvenue a " .. base) or ("Pose hors aeroport (pres de " .. base .. ")")) ..
            ", " .. playerName ..
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
LastImpact = {} -- pilote -> { point = impact estime de sa derniere arme, t }
Shots = {}      -- id_ de l'arme -> { point = tireur au tir, dist = distance de la cible verrouillee au tir, t }
LastHit = {}    -- pilote -> { point = cible au dernier coup au but, t }
local SHOT_KEEP_S = 3600 -- un SLAM-ER tire a 350 km vole plus de 20 min
HIT_KEEP_S = 30         -- une cible touchee peut mettre quelques secondes a mourir

local function Distance2D(p1, p2)
    if not p1 or not p2 then return nil end
    local dx, dz = p1.x - p2.x, p1.z - p2.z
    return math.sqrt(dx * dx + dz * dz)
end

local function TrackWeapons(_, now)
    for id, shot in pairs(Shots) do
        if now - shot.t > SHOT_KEEP_S then Shots[id] = nil end
    end
    for id, data in pairs(TrackedWeapons) do
        local weapon = data.weapon
        if weapon:isExist() then
            local pos = weapon:getPosition()
            data.lastIP = land.getIP(pos.p, pos.x, IP_DISTANCE) or data.lastIP
            if Shots[weapon.id_] then Shots[weapon.id_].last = pos.p end -- remplace la cible si elle a disparu d'un seul coup
        else
            if data.lastIP then
                LastImpact[data.shooterName] = { point = data.lastIP, t = now }
            end
            TrackedWeapons[id] = nil
        end
    end
    return now + TRACK_INTERVAL
end

timer.scheduleFunction(TrackWeapons, nil, timer.getTime() + TRACK_INTERVAL)

WeaponTrackerHandler = {}

function WeaponTrackerHandler:onEvent(event)
    if event.id ~= world.event.S_EVENT_SHOT and event.id ~= world.event.S_EVENT_HIT then return end
    if not event.initiator or not event.initiator.getPlayerName or not event.initiator:isExist() then return end

    local shooterName = event.initiator:getPlayerName()
    if not shooterName then return end -- les tirs IA ne sont plus suivis

    if event.id == world.event.S_EVENT_HIT then
        local target = event.target
        if target and target.getPoint and target:isExist() then
            LastHit[shooterName] = { point = target:getPoint(), t = timer.getTime() }
        end
        return
    end
    if not event.weapon then return end

    local launch = event.initiator:getPoint()
    local locked = event.weapon.getTarget and event.weapon:getTarget()
    Shots[event.weapon.id_] = { point = launch, t = timer.getTime(),
        dist = locked and locked:isExist() and Distance2D(launch, locked:getPoint()) or nil }

    TrackedWeapons[tostring(event.weapon)] = {
        weapon = event.weapon,
        shooterName = shooterName,
    }
end

world.addEventHandler(WeaponTrackerHandler)

------------------------------------------------------------
-- KILLS
------------------------------------------------------------
local function GetTargetPoint(EventData)
    for _, obj in ipairs({ EventData.TgtDCSUnit, EventData.TgtDCSObject }) do
        if obj and obj.isExist and obj:isExist() then return obj:getPoint() end
    end
    if EventData.TgtObject and EventData.TgtObject.GetPointVec3 then
        local p = EventData.TgtObject:GetPointVec3()
        if p then return { x = p.x, y = p.y, z = p.z } end
    end
    -- cible deja disparue au moment du kill : sa position au dernier coup au but du tireur
    local hit = EventData.IniPlayerName and LastHit[EventData.IniPlayerName]
    if hit and timer.getTime() - hit.t <= HIT_KEEP_S then return hit.point end
    return nil
end

local function IsAirDefence(typeName)
    for _, keyword in ipairs(AIR_DEFENCE_KEYWORDS) do
        if string.find(typeName, keyword, 1, true) then return true end
    end
    return false
end

-- Cibles strike (08/11) : valent plus que le decor (1 pt). Cercle repris d'un dessin F10 de la mission
-- (le script ne voit pas les dessins) : a mettre a jour si le dessin bouge. x = nord, z = est (y editeur).
local STRIKE_TYPES = { ["Oil rig"] = 5, ["Gas platform"] = 5, -- derricks et plateforme de Petrol Strike
    [".Ammunition depot"] = 5, [".Command Center"] = 5, ["Tank 2"] = 5 }
for _, parked in ipairs({ "IL-78M", "Tu-22M3", "Su-34", "Su-33", "MiG-29A", "Tu-160", "Tu-95MS", "Su-24M", "Su-24MR", "Su-25T", "Su-25",
    "A-20G", "Tu-142", "Yak-52", "La-7", "An-30M", "Mi-8MT" }) do
    STRIKE_TYPES[parked] = 2 -- avions parques de la mission (statiques)
end
local STRIKE_ZONES = {
    { x = -33689, z = 587156, r = 969, pts = 2 }, -- cercle a 27 objets (depot de munitions, PC, pompes...)
}

local function StaticPoints(EventData)
    local pts = STRIKE_TYPES[EventData.TgtTypeName or ""]
    if pts then return pts end
    local p = GetTargetPoint(EventData)
    for _, z in ipairs(STRIKE_ZONES) do
        local d = Distance2D(p, z)
        if d and d <= z.r then return z.pts end
    end
    return POINTS.STATIC
end

-- Renvoie : categorie de kill, points, titre, type affiche
local function ClassifyKill(EventData)
    if EventData.TgtObjectCategory == Object.Category.STATIC then
        return "airsol", StaticPoints(EventData), "GROUND KILL CONFIRMED", nil
    end
    if EventData.TgtObjectCategory ~= Object.Category.UNIT or not EventData.TgtCategory then return nil end

    local cat = EventData.TgtCategory
    if cat == Unit.Category.AIRPLANE then
        return "airair", POINTS.AIRPLANE, "AIR KILL CONFIRMED", "AVION"
    elseif cat == Unit.Category.HELICOPTER then
        return "airair", POINTS.HELICOPTER, "AIR KILL CONFIRMED", "HELICO"
    elseif cat == Unit.Category.SHIP then
        return "airmer", POINTS.SHIP, "SEA KILL CONFIRMED", nil
    end
    local typeName = string.lower(EventData.TgtTypeName or "")
    -- trains (13/11) : DCS n'a pas de categorie d'unite train, on les reconnait aussi par leur groupe
    local dcsTgt = EventData.TgtDCSUnit
    local ok, train = pcall(function() return dcsTgt:getGroup():getCategory() == Group.Category.TRAIN end)
    if cat == Unit.Category.GROUND_UNIT or cat == Unit.Category.STRUCTURE or (ok and train) then
        if typeName:find("locomotive") or typeName == "es44ah" or typeName == "drg_class_86" then
            return "airsol", POINTS.LOCOMOTIVE, "LOCOMOTIVE DESTROYED", typeName
        end
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

    OpCredit(EventData, crew) -- avant CapKill (le 5e avion doit compter dans les parts) et meme pour une cible sans points
    local kind, points, title, typeLabel = ClassifyKill(EventData)
    if not kind then return end
    -- avion a intercepter abattu sans autorisation par un membre de la mission : 0 pt (IcptKillAllowed plus bas)
    if not IcptKillAllowed(EventData, playerName) then return end
    CapKill(EventData, playerName)

    local targetPoint = GetTargetPoint(EventData)
    local shooterPoint = EventData.IniDCSUnit:isExist() and EventData.IniDCSUnit:getPoint() or nil
    -- distance pour les records : au moment du tir pour une arme suivie, sinon (canon) au moment du kill ; au moins 1 m (0 = pas de record)
    local shot = type(EventData.weapon) == "table" and Shots[EventData.weapon.id_]
    local killDist = shot and (shot.dist or Distance2D(shot.point, targetPoint or shot.last)) or Distance2D(shooterPoint, targetPoint)
    killDist = killDist and math.max(1, math.floor(killDist))
    env.info(string.format("BlueSky kill : %s, %s, arme %s, distance %s, cible localisee %s, tir suivi %s", playerName, kind,
        tostring(EventData.WeaponName), tostring(killDist), tostring(targetPoint ~= nil), tostring(shot and true or false)))

    -- En vol : en attente jusqu'a l'atterrissage. Au sol : valide direct. Chaque membre d'equipage a le kill entier.
    local f, pending
    for i, name in ipairs(crew) do
        local fc = Flights[name]
        local pend = fc and fc.active
        if not pend then fc = NewFlight() end
        fc[kind] = fc[kind] + 1
        fc.points = fc.points + points
        if killDist then
            local far, near = "killFar", "killNear"
            if kind ~= "airair" then far, near = "killFarAS", "killNearAS" end
            fc[far] = math.max(fc[far] or 0, killDist)
            if (fc[near] or 0) == 0 or killDist < fc[near] then fc[near] = killDist end
        end
        if not pend then
            CommitFlightKills(name, fc)
            SaveScores()
        end
        if i == 1 then f, pending = fc, pend end
    end

    -- Petit delai pour laisser le tracker enregistrer l'impact
    timer.scheduleFunction(function()
        -- Impact recent uniquement, et jamais a la place de la cible : un impact d'une autre passe donnait
        -- "impact-cible 0 m" et une distance avion-cible de plusieurs centaines de km
        local last = LastImpact[playerName]
        local impactDist = last and timer.getTime() - last.t <= HIT_KEEP_S and Distance2D(last.point, targetPoint) or nil
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
            (impactDist and ("\nDistance impact-cible : " .. FormatDistance(impactDist)) or "") ..
            (killDist and ("\nDistance de tir : " .. FormatDistance(killDist)) or ""), -- la valeur des records
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
            env.info("BlueSky : mode Blue Sky active par " .. name)
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

-- DEBUG (13/11) : atterrissage non detecte par DCS -> le joueur le fait revalider au sol, presque arrete.
-- Un vol encore actif au sol = Land manque (sinon CloseFlight l'aurait deja ferme).
LAND_CHECK_MAX_MPS = 3 -- ~10 km/h
PlayerDebugMenus = PlayerDebugMenus or {}

function DebugRevalidateLanding(GroupObject)
    ForEachGroupPlayer(GroupObject, function(id, name, u)
        local f = Flights[name]
        if not (f and f.active) then
            MessageToPlayer(id, "DEBUG : aucun vol en cours a valider (" .. name .. ").", 8)
            return
        end
        local v = u:getVelocity()
        local speed = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
        if u:inAir() or speed > LAND_CHECK_MAX_MPS then
            MessageToPlayer(id, "DEBUG : refuse, il faut etre pose et quasi arrete (moins de " ..
                math.floor(LAND_CHECK_MAX_MPS * 3.6) .. " km/h).", 8)
            return
        end
        local base, onField = LandPlace(u)
        local elapsed, fl = CloseFlight(name)
        env.info("BlueSky DEBUG : atterrissage revalide pour " .. name .. " a " .. base)
        if elapsed then LandFlight(name, fl, elapsed, base, onField, u, name == u:getPlayerName()) end
    end)
end

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

    local dbg = MENU_GROUP:New(GroupObject, "DEBUG")
    MENU_GROUP_COMMAND:New(GroupObject, "Revalider l'atterrissage", dbg, DebugRevalidateLanding, GroupObject)

    PlayerScoreMenus[groupName] = root
    PlayerBSMenus[groupName] = bs
    PlayerDebugMenus[groupName] = dbg
    AddMissionMenusForGroup(GroupObject, groupName)
end

------------------------------------------------------------
-- SPAWNS
-- Un seul objet SPAWN par template (reutilise a chaque appel) :
-- evite que MOOSE reprenne les memes noms de groupe (#001) a chaque spawn.
------------------------------------------------------------
local Spawners = {}

-- zone : ZONE MOOSE ou le groupe apparait au hasard (nil = position de l'editeur)
local function GetSpawner(template, zone)
    local sp = Spawners[template]
    if not sp then
        sp = SPAWN:New(template)
        if zone then
            sp:InitRandomizeZones({ zone })
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
DestroyWatch = {} -- groupes HOST A/A + zone CAP : detruits s'ils entrent dans une zone "Destroy cap" (13/11)

local function SpawnHostile(template)
    -- ZONE:New sur une zone quad = cercle de 3 km au centre (comportement d'origine, garde tel quel)
    local group = GetSpawner(template, ZONE:New("Spawn Air")):Spawn()
    if group then
        HostileGroups[#HostileGroups + 1] = group
        DestroyWatch[#DestroyWatch + 1] = group
    end
end

-- Detruit TOUS les hostiles spawnes (l'original ne detruisait que le dernier de chaque)
function Clear()
    DestroyAll(HostileGroups)
    HostileGroups = {}
end

-- TANKERS
local TANKERS = {
    { label = "S3-B",        template = "S3B" },
    { label = "A-6",         template = "A6" }, -- 14/11 : ajoute par Thibaud dans l'editeur (Phoenix 1-1)
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

-- Reset facon "Zone Alpha" de Weefe (14/11) : tout retirer, nettoyer epaves/crateres, puis respawn aux positions ME.
local CROIX_JUNK_MARGIN = 500 -- m ajoutes autour des templates pour le nettoyage
local CroixBusy = false
local CroixJunkVolume = nil

-- Pas de zone a dessiner dans l'editeur : cercle calcule sur les statics, les chars et leurs waypoints
local function GetCroixJunkVolume()
    if CroixJunkVolume then return CroixJunkVolume end
    local pts = {}
    for i = 1, CROIX_STATIC_COUNT do
        local t = _DATABASE:GetStaticUnitTemplate("s-croix-" .. i)
        if t then pts[#pts + 1] = { x = t.x, y = t.y } end
    end
    for i = 1, CROIX_GROUP_COUNT do
        local g = _DATABASE:GetGroupTemplate("croix-" .. i)
        if g then
            for _, u in ipairs(g.units or {}) do pts[#pts + 1] = { x = u.x, y = u.y } end
            for _, p in ipairs((g.route and g.route.points) or {}) do pts[#pts + 1] = { x = p.x, y = p.y } end
        end
    end
    if #pts == 0 then return nil end
    local cx, cy = 0, 0
    for _, p in ipairs(pts) do cx, cy = cx + p.x, cy + p.y end
    cx, cy = cx / #pts, cy / #pts
    local r = 0
    for _, p in ipairs(pts) do r = math.max(r, math.sqrt((p.x - cx) ^ 2 + (p.y - cy) ^ 2)) end
    CroixJunkVolume = {
        id = world.VolumeType.SPHERE,
        params = { point = { x = cx, y = land.getHeight({ x = cx, y = cy }), z = cy }, radius = r + CROIX_JUNK_MARGIN },
    }
    env.info(string.format("[CROIX] zone de nettoyage : rayon %d m", r + CROIX_JUNK_MARGIN))
    return CroixJunkVolume
end

function Croix()
    if CroixBusy then
        trigger.action.outTextForCoalition(coalition.side.BLUE, "Croix : reset deja en cours.", 5)
        return
    end
    CroixBusy = true
    trigger.action.outTextForCoalition(coalition.side.BLUE, "Croix : nettoyage et reconstruction en cours...", 8)

    -- 1. retirer les survivants (spawns precedents + statics d'origine de l'editeur)
    DestroyAll(CroixStatics)
    DestroyAll(CroixGroups)
    CroixStatics, CroixGroups = {}, {}
    for i = 1, CROIX_STATIC_COUNT do
        local s = StaticObject.getByName("s-croix-" .. i)
        if s and s:isExist() then s:destroy() end
    end

    -- 2. apres 1 s : epaves, crateres, debris de la zone
    timer.scheduleFunction(function()
        local ok, err = pcall(function()
            local vol = GetCroixJunkVolume()
            if vol then env.info("[CROIX] junk retire : " .. tostring(world.removeJunk(vol))) end
        end)
        if not ok then env.info("[CROIX] ERREUR nettoyage : " .. tostring(err)) end

        -- 3. apres 2 s de plus : respawn aux positions et routes de l'editeur
        timer.scheduleFunction(function()
            local ok2, err2 = pcall(function()
                for i = 1, CROIX_GROUP_COUNT do
                    CroixGroups[#CroixGroups + 1] = GetSpawner("croix-" .. i):Spawn()
                end
                for i = 1, CROIX_STATIC_COUNT do
                    CroixStatics[#CroixStatics + 1] = CroixStaticSpawners[i]:Spawn()
                end
            end)
            CroixBusy = false
            if not ok2 then env.info("[CROIX] ERREUR respawn : " .. tostring(err2)) end
            trigger.action.outTextForCoalition(coalition.side.BLUE, string.format(
                "Croix : %d/%d groupes, %d/%d statics recrees.",
                #CroixGroups, CROIX_GROUP_COUNT, #CroixStatics, CROIX_STATIC_COUNT), 12)
        end, nil, timer.getTime() + 2)
    end, nil, timer.getTime() + 1)
end

-- AIR-SOL : Convoi aleatoire
local CONVOIS = { "conv-1", "conv-2", "conv-3", "conv-4", "conv-5", "conv-6", "conv-7", "conv-8" }

function Convoi()
    GetSpawner(CONVOIS[math.random(#CONVOIS)]):Spawn()
end

------------------------------------------------------------
-- FRONT RUSSE : RENFORTS AU PREMIER KILL
-- Premier vehicule / batiment / bateau detruit a moins de BASE_RADIUS du centre d'une base :
-- ses groupes (en activation retardee dans l'editeur) sont actives, une seule fois par mission.
-- Pour un nouveau convoi : ajouter son nom dans "groups" (ou une nouvelle base, x = nord, y = est de l'editeur).
------------------------------------------------------------
local BASE_RADIUS = 8000 -- m

local BASES = {
    -- "sukumi convoie" : contre-attaque russe partie de Gudauta vers Soukhoumi (11/11 : avant, au premier kill a Soukhoumi)
    { name = "Gudauta",   x = -196500, y = 516500, groups = { "Gudauta convoie", "KA 50 gudauta", "sukumi convoie" } },
    { name = "Sochi",     x = -164000, y = 462000, groups = { "sochi convoie", "hélico sochi convoie", "helico sochi" } },
    { name = "Anapa",     x = -5000,   y = 243500, groups = { "hélico anapa" } },
}

local function IsGroundTarget(obj)
    local cat = Object.getCategory(obj)
    if cat == Object.Category.STATIC then return true end
    if cat ~= Object.Category.UNIT then return false end
    local unitCat = obj:getDesc().category
    return unitCat == Unit.Category.GROUND_UNIT or unitCat == Unit.Category.SHIP
end

function OnGroundTargetKilled(obj)
    if not IsGroundTarget(obj) then return end
    local p = obj:getPoint()
    for _, base in ipairs(BASES) do
        local dx, dz = p.x - base.x, p.z - base.y
        if not base.done and dx * dx + dz * dz < BASE_RADIUS * BASE_RADIUS then
            base.done = true
            for _, name in ipairs(base.groups) do
                local g = Group.getByName(name)
                if g then g:activate() else env.warning("BLUESKY : renfort introuvable : " .. name) end
            end
            env.info("BLUESKY : premier kill a " .. base.name .. ", renforts actives")
            -- les convois en route apparaissent dans F10 > MISSIONS > CONVOIS (2 s : laisser l'activation se faire)
            timer.scheduleFunction(function() RefreshMissionMenus() end, nil, timer.getTime() + 2)
        end
    end
end

BaseHandler = {}

function BaseHandler:onEvent(event)
    local obj
    if event.id == world.event.S_EVENT_KILL then obj = event.target
    elseif event.id == world.event.S_EVENT_DEAD or event.id == world.event.S_EVENT_UNIT_LOST then obj = event.initiator end
    if not obj then return end
    local ok, err = pcall(OnGroundTargetKilled, obj)
    if not ok then env.warning("BLUESKY : renforts : " .. tostring(err)) end
end

world.addEventHandler(BaseHandler)

------------------------------------------------------------
-- FRONT RUSSE : SPAWN ENI (menu F10 SPAWN > Spawn ENI)
-- Active : un groupe tire au sort apparait n'importe ou dans la zone "Spawn ENI", puis suit sa route de l'editeur.
-- Vague suivante seulement quand chaque avion de la vague est detruit, pose, a court de carburant ou sans armement
-- (canon seul = sans armement). Bombardiers : toujours avec leur escorte.
-- Les avions spawnes sont aussi effaces par "Clear hostile".
------------------------------------------------------------
local ENI_WAVES = {
    { "mig29s" }, { "mig21" }, { "su33" }, { "jf17" }, { "su27" },
    { "su34" }, { "su25" }, { "l39" },
    { "tu95", "escorte 95" }, { "tu160", "escorte 160" },
}
local ENI_FUEL_MIN = 0.15  -- part de carburant sous laquelle l'avion compte comme "a court"
local ENI_MAX_WAVE_S = 3600 -- shortcut: vague consideree finie apres 1 h (avion IA coince en l'air), a revoir si des vagues sont coupees trop tot
local ENI_ENGAGE_M = 60000  -- distance max entre la route de l'avion et une cible qu'il peut aller chercher

-- La tache CAP auto de l'editeur (EngageTargets) n'a pas de limite : l'IA part sur n'importe quel bleu vu par l'A-50
-- (constate le 07/11 : MiG-29 partis droit vers la zone BVR). On borne le modele MOOSE, copie a chaque spawn.
local function LimitEngage(name)
    local t = _DATABASE.Templates.Groups[name]
    for _, wp in ipairs(t and t.Template.route.points or {}) do
        for _, task in ipairs(wp.task and wp.task.params and wp.task.params.tasks or {}) do
            if task.id == "EngageTargets" then
                task.params.maxDist = ENI_ENGAGE_M
                task.params.maxDistEnabled = true
            end
        end
    end
end

EniActive = false
EniWave = nil -- { groups = { GROUP... }, t0 = temps du spawn }

local function UnitSpent(u)
    if not u:isExist() or u:getLife() < 1 or not u:inAir() or u:getFuel() < ENI_FUEL_MIN then return true end
    for _, a in ipairs(u:getAmmo() or {}) do
        if a.count > 0 and a.desc.category ~= Weapon.Category.SHELL then return false end
    end
    return true
end

function EniWaveOver(wave)
    if timer.getTime() - wave.t0 > ENI_MAX_WAVE_S then return true end
    for _, g in ipairs(wave.groups) do
        for _, u in ipairs(GroupDCSUnits(g)) do
            if not UnitSpent(u) then return false end
        end
    end
    return true
end

local function SpawnEniWave()
    local wave = ENI_WAVES[math.random(#ENI_WAVES)]
    local lead = GetSpawner(wave[1], ZONE:FindByName("Spawn ENI")):Spawn()
    if not lead then return end
    local groups = { lead }
    local p = lead:GetVec3() or {}
    for i = 2, p.x and #wave or 1 do -- position inconnue : pas d'escorte plutot qu'une erreur
        -- escorte : a cote du bombardier ; sa tache "suivre" de l'editeur visait le modele, on la refait sur le groupe spawne
        local esc = GetSpawner(wave[i]):SpawnFromVec3({ x = p.x - 300, y = p.y, z = p.z + 300 * (i - 1) })
        if esc then
            esc:SetTask(esc:TaskEscort(lead, { x = -150, y = 0, z = 150 * (i - 1) }, nil, 40000, { "Air" }), 1)
            groups[#groups + 1] = esc
        end
    end
    for _, g in ipairs(groups) do HostileGroups[#HostileGroups + 1] = g end
    EniWave = { groups = groups, t0 = timer.getTime() }
    env.info("BLUESKY : Spawn ENI : " .. table.concat(wave, " + "))
end

local function EniTick()
    if EniWave and not EniWaveOver(EniWave) then return end
    EniWave = nil
    if EniActive then SpawnEniWave() end
end

timer.scheduleFunction(function()
    local ok, err = pcall(EniTick)
    if not ok then env.warning("BLUESKY : Spawn ENI : " .. tostring(err)) end
    return timer.getTime() + 30
end, nil, timer.getTime() + 30)

function SetEniSpawn(on)
    EniActive = on
    MESSAGE:New(on and "SPAWN ENI ACTIVE" or "SPAWN ENI DESACTIVE", 10):ToCoalition(coalition.side.BLUE)
end

-- Noms de l'editeur a verifier dans dcs.log si un renfort ou une vague ne part pas
for _, base in ipairs(BASES) do
    for _, name in ipairs(base.groups) do
        if not Group.getByName(name) then env.warning("BLUESKY : groupe absent de la mission : " .. name) end
    end
end
for _, wave in ipairs(ENI_WAVES) do
    for _, name in ipairs(wave) do
        if not Group.getByName(name) then env.warning("BLUESKY : groupe absent de la mission : " .. name) end
        LimitEngage(name)
    end
end

------------------------------------------------------------
-- MISSIONS A CODE (10/11) : qui lance une mission recoit un code, ses equipiers le composent dans F10 > CODE.
-- Messages et bonus reserves aux membres. Le menu F10 de groupe ne dit pas qui a clique : le clic vaut pour tout le groupe.
------------------------------------------------------------
local OP_CODE_LEN = 2  -- chiffres 1 a 9 (11 a 99) : F10 > CODE > 1er chiffre (sous-menu) > 2e chiffre (rejoint)

Ops = {}       -- missions en cours par nom : { label, code, brief, members = { pilote = true } }

local function GroupMsg(group, text, t) MESSAGE:New(text, t or 10):ToGroup(group) end

-- Unites bleues ou se trouve au moins un membre (equipage compris)
local function MemberUnits(op)
    local list = {}
    for _, u in ipairs(coalition.getPlayers(coalition.side.BLUE) or {}) do
        if u:isExist() then
            for _, name in ipairs(Crew(u:getName(), u:getPlayerName())) do
                if op.members[name] then list[#list + 1] = u break end
            end
        end
    end
    return list
end

local function OpMsg(op, text, t)
    for _, u in ipairs(MemberUnits(op)) do MessageToPlayer(u:getID(), text, t or 15) end
end

-- Voix radio (10/11) : .ogg de la .miz et duree en s, numeros = liste des calls. Sources et reglages : dossier voix-ia.
local VOIX = {
    c01 = { "c01_scramble_tu95.ogg", 6.6 },
    c02 = { "c02_chasseur_rf59_1.ogg", 8.1 },
    c03 = { "c03_rf59_mensonge.ogg", 6.0 },
    c04 = { "c04_chasseur_rf59_2.ogg", 6.6 },
    c05 = { "c05_rf59_demitour.ogg", 4.8 },
    c06 = { "c06_escortez_frontiere.ogg", 4.2 },
    c07 = { "c07_rf59_rentre.ogg", 5.7 },
    c08 = { "c08_rf59_refus.ogg", 5.8 },
    c09 = { "c09_rf59_virage.ogg", 3.6 },
    c10 = { "c10_tir_su27_abattu.ogg", 5.3 },
    c11 = { "c11_missiles_tbilissi.ogg", 6.9 },
    c12 = { "c12_scramble_su34.ogg", 10.4 },
    c13 = { "c13_frontiere_franchie.ogg", 8.5 },
    c14 = { "c14_chasseur_vvs_1.ogg", 7.8 },
    c15 = { "c15_vvs_recu.ogg", 5.5 },
    c16 = { "c16_restez_zone.ogg", 4.0 },
    c17 = { "c17_deuxieme_sortie.ogg", 5.9 },
    c18 = { "c18_chasseur_vvs_2.ogg", 7.7 },
    c19 = { "c19_vvs_base.ogg", 4.2 },
    c20 = { "c20_accompagnez.ogg", 3.9 },
    c21 = { "c21_vvs_rentre.ogg", 5.9 },
    c22 = { "c22_largage.ogg", 5.2 },
    c23 = { "c23_fuite.ogg", 6.5 },
    c24 = { "c24_vengeance.ogg", 4.8 },
    c25 = { "c25_rompt_combat.ogg", 3.4 },
    c26 = { "c26_petrol_brief.ogg", 7.8 },
    c27 = { "c27_petrol_ok.ogg", 4.1 },
    c28 = { "c28_naval_brief.ogg", 7.7 },
    c29 = { "c29_naval_ok.ogg", 4.4 },
    c30 = { "c30_cap_brief.ogg", 5.2 },
    c31 = { "c31_cap_ok.ogg", 4.9 },
    -- 12/11 : bases, convois, Factory (radio plus forte)
    c32 = { "c32_gudauta_brief.ogg", 7.3 },
    c33 = { "c33_gudauta_tombee.ogg", 5.2 },
    c34 = { "c34_sochi_brief.ogg", 6.1 },
    c35 = { "c35_sochi_tombee.ogg", 4.4 },
    c36 = { "c36_anapa_brief.ogg", 5.9 },
    c37 = { "c37_anapa_victoire.ogg", 4.1 },
    c38 = { "c38_convoi_gudauta.ogg", 6.1 },
    c39 = { "c39_convoi_sochi.ogg", 5.8 },
    c40 = { "c40_convoi_soukhoumi.ogg", 4.4 },
    c41 = { "c41_convoi_nord.ogg", 5.6 },
    c42 = { "c42_convoi_ok.ogg", 2.9 },
    c43 = { "c43_factory_brief.ogg", 8.3 },
    c44 = { "c44_factory_ok.ogg", 3.8 },
}

-- Joue une voix ou une liste de voix a la suite (DCS superpose deux sons lances ensemble), aux membres presents a ce moment-la
local function OpVoice(op, voice)
    if not voice then return end
    local at = timer.getTime() + 0.5
    for _, key in ipairs(type(voice) == "table" and voice or { voice }) do
        local v = VOIX[key]
        timer.scheduleFunction(function()
            for _, u in ipairs(MemberUnits(op)) do trigger.action.outSoundForUnit(u:getID(), v[1]) end
        end, nil, at)
        at = at + v[2] + 0.5
    end
end

-- Annonce a tout le serveur (base tombee)
local function VoiceAll(key)
    local v = key and VOIX[key]
    if v then timer.scheduleFunction(function() trigger.action.outSound(v[1]) end, nil, timer.getTime() + 0.5) end
end

-- Anti-triche : retient les membres venus sur zone, seuls eux auront le bonus (pas de tir de tres loin, pas de points sur le dos des autres)
local function OpMarkPresent(op, inZone)
    for _, u in ipairs(MemberUnits(op)) do
        if inZone(u:getPoint()) then
            for _, name in ipairs(Crew(u:getName(), u:getPlayerName())) do
                if op.members[name] and not op.present[name] then
                    op.present[name] = true
                    MessageToPlayer(u:getID(), "MISSION " .. op.label .. " : presence sur zone validee (" .. name .. ").", 8)
                end
            end
        end
    end
end

local function OpBrief(op)
    return "=== MISSION " .. op.label .. " ===\n\n" .. op.brief .. "\n\nCODE DE LA MISSION : " .. op.code ..
           (op.public and "\nTous les pilotes peuvent la rejoindre : composez ce code dans F10 > CODE."
                       or "\nTes equipiers le composent dans F10 > CODE pour te rejoindre.") ..
           (op.prorata and "\nBonus partage selon les cibles detruites par chacun : qui ne detruit rien ne touche rien." or
            op.noZone and "" or "\nBonus : il faut venir au moins une fois sur zone (message de confirmation).") ..
           "\nRappel : F10 > MISSIONS > Rappel de mes missions"
end

local function NewCode()
    while true do
        local code, used = "", false
        for _ = 1, OP_CODE_LEN do code = code .. math.random(9) end
        for _, op in pairs(Ops) do used = used or op.code == code end
        if not used then return code end
    end
end

-- prorata : bonus partage selon les kills de cibles (OpCredit), sans condition de presence
-- public : briefing et code envoyes a tous les pilotes du serveur (interceptions, 11/11), sinon au groupe du lanceur
local function OpStart(label, brief, group, noZone, prorata, public)
    local op = { label = label, brief = brief, code = NewCode(), members = {}, present = {}, noZone = noZone,
                 prorata = prorata, credit = {}, public = public }
    Ops[label] = op
    ForEachGroupPlayer(group, function(_, name) op.members[name] = true end)
    if public then MESSAGE:New(OpBrief(op), 30):ToAll() else GroupMsg(group, OpBrief(op), 30) end
    return op
end

local function OpHasGroup(op, group)
    local found = false
    ForEachGroupPlayer(group, function(_, name) found = found or op.members[name] end)
    return found
end

local function OpJoin(op, group)
    local names = {}
    ForEachGroupPlayer(group, function(_, name)
        if not op.members[name] then names[#names + 1] = name end
    end)
    if #names == 0 then GroupMsg(group, "Tu es deja dans la mission " .. op.label .. ".", 8) return end
    OpMsg(op, table.concat(names, ", ") .. " a rejoint la mission " .. op.label .. ".", 10)
    for _, name in ipairs(names) do op.members[name] = true end
    GroupMsg(group, "MISSION REJOINTE\n\n" .. OpBrief(op), 30)
end

function CodeJoin(group, code)
    if not group or not group:IsAlive() then return end
    for _, op in pairs(Ops) do
        if op.code == code then OpJoin(op, group) return end
    end
    GroupMsg(group, "CODE " .. code .. " INCONNU ou mission terminee.", 8)
end

function OpRecall(group)
    if not group or not group:IsAlive() then return end
    local lines = {}
    for _, op in pairs(Ops) do
        if OpHasGroup(op, group) then lines[#lines + 1] = OpBrief(op) end
    end
    GroupMsg(group, #lines > 0 and table.concat(lines, "\n\n") or
        "Aucune mission en cours.\nLancer : F10 > MISSIONS. Rejoindre : F10 > CODE.", 30)
end

-- Points hors kill : en attente si le joueur vole (comme un kill), sinon valides tout de suite
local function AwardPoints(name, pts)
    local f = Flights[name]
    if f and f.active then f.points = f.points + pts return end
    f = NewFlight()
    f.points = pts
    CommitFlightKills(name, f)
end

-- Bonus egal a chaque membre en vie et venu sur zone (mort ou slot quitte : le vol est perdu, comme ses kills). Renvoie la ligne a afficher.
-- Appele par le KillHandler : chaque membre d'equipage qui detruit une cible d'une mission au prorata gagne une part
function OpCredit(EventData, crew)
    local unitName, groupName = EventData.TgtUnitName or EventData.TgtDCSUnitName, EventData.TgtGroupName
    for _, op in pairs(Ops) do
        if op.prorata and op.isTarget and op.isTarget(unitName, groupName) then
            for _, name in ipairs(crew) do
                if op.members[name] then op.credit[name] = (op.credit[name] or 0) + 1 end
            end
        end
    end
end

-- Prorata (11/11) : cagnotte = bonus x membres ayant detruit au moins une cible, partagee selon la part de chacun dans
-- les kills des membres (kills de non-membres ou d'avant le lancement : hors calcul). Mort ou slot quitte : sa part est perdue.
-- Aucun kill credite (cible sans evenement Kill, ex. derrick) : bonus egal a chaque membre vivant, comme avant.
local function OpRewardShare(op, bonus)
    local total, shooters = 0, 0
    for name, n in pairs(op.credit) do
        if op.members[name] then total, shooters = total + n, shooters + 1 end
    end
    if total == 0 then return nil end
    local names, paid, none = {}, {}, {}
    for name in pairs(op.members) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local n = op.credit[name] or 0
        if n == 0 then
            none[#none + 1] = name
        elseif not (PlayerLife[name] and PlayerLife[name].dead) then
            local pts = math.floor(bonus * shooters * n / total + 0.5)
            AwardPoints(name, pts)
            paid[#paid + 1] = name .. " +" .. pts .. " pts (" .. math.floor(100 * n / total + 0.5) .. " %)"
        end
    end
    SaveScores()
    return (#paid > 0 and ("Bonus partage : " .. table.concat(paid, ", ") .. " (valides a l'atterrissage).") or "Aucun bonus.") ..
           (#none > 0 and ("\nAucune cible detruite, pas de bonus : " .. table.concat(none, ", ")) or "")
end

local function OpReward(op, bonus)
    if op.prorata then
        local text = OpRewardShare(op, bonus)
        if text then return text end
    end
    local paid, absent = {}, {}
    for name in pairs(op.members) do
        if not (PlayerLife[name] and PlayerLife[name].dead) then
            if op.noZone or op.prorata or op.present[name] then
                AwardPoints(name, bonus)
                paid[#paid + 1] = name
            else
                absent[#absent + 1] = name
            end
        end
    end
    SaveScores()
    return (#paid > 0 and ("+" .. bonus .. " pts pour " .. table.concat(paid, ", ") .. " (valides a l'atterrissage).") or "Aucun bonus.") ..
           (#absent > 0 and ("\nPas de bonus, jamais venu sur zone : " .. table.concat(absent, ", ")) or "")
end

------------------------------------------------------------
-- INTERCEPTION (08/11) : F10 > MISSIONS > INTERCEPTION > Lancer tire un avion de INTERCEPTS (un a la fois).
-- Appel radio : seulement les membres a moins de 1000 ft. Chaque avion a son histoire : def.call (a chaque appel),
-- def.tick (toutes les 5 s). Etats : "silent" (appels), "hostile" (tir autorise), "divert" (il rentre, points a l'arrivee).
-- Autre avion = une entree de plus dans INTERCEPTS.
------------------------------------------------------------
local ICPT_CALL_M = 305      -- 1000 ft, distance 3D joueur-avion pour que l'appel passe
local ICPT_GAP_S = 10        -- delai mini entre deux appels
local ICPT_HOME_M = 10000    -- revenu a 10 km de son point de depart = frontiere repassee
local ICPT_LOST_S = 120      -- avion mourant : delai laisse a l'evenement Kill (chute depuis le FL300) avant de clore
local ICPT_NEAR_M = 5556     -- 3 NM de l'avion : la "zone" d'une interception pour avoir droit au bonus

Icpt = nil -- interception en cours

local ICPT_LABEL = "INTERCEPTION"

local function IcptMsg(text, t, voice) if Icpt then OpMsg(Icpt.op, text, t) OpVoice(Icpt.op, voice) end end

local function Wp(x, z, alt, speed, altType)
    return { x = x, y = z, alt = alt, alt_type = altType or "BARO", speed = speed, speed_locked = true,
             type = "Turning Point", action = "Turning Point" }
end

local function LandWp(ab)
    local b = ab:getPoint()
    return { x = b.x, y = b.z, alt = b.y, alt_type = "BARO", speed = 80,
             type = "Land", action = "Landing", airdromeId = ab:getID() }
end

-- Cap vrai (degres) d'un point vers un autre : x = nord, z = est
local function Bearing(from, to)
    return math.floor(math.deg((math.atan2 or math.atan)(to.z - from.z, to.x - from.x)) + 360.5) % 360
end

local function IcptFly(points)
    Icpt.group:SetTask({ id = "Mission", params = { route = { points = points } } }, 1)
end

local function GroupUnit(group)
    local g = group and group:GetDCSObject()
    if not (g and g:isExist()) then return nil end
    for _, u in ipairs(g:getUnits()) do -- le premier vivant : le leader d'une patrouille peut etre mort, pas l'ailier
        if u:isExist() and u:getLife() >= 1 then return u end
    end
end

local function IcptUnit() return Icpt and GroupUnit(Icpt.group) end

-- L'avion n'est jamais efface : abattu il va jusqu'au sol, pose il reste sur la piste
local function IcptEnd(text, voice)
    if text then IcptMsg(text, 20, voice) end
    -- plus de Tu-95 a escorter : il rentre a Maykop
    local e = Icpt.escort and GroupUnit(Icpt.escort)
    if e then
        local q = e:getPoint()
        Icpt.escort:SetTask({ id = "Mission", params = { route = { points = {
            Wp(q.x, q.z, q.y, Icpt.def.speed), LandWp(Airbase.getByName(Icpt.def.home)) } } } }, 0)
    end
    Ops[ICPT_LABEL] = nil
    Icpt = nil
end

-- Fin reussie : def.bonus a chaque membre ; l'avion continue sa route
local function IcptSuccess(text, voice)
    IcptEnd(text .. " Interception reussie !\n" .. OpReward(Icpt.op, Icpt.def.bonus), voice)
end

-- Retour a son point de depart puis atterrissage sur def.home ; renvoie le cap a donner
local function GoHome(def, u)
    local p, s = u:getPoint(), Icpt.start
    local route = { Wp(p.x, p.z, p.y, def.speed), Wp(s.x, s.z, def.alt, def.speed) }
    local home = Airbase.getByName(def.home)
    if home then route[3] = LandWp(home) end
    IcptFly(route)
    Icpt.state = "divert"
    Icpt.dest = "border"
    return Bearing(p, s)
end

-- Largage porte par un waypoint juste devant lui : l'IA enchaine ensuite le retour (une tache seule le renvoyait a Beslan)
local function BombWp(def, u, p, t, groupAttack, weapon)
    local f = u:getPosition().x
    local bomb = Icpt.group:TaskBombing({ x = t.x, y = t.z }, groupAttack, "All", nil, nil, nil, weapon)
    local fire = Wp(p.x + f.x * 3000, p.z + f.z * 3000, p.y, def.speed)
    fire.task = { id = "ComboTask", params = { tasks = {
        { number = 1, auto = false, enabled = true, id = bomb.id, params = bomb.params } } } }
    return fire
end

---- Tu-95 : 1er appel = il ment (erreur de nav) et garde son cap ; 2e appel = ordre de demi-tour :
---- 30 % il rentre, sinon il ment (autopilote) et appelle en secret son Su-27, qui ne tire pas avant d'etre a cote :
---- la, tir autorise sur les deux. A 60 NM de Tbilissi, s'il n'a pas fait demi-tour, il tire ses Kh-555 sur l'aeroport.
local TU_HOME = 0.3
local TU_FIRE_M = 111120     -- 60 NM
local TU_TURN_M = 8000       -- annonce "autopilote regle" a cette distance de son virage (il commence a tourner vers 6 km avant le point)
local TU_SPAWN_M = 15000     -- le Su-27 apparait a cette distance derriere le Tu-95, dans son axe (08/11 : depuis l'editeur il arrivait apres le virage)
local TU_SLOW_M = 4000       -- le Su-27 fonce jusque-la, puis ralentit (vitesse du Tu-95 + 100 m/s) pour ne pas le depasser
local TU_ESCORT_M = 2000     -- il suit le Tu-95 jusqu'a 2 km, puis se met en formation (la tache Escort seule rejoint trop lentement)
local TU_JOIN_M = 1500       -- Su-27 "a cote" du Tu-95 : il ouvre le feu (a 2 km il tirait de trop loin ; a 500 et 800 m il plongeait dans le relief, 08/11)
local TU_CHASE_S = 15        -- recalcul de la poursuite (a chaque tick une fois en approche)
local TU_REJOIN_M = 20000    -- plus aucun joueur bleu a cette distance du Su-27 : combat fini, il rejoint le Tu-95
local WEAPON_CRUISE = 2097152

local function TuCall(def, u, p, name)
    Icpt.calls = Icpt.calls + 1
    if Icpt.calls == 1 then return name .. " : " .. def.calls[1] .. "\n\n" .. def.lie, def.voice.call1 end
    local hdg = Bearing(p, Icpt.start)
    local text = name .. " : " .. string.format(def.calls[2], hdg) .. "\n\n"
    if math.random() < TU_HOME then
        GoHome(def, u)
        return text .. string.format(def.homeReply, hdg), def.voice.home
    end
    Icpt.state = "escort"
    -- derriere lui et dans son axe : ni detour au depart, ni visible devant les joueurs en formation
    local f, sp = u:getPosition().x, GetSpawner(def.escort)
    sp:InitHeading(Bearing({ x = 0, z = 0 }, f))
    local esc = sp:SpawnFromVec3({ x = p.x - f.x * TU_SPAWN_M, y = p.y, z = p.z - f.z * TU_SPAWN_M })
    local e = GroupUnit(esc)
    if e then
        Icpt.escort, Icpt.escortName = esc, e:getName()
        Icpt.chaseAt = timer.getTime() + 2 -- laisse le temps au groupe d'apparaitre
        -- apres la tache de depart de l'editeur (qui peut remettre le tir libre)
        timer.scheduleFunction(function() if esc:IsAlive() then esc:OptionROEHoldFire() end end, nil, timer.getTime() + 2)
    end
    return text .. def.refuse, def.voice.refuse
end

local function TuTick(def, u, p)
    if Icpt.state == "divert" then
        if Distance2D(p, Icpt.start) < ICPT_HOME_M then IcptSuccess(def.success, def.voice.success) end
        return
    end
    if Distance2D(p, Icpt.target) <= TU_FIRE_M then
        IcptFly({ Wp(p.x, p.z, p.y, def.speed), BombWp(def, u, p, def.aim, false, WEAPON_CRUISE), Wp(Icpt.start.x, Icpt.start.z, def.alt, def.speed),
                  LandWp(Airbase.getByName(def.home)) })
        if Icpt.state == "hostile" then Icpt.escort = nil end -- deja au combat : on ne le rappelle pas
        IcptEnd(def.failed, def.voice.failed)
        return
    end
    -- virage vers Tbilissi : les joueurs doivent croire au demi-tour promis (pas d'annonce si le virage est deja passe)
    if not Icpt.turned and Distance2D(p, def.mid) < TU_TURN_M then
        Icpt.turned = true
        if Icpt.state ~= "hostile" then IcptMsg(def.turning, 15, def.voice.turning) end -- Su-27 appele ou non ; pas en plein combat
    end
    if Icpt.state == "escort" then
        local e, esc = GroupUnit(Icpt.escort), Icpt.escort
        local q = e and e:getPoint()
        local d = q and math.sqrt((q.x - p.x) ^ 2 + (q.y - p.y) ^ 2 + (q.z - p.z) ^ 2)
        if not e or d <= TU_JOIN_M then
            Icpt.state = "hostile"
            if e then esc:OptionROEWeaponFree() end
        elseif d > TU_ESCORT_M then
            if timer.getTime() >= Icpt.chaseAt then
                local near = d < TU_SLOW_M
                local v = near and def.speed + 100 or def.escortSpeed
                Icpt.chaseAt = timer.getTime() + (near and 0 or TU_CHASE_S)
                esc:SetTask({ id = "Mission", params = { route = { points = {
                    Wp(q.x, q.z, q.y, v), Wp(p.x, p.z, p.y, v) } } } }, 0)
            end
        elseif not Icpt.escorting then
            Icpt.escorting = true
            esc:SetTask(esc:TaskEscort(Icpt.group, { x = -100, y = 0, z = 100 }, nil, 40000, { "Air" }), 0)
        end
    elseif Icpt.state == "hostile" and not Icpt.rejoined then
        -- apres son kill il partait vers Mozdok en laissant le Tu-95 (08/11) ; pas de tache pendant le combat, qui marche tel quel
        local e, esc = GroupUnit(Icpt.escort), Icpt.escort
        local q, clear = e and e:getPoint(), e ~= nil
        for _, pu in ipairs(coalition.getPlayers(coalition.side.BLUE)) do
            if clear and pu:isExist() and Distance2D(pu:getPoint(), q) < TU_REJOIN_M then clear = false end
        end
        if clear then
            Icpt.rejoined = true
            esc:SetTask(esc:TaskEscort(Icpt.group, { x = -100, y = 0, z = 100 }, nil, 40000, { "Air" }), 0)
        end
    end
    -- Su-27 abattu, avant ou apres son ouverture du feu : ordre de tir, une seule fois
    if Icpt.state == "hostile" and not Icpt.fireOrder and not GroupUnit(Icpt.escort) then
        Icpt.fireOrder = true
        IcptMsg(def.escortDown, 20, def.voice.escortDown)
    end
end

-- Tu-95 abattu sans autorisation par un membre : le Su-27 attaque le tireur, sans annonce. S'il n'est pas deja en vol,
-- il apparait derriere le tireur. Il rentre a Maykop quand le tireur est mort ou a quitte son avion.
local function TuPunish(def, shooter)
    if not (shooter and shooter:isExist()) then return end
    local esc = GroupUnit(Icpt.escort) and Icpt.escort
    if not esc then
        local f, q, sp = shooter:getPosition().x, shooter:getPoint(), GetSpawner(def.escort)
        sp:InitHeading(Bearing({ x = 0, z = 0 }, f))
        esc = sp:SpawnFromVec3({ x = q.x - f.x * TU_SPAWN_M, y = q.y, z = q.z - f.z * TU_SPAWN_M })
    end
    Icpt.escort = nil -- sinon IcptEnd le renvoie a Maykop
    if not esc then return end
    local attacking = false
    timer.scheduleFunction(function()
        local e = GroupUnit(esc)
        if not e then return nil end
        if shooter:isExist() and shooter:getLife() >= 1 then
            if not attacking then
                attacking = true
                esc:OptionROEWeaponFree()
                esc:SetTask({ id = "AttackUnit", params = { unitId = shooter:getID(), groupAttack = false, expend = "All",
                                                            attackQtyLimit = false, weaponType = 1073741822 } }, 0)
            end
            return timer.getTime() + 15
        end
        local q = e:getPoint()
        esc:SetTask({ id = "Mission", params = { route = { points = {
            Wp(q.x, q.z, q.y, def.speed), LandWp(Airbase.getByName(def.home)) } } } }, 0)
        return nil
    end, nil, timer.getTime() + 2) -- laisse le temps au groupe d'apparaitre
end

---- Su-34 (2 avions) : appel possible seulement hors frontiere. 1re interception = detour par le nord et 2e sortie ;
---- 2e interception = retour a Maykop. Sans interception : largage sur Mineralnye, puis tir autorise pendant la fuite.
local SU_FIRE_M = 25000      -- a cette distance de la cible : trop tard pour intercepter, largage
local SU_DROP_S = 180        -- l'IA n'a toujours rien largue apres ce delai : on passe quand meme a la fuite
local SU_CROSS_M = 5000      -- rayon de detection du point de 2e sortie (1,2 km parcourus entre deux ticks)
local SU_FLEE_MS = 300       -- fuite apres largage (plafonne par l'IA)
local SU_HUNT_M = 100000     -- vengeance : il traque les joueurs bleus dans ce rayon, sinon il rentre

local function SuInit(def)
    Icpt.state, Icpt.pass = "inbound", 1
    local w = Icpt.group:GetDCSObject():getUnit(2)
    Icpt.escortName = w and w:getName()
end

local function SuCall(def, u, p, name)
    local pass = Icpt.pass
    local here = Wp(p.x, p.z, p.y, def.speed)
    if pass == 1 then
        Icpt.state, Icpt.pass = "detour", 2
        local route = { here }
        for _, w in ipairs(def.detour) do route[#route + 1] = Wp(w.x, w.z, def.alt, def.speed) end
        route[#route + 1] = Wp(Icpt.target.x, Icpt.target.z, def.alt, def.speed)
        IcptFly(route)
    else
        Icpt.state, Icpt.dest = "divert", "border"
        IcptFly({ here, Wp(def.west.x, def.west.z, def.alt, def.speed), LandWp(Airbase.getByName(def.home)) })
    end
    return name .. " : " .. def.calls[pass] .. "\n\n" .. def.replies[pass], def.voice[pass]
end

local function GroupAmmo(group)
    local n, g = 0, group:GetDCSObject()
    for _, unit in ipairs(g and g:getUnits() or {}) do
        for _, w in ipairs(unit:getAmmo() or {}) do n = n + w.count end
    end
    return n
end

-- L'un des deux est abattu : le survivant se venge sur le joueur bleu le plus proche
local function SuRevenge(def)
    Icpt.state = "revenge"
    Icpt.group:OptionROEWeaponFree()
    IcptMsg(def.revenge, 20, def.voice.revenge)
end

local function SuHunt(def, u, p)
    local prey = Icpt.prey
    if prey and prey:isExist() and Distance2D(prey:getPoint(), p) < SU_HUNT_M then return end
    local best = SU_HUNT_M
    prey = nil
    for _, pu in ipairs(coalition.getPlayers(coalition.side.BLUE)) do
        if pu:isExist() then
            local d = Distance2D(pu:getPoint(), p)
            if d < best then prey, best = pu, d end
        end
    end
    Icpt.prey = prey
    if prey then
        Icpt.group:SetTask({ id = "AttackUnit", params = { unitId = prey:getID(), groupAttack = false, expend = "All",
                                                            attackQtyLimit = false, weaponType = 1073741822 } }, 0)
    else
        IcptFly({ Wp(p.x, p.z, p.y, def.speed), LandWp(Airbase.getByName(def.home)) })
        IcptEnd(def.revengeOver, def.voice.revengeOver)
    end
end

local function SuTick(def, u, p)
    local s, now = Icpt.state, timer.getTime()
    if s == "revenge" then
        SuHunt(def, u, p)
    elseif s == "inbound" then
        if p.x >= def.mid.x then
            Icpt.state = "silent"
            IcptMsg(def.crossed, 20, def.voice.crossed)
        end
    elseif s == "detour" then
        if Distance2D(p, def.cross2) < SU_CROSS_M then
            Icpt.state = "silent"
            IcptMsg(def.crossedAgain, 20, def.voice.crossedAgain)
        end
    elseif s == "silent" then
        if Distance2D(p, Icpt.target) <= SU_FIRE_M then
            Icpt.state, Icpt.ammo, Icpt.fireAt = "attack", GroupAmmo(Icpt.group), now
            IcptFly({ Wp(p.x, p.z, p.y, def.speed), BombWp(def, u, p, Icpt.target, true),
                      Wp(def.egress.x, def.egress.z, def.alt, SU_FLEE_MS), Wp(def.west.x, def.west.z, def.alt, SU_FLEE_MS),
                      LandWp(Airbase.getByName(def.home)) })
        end
    elseif s == "attack" then
        if GroupAmmo(Icpt.group) < Icpt.ammo or now - Icpt.fireAt >= SU_DROP_S then
            Icpt.state = "hostile"
            IcptMsg(def.released, 20, def.voice.released)
        end
    elseif p.z < def.border then -- "divert" ou "hostile" : frontiere repassee
        if s == "divert" then IcptSuccess(def.success, def.voice.success) else IcptEnd(def.failed, def.voice.failed) end
    end
end

local INTERCEPTS = {
    {
        template = "TU95 inter", label = "Tu-95", escort = "Escorte tu95 inter", call = TuCall, tick = TuTick, punish = TuPunish,
        bonus = 10,
        -- 255 m/s = quasi sa vitesse maxi reelle (925 km/h) ; a 230 on etait bloque vers 300 kt indiques (08/11)
        speed = 255, alt = 9144, -- m/s, m (FL300)
        escortSpeed = 600, -- m/s, plafonne par l'IA a la vitesse maxi du Su-27
        mid = { x = -170000, z = 820000 }, -- longe le nord des montagnes, puis plein sud sur Tbilissi
        aim = { x = -314935, z = 896939 }, -- point d'impact des Kh-555 : parking du terminal de Tbilissi
        target = "Tbilisi-Lochini",
        home = "Maykop-Khanskaya",
        alert = "COMMANDEMENT : A tous les chasseurs, bombardier Tu-95 au nord du Caucase, FL300, cap %03d depuis %s. " ..
                "Interception et identification demandees.\n" ..
                "F10 > MISSIONS > INTERCEPTION > Appel radio (a moins de 1000 ft).",
        calls = {
            "RF-59, ici chasseur d'interception. Vous penetrez un espace aerien controle sans autorisation. " ..
                "Annoncez vos intentions. Parlez.",
            "RF-59, ici chasseur d'interception. Trajectoire non corrigee. Faites demi-tour immediatement, cap %03d, et accusez reception.",
        },
        lie = "RF-59 : Chasseur, RF-59, vol d'entrainement. Legere erreur de navigation, nous corrigeons dans quelques instants.",
        homeReply = "RF-59 : Recu, cap %03d, nous faisons demi-tour. RF-59.\n\n" ..
                    "COMMANDEMENT : Escortez le trafic jusqu'a la frontiere.",
        -- il ment : le Su-27 arrive en secret
        refuse = "RF-59 : Recu, chasseur. Anomalie autopilote en cours de traitement, nous allons modifier notre cap. RF-59.",
        turning = "RF-59 : Autopilote retabli, virage en cours.",
        escortDown = "COMMANDEMENT : TIR AUTORISE. Engagez au plus vite, l'appareil se dirige vers Tbilissi.",
        success = "COMMANDEMENT : RF-59 a repasse la frontiere.",
        failed = "COMMANDEMENT : RF-59 a lance ses missiles de croisiere sur Tbilissi. Interception ratee.",
        -- voix (VOIX) : appel du chasseur, reponse et ordre du COMMANDEMENT enchaines, puis messages seuls
        voice = { call1 = { "c02", "c03" }, home = { "c04", "c05", "c06" }, refuse = { "c04", "c08" }, alert = "c01",
                  turning = "c09", escortDown = "c10", success = "c07", failed = "c11" },
    },
    {
        template = "Su34 inter", label = "Su-34", wing = "l'ailier", init = SuInit, call = SuCall, tick = SuTick,
        bonus = 15, revengeFn = SuRevenge, -- bonus pour la 2e interception reussie ; abattu apres largage = kill normal
        speed = 231, alt = 8230, -- m/s (450 kt), m (FL270)
        target = "Mineralnye Vody",
        home = "Maykop-Khanskaya",
        -- releves sur le dessin du 08/11 (cale sur la boite BVR, precision ~2 km) ; x = nord, z = est
        mid = { x = -112848, z = 702576 }, -- franchissement de la frontiere (trajet rouge), puis droit sur Mineralnye
        detour = { { x = -45651, z = 623471 }, { x = -8262, z = 668197 }, { x = -8952, z = 729938 } }, -- trajet jaune
        cross2 = { x = -8600, z = 686614 }, -- 2e sortie, sur la branche nord du jaune
        egress = { x = -8952, z = 681352 }, -- fuite apres largage (fin du rouge)
        west = { x = -11191, z = 607684 }, -- fleche verte, vers Maykop
        border = 676967, -- a l'ouest de ce z (secteur nord) : frontiere repassee
        alert = "COMMANDEMENT : A tous les chasseurs, deux Su-34 en rapprochement de la frontiere, secteur Tyrnyauz, FL270, cap %03d depuis %s. " ..
                "Mettez-vous en position, interception uniquement s'ils franchissent la frontiere.\n" ..
                "F10 > MISSIONS > INTERCEPTION > Appel radio (a moins de 1000 ft).",
        crossed = "COMMANDEMENT : VVS 34 et VVS 35 viennent de franchir la frontiere, cap nord sur Mineralnye Vody. Interception immediate.",
        crossedAgain = "COMMANDEMENT : VVS 34 de nouveau hors frontiere, secteur nord, cap sud sur Mineralnye Vody. Interception immediate.",
        calls = {
            "VVS 34, ici chasseur d'interception. Vous penetrez un espace aerien controle. " ..
                "Faites demi-tour immediatement et accusez reception. Parlez.",
            "VVS 34, ici chasseur d'interception, deuxieme interception. Regagnez immediatement votre espace aerien. Dernier avertissement.",
        },
        replies = {
            "VVS 34 : Chasseur, VVS 34, recu. Demi-tour, nous regagnons notre espace aerien.\n\n" ..
                "COMMANDEMENT : Restez sur zone, maintenez la surveillance.",
            "VVS 34 : Recu, chasseur. Nous regagnons notre base. VVS 34.\n\n" ..
                "COMMANDEMENT : Accompagnez-les jusqu'a la frontiere.",
        },
        success = "COMMANDEMENT : VVS 34 a repasse la frontiere.",
        released = "COMMANDEMENT : VVS 34 a largue sur Mineralnye Vody ! TIR AUTORISE. Engagez au plus vite.",
        failed = "COMMANDEMENT : VVS 34 a repasse la frontiere apres largage. Interception ratee.",
        revenge = "COMMANDEMENT : TIR AUTORISE. L'appareil restant vous attaque, engagez au plus vite.",
        revengeOver = "COMMANDEMENT : L'appareil VVS restant rompt le combat.",
        -- voix (VOIX) : [1] et [2] = appel, reponse et ordre du COMMANDEMENT de chaque interception
        voice = { { "c14", "c15", "c16" }, { "c18", "c19", "c20" }, alert = "c12", crossed = "c13", crossedAgain = "c17",
                  success = "c21", released = "c22", failed = "c23", revenge = "c24", revengeOver = "c25" },
    },
}

-- Tirage sans repetition : chaque avion sort une fois avant que le tirage reparte de zero
IcptBag = {}

local function IcptDraw()
    if #IcptBag == 0 then
        for i = 1, #INTERCEPTS do IcptBag[i] = i end
    end
    return INTERCEPTS[table.remove(IcptBag, math.random(#IcptBag))]
end

function IcptLaunch(group)
    if not group or not group:IsAlive() then return end
    if Icpt then GroupMsg(group, "Interception deja en cours : demande le code a ceux qui l'ont lancee.", 10) return end
    local def = IcptDraw()
    local ai = GetSpawner(def.template):Spawn() -- pas "group" : il masquait le groupe du lanceur (mission sans membre, 10/11)
    local u = GroupUnit(ai)
    local target = Airbase.getByName(def.target)
    if not u or not target then env.warning("BLUESKY : interception impossible : " .. def.template) return end
    local p, t = u:getPoint(), target:getPoint()
    Icpt = { def = def, group = ai, unitName = u:getName(), start = p, target = t,
             state = "silent", calls = 0, lastCall = -ICPT_GAP_S }
    -- cap du lanceur vers l'avion, repris par def.alert (%03d, puis %s = lanceur)
    local hdg, who = 0, "le lanceur"
    ForEachGroupPlayer(group, function(_, name, pu) hdg, who = Bearing(pu:getPoint(), p), name end)
    Icpt.op = OpStart(ICPT_LABEL, string.format(def.alert, hdg, who), group, nil, nil, true)
    OpVoice(Icpt.op, def.voice.alert)
    if def.init then def.init(def) end
    IcptFly({ Wp(p.x, p.z, def.alt, def.speed), Wp(def.mid.x, def.mid.z, def.alt, def.speed),
              Wp(t.x, t.z, def.alt, def.speed) })
end

function IcptCall(group)
    if not group or not group:IsAlive() then return end
    if not Icpt then GroupMsg(group, "Aucune interception en cours (F10 > MISSIONS > INTERCEPTION > Lancer).", 10) return end
    if not OpHasGroup(Icpt.op, group) then GroupMsg(group, "Tu n'es pas dans cette interception (code a composer dans F10 > CODE).", 10) return end
    local def, u = Icpt.def, IcptUnit()
    if not u or (Icpt.state ~= "silent" and Icpt.state ~= "heading") then IcptMsg("Personne ne repond.", 10) return end
    local now = timer.getTime()
    if now - Icpt.lastCall < ICPT_GAP_S then IcptMsg("Attendez la reponse (" .. ICPT_GAP_S .. " s entre deux appels).", 5) return end

    -- l'appel vient des membres a moins de 1000 ft
    local p, names = u:getPoint(), {}
    for _, pu in ipairs(MemberUnits(Icpt.op)) do
        local q = pu:getPoint()
        if math.sqrt((q.x - p.x) ^ 2 + (q.y - p.y) ^ 2 + (q.z - p.z) ^ 2) <= ICPT_CALL_M then
            for _, name in ipairs(Crew(pu:getName(), pu:getPlayerName())) do
                if Icpt.op.members[name] then names[#names + 1] = name end
            end
        end
    end
    if #names == 0 then IcptMsg("Appel impossible : aucun membre a moins de 1000 ft du " .. def.label .. ".", 8) return end

    Icpt.lastCall = now
    local text, voice = def.call(def, u, p, names[1])
    IcptMsg(text, 20, voice)
end

-- Appele par le KillHandler : false = tir non autorise d'un membre (0 pt). Un pilote hors mission n'est pas au courant : kill normal.
function IcptKillAllowed(EventData, playerName)
    if not Icpt then return true end
    local tgt, def, op = EventData.TgtUnitName, Icpt.def, Icpt.op
    local main = tgt == Icpt.unitName
    if not main and (not tgt or tgt ~= Icpt.escortName) then return true end
    local member = op.members[playerName]
    if Icpt.state == "revenge" then -- le dernier de la patrouille : kill normal
        IcptEnd(def.label .. " abattu par " .. playerName .. ", patrouille detruite.")
        return true
    end
    if Icpt.state ~= "hostile" then
        local over = main or def.wing -- un ailier compte comme l'avion principal, pas l'escorte du Tu-95
        local who = main and ("le " .. def.label) or def.wing or "l'escorte"
        IcptMsg((member and ("TIR NON AUTORISE : " .. playerName .. " a abattu " .. who .. " sans autorisation. Aucun point.")
                 or (playerName .. " (hors mission) a abattu " .. who .. ".")) .. (over and " Interception ratee." or ""), 20)
        if member and main and def.punish then def.punish(def, EventData.IniDCSUnit) end
        if def.revengeFn then def.revengeFn(def) elseif main then IcptEnd() end
        return not member
    end
    if def.revengeFn then def.revengeFn(def) return true end -- patrouille : kill normal, l'autre se venge
    if not main then return true end -- escorte abattue apres autorisation : kill normal
    if member then
        IcptEnd(def.label .. " abattu par " .. playerName .. ".\n" .. OpReward(op, def.bonus))
    else
        IcptEnd(def.label .. " abattu par " .. playerName .. " (hors mission), pas de bonus.")
    end
    return true
end

local function IcptTick()
    if not Icpt then return end
    local u = IcptUnit()
    if not u then
        -- l'evenement Kill arrive apres la perte de vie : finir ici en ferait un kill normal, sans juger le tir (08/11)
        Icpt.lostAt = Icpt.lostAt or timer.getTime()
        if timer.getTime() - Icpt.lostAt >= ICPT_LOST_S then IcptEnd(Icpt.def.label .. " detruit, interception terminee.") end
        return
    end
    local here = u:getPoint()
    OpMarkPresent(Icpt.op, function(p) return Distance2D(p, here) <= ICPT_NEAR_M end)
    Icpt.def.tick(Icpt.def, u, here)
end

timer.scheduleFunction(function()
    local ok, err = pcall(IcptTick)
    if not ok then env.warning("BLUESKY : interception : " .. tostring(err)) end
    return timer.getTime() + 5
end, nil, timer.getTime() + 5)

for _, def in ipairs(INTERCEPTS) do
    for _, name in ipairs({ def.template, def.escort }) do
        if not Group.getByName(name) then env.warning("BLUESKY : groupe absent de la mission : " .. name) end
    end
end

-- HOST Naval AERA (08/11) : beaucoup de bateaux, en activation retardee pour ne pas charger le serveur ; actives au menu
local NAVAL_HOST = { "Admiral" }
NavalHostOn = false

-- Renvoie true si le groupe vient d'etre active
local function ActivateNaval()
    if NavalHostOn then return false end
    NavalHostOn = true
    for _, name in ipairs(NAVAL_HOST) do
        local g = Group.getByName(name)
        if g then g:activate() else env.warning("BLUESKY : groupe absent de la mission : " .. name) end
    end
    return true
end

function NavalHost()
    MESSAGE:New(ActivateNaval() and "HOST Naval AERA ACTIVE : groupe aeronaval russe en mer." or "HOST Naval AERA deja active.", 15)
        :ToCoalition(coalition.side.BLUE)
end

------------------------------------------------------------
-- MISSIONS STRIKE (10/11) : reussies quand toutes les cibles (objets DCS) sont detruites. Autre mission = une entree de STRIKES.
------------------------------------------------------------
local OP_IDLE_S = 600 -- plus aucun membre en slot depuis 10 min : mission fermee, sinon personne ne pourrait la relancer (le code est prive)
local PETROL = { x = -274341, z = 495476, r = 7606 } -- champ petrolier : sert seulement a trouver ses cibles

-- Cibles detruites, notees par l'evenement Dead (menus plus bas)
StrikeDead = {}

-- life0 = vie au lancement : une vie qui tombe a 0 compte comme detruite, une vie deja a 0 au lancement est ignoree
local function TargetAlive(o, life0)
    if not o:isExist() or StrikeDead[o:getName()] then return false end
    local life = o:getLife()
    if life0 and life0 > 0 and life and life <= 0 then
        StrikeDead[o:getName()] = true -- reste detruite pour un prochain lancement
        return false
    end
    return true
end

-- Derricks et plateforme : statiques de type heliport dans l'editeur, donc des Airbase pour DCS (pas des StaticObject, 10/11)
local function PetrolTargets()
    local list, near = {}, {}
    for _, o in ipairs(world.getAirbases() or {}) do
        if Distance2D(o:getPoint(), PETROL) <= PETROL.r then
            near[#near + 1] = o:getName() .. " / " .. tostring(o:getTypeName()) .. " / vie " .. tostring(o:getLife())
            if TargetAlive(o) then list[#list + 1] = o end
        end
    end
    env.info("BLUESKY : Petrol Strike, cibles du champ : " .. (#near > 0 and table.concat(near, " ; ") or "aucune"))
    return list
end

-- Factory Strike (11/11) : site industriel de GCI-2 (N 44 30 19, E 41 38 17), meme cercle que STRIKE_ZONES.
-- Cibles = statiques rouges industriels du cercle (pas les tours, sacs de sable, tentes, barrages).
local FACTORY = { x = -33689, z = 587167, r = 969 }
local FACTORY_TYPES = { ["Tank 2"] = true, [".Ammunition depot"] = true, [".Command Center"] = true, ["FARP Fuel Depot"] = true,
    ["Nodding_Donkey_Pump"] = true, ["Workshop A"] = true, ["Building01_PBR"] = true, ["Building05_PBR"] = true, ["HESCO_generator"] = true }

local function FactoryTargets()
    local list = {}
    for _, o in ipairs(coalition.getStaticObjects(coalition.side.RED) or {}) do
        if FACTORY_TYPES[o:getTypeName()] and Distance2D(o:getPoint(), FACTORY) <= FACTORY.r and TargetAlive(o) then
            list[#list + 1] = o
        end
    end
    env.info("BLUESKY : Factory Strike, " .. #list .. " cibles")
    return list
end

local function NavalTargets()
    ActivateNaval()
    local g = Group.getByName(NAVAL_HOST[1])
    for _, u in ipairs(g and g:getUnits() or {}) do
        if u:getTypeName() == "CV_1143_5" and TargetAlive(u) then return { u } end
    end
    return {}
end

-- Toutes les missions strike sont au prorata (11/11) : plus de condition de presence.
-- creditGroups : groupes dont chaque kill compte dans les parts, en plus des cibles (HOST Naval : toute l'escorte).
-- tab = "NAVAL" : rangee dans F10 > MISSIONS > NAVAL au lieu de STRIKE.
local STRIKES = {
    {
        label = "Petrol Strike", bonus = 20, targets = PetrolTargets,
        brief = "COMMANDEMENT : Champ petrolier russe en mer Noire, environ 47 NM au sud-ouest de Soukhoumi. " ..
                "Detruisez les derricks et la plateforme gaziere. Navires russes sur zone.",
        success = "COMMANDEMENT : Champ petrolier detruit. Mission reussie !",
        voice = { brief = "c26", success = "c27" },
    },
    {
        label = "HOST Naval AERA", bonus = 50, targets = NavalTargets, creditGroups = { [NAVAL_HOST[1]] = true }, tab = "NAVAL",
        brief = "COMMANDEMENT : Groupe aeronaval russe en mer Noire, environ 60 NM au sud-sud-ouest de Sochi. " ..
                "Coulez le porte-avions Kuznetsov. Forte defense antiaerienne.",
        success = "COMMANDEMENT : Kuznetsov coule. Mission reussie !",
        voice = { brief = "c28", success = "c29" },
    },
    {
        label = "Factory Strike", bonus = 30, targets = FactoryTargets, creditGroups = { ["GCI-2"] = true },
        brief = "COMMANDEMENT : Complexe industriel russe au nord du Caucase, autour du site radar GCI-2, " ..
                "environ 65 NM a l'ouest-nord-ouest de Mineralnye Vody. Detruisez reservoirs, depots, pompes et ateliers. " ..
                "Defense antiaerienne sur place.",
        success = "COMMANDEMENT : Complexe industriel detruit. Mission reussie !",
        voice = { brief = "c43", success = "c44" },
    },
}

------------------------------------------------------------
-- BASES ET CONVOIS (11/11) : memes regles que les strikes (cibles = unites, reussie quand tout est detruit, prorata).
-- Bases enchainees : Gudauta, puis Sochi, puis Anapa ; seule la base debloquee apparait dans F10 > MISSIONS > BASES.
-- Progression remise a zero a chaque lancement de la mission serveur (les unites detruites reapparaissent).
-- Cibles d'une base : unites au sol rouges actives a moins de BASE_RADIUS de son centre, sauf renforts et convois.
------------------------------------------------------------
local CAMPAIGN = {
    -- voice : briefing (membres) ; fallen : base tombee (tout le serveur, seule voix de la reussite)
    { base = "Gudauta", bonus = 30, voice = "c32", fallen = "c33",
      brief = "COMMANDEMENT : Base aerienne de Gudauta, environ 30 NM au nord-ouest de Soukhoumi. " ..
              "Detruisez toutes les unites au sol de la base. Defense antiaerienne sur place, renforts attendus." },
    { base = "Sochi", bonus = 40, voice = "c34", fallen = "c35",
      brief = "COMMANDEMENT : Base aerienne de Sochi, environ 35 NM au nord-ouest de Gudauta. " ..
              "Detruisez toutes les unites au sol de la base. Renforts blindes et helicopteres attendus." },
    { base = "Anapa", bonus = 60, voice = "c36", fallen = "c37",
      brief = "COMMANDEMENT : Base aerienne d'Anapa, a l'extremite nord-ouest de la cote. Derniere base russe du front : " ..
              "plus de 60 vehicules. Detruisez toutes les unites au sol de la base." },
}
CampaignStage = 1 -- indice de la base debloquee dans CAMPAIGN (au-dela : campagne finie)

-- Convois activables en renfort : leur mission n'apparait qu'une fois le convoi en route
local CONVOY_MISSIONS = {
    { label = "Convoi Gudauta", group = "Gudauta convoie", voice = "c38",
      brief = "COMMANDEMENT : Un convoi blinde russe fait route vers Gudauta en renfort. Detruisez tous ses vehicules." },
    { label = "Convoi Sochi", group = "sochi convoie", voice = "c39",
      brief = "COMMANDEMENT : Un convoi blinde russe fait route vers Sochi en renfort. Detruisez tous ses vehicules." },
    { label = "Convoi Soukhoumi", group = "sukumi convoie", voice = "c40",
      brief = "COMMANDEMENT : Contre-attaque russe : un convoi parti de Gudauta fait route vers Soukhoumi. Arretez-le." },
}
local CONVOY_BONUS = 20
-- Convoi nord : un tire au sort parmi les vivants (GCI-2 exclu : site radar, pas un convoi)
local NORTH_CONVOYS = { "convoie-1", "convoie-2", "convoie-3", "convoie-4", "convoie-5", "convoie-6", "sochi convoie-1" }
local NORTH_LABEL = "Convoi nord"

-- Unites vivantes et actives (renfort pas encore active : rien) d'une liste de groupes
local function GroupTargets(names)
    local list = {}
    for _, name in ipairs(names) do
        local g = Group.getByName(name)
        for _, u in ipairs(g and g:getUnits() or {}) do
            if u:isActive() and TargetAlive(u) then list[#list + 1] = u end
        end
    end
    return list
end

local NOT_BASE = {} -- renforts et convois : jamais comptes dans une base
for _, b in ipairs(BASES) do for _, name in ipairs(b.groups) do NOT_BASE[name] = true end end
for _, c in ipairs(CONVOY_MISSIONS) do NOT_BASE[c.group] = true end
for _, name in ipairs(NORTH_CONVOYS) do NOT_BASE[name] = true end

local function BaseTargets(baseName)
    local center
    for _, b in ipairs(BASES) do if b.name == baseName then center = { x = b.x, z = b.y } end end
    local list, groups = {}, {}
    for _, g in ipairs(coalition.getGroups(coalition.side.RED, Group.Category.GROUND) or {}) do
        local name = g:getName()
        if not NOT_BASE[name] then
            for _, u in ipairs(g:getUnits()) do
                if u:isActive() and TargetAlive(u) and Distance2D(u:getPoint(), center) <= BASE_RADIUS then
                    list[#list + 1] = u
                    groups[name] = true
                end
            end
        end
    end
    local names = {}
    for name in pairs(groups) do names[#names + 1] = name end
    table.sort(names)
    env.info("BLUESKY : base " .. baseName .. ", " .. #list .. " cibles, groupes : " .. table.concat(names, ", "))
    return list
end

-- Position approximative pour un briefing : distance et cap depuis l'aerodrome le plus proche
local function WhereIs(p)
    local best, bd
    for _, ab in ipairs(world.getAirbases() or {}) do
        if ab:getDesc().category == Airbase.Category.AIRDROME then
            local d = Distance2D(ab:getPoint(), p)
            if not bd or d < bd then best, bd = ab, d end
        end
    end
    if not best then return "" end
    return string.format(" Derniere position : environ %d NM au %03d de %s.", math.floor(bd / 1852 + 0.5),
        Bearing(best:getPoint(), p), best:getName())
end

local function CampaignDone(stage)
    if CampaignStage ~= stage then return end
    CampaignStage = stage + 1
    local name, nxt = CAMPAIGN[stage].base, CAMPAIGN[stage + 1]
    MESSAGE:New(nxt and ("COMMANDEMENT : " .. name .. " est tombee. Nouvelle mission disponible : " .. nxt.base ..
                         " (F10 > MISSIONS > BASES).")
                    or ("COMMANDEMENT : " .. name .. " est tombee. Le front russe est brise : victoire !"), 20):ToAll()
    VoiceAll(CAMPAIGN[stage].fallen)
    env.info("BLUESKY : campagne, " .. name .. " tombee")
end

local BASE_DEFS, CONVOY_DEFS = {}, {}
for i, c in ipairs(CAMPAIGN) do
    BASE_DEFS[i] = { label = "Base " .. c.base, bonus = c.bonus, brief = c.brief, stage = i,
                     targets = function() return BaseTargets(c.base) end, voice = { brief = c.voice },
                     success = "COMMANDEMENT : Base de " .. c.base .. " detruite. Mission reussie !" }
end
for i, c in ipairs(CONVOY_MISSIONS) do
    CONVOY_DEFS[i] = { label = c.label, bonus = CONVOY_BONUS, brief = c.brief,
                       targets = function() return GroupTargets({ c.group }) end, voice = { brief = c.voice, success = "c42" },
                       success = "COMMANDEMENT : Convoi detruit. Mission reussie !" }
end
local NORTH_DEF = {
    label = NORTH_LABEL, bonus = CONVOY_BONUS,
    targets = function()
        local alive = {}
        for _, name in ipairs(NORTH_CONVOYS) do
            if #GroupTargets({ name }) > 0 then alive[#alive + 1] = name end
        end
        return #alive > 0 and GroupTargets({ alive[math.random(#alive)] }) or {}
    end,
    brief = function(targets)
        return "COMMANDEMENT : Convoi russe repere au nord, en zone hostile. Detruisez tous ses vehicules." ..
               WhereIs(targets[1]:getPoint())
    end,
    success = "COMMANDEMENT : Convoi detruit. Mission reussie !",
    voice = { brief = "c41", success = "c42" },
}

function StrikeLaunch(group, def)
    if not group or not group:IsAlive() then return end
    if Ops[def.label] then GroupMsg(group, def.label .. " deja en cours : demande le code a ceux qui l'ont lancee.", 10) return end
    local targets = def.targets()
    if #targets == 0 then
        GroupMsg(group, def.label .. " : objectif deja detruit.", 10)
        if def.stage then CampaignDone(def.stage) RefreshMissionMenus() end -- base videe sans mission : la suivante s'ouvre
        return
    end
    local brief = type(def.brief) == "function" and def.brief(targets) or def.brief
    local op = OpStart(def.label, brief, group, true, true)
    op.def, op.targets, op.left, op.life0, op.names = def, targets, #targets, {}, {}
    for _, o in ipairs(targets) do
        op.life0[o:getName()] = o:getLife()
        op.names[o:getName()] = true
    end
    op.isTarget = function(unitName, groupName)
        return (unitName and op.names[unitName]) or (groupName and def.creditGroups and def.creditGroups[groupName]) or false
    end
    OpVoice(op, def.voice and def.voice.brief)
end

local function OpIdleClose(op, now)
    if #MemberUnits(op) > 0 then
        op.idleAt = nil
    else
        op.idleAt = op.idleAt or now
        if now - op.idleAt >= OP_IDLE_S then Ops[op.label] = nil end
    end
end

local function StrikeTick(op)
    local left, now = 0, timer.getTime()
    for _, o in ipairs(op.targets) do
        if TargetAlive(o, op.life0[o:getName()]) then left = left + 1 end
    end
    if left == 0 then
        OpMsg(op, op.def.success .. "\n" .. OpReward(op, op.def.bonus), 20)
        OpVoice(op, op.def.voice and op.def.voice.success)
        Ops[op.label] = nil
        if op.def.stage then CampaignDone(op.def.stage) end
        RefreshMissionMenus() -- base suivante, convoi detruit
        return
    end
    if left < op.left then
        op.left = left
        OpMsg(op, op.label .. " : cible detruite, reste " .. left .. ".", 10)
    end
    OpIdleClose(op, now)
end

timer.scheduleFunction(function()
    for _, op in pairs(Ops) do
        if op.targets then
            local ok, err = pcall(StrikeTick, op)
            if not ok then env.warning("BLUESKY : mission " .. op.label .. " : " .. tostring(err)) end
        end
    end
    return timer.getTime() + 5
end, nil, timer.getTime() + 5)

------------------------------------------------------------
-- ZONE CAP (10/11) : une vague = un groupe tire au sort dans CAP_GROUPS, qui patrouille au hasard dans la zone "spawn cap".
-- S'il sort de la zone, il y revient sans engager, puis reprend sa patrouille : ni frontiere ni montagnes au sud.
-- Vague suivante : quand tous ses avions sont abattus, poses, a court de carburant ou sans missile (EniWaveOver).
-- En route tant que F10 SPAWN > Zone CAP est actif ou qu'une mission CAP est en cours.
------------------------------------------------------------
local CAP_GROUPS = { "Mig 21 Cap", "jf17 cap", "mig29 cap", "su27 cap", "mig31 cap", "su34 cap", "su30 cap", "su33 cap", "F14 cap", "M2000 Cap" }
local CAP_LABEL = "CAP"
local CAP_GOAL, CAP_BONUS = 5, 30 -- avions abattus par les membres, points par membre
local CAP_SPEED = 240             -- m/s : les vitesses de l'editeur (jusqu'a 833 m/s) videraient les reservoirs
local CAP_ALT_MIN = 5000          -- m : au-dessus des sommets de la zone (~4000 m)
local CAP_ALT_MAX = 12000         -- m : a 21000 m (MiG-31 de l'editeur), 240 m/s ne suffit pas a tenir en l'air
local CAP_ENGAGE_M = 25000        -- distance max entre la route et une cible (12/11 : 60 km allaient chercher un Apache a Gudauta)
local CAP_OUT_MAX_S = 120         -- hors zone depuis 2 min (parti trop loin en poursuite) : groupe supprime, sans points, vague suivante
local CAP_REACH_M = 5000          -- point de patrouille atteint : il en prend un autre
local CAP_BACK_S = 90             -- apres un retour dans la zone, delai sans engager : evite les allers-retours sur la limite
local CAP_HOME = "Maykop-Khanskaya"

CapActive = false
CapWave = nil -- { groups = { GROUP }, group, t0, alt, dest, back }

local function CapZone() return ZONE:FindByName("spawn cap") end

local function CapInZone(p) return CapZone():IsVec2InZone({ x = p.x, y = p.z }) end

local function CapRoute(w, p, engage)
    local d = CapZone():GetRandomVec2()
    w.dest = { x = d.x, z = d.y }
    local from = Wp(p.x, p.z, w.alt, CAP_SPEED)
    if engage then
        local t = w.group:EnRouteTaskEngageTargets(CAP_ENGAGE_M, { "Air" }, 0)
        from.task = { id = "ComboTask", params = { tasks = {
            { number = 1, auto = false, enabled = true, id = t.id, params = t.params } } } }
    end
    w.group:SetTask({ id = "Mission", params = { route = { points = { from, Wp(d.x, d.y, w.alt, CAP_SPEED) } } } }, 1)
end

local function CapSpawn(now)
    local name = CAP_GROUPS[math.random(#CAP_GROUPS)]
    local d = CapZone():GetRandomVec2()
    local alt = _DATABASE.Templates.Groups[name].Template.route.points[1].alt
    alt = math.min(math.max(alt, CAP_ALT_MIN), CAP_ALT_MAX)
    local g = GetSpawner(name):InitSpeedMps(CAP_SPEED):SpawnFromVec3({ x = d.x, y = alt, z = d.y })
    if not g then return end
    HostileGroups[#HostileGroups + 1] = g -- efface aussi par "Clear hostile"
    DestroyWatch[#DestroyWatch + 1] = g
    g:OptionROEWeaponFree()
    CapWave = { groups = { g }, group = g, t0 = now, alt = alt }
    CapRoute(CapWave, { x = d.x, z = d.y }, true)
    env.info("BLUESKY : Zone CAP : " .. name)
end

local function CapPatrol(w, now)
    local u = GroupUnit(w.group)
    if not u then return end
    local p = u:getPoint()
    if not CapInZone(p) then
        w.out = w.out or now
        if now - w.out >= CAP_OUT_MAX_S then
            env.info("BLUESKY : Zone CAP : " .. w.group:GetName() .. " hors zone depuis " .. CAP_OUT_MAX_S .. " s, supprime")
            w.group:Destroy()
            return
        end
        if not w.back then CapRoute(w, p, false) end
        w.back = now
        return
    end
    w.out = nil
    if w.back then
        if now - w.back >= CAP_BACK_S then
            w.back = nil
            CapRoute(w, p, true)
        end
    elseif Distance2D(p, w.dest) < CAP_REACH_M then
        CapRoute(w, p, true)
    end
end

-- Vague finie mais encore en l'air (plus de carburant ou de missile) : elle rentre se poser
local function CapRtb(w)
    local u = GroupUnit(w.group)
    local home = Airbase.getByName(CAP_HOME)
    if not (u and home and u:inAir()) then return end
    local p = u:getPoint()
    w.group:SetTask({ id = "Mission", params = { route = { points = { Wp(p.x, p.z, p.y, CAP_SPEED), LandWp(home) } } } }, 1)
end

local function CapTick()
    local now = timer.getTime()
    local op = Ops[CAP_LABEL]
    if op then OpIdleClose(op, now) end
    if CapWave and not EniWaveOver(CapWave) then CapPatrol(CapWave, now) return end
    if CapWave then CapRtb(CapWave) end
    CapWave = nil
    if CapActive or Ops[CAP_LABEL] then CapSpawn(now) end
end

timer.scheduleFunction(function()
    local ok, err = pcall(CapTick)
    if not ok then env.warning("BLUESKY : Zone CAP : " .. tostring(err)) end
    return timer.getTime() + 15
end, nil, timer.getTime() + 15)

function SetCapSpawn(on)
    CapActive = on
    MESSAGE:New(on and "ZONE CAP ACTIVE" or "ZONE CAP DESACTIVE", 10):ToCoalition(coalition.side.BLUE)
end

function CapLaunch(group)
    if not group or not group:IsAlive() then return end
    if Ops[CAP_LABEL] then GroupMsg(group, "CAP deja en cours : demande le code a ceux qui l'ont lancee.", 10) return end
    local op = OpStart(CAP_LABEL, "COMMANDEMENT : Patrouilles russes au nord du Caucase, secteur Maykop. " ..
        "Entrez dans la zone CAP et abattez " .. CAP_GOAL .. " appareils ennemis.", group, true, true)
    op.kills = 0
    op.isTarget = function(unitName) return CapTemplate(unitName) ~= nil end
    OpVoice(op, "c30") -- la voix dit "cinq appareils" : a refaire si CAP_GOAL change
end

-- Appele par le KillHandler : seuls les kills des membres sur des avions de la zone CAP comptent
-- Nom du modele CAP d'une unite spawnee ("mig29 cap#001-01" -> "mig29 cap"), nil si ce n'est pas un avion de la zone CAP
function CapTemplate(unitName)
    local template = tostring(unitName):match("^(.-)#")
    for _, name in ipairs(CAP_GROUPS) do
        if name == template then return name end
    end
    return nil
end

function CapKill(EventData, playerName)
    local op = Ops[CAP_LABEL]
    if not (op and op.members[playerName] and CapTemplate(EventData.TgtUnitName)) then return end
    op.kills = op.kills + 1
    if op.kills >= CAP_GOAL then
        OpMsg(op, "COMMANDEMENT : Objectif atteint, mission CAP reussie !\n" .. OpReward(op, CAP_BONUS), 20)
        OpVoice(op, "c31")
        Ops[CAP_LABEL] = nil
    else
        OpMsg(op, "CAP : " .. op.kills .. "/" .. CAP_GOAL .. " appareils abattus.", 10)
    end
end

for _, name in ipairs(CAP_GROUPS) do
    if not Group.getByName(name) then env.warning("BLUESKY : groupe absent de la mission : " .. name) end
end

-- ZONES DESTROY CAP (13/11) : un avion HOST A/A ou zone CAP qui entre dans une de ces zones est supprime, sans points.
-- Zones = bandes de ~3 km de large : verifie toutes les 2 s (a 300 m/s, 600 m parcourus entre deux passages).
local DESTROY_ZONES = {}
for _, name in ipairs({ "Destroy cap", "Destroy cap-2" }) do
    local z = ZONE:FindByName(name)
    if z then DESTROY_ZONES[#DESTROY_ZONES + 1] = z else env.warning("BLUESKY : zone absente de la mission : " .. name) end
end

local function DestroyTick()
    local keep = {}
    for _, g in ipairs(DestroyWatch) do
        local dcs = g:GetDCSObject()
        if dcs and dcs:isExist() then
            for _, u in ipairs(dcs:getUnits()) do
                local p = u:getPoint()
                for _, z in ipairs(DESTROY_ZONES) do
                    if z:IsVec2InZone({ x = p.x, y = p.z }) then
                        env.info("BLUESKY : Destroy cap : " .. u:getName() .. " supprime dans " .. z:GetName())
                        u:destroy() -- suppression simple : pas d'evenement de kill, donc aucun point
                        break
                    end
                end
            end
            if dcs:isExist() and dcs:getSize() > 0 then keep[#keep + 1] = g end
        end
    end
    DestroyWatch = keep
end

timer.scheduleFunction(function()
    local ok, err = pcall(DestroyTick)
    if not ok then env.warning("BLUESKY : Destroy cap : " .. tostring(err)) end
    return timer.getTime() + 2
end, nil, timer.getTime() + 2)

------------------------------------------------------------
-- MENUS F10 MISSIONS + CODE : par groupe (et pas par coalition) pour savoir qui lance et qui rejoint
------------------------------------------------------------
-- cibles statiques des missions strike : detruites = evenement Dead (voir TargetAlive)
StrikeDeadHandler = EVENTHANDLER:New()
StrikeDeadHandler:HandleEvent(EVENTS.Dead)
function StrikeDeadHandler:OnEventDead(EventData)
    local name = EventData.IniDCSUnitName or EventData.IniUnitName
    if name then StrikeDead[name] = true end
end

-- BASES et CONVOIS changent en cours de partie (base debloquee, convoi en route ou detruit) : refaits par RefreshMissionMenus
PlayerDynMenus = PlayerDynMenus or {} -- groupe -> { group, root, bases, convois }

local function NorthAlive()
    for _, name in ipairs(NORTH_CONVOYS) do
        if #GroupTargets({ name }) > 0 then return true end
    end
    return false
end

local function FillDynMenus(e)
    local group = e.group
    e.bases:RemoveSubMenus()
    e.convois:RemoveSubMenus()
    local base = BASE_DEFS[CampaignStage]
    if base then
        MENU_GROUP_COMMAND:New(group, base.label, e.bases, StrikeLaunch, group, base)
    else
        MENU_GROUP_COMMAND:New(group, "Campagne terminee", e.bases, GroupMsg, group, "Toutes les bases sont tombees.", 8)
    end
    local any = false
    for _, def in ipairs(CONVOY_DEFS) do
        if Ops[def.label] or #def.targets() > 0 then
            MENU_GROUP_COMMAND:New(group, def.label, e.convois, StrikeLaunch, group, def)
            any = true
        end
    end
    if Ops[NORTH_LABEL] or NorthAlive() then
        MENU_GROUP_COMMAND:New(group, NORTH_LABEL, e.convois, StrikeLaunch, group, NORTH_DEF)
        any = true
    end
    if not any then
        MENU_GROUP_COMMAND:New(group, "Aucun convoi en route", e.convois, GroupMsg, group, "Aucun convoi a attaquer pour l'instant.", 8)
    end
end

function RefreshMissionMenus()
    for groupName, e in pairs(PlayerDynMenus) do
        if PlayerMissionMenus[groupName] == e.root and e.group:IsAlive() then
            local ok, err = pcall(FillDynMenus, e)
            if not ok then env.warning("BLUESKY : menus missions : " .. tostring(err)) end
        else
            PlayerDynMenus[groupName] = nil
        end
    end
end

function AddMissionMenusForGroup(group, groupName)
    local g = group:GetDCSObject()
    if not g or g:getCoalition() ~= coalition.side.BLUE then return end

    local root = MENU_GROUP:New(group, "MISSIONS")
    local e = { group = group, root = root, bases = MENU_GROUP:New(group, "BASES", root),
                convois = MENU_GROUP:New(group, "CONVOIS", root) }
    local tabs = { STRIKE = MENU_GROUP:New(group, "STRIKE", root), NAVAL = MENU_GROUP:New(group, "NAVAL", root) }
    for _, def in ipairs(STRIKES) do
        MENU_GROUP_COMMAND:New(group, def.label, tabs[def.tab or "STRIKE"], StrikeLaunch, group, def)
    end
    local air = MENU_GROUP:New(group, "AIR", root)
    local icpt = MENU_GROUP:New(group, "INTERCEPTION", air)
    MENU_GROUP_COMMAND:New(group, "Lancer", icpt, IcptLaunch, group)
    MENU_GROUP_COMMAND:New(group, "Appel radio", icpt, IcptCall, group)
    MENU_GROUP_COMMAND:New(group, CAP_LABEL, air, CapLaunch, group)
    MENU_GROUP_COMMAND:New(group, "Rappel de mes missions", root, OpRecall, group)
    FillDynMenus(e)
    PlayerDynMenus[groupName] = e

    local code = MENU_GROUP:New(group, "CODE")
    for a = 1, 9 do
        local sub = MENU_GROUP:New(group, a .. "_", code)
        for b = 1, 9 do
            MENU_GROUP_COMMAND:New(group, tostring(a * 10 + b), sub, CodeJoin, group, tostring(a * 10 + b))
        end
    end

    PlayerMissionMenus[groupName], PlayerCodeMenus[groupName] = root, code
end

------------------------------------------------------------
-- MENUS F10 COALITION BLEUE
------------------------------------------------------------
local BLUE = coalition.side.BLUE

local MenuSpawn = MENU_COALITION:New(BLUE, "SPAWN")
local MenuEni = MENU_COALITION:New(BLUE, "Spawn ENI", MenuSpawn)
MENU_COALITION_COMMAND:New(BLUE, "Activer", MenuEni, SetEniSpawn, true)
MENU_COALITION_COMMAND:New(BLUE, "Desactiver", MenuEni, SetEniSpawn, false)
local MenuCap = MENU_COALITION:New(BLUE, "Zone CAP", MenuSpawn)
MENU_COALITION_COMMAND:New(BLUE, "Activer", MenuCap, SetCapSpawn, true)
MENU_COALITION_COMMAND:New(BLUE, "Desactiver", MenuCap, SetCapSpawn, false)
local MenuHostAA = MENU_COALITION:New(BLUE, "HOST A/A AERA", MenuSpawn)
for _, h in ipairs(HOSTILES) do
    local sub = MENU_COALITION:New(BLUE, h.menu, MenuHostAA)
    for i = 1, 4 do
        MENU_COALITION_COMMAND:New(BLUE, h.menu .. "-" .. i, sub, SpawnHostile, h.prefix .. i)
    end
end
MENU_COALITION_COMMAND:New(BLUE, "Clear hostile", MenuHostAA, Clear)
MENU_COALITION_COMMAND:New(BLUE, "HOST Naval AERA", MenuSpawn, NavalHost)
MENU_COALITION_COMMAND:New(BLUE, "Reset Croix", MenuSpawn, Croix)
MENU_COALITION_COMMAND:New(BLUE, "Spawn Convoi", MenuSpawn, Convoi)

local MenuTankers = MENU_COALITION:New(BLUE, "TANKERS")
for _, t in ipairs(TANKERS) do
    MENU_COALITION_COMMAND:New(BLUE, t.label, MenuTankers, SpawnTanker, t.template)
end
