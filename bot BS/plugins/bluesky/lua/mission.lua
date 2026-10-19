-----------------------------------------------------
-- Blue Sky - environnement mission
-- Lit la position des avions des joueurs (carte live du site).
-----------------------------------------------------
local base      = _G
dcsbot          = base.dcsbot

local M_TO_FT   = 3.28084
local MS_TO_KT  = 1.94384

local function playerUnit(unit)
    if not unit or not unit:isExist() then return nil end
    local name = unit:getPlayerName()
    if not name then return nil end
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
        side     = unit:getCoalition(),
        air      = air,
        lat      = lat,
        lon      = lon,
        hdg      = math.floor(hdg + 0.5),
        alt      = math.floor(p.y * M_TO_FT + 0.5),
        spd      = math.floor(math.sqrt(v.x ^ 2 + v.y ^ 2 + v.z ^ 2) * MS_TO_KT + 0.5),
        base     = base_name,
    }
end

function dcsbot.bsGetLive(channel)
    local players = {}
    for _, side in ipairs({ coalition.side.NEUTRAL, coalition.side.RED, coalition.side.BLUE }) do
        for _, unit in ipairs(coalition.getPlayers(side) or {}) do
            local ok, data = pcall(playerUnit, unit)
            if ok and data then players[#players + 1] = data end
        end
    end
    dcsbot.sendBotTable({ command = 'bsGetLive', time = timer.getAbsTime(), players = players }, channel)
end

env.info('DCSServerBot - BlueSky: mission.lua charge')
