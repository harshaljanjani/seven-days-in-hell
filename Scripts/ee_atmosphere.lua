local UEHelpers = require("UEHelpers")

-- Phase targets
local AtmosphereTargets = {
    [0] = { tintOpacity = 0.0 },
    [1] = { tintOpacity = 0.07 },
    [2] = { tintOpacity = 0.15 },
    [3] = { tintOpacity = 0.30 },
    [4] = { tintOpacity = 0.44 },
}

-- Weather names from DataIndex.json: Clear, CloudyA, CloudyB, SparseClouds, Misty, DistantStormy
local WeatherStages = {
    [0] = { {"Clear", 0} },
    [1] = { {"CloudyA", 0}, {"CloudyB", 30} },
    [2] = { {"CloudyB", 0}, {"Misty", 20}, {"DistantStormy", 45} },
    [3] = { {"Misty", 0}, {"DistantStormy", 15} },
    [4] = { {"DistantStormy", 0} },
}

local GlitchIntensity = {
    [0] = 0.0, [1] = 0.25, [2] = 0.45, [3] = 0.75, [4] = 1.0,
}

local TranceConfig = {
    [3] = { chance = 0.10, checkInterval = {60, 90}, duration = {10, 20} },
    [4] = { chance = 0.25, checkInterval = {30, 60}, duration = {15, 30} },
}

-- State
local CurrentAtmoPhase    = 0
local TintImage           = nil
local TintFound           = nil
local LerpProgress        = 0.0
local LerpDuration        = 30.0
local PreviousTargets     = nil
local CurrentTargets      = nil
local CurrentTintOpacity  = 0.0
local FirstPhaseSet       = true
local MENU_TINT_REDUCTION = 0.08
local PausePollActive     = false
local TranceActive        = false
local PreTranceHealth     = nil
local WeatherPhaseTag     = 0
local LerpTag             = 0

-- Component finders
local function FindTintOverlay()
    local valid = false
    if TintImage then pcall(function() valid = TintImage:IsValid() end) end
    if valid then return TintImage end
    TintImage = nil
    local Widgets = FindAllOf("WBP_ExtinctionEvent_C")
    if not Widgets then return nil end
    for _, Widget in ipairs(Widgets) do
        local ok, img = pcall(function()
            if not Widget:IsValid() then return nil end
            local ti = Widget.TintOverlay
            if ti and type(ti) == "userdata" and ti:IsValid() then return ti end
            return nil
        end)
        if ok and img then
            TintImage = img
            if not TintFound then
                TintFound = true
                print("[EE-ATM] TintOverlay found\n")
            end
            return img
        end
    end
    return nil
end

-- Game system wrappers (only float/int/string/UObject* params, structs crash UE4SS)
local function ApplyTint(opacity)
    local img = FindTintOverlay()
    if not img then return end
    CurrentTintOpacity = opacity
    pcall(function() img:SetRenderOpacity(opacity) end)
    pcall(function() img:SetVisibility(3) end)
end

local function CheatCommand(fn)
    ExecuteInGameThread(function()
        pcall(function()
            local PC = UEHelpers.GetPlayerController()
            if not PC or not PC:IsValid() then return end
            local CM = PC.CheatManager
            if not CM or not CM:IsValid() then return end
            fn(CM, PC)
        end)
    end)
end

local function SetWeather(name)
    if not name then return end
    CheatCommand(function(CM)
        CM:SetCurrentWeather(name)
        CM:SetNextWeather(name)
        print(string.format("[EE-ATM] Weather → %s\n", name))
    end)
end

local function SetGlitchPhaseIntensity(phase)
    local intensity = GlitchIntensity[phase] or 1.0
    if EE_SetGlitchOpacity then EE_SetGlitchOpacity(intensity) end
end

-- Staggered weather
local function ApplyStaggeredWeather(phase)
    local stages = WeatherStages[phase]
    if not stages then return end
    WeatherPhaseTag = phase
    for _, stage in ipairs(stages) do
        local name, delaySec = stage[1], stage[2]
        if delaySec == 0 then
            SetWeather(name)
        else
            ExecuteWithDelay(delaySec * 1000, function()
                if WeatherPhaseTag == phase then SetWeather(name) end
            end)
        end
    end
end

-- Trance (Phase 3-4): slow tint pulse + darkening, damage breaks it
local function GetPlayerHealth()
    local hp = nil
    pcall(function()
        local PC = UEHelpers.GetPlayerController()
        if not PC or not PC:IsValid() then return end
        local Pawn = PC.Pawn
        if not Pawn or not Pawn:IsValid() then return end
        local hsc = Pawn.HealthSetComponent
        if hsc and hsc:IsValid() then hp = hsc:GetHealth() end
    end)
    return hp
end

local function EndTrance()
    if not TranceActive then return end
    TranceActive = false
    PreTranceHealth = nil
    if EE_VisorTranceEnd then EE_VisorTranceEnd() end
    CheatCommand(function(CM) CM:Slomo(1.0) end)
    local fadeSteps = 10
    local fadeInterval = 80
    local img = FindTintOverlay()
    if not img then ApplyTint(CurrentTintOpacity); return end
    local currentOp = 0
    pcall(function() currentOp = img:GetRenderOpacity() end)
    local step = 0
    local function FadeBack()
        step = step + 1
        if step > fadeSteps then
            ApplyTint(CurrentTintOpacity)
            return
        end
        local freshImg = FindTintOverlay()
        if not freshImg then ApplyTint(CurrentTintOpacity); return end
        local t = step / fadeSteps
        local op = currentOp + (CurrentTintOpacity - currentOp) * t
        pcall(function() freshImg:SetRenderOpacity(op) end)
        ExecuteWithDelay(fadeInterval, function() ExecuteInGameThread(FadeBack) end)
    end
    FadeBack()
    print("[EE-ATM] Trance ended\n")
end

local function StartTrance(duration)
    if TranceActive then return end
    TranceActive = true
    PreTranceHealth = GetPlayerHealth()
    if EE_VisorTranceStart then EE_VisorTranceStart() end
    print(string.format("[EE-ATM] Trance started (%ds)\n", duration))
    CheatCommand(function(CM) CM:Slomo(0.4) end)

    local interval = 60
    local totalTicks = math.floor(duration * 1000 / interval)
    local tick = 0
    local baseTint = CurrentTintOpacity

    local function PulseTick()
        tick = tick + 1
        if not TranceActive or tick > totalTicks then
            EndTrance()
            return
        end

        if EE_IsMenuActive and EE_IsMenuActive() then
            ExecuteWithDelay(interval, function() ExecuteInGameThread(PulseTick) end)
            return
        end

        local rampIn = math.min(tick / 15, 1.0)
        local pulse = math.sin(tick * 0.06) * 0.5 + 0.5
        local opacity = baseTint + (pulse * rampIn) * (0.65 - baseTint)
        local img = FindTintOverlay()
        if img then
            pcall(function() img:SetRenderOpacity(opacity) end)
        end

        ExecuteWithDelay(interval, function()
            ExecuteInGameThread(PulseTick)
        end)
    end

    local function HealthPoll()
        if not TranceActive then return end
        if EE_IsMenuActive and EE_IsMenuActive() then
            ExecuteWithDelay(250, function() ExecuteInGameThread(HealthPoll) end)
            return
        end
        local hp = GetPlayerHealth()
        if hp and PreTranceHealth and hp < PreTranceHealth then
            ExecuteInGameThread(function() EndTrance() end)
            return
        end
        ExecuteWithDelay(250, function() ExecuteInGameThread(HealthPoll) end)
    end

    ExecuteWithDelay(interval, function() ExecuteInGameThread(PulseTick) end)
    ExecuteWithDelay(500, function() ExecuteInGameThread(HealthPoll) end)

    ExecuteWithDelay((duration + 2) * 1000, function()
        ExecuteInGameThread(function()
            if TranceActive then
                print("[EE-ATM] Trance safety timeout\n")
                EndTrance()
            end
        end)
    end)
end

local function ScheduleTranceChecks(phaseNum)
    local cfg = TranceConfig[phaseNum]
    if not cfg then return end
    local function CheckTrance()
        if CurrentAtmoPhase ~= phaseNum then return end
        if EE_IsMenuActive and EE_IsMenuActive() then
            ExecuteWithDelay(math.random(cfg.checkInterval[1], cfg.checkInterval[2]) * 1000, function()
                ExecuteInGameThread(CheckTrance)
            end)
            return
        end
        if not TranceActive and math.random() < cfg.chance then
            StartTrance(math.random(cfg.duration[1], cfg.duration[2]))
        end
        ExecuteWithDelay(math.random(cfg.checkInterval[1], cfg.checkInterval[2]) * 1000, function()
            ExecuteInGameThread(CheckTrance)
        end)
    end
    ExecuteWithDelay(math.random(cfg.checkInterval[1], cfg.checkInterval[2]) * 1000, function()
        ExecuteInGameThread(CheckTrance)
    end)
end

-- Menu tint: reduce by 8% so menu stays tinted but slightly lighter
local function StartPausePoll()
    if PausePollActive then return end
    PausePollActive = true
    local function PollPause()
        if CurrentAtmoPhase == 0 then PausePollActive = false; return end
        if TranceActive then
            ExecuteWithDelay(1000, function() ExecuteInGameThread(PollPause) end)
            return
        end
        pcall(function()
            local img = FindTintOverlay()
            if not img then return end
            local inMenu = false
            local PC = UEHelpers.GetPlayerController()
            if PC and PC:IsValid() then
                local ok, cursor = pcall(function() return PC.bShowMouseCursor end)
                if ok and cursor then inMenu = true end
            end
            local menuOpacity = CurrentTintOpacity
            if CurrentAtmoPhase >= 3 then
                menuOpacity = math.max(CurrentTintOpacity - MENU_TINT_REDUCTION, 0.0)
            end
            img:SetRenderOpacity(inMenu and menuOpacity or CurrentTintOpacity)
        end)
        ExecuteWithDelay(1000, function() ExecuteInGameThread(PollPause) end)
    end
    ExecuteWithDelay(1000, function() ExecuteInGameThread(PollPause) end)
end

-- Lerp
local function Lerp(a, b, t)
    return a + (b - a) * math.min(math.max(t, 0), 1)
end

local function AtmosphereTick(tag)
    if tag ~= LerpTag then return end
    if not PreviousTargets or not CurrentTargets then return end
    if TranceActive then
        ExecuteWithDelay(500, function() ExecuteInGameThread(function() AtmosphereTick(tag) end) end)
        return
    end
    LerpProgress = LerpProgress + (0.5 / LerpDuration)
    if LerpProgress > 1.0 then LerpProgress = 1.0 end
    ApplyTint(Lerp(PreviousTargets.tintOpacity, CurrentTargets.tintOpacity, LerpProgress))
    if LerpProgress < 1.0 then
        ExecuteWithDelay(500, function() ExecuteInGameThread(function() AtmosphereTick(tag) end) end)
    else
        print(string.format("[EE-ATM] Phase %d complete - tint:%.0f%%\n",
            CurrentAtmoPhase, CurrentTargets.tintOpacity * 100))
    end
end

-- Set phase (global, called by ee_spawn.lua)
-- Game load: tint + glitch only. Weather/stingers/trance crash if called before game is ready.
function EE_SetAtmospherePhase(phase)
    if phase == CurrentAtmoPhase and LerpProgress >= 1.0 then return end
    print(string.format("[EE-ATM] === Phase %d ===\n", phase))
    if TranceActive then EndTrance() end

    if phase == 0 then TintImage = nil end

    PreviousTargets = { tintOpacity = CurrentTintOpacity }
    CurrentTargets  = AtmosphereTargets[phase] or AtmosphereTargets[0]
    CurrentAtmoPhase = phase
    LerpProgress = 0.0

    SetGlitchPhaseIntensity(phase)

    if FirstPhaseSet or phase == 0 then
        if FirstPhaseSet then FirstPhaseSet = false end
        LerpProgress = 1.0
        CurrentTintOpacity = CurrentTargets.tintOpacity
        ApplyTint(CurrentTintOpacity)
        StartPausePoll()
        print(string.format("[EE-ATM] Phase %d - instant\n", phase))
    else
        LerpTag = LerpTag + 1
        local tag = LerpTag
        ApplyStaggeredWeather(phase)
        ScheduleTranceChecks(phase)
        StartPausePoll()
        ExecuteWithDelay(500, function() ExecuteInGameThread(function() AtmosphereTick(tag) end) end)
    end
end

function EE_TestTrance(duration)
    StartTrance(duration or 10)
end

RegisterConsoleCommandHandler("ee_atmo", function(FullCommand, Parameters)
    if #Parameters < 1 then return true end
    EE_SetAtmospherePhase(tonumber(Parameters[1]) or 0)
    return true
end)

print("[EE-ATM] Atmosphere Manager loaded\n")
