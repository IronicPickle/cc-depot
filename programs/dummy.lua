local utils = require("/lib/utils")
local Monitor = require("/lib/peripherals/Monitor")

local function start()
    while true do
        os.sleep(1)
    end

    print("DUMMY TEST")
end

start()