-- Deps
local Monitor = require("/lib/peripherals/Monitor")

-- Config
local CONFIG = textutils.unserialiseJSON(arg[1])
local DIR = arg[2]

-- Peripherals
local TERMINAL = Monitor:new(term.current(), {
    textScale=0.5
})

local MODEM = peripheral.find("modem")

if not peripheral.find("modem") then error("An attached modem is required") end

local function startSetup()
    print("- Running setup")

    local currentPos = 1
    local areaCount = 0

    print("  - Setup now in progress.")

    while true do
        TERMINAL.output.clear()
        TERMINAL.output.setCursorPos(0, 0)
    
        print("\n- Area "..(areaCount + 1).." Setup:")
        print("\nHead to the "..(currentPos == 1 and "first" or "second").." corner.")
        print("\nEnter - Confirm position")
        print("Backspace - Finish setup")

        local event, key = os.pullEvent()

        if event == "key_up" then
            if key == keys.enter then
                MODEM.transmit(CONFIG.channel, CONFIG.channel, {
                    type="/playerSensor/setup/addArea/pos"
                })

                print("Registered corner "..currentPos.." of area "..(areaCount + 1))

                currentPos = currentPos + 1
                if currentPos > 2 then
                    areaCount = areaCount + 1
                    currentPos = 1
                end
            elseif key == keys.backspace then
                MODEM.transmit(CONFIG.channel, CONFIG.channel, {
                    type="/playerSensor/setup/done"
                })

                print("- Setup finished, return to the sensor.")
                break
            end
        end
    end



end

local function start()
    -- Allow for runner commands to print
    os.sleep(1)

    TERMINAL.output.clear()

    startSetup()
end

start()