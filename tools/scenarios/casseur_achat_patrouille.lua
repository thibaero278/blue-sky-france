-- Passe casseur du 23/11 : dans un groupe a plusieurs avions, DCS ne dit pas qui clique dans F10. Avant : le plus riche
-- payait seul (un joueur a 0 credit depensait ceux de Branch). Maintenant chacun paie sa part, refus si l'un n'a pas assez.
return {
    description = "achat dans une patrouille a deux : chacun paie sa part, refus si l'un n'a pas assez",
    scores = { Branch = { points = 1000 }, Noob = { points = 0 } },
    mission = function(M)
        M.groups[#M.groups + 1] = { name = "Case I", kind = "AIRPLANE", coal = 2, client = true, x = -317800, z = 636600,
            units = { { name = "CaseI-1", type = "FA-18C_hornet" }, { name = "CaseI-2", type = "FA-18C_hornet", x = -317820, z = 636620 } } }
    end,
    steps = {
        { t = 5, spawn = { player = "Branch", slot = "Case I" } },
        { t = 6, lua = function(F)
            local u = F.units["CaseI-2"]
            u.exists, u.active, u.player, u.seats, u.x, u.z = true, true, "Noob", { "Noob" }, -317820, 636620
            F.event("Birth", { initiator = u })
        end },
        { t = 20, menu = { player = "Noob", path = "MISSIONS > CAPTURE > Acheter CAP alliee (40 cr) > Anapa" } },
        { t = 21, check = { message = { { player = "Noob", has = "pas assez pour Noob (0)" }, { player = "Branch", has = "20 chacun" } },
                            stats = { Branch = { creditsSpent = 0 } },
                            ok = function(F) return #F.added == 0, "CAP partie quand meme" end } },
        { t = 30, lua = function(F, env) env.Scores.Noob.points = 25 end },
        { t = 31, menu = { player = "Noob", path = "MISSIONS > CAPTURE > Acheter CAP alliee (40 cr) > Anapa" } },
        { t = 32, check = { message = { player = "Branch", has = "ACHAT : Branch, Noob (40 credits, 20 chacun)" },
                            stats = { Branch = { creditsSpent = 20 }, Noob = { creditsSpent = 20 } } } },
    },
}
