-- 23/11 : capture des bases (base videe = blanche, troupes debarquees = bleue), credits (points - creditsSpent),
-- achats (C-130 IA qui capture, CAP alliee), slot Blue Sky de Mozdok (mode d'office), Spawn ENI efface a la
-- desactivation, garde-fou de vitesse (coupure reseau a ~4000 km/h).
local function coal(F, name) return F.airbases[name].coal end

return {
    description = "capture de base par troupes et par C-130 achete, credits, CAP achetee, slot Blue Sky, Spawn ENI efface",
    scores = { Dex = { points = 100, flights = 0 } },
    steps = {
        { t = 5, spawn = { player = "Dex", slot = "Mi-8 Sukhumi" } },
        { t = 6, check = { menu = { player = "Dex", has = { "MISSIONS > CAPTURE > Embarquer des troupes",
            "MISSIONS > CAPTURE > Debarquer les troupes", "MISSIONS > CAPTURE > Mes credits",
            "MISSIONS > CAPTURE > Acheter C-130 IA (60 cr) > Sochi", "MISSIONS > CAPTURE > Acheter CAP alliee (40 cr) > Anapa" } } } },
        { t = 8, menu = { player = "Dex", path = "MISSIONS > CAPTURE > Debarquer les troupes" } },
        { t = 9, check = { message = { player = "Dex", has = "aucune troupe a bord" } } },
        { t = 10, menu = { player = "Dex", path = "MISSIONS > CAPTURE > Embarquer des troupes" } },
        { t = 11, check = { message = { player = "Dex", has = "TROUPES A BORD" } } },
        -- Gudauta encore rouge : debarquer ne capture rien
        { t = 20, takeoff = { player = "Dex", alt = 300, speed = 60 } },
        { t = 100, land = { player = "Dex", at = "Gudauta" } },
        { t = 101, menu = { player = "Dex", path = "MISSIONS > CAPTURE > Debarquer les troupes" } },
        { t = 102, check = { message = { player = "Dex", has = "pas de base blanche ici" },
                             ok = function(F) return coal(F, "Gudauta") == 1, "Gudauta pas rouge" end } },
        -- base videe (fin de la mission BASES) : blanche
        { t = 110, lua = function(F, env) env.BaseFallen("Gudauta") end },
        { t = 111, check = { message = { player = "Dex", has = "Gudauta est neutre (blanche)" },
                             ok = function(F) return coal(F, "Gudauta") == 0 and F.airbases["Gudauta"].auto == false, "Gudauta pas blanche" end } },
        { t = 120, menu = { player = "Dex", path = "MISSIONS > CAPTURE > Debarquer les troupes" } },
        { t = 121, check = {
            message = { player = "Dex", has = "Gudauta est bleue (troupes debarquees par Dex)" },
            stats = { Dex = { points = 120 } },
            ok = function(F, env)
                local soldiers = 0
                for _, a in ipairs(F.added) do for _, u in ipairs(a.data.units) do if u.type == "Soldier M4" then soldiers = soldiers + 1 end end end
                return coal(F, "Gudauta") == 2 and soldiers == 4 and env.BaseState.Gudauta == "blue",
                    "Gudauta : coalition " .. tostring(coal(F, "Gudauta")) .. ", " .. soldiers .. " soldats"
            end } },
        -- troupes deja debarquees : rien a refaire
        { t = 125, menu = { player = "Dex", path = "MISSIONS > CAPTURE > Debarquer les troupes" } },
        { t = 126, check = { message = { player = "Dex", has = "aucune troupe a bord" } } },
        -- achats : Weefe (0 credit) refuse ; Dex (120) achete un C-130 pour Sochi, blanche
        { t = 130, lua = function(F, env) env.BaseFallen("Sochi") end },
        { t = 131, spawn = { player = "Weefe", slot = "Aerobatics Team" } },
        { t = 132, check = { message = { player = "Weefe", has = "SLOT BLUE SKY" },
                             ok = function(F, env) return env.BSMode.Weefe == true, "mode Blue Sky pas actif d'office" end } },
        { t = 135, menu = { player = "Weefe", path = "MISSIONS > CAPTURE > Acheter C-130 IA (60 cr) > Sochi" } },
        { t = 136, check = { message = { player = "Weefe", has = "ACHAT REFUSE : 60 credits, pas assez pour Weefe (0)" } } },
        { t = 140, menu = { player = "Dex", path = "MISSIONS > CAPTURE > Acheter C-130 IA (60 cr) > Sochi" } },
        { t = 141, check = { message = { player = "Dex", has = "ACHAT : Dex (60 credits) : C-130 IA en route vers Sochi" },
                             stats = { Dex = { creditsSpent = 60, points = 120 } },
                             ok = function(F) return F.units["ACHAT CARGO 2-1"] ~= nil and F.units["ACHAT CARGO 2-1"].type == "C-130", "pas de C-130" end } },
        { t = 145, menu = { player = "Dex", path = "MISSIONS > CAPTURE > Acheter C-130 IA (60 cr) > Sochi" } },
        { t = 146, check = { message = { player = "Dex", has = "un transport est deja en route vers Sochi" }, stats = { Dex = { creditsSpent = 60 } } } },
        -- le C-130 se pose a Sochi : capture, sans bonus (achete)
        { t = 500, lua = function(F)
            local u = F.units["ACHAT CARGO 2-1"]
            u.x, u.z, u.air, u.y = F.airbases["Sochi-Adler"].x, F.airbases["Sochi-Adler"].z, false, 0
            F.event("Land", { initiator = u, place = F.airbases["Sochi-Adler"] })
        end },
        { t = 501, check = { message = { player = "Weefe", has = "Sochi est bleue (C-130 IA achete par Dex)" },
                             stats = { Dex = { points = 120 } },
                             ok = function(F, env) return coal(F, "Sochi-Adler") == 2 and not env.BuyBusy.Sochi, "Sochi pas bleue" end } },
        { t = 625, check = { ok = function(F) return not F.units["ACHAT CARGO 2-1"].exists, "C-130 pas retire apres la pose" end } },
        -- CAP alliee sur Anapa : 2 F-15C armes ; une 2e refusee (plus assez de credits)
        { t = 630, menu = { player = "Dex", path = "MISSIONS > CAPTURE > Acheter CAP alliee (40 cr) > Anapa" } },
        { t = 631, check = { message = { player = "Dex", has = "2 F-15C en CAP au-dessus de Anapa" },
                             stats = { Dex = { creditsSpent = 100 } },
                             ok = function(F)
                                 local a = F.added[#F.added]
                                 local pyl = 0
                                 for _ in pairs(a.data.units[1].payload.pylons) do pyl = pyl + 1 end
                                 return a.data.units[1].type == "F-15C" and #a.data.units == 2 and pyl == 11, "CAP mal formee"
                             end } },
        { t = 635, menu = { player = "Dex", path = "MISSIONS > CAPTURE > Acheter CAP alliee (40 cr) > Anapa" } },
        { t = 636, check = { message = { player = "Dex", has = "pas assez pour Dex (20)" } } },
        { t = 640, menu = { player = "Dex", path = "MISSIONS > CAPTURE > Mes credits" } },
        { t = 641, check = { message = { player = "Dex", has = "CREDITS de Dex : 20" } } },
        { t = 2500, check = { ok = function(F) return not F.units["ACHAT CAP 3-1"].exists, "CAP pas rentree apres 30 min" end } },
        -- slot Blue Sky : le mode reprend apres chaque atterrissage tant qu'on reste dans l'avion
        { t = 2510, takeoff = { player = "Weefe", alt = 3000, speed = 200 } },
        -- coupure reseau : 1150 m/s pendant 5 s, jamais un record
        { t = 2600, move = { player = "Weefe", speed = 1150 } },
        { t = 2605, move = { player = "Weefe", speed = 200 } },
        { t = 3110, land = { player = "Weefe", at = "Kobuleti" } },
        { t = 3111, check = { stats = { Weefe = { bsFlightTime = 600, maxSpeed = 200 } },
                              message = { player = "Dex", has = "Vol le plus long : Weefe (FA-18C_hornet)" }, -- avion du record
                              ok = function(F, env) return env.BSMode.Weefe == true, "mode Blue Sky pas repris apres l'atterrissage" end } },
        -- Spawn ENI : desactiver efface les avions ENI en l'air
        { t = 3120, menu = { player = "Dex", path = "SPAWN > Spawn ENI > Activer" } },
        { t = 3200, check = { ok = function(F, env) return #env.EniGroups > 0 and env.EniGroups[1]:IsAlive(), "aucune vague ENI" end } },
        { t = 3210, menu = { player = "Dex", path = "SPAWN > Spawn ENI > Desactiver" } },
        { t = 3211, check = { message = { player = "Dex", has = "ENI retire(s)" },
                              ok = function(F, env)
                                  for _, g in ipairs(F.groupList) do
                                      if g.name:find("#", 1, true) and g:isExist() and g.coal == 1 and g.kind == "AIRPLANE" then return false, "encore en l'air : " .. g.name end
                                  end
                                  return #env.EniGroups == 0, "liste ENI pas videe"
                              end } },
        { t = 3300, mission_end = true },
        { t = 3301, check = { scores_file = { Dex = { points = 120, creditsSpent = 100 } } } },
    },
}
