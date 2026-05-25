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
        minimumFuelStock = 32,
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

        if anchorOffset.z < maxZ then
            if shouldStaggerX and anchorOffset.x % 4 == 2 then
                -- Dig shaft
                print("<-> Digging shaft")
                TURTLE:faceForward()
                forwardAndScan()
            elseif not shouldStaggerX and anchorOffset.x % 4 == 0 then
                -- Dig shaft
                print("<-> Digging shaft")
                TURTLE:faceForward()
                forwardAndScan()
            elseif anchorOffset.z == 0 then

                if anchorOffset.x < maxX then
                    -- Move to next shaft
                    print("<-> Moving to next shaft")
                    TURTLE:faceRight()
                    forwardAndScan()
                else
                    -- Leave level
                    print("<-> Leaving level: "..(0 - anchorOffset.y))
                    TURTLE:faceRight()
                    TURTLE:back(maxX)

                    if (0 - anchorOffset.y) < maxY then
                        -- Move to next level
                        print("<-> Moving to next level: "..((0 - anchorOffset.y) + 1))
                        downAndScan()
                    else
                        -- Leave mine
                        print("<-> Leaving mine")
                        TURTLE:faceForward()
                        TURTLE:up(maxY)

                        print("# Quarry complete")
                        return true
                    end
                end
            end
        else
            -- Leave shaft
            print("<-> Leaving shaft")
            TURTLE:faceForward()
            TURTLE:back(maxZ)

            -- Move to next shaft
            print("<-> Moving to next shaft")
            TURTLE:faceRight()
            forwardAndScan()
        end
end

-- Main
local function start()
  print("# Quarry program started")

  TURTLE:initialize()
  TURTLE:resumePosition()

  while not nextAction() do end

  while true do sleep(5) end
end

start()

