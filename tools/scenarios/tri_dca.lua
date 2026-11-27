-- 27/11 : tri de Thibaud. Restent en permanence : groupe avec un missile sol-air (SAM, MANPADS) ou un C-RAM, garde
-- entier ; ZU-23 seulement en majorite. Les autres canons suivent les blindes. Krasnodar : tout apparait avec la mission.
-- Campagne : Anapa -> Pashkovsky (50) -> Krasnodar (70).
local function exists(F, name) local u = F.units[name] return u ~= nil and u.exists end
local G = { x = -196300, z = 516700 } -- dans la base de Gudauta
local function grp(M, name, x, z, units)
    for i, u in ipairs(units) do u.name, u.x, u.z = name .. " " .. i, x + i * 20, z end
    M.groups[#M.groups + 1] = { name = name, coal = 1, x = x, z = z, units = units }
end

return {
    description = "tri DCA : SAM / MANPADS / C-RAM gardent leur groupe, ZU-23 en majorite, Krasnodar tout retire, base Krasnodar",
    mission = function(M)
        grp(M, "conv ZU", G.x, G.z, { { type = "T-72B" }, { type = "T-72B" }, { type = "T-72B" }, { type = "ZU-23 Emplacement" } })
        grp(M, "batterie ZU", G.x + 300, G.z, { { type = "ZU-23 Emplacement" }, { type = "ZU-23 Emplacement" }, { type = "BTR-80" } })
        grp(M, "Shilka BTR", G.x + 600, G.z, { { type = "ZSU-23-4 Shilka" }, { type = "BTR-80" } })
        grp(M, "C-RAM BTR", G.x + 900, G.z, { { type = "HEMTT_C-RAM_Phalanx" }, { type = "BTR-80" }, { type = "BTR-80" } })
        grp(M, "Stinger T-72", G.x + 1200, G.z, { { type = "Soldier stinger" }, { type = "T-72B" }, { type = "T-72B" } })
        grp(M, "Krasnodar", 11700, 368700, { { type = "KS-19" }, { type = "KS-19" }, { type = "Tor 9A331" } })
        grp(M, "PASH", 7800, 387900, { { type = "Tor 9A331" } })
        grp(M, "PASH-2", 7900, 388000, { { type = "T-72B" }, { type = "T-72B" } })
    end,
    steps = {
        { t = 1, check = { ok = function(F)
            local want = { ["conv ZU 1"] = false, ["batterie ZU 1"] = true, ["Shilka BTR 1"] = false, ["C-RAM BTR 2"] = true,
                           ["Stinger T-72 2"] = true, ["Krasnodar 3"] = false, ["PASH 1"] = true, ["PASH-2 1"] = false }
            for name, keep in pairs(want) do
                if exists(F, name) ~= keep then return false, name .. (keep and " retire a tort" or " pas retire") end
            end
            return true
        end } },
        -- Anapa tombe : Pashkovsky s'ouvre ; puis Pashkovsky : Krasnodar
        { t = 5, spawn = { player = "Dex", slot = "Hornet Kobuleti" } },
        { t = 6, lua = function(F, env) env.CampaignStage = 4 env.RefreshMissionMenus() end },
        { t = 7, check = { menu = { player = "Dex", has = { "MISSIONS > BASES > Base Pashkovsky" }, lacks = { "MISSIONS > BASES > Base Anapa" } } } },
        { t = 8, lua = function(F, env) env.CampaignStage = 5 env.RefreshMissionMenus() end },
        { t = 10, menu = { player = "Dex", path = "MISSIONS > BASES > Base Krasnodar" } },
        { t = 11, check = {
            message = { { player = "Dex", has = "Dex a lance Base Krasnodar : les forces russes se deploient." },
                        { player = "Dex", has = "Base aerienne de Krasnodar-Center" } },
            ops = { ["Base Krasnodar"] = { left = 3 } },
            ok = function(F) return exists(F, "Krasnodar 1") and exists(F, "Krasnodar 3"), "Krasnodar pas recree" end } },
        -- Krasnodar videe : fin de la campagne, la base passe blanche
        { t = 20, lua = function(F, env) for i = 1, 3 do env.StrikeDead["Krasnodar " .. i] = true end end },
        { t = 26, check = { message = { { player = "Dex", has = "Krasnodar est tombee. Le front russe est brise : victoire !" },
                                        { player = "Dex", has = "Krasnodar est neutre (blanche)" } } } },
    },
}
