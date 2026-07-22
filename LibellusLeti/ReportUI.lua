Mancer.ReportUI = Mancer.ReportUI or {}
local ReportUI = Mancer.ReportUI

local function GetUI()
    return Mancer.UI
end

ReportUI.windows = ReportUI.windows or {}

local DEFAULT_LAYOUT = {
    minionStatus = { width = 520, height = 460, point = "CENTER", x = -220, y = 100 },
    minionStance = { width = 460, height = 220, point = "CENTER", x = 220, y = 180 },
    minionHelp = { width = 480, height = 320, point = "CENTER", x = 0, y = 0 },
    minionLifeForce = { width = 500, height = 420, point = "CENTER", x = 0, y = 120 },
    minionDps = { width = 500, height = 400, point = "CENTER", x = 240, y = 80 },
    minionCombo = { width = 480, height = 320, point = "CENTER", x = -240, y = 80 },
    minionStAoe = { width = 520, height = 520, point = "CENTER", x = -200, y = 40 },
    minionMeasure = { width = 480, height = 300, point = "CENTER", x = 200, y = 40 },
    minionInspect = { width = 560, height = 520, point = "CENTER", x = 0, y = -20 },
    paperMath = { width = 560, height = 520, point = "CENTER", x = 0, y = -20 },
    buffPicks = { width = 500, height = 360, point = "CENTER", x = 180, y = 40 },
    notice = { width = 420, height = 180, point = "CENTER", x = 0, y = 0 },
}

local function GetLayout(id)
    MancerDB.reports = MancerDB.reports or {}
    local saved = MancerDB.reports[id]
    local defaults = DEFAULT_LAYOUT[id] or { width = 480, height = 400, point = "CENTER", x = 0, y = 0 }
    return {
        width = (saved and saved.width) or defaults.width,
        height = (saved and saved.height) or defaults.height,
        point = (saved and saved.point) or defaults.point,
        x = (saved and saved.x) or defaults.x,
        y = (saved and saved.y) or defaults.y,
    }
end

local function SavePosition(id, frame)
    MancerDB.reports = MancerDB.reports or {}
    local point, _, _, x, y = frame:GetPoint(1)
    MancerDB.reports[id] = MancerDB.reports[id] or {}
    MancerDB.reports[id].point = point
    MancerDB.reports[id].x = x
    MancerDB.reports[id].y = y
end

local function EstimateTextHeight(text, width)
    local lines = 0
    for _ in string.gmatch(text .. "\n", "([^\n]*)\n") do
        lines = lines + 1
    end
    local _, fontSize = ChatFontNormal:GetFont()
    fontSize = fontSize or 14
    return math.max(24, (lines * (fontSize + 2)) + 8)
end

local function UpdateContentHeight(frame)
    local content = frame.content
    local scrollChild = frame.scrollChild
    local scroll = frame.scroll
    if not content or not scrollChild or not scroll then
        return
    end

    local width = math.max(200, scroll:GetWidth() - 8)
    content:SetWidth(width)
    scrollChild:SetWidth(width)

    local textHeight = EstimateTextHeight(content:GetText() or "", width)
    scrollChild:SetHeight(math.max(textHeight + 8, scroll:GetHeight()))
end

function ReportUI:GetWindow(id)
    local existing = self.windows[id]
    if existing and existing.scrollChild and existing.content then
        return existing
    end
    if existing then
        existing:Hide()
        self.windows[id] = nil
    end

    local layout = GetLayout(id)
    local frameName = "MancerReport_" .. id
    local frame = CreateFrame("Frame", frameName, UIParent)
    frame:SetSize(layout.width, layout.height)
    frame:SetPoint(layout.point, UIParent, layout.point, layout.x, layout.y)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f)
        f:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        SavePosition(id, f)
    end)
    frame:SetFrameStrata("DIALOG")
    local ui = GetUI()
    if ui and ui.SkinFrame then
        ui.SkinFrame(frame)
    end
    frame:Hide()

    frame.reportId = id

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -10)
    if ui and ui.StyleTitle then
        ui.StyleTitle(title)
    end
    frame.title = title

    if ui and ui.CreateCloseButton then
        ui.CreateCloseButton(frame)
    else
        local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
        closeBtn:SetScript("OnClick", function()
            frame:Hide()
        end)
    end

    local refreshBtn
    if ui and ui.CreateButton then
        refreshBtn = ui.CreateButton(frame, "Refresh", 72, 22)
        refreshBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -6)
    else
        refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        refreshBtn:SetSize(72, 22)
        refreshBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -6)
        refreshBtn:SetText("Refresh")
    end
    refreshBtn:SetScript("OnClick", function()
        if frame.refreshFn then
            ReportUI:ShowCapture(id, frame.titleText or (Mancer.DISPLAY_NAME or "Libellus Leti"), frame.refreshFn, frame.customWidth, frame.customHeight)
        end
    end)
    frame.refreshBtn = refreshBtn

    local scroll = CreateFrame("ScrollFrame", frameName .. "Scroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -36)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 14)
    frame.scroll = scroll

    local scrollChild = CreateFrame("Frame", frameName .. "ScrollChild", scroll)
    scrollChild:SetSize(400, 400)
    scroll:SetScrollChild(scrollChild)
    frame.scrollChild = scrollChild

    local content = scrollChild:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
    content:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, -4)
    content:SetJustifyH("LEFT")
    content:SetJustifyV("TOP")
    if ui and ui.Colors and ui.Colors.title then
        local c = ui.Colors.title
        content:SetTextColor(c[1], c[2], c[3], 0.92)
    end
    frame.content = content

    if UISpecialFrames then
        tinsert(UISpecialFrames, frameName)
    end

    self.windows[id] = frame
    return frame
end

function ReportUI:Show(id, title, lines, width, height)
    local frame = self:GetWindow(id)
    local layout = GetLayout(id)

    frame.titleText = title
    frame.title:SetText(title or (Mancer.DISPLAY_NAME or "Libellus Leti"))
    frame.customWidth = width
    frame.customHeight = height

    if width and height then
        frame:SetSize(width, height)
    else
        frame:SetSize(layout.width, layout.height)
    end

    local text = table.concat(lines or {}, "\n")
    if text == "" then
        text = "(empty report)"
    end

    frame.content:SetText(text)
    UpdateContentHeight(frame)
    frame:Show()
end

function ReportUI:ShowCapture(id, title, fn, width, height)
    if type(fn) ~= "function" then
        return
    end

    local frame = self:GetWindow(id)
    frame.refreshFn = fn

    local lines = {}
    Mancer.reportSink = lines
    local ok, err = pcall(fn)
    Mancer.reportSink = nil

    if not ok then
        self:Show("notice", Mancer.DISPLAY_NAME or "Libellus Leti", { "Report failed: " .. tostring(err) })
        return
    end

    self:Show(id, title, lines, width, height)
end

function Mancer.ShowReport(id, title, fn, width, height)
    if Mancer.ReportUI then
        Mancer.ReportUI:ShowCapture(id, title, fn, width, height)
    elseif fn then
        fn()
    end
end
