Mancer.MinionInspectModule = {}
local MinionInspect = Mancer.MinionInspectModule

local INSPECT_ORDER = {
    "crypt_fiend",
    "banshee",
    "abomination",
    "skeletal_warrior_greater",
    "skeletal_warrior_lesser",
    "skeletal_rogue",
    "ghoul",
    "bone_wraith",
    "skeletal_archer",
}

local SPELL_SCHOOLS = {
    { id = 1, name = "Physical" },
    { id = 2, name = "Holy" },
    { id = 3, name = "Fire" },
    { id = 4, name = "Nature" },
    { id = 5, name = "Frost" },
    { id = 6, name = "Shadow" },
    { id = 7, name = "Arcane" },
}

local function GetAdvisor()
    return Mancer.NecromancerAdvisorModule
end

local function GetMinionDps()
    return Mancer.MinionDpsModule
end

local function NormalizeSpellId(spellId)
    local id = tonumber(spellId)
    if not id or id <= 0 then
        return nil
    end
    return id
end

local function SafeCall(fn, ...)
    if not fn then
        return false, nil
    end
    return pcall(fn, ...)
end

function MinionInspect:GetSpellDetails(spellId)
    spellId = NormalizeSpellId(spellId)
    if not spellId then
        return nil, nil, nil, nil
    end

    local name, rank, icon

    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellId)
        if type(info) == "table" then
            name = info.name
            icon = info.iconID or info.icon
            spellId = NormalizeSpellId(info.spellID or info.spellId or info.id) or spellId
        else
            local a, b, c, d = C_Spell.GetSpellInfo(spellId)
            if type(a) == "string" then
                name, rank, icon = a, b, c
            elseif type(a) == "number" and type(b) == "string" then
                spellId = NormalizeSpellId(a) or spellId
                name, rank, icon = b, c, d
            end
        end
    end

    if not name and GetSpellInfo then
        name, rank, icon = GetSpellInfo(spellId)
    end

    local desc
    if C_Spell and C_Spell.GetSpellDescription then
        local ok, result = SafeCall(C_Spell.GetSpellDescription, spellId)
        if ok then
            desc = result
        end
    end
    if not desc and GetSpellDescription then
        local ok, result = SafeCall(GetSpellDescription, spellId)
        if ok then
            desc = result
        end
    end

    return name, rank, icon, desc, spellId
end

function MinionInspect:ResolveFilter(filter)
    filter = Mancer.Trim(filter or ""):lower()
    if filter == "" or filter == "all" then
        return nil
    end

    local aliases = {
        crypt = "crypt_fiend",
        fiend = "crypt_fiend",
        abom = "abomination",
        rogue = "skeletal_rogue",
        lesser = "skeletal_warrior_lesser",
        greater = "skeletal_warrior_greater",
        skeletal = "skeletal_warrior_greater",
        wraith = "bone_wraith",
        archer = "skeletal_archer",
    }
    if aliases[filter] then
        return aliases[filter]
    end

    local Advisor = GetAdvisor()
    if not Advisor then
        return nil
    end

    for _, minionId in ipairs(INSPECT_ORDER) do
        if minionId:find(filter, 1, true) then
            return minionId
        end
        local def = Advisor.MINION_TYPES[minionId]
        if def and def.label and def.label:lower():find(filter, 1, true) then
            return minionId
        end
    end

    return nil
end

function MinionInspect:PrintPlayerStats()
    Mancer.Print("--- Player stats (client) ---")
    Mancer.Print(string.format("  Level: %d", UnitLevel and UnitLevel("player") or 0))

    if UnitStat then
        Mancer.Print(string.format(
            "  Intellect: %d | Spirit: %d",
            UnitStat("player", 4) or 0,
            UnitStat("player", 5) or 0
        ))
    end

    if GetSpellBonusDamage then
        local lines = {}
        for _, school in ipairs(SPELL_SCHOOLS) do
            local bonus = GetSpellBonusDamage(school.id)
            if bonus and bonus > 0 then
                table.insert(lines, string.format("%s %d", school.name, bonus))
            end
        end
        if #lines > 0 then
            Mancer.Print("  Spell bonus damage: " .. table.concat(lines, " | "))
        end
    end

    if GetSpellBonusHealing then
        local healing = GetSpellBonusHealing()
        if healing and healing > 0 then
            Mancer.Print(string.format("  Spell bonus healing: %d", healing))
        end
    end

    if GetPetSpellBonusDamage then
        local petBonus = GetPetSpellBonusDamage()
        if petBonus and petBonus > 0 then
            Mancer.Print(string.format("  Pet spell bonus damage: %d", petBonus))
        end
    end
end

function MinionInspect:PrintSpellLine(spellId, role)
    spellId = NormalizeSpellId(spellId)
    if not spellId then
        Mancer.Print(string.format("    [%s] (invalid spell id)", role or "?"))
        return
    end

    local name, rank, _, desc, resolvedId = self:GetSpellDetails(spellId)
    spellId = resolvedId or spellId
    local suffix = rank and rank ~= "" and (" (" .. rank .. ")") or ""
    Mancer.Print(string.format("    [%s] #%d %s%s", role or "?", spellId, name or "?", suffix))

    if desc and desc ~= "" then
        for line in tostring(desc):gmatch("[^\n]+") do
            Mancer.Print("      " .. line)
        end
    else
        Mancer.Print("      (no description from client)")
    end
end

function MinionInspect:PrintMinionBlock(minionId, dpsEstimates)
    local Advisor = GetAdvisor()
    local MinionDps = GetMinionDps()
    if not Advisor or not MinionDps then
        return
    end

    local def = Advisor.MINION_TYPES[minionId]
    if not def then
        return
    end

    local label = MinionDps.GetMinionLabel and MinionDps:GetMinionLabel(minionId) or def.label
    local lfCost = Advisor:GetMinionLifeForceCost(minionId)
    local requiredLevel = Advisor.GetMinionRequiredLevel and Advisor:GetMinionRequiredLevel(minionId)
    local active = 0
    if Advisor.GetCachedAuraCounts then
        active = (Advisor:GetCachedAuraCounts()[minionId] or 0)
    end

    Mancer.Print(string.format("--- %s ---", label))
    Mancer.Print(string.format(
        "  LF cost: %d | Active: %d | Talent: %s",
        lfCost,
        active,
        Advisor:HasMinionTalent(minionId) and "yes" or "no"
    ))
    if requiredLevel then
        Mancer.Print(string.format("  Requires level: %d", requiredLevel))
    end

    local row = dpsEstimates and dpsEstimates[minionId]
    if row and row.dps and row.dps > 0 then
        local dpsLf = (lfCost > 0) and (row.dps / lfCost) or nil
        if dpsLf then
            Mancer.Print(string.format("  Measured/benchmark: %.1f DPS/unit (%.1f DPS/LF)", row.dps, dpsLf))
        else
            Mancer.Print(string.format("  Measured/benchmark: %.1f DPS/unit", row.dps))
        end
    else
        Mancer.Print("  Measured/benchmark: none yet")
    end

    local spells = Advisor:CollectMinionSpellIds(minionId)
    if #spells == 0 then
        Mancer.Print("  Spells: (none mapped)")
        return
    end

    Mancer.Print("  Spells:")
    for _, entry in ipairs(spells) do
        local spellId = NormalizeSpellId(entry.id)
        if spellId then
            self:PrintSpellLine(spellId, entry.role)
        elseif entry.name then
            Mancer.Print(string.format("    [%s] %s (combat log name — no spell ID mapped)", entry.role, entry.name))
        end
    end
end

function MinionInspect:PrintInspect(filter)
    local Advisor = GetAdvisor()
    if not Advisor then
        Mancer.Print("Minion advisor not loaded.")
        return
    end

    if not Advisor:IsNecromancer() then
        Mancer.Print("Inspect requires a Necromancer character.")
        return
    end

    local MinionDps = GetMinionDps()
    local dpsEstimates = MinionDps and MinionDps.GetDpsEstimates and select(1, MinionDps:GetDpsEstimates()) or nil
    local onlyMinion = self:ResolveFilter(filter)
    local filterText = Mancer.Trim(filter or "")
    if filterText ~= "" and filterText:lower() ~= "all" and not onlyMinion then
        Mancer.Print("No match for '" .. filterText .. "'. Try: crypt, ghoul, abom, rogue, skeletal")
        return
    end

    Mancer.Print("Minion inspect — client spell data + your stats")
    self:PrintPlayerStats()
    if Mancer.PaperMathModule then
        Mancer.Print("")
        Mancer.PaperMathModule:PrintReport()
        Mancer.Print("")
    end

    local printed = 0
    for _, minionId in ipairs(INSPECT_ORDER) do
        if not onlyMinion or onlyMinion == minionId then
            if Advisor:HasMinionTalent(minionId) or (onlyMinion == minionId) then
                self:PrintMinionBlock(minionId, dpsEstimates)
                printed = printed + 1
            end
        end
    end

    if printed == 0 then
        Mancer.Print("No minion talents detected to inspect.")
    else
        Mancer.Print("Tip: compare spell descriptions at different gear levels on a dummy, then /leti minions dps save")
    end
end
