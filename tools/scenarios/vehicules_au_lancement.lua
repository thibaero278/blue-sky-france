-- 27/11 : vehicules des missions retires au chargement (toute la DCA reste), recrees au lancement de leur mission
-- (Base, Convoi nord) ou au premier kill dans une base, avec un message a tous. Renforts pas declenches par le retrait.
local function exists(F, name) local u = F.units[name] return u ~= nil and u.exists end
local function northAlive(F)
    local n = 0
    for _, name in ipairs({ "convoie-1", "convoie-2", "convoie-3", "convoie-4", "convoie-5", "convoie-6", "sochi convoie-1" }) do
        if exists(F, name .. "-1") then n = n + 1 end
    end
    return n
end
local function added(F, name)
    local n = 0
    for _, a in ipairs(F.added) do if a.data.name == name then n = n + 1 end end
    return n
end

return {
    description = "vehicules retires au chargement, recrees au lancement (base, convoi nord) et au 1er kill, DCA gardee",
    mission = function(M)
        -- camions de Gudauta, sans DCA : retires (le groupe T-72 + Tor de Gudauta, lui, reste : il a de la DCA)
        M.groups[#M.groups + 1] = { name = "Gudauta camions", coal = 1, x = -196200, z = 516800, units = {
            { name = "Gudauta Ural 1", type = "Ural-375", x = -196200, z = 516800 },
            { name = "Gudauta Ural 2", type = "Ural-375", x = -196300, z = 516900 } } }
        -- structure pres de Sochi : son kill est le premier kill de la base
        M.statics[#M.statics + 1] = { name = "Sochi hangar", type = "Hangar A", x = -164100, z = 462300, coal = 1 }
        -- convois du nord sans DCA : tous retires, Convoi nord en fait apparaitre un seul
        for _, g in ipairs(M.groups) do
            if g.name:find("convoie%-") then g.units = { { type = "T-72B3" } } end
        end
    end,
    steps = {
        { t = 1, check = {
            log = { has = "vehicules des missions, 11 unites retirees" },
            ok = function(F)
                if exists(F, "Sochi T-72") or exists(F, "Anapa T-72") or exists(F, "Gudauta Ural 1") then return false, "vehicule pas retire" end
                if not (exists(F, "Gudauta T-72 1") and exists(F, "Gudauta Tor") and exists(F, "Strike")) then return false, "DCA retiree" end
                if northAlive(F) ~= 0 then return false, northAlive(F) .. " convois du nord encore la" end
                if F.units["Gudauta convoie-1"].active then return false, "renforts de Gudauta declenches par le retrait" end
                return true
            end } },
        { t = 5, spawn = { player = "Dex", slot = "Hornet Kobuleti" } },
        { t = 6, check = { menu = { player = "Dex", has = { "MISSIONS > BASES > Base Gudauta", "MISSIONS > CONVOIS > Convoi nord" } } } },
        -- lancement de la base : ses camions apparaissent et comptent dans les cibles (3 du groupe DCA + 2 camions)
        { t = 10, menu = { player = "Dex", path = "MISSIONS > BASES > Base Gudauta" } },
        { t = 11, check = {
            message = { player = "Dex", has = "Dex a lance Base Gudauta : les forces russes se deploient." },
            ops = { ["Base Gudauta"] = { left = 5 } },
            ok = function(F)
                return exists(F, "Gudauta Ural 1") and exists(F, "Gudauta Ural 2") and not F.units["Gudauta convoie-1"].active,
                    "camions pas recrees, ou renforts declenches par le lancement"
            end } },
        -- relance : deja en cours, rien de recree en double
        { t = 15, menu = { player = "Dex", path = "MISSIONS > BASES > Base Gudauta" } },
        { t = 16, check = { message = { player = "Dex", has = "deja en cours" },
                            ok = function(F) return added(F, "Gudauta camions") == 1, "camions recrees " .. added(F, "Gudauta camions") .. " fois" end } },
        -- premier kill a Sochi sans mission : ses vehicules apparaissent, renforts comme avant
        { t = 20, takeoff = { player = "Dex", alt = 3000, speed = 200 } },
        { t = 30, kill = { by = "Dex", target = "Sochi hangar", distance = 5000, weapon = "GBU_12" } },
        { t = 31, check = {
            message = { player = "Dex", has = "Sochi attaquee : les forces russes se deploient." },
            ok = function(F) return exists(F, "Sochi T-72") and F.units["sochi convoie-1"].active, "Sochi : vehicules ou renforts absents" end } },
        -- Convoi nord : un seul convoi apparait
        { t = 40, menu = { player = "Dex", path = "MISSIONS > CONVOIS > Convoi nord" } },
        { t = 41, check = {
            message = { player = "Dex", has = "Dex a lance Convoi nord : les forces russes se deploient." },
            ops = { ["Convoi nord"] = { left = 1 } },
            ok = function(F) return northAlive(F) == 1, northAlive(F) .. " convois du nord au lieu de 1" end } },
        -- Factory Strike : rien a recreer (le site n'a que sa DCA), pas de message de deploiement
        { t = 50, menu = { player = "Dex", path = "MISSIONS > STRIKE > Factory Strike" } },
        { t = 51, check = { message = { player = "Dex", lacks = "a lance Factory Strike" }, ops = { ["Factory Strike"] = { left = 4 } } } },
    },
}
