-- Character macros: cast a spell + Grave March (minion AI workaround).
-- Never overwrites existing macros by name.
-- Ascension 3.3.5: CreateMacro(name, iconIndex, body, perCharacter) — icon is numeric.

Mancer = Mancer or {}
local Macros = {}
Mancer.Macros = Macros

local MAX_CHARACTER_MACROS = 18
local DEFAULT_ICON_INDEX = 1 -- INV_Misc_QuestionMark

-- Exact spell names as they appear on Ascension Animation Necro.
local GRAVE_MARCH_SPELLS = {
    "Lichfrost",
    "Crypt Swarm",
    "Harvest Plague",
    "Command: Undead",
    "Blight",
    "Unholy Frenzy",
}

local function NormalizeIconKey(texture)
    if type(texture) ~= "string" or texture == "" then
        return nil
    end
    local file = texture:match("([^\\/]+)$") or texture
    file = file:gsub("%.blp$", ""):gsub("%.tga$", "")
    return string.lower(file)
end

local function MacroIconIndexForSpell(spellName)
    local want = NormalizeIconKey(select(3, GetSpellInfo(spellName)))
    local numIcons = (GetNumMacroIcons and GetNumMacroIcons()) or 0
    if want and numIcons > 0 and GetMacroIconInfo then
        for i = 1, numIcons do
            if NormalizeIconKey(GetMacroIconInfo(i)) == want then
                return i
            end
        end
    end
    return DEFAULT_ICON_INDEX
end

local function BuildBody(spellName)
    return "#showtooltip\n/cast " .. spellName .. "\n/cast Grave March"
end

local function CharacterMacroCount()
    local account, character = GetNumMacros()
    return tonumber(character) or 0, tonumber(account) or 0
end

--- Install per-character macros. Skips any name that already exists (account or character).
--- @return table lines  human-readable result lines
function Macros:InstallGraveMarchSet()
    local lines = {}

    if InCombatLockdown and InCombatLockdown() then
        table.insert(lines, "Leave combat first — macros can't be created in combat.")
        return lines
    end

    if type(CreateMacro) ~= "function" then
        table.insert(lines, "CreateMacro API not available on this client.")
        return lines
    end

    -- Must call GetNumMacroIcons before GetMacroIconInfo on 3.3.5.
    if GetNumMacroIcons then
        GetNumMacroIcons()
    end

    local created, skipped, failed = 0, 0, 0
    local charCount = CharacterMacroCount()

    for _, spellName in ipairs(GRAVE_MARCH_SPELLS) do
        local existing = GetMacroIndexByName and GetMacroIndexByName(spellName) or 0
        if existing and existing > 0 then
            skipped = skipped + 1
            table.insert(lines, "Skip " .. spellName .. " (already exists)")
        elseif charCount >= MAX_CHARACTER_MACROS then
            failed = failed + 1
            table.insert(lines, "Fail " .. spellName .. " (character macro slots full)")
        else
            local iconIndex = MacroIconIndexForSpell(spellName)
            local ok, result = pcall(CreateMacro, spellName, iconIndex, BuildBody(spellName), 1)
            if ok and result then
                created = created + 1
                charCount = charCount + 1
                table.insert(lines, "Created " .. spellName)
            else
                failed = failed + 1
                local err = (not ok and tostring(result)) or "unknown error"
                table.insert(lines, "Fail " .. spellName .. " (" .. err .. ")")
            end
        end
    end

    if MacroFrame_Update and MacroFrame and MacroFrame:IsShown() then
        pcall(MacroFrame_Update)
    end

    table.insert(lines, 1, string.format(
        "Grave March macros — created %d, skipped %d, failed %d",
        created, skipped, failed
    ))
    table.insert(lines, 2, "Each macro: #showtooltip → /cast <spell> → /cast Grave March")
    table.insert(lines, 3, "Open /macro (character tab) to drag them onto your bars.")
    return lines
end

function Macros:GetSpellList()
    return GRAVE_MARCH_SPELLS
end
