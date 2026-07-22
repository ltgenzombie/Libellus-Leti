Mancer.NecromancerAdvisorModule = {}
local Advisor = Mancer.NecromancerAdvisorModule
local Ascension = Mancer.Ascension

Advisor.MINION_TYPES = {
    ghoul = {
        label = "Ghoul",
        namePatterns = {
            "Ghoul", "Geist", "Risen", "Gurgling Horror", "Gurgling", "Horror",
            "Putrid Ghoul", "Rotling",
        },
        talentPatterns = {
            "Raise: Ghoul", "Raise: Gurgling Horror", "Ghoulkeeper", "Ghoulify",
            "Ghoul Commander", "Ghoul Mastery",
        },
        summonSpellIds = { [500971] = true, [45850] = true, [45861] = true },
        buffSpellIds = { [680761] = true, [805019] = true },
        trackMode = "buff",
        trackUnits = true,
        -- Soft fallback while LF has not been seen yet (early game ~1–4).
        -- Live pool is tracked dynamically by lifeForcePeak / GetLifeForceMax().
        defaultMax = 4,
        talentTree = "class",
        typicalClassPointCost = 2,
        requiredForAlert = false,
    },
    bone_wraith = {
        label = "Bone Wraith",
        namePatterns = { "Bone Wraith", "Knight of Decay" },
        -- CA node is "Animate: Knight of Decay"; spell tip often shows Bone Wraith.
        talentPatterns = { "Animate: Bone Wraith", "Animate: Knight of Decay" },
        spellNames = { "Animate: Bone Wraith", "Animate: Knight of Decay" },
        alertSpellId = 805032,
        -- 707175 is Bone King (Command → free Lichfrost/Blight), not Wraith.
        summonSpellIds = { [805032] = true, [712317] = true },
        cooldownSpellIds = { [805032] = true },
        trackMode = "temporary",
        duration = 60,
        cooldown = 60,
        defaultMax = 1,
        requiredForAlert = true,
    },
    tomb_king = {
        label = "Tomb King",
        namePatterns = { "Tomb King" },
        talentPatterns = { "Animate: Tomb King" },
        spellNames = { "Animate: Tomb King" },
        alertSpellId = 805044,
        summonSpellIds = { [805044] = true, [355744] = true },
        -- Strip CD uses 805044 only (355744 is an alternate summon id, not the strip lock).
        cooldownSpellIds = { [805044] = true },
        trackMode = "temporary",
        duration = 15,
        cooldown = 60,
        defaultMax = 1,
        requiredForAlert = false,
    },
    skeletal_archer = {
        label = "Skeletal Archer",
        namePatterns = { "Skeletal Archer", "Grave Mage" },
        -- Spell tip: Animate: Skeletal Archer (805040) — 18s duration, 24s CD.
        talentPatterns = { "Animate: Skeletal Archer", "Animate: Putrid Ghoul" },
        spellNames = { "Animate: Skeletal Archer", "Animate: Putrid Ghoul" },
        alertSpellId = 805040,
        summonSpellIds = { [500330] = true, [500332] = true, [500331] = true, [805040] = true },
        -- Strip CD uses 805040 only — 500330 sibling was leaking CD onto other Animates.
        cooldownSpellIds = { [805040] = true },
        trackMode = "temporary",
        duration = 18,
        cooldown = 24,
        defaultMax = 1,
        requiredForAlert = true,
    },
    plaguefather = {
        label = "Plaguefather",
        namePatterns = { "Plaguefather" },
        talentPatterns = { "Animate: Plaguefather" },
        spellNames = { "Animate: Plaguefather" },
        alertSpellId = 805048,
        summonSpellIds = { [805048] = true },
        cooldownSpellIds = { [805048] = true },
        trackMode = "temporary",
        duration = 60,
        cooldown = 60,
        defaultMax = 1,
        requiredForAlert = false,
    },
    frost_wyrm = {
        label = "Frost Wyrm",
        namePatterns = { "Frost Wyrm" },
        -- Class tree CA node is "Shatterfrost"; spell tip is Animate: Frost Wyrm (805428).
        talentPatterns = { "Animate: Frost Wyrm", "Shatterfrost" },
        spellNames = { "Animate: Frost Wyrm", "Shatterfrost" },
        alertSpellId = 805428,
        summonSpellIds = { [805428] = true },
        cooldownSpellIds = { [805428] = true },
        trackMode = "temporary",
        talentTree = "class",
        duration = 60,
        cooldown = 60,
        defaultMax = 1,
        requiredForAlert = false,
    },
    crypt_fiend = {
        label = "Crypt Fiend",
        namePatterns = { "Crypt Fiend", "Crypt Keeper" },
        talentPatterns = { "Raise: Crypt Fiend" },
        summonSpellIds = { [504859] = true },
        buffSpellIds = { [712309] = true, [800034] = true },
        trackMode = "buff",
        lifeForceCost = 2,
        requiredLevel = 8,
        learnedFrom = "training",
        defaultMax = 1,
        requiredForAlert = false,
    },
    banshee = {
        label = "Banshee",
        namePatterns = { "Banshee" },
        talentPatterns = { "Raise: Banshee" },
        spellNames = { "Raise: Banshee" },
        -- Creature 500650 from Raise: Banshee (504861) summon effect.
        summonSpellIds = { [504861] = true },
        trackMode = "buff",
        trackUnits = true,
        lifeForceCost = 2,
        defaultMax = 1,
        requiredForAlert = false,
    },
    skeletal_warrior_lesser = {
        label = "Lesser Skeletal Warrior",
        namePatterns = { "Lesser Skeletal Warrior", "Brittle Skeleton", "Skeletal Warrior" },
        talentPatterns = {
            "Raise: Lesser Skeletal Warrior", "Raise: Lesser Skeletal warrior",
            "Raise: Brittle Skeleton",
        },
        summonSpellIds = { [500970] = true },
        buffSpellIds = { [805016] = true },
        trackMode = "buff",
        defaultMax = 1,
        requiredForAlert = false,
    },
    skeletal_warrior_greater = {
        label = "Greater Skeletal Warrior",
        namePatterns = { "Greater Skeletal Warrior" },
        talentPatterns = {
            "Raise: Greater Skeletal Warrior", "Raise: Greater Skeletal warrior",
        },
        summonSpellIds = { [504901] = true },
        buffSpellIds = { [807927] = true },
        trackMode = "buff",
        defaultMax = 1,
        requiredForAlert = false,
    },
    skeletal_rogue = {
        label = "Skeletal Rogue",
        namePatterns = { "Skeletal Rogue" },
        talentPatterns = { "Raise: Skeletal Rogue", "Raise: Crypt Leaper" },
        summonSpellIds = { [500969] = true },
        buffSpellIds = { [805021] = true },
        trackMode = "buff",
        defaultMax = 1,
        requiredForAlert = false,
    },
    abomination = {
        label = "Abomination",
        namePatterns = { "Abomination", "Flesh Giant", "Unholy Colossus", "Flesh Golem", "Decaying Colossus" },
        talentPatterns = {
            "Raise: Abomination", "Army of the Dead", "Raise: Unholy Colossus", "Raise: Flesh Golem",
            "Raise: Decaying Colossus",
        },
        spellNames = {
            "Raise: Abomination", "Raise: Unholy Colossus", "Raise: Flesh Golem", "Raise: Decaying Colossus",
        },
        summonSpellIds = { [42650] = true, [500989] = true, [500335] = true, [803139] = true },
        buffSpellIds = { [680760] = true, [685010] = true, [805017] = true },
        trackMode = "buff",
        lifeForceCost = 3,
        defaultMax = 1,
        requiredForAlert = false,
    },
    lesser_zombie = {
        label = "Lesser Zombie",
        namePatterns = { "Lesser Zombie", "Zombie" },
        talentPatterns = { "Unrelenting Army" },
        trackMode = "temporary",
        duration = 15,
        trackUnits = true,
        lifeForceCost = 0,
        defaultMax = 3,
        requiredForAlert = false,
    },
}

-- Most-specific minion names first so broad patterns (e.g. Ghoul) do not steal matches.
Advisor.MINION_CLASSIFY_ORDER = {
    "skeletal_warrior_greater",
    "skeletal_warrior_lesser",
    "skeletal_rogue",
    "crypt_fiend",
    "banshee",
    "skeletal_archer",
    "bone_wraith",
    "tomb_king",
    "plaguefather",
    "frost_wyrm",
    "abomination",
    "lesser_zombie",
    "ghoul",
}

-- Minion-owned combat abilities only (not player spellbook damage).
Advisor.MINION_DAMAGE_SPELLS = {
    ["Putrid Claws"] = "ghoul",
    ["Command: Ghouls"] = "ghoul",
    ["Frozen Barbs"] = "crypt_fiend",
    ["Command: Banshee"] = "banshee",
    ["Disease Cloud"] = "abomination",
}

-- Player spellbook abilities — never count toward minion DPS.
Advisor.PLAYER_DAMAGE_SPELLS = {
    ["Animate: Skeletal Archer"] = true,
    ["Animate: Putrid Ghoul"] = true,
    ["Animate: Tomb King"] = true,
    ["Animate: Bone Wraith"] = true,
    ["Animate: Knight of Decay"] = true,
    ["Animate: Plaguefather"] = true,
    ["Animate: Frost Wyrm"] = true,
    ["Shatterfrost"] = true,
    ["Bone Tithe"] = true,
    ["Bone Ward"] = true,
    ["Call of The Scourge"] = true,
    ["Call of the Scourge"] = true,
    ["Command: Undead"] = true,
    ["Create Bone Reliquary"] = true,
    ["Deadly Bond"] = true,
    ["Grave March"] = true,
    ["Necromancy"] = true,
    ["Raise: Abomination"] = true,
    ["Raise: Crypt Fiend"] = true,
    ["Raise: Banshee"] = true,
    ["Raise: Ghoul"] = true,
    ["Raise: Greater Skeletal Warrior"] = true,
    ["Raise: Lesser Skeletal Warrior"] = true,
    ["Raise: Skeletal Rogue"] = true,
    ["Scourge Apprentice Training"] = true,
    ["Summoning Adept"] = true,
    ["Summoning Expert"] = true,
    ["Undead: Assault"] = true,
    ["Undead: Pacify"] = true,
    ["Undead: Protect"] = true,
    ["Unholy Frenzy"] = true,
    ["Blight"] = true,
    ["Call of the Grave"] = true,
    ["Corpse Explosion"] = true,
    ["Crypt Swarm"] = true,
    ["Entomb"] = true,
    ["Expunge Blight"] = true,
    ["Fetid Ward"] = true,
    ["Foul Mandate"] = true,
    ["Ghoulify"] = true,
    ["Harvest Plague"] = true,
    ["Sacrifice Undead"] = true,
    ["Sense Undead"] = true,
    ["Chill of the Tomb"] = true,
    ["Create Frozen Reliquary"] = true,
    ["Glacial Tap"] = true,
    ["Glacial Ward"] = true,
    ["Lichfrost"] = true,
    ["Razorice"] = true,
    ["Siphon Mana"] = true,
    ["Transfer Life"] = true,
}

-- Passive talents / buffs that mention minions but are not summon spells.
Advisor.MINION_TOOLTIP_EXCLUDE_SPELLS = {
    ["Army of the Dead"] = true,
    ["Ghoulkeeper"] = true,
    ["Ghoulify"] = true,
    ["Ghoul Commander"] = true,
    ["Ghoul Mastery"] = true,
}

Advisor.TEMP_ICON_ALERT_MINIONS = {
    bone_wraith = true,
    skeletal_archer = true,
}

-- Temporary Animate CDs shown on the ready strip when talented + off cooldown.
Advisor.ANIMATE_READY_MINIONS = {
    bone_wraith = true,
    skeletal_archer = true,
    tomb_king = true,
    plaguefather = true,
    frost_wyrm = true,
}

Advisor.ANIMATE_READY_ORDER = {
    "bone_wraith",
    "skeletal_archer",
    "tomb_king",
    "plaguefather",
    "frost_wyrm",
}

-- One castable spell ID per Animate for A-strip CD/icon. Never resolve CD by name —
-- Ascension aliases (Putrid Ghoul / Knight of Decay / Shatterfrost) and sibling IDs
-- were bleeding one Animate's cooldown onto another.
Advisor.ANIMATE_STRIP_SPELL_ID = {
    bone_wraith = 805032,
    skeletal_archer = 805040,
    tomb_king = 805044,
    plaguefather = 805048,
    frost_wyrm = 805428,
}

Advisor.IGNORED_AURA_NAMES = {
    ["life force"] = true,
    ["used life force"] = true,
    ["stolen life force visual"] = true,
}

Advisor.IGNORED_AURA_SPELL_IDS = {
    [524901] = true,
    [525004] = true,
    [805011] = true,
    [807844] = true,
}

-- Known Life Force pool auras.
-- Free pool is the HARMFUL debuff "Life Force" (525004); stacks = free LF.
-- Debuff hides when the pool is fully spent on minions.
Advisor.LIFE_FORCE_AURA_SPELL_IDS = {
    [524901] = true,
    [525004] = true, -- primary: Life Force debuff (stacks = free)
    [805011] = true,
    [807844] = true,
}

Advisor.LIFE_FORCE_FREE_DEBUFF_ID = 525004

-- Talent bonuses on top of the base Life Force pool (Ascension Animation).
-- Base ~4 from the Life Force aura spell dummy; Adept/Expert/Animator +1; Mastery +2.
Advisor.LIFE_FORCE_BASE = 4
Advisor.LIFE_FORCE_TALENTS = {
    { name = "Summoning Adept", spellIds = { 92123 }, bonus = 1 },
    { name = "Summoning Expert", spellIds = { 807494 }, bonus = 1 },
    { name = "Master Animator", spellIds = { 504431 }, bonus = 1 },
    { name = "Summoning Mastery", spellIds = { 805042, 707015 }, bonus = 2 },
}

Advisor.LIFE_FORCE_COST = {
    ghoul = 1,
    crypt_fiend = 2,
    banshee = 2,
    skeletal_warrior_lesser = 1,
    skeletal_warrior_greater = 1,
    skeletal_rogue = 1,
    abomination = 3,
}

Advisor.UNDEAD_STANCES = {
    assault = {
        label = "Undead: Assault",
        spellIds = { [500982] = true },
    },
    pacify = {
        label = "Undead: Pacify",
        spellIds = { [500983] = true, [504692] = true, [504729] = true },
    },
    protect = {
        label = "Undead: Protect",
        spellIds = { [500985] = true, [504902] = true },
    },
}

-- Flat lookup for buff scans (Ascension UnitAura packing is unreliable).
Advisor.UNDEAD_STANCE_SPELL_LOOKUP = {
    [500982] = "assault",
    [500983] = "pacify",
    [500985] = "protect",
    [504692] = "pacify",
    [504729] = "pacify",
    [504902] = "protect",
}

Advisor.TALENT_DEFS = {
    armyOfTheDead = {
        label = "Army of the Dead",
        spellId = nil,
        namePattern = "Army of the Dead",
    },
}

local SCAN_UNITS = {
    "pet",
    "target",
    "focus",
    "mouseover",
}

local ADVISOR_POLL_INTERVAL = 2.0
local ALERT_REFRESH_INTERVAL = 0.35
local SPELL_CD_SYNC_INTERVAL = 0.25
local UNIT_SCAN_INTERVAL = 3.0
local AURA_SCAN_CACHE_TTL = 2.0
local ICON_PULSE_INTERVAL = 0.05
-- Nameplate GUID seed + army snapshot (not every frame — live enough without spam).
local GUARDIAN_SEED_INTERVAL = 5.0
local MINION_SNAPSHOT_TTL = 5.0

for i = 1, 4 do
    SCAN_UNITS[#SCAN_UNITS + 1] = "party" .. i
    SCAN_UNITS[#SCAN_UNITS + 1] = "partypet" .. i
end

-- Nameplates are resolved dynamically via C_NamePlate + trackedUnits; avoid 40x UnitExists every scan.

local OBJECT_TYPE_PET = 0x00001000
local OBJECT_TYPE_GUARDIAN = 0x00002000

-- CLEU uses Creature-0-...-0xF130...; UnitGUID often returns 0xF130... — compare by hex tail.
local function NormalizeGuidKey(guid)
    if not guid then
        return nil
    end
    local s = tostring(guid):lower()
    local hex = s:match("0x(%x+)$")
    if hex then
        return hex
    end
    hex = s:match("^0x(%x+)$")
    if hex then
        return hex
    end
    return s
end

local function GuidsMatch(a, b)
    if not a or not b then
        return false
    end
    if a == b then
        return true
    end
    local ka = NormalizeGuidKey(a)
    local kb = NormalizeGuidKey(b)
    return ka and kb and ka == kb
end

local function GetCombatLogPayload(...)
    if Mancer.CombatLog and Mancer.CombatLog.GetPayload then
        return Mancer.CombatLog.GetPayload(...)
    end
    if select("#", ...) > 0 then
        return { ... }
    end
    if CombatLogGetCurrentEventInfo then
        return { CombatLogGetCurrentEventInfo(...) }
    end
    return { ... }
end

local function SafeGetNamePlates()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then
        return nil
    end

    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or not plates then
        return nil
    end

    return plates
end

local function IsPetOrGuardianFlags(flags)
    if not flags or not bit or not bit.band then
        return false
    end
    return bit.band(flags, OBJECT_TYPE_PET + OBJECT_TYPE_GUARDIAN) ~= 0
end

function Advisor:ResolveMinionId(name, spellId, spellName, destFlags)
    local minionId = self:ClassifyMinionName(name)
        or self:ClassifyBySpellId(spellId)
        or self:ClassifyMinionName(spellName)

    if minionId then
        return minionId
    end

    if IsPetOrGuardianFlags(destFlags) then
        local fromName = self:ClassifyMinionName(name)
        if fromName then
            return fromName
        end
    end

    return nil
end

function Advisor:HasUnrelentingArmy()
    return self:HasMinionTalent("lesser_zombie")
end

function Advisor:IsLesserZombieSummon(destName, spellId, spellName)
    if not self:HasUnrelentingArmy() then
        return false
    end

    if self:ClassifyMinionName(destName) == "lesser_zombie" then
        return true
    end

    if destName and destName:find("Lesser Zombie", 1, true) then
        return true
    end

    if destName and destName:find("^Zombie$") then
        return true
    end

    if spellName then
        local normalized = self:NormalizeSpellName(spellName)
        if normalized == "Harvest Plague" or normalized == "Zombie Plague" then
            return true
        end
    end

    return false
end

function Advisor:RecordSummon(destGuid, destName, minionId, spellId, source)
    if not destGuid or not minionId then
        return
    end

    local def = self.MINION_TYPES[minionId]
    local now = GetTime and GetTime() or 0

    self.activeSummons = self.activeSummons or {}
    local existing = self.activeSummons[destGuid]
    if not existing then
        for key, info in pairs(self.activeSummons) do
            if GuidsMatch(key, destGuid) then
                existing = info
                destGuid = key
                break
            end
        end
    end

    -- Re-seed from nameplates should not thrash caches every poll.
    if existing and existing.minionId == minionId then
        existing.name = destName or existing.name
        existing.unit = existing.unit
        if source and source ~= "combatlog" then
            existing.source = existing.source or source
        end
        self:TryLinkSummonUnit(destGuid)
        return
    end

    self.activeSummons[destGuid] = {
        name = destName,
        minionId = minionId,
        spellId = spellId,
        source = source or "combatlog",
        time = now,
        guid = destGuid,
    }

    if Mancer.MinionDpsModule then
        Mancer.MinionDpsModule:RegisterSummonGuid(destGuid, minionId)
    end

    self:TryLinkSummonUnit(destGuid)

    self.cachedScanUnits = nil
    self.cachedScanUnitsUntil = 0
    self:ClearPollCaches()
    self.dirtyAlert = true

    if def and def.trackMode == "temporary" and def.duration then
        local duration = self.GetTemporaryDuration and self:GetTemporaryDuration(minionId) or def.duration
        self.activeSummons[destGuid].expiresAt = now + duration
        -- Only real casts refresh the Animate "active" window. Visible/nameplate seeds
        -- (other players' Animates, leftover GUIDs) used to keep the A-strip permanently grey.
        if source == "combatlog" or source == "cast" or source == "spell" then
            self.temporaryActive = self.temporaryActive or {}
            self.temporaryActive[minionId] = now + duration
        end
    end
end

function Advisor:MarkTemporaryCast(minionId)
    local def = self.MINION_TYPES[minionId]
    if not def or def.trackMode ~= "temporary" then
        return
    end

    local now = GetTime and GetTime() or 0
    self.lastCastTime = self.lastCastTime or {}
    self.lastCastTime[minionId] = now

    local duration = self.GetTemporaryDuration and self:GetTemporaryDuration(minionId) or def.duration
    if duration and duration > 0 then
        self.temporaryActive = self.temporaryActive or {}
        self.temporaryActive[minionId] = now + duration
    end

    -- Drop cached CD for this Animate so the strip rematches the cast spell id immediately.
    if self.spellCdCache then
        self.spellCdCache["anim:" .. tostring(minionId)] = nil
        self.spellCdCache[minionId] = nil
    end

    self:ClearPollCaches()
    self.dirtyAlert = true
end

function Advisor:GetTrackMode(minionId)
    local def = self.MINION_TYPES[minionId]
    return def and def.trackMode or "buff"
end

function Advisor:UsesBuffTracking(minionId)
    return self:GetTrackMode(minionId) == "buff"
end

function Advisor:UsesTemporaryTracking(minionId)
    return self:GetTrackMode(minionId) == "temporary"
end

-- True only for Animate/Raise casts that spawn the pet — never Command: Undead / Command: Archers / etc.
function Advisor:IsTemporarySummonCast(spellId, spellName)
    spellId = tonumber(spellId)
    if spellName then
        local normalized = self.NormalizeSpellName and self:NormalizeSpellName(spellName) or spellName
        if type(normalized) == "string" then
            if normalized:find("^Command:", 1, true)
                or normalized:find("^Undead:", 1, true)
                or normalized:find("^Sacrifice ", 1, true) then
                return false, nil
            end
        end
    end

    if spellId and spellId > 0 then
        for minionId, def in pairs(self.MINION_TYPES) do
            if def and def.trackMode == "temporary" then
                if (def.cooldownSpellIds and def.cooldownSpellIds[spellId])
                    or (def.summonSpellIds and def.summonSpellIds[spellId]) then
                    return true, minionId
                end
            end
        end
    end

    if spellName and (spellName:find("^Animate:", 1, true) or spellName:find("^Raise:", 1, true)) then
        local minionId = self:ClassifyMinionSummonSpell(spellName, spellId)
        if minionId and self:UsesTemporaryTracking(minionId) then
            return true, minionId
        end
    end

    return false, nil
end

function Advisor:UsesUnitTracking(minionId)
    local def = self.MINION_TYPES[minionId]
    return def and def.trackUnits == true
end

local function SafeGetSpellCooldown(...)
    if not GetSpellCooldown then
        return nil
    end

    local ok, start, duration, enabled = pcall(GetSpellCooldown, ...)
    if not ok then
        return nil
    end

    start = start or 0
    duration = duration or 0
    enabled = enabled or 1
    -- WeakAuras: discard absurd durations that freeze the client.
    if duration > 604800 then
        return 0, 0, 1
    end
    -- WoW wraps large negative starts; unwrap like WeakAuras.
    if start > (GetTime and GetTime() or 0) + (2 ^ 31) / 1000 then
        start = start - (2 ^ 32) / 1000
    end
    return start, duration, enabled
end

-- WeakAuras-style: ignore GCD-only returns so Animate CDs are not treated as real CDs.
local function GetPlayerGcd()
    if not GetSpellCooldown then
        return 0, 0
    end
    local ok, start, duration = pcall(GetSpellCooldown, 61304)
    if not ok then
        return 0, 0
    end
    return start or 0, duration or 0
end

local function IsSignificantSpellCooldown(start, duration)
    if not start or not duration or duration <= 0 then
        return false
    end
    if duration > 604800 then
        return false
    end
    local gcdStart, gcdDuration = GetPlayerGcd()
    if gcdDuration > 0
        and math.abs(duration - gcdDuration) < 0.001
        and math.abs(start - gcdStart) < 0.001 then
        return false
    end
    -- Short flickers / GCD-length false positives (WA uses > 1.5).
    if duration <= 1.5 then
        return false
    end
    return true
end

local function RemainingFromCooldown(start, duration, now)
    if not IsSignificantSpellCooldown(start, duration) then
        return nil
    end
    now = now or (GetTime and GetTime() or 0)
    local remaining = start + duration - now
    if remaining <= 0.05 then
        return nil
    end
    return remaining
end

local function CachedCooldownResult(cached, now)
    if not cached then
        return nil
    end
    if cached.start and cached.duration then
        local remaining = RemainingFromCooldown(cached.start, cached.duration, now)
        if remaining and remaining > 0.35 then
            return cached.start, cached.duration, remaining
        end
        return nil
    end
    return nil
end

local function NormalizeTalentMatch(name)
    if not name then
        return ""
    end
    return string.lower((tostring(name):gsub("%s+", " "):match("^%s*(.-)%s*$") or ""))
end

local function ResolveSpellIdFromName(spellName)
    if not spellName or spellName == "" then
        return nil
    end

    -- Wrath GetSpellInfo(name) does NOT return spellId (7th is castTime). Prefer C_Spell.
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellName)
        if info and info.spellID and info.spellID > 0 then
            return info.spellID
        end
    end

    return nil
end

local function QuerySpellCooldownBySpellId(spellId)
    spellId = tonumber(spellId)
    if not spellId or spellId <= 0 then
        return nil
    end

    -- Ascension / modern-ish: GetSpellCooldown(spellId)
    local start, duration, enabled = SafeGetSpellCooldown(spellId)
    if start then
        return start, duration, enabled
    end

    -- Some clients still use (slot, bookType); try by resolved name.
    if GetSpellInfo then
        local name = GetSpellInfo(spellId)
        if name and name ~= "" then
            start, duration, enabled = SafeGetSpellCooldown(name)
            if start then
                return start, duration, enabled
            end
        end
    end

    if FindSpellBookSlotByID then
        local ok, slot, bookType = pcall(FindSpellBookSlotByID, spellId, false)
        if ok and slot and slot > 0 then
            start, duration, enabled = SafeGetSpellCooldown(slot, bookType or "spell")
            if start then
                return start, duration, enabled
            end
        end
    end

    return nil
end

local function QuerySpellCooldown(spellRef)
    if spellRef == nil then
        return nil
    end

    if type(spellRef) == "string" then
        local start, duration, enabled = SafeGetSpellCooldown(spellRef)
        if start then
            return start, duration, enabled
        end

        local spellId = ResolveSpellIdFromName(spellRef)
        if spellId then
            return QuerySpellCooldownBySpellId(spellId)
        end

        return nil
    end

    if type(spellRef) == "number" then
        return QuerySpellCooldownBySpellId(spellRef)
    end

    return nil
end

local function SpellIdNameMatches(spellId, wantName)
    if not spellId or not wantName or not GetSpellInfo then
        return false
    end
    local name = GetSpellInfo(spellId)
    return name and NormalizeTalentMatch(name) == NormalizeTalentMatch(wantName)
end

function Advisor:GetCanonicalAnimateSpellId(minionId)
    if not minionId then
        return nil
    end
    local pinned = self.ANIMATE_STRIP_SPELL_ID and self.ANIMATE_STRIP_SPELL_ID[minionId]
    if pinned then
        return pinned
    end
    local def = self.MINION_TYPES[minionId]
    return def and def.alertSpellId or nil
end

-- Strip CD/icon only — never ResolveSpellIdFromName (aliases cross-wire Animates).
function Advisor:ResolveKnownAnimateSpellId(minionId, binding)
    if binding and binding.spellId then
        local id = tonumber(binding.spellId)
        if id and id > 0 then
            return id
        end
    end
    return self:GetCanonicalAnimateSpellId(minionId)
end

local function ResolveKnownAnimateSpellId(minionId, binding)
    return Advisor:ResolveKnownAnimateSpellId(minionId, binding)
end

function Advisor:GetMinionSpellCooldown(minionId)
    local now = GetTime and GetTime() or 0
    if self.spellCdCache and self.spellCdCache[minionId] and now < self.spellCdCache[minionId].expiresAt then
        return CachedCooldownResult(self.spellCdCache[minionId], now)
    end

    local def = self.MINION_TYPES[minionId]
    if not def then
        return nil
    end

    local bestStart, bestDuration, bestRemaining

    local function consider(spellRef)
        local start, duration = QuerySpellCooldown(spellRef)
        local remaining = RemainingFromCooldown(start, duration, now)
        if not remaining then
            return
        end

        if not bestRemaining or remaining > bestRemaining then
            bestStart = start
            bestDuration = duration
            bestRemaining = remaining
        end
    end

    if def.spellNames then
        for _, spellName in ipairs(def.spellNames) do
            consider(spellName)
        end
    end

    if def.cooldownSpellIds then
        for spellId in pairs(def.cooldownSpellIds) do
            consider(spellId)
        end
    end

    self.spellCdCache = self.spellCdCache or {}
    self.spellCdCache[minionId] = {
        start = bestStart,
        duration = bestDuration,
        expiresAt = now + SPELL_CD_SYNC_INTERVAL,
    }

    if not bestRemaining then
        return nil
    end

    return bestStart, bestDuration, bestRemaining
end

function Advisor:SyncTemporaryMinionFromSpellCooldown(minionId)
    local def = self.MINION_TYPES[minionId]
    if not def or def.trackMode ~= "temporary" or not self:HasMinionTalent(minionId) then
        return false
    end

    local start, duration, remaining
    if self:IsAnimateReadyMinion(minionId) then
        start, duration, remaining = self:GetAnimateSpellCooldown(minionId)
    else
        start, duration, remaining = self:GetMinionSpellCooldown(minionId)
    end

    local now = GetTime()
    local petDuration = self.GetTemporaryDuration and self:GetTemporaryDuration(minionId) or def.duration
    self.temporaryActive = self.temporaryActive or {}
    self.lastCastTime = self.lastCastTime or {}

    -- Keep an existing vanish window. Command: Undead + Forbidden Technique CDR
    -- rewrites GetSpellCooldown start without re-summoning — do not re-anchor teal.
    local existingUntil = self.temporaryActive[minionId]
    if existingUntil and existingUntil > now then
        return true
    end

    -- Seed only when we have no window yet (e.g. cast detected via CD before CLEU).
    local castStart = self.lastCastTime[minionId]
    if (not castStart or castStart <= 0) and start and remaining and remaining > 0 then
        castStart = start
        self.lastCastTime[minionId] = start
    end

    if castStart and petDuration and petDuration > 0 then
        local activeUntil = castStart + petDuration
        if now < activeUntil then
            self.temporaryActive[minionId] = activeUntil
            return true
        end
    end

    self.temporaryActive[minionId] = nil
    return false
end

function Advisor:SyncTemporaryFromSpellCooldowns()
    for minionId, def in pairs(self.MINION_TYPES) do
        if def.trackMode == "temporary" then
            self:SyncTemporaryMinionFromSpellCooldown(minionId)
        end
    end
end

function Advisor:IsMinionOnCooldown(minionId)
    local def = self.MINION_TYPES[minionId]
    if not def then
        return false
    end

    if def.trackMode == "temporary" then
        local start, duration, remaining = self:GetMinionSpellCooldown(minionId)
        if start and remaining and remaining > 0 then
            local now = GetTime()
            local petDuration = self.GetTemporaryDuration and self:GetTemporaryDuration(minionId) or def.duration
            if petDuration and (now - start) < petDuration then
                return false
            end
            return true
        end
    end

    if not def.cooldown or not self.lastCastTime then
        return false
    end

    local lastCast = self.lastCastTime[minionId]
    if not lastCast then
        return false
    end

    return GetTime() < lastCast + def.cooldown
end

function Advisor:AdjustSummonCount(minionId, delta)
    if not minionId or not delta or delta == 0 then
        return
    end

    self.castCounts = self.castCounts or {}
    local maxCount = self:GetMinionScanCap(minionId)
    local current = self.castCounts[minionId] or 0
    self.castCounts[minionId] = math.max(0, math.min(maxCount, current + delta))
end

function Advisor:IsGhoulSummonSpell(spellId, spellName)
    if spellId and self:ClassifyBySpellId(spellId) == "ghoul" then
        return true
    end
    if spellName and self:ClassifyMinionSummonSpell(spellName, spellId) == "ghoul" then
        return true
    end
    return false
end

function Advisor:OnGhoulSummoned()
    self.cachedScanUnits = nil
    self.cachedScanUnitsUntil = 0
    self:ClearPollCaches()
    self.dirtyAlert = true
end

function Advisor:OnGhoulDied()
    self.cachedScanUnits = nil
    self.cachedScanUnitsUntil = 0
    self:ClearPollCaches()
    self.dirtyAlert = true
end

function Advisor:ClearGhoulTracking()
    if self.castCounts then
        self.castCounts.ghoul = 0
    end
    if self.activeSummons then
        for guid, info in pairs(self.activeSummons) do
            if info and info.minionId == "ghoul" then
                self.activeSummons[guid] = nil
            end
        end
    end
end

function Advisor:CountActiveSummonsByMinion(minionId)
    local count = 0
    if not self.activeSummons then
        return 0
    end
    for _, info in pairs(self.activeSummons) do
        if info and info.minionId == minionId then
            local src = info.source
            if self:IsTrustedSummonSource(src) or src == "owned_visible" then
                count = count + 1
            end
        end
    end
    return count
end

-- Live Harvest Plague / Unrelenting Army zombies (nameplate + CLEU GUID set).
function Advisor:GetActiveZombieCount()
    if not self:HasUnrelentingArmy() then
        return 0
    end
    self:SeedSummonsFromVisibleUnits()
    local now = GetTime and GetTime() or 0
    local count = 0
    if not self.activeSummons then
        return 0
    end
    for guid, info in pairs(self.activeSummons) do
        if info and info.minionId == "lesser_zombie" then
            if info.expiresAt and info.expiresAt <= now then
                self.activeSummons[guid] = nil
                if Mancer.MinionDpsModule and Mancer.MinionDpsModule.CloseSummonGuid then
                    Mancer.MinionDpsModule:CloseSummonGuid(guid, "zombie_expired")
                end
            else
                count = count + 1
            end
        end
    end
    return count
end

function Advisor:CountVisibleGhoulUnits()
    return self:CountVisibleMinionUnits("ghoul")
end

function Advisor:MergeGhoulActiveCount(counts)
    local buffCount = counts.ghoul or 0
    local summonCount = self:CountActiveSummonsByMinion("ghoul")
    local visibleCount = self:CountVisibleGhoulUnits()

    if buffCount == 0 and visibleCount == 0 and summonCount == 0 then
        self:ClearGhoulTracking()
        counts.ghoul = nil
        return counts
    end

    -- Teach Life Force peak from total LF spent on raised minions (not ghouls alone).
    if not self.computingLifeForcePeak then
        self:UpdateLifeForcePeak()
    end

    -- Nameplates are ground truth — never clamp below live plate count.
    if visibleCount > 0 then
        counts.ghoul = visibleCount
    else
        local cap = self:GetMinionScanCap("ghoul")
        local merged = buffCount > 0 and buffCount or summonCount
        counts.ghoul = math.min(merged, cap)
    end

    self.castCounts = self.castCounts or {}
    self.castCounts.ghoul = counts.ghoul
    return counts
end

function Advisor:InvalidateCaches()
    self.requiredMinionsDirty = true
    self.cachedKnownMinions = nil
    self.cachedScanUnits = nil
    self.cachedScanUnitsUntil = 0
    self.minionSnapshot = nil
    self.cachedAuraCounts = nil
    self.cachedAuraSeen = nil
    self.cachedAuraUntil = 0
    self.spellCdCache = nil
    self.dirtyAlert = true
    self.lastAlertKey = nil
    self.talentCache = nil
    self.talentCacheUntil = 0
    self.dynamicPatternCache = nil
    self.animateSpellbookCache = nil
    if Ascension.InvalidateTalentCache then
        Ascension.InvalidateTalentCache()
    end
end

-- Force an Animate strip rebuild on the next poll tick (talent learn / CA update).
function Advisor:RequestAnimateStripRefresh()
    self.pendingCacheInvalidate = true
    self.dirtyAlert = true
    self.lastAlertKey = nil
    self.animateSpellbookCache = nil
    self.alertTimer = ALERT_REFRESH_INTERVAL
end

function Advisor:ClearPollCaches()
    self.minionSnapshot = nil
    self.cachedAuraCounts = nil
    self.cachedAuraSeen = nil
    self.cachedAuraUntil = 0
end

function Advisor:GetCachedScanUnits()
    local now = GetTime and GetTime() or 0
    if self.cachedScanUnits and now < (self.cachedScanUnitsUntil or 0) then
        return self.cachedScanUnits
    end

    self.cachedScanUnits = self:GetAllScanUnits()
    self.cachedScanUnitsUntil = now + UNIT_SCAN_INTERVAL
    return self.cachedScanUnits
end

function Advisor:SyncTemporaryFromSpellCooldownsIfNeeded()
    local now = GetTime and GetTime() or 0
    if now < (self.nextSpellCdSync or 0) then
        return
    end

    self.nextSpellCdSync = now + SPELL_CD_SYNC_INTERVAL
    self:SyncTemporaryFromSpellCooldowns()
end

function Advisor:ShouldScanUnits()
    local now = GetTime and GetTime() or 0
    if now >= (self.nextUnitScan or 0) then
        self.nextUnitScan = now + UNIT_SCAN_INTERVAL
        return true
    end
    return false
end

function Advisor:GetLightweightTempScanUnits()
    local units = { "pet", "target", "focus", "mouseover" }
    local seen = {}

    local function addUnit(unit)
        if unit and not seen[unit] then
            seen[unit] = true
            units[#units + 1] = unit
        end
    end

    for i = 1, 4 do
        addUnit("party" .. i)
        addUnit("partypet" .. i)
    end

    if self.trackedUnits then
        for unit in pairs(self.trackedUnits) do
            addUnit(unit)
        end
    end

    local plates = SafeGetNamePlates()
    if plates then
        for _, plate in ipairs(plates) do
            addUnit(plate.namePlateUnitToken or plate.unitToken or plate.unit)
        end
end

for i = 1, 40 do
        addUnit("nameplate" .. i)
    end

    return units
end

function Advisor:GetAllScanUnits()
    local units = {}
    local seen = {}

    local function addUnit(unit, allowMissingExists)
        if not unit or seen[unit] then
            return
        end
        -- Ascension friendly guardian plates: UnitName/UnitGUID often work while UnitExists is false.
        if not allowMissingExists and UnitExists and not UnitExists(unit) then
            return
        end
        if allowMissingExists then
            local name = UnitName and UnitName(unit)
            if not name or name == "" then
                return
            end
        end
        seen[unit] = true
        units[#units + 1] = unit
    end

    for _, unit in ipairs(SCAN_UNITS) do
        addUnit(unit, false)
    end

    if self.trackedUnits then
        for unit in pairs(self.trackedUnits) do
            addUnit(unit, false)
        end
    end

    local plates = SafeGetNamePlates()
    if plates then
        for _, plate in ipairs(plates) do
            addUnit(plate.namePlateUnitToken or plate.unitToken or plate.unit, true)
        end
    end

    for i = 1, 40 do
        addUnit("nameplate" .. i, true)
    end

    return units
end

local function IsTrustedSummonSource(source)
    return source == "summon" or source == "combatlog" or source == "cast" or source == "spell"
end

function Advisor:IsTrustedSummonSource(source)
    return IsTrustedSummonSource(source)
end

-- Seed activeSummons from visible guardian units (CLEU SPELL_SUMMON is often silent on Ascension).
-- Friendly nameplates must be on (nameplateShowFriends + nameplateShowFriendlyGuardians).
-- On Ascension, nameplate tokens often fail UnitExists / UnitPlayerControlled while UnitName+GUID still work.
-- Ascension UnitGUID dumps: 0xF13000C39C… = Skeletal Archer, 0xF13000C490… = Tomb King,
-- 0xF13000C399… = Ghoul (50073).
Advisor.GUID_CREATURE_SIGS = {
    ["00c39c"] = "skeletal_archer",
    ["00c490"] = "tomb_king",
    ["00c399"] = "ghoul",
    ["07a3aa"] = "banshee", -- creature 500650
    ["07acf7"] = "lesser_zombie", -- Harvest Plague / Unrelenting Army (dump: 0xF13007ACF7…)
}

function Advisor:ClassifyByGuid(guid)
    if not guid then
        return nil
    end
    local sig = tostring(guid):lower():match("^0x[f]?130(%x%x%x%x%x%x)")
    if not sig then
        return nil
    end
    return self.GUID_CREATURE_SIGS[sig]
end

function Advisor:TryClassifyVisibleMinionUnit(unit)
    if not unit or (UnitIsUnit and UnitIsUnit(unit, "player")) then
        return nil
    end

    local name = UnitName and UnitName(unit)
    if not name or name == "" then
        return nil
    end

    local guid = UnitGUID and UnitGUID(unit)
    local minionId = self:ClassifyByGuid(guid) or self:ClassifyMinionName(name)
    if not minionId then
        return nil
    end
    if minionId == "lesser_zombie" and not self:HasUnrelentingArmy() then
        return nil
    end

    if UnitIsPlayer and UnitIsPlayer(unit) then
        return nil
    end

    if UnitIsEnemy and UnitIsEnemy("player", unit) then
        return nil
    end

    -- Must be THIS player's undead — other necros' guardians are also friendly + player-controlled.
    if not self:IsOwnedByPlayer(unit, name) then
        return nil
    end

    return minionId, name
end

function Advisor:SeedSummonsFromVisibleUnits(force)
    local now = GetTime and GetTime() or 0
    if not force and now < (self.nextGuardianSeed or 0) then
        return false
    end
    self.nextGuardianSeed = now + GUARDIAN_SEED_INTERVAL

    -- Wipe untrusted nameplate/visible seeds every pass so other necros' GUIDs cannot stick.
    -- CLEU/cast summons (source=summon/combatlog/cast/spell) are kept.
    if self.activeSummons then
        for guid, info in pairs(self.activeSummons) do
            if info and not self:IsTrustedSummonSource(info.source) then
                -- Drop visible/nameplate/unit/owned_visible — re-validated below only if still owned.
                self.activeSummons[guid] = nil
                self:ClearGuidUnitCache(guid)
                if Mancer.MinionDpsModule and Mancer.MinionDpsModule.UnregisterSummonGuid then
                    Mancer.MinionDpsModule:UnregisterSummonGuid(guid)
                end
            end
        end
    end

    local seenKeys = {}

    local function consider(unit, source)
        local minionId, name = self:TryClassifyVisibleMinionUnit(unit)
        if not minionId then
            return
        end
        local guid = UnitGUID and UnitGUID(unit)
        if not guid then
            return
        end
        local key = NormalizeGuidKey(guid) or tostring(guid):lower()
        seenKeys[key] = true
        self:RecordSummon(guid, name, minionId, nil, "owned_visible")
        self:CacheGuidUnit(guid, unit)
    end

    for _, unit in ipairs({ "target", "mouseover", "focus", "pet" }) do
        consider(unit, "owned_visible")
    end

    local anyNameplate = false
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitName and UnitName(unit) then
            anyNameplate = true
        end
        consider(unit, "owned_visible")
    end

    -- Only prune when we can see plates (or a targeted minion), so looking away doesn't wipe.
    local canPrune = anyNameplate
    for _, unit in ipairs({ "target", "mouseover", "focus" }) do
        if self:TryClassifyVisibleMinionUnit(unit) then
            canPrune = true
            break
        end
    end

    -- Drop unowned / stale GUID seeds. CLEU summons (source=summon) keep without plates;
    -- nameplate/visible seeds of other necros must not stick in the sheet roster.
    if canPrune and self.activeSummons then
        for guid, info in pairs(self.activeSummons) do
            if info then
                local key = NormalizeGuidKey(guid) or tostring(guid):lower()
                local missing = not seenKeys[key]
                local untrustedSeed = info.source == "visible"
                    or info.source == "nameplate"
                    or info.source == "unit"
                if missing and (self:UsesBuffTracking(info.minionId) or untrustedSeed) then
                    self.activeSummons[guid] = nil
                    self:ClearGuidUnitCache(guid)
                    if Mancer.MinionDpsModule and Mancer.MinionDpsModule.UnregisterSummonGuid then
                        Mancer.MinionDpsModule:UnregisterSummonGuid(guid)
                    end
                end
            end
        end
    end
    return true
end

function Advisor:CountVisibleMinionUnits(minionId)
    local count = 0
    local seen = {}

    local function consider(unit)
        local id, name = self:TryClassifyVisibleMinionUnit(unit)
        if not id or (minionId and id ~= minionId) then
            return
        end
        local guid = UnitGUID and UnitGUID(unit)
        if guid then
            if seen[guid] then
                return
            end
            seen[guid] = true
        end
        count = count + 1
    end

    for i = 1, 40 do
        consider("nameplate" .. i)
    end
    for _, unit in ipairs({ "target", "mouseover", "focus", "pet" }) do
        consider(unit)
    end

    return count
end

local function NormalizeAuraCount(value)
    local count = tonumber(value)
    if count and count > 0 then
        return count
    end
    return 1
end

local function GetPlayerBuffData(index)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId

    if UnitAura then
        name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId =
            UnitAura("player", index, "HELPFUL")
    else
        name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId =
            UnitBuff("player", index)
    end

    if not name then
        return nil
    end

    count = NormalizeAuraCount(count)
    spellId = tonumber(spellId)

    return name, count, spellId, index, unitCaster
end

local function GetPlayerDebuffData(index)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId

    if UnitAura then
        name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId =
            UnitAura("player", index, "HARMFUL")
    elseif UnitDebuff then
        name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId =
            UnitDebuff("player", index)
    else
        return nil
    end

    if not name then
        return nil
    end

    count = NormalizeAuraCount(count)
    spellId = tonumber(spellId)

    return name, count, spellId, index, unitCaster
end

function Advisor:IsLifeForceAura(name, spellId)
    if spellId and (self.LIFE_FORCE_AURA_SPELL_IDS[spellId] or self.IGNORED_AURA_SPELL_IDS[spellId]) then
        return true
    end

    if name then
        local lower = string.lower(name)
        if lower:find("life force", 1, true)
            and not lower:find("used life force", 1, true)
            and not lower:find("stolen life force", 1, true) then
            return true
        end
    end

    return false
end

-- Read free/max from the official CoA Life Force orb when present.
function Advisor:TryReadCoALifeForce()
    local orb = rawget(_G, "CoAResourceOrb")
    if not orb then
        return nil, nil
    end

    local free = tonumber(orb.value or orb.currentValue or orb.resourceValue)
    local maxValue = tonumber(orb.maxValue or orb.resourceMax)
    if free and maxValue and maxValue > 0 then
        return free, maxValue
    end

    if orb.Text and orb.Text.GetText then
        local text = orb.Text:GetText()
        if text and text ~= "" then
            local a, b = string.match(text, "(%d+)%s*/%s*(%d+)")
            if a and b then
                return tonumber(a), tonumber(b)
            end
            local only = tonumber(string.match(text, "(%d+)"))
            if only then
                return only, nil
            end
        end
    end

    return nil, nil
end

function Advisor:HasLifeForceTalent(entry)
    if not entry then
        return false
    end
    if entry.spellIds then
        for _, spellId in ipairs(entry.spellIds) do
            if Ascension.HasActiveTalentSpell and Ascension.HasActiveTalentSpell(spellId) then
                return true
            end
            if Ascension.HasTalentSpell and Ascension.HasTalentSpell(spellId) then
                return true
            end
            if Ascension.GetTalentRankBySpell and Ascension.GetTalentRankBySpell(spellId) > 0 then
                return true
            end
        end
    end
    if entry.name and Ascension.HasTalentByName then
        return select(1, Ascension.HasTalentByName(entry.name)) and true or false
    end
    return false
end

-- Talent-derived pool size (floor). Live peak / CoA orb can raise this further.
function Advisor:GetTalentLifeForceMax()
    local total = tonumber(self.LIFE_FORCE_BASE) or 4
    for _, entry in ipairs(self.LIFE_FORCE_TALENTS or {}) do
        if self:HasLifeForceTalent(entry) then
            total = total + (tonumber(entry.bonus) or 0)
        end
    end
    return total
end

function Advisor:ScanLifeForceDebuff()
    local bestStacks, bestSpellId, bestName
    local freeId = self.LIFE_FORCE_FREE_DEBUFF_ID or 525004

    local function consider(name, count, spellId)
        if not self:IsLifeForceAura(name, spellId) then
            return
        end

        -- Do NOT coerce 0 → 1 here. Ascension often reports 0 for non-stack displays;
        -- treating that as 1 permanently under-teaches the Life Force peak.
        local stacks = tonumber(count)
        if not stacks or stacks < 1 then
            return
        end

        -- Prefer the confirmed free-pool debuff (525004) over alternate LF auras.
        local isPrimary = spellId == freeId
        local bestIsPrimary = bestSpellId == freeId
        if not bestStacks
            or (isPrimary and not bestIsPrimary)
            or (isPrimary == bestIsPrimary and stacks > bestStacks) then
            bestStacks = stacks
            bestSpellId = spellId
            bestName = name
        end
    end

    -- Direct name / id query first (debuff is HARMFUL).
    local function tryDirect()
        local name, _, _, count, _, _, _, _, _, _, spellId
        if UnitDebuff then
            name, _, _, count, _, _, _, _, _, _, spellId = UnitDebuff("player", "Life Force")
        end
        if (not name) and UnitAura then
            name, _, _, count, _, _, _, _, _, _, spellId = UnitAura("player", "Life Force", "HARMFUL")
        end
        if name then
            consider(name, count, tonumber(spellId) or freeId)
        end
    end
    tryDirect()

    local function scan(getter)
        for i = 1, 40 do
            local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId
            if getter == "HARMFUL" then
                if UnitAura then
                    name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId =
                        UnitAura("player", i, "HARMFUL")
                elseif UnitDebuff then
                    name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId =
                        UnitDebuff("player", i)
                end
            else
                if UnitAura then
                    name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId =
                        UnitAura("player", i, "HELPFUL")
                else
                    name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId =
                        UnitBuff("player", i)
                end
            end
            -- Don't break on nil gaps — Ascension can leave holes when LF reshuffles.
            if name then
                consider(name, count, tonumber(spellId))
            end
        end
    end

    -- Free Life Force is a debuff; scan harmful first.
    scan("HARMFUL")
    if not bestStacks then
        scan("HELPFUL")
    end

    return bestStacks, bestSpellId, bestName
end

function Advisor:GetMinionLifeForceCost(minionId)
    if self.LIFE_FORCE_COST[minionId] then
        return self.LIFE_FORCE_COST[minionId]
    end

    local def = self.MINION_TYPES[minionId]
    if def and def.lifeForceCost then
        return def.lifeForceCost
    end
    if def and def.trackMode == "buff" then
        return 1
    end
    return 0
end

function Advisor:IsMultiSlotMinionBuff(minionId)
    return minionId and self:UsesBuffTracking(minionId) and self:GetMinionLifeForceCost(minionId) == 1
end

function Advisor:ScanLifeForceUsageFromBuffs(excludeMinionId)
    local used = 0
    local buffKeys = {}

    for i = 1, 40 do
        local name, count, spellId = GetPlayerBuffData(i)
        if not name then
            break
        end

        local minionId = self:ClassifyMinionBuff(name, spellId)
        if minionId and minionId ~= excludeMinionId and self:UsesBuffTracking(minionId) then
            local cost = self:GetMinionLifeForceCost(minionId)
            if cost > 0 then
                if cost == 1 then
                    -- One buff icon per minion (ghouls, rogues, etc.), often sharing a spell ID.
                    used = used + math.max(1, count or 1)
                else
                    local key = spellId and ("id:" .. tostring(spellId)) or ("name:" .. string.lower(name))
                    buffKeys[minionId] = buffKeys[minionId] or {}
                    if not buffKeys[minionId][key] then
                        buffKeys[minionId][key] = true
                        used = used + cost
                    end
                end
            end
        end
    end

    return used
end

function Advisor:GetActiveLifeForceUsed(excludeMinionId)
    return self:ScanLifeForceUsageFromBuffs(excludeMinionId)
end

function Advisor:UpdateLifeForcePeak()
    if self.computingLifeForcePeak then
        return self.lifeForcePeak, 0, nil, nil
    end

    self.computingLifeForcePeak = true
    local coaFree, coaMax = self:TryReadCoALifeForce()
    local stacks, spellId, name = self:ScanLifeForceDebuff()
    local used = self:ScanLifeForceUsageFromBuffs()
    self.computingLifeForcePeak = false

    if coaMax and coaMax > 0 then
        self.lifeForcePeak = math.max(self.lifeForcePeak or 0, coaMax)
        if coaFree ~= nil then
            stacks = coaFree
        end
    elseif stacks and stacks > 0 then
        -- Free stacks + committed usage = total pool.
        local pool = used > 0 and (stacks + used) or stacks
        self.lifeForcePeak = math.max(self.lifeForcePeak or 0, pool)
    elseif used > 0 then
        -- Life Force debuff hidden when pool is fully committed; usage is the pool size.
        self.lifeForcePeak = math.max(self.lifeForcePeak or 0, used)
    end

    local talentMax = self:GetTalentLifeForceMax()
    if talentMax and talentMax > 0 then
        self.lifeForcePeak = math.max(self.lifeForcePeak or 0, talentMax)
    end

    return stacks, used, spellId, name
end

function Advisor:IsAutoLifeForceEnabled()
    local limits = self:GetConfig().minionMax or {}
    return limits.autoLifeForce ~= false
end

function Advisor:GetLifeForceMax()
    local limits = self:GetConfig().minionMax or {}
    local defaultMax = (self.MINION_TYPES.ghoul and self.MINION_TYPES.ghoul.defaultMax) or 4

    if not self:IsAutoLifeForceEnabled() then
        return limits.ghoul or limits.lifeForceMax or defaultMax
    end

    if self.computingLifeForcePeak then
        return math.max(
            self.lifeForcePeak or 0,
            self:GetTalentLifeForceMax() or 0,
            limits.ghoul or 0,
            defaultMax
        )
    end

    local _, coaMax = self:TryReadCoALifeForce()
    if coaMax and coaMax > 0 then
        self.lifeForcePeak = math.max(self.lifeForcePeak or 0, coaMax)
        return coaMax
    end

    self:UpdateLifeForcePeak()

    local talentMax = self:GetTalentLifeForceMax() or 0
    local peak = self.lifeForcePeak or 0
    local best = math.max(peak, talentMax, 0)
    if best > 0 then
        return best
    end

    return defaultMax
end

function Advisor:GetLifeForceSlotStatus()
    -- Free LF for the HUD = max - LF spent on minion buffs (same as 0.9.325).
    -- Debuff 525004 stacks still teach the peak in UpdateLifeForcePeak; using stacks
    -- directly here fought CoA/peak and read one short on spent/free.
    local coaFree, coaMax = self:TryReadCoALifeForce()
    local used = self:ScanLifeForceUsageFromBuffs()
    local max = coaMax and coaMax > 0 and coaMax or self:GetLifeForceMax()
    if coaFree ~= nil and coaMax and coaMax > 0 then
        -- Orb value is free Life Force.
        return math.max(0, max - coaFree), max, coaFree
    end
    return used, max, math.max(0, max - used)
end

function Advisor:GetGhoulMinionMax()
    local limits = self:GetConfig().minionMax or {}
    local defaultMax = (self.MINION_TYPES.ghoul and self.MINION_TYPES.ghoul.defaultMax) or 4

    if self.computingLifeForcePeak then
        return self.lifeForcePeak or limits.ghoul or defaultMax
    end

    if self:IsAutoLifeForceEnabled() then
        local lifeForceMax = self:GetLifeForceMax()
        local usedByOthers = self:GetActiveLifeForceUsed("ghoul")
        return math.max(0, lifeForceMax - usedByOthers)
    end

    if limits.ghoul then
        return limits.ghoul
    end

    return defaultMax
end

function Advisor:IsIgnoredAura(name, spellId)
    if spellId and self.IGNORED_AURA_SPELL_IDS[spellId] then
        return true
    end

    if name then
        local lower = string.lower(name)
        if self.IGNORED_AURA_NAMES[lower] then
            return true
        end
        if lower:find("life force", 1, true) then
            return true
        end
    end

    return false
end

function Advisor:ClassifyByBuffSpellId(spellId)
    if not spellId then
        return nil
    end

    for minionId, def in pairs(self.MINION_TYPES) do
        if def.buffSpellIds and def.buffSpellIds[spellId] then
            return minionId
        end
    end

    return nil
end

function Advisor:ClassifyMinionBuff(name, spellId)
    if self:IsIgnoredAura(name, spellId) then
        return nil
    end

    local bySpell = self:ClassifyByBuffSpellId(spellId)
    if bySpell then
        return bySpell
    end

    if not name then
        return nil
    end

    local fromRaise = self:MapTalentNameToMinionId(name)
    if fromRaise then
        return fromRaise
    end

    local lower = string.lower(name)
    for _, minionId in ipairs(self.MINION_CLASSIFY_ORDER) do
        local def = self.MINION_TYPES[minionId]
        if def and string.lower(def.label) == lower then
            return minionId
        end
        for _, creature in ipairs(self:GetDynamicNamePatterns(minionId)) do
            if string.lower(creature) == lower then
                return minionId
            end
        end
    end

    return self:ClassifyMinionName(name)
end

function Advisor:ScanAurasForMinions()
    if self.scanningAuras then
        return self.cachedAuraCounts or {}, self.cachedAuraSeen or {}
    end

    self.scanningAuras = true
    local counts = {}
    local seen = {}
    local buffKeys = {}

    for i = 1, 40 do
        local name, count, spellId, index = GetPlayerBuffData(i)
        if not name then
            break
        end

        local minionId = self:ClassifyMinionBuff(name, spellId)
        if minionId and self:UsesBuffTracking(minionId) then
            local maxAllowed = self:GetMinionScanCap(minionId)
            local cost = self:GetMinionLifeForceCost(minionId)
            local key = spellId and ("id:" .. tostring(spellId)) or ("name:" .. string.lower(name or ""))
            buffKeys[minionId] = buffKeys[minionId] or {}
            -- Multi-LF minions (crypt, abom) use one buff icon; 1-LF minions get one icon each.
            local duplicate = false
            if cost > 1 then
                duplicate = buffKeys[minionId][key] and true or false
                buffKeys[minionId][key] = true
            end

            seen[minionId] = seen[minionId] or {}
            table.insert(seen[minionId], {
                name = name,
                unit = "player",
                source = string.format("buff[%d]", index),
                spellId = spellId,
                duplicate = duplicate or nil,
            })

            if not duplicate then
                local add = math.max(1, count or 1)
                if cost > 1 then
                    counts[minionId] = 1
                else
                    counts[minionId] = math.min(maxAllowed, (counts[minionId] or 0) + add)
                end
            end
        end
    end

    for minionId, amount in pairs(counts) do
        counts[minionId] = math.min(amount, self:GetMinionScanCap(minionId))
    end

    self.scanningAuras = false
    return counts, seen
end

function Advisor:GetCachedAuraCounts()
    local now = GetTime and GetTime() or 0
    if self.cachedAuraCounts and now < (self.cachedAuraUntil or 0) then
        return self.cachedAuraCounts, self.cachedAuraSeen or {}
    end

    local counts, seen = self:ScanAurasForMinions()
    self.cachedAuraCounts = counts
    self.cachedAuraSeen = seen
    self.cachedAuraUntil = now + AURA_SCAN_CACHE_TTL
    return counts, seen
end

function Advisor:HasArmyOfTheDeadTalent()
    local def = self.TALENT_DEFS.armyOfTheDead
    if def.spellId and Ascension.HasTalentSpell(def.spellId) then
        return true
    end
    return select(1, Ascension.HasTalentByName(def.namePattern))
end

function Advisor:GetConfig()
    MancerDB.necromancer = MancerDB.necromancer or {}
    return MancerDB.necromancer
end

function Advisor:IsNecromancer()
    return Ascension.GetPlayerClass() == "NECROMANCER"
end

function Advisor:IsMinionAdvisorEnabled()
    local cfg = self:GetConfig()
    if cfg.enabled == false then
        return false
    end
    return Ascension.IsAnimationNecromancer()
end

function Advisor:IsStanceAdvisorEnabled()
    local cfg = self:GetConfig()
    if cfg.stanceEnabled == false then
        return false
    end
    return self:IsNecromancer()
end

function Advisor:ShouldRunAdvisor()
    return self:IsMinionAdvisorEnabled() or self:IsStanceAdvisorEnabled()
end

function Advisor:IsEnabled()
    return self:ShouldRunAdvisor()
end

function Advisor:IsInPartyOrRaid()
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        return true
    end
    if GetNumPartyMembers and GetNumPartyMembers() > 0 then
        return true
    end
    return false
end

function Advisor:HasShapeshiftStanceBar()
    if not GetNumShapeshiftForms then
        return false
    end
    local numForms = GetNumShapeshiftForms()
    return numForms and numForms > 0
end

-- Require "undead" in the aura name (or an exact known label). Bare substrings like
-- "protect" alone are too loose and are not how Ascension names these stances.
local function AuraNameLooksLikeStance(name)
    if not name then
        return false
    end
    local lower = string.lower(tostring(name)
        :gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", "")
        :gsub("|T.-|t", "")
        :gsub("^%s+", "")
        :gsub("%s+$", ""))
    if lower:find("life force", 1, true) then
        return false
    end
    if lower == "undead: protect"
        or lower == "undead: assault"
        or lower == "undead: assult"
        or lower == "undead: pacify" then
        return true
    end
    return lower:find("undead", 1, true)
        and (
            lower:find("protect", 1, true)
            or lower:find("assault", 1, true)
            or lower:find("assult", 1, true)
            or lower:find("pacify", 1, true)
        )
end

function Advisor:ClassifyUndeadStance(name, spellId)
    spellId = tonumber(spellId)

    -- Never classify from spellId alone — Ascension packs colliding IDs into other auras.
    if not AuraNameLooksLikeStance(name) then
        return nil
    end

    if spellId then
        for stanceId, def in pairs(self.UNDEAD_STANCES) do
            if def.spellIds and def.spellIds[spellId] then
                return stanceId, def.label
            end
        end
        local mapped = self.UNDEAD_STANCE_SPELL_LOOKUP[spellId]
        if mapped then
            local def = self.UNDEAD_STANCES[mapped]
            return mapped, def and def.label
        end
    end

    local lower = string.lower(tostring(name)
        :gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", "")
        :gsub("|T.-|t", ""))

    for stanceId, def in pairs(self.UNDEAD_STANCES) do
        if lower == string.lower(def.label) then
            return stanceId, def.label
        end
    end

    if lower:find("assault", 1, true) or lower:find("assult", 1, true) then
        return "assault", self.UNDEAD_STANCES.assault.label
    end
    if lower:find("protect", 1, true) then
        return "protect", self.UNDEAD_STANCES.protect.label
    end
    if lower:find("pacify", 1, true) then
        return "pacify", self.UNDEAD_STANCES.pacify.label
    end

    return nil
end

-- Ascension Necromancer stances live on the CoA MultiCast bar (totem-style
-- CheckButtons next to the Life Force orb) — NOT reliably in UnitBuff.
-- That is why detection appeared to "only work" while the LF prompt was up:
-- both share the same CoA bar, but UnitBuff goes blind when LF is spent.
function Advisor:GetCoAMultiCastBar()
    return rawget(_G, "CoAMultiCastActionBarFrame")
end

local function CoAButtonSpellId(button)
    if not button then
        return nil
    end
    local id = tonumber(button.spellID or button.spellId or button.actionSpellID or button.spell or button.id)
    if id then
        return id
    end
    if button.GetAttribute then
        for _, key in ipairs({ "spell", "spellID", "spellId", "actionspell", "macro" }) do
            local attr = button:GetAttribute(key)
            id = tonumber(attr)
            if id then
                return id
            end
            if type(attr) == "string" and attr ~= "" and GetSpellInfo then
                for spellId in pairs(Advisor.UNDEAD_STANCE_SPELL_LOOKUP) do
                    if GetSpellInfo(spellId) == attr then
                        return spellId
                    end
                end
                local stanceId = select(1, Advisor:ClassifyUndeadStance(attr, nil))
                if stanceId then
                    for spellId, sid in pairs(Advisor.UNDEAD_STANCE_SPELL_LOOKUP) do
                        if sid == stanceId then
                            return spellId
                        end
                    end
                end
            end
        end
        local action = tonumber(button:GetAttribute("action"))
        if action and GetActionInfo then
            local actionType, actionId = GetActionInfo(action)
            if actionType == "spell" then
                return tonumber(actionId)
            end
        end
    end
    if button.action and GetActionInfo then
        local actionType, actionId = GetActionInfo(button.action)
        if actionType == "spell" then
            return tonumber(actionId)
        end
    end
    if button.Icon and button.Icon.GetSpellID then
        id = tonumber(button.Icon:GetSpellID())
        if id then
            return id
        end
    end
    -- Match icon texture to known stance spell textures.
    local icon = button.icon or button.Icon or _G[(button.GetName and button:GetName() or "") .. "Icon"]
    local tex = icon and icon.GetTexture and icon:GetTexture()
    if tex and GetSpellTexture then
        tex = tostring(tex)
        for spellId in pairs(Advisor.UNDEAD_STANCE_SPELL_LOOKUP) do
            local bookTex = GetSpellTexture(spellId)
            if bookTex and tostring(bookTex) == tex then
                return spellId
            end
        end
    end
    -- Name fontstring on the button (shown for some CoA builds).
    local nameFS = button.Name or _G[(button.GetName and button:GetName() or "") .. "Name"]
    local nameText = nameFS and nameFS.GetText and nameFS:GetText()
    if nameText and nameText ~= "" and GetSpellInfo then
        for spellId in pairs(Advisor.UNDEAD_STANCE_SPELL_LOOKUP) do
            if GetSpellInfo(spellId) == nameText then
                return spellId
            end
        end
        local stanceId = select(1, Advisor:ClassifyUndeadStance(nameText, nil))
        if stanceId then
            for spellId, sid in pairs(Advisor.UNDEAD_STANCE_SPELL_LOOKUP) do
                if sid == stanceId then
                    return spellId
                end
            end
        end
    end
    return nil
end

local function CoAButtonIsActive(button)
    if not button then
        return false
    end
    if button.GetChecked then
        local checked = button:GetChecked()
        if checked then
            return true
        end
    end
    if button.checked then
        return true
    end
    if button.IsActive and button:IsActive() then
        return true
    end
    if button.active then
        return true
    end
    -- ExtraAction / CheckButton checked texture (GetChecked can be nil on Ascension).
    if button.GetCheckedTexture then
        local ct = button:GetCheckedTexture()
        if ct and ct.IsShown and ct:IsShown() then
            local a = ct.GetAlpha and ct:GetAlpha() or 1
            if a and a > 0.05 then
                return true
            end
        end
    end
    local border = button.Border
        or button.border
        or _G[(button.GetName and button:GetName() or "") .. "Border"]
    if border and border.IsShown and border:IsShown() then
        local a = border.GetAlpha and border:GetAlpha() or 1
        if a and a > 0.1 then
            return true
        end
    end
    if button.SelectedTexture and button.SelectedTexture.IsShown and button.SelectedTexture:IsShown() then
        return true
    end
    if button.Flash and button.Flash.IsShown and button.Flash:IsShown() then
        return true
    end
    -- Lit / desaturated icon often marks the active multicast slot.
    local icon = button.icon or button.Icon or _G[(button.GetName and button:GetName() or "") .. "Icon"]
    if icon and icon.IsDesaturated and not icon:IsDesaturated() then
        -- Only treat as active if sibling stance buttons exist and are desaturated —
        -- handled in ScanCoAMultiCastStance via relative compare.
    end
    return false
end

function Advisor:IterCoAMultiCastButtons(callback)
    if not callback then
        return
    end

    local bar = self:GetCoAMultiCastBar()
    if bar and type(bar.Buttons) == "table" then
        for key, button in pairs(bar.Buttons) do
            callback(key, button)
        end
    end

    -- Ascension pools buttons as:
    -- CoAMultiCastActionBarFramePoolFrameCoAMultiCastActionButtonTemplateN
    local pool = rawget(_G, "CoAMultiCastActionBarFramePoolFrame")
    if pool and pool.GetChildren then
        local children = { pool:GetChildren() }
        for i, child in ipairs(children) do
            if child and child.IsObjectType and child:IsObjectType("CheckButton") then
                callback("pool:" .. i, child)
            end
        end
    end

    for i = 1, 8 do
        local name = "CoAMultiCastActionBarFramePoolFrameCoAMultiCastActionButtonTemplate" .. i
        local button = rawget(_G, name)
        if button then
            callback(name, button)
        end
        if bar then
            callback("Button" .. i, bar["Button" .. i])
        end
        callback("legacy" .. i, rawget(_G, "CoAMultiCastActionButton" .. i))
    end
end

function Advisor:ScanCoAMultiCastStance()
    if not self:GetCoAMultiCastBar() and not rawget(_G, "CoAMultiCastActionBarFramePoolFrame") then
        return nil, nil, false
    end

    local candidates = {}
    local seen = {}

    self:IterCoAMultiCastButtons(function(_, button)
        if not button or seen[button] then
            return
        end
        seen[button] = true
        if button.IsShown and not button:IsShown() then
            return
        end

        local spellId = CoAButtonSpellId(button)
        local stanceId = spellId and self.UNDEAD_STANCE_SPELL_LOOKUP[spellId]
        if not stanceId and button.GetAttribute then
            local attr = button:GetAttribute("spell")
            if type(attr) == "string" then
                stanceId = select(1, self:ClassifyUndeadStance(attr, nil))
            end
        end
        if not stanceId then
            return
        end

        local active = CoAButtonIsActive(button)
        if not active and IsCurrentSpell and spellId then
            local ok, current = pcall(IsCurrentSpell, spellId)
            active = ok and current
        end

        local icon = button.icon or button.Icon or _G[(button.GetName and button:GetName() or "") .. "Icon"]
        local desat = icon and icon.IsDesaturated and icon:IsDesaturated()
        table.insert(candidates, {
            stanceId = stanceId,
            spellId = spellId,
            active = active,
            desat = desat and true or false,
        })
    end)

    -- No stance buttons found on the bar — scan failed / bar empty; not proof of "no stance".
    if #candidates == 0 then
        return nil, nil, false
    end

    for _, c in ipairs(candidates) do
        if c.active then
            local def = self.UNDEAD_STANCES[c.stanceId]
            return c.stanceId, def and def.label, true
        end
    end

    -- Ascension often leaves GetChecked nil; active slot is the non-desaturated icon.
    local undestat = {}
    for _, c in ipairs(candidates) do
        if not c.desat then
            table.insert(undestat, c)
        end
    end
    if #undestat == 1 then
        local def = self.UNDEAD_STANCES[undestat[1].stanceId]
        return undestat[1].stanceId, def and def.label, true
    end

    -- Saw stance buttons and none look selected → truly unstanced.
    if #undestat == 0 then
        return nil, nil, true
    end

    -- Multiple lit icons — ambiguous; do not claim empty.
    return nil, nil, false
end

function Advisor:DumpCoAMultiCastButtons()
    local bar = self:GetCoAMultiCastBar()
    local pool = rawget(_G, "CoAMultiCastActionBarFramePoolFrame")
    if not bar and not pool then
        Mancer.Print("  CoA MultiCast bar: not found")
        return
    end
    Mancer.Print(string.format(
        "  CoA MultiCast bar: %s shown=%s pool=%s",
        bar and bar.GetName and bar:GetName() or "?",
        tostring(bar and bar.IsShown and bar:IsShown()),
        pool and "yes" or "no"
    ))
    local count = 0
    local seen = {}
    self:IterCoAMultiCastButtons(function(label, button)
        if not button or seen[button] then
            return
        end
        seen[button] = true
        count = count + 1
        local spellId = CoAButtonSpellId(button)
        local name = spellId and GetSpellInfo and GetSpellInfo(spellId) or "?"
        local keys = {}
        for k, v in pairs(button) do
            local vt = type(v)
            if vt == "number" or vt == "string" or vt == "boolean" then
                table.insert(keys, string.format("%s=%s", tostring(k), tostring(v)))
            end
        end
        table.sort(keys)
        Mancer.Print(string.format(
            "    [%s] spell=%s (%s) checked=%s shown=%s",
            tostring(label),
            tostring(spellId or "?"),
            tostring(name),
            tostring(CoAButtonIsActive(button)),
            tostring(button.IsShown and button:IsShown())
        ))
        if #keys > 0 then
            Mancer.Print("      fields: " .. table.concat(keys, ", "))
        end
    end)
    if count == 0 then
        Mancer.Print("    (no pooled CheckButtons found)")
    end
end

function Advisor:GetStanceTextureLookup()
    local map = {}
    for spellId, stanceId in pairs(self.UNDEAD_STANCE_SPELL_LOOKUP) do
        local tex = GetSpellTexture and GetSpellTexture(spellId)
        if (not tex or tex == "") and GetSpellInfo then
            tex = select(3, GetSpellInfo(spellId))
        end
        if tex and tex ~= "" then
            map[tostring(tex):lower()] = stanceId
        end
    end
    return map
end

function Advisor:ClassifyStanceTexture(texture)
    if not texture then
        return nil, nil
    end
    local stanceId = self:GetStanceTextureLookup()[tostring(texture):lower()]
    if not stanceId then
        return nil, nil
    end
    local def = self.UNDEAD_STANCES[stanceId]
    return stanceId, def and def.label
end

-- ShapeshiftButton:GetChecked() — more reliable than GetShapeshiftForm on Ascension.
function Advisor:ScanShapeshiftButtonStance()
    local num = (GetNumShapeshiftForms and GetNumShapeshiftForms()) or 10
    for i = 1, math.max(num, 10) do
        local button = _G["ShapeshiftButton" .. i] or _G["StanceButton" .. i]
        if button and button.IsShown and button:IsShown() then
            local checked = button.GetChecked and button:GetChecked()
            if checked then
                local texture, name = nil, nil
                if GetShapeshiftFormInfo then
                    texture, name = GetShapeshiftFormInfo(i)
                end
                local stanceId, label = self:ClassifyUndeadStance(name, nil)
                if not stanceId then
                    stanceId, label = self:ClassifyStanceTexture(texture)
                end
                if not stanceId then
                    local icon = _G["ShapeshiftButton" .. i .. "Icon"]
                        or _G["StanceButton" .. i .. "Icon"]
                        or button.icon
                        or button.Icon
                    local tex = icon and icon.GetTexture and icon:GetTexture()
                    stanceId, label = self:ClassifyStanceTexture(tex)
                end
                if stanceId then
                    return stanceId, label
                end
            end
        end
    end
    return nil, nil
end

function Advisor:ScanShapeshiftStance()
    if not GetNumShapeshiftForms or not GetShapeshiftFormInfo then
        return nil
    end

    local function consider(texture, name)
        local stanceId, label = self:ClassifyUndeadStance(name, nil)
        if stanceId then
            return stanceId, label
        end
        return self:ClassifyStanceTexture(texture)
    end

    local activeForm = GetShapeshiftForm and GetShapeshiftForm() or 0
    if activeForm and activeForm > 0 then
        local texture, name = GetShapeshiftFormInfo(activeForm)
        local stanceId, label = consider(texture, name)
        if stanceId then
            return stanceId, label
        end
    end

    local numForms = GetNumShapeshiftForms()
    if numForms and numForms > 0 then
        for i = 1, numForms do
            local texture, name, isActive = GetShapeshiftFormInfo(i)
            if isActive then
                local stanceId, label = consider(texture, name)
                if stanceId then
                    return stanceId, label
                end
            end
        end
    end

    return nil
end

-- True only when the stance bar confidently shows no Undead form selected.
function Advisor:ShapeshiftBarShowsNoStance()
    if not self:HasShapeshiftStanceBar() then
        return false
    end
    if self:ScanShapeshiftButtonStance() or self:ScanShapeshiftStance() then
        return false
    end
    local form = GetShapeshiftForm and GetShapeshiftForm() or 0
    if form and form > 0 then
        return false
    end
    local num = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
    for i = 1, num do
        local _, _, isActive = GetShapeshiftFormInfo(i)
        if isActive then
            return false
        end
        local button = _G["ShapeshiftButton" .. i]
        if button and button.GetChecked and button:GetChecked() then
            return false
        end
    end
    return true
end

-- Warrior-style check: active stance spells report as "current".
-- This does NOT depend on UnitBuff / Life Force debuff visibility.
function Advisor:ScanCurrentSpellStance()
    if not IsCurrentSpell then
        return nil, nil
    end

    for spellId, stanceId in pairs(self.UNDEAD_STANCE_SPELL_LOOKUP) do
        local hit = false
        local ok, current = pcall(IsCurrentSpell, spellId)
        if ok and current then
            hit = true
        end
        if not hit then
            local bookName = GetSpellInfo and GetSpellInfo(spellId)
            if bookName then
                ok, current = pcall(IsCurrentSpell, bookName)
                if ok and current then
                    hit = true
                end
            end
        end
        if hit then
            local def = self.UNDEAD_STANCES[stanceId]
            return stanceId, def and def.label
        end
    end

    return nil, nil
end

-- Action-bar fallback: lit stance buttons use IsCurrentAction.
function Advisor:ScanCurrentActionStance()
    if not IsCurrentAction or not GetActionInfo then
        return nil, nil
    end

    local maxSlot = 120
    for slot = 1, maxSlot do
        local ok, current = pcall(IsCurrentAction, slot)
        if ok and current then
            local actionType, id = GetActionInfo(slot)
            id = tonumber(id)
            if actionType == "spell" and id and self.UNDEAD_STANCE_SPELL_LOOKUP[id] then
                local stanceId = self.UNDEAD_STANCE_SPELL_LOOKUP[id]
                local def = self.UNDEAD_STANCES[stanceId]
                return stanceId, def and def.label
            end
        end
    end

    return nil, nil
end

function Advisor:IsPlayerAuraSource(unitCaster)
    if not unitCaster then
        return true
    end
    if unitCaster == "player" then
        return true
    end
    if UnitIsUnit and UnitIsUnit(unitCaster, "player") then
        return true
    end
    return false
end

function Advisor:GetStanceScanTooltip()
    local tip = self._stanceScanTooltip
    if tip then
        return tip
    end
    tip = CreateFrame("GameTooltip", "MancerStanceScanTooltip", UIParent, "GameTooltipTemplate")
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    self._stanceScanTooltip = tip
    return tip
end

local function TooltipTitle(tip)
    if not tip then
        return nil
    end
    local fs = _G[tip:GetName() .. "TextLeft1"]
    if fs and fs.GetText then
        local text = fs:GetText()
        if text and text ~= "" then
            return text
        end
    end
    return nil
end

function Advisor:ScanStanceFromTooltips()
    local tip = self:GetStanceScanTooltip()
    if not tip or not tip.SetUnitBuff then
        return nil, nil
    end

    local function considerName(name)
        return self:ClassifyUndeadStance(name, nil)
    end

    for i = 1, 40 do
        tip:ClearLines()
        tip:SetOwner(UIParent, "ANCHOR_NONE")
        pcall(tip.SetUnitBuff, tip, "player", i)
        local sid, lab = considerName(TooltipTitle(tip))
        if sid then
            tip:Hide()
            return sid, lab
        end
    end

    if tip.SetUnitDebuff then
        for i = 1, 40 do
            tip:ClearLines()
            tip:SetOwner(UIParent, "ANCHOR_NONE")
            pcall(tip.SetUnitDebuff, tip, "player", i)
            local sid, lab = considerName(TooltipTitle(tip))
            if sid then
                tip:Hide()
                return sid, lab
            end
        end
    end

    tip:Hide()
    return nil, nil
end

function Advisor:ScanStanceFromAuraButtons()
    local tip = self:GetStanceScanTooltip()
    if not tip then
        return nil, nil
    end

    local function scanPrefix(prefix, setter)
        local limit = math.max(tonumber(BUFF_ACTUAL_DISPLAY) or 0, tonumber(DEBUFF_ACTUAL_DISPLAY) or 0, 32)
        for i = 1, limit do
            local button = _G[prefix .. i]
            if button and button.IsShown and button:IsShown() then
                local auraIndex = button.GetID and button:GetID() or i
                if auraIndex and auraIndex > 0 and setter then
                    tip:ClearLines()
                    tip:SetOwner(UIParent, "ANCHOR_NONE")
                    pcall(setter, tip, "player", auraIndex)
                    local stanceId, label = self:ClassifyUndeadStance(TooltipTitle(tip), nil)
                    if stanceId then
                        tip:Hide()
                        return stanceId, label
                    end
                end
            end
        end
        return nil, nil
    end

    local sid, lab = scanPrefix("BuffButton", tip.SetUnitBuff)
    if sid then
        return sid, lab
    end
    return scanPrefix("DebuffButton", tip.SetUnitDebuff)
end

function Advisor:FindStanceAuraDirect()
    local names = {
        "Undead: Protect",
        "Undead: Assault",
        "Undead: Assult",
        "Undead: Pacify",
    }
    for spellId in pairs(self.UNDEAD_STANCE_SPELL_LOOKUP) do
        local bookName = GetSpellInfo and GetSpellInfo(spellId)
        if bookName and bookName ~= "" then
            table.insert(names, bookName)
        end
    end

    local seen = {}
    for _, auraName in ipairs(names) do
        if auraName and not seen[auraName] then
            seen[auraName] = true
            local name, _, _, _, _, _, _, _, _, _, spellId
            if UnitBuff then
                name, _, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", auraName)
            end
            if (not name) and UnitAura then
                name, _, _, _, _, _, _, _, _, _, spellId = UnitAura("player", auraName, "HELPFUL")
            end
            if (not name) and UnitDebuff then
                name, _, _, _, _, _, _, _, _, _, spellId = UnitDebuff("player", auraName)
            end
            if (not name) and UnitAura then
                name, _, _, _, _, _, _, _, _, _, spellId = UnitAura("player", auraName, "HARMFUL")
            end
            if name then
                local stanceId, label = self:ClassifyUndeadStance(name, spellId)
                if stanceId then
                    return stanceId, label
                end
            end
        end
    end
    return nil, nil
end

function Advisor:ScanBuffStance()
    local stanceId, label = self:ScanStanceFromTooltips()
    if stanceId then
        return stanceId, label
    end

    stanceId, label = self:ScanStanceFromAuraButtons()
    if stanceId then
        return stanceId, label
    end

    stanceId, label = self:FindStanceAuraDirect()
    if stanceId then
        return stanceId, label
    end

    for i = 1, 40 do
        local name, _, spellId, _, unitCaster = GetPlayerBuffData(i)
        if name and self:IsPlayerAuraSource(unitCaster) and not self:IsLifeForceAura(name, spellId) then
            stanceId, label = self:ClassifyUndeadStance(name, spellId)
            if stanceId then
                return stanceId, label
            end
        end
    end
    for i = 1, 40 do
        local name, _, spellId, _, unitCaster = GetPlayerDebuffData(i)
        if name and self:IsPlayerAuraSource(unitCaster) and not self:IsLifeForceAura(name, spellId) then
            stanceId, label = self:ClassifyUndeadStance(name, spellId)
            if stanceId then
                return stanceId, label
            end
        end
    end

    return nil, nil
end

function Advisor:RememberStance(stanceId, label)
    if not stanceId then
        return
    end
    self.trackedStanceId = stanceId
    self.trackedStanceLabel = label
    if MancerDB then
        MancerDB.activeUndeadStance = stanceId
        MancerDB.activeUndeadStanceLabel = label
    end
end

function Advisor:ClearRememberedStance(stanceId)
    if stanceId and self.trackedStanceId and self.trackedStanceId ~= stanceId then
        return
    end
    self.trackedStanceId = nil
    self.trackedStanceLabel = nil
    if MancerDB then
        MancerDB.activeUndeadStance = nil
        MancerDB.activeUndeadStanceLabel = nil
    end
end

function Advisor:GetRememberedStance()
    local stanceId = self.trackedStanceId or (MancerDB and MancerDB.activeUndeadStance)
    if not stanceId then
        return nil, nil
    end
    local def = self.UNDEAD_STANCES[stanceId]
    local label = self.trackedStanceLabel
        or (MancerDB and MancerDB.activeUndeadStanceLabel)
        or (def and def.label)
    self.trackedStanceId = stanceId
    self.trackedStanceLabel = label
    return stanceId, label
end

-- Ascension UnitBuff / tooltips see Undead stances only while free Life Force > 0
-- (LF prompt showing as X/Y with X < Y). When fully spent (free=0, prompt hidden),
-- those APIs go blind — keep CLEU/scan memory in that window only.
function Advisor:IsLifeForceAuraApiBlind()
    local stacks = self:ScanLifeForceDebuff()
    if stacks and stacks > 0 then
        return false
    end
    local _, _, lfFree = self:GetLifeForceSlotStatus()
    if lfFree and lfFree > 0 then
        return false
    end
    return true
end

-- CLEU apply only. Never clear on REMOVED — Ascension fake-removes the stance
-- aura when Life Force hits 0/max, which was wiping detection.
function Advisor:NoteStanceAuraEvent(spellId, spellName, applied)
    if not applied then
        return
    end
    if spellName and self:IsLifeForceAura(spellName, spellId) then
        return
    end

    spellId = tonumber(spellId)
    local stanceId, label = self:ClassifyUndeadStance(spellName, spellId)
    if not stanceId and spellId and self.UNDEAD_STANCE_SPELL_LOOKUP[spellId] then
        stanceId = self.UNDEAD_STANCE_SPELL_LOOKUP[spellId]
        local def = self.UNDEAD_STANCES[stanceId]
        label = def and def.label
    end
    if not stanceId then
        return
    end

    self:RememberStance(stanceId, label)
    self:ForceStanceAlertRefresh()
end

function Advisor:RefreshStanceFromShapeshiftBar()
    -- Read the bar immediately (event-time). Prefer form index over isActive flags.
    local form = GetShapeshiftForm and GetShapeshiftForm() or 0
    if form and form > 0 and GetShapeshiftFormInfo then
        local texture, name = GetShapeshiftFormInfo(form)
        local stanceId, label = self:ClassifyUndeadStance(name, nil)
        if not stanceId then
            stanceId, label = self:ClassifyStanceTexture(texture)
        end
        if stanceId then
            self:RememberStance(stanceId, label)
            return stanceId, label
        end
    end

    local stanceId, label = self:ScanShapeshiftButtonStance()
    if stanceId then
        self:RememberStance(stanceId, label)
        return stanceId, label
    end

    stanceId, label = self:ScanShapeshiftStance()
    if stanceId then
        self:RememberStance(stanceId, label)
        return stanceId, label
    end

    if self:ShapeshiftBarShowsNoStance() then
        self:ClearRememberedStance()
        return nil, nil
    end

    return self:GetRememberedStance()
end

function Advisor:GetActiveUndeadStance()
    -- Ascension Necro stances live on the CoA MultiCast bar. Prefer that over
    -- sticky CLEU/LF memory — otherwise cancelling a stance still looks "active"
    -- when the last remembered form matches the desired one (prompt never fires).
    local stanceId, label, coaConfident = self:ScanCoAMultiCastStance()
    if stanceId then
        self:RememberStance(stanceId, label)
        return stanceId, label
    end
    if coaConfident then
        self:ClearRememberedStance()
        return nil, nil
    end

    -- Shapeshift bar (works at free=0 on some clients / dumps).
    stanceId, label = self:RefreshStanceFromShapeshiftBar()
    if stanceId then
        return stanceId, label
    end
    -- RefreshStanceFromShapeshiftBar already cleared memory if bar is empty.
    if self:ShapeshiftBarShowsNoStance() then
        return nil, nil
    end

    stanceId, label = self:ScanCurrentSpellStance()
    if stanceId then
        self.stanceCurrentSpellWorks = true
        self:RememberStance(stanceId, label)
        return stanceId, label
    end

    stanceId, label = self:ScanCurrentActionStance()
    if stanceId then
        self.stanceCurrentSpellWorks = true
        self:RememberStance(stanceId, label)
        return stanceId, label
    end

    -- Skip heavy tooltip iteration when LF is spent — UnitBuff-by-name is enough.
    stanceId, label = self:FindStanceAuraDirect()
    if stanceId then
        self:RememberStance(stanceId, label)
        return stanceId, label
    end

    if not self:IsLifeForceAuraApiBlind() then
        stanceId, label = self:ScanBuffStance()
        if stanceId then
            self:RememberStance(stanceId, label)
            return stanceId, label
        end
        -- Live aura APIs can see buffs and found none → truly unstanced.
        self:ClearRememberedStance()
        return nil, nil
    end

    -- LF-blind window only: keep last CLEU/scan memory (Ascension hides stance auras).
    return self:GetRememberedStance()
end

function Advisor:ForceStanceAlertRefresh()
    -- Do not clear lastAlertKey here. UpdateAlert(true) redraws; if the advisor
    -- has nothing left to show (stance OK + LF hidden), it must still HideAlert.
    -- Clearing the key first skipped HideAlert and left "Use Undead: …" stuck.
    self.dirtyAlert = true
    self.alertTimer = ALERT_REFRESH_INTERVAL
    if self:ShouldRunAdvisor() then
        self:UpdateAlert(true)
    end
end

function Advisor:GetDesiredUndeadStance()
    if self:IsInPartyOrRaid() then
        return "assault", self.UNDEAD_STANCES.assault.label
    end
    return "protect", self.UNDEAD_STANCES.protect.label
end

function Advisor:GetStanceAlert()
    if not self:IsStanceAdvisorEnabled() then
        return nil
    end
    if Mancer.IsStancePromptAllowed and not Mancer.IsStancePromptAllowed() then
        return nil
    end

    local activeId = self:GetActiveUndeadStance()
    local desiredId, desiredLabel = self:GetDesiredUndeadStance()
    -- nil activeId = no stance → still prompt. Only suppress when the live form matches.
    if activeId and activeId == desiredId then
        return nil
    end

    return string.format("Use %s", desiredLabel)
end

function Advisor:GetMinionMax(minionId)
    local cfg = self:GetConfig()
    local limits = cfg.minionMax or {}
    local def = self.MINION_TYPES[minionId]

    if minionId == "ghoul" then
        return self:GetGhoulMinionMax()
    end

    if self:IsMultiSlotMinionBuff(minionId) and self:IsAutoLifeForceEnabled() then
        local lifeForceMax = self:GetLifeForceMax()
        local usedByOthers = self:GetActiveLifeForceUsed(minionId)
        return math.max(0, lifeForceMax - usedByOthers)
    end

    return limits[minionId] or (def and def.defaultMax) or 1
end

function Advisor:GetMinionScanCap(minionId)
    local def = self.MINION_TYPES[minionId]
    local limits = self:GetConfig().minionMax or {}

    if minionId == "ghoul" or self:IsMultiSlotMinionBuff(minionId) then
        -- Dynamic: follow Life Force pool (typically 1–6), never a fixed magic ceiling.
        if self.computingLifeForcePeak then
            return math.max(tonumber(self.lifeForcePeak) or 1, 1)
        end
        local lfMax = tonumber(self:GetLifeForceMax()) or 0
        local peak = tonumber(self.lifeForcePeak) or 0
        local configured = math.max(tonumber(limits.lifeForceMax) or 0, tonumber(limits.ghoul) or 0)
        return math.max(lfMax, peak, configured, 1)
    end

    return limits[minionId] or (def and def.defaultMax) or 1
end

function Advisor:GetRawMergedCounts()
    local counts = {}
    local auraCounts, _ = self:ScanAurasForMinions()
    for minionId, amount in pairs(auraCounts) do
        counts[minionId] = amount
    end

    local unitCounts, _ = self:ScanPhysicalBuffMinions()
    for minionId, amount in pairs(unitCounts) do
        if amount > (counts[minionId] or 0) then
            counts[minionId] = amount
        end
    end

    return counts
end

function Advisor:GetMinionRequiredLevel(minionId)
    local def = self.MINION_TYPES[minionId]
    return def and def.requiredLevel or nil
end

function Advisor:IsMinionAvailable(minionId)
    local requiredLevel = self:GetMinionRequiredLevel(minionId)
    if requiredLevel then
        local playerLevel = UnitLevel and UnitLevel("player") or 1
        if playerLevel < requiredLevel then
            return false
        end
    end
    return self:HasMinionTalent(minionId)
end

function Advisor:HasMinionTalent(minionId)
    local now = GetTime and GetTime() or 0
    if self.talentCache and now < (self.talentCacheUntil or 0) then
        local cached = self.talentCache[minionId]
        if cached ~= nil then
            return cached
        end
    else
        self.talentCache = {}
        self.talentCacheUntil = now + 2.0
    end

    local result = self:EvaluateMinionTalent(minionId)
    self.talentCache[minionId] = result
    return result
end

function Advisor:EvaluateMinionTalent(minionId)
    local def = self.MINION_TYPES[minionId]
    if not def then
        return false
    end

    local isAnimateStrip = self:IsAnimateReadyMinion(minionId)

    if Ascension.HasCharacterAdvancement() then
        for _, talent in ipairs(Ascension.GetKnownTalents()) do
            if self:MapTalentNameToMinionId(talent.name) == minionId then
                -- Animate strip slots must not light up from Raise:… (same minionId map).
                if not isAnimateStrip or (talent.name and tostring(talent.name):find("^Animate:", 1, true)) then
                    return true
                end
            end
        end

        if def.talentPatterns then
            for _, pattern in ipairs(def.talentPatterns) do
                if (not isAnimateStrip or tostring(pattern):find("^Animate:", 1, true))
                    and select(1, Ascension.HasTalentByName(pattern)) then
                    return true
                end
            end
        end

        if def.summonSpellIds then
            for spellId in pairs(def.summonSpellIds) do
                -- Animates may be known spell-ids without a CA talent rank.
                if Ascension.HasActiveTalentSpell(spellId) or Ascension.HasTalentSpell(spellId) then
                    return true
                end
            end
        end

        if def.cooldownSpellIds then
            for spellId in pairs(def.cooldownSpellIds) do
                if Ascension.HasActiveTalentSpell(spellId) or Ascension.HasTalentSpell(spellId) then
                    return true
                end
            end
        end

        if def.alertSpellId
            and (Ascension.HasActiveTalentSpell(def.alertSpellId) or Ascension.HasTalentSpell(def.alertSpellId)) then
            return true
        end

        return false
    end

    if def.talentPatterns then
        for _, pattern in ipairs(def.talentPatterns) do
            if select(1, Ascension.HasTalentByName(pattern)) then
                return true
            end
        end
    end

    if def.summonSpellIds then
        for spellId in pairs(def.summonSpellIds) do
            if Ascension.HasTalentSpell(spellId) then
                return true
            end
        end
    end

    if def.cooldownSpellIds then
        for spellId in pairs(def.cooldownSpellIds) do
            if Ascension.HasTalentSpell(spellId) then
                return true
            end
        end
    end

    if def.alertSpellId and Ascension.HasTalentSpell(def.alertSpellId) then
        return true
    end

    if def.spellNames then
        for _, spellName in ipairs(def.spellNames) do
            if IsSpellKnown and IsSpellKnown(spellName) then
                return true
            end
            local spellId = ResolveSpellIdFromName(spellName)
            if spellId and Ascension.HasTalentSpell(spellId) then
                return true
            end
        end
    end

    for _, talent in ipairs(Ascension.GetKnownTalents()) do
        if self:MapTalentNameToMinionId(talent.name) == minionId then
            return true
        end
    end

    return false
end

function Advisor:MapTalentNameToMinionId(talentName)
    if not talentName then
        return nil
    end

    local creature = talentName:match("^Raise: (.+)$") or talentName:match("^Animate: (.+)$")
    if not creature then
        for minionId, def in pairs(self.MINION_TYPES) do
            if def.talentPatterns then
                for _, pattern in ipairs(def.talentPatterns) do
                    if talentName:find(pattern, 1, true) then
                        return minionId
                    end
                end
            end
        end
        return nil
    end

    local lower = string.lower(creature)
    -- CA node names can differ from spell tip names (same spell ID).
    if lower:find("putrid ghoul", 1, true) then
        return "skeletal_archer"
    end
    if lower:find("plaguefather", 1, true) then
        return "plaguefather"
    end
    if lower:find("frost wyrm", 1, true) or lower:find("shatterfrost", 1, true) then
        return "frost_wyrm"
    end
    if lower:find("greater skeletal", 1, true) then
        return "skeletal_warrior_greater"
    end
    if lower:find("lesser skeletal", 1, true) or lower:find("brittle skeleton", 1, true) then
        return "skeletal_warrior_lesser"
    end
    if lower:find("skeletal rogue", 1, true) then
        return "skeletal_rogue"
    end
    if lower:find("crypt fiend", 1, true) or lower:find("crypt keeper", 1, true) then
        return "crypt_fiend"
    end
    if lower:find("banshee", 1, true) then
        return "banshee"
    end
    if lower:find("archer", 1, true) or lower:find("grave mage", 1, true) then
        return "skeletal_archer"
    end
    if lower:find("wraith", 1, true) or lower:find("knight of decay", 1, true) then
        return "bone_wraith"
    end
    if lower:find("tomb king", 1, true) then
        return "tomb_king"
    end
    if lower:find("abomination", 1, true) or lower:find("colossus", 1, true) or lower:find("golem", 1, true) then
        return "abomination"
    end
    if lower:find("ghoul", 1, true) or lower:find("horror", 1, true) or lower:find("gurgling", 1, true)
        or lower:find("rotling", 1, true) then
        return "ghoul"
    end

    return nil
end

function Advisor:IsRequiredForAlert(minionId)
    local def = self.MINION_TYPES[minionId]
    return def and def.requiredForAlert ~= false
end

function Advisor:GetDynamicNamePatterns(minionId)
    self.dynamicPatternCache = self.dynamicPatternCache or {}
    local cached = self.dynamicPatternCache[minionId]
    if cached then
        return cached
    end

    local patterns = {}
    local seen = {}

    local function addPattern(pattern)
        if pattern and pattern ~= "" and not seen[pattern] then
            seen[pattern] = true
            table.insert(patterns, pattern)
        end
    end

    for _, talent in ipairs(Ascension.GetKnownTalents()) do
        if self:MapTalentNameToMinionId(talent.name) == minionId then
            local creature = talent.name:match("^Raise: (.+)$") or talent.name:match("^Animate: (.+)$")
            addPattern(creature)
        end
    end

    self.dynamicPatternCache[minionId] = patterns
    return patterns
end

function Advisor:GetKnownMinionTalents()
    if self.cachedKnownMinions and not self.requiredMinionsDirty then
        return self.cachedKnownMinions
    end

    local known = {}

    for minionId, def in pairs(self.MINION_TYPES) do
        if self:HasMinionTalent(minionId) then
            table.insert(known, {
                id = minionId,
                label = def.label,
                namePatterns = def.namePatterns,
                requiredForAlert = self:IsRequiredForAlert(minionId),
            })
        end
    end

    table.sort(known, function(a, b)
        return a.label < b.label
    end)

    self.cachedKnownMinions = known
    self.requiredMinionsDirty = false
    return known
end

function Advisor:GetRequiredMinions()
    local required = {}
    for _, entry in ipairs(self:GetKnownMinionTalents()) do
        if entry.requiredForAlert then
            table.insert(required, entry)
        end
    end
    return required
end

function Advisor:GetStatusMinions()
    local byId = {}
    local list = {}

    for _, entry in ipairs(self:GetKnownMinionTalents()) do
        byId[entry.id] = true
        table.insert(list, entry)
    end

    local counts = self:CollectActiveMinions()
    for minionId, amount in pairs(counts) do
        if amount > 0 and not byId[minionId] then
            local def = self.MINION_TYPES[minionId]
            if def then
                byId[minionId] = true
                table.insert(list, {
                    id = minionId,
                    label = def.label,
                    namePatterns = def.namePatterns,
                    requiredForAlert = false,
                    activeOnly = true,
                })
            end
        end
    end

    table.sort(list, function(a, b)
        return a.label < b.label
    end)

    return list
end

local function NameMatches(name, patterns)
    if not name then
        return false
    end
    local lower = string.lower(name)
    for _, pattern in ipairs(patterns) do
        if lower:find(string.lower(pattern), 1, true) then
            return true
        end
    end
    return false
end

function Advisor:FindActiveSummon(guid)
    if not guid or not self.activeSummons then
        return nil, nil
    end
    if self.activeSummons[guid] then
        return guid, self.activeSummons[guid]
    end
    for key, info in pairs(self.activeSummons) do
        if GuidsMatch(key, guid) then
            return key, info
        end
    end
    return nil, nil
end

function Advisor:IsTrackedSummon(guid)
    return self:FindActiveSummon(guid) ~= nil
end

function Advisor:GuidsMatch(a, b)
    return GuidsMatch(a, b)
end

function Advisor:CacheGuidUnit(guid, unit)
    if not guid or not unit then
        return
    end
    local key = NormalizeGuidKey(guid)
    if not key then
        return
    end
    self.guidUnitCache = self.guidUnitCache or {}
    self.guidUnitCache[key] = unit
end

function Advisor:ClearGuidUnitCache(guid)
    if not guid or not self.guidUnitCache then
        return
    end
    local key = NormalizeGuidKey(guid)
    if key then
        self.guidUnitCache[key] = nil
    end
end

function Advisor:ResolveUnitTokenFromGuid(guid)
    if not guid then
        return nil
    end

    local key = NormalizeGuidKey(guid)
    if key and self.guidUnitCache and self.guidUnitCache[key] then
        local cached = self.guidUnitCache[key]
        local cachedGuid = UnitGUID and UnitGUID(cached)
        if cachedGuid and GuidsMatch(cachedGuid, guid) then
            return cached
        end
        self.guidUnitCache[key] = nil
    end

    local _, info = self:FindActiveSummon(guid)
    if info and info.unit then
        local linkedGuid = UnitGUID and UnitGUID(info.unit)
        if linkedGuid and GuidsMatch(linkedGuid, guid) then
            self:CacheGuidUnit(guid, info.unit)
            return info.unit
        end
        info.unit = nil
    end

    local function tryUnit(unit)
        if not unit then
            return nil
        end
        local unitGuid = UnitGUID and UnitGUID(unit)
        if unitGuid and GuidsMatch(unitGuid, guid) then
            self:CacheGuidUnit(guid, unit)
            if info then
                info.unit = unit
            end
            return unit
        end
        return nil
    end

    for _, unit in ipairs({ "target", "mouseover", "focus", "pet" }) do
        local found = tryUnit(unit)
        if found then
            return found
        end
    end

    for i = 1, 40 do
        local found = tryUnit("nameplate" .. i)
        if found then
            return found
        end
    end

    for _, unit in ipairs(self:GetCachedScanUnits()) do
        local found = tryUnit(unit)
        if found then
            return found
        end
    end

    if self.trackedUnits then
        for unit in pairs(self.trackedUnits) do
            local found = tryUnit(unit)
            if found then
                return found
            end
        end
    end

    return nil
end

function Advisor:TryLinkSummonUnit(guid)
    if not guid then
        return nil
    end
    local unit = self:ResolveUnitTokenFromGuid(guid)
    if unit then
        local _, info = self:FindActiveSummon(guid)
        if info then
            info.unit = unit
        end
    end
    return unit
end

function Advisor:OnGuardianUnitDiscovered(unit)
    if not unit then
        return
    end
    local unitGuid = UnitGUID and UnitGUID(unit)
    if not unitGuid then
        return
    end

    local summonKey, info = self:FindActiveSummon(unitGuid)
    if summonKey then
        info.unit = unit
        self:CacheGuidUnit(unitGuid, unit)
    end
    -- Never RecordSummon from nameplate alone — party/raid has other players' guardians too.
end

function Advisor:GetRepresentativeUnitForMinion(minionId)
    local now = GetTime and GetTime() or 0
    local fallback

    if self.activeSummons then
        for guid, info in pairs(self.activeSummons) do
            if info and info.minionId == minionId and self:IsTrustedSummonSource(info.source) then
                if info.expiresAt and info.expiresAt <= now then
                    -- expired temporary
                else
                    local unit = info.unit
                    if unit and UnitGUID and GuidsMatch(UnitGUID(unit), guid) and self:IsOwnedByPlayer(unit) then
                        return unit, guid, info.name
                    end
                    unit = self:ResolveUnitTokenFromGuid(guid)
                    if unit and self:IsOwnedByPlayer(unit) then
                        info.unit = unit
                        return unit, guid, info.name or (UnitName and UnitName(unit))
                    end
                    if not fallback then
                        fallback = { guid = guid, name = info.name }
                    end
                end
            end
        end
    end

    local prefer = { "target", "mouseover", "focus", "pet" }
    for _, unit in ipairs(prefer) do
        local id, name = self:TryClassifyVisibleMinionUnit(unit)
        if id == minionId then
            local guid = UnitGUID and UnitGUID(unit)
            return unit, guid, name
        end
    end

    for i = 1, 40 do
        local unit = "nameplate" .. i
        local id, name = self:TryClassifyVisibleMinionUnit(unit)
        if id == minionId then
            local guid = UnitGUID and UnitGUID(unit)
            return unit, guid, name
        end
    end

    for _, unit in ipairs(self:GetCachedScanUnits()) do
        local id, name = self:TryClassifyVisibleMinionUnit(unit)
        if id == minionId then
            local guid = UnitGUID and UnitGUID(unit)
            return unit, guid, name
        end
    end

    if fallback then
        return nil, fallback.guid, fallback.name
    end
    return nil, nil, nil
end

-- Necromancer minions are engine Guardians (not Pets): no PetFrame, nameplate tag is "<Player's Guardian>".
-- Creature name is the type ("Ghoul", "Abomination"); ownership uses tooltip/plate text/CLEU — never UnitPlayerControlled alone.

function Advisor:EnsureOwnershipTooltip()
    if self.ownershipTip then
        return self.ownershipTip
    end
    local tip = CreateFrame("GameTooltip", "MancerOwnershipTooltip", UIParent, "GameTooltipTemplate")
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:Hide()
    self.ownershipTip = tip
    return tip
end

-- Ascension subtitle is "<Player>'s Guardian" (ASCII or curly apostrophe).
local function OwnershipTextSaysMine(text, playerName)
    if not text or type(text) ~= "string" or not playerName or playerName == "" then
        return false
    end
    local needles = {
        playerName .. "'s",
        playerName .. "\226\128\153s", -- ’
    }
    local hasOwner = false
    for i = 1, #needles do
        if text:find(needles[i], 1, true) then
            hasOwner = true
            break
        end
    end
    if not hasOwner then
        return false
    end
    -- Require ownership phrasing so a bare player-name hit on unrelated plate UI does not match.
    if text:find("Guardian", 1, true)
        or text:find("Minion", 1, true)
        or text:find("Pet", 1, true)
        or text:find("Undead", 1, true) then
        return true
    end
    -- Short subtitle line that is only the owner tag.
    return #text <= (#playerName + 18)
end

-- Tooltip / nameplate subtitle ownership: "Mortuus's Guardian".
function Advisor:UnitOwnershipTextSaysMine(unit)
    if not unit then
        return false
    end
    local playerName = UnitName and UnitName("player")
    if not playerName or playerName == "" then
        return false
    end

    local tip = self:EnsureOwnershipTooltip()
    tip:ClearLines()
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    local ok = pcall(function()
        tip:SetUnit(unit)
    end)
    if ok then
        local lines = tip:NumLines() or 0
        for i = 1, lines do
            local fs = _G["MancerOwnershipTooltipTextLeft" .. i]
            local text = fs and fs:GetText()
            if OwnershipTextSaysMine(text, playerName) then
                tip:Hide()
                return true
            end
        end
    end
    tip:Hide()
    return false
end

-- Only FontStrings — do not walk unrelated child frames (party markers, Plater widgets, etc.).
local function RegionTreeHasOwnershipText(frame, playerName, depth)
    if not frame or not playerName or (depth or 0) > 5 then
        return false
    end
    if frame.GetText then
        local ok, text = pcall(frame.GetText, frame)
        if ok and OwnershipTextSaysMine(text, playerName) then
            return true
        end
    end
    if frame.GetRegions then
        local regions = { frame:GetRegions() }
        for i = 1, #regions do
            if RegionTreeHasOwnershipText(regions[i], playerName, (depth or 0) + 1) then
                return true
            end
        end
    end
    if frame.GetChildren then
        local children = { frame:GetChildren() }
        for i = 1, #children do
            if RegionTreeHasOwnershipText(children[i], playerName, (depth or 0) + 1) then
                return true
            end
        end
    end
    return false
end

function Advisor:GetNamePlateFrameForUnit(unit)
    if not unit then
        return nil
    end
    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
        if ok and plate then
            return plate
        end
    end
    local wantGuid = UnitGUID and UnitGUID(unit)
    local plates = SafeGetNamePlates and SafeGetNamePlates()
    if plates then
        for _, plate in ipairs(plates) do
            local token = plate.namePlateUnitToken or plate.unitToken or plate.unit
            if token == unit then
                return plate
            end
            if wantGuid and token and UnitGUID and GuidsMatch(UnitGUID(token), wantGuid) then
                return plate
            end
        end
    end
    return nil
end

-- Ascension friendly plates show "<Player>'s Guardian" on the plate UI (not in UnitName).
function Advisor:NameplateOwnershipTextSaysMine(unit)
    local playerName = UnitName and UnitName("player")
    if not playerName or playerName == "" then
        return false
    end
    local plate = self:GetNamePlateFrameForUnit(unit)
    if plate and RegionTreeHasOwnershipText(plate, playerName, 0) then
        return true
    end
    -- nameplateN token: also try the global frame if present.
    if type(unit) == "string" and unit:find("^nameplate", 1) then
        local frame = _G[unit]
        if frame and RegionTreeHasOwnershipText(frame, playerName, 0) then
            return true
        end
    end
    return false
end

-- True only for THIS player's undead.
-- Never use UnitPlayerControlled / UnitIsOwnerOrControllerOfUnit alone — on Ascension those
-- return true for nearby necros' guardians as well.
function Advisor:IsOwnedByPlayer(unit, name)
    if not unit or (UnitIsUnit and UnitIsUnit(unit, "player")) then
        return false
    end

    if UnitIsUnit and UnitIsUnit(unit, "pet") then
        return true
    end

    name = name or (UnitName and UnitName(unit))
    local playerName = UnitName and UnitName("player")
    if playerName and name and OwnershipTextSaysMine(name, playerName) then
        return true
    end

    if self:UnitOwnershipTextSaysMine(unit) then
        return true
    end

    if self:NameplateOwnershipTextSaysMine(unit) then
        return true
    end

    local guid = UnitGUID and UnitGUID(unit)
    if guid then
        local _, info = self:FindActiveSummon(guid)
        -- Only CLEU / cast seeds are trusted. Visible/nameplate seeds must re-prove ownership above.
        if info and self:IsTrustedSummonSource(info.source) then
            return true
        end
    end

    return false
end

function Advisor:IsOwnedGuardianUnit(unit, name, minionId)
    if not unit or UnitIsUnit(unit, "player") then
        return false
    end

    if UnitIsDead and UnitExists and UnitExists(unit) and UnitIsDead(unit) then
        return false
    end

    if UnitIsPlayer and UnitIsPlayer(unit) then
        return false
    end

    name = name or (UnitName and UnitName(unit))
    if not name or name == "" then
        return false
    end

    local classified = self:ClassifyMinionName(name)
    if not classified then
        return false
    end
    if minionId and classified ~= minionId then
        return false
    end

    if UnitIsEnemy and UnitIsEnemy("player", unit) then
        return false
    end

    return self:IsOwnedByPlayer(unit, name)
end

function Advisor:IsGhoulGuardianUnit(unit, name)
    return self:IsOwnedGuardianUnit(unit, name, "ghoul")
end

function Advisor:IsPlayerMinionUnit(unit)
    if not unit then
        return false
    end

    -- Ascension nameplates: UnitName works while UnitExists is false until targeted.
    if UnitExists and not UnitExists(unit) then
        local probe = UnitName and UnitName(unit)
        if not probe or probe == "" then
            return false
        end
    end

    if UnitIsDead and UnitIsDead(unit) then
    return false
    end

    if UnitIsUnit(unit, "player") then
        return false
    end

    if UnitIsPlayer and UnitIsPlayer(unit) then
        return false
    end

    if UnitIsEnemy and UnitIsEnemy("player", unit) then
        return false
    end

    local name = UnitName and UnitName(unit)
    if not name or name == "" then
        return false
    end

    local minionId = self:ClassifyMinionName(name)
    if not minionId then
        return false
    end

    return self:IsOwnedGuardianUnit(unit, name, minionId)
end

function Advisor:ClassifyMinionName(name)
    if not name then
        return nil
    end

    local function matchesMinionId(minionId)
        local def = self.MINION_TYPES[minionId]
        if not def then
            return false
        end
        if NameMatches(name, def.namePatterns) then
            return true
        end
        return NameMatches(name, self:GetDynamicNamePatterns(minionId))
    end

    for _, minionId in ipairs(self.MINION_CLASSIFY_ORDER) do
        if matchesMinionId(minionId) then
            return minionId, name
        end
    end

    local playerName = UnitName("player")
    if playerName and name:find(playerName, 1, true) then
        for _, minionId in ipairs(self.MINION_CLASSIFY_ORDER) do
            if minionId ~= "ghoul" and self:HasMinionTalent(minionId) and matchesMinionId(minionId) then
                    return minionId, name
            end
        end
        if self:HasMinionTalent("ghoul") then
            return "ghoul", name
        end
    end

    return nil
end

function Advisor:ClassifyBySpellId(spellId)
    if not spellId then
        return nil
    end

    local function matches(def)
        return def and def.summonSpellIds and def.summonSpellIds[spellId]
    end

    for _, minionId in ipairs(self.MINION_CLASSIFY_ORDER) do
        if matches(self.MINION_TYPES[minionId]) then
            return minionId
        end
    end

    for minionId, def in pairs(self.MINION_TYPES) do
        if matches(def) then
            return minionId
        end
    end

    return nil
end

function Advisor:CollectMinionSpellIds(minionId)
    local def = self.MINION_TYPES[minionId]
    if not def then
        return {}
    end

    local spells = {}
    local seen = {}

    local function normalizeSpellId(spellId)
        local id = tonumber(spellId)
        if not id or id <= 0 then
            return nil
        end
        return id
    end

    local function add(entry)
        local id = normalizeSpellId(entry.id)
        if id then
            if seen[id] then
                return
            end
            seen[id] = true
            entry.id = id
        elseif not entry.name then
            return
        end
        table.insert(spells, entry)
    end

    if def.summonSpellIds then
        for spellId in pairs(def.summonSpellIds) do
            add({ id = spellId, role = "summon" })
        end
    end
    if def.buffSpellIds then
        for spellId in pairs(def.buffSpellIds) do
            add({ id = spellId, role = "buff" })
        end
    end
    if def.alertSpellId then
        add({ id = def.alertSpellId, role = "alert" })
    end
    if def.damageSpellIds then
        for spellId in pairs(def.damageSpellIds) do
            add({ id = spellId, role = "damage" })
        end
    end

    for spellName, mappedId in pairs(self.MINION_DAMAGE_SPELLS or {}) do
        if mappedId == minionId then
            add({ name = spellName, role = "damage" })
        end
    end

    table.sort(spells, function(a, b)
        if a.id and b.id then
            return a.id < b.id
        end
        if a.id then
            return true
        end
        return (a.name or "") < (b.name or "")
    end)

    return spells
end

function Advisor:NormalizeSpellName(spellName)
    if not spellName then
        return nil
    end
    local name = spellName:gsub(" %(Rank %d+%)$", "")
    name = name:gsub(" %d+$", "")
    return name
end

function Advisor:IsPlayerDamageSpell(spellName, spellId)
    if not spellName then
        return false
    end

    if self.PLAYER_DAMAGE_SPELLS[spellName] then
        return true
    end

    local normalized = self:NormalizeSpellName(spellName)
    if normalized and self.PLAYER_DAMAGE_SPELLS[normalized] then
        return true
    end

    if normalized then
        local lower = string.lower(normalized)
        for name in pairs(self.PLAYER_DAMAGE_SPELLS) do
            if string.lower(name) == lower then
                return true
            end
        end
    end

    return false
end

function Advisor:ClassifyMinionDamageSpell(spellName, spellId)
    if self:IsPlayerDamageSpell(spellName, spellId) then
        return nil
    end
    if spellId then
        for minionId, def in pairs(self.MINION_TYPES) do
            if def.damageSpellIds and def.damageSpellIds[spellId] then
                return minionId
            end
        end
    end
    if spellName then
        local mapped = self.MINION_DAMAGE_SPELLS[spellName]
        if mapped then
            return mapped
        end
        local lower = string.lower(spellName)
        for name, minionId in pairs(self.MINION_DAMAGE_SPELLS) do
            if string.lower(name) == lower then
                return minionId
            end
        end
    end
    return nil
end

function Advisor:ClassifyMinionTalentSpell(spellName)
    if not spellName then
        return nil
    end

    for _, minionId in ipairs(self.MINION_CLASSIFY_ORDER) do
        local def = self.MINION_TYPES[minionId]
        if def and def.talentPatterns then
            for _, pattern in ipairs(def.talentPatterns) do
                if spellName:find(pattern, 1, true) then
                    return minionId
                end
            end
        end
        if def and def.spellNames then
            for _, pattern in ipairs(def.spellNames) do
                if spellName:find(pattern, 1, true) then
                    return minionId
                end
            end
        end
    end

    return nil
end

function Advisor:IsMinionSummonSpell(spellName, spellId)
    if spellName and self.MINION_TOOLTIP_EXCLUDE_SPELLS[spellName] then
        return false
    end

    if spellId and self:ClassifyBySpellId(spellId) then
        return true
    end

    if not spellName then
        return false
    end

    if spellName:find("^Raise:", 1) or spellName:find("^Animate:", 1) then
        return true
    end

    for _, minionId in ipairs(self.MINION_CLASSIFY_ORDER) do
        local def = self.MINION_TYPES[minionId]
        if def and def.spellNames then
            for _, pattern in ipairs(def.spellNames) do
                if spellName == pattern or spellName:find(pattern, 1, true) then
                    return true
                end
            end
        end
    end

    return false
end

function Advisor:ClassifyMinionSummonSpell(spellName, spellId)
    if not self:IsMinionSummonSpell(spellName, spellId) then
        return nil
    end

    if spellName then
        for _, minionId in ipairs(self.MINION_CLASSIFY_ORDER) do
            local def = self.MINION_TYPES[minionId]
            if def and def.talentPatterns then
                for _, pattern in ipairs(def.talentPatterns) do
                    if pattern:find("^Raise:", 1) or pattern:find("^Animate:", 1) then
                        if spellName:find(pattern, 1, true) then
                            return minionId
                        end
                    end
                end
            end
            if def and def.spellNames then
                for _, pattern in ipairs(def.spellNames) do
                    if spellName:find(pattern, 1, true) then
                        return minionId
                    end
                end
            end
        end
    end

    if spellId then
        local fromId = self:ClassifyBySpellId(spellId)
        if fromId then
            return fromId
        end
    end

    return nil
end

function Advisor:RefreshTemporaryMinion(minionId, unit, name)
    local def = self.MINION_TYPES[minionId]
    if not def or def.trackMode ~= "temporary" or not def.duration then
        return
    end

    local now = GetTime and GetTime() or 0
    local duration = self.GetTemporaryDuration and self:GetTemporaryDuration(minionId) or def.duration
    local expiresAt = now + duration
    self.temporaryActive = self.temporaryActive or {}
    if (self.temporaryActive[minionId] or 0) < expiresAt then
        self.temporaryActive[minionId] = expiresAt
    end

    if unit and UnitGUID(unit) then
        self:RecordSummon(UnitGUID(unit), name or def.label, minionId, nil, "unit")
    end
end

function Advisor:IsOwnedTemporaryMinion(unit, name)
    if UnitIsUnit(unit, "pet") then
        return true
    end

    if UnitIsEnemy and UnitIsEnemy("player", unit) then
        return false
    end

    return self:IsOwnedByPlayer(unit, name)
end

function Advisor:HandlePlayerSpellCast(unit, spellName, spellId)
    if unit ~= "player" and (not UnitIsUnit or not UnitIsUnit(unit, "player")) then
        return
    end

    spellId = tonumber(spellId)
    local isTemp, minionId = self:IsTemporarySummonCast(spellId, spellName)
    if isTemp and minionId then
        self:MarkTemporaryCast(minionId)
    elseif self:IsGhoulSummonSpell(spellId, spellName) then
        self:OnGhoulSummoned()
    end

    if spellId and self.UNDEAD_STANCE_SPELL_LOOKUP[spellId] then
        self:NoteStanceAuraEvent(spellId, spellName, true)
    else
        local stanceId = select(1, self:ClassifyUndeadStance(spellName, spellId))
        if stanceId then
            self:NoteStanceAuraEvent(spellId, spellName, true)
        end
    end
end

function Advisor:ScanTemporaryUnitToken(unit)
    if not unit or not UnitExists(unit) or UnitIsDead(unit) or UnitIsUnit(unit, "player") then
        return nil
    end

    local name = UnitName(unit)
    if not name then
        return nil
    end

    local minionId = self:ClassifyMinionName(name)
    if not minionId or not self:UsesTemporaryTracking(minionId) then
        return nil
    end

    if not self:IsOwnedTemporaryMinion(unit, name) then
        return nil
    end

    return minionId, name
end

function Advisor:ScanTemporaryMinions()
    self:SyncTemporaryFromSpellCooldownsIfNeeded()

    local counts = {}
    local seen = { _guids = {} }
    local now = GetTime and GetTime() or 0

    if self.temporaryActive then
        for minionId, expiresAt in pairs(self.temporaryActive) do
            if expiresAt <= now then
                self.temporaryActive[minionId] = nil
            elseif self:HasMinionTalent(minionId) then
                counts[minionId] = 1
                seen[minionId] = seen[minionId] or {}
                table.insert(seen[minionId], {
                    name = self.MINION_TYPES[minionId].label,
                    unit = "player",
                    source = string.format("timer (%.0fs left)", expiresAt - now),
                })
            end
        end
    end

    for _, unit in ipairs(self:GetLightweightTempScanUnits()) do
        if UnitExists(unit) then
            local minionId, name = self:ScanTemporaryUnitToken(unit)
            if minionId then
                self:RefreshTemporaryMinion(minionId, unit, name)
                self:NoteMinion(counts, seen, minionId, name, unit, "unit")
            end
        end
    end

    if self.activeSummons then
        for guid, info in pairs(self.activeSummons) do
            if info and info.minionId and self:UsesTemporaryTracking(info.minionId) then
                if info.expiresAt and info.expiresAt <= now then
                    self.activeSummons[guid] = nil
                else
                    self:NoteMinion(counts, seen, info.minionId, info.name, nil, "combatlog", guid)
                end
            end
        end
    end

    for minionId, amount in pairs(counts) do
        counts[minionId] = math.min(amount, self:GetMinionScanCap(minionId))
    end

    seen._guids = nil
    return counts, seen
end

function Advisor:ScanPhysicalBuffMinions()
    local counts = {}
    local seen = { _guids = {} }
    local now = GetTime and GetTime() or 0

    self:SeedSummonsFromVisibleUnits()

    local function trackPhysical(minionId, name, unit, source, guid)
        if not minionId then
            return
        end
        local unitGuid = guid or (unit and UnitGUID(unit))
        if unitGuid then
            self:RecordSummon(unitGuid, name or (self.MINION_TYPES[minionId] and self.MINION_TYPES[minionId].label) or minionId, minionId, nil, source or "unit")
        end
        self:NoteMinion(counts, seen, minionId, name, unit, source, guid)
    end

    for _, unit in ipairs(self:GetCachedScanUnits()) do
        local minionId, name = self:ScanUnitToken(unit)
        if minionId then
            trackPhysical(minionId, name, unit, "unit")
        end
    end

    -- Nameplates often absent from cached scan when UnitExists is false — count them directly.
    for i = 1, 40 do
        local unit = "nameplate" .. i
        local minionId, name = self:ScanUnitToken(unit)
        if minionId then
            trackPhysical(minionId, name, unit, "nameplate")
        end
    end

    if self.activeSummons then
        for guid, info in pairs(self.activeSummons) do
            if info and info.minionId and self:IsTrustedSummonSource(info.source) then
                if not info.expiresAt or info.expiresAt > now then
                    trackPhysical(info.minionId, info.name, nil, info.source or "tracked", guid)
                end
            end
        end
    end

    for minionId, amount in pairs(counts) do
        counts[minionId] = math.min(amount, self:GetMinionScanCap(minionId))
    end

    seen._guids = nil
    return counts, seen
end

function Advisor:ScanUnitToken(unit)
    if not unit or UnitIsUnit(unit, "player") then
        return nil
    end

    if UnitIsDead and UnitExists and UnitExists(unit) and UnitIsDead(unit) then
        return nil
    end

    local name = UnitName and UnitName(unit)
    if not name or name == "" then
        return nil
    end

    local minionId = self:ClassifyMinionName(name)
    if not minionId then
        return nil
    end

    if self:IsOwnedGuardianUnit(unit, name, minionId) then
        return minionId, name
    end

    return nil
end

function Advisor:GetMinionSheetOrder()
    local order = {}
    for i = #self.MINION_CLASSIFY_ORDER, 1, -1 do
        order[#order + 1] = self.MINION_CLASSIFY_ORDER[i]
    end
    return order
end

-- One representative unit per active minion type (pet-screen style: Ghoul ×3 still shows one Ghoul slot).
function Advisor:GetMinionTypeRoster()
    local now = GetTime and GetTime() or 0
    local counts
    if self.minionSnapshot and self.minionSnapshot.counts and now < (self.minionSnapshot.expiresAt or 0) then
        counts = self.minionSnapshot.counts
    else
        counts = self:CollectActiveMinions(true)
    end
    local roster = {}

    for _, minionId in ipairs(self:GetMinionSheetOrder()) do
        local count = counts[minionId]
        if count and count > 0 then
            local def = self.MINION_TYPES[minionId]
            local unit, guid, name = self:GetRepresentativeUnitForMinion(minionId)
            roster[#roster + 1] = {
                minionId = minionId,
                label = def and def.label or minionId,
                count = count,
                unit = unit,
                guid = guid,
                name = name,
            }
        end
    end
    return roster
end

function Advisor:NoteMinion(counts, seen, minionId, name, unit, source, guid)
    if not minionId then
        return
    end

    guid = guid or (unit and UnitGUID(unit))
    if guid then
        seen._guids = seen._guids or {}
        if seen._guids[guid] then
            return
        end
        seen._guids[guid] = true
    end

    counts[minionId] = (counts[minionId] or 0) + 1
    seen[minionId] = seen[minionId] or {}
    table.insert(seen[minionId], {
        name = name or "?",
        unit = unit or source or "?",
        source = source or "scan",
    })
end

function Advisor:CollectActiveMinions(force)
    -- Throttled nameplate GUID seed (force=true for Sheet Refresh / manual dump).
    self:SeedSummonsFromVisibleUnits(force == true)

    local now = GetTime and GetTime() or 0
    local summonGhoul = self:CountActiveSummonsByMinion("ghoul")
    local visibleGhoul = self:CountVisibleGhoulUnits()
    if self.minionSnapshot and force ~= true then
        local snapUntil = self.minionSnapshot.expiresAt or 0
        local snapGhoul = self.minionSnapshot.counts and self.minionSnapshot.counts.ghoul or 0
        if now < snapUntil then
            if visibleGhoul > 0 then
                -- Live plates changed (or first sighted) — don't keep a higher sticky ×N.
                if visibleGhoul ~= snapGhoul then
                    self.minionSnapshot = nil
                else
                    return self.minionSnapshot.counts, self.minionSnapshot.seen
                end
            elseif summonGhoul == snapGhoul then
                return self.minionSnapshot.counts, self.minionSnapshot.seen
            else
                self.minionSnapshot = nil
            end
        end
    end

    local counts = {}
    local seen = {}

    local auraCounts, auraSeen = self:GetCachedAuraCounts()
    for minionId, amount in pairs(auraCounts) do
        counts[minionId] = amount
        seen[minionId] = auraSeen[minionId] or {}
    end

    local tempCounts, tempSeen = self:ScanTemporaryMinions()
    for minionId, amount in pairs(tempCounts) do
        if amount > (counts[minionId] or 0) then
            counts[minionId] = amount
        end
        seen[minionId] = tempSeen[minionId] or seen[minionId] or {}
    end

    local unitCounts, unitSeen = self:ScanPhysicalBuffMinions()
    for minionId, amount in pairs(unitCounts) do
        if amount > (counts[minionId] or 0) then
            counts[minionId] = amount
        end
        if unitSeen[minionId] then
            seen[minionId] = unitSeen[minionId]
        end
    end

    -- Apply unique-GUID / nameplate counts for every raised type, not just aura stacks.
    for minionId in pairs(self.MINION_TYPES) do
        if self:UsesBuffTracking(minionId) then
            local visible = self:CountVisibleMinionUnits(minionId)
            local summons = self:CountActiveSummonsByMinion(minionId)
            local aura = counts[minionId] or 0
            local merged
            if visible > 0 then
                merged = visible
            else
                local cap = self:GetMinionScanCap(minionId)
                merged = math.min(math.max(aura, summons), cap)
            end
            if merged > 0 then
                counts[minionId] = merged
            elseif counts[minionId] then
                counts[minionId] = nil
            end
        end
    end

    self:MergeGhoulActiveCount(counts)

    self.minionSnapshot = {
        counts = counts,
        seen = seen,
        expiresAt = now + MINION_SNAPSHOT_TTL,
    }
    return counts, seen
end

function Advisor:GetMissingMinions()
    local counts = self:CollectActiveMinions()
    local missing = {}

    for _, req in ipairs(self:GetRequiredMinions()) do
        if self:IsMinionOnCooldown(req.id) then
            -- temporary minion on cooldown — don't nag
        else
        local active = counts[req.id] or 0
            local want = self:GetMinionMax(req.id)
            if active < want then
            table.insert(missing, {
                id = req.id,
                label = req.label,
                    needed = want - active,
                have = active,
                    want = want,
            })
            end
        end
    end

    return missing
end

function Advisor:GetSpellTooltipDurationSeconds(spellId)
    spellId = tonumber(spellId)
    if not spellId or spellId <= 0 then
        return nil
    end

    self._spellDurCache = self._spellDurCache or {}
    local now = GetTime and GetTime() or 0
    local cached = self._spellDurCache[spellId]
    if cached and (now - (cached.t or 0)) < 8 then
        return cached.v
    end

    local desc
    if C_Spell and C_Spell.GetSpellDescription then
        local ok, result = pcall(C_Spell.GetSpellDescription, spellId)
        if ok then
            desc = result
        end
    end
    if (not desc or desc == "") and GetSpellDescription then
        local ok, result = pcall(GetSpellDescription, spellId)
        if ok then
            desc = result
        end
    end

    local secs
    if type(desc) == "string" and desc ~= "" then
        -- Prefer "for 18 sec" (pet lifetime), not the "24 sec cooldown" header.
        secs = tonumber(desc:match("[Ff]or%s+(%d+%.?%d*)%s*[Ss]ec"))
        if not secs then
            secs = tonumber(desc:match("[Ff]or%s+(%d+%.?%d*)%s*[Ss]econds?"))
        end
    end

    if secs and (secs <= 0 or secs >= 600) then
        secs = nil
    end

    self._spellDurCache[spellId] = { t = now, v = secs }
    return secs
end

function Advisor:GetTemporaryDuration(minionId)
    local def = self.MINION_TYPES[minionId]
    if not def then
        return 0
    end

    -- Live tip text already includes Summoning Prodigy / other duration talents.
    local spellIds = {}
    if def.alertSpellId then
        table.insert(spellIds, def.alertSpellId)
    end
    if type(def.summonSpellIds) == "table" then
        for sid in pairs(def.summonSpellIds) do
            table.insert(spellIds, sid)
        end
    end
    for i = 1, #spellIds do
        local secs = self:GetSpellTooltipDurationSeconds(spellIds[i])
        if secs and secs > 0 then
            return secs
        end
    end

    local duration = tonumber(def.duration) or 0
    if duration <= 0 then
        return 0
    end
    -- Fallback only: Summoning Prodigy (704682) +3s Skeletal Archer (DBC bp 2999ms).
    if minionId == "skeletal_archer" then
        local hasProdigy = false
        if Ascension.HasActiveTalentSpell and Ascension.HasActiveTalentSpell(704682) then
            hasProdigy = true
        elseif Ascension.HasTalentSpell and Ascension.HasTalentSpell(704682) then
            hasProdigy = true
        elseif Ascension.GetTalentRankBySpell and Ascension.GetTalentRankBySpell(704682) > 0 then
            hasProdigy = true
        end
        if hasProdigy then
            duration = duration + 3
        end
    end
    return duration
end

function Advisor:GetAnimateActiveRemaining(minionId)
    if not minionId then
        return nil
    end
    local now = GetTime and GetTime() or 0
    self.temporaryActive = self.temporaryActive or {}
    local activeUntil = self.temporaryActive[minionId]
    if not activeUntil then
        return nil
    end
    if now >= activeUntil then
        self.temporaryActive[minionId] = nil
        return nil
    end
    return activeUntil - now
end

function Advisor:IsTempIconAlert(minionId)
    return self.TEMP_ICON_ALERT_MINIONS[minionId] == true
end

function Advisor:IsAnimateReadyMinion(minionId)
    return self.ANIMATE_READY_MINIONS[minionId] == true
end

function Advisor:IsAnimateTemporarilyActive(minionId)
    if not minionId then
        return false
    end

    local now = GetTime and GetTime() or 0
    self.temporaryActive = self.temporaryActive or {}
    local activeUntil = self.temporaryActive[minionId]
    if activeUntil then
        if now < activeUntil then
            return true
        end
        self.temporaryActive[minionId] = nil
    end

    -- Fallback when CLEU/spell CD tracking missed the cast.
    local visible = self.CountVisibleMinionUnits and self:CountVisibleMinionUnits(minionId) or 0
    if visible > 0 then
        return true
    end
    local summons = self.CountActiveSummonsByMinion and self:CountActiveSummonsByMinion(minionId) or 0
    return summons > 0
end

-- A-strip only: your cast window — ignore other players' Animates / sticky summons.
function Advisor:IsAnimateCastWindowActive(minionId)
    if not minionId then
            return false
        end

    local now = GetTime and GetTime() or 0
    self.temporaryActive = self.temporaryActive or {}
    local activeUntil = self.temporaryActive[minionId]
    if not activeUntil then
        return false
    end
    if now >= activeUntil then
        self.temporaryActive[minionId] = nil
        return false
    end
    return true
end

local function IsAnimateTalentName(name)
    return type(name) == "string" and name:find("^Animate:", 1, true) ~= nil
end

local function IsRaiseTalentName(name)
    return type(name) == "string" and name:find("^Raise:", 1, true) ~= nil
end

-- Learned Animate:… spells from the spellbook only (not DBC / IsKnownSpellID).
-- CA GetKnownTalentEntries can lag a tick behind learning; the book updates on SPELLS_CHANGED.
function Advisor:GetLearnedAnimateSpellNames()
    if self.animateSpellbookCache ~= nil then
        return self.animateSpellbookCache
    end

    local names = {}
    local seen = {}
    if GetNumSpellTabs and GetSpellTabInfo and GetSpellName then
        local bookType = BOOKTYPE_SPELL or "spell"
        local tabs = GetNumSpellTabs() or 0
        for tab = 1, tabs do
            local _, _, offset, numSpells = GetSpellTabInfo(tab)
            offset = offset or 0
            numSpells = numSpells or 0
            for i = offset + 1, offset + numSpells do
                local name = GetSpellName(i, bookType)
                if IsAnimateTalentName(name) then
                    local key = NormalizeTalentMatch(name)
                    if not seen[key] then
                        seen[key] = true
                        table.insert(names, name)
                    end
                end
            end
        end
    end

    self.animateSpellbookCache = names
    return names
end

-- Prefer spent CA talent ranks (GetTalentRankBySpell > 0). IsKnownSpellID false-positives
-- unlearned Animates; name-only matching fails because CA renames nodes
-- (Putrid Ghoul = Archer, Knight of Decay = Bone Wraith).
function Advisor:ResolveAnimateStripSpellId(minionId)
    local canonical = self:GetCanonicalAnimateSpellId(minionId)
    if not canonical or not Ascension.HasActiveTalentSpell then
        return nil
    end

    -- Canonical castable ID wins when the rank is spent.
    if Ascension.HasActiveTalentSpell(canonical) then
        return canonical
    end

    local def = self.MINION_TYPES[minionId]
    if not def then
        return nil
    end

    local seen = { [canonical] = true }
    local function consider(spellId)
        spellId = tonumber(spellId)
        if not spellId or spellId <= 0 or seen[spellId] then
            return nil
        end
        seen[spellId] = true
        if Ascension.HasActiveTalentSpell(spellId) then
            return spellId
        end
        return nil
    end

    -- Only cooldown / alert IDs — never roam summon sibling tables for strip ownership.
    local hit = consider(def.alertSpellId)
    if hit then
        return hit
    end
    if def.cooldownSpellIds then
        for id in pairs(def.cooldownSpellIds) do
            hit = consider(id)
            if hit then
                return hit
            end
        end
    end
    return nil
end

-- Animate strip: ONLY Animates you have taken.
function Advisor:ResolveAnimateStripBinding(minionId)
    local def = self.MINION_TYPES[minionId]
    if not def or not self:IsAnimateReadyMinion(minionId) then
        return nil
    end

    local canonical = self:GetCanonicalAnimateSpellId(minionId)

    local patterns = {}
    for _, pattern in ipairs(def.talentPatterns or {}) do
        if IsAnimateTalentName(pattern) or (minionId == "frost_wyrm" and pattern == "Shatterfrost") then
            table.insert(patterns, pattern)
        end
    end
    for _, pattern in ipairs(def.spellNames or {}) do
        if IsAnimateTalentName(pattern) or (minionId == "frost_wyrm" and pattern == "Shatterfrost") then
            table.insert(patterns, pattern)
        end
    end

    local function bindingFrom(name, talent, pattern, spellId)
        return {
            name = name,
            pattern = pattern or name,
            caId = talent and talent.id,
            icon = talent and talent.icon,
            -- Always pin the strip spell id so CD never follows a name lookup.
            spellId = tonumber(spellId) or canonical,
        }
    end

    -- 1) Spent talent rank on this Animate's spell ID (authoritative on Ascension).
    local learnedSpellId = self:ResolveAnimateStripSpellId(minionId)
    if learnedSpellId then
        local spellName = GetSpellInfo and GetSpellInfo(learnedSpellId)
        if not spellName or spellName == "" then
            spellName = patterns[1] or def.label
        end
        return bindingFrom(spellName, nil, patterns[1] or spellName, learnedSpellId)
    end

    -- 2) CA known-entry names (handles Knight of Decay / Putrid Ghoul aliases).
    for _, talent in pairs(Ascension.GetKnownTalents() or {}) do
        local name = talent and talent.name
        if not name or IsRaiseTalentName(name) then
            -- skip
        elseif IsAnimateTalentName(name) and self:MapTalentNameToMinionId(name) == minionId then
            return bindingFrom(name, talent, name, canonical)
        else
            local asAnimate = "Animate: " .. name
            if self:MapTalentNameToMinionId(asAnimate) == minionId then
                return bindingFrom(asAnimate, talent, asAnimate, canonical)
            end
            if minionId == "frost_wyrm" and NormalizeTalentMatch(name) == "shatterfrost" then
                return bindingFrom(name, talent, "Shatterfrost", canonical)
            end
            local lowerName = NormalizeTalentMatch(name)
            for _, pattern in ipairs(patterns) do
                local creature = pattern:match("^Animate:%s*(.+)$") or pattern
                if lowerName == NormalizeTalentMatch(pattern) or lowerName == NormalizeTalentMatch(creature) then
                    return bindingFrom(pattern, talent, pattern, canonical)
                end
            end
        end
    end

    -- 3) Spellbook fallback (Animate:… entries only).
    for _, name in ipairs(self:GetLearnedAnimateSpellNames()) do
        if self:MapTalentNameToMinionId(name) == minionId then
            return bindingFrom(name, nil, name, canonical)
        end
    end

    return nil
end

function Advisor:HasAnimateStripTalent(minionId)
    return self:ResolveAnimateStripBinding(minionId) ~= nil
end

function Advisor:BuildAnimateStripBinding(minionId)
    return self:ResolveAnimateStripBinding(minionId)
end

-- Cooldown for ONE Animate only — numeric spell ID, never GetSpellCooldown(name).
-- Remaining is always recomputed from start+duration (WeakAuras-style); never cache a frozen remaining.
function Advisor:GetAnimateSpellCooldown(minionId, binding)
    local now = GetTime and GetTime() or 0
    local cacheKey = "anim:" .. tostring(minionId)
    if self.spellCdCache and self.spellCdCache[cacheKey] and now < self.spellCdCache[cacheKey].expiresAt then
        return CachedCooldownResult(self.spellCdCache[cacheKey], now)
    end

    binding = binding or self:ResolveAnimateStripBinding(minionId)
    local spellId = tonumber(binding and binding.spellId) or self:GetCanonicalAnimateSpellId(minionId)
    if not spellId or spellId <= 0 then
        self.spellCdCache = self.spellCdCache or {}
        self.spellCdCache[cacheKey] = {
            start = nil,
            duration = nil,
            expiresAt = now + SPELL_CD_SYNC_INTERVAL,
        }
        return nil
    end

    local start, duration = QuerySpellCooldownBySpellId(spellId)
    local remaining = RemainingFromCooldown(start, duration, now)
    local bestStart, bestDuration, bestRemaining
    if remaining then
        bestStart = start
        bestDuration = duration
        bestRemaining = remaining
    end

    self.spellCdCache = self.spellCdCache or {}
    self.spellCdCache[cacheKey] = {
        start = bestStart,
        duration = bestDuration,
        expiresAt = now + SPELL_CD_SYNC_INTERVAL,
    }

    if not bestRemaining then
        return nil
    end
    return bestStart, bestDuration, bestRemaining
end

function Advisor:GetAnimateAlertIcon(minionId, binding)
    binding = binding or self:ResolveAnimateStripBinding(minionId)
    local def = self.MINION_TYPES[minionId]
    if not def then
        return nil, nil
    end

    local function usableTexture(tex)
        if tex == nil then
            return nil
        end
        if type(tex) == "string" then
            if tex == "" or tex == "?" then
                return nil
            end
            return tex
        end
        -- Ascension CA icons are often numeric fileIDs; Wrath SetTexture needs a path string.
        if type(tex) == "number" then
            return nil
        end
        return nil
    end

    local function iconFromSpellId(spellId)
        spellId = tonumber(spellId)
        if not spellId or spellId <= 0 then
            return nil, nil
        end
        local texture
        if GetSpellTexture then
            texture = usableTexture(GetSpellTexture(spellId))
        end
        if not texture and GetSpellInfo then
            texture = usableTexture(select(3, GetSpellInfo(spellId)))
        end
        return spellId, texture
    end

    local function iconFromSpellName(spellName)
        if not spellName or spellName == "" or not GetSpellInfo then
            return nil, nil
        end
        local texture = usableTexture(select(3, GetSpellInfo(spellName)))
        if texture then
            return nil, texture
        end
        return nil, nil
    end

    local spellId = binding and binding.spellId or self:GetCanonicalAnimateSpellId(minionId)
    local texture

    -- Pin art to the canonical strip spell first (stable across CA aliases).
    if spellId then
        local id, tex = iconFromSpellId(spellId)
        spellId = id or spellId
        texture = tex
    end

    if not texture and binding and binding.name then
        local _, tex = iconFromSpellName(binding.name)
        texture = tex or texture
    end

    if not texture and binding and binding.pattern then
        local _, tex = iconFromSpellName(binding.pattern)
        texture = tex or texture
    end

    if not texture and def.alertSpellId then
        local id, tex = iconFromSpellId(def.alertSpellId)
        spellId = spellId or id
        texture = tex or texture
    end

    if not texture and def.spellNames then
        for _, spellName in ipairs(def.spellNames) do
            if IsAnimateTalentName(spellName) or spellName == "Shatterfrost" then
                local _, tex = iconFromSpellName(spellName)
                if tex then
                    texture = tex
                    break
                end
            end
        end
    end

    -- CA icon path strings only (never raw fileIDs — those blank out on 3.3.5).
    if not texture and binding then
        texture = usableTexture(binding.icon)
    end

    if not texture then
        texture = "Interface\\Icons\\Spell_Shadow_AnimateDead"
    end

    return spellId, texture
end

-- Player procs that deserve a dedicated HUD strip (duration + stacks).
-- Bone King: user ID 707176; tips/CA also reference 707175 — accept both.
-- Frost Runes: talent/ability 705750; live buff aura reported as 705751.
Advisor.PROC_AURAS = {
    {
        id = "diabolical",
        label = "Diabolical",
        spellIds = { 707133 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_ShadowWordDominate",
    },
    {
        id = "bone_king",
        label = "Bone King",
        spellIds = { 707176, 707175 },
        fallbackIcon = "Interface\\Icons\\Ability_Creature_Cursed_05",
    },
    {
        id = "frost_runes",
        label = "Frost Runes",
        spellIds = { 705751, 705750 },
        fallbackIcon = "Interface\\Icons\\Spell_Deathknight_EmpowerRuneBlade2",
    },
}

local function SpellIdInList(spellId, list)
    if not spellId or not list then
        return false
    end
    for _, id in ipairs(list) do
        if id == spellId then
            return true
        end
    end
    return false
end

-- Returns name, count, duration, expirationTime, iconTexture, remaining for a player HELPFUL aura.
function Advisor:FindPlayerAuraBySpellIds(spellIds)
    if not spellIds or #spellIds == 0 then
        return nil
    end
    local now = GetTime and GetTime() or 0
    for i = 1, 40 do
        local name, _, icon, count, _, duration, expirationTime, _, _, _, spellId
        if UnitAura then
            name, _, icon, count, _, duration, expirationTime, _, _, _, spellId =
                UnitAura("player", i, "HELPFUL")
        elseif UnitBuff then
            name, _, icon, count, _, duration, expirationTime, _, _, _, spellId =
                UnitBuff("player", i)
        else
            break
        end
        if not name then
            break
        end
        spellId = tonumber(spellId)
        if SpellIdInList(spellId, spellIds) then
            count = NormalizeAuraCount(count)
            duration = tonumber(duration) or 0
            expirationTime = tonumber(expirationTime) or 0
            local remaining = 0
            if expirationTime > 0 then
                remaining = math.max(0, expirationTime - now)
            end
            return name, count, duration, expirationTime, icon, remaining, spellId
        end
    end
    return nil
end

function Advisor:GetProcStripIcons(includeInactive)
    local icons = {}
    if MancerDB and MancerDB.showProcBar == false then
        return icons
    end

    for _, def in ipairs(self.PROC_AURAS or {}) do
        local name, count, duration, expirationTime, icon, remaining, spellId =
            self:FindPlayerAuraBySpellIds(def.spellIds)
        local active = name ~= nil and ((remaining and remaining > 0.05) or (count and count > 0))
        if active or includeInactive then
            local texture = icon
            if not texture and def.spellIds and def.spellIds[1] and GetSpellInfo then
                texture = select(3, GetSpellInfo(def.spellIds[1]))
            end
            if not texture then
                texture = def.fallbackIcon
            end
            local start = nil
            if active and duration and duration > 0 and expirationTime and expirationTime > 0 then
                start = expirationTime - duration
            end
            table.insert(icons, {
                id = def.id,
                label = def.label,
                spellId = spellId or (def.spellIds and def.spellIds[1]),
                texture = texture,
                stacks = active and count or (includeInactive and 3 or 0),
                duration = active and duration or (includeInactive and 12 or 0),
                expirationTime = active and expirationTime or nil,
                start = active and start or (includeInactive and ((GetTime and GetTime() or 0) - 3) or nil),
                remaining = active and remaining or (includeInactive and 9 or 0),
                active = active == true,
            })
        end
    end
    return icons
end

-- Strip entries for Animate CDs you have taken only. Ready icons pulse; others stay dim with CD remaining.
function Advisor:GetAnimateStripIcons()
    local icons = {}
    if not self:IsMinionAdvisorEnabled() then
        return icons
    end

    -- Do not SeedSummonsFromVisibleUnits here — nameplate seeds were refreshing temporaryActive
    -- and greying Animates that were actually off cooldown.
    self:SyncTemporaryFromSpellCooldowns()

    for _, minionId in ipairs(self.ANIMATE_READY_ORDER or {}) do
        if self:IsAnimateReadyMinion(minionId) then
            local binding = self:BuildAnimateStripBinding(minionId)
            if binding then
                local spellId, texture = self:GetAnimateAlertIcon(minionId, binding)
                local start, duration, remaining = self:GetAnimateSpellCooldown(minionId, binding)
                local active = self:IsAnimateCastWindowActive(minionId)
                local activeRemaining = active and self:GetAnimateActiveRemaining(minionId) or nil
                local onCd = remaining and remaining > 0.35
                local ready = not active and not onCd
                -- Keep spell CD for center number; vanish timer uses pet duration only.
                if active and activeRemaining and activeRemaining > 0 then
                    local window = self:GetTemporaryDuration(minionId)
                    if window and window > 0 and activeRemaining > window then
                        activeRemaining = window
                    end
                end
                table.insert(icons, {
                    minionId = minionId,
                    spellId = spellId,
                    texture = texture,
                    talentName = binding.name,
                    ready = ready,
                    active = active,
                    -- Spell CD (center + swipe) — includes Runic Animation CDR via GetSpellCooldown
                    start = start,
                    duration = duration,
                    remaining = remaining,
                    cdStart = start,
                    cdDuration = duration,
                    cdRemaining = remaining,
                    -- Despawn / vanish (top-right) — from tip duration / Prodigy, not CD
                    activeRemaining = activeRemaining,
                })
            end
        end
    end

    return icons
end

function Advisor:GetReadyAnimateIcons()
    local ready = {}
    for _, icon in ipairs(self:GetAnimateStripIcons()) do
        if icon.ready then
            table.insert(ready, icon)
        end
    end
    return ready
end

function Advisor:GetMinionAlertIcon(minionId)
    local def = self.MINION_TYPES[minionId]
    if not def then
        return nil, nil
    end

    local spellId = def.alertSpellId
    local texture

    if def.spellNames then
        for _, spellName in ipairs(def.spellNames) do
            if GetSpellInfo then
                local icon = select(3, GetSpellInfo(spellName))
                if icon then
                    texture = icon
                    break
                end
            end
        end
    end

    if not texture and spellId then
        if GetSpellTexture then
            texture = GetSpellTexture(spellId)
        end
        if not texture and GetSpellInfo then
            texture = select(3, GetSpellInfo(spellId))
        end
    end

    if not spellId then
        if def.cooldownSpellIds then
            for id in pairs(def.cooldownSpellIds) do
                spellId = id
                break
            end
        end
        if not spellId and def.summonSpellIds then
            for id in pairs(def.summonSpellIds) do
                spellId = id
                break
            end
        end
    end

    if not texture and spellId then
        if GetSpellTexture then
            texture = GetSpellTexture(spellId)
        end
        if not texture and GetSpellInfo then
            texture = select(3, GetSpellInfo(spellId))
        end
    end

    return spellId, texture
end

function Advisor:GetAdvisorDisplayKey(display)
    if not display then
        return nil
    end

    local parts = {
        display.stanceText or "",
        display.lfText or "",
        display.text or "",
    }
    for _, icon in ipairs(display.animateIcons or display.icons or {}) do
        local rem = icon.remaining and math.floor(icon.remaining + 0.5) or 0
        local flag = icon.ready and "R" or (icon.active and "A" or "C")
        table.insert(parts, string.format("%s:%s:%d", tostring(icon.minionId or "?"), flag, rem))
    end
    return table.concat(parts, "|")
end

function Advisor:GetAdvisorDisplay()
    local color = self:GetConfig().alertColor or { 0.25, 0.95, 0.75 }
    local display = {
        text = nil,
        stanceText = nil,
        lfText = nil,
        icons = {},
        animateIcons = {},
        color = color,
    }

    -- Stance is independent of Life Force / minion advisor.
    if self:IsStanceAdvisorEnabled() then
        display.stanceText = self:GetStanceAlert()
    end

    if self:IsMinionAdvisorEnabled() then
        local lfUsed, lfMax, lfFree = self:GetLifeForceSlotStatus()
        if lfMax and lfMax > 0 and lfUsed and lfUsed < lfMax then
            display.lfText = string.format(
                "Life Force (%d/%d)",
                lfFree or math.max(0, lfMax - lfUsed),
                lfMax
            )
        end

        if MancerDB.showAnimateBar ~= false then
            local animOk, icons = pcall(function()
                return self:GetAnimateStripIcons()
            end)
            if animOk and type(icons) == "table" then
                display.animateIcons = icons
            end
        end
    end

    local lines = {}
    if display.stanceText and display.stanceText ~= "" then
        table.insert(lines, display.stanceText)
    end
    if display.lfText and display.lfText ~= "" then
        table.insert(lines, display.lfText)
    end
    if #lines > 0 then
        display.text = table.concat(lines, "\n")
    end

    local hasText = display.text and display.text ~= ""
    local hasAnimates = display.animateIcons and #display.animateIcons > 0
    if not hasText and not hasAnimates then
        return nil
    end

    return display
end

function Advisor:GetPrimaryAlert()
    local display = self:GetAdvisorDisplay()
    if not display then
        return nil
    end
    return display.text
end

function Advisor:HandleCombatLogEvent(...)
    local parsed = Mancer.CombatLog and Mancer.CombatLog.Parse and Mancer.CombatLog.Parse(...)
    if not parsed then
        return
    end

    local eventType = parsed.eventType
    local playerGuid = UnitGUID("player")
    if not playerGuid then
        return
    end

    if eventType == "SPELL_SUMMON" then
        -- Only track summons cast by this player — ignore other necromancers in party/raid.
        if not parsed.sourceGUID or not GuidsMatch(parsed.sourceGUID, playerGuid) then
            return
        end
        local minionId = self:ClassifyMinionName(parsed.destName)
            or self:ClassifyBySpellId(parsed.spellId)
            or self:ClassifyMinionName(parsed.spellName)
        if self:IsLesserZombieSummon(parsed.destName, parsed.spellId, parsed.spellName) then
            minionId = "lesser_zombie"
        end
        if minionId == "lesser_zombie" and not self:HasUnrelentingArmy() then
            minionId = nil
        end
        if parsed.destGUID and minionId then
            self:RecordSummon(parsed.destGUID, parsed.destName or parsed.spellName, minionId, parsed.spellId, "summon")
            if self:UsesTemporaryTracking(minionId) then
                self:MarkTemporaryCast(minionId)
            end
        end
    elseif eventType == "SPELL_CAST_SUCCESS" then
        if parsed.sourceGUID == playerGuid then
            if self:IsGhoulSummonSpell(parsed.spellId, parsed.spellName) then
                self:OnGhoulSummoned()
            else
                -- Only Animate/Raise summons refresh vanish — Command: Undead must not.
                local isTemp, minionId = self:IsTemporarySummonCast(parsed.spellId, parsed.spellName)
                if isTemp and minionId then
                    self:MarkTemporaryCast(minionId)
                end
            end
            -- Stance casts / auras: remember via CLEU (UnitBuff goes blind when LF hides).
            if parsed.spellId and self.UNDEAD_STANCE_SPELL_LOOKUP[tonumber(parsed.spellId)] then
                self:NoteStanceAuraEvent(parsed.spellId, parsed.spellName, true)
            elseif select(1, self:ClassifyUndeadStance(parsed.spellName, parsed.spellId)) then
                self:NoteStanceAuraEvent(parsed.spellId, parsed.spellName, true)
            end
        end
    elseif eventType == "SPELL_AURA_APPLIED"
        or eventType == "SPELL_AURA_REFRESH"
        or eventType == "SPELL_AURA_APPLIED_DOSE" then
        if parsed.destGUID and GuidsMatch(parsed.destGUID, playerGuid) then
            self:NoteStanceAuraEvent(parsed.spellId, parsed.spellName, true)
        end
    elseif eventType == "SPELL_AURA_REMOVED" then
        if parsed.destGUID and GuidsMatch(parsed.destGUID, playerGuid) then
            self:NoteStanceAuraEvent(parsed.spellId, parsed.spellName, false)
        end
    elseif eventType == "UNIT_DIED" then
        local destGuid = parsed.destGUID
        local destName = parsed.destName
        local minionId = nil
        local summonKey, summonInfo = self:FindActiveSummon(destGuid)
        if summonKey and summonInfo then
            minionId = summonInfo.minionId
            self.activeSummons[summonKey] = nil
            self:ClearGuidUnitCache(destGuid)
            if Mancer.MinionDpsModule then
                if Mancer.MinionDpsModule.CloseSummonGuid then
                    Mancer.MinionDpsModule:CloseSummonGuid(destGuid, "advisor_died")
                else
                    Mancer.MinionDpsModule:UnregisterSummonGuid(destGuid)
                end
            end
            if minionId and self:UsesTemporaryTracking(minionId) and self.temporaryActive then
                self.temporaryActive[minionId] = nil
            end
        end
        if not minionId and destName then
            minionId = self:ClassifyMinionName(destName)
        end
        if minionId == "ghoul" then
            self:OnGhoulDied()
        end
    end
end

function Advisor:TrackNameplateUnit(unit)
    if not unit then
        return
    end
    if UnitExists and not UnitExists(unit) then
        local name = UnitName and UnitName(unit)
        if not name or name == "" then
            return
        end
    end
    self.trackedUnits = self.trackedUnits or {}
    self.trackedUnits[unit] = true
end

function Advisor:UntrackNameplateUnit(unit)
    if not self.trackedUnits or not unit then
        return
    end
    self.trackedUnits[unit] = nil
end

function Advisor:UpdateAlert(forceShow)
    if not self:IsEnabled() then
        self:HideAlert()
        if Mancer.FloatingText and Mancer.FloatingText.HideZombieCounter then
            Mancer.FloatingText:HideZombieCounter()
        end
        if Mancer.FloatingText and Mancer.FloatingText.HideProcStrip then
            Mancer.FloatingText:HideProcStrip()
        end
        return
    end

    if Mancer.FloatingText and Mancer.FloatingText.UpdateZombieCounter then
        Mancer.FloatingText:UpdateZombieCounter()
    end
    if Mancer.FloatingText and Mancer.FloatingText.UpdateProcStrip then
        Mancer.FloatingText:UpdateProcStrip()
    end

    local display = self:GetAdvisorDisplay()
    if not display then
        -- Always clear: stance-correct + full LF spend often means nil display.
        -- Guarding on lastAlertKey left the stance FontString stuck forever after
        -- ForceStanceAlertRefresh / InvalidateCaches nil'd the key first.
        self:HideAlert()
        return
    end

    local key = self:GetAdvisorDisplayKey(display)
    if key == self.lastAlertKey and not forceShow then
        return
    end

    self.lastAlertKey = key
    if Mancer.FloatingText then
        Mancer.FloatingText:ShowAdvisorDisplay(display)
    end
end

function Advisor:HideAlert()
    self.lastAlertKey = nil
    if Mancer.FloatingText then
        Mancer.FloatingText:HideAdvisorAlert()
    end
end

function Advisor:PrintStanceDebug()
    local function out(msg)
        local text = "|cff7fd4ffMancer stance|r " .. tostring(msg)
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(text)
        else
            print(text)
        end
    end

    local function spellTex(spellId)
        local tex = GetSpellTexture and GetSpellTexture(spellId)
        if (not tex or tex == "") and GetSpellInfo then
            tex = select(3, GetSpellInfo(spellId))
        end
        return tex and tostring(tex) or nil
    end

    local activeId, activeLabel = self:GetActiveUndeadStance()
    local desiredId, desiredLabel = self:GetDesiredUndeadStance()
    local lfUsed, lfMax, lfFree = self:GetLifeForceSlotStatus()
    out(string.format("active=%s want=%s", activeLabel or "none", desiredLabel or "?"))
    out(string.format(
        "LF used=%s max=%s free=%s (prompt %s) apiBlind=%s mem=%s",
        tostring(lfUsed),
        tostring(lfMax),
        tostring(lfFree),
        (lfMax and lfUsed and lfUsed < lfMax) and "shown" or "hidden",
        tostring(self:IsLifeForceAuraApiBlind()),
        tostring(self.trackedStanceId or (MancerDB and MancerDB.activeUndeadStance) or "-")
    ))
    out(string.format(
        "paths coa=%s cur=%s act=%s shift=%s tip=%s direct=%s",
        tostring(select(1, self:ScanCoAMultiCastStance()) or "-"),
        tostring(select(1, self:ScanCurrentSpellStance()) or "-"),
        tostring(select(1, self:ScanCurrentActionStance()) or "-"),
        tostring(select(1, self:ScanShapeshiftStance()) or "-"),
        tostring(select(1, self:ScanStanceFromTooltips()) or "-"),
        tostring(select(1, self:FindStanceAuraDirect()) or "-")
    ))

    local form = GetShapeshiftForm and GetShapeshiftForm() or 0
    local num = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
    out(string.format("shapeshift form=%s num=%s", tostring(form), tostring(num)))
    if GetShapeshiftFormInfo and num and num > 0 then
        for i = 1, num do
            local texture, name, isActive, isCastable = GetShapeshiftFormInfo(i)
            local button = _G["ShapeshiftButton" .. i]
            local checked = button and button.GetChecked and button:GetChecked()
            out(string.format(
                "  form%d active=%s checked=%s cast=%s name=%s",
                i,
                tostring(isActive),
                tostring(checked),
                tostring(isCastable),
                tostring(name or "?")
            ))
        end
    end

    out("prot=" .. tostring(GetSpellInfo and GetSpellInfo(500985) or "?") .. " tex=" .. tostring(spellTex(500985) or "?"))
    out("assault=" .. tostring(GetSpellInfo and GetSpellInfo(500982) or "?") .. " tex=" .. tostring(spellTex(500982) or "?"))

    -- CoA bar is minion shortcuts + LF icon (not stances) — keep a short dump.
    out("CoA bar (minions/LF, not stances):")
    for i = 1, 5 do
        local name = "CoAMultiCastActionBarFramePoolFrameCoAMultiCastActionButtonTemplate" .. i
        local button = rawget(_G, name)
        if not button then
            out(i .. " missing")
        else
            local spellId = CoAButtonSpellId(button)
            local book = spellId and GetSpellInfo and GetSpellInfo(spellId)
            out(string.format(
                "%d id=%s name=%s shown=%s",
                i,
                tostring(spellId or "-"),
                tostring(book or "-"),
                tostring(button.IsShown and button:IsShown())
            ))
        end
    end
end

function Advisor:PrintStanceStatus()
    if not self:IsNecromancer() then
        Mancer.Print("  Undead stances: not a Necromancer.")
        return
    end

    local activeId, activeLabel = self:GetActiveUndeadStance()
    local desiredId, desiredLabel = self:GetDesiredUndeadStance()
    local inGroup = self:IsInPartyOrRaid()

    Mancer.Print(string.format(
        "  Undead stance: %s | group: %s | recommended: %s",
        activeLabel or "none",
        inGroup and "yes" or "no",
        desiredLabel
    ))
    if self.trackedStanceId then
        Mancer.Print(string.format(
            "  CLEU memory: %s",
            self.trackedStanceLabel or self.trackedStanceId
        ))
    end

    Mancer.Print(string.format(
        "  Scan paths: coa=%s current=%s action=%s shapeshift=%s tooltip=%s direct=%s",
        tostring(select(1, self:ScanCoAMultiCastStance()) or "miss"),
        tostring(select(1, self:ScanCurrentSpellStance()) or "miss"),
        tostring(select(1, self:ScanCurrentActionStance()) or "miss"),
        tostring(select(1, self:ScanShapeshiftStance()) or "miss"),
        tostring(select(1, self:ScanStanceFromTooltips()) or "miss"),
        tostring(select(1, self:FindStanceAuraDirect()) or "miss")
    ))
    self:DumpCoAMultiCastButtons()

    if activeId ~= desiredId then
        Mancer.Print(string.format("  STANCE: %s", string.format("Use %s", desiredLabel)))
    end

    if self:HasShapeshiftStanceBar() then
        local form = GetShapeshiftForm and GetShapeshiftForm() or 0
        Mancer.Print(string.format("  Stance bar: %d forms | active form index: %s", GetNumShapeshiftForms(), tostring(form)))
    end
end

function Advisor:PrintStatus()
    self.requiredMinionsDirty = true
    self.cachedKnownMinions = nil
    self:ClearPollCaches()

    if self:IsStanceAdvisorEnabled() then
        Mancer.Print("Necromancer advisor status:")
        self:PrintStanceStatus()
    end

    if not Ascension.IsAnimationNecromancer() then
        if not self:IsStanceAdvisorEnabled() then
        Mancer.Print("Animation Necromancer not detected.")
        Ascension.PrintSpecInfo()
        end
        return
    end

    if not self:IsMinionAdvisorEnabled() then
        return
    end

    Mancer.Print("Animation Necromancer minion status:")
    if self:IsAutoLifeForceEnabled() then
        local stacks, used, spellId, auraName = self:UpdateLifeForcePeak()
        Mancer.Print(string.format(
            "  Life Force: max %d | debuff stacks %s | used by minions %d%s",
            self:GetLifeForceMax(),
            stacks and tostring(stacks) or "none",
            used,
            spellId and (" | spell:" .. spellId) or (auraName and (" | " .. auraName) or "")
        ))
    else
        Mancer.Print("  Life Force: manual ghoul cap (" .. tostring(self:GetGhoulMinionMax()) .. ")")
    end

    self.animateSpellbookCache = nil
    if Ascension.InvalidateTalentCache then
        Ascension.InvalidateTalentCache()
    end
    Mancer.Print("  Animate A-bar:")
    for _, minionId in ipairs(self.ANIMATE_READY_ORDER or {}) do
        local def = self.MINION_TYPES[minionId]
        local spellId = def and def.alertSpellId
        local rank = spellId and Ascension.GetTalentRankBySpell and Ascension.GetTalentRankBySpell(spellId) or 0
        local binding = self:ResolveAnimateStripBinding(minionId)
        Mancer.Print(string.format(
            "    %s: rank=%s spell=%s strip=%s",
            def and def.label or minionId,
            tostring(rank),
            tostring(spellId or "?"),
            binding and (binding.name or "yes") or "no"
        ))
    end
    local book = self:GetLearnedAnimateSpellNames()
    if #book > 0 then
        Mancer.Print("  Spellbook Animates: " .. table.concat(book, ", "))
    end

    local known = self:GetStatusMinions()
    if #known == 0 then
        Mancer.Print("  No tracked minion talents detected.")
    end

    local counts, seen = self:CollectActiveMinions()
    for _, req in ipairs(known) do
        local active = counts[req.id] or 0
        local want = self:GetMinionMax(req.id)
        local suffix = ""
        local _, _, cdRemaining = self:GetMinionSpellCooldown(req.id)
        if cdRemaining and cdRemaining > 0 then
            suffix = string.format(" (spell cd %.0fs)", cdRemaining)
        elseif self:IsMinionOnCooldown(req.id) then
            suffix = " (on cooldown)"
        end
        local alertTag = req.requiredForAlert and "" or " (tracked only)"
        if req.activeOnly then
            alertTag = " (active, talent not detected)"
        end
        Mancer.Print(string.format("  %s: %d / %d active%s%s", req.label, active, want, suffix, alertTag))
        if seen[req.id] then
            for _, entry in ipairs(seen[req.id]) do
                local duplicateTag = entry.duplicate and " (duplicate aura)" or ""
                if entry.spellId then
                    Mancer.Print(string.format(
                        "    - %s via %s (%s) spell:%s%s",
                        entry.name, entry.source, entry.unit, tostring(entry.spellId), duplicateTag
                    ))
                else
                    Mancer.Print(string.format(
                        "    - %s via %s (%s)%s",
                        entry.name, entry.source, entry.unit, duplicateTag
                    ))
                end
            end
        end
    end

    local tracked = 0
    if self.activeSummons then
        for _ in pairs(self.activeSummons) do
            tracked = tracked + 1
        end
    end
    Mancer.Print(string.format("  Combat log tracked summons: %d", tracked))

    if self.castCounts then
        for minionId, amount in pairs(self.castCounts) do
            if amount > 0 then
                Mancer.Print(string.format("  Cast-tracked %s: %d", minionId, amount))
            end
        end
    end

    local scanUnits = self:GetAllScanUnits()
    Mancer.Print(string.format("  Scannable units: %d | pet: %s", #scanUnits, tostring(UnitExists("pet"))))

    local lfUsed, lfMax, lfFree = self:GetLifeForceSlotStatus()
    if lfUsed < lfMax then
        Mancer.Print(string.format("  Life Force: %d / %d (%d free)", lfUsed, lfMax, lfFree))
    else
        Mancer.Print(string.format("  Life Force: %d / %d (full)", lfUsed, lfMax))
    end

    local missing = self:GetMissingMinions()
    if #missing == 0 then
        Mancer.Print("  All temporary minion alerts are satisfied.")
    else
        for _, entry in ipairs(missing) do
            Mancer.Print(string.format("  MISSING: %s (%d/%d)", entry.label, entry.have, entry.want))
        end
    end
end

function Advisor:PrintLifeForceStatus()
    Mancer.Print("Life Force scan:")
    local stacks, used, spellId, auraName = self:UpdateLifeForcePeak()
    local maxValue = self:GetLifeForceMax()
    local ghoulCap = self:GetGhoulMinionMax()
    local usedByOthers = self:GetActiveLifeForceUsed("ghoul")
    local auraCounts = self:ScanAurasForMinions()

    Mancer.Print(string.format("  Auto-detect: %s", self:IsAutoLifeForceEnabled() and "on" or "off"))
    Mancer.Print(string.format("  Peak max seen: %s", tostring(self.lifeForcePeak or "none")))
    Mancer.Print(string.format("  Talent-derived max: %d", self:GetTalentLifeForceMax()))
    local coaFree, coaMax = self:TryReadCoALifeForce()
    if coaMax then
        Mancer.Print(string.format("  CoA orb: %s / %s", tostring(coaFree), tostring(coaMax)))
    end
    Mancer.Print(string.format("  Debuff: %s | stacks: %s | spell: %s",
        auraName or "not found", stacks and tostring(stacks) or "none", tostring(spellId or "?")))
    Mancer.Print(string.format("  Life force used by minions: %d", self:ScanLifeForceUsageFromBuffs()))
    Mancer.Print(string.format("  Inferred max pool: %d", maxValue))
    Mancer.Print(string.format("  Ghoul cap (max minus other minions): %d", ghoulCap))
    if usedByOthers > 0 then
        Mancer.Print(string.format("  Used by non-ghoul minions: %d", usedByOthers))
    end

    Mancer.Print("  Minion buff costs:")
    for minionId, amount in pairs(auraCounts) do
        if amount > 0 then
                Mancer.Print(string.format(
                "    %s x%d = %d life force",
                self.MINION_TYPES[minionId].label,
                amount,
                amount * self:GetMinionLifeForceCost(minionId)
            ))
        end
    end

    Mancer.Print("  Debuff scan (life force auras):")
    local found = false
    for i = 1, 40 do
        local name, count, spellId, index = GetPlayerDebuffData(i)
        if not name then
            break
        end
        if self:IsLifeForceAura(name, spellId) then
            found = true
            Mancer.Print(string.format("    [debuff %d] %s x%s spell:%s", index, name, tostring(count), tostring(spellId)))
        end
    end
    if not found then
        Mancer.Print("    (no life force debuff found)")
    end
end

function Advisor:SetGhoulMax(count)
    count = tonumber(count)
    if not count or count < 0 or count > 20 then
        if Mancer.Hub then
            Mancer.Hub:Notify("Ghoul cap must be between 0 and 20.")
        end
        return
    end
    local cfg = self:GetConfig()
    cfg.minionMax = cfg.minionMax or {}
    cfg.minionMax.autoLifeForce = false
    cfg.minionMax.ghoul = count
    self.lifeForcePeak = count
    if Mancer.Hub then
        Mancer.Hub:Notify("Ghoul cap set to " .. count .. " (Life Force auto-detect disabled)")
    end
end

function Advisor:LinkPendingSummonUnits()
    if not self.activeSummons then
        return
    end
    for guid, info in pairs(self.activeSummons) do
        if info and not info.unit then
            self:TryLinkSummonUnit(guid)
        end
    end
end

function Advisor:Poll(elapsed)
    if not self:ShouldRunAdvisor() then
        return
    end

    if self.pendingCacheInvalidate then
        self.pendingCacheInvalidate = false
        self:InvalidateCaches()
    end

    self.alertTimer = (self.alertTimer or 0) + elapsed
    if self.dirtyAlert and self.alertTimer >= ALERT_REFRESH_INTERVAL then
        self.alertTimer = 0
        self.dirtyAlert = false
        self:ClearPollCaches()
        self:UpdateAlert(true)
    end

    self.pollTimer = (self.pollTimer or 0) + elapsed
    if self.pollTimer < ADVISOR_POLL_INTERVAL then
        return
    end

    self.pollTimer = 0
    self:ClearPollCaches()
    self:LinkPendingSummonUnits()
    if self.dirtyAlert then
        self.dirtyAlert = false
        self.alertTimer = 0
        self:UpdateAlert(true)
    else
        self:UpdateAlert(false)
    end
end

function Advisor:ApplyConfig()
    if self.frame then
        if self:ShouldRunAdvisor() then
            self.frame:Show()
        else
            self.frame:Hide()
            self:HideAlert()
        end
    end

    if self.tickerFrame then
        if self:ShouldRunAdvisor() then
            self.tickerFrame:Show()
        else
            self.tickerFrame:Hide()
        end
    end

    if self.pollFrame then
        self.pollFrame:Hide()
        self.pollFrame:SetScript("OnUpdate", nil)
        self.pollFrame = nil
    end

    -- Instant HUD refresh (Animate / proc / zombie toggles, etc.) — don't wait for poll.
    self.lastAlertKey = nil
    self.dirtyAlert = true
    if self:ShouldRunAdvisor() then
        self:UpdateAlert(true)
    else
        if Mancer.FloatingText and Mancer.FloatingText.HideZombieCounter then
            Mancer.FloatingText:HideZombieCounter()
        end
        if Mancer.FloatingText and Mancer.FloatingText.HideProcStrip then
            Mancer.FloatingText:HideProcStrip()
        end
    end
end

function Advisor:New()
    local self = setmetatable({}, { __index = Advisor })

    self.trackedUnits = {}
    self.activeSummons = {}
    self.guidUnitCache = {}
    self.temporaryActive = {}
    self.lastCastTime = {}
    self.lastAlert = nil
    self.pollTimer = 0
    self.dirtyAlert = true
    self.requiredMinionsDirty = true

    self.frame = CreateFrame("Frame")
    self.frame:Hide()
    self.frame:RegisterEvent("UNIT_PET")
    self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    pcall(function() self.frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED") end)
    self.frame:RegisterEvent("ASCENSION_KNOWN_ENTRIES_UPDATED")
    pcall(function() self.frame:RegisterEvent("ASCENSION_KNOWN_ENTRIES_CHANGED") end)
    self.frame:RegisterEvent("ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED")
    self.frame:RegisterEvent("PLAYER_TALENT_UPDATE")
    self.frame:RegisterEvent("SPELLS_CHANGED")
    pcall(function() self.frame:RegisterEvent("SPELL_UPDATE_COOLDOWN") end)
    self.frame:RegisterEvent("UNIT_AURA")
    self.frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    self.frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    self.frame:RegisterEvent("RAID_ROSTER_UPDATE")
    pcall(function() self.frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM") end)
    pcall(function() self.frame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS") end)

    pcall(function() self.frame:RegisterEvent("NAME_PLATE_UNIT_ADDED") end)
    pcall(function() self.frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED") end)

    self.frame:SetScript("OnEvent", function(_, event, arg1, ...)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            self:HandleCombatLogEvent(arg1, ...)
            return
        end

        if event == "PLAYER_REGEN_DISABLED" then
            if Mancer.MinionDpsModule then
                Mancer.MinionDpsModule:OnCombatStart()
            end
            return
        end

        if event == "PLAYER_REGEN_ENABLED" then
            if Mancer.MinionDpsModule then
                Mancer.MinionDpsModule:OnCombatEnd()
            end
            return
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            self:HandlePlayerSpellCast(arg1, select(2, ...), select(5, ...))
            self.nextSpellCdSync = 0
            self.spellCdCache = nil
            return
        end

        if event == "NAME_PLATE_UNIT_ADDED" then
            self:TrackNameplateUnit(arg1)
            self:OnGuardianUnitDiscovered(arg1)
            self.cachedScanUnits = nil
            return
        end

        if event == "NAME_PLATE_UNIT_REMOVED" then
            self:UntrackNameplateUnit(arg1)
            self.cachedScanUnits = nil
            return
        end

        if event == "UNIT_AURA" then
            if arg1 == "player" then
                self.dirtyAlert = true
            end
            return
        end

        if event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_SHAPESHIFT_FORMS" then
            -- Stance toggle — refresh HUD immediately (do not wait for poll).
            self:RefreshStanceFromShapeshiftBar()
            self:ForceStanceAlertRefresh()
            return
        end

        if event == "PLAYER_ENTERING_WORLD" then
            self:RefreshStanceFromShapeshiftBar()
            self.dirtyAlert = true
            self:InvalidateCaches()
            return
        end

        if event == "SPELL_UPDATE_COOLDOWN" then
            self.nextSpellCdSync = 0
            self.spellCdCache = nil
            return
        end

        -- Talent / CA learn: refresh strip promptly (spellbook + known talents).
        if event == "PLAYER_TALENT_UPDATE"
            or event == "ASCENSION_KNOWN_ENTRIES_UPDATED"
            or event == "ASCENSION_KNOWN_ENTRIES_CHANGED"
            or event == "ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED" then
            self:RequestAnimateStripRefresh()
            return
        end

        -- Noisy events: clear spellbook cache + debounce invalidate (avoid forced UI spam).
        if event == "SPELLS_CHANGED" or event == "UNIT_PET" then
            self.pendingCacheInvalidate = true
            self.animateSpellbookCache = nil
            self.dirtyAlert = true
            return
        end

        self:InvalidateCaches()
    end)

    -- Advisor updates on its own low-frequency ticker (not every rendered frame).
    self.tickerFrame = CreateFrame("Frame", "MancerAdvisorTicker", UIParent)
    self.tickerFrame:SetSize(1, 1)
    self.tickerFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    self.tickerFrame:SetScript("OnUpdate", function(_, elapsed)
        self:Poll(elapsed)
    end)

    self:ApplyConfig()
    self.dirtyAlert = true
    return self
end
