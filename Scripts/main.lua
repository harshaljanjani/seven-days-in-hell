GlobalAr = nil

function Log(Message)
    print("[ConsoleCommandsMod] " .. Message .. "\n")
    if type(GlobalAr) == "userdata" and GlobalAr:type() == "FOutputDevice" then
        GlobalAr:Log(Message)
    end
end

require("summon_unloaded_assets")
require("set")
require("dump_object")
require("ee_visor")
require("ee_atmosphere")
require("ee_spawn")
require("ee_test")