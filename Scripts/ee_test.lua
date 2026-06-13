-- F5: trance test
RegisterConsoleCommandHandler("ee_trance", function(FullCommand, Parameters)
    local duration = 10
    if #Parameters >= 1 then duration = tonumber(Parameters[1]) or 10 end
    if EE_TestTrance then
        EE_TestTrance(duration)
        print(string.format("[EE-TEST] Trance triggered (%ds)\n", duration))
    end
    return true
end)

-- F7: cycle weather
RegisterConsoleCommandHandler("ee_weather", function(FullCommand, Parameters)
    local weathers = {"Clear", "CloudyA", "CloudyB", "SparseClouds", "Misty", "DistantStormy"}
    local name = weathers[math.random(#weathers)]
    if Parameters[1] then name = Parameters[1] end
    ExecuteInGameThread(function()
        pcall(function()
            local UEHelpers = require("UEHelpers")
            local PC = UEHelpers.GetPlayerController()
            if not PC or not PC:IsValid() then return end
            local CM = PC.CheatManager
            if not CM or not CM:IsValid() then return end
            CM:SetCurrentWeather(name)
            CM:SetNextWeather(name)
            print(string.format("[EE-TEST] Weather set to: %s\n", name))
        end)
    end)
    return true
end)

-- F11: toggle slomo (raw test, bypasses trance)
local SlomoOn = false
RegisterConsoleCommandHandler("ee_slomo", function(FullCommand, Parameters)
    SlomoOn = not SlomoOn
    local val = SlomoOn and 0.3 or 1.0
    ExecuteInGameThread(function()
        pcall(function()
            local UEHelpers = require("UEHelpers")
            local PC = UEHelpers.GetPlayerController()
            if not PC or not PC:IsValid() then return end
            local CM = PC.CheatManager
            if not CM or not CM:IsValid() then return end
            CM:Slomo(val)
            print(string.format("[EE-TEST] Slomo set to %.1f\n", val))
        end)
    end)
    return true
end)
