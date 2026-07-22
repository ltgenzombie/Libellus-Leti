Mancer.Hub = Mancer.Hub or {}
local Hub = Mancer.Hub

local function GetUI()
    return Mancer.UI
end

local function CreateSection(parent, text, anchorTo, yGap)
    local ui = GetUI()
    if ui and ui.CreateSection then
        return ui.CreateSection(parent, text, anchorTo, yGap)
    end
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, yGap or -14)
    label:SetText(text)
    return label
end

local BUTTON_WIDTH = 112
local BUTTON_GAP = 6

local CreatePage

local function BindButtonTooltip(btn, title, tip)
    if not btn or not tip or tip == "" then
        return
    end
    local oldEnter = btn:GetScript("OnEnter")
    local oldLeave = btn:GetScript("OnLeave")
    -- Section rail sits on the right; tip opens toward the content.
    local anchor = btn.isHubSection and "ANCHOR_LEFT" or "ANCHOR_TOP"
    btn:SetScript("OnEnter", function(self)
        if oldEnter then
            oldEnter(self)
        end
        if GameTooltip then
            GameTooltip:SetOwner(self, anchor)
            GameTooltip:ClearLines()
            GameTooltip:AddLine(title or self:GetText() or (Mancer.DISPLAY_NAME or "Libellus Leti"), 1, 1, 1)
            GameTooltip:AddLine(tip, 0.75, 0.82, 0.80, true)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if oldLeave then
            oldLeave(self)
        end
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
end

local function CreateButtonRow(parent, anchorTo, yGap, definitions)
    local row = CreateFrame("Frame", nil, parent)
    local count = #definitions
    local totalWidth = 0
    for i, def in ipairs(definitions) do
        totalWidth = totalWidth + (def.width or BUTTON_WIDTH)
        if i < count then
            totalWidth = totalWidth + BUTTON_GAP
        end
    end
    row:SetSize(math.max(1, totalWidth), 24)
    row:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, yGap or -8)

    local ui = GetUI()
    local x = 0
    row.buttons = {}
    row.buttonsById = {}
    for i, def in ipairs(definitions) do
        local width = def.width or BUTTON_WIDTH
        local btn
        if ui and ui.CreateButton then
            btn = ui.CreateButton(row, def.text, width, 24)
            btn:ClearAllPoints()
            btn:SetPoint("LEFT", row, "LEFT", x, 0)
        else
            btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            btn:SetSize(width, 24)
            btn:SetPoint("LEFT", row, "LEFT", x, 0)
            btn:SetText(def.text)
        end
        btn._mancerButtonId = def.id
        if def.onClick then
            local clickFn = def.onClick
            local buttonId = def.id
            btn:SetScript("OnClick", function(self, ...)
                if buttonId then
                    if Hub.pages and Hub.pages.theory and Hub.pages.theory.theoryButtons
                        and Hub.pages.theory.theoryButtons[buttonId]
                        and Hub.SetTheoryButtonActive then
                        Hub:SetTheoryButtonActive(buttonId)
                    elseif Hub.SetCombatButtonActive then
                        Hub:SetCombatButtonActive(buttonId)
                    end
                end
                clickFn(self, ...)
            end)
        end
        if def.storeKey then
            Hub[def.storeKey] = btn
        end
        if def.tooltip then
            BindButtonTooltip(btn, def.text, def.tooltip)
        end
        table.insert(row.buttons, btn)
        if def.id then
            row.buttonsById[def.id] = btn
        end
        x = x + width + BUTTON_GAP
    end

    return row
end

local function CreateCheckbox(parent, label, anchorTo, yGap, isChecked, onToggle)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(420, 26)
    row:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, yGap or -6)

    local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb:SetPoint("LEFT", row, "LEFT", 0, 0)
    cb:SetChecked(isChecked and 1 or nil)

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 8, 0)
    text:SetText(label)
    local ui = GetUI()
    if ui and ui.StyleTitle then
        ui.StyleTitle(text)
    end

    cb:SetScript("OnClick", function(self)
        onToggle(self:GetChecked() and true or false)
    end)

    row.checkbox = cb
    return row
end

local function FitHubScroll(scroll, panel, lastWidget)
    if not scroll or not panel or not lastWidget then
        return
    end

    local top = panel:GetTop()
    local bottom = lastWidget:GetBottom()
    if not top or not bottom then
        return
    end

    local contentHeight = math.max(1, (top - bottom) + 8)
    local width = panel:GetWidth()
    if not width or width < 10 then
        width = Hub.CONTENT_WIDTH or 520
    end
    panel:SetWidth(width)
    panel:SetHeight(contentHeight)

    local bar = scroll.ScrollBar or (scroll.GetName and _G[scroll:GetName() .. "ScrollBar"])
    local viewHeight = scroll:GetHeight() or 0
    if contentHeight <= (viewHeight + 1) then
        scroll:SetVerticalScroll(0)
        if bar then
            bar:SetMinMaxValues(0, 0)
            bar:SetValue(0)
            bar:Hide()
        end
    elseif bar then
        bar:Show()
    end
end

local function FitFontStringHeight(fs)
    if not fs then
        return 20
    end
    local height = fs:GetStringHeight()
    if not height or height < 20 then
        height = 20
    end
    fs:SetHeight(height)
    return height
end

local DPS_ACC_ICON = 18
local DPS_ACC_HEADER_H = 26
local DPS_ACC_LINE_H = 18
local DPS_ACC_GAP = 8
local DPS_ACC_BODY_PAD = 4
local DPS_ACC_BODY_TOP = 2
local DPS_ACC_INDENT = 22

local function HubInCombat()
    return InCombatLockdown and InCombatLockdown()
end

-- Single pcall for clear+set so we never clear points then fail to re-set.
local function HubSetPoint(region, ...)
    if not region then
        return false
    end
    local ok = pcall(function(...)
        region:ClearAllPoints()
        region:SetPoint(...)
    end, ...)
    return ok and true or false
end

local function HubSetPoints(region, pointFn)
    if not region or type(pointFn) ~= "function" then
        return false
    end
    local ok = pcall(function()
        region:ClearAllPoints()
        pointFn(region)
    end)
    return ok and true or false
end

local DPS_FALLBACK_ICONS = {
    ghoul = "Interface\\Icons\\Spell_Shadow_AnimateDead",
    lesser_zombie = "Interface\\Icons\\Spell_Shadow_AnimateDead",
    bone_wraith = "Interface\\Icons\\Ability_Creature_Cursed_05",
    skeletal_archer = "Interface\\Icons\\INV_Weapon_Bow_07",
    skeletal_rogue = "Interface\\Icons\\Ability_Stealth",
    skeletal_warrior_lesser = "Interface\\Icons\\INV_Sword_07",
    skeletal_warrior_greater = "Interface\\Icons\\INV_Sword_39",
    plaguefather = "Interface\\Icons\\Spell_Shadow_Shadowfiend",
    tomb_king = "Interface\\Icons\\Achievement_Boss_LichKing",
    frost_wyrm = "Interface\\Icons\\INV_Misc_Head_Dragon_Blue",
    crypt_fiend = "Interface\\Icons\\Ability_Hunter_Pet_Spider",
    banshee = "Interface\\Icons\\Spell_Shadow_PsychicScream",
    abomination = "Interface\\Icons\\Ability_Warrior_BloodFrenzy",
    blight = "Interface\\Icons\\Spell_Shadow_DeathAndDecay",
    harvest_plague = "Interface\\Icons\\Spell_Shadow_CreepingPlague",
    ["Harvest Plague"] = "Interface\\Icons\\Spell_Shadow_CreepingPlague",
    ["Blight"] = "Interface\\Icons\\Spell_Shadow_DeathAndDecay",
    ["Diabolical"] = "Interface\\Icons\\Spell_Shadow_ShadowWordDominate",
    ["Bone King"] = "Interface\\Icons\\Ability_Creature_Cursed_05",
    ["Frost Runes"] = "Interface\\Icons\\Spell_Deathknight_EmpowerRuneBlade2",
    ["Command: Ghouls"] = "Interface\\Icons\\Spell_Shadow_AnimateDead",
    Melee = "Interface\\Icons\\INV_Sword_04",
    ["Zombie Plague"] = "Interface\\Icons\\Spell_Shadow_CreepingPlague",
    Bonestorm = "Interface\\Icons\\Spell_DeathKnight_BladedArmor",
    ["Skeletal Arrow"] = "Interface\\Icons\\INV_Weapon_Bow_07",
}

local function UsableDpsTexture(tex)
    if type(tex) ~= "string" then
        return nil
    end
    if tex == "" or tex == "?" then
        return nil
    end
    return tex
end

local function ResolveDpsIconTexture(spellId, spellName, fallbackKey)
    local tex
    spellId = tonumber(spellId)
    if spellId and spellId > 0 then
        if GetSpellTexture then
            tex = UsableDpsTexture(GetSpellTexture(spellId))
        end
        if not tex and GetSpellInfo then
            tex = UsableDpsTexture(select(3, GetSpellInfo(spellId)))
        end
    end
    if not tex and spellName and spellName ~= "" and GetSpellInfo then
        tex = UsableDpsTexture(select(3, GetSpellInfo(spellName)))
    end
    if not tex and fallbackKey then
        tex = DPS_FALLBACK_ICONS[fallbackKey]
    end
    if not tex and spellName then
        tex = DPS_FALLBACK_ICONS[spellName]
    end
    return tex or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function SetDpsSpellIcon(icon, spellId, spellName, fallbackKey)
    if not icon then
        return
    end
    icon:SetTexture(ResolveDpsIconTexture(spellId, spellName, fallbackKey))
    icon:Show()
end

function Hub:EnsureDpsAccordionHost(page, key, anchorHeader)
    if page[key] then
        return page[key]
    end

    local host = CreateFrame("Frame", nil, page)
    host:SetPoint("TOPLEFT", anchorHeader, "BOTTOMLEFT", 0, -6)
    host.rows = {}
    host.nextIndex = 1
    host:Hide()
    page[key] = host
    return host
end

function Hub:ResetDpsAccordionHost(host)
    if not host then
        return
    end
    host.nextIndex = 1
    for _, row in ipairs(host.rows or {}) do
        row:Hide()
        row:SetExpanded(false, true)
        row:UpdateHeight()
    end
end

function Hub:CreateDpsAccordionRow(parent, width)
    local row = CreateFrame("Frame", nil, parent)
    row:SetWidth(width)
    row.bodyLines = {}
    row.expanded = false

    local header = CreateFrame("Button", nil, row)
    header:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    header:SetSize(width, DPS_ACC_HEADER_H)
    header:RegisterForClicks("LeftButtonUp")
    row.header = header

    local chevron = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chevron:SetPoint("LEFT", header, "LEFT", 2, 0)
    chevron:SetWidth(14)
    chevron:SetJustifyH("CENTER")
    chevron:SetText(">")
    row.chevron = chevron

    local icon = header:CreateTexture(nil, "ARTWORK")
    icon:SetSize(DPS_ACC_ICON, DPS_ACC_ICON)
    icon:SetPoint("LEFT", chevron, "RIGHT", 4, 0)
    row.icon = icon

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    title:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetNonSpaceWrap(false)
    row.title = title

    local body = CreateFrame("Frame", nil, row)
    body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", DPS_ACC_INDENT, -DPS_ACC_BODY_TOP)
    body:SetWidth(math.max(1, width - DPS_ACC_INDENT))
    body:Hide()
    row.body = body

    header:SetScript("OnClick", function()
        row:SetExpanded(not row.expanded)
        if row.onToggle then
            row.onToggle()
        end
    end)
    header:SetScript("OnEnter", function()
        local ui = GetUI()
        if ui and ui.StyleAccent then
            ui.StyleAccent(row.title)
        end
        if row.chevron then
            row.chevron:SetTextColor(0.4, 0.95, 0.75, 1)
        end
    end)
    header:SetScript("OnLeave", function()
        local ui = GetUI()
        if ui and row.expanded and ui.StyleAccent then
            ui.StyleAccent(row.title)
        elseif row.title then
            row.title:SetTextColor(1, 0.82, 0, 1)
        end
        if row.chevron then
            row.chevron:SetTextColor(1, 1, 1, 1)
        end
    end)

    function row:SetExpanded(on, silent)
        self.expanded = on and true or false
        if self.chevron then
            self.chevron:SetText(self.expanded and "v" or ">")
        end
        if self.body then
            if self.expanded then
                self.body:Show()
            else
                self.body:Hide()
            end
        end
        if self.title then
            local ui = GetUI()
            if self.expanded and ui and ui.StyleAccent then
                ui.StyleAccent(self.title)
            else
                self.title:SetTextColor(1, 0.82, 0, 1)
            end
        end
        self:UpdateHeight()
    end

    function row:SetHeader(spellId, text, spellName, fallbackKey, iconTexture)
        if iconTexture and UsableDpsTexture(iconTexture) then
            self.icon:SetTexture(iconTexture)
            self.icon:Show()
        else
            SetDpsSpellIcon(self.icon, spellId, spellName or text, fallbackKey)
        end
        if self.title then
            self.title:SetText(text or "")
        end
    end

    function row:ClearBody()
        for _, line in ipairs(self.bodyLines or {}) do
            line:Hide()
        end
        self.bodyLineIndex = 1
    end

    function row:AddBodyLine(leftPad, spellId, text, spellName, fallbackKey, iconTexture)
        self.bodyLineIndex = self.bodyLineIndex or 1
        local idx = self.bodyLineIndex
        local line = self.bodyLines[idx]
        local pad = leftPad or 0
        if not line then
            line = CreateFrame("Frame", nil, self.body)
            line:SetHeight(DPS_ACC_LINE_H)
            line.icon = line:CreateTexture(nil, "ARTWORK")
            line.icon:SetSize(13, 13)
            line.text = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            line.text:SetJustifyH("LEFT")
            line.text:SetWordWrap(false)
            -- Anchor once at creation — never ClearAllPoints on recycle.
            line:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, -((idx - 1) * DPS_ACC_LINE_H))
            line.icon:SetPoint("LEFT", line, "LEFT", pad, 0)
            line.text:SetPoint("LEFT", line.icon, "RIGHT", 4, 0)
            line.text:SetPoint("RIGHT", line, "RIGHT", 0, 0)
            line._hasIconSlot = true
            self.bodyLines[idx] = line
        else
            -- Keep the fixed Y slot; only nudge icon/text pad if needed.
            pcall(function()
                line.icon:ClearAllPoints()
                line.icon:SetPoint("LEFT", line, "LEFT", pad, 0)
            end)
        end
        pcall(function()
            line:SetWidth(self.body:GetWidth() or 1)
        end)

        local showIcon = (iconTexture and UsableDpsTexture(iconTexture))
            or (spellId and tonumber(spellId))
            or false
        if showIcon then
            if iconTexture and UsableDpsTexture(iconTexture) then
                line.icon:SetTexture(iconTexture)
            else
                SetDpsSpellIcon(line.icon, spellId, spellName or text, fallbackKey)
            end
            line.icon:Show()
            pcall(function()
                line.text:ClearAllPoints()
                line.text:SetPoint("LEFT", line.icon, "RIGHT", 4, 0)
                line.text:SetPoint("RIGHT", line, "RIGHT", 0, 0)
            end)
        else
            line.icon:Hide()
            pcall(function()
                line.text:ClearAllPoints()
                line.text:SetPoint("LEFT", line, "LEFT", pad, 0)
                line.text:SetPoint("RIGHT", line, "RIGHT", 0, 0)
            end)
        end
        line.text:SetText(text or "")
        line:Show()
        self.bodyLineIndex = idx + 1
    end

    function row:UpdateHeight()
        local bodyLines = (self.bodyLineIndex or 1) - 1
        if bodyLines < 0 then
            bodyLines = 0
        end
        local bodyH = 0
        if self.expanded and bodyLines > 0 then
            bodyH = bodyLines * DPS_ACC_LINE_H + DPS_ACC_BODY_PAD
            self.body:SetHeight(bodyH)
            self.body:Show()
        else
            self.body:SetHeight(1)
            if not self.expanded then
                self.body:Hide()
            end
        end
        local total = DPS_ACC_HEADER_H
        if self.expanded and bodyLines > 0 then
            total = total + DPS_ACC_BODY_TOP + bodyH
        end
        self:SetHeight(total)
        self.header:SetHeight(DPS_ACC_HEADER_H)
        return total
    end

    row:SetExpanded(false, true)
    return row
end

function Hub:AcquireDpsAccordionRow(host, width)
    local idx = host.nextIndex or 1
    local row = host.rows[idx]
    if not row then
        row = self:CreateDpsAccordionRow(host, width)
        host.rows[idx] = row
    end
    row:SetWidth(width)
    row.header:SetWidth(width)
    row.body:SetWidth(math.max(1, width - DPS_ACC_INDENT))
    row:ClearBody()
    row:SetExpanded(false, true)
    row:Show()
    host.nextIndex = idx + 1
    row.onToggle = function()
        if host.onLayout then
            host.onLayout()
        end
    end
    return row
end

-- Absolute Y layout — does not chain row-to-row BOTTOMLEFT (avoids stuck overlaps).
function Hub:LayoutDpsAccordionHost(host, width, bannerText)
    if not host then
        return 1
    end

    local y = 0
    if host.banner then
        if bannerText and bannerText ~= "" then
            host.banner:SetWidth(width)
            host.banner:SetText(bannerText)
            host.banner:Show()
            local h = FitFontStringHeight(host.banner)
            host.banner:SetHeight(h)
            HubSetPoint(host.banner, "TOPLEFT", host, "TOPLEFT", 0, 0)
            y = h + 6
        else
            host.banner:Hide()
        end
    end

    local used = (host.nextIndex or 1) - 1
    for i = 1, used do
        local row = host.rows[i]
        if row then
            row:SetWidth(width)
            row.header:SetWidth(width)
            row.body:SetWidth(math.max(1, width - DPS_ACC_INDENT))
            local h = row:UpdateHeight() or row:GetHeight() or DPS_ACC_HEADER_H
            HubSetPoint(row, "TOPLEFT", host, "TOPLEFT", 0, -y)
            y = y + h + DPS_ACC_GAP
        end
    end

    for i = used + 1, #(host.rows or {}) do
        local row = host.rows[i]
        if row then
            row:Hide()
        end
    end

    if used > 0 then
        y = y - DPS_ACC_GAP
    end
    host:SetWidth(width)
    host:SetHeight(math.max(1, y))
    return y
end

function Hub:PopulateDpsAccordions(page, data, minionW, playerW)
    local MinionDps = Mancer.MinionDpsModule
    local fmt = MinionDps and MinionDps.FormatNumber and function(n)
        return MinionDps:FormatNumber(n)
    end or tostring

    local minionHost = self:EnsureDpsAccordionHost(page, "dpsMinionHost", page.stHeader)
    local playerHost = self:EnsureDpsAccordionHost(page, "dpsPlayerHost", page.aoeHeader)
    minionHost.onLayout = function()
        Hub:SyncDpsAccordionHeights(page, minionW, playerW)
    end
    playerHost.onLayout = minionHost.onLayout

    if minionHost.banner then
        minionHost.banner:Hide()
        minionHost.banner = nil
    end

    self:ResetDpsAccordionHost(minionHost)
    self:ResetDpsAccordionHost(playerHost)

    if data and data.mode == "benchmark" then
        minionHost:Hide()
        playerHost:Hide()
        if page.stCol then
            page.stCol:Show()
            page.stCol:SetText("")
        end
        if page.aoeCol then
            page.aoeCol:Show()
            page.aoeCol:SetText(data.playerTextFallback or "(benchmarks are minion-only)")
        end
        return page.aoeCol, page.stCol
    end

    page.stCol:Hide()
    page.aoeCol:Hide()
    minionHost:Show()
    playerHost:Show()

    minionHost:SetWidth(minionW)
    playerHost:SetWidth(playerW)
    HubSetPoint(minionHost, "TOPLEFT", page.stHeader, "BOTTOMLEFT", 0, -6)
    HubSetPoint(playerHost, "TOPLEFT", page.aoeHeader, "BOTTOMLEFT", 0, -6)

    local minionRows = data and data.minions or {}
    if #minionRows == 0 then
        local acc = self:AcquireDpsAccordionRow(minionHost, minionW)
        acc:SetHeader(nil, "(no minion damage recorded)")
        acc:UpdateHeight()
    end
    for _, row in ipairs(minionRows) do
        local acc = self:AcquireDpsAccordionRow(minionHost, minionW)
        local lf = row.dpsLf and string.format(" · %.0f DPS/LF", row.dpsLf) or ""
        acc:SetHeader(
            row.iconSpellId,
            string.format(
                "%s · %.0f DPS/unit · %d hits%s",
                row.label,
                row.dps or 0,
                row.hits or 0,
                lf
            ),
            row.label,
            row.minionId,
            row.iconTexture
        )
        if (row.summonCount or 0) > 0 then
            acc:AddBodyLine(0, nil, string.format(
                "%d summons · %.0fs unit-time",
                row.summonCount,
                row.activeSeconds or 0
            ))
        elseif (row.activeSeconds or 0) > 0 then
            acc:AddBodyLine(0, nil, string.format(
                "Out %.0fs (%.0f%% of fight)",
                row.activeSeconds,
                row.uptimePct or 0
            ))
        end
        for _, spell in ipairs(row.spells or {}) do
            acc:AddBodyLine(
                4,
                spell.spellId,
                string.format(
                    "%s · %s dmg · %.1f%% · %d hits · %.0f DPS",
                    spell.label,
                    fmt(spell.damage),
                    spell.sharePct or 0,
                    spell.hits or 0,
                    spell.dps or 0
                ),
                spell.label,
                spell.label,
                spell.iconTexture
            )
        end
        acc:UpdateHeight()
    end

    local players = data and data.players or {}
    if #players == 0 then
        local acc = self:AcquireDpsAccordionRow(playerHost, playerW)
        acc:SetHeader(nil, "(no player DoTs / procs this fight)")
        acc:UpdateHeight()
    else
        for _, row in ipairs(players) do
            local acc = self:AcquireDpsAccordionRow(playerHost, playerW)
            if row.kind == "proc" then
                acc:SetHeader(
                    row.iconSpellId,
                    string.format("%s · %d procs", row.label, row.procs or 0),
                    row.label,
                    row.id or row.label,
                    row.iconTexture
                )
                if row.sessionNote then
                    acc:AddBodyLine(0, nil, row.sessionNote)
                else
                    local procs = row.procs or 0
                    local dur = data.duration or 0
                    acc:AddBodyLine(0, row.iconSpellId, string.format("%d procs this fight", procs), row.label, row.id or row.label, row.iconTexture)
                    if dur > 0 then
                        acc:AddBodyLine(0, nil, string.format("Fight %.0fs · %.1f procs/min", dur, procs * 60 / dur))
                    end
                end
            elseif row.sessionNote then
                acc:SetHeader(
                    row.iconSpellId,
                    string.format("%s · session", row.label),
                    row.label,
                    row.id or row.label,
                    row.iconTexture
                )
                acc:AddBodyLine(0, nil, row.sessionNote)
            else
                local durPart = (row.unitSec or 0) > 0 and string.format("%.0fs", row.unitSec) or "—"
                local tgtPart = string.format("%d target%s", row.targetCount or 0, (row.targetCount or 0) == 1 and "" or "s")
                local upPart = row.uptimePct and string.format("%.0f%% of fight", row.uptimePct) or "—"
                acc:SetHeader(
                    row.iconSpellId,
                    string.format(
                        "%s · %s · %s · %s",
                        row.label,
                        durPart,
                        tgtPart,
                        upPart
                    ),
                    row.label,
                    row.id or row.label,
                    row.iconTexture
                )
                for _, t in ipairs(row.targets or {}) do
                    acc:AddBodyLine(4, nil, string.format("%s · %s dmg", t.name, fmt(t.damage)))
                end
            end
            acc:UpdateHeight()
        end
    end

    self:LayoutDpsAccordionHost(minionHost, minionW, nil)
    self:LayoutDpsAccordionHost(playerHost, playerW, nil)

    return minionHost, playerHost
end

function Hub:EnsureDpsCombatLayoutWatcher()
    if self.dpsCombatWatcher then
        return
    end
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    watcher:SetScript("OnEvent", function()
        local pending = Hub.pendingDpsLayout
        Hub.pendingDpsLayout = nil
        if pending and Hub.frame and Hub.frame:IsShown() then
            Hub:SyncDpsAccordionHeights(pending.page, pending.minionW, pending.playerW)
        end
    end)
    self.dpsCombatWatcher = watcher
end

function Hub:SyncDpsAccordionHeights(page, minionW, playerW)
    local minionHost = page and page.dpsMinionHost
    local playerHost = page and page.dpsPlayerHost
    if not minionHost or not playerHost then
        return
    end

    -- Absolute Y layout on every toggle — works whether one or many rows are open.
    self:LayoutDpsAccordionHost(minionHost, minionW, nil)
    self:LayoutDpsAccordionHost(playerHost, playerW, nil)
    local minH = minionHost:GetHeight() or 1
    local plH = playerHost:GetHeight() or 1
    page.lastWidget = minH >= plH and minionHost or playerHost
    FitHubScroll(self.scroll, page, page.lastWidget)

    if HubInCombat() then
        self:EnsureDpsCombatLayoutWatcher()
        self.pendingDpsLayout = {
            page = page,
            minionW = minionW,
            playerW = playerW,
        }
    end
end

function Hub:SetStatus(msg)
    if self.statusText then
        self.statusText:SetText(tostring(msg or ""))
        local ui = GetUI()
        if ui and ui.StyleMuted then
            ui.StyleMuted(self.statusText)
        end
    end
end

function Hub:Notify(msg)
    self:SetStatus(msg)
end

function Hub:OpenDisplaySettings()
    -- Display is the only external window: hide Hub so bars/ticks stay visible.
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
    end
    if not Mancer.Options then
        return
    end
    Mancer.Options:Open()
    local win = Mancer.Options.window
    if win and not win._mancerHubDisplayHooked then
        win._mancerHubDisplayHooked = true
        local prev = win:GetScript("OnHide")
        win:SetScript("OnHide", function(self, ...)
            if prev then
                prev(self, ...)
            end
            -- Leave Hub closed after Options; reopen via /leti or minimap.
            if Hub.frame and Hub.frame:IsShown() then
                Hub.frame:Hide()
            end
        end)
    end
end

function Hub:SaveFramePosition()
    if not self.frame then
        return
    end
    MancerDB = MancerDB or {}
    MancerDB.hub = MancerDB.hub or {}
    local point, _, _, x, y = self.frame:GetPoint(1)
    MancerDB.hub.point = point
    MancerDB.hub.x = x
    MancerDB.hub.y = y
    MancerDB.hub.tab = self.activeTab or MancerDB.hub.tab
end

function Hub:ApplySavedPosition()
    if not self.frame then
        return
    end
    local saved = MancerDB and MancerDB.hub
    if saved and saved.point then
        self.frame:ClearAllPoints()
        self.frame:SetPoint(saved.point, UIParent, saved.point, saved.x or 0, saved.y or 0)
    end
end

function Hub:RefreshSummary()
    if not self.summaryText then
        return
    end
    local parts = {}

    if Mancer.PaperMathModule and Mancer.PaperMathModule.GetPlayerPaperStats then
        local p = Mancer.PaperMathModule:GetPlayerPaperStats()
        if p then
            table.insert(parts, string.format("Hit %.0f%%", p.spellHitPct or 0))
            table.insert(parts, string.format("Haste %.0f%%", p.hastePct or 0))
            local crit = (p.critPctFromRating or 0) + (p.spellCritFromInt or 0)
            table.insert(parts, string.format("Crit %.0f%%", crit))
            table.insert(parts, string.format("INT %d", p.intellect or 0))
        end
    end

    if Mancer.StatPriorityModule and Mancer.StatPriorityModule.GetLiveStats then
        local stats = Mancer.StatPriorityModule:GetLiveStats()
        if stats and Mancer.StatPriorityModule.GetActiveStep then
            local active = Mancer.StatPriorityModule:GetActiveStep(stats)
            if active then
                if active.kind == "primary" then
                    table.insert(parts, "Next: INT")
                elseif active.targetPct then
                    local live = stats[active.stat] or 0
                    local needPct, needRating = Mancer.StatPriorityModule:GetCapDeficit(active, stats)
                    if needRating and needRating > 0 then
                        table.insert(parts, string.format("Next: %s (~%d)", active.label, needRating))
                    else
                        table.insert(parts, string.format("Next: %s (%.0f/%.0f)", active.label, live, active.targetPct))
                    end
                end
            end
        end
    end

    if #parts == 0 then
        self.summaryText:SetText("Live stats unavailable — open after fully loaded.")
    else
        self.summaryText:SetText(table.concat(parts, "  |  "))
    end
    local ui = GetUI()
    if ui and ui.StyleMuted then
        ui.StyleMuted(self.summaryText)
    end
end

function Hub:LeaveContentView()
    if self.viewMode == "sheet" then
        self:DetachMinionSheet()
    end
    self.viewMode = nil
    if self.scroll then
        self.scroll:Show()
    end
    if self.pages then
        if self.pages.report then
            self.pages.report:Hide()
        end
        if self.pages.stAoe then
            self.pages.stAoe:Hide()
        end
        if self.pages.sheet then
            self.pages.sheet:Hide()
        end
        if self.pages.statPriority then
            self.pages.statPriority:Hide()
        end
    end
end

function Hub:BackFromContent()
    self:LeaveContentView()
    self:SelectTab(self.activeTab or "combat")
end

function Hub:LayoutScrollForPage(page)
    local frame = self.frame
    local scroll = self.scroll
    local tabBar = self.tabBar
    if not frame or not scroll or not tabBar then
        return
    end
    scroll:ClearAllPoints()
    if page == self.pages.sheet then
        if self.summaryText then
            self.summaryText:Hide()
        end
        -- Pull content up into the summary strip so no dark gap bar shows.
        scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -62)
    else
        if self.summaryText then
            self.summaryText:Show()
        end
        scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -88)
    end
    scroll:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 28)
    scroll:SetPoint("RIGHT", tabBar, "LEFT", -14, 0)
end

function Hub:PresentPage(page)
    if not self.scroll or not page then
        return
    end
    for id, p in pairs(self.pages or {}) do
        if p == page then
            p:Show()
        else
            p:Hide()
        end
    end
    -- Sheet host is parented to Hub art (full-bleed); hide scroll so it cannot
    -- cover the art or steal mouse / fight layout.
    if page == self.pages.sheet then
        self.scroll:Hide()
        if self.summaryText then
            self.summaryText:Hide()
        end
        return
    end
    self.scroll:Show()
    self:LayoutScrollForPage(page)
    self.scroll:SetScrollChild(page)
    page:ClearAllPoints()
    page:SetPoint("TOPLEFT", self.scroll, "TOPLEFT", 0, 0)
    page:SetWidth(Hub.CONTENT_WIDTH or 520)
    FitHubScroll(self.scroll, page, page.lastWidget)
end

function Hub:EnsureReportPage()
    if self.pages and self.pages.report then
        return self.pages.report
    end
    if not self.frame or not self.pages then
        return nil
    end

    local ui = GetUI()
    local page = CreatePage(self.frame)
    local backRow = CreateButtonRow(page, page, 0, {
        {
            text = "Back",
            width = 72,
            tooltip = "Return to the current section",
            onClick = function()
                Hub:BackFromContent()
            end,
        },
    })
    backRow:ClearAllPoints()
    backRow:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)

    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", backRow, "RIGHT", 12, 0)
    title:SetJustifyH("LEFT")
    title:SetText("Report")
    if ui and ui.StyleTitle then
        ui.StyleTitle(title)
    end
    page.titleText = title

    local body = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", backRow, "BOTTOMLEFT", 0, -12)
    body:SetWidth((Hub.CONTENT_WIDTH or 520) - 24)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetSpacing(3)
    body:SetText("")
    if ui and ui.StyleMuted then
        ui.StyleMuted(body)
    end
    page.body = body
    page.lastWidget = body
    self.pages.report = page
    return page
end

function Hub:EnsureStAoePage()
    if self.pages and self.pages.stAoe then
        return self.pages.stAoe
    end
    if not self.frame or not self.pages then
        return nil
    end

    local ui = GetUI()
    local contentW = Hub.CONTENT_WIDTH or 980
    local gap = 24
    local colW = math.floor((contentW - gap) / 2)

    local page = CreatePage(self.frame)
    local backRow = CreateButtonRow(page, page, 0, {
        {
            text = "Back",
            width = 72,
            tooltip = "Return to Combat",
            onClick = function()
                Hub:BackFromContent()
            end,
        },
    })
    backRow:ClearAllPoints()
    backRow:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)

    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", backRow, "RIGHT", 12, 0)
    title:SetJustifyH("LEFT")
    title:SetText("ST vs AOE")
    if ui and ui.StyleTitle then
        ui.StyleTitle(title)
    end
    page.titleText = title

    local intro = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", backRow, "BOTTOMLEFT", 0, -10)
    intro:SetWidth(contentW - 8)
    intro:SetJustifyH("LEFT")
    intro:SetJustifyV("TOP")
    intro:SetSpacing(2)
    intro:SetText("")
    if ui and ui.StyleMuted then
        ui.StyleMuted(intro)
    end
    page.introText = intro

    local stHeader = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    stHeader:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -12)
    stHeader:SetWidth(colW)
    stHeader:SetJustifyH("LEFT")
    stHeader:SetText("Boss / one target")
    if ui and ui.StyleTitle then
        ui.StyleTitle(stHeader)
    elseif ui and ui.Colors and ui.Colors.accent then
        local c = ui.Colors.accent
        stHeader:SetTextColor(c[1], c[2], c[3], 1)
    end
    page.stHeader = stHeader

    local aoeHeader = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    aoeHeader:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", colW + gap, -12)
    aoeHeader:SetWidth(colW)
    aoeHeader:SetJustifyH("LEFT")
    aoeHeader:SetText("Packs / AoE")
    if ui and ui.StyleTitle then
        ui.StyleTitle(aoeHeader)
    elseif ui and ui.Colors and ui.Colors.accent then
        local c = ui.Colors.accent
        aoeHeader:SetTextColor(c[1], c[2], c[3], 1)
    end
    page.aoeHeader = aoeHeader

    local stCol = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    stCol:SetPoint("TOPLEFT", stHeader, "BOTTOMLEFT", 0, -6)
    stCol:SetWidth(colW)
    stCol:SetJustifyH("LEFT")
    stCol:SetJustifyV("TOP")
    stCol:SetSpacing(3)
    stCol:SetText("")
    page.stCol = stCol

    local aoeCol = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    aoeCol:SetPoint("TOPLEFT", aoeHeader, "BOTTOMLEFT", 0, -6)
    aoeCol:SetWidth(colW)
    aoeCol:SetJustifyH("LEFT")
    aoeCol:SetJustifyV("TOP")
    aoeCol:SetSpacing(3)
    aoeCol:SetText("")
    page.aoeCol = aoeCol

    local cheat = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cheat:SetPoint("TOPLEFT", stCol, "BOTTOMLEFT", 0, -16)
    cheat:SetWidth(contentW - 8)
    cheat:SetJustifyH("LEFT")
    cheat:SetJustifyV("TOP")
    cheat:SetSpacing(3)
    cheat:SetText("")
    if ui and ui.StyleMuted then
        ui.StyleMuted(cheat)
    end
    page.cheatText = cheat

    page.lastWidget = cheat
    self.pages.stAoe = page
    return page
end

local function StripFirstLine(text)
    if not text then
        return ""
    end
    local rest = text:match("^[^\n]*\n(.*)$")
    return rest or text
end

function Hub:SetCombatButtonActive(id)
    local page = self.pages and self.pages.combat
    local map = page and page.combatButtons
    if not map then
        return
    end
    page.activeCombatButton = id
    for btnId, btn in pairs(map) do
        if btn.SetSelected then
            btn:SetSelected(btnId == id)
        end
    end
end

function Hub:PrepareCombatDetail()
    if self.viewMode == "sheet" then
        self:DetachMinionSheet()
    end
    self.viewMode = nil
    if self.pages then
        if self.pages.report then
            self.pages.report:Hide()
        end
        if self.pages.stAoe then
            self.pages.stAoe:Hide()
        end
        if self.pages.sheet then
            self.pages.sheet:Hide()
        end
    end

    if self.activeTab ~= "combat" then
        self.activeTab = "combat"
        local ui = GetUI()
        local colors = ui and ui.Colors
        for id, btn in pairs(self.tabButtons or {}) do
            local selected = id == "combat"
            if btn.SetSelected then
                btn:SetSelected(selected)
            elseif btn.label and colors then
                if selected then
                    btn.label:SetTextColor(colors.accent[1], colors.accent[2], colors.accent[3], 1)
                else
                    btn.label:SetTextColor(colors.buttonText[1], colors.buttonText[2], colors.buttonText[3], 1)
                end
            end
        end
        MancerDB = MancerDB or {}
        MancerDB.hub = MancerDB.hub or {}
        MancerDB.hub.tab = "combat"
    end

    local page = self.pages and self.pages.combat
    if page then
        self:PresentPage(page)
    end
    return page
end

function Hub:SetCombatDetailMode(mode)
    local page = self.pages and self.pages.combat
    if not page then
        return
    end
    local stAoe = mode == "stAoe"
    local dps = mode == "dps"
    local export = mode == "export"
    local twoCol = stAoe or dps
    if page.detailBody then
        if twoCol or export then
            page.detailBody:Hide()
        else
            page.detailBody:Show()
        end
    end
    if page.exportFrame then
        if export then
            page.exportFrame:Show()
        else
            page.exportFrame:Hide()
        end
    end
    -- Intro + cheat sheet only for ST vs AoE.
    for _, widget in ipairs({ page.stIntro, page.cheatText }) do
        if widget then
            if stAoe then
                widget:Show()
            else
                widget:Hide()
            end
        end
    end
    for _, widget in ipairs({ page.stHeader, page.aoeHeader, page.stCol, page.aoeCol }) do
        if widget then
            if twoCol then
                if dps and (widget == page.stCol or widget == page.aoeCol) then
                    widget:Hide()
                else
                    widget:Show()
                end
            else
                widget:Hide()
            end
        end
    end
    for _, key in ipairs({ "dpsMinionHost", "dpsPlayerHost" }) do
        local host = page[key]
        if host then
            if dps then
                host:Show()
            else
                host:Hide()
            end
        end
    end
end

function Hub:ShowCombatDetailReport(title, lines, buttonId)
    local page = self:PrepareCombatDetail()
    if not page or not page.detailTitle or not page.detailBody then
        self:ShowInHubReport(title, lines)
        return
    end

    if buttonId then
        self:SetCombatButtonActive(buttonId)
    end

    self:SetCombatDetailMode("report")
    page.detailTitle:SetText(title or (Mancer.DISPLAY_NAME or "Libellus Leti"))
    local text = table.concat(lines or { "(empty)" }, "\n")
    if text == "" then
        text = "(empty)"
    end
    local width = (Hub.CONTENT_WIDTH or 980) - 24
    page.detailBody:SetWidth(width)
    page.detailBody:SetText(text)
    local height = FitFontStringHeight(page.detailBody)
    page.detailBody:SetHeight(height)
    page.lastWidget = page.detailBody
    FitHubScroll(self.scroll, page, page.lastWidget)
end

function Hub:CaptureReportLines(fn)
    local lines = {}
    Mancer.reportSink = lines
    local ok, err = pcall(fn)
    Mancer.reportSink = nil
    if not ok then
        return { "Report failed: " .. tostring(err) }
    end
    if #lines == 0 then
        return { "(no output)" }
    end
    return lines
end

function Hub:ShowStVsAoe()
    if not Mancer.MinionDpsModule or not Mancer.MinionDpsModule.GetStVsAoeColumns then
        self:ShowCombatDetailReport("ST vs AOE", { "Minion DPS module not loaded." }, "stAoe")
        return
    end

    local page = self:PrepareCombatDetail()
    if not page or not page.stIntro then
        -- Fallback to legacy full-page layout if combat detail is missing.
        local legacy = self:EnsureStAoePage()
        if not legacy then
            return
        end
        if self.viewMode == "sheet" then
            self:DetachMinionSheet()
        end
        self.viewMode = "stAoe"
        page = legacy
        if page.introText and not page.stIntro then
            page.stIntro = page.introText
        end
    else
        self:SetCombatDetailMode("stAoe")
        page.detailTitle:SetText("ST vs AOE")
        self:SetCombatButtonActive("stAoe")
    end

    local cols = Mancer.MinionDpsModule:GetStVsAoeColumns()
    local contentW = Hub.CONTENT_WIDTH or 980
    local gap = 24
    local colW = math.floor((contentW - gap) / 2)

    page.stIntro:SetWidth(contentW - 8)
    page.stIntro:SetText(cols.intro or "")
    FitFontStringHeight(page.stIntro)

    page.stHeader:ClearAllPoints()
    page.stHeader:SetPoint("TOPLEFT", page.stIntro, "BOTTOMLEFT", 0, -12)
    page.stHeader:SetWidth(colW)
    page.stHeader:SetText("Boss / one target")
    page.aoeHeader:ClearAllPoints()
    page.aoeHeader:SetPoint("TOPLEFT", page.stIntro, "BOTTOMLEFT", colW + gap, -12)
    page.aoeHeader:SetWidth(colW)
    page.aoeHeader:SetText("Packs / AoE")

    page.stCol:ClearAllPoints()
    page.stCol:SetPoint("TOPLEFT", page.stHeader, "BOTTOMLEFT", 0, -6)
    page.stCol:SetWidth(colW)
    page.stCol:SetText(StripFirstLine(cols.stText))
    local stH = FitFontStringHeight(page.stCol)

    page.aoeCol:ClearAllPoints()
    page.aoeCol:SetPoint("TOPLEFT", page.aoeHeader, "BOTTOMLEFT", 0, -6)
    page.aoeCol:SetWidth(colW)
    page.aoeCol:SetText(StripFirstLine(cols.aoeText))
    local aoeH = FitFontStringHeight(page.aoeCol)

    local colH = math.max(stH, aoeH)
    page.stCol:SetHeight(colH)
    page.aoeCol:SetHeight(colH)

    page.cheatText:ClearAllPoints()
    page.cheatText:SetPoint("TOPLEFT", page.stCol, "BOTTOMLEFT", 0, -16)
    page.cheatText:SetWidth(contentW - 8)
    page.cheatText:SetText(cols.cheatText or "")
    FitFontStringHeight(page.cheatText)
    page.lastWidget = page.cheatText

    if page == self.pages.combat then
        FitHubScroll(self.scroll, page, page.lastWidget)
    else
        self:PresentPage(page)
    end
end

function Hub:ShowInHubReport(title, lines)
    local page = self:EnsureReportPage()
    if not page then
        return
    end
    if self.viewMode == "sheet" then
        self:DetachMinionSheet()
    end
    self.viewMode = "report"

    page.titleText:SetText(title or (Mancer.DISPLAY_NAME or "Libellus Leti"))
    local text = table.concat(lines or { "(empty)" }, "\n")
    if text == "" then
        text = "(empty)"
    end
    page.body:SetWidth((Hub.CONTENT_WIDTH or 520) - 24)
    page.body:SetText(text)
    local height = page.body:GetStringHeight()
    if not height or height < 20 then
        height = 20
    end
    page.body:SetHeight(height)
    page.lastWidget = page.body
    self:PresentPage(page)
end

function Hub:SelectTab(tabId)
    if not self.pages then
        return
    end
    self:LeaveContentView()

    tabId = tabId or "combat"
    -- Setup jumps straight to Display (controls live there; no Hub page).
    if tabId == "setup" then
        self:OpenDisplaySettings()
        return
    end
    if not self.pages[tabId] then
        tabId = "combat"
    end
    self.activeTab = tabId

    local ui = GetUI()
    local colors = ui and ui.Colors
    for id, btn in pairs(self.tabButtons or {}) do
        local selected = id == tabId
        if btn.SetSelected then
            btn:SetSelected(selected)
        else
            if btn.bg and colors then
                if selected then
                    btn.bg:SetVertexColor(0.16, 0.28, 0.25, 1)
                else
                    btn.bg:SetVertexColor(colors.buttonBg[1], colors.buttonBg[2], colors.buttonBg[3], colors.buttonBg[4] or 1)
                end
            end
            if btn.border and colors then
                if selected then
                    btn.border:SetVertexColor(colors.accent[1], colors.accent[2], colors.accent[3], 1)
                else
                    btn.border:SetVertexColor(colors.buttonBorder[1], colors.buttonBorder[2], colors.buttonBorder[3], 1)
                end
            end
            if btn.label and colors then
                if selected then
                    btn.label:SetTextColor(colors.accent[1], colors.accent[2], colors.accent[3], 1)
                else
                    btn.label:SetTextColor(colors.buttonText[1], colors.buttonText[2], colors.buttonText[3], 1)
                end
            end
        end
    end

    MancerDB = MancerDB or {}
    MancerDB.hub = MancerDB.hub or {}
    MancerDB.hub.tab = tabId

    -- Minions section LOCKED (0.9.267): opens the sheet directly (no Sheet/Inspect menu).
    -- Model = Plaguefather; stats = Overwhelming Force + Tears of Lordaeron. Do not retune.
    if tabId == "minions" then
        self:ShowMinionSheet()
        return
    end

    local page = self.pages[tabId]
    self:PresentPage(page)
    self:RefreshSummary()
end

function Hub:ShowReport(id, title, fn)
    if type(fn) ~= "function" then
        return
    end
    local lines = self:CaptureReportLines(fn)
    local combatButtonIds = {
        minionDps = "dps",
        minionCombo = "combo",
        minionMeasure = "measure",
    }
    local combatIds = {
        minionDps = true,
        minionCombo = true,
        minionMeasure = true,
    }
    if combatIds[id] and self.pages and self.pages.combat and self.pages.combat.detailBody then
        local buttonId = combatButtonIds[id]
        self:ShowCombatDetailReport(title or (Mancer.DISPLAY_NAME or "Libellus Leti"), lines, buttonId)
        return
    end
    self:ShowInHubReport(title or (Mancer.DISPLAY_NAME or "Libellus Leti"), lines)
end

function Hub:ShowNotice(title, lines)
    if self.pages and self.pages.combat and self.pages.combat.detailBody
        and (self.activeTab == "combat" or not self.activeTab) then
        self:ShowCombatDetailReport(title or (Mancer.DISPLAY_NAME or "Libellus Leti"), lines or { "(empty)" })
        return
    end
    self:ShowInHubReport(title or (Mancer.DISPLAY_NAME or "Libellus Leti"), lines or { "(empty)" })
end

function Hub:EnsureSheetPage()
    if self.pages and self.pages.sheet then
        local page = self.pages.sheet
        if page.backRow then
            page.backRow:Hide()
        end
        if page.titleText then
            page.titleText:Hide()
        end
        return page
    end
    if not self.frame or not self.pages then
        return nil
    end

    -- Placeholder scroll child only — sheet host is parented to Hub art.
    -- No Back / title: Minions rail opens the sheet directly.
    local page = CreatePage(self.frame)
    page:SetWidth(1)
    page:SetHeight(1)
    page.lastWidget = page
    self.pages.sheet = page
    return page
end

function Hub:DetachMinionSheet()
    local sheet = Mancer.MinionSheetModule
    if not sheet or not sheet.frame then
        return
    end
    local frame = sheet.frame
    sheet:Hide()
    if sheet.RestoreStandaloneStyle then
        sheet:RestoreStandaloneStyle()
    end
    if sheet.BindFrameOnUpdate then
        sheet:BindFrameOnUpdate()
    end
    frame:SetParent(UIParent)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    if frame.title then
        frame.title:Show()
    end
    if frame.subtitle then
        frame.subtitle:Show()
    end
    if frame.close then
        frame.close:Show()
        frame.close:SetScript("OnClick", function()
            sheet:Hide()
        end)
    end
    frame._mancerHubEmbedded = nil
end

function Hub:EmbedMinionSheet()
    -- LOCKED with Minions section (0.9.267) — sheet == art; Plaguefather model; OF/Tears stats.
    local page = self:EnsureSheetPage()
    local sheet = Mancer.MinionSheetModule
    if not page or not sheet then
        return nil
    end

    self:SyncHubArtToCoA()
    self:SamplePlaguefatherOffset()
    self:SampleStatsTextRect()

    local hub = self.frame
    local art = hub and hub.mancerArt
    local frame = sheet:EnsureFrame()
    frame._mancerHubEmbedded = true
    frame:SetParent(hub)
    frame:ClearAllPoints()
    -- Sheet == background art rect so Plaguefather coords stay locked while dragging.
    if art then
        frame:SetPoint("TOPLEFT", art, "TOPLEFT", 0, 0)
        frame:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT", 0, 0)
    else
        frame:SetPoint("TOPLEFT", hub, "TOPLEFT", 2, -24)
        frame:SetPoint("BOTTOMRIGHT", hub, "BOTTOMRIGHT", -2, 2)
    end
    frame:SetMovable(false)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", nil)
    frame:SetScript("OnDragStop", nil)
    frame:SetFrameStrata(hub:GetFrameStrata() or "DIALOG")
    -- Below SECTIONS rail / chrome so tabs and close stay clickable.
    frame:SetFrameLevel((hub:GetFrameLevel() or 1) + 2)
    if self.tabBar then
        self.tabBar:SetFrameLevel(frame:GetFrameLevel() + 10)
    end
    if frame.title then
        frame.title:Hide()
    end
    if frame.subtitle then
        frame.subtitle:Hide()
    end
    if frame.close then
        frame.close:Hide()
    end

    local w = (art and art.GetWidth and art:GetWidth()) or (hub:GetWidth() - 4) or 980
    local h = (art and art.GetHeight and art:GetHeight()) or (hub:GetHeight() - 26) or 500
    if sheet.ApplyHubEmbedStyle then
        sheet:ApplyHubEmbedStyle(w, h)
    end
    -- Keep the sheet's refresh OnUpdate; only request a one-shot art-size layout pass.
    sheet._hubLayoutOnce = true
    if sheet.BindFrameOnUpdate then
        sheet:BindFrameOnUpdate()
    end
    sheet:Show()
    sheet:Refresh(true)

    page.lastWidget = page
    return page
end

function Hub:ShowMinionStatus()
    if not Mancer.NecromancerAdvisor then
        self:ShowNotice("Minion Status", { "Minion advisor not loaded." })
        return
    end
    self:ShowReport("minionStatus", "Minion Status", function()
        Mancer.NecromancerAdvisor:PrintStatus()
    end)
end

function Hub:ShowMinionStance()
    if not Mancer.NecromancerAdvisor then
        return
    end
    self:ShowReport("minionStance", "Undead Stance", function()
        Mancer.NecromancerAdvisor:PrintStanceStatus()
    end)
end

function Hub:ShowLifeForce()
    if not Mancer.NecromancerAdvisor then
        return
    end
    self:ShowReport("minionLifeForce", "Life Force", function()
        Mancer.NecromancerAdvisor:PrintLifeForceStatus()
    end)
end

function Hub:ShowDpsColumns(mode)
    if not Mancer.MinionDpsModule or not Mancer.MinionDpsModule.GetDpsReportColumns then
        self:ShowCombatDetailReport("Minion DPS", { "Minion DPS module not loaded." }, mode == "session" and "session" or "dps")
        return
    end

    local page = self:PrepareCombatDetail()
    if not page or not page.stHeader or not page.stCol or not page.aoeCol then
        local titles = {
            auto = "Minion DPS",
            session = "Minion DPS (Session)",
            benchmark = "Minion DPS (Benchmark)",
        }
        self:ShowReport("minionDps", titles[mode] or "Minion DPS", function()
            Mancer.MinionDpsModule:PrintDpsReport(mode)
        end)
        return
    end

    self:SetCombatDetailMode("dps")
    self:SetCombatButtonActive(mode == "session" and "session" or "dps")

    local cols = Mancer.MinionDpsModule:GetDpsReportColumns(mode)
    local contentW = Hub.CONTENT_WIDTH or 980
    -- Use the live scroll width when the Hub is wider than the content constant.
    if self.scroll and self.scroll.GetWidth then
        local sw = self.scroll:GetWidth()
        if sw and sw > contentW + 1 then
            contentW = math.floor(sw)
        end
    end
    local gap = 16
    -- Minion lines are denser (Harvest Plague summary); give them extra room.
    local minionW = math.floor((contentW - gap) * 0.56)
    local playerW = contentW - gap - minionW

    page.detailTitle:SetText(cols.title or "Minion DPS")

    HubSetPoint(page.stHeader, "TOPLEFT", page.detailTitle, "BOTTOMLEFT", 0, -12)
    page.stHeader:SetWidth(minionW)
    page.stHeader:SetText("Minions")

    HubSetPoint(page.aoeHeader, "TOPLEFT", page.detailTitle, "BOTTOMLEFT", minionW + gap, -12)
    page.aoeHeader:SetWidth(playerW)
    page.aoeHeader:SetText("Player")

    if cols.data and mode ~= "benchmark" then
        self:PopulateDpsAccordions(page, cols.data, minionW, playerW)
        self:SyncDpsAccordionHeights(page, minionW, playerW)
        return
    end

    if page.dpsMinionHost then
        page.dpsMinionHost:Hide()
    end
    if page.dpsPlayerHost then
        page.dpsPlayerHost:Hide()
    end
    page.stCol:Show()
    page.aoeCol:Show()

    HubSetPoint(page.stCol, "TOPLEFT", page.stHeader, "BOTTOMLEFT", 0, -6)
    page.stCol:SetWidth(minionW)
    page.stCol:SetText(cols.minionText or "")
    local stH = FitFontStringHeight(page.stCol)

    HubSetPoint(page.aoeCol, "TOPLEFT", page.aoeHeader, "BOTTOMLEFT", 0, -6)
    page.aoeCol:SetWidth(playerW)
    page.aoeCol:SetText(cols.playerText or "")
    local aoeH = FitFontStringHeight(page.aoeCol)

    local colH = math.max(stH, aoeH)
    page.stCol:SetHeight(colH)
    page.aoeCol:SetHeight(colH)
    page.lastWidget = (aoeH > stH) and page.aoeCol or page.stCol
    FitHubScroll(self.scroll, page, page.lastWidget)
end

function Hub:ShowMinionDps(mode)
    if not Mancer.MinionDpsModule then
        self:ShowNotice("Minion DPS", { "Minion DPS module not loaded." })
        return
    end
    mode = mode or "auto"
    if mode == "benchmark" then
        self:ShowReport("minionDps", "Minion DPS (Benchmark)", function()
            Mancer.MinionDpsModule:PrintDpsReport(mode)
        end)
        return
    end
    self:ShowDpsColumns(mode)
end

function Hub:ShowCombo()
    if not Mancer.MinionDpsModule then
        return
    end
    self:ShowReport("minionCombo", "LF Combo", function()
        Mancer.MinionDpsModule:PrintComboRecommendation()
    end)
end

function Hub:ShowHowToMeasure()
    if not Mancer.MinionDpsModule then
        self:ShowNotice("How to Measure", { "Minion DPS module not loaded." })
        return
    end
    self:ShowReport("minionMeasure", "How to Measure", function()
        Mancer.MinionDpsModule:PrintCalibrationHelp()
    end)
end

function Hub:ShowInspect()
    if not Mancer.MinionInspectModule then
        return
    end
    self:ShowReport("minionInspect", "Minion Inspect", function()
        Mancer.MinionInspectModule:PrintInspect("")
    end)
end

function Hub:ShowMinionSheet()
    if not Mancer.MinionSheetModule then
        Mancer.Print("MinionSheet module not loaded.")
        return
    end
    local page = self:EmbedMinionSheet()
    if not page then
        self:Notify("Could not open Minion Sheet in Hub.")
        return
    end
    self.viewMode = "sheet"
    self:PresentPage(page)
    self:RefreshSummary()
end

function Hub:ShowPaperMath()
    self:ShowTheoryDetailReport("Paper DPS", "paper", function()
        if Mancer.PaperMathModule then
            Mancer.PaperMathModule:PrintReport()
        else
            Mancer.Print("PaperMath module not loaded.")
        end
    end)
end

function Hub:ShowBuffPicks()
    self:ShowTheoryDetailReport("Preferred Buffs", "buffs", function()
        if Mancer.AnimationTalentTips and Mancer.AnimationTalentTips.PrintBuffGuide then
            Mancer.AnimationTalentTips.PrintBuffGuide()
        else
            Mancer.Print("Buff guide not loaded.")
        end
    end)
end

function Hub:InstallPlayerMacros()
    if not Mancer.Macros or not Mancer.Macros.InstallGraveMarchSet then
        self:ShowNotice("Player Macros", { "Macros module not loaded." })
        return
    end
    local lines = Mancer.Macros:InstallGraveMarchSet()
    self:ShowNotice("Player Macros", lines)
    if self.SetStatus and lines[1] then
        self:SetStatus(lines[1])
    end
end

function Hub:SetTheoryButtonActive(id)
    local page = self.pages and self.pages.theory
    local map = page and page.theoryButtons
    if not map then
        return
    end
    page.activeTheoryButton = id
    for btnId, btn in pairs(map) do
        if btn.SetSelected then
            btn:SetSelected(btnId == id)
        end
    end
end

function Hub:PrepareTheoryDetail()
    if self.viewMode == "sheet" then
        self:DetachMinionSheet()
    end
    self.viewMode = nil
    if self.pages then
        if self.pages.report then
            self.pages.report:Hide()
        end
        if self.pages.stAoe then
            self.pages.stAoe:Hide()
        end
        if self.pages.sheet then
            self.pages.sheet:Hide()
        end
        if self.pages.statPriority then
            self.pages.statPriority:Hide()
        end
    end

    if self.activeTab ~= "theory" then
        self.activeTab = "theory"
        local ui = GetUI()
        local colors = ui and ui.Colors
        for id, btn in pairs(self.tabButtons or {}) do
            local selected = id == "theory"
            if btn.SetSelected then
                btn:SetSelected(selected)
            elseif btn.label and colors then
                if selected then
                    btn.label:SetTextColor(colors.accent[1], colors.accent[2], colors.accent[3], 1)
                else
                    btn.label:SetTextColor(colors.buttonText[1], colors.buttonText[2], colors.buttonText[3], 1)
                end
            end
        end
        MancerDB = MancerDB or {}
        MancerDB.hub = MancerDB.hub or {}
        MancerDB.hub.tab = "theory"
    end

    local page = self.pages and self.pages.theory
    if page then
        self:PresentPage(page)
    end
    return page
end

function Hub:SetTheoryDetailMode(mode)
    local page = self.pages and self.pages.theory
    if not page then
        return
    end
    local stats = mode == "statPriority"
    if page.detailBody then
        if stats then
            page.detailBody:Hide()
        else
            page.detailBody:Show()
        end
    end
    if page.statHost then
        if stats then
            page.statHost:Show()
        else
            page.statHost:Hide()
        end
    end
end

function Hub:ShowTheoryDetailReport(title, buttonId, fn)
    local page = self:PrepareTheoryDetail()
    if not page or not page.detailTitle or not page.detailBody then
        self:ShowInHubReport(title, self:CaptureReportLines(fn))
        return
    end
    if buttonId then
        self:SetTheoryButtonActive(buttonId)
    end
    self:SetTheoryDetailMode("report")
    page.detailTitle:SetText(title or (Mancer.DISPLAY_NAME or "Libellus Leti"))
    local lines = self:CaptureReportLines(fn)
    local text = table.concat(lines or { "(empty)" }, "\n")
    if text == "" then
        text = "(empty)"
    end
    local width = (Hub.CONTENT_WIDTH or 980) - 24
    page.detailBody:SetWidth(width)
    page.detailBody:SetText(text)
    local height = FitFontStringHeight(page.detailBody)
    page.detailBody:SetHeight(height)
    page.lastWidget = page.detailBody
    FitHubScroll(self.scroll, page, page.lastWidget)
end

function Hub:ShowStatPriority()
    if not Mancer.StatPriorityModule or not Mancer.StatPriorityModule.ShowInHost then
        Mancer.Print("StatPriority module not loaded.")
        return
    end
    local page = self:PrepareTheoryDetail()
    if not page or not page.statHost then
        Mancer.Print("Guides page not ready.")
        return
    end

    self:SetTheoryButtonActive("statPriority")
    self:SetTheoryDetailMode("statPriority")
    page.detailTitle:SetText("Stat Priority")

    local width = (Hub.CONTENT_WIDTH or 1060) - 24
    page.statHost:SetWidth(width)
    local content = Mancer.StatPriorityModule:ShowInHost(page.statHost, width)
    if content then
        page.statHost:SetHeight(content:GetHeight() or 400)
        page.lastWidget = page.statHost
    else
        page.lastWidget = page.detailTitle
    end
    FitHubScroll(self.scroll, page, page.lastWidget)
end

function Hub:EnsureDpsExportPanel()
    local page = self.pages and self.pages.combat
    if not page or page.exportFrame then
        return page and page.exportFrame
    end

    local contentW = Hub.CONTENT_WIDTH or 1060
    local frame = CreateFrame("Frame", nil, page)
    frame:SetPoint("TOPLEFT", page.detailTitle, "BOTTOMLEFT", 0, -10)
    frame:SetWidth(contentW - 24)
    frame:SetHeight(420)
    frame:Hide()
    page.exportFrame = frame

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    hint:SetWidth(contentW - 24)
    hint:SetJustifyH("LEFT")
    hint:SetText("WoW cannot write .txt files directly. Report is copied to the clipboard when possible — paste into Notepad and Save As .txt. Or Ctrl+A / Ctrl+C below.")
    local ui = GetUI()
    if ui and ui.StyleMuted then
        ui.StyleMuted(hint)
    end
    frame.hint = hint

    local scroll = CreateFrame("ScrollFrame", "MancerDpsExportScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 0)
    frame.scroll = scroll

    local edit = CreateFrame("EditBox", "MancerDpsExportEdit", scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(GameFontHighlightSmall)
    edit:SetWidth((contentW - 24) - 36)
    edit:SetTextInsets(4, 4, 4, 4)
    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    scroll:SetScrollChild(edit)
    frame.edit = edit

    return frame
end

function Hub:ShowDpsExport(text, statusMsg)
    local page = self:PrepareCombatDetail()
    if not page or not page.detailTitle then
        self:ShowInHubReport("Save DPS", { statusMsg or "Export ready.", text or "" })
        return
    end

    local export = self:EnsureDpsExportPanel()
    self:SetCombatDetailMode("export")
    self:SetCombatButtonActive("save")
    page.detailTitle:SetText("Save DPS")

    if export and export.edit then
        export.edit:SetText(text or "")
        export.edit:SetFocus()
        local lineCount = 1
        if text and text ~= "" then
            for _ in string.gmatch(text, "\n") do
                lineCount = lineCount + 1
            end
        end
        local height = math.max(200, lineCount * 14 + 20)
        export.edit:SetHeight(height)
        export:SetHeight(math.min(480, 40 + height))
        page.lastWidget = export
        FitHubScroll(self.scroll, page, export)
    end

    if statusMsg then
        self:Notify(statusMsg)
        if page.exportFrame and page.exportFrame.hint then
            page.exportFrame.hint:SetText(statusMsg)
        end
    end
end

function Hub:SaveDpsFight()
    if not Mancer.MinionDpsModule then
        self:ShowCombatDetailReport("Save DPS", { "Minion DPS module not loaded." }, "save")
        return
    end

    -- Still commit mid-fight pulls (training dummies) so LF Combo has data.
    local saveResult = Mancer.MinionDpsModule:SaveCurrentFight()
    local text = Mancer.MinionDpsModule:BuildDpsExportText("auto")
    if not text or text == "" then
        self:ShowCombatDetailReport("Save DPS", { "No minion DPS data to export yet." }, "save")
        return
    end

    MancerDB = MancerDB or {}
    MancerDB.dpsExportText = text
    MancerDB.dpsExportAt = time and time() or nil

    local copied = false
    if Internal_CopyToClipboard then
        copied = pcall(Internal_CopyToClipboard, text)
    end

    local status
    if copied then
        status = "DPS report copied to clipboard — paste into Notepad and Save As a .txt file."
    else
        status = "Select the text below (Ctrl+A), copy (Ctrl+C), paste into Notepad, and Save As a .txt file."
    end
    if saveResult == true then
        status = status .. " (Fight also saved for LF Combo.)"
    elseif saveResult == "already_saved" then
        status = status .. " (Fight was already saved.)"
    end

    self:ShowDpsExport(text, status)
end

function Hub:ResetDpsSession()
    if not Mancer.MinionDpsModule then
        return
    end
    Mancer.MinionDpsModule:ResetSession()
    self:Notify("Minion DPS session cleared.")
end

function Hub:ToggleMoveMode()
    if not Mancer.FloatingText then
        self:Notify("Addon not fully loaded yet.")
        return
    end
    Mancer.FloatingText:SetMoveMode(not Mancer.FloatingText.moveMode)
    if Mancer.Options then
        Mancer.Options:UpdateMoveButton()
    end
    self:Notify(Mancer.FloatingText.moveMode and "Layout anchors shown." or "Layout anchors hidden.")
    self:SyncControls()
end

function Hub:TestPreview()
    if not Mancer.FloatingText then
        return
    end
    Mancer.FloatingText:ShowTick("+42 mana", MancerDB.manaColor, "mana")
    Mancer.FloatingText:ShowTick("+18 health", MancerDB.healthColor, "health")
    Mancer.FloatingText:UpdateRateText(42)
    self:Notify("Preview ticks shown.")
end

function Hub:ResetBarLayout()
    if Mancer.Options then
        Mancer.Options:ResetBarLayout()
    end
    self:Notify("Bar layout reset.")
    self:SyncControls()
end

function Hub:SyncControls()
    if not self.frame then
        return
    end

    if Mancer.Options and Mancer.Options.SyncControls then
        Mancer.Options:SyncControls()
    end

    self:RefreshSummary()
end

-- ============================================================================
-- HUB ARTWORK LOCKED (shipped look as of 0.9.249)
-- Do not change sizes, atlases, rail placement, connectors, or label gaps
-- unless the user explicitly confirms an art change.
-- ============================================================================
-- Match CoATalentFrame outer size (CoATalentFrame.xml).
local HUB_WIDTH = 1294
local HUB_HEIGHT = 666
-- PassivesBackground XML display size (CoATalentFrame.xml). AtlasInfo native is
-- 159×1018; CoA stretches it to 74×480 via SetAtlas(..., IgnoreAtlasSize).
local RAIL_W = 74
local RAIL_H = 480
local ATLAS_NATIVE_W = 159 -- AtlasInfo only; do not use for display scale.
local ATLAS_NATIVE_H = 1018
-- Relative to CoATalentFrame: PassivesBackground left 1203, top -81.
local RAIL_LEFT = 1203
local RAIL_TOP = -81
local RAIL_LABEL_WIDTH = 86
-- SpecTree: button 30; section nodes spread across full PassivesBackground height.
local NODE_SIZE = 30
local NODE_RING = 36
-- SECTIONS gold connectors (locked with Hub art — do not retune).
local SECTION_ARROW_HEAD_W = 14
local SECTION_ARROW_HEAD_H = 12
local SECTION_ARROW_TIP_INSET = 6
local SECTION_LABEL_TEXT_GAP = 20
Hub.CONTENT_WIDTH = 1060

local TAB_DEFS = {
    {
        id = "combat",
        label = "Combat",
        subtitle = "Army · LF · DPS",
        tip = "Army picks, Life Force, DPS, and ST vs AoE",
        icon = "Interface\\Icons\\Spell_Shadow_DeathCoil",
    },
    {
        id = "minions",
        label = "Minions",
        subtitle = "Guardian sheet",
        tip = "Live guardian sheet — stats and model",
        icon = "Interface\\Icons\\Spell_Shadow_AnimateDead",
    },
    {
        id = "theory",
        label = "Guides",
        subtitle = "Stats · Paper · Buffs",
        tip = "Stat caps, paper DPS, and buff picks",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
    },
    {
        id = "setup",
        label = "Setup",
        subtitle = "Bars · Display",
        tip = "Open display options (bars, ticks, fonts, layout)",
        icon = "Interface\\Icons\\INV_Misc_Gear_01",
    },
    {
        id = "credits",
        label = "Credits",
        subtitle = "Thanks · Help",
        tip = "Thanks to everyone who helped with Mancer",
        icon = "Interface\\Icons\\INV_Misc_GroupLooking",
    },
}

-- CoATreeViewMixin lives on CoATalentFrame.TreeView — SpecTree is a child of TreeView,
-- not of CoATalentFrame (CoATalentFrame.xml + CoATreeViewMixin.lua).
local function GetCoATreeView()
    return CoATalentFrame and CoATalentFrame.TreeView
end

local function GetCoASpecTree()
    local treeView = GetCoATreeView()
    return treeView and treeView.SpecTree
end

local function GetCoAPassivesBackground()
    local specTree = GetCoASpecTree()
    return specTree and specTree.PassivesBackground
end

-- Animate: Plaguefather — CA entry 33748 / spell 805048.
-- LOCKED (0.9.265): model CENTER on this node; do not retune without confirmation.
local PLAGUEFATHER_ENTRY_ID = 33748
local PLAGUEFATHER_SPELL_ID = 805048
local PLAGUEFATHER_CACHE_VER = 4
-- Fallback center relative to Hub/CoATalentFrame TOPLEFT (Animation tree mid).
local PLAGUEFATHER_FALLBACK_X = 920
local PLAGUEFATHER_FALLBACK_Y = -310

-- Stats text column — LOCKED (0.9.266 look). Bookended by Animation nodes
-- Overwhelming Force CA 29196 / spell 531128; Tears of Lordaeron CA 6897 / spell 705752.
-- Do not retune offsets / fallbacks without confirmation.
local STATS_TEXT_CACHE_VER = 1
local STATS_ANCHORS = {
    { key = "force", name = "Overwhelming Force", entryId = 29196, spellId = 531128 },
    { key = "tears", name = "Tears of Lordaeron", entryId = 6897, spellId = 705752 },
}
-- Fallbacks: left column of Animation tree (hub TOPLEFT space).
local STATS_FALLBACK_TOP_X, STATS_FALLBACK_TOP_Y = 300, -140
local STATS_FALLBACK_BOT_X, STATS_FALLBACK_BOT_Y = 300, -500

local function EntryMatchesIds(entry, entryId, spellId, nameNeedle)
    if not entry then
        return false
    end
    if entryId and entry.ID == entryId then
        return true
    end
    local spell = entry.SpellID or entry.spellID
    if type(entry.Spells) == "table" then
        spell = spell or entry.Spells[1]
    elseif type(entry.Spells) == "number" then
        spell = spell or entry.Spells
    end
    if spellId and spell == spellId then
        return true
    end
    local name = entry.Name or entry.name
    if nameNeedle and name and tostring(name):find(nameNeedle, 1, true) then
        return true
    end
    return false
end

local function EntryMatchesPlaguefather(entry)
    return EntryMatchesIds(entry, PLAGUEFATHER_ENTRY_ID, PLAGUEFATHER_SPELL_ID, "Plaguefather")
end

local function NodeMatchesSpellOrEntry(node, entryId, spellId, nameNeedle)
    if not node then
        return false
    end
    if EntryMatchesIds(node.entry, entryId, spellId, nameNeedle) then
        return true
    end
    if spellId and node.spellID == spellId then
        return true
    end
    if spellId and node.GetTooltipSpellID then
        local ok, id = pcall(function()
            return node:GetTooltipSpellID()
        end)
        if ok and id == spellId then
            return true
        end
    end
    return false
end

local function NodeMatchesPlaguefather(node)
    return NodeMatchesSpellOrEntry(node, PLAGUEFATHER_ENTRY_ID, PLAGUEFATHER_SPELL_ID, "Plaguefather")
end

-- Copy CoA TreeView.Background1 atlas + relative rect onto Hub.mancerArt.
function Hub:SyncHubArtToCoA()
    local hub = self.frame
    local art = hub and hub.mancerArt
    local scrub = hub and hub.mancerBg
    local coa = CoATalentFrame
    local bg = coa and coa.TreeView and coa.TreeView.Background1
    if not hub or not art then
        return
    end

    if bg and coa and coa.IsShown and coa:IsShown() and bg.GetLeft and bg:GetLeft() then
        if bg.GetAtlas and art.SetAtlas then
            local atlas = bg:GetAtlas()
            if atlas and atlas ~= "" then
                pcall(function()
                    art:SetAtlas(atlas, Const and Const.TextureKit and Const.TextureKit.IgnoreAtlasSize)
                end)
            end
        end
        local cL, cR = coa:GetLeft(), coa:GetRight()
        local cT, cB = coa:GetTop(), coa:GetBottom()
        local bL, bR = bg:GetLeft(), bg:GetRight()
        local bT, bB = bg:GetTop(), bg:GetBottom()
        if cL and cR and cT and cB and bL and bR and bT and bB then
            art:ClearAllPoints()
            art:SetPoint("TOPLEFT", hub, "TOPLEFT", bL - cL, bT - cT)
            art:SetPoint("BOTTOMRIGHT", hub, "BOTTOMRIGHT", bR - cR, bB - cB)
            if scrub and scrub.ClearAllPoints then
                scrub:ClearAllPoints()
                scrub:SetPoint("TOPLEFT", art, "TOPLEFT", 0, 0)
                scrub:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT", 0, 0)
            end
            return
        end
    end

    -- Static CoA-matched insets when talent UI is closed.
    local inset = 2
    local topInset = 24
    art:ClearAllPoints()
    art:SetPoint("TOPLEFT", hub, "TOPLEFT", inset, -topInset)
    art:SetPoint("BOTTOMRIGHT", hub, "BOTTOMRIGHT", -inset, inset)
    if scrub and scrub.ClearAllPoints then
        scrub:ClearAllPoints()
        scrub:SetPoint("TOPLEFT", art, "TOPLEFT", 0, 0)
        scrub:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT", 0, 0)
    end
end

-- Sample SpecTree node center as offsets from CoATalentFrame TOPLEFT.
local function SampleSpecTreeNodeOffset(matchFn)
    local coa = CoATalentFrame
    local specTree = GetCoASpecTree()
    if not coa or not coa:IsShown() or not specTree or not specTree.EnumerateNodes or not matchFn then
        return nil
    end
    local rLeft, rTop = coa:GetLeft(), coa:GetTop()
    if not rLeft or not rTop then
        return nil
    end

    local function tryNode(node)
        if not node or not node.GetCenter or not matchFn(node) then
            return nil
        end
        if node.IsShown and not node:IsShown() then
            return nil
        end
        local cx, cy = node:GetCenter()
        if not cx or not cy then
            return nil
        end
        return cx - rLeft, cy - rTop
    end

    for node in specTree:EnumerateNodes() do
        local x, y = tryNode(node)
        if not x and node.nodes then
            for _, sub in ipairs(node.nodes) do
                x, y = tryNode(sub)
                if x then
                    break
                end
            end
        end
        if x then
            return x, y
        end
    end
    return nil
end

function Hub:SamplePlaguefatherOffset()
    local x, y = SampleSpecTreeNodeOffset(NodeMatchesPlaguefather)
    if not x then
        return nil
    end
    self._plaguefatherOffset = { x = x, y = y }
    MancerDB = MancerDB or {}
    MancerDB.hub = MancerDB.hub or {}
    MancerDB.hub.plaguefatherVer = PLAGUEFATHER_CACHE_VER
    MancerDB.hub.plaguefatherX = x
    MancerDB.hub.plaguefatherY = y
    return x, y
end

function Hub:GetPlaguefatherOffset()
    local x, y = self:SamplePlaguefatherOffset()
    if x then
        return x, y
    end
    if self._plaguefatherOffset then
        return self._plaguefatherOffset.x, self._plaguefatherOffset.y
    end
    local saved = MancerDB and MancerDB.hub
    if saved and saved.plaguefatherVer == PLAGUEFATHER_CACHE_VER and saved.plaguefatherX and saved.plaguefatherY then
        return saved.plaguefatherX, saved.plaguefatherY
    end
    return PLAGUEFATHER_FALLBACK_X, PLAGUEFATHER_FALLBACK_Y
end

-- Sample Overwhelming Force + Tears of Lordaeron → stats column top/bottom in hub space.
function Hub:SampleStatsTextRect()
    local points = {}
    for _, def in ipairs(STATS_ANCHORS) do
        local x, y = SampleSpecTreeNodeOffset(function(node)
            return NodeMatchesSpellOrEntry(node, def.entryId, def.spellId, def.name)
        end)
        if x then
            points[#points + 1] = { x = x, y = y, key = def.key }
        end
    end
    if #points < 1 then
        return nil
    end

    local topX, topY = points[1].x, points[1].y
    local botX, botY = points[1].x, points[1].y
    for i = 2, #points do
        local p = points[i]
        if p.y > topY then
            topX, topY = p.x, p.y
        end
        if p.y < botY then
            botX, botY = p.x, p.y
        end
    end
    -- Single hit: invent a column height around that node.
    if #points == 1 then
        botX, botY = topX, topY - 360
    end

    self._statsTextRect = { topX = topX, topY = topY, botX = botX, botY = botY }
    MancerDB = MancerDB or {}
    MancerDB.hub = MancerDB.hub or {}
    local hub = MancerDB.hub
    hub.statsTextVer = STATS_TEXT_CACHE_VER
    hub.statsTextTopX, hub.statsTextTopY = topX, topY
    hub.statsTextBotX, hub.statsTextBotY = botX, botY
    return topX, topY, botX, botY
end

function Hub:GetStatsTextRect()
    local topX, topY, botX, botY = self:SampleStatsTextRect()
    if topX then
        return topX, topY, botX, botY
    end
    local cached = self._statsTextRect
    if cached then
        return cached.topX, cached.topY, cached.botX, cached.botY
    end
    local saved = MancerDB and MancerDB.hub
    if saved and saved.statsTextVer == STATS_TEXT_CACHE_VER
        and saved.statsTextTopX and saved.statsTextTopY
        and saved.statsTextBotX and saved.statsTextBotY then
        return saved.statsTextTopX, saved.statsTextTopY, saved.statsTextBotX, saved.statsTextBotY
    end
    return STATS_FALLBACK_TOP_X, STATS_FALLBACK_TOP_Y, STATS_FALLBACK_BOT_X, STATS_FALLBACK_BOT_Y
end

-- CoA XML display size is 74×480. Hub SECTIONS always uses these locked
-- constants — copying live PassivesBackground when CoA was open made the
-- rail look different after /reload vs with the talent tree open.
local function GetPassivesRailSize()
    return RAIL_W, RAIL_H, GetCoAPassivesBackground()
end

local function ForceSize(region, w, h)
    if not region then
        return
    end
    if region.SetWidth then
        region:SetWidth(w)
    end
    if region.SetHeight then
        region:SetHeight(h)
    end
    if region.SetSize then
        region:SetSize(w, h)
    end
end

-- CoATreeViewMixin: SetAtlas("ca-passive-bg", IgnoreAtlasSize) on a Texture sized
-- 74×480 — that STRETCHES the 159×1018 atlas (non-uniform). Uniform scale(74/159)
-- only paints ~74×474 and makes our silver frame visibly shorter at the tips.
local function ApplyPassivesBackground(tex, host, carrier)
    local railW, railH = GetPassivesRailSize()
    ForceSize(host, railW, railH)
    host:SetScale(1)

    if carrier then
        -- Carrier matches the XML display box exactly (74×480), not atlas native.
        carrier:SetScale(1)
        ForceSize(carrier, railW, railH)
        carrier:ClearAllPoints()
        carrier:SetAllPoints(host)
        carrier:Show()
    end

    local rail = Mancer.UI and Mancer.UI.HUB_PASSIVE_RAIL
    local loaded = false
    -- Prefer game atlas exactly like CoATreeViewMixin.
    if tex.SetAtlas then
        loaded = pcall(function()
            local ignore = Const and Const.TextureKit and Const.TextureKit.IgnoreAtlasSize
            if ignore ~= nil then
                tex:SetAtlas((rail and rail.atlas) or "ca-passive-bg", ignore)
            else
                tex:SetAtlas((rail and rail.atlas) or "ca-passive-bg", false)
            end
        end)
        loaded = loaded and tex.GetTexture and tex:GetTexture() and true or false
    end
    if not loaded and rail and rail.path then
        tex:SetTexture(rail.path)
        tex:SetTexCoord(rail.left, rail.right, rail.top, rail.bottom)
        loaded = tex.GetTexture and tex:GetTexture() and true or false
    end

    tex:ClearAllPoints()
    if carrier then
        tex:SetAllPoints(carrier)
    else
        tex:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    end
    -- Match CoA: IgnoreAtlasSize + force XML size so art fills 74×480.
    ForceSize(tex, railW, railH)
    if loaded then
        tex:Show()
    end

    return railW, railH
end

-- Place tabBar so the 74×480 railHost sits where CoA PassivesBackground sits.
local function PlaceSectionRail(tabBar, railHost, hubFrame)
    if not tabBar or not railHost or not hubFrame then
        return
    end

    local railW, railH = GetPassivesRailSize()
    ForceSize(railHost, railW, railH)
    railHost:SetScale(1)
    tabBar:SetScale(1)
    ForceSize(tabBar, RAIL_LABEL_WIDTH + railW, railH)

    tabBar:ClearAllPoints()
    tabBar:SetPoint("TOPLEFT", hubFrame, "TOPLEFT", RAIL_LEFT - RAIL_LABEL_WIDTH, RAIL_TOP)
    railHost:ClearAllPoints()
    railHost:SetPoint("TOPRIGHT", tabBar, "TOPRIGHT", 0, 0)
end

-- Passive-column centers tuned to the native CoA rail layout.
-- Keep nodes inside the straight inner track rather than stretching them to
-- the decorative top/bottom tips of the frame.
local SECTION_SLOT_CENTERS_Y = { 60, 150, 240, 330, 420 }

local function RelToPassivesBg(bgLeft, bgTop, sx, sy)
    return sx - bgLeft, bgTop - sy
end

-- Sample live SpecTree passive-node centers + CALineConnection Arrow centers
-- relative to PassivesBackground, so Hub connectors match CoA X/Y exactly.
local function CollectLivePassiveLayout(count)
    local specTree = GetCoASpecTree()
    local passivesBg = GetCoAPassivesBackground()
    if not specTree or not passivesBg or not specTree.EnumerateNodes then
        return nil
    end

    local bgLeft, bgRight = passivesBg:GetLeft(), passivesBg:GetRight()
    local bgTop, bgBottom = passivesBg:GetTop(), passivesBg:GetBottom()
    if not bgLeft or not bgRight or not bgTop or not bgBottom then
        return nil
    end

    local padX = 8
    local padY = 6
    local seen = {}
    local hits = {}
    local liveNodes = {}

    local function consider(node)
        if not node or not node.IsShown or not node:IsShown() or not node.GetCenter then
            return
        end
        local cx, cy = node:GetCenter()
        if not cx or not cy then
            return
        end
        if cx < (bgLeft - padX) or cx > (bgRight + padX) then
            return
        end
        if cy > (bgTop + padY) or cy < (bgBottom - padY) then
            return
        end

        local relX, relY = RelToPassivesBg(bgLeft, bgTop, cx, cy)
        local key = floor(relX + 0.5) .. ":" .. floor(relY + 0.5)
        if seen[key] then
            return
        end
        seen[key] = true
        local hit = {
            x = relX,
            y = relY,
            node = node,
        }
        table.insert(hits, hit)
        table.insert(liveNodes, node)
    end

    for node in specTree:EnumerateNodes() do
        consider(node)
        if node.nodes then
            for _, sub in ipairs(node.nodes) do
                consider(sub)
            end
        end
    end

    if #hits < (count or #TAB_DEFS) then
        return nil
    end

    table.sort(hits, function(a, b)
        return a.y < b.y
    end)

    local slots = {}
    for i = 1, math.min(#hits, count or #TAB_DEFS) do
        local hit = hits[i]
        slots[i] = {
            x = hit.x,
            y = -hit.y,
            cx = hit.x,
            cy = -hit.y,
            node = hit.node,
        }
    end

    -- Live arrowheads from CALineConnectionTemplate frames on SpecTree.
    local arrows = {}
    local function considerArrow(conn)
        if not conn or not conn.IsShown or not conn:IsShown() then
            return
        end
        local arrow = conn.Arrow
        if not arrow or not arrow.GetCenter then
            return
        end
        local ax, ay = arrow:GetCenter()
        if not ax or not ay then
            return
        end
        if ax < (bgLeft - padX) or ax > (bgRight + padX) then
            return
        end
        if ay > (bgTop + padY) or ay < (bgBottom - padY) then
            return
        end
        local relX, relY = RelToPassivesBg(bgLeft, bgTop, ax, ay)
        local hw = (arrow.GetWidth and arrow:GetWidth()) or 24
        local hh = (arrow.GetHeight and arrow:GetHeight()) or 24
        table.insert(arrows, {
            x = relX,
            y = relY,
            cx = relX,
            cy = -relY,
            w = hw,
            h = hh,
            conn = conn,
        })
    end

    -- Prefer node.connectionBranches (authoritative), then scan SpecTree children.
    for i = 1, #liveNodes do
        local node = liveNodes[i]
        if node and node.connectionBranches then
            for _, conn in pairs(node.connectionBranches) do
                considerArrow(conn)
            end
        end
    end
    if #arrows == 0 then
        local ok, kids = pcall(function()
            return { specTree:GetChildren() }
        end)
        if ok and kids then
            for i = 1, #kids do
                considerArrow(kids[i])
            end
        end
    end

    table.sort(arrows, function(a, b)
        return a.y < b.y
    end)

    local links = {}
    for i = 1, #slots - 1 do
        local a, b = slots[i], slots[i + 1]
        local aY = -a.cy
        local bY = -b.cy
        local midY = (aY + bY) / 2
        local best, bestDist
        for _, arrowHit in ipairs(arrows) do
            if arrowHit.y > aY - 2 and arrowHit.y < bY + 2 then
                local dist = math.abs(arrowHit.y - midY)
                if not bestDist or dist < bestDist then
                    best = arrowHit
                    bestDist = dist
                end
            end
        end
        local tipPad = NODE_SIZE / 2
        -- Overlap a couple of pixels into each icon so tips/tails don't float.
        local tipY = b.cy + tipPad - 2
        links[i] = {
            cx = a.cx,
            topY = a.cy - tipPad + 2,
            botY = b.cy,
            -- Keep live X when available; tip is forced onto the lower icon edge.
            headCx = best and best.cx or a.cx,
            headCy = tipY + 6,
            headW = 14,
            headH = 12,
            tipY = tipY,
            hasLiveHead = best ~= nil,
        }
    end

    return slots, links
end

local function BuildSectionSlots(count, railW, railH)
    count = count or 1
    railW = railW or RAIL_W
    railH = railH or RAIL_H
    -- Always use fixed slot centers. Live SpecTree sampling made icon spacing
    -- jump when CoA was open vs after a reload with no talent tree.
    local centerX = floor(railW / 2)
    local slots = {}
    for i = 1, count do
        local centerY = SECTION_SLOT_CENTERS_Y[i]
        if not centerY then
            local topPad = 48
            local bottomPad = 44
            local firstCenter = topPad
            local lastCenter = railH - bottomPad
            local step = (count > 1) and ((lastCenter - firstCenter) / (count - 1)) or 0
            centerY = firstCenter + (i - 1) * step
        end
        slots[i] = {
            x = centerX,
            y = -centerY,
            cx = centerX,
            cy = -centerY,
        }
    end
    return slots, nil
end

local function BuildSectionLinks(slots, arrow)
    local links = {}
    if not slots then
        return links
    end
    local headW = (arrow and arrow.headW) or 14
    local headH = (arrow and arrow.headH) or 12
    -- Tip sits slightly into the lower icon edge so the arrow touches.
    local tipPad = NODE_SIZE / 2
    for i = 1, #slots - 1 do
        local a, b = slots[i], slots[i + 1]
        if a and b then
            local tipY = b.cy + tipPad - 2
            links[i] = {
                cx = a.cx,
                topY = a.cy - tipPad + 2,
                botY = b.cy,
                headCx = a.cx,
                headCy = tipY + (headH / 2),
                headW = headW,
                headH = headH,
                tipY = tipY,
                hasLiveHead = false,
            }
        end
    end
    return links
end

CreatePage = function(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetSize(Hub.CONTENT_WIDTH or 520, 1)
    page:Hide()
    return page
end

function Hub:LayoutSectionRail()
    local railHost = self.tabRailHost
    local tabBar = self.tabBar
    local railBg = self.tabRailBg
    local carrier = self.tabRailCarrier
    if not railHost or not tabBar or not self.tabButtons or not railBg then
        return
    end

    self:DetachCoASectionRail()

    if self.frame and tabBar:GetParent() ~= self.frame then
        tabBar:SetParent(self.frame)
    end

    local railW, railH = ApplyPassivesBackground(railBg, railHost, carrier)
    railBg:Show()
    PlaceSectionRail(tabBar, railHost, self.frame)

    local slots, liveLinks = BuildSectionSlots(#TAB_DEFS, railW, railH)
    local ui = GetUI()
    local arrow = ui and ui.HUB_NODE_ARROW
    local links = liveLinks
    if not links or #links == 0 then
        links = BuildSectionLinks(slots, arrow)
    end

    for i, def in ipairs(TAB_DEFS) do
        local btn = self.tabButtons[def.id]
        local slot = slots[i] or slots[#slots]
        if btn and slot then
            btn:ClearAllPoints()
            -- Icon sits on the button's RIGHT; place so icon center matches rail slot center.
            btn:SetPoint("RIGHT", railHost, "TOPLEFT", slot.cx + (NODE_SIZE / 2), slot.cy)
        end
    end

    if self.tabRailLinks then
        for _, tex in ipairs(self.tabRailLinks) do
            tex:Hide()
        end
    end
    local linkLayer = self.tabRailLinkLayer
    if linkLayer then
        ------------------------------------------------------------------
        -- LOCKED SECTIONS CONNECTORS (shipped look as of 0.9.247)
        -- Do not change tipInset, head size, layer order, or center-to-center
        -- line geometry unless the user explicitly asks to retune arrows.
        -- Lines: behind icons. Heads: above icons so tips paint on rings.
        ------------------------------------------------------------------
        linkLayer:SetFrameLevel(math.max(1, railHost:GetFrameLevel() + 1))
        if not self.tabRailHeadLayer then
            local headLayer = CreateFrame("Frame", nil, railHost)
            headLayer:SetAllPoints(railHost)
            self.tabRailHeadLayer = headLayer
        end
        local headLayer = self.tabRailHeadLayer
        self.tabRailLinks = self.tabRailLinks or {}
        local linkIndex = 0
        local outlineW = (arrow and arrow.outlineThickness) or 4
        local lineW = (arrow and arrow.lineThickness) or 2
        local fallbackHeadW = SECTION_ARROW_HEAD_W
        local fallbackHeadH = SECTION_ARROW_HEAD_H
        local lineR = (arrow and arrow.lineR) or 0.65
        local lineG = (arrow and arrow.lineG) or 0.54
        local lineB = (arrow and arrow.lineB) or 0.06
        local lineA = (arrow and arrow.lineA) or 1
        local tipInset = SECTION_ARROW_TIP_INSET

        local function AcquireLinkTex(parent, drawLayer)
            linkIndex = linkIndex + 1
            local tex = self.tabRailLinks[linkIndex]
            if not tex then
                tex = parent:CreateTexture(nil, drawLayer or "ARTWORK")
                self.tabRailLinks[linkIndex] = tex
            elseif tex.GetParent and tex:GetParent() ~= parent then
                tex:SetParent(parent)
            end
            return tex
        end

        for i = 1, #TAB_DEFS - 1 do
            local link = links[i]
            local a = slots[i]
            local b = slots[i + 1]
            if link and a and b then
                local cx = link.headCx or link.cx or a.cx
                local headW = fallbackHeadW
                local headH = fallbackHeadH
                local topY = a.cy
                local botY = b.cy
                local tipY = b.cy + (NODE_RING / 2) - tipInset

                local outline = AcquireLinkTex(linkLayer, "BACKGROUND")
                outline:SetTexture("Interface\\Buttons\\WHITE8X8")
                outline:SetVertexColor(0, 0, 0, 1)
                outline:SetWidth(outlineW)
                outline:ClearAllPoints()
                outline:SetPoint("TOP", railHost, "TOPLEFT", cx, topY)
                outline:SetPoint("BOTTOM", railHost, "TOPLEFT", cx, botY)
                outline:Show()

                local line = AcquireLinkTex(linkLayer, "BORDER")
                line:SetTexture("Interface\\Buttons\\WHITE8X8")
                line:SetVertexColor(lineR, lineG, lineB, lineA)
                line:SetWidth(lineW)
                line:ClearAllPoints()
                line:SetPoint("TOP", railHost, "TOPLEFT", cx, topY)
                line:SetPoint("BOTTOM", railHost, "TOPLEFT", cx, botY)
                line:Show()

                local head = AcquireLinkTex(headLayer, "OVERLAY")
                local usedHead = false
                if arrow and head.SetAtlas and arrow.headAtlas then
                    usedHead = pcall(function()
                        local ignore = Const and Const.TextureKit and Const.TextureKit.IgnoreAtlasSize
                        if ignore ~= nil then
                            head:SetAtlas(arrow.headAtlas, ignore)
                        else
                            head:SetAtlas(arrow.headAtlas, true)
                        end
                    end)
                    usedHead = usedHead and head.GetTexture and head:GetTexture()
                end
                if not usedHead and arrow and arrow.headPath then
                    usedHead = pcall(function()
                        head:SetTexture(arrow.headPath)
                    end)
                    usedHead = usedHead and head.GetTexture and head:GetTexture()
                end
                if not usedHead then
                    if arrow and arrow.head then
                        head:SetTexture("Interface\\TalentFrame\\talents")
                        head:SetTexCoord(arrow.head[1], arrow.head[2], arrow.head[3], arrow.head[4])
                    else
                        head:SetTexture("Interface\\Buttons\\WHITE8X8")
                        head:SetVertexColor(lineR, lineG, lineB, lineA)
                    end
                end
                ForceSize(head, headW, headH)
                head:ClearAllPoints()
                head:SetPoint("BOTTOM", railHost, "TOPLEFT", cx, tipY)
                head:Show()
            end
        end

        for _, def in ipairs(TAB_DEFS) do
            local btn = self.tabButtons[def.id]
            if btn then
                btn:SetFrameLevel(linkLayer:GetFrameLevel() + 2)
            end
        end
        headLayer:SetFrameLevel(linkLayer:GetFrameLevel() + 8)
    end
end

local function BuildSectionButtons(hub, tabBar, linkLayer, ui)
    hub.tabButtons = hub.tabButtons or {}
    for _, def in ipairs(TAB_DEFS) do
        if not hub.tabButtons[def.id] then
            local btn
            if ui and ui.CreateHubSectionButton then
                btn = ui.CreateHubSectionButton(tabBar, def.label, {
                    icon = def.icon,
                    size = NODE_SIZE,
                    ringSize = NODE_RING,
                    width = RAIL_LABEL_WIDTH + NODE_SIZE,
                    labelSide = "LEFT",
                    labelGap = RAIL_LABEL_WIDTH - 6,
                    textGap = SECTION_LABEL_TEXT_GAP,
                    textY = -3,
                    compact = true,
                })
            else
                btn = CreateFrame("Button", nil, tabBar, "UIPanelButtonTemplate")
                btn:SetWidth(NODE_SIZE)
                btn:SetHeight(NODE_SIZE)
                btn:SetText(def.label)
            end
            btn:SetHeight(NODE_SIZE)
            btn:SetFrameLevel(linkLayer:GetFrameLevel() + 2)
            local tabId = def.id
            btn:SetScript("OnClick", function()
                Hub:SelectTab(tabId)
            end)
            BindButtonTooltip(btn, def.label, def.tip)
            hub.tabButtons[def.id] = btn
        else
            hub.tabButtons[def.id]:SetParent(tabBar)
        end
    end
end

-- Tear down any rail accidentally parented onto CoA SpecTree (0.9.218–0.9.219).
function Hub:DetachCoASectionRail()
    local function Kill(frame)
        if not frame then
            return
        end
        frame:Hide()
        frame:EnableMouse(false)
        frame:ClearAllPoints()
        frame:SetParent(UIParent)
        frame:SetAlpha(0)
        if frame.SetFrameStrata then
            frame:SetFrameStrata("BACKGROUND")
        end
    end
    Kill(self.coaRailBar)
    self.coaRailBar = nil
    Kill(_G.MancerCoASectionRail)

    -- Sweep leftover named frames from older builds that sat on SpecTree.
    local specTree = GetCoASpecTree()
    if specTree then
        local ok, kids = pcall(function()
            return { specTree:GetChildren() }
        end)
        if ok and kids then
            for i = 1, #kids do
                local child = kids[i]
                local name = child and child.GetName and child:GetName()
                if name and name:find("Mancer", 1, true) then
                    Kill(child)
                end
            end
        end
    end
    self.railPinnedToCoA = false
end

-- Match CoATalentFrame on-screen size (the path where width was correct).
-- scale = coaEff/parentEff + GetWidth/GetHeight. Do not use GetLeft/Right screen-rect
-- math — that made the window massive or shoved the rail off-screen.
function Hub:SyncFrameSizeToCoA()
    local frame = self.frame
    if not frame then
        return
    end

    local coa = CoATalentFrame
    local w, h = HUB_WIDTH, HUB_HEIGHT
    local scale = 1
    local parent = frame:GetParent() or UIParent
    local parentEff = (parent.GetEffectiveScale and parent:GetEffectiveScale()) or 1
    if parentEff <= 0 then
        parentEff = 1
    end

    if coa and coa.GetWidth and coa:GetWidth() and coa:GetWidth() > 0 then
        -- Prefer live CoA layout size whenever the frame exists (open or just loaded).
        w = coa:GetWidth()
        h = coa:GetHeight()
        local coaEff = (coa.GetEffectiveScale and coa:GetEffectiveScale()) or 1
        scale = coaEff / parentEff
    end

    if scale < 0.25 or scale > 2.5 then
        scale = 1
    end
    if not w or w < 200 then
        w = HUB_WIDTH
    end
    if not h or h < 200 then
        h = HUB_HEIGHT
    end

    frame:SetScale(scale)
    frame:SetWidth(w)
    frame:SetHeight(h)
    self:SyncHubArtToCoA()
end

-- When CoA opens/closes, re-fit Hub if visible. Rail offsets stay XML-fixed.
function Hub:HookCoATalentFrame()
    if self.coaHooked then
        return
    end
    local frame = CoATalentFrame
    if not frame then
        return
    end
    self.coaHooked = true
    frame:HookScript("OnShow", function()
        Hub:DetachCoASectionRail()
        -- CoA scale/size may settle a tick after show.
        if Hub.syncTicker then
            Hub.syncTicker:SetScript("OnUpdate", nil)
            Hub.syncTicker = nil
        end
        local ticker = CreateFrame("Frame")
        local elapsed = 0
        ticker:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if elapsed < 0.05 then
                return
            end
            self:SetScript("OnUpdate", nil)
            Hub.syncTicker = nil
            if Hub.frame and Hub.frame:IsShown() then
                Hub:SyncFrameSizeToCoA()
                Hub:LayoutSectionRail()
            end
        end)
        Hub.syncTicker = ticker
        if Hub.frame and Hub.frame:IsShown() then
            Hub:SyncFrameSizeToCoA()
            Hub:LayoutSectionRail()
        end
    end)
    frame:HookScript("OnHide", function()
        if Hub.frame and Hub.frame:IsShown() then
            Hub:SyncFrameSizeToCoA()
            Hub:LayoutSectionRail()
        end
    end)
end


function Hub:RefreshTitle()
    local version = (Mancer.GetVersion and Mancer.GetVersion()) or Mancer.VERSION or ""
    local text = (Mancer.DISPLAY_NAME or "Libellus Leti") .. " " .. tostring(version)
    local frame = self.frame
    if frame and PortraitFrame_SetTitle then
        pcall(PortraitFrame_SetTitle, frame, text)
    end
    if frame and frame.TitleText then
        frame.TitleText:SetText(text)
    elseif frame and frame.TitleContainer and frame.TitleContainer.TitleText then
        frame.TitleContainer.TitleText:SetText(text)
    end
    if self.titleText then
        self.titleText:SetText(text)
    end
end

function Hub:Create()
    if self.frame then
        self:RefreshTitle()
        return
    end

    local ui = GetUI()
    local frame, chromeKind
    if ui and ui.CreateHubRootFrame then
        frame, chromeKind = ui.CreateHubRootFrame("MancerHubFrame", UIParent)
    else
        frame = CreateFrame("Frame", "MancerHubFrame", UIParent)
        chromeKind = "metal"
    end
    self.chromeKind = chromeKind
    frame:SetWidth(HUB_WIDTH)
    frame:SetHeight(HUB_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f)
        f:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        Hub:SaveFramePosition()
    end)
    frame:SetFrameStrata("DIALOG")

    if ui and ui.SkinFrame then
        -- Same grey metal border + red X as Character Advancement.
        ui.SkinFrame(frame, {
            nativeChrome = true,
            useHubArt = true,
            artScrub = 0.58,
            -- Match CoA TreeView.Background1 (user-approved 0.9.262).
            artInset = 2,
            artTopInset = 24,
            title = Mancer.DISPLAY_NAME or "Libellus Leti",
        })
    elseif ui and ui.ApplyMetalPortraitBorder then
        ui.ApplyMetalPortraitBorder(frame)
        if ui.CreateNativeCloseButton then
            ui.CreateNativeCloseButton(frame)
        end
    end
    frame:Hide()

    -- Fallback title only if native portrait title isn't present.
    if not (frame.TitleText or (frame.TitleContainer and frame.TitleContainer.TitleText) or PortraitFrame_SetTitle) then
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 58, -8)
        self.titleText = title
        if ui and ui.StyleTitle then
            ui.StyleTitle(title)
        end
    end
    self:RefreshTitle()

    -- SECTIONS rail on the Hub only. Size/atlas copied from CoA PassivesBackground
    -- (TreeView.SpecTree) — never parented onto the talent tree.
    self:DetachCoASectionRail()
    self:HookCoATalentFrame()

    local tabBar = CreateFrame("Frame", nil, frame)
    tabBar:SetWidth(RAIL_LABEL_WIDTH + RAIL_W)
    tabBar:SetHeight(RAIL_H)
    self.tabBar = tabBar
    self.railPinnedToCoA = false

    local railHost = CreateFrame("Frame", nil, tabBar)
    self.tabRailHost = railHost

    -- Carrier fills the 74×480 XML display box (CoA stretches atlas via IgnoreAtlasSize).
    local railCarrier = CreateFrame("Frame", nil, railHost)
    self.tabRailCarrier = railCarrier

    local railBg = railCarrier:CreateTexture(nil, "BACKGROUND")
    self.tabRailBg = railBg
    ApplyPassivesBackground(railBg, railHost, railCarrier)
    PlaceSectionRail(tabBar, railHost, frame)

    local linkLayer = CreateFrame("Frame", nil, railHost)
    linkLayer:SetAllPoints(railHost)
    linkLayer:SetFrameLevel(railHost:GetFrameLevel() + 1)
    self.tabRailLinkLayer = linkLayer
    self.tabRailLinks = {}

    local railLabel = tabBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    railLabel:SetPoint("BOTTOM", railHost, "TOP", 0, 6)
    railLabel:SetJustifyH("CENTER")
    railLabel:SetText("SECTIONS")
    if ui and ui.StyleMuted then
        ui.StyleMuted(railLabel)
    end

    BuildSectionButtons(self, tabBar, linkLayer, ui)
    self:LayoutSectionRail()

    -- Live summary strip (left content, clear of portrait/title chrome)
    self.summaryText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.summaryText:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -58)
    self.summaryText:SetPoint("RIGHT", tabBar, "LEFT", -14, 0)
    self.summaryText:SetJustifyH("LEFT")
    self.summaryText:SetText("Reading live stats…")
    if ui and ui.StyleMuted then
        ui.StyleMuted(self.summaryText)
    end

    local scroll = CreateFrame("ScrollFrame", "MancerHubScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -88)
    scroll:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 28)
    scroll:SetPoint("RIGHT", tabBar, "LEFT", -14, 0)
    self.scroll = scroll

    self.pages = {}

    -- ── Combat ──────────────────────────────────────────────
    do
        local page = CreatePage(frame)
        local header = CreateSection(page, "Army picks & DPS", nil, 0)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
        header:SetWidth(440)

        local row1 = CreateButtonRow(page, header, -8, {
            { id = "stAoe", text = "ST vs AOE", tooltip = "Which minions for bosses vs packs — plain English", onClick = function() Hub:ShowStVsAoe() end },
            { id = "combo", text = "LF Combo", tooltip = "Best Life Force army for bosses (one target)", onClick = function() Hub:ShowCombo() end },
            { id = "dps", text = "DPS", tooltip = "Current / last fight minion DPS (auto-records in combat)", onClick = function() Hub:ShowMinionDps("auto") end },
            { id = "save", text = "Save DPS", tooltip = "Copy last fight DPS to clipboard / text you can paste into a .txt file", onClick = function() Hub:SaveDpsFight() end },
            {
                id = "macros",
                text = "Install Macros",
                width = 120,
                tooltip = "Create character macros: Lichfrost / Crypt Swarm / Harvest Plague / Command: Undead / Blight / Unholy Frenzy + Grave March. Never overwrites existing macros.",
                onClick = function() Hub:InstallPlayerMacros() end,
            },
        })
        page.combatButtons = row1.buttonsById
        page.combatButtonRow = row1

        local contentW = Hub.CONTENT_WIDTH or 980
        local gap = 24
        local colW = math.floor((contentW - gap) / 2)
        local ui = GetUI()

        local detailTitle = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        detailTitle:SetPoint("TOPLEFT", row1, "BOTTOMLEFT", 0, -16)
        detailTitle:SetJustifyH("LEFT")
        detailTitle:SetText("")
        if ui and ui.StyleTitle then
            ui.StyleTitle(detailTitle)
        end
        page.detailTitle = detailTitle

        local detailBody = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        detailBody:SetPoint("TOPLEFT", detailTitle, "BOTTOMLEFT", 0, -10)
        detailBody:SetWidth(contentW - 24)
        detailBody:SetJustifyH("LEFT")
        detailBody:SetJustifyV("TOP")
        detailBody:SetSpacing(3)
        detailBody:SetText("Pick a button above to show army / DPS info here.")
        if ui and ui.StyleMuted then
            ui.StyleMuted(detailBody)
        end
        page.detailBody = detailBody

        local stIntro = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        stIntro:SetPoint("TOPLEFT", detailTitle, "BOTTOMLEFT", 0, -10)
        stIntro:SetWidth(contentW - 8)
        stIntro:SetJustifyH("LEFT")
        stIntro:SetJustifyV("TOP")
        stIntro:SetSpacing(2)
        stIntro:SetText("")
        if ui and ui.StyleMuted then
            ui.StyleMuted(stIntro)
        end
        page.stIntro = stIntro

        local stHeader = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        stHeader:SetPoint("TOPLEFT", stIntro, "BOTTOMLEFT", 0, -12)
        stHeader:SetWidth(colW)
        stHeader:SetJustifyH("LEFT")
        stHeader:SetText("Boss / one target")
        if ui and ui.StyleTitle then
            ui.StyleTitle(stHeader)
        end
        page.stHeader = stHeader

        local aoeHeader = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        aoeHeader:SetPoint("TOPLEFT", stIntro, "BOTTOMLEFT", colW + gap, -12)
        aoeHeader:SetWidth(colW)
        aoeHeader:SetJustifyH("LEFT")
        aoeHeader:SetText("Packs / AoE")
        if ui and ui.StyleTitle then
            ui.StyleTitle(aoeHeader)
        end
        page.aoeHeader = aoeHeader

        local stCol = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        stCol:SetPoint("TOPLEFT", stHeader, "BOTTOMLEFT", 0, -6)
        stCol:SetWidth(colW)
        stCol:SetJustifyH("LEFT")
        stCol:SetJustifyV("TOP")
        stCol:SetSpacing(3)
        stCol:SetText("")
        page.stCol = stCol

        local aoeCol = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        aoeCol:SetPoint("TOPLEFT", aoeHeader, "BOTTOMLEFT", 0, -6)
        aoeCol:SetWidth(colW)
        aoeCol:SetJustifyH("LEFT")
        aoeCol:SetJustifyV("TOP")
        aoeCol:SetSpacing(3)
        aoeCol:SetText("")
        page.aoeCol = aoeCol

        local cheat = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        cheat:SetPoint("TOPLEFT", stCol, "BOTTOMLEFT", 0, -16)
        cheat:SetWidth(contentW - 8)
        cheat:SetJustifyH("LEFT")
        cheat:SetJustifyV("TOP")
        cheat:SetSpacing(3)
        cheat:SetText("")
        if ui and ui.StyleMuted then
            ui.StyleMuted(cheat)
        end
        page.cheatText = cheat

        -- Start in report/placeholder mode (ST vs AOE columns hidden).
        stIntro:Hide()
        stHeader:Hide()
        aoeHeader:Hide()
        stCol:Hide()
        aoeCol:Hide()
        cheat:Hide()

        page.lastWidget = detailBody
        self.pages.combat = page
    end

    -- ── Minions ─────────────────────────────────────────────
    -- LOCKED (0.9.267): placeholder only; SelectTab("minions") opens the sheet directly.
    do
        local page = CreatePage(frame)
        page:SetWidth(1)
        page:SetHeight(1)
        page.lastWidget = page
        self.pages.minions = page
    end

    -- ── Theory ──────────────────────────────────────────────
    do
        local page = CreatePage(frame)
        local header = CreateSection(page, "Build helpers", nil, 0)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
        header:SetWidth(440)

        local row1 = CreateButtonRow(page, header, -8, {
            {
                id = "statPriority",
                text = "Stat Priority",
                tooltip = "Hit / haste / crit soft caps with live % bars",
                onClick = function() Hub:ShowStatPriority() end,
            },
            {
                id = "paper",
                text = "Paper",
                tooltip = "Estimated DPS from your sheet stats",
                onClick = function() Hub:ShowPaperMath() end,
            },
            {
                id = "buffs",
                text = "Buffs",
                tooltip = "Preferred buffs: Grim Mandate, Razorice, Bone Ward, Chill of the Tomb",
                onClick = function() Hub:ShowBuffPicks() end,
            },
        })
        page.theoryButtons = row1.buttonsById
        page.theoryButtonRow = row1

        local contentW = Hub.CONTENT_WIDTH or 980
        local ui = GetUI()

        local detailTitle = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        detailTitle:SetPoint("TOPLEFT", row1, "BOTTOMLEFT", 0, -16)
        detailTitle:SetJustifyH("LEFT")
        detailTitle:SetText("")
        if ui and ui.StyleTitle then
            ui.StyleTitle(detailTitle)
        end
        page.detailTitle = detailTitle

        local detailBody = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        detailBody:SetPoint("TOPLEFT", detailTitle, "BOTTOMLEFT", 0, -10)
        detailBody:SetWidth(contentW - 24)
        detailBody:SetJustifyH("LEFT")
        detailBody:SetJustifyV("TOP")
        detailBody:SetSpacing(3)
        detailBody:SetText("Pick a button above to show guides here.")
        if ui and ui.StyleMuted then
            ui.StyleMuted(detailBody)
        end
        page.detailBody = detailBody

        local host = CreateFrame("Frame", nil, page)
        host:SetPoint("TOPLEFT", detailTitle, "BOTTOMLEFT", 0, -10)
        host:SetWidth(contentW - 24)
        host:SetHeight(1)
        host:Hide()
        page.statHost = host

        page.lastWidget = detailBody
        self.pages.theory = page
    end

    -- ── Setup ───────────────────────────────────────────────
    -- Placeholder only; SelectTab("setup") opens Display directly.
    do
        local page = CreatePage(frame)
        page:SetWidth(1)
        page:SetHeight(1)
        page.lastWidget = page
        self.pages.setup = page
    end

    -- ── Credits ─────────────────────────────────────────────
    do
        local page = CreatePage(frame)
        local header = CreateSection(page, "Thanks", nil, 0)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
        header:SetWidth(640)

        local body = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -12)
        body:SetWidth(640)
        body:SetJustifyH("LEFT")
        body:SetSpacing(4)
        body:SetText(
            (Mancer.DISPLAY_NAME or "Libellus Leti") .. " is built for casual Animation Necromancers on Ascension.\n\n"
                .. "Huge thanks to everyone who tested builds, shared feedback, and helped dig through "
                .. "talent / UI files so the Hub, tooltips, and minion tools could ship.\n\n"
                .. "Author: Mortuus (Discord: LtGenZombie)\n"
                .. "If this addon helped your necro, share it with another undead friend."
        )
        if ui and ui.StyleMuted then
            ui.StyleMuted(body)
        end
        page.lastWidget = body
        self.pages.credits = page
    end

    self.statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.statusText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 12)
    self.statusText:SetPoint("BOTTOMRIGHT", tabBar, "BOTTOMLEFT", -14, 12)
    self.statusText:SetJustifyH("LEFT")
    self.statusText:SetText("Ready")
    if ui and ui.StyleMuted then
        ui.StyleMuted(self.statusText)
    end

    frame:SetScript("OnShow", function()
        Hub:RefreshTitle()
        if GetUI() and GetUI().ApplyHubPortraitMark then
            GetUI().ApplyHubPortraitMark(Hub.frame)
        end
        Hub:DetachCoASectionRail()
        Hub:HookCoATalentFrame()
        Hub:SyncFrameSizeToCoA()
        Hub:SyncHubArtToCoA()
        Hub:LayoutSectionRail()
        Hub:SamplePlaguefatherOffset()
        Hub:SampleStatsTextRect()
        Hub:SyncControls()
        local tab = (MancerDB and MancerDB.hub and MancerDB.hub.tab) or Hub.activeTab or "combat"
        if tab == "setup" then
            tab = "combat"
        end
        Hub:SelectTab(tab)
    end)
    frame:HookScript("OnHide", function()
        if Hub.viewMode then
            Hub:LeaveContentView()
        end
    end)

    if UISpecialFrames then
        tinsert(UISpecialFrames, "MancerHubFrame")
    end

    self.frame = frame
    self:SyncFrameSizeToCoA()
    self:ApplySavedPosition()

    local startTab = (MancerDB and MancerDB.hub and MancerDB.hub.tab) or "combat"
    if startTab == "setup" then
        startTab = "combat"
    end
    self:SelectTab(startTab)
end

function Hub:Open()
    self:Create()
    if self.frame then
        self.frame:Show()
    end
end

function Hub:Toggle()
    self:Create()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
    end
end
