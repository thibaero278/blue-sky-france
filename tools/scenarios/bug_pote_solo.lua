-- Bug du 27/11 : le pote lance la mission en solo. Il n'a que SPAWN et TANKERS dans F10 > Autres, pas d'accueil,
-- rien au décollage ni à l'atterrissage, mais ses kills comptent. En solo, son avion existe avant le script :
-- l'apparition (Birth) est passée avant que le script écoute, donc ni menus de groupe, ni accueil, ni suivi de vol.
return {
    description = "Solo, DCS non debloque : joueur deja dans l'avion au lancement, menus, accueil et vol quand meme",
    mission = function(M) lfs, io = nil, nil end,
    warnings = { "scores non sauvegardes" },
    at_start = { { player = "Pote", slot = "Hornet Kobuleti" } },
    steps = {
        { t = 10, check = { menu = { player = "Pote", has = {
            "SPAWN > HOST A/A AERA > Mig21 > Mig21-1", "TANKERS > A-6", "STATISTIQUES > Mes scores",
            "MISSIONS > STRIKE > Petrol Strike", "CODE > 4_ > 47" } },
            message = { player = "Pote", has = "Bienvenue sur Blue Sky, Pote" } } },
        { t = 60, takeoff = { player = "Pote", alt = 300, speed = 70 },
            check = { message = { player = "Pote", has = "DECOLLAGE DETECTE" } } },
        { t = 61, check = { flying = { "Pote" } } },
        { t = 100, kill = { by = "Pote", target = "Gudauta T-72 1", distance = 4000 } },
        { t = 660, land = { player = "Pote", at = "Kobuleti" } },
        { t = 671, check = { points = { Pote = 4 } } },
        { t = 700, mission_end = true },
    },
}
