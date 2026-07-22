-- CoA talent-tree route overlay: toggleable, click-through highlights.
-- Highlights stay up while you spend — no need to dismiss between picks.
Mancer.TalentOverlayModule = {}
local Overlay = Mancer.TalentOverlayModule

local WHITE = "Interface\\Buttons\\WHITE8X8"
local ACCENT = { 0.25, 0.95, 0.75, 0.95 }
local NEXT = { 1.0, 0.85, 0.25, 1 }
local FREE = { 0.35, 0.85, 1.0, 1 }
local SOON = { 0.25, 0.95, 0.75, 0.45 }
local BLOCKED = { 0.95, 0.55, 0.20, 0.95 }

local function DB()
    MancerDB = MancerDB or {}
    MancerDB.talentOverlay = MancerDB.talentOverlay or {}
    if MancerDB.talentOverlay.show == nil then
        -- Off by default so the tree stays clean until you ask for it.
        MancerDB.talentOverlay.show = false
    end
    return MancerDB.talentOverlay
end

local function GetRoute()
    return Mancer.TalentRouteModule
end

local function StripName(name)
    if not name then
        return nil
    end
    name = tostring(name)
    name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if CoACharacterAdvancementUtil and CoACharacterAdvancementUtil.StripArchitectTag then
        name = CoACharacterAdvancementUtil.StripArchitectTag(name) or name
    end
    return name:gsub("^%s+", ""):gsub("%s+$", "")
end

local function EntryName(entry)
    if not entry then
        return nil
    end
    return StripName(entry.Name or entry.name)
end

function Overlay:IsEnabled()
    return DB().show and true or false
end

function Overlay:SetEnabled(enabled)
    DB().show = enabled and true or false
    self:ApplyVisibility()
    self:Refresh()
end

function Overlay:Toggle()
    self:SetEnabled(not self:IsEnabled())
end

local function EnsureHighlight(node)
    if node.mancerRouteGlow then
        return node.mancerRouteGlow
    end
    -- Parent to the talent button; mouse OFF so clicks still hit the talent.
    local glow = CreateFrame("Frame", nil, node)
    glow:SetAllPoints(node)
    glow:EnableMouse(false)
    glow:SetFrameLevel((node:GetFrameLevel() or 1) + 8)

    -- Four-edge ring (no fill) so the talent icon stays clickable/visible.
    local function Edge(point)
        local t = glow:CreateTexture(nil, "OVERLAY")
        t:SetTexture(WHITE)
        if point == "TOP" then
            t:SetPoint("TOPLEFT", -4, 4)
            t:SetPoint("TOPRIGHT", 4, 4)
            t:SetHeight(3)
        elseif point == "BOTTOM" then
            t:SetPoint("BOTTOMLEFT", -4, -4)
            t:SetPoint("BOTTOMRIGHT", 4, -4)
            t:SetHeight(3)
        elseif point == "LEFT" then
            t:SetPoint("TOPLEFT", -4, 4)
            t:SetPoint("BOTTOMLEFT", -4, -4)
            t:SetWidth(3)
        else
            t:SetPoint("TOPRIGHT", 4, 4)
            t:SetPoint("BOTTOMRIGHT", 4, -4)
            t:SetWidth(3)
        end
        t:SetVertexColor(NEXT[1], NEXT[2], NEXT[3], 0.95)
        return t
    end
    glow.edgeT = Edge("TOP")
    glow.edgeB = Edge("BOTTOM")
    glow.edgeL = Edge("LEFT")
    glow.edgeR = Edge("RIGHT")
    glow.border = glow.edgeT -- SetGlowStyle recolors all edges via glow.edges
    glow.edges = { glow.edgeT, glow.edgeB, glow.edgeL, glow.edgeR }

    local label = glow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("BOTTOM", glow, "TOP", 0, 2)
    label:SetText("")
    glow.label = label

    glow:Hide()
    node.mancerRouteGlow = glow
    return glow
end

local function SetGlowStyle(glow, style, labelText)
    if not glow then
        return
    end
    local c = NEXT
    if style == "free" then
        c = FREE
    elseif style == "soon" then
        c = SOON
    elseif style == "blocked" then
        c = BLOCKED
    elseif style == "class" or style == "spec" then
        c = NEXT
    end
    for _, edge in ipairs(glow.edges or {}) do
        edge:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
    end
    if glow.label then
        glow.label:SetText(labelText or "")
        glow.label:SetTextColor(c[1], c[2], c[3], 1)
    end
    glow.style = style
    glow:Show()
end

function Overlay:ClearGlows()
    for _, glow in pairs(self.activeGlows or {}) do
        if glow and glow.Hide then
            glow:Hide()
            if glow.label then
                glow.label:SetText("")
            end
        end
    end
    wipe(self.activeGlows)
end

function Overlay:CollectRankMap()
    local ranks = {}
    local frame = self.talentFrame
    if not frame or not frame.TreeView then
        return ranks
    end

    local function note(name, rank, entryId)
        rank = tonumber(rank) or 0
        -- Record 0 explicitly so BuildTakenRankMap can clear unlearned picks.
        if name and name ~= "" then
            if rank <= 0 then
                ranks[name] = 0
            else
                ranks[name] = math.max(ranks[name] or 0, rank)
            end
        end
        entryId = tonumber(entryId)
        if entryId then
            local idKey = "#" .. tostring(entryId)
            if rank <= 0 then
                ranks[idKey] = 0
            else
                ranks[idKey] = math.max(ranks[idKey] or 0, rank)
            end
        end
    end

    local function effectiveRank(nodeRank, entryId)
        local rank = tonumber(nodeRank) or 0
        if not entryId or not C_CharacterAdvancement or not C_CharacterAdvancement.GetPendingRankByEntryID then
            return rank
        end
        local ok, pending = pcall(C_CharacterAdvancement.GetPendingRankByEntryID, entryId)
        -- pending can be 0 after an unlearn — must not use `if pending then` (0 is falsy).
        if ok and pending ~= nil then
            return tonumber(pending) or 0
        end
        return rank
    end

    local function scanNode(node)
        if not node or not node.entry then
            return
        end
        local entryId = node.entry.ID or node.entry.id
        note(EntryName(node.entry), effectiveRank(node.rank, entryId), entryId)
        if node.nodes then
            for _, sub in ipairs(node.nodes) do
                if sub and sub.entry then
                    local subId = sub.entry.ID or sub.entry.id
                    note(EntryName(sub.entry), effectiveRank(sub.rank, subId), subId)
                end
            end
        end
    end

    local function scanTree(tree)
        if not tree or not tree.EnumerateNodes then
            return
        end
        for node in tree:EnumerateNodes() do
            scanNode(node)
        end
    end
    scanTree(frame.TreeView.ClassTree)
    scanTree(frame.TreeView.SpecTree)
    return ranks
end

-- Legacy name list for anything still calling CollectPendingNames.
function Overlay:CollectPendingNames()
    local names = {}
    for name, rank in pairs(self:CollectRankMap()) do
        if type(name) == "string" and name:sub(1, 1) ~= "#" and rank and rank > 0 then
            table.insert(names, name)
        end
    end
    return names
end

function Overlay:FindNodesByPick(wantName, entryId)
    local found = {}
    local route = GetRoute()
    if not self.talentFrame or not self.talentFrame.TreeView then
        return found
    end
    entryId = tonumber(entryId)

    local function consider(node)
        if not node or not node:IsShown() or not node.entry then
            return
        end
        local id = tonumber(node.entry.ID or node.entry.id)
        if entryId then
            if id == entryId then
                table.insert(found, node)
            end
            if node.nodes then
                for _, sub in ipairs(node.nodes) do
                    if sub and sub.entry then
                        local subId = tonumber(sub.entry.ID or sub.entry.id)
                        if subId == entryId then
                            table.insert(found, sub)
                        end
                    end
                end
            end
            return
        end
        local name = EntryName(node.entry)
        if name and route and route.NamesEqual and route:NamesEqual(name, wantName) then
            table.insert(found, node)
            return
        end
        if node.nodes then
            for _, sub in ipairs(node.nodes) do
                if sub and sub.entry then
                    local subName = EntryName(sub.entry)
                    if subName and route and route.NamesEqual and route:NamesEqual(subName, wantName) then
                        table.insert(found, sub)
                    end
                end
            end
        end
    end

    local function scanTree(tree)
        if not tree or not tree.EnumerateNodes then
            return
        end
        for node in tree:EnumerateNodes() do
            consider(node)
        end
    end
    scanTree(self.talentFrame.TreeView.ClassTree)
    scanTree(self.talentFrame.TreeView.SpecTree)

    -- Wrong/stale entryId must not blank the highlight — fall back to exact name.
    if #found == 0 and wantName and entryId and route and route.NamesEqual then
        local function considerByName(node)
            if not node or not node:IsShown() or not node.entry then
                return
            end
            local name = EntryName(node.entry)
            if name and route:NamesEqual(name, wantName) then
                table.insert(found, node)
                return
            end
            if node.nodes then
                for _, sub in ipairs(node.nodes) do
                    if sub and sub.entry then
                        local subName = EntryName(sub.entry)
                        if subName and route:NamesEqual(subName, wantName) then
                            table.insert(found, sub)
                        end
                    end
                end
            end
        end
        local function scanByName(tree)
            if not tree or not tree.EnumerateNodes then
                return
            end
            for node in tree:EnumerateNodes() do
                considerByName(node)
            end
        end
        scanByName(self.talentFrame.TreeView.ClassTree)
        scanByName(self.talentFrame.TreeView.SpecTree)
    end

    -- Fallback: fuzzy name only when no entryId and no exact hits.
    if #found == 0 and wantName and not entryId and route and route.NamesMatch then
        local function considerFuzzy(node)
            if not node or not node:IsShown() then
                return
            end
            local name = EntryName(node.entry)
            if name and route:NamesMatch(name, wantName) then
                table.insert(found, node)
                return
            end
            if node.nodes then
                for _, sub in ipairs(node.nodes) do
                    local subName = EntryName(sub.entry)
                    if subName and route:NamesMatch(subName, wantName) then
                        table.insert(found, sub)
                    end
                end
            end
        end
        scanTree = function(tree)
            if not tree or not tree.EnumerateNodes then
                return
            end
            for node in tree:EnumerateNodes() do
                considerFuzzy(node)
            end
        end
        scanTree(self.talentFrame.TreeView.ClassTree)
        scanTree(self.talentFrame.TreeView.SpecTree)
    end

    return found
end

function Overlay:FindNodesByName(wantName)
    return self:FindNodesByPick(wantName, nil)
end

function Overlay:HighlightPick(name, entryId, style, labelText)
    if not name and not entryId then
        return
    end
    for _, node in ipairs(self:FindNodesByPick(name, entryId)) do
        local glow = EnsureHighlight(node)
        SetGlowStyle(glow, style, labelText)
        self.activeGlows[glow] = glow
    end
end

function Overlay:HighlightName(name, style, labelText)
    self:HighlightPick(name, nil, style, labelText)
end

function Overlay:UpdateStatusText(picks)
    if not self.statusText then
        return
    end
    local lines = {}
    if picks.free then
        table.insert(lines, string.format("FREE L%d: %s", picks.free.level or 0, picks.free.name))
    end
    if picks.class then
        table.insert(lines, "Class: " .. picks.class.name)
    end
    if picks.spec then
        local specLine = "Spec: " .. picks.spec.name
        if picks.spec.blocked and picks.spec.blockReason then
            specLine = specLine .. " (" .. picks.spec.blockReason .. ")"
        end
        table.insert(lines, specLine)
    end
    if #lines == 0 then
        table.insert(lines, "Route complete (or nodes not on this tree)")
    end
    table.insert(lines, "Click talents normally — overlay stays up")
    self.statusText:SetText(table.concat(lines, "  ·  "))
end

function Overlay:Refresh()
    if not self.hooked or not self.talentFrame then
        return
    end
    self:ClearGlows()
    if not self:IsEnabled() or not self.talentFrame:IsShown() then
        if self.overlayLayer then
            self.overlayLayer:Hide()
        end
        self:UpdateToggleLabel()
        return
    end

    if self.overlayLayer then
        self.overlayLayer:Show()
    end

    local route = GetRoute()
    if not route or not route.GetNextOverlayPicks then
        return
    end

    local pending = self:CollectRankMap()
    local picks = route:GetNextOverlayPicks(pending)

    if picks.free then
        self:HighlightPick(picks.free.name, picks.free.entryId, "free", "FREE")
    end
    if picks.class then
        self:HighlightPick(picks.class.name, picks.class.entryId, "class", "NEXT")
    end
    if picks.spec then
        local style = picks.spec.blocked and "blocked" or "spec"
        local label = picks.spec.blocked and "NEED ABOM" or "NEXT"
        self:HighlightPick(picks.spec.name, picks.spec.entryId, style, label)
    end

    self:UpdateStatusText(picks)
    self:UpdateToggleLabel()
end

function Overlay:UpdateToggleLabel()
    if not self.toggleBtn or not self.toggleBtn.label then
        return
    end
    if self:IsEnabled() then
        self.toggleBtn.label:SetText("Hide Route")
        self.toggleBtn.bg:SetVertexColor(0.12, 0.28, 0.24, 0.95)
    else
        self.toggleBtn.label:SetText("Show Route")
        self.toggleBtn.bg:SetVertexColor(0.14, 0.16, 0.18, 0.95)
    end
end

function Overlay:ApplyVisibility()
    if self.overlayLayer then
        if self:IsEnabled() and self.talentFrame and self.talentFrame:IsShown() then
            self.overlayLayer:Show()
        else
            self.overlayLayer:Hide()
        end
    end
    self:UpdateToggleLabel()
end

function Overlay:HookTalentFrame(frame)
    if not frame or self.hooked then
        return
    end
    self.talentFrame = frame
    self.hooked = true
    self.activeGlows = {}

    -- Toggle button: mouse-enabled. Always available on the talent frame.
    local btn = CreateFrame("Button", "MancerTalentRouteToggle", frame)
    btn:SetSize(96, 22)
    btn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -36, -28)
    btn:SetFrameStrata(frame:GetFrameStrata() or "DIALOG")
    btn:SetFrameLevel((frame:GetFrameLevel() or 1) + 50)
    btn:EnableMouse(true)
    btn:RegisterForClicks("AnyUp")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(WHITE)
    bg:SetVertexColor(0.14, 0.16, 0.18, 0.95)
    btn.bg = bg

    local border = btn:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetTexture(WHITE)
    border:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.9)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", 0, 0)
    label:SetText("Show Route")
    btn.label = label

    btn:SetScript("OnClick", function()
        Overlay:Toggle()
    end)
    btn:SetScript("OnEnter", function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Mancer talent route", 1, 1, 1)
            GameTooltip:AddLine("Toggle route highlights on the tree.", 0.75, 0.82, 0.80, true)
            GameTooltip:AddLine("Highlights are click-through — keep spending with the overlay on.", 0.75, 0.82, 0.80, true)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    self.toggleBtn = btn

    -- Overlay chrome: mouse DISABLED so you never have to dismiss it to click talents.
    local layer = CreateFrame("Frame", "MancerTalentRouteOverlay", frame)
    layer:SetAllPoints(frame)
    layer:EnableMouse(false)
    layer:SetFrameLevel((frame:GetFrameLevel() or 1) + 20)
    layer:Hide()
    self.overlayLayer = layer

    local status = layer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", layer, "TOPLEFT", 140, -32)
    status:SetPoint("TOPRIGHT", layer, "TOPRIGHT", -140, -32)
    status:SetJustifyH("LEFT")
    status:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    status:SetText("")
    self.statusText = status

    local function onShow()
        Overlay:ApplyVisibility()
        Overlay:Refresh()
    end
    local function onHide()
        Overlay:ClearGlows()
        if Overlay.overlayLayer then
            Overlay.overlayLayer:Hide()
        end
    end

    frame:HookScript("OnShow", onShow)
    frame:HookScript("OnHide", onHide)

    if frame:IsShown() then
        onShow()
    else
        self:UpdateToggleLabel()
    end
end

function Overlay:TryHook()
    if self.hooked then
        return true
    end
    if CoATalentFrame then
        self:HookTalentFrame(CoATalentFrame)
        return true
    end
    return false
end

function Overlay:Init()
    if self.initialized then
        return
    end
    self.initialized = true
    self.activeGlows = {}

    local driver = CreateFrame("Frame")
    self.driver = driver
    driver:RegisterEvent("PLAYER_LOGIN")
    driver:RegisterEvent("ADDON_LOADED")
    driver:RegisterEvent("PLAYER_LEVEL_UP")
    if C_CharacterAdvancement then
        driver:RegisterEvent("CHARACTER_ADVANCEMENT_PENDING_BUILD_UPDATED")
        pcall(function()
            driver:RegisterEvent("CHARACTER_ADVANCEMENT_UPDATE_ENTRIES_RESULT")
        end)
        pcall(function()
            driver:RegisterEvent("CHARACTER_ADVANCEMENT_KNOWN_ENTRIES_CHANGED")
        end)
        pcall(function()
            driver:RegisterEvent("CHARACTER_ADVANCEMENT_LEARN_RESULT")
        end)
        pcall(function()
            driver:RegisterEvent("CHARACTER_ADVANCEMENT_UNLEARN_RESULT")
        end)
    end

    driver:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" then
            if arg1 == "Ascension_CoATalents" or arg1 == "Ascension_TalentUI" then
                Overlay:TryHook()
            end
            return
        end
        if event == "PLAYER_LOGIN" then
            Overlay:TryHook()
            return
        end
        if Overlay.hooked and Overlay:IsEnabled() then
            if Mancer.Ascension and Mancer.Ascension.InvalidateTalentCache then
                Mancer.Ascension.InvalidateTalentCache()
            end
            -- Defer so CoA nodes finish UpdateDisplay after spend / unlearn.
            Overlay.pendingRefresh = true
            Overlay.refreshDelay = 0
        end
    end)

    driver:SetScript("OnUpdate", function(_, elapsed)
        if not Overlay.pendingRefresh then
            return
        end
        Overlay.refreshDelay = (Overlay.refreshDelay or 0) + elapsed
        -- Unlearn pending ranks often settle slightly later than spends.
        if Overlay.refreshDelay < 0.12 then
            return
        end
        Overlay.pendingRefresh = false
        Overlay.refreshDelay = 0
        Overlay:Refresh()
    end)

    -- CoA may already be loaded before Mancer.
    self:TryHook()
end
