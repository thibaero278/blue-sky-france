-- Bug vu en jeu (corrigé dans CheckAirbornePlayers, cas 2 de test_equipage_en_vol.py) : Weefe, monté en vol dans l'AH-64 de Dex après avoir quitté son Hornet, n'était pas crédité.
-- Quitter un avion le marque « mort » jusqu'au prochain Birth, et DCS n'envoie pas de Birth à qui monte dans un
-- multi-places ; en plus DCS le donne parfois comme pilote de l'Apache (pilote fantôme). Son vol doit quand même
-- démarrer (≤ 10 s après que le bot l'a vu assis), le kill compter pour les deux, l'atterrissage valider les deux.
return {
    description = "equipier monte en vol dans l'AH-64 apres un autre avion : vol, kill et atterrissage credites",
    steps = {
        { t = 5, spawn = { player = "Weefe", slot = "Hornet Kobuleti" } },
        { t = 6, spawn = { player = "Dex", slot = "Apache Sukhumi" } },
        { t = 10, takeoff = { player = "Weefe" } },
        { t = 20, takeoff = { player = "Dex", alt = 150, speed = 60 } },
        { t = 60, leave = { player = "Weefe" } },          -- quitte son Hornet en vol : vol fermé, « mort » pour cette vie
        { t = 61, check = { grounded = { "Weefe" }, stats = { Weefe = { flights = 1, deaths = 0 } } } },
        { t = 65, crew = { pilot = "Dex", seats = { "Dex", "Weefe" }, dcs_pilot = "Weefe" } },
        { t = 85, check = { flying = { "Dex", "Weefe" } } },
        -- kill : DCS l'attribue au pilote qu'il voit (Weefe), l'équipage entier a le kill
        { t = 200, kill = { by = "Dex", target = "Gudauta T-72 1", distance = 5000 } },
        { t = 201, check = { pending = { Dex = 2, Weefe = 2 }, message = { { player = "Dex", has = "GROUND TARGET" },
                                                                           { player = "Weefe", has = "Distance de tir : 2.7 NM" } } } },
        -- posé à Sukhumi après ~9 min (Dex) et ~8 min 30 (Weefe) : +1 pt de temps chacun
        { t = 600, land = { player = "Dex", at = "Sukhumi-Babushara" } },
        { t = 601, check = {
            points = { Dex = 3, Weefe = 3 },
            message = { { player = "Dex", has = "Bienvenue a Sukhumi-Babushara, Dex" }, { player = "Weefe", has = "Bienvenue a Sukhumi-Babushara, Weefe" } },
            scores_file = { Dex = { points = 3, airsol = 1, landings = 1, flights = 1 },
                            Weefe = { points = 3, airsol = 1, landings = 1, flights = 2, deaths = 0, maxKillDistanceAS = 5000 } } } },
    },
}
