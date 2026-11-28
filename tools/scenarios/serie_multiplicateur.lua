-- Série v2 (28/11, choix de Thibaud du 27/11) : atterrissage validé = 10 s au sol sous 50 nœuds, la série monte tout de
-- suite (plus de coupure moteur). Rebond, touch-and-go : le vol continue. Vol trop court = série inchangée. Redécoller
-- moins de 2 min après l'atterrissage = vol neutre. Bonus sur les points de combat et sur ceux de la 1re heure de vol.
-- Slot quitté au sol pendant les 10 s = atterrissage validé. Mort = série perdue. s.serie est une chaîne.
return {
    description = "serie v2 : 10 s au sol, x1,5 sur kill + temps, vol court, redecollage trop tot, rebonds, 1re heure, slot quitte au sol, mort",
    scores = { Dex = { points = 0, flights = 0 } },
    steps = {
        { t = 5, spawn = { player = "Dex", slot = "Apache Sukhumi" } },
        -- vol 1 : 600 s = 2 pts, x1 ; validé 10 s après le toucher, pas avant
        { t = 60, takeoff = { player = "Dex", alt = 300, speed = 70 } },
        { t = 660, land = { player = "Dex", at = "Sukhumi-Babushara" } },
        { t = 665, check = { flying = { "Dex" }, points = { Dex = 0 }, stats = { Dex = { serie = "0" } } } },
        { t = 671, check = { grounded = { "Dex" }, points = { Dex = 2 }, stats = { Dex = { serie = "1", landings = 1 } },
            message = { { player = "Dex", has = "Serie : x1\n" },
                        { player = "Dex", has = "Serie validee : 1 vol(s) d'affilee, prochain vol x1,5 (reste 2 min au sol)" },
                        { player = "Dex", lacks = "Coupe le moteur" } } } },
        -- vol 2 : 1200 s = 4 pts de temps + 1 kill (2 pts), x1,5 sur les deux -> +3 = 9 (total 11)
        { t = 800, takeoff = { player = "Dex", alt = 300, speed = 70 } },
        { t = 801, check = { message = { player = "Dex", lacks = "ne compte pas pour la serie" } } },
        { t = 1000, kill = { by = "Dex", target = "Gudauta T-72 1", distance = 4000 } },
        { t = 2000, land = { player = "Dex", at = "Sukhumi-Babushara" } },
        { t = 2011, check = { points = { Dex = 11 }, stats = { Dex = { serie = "2" } }, message = { player = "Dex", has = "Serie : x1,5 (+3 pts)" } } },
        -- vol 3 : 100 s sans kill = trop court, la série ne bouge pas
        { t = 2140, takeoff = { player = "Dex", alt = 300, speed = 70 } },
        { t = 2240, land = { player = "Dex", at = "Sukhumi-Babushara" } },
        { t = 2251, check = { stats = { Dex = { serie = "2" } }, message = { player = "Dex", has = "Vol trop court pour la serie" } } },
        -- vol 4 : redécolle 50 s après -> alerte, vol neutre (2 pts sans bonus, série inchangée, total 13)
        { t = 2300, takeoff = { player = "Dex", alt = 300, speed = 70 } },
        { t = 2301, check = { message = { player = "Dex", has = "Redecolle apres 50 s : ce vol ne compte pas pour la serie (2 min au sol entre deux vols)." } } },
        { t = 2900, land = { player = "Dex", at = "Sukhumi-Babushara" } },
        { t = 2911, check = { points = { Dex = 13 }, stats = { Dex = { serie = "2" } },
            message = { player = "Dex", has = "Serie : redecolle trop tot, vol neutre (2 vol(s), x2)" } } },
        -- vol 5 : touch-and-go à 60 m/s puis rebond de 2 s : le vol continue, sans ses 4 s au sol ; 1206 s à x2 = 4 + 4 (total 21)
        { t = 3100, takeoff = { player = "Dex", alt = 300, speed = 70 } },
        { t = 3400, land = { player = "Dex", at = "Sukhumi-Babushara", speed = 60 } },
        { t = 3402, takeoff = { player = "Dex", alt = 100, speed = 70 } },
        { t = 3420, check = { flying = { "Dex" }, points = { Dex = 13 } } },
        { t = 3700, land = { player = "Dex", at = "Sukhumi-Babushara" } },
        { t = 3702, takeoff = { player = "Dex", alt = 50, speed = 40 } },
        { t = 3720, check = { flying = { "Dex" }, points = { Dex = 13 }, stats = { Dex = { serie = "2", landings = 4 } } } },
        { t = 4310, land = { player = "Dex", at = "Sukhumi-Babushara" } },
        { t = 4321, check = { points = { Dex = 21 }, stats = { Dex = { serie = "3", landings = 5 } }, message = { player = "Dex", has = "Serie : x2 (+4 pts)" } } },
        -- vol 6 : 2 h à x2,5 = 24 pts de temps, bonus sur la 1re heure seulement : 12 x 1,5 = +18 -> 42 (total 63)
        { t = 4500, takeoff = { player = "Dex", alt = 300, speed = 70 } },
        { t = 11700, land = { player = "Dex", at = "Sukhumi-Babushara" } },
        { t = 11711, check = { points = { Dex = 63 }, message = { player = "Dex", has = "Serie : x2,5 (+18 pts)" } } },
        -- vol 7 : 1 h à x3 = 12 + 24 = 36 pts (exemple de Thibaud, total 99)
        { t = 11900, takeoff = { player = "Dex", alt = 300, speed = 70 } },
        { t = 15500, land = { player = "Dex", at = "Sukhumi-Babushara" } },
        { t = 15511, check = { points = { Dex = 99 }, stats = { Dex = { serie = "5" } }, message = { player = "Dex", has = "Serie : x3 (+24 pts)" } } },
        -- vol 8 : quitte le slot 3 s après le toucher, au sol : atterrissage validé (600 s à x3 = 2 + 4, total 105)
        { t = 15700, takeoff = { player = "Dex", alt = 300, speed = 70 } },
        { t = 16300, land = { player = "Dex", at = "Sukhumi-Babushara" } },
        { t = 16303, leave = { player = "Dex" } },
        { t = 16304, check = { points = { Dex = 105 }, stats = { Dex = { serie = "6", deaths = 0, landings = 8 } } } },
        -- puis crash : série perdue
        { t = 16400, spawn = { player = "Dex", slot = "Apache Sukhumi" } },
        { t = 16600, takeoff = { player = "Dex", alt = 300, speed = 70 } },
        { t = 16700, die = { player = "Dex" } },
        { t = 16701, check = { stats = { Dex = { serie = "0" } }, message = { player = "Dex", has = "Serie perdue." } } },
        { t = 16800, mission_end = true },
        { t = 16801, check = { scores_file = { Dex = { serie = "0", points = 105, deaths = 1, landings = 8 } } } },
    },
}
