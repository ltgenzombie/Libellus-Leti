Mancer.MinionTooltipModule = {}
local MinionTooltip = Mancer.MinionTooltipModule

local TOOLTIP_COLOR = { 0.4, 0.8, 1.0 }
local VALUE_COLOR = { 1.0, 1.0, 1.0 }
local MUTED_COLOR = { 0.7, 0.7, 0.7 }
local ADVICE_COLOR = { 0.9, 0.75, 0.45 }
local RECOMMENDED_COLOR = { 0.3, 1.0, 0.3 }

local VERDICT_LABELS = {
    math_first = { label = "Recommended", color = RECOMMENDED_COLOR },
    math_first_s = { label = "High priority — take early", color = RECOMMENDED_COLOR },
    math_first_a = { label = "Strong pick", color = RECOMMENDED_COLOR },
    math_first_b = { label = "Later / situational", color = ADVICE_COLOR },
    math_first_c = { label = "Extra haste (optional)", color = ADVICE_COLOR },
    highly_recommended = { label = "Recommended", color = RECOMMENDED_COLOR },
    recommended = { label = "Recommended", color = RECOMMENDED_COLOR },
    favoured = { label = "Worth taking", color = ADVICE_COLOR },
    situational = { label = "Utility / skip for damage", color = MUTED_COLOR },
    path = { label = "Path talent", color = RECOMMENDED_COLOR },
    free_passive = { label = "Free unlock — always taken", color = RECOMMENDED_COLOR },
}

-- Route priority fallbacks (TalentRoute module is authoritative when loaded).
local ROUTE_TIER_BY_NAME = {
    -- Free passive column (not Spec TE — do not treat as S/A/B)
    ["Summoning Adept"] = "PASSIVE",
    ["Deadly Bond"] = "PASSIVE",
    ["Summoning Expert"] = "PASSIVE",
    ["Diabolical"] = "PASSIVE",
    ["Grave Mastery"] = "PASSIVE",
    -- S
    ["Animation Necromancer"] = "S",
    ["Raise: Ghoul"] = "S",
    ["Summoning Prodigy"] = "S",
    ["Summoning Mastery"] = "S",
    ["Life For Power"] = "S",
    ["Mindless Fury"] = "S",
    ["Graverobber"] = "S",
    ["Ghoul Mastery"] = "S",
    ["Ghoulkeeper"] = "S",
    ["Ghoul Commander"] = "S",
    ["Improved Unholy Command"] = "S",
    ["Sepulchral Might"] = "S",
    ["Unrelenting Army"] = "S",
    ["Forbidden Technique"] = "S",
    ["Army of the Dead"] = "S",
    ["Raise: Abomination"] = "S",
    ["Animate: Skeletal Archer"] = "S",
    ["Bone King"] = "S",
    -- A
    ["Animate: Bone Wraith"] = "A",
    ["Animate: Knight of Decay"] = "A",
    ["Putrid Summoner"] = "A",
    ["Greater Summoning"] = "A",
    ["Ghoulish Mutation"] = "A",
    ["Foul Invocation"] = "A",
    ["Depravity"] = "A",
    ["Fetid Frenzy"] = "A",
    ["Scourge Disciple"] = "A",
    ["Plague Horde"] = "A",
    ["Chomp"] = "A",
    ["Unrelenting"] = "A",
    -- B
    ["Animate: Tomb King"] = "B",
    ["Animate: Plaguefather"] = "B",
    ["Animate: Bone Construct"] = "B",
    ["Unrelenting Swarm"] = "B",
    ["Plaguecraft"] = "B",
    ["Necrotic Power"] = "B",
    ["Crypt Keeper"] = "B",
    ["March of the Dead"] = "B",
    ["Long March"] = "B",
    ["Corpse Wagon"] = "B",
    ["Skeletal Mastery"] = "B",
    ["Artillery"] = "B",
}

local function GetRouteTier(name)
    if not name then
        return nil
    end
    local route = Mancer.TalentRouteModule
    if route and route.IsFreePassive and route:IsFreePassive(name) then
        return "PASSIVE"
    end
    if ROUTE_TIER_BY_NAME[name] then
        return ROUTE_TIER_BY_NAME[name]
    end
    if route and route.TIERS then
        for _, tier in ipairs(route.TIERS) do
            if tier.id == "S" or tier.id == "A" or tier.id == "B" then
                for _, entry in ipairs(tier.entries or {}) do
                    if entry.name == name then
                        return tier.id
                    end
                end
            end
        end
    end
    return nil
end

local function ApplyMathFirstVerdict(tip, tipKey)
    if not tip or not tipKey then
        return tip
    end
    local tier = GetRouteTier(tipKey)
    if not tier then
        return tip
    end
    -- Keep "not ready yet" only for dynamic LF gates (Abom / AotD).
    if tip.verdict == "situational" and (tipKey == "Raise: Abomination" or tipKey == "Army of the Dead") then
        return tip
    end
    local copy = {}
    for k, v in pairs(tip) do
        copy[k] = v
    end
    if tier == "PASSIVE" then
        copy.verdict = "free_passive"
        local route = Mancer.TalentRouteModule
        local ok, level = route and route:IsFreePassive(tipKey)
        if ok and level and (not copy.headline or copy.headline == "") then
            copy.headline = string.format("Free unlock at level %d — always taken", level)
        elseif ok and level then
            -- Keep tip headline; verdict already marks free unlock.
        end
    elseif tier == "S" then
        -- Keep explicit priority tips (e.g. Mindless Fury / AotD haste).
        if tip.verdict == "math_first_s" then
            copy.verdict = "math_first_s"
        else
            copy.verdict = "math_first"
        end
    elseif tier == "A" then
        copy.verdict = "math_first_a"
    else
        copy.verdict = "math_first_b"
    end
    return copy
end

-- CD Animate guidance on Raise/Animate tooltips.
local CD_MINION_USAGE = {
    bone_wraith = {
        verdict = "math_first",
        headline = "Best scaling Animate (Bonestorm SP×0.4)",
        lines = {
            "Bonestorm: base + SP×0.4 per tick — scales directly with Spell Power.",
            "Tip math beats Tomb King’s ~10% army plague convert on the same CD window.",
            "No Life Force cost — pairs well with Forbidden Technique.",
        },
    },
    tomb_king = {
        verdict = "math_first",
        headline = "Flat ~10% plague on minion hits",
        lines = {
            "Buff % is a hard DBC cap (no SP / ppl scaling) — only army damage under it scales.",
            "Weaker Spell Power scaling than Bone Wraith’s SP×0.4 Bonestorm.",
        },
    },
    skeletal_archer = {
        verdict = "math_first",
        headline = "Strong hybrid Animate (no Life Force cost)",
        lines = {
            "Its own cooldown damage — keep pressing it when ready.",
            "Forbidden Technique makes that cooldown come back much faster.",
        },
    },
    plaguefather = {
        verdict = "math_first",
        headline = "Cooldown Animate (no Life Force cost)",
        lines = {
            "Press when ready alongside your raised army.",
            "Works in both boss and pack fights.",
        },
    },
    frost_wyrm = {
        verdict = "math_first",
        headline = "Cooldown Animate (no Life Force cost)",
        lines = {
            "Press when ready alongside your raised army.",
            "Works in both boss and pack fights.",
        },
    },
}

-- Passive / choice talent guidance (Animation Necromancer).
local TALENT_TIPS = {}

local TALENT_TIP_SPELL_IDS = {}

local TALENT_NAME_ALIASES = {}

-- Preferred gear tags (ordered): "int" | "hst" | "crit" — see AnimationTalentTips.statScales.
local TALENT_STAT_SCALES = {}

local STAT_SCALE_COLORS = {
    int = { 0.45, 0.75, 1.0 },
    hst = { 1.0, 0.82, 0.25 },
    crit = { 1.0, 0.45, 0.25 },
}

local STAT_SCALE_LABELS = {
    int = "Intellect",
    hst = "Haste",
    crit = "Crit",
}

-- Raised minion usage tips (shown on Raise tooltips).
local LF_MINION_TIPS = {
    ghoul = {
        verdict = "math_first",
        headline = "Costs 1 Life Force — your main army unit",
        classPointCost = 2,
        lines = {
            "Best for bosses / one target — fill Life Force with ghouls.",
            "Rough boss DPS: ~70 early, ~150 mid-levels each when filled/geared.",
            "Command is a huge chunk of their damage on long single-target fights.",
        },
    },
    abomination = {
        verdict = "math_first",
        headline = "Costs 3 Life Force — enables Army of the Dead",
        lines = {
            "About as strong as three ghouls on a boss.",
            "Main upside: Army of the Dead’s +10% ghoul haste (and crit).",
            "Best boss loadout: 1 Abom + fill leftover Life Force with ghouls.",
        },
    },
    crypt_fiend = {
        verdict = "math_first",
        headline = "Costs 2 Life Force — best for packs",
        lines = {
            "Learned from a trainer (not a CoA point spend).",
            "Best Raise for trash packs / AoE.",
            "On a boss, two ghouls usually beat one Crypt Fiend.",
        },
    },
    banshee = {
        verdict = "math_first",
        headline = "Costs 2 Life Force — mana-drain Raise",
        lines = {
            "Channels on one target and drains mana over time.",
            "Strong vs caster bosses; Command burns more mana for Frost damage.",
            "Same Life Force as Crypt Fiend — pick Fiend for packs, Banshee for single casters.",
        },
    },
    skeletal_warrior_greater = {
        verdict = "math_first",
        headline = "Costs 1 Life Force — filler Raise",
        lines = {
            "Fine for either boss or packs.",
            "Usually worse than ghouls (boss) or Crypt Fiend (packs) for the same Life Force.",
        },
    },
    skeletal_warrior_lesser = {
        verdict = "math_first",
        headline = "Costs 1 Life Force — early Raise",
        lines = {
            "Early option while you unlock better Raises.",
            "Move toward Ghouls + Abom (boss) or Crypt Fiend (packs).",
        },
    },
    skeletal_rogue = {
        verdict = "math_first",
        headline = "Costs 1 Life Force — niche boss Raise",
        lines = {
            "Niche single-target option.",
            "Check Hub → LF Combo before forcing it over ghouls.",
        },
    },
}

-- Dummy-calibrated ST baselines (1 Abom + 2 Ghoul pull). Prefer live DPS estimates when available.
local CALIBRATED_ABOM_DPS = 206
-- Prefer mid-40s non-tank ST dummy; early ~70 still in tip copy. Live Minion DPS overwrites.
local CALIBRATED_GHOUL_DPS = 152
local AOTD_GHOUL_HASTE = 0.10

local function MergeAnimationTalentTips()
    local pack = Mancer.AnimationTalentTips
    if not pack then
        return
    end

    for name, tip in pairs(pack.tips or {}) do
        TALENT_TIPS[name] = tip
    end

    for spellId, name in pairs(pack.spellIds or {}) do
        TALENT_TIP_SPELL_IDS[spellId] = name
    end

    for alias, canonical in pairs(pack.nameAliases or {}) do
        TALENT_NAME_ALIASES[alias] = canonical
    end

    for name, scales in pairs(pack.statScales or {}) do
        TALENT_STAT_SCALES[name] = scales
        -- Attach onto tip so ResolveTip / dynamic clones can inherit.
        if TALENT_TIPS[name] and not TALENT_TIPS[name].scales then
            TALENT_TIPS[name].scales = scales
        end
    end
end

local function HasStatScales(scales)
    return scales and #scales > 0
end

local function GetStatScales(tipKey, tip)
    if tip and tip.scales then
        return tip.scales
    end
    if tipKey and TALENT_STAT_SCALES[tipKey] then
        return TALENT_STAT_SCALES[tipKey]
    end
    return nil
end

local function StatScalesKey(scales)
    if not HasStatScales(scales) then
        return "-"
    end
    return table.concat(scales, ",")
end

local function AddStatScaleLines(tooltip, scales)
    if not HasStatScales(scales) then
        return
    end
    local parts = {}
    local color = MUTED_COLOR
    for _, tag in ipairs(scales) do
        local label = STAT_SCALE_LABELS[tag]
        if label then
            parts[#parts + 1] = label
            color = STAT_SCALE_COLORS[tag] or color
        end
    end
    if #parts == 0 then
        return
    end
    -- One readable line instead of raw tags like "hst" stacked under advice.
    tooltip:AddLine(
        "Gear: " .. table.concat(parts, " > "),
        color[1], color[2], color[3]
    )
end

local function GetAdvisor()
    return Mancer.NecromancerAdvisorModule
end

local function GetMinionDps()
    return Mancer.MinionDpsModule
end

local function GetPlayerLifeForceMax()
    local Advisor = GetAdvisor()
    if Advisor and Advisor.GetLifeForceMax then
        local lf = tonumber(Advisor:GetLifeForceMax())
        if lf and lf > 0 then
            return lf
        end
    end
    return nil
end

local function GetCalibratedUnitDps(minionId, fallback)
    local MinionDps = GetMinionDps()
    if MinionDps and MinionDps.GetDpsEstimates then
        local estimates = MinionDps:GetDpsEstimates()
        local row = estimates and estimates[minionId]
        if row and row.dps and row.dps > 0 then
            return row.dps
        end
    end
    return fallback
end

local function GetAbomGhoulLoadout(lfMax)
    local Advisor = GetAdvisor()
    local abomCost = 3
    local ghoulCost = 1
    if Advisor and Advisor.GetMinionLifeForceCost then
        abomCost = math.max(1, Advisor:GetMinionLifeForceCost("abomination") or abomCost)
        ghoulCost = math.max(1, Advisor:GetMinionLifeForceCost("ghoul") or ghoulCost)
    end

    lfMax = tonumber(lfMax) or 0
    if lfMax < abomCost then
        return {
            lfMax = lfMax,
            abomCost = abomCost,
            ghoulCost = ghoulCost,
            abomCount = 0,
            ghoulCount = math.floor(lfMax / ghoulCost),
            canRunAbom = false,
        }
    end

    local ghoulCount = math.floor((lfMax - abomCost) / ghoulCost)
    return {
        lfMax = lfMax,
        abomCost = abomCost,
        ghoulCost = ghoulCost,
        abomCount = 1,
        ghoulCount = ghoulCount,
        canRunAbom = true,
    }
end

local function FormatLoadout(abomCount, ghoulCount)
    if abomCount > 0 and ghoulCount > 0 then
        return string.format("1 Abom + %d Ghoul%s", ghoulCount, ghoulCount == 1 and "" or "s")
    end
    if abomCount > 0 then
        return "1 Abom"
    end
    if ghoulCount > 0 then
        return string.format("%d Ghoul%s", ghoulCount, ghoulCount == 1 and "" or "s")
    end
    return "empty"
end

local function BuildArmyOfTheDeadTip()
    local lfMax = GetPlayerLifeForceMax()
    local abomDps = GetCalibratedUnitDps("abomination", CALIBRATED_ABOM_DPS)
    local ghoulDps = GetCalibratedUnitDps("ghoul", CALIBRATED_GHOUL_DPS)

    if not lfMax then
        return {
            verdict = "math_first",
            headline = "+10% ghoul haste and crit with 1 Abomination",
            lines = {
                string.format("Each ghoul gains roughly +%.0f DPS from the haste alone (~%.0f base).", ghoulDps * AOTD_GHOUL_HASTE, ghoulDps),
                "Typical loadout: 1 Abom + fill leftover Life Force with ghouls.",
            },
        }
    end

    local loadout = GetAbomGhoulLoadout(lfMax)
    if not loadout.canRunAbom then
        return {
            verdict = "situational",
            headline = string.format("Need %d Life Force for an Abomination (you have %d)", loadout.abomCost, lfMax),
            lines = {
                "Pick up more Life Force first, then run 1 Abom + ghouls.",
            },
        }
    end

    local ghouls = loadout.ghoulCount
    local baseGhoul = ghouls * ghoulDps
    local buffedGhoul = ghouls * ghoulDps * (1 + AOTD_GHOUL_HASTE)
    local hasteGain = buffedGhoul - baseGhoul
    local baseTotal = abomDps + baseGhoul
    local buffedTotal = abomDps + buffedGhoul
    local label = FormatLoadout(1, ghouls)

    local lines = {
        string.format("With your Life Force (%d): run %s.", lfMax, label),
    }

    if ghouls > 0 then
        table.insert(lines, string.format(
            "Haste buff ≈ +%.0f total DPS on those ghouls (~%.0f → ~%.0f with Abom).",
            hasteGain, baseTotal, buffedTotal
        ))
    else
        table.insert(lines, "Abom fits, but no leftover LF for ghouls — the haste buff needs ghouls.")
    end

    return {
        verdict = "math_first",
        headline = string.format("+10%% ghoul haste/crit — %s", label),
        lines = lines,
        lfMax = lfMax,
    }
end

local function BuildAbomLoadoutTip()
    local lfMax = GetPlayerLifeForceMax()
    local abomDps = GetCalibratedUnitDps("abomination", CALIBRATED_ABOM_DPS)
    local ghoulDps = GetCalibratedUnitDps("ghoul", CALIBRATED_GHOUL_DPS)

    if not lfMax then
        return {
            verdict = "math_first",
            headline = "Costs 3 Life Force — pair with ghouls",
            lines = {
                string.format("About as strong as three ghouls (~%.0f DPS vs ~%.0f each).", abomDps, ghoulDps),
                "Take Army of the Dead with it for +10% ghoul haste and crit.",
            },
        }
    end

    local loadout = GetAbomGhoulLoadout(lfMax)
    if not loadout.canRunAbom then
        return {
            verdict = "situational",
            headline = string.format("Needs %d Life Force (you have %d)", loadout.abomCost, lfMax),
            lines = {
                "Unlock more Life Force before this fits in your army.",
            },
            lfMax = lfMax,
        }
    end

    local ghouls = loadout.ghoulCount
    local ghoulOnly = math.floor(lfMax / loadout.ghoulCost)
    local withAbom = abomDps + ghouls * ghoulDps
    local allGhoul = ghoulOnly * ghoulDps
    local label = FormatLoadout(1, ghouls)

    return {
        verdict = "math_first",
        headline = string.format("With your Life Force (%d): %s", lfMax, label),
        lines = {
            string.format("That setup is about %.0f DPS (Abom ~%.0f + ghouls).", withAbom, abomDps),
            string.format("All-ghoul instead: about %.0f DPS — Abom is mainly for Army of the Dead haste.", allGhoul),
            "Keep Army of the Dead for +10% ghoul haste and crit while the Abom is up.",
        },
        lfMax = lfMax,
    }
end

local function ResolveTip(tipKey, tip)
    if not tip then
        return nil
    end

    if tip.dynamic == "army_of_the_dead" or tipKey == "Army of the Dead" then
        return BuildArmyOfTheDeadTip()
    end

    if tip.dynamic == "abom_loadout" or tipKey == "Raise: Abomination" then
        return BuildAbomLoadoutTip()
    end

    return tip
end

local function IsEnabled()
    MancerDB.minionDps = MancerDB.minionDps or {}
    return MancerDB.minionDps.tooltipEnabled ~= false
end

local function GetTooltipTextLine(tooltip, index)
    if not tooltip or not tooltip.GetName then
        return nil
    end

    local name = tooltip:GetName()
    if not name then
        return nil
    end

    local left = _G[name .. "TextLeft" .. tostring(index or 1)]
    if left and left.GetText then
        return left:GetText()
    end

    return nil
end

local function NormalizeTalentName(spellName)
    if not spellName then
        return nil
    end
    return spellName:gsub("%s*%([Rr]ank.*%)", ""):gsub("%s+$", "")
end

local function IsNecromancerPlayer()
    if Mancer.Ascension and Mancer.Ascension.GetPlayerClass then
        if Mancer.Ascension.GetPlayerClass() == "NECROMANCER" then
            return true
        end
    end

    local Advisor = GetAdvisor()
    if Advisor and Advisor.IsNecromancer and Advisor:IsNecromancer() then
        return true
    end

    if UnitClass then
        local _, classToken = UnitClass("player")
        if classToken == "NECROMANCER" then
            return true
        end
    end

    return false
end

local function GetCaEntry(spellId)
    if not spellId or spellId <= 0 or not C_CharacterAdvancement then
        return nil
    end
    if not C_CharacterAdvancement.GetInternalID or not C_CharacterAdvancement.GetEntryByInternalID then
        return nil
    end

    local ok, entry = pcall(function()
        local internalId = C_CharacterAdvancement.GetInternalID(spellId)
        if not internalId then
            return nil
        end
        return C_CharacterAdvancement.GetEntryByInternalID(internalId)
    end)

    if ok then
        return entry
    end
    return nil
end

local function IsNecromancerCaEntry(entry)
    if not entry then
        return false
    end
    local className = entry.Class or entry.class or entry.ClassName or entry.className
    if not className then
        return false
    end
    return string.upper(tostring(className)) == "NECROMANCER"
end

local function IsNecromancerAbility(spellId, spellName, tooltipTitle)
    if spellId and TALENT_TIP_SPELL_IDS[spellId] then
        return true
    end

    local entry = GetCaEntry(spellId)
    if IsNecromancerCaEntry(entry) then
        return true
    end

    local name = NormalizeTalentName(spellName) or NormalizeTalentName(tooltipTitle)
    if name and (TALENT_TIPS[name] or TALENT_NAME_ALIASES[name] or TALENT_STAT_SCALES[name]) then
        -- Known Animation tip names only apply while playing Necromancer.
        return true
    end

    if name and (
        name:match("^Raise: ")
        or name:match("^Animate: ")
        or name:match("^Command: ")
    ) then
        return true
    end

    local Advisor = GetAdvisor()
    if Advisor and Advisor.ClassifyMinionSummonSpell then
        if Advisor:ClassifyMinionSummonSpell(spellName or name, spellId) then
            return true
        end
    end

    return false
end

local function ShouldAugmentTooltips()
    if not IsEnabled() then
        return false
    end
    return IsNecromancerPlayer()
end

local function ClearAugmentFlag(tooltip)
    tooltip.mancerMinionSpellId = nil
    tooltip.mancerAugmentKey = nil
    tooltip.mancerAugmentScheduled = nil
    tooltip.mancerPendingSpellId = nil
end

local function ResolveCaEntryName(spellId)
    if not spellId or spellId <= 0 or not C_CharacterAdvancement then
        return nil
    end

    if not C_CharacterAdvancement.GetInternalID or not C_CharacterAdvancement.GetEntryByInternalID then
        return nil
    end

    local ok, entryName = pcall(function()
        local internalId = C_CharacterAdvancement.GetInternalID(spellId)
        if not internalId then
            return nil
        end
        local entry = C_CharacterAdvancement.GetEntryByInternalID(internalId)
        if not entry then
            return nil
        end
        return entry.name or entry.Name
    end)

    if ok and entryName and entryName ~= "" then
        return NormalizeTalentName(entryName)
    end

    return nil
end

local function LooksLikeTalentTooltip(tooltip)
    for i = 2, 6 do
        local line = GetTooltipTextLine(tooltip, i)
        if line and line:match("[Rr]ank%s+%d+/%d+") then
            return true
        end
    end
    return false
end

local function NamesMatch(a, b)
    if not a or not b then
        return false
    end
    return NormalizeTalentName(a) == NormalizeTalentName(b)
end

local function TooltipMatchesSpell(spellId, tooltipTitle)
    if not spellId or spellId <= 0 or not tooltipTitle or tooltipTitle == "" then
        return false
    end

    local spellName = GetSpellInfo(spellId)
    if NamesMatch(spellName, tooltipTitle) then
        return true
    end

    local caName = ResolveCaEntryName(spellId)
    if NamesMatch(caName, tooltipTitle) then
        return true
    end

    local mapped = TALENT_TIP_SPELL_IDS[spellId]
    if mapped and NamesMatch(mapped, tooltipTitle) then
        return true
    end

    return false
end

local function LooksLikeItemTooltip(tooltip)
    for i = 2, 10 do
        local line = GetTooltipTextLine(tooltip, i)
        if not line then
            break
        end
        if line:match("[Ii]tem [Ll]evel")
            or line:match("[Ss]ell [Pp]rice")
            or line:match("[Bb]inds when")
            or line:match("[Dd]urability %d+")
            or line:match("[Rr]equires Level") then
            return true
        end
    end
    return false
end

local function LooksLikeSpellOrTalentTooltip(tooltip, tooltipTitle)
    if LooksLikeTalentTooltip(tooltip) then
        return true
    end

    if not tooltipTitle or tooltipTitle == "" then
        return false
    end

    for i = 2, 6 do
        local line = GetTooltipTextLine(tooltip, i)
        if line and (
            line:match("[Mm]ana")
            or line:match("[Cc]ooldown")
            or line:match("[Cc]ast [Tt]ime")
            or line:match("[Rr]ange")
            or line:match("[Ii]nstant")
        ) then
            return true
        end
    end

    if tooltipTitle:match("^Raise: ") or tooltipTitle:match("^Animate: ") then
        return true
    end

    return false
end

local function HookTooltipClear(tooltip, methodName)
    if not tooltip[methodName] then
        return
    end
    hooksecurefunc(tooltip, methodName, function(frame)
        ClearAugmentFlag(frame)
    end)
end

local function ResolveTalentName(spellId, spellName, tooltipTitle, requireTitleMatch)
    local normalizedTitle = NormalizeTalentName(tooltipTitle)

    if normalizedTitle and TALENT_TIPS[normalizedTitle] then
        return normalizedTitle
    end

    if normalizedTitle and TALENT_STAT_SCALES[normalizedTitle] then
        return normalizedTitle
    end

    if normalizedTitle and TALENT_NAME_ALIASES[normalizedTitle] then
        return TALENT_NAME_ALIASES[normalizedTitle]
    end

    if requireTitleMatch and spellId and spellId > 0 and normalizedTitle then
        if not TooltipMatchesSpell(spellId, normalizedTitle) then
            spellId = nil
            spellName = nil
        end
    end

    local candidates = {}

    if spellId and TALENT_TIP_SPELL_IDS[spellId] then
        table.insert(candidates, TALENT_TIP_SPELL_IDS[spellId])
    end

    local caName = ResolveCaEntryName(spellId)
    if caName then
        table.insert(candidates, caName)
    end

    local normalizedSpell = NormalizeTalentName(spellName)
    if normalizedSpell then
        table.insert(candidates, normalizedSpell)
    end

    if normalizedTitle then
        table.insert(candidates, normalizedTitle)
    end

    for _, candidate in ipairs(candidates) do
        if TALENT_NAME_ALIASES[candidate] then
            return TALENT_NAME_ALIASES[candidate]
        end
        if TALENT_TIPS[candidate] then
            return candidate
        end
        if TALENT_STAT_SCALES[candidate] then
            return candidate
        end
    end

    for _, candidate in ipairs(candidates) do
        if TALENT_NAME_ALIASES[candidate] then
            return TALENT_NAME_ALIASES[candidate]
        end
    end

    return candidates[1]
end

local function ScheduleTooltipAugment(tooltip)
    if tooltip.mancerAugmentScheduled then
        return
    end
    tooltip.mancerAugmentScheduled = true

    local function run()
        tooltip.mancerAugmentScheduled = nil
        if tooltip:IsVisible() then
            MinionTooltip:TryAugmentFromTooltipDisplay(tooltip)
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, run)
    else
        local frame = CreateFrame("Frame")
        frame:SetScript("OnUpdate", function(self)
            self:SetScript("OnUpdate", nil)
            run()
        end)
    end
end

local function ResolveMinionId(spellId, spellName)
    local Advisor = GetAdvisor()
    if not Advisor then
        return nil
    end

    if Advisor.ClassifyMinionSummonSpell then
        return Advisor:ClassifyMinionSummonSpell(spellName, spellId)
    end

    return nil
end

-- CoA: even lvl = class point from 10. Uses TalentRoute when loaded.
local function GetLevelForClassPoints(count)
    local route = Mancer.TalentRouteModule
    if route and route.LevelForClassPoints then
        return route:LevelForClassPoints(count)
    end
    if not count or count <= 0 then
        return nil
    end
    return 10 + (count - 1) * 2
end

local function NormalizeTipText(text)
    if not text then
        return ""
    end
    return (tostring(text):lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function TipLineRedundant(candidate, anchors)
    local c = NormalizeTipText(candidate)
    if c == "" then
        return true
    end
    -- Pointers at the stock spell text add nothing.
    if c:find("see talent", 1, true)
        or c:find("see tooltip", 1, true)
        or c:find("see the talent", 1, true)
        or c:find("(see %%)", 1, true)
        or c:find("see %", 1, true)
        or c:find("for the amount", 1, true)
        or c:find("named on the talent", 1, true)
    then
        return true
    end
    for _, anchor in ipairs(anchors) do
        local a = NormalizeTipText(anchor)
        if a ~= "" then
            if c == a then
                return true
            end
            -- Drop paraphrases that just restate priority / take-early messaging.
            if (c:find("take asap", 1, true) or c:find("take early", 1, true) or c:find("high priority", 1, true))
                and (a:find("take asap", 1, true) or a:find("take early", 1, true) or a:find("high priority", 1, true) or a:find("priority", 1, true) or a:find("recommended", 1, true) or a:find("strong pick", 1, true))
            then
                return true
            end
            if #c > 20 and #a > 20 then
                if a:find(c, 1, true) or c:find(a, 1, true) then
                    return true
                end
                -- Shared distinctive phrase (e.g. both mention "+10% ghoul haste").
                local shared = c:match("%+%d+%%[^%.]+") or c:match("%d+%%[^%.]+haste")
                if shared and #shared > 12 and a:find(shared, 1, true) then
                    return true
                end
            end
        end
    end
    return false
end

local function AddVerdictHeader(tooltip, verdict, headline)
    local info = verdict and VERDICT_LABELS[verdict]
    local verdictLabel = info and info.label or nil

    if info then
        -- Avoid "High priority — take early" + another "take ASAP" headline stacked.
        if headline and headline ~= "" and TipLineRedundant(headline, { verdictLabel }) then
            tooltip:AddLine(
                string.format("|cff33ccffMancer:|r %s", verdictLabel),
                info.color[1], info.color[2], info.color[3]
            )
            return
        end
        tooltip:AddLine(
            string.format("|cff33ccffMancer:|r %s", verdictLabel),
            info.color[1], info.color[2], info.color[3]
        )
    else
        tooltip:AddLine("|cff33ccffMancer|r", TOOLTIP_COLOR[1], TOOLTIP_COLOR[2], TOOLTIP_COLOR[3])
    end

    if headline and headline ~= "" then
        tooltip:AddLine(headline, ADVICE_COLOR[1], ADVICE_COLOR[2], ADVICE_COLOR[3])
    end
end

local function AddAdviceLines(tooltip, lines, anchors)
    anchors = anchors or {}
    local seen = {}
    for _, line in ipairs(lines or {}) do
        if line and line ~= "" and not TipLineRedundant(line, anchors) and not TipLineRedundant(line, seen) then
            tooltip:AddLine(line, MUTED_COLOR[1], MUTED_COLOR[2], MUTED_COLOR[3])
            seen[#seen + 1] = line
            anchors[#anchors + 1] = line
        end
    end
end

local function GetTooltipCreatureLabel(spellName, fallbackLabel)
    if not spellName then
        return fallbackLabel
    end

    local creature = spellName:match("^Raise: (.+)$") or spellName:match("^Animate: (.+)$")
    if creature and creature ~= "" then
        return creature
    end

    return fallbackLabel
end

local function AddFightRoleLine(tooltip, minionId)
    local MinionDps = Mancer.MinionDpsModule
    local role = MinionDps and MinionDps.GetFightRole and MinionDps:GetFightRole(minionId)
    if not role or not role.bestFor then
        return
    end
    tooltip:AddLine(
        "|cff33ccffBest for:|r " .. role.bestFor,
        TOOLTIP_COLOR[1], TOOLTIP_COLOR[2], TOOLTIP_COLOR[3]
    )
end

local function AddCdMinionUsage(tooltip, minionId)
    local usage = CD_MINION_USAGE[minionId]
    if not usage then
        return
    end

    AddFightRoleLine(tooltip, minionId)
    AddVerdictHeader(tooltip, usage.verdict, usage.headline)
    AddAdviceLines(tooltip, usage.lines)
end

local function AddLfMinionUsage(tooltip, minionId)
    local usage = LF_MINION_TIPS[minionId]
    if minionId == "abomination" then
        usage = BuildAbomLoadoutTip()
    elseif minionId == "ghoul" then
        local lfMax = GetPlayerLifeForceMax()
        local ghoulDps = GetCalibratedUnitDps("ghoul", CALIBRATED_GHOUL_DPS)
        if lfMax then
            local loadout = GetAbomGhoulLoadout(lfMax)
            usage = {
                verdict = "recommended",
                headline = string.format("Your Life Force (%d): up to %d ghouls", lfMax, math.floor(lfMax / (loadout.ghoulCost or 1))),
                lines = {
                    string.format("About %.0f DPS each when filled mid-levels.", ghoulDps),
                    loadout.canRunAbom
                        and string.format("Typical Army of the Dead setup: %s.", FormatLoadout(1, loadout.ghoulCount))
                        or "Not enough Life Force for Abomination + ghouls yet.",
                    "Keep Command on cooldown — it’s a big part of ghoul damage.",
                    "Bosses: ghouls. Packs: check Hub → ST vs AOE.",
                },
                classPointCost = 2,
                lfMax = lfMax,
            }
        end
    end

    if not usage then
        return
    end

    AddFightRoleLine(tooltip, minionId)
    AddVerdictHeader(tooltip, usage.verdict, usage.headline)
    AddAdviceLines(tooltip, usage.lines)

    if usage.classPointCost then
        local level = GetLevelForClassPoints(usage.classPointCost)
        if level then
            tooltip:AddLine(
                string.format("Earliest with %d class points: level %d", usage.classPointCost, level),
                MUTED_COLOR[1], MUTED_COLOR[2], MUTED_COLOR[3]
            )
        end
    end
end

function MinionTooltip:AugmentTalentTooltip(tooltip, spellId, spellName, tooltipTitle, requireTitleMatch)
    if not ShouldAugmentTooltips() then
        return false
    end

    if not IsNecromancerAbility(spellId, spellName, tooltipTitle) then
        return false
    end

    local tipKey = ResolveTalentName(spellId, spellName, tooltipTitle, requireTitleMatch)
    if not tipKey then
        return false
    end

    local tip = ResolveTip(tipKey, TALENT_TIPS[tipKey])
    local scales = GetStatScales(tipKey, tip)
    if not tip and not HasStatScales(scales) then
        -- Known Animation node with no gear-stat tag (utility) — skip fallback noise.
        if tipKey and TALENT_STAT_SCALES[tipKey] ~= nil then
            local augmentKey = string.format("util:%s:%s", tipKey, tostring(spellId or 0))
            tooltip.mancerAugmentKey = augmentKey
            return true
        end
        return false
    end
    if tip then
        tip = ApplyMathFirstVerdict(tip, tipKey)
        scales = GetStatScales(tipKey, tip) or scales
    end

    local lfKey = tip and tip.lfMax and tostring(tip.lfMax) or "na"
    local verdictKey = tip and tostring(tip.verdict or "") or "scales"
    local augmentKey = string.format(
        "%s:%s:%s:%s:%s:%s",
        tostring(spellId or 0),
        tipKey,
        tostring(tooltipTitle or ""),
        lfKey,
        verdictKey,
        StatScalesKey(scales)
    )
    if tooltip.mancerAugmentKey == augmentKey then
        return true
    end
    tooltip.mancerAugmentKey = augmentKey
    tooltip.mancerMinionSpellId = spellId

    tooltip:AddLine(" ")
    if tip then
        local info = tip.verdict and VERDICT_LABELS[tip.verdict]
        local anchors = { tip.headline, info and info.label }
        AddVerdictHeader(tooltip, tip.verdict, tip.headline)
        AddStatScaleLines(tooltip, scales)
        AddAdviceLines(tooltip, tip.lines, anchors)
    else
        tooltip:AddLine("|cff33ccffMancer|r", TOOLTIP_COLOR[1], TOOLTIP_COLOR[2], TOOLTIP_COLOR[3])
        AddStatScaleLines(tooltip, scales)
    end
    tooltip:Show()
    return true
end

function MinionTooltip:TryAugmentFromTooltipDisplay(tooltip)
    if not ShouldAugmentTooltips() or not tooltip or not tooltip:IsVisible() then
        return
    end

    if tooltip.mancerAugmentKey then
        return
    end

    local tooltipTitle = GetTooltipTextLine(tooltip, 1)
    if not tooltipTitle or tooltipTitle == "" then
        return
    end

    if LooksLikeItemTooltip(tooltip) then
        ClearAugmentFlag(tooltip)
        return
    end

    if not LooksLikeSpellOrTalentTooltip(tooltip, tooltipTitle) then
        ClearAugmentFlag(tooltip)
        return
    end

    local spellId = tooltip.mancerPendingSpellId or tooltip.spellID or tooltip.spellId
    spellId = tonumber(spellId)
    if spellId and spellId > 0 and not TooltipMatchesSpell(spellId, tooltipTitle) then
        spellId = nil
    end

    if not IsNecromancerAbility(spellId, nil, tooltipTitle) then
        return
    end

    if not spellId or spellId <= 0 then
        local tipName = NormalizeTalentName(tooltipTitle)
        -- Allow known tip names (e.g. Sense Undead) even when the hover has no spell id.
        if not LooksLikeTalentTooltip(tooltip) and not (tipName and (TALENT_TIPS[tipName] or TALENT_STAT_SCALES[tipName])) then
            return
        end
    end

    local spellName = spellId and spellId > 0 and GetSpellInfo(spellId) or tooltipTitle
    if self:AugmentTalentTooltip(tooltip, spellId, spellName, tooltipTitle, true) then
        return
    end

    -- Only annotate unknown Necromancer CA talents (never other classes / generic spells).
    if LooksLikeTalentTooltip(tooltip) and IsNecromancerAbility(spellId, spellName, tooltipTitle) then
        local tipKey = ResolveTalentName(spellId, spellName, tooltipTitle, true)
        if tipKey and (TALENT_TIPS[tipKey] or TALENT_STAT_SCALES[tipKey] ~= nil) then
            return
        end
        local caEntry = GetCaEntry(spellId)
        if spellId and spellId > 0 and caEntry and not IsNecromancerCaEntry(caEntry) then
            return
        end
        if not tipKey and not IsNecromancerCaEntry(caEntry) and not (tooltipTitle:match("^Raise: ") or tooltipTitle:match("^Animate: ") or tooltipTitle:match("^Command: ")) then
            return
        end

        local augmentKey = string.format("unknown:%s", NormalizeTalentName(tooltipTitle) or tooltipTitle)
        if tooltip.mancerAugmentKey ~= augmentKey then
            tooltip.mancerAugmentKey = augmentKey
            tooltip:AddLine(" ")
            tooltip:AddLine("|cff33ccffMancer:|r No paper DPS model yet", MUTED_COLOR[1], MUTED_COLOR[2], MUTED_COLOR[3])
            tooltip:AddLine("Read the talent % and measure on dummy when possible.", MUTED_COLOR[1], MUTED_COLOR[2], MUTED_COLOR[3])
            tooltip:Show()
        end
    end
end

function MinionTooltip:AugmentTooltip(tooltip, spellId, spellName, tooltipTitle)
    if not ShouldAugmentTooltips() then
        return
    end

    spellId = tonumber(spellId)
    if not spellId or spellId <= 0 then
        ScheduleTooltipAugment(tooltip)
        return
    end

    tooltip.mancerPendingSpellId = spellId

    local Advisor = GetAdvisor()
    local MinionDps = GetMinionDps()
    if not Advisor or not MinionDps then
        return
    end

    spellName = spellName or GetSpellInfo(spellId)
    tooltipTitle = tooltipTitle or GetTooltipTextLine(tooltip, 1)

    -- Bartender/SetAction can pass a stale spell id that does not match the visible tooltip.
    if tooltipTitle and spellName and NormalizeTalentName(tooltipTitle) ~= NormalizeTalentName(spellName) then
        if not TooltipMatchesSpell(spellId, tooltipTitle) then
            spellId = nil
            spellName = tooltipTitle
            tooltip.mancerPendingSpellId = nil
        end
    end

    if not IsNecromancerAbility(spellId, spellName, tooltipTitle) then
        return
    end

    if not spellId or spellId <= 0 then
        if self:AugmentTalentTooltip(tooltip, nil, spellName, tooltipTitle, true) then
            return
        end
        return
    end

    local minionId = ResolveMinionId(spellId, spellName)
    if not minionId and tooltipTitle then
        minionId = ResolveMinionId(nil, tooltipTitle)
    end

    local tipKey = ResolveTalentName(spellId, spellName, tooltipTitle, false)
    local scales = GetStatScales(tipKey)

    if minionId then
        local augmentKey = string.format(
            "minion:%s:%s:%s",
            tostring(spellId),
            minionId,
            StatScalesKey(scales)
        )
        if tooltip.mancerAugmentKey == augmentKey then
            return
        end
        tooltip.mancerAugmentKey = augmentKey
        tooltip.mancerMinionSpellId = spellId
    else
        if self:AugmentTalentTooltip(tooltip, spellId, spellName, tooltipTitle, false) then
            return
        end

        if LooksLikeTalentTooltip(tooltip) then
            ScheduleTooltipAugment(tooltip)
        end
        return
    end

    local estimates, _, source = MinionDps:GetDpsEstimates()
    local row = estimates and estimates[minionId]
    local lfCost = Advisor:GetMinionLifeForceCost(minionId)
    local label = GetTooltipCreatureLabel(spellName, MinionDps:GetMinionLabel(minionId))
    local requiredLevel = Advisor.GetMinionRequiredLevel and Advisor:GetMinionRequiredLevel(minionId)

    tooltip:AddLine(" ")

    if requiredLevel then
        local playerLevel = UnitLevel and UnitLevel("player") or 1
        if playerLevel < requiredLevel then
            tooltip:AddLine(string.format("Requires level %d", requiredLevel), 1.0, 0.3, 0.3)
        elseif not Advisor:HasMinionTalent(minionId) then
            tooltip:AddLine(string.format("Trained at level %d", requiredLevel), MUTED_COLOR[1], MUTED_COLOR[2], MUTED_COLOR[3])
        end
    end

    if row and row.dps and row.dps > 0 then
        if lfCost and lfCost > 0 then
            tooltip:AddDoubleLine(
                "|cff33ccffMancer|r DPS/LF",
                string.format("%.0f", row.dps / lfCost),
                TOOLTIP_COLOR[1], TOOLTIP_COLOR[2], TOOLTIP_COLOR[3],
                VALUE_COLOR[1], VALUE_COLOR[2], VALUE_COLOR[3]
            )
            tooltip:AddDoubleLine(
                "DPS per " .. label,
                string.format("%.0f", row.dps),
                MUTED_COLOR[1], MUTED_COLOR[2], MUTED_COLOR[3],
                VALUE_COLOR[1], VALUE_COLOR[2], VALUE_COLOR[3]
            )
        else
            tooltip:AddDoubleLine(
                "|cff33ccffMancer|r DPS",
                string.format("%.0f", row.dps),
                TOOLTIP_COLOR[1], TOOLTIP_COLOR[2], TOOLTIP_COLOR[3],
                VALUE_COLOR[1], VALUE_COLOR[2], VALUE_COLOR[3]
            )
        end

        if source == "benchmark" then
            tooltip:AddLine("Single-target dummy benchmark (lvl 30)", 0.5, 0.5, 0.5)
        elseif source then
            tooltip:AddLine("Source: " .. source, 0.5, 0.5, 0.5)
        end
    elseif Advisor.UsesTemporaryTracking and Advisor:UsesTemporaryTracking(minionId) then
        tooltip:AddLine("|cff33ccffMancer:|r CD minion (not LF-limited)", 0.8, 0.8, 0.8)
        tooltip:AddLine("Summon on cooldown alongside your LF loadout", 0.55, 0.55, 0.55)
    else
        tooltip:AddLine("|cff33ccffMancer:|r No DPS data yet", 0.8, 0.8, 0.8)
        tooltip:AddLine("Train on a dummy, then Hub → Save Fight", 0.55, 0.55, 0.55)
    end

    AddLfMinionUsage(tooltip, minionId)
    AddCdMinionUsage(tooltip, minionId)
    AddStatScaleLines(tooltip, scales)

    tooltip:Show()
end

function MinionTooltip:HookTooltip(tooltip)
    if not tooltip or tooltip.mancerMinionHooked then
        return
    end
    tooltip.mancerMinionHooked = true

    tooltip:HookScript("OnHide", ClearAugmentFlag)

    local clearMethods = {
        "SetItem", "SetBagItem", "SetInventoryItem", "SetMerchantItem",
        "SetQuestItem", "SetQuestLogItem", "SetLootItem", "SetLootRollItem",
        "SetBuybackItem", "SetTradeTargetItem", "SetTradePlayerItem",
        "SetGuildBankItem", "SetCurrencyToken", "SetCurrencyByID",
        "SetUnit", "SetUnitAura", "SetUnitBuff", "SetUnitDebuff",
        "SetText", "SetFormattedText",
    }
    for _, methodName in ipairs(clearMethods) do
        HookTooltipClear(tooltip, methodName)
    end

    if tooltip.SetSpell then
        hooksecurefunc(tooltip, "SetSpell", function(frame, spellId)
            ClearAugmentFlag(frame)
            MinionTooltip:AugmentTooltip(frame, spellId)
        end)
    end

    if tooltip.SetSpellByID then
        hooksecurefunc(tooltip, "SetSpellByID", function(frame, spellId)
            ClearAugmentFlag(frame)
            MinionTooltip:AugmentTooltip(frame, spellId)
        end)
    end

    if tooltip.SetAction then
        hooksecurefunc(tooltip, "SetAction", function(frame, slot)
            ClearAugmentFlag(frame)
            local actionType, id = GetActionInfo(slot)
            if actionType == "spell" then
                MinionTooltip:AugmentTooltip(frame, id)
            end
        end)
    end

    if tooltip.SetHyperlink then
        hooksecurefunc(tooltip, "SetHyperlink", function(frame, link)
            if link and not link:match("spell:") then
                ClearAugmentFlag(frame)
                return
            end
            -- CA talent tree calls SetHyperlink then SetSpellByID; only augment once.
            if tooltip.SetSpellByID then
                return
            end
            local spellId = link and tonumber(link:match("spell:(%d+)"))
            if spellId then
                MinionTooltip:AugmentTooltip(frame, spellId)
            end
        end)
    end
end

function MinionTooltip:Init()
    if self.initialized then
        return
    end
    self.initialized = true

    MergeAnimationTalentTips()

    MancerDB.minionDps = MancerDB.minionDps or {}
    if MancerDB.minionDps.tooltipEnabled == nil then
        MancerDB.minionDps.tooltipEnabled = true
    end

    self:HookTooltip(GameTooltip)
    if ItemRefTooltip then
        self:HookTooltip(ItemRefTooltip)
    end
    if ShoppingTooltip1 then
        self:HookTooltip(ShoppingTooltip1)
    end
    if ShoppingTooltip2 then
        self:HookTooltip(ShoppingTooltip2)
    end
end

function MinionTooltip:SetEnabled(enabled)
    MancerDB.minionDps = MancerDB.minionDps or {}
    MancerDB.minionDps.tooltipEnabled = enabled and true or false
    if Mancer.Hub then
        Mancer.Hub:SyncControls()
    end
end
