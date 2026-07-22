-- Stack duplicate auras on the default buff bar (same spell ID → one icon + count).
--
-- Must run *inside* BuffFrame_UpdateAllBuffAnchors *before* main-strip layout —
-- same timing as Ascension's consolidated/vanity flags. Hooking after layout
-- causes flicker: Blizzard places every icon, then we pull extras off, then the
-- next UpdateAllBuffAnchors puts them back.

Mancer.BuffConsolidateModule = {}
local Mod = Mancer.BuffConsolidateModule

local MAX_BUFF_BUTTONS = 40
local applying = false

local function IsEnabled()
    return MancerDB and MancerDB.consolidateBuffs == true
end

local function EnsureContainer()
    if Mod.container then
        return Mod.container
    end
    local frame = CreateFrame("Frame", "MancerRaiseBuffsContainer", UIParent)
    frame:Hide()
    frame:SetSize(1, 1)
    Mod.container = frame
    return frame
end

local function ReadAura(index)
    if not index or index < 1 then
        return nil
    end
    local name, _, _, count, _, _, _, _, _, _, spellId
    if UnitAura then
        name, _, _, count, _, _, _, _, _, _, spellId = UnitAura("player", index, "HELPFUL")
    elseif UnitBuff then
        name, _, _, count, _, _, _, _, _, _, spellId = UnitBuff("player", index)
    else
        return nil
    end
    if not name then
        return nil
    end
    return name, tonumber(spellId), math.max(1, tonumber(count) or 1)
end

local function AuraIndexForButton(button, fallbackIndex)
    if not button then
        return fallbackIndex
    end
    if button.GetID then
        local id = button:GetID()
        if id and id > 0 then
            return id
        end
    end
    return fallbackIndex
end

local function ClearMarks(button)
    if not button then
        return
    end
    button.mancerRaiseDup = nil
    button.mancerRaiseKeeper = nil
    button.mancerRaiseTotal = nil
end

local function RestoreToBuffFrame(button)
    if not button then
        return
    end
    ClearMarks(button)
    if BuffFrame and button.parent ~= BuffFrame then
        button:SetParent(BuffFrame)
        button.parent = BuffFrame
    end
end

-- Mark duplicate spell-ID groups. Extras are flagged + reparented off-strip
-- *before* Ascension-style layout so they are never placed on the main row.
local function MarkDuplicates()
    local container = EnsureContainer()
    local groups = {}
    local order = {}
    local actual = BUFF_ACTUAL_DISPLAY or 0

    for i = 1, actual do
        local button = _G["BuffButton" .. i]
        ClearMarks(button)
        -- Do not require IsShown(): AuraButton_Update re-Shows everyone, then our
        -- aura hook may already have re-hidden last-pass duplicates.
        if button and not button.consolidated and not button.vanity then
            local auraIndex = AuraIndexForButton(button, i)
            local name, spellId, count = ReadAura(auraIndex)
            if name and spellId and spellId > 0 then
                local group = groups[spellId]
                if not group then
                    group = { buttons = {}, total = 0 }
                    groups[spellId] = group
                    table.insert(order, spellId)
                end
                group.total = group.total + count
                table.insert(group.buttons, button)
            end
        end
    end

    for _, spellId in ipairs(order) do
        local group = groups[spellId]
        if group and #group.buttons > 1 then
            for idx, button in ipairs(group.buttons) do
                if idx == 1 then
                    button.mancerRaiseKeeper = true
                    button.mancerRaiseTotal = group.total
                    local countFS = button.count or _G[button:GetName() .. "Count"]
                    if countFS then
                        countFS:SetText(tostring(group.total))
                        countFS:Show()
                    end
                    if not button:IsShown() then
                        button:Show()
                    end
                else
                    button.mancerRaiseDup = true
                    if button.parent ~= container then
                        button:SetParent(container)
                        button.parent = container
                    end
                    button:ClearAllPoints()
                    button:Hide()
                end
            end
        end
    end
end

-- Ascension BuffFrame_UpdateAllBuffAnchors, plus skip mancerRaiseDup.
local function LayoutMainStrip()
    local buff, previousBuff, aboveBuff
    local numBuffs = 0
    local slack = BuffFrame.numEnchants or 0
    if (BuffFrame.numConsolidated or 0) > 0 or (BuffFrame.numVanity or 0) > 0 then
        slack = slack + 1
    end

    local actual = BUFF_ACTUAL_DISPLAY or 0
    local rowSpacing = BUFF_ROW_SPACING or 5
    local perRow = BUFFS_PER_ROW or 8

    for i = 1, actual do
        buff = _G["BuffButton" .. i]
        if not buff then
            -- skip
        elseif buff.consolidated then
            if ConsolidatedBuffsContainer and buff.parent ~= ConsolidatedBuffsContainer then
                buff:SetParent(ConsolidatedBuffsContainer)
                buff.parent = ConsolidatedBuffsContainer
            end
        elseif buff.vanity then
            if VanityBuffsContainer and buff.parent ~= VanityBuffsContainer then
                buff:SetParent(VanityBuffsContainer)
                buff.parent = VanityBuffsContainer
            end
        elseif buff.mancerRaiseDup then
            -- Already off-strip; do not place on the main row.
        else
            numBuffs = numBuffs + 1
            local index = numBuffs + slack
            if buff.parent ~= BuffFrame then
                if buff.count and buff.count.SetFontObject then
                    buff.count:SetFontObject(NumberFontNormal)
                end
                buff:SetParent(BuffFrame)
                buff.parent = BuffFrame
            end
            if not buff:IsShown() then
                buff:Show()
            end
            buff:ClearAllPoints()
            if (index > 1) and (mod(index, perRow) == 1) then
                if index == perRow + 1 and ConsolidatedBuffs then
                    buff:SetPoint("TOP", ConsolidatedBuffs, "BOTTOM", 0, -rowSpacing)
                elseif aboveBuff then
                    buff:SetPoint("TOP", aboveBuff, "BOTTOM", 0, -rowSpacing)
                else
                    buff:SetPoint("TOPRIGHT", BuffFrame, "TOPRIGHT", 0, 0)
                end
                aboveBuff = buff
            elseif index == 1 then
                buff:SetPoint("TOPRIGHT", BuffFrame, "TOPRIGHT", 0, 0)
            else
                if numBuffs == 1 then
                    if (BuffFrame.numEnchants or 0) > 0 and TemporaryEnchantFrame then
                        buff:SetPoint("TOPRIGHT", TemporaryEnchantFrame, "TOPLEFT", -5, 0)
                    elseif (BuffFrame.numVanity or 0) > 0 and VanityBuffs then
                        buff:SetPoint("TOPRIGHT", VanityBuffs, "TOPLEFT", -5, 0)
                    elseif (BuffFrame.numConsolidated or 0) > 0 and ConsolidatedBuffs then
                        buff:SetPoint("TOPRIGHT", ConsolidatedBuffs, "TOPLEFT", -5, 0)
                    elseif ConsolidatedBuffs then
                        buff:SetPoint("TOPRIGHT", ConsolidatedBuffs, "TOPRIGHT", 0, 0)
                    else
                        buff:SetPoint("TOPRIGHT", BuffFrame, "TOPRIGHT", 0, 0)
                    end
                elseif previousBuff then
                    buff:SetPoint("RIGHT", previousBuff, "LEFT", -5, 0)
                end
            end
            previousBuff = buff
        end
    end

    if ConsolidatedBuffsTooltip and ConsolidatedBuffsTooltip:IsShown() and ConsolidatedBuffs_UpdateAllAnchors then
        ConsolidatedBuffs_UpdateAllAnchors()
    end
    if VanityBuffsTooltip and VanityBuffsTooltip:IsShown() and VanityBuffs_UpdateAllAnchors then
        VanityBuffs_UpdateAllAnchors()
    end
end

local function RestoreAllAndOrig(orig)
    for i = 1, MAX_BUFF_BUTTONS do
        local button = _G["BuffButton" .. i]
        if button and (button.mancerRaiseDup or button.mancerRaiseKeeper) then
            RestoreToBuffFrame(button)
            if button.Show then
                button:Show()
            end
        else
            ClearMarks(button)
        end
    end
    if orig then
        orig()
    end
end

function Mod:OnUpdateAllBuffAnchors(orig)
    if applying then
        return
    end
    applying = true

    if not IsEnabled() then
        RestoreAllAndOrig(orig)
        applying = false
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        self.needAfterCombat = true
        RestoreAllAndOrig(orig)
        applying = false
        return
    end

    MarkDuplicates()
    LayoutMainStrip()

    applying = false
end

-- Public entry used by Core:Refresh — do not call BuffFrame_Update from here
-- (that re-Shows every aura and fights our marks). Just re-anchor.
function Mod:ApplyConsolidation()
    if BuffFrame_UpdateAllBuffAnchors then
        BuffFrame_UpdateAllBuffAnchors()
    end
end

function Mod:Refresh()
    self:ApplyConsolidation()
end

function Mod:Init()
    if self.ready then
        return
    end
    self.ready = true

    if MancerDB then
        if MancerDB.consolidateBuffsFix320 == nil then
            MancerDB.consolidateBuffs = false
            MancerDB.consolidateBuffsFix320 = true
        elseif MancerDB.consolidateBuffs == nil then
            MancerDB.consolidateBuffs = false
        end
    end

    EnsureContainer()

    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
    end
    self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" and self.needAfterCombat then
            self.needAfterCombat = false
            if BuffFrame_Update then
                BuffFrame_Update()
            else
                Mod:ApplyConsolidation()
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            if BuffFrame_Update then
                BuffFrame_Update()
            end
        end
    end)

    -- Ascension re-Shows every BuffButton in AuraButton_Update. Keep last-pass
    -- duplicates hidden until MarkDuplicates runs so they never flash on-screen.
    if type(hooksecurefunc) == "function" and AuraButton_Update and not Mod._auraHooked then
        Mod._auraHooked = true
        hooksecurefunc("AuraButton_Update", function(buttonName, index, filter)
            if filter ~= "HELPFUL" or not IsEnabled() then
                return
            end
            local buff = _G[buttonName .. index]
            if buff and buff.mancerRaiseDup then
                buff:Hide()
            end
        end)
    end

    -- Replace (don't post-hook) so duplicates are marked before main-strip layout.
    if type(BuffFrame_UpdateAllBuffAnchors) == "function" and not Mod._wrapped then
        Mod._wrapped = true
        local orig = BuffFrame_UpdateAllBuffAnchors
        Mod._origLayout = orig
        BuffFrame_UpdateAllBuffAnchors = function()
            Mod:OnUpdateAllBuffAnchors(orig)
        end
    end
end
