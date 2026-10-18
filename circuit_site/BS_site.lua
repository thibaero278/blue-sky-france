------------------------------------------------------------
-- BLUE SKY - Hook serveur : envoi des stats vers le site
-- A copier dans : Saved Games\DCS...\Scripts\Hooks\BS_site.lua
-- Lit Scores.lua (ecrit par script Caucase.lua), le convertit en JSON
-- et l'envoie a l'Apps Script Google via curl (en arriere-plan).
------------------------------------------------------------

local CONFIG = {
    url        = "COLLE_ICI_L_URL_DU_DEPLOIEMENT_APPS_SCRIPT",  -- https://script.google.com/macros/s/.../exec
    token      = "COLLE_ICI_LE_TOKEN",                       -- identique a la propriete TOKEN de l'Apps Script
    server     = "Blue Sky France",
    interval   = 60,     -- secondes entre deux verifications de Scores.lua
    heartbeat  = 300,    -- envoi force (joueurs en ligne) meme sans changement
}

local S = DCS or Sim
local SCORES_FILE = lfs.writedir() .. "Scores.lua"
local PAYLOAD_FILE = lfs.tempdir() .. "\\BS_site_payload.json"

local bs = {}
local lastCheck, lastSend, lastMtime = 0, 0, nil

local function blog(msg)
    if log and log.write then log.write("BS_SITE", log.INFO, msg) end
end

local function readScores()
    if not lfs.attributes(SCORES_FILE) then return nil end
    local ok, data = pcall(dofile, SCORES_FILE)
    if ok and type(data) == "table" then return data end
    return nil  -- fichier en cours d'ecriture : on retentera
end

local function onlinePlayers()
    local list = {}
    for _, id in ipairs(net.get_player_list() or {}) do
        if id ~= net.get_server_id() then
            local side = net.get_player_info(id, "side") or 0
            list[#list + 1] = { name = net.get_name(id), side = side }
        end
    end
    return list
end

local function send(scores)
    local pilots = {}
    for name, s in pairs(scores or {}) do
        local p = { name = name }
        for k, v in pairs(s) do p[k] = v end
        pilots[#pilots + 1] = p
    end

    local payload = net.lua2json({
        token   = CONFIG.token,
        type    = "scores",
        server  = CONFIG.server,
        mission = S.getMissionName and S.getMissionName() or "",
        online  = onlinePlayers(),
        pilots  = pilots,
    })

    local f = io.open(PAYLOAD_FILE, "w")
    if not f then blog("impossible d'ecrire " .. PAYLOAD_FILE) return end
    f:write(payload)
    f:close()

    -- start /B : curl tourne en arriere-plan, DCS n'attend pas la reponse
    os.execute(string.format(
        'start "" /B curl.exe -s -L -m 30 -o NUL -H "Content-Type: application/json" --data-binary "@%s" "%s"',
        PAYLOAD_FILE, CONFIG.url))
    lastSend = S.getRealTime()
    blog("stats envoyees (" .. #pilots .. " pilotes)")
end

local function check(force)
    local attr = lfs.attributes(SCORES_FILE)
    local mtime = attr and attr.modification
    local now = S.getRealTime()
    if force or mtime ~= lastMtime or now - lastSend >= CONFIG.heartbeat then
        local scores = readScores()
        if scores or not attr then
            lastMtime = mtime
            send(scores)
        end
    end
end

function bs.onSimulationFrame()
    local now = S.getRealTime()
    if now - lastCheck < CONFIG.interval then return end
    lastCheck = now
    if not S.isServer or S.isServer() then
        pcall(check, false)
    end
end

function bs.onSimulationStart() lastSend = 0 end
function bs.onSimulationStop()  pcall(check, true) end
function bs.onPlayerConnect()   lastSend = 0 end  -- maj rapide de la liste en ligne
function bs.onPlayerDisconnect() lastSend = 0 end

S.setUserCallbacks(bs)
blog("BS_site.lua charge")
