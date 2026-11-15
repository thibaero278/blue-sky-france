-- Bug du 13/11 (F10 > SPAWN > HOST A/A AERA absent) : seule cause trouvée dans le script. Avant le 15/11, s'il manquait
-- une statique "s-croix-1" à "s-croix-12" dans la .miz (renommée, supprimée), SPAWNSTATIC:NewFromStatic plantait au
-- chargement et tout ce qui suit n'existait pas (menus SPAWN, TANKERS, MISSIONS, CODE).
-- Depuis le 15/11 : chargement protégé, avertissement "[CROIX]" dans dcs.log, tous les menus restent, Reset Croix
-- recrée ce qui existe (11/12).
return {
    description = "une statique s-croix manquante ne casse plus le script : menus complets, Reset Croix 11/12",
    mission = function(M) M.remove("s-croix-5") end,
    warnings = { "s-croix-5" },
    steps = {
        { t = 5, spawn = { player = "Dex", slot = "Hornet Kobuleti" } },
        { t = 10, check = { menu = { player = "Dex",
            has = { "STATISTIQUES > Mes scores", "MODE BLUE SKY > Activer (au sol)",
                    "SPAWN > HOST A/A AERA", "SPAWN > Reset Croix", "TANKERS", "MISSIONS", "CODE" } },
            log = { has = "s-croix-5" } } },
        { t = 11, menu = { player = "Dex", path = "SPAWN > Reset Croix" } },
        { t = 16, check = { message = { player = "Dex", has = "11/12 statics recrees" } } },
    },
}
