-- 24/11 : F10 > LOGISTIQUE. C-130 : troupes, 2 Humvee Avenger (defense AA, dechargeables partout) ou caisse ;
-- helicos (Mi-8...) : troupes seulement ; pas de menu dans un chasseur. Avion du record garde dans Scores.lua (site).
local function added(F, typeName)
    local n = 0
    for _, a in ipairs(F.added) do
        if a.static then n = n + (a.data.type == typeName and 1 or 0)
        else for _, u in ipairs(a.data.units) do n = n + (u.type == typeName and 1 or 0) end end
    end
    return n
end

return {
    description = "logistique : C-130 (Humvee Avenger hors base, caisse qui capture), Mi-8 troupes seulement, avion du record",
    steps = {
        { t = 5, spawn = { player = "Dex", slot = "C-130 Kobuleti" } },
        { t = 6, spawn = { player = "Weefe", slot = "Mi-8 Sukhumi" } },
        { t = 7, spawn = { player = "Joker", slot = "Hornet Kobuleti" } },
        { t = 9, check = { menu = {
            { player = "Dex", has = { "LOGISTIQUE > Charger des troupes", "LOGISTIQUE > Charger 2 Humvee Avenger (AA)", "LOGISTIQUE > Charger une caisse", "LOGISTIQUE > Decharger" } },
            { player = "Weefe", has = { "LOGISTIQUE > Charger des troupes", "LOGISTIQUE > Decharger" }, lacks = { "LOGISTIQUE > Charger une caisse", "LOGISTIQUE > Charger 2 Humvee Avenger (AA)" } },
            { player = "Joker", lacks = { "LOGISTIQUE > Charger des troupes", "LOGISTIQUE > Decharger" } } } } },
        -- Humvee charges a Kobuleti, decharges en campagne : defense AA, pas de capture
        { t = 10, menu = { player = "Dex", path = "LOGISTIQUE > Charger 2 Humvee Avenger (AA)" } },
        { t = 11, check = { message = { player = "Dex", has = "2 HUMVEE AVENGER A BORD" } } },
        { t = 12, menu = { player = "Dex", path = "LOGISTIQUE > Charger une caisse" } },
        { t = 13, check = { message = { player = "Dex", has = "soute deja pleine (2 HUMVEE AVENGER)" } } },
        -- passe casseur du 24/11 : decharger sans avoir vole depuis le chargement (avant : 40 Avenger en 40 s sur Kobuleti)
        { t = 14, menu = { player = "Dex", path = "LOGISTIQUE > Decharger" } },
        { t = 15, check = { message = { player = "Dex", has = "decolle et pose-toi ailleurs" },
                            ok = function(F) return added(F, "M1097 Avenger") == 0, "Avenger sans vol" end } },
        { t = 20, takeoff = { player = "Dex", alt = 3000, speed = 140 } },
        { t = 1820, land = { player = "Dex", at = { x = -250000, z = 600000 } } },
        -- serie v2 : decharger avant les 10 s au sol = refuse, atterrissage pas encore valide
        { t = 1821, menu = { player = "Dex", path = "LOGISTIQUE > Decharger" } },
        { t = 1822, check = { message = { player = "Dex", has = "atterrissage pas encore valide" },
                              ok = function(F) return added(F, "M1097 Avenger") == 0, "Avenger avant validation" end } },
        { t = 1831, menu = { player = "Dex", path = "LOGISTIQUE > Decharger" } },
        { t = 1832, check = { message = { player = "Dex", has = "defense antiaerienne en place" },
                              ok = function(F) return added(F, "M1097 Avenger") == 2, "Avenger : " .. added(F, "M1097 Avenger") end } },
        -- caisse : refusee hors base blanche, capture Gudauta une fois blanche
        { t = 1835, takeoff = { player = "Dex", alt = 1000, speed = 140 } },
        { t = 1840, land = { player = "Dex", at = "Kobuleti" } },
        { t = 1851, menu = { player = "Dex", path = "LOGISTIQUE > Charger une caisse" } },
        { t = 1855, lua = function(F, env) env.BaseFallen("Gudauta") end },
        { t = 1860, takeoff = { player = "Dex", alt = 1000, speed = 140 } },
        { t = 1870, land = { player = "Dex", at = "Gudauta" } },
        { t = 1881, menu = { player = "Dex", path = "LOGISTIQUE > Decharger" } },
        { t = 1882, check = { message = { player = "Joker", has = "Gudauta est bleue (caisse dechargee par Dex)" },
                              ok = function(F) return F.airbases["Gudauta"].coal == 2 and added(F, "container_cargo") == 1, "caisse / capture" end } },
        -- Mi-8 : ne peut pas charger de vehicules meme par la commande
        { t = 1890, lua = function(F, env) env.LogiLoad(env.GROUP:FindByName("Mi-8 Sukhumi"), "vehicules") end },
        { t = 1891, check = { message = { player = "Weefe", has = "vehicules et caisses : C-130 seulement" } } },
        -- avion du record (vol de Dex de 1800 s, premier record : pas d'annonce, mais garde) jusque dans Scores.lua
        { t = 1900, mission_end = true },
        { t = 1901, check = { scores_file = { Dex = { maxFlightTimeAc = "C-130J-30" } } } },
    },
}
