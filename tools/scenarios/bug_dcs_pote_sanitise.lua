-- Bug du 26/11 : chez un pote (MissionScripting.lua d'origine : io et lfs bloqués), F10 > Autres vide.
-- Le script plantait dès la ligne 17 (lfs.writedir) avant de créer les menus. Il doit tourner, scores en mémoire seulement.
return {
    description = "DCS non debloque (sans io ni lfs) : menus F10 presents, kill compte, fin de mission sans erreur",
    mission = function(M) lfs, io = nil, nil end, -- os est déjà nil dans le faux DCS
    warnings = { "scores non sauvegardes" },
    steps = {
        { t = 5, spawn = { player = "Dex", slot = "Hornet Kobuleti" } },
        { t = 10, check = { menu = { player = "Dex", has = {
            "SPAWN > HOST A/A AERA > Mig21 > Mig21-1", "STATISTIQUES > Mes scores", "MISSIONS > STRIKE > Petrol Strike", "CODE > 4_ > 47" } } } },
        { t = 12, menu = { player = "Dex", path = "STATISTIQUES > Mes scores" } },
        { t = 60, takeoff = { player = "Dex", alt = 300, speed = 70 } },
        { t = 100, kill = { by = "Dex", target = "Gudauta T-72 1", distance = 4000 } },
        { t = 660, land = { player = "Dex", at = "Kobuleti" } },
        { t = 671, check = { points = { Dex = 4 } } },
        { t = 700, mission_end = true },
    },
}
