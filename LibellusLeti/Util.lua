Mancer.Util = Mancer.Util or {}

local MANA_POWER_TYPE = 0

function Mancer.Util.GetPlayerMana()
    if UnitPower and UnitPowerMax then
        local max = UnitPowerMax("player", MANA_POWER_TYPE)
        if max and max > 0 then
            return UnitPower("player", MANA_POWER_TYPE) or 0, max
        end
    end

    local current = UnitMana and UnitMana("player") or 0
    local max = UnitManaMax and UnitManaMax("player") or 0
    return current or 0, max or 0
end

function Mancer.Util.HasManaBar()
    local _, max = Mancer.Util.GetPlayerMana()
    return max > 0
end

function Mancer.Util.GetPlayerHealth()
    return UnitHealth("player") or 0, UnitHealthMax("player") or 0
end

function Mancer.Util.GetArcOffset(progress, side, radius)
    local angle

    if side == "health" then
        angle = math.rad(-20 + (80 * progress))
    else
        angle = math.rad(200 - (80 * progress))
    end

    return math.cos(angle) * radius, math.sin(angle) * radius
end

function Mancer.Util.GetArcAngle(progress, side)
    if side == "health" then
        return math.rad(-20 + (80 * progress))
    end
    return math.rad(200 - (80 * progress))
end

function Mancer.Util.GetArcRotation(progress, side)
    return Mancer.Util.GetArcAngle(progress, side) + (math.pi / 2)
end

function Mancer.Util.GetArcBounds(side, radius)
    local x0, y0 = Mancer.Util.GetArcOffset(0, side, radius)
    local x1, y1 = Mancer.Util.GetArcOffset(1, side, radius)
    local cx = (x0 + x1) * 0.5
    local cy = (y0 + y1) * 0.5
    local arcLength = radius * math.rad(80)
    local width = math.max(18, radius * 0.38)
    local rotation = math.deg(Mancer.Util.GetArcRotation(0.5, side))

    return cx, cy, arcLength, width, rotation
end

function Mancer.Util.GetFontFile()
    local path = MancerDB.fontFile or "Fonts\\FRIZQT__.TTF"
    if Mancer.ResolveFontFile then
        path = Mancer.ResolveFontFile(path)
    end
    return path
end

-- Ascension/3.3.5 SetFont visually caps around ~22; larger sizes need SetTextHeight.
local FONT_GLYPH_CAP = 18

function Mancer.Util.ApplyFont(fontString, size)
    if not fontString or not fontString.SetFont then
        return
    end
    size = tonumber(size) or 14
    if size < 8 then
        size = 8
    end
    local path = Mancer.Util.GetFontFile()
    local glyph = size
    if glyph > FONT_GLYPH_CAP then
        glyph = FONT_GLYPH_CAP
    end
    local ok = fontString:SetFont(path, glyph, "OUTLINE")
    if not ok then
        fontString:SetFont("Fonts\\FRIZQT__.TTF", glyph, "OUTLINE")
    end
    if fontString.SetTextHeight then
        fontString:SetTextHeight(size)
    end
end
