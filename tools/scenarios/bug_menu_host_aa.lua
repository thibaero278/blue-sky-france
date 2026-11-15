-- Bug vu en jeu le 13/11 : F10 > SPAWN > HOST A/A AERA absent. Avec une mission complète, le menu doit exister,
-- chaque commande doit faire apparaître son groupe, et rester en un seul exemplaire après une réapparition.
local HOST = {}
for _, m in ipairs({ "Mig21", "Mig29", "Su27" }) do
    for i = 1, 4 do HOST[#HOST + 1] = "SPAWN > HOST A/A AERA > " .. m .. " > " .. m .. "-" .. i end
end
HOST[#HOST + 1] = "SPAWN > HOST A/A AERA > Clear hostile"

return {
    description = "menu HOST A/A AERA present, cliquable, intact apres reapparition",
    steps = {
        { t = 5, spawn = { player = "Dex", slot = "Hornet Kobuleti" } },
        { t = 10, check = { menu = { player = "Dex", has = HOST, once = {
            "SPAWN > HOST A/A AERA", "SPAWN > Spawn ENI > Activer", "TANKERS > S3-B", "TANKERS > A-6",
            "STATISTIQUES > Mes scores", "MISSIONS > STRIKE > Petrol Strike", "CODE > 4_ > 47" } } } },
        { t = 12, menu = { player = "Dex", path = "SPAWN > HOST A/A AERA > Mig29 > Mig29-2" } },
        { t = 13, check = { ok = function(F, env)
            local g = Group.getByName("29-2#001")
            return g and g:getUnit(1):inAir() and #env.HostileGroups == 1 and #env.DestroyWatch == 1,
                "Mig29-2 : groupe 29-2#001 pas apparu en vol, ou pas suivi (HostileGroups / DestroyWatch)"
        end } },
        { t = 14, menu = { player = "Dex", path = "SPAWN > HOST A/A AERA > Clear hostile" } },
        { t = 15, check = { ok = function(F, env)
            return Group.getByName("29-2#001") == nil and #env.HostileGroups == 0, "Clear hostile n'a pas efface 29-2#001"
        end } },
        -- changement de slot puis retour : menus de groupe refaits, toujours un seul exemplaire
        { t = 20, leave = { player = "Dex" } },
        { t = 30, spawn = { player = "Dex", slot = "Hornet Kobuleti" } },
        { t = 35, check = { menu = { player = "Dex", has = HOST, once = {
            "SPAWN > HOST A/A AERA", "STATISTIQUES > Mes scores", "MISSIONS", "CODE" } } } },
    },
}
