-----------------------------------------------------
-- Blue Sky - commandes Python -> DCS (environnement hook)
-----------------------------------------------------
local base      = _G
local dcsbot    = base.dcsbot
local utils     = base.require("DCSServerBotUtils")
local Sim       = base.Sim

-- Positions des joueurs pour la carte live du site (reponse : dcsbot.bsGetLive dans mission.lua)
function dcsbot.bsGetLive(json)
    -- UCID de l'hôte (id 1), que DCSServerBot ignore : le plugin l'enregistre pour regrouper ses pseudos
    local ok, ucid = pcall(net.get_player_info, 1, 'ucid')
    if ok and ucid and ucid ~= '' then
        utils.sendBotTable({ command = 'bsHost', ucid = ucid, name = net.get_player_info(1, 'name') })
    end
    -- Multi-équipage : le script de mission ne voit que le pilote ; on lui donne les autres places (unité -> pseudos)
    local crew = {}
    local okCrew, err = pcall(function()
        for _, id in ipairs(net.get_player_list() or {}) do
            local _, slot, sub = utils.getMulticrewAllParameters(id)
            if slot and sub and sub > 0 then
                local unit = Sim.getUnitProperty(slot, Sim.UNIT_NAME)
                if unit then
                    crew[unit] = crew[unit] or {}
                    table.insert(crew[unit], net.get_player_info(id, 'name'))
                end
            end
        end
    end)
    if not okCrew then log.write('DCSServerBot', log.WARNING, 'BlueSky: equipages non lus : ' .. tostring(err)) end
    local script = 'dcsbot.bsSetCrew(' .. utils.basicSerialize(net.lua2json(crew)) .. ') ' ..
                   'dcsbot.bsGetLive(' .. utils.basicSerialize(json.channel or "-1") .. ')'
    net.dostring_in('mission', 'a_do_script(' .. utils.basicSerialize(script) .. ')')
end

-- Scores fusionnés de tous les serveurs (R2D2) → script de mission (mission.lua : dcsbot.bsSetScores)
function dcsbot.bsSetScores(json)
    local script = 'dcsbot.bsSetScores(' .. utils.basicSerialize(json.scores or '{}') .. ', ' ..
                   utils.basicSerialize(json.remove or '[]') .. ')'
    net.dostring_in('mission', 'a_do_script(' .. utils.basicSerialize(script) .. ')')
end
