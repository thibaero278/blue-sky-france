-- 27/11 : mission Train (MISSIONS > AIR-SOL) : le groupe en activation retardee apparait au lancement, message a tous,
-- reussie quand locomotive et wagons sont detruits, puis « objectif deja detruit ».
-- Nom du groupe = celui de la vraie .miz (TRAIN) ; locomotive et wagon simplifies (la vraie : type "Train", 16 wagons).
return {
    description = "mission Train : apparait au lancement, message a tous, reussie quand loco et wagon sont detruits",
    mission = function(M)
        M.groups[#M.groups + 1] = { name = "TRAIN", kind = "TRAIN", coal = 1, late = true, x = -60000, z = 560000, units = {
            { name = "Train loco", type = "ES44AH", x = -60000, z = 560000 },
            { name = "Train wagon", type = "Coach a tank yellow", x = -60020, z = 560000 } } }
    end,
    steps = {
        { t = 5, spawn = { player = "Dex", slot = "Hornet Kobuleti" } },
        { t = 6, check = { menu = { player = "Dex", has = { "MISSIONS > AIR-SOL > Train" } },
                           ok = function(F) return not F.units["Train loco"].active, "train actif avant le lancement" end } },
        { t = 10, menu = { player = "Dex", path = "MISSIONS > AIR-SOL > Train" } },
        { t = 11, check = {
            message = { { player = "Dex", has = "Dex a lance Train : un train russe se met en route." },
                        { player = "Dex", has = "Train russe en route" } },
            ops = { Train = { left = 2 } },
            ok = function(F) return F.units["Train loco"].active, "train pas active au lancement" end } },
        { t = 20, takeoff = { player = "Dex", alt = 3000, speed = 200 } },
        { t = 100, kill = { by = "Dex", target = "Train loco", distance = 4000, weapon = "GBU_12" } },
        { t = 110, kill = { by = "Dex", target = "Train wagon", distance = 4000, weapon = "GBU_12" } },
        { t = 116, check = { message = { player = "Dex", has = "Train detruit. Mission reussie !" }, ops = { Train = false } } },
        { t = 120, menu = { player = "Dex", path = "MISSIONS > AIR-SOL > Train" } },
        { t = 121, check = { message = { player = "Dex", has = "Train : objectif deja detruit." } } },
    },
}
