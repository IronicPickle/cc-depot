local Monitor = require("/cc_depot/lib/peripherals/Monitor")
local Window = require("/cc_depot/lib/Window")

if not peripheral.find("monitor") then error("An attached monitor is required") end
if not peripheral.find("modem") then error("An attached modem is required") end

local MONITOR = Monitor:new(peripheral.find("monitor"), {
    textScale=0.5
})

function start()
    MONITOR.output.clear()
    MONITOR:write("Test", {
        x=1,
        y=2,
        textColor=colors.white
    })


end

start()