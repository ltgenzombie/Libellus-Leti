Mancer = Mancer or {}
Mancer.Options = Mancer.Options or {}

-- User-facing rebrand (0.9.406). Internal namespace + MancerDB kept for compatibility.
Mancer.ADDON_FOLDER = "LibellusLeti"
Mancer.DISPLAY_NAME = "Libellus Leti"

-- Embedded so /reload always picks up bumps. Ascension can cache GetAddOnMetadata
-- across reload, which left the Hub title stuck on an older ## Version.
local EMBEDDED_VERSION = "0.9.406"

-- Prefer embedded version; fall back to toc metadata when present.
function Mancer.GetVersion()
    if EMBEDDED_VERSION and EMBEDDED_VERSION ~= "" then
        Mancer.VERSION = EMBEDDED_VERSION
        return EMBEDDED_VERSION
    end
    if GetAddOnMetadata then
        local version = GetAddOnMetadata(Mancer.ADDON_FOLDER or "LibellusLeti", "Version")
        if version and version ~= "" then
            Mancer.VERSION = version
            return version
        end
    end
    return Mancer.VERSION or "?"
end

Mancer.VERSION = Mancer.GetVersion()

-- Where Undead stance prompts may show.
-- Uses IsInInstance() instanceType: none→world, party→dungeon, raid→raid.
local SHOW_WHERE = {
    { id = "all", label = "All" },
    { id = "world", label = "Open world" },
    { id = "raid", label = "Raids" },
    { id = "dungeon", label = "Dungeons" },
}

local SHOW_WHERE_PLACES = { "world", "raid", "dungeon" }

local function DefaultShowWherePlaces()
    return { world = true, raid = true, dungeon = true }
end

local function NormalizeShowWherePlaces(places)
    local out = DefaultShowWherePlaces()
    if type(places) ~= "table" then
        return out
    end
    for _, id in ipairs(SHOW_WHERE_PLACES) do
        out[id] = places[id] and true or false
    end
    return out
end

local function PlacesFromLegacyShowWhere(id)
    if id == "world" then
        return { world = true, raid = false, dungeon = false }
    end
    if id == "raid" then
        return { world = false, raid = true, dungeon = false }
    end
    if id == "dungeon" then
        return { world = false, raid = false, dungeon = true }
    end
    return DefaultShowWherePlaces()
end

function Mancer.GetShowWhereOptions()
    return SHOW_WHERE
end

function Mancer.GetShowWherePlaces()
    MancerDB = MancerDB or {}
    if type(MancerDB.showWherePlaces) ~= "table" then
        MancerDB.showWherePlaces = PlacesFromLegacyShowWhere(MancerDB.showWhere)
    end
    MancerDB.showWherePlaces = NormalizeShowWherePlaces(MancerDB.showWherePlaces)
    return MancerDB.showWherePlaces
end

function Mancer.IsShowWhereAll()
    local places = Mancer.GetShowWherePlaces()
    return places.world and places.raid and places.dungeon
end

-- Back-compat: single id summary ("all", or one place if only that is on).
function Mancer.GetShowWhere()
    local places = Mancer.GetShowWherePlaces()
    if places.world and places.raid and places.dungeon then
        return "all"
    end
    local only = nil
    for _, id in ipairs(SHOW_WHERE_PLACES) do
        if places[id] then
            if only then
                return "custom"
            end
            only = id
        end
    end
    return only or "all"
end

function Mancer.GetShowWhereLabel(id)
    id = id or Mancer.GetShowWhere()
    for _, opt in ipairs(SHOW_WHERE) do
        if opt.id == id then
            return opt.label
        end
    end
    if id == "custom" then
        local places = Mancer.GetShowWherePlaces()
        local parts = {}
        for _, placeId in ipairs(SHOW_WHERE_PLACES) do
            if places[placeId] then
                for _, opt in ipairs(SHOW_WHERE) do
                    if opt.id == placeId then
                        table.insert(parts, opt.label)
                        break
                    end
                end
            end
        end
        if #parts > 0 then
            return table.concat(parts, ", ")
        end
    end
    return "All"
end

function Mancer.SetShowWherePlace(id, enabled)
    MancerDB = MancerDB or {}
    local places = Mancer.GetShowWherePlaces()
    enabled = not not enabled

    if id == "all" then
        -- Tick All → everything on. Untick All → clear all places.
        for _, placeId in ipairs(SHOW_WHERE_PLACES) do
            places[placeId] = enabled
        end
    elseif id == "world" or id == "raid" or id == "dungeon" then
        places[id] = enabled
    else
        return
    end

    MancerDB.showWherePlaces = places
    -- Keep legacy string in sync for older readers.
    MancerDB.showWhere = Mancer.GetShowWhere()
    if Mancer.Refresh then
        Mancer:Refresh()
    end
end

-- Back-compat exclusive setter (single place or all).
function Mancer.SetShowWhere(id)
    if id == "all" then
        Mancer.SetShowWherePlace("all", true)
        return
    end
    if id == "world" or id == "raid" or id == "dungeon" then
        MancerDB = MancerDB or {}
        MancerDB.showWherePlaces = {
            world = id == "world",
            raid = id == "raid",
            dungeon = id == "dungeon",
        }
        MancerDB.showWhere = id
        if Mancer.Refresh then
            Mancer:Refresh()
        end
        return
    end
    Mancer.SetShowWherePlace("all", true)
end

function Mancer.GetInstanceKind()
    if not IsInInstance then
        return "world"
    end
    local inInstance, instanceType = IsInInstance()
    if not inInstance or not instanceType or instanceType == "" or instanceType == "none" then
        return "world"
    end
    if instanceType == "raid" then
        return "raid"
    end
    if instanceType == "party" then
        return "dungeon"
    end
    -- pvp / arena / other: not open world, not dungeon/raid filters
    return instanceType
end

-- Stance prompt allowed here? Move-mode / Display preview always allowed.
function Mancer.IsStancePromptAllowed()
    if Mancer.FloatingText and Mancer.FloatingText.moveMode then
        return true
    end
    if Mancer.Options and Mancer.Options.window and Mancer.Options.window:IsShown() then
        return true
    end
    local places = Mancer.GetShowWherePlaces()
    -- All three → everywhere (including pvp/arena).
    if places.world and places.raid and places.dungeon then
        return true
    end
    local kind = Mancer.GetInstanceKind()
    if kind == "world" then
        return places.world and true or false
    end
    if kind == "raid" then
        return places.raid and true or false
    end
    if kind == "dungeon" then
        return places.dungeon and true or false
    end
    return false
end

-- Back-compat alias (older calls).
function Mancer.IsHudContextAllowed()
    return Mancer.IsStancePromptAllowed()
end

function Mancer.Print(msg)
    local text = tostring(msg)
    -- Hub / ReportUI capture: collect lines only — do not spam chat.
    if Mancer.reportSink then
        table.insert(Mancer.reportSink, text)
        return
    end
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff" .. (Mancer.DISPLAY_NAME or "Libellus Leti") .. "|r: " .. text)
    end
end

function Mancer.Trim(msg)
    return (msg or ""):match("^%s*(.-)%s*$") or ""
end

local ADDON_FOLDER = Mancer.ADDON_FOLDER or "LibellusLeti"
local ADDON_ROOT = "Interface\\AddOns\\" .. ADDON_FOLDER .. "\\"
local MANCER_AURA = ADDON_ROOT .. "PowerAurasMedia\\Auras\\"
local WEAKAURAS_AURA = "Interface\\Addons\\WeakAuras\\PowerAurasMedia\\Auras\\"

Mancer.BAR_TEXTURES = {
    { name = "Runed Text", path = MANCER_AURA .. "Aura1", splitHalf = true },
    { name = "Runed Text On Ring", path = MANCER_AURA .. "Aura2", splitHalf = true },
    { name = "Power Waves", path = MANCER_AURA .. "Aura3", splitHalf = true },
    { name = "Majesty", path = MANCER_AURA .. "Aura4", splitHalf = true },
    { name = "Runed Ends", path = MANCER_AURA .. "Aura5", splitHalf = true },
    { name = "Extra Majesty", path = MANCER_AURA .. "Aura6", splitHalf = true },
    { name = "Triangular Highlights", path = MANCER_AURA .. "Aura7", splitHalf = true },
    { name = "Oblong Highlights", path = MANCER_AURA .. "Aura11", splitHalf = true },
    { name = "Thin Crescents", path = MANCER_AURA .. "Aura16", splitHalf = true },
    { name = "Crescent Highlights", path = MANCER_AURA .. "Aura17", splitHalf = true },
    { name = "Dense Runed Text", path = MANCER_AURA .. "Aura18", splitHalf = true },
    { name = "Runed Spiked Ring", path = MANCER_AURA .. "Aura23", splitHalf = true },
    { name = "Smoke", path = MANCER_AURA .. "Aura24", splitHalf = true },
    { name = "Flourished Text", path = MANCER_AURA .. "Aura28", splitHalf = true },
    { name = "Droplet Highlights", path = MANCER_AURA .. "Aura33", splitHalf = true },
}

function Mancer.GetBarTextureName(path)
    path = Mancer.NormalizeBarTexturePath(path)
    for _, entry in ipairs(Mancer.BAR_TEXTURES) do
        if entry.path == path then
            return entry.name
        end
    end
    return "Runed Text"
end

function Mancer.GetBarTexturePath(path)
    if path and path ~= "" then
        return path
    end
    return Mancer.BAR_TEXTURES[1].path
end

function Mancer.NormalizeBarTexturePath(path)
    if type(path) ~= "string" or path == "" then
        return Mancer.BAR_TEXTURES[1].path
    end

    path = path:gsub("/", "\\")
        :gsub("\\AddOns\\", "\\Addons\\")
        :gsub("\\CombatText\\", "\\" .. ADDON_FOLDER .. "\\")
        :gsub("\\RunePulse\\", "\\" .. ADDON_FOLDER .. "\\")
        :gsub("\\WeakAuras\\PowerAurasMedia\\Auras\\", "\\" .. ADDON_FOLDER .. "\\PowerAurasMedia\\Auras\\")
        :gsub("\\Addons\\WeakAuras\\PowerAurasMedia\\Auras\\", "\\" .. ADDON_FOLDER .. "\\PowerAurasMedia\\Auras\\")
        :gsub("\\Mancer\\Media\\Auras\\", "\\" .. ADDON_FOLDER .. "\\PowerAurasMedia\\Auras\\")
        :gsub("\\LibellusLeti\\Media\\Auras\\", "\\" .. ADDON_FOLDER .. "\\PowerAurasMedia\\Auras\\")

    if path:find("VineStem", 1, true) or path:find("Aura124", 1, true) then
        return MANCER_AURA .. "Aura1"
    end

    local flatAura = path:match("\\Mancer\\Media\\(Aura%d+)$")
        or path:match("\\LibellusLeti\\Media\\(Aura%d+)$")
    if flatAura then
        path = MANCER_AURA .. flatAura
    end

    for _, entry in ipairs(Mancer.BAR_TEXTURES) do
        if entry.path == path then
            return path
        end
    end

    local base = path:match("[^\\]+$")
    if base and base:match("^Aura%d+$") then
        return MANCER_AURA .. base
    end

    return path
end

function Mancer.GetBarTextureMeta(path)
    path = Mancer.NormalizeBarTexturePath(path)
    for _, entry in ipairs(Mancer.BAR_TEXTURES) do
        if entry.path == path then
            return entry
        end
    end

    local base = path:match("[^\\]+$")
    if base == "Aura124" or base == "VineStem" then
        return Mancer.BAR_TEXTURES[1]
    end
    if base then
        for _, entry in ipairs(Mancer.BAR_TEXTURES) do
            if entry.path:match("[^\\]+$") == base then
                return entry
            end
        end
    end

    return Mancer.BAR_TEXTURES[1]
end

function Mancer.UsesSplitBarTexture(path)
    local entry = Mancer.GetBarTextureMeta(path)
    return entry and entry.splitHalf == true
end

function Mancer.GetBarTextureLoadPaths(metaPath)
    metaPath = Mancer.NormalizeBarTexturePath(metaPath)
    local base = metaPath:match("[^\\]+$") or "Aura1"
    local paths = {}

    local function add(path)
        for _, existing in ipairs(paths) do
            if existing == path then
                return
            end
        end
        paths[#paths + 1] = path
    end

    add(MANCER_AURA .. base)
    add(MANCER_AURA .. base .. ".tga")
    add(ADDON_ROOT .. "Media\\Auras\\" .. base)
    add(ADDON_ROOT .. "Media\\Auras\\" .. base .. ".tga")
    add(ADDON_ROOT .. "PowerAurasMedia\\Auras\\" .. base)
    add(ADDON_ROOT .. "Media\\Auras\\" .. base)
    add(ADDON_ROOT .. "Media\\" .. base)
    add(ADDON_ROOT .. "Media\\" .. base)
    add(WEAKAURAS_AURA .. base)
    add("Interface\\AddOns\\WeakAuras\\PowerAurasMedia\\Auras\\" .. base)

    return paths
end

local DEFAULTS = {
    showMana = true,
    showHealth = true,
    showManaBar = true,
    showHealthBar = true,
    showAnimateBar = true,
    showProcBar = true,
    consolidateBuffs = false,
    showZombieCounter = true,
    showRegenRate = true,
    showWhere = "all",
    showWherePlaces = { world = true, raid = true, dungeon = true },
    regenOnly = false,
    fontSize = 22,
    fontFile = "Fonts\\FRIZQT__.TTF",
    anchorX = 0,
    anchorY = 80,
    arcRadius = 65,
    scale = 1.0,
    manaColor = { 0.35, 0.65, 1.0 },
    healthColor = { 0.35, 0.95, 0.45 },
    rateColor = { 0.85, 0.85, 0.85 },
    barTexture = MANCER_AURA .. "Aura1",
    barTransform = {
        unified = { scale = 1.0, width = 1.0, height = 1.0, offsetX = 0, offsetY = 0 },
        mana = { width = 1.0, height = 1.0, offsetX = 0, offsetY = 0 },
        health = { width = 1.0, height = 1.0, offsetX = 0, offsetY = 0 },
    },
    advisorTextOffset = { x = 0, y = 28 },
    animateBarOffset = { x = 0, y = -40 },
    zombieCounterOffset = { x = 56, y = -40 },
    procBarOffset = { x = -56, y = -40 },
    moveHelpOffset = { x = 0, y = -160 },
    animateIconScale = 0.75,
    zombieIconScale = 0.85,
    procIconScale = 0.8,
    advisorTextScale = 1.0,
    necromancer = {
        enabled = true,
        stanceEnabled = true,
        emptyMinionPrompt = "No minions",
        alertColor = { 0.25, 0.95, 0.75 },
        minionMax = {
            autoLifeForce = true,
        },
    },
    minimap = {
        hide = false,
        angle = 220,
    },
    talentOverlay = {
        show = false,
    },
}

local function CopyDefaults(source, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(source[key]) ~= "table" then
                source[key] = {}
            end
            CopyDefaults(source[key], value)
        elseif source[key] == nil then
            source[key] = value
        end
    end
end

local function MigrateSavedVariables()
    if MancerDB == nil and RunePulseDB ~= nil then
        MancerDB = RunePulseDB
    end
    if MancerDB == nil and CombatTextDB ~= nil then
        MancerDB = CombatTextDB
    end
    MancerDB = MancerDB or {}

    if type(MancerDB.barTexture) == "string" then
        MancerDB.barTexture = Mancer.NormalizeBarTexturePath(MancerDB.barTexture)
    end

    -- Old purple advisor text → Life Force teal (matches LF orb).
    local necro = MancerDB.necromancer
    if type(necro) == "table" and type(necro.alertColor) == "table" then
        local r, g, b = necro.alertColor[1], necro.alertColor[2], necro.alertColor[3]
        if r and g and b
            and math.abs(r - 0.85) < 0.02
            and math.abs(g - 0.35) < 0.02
            and math.abs(b - 1.0) < 0.02 then
            necro.alertColor = { 0.25, 0.95, 0.75 }
        end
    end

    -- Minimap button is on by default (re-enable once for older saved profiles).
    MancerDB.minimap = MancerDB.minimap or {}
    if not MancerDB.minimapDefaultOn_v183 then
        MancerDB.minimap.hide = false
        MancerDB.minimapDefaultOn_v183 = true
    end
    if MancerDB.minimap.hide == nil then
        MancerDB.minimap.hide = false
    end

    -- Drop saved fonts that are not in the Ascension/3.3.5 set.
    if Mancer.ResolveFontFile then
        MancerDB.fontFile = Mancer.ResolveFontFile(MancerDB.fontFile)
    end

    -- Advisor T-scale was often left at 2.0 while visuals were font-capped; reset once.
    if not MancerDB.advisorScaleHeight_v282 then
        MancerDB.advisorTextScale = 1.0
        MancerDB.advisorScaleHeight_v282 = true
    end

    -- Where: migrate exclusive string → multi-select places table.
    if type(MancerDB.showWherePlaces) ~= "table" then
        local id = MancerDB.showWhere
        if id == "world" then
            MancerDB.showWherePlaces = { world = true, raid = false, dungeon = false }
        elseif id == "raid" then
            MancerDB.showWherePlaces = { world = false, raid = true, dungeon = false }
        elseif id == "dungeon" then
            MancerDB.showWherePlaces = { world = false, raid = false, dungeon = true }
        else
            MancerDB.showWherePlaces = { world = true, raid = true, dungeon = true }
        end
    else
        MancerDB.showWherePlaces.world = not not MancerDB.showWherePlaces.world
        MancerDB.showWherePlaces.raid = not not MancerDB.showWherePlaces.raid
        MancerDB.showWherePlaces.dungeon = not not MancerDB.showWherePlaces.dungeon
    end
    if MancerDB.showWherePlaces.world and MancerDB.showWherePlaces.raid and MancerDB.showWherePlaces.dungeon then
        MancerDB.showWhere = "all"
    elseif MancerDB.showWherePlaces.world and not MancerDB.showWherePlaces.raid and not MancerDB.showWherePlaces.dungeon then
        MancerDB.showWhere = "world"
    elseif MancerDB.showWherePlaces.raid and not MancerDB.showWherePlaces.world and not MancerDB.showWherePlaces.dungeon then
        MancerDB.showWhere = "raid"
    elseif MancerDB.showWherePlaces.dungeon and not MancerDB.showWherePlaces.world and not MancerDB.showWherePlaces.raid then
        MancerDB.showWhere = "dungeon"
    else
        MancerDB.showWhere = "custom"
    end
end

function Mancer:GetConfig()
    return MancerDB
end

function Mancer:Refresh()
    if self.FloatingText then
        self.FloatingText:ApplyConfig()
    end
    if self.RegenTracker then
        self.RegenTracker:ApplyConfig()
    end
    if self.NecromancerAdvisor then
        self.NecromancerAdvisor:ApplyConfig()
    end
    if Mancer.BuffConsolidateModule and Mancer.BuffConsolidateModule.ApplyConsolidation then
        Mancer.BuffConsolidateModule:ApplyConsolidation()
    end
end

function Mancer.OpenHub()
    if Mancer.Hub and Mancer.Hub.Open then
        Mancer.Hub:Open()
    elseif Mancer.Options then
        Mancer.Options:Open()
    end
end

function Mancer.Notify(msg)
    if Mancer.Hub and Mancer.Hub.SetStatus then
        Mancer.Hub:SetStatus(msg)
    elseif Mancer.Print then
        Mancer.Print(msg)
    end
end

local function HandleSlashCommand(msg)
    msg = tostring(msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "stance" or msg == "stances" or msg == "coa" then
        if Mancer.NecromancerAdvisor and Mancer.NecromancerAdvisor.PrintStanceDebug then
            Mancer.NecromancerAdvisor:PrintStanceDebug()
        else
            print("|cff7fd4ff" .. (Mancer.DISPLAY_NAME or "Libellus Leti") .. "|r stance debug not loaded yet — try after login.")
        end
        return
    end
    Mancer.OpenHub()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and (arg1 == "LibellusLeti" or arg1 == "Mancer") then
        MigrateSavedVariables()
        CopyDefaults(MancerDB, DEFAULTS)
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if Mancer.Refresh then
            Mancer:Refresh()
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        local function safeInit(name, fn)
            local ok, err = pcall(fn)
            if not ok and Mancer.Hub then
                Mancer.Hub:Notify("Failed to load " .. name .. ": " .. tostring(err))
            end
            return ok
        end

        safeInit("FloatingText", function()
            if not Mancer.FloatingText then
                Mancer.FloatingText = Mancer.FloatingTextModule:New()
            end
        end)

        if Mancer.ArcBarsModule then
            safeInit("ArcBars", function()
                if not Mancer.ArcBars then
                    Mancer.ArcBars = Mancer.ArcBarsModule:New()
                end
            end)
        end

        safeInit("RegenTracker", function()
            if not Mancer.RegenTracker then
                Mancer.RegenTracker = Mancer.RegenTrackerModule:New()
            end
        end)

        safeInit("MinionDps", function()
            if Mancer.MinionDpsModule then
                Mancer.MinionDpsModule:Init()
            end
        end)

        safeInit("MinionTooltip", function()
            if Mancer.MinionTooltipModule then
                Mancer.MinionTooltipModule:Init()
            end
        end)

        safeInit("NecromancerAdvisor", function()
            if Mancer.NecromancerAdvisorModule and not Mancer.NecromancerAdvisor then
                Mancer.NecromancerAdvisor = Mancer.NecromancerAdvisorModule:New()
            end
        end)

        safeInit("BuffConsolidate", function()
            if Mancer.BuffConsolidateModule then
                Mancer.BuffConsolidateModule:Init()
            end
        end)

        safeInit("MinimapButton", function()
            if Mancer.MinimapButtonModule then
                Mancer.MinimapButtonModule:Init()
            end
        end)

        safeInit("TalentOverlay", function()
            if Mancer.TalentOverlayModule then
                Mancer.TalentOverlayModule:Init()
            end
        end)

        safeInit("Hub", function()
            if Mancer.Hub then
                Mancer.Hub:DetachCoASectionRail()
                Mancer.Hub:Create()
                Mancer.Hub:HookCoATalentFrame()
            end
        end)

        Mancer.Options:Initialize()
        Mancer:Refresh()
        Mancer.Print("v" .. Mancer.GetVersion() .. " loaded. Type /leti to open.")
    end
end)

-- Options panel (kept in Core.lua so it always loads with the addon)
local Options = Mancer.Options

-- Game fonts (always present) + bundled Media\\Fonts (addon paths).
-- Later Blizzard names (2002, PVPFont, etc.) are not on Ascension 3.3.5.
local ADDON_FONT = ADDON_ROOT .. "Media\\Fonts\\"
Mancer.FONTS = {
    { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { name = "Skurri", path = "Fonts\\skurri.ttf" },
    { name = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
    { name = "PT Sans Narrow", path = ADDON_FONT .. "PTSansNarrow-Regular.ttf" },
    { name = "PT Sans Narrow Bold", path = ADDON_FONT .. "PTSansNarrow-Bold.ttf" },
    { name = "Fira Sans Heavy", path = ADDON_FONT .. "FiraSans-Heavy.ttf" },
    { name = "Fira Condensed Heavy", path = ADDON_FONT .. "FiraSansCondensed-Heavy.ttf" },
    { name = "Fira Mono", path = ADDON_FONT .. "FiraMono-Medium.ttf" },
    { name = "Oswald", path = ADDON_FONT .. "Oswald-Regular.ttf" },
    { name = "Forced Square", path = ADDON_FONT .. "ForcedSquare.ttf" },
    { name = "Accidental Presidency", path = ADDON_FONT .. "AccidentalPresidency.ttf" },
    { name = "TrashHand", path = ADDON_FONT .. "TrashHand.ttf" },
}

local DEFAULT_FONT_PATH = "Fonts\\FRIZQT__.TTF"

local function FontPathKnown(path)
    if not path then
        return false
    end
    for _, font in ipairs(Mancer.FONTS) do
        if font.path == path then
            return true
        end
    end
    return false
end

local function GetFontName(path)
    for _, font in ipairs(Mancer.FONTS) do
        if font.path == path then
            return font.name
        end
    end
    return "Friz Quadrata"
end

function Mancer.ResolveFontFile(path)
    if FontPathKnown(path) then
        return path
    end
    return DEFAULT_FONT_PATH
end

local OPTION_TIPS = {
    showMana = {
        title = "Show mana ticks",
        lines = {
            "Shows floating text when you gain mana (regen ticks, potions, etc.).",
            "Appears near your arc / combat text anchors.",
        },
    },
    showHealth = {
        title = "Show health ticks",
        lines = {
            "Shows floating text when you gain health (regen, heals, bandages, etc.).",
            "Appears near your arc / combat text anchors.",
        },
    },
    showRegenRate = {
        title = "Show last mana tick label",
        lines = {
            "Shows a small HUD label with the size of your last mana tick",
            "(for example “Last mana tick: +42”).",
            "Useful while calibrating regen; turn off if you want a cleaner HUD.",
        },
    },
    regenOnly = {
        title = "Regen-only filter",
        lines = {
            "Only show floating mana/health ticks from natural regeneration.",
            "Hides ticks from potions, bandages, spells, and other burst gains.",
            "Leave off if you want every heal and mana gain to appear.",
        },
    },
    showManaBar = {
        title = "Show mana arc bar",
        lines = {
            "Shows the curved mana resource arc around your character.",
            "Uses your chosen bar texture from the options below.",
        },
    },
    showHealthBar = {
        title = "Show health arc bar",
        lines = {
            "Shows the curved health resource arc around your character.",
            "Uses your chosen bar texture from the options below.",
        },
    },
    showAnimateBar = {
        title = "Show Animate bar",
        lines = {
            "Shows the Animate readiness strip (A handle) with cooldown timers.",
            "Icons auto-update from Animates you have taken in your Character Advancement talent tree.",
            "Ready Animates pulse; while out, the timer is seconds until they despawn; on cooldown icons stay dim.",
            "Left-click an icon to cast that Animate (secure click — never auto-casts).",
            "Spell binding updates out of combat; clicks still work in combat once bound.",
        },
    },
    showProcBar = {
        title = "Show proc bar",
        lines = {
            "Shows a proc/trigger strip (P handle) for Diabolical and Bone King.",
            "Each icon tracks remaining duration (center) and stacks (corner).",
            "Drag P in move mode; mousewheel scales the icons.",
        },
    },
    consolidateBuffs = {
        title = "Stack duplicate buffs",
        lines = {
            "On the default buff bar, merges auras that share the same spell ID into one icon.",
            "Covers every Raise (ghouls, fiends, aboms, skeletons, …) and any other true duplicates.",
            "Uses Ascension’s consolidate pattern (reparent off-strip), not hide/reflow.",
            "Off by default.",
        },
    },
    showZombieCounter = {
        title = "Show zombie counter",
        lines = {
            "Shows a Harvest Plague zombie icon with how many are currently alive.",
            "Requires Unrelenting Army. Drag the Z handle in move mode; mousewheel scales it.",
            "Minion DPS reports also list how many zombies spawned each fight.",
        },
    },
    showWhere = {
        title = "Where",
        lines = {
            "Controls where Undead stance prompts appear.",
            "Tick any mix of Open world, Raids, and Dungeons.",
            "All checks every place; unticking one clears All.",
        },
    },
    showWhere_all = {
        title = "All",
        lines = {
            "Tick to enable stance prompts everywhere.",
            "Untick to clear Open world, Raids, and Dungeons.",
        },
    },
    showWhere_world = {
        title = "Open world",
        lines = {
            "Show stance prompts in open world.",
            "Can be combined with Raids and Dungeons.",
        },
    },
    showWhere_raid = {
        title = "Raids",
        lines = {
            "Show stance prompts in raids.",
            "Can be combined with Open world and Dungeons.",
        },
    },
    showWhere_dungeon = {
        title = "Dungeons",
        lines = {
            "Show stance prompts in dungeons.",
            "Can be combined with Open world and Raids.",
        },
    },
    showMinimapButton = {
        title = "Show minimap button",
        lines = {
            "Shows the Mancer button on the minimap.",
            "Right-click the button for Hub / Display / Hide shortcuts.",
        },
    },
    minionDpsTooltips = {
        title = "Minion DPS spell tooltips",
        lines = {
            "Adds estimated minion DPS notes to relevant spell tooltips.",
            "Turn off if you want the default Ascension tooltip text only.",
        },
    },
}

local function ShowOptionTip(owner, tip)
    if not tip or not GameTooltip then
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local accent = Mancer.UI and Mancer.UI.Colors and Mancer.UI.Colors.accent
    if accent then
        GameTooltip:AddLine(tip.title, accent[1], accent[2], accent[3])
    else
        GameTooltip:AddLine(tip.title, 0.25, 0.95, 0.75)
    end
    for _, line in ipairs(tip.lines or {}) do
        GameTooltip:AddLine(line, 0.9, 0.9, 0.9, true)
    end
    GameTooltip:Show()
end

local function AttachOptionTip(frame, dbKey)
    local tip = OPTION_TIPS[dbKey]
    if not frame or not tip then
        return
    end
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        ShowOptionTip(self, tip)
    end)
    frame:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
end

local function CreateSectionLabel(parent, text, anchorTo, yOffset, sectionWidth)
    local section
    if Mancer.UI and Mancer.UI.CreateSection then
        section = Mancer.UI.CreateSection(parent, text, anchorTo, yOffset or -16)
    else
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        label:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, yOffset or -16)
        label:SetText(text)
        section = label
    end
    if section and section.SetWidth and sectionWidth then
        section:SetWidth(sectionWidth)
    end
    return section
end

local function CreateCheckboxRow(parent, label, anchorTo, yGap, dbKey, rowWidth)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(rowWidth or 240, 24)
    row:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, yGap)

    local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("LEFT", row, "LEFT", 0, 0)

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    text:SetJustifyH("LEFT")
    text:SetText(label)
    if Mancer.UI and Mancer.UI.StyleTitle then
        Mancer.UI.StyleTitle(text)
    end

    -- Invisible hit area over the label (FontStrings do not receive mouse).
    local hit = CreateFrame("Button", nil, row)
    hit:SetPoint("LEFT", text, "LEFT", -2, 0)
    hit:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    hit:SetHeight(20)
    hit:SetFrameLevel((row:GetFrameLevel() or 1) + 2)
    hit:RegisterForClicks("AnyUp")
    hit:SetScript("OnClick", function()
        cb:Click()
    end)

    AttachOptionTip(cb, dbKey)
    AttachOptionTip(hit, dbKey)

    cb:SetScript("OnClick", function(self)
        MancerDB[dbKey] = self:GetChecked() == 1
        Mancer:Refresh()
    end)

    row.checkbox = cb
    row.hit = hit
    return row
end

local function CreateButton(parent, width, height, text, anchorTo, x, y)
    -- Native red/gold UIPanel buttons (same family as Hub / Minion Sheet arrows).
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, height)
    btn:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", x, y)
    btn:SetText(text)
    return btn
end

function Options:GetBarTextureIndex()
    local path = Mancer.NormalizeBarTexturePath(MancerDB.barTexture or Mancer.BAR_TEXTURES[1].path)
    for i, entry in ipairs(Mancer.BAR_TEXTURES) do
        if entry.path == path then
            return i
        end
    end
    return 1
end

function Options:CycleBarTexture(delta)
    local index = self:GetBarTextureIndex() + delta
    if index > #Mancer.BAR_TEXTURES then
        index = 1
    elseif index < 1 then
        index = #Mancer.BAR_TEXTURES
    end

    MancerDB.barTexture = Mancer.BAR_TEXTURES[index].path
    if self.barValueText then
        self.barValueText:SetText(Mancer.BAR_TEXTURES[index].name)
    end
    if Mancer.ArcBars then
        Mancer.ArcBars:ApplyConfig()
    else
        Mancer:Refresh()
    end
end

function Options:GetFontIndex()
    local path = Mancer.ResolveFontFile(MancerDB.fontFile)
    for i, font in ipairs(Mancer.FONTS) do
        if font.path == path then
            return i
        end
    end
    return 1
end

function Options:CycleFont(delta)
    local index = self:GetFontIndex() + delta
    if index > #Mancer.FONTS then
        index = 1
    elseif index < 1 then
        index = #Mancer.FONTS
    end

    MancerDB.fontFile = Mancer.FONTS[index].path
    if self.fontValueText then
        self.fontValueText:SetText(Mancer.FONTS[index].name)
    end
    Mancer:Refresh()
    if Mancer.FloatingText then
        Mancer.FloatingText:ShowTick("+12 mana", MancerDB.manaColor, "mana")
    end
end

function Options:ChangeFontSize(delta)
    local size = (MancerDB.fontSize or 22) + delta
    size = math.max(12, math.min(48, size))
    MancerDB.fontSize = size
    if self.sizeValueText then
        self.sizeValueText:SetText(tostring(size))
    end
    Mancer:Refresh()
    if Mancer.FloatingText then
        Mancer.FloatingText:ShowTick("+" .. size .. " mana", MancerDB.manaColor, "mana")
    end
end

function Options:UpdateMoveButton()
    if not self.moveBtn then
        return
    end

    local inMoveMode = Mancer.FloatingText and Mancer.FloatingText.moveMode
    if inMoveMode then
        self.moveBtn:SetText("Hide")
    else
        self.moveBtn:SetText("Show")
    end
end

function Options:ResetBarLayout()
    MancerDB.barTransform = {
        unified = { scale = 1.0, width = 1.0, height = 1.0, offsetX = 0, offsetY = 0 },
        mana = { width = 1.0, height = 1.0, offsetX = 0, offsetY = 0 },
        health = { width = 1.0, height = 1.0, offsetX = 0, offsetY = 0 },
    }
    MancerDB.advisorTextOffset = { x = 0, y = 28 }
    MancerDB.animateBarOffset = { x = 0, y = -40 }
    MancerDB.zombieCounterOffset = { x = 56, y = -40 }
    MancerDB.procBarOffset = { x = -56, y = -40 }
    MancerDB.animateIconScale = 0.75
    MancerDB.zombieIconScale = 0.85
    MancerDB.procIconScale = 0.8
    MancerDB.advisorTextScale = 1.0
    if Mancer.FloatingText then
        Mancer.FloatingText:SetMoveMode(false)
    end
    Mancer:Refresh()
end

function Options:ToggleMoveMode()
    if not Mancer.FloatingText then
        return
    end

    Mancer.FloatingText:SetMoveMode(not Mancer.FloatingText.moveMode)
    self:UpdateMoveButton()
end

function Options:SyncControls()
    if not self.window or not MancerDB then
        return
    end

    self.rowMana.checkbox:SetChecked(MancerDB.showMana and 1 or nil)
    self.rowHealth.checkbox:SetChecked(MancerDB.showHealth and 1 or nil)
    self.rowRate.checkbox:SetChecked(MancerDB.showRegenRate and 1 or nil)
    self.rowRegenOnly.checkbox:SetChecked(MancerDB.regenOnly and 1 or nil)
    self.rowManaBar.checkbox:SetChecked(MancerDB.showManaBar and 1 or nil)
    self.rowHealthBar.checkbox:SetChecked(MancerDB.showHealthBar and 1 or nil)
    if self.rowAnimateBar then
        self.rowAnimateBar.checkbox:SetChecked(MancerDB.showAnimateBar ~= false and 1 or nil)
    end
    if self.rowProcBar then
        self.rowProcBar.checkbox:SetChecked(MancerDB.showProcBar ~= false and 1 or nil)
    end
    if self.rowConsolidateBuffs then
        self.rowConsolidateBuffs.checkbox:SetChecked(MancerDB.consolidateBuffs == true and 1 or nil)
    end
    if self.rowZombieCounter then
        self.rowZombieCounter.checkbox:SetChecked(MancerDB.showZombieCounter ~= false and 1 or nil)
    end

    if self.rowMinimap then
        local hidden = MancerDB.minimap and MancerDB.minimap.hide
        self.rowMinimap.checkbox:SetChecked(not hidden and 1 or nil)
    end
    if self.rowTooltip then
        MancerDB.minionDps = MancerDB.minionDps or {}
        local enabled = MancerDB.minionDps.tooltipEnabled ~= false
        self.rowTooltip.checkbox:SetChecked(enabled and 1 or nil)
    end

    if self.barValueText then
        self.barValueText:SetText(Mancer.GetBarTextureName(MancerDB.barTexture))
    end

    if self.fontValueText then
        self.fontValueText:SetText(GetFontName(Mancer.ResolveFontFile(MancerDB.fontFile)))
    end
    if self.sizeValueText then
        self.sizeValueText:SetText(tostring(MancerDB.fontSize or 22))
    end

    if self.whereRows then
        local places = Mancer.GetShowWherePlaces and Mancer.GetShowWherePlaces() or {
            world = true, raid = true, dungeon = true,
        }
        local allOn = places.world and places.raid and places.dungeon
        for id, row in pairs(self.whereRows) do
            if row.checkbox then
                local on = (id == "all") and allOn or places[id]
                row.checkbox:SetChecked(on and 1 or nil)
            end
        end
    end

    self:UpdateMoveButton()
end

function Options:CreatePanel()
    if self.window then
        return
    end

    local ui = Mancer.UI
    local window
    if ui and ui.CreateHubRootFrame then
        window = ui.CreateHubRootFrame("MancerConfigFrame", UIParent)
    else
        window = CreateFrame("Frame", "MancerConfigFrame", UIParent)
    end
    window:SetSize(580, 640)
    window:SetPoint("CENTER")
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function(frame)
        frame:StartMoving()
    end)
    window:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
    end)
    window:SetFrameStrata("DIALOG")
    window:Hide()

    if ui and ui.SkinFrame then
        -- Metal chrome + red X; Display BG = DefaultTalentArt1 priest shadow tile.
        local bg = ui.DISPLAY_BG or {}
        ui.SkinFrame(window, {
            nativeChrome = true,
            artAtlas = bg.atlas,
            artPath = bg.path,
            artCoords = bg.left and { bg.left, bg.right, bg.top, bg.bottom } or nil,
            artScrub = 0.58,
            artInset = bg.artInset or 2,
            artTopInset = bg.artTopInset or 24,
            title = "Mancer Display",
        })
    elseif ui and ui.ApplyMetalPortraitBorder then
        ui.ApplyMetalPortraitBorder(window)
        if ui.CreateNativeCloseButton then
            ui.CreateNativeCloseButton(window)
        end
    elseif window.SetBackdrop then
        window:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            tileSize = 8,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        window:SetBackdropColor(0.08, 0.09, 0.11, 0.96)
        window:SetBackdropBorderColor(0.18, 0.22, 0.24, 1)
        if ui and ui.CreateNativeCloseButton then
            ui.CreateNativeCloseButton(window)
        end
    end

    -- Content inset clears portrait chrome / title strip.
    local panel = CreateFrame("Frame", nil, window)
    panel:SetPoint("TOPLEFT", 22, -68)
    panel:SetPoint("BOTTOMRIGHT", -22, 28)
    self.window = window
    self.panel = panel

    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    desc:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    desc:SetWidth(520)
    desc:SetJustifyH("LEFT")
    desc:SetText("Resource bars, floating regen ticks, and Necromancer minion reminders.")
    if ui and ui.StyleMuted then
        ui.StyleMuted(desc)
    end

    -- Where | Display (Display split into two checkbox columns so it doesn't crowd Bar texture).
    local cols = CreateFrame("Frame", nil, panel)
    cols:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
    cols:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
    cols:SetHeight(230)

    local leftCol = CreateFrame("Frame", nil, cols)
    leftCol:SetPoint("TOPLEFT", cols, "TOPLEFT", 0, 0)
    leftCol:SetPoint("BOTTOM", cols, "BOTTOM", 0, 0)
    leftCol:SetWidth(140)

    local displayCol = CreateFrame("Frame", nil, cols)
    displayCol:SetPoint("TOPLEFT", leftCol, "TOPRIGHT", 14, 0)
    displayCol:SetPoint("BOTTOMRIGHT", cols, "BOTTOMRIGHT", 0, 0)

    local leftTop = CreateFrame("Frame", nil, leftCol)
    leftTop:SetPoint("TOPLEFT", leftCol, "TOPLEFT", 0, 0)
    leftTop:SetSize(1, 1)
    local whereHeader = CreateSectionLabel(leftCol, "Where", leftTop, 0, 140)
    whereHeader:ClearAllPoints()
    whereHeader:SetPoint("TOPLEFT", leftCol, "TOPLEFT", 0, 0)

    self.whereRows = {}
    local whereAnchor = whereHeader
    local whereOptions = Mancer.GetShowWhereOptions and Mancer.GetShowWhereOptions() or {
        { id = "all", label = "All" },
        { id = "world", label = "Open world" },
        { id = "raid", label = "Raids" },
        { id = "dungeon", label = "Dungeons" },
    }
    for i, opt in ipairs(whereOptions) do
        local tipKey = "showWhere_" .. opt.id
        local row = CreateCheckboxRow(leftCol, opt.label, whereAnchor, i == 1 and -6 or -2, tipKey, 138)
        local function applyWhereClick(checked)
            if Mancer.SetShowWherePlace then
                Mancer.SetShowWherePlace(opt.id, checked)
            else
                Mancer.SetShowWhere(opt.id)
            end
            Options:SyncControls()
        end
        row.checkbox:SetScript("OnClick", function(self)
            applyWhereClick(self:GetChecked() == 1)
        end)
        row.hit:SetScript("OnClick", function()
            local checked = not (row.checkbox:GetChecked() == 1)
            row.checkbox:SetChecked(checked and 1 or nil)
            applyWhereClick(checked)
        end)
        AttachOptionTip(row.checkbox, tipKey)
        AttachOptionTip(row.hit, tipKey)
        self.whereRows[opt.id] = row
        whereAnchor = row
    end

    local rightTop = CreateFrame("Frame", nil, displayCol)
    rightTop:SetPoint("TOPLEFT", displayCol, "TOPLEFT", 0, 0)
    rightTop:SetSize(1, 1)
    local displayHeader = CreateSectionLabel(displayCol, "Display", rightTop, 0, 380)
    displayHeader:ClearAllPoints()
    displayHeader:SetPoint("TOPLEFT", displayCol, "TOPLEFT", 0, 0)

    local dispLeft = CreateFrame("Frame", nil, displayCol)
    dispLeft:SetPoint("TOPLEFT", displayHeader, "BOTTOMLEFT", 0, -6)
    dispLeft:SetPoint("BOTTOM", displayCol, "BOTTOM", 0, 0)
    dispLeft:SetWidth(200)

    local dispRight = CreateFrame("Frame", nil, displayCol)
    dispRight:SetPoint("TOPLEFT", dispLeft, "TOPRIGHT", 10, 0)
    dispRight:SetPoint("BOTTOMRIGHT", displayCol, "BOTTOMRIGHT", 0, 0)

    local dispLeftTop = CreateFrame("Frame", nil, dispLeft)
    dispLeftTop:SetPoint("TOPLEFT", dispLeft, "TOPLEFT", 0, 0)
    dispLeftTop:SetSize(1, 1)
    local dispRightTop = CreateFrame("Frame", nil, dispRight)
    dispRightTop:SetPoint("TOPLEFT", dispRight, "TOPLEFT", 0, 0)
    dispRightTop:SetSize(1, 1)

    self.rowMana = CreateCheckboxRow(dispLeft, "Show mana ticks", dispLeftTop, 0, "showMana", 198)
    self.rowHealth = CreateCheckboxRow(dispLeft, "Show health ticks", self.rowMana, -2, "showHealth", 198)
    self.rowRate = CreateCheckboxRow(dispLeft, "Show last mana tick label", self.rowHealth, -2, "showRegenRate", 198)
    self.rowRegenOnly = CreateCheckboxRow(dispLeft, "Regen-only filter", self.rowRate, -2, "regenOnly", 198)
    self.rowManaBar = CreateCheckboxRow(dispLeft, "Show mana arc bar", self.rowRegenOnly, -2, "showManaBar", 198)
    self.rowHealthBar = CreateCheckboxRow(dispLeft, "Show health arc bar", self.rowManaBar, -2, "showHealthBar", 198)
    self.rowAnimateBar = CreateCheckboxRow(dispLeft, "Show Animate bar", self.rowHealthBar, -2, "showAnimateBar", 198)

    self.rowConsolidateBuffs = CreateCheckboxRow(dispRight, "Stack duplicate buffs", dispRightTop, 0, "consolidateBuffs", 198)
    self.rowProcBar = CreateCheckboxRow(dispRight, "Show proc bar", self.rowConsolidateBuffs, -2, "showProcBar", 198)
    self.rowZombieCounter = CreateCheckboxRow(dispRight, "Show zombie counter", self.rowProcBar, -2, "showZombieCounter", 198)
    self.rowMinimap = CreateCheckboxRow(dispRight, "Show minimap button", self.rowZombieCounter, -2, "showMinimapButton", 198)
    self.rowMinimap.checkbox:SetScript("OnClick", function(self)
        local show = self:GetChecked() == 1
        if Mancer.MinimapButtonModule then
            Mancer.MinimapButtonModule:SetHidden(not show)
        else
            MancerDB.minimap = MancerDB.minimap or {}
            MancerDB.minimap.hide = not show
        end
    end)

    self.rowTooltip = CreateCheckboxRow(dispRight, "Minion DPS spell tooltips", self.rowMinimap, -2, "minionDpsTooltips", 198)
    self.rowTooltip.checkbox:SetScript("OnClick", function(self)
        local enabled = self:GetChecked() == 1
        if Mancer.MinionTooltipModule then
            Mancer.MinionTooltipModule:SetEnabled(enabled)
        else
            MancerDB.minionDps = MancerDB.minionDps or {}
            MancerDB.minionDps.tooltipEnabled = enabled
        end
    end)

    local barHeader = CreateSectionLabel(panel, "Bar texture", cols, -16, 520)
    barHeader:ClearAllPoints()
    barHeader:SetPoint("TOPLEFT", cols, "BOTTOMLEFT", 0, -16)

    local barPrev = CreateButton(panel, 32, 22, "<", barHeader, 0, -8)
    barPrev:ClearAllPoints()
    barPrev:SetPoint("TOPLEFT", barHeader, "BOTTOMLEFT", 0, -8)
    local barNext = CreateButton(panel, 32, 22, ">", barHeader, 36, -8)
    barNext:ClearAllPoints()
    barNext:SetPoint("LEFT", barPrev, "RIGHT", 4, 0)

    self.barValueText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.barValueText:SetPoint("LEFT", barNext, "RIGHT", 12, 0)
    self.barValueText:SetWidth(280)
    self.barValueText:SetJustifyH("LEFT")
    self.barValueText:SetText("Runed Text")

    barPrev:SetScript("OnClick", function()
        Options:CycleBarTexture(-1)
    end)
    barNext:SetScript("OnClick", function()
        Options:CycleBarTexture(1)
    end)

    local fontHeader = CreateSectionLabel(panel, "Font", barPrev, -14)

    local fontPrev = CreateButton(panel, 32, 22, "<", fontHeader, 0, -8)
    fontPrev:ClearAllPoints()
    fontPrev:SetPoint("TOPLEFT", fontHeader, "BOTTOMLEFT", 0, -8)
    local fontNext = CreateButton(panel, 32, 22, ">", fontHeader, 36, -8)
    fontNext:ClearAllPoints()
    fontNext:SetPoint("LEFT", fontPrev, "RIGHT", 4, 0)

    self.fontValueText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.fontValueText:SetPoint("LEFT", fontNext, "RIGHT", 12, 0)
    self.fontValueText:SetWidth(280)
    self.fontValueText:SetJustifyH("LEFT")
    self.fontValueText:SetText("Friz Quadrata")

    fontPrev:SetScript("OnClick", function()
        Options:CycleFont(-1)
    end)
    fontNext:SetScript("OnClick", function()
        Options:CycleFont(1)
    end)

    local sizeHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeHeader:SetPoint("TOPLEFT", fontPrev, "BOTTOMLEFT", 0, -14)
    sizeHeader:SetText("Font size")
    if ui and ui.StyleAccent then
        ui.StyleAccent(sizeHeader)
    end

    local sizeMinus = CreateButton(panel, 32, 22, "-", sizeHeader, 0, -6)
    sizeMinus:ClearAllPoints()
    sizeMinus:SetPoint("TOPLEFT", sizeHeader, "BOTTOMLEFT", 0, -6)
    local sizePlus = CreateButton(panel, 32, 22, "+", sizeHeader, 36, -6)
    sizePlus:ClearAllPoints()
    sizePlus:SetPoint("LEFT", sizeMinus, "RIGHT", 4, 0)

    self.sizeValueText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.sizeValueText:SetPoint("LEFT", sizePlus, "RIGHT", 12, 0)
    self.sizeValueText:SetText("22")

    sizeMinus:SetScript("OnClick", function()
        Options:ChangeFontSize(-2)
    end)
    sizePlus:SetScript("OnClick", function()
        Options:ChangeFontSize(2)
    end)

    local layoutHeader = CreateSectionLabel(panel, "Layout", sizeMinus, -14)

    self.moveBtn = CreateButton(panel, 120, 24, "Show", layoutHeader, 0, -8)
    self.moveBtn:ClearAllPoints()
    self.moveBtn:SetPoint("TOPLEFT", layoutHeader, "BOTTOMLEFT", 0, -8)
    self.moveBtn:SetScript("OnClick", function()
        Options:ToggleMoveMode()
    end)

    local testBtn = CreateButton(panel, 120, 24, "Test Preview", self.moveBtn, 0, 0)
    testBtn:ClearAllPoints()
    testBtn:SetPoint("LEFT", self.moveBtn, "RIGHT", 8, 0)
    testBtn:SetScript("OnClick", function()
        if Mancer.FloatingText then
            Mancer.FloatingText:ShowTick("+42 mana", MancerDB.manaColor, "mana")
            Mancer.FloatingText:ShowTick("+18 health", MancerDB.healthColor, "health")
            Mancer.FloatingText:UpdateRateText(42)
        end
    end)

    local resetBtn = CreateButton(panel, 100, 24, "Reset Bars", testBtn, 0, 0)
    resetBtn:ClearAllPoints()
    resetBtn:SetPoint("LEFT", testBtn, "RIGHT", 8, 0)
    resetBtn:SetScript("OnClick", function()
        Options:ResetBarLayout()
    end)

    window:SetScript("OnShow", function()
        Options:SyncControls()
        if Mancer.Refresh then
            Mancer:Refresh()
        end
    end)
    window:SetScript("OnHide", function()
        if Mancer.Refresh then
            Mancer:Refresh()
        end
    end)

    if UISpecialFrames then
        tinsert(UISpecialFrames, "MancerConfigFrame")
    end
end

function Options:Initialize()
    if self.window then
        return
    end

    local ok, err = pcall(function()
        self:CreatePanel()
    end)
    if not ok then
        if Mancer.Hub then
            Mancer.Hub:Notify("Failed to create options window: " .. tostring(err))
        end
    end
end

function Options:Open()
    if not self.window then
        self:Initialize()
    end
    if not self.window then
        if Mancer.Hub then
            Mancer.Hub:Notify("Options window could not be loaded.")
        end
        return
    end
    self:SyncControls()
    self.window:Show()
end

SLASH_LIBELLUSLETI1 = "/leti"
SlashCmdList["LIBELLUSLETI"] = HandleSlashCommand
