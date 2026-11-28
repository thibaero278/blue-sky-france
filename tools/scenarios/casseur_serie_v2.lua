-- Passe casseur de la série v2 (28/11) : sur un porte-avions en route, la vitesse compte par rapport au navire ;
-- encore trop rapide sur le pont = pas validé ; train cassé = vol neutre ; slot quitté en vol = série perdue.
local CVN = "CVN-75 Harry S. Truman"
return {
    description = "casseur serie v2 : PA en route (vitesse relative), train casse, slot quitte en vol",
    scores = { Dex = { points = 0, flights = 0 } },
    steps = {
        { t = 5, spawn = { player = "Dex", slot = "Hornet Kobuleti" } },
        { t = 20, takeoff = { player = "Dex", alt = 3000, speed = 200 } },
        -- PA à 15 m/s ; avion posé à 50 m/s (35 m/s = 68 nœuds par rapport au pont) : pas validé
        { t = 600, lua = function(F) F.airbases[CVN].speed = 15 end },
        { t = 620, land = { player = "Dex", at = CVN, speed = 50 } },
        { t = 635, check = { flying = { "Dex" } } },
        -- 30 m/s absolu (58 nœuds) mais 15 m/s par rapport au pont : validé 10 s plus tard
        { t = 636, move = { player = "Dex", speed = 30 } },
        { t = 646, check = { flying = { "Dex" } } },
        { t = 648, check = { grounded = { "Dex" }, points = { Dex = 2 }, stats = { Dex = { traps = 1, landings = 0, serie = "1" } },
            message = { player = "Dex", has = "AIRBOSS - CVN-75" } } },
        -- train cassé à l'appontage : troll, vol neutre (points sans bonus, série inchangée, pas d'appontage)
        { t = 800, takeoff = { player = "Dex", alt = 3000, speed = 200 } },
        { t = 1390, lua = function(F) F.unitOf("Dex").gear = 0.5 end },
        { t = 1400, land = { player = "Dex", at = CVN, speed = 15 } },
        { t = 1411, check = { points = { Dex = 4 }, stats = { Dex = { traps = 1, serie = "1" } },
            message = { player = "Dex", has = "Serie : pose rate, vol neutre (1 vol(s), x1,5)" } } },
        -- slot quitté en vol : série perdue
        { t = 1600, lua = function(F) F.unitOf("Dex").gear = 1 end },
        { t = 1601, takeoff = { player = "Dex", alt = 3000, speed = 200 } },
        { t = 1700, leave = { player = "Dex" } },
        { t = 1701, check = { stats = { Dex = { serie = "0", deaths = 0, traps = 1 } }, points = { Dex = 4 } } },
    },
}
