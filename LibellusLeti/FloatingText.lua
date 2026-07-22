Mancer.FloatingTextModule = {}
local FloatingText = Mancer.FloatingTextModule

local POOL_SIZE = 6
local TICK_DURATION = 1.6
-- Pad past the vine outer edge (circle path sits slightly outside the bar).
local TICK_RADIUS_OFFSET = 12
-- Vine art tucks in more than a circle near the feet; pull ticks inward at progress 0.
local TICK_BOTTOM_PULL = 18
local SCALE_HANDLE_PROGRESS = 1.0
local SCALE_HANDLE_RADIUS_MULT = 1.12
local HANDLE_SIZE = 22
local MIN_SCALE = 0.5
local MAX_SCALE = 2.0
local ADVISOR_ICON_BASE_SIZE = 36
local ADVISOR_ICON_GAP = 6
local ADVISOR_ICON_PULSE_SPEED = 2.2
local ANIMATE_READY_PULSE_SPEED = 3.6
local ANIMATE_READY_BURST_SPEED = 10
local ANIMATE_READY_BURST_SEC = 2.8
local ICON_PULSE_INTERVAL = 0.05
local ANIMATE_ICON_SLOTS = 6
local ANIMATE_ICON_BASE_SIZE = 28
local ANIMATE_DEFAULT_SCALE = 0.75
local MIN_ANIMATE_SCALE = 0.35
local MAX_ANIMATE_SCALE = 1.75
local ADVISOR_DEFAULT_SCALE = 1.0
local MIN_ADVISOR_SCALE = 0.5
local MAX_ADVISOR_SCALE = 2.0
-- Glyph size fed to SetFont (must stay under the client size cap ~18–21).
local ADVISOR_GLYPH_SIZE = 14
-- Display height at scale 1.0; SetTextHeight scales past the SetFont cap.
local ADVISOR_HEIGHT_AT_1 = 18
local HUD_WHEEL_STEP = 0.1
local ADVISOR_WHEEL_STEP = 0.08
local ANIMATE_DEFAULT_OFFSET = { x = 0, y = -40 }
local ZOMBIE_ICON_BASE_SIZE = 32
local ZOMBIE_DEFAULT_SCALE = 0.85
local MIN_ZOMBIE_SCALE = 0.4
local MAX_ZOMBIE_SCALE = 1.75
local ZOMBIE_DEFAULT_OFFSET = { x = 56, y = -40 }
local ZOMBIE_ICON_FALLBACK = "Interface\\Icons\\Spell_Shadow_AnimateDead"
local PROC_ICON_SLOTS = 4
local PROC_ICON_BASE_SIZE = 30
local PROC_DEFAULT_SCALE = 0.8
local MIN_PROC_SCALE = 0.4
local MAX_PROC_SCALE = 1.75
local PROC_DEFAULT_OFFSET = { x = -56, y = -40 }

-- SecureActionButtonTemplate protects the button AND its parent. Check before any
-- SetSize/SetPoint/Show/Hide on the A-strip (must be declared before methods that use it).
local function IsCombatLocked()
    return InCombatLockdown and InCombatLockdown()
end

local function CanTouchAnimateStrip()
    return not IsCombatLocked()
end

-- Ascension can fire PLAYER_REGEN_ENABLED a tick before protected frames unlock.
-- Never call ClearAllPoints/SetPoint/SetSize/Show/Hide on protected frames until safe.
local function SafeProtectedCall(frame, method, ...)
    if not frame or not method or IsCombatLocked() then
        return false
    end
    local fn = frame[method]
    if type(fn) ~= "function" then
        return false
    end
    -- pcall so Ascension lockdown races don't throw; still skip when locked above.
    local ok = pcall(fn, frame, ...)
    return ok and true or false
end

local function CreateFontString(parent, fontSize)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    Mancer.Util.ApplyFont(fs, fontSize)
    fs:SetShadowOffset(1, -1)
    fs:Hide()
    return fs
end

function FloatingText:GetScale()
    return MancerDB.scale or 1
end

function FloatingText:GetScaledRadius()
    return (MancerDB.arcRadius or 65) * self:GetScale()
end

function FloatingText:GetTickFontSize()
    return math.max(10, MancerDB.fontSize or 22)
end

function FloatingText:GetRateFontSize()
    return math.max(10, self:GetTickFontSize() - 8)
end

function FloatingText:GetGuideFontSize()
    return math.max(10, math.floor(self:GetTickFontSize() * 0.6))
end

function FloatingText:GetScaledFontSize(baseSize)
    return math.max(8, math.floor((baseSize * self:GetScale()) + 0.5))
end

function FloatingText:GetAdvisorFontSize()
    return math.max(10, math.floor(ADVISOR_HEIGHT_AT_1 * self:GetAdvisorTextScale() + 0.5))
end

function FloatingText:ApplyAdvisorFont(fontString, heightMult)
    if not fontString then
        return
    end
    heightMult = heightMult or 1
    -- Keep SetFont under the client glyph cap; scale the drawn height instead.
    Mancer.Util.ApplyFont(fontString, ADVISOR_GLYPH_SIZE)
    local height = ADVISOR_HEIGHT_AT_1 * self:GetAdvisorTextScale() * heightMult
    height = math.max(8, height)
    if fontString.SetTextHeight then
        fontString:SetTextHeight(height)
    else
        Mancer.Util.ApplyFont(fontString, math.max(10, math.floor(height + 0.5)))
    end
end

function FloatingText:ApplyFonts()
    for _, entry in ipairs(self.pool) do
        Mancer.Util.ApplyFont(entry.fs, self:GetTickFontSize())
    end

    Mancer.Util.ApplyFont(self.rateText, self:GetRateFontSize())

    if self.advisorText then
        self:ApplyAdvisorFont(self.advisorText, 1)
    end
    if self.advisorLfText then
        self:ApplyAdvisorFont(self.advisorLfText, 0.9)
    end

    if self.arcGuides then
        local guideSize = self:GetGuideFontSize()
        for _, guide in ipairs(self.arcGuides) do
            Mancer.Util.ApplyFont(guide.mana, guideSize)
            Mancer.Util.ApplyFont(guide.health, guideSize)
        end
    end
end

local function GetArcOffset(progress, side, radius)
    return Mancer.Util.GetArcOffset(progress, side, radius)
end

-- Regen / preview text on the outside of the vine bars; follows barTransform moves.
function FloatingText:GetTickArcPosition(progress, side)
    local baseRadius = self:GetScaledRadius()
    local ox, oy = self:GetBarTransformOffset()
    local widthScale = 1
    if Mancer.ArcBars and Mancer.ArcBars.GetTransform then
        local t = Mancer.ArcBars:GetTransform("unified")
        widthScale = tonumber(t and t.width) or 1
    elseif MancerDB and MancerDB.barTransform and MancerDB.barTransform.unified then
        widthScale = tonumber(MancerDB.barTransform.unified.width) or 1
    end
    if widthScale < 0.25 then
        widthScale = 0.25
    elseif widthScale > 3 then
        widthScale = 3
    end
    progress = math.max(0, math.min(1, progress or 0))
    -- Bar visual thickness (same formula as ArcBars layout) + pad past the outer edge.
    local barWidth = math.max(18, baseRadius * 0.38) * widthScale
    local radius = baseRadius + (barWidth * 0.55) + TICK_RADIUS_OFFSET
    local x, y = GetArcOffset(progress, side, radius)
    -- Squared ease: full inward pull at the bottom, none at the top (top already matches).
    local pull = TICK_BOTTOM_PULL * (1 - progress) * (1 - progress) * self:GetScale()
    if side == "health" then
        x = x - pull
    else
        x = x + pull
    end
    return x + ox, y + oy
end

function FloatingText:GetBaseArcDistance()
    local baseRadius = (MancerDB.arcRadius or 65) * SCALE_HANDLE_RADIUS_MULT
    local x, y = GetArcOffset(SCALE_HANDLE_PROGRESS, "health", baseRadius)
    return math.sqrt((x * x) + (y * y))
end

local function SetSolidTexture(texture, r, g, b, a)
    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    texture:SetVertexColor(r, g, b, a)
end

local function IsLeftMouseDown()
    return IsMouseButtonDown and IsMouseButtonDown("LeftButton")
end

local function RaiseTextAboveBars(fontString)
    if fontString and fontString.SetDrawLayer then
        fontString:SetDrawLayer("OVERLAY", 7)
    end
end

function FloatingText:New()
    local self = setmetatable({}, { __index = FloatingText })

    self.anchor = CreateFrame("Frame", "MancerAnchor", UIParent)
    self.anchor:SetSize(1, 1)
    self.anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    self.anchor:SetFrameStrata("MEDIUM")
    self.anchor:SetFrameLevel(24)
    self.moveMode = false
    self.moving = false
    self.scaling = false
    self.advisorMoving = false

    self.dragHandle = CreateFrame("Button", nil, self.anchor)
    self.dragHandle:SetSize(HANDLE_SIZE, HANDLE_SIZE)
    self.dragHandle:SetPoint("CENTER", self.anchor, "CENTER", 0, 0)
    self.dragHandle:EnableMouse(false)
    self.dragHandle:Hide()
    self.dragHandle:SetScript("OnMouseDown", function()
        if self.moveMode and not self.advisorMoving and not self.animateMoving and not self.barMoving and not self.helpMoving then
            self.moving = true
            local uiScale = UIParent:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            cx, cy = cx / uiScale, cy / uiScale
            local ax, ay = self.anchor:GetCenter()
            self.dragOffsetX = ax - cx
            self.dragOffsetY = ay - cy
        end
    end)
    self.dragHandle:SetScript("OnMouseUp", function()
        self:StopInteraction()
    end)
    self.dragHandle:EnableMouseWheel(true)
    self.dragHandle:SetScript("OnMouseWheel", function(_, delta)
        if self.moveMode then
            self:AdjustHudScale(delta > 0 and HUD_WHEEL_STEP or -HUD_WHEEL_STEP)
        end
    end)

    self.centerMarker = self.dragHandle:CreateFontString(nil, "OVERLAY")
    Mancer.Util.ApplyFont(self.centerMarker, 20)
    self.centerMarker:SetPoint("CENTER", self.dragHandle, "CENTER", 0, 0)
    self.centerMarker:SetText("+")
    self.centerMarker:SetTextColor(1, 0.85, 0.2, 1)

    -- B = bar move + scale hotspot (replaces the full-size yellow hitbox).
    self.barHandle = CreateFrame("Button", nil, self.anchor)
    self.barHandle:SetSize(HANDLE_SIZE, HANDLE_SIZE)
    self.barHandle:EnableMouse(false)
    self.barHandle:Hide()
    self.barHandle:SetScript("OnMouseDown", function()
        if self.moveMode and not self.moving and not self.advisorMoving and not self.animateMoving then
            self.barMoving = true
            local uiScale = UIParent:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            cx, cy = cx / uiScale, cy / uiScale
            local ax, ay = self.barHandle:GetCenter()
            self.barDragOffsetX = ax - cx
            self.barDragOffsetY = ay - cy
        end
    end)
    self.barHandle:SetScript("OnMouseUp", function()
        self:StopBarInteraction()
    end)
    self.barHandle:EnableMouseWheel(true)
    self.barHandle:SetScript("OnMouseWheel", function(_, delta)
        if self.moveMode and Mancer.ArcBars and Mancer.ArcBars.AdjustBarScale then
            Mancer.ArcBars:AdjustBarScale(delta > 0 and 1 or -1)
        end
    end)

    self.barHandleBg = self.barHandle:CreateTexture(nil, "ARTWORK")
    self.barHandleBg:SetPoint("TOPLEFT", 1, -1)
    self.barHandleBg:SetPoint("BOTTOMRIGHT", -1, 1)
    SetSolidTexture(self.barHandleBg, 1, 0.85, 0.2, 0.9)

    self.barHandleMark = self.barHandle:CreateFontString(nil, "OVERLAY")
    Mancer.Util.ApplyFont(self.barHandleMark, 14)
    self.barHandleMark:SetPoint("CENTER", self.barHandle, "CENTER", 0, 0)
    self.barHandleMark:SetText("B")
    self.barHandleMark:SetTextColor(0, 0, 0, 1)

    -- Single movable help box for move mode (no letter handle).
    self.helpMoving = false
    self.helpBox = CreateFrame("Button", "MancerMoveHelp", UIParent)
    self.helpBox:SetSize(300, 78)
    self.helpBox:SetFrameStrata("HIGH")
    self.helpBox:SetFrameLevel(100)
    self.helpBox:EnableMouse(true)
    self.helpBox:Hide()
    self.helpBox:RegisterForClicks("LeftButtonUp", "LeftButtonDown")

    local helpBg = self.helpBox:CreateTexture(nil, "BACKGROUND")
    helpBg:SetAllPoints()
    SetSolidTexture(helpBg, 0.05, 0.05, 0.08, 0.82)

    local helpEdge = self.helpBox:CreateTexture(nil, "BORDER")
    helpEdge:SetPoint("TOPLEFT", 0, 0)
    helpEdge:SetPoint("BOTTOMRIGHT", 0, 0)
    SetSolidTexture(helpEdge, 1, 0.82, 0.25, 0.35)
    local helpInset = self.helpBox:CreateTexture(nil, "BORDER")
    helpInset:SetPoint("TOPLEFT", 1, -1)
    helpInset:SetPoint("BOTTOMRIGHT", -1, 1)
    SetSolidTexture(helpInset, 0.05, 0.05, 0.08, 0.82)

    self.helpBoxText = self.helpBox:CreateFontString(nil, "OVERLAY")
    Mancer.Util.ApplyFont(self.helpBoxText, 11)
    self.helpBoxText:SetPoint("TOPLEFT", 10, -10)
    self.helpBoxText:SetPoint("BOTTOMRIGHT", -10, 10)
    self.helpBoxText:SetJustifyH("LEFT")
    self.helpBoxText:SetJustifyV("MIDDLE")
    self.helpBoxText:SetTextColor(1, 0.9, 0.55, 1)
    self.helpBoxText:SetText(
        "Drag letter handles to move panels.\n"
            .. "Mousewheel on a handle scales it (except bars).\n"
            .. "Use the yellow squares to move and resize the bars."
    )
    if self.helpBoxText.SetWordWrap then
        self.helpBoxText:SetWordWrap(true)
    end
    if self.helpBoxText.SetNonSpaceWrap then
        self.helpBoxText:SetNonSpaceWrap(true)
    end

    self.helpBox:SetScript("OnMouseDown", function()
        if not self.moveMode then
            return
        end
        if self.moving or self.advisorMoving or self.animateMoving
            or self.zombieMoving or self.procMoving or self.barMoving then
            return
        end
        self.helpMoving = true
        local uiScale = UIParent:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        cx, cy = cx / uiScale, cy / uiScale
        local ax, ay = self.helpBox:GetCenter()
        self.helpDragOffsetX = ax - cx
        self.helpDragOffsetY = ay - cy
    end)
    self.helpBox:SetScript("OnMouseUp", function()
        self:StopHelpInteraction()
    end)

    self.pool = {}
    for i = 1, POOL_SIZE do
        local fs = CreateFontString(self.anchor, 22)
        RaiseTextAboveBars(fs)
        self.pool[i] = {
            fs = fs,
            active = false,
            elapsed = 0,
            side = "mana",
            jitter = 0,
        }
    end

    self.rateText = CreateFontString(self.anchor, 14)
    self.rateText:SetPoint("TOP", self.anchor, "BOTTOM", 0, -8)

    self.advisorText = CreateFontString(self.anchor, 18)
    self.advisorText:SetShadowOffset(2, -2)
    self.advisorText:Hide()

    self.advisorLfText = CreateFontString(self.anchor, 16)
    self.advisorLfText:SetShadowOffset(2, -2)
    self.advisorLfText:Hide()

    -- Legacy center icons (unused for Animate CDs; kept empty / hidden).
    self.advisorIcons = CreateFrame("Frame", nil, self.anchor)
    self.advisorIcons:Hide()
    self.advisorIconSlots = {}
    for i = 1, 2 do
        local slotFrame = CreateFrame("Frame", nil, self.advisorIcons)
        slotFrame:Hide()

        local icon = slotFrame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local border = slotFrame:CreateTexture(nil, "OVERLAY")
        border:SetPoint("TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", 1, -1)
        border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        border:SetTexCoord(0.2, 0.8, 0.2, 0.8)

        self.advisorIconSlots[i] = {
            frame = slotFrame,
            icon = icon,
            border = border,
        }
    end

    self.advisorHandle = CreateFrame("Button", nil, self.anchor)
    self.advisorHandle:SetSize(HANDLE_SIZE, HANDLE_SIZE)
    self.advisorHandle:EnableMouse(false)
    self.advisorHandle:Hide()
    self.advisorHandle:SetScript("OnMouseDown", function()
        if self.moveMode and not self.moving and not self.animateMoving then
            self.advisorMoving = true
            local uiScale = UIParent:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            cx, cy = cx / uiScale, cy / uiScale
            local ax, ay = self.advisorHandle:GetCenter()
            self.advisorDragOffsetX = ax - cx
            self.advisorDragOffsetY = ay - cy
        end
    end)
    self.advisorHandle:SetScript("OnMouseUp", function()
        self:StopAdvisorInteraction()
    end)
    self.advisorHandle:EnableMouseWheel(true)
    self.advisorHandle:SetScript("OnMouseWheel", function(_, delta)
        if self.moveMode then
            self:AdjustAdvisorTextScale(delta > 0 and ADVISOR_WHEEL_STEP or -ADVISOR_WHEEL_STEP)
        end
    end)

    self.advisorHandleMark = self.advisorHandle:CreateFontString(nil, "OVERLAY")
    Mancer.Util.ApplyFont(self.advisorHandleMark, 14)
    self.advisorHandleMark:SetPoint("CENTER", self.advisorHandle, "CENTER", 0, 0)
    self.advisorHandleMark:SetText("T")
    self.advisorHandleMark:SetTextColor(0, 0, 0, 1)

    self.advisorHandleBg = self.advisorHandle:CreateTexture(nil, "ARTWORK")
    self.advisorHandleBg:SetPoint("TOPLEFT", 1, -1)
    self.advisorHandleBg:SetPoint("BOTTOMRIGHT", -1, 1)
    SetSolidTexture(self.advisorHandleBg, 0.35, 0.85, 1.0, 0.9)

    -- Larger mouse zone over suggestion text so wheel/drag work without hitting the tiny T.
    -- Button (not Frame): 3.3.5 mousewheel is unreliable on plain Frames.
    self.advisorHit = CreateFrame("Button", nil, self.anchor)
    self.advisorHit:SetSize(1, 1)
    self.advisorHit:EnableMouse(false)
    self.advisorHit:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
    self.advisorHit:EnableMouseWheel(true)
    self.advisorHit:Hide()
    if self.advisorHit.SetNormalTexture then
        self.advisorHit:SetNormalTexture("")
    end
    if self.advisorHit.SetHighlightTexture then
        self.advisorHit:SetHighlightTexture("")
    end
    if self.advisorHit.SetPushedTexture then
        self.advisorHit:SetPushedTexture("")
    end
    self.advisorHit:SetScript("OnMouseWheel", function(_, delta)
        if self.moveMode then
            self:AdjustAdvisorTextScale(delta > 0 and ADVISOR_WHEEL_STEP or -ADVISOR_WHEEL_STEP)
        end
    end)
    self.advisorHit:SetScript("OnMouseDown", function()
        if self.moveMode and not self.moving and not self.animateMoving and not self.barMoving then
            self.advisorMoving = true
            local uiScale = UIParent:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            cx, cy = cx / uiScale, cy / uiScale
            local ax, ay = self.advisorHandle:GetCenter()
            self.advisorDragOffsetX = ax - cx
            self.advisorDragOffsetY = ay - cy
        end
    end)
    self.advisorHit:SetScript("OnMouseUp", function()
        self:StopAdvisorInteraction()
    end)

    -- Animate-ready strip (own movable A handle).
    self.animateReady = CreateFrame("Frame", nil, self.anchor)
    self.animateReady:SetSize(1, 1)
    self.animateReady:Hide()
    self.animateReady:EnableMouse(false)
    self.animateReady:EnableMouseWheel(true)
    self.animateReady:SetScript("OnMouseWheel", function(_, delta)
        if self.moveMode then
            self:AdjustAnimateIconScale(delta > 0 and 0.08 or -0.08)
        end
    end)
    self.animateIconSlots = {}
    for i = 1, ANIMATE_ICON_SLOTS do
        -- Secure cast button: user left-click only. CastSpellByName from OnClick is blocked by the client.
        local slotFrame
        local okSecure = pcall(function()
            slotFrame = CreateFrame("Button", "MancerAnimateCast" .. i, self.animateReady, "SecureActionButtonTemplate")
        end)
        if not okSecure or not slotFrame then
            slotFrame = CreateFrame("Button", "MancerAnimateCast" .. i, self.animateReady)
            slotFrame.mancerInsecure = true
        end
        slotFrame:Hide()
        slotFrame:EnableMouse(true)
        slotFrame:RegisterForClicks("LeftButtonUp")
        -- Do NOT call CastSpell* from OnClick — that triggers "Addon Action Blocked".
        -- Casting is driven by SecureActionButton attributes (type/spell) set out of combat.
        slotFrame:SetScript("OnEnter", nil)
        slotFrame:SetScript("OnLeave", nil)
        slotFrame:EnableMouseWheel(true)
        slotFrame:SetScript("OnMouseWheel", function(_, delta)
            if FloatingText.moveMode then
                FloatingText:AdjustAnimateIconScale(delta > 0 and 0.08 or -0.08)
            end
        end)

        -- Visual child holds art/timers. Never SetScale the secure button (client blocks it).
        local visual = CreateFrame("Frame", nil, slotFrame)
        visual:SetAllPoints(slotFrame)
        visual:EnableMouse(false)

        local icon = visual:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local border = visual:CreateTexture(nil, "OVERLAY")
        border:SetPoint("TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", 1, -1)
        border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        border:SetTexCoord(0.2, 0.8, 0.2, 0.8)

        local cooldown
        local ok = pcall(function()
            cooldown = CreateFrame("Cooldown", nil, visual, "CooldownFrameTemplate")
        end)
        if not ok or not cooldown then
            cooldown = CreateFrame("Cooldown", nil, visual)
        end
        cooldown:SetAllPoints(visual)
        if cooldown.SetDrawEdge then
            cooldown:SetDrawEdge(false)
        end
        -- Prefer our own seconds label; suppress OmniCC / native "1m" text on this swipe.
        cooldown.noCooldown = true
        cooldown.noCooldownCount = true
        cooldown.noOCC = true
        cooldown.noOmniCC = true
        if cooldown.SetHideCountdownNumbers then
            cooldown:SetHideCountdownNumbers(true)
        end
        -- Must not steal clicks from the cast button.
        cooldown:EnableMouse(false)
        cooldown:Hide()

        -- Timer must sit above Cooldown (swipe + OmniCC), or the number is buried/illegible.
        local timerLayer = CreateFrame("Frame", nil, visual)
        timerLayer:SetAllPoints(visual)
        timerLayer:SetFrameLevel((cooldown:GetFrameLevel() or 1) + 12)
        timerLayer:EnableMouse(false)

        local timerBg = timerLayer:CreateTexture(nil, "BACKGROUND")
        timerBg:SetTexture("Interface\\Buttons\\WHITE8X8")
        timerBg:SetVertexColor(0, 0, 0, 0.62)
        timerBg:SetPoint("CENTER", timerLayer, "CENTER", 0, 0)
        timerBg:Hide()

        local timer = timerLayer:CreateFontString(nil, "OVERLAY")
        Mancer.Util.ApplyFont(timer, 16)
        timer:SetPoint("CENTER", timerLayer, "CENTER", 0, 0)
        timer:SetTextColor(1, 1, 1, 1)
        if timer.SetShadowColor then
            timer:SetShadowColor(0, 0, 0, 1)
            timer:SetShadowOffset(1, -1)
        end
        timer:Hide()

        -- Top-right: seconds until Animate despawns (while still out).
        local aliveTimer = timerLayer:CreateFontString(nil, "OVERLAY")
        Mancer.Util.ApplyFont(aliveTimer, 11)
        aliveTimer:SetPoint("TOPRIGHT", timerLayer, "TOPRIGHT", -1, -1)
        aliveTimer:SetJustifyH("RIGHT")
        aliveTimer:SetTextColor(0.35, 1.0, 0.85, 1)
        if aliveTimer.SetShadowColor then
            aliveTimer:SetShadowColor(0, 0, 0, 1)
            aliveTimer:SetShadowOffset(1, -1)
        end
        aliveTimer:Hide()

        self.animateIconSlots[i] = {
            frame = slotFrame,
            visual = visual,
            icon = icon,
            border = border,
            cooldown = cooldown,
            timerLayer = timerLayer,
            timerBg = timerBg,
            timer = timer,
            aliveTimer = aliveTimer,
        }
    end
    self:EnsureAnimateSecureListener()

    self.animateHandle = CreateFrame("Button", nil, self.anchor)
    self.animateHandle:SetSize(HANDLE_SIZE, HANDLE_SIZE)
    self.animateHandle:EnableMouse(false)
    self.animateHandle:Hide()
    self.animateHandle:SetScript("OnMouseDown", function()
        if self.moveMode and not self.moving and not self.advisorMoving then
            self.animateMoving = true
            local uiScale = UIParent:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            cx, cy = cx / uiScale, cy / uiScale
            local ax, ay = self.animateHandle:GetCenter()
            self.animateDragOffsetX = ax - cx
            self.animateDragOffsetY = ay - cy
        end
    end)
    self.animateHandle:SetScript("OnMouseUp", function()
        self:StopAnimateInteraction()
    end)
    self.animateHandle:EnableMouseWheel(true)
    self.animateHandle:SetScript("OnMouseWheel", function(_, delta)
        if self.moveMode then
            self:AdjustAnimateIconScale(delta > 0 and 0.08 or -0.08)
        end
    end)

    self.animateHandleMark = self.animateHandle:CreateFontString(nil, "OVERLAY")
    Mancer.Util.ApplyFont(self.animateHandleMark, 14)
    self.animateHandleMark:SetPoint("CENTER", self.animateHandle, "CENTER", 0, 0)
    self.animateHandleMark:SetText("A")
    self.animateHandleMark:SetTextColor(0, 0, 0, 1)

    self.animateHandleBg = self.animateHandle:CreateTexture(nil, "BACKGROUND")
    self.animateHandleBg:SetPoint("TOPLEFT", 1, -1)
    self.animateHandleBg:SetPoint("BOTTOMRIGHT", -1, 1)
    SetSolidTexture(self.animateHandleBg, 0.95, 0.55, 0.25, 0.95)
    if self.animateHandleBg.SetDrawLayer then
        self.animateHandleBg:SetDrawLayer("BACKGROUND", 0)
    end

    -- Harvest Plague zombie counter (own movable Z handle).
    -- Button (not Frame) so Ascension/3.3.5 mousewheel is reliable, same as A / T.
    self.zombieCounter = CreateFrame("Button", nil, self.anchor)
    self.zombieCounter:SetSize(ZOMBIE_ICON_BASE_SIZE, ZOMBIE_ICON_BASE_SIZE)
    self.zombieCounter:Hide()
    self.zombieCounter:EnableMouse(false)
    self.zombieCounter:EnableMouseWheel(true)
    self.zombieCounter:RegisterForClicks("AnyUp")
    self.zombieCounter:SetScript("OnMouseWheel", function(_, delta)
        if self.moveMode then
            self:AdjustZombieIconScale(delta > 0 and 0.08 or -0.08)
        end
    end)
    self.zombieCounter:SetScript("OnMouseDown", function()
        if self.moveMode and not self.moving and not self.advisorMoving and not self.animateMoving then
            self.zombieMoving = true
            local uiScale = UIParent:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            cx, cy = cx / uiScale, cy / uiScale
            local ax, ay = self.zombieHandle:GetCenter()
            self.zombieDragOffsetX = ax - cx
            self.zombieDragOffsetY = ay - cy
        end
    end)
    self.zombieCounter:SetScript("OnMouseUp", function()
        self:StopZombieInteraction()
    end)

    self.zombieIcon = self.zombieCounter:CreateTexture(nil, "ARTWORK")
    self.zombieIcon:SetAllPoints()
    self.zombieIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    self.zombieIcon:SetTexture(ZOMBIE_ICON_FALLBACK)

    self.zombieBorder = self.zombieCounter:CreateTexture(nil, "OVERLAY")
    self.zombieBorder:SetPoint("TOPLEFT", -1, 1)
    self.zombieBorder:SetPoint("BOTTOMRIGHT", 1, -1)
    self.zombieBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    self.zombieBorder:SetTexCoord(0.2, 0.8, 0.2, 0.8)
    self.zombieBorder:SetVertexColor(0.45, 0.9, 0.4, 1)

    self.zombieCountText = self.zombieCounter:CreateFontString(nil, "OVERLAY")
    Mancer.Util.ApplyFont(self.zombieCountText, 14)
    self.zombieCountText:SetPoint("BOTTOMRIGHT", self.zombieCounter, "BOTTOMRIGHT", 1, -1)
    self.zombieCountText:SetTextColor(1, 0.95, 0.4, 1)
    self.zombieCountText:SetShadowOffset(1, -1)
    self.zombieCountText:SetText("0")

    self.zombieHandle = CreateFrame("Button", nil, self.anchor)
    self.zombieHandle:SetSize(HANDLE_SIZE, HANDLE_SIZE)
    self.zombieHandle:EnableMouse(false)
    self.zombieHandle:Hide()
    self.zombieHandle:SetScript("OnMouseDown", function()
        if self.moveMode and not self.moving and not self.advisorMoving and not self.animateMoving then
            self.zombieMoving = true
            local uiScale = UIParent:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            cx, cy = cx / uiScale, cy / uiScale
            local ax, ay = self.zombieHandle:GetCenter()
            self.zombieDragOffsetX = ax - cx
            self.zombieDragOffsetY = ay - cy
        end
    end)
    self.zombieHandle:SetScript("OnMouseUp", function()
        self:StopZombieInteraction()
    end)
    self.zombieHandle:EnableMouseWheel(true)
    self.zombieHandle:SetScript("OnMouseWheel", function(_, delta)
        if self.moveMode then
            self:AdjustZombieIconScale(delta > 0 and 0.08 or -0.08)
        end
    end)

    self.zombieHandleMark = self.zombieHandle:CreateFontString(nil, "OVERLAY")
    Mancer.Util.ApplyFont(self.zombieHandleMark, 14)
    self.zombieHandleMark:SetPoint("CENTER", self.zombieHandle, "CENTER", 0, 0)
    self.zombieHandleMark:SetText("Z")
    self.zombieHandleMark:SetTextColor(0, 0, 0, 1)

    self.zombieHandleBg = self.zombieHandle:CreateTexture(nil, "ARTWORK")
    self.zombieHandleBg:SetPoint("TOPLEFT", 1, -1)
    self.zombieHandleBg:SetPoint("BOTTOMRIGHT", -1, 1)
    SetSolidTexture(self.zombieHandleBg, 0.45, 0.85, 0.4, 0.9)

    -- Proc / trigger strip (Diabolical, Bone King, …) — movable P handle.
    self.procStrip = CreateFrame("Frame", nil, self.anchor)
    self.procStrip:SetSize(1, 1)
    self.procStrip:Hide()
    self.procStrip:EnableMouse(false)
    self.procStrip:EnableMouseWheel(true)
    self.procStrip:SetScript("OnMouseWheel", function(_, delta)
        if self.moveMode then
            self:AdjustProcIconScale(delta > 0 and 0.08 or -0.08)
        end
    end)
    self.procIconSlots = {}
    for i = 1, PROC_ICON_SLOTS do
        local slotFrame = CreateFrame("Frame", nil, self.procStrip)
        slotFrame:Hide()

        local icon = slotFrame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local border = slotFrame:CreateTexture(nil, "OVERLAY")
        border:SetPoint("TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", 1, -1)
        border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        border:SetTexCoord(0.2, 0.8, 0.2, 0.8)
        border:SetVertexColor(0.75, 0.45, 1, 1)

        local cooldown
        local okCd = pcall(function()
            cooldown = CreateFrame("Cooldown", nil, slotFrame, "CooldownFrameTemplate")
        end)
        if not okCd or not cooldown then
            cooldown = CreateFrame("Cooldown", nil, slotFrame)
        end
        cooldown:SetAllPoints(slotFrame)
        if cooldown.SetDrawEdge then
            cooldown:SetDrawEdge(false)
        end
        cooldown.noCooldown = true
        cooldown.noCooldownCount = true
        cooldown.noOCC = true
        cooldown.noOmniCC = true
        if cooldown.SetHideCountdownNumbers then
            cooldown:SetHideCountdownNumbers(true)
        end
        cooldown:Hide()

        local timerLayer = CreateFrame("Frame", nil, slotFrame)
        timerLayer:SetAllPoints(slotFrame)
        timerLayer:SetFrameLevel((cooldown:GetFrameLevel() or 1) + 12)

        local timerBg = timerLayer:CreateTexture(nil, "BACKGROUND")
        timerBg:SetTexture("Interface\\Buttons\\WHITE8X8")
        timerBg:SetVertexColor(0, 0, 0, 0.62)
        timerBg:SetPoint("CENTER", timerLayer, "CENTER", 0, 0)
        timerBg:Hide()

        local timer = timerLayer:CreateFontString(nil, "OVERLAY")
        Mancer.Util.ApplyFont(timer, 14)
        timer:SetPoint("CENTER", timerLayer, "CENTER", 0, 0)
        timer:SetTextColor(1, 0.9, 0.35, 1)
        if timer.SetShadowColor then
            timer:SetShadowColor(0, 0, 0, 1)
            timer:SetShadowOffset(1, -1)
        end
        timer:Hide()

        local stacks = timerLayer:CreateFontString(nil, "OVERLAY")
        Mancer.Util.ApplyFont(stacks, 12)
        stacks:SetPoint("BOTTOMRIGHT", timerLayer, "BOTTOMRIGHT", 1, -1)
        stacks:SetJustifyH("RIGHT")
        stacks:SetTextColor(1, 0.95, 0.45, 1)
        if stacks.SetShadowColor then
            stacks:SetShadowColor(0, 0, 0, 1)
            stacks:SetShadowOffset(1, -1)
        end
        stacks:Hide()

        self.procIconSlots[i] = {
            frame = slotFrame,
            icon = icon,
            border = border,
            cooldown = cooldown,
            timerLayer = timerLayer,
            timerBg = timerBg,
            timer = timer,
            stacks = stacks,
        }
    end

    self.procHandle = CreateFrame("Button", nil, self.anchor)
    self.procHandle:SetSize(HANDLE_SIZE, HANDLE_SIZE)
    self.procHandle:EnableMouse(false)
    self.procHandle:Hide()
    self.procHandle:SetScript("OnMouseDown", function()
        if self.moveMode and not self.moving and not self.advisorMoving and not self.animateMoving and not self.zombieMoving then
            self.procMoving = true
            local uiScale = UIParent:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            cx, cy = cx / uiScale, cy / uiScale
            local ax, ay = self.procHandle:GetCenter()
            self.procDragOffsetX = ax - cx
            self.procDragOffsetY = ay - cy
        end
    end)
    self.procHandle:SetScript("OnMouseUp", function()
        self:StopProcInteraction()
    end)
    self.procHandle:EnableMouseWheel(true)
    self.procHandle:SetScript("OnMouseWheel", function(_, delta)
        if self.moveMode then
            self:AdjustProcIconScale(delta > 0 and 0.08 or -0.08)
        end
    end)

    self.procHandleMark = self.procHandle:CreateFontString(nil, "OVERLAY")
    Mancer.Util.ApplyFont(self.procHandleMark, 14)
    self.procHandleMark:SetPoint("CENTER", self.procHandle, "CENTER", 0, 0)
    self.procHandleMark:SetText("P")
    self.procHandleMark:SetTextColor(0, 0, 0, 1)

    self.procHandleBg = self.procHandle:CreateTexture(nil, "ARTWORK")
    self.procHandleBg:SetPoint("TOPLEFT", 1, -1)
    self.procHandleBg:SetPoint("BOTTOMRIGHT", -1, 1)
    SetSolidTexture(self.procHandleBg, 0.7, 0.4, 0.95, 0.9)

    self:ApplyAdvisorLayout()

    self.anchor:SetScript("OnUpdate", function(_, elapsed)
        self:OnUpdate(elapsed)
    end)

    return self
end

function FloatingText:EnsureArcGuides()
    if self.arcGuides then
        return
    end

    self.arcGuides = {}
    local samples = {
        { progress = 0.15, manaText = "+12", healthText = "+8" },
        { progress = 0.45, manaText = "+12", healthText = "+8" },
        { progress = 0.7, manaText = "+12", healthText = "+8" },
    }

    for i, sample in ipairs(samples) do
        local mana = CreateFontString(self.anchor, 13)
        RaiseTextAboveBars(mana)
        mana:SetText(sample.manaText)
        mana:SetTextColor(0.35, 0.65, 1.0, 0.45)

        local health = CreateFontString(self.anchor, 13)
        RaiseTextAboveBars(health)
        health:SetText(sample.healthText)
        health:SetTextColor(0.35, 0.95, 0.45, 0.45)

        self.arcGuides[i] = {
            progress = sample.progress,
            mana = mana,
            health = health,
        }
    end
end

function FloatingText:ApplyAdvisorLayout()
    MancerDB.advisorTextOffset = MancerDB.advisorTextOffset or { x = 0, y = 28 }
    MancerDB.animateBarOffset = MancerDB.animateBarOffset or {
        x = ANIMATE_DEFAULT_OFFSET.x,
        y = ANIMATE_DEFAULT_OFFSET.y,
    }
    MancerDB.zombieCounterOffset = MancerDB.zombieCounterOffset or {
        x = ZOMBIE_DEFAULT_OFFSET.x,
        y = ZOMBIE_DEFAULT_OFFSET.y,
    }
    MancerDB.procBarOffset = MancerDB.procBarOffset or {
        x = PROC_DEFAULT_OFFSET.x,
        y = PROC_DEFAULT_OFFSET.y,
    }
    local offset = MancerDB.advisorTextOffset
    local animateOffset = MancerDB.animateBarOffset
    local zombieOffset = MancerDB.zombieCounterOffset
    local procOffset = MancerDB.procBarOffset

    if self.advisorHandle then
        self.advisorHandle:ClearAllPoints()
        self.advisorHandle:SetPoint("CENTER", self.anchor, "CENTER", offset.x or 0, offset.y or 28)
        self.advisorHandle:SetFrameLevel(self.anchor:GetFrameLevel() + 40)
    end

    if self.animateHandle then
        self.animateHandle:ClearAllPoints()
        self.animateHandle:SetPoint(
            "CENTER",
            self.anchor,
            "CENTER",
            animateOffset.x or ANIMATE_DEFAULT_OFFSET.x,
            animateOffset.y or ANIMATE_DEFAULT_OFFSET.y
        )
        self.animateHandle:SetFrameLevel(self.anchor:GetFrameLevel() + 40)
    end

    if self.zombieHandle then
        self.zombieHandle:ClearAllPoints()
        self.zombieHandle:SetPoint(
            "CENTER",
            self.anchor,
            "CENTER",
            zombieOffset.x or ZOMBIE_DEFAULT_OFFSET.x,
            zombieOffset.y or ZOMBIE_DEFAULT_OFFSET.y
        )
        self.zombieHandle:SetFrameLevel(self.anchor:GetFrameLevel() + 40)
    end

    if self.procHandle then
        self.procHandle:ClearAllPoints()
        self.procHandle:SetPoint(
            "CENTER",
            self.anchor,
            "CENTER",
            procOffset.x or PROC_DEFAULT_OFFSET.x,
            procOffset.y or PROC_DEFAULT_OFFSET.y
        )
        self.procHandle:SetFrameLevel(self.anchor:GetFrameLevel() + 40)
    end

    self:LayoutAdvisorTexts()

    if self.advisorIcons then
        self.advisorIcons:ClearAllPoints()
        self.advisorIcons:SetPoint("CENTER", self.advisorHandle or self.anchor, "CENTER", 0, 0)
        self.advisorIcons:SetFrameLevel(self.anchor:GetFrameLevel() + 38)
    end

    if self.animateReady then
        -- Icons sit above A (same pattern as Z), so the orange handle plate stays visible.
        if CanTouchAnimateStrip() then
            SafeProtectedCall(self.animateReady, "ClearAllPoints")
            SafeProtectedCall(self.animateReady, "SetPoint", "BOTTOM", self.animateHandle or self.anchor, "TOP", 0, 4)
            if self.animateReady.SetFrameLevel then
                self.animateReady:SetFrameLevel(
                    (self.animateHandle and self.animateHandle:GetFrameLevel() or self.anchor:GetFrameLevel()) + 2
                )
            end
        else
            self.pendingAnimateStripAnchor = true
        end
    end

    if self.zombieCounter then
        -- Icon sits above Z so the handle stays clickable (same idea as T hit box).
        self.zombieCounter:ClearAllPoints()
        self.zombieCounter:SetPoint("BOTTOM", self.zombieHandle or self.anchor, "TOP", 0, 4)
        self.zombieCounter:SetFrameLevel((self.zombieHandle and self.zombieHandle:GetFrameLevel() or self.anchor:GetFrameLevel()) + 2)
        self:LayoutZombieCounter()
    end

    if self.procStrip then
        self.procStrip:ClearAllPoints()
        self.procStrip:SetPoint("CENTER", self.procHandle or self.anchor, "CENTER", 0, 0)
        self.procStrip:SetFrameLevel(self.anchor:GetFrameLevel() + 38)
    end
end

function FloatingText:LayoutAdvisorTexts()
    local hasStance = self.advisorText and self.advisorText:IsShown()
        and (self.advisorText:GetText() or "") ~= ""
    local hasLf = self.advisorLfText and self.advisorLfText:IsShown()
        and (self.advisorLfText:GetText() or "") ~= ""

    if self.advisorText then
        self.advisorText:ClearAllPoints()
        if hasStance and hasLf then
            self.advisorText:SetPoint("BOTTOM", self.advisorHandle or self.anchor, "CENTER", 0, 4)
        else
            self.advisorText:SetPoint("CENTER", self.advisorHandle or self.anchor, "CENTER", 0, 0)
        end
    end

    if self.advisorLfText then
        self.advisorLfText:ClearAllPoints()
        if hasStance and hasLf then
            self.advisorLfText:SetPoint("TOP", self.advisorText, "BOTTOM", 0, -2)
        else
            self.advisorLfText:SetPoint("CENTER", self.advisorHandle or self.anchor, "CENTER", 0, 0)
        end
    end

    self:LayoutAdvisorHit()
end

function FloatingText:LayoutAdvisorHit()
    if not self.advisorHit or not self.advisorHandle then
        return
    end

    local padX, padY = 16, 10
    local width = HANDLE_SIZE + padX * 2
    local height = HANDLE_SIZE + padY * 2
    local extraAbove = 0
    local extraBelow = 0

    local function growFrom(fs)
        if not fs or not fs:IsShown() then
            return
        end
        local text = fs:GetText()
        if not text or text == "" then
            return
        end
        local tw = fs:GetStringWidth() or 0
        local th = fs:GetStringHeight() or 0
        width = math.max(width, tw + padX * 2)
        -- Text sits on/above the T handle; extend the hit box upward.
        extraAbove = math.max(extraAbove, th + padY)
    end

    growFrom(self.advisorText)
    growFrom(self.advisorLfText)
    if self.advisorText and self.advisorText:IsShown()
        and self.advisorLfText and self.advisorLfText:IsShown() then
        extraAbove = extraAbove + 4
    end

    height = HANDLE_SIZE + extraAbove + extraBelow + padY
    self.advisorHit:ClearAllPoints()
    self.advisorHit:SetSize(math.max(80, width), math.max(HANDLE_SIZE + 8, height))
    -- Anchor so the bottom covers T and the top covers suggestion lines.
    self.advisorHit:SetPoint("BOTTOM", self.advisorHandle, "BOTTOM", 0, -padY)
    -- Sit above the T handle so wheel always hits this Button (3.3.5).
    local handleLevel = (self.advisorHandle:GetFrameLevel() or 1) + 2
    self.advisorHit:SetFrameLevel(handleLevel)
    self.advisorHandle:SetFrameLevel(math.max(1, handleLevel - 1))

    if self.moveMode then
        self.advisorHit:Show()
        self.advisorHit:EnableMouse(true)
        self.advisorHit:EnableMouseWheel(true)
    else
        self.advisorHit:Hide()
        self.advisorHit:EnableMouse(false)
    end
end

function FloatingText:GetAnimateIconScale()
    local scale = tonumber(MancerDB and MancerDB.animateIconScale)
    if not scale then
        scale = ANIMATE_DEFAULT_SCALE
    end
    return math.max(MIN_ANIMATE_SCALE, math.min(MAX_ANIMATE_SCALE, scale))
end

function FloatingText:GetAdvisorTextScale()
    local scale = tonumber(MancerDB and MancerDB.advisorTextScale)
    if not scale then
        scale = ADVISOR_DEFAULT_SCALE
    end
    return math.max(MIN_ADVISOR_SCALE, math.min(MAX_ADVISOR_SCALE, scale))
end

function FloatingText:GetAdvisorIconSize()
    return math.max(24, math.floor(ADVISOR_ICON_BASE_SIZE * self:GetScale()))
end

function FloatingText:GetAnimateIconSize()
    return math.max(16, math.floor(ANIMATE_ICON_BASE_SIZE * self:GetAnimateIconScale() + 0.5))
end

function FloatingText:AdjustHudScale(delta)
    local next = math.max(MIN_SCALE, math.min(MAX_SCALE, self:GetScale() + (delta or 0)))
    MancerDB.scale = math.floor(next * 100 + 0.5) / 100
    self:RefreshScaledLayout()
end

function FloatingText:AdjustAdvisorTextScale(delta)
    local next = math.max(
        MIN_ADVISOR_SCALE,
        math.min(MAX_ADVISOR_SCALE, self:GetAdvisorTextScale() + (delta or 0))
    )
    MancerDB.advisorTextScale = math.floor(next * 100 + 0.5) / 100
    self:ApplyFonts()
    if self.moveMode then
        self:ShowAdvisorPreview()
    elseif self.advisorDisplayActive then
        self:ShowAdvisorDisplay(self.advisorDisplayActive)
    end
    self:LayoutAdvisorHit()
end

function FloatingText:AdjustAnimateIconScale(delta)
    local next = self:GetAnimateIconScale() + (delta or 0)
    next = math.max(MIN_ANIMATE_SCALE, math.min(MAX_ANIMATE_SCALE, next))
    MancerDB.animateIconScale = math.floor(next * 100 + 0.5) / 100
    if self.moveMode then
        self:ShowAdvisorPreview()
    elseif self.advisorDisplayActive then
        self:ShowAdvisorDisplay(self.advisorDisplayActive)
    end
end

function FloatingText:GetZombieIconScale()
    local scale = tonumber(MancerDB and MancerDB.zombieIconScale)
    if not scale then
        scale = ZOMBIE_DEFAULT_SCALE
    end
    return math.max(MIN_ZOMBIE_SCALE, math.min(MAX_ZOMBIE_SCALE, scale))
end

function FloatingText:GetZombieIconSize()
    -- Match Animate: own scale, and also follow HUD + scale.
    return math.max(
        18,
        math.floor(ZOMBIE_ICON_BASE_SIZE * self:GetZombieIconScale() * self:GetScale() + 0.5)
    )
end

function FloatingText:AdjustZombieIconScale(delta)
    local next = self:GetZombieIconScale() + (delta or 0)
    next = math.max(MIN_ZOMBIE_SCALE, math.min(MAX_ZOMBIE_SCALE, next))
    MancerDB.zombieIconScale = math.floor(next * 100 + 0.5) / 100
    self:LayoutZombieCounter()
end

local function ResolveZombieIconTexture()
    if GetSpellInfo then
        local icon = select(3, GetSpellInfo("Harvest Plague"))
        if icon then
            return icon
        end
        icon = select(3, GetSpellInfo("Unrelenting Army"))
        if icon then
            return icon
        end
    end
    return ZOMBIE_ICON_FALLBACK
end

function FloatingText:LayoutZombieCounter()
    if not self.zombieCounter then
        return
    end
    local size = self:GetZombieIconSize()
    -- Ascension often ignores SetSize alone — set width/height explicitly.
    self.zombieCounter:SetWidth(size)
    self.zombieCounter:SetHeight(size)
    if self.zombieCounter.SetSize then
        self.zombieCounter:SetSize(size, size)
    end
    if self.zombieIcon then
        self.zombieIcon:ClearAllPoints()
        self.zombieIcon:SetPoint("TOPLEFT", self.zombieCounter, "TOPLEFT", 0, 0)
        self.zombieIcon:SetPoint("BOTTOMRIGHT", self.zombieCounter, "BOTTOMRIGHT", 0, 0)
        if self.zombieIcon.SetWidth then
            self.zombieIcon:SetWidth(size)
            self.zombieIcon:SetHeight(size)
        end
    end
    local countSize = math.max(10, math.floor(size * 0.48 + 0.5))
    if self.zombieCountText then
        Mancer.Util.ApplyFont(self.zombieCountText, math.min(18, countSize))
        if self.zombieCountText.SetTextHeight then
            self.zombieCountText:SetTextHeight(countSize)
        end
    end
end

function FloatingText:HideZombieCounter()
    if self.zombieCounter then
        self.zombieCounter:Hide()
    end
    if self.zombieHandle and not self.moveMode then
        self.zombieHandle:Hide()
    end
end

function FloatingText:UpdateZombieCounter(forcedCount)
    if not self.zombieCounter then
        return
    end

    local show = MancerDB.showZombieCounter ~= false
    local Advisor = Mancer.NecromancerAdvisor
    local hasTalent = Advisor and Advisor.HasUnrelentingArmy and Advisor:HasUnrelentingArmy()
    if not show or (not hasTalent and not self.moveMode) then
        self:HideZombieCounter()
        return
    end

    local count = forcedCount
    if count == nil then
        if self.moveMode and not hasTalent then
            count = 2
        elseif Advisor and Advisor.GetActiveZombieCount then
            count = Advisor:GetActiveZombieCount()
        else
            count = 0
        end
    end
    count = math.max(0, math.floor(tonumber(count) or 0))

    if self.zombieIcon then
        self.zombieIcon:SetTexture(ResolveZombieIconTexture())
        if not self.zombieIcon:GetTexture() then
            self.zombieIcon:SetTexture(ZOMBIE_ICON_FALLBACK)
        end
    end
    if self.zombieCountText then
        self.zombieCountText:SetText(tostring(count))
        if count > 0 then
            self.zombieCountText:SetTextColor(1, 0.95, 0.4, 1)
        else
            self.zombieCountText:SetTextColor(0.75, 0.75, 0.75, 1)
        end
    end
    if self.zombieIcon then
        if count > 0 then
            self.zombieIcon:SetVertexColor(1, 1, 1, 1)
            if self.zombieIcon.SetDesaturated then
                self.zombieIcon:SetDesaturated(false)
            end
        else
            self.zombieIcon:SetVertexColor(0.65, 0.65, 0.65, 1)
            if self.zombieIcon.SetDesaturated then
                self.zombieIcon:SetDesaturated(true)
            end
        end
    end

    self:LayoutZombieCounter()
    self.zombieCounter:Show()
    if self.moveMode and self.zombieHandle and MancerDB.showZombieCounter ~= false then
        self.zombieHandle:Show()
    end
end

function FloatingText:GetProcIconScale()
    local scale = tonumber(MancerDB and MancerDB.procIconScale)
    if not scale or scale <= 0 then
        scale = PROC_DEFAULT_SCALE
    end
    return math.max(MIN_PROC_SCALE, math.min(MAX_PROC_SCALE, scale))
end

function FloatingText:GetProcIconSize()
    return math.max(
        16,
        math.floor(PROC_ICON_BASE_SIZE * self:GetProcIconScale() * self:GetScale() + 0.5)
    )
end

function FloatingText:AdjustProcIconScale(delta)
    local next = self:GetProcIconScale() + (delta or 0)
    next = math.max(MIN_PROC_SCALE, math.min(MAX_PROC_SCALE, next))
    MancerDB.procIconScale = math.floor(next * 100 + 0.5) / 100
    self:LayoutProcIcons(#(self.procLastIcons or {}))
end

function FloatingText:LayoutProcIcons(iconCount)
    if not self.procStrip then
        return
    end
    iconCount = math.max(0, math.floor(tonumber(iconCount) or 0))
    if iconCount <= 0 then
        self.procStrip:SetSize(1, 1)
        return
    end

    local size = self:GetProcIconSize()
    local gap = math.max(3, math.floor(ADVISOR_ICON_GAP * self:GetProcIconScale() + 0.5))
    local totalWidth = (iconCount * size) + ((iconCount - 1) * gap)
    local startX = (-totalWidth / 2) + (size / 2)
    self.procStrip:SetSize(math.max(1, totalWidth), size)

    for i, slot in ipairs(self.procIconSlots or {}) do
        if i <= iconCount then
            slot.frame:SetSize(size, size)
            slot.frame:ClearAllPoints()
            slot.frame:SetPoint(
                "CENTER",
                self.procStrip,
                "CENTER",
                startX + ((i - 1) * (size + gap)),
                0
            )
            if slot.timer then
                Mancer.Util.ApplyFont(slot.timer, math.max(12, math.floor(size * 0.5 + 0.5)))
            end
            if slot.stacks then
                Mancer.Util.ApplyFont(slot.stacks, math.max(10, math.floor(size * 0.4 + 0.5)))
            end
            if slot.timerBg then
                local bg = math.max(12, math.floor(size * 0.7 + 0.5))
                slot.timerBg:SetSize(bg, math.max(10, math.floor(bg * 0.55 + 0.5)))
            end
            if slot.timerLayer and slot.cooldown then
                slot.timerLayer:SetFrameLevel((slot.cooldown:GetFrameLevel() or 1) + 12)
            end
            slot.frame:Show()
        else
            slot.frame:Hide()
        end
    end
end

local function SetProcSlotTimer(slot, text, r, g, b)
    if not slot or not slot.timer then
        return
    end
    if text and text ~= "" then
        slot.timer:SetText(text)
        slot.timer:SetTextColor(r or 1, g or 0.9, b or 0.35, 1)
        slot.timer:Show()
        if slot.timerBg then
            slot.timerBg:Show()
        end
    else
        slot.timer:Hide()
        slot.timer:SetText("")
        if slot.timerBg then
            slot.timerBg:Hide()
        end
    end
end

local function SetProcSlotStacks(slot, stacks)
    if not slot or not slot.stacks then
        return
    end
    stacks = tonumber(stacks) or 0
    if stacks > 1 then
        slot.stacks:SetText(tostring(math.floor(stacks)))
        slot.stacks:Show()
    elseif stacks == 1 then
        slot.stacks:SetText("1")
        slot.stacks:Show()
    else
        slot.stacks:Hide()
        slot.stacks:SetText("")
    end
end

function FloatingText:ApplyProcIconState(slot, iconData)
    if not slot or not iconData then
        return
    end

    local texture = iconData.texture
    slot.icon:SetTexture(nil)
    if texture then
        slot.icon:SetTexture(texture)
    end
    if not slot.icon:GetTexture() then
        slot.icon:SetTexture("Interface\\Icons\\Spell_Shadow_ShadowWordDominate")
    end
    slot.icon:Show()

    local now = GetTime and GetTime() or 0
    local active = iconData.active == true
    local remaining = iconData.remaining
    local duration = iconData.duration
    local start = iconData.start
    if (not start or not duration or duration <= 0) and remaining and remaining > 0 and duration and duration > 0 then
        start = now - (duration - remaining)
    end
    if start and duration and duration > 0 then
        remaining = start + duration - now
    end

    slot.procStart = start
    slot.procDuration = duration
    slot.procActive = active

    if slot.cooldown and start and duration and duration > 0 and CooldownFrame_SetTimer then
        slot.cooldown.noCooldown = true
        slot.cooldown.noCooldownCount = true
        slot.cooldown.noOCC = true
        slot.cooldown.noOmniCC = true
        if slot.cooldown.SetHideCountdownNumbers then
            slot.cooldown:SetHideCountdownNumbers(true)
        end
        CooldownFrame_SetTimer(slot.cooldown, start, duration, 1)
        slot.cooldown:Show()
    elseif slot.cooldown then
        slot.cooldown:Hide()
    end

    if active then
        slot.icon:SetVertexColor(1, 1, 1, 1)
        if slot.icon.SetDesaturated then
            slot.icon:SetDesaturated(false)
        end
        if slot.border then
            slot.border:SetVertexColor(0.85, 0.45, 1, 1)
        end
        slot.frame:SetAlpha(1)
    else
        slot.icon:SetVertexColor(0.6, 0.6, 0.6, 1)
        if slot.icon.SetDesaturated then
            slot.icon:SetDesaturated(true)
        end
        if slot.border then
            slot.border:SetVertexColor(0.5, 0.5, 0.5, 1)
        end
        slot.frame:SetAlpha(0.85)
    end

    if remaining and remaining > 0.05 then
        local text
        if remaining < 10 then
            text = string.format("%.1f", remaining)
        else
            text = string.format("%.0f", remaining)
        end
        SetProcSlotTimer(slot, text, 1, 0.9, 0.35)
    else
        SetProcSlotTimer(slot, nil)
    end
    SetProcSlotStacks(slot, iconData.stacks)
end

function FloatingText:HideProcStrip()
    self.procIconPulse = false
    self.procLastIcons = nil
    if self.procStrip then
        self.procStrip:Hide()
    end
    for _, slot in ipairs(self.procIconSlots or {}) do
        slot.frame:Hide()
        slot.procStart = nil
        slot.procDuration = nil
        slot.procActive = nil
    end
    if self.procHandle and not self.moveMode then
        self.procHandle:Hide()
    end
end

function FloatingText:UpdateProcStrip()
    if not self.procStrip then
        return
    end

    local show = MancerDB.showProcBar ~= false
    if not show then
        self:HideProcStrip()
        return
    end

    local Advisor = Mancer.NecromancerAdvisor
    local icons = {}
    if Advisor and Advisor.GetProcStripIcons then
        icons = Advisor:GetProcStripIcons(self.moveMode == true) or {}
    end
    self.procLastIcons = icons

    local count = #icons
    if count <= 0 then
        self:HideProcStrip()
        if self.moveMode and self.procHandle and MancerDB.showProcBar ~= false then
            self.procHandle:Show()
        end
        return
    end

    local anyTimed = false
    for i, slot in ipairs(self.procIconSlots or {}) do
        local iconData = icons[i]
        if iconData and iconData.texture then
            self:ApplyProcIconState(slot, iconData)
            if iconData.active and iconData.remaining and iconData.remaining > 0.05 then
                anyTimed = true
            end
            slot.frame:Show()
        else
            slot.procStart = nil
            slot.procDuration = nil
            slot.procActive = nil
            slot.frame:Hide()
        end
    end

    self:LayoutProcIcons(count)
    self.procIconPulse = anyTimed
    self.procStrip:Show()
    if self.moveMode and self.procHandle and MancerDB.showProcBar ~= false then
        self.procHandle:Show()
    end
end

function FloatingText:LayoutAdvisorIcons(iconCount, hasText)
    -- Legacy center icons unused; keep hidden.
    if self.advisorIcons then
        self.advisorIcons:Hide()
    end
    for _, slot in ipairs(self.advisorIconSlots or {}) do
        slot.frame:Hide()
    end
    self:LayoutAdvisorTexts()
end

local function AnimatePulseTarget(slot)
    if not slot then
        return nil
    end
    -- Pulse/scale must never touch SecureActionButton frames.
    return slot.visual or slot.frame
end

-- Secure Animate buttons cannot Show/Hide/EnableMouse/SetPoint in combat.
local function CanTouchAnimateButton(btn)
    if not btn then
        return false
    end
    if btn.mancerInsecure then
        return true
    end
    return CanTouchAnimateStrip()
end

local function SetAnimateButtonShown(btn, shown)
    if not btn then
        return
    end
    shown = shown and true or false
    if not CanTouchAnimateButton(btn) then
        btn.mancerWantShown = shown
        return
    end
    btn.mancerWantShown = nil
    if shown then
        SafeProtectedCall(btn, "Show")
    else
        SafeProtectedCall(btn, "Hide")
    end
end

local function SetAnimateButtonMouse(btn, enabled)
    if not btn then
        return
    end
    enabled = enabled and true or false
    if not CanTouchAnimateButton(btn) then
        btn.mancerWantMouse = enabled
        return
    end
    btn.mancerWantMouse = nil
    SafeProtectedCall(btn, "EnableMouse", enabled)
end

function FloatingText:SetAnimateStripShown(shown)
    if not self.animateReady then
        return
    end
    shown = shown and true or false
    if not CanTouchAnimateStrip() then
        self.pendingAnimateStripShown = shown
        return
    end
    self.pendingAnimateStripShown = nil
    if shown then
        SafeProtectedCall(self.animateReady, "Show")
    else
        SafeProtectedCall(self.animateReady, "Hide")
    end
end

function FloatingText:LayoutAnimateIcons(iconCount)
    if not self.animateReady then
        return
    end

    iconCount = math.max(0, math.floor(tonumber(iconCount) or 0))
    self.pendingAnimateLayoutCount = iconCount

    -- Parent strip + SecureActionButton slots are protected in combat.
    if not CanTouchAnimateStrip() then
        return
    end

    if iconCount <= 0 then
        SafeProtectedCall(self.animateReady, "SetSize", 1, 1)
        return
    end

    local size = self:GetAnimateIconSize()
    local gap = math.max(3, math.floor(ADVISOR_ICON_GAP * self:GetAnimateIconScale() + 0.5))
    local totalWidth = (iconCount * size) + ((iconCount - 1) * gap)
    local startX = (-totalWidth / 2) + (size / 2)

    SafeProtectedCall(self.animateReady, "SetSize", math.max(1, totalWidth), size)

    for i, slot in ipairs(self.animateIconSlots) do
        if i <= iconCount then
            if CanTouchAnimateButton(slot.frame) then
                SafeProtectedCall(slot.frame, "SetSize", size, size)
                SafeProtectedCall(slot.frame, "ClearAllPoints")
                SafeProtectedCall(
                    slot.frame,
                    "SetPoint",
                    "CENTER",
                    self.animateReady,
                    "CENTER",
                    startX + ((i - 1) * (size + gap)),
                    0
                )
                -- visual is a child of the secure button → also protected.
                if slot.visual then
                    SafeProtectedCall(slot.visual, "SetAllPoints", slot.frame)
                    if slot.visual.SetScale then
                        slot.visual:SetScale(1)
                    end
                end
            end
            if slot.timer then
                local fontSize = math.max(14, math.floor(size * 0.58 + 0.5))
                Mancer.Util.ApplyFont(slot.timer, fontSize)
            end
            if slot.aliveTimer then
                Mancer.Util.ApplyFont(slot.aliveTimer, math.max(10, math.floor(size * 0.36 + 0.5)))
            end
            if slot.timerBg then
                local bg = math.max(12, math.floor(size * 0.72 + 0.5))
                slot.timerBg:SetSize(bg, math.max(10, math.floor(bg * 0.55 + 0.5)))
            end
            if slot.timerLayer and slot.cooldown then
                slot.timerLayer:SetFrameLevel((slot.cooldown:GetFrameLevel() or 1) + 12)
            end
            SetAnimateButtonShown(slot.frame, true)
        else
            SetAnimateButtonShown(slot.frame, false)
        end
    end
end

local function SetAnimateSlotTimer(slot, text, r, g, b)
    if not slot or not slot.timer then
        return
    end
    if text and text ~= "" then
        slot.timer:SetText(text)
        slot.timer:SetTextColor(r or 1, g or 1, b or 1, 1)
        slot.timer:Show()
        if slot.timerBg then
            slot.timerBg:Show()
        end
        if slot.timerLayer and slot.cooldown then
            slot.timerLayer:SetFrameLevel((slot.cooldown:GetFrameLevel() or 1) + 12)
        end
    else
        slot.timer:Hide()
        slot.timer:SetText("")
        if slot.timerBg then
            slot.timerBg:Hide()
        end
    end
end

local function SetAnimateAliveTimer(slot, text, r, g, b)
    if not slot or not slot.aliveTimer then
        return
    end
    if text and text ~= "" then
        slot.aliveTimer:SetText(text)
        slot.aliveTimer:SetTextColor(r or 0.35, g or 1, b or 0.85, 1)
        slot.aliveTimer:Show()
        if slot.timerLayer and slot.cooldown then
            slot.timerLayer:SetFrameLevel((slot.cooldown:GetFrameLevel() or 1) + 12)
        end
    else
        slot.aliveTimer:Hide()
        slot.aliveTimer:SetText("")
    end
end

local function FormatAnimateSeconds(remaining, preciseUnder10)
    if not remaining or remaining <= 0 then
        return nil
    end
    if preciseUnder10 and remaining < 10 then
        return string.format("%.1f", remaining)
    end
    return string.format("%.0f", remaining)
end

local function ArmAnimateCooldownNoCount(cd)
    if not cd then
        return
    end
    cd.noCooldown = true
    cd.noCooldownCount = true
    cd.noOCC = true
    cd.noOmniCC = true
    if cd.SetHideCountdownNumbers then
        cd:SetHideCountdownNumbers(true)
    end
end

function FloatingText:EnsureAnimateSecureListener()
    if self.animateSecureFrame then
        return
    end
    self.animateSecureFrame = CreateFrame("Frame")
    self.animateSecureFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.animateSecureFrame:SetScript("OnEvent", function(frame, event)
        if event ~= "PLAYER_REGEN_ENABLED" then
            return
        end
        -- Ascension often unlocks protected frames one frame after REGEN_ENABLED.
        frame.elapsed = 0
        frame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = (self.elapsed or 0) + (elapsed or 0)
            if IsCombatLocked() then
                return
            end
            -- Wait a short beat so ClearAllPoints/SetSize are legal on protected parents.
            if self.elapsed < 0.05 then
                return
            end
            self:SetScript("OnUpdate", nil)
            FloatingText:FlushPendingAnimateSpellBinds()
        end)
    end)
end

function FloatingText:ApplySecureAnimateBind(slot, spellId, spellName, castEnabled)
    local btn = slot and slot.frame
    if not btn or btn.mancerInsecure or not btn.SetAttribute then
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        return false
    end

    if castEnabled and spellName and spellName ~= "" then
        btn:SetAttribute("type", "spell")
        btn:SetAttribute("spell", spellName)
        -- Some Ascension builds also honor type1/spell1 for left click.
        btn:SetAttribute("type1", "spell")
        btn:SetAttribute("spell1", spellName)
        SetAnimateButtonMouse(btn, true)
    else
        btn:SetAttribute("type", nil)
        btn:SetAttribute("spell", nil)
        btn:SetAttribute("type1", nil)
        btn:SetAttribute("spell1", nil)
        SetAnimateButtonMouse(btn, castEnabled and true or false)
    end
    return true
end

function FloatingText:FlushPendingAnimateSpellBinds()
    if IsCombatLocked() then
        self:EnsureAnimateSecureListener()
        return
    end
    for _, slot in ipairs(self.animateIconSlots or {}) do
        local pending = slot.pendingSpellBind
        if pending then
            slot.pendingSpellBind = nil
            slot.spellId = pending.spellId
            slot.spellName = pending.spellName
            if slot.frame then
                slot.frame.mancerSpellId = pending.spellId
                slot.frame.mancerSpellName = pending.spellName
            end
            local castEnabled = not self.moveMode and pending.spellName and pending.spellName ~= ""
            self:ApplySecureAnimateBind(slot, pending.spellId, pending.spellName, castEnabled)
        elseif slot.spellName and not self.moveMode then
            self:ApplySecureAnimateBind(slot, slot.spellId, slot.spellName, true)
        end
        local btn = slot.frame
        if btn then
            if btn.mancerWantShown ~= nil then
                local want = btn.mancerWantShown
                btn.mancerWantShown = nil
                if want then
                    SafeProtectedCall(btn, "Show")
                else
                    SafeProtectedCall(btn, "Hide")
                end
            end
            if btn.mancerWantMouse ~= nil then
                local wantMouse = btn.mancerWantMouse
                btn.mancerWantMouse = nil
                SafeProtectedCall(btn, "EnableMouse", wantMouse)
            end
        end
    end

    if self.pendingAnimateStripShown ~= nil then
        local wantStrip = self.pendingAnimateStripShown
        self.pendingAnimateStripShown = nil
        if wantStrip then
            SafeProtectedCall(self.animateReady, "Show")
        else
            SafeProtectedCall(self.animateReady, "Hide")
        end
    end

    if self.pendingAnimateStripAnchor or self.animateReady then
        self.pendingAnimateStripAnchor = nil
        if self.animateReady and CanTouchAnimateStrip() then
            SafeProtectedCall(self.animateReady, "ClearAllPoints")
            SafeProtectedCall(self.animateReady, "SetPoint", "BOTTOM", self.animateHandle or self.anchor, "TOP", 0, 4)
        end
    end

    -- Re-apply layout now that secure SetSize/SetPoint are allowed again.
    local count = self.pendingAnimateLayoutCount
    if not count or count <= 0 then
        count = 0
        for _, slot in ipairs(self.animateIconSlots or {}) do
            if slot.frame and (slot.frame:IsShown() or slot.spellName) then
                count = count + 1
            end
        end
    end
    self:LayoutAnimateIcons(count)
end

function FloatingText:BindAnimateSlotSpell(slot, iconData)
    if not slot or not slot.frame then
        return
    end
    self:EnsureAnimateSecureListener()

    local spellId = iconData and tonumber(iconData.spellId) or nil
    local spellName = iconData and iconData.talentName or nil
    if (not spellName or spellName == "") and spellId and GetSpellInfo then
        spellName = GetSpellInfo(spellId)
    end
    -- Prefer book name if talent label differs from castable spell name.
    if spellId and GetSpellInfo then
        local bookName = GetSpellInfo(spellId)
        if bookName and bookName ~= "" then
            spellName = bookName
        end
    end

    slot.spellId = spellId
    slot.spellName = spellName
    slot.frame.mancerSpellId = spellId
    slot.frame.mancerSpellName = spellName
    slot.frame.mancerMinionId = iconData and iconData.minionId or nil

    local castEnabled = not self.moveMode and spellName and spellName ~= ""
    if not self:ApplySecureAnimateBind(slot, spellId, spellName, castEnabled) then
        slot.pendingSpellBind = { spellId = spellId, spellName = spellName }
        -- Still allow mouse for tooltip; cast binds after combat ends.
        if slot.frame and not self.moveMode then
            SetAnimateButtonMouse(slot.frame, true)
        end
    end
end

function FloatingText:ShowAnimateSlotTooltip(btn)
    if not btn or not GameTooltip or self.moveMode then
        return
    end
    local spellId = tonumber(btn.mancerSpellId)
    local spellName = btn.mancerSpellName
    if (not spellName or spellName == "") and spellId and GetSpellInfo then
        spellName = GetSpellInfo(spellId)
    end
    if not spellName and not spellId then
        return
    end

    GameTooltip:SetOwner(btn, "ANCHOR_BOTTOMLEFT")
    if spellId and GameTooltip.SetSpellByID then
        GameTooltip:SetSpellByID(spellId)
    elseif spellName then
        GameTooltip:SetText(spellName, 1, 1, 1)
    end
    if btn.mancerInsecure then
        GameTooltip:AddLine("Click-to-cast unavailable on this client", 1, 0.35, 0.35)
    else
        GameTooltip:AddLine("Click to cast", 0.35, 1.0, 0.75)
    end
    GameTooltip:Show()
end

function FloatingText:ApplyAnimateIconState(slot, iconData)
    if not slot or not iconData then
        return
    end

    self:BindAnimateSlotSpell(slot, iconData)

    local texture = iconData.texture
    slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    slot.icon:SetTexture(nil)
    if texture then
        slot.icon:SetTexture(texture)
    end
    -- CA / bad paths sometimes leave a blank texture — force a visible fallback.
    if not slot.icon:GetTexture() then
        slot.icon:SetTexture("Interface\\Icons\\Spell_Shadow_AnimateDead")
    end
    slot.icon:Show()

    local ready = iconData.ready ~= false and not iconData.active
    if iconData.ready ~= nil then
        ready = iconData.ready
    end
    local active = iconData.active == true
    slot.active = active

    -- Section canary yellow — readable over dark swipe / purple icons.
    local y = (Mancer.UI and Mancer.UI.Colors and Mancer.UI.Colors.sectionYellow) or { 1, 0.88, 0.12, 1 }
    local now = GetTime and GetTime() or 0

    -- Center = spell CD. Top-right = time until they vanish (while active).
    local cdStart = iconData.cdStart or iconData.spellStart or iconData.start
    local cdDuration = iconData.cdDuration or iconData.spellDuration or iconData.duration
    local cdRemaining = iconData.cdRemaining or iconData.spellRemaining or iconData.remaining
    local aliveRemaining = active and iconData.activeRemaining or nil

    if ready then
        slot.cdStart = nil
        slot.cdDuration = nil
        slot.aliveUntil = nil
        slot.icon:SetVertexColor(1, 1, 1, 1)
        if slot.icon.SetDesaturated then
            slot.icon:SetDesaturated(false)
        end
        if slot.cooldown then
            slot.cooldown:Hide()
            if CooldownFrame_SetTimer then
                CooldownFrame_SetTimer(slot.cooldown, 0, 0, 0)
            end
        end
        SetAnimateSlotTimer(slot, nil)
        SetAnimateAliveTimer(slot, nil)
        if slot.border then
            slot.border:SetVertexColor(0.55, 0.95, 0.7, 1)
        end
        local pulseTarget = AnimatePulseTarget(slot)
        if pulseTarget then
            pulseTarget:SetAlpha(1)
            pulseTarget:SetScale(1)
        end
        return
    end

    if (not cdStart or not cdDuration or cdDuration <= 0) and cdRemaining and cdRemaining > 0 then
        cdStart = now
        cdDuration = cdRemaining
    end
    if cdStart and cdDuration and cdDuration > 0 then
        cdRemaining = cdStart + cdDuration - now
    end

    slot.cdStart = cdStart
    slot.cdDuration = cdDuration
    if aliveRemaining and aliveRemaining > 0.05 then
        slot.aliveUntil = now + aliveRemaining
    else
        slot.aliveUntil = nil
    end

    if slot.cooldown and cdStart and cdDuration and cdDuration > 0 and CooldownFrame_SetTimer then
        ArmAnimateCooldownNoCount(slot.cooldown)
        CooldownFrame_SetTimer(slot.cooldown, cdStart, cdDuration, 1)
        slot.cooldown:Show()
    elseif slot.cooldown then
        slot.cooldown:Hide()
    end

    if active then
        slot.icon:SetVertexColor(1, 1, 1, 1)
        if slot.icon.SetDesaturated then
            slot.icon:SetDesaturated(false)
        end
        if slot.border then
            slot.border:SetVertexColor(0.25, 0.95, 0.75, 1)
        end
    else
        slot.icon:SetVertexColor(0.7, 0.7, 0.7, 1)
        if slot.icon.SetDesaturated then
            slot.icon:SetDesaturated(true)
        end
        if slot.border then
            slot.border:SetVertexColor(1, 1, 1, 1)
        end
    end

    if cdRemaining and cdRemaining > 0.5 then
        SetAnimateSlotTimer(slot, FormatAnimateSeconds(cdRemaining, false), y[1], y[2], y[3])
    else
        SetAnimateSlotTimer(slot, nil)
    end

    if slot.aliveUntil and slot.aliveUntil > now + 0.05 then
        local left = slot.aliveUntil - now
        SetAnimateAliveTimer(slot, FormatAnimateSeconds(left, true), 0.35, 1.0, 0.85)
    else
        SetAnimateAliveTimer(slot, nil)
    end

    local pulseTarget = AnimatePulseTarget(slot)
    if pulseTarget then
        pulseTarget:SetAlpha(1)
        pulseTarget:SetScale(1)
    end
end

function FloatingText:UpdateAdvisorIconPulse(elapsed)
    local hasAnimateSlots = false
    for _, slot in ipairs(self.animateIconSlots or {}) do
        if slot.frame:IsShown() then
            hasAnimateSlots = true
            break
        end
    end
    local hasProcSlots = false
    for _, slot in ipairs(self.procIconSlots or {}) do
        if slot.frame:IsShown() then
            hasProcSlots = true
            break
        end
    end
    if not self.advisorIconPulse and not self.animateIconPulse and not self.procIconPulse and not hasAnimateSlots and not hasProcSlots then
        return
    end

    self.iconPulseTimer = (self.iconPulseTimer or 0) + (elapsed or 0)
    if self.iconPulseTimer < ICON_PULSE_INTERVAL then
        return
    end
    self.iconPulseTimer = 0

    local now = GetTime()
    local inCombat = UnitAffectingCombat and UnitAffectingCombat("player")
    if self.animateIconPulse then
        for _, slot in ipairs(self.animateIconSlots or {}) do
            local pulseTarget = AnimatePulseTarget(slot)
            if slot.frame:IsShown() and slot.ready and pulseTarget then
                if inCombat then
                    local bursting = slot.readyBurstUntil and now < slot.readyBurstUntil
                    local speed = bursting and ANIMATE_READY_BURST_SPEED or ANIMATE_READY_PULSE_SPEED
                    local wave = 0.5 + (0.5 * math.sin(now * speed))
                    -- Idle ready: clear alpha + light scale. Just-finished CD: stronger bounce.
                    local alpha = bursting and (0.4 + (0.6 * wave)) or (0.62 + (0.38 * wave))
                    local scale = bursting and (1 + (0.2 * wave)) or (1 + (0.1 * wave))
                    pulseTarget:SetAlpha(alpha)
                    pulseTarget:SetScale(scale)
                    if slot.border then
                        if bursting then
                            slot.border:SetVertexColor(0.35, 1.0, 0.55, 1)
                        else
                            slot.border:SetVertexColor(0.55, 0.95, 0.7, 1)
                        end
                    end
                else
                    -- Out of combat: ready icons stay steady (no pulse).
                    slot.readyBurstUntil = nil
                    pulseTarget:SetAlpha(1)
                    pulseTarget:SetScale(1)
                    if slot.border then
                        slot.border:SetVertexColor(0.55, 0.95, 0.7, 1)
                    end
                end
            elseif slot.frame:IsShown() and slot.active and pulseTarget then
                pulseTarget:SetScale(1)
                pulseTarget:SetAlpha(1)
                if slot.border then
                    slot.border:SetVertexColor(0.25, 0.95, 0.75, 1)
                end
            elseif slot.frame:IsShown() and pulseTarget then
                pulseTarget:SetScale(1)
                if slot.border then
                    slot.border:SetVertexColor(1, 1, 1, 1)
                end
            end
        end
    end
    -- Center = spell CD; top-right = time until Animate vanishes.
    local y = (Mancer.UI and Mancer.UI.Colors and Mancer.UI.Colors.sectionYellow) or { 1, 0.88, 0.12, 1 }
    for _, slot in ipairs(self.animateIconSlots or {}) do
        if slot.frame:IsShown() then
            if slot.timer and slot.cdStart and slot.cdDuration and slot.cdDuration > 0 then
                local remaining = slot.cdStart + slot.cdDuration - now
                if remaining > 0.5 then
                    SetAnimateSlotTimer(slot, FormatAnimateSeconds(remaining, false), y[1], y[2], y[3])
                else
                    SetAnimateSlotTimer(slot, nil)
                end
            end
            if slot.aliveTimer then
                if slot.aliveUntil and slot.aliveUntil > now + 0.05 then
                    SetAnimateAliveTimer(slot, FormatAnimateSeconds(slot.aliveUntil - now, true), 0.35, 1.0, 0.85)
                else
                    slot.aliveUntil = nil
                    SetAnimateAliveTimer(slot, nil)
                end
            end
        end
    end
    if self.advisorIconPulse then
        local pulse = 0.78 + (0.22 * (0.5 + (0.5 * math.sin(now * ADVISOR_ICON_PULSE_SPEED))))
        for _, slot in ipairs(self.advisorIconSlots or {}) do
            if slot.frame:IsShown() then
                slot.frame:SetAlpha(pulse)
            end
        end
    end

    if self.procIconPulse then
        for _, slot in ipairs(self.procIconSlots or {}) do
            if slot.frame:IsShown() and slot.procStart and slot.procDuration and slot.procDuration > 0 then
                local remaining = slot.procStart + slot.procDuration - now
                if remaining > 0.05 then
                    local text
                    if remaining < 10 then
                        text = string.format("%.1f", remaining)
                    else
                        text = string.format("%.0f", remaining)
                    end
                    SetProcSlotTimer(slot, text, 1, 0.9, 0.35)
                else
                    SetProcSlotTimer(slot, nil)
                    slot.procActive = false
                end
            end
        end
    end
end

function FloatingText:ShowAdvisorPreview()
    local preview = {
        stanceText = "Undead: Protect",
        lfText = "Life Force (2/5)",
        text = "Undead: Protect\nLife Force (2/5)",
        icons = {},
        animateIcons = {},
        color = { 0.25, 0.95, 0.75 },
    }
    local Advisor = Mancer.NecromancerAdvisor

    -- Only Animates from CA known talents — same filter as live strip.
    if MancerDB.showAnimateBar ~= false and Advisor and Advisor.GetAnimateStripIcons then
        preview.animateIcons = Advisor:GetAnimateStripIcons()
    end

    self.advisorPreviewActive = true
    self:ShowAdvisorDisplay(preview, true)
    self:UpdateZombieCounter()
    self:UpdateProcStrip()
end

function FloatingText:GetBarArcMidpoint()
    local radius = (MancerDB.arcRadius or 65) * (MancerDB.scale or 1)
    if Mancer.ArcBars and Mancer.ArcBars.GetRadius then
        radius = Mancer.ArcBars:GetRadius()
    end
    local mx, my = Mancer.Util.GetArcBounds("mana", radius)
    local hx, hy = Mancer.Util.GetArcBounds("health", radius)
    return (mx + hx) * 0.5, (my + hy) * 0.5
end

function FloatingText:GetBarTransformOffset()
    local t = MancerDB.barTransform and MancerDB.barTransform.unified
    if Mancer.ArcBars and Mancer.ArcBars.GetTransform then
        t = Mancer.ArcBars:GetTransform("unified")
    end
    t = t or {}
    local maxOff = 80
    local ox = math.max(-maxOff, math.min(maxOff, tonumber(t.offsetX) or 0))
    local oy = math.max(-maxOff, math.min(maxOff, tonumber(t.offsetY) or 0))
    return ox, oy
end

function FloatingText:ApplyBarHandleLayout()
    if not self.barHandle then
        return
    end
    local midX, midY = self:GetBarArcMidpoint()
    local ox, oy = self:GetBarTransformOffset()
    self.barHandle:ClearAllPoints()
    self.barHandle:SetPoint("CENTER", self.anchor, "CENTER", midX + ox, midY + oy)
    self.barHandle:SetFrameLevel(self.anchor:GetFrameLevel() + 40)
end

function FloatingText:StopBarInteraction()
    if not self.barMoving then
        return
    end
    self.barMoving = false
    if self.lastBarDragX and self.lastBarDragY then
        MancerDB.barTransform = MancerDB.barTransform or {}
        local t = MancerDB.barTransform.unified
        if not t and Mancer.ArcBars and Mancer.ArcBars.GetTransform then
            t = Mancer.ArcBars:GetTransform("unified")
        end
        t = t or {}
        MancerDB.barTransform.unified = t
        local midX, midY = self:GetBarArcMidpoint()
        t.offsetX = math.floor((self.lastBarDragX - midX) + 0.5)
        t.offsetY = math.floor((self.lastBarDragY - midY) + 0.5)
        if Mancer.ArcBars and Mancer.ArcBars.GetTransform then
            Mancer.ArcBars:GetTransform("unified")
        end
        if Mancer.ArcBars and Mancer.ArcBars.Layout then
            Mancer.ArcBars:Layout()
        end
        self:ApplyBarHandleLayout()
    end
end

function FloatingText:UpdateBarPositionFromCursor()
    local uiScale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / uiScale, cy / uiScale

    local parentX, parentY = self.anchor:GetCenter()
    local x = (cx + self.barDragOffsetX) - parentX
    local y = (cy + self.barDragOffsetY) - parentY

    self.lastBarDragX = x
    self.lastBarDragY = y

    local midX, midY = self:GetBarArcMidpoint()
    MancerDB.barTransform = MancerDB.barTransform or {}
    local t = MancerDB.barTransform.unified
    if not t and Mancer.ArcBars and Mancer.ArcBars.GetTransform then
        t = Mancer.ArcBars:GetTransform("unified")
    end
    t = t or {}
    MancerDB.barTransform.unified = t
    t.offsetX = x - midX
    t.offsetY = y - midY
    if Mancer.ArcBars and Mancer.ArcBars.GetTransform then
        Mancer.ArcBars:GetTransform("unified")
    end
    if Mancer.ArcBars and Mancer.ArcBars.Layout then
        Mancer.ArcBars:Layout()
    end

    if self.barHandle then
        self.barHandle:ClearAllPoints()
        self.barHandle:SetPoint("CENTER", self.anchor, "CENTER", x, y)
    end
    if self.moveMode then
        self:ShowArcPreview()
    end
end

function FloatingText:StopAdvisorInteraction()
    if not self.advisorMoving then
        return
    end

    self.advisorMoving = false

    if self.lastAdvisorDragX and self.lastAdvisorDragY then
        MancerDB.advisorTextOffset = {
            x = math.floor(self.lastAdvisorDragX + 0.5),
            y = math.floor(self.lastAdvisorDragY + 0.5),
        }
        self:ApplyAdvisorLayout()
    end
end

function FloatingText:StopAnimateInteraction()
    if not self.animateMoving then
        return
    end

    self.animateMoving = false

    if self.lastAnimateDragX and self.lastAnimateDragY then
        MancerDB.animateBarOffset = {
            x = math.floor(self.lastAnimateDragX + 0.5),
            y = math.floor(self.lastAnimateDragY + 0.5),
        }
        self:ApplyAdvisorLayout()
    end
end

function FloatingText:StopZombieInteraction()
    if not self.zombieMoving then
        return
    end

    self.zombieMoving = false

    if self.lastZombieDragX and self.lastZombieDragY then
        MancerDB.zombieCounterOffset = {
            x = math.floor(self.lastZombieDragX + 0.5),
            y = math.floor(self.lastZombieDragY + 0.5),
        }
        self:ApplyAdvisorLayout()
    end
end

function FloatingText:StopProcInteraction()
    if not self.procMoving then
        return
    end

    self.procMoving = false

    if self.lastProcDragX and self.lastProcDragY then
        MancerDB.procBarOffset = {
            x = math.floor(self.lastProcDragX + 0.5),
            y = math.floor(self.lastProcDragY + 0.5),
        }
        self:ApplyAdvisorLayout()
    end
end

function FloatingText:UpdateAdvisorPositionFromCursor()
    local uiScale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / uiScale, cy / uiScale

    local parentX, parentY = self.anchor:GetCenter()
    local x = (cx + self.advisorDragOffsetX) - parentX
    local y = (cy + self.advisorDragOffsetY) - parentY

    self.lastAdvisorDragX = x
    self.lastAdvisorDragY = y

    self.advisorHandle:ClearAllPoints()
    self.advisorHandle:SetPoint("CENTER", self.anchor, "CENTER", x, y)
    self:LayoutAdvisorTexts()
end

function FloatingText:UpdateAnimatePositionFromCursor()
    local uiScale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / uiScale, cy / uiScale

    local parentX, parentY = self.anchor:GetCenter()
    local x = (cx + self.animateDragOffsetX) - parentX
    local y = (cy + self.animateDragOffsetY) - parentY

    self.lastAnimateDragX = x
    self.lastAnimateDragY = y

    self.animateHandle:ClearAllPoints()
    self.animateHandle:SetPoint("CENTER", self.anchor, "CENTER", x, y)
    if self.animateReady then
        if CanTouchAnimateStrip() then
            SafeProtectedCall(self.animateReady, "ClearAllPoints")
            SafeProtectedCall(self.animateReady, "SetPoint", "BOTTOM", self.animateHandle, "TOP", 0, 4)
        else
            self.pendingAnimateStripAnchor = true
        end
    end
end

function FloatingText:UpdateZombiePositionFromCursor()
    local uiScale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / uiScale, cy / uiScale

    local parentX, parentY = self.anchor:GetCenter()
    local x = (cx + self.zombieDragOffsetX) - parentX
    local y = (cy + self.zombieDragOffsetY) - parentY

    self.lastZombieDragX = x
    self.lastZombieDragY = y

    self.zombieHandle:ClearAllPoints()
    self.zombieHandle:SetPoint("CENTER", self.anchor, "CENTER", x, y)
    if self.zombieCounter then
        self.zombieCounter:ClearAllPoints()
        self.zombieCounter:SetPoint("BOTTOM", self.zombieHandle, "TOP", 0, 4)
    end
end

function FloatingText:UpdateProcPositionFromCursor()
    local uiScale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / uiScale, cy / uiScale

    local parentX, parentY = self.anchor:GetCenter()
    local x = (cx + self.procDragOffsetX) - parentX
    local y = (cy + self.procDragOffsetY) - parentY

    self.lastProcDragX = x
    self.lastProcDragY = y

    self.procHandle:ClearAllPoints()
    self.procHandle:SetPoint("CENTER", self.anchor, "CENTER", x, y)
    if self.procStrip then
        self.procStrip:ClearAllPoints()
        self.procStrip:SetPoint("CENTER", self.procHandle, "CENTER", 0, 0)
    end
end

function FloatingText:StopInteraction()
    if self.helpMoving then
        self:StopHelpInteraction()
    end
    if self.advisorMoving then
        self:StopAdvisorInteraction()
    end
    if self.animateMoving then
        self:StopAnimateInteraction()
    end
    if self.zombieMoving then
        self:StopZombieInteraction()
    end
    if self.procMoving then
        self:StopProcInteraction()
    end
    if self.barMoving then
        self:StopBarInteraction()
    end

    if not self.moving then
        return
    end

    self.moving = false

    local _, _, _, x, y = self.anchor:GetPoint()
    MancerDB.anchorX = x
    MancerDB.anchorY = y
end

function FloatingText:UpdatePositionFromCursor()
    local uiScale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / uiScale, cy / uiScale

    local parentX, parentY = UIParent:GetCenter()
    self.anchor:ClearAllPoints()
    self.anchor:SetPoint(
        "CENTER", UIParent, "CENTER",
        (cx + self.dragOffsetX) - parentX,
        (cy + self.dragOffsetY) - parentY
    )
end

function FloatingText:ApplyHelpBoxLayout()
    if not self.helpBox then
        return
    end
    local offset = MancerDB.moveHelpOffset or { x = 0, y = -160 }
    self.helpBox:ClearAllPoints()
    self.helpBox:SetPoint(
        "CENTER",
        UIParent,
        "CENTER",
        offset.x or 0,
        offset.y or -160
    )
end

function FloatingText:StopHelpInteraction()
    if not self.helpMoving then
        return
    end
    self.helpMoving = false
    local _, _, _, x, y = self.helpBox:GetPoint()
    MancerDB.moveHelpOffset = MancerDB.moveHelpOffset or {}
    MancerDB.moveHelpOffset.x = math.floor((x or 0) + 0.5)
    MancerDB.moveHelpOffset.y = math.floor((y or 0) + 0.5)
end

function FloatingText:UpdateHelpBoxFromCursor()
    if not self.helpBox then
        return
    end
    local uiScale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / uiScale, cy / uiScale
    local parentX, parentY = UIParent:GetCenter()
    self.helpBox:ClearAllPoints()
    self.helpBox:SetPoint(
        "CENTER",
        UIParent,
        "CENTER",
        (cx + self.helpDragOffsetX) - parentX,
        (cy + self.helpDragOffsetY) - parentY
    )
end

-- Kept for compatibility with older call sites.
function FloatingText:UpdateScaleLabel()
end

function FloatingText:UpdateScaleHandlePosition()
    -- HUD scale is mousewheel on + only (S hotspot removed).
    self.dragHandle:SetFrameLevel(self.anchor:GetFrameLevel() + 30)
end

function FloatingText:RefreshScaledLayout()
    self:ApplyScaleVisuals()
    if Mancer.ArcBars then
        Mancer.ArcBars:Layout()
        if Mancer.ArcBars.editMode then
            Mancer.ArcBars:ApplyBarVisual(Mancer.ArcBars.manaBar, MancerDB.manaColor)
            Mancer.ArcBars:ApplyBarVisual(Mancer.ArcBars.healthBar, MancerDB.healthColor)
        end
    end
    if not self.advisorMoving then
        self:ApplyAdvisorLayout()
    end
    if self.moveMode then
        self:ShowAdvisorPreview()
    end
end

function FloatingText:SetMoveMode(enabled)
    self.moveMode = enabled
    self.scaling = false
    self:StopInteraction()
    self:StopAdvisorInteraction()
    self:StopAnimateInteraction()
    self:StopZombieInteraction()
    self:StopProcInteraction()
    self:StopBarInteraction()
    self:StopHelpInteraction()
    self.dragHandle:EnableMouse(enabled)
    if self.barHandle then
        self.barHandle:EnableMouse(enabled)
    end
    if self.advisorHandle then
        -- Input goes through advisorHit; keep T as a visible marker only.
        self.advisorHandle:EnableMouse(false)
        self.advisorHandle:EnableMouseWheel(false)
    end
    if self.advisorHit then
        self.advisorHit:EnableMouse(enabled)
        self.advisorHit:EnableMouseWheel(enabled)
        if enabled then
            self.advisorHit:Show()
            self:LayoutAdvisorHit()
        else
            self.advisorHit:Hide()
        end
    end
    if self.animateHandle then
        local showAnimate = enabled and MancerDB.showAnimateBar ~= false
        self.animateHandle:EnableMouse(showAnimate)
        self.animateHandle:EnableMouseWheel(showAnimate)
    end
    if self.animateReady then
        if CanTouchAnimateStrip() then
            self.animateReady:EnableMouse(enabled and MancerDB.showAnimateBar ~= false)
            self.animateReady:EnableMouseWheel(enabled and MancerDB.showAnimateBar ~= false)
        end
    end
    for _, slot in ipairs(self.animateIconSlots or {}) do
        if slot.frame then
            -- In move mode, clear secure cast so A-handle drag/scale stays clean.
            local castEnabled = (not enabled) and MancerDB.showAnimateBar ~= false and slot.spellName and slot.spellName ~= ""
            if not self:ApplySecureAnimateBind(slot, slot.spellId, slot.spellName, castEnabled) then
                slot.pendingSpellBind = {
                    spellId = slot.spellId,
                    spellName = slot.spellName,
                }
                SetAnimateButtonMouse(slot.frame, false)
            elseif not castEnabled then
                SetAnimateButtonMouse(slot.frame, false)
            end
        end
    end
    if self.zombieHandle then
        local showZombie = enabled and MancerDB.showZombieCounter ~= false
        self.zombieHandle:EnableMouse(showZombie)
        self.zombieHandle:EnableMouseWheel(showZombie)
    end
    if self.zombieCounter then
        self.zombieCounter:EnableMouse(enabled and MancerDB.showZombieCounter ~= false)
        self.zombieCounter:EnableMouseWheel(enabled and MancerDB.showZombieCounter ~= false)
    end
    if self.procHandle then
        local showProc = enabled and MancerDB.showProcBar ~= false
        self.procHandle:EnableMouse(showProc)
        self.procHandle:EnableMouseWheel(showProc)
    end
    if self.procStrip then
        self.procStrip:EnableMouse(enabled and MancerDB.showProcBar ~= false)
        self.procStrip:EnableMouseWheel(enabled and MancerDB.showProcBar ~= false)
    end

    if enabled then
        self.dragHandle:Show()
        if self.barHandle then
            self.barHandle:Show()
        end
        self.advisorHandle:Show()
        if self.animateHandle then
            if MancerDB.showAnimateBar ~= false then
                self.animateHandle:Show()
            else
                self.animateHandle:Hide()
            end
        end
        if self.zombieHandle then
            if MancerDB.showZombieCounter ~= false then
                self.zombieHandle:Show()
            else
                self.zombieHandle:Hide()
            end
        end
        if self.procHandle then
            if MancerDB.showProcBar ~= false then
                self.procHandle:Show()
            else
                self.procHandle:Hide()
            end
        end
        if self.helpBox then
            self:ApplyHelpBoxLayout()
            self.helpBox:Show()
        end
        self.rateText:Hide()
        self:ApplyAdvisorLayout()
        self:ApplyBarHandleLayout()
        self:ShowAdvisorPreview()
        self:UpdateZombieCounter()
        self:UpdateProcStrip()
        self:ApplyScaleVisuals()
    else
        self.dragHandle:Hide()
        if self.barHandle then
            self.barHandle:Hide()
        end
        self.advisorHandle:Hide()
        if self.animateHandle then
            self.animateHandle:Hide()
        end
        if self.zombieHandle then
            self.zombieHandle:Hide()
        end
        if self.procHandle then
            self.procHandle:Hide()
        end
        if self.helpBox then
            self.helpBox:Hide()
        end
        self:HideArcPreview()
        self.advisorPreviewActive = false
        if not self.advisorDisplayActive then
            self:HideAdvisorAlert()
        else
            self:ShowAdvisorDisplay(self.advisorDisplayActive)
        end
        self:ApplyAdvisorLayout()
        self:UpdateZombieCounter()
        self:UpdateProcStrip()
        self:UpdateRateText(self.lastShownTick)
    end

    if Mancer.ArcBars then
        Mancer.ArcBars:ApplyConfig()
        Mancer.ArcBars:SetEditMode(enabled)
    end

    if Mancer.Options and Mancer.Options.UpdateMoveButton then
        Mancer.Options:UpdateMoveButton()
    end
end

function FloatingText:ApplyScaleVisuals()
    self:ApplyFonts()

    self:ShowArcPreview()
    self:UpdateScaleHandlePosition()
    self:ApplyBarHandleLayout()
end

function FloatingText:ShowArcPreview()
    self:EnsureArcGuides()

    for _, guide in ipairs(self.arcGuides) do
        local guideSize = self:GetGuideFontSize()
        Mancer.Util.ApplyFont(guide.mana, guideSize)
        Mancer.Util.ApplyFont(guide.health, guideSize)
        local mx, my = self:GetTickArcPosition(guide.progress, "mana")
        local hx, hy = self:GetTickArcPosition(guide.progress, "health")

        guide.mana:ClearAllPoints()
        guide.mana:SetPoint("CENTER", self.anchor, "CENTER", mx, my)
        guide.mana:Show()

        guide.health:ClearAllPoints()
        guide.health:SetPoint("CENTER", self.anchor, "CENTER", hx, hy)
        guide.health:Show()
    end
end

function FloatingText:HideArcPreview()
    if not self.arcGuides then
        return
    end
    for _, guide in ipairs(self.arcGuides) do
        guide.mana:Hide()
        guide.health:Hide()
    end
end

function FloatingText:ApplyConfig()
    local cfg = Mancer:GetConfig()
    self.anchor:ClearAllPoints()
    self.anchor:SetPoint("CENTER", UIParent, "CENTER", cfg.anchorX, cfg.anchorY)
    self:ApplyHelpBoxLayout()

    self:ApplyFonts()
    self:ApplyAdvisorLayout()
    self:UpdateZombieCounter()
    self:UpdateProcStrip()

    if self.moveMode then
        self:ApplyScaleVisuals()
    end

    if Mancer.ArcBars then
        Mancer.ArcBars:ApplyConfig()
    end

    self:UpdateRateText(self.lastShownTick)
end

function FloatingText:AcquireEntry()
    for _, entry in ipairs(self.pool) do
        if not entry.active then
            return entry
        end
    end
    return self.pool[1]
end

function FloatingText:ShowAdvisorDisplay(display, isPreview)
    if not display then
        return
    end

    local color = display.color or { 0.25, 0.95, 0.75 }
    local stanceText = display.stanceText
    local lfText = display.lfText
    if (not stanceText or stanceText == "") and (not lfText or lfText == "") and display.text and display.text ~= "" then
        -- Back-compat: single text with optional newline split.
        local stance, lf = string.match(display.text, "^(.-)\n(.*)$")
        if stance then
            stanceText = stance
            lfText = lf
        else
            if display.text:find("Life Force", 1, true) then
                lfText = display.text
            else
                stanceText = display.text
            end
        end
    end

    local animateIcons = display.animateIcons or {}
    local animateCount = #animateIcons
    local hasStance = stanceText and stanceText ~= ""
    local hasLf = lfText and lfText ~= ""
    local hasAnimates = animateCount > 0

    if not hasStance and not hasLf and not hasAnimates then
        -- Nothing to show — make sure prior stance/LF text is cleared.
        if not isPreview then
            self:HideAdvisorAlert()
        end
        return
    end

    if isPreview then
        self.advisorPreviewActive = true
    else
        self.advisorDisplayActive = display
    end

    if hasStance and self.advisorText then
        self:ApplyAdvisorFont(self.advisorText, 1)
        self.advisorText:SetText(stanceText)
        self.advisorText:SetTextColor(color[1], color[2], color[3], 1)
        self.advisorText:Show()
    elseif self.advisorText then
        self.advisorText:Hide()
        self.advisorText:SetText("")
    end

    if hasLf and self.advisorLfText then
        self:ApplyAdvisorFont(self.advisorLfText, 0.9)
        self.advisorLfText:SetText(lfText)
        self.advisorLfText:SetTextColor(color[1], color[2], color[3], 1)
        self.advisorLfText:Show()
    elseif self.advisorLfText then
        self.advisorLfText:Hide()
        self.advisorLfText:SetText("")
    end

    -- Center legacy icons stay off; Animates use the A strip.
    if self.advisorIcons then
        self.advisorIcons:Hide()
    end
    for _, slot in ipairs(self.advisorIconSlots or {}) do
        slot.frame:Hide()
    end
    self.advisorIconPulse = false

    if hasAnimates and self.animateReady then
        local anyReady = false
        local anyTimed = false
        local now = GetTime and GetTime() or 0
        for i, slot in ipairs(self.animateIconSlots) do
            local iconData = animateIcons[i]
            if iconData and iconData.texture then
                local wasReady = slot.ready == true
                self:ApplyAnimateIconState(slot, iconData)
                slot.ready = iconData.ready == true
                slot.active = iconData.active == true
                if slot.ready then
                    anyReady = true
                    -- CD just finished in combat → short stronger pulse so it reads clearly.
                    if not wasReady and UnitAffectingCombat and UnitAffectingCombat("player") then
                        slot.readyBurstUntil = now + ANIMATE_READY_BURST_SEC
                    end
                else
                    slot.readyBurstUntil = nil
                    local pulseTarget = AnimatePulseTarget(slot)
                    if pulseTarget then
                        pulseTarget:SetScale(1)
                    end
                end
                if slot.active or (iconData.remaining and iconData.remaining > 0.5) then
                    anyTimed = true
                end
                SetAnimateButtonShown(slot.frame, true)
            else
                slot.ready = false
                slot.active = false
                slot.readyBurstUntil = nil
                local pulseTarget = AnimatePulseTarget(slot)
                if pulseTarget then
                    pulseTarget:SetScale(1)
                end
                SetAnimateButtonShown(slot.frame, false)
            end
        end
        self:LayoutAnimateIcons(animateCount)
        -- Keep OnUpdate running while Animates are alive or on CD so timers tick.
        self.animateIconPulse = anyReady or anyTimed
        self:SetAnimateStripShown(true)
    else
        self.animateIconPulse = false
        self:SetAnimateStripShown(false)
        for _, slot in ipairs(self.animateIconSlots or {}) do
            slot.ready = false
            slot.readyBurstUntil = nil
            local pulseTarget = AnimatePulseTarget(slot)
            if pulseTarget then
                pulseTarget:SetScale(1)
            end
            SetAnimateButtonShown(slot.frame, false)
        end
    end

    self:ApplyAdvisorLayout()
end

function FloatingText:ShowAdvisorAlert(text, color)
    local stanceText, lfText
    if text and text:find("Life Force", 1, true) then
        lfText = text
    else
        stanceText = text
    end
    self:ShowAdvisorDisplay({
        stanceText = stanceText,
        lfText = lfText,
        text = text,
        icons = {},
        animateIcons = {},
        color = color or { 0.25, 0.95, 0.75 },
    })
end

function FloatingText:HideAdvisorAlert()
    self.advisorDisplayActive = nil
    self.advisorPreviewActive = false
    self.advisorIconPulse = false
    self.animateIconPulse = false
    self.iconPulseTimer = 0

    if self.advisorText then
        self.advisorText:Hide()
        self.advisorText:SetText("")
    end
    if self.advisorLfText then
        self.advisorLfText:Hide()
        self.advisorLfText:SetText("")
    end

    if self.advisorIcons then
        self.advisorIcons:Hide()
    end

    for _, slot in ipairs(self.advisorIconSlots or {}) do
        slot.frame:Hide()
    end

    if self.animateReady then
        self:SetAnimateStripShown(false)
    end
    for _, slot in ipairs(self.animateIconSlots or {}) do
        slot.ready = false
        slot.readyBurstUntil = nil
        local pulseTarget = AnimatePulseTarget(slot)
        if pulseTarget then
            pulseTarget:SetScale(1)
        end
        SetAnimateButtonShown(slot.frame, false)
    end
end

function FloatingText:ShowTick(text, color, side)
    local entry = self:AcquireEntry()

    entry.active = true
    entry.elapsed = 0
    entry.side = side or "mana"
    entry.jitter = (math.random() - 0.5) * 6 * self:GetScale()

    local fs = entry.fs
    fs:SetText(text)
    fs:SetTextColor(color[1], color[2], color[3], 1)

    local x, y = self:GetTickArcPosition(0, entry.side)
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", self.anchor, "CENTER", x + entry.jitter, y)
    fs:SetAlpha(1)
    fs:Show()
end

function FloatingText:UpdateRateText(lastTick)
    local cfg = Mancer:GetConfig()
    if not cfg.showRegenRate or self.moveMode then
        self.rateText:Hide()
        return
    end

    self.lastShownTick = lastTick

    if lastTick and lastTick > 0 then
        self.rateText:SetText(string.format("Last mana tick: +%d", lastTick))
    else
        local current, max = Mancer.Util.GetPlayerMana()
        if max > 0 and current < max then
            self.rateText:SetText(string.format("Mana %d/%d - waiting for tick...", current, max))
        elseif max > 0 then
            self.rateText:SetText(string.format("Mana %d/%d", current, max))
        else
            self.rateText:SetText("No mana bar detected")
        end
    end

    self.rateText:SetTextColor(cfg.rateColor[1], cfg.rateColor[2], cfg.rateColor[3], 0.9)
    self.rateText:Show()
end

function FloatingText:OnUpdate(elapsed)
    local busy = self.advisorIconPulse
        or self.animateIconPulse
        or self.procIconPulse
        or self.advisorMoving
        or self.animateMoving
        or self.zombieMoving
        or self.procMoving
        or self.barMoving
        or self.helpMoving
        or self.moving
    if not busy then
        for _, entry in ipairs(self.pool) do
            if entry.active then
                busy = true
                break
            end
        end
    end

    if not busy then
        return
    end

    if self.advisorIconPulse or self.animateIconPulse or self.procIconPulse then
        self:UpdateAdvisorIconPulse(elapsed)
    end

    if self.advisorMoving then
        if IsLeftMouseDown() then
            self:UpdateAdvisorPositionFromCursor()
        else
            self:StopAdvisorInteraction()
        end
    elseif self.animateMoving then
        if IsLeftMouseDown() then
            self:UpdateAnimatePositionFromCursor()
        else
            self:StopAnimateInteraction()
        end
    elseif self.zombieMoving then
        if IsLeftMouseDown() then
            self:UpdateZombiePositionFromCursor()
        else
            self:StopZombieInteraction()
        end
    elseif self.procMoving then
        if IsLeftMouseDown() then
            self:UpdateProcPositionFromCursor()
        else
            self:StopProcInteraction()
        end
    elseif self.barMoving then
        if IsLeftMouseDown() then
            self:UpdateBarPositionFromCursor()
        else
            self:StopBarInteraction()
        end
    elseif self.helpMoving then
        if IsLeftMouseDown() then
            self:UpdateHelpBoxFromCursor()
        else
            self:StopHelpInteraction()
        end
    elseif self.moving then
        if IsLeftMouseDown() then
            self:UpdatePositionFromCursor()
        else
            self:StopInteraction()
        end
    end

    for _, entry in ipairs(self.pool) do
        if entry.active then
            entry.elapsed = entry.elapsed + elapsed
            local progress = entry.elapsed / TICK_DURATION

            if progress >= 1 then
                entry.active = false
                entry.fs:Hide()
            else
                local x, y = self:GetTickArcPosition(progress, entry.side)
                local alpha = 1 - (progress * progress)
                entry.fs:ClearAllPoints()
                entry.fs:SetPoint("CENTER", self.anchor, "CENTER", x + entry.jitter, y)
                entry.fs:SetAlpha(alpha)
            end
        end
    end
end

-- Arc resource bars: vine pattern with vertical fill/drain (WeakAuras-style)
Mancer.ArcBarsModule = {}
local ArcBars = Mancer.ArcBarsModule

local FILL_SPEED = 9
local HANDLE_SIZE = 10
local UNIFIED_HANDLE_SIZE = 18
local MIN_BAR_SCALE = 0.25
local MAX_BAR_SCALE = 3.0
local MAX_BAR_OFFSET = 80
local DRAG_SENS = 0.006
local TEX_INSET = 0.06
local PLACEHOLDER_TEX = "Interface\\Buttons\\WHITE8X8"
local FLUSH_TEX = "Interface\\Icons\\INV_Misc_QuestionMark"
local BAR_WHEEL_STEP = 0.08

local function ForceSetTexture(tex, path)
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetTexture(FLUSH_TEX)
    tex:SetTexture(path)
end

local function ProbeTexture(tex, path)
    ForceSetTexture(tex, path)
    local loaded = tex:GetTexture()
    if not loaded then
        return false
    end
    if type(loaded) == "string" then
        local base = path:match("([^\\]+)%.?tga$") or path:match("[^\\]+$")
        if base and not loaded:find(base, 1, true) then
            return false
        end
    end
    return true
end

local HANDLE_DEFS = {
    tl = { "TOPLEFT", "TOPLEFT", -5, 5 },
    t = { "TOP", "TOP", 0, 5 },
    tr = { "TOPRIGHT", "TOPRIGHT", 5, 5 },
    r = { "RIGHT", "RIGHT", 5, 0 },
    br = { "BOTTOMRIGHT", "BOTTOMRIGHT", 5, -5 },
    b = { "BOTTOM", "BOTTOM", 0, -5 },
    bl = { "BOTTOMLEFT", "BOTTOMLEFT", -5, -5 },
    l = { "LEFT", "LEFT", -5, 0 },
}

local function IsLeftMouseDown()
    return IsMouseButtonDown and IsMouseButtonDown("LeftButton")
end

local function ClampScale(value)
    return math.max(MIN_BAR_SCALE, math.min(MAX_BAR_SCALE, value))
end

local function ClampOffset(value)
    return math.max(-MAX_BAR_OFFSET, math.min(MAX_BAR_OFFSET, value or 0))
end

local function BindBarLayers(bar, texturePath)
    texturePath = Mancer.NormalizeBarTexturePath(texturePath)
    local generation = Mancer.ArcBars and Mancer.ArcBars.textureBindGeneration or 0
    local force = bar.bindGeneration ~= generation
        or bar.boundMetaPath ~= texturePath
        or not bar.loadPath

    if not force then
        return bar.loadPath
    end

    local chosen
    for _, path in ipairs(Mancer.GetBarTextureLoadPaths(texturePath)) do
        if ProbeTexture(bar.background, path) then
            chosen = path
            break
        end
    end

    if not chosen then
        bar.boundMetaPath = texturePath
        bar.loadPath = nil
        bar.bindGeneration = generation
        bar.background:Hide()
        bar.foreground:Hide()
        bar.glow:Hide()
        return nil
    end

    ForceSetTexture(bar.foreground, chosen)
    ForceSetTexture(bar.glow, chosen)
    bar.boundMetaPath = texturePath
    bar.loadPath = chosen
    bar.bindGeneration = generation
    return chosen
end

local function GetHorizontalBounds(bar, texturePath)
    if Mancer.UsesSplitBarTexture(texturePath) then
        if bar.side == "mana" then
            return 0, 0.5, true, false
        end
        return 0.5, 1, false, true
    end

    return TEX_INSET, 1 - TEX_INSET, true, true
end

local function SetVerticalSliceTexCoord(texture, bar, texturePath, vTop, vBottom)
    vTop = math.max(0, math.min(1, vTop))
    vBottom = math.max(0, math.min(1, vBottom))
    if vBottom <= vTop then
        texture:Hide()
        return false
    end

    local uMin, uMax, insetOuterLeft, insetOuterRight = GetHorizontalBounds(bar, texturePath)
    local uSpan = uMax - uMin
    if insetOuterLeft then
        uMin = uMin + (uSpan * TEX_INSET)
    end
    if insetOuterRight then
        uMax = uMax - (uSpan * TEX_INSET)
    end

    local flipH = bar.flipH and not Mancer.UsesSplitBarTexture(texturePath)
    if flipH then
        texture:SetTexCoord(uMax, uMin, vTop, vBottom)
    else
        texture:SetTexCoord(uMin, uMax, vTop, vBottom)
    end
    return true
end

local function ApplyVerticalFill(background, foreground, bar, texturePath, progress, color)
    progress = math.max(0, math.min(1, progress or 0))
    local barHeight = bar:GetHeight()
    if barHeight <= 0 then
        return
    end

    if progress >= 0.999 then
        foreground:Show()
        foreground:ClearAllPoints()
        foreground:SetAllPoints(bar)
        SetVerticalSliceTexCoord(foreground, bar, texturePath, 0, 1)
        foreground:SetVertexColor(color[1], color[2], color[3], 1)
        background:Hide()
        return
    end

    if progress <= 0.001 then
        background:Show()
        background:ClearAllPoints()
        background:SetAllPoints(bar)
        SetVerticalSliceTexCoord(background, bar, texturePath, 0, 1)
        background:SetVertexColor(0.45, 0.45, 0.45, 0.55)
        foreground:Hide()
        return
    end

    local fillHeight = barHeight * progress
    if fillHeight < 1 then
        fillHeight = 1
    end
    if fillHeight > barHeight then
        fillHeight = barHeight
    end

    local emptyHeight = barHeight - fillHeight
    local seamV = 1 - (fillHeight / barHeight)

    foreground:Show()
    foreground:ClearAllPoints()
    foreground:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT")
    foreground:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
    foreground:SetHeight(fillHeight)
    SetVerticalSliceTexCoord(foreground, bar, texturePath, seamV, 1)
    foreground:SetVertexColor(color[1], color[2], color[3], 1)

    background:Show()
    background:ClearAllPoints()
    background:SetPoint("TOPLEFT", bar, "TOPLEFT")
    background:SetPoint("TOPRIGHT", bar, "TOPRIGHT")
    background:SetHeight(emptyHeight)
    if SetVerticalSliceTexCoord(background, bar, texturePath, 0, seamV) then
        background:SetVertexColor(0.45, 0.45, 0.45, 0.55)
    else
        background:Hide()
    end
end

local function CreateProgressBar(parent)
    local bar = CreateFrame("Frame", nil, parent)

    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetTexture(PLACEHOLDER_TEX)
    background:SetBlendMode("BLEND")
    background:Hide()

    local foreground = bar:CreateTexture(nil, "ARTWORK")
    foreground:SetTexture(PLACEHOLDER_TEX)
    foreground:SetBlendMode("BLEND")
    foreground:Hide()

    local glow = bar:CreateTexture(nil, "OVERLAY")
    glow:SetTexture(PLACEHOLDER_TEX)
    glow:SetBlendMode("ADD")
    glow:Hide()

    bar.background = background
    bar.foreground = foreground
    bar.glow = glow
    bar.targetPercent = 0
    bar.displayPercent = 0
    bar.rotation = 0
    bar.flipH = false
    return bar
end

local function CreateHandleTexture(parent)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    tex:SetVertexColor(1, 0.75, 0.1, 0.95)
    return tex
end

function ArcBars:GetTransform(_side)
    MancerDB.barTransform = MancerDB.barTransform or {}
    local unified = MancerDB.barTransform.unified
    if not unified then
        local mana = MancerDB.barTransform.mana
        unified = {
            width = (mana and mana.width) or 1.0,
            height = (mana and mana.height) or 1.0,
            offsetX = (mana and mana.offsetX) or 0,
            offsetY = (mana and mana.offsetY) or 0,
        }
        MancerDB.barTransform.unified = unified
    end

    -- Width/height stay independent for 8-point handles. scale is display/wheel only.
    unified.width = ClampScale(tonumber(unified.width) or 1)
    unified.height = ClampScale(tonumber(unified.height) or 1)
    unified.scale = (unified.width + unified.height) * 0.5
    unified.offsetX = ClampOffset(unified.offsetX)
    unified.offsetY = ClampOffset(unified.offsetY)
    return unified
end

function ArcBars:AdjustBarScale(delta)
    local t = self:GetTransform("unified")
    local step = (delta or 0) * BAR_WHEEL_STEP
    local scale = ClampScale(((t.width or 1) + (t.height or 1)) * 0.5 + step)
    t.scale = scale
    t.width = scale
    t.height = scale
    self:Layout()
    self:ApplyBarVisual(self.manaBar, self.manaBar.color or MancerDB.manaColor)
    self:ApplyBarVisual(self.healthBar, self.healthBar.color or MancerDB.healthColor)
    if Mancer.FloatingText and Mancer.FloatingText.ApplyBarHandleLayout then
        Mancer.FloatingText:ApplyBarHandleLayout()
    end
    if Mancer.FloatingText and Mancer.FloatingText.moveMode and Mancer.FloatingText.ShowArcPreview then
        Mancer.FloatingText:ShowArcPreview()
    end
end

function ArcBars:CreateUnifiedTransformEditor()
    local box = CreateFrame("Frame", nil, self.frame)
    box:EnableMouse(false)
    box:EnableMouseWheel(false)
    box:Hide()
    box:SetFrameStrata("MEDIUM")

    local outline = box:CreateTexture(nil, "BACKGROUND")
    outline:SetAllPoints()
    outline:SetTexture("Interface\\Buttons\\WHITE8X8")
    outline:SetVertexColor(1, 0.85, 0.2, 0.22)

    self.unifiedBox = box
    self.unifiedHandles = {}

    for id, def in pairs(HANDLE_DEFS) do
        local handleId = id
        local handle = CreateFrame("Frame", nil, box)
        handle:SetSize(UNIFIED_HANDLE_SIZE, UNIFIED_HANDLE_SIZE)
        handle:SetPoint(def[1], box, def[2], def[3], def[4])
        handle:EnableMouse(false)
        handle:SetFrameLevel(box:GetFrameLevel() + 10)
        CreateHandleTexture(handle)

        handle.handleId = handleId
        handle:SetScript("OnMouseDown", function()
            if not self.editMode then
                return
            end
            if Mancer.FloatingText then
                Mancer.FloatingText:StopInteraction()
                Mancer.FloatingText:StopAdvisorInteraction()
                Mancer.FloatingText:StopAnimateInteraction()
                Mancer.FloatingText:StopBarInteraction()
            end
            local uiScale = UIParent:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            cx, cy = cx / uiScale, cy / uiScale
            local t = self:GetTransform("unified")
            self.activeHandle = {
                id = handleId,
                startCX = cx,
                startCY = cy,
                startW = t.width,
                startH = t.height,
                startX = t.offsetX,
                startY = t.offsetY,
            }
            self:UpdateHandleDrag()
        end)

        self.unifiedHandles[handleId] = handle
    end
end

function ArcBars:UpdateUnifiedEditorBounds()
    if not self.unifiedBox then
        return
    end

    self.unifiedBox:ClearAllPoints()
    self.unifiedBox:SetPoint("TOPLEFT", self.manaBar, "TOPLEFT", -8, 8)
    self.unifiedBox:SetPoint("BOTTOMRIGHT", self.healthBar, "BOTTOMRIGHT", 8, -8)
    if Mancer.FloatingText and Mancer.FloatingText.ApplyBarHandleLayout then
        Mancer.FloatingText:ApplyBarHandleLayout()
    end
end

function ArcBars:CreateTransformEditor(_bar, _side)
    -- Per-bar editors replaced by unified 8-point editor.
end

function ArcBars:UpdateHandleDrag()
    local active = self.activeHandle
    if not active then
        return
    end

    local uiScale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / uiScale, cy / uiScale
    local dx = cx - active.startCX
    local dy = cy - active.startCY
    local t = self:GetTransform("unified")
    local id = active.id

    if id == "br" then
        t.width = ClampScale(active.startW + dx * DRAG_SENS)
        t.height = ClampScale(active.startH - dy * DRAG_SENS)
    elseif id == "bl" then
        t.width = ClampScale(active.startW - dx * DRAG_SENS)
        t.height = ClampScale(active.startH - dy * DRAG_SENS)
    elseif id == "tr" then
        t.width = ClampScale(active.startW + dx * DRAG_SENS)
        t.height = ClampScale(active.startH + dy * DRAG_SENS)
    elseif id == "tl" then
        t.width = ClampScale(active.startW - dx * DRAG_SENS)
        t.height = ClampScale(active.startH + dy * DRAG_SENS)
    elseif id == "r" then
        t.width = ClampScale(active.startW + dx * DRAG_SENS)
    elseif id == "l" then
        t.width = ClampScale(active.startW - dx * DRAG_SENS)
    elseif id == "t" then
        t.height = ClampScale(active.startH + dy * DRAG_SENS)
    elseif id == "b" then
        t.height = ClampScale(active.startH - dy * DRAG_SENS)
    end

    t.scale = (t.width + t.height) * 0.5
    self:Layout()
    self:ApplyBarVisual(self.manaBar, self.manaBar.color or MancerDB.manaColor)
    self:ApplyBarVisual(self.healthBar, self.healthBar.color or MancerDB.healthColor)
    if Mancer.FloatingText and Mancer.FloatingText.moveMode and Mancer.FloatingText.ShowArcPreview then
        Mancer.FloatingText:ShowArcPreview()
    end
end

function ArcBars:SetEditMode(enabled)
    self.editMode = enabled
    if not enabled then
        self.activeHandle = nil
    end

    -- Stay on MEDIUM so FloatingText handles (+/B/T/A) remain clickable.
    self.frame:SetFrameStrata("MEDIUM")
    self.frame:SetFrameLevel(enabled and 12 or 8)

    if self.unifiedBox then
        self.unifiedBox:SetShown(enabled)
        self.unifiedBox:EnableMouse(false)
        self.unifiedBox:SetFrameLevel(self.frame:GetFrameLevel() + 1)
        for _, handle in pairs(self.unifiedHandles or {}) do
            handle:EnableMouse(enabled)
            if enabled then
                handle:SetFrameLevel(self.unifiedBox:GetFrameLevel() + 5)
            end
        end
    end

    if enabled then
        self.manaBar.targetPercent = 0.75
        self.manaBar.displayPercent = 0.75
        self.healthBar.targetPercent = 0.75
        self.healthBar.displayPercent = 0.75
        self:Layout()
        self:ApplyBarVisual(self.manaBar, MancerDB.manaColor)
        self:ApplyBarVisual(self.healthBar, MancerDB.healthColor)
        if Mancer.FloatingText and Mancer.FloatingText.ApplyBarHandleLayout then
            Mancer.FloatingText:ApplyBarHandleLayout()
        end
    else
        self:UpdateValues()
    end
end

function ArcBars:ApplyBarTextures(path)
    path = Mancer.NormalizeBarTexturePath(path)
    self.barTexture = path
    self.barTextureMeta = path
    self.textureBindGeneration = (self.textureBindGeneration or 0) + 1

    for _, bar in ipairs({ self.manaBar, self.healthBar }) do
        bar.texturePath = path
        bar.boundMetaPath = nil
        bar.loadPath = nil
        bar.bindGeneration = nil
    end
end

function ArcBars:RefreshBarVisuals()
    local manaColor = self.manaBar.color or MancerDB.manaColor
    local healthColor = self.healthBar.color or MancerDB.healthColor
    self:ApplyBarVisual(self.manaBar, manaColor)
    self:ApplyBarVisual(self.healthBar, healthColor)
end

function ArcBars:New()
    local self = setmetatable({}, { __index = ArcBars })

    self.editMode = false
    self.frame = CreateFrame("Frame", "MancerArcBars", UIParent)
    self.frame:SetSize(1, 1)
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    self.frame:SetFrameStrata("MEDIUM")
    self.frame:SetFrameLevel(16)

    self.manaBar = CreateProgressBar(self.frame)
    self.manaBar.side = "mana"

    self.healthBar = CreateProgressBar(self.frame)
    self.healthBar.side = "health"

    self:ApplyBarTextures(MancerDB and MancerDB.barTexture)
    self:CreateUnifiedTransformEditor()

    self.frame:SetScript("OnUpdate", function(_, elapsed)
        self.pollTimer = (self.pollTimer or 0) + elapsed
        if self.pollTimer >= 0.15 and not self.editMode then
            self.pollTimer = 0
            self:UpdateValues()
        end
        if not self.editMode then
            self:AnimateBars(elapsed)
        end
        if self.editMode and self.activeHandle then
            if IsLeftMouseDown() then
                self:UpdateHandleDrag()
            else
                self.activeHandle = nil
            end
        end
    end)

    return self
end

function ArcBars:GetScale()
    return MancerDB.scale or 1
end

function ArcBars:GetRadius()
    return (MancerDB.arcRadius or 65) * self:GetScale()
end

function ArcBars:GetSideFlipH(side)
    local metaPath = self.barTextureMeta or self.barTexture
    if Mancer.UsesSplitBarTexture(metaPath) then
        return false
    end
    return side == "mana"
end

function ArcBars:LayoutBar(bar, side)
    local radius = self:GetRadius()
    local cx, cy, height, width, rotation = Mancer.Util.GetArcBounds(side, radius)
    local barHeight = math.max(56, math.floor(height + 0.5))
    local barWidth = math.max(20, math.floor(width + 0.5))
    local t = self:GetTransform(side)

    bar:SetSize(
        math.max(1, math.floor(barWidth * t.width + 0.5)),
        math.max(1, math.floor(barHeight * t.height + 0.5))
    )
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", self.frame, "CENTER", cx + t.offsetX, cy + t.offsetY)
    bar.rotation = rotation
    bar.flipH = self:GetSideFlipH(side)

    bar:SetScale(1, 1)
    if bar.SetRotation then
        pcall(function()
            bar:SetRotation(0)
        end)
    end
end

function ArcBars:Layout()
    if Mancer.FloatingText and Mancer.FloatingText.anchor then
        self.frame:ClearAllPoints()
        self.frame:SetPoint("CENTER", Mancer.FloatingText.anchor, "CENTER", 0, 0)
    end

    self:LayoutBar(self.manaBar, "mana")
    self:LayoutBar(self.healthBar, "health")
    self:UpdateUnifiedEditorBounds()
end

function ArcBars:ApplyBarVisual(bar, color)
    local percent = math.max(0, math.min(1, bar.displayPercent))
    local metaPath = bar.texturePath or self.barTextureMeta or self.barTexture

    if not BindBarLayers(bar, metaPath) then
        return
    end

    ApplyVerticalFill(bar.background, bar.foreground, bar, metaPath, percent, color)
    bar.glow:Hide()
end

function ArcBars:AnimateBars(elapsed)
    for _, bar in ipairs({ self.manaBar, self.healthBar }) do
        if bar:IsShown() then
            local diff = bar.targetPercent - bar.displayPercent
            if math.abs(diff) > 0.002 then
                if math.abs(diff) > 0.3 then
                    bar.displayPercent = bar.targetPercent
                else
                    bar.displayPercent = bar.displayPercent + (diff * math.min(1, elapsed * FILL_SPEED))
                end
                self:ApplyBarVisual(bar, bar.color or { 1, 1, 1 })
            end
        end
    end
end

function ArcBars:UpdateBar(bar, current, max, color, enabled)
    if not enabled or max <= 0 then
        bar:Hide()
        bar.targetPercent = 0
        bar.displayPercent = 0
        return
    end

    bar:Show()
    bar.color = color
    bar.targetPercent = math.max(0, math.min(1, current / max))

    if bar.displayPercent == 0 and bar.targetPercent > 0 then
        bar.displayPercent = bar.targetPercent
    elseif math.abs(bar.targetPercent - bar.displayPercent) > 0.3 then
        bar.displayPercent = bar.targetPercent
    end

    self:ApplyBarVisual(bar, color)
end

function ArcBars:UpdateValues()
    local cfg = Mancer:GetConfig()
    local mana, maxMana = Mancer.Util.GetPlayerMana()
    local health, maxHealth = Mancer.Util.GetPlayerHealth()

    self:UpdateBar(self.manaBar, mana, maxMana, cfg.manaColor, cfg.showManaBar and Mancer.Util.HasManaBar())
    self:UpdateBar(self.healthBar, health, maxHealth, cfg.healthColor, cfg.showHealthBar)
end

function ArcBars:ApplyConfig()
    self.frame:Show()
    self:Layout()
    self:ApplyBarTextures(MancerDB.barTexture)
    self:UpdateValues()
    self:RefreshBarVisuals()
    if self.editMode then
        self:SetEditMode(true)
    end
end
