-- Live minion sheet: stats (left) + 3D model (right).
-- Guardian minions (not pets): one slot per type, cycle with </> like a hunter pet screen.
Mancer.MinionSheetModule = {}
local MinionSheet = Mancer.MinionSheetModule

local FRAME_WIDTH = 560
-- Tall enough that Identity → Melee (Speed / Crit / Paper Auto) fits without scrolling.
local FRAME_HEIGHT = 580
local MODEL_WIDTH = 240
local REFRESH_INTERVAL = 5.0 -- live enough without spamming Unit*/nameplate scans
local WAIT_REFRESH_INTERVAL = 1.0 -- pick up nameplates quickly while waiting
-- Fixed model pose (no mousewheel). z is slight pull-back only at mount time.
local DEFAULT_MODEL_ZOOM = -1.6
local DISPLAY_CREATURE_ID = {
    ghoul = 50073, -- Raise Dead / PaperMath.GHOUL_TOOLTIP.summonCreatureId (GUID 0xF13000C399…)
    skeletal_archer = 50076, -- Animate: Skeletal Archer (GUID 0xF13000C39C…)
    tomb_king = 50320, -- Animate: Tomb King (GUID 0xF13000C490…)
    banshee = 500650, -- Raise: Banshee summon creature
}
local NAMEPLATE_HINT = "Friendly nameplates enabled while this sheet is open"
local WAIT_HINT = "Waiting a few seconds for the guardian scan"
-- Saved on open and restored on close so live stats work without manual Shift+V.
local NAMEPLATE_BOOST_CVARS = {
    "nameplateShowAll",
    "nameplateShowFriends",
    "nameplateShowFriendlyGuardians",
}
local NAMEPLATE_ENABLE_VALUES = {
    nameplateShowAll = "1",
    nameplateShowFriends = "1",
    nameplateShowFriendlyGuardians = "1",
}


local STAT_INDEX = {
    { key = "strength", label = "Strength", index = 1 },
    { key = "agility", label = "Agility", index = 2 },
    { key = "stamina", label = "Stamina", index = 3 },
    { key = "intellect", label = "Intellect", index = 4 },
    { key = "spirit", label = "Spirit", index = 5 },
}

local function GetUI()
    return Mancer.UI
end

local function GetAdvisor()
    return Mancer.NecromancerAdvisorModule
end

local function GetPaperMath()
    return Mancer.PaperMathModule
end

local function FormatDash(value, fmt)
    if value == nil then
        return "-"
    end
    if type(value) == "number" then
        if value ~= value then -- NaN
            return "-"
        end
        if fmt then
            return string.format(fmt, value)
        end
        if math.floor(value) == value then
            return string.format("%.0f", value)
        end
        return string.format("%.1f", value)
    end
    local text = tostring(value)
    if text == "" then
        return "-"
    end
    return text
end

local function SafeUnitStat(unit, index)
    if not unit or not UnitStat then
        return 0, 0, 0, 0
    end
    local a, b, c, d = UnitStat(unit, index)
    return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0, tonumber(d) or 0
end

local function PlayerGuardianTag()
    local playerName = UnitName and UnitName("player")
    if not playerName then
        return "Player's Guardian"
    end
    return playerName .. "'s Guardian"
end

local function InvalidateAdvisorScan()
    local Advisor = GetAdvisor()
    if not Advisor then
        return
    end
    Advisor.cachedScanUnits = nil
    Advisor.minionSnapshot = nil
    Advisor.nextGuardianSeed = 0
    if Advisor.SeedSummonsFromVisibleUnits then
        Advisor:SeedSummonsFromVisibleUnits(true)
    end
end

function MinionSheet:BoostNameplates()
    if self.nameplateCvarBackup or not SetCVar then
        return
    end
    local backup = {}
    for i = 1, #NAMEPLATE_BOOST_CVARS do
        local key = NAMEPLATE_BOOST_CVARS[i]
        if GetCVar then
            local ok, val = pcall(GetCVar, key)
            if ok and val ~= nil then
                backup[key] = val
                local enable = NAMEPLATE_ENABLE_VALUES[key]
                if enable then
                    pcall(SetCVar, key, enable)
                end
            end
        end
    end
    if next(backup) then
        self.nameplateCvarBackup = backup
        InvalidateAdvisorScan()
    end
end

function MinionSheet:RestoreNameplates()
    if not self.nameplateCvarBackup or not SetCVar then
        self.nameplateCvarBackup = nil
        return
    end
    for key, val in pairs(self.nameplateCvarBackup) do
        pcall(SetCVar, key, val)
    end
    self.nameplateCvarBackup = nil
    InvalidateAdvisorScan()
end

function MinionSheet:GetTypeRoster(force)
    local Advisor = GetAdvisor()
    if Advisor and Advisor.CollectActiveMinions then
        -- Always recount while the sheet is open so ×N tracks live nameplates.
        Advisor.minionSnapshot = nil
        Advisor.cachedAuraCounts = nil
        Advisor.cachedAuraUntil = 0
        Advisor:CollectActiveMinions(true)
    end
    if Advisor and Advisor.GetMinionTypeRoster then
        return Advisor:GetMinionTypeRoster()
    end
    return {}
end

local function GuidsMatchSafe(a, b)
    if not a or not b then
        return false
    end
    if a == b then
        return true
    end
    local Advisor = GetAdvisor()
    if Advisor and Advisor.GuidsMatch then
        return Advisor:GuidsMatch(a, b)
    end
    return tostring(a):lower() == tostring(b):lower()
end

-- Nameplate tokens often refresh UnitHealth after Bone Ward / temp HP before UnitHealthMax.
-- Prefer the highest Max seen for the same GUID; never show current > max.
local function ReadUnitHealth(unit)
    local health = tonumber(UnitHealth and UnitHealth(unit)) or 0
    local healthMax = tonumber(UnitHealthMax and UnitHealthMax(unit)) or 0
    local guid = UnitGUID and UnitGUID(unit)

    if guid and UnitHealthMax then
        local function consider(token)
            if not token or not UnitName or not UnitName(token) then
                return
            end
            if not GuidsMatchSafe(UnitGUID(token), guid) then
                return
            end
            local maxHp = tonumber(UnitHealthMax(token)) or 0
            if maxHp > healthMax then
                healthMax = maxHp
            end
            local cur = tonumber(UnitHealth and UnitHealth(token)) or 0
            if cur > health then
                health = cur
            end
        end

        for _, token in ipairs({ "target", "mouseover", "focus", "pet" }) do
            consider(token)
        end
        for i = 1, 40 do
            consider("nameplate" .. i)
        end
    end

    if healthMax < 1 and health > 0 then
        healthMax = health
    elseif health > healthMax then
        healthMax = health
    end

    return health, healthMax
end

function MinionSheet:ResolveTypeEntry(force)
    local roster = self:GetTypeRoster(force)
    if #roster == 0 then
        self.lockedMinionId = nil
        self.lockedIndex = nil
        self.lockedGuid = nil
        return nil
    end

    -- GetTypeRoster already recounted; refresh the locked row's live count from that roster.
    local Advisor = GetAdvisor()

    local function attachUnit(entry)
        if not entry then
            return entry
        end
        if entry.unit and UnitGUID and entry.guid and GuidsMatchSafe(UnitGUID(entry.unit), entry.guid) then
            return entry
        end
        if entry.guid and Advisor and Advisor.ResolveUnitTokenFromGuid then
            entry.unit = Advisor:ResolveUnitTokenFromGuid(entry.guid)
        end
        if not entry.unit and Advisor and Advisor.TryClassifyVisibleMinionUnit then
            for i = 1, 40 do
                local unit = "nameplate" .. i
                local id = Advisor:TryClassifyVisibleMinionUnit(unit)
                if id == entry.minionId and Advisor:IsOwnedByPlayer(unit) then
                    entry.unit = unit
                    entry.guid = UnitGUID and UnitGUID(unit) or entry.guid
                    entry.name = UnitName and UnitName(unit) or entry.name
                    break
                end
            end
        end
        if entry.unit and Advisor and Advisor.IsOwnedByPlayer and not Advisor:IsOwnedByPlayer(entry.unit) then
            entry.unit = nil
            entry.guid = nil
        end
        return entry
    end

    if self.lockedMinionId then
        for i, entry in ipairs(roster) do
            if entry.minionId == self.lockedMinionId then
                self.lockedIndex = i
                entry = attachUnit(entry)
                if entry.guid then
                    self.lockedGuid = entry.guid
                end
                return entry
            end
        end
        -- Locked type dismissed — fall through to whatever is still out.
        self.lockedMinionId = nil
        self.lockedIndex = nil
        self.lockedGuid = nil
    end

    local preferUnits = { "target", "mouseover", "focus", "pet" }
    for _, unit in ipairs(preferUnits) do
        local minionId
        if Advisor and Advisor.TryClassifyVisibleMinionUnit then
            minionId = Advisor:TryClassifyVisibleMinionUnit(unit)
        elseif Advisor and Advisor.ScanUnitToken then
            minionId = Advisor:ScanUnitToken(unit)
        end
        if minionId then
            for i, entry in ipairs(roster) do
                if entry.minionId == minionId then
                    self.lockedMinionId = minionId
                    self.lockedIndex = i
                    entry.unit = unit
                    entry.guid = UnitGUID and UnitGUID(unit)
                    entry.name = UnitName and UnitName(unit)
                    self.lockedGuid = entry.guid
                    return entry
                end
            end
        end
    end

    local idx = self.lockedIndex or 1
    if idx < 1 or idx > #roster then
        idx = 1
    end
    local entry = attachUnit(roster[idx])
    self.lockedIndex = idx
    self.lockedMinionId = entry.minionId
    self.lockedGuid = entry.guid
    return entry
end

function MinionSheet:CycleMinion(delta)
    local roster = self:GetTypeRoster(true)
    if #roster == 0 then
        self.lockedMinionId = nil
        self.lockedIndex = nil
        self.lockedGuid = nil
        self:Refresh(true)
        return
    end

    local idx = self.lockedIndex or 1
    if self.lockedMinionId then
        for i, entry in ipairs(roster) do
            if entry.minionId == self.lockedMinionId then
                idx = i
                break
            end
        end
    end

    idx = idx + (delta or 1)
    if idx < 1 then
        idx = #roster
    elseif idx > #roster then
        idx = 1
    end

    local entry = roster[idx]
    self.lockedIndex = idx
    self.lockedMinionId = entry.minionId
    self.lockedGuid = entry.guid
    self.modelGuid = nil
    self:Refresh(true)
end

function MinionSheet:CollectSheet(entry)
    if not entry then
        return nil
    end

    local unit = entry.unit
    local Advisor = GetAdvisor()
    if not unit and entry.guid and Advisor and Advisor.ResolveUnitTokenFromGuid then
        unit = Advisor:ResolveUnitTokenFromGuid(entry.guid)
        if unit then
            entry.unit = unit
        end
    end
    if not unit and Advisor and Advisor.TryClassifyVisibleMinionUnit then
        for i = 1, 40 do
            local token = "nameplate" .. i
            local id = Advisor:TryClassifyVisibleMinionUnit(token)
            if id == entry.minionId then
                unit = token
                entry.unit = token
                entry.guid = UnitGUID and UnitGUID(token) or entry.guid
                break
            end
        end
    end

    if not unit then
        return {
            unit = nil,
            minionId = entry.minionId,
            label = entry.label,
            name = entry.name or entry.label,
            count = entry.count,
            needsNameplates = true,
            guid = entry.guid,
        }
    end

    local PaperMath = GetPaperMath()
    local combat = PaperMath and PaperMath.GetUnitCombatSheet and PaperMath:GetUnitCombatSheet(unit) or nil
    local name = UnitName and UnitName(unit)
    if not name or name == "" then
        return {
            unit = nil,
            minionId = entry.minionId,
            label = entry.label,
            name = entry.name or entry.label,
            count = entry.count,
            needsNameplates = true,
            guid = entry.guid,
        }
    end
    if not combat then
        combat = { name = name, unit = unit }
    end

    local health, healthMax = ReadUnitHealth(unit)
    local power = UnitPower and UnitPower(unit) or 0
    local powerMax = UnitPowerMax and UnitPowerMax(unit) or 0
    if powerMax > 0 and power > powerMax then
        powerMax = power
    end

    local sheet = {
        unit = unit,
        minionId = entry.minionId,
        label = entry.label,
        name = combat.name or entry.name or entry.label,
        level = combat.level or (UnitLevel and UnitLevel(unit)) or 0,
        creatureType = UnitCreatureType and UnitCreatureType(unit) or "-",
        classification = UnitClassification and UnitClassification(unit) or "Guardian",
        guid = UnitGUID and UnitGUID(unit) or entry.guid,
        health = health,
        healthMax = healthMax,
        power = power,
        powerMax = powerMax,
        armor = UnitArmor and select(2, UnitArmor(unit)) or (UnitArmor and UnitArmor(unit)) or 0,
        count = entry.count,
        needsNameplates = false,
    }

    if UnitFactionGroup then
        sheet.faction = UnitFactionGroup(unit) or "-"
    else
        sheet.faction = "-"
    end

    for _, def in ipairs(STAT_INDEX) do
        sheet[def.key] = SafeUnitStat(unit, def.index)
    end

    if combat.stamina and combat.stamina > 0 then
        sheet.stamina = combat.stamina
    end

    if combat.attackPowerApiStub then
        sheet.attackPower = nil
        sheet.attackPowerStub = true
    else
        sheet.attackPower = combat.attackPower
        sheet.attackPowerStub = false
    end

    sheet.damageMin = combat.damageMin or 0
    sheet.damageMax = combat.damageMax or 0
    sheet.attackSpeed = combat.attackSpeed or 0

    if UnitDefense then
        local ok, base, mod = pcall(UnitDefense, unit)
        if ok then
            base = tonumber(base) or 0
            mod = tonumber(mod) or 0
            sheet.defense = base + mod
        end
    end

    local resists = {}
    if UnitResistance then
        for i = 2, 6 do
            local _, total = UnitResistance(unit, i)
            resists[i] = tonumber(total) or 0
        end
    end
    sheet.resists = resists

    if PaperMath and PaperMath.SEPULCHRAL_SPELL_FROM_STAM then
        sheet.sepulchral = (sheet.stamina or 0) * PaperMath.SEPULCHRAL_SPELL_FROM_STAM
    end

    return sheet
end

local function MakeLabel(parent, text, size)
    local fs = parent:CreateFontString(nil, "OVERLAY", size or "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    fs:SetText(text or "")
    return fs
end

local function MakeHeader(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    local ui = GetUI()
    if ui and ui.Colors and ui.Colors.accent then
        local c = ui.Colors.accent
        fs:SetTextColor(c[1], c[2], c[3], 1)
    else
        fs:SetTextColor(1, 0.82, 0, 1)
    end
    return fs
end

local function MakeRow(parent, label)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(14)
    row:SetWidth(250)
    local key = MakeLabel(row, label)
    key:SetPoint("LEFT", row, "LEFT", 0, 0)
    key:SetWidth(100)
    local ui = GetUI()
    if ui and ui.Colors and ui.Colors.muted then
        local c = ui.Colors.muted
        key:SetTextColor(c[1], c[2], c[3], 1)
    end
    local value = MakeLabel(row, "-")
    value:SetPoint("LEFT", key, "RIGHT", 4, 0)
    value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.key = key
    row.value = value
    return row
end

function MinionSheet:EnsureFrame()
    if self.frame then
        return self.frame
    end

    local ui = GetUI()
    local frame = CreateFrame("Frame", "MancerMinionSheetFrame", UIParent)
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    if ui and ui.SkinFrame then
        ui.SkinFrame(frame)
    end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -12)
    title:SetText("Minion Sheet")
    if ui and ui.StyleTitle then
        ui.StyleTitle(title)
    end
    frame.title = title

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    subtitle:SetText("Guardian minions · one slot per type")
    if ui and ui.StyleMuted then
        ui.StyleMuted(subtitle)
    end
    frame.subtitle = subtitle

    local close
    if ui and ui.CreateCloseButton then
        close = ui.CreateCloseButton(frame)
    else
        close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
        close:SetScript("OnClick", function()
            frame:Hide()
        end)
    end
    frame.close = close

    local statsPanel = CreateFrame("Frame", nil, frame)
    statsPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -48)
    statsPanel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 40)
    statsPanel:SetWidth(FRAME_WIDTH - MODEL_WIDTH - 40)
    if ui and ui.PaintPanel then
        ui.PaintPanel(statsPanel, ui.Colors and ui.Colors.bgInset)
    end
    frame.statsPanel = statsPanel

    local modelPanel = CreateFrame("Frame", nil, frame)
    modelPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -48)
    modelPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 40)
    modelPanel:SetWidth(MODEL_WIDTH)
    if ui and ui.PaintPanel then
        ui.PaintPanel(modelPanel, ui.Colors and ui.Colors.bgInset)
    end

    local model = CreateFrame("PlayerModel", nil, modelPanel)
    model:SetPoint("TOPLEFT", modelPanel, "TOPLEFT", 4, -8)
    model:SetPoint("BOTTOMRIGHT", modelPanel, "BOTTOMRIGHT", -4, 4)
    model:EnableMouse(true)
    model:EnableMouseWheel(false)
    model:SetScript("OnMouseUp", function()
        MinionSheet.modelGuid = nil
        MinionSheet.modelCreatureId = nil
        MinionSheet:Refresh(true)
    end)
    frame.model = model
    frame.modelPanel = modelPanel

    local modelHint = modelPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    modelHint:SetPoint("BOTTOM", modelPanel, "BOTTOM", 0, 8)
    modelHint:SetWidth(MODEL_WIDTH - 16)
    modelHint:SetJustifyH("CENTER")
    modelHint:SetText("No minion unit")
    frame.modelHint = modelHint

    local nameplateWarn = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameplateWarn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 38)
    nameplateWarn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 38)
    nameplateWarn:SetJustifyH("LEFT")
    nameplateWarn:SetTextColor(1, 0.82, 0.2, 1)
    nameplateWarn:SetText(NAMEPLATE_HINT)
    nameplateWarn:Hide()
    frame.nameplateWarn = nameplateWarn

    -- Blank waiting page (hides the empty stats skeleton until a live unit resolves).
    local waitingPanel = CreateFrame("Frame", nil, frame)
    waitingPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -48)
    waitingPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 40)
    if ui and ui.PaintPanel then
        ui.PaintPanel(waitingPanel, ui.Colors and ui.Colors.bgInset)
    end
    waitingPanel:Hide()
    frame.waitingPanel = waitingPanel

    -- Centered wait cluster: "Waiting…" + </> on one line, hints below.
    local waitCluster = CreateFrame("Frame", nil, waitingPanel)
    waitCluster:SetHeight(28)
    waitCluster:SetPoint("CENTER", waitingPanel, "CENTER", 0, 24)
    frame.waitCluster = waitCluster

    local waitTitle = waitCluster:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    waitTitle:SetPoint("LEFT", waitCluster, "LEFT", 0, 0)
    waitTitle:SetText("Waiting for a visible minion")
    if ui and ui.StyleTitle then
        ui.StyleTitle(waitTitle)
    end
    frame.waitTitle = waitTitle

    local waitLine1 = waitingPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    waitLine1:SetPoint("TOP", waitCluster, "BOTTOM", 0, -14)
    waitLine1:SetWidth(FRAME_WIDTH - 80)
    waitLine1:SetJustifyH("CENTER")
    waitLine1:SetText(NAMEPLATE_HINT)
    waitLine1:SetTextColor(1, 0.82, 0.2, 1)
    frame.waitLine1 = waitLine1

    local waitLine2 = waitingPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    waitLine2:SetPoint("TOP", waitLine1, "BOTTOM", 0, -10)
    waitLine2:SetWidth(FRAME_WIDTH - 80)
    waitLine2:SetJustifyH("CENTER")
    waitLine2:SetText(WAIT_HINT)
    frame.waitLine2 = waitLine2

    local scroll = CreateFrame("ScrollFrame", nil, statsPanel)
    scroll:SetPoint("TOPLEFT", statsPanel, "TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", statsPanel, "BOTTOMRIGHT", -8, 8)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(250)
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    frame.statsContent = content

    local y = 0
    local function place(widget)
        widget:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        widget:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        y = y - (widget:GetHeight() + 2)
    end

    frame.statRows = {}
    local function addHeader(text)
        local h = MakeHeader(content, text)
        h:SetHeight(16)
        place(h)
        y = y - 2
    end
    local function addRow(key, label)
        local row = MakeRow(content, label)
        place(row)
        frame.statRows[key] = row
    end

    addHeader("Identity")
    addRow("name", "Name")
    addRow("level", "Level")
    addRow("creatureType", "Creature Type")
    addRow("classification", "Classification")
    addRow("faction", "Faction")

    addHeader("Attributes")
    for _, def in ipairs(STAT_INDEX) do
        addRow(def.key, def.label)
    end

    addHeader("Vitals")
    addRow("health", "Health")
    addRow("power", "Power")
    addRow("armor", "Armor")
    addRow("defense", "Defense")

    addHeader("Melee")
    addRow("attackPower", "Attack Power")
    addRow("damage", "Damage")
    addRow("attackSpeed", "Speed")

    addHeader("Sepulchral")
    addRow("sepulchral", "Spell dmg from Stam")

    content:SetHeight(math.abs(y) + 8)

    local prevBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    prevBtn:SetSize(28, 22)
    prevBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 12)
    prevBtn:SetText("<")
    prevBtn:SetScript("OnClick", function()
        MinionSheet:CycleMinion(-1)
    end)

    local nextBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    nextBtn:SetSize(28, 22)
    nextBtn:SetPoint("LEFT", prevBtn, "RIGHT", 2, 0)
    nextBtn:SetText(">")
    nextBtn:SetScript("OnClick", function()
        MinionSheet:CycleMinion(1)
    end)
    frame.prevBtn = prevBtn
    frame.nextBtn = nextBtn

    local tip = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tip:SetPoint("LEFT", nextBtn, "RIGHT", 8, 0)
    tip:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
    tip:SetJustifyH("LEFT")
    tip:SetText("Tip: </> cycles types · auto-scan ~5s · nameplates restore on close.")
    frame.tip = tip

    self:BindFrameOnUpdate()

    frame:SetScript("OnShow", function()
        MinionSheet:BoostNameplates()
        MinionSheet.accum = 0
        MinionSheet:Refresh(true)
    end)
    frame:SetScript("OnHide", function()
        MinionSheet:RestoreNameplates()
    end)

    if UISpecialFrames then
        table.insert(UISpecialFrames, "MancerMinionSheetFrame")
    end

    self.frame = frame
    return frame
end

function MinionSheet:BindFrameOnUpdate()
    local frame = self.frame
    if not frame then
        return
    end
    frame:SetScript("OnUpdate", function(self, elapsed)
        -- One-shot hub layout after art size settles (must not wipe the refresh ticker).
        if MinionSheet._hubLayoutOnce then
            MinionSheet._hubLayoutOnce = nil
            local hub = Mancer.Hub and Mancer.Hub.frame
            local art = hub and hub.mancerArt
            local aw = (art and art.GetWidth and art:GetWidth()) or self:GetWidth() or 980
            local ah = (art and art.GetHeight and art:GetHeight()) or self:GetHeight() or 500
            if MinionSheet.ApplyHubEmbedStyle then
                MinionSheet:ApplyHubEmbedStyle(aw, ah)
            end
            if self.waitingPanel and self.waitingPanel:IsShown() then
                MinionSheet:LayoutWaitingNav()
            end
        end
        if not self:IsShown() then
            return
        end
        MinionSheet.accum = (MinionSheet.accum or 0) + (elapsed or 0)
        local waiting = self.waitingPanel and self.waitingPanel:IsShown()
        local interval = waiting and WAIT_REFRESH_INTERVAL or REFRESH_INTERVAL
        if MinionSheet.accum < interval then
            return
        end
        MinionSheet.accum = 0
        MinionSheet:Refresh(false)
    end)
end

function MinionSheet:LayoutWaitingNav()
    local frame = self.frame
    if not frame or not frame.waitCluster or not frame.prevBtn or not frame.nextBtn then
        return
    end

    local waiting = frame.waitingPanel
    if waiting then
        if frame._mancerHubEmbedded then
            -- Full sheet center (not just the left stats column).
            waiting:ClearAllPoints()
            waiting:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
            waiting:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
        end
        waiting:Show()
    end

    local title = frame.waitTitle
    local cluster = frame.waitCluster

    -- Title alone, centered; arrows stay at the bottom.
    title:ClearAllPoints()
    title:SetPoint("CENTER", cluster, "CENTER", 0, 0)
    local titleW = (title.GetStringWidth and title:GetStringWidth()) or 220
    cluster:SetWidth(math.max(titleW, 200))
    cluster:ClearAllPoints()
    cluster:SetPoint("CENTER", waiting or frame, "CENTER", 0, 24)

    if frame.waitLine1 then
        frame.waitLine1:ClearAllPoints()
        frame.waitLine1:SetPoint("TOP", cluster, "BOTTOM", 0, -14)
        frame.waitLine1:SetWidth(math.max(280, (waiting and waiting:GetWidth() or FRAME_WIDTH) - 80))
        frame.waitLine1:SetJustifyH("CENTER")
    end
    if frame.waitLine2 then
        frame.waitLine2:ClearAllPoints()
        frame.waitLine2:SetPoint("TOP", frame.waitLine1 or cluster, "BOTTOM", 0, -10)
        frame.waitLine2:SetWidth(math.max(280, (waiting and waiting:GetWidth() or FRAME_WIDTH) - 80))
        frame.waitLine2:SetJustifyH("CENTER")
    end

    self:LayoutLiveNav()
    -- While waiting in Hub, center </> at the bottom of the sheet.
    if frame._mancerHubEmbedded then
        frame.prevBtn:SetParent(frame)
        frame.nextBtn:SetParent(frame)
        frame.prevBtn:ClearAllPoints()
        frame.prevBtn:SetPoint("BOTTOM", frame, "BOTTOM", -16, 14)
        frame.nextBtn:ClearAllPoints()
        frame.nextBtn:SetPoint("LEFT", frame.prevBtn, "RIGHT", 4, 0)
        frame.prevBtn:SetFrameLevel((frame:GetFrameLevel() or 1) + 6)
        frame.nextBtn:SetFrameLevel((frame:GetFrameLevel() or 1) + 6)
        frame.prevBtn:EnableMouse(true)
        frame.nextBtn:EnableMouse(true)
        frame.prevBtn:Show()
        frame.nextBtn:Show()
        if frame.tip then
            frame.tip:Hide()
        end
    end
end

function MinionSheet:LayoutLiveNav()
    local frame = self.frame
    if not frame or not frame.prevBtn or not frame.nextBtn then
        return
    end

    local prevBtn = frame.prevBtn
    local nextBtn = frame.nextBtn
    prevBtn:SetParent(frame)
    nextBtn:SetParent(frame)

    if frame._mancerHubEmbedded and frame.modelPanel then
        prevBtn:ClearAllPoints()
        prevBtn:SetPoint("TOP", frame.modelPanel, "BOTTOM", -16, -4)
        nextBtn:ClearAllPoints()
        nextBtn:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
        prevBtn:SetFrameLevel((frame:GetFrameLevel() or 1) + 6)
        nextBtn:SetFrameLevel((frame:GetFrameLevel() or 1) + 6)
        if frame.tip then
            frame.tip:Hide()
        end
    else
        prevBtn:ClearAllPoints()
        prevBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 12)
        nextBtn:ClearAllPoints()
        nextBtn:SetPoint("LEFT", prevBtn, "RIGHT", 2, 0)
        if frame.tip then
            frame.tip:ClearAllPoints()
            frame.tip:SetPoint("LEFT", nextBtn, "RIGHT", 8, 0)
            frame.tip:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
            frame.tip:Show()
        end
    end
    prevBtn:EnableMouse(true)
    nextBtn:EnableMouse(true)
    prevBtn:Show()
    nextBtn:Show()
end

function MinionSheet:SetRow(key, value)
    local row = self.frame and self.frame.statRows and self.frame.statRows[key]
    if not row then
        return
    end
    row.value:SetText(FormatDash(value))
end

local function SetChromeVisible(frame, shown)
    local regions = {
        frame.mancerBg,
        frame.mancerArt,
        frame.mancerTitleBar,
        frame.mancerTitleAccent,
        frame.mancerEdgeT,
        frame.mancerEdgeB,
        frame.mancerEdgeL,
        frame.mancerEdgeR,
    }
    for _, region in ipairs(regions) do
        if region then
            if shown then
                if region.SetAlpha then
                    region:SetAlpha(1)
                end
                region:Show()
            else
                if region.SetAlpha then
                    region:SetAlpha(0)
                end
                region:Hide()
            end
        end
    end
    if frame.SetBackdrop then
        pcall(function()
            if shown then
                frame:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = false,
                    tileSize = 8,
                    edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 },
                })
                frame:SetBackdropColor(0.08, 0.09, 0.11, 0.96)
                frame:SetBackdropBorderColor(0.22, 0.28, 0.30, 1)
            else
                -- Fully strip backdrop so no border box remains in Hub embed.
                frame:SetBackdrop(nil)
            end
        end)
    end
end

local function ClearPanelBackground(panel)
    if not panel then
        return
    end
    if panel.mancerBg then
        panel.mancerBg:SetVertexColor(0, 0, 0, 0)
        panel.mancerBg:SetAlpha(0)
        panel.mancerBg:Hide()
    end
    if panel.mancerArt then
        panel.mancerArt:SetAlpha(0)
        panel.mancerArt:Hide()
    end
    local edges = {
        panel.mancerEdgeT,
        panel.mancerEdgeB,
        panel.mancerEdgeL,
        panel.mancerEdgeR,
    }
    for _, edge in ipairs(edges) do
        if edge then
            edge:SetAlpha(0)
            edge:Hide()
        end
    end
    if panel.SetBackdrop then
        pcall(function()
            panel:SetBackdrop(nil)
        end)
    end
end

local function SetSolidPanel(panel)
    if not panel or not panel.mancerBg then
        return
    end
    local ui = GetUI()
    local c = (ui and ui.Colors and ui.Colors.bgInset) or { 0.11, 0.12, 0.14, 0.95 }
    panel.mancerBg:SetAlpha(1)
    panel.mancerBg:SetVertexColor(c[1], c[2], c[3], c[4] or 0.95)
    panel.mancerBg:Show()
    local edges = {
        panel.mancerEdgeT,
        panel.mancerEdgeB,
        panel.mancerEdgeL,
        panel.mancerEdgeR,
    }
    for _, edge in ipairs(edges) do
        if edge then
            edge:SetAlpha(1)
            edge:Show()
        end
    end
end

function MinionSheet:ApplyModelFraming(model)
    -- Fixed framing only — no wheel zoom.
    -- Do not call SetCamera(0): that is the portrait/face cam and zooms into the head.
    if model.SetFacing then
        model:SetFacing(0.4)
    end
    if model.SetPosition then
        -- Pull back so limbs are not clipped by the PlayerModel rect.
        model:SetPosition(0, 0, DEFAULT_MODEL_ZOOM)
    end
end

-- Hub embed: sheet host matches Hub art; model coords are art-local.
function MinionSheet:ApplyHubEmbedStyle(availW, availH)
    local frame = self:EnsureFrame()
    SetChromeVisible(frame, false)
    ClearPanelBackground(frame)
    if frame.mancerTitleBar then
        frame.mancerTitleBar:ClearAllPoints()
        frame.mancerTitleBar:SetAlpha(0)
        frame.mancerTitleBar:Hide()
    end
    if frame.mancerTitleAccent then
        frame.mancerTitleAccent:ClearAllPoints()
        frame.mancerTitleAccent:SetAlpha(0)
        frame.mancerTitleAccent:Hide()
    end
    frame:EnableMouse(false)

    local hubMod = Mancer.Hub
    local hubFrame = hubMod and hubMod.frame
    local art = hubFrame and hubFrame.mancerArt
    local tabBar = hubMod and hubMod.tabBar

    -- Prefer live art size (sheet should already SetAllPoints art).
    local w = (frame:GetWidth() and frame:GetWidth() > 10 and frame:GetWidth())
        or (art and art:GetWidth())
        or availW
        or 980
    local h = (frame:GetHeight() and frame:GetHeight() > 10 and frame:GetHeight())
        or (art and art:GetHeight())
        or availH
        or 500
    w = math.max(400, w)
    h = math.max(280, h)
    -- Do not SetSize when pinned to art — anchors define size.
    self._hubEmbedW = w
    self._hubEmbedH = h

    -- Layout against the visible content strip (art left → SECTIONS rail), not full art
    -- width that extends under the rail.
    local usableW = w
    local usableRight = w - 8
    if art and art.GetLeft and tabBar and tabBar.GetLeft then
        local aL = art:GetLeft()
        local tL = tabBar:GetLeft()
        if aL and tL and tL > aL + 100 then
            usableRight = (tL - aL) - 12
            usableW = math.max(400, usableRight)
        end
    elseif hubMod and hubMod.CONTENT_WIDTH then
        usableW = math.min(w, hubMod.CONTENT_WIDTH)
        usableRight = usableW - 8
    end

    -- Hub TOPLEFT → art/sheet TOPLEFT conversion (shared by model + stats anchors).
    local function HubToArt(ox, oy)
        local ref = art or hubFrame
        if ref and hubFrame and ref.GetLeft and hubFrame.GetLeft then
            local hL, hT = hubFrame:GetLeft(), hubFrame:GetTop()
            local rL, rT = ref:GetLeft(), ref:GetTop()
            if hL and hT and rL and rT then
                return ox + (hL - rL), oy + (hT - rT)
            end
        end
        return ox - 2, oy + 24
    end

    -- Stats: LOCKED — TOPLEFT / height from Overwhelming Force + Tears of Lordaeron.
    local statsW = 260
    local topHX, topHY = 300, -140
    local botHX, botHY = 300, -500
    if hubMod and hubMod.GetStatsTextRect then
        topHX, topHY, botHX, botHY = hubMod:GetStatsTextRect()
    end
    local statsX, statsTopY = HubToArt(topHX, topHY)
    local _, statsBotY = HubToArt(botHX, botHY)
    -- Column left-aligned to the upper node center (slight left pad so labels clear the icon).
    statsX = statsX - 12
    local statsPointY = statsTopY
    local statsH = math.max(220, math.abs(statsTopY - statsBotY) + 24)
    if statsH > h - 48 then
        statsH = h - 48
    end
    if statsX < 8 then
        statsX = 8
    end
    if statsX + statsW > usableRight - 8 then
        statsX = math.max(8, usableRight - statsW - 8)
    end

    -- =====================================================================
    -- MODEL LOCKED (0.9.265): Plaguefather center + clamp/zoom — do not retune.
    -- =====================================================================
    local ox, oy = 920, -310
    if hubMod and hubMod.GetPlaguefatherOffset then
        ox, oy = hubMod:GetPlaguefatherOffset()
    end
    local localX, localY = HubToArt(ox, oy)

    local modelW = math.min(360, math.max(280, math.floor(usableW * 0.34)))
    local modelH = math.min(math.floor(h * 0.82), math.max(320, math.floor(h * 0.75)))
    local halfW = modelW / 2
    if localX + halfW > usableRight then
        localX = usableRight - halfW
    end
    if localX - halfW < 8 then
        localX = halfW + 8
    end
    local halfH = modelH / 2
    if localY - halfH < -(h - 36) then
        localY = -(h - 36) + halfH
    end

    local stats = frame.statsPanel
    local modelPanel = frame.modelPanel
    local waiting = frame.waitingPanel

    if stats then
        stats:ClearAllPoints()
        stats:SetPoint("TOPLEFT", frame, "TOPLEFT", statsX, statsPointY)
        stats:SetSize(statsW, statsH)
        ClearPanelBackground(stats)
        stats:EnableMouse(true)
    end
    if frame.statsContent then
        frame.statsContent:SetWidth(statsW - 16)
    end
    if waiting then
        waiting:ClearAllPoints()
        waiting:SetPoint("TOPLEFT", frame, "TOPLEFT", statsX, statsPointY)
        waiting:SetSize(statsW, statsH)
        ClearPanelBackground(waiting)
    end
    if modelPanel then
        modelPanel:SetParent(frame)
        modelPanel:ClearAllPoints()
        modelPanel:SetSize(modelW, modelH)
        modelPanel:SetPoint("CENTER", frame, "TOPLEFT", localX, localY)
        ClearPanelBackground(modelPanel)
        modelPanel:EnableMouse(true)
    end

    if frame.model and modelPanel then
        frame.model:SetParent(modelPanel)
        frame.model:ClearAllPoints()
        frame.model:SetPoint("TOPLEFT", modelPanel, "TOPLEFT", 0, 0)
        frame.model:SetPoint("BOTTOMRIGHT", modelPanel, "BOTTOMRIGHT", 0, 0)
    end
    if frame.modelHint and modelPanel then
        frame.modelHint:ClearAllPoints()
        frame.modelHint:SetPoint("BOTTOM", modelPanel, "BOTTOM", 0, 8)
        frame.modelHint:SetWidth(math.max(80, modelW - 16))
    end

    if frame.prevBtn then
        frame.prevBtn:ClearAllPoints()
        frame.prevBtn:SetPoint("TOP", modelPanel or frame, "BOTTOM", -16, -4)
        frame.prevBtn:SetFrameLevel((frame:GetFrameLevel() or 1) + 6)
        frame.prevBtn:EnableMouse(true)
        frame.prevBtn:Show()
    end
    if frame.nextBtn then
        frame.nextBtn:ClearAllPoints()
        frame.nextBtn:SetPoint("LEFT", frame.prevBtn, "RIGHT", 4, 0)
        frame.nextBtn:SetFrameLevel((frame:GetFrameLevel() or 1) + 6)
        frame.nextBtn:EnableMouse(true)
        frame.nextBtn:Show()
    end
    if frame.waitingPanel and frame.waitingPanel:IsShown() then
        self:LayoutWaitingNav()
    else
        self:LayoutLiveNav()
    end
    if frame.tip then
        frame.tip:Hide()
    end
    if frame.nameplateWarn then
        frame.nameplateWarn:ClearAllPoints()
        frame.nameplateWarn:SetPoint("TOPLEFT", stats or frame, "BOTTOMLEFT", 0, -4)
        frame.nameplateWarn:SetWidth(statsW or 200)
    end

    if frame.model then
        self:ApplyModelFraming(frame.model)
    end
end

function MinionSheet:RestoreStandaloneStyle()
    local frame = self.frame
    if not frame then
        return
    end
    SetChromeVisible(frame, true)
    frame:EnableMouse(true)
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)

    local stats = frame.statsPanel
    local model = frame.modelPanel
    local waiting = frame.waitingPanel
    if stats then
        stats:ClearAllPoints()
        stats:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -48)
        stats:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 40)
        stats:SetWidth(FRAME_WIDTH - MODEL_WIDTH - 40)
        SetSolidPanel(stats)
    end
    if model then
        model:ClearAllPoints()
        model:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -48)
        model:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 40)
        model:SetWidth(MODEL_WIDTH)
        SetSolidPanel(model)
    end
    if waiting then
        waiting:ClearAllPoints()
        waiting:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -48)
        waiting:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 40)
        SetSolidPanel(waiting)
    end

    if frame.mancerTitleBar then
        frame.mancerTitleBar:ClearAllPoints()
        frame.mancerTitleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        frame.mancerTitleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        frame.mancerTitleBar:SetHeight(28)
        frame.mancerTitleBar:SetAlpha(1)
        frame.mancerTitleBar:Show()
    end
    if frame.mancerTitleAccent then
        frame.mancerTitleAccent:ClearAllPoints()
        if frame.mancerTitleBar then
            frame.mancerTitleAccent:SetPoint("TOPLEFT", frame.mancerTitleBar, "BOTTOMLEFT", 0, 0)
            frame.mancerTitleAccent:SetPoint("TOPRIGHT", frame.mancerTitleBar, "BOTTOMRIGHT", 0, 0)
        end
        frame.mancerTitleAccent:SetHeight(2)
        frame.mancerTitleAccent:SetAlpha(1)
        frame.mancerTitleAccent:Show()
    end
    if frame.prevBtn then
        frame.prevBtn:ClearAllPoints()
        frame.prevBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 12)
    end
    if frame.nextBtn then
        frame.nextBtn:ClearAllPoints()
        frame.nextBtn:SetPoint("LEFT", frame.prevBtn, "RIGHT", 2, 0)
    end
    if frame.waitingPanel and frame.waitingPanel:IsShown() then
        self:LayoutWaitingNav()
    else
        self:LayoutLiveNav()
    end
    if frame.tip and not (frame.waitingPanel and frame.waitingPanel:IsShown()) then
        frame.tip:Show()
    end
    if frame.model then
        frame.model:ClearAllPoints()
        frame.model:SetPoint("TOPLEFT", frame.modelPanel, "TOPLEFT", 4, -8)
        frame.model:SetPoint("BOTTOMRIGHT", frame.modelPanel, "BOTTOMRIGHT", -4, 4)
    end
    if frame.modelHint and frame.modelPanel then
        frame.modelHint:ClearAllPoints()
        frame.modelHint:SetPoint("BOTTOM", frame.modelPanel, "BOTTOM", 0, 8)
        frame.modelHint:SetWidth(MODEL_WIDTH - 16)
    end
    if frame.nameplateWarn then
        frame.nameplateWarn:ClearAllPoints()
        frame.nameplateWarn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 38)
        frame.nameplateWarn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 38)
    end
    if frame.model then
        self:ApplyModelFraming(frame.model)
    end
end

function MinionSheet:UpdateModel(unit, minionId, forceRemount)
    local frame = self.frame
    if not frame or not frame.model then
        return
    end
    local model = frame.model
    local creatureId = minionId and DISPLAY_CREATURE_ID[minionId]
    local mountKey = (creatureId and ("creature:" .. creatureId))
        or (unit and UnitGUID and UnitGUID(unit))
        or nil

    if not creatureId and not unit then
        model:SetScript("OnUpdate", nil)
        model:ClearModel()
        self.modelGuid = nil
        self.modelCreatureId = nil
        frame.modelHint:Show()
        frame.modelHint:SetText(NAMEPLATE_HINT)
        return
    end

    if not forceRemount and mountKey and self.modelGuid == mountKey then
        frame.modelHint:Hide()
        return
    end

    local ok = pcall(function()
        model:SetScript("OnUpdate", nil)
        model:ClearModel()
        if creatureId and model.SetCreature then
            model:SetCreature(creatureId)
        elseif unit then
            model:SetUnit(unit)
        else
            error("no model source")
        end
        -- Frame after the mesh finishes loading (immediate SetPosition often lands in the face).
        local delay = 0
        model:SetScript("OnUpdate", function(self, elapsed)
            delay = delay + (elapsed or 0)
            if delay < 0.05 then
                return
            end
            self:SetScript("OnUpdate", nil)
            MinionSheet:ApplyModelFraming(self)
        end)
        MinionSheet:ApplyModelFraming(model)
    end)

    if ok then
        self.modelGuid = mountKey
        self.modelCreatureId = creatureId
        frame.modelHint:Hide()
    else
        self.modelGuid = nil
        self.modelCreatureId = nil
        frame.modelHint:Show()
        frame.modelHint:SetText("Model unavailable")
    end
end

function MinionSheet:ClearStatRows()
    for key in pairs(self.frame.statRows) do
        self:SetRow(key, "-")
    end
end

function MinionSheet:ShowWaitingPage(titleText, subtitleText)
    local frame = self.frame
    if not frame then
        return
    end
    frame.title:SetText(titleText or "Minion Sheet")
    frame.subtitle:SetText(subtitleText or "Scanning guardians for live stats")
    if frame.statsPanel then
        frame.statsPanel:Hide()
    end
    if frame.modelPanel then
        frame.modelPanel:Hide()
    end
    if frame.nameplateWarn then
        frame.nameplateWarn:Hide()
    end
    if frame.waitingPanel then
        frame.waitingPanel:Show()
    end
    if frame.waitLine1 then
        frame.waitLine1:SetText(NAMEPLATE_HINT)
    end
    if frame.waitLine2 then
        frame.waitLine2:SetText(WAIT_HINT)
    end
    self:LayoutWaitingNav()
    self:UpdateModel(nil, nil, true)
end

function MinionSheet:ShowLivePage()
    local frame = self.frame
    if not frame then
        return
    end
    local wasWaiting = frame.waitingPanel and frame.waitingPanel:IsShown()
    if frame.waitingPanel then
        frame.waitingPanel:Hide()
    end
    if frame.nameplateWarn then
        frame.nameplateWarn:Hide()
    end
    if frame.statsPanel then
        frame.statsPanel:Show()
    end
    if frame.modelPanel then
        frame.modelPanel:Show()
    end
    -- Restore hub stats/model layout after full-bleed waiting panel.
    if wasWaiting and frame._mancerHubEmbedded and self._hubEmbedW and self._hubEmbedH then
        self:ApplyHubEmbedStyle(self._hubEmbedW, self._hubEmbedH)
    end
    self:LayoutLiveNav()
end

function MinionSheet:Refresh(forceModel)
    local frame = self:EnsureFrame()
    local entry = self:ResolveTypeEntry(forceModel == true)
    local sheet = entry and self:CollectSheet(entry) or nil

    if not sheet then
        self:ShowWaitingPage("Minion Sheet", "No raised minions detected")
        self.lastUnit = nil
        self.lastGuid = nil
        return
    end

    local roster = self:GetTypeRoster(false)
    local cycleText = ""
    if #roster > 1 and self.lockedIndex then
        cycleText = string.format(" · type %d/%d", self.lockedIndex, #roster)
    end

    local countText = ""
    if sheet.count and sheet.count >= 1 then
        countText = string.format(" ×%d active", sheet.count)
    end

    local displayLabel = sheet.label or sheet.name

    if sheet.needsNameplates then
        self:ShowWaitingPage(
            displayLabel,
            string.format("<%s>%s%s · waiting for unit", PlayerGuardianTag(), countText, cycleText)
        )
        self.lastUnit = nil
        self.lastGuid = nil
        return
    end

    self:ShowLivePage()
    frame.title:SetText(displayLabel)
    frame.subtitle:SetText(string.format("<%s>%s%s · live (~5s)",
        PlayerGuardianTag(), countText, cycleText))

    self:SetRow("name", sheet.name)
    self:SetRow("level", sheet.level)
    self:SetRow("creatureType", sheet.creatureType)
    self:SetRow("classification", sheet.classification)
    self:SetRow("faction", sheet.faction)
    self:SetRow("strength", sheet.strength)
    self:SetRow("agility", sheet.agility)
    self:SetRow("stamina", sheet.stamina)
    self:SetRow("intellect", sheet.intellect)
    self:SetRow("spirit", sheet.spirit)
    self:SetRow("health", string.format("%d / %d", sheet.health or 0, sheet.healthMax or 0))
    self:SetRow("power", string.format("%d / %d", sheet.power or 0, sheet.powerMax or 0))
    self:SetRow("armor", sheet.armor)
    self:SetRow("defense", sheet.defense)
    if sheet.attackPowerStub then
        self:SetRow("attackPower", "API stub")
    else
        self:SetRow("attackPower", sheet.attackPower)
    end
    if (sheet.damageMin or 0) > 0 or (sheet.damageMax or 0) > 0 then
        self:SetRow("damage", string.format("%.0f – %.0f", sheet.damageMin, sheet.damageMax))
    else
        self:SetRow("damage", "-")
    end
    self:SetRow("attackSpeed", sheet.attackSpeed and sheet.attackSpeed > 0 and string.format("%.2f", sheet.attackSpeed) or "-")
    self:SetRow("sepulchral", sheet.sepulchral and string.format("+%.1f", sheet.sepulchral) or "-")

    local unit = sheet.unit
    local creatureId = sheet.minionId and DISPLAY_CREATURE_ID[sheet.minionId]
    local mountKey = (creatureId and ("creature:" .. creatureId))
        or sheet.guid
        or (unit and UnitGUID and UnitGUID(unit))
    -- Timed polls must NOT remount (avoids model flicker).
    local remount = forceModel == true or self.modelGuid ~= mountKey
    self:UpdateModel(unit, sheet.minionId, remount)
    self.lastUnit = unit
    self.lastGuid = mountKey
end

function MinionSheet:Show()
    local frame = self:EnsureFrame()
    frame:Show()
    self:Refresh(true)
end

function MinionSheet:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function MinionSheet:Toggle()
    local frame = self:EnsureFrame()
    if frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end
