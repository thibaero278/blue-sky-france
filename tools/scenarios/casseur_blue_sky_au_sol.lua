-- 27/11 (passe casseur du 20/11) : DCS rate l'atterrissage, le vol reste ouvert au sol. Avant : Activer / Desactiver
-- le mode Blue Sky en boucle ajoutait tout le vol a chaque fois, et le parking comptait comme du vol (DEBUG apres 1 h).
-- Le temps Blue Sky compte depuis l'activation. Serie v2 (28/11) : le vol se ferme apres 10 s au sol sous 50 noeuds,
-- sans event Land et sans compter ces 10 s (avant : 1 min a l'arret).
local function stop(F) local u = F.unitOf("Dex") u.air, u.y, u.speed = false, 0, 0 end

return {
    description = "Blue Sky au sol : temps compte depuis l'activation, vol ferme seul apres 10 s au sol, sans l'attente",
    steps = {
        { t = 5, spawn = { player = "Dex", slot = "Hornet Kobuleti" } },
        { t = 20, takeoff = { player = "Dex", alt = 1000, speed = 150 } },
        -- pose a t=600 sans evenement Land (vu en jeu, d'ou le menu DEBUG) ; arret vu au test suivant (t=601)
        { t = 600, lua = stop },
        { t = 601, check = { flying = { "Dex" } } },
        -- 1 aller-retour Activer / Desactiver de 2 s, puis mode laisse actif a t=606
        { t = 602, menu = { player = "Dex", path = "MODE BLUE SKY > Activer (au sol)" } },
        { t = 604, menu = { player = "Dex", path = "MODE BLUE SKY > Desactiver" } },
        { t = 606, menu = { player = "Dex", path = "MODE BLUE SKY > Activer (au sol)" } },
        { t = 607, check = { stats = { Dex = { bsFlightTime = 2 } }, flying = { "Dex" } } },
        { t = 610, check = { flying = { "Dex" } } },
        { t = 612, check = {
            grounded = { "Dex" },
            message = { player = "Dex", has = "Bienvenue a Kobuleti" },
            -- vol : 20 -> 611 moins 10 s au sol = 581 s ; Blue Sky : 2 + (611 - 606 = 5) = 7 s
            stats = { Dex = { landings = 1, totalFlightTime = 581, bsFlightTime = 7 } },
            log = { has = "atterrissage valide pour Dex a Kobuleti (10 s au sol sous 50 kt)" } } },
    },
}
