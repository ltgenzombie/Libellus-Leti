-- MinionHpHud.lua
-- Movable text list of permanent guardian Current/Max HP near the player HUD.
-- Ascension: friendly nameplates are the master switch for pet plates to appear.
-- While HP list / Minion Sheet needs tokens, turn Friends + Pets (+ Guardians) ON,
-- then optionally SetAlpha(0) on *all* friendly plates so the world stays clean.

local MinionHpHud = {}
Mancer.MinionHpHudModule = MinionHpHud

local REFRESH_INTERVAL = 0.5
local MAX_ROWS = 12
local BAR_WIDTH = 152
local BAR_HEIGHT = 20
local ROW_GAP = 3
local ROW_HEIGHT = BAR_HEIGHT + ROW_GAP
local HANDLE_SIZE = 18
local LABEL_WIDTH = 52
-- HP color: full = green, at/below 30% = red, smooth lerp between.
local HP_RED_PCT = 0.30
-- Keep a row briefly if its unit token blips (nameplate recycle).
local STALE_ROW_SEC = 2.5
-- Don't thrash SetAlpha / CVar checks every HP tick.
local NAMEPLATE_SYNC_INTERVAL = 1.25
-- Camera/move resets plate alpha; rescan owned units often while pin runs every frame.
local CLOAK_SCAN_INTERVAL = 0.12

local PERMANENT_ORDER = {
    "skeletal_warrior_lesser",
    "skeletal_warrior_greater",
    "skeletal_rogue",
    "ghoul",
    "crypt_fiend",
    "abomination",
}

local PERMANENT_SET = {}
for i, id in ipairs(PERMANENT_ORDER) do
    PERMANENT_SET[id] = i
end

-- Ascension: Friends is the master switch for pet plates. Enable Friends + Pets
-- (+ Guardians). Never force nameplateShowAll off — that kills Ascension plates.
local NAMEPLATE_CVARS = {
    "nameplateShowFriends",
    "nameplateShowFriendlyGuardians",
    "nameplateShowFriendlyPets",
}

local NAMEPLATE_ENABLE = {
    nameplateShowFriends = "1",
    nameplateShowFriendlyGuardians = "1",
    nameplateShowFriendlyPets = "1",
}

local SHORT_LABEL = {
    skeletal_warrior_lesser = "L. Skel",
    skeletal_warrior_greater = "G. Skel",
    skeletal_rogue = "Rogue",
    ghoul = "Ghoul",
    crypt_fiend = "Fiend",
    abomination = "Abom",
}

local function GuidsMatch(a, b)
    if not a or not b then
        return false
    end
    if a == b then
        return true
    end
    local Advisor = Mancer.NecromancerAdvisor or Mancer.NecromancerAdvisorModule
    if Advisor and Advisor.GuidsMatch then
        return Advisor:GuidsMatch(a, b)
    end
    return tostring(a):lower() == tostring(b):lower()
end

-- Shared with Minion Sheet (Bone Ward / temp HP max staleness).
function Mancer.Util.ReadUnitHealth(unit)
    local health = tonumber(UnitHealth and UnitHealth(unit)) or 0
    local healthMax = tonumber(UnitHealthMax and UnitHealthMax(unit)) or 0
    local guid = UnitGUID and UnitGUID(unit)

    if guid and UnitHealthMax then
        local function consider(token)
            if not token or not UnitName or not UnitName(token) then
                return
            end
            if not GuidsMatch(UnitGUID(token), guid) then
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

local function FeatureEnabled()
    return MancerDB and MancerDB.showMinionHpList == true
end

local function HideVisualsEnabled()
    return MancerDB and MancerDB.hideMinionHpNameplateVisuals ~= false
end

local function GetAdvisor()
    return Mancer.NecromancerAdvisor or Mancer.NecromancerAdvisorModule
end

local function SheetHasNameplateBoost()
    local sheet = Mancer.MinionSheetModule
    return sheet and sheet.nameplateCvarBackup ~= nil
end

--- Cloak only while "Hide friendly plates" is checked AND (HP bars or Minion Sheet need tokens).
local function ShouldCloakFriendlyPlates()
    if not HideVisualsEnabled() then
        return false
    end
    return FeatureEnabled() or SheetHasNameplateBoost()
end

local function FormatHp(n)
    n = math.floor(tonumber(n) or 0)
    if n >= 1000000 then
        return string.format("%.1fm", n / 1000000)
    end
    if n >= 10000 then
        return string.format("%.1fk", n / 1000)
    end
    return tostring(n)
end

-- pct 1.0 → green; pct ≤ 0.30 → red; smooth fade between.
local function HpBarColor(pct)
    pct = tonumber(pct) or 0
    if pct < 0 then
        pct = 0
    elseif pct > 1 then
        pct = 1
    end
    if pct <= HP_RED_PCT then
        return 0.95, 0.18, 0.12
    end
    local t = (pct - HP_RED_PCT) / (1 - HP_RED_PCT)
    -- lerp red → green
    local r = 0.95 + (0.28 - 0.95) * t
    local g = 0.18 + (0.88 - 0.18) * t
    local b = 0.12 + (0.28 - 0.12) * t
    return r, g, b
end

-- Minion HP bar skins in LibellusLeti/MinionBarTextures (no .blp suffix for SetTexture).
local ADDON_FOLDER = (Mancer and Mancer.ADDON_FOLDER) or "LibellusLeti"
local MINION_BAR_DIR = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\MinionBarTextures\\"
local MINION_BAR_TEXTURES = {
    MINION_BAR_DIR .. "abstract",
    MINION_BAR_DIR .. "Leaves",
    MINION_BAR_DIR .. "Runes",
    MINION_BAR_DIR .. "static",
}
local MINION_BAR_NAMES = {
    "Abstract",
    "Leaves",
    "Runes",
    "Static",
}
local HP_BAR_FILL_FALLBACK = "Interface\\Buttons\\WHITE8X8"

local function NormalizeMinionHpBarIndex(idx)
    idx = tonumber(idx) or 1
    if idx < 1 then
        idx = 1
    elseif idx > #MINION_BAR_TEXTURES then
        idx = #MINION_BAR_TEXTURES
    end
    return idx
end

local function GetMinionHpBarTexture()
    local idx = NormalizeMinionHpBarIndex(MancerDB and MancerDB.minionHpBarTextureIndex)
    return MINION_BAR_TEXTURES[idx] or MINION_BAR_TEXTURES[1]
end

function MinionHpHud:GetBarTextureName()
    local idx = NormalizeMinionHpBarIndex(MancerDB and MancerDB.minionHpBarTextureIndex)
    return MINION_BAR_NAMES[idx] or MINION_BAR_NAMES[1]
end

function MinionHpHud:CycleBarTexture(delta)
    MancerDB = MancerDB or {}
    local idx = NormalizeMinionHpBarIndex(MancerDB.minionHpBarTextureIndex)
    idx = idx + (tonumber(delta) or 1)
    if idx > #MINION_BAR_TEXTURES then
        idx = 1
    elseif idx < 1 then
        idx = #MINION_BAR_TEXTURES
    end
    MancerDB.minionHpBarTextureIndex = idx
    self:ApplyBarTextures()
    self:Refresh(true)
    return self:GetBarTextureName()
end

function MinionHpHud:IsPermanentMinionId(minionId)
    return PERMANENT_SET[minionId] ~= nil
end

function MinionHpHud:BoostNameplates()
    if not SetCVar then
        return
    end
    -- Already boosted — only touch CVars that drifted (Sheet restore can leave friends on).
    if self.nameplateCvarBackup then
        for key, enable in pairs(NAMEPLATE_ENABLE) do
            local ok, cur = pcall(GetCVar, key)
            if ok and cur ~= nil and tostring(cur) ~= tostring(enable) then
                pcall(SetCVar, key, enable)
            end
        end
        return
    end
    local backup = {}
    for i = 1, #NAMEPLATE_CVARS do
        local key = NAMEPLATE_CVARS[i]
        local ok, val = pcall(GetCVar, key)
        if ok and val ~= nil then
            backup[key] = val
            local enable = NAMEPLATE_ENABLE[key]
            if enable ~= nil and tostring(val) ~= tostring(enable) then
                pcall(SetCVar, key, enable)
            end
        end
    end
    if next(backup) then
        self.nameplateCvarBackup = backup
    end
end

function MinionHpHud:RestoreNameplates()
    if not self.nameplateCvarBackup or not SetCVar then
        self.nameplateCvarBackup = nil
        return
    end
    for key, val in pairs(self.nameplateCvarBackup) do
        pcall(SetCVar, key, val)
    end
    self.nameplateCvarBackup = nil
end

function MinionHpHud:CollectNamePlateFrames()
    local frames = {}
    local seen = {}

    local function add(frame)
        if frame and not seen[frame] then
            seen[frame] = true
            frames[#frames + 1] = frame
        end
    end

    for i = 1, 40 do
        add(_G["NamePlate" .. i])
        add(_G["NamePlate" .. i .. "UnitFrame"])
    end

    if C_NamePlate and C_NamePlate.GetNamePlates then
        local ok, plates = pcall(C_NamePlate.GetNamePlates)
        if ok and type(plates) == "table" then
            for _, plate in ipairs(plates) do
                add(plate)
                if plate.UnitFrame then
                    add(plate.UnitFrame)
                end
            end
        end
    end

    if WorldFrame and WorldFrame.GetChildren then
        local children = { WorldFrame:GetChildren() }
        for i = 1, #children do
            local f = children[i]
            if f and f.GetName then
                local name = f:GetName()
                if name and tostring(name):find("NamePlate", 1, true) then
                    add(f)
                end
            end
        end
    end

    return frames
end

function MinionHpHud:IsOwnedGuardianUnit(unit)
    if not unit then
        return false
    end
    if UnitCanAttack and UnitCanAttack("player", unit) then
        return false
    end
    -- Need a readable plate (Ascension: UnitName often works while UnitExists is false).
    if not ((UnitName and UnitName(unit)) or (UnitExists and UnitExists(unit))) then
        return false
    end
    local Advisor = GetAdvisor()
    if Advisor and Advisor.IsOwnedByPlayer then
        return Advisor:IsOwnedByPlayer(unit) and true or false
    end
    return false
end

-- Any friendly plate (players, pets, NPCs) — used for visual hide while Friends are on.
function MinionHpHud:IsFriendlyPlateUnit(unit)
    if not unit then
        return false
    end
    if UnitIsUnit and UnitIsUnit(unit, "player") then
        return false
    end
    if not ((UnitName and UnitName(unit)) or (UnitExists and UnitExists(unit))) then
        return false
    end
    if UnitCanAttack and UnitCanAttack("player", unit) then
        return false
    end
    if UnitIsEnemy and UnitIsEnemy("player", unit) then
        return false
    end
    if UnitIsFriend then
        return UnitIsFriend("player", unit) and true or false
    end
    return true
end

function MinionHpHud:CloakPlateFrame(frame)
    if not frame or not frame.SetAlpha then
        return
    end
    self.hiddenPlateFrames = self.hiddenPlateFrames or {}
    if self.hiddenPlateFrames[frame] == nil then
        local ok, alpha = pcall(frame.GetAlpha, frame)
        self.hiddenPlateFrames[frame] = (ok and alpha) or 1
    end
    pcall(frame.SetAlpha, frame, 0)
end

function MinionHpHud:CloakUnitPlate(unit)
    if not unit then
        return
    end
    local Advisor = GetAdvisor()
    local frame = Advisor and Advisor.GetNamePlateFrameForUnit and Advisor:GetNamePlateFrameForUnit(unit)
    if not frame then
        local idx = tostring(unit):match("^nameplate(%d+)$")
        if idx then
            frame = _G["NamePlate" .. idx]
        end
    end
    if not frame then
        return
    end
    self:CloakPlateFrame(frame)
    if frame.UnitFrame then
        self:CloakPlateFrame(frame.UnitFrame)
    end
    local name = frame.GetName and frame:GetName()
    if name then
        self:CloakPlateFrame(_G[name .. "UnitFrame"])
        self:CloakPlateFrame(_G[name .. "HealthBar"])
        self:CloakPlateFrame(_G[name .. "CastBar"])
    end
    -- Ascension / custom plate children often get their own alpha reset on camera move.
    if frame.GetChildren then
        local kids = { frame:GetChildren() }
        for i = 1, #kids do
            self:CloakPlateFrame(kids[i])
        end
    end
    if frame.GetRegions then
        local regions = { frame:GetRegions() }
        for i = 1, #regions do
            local r = regions[i]
            if r and r.SetAlpha then
                self:CloakPlateFrame(r)
            end
        end
    end
end

--- Pin already-cloaked frames to 0 (nameplate driver restores alpha on move/camera).
function MinionHpHud:ReassertCloakedAlphas()
    local frames = self.hiddenPlateFrames
    if not frames then
        return
    end
    for frame in pairs(frames) do
        if not frame or not frame.SetAlpha then
            frames[frame] = nil
        else
            local ok, alpha = pcall(frame.GetAlpha, frame)
            if not ok or not alpha or alpha > 0.01 then
                pcall(frame.SetAlpha, frame, 0)
            end
        end
    end
end

function MinionHpHud:ScanAndCloakFriendlyPlates()
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if self:IsFriendlyPlateUnit(unit) then
            self:CloakUnitPlate(unit)
        end
    end
end

--- Keep CVars on (tokens live) but SetAlpha(0) on all friendly plates.
function MinionHpHud:ApplyNameplateVisualHide()
    if not ShouldCloakFriendlyPlates() then
        self:ClearNameplateVisualHide()
        return
    end

    self.hiddenPlateFrames = self.hiddenPlateFrames or {}
    self:ScanAndCloakFriendlyPlates()
    self:ReassertCloakedAlphas()
    self:UpdateCloakDriver()
end

function MinionHpHud:ClearNameplateVisualHide()
    if self.cloakDriver then
        self.cloakDriver:Hide()
    end
    if not self.hiddenPlateFrames then
        return
    end
    for frame, alpha in pairs(self.hiddenPlateFrames) do
        if frame and frame.SetAlpha then
            pcall(frame.SetAlpha, frame, alpha or 1)
        end
    end
    self.hiddenPlateFrames = nil
end

-- Always-on while cloaking (even if HP list frame is hidden / Minion Sheet only).
function MinionHpHud:EnsureCloakDriver()
    if self.cloakDriver then
        return
    end
    local driver = CreateFrame("Frame", "MancerMinionPlateCloakDriver")
    driver:Hide()
    driver.scanElapsed = 0
    driver:SetScript("OnUpdate", function(f, elapsed)
        if not ShouldCloakFriendlyPlates() then
            f:Hide()
            return
        end
        -- Every frame: fight Ascension nameplate alpha resets on move/camera.
        self:ReassertCloakedAlphas()
        f.scanElapsed = (f.scanElapsed or 0) + (elapsed or 0)
        if f.scanElapsed >= CLOAK_SCAN_INTERVAL then
            f.scanElapsed = 0
            self:ScanAndCloakFriendlyPlates()
        end
    end)
    self.cloakDriver = driver
end

function MinionHpHud:UpdateCloakDriver()
    self:EnsureCloakDriver()
    if ShouldCloakFriendlyPlates() then
        if not self.cloakDriver:IsShown() then
            self.cloakDriver:Show()
        end
    else
        self.cloakDriver:Hide()
    end
end

function MinionHpHud:SyncNameplateSupport(force)
    local now = GetTime and GetTime() or 0
    if not force and self._nextNameplateSync and now < self._nextNameplateSync then
        if ShouldCloakFriendlyPlates() then
            self:UpdateCloakDriver()
        end
        return
    end
    self._nextNameplateSync = now + NAMEPLATE_SYNC_INTERVAL

    -- Hide ON  → force Friends/Pets on for tokens + alpha 0.
    -- Hide OFF → restore user's CVars and stop re-asserting (so V-key / options stay off).
    if HideVisualsEnabled() and (FeatureEnabled() or SheetHasNameplateBoost()) then
        if FeatureEnabled() then
            self:BoostNameplates()
        end
        self:ApplyNameplateVisualHide()
        return
    end

    self:ClearNameplateVisualHide()
    -- Don't restore over Minion Sheet's temporary boost while the sheet is open.
    if FeatureEnabled() and not SheetHasNameplateBoost() then
        self:RestoreNameplates()
    elseif not FeatureEnabled() and not SheetHasNameplateBoost() then
        self:RestoreNameplates()
    end
end

function MinionHpHud:OnNamePlateUnitAdded(unit)
    if not unit or not ShouldCloakFriendlyPlates() then
        return
    end
    if self:IsFriendlyPlateUnit(unit) then
        self:CloakUnitPlate(unit)
        self:UpdateCloakDriver()
    end
end

function MinionHpHud:CollectHpRows()
    local rows = {}
    local Advisor = GetAdvisor()
    if not Advisor then
        return rows
    end

    -- Seeding every tick reshuffles tokens; throttle it with nameplate sync.
    local now = GetTime and GetTime() or 0
    if not self._nextSeed or now >= self._nextSeed then
        self._nextSeed = now + NAMEPLATE_SYNC_INTERVAL
        if Advisor.SeedSummonsFromVisibleUnits then
            Advisor:SeedSummonsFromVisibleUnits(false)
        end
    end

    local seenGuid = {}
    local liveByGuid = {}

    local function addRow(minionId, guid, unit, name)
        if not minionId or not PERMANENT_SET[minionId] then
            return
        end
        if not unit then
            return
        end
        local health, healthMax = Mancer.Util.ReadUnitHealth(unit)
        if not healthMax or healthMax < 1 then
            return
        end
        guid = guid or (UnitGUID and UnitGUID(unit))
        local key = guid and tostring(guid):lower() or nil
        if key then
            if seenGuid[key] then
                return
            end
            seenGuid[key] = true
        end
        local def = Advisor.MINION_TYPES and Advisor.MINION_TYPES[minionId]
        local row = {
            minionId = minionId,
            label = SHORT_LABEL[minionId] or (def and def.label) or minionId,
            guid = guid,
            unit = unit,
            name = name,
            health = health,
            healthMax = healthMax,
            order = PERMANENT_SET[minionId] or 99,
            seenAt = now,
        }
        if key then
            liveByGuid[key] = row
        else
            rows[#rows + 1] = row
        end
    end

    if Advisor.activeSummons then
        for guid, info in pairs(Advisor.activeSummons) do
            if info and PERMANENT_SET[info.minionId] then
                if not (info.expiresAt and info.expiresAt <= now) then
                    local unit = info.unit
                    if not (unit and UnitGUID and GuidsMatch(UnitGUID(unit), guid)) then
                        unit = Advisor.ResolveUnitTokenFromGuid and Advisor:ResolveUnitTokenFromGuid(guid)
                    end
                    if unit and Advisor.IsOwnedByPlayer and Advisor:IsOwnedByPlayer(unit) then
                        info.unit = unit
                        addRow(info.minionId, guid, unit, info.name)
                    end
                end
            end
        end
    end

    -- Visible owned plates not yet in activeSummons.
    local function considerUnit(unit)
        if not unit then
            return
        end
        local minionId, name = Advisor:TryClassifyVisibleMinionUnit(unit)
        if not PERMANENT_SET[minionId] then
            return
        end
        if Advisor.IsOwnedByPlayer and not Advisor:IsOwnedByPlayer(unit, name) then
            return
        end
        local guid = UnitGUID and UnitGUID(unit)
        addRow(minionId, guid, unit, name)
    end

    for _, unit in ipairs({ "target", "mouseover", "focus", "pet" }) do
        considerUnit(unit)
    end
    for i = 1, 40 do
        considerUnit("nameplate" .. i)
    end

    -- Sticky cache: keep last HP for a short grace so plate recycle doesn't pop rows.
    self._stickyRows = self._stickyRows or {}
    for key, row in pairs(liveByGuid) do
        self._stickyRows[key] = row
        rows[#rows + 1] = row
    end
    for key, prev in pairs(self._stickyRows) do
        if not liveByGuid[key] then
            local age = now - (prev.seenAt or 0)
            if age <= STALE_ROW_SEC and PERMANENT_SET[prev.minionId] then
                rows[#rows + 1] = prev
            else
                self._stickyRows[key] = nil
            end
        end
    end

    table.sort(rows, function(a, b)
        if a.order ~= b.order then
            return a.order < b.order
        end
        local ga = tostring(a.guid or "")
        local gb = tostring(b.guid or "")
        return ga < gb
    end)

    return rows
end

function MinionHpHud:EnsureFrames()
    local needBars = not (self.rows and self.rows[1] and self.rows[1].bar)
    if self.frame and not needBars then
        return
    end

    local parent = (Mancer.FloatingText and Mancer.FloatingText.anchor) or UIParent
    if not self.frame then
        self.frame = CreateFrame("Frame", "MancerMinionHpHud", parent)
        self.frame:SetSize(HANDLE_SIZE + 4 + LABEL_WIDTH + BAR_WIDTH, ROW_HEIGHT * MAX_ROWS + 4)
        self.frame:SetFrameStrata("MEDIUM")
        self.frame:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 1) + 30)
        -- Default anchor so the list is never "unpointed" if ApplyLayout is deferred.
        self.frame:SetPoint("TOPLEFT", parent, "CENTER", 90, 20)
        self.frame:Hide()

        -- H handle on the HUD anchor (like A/Z/T), not on the list frame — so it stays
        -- visible in move mode even before rows resolve.
        local handleParent = (Mancer.FloatingText and Mancer.FloatingText.anchor) or self.frame
        self.handle = CreateFrame("Button", nil, handleParent)
        self.handle:SetSize(HANDLE_SIZE, HANDLE_SIZE)
        self.handle:SetFrameLevel((handleParent.GetFrameLevel and handleParent:GetFrameLevel() or 1) + 45)
        self.handle:Hide()
        self.handle:EnableMouse(false)
        self.handle:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
        self.handle:SetScript("OnMouseDown", function()
            if self.moveMode then
                self.moving = true
                self._dragX, self._dragY = nil, nil
                local uiScale = UIParent:GetEffectiveScale()
                local cx, cy = GetCursorPosition()
                cx, cy = cx / uiScale, cy / uiScale
                -- Offset from cursor to handle TOPLEFT (matches SetPoint TOPLEFT while dragging).
                local left, top = self.handle:GetLeft(), self.handle:GetTop()
                if left and top then
                    self.dragOffsetX = left - cx
                    self.dragOffsetY = top - cy
                else
                    local ax, ay = self.handle:GetCenter()
                    self.dragOffsetX = (ax or 0) - cx - (HANDLE_SIZE * 0.5)
                    self.dragOffsetY = (ay or 0) - cy + (HANDLE_SIZE * 0.5)
                end
            end
        end)
        self.handle:SetScript("OnMouseUp", function()
            if self.moving then
                self.moving = false
                self:SaveOffsetFromHandle()
            end
        end)

        local bg = self.handle:CreateTexture(nil, "ARTWORK")
        bg:SetPoint("TOPLEFT", 1, -1)
        bg:SetPoint("BOTTOMRIGHT", -1, 1)
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bg:SetVertexColor(0.85, 0.55, 0.2, 0.9)
        self.handleBg = bg

        local mark = self.handle:CreateFontString(nil, "OVERLAY")
        if Mancer.Util and Mancer.Util.ApplyFont then
            Mancer.Util.ApplyFont(mark, 12)
        end
        mark:SetPoint("CENTER")
        mark:SetText("H")
        mark:SetTextColor(0, 0, 0, 1)
        self.handleMark = mark
        -- OnUpdate lives on ticker (below) — hiding this frame must not stop scanning.
    end

    -- Rebuild rows as status bars (migrates old text-only rows after /reload).
    if self.rows then
        for _, old in ipairs(self.rows) do
            if old and old.Hide then
                old:Hide()
            end
            if old and old.frame and old.frame.Hide then
                old.frame:Hide()
            end
        end
    end

    local tex = GetMinionHpBarTexture()
    self.rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Frame", nil, self.frame)
        row:SetSize(LABEL_WIDTH + BAR_WIDTH, BAR_HEIGHT)
        row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", HANDLE_SIZE + 4, -(i - 1) * ROW_HEIGHT)
        row:Hide()

        local label = row:CreateFontString(nil, "OVERLAY")
        if Mancer.Util and Mancer.Util.ApplyFont then
            Mancer.Util.ApplyFont(label, 12)
        else
            label:SetFontObject(GameFontHighlightSmall)
        end
        label:SetJustifyH("LEFT")
        label:SetPoint("LEFT", row, "LEFT", 0, 0)
        label:SetWidth(LABEL_WIDTH - 2)
        label:SetTextColor(0.9, 0.92, 0.85, 1)

        -- Dark empty track behind the tinted XPerl fill.
        local track = row:CreateTexture(nil, "BACKGROUND")
        track:SetPoint("LEFT", row, "LEFT", LABEL_WIDTH, 0)
        track:SetSize(BAR_WIDTH, BAR_HEIGHT)
        track:SetTexture(HP_BAR_FILL_FALLBACK)
        track:SetVertexColor(0.08, 0.08, 0.08, 0.9)

        local bar = CreateFrame("StatusBar", nil, row)
        bar:SetPoint("LEFT", row, "LEFT", LABEL_WIDTH, 0)
        bar:SetSize(BAR_WIDTH, BAR_HEIGHT)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
        -- Greyscale skins tint via SetStatusBarColor (green→red HP).
        bar:SetStatusBarTexture(tex)
        local fill = bar:GetStatusBarTexture()
        if fill then
            fill:SetTexture(tex)
            fill:SetHorizTile(false)
            fill:SetVertTile(false)
        end
        bar:SetStatusBarColor(0.28, 0.88, 0.28, 1)

        local value = bar:CreateFontString(nil, "OVERLAY")
        if Mancer.Util and Mancer.Util.ApplyFont then
            Mancer.Util.ApplyFont(value, 12)
        else
            value:SetFontObject(GameFontHighlightSmall)
        end
        value:SetPoint("CENTER", bar, "CENTER", 0, 0)
        value:SetTextColor(1, 1, 1, 0.95)
        value:SetShadowOffset(1, -1)

        self.rows[i] = {
            frame = row,
            label = label,
            track = track,
            bar = bar,
            value = value,
        }
    end
end

function MinionHpHud:ApplyBarTextures()
    if not self.rows then
        return
    end
    local tex = GetMinionHpBarTexture()
    for _, row in ipairs(self.rows) do
        if row.track then
            row.track:SetTexture(HP_BAR_FILL_FALLBACK)
            row.track:SetVertexColor(0.08, 0.08, 0.08, 0.9)
        end
        if row.bar then
            row.bar:SetStatusBarTexture(tex)
            local fill = row.bar:GetStatusBarTexture()
            if fill then
                fill:SetTexture(tex)
                fill:SetHorizTile(false)
                fill:SetVertTile(false)
            end
        end
    end
end

function MinionHpHud:EnsureTicker()
    if self.ticker then
        return
    end
    -- Always-running ticker: the list frame hides when no minions are up, and a
    -- hidden frame's OnUpdate stops — resummons would never refresh until Display opens.
    local ticker = CreateFrame("Frame", "MancerMinionHpTicker")
    ticker:SetScript("OnUpdate", function(_, elapsed)
        self:OnUpdate(elapsed)
    end)
    self.ticker = ticker
end

function MinionHpHud:RequestRefreshSoon()
    self.elapsed = REFRESH_INTERVAL
end

function MinionHpHud:SaveOffsetFromHandle()
    if not self.handle or not Mancer.FloatingText or not Mancer.FloatingText.anchor then
        return
    end
    -- Must save the same TOPLEFT↔CENTER offsets used while dragging.
    -- Using GetCenter here used to snap the bar by ~half the H-handle size on drop.
    local x, y = self._dragX, self._dragY
    if not x or not y then
        local parent = Mancer.FloatingText.anchor
        local hx, hy = self.handle:GetLeft(), self.handle:GetTop()
        local ax, ay = parent:GetCenter()
        if hx and hy and ax and ay then
            x = (hx - ax)
            y = (hy - ay)
        else
            return
        end
    end
    MancerDB.minionHpListOffset = {
        x = x,
        y = y,
    }
    self._layoutX, self._layoutY = x, y
    self._dragX, self._dragY = nil, nil
    -- Already at the drop point — skip ClearAllPoints/SetPoint snap.
end

function MinionHpHud:ApplyLayout(force)
    self:EnsureFrames()
    if self.moving and not force then
        return
    end

    local parent = (Mancer.FloatingText and Mancer.FloatingText.anchor) or UIParent
    if self.frame:GetParent() ~= parent then
        self.frame:SetParent(parent)
    end
    if self.handle and self.handle:GetParent() ~= parent then
        self.handle:SetParent(parent)
        self.handle:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 1) + 45)
    end

    local off = MancerDB.minionHpListOffset or { x = 90, y = 20 }
    local x, y = off.x or 90, off.y or 20
    if not force
        and self._layoutParent == parent
        and self._layoutX == x
        and self._layoutY == y
    then
        return
    end
    self._layoutParent = parent
    self._layoutX = x
    self._layoutY = y

    pcall(function()
        self.frame:ClearAllPoints()
        self.frame:SetPoint("TOPLEFT", parent, "CENTER", x, y)
        if self.handle then
            self.handle:ClearAllPoints()
            self.handle:SetPoint("TOPLEFT", parent, "CENTER", x, y)
        end
    end)
end

function MinionHpHud:SetMoveMode(enabled)
    self:EnsureFrames()
    self.moveMode = not not enabled
    self.moving = false
    self:ApplyLayout(true)
    if self.handle then
        local show = enabled and FeatureEnabled()
        self.handle:EnableMouse(show)
        if show then
            self.handle:Show()
        else
            self.handle:Hide()
        end
    end
    -- Immediate refresh so preview rows + H appear without waiting for OnUpdate.
    self:Refresh(true)
end

function MinionHpHud:OnUpdate(elapsed)
    if self.moving and self.handle and Mancer.FloatingText and Mancer.FloatingText.anchor then
        -- Same pattern as A/Z/T: if mouse-up is lost (handle slid out from under cursor),
        -- stop when the button is no longer held.
        local stillDown = IsMouseButtonDown and IsMouseButtonDown("LeftButton")
        if not stillDown then
            self.moving = false
            self:SaveOffsetFromHandle()
        else
            local uiScale = UIParent:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            cx, cy = cx / uiScale, cy / uiScale
            local ax, ay = Mancer.FloatingText.anchor:GetCenter()
            if ax and ay then
                local x = (cx + (self.dragOffsetX or 0)) - ax
                local y = (cy + (self.dragOffsetY or 0)) - ay
                self._dragX, self._dragY = x, y
                -- Invalidate cached layout while dragging.
                self._layoutX, self._layoutY = nil, nil
                pcall(function()
                    self.frame:ClearAllPoints()
                    self.frame:SetPoint("TOPLEFT", Mancer.FloatingText.anchor, "CENTER", x, y)
                    self.handle:ClearAllPoints()
                    self.handle:SetPoint("TOPLEFT", Mancer.FloatingText.anchor, "CENTER", x, y)
                end)
            end
        end
    end

    self.elapsed = (self.elapsed or 0) + (elapsed or 0)
    if self.elapsed < REFRESH_INTERVAL then
        return
    end
    self.elapsed = 0
    self:Refresh()
end

function MinionHpHud:Refresh(forceSync)
    self:EnsureFrames()
    self:ApplyLayout()
    self:SyncNameplateSupport(forceSync)

    if not FeatureEnabled() then
        self.frame:Hide()
        if self.handle then
            self.handle:Hide()
        end
        self._lastRowText = nil
        return
    end

    local rows = self:CollectHpRows()
    -- Move mode always shows sample rows so H + list are findable even with no tokens yet.
    if self.moveMode and #rows == 0 then
        rows = {
            { label = "Ghoul", health = 21000, healthMax = 21000 },
            { label = "Abom", health = 28800, healthMax = 48000 },
            { label = "Fiend", health = 4500, healthMax = 18000 },
        }
    end

    if #rows == 0 then
        self.frame:Hide()
        if self.handle and self.moveMode then
            self.handle:Show()
        elseif self.handle then
            self.handle:Hide()
        end
        self._lastRowText = nil
        return
    end

    if not self.frame:IsShown() then
        self.frame:Show()
    end
    if self.moveMode and self.handle then
        if not self.handle:IsShown() then
            self.handle:Show()
        end
    elseif self.handle and self.handle:IsShown() then
        self.handle:Hide()
    end

    self._lastRowText = self._lastRowText or {}
    for i = 1, MAX_ROWS do
        local slot = self.rows[i]
        local row = rows[i]
        if row and slot and slot.bar then
            local pct = 0
            if row.healthMax and row.healthMax > 0 then
                pct = row.health / row.healthMax
            end
            if pct < 0 then
                pct = 0
            elseif pct > 1 then
                pct = 1
            end
            local text = string.format(
                "%s|%s/%s|%.3f",
                row.label or "",
                FormatHp(row.health),
                FormatHp(row.healthMax),
                pct
            )
            if self._lastRowText[i] ~= text then
                self._lastRowText[i] = text
                slot.label:SetText(row.label or "")
                slot.value:SetText(string.format("[%s/%s]", FormatHp(row.health), FormatHp(row.healthMax)))
                slot.bar:SetMinMaxValues(0, 1)
                slot.bar:SetValue(pct)
                local r, g, b = HpBarColor(pct)
                slot.bar:SetStatusBarColor(r, g, b, 1)
            end
            if not slot.frame:IsShown() then
                slot.frame:Show()
            end
        elseif slot and slot.frame then
            self._lastRowText[i] = nil
            if slot.frame:IsShown() then
                slot.frame:Hide()
            end
        end
    end

    local height = math.min(#rows, MAX_ROWS) * ROW_HEIGHT + 4
    local width = HANDLE_SIZE + 4 + LABEL_WIDTH + BAR_WIDTH
    if self._lastHeight ~= height or self._lastWidth ~= width then
        self._lastHeight = height
        self._lastWidth = width
        self.frame:SetHeight(height)
        self.frame:SetWidth(width)
    end
end

function MinionHpHud:ApplyConfig()
    self:EnsureFrames()
    self:EnsureTicker()
    self:ApplyBarTextures()
    self:ApplyLayout(true)
    self:SyncNameplateSupport(true)
    self:Refresh(true)
end

function MinionHpHud:New()
    local self = setmetatable({}, { __index = MinionHpHud })
    self.elapsed = 0
    self.moveMode = false
    self:EnsureFrames()
    self:EnsureTicker()
    self:ApplyConfig()

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGOUT")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    pcall(function()
        f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    end)
    pcall(function()
        f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    end)
    f:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_LOGOUT" then
            self:ClearNameplateVisualHide()
            self:RestoreNameplates()
        elseif event == "PLAYER_ENTERING_WORLD" then
            self:ApplyConfig()
        elseif event == "NAME_PLATE_UNIT_ADDED" then
            self:OnNamePlateUnitAdded(unit)
            if FeatureEnabled() then
                self:RequestRefreshSoon()
                self:Refresh()
            end
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            if FeatureEnabled() then
                self:RequestRefreshSoon()
            end
        end
    end)
    self.eventFrame = f
    return self
end
