-----------------------------------------------------
-- Blue Sky - callbacks (environnement hook)
-- Charge lua/mission.lua dans la mission a chaque chargement.
-----------------------------------------------------
local base      = _G
local utils     = base.require("DCSServerBotUtils")

local bluesky = {}

function bluesky.onMissionLoadEnd()
    log.write('DCSServerBot', log.DEBUG, 'BlueSky: onMissionLoadEnd()')
    utils.loadScript('DCSServerBot.lua')
    utils.loadScript('bluesky/mission.lua')
end

-- SRS n'envoie l'auto-connexion qu'aux joueurs qui rejoignent, jamais à l'hôte (id 1) :
-- on lance donc nous-mêmes le client SRS de l'hôte qui joue sur son propre serveur.
-- Le serveur SRS (démarré par le bot avec la mission) n'écoute qu'après ~10 s (essai UPnP) : connecté trop tôt,
-- le client est refusé et reste déconnecté. On attend donc que le port réponde (essai toutes les 2 s, 3 min max).
-- shortcut: port 5002 en dur (celui de nodes.yaml pour MSI et Weefe), à lire dans la config s'il change un jour
local srsWait = nil   -- { next = heure du prochain essai, stop = heure limite } tant que le client n'est pas lancé

local function srsReady()
    local tcp = base.require('socket').tcp()
    tcp:settimeout(0.2)
    local ok = tcp:connect('127.0.0.1', 5002)
    tcp:close()
    return ok ~= nil
end

local function startHostSrs()
    local lfs = base.require('lfs')
    package.cpath = package.cpath .. ';' .. lfs.writedir() .. 'Mods\\Services\\DCS-SRS\\bin\\?.dll'
    local srs = base.require('srs')
    if srs.get_srs_path() == '' then return end
    srs.start_srs('127.0.0.1:5002')
    -- client déjà ouvert : on lui demande de se connecter (même message que le mod SRS)
    local udp = base.require('socket').udp()
    udp:sendto('127.0.0.1:5002\n', '127.0.0.1', 5069)
    udp:close()
end

function bluesky.onSimulationStart()
    if not (DCS.isMultiplayer() and DCS.isServer()) then return end
    local now = DCS.getRealTime()
    srsWait = { next = now, stop = now + 180 }
end

function bluesky.onSimulationStop()
    srsWait = nil
end

function bluesky.onSimulationFrame()
    if not srsWait then return end
    local now = DCS.getRealTime()
    if now < srsWait.next then return end
    srsWait.next = now + 2
    local ok, ready = pcall(srsReady)
    if ok and not ready and now < srsWait.stop then return end
    srsWait = nil
    if not (ok and ready) then
        log.write('DCSServerBot', log.WARNING, 'BlueSky: serveur SRS injoignable (bot arrete ?), client SRS de l\'hote non lance')
        return
    end
    local launched, err = pcall(startHostSrs)
    log.write('DCSServerBot', launched and log.INFO or log.WARNING, 'BlueSky: client SRS de l\'hote ' .. (launched and 'lance' or ('non lance : ' .. tostring(err))))
end

Sim.setUserCallbacks(bluesky)
