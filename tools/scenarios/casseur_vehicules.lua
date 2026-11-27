-- 27/11, passe casseur sur les vehicules au lancement et la mission Train : relances apres fermeture pour inactivite,
-- convoi nord relance en boucle, train relance, kill d'un vehicule recree, vehicule recree pas compte comme deja detruit.
local function count(F, prefix)
    local n = 0
    for _, a in ipairs(F.added) do if a.data.name:find(prefix, 1, true) == 1 then n = n + 1 end end
    return n
end

return {
    description = "casseur : relances apres abandon (base, convoi nord, train), cibles recreees vivantes, pas de doublon",
    mission = function(M)
        M.groups[#M.groups + 1] = { name = "Gudauta camions", coal = 1, x = -196200, z = 516800, units = {
            { name = "Gudauta Ural 1", type = "Ural-375", x = -196200, z = 516800 } } }
        for _, g in ipairs(M.groups) do
            if g.name:find("convoie%-") then g.units = { { type = "T-72B3" } } end
        end
        M.groups[#M.groups + 1] = { name = "TRAIN", kind = "TRAIN", coal = 1, late = true, x = -60000, z = 560000, units = {
            { name = "Train loco", type = "ES44AH" } } }
    end,
    steps = {
        { t = 5, spawn = { player = "Dex", slot = "Hornet Kobuleti" } },
        -- DCS a peut-etre envoye Dead pour un vehicule retire : il ne doit pas compter comme deja detruit une fois recree
        { t = 6, lua = function(F, env) env.StrikeDead["Gudauta Ural 1"] = true end },
        { t = 10, menu = { player = "Dex", path = "MISSIONS > BASES > Base Gudauta" } },
        { t = 11, check = { ops = { ["Base Gudauta"] = { left = 4 } } } },
        { t = 12, menu = { player = "Dex", path = "MISSIONS > CONVOIS > Convoi nord" } },
        { t = 13, menu = { player = "Dex", path = "MISSIONS > AIR-SOL > Train" } },
        -- Dex quitte : missions fermees apres 10 min sans membre, puis il revient et relance tout
        { t = 20, leave = { player = "Dex" } },
        { t = 700, check = { ops = { ["Base Gudauta"] = false, ["Convoi nord"] = false, Train = false } } },
        { t = 705, spawn = { player = "Dex", slot = "Hornet Kobuleti" } },
        { t = 710, menu = { player = "Dex", path = "MISSIONS > BASES > Base Gudauta" } },
        { t = 711, check = {
            message = { player = "Dex", lacks = "les forces russes se deploient" }, -- rien a recreer : deja la
            ops = { ["Base Gudauta"] = { left = 4 } },
            ok = function(F) return count(F, "Gudauta camions") == 1, "camions recrees " .. count(F, "Gudauta camions") .. " fois" end } },
        { t = 712, menu = { player = "Dex", path = "MISSIONS > AIR-SOL > Train" } },
        { t = 713, check = { message = { player = "Dex", lacks = "un train russe se met en route" }, ops = { Train = { left = 1 } } } },
        -- Convoi nord relance : un convoi de plus (le premier est toujours la), jamais plus de 7
        { t = 714, menu = { player = "Dex", path = "MISSIONS > CONVOIS > Convoi nord" } },
        { t = 715, check = { ok = function(F)
            local n = count(F, "convoie-") + count(F, "sochi convoie-1")
            return n >= 1 and n <= 2, n .. " convois recrees"
        end } },
    },
}
