-----------------------------------------------------
-- Blue Sky - commandes Python -> DCS (environnement hook)
-----------------------------------------------------
local base      = _G
local dcsbot    = base.dcsbot
local utils     = base.require("DCSServerBotUtils")

-- Positions des joueurs pour la carte live du site (reponse : dcsbot.bsGetLive dans mission.lua)
function dcsbot.bsGetLive(json)
    local script = 'dcsbot.bsGetLive(' .. utils.basicSerialize(json.channel or "-1") .. ')'
    net.dostring_in('mission', 'a_do_script(' .. utils.basicSerialize(script) .. ')')
end
