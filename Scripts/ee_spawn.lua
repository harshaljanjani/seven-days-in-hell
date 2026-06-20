local UEHelpers = require("UEHelpers")
local AIHelpers = nil

-- Not available at script load time, lazy-init
local function GetAIHelpers()
    if not AIHelpers or not AIHelpers:IsValid() then
        AIHelpers = StaticFindObject("/Script/AIModule.Default__AIBlueprintHelperLibrary")
    end
    return AIHelpers
end

-- Creature pools
local SmallCarnivores = {
    "/Game/Blueprints/AI/Agents/SmallCreature012_Bullethead/BP_Bullethead.BP_Bullethead_C",
    "/Game/Blueprints/AI/Agents/SmallCreature001_Quadrate/BP_Quadrate.BP_Quadrate_C",
    "/Game/Blueprints/AI/Agents/SmallCreature018_FourEye/BP_FourEye.BP_FourEye_C",
}

local BigCarnivores = {
    "/Game/Blueprints/AI/Agents/LargeCreature018_NibblerShark/BP_NibblerShark.BP_NibblerShark_C",
    "/Game/Blueprints/AI/Agents/LargeCreature003_NeedlerShark/BP_NeedlerShark.BP_NeedlerShark_C",
    "/Game/Blueprints/AI/Agents/LargeCreature004_Marrowbreach/BP_Marrowbreach.BP_Marrowbreach_C",
    "/Game/Blueprints/AI/Agents/LargeCreature008_TwinEel/BP_TwinEel.BP_TwinEel_C",
    "/Game/Blueprints/AI/Agents/LargeCreature015_Epicurean/BP_Epicurean.BP_Epicurean_C",
}

local GiantCarnivores = {
    "/Game/Blueprints/AI/Agents/LargeCreature003_NeedlerShark/BP_NeedlerShark_Giant.BP_NeedlerShark_Giant_C",
    "/Game/Blueprints/AI/Agents/LargeCreature004_Marrowbreach/BP_Marrowbreach_Giant.BP_Marrowbreach_Giant_C",
}

local Leviathans = {
    "/Game/Blueprints/AI/Agents/DeepWingLeviathan/BP_DeepWingLeviathan.BP_DeepWingLeviathan_C",
    "/Game/Blueprints/AI/Agents/VoidLeviathan/BP_VoidLeviathanMother.BP_VoidLeviathanMother_C",
    "/Game/Blueprints/AI/Agents/VoidLeviathan/BP_VoidLeviathanChild.BP_VoidLeviathanChild_C",
}

-- Phase configs
local PhaseConfig = {
    [1] = {
        initialDelay = {50, 100},
        waveInterval = {120, 180},
        waves = {
            {pool = SmallCarnivores, count = {3, 5}, dist = {1500, 2500}, zOffset = {-200, -400}},
        },
        wildcardChance = 0.15,
    },
    [2] = {
        initialDelay = {35, 75},
        waveInterval = {100, 150},
        waves = {
            {pool = BigCarnivores, count = {2, 3}, dist = {2000, 3500}, zOffset = {-300, -700}},
            {pool = SmallCarnivores, count = {3, 4}, dist = {1500, 2500}, zOffset = {-200, -400}, staggerDelay = {12, 25}},
        },
        wildcardChance = 0.25,
    },
    [3] = {
        initialDelay = {25, 50},
        waveInterval = {75, 120},
        waves = {
            {pool = GiantCarnivores, count = {1, 2}, dist = {2500, 4000}, zOffset = {-500, -1000}, highTier = true},
            {pool = BigCarnivores, count = {2, 3}, dist = {2000, 3500}, zOffset = {-300, -700}, staggerDelay = {8, 18}},
            {pool = SmallCarnivores, count = {3, 5}, dist = {1500, 2500}, zOffset = {-200, -400}, staggerDelay = {15, 30}},
        },
        wildcardChance = 0.3,
    },
    [4] = {
        initialDelay = {45, 75},
        waveInterval = {150, 240},
        waves = {
            {pool = Leviathans, count = {1, 1}, dist = {15000, 25000}, zOffset = {-1500, -3000}, highTier = true},
            {pool = GiantCarnivores, count = {1, 1}, dist = {2500, 4000}, zOffset = {-500, -1000}, staggerDelay = {12, 25}, highTier = true},
            {pool = BigCarnivores, count = {2, 3}, dist = {2000, 3500}, zOffset = {-300, -700}, staggerDelay = {25, 45}},
            {pool = SmallCarnivores, count = {3, 5}, dist = {1500, 2500}, zOffset = {-200, -400}, staggerDelay = {35, 55}},
        },
        wildcardChance = 0.35,
    },
}

-- Cumulative pools, each phase includes all previous tiers
local function CopyTable(t)
    local c = {}
    for i, v in ipairs(t) do c[i] = v end
    return c
end

local CumulativePools = {
    [1] = CopyTable(SmallCarnivores),
    [2] = CopyTable(SmallCarnivores),
    [3] = CopyTable(SmallCarnivores),
    [4] = CopyTable(SmallCarnivores),
}
for _, v in ipairs(BigCarnivores) do
    table.insert(CumulativePools[2], v)
    table.insert(CumulativePools[3], v)
    table.insert(CumulativePools[4], v)
end
for _, v in ipairs(GiantCarnivores) do
    table.insert(CumulativePools[3], v)
    table.insert(CumulativePools[4], v)
end
for _, v in ipairs(Leviathans) do
    table.insert(CumulativePools[4], v)
end

-- Active phase tracking

local ActivePhase = 0
local SpawnTag = 0
local MAX_HIGH_TIER = 2

local CreatureClassNames = {
    "BP_Bullethead_C", "BP_Quadrate_C", "BP_FourEye_C",
    "BP_NibblerShark_C", "BP_NeedlerShark_C", "BP_NeedlerShark_Giant_C",
    "BP_Marrowbreach_C", "BP_Marrowbreach_Giant_C",
    "BP_TwinEel_C", "BP_Epicurean_C",
    "BP_DeepWingLeviathan_C", "BP_VoidLeviathanMother_C", "BP_VoidLeviathanChild_C",
}

local HighTierClasses = {
    BP_NeedlerShark_Giant_C = true, BP_Marrowbreach_Giant_C = true,
    BP_DeepWingLeviathan_C = true, BP_VoidLeviathanMother_C = true, BP_VoidLeviathanChild_C = true,
}

local LowTierClasses = {
    BP_Bullethead_C = true, BP_Quadrate_C = true, BP_FourEye_C = true,
    BP_NibblerShark_C = true, BP_NeedlerShark_C = true,
    BP_Marrowbreach_C = true, BP_TwinEel_C = true, BP_Epicurean_C = true,
}

local PhaseCreatureClasses = {
    [0] = {},
    [1] = {"BP_Bullethead_C", "BP_Quadrate_C", "BP_FourEye_C"},
    [2] = {"BP_Bullethead_C", "BP_Quadrate_C", "BP_FourEye_C",
           "BP_NibblerShark_C", "BP_NeedlerShark_C",
           "BP_Marrowbreach_C", "BP_TwinEel_C", "BP_Epicurean_C"},
    [3] = {"BP_Bullethead_C", "BP_Quadrate_C", "BP_FourEye_C",
           "BP_NibblerShark_C", "BP_NeedlerShark_C", "BP_NeedlerShark_Giant_C",
           "BP_Marrowbreach_C", "BP_Marrowbreach_Giant_C",
           "BP_TwinEel_C", "BP_Epicurean_C"},
    [4] = CreatureClassNames,
}

local function GetPhaseClasses()
    return PhaseCreatureClasses[ActivePhase] or CreatureClassNames
end

local function SafeActorLocation(actor)
    local loc = nil
    pcall(function()
        if not actor:IsValid() then return end
        loc = actor:K2_GetActorLocation()
    end)
    if loc and loc.X then return loc end
    return nil
end

local function SafeDestroyActor(actor)
    pcall(function()
        if actor:IsValid() then actor:K2_DestroyActor() end
    end)
end

function EE_GetPhaseCreatureClasses()
    return GetPhaseClasses()
end

function EE_StopAllSpawns()
    ActivePhase = -1
    SpawnTag = SpawnTag + 1
    print("[EE] All spawns stopped\n")
end

local function CountNearbyByTier(radius)
    local high, low = 0, 0
    pcall(function()
        local PC = UEHelpers.GetPlayerController()
        if not PC or not PC:IsValid() then return end
        local Pawn = PC.Pawn
        if not Pawn or not Pawn:IsValid() then return end
        local ploc = SafeActorLocation(Pawn)
        if not ploc then return end

        for _, className in ipairs(GetPhaseClasses()) do
            local actors = FindAllOf(className)
            if actors then
                for _, actor in ipairs(actors) do
                    local loc = SafeActorLocation(actor)
                    if loc then
                        local dx = loc.X - ploc.X
                        local dy = loc.Y - ploc.Y
                        local dz = loc.Z - ploc.Z
                        if math.sqrt(dx*dx + dy*dy + dz*dz) < radius then
                            if HighTierClasses[className] then
                                high = high + 1
                            elseif LowTierClasses[className] then
                                low = low + 1
                            end
                        end
                    end
                end
            end
        end
    end)
    return high, low
end

local function CleanupNearbyLowTier(radius)
    pcall(function()
        local PC = UEHelpers.GetPlayerController()
        if not PC or not PC:IsValid() then return end
        local Pawn = PC.Pawn
        if not Pawn or not Pawn:IsValid() then return end
        local ploc = SafeActorLocation(Pawn)
        if not ploc then return end
        local cleaned = 0

        for className, _ in pairs(LowTierClasses) do
            local actors = FindAllOf(className)
            if actors then
                for _, actor in ipairs(actors) do
                    local loc = SafeActorLocation(actor)
                    if loc then
                        local dx = loc.X - ploc.X
                        local dy = loc.Y - ploc.Y
                        local dz = loc.Z - ploc.Z
                        if math.sqrt(dx*dx + dy*dy + dz*dz) < radius then
                            SafeDestroyActor(actor)
                            cleaned = cleaned + 1
                        end
                    end
                end
            end
        end
        if cleaned > 0 then
            print(string.format("[EE] Cleaned %d low-tier creatures for high-tier spawn\n", cleaned))
        end
    end)
end

-- Utility

local function RandRange(min, max)
    return math.random(min, max)
end

local function RandFloat(min, max)
    return min + math.random() * (max - min)
end

local function PickRandom(tbl)
    if #tbl == 0 then return nil end
    return tbl[math.random(#tbl)]
end

local function PickRandomN(tbl, n)
    if #tbl == 0 then return {} end
    local result = {}
    local copy = {}
    for i, v in ipairs(tbl) do copy[i] = v end
    for i = 1, math.min(n, #copy) do
        local idx = math.random(#copy)
        table.insert(result, copy[idx])
        table.remove(copy, idx)
    end
    while #result < n do
        table.insert(result, PickRandom(tbl))
    end
    return result
end

-- Glitch overlay refs and state
local GlitchOverlayRef = nil
local GlitchWidgetRef = nil
local GlitchPhaseOpacity = 1.0
local GlitchActive = false

local function FindGlitchRefs()
    local valid = false
    pcall(function()
        valid = GlitchOverlayRef and GlitchOverlayRef:IsValid()
                and GlitchWidgetRef and GlitchWidgetRef:IsValid()
    end)
    if valid then return true end
    GlitchOverlayRef = nil
    GlitchWidgetRef = nil
    local Widgets = FindAllOf("WBP_ExtinctionEvent_C")
    if not Widgets then return false end
    for _, Widget in ipairs(Widgets) do
        local ok, img = pcall(function()
            if not Widget:IsValid() then return nil end
            local go = Widget.GlitchOverlay
            if go and type(go) == "userdata" and go:IsValid() then return go end
            return nil
        end)
        if ok and img then
            GlitchWidgetRef = Widget
            GlitchOverlayRef = img
            return true
        end
    end
    return false
end

function EE_SetGlitchOpacity(opacity)
    GlitchPhaseOpacity = opacity
end

local function IsInMenu()
    local inMenu = true
    pcall(function()
        local PC = UEHelpers.GetPlayerController()
        if not PC or not PC:IsValid() then return end
        local ok, cursor = pcall(function() return PC.bShowMouseCursor end)
        inMenu = ok and cursor
    end)
    return inMenu
end

local function SetGlitchOpacity(o)
    if not GlitchOverlayRef then return end
    pcall(function() GlitchOverlayRef:SetRenderOpacity(o) end)
end

-- spawn glitch: flicker → solid blotch (teleport here) → flicker hold → flicker fade
local SpawnGlitchReady = false

local function TriggerSpawnGlitch()
    if EE_IsMissionComplete and EE_IsMissionComplete() then return end
    if IsInMenu() then return end
    if not FindGlitchRefs() then return end
    GlitchActive = true
    SpawnGlitchReady = false
    if EE_VisorGlitchStart then EE_VisorGlitchStart() end

    local preFlickers = RandRange(5, 8)
    local interval = 40
    local maskMs = 150
    local holdMs = ({[1] = 1100, [2] = 1100, [3] = 1100, [4] = 1500})[ActivePhase] or 1100
    local fadeMs = 800
    local holdTicks = math.floor(holdMs / interval)
    local fadeTicks = math.floor(fadeMs / interval)
    local totalTicks = holdTicks + fadeTicks

    pcall(function() GlitchOverlayRef:SetVisibility(3) end)

    -- phase 1: pre-flicker burst (ramping drift, not linear)
    local preTick = 0
    local prePrevOpacity = 0
    local function PreFlickerTick()
        if EE_IsMissionComplete and EE_IsMissionComplete() then
            if FindGlitchRefs() then SetGlitchOpacity(0); pcall(function() GlitchOverlayRef:SetVisibility(1) end) end
            GlitchActive = false; return
        end
        preTick = preTick + 1
        if preTick > preFlickers or not FindGlitchRefs() then
            -- phase 2: solid blotch (teleport happens during this)
            SetGlitchOpacity(1.0)
            pcall(function() GlitchOverlayRef:SetVisibility(3) end)
            SpawnGlitchReady = true

            -- phase 3: post-flicker hold + fade
            local postTick = 0
            local prevOpacity = 1.0
            local function PostFlickerTick()
                if EE_IsMissionComplete and EE_IsMissionComplete() then
                    if FindGlitchRefs() then SetGlitchOpacity(0); pcall(function() GlitchOverlayRef:SetVisibility(1) end) end
                    GlitchActive = false; return
                end
                postTick = postTick + 1
                if postTick > totalTicks or not FindGlitchRefs() then
                    if FindGlitchRefs() then
                        SetGlitchOpacity(0)
                        pcall(function() GlitchOverlayRef:SetVisibility(1) end)
                    end
                    GlitchActive = false
                    if EE_VisorReboot then EE_VisorReboot() end
                    return
                end

                pcall(function() GlitchOverlayRef:SetVisibility(3) end)

                local opacity
                if postTick <= holdTicks then
                    local drift = (math.random() - 0.5) * 0.3
                    opacity = math.max(0.4, math.min(1.0, prevOpacity + drift))
                else
                    local fadeProgress = (postTick - holdTicks) / fadeTicks
                    local ceiling = 1.0 - fadeProgress
                    local drift = (math.random() - 0.5) * 0.25
                    opacity = math.max(0, math.min(ceiling, prevOpacity + drift))
                end

                prevOpacity = opacity
                SetGlitchOpacity(opacity)
                ExecuteWithDelay(interval, function()
                    ExecuteInGameThread(PostFlickerTick)
                end)
            end

            ExecuteWithDelay(maskMs, function()
                ExecuteInGameThread(PostFlickerTick)
            end)
            return
        end

        local ceiling = preTick / preFlickers
        local drift = (math.random() - 0.5) * 0.25
        local opacity = math.max(0.1, math.min(ceiling, prePrevOpacity + drift + (ceiling * 0.2)))
        prePrevOpacity = opacity
        SetGlitchOpacity(opacity)

        ExecuteWithDelay(interval, function()
            ExecuteInGameThread(PreFlickerTick)
        end)
    end

    PreFlickerTick()
end

-- false alarm: randomized flicker burst, more intense at higher phases
local function TriggerFalseAlarm()
    if EE_IsMissionComplete and EE_IsMissionComplete() then return end
    if IsInMenu() then return end
    if not FindGlitchRefs() then return end
    if GlitchActive then return end
    GlitchActive = true
    if EE_VisorGlitchStart then EE_VisorGlitchStart() end

    local baseOpacity = GlitchPhaseOpacity
    local interval = 40
    local totalTicks = ({[1] = RandRange(5, 8), [2] = RandRange(7, 12), [3] = RandRange(10, 16), [4] = RandRange(14, 22)})[ActivePhase] or RandRange(5, 8)
    local tick = 0
    local prevOpacity = 0

    pcall(function() GlitchOverlayRef:SetVisibility(3) end)

    local function FlickerTick()
        if EE_IsMissionComplete and EE_IsMissionComplete() then
            if FindGlitchRefs() then SetGlitchOpacity(0); pcall(function() GlitchOverlayRef:SetVisibility(1) end) end
            GlitchActive = false; return
        end
        tick = tick + 1
        if not GlitchActive or tick > totalTicks or not FindGlitchRefs() then
            if FindGlitchRefs() then
                SetGlitchOpacity(0)
                pcall(function() GlitchOverlayRef:SetVisibility(1) end)
            end
            GlitchActive = false
            if EE_VisorRestore then EE_VisorRestore() end
            return
        end

        local fadeProgress = tick / totalTicks
        local ceiling = baseOpacity * (1.0 - fadeProgress)
        local drift = (math.random() - 0.5) * 0.2
        local opacity = math.max(0, math.min(ceiling, prevOpacity + drift + (ceiling * 0.15)))
        prevOpacity = opacity
        SetGlitchOpacity(opacity)

        ExecuteWithDelay(interval, function()
            ExecuteInGameThread(FlickerTick)
        end)
    end

    FlickerTick()
end

-- Sea level cache for spawn Z clamping
local SpawnSeaLevel = nil
local function GetSpawnSeaLevel()
    if SpawnSeaLevel then return SpawnSeaLevel end
    pcall(function()
        local statics = StaticFindObject("/Script/UWEGameplay.Default__UWEGameConfigurationStatics")
        if not statics then return end
        local isValid = false
        pcall(function() isValid = statics:IsValid() end)
        if isValid then
            SpawnSeaLevel = statics:GetGlobalOceanSeaLevel()
        end
    end)
    return SpawnSeaLevel or 0
end

-- Position calculation (behind player, outside FoV)

local function CalcSpawnPosition(dist, zOffsetMin, zOffsetMax)
    local ok, result = pcall(function()
        local PC = UEHelpers.GetPlayerController()
        if not PC or not PC:IsValid() then return nil end
        local Pawn = PC.Pawn
        if not Pawn or not Pawn:IsValid() then return nil end
        return {pawn = Pawn, loc = Pawn:K2_GetActorLocation(), fwd = Pawn:GetActorForwardVector(), rot = Pawn:K2_GetActorRotation()}
    end)
    if not ok or not result then return nil end
    local Loc = result.loc
    local Fwd = result.fwd

    -- 120°-240° arc = behind player, outside 120° forward FoV cone
    local angleDeg = RandFloat(120, 240)
    local angleRad = math.rad(angleDeg)

    local cosA = math.cos(angleRad)
    local sinA = math.sin(angleRad)
    local dirX = Fwd.X * cosA - Fwd.Y * sinA
    local dirY = Fwd.X * sinA + Fwd.Y * cosA

    local spawnX = Loc.X + dirX * dist
    local spawnY = Loc.Y + dirY * dist
    local spawnZ = Loc.Z - RandRange(math.abs(zOffsetMin), math.abs(zOffsetMax))

    local seaLevel = GetSpawnSeaLevel()
    if spawnZ > seaLevel - 500 then
        spawnZ = seaLevel - 500
    end

    return {
        x = spawnX, y = spawnY, z = spawnZ,
        saveX = Loc.X, saveY = Loc.Y, saveZ = Loc.Z,
        rot = result.rot
    }
end

-- Spawn group: one teleport, all summons, one return

local function SpawnGroup(creatures, dist, zOffsetMin, zOffsetMax)
    local pos = CalcSpawnPosition(dist, zOffsetMin, zOffsetMax)
    if not pos then
        print("[EE] Failed to calculate spawn position\n")
        return
    end

    ExecuteInGameThread(function()
        pcall(function()
            local PC = UEHelpers.GetPlayerController()
            if not PC or not PC:IsValid() then return end
            local Pawn = PC.Pawn
            if not Pawn or not Pawn:IsValid() then return end
            local CM = PC.CheatManager
            if not CM or not CM:IsValid() then return end

            for _, path in ipairs(creatures) do
                LoadAsset(path)
            end

            TriggerSpawnGlitch()

            local spawnRetries = 0
            local function DoSpawnWhenReady()
                spawnRetries = spawnRetries + 1
                if SpawnGlitchReady or spawnRetries > 50 then
                    pcall(function()
                        local TP = UEHelpers.GetPlayerController()
                        if not TP or not TP:IsValid() then return end
                        local TPawn = TP.Pawn
                        if not TPawn or not TPawn:IsValid() then return end
                        local TCM = TP.CheatManager
                        if not TCM or not TCM:IsValid() then return end

                        local TempLoc = TPawn:K2_GetActorLocation()
                        TempLoc.X = pos.x
                        TempLoc.Y = pos.y
                        TempLoc.Z = pos.z
                        TPawn:K2_SetActorLocationAndRotation(TempLoc, pos.rot, false, {}, true)

                        for _, path in ipairs(creatures) do
                            TCM:Summon(path)
                        end

                        print(string.format("[EE] Spawned group of %d at dist %.0f behind player\n", #creatures, dist))

                        ExecuteWithDelay(50, function()
                            ExecuteInGameThread(function()
                                pcall(function()
                                    local RetPC = UEHelpers.GetPlayerController()
                                    if not RetPC or not RetPC:IsValid() then return end
                                    local RetPawn = RetPC.Pawn
                                    if not RetPawn or not RetPawn:IsValid() then return end
                                    local RetLoc = RetPawn:K2_GetActorLocation()
                                    RetLoc.X = pos.saveX
                                    RetLoc.Y = pos.saveY
                                    RetLoc.Z = pos.saveZ
                                    RetPawn:K2_SetActorLocationAndRotation(RetLoc, pos.rot, false, {}, true)

                                    local function RepeatedAggro(remaining)
                                        if remaining <= 0 then return end
                                        ExecuteWithDelay(500, function()
                                            ExecuteInGameThread(function()
                                                pcall(ForceAggroAll)
                                                ExecuteWithDelay(3000, function()
                                                    ExecuteInGameThread(function()
                                                        RepeatedAggro(remaining - 1)
                                                    end)
                                                end)
                                            end)
                                        end)
                                    end
                                    RepeatedAggro(3)
                                end)
                            end)
                        end)
                    end)
                    return
                end
                ExecuteWithDelay(20, function()
                    ExecuteInGameThread(DoSpawnWhenReady)
                end)
            end

            DoSpawnWhenReady()
        end)
    end)
end

-- Force aggro on nearby creatures

function ForceAggroAll()
    pcall(function()
        local helpers = GetAIHelpers()
        if not helpers or not helpers:IsValid() then return end

        local PC = UEHelpers.GetPlayerController()
        if not PC or not PC:IsValid() then return end
        local Pawn = PC.Pawn
        if not Pawn or not Pawn:IsValid() then return end

        local PlayerLoc = SafeActorLocation(Pawn)
        if not PlayerLoc then return end
        local candidates = {}

        for _, className in ipairs(GetPhaseClasses()) do
            local actors = FindAllOf(className)
            if actors then
                for _, actor in ipairs(actors) do
                    local loc = SafeActorLocation(actor)
                    if loc then
                        local dx = loc.X - PlayerLoc.X
                        local dy = loc.Y - PlayerLoc.Y
                        local dz = loc.Z - PlayerLoc.Z
                        local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
                        if dist < 25000 then
                            table.insert(candidates, {actor = actor, dist = dist})
                        end
                    end
                end
            end
        end

        table.sort(candidates, function(a, b) return a.dist < b.dist end)

        local maxAggro = 6
        local aggroCount = 0
        for i = 1, math.min(#candidates, maxAggro) do
            pcall(function()
                local actor = candidates[i].actor
                if not actor:IsValid() then return end
                local controller = helpers:GetAIController(actor)
                if controller and controller:IsValid() then
                    controller:K2_SetFocus(Pawn)
                    helpers:SimpleMoveToActor(controller, Pawn)
                    aggroCount = aggroCount + 1
                end
            end)
        end

        if aggroCount > 0 then
            print(string.format("[EE] Forced aggro on %d creatures (of %d nearby)\n", aggroCount, #candidates))
        end
    end)
end

-- Distant creature cleanup (every 30s, removes our creature types beyond 500m)
local CLEANUP_DISTANCE = 50000
local CleanupActive = false

local function StartCreatureCleanup()
    if CleanupActive then return end
    CleanupActive = true

    local function DoCleanup()
        if ActivePhase == 0 then CleanupActive = false; return end

        pcall(function()
            local PC = UEHelpers.GetPlayerController()
            if not PC or not PC:IsValid() then return end
            local Pawn = PC.Pawn
            if not Pawn or not Pawn:IsValid() then return end
            local PlayerLoc = SafeActorLocation(Pawn)
            if not PlayerLoc then return end

            local toDestroy = {}

            for _, className in ipairs(GetPhaseClasses()) do
                local actors = FindAllOf(className)
                if actors then
                    for _, actor in ipairs(actors) do
                        local loc = SafeActorLocation(actor)
                        if loc then
                            local dx = loc.X - PlayerLoc.X
                            local dy = loc.Y - PlayerLoc.Y
                            local dz = loc.Z - PlayerLoc.Z
                            if math.sqrt(dx*dx + dy*dy + dz*dz) > CLEANUP_DISTANCE then
                                table.insert(toDestroy, actor)
                            end
                        end
                    end
                end
            end

            for _, actor in ipairs(toDestroy) do
                SafeDestroyActor(actor)
            end

            if #toDestroy > 0 then
                print(string.format("[EE] Cleaned up %d distant creatures\n", #toDestroy))
            end
        end)

        ExecuteWithDelay(30000, function()
            ExecuteInGameThread(DoCleanup)
        end)
    end

    ExecuteWithDelay(30000, function()
        ExecuteInGameThread(DoCleanup)
    end)
end

-- Execute a wave (one or more groups with stagger)

local function ExecuteWave(phaseNum, tag)
    if SpawnTag ~= tag then return end
    local config = PhaseConfig[phaseNum]
    if not config then return end

    local isWildcard = math.random() < (config.wildcardChance or 0)
    if isWildcard and CumulativePools[phaseNum] then
        local count = RandRange(2, 4)
        local creatures = PickRandomN(CumulativePools[phaseNum], count)
        local dist = RandFloat(2000, 5000)
        print(string.format("[EE] WILDCARD wave for Phase %d - %d random creatures\n", phaseNum, count))
        SpawnGroup(creatures, dist, -500, -1200)

        local nextWaveDelay = RandRange(config.waveInterval[1], config.waveInterval[2]) * 1000
        ExecuteWithDelay(nextWaveDelay, function()
            ExecuteInGameThread(function()
                if SpawnTag == tag then
                    ExecuteWave(phaseNum, tag)
                end
            end)
        end)
        return
    end

    print(string.format("[EE] Executing wave for Phase %d\n", phaseNum))

    local highNearby, lowNearby = CountNearbyByTier(25000)
    local highBudget = math.max(0, MAX_HIGH_TIER - highNearby)

    if highBudget == 0 and lowNearby > 0 and math.random() < 0.5 then
        CleanupNearbyLowTier(35000)
        highBudget = MAX_HIGH_TIER
    end

    local cumulativeDelay = 0

    for _, waveGroup in ipairs(config.waves) do
        local count = RandRange(waveGroup.count[1], waveGroup.count[2])

        if waveGroup.highTier then
            if highBudget <= 0 then
                print(string.format("[EE] High-tier cap reached, skipping %d creatures\n", count))
                goto continue
            end
            count = math.min(count, highBudget)
            highBudget = highBudget - count
        end

        local creatures = PickRandomN(waveGroup.pool, count)
        local dist = RandFloat(waveGroup.dist[1], waveGroup.dist[2])
        local zMin = waveGroup.zOffset[1]
        local zMax = waveGroup.zOffset[2]

        local delay = cumulativeDelay
        if waveGroup.staggerDelay then
            delay = delay + RandRange(waveGroup.staggerDelay[1], waveGroup.staggerDelay[2]) * 1000
        end

        if delay > 0 then
            ExecuteWithDelay(delay, function()
                ExecuteInGameThread(function()
                    SpawnGroup(creatures, dist, zMin, zMax)
                end)
            end)
        else
            SpawnGroup(creatures, dist, zMin, zMax)
        end

        cumulativeDelay = delay
        ::continue::
    end

    local nextWaveDelay = RandRange(config.waveInterval[1], config.waveInterval[2]) * 1000
    local totalDelay = cumulativeDelay + nextWaveDelay

    ExecuteWithDelay(totalDelay, function()
        ExecuteInGameThread(function()
            if SpawnTag == tag then
                print(string.format("[EE] Repeat wave for Phase %d (active phase: %d)\n", phaseNum, ActivePhase))
                ExecuteWave(phaseNum, tag)
            end
        end)
    end)
end

-- False alarm glitches (no spawn, just visual)

local function ScheduleFalseAlarms(phaseNum, tag)
    local intervals = {
        [1] = {90, 150},
        [2] = {60, 90},
        [3] = {40, 60},
        [4] = {30, 50},
    }
    local interval = intervals[phaseNum] or {60, 90}

    local function DoFalseAlarm()
        if SpawnTag ~= tag then return end

        if math.random() < 0.3 then
            ExecuteInGameThread(function()
                TriggerFalseAlarm()
                print("[EE] False alarm glitch\n")
            end)
        end

        local nextDelay = RandRange(interval[1], interval[2]) * 1000
        ExecuteWithDelay(nextDelay, function()
            DoFalseAlarm()
        end)
    end

    local firstDelay = RandRange(interval[1], interval[2]) * 1000
    ExecuteWithDelay(firstDelay, function()
        DoFalseAlarm()
    end)
end

-- Phase handler

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

RegisterConsoleCommandHandler("ee_phase", function(FullCommand, Parameters)
    if #Parameters < 1 then
        print("[EE] Usage: ee_phase <phase_number>\n")
        return true
    end

    local phaseNum = tonumber(Parameters[1])
    if not phaseNum or phaseNum < 0 or phaseNum > 4 then
        print(string.format("[EE] Invalid phase: %s\n", Parameters[1]))
        return true
    end

    if not IsInMainLevel() then
        print(string.format("[EE] Phase %d ignored - not in game level\n", phaseNum))
        if EE_ShutdownAtmosphere then EE_ShutdownAtmosphere() end
        return true
    end

    if phaseNum == 0 then
        ActivePhase = 0
        SpawnTag = SpawnTag + 1
        if EE_SetAtmospherePhase then EE_SetAtmospherePhase(0) end
        if EE_SetVisorPhase then EE_SetVisorPhase(0) end
        if EE_ResetLore then EE_ResetLore() end
        print("[EE] === PHASE 0 - ALL SYSTEMS RESET ===\n")
        return true
    end

    ActivePhase = phaseNum
    SpawnTag = SpawnTag + 1
    local tag = SpawnTag

    print(string.format("[EE] === PHASE %d ACTIVATED ===\n", phaseNum))

    if EE_SetAtmospherePhase then EE_SetAtmospherePhase(phaseNum) end
    if EE_SetVisorPhase then EE_SetVisorPhase(phaseNum) end

    local config = PhaseConfig[phaseNum]
    local initialDelay = RandRange(config.initialDelay[1], config.initialDelay[2]) * 1000

    print(string.format("[EE] First wave in %.0f seconds\n", initialDelay / 1000))

    ExecuteWithDelay(initialDelay, function()
        ExecuteInGameThread(function()
            if SpawnTag == tag then
                ExecuteWave(phaseNum, tag)
            end
        end)
    end)

    ScheduleFalseAlarms(phaseNum, tag)
    StartCreatureCleanup()

    return true
end)

RegisterConsoleCommandHandler("ee_spawn", function(FullCommand, Parameters)
    if #Parameters < 4 then return true end
    local function cleanNumber(s)
        local cleaned = s:gsub(",", ""):gsub("%s", "")
        return tonumber(cleaned)
    end
    local path = Parameters[1]
    local x = cleanNumber(Parameters[2])
    local y = cleanNumber(Parameters[3])
    local z = cleanNumber(Parameters[4])
    if not x or not y or not z then return true end

    ExecuteInGameThread(function()
        pcall(function()
            local PC = UEHelpers.GetPlayerController()
            if not PC or not PC:IsValid() then return end
            local Pawn = PC.Pawn
            if not Pawn or not Pawn:IsValid() then return end
            LoadAsset(path)
            local origLoc = Pawn:K2_GetActorLocation()
            local origRot = Pawn:K2_GetActorRotation()
            local sx, sy, sz = origLoc.X, origLoc.Y, origLoc.Z

            TriggerSpawnGlitch()

            local dbgRetries = 0
            local function DoSpawn()
                dbgRetries = dbgRetries + 1
                if SpawnGlitchReady or dbgRetries > 50 then
                    pcall(function()
                        local TP = UEHelpers.GetPlayerController()
                        if not TP or not TP:IsValid() then return end
                        local TPawn = TP.Pawn
                        if not TPawn or not TPawn:IsValid() then return end
                        local TCM = TP.CheatManager
                        if not TCM or not TCM:IsValid() then return end
                        local tmp = TPawn:K2_GetActorLocation()
                        tmp.X = x; tmp.Y = y; tmp.Z = z
                        TPawn:K2_SetActorLocationAndRotation(tmp, origRot, false, {}, true)
                        TCM:Summon(path)
                        ExecuteWithDelay(50, function()
                            ExecuteInGameThread(function()
                                pcall(function()
                                    local rpc = UEHelpers.GetPlayerController()
                                    if not rpc or not rpc:IsValid() then return end
                                    local rp = rpc.Pawn
                                    if not rp or not rp:IsValid() then return end
                                    local rl = rp:K2_GetActorLocation()
                                    rl.X = sx; rl.Y = sy; rl.Z = sz
                                    rp:K2_SetActorLocationAndRotation(rl, origRot, false, {}, true)
                                end)
                            end)
                        end)
                    end)
                    return
                end
                ExecuteWithDelay(20, function() ExecuteInGameThread(DoSpawn) end)
            end

            DoSpawn()
        end)
    end)
    return true
end)

print("[EE] Extinction Event spawn system loaded\n")
print("[EE] Commands: ee_phase <1-4>, ee_spawn <path> <x> <y> <z>\n")
