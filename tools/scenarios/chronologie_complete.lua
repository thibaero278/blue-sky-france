-- Une partie complète : apparition, mode Blue Sky, mission BASES Gudauta, décollage, équipier qui rejoint l'AH-64 en
-- retard (et la mission avec le code), kill à 4 km, renforts, base capturée (Sochi débloquée), pose hors aéroport
-- (points ÷ 2), fin de mission et Scores.lua.
return {
    description = "partie complete en AH-64 a deux : base Gudauta capturee, pose hors aeroport, Scores.lua",
    scores = { Dex = { points = 0, flights = 0 } }, -- Scores.lua de départ (relu au chargement)
    steps = {
        { t = 5, spawn = { player = "Dex", slot = "Apache Sukhumi" } },
        { t = 7, check = {
            message = { player = "Dex", has = "Bienvenue sur Blue Sky, Dex" },
            menu = { player = "Dex", has = { "STATISTIQUES > Mes scores", "MODE BLUE SKY > Activer (au sol)",
                "DEBUG > Revalider l'atterrissage", "MISSIONS > BASES > Base Gudauta", "MISSIONS > CONVOIS > Convoi nord",
                "MISSIONS > STRIKE > Factory Strike", "MISSIONS > NAVAL > HOST Naval AERA", "MISSIONS > AIR > CAP",
                "CODE > 9_ > 99", "SPAWN > HOST A/A AERA > Su27 > Su27-4" },
                lacks = { "MISSIONS > BASES > Base Sochi", "MISSIONS > CONVOIS > Convoi Gudauta" } } } },
        { t = 16, check = { sound = { player = "Dex", file = "c00_accueil.ogg" } } }, -- 10 s après l'apparition
        { t = 20, menu = { player = "Dex", path = "MODE BLUE SKY > Activer (au sol)" } },
        { t = 21, check = { message = { player = "Dex", has = "MODE BLUE SKY ACTIF (Dex)" } } },
        { t = 30, menu = { player = "Dex", path = "MISSIONS > BASES > Base Gudauta" } },
        { t = 31, check = { message = { { player = "Dex", has = "=== MISSION Base Gudauta ===" }, { player = "Dex", has = "Bonus partage" } },
                            ops = { ["Base Gudauta"] = { left = 3 } } } },
        { t = 60, takeoff = { player = "Dex", alt = 300, speed = 70 } },
        { t = 61, check = { message = { player = "Dex", has = "DECOLLAGE DETECTE" }, pending = { Dex = 0 } } },
        -- Weefe se connecte directement en place 2 (pas de Birth pour lui)
        { t = 120, crew = { pilot = "Dex", seats = { "Dex", "Weefe" } } },
        { t = 140, check = { flying = { "Weefe" }, stats = { Weefe = { points = 0 } } } },
        { t = 150, join = { player = "Weefe", op = "Base Gudauta" } },
        { t = 151, check = { message = { player = "Weefe", has = "MISSION REJOINTE" } } },
        -- kill air-sol à 4 km (Hellfire verrouillé) : 2 pts en attente pour chacun, renforts de Gudauta activés
        { t = 300, kill = { by = "Dex", target = "Gudauta T-72 1", distance = 4000 } },
        { t = 306, check = {
            pending = { Dex = 2, Weefe = 2 },
            message = { { player = "Dex", has = "Distance de tir : 2.2 NM" }, { player = "Weefe", has = "(valides a l'atterrissage)" },
                        { player = "Dex", has = "Base Gudauta : cible detruite, reste 2" } },
            menu = { player = "Dex", has = { "MISSIONS > CONVOIS > Convoi Gudauta", "MISSIONS > CONVOIS > Convoi Soukhoumi" } } } },
        -- zone capturée : le reste de la base (T-72 2 pts + Tor 5 pts) ; prorata 3 kills chacun -> 30 pts chacun
        { t = 400, capture = { base = "Gudauta", by = "Dex", distance = 3000 } },
        { t = 406, check = {
            pending = { Dex = 39, Weefe = 39 },
            ops = { ["Base Gudauta"] = false },
            message = { { player = "Dex", has = "Base de Gudauta detruite. Mission reussie !" }, { player = "Weefe", has = "Weefe +30 pts (50 %)" },
                        { player = "Dex", has = "COMMANDEMENT : Gudauta est tombee. Nouvelle mission disponible : Sochi" } },
            sound = { player = "Dex", file = "c33_gudauta_tombee.ogg" },
            menu = { player = "Dex", has = { "MISSIONS > BASES > Base Sochi" }, lacks = { "MISSIONS > BASES > Base Gudauta" } },
            ok = function(F, env) return env.CampaignStage == 2, "CampaignStage = " .. tostring(env.CampaignStage) end } },
        -- pose dans l'herbe à 25 km de Gudauta : vol de 900 s (Dex) -> 39 + 3 = 42, ÷ 2 = 21 ; Weefe 39 + 2 = 41 -> 20
        { t = 960, land = { player = "Dex", at = { x = -205000, z = 540000 } } },
        { t = 961, check = {
            points = { Dex = 21, Weefe = 20 },
            message = { { player = "Dex", has = "Pose hors aeroport (pres de Gudauta), Dex" }, { player = "Dex", has = "points divises par 2 (-21)" },
                        { player = "Weefe", has = "points divises par 2 (-21)" }, { player = "Dex", has = "Mode Blue Sky : +15:00" } },
            stats = { Dex = { landings = 1, airsol = 3, bsFlightTime = 900, maxKillDistanceAS = 4000, minKillDistanceAS = 3000, completedFlightTime = 900 },
                      Weefe = { landings = 1, airsol = 3, bsFlightTime = 0, maxKillDistanceAS = 4000 } } } },
        { t = 1000, mission_end = true },
        { t = 1001, check = { scores_file = {
            Dex = { points = 21, airsol = 3, landings = 1, flights = 1, deaths = 0, bsFlightTime = 900, totalFlightTime = 900,
                    maxKillDistanceAS = 4000, minKillDistanceAS = 3000, maxKillsFlightAS = 3, rang = "Sous-lieutenant" },
            Weefe = { points = 20, airsol = 3, landings = 1, flights = 1, rang = "Sous-lieutenant" } } } },
    },
}
