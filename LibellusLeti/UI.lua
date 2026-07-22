-- Shared Mancer window skin (dark charcoal + Life Force teal).
-- Uses textures instead of SetBackdrop for Ascension / 3.3.5 reliability.
Mancer.UI = Mancer.UI or {}
local UI = Mancer.UI

local WHITE = "Interface\\Buttons\\WHITE8X8"
local floor = math.floor

UI.Colors = {
    bg = { 0.08, 0.09, 0.11, 0.96 },
    bgInset = { 0.11, 0.12, 0.14, 0.95 },
    border = { 0.22, 0.28, 0.30, 1 },
    accent = { 0.25, 0.95, 0.75, 1 },
    title = { 0.92, 0.95, 0.97, 1 },
    muted = { 0.55, 0.60, 0.62, 1 },
    buttonBg = { 0.14, 0.16, 0.18, 1 },
    buttonHover = { 0.18, 0.17, 0.14, 1 },
    buttonBorder = { 0.28, 0.40, 0.36, 1 },
    buttonText = { 0.90, 0.94, 0.95, 1 },
    -- Active Hub buttons: same canary yellow as SECTIONS node ring / connectors.
    sectionYellow = { 1.00, 0.88, 0.12, 1 },
    buttonSelectedBg = { 0.09, 0.09, 0.08, 1 },
    buttonSelectedBorder = { 1.00, 0.88, 0.12, 1 },
    buttonSelectedText = { 1.00, 0.92, 0.45, 1 },
    buttonSelectedRim = { 0.85, 0.72, 0.08, 1 },
    rule = { 0.25, 0.95, 0.75, 0.40 },
    ok = { 0.35, 0.85, 0.55, 1 },
    warn = { 0.95, 0.78, 0.28, 1 },
    next = { 0.25, 0.95, 0.75, 1 },
    track = { 0.16, 0.18, 0.20, 1 },
}

local function Unpack(c)
    return c[1], c[2], c[3], c[4] or 1
end

local function Solid(parent, layer)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND")
    tex:SetTexture(WHITE)
    return tex
end

-- ============================================================================
-- HUB ARTWORK — background placement matched to CoA TreeView.Background1 (user-approved 0.9.262).
-- Other Hub art (chrome, rail, nodes, connectors) remains locked.
-- Game atlases only — no local Media copies.
-- ============================================================================
-- Hub necro talent art from game AtlasInfo / CoA SetAtlas(specArt).
-- Atlas: talents-background-necromancer-animation (same as CoA Animation BG).
UI.HUB_ANIMATION_BG = {
    atlas = "talents-background-necromancer-animation",
    path = "Interface\\TalentFrame\\Backgrounds\\NecromancerTalentBackground1",
    left = 0,
    right = 0.787109375,
    top = 0,
    bottom = 0.3779296875,
    -- Native atlas element size (matches CoA Animation BG).
    width = 1612,
    height = 774,
    -- Match CoATalentFrame TreeView content insets (Background1 setAllPoints).
    -- CoA: TreeView TOPLEFT y=-24; inner TOPLEFT 2,-24 → art top -24 from frame with side inset 2.
    artInset = 2,
    artTopInset = 24,
}

-- Display options only — DefaultTalentArt1 Priest Shadow tile (graveyard / crypt).
-- Native 300×330 portrait tile; much closer to the tall Options frame than Animation BG.
UI.DISPLAY_BG = {
    atlas = "default-talent-priest-shadow",
    path = "Interface\\TalentFrame\\DefaultTalentArt1",
    left = 0.29296875,
    right = 0.439453125,
    top = 0.4833984375,
    bottom = 0.64453125,
    width = 300,
    height = 330,
    artInset = 2,
    artTopInset = 24,
}

-- CoA talent-frame portrait (AtlasInfo class-round-necromancer).
UI.HUB_PORTRAIT = {
    atlas = "class-round-necromancer",
    path = "Interface\\Glues\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES-ROUND",
    left = 0.5,
    right = 0.625,
    top = 0.25,
    bottom = 0.5,
}

-- Game-only art paths / atlases (never local AddOns\\Mancer\\Media).
UI.HUB_ART_PATHS = {
    UI.HUB_ANIMATION_BG.path,
}

-- CoA SpendCircle art (CoACharacterAdvancementUtil.NodeArtSet.Circle + AtlasInfo).
-- Prefer SetAtlas(name) on Ascension — same path the talent UI uses.
UI.HUB_NODE_CIRCLE = {
    path = "Interface\\TalentFrame\\talents",
    mask = "Interface\\TalentFrame\\TalentsMaskNodeCircle",
    -- Match AtlasInfo talents-node-circle-* (50) + SpecTree buttonWidth/Height 30.
    iconSize = 30,
    ringSize = 50,
    shadowSize = 46,
    atlas = {
        yellow = "talents-node-circle-yellow",
        gray = "talents-node-circle-gray",
        green = "talents-node-circle-green",
        shadow = "talents-node-circle-shadow",
    },
    yellow = { 0.899414, 0.923828, 0.112305, 0.161133 },
    gray = { 0.106934, 0.131348, 0.555664, 0.604492 },
    green = { 0.106934, 0.131348, 0.606445, 0.655273 },
    shadow = { 0.747070, 0.784180, 0.083008, 0.157227 },
}

-- Talent connection art (yellow path between SpendCircles).
-- CoA CALineConnectionMixin uses solid LineMixin strokes + head textures.
UI.HUB_NODE_ARROW = {
    linePath = "Interface\\TalentFrame\\talentsarrowline",
    lineAtlas = "talents-arrow-line-yellow",
    line = { 0.000000, 1.000000, 0.429688, 0.554688 },
    -- CoA UpdateConnectionState uses this file path (not the atlas sheet).
    headPath = "Interface\\TalentFrame\\talents-arrow-head-yellow",
    headAtlas = "talents-arrow-head-yellow",
    head = { 0.203613, 0.217285, 0.942383, 0.965820 },
    -- Locked with Hub SECTIONS connectors — keep in sync with SECTION_ARROW_* in Hub.lua.
    headW = 14,
    headH = 12,
    -- Match CALineConnectionMixin Line1/Line2 thicknesses + connected gold.
    outlineThickness = 4,
    lineThickness = 2,
    lineR = 0.65,
    lineG = 0.54,
    lineB = 0.06,
    lineA = 1,
}

-- Back-compat alias used by older hub ring code.
UI.HUB_NODE_RING = UI.HUB_NODE_CIRCLE

-- Animation passive column border (CoA SpecTree.PassivesBackground → ca-passive-bg).
UI.HUB_PASSIVE_RAIL = {
    path = "Interface\\CharacterAdvancement\\CharacterAdvancementAtlas",
    atlas = "ca-passive-bg",
    left = 0.375,
    right = 0.99609375,
    top = 0.0029296875,
    bottom = 0.9970703125,
    width = 74,
    height = 480,
}

-- Ascension textures often ignore SetSize; CoA uses SetWidth/SetHeight after SetAtlas.
local function ForceTextureSize(tex, w, h)
    if not tex or not w or not h then
        return
    end
    if tex.SetWidth then
        tex:SetWidth(w)
    end
    if tex.SetHeight then
        tex:SetHeight(h)
    end
    if tex.SetSize then
        tex:SetSize(w, h)
    end
end

local function AtlasIgnoreSize()
    if Const and Const.TextureKit and Const.TextureKit.IgnoreAtlasSize ~= nil then
        return Const.TextureKit.IgnoreAtlasSize
    end
    -- Blizzard SetAtlas 2nd arg: useAtlasSize. false = keep our width/height.
    return false
end

local function SetAtlasOrCoords(tex, atlasName, path, coords, w, h)
    if not tex then
        return false
    end
    ForceTextureSize(tex, w, h)
    -- Match CoA: SetAtlas(..., IgnoreAtlasSize) then re-assert size.
    if atlasName and tex.SetAtlas then
        local ok = pcall(function()
            tex:SetAtlas(atlasName, AtlasIgnoreSize())
        end)
        if ok and tex.GetTexture and tex:GetTexture() then
            ForceTextureSize(tex, w, h)
            return true
        end
    end
    if path and coords then
        tex:SetTexture(path)
        tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        ForceTextureSize(tex, w, h)
        return true
    end
    return false
end

UI.ForceTextureSize = ForceTextureSize
UI.SetAtlasOrCoords = SetAtlasOrCoords

local function ApplyCircleIcon(tex, iconPath, maskPath)
    if not tex or not iconPath then
        return
    end
    maskPath = maskPath or UI.HUB_NODE_CIRCLE.mask
    local applied = false
    if tex.SetMaskedTexture then
        applied = pcall(function()
            tex:SetMaskedTexture(iconPath, maskPath)
        end)
    end
    if not applied then
        tex:SetTexture(iconPath)
        if tex.SetMask then
            pcall(function()
                tex:SetMask(maskPath)
            end)
        end
    end
end

-- Nine-slice-ish: fill + 1px border via four edge textures.
-- opts.artPath / opts.useHubArt: Hub-only background art + dark scrub for readability.
function UI.PaintPanel(frame, insetColor, opts)
    if not frame then
        return
    end
    if frame.mancerBg then
        return
    end
    opts = opts or {}

    -- Native portrait templates often ship an opaque Bg that hides custom art.
    local function DimTemplateBg(region)
        if not region then
            return
        end
        if region.SetAlpha then
            region:SetAlpha(0)
        end
        if region.Hide then
            region:Hide()
        end
    end
    DimTemplateBg(frame.Bg)
    DimTemplateBg(frame.Background)
    if frame.Inset then
        DimTemplateBg(frame.Inset.Bg)
        DimTemplateBg(frame.Inset.Background)
    end
    if frame.NineSlice and frame.NineSlice.Center then
        DimTemplateBg(frame.NineSlice.Center)
    end

    local artPath = opts.artPath
    local artCoords = opts.artCoords
    local artAtlas = opts.artAtlas
    if opts.useHubArt then
        artAtlas = artAtlas or (UI.HUB_ANIMATION_BG and UI.HUB_ANIMATION_BG.atlas)
        if not artPath then
            artPath = UI.HUB_ANIMATION_BG and UI.HUB_ANIMATION_BG.path
            artCoords = {
                UI.HUB_ANIMATION_BG.left,
                UI.HUB_ANIMATION_BG.right,
                UI.HUB_ANIMATION_BG.top,
                UI.HUB_ANIMATION_BG.bottom,
            }
        end
    end

    if artAtlas or artPath then
        local art = frame:CreateTexture(nil, "BACKGROUND")
        art:SetDrawLayer("BACKGROUND", 2)
        local inset = opts.artInset or 0
        local topInset = opts.artTopInset or inset
        if inset > 0 or topInset > 0 then
            art:ClearAllPoints()
            art:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -topInset)
            art:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
        else
            art:SetAllPoints(frame)
        end

        local loaded = false
        -- Prefer game atlas (same as CoA Animation BG), then path+texcoord.
        if artAtlas and art.SetAtlas then
            loaded = pcall(function()
                art:SetAtlas(artAtlas, AtlasIgnoreSize())
            end)
            loaded = loaded and art.GetTexture and art:GetTexture() and true or false
        end
        if not loaded and artPath then
            art:SetTexture(artPath)
            loaded = art:GetTexture() and true or false
            if loaded then
                if artCoords then
                    art:SetTexCoord(artCoords[1], artCoords[2], artCoords[3], artCoords[4])
                else
                    art:SetTexCoord(0.02, 0.98, 0.04, 0.96)
                end
            end
        end

        if loaded then
            frame.mancerArt = art

            local scrub = Solid(frame, "BACKGROUND")
            scrub:SetDrawLayer("BACKGROUND", 3)
            if inset > 0 or topInset > 0 then
                scrub:ClearAllPoints()
                scrub:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -topInset)
                scrub:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
            else
                scrub:SetAllPoints(frame)
            end
            scrub:SetVertexColor(0.03, 0.05, 0.07, opts.artScrub or 0.58)
            frame.mancerBg = scrub
        else
            art:Hide()
        end
    end

    if not frame.mancerBg then
        local bg = Solid(frame, "BACKGROUND")
        bg:SetAllPoints(frame)
        bg:SetVertexColor(Unpack(insetColor or UI.Colors.bg))
        frame.mancerBg = bg
    end

    if not opts.skipEdges then
        local function Edge(point)
            local e = Solid(frame, "BORDER")
            e:SetVertexColor(Unpack(UI.Colors.border))
            if point == "TOP" then
                e:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
                e:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
                e:SetHeight(1)
            elseif point == "BOTTOM" then
                e:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
                e:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
                e:SetHeight(1)
            elseif point == "LEFT" then
                e:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
                e:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
                e:SetWidth(1)
            else
                e:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
                e:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
                e:SetWidth(1)
            end
            return e
        end

        frame.mancerEdgeT = Edge("TOP")
        frame.mancerEdgeB = Edge("BOTTOM")
        frame.mancerEdgeL = Edge("LEFT")
        frame.mancerEdgeR = Edge("RIGHT")
    end

    if frame.SetBackdrop then
        pcall(function()
            frame:SetBackdrop({
                bgFile = WHITE,
                edgeFile = WHITE,
                tile = false,
                tileSize = 8,
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            if frame.mancerArt or opts.skipEdges then
                frame:SetBackdropColor(0, 0, 0, 0)
                frame:SetBackdropBorderColor(0, 0, 0, 0)
            else
                frame:SetBackdropColor(Unpack(insetColor or UI.Colors.bg))
                frame:SetBackdropBorderColor(Unpack(UI.Colors.border))
            end
        end)
    end
end

function UI.StyleTitle(fs)
    if not fs then
        return
    end
    local c = UI.Colors.title
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

function UI.StyleMuted(fs)
    if not fs then
        return
    end
    local c = UI.Colors.muted
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

function UI.StyleAccent(fs)
    if not fs then
        return
    end
    local c = UI.Colors.accent
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

local function SetAtlasSized(tex, atlasName, w, h)
    if not tex or not atlasName then
        return false
    end
    if UI.ForceTextureSize then
        UI.ForceTextureSize(tex, w, h)
    else
        tex:SetWidth(w)
        tex:SetHeight(h)
    end
    if not tex.SetAtlas then
        return false
    end
    local ok = pcall(function()
        tex:SetAtlas(atlasName, AtlasIgnoreSize())
    end)
    if ok then
        if UI.ForceTextureSize then
            UI.ForceTextureSize(tex, w, h)
        end
        return tex.GetTexture and tex:GetTexture() and true or ok
    end
    return false
end

-- Same grey metal chrome Ascension uses on CoA (GenericMetal2 / RaisedPortraitFrame).
function UI.ApplyMetalPortraitBorder(frame)
    if not frame or frame.mancerMetalBorder then
        return frame
    end

    local border = CreateFrame("Frame", nil, frame)
    border:SetAllPoints(frame)
    border:SetFrameLevel((frame:GetFrameLevel() or 1) + 20)
    frame.mancerMetalBorder = border

    local CORNER = 36
    local TOP_CORNER = 42
    local EDGE_V = 36
    local EDGE_H = 36

    local tl = border:CreateTexture(nil, "OVERLAY")
    tl:SetPoint("TOPLEFT", frame, "TOPLEFT", -6, 8)
    SetAtlasSized(tl, "GenericMetal2-NineSlice-CornerTopLeft", TOP_CORNER, TOP_CORNER)

    local tr = border:CreateTexture(nil, "OVERLAY")
    tr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 8)
    SetAtlasSized(tr, "GenericMetal2-NineSlice-CornerTopRight", TOP_CORNER, TOP_CORNER)

    local bl = border:CreateTexture(nil, "OVERLAY")
    bl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -6, -4)
    SetAtlasSized(bl, "GenericMetal2-NineSlice-CornerBottomLeft", CORNER, CORNER)

    local br = border:CreateTexture(nil, "OVERLAY")
    br:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -4)
    SetAtlasSized(br, "GenericMetal2-NineSlice-CornerBottomRight", CORNER, CORNER)

    local top = border:CreateTexture(nil, "OVERLAY")
    top:SetPoint("TOPLEFT", tl, "TOPRIGHT", 0, 0)
    top:SetPoint("TOPRIGHT", tr, "TOPLEFT", 0, 0)
    top:SetHeight(EDGE_H)
    SetAtlasSized(top, "_GenericMetal2-NineSlice-EdgeTop", 64, EDGE_H)

    local bot = border:CreateTexture(nil, "OVERLAY")
    bot:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT", 0, 0)
    bot:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)
    bot:SetHeight(EDGE_H)
    SetAtlasSized(bot, "_GenericMetal2-NineSlice-EdgeBottom", 64, EDGE_H)

    local left = border:CreateTexture(nil, "OVERLAY")
    left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", bl, "TOPLEFT", 0, 0)
    left:SetWidth(EDGE_V)
    SetAtlasSized(left, "!GenericMetal2-NineSlice-EdgeLeft", EDGE_V, 64)

    local right = border:CreateTexture(nil, "OVERLAY")
    right:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT", 0, 0)
    right:SetWidth(EDGE_V)
    SetAtlasSized(right, "!GenericMetal2-NineSlice-EdgeRight", EDGE_V, 64)

    return frame
end

-- Red X used by Character Advancement / standard panels.
function UI.CreateNativeCloseButton(parent)
    local btn
    local ok = pcall(function()
        btn = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    end)
    if not ok or not btn then
        return UI.CreateCloseButton(parent)
    end
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 2, 2)
    btn:SetFrameLevel((parent:GetFrameLevel() or 1) + 30)
    btn:SetScript("OnClick", function()
        parent:Hide()
    end)
    return btn
end

-- Build Hub root like CoATalentFrame: RaisedPortraitFrameTemplate when available.
-- Returns frame, chromeKind ("raised"|"portrait"|"metal").
function UI.CreateHubRootFrame(name, parent)
    parent = parent or UIParent
    local frame
    local kind = "metal"

    local templates = { "RaisedPortraitFrameTemplate", "PortraitFrameTemplate" }
    for i = 1, #templates do
        local tmpl = templates[i]
        local ok, created = pcall(function()
            return CreateFrame("Frame", name, parent, tmpl)
        end)
        if ok and created then
            frame = created
            kind = (tmpl == "RaisedPortraitFrameTemplate") and "raised" or "portrait"
            break
        end
    end

    if not frame then
        frame = CreateFrame("Frame", name, parent)
        UI.ApplyMetalPortraitBorder(frame)
        kind = "metal"
    end

    return frame, kind
end

local function GetFramePortraitTexture(frame)
    if not frame then
        return nil
    end
    if frame.portrait then
        return frame.portrait
    end
    if frame.PortraitContainer and frame.PortraitContainer.portrait then
        return frame.PortraitContainer.portrait
    end
    if frame.PortraitFrame and frame.PortraitFrame.Portrait then
        return frame.PortraitFrame.Portrait
    end
    local name = frame.GetName and frame:GetName()
    if name and _G[name .. "Portrait"] then
        return _G[name .. "Portrait"]
    end
    return nil
end

-- Match CoA talent-tree portrait (class-round-necromancer).
function UI.ApplyHubPortraitMark(frame)
    if not frame then
        return
    end

    local art = UI.HUB_PORTRAIT
    local portrait = GetFramePortraitTexture(frame)

    local classToken = select(2, UnitClass("player"))
    if PortraitFrame_SetClassIcon and classToken then
        pcall(PortraitFrame_SetClassIcon, frame, classToken)
    end

    if portrait and art then
        local usedAtlas = false
        if portrait.SetAtlas and art.atlas then
            usedAtlas = pcall(function()
                portrait:SetAtlas(art.atlas, AtlasIgnoreSize())
            end)
            if usedAtlas and portrait.GetTexture then
                usedAtlas = portrait:GetTexture() and true or false
            end
        end
        if not usedAtlas and art.path then
            portrait:SetTexture(art.path)
            portrait:SetTexCoord(art.left, art.right, art.top, art.bottom)
        end
    end

    if frame.mancerPortraitMark then
        frame.mancerPortraitMark:Hide()
        frame.mancerPortraitMark = nil
    end
end

function UI.ApplyHubNativeChrome(frame, opts)
    opts = opts or {}
    if not frame then
        return
    end

    local title = opts.title or (Mancer.DISPLAY_NAME or "Libellus Leti")

    if PortraitFrame_SetTitle then
        pcall(PortraitFrame_SetTitle, frame, title)
    elseif frame.TitleText then
        frame.TitleText:SetText(title)
    elseif frame.TitleContainer and frame.TitleContainer.TitleText then
        frame.TitleContainer.TitleText:SetText(title)
    end

    UI.ApplyHubPortraitMark(frame)

    local close = frame.CloseButton or frame.Close
    if close then
        close:SetScript("OnClick", function()
            frame:Hide()
        end)
        close:Show()
    else
        UI.CreateNativeCloseButton(frame)
    end

    -- Keep native metal border; fill inner content flush to the chrome.
    -- Art insets match CoA TreeView.Background1 (user-approved sync 0.9.262).
    if opts.useHubArt or opts.artAtlas or opts.artPath then
        local bg = opts.useHubArt and (UI.HUB_ANIMATION_BG or {}) or {}
        UI.PaintPanel(frame, opts.insetColor, {
            useHubArt = opts.useHubArt and not opts.artAtlas and not opts.artPath or false,
            artAtlas = opts.artAtlas,
            artPath = opts.artPath,
            artCoords = opts.artCoords,
            artScrub = opts.artScrub or 0.58,
            artInset = opts.artInset or bg.artInset or 2,
            artTopInset = opts.artTopInset or bg.artTopInset or 24,
            skipEdges = true,
            skipTitleBar = true,
        })
    end
end

function UI.SkinFrame(frame, opts)
    if not frame then
        return frame
    end
    opts = opts or {}
    if opts.nativeChrome then
        UI.ApplyHubNativeChrome(frame, opts)
        return frame
    end
    UI.PaintPanel(frame, opts.insetColor, opts)

    if opts.titleBar ~= false and not frame.mancerTitleBar then
        local bar = Solid(frame, "ARTWORK")
        bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        bar:SetHeight(opts.titleBarHeight or 28)
        if frame.mancerArt then
            bar:SetVertexColor(0.06, 0.07, 0.09, 0.72)
        else
            bar:SetVertexColor(Unpack(UI.Colors.bgInset))
        end
        frame.mancerTitleBar = bar

        local accent = Solid(frame, "ARTWORK")
        accent:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, 0)
        accent:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, 0)
        accent:SetHeight(2)
        accent:SetVertexColor(Unpack(UI.Colors.accent))
        frame.mancerTitleAccent = accent
    end

    return frame
end

function UI.CreateCloseButton(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(22, 22)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -6)
    btn:SetFrameLevel((parent:GetFrameLevel() or 1) + 8)

    local bg = Solid(btn, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetVertexColor(Unpack(UI.Colors.buttonBg))
    btn.bg = bg

    local border = Solid(btn, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetVertexColor(Unpack(UI.Colors.buttonBorder))
    -- Keep bg above border fill by sizing bg inset.
    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    bg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("CENTER", 0, 1)
    label:SetText("x")
    label:SetTextColor(Unpack(UI.Colors.muted))
    btn.label = label

    btn:SetScript("OnEnter", function(self)
        self.bg:SetVertexColor(Unpack(UI.Colors.buttonHover))
        self.label:SetTextColor(Unpack(UI.Colors.accent))
    end)
    btn:SetScript("OnLeave", function(self)
        self.bg:SetVertexColor(Unpack(UI.Colors.buttonBg))
        self.label:SetTextColor(Unpack(UI.Colors.muted))
    end)
    btn:SetScript("OnClick", function()
        parent:Hide()
    end)

    return btn
end

function UI.CreateButton(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width or 112, height or 24)
    btn:EnableMouse(true)
    btn:RegisterForClicks("AnyUp")

    -- Thin outer rim (brass when selected — matches Hub metal / talent connectors).
    local rim = Solid(btn, "BACKGROUND")
    rim:SetPoint("TOPLEFT", -2, 2)
    rim:SetPoint("BOTTOMRIGHT", 2, -2)
    rim:SetVertexColor(0, 0, 0, 0)
    btn.rim = rim

    local border = Solid(btn, "BORDER")
    border:SetAllPoints()
    border:SetVertexColor(Unpack(UI.Colors.buttonBorder))
    btn.border = border

    local bg = Solid(btn, "ARTWORK")
    bg:SetPoint("TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", -1, 1)
    bg:SetVertexColor(Unpack(UI.Colors.buttonBg))
    btn.bg = bg

    -- Subtle recessed top highlight (metal plate, not neon).
    local sheen = Solid(btn, "OVERLAY")
    sheen:SetPoint("TOPLEFT", bg, "TOPLEFT", 1, -1)
    sheen:SetPoint("TOPRIGHT", bg, "TOPRIGHT", -1, -1)
    sheen:SetHeight(2)
    sheen:SetVertexColor(1, 1, 1, 0)
    btn.sheen = sheen

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", 0, 0)
    label:SetText(text or "")
    label:SetTextColor(Unpack(UI.Colors.buttonText))
    btn.label = label

    btn.SetText = function(self, value)
        if self.label then
            self.label:SetText(value or "")
        end
    end
    btn.GetText = function(self)
        return self.label and self.label:GetText() or ""
    end

    local function ApplyVisual(self)
        local selected = self._selected
        local hover = self._hover
        if selected then
            if self.rim then
                self.rim:SetVertexColor(Unpack(UI.Colors.buttonSelectedRim))
            end
            self.border:SetVertexColor(Unpack(UI.Colors.buttonSelectedBorder))
            self.bg:SetVertexColor(Unpack(UI.Colors.buttonSelectedBg))
            self.label:SetTextColor(Unpack(UI.Colors.buttonSelectedText))
            if self.sheen then
                self.sheen:SetVertexColor(1.00, 0.88, 0.12, 0.40)
            end
        elseif hover then
            if self.rim then
                self.rim:SetVertexColor(0, 0, 0, 0)
            end
            self.border:SetVertexColor(Unpack(UI.Colors.buttonSelectedBorder))
            self.bg:SetVertexColor(Unpack(UI.Colors.buttonHover))
            self.label:SetTextColor(Unpack(UI.Colors.buttonSelectedText))
            if self.sheen then
                self.sheen:SetVertexColor(1, 1, 1, 0.12)
            end
        else
            if self.rim then
                self.rim:SetVertexColor(0, 0, 0, 0)
            end
            self.border:SetVertexColor(Unpack(UI.Colors.buttonBorder))
            self.bg:SetVertexColor(Unpack(UI.Colors.buttonBg))
            self.label:SetTextColor(Unpack(UI.Colors.buttonText))
            if self.sheen then
                self.sheen:SetVertexColor(1, 1, 1, 0)
            end
        end
    end

    btn.SetSelected = function(self, selected)
        self._selected = not not selected
        ApplyVisual(self)
    end
    btn.IsSelected = function(self)
        return self._selected and true or false
    end

    btn:SetScript("OnEnter", function(self)
        self._hover = true
        ApplyVisual(self)
    end)
    btn:SetScript("OnLeave", function(self)
        self._hover = false
        ApplyVisual(self)
    end)
    btn:SetScript("OnMouseDown", function(self)
        self.bg:SetVertexColor(0.06, 0.06, 0.05, 1)
    end)
    btn:SetScript("OnMouseUp", function(self)
        ApplyVisual(self)
    end)

    return btn
end

-- SpendCircle section node — same art set as Animation passives (mask + circle ring + shadow).
-- opts: icon, subtitle, size (icon, default 30), width, labelSide ("LEFT"|"RIGHT"), labelGap
function UI.CreateHubSectionButton(parent, text, opts)
    opts = opts or {}
    local art = UI.HUB_NODE_CIRCLE
    local size = opts.size or art.iconSize or 30
    local ringSize = opts.ringSize or art.ringSize or 50
    local shadowSize = opts.shadowSize or art.shadowSize or math.min(ringSize + 4, 46)
    local fullWidth = opts.width or (size + 140)
    local labelLeft = opts.labelSide == "LEFT"
    -- Keep labels clear of the ornate rail.
    local labelGap = opts.labelGap or (floor(ringSize / 2) + 28)

    local btn = CreateFrame("Button", nil, parent)
    local btnH = opts.compact and size or (math.max(ringSize, size) + (opts.subtitle and 10 or 0))
    btn:SetWidth(fullWidth)
    btn:SetHeight(btnH)
    btn:EnableMouse(true)
    btn:RegisterForClicks("AnyUp")
    btn.isHubSection = true
    btn.selected = false

    local iconAnchor = labelLeft and "RIGHT" or "LEFT"
    local iconOffset = labelLeft and -(size / 2) or (size / 2)

    local shadow = btn:CreateTexture(nil, "BACKGROUND")
    SetAtlasOrCoords(shadow, art.atlas and art.atlas.shadow, art.path, art.shadow, shadowSize, shadowSize)
    shadow:SetPoint("CENTER", btn, iconAnchor, iconOffset, -1)
    btn.shadow = shadow

    local icon = btn:CreateTexture(nil, "ARTWORK")
    if UI.ForceTextureSize then
        UI.ForceTextureSize(icon, size, size)
    else
        icon:SetWidth(size)
        icon:SetHeight(size)
    end
    icon:SetPoint("CENTER", btn, iconAnchor, iconOffset, 0)
    if opts.icon then
        ApplyCircleIcon(icon, opts.icon, art.mask)
    end
    btn.icon = icon

    local ringTex = btn:CreateTexture(nil, "OVERLAY")
    SetAtlasOrCoords(ringTex, art.atlas and art.atlas.gray, art.path, art.gray, ringSize, ringSize)
    ringTex:SetPoint("CENTER", btn, iconAnchor, iconOffset, 0)
    btn.ring = ringTex

    local name = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    -- Gap from rail icon; negative Y drops GameFontNormal baseline to optical center.
    local textGap = opts.textGap or 10
    local textY = opts.textY or -3
    if labelLeft then
        name:SetPoint("RIGHT", icon, "LEFT", -textGap, textY)
        name:SetJustifyH("RIGHT")
    else
        name:SetPoint("LEFT", icon, "RIGHT", textGap, textY)
        name:SetJustifyH("LEFT")
    end
    name:SetText(text or "")
    name:SetTextColor(Unpack(UI.Colors.buttonText))
    btn.label = name

    local sub
    if opts.subtitle and opts.subtitle ~= "" then
        sub = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        if labelLeft then
            sub:SetPoint("TOPRIGHT", name, "BOTTOMRIGHT", 0, -2)
            sub:SetJustifyH("RIGHT")
        else
            sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
            sub:SetJustifyH("LEFT")
        end
        sub:SetWidth(fullWidth - labelGap - 8)
        sub:SetText(opts.subtitle)
        sub:SetTextColor(Unpack(UI.Colors.muted))
        btn.subtitle = sub
    end

    btn.SetText = function(self, value)
        if self.label then
            self.label:SetText(value or "")
        end
    end
    btn.GetText = function(self)
        return self.label and self.label:GetText() or ""
    end

    local function ApplyRing(self, selected, hover)
        local atlasName = art.atlas and art.atlas.gray
        local coords = art.gray
        if selected then
            atlasName = art.atlas and art.atlas.yellow
            coords = art.yellow
        elseif hover then
            atlasName = art.atlas and art.atlas.green
            coords = art.green
        end
        SetAtlasOrCoords(self.ring, atlasName, art.path, coords, ringSize, ringSize)
        self.ring:SetPoint("CENTER", self, iconAnchor, iconOffset, 0)
        if self.label then
            if selected or hover then
                self.label:SetTextColor(Unpack(UI.Colors.accent))
            else
                self.label:SetTextColor(Unpack(UI.Colors.buttonText))
            end
        end
        if self.subtitle then
            if selected or hover then
                self.subtitle:SetTextColor(0.70, 0.82, 0.78, 1)
            else
                self.subtitle:SetTextColor(Unpack(UI.Colors.muted))
            end
        end
        if self.icon then
            if selected then
                self.icon:SetVertexColor(1, 1, 1, 1)
            elseif hover then
                self.icon:SetVertexColor(0.92, 1, 0.96, 1)
            else
                self.icon:SetVertexColor(0.82, 0.86, 0.84, 1)
            end
        end
    end

    btn.SetSelected = function(self, selected)
        self.selected = selected and true or false
        ApplyRing(self, self.selected, false)
    end

    btn:SetScript("OnEnter", function(self)
        ApplyRing(self, self.selected, true)
    end)
    btn:SetScript("OnLeave", function(self)
        ApplyRing(self, self.selected, false)
    end)

    ApplyRing(btn, false, false)
    return btn
end

function UI.CreateSection(parent, text, anchorTo, yGap)
    local wrap = CreateFrame("Frame", nil, parent)
    wrap:SetHeight(20)
    wrap:SetWidth(440)
    if anchorTo then
        wrap:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, yGap or -14)
    else
        wrap:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    end

    local label = wrap:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", wrap, "TOPLEFT", 0, 0)
    label:SetText(text or "")
    UI.StyleAccent(label)
    wrap.label = label

    local rule = Solid(wrap, "ARTWORK")
    rule:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
    rule:SetPoint("RIGHT", wrap, "RIGHT", 0, 0)
    rule:SetHeight(1)
    rule:SetVertexColor(Unpack(UI.Colors.rule))
    wrap.rule = rule

    return wrap
end

-- Horizontal stat progress track (fill + optional border). ratio 0–1.
function UI.CreateStatBar(parent, width, height)
    width = width or 180
    height = height or 10
    local wrap = CreateFrame("Frame", nil, parent)
    wrap:SetSize(width, height)
    wrap.barWidth = width
    wrap.barHeight = height

    local border = Solid(wrap, "BACKGROUND")
    border:SetAllPoints()
    border:SetVertexColor(Unpack(UI.Colors.buttonBorder))
    wrap.border = border

    local track = Solid(wrap, "ARTWORK")
    track:SetPoint("TOPLEFT", 1, -1)
    track:SetPoint("BOTTOMRIGHT", -1, 1)
    track:SetVertexColor(Unpack(UI.Colors.track))
    wrap.track = track

    local fill = Solid(wrap, "OVERLAY")
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMLEFT", 1, 1)
    fill:SetWidth(1)
    fill:SetVertexColor(Unpack(UI.Colors.accent))
    wrap.fill = fill

    wrap.SetProgress = function(self, ratio, color)
        ratio = tonumber(ratio) or 0
        if ratio < 0 then
            ratio = 0
        elseif ratio > 1 then
            ratio = 1
        end
        local inner = math.max(1, (self.barWidth or width) - 2)
        local w = math.max(1, math.floor(inner * ratio + 0.5))
        if ratio <= 0 then
            w = 1
            self.fill:SetVertexColor(0.20, 0.22, 0.24, 1)
        else
            local c = color or UI.Colors.accent
            self.fill:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
        end
        self.fill:SetWidth(w)
        self.ratio = ratio
    end

    return wrap
end
