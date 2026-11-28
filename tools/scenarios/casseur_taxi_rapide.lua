-- Passe casseur du 28/11 (choix de Thibaud) : rouler a plus de 50 noeuds au sol pendant 1 h gardait le vol ouvert
-- et rapportait le temps de vol (+36 pts a x3 au lieu de +3). Le temps au sol ne compte plus jamais comme du vol.
return {
    description = "casseur : taxi a 58 noeuds pendant 1 h apres le toucher, aucun temps de vol en plus",
    scores = { Dex = { points = 0, serie = "4" } },
    steps = {
        { t = 5, spawn = { player = "Dex", slot = "Hornet Kobuleti" } },
        { t = 20, takeoff = { player = "Dex", alt = 3000, speed = 200 } },
        { t = 320, land = { player = "Dex", at = "Kobuleti", speed = 30 } },
        { t = 3921, move = { player = "Dex", speed = 0 } },
        -- vol de 300 s = 1 pt a x3 = 3 (avant : 3900 s = 13 pts dont 12 bonifies -> 37)
        { t = 3940, check = { grounded = { "Dex" }, points = { Dex = 3 }, stats = { Dex = { totalFlightTime = 300, serie = "5" } } } },
    },
}
