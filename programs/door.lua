local Monitor = require("/lib/peripherals/Monitor")
local Window = require("/lib/peripherals/Window")


if not peripheral.isPresent("monitor") then error("An attached monitor is required") end
if not peripheral.isPresent("modem") then error("An attached modem is required") end

local MONITOR = Monitor:new(peripheral.find("monitor"))

function start()
    MONITOR.output.clear()
    MONITOR:write("Test", {
        x=1,
        y=2,
        textColor=colors.white
    })

end


start()