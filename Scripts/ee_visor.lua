local UEHelpers = require("UEHelpers")

local Refs = {}
local RefsFound = false
local VisorBooted = false
local HudVisible = false
local TranceWarnActive = false
local SurfaceWarnShowing = false
local MenuHidden = false

local VisorPhase = 0
local Phase4StartDay = nil
local PhaseReceived = false
local BootedWidgetName = nil

local RESCUE_TOTAL_DAYS = 5
local SURFACE_DAMAGE = 3.0
local POLL_MS = 3000
local FADE_INTERVAL = 40

local PhaseNames = {
    [0] = "CALM", [1] = "TREMORS", [2] = "MIGRATION",
    [3] = "COLLAPSE", [4] = "VOID BREACH",
}

local ExtinctionPct = {
    [0] = 0, [1] = 25, [2] = 50, [3] = 75, [4] = 100,
}

local CreatureClassNames = {
    "BP_Bullethead_C", "BP_Quadrate_C", "BP_FourEye_C",
    "BP_NibblerShark_C", "BP_NeedlerShark_C", "BP_NeedlerShark_Giant_C",
    "BP_Marrowbreach_C", "BP_Marrowbreach_Giant_C",
    "BP_TwinEel_C", "BP_Epicurean_C",
    "BP_DeepWingLeviathan_C", "BP_VoidLeviathanMother_C", "BP_VoidLeviathanChild_C",
}

local HudNames = {
    "VisorHeader", "VisorDay", "VisorPhase",
    "VisorIndex", "VisorThreat", "VisorRescue",
}

local AllNames = {
    "VisorHeader", "VisorDay", "VisorPhase", "VisorIndex",
    "VisorThreat", "VisorRescue", "VisorSurfaceWarn",
    "VisorTranceWarn", "VisorGlitchText",
}

local function FindRefs()
    if RefsFound then return true end
    local Widgets = FindAllOf("WBP_ExtinctionEvent_C")
    if not Widgets then return false end
    for _, Widget in ipairs(Widgets) do
        if Widget:IsValid() then
            local allOk = true
            for _, name in ipairs(AllNames) do
                local ok, ref = pcall(function() return Widget[name] end)
                if ok and ref and type(ref) == "userdata" and ref:IsValid() then
                    Refs[name] = ref
                else
                    allOk = false
                end
            end
            if allOk then
                Refs._widget = Widget
                RefsFound = true
                print("[EE-VISOR] All refs found\n")
                return true
            end
        end
    end
    return false
end

local TextIndex = {
    VisorDay = 0, VisorPhase = 1, VisorIndex = 2,
    VisorThreat = 3, VisorRescue = 4,
}

local function GetWidget()
    local w = Refs._widget
    if w then
        local valid = false
        pcall(function() valid = w:IsValid() end)
        if valid then return w end
    end
    RefsFound = false
    Refs = {}
    if not FindRefs() then return nil end
    return Refs._widget
end

local function SetText(name, text)
    local widget = GetWidget()
    if not widget then return end
    local idx = TextIndex[name]
    if idx == nil then return end
    pcall(function() widget:SetVisorLine(idx, text) end)
end

local function SetOpacity(name, op)
    local ref = Refs[name]
    if not ref then return end
    pcall(function() ref:SetRenderOpacity(op) end)
end

local function GetOpacity(name)
    local op = 1.0
    local ref = Refs[name]
    if not ref then return op end
    pcall(function() op = ref:GetRenderOpacity() end)
    return op
end

local FadeGen = {}

local function FadeElement(name, fromOp, toOp, durationMs, onComplete)
    FadeGen[name] = (FadeGen[name] or 0) + 1
    local gen = FadeGen[name]
    local steps = math.max(1, math.floor(durationMs / FADE_INTERVAL))
    local step = 0
    if fromOp then SetOpacity(name, fromOp) end

    local function Tick()
        if FadeGen[name] ~= gen then return end
        step = step + 1
        if step >= steps then
            SetOpacity(name, toOp)
            if onComplete then onComplete() end
            return
        end
        local from = fromOp or 0
        SetOpacity(name, from + (toOp - from) * (step / steps))
        ExecuteWithDelay(FADE_INTERVAL, function() ExecuteInGameThread(Tick) end)
    end
    Tick()
end

local function IsInGame()
    local inGame = false
    pcall(function()
        local PC = UEHelpers.GetPlayerController()
        if not PC or not PC:IsValid() then return end
        local Pawn = PC.Pawn
        if Pawn and Pawn:IsValid() then inGame = true end
    end)
    return inGame
end

local function IsInMenu()
    local inMenu = false
    pcall(function()
        local PC = UEHelpers.GetPlayerController()
        if not PC or not PC:IsValid() then return end
        local ok, cursor = pcall(function() return PC.bShowMouseCursor end)
        if ok and cursor then inMenu = true end
    end)
    return inMenu
end

local function IsInMainLevel()
    local inMain = false
    pcall(function()
        local actors = FindAllOf("ModActor_C")
        if not actors then return end
        for i = #actors, 1, -1 do
            if actors[i]:IsValid() then
                local name = actors[i]:GetFullName()
                if name and name:find("L_Main") then
                    inMain = true
                    return
                end
            end
        end
    end)
    return inMain
end

local function GetDayNumber()
    local day = 1
    pcall(function()
        local comps = FindAllOf("UWETimeOfDayComponent")
        if comps then
            for _, comp in ipairs(comps) do
                if comp:IsValid() then
                    day = comp:GetDayNumber()
                    break
                end
            end
        end
    end)
    return day
end

local SeaLevel = nil

local function GetSeaLevel()
    if SeaLevel then return SeaLevel end
    pcall(function()
        local statics = StaticFindObject("/Script/UWEGameplay.Default__UWEGameConfigurationStatics")
        if statics and statics:IsValid() then
            SeaLevel = statics:GetGlobalOceanSeaLevel()
        end
    end)
    return SeaLevel or 0
end

local function IsAboveWater()
    local above = false
    pcall(function()
        local PC = UEHelpers.GetPlayerController()
        if not PC or not PC:IsValid() then return end
        local Pawn = PC.Pawn
        if not Pawn or not Pawn:IsValid() then return end
        local loc = Pawn:K2_GetActorLocation()
        above = loc.Z > GetSeaLevel()
    end)
    return above
end

local function CountNearbyCreatures()
    local count = 0
    pcall(function()
        local PC = UEHelpers.GetPlayerController()
        if not PC or not PC:IsValid() then return end
        local Pawn = PC.Pawn
        if not Pawn or not Pawn:IsValid() then return end
        local ploc = Pawn:K2_GetActorLocation()

        for _, className in ipairs(CreatureClassNames) do
            local actors = FindAllOf(className)
            if actors then
                for _, actor in ipairs(actors) do
                    pcall(function()
                        if not actor:IsValid() then return end
                        local loc = actor:K2_GetActorLocation()
                        local dx = loc.X - ploc.X
                        local dy = loc.Y - ploc.Y
                        local dz = loc.Z - ploc.Z
                        if math.sqrt(dx*dx + dy*dy + dz*dz) < 15000 then
                            count = count + 1
                        end
                    end)
                end
            end
        end
    end)
    return count
end

local function ThreatText(count)
    if count == 0 then return "THREAT: MINIMAL" end
    if count <= 3 then return "THREAT: ELEVATED" end
    if count <= 6 then return "THREAT: HIGH" end
    return "THREAT: CRITICAL"
end

local function DealSurfaceDamage()
    pcall(function()
        local PC = UEHelpers.GetPlayerController()
        if not PC or not PC:IsValid() then return end
        local Pawn = PC.Pawn
        if not Pawn or not Pawn:IsValid() then return end
        local hsc = Pawn.HealthSetComponent
        if not hsc or not hsc:IsValid() then return end
        hsc:SetDamage(SURFACE_DAMAGE)
    end)
end

local function WriteHudText()
    local day = GetDayNumber()
    SetText("VisorDay", string.format("DAY %02d", day))
    SetText("VisorPhase", string.format("PHASE: %s", PhaseNames[VisorPhase] or "UNKNOWN"))
    SetText("VisorIndex", string.format("EXTINCTION INDEX %d%%", ExtinctionPct[VisorPhase] or 0))

    local nearby = CountNearbyCreatures()
    SetText("VisorThreat", ThreatText(nearby))

    if VisorPhase >= 4 and Phase4StartDay then
        local eta = math.max(0, RESCUE_TOTAL_DAYS - (day - Phase4StartDay))
        SetText("VisorRescue", string.format("RESCUE ETA: %d DAYS", eta))
    elseif VisorPhase >= 1 then
        SetText("VisorRescue", "RESCUE ETA: PENDING")
    else
        SetText("VisorRescue", "RESCUE ETA: -- DAYS")
    end
end

local function BootVisor()
    if VisorBooted then return end
    VisorBooted = true
    print("[EE-VISOR] Booting visor\n")

    ExecuteWithDelay(3000, function()
        ExecuteInGameThread(function()
            RefsFound = false
            Refs = {}
            if not FindRefs() then
                VisorBooted = false
                print("[EE-VISOR] Boot deferred - widget not ready\n")
                return
            end

            pcall(function() BootedWidgetName = Refs._widget:GetFullName() end)

            for _, name in ipairs(AllNames) do
                SetOpacity(name, 0)
            end

            WriteHudText()

            local stagger = 250
            for i, name in ipairs(HudNames) do
                ExecuteWithDelay(stagger * i, function()
                    ExecuteInGameThread(function()
                        FadeElement(name, 0, 1.0, 300)
                    end)
                end)
            end
            ExecuteWithDelay(stagger * #HudNames + 400, function()
                HudVisible = true
            end)
        end)
    end)
end

local function ShutdownVisor()
    if not VisorBooted then return end
    HudVisible = false
    VisorBooted = false
    SurfaceWarnShowing = false
    TranceWarnActive = false
    MenuHidden = false
    PhaseReceived = false
    BootedWidgetName = nil
    for _, name in ipairs(AllNames) do
        SetOpacity(name, 0)
    end
end

local function UpdateHud()
    if not FindRefs() then return end

    if not IsInGame() then
        if VisorBooted then ShutdownVisor() end
        return
    end

    if not VisorBooted then
        if PhaseReceived and IsInMainLevel() then BootVisor() end
        return
    end

    if not HudVisible then return end

    WriteHudText()

    if BootedWidgetName then
        local currentName = nil
        pcall(function() currentName = Refs._widget:GetFullName() end)
        if currentName and currentName ~= BootedWidgetName then
            print("[EE-VISOR] Widget changed, re-booting\n")
            VisorBooted = false
            HudVisible = false
            BootedWidgetName = nil
            if PhaseReceived and IsInMainLevel() then BootVisor() end
            return
        end
    end

    local inMenu = IsInMenu()
    if inMenu and not MenuHidden then
        MenuHidden = true
        for _, name in ipairs(HudNames) do
            FadeElement(name, GetOpacity(name), 0, 150)
        end
        return
    elseif not inMenu and MenuHidden then
        MenuHidden = false
        for _, name in ipairs(HudNames) do
            FadeElement(name, 0, 1.0, 200)
        end
    end
    if MenuHidden then return end

    local above = IsAboveWater()
    if above and VisorPhase >= 1 then
        if not SurfaceWarnShowing then
            SurfaceWarnShowing = true
            FadeElement("VisorSurfaceWarn", 0, 0.9, 300)
        end
        DealSurfaceDamage()
    else
        if SurfaceWarnShowing then
            SurfaceWarnShowing = false
            FadeElement("VisorSurfaceWarn", GetOpacity("VisorSurfaceWarn"), 0, 300)
        end
    end
end

local function StartPoll()
    local function Poll()
        ExecuteInGameThread(function() UpdateHud() end)
        ExecuteWithDelay(POLL_MS, function() Poll() end)
    end
    ExecuteWithDelay(3000, function() Poll() end)
end

function EE_SetVisorPhase(phase)
    PhaseReceived = true
    VisorPhase = phase
    if phase == 4 and not Phase4StartDay then
        Phase4StartDay = GetDayNumber()
    end
    ExecuteInGameThread(function()
        if FindRefs() and HudVisible then WriteHudText() end
    end)
end

function EE_VisorGlitchStart()
    if not FindRefs() then return end
    HudVisible = false
    for _, name in ipairs(HudNames) do
        FadeElement(name, GetOpacity(name), 0, 100)
    end
    FadeElement("VisorGlitchText", 0, 0.9, 150)
end

function EE_VisorReboot()
    if not FindRefs() then return end
    FadeElement("VisorGlitchText", GetOpacity("VisorGlitchText"), 0, 120)

    local stagger = 200
    for i, name in ipairs(HudNames) do
        ExecuteWithDelay(stagger * i, function()
            ExecuteInGameThread(function()
                FadeElement(name, 0, 1.0, 300)
            end)
        end)
    end
    ExecuteWithDelay(stagger * #HudNames + 400, function()
        HudVisible = true
    end)
end

function EE_VisorRestore()
    if not FindRefs() then return end
    FadeElement("VisorGlitchText", GetOpacity("VisorGlitchText"), 0, 80)
    for _, name in ipairs(HudNames) do
        FadeElement(name, 0, 1.0, 200)
    end
    ExecuteWithDelay(250, function()
        HudVisible = true
    end)
end

function EE_VisorTranceStart()
    if not FindRefs() then return end
    TranceWarnActive = true
    FadeElement("VisorTranceWarn", 0, 0.9, 500)

    local function Pulse()
        if not TranceWarnActive then return end
        FadeElement("VisorTranceWarn", 0.9, 0.4, 900, function()
            if not TranceWarnActive then return end
            FadeElement("VisorTranceWarn", 0.4, 0.9, 900, function()
                Pulse()
            end)
        end)
    end
    ExecuteWithDelay(600, function() ExecuteInGameThread(Pulse) end)
end

function EE_VisorTranceEnd()
    if not FindRefs() then return end
    TranceWarnActive = false
    FadeElement("VisorTranceWarn", GetOpacity("VisorTranceWarn"), 0, 500)
end

StartPoll()

print("[EE-VISOR] Visor HUD loaded\n")
