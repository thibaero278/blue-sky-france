-- Bug vu en jeu le 10/11 : Petrol Strike répondait « objectif deja detruit » avec les derricks intacts. Les derricks
-- et la plateforme sont des statiques de type héliport, donc des Airbase pour DCS (pas dans coalition.getStaticObjects),
-- avec une vie à 0 dès le départ. La mission doit les trouver, avancer cible par cible (événement Dead, pas de Kill),
-- payer les membres, puis seulement là répondre « deja detruit ».
return {
    description = "Petrol Strike trouve ses 3 cibles (Airbase a vie 0), progresse, paie, puis deja detruit",
    steps = {
        { t = 5, spawn = { player = "Dex", slot = "Hornet Kobuleti" } },
        { t = 6, spawn = { player = "Weefe", slot = "Hornet Kobuleti 2" } },
        { t = 10, menu = { player = "Dex", path = "MISSIONS > STRIKE > Petrol Strike" } },
        { t = 11, check = {
            message = { { player = "Dex", has = "=== MISSION Petrol Strike ===" }, { player = "Dex", has = "CODE DE LA MISSION" },
                        { player = "Dex", lacks = "deja detruit" } },
            ops = { ["Petrol Strike"] = { left = 3 } } } },
        { t = 12, join = { player = "Weefe", op = "Petrol Strike" } },
        { t = 13, check = { message = { { player = "Weefe", has = "MISSION REJOINTE" }, { player = "Dex", has = "Weefe a rejoint" } } } },
        { t = 20, takeoff = { player = "Dex" } },
        { t = 100, destroy = { targets = { "Petrol derrick 1" } } },
        { t = 106, check = { message = { { player = "Dex", has = "Petrol Strike : cible detruite, reste 2" },
                                         { player = "Weefe", has = "reste 2" } } } },
        { t = 200, destroy = { targets = { "Petrol derrick 2", "Petrol platform" } } },
        -- aucun kill crédité (pas d'événement Kill sur un derrick) : bonus égal (20) à chaque membre vivant
        { t = 206, check = {
            message = { { player = "Dex", has = "Champ petrolier detruit. Mission reussie !" }, { player = "Weefe", has = "+20 pts pour" } },
            ops = { ["Petrol Strike"] = false },
            pending = { Dex = 20 },  -- en vol : en attente de l'atterrissage
            points = { Weefe = 20 } } }, -- au sol : validés tout de suite
        { t = 210, menu = { player = "Dex", path = "MISSIONS > STRIKE > Petrol Strike" } },
        { t = 211, check = { message = { player = "Dex", has = "Petrol Strike : objectif deja detruit." }, ops = { ["Petrol Strike"] = false } } },
        -- 380 s de vol : +1 pt de temps ; posé à Kobuleti
        { t = 400, land = { player = "Dex", at = "Kobuleti" } },
        { t = 411, check = { points = { Dex = 21, Weefe = 20 }, message = { player = "Dex", has = "Bienvenue a Kobuleti" },
                             scores_file = { Dex = { points = 21, landings = 1, flights = 1 }, Weefe = { points = 20, flights = 0 } } } },
    },
}
