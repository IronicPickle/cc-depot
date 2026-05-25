-- Deps
local StateManager = require("/lib/StateManager")
local Turtle = require("/lib/peripherals/Turtle")

-- Config
local CONFIG = textutils.unserialiseJSON(arg[1])
local DIR = arg[2]

-- Globals
local STATE_MANAGER = StateManager:new({
    dir=DIR,
    name="quarry"
})

local TURTLE = Turtle:new(
    StateManager:new(
        {
            dir=DIR,
            name="quarry-turtle"
        }
    ),
    {
        fuelInventorySide = "back",
        minimumFuelStock = 16,
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

local function nextAction()
    local anchorOffset = TURTLE:getStateValue("anchorOffset")

    local maxX = CONFIG.x - 1
    local maxY = CONFIG.y - 1
    local maxZ = CONFIG.z - 1

    local shouldStaggerX = anchorOffset.y % 2 ~= 0

    if anchorOffset.x < maxX and anchorOffset.y < maxY then
        if anchorOffset.x == 0 and shouldStaggerX then
            print(" -- Offsetting")
            TURTLE:faceRight()
            forwardAndScan(2)
        end

        if anchorOffset.z < maxZ then
            print("  - Digging shaft")
            TURTLE:faceForward()
            forwardAndScan(maxZ - anchorOffset.z)
        else
            print("  - Leaving shaft")
            TURTLE:faceForward()
            TURTLE:back(maxZ)

            local remainingX = maxX - anchorOffset.x

            if remainingX < 4 then
                print("  - Finishing level")
                TURTLE:faceRight()
                forwardAndScan(remainingX)
            elseif remainingX >= 4 then
                print("  - Moving to next shaft")
                TURTLE:faceRight()
                forwardAndScan(4)
            end
        end
    else
        print("  - Leaving level")
        TURTLE:faceLeft()
        TURTLE:forward(maxX)

        local remainingY = maxY - anchorOffset.y

        if remainingY >= 1 then
            print("  - Moving to next level")
            downAndScan(1)
        end
    end
end

-- Main
local function start()
  print("# Quarry program started")

  TURTLE:initialize()

  TURTLE:returnToAnchor()

  while true do
    nextAction()
  end
end

start()

