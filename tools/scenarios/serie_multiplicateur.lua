-- Série (20/11) : un vol valable posé puis moteur coupé fait monter la série (x1, x1,5, x2...) ;
-- vol trop court = neutre, redécoller sans couper le moteur = pas compté, mort = série perdue. s.serie est une chaîne.
-- Le multiplicateur ne touche que les points de combat (kills, missions), pas ceux du temps de vol (choix du 20/11 : AFK).
return {
    description = "serie : x1 puis x1,5 sur le kill seulement, vol court neutre, pas de bonus sur le temps, serie perdue a la mort",
    scores = { Dex = { points = 0, flights = 0 } },
    steps = {
        { t = 5, spawn = { player = "Dex", slot = "Apache Sukhumi" } },
        -- vol 1 : 600 s = 2 pts, x1
        { t = 60, takeoff = { player = "Dex", alt = 300, speed = 70 } },
        { t = 660, land = { player = "Dex", at = "Sukhumi-Babushara" } },
        { t = 661, check = { points = { Dex = 2 }, stats = { Dex = { serie = "0" } },
            message = { { player = "Dex", has = "Serie : x1\n" }, { player = "Dex", has = "Coupe le moteur pour valider ce vol dans la serie (prochain vol x1,5)" } } } },
        { t = 670, shutdown = { player = "Dex" } },
        { t = 671, check = { stats = { Dex = { serie = "1" } }, message = { player = "Dex", has = "Serie validee, Dex : 1 vol(s) d'affilee, prochain vol x1,5" } } },
        -- vol 2 : 1200 s = 4 pts de temps + 1 kill (2 pts), x1,5 sur le kill seulement -> +1 = 7 (total 9)
        { t = 700, takeoff = { player = "Dex", alt = 300, speed = 70 } },
        { t = 1000, kill = { by = "Dex", target = "Gudauta T-72 1", distance = 4000 } },
        { t = 1900, land = { player = "Dex", at = "Sukhumi-Babushara" } },
        { t = 1901, check = { points = { Dex = 9 }, message = { player = "Dex", has = "Serie : x1,5 (+1 pts)" } } },
        { t = 1910, shutdown = { player = "Dex" } },
        { t = 1911, check = { stats = { Dex = { serie = "2" } } } },
        -- vol 3 : 100 s sans kill = trop court, la série ne bouge pas
        { t = 2000, takeoff = { player = "Dex", alt = 300, speed = 70 } },
        { t = 2100, land = { player = "Dex", at = "Sukhumi-Babushara" } },
        { t = 2101, check = { message = { player = "Dex", has = "Vol trop court pour la serie" } } },
        { t = 2110, shutdown = { player = "Dex" } },
        { t = 2111, check = { stats = { Dex = { serie = "2" } }, message = { player = "Dex", lacks = "Serie validee" } } },
        -- vol 4 : 600 s a x2 = 2 pts de temps, sans bonus (total 11) ; redécolle sans couper le moteur -> pas compté ; puis crash -> série perdue
        { t = 2200, takeoff = { player = "Dex", alt = 300, speed = 70 } },
        { t = 2800, land = { player = "Dex", at = "Sukhumi-Babushara" } },
        { t = 2801, check = { points = { Dex = 11 }, message = { player = "Dex", lacks = "Serie : x2 (+" } } },
        { t = 2900, takeoff = { player = "Dex", alt = 300, speed = 70 } },
        { t = 2950, shutdown = { player = "Dex" } }, -- en vol : ignoré
        { t = 2951, check = { stats = { Dex = { serie = "2" } } } },
        { t = 3000, die = { player = "Dex" } },
        { t = 3001, check = { stats = { Dex = { serie = "0" } }, message = { player = "Dex", has = "Serie perdue." } } },
        { t = 3100, mission_end = true },
        { t = 3101, check = { scores_file = { Dex = { serie = "0", points = 11, deaths = 1 } } } },
    },
}
