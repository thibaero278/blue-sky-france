-- Bugs trouvés le 15/11 en recoupant avec la vraie .miz (corrigés le 15/11) :
--  * SPAWN > Spawn Convoi tirait conv-1 à conv-8 au sort, la .miz n'a que conv-1 à conv-5 : 3 clics sur 8 ne faisaient rien.
--  * Zone CAP : le script cherchait le groupe "F14 cap" (nom de l'unité), le groupe s'appelle "f14 cap" : F-14 jamais apparu.
-- Ici : 16 clics = 16 convois, et chaque groupe de la zone CAP peut apparaître (aucun "groupe absent" au chargement,
-- vérifié par le moteur sur tous les scénarios).
local steps = { { t = 5, spawn = { player = "Dex", slot = "Hornet Kobuleti" } } }
for i = 1, 16 do steps[#steps + 1] = { t = 10 + i, menu = { player = "Dex", path = "SPAWN > Spawn Convoi" } } end
steps[#steps + 1] = { t = 30, check = { ok = function(F)
    local n = 0
    for _, g in ipairs(F.groupList) do if g.name:match("^conv%-%d#") then n = n + 1 end end
    return n == 16, "Spawn Convoi : " .. n .. " convois apparus sur 16 clics"
end } }
-- tirage de la zone CAP jusqu'à tomber sur le F-14 : il apparaît bien (l'avion de la vague précédente est abattu)
steps[#steps + 1] = { t = 31, menu = { player = "Dex", path = "SPAWN > Zone CAP > Activer" } }
steps[#steps + 1] = { t = 32, lua = function(F)
    for _ = 1, 200 do
        if F.groups["f14 cap#001"] then return end
        for _, g in ipairs(F.groupList) do
            if g.name:find(" cap#", 1, true) or g.name:find(" Cap#", 1, true) then g:destroy() end
        end
        F.runUntil(F.now + 15)
    end
end }
steps[#steps + 1] = { check = { ok = function(F)
    local g = Group.getByName("f14 cap#001")
    return g ~= nil and g:getUnit(1):inAir(), "Zone CAP : le F-14 (f14 cap) n'est jamais apparu en 200 vagues"
end } }

return { description = "Spawn Convoi reussit a chaque clic, le F-14 de la zone CAP apparait", steps = steps }
