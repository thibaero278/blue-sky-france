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

Sim.setUserCallbacks(bluesky)
