-- Deps
local StateManager = require("/lib/StateManager")
local Monitor = require("/lib/peripherals/Monitor")
local utils = require("/lib/utils")

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
if not peripheral.find("modem") and CONFIG.role ~= "both" then error("An attached modem is required for '"..CONFIG.mode.."' mode.") end

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

local function outputToRedstone(rsState)
    if CONFIG.redstoneOutputSide == nil then return end

    rs.setAnalogOutput(CONFIG.redstoneOutputSide, rsState and 15 or 0)
end

local EMIT_FOR_SECONDS = -1

local function startOperation()
    local function resetLinger()
        if CONFIG.mode == "sense" then return end

        local isNewEmission = EMIT_FOR_SECONDS == -1
        if isNewEmission and SPEAKER then
            SPEAKER.playSound("block.lever.click", 3, 1.8)
        end
        print("| Resetting output linger.")
        EMIT_FOR_SECONDS = CONFIG.redstoneLingerDuration
    end

    local function broadcast()
        if not MODEM then return end

        MODEM.transmit(CONFIG.channel, CONFIG.channel, {
            type="/playerSensor/playersDetected"
        })
    end
    
    local function sense()
        if CONFIG.mode == "emit" then return end

        while true do
            for _, area in ipairs(STATE_MANAGER.state.areas) do
                local pos1 = utils.tableShallowClone(area[1])
                local pos2 = utils.tableShallowClone(area[2])

                for key, _ in pairs(pos1) do
                    if pos1[key] > pos2[key] then
                        pos1[key] = pos1[key] + 1
                    else
                        pos2[key] = pos2[key] + 1
                    end
                end

                local players = PLAYER_DETECTOR.getPlayersInCoords(pos1, pos2)
                if #players > 0 then
                    print("- Player(s) in area: "..textutils.serialiseJSON(players))
                    broadcast()
                    resetLinger()
                end
            end

            os.sleep(0.5)
        end
    end

    local function emit()
        if CONFIG.mode == "sense" then return end

        while true do
            if EMIT_FOR_SECONDS > 0 then
                EMIT_FOR_SECONDS = EMIT_FOR_SECONDS - 1
                outputToRedstone(true)
            elseif EMIT_FOR_SECONDS == 0 then
                EMIT_FOR_SECONDS = -1
                print("- Linger duration expired.")
                print("| Halting output.")
                if SPEAKER then
                    SPEAKER.playSound("block.lever.click", 3, 0.8)
                end
                outputToRedstone(false)
            end

            os.sleep(1)
        end
    end

    local function listen()
        if CONFIG.mode == "sense" then return end

        if not MODEM then return end

        MODEM.open(CONFIG.channel)

        while true do
            local event, _, _, _, body = os.pullEvent()

            if event == "modem_message" then
                if body.type == "/playerSensor/playersDetected" then
                    resetLinger()
                end
            end
        end
    end

    parallel.waitForAll(sense, emit, listen)
end

local function start()
    -- Allow for runner commands to print
    os.sleep(1)

    TERMINAL.output.clear()
    TERMINAL.output.setCursorPos(1, 1)

    if CONFIG.role == "both" or CONFIG.role == "sense" then
        local isSetupDone = STATE_MANAGER.state.areas ~= nil
        if not isSetupDone then
            startSetup()
        end
    end

    startOperation()

end

start()