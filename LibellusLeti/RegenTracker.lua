Mancer.RegenTrackerModule = {}
local RegenTracker = Mancer.RegenTrackerModule

local POLL_INTERVAL = 0.05
local REGEN_TICK_SECONDS = 2
local DISPLAY_INTERVAL = 1.95
local LARGE_GAIN_MULTIPLIER = 1.5
local MIN_LARGE_GAIN = 20

function RegenTracker:New()
    local self = setmetatable({}, { __index = RegenTracker })

    self.lastMana = 0
    self.lastHealth = 0
    self.lastManaTick = 0
    self.pollTimer = 0
    self.rateTimer = 0
    self.displayTimer = 0
    self.pendingMana = 0
    self.pendingHealth = 0

    self.frame = CreateFrame("Frame")
    self.frame:RegisterEvent("UNIT_MANA")
    self.frame:RegisterEvent("UNIT_HEALTH")
    self.frame:RegisterEvent("UNIT_MAXMANA")
    self.frame:RegisterEvent("UNIT_MAXHEALTH")
    self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")

    if RegisterUnitEvent then
        pcall(function()
            RegisterUnitEvent(self.frame, "UNIT_POWER_UPDATE", "player")
        end)
    end

    self.frame:SetScript("OnEvent", function(_, event, ...)
        self:OnEvent(event, ...)
    end)

    self.frame:SetScript("OnUpdate", function(_, elapsed)
        self:OnUpdate(elapsed)
    end)

    return self
end

function RegenTracker:ApplyConfig()
    self:SyncValues()
    Mancer.FloatingText:UpdateRateText(self.lastManaTick)
end

function RegenTracker:SyncValues()
    self.lastMana = Mancer.Util.GetPlayerMana()
    self.lastHealth = Mancer.Util.GetPlayerHealth()
end

function RegenTracker:GetExpectedManaTick()
    if GetManaRegen then
        local baseRegen, castingRegen = GetManaRegen()
        local casting = UnitCastingInfo and UnitCastingInfo("player") ~= nil
        if not casting and UnitChannelInfo then
            casting = UnitChannelInfo("player") ~= nil
        end

        if casting and (castingRegen or 0) > 0 then
            return castingRegen
        end
        return baseRegen or 0
    end
    return 0
end

function RegenTracker:LooksLikeRegenTick(amount, expectedTick)
    if expectedTick <= 0 then
        return false
    end
    local tolerance = math.max(2, expectedTick * 0.2)
    return math.abs(amount - expectedTick) <= tolerance
end

function RegenTracker:ShouldShowManaGain(amount)
    local cfg = Mancer:GetConfig()
    if not cfg.showMana or amount <= 0 then
        return false
    end

    if cfg.regenOnly then
        return self:LooksLikeRegenTick(amount, self:GetExpectedManaTick())
    end

    return true
end

function RegenTracker:ShouldShowHealthGain(amount)
    local cfg = Mancer:GetConfig()
    if not cfg.showHealth or amount <= 0 then
        return false
    end

    if cfg.regenOnly and GetUnitHealthRegenRateFromSpirit then
        local spiritRegen = GetUnitHealthRegenRateFromSpirit("player") or 0
        local expectedTick = spiritRegen * REGEN_TICK_SECONDS
        return self:LooksLikeRegenTick(amount, expectedTick)
    end

    return true
end

function RegenTracker:IsLargeGain(amount, expectedTick)
    if amount >= MIN_LARGE_GAIN then
        return true
    end
    if expectedTick and expectedTick > 0 then
        return amount >= (expectedTick * LARGE_GAIN_MULTIPLIER)
    end
    return false
end

function RegenTracker:FlushPendingGains()
    if self.pendingMana > 0 then
        self:ShowManaGain(self.pendingMana)
        self.pendingMana = 0
    end

    if self.pendingHealth > 0 then
        self:ShowHealthGain(self.pendingHealth)
        self.pendingHealth = 0
    end
end

function RegenTracker:ProcessManaGain(delta)
    if delta <= 0 then
        return
    end

    local expectedTick = self:GetExpectedManaTick()
    if self:IsLargeGain(delta, expectedTick) then
        self.pendingMana = 0
        self:ShowManaGain(delta)
        return
    end

    self.pendingMana = self.pendingMana + delta
end

function RegenTracker:ProcessHealthGain(delta)
    if delta <= 0 then
        return
    end

    local expectedTick = 0
    if GetUnitHealthRegenRateFromSpirit then
        local spiritRegen = GetUnitHealthRegenRateFromSpirit("player") or 0
        expectedTick = spiritRegen * REGEN_TICK_SECONDS
    end

    if self:IsLargeGain(delta, expectedTick) then
        self.pendingHealth = 0
        self:ShowHealthGain(delta)
        return
    end

    self.pendingHealth = self.pendingHealth + delta
end

function RegenTracker:ShowManaGain(amount)
    if not self:ShouldShowManaGain(amount) then
        return
    end

    local rounded = math.floor(amount + 0.5)
    self.lastManaTick = rounded
    Mancer.FloatingText:ShowTick("+" .. rounded .. " mana", MancerDB.manaColor, "mana")
    Mancer.FloatingText:UpdateRateText(rounded)
end

function RegenTracker:ShowHealthGain(amount)
    if not self:ShouldShowHealthGain(amount) then
        return
    end

    local rounded = math.floor(amount + 0.5)
    Mancer.FloatingText:ShowTick("+" .. rounded .. " health", MancerDB.healthColor, "health")
end

function RegenTracker:CheckMana()
    if not Mancer.Util.HasManaBar() then
        return
    end

    local current = Mancer.Util.GetPlayerMana()
    local delta = current - self.lastMana

    if delta > 0 then
        self:ProcessManaGain(delta)
    end

    self.lastMana = current
end

function RegenTracker:CheckHealth()
    local current = Mancer.Util.GetPlayerHealth()
    local delta = current - self.lastHealth

    if delta > 0 then
        self:ProcessHealthGain(delta)
    end

    self.lastHealth = current
end

function RegenTracker:OnEvent(event, arg1, powerType)
    if event == "UNIT_MANA" or event == "UNIT_MAXMANA" then
        if arg1 == "player" then
            self:CheckMana()
        end
        return
    end

    if event == "UNIT_POWER_UPDATE" then
        if arg1 == "player" and (powerType == nil or powerType == 0) then
            self:CheckMana()
        end
        return
    end

    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        if arg1 == "player" then
            self:CheckHealth()
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
        Mancer.FloatingText:UpdateRateText(self.lastManaTick)
    end
end

function RegenTracker:OnUpdate(elapsed)
    self.pollTimer = self.pollTimer + elapsed
    if self.pollTimer >= POLL_INTERVAL then
        self.pollTimer = 0
        self:CheckMana()
        self:CheckHealth()
    end

    self.displayTimer = self.displayTimer + elapsed
    if self.displayTimer >= DISPLAY_INTERVAL then
        self.displayTimer = 0
        self:FlushPendingGains()
    end

    self.rateTimer = self.rateTimer + elapsed
    if self.rateTimer >= 1 then
        self.rateTimer = 0
        Mancer.FloatingText:UpdateRateText(self.lastManaTick)
    end
end
