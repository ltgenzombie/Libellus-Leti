-- Animation Necromancer ST stat priority / soft-cap ladder.
-- Soft numbers are research-backed starting estimates (Ascension wiki + community
-- caster guides); retune BREAKPOINTS below as live play proves better values.
Mancer.StatPriorityModule = {}
local StatPriority = Mancer.StatPriorityModule

-- Ordered gearing steps. Caps with targetPct are checked live; intellect is the
-- primary stack after early haste (no numeric soft cap).
-- Sources:
--   spell hit 17%  — Ascension Stats wiki (boss +3 hard cap)
--   haste 12%      — early comfort soft (community pattern)
--   intellect      — primary throughput after early haste (ability coeffs + crit)
--   crit 25%       — Pure Shadow Ascension build guide soft aim
--   haste 17.5%    — Pure Shadow “GCD capped” community soft aim
StatPriority.BREAKPOINTS = {
    {
        id = "spellHit",
        label = "Spell hit",
        kind = "cap",
        stat = "spellHitPct",
        ratingKey = "spellHitRating",
        ratingTableKey = "spellHit",
        ratingName = "hit rating",
        targetPct = 17,
        why = "Hard cap vs +3 bosses — rating past this is nearly waste.",
        source = "Ascension Stats wiki hit table",
    },
    {
        id = "hasteEarly",
        label = "Haste (early)",
        kind = "cap",
        stat = "hastePct",
        ratingKey = "hasteRating",
        ratingTableKey = "haste",
        ratingName = "haste rating",
        targetPct = 12,
        why = "Early gear soft so casts/GCD feel smooth before stacking INT.",
        source = "Community early-comfort pattern",
    },
    {
        id = "intellect",
        label = "Intellect",
        kind = "primary",
        why = "Primary stack after early haste — feeds damage coeffs and spell crit.",
        source = "Animation INT/SP tooltip coefficients + PaperMath",
    },
    {
        id = "crit",
        label = "Crit",
        kind = "cap",
        -- Sheet aim = rating crit + INT crit; deficit reported as crit rating to close the gap.
        stat = "spellCritPct",
        ratingKey = "critRating",
        ratingTableKey = "crit",
        ratingName = "crit rating",
        targetPct = 25,
        why = "Soft sheet aim (rating + INT crit); keep scaling past this if free.",
        source = "Ascension Pure Shadow build guide",
    },
    {
        id = "hasteGcd",
        label = "Haste (GCD soft)",
        kind = "cap",
        stat = "hastePct",
        ratingKey = "hasteRating",
        ratingTableKey = "haste",
        ratingName = "haste rating",
        targetPct = 17.5,
        why = "Community GCD-aligned soft; after this prefer INT/SP/crit if free.",
        source = "Ascension Pure Shadow build guide (~17.5%)",
    },
}

StatPriority.TALENT_HASTE_NOTES = {
    "Mindless Fury — haste stacks on Animate/Command (talent haste, not gear rating).",
    "Depravity — talent haste on top of gear.",
    "Army of the Dead — +10% ghoul haste (minion side, not your gear soft cap).",
}

local function Paper()
    return Mancer.PaperMathModule
end

function StatPriority:GetLiveStats()
    local pm = Paper()
    if not pm or not pm.GetPlayerPaperStats then
        return nil
    end
    local p = pm:GetPlayerPaperStats()
    if not p then
        return nil
    end
    local spellCritPct = (p.critPctFromRating or 0) + (p.spellCritFromInt or 0)
    return {
        level = p.level,
        ratingLevel = p.ratingLevel,
        intellect = p.intellect or 0,
        spellDamage = p.spellDamage or 0,
        spellHitPct = p.spellHitPct or 0,
        spellHitRating = p.spellHitRating or 0,
        hastePct = p.hastePct or 0,
        hasteRating = p.hasteRating or 0,
        critPctFromRating = p.critPctFromRating or 0,
        spellCritFromInt = p.spellCritFromInt or 0,
        spellCritPct = spellCritPct,
        critRating = p.critRating or 0,
    }
end

function StatPriority:IsStepMet(step, stats)
    if not step or not stats then
        return false
    end
    if step.kind == "primary" then
        -- No numeric cap — treated as the active stack phase after early gates.
        return false
    end
    local live = stats[step.stat]
    if live == nil or step.targetPct == nil then
        return false
    end
    return live + 0.05 >= step.targetPct
end

--- First unmet hard/soft step. Intellect becomes active once hit + early haste
--- are met; later soft caps ride along as unfinished checklist items.
function StatPriority:GetActiveStep(stats)
    if not stats then
        return nil, {}
    end

    local unfinishedSoft = {}
    local earlyGatesMet = true
    local primaryStep = nil
    local active = nil

    for _, step in ipairs(self.BREAKPOINTS) do
        if step.kind == "primary" then
            primaryStep = step
        elseif not self:IsStepMet(step, stats) then
            if not primaryStep then
                -- Still before INT — hit / early haste
                earlyGatesMet = false
                if not active then
                    active = step
                end
            else
                table.insert(unfinishedSoft, step)
            end
        end
    end

    if earlyGatesMet and primaryStep then
        active = primaryStep
    else
        unfinishedSoft = {}
    end

    return active, unfinishedSoft
end

local function FormatPct(n)
    return string.format("%.1f%%", n or 0)
end

--- How far below a cap step (percent + rating), using PaperMath level rating table.
--- Returns needPct, needRating, ratingPerPercent (needRating 0 if met / unknown).
function StatPriority:GetCapDeficit(step, stats)
    if not step or step.kind ~= "cap" or not stats or not step.targetPct then
        return 0, 0, 0
    end
    local live = stats[step.stat] or 0
    local needPct = math.max(0, step.targetPct - live)
    if needPct <= 0 then
        return 0, 0, 0
    end

    local pm = Paper()
    if not pm or not pm.GetRatingTable or not pm.PercentToRating then
        return needPct, 0, 0
    end
    local table = pm:GetRatingTable(stats.level)
    local per = table and step.ratingTableKey and table[step.ratingTableKey] or 0
    local needRating = pm:PercentToRating(needPct, per)
    return needPct, needRating, per
end

local function FormatDeficit(step, needPct, needRating)
    if (needRating or 0) > 0 then
        return string.format(
            "need ~%d %s (~%s)",
            needRating,
            step.ratingName or "rating",
            FormatPct(needPct)
        )
    end
    return string.format("need ~%s", FormatPct(needPct))
end

function StatPriority:PrintGuide()
    local stats = self:GetLiveStats()
    Mancer.Print("Animation ST stat priority (research-backed soft caps)")
    Mancer.Print("Gear haste/hit/crit from PaperMath rating table; talent haste is separate.")
    Mancer.Print("")

    if not stats then
        Mancer.Print("PaperMath not available — cannot read live stats.")
        return
    end

    local active, unfinishedSoft = self:GetActiveStep(stats)
    local activeId = active and active.id

    Mancer.Print(string.format(
        "Live (lvl %s, rating table %s): hit %s | haste %s | crit ~%s (rating %s + INT %s) | INT %d | SP %d",
        tostring(stats.level),
        tostring(stats.ratingLevel),
        FormatPct(stats.spellHitPct),
        FormatPct(stats.hastePct),
        FormatPct(stats.spellCritPct),
        FormatPct(stats.critPctFromRating),
        FormatPct(stats.spellCritFromInt),
        stats.intellect or 0,
        stats.spellDamage or 0
    ))
    Mancer.Print("")

    Mancer.Print("Priority ladder")
    for i, step in ipairs(self.BREAKPOINTS) do
        local marker = " "
        local status = ""
        if step.kind == "primary" then
            if activeId == step.id then
                marker = ">"
                status = " ← next: stack this"
            else
                status = " (primary when early gates are met)"
            end
        else
            local live = stats[step.stat] or 0
            local met = self:IsStepMet(step, stats)
            local needPct, needRating = self:GetCapDeficit(step, stats)
            if met then
                marker = "x"
                status = string.format("  %s / %s", FormatPct(live), FormatPct(step.targetPct))
            elseif activeId == step.id then
                marker = ">"
                status = string.format(
                    "  %s / %s  ← %s",
                    FormatPct(live),
                    FormatPct(step.targetPct),
                    FormatDeficit(step, needPct, needRating)
                )
            else
                marker = " "
                if needRating > 0 or needPct > 0 then
                    status = string.format(
                        "  %s / %s (%s)",
                        FormatPct(live),
                        FormatPct(step.targetPct),
                        FormatDeficit(step, needPct, needRating)
                    )
                else
                    status = string.format("  %s / %s", FormatPct(live), FormatPct(step.targetPct))
                end
            end
        end
        Mancer.Print(string.format(
            "  [%s] %d. %s%s — %s",
            marker,
            i,
            step.label,
            status,
            step.why
        ))
    end

    Mancer.Print("")
    if active then
        if active.kind == "primary" then
            Mancer.Print("Next aim: stack Intellect (and Spell Power on gear).")
            if unfinishedSoft and #unfinishedSoft > 0 then
                Mancer.Print("Also finish soft caps:")
                for _, step in ipairs(unfinishedSoft) do
                    local live = stats[step.stat] or 0
                    local needPct, needRating = self:GetCapDeficit(step, stats)
                    Mancer.Print(string.format(
                        "  - %s %s / %s — %s",
                        step.label,
                        FormatPct(live),
                        FormatPct(step.targetPct),
                        FormatDeficit(step, needPct, needRating)
                    ))
                end
            else
                Mancer.Print("Soft caps look met — keep stacking INT/SP; take haste/crit when free.")
            end
        else
            local live = stats[active.stat] or 0
            local needPct, needRating = self:GetCapDeficit(active, stats)
            Mancer.Print(string.format(
                "Next aim: %s — %s (now %s / %s).",
                active.label,
                FormatDeficit(active, needPct, needRating),
                FormatPct(live),
                FormatPct(active.targetPct)
            ))
        end
    end

    Mancer.Print("")
    Mancer.Print("Talent haste (not counted in gear soft caps above):")
    for _, note in ipairs(self.TALENT_HASTE_NOTES) do
        Mancer.Print("  - " .. note)
    end
end

-- ── Structured panel (embedded in Hub → Guides → Stat Priority) ────────────

local ROW_WIDTH = 640
local BAR_WIDTH = 220

local function UI()
    return Mancer.UI
end

local function ColorUnpack(c)
    return c[1], c[2], c[3], c[4] or 1
end

local function StatusColor(kind)
    local ui = UI()
    local colors = ui and ui.Colors or {}
    if kind == "met" then
        return colors.ok or { 0.35, 0.85, 0.55, 1 }
    elseif kind == "next" then
        return colors.next or colors.accent or { 0.25, 0.95, 0.75, 1 }
    elseif kind == "soft" then
        return colors.warn or { 0.95, 0.78, 0.28, 1 }
    end
    return colors.muted or { 0.55, 0.60, 0.62, 1 }
end

local function SetTextColor(fs, color)
    if fs and color then
        fs:SetTextColor(ColorUnpack(color))
    end
end

local function CreateStatChip(parent, label)
    local chip = CreateFrame("Frame", nil, parent)
    chip:SetSize(108, 36)

    local ui = UI()
    local bg = chip:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetAllPoints()
    local inset = (ui and ui.Colors and ui.Colors.bgInset) or { 0.11, 0.12, 0.14, 0.95 }
    bg:SetVertexColor(ColorUnpack(inset))
    chip.bg = bg

    local border = chip:CreateTexture(nil, "BORDER")
    border:SetTexture("Interface\\Buttons\\WHITE8X8")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    local bc = (ui and ui.Colors and ui.Colors.border) or { 0.22, 0.28, 0.30, 1 }
    border:SetVertexColor(ColorUnpack(bc))
    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT", chip, "TOPLEFT", 0, 0)
    bg:SetPoint("BOTTOMRIGHT", chip, "BOTTOMRIGHT", 0, 0)
    chip.border = border

    local name = chip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetPoint("TOPLEFT", 6, -4)
    name:SetText(label or "")
    SetTextColor(name, (ui and ui.Colors and ui.Colors.muted) or { 0.55, 0.60, 0.62, 1 })
    chip.name = name

    local value = chip:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    value:SetPoint("BOTTOMLEFT", 6, 5)
    value:SetText("—")
    SetTextColor(value, (ui and ui.Colors and ui.Colors.title) or { 0.92, 0.95, 0.97, 1 })
    chip.value = value

    chip.SetValue = function(self, text, color)
        self.value:SetText(text or "—")
        if color then
            SetTextColor(self.value, color)
        end
    end

    return chip
end

local function CreateLadderRow(parent, step, index, rowWidth)
    local width = rowWidth or ROW_WIDTH
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width, 44)
    row.step = step
    row.index = index

    local marker = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    marker:SetPoint("TOPLEFT", 0, -2)
    marker:SetWidth(18)
    marker:SetJustifyH("CENTER")
    marker:SetText(tostring(index))
    row.marker = marker

    local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 22, -2)
    title:SetText(step.label or "")
    row.title = title

    local values = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    values:SetPoint("TOPRIGHT", 0, -2)
    values:SetJustifyH("RIGHT")
    values:SetText("")
    row.values = values

    local bar
    local ui = UI()
    if ui and ui.CreateStatBar then
        bar = ui.CreateStatBar(row, BAR_WIDTH, 10)
        bar:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    end
    row.bar = bar

    local detail = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if bar then
        detail:SetPoint("LEFT", bar, "RIGHT", 10, 0)
    else
        detail:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    end
    detail:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    detail:SetJustifyH("LEFT")
    detail:SetText("")
    row.detail = detail

    return row
end

--- Build (or reuse) the ladder UI as a child of `parent` for Hub embedding.
function StatPriority:EnsureContent(parent, width)
    if not parent then
        return nil
    end
    if self.content and self.content._mancerParent == parent then
        return self.content
    end

    if self.content then
        self.content:Hide()
        self.content:SetParent(nil)
        self.content = nil
    end
    -- Hide legacy floating panel if it was created on an older build.
    if self.panel then
        self.panel:Hide()
    end

    local ui = UI()
    local rowWidth = math.max(ROW_WIDTH, math.floor(tonumber(width) or ROW_WIDTH))
    local frame = CreateFrame("Frame", "MancerStatPriorityContent", parent)
    frame._mancerParent = parent
    frame:SetWidth(rowWidth)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    subtitle:SetWidth(rowWidth)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("live gear vs soft caps")
    if ui and ui.StyleMuted then
        ui.StyleMuted(subtitle)
    end
    frame.subtitle = subtitle

    local refreshBtn
    if ui and ui.CreateButton then
        refreshBtn = ui.CreateButton(frame, "Refresh", 72, 22)
    else
        refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        refreshBtn:SetSize(72, 22)
        refreshBtn:SetText("Refresh")
    end
    refreshBtn:ClearAllPoints()
    refreshBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 2)
    refreshBtn:SetScript("OnClick", function()
        StatPriority:RefreshPanel()
    end)
    frame.refreshBtn = refreshBtn

    local y = -28

    local nextBanner = CreateFrame("Frame", nil, frame)
    nextBanner:SetSize(rowWidth, 40)
    nextBanner:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, y)
    local nbBg = nextBanner:CreateTexture(nil, "BACKGROUND")
    nbBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    nbBg:SetAllPoints()
    nbBg:SetVertexColor(0.10, 0.18, 0.16, 0.95)
    nextBanner.bg = nbBg
    local nextLabel = nextBanner:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nextLabel:SetPoint("TOPLEFT", 10, -5)
    nextLabel:SetText("NEXT AIM")
    SetTextColor(nextLabel, StatusColor("next"))
    nextBanner.label = nextLabel
    local nextText = nextBanner:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nextText:SetPoint("TOPLEFT", 10, -18)
    nextText:SetPoint("RIGHT", nextBanner, "RIGHT", -10, 0)
    nextText:SetJustifyH("LEFT")
    nextText:SetText("—")
    nextBanner.text = nextText
    frame.nextBanner = nextBanner
    y = y - 48

    local chipRow = CreateFrame("Frame", nil, frame)
    chipRow:SetSize(rowWidth, 40)
    chipRow:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, y)
    frame.chips = {}
    local chipDefs = {
        { id = "hit", label = "Hit" },
        { id = "haste", label = "Haste" },
        { id = "crit", label = "Crit" },
        { id = "int", label = "INT" },
    }
    for i, def in ipairs(chipDefs) do
        local chip = CreateStatChip(chipRow, def.label)
        chip:SetPoint("TOPLEFT", chipRow, "TOPLEFT", (i - 1) * 116, 0)
        frame.chips[def.id] = chip
    end
    y = y - 50

    local ladderHeader
    if ui and ui.CreateSection then
        ladderHeader = ui.CreateSection(frame, "Priority ladder", nil, 0)
        ladderHeader:ClearAllPoints()
        ladderHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, y)
        ladderHeader:SetWidth(rowWidth)
    else
        ladderHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        ladderHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, y)
        ladderHeader:SetText("Priority ladder")
    end
    frame.ladderHeader = ladderHeader
    y = y - 28

    frame.rows = {}
    for i, step in ipairs(self.BREAKPOINTS) do
        local row = CreateLadderRow(frame, step, i, rowWidth)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, y)
        frame.rows[step.id] = row
        y = y - 50
    end

    local notesHeader
    if ui and ui.CreateSection then
        notesHeader = ui.CreateSection(frame, "Talent haste (not in gear caps)", nil, 0)
        notesHeader:ClearAllPoints()
        notesHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, y)
        notesHeader:SetWidth(rowWidth)
    else
        notesHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        notesHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, y)
        notesHeader:SetText("Talent haste (not in gear caps)")
    end
    y = y - 26

    frame.noteLines = {}
    for i, note in ipairs(self.TALENT_HASTE_NOTES) do
        local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, y)
        fs:SetWidth(rowWidth - 8)
        fs:SetJustifyH("LEFT")
        fs:SetText("- " .. note)
        if ui and ui.StyleMuted then
            ui.StyleMuted(fs)
        end
        frame.noteLines[i] = fs
        y = y - 16
    end

    frame:SetHeight(math.max(400, -y + 8))
    self.content = frame
    return frame
end

function StatPriority:RefreshPanel()
    local frame = self.content
    if not frame then
        return
    end
    local stats = self:GetLiveStats()
    local ui = UI()
    local muted = (ui and ui.Colors and ui.Colors.muted) or { 0.55, 0.60, 0.62, 1 }
    local titleC = (ui and ui.Colors and ui.Colors.title) or { 0.92, 0.95, 0.97, 1 }

    if not stats then
        frame.nextBanner.text:SetText("PaperMath not available — cannot read live stats.")
        return
    end

    if frame.subtitle then
        frame.subtitle:SetText(string.format(
            "lvl %s · rating table %s · live gear vs soft caps",
            tostring(stats.level),
            tostring(stats.ratingLevel)
        ))
    end

    if frame.chips.hit then
        frame.chips.hit:SetValue(FormatPct(stats.spellHitPct), titleC)
    end
    if frame.chips.haste then
        frame.chips.haste:SetValue(FormatPct(stats.hastePct), titleC)
    end
    if frame.chips.crit then
        frame.chips.crit:SetValue(FormatPct(stats.spellCritPct), titleC)
    end
    if frame.chips.int then
        frame.chips.int:SetValue(tostring(stats.intellect or 0), titleC)
    end

    local active, unfinishedSoft = self:GetActiveStep(stats)
    local activeId = active and active.id
    local softIds = {}
    for _, step in ipairs(unfinishedSoft or {}) do
        softIds[step.id] = true
    end

    if active then
        if active.kind == "primary" then
            local extra = ""
            if unfinishedSoft and #unfinishedSoft > 0 then
                local parts = {}
                for _, step in ipairs(unfinishedSoft) do
                    local needPct, needRating = self:GetCapDeficit(step, stats)
                    table.insert(parts, FormatDeficit(step, needPct, needRating))
                end
                extra = "  ·  also " .. table.concat(parts, "; ")
            end
            frame.nextBanner.text:SetText("Stack Intellect / Spell Power" .. extra)
        else
            local needPct, needRating = self:GetCapDeficit(active, stats)
            local live = stats[active.stat] or 0
            frame.nextBanner.text:SetText(string.format(
                "%s — %s  (%s / %s)",
                active.label,
                FormatDeficit(active, needPct, needRating),
                FormatPct(live),
                FormatPct(active.targetPct)
            ))
        end
        SetTextColor(frame.nextBanner.text, StatusColor("next"))
    else
        frame.nextBanner.text:SetText("Soft caps met — keep stacking INT / SP.")
        SetTextColor(frame.nextBanner.text, StatusColor("met"))
    end

    for _, step in ipairs(self.BREAKPOINTS) do
        local row = frame.rows[step.id]
        if row then
            local isNext = activeId == step.id
            local isMet = step.kind == "cap" and self:IsStepMet(step, stats)
            local isSoft = softIds[step.id]
            local color
            if isMet then
                color = StatusColor("met")
                row.marker:SetText("x")
            elseif isNext then
                color = StatusColor("next")
                row.marker:SetText(">")
            elseif isSoft then
                color = StatusColor("soft")
                row.marker:SetText("*")
            else
                color = muted
                row.marker:SetText(tostring(row.index))
            end
            SetTextColor(row.marker, color)
            SetTextColor(row.title, isNext and StatusColor("next") or titleC)

            if step.kind == "primary" then
                row.values:SetText(isNext and "stack now" or "primary")
                SetTextColor(row.values, isNext and StatusColor("next") or muted)
                if row.bar then
                    row.bar:SetProgress(isNext and 0.35 or 0.15, color)
                end
                row.detail:SetText(step.why or "")
                SetTextColor(row.detail, muted)
            else
                local live = stats[step.stat] or 0
                local target = step.targetPct or 1
                local ratio = 0
                if target > 0 then
                    ratio = live / target
                    if ratio > 1 then
                        ratio = 1
                    end
                end
                row.values:SetText(string.format("%s / %s", FormatPct(live), FormatPct(target)))
                SetTextColor(row.values, color)

                if row.bar then
                    row.bar:SetProgress(ratio, color)
                end

                if isMet then
                    row.detail:SetText("met")
                    SetTextColor(row.detail, StatusColor("met"))
                else
                    local needPct, needRating = self:GetCapDeficit(step, stats)
                    row.detail:SetText(FormatDeficit(step, needPct, needRating))
                    SetTextColor(row.detail, isNext and StatusColor("next") or (isSoft and StatusColor("soft") or muted))
                end
            end
        end
    end
end

--- Embed into a Hub host frame. Returns the content frame (for scroll sizing).
function StatPriority:ShowInHost(parent, width)
    local frame = self:EnsureContent(parent, width)
    if not frame then
        return nil
    end
    frame:Show()
    self:RefreshPanel()
    return frame
end

-- Back-compat: Hub used to open a floating window; now embeds via ShowInHost.
function StatPriority:ShowPanel()
    if Mancer.Hub and Mancer.Hub.ShowStatPriority then
        Mancer.Hub:ShowStatPriority()
        return
    end
    if Mancer.Print then
        Mancer.Print("Open Mancer Hub → Guides → Stat Priority.")
    end
end
