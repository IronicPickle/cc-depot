-- Deps
local Monitor = require("/lib/peripherals/Monitor")
local Window = require("/lib/Window")
local StateManager = require("/lib/StateManager")
local network = require("/lib/network")
local utils = require("/lib/utils")

-- Config
local CONFIG = textutils.unserialiseJSON(arg[1])
local DIR = arg[2]

-- Peripherals
if not peripheral.find("monitor") then error("An attached monitor is required") end

local MONITOR = Monitor:new(peripheral.find("monitor"), {
    textScale=0.5
})

local MODEM = peripheral.find("modem")
local SPEAKER = peripheral.find("speaker")

-- Globals
local STATE_MANAGER = StateManager:new({
    dir=DIR,
    name="elevator",
    default={
        floor=1
    }
})

-- Windows
local HEADER_HEIGHT = CONFIG.role == "multi" and 6 or 4
local FOOTER_HEIGHT = CONFIG.role == "multi" and 3 or 0
local BODY_HEIGHT = MONITOR.output.height - HEADER_HEIGHT - FOOTER_HEIGHT

local HEADER = Window:new(MONITOR.output, {
    x=1,
    y=1,
    height=HEADER_HEIGHT
})
local BODY = Window:new(MONITOR.output, {
    x=1,
    y=HEADER_HEIGHT + 1,
    height=BODY_HEIGHT
})
local FOOTER = Window:new(MONITOR.output, {
    x=1,
    y=HEADER_HEIGHT + BODY_HEIGHT + 1,
    height=FOOTER_HEIGHT
})

-- Globals
local FLOORS = {}
local IS_MOVING = false
local DIRECTION = 0

-- Main
    
    
local function drawFloors()
    if(STATE_MANAGER.state.floor > #FLOORS) then
        STATE_MANAGER:save({
            floor=1
        })
    end
    

    if CONFIG.role == "multi" then
        BODY:write("Floor: " .. FLOORS[STATE_MANAGER.state.floor].floorName, {
            x=2,
            y=2,
            align="right"
        })
        BODY:write("# Floors", {
            x=2,
            y=2,
            align="left"
        })
        
        for i, floor in ipairs(FLOORS) do
            local y = 4 + i
            if(i == STATE_MANAGER.state.floor) then
                BODY.output.setBackgroundColor(colors.blue)
                BODY:drawBox({
                    x=1,
                    y=y,
                    width=BODY.output.width,
                    height=1,
                    filled=true,
                    bgColor=colors.blue
                })
            end
            BODY:write(" > " .. floor.floorName .. " ", {
                x=2,
                y=y,
                align="left"
            })
            BODY.output.setBackgroundColor(colors.cyan)
        end
    else
        BODY:write(CONFIG.floorName, {
            x=0,
            y=2,
            align="center"
        })

        local _, floorIndex = utils.findInTable(FLOORS, function (floor)
            return CONFIG.floorNumber == floor.floorNumber    
        end)
        local isAtThisLevel = floorIndex == STATE_MANAGER.state.floor
        if isAtThisLevel then
            BODY:write("At this level", {
                x=0,
                y=5,
                align="center"
            })
        else
            BODY:write("Click to call", {
                x=0,
                y=5,
                align="center"
            })
        end
    end
end

local function awaitFinish()
    os.sleep(1)
    while(true) do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()
        
        local isRedstone = (event == "redstone")
        local isTargetFloor = CONFIG.floorNumber == FLOORS[STATE_MANAGER.state.floor].floorNumber
        
        local isModemMessage = (event == "modem_message")

        if(isRedstone and isTargetFloor) then
            if MODEM then
                MODEM.transmit(CONFIG.channel, CONFIG.channel,
                    {
                        type = "/elevator/floorChanged"
                    }
                )
                end
            return
        elseif(isModemMessage) then
            local body = p4
            if(body.type == "/elevator/floorChanged") then
                return
            end
        end
        
    end
end

local function drawMoving()
    local dirStr = "\\/"
    if(DIRECTION > 0) then
        dirStr = "/\\"
    end

    local floor = FLOORS[StateManager.state.floor]
            
    if CONFIG.role == "multi" then
        local i = 1
        local max = BODY.output.height - 4

        while true do
            i = i + 1
            if(i > max) then i = 1 end
            BODY.output.clear()
            
            BODY:write("Moving to: " .. floor.floorName, {
                x=0,
                y=2,
                align="center"
            })
            
            for ii = 1, 5, 1 do
                local y = i + ii - 1
                if(y > max) then y = y % max end
                if(DIRECTION > 0) then
                    y = (y - max - 1) * -1
                end
                
                BODY:write(dirStr, {
                    x=0,
                    y=y + 3,
                    align="center"
                })
            end
            
            os.sleep(0.1)
        end
    else

        local i = 1
        local max = BODY.output.height - 1

        while true do
            i = i + 1
            if(i > max) then i = 1 end
            BODY.output.clear()

            local y = i

            if DIRECTION > 0 then
                y = (y - max - 1) * -1
            end

            BODY:write("Moving to", {
                x=1,
                y=2,
                align="left"
            })
            BODY:write(floor.floorName, {
                x=1,
                y=5,
                align="left"
            })

            BODY:write(dirStr, {
                x=1,
                y=y + 1,
                align="right"
            })
            
            os.sleep(0.2)
        end
    end
end


local function drawHeader()
    HEADER:fillBackground({
        bgColor=colors.blue
    })

    HEADER:drawBox({
        x=1,
        y=HEADER.output.height,
        width=HEADER.output.width,
        height=HEADER.output.height,
        filled=true,
        bgColor=colors.white
    })

        HEADER:write("Elevator", {
            x=0,
            y=2,
            align="center"
        })

    if CONFIG.role == "multi" then
        HEADER:write("This Floor: "..CONFIG.floorName, {
            x=0,
            y=4,
            align="center"
        })
    end
end

local function drawBody()
    BODY:fillBackground({
        bgColor=colors.cyan
    })

    if(IS_MOVING) then
        parallel.waitForAny(
            drawMoving, awaitFinish,
            function() os.sleep(120) end
        )
        IS_MOVING = false
        drawBody()
    else
        drawFloors()
    end
end

local function drawFooter()
    FOOTER:fillBackground({
        bgColor=colors.blue
    })
    
    FOOTER:drawBox({
        x=1,
        y=1,
        width=FOOTER.output.width,
        height=1,
        filled=true,
        bgColor=colors.white

    })

    if CONFIG.role == "multi" then
        FOOTER:write("Select a floor", {
            x=2,
            y=3,
            align="left"
        })
        FOOTER:write("Channel: "..CONFIG.channel, {
            x=2,
            y=3,
            align="right"
        })
    end
end


local function sendSignal(targetFloorNum)
    if CONFIG.destinationRedstoneOutputSide then
        redstone.setOutput(
            CONFIG.destinationRedstoneOutputSide, CONFIG.floorNumber ~= targetFloorNum
        )
    end
    if CONFIG.directionRedstoneOutputSide then
        redstone.setOutput(
            CONFIG.directionRedstoneOutputSide, DIRECTION < 0
        )
    end
    if CONFIG.movingRedstoneOutputSide then
        redstone.setOutput(
            CONFIG.movingRedstoneOutputSide, IS_MOVING
        )
    end
end

local function moveTo(floorIndex)
    local floor = FLOORS[STATE_MANAGER.state.floor]
    DIRECTION = STATE_MANAGER.state.floor - floorIndex
    STATE_MANAGER:save({
        floor=floorIndex
    })
    IS_MOVING = true
    
    if(SPEAKER) then
        SPEAKER.playSound(
            "minecraft:entity.experience_orb.pickup",
            1, 0.5
        )
    end
    
    sendSignal(floor.floorNumber)
    
    drawBody()
    
    sendSignal(floor.floorNumber)
    
    if(SPEAKER) then
        SPEAKER.playSound(
            "minecraft:entity.player.levelup",
            1, 0.5
        )
    end
    
    await()
end

function await()
    while true do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()
        
        local isTouch = (event == "monitor_touch")
        
        local isModemMessage = (event == "modem_message")
        
        if(isTouch) then
            if CONFIG.role == "multi" then
                local x = p2
                local y = p3 - HEADER.output.height
                
                local floorIndex = y - 4
                local floor = FLOORS[floorIndex]
                if(floor and (floorIndex) ~= STATE_MANAGER.state.floor) then
                    if MODEM then
                        MODEM.transmit(CONFIG.channel, CONFIG.channel,
                            {
                                type = "/elevator/floorChange",
                                floorIndex = floorIndex
                            }
                        )
                    end
                    moveTo(floorIndex)
                    break
                end
            else
                local _, floorIndex = utils.findInTable(FLOORS, function (floor)
                    return CONFIG.floorNumber == floor.floorNumber            
                end)

                if floorIndex == STATE_MANAGER.state.floor then
                    goto continue
                end

                if MODEM then
                    MODEM.transmit(CONFIG.channel, CONFIG.channel,
                        {
                            type = "/elevator/floorChange",
                            floorIndex = floorIndex
                        }
                    )
                end
                moveTo(floorIndex)
            end
        elseif(isModemMessage) then
            local body = p4
            if(body.type == "/elevator/floorChange") then
                moveTo(body.floorIndex)
                break
            end
        end

        ::continue::
    end
end

local function start()
    print("# Program Started")
    
    local deviceData = {
        floorNumber= CONFIG.floorNumber,
        floorName = CONFIG.floorName,
    }

    FLOORS = { deviceData }

    local joinOrCreate = function()
        network.joinOrCreate(CONFIG.channel, CONFIG.isHost, deviceData,
            function(devices)
                FLOORS = utils.filterTable(devices, function(device, newDevices)
                    for _,newDevice in ipairs(newDevices) do
                        if newDevice.floorNumber == device.floorNumber then return false end
                    end
                    return true
                end)
                table.sort(FLOORS,
                    function(a, b) return a.floorNumber > b.floorNumber end
                )
                drawHeader()
                if CONFIG.role == "multi" then drawFooter() end
                drawBody()
            end
        )
    end

    parallel.waitForAny(joinOrCreate, await)
end

start()