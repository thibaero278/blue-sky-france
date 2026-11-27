-- Mission de test : les objets de la .miz DAY que "script Caucase.lua" attend, avec les noms exacts du script.
-- x = nord, z = est (y de l'éditeur), positions approchées. Renvoie une fonction qui fabrique une mission neuve.
-- shortcut: noms repris du script, pas lus dans la vraie .miz (illisible tant que DCS tourne) ; si un objet y est
-- renommé, le corriger ici aussi.
return function()
    local M = { airbases = {}, zones = {}, groups = {}, statics = {} }
    local function ab(name, x, z, coal, extra)
        local a = { name = name, x = x, z = z, coal = coal }
        for k, v in pairs(extra or {}) do a[k] = v end
        M.airbases[#M.airbases + 1] = a
    end
    local function grp(d) M.groups[#M.groups + 1] = d return d end
    local function static(name, typeName, x, z, coal) M.statics[#M.statics + 1] = { name = name, type = typeName, x = x, z = z, coal = coal or 1 } end

    -- Aérodromes (coalition : 1 rouge, 2 bleu)
    ab("Kobuleti", -317948, 636639, 2)
    ab("Senaki-Kolkhi", -281903, 648379, 2)
    ab("Sukhumi-Babushara", -221382, 565909, 2)
    ab("Tbilisi-Lochini", -315414, 896700, 2)
    ab("Gudauta", -196850, 516496, 1)
    ab("Sochi-Adler", -164474, 462236, 1)
    ab("Anapa-Vityazevo", -4448, 244022, 1)
    ab("Maykop-Khanskaya", -27626, 457048, 1)
    ab("Mineralnye Vody", -52090, 707418, 1)
    ab("Beslan", -148810, 842252, 1)
    ab("Krasnodar-Center", 11650, 368650, 1) -- 27/11 : suite de la campagne
    ab("Krasnodar-Pashkovsky", 7700, 387900, 1)
    ab("CVN-75 Harry S. Truman", -350000, 520000, 2, { kind = "SHIP" })
    -- Derricks et plateforme de Petrol Strike : statiques de type héliport = des Airbase pour DCS (pas des StaticObject),
    -- vie à 0 dès le départ (vu en jeu le 10/11)
    ab("Petrol derrick 1", -274568, 495942, 1, { kind = "HELIPAD", type = "Oil rig", life = 0 })
    ab("Petrol derrick 2", -275200, 495300, 1, { kind = "HELIPAD", type = "Oil rig", life = 0 })
    ab("Petrol platform", -274419, 495765, 1, { kind = "HELIPAD", type = "Gas platform", life = 0 })

    -- Zones de l'éditeur
    M.zones = {
        { name = "Spawn Air", x = -60000, z = 560000, r = 30000 },
        { name = "Spawn ENI", x = -80000, z = 650000, r = 40000 },
        { name = "spawn cap", quad = { { -20000, 420000 }, { -20000, 520000 }, { 40000, 520000 }, { 40000, 420000 } } },
        { name = "Destroy cap", quad = { { -60000, 400000 }, { -60000, 540000 }, { -57000, 540000 }, { -57000, 400000 } } },
        { name = "Destroy cap-2", quad = { { 45000, 400000 }, { 45000, 540000 }, { 48000, 540000 }, { 48000, 400000 } } },
    }

    -- Slots joueurs (bleus)
    grp({ name = "Apache Sukhumi", kind = "HELICOPTER", coal = 2, client = true, x = -221000, z = 565500,
          units = { { name = "Apache-1", type = "AH-64D_BLK_II" } } })
    grp({ name = "Hornet Kobuleti", kind = "AIRPLANE", coal = 2, client = true, x = -317500, z = 636300,
          units = { { name = "Hornet-1", type = "FA-18C_hornet" } } })
    grp({ name = "Hornet Kobuleti 2", kind = "AIRPLANE", coal = 2, client = true, x = -317600, z = 636400,
          units = { { name = "Hornet-2", type = "FA-18C_hornet" } } })
    -- 23/11 : transport de troupes (capture des bases) et slot Blue Sky (mode Blue Sky d'office, Mozdok dans la .miz)
    grp({ name = "Mi-8 Sukhumi", kind = "HELICOPTER", coal = 2, client = true, x = -221200, z = 565700,
          units = { { name = "Mi8-1", type = "Mi-8MT" } } })
    grp({ name = "C-130 Kobuleti", kind = "AIRPLANE", coal = 2, client = true, x = -317900, z = 636700,
          units = { { name = "Herc-1", type = "C-130J-30" } } })
    grp({ name = "Aerobatics Team", kind = "AIRPLANE", coal = 2, client = true, x = -317700, z = 636500,
          units = { { name = "Aero-1", type = "FA-18C_hornet" } } })

    -- Front russe : défense des bases (cibles des missions BASES), à moins de 8 km du centre
    grp({ name = "Gudauta defense", coal = 1, x = -196500, z = 516500, units = {
        { name = "Gudauta T-72 1", type = "T-72B", x = -196000, z = 517000 },
        { name = "Gudauta T-72 2", type = "T-72B", x = -197000, z = 516000 },
        { name = "Gudauta Tor", type = "Tor 9A331", x = -196500, z = 517500 } } })
    grp({ name = "Sochi defense", coal = 1, x = -164000, z = 462500, units = { { name = "Sochi T-72", type = "T-72B" } } })
    grp({ name = "Anapa defense", coal = 1, x = -5000, z = 244000, units = { { name = "Anapa T-72", type = "T-72B" } } })
    -- Renforts (activation retardée), en route à plus de 8 km des bases
    grp({ name = "Gudauta convoie", coal = 1, late = true, x = -185000, z = 525000, units = { { type = "T-72B" }, { type = "BMP-2" } } })
    grp({ name = "KA 50 gudauta", kind = "HELICOPTER", coal = 1, late = true, x = -196850, z = 516496, units = { { type = "Ka-50" } } })
    grp({ name = "sukumi convoie", coal = 1, late = true, x = -205000, z = 530000, units = { { type = "T-72B" } } })
    grp({ name = "sochi convoie", coal = 1, late = true, x = -150000, z = 470000, units = { { type = "T-72B" } } })
    grp({ name = "hélico sochi convoie", kind = "HELICOPTER", coal = 1, late = true, x = -150000, z = 470000, units = { { type = "Mi-24P" } } })
    grp({ name = "helico sochi", kind = "HELICOPTER", coal = 1, late = true, x = -164474, z = 462236, units = { { type = "Mi-24P" } } })
    grp({ name = "hélico anapa", kind = "HELICOPTER", coal = 1, late = true, x = -4448, z = 244022, units = { { type = "Mi-24P" } } })
    grp({ name = "KA 50 aanapa", kind = "HELICOPTER", coal = 1, late = true, x = -5229, z = 242808, units = { { type = "Ka-50" }, { type = "Ka-50" } } })
    -- Convois du nord (actifs)
    for i, name in ipairs({ "convoie-1", "convoie-2", "convoie-3", "convoie-4", "convoie-5", "convoie-6", "sochi convoie-1" }) do
        grp({ name = name, coal = 1, x = -40000, z = 600000 + i * 5000, units = { { type = "T-72B3" }, { type = "ZU-23 Emplacement" } } })
    end
    -- Croix (air-sol) : 6 groupes + 12 statiques ; convois aléatoires (modèles)
    for i = 1, 6 do grp({ name = "croix-" .. i, coal = 1, x = -250000, z = 620000 + i * 200, units = { { type = "T-55" } } }) end
    for i = 1, 12 do static("s-croix-" .. i, "Container_20ft", -250500, 620000 + i * 100) end
    -- la .miz du 14/11 n'a que conv-1 à conv-5 (le script en tire 8 au sort : bug signalé le 15/11)
    for i = 1, 5 do grp({ name = "conv-" .. i, coal = 1, late = true, x = -90000, z = 600000 + i * 1000, units = { { type = "Ural-375" } } }) end
    -- HOST Naval AERA
    grp({ name = "Admiral", kind = "SHIP", coal = 1, late = true, x = -260000, z = 420000, units = {
        { name = "Admiral-1", type = "CV_1143_5" }, { name = "Admiral-2", type = "REZKY" } } })
    -- Factory Strike : site industriel GCI-2 (statiques rouges) + son groupe de défense
    grp({ name = "Strike 1", coal = 1, x = -33400, z = 587400, units = { { name = "Strike", type = "55G6 EWR" }, { name = "Strike-2", type = "Soldier stinger" } } }) -- ex-GCI-2 (27/11)
    static("Factory tank 1", "Tank 2", -33689, 587000)
    static("Factory tank 2", "Tank 2", -33800, 587250)
    static("Factory ammo", ".Ammunition depot", -33500, 587300)
    static("Factory CP", ".Command Center", -33700, 587100)
    static("Factory sandbags", "Sandbag_02", -33689, 587167) -- exclu des cibles

    -- Avions IA (modèles en activation retardée)
    local engage = { id = "ComboTask", params = { tasks = { { id = "EngageTargets", params = { maxDist = 0, maxDistEnabled = false } } } } }
    local function air(name, coal, n, typeName, alt)
        local units = {}
        for i = 1, n or 1 do units[i] = { type = typeName or "MiG-29A" } end
        grp({ name = name, kind = "AIRPLANE", coal = coal, late = true, x = -80000, z = 650000, alt = alt or 8000, task = engage, units = units })
    end
    for _, name in ipairs({ "mig29s", "mig21", "su33", "jf17", "su27", "su34", "su25", "l39", "tu95", "escorte 95", "tu160", "escorte 160" }) do
        air(name, 1, 2)
    end
    air("TU95 inter", 1, 1, "Tu-95MS", 9144)
    air("Escorte tu95 inter", 1, 1, "Su-27", 9144)
    air("Su34 inter", 1, 2, "Su-34", 8230)
    for _, name in ipairs({ "Mig 21 Cap", "jf17 cap", "mig29 cap", "su27 cap", "mig31 cap", "su34 cap", "su30 cap", "su33 cap", "f14 cap", "M2000 Cap" }) do
        air(name, 1, 2, nil, name == "mig31 cap" and 21000 or 8000)
    end
    M.groups[#M.groups - 1].units = { { name = "F14 cap", type = "F-14A-95-GR" } } -- comme la .miz : groupe "f14 cap", unité "F14 cap"
    for _, p in ipairs({ "21-", "29-", "27-" }) do
        for i = 1, 4 do air(p .. i, 1, 2) end
    end
    for _, name in ipairs({ "S3B", "A6", "MPRS", "KC135", "KC130", "IL78" }) do air(name, 2, 1, "KC-135", 6000) end

    -- Retire un objet par son nom (groupe, statique, zone, aérodrome) : mission où il manque
    function M.remove(name)
        for _, list in ipairs({ M.groups, M.statics, M.zones, M.airbases }) do
            for i = #list, 1, -1 do if list[i].name == name then table.remove(list, i) end end
        end
    end
    function M.names()
        local all = {}
        for _, list in ipairs({ M.groups, M.statics, M.zones, M.airbases }) do
            for _, o in ipairs(list) do all[#all + 1] = o.name end
        end
        return all
    end
    return M
end
