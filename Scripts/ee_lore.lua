local UEHelpers = require("UEHelpers")

local FADE_MS = 40
local POLL_MS = 2000
local CONTENT_FADE = 200
local OPEN_STAGGER = 80

-- Lore content
local BODY_0 = [[ALTERRA COLONIAL SCIENCES DIVISION
Ref: ACS/4546B-7/FIELD-OBS-DISPATCH
Compiled by: Dr. Skye Maren, Lead Xenoecologist

Forty-eight hours ago, our orbital bioscan array flagged Sector 4546B-7 for a Priority-2 ecological anomaly. That designation means something is killing the local fauna faster than the biology can replace it, and the rate is accelerating. You have been deployed to collect field telemetry. Your PDA will receive our analysis as it becomes available.

A rescue vessel has been dispatched from Alterra Relay Station Kepler-9. FTL transit plus atmospheric entry puts arrival at seven standard days. The mission parameters do not allow for early extraction. We trust this will not be necessary.

You are wearing the PERISH-COPE V0.1.0. It was not built for you. Three years ago, Alterra deployed Dr. Elias Voss; a xenogeologist; to this sector under similar readings. Voss was a solo operative. He built the visor from salvaged sensor equipment during his deployment to monitor what he was experiencing. He lasted seven days. His final transmission was severely degraded, but the fragment we recovered contained the phrase "seven days in hell," which is how this operation got its name. His remains and the visor were recovered four months later. The H₂S corrosion had destroyed the onboard data storage. All of Voss's observations; his analysis, his field notes, whatever he learned during those seven days; were lost.

The visor's firmware survived. We have repaired what we could. It still displays readings Voss programmed, but without his notes, we do not yet know what all of them mean. The day counter and rescue ETA are self-explanatory. The other readouts; phase classification, a percentage index, a proximity indicator; appear to track something Voss considered important enough to monitor continuously. Your telemetry will help us determine their function. We will update you as we make progress.

Our scans suggest that whatever is happening started deep; far below the thermal layer, near the boundary the locals call the Void. The readings are consistent with what we saw three years ago, before we lost Voss.

We appreciate your willingness to participate in this deployment. Stay underwater as much as possible; preliminary atmospheric readings suggest the surface environment may be compromised. Further details pending analysis.

Assessment: Standard field deployment. Elevated caution advised.

- Dr. Skye Maren
  Alterra Colonial Sciences, Orbital Research Platform *Calypso*]]

local BODY_1 = [[ALTERRA COLONIAL SCIENCES DIVISION
Ref: ACS/4546B-7/SEIS-001
Compiled by: Dr. Skye Maren, Lead Xenoecologist

Your telemetry has been productive. Thank you for that.

A section of the basalt cap layer; the dense volcanic rock that separates the upper ocean from the deep hydrothermal vent network; has fractured along a 12-kilometer fault line. Everything that was sealed beneath that rock is now entering the water column above it.

Our water sample analysis has identified the contaminant. It is a microorganism: a single-celled archaeon, roughly two microns across, that thrives in extreme heat and pressure. On Earth, organisms like this are called thermophilic archaea; they live around deep-sea hydrothermal vents, feeding on chemical energy rather than sunlight. This species is new to us. We are designating it Sulfolobus 4546b-EX pending formal taxonomy. Under normal conditions, it cannot survive above the basalt cap. The vent rupture is pushing superheated water upward in massive plumes, carrying billions of these organisms into depth ranges where the rest of the ecosystem lives.

S. 4546b-EX feeds on the same chemical compounds that support the base of 4546B's food web; the microbial mats and chemosynthetic flora that everything else eats. It is not attacking them. It is outcompeting them. The small predators appearing in unusual locations are the first visible symptom. Their prey is vanishing from its normal habitat, so they are following it wherever it goes. This is textbook trophic displacement.

We have also made progress on Voss's visor firmware. The readout your PERISH-COPE labels as "phase" appears to be a classification system he programmed based on what he observed during his deployment. We believe he divided the event into stages. Your visor is currently reading TREMORS; we think this corresponds to the seismic activity and initial fauna displacement. Voss saw the same thing. We do not yet know what his later stage designations refer to, but given how his deployment ended, we are not optimistic.

We do not yet know how far S. 4546b-EX will spread, or how fast. Our models are running. Your continued field presence is essential to calibrating them. For now: the creatures you are encountering are hungry, confused, and territorial. They are not specifically hunting you. You are just in the way.

Assessment: Moderate threat. Fauna displacement in early stages. Standard predator avoidance protocols apply.

- Skye]]

local BODY_2 = [[ALTERRA COLONIAL SCIENCES DIVISION
Ref: ACS/4546B-7/MIGR-001
Compiled by: Dr. Skye Maren, Lead Xenoecologist

Our models were optimistic. That is being revised.

S. 4546b-EX has reached the mid-depth thermal layers; the warm, nutrient-rich band of water where most of 4546B's large fauna live and hunt. The filter feeders, the grazers, the shoal species that everything else depends on; they are dying or fleeing upward into shallow water. The predators are following.

We are now detecting deep-water apex predators in zones our database has never recorded them. These are animals evolved to hunt in open water at 200 to 500 meters depth. They do not have established territories. What they have is hunger. You are not prey in any conventional sense. You are simply the closest thing to food they have encountered.

There is a second development, and your visor data has helped us understand it. S. 4546b-EX produces hydrogen sulfide as a metabolic waste product. In small concentrations, harmless. At the saturation levels now present, the H₂S is volatilizing at the surface; escaping from the water into the air above it. Your PERISH-COPE is tracking atmospheric concentration in real time. We have now identified the surface countdown that Voss programmed; it is a toxicity timer. When you surface, it measures how long you can remain exposed before the H₂S concentration exceeds a survivable threshold. When it reaches zero, get back underwater. H₂S paralyzes the olfactory nerve before anything else. By the time you stop smelling it, you are already being poisoned. We have also correlated Voss's percentage readout with our ecosystem models. The number your visor displays as "collapse index" tracks ecological deterioration. Zero is a healthy system. The number it reaches at the end... Voss did not leave notes on that either. Our current projection is not encouraging.

You may have noticed the weather. H₂S interacts with atmospheric moisture to produce sulfuric acid microdroplets. Expect reduced visibility and increasingly stormy conditions. At current dissolved concentrations, the compound permeates sealed structures; habitat modules, shelters, any enclosed space with water exchange. Prolonged occupation accelerates toxin buildup. Your visor will track exposure inside structures as at the surface. We are suggesting you take the surface warnings seriously.

Assessment: Serious threat. Minimize surface exposure. Your data remains our highest priority.

- Skye

P.S. Five more days.]]

local BODY_3 = [[ALTERRA COLONIAL SCIENCES DIVISION
Ref: ACS/4546B-7/COLL-001
Compiled by: Dr. Skye Maren, Lead Xenoecologist

I have been looking at these numbers for six hours. The models are no longer preliminary.

The ecosystem has crossed what we classify as a tipping point; the threshold beyond which recovery requires external intervention. S. 4546b-EX has consumed or displaced the chemosynthetic microflora across more than 80% of the surveyed area. Without that foundation, herbivorous species starve. Without herbivores, mid-tier predators lose their food source. Without mid-tier predation keeping populations in balance, the remaining prey species are hunted to local extinction. Every organism in your sector is now operating on biological emergency reserves. What you are experiencing is not an invasion. It is a famine.

We have identified two additional visor functions from Voss's firmware. The first is the threat indicator. It monitors fauna signatures within approximately 150 meters of your position and categorizes proximity density; MINIMAL, ELEVATED, HIGH, or CRITICAL. Voss clearly considered this worth tracking continuously. Given the current state of things, we agree.

The second is a warning flag your visor labels as a cognitive anomaly. We now understand why Voss programmed it. At high concentrations, S. 4546b-EX produces a secondary compound; a molecule we are designating 4546-TTX, because its structure closely resembles tetrodotoxin. 4546-TTX is not identical to its Earth counterpart, but it targets the same pathways. At current ambient concentrations, it crosses the blood-brain barrier.

The result is brief episodes of cognitive disruption. Perception of time may slow. Vision may distort. You may experience a sense of detachment. These episodes are temporary; typically less than 30 seconds. If you need to break out of one immediately: sharp physical stimulus triggers an adrenaline response that overrides the sodium channel blockade. Voss knew about this. He built a warning for it into the visor. He experienced it, and he still did not survive the full seven days. Our communications are degrading. The H₂S atmospheric layer is interfering with the orbital relay signal. If our transmissions become garbled or stop, it means the atmosphere between us has become opaque to radio. The rescue vessel is on schedule.

Assessment: Critical threat. Assume all fauna are hostile. Cognitive episodes are survivable but disorienting.

- Skye

Three more days.]]

local BODY_4 = [[ALTERRA COLONIAL SCIENCES DIVISION
Ref: ACS/4546B-7/VOID-001
Signal Integrity: 14% - [PARTIAL DATA LOSS]
Compiled by: Dr. Skye Maren, Lead Xenoecologist

[...] managed to reconstruct enough of the data. There is a reason the creatures of the Void have never been seen in shallower waters. It is not because they choose to stay down there. It is because they cannot leave. Along the boundary between the Void and the inhabited ocean, there is a biogenic structure; a dense lattice of calcium carbonate deposited over thousands of years by deep-sea filter-feeding organisms. Hundreds of meters thick. These formations are called bioite barriers. They keep the leviathan-class organisms contained in their own territory.

S. 4546b-EX dissolves calcium carbonate. At normal concentrations, harmless; dissolution slower than deposition. At current concentrations, the barriers are being [...] consumed from the inside out. Twenty-two hours ago, our deep sonar array detected structural failure in the northern barrier. Three hours later, the eastern [...] followed.

We are tracking leviathan signatures in waters above 500 meters. These are Category-7 megafauna. They have never been observed outside the Void in recorded [...] history. Your best strategy is distance. If you can see one clearly, you are too close. Do not attract [...] attention.

I understand now what happened to Voss. This is what he saw. This is the stage he did not survive. The visor's final phase designation; VOID BREACH; he named it because he watched it happen. The interference your PERISH-COPE displays, the static and the flicker; it is not geological noise. It never was. It is the sensor array being overwhelmed by biological signatures too large for it [...] to resolve cleanly. When your visor glitches, something is nearby. Voss figured that out. He programmed the warning. And then whatever came through the barrier killed him before he could tell anyone what it meant.

I am breaking protocol to say this. I pushed for your deployment. I was wrong about that. You were supposed to observe. You were not supposed to be in the middle of [...] this. The rescue vessel is confirmed. I spoke with the pilot. They are on approach. ETA is within [...] days. This is likely my last transmission. If this reaches you, I need you to know that I will be on the deck of the *Calypso* watching your bioscan until you are off that planet. Two more days. Stay under the water. Stay near cover.

[END TRANSMISSION]

- Skye]]

local BODY_5 = [=[[FRAGMENTARY SIGNAL]
[SOURCE: ALTERRA RESCUE VESSEL ARC-7]
[SIGNAL INTEGRITY: 6%]

[...] is ARC-7. If you are receiving this, your relay somehow punched through the atmospheric interference. We have been trying to reach you for [...]

We have you on long-range bioscan. Vital signs are [...] still reading. You have no idea how good that looks from up here.

Approach vector is locked. The H₂S layer is going to make atmospheric entry [...] difficult, but the pilot says she has flown through worse. I am choosing to believe her.

ETA: one day. Maybe less if the wind cooperates.

I am not going to pretend the last six days were handled well. You deserved better information, sooner. You deserved to know what Voss saw before we put you in the same water. That is on me, and I will answer for it when you are back on the *Calypso*. Not before. Right now the only thing that matters is that you are still [...] alive, and that you stay that way for one more day.

Your PERISH-COPE data is transmitting automatically; we have been receiving fragments through the static. The science team is [...] already writing papers. You have generated more field data on a live extinction event than anyone in Alterra's history. That is not why I want you back. One more day. Stay below the surface. Find somewhere sheltered and do not move unless you have to.

We are coming.

[SIGNAL LOST]]=]

local LoreEntries = {
    [0] = { title = "MISSION BRIEFING",           body = BODY_0 },
    [1] = { title = "SEISMIC ANALYSIS",            body = BODY_1 },
    [2] = { title = "PREDATOR MIGRATION REPORT",   body = BODY_2 },
    [3] = { title = "ECOSYSTEM COLLAPSE MODEL",    body = BODY_3 },
    [4] = { title = "VOID BREACH ANALYSIS",        body = BODY_4 },
    [5] = { title = "RESCUE SIGNAL",               body = BODY_5 },
}

-- Widget element names
local LoreStaticNames = {
    "LoreBG", "LoreHeader", "LoreSubHeader", "LoreNav",
}

local LoreDynamicNames = {
    "LoreCounter", "LoreTitle", "LoreBody",
}

local LoreImageNames = {
    "LoreImage0",
}

local AllLoreNames = {}
for _, t in ipairs({LoreStaticNames, LoreDynamicNames, LoreImageNames}) do
    for _, name in ipairs(t) do
        table.insert(AllLoreNames, name)
    end
end

local LoreTextIndex = {
    LoreCounter = 0, LoreTitle = 1, LoreBody = 2,
}

-- State
local LoreRefs = {}
local LoreRefsFound = false
local LoreOpen = false
local LoreBooted = false
local CurrentPage = 0
local LoreMenuWatchActive = false
local Transitioning = false
local UnlockedEntries = {}
local LoreFadeGen = {}

-- Ref acquisition
local function FindLoreRefs()
    if LoreRefsFound then return true end
    local Widgets = FindAllOf("WBP_ExtinctionEvent_C")
    if not Widgets then return false end
    for _, Widget in ipairs(Widgets) do
        local wValid = false
        pcall(function() wValid = Widget:IsValid() end)
        if wValid then
            local allOk = true
            for _, name in ipairs(AllLoreNames) do
                local ok, ref = pcall(function()
                    local r = Widget[name]
                    if r and type(r) == "userdata" and r:IsValid() then return r end
                    return nil
                end)
                if ok and ref then
                    LoreRefs[name] = ref
                else
                    allOk = false
                    break
                end
            end
            if allOk then
                LoreRefs._widget = Widget
                LoreRefsFound = true
                local wPath = ""
                pcall(function() wPath = Widget:GetFullName() end)
                print(string.format("[EE-LORE] Refs OK: %s\n", wPath))
                return true
            end
        end
    end
    return false
end

local function GetLoreWidget()
    local w = LoreRefs._widget
    if w then
        local valid = false
        pcall(function() valid = w:IsValid() end)
        if valid then return w end
    end
    LoreRefsFound = false
    LoreRefs = {}
    if not FindLoreRefs() then return nil end
    return LoreRefs._widget
end

-- Text and opacity helpers
local function SetLoreText(name, text)
    local widget = GetLoreWidget()
    if not widget then return end
    local idx = LoreTextIndex[name]
    if idx == nil then return end
    pcall(function() widget:SetLoreLine(idx, text) end)
end

local function SetLoreOpacity(name, op)
    if not GetLoreWidget() then return end
    local ref = LoreRefs[name]
    if not ref then return end
    local valid = false
    pcall(function() valid = ref:IsValid() end)
    if not valid then
        LoreRefsFound = false
        LoreRefs = {}
        if not GetLoreWidget() then return end
        ref = LoreRefs[name]
        if not ref then return end
    end
    pcall(function() ref:SetRenderOpacity(op) end)
end

local function GetLoreOpacity(name)
    if not GetLoreWidget() then return 0 end
    local ref = LoreRefs[name]
    if not ref then return 0 end
    local valid = false
    pcall(function() valid = ref:IsValid() end)
    if not valid then
        LoreRefsFound = false
        LoreRefs = {}
        if not GetLoreWidget() then return 0 end
        ref = LoreRefs[name]
        if not ref then return 0 end
    end
    local op = 0
    pcall(function() op = ref:GetRenderOpacity() end)
    return op
end

local function FadeLoreElement(name, fromOp, toOp, durationMs, onComplete)
    LoreFadeGen[name] = (LoreFadeGen[name] or 0) + 1
    local gen = LoreFadeGen[name]
    local steps = math.max(1, math.floor(durationMs / FADE_MS))
    local step = 0
    if fromOp then SetLoreOpacity(name, fromOp) end

    local function Tick()
        if LoreFadeGen[name] ~= gen then return end
        step = step + 1
        if step >= steps then
            SetLoreOpacity(name, toOp)
            if onComplete then onComplete() end
            return
        end
        local from = fromOp or 0
        SetLoreOpacity(name, from + (toOp - from) * (step / steps))
        ExecuteWithDelay(FADE_MS, function() ExecuteInGameThread(Tick) end)
    end
    Tick()
end

-- Game state checks
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

-- Page management
local function GetUnlockedList()
    local list = {}
    for i = 0, 5 do
        if UnlockedEntries[i] then table.insert(list, i) end
    end
    return list
end

local function ShowPage(index)
    local entry = LoreEntries[index]
    if not entry then return end
    CurrentPage = index

    local list = GetUnlockedList()
    local pageNum = 0
    for i, idx in ipairs(list) do
        if idx == index then pageNum = i; break end
    end

    SetLoreText("LoreCounter", string.format("ENTRY %d / %d", pageNum, #list))
    SetLoreText("LoreTitle", entry.title)
    SetLoreText("LoreBody", entry.body)

    SetLoreOpacity("LoreImage0", 1.0)
end

local function TransitionToPage(newIndex)
    if newIndex == CurrentPage or Transitioning then return end
    Transitioning = true

    FadeLoreElement("LoreCounter", nil, 0, CONTENT_FADE)
    FadeLoreElement("LoreTitle", nil, 0, CONTENT_FADE)
    FadeLoreElement("LoreBody", nil, 0, CONTENT_FADE)

    ExecuteWithDelay(CONTENT_FADE + 50, function()
        ExecuteInGameThread(function()
            ShowPage(newIndex)
            FadeLoreElement("LoreCounter", 0, 1.0, CONTENT_FADE + 50)
            FadeLoreElement("LoreTitle", 0, 1.0, CONTENT_FADE + 50)
            FadeLoreElement("LoreBody", 0, 1.0, CONTENT_FADE + 50, function()
                Transitioning = false
            end)
        end)
    end)
end

-- Open / close
local function CloseLore(instant)
    if not LoreOpen then return end
    LoreOpen = false
    Transitioning = false
    if EE_OnLoreToggle then EE_OnLoreToggle(false) end
    if instant then
        for _, name in ipairs(AllLoreNames) do
            LoreFadeGen[name] = (LoreFadeGen[name] or 0) + 1
            SetLoreOpacity(name, 0)
        end
    else
        for _, name in ipairs(AllLoreNames) do
            FadeLoreElement(name, GetLoreOpacity(name), 0, 200)
        end
    end
end

local function StartLoreMenuWatch()
    if LoreMenuWatchActive then return end
    LoreMenuWatchActive = true
    local function WatchTick()
        if not LoreOpen then
            LoreMenuWatchActive = false
            return
        end
        if IsInMenu() then
            CloseLore(true)
            LoreMenuWatchActive = false
            return
        end
        ExecuteWithDelay(200, function() ExecuteInGameThread(WatchTick) end)
    end
    ExecuteWithDelay(200, function() ExecuteInGameThread(WatchTick) end)
end

local function OpenLore()
    if LoreOpen or Transitioning then return end
    if not FindLoreRefs() then return end

    local list = GetUnlockedList()
    if #list == 0 then return end

    LoreOpen = true
    if EE_OnLoreToggle then EE_OnLoreToggle(true) end

    for _, name in ipairs(AllLoreNames) do
        SetLoreOpacity(name, 0)
    end

    ShowPage(list[#list])

    FadeLoreElement("LoreBG", 0, 0.93, 250)

    local ordered = {
        "LoreHeader", "LoreSubHeader",
        "LoreCounter", "LoreTitle", "LoreBody",
        "LoreNav",
    }
    for i, name in ipairs(ordered) do
        ExecuteWithDelay(OPEN_STAGGER * i, function()
            ExecuteInGameThread(function()
                FadeLoreElement(name, 0, 1.0, 250)
            end)
        end)
    end

    ExecuteWithDelay(OPEN_STAGGER * (#ordered + 1), function()
        ExecuteInGameThread(function()
            FadeLoreElement("LoreImage0", 0, 1.0, 300)
        end)
    end)

    StartLoreMenuWatch()
end

local function ToggleLore()
    if LoreOpen then CloseLore() else OpenLore() end
end

-- Navigation
local function NextPage()
    if not LoreOpen or Transitioning then return end
    local list = GetUnlockedList()
    if #list <= 1 then return end
    local target = list[1]
    for i, idx in ipairs(list) do
        if idx == CurrentPage then
            target = list[i < #list and i + 1 or 1]
            break
        end
    end
    TransitionToPage(target)
end

local function PrevPage()
    if not LoreOpen or Transitioning then return end
    local list = GetUnlockedList()
    if #list <= 1 then return end
    local target = list[#list]
    for i, idx in ipairs(list) do
        if idx == CurrentPage then
            target = list[i > 1 and i - 1 or #list]
            break
        end
    end
    TransitionToPage(target)
end

-- Shutdown / cleanup
local function ShutdownLore()
    LoreOpen = false
    LoreBooted = false
    LoreMenuWatchActive = false
    Transitioning = false
    CurrentPage = 0
    UnlockedEntries = {}
    LoreFadeGen = {}
    for _, name in ipairs(AllLoreNames) do
        SetLoreOpacity(name, 0)
    end
end

-- Update poll, menu/PDA awareness, game exit cleanup
local function UpdateLore()
    if not FindLoreRefs() then return end

    if not IsInGame() then
        if LoreBooted then ShutdownLore() end
        LoreRefsFound = false
        LoreRefs = {}
        return
    end

    if not LoreBooted then
        LoreBooted = true
        for _, name in ipairs(AllLoreNames) do
            SetLoreOpacity(name, 0)
        end
    end

    if IsInMenu() and LoreOpen then
        CloseLore(true)
        return
    end
end

local function StartLorePoll()
    local function Poll()
        ExecuteInGameThread(function() UpdateLore() end)
        ExecuteWithDelay(POLL_MS, function() Poll() end)
    end
    ExecuteWithDelay(4000, function() Poll() end)
end

-- Global API (called by ee_visor.lua)
function EE_UnlockLoreEntry(index)
    if UnlockedEntries[index] then return end
    UnlockedEntries[index] = true
    print(string.format("[EE-LORE] Entry %d unlocked: %s\n",
        index, LoreEntries[index] and LoreEntries[index].title or "???"))
end

function EE_ResetLore()
    UnlockedEntries = {}
    UnlockedEntries[0] = true
    CurrentPage = 0
    if LoreOpen then
        LoreOpen = false
        for _, name in ipairs(AllLoreNames) do
            SetLoreOpacity(name, 0)
        end
    end
    print("[EE-LORE] Lore reset to entry 0 only\n")
end

-- Key bindings with debounce
local KeyCooldown = false
local function Debounce(fn)
    return function()
        if KeyCooldown then return end
        KeyCooldown = true
        ExecuteInGameThread(function()
            fn()
            ExecuteWithDelay(250, function() KeyCooldown = false end)
        end)
    end
end

RegisterKeyBind(Key.P, Debounce(function()
    if IsInMenu() then return end
    if not GetLoreWidget() then return end
    ToggleLore()
end))

RegisterKeyBind(Key.LEFT_ARROW, Debounce(function()
    if not LoreOpen then return end
    PrevPage()
end))

RegisterKeyBind(Key.RIGHT_ARROW, Debounce(function()
    if not LoreOpen then return end
    NextPage()
end))

-- Console command fallbacks
RegisterConsoleCommandHandler("ee_lore", function(_, Parameters)
    ExecuteInGameThread(function()
        if #Parameters > 0 then
            local idx = tonumber(Parameters[1])
            if idx then EE_UnlockLoreEntry(idx) end
        end
        if IsInMenu() then return end
        if not FindLoreRefs() then return end
        ToggleLore()
    end)
    return true
end)

RegisterConsoleCommandHandler("ee_lore_next", function()
    ExecuteInGameThread(function()
        if LoreOpen then NextPage() end
    end)
    return true
end)

RegisterConsoleCommandHandler("ee_lore_prev", function()
    ExecuteInGameThread(function()
        if LoreOpen then PrevPage() end
    end)
    return true
end)

StartLorePoll()
print("[EE-LORE] PERISH-COPE Data Recovery Terminal loaded\n")
print("[EE-LORE] P: Open/Close | LEFT: Prev | RIGHT: Next\n")
