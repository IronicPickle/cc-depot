-- Deps
local StateManager = require("/lib/StateManager")
local Monitor = require("/lib/peripherals/Monitor")

-- Config
-- Config
local CONFIG = textutils.unserialiseJSON(arg[1])
local DIR = arg[2]

-- Peripherals
local TERMINAL = Monitor:new(term.current(), {
    textScale=0.5
})

local MODEM = peripheral.find("modem")
local SPEAKER = peripheral.find("speaker")
local PLAYER_DETECTOR = peripheral.find("playerDetector")

    if not peripheral.find("playerDetector") then error("An attached player detector is required for setup") end

-- Globals
local STATE_MANAGER = StateManager:new({
    dir=DIR,
    name="playerSensor",
    default={}
})

local function startSetup()
    print("- Running setup")

    if not peripheral.find("modem") then error("An attached modem is required for setup") end

    MODEM.open(CONFIG.setupChannel)

    print("- Install the Player Sensor Remote program on a pocket computer to continue...")

    local areas = {}
    local currentArea = {}

    while true do
        local event, _, _, _, body = os.pullEvent()

        if event == "modem_message" then
            if body.type == "/playerSensor/setup/addArea/pos" then
                local pos = PLAYER_DETECTOR.getPlayerPos(CONFIG.setupUsername)
                if not pos then goto continue end

                table.insert(currentArea, { x=pos.x, y=pos.y, z=pos.z })

                if #currentArea == 2 then
                    table.insert(areas, currentArea)
                    print("  - Registered area:")
                    print("  | "..currentArea[1].x.." / "..currentArea[1].y.." / "..currentArea[1].z)
                    print("  | "..currentArea[2].x.." / "..currentArea[2].y.." / "..currentArea[2].z)
                    currentArea = {}
                end
            elseif body.type == "/playerSensor/setup/done" then
                STATE_MANAGER:save({
                    areas=areas
                })
                print("- Setup done, registered "..#areas.." areas.\n")

                print("- Rebooting in 5 seconds...")
                os.sleep(5)

                os.reboot()
            end
        end

        ::continue::
    end



    
end

local function startOperation()

end

local function start()
    -- Allow for runner commands to print
    os.sleep(1)

    TERMINAL.output.clear()
    TERMINAL.output.setCursorPos(1, 1)

    if CONFIG.role == "both" or CONFIG.role == "sense" then
        local isSetupDone = STATE_MANAGER.areas ~= nil
        if not isSetupDone then
            startSetup()
        end
    end

    startOperation()

end

start()