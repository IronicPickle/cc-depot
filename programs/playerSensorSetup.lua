-- Deps
local StateManager = require("/lib/StateManager")

-- Config
local CONFIG = textutils.unserialiseJSON(arg[1])
local DIR = arg[2]

-- Peripherals
if not peripheral.find("monitor") then error("An attached monitor is required") end

local MONITOR = Monitor:new(peripheral.find("monitor"), {
    textScale=0.5
})

local MODEM = peripheral.find("modem")

-- Globals
local STATE_MANAGER = StateManager:new({
    dir=DIR,
    name="door",
    default={
        mode="closed"
    }
})

local function start()
    while true do
        os.sleep(1)
    end
end

start()