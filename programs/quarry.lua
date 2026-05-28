-- Deps
local StateManager = require("/lib/StateManager")
local Turtle = require("/lib/peripherals/Turtle")

-- Config
local CONFIG = textutils.unserialiseJSON(arg[1])
local DIR = arg[2]

-- Globals
local STATE_MANAGER = StateManager:new({
    dir=DIR,
    name="quarry",
    default={
        done=false
    }
})

local TURTLE = Turtle:new(
    StateManager:new(
        {
            dir=DIR,
            name="quarry-turtle"
        }
    ),
    {
        refuelThresholdPercent = CONFIG.refuelThresholdPercent,
        refuelAmountPercent = CONFIG.refuelAmountPercent,
        fuelInventorySide = CONFIG.fuelInventorySide,
        minimumFuelStock = CONFIG.minimumFuelStock,
        mainToolSlotSide = CONFIG.diggingToolSide
    }
)

local function scanAndMineSurroundings()
    local function isOre(blockInfo)
        return blockInfo.tags["c:ores"]
    end

    do
        local isBlock, blockInfo = turtle.inspect()

        if isBlock and isOre(blockInfo) then
            TURTLE:dig()
        end
    end

    do
        TURTLE:turnLeft()

        local isBlock, blockInfo = turtle.inspect()

        if isBlock and isOre(blockInfo) then
            TURTLE:dig()
        end
    end

    do
        TURTLE:turnAround()

        local isBlock, blockInfo = turtle.inspect()

        if isBlock and isOre(blockInfo) then
            TURTLE:dig()
        end
    end

    TURTLE:turnLeft()

    do
        local isBlock, blockInfo = turtle.inspectUp()

        if isBlock and isOre(blockInfo) then
            TURTLE:digUp()
        end
    end

    do
        local isBlock, blockInfo = turtle.inspectDown()

        if isBlock and isOre(blockInfo) then
            TURTLE:digDown()
        end
    end
end

local function forwardAndScan(distance)
    if distance == nil then distance = 1 end

    for i=1, distance, 1 do
        TURTLE:forward()
        scanAndMineSurroundings()
    end
end

local function downAndScan(distance)
    if distance == nil then distance = 1 end

    for i=1, distance, 1 do
        TURTLE:down()
        scanAndMineSurroundings()
    end
end

local function checkIsInventoryFull()
    local fullSlots = 0

    for slot = 1, 16, 1 do
        if slot == TURTLE.options.fuelSlot then goto continue end

        local itemCount = turtle.getItemCount(slot)
        if itemCount > 0 then
            fullSlots = fullSlots + 1
        end

        ::continue::
    end

    return fullSlots == 15
end


function storeInventory()
    if not TURTLE:isAtAnchor() then
        TURTLE:printLines({
            "Returning to anchor to store inventory"
        })
        TURTLE:returnToAnchor(false)
    end
        
    local currentOrientation = TURTLE:getStateValue("orientation")

    TURTLE:face(CONFIG.storeInventorySide)

    local success, error
    while not success do
        if error then
            TURTLE:printLines({
                "Inventory store failed: "..error,
                "Retrying in 5 seconds..."
            })
            sleep(5)
        end

        for slot = 1, 16, 1 do
            if slot == TURTLE.options.fuelSlot then goto continue end

            turtle.select(slot)
            turtle.drop(64)

            ::continue::
        end

        if checkIsInventoryFull() then
            success = false
            error = "Couldn't empty inventory"
        else
            success = true
            error = nil
        end


    end

    TURTLE:face(currentOrientation)

    TURTLE:resumePosition(true)
end

local function nextAction()
    local anchorOffset = TURTLE:getStateValue("anchorOffset")

    local maxX = CONFIG.x - 1
    local maxY = CONFIG.y - 1
    local maxZ = CONFIG.z - 1

    local shouldStaggerX = anchorOffset.y % 2 ~= 0

    if checkIsInventoryFull() then
        storeInventory()
    end

    local prettyLevel = (0 - anchorOffset.y) + 1
    local currentLevelLine = "<#> Current Level: "..prettyLevel

    if anchorOffset.z < maxZ then
        if shouldStaggerX and anchorOffset.x % 4 == 2 then
            -- Dig shaft
            TURTLE:printLines({
                currentLevelLine,
                "<-> Digging shaft"
            })
            TURTLE:faceForward()
            forwardAndScan()
        elseif not shouldStaggerX and anchorOffset.x % 4 == 0 then
            -- Dig shaft
            TURTLE:printLines({
                currentLevelLine,
                "<-> Digging shaft"
            })
            TURTLE:faceForward()
            forwardAndScan()
        elseif anchorOffset.z == 0 then

            if anchorOffset.x < maxX then
                -- Move to next shaft
                TURTLE:printLines({
                    currentLevelLine,
                    "<-> Moving to next shaft"
                })
                TURTLE:faceRight()
                forwardAndScan()
            else
                -- Leave level
                TURTLE:printLines({
                    currentLevelLine,
                    "<-> Leaving level: "..prettyLevel
                })
                TURTLE:faceRight()
                TURTLE:back(maxX)

                if (0 - anchorOffset.y) < maxY then
                    -- Move to next level
                    TURTLE:printLines({
                        currentLevelLine,
                        "<-> Moving to next level: "..(prettyLevel + 1)
                    })
                    downAndScan()
                else
                    -- Leave mine
                    TURTLE:printLines({
                        currentLevelLine,
                        "<-> Leaving mine"
                    })
                    TURTLE:faceForward()
                    TURTLE:up(maxY)

                    return true
                end
            end
        end
    else
        -- Leave shaft
        TURTLE:printLines({
            currentLevelLine,
            "<-> Leaving shaft"
        })
        TURTLE:faceForward()
        TURTLE:back(maxZ)

        -- Move to next shaft
        TURTLE:printLines({
            currentLevelLine,
            "<-> Moving to next shaft"
        })
        TURTLE:faceRight()
        forwardAndScan()
    end
end

-- Main
local function start()
    TURTLE:initialize()
    if STATE_MANAGER.state.done then
        TURTLE:printLines({
            "# This quarry has previously completed"
        })
    else
        TURTLE:printLines({
            "# Quarry program started"
        })

        while not nextAction() do end

        storeInventory()

        TURTLE:printLines({
            "# Quarry complete"
        })

        STATE_MANAGER:save({
            done=true
        })
    end

    while true do sleep(5) end
end

start()

