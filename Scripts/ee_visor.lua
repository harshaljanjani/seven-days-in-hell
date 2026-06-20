local UEHelpers = require("UEHelpers")

local Refs = {}
local RefsFound = false
local VisorBooted = false
local HudVisible = false
local TranceWarnActive = false
local SurfaceWarnShowing = false
local MenuHidden = false

local VisorPhase = 0
local PhaseReceived = false
local BootedWidgetName = nil
local SurfaceElapsed = 0
local LastKnownDay = nil
local DayPulseActive = false
local MissionComplete = false
local MissionCompleteTag = 0

local TOTAL_DAYS = 7
local SURFACE_TICK = 1000
local POLL_MS = 3000
local FADE_INTERVAL = 40

local SurfaceGrace = {
    [0] = 60, [1] = 40, [2] = 25, [3] = 12, [4] = 5,
}

local SurfaceDmg = {
    [0] = 0, [1] = 2.0, [2] = 4.0, [3] = 7.0, [4] = 12.0,
}

local BaseGrace = {
    [0] = 999, [1] = 999, [2] = 90, [3] = 45, [4] = 20,
}

local BaseDmg = {
    [0] = 0, [1] = 0, [2] = 1.5, [3] = 3.0, [4] = 6.0,
}

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
    "VisorTranceWarn", "VisorGlitchText", "VisorMessage",
}

local function FindRefs()
    if RefsFound then return true end
    local Widgets = FindAllOf("WBP_ExtinctionEvent_C")
    if not Widgets then return false end
    for _, Widget in ipairs(Widgets) do
        local wValid = false
        pcall(function() wValid = Widget:IsValid() end)
        if wValid then
            local allOk = true
            for _, name in ipairs(AllNames) do
                local ok, ref = pcall(function()
                    local r = Widget[name]
                    if r and type(r) == "userdata" and r:IsValid() then return r end
                    return nil
                end)
                if ok and ref then
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
    VisorThreat = 3, VisorRescue = 4, VisorSurfaceWarn = 5,
    VisorMessage = 6, VisorGlitchText = 7,
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
    if not RefsFound then return end
    local ref = Refs[name]
    if not ref then return end
    pcall(function()
        if ref:IsValid() then ref:SetRenderOpacity(op) end
    end)
end

local function GetOpacity(name)
    if not RefsFound then return 1.0 end
    local ref = Refs[name]
    if not ref then return 1.0 end
    local op = 1.0
    pcall(function()
        if ref:IsValid() then op = ref:GetRenderOpacity() end
    end)
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
            local ok, name = pcall(function() return actors[i]:GetFullName() end)
            if ok and name and name:find("L_Main") then
                inMain = true
                return
            end
        end
    end)
    return inMain
end

local function GetDayNumber()
    local day = 1
    pcall(function()
        local comps = FindAllOf("UWETimeOfDayComponent")
        if not comps then return end
        for _, comp in ipairs(comps) do
            local isValid = false
            pcall(function() isValid = comp:IsValid() end)
            if isValid then
                local ok, d = pcall(function() return comp:GetDayNumber() end)
                if ok and d then day = d; break end
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
        if not statics then return end
        
        local isValid = false
        pcall(function() isValid = statics:IsValid() end)
        if isValid then
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

local BaseElapsed = 0
local BaseWarnShowing = false

local function IsInBase()
    local inBase = false
    pcall(function()
        local PC = UEHelpers.GetPlayerController()
        if not PC or not PC:IsValid() then return end
        local Pawn = PC.Pawn
        if not Pawn or not Pawn:IsValid() then return end
        local loc = Pawn:K2_GetActorLocation()
        if loc.Z >= GetSeaLevel() then return end
        local cmc = Pawn.CharacterMovement
        if not cmc or type(cmc) ~= "userdata" then return end
        local valid = false
        pcall(function() valid = cmc:IsValid() end)
        if not valid then return end
        local mode = 4
        pcall(function() mode = cmc.MovementMode end)
        inBase = (mode ~= 4)
    end)
    return inBase
end

local function DealBaseDamage()
    local dmg = BaseDmg[VisorPhase] or 0
    if dmg <= 0 then return end
    pcall(function()
        local PC = UEHelpers.GetPlayerController()
        if not PC or not PC:IsValid() then return end
        local Pawn = PC.Pawn
        if not Pawn or not Pawn:IsValid() then return end
        local hsc = Pawn.HealthSetComponent
        if not hsc or not hsc:IsValid() then return end
        local hp = hsc:GetHealth()
        if hp and hp > 0 then
            hsc:SetHealth(math.max(0, hp - dmg))
        end
    end)
end

-- Visor message queue (bottom screen text)
local MessageQueue = {}
local MessageActive = false
local MESSAGE_HOLD = 5000
local MESSAGE_GAP = 1500

local PhaseLore = {
    [0] = {
        "Biosensor calibrated. Toxin monitoring enabled.",
        "Mission: Document ecological anomaly on 4546B.",
        "Rescue vessel dispatched. ETA: 7 days.",
    },
    [1] = {
        "Seismic instability detected in deep thermal vent system.",
        "Toxin bloom spreading through lower thermal layers.",
        "Small fauna displacement detected in shallow zones.",
    },
    [2] = {
        "Warning: Toxin concentration exceeding safe threshold.",
        "Large predators ascending from deep territories.",
        "Atmospheric contamination rising. Surface grace period reduced.",
    },
    [3] = {
        "Critical: Ecosystem tipping point reached. Total collapse in progress.",
        "Neurotoxin variant detected. Cognitive anomalies possible.",
        "Cicada command signal degrading.",
    },
    [4] = {
        "Emergency: Void boundary integrity failure confirmed.",
        "Leviathan-class organisms breaching into inhabited waters.",
        "Cicada command signal lost. Rescue ETA: 2 days. Survive.",
    },
}

local DayLore = {
    [6] = { "Faint signal detected. Rescue vessel on approach. ETA: 1 day." },
    [7] = { "Rescue vessel in final approach. Prepare for extraction." },
}

local DatabankTitles = {
    [0] = "Mission Briefing",
    [1] = "Seismic Analysis",
    [2] = "Predator Migration Report",
    [3] = "Ecosystem Collapse Model",
    [4] = "Void Breach Analysis",
}

local function QueueMessages(messages)
    for _, msg in ipairs(messages) do
        table.insert(MessageQueue, msg)
    end
end

local function ProcessMessageQueue()
    if MessageActive or #MessageQueue == 0 then return end
    if not HudVisible or MenuHidden then
        ExecuteWithDelay(1000, function() ExecuteInGameThread(ProcessMessageQueue) end)
        return
    end
    MessageActive = true
    local msg = table.remove(MessageQueue, 1)
    SetText("VisorMessage", msg)
    FadeElement("VisorMessage", 0, 0.9, 600, function()
        ExecuteWithDelay(MESSAGE_HOLD, function()
            ExecuteInGameThread(function()
                FadeElement("VisorMessage", 0.9, 0, 600, function()
                    MessageActive = false
                    ExecuteWithDelay(MESSAGE_GAP, function()
                        ExecuteInGameThread(ProcessMessageQueue)
                    end)
                end)
            end)
        end)
    end)
end

local function SendDatabankNotification(title)
    pcall(function()
        local actors = FindAllOf("ModActor_C")
        if not actors then return end
        for i = #actors, 1, -1 do
            local ok, name = pcall(function() return actors[i]:GetFullName() end)
            if ok and name and name:find("L_Main") then
                pcall(function() actors[i]:ShowEENotification(title, 4) end)
                return
            end
        end
    end)
end

local LastLorePhase = -1
local LastLoreDay = -1

local function TriggerPhaseLore(phase)
    if phase == LastLorePhase then return end
    LastLorePhase = phase
    if EE_UnlockLoreEntry then
        for i = 0, phase do EE_UnlockLoreEntry(i) end
    end
    local day = GetDayNumber()
    if day >= 6 and EE_UnlockLoreEntry then EE_UnlockLoreEntry(5) end
    local messages = PhaseLore[phase]
    if messages then
        QueueMessages(messages)
        ProcessMessageQueue()
    end
    local title = DatabankTitles[phase]
    if title then
        SendDatabankNotification(title .. " (P to view)")
    end
    ExecuteWithDelay(3000, function()
        ExecuteInGameThread(function()
            QueueMessages({"PERISH-COPE: New data recovered. Press P to view."})
            ProcessMessageQueue()
        end)
    end)
end

local function TriggerDayLore(day)
    if day == LastLoreDay then return end
    LastLoreDay = day
    local messages = DayLore[day]
    if not messages then return end
    QueueMessages(messages)
    ProcessMessageQueue()
    if day == 6 and EE_UnlockLoreEntry then
        EE_UnlockLoreEntry(5)
        SendDatabankNotification("Rescue Signal (P to view)")
        ExecuteWithDelay(3000, function()
            ExecuteInGameThread(function()
                QueueMessages({"PERISH-COPE: New data recovered. Press P to view."})
                ProcessMessageQueue()
            end)
        end)
    end
end

local function CountNearbyCreatures()
    local count = 0
    pcall(function()
        local PC = UEHelpers.GetPlayerController()
        if not PC or not PC:IsValid() then return end
        local Pawn = PC.Pawn
        if not Pawn or not Pawn:IsValid() then return end
        local ploc = Pawn:K2_GetActorLocation()

        local classes = EE_GetPhaseCreatureClasses and EE_GetPhaseCreatureClasses() or CreatureClassNames
        for _, className in ipairs(classes) do
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

local ThreatPollCounter = 0
local CachedNearbyCount = 0
local THREAT_SCAN_INTERVAL = 3

local function ThreatText(count)
    if count == 0 then return "THREAT: MINIMAL" end
    if count <= 3 then return "THREAT: ELEVATED" end
    if count <= 6 then return "THREAT: HIGH" end
    return "THREAT: CRITICAL"
end

local function DealSurfaceDamage()
    local dmg = SurfaceDmg[VisorPhase] or 0
    if dmg <= 0 then return end
    pcall(function()
        local PC = UEHelpers.GetPlayerController()
        if not PC or not PC:IsValid() then return end
        local Pawn = PC.Pawn
        if not Pawn or not Pawn:IsValid() then return end
        local hsc = Pawn.HealthSetComponent
        if not hsc or not hsc:IsValid() then return end
        local hp = hsc:GetHealth()
        if hp and hp > 0 then
            hsc:SetHealth(math.max(0, hp - dmg))
        end
    end)
end

local function PulseDayChange()
    if DayPulseActive then return end
    DayPulseActive = true
    local pulses = 0
    local maxPulses = 2
    local function DoPulse()
        pulses = pulses + 1
        if pulses > maxPulses or not HudVisible or MenuHidden then
            DayPulseActive = false
            if VisorBooted and HudVisible then
                SetOpacity("VisorDay", 1.0)
            end
            return
        end
        FadeElement("VisorDay", 1.0, 0.15, 700, function()
            FadeElement("VisorDay", 0.15, 1.0, 700, function()
                DoPulse()
            end)
        end)
    end
    DoPulse()
end

local function TriggerMissionComplete()
    if MissionComplete then return end
    MissionComplete = true
    MissionCompleteTag = MissionCompleteTag + 1
    local tag = MissionCompleteTag
    print("[EE-VISOR] MISSION COMPLETE triggered\n")

    HudVisible = true
    TranceWarnActive = false
    SurfaceWarnShowing = false
    BaseWarnShowing = false
    SurfaceElapsed = 0
    BaseElapsed = 0
    FadeElement("VisorTranceWarn", GetOpacity("VisorTranceWarn"), 0, 200)
    FadeElement("VisorSurfaceWarn", GetOpacity("VisorSurfaceWarn"), 0, 200)
    FadeElement("VisorGlitchText", GetOpacity("VisorGlitchText"), 0, 200)

    if EE_StopAllSpawns then EE_StopAllSpawns() end

    QueueMessages({
        "ALTERRA RESCUE VESSEL ARC-7 HAS ARRIVED.",
        "YOU SURVIVED.",
    })
    ProcessMessageQueue()

    ExecuteWithDelay(3000, function()
        ExecuteInGameThread(function()
            if MissionCompleteTag ~= tag or not MissionComplete then return end

            for _, name in ipairs(HudNames) do
                FadeElement(name, GetOpacity(name), 0, 1500)
            end

            if EE_Slomo then EE_Slomo(0.4) end
            if EE_StartMissionFade then EE_StartMissionFade(10) end

            local flickerTick = 0
            local flickerTotal = 40
            local function Flicker()
                if MissionCompleteTag ~= tag or not MissionComplete then return end
                if MenuHidden then
                    ExecuteWithDelay(200, function() ExecuteInGameThread(Flicker) end)
                    return
                end
                flickerTick = flickerTick + 1
                if flickerTick > flickerTotal then
                    FadeElement("VisorGlitchText", GetOpacity("VisorGlitchText"), 0, 400)
                    return
                end
                local flicker = (math.random() < 0.5) and (math.random() * 0.7 + 0.1) or 0
                SetOpacity("VisorGlitchText", flicker)
                ExecuteWithDelay(200, function() ExecuteInGameThread(Flicker) end)
            end
            Flicker()

            ExecuteWithDelay(12000, function()
                ExecuteInGameThread(function()
                    if MissionCompleteTag ~= tag or not MissionComplete then return end
                    if EE_Slomo then EE_Slomo(0.15) end

                    SetText("VisorGlitchText", "MISSION COMPLETE")
                    FadeElement("VisorGlitchText", 0, 1.0, 1500, function()
                        local function Pulse()
                            if MissionCompleteTag ~= tag or not MissionComplete then return end
                            if MenuHidden then
                                ExecuteWithDelay(300, function() ExecuteInGameThread(Pulse) end)
                                return
                            end
                            FadeElement("VisorGlitchText", 1.0, 0.3, 600, function()
                                if MissionCompleteTag ~= tag or not MissionComplete then return end
                                FadeElement("VisorGlitchText", 0.3, 1.0, 600, function()
                                    Pulse()
                                end)
                            end)
                        end
                        ExecuteWithDelay(300, function() ExecuteInGameThread(Pulse) end)
                    end)
                end)
            end)
        end)
    end)
end

local function WriteHudText()
    local day = GetDayNumber()

    if day > TOTAL_DAYS and not MissionComplete then
        TriggerMissionComplete()
    end

    if MissionComplete then
        LastKnownDay = day
        return
    end

    SetText("VisorDay", string.format("DAY %02d", day))
    SetText("VisorPhase", string.format("PHASE: %s", PhaseNames[VisorPhase] or "UNKNOWN"))
    SetText("VisorIndex", string.format("COLLAPSE INDEX %d%%", ExtinctionPct[VisorPhase] or 0))

    ThreatPollCounter = ThreatPollCounter + 1
    if ThreatPollCounter >= THREAT_SCAN_INTERVAL then
        ThreatPollCounter = 0
        CachedNearbyCount = CountNearbyCreatures()
    end
    SetText("VisorThreat", ThreatText(CachedNearbyCount))

    local eta = math.max(0, TOTAL_DAYS - day)
    if eta > 0 then
        SetText("VisorRescue", string.format("RESCUE ETA: %d DAY%s", eta, eta == 1 and "" or "S"))
    else
        SetText("VisorRescue", "RESCUE: IMMINENT")
    end

    if LastKnownDay and day ~= LastKnownDay and HudVisible then
        print(string.format("[EE-VISOR] Day changed: %d → %d\n", LastKnownDay, day))
        PulseDayChange()
        TriggerDayLore(day)
    end
    LastKnownDay = day
end

local function ZeroAllWidgets()
    pcall(function()
        local widgets = FindAllOf("WBP_ExtinctionEvent_C")
        if not widgets then return end
        for _, w in ipairs(widgets) do
            pcall(function()
                if not w:IsValid() then return end
                for _, name in ipairs(AllNames) do
                    local r = w[name]
                    if r and type(r) == "userdata" and r:IsValid() then
                        r:SetRenderOpacity(0)
                    end
                end
            end)
        end
    end)
end

local function BootVisor()
    if VisorBooted then return end
    VisorBooted = true
    print("[EE-VISOR] Booting visor\n")

    ExecuteWithDelay(3000, function()
        ExecuteInGameThread(function()
            ZeroAllWidgets()

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

            local day = GetDayNumber()
            if day > TOTAL_DAYS then
                MissionComplete = true
                MissionCompleteTag = MissionCompleteTag + 1
                local tag = MissionCompleteTag
                HudVisible = true
                if EE_StopAllSpawns then EE_StopAllSpawns() end
                if EE_Slomo then EE_Slomo(0.15) end
                if EE_StartMissionFade then EE_StartMissionFade(3) end
                SetText("VisorGlitchText", "MISSION COMPLETE")
                SetOpacity("VisorGlitchText", 1.0)
                local function Pulse()
                    if MissionCompleteTag ~= tag or not MissionComplete then return end
                    if MenuHidden then
                        ExecuteWithDelay(300, function() ExecuteInGameThread(Pulse) end)
                        return
                    end
                    FadeElement("VisorGlitchText", 1.0, 0.3, 600, function()
                        if MissionCompleteTag ~= tag or not MissionComplete then return end
                        FadeElement("VisorGlitchText", 0.3, 1.0, 600, function()
                            Pulse()
                        end)
                    end)
                end
                ExecuteWithDelay(300, function() ExecuteInGameThread(Pulse) end)
                print("[EE-VISOR] MISSION COMPLETE resumed\n")
                return
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
                if VisorBooted then
                    HudVisible = true
                    if day > 1 then
                        QueueMessages({"Field protocol designed for day 1 deployment.", "New game recommended for full experience."})
                    end
                    TriggerPhaseLore(VisorPhase)
                end
            end)
        end)
    end)
end

local function ShutdownVisor()
    if not VisorBooted then return end
    if MissionComplete then
        if EE_Slomo then EE_Slomo(1.0) end
    end
    MissionComplete = false
    MissionCompleteTag = MissionCompleteTag + 1
    for _, name in ipairs(AllNames) do
        FadeGen[name] = (FadeGen[name] or 0) + 1
    end
    ZeroAllWidgets()
    HudVisible = false
    VisorBooted = false
    SurfaceWarnShowing = false
    SurfaceElapsed = 0
    BaseWarnShowing = false
    BaseElapsed = 0
    TranceWarnActive = false
    MenuHidden = false
    PhaseReceived = false
    BootedWidgetName = nil
    LastKnownDay = nil
    DayPulseActive = false
    LastLorePhase = -1
    LastLoreDay = -1
    MessageQueue = {}
    MessageActive = false
    RefsFound = false
    Refs = {}
    if EE_ShutdownAtmosphere then EE_ShutdownAtmosphere() end
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
        SurfaceWarnShowing = false
        BaseWarnShowing = false
        for _, name in ipairs(AllNames) do
            FadeGen[name] = (FadeGen[name] or 0) + 1
            SetOpacity(name, 0)
        end
        return
    elseif not inMenu and MenuHidden then
        MenuHidden = false
        if VisorBooted then HudVisible = true end
        if MissionComplete then
            FadeElement("VisorGlitchText", 0, 1.0, 200)
        else
            for _, name in ipairs(HudNames) do
                FadeElement(name, 0, 1.0, 200)
            end
            if TranceWarnActive then
                FadeElement("VisorTranceWarn", 0, 0.9, 300)
            end
        end
    end
    if MenuHidden then return end
end

local function IsPlayerDead()
    local dead = false
    pcall(function()
        local PC = UEHelpers.GetPlayerController()
        if not PC or not PC:IsValid() then return end
        local Pawn = PC.Pawn
        if not Pawn or not Pawn:IsValid() then dead = true; return end
        local hsc = Pawn.HealthSetComponent
        if hsc and hsc:IsValid() then
            local hp = hsc:GetHealth()
            if hp and hp <= 0 then dead = true end
        end
    end)
    return dead
end

local function SurfaceTick()
    ExecuteInGameThread(function()
        if MissionComplete or not VisorBooted or not HudVisible or MenuHidden or IsPlayerDead() then
            if SurfaceWarnShowing or BaseWarnShowing then
                SurfaceWarnShowing = false
                SurfaceElapsed = 0
                BaseWarnShowing = false
                BaseElapsed = 0
                FadeElement("VisorSurfaceWarn", GetOpacity("VisorSurfaceWarn"), 0, 200)
            end
            ExecuteWithDelay(SURFACE_TICK, SurfaceTick)
            return
        end

        local above = IsAboveWater() and VisorPhase >= 1
        local inBase = not above and IsInBase() and VisorPhase >= 2

        if above then
            BaseElapsed = 0
            BaseWarnShowing = false
            SurfaceElapsed = SurfaceElapsed + 1
            local grace = SurfaceGrace[VisorPhase] or 60
            local remaining = grace - SurfaceElapsed
            if remaining > 0 then
                SetText("VisorSurfaceWarn", string.format("SURFACE EXPOSURE: %ds", remaining))
            else
                SetText("VisorSurfaceWarn", "TOXIC - SEEK WATER")
                DealSurfaceDamage()
            end
            if not SurfaceWarnShowing then
                SurfaceWarnShowing = true
                FadeElement("VisorSurfaceWarn", 0, 0.9, 200)
            end
        elseif inBase then
            SurfaceElapsed = 0
            SurfaceWarnShowing = false
            BaseElapsed = BaseElapsed + 1
            local grace = BaseGrace[VisorPhase] or 999
            local remaining = grace - BaseElapsed
            if remaining > 0 then
                SetText("VisorSurfaceWarn", string.format("HABITAT CONTAMINATION: %ds", remaining))
            else
                SetText("VisorSurfaceWarn", "HABITAT COMPROMISED - SEEK OPEN WATER")
                DealBaseDamage()
            end
            if not BaseWarnShowing then
                BaseWarnShowing = true
                FadeElement("VisorSurfaceWarn", 0, 0.9, 200)
            end
        else
            local wasWarning = SurfaceWarnShowing or SurfaceElapsed > 0 or BaseWarnShowing or BaseElapsed > 0
            SurfaceWarnShowing = false
            SurfaceElapsed = 0
            BaseWarnShowing = false
            BaseElapsed = 0
            if wasWarning then
                FadeElement("VisorSurfaceWarn", GetOpacity("VisorSurfaceWarn"), 0, 200)
            end
        end

        ExecuteWithDelay(SURFACE_TICK, SurfaceTick)
    end)
end

local function StartPoll()
    local function Poll()
        ExecuteInGameThread(function() UpdateHud() end)
        ExecuteWithDelay(POLL_MS, function() Poll() end)
    end
    ExecuteWithDelay(3000, function() Poll() end)
    ExecuteWithDelay(5000, SurfaceTick)
end

function EE_SetVisorPhase(phase)
    if phase == 0 and MissionComplete then
        MissionComplete = false
        MissionCompleteTag = MissionCompleteTag + 1
        if EE_Slomo then EE_Slomo(1.0) end
        FadeElement("VisorGlitchText", GetOpacity("VisorGlitchText"), 0, 300)
        ExecuteWithDelay(400, function()
            ExecuteInGameThread(function()
                if MissionComplete then return end
                for _, name in ipairs(HudNames) do
                    FadeElement(name, 0, 1.0, 300)
                end
            end)
        end)
        print("[EE-VISOR] Mission complete cleared by phase 0 reset\n")
    end
    if MissionComplete then return end
    PhaseReceived = true
    VisorPhase = phase
    if phase == 0 then
        LastLorePhase = -1
        LastLoreDay = -1
    end
    ExecuteInGameThread(function()
        if FindRefs() and HudVisible then
            WriteHudText()
            TriggerPhaseLore(phase)
        end
    end)
end

function EE_IsMenuActive()
    return MenuHidden
end

function EE_IsMissionComplete()
    return MissionComplete
end

function EE_OnLoreToggle(isOpen)
    if not MissionComplete then return end
    if isOpen then
        FadeElement("VisorGlitchText", GetOpacity("VisorGlitchText"), 0, 200)
    else
        FadeElement("VisorGlitchText", 0, 1.0, 200)
    end
end

function EE_VisorGlitchStart()
    if MissionComplete then return end
    if not HudVisible then return end
    if MenuHidden then return end
    if not FindRefs() then return end
    HudVisible = false
    SetText("VisorGlitchText", "VISOR RECALIBRATING")
    for _, name in ipairs(HudNames) do
        FadeElement(name, GetOpacity(name), 0, 100)
    end
    FadeElement("VisorGlitchText", 0, 0.9, 150)
end

function EE_VisorReboot()
    if MissionComplete then return end
    if MenuHidden then return end
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
        if VisorBooted then HudVisible = true end
    end)
end

function EE_VisorRestore()
    if MissionComplete then return end
    if MenuHidden then return end
    if not FindRefs() then return end
    FadeElement("VisorGlitchText", GetOpacity("VisorGlitchText"), 0, 80)
    for _, name in ipairs(HudNames) do
        FadeElement(name, 0, 1.0, 200)
    end
    ExecuteWithDelay(250, function()
        if VisorBooted then HudVisible = true end
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
