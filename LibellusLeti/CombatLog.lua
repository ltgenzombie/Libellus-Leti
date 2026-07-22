Mancer.CombatLog = {}
local CombatLog = Mancer.CombatLog

local function GetCleuAPI()
    return _G.CombatLogGetCurrentEventInfo
end

local function ParseFromVarargs(...)
    local argCount = select("#", ...)
    if argCount < 1 then
        return nil
    end

    local tokenIdx = 2
    local token = select(2, ...)
    if type(token) ~= "string" then
        token = select(1, ...)
        tokenIdx = 1
    end
    if type(token) ~= "string" then
        return nil
    end

    local timestamp = nil
    if tokenIdx == 2 then
        timestamp = select(1, ...)
    end

    local idx = tokenIdx + 1
    if type(select(idx, ...)) == "boolean" then
        idx = idx + 1
    end

    local sourceGUID = select(idx, ...)
    local sourceName = select(idx + 1, ...)
    local sourceFlags = select(idx + 2, ...)
    idx = idx + 3

    if type(select(idx, ...)) == "number" and type(select(idx + 1, ...)) == "string"
        and tostring(select(idx + 1, ...)):find("-", 1, true) then
        idx = idx + 1
    end

    local destGUID = select(idx, ...)
    local destName = select(idx + 1, ...)
    local destFlags = select(idx + 2, ...)
    idx = idx + 3

    if token == "SWING_DAMAGE" or token == "SWING_MISSED" then
        if type(select(idx, ...)) == "number" and type(select(idx + 1, ...)) == "string"
            and tostring(select(idx + 1, ...)):find("-", 1, true) then
            idx = idx + 1
        end
    elseif type(select(idx, ...)) == "number" and type(select(idx + 1, ...)) == "number" then
        idx = idx + 1
    end

    local A1 = select(idx, ...)
    local A2 = select(idx + 1, ...)
    local A3 = select(idx + 2, ...)
    local A4 = select(idx + 3, ...)

    return timestamp, token, nil, sourceGUID, sourceName, sourceFlags, nil,
        destGUID, destName, destFlags, nil,
        A1, A2, A3, A4, "varargs"
end

local function PackCleuReturns(timestamp, token, hideCaster, sourceGUID, sourceName, sourceFlags, sourceFlags2,
    destGUID, destName, destFlags, destFlags2,
    A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12, parseMode)
    return timestamp, token, hideCaster, sourceGUID, sourceName, sourceFlags, sourceFlags2,
        destGUID, destName, destFlags, destFlags2,
        A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12, parseMode
end

local function ReadCleuFields(...)
    local cleu = GetCleuAPI()
    if cleu then
        -- Prefer zero-arg read: correct for COMBAT_LOG_EVENT_UNFILTERED on 3.x clients.
        local timestamp, token, hideCaster, sourceGUID, sourceName, sourceFlags, sourceFlags2,
            destGUID, destName, destFlags, destFlags2,
            A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12 =
            cleu()

        if token then
            return PackCleuReturns(timestamp, token, hideCaster, sourceGUID, sourceName, sourceFlags, sourceFlags2,
                destGUID, destName, destFlags, destFlags2,
                A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12, "cleu")
        end

        -- Fallback: some builds pass payload varargs into the handler (Details-style).
        timestamp, token, hideCaster, sourceGUID, sourceName, sourceFlags, sourceFlags2,
            destGUID, destName, destFlags, destFlags2,
            A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12 =
            cleu(...)

        if token then
            return PackCleuReturns(timestamp, token, hideCaster, sourceGUID, sourceName, sourceFlags, sourceFlags2,
                destGUID, destName, destFlags, destFlags2,
                A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12, "cleu-varargs")
        end
    end

    return ParseFromVarargs(...)
end

function CombatLog.IsAvailable()
    return GetCleuAPI() ~= nil
end

local function ExtractDamageAmount(token, A1, A2, A3, A4, A5)
    if token == "SWING_DAMAGE" then
        return tonumber(A1) or 0
    end

    if token == "SPELL_DAMAGE" or token == "SPELL_PERIODIC_DAMAGE" or token == "RANGE_DAMAGE" then
        local amount = tonumber(A4) or tonumber(A3) or tonumber(A5) or 0
        return amount
    end

    if token == "DAMAGE_SPLIT" then
        return tonumber(A3) or tonumber(A4) or 0
    end

    return 0
end

function CombatLog.Parse(...)
    local timestamp, token, hideCaster, sourceGUID, sourceName, sourceFlags, sourceFlags2,
        destGUID, destName, destFlags, destFlags2,
        A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12, parseMode = ReadCleuFields(...)

    if not token then
        return nil
    end

    local spellId, spellName, amount = nil, nil, 0

    if token == "SWING_DAMAGE" then
        amount = ExtractDamageAmount(token, A1, A2, A3, A4, A5)
    elseif token == "SPELL_DAMAGE" or token == "SPELL_PERIODIC_DAMAGE" or token == "RANGE_DAMAGE" then
        spellId = tonumber(A1)
        spellName = A2
        amount = ExtractDamageAmount(token, A1, A2, A3, A4, A5)
    elseif token == "DAMAGE_SPLIT" then
        spellId = tonumber(A1)
        spellName = A2
        amount = ExtractDamageAmount(token, A1, A2, A3, A4, A5)
    elseif token == "SPELL_SUMMON" or token == "SPELL_CAST_SUCCESS"
        or token == "SPELL_AURA_APPLIED" or token == "SPELL_AURA_REFRESH"
        or token == "SPELL_AURA_REMOVED" or token == "SPELL_AURA_APPLIED_DOSE"
        or token == "SPELL_AURA_REMOVED_DOSE" then
        spellId = tonumber(A1)
        spellName = A2
    elseif token == "UNIT_DIED" or token == "UNIT_DESTROYED" or token == "PARTY_KILL" then
        -- destGUID/destName already set; no spell payload
        spellId = nil
        spellName = nil
    end

    return {
        eventType = token,
        timestamp = timestamp,
        sourceGUID = sourceGUID,
        sourceName = sourceName,
        sourceFlags = sourceFlags,
        destGUID = destGUID,
        destName = destName,
        destFlags = destFlags,
        spellId = spellId,
        spellName = spellName,
        amount = amount,
        parseMode = parseMode or (GetCleuAPI() and "cleu" or "varargs"),
    }
end

function CombatLog.GetPayload(...)
    return { ReadCleuFields(...) }
end

function CombatLog.ParseInline(...)
    return CombatLog.Parse(...)
end
