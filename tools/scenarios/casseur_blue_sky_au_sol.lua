-- 27/11 (passe casseur du 20/11) : DCS rate l'atterrissage, le vol reste ouvert au sol. Avant : Activer / Desactiver
-- le mode Blue Sky en boucle ajoutait tout le vol a chaque fois, et le parking comptait comme du vol (DEBUG apres 1 h).
-- Maintenant : le temps Blue Sky compte depuis l'activation, et le vol se ferme seul apres 1 min a l'arret.
local function stop(F) local u = F.unitOf("Dex") u.air, u.y, u.speed = false, 0, 0 end

return {
    description = "Blue Sky au sol : temps compte depuis l'activation, vol ferme seul apres 1 min a l'arret, sans l'attente",
    steps = {
        { t = 5, spawn = { player = "Dex", slot = "Hornet Kobuleti" } },
        { t = 20, takeoff = { player = "Dex", alt = 1000, speed = 150 } },
        -- pose a t=600 sans evenement Land (vu en jeu, d'ou le menu DEBUG)
        { t = 600, lua = stop },
        { t = 601, check = { flying = { "Dex" } } },
        -- 2 allers-retours Activer / Desactiver de 2 s, puis mode laisse actif a t=620
        { t = 610, menu = { player = "Dex", path = "MODE BLUE SKY > Activer (au sol)" } },
        { t = 612, menu = { player = "Dex", path = "MODE BLUE SKY > Desactiver" } },
        { t = 615, menu = { player = "Dex", path = "MODE BLUE SKY > Activer (au sol)" } },
        { t = 617, menu = { player = "Dex", path = "MODE BLUE SKY > Desactiver" } },
        { t = 620, menu = { player = "Dex", path = "MODE BLUE SKY > Activer (au sol)" } },
        { t = 621, check = { stats = { Dex = { bsFlightTime = 4 } }, flying = { "Dex" } } },
        -- arret vu a t=605 (test toutes les 5 s) : ferme a t=665, comme un atterrissage, sans la minute d'attente
        { t = 660, check = { flying = { "Dex" } } },
        { t = 666, check = {
            grounded = { "Dex" },
            message = { player = "Dex", has = "Bienvenue a Kobuleti" },
            -- vol : 20 -> 665 moins 60 s d'arret = 585 s ; Blue Sky : 2 + 2 + (665 - 620 = 45) = 49 s
            stats = { Dex = { landings = 1, totalFlightTime = 585, bsFlightTime = 49 } },
            log = { has = "atterrissage non vu par DCS, vol ferme apres 60 s a l'arret pour Dex" } } },
    },
}
