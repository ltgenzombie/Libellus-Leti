Mancer.MinimapButtonModule = {}
local MinimapButton = Mancer.MinimapButtonModule

-- Round Necromancer class icon (AtlasInfo: class-round-necromancer).
local ICON_PATH = "Interface\\Glues\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES-ROUND"
local ICON_TEX_COORD = { 0.5, 0.625, 0.25, 0.5 } -- left, right, top, bottom
local ICON_ATLAS = "class-round-necromancer"
local DEFAULT_ANGLE = 220

local function GetConfig()
    MancerDB.minimap = MancerDB.minimap or {}
    if MancerDB.minimap.hide == nil then
        MancerDB.minimap.hide = false
    end
    if MancerDB.minimap.angle == nil then
        MancerDB.minimap.angle = DEFAULT_ANGLE
    end
    return MancerDB.minimap
end

local function IsHidden()
    return GetConfig().hide == true
end

local function GetRadius()
    return (Minimap:GetWidth() / 2) + 10
end

function MinimapButton:UpdatePosition()
    if not self.button then
        return
    end

    local cfg = GetConfig()
    local angleRad = math.rad(cfg.angle or DEFAULT_ANGLE)
    local radius = GetRadius()
    local x = math.cos(angleRad) * radius
    local y = math.sin(angleRad) * radius
    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function MinimapButton:ApplyVisibility()
    if not self.button then
        return
    end
    if IsHidden() then
        self.button:Hide()
    else
        self.button:Show()
        self:UpdatePosition()
    end
end

function MinimapButton:SetHidden(hide)
    local cfg = GetConfig()
    cfg.hide = hide and true or false
    self:ApplyVisibility()

    if Mancer.Hub then
        Mancer.Hub:SyncControls()
    end
end

local function OpenHub()
    if Mancer.OpenHub then
        Mancer.OpenHub()
    elseif Mancer.Options then
        Mancer.Options:Open()
    end
end

local function OpenDisplay()
    if Mancer.Hub and Mancer.Hub.OpenDisplaySettings then
        Mancer.Hub:OpenDisplaySettings()
    elseif Mancer.Options then
        Mancer.Options:Open()
    end
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale

    local cfg = GetConfig()
    cfg.angle = math.deg(math.atan2(py - my, px - mx))
    MinimapButton:UpdatePosition()
end

local function ShowMenu(anchor)
    if not EasyMenu then
        OpenDisplay()
        return
    end

    if not MinimapButton.menuFrame then
        MinimapButton.menuFrame = CreateFrame("Frame", "MancerMinimapMenu", UIParent, "UIDropDownMenuTemplate")
    end

    local menu = {
        { text = Mancer.DISPLAY_NAME or "Libellus Leti", isTitle = true, notCheckable = true },
        {
            text = "Open Hub",
            notCheckable = true,
            func = function()
                OpenHub()
            end,
        },
        {
            text = "Display",
            notCheckable = true,
            func = function()
                OpenDisplay()
            end,
        },
        {
            text = "Hide minimap button",
            notCheckable = true,
            func = function()
                MinimapButton:SetHidden(true)
            end,
        },
    }
    EasyMenu(menu, MinimapButton.menuFrame, anchor or "cursor", 0, 0, "MENU")
end

local function CreateButton()
    local button = CreateFrame("Button", "MancerMinimapButton", Minimap)
    button:SetSize(31, 31)
    -- Stay on the Minimap's strata so bags/windows paint above the icon.
    local strata = (Minimap.GetFrameStrata and Minimap:GetFrameStrata()) or "BACKGROUND"
    button:SetFrameStrata(strata)
    button:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZOOMIN-ToggleHighlight")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:Show()

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetPoint("TOPLEFT")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 7, -6)
    -- Prefer explicit UV crop so the packed CLASSES-ROUND sheet always shows Necromancer.
    icon:SetTexture(ICON_PATH)
    icon:SetTexCoord(unpack(ICON_TEX_COORD))
    if not icon:GetTexture() and icon.SetAtlas then
        icon:SetAtlas(ICON_ATLAS)
    end

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(Mancer.DISPLAY_NAME or "Libellus Leti", 1, 1, 1)
        GameTooltip:AddLine("Left-click: Open Hub", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: Menu", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag: Move icon", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            ShowMenu(self)
        else
            OpenHub()
        end
    end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", OnDragUpdate)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    return button
end

function MinimapButton:Init()
    if self.button then
        self:ApplyVisibility()
        return
    end
    if not Minimap then
        return
    end

    local ok, err = pcall(function()
        self.button = CreateButton()
        self:ApplyVisibility()
    end)
    if not ok and Mancer.Hub then
        Mancer.Hub:Notify("Minimap button failed: " .. tostring(err))
    end
end

local retryFrame = CreateFrame("Frame")
retryFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
retryFrame:SetScript("OnEvent", function()
    if Mancer.MinimapButtonModule and not Mancer.MinimapButtonModule.button then
        Mancer.MinimapButtonModule:Init()
    elseif Mancer.MinimapButtonModule then
        Mancer.MinimapButtonModule:ApplyVisibility()
    end
end)
