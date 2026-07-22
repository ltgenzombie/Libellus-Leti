-- Paper DPS math from Ascension wiki Stats/Attributes (WotLK ratings)
-- plus live unit combat sheets for Raised minions.
-- Note: the wiki Ability Scaling Coefficients page is WIP / not Necro-complete.
-- Owner→pet inheritance (community creature math / Discord) applies to Raised
-- minions generally — Bone Wraith dump + Mortuus lvl~41 non-tank dummy close
-- the loop for ghouls (see NECROMANCY_INHERIT). Ghoul Command is tooltip $INT/$SP.
Mancer.PaperMathModule = {}
local PaperMath = Mancer.PaperMathModule

-- Rating → % at key levels (project-ascension.fandom.com/wiki/Stats_and_Attributes).
PaperMath.RATING = {
    [60] = {
        spellHit = 8,
        meleeHit = 10,
        crit = 14,
        haste = 10,
        intPerSpellCrit = 61,
    },
    [70] = {
        spellHit = 12.62,
        meleeHit = 15.77,
        crit = 22.08,
        haste = 15.77,
        intPerSpellCrit = 80,
    },
}

-- Sepulchral Might 2/2 (talent tooltip + Mortuus live check).
-- Tip: +10% Stam (you + Raised); spell dmg += 30% of Raised minions' total Stamina.
-- Live: 1 ghoul @ 742 HP → +16 spell damage ⇒ Stam ≈ 16/0.30 ≈ 53 (HP ≈ 14×Stam).
-- Do NOT multiply live UnitStat Stam by 1.10 again — sheet already includes the +10%.
PaperMath.SEPULCHRAL_STAM_MULT = 1.10 -- talent rank buff (already in UnitStat when talented)
PaperMath.SEPULCHRAL_SPELL_FROM_STAM = 0.30
-- Empirical HP→Stam when UnitStat fails on Ascension guardians (1 ghoul 742 HP / ~53 Stam).
PaperMath.SEPULCHRAL_HP_PER_STAM = 14

-- WotLK white-swing model: 1 AP ≈ 1 DPS / 14.
PaperMath.AP_PER_DPS = 14

-- Raise: Ghoul tooltip scripts (Ascension description — not classic EffectMultipleValue).
-- Auto heal on ghoul autos uses spell 707000 bases; Command uses spell 801514.
-- DBC bases extracted from Ascension Spell.dbc (WDBX/WotLK layout, Effect @ field 71).
PaperMath.GHOUL_TOOLTIP = {
    autoHealSpellId = 707000, -- named "Ghoul Frenzy" in Spell.dbc
    commandSpellId = 801514, -- "Command: Ghouls"
    raiseSpellId = 500971, -- summon only (creature misc 50073); no damage maths
    summonCreatureId = 50073,
    -- Heal on auto: m1 + ppl1 + (INT*0.504 + SP*0.504)*0.07
    -- 707000: Effect1 HEAL bp=4 → m1=5, ppl=0.35
    autoHealM1 = 5,
    autoHealPpl1 = 0.35,
    autoHealIntSp = 0.504,
    autoHealScale = 0.07,
    -- Command dmg: (INT*0.28+SP*0.28)*0.2 + (INT*0.504+SP*0.504)*0.2 + m1
    -- 801514: Effect1 SCHOOL_DAMAGE bp=29 → m1=30
    commandM1 = 30,
    commandIntSpA = 0.28,
    commandIntSpB = 0.504,
    commandScaleA = 0.2,
    commandScaleB = 0.2,
    -- Command heal per ghoul: m3 + ppl3 + SP*0.22 + INT*0.50
    -- 801514: Effect3 HEAL bp=14 → m3=15, ppl=0.5
    commandM3 = 15,
    commandPpl3 = 0.5,
    commandHealSp = 0.22,
    commandHealInt = 0.50,
}

-- Necromancy (804360): Undead gain AP/SP from owner INT+SP *based on their Life Force*.
-- Mortuus naked UnitAttackPower dumps (0 gear, INT≈78 SP≈0) — API works on targeted minions:
--   Ghoul/Rogue 1 LF: 87 | Fiend 2 LF: 153 | Abom 3 LF: 256
--   AP/14 ≈ 6.2 / 10.9 / 18.3 white DPS (ghoul matched melee floor ~6–7).
--   Fit: PetAP ≈ creatureBase + 0.882×(INT+SP)×LF  (bases ~15–20; abom base higher ~50).
--   Abom/Rogue AP ratio ≈ 2.94 ≈ LF 3. Stub (1,2,1) is NOT always true — dump "target".
-- Animates (Bone Wraith, Archer, …) occupy 0 LF — tip/DoT maths, NOT this LF×AP path.
--
-- Mortuus Crypt Fiend naked sheet (0 gear/buffs) — dump order:
--   UnitName, UnitHealthMax, UnitStat(,3), UnitDamage
--   Name Crypt Fiend | HP 1236 | Stam 31/31 | MH dmg ~36.2–39.7 (mult 1)
--   Prefer UnitStat Stam for Sepulchral (0.30×31≈+9.3); do NOT use HP/10 (would invent ~124 Stam).
--   If baseHP + ~10×Stam: base ≈ 926 + 310 = 1236.
--   Player +8: 1230→1310 (=10 HP/stam).
--   +8 owner: Ghoul +10 | Rogue/G.Skel +20 | Fiend +30 | Abom +60
--   Ghoul +37 owner: 732→782 (+50). Fits PetStam += Owner×0.271×LF @ ~5 HP/stam (predict +50).
--   Other raises ≈ same 0.271×LF @ ~10 HP/stam. Ghoul is half HP/stam, not half inherit rate.
PaperMath.NECROMANCY_INHERIT = {
    spellId = 804360,
    -- Per Life Force (candidate rates from creature dump — unconfirmed live).
    apPerLfFromSp = 0.882,
    apPerLfFromInt = 0.882,
    spPerLfFromSp = 0.4914,
    spPerLfFromInt = 0.4914,
    -- Legacy aliases (1 LF = old flat dump).
    apFromSp = 0.882,
    apFromInt = 0.882,
    spFromSp = 0.4914,
    spFromInt = 0.4914,
    stamFromStam = 0.271384,
    -- Historical mistaken flat rate (do not feed GetOwnerPetInheritPaper).
    -- stamFromStamGhoulLive = 0.10,
    armorFromArmor = 0.45,
    lifeForceCosts = {
        ghoul = 1,
        crypt_fiend = 2,
        banshee = 2,
        abomination = 3,
        skeletal_rogue = 1,
        skeletal_warrior_greater = 1,
        skeletal_warrior_lesser = 1,
        bone_wraith = 0, -- Animate
        skeletal_archer = 0,
        tomb_king = 0,
    },
}

-- Bone Wraith extras on top of shared inherit.
-- Tooltip script (805032): Bonestorm ≈ m1+ppl1+owner SP×0.4 (801411) — tip overstates live.
-- Two-point dummy (Mortuus lvl 41):
--   Naked (0 gear SP, INT 78): Bonestorm normal = 34 exactly (crit 68).
--   Geared (SP 224, INT 137): Bonestorm normal = 58 exactly.
--   Δ +24 dmg / +224 SP ⇒ live coeff ≈ 0.107  (hit ≈ 34 + SP×0.107).
-- Old 0.125 fit assumed floor=m1(30) and naked SP=0; naked floor is actually 34.
PaperMath.BONE_WRAITH = {
    animateSpellId = 805032,
    bonestormSpellId = 801411,
    bonestormAuraId = 801412,
    bonestormOwnerSpCoeffTip = 0.4,
    bonestormOwnerSpCoeffLive = 0.10714, -- 24/224 from naked↔geared dummy
    bonestormHitFloorLive = 34, -- naked 0-SP normal hit
    bonestormM1 = 30, -- Spell.dbc 801411 Effect1 bp=29, dieSides=1
    bonestormPpl1 = 0,
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

local function NearestRatingLevel(level)
    level = tonumber(level) or 60
    if level >= 70 then
        return 70
    end
    return 60
end

function PaperMath:GetRatingTable(level)
    return self.RATING[NearestRatingLevel(level)] or self.RATING[60]
end

function PaperMath:RatingToPercent(rating, ratingPerPercent)
    rating = tonumber(rating) or 0
    ratingPerPercent = tonumber(ratingPerPercent) or 0
    if ratingPerPercent <= 0 then
        return 0
    end
    return rating / ratingPerPercent
end

-- Inverse of RatingToPercent (ceil so gear aims are "at least this much").
function PaperMath:PercentToRating(percent, ratingPerPercent)
    percent = tonumber(percent) or 0
    ratingPerPercent = tonumber(ratingPerPercent) or 0
    if ratingPerPercent <= 0 or percent <= 0 then
        return 0
    end
    return math.ceil(percent * ratingPerPercent - 1e-6)
end

function PaperMath:GetPlayerPaperStats()
    local level = UnitLevel and UnitLevel("player") or 60
    local table = self:GetRatingTable(level)
    local int = UnitStat and select(1, UnitStat("player", 4)) or 0
    local spi = UnitStat and select(1, UnitStat("player", 5)) or 0
    local sta = UnitStat and select(1, UnitStat("player", 3)) or 0
    local str = UnitStat and select(1, UnitStat("player", 1)) or 0
    local agi = UnitStat and select(1, UnitStat("player", 2)) or 0

    local schools = {}
    local maxSpell = 0
    if GetSpellBonusDamage then
        for _, school in ipairs(SPELL_SCHOOLS) do
            local bonus = GetSpellBonusDamage(school.id) or 0
            schools[school.name] = bonus
            if bonus > maxSpell then
                maxSpell = bonus
            end
        end
    end

    local spellHitRating = (GetCombatRating and CR_HIT_SPELL and GetCombatRating(CR_HIT_SPELL)) or 0
    local critRating = (GetCombatRating and CR_CRIT_SPELL and GetCombatRating(CR_CRIT_SPELL)) or 0
    local hasteRating = (GetCombatRating and CR_HASTE_SPELL and GetCombatRating(CR_HASTE_SPELL))
        or (GetCombatRating and CR_HASTE_MELEE and GetCombatRating(CR_HASTE_MELEE))
        or 0

    local base, pos, neg = 0, 0, 0
    if UnitAttackPower then
        base, pos, neg = UnitAttackPower("player")
    end
    local playerAP = (base or 0) + (pos or 0) + (neg or 0)

    local petSpell = 0
    if GetPetSpellBonusDamage then
        petSpell = GetPetSpellBonusDamage() or 0
    end

    local armor = 0
    if UnitArmor then
        armor = select(1, UnitArmor("player")) or 0
    end

    return {
        level = level,
        ratingLevel = NearestRatingLevel(level),
        intellect = int,
        spirit = spi,
        stamina = sta,
        strength = str,
        agility = agi,
        armor = armor,
        spellBonus = schools,
        spellDamage = maxSpell,
        spellHitRating = spellHitRating,
        spellHitPct = self:RatingToPercent(spellHitRating, table.spellHit),
        critRating = critRating,
        critPctFromRating = self:RatingToPercent(critRating, table.crit),
        spellCritFromInt = self:RatingToPercent(int, table.intPerSpellCrit),
        hasteRating = hasteRating,
        hastePct = self:RatingToPercent(hasteRating, table.haste),
        attackPower = playerAP,
        apWhiteDps = playerAP / self.AP_PER_DPS,
        petSpellBonus = petSpell,
        -- Wiki: Intellect specialization doubles Spell Damage from Spell Power.
        -- GetSpellBonusDamage already returns the final (post-spec) value.
        wikiNote = "INT spec doubles SP→spell damage (already in spell bonus). Coeff page is WIP.",
    }
end

function PaperMath:GetUnitCombatSheet(unit)
    if not unit then
        return nil
    end
    -- Do not require UnitExists — Ascension guardians often fail Exists on nameplates
    -- until targeted, while UnitName / UnitDamage still return values.
    if UnitIsDead and UnitExists and UnitExists(unit) and UnitIsDead(unit) then
        return nil
    end

    local name = UnitName and UnitName(unit) or nil
    if not name or name == "" then
        return nil
    end
    local level = UnitLevel and UnitLevel(unit) or 0

    local stam = 0
    if UnitStat then
        stam = select(1, UnitStat(unit, 3)) or 0
    end
    -- Ascension guardians often report Stam 0; estimate from max HP (Mortuus: 742 HP ≈ 53 Stam).
    if stam <= 0 and UnitHealthMax then
        local hp = tonumber(UnitHealthMax(unit)) or 0
        if hp > 0 and self.SEPULCHRAL_HP_PER_STAM and self.SEPULCHRAL_HP_PER_STAM > 0 then
            stam = math.floor(hp / self.SEPULCHRAL_HP_PER_STAM + 0.5)
        end
    end

    local base, pos, neg = 0, 0, 0
    local apApiStub = false
    if UnitAttackPower then
        base, pos, neg = UnitAttackPower(unit)
        base = tonumber(base) or 0
        pos = tonumber(pos) or 0
        neg = tonumber(neg) or 0
        -- Ascension necro minions: UnitAttackPower often returns stub (1, 2, 1) — not real AP.
        if base == 1 and pos == 2 and (neg == 1 or neg == -1) then
            apApiStub = true
            base, pos, neg = 0, 0, 0
        end
    end
    local ap = base + pos + neg
    if apApiStub then
        ap = 0
    end

    local dmgMin, dmgMax = 0, 0
    local offMin, offMax = 0, 0
    if UnitDamage then
        dmgMin, dmgMax, offMin, offMax = UnitDamage(unit)
        dmgMin = tonumber(dmgMin) or 0
        dmgMax = tonumber(dmgMax) or 0
        offMin = tonumber(offMin) or 0
        offMax = tonumber(offMax) or 0
    end

    local speed, offSpeed = 0, 0
    if UnitAttackSpeed then
        speed, offSpeed = UnitAttackSpeed(unit)
        speed = tonumber(speed) or 0
        offSpeed = tonumber(offSpeed) or 0
    end

    local avg = (dmgMin + dmgMax) / 2
    local paperAuto = 0
    if speed > 0 and avg > 0 then
        paperAuto = avg / speed
    end
    if offSpeed and offSpeed > 0 and (offMin + offMax) > 0 then
        paperAuto = paperAuto + ((offMin + offMax) / 2) / offSpeed
    end

    local apWhite = ap / self.AP_PER_DPS

    local critChance = 0
    if UnitCritChance then
        local ok, value = pcall(UnitCritChance, unit)
        if ok and value then
            critChance = tonumber(value) or 0
        end
    end

    local paperWithCrit = paperAuto * (1 + critChance / 100)

    return {
        unit = unit,
        name = name,
        level = level,
        stamina = stam,
        attackPower = ap,
        attackPowerApiStub = apApiStub,
        damageMin = dmgMin,
        damageMax = dmgMax,
        attackSpeed = speed,
        paperAutoDps = paperAuto,
        paperAutoDpsWithCrit = paperWithCrit,
        apWhiteDps = apWhite,
        critChance = critChance,
    }
end

function PaperMath:ScanArmySheets()
    local Advisor = GetAdvisor()
    local rows = {}
    local seenGuid = {}

    if Advisor and Advisor.ClearPollCaches then
        Advisor:ClearPollCaches()
    end
    if Advisor then
        Advisor.cachedScanUnits = nil
        Advisor.cachedScanUnitsUntil = 0
    end

    local function addUnit(unit, minionId)
        if not unit then
            return
        end
        -- Ascension nameplates: UnitExists can be false while UnitName/UnitDamage still work.
        local name = UnitName and UnitName(unit)
        if not name or name == "" then
            return
        end

        local guid = UnitGUID and UnitGUID(unit)
        if guid and seenGuid[guid] then
            return
        end
        if guid then
            seenGuid[guid] = true
        end

        local sheet = self:GetUnitCombatSheet(unit)
        if not sheet then
            return
        end
        -- Sheet needs real combat values; skip empty shells.
        if (sheet.attackPower or 0) <= 0 and (sheet.paperAutoDps or 0) <= 0 and (sheet.stamina or 0) <= 0 then
            return
        end

        sheet.minionId = minionId
        if not sheet.minionId and Advisor and Advisor.ClassifyMinionName then
            sheet.minionId = Advisor:ClassifyMinionName(sheet.name)
        end
        table.insert(rows, sheet)
    end

    local function classify(unit)
        if not Advisor then
            return nil
        end
        -- Prefer ScanUnitToken (guardian ownership — works without hard target).
        if Advisor.ScanUnitToken then
            local minionId = Advisor:ScanUnitToken(unit)
            if minionId then
                return minionId
            end
        end
        local name = UnitName and UnitName(unit)
        if name and Advisor.IsOwnedGuardianUnit and Advisor:IsOwnedGuardianUnit(unit, name) then
            return Advisor:ClassifyMinionName(name)
        end
        if name and Advisor.ClassifyMinionName and Advisor.IsPlayerMinionUnit and Advisor:IsPlayerMinionUnit(unit) then
            return Advisor:ClassifyMinionName(name)
        end
        return nil
    end

    local function tryUnit(unit)
        local minionId = classify(unit)
        if minionId then
            addUnit(unit, minionId)
        end
    end

    -- Always probe these (same set Status uses for visible ghouls).
    for i = 1, 40 do
        tryUnit("nameplate" .. i)
    end

    tryUnit("pet")
    tryUnit("target")
    tryUnit("focus")
    tryUnit("mouseover")

    if Advisor and Advisor.GetLightweightTempScanUnits then
        for _, unit in ipairs(Advisor:GetLightweightTempScanUnits()) do
            tryUnit(unit)
        end
    elseif Advisor and Advisor.GetAllScanUnits then
        for _, unit in ipairs(Advisor:GetAllScanUnits()) do
            tryUnit(unit)
        end
    end

    if Advisor and Advisor.trackedUnits then
        for unit in pairs(Advisor.trackedUnits) do
            tryUnit(unit)
        end
    end

    return rows
end

function PaperMath:SummarizeArmy(rows)
    rows = rows or self:ScanArmySheets()
    local totalAuto = 0
    local totalApWhite = 0
    local totalStam = 0
    local byType = {}

    for _, sheet in ipairs(rows) do
        totalAuto = totalAuto + (sheet.paperAutoDps or 0)
        totalApWhite = totalApWhite + (sheet.apWhiteDps or 0)
        totalStam = totalStam + (sheet.stamina or 0)
        local id = sheet.minionId or "unknown"
        local bucket = byType[id]
        if not bucket then
            bucket = { count = 0, auto = 0, ap = 0, stam = 0, sheets = {} }
            byType[id] = bucket
        end
        bucket.count = bucket.count + 1
        bucket.auto = bucket.auto + (sheet.paperAutoDps or 0)
        bucket.ap = bucket.ap + (sheet.attackPower or 0)
        bucket.stam = bucket.stam + (sheet.stamina or 0)
        table.insert(bucket.sheets, sheet)
    end

    -- If Status knows more ghouls than we could sheet-read, extrapolate from sampled average.
    local Advisor = GetAdvisor()
    local extrapolated = false
    if Advisor and Advisor.CollectActiveMinions then
        local counts = Advisor:CollectActiveMinions()
        for minionId, want in pairs(counts or {}) do
            want = tonumber(want) or 0
            local bucket = byType[minionId]
            local have = bucket and bucket.count or 0
            if want > have and have > 0 then
                local avgAuto = bucket.auto / have
                local avgAp = bucket.ap / have
                local avgStam = bucket.stam / have
                local missing = want - have
                bucket.count = want
                bucket.auto = bucket.auto + avgAuto * missing
                bucket.ap = bucket.ap + avgAp * missing
                bucket.stam = bucket.stam + avgStam * missing
                totalAuto = totalAuto + avgAuto * missing
                totalApWhite = totalApWhite + (avgAp / self.AP_PER_DPS) * missing
                totalStam = totalStam + avgStam * missing
                extrapolated = true
                bucket.extrapolated = missing
            elseif want > 0 and have == 0 then
                byType[minionId] = byType[minionId] or {
                    count = want,
                    auto = 0,
                    ap = 0,
                    stam = 0,
                    sheets = {},
                    unscanned = want,
                }
                extrapolated = true
            end
        end
    end

    local sepulchral = totalStam * self.SEPULCHRAL_SPELL_FROM_STAM

    return {
        rows = rows,
        byType = byType,
        totalAutoDps = totalAuto,
        totalApWhiteDps = totalApWhite,
        totalStamina = totalStam,
        sepulchralSpellDamage = sepulchral,
        unitCount = #rows,
        extrapolated = extrapolated,
    }
end

function PaperMath:EstimateSpellHit(baseDamage, schoolId)
    local player = self:GetPlayerPaperStats()
    schoolId = tonumber(schoolId) or 6
    local bonus = 0
    if GetSpellBonusDamage then
        bonus = GetSpellBonusDamage(schoolId) or 0
    end
    -- Without a real coefficient, report SP contribution only if caller supplies coeff.
    return {
        base = tonumber(baseDamage) or 0,
        spellBonus = bonus,
        schoolId = schoolId,
        note = "Need spell coefficient (wiki coeff page is WIP). Paper = base + SP × coeff.",
    }
end

function PaperMath:PaperSpellDamage(baseDamage, coefficient, schoolId)
    baseDamage = tonumber(baseDamage) or 0
    coefficient = tonumber(coefficient) or 0
    schoolId = tonumber(schoolId) or 6
    local bonus = GetSpellBonusDamage and (GetSpellBonusDamage(schoolId) or 0) or 0
    return baseDamage + bonus * coefficient
end

-- Uses Ascension Raise: Ghoul tooltip variables $INT / $SP (sheet INT + max spell bonus).
-- DBC m1/m3/ppl filled from Spell.dbc (801514 / 707000).
function PaperMath:GetGhoulTooltipPaper(dbc)
    local player = self:GetPlayerPaperStats()
    local g = self.GHOUL_TOOLTIP
    local int = player.intellect or 0
    local sp = player.spellBonus and (player.spellBonus.Shadow or player.spellDamage) or player.spellDamage or 0
    dbc = dbc or {}

    local level = player.level or 0
    local autoM1 = tonumber(dbc.autoM1) or g.autoHealM1 or 0
    local autoPpl = tonumber(dbc.autoPpl1) or g.autoHealPpl1 or 0
    -- ppl usually scales with (level - spellLevel); tooltip uses raw ppl term — show base+scaling SP/INT and note ppl.
    local autoHeal = autoM1 + (int * g.autoHealIntSp + sp * g.autoHealIntSp) * g.autoHealScale
    local autoHealWithPpl = autoHeal + autoPpl -- rough; exact ppl*level delta needs spellLevel

    local commandScale = (int * g.commandIntSpA + sp * g.commandIntSpA) * g.commandScaleA
        + (int * g.commandIntSpB + sp * g.commandIntSpB) * g.commandScaleB
    local commandBase = tonumber(dbc.commandM1) or g.commandM1 or 0
    local commandDamage = commandScale + commandBase

    local commandM3 = tonumber(dbc.commandM3) or g.commandM3 or 0
    local commandPpl3 = tonumber(dbc.commandPpl3) or g.commandPpl3 or 0
    local commandHeal = commandM3 + sp * g.commandHealSp + int * g.commandHealInt

    return {
        intellect = int,
        spellPower = sp,
        level = level,
        autoHealPerHit = autoHeal,
        autoHealPerHitInclPplHint = autoHealWithPpl,
        autoHealPpl1 = autoPpl,
        autoHealScalingOnly = (int * g.autoHealIntSp + sp * g.autoHealIntSp) * g.autoHealScale,
        commandDamage = commandDamage,
        commandDamageScalingOnly = commandScale,
        commandM1 = commandBase,
        commandHealPerGhoul = commandHeal,
        commandM3 = commandM3,
        commandPpl3 = commandPpl3,
        commandSpellId = g.commandSpellId,
        autoHealSpellId = g.autoHealSpellId,
        summonCreatureId = g.summonCreatureId,
        note = "White auto damage is still unit-sheet (AP/damage), not this tooltip.",
    }
end

-- Necromancy (804360): AP/SP from owner INT+SP, scaled by the minion's Life Force cost.
-- lifeForceCost 0 = Animate / no LF path (do not use Raised AP formula).
function PaperMath:GetOwnerPetInheritPaper(lifeForceCost)
    local player = self:GetPlayerPaperStats()
    local inherit = self.NECROMANCY_INHERIT
    local int = player.intellect or 0
    local sp = player.spellBonus and (player.spellBonus.Shadow or player.spellDamage) or player.spellDamage or 0
    local sta = player.stamina or 0
    local armor = player.armor or 0
    local lf = tonumber(lifeForceCost)
    if lf == nil then
        lf = 1
    end

    local apPerLf = (inherit.apPerLfFromSp or inherit.apFromSp or 0) * sp
        + (inherit.apPerLfFromInt or inherit.apFromInt or 0) * int
    local spPerLf = (inherit.spPerLfFromSp or inherit.spFromSp or 0) * sp
        + (inherit.spPerLfFromInt or inherit.spFromInt or 0) * int
    local petAp = apPerLf * lf
    local petSp = spPerLf * lf
    -- Live A/B: PetStam += OwnerStam × 0.271 × LF (ghoul half HP/stam, same inherit rate).
    -- stamFromStamGhoulLive (0.10) was a bad paper shortcut — do not use for all types.
    local stamRate = inherit.stamFromStam or 0
    local petStam = (lf > 0) and (sta * stamRate * lf) or 0
    local petArmor = armor * (inherit.armorFromArmor or 0)

    return {
        intellect = int,
        spellPower = sp,
        stamina = sta,
        armor = armor,
        lifeForceCost = lf,
        apPerLifeForce = apPerLf,
        spPerLifeForce = spPerLf,
        petApFromOwner = petAp,
        petSpFromOwner = petSp,
        petStamFromOwner = petStam,
        petArmorFromOwner = petArmor,
        inheritedApWhiteDps = lf > 0 and (petAp / self.AP_PER_DPS) or 0,
        note = lf > 0
            and string.format("Necromancy AP/SP × %d LF (hypothesis). Animates are LF 0 — separate maths.", lf)
            or "LF 0 (Animate): Necromancy AP×LF path N/A — use ability tip maths.",
    }
end

function PaperMath:GetMinionLifeForceCost(minionId)
    local inherit = self.NECROMANCY_INHERIT
    if inherit.lifeForceCosts and inherit.lifeForceCosts[minionId] ~= nil then
        return inherit.lifeForceCosts[minionId]
    end
    local Advisor = GetAdvisor()
    if Advisor and Advisor.GetMinionLifeForceCost then
        return Advisor:GetMinionLifeForceCost(minionId) or 1
    end
    if Advisor and Advisor.MINION_TYPES and Advisor.MINION_TYPES[minionId] then
        return Advisor.MINION_TYPES[minionId].lifeForceCost or 1
    end
    return 1
end

-- Ghoul package = LF×1 Necromancy inherit + Command tooltip (owner $INT/$SP).
function PaperMath:GetGhoulInheritPaper()
    local inherit = self:GetOwnerPetInheritPaper(self:GetMinionLifeForceCost("ghoul"))
    local tip = self:GetGhoulTooltipPaper()
    inherit.commandDamage = tip.commandDamage
    inherit.commandDamageScalingOnly = tip.commandDamageScalingOnly
    inherit.autoHealPerHit = tip.autoHealPerHit
    inherit.note = "Ghoul = 1 LF Necromancy AP/SP path (coeff/LF unconfirmed). Command tip is separate."
    return inherit
end

-- Bone Wraith = Animate (0 LF). Bonestorm uses owner-$SP tip math; not Raise LF×AP.
function PaperMath:GetBoneWraithPaper()
    local inherit = self:GetOwnerPetInheritPaper(0)
    local w = self.BONE_WRAITH
    local sp = inherit.spellPower or 0
    local m1 = w.bonestormM1 or 0
    local ppl = w.bonestormPpl1 or 0
    local floorLive = w.bonestormHitFloorLive or m1
    inherit.bonestormOwnerSpSliceTip = sp * (w.bonestormOwnerSpCoeffTip or 0)
    inherit.bonestormOwnerSpSliceLive = sp * (w.bonestormOwnerSpCoeffLive or 0)
    inherit.bonestormHitTip = m1 + ppl + inherit.bonestormOwnerSpSliceTip
    inherit.bonestormHitLive = floorLive + inherit.bonestormOwnerSpSliceLive
    inherit.bonestormHitFloorLive = floorLive
    inherit.bonestormM1 = m1
    inherit.animateSpellId = w.animateSpellId
    inherit.bonestormSpellId = w.bonestormSpellId
    inherit.bonestormOwnerSpSlice = inherit.bonestormOwnerSpSliceLive
    inherit.note = "Animate (0 LF): Bonestorm ≈ 34 + SP×0.107 live; tip SP×0.4 wrong. Not Necromancy LF×AP."
    return inherit
end

local function FindMeasuredSpell(spells, needle)
    needle = string.lower(needle or "")
    for _, row in ipairs(spells or {}) do
        local label = string.lower(row.label or "")
        if label == needle or label:find(needle, 1, true) then
            return row
        end
    end
    return nil
end

-- Predict-vs-live test for the "shared 0.882 AP inherit" hypothesis.
-- Best proofs: (1) measured Melee DPS A/B vs SP — UnitAttackPower on Ascension
-- minions is a stub (often returns 1, 2, 1), so sheet AP cannot validate inherit.
-- (2) sheet UnitDamage/speed when non-zero, (3) Command tip hit vs measured.
function PaperMath:PrintInheritHypothesisTest(army, measured, measuredSource)
    local inherit = self:GetOwnerPetInheritPaper()
    local tip = self:GetGhoulTooltipPaper()
    local predictedAp = inherit.petApFromOwner or 0
    local predictedWhite = inherit.inheritedApWhiteDps or 0

    Mancer.Print("--- Inherit hypothesis test (Necromancy 804360 × Life Force) ---")
    Mancer.Print("  Raised: Pet AP/SP from (INT+SP) × per-LF coeff × LF cost (ghoul1 / fiend2 / abom3).")
    Mancer.Print("  Animates: 0 LF — ability tip maths (e.g. Bonestorm), not this AP×LF path.")
    Mancer.Print(string.format(
        "  Per-LF candidate dump: AP += 0.882×(INT+SP) → ×1 LF ≈%.0f AP (≈%.1f white DPS)",
        predictedAp, predictedWhite
    ))
    local fiend = self:GetOwnerPetInheritPaper(2)
    local abom = self:GetOwnerPetInheritPaper(3)
    Mancer.Print(string.format(
        "  Same coeffs × LF: Fiend(2) ≈%.0f AP / %.1f DPS | Abom(3) ≈%.0f AP / %.1f DPS",
        fiend.petApFromOwner, fiend.inheritedApWhiteDps, abom.petApFromOwner, abom.inheritedApWhiteDps
    ))

    local ghoulBucket = army and army.byType and army.byType.ghoul
    if ghoulBucket and ghoulBucket.count and ghoulBucket.count > 0 then
        local liveAp = (ghoulBucket.ap or 0) / ghoulBucket.count
        local liveAuto = (ghoulBucket.auto or 0) / ghoulBucket.count
        Mancer.Print(string.format(
            "  Live ghoul sheet: avg AP %.0f | paper auto ≈%.1f DPS/unit ×%d",
            liveAp, liveAuto, ghoulBucket.count
        ))
        if liveAp <= 0 and liveAuto <= 0 then
            Mancer.Print("  Sheet AP/auto unusable — Ascension UnitAttackPower on minions is a stub (e.g. 1, 2, 1).")
            Mancer.Print("  Use measured Melee + implied X (cannot AP-check via API).")
        else
            local baseGuess = liveAp - predictedAp
            local apRatio = predictedAp > 0 and (liveAp / predictedAp) or 0
            Mancer.Print(string.format(
                "  AP check: live − inherit = %.0f (creature base + buffs if X=0.882 is exact)",
                baseGuess
            ))
            Mancer.Print(string.format(
                "  liveAP / inheritAP = %.2f  (≈1.0 + base/inherit ⇒ coeffs look good; <<1 or >>1 ⇒ different X)",
                apRatio
            ))
            Mancer.Print(string.format(
                "  White predict: inherit AP/14 ≈%.1f vs sheet auto ≈%.1f  (Δ %.1f)",
                predictedWhite, liveAuto, liveAuto - predictedWhite
            ))
        end
    else
        Mancer.Print("  No live ghoul sheet — summon ghouls + friendly nameplates (or target one).")
    end

    -- Walk any scanned types: same predicted inherit AP compared to each type's avg AP.
    if army and army.byType then
        local parts = {}
        for minionId, bucket in pairs(army.byType) do
            if bucket.count and bucket.count > 0 and (bucket.ap or 0) > 0 then
                local liveAp = bucket.ap / bucket.count
                local label = minionId
                local Advisor = GetAdvisor()
                if Advisor and Advisor.MINION_TYPES and Advisor.MINION_TYPES[minionId] then
                    label = Advisor.MINION_TYPES[minionId].label or minionId
                end
                table.insert(parts, string.format("%s AP%.0f (Δ%+.0f)", label, liveAp, liveAp - predictedAp))
            end
        end
        if #parts > 0 then
            Mancer.Print("  All scanned minions vs same inherit AP: " .. table.concat(parts, " | "))
            Mancer.Print("  Similar Δ across types ⇒ shared X; wild Δ spread ⇒ per-creature (or Animate) rates.")
        end
    end

    local intSp = (inherit.intellect or 0) + (inherit.spellPower or 0)
    local ghoulMeasured = measured and measured.ghoul
    if ghoulMeasured and ghoulMeasured.spells then
        local melee = FindMeasuredSpell(ghoulMeasured.spells, "melee")
        local command = FindMeasuredSpell(ghoulMeasured.spells, "command")
        local source = measuredSource or "fight"
        local meleeDps = nil
        if melee and melee.dps then
            meleeDps = melee.dps
        elseif melee and melee.damage and ghoulMeasured.damage and ghoulMeasured.dps then
            meleeDps = ghoulMeasured.dps * (melee.damage / math.max(1, ghoulMeasured.damage))
        end
        if meleeDps then
            Mancer.Print(string.format(
                "  Measured Melee (%s) ≈%.1f DPS/unit vs Wraith predict ≈%.1f (Δ %.1f)",
                source, meleeDps, predictedWhite, meleeDps - predictedWhite
            ))
            if intSp > 0 then
                -- Assume base AP≈0 and whites ≈ AP/14: imply Pet AP += X×(INT+SP).
                local impliedAp = meleeDps * self.AP_PER_DPS
                local impliedX = impliedAp / intSp
                Mancer.Print(string.format(
                    "  Implied ghoul X ≈ %.3f  [meleeDPS×14 / (INT+SP)=%.0f / %d]  vs Wraith 0.882",
                    impliedX, impliedAp, intSp
                ))
                if math.abs(impliedX - 0.882) > 0.08 then
                    Mancer.Print("  Verdict: 0.882 does NOT fit this Melee-only sample — treat as different X or incomplete model.")
                else
                    Mancer.Print("  Verdict: within ~0.08 of 0.882 — still plausible pending gear-swap.")
                end
            end
        else
            Mancer.Print("  No measured Melee row yet — dummy fight with ghouls, then reopen Paper.")
        end
        if command and command.hits and command.hits > 0 and command.damage then
            local avgHit = command.damage / command.hits
            Mancer.Print(string.format(
                "  Command avg hit %.1f vs tip predict %.1f  (Δ %.1f)  [crits inflate avg; tip is non-crit]",
                avgHit, tip.commandDamage or 0, avgHit - (tip.commandDamage or 0)
            ))
        end
    else
        Mancer.Print("  No Minion DPS ghoul sample — run a dummy pull so Melee/Command can compare.")
    end
    Mancer.Print("  Gear-swap test: if Melee DPS tracks X×Δ(INT+SP)/14, X is confirmed (sheet AP optional).")
    Mancer.Print("")
end

function PaperMath:PrintReport()
    local player = self:GetPlayerPaperStats()
    local army = self:SummarizeArmy()
    local MinionDps = GetMinionDps()
    local measured, measuredSource = nil, nil
    if MinionDps and MinionDps.GetDpsEstimates then
        measured, _, measuredSource = MinionDps:GetDpsEstimates()
    end
    -- Prefer fight spell rows (Melee/Command) when available.
    if MinionDps and MinionDps.AggregateFightStats then
        local fight = MinionDps.currentFight
        if fight and fight.startedAt then
            local current = MinionDps:AggregateFightStats(fight)
            if current and current.ghoul and current.ghoul.spells then
                measured, measuredSource = current, "current"
            end
        end
        local db = MancerDB and MancerDB.minionDps
        if (not measured or not measured.ghoul or not measured.ghoul.spells) and db and db.fights and db.fights[1] then
            local last = MinionDps:AggregateFightStats(db.fights[1])
            if last and last.ghoul then
                measured, measuredSource = last, "last"
            end
        end
    end
    local ghoulPaper = self:GetGhoulTooltipPaper()
    local ghoulInherit = self:GetGhoulInheritPaper()
    local wraithPaper = self:GetBoneWraithPaper()

    Mancer.Print("Paper DPS — player sheet + live minion combat stats")
    Mancer.Print("Ghoul Command = tip scripts; ghoul/wraith whites = HYPOTHESIS shared inherit (0.882 AP).")
    Mancer.Print("Minion paper auto DPS = UnitDamage ÷ UnitAttackSpeed (includes their AP).")
    Mancer.Print(string.format("AP/14 check: 1 AP ≈ %.3f white DPS (WotLK model).", 1 / self.AP_PER_DPS))
    Mancer.Print("")

    Mancer.Print("--- Player ---")
    Mancer.Print(string.format(
        "  Level %d | INT %d | STA %d | SPI %d | Armor %d",
        player.level, player.intellect, player.stamina, player.spirit, player.armor or 0
    ))
    Mancer.Print(string.format(
        "  Spell damage (max school): %d  |  Shadow: %d",
        player.spellDamage,
        player.spellBonus.Shadow or 0
    ))
    if player.petSpellBonus and player.petSpellBonus > 0 then
        Mancer.Print(string.format("  Pet spell bonus (client): %d", player.petSpellBonus))
    end
    Mancer.Print(string.format(
        "  Spell hit: %.1f%% from %d rating | Crit rating→%.1f%% | INT→%.1f%% spell crit | Haste %.1f%%",
        player.spellHitPct, player.spellHitRating,
        player.critPctFromRating, player.spellCritFromInt, player.hastePct
    ))
    Mancer.Print(string.format(
        "  Player AP %d → ≈%.1f white DPS (AP/14)",
        player.attackPower, player.apWhiteDps
    ))
    Mancer.Print("  " .. player.wikiNote)
    Mancer.Print("")

    Mancer.Print("--- Raise: Ghoul tooltip maths (Ascension script + Spell.dbc) ---")
    Mancer.Print(string.format(
        "  Using INT %d + SP %d (Shadow/max spell bonus as $SP).",
        ghoulPaper.intellect, ghoulPaper.spellPower
    ))
    Mancer.Print(string.format(
        "  Raise: Ghoul (500971) summons creature %s — no damage maths on that row.",
        tostring(ghoulPaper.summonCreatureId or "?")
    ))
    Mancer.Print(string.format(
        "  Auto→you heal ≈%.1f  [707000 m1=5 + (INT+SP)×0.03528; ppl=%.2f extra]",
        ghoulPaper.autoHealPerHit, ghoulPaper.autoHealPpl1 or 0
    ))
    Mancer.Print(string.format(
        "  Command plague dmg ≈%.1f  [801514 m1=%d + (INT+SP)×0.1568]",
        ghoulPaper.commandDamage, ghoulPaper.commandM1 or 0
    ))
    Mancer.Print(string.format(
        "  Command heal / ghoul ≈%.1f  [m3=%d + SP×0.22 + INT×0.50; ppl3=%.1f]",
        ghoulPaper.commandHealPerGhoul, ghoulPaper.commandM3 or 0, ghoulPaper.commandPpl3 or 0
    ))
    Mancer.Print("  " .. ghoulPaper.note)
    Mancer.Print(string.format(
        "  Inherit whites ≈%.1f DPS/unit  [hypothesis AP×0.882 → +%.0f pet AP]",
        ghoulInherit.inheritedApWhiteDps, ghoulInherit.petApFromOwner
    ))
    Mancer.Print("  " .. ghoulInherit.note)
    Mancer.Print("")

    self:PrintInheritHypothesisTest(army, measured, measuredSource)

    Mancer.Print("--- Owner→pet inheritance (Necromancy × LF; dump coeffs are candidates) ---")
    Mancer.Print(string.format(
        "  Using INT %d + SP %d + STA %d + Armor %d.",
        wraithPaper.intellect, wraithPaper.spellPower, wraithPaper.stamina, wraithPaper.armor
    ))
    local g1 = self:GetOwnerPetInheritPaper(1)
    Mancer.Print(string.format(
        "  Per LF: +%.0f AP / +%.0f SP  [0.882 AP & 0.4914 SP × (INT+SP)]",
        g1.apPerLifeForce or 0, g1.spPerLifeForce or 0
    ))
    Mancer.Print(string.format(
        "  ×1 LF (Ghoul) ≈%.0f AP → ≈%.1f white | ×2 Fiend ≈%.0f | ×3 Abom ≈%.0f",
        g1.petApFromOwner,
        g1.inheritedApWhiteDps,
        self:GetOwnerPetInheritPaper(2).petApFromOwner,
        self:GetOwnerPetInheritPaper(3).petApFromOwner
    ))
    Mancer.Print(string.format(
        "  Bonestorm tip ≈%.0f  [m1=%d + SP×0.4] | live A/B ≈%.0f  [floor %d + SP×0.107]",
        wraithPaper.bonestormHitTip or 0,
        wraithPaper.bonestormM1 or 30,
        wraithPaper.bonestormHitLive or 0,
        wraithPaper.bonestormHitFloorLive or 34
    ))
    Mancer.Print("  Naked 0-SP dummy: Bonestorm 34/hit; geared SP 224 → 58/hit (+24). Tip 0.4 is ~4× high.")
    Mancer.Print("  " .. wraithPaper.note)
    Mancer.Print("")

    Mancer.Print("--- Raised army (live units) ---")
    if army.unitCount == 0 then
        Mancer.Print("  No scannable minion units yet.")
        Mancer.Print("  Tip: enable Friendly Nameplates (or V key) so guardians get nameplate tokens.")
        Mancer.Print("  Targeting one minion still works as a fallback sample.")
        local Advisor = GetAdvisor()
        if Advisor and Advisor.CollectActiveMinions then
            local counts = Advisor:CollectActiveMinions()
            local parts = {}
            for minionId, n in pairs(counts or {}) do
                if n and n > 0 then
                    local label = minionId
                    if Advisor.MINION_TYPES and Advisor.MINION_TYPES[minionId] then
                        label = Advisor.MINION_TYPES[minionId].label or minionId
                    end
                    table.insert(parts, string.format("%s×%d", label, n))
                end
            end
            if #parts > 0 then
                Mancer.Print("  Status sees army: " .. table.concat(parts, ", ") .. " (no unit sheet yet).")
            end
        end
    else
        for minionId, bucket in pairs(army.byType) do
            local label = minionId
            local Advisor = GetAdvisor()
            if Advisor and Advisor.MINION_TYPES and Advisor.MINION_TYPES[minionId] then
                label = Advisor.MINION_TYPES[minionId].label or minionId
            end
            local avgAp = bucket.count > 0 and (bucket.ap / bucket.count) or 0
            local avgAuto = bucket.count > 0 and (bucket.auto / bucket.count) or 0
            local extra = ""
            if bucket.extrapolated and bucket.extrapolated > 0 then
                extra = string.format(" (incl. %d extrapolated)", bucket.extrapolated)
            elseif bucket.unscanned and bucket.unscanned > 0 then
                extra = " (counted but no sheet — turn on friendly nameplates)"
            end
            Mancer.Print(string.format(
                "  %s ×%d | avg AP %.0f | paper auto ≈%.1f DPS/unit (Σ %.1f) | Stam Σ %d%s",
                label, bucket.count, avgAp, avgAuto, bucket.auto, bucket.stam, extra
            ))

            local measuredRow = measured and measured[minionId]
            if measuredRow and measuredRow.dps and measuredRow.dps > 0 and avgAuto > 0 then
                Mancer.Print(string.format(
                    "    Measured/benchmark ≈%.1f DPS/unit vs paper auto ≈%.1f (Command/DoTs not in auto).",
                    measuredRow.dps, avgAuto
                ))
            end
        end
        Mancer.Print(string.format(
            "  Army paper auto Σ ≈%.1f DPS | AP/14 Σ ≈%.1f | Raised Stam Σ %d",
            army.totalAutoDps, army.totalApWhiteDps, army.totalStamina
        ))
        Mancer.Print(string.format(
            "  Sepulchral Might 2/2 paper: spell dmg +%.0f  (0.30 × Raised Stam Σ %d; live UnitStat, no extra ×1.10)",
            army.sepulchralSpellDamage, army.totalStamina
        ))
        if army.extrapolated then
            Mancer.Print("  Note: some units extrapolated from sampled sheets × Status count.")
        end
        local ghoulCount = (army.byType.ghoul and army.byType.ghoul.count) or 0
        if ghoulCount > 0 then
            Mancer.Print(string.format(
                "  Command paper (scaling×1 hit): ≈%.1f plague; heal ≈%.1f × %d ghoul(s) ≈%.1f",
                ghoulPaper.commandDamageScalingOnly,
                ghoulPaper.commandHealPerGhoul,
                ghoulCount,
                ghoulPaper.commandHealPerGhoul * ghoulCount
            ))
        end
        Mancer.Print("  Paper auto is melee whites only — Command package uses tooltip script above.")
    end
end
