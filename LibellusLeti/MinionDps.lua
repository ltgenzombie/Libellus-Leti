Mancer.MinionDpsModule = {}
local MinionDps = Mancer.MinionDpsModule

local MAX_SAVED_FIGHTS = 10
local SESSION_MIN_FIGHTS = 1

local DAMAGE_EVENTS = {
    SWING_DAMAGE = true,
    RANGE_DAMAGE = true,
    SPELL_DAMAGE = true,
    SPELL_PERIODIC_DAMAGE = true,
    DAMAGE_SPLIT = true,
}

local AURA_EVENTS = {
    SPELL_AURA_APPLIED = true,
    SPELL_AURA_REFRESH = true,
    SPELL_AURA_REMOVED = true,
    SPELL_AURA_APPLIED_DOSE = true,
    SPELL_AURA_REMOVED_DOSE = true,
}

-- Player spells logged beside minion DPS (DoT uptime / proc counts).
-- DoTs: per-target GUID + combined unit-seconds. Procs: times applied to the player.
local PLAYER_TRACKED_SPELLS = {
    {
        id = "blight",
        kind = "dot",
        label = "Blight",
        names = { ["Blight"] = true },
        spellIds = {},
    },
    {
        id = "harvest_plague",
        kind = "dot",
        label = "Harvest Plague",
        names = {
            ["Harvest Plague"] = true,
            ["harvest plague"] = true,
        },
        -- Ranked spell IDs from Ascension Spell.dbc (trainer ranks).
        spellIds = {
            [500968] = true,
            [501890] = true,
            [501891] = true,
            [501892] = true,
            [583255] = true,
            [583256] = true,
            [572842] = true,
            [572843] = true,
            [572844] = true,
            [572845] = true,
        },
    },
    {
        id = "bone_king",
        kind = "proc",
        label = "Bone King",
        names = { ["Bone King"] = true },
        spellIds = { [707176] = true, [707175] = true },
    },
    {
        id = "diabolical",
        kind = "proc",
        label = "Diabolical",
        names = { ["Diabolical"] = true },
        spellIds = { [707133] = true },
    },
    {
        id = "frost_runes",
        kind = "proc",
        label = "Frost Runes",
        names = { ["Frost Runes"] = true },
        spellIds = {
            [705751] = true,
            [705750] = true,
        },
    },
    {
        -- CA 29943 / spell 707007 — player AoE plague CD (damage + cast count).
        id = "march_of_the_dead",
        kind = "spell",
        label = "March of the Dead",
        names = {
            ["March of the Dead"] = true,
            ["march of the dead"] = true,
        },
        spellIds = {
            [707007] = true,
        },
    },
}

local OBJECT_TYPE_PET = 0x00001000
local OBJECT_TYPE_GUARDIAN = 0x00002000
local AFFILIATION_MINE = 0x00000001
local REACTION_FRIENDLY = 0x00000010
local CONTROL_PLAYER = 0x00000100

local LF_COMBO_MINIONS = {
    "abomination",
    "crypt_fiend",
    "banshee",
    "skeletal_warrior_lesser",
    "skeletal_warrior_greater",
    "skeletal_rogue",
}

local CD_MINIONS = {
    "bone_wraith",
    "skeletal_archer",
    "tomb_king",
    "plaguefather",
    "frost_wyrm",
}

-- Plain-language ST vs AoE roles for Hub / tooltips (not a second math engine).
-- focus: "st" | "aoe" | "both" | "burst"
local FIGHT_ROLES = {
    ghoul = {
        focus = "st",
        bestFor = "Bosses (one target)",
        oneLiner = "Your main army for boss damage. Fill leftover Life Force with these.",
    },
    abomination = {
        focus = "st",
        bestFor = "Bosses (one target)",
        oneLiner = "About as strong as three ghouls — and unlocks Army of the Dead haste.",
    },
    crypt_fiend = {
        focus = "aoe",
        bestFor = "Packs & AoE",
        oneLiner = "Best Raise when several enemies are stacked. Costs 2 Life Force.",
    },
    banshee = {
        focus = "st",
        bestFor = "Bosses / mana drain",
        oneLiner = "Channels on one target and drains mana. Costs 2 Life Force — strong vs casters.",
    },
    skeletal_warrior_greater = {
        focus = "both",
        bestFor = "Either (usually filler)",
        oneLiner = "Fine either way; ghouls or Crypt Fiend usually beat it for your Life Force.",
    },
    skeletal_warrior_lesser = {
        focus = "both",
        bestFor = "Either (usually filler)",
        oneLiner = "Early option. Swap toward ghouls / Abom / Crypt Fiend as you unlock them.",
    },
    skeletal_rogue = {
        focus = "st",
        bestFor = "Bosses (niche)",
        oneLiner = "Niche single-target Raise. Check Hub → LF Combo before forcing it in.",
    },
    bone_wraith = {
        focus = "burst",
        bestFor = "Boss burst (Animate)",
        oneLiner = "Best Animate for one tough enemy. No Life Force cost — press when ready.",
    },
    tomb_king = {
        focus = "aoe",
        bestFor = "Packs / big army",
        oneLiner = "Short buff for the whole army. Stronger when many minions are already out.",
    },
    skeletal_archer = {
        focus = "both",
        bestFor = "Always (on cooldown)",
        oneLiner = "Free Animate damage. Press whenever it is ready.",
    },
    plaguefather = {
        focus = "both",
        bestFor = "Always (on cooldown)",
        oneLiner = "Cooldown Animate. Use when ready alongside your army.",
    },
    frost_wyrm = {
        focus = "both",
        bestFor = "Always (on cooldown)",
        oneLiner = "Cooldown Animate. Use when ready alongside your army.",
    },
}

local FIGHT_ROLE_ORDER = {
    "abomination",
    "ghoul",
    "crypt_fiend",
    "banshee",
    "skeletal_warrior_greater",
    "skeletal_warrior_lesser",
    "skeletal_rogue",
    "bone_wraith",
    "tomb_king",
    "skeletal_archer",
    "plaguefather",
    "frost_wyrm",
}

local TEMP_DURATION_FALLBACK = {
    bone_wraith = 60,
    skeletal_archer = 18,
    tomb_king = 15,
}

-- Ascension hex GUID creature signatures from /dump UnitGUID("target") on summoned minions.
-- Format: 0xF130<6-char sig><spawn id> e.g. Skeletal Archer = 0xF13000C39C008AFA
local GUID_CREATURE_SIGS = {
    ["00c39c"] = "skeletal_archer",
    ["00c490"] = "tomb_king",
    ["07acf7"] = "lesser_zombie",
}

local function GuidCreatureSig(guid)
    if not guid then
        return nil
    end
    return tostring(guid):lower():match("^0x[f]?130(%x%x%x%x%x%x)")
end

-- Details-style per-pet breakdown (one CLEU source GUID = one "Attack" row).
local UNIT_TRACKED_MINIONS = {
    ghoul = true,
    lesser_zombie = true,
}

-- High-level calibration anchors (live Minion DPS overwrites when saved fights exist):
-- Early Details lvl~30: 1 Abom + 2 Ghoul → Abom ~206, Ghoul ~70 DPS/unit.
-- Mortuus lvl~41 long ST non-tank (~475s, geared+talents): Ghoul ~152 DPS/unit,
--   Command ~78% / Melee ~18% / Claws ~4%. Tomb King ~32% wall uptime.
-- Mortuus lvl~41 melee-only geared: ~16–17 DPS/unit (0.882 Wraith AP inherit over-predicted).
-- Mortuus lvl~41 naked (0 gear SP, INT 78, talents stripped):
--   5-ghoul army melee-only ≈ 6 DPS/unit; single ghoul ≈ 6–7 DPS (430/70s, hit ≈10–12).
--   Floor for AP-inherit A/B — not a 0.882 confirm.
-- Azuregos Pathstalker lvl60 WB: Command ~30% of ghoul package (autos-led).
local CALIB_GHOUL_DPS_EARLY = 70
local CALIB_GHOUL_DPS_MID41 = 152
local CALIB_GHOUL_DPS_NAKED41 = 6.5
local CALIB_ABOM_DPS = 206
local CALIB_COMMAND_SHARE_LONG_ST = 0.785
-- Extrapolated early: 3rd ghoul ≈ +70 ST DPS; 3 ghouls (~210) ≈ 1 abom (~206).
local BENCHMARK_DPS = {
    [30] = {
        ghoul = 9.5,
        abomination = 33,
        crypt_fiend = 60,
        skeletal_rogue = 7.5,
        skeletal_warrior_greater = 11.8,
        skeletal_warrior_lesser = 9.3,
    },
    -- Fallback when no live Minion DPS yet (lvl ≥40 uses this tier).
    [60] = {
        ghoul = CALIB_GHOUL_DPS_MID41,
        abomination = CALIB_ABOM_DPS,
    },
}

-- Mortuus lvl~41 non-tank dummy: Command DPS/unit ≈ 152 × 0.785 ≈ 119.
local COMMAND_GHOUL_DPS_PER_UNIT = math.floor(CALIB_GHOUL_DPS_MID41 * CALIB_COMMAND_SHARE_LONG_ST + 0.5)
local COMMAND_GHOUL_MIN_COUNT = 2

local function GetAdvisor()
    return Mancer.NecromancerAdvisorModule
end

local function IsNecromancerPlayer()
    if Mancer.Ascension and Mancer.Ascension.GetPlayerClass then
        return Mancer.Ascension.GetPlayerClass() == "NECROMANCER"
    end
    local Advisor = GetAdvisor()
    return Advisor and Advisor.IsNecromancer and Advisor:IsNecromancer()
end

local function GetTimeNow()
    return GetTime and GetTime() or 0
end

local function BitAnd(a, b)
    if bit and bit.band then
        return bit.band(a, b)
    end
    local result = 0
    for i = 0, 31 do
        local mask = 2 ^ i
        if math.floor(a / mask) % 2 == 1 and math.floor(b / mask) % 2 == 1 then
            result = result + mask
        end
    end
    return result
end

local function EnsureDb()
    MancerDB.minionDps = MancerDB.minionDps or {}
    local db = MancerDB.minionDps
    db.fights = db.fights or {}
    return db
end

local function NewMinionBucket()
    return {
        damage = 0,
        hits = 0,
        firstSeen = nil,
        lastSeen = nil,
        -- Sum of per-guid lifetimes (unit-seconds). Used for Animate CD uptime/DPS.
        activeSeconds = 0,
        summonCount = 0,
        spells = {},
    }
end

local function GetTempDuration(minionId)
    local Advisor = GetAdvisor()
    local def = Advisor and Advisor.MINION_TYPES and Advisor.MINION_TYPES[minionId]
    if def and def.duration and def.duration > 0 then
        return def.duration
    end
    return TEMP_DURATION_FALLBACK[minionId]
end

local function IsTemporaryMinion(minionId)
    local Advisor = GetAdvisor()
    if Advisor and Advisor.UsesTemporaryTracking then
        return Advisor:UsesTemporaryTracking(minionId)
    end
    return TEMP_DURATION_FALLBACK[minionId] ~= nil
end

local function ResolveSpellLabel(eventType, spellId, spellName)
    if eventType == "SWING_DAMAGE" then
        return "Melee", spellId or 1
    end
    if spellName and spellName ~= "" then
        return spellName, spellId
    end
    if spellId then
        return "Spell #" .. tostring(spellId), spellId
    end
    if eventType then
        return eventType, nil
    end
    return "Unknown", nil
end

local function GetSpellKey(spellId, spellLabel)
    if spellId then
        return "id:" .. tostring(spellId)
    end
    return "name:" .. tostring(spellLabel or "Unknown")
end

local function GetSpellBucket(bucket, spellKey, spellLabel, spellId)
    bucket.spells = bucket.spells or {}
    if not bucket.spells[spellKey] then
        bucket.spells[spellKey] = {
            label = spellLabel,
            spellId = spellId,
            damage = 0,
            hits = 0,
        }
    end
    return bucket.spells[spellKey]
end

local function ResolvePlayerTracked(spellId, spellName)
    spellId = tonumber(spellId)
    if spellId then
        for _, def in ipairs(PLAYER_TRACKED_SPELLS) do
            if def.spellIds and def.spellIds[spellId] then
                return def
            end
        end
    end
    if spellName and spellName ~= "" then
        local cleaned = tostring(spellName):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", "")
        for _, def in ipairs(PLAYER_TRACKED_SPELLS) do
            if def.names and (def.names[spellName] or def.names[cleaned]) then
                return def
            end
        end
        local lower = string.lower(cleaned)
        for _, def in ipairs(PLAYER_TRACKED_SPELLS) do
            if def.names then
                for name in pairs(def.names) do
                    if string.lower(name) == lower then
                        return def
                    end
                end
            end
        end
    end
    return nil
end

local function PlayerSpellKey(def)
    return "track:" .. tostring(def.id or def.label or "unknown")
end

local function NewPlayerSpellBucket(def)
    return {
        id = def.id,
        kind = def.kind or "dot",
        label = def.label,
        spellId = nil,
        damage = 0,
        hits = 0,
        procs = 0,
        casts = 0,
        activeSeconds = 0,
        peakTargets = 0,
        targets = {},
    }
end

local function GetPlayerSpellBucket(fight, def)
    fight.playerSpells = fight.playerSpells or {}
    local key = PlayerSpellKey(def)
    if not fight.playerSpells[key] then
        fight.playerSpells[key] = NewPlayerSpellBucket(def)
    end
    return fight.playerSpells[key], key
end

local function GetPlayerTargetBucket(spellBucket, destGuid, destName)
    spellBucket.targets = spellBucket.targets or {}
    if not destGuid then
        destGuid = "unknown"
    end
    local target = spellBucket.targets[destGuid]
    if not target then
        target = {
            guid = destGuid,
            name = destName,
            damage = 0,
            hits = 0,
            firstSeen = nil,
            lastSeen = nil,
            activeSeconds = 0,
            openStart = nil,
        }
        spellBucket.targets[destGuid] = target
    elseif destName and destName ~= "" then
        target.name = destName
    end
    return target
end

local function CountOpenPlayerTargets(spellBucket)
    local n = 0
    for _, target in pairs(spellBucket.targets or {}) do
        if target.openStart then
            n = n + 1
        end
    end
    return n
end

local function CopyPlayerSpellBuckets(source)
    local copy = {}
    for key, row in pairs(source or {}) do
        local targets = {}
        for guid, t in pairs(row.targets or {}) do
            targets[guid] = {
                guid = t.guid,
                name = t.name,
                damage = t.damage or 0,
                hits = t.hits or 0,
                firstSeen = t.firstSeen,
                lastSeen = t.lastSeen,
                activeSeconds = t.activeSeconds or 0,
                -- openStart intentionally dropped on save (flushed at combat end)
            }
        end
        copy[key] = {
            id = row.id,
            kind = row.kind,
            label = row.label,
            spellId = row.spellId,
            damage = row.damage or 0,
            hits = row.hits or 0,
            procs = row.procs or 0,
            casts = row.casts or 0,
            activeSeconds = row.activeSeconds or 0,
            peakTargets = row.peakTargets or 0,
            targets = targets,
        }
    end
    return copy
end

local function PlayerSpellsHaveData(fight)
    for _, row in pairs(fight and fight.playerSpells or {}) do
        if (row.damage or 0) > 0 or (row.hits or 0) > 0 or (row.procs or 0) > 0 then
            return true
        end
        if (row.activeSeconds or 0) > 0 then
            return true
        end
        for _, t in pairs(row.targets or {}) do
            if t.openStart or (t.activeSeconds or 0) > 0 or (t.damage or 0) > 0 then
                return true
            end
        end
    end
    return false
end

local function IsPlayerGuid(guid)
    if not guid then
        return false
    end
    local playerGuid = UnitGUID("player")
    if not playerGuid then
        return false
    end
    if guid == playerGuid then
        return true
    end
    local Advisor = GetAdvisor()
    if Advisor and Advisor.GuidsMatch then
        return Advisor:GuidsMatch(guid, playerGuid)
    end
    return false
end

local function CopyGuidSet(source)
    local copy = {}
    for guid in pairs(source or {}) do
        copy[guid] = true
    end
    return copy
end

local function CopySpellBuckets(sourceSpells)
    local copy = {}
    for key, row in pairs(sourceSpells or {}) do
        copy[key] = {
            label = row.label,
            spellId = row.spellId,
            damage = row.damage or 0,
            hits = row.hits or 0,
        }
    end
    return copy
end

local function CopyUnitBuckets(sourceUnits)
    local copy = {}
    for guid, row in pairs(sourceUnits or {}) do
        copy[guid] = {
            guid = guid,
            label = row.label,
            attackIndex = row.attackIndex,
            damage = row.damage or 0,
            hits = row.hits or 0,
            firstSeen = row.firstSeen,
            lastSeen = row.lastSeen,
            spells = CopySpellBuckets(row.spells),
        }
    end
    return copy
end

local function IsValidPetGuid(guid)
    if guid == nil or guid == "" then
        return false
    end
    local s = tostring(guid)
    -- Standard CLEU form: Creature-0-4218-...
    if s:find("-", 1, true) then
        return true
    end
    -- Ascension client form from UnitGUID / some CLEU sources: 0xF130...
    if s:match("^0[xX]%x+$") then
        return true
    end
    return false
end

local function UsesUnitBreakdown(minionId)
    return UNIT_TRACKED_MINIONS[minionId] == true
end

local function GetFightBucket(fight, minionId)
    fight.minions = fight.minions or {}
    if not fight.minions[minionId] then
        fight.minions[minionId] = NewMinionBucket()
    end
    return fight.minions[minionId]
end

local function GetUnitBucket(fight, minionId, sourceGuid, sourceName)
    local bucket = GetFightBucket(fight, minionId)
    bucket.units = bucket.units or {}
    if not bucket.units[sourceGuid] then
        fight.unitCounters = fight.unitCounters or {}
        fight.unitCounters[minionId] = (fight.unitCounters[minionId] or 0) + 1
        bucket.units[sourceGuid] = {
            guid = sourceGuid,
            label = (sourceName and sourceName ~= "") and sourceName or "Attack",
            attackIndex = fight.unitCounters[minionId],
            damage = 0,
            hits = 0,
            firstSeen = nil,
            lastSeen = nil,
            spells = {},
        }
    elseif sourceName and sourceName ~= "" and bucket.units[sourceGuid].label == "Attack" then
        bucket.units[sourceGuid].label = sourceName
    end
    return bucket.units[sourceGuid]
end

local function BuildSpellRows(spellMap, parentDamage, uptime, units)
    local spells = {}
    for _, spellRow in pairs(spellMap or {}) do
        if spellRow.damage and spellRow.damage > 0 then
            table.insert(spells, {
                label = spellRow.label or "?",
                spellId = spellRow.spellId,
                damage = spellRow.damage,
                hits = spellRow.hits or 0,
                dps = spellRow.damage / uptime / units,
                share = spellRow.damage / parentDamage,
            })
        end
    end
    table.sort(spells, function(a, b)
        return a.damage > b.damage
    end)
    return spells
end

local function IsPlayerOwnedPet(flags)
    if not flags then
        return false
    end

    if BitAnd(flags, AFFILIATION_MINE) == 0 then
        return false
    end

    if BitAnd(flags, OBJECT_TYPE_PET + OBJECT_TYPE_GUARDIAN) ~= 0 then
        return true
    end

    -- Ascension ghouls and other guardians often lack strict pet/guardian type bits.
    if BitAnd(flags, AFFILIATION_MINE + REACTION_FRIENDLY) == (AFFILIATION_MINE + REACTION_FRIENDLY) then
        return true
    end

    return BitAnd(flags, AFFILIATION_MINE + CONTROL_PLAYER) == (AFFILIATION_MINE + CONTROL_PLAYER)
end

local function GetCombatLogPayload(...)
    if Mancer.CombatLog and Mancer.CombatLog.GetPayload then
        return Mancer.CombatLog.GetPayload(...)
    end
    if select("#", ...) > 0 then
        return { ... }
    end
    if CombatLogGetCurrentEventInfo then
        return { CombatLogGetCurrentEventInfo() }
    end
    return {}
end

local function CollectGuidMapFromAdvisor()
    local guidMap = {}
    local advisor = GetAdvisor()
    if advisor and advisor.activeSummons then
        for guid, entry in pairs(advisor.activeSummons) do
            guidMap[guid] = entry.minionId
        end
    end
    return guidMap
end

local function IsValidMinionType(Advisor, minionId)
    return Advisor and minionId and Advisor.MINION_TYPES and Advisor.MINION_TYPES[minionId] ~= nil
end

local function CanTrackMinionType(Advisor, minionId)
    if not IsValidMinionType(Advisor, minionId) then
        return false
    end
    if minionId == "lesser_zombie" then
        return Advisor.HasUnrelentingArmy and Advisor:HasUnrelentingArmy()
    end
    return true
end

function MinionDps:SyncGuidMapFromAdvisor()
    local fight = self:GetCurrentFight()
    fight.guidMap = fight.guidMap or {}
    for guid, minionId in pairs(CollectGuidMapFromAdvisor()) do
        fight.guidMap[guid] = minionId
        if CanTrackMinionType(GetAdvisor(), minionId) then
            self:TagGuidForMinion(guid, minionId)
        end
    end
end

local function IsSharedMinionAttack(normalizedSpell, eventType)
    if eventType == "SWING_DAMAGE" then
        return true
    end
    return normalizedSpell == "Melee" or normalizedSpell == "Bone Club"
end

local function AcceptMinionId(Advisor, minionId)
    if CanTrackMinionType(Advisor, minionId) then
        return minionId
    end
    return nil
end

local function CountActiveSummons(Advisor, minionId)
    local count = 0
    if not Advisor or not Advisor.activeSummons then
        return count
    end
    for _, entry in pairs(Advisor.activeSummons) do
        if entry.minionId == minionId then
            count = count + 1
        end
    end
    return count
end

local function IsMinionTypeActive(Advisor, minionId)
    if not Advisor or not minionId then
        return false
    end

    if Advisor.GetCachedAuraCounts then
        local counts = Advisor:GetCachedAuraCounts()
        if counts and (counts[minionId] or 0) > 0 then
            return true
        end
    end

    if Advisor.temporaryActive then
        local now = GetTime and GetTime() or 0
        if (Advisor.temporaryActive[minionId] or 0) > now then
            return true
        end
    end

    if Advisor.activeSummons then
        for _, entry in pairs(Advisor.activeSummons) do
            if entry.minionId == minionId then
                return true
            end
        end
    end

    return false
end

function MinionDps:ResolveMinionFromActiveBuffs(sourceGuid)
    local Advisor = GetAdvisor()
    if not Advisor or not Advisor.GetCachedAuraCounts then
        return nil
    end

    if sourceGuid and self.guidTypeCache and self.guidTypeCache[sourceGuid] then
        return self.guidTypeCache[sourceGuid]
    end

    local counts = Advisor:GetCachedAuraCounts()
    local bestId, bestCount = nil, 0
    for minionId, amount in pairs(counts) do
        if minionId ~= "lesser_zombie" and amount > bestCount then
            bestCount = amount
            bestId = minionId
        end
    end

    return bestId
end

function MinionDps:ResetCurrentFight()
    self.currentFight = {
        startedAt = nil,
        endedAt = nil,
        minions = {},
        playerSpells = {},
        guidMap = {},
        peakCounts = {},
        knownGhoulGuids = {},
        knownZombieGuids = {},
        unitCounters = {},
        openSummons = {},
    }
    self.guidTypeCache = {}
end

function MinionDps:FightHasDamage(fight)
    if not fight then
        return false
    end
    for _, bucket in pairs(fight.minions or {}) do
        if bucket.damage and bucket.damage > 0 then
            return true
        end
    end
    return PlayerSpellsHaveData(fight)
end

function MinionDps:CopyFight(fight)
    if not fight then
        return nil
    end
    local copy = {
        startedAt = fight.startedAt,
        endedAt = fight.endedAt,
        minions = {},
        playerSpells = CopyPlayerSpellBuckets(fight.playerSpells),
        guidMap = {},
        peakCounts = {},
        knownGhoulGuids = CopyGuidSet(fight.knownGhoulGuids),
        knownZombieGuids = CopyGuidSet(fight.knownZombieGuids),
    }
    for minionId, bucket in pairs(fight.minions or {}) do
        copy.minions[minionId] = {
            damage = bucket.damage or 0,
            hits = bucket.hits or 0,
            firstSeen = bucket.firstSeen,
            lastSeen = bucket.lastSeen,
            activeSeconds = bucket.activeSeconds or 0,
            summonCount = bucket.summonCount or 0,
            spells = CopySpellBuckets(bucket.spells),
            units = CopyUnitBuckets(bucket.units),
        }
    end
    for guid, minionId in pairs(fight.guidMap or {}) do
        copy.guidMap[guid] = minionId
    end
    for minionId, amount in pairs(fight.peakCounts or {}) do
        copy.peakCounts[minionId] = amount
    end
    return copy
end

function MinionDps:Init()
    EnsureDb()
    if not self.currentFight then
        self:ResetCurrentFight()
    end
    self.inCombat = self.inCombat or false
    self.debugTotal = self.debugTotal or 0
    self.debugHit = self.debugHit or 0
    self.debugMiss = self.debugMiss or 0
    self.debugCleuRaw = self.debugCleuRaw or 0
    self:EnsureCombatLogListener()
end

local CLEU_HANDLER_VERSION = 5

function MinionDps:EnsureCombatLogListener()
    if self.cleuFrame and self.cleuHandlerVersion == CLEU_HANDLER_VERSION then
        return
    end

    if not self.cleuFrame then
        self.cleuFrame = CreateFrame("Frame")
        self.cleuFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end

    self.cleuHandlerVersion = CLEU_HANDLER_VERSION
    self.cleuFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            MinionDps:ProcessCleuEvent(...)
        end
    end)
end

function MinionDps:ProcessCleuEvent(...)
    self:Init()
    self.debugCleuRaw = (self.debugCleuRaw or 0) + 1
    self.lastCleuArgCount = select("#", ...)

    local parsed = Mancer.CombatLog and Mancer.CombatLog.Parse and Mancer.CombatLog.Parse(...)
    if parsed and parsed.eventType then
        self.lastCleuToken = parsed.eventType
        self.lastParseMode = parsed.parseMode
        self.debugParseOk = (self.debugParseOk or 0) + 1
    else
        self.debugParseFail = (self.debugParseFail or 0) + 1
        return
    end

    if not DAMAGE_EVENTS[parsed.eventType] then
        if AURA_EVENTS[parsed.eventType] or parsed.eventType == "SPELL_CAST_SUCCESS" then
            self:HandlePlayerTrackedEvent(parsed)
        end
        if parsed.eventType == "SPELL_SUMMON" and parsed.destGUID then
            local playerGuid = UnitGUID("player")
            local Advisor = GetAdvisor()
            local isMySummon = playerGuid and parsed.sourceGUID
                and Advisor and Advisor.GuidsMatch
                and Advisor:GuidsMatch(parsed.sourceGUID, playerGuid)
            if isMySummon and Advisor then
                local minionId = Advisor:ClassifyMinionName(parsed.destName)
                if Advisor.IsLesserZombieSummon
                    and Advisor:IsLesserZombieSummon(parsed.destName, parsed.spellId, parsed.spellName) then
                    minionId = "lesser_zombie"
                end
                if minionId and CanTrackMinionType(Advisor, minionId) then
                    self:RegisterSummonGuid(parsed.destGUID, minionId)
                end
            end
        elseif parsed.eventType == "UNIT_DIED" or parsed.eventType == "UNIT_DESTROYED" or parsed.eventType == "PARTY_KILL" then
            if parsed.destGUID then
                self:CloseSummonGuid(parsed.destGUID, "died")
            end
        end
        return
    end

    self.debugTotal = (self.debugTotal or 0) + 1
    self.lastParsedAmount = parsed.amount
    self.lastParsedSpell = parsed.spellName

    if not IsNecromancerPlayer() then
        return
    end

    self:SyncGuidMapFromAdvisor()

    local amount = parsed.amount or 0
    if amount <= 0 then
        self.debugMiss = (self.debugMiss or 0) + 1
        self.lastMiss = {
            event = parsed.eventType,
            name = parsed.sourceName,
            flags = parsed.sourceFlags,
            spell = parsed.spellName,
            spellId = parsed.spellId,
            amount = amount,
            reason = "zero amount",
        }
        return
    end

    -- Tracked player DoTs (Blight / Harvest Plague): log under playerSpells, not minions.
    if self:HandlePlayerTrackedEvent(parsed) then
        self.debugHit = (self.debugHit or 0) + 1
        return
    end

    local playerGuid = UnitGUID("player")
    if parsed.sourceGUID and playerGuid and IsPlayerGuid(parsed.sourceGUID) then
        self.debugMiss = (self.debugMiss or 0) + 1
        self.lastMiss = {
            event = parsed.eventType,
            name = parsed.sourceName,
            flags = parsed.sourceFlags,
            spell = parsed.spellName,
            spellId = parsed.spellId,
            amount = amount,
            reason = "player source",
        }
        return
    end

    local Advisor = GetAdvisor()
    if Advisor and Advisor.IsPlayerDamageSpell and Advisor:IsPlayerDamageSpell(parsed.spellName, parsed.spellId) then
        self.debugMiss = (self.debugMiss or 0) + 1
        self.lastMiss = {
            event = parsed.eventType,
            name = parsed.sourceName,
            flags = parsed.sourceFlags,
            spell = parsed.spellName,
            spellId = parsed.spellId,
            amount = amount,
            reason = "player spell",
        }
        return
    end

    local minionId = self:ResolveMinionId(
        parsed.sourceGUID,
        parsed.sourceName,
        parsed.sourceFlags,
        parsed.spellId,
        parsed.spellName,
        parsed.eventType
    )
    if minionId then
        self.debugHit = (self.debugHit or 0) + 1
        self.lastParsedSourceGuid = parsed.sourceGUID and tostring(parsed.sourceGUID) or nil
        self:RecordDamage(minionId, amount, parsed.eventType, parsed.spellId, parsed.spellName, parsed.sourceGUID, parsed.sourceName)
    else
        self.debugMiss = (self.debugMiss or 0) + 1
        self.lastMiss = {
            event = parsed.eventType,
            name = parsed.sourceName,
            flags = parsed.sourceFlags,
            spell = parsed.spellName,
            spellId = parsed.spellId,
            amount = amount,
        }
    end
end

function MinionDps:OnCombatLogEvent(...)
    self:ProcessCleuEvent(...)
end

function MinionDps:GetCurrentFight()
    self:Init()
    return self.currentFight
end

function MinionDps:FightFingerprint(fight)
    if not fight then
        return nil
    end
    local damage = 0
    for _, bucket in pairs(fight.minions or {}) do
        damage = damage + (bucket.damage or 0)
    end
    return string.format(
        "%.3f:%.3f:%.0f",
        tonumber(fight.startedAt) or 0,
        tonumber(fight.endedAt) or 0,
        damage
    )
end

-- Persist a finished pull into the session (Details-style). Dedupes identical commits.
function MinionDps:CommitFight(fight)
    if not fight or not self:FightHasDamage(fight) then
        return false
    end
    self:UpdatePeakCounts(fight)
    fight.endedAt = fight.endedAt or GetTimeNow()
    fight.startedAt = fight.startedAt or fight.endedAt

    local fp = self:FightFingerprint(fight)
    if fp and self.lastCommittedFp == fp then
        return "already_saved"
    end

    self:SaveFight(fight)
    self.lastCommittedFp = fp
    return true
end

function MinionDps:OnCombatStart()
    self:Init()
    self.inCombat = true

    -- New pull: commit any leftover pending segment, then start fresh (like Details).
    if self.pendingFight and self:FightHasDamage(self.pendingFight) then
        self:CommitFight(self.pendingFight)
        self.pendingFight = nil
    end

    local fight = self.currentFight
    local hasDamage = false
    for _, bucket in pairs(fight.minions or {}) do
        if bucket.damage and bucket.damage > 0 then
            hasDamage = true
            break
        end
    end

    local guidMap = CollectGuidMapFromAdvisor()
    if hasDamage and fight.startedAt then
        fight.guidMap = fight.guidMap or {}
        for guid, minionId in pairs(guidMap) do
            fight.guidMap[guid] = minionId
        end
        return
    end

    self:ResetCurrentFight()
    self.currentFight.guidMap = guidMap
    self.currentFight.startedAt = GetTimeNow()
end

function MinionDps:OnCombatEnd()
    self:Init()
    if not self.inCombat and not self.currentFight.startedAt then
        return
    end

    self.inCombat = false
    local fight = self.currentFight
    self:FlushAllOpenSummons(fight)
    fight.endedAt = GetTimeNow()
    if not fight.startedAt then
        fight.startedAt = fight.endedAt
    end

    if self:FightHasDamage(fight) then
        self:UpdatePeakCounts(fight)
        local copy = self:CopyFight(fight)
        self.pendingFight = copy
        -- Auto-save into session — no manual Save Fight needed for normal combat.
        self:CommitFight(copy)
    end

    self:ResetCurrentFight()
end

function MinionDps:SaveCurrentFight()
    self:Init()
    self:SyncGuidMapFromAdvisor()

    local fight = self.currentFight
    if self:FightHasDamage(fight) then
        self:FlushAllOpenSummons(fight)
        fight.startedAt = fight.startedAt or GetTimeNow()
        fight.endedAt = GetTimeNow()
        local result = self:CommitFight(fight)
        self:ResetCurrentFight()
        self.inCombat = false
        self.pendingFight = nil
        return result
    end

    if self.pendingFight and self:FightHasDamage(self.pendingFight) then
        local pending = self.pendingFight
        pending.endedAt = pending.endedAt or GetTimeNow()
        local result = self:CommitFight(pending)
        self.pendingFight = nil
        self:ResetCurrentFight()
        self.inCombat = false
        return result
    end

    local db = EnsureDb()
    local last = db.fights[1]
    if last and self:FightHasDamage(last) then
        local now = GetTimeNow()
        local endedAt = last.endedAt or last.startedAt or 0
        if endedAt > 0 and (now - endedAt) < 120 then
            return "already_saved"
        end
    end

    return false
end

function MinionDps:SaveFight(fight)
    local db = EnsureDb()
    table.insert(db.fights, 1, self:CopyFight(fight))
    while #db.fights > MAX_SAVED_FIGHTS do
        table.remove(db.fights)
    end
end

function MinionDps:ResetSession()
    local db = EnsureDb()
    db.fights = {}
    self:ResetCurrentFight()
    self.pendingFight = nil
    self.lastCommittedFp = nil
    self.inCombat = false
    self.debugTotal = 0
    self.debugHit = 0
    self.debugMiss = 0
    self.debugCleuRaw = 0
    self.debugParseOk = 0
    self.debugParseFail = 0
    self.lastMiss = nil
    self.lastCleuToken = nil
    self.lastCleuArgCount = nil
    self.lastParseMode = nil
    self.lastParsedAmount = nil
    self.lastParsedSpell = nil
end

local function EnsureFightGuidSets(fight)
    fight.knownGhoulGuids = fight.knownGhoulGuids or {}
    fight.knownZombieGuids = fight.knownZombieGuids or {}
end

function MinionDps:TagGuidForMinion(sourceGuid, minionId)
    if not sourceGuid or not minionId then
        return
    end

    local fight = self:GetCurrentFight()
    EnsureFightGuidSets(fight)
    fight.guidMap = fight.guidMap or {}
    fight.guidMap[sourceGuid] = minionId

    if minionId == "lesser_zombie" then
        fight.knownZombieGuids[sourceGuid] = true
        fight.knownGhoulGuids[sourceGuid] = nil
    elseif minionId == "ghoul" then
        fight.knownGhoulGuids[sourceGuid] = true
    end

    self.guidTypeCache = self.guidTypeCache or {}
    self.guidTypeCache[sourceGuid] = minionId
end

function MinionDps:RegisterSummonGuid(guid, minionId)
    if not guid or not minionId then
        return
    end
    local fight = self:GetCurrentFight()
    self:TagGuidForMinion(guid, minionId)
    if not fight.startedAt then
        fight.startedAt = GetTimeNow()
    end

    fight.openSummons = fight.openSummons or {}
    if fight.openSummons[guid] then
        return
    end

    local now = GetTimeNow()
    local duration = GetTempDuration(minionId)
    fight.openSummons[guid] = {
        minionId = minionId,
        start = now,
        expiresAt = duration and (now + duration) or nil,
    }

    local bucket = GetFightBucket(fight, minionId)
    bucket.summonCount = (bucket.summonCount or 0) + 1
end

function MinionDps:CloseSummonGuid(guid, reason)
    if not guid then
        return
    end
    local fight = self:GetCurrentFight()
    if not fight or not fight.openSummons or not fight.openSummons[guid] then
        -- Still clear maps when Advisor reports death.
        self:UnregisterSummonGuid(guid)
        return
    end

    local info = fight.openSummons[guid]
    local now = GetTimeNow()
    local endAt = now
    if info.expiresAt and info.expiresAt < endAt then
        endAt = info.expiresAt
    end
    local lived = math.max(0, endAt - (info.start or now))
    local bucket = GetFightBucket(fight, info.minionId)
    bucket.activeSeconds = (bucket.activeSeconds or 0) + lived
    fight.openSummons[guid] = nil

    self:UnregisterSummonGuid(guid)
end

function MinionDps:FlushExpiredOpenSummons(fight, now)
    fight = fight or self:GetCurrentFight()
    if not fight or not fight.openSummons then
        return
    end
    now = now or GetTimeNow()
    local toClose = {}
    for guid, info in pairs(fight.openSummons) do
        if info.expiresAt and info.expiresAt <= now then
            table.insert(toClose, guid)
        end
    end
    for _, guid in ipairs(toClose) do
        self:CloseSummonGuid(guid, "expired")
    end
end

function MinionDps:FlushAllOpenSummons(fight)
    fight = fight or self:GetCurrentFight()
    if not fight or not fight.openSummons then
        self:FlushAllOpenPlayerAuras(fight)
        return
    end
    self:FlushExpiredOpenSummons(fight)
    local remaining = {}
    for guid in pairs(fight.openSummons) do
        table.insert(remaining, guid)
    end
    for _, guid in ipairs(remaining) do
        self:CloseSummonGuid(guid, "combat_end")
    end
    self:FlushAllOpenPlayerAuras(fight)
end

function MinionDps:OpenPlayerDotAura(def, destGuid, destName, spellId)
    if not def or (def.kind ~= "dot" and def.kind ~= "spell") or not destGuid then
        return
    end
    local fight = self:GetCurrentFight()
    if not fight.startedAt then
        fight.startedAt = GetTimeNow()
    end
    local spellBucket = GetPlayerSpellBucket(fight, def)
    if spellId then
        spellBucket.spellId = spellId
    end
    local target = GetPlayerTargetBucket(spellBucket, destGuid, destName)
    local now = GetTimeNow()
    target.firstSeen = target.firstSeen or now
    target.lastSeen = now
    if not target.openStart then
        target.openStart = now
        local open = CountOpenPlayerTargets(spellBucket)
        if open > (spellBucket.peakTargets or 0) then
            spellBucket.peakTargets = open
        end
    end
end

function MinionDps:ClosePlayerDotAura(def, destGuid, destName)
    if not def or (def.kind ~= "dot" and def.kind ~= "spell") or not destGuid then
        return
    end
    local fight = self:GetCurrentFight()
    local spellBucket = GetPlayerSpellBucket(fight, def)
    local target = spellBucket.targets and spellBucket.targets[destGuid]
    if not target or not target.openStart then
        return
    end
    local now = GetTimeNow()
    local lived = math.max(0, now - target.openStart)
    target.activeSeconds = (target.activeSeconds or 0) + lived
    spellBucket.activeSeconds = (spellBucket.activeSeconds or 0) + lived
    target.openStart = nil
    target.lastSeen = now
    if destName and destName ~= "" then
        target.name = destName
    end
end

function MinionDps:RecordPlayerProc(def, spellId)
    if not def or def.kind ~= "proc" then
        return
    end
    local fight = self:GetCurrentFight()
    if not fight.startedAt then
        fight.startedAt = GetTimeNow()
    end
    local spellBucket = GetPlayerSpellBucket(fight, def)
    if spellId then
        spellBucket.spellId = spellId
    end
    spellBucket.procs = (spellBucket.procs or 0) + 1
end

function MinionDps:RecordPlayerCast(def, spellId)
    if not def or def.kind == "proc" then
        return
    end
    local fight = self:GetCurrentFight()
    if not fight.startedAt then
        fight.startedAt = GetTimeNow()
    end
    local spellBucket = GetPlayerSpellBucket(fight, def)
    if spellId then
        spellBucket.spellId = spellId
    end
    spellBucket.casts = (spellBucket.casts or 0) + 1
end

function MinionDps:RecordPlayerSpellDamage(def, amount, destGuid, destName, spellId)
    if not def or not amount or amount <= 0 then
        return
    end
    local fight = self:GetCurrentFight()
    if not fight.startedAt then
        fight.startedAt = GetTimeNow()
    end
    local spellBucket = GetPlayerSpellBucket(fight, def)
    if spellId then
        spellBucket.spellId = spellId
    end
    spellBucket.damage = (spellBucket.damage or 0) + amount
    spellBucket.hits = (spellBucket.hits or 0) + 1

    if def.kind == "dot" or def.kind == "spell" then
        -- Damage ticks also open the window if CLEU missed APPLIED.
        self:OpenPlayerDotAura(def, destGuid or "unknown", destName, spellId)
        local target = GetPlayerTargetBucket(spellBucket, destGuid or "unknown", destName)
        local now = GetTimeNow()
        target.firstSeen = target.firstSeen or now
        target.lastSeen = now
        target.damage = (target.damage or 0) + amount
        target.hits = (target.hits or 0) + 1
    end
end

function MinionDps:FlushAllOpenPlayerAuras(fight)
    fight = fight or self:GetCurrentFight()
    if not fight or not fight.playerSpells then
        return
    end
    local now = fight.endedAt or GetTimeNow()
    for _, spellBucket in pairs(fight.playerSpells) do
        for _, target in pairs(spellBucket.targets or {}) do
            if target.openStart then
                local lived = math.max(0, now - target.openStart)
                target.activeSeconds = (target.activeSeconds or 0) + lived
                spellBucket.activeSeconds = (spellBucket.activeSeconds or 0) + lived
                target.openStart = nil
                target.lastSeen = now
            end
        end
    end
end

function MinionDps:HandlePlayerTrackedEvent(parsed)
    if not parsed or not IsNecromancerPlayer() then
        return false
    end

    local def = ResolvePlayerTracked(parsed.spellId, parsed.spellName)
    if not def then
        return false
    end

    local eventType = parsed.eventType
    local fromPlayer = IsPlayerGuid(parsed.sourceGUID)
    local onPlayer = IsPlayerGuid(parsed.destGUID)

    if def.kind == "proc" then
        -- Bone King / Diabolical: count applies (and refreshes) on the player.
        if onPlayer and (eventType == "SPELL_AURA_APPLIED" or eventType == "SPELL_AURA_REFRESH") then
            self:RecordPlayerProc(def, parsed.spellId)
            return true
        end
        return false
    end

    -- DoTs / player spells must come from the player onto enemies.
    if not fromPlayer then
        return false
    end

    if eventType == "SPELL_CAST_SUCCESS" then
        self:RecordPlayerCast(def, parsed.spellId)
        -- Cast success often has no dest; open on current target so uptime still counts.
        local destGuid = parsed.destGUID
        local destName = parsed.destName
        if (not destGuid or onPlayer) and UnitExists and UnitExists("target") and UnitCanAttack and UnitCanAttack("player", "target") then
            destGuid = UnitGUID and UnitGUID("target")
            destName = UnitName and UnitName("target")
        end
        if destGuid and not IsPlayerGuid(destGuid) then
            self:OpenPlayerDotAura(def, destGuid, destName, parsed.spellId)
        end
        return true
    end

    if eventType == "SPELL_AURA_APPLIED" or eventType == "SPELL_AURA_REFRESH" or eventType == "SPELL_AURA_APPLIED_DOSE" then
        if parsed.destGUID and not onPlayer then
            self:OpenPlayerDotAura(def, parsed.destGUID, parsed.destName, parsed.spellId)
            return true
        end
    elseif eventType == "SPELL_AURA_REMOVED" or eventType == "SPELL_AURA_REMOVED_DOSE" then
        -- Only full REMOVED closes; REMOVED_DOSE still has the aura.
        if eventType == "SPELL_AURA_REMOVED" and parsed.destGUID and not onPlayer then
            self:ClosePlayerDotAura(def, parsed.destGUID, parsed.destName)
            return true
        end
    elseif DAMAGE_EVENTS[eventType] then
        local amount = parsed.amount or 0
        if amount > 0 then
            self:RecordPlayerSpellDamage(def, amount, parsed.destGUID, parsed.destName, parsed.spellId)
            return true
        end
    end

    return false
end

function MinionDps:UnregisterSummonGuid(guid)
    if not guid then
        return
    end
    local fight = self:GetCurrentFight()
    if fight.guidMap then
        fight.guidMap[guid] = nil
    end
    if fight.knownGhoulGuids then
        fight.knownGhoulGuids[guid] = nil
    end
    if fight.knownZombieGuids then
        fight.knownZombieGuids[guid] = nil
    end
end

-- Open a synthetic lifetime when we first see damage from a CD Animate GUID
-- (SPELL_SUMMON can be missing on some Ascension client paths).
function MinionDps:EnsureOpenSummonFromDamage(guid, minionId)
    if not guid or not minionId or not IsTemporaryMinion(minionId) then
        return
    end
    local fight = self:GetCurrentFight()
    fight.openSummons = fight.openSummons or {}
    if fight.openSummons[guid] then
        return
    end
    local now = GetTimeNow()
    local duration = GetTempDuration(minionId)
    fight.openSummons[guid] = {
        minionId = minionId,
        start = now,
        expiresAt = duration and (now + duration) or nil,
        synthetic = true,
    }
    local bucket = GetFightBucket(fight, minionId)
    bucket.summonCount = (bucket.summonCount or 0) + 1
end

local function NormalizeSpellToken(Advisor, spellName)
    if not spellName then
        return nil
    end
    if Advisor and Advisor.NormalizeSpellName then
        return Advisor:NormalizeSpellName(spellName)
    end
    return spellName
end

function MinionDps:ResolveMinionId(sourceGuid, sourceName, sourceFlags, spellId, spellName, eventType)
    local Advisor = GetAdvisor()
    if not Advisor then
        return nil
    end

    local playerGuid = UnitGUID("player")

    if sourceGuid and playerGuid and sourceGuid == playerGuid then
        return nil
    end

    self:SyncGuidMapFromAdvisor()

    local fight = self:GetCurrentFight()
    EnsureFightGuidSets(fight)

    local normalizedSpell = NormalizeSpellToken(Advisor, spellName)

    -- Signature spells override stale GUID tags (proc zombies often melee before Zombie Plague).
    if normalizedSpell == "Zombie Plague" and Advisor:HasUnrelentingArmy() then
        if sourceGuid then
            self:TagGuidForMinion(sourceGuid, "lesser_zombie")
        end
        return "lesser_zombie"
    end

    if normalizedSpell == "Command: Ghouls" then
        if sourceGuid then
            self:TagGuidForMinion(sourceGuid, "ghoul")
        end
        return "ghoul"
    end

    if sourceGuid and fight.knownZombieGuids[sourceGuid] then
        return "lesser_zombie"
    end

    if sourceGuid and fight.knownGhoulGuids[sourceGuid] then
        return "ghoul"
    end

    if sourceGuid then
        local sig = GuidCreatureSig(sourceGuid)
        local fromSig = sig and GUID_CREATURE_SIGS[sig]
        if fromSig then
            self:TagGuidForMinion(sourceGuid, fromSig)
            return AcceptMinionId(Advisor, fromSig)
        end
    end

    if sourceGuid and fight.guidMap and fight.guidMap[sourceGuid] then
        return AcceptMinionId(Advisor, fight.guidMap[sourceGuid])
    end

    if Advisor.activeSummons and sourceGuid and Advisor.activeSummons[sourceGuid] then
        local minionId = AcceptMinionId(Advisor, Advisor.activeSummons[sourceGuid].minionId)
        if minionId and sourceGuid then
            self:TagGuidForMinion(sourceGuid, minionId)
        end
        return minionId
    end

    if sourceName then
        local fromName = Advisor:ClassifyMinionName(sourceName)
        if fromName and fromName ~= "ghoul" then
            if sourceGuid then
                self:TagGuidForMinion(sourceGuid, fromName)
            end
            return AcceptMinionId(Advisor, fromName)
        end
    end

    if IsPlayerOwnedPet(sourceFlags) and sourceGuid and Advisor:HasUnrelentingArmy() then
        if fight.knownZombieGuids[sourceGuid] then
            return "lesser_zombie"
        end
        if normalizedSpell == "Zombie Plague" then
            self:TagGuidForMinion(sourceGuid, "lesser_zombie")
            return "lesser_zombie"
        end
        if fight.knownGhoulGuids[sourceGuid] then
            return "ghoul"
        end
    end

    if sourceName then
        local fromName = Advisor:ClassifyMinionName(sourceName)
        if fromName then
            if fromName == "ghoul" and Advisor:HasUnrelentingArmy() then
                if sourceGuid and fight.knownGhoulGuids[sourceGuid] then
                    return "ghoul"
                end
                local summonEntry = Advisor.activeSummons and sourceGuid and Advisor.activeSummons[sourceGuid]
                if summonEntry and summonEntry.minionId == "ghoul" then
                    return "ghoul"
                end
            else
                if sourceGuid then
                    self:TagGuidForMinion(sourceGuid, fromName)
                end
                return AcceptMinionId(Advisor, fromName)
            end
        end
    end

    if IsSharedMinionAttack(normalizedSpell, eventType) and IsPlayerOwnedPet(sourceFlags) and sourceGuid then
        if fight.knownZombieGuids[sourceGuid] then
            return "lesser_zombie"
        end
        if fight.knownGhoulGuids[sourceGuid] then
            return "ghoul"
        end
        if fight.guidMap and fight.guidMap[sourceGuid] then
            return AcceptMinionId(Advisor, fight.guidMap[sourceGuid])
        end
        if Advisor.activeSummons and Advisor.activeSummons[sourceGuid] then
            local summonId = AcceptMinionId(Advisor, Advisor.activeSummons[sourceGuid].minionId)
            if summonId then
                self:TagGuidForMinion(sourceGuid, summonId)
                return summonId
            end
        end
    end

    if IsPlayerOwnedPet(sourceFlags) then
        if sourceGuid and fight.knownGhoulGuids[sourceGuid] then
            return "ghoul"
        end
        if sourceGuid and fight.knownZombieGuids[sourceGuid] then
            return "lesser_zombie"
        end
        local fromBuffs = self:ResolveMinionFromActiveBuffs(sourceGuid)
        if fromBuffs and fromBuffs ~= "lesser_zombie" then
            return AcceptMinionId(Advisor, fromBuffs)
        end
    end

    if sourceGuid and playerGuid and sourceGuid ~= playerGuid then
        if fight.knownZombieGuids[sourceGuid] then
            return "lesser_zombie"
        end
        if fight.knownGhoulGuids[sourceGuid] then
            return "ghoul"
        end
    end

    if Advisor.ClassifyMinionDamageSpell then
        local fromSpell = Advisor:ClassifyMinionDamageSpell(spellName, spellId)
        if fromSpell and IsMinionTypeActive(Advisor, fromSpell) then
            if sourceGuid and fromSpell ~= "ghoul" then
                self:TagGuidForMinion(sourceGuid, fromSpell)
            elseif sourceGuid and normalizedSpell == "Command: Ghouls" then
                self:TagGuidForMinion(sourceGuid, "ghoul")
            end
            return AcceptMinionId(Advisor, fromSpell)
        end
    end

    return nil
end

function MinionDps:UpdatePeakCounts(fight)
    local Advisor = GetAdvisor()
    if not Advisor or not Advisor.GetCachedAuraCounts then
        return
    end

    fight.peakCounts = fight.peakCounts or {}
    local counts = Advisor:GetCachedAuraCounts()
    for minionId, amount in pairs(counts) do
        if amount > (fight.peakCounts[minionId] or 0) then
            fight.peakCounts[minionId] = amount
        end
    end

    local summonPeaks = {}
    for _, entry in pairs(Advisor.activeSummons or {}) do
        if entry.minionId then
            summonPeaks[entry.minionId] = (summonPeaks[entry.minionId] or 0) + 1
        end
    end
    for minionId, amount in pairs(summonPeaks) do
        if amount > (fight.peakCounts[minionId] or 0) then
            fight.peakCounts[minionId] = amount
        end
    end
end

function MinionDps:RecordDamage(minionId, amount, eventType, spellId, spellName, sourceGuid, sourceName)
    if not minionId or not amount or amount <= 0 then
        return
    end

    local fight = self:GetCurrentFight()
    if not fight.startedAt then
        fight.startedAt = GetTimeNow()
    end

    local now = GetTimeNow()
    self:FlushExpiredOpenSummons(fight, now)
    if sourceGuid then
        self:EnsureOpenSummonFromDamage(sourceGuid, minionId)
    end

    local bucket = GetFightBucket(fight, minionId)
    bucket.damage = bucket.damage + amount
    bucket.hits = bucket.hits + 1
    bucket.firstSeen = bucket.firstSeen or now
    bucket.lastSeen = now

    local label, resolvedSpellId = ResolveSpellLabel(eventType, spellId, spellName)
    local spellKey = GetSpellKey(resolvedSpellId, label)
    local spellBucket = GetSpellBucket(bucket, spellKey, label, resolvedSpellId)
    spellBucket.damage = spellBucket.damage + amount
    spellBucket.hits = spellBucket.hits + 1

    if UsesUnitBreakdown(minionId) and IsValidPetGuid(sourceGuid) then
        self.debugUnitHits = (self.debugUnitHits or 0) + 1
        self.lastRecordGuid = tostring(sourceGuid)
        local unitBucket = GetUnitBucket(fight, minionId, sourceGuid, sourceName)
        unitBucket.damage = unitBucket.damage + amount
        unitBucket.hits = unitBucket.hits + 1
        unitBucket.firstSeen = unitBucket.firstSeen or now
        unitBucket.lastSeen = now
        local unitSpellBucket = GetSpellBucket(unitBucket, spellKey, label, resolvedSpellId)
        unitSpellBucket.damage = unitSpellBucket.damage + amount
        unitSpellBucket.hits = unitSpellBucket.hits + 1

        local unitCount = 0
        for _ in pairs(bucket.units or {}) do
            unitCount = unitCount + 1
        end
        fight.peakCounts[minionId] = math.max(fight.peakCounts[minionId] or 0, unitCount)
    elseif UsesUnitBreakdown(minionId) then
        self.debugNoGuidHits = (self.debugNoGuidHits or 0) + 1
    end

    fight.peakCounts = fight.peakCounts or {}
    fight.peakCounts[minionId] = math.max(fight.peakCounts[minionId] or 0, 1)
end

function MinionDps:HandleCombatLogEvent(...)
    self:ProcessCleuEvent(...)
end

function MinionDps:ProcessCombatLogEvent(...)
    self:ProcessCleuEvent(...)
end

function MinionDps:GetFightDuration(fight)
    if not fight then
        return 0
    end
    local startAt = fight.startedAt or 0
    local endAt = fight.endedAt or GetTimeNow()
    return math.max(1, endAt - startAt)
end

function MinionDps:GetMinionUptime(bucket, fightDuration)
    if not bucket then
        return fightDuration
    end
    -- Prefer accumulated summon lifetimes (unit-seconds) for Animate CD pets.
    if bucket.activeSeconds and bucket.activeSeconds > 0 then
        return math.max(1, bucket.activeSeconds)
    end
    if bucket.firstSeen and bucket.lastSeen then
        return math.max(1, bucket.lastSeen - bucket.firstSeen)
    end
    return fightDuration
end

function MinionDps:AggregateFightStats(fight)
    local stats = {}
    if fight then
        self:FlushExpiredOpenSummons(fight, fight.endedAt or GetTimeNow())
        -- Credit still-open summons against fight end without mutating mid-combat state
        -- only when fight has ended (endedAt set).
        if fight.endedAt and fight.openSummons then
            for guid, info in pairs(fight.openSummons) do
                local endAt = fight.endedAt
                if info.expiresAt and info.expiresAt < endAt then
                    endAt = info.expiresAt
                end
                local lived = math.max(0, endAt - (info.start or fight.endedAt))
                local bucket = GetFightBucket(fight, info.minionId)
                bucket.activeSeconds = (bucket.activeSeconds or 0) + lived
            end
            fight.openSummons = {}
        end
        if fight.endedAt then
            self:FlushAllOpenPlayerAuras(fight)
        end
    end
    local duration = self:GetFightDuration(fight)

    for minionId, bucket in pairs(fight.minions or {}) do
        if bucket.damage and bucket.damage > 0 then
            local activeSeconds = bucket.activeSeconds or 0
            local uptime = self:GetMinionUptime(bucket, duration)
            local units = 1
            if fight.peakCounts and fight.peakCounts[minionId] and fight.peakCounts[minionId] > 0 then
                units = fight.peakCounts[minionId]
            end
            -- When activeSeconds is unit-seconds, DPS/unit = damage / activeSeconds.
            local dpsPerUnit
            if activeSeconds > 0 then
                dpsPerUnit = bucket.damage / activeSeconds
            else
                dpsPerUnit = bucket.damage / uptime / units
            end
            local spells = BuildSpellRows(bucket.spells, bucket.damage, activeSeconds > 0 and activeSeconds or uptime, activeSeconds > 0 and 1 or units)
            local attacks = nil
            if UsesUnitBreakdown(minionId) and bucket.units then
                attacks = {}
                for _, unitBucket in pairs(bucket.units) do
                    if unitBucket.damage and unitBucket.damage > 0 then
                        local unitUptime = self:GetMinionUptime(unitBucket, duration)
                        table.insert(attacks, {
                            guid = unitBucket.guid,
                            label = unitBucket.label,
                            attackIndex = unitBucket.attackIndex or 0,
                            damage = unitBucket.damage,
                            hits = unitBucket.hits or 0,
                            dps = unitBucket.damage / unitUptime,
                            spells = BuildSpellRows(unitBucket.spells, unitBucket.damage, unitUptime, 1),
                        })
                    end
                end
                table.sort(attacks, function(a, b)
                    if a.attackIndex ~= b.attackIndex then
                        return a.attackIndex < b.attackIndex
                    end
                    return a.damage > b.damage
                end)
                if #attacks == 0 then
                    attacks = nil
                end
            end
            stats[minionId] = {
                damage = bucket.damage,
                hits = bucket.hits or 0,
                uptime = uptime,
                activeSeconds = activeSeconds,
                summonCount = bucket.summonCount or 0,
                units = units,
                dps = dpsPerUnit,
                spells = spells,
                attacks = attacks,
                temporary = IsTemporaryMinion(minionId),
            }
        end
    end

    return stats, duration
end

function MinionDps:AggregateSessionStats()
    local db = EnsureDb()
    local totals = {}
    local fightCount = 0

    for _, fight in ipairs(db.fights) do
        local fightStats = self:AggregateFightStats(fight)
        local hasData = false
        for minionId, row in pairs(fightStats) do
            hasData = true
            totals[minionId] = totals[minionId] or { dpsTotal = 0, damage = 0, hits = 0, samples = 0, spells = {} }
            totals[minionId].dpsTotal = totals[minionId].dpsTotal + row.dps
            totals[minionId].damage = totals[minionId].damage + row.damage
            totals[minionId].hits = totals[minionId].hits + row.hits
            totals[minionId].samples = totals[minionId].samples + 1
            for _, spellRow in ipairs(row.spells or {}) do
                local spellKey = GetSpellKey(spellRow.spellId, spellRow.label)
                local bucket = totals[minionId].spells[spellKey]
                if not bucket then
                    bucket = {
                        label = spellRow.label,
                        spellId = spellRow.spellId,
                        damage = 0,
                        hits = 0,
                    }
                    totals[minionId].spells[spellKey] = bucket
                end
                bucket.damage = bucket.damage + spellRow.damage
                bucket.hits = bucket.hits + spellRow.hits
            end
        end
        if hasData then
            fightCount = fightCount + 1
        end
    end

    local averages = {}
    for minionId, row in pairs(totals) do
        local spells = {}
        for _, spellRow in pairs(row.spells or {}) do
            if spellRow.damage and spellRow.damage > 0 then
                table.insert(spells, {
                    label = spellRow.label,
                    spellId = spellRow.spellId,
                    damage = spellRow.damage,
                    hits = spellRow.hits or 0,
                    share = spellRow.damage / math.max(1, row.damage),
                })
            end
        end
        table.sort(spells, function(a, b)
            return a.damage > b.damage
        end)
        averages[minionId] = {
            damage = row.damage,
            hits = row.hits,
            fights = row.samples,
            dps = row.dpsTotal / math.max(1, row.samples),
            spells = spells,
        }
    end

    return averages, fightCount
end

function MinionDps:GetBenchmarkEstimates()
    local level = UnitLevel and UnitLevel("player") or 30
    local tier = BENCHMARK_DPS[level]
    if not tier then
        -- Prefer high-level calibration once past early levels (more LF → more ghouls).
        if level >= 40 then
            tier = BENCHMARK_DPS[60]
        else
            tier = BENCHMARK_DPS[30]
        end
    end
    if not tier then
        return nil
    end

    local estimates = {}
    for minionId, dps in pairs(tier) do
        estimates[minionId] = {
            damage = 0,
            hits = 0,
            fights = 0,
            dps = dps,
        }
    end
    return estimates
end

function MinionDps:GetDpsEstimates()
    local session, fightCount = self:AggregateSessionStats()
    if fightCount >= SESSION_MIN_FIGHTS then
        return session, fightCount, "session"
    end

    local fight = self.currentFight
    if fight and fight.startedAt then
        local current = self:AggregateFightStats(fight)
        if next(current) then
            return current, 1, "current"
        end
    end

    local db = EnsureDb()
    if db.fights[1] then
        local last = self:AggregateFightStats(db.fights[1])
        if next(last) then
            return last, 1, "last"
        end
    end

    local benchmark = self:GetBenchmarkEstimates()
    if benchmark and next(benchmark) then
        return benchmark, 0, "benchmark"
    end

    return nil, 0, nil
end

function MinionDps:FormatNumber(value)
    if value >= 1000000 then
        return string.format("%.1fm", value / 1000000)
    end
    if value >= 1000 then
        return string.format("%.1fk", value / 1000)
    end
    return string.format("%.0f", value)
end

function MinionDps:GetMinionLabel(minionId)
    local Advisor = GetAdvisor()
    local def = Advisor and Advisor.MINION_TYPES and Advisor.MINION_TYPES[minionId]
    if minionId == "lesser_zombie" then
        return (def and def.label or "Lesser Zombie") .. " (proc)"
    end
    return (def and def.label) or minionId
end

function MinionDps:GetAttackLabel(attackRow)
    local index = attackRow.attackIndex or 0
    local name = attackRow.label
    if name and name ~= "" and name ~= "Attack" then
        return string.format("Attack %d (%s)", index, name)
    end
    return string.format("Attack %d", index)
end

function MinionDps:PrintSpellBreakdown(minionDamage, spells, duration, units, indent)
    if not spells or #spells == 0 then
        return
    end

    indent = indent or "    "
    units = units or 1
    duration = math.max(1, duration or 1)
    for _, spellRow in ipairs(spells) do
        local share = spellRow.share
        if not share and minionDamage and minionDamage > 0 then
            share = spellRow.damage / minionDamage
        end
        local spellDps = spellRow.dps
        if not spellDps then
            spellDps = spellRow.damage / duration / units
        end
        Mancer.Print(string.format(
            "%s- %s: %s dmg | %.1f%% | %d hits | %.0f DPS",
            indent,
            spellRow.label or "?",
            self:FormatNumber(spellRow.damage),
            (share or 0) * 100,
            spellRow.hits or 0,
            spellDps
        ))
    end
end

function MinionDps:PrintAttackBreakdown(attacks, duration)
    if not attacks or #attacks == 0 then
        return
    end

    duration = math.max(1, duration or 1)
    for _, attackRow in ipairs(attacks) do
        Mancer.Print(string.format(
            "    %s: %s dmg | %.0f DPS | %d hits",
            self:GetAttackLabel(attackRow),
            self:FormatNumber(attackRow.damage),
            attackRow.dps or (attackRow.damage / duration),
            attackRow.hits or 0
        ))
        self:PrintSpellBreakdown(attackRow.damage, attackRow.spells, duration, 1, "      ")
    end
end

function MinionDps:PrintPlayerSpellStats(fight, duration, opts)
    opts = opts or {}
    local printFn = opts.printFn or function(msg)
        Mancer.Print(msg)
    end
    if not fight or not fight.playerSpells then
        return
    end
    duration = math.max(1, duration or self:GetFightDuration(fight))

    local rows = {}
    for _, row in pairs(fight.playerSpells) do
        local targetCount = 0
        local openExtra = 0
        local now = fight.endedAt or GetTimeNow()
        for _, t in pairs(row.targets or {}) do
            targetCount = targetCount + 1
            if t.openStart then
                openExtra = openExtra + math.max(0, now - t.openStart)
            end
        end
        local unitSec = (row.activeSeconds or 0) + openExtra
        local hasData = (row.damage or 0) > 0
            or (row.procs or 0) > 0
            or (row.casts or 0) > 0
            or unitSec > 0
            or targetCount > 0
        if hasData then
            table.insert(rows, { row = row, targetCount = targetCount, unitSec = unitSec })
        end
    end
    if #rows == 0 then
        return
    end

    table.sort(rows, function(a, b)
        local ad = a.row.damage or 0
        local bd = b.row.damage or 0
        if ad ~= bd then
            return ad > bd
        end
        return (a.row.procs or 0) > (b.row.procs or 0)
    end)

    printFn("Player spells:")
    for _, entry in ipairs(rows) do
        local row = entry.row
        if row.kind == "proc" then
            printFn(string.format(
                "  %s: %d procs",
                row.label or "?",
                row.procs or 0
            ))
        else
            local parts = {
                string.format("%s: %s dmg", row.label or "?", self:FormatNumber(row.damage or 0)),
            }
            if (row.casts or 0) > 0 then
                table.insert(parts, string.format("%d cast%s", row.casts, row.casts == 1 and "" or "s"))
            end
            if (row.damage or 0) > 0 then
                table.insert(parts, string.format("%.0f DPS", (row.damage or 0) / duration))
            end
            if entry.targetCount > 0 then
                table.insert(parts, string.format("%d target%s", entry.targetCount, entry.targetCount == 1 and "" or "s"))
            end
            if (entry.unitSec or 0) > 0 then
                table.insert(parts, string.format("%.1fs unit-sec", entry.unitSec))
            end
            if (row.peakTargets or 0) > 1 then
                table.insert(parts, string.format("peak %d", row.peakTargets))
            end
            if (row.hits or 0) > 0 then
                table.insert(parts, string.format("%d hits", row.hits))
            end
            printFn("  " .. table.concat(parts, " | "))

            -- Per-target breakdown (top 6 by damage, then uptime).
            local targets = {}
            for _, t in pairs(row.targets or {}) do
                table.insert(targets, t)
            end
            table.sort(targets, function(a, b)
                local ad = a.damage or 0
                local bd = b.damage or 0
                if ad ~= bd then
                    return ad > bd
                end
                return (a.activeSeconds or 0) > (b.activeSeconds or 0)
            end)
            local shown = 0
            for _, t in ipairs(targets) do
                if shown >= 20 then
                    local left = #targets - shown
                    if left > 0 then
                        printFn(string.format("    … +%d more targets", left))
                    end
                    break
                end
                local name = t.name
                if not name or name == "" then
                    name = "Target"
                end
                local up = t.activeSeconds or 0
                if t.openStart then
                    up = up + math.max(0, (fight.endedAt or GetTimeNow()) - t.openStart)
                end
                printFn(string.format(
                    "    %s: %s dmg | %.1fs up | %d ticks",
                    name,
                    self:FormatNumber(t.damage or 0),
                    up,
                    t.hits or 0
                ))
                shown = shown + 1
            end
        end
    end
end

function MinionDps:GetHarvestPlagueSummary(fight)
    if not fight or not fight.playerSpells then
        return nil
    end
    local bucket = fight.playerSpells["track:harvest_plague"]
    if not bucket then
        return nil
    end
    local targetCount = 0
    local openExtra = 0
    local now = fight.endedAt or GetTimeNow()
    for _, t in pairs(bucket.targets or {}) do
        targetCount = targetCount + 1
        if t.openStart then
            openExtra = openExtra + math.max(0, now - t.openStart)
        end
    end
    local unitSec = (bucket.activeSeconds or 0) + openExtra
    if unitSec <= 0 and (bucket.damage or 0) <= 0 and targetCount <= 0 and (bucket.hits or 0) <= 0 then
        return nil
    end
    return {
        unitSec = unitSec,
        targets = targetCount,
        damage = bucket.damage or 0,
        ticks = bucket.hits or 0,
        peak = bucket.peakTargets or 0,
    }
end

function MinionDps:GetHarvestPlagueSummaryFromFights(fights)
    local unitSec, targets, damage, ticks, peak = 0, 0, 0, 0, 0
    local any = false
    for _, fight in ipairs(fights or {}) do
        local s = self:GetHarvestPlagueSummary(fight)
        if s then
            any = true
            unitSec = unitSec + (s.unitSec or 0)
            targets = targets + (s.targets or 0)
            damage = damage + (s.damage or 0)
            ticks = ticks + (s.ticks or 0)
            if (s.peak or 0) > peak then
                peak = s.peak
            end
        end
    end
    if not any then
        return nil
    end
    return {
        unitSec = unitSec,
        targets = targets,
        damage = damage,
        ticks = ticks,
        peak = peak,
    }
end

function MinionDps:FormatHarvestPlagueLine(plague, zombieSpawns, duration)
    if (not zombieSpawns or zombieSpawns <= 0) and not plague then
        return nil
    end
    local parts = {}
    if zombieSpawns and zombieSpawns > 0 then
        table.insert(parts, string.format("%d zombies spawned", zombieSpawns))
    end
    if plague then
        if (plague.unitSec or 0) > 0 then
            table.insert(parts, string.format("%.0fs DoT unit-time", plague.unitSec))
        end
        if (plague.targets or 0) > 0 then
            table.insert(parts, string.format("%d target%s", plague.targets, plague.targets == 1 and "" or "s"))
        end
        if (plague.peak or 0) > 1 then
            table.insert(parts, string.format("peak %d", plague.peak))
        end
        if duration and duration > 0 and (plague.unitSec or 0) > 0 and (plague.targets or 0) <= 1 then
            local cover = math.min(100, 100 * plague.unitSec / duration)
            table.insert(parts, string.format("%.0f%% of fight", cover))
        end
    end
    if #parts == 0 then
        return nil
    end
    return "  Harvest Plague: " .. table.concat(parts, " · ")
end

function MinionDps:PrintFightStats(label, stats, duration, fight, opts)
    opts = opts or {}
    local includePlayer = opts.includePlayer ~= false
    local printFn = opts.printFn or function(msg)
        Mancer.Print(msg)
    end

    printFn(label .. string.format(" (%.1fs)", duration))

    local rows = {}
    for minionId, row in pairs(stats or {}) do
        table.insert(rows, { minionId = minionId, row = row })
    end
    table.sort(rows, function(a, b)
        return a.row.damage > b.row.damage
    end)

    if #rows == 0 then
        printFn("  No minion damage recorded.")
    else
        local Advisor = GetAdvisor()
        local zombieSpawns = 0
        for _, entry in ipairs(rows) do
            if entry.minionId == "lesser_zombie" then
                zombieSpawns = entry.row.summonCount or 0
                break
            end
        end
        local plague = opts.plagueSummary
        if plague == nil then
            plague = self:GetHarvestPlagueSummary(fight)
        end
        if plague == nil and opts.sessionFights then
            plague = self:GetHarvestPlagueSummaryFromFights(opts.sessionFights)
        end
        local plagueLine = self:FormatHarvestPlagueLine(plague, zombieSpawns, duration)
        if plagueLine then
            printFn(plagueLine)
        end

        for _, entry in ipairs(rows) do
            local minionId = entry.minionId
            local row = entry.row
            local lfCost = Advisor and Advisor:GetMinionLifeForceCost(minionId) or 0
            local dpsLf = (lfCost and lfCost > 0) and (row.dps / lfCost) or nil
            local suffix = dpsLf and string.format(" | %.0f DPS/LF", dpsLf) or ""
            printFn(string.format(
                "  %s: %s dmg | %.0f DPS/unit | %d hits%s",
                self:GetMinionLabel(minionId),
                self:FormatNumber(row.damage),
                row.dps,
                row.hits,
                suffix
            ))
            if row.temporary or (row.activeSeconds and row.activeSeconds > 0) or (row.summonCount and row.summonCount > 0) then
                local active = row.activeSeconds or row.uptime or 0
                local summons = row.summonCount or 0
                if summons > 1 then
                    local mult = duration > 0 and (active / duration) or 0
                    printFn(string.format(
                        "    %d summons · %.0fs unit-time total (fight %.0fs%s)",
                        summons,
                        active,
                        duration,
                        mult > 1.05 and string.format(" · %.1f× overlapping unit-time", mult) or ""
                    ))
                elseif summons == 1 or active > 0 then
                    local pct = duration > 0 and math.min(100, 100 * active / duration) or 0
                    printFn(string.format(
                        "    Out %.0fs (%.0f%% of fight)%s",
                        active,
                        pct,
                        summons > 0 and " · 1 summon" or ""
                    ))
                end
            end
            -- Spell breakdown still uses Mancer.Print; route via temporary sink if needed.
            if opts.printFn then
                local prevSink = Mancer.reportSink
                local lines = {}
                Mancer.reportSink = lines
                self:PrintSpellBreakdown(row.damage, row.spells, duration, row.units)
                Mancer.reportSink = prevSink
                for _, line in ipairs(lines) do
                    printFn(line)
                end
            else
                self:PrintSpellBreakdown(row.damage, row.spells, duration, row.units)
            end
        end
    end

    if includePlayer then
        self:PrintPlayerSpellStats(fight, duration, opts.printFn and { printFn = opts.printFn } or nil)
    end
end

function MinionDps:PrintSessionPlayerSpells(fights, opts)
    opts = opts or {}
    local printFn = opts.printFn or function(msg)
        Mancer.Print(msg)
    end
    local totals = {}
    for _, fight in ipairs(fights or {}) do
        for key, row in pairs(fight.playerSpells or {}) do
            local t = totals[key]
            if not t then
                t = {
                    id = row.id,
                    kind = row.kind,
                    label = row.label,
                    damage = 0,
                    hits = 0,
                    procs = 0,
                    activeSeconds = 0,
                    peakTargets = 0,
                    targetSightings = 0,
                }
                totals[key] = t
            end
            t.damage = t.damage + (row.damage or 0)
            t.hits = t.hits + (row.hits or 0)
            t.procs = t.procs + (row.procs or 0)
            t.activeSeconds = t.activeSeconds + (row.activeSeconds or 0)
            if (row.peakTargets or 0) > t.peakTargets then
                t.peakTargets = row.peakTargets
            end
            for _ in pairs(row.targets or {}) do
                t.targetSightings = t.targetSightings + 1
            end
        end
    end

    local rows = {}
    for _, row in pairs(totals) do
        if (row.damage or 0) > 0 or (row.procs or 0) > 0 or (row.activeSeconds or 0) > 0 then
            table.insert(rows, row)
        end
    end
    if #rows == 0 then
        return
    end
    table.sort(rows, function(a, b)
        if (a.damage or 0) ~= (b.damage or 0) then
            return (a.damage or 0) > (b.damage or 0)
        end
        return (a.procs or 0) > (b.procs or 0)
    end)

    printFn("Player spells (session totals):")
    for _, row in ipairs(rows) do
        if row.kind == "proc" then
            printFn(string.format("  %s: %d procs", row.label or "?", row.procs or 0))
        else
            printFn(string.format(
                "  %s: %s dmg | %.1fs unit-sec | peak %d | %d target-sightings | %d ticks",
                row.label or "?",
                self:FormatNumber(row.damage or 0),
                row.activeSeconds or 0,
                row.peakTargets or 0,
                row.targetSightings or 0,
                row.hits or 0
            ))
        end
    end
end

function MinionDps:GetMinionIconSpellId(minionId)
    local Advisor = GetAdvisor()
    local def = Advisor and Advisor.MINION_TYPES and Advisor.MINION_TYPES[minionId]
    if not def then
        return nil
    end
    if def.alertSpellId then
        return def.alertSpellId
    end
    if def.summonSpellIds then
        -- Prefer Ascension-range IDs when present.
        local best
        for spellId in pairs(def.summonSpellIds) do
            local id = tonumber(spellId)
            if id and (not best or id > best) then
                best = id
            end
        end
        return best
    end
    if def.buffSpellIds then
        local best
        for spellId in pairs(def.buffSpellIds) do
            local id = tonumber(spellId)
            if id and (not best or id > best) then
                best = id
            end
        end
        return best
    end
    return nil
end

function MinionDps:ResolveMinionIconTexture(minionId, spellId)
    local Advisor = GetAdvisor()
    if Advisor and Advisor.GetAnimateAlertIcon then
        local _, texture = Advisor:GetAnimateAlertIcon(minionId)
        if type(texture) == "string" and texture ~= "" then
            return texture
        end
    end
    spellId = tonumber(spellId) or self:GetMinionIconSpellId(minionId)
    if spellId and GetSpellInfo then
        local tex = select(3, GetSpellInfo(spellId))
        if type(tex) == "string" and tex ~= "" then
            return tex
        end
    end
    local label = self:GetMinionLabel(minionId)
    if label and GetSpellInfo then
        local tex = select(3, GetSpellInfo(label))
        if type(tex) == "string" and tex ~= "" then
            return tex
        end
    end
    return nil
end

function MinionDps:GetPlayerSpellIconSpellId(row)
    if row and row.spellId then
        return row.spellId
    end
    for _, def in ipairs(PLAYER_TRACKED_SPELLS) do
        if row and (def.id == row.id or def.label == row.label) then
            if def.spellIds then
                local best
                for spellId in pairs(def.spellIds) do
                    local id = tonumber(spellId)
                    if id and (not best or id > best) then
                        best = id
                    end
                end
                return best
            end
        end
    end
    return nil
end

function MinionDps:ResolvePlayerIconTexture(row, spellId)
    spellId = tonumber(spellId) or self:GetPlayerSpellIconSpellId(row)
    local Advisor = GetAdvisor()
    if Advisor and Advisor.PROC_AURAS and row then
        for _, def in ipairs(Advisor.PROC_AURAS) do
            if def.id == row.id or def.label == row.label then
                if def.fallbackIcon then
                    -- Prefer live spell texture when it's a path string.
                    if spellId and GetSpellInfo then
                        local tex = select(3, GetSpellInfo(spellId))
                        if type(tex) == "string" and tex ~= "" then
                            return tex
                        end
                    end
                    return def.fallbackIcon
                end
            end
        end
    end
    if spellId and GetSpellInfo then
        local tex = select(3, GetSpellInfo(spellId))
        if type(tex) == "string" and tex ~= "" then
            return tex
        end
    end
    if row and row.label and GetSpellInfo then
        local tex = select(3, GetSpellInfo(row.label))
        if type(tex) == "string" and tex ~= "" then
            return tex
        end
    end
    return nil
end

function MinionDps:BuildMinionAccordionRows(stats, duration, fight, opts)
    opts = opts or {}
    duration = math.max(1, duration or 1)
    local rows = {}
    for minionId, row in pairs(stats or {}) do
        table.insert(rows, { minionId = minionId, row = row })
    end
    table.sort(rows, function(a, b)
        return a.row.damage > b.row.damage
    end)

    local out = {}
    local Advisor = GetAdvisor()
    for _, entry in ipairs(rows) do
        local minionId = entry.minionId
        local row = entry.row
        local lfCost = Advisor and Advisor:GetMinionLifeForceCost(minionId) or 0
        local dpsLf = (lfCost and lfCost > 0) and (row.dps / lfCost) or nil
        local active = row.activeSeconds or row.uptime or 0
        local uptimePct = duration > 0 and math.min(100, 100 * active / duration) or 0
        local iconSpellId = self:GetMinionIconSpellId(minionId)
        local iconTexture = self:ResolveMinionIconTexture(minionId, iconSpellId)
        local spells = {}
        for _, spellRow in ipairs(row.spells or {}) do
            local spellId = spellRow.spellId
            local spellLabel = spellRow.label or "?"
            local spellTex
            if spellId and GetSpellInfo then
                local tex = select(3, GetSpellInfo(spellId))
                if type(tex) == "string" and tex ~= "" then
                    spellTex = tex
                end
            end
            if not spellTex and spellLabel and GetSpellInfo then
                local tex = select(3, GetSpellInfo(spellLabel))
                if type(tex) == "string" and tex ~= "" then
                    spellTex = tex
                end
            end
            table.insert(spells, {
                label = spellLabel,
                spellId = spellId,
                iconTexture = spellTex,
                damage = spellRow.damage or 0,
                sharePct = (spellRow.share or 0) * 100,
                hits = spellRow.hits or 0,
                dps = spellRow.dps or 0,
            })
        end
        table.insert(out, {
            minionId = minionId,
            label = self:GetMinionLabel(minionId),
            iconSpellId = iconSpellId,
            iconTexture = iconTexture,
            damage = row.damage or 0,
            dps = row.dps or 0,
            hits = row.hits or 0,
            dpsLf = dpsLf,
            uptimePct = uptimePct,
            activeSeconds = active,
            summonCount = row.summonCount or 0,
            spells = spells,
        })
    end

    local harvest = nil
    if opts.plagueSummary == nil then
        opts.plagueSummary = self:GetHarvestPlagueSummary(fight)
    end
    if opts.plagueSummary == nil and opts.sessionFights then
        opts.plagueSummary = self:GetHarvestPlagueSummaryFromFights(opts.sessionFights)
    end
    local zombieSpawns = 0
    for _, entry in ipairs(rows) do
        if entry.minionId == "lesser_zombie" then
            zombieSpawns = entry.row.summonCount or 0
            break
        end
    end
    local plagueLine = self:FormatHarvestPlagueLine(opts.plagueSummary, zombieSpawns, duration)
    if plagueLine then
        harvest = plagueLine:gsub("^%s+", "")
    end

    return out, harvest
end

function MinionDps:BuildPlayerAccordionRows(fight, duration, opts)
    opts = opts or {}
    if not fight or not fight.playerSpells then
        return {}
    end
    duration = math.max(1, duration or self:GetFightDuration(fight))

    local entries = {}
    for _, row in pairs(fight.playerSpells) do
        local targetCount = 0
        local openExtra = 0
        local now = fight.endedAt or GetTimeNow()
        for _, t in pairs(row.targets or {}) do
            targetCount = targetCount + 1
            if t.openStart then
                openExtra = openExtra + math.max(0, now - t.openStart)
            end
        end
        local unitSec = (row.activeSeconds or 0) + openExtra
        local hasData = (row.damage or 0) > 0
            or (row.procs or 0) > 0
            or (row.casts or 0) > 0
            or unitSec > 0
            or targetCount > 0
        if hasData then
            table.insert(entries, { row = row, targetCount = targetCount, unitSec = unitSec })
        end
    end
    if #entries == 0 then
        return {}
    end

    table.sort(entries, function(a, b)
        local ad = a.row.damage or 0
        local bd = b.row.damage or 0
        if ad ~= bd then
            return ad > bd
        end
        local ac = a.row.casts or 0
        local bc = b.row.casts or 0
        if ac ~= bc then
            return ac > bc
        end
        return (a.row.procs or 0) > (b.row.procs or 0)
    end)

    local out = {}
    for _, entry in ipairs(entries) do
        local row = entry.row
        local uptimePct = nil
        if entry.targetCount <= 1 and entry.unitSec > 0 and duration > 0 then
            uptimePct = math.min(100, 100 * entry.unitSec / duration)
        end
        local item = {
            id = row.id,
            label = row.label or "?",
            kind = row.kind or "dot",
            iconSpellId = self:GetPlayerSpellIconSpellId(row),
            iconTexture = nil,
            damage = row.damage or 0,
            procs = row.procs or 0,
            casts = row.casts or 0,
            dps = (row.damage or 0) / duration,
            unitSec = entry.unitSec,
            targetCount = entry.targetCount,
            uptimePct = uptimePct,
            hits = row.hits or 0,
            targets = {},
        }
        item.iconTexture = self:ResolvePlayerIconTexture(item, item.iconSpellId)
        if row.kind ~= "proc" then
            local targets = {}
            for _, t in pairs(row.targets or {}) do
                table.insert(targets, t)
            end
            table.sort(targets, function(a, b)
                local ad = a.damage or 0
                local bd = b.damage or 0
                if ad ~= bd then
                    return ad > bd
                end
                return (a.activeSeconds or 0) > (b.activeSeconds or 0)
            end)
            for _, t in ipairs(targets) do
                local name = t.name
                if not name or name == "" then
                    name = "Target"
                end
                table.insert(item.targets, {
                    name = name,
                    damage = t.damage or 0,
                })
            end
        end
        table.insert(out, item)
    end
    return out
end

function MinionDps:BuildSessionPlayerAccordionRows(fights)
    local totals = {}
    for _, fight in ipairs(fights or {}) do
        for key, row in pairs(fight.playerSpells or {}) do
            local t = totals[key]
            if not t then
                t = {
                    id = row.id,
                    kind = row.kind,
                    label = row.label,
                    damage = 0,
                    hits = 0,
                    procs = 0,
                    casts = 0,
                    activeSeconds = 0,
                    peakTargets = 0,
                    targetSightings = 0,
                }
                totals[key] = t
            end
            t.damage = t.damage + (row.damage or 0)
            t.hits = t.hits + (row.hits or 0)
            t.procs = t.procs + (row.procs or 0)
            t.casts = t.casts + (row.casts or 0)
            t.activeSeconds = t.activeSeconds + (row.activeSeconds or 0)
            if (row.peakTargets or 0) > t.peakTargets then
                t.peakTargets = row.peakTargets
            end
            for _ in pairs(row.targets or {}) do
                t.targetSightings = t.targetSightings + 1
            end
        end
    end

    local rows = {}
    for _, row in pairs(totals) do
        if (row.damage or 0) > 0 or (row.procs or 0) > 0 or (row.casts or 0) > 0 or (row.activeSeconds or 0) > 0 then
            table.insert(rows, row)
        end
    end
    table.sort(rows, function(a, b)
        if (a.damage or 0) ~= (b.damage or 0) then
            return (a.damage or 0) > (b.damage or 0)
        end
        if (a.casts or 0) ~= (b.casts or 0) then
            return (a.casts or 0) > (b.casts or 0)
        end
        return (a.procs or 0) > (b.procs or 0)
    end)

    local out = {}
    for _, row in ipairs(rows) do
        local sessionNote
        if row.kind == "proc" then
            sessionNote = string.format("%d procs (session total)", row.procs or 0)
        elseif row.kind == "spell" or (row.casts or 0) > 0 then
            sessionNote = string.format(
                "%s dmg | %d casts | %d hits | %.1fs unit-sec | %d target-sightings",
                self:FormatNumber(row.damage or 0),
                row.casts or 0,
                row.hits or 0,
                row.activeSeconds or 0,
                row.targetSightings or 0
            )
        else
            sessionNote = string.format(
                "%s dmg | %.1fs unit-sec | peak %d | %d target-sightings | %d ticks",
                self:FormatNumber(row.damage or 0),
                row.activeSeconds or 0,
                row.peakTargets or 0,
                row.targetSightings or 0,
                row.hits or 0
            )
        end
        local item = {
            id = row.id,
            label = row.label or "?",
            kind = row.kind or "dot",
            iconSpellId = self:GetPlayerSpellIconSpellId(row),
            damage = row.damage or 0,
            procs = row.procs or 0,
            casts = row.casts or 0,
            unitSec = row.activeSeconds or 0,
            targetCount = row.targetSightings or 0,
            uptimePct = nil,
            hits = row.hits or 0,
            targets = {},
            sessionNote = sessionNote,
        }
        item.iconTexture = self:ResolvePlayerIconTexture(item, item.iconSpellId)
        table.insert(out, item)
    end
    return out
end

function MinionDps:GetDpsReportData(mode)
    self:Init()
    mode = mode or "auto"

    if mode == "benchmark" then
        return {
            title = "Minion DPS (Benchmark)",
            duration = 0,
            mode = "benchmark",
            minions = {},
            players = {},
            minionTextFallback = nil,
            playerTextFallback = "(benchmarks are minion-only)",
        }
    end

    local resolved = self:ResolveDpsFight(mode)
    if not resolved then
        return nil
    end

    local minions, harvest = self:BuildMinionAccordionRows(
        resolved.stats,
        resolved.duration,
        resolved.fight,
        { sessionFights = resolved.sessionFights }
    )

    local players = {}
    if resolved.mode == "session" then
        players = self:BuildSessionPlayerAccordionRows(resolved.sessionFights)
    elseif resolved.fight then
        players = self:BuildPlayerAccordionRows(resolved.fight, resolved.duration)
    end

    return {
        title = resolved.title,
        duration = resolved.duration,
        mode = resolved.mode,
        harvestPlague = harvest,
        minions = minions,
        players = players,
    }
end

function MinionDps:FormatDpsReportText(data)
    if not data then
        return "", ""
    end
    if data.mode == "benchmark" then
        local lines = {}
        local prev = Mancer.reportSink
        Mancer.reportSink = lines
        self:PrintDpsReport("benchmark")
        Mancer.reportSink = prev
        return table.concat(lines, "\n"), data.playerTextFallback or ""
    end

    local minionLines = {}
    if data.harvestPlague and data.harvestPlague ~= "" then
        table.insert(minionLines, data.harvestPlague)
    end
    for _, row in ipairs(data.minions or {}) do
        local suffix = row.dpsLf and string.format(" | %.0f DPS/LF", row.dpsLf) or ""
        table.insert(minionLines, string.format(
            "  %s: %s dmg | %.0f DPS/unit | %d hits%s",
            row.label,
            self:FormatNumber(row.damage),
            row.dps,
            row.hits,
            suffix
        ))
        for _, spell in ipairs(row.spells or {}) do
            table.insert(minionLines, string.format(
                "    - %s: %s dmg | %.1f%% | %d hits | %.0f DPS",
                spell.label,
                self:FormatNumber(spell.damage),
                spell.sharePct,
                spell.hits,
                spell.dps
            ))
        end
    end

    local playerLines = {}
    for _, row in ipairs(data.players or {}) do
        if row.kind == "proc" then
            table.insert(playerLines, string.format("  %s: %d procs", row.label, row.procs or 0))
        elseif row.sessionNote then
            table.insert(playerLines, string.format("  %s: %s", row.label, row.sessionNote))
        else
            local parts = {
                string.format("%s: %s dmg", row.label, self:FormatNumber(row.damage or 0)),
            }
            if (row.casts or 0) > 0 then
                table.insert(parts, string.format("%d cast%s", row.casts, row.casts == 1 and "" or "s"))
            end
            if (row.dps or 0) > 0 or (row.damage or 0) > 0 then
                table.insert(parts, string.format("%.0f DPS", row.dps or 0))
            end
            if (row.targetCount or 0) > 0 then
                table.insert(parts, string.format("%d target%s", row.targetCount, row.targetCount == 1 and "" or "s"))
            end
            if (row.unitSec or 0) > 0 then
                table.insert(parts, string.format("%.1fs unit-sec", row.unitSec))
            end
            if row.uptimePct then
                table.insert(parts, string.format("%.0f%% of fight", row.uptimePct))
            end
            if (row.hits or 0) > 0 then
                table.insert(parts, string.format("%d hits", row.hits))
            end
            table.insert(playerLines, "  " .. table.concat(parts, " | "))
            for _, t in ipairs(row.targets or {}) do
                table.insert(playerLines, string.format(
                    "    %s: %s dmg",
                    t.name,
                    self:FormatNumber(t.damage or 0)
                ))
            end
        end
    end

    return table.concat(minionLines, "\n"), table.concat(playerLines, "\n")
end

function MinionDps:ResolveDpsFight(mode)
    self:Init()
    mode = mode or "auto"
    if mode == "session" then
        local stats, fightCount = self:AggregateSessionStats()
        if fightCount <= 0 then
            return nil
        end
        local totalDuration = 0
        local db = EnsureDb()
        for _, fight in ipairs(db.fights) do
            totalDuration = totalDuration + self:GetFightDuration(fight)
        end
        return {
            mode = "session",
            title = string.format("Minion DPS session (%d fights)", fightCount),
            stats = stats,
            duration = totalDuration,
            fight = nil,
            sessionFights = db.fights,
        }
    end

    if self.currentFight and (self.currentFight.startedAt or PlayerSpellsHaveData(self.currentFight)) then
        local stats, duration = self:AggregateFightStats(self.currentFight)
        if next(stats) or PlayerSpellsHaveData(self.currentFight) then
            return {
                mode = "current",
                title = "DPS (current fight)",
                stats = stats,
                duration = duration,
                fight = self.currentFight,
            }
        end
    end

    if self.pendingFight and self:FightHasDamage(self.pendingFight) then
        local stats, duration = self:AggregateFightStats(self.pendingFight)
        if next(stats) or PlayerSpellsHaveData(self.pendingFight) then
            return {
                mode = "last",
                title = "DPS (last fight)",
                stats = stats,
                duration = duration,
                fight = self.pendingFight,
            }
        end
    end

    local db = EnsureDb()
    if db.fights[1] then
        local stats, duration = self:AggregateFightStats(db.fights[1])
        return {
            mode = "saved",
            title = "DPS (last fight)",
            stats = stats,
            duration = duration,
            fight = db.fights[1],
        }
    end
    return nil
end

function MinionDps:GetDpsReportColumns(mode)
    self:Init()
    mode = mode or "auto"

    if mode == "benchmark" then
        local data = self:GetDpsReportData("benchmark")
        local minionText, playerText = self:FormatDpsReportText(data)
        return {
            title = data.title,
            minionText = minionText,
            playerText = playerText,
        }
    end

    local data = self:GetDpsReportData(mode)
    if not data then
        local lines = {}
        local prev = Mancer.reportSink
        Mancer.reportSink = lines
        if mode == "session" then
            Mancer.Print("No saved minion DPS fights yet. Enter combat with your army — fights auto-save when combat ends.")
        else
            Mancer.Print("No live DPS data yet.")
        end
        self:PrintCalibrationHelp()
        Mancer.reportSink = prev
        return {
            title = mode == "session" and "Minion DPS (Session)" or "Minion DPS",
            minionText = table.concat(lines, "\n"),
            playerText = "(no player spell data yet)",
        }
    end

    local minionText, playerText = self:FormatDpsReportText(data)
    if playerText == "" then
        playerText = "(no player DoTs / procs this fight)"
    end

    return {
        title = data.title,
        minionText = minionText,
        playerText = playerText,
        data = data,
    }
end

function MinionDps:BuildDpsExportText(mode)
    local cols = self:GetDpsReportColumns(mode or "auto")
    if not cols then
        return nil
    end
    local playerName = (UnitName and UnitName("player")) or "?"
    local stamp = date and date("%Y-%m-%d %H:%M:%S") or "?"
    local lines = {
        "Mancer Minion DPS Export",
        "Version: " .. tostring(Mancer.VERSION or "?"),
        "Character: " .. tostring(playerName),
        "Exported: " .. tostring(stamp),
        "",
        cols.title or "Minion DPS",
        "",
        "=== Minions ===",
        cols.minionText or "(none)",
        "",
        "=== Player ===",
        cols.playerText or "(none)",
        "",
    }
    return table.concat(lines, "\n")
end

function MinionDps:PrintDpsReport(mode)
    self:Init()
    mode = mode or "auto"

    if mode == "benchmark" then
        local stats = self:GetBenchmarkEstimates()
        if not stats or not next(stats) then
            Mancer.Print("No benchmark data available.")
            return
        end
        Mancer.Print("Reference DPS per minion (single-target dummy — used until you record a fight):")
        local Advisor = GetAdvisor()
        for _, minionId in ipairs({ "crypt_fiend", "banshee", "abomination", "skeletal_warrior_greater", "ghoul", "skeletal_rogue", "skeletal_warrior_lesser" }) do
            local row = stats[minionId]
            if row then
                local lfCost = Advisor and Advisor:GetMinionLifeForceCost(minionId) or 0
                local dpsLf = (lfCost and lfCost > 0) and (row.dps / lfCost) or nil
                local suffix = dpsLf and string.format(" | %.0f DPS per Life Force", dpsLf) or ""
                Mancer.Print(string.format("  %s: %.1f DPS each%s", self:GetMinionLabel(minionId), row.dps, suffix))
            end
        end
        Mancer.Print("")
        Mancer.Print("  These are boss/single-target numbers. For packs, open Hub → ST vs AOE.")
        return
    end

    local cols = self:GetDpsReportColumns(mode)
    for line in string.gmatch((cols.minionText or "") .. "\n", "(.-)\n") do
        Mancer.Print(line)
    end
    Mancer.Print("")
    for line in string.gmatch((cols.playerText or "") .. "\n", "(.-)\n") do
        Mancer.Print(line)
    end
end

function MinionDps:GetFightRole(minionId)
    return FIGHT_ROLES[minionId]
end

function MinionDps:PrintCalibrationHelp()
    Mancer.Print("How to measure your minion DPS (easy steps)")
    Mancer.Print("")
    Mancer.Print("  1. Raise your army and fight — recording starts when you enter combat")
    Mancer.Print("  2. When combat ends, the fight is saved automatically")
    Mancer.Print("  3. Open Hub → Combat → DPS after a pull")
    Mancer.Print("  4. Training dummies: Hub → Save DPS (exports report + saves for LF Combo)")
    Mancer.Print("  5. Hub → Save DPS copies the report so you can paste into a .txt file")
    Mancer.Print("  6. Hub → LF Combo uses your recent fight data to pick a boss army")
    Mancer.Print("")
    Mancer.Print("  Good starter: 1 Abomination + as many Ghouls as you can.")
    Mancer.Print("  For packs vs bosses, open Hub → ST vs AOE.")
end

function MinionDps:GetStVsAoeColumns()
    return {
        intro = "Simple answer — what to raise for each fight type.\n(No heavy maths — pick the column that matches your pull.)",
        stText = table.concat({
            "Boss / one target",
            "Goal: kill ONE enemy (boss, dummy, priority kill).",
            "",
            "Raise first",
            "  • Abomination, then fill leftover Life Force with Ghouls",
            "  • Pure Ghouls are fine early if you do not have Abom yet",
            "",
            "Animates (no Life Force)",
            "  • Bone Wraith — best boss Animate",
            "  • Archer / Frost Wyrm / Plaguefather — press when ready",
            "",
            "Leave for packs",
            "  • Crypt Fiend — usually worse than Ghouls on one target",
            "  • Tomb King — better when many minions are hitting",
        }, "\n"),
        aoeText = table.concat({
            "Packs / AoE",
            "Goal: hit MANY enemies (trash packs, cleave).",
            "",
            "Raise first",
            "  • Crypt Fiend — best Raise for packs",
            "  • Keep 1 Abomination if you can (Army of the Dead haste)",
            "  • Fill the rest with Ghouls",
            "",
            "Animates",
            "  • Tomb King — short buff for the whole army",
            "  • Archer / Frost Wyrm / Plaguefather — still press on cooldown",
            "  • Bone Wraith — still strong; Tomb King can win with a big army",
        }, "\n"),
        cheatText = table.concat({
            "Quick cheat sheet",
            "  Boss  → Abom + Ghouls + Bone Wraith",
            "  Trash → Crypt Fiend + Ghouls + Tomb King",
            "",
            "  Hub → LF Combo = best Life Force army for bosses.",
            "  Fights auto-save when combat ends (Save DPS for dummies / .txt export).",
        }, "\n"),
    }
end

local function PrintMultiline(text, skipFirst)
    if not text then
        return
    end
    local first = true
    for line in string.gmatch(text .. "\n", "(.-)\n") do
        if skipFirst and first then
            first = false
        else
            Mancer.Print(line)
            first = false
        end
    end
end

function MinionDps:PrintStVsAoeGuide()
    local Advisor = GetAdvisor()
    local cols = self:GetStVsAoeColumns()

    PrintMultiline(cols.intro)
    Mancer.Print("")
    Mancer.Print("════════ Boss / one target ════════")
    PrintMultiline(cols.stText, true)
    Mancer.Print("")
    Mancer.Print("════════ Packs / AoE ════════")
    PrintMultiline(cols.aoeText, true)
    Mancer.Print("")
    Mancer.Print("════════ Quick cheat sheet ════════")
    PrintMultiline(cols.cheatText, true)
    Mancer.Print("")
    Mancer.Print("──────── Each guardian ────────")
    for _, minionId in ipairs(FIGHT_ROLE_ORDER) do
        local role = FIGHT_ROLES[minionId]
        if role then
            local label = self:GetMinionLabel(minionId)
            local locked = ""
            if Advisor and Advisor.IsMinionAvailable and not Advisor:IsMinionAvailable(minionId) then
                locked = " (not unlocked yet)"
            end
            Mancer.Print(string.format("  %s — %s%s", label, role.bestFor, locked))
            Mancer.Print("    " .. role.oneLiner)
        end
    end
end

function MinionDps:BuildComboLabel(counts)
    local parts = {}
    local Advisor = GetAdvisor()
    if not Advisor then
        return "?"
    end

    local order = { "abomination", "crypt_fiend", "banshee", "skeletal_warrior_greater", "skeletal_warrior_lesser", "skeletal_rogue", "ghoul" }
    for _, minionId in ipairs(order) do
        local count = counts[minionId] or 0
        if count > 0 then
            local label = self:GetMinionLabel(minionId)
            if count > 1 then
                table.insert(parts, string.format("%dx %s", count, label))
            else
                table.insert(parts, label)
            end
        end
    end

    if #parts == 0 then
        return "empty"
    end
    return table.concat(parts, " + ")
end

function MinionDps:GetCommandGhoulBonus(ghoulCount)
    ghoulCount = tonumber(ghoulCount) or 0
    if ghoulCount < COMMAND_GHOUL_MIN_COUNT then
        return 0
    end

    local Advisor = GetAdvisor()
    if not Advisor or not Advisor.IsMinionAvailable or not Advisor:IsMinionAvailable("ghoul") then
        return 0
    end

    return ghoulCount * COMMAND_GHOUL_DPS_PER_UNIT
end

function MinionDps:ScoreCombo(counts, dpsEstimates)
    local Advisor = GetAdvisor()
    if not Advisor then
        return 0
    end

    local total = 0
    for minionId, count in pairs(counts) do
        local dps = dpsEstimates[minionId] and dpsEstimates[minionId].dps or 0
        total = total + (count * dps)
    end

    total = total + self:GetCommandGhoulBonus(counts.ghoul or 0)
    return total
end

function MinionDps:GetLifeForceUsed(counts)
    local Advisor = GetAdvisor()
    if not Advisor then
        return 0
    end

    local used = 0
    for minionId, count in pairs(counts) do
        used = used + (count * Advisor:GetMinionLifeForceCost(minionId))
    end
    return used
end

function MinionDps:EnumerateComboCandidates(lfMax, dpsEstimates)
    local Advisor = GetAdvisor()
    if not Advisor then
        return {}
    end

    local optional = {}
    for _, minionId in ipairs(LF_COMBO_MINIONS) do
        if Advisor:IsMinionAvailable(minionId) and dpsEstimates[minionId] then
            table.insert(optional, {
                id = minionId,
                cost = math.max(1, Advisor:GetMinionLifeForceCost(minionId)),
                maxCount = Advisor:GetMinionMax(minionId) or 1,
            })
        end
    end

    local hasGhoul = Advisor:IsMinionAvailable("ghoul") and dpsEstimates.ghoul
    local results = {}

    local function finalize(counts, lfUsed)
        local final = {}
        for minionId, count in pairs(counts) do
            if count and count > 0 then
                final[minionId] = count
            end
        end

        local ghoulSlots = lfMax - lfUsed
        if hasGhoul and ghoulSlots > 0 then
            local ghoulMax = Advisor:GetMinionMax("ghoul") or lfMax
            final.ghoul = math.min(ghoulSlots, ghoulMax)
        end

        if next(final) then
            table.insert(results, {
                counts = final,
                score = self:ScoreCombo(final, dpsEstimates),
                lfUsed = self:GetLifeForceUsed(final),
            })
        elseif hasGhoul then
            local fallback = { ghoul = math.min(lfMax, Advisor:GetMinionMax("ghoul") or lfMax) }
            table.insert(results, {
                counts = fallback,
                score = self:ScoreCombo(fallback, dpsEstimates),
                lfUsed = self:GetLifeForceUsed(fallback),
            })
        end
    end

    local function search(index, lfUsed, counts)
        if index > #optional then
            finalize(counts, lfUsed)
            return
        end

        local entry = optional[index]
        local maxByLf = math.floor((lfMax - lfUsed) / entry.cost)
        local maxCount = math.min(entry.maxCount, maxByLf)
        for count = 0, maxCount do
            if count > 0 then
                counts[entry.id] = count
            else
                counts[entry.id] = nil
            end
            search(index + 1, lfUsed + (count * entry.cost), counts)
        end
    end

    if #optional == 0 then
        finalize({}, 0)
    else
        search(1, 0, {})
    end

    return results
end

function MinionDps:FindBestCombo(dpsEstimates, lfMax)
    local Advisor = GetAdvisor()
    if not Advisor then
        return nil
    end

    local bestScore = -1
    local bestCounts = nil
    local bestLfUsed = -1

    for _, candidate in ipairs(self:EnumerateComboCandidates(lfMax, dpsEstimates)) do
        local score = candidate.score
        local lfUsed = candidate.lfUsed
        if score > bestScore or (score == bestScore and lfUsed > bestLfUsed) then
            bestScore = score
            bestCounts = candidate.counts
            bestLfUsed = lfUsed
        end
    end

    return bestCounts, bestScore, bestLfUsed
end

function MinionDps:FindRunnerUpCombo(dpsEstimates, lfMax, bestCounts)
    if not bestCounts then
        return nil, 0
    end

    local bestLabel = self:BuildComboLabel(bestCounts)
    local runnerCounts = nil
    local runnerScore = -1

    for _, candidate in ipairs(self:EnumerateComboCandidates(lfMax, dpsEstimates)) do
        local label = self:BuildComboLabel(candidate.counts)
        if label ~= bestLabel and candidate.score > runnerScore then
            runnerScore = candidate.score
            runnerCounts = candidate.counts
        end
    end

    return runnerCounts, runnerScore
end

function MinionDps:PrintComboRecommendation()
    local Advisor = GetAdvisor()
    if not Advisor then
        Mancer.Print("Minion advisor not loaded.")
        return
    end

    if not Advisor:IsMinionAdvisorEnabled() then
        Mancer.Print("Minion combo planner requires Animation Necromancer.")
        return
    end

    local dpsEstimates, fightCount, source = self:GetDpsEstimates()
    if not dpsEstimates or not next(dpsEstimates) then
        Mancer.Print("Need minion DPS data before recommending combos.")
        self:PrintCalibrationHelp()
        return
    end

    local lfMax = Advisor:GetLifeForceMax()
    local bestCounts, bestScore, lfUsed = self:FindBestCombo(dpsEstimates, lfMax)
    if not bestCounts then
        Mancer.Print("Could not build a life force combo for your talents.")
        return
    end

    local sourceLabel = "your measured fights"
    if source == "benchmark" then
        sourceLabel = "built-in single-target numbers"
    elseif source == "session" then
        sourceLabel = "your session averages"
    elseif source == "current" or source == "last" then
        sourceLabel = "your recent fight"
    elseif source then
        sourceLabel = tostring(source)
    end

    Mancer.Print("Best army for bosses (one target)")
    Mancer.Print(string.format("  Based on: %s", sourceLabel))
    Mancer.Print("")
    Mancer.Print("  Raise this:")
    Mancer.Print("    " .. self:BuildComboLabel(bestCounts))
    Mancer.Print(string.format(
        "  About %.0f minion DPS  |  Life Force %d / %d",
        bestScore,
        lfUsed,
        lfMax
    ))

    local ghoulCount = bestCounts.ghoul or 0
    local commandBonus = self:GetCommandGhoulBonus(ghoulCount)
    if commandBonus > 0 then
        Mancer.Print(string.format(
            "  (Includes Command: Undead bonus from %d ghouls)",
            ghoulCount
        ))
    end

    local runnerCounts, runnerScore = self:FindRunnerUpCombo(dpsEstimates, lfMax, bestCounts)
    if runnerCounts and runnerScore > 0 and bestScore > 0 then
        local delta = ((bestScore - runnerScore) / runnerScore) * 100
        Mancer.Print("")
        Mancer.Print(string.format(
            "  Next best: %s (about %.0f%% weaker)",
            self:BuildComboLabel(runnerCounts),
            delta
        ))
    end

    local cdNotes = {}
    for _, minionId in ipairs(CD_MINIONS) do
        if Advisor:IsMinionAvailable(minionId) then
            table.insert(cdNotes, self:GetMinionLabel(minionId))
        end
    end
    if #cdNotes > 0 then
        Mancer.Print("")
        Mancer.Print("  Animates (no Life Force) — press when ready:")
        Mancer.Print("    " .. table.concat(cdNotes, ", "))
    end

    Mancer.Print("")
    Mancer.Print("  For packs / AoE, open Hub → ST vs AOE.")
    if source == "benchmark" then
        Mancer.Print("  Tip: Fight anything with your army — DPS auto-saves when combat ends (Save DPS for dummies / export).")
    end
end
