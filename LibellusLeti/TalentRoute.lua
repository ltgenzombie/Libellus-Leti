-- Math-first Animation Necromancer talent priority route (ST leveling → hybrid).
-- Evidence: dummy calibrations (ghoul ~152 mid ST / ~70 early, Abom ~206, AotD haste/crit,
-- Forbidden Technique Command CDR) + Azuregos lvl 60 logs.
-- Policy: recommend every talent that grants player or minion haste; Mindless Fury first.
Mancer.TalentRouteModule = {}
local TalentRoute = Mancer.TalentRouteModule

-- CA JSON gaps vs live Vol'jin client (CharacterAdvancementData.json dump).
-- These S/A names are confirmed in-game / WeakAuras / Mancer tips but absent or
-- incomplete as Animation Talent rows in the local CA dump:
TalentRoute.CA_JSON_GAPS = {
    "Raise: Ghoul",
    "Raise: Abomination",
    "Graverobber",
    "Mindless Fury",
    "Sepulchral Might",
    "Unrelenting Army",
    "Forbidden Technique",
    "Army of the Dead",
    "Ghoul Mastery",
    "Animate: Bone Wraith",
    "Animate: Skeletal Archer",
    "Summoning Expert",
    "Summoning Prodigy",
    "Life For Power",
    "Depravity",
    "Mass Grave",
}

-- Known CA path gate from local dump (~37 Animation Talent rows; most RequiredIDs empty).
-- Animation Necromancer requires CoA Animation specialization + Animate: Rotlings.
-- CoA builder (Voljin Alpha) is a client SPA — verify remaining S-tier path gates there;
-- HTML fetch cannot import tooltips/prereqs without capturing its XHR API.
TalentRoute.KNOWN_CA_GATES = {
    {
        name = "Animation Necromancer",
        requires = {
            "Conquest of Azeroth Specialization - Necromancer (Animation)",
            "Animate: Rotlings",
        },
    },
}

-- Present in CA dump as Animation Talent/Ability but not a math-first talent spend.
TalentRoute.NOT_TALENT_SPENDS = {
    {
        name = "Unholy Frenzy",
        note = "Learned ~lvl 22 spell — attack-speed buff (haste-like). Cast on army; not an S/A CA point spend.",
    },
}

-- Animation passive column (SpendCircle Abilities).
-- These unlock with a separate free point at a set character level — they do NOT
-- consume Class/Spec TE from even/odd level-ups. Always taken; never S/A/B.
TalentRoute.FREE_PASSIVES = {
    { name = "Summoning Adept", level = 10, why = "+ Life Force capacity" },
    { name = "Deadly Bond", level = 20, why = "Chance for free follow-up Command" },
    { name = "Summoning Expert", level = 30, why = "+ Life Force + Undead stamina" },
    { name = "Diabolical", level = 40, why = "Spell stacks amp Crypt Swarm" },
    { name = "Grave Mastery", level = 50, why = "Cheaper Animate / Raise / Command" },
}

TalentRoute.TIERS = {
    {
        id = "S",
        label = "S — always take when available",
        entries = {
            { name = "Animation Necromancer", why = "Spec root" },
            { name = "Animate: Skeletal Archer", why = "First Animation spend (CA 7345 / 805040) — required path; strong DPS" },
            { name = "Bone King", why = "Second Animation spend (CA 7143 / 707175) — Command → free instant Lichfrost/Blight" },
            { name = "Raise: Ghoul", why = "Core LF DPS (~152 mid ST / ~70 early)" },
            { name = "Summoning Prodigy", why = "More LF capacity (Spec TE spend)" },
            { name = "Summoning Mastery", why = "+LF pool — linear army DPS" },
            { name = "Life For Power", why = "LF scaling talent" },
            { name = "Mindless Fury", why = "Stacking haste buff — huge; far ahead of Depravity" },
            { name = "Graverobber", why = "Path + faster Raise/Animate" },
            { name = "Ghoul Mastery", why = "Ghoul army scaling" },
            { name = "Ghoulkeeper", why = "More ghouls for Command / Sepulchral" },
            { name = "Ghoul Commander", why = "Command: Ghouls synergy" },
            { name = "Improved Unholy Command", why = "Command ~78% ghoul pkg on ST; ~30% raid WB" },
            { name = "Sepulchral Might", why = "Army stamina → Crypt Swarm / Blight" },
            { name = "Unrelenting Army", why = "Free Lesser Zombies (~24% in hybrid log)" },
            { name = "Forbidden Technique", why = "Command → Animate CDR (~37s/min)" },
            { name = "Army of the Dead", why = "Must-take — +10% ghoul haste (and crit) with 1 Abom" },
            { name = "Raise: Abomination", why = "Enables AotD haste; ~206 ST ≈ 3 ghouls" },
        },
    },
    -- Triaged from Animation TabType 61 nodes that were not on S/A/B:
    -- anything that raises minion damage or player/minion haste → S? (confirm in logs).
    {
        id = "S?",
        label = "S? — possible S (minion damage / haste) — confirm with logs",
        entries = {
            { name = "Master Animator", why = "+1 Life Force — linear army DPS (Spec TE spend)" },
            { name = "Runic Animation", why = "Shorter Archer Animate CD — more Animate DPS + Scourge Disciple haste uptime" },
            { name = "Skeletal Artillery", why = "+1 Skeletal Archer per Animate — minion damage + more haste stacks from Scourge Disciple" },
            { name = "Underking", why = "Commands stack into Animate CDR (Wraith / Tomb King / Plaguefather) — more CD Animate DPS" },
            { name = "Unstoppable Frenzy", why = "Shorter Unholy Frenzy CD — army attack-speed (haste-like) more often" },
        },
    },
    {
        id = "A",
        label = "A — strong once S is online",
        entries = {
            { name = "Animate: Bone Wraith", why = "Bonestorm SP×0.4 — better SP scaling than Tomb King ~10% army convert" },
            { name = "Animate: Knight of Decay", why = "Same CD role as Bone Wraith" },
            { name = "Putrid Summoner", why = "Faster / cheaper summoning" },
            { name = "Greater Summoning", why = "Flat LF army power" },
            { name = "Ghoulish Mutation", why = "Direct ghoul damage" },
            { name = "Foul Invocation", why = "Plague/summon synergy with Unrelenting" },
            { name = "Depravity", why = "Army melee haste — take after Mindless Fury" },
            { name = "Fetid Frenzy", why = "Proc haste on other Undead" },
            { name = "Scourge Disciple", why = "Your haste per active Skeletal Archer" },
            { name = "Plague Horde", why = "Horde enrage includes melee/ranged haste" },
            { name = "Chomp", why = "Abom Chomp → attack-speed frenzy" },
            { name = "Unrelenting", why = "Faster Crypt Swarm channel — path into Unrelenting Army" },
        },
    },
    {
        id = "B",
        label = "B — situational / later",
        entries = {
            { name = "Animate: Tomb King", why = "Flat ~10% plague on minion hits (no SP on the %); behind Wraith on scaling" },
            { name = "Animate: Plaguefather", why = "Hybrid Animate CD" },
            { name = "Animate: Bone Construct", why = "Pierce Animate — behind Wraith / Archer for ST" },
            { name = "Unrelenting Swarm", why = "Multi-target / Unrelenting path" },
            { name = "Plaguecraft", why = "Player plague damage" },
            { name = "Necrotic Power", why = "Caster side; behind Sepulchral" },
            { name = "Crypt Keeper", why = "Crypt Swarm bounces — AoE caster; behind Sepulchral" },
            { name = "March of the Dead", why = "Player AoE plague CD — not army DPS" },
            { name = "Long March", why = "MotD spam modifier — only with March of the Dead" },
            { name = "Corpse Wagon", why = "Raid damage buff + Corpse Explosion — situational group value" },
            { name = "Skeletal Mastery", why = "Only if investing skeletons" },
            { name = "Artillery", why = "Only if investing skeletons" },
        },
    },
    {
        id = "SKIP",
        label = "Skip / last for ST calibration",
        entries = {
            { name = "Mass Grave", why = "AoE fear CC — not army size" },
            { name = "Fetid Mark", why = "Skeletal warrior only" },
            { name = "Bone Plating", why = "Survivability only" },
            { name = "Acrid Aegis", why = "Defensive" },
            { name = "Will of the Necropolis", why = "Survivability" },
            { name = "Crypt Scarabs", why = "Utility" },
            { name = "Wands", why = "No minion DPS" },
            { name = "Black Hook", why = "Abom path utility" },
            { name = "Flesh Laboratory", why = "Utility" },
            { name = "Corpse Handling", why = "Utility" },
            { name = "Locust", why = "Utility / AoE" },
            { name = "Guts", why = "Utility" },
            { name = "Ritual Casting", why = "Behind Graverobber for cast speed" },
            { name = "Zombimancy", why = "Needs Unrelenting investment" },
            { name = "Anti-Magic Shell", why = "Raised-minion magic absorb — survivability, not DPS" },
            { name = "Flesh Symbiosis", why = "Armor / MR / regen from Abom — defensive" },
            { name = "Lich's Prodigy", why = "Glacial Tap RP — resource, not army DPS" },
            { name = "Plague Protection", why = "Ward effectiveness — utility" },
            { name = "Putrifier", why = "Ghoulify / Mass Grave duration — CC utility" },
            { name = "Summoner", why = "Sacrifice Undead cost/CD — utility" },
            { name = "Summoning Ritual", why = "Ritual Return utility — not army DPS" },
        },
    },
}

-- CoA point schedule (lvl 10–60):
--   Even levels 10,12,…60 → Class tree (left / TabType 87)  → 26 points
--   Odd  levels 11,13,…59 → Spec  tree (Animation TabType 61) → 25 points
-- First point at 10 is Class; second at 11 is Spec; then alternate.
TalentRoute.POINT_SCHEDULE = {
    firstLevel = 10,
    lastLevel = 60,
    -- Even → class, odd → spec (matches 10 class, 11 spec).
    classOnEvenLevels = true,
    classPointsTotal = 26,
    specPointsTotal = 25,
    -- CA TabType values (dbc ClassType/TabType cols formerly mislabeled X/Y).
    classTabType = 87,
    animationTabType = 61,
}

-- Which tree gets the talent point awarded at `level`. Returns "class", "spec", or nil.
function TalentRoute:PointTreeAtLevel(level)
    level = tonumber(level)
    local sch = self.POINT_SCHEDULE
    if not level or level < sch.firstLevel or level > sch.lastLevel then
        return nil
    end
    local even = (level % 2) == 0
    if sch.classOnEvenLevels then
        return even and "class" or "spec"
    end
    return even and "spec" or "class"
end

-- Earliest character level that grants the Nth class point (1-indexed).
function TalentRoute:LevelForClassPoints(count)
    count = tonumber(count)
    if not count or count <= 0 then
        return nil
    end
    local sch = self.POINT_SCHEDULE
    -- Class points: 10,12,14,… → level = 10 + (n-1)*2
    return sch.firstLevel + (count - 1) * 2
end

-- Earliest character level that grants the Nth spec (Animation) point (1-indexed).
function TalentRoute:LevelForSpecPoints(count)
    count = tonumber(count)
    if not count or count <= 0 then
        return nil
    end
    local sch = self.POINT_SCHEDULE
    -- Spec points: 11,13,15,… → level = 11 + (n-1)*2
    return (sch.firstLevel + 1) + (count - 1) * 2
end

-- Class + spec points available by `level` (inclusive). Returns classCount, specCount.
function TalentRoute:PointsAvailableByLevel(level)
    level = tonumber(level) or UnitLevel("player") or 0
    local sch = self.POINT_SCHEDULE
    local classN, specN = 0, 0
    for lvl = sch.firstLevel, math.min(level, sch.lastLevel) do
        if self:PointTreeAtLevel(lvl) == "class" then
            classN = classN + 1
        else
            specN = specN + 1
        end
    end
    return classN, specN
end

TalentRoute.CHECKPOINTS = {
    { range = "~10–20", steps = "Lvl 10 class root → 11+ Animation S: Raise: Ghoul → Graverobber → Mindless Fury (haste first) → early Command → Depravity when free." },
    { range = "~20–33", steps = "LF summoning line → fill ghouls → Ghoul Mastery/Keeper → Forbidden Technique → Bone Wraith." },
    { range = "~33–45", steps = "Summoning Mastery → Sepulchral Might → Unrelenting Army → Raise: Abomination + Army of the Dead (ghoul haste) when LF fits." },
    { range = "~45–52+", steps = "Archer / Scourge Disciple / Fetid Frenzy / Plague Horde haste picks; hybrid polish. Keep LF filled." },
}

-- Ordered picks for the CoA talent overlay (skip already taken / pending).
-- Animation tree — rebuild one pick at a time with the player.
-- Entries may be a name string (needs 1 rank) or { name=, ranks= } for multi-rank.
-- #1 Animate: Skeletal Archer — CA 7345 / spell 805040
-- #2 Bone King — CA 7143 / spell 707175 (aura also 707176)
-- #3 Sepulchral Might 1/2 — unlocks Raise: Ghoul
-- #4 Raise: Ghoul → #5 Graverobber → #6 Forbidden Technique → #7 Runic Animation
-- #8 Sepulchral Might 2/2 — finish after Runic Animation
-- #9 Ghoul Mastery → #10 Summoning Prodigy → #11 Scourge Disciple
-- #12 Animate: Bone Wraith — tip SP×0.4 Bonestorm outscales Tomb King α≈10% army convert
-- #13 Unrelenting Army 1/? → #14 Mindless Fury
-- #15 Skeletal Artillery 1/? → #16 March of the Dead
-- #17 Animate: Plaguefather (CA 33748) → #18 Unrelenting (CA 11112) → #19 Corpse Wagon (CA 7350)
-- #20 Unrelenting Army 2/? → #21 Skeletal Artillery 2/?
-- #22 Unstoppable Frenzy (CA 33773)
-- #23 Lich's Prodigy (CA 33772) → #24 Plague Horde (CA 4238) → #25 Master Animator (CA 7117)
TalentRoute.OVERLAY_SPEC_ORDER = {
    "Animate: Skeletal Archer",
    "Bone King",
    { name = "Sepulchral Might", ranks = 1 },
    "Raise: Ghoul",
    "Graverobber",
    "Forbidden Technique",
    "Runic Animation",
    { name = "Sepulchral Might", ranks = 2 },
    "Ghoul Mastery",
    "Summoning Prodigy",
    "Scourge Disciple",
    "Animate: Bone Wraith",
    { name = "Unrelenting Army", ranks = 1 },
    "Mindless Fury",
    { name = "Skeletal Artillery", ranks = 1 },
    "March of the Dead",
    { name = "Animate: Plaguefather", entryId = 33748 },
    { name = "Unrelenting", entryId = 11112 },
    { name = "Corpse Wagon", entryId = 7350 },
    { name = "Unrelenting Army", ranks = 2 },
    { name = "Skeletal Artillery", ranks = 2 },
    { name = "Unstoppable Frenzy", entryId = 33773 },
    { name = "Lich's Prodigy", entryId = 33772 },
    { name = "Plague Horde", entryId = 4238 },
    { name = "Master Animator", entryId = 7117 },
    -- Rest paused until the early route above is verified in-game.
    "Depravity",
    "Army of the Dead",
    "Underking",
    "Chomp",
    "Animate: Tomb King",
    "Crypt Keeper",
}

-- Class tree — rebuild one pick at a time with the player.
-- Raise: Abomination (CA 29364) is auto-granted at level 10 — skip in overlay.
TalentRoute.OVERLAY_CLASS_ORDER = {
    { name = "Hulking Hordes", entryId = 6885, ranks = 1 },           -- 1
    { name = "Vampiric Aura", entryId = 6458 },                       -- 2
    { name = "Life For Power", entryId = 6903 },                      -- 3
    { name = "Hulking Hordes", entryId = 6885, ranks = 2 },           -- 4
    { name = "Living Dead", entryId = 30833, ranks = 1 },             -- 5
    { name = "Living Dead", entryId = 30833, ranks = 2 },             -- 6
    { name = "Overwhelming Force", entryId = 6897 },                  -- 7
    { name = "Reclaimed Life" },                                     -- 8
    { name = "Disciple of Kel'thuzad", entryId = 33784, ranks = 1 },  -- 9
    { name = "Icecrown Scriptures", entryId = 6459, ranks = 1 },     -- 10
    { name = "Disciple of Kel'thuzad", entryId = 33784, ranks = 2 },  -- 11
    { name = "Icecrown Scriptures", entryId = 6459, ranks = 2 },     -- 12
    { name = "Mass Grave", entryId = 33778 },                        -- 13
    { name = "Lich Commander", entryId = 5781 },                     -- 14
    { name = "Create Frozen Reliquary", entryId = 34980 },           -- 15
    { name = "Ner'zhul's Blessing", entryId = 31143 },               -- 16
    { name = "Death's Gate", entryId = 29788 },                      -- 17
    { name = "Improved Mandates", entryId = 34977 },                 -- 18
    { name = "Cobalt-Plated Armour", entryId = 6555 },               -- 19
    { name = "Frost Runes", entryId = 33771 },                      -- 20
    { name = "Animate: Frost Wyrm", entryId = 30600 },              -- 21
}

local function NormalizeTalentName(name)
    if not name then
        return ""
    end
    name = tostring(name)
    name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    return string.lower(name)
end

local function EntryRankKey(entryId)
    entryId = tonumber(entryId)
    if not entryId then
        return nil
    end
    return "#" .. tostring(entryId)
end

local function ParseOrderEntry(entry)
    if type(entry) == "table" then
        return entry.name, math.max(1, tonumber(entry.ranks) or 1), tonumber(entry.entryId)
    end
    return entry, 1, nil
end

function TalentRoute:NamesEqual(a, b)
    if not a or not b then
        return false
    end
    return NormalizeTalentName(a) == NormalizeTalentName(b)
end

-- Fuzzy match for tooltips / loose lookups. Do NOT use for route rank progress —
-- "Unrelenting" must not count as "Unrelenting Army".
function TalentRoute:NamesMatch(a, b)
    if not a or not b then
        return false
    end
    local na, nb = NormalizeTalentName(a), NormalizeTalentName(b)
    return na == nb or na:find(nb, 1, true) or nb:find(na, 1, true)
end

function TalentRoute:GetRankForPick(name, entryId, rankMap)
    if not rankMap then
        return 0
    end
    local idKey = EntryRankKey(entryId)
    if idKey then
        local byId = rankMap[idKey]
        if type(byId) == "number" then
            return byId
        end
        if byId == true then
            return 1
        end
    end
    if not name then
        return 0
    end
    local key = NormalizeTalentName(name)
    local direct = rankMap[key]
    if type(direct) == "number" then
        return direct
    end
    if direct == true then
        return 1
    end
    -- Exact name only (never substring — avoids Unrelenting ↔ Unrelenting Army).
    return 0
end

function TalentRoute:GetRankForName(name, rankMap)
    return self:GetRankForPick(name, nil, rankMap)
end

function TalentRoute:HasAtLeastRank(name, rankMap, need, entryId)
    return self:GetRankForPick(name, entryId, rankMap) >= (need or 1)
end

-- Back-compat: boolean / truthy taken sets still work (any rank counts as taken).
function TalentRoute:IsNameInTakenSet(name, takenSet)
    if not name or not takenSet then
        return false
    end
    return self:HasAtLeastRank(name, takenSet, 1)
end

-- rankExtras: optional map of display-name / "#entryId" → rank (from CoA tree),
-- or a legacy list of names that each count as at least rank 1.
-- When the open tree provides extras, those ranks win (including 0 after unlearn).
-- Do not math.max with GetKnownTalents for the same keys — that kept unlearned picks
-- highlighted as "taken" until the known list lagged behind.
function TalentRoute:BuildTakenRankMap(rankExtras)
    local ranks = {}

    local function note(name, rank, entryId)
        local n = tonumber(rank) or 0
        if name then
            local key = NormalizeTalentName(name)
            if n <= 0 then
                ranks[key] = nil
            else
                ranks[key] = math.max(ranks[key] or 0, n)
            end
        end
        local idKey = EntryRankKey(entryId)
        if idKey then
            if n <= 0 then
                ranks[idKey] = nil
            else
                ranks[idKey] = math.max(ranks[idKey] or 0, n)
            end
        end
    end

    local function applyExtra(key, rank)
        local n = tonumber(rank) or 0
        if type(key) ~= "string" then
            return
        end
        if key:sub(1, 1) == "#" then
            if n <= 0 then
                ranks[key] = nil
            else
                ranks[key] = n
            end
            return
        end
        note(key, n)
    end

    local hasTreeExtras = false
    if type(rankExtras) == "table" then
        if rankExtras[1] ~= nil then
            hasTreeExtras = true
        else
            for _ in pairs(rankExtras) do
                hasTreeExtras = true
                break
            end
        end
    end

    -- Known list only when the talent UI did not supply a live tree map.
    if not hasTreeExtras and Mancer.Ascension and Mancer.Ascension.GetKnownTalents then
        if Mancer.Ascension.InvalidateTalentCache then
            Mancer.Ascension.InvalidateTalentCache()
        end
        for _, talent in ipairs(Mancer.Ascension.GetKnownTalents() or {}) do
            if talent.name or talent.id then
                note(talent.name, talent.rank or 1, talent.id)
            end
        end
    end

    if type(rankExtras) == "table" then
        if rankExtras[1] ~= nil then
            for _, name in ipairs(rankExtras) do
                note(name, 1)
            end
        else
            for key, rank in pairs(rankExtras) do
                applyExtra(key, rank)
            end
        end
    end

    return ranks
end

-- Legacy alias used by older callers.
function TalentRoute:BuildTakenNameSet(extraNames)
    return self:BuildTakenRankMap(extraNames)
end

function TalentRoute:GetNextInOrder(order, rankMap)
    if not order then
        return nil
    end
    for _, entry in ipairs(order) do
        local name, need, entryId = ParseOrderEntry(entry)
        if name and not self:HasAtLeastRank(name, rankMap, need, entryId) then
            return name, entryId
        end
    end
    return nil
end

-- Returns free / class / spec next picks for the overlay.
-- rankExtras: name→rank map from the open CoA tree (preferred), or name list.
function TalentRoute:GetNextOverlayPicks(rankExtras)
    local ranks = self:BuildTakenRankMap(rankExtras)
    local level = UnitLevel and UnitLevel("player") or 0

    local free
    for _, entry in ipairs(self.FREE_PASSIVES or {}) do
        if (entry.level or 0) <= level and not self:HasAtLeastRank(entry.name, ranks, 1) then
            free = { name = entry.name, level = entry.level, why = entry.why, kind = "free" }
            break
        end
    end

    local className, classEntryId = self:GetNextInOrder(self.OVERLAY_CLASS_ORDER, ranks)
    local specName, specEntryId = self:GetNextInOrder(self.OVERLAY_SPEC_ORDER, ranks)

    local class = className and { name = className, entryId = classEntryId, kind = "class" } or nil
    local spec = specName and { name = specName, entryId = specEntryId, kind = "spec" } or nil

    if spec and spec.name == "Army of the Dead" and not self:HasAtLeastRank("Raise: Abomination", ranks, 1, 29364) then
        spec.blocked = true
        spec.blockReason = "Take Raise: Abomination (Class) first"
        if not class then
            class = { name = "Raise: Abomination", entryId = 29364, kind = "class", why = "Required for Army of the Dead" }
        elseif class.name ~= "Raise: Abomination" then
            -- Prefer Abom as class next when Spec is blocked on AotD.
            class = { name = "Raise: Abomination", entryId = 29364, kind = "class", why = "Required for Army of the Dead" }
        end
    end

    return {
        free = free,
        class = class,
        spec = spec,
        taken = ranks,
    }
end

function TalentRoute:IsFreePassive(name)
    if not name then
        return false
    end
    for _, entry in ipairs(self.FREE_PASSIVES or {}) do
        if entry.name == name then
            return true, entry.level, entry.why
        end
    end
    return false
end
