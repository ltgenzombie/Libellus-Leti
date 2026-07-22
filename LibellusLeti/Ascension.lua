Mancer.Ascension = Mancer.Ascension or {}
local Ascension = Mancer.Ascension

Ascension.SPEC = {
    DEATH_NECROMANCER = 34,
    ANIMATION_NECROMANCER = 35,
    RIME_NECROMANCER = 36,
}

Ascension.NECROMANCER_SPEC_IDS = {
    Ascension.SPEC.DEATH_NECROMANCER,
    Ascension.SPEC.ANIMATION_NECROMANCER,
    Ascension.SPEC.RIME_NECROMANCER,
}

function Ascension.HasCharacterAdvancement()
    return C_CharacterAdvancement
        and C_CharacterAdvancement.IsKnownSpellID
        and C_CharacterAdvancement.GetKnownTalentEntries
end

function Ascension.GetPlayerClass()
    local _, class = UnitClass("player")
    return class
end

function Ascension.GetClassSpecInfo(class, index)
    if not class or not index or index <= 0 or not C_ClassInfo then
        return nil
    end

    if C_ClassInfo.GetAllSpecs and C_ClassInfo.GetSpecInfo then
        local specs = C_ClassInfo.GetAllSpecs(class)
        if specs then
            local specKey = specs[index]
            if specKey then
                local info = C_ClassInfo.GetSpecInfo(class, specKey)
                if info then
                    return info
                end
            end
        end

        local info = C_ClassInfo.GetSpecInfo(class, index)
        if info then
            return info
        end
    end

    if C_ClassInfo.GetSpecInfoByID and class == "NECROMANCER" then
        local specId = Ascension.NECROMANCER_SPEC_IDS[index]
        if specId then
            return C_ClassInfo.GetSpecInfoByID(specId)
        end
    end

    return nil
end

function Ascension.ResolveSpecFromIndex(class, index)
    local info = Ascension.GetClassSpecInfo(class, index)
    if info and info.ID then
        return info.ID, info.Name or info.SpecFilename
    end

    if class == "NECROMANCER" and Ascension.NECROMANCER_SPEC_IDS[index] then
        return Ascension.NECROMANCER_SPEC_IDS[index], nil
    end

    return nil, nil
end

function Ascension.GetActiveSpecIndex()
    if GetSpecialization then
        local index = GetSpecialization()
        if index and index > 0 then
            return index
        end
    end

    if SpecializationUtil and SpecializationUtil.GetActiveSpecialization then
        local raw = SpecializationUtil.GetActiveSpecialization()
        if raw and raw > 0 and raw <= 10 then
            return raw
        end
    end

    return nil
end

function Ascension.GetActiveSpecName()
    local class = Ascension.GetPlayerClass()
    local index = Ascension.GetActiveSpecIndex()

    if index and GetSpecializationInfo then
        local _, name = GetSpecializationInfo(index)
        if name and name ~= "" then
            return name
        end
    end

    if index and class then
        local info = Ascension.GetClassSpecInfo(class, index)
        if info then
            return info.Name or info.SpecFilename
        end
    end

    if SpecializationUtil and SpecializationUtil.GetActiveSpecialization and SpecializationUtil.GetSpecializationInfo then
        local raw = SpecializationUtil.GetActiveSpecialization()
        if raw and raw <= 10 then
            local name = SpecializationUtil.GetSpecializationInfo(raw)
            if name and name ~= "" then
                return name
            end
        end
    end

    local specId = Ascension.GetActiveSpecId()
    if specId and C_ClassInfo and C_ClassInfo.GetSpecInfoByID then
        local info = C_ClassInfo.GetSpecInfoByID(specId)
        if info then
            return info.Name or info.SpecFilename
        end
    end

    return nil
end

function Ascension.GetActiveSpecId()
    local class = Ascension.GetPlayerClass()
    local index = Ascension.GetActiveSpecIndex()

    if index and GetSpecializationInfo then
        local id = select(1, GetSpecializationInfo(index))
        if id and id >= 30 then
            return id
        end
    end

    if index and class then
        local id = select(1, Ascension.ResolveSpecFromIndex(class, index))
        if id then
            return id
        end
    end

    if SpecializationUtil and SpecializationUtil.GetActiveSpecialization then
        local raw = SpecializationUtil.GetActiveSpecialization()
        if raw and raw >= 30 then
            return raw
        end
        if raw and raw > 0 and raw <= 10 and class then
            local id = select(1, Ascension.ResolveSpecFromIndex(class, raw))
            if id then
                return id
            end
        end
    end

    return nil
end

local function NormalizeName(name)
    if not name then
        return ""
    end
    return string.lower(name)
end

function Ascension.IsSpecNameMatch(name, pattern)
    if not name or not pattern then
        return false
    end
    return NormalizeName(name):find(NormalizeName(pattern), 1, true) ~= nil
end

function Ascension.IsAnimationNecromancer()
    if Ascension.GetPlayerClass() ~= "NECROMANCER" then
        return false
    end

    local specId = Ascension.GetActiveSpecId()
    if specId == Ascension.SPEC.ANIMATION_NECROMANCER then
        return true
    end

    local specName = Ascension.GetActiveSpecName()
    if Ascension.IsSpecNameMatch(specName, "Animation") then
        return true
    end

    return false
end

function Ascension.HasTalentSpell(spellId)
    if not spellId or spellId <= 0 then
        return false
    end

    if Ascension.HasCharacterAdvancement() then
        return C_CharacterAdvancement.IsKnownSpellID(spellId) and true or false
    end

    if IsSpellKnown then
        return IsSpellKnown(spellId) and true or false
    end

    return false
end

function Ascension.GetTalentRankBySpell(spellId)
    if not spellId or spellId <= 0 or not Ascension.HasCharacterAdvancement() then
        return 0
    end

    local ok, rank = pcall(function()
        local internalId = C_CharacterAdvancement.GetInternalID(spellId)
        if not internalId then
            return 0
        end
        return select(1, C_CharacterAdvancement.GetTalentRankByID(internalId)) or 0
    end)

    if not ok or not rank then
        return 0
    end
    return rank
end

function Ascension.HasActiveTalentSpell(spellId)
    if not spellId or spellId <= 0 then
        return false
    end

    if Ascension.HasCharacterAdvancement() then
        return Ascension.GetTalentRankBySpell(spellId) > 0
    end

    return Ascension.HasTalentSpell(spellId)
end

local knownTalentsCache = nil
local knownTalentsUntil = 0
local KNOWN_TALENTS_TTL = 2.0

function Ascension.InvalidateTalentCache()
    knownTalentsCache = nil
    knownTalentsUntil = 0
end

function Ascension.GetKnownTalents()
    local now = GetTime and GetTime() or 0
    if knownTalentsCache and now < knownTalentsUntil then
        return knownTalentsCache
    end

    local talents = {}

    if Ascension.HasCharacterAdvancement() then
        local ok, entries = pcall(C_CharacterAdvancement.GetKnownTalentEntries)
        if ok and entries then
            -- Ascension may return a hash keyed by talent ID — use pairs, not ipairs.
            for _, entry in pairs(entries) do
                if type(entry) == "table" then
                    local name = entry.name or entry.Name
                    if name then
                        table.insert(talents, {
                            id = entry.ID or entry.id,
                            name = name,
                            icon = entry.icon or entry.Icon,
                            rank = entry.rank or entry.Rank or entry.currentRank or entry.CurrentRank,
                        })
                    end
                end
            end
        end
        knownTalentsCache = talents
        knownTalentsUntil = now + KNOWN_TALENTS_TTL
        return talents
    end

    if GetNumTalentTabs and GetNumTalents and GetTalentInfo then
        local group = GetActiveTalentGroup and GetActiveTalentGroup() or 1
        for tab = 1, GetNumTalentTabs(false, false) do
            for talentIndex = 1, GetNumTalents(tab, false, false) do
                local name, _, _, _, rank = GetTalentInfo(tab, talentIndex, false, false, group)
                if rank and rank > 0 then
                    table.insert(talents, { id = tab * 100 + talentIndex, name = name, rank = rank })
                end
            end
        end
    end

    knownTalentsCache = talents
    knownTalentsUntil = now + KNOWN_TALENTS_TTL
    return talents
end

function Ascension.HasTalentByName(namePattern)
    if not namePattern or namePattern == "" then
        return false
    end

    local pattern = NormalizeName(namePattern)
    for _, talent in ipairs(Ascension.GetKnownTalents()) do
        local talentName = NormalizeName(talent.name)
        if talentName:find(pattern, 1, true) then
            return true, talent
        end
    end

    return false
end

function Ascension.PrintSpecInfo()
    local class = Ascension.GetPlayerClass() or "?"
    local index = Ascension.GetActiveSpecIndex()
    local specId = Ascension.GetActiveSpecId()
    local specName = Ascension.GetActiveSpecName()

    Mancer.Print(string.format(
        "Class: %s | Index: %s | Spec ID: %s | Name: %s | Animation: %s",
        class,
        tostring(index),
        tostring(specId),
        tostring(specName),
        tostring(Ascension.IsAnimationNecromancer())
    ))
end