-- 27/11 : TRAIN pose bleu dans l'editeur (vu dans la .miz du 27/11 a 1 h 51) : la mission ne doit jamais en faire une cible.
return {
    description = "train bleu dans l'editeur : pas de mission Train sur un train ami, avertissement dans dcs.log",
    mission = function(M)
        M.groups[#M.groups + 1] = { name = "TRAIN", kind = "TRAIN", coal = 2, x = -200845, z = 543318, units = {
            { name = "TRAIN", type = "Train" } } }
    end,
    warnings = { "TRAIN n'est pas rouge dans l'editeur" },
    steps = {
        { t = 5, spawn = { player = "Dex", slot = "Hornet Kobuleti" } },
        { t = 10, menu = { player = "Dex", path = "MISSIONS > AIR-SOL > Train" } },
        { t = 11, check = { ops = { Train = false }, message = { player = "Dex", lacks = "un train russe se met en route" },
                            log = { has = "TRAIN n'est pas rouge dans l'editeur" } } },
    },
}
