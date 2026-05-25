-- Deps
local utils = require("/lib/utils")
local Monitor = require("/lib/peripherals/Monitor")

-- Term
local TERM = Monitor:new(term.current(), {
    textScale=0.5
})

local Turtle = {}

local DEFAULT_STATE = {
    anchorOffset = {
        x = 0,
        z = 0,
        y = 0
    },
    previousAnchorOffset = nil,
    movingTo = {
        x = nil,
        z = nil,
        y = nil
    },
    orientation = "forward"
}

local DEFAULT_OPTIONS = {
    -- Which inventory slot to store fuel in
    fuelSlot = 16,
    -- The minimum fuel percent the turtle will operate at before refueling
    refuelThresholdPercent = 14.99,
    -- The target fuel percent the turtle will attempt to reach when refueling
    refuelAmountPercent = 15,
    -- Which side of the turtle to use for accessing fuel
    fuelInventorySide = nil,
    -- How many fuel items should the turtle require as stock
    minimumFuelStock = nil,
    -- Whether the turtle should clear blocks when movement it obstructed
    clearObstructions = true,
    -- The default tool slot side to use when clearing blocks
    mainToolSlotSide = "left"
}

function Turtle:new(stateManager, options)
    if not options then
        options = DEFAULT_OPTIONS
    end

    if options.fuelSlot == nil then options.fuelSlot = DEFAULT_OPTIONS.fuelSlot end
    if options.refuelThresholdPercent == nil then options.refuelThresholdPercent = DEFAULT_OPTIONS.refuelThresholdPercent end
    if options.refuelAmountPercent == nil then options.refuelAmountPercent = DEFAULT_OPTIONS.refuelAmountPercent end
    if options.fuelInventorySide == nil then options.fuelInventorySide = DEFAULT_OPTIONS.fuelInventorySide end
    if options.minimumFuelStock == nil then options.minimumFuelStock = DEFAULT_OPTIONS.minimumFuelStock end
    if options.clearObstructions == nil then options.clearObstructions = DEFAULT_OPTIONS.clearObstructions end
    if options.mainToolSlotSide == nil then options.mainToolSlotSide = DEFAULT_OPTIONS.mainToolSlotSide end

    local o = {
        stateManager = stateManager,
        options = options
    }

    stateManager.default = DEFAULT_STATE
    if not stateManager.state then
        stateManager:save(DEFAULT_STATE)
    end

    setmetatable(o, self)
    self.__index = self

    return o
end

function formatCoords(coords)
    if not coords then coords = {} end

    return (coords.x or 0)..", "..(coords.y or 0)..", "..(coords.z or 0)
end

function Turtle:initialize()
    sleep(1)

    print("")
    print("- Initializing turtle...")

    self:drawHeader()

    self:resumePreviousMovement()
end

function Turtle:setStateValue(key, value)
    local newState = utils.tableShallowClone(self.stateManager.state)

    newState[key] = value

    self.stateManager:save(newState)
end

function Turtle:getStateValue(key)
    return self.stateManager.state[key]
end

function Turtle:resumePreviousMovement()
    local movingTo = utils.tableShallowClone(self:getStateValue("movingTo"))

    print("- Resuming previous movement ".."("..formatCoords(movingTo)..")")

    self:drawHeader()

    if movingTo.x ~= nil or movingTo.y ~= nil or movingTo.z ~= nil then
        self:moveTo({
            x = movingTo.x or 0,
            y = movingTo.y or 0,
            z = movingTo.z or 0
        })
    end
end

function Turtle:resetAnchor()
    self:setStateValue("anchorOffset", {
        x = 0,
        z = 0,
        y = 0
    })
    self:setStateValue("previousAnchorOffset", nil)
end

function Turtle:moveTo(coords, noRefuelAttempt)
    -- Save target destination to state
    local movingTo = utils.tableShallowClone(self:getStateValue(coords) or {})

    if coords.x ~= nil then
        movingTo.x = coords.x
    end
    if coords.y ~= nil then
        movingTo.y = coords.y
    end
    if coords.z ~= nil then
        movingTo.z = coords.z
    end

    self:setStateValue("movingTo", utils.tableShallowClone(movingTo))

    -- Move to anchor z
    if coords.z > 0 then
        self:faceForward()
        self:forward(coords.z, noRefuelAttempt)
    elseif coords.z < 0 then
        self:faceBack()
        self:forward(0 - coords.z, noRefuelAttempt)
    end

    -- Move to anchor x
    if coords.x > 0 then
        self:faceRight()
        self:forward(coords.x, noRefuelAttempt)
    elseif coords.x < 0 then
        self:faceLeft()
        self:forward(0 - coords.x, noRefuelAttempt)
    end

    -- Move to anchor y
    if coords.y > 0 then
        self:up(coords.y, noRefuelAttempt)
    elseif coords.y < 0 then
        self:down(0 - coords.y, noRefuelAttempt)
    end
end

function Turtle:isAtAnchor()
    local anchorOffset = self:getStateValue("anchorOffset")

    return anchorOffset.x == 0 and anchorOffset.y == 0 and anchorOffset.z == 0
end

function Turtle:returnToAnchor(noRefuelAttempt)
    if not self:isAtAnchor() then
        -- Save current anchor to previousAnchorOffset
        local anchorOffset = utils.tableShallowClone(self:getStateValue("anchorOffset"))
        self:setStateValue("previousAnchorOffset", anchorOffset)

        print("- Returning to anchor ".."("..formatCoords(anchorOffset)..")")

        self:drawHeader()

        self:moveTo({
            x = 0 - anchorOffset.x,
            y = 0 - anchorOffset.y,
            z = 0 - anchorOffset.z
        }, noRefuelAttempt)
    end

    -- Reset position
    self:faceForward()
end

function Turtle:resumePosition()
    if not self:getStateValue("previousAnchorOffset") then return end

    -- Retain and reset previousAnchorOffset
    local previousAnchorOffset = utils.tableShallowClone(self:getStateValue("previousAnchorOffset"))
    self:setStateValue("previousAnchorOffset", nil)

    print("- Resuming position ".."("..formatCoords(previousAnchorOffset)..")")

    self:drawHeader()

    self:moveTo({
        x = previousAnchorOffset.x,
        y = previousAnchorOffset.y,
        z = previousAnchorOffset.z
    })

    -- Reset position
    self:faceForward()
end

function Turtle:incrementAnchor(increments)
    local anchorOffset = utils.tableShallowClone(self:getStateValue("anchorOffset"))

    if increments.x ~= nil then
        anchorOffset.x = anchorOffset.x + increments.x
    end

    if increments.z ~= nil then
        anchorOffset.z = anchorOffset.z + increments.z
    end

    if increments.y ~= nil then
        anchorOffset.y = anchorOffset.y + increments.y
    end

    self:setStateValue("anchorOffset", anchorOffset)
end

function Turtle:incrementAnchorX(increment)
    self:incrementAnchor({
        x=increment
    })
end

function Turtle:incrementAnchorZ(increment)
    self:incrementAnchor({
        z=increment
    })
end

function Turtle:incrementAnchorY(increment)
    self:incrementAnchor({
        y=increment
    })
end

function Turtle:drawHeader()
    local width = TERM.output.width

    local fuelLevel = turtle.getFuelLevel()
    local maxFuelLevel = turtle.getFuelLimit()

    if fuelLevel == "unlimited" then
        fuelLevel = maxFuelLevel
    end

    local currentFuelPercent = fuelLevel / (maxFuelLevel / 100)

    local prefix = "Fuel "
    local suffix = " "..string.format("%.2f", (math.floor(currentFuelPercent * 100) / 100)).."%"

    local maxFuelCharacters = width - 2 - prefix:len() - suffix:len()
    local currentFuelCharacters = math.ceil(((maxFuelCharacters / 100) * currentFuelPercent))

    local currentFuelString = string.rep("-", currentFuelCharacters)
    local emptyFuelString = string.rep(" ", maxFuelCharacters - currentFuelCharacters)

    local fuelString = prefix.."["..currentFuelString..emptyFuelString.."]"..suffix

    TERM:drawBox({
        x=1,
        y=1,
        width=width,
        height=5,
        bgColor=colors.blue,
        filled=true
    })

    TERM:write(fuelString,
        {
            x=0,
            y=1,
            textColor=colors.white,
            bgColor=colors.blue
        }
    )

    TERM:write("Anchor: "..formatCoords(self.stateManager.state.anchorOffset),
        {
            x=0,
            y=2,
            textColor=colors.white,
            bgColor=colors.blue
        }
    )

    TERM:write("Previous Anchor: "..formatCoords(self.stateManager.state.previousAnchorOffset),
        {
            x=0,
            y=3,
            textColor=colors.white,
            bgColor=colors.blue
        }
    )

    TERM:write("Moving to: "..formatCoords(self.stateManager.state.movingTo),
        {
            x=0,
            y=4,
            textColor=colors.white,
            bgColor=colors.blue
        }
    )

    TERM:write("Orientation: "..self.stateManager.state.orientation,
        {
            x=0,
            y=5,
            textColor=colors.white,
            bgColor=colors.blue
        }
    )

    TERM.output.setCursorPos(0, TERM.output.height)
end

function Turtle:attemptRefuel()
    local fuelLevel = turtle.getFuelLevel()
    local maxFuelLevel = turtle.getFuelLimit()

    if fuelLevel == "unlimited" then return end

    local currentFuelPercent = fuelLevel / (maxFuelLevel / 100)
    local needsRefueling = currentFuelPercent < self.options.refuelThresholdPercent

    local didAnchorReturn = false

    self:drawHeader()

    if needsRefueling then
        print("  - Attempting refuel...")
        print("  - Current fuel level: "..currentFuelPercent.."%")
        print("  - Target fuel level: "..self.options.refuelAmountPercent.."%")

        self:drawHeader()

        local selectedSlot = turtle.getSelectedSlot()
        turtle.select(self.options.fuelSlot)

        while currentFuelPercent < self.options.refuelAmountPercent do
            local success, error

            while not success do
                if error then
                    print("  - Refuel failed: "..error)
                    print("  - Current fuel level: "..currentFuelPercent.."%")
                    

                    self:drawHeader()

                    if self.options.fuelInventorySide and self.options.minimumFuelStock then
                        if not self:isAtAnchor() then
                            print("  - Returning to anchor to restock fuel...")
                            didAnchorReturn = true
                            self:returnToAnchor(true)
                        end
                        self:attemptRestock()
                    else
                        print("  - Retrying in 5 seconds...")
                        sleep(5)
                    end
                end

                success, error = turtle.refuel(4)

                print("  - Refueled to: "..currentFuelPercent.."%")
                self:drawHeader()
            end

            fuelLevel = turtle.getFuelLevel()
            currentFuelPercent = fuelLevel / (maxFuelLevel / 100)
        end

        turtle.select(selectedSlot)
    end

    if didAnchorReturn then
        self:resumePosition()
    end
end

function Turtle:attemptRestock()
    if not self:isAtAnchor() then return end
        
    if self.options.fuelInventorySide == nil or self.options.minimumFuelStock == nil then return end

    if self.options.fuelInventorySide == "forward" then
        self:faceForward()
    elseif self.options.fuelInventorySide == "left" then
        self:faceLeft()
    elseif self.options.fuelInventorySide == "right" then
        self:right()
    elseif self.options.fuelInventorySide == "back" then
        self:faceBack()
    end

    local fuelItemCount = turtle.getItemCount(self.options.fuelSlot)

    if fuelItemCount < self.options.minimumFuelStock then
        print("  - Attempting restock")
        print("  - Current stock count: "..fuelItemCount)
        print("  - Target stock count: "..self.options.minimumFuelStock)

        self:drawHeader()

        local selectedSlot = turtle.getSelectedSlot()
        turtle.select(self.options.fuelSlot)

        while fuelItemCount < self.options.minimumFuelStock do
            local success, error

            while not success do
                if error then
                    print("  - Could not restock fuel: "..error)
                    print("  - Current stock count: "..fuelItemCount)
                    print("  - Retrying in 5 seconds...")

                    self:drawHeader()

                    sleep(5)
                end

                if self.options.fuelInventorySide == "up" then
                    success, error = turtle.suckUp(4)
                elseif self.options.fuelInventorySide == "down" then
                    success, error = turtle.suckDown(4)
                else
                    success, error = turtle.suck(4)
                end
            end

            fuelItemCount = turtle.getItemCount(self.options.fuelSlot)

            print("  - Restocked to: "..fuelItemCount)

            self:drawHeader()
        end

        turtle.select(selectedSlot)
    end
end

function Turtle:turnRight(turns)
    if turns == nil then turns = 1 end

    for _=1, turns, 1 do
        local orientation = self:getStateValue("orientation")
        
        -- State update
        if orientation == "forward" then
            orientation = "right"
        elseif orientation == "right" then
            orientation = "back"
        elseif orientation == "back" then
            orientation = "left"
        elseif orientation == "left" then
            orientation = "forward"
        end

        self:setStateValue("orientation", orientation)

        -- Turtle action
        turtle.turnRight()

        self:drawHeader()
    end
end

function Turtle:turnLeft(turns)
    if turns == nil then turns = 1 end

    for _=1, turns, 1 do
        local orientation = self:getStateValue("orientation")

        -- State update
        if orientation == "forward" then
            orientation = "left"
        elseif orientation == "left" then
            orientation = "back"
        elseif orientation == "back" then
            orientation = "right"
        elseif orientation == "right" then
            orientation = "forward"
        end

        self:setStateValue("orientation", orientation)

        -- Turtle action
        turtle.turnLeft()

        self:drawHeader()
    end
end

function Turtle:turnAround()
    self:turnLeft(2)
end

function Turtle:faceForward()
    local orientation = self:getStateValue("orientation")

    if orientation == "left" then
        self:turnRight()
    elseif orientation == "right" then
        self:turnLeft()
    elseif orientation == "back" then
        self:turnAround()
    end
end

function Turtle:faceRight()
    local orientation = self:getStateValue("orientation")

    if orientation == "forward" then
        self:turnRight()
    elseif orientation == "left" then
        self:turnAround()
    elseif orientation == "back" then
        self:turnLeft()
    end
end

function Turtle:faceLeft()
    local orientation = self:getStateValue("orientation")

    if orientation == "forward" then
        self:turnLeft()
    elseif orientation == "right" then
        self:turnAround()
    elseif orientation == "back" then
        self:turnRight()
    end
end

function Turtle:faceBack()
    local orientation = self:getStateValue("orientation")

    if orientation == "forward" then
        self:turnAround()
    elseif orientation == "right" then
        self:turnRight()
    elseif orientation == "left" then
        self:turnLeft()
    end
end

function Turtle:forward(distance, noRefuelAttempt)
    if distance == nil then distance = 1 end

    local orientation = self:getStateValue("orientation")
    local movingTo = utils.tableShallowClone(self:getStateValue("movingTo"))

    if orientation == "forward" then
        movingTo.z = distance
    elseif orientation == "back" then
        movingTo.z = -distance
    elseif orientation == "right" then
        movingTo.x = distance
    elseif orientation == "left" then
        movingTo.x = -distance
    end

    self:setStateValue("movingTo", utils.tableShallowClone(movingTo))

    local function updateState(increment)
        -- State update
        if orientation == "forward" then
            self:incrementAnchorZ(increment)
            movingTo.z = movingTo.z - increment
        elseif orientation == "back" then
            self:incrementAnchorZ(-increment)
            movingTo.z = movingTo.z + increment
        elseif orientation == "right" then
            self:incrementAnchorX(increment)
            movingTo.x = movingTo.x - increment
        elseif orientation == "left" then
            self:incrementAnchorX(-increment)
            movingTo.x = movingTo.x + increment
        end

        self:setStateValue("movingTo", utils.tableShallowClone(movingTo))
    end

    for _=1, distance, 1 do
        -- Turtle action
        local success, error
        while not success do
            if error then
                updateState(-1)

                if error == "Movement obstructed" and self.options.clearObstructions then
                    self:dig(nil, noRefuelAttempt)
                else
                    print("  - Movement forward failed: "..error)
                    print("  - Retrying in 5 seconds...")

                    sleep(5)
                end

                self:drawHeader()
            end


            if not noRefuelAttempt then self:attemptRefuel() end

            updateState(1)
            success, error = turtle.forward()
        end

        self:drawHeader()
    end

    if orientation == "forward" then
        movingTo.z = nil
    elseif orientation == "back" then
        movingTo.z = nil
    elseif orientation == "right" then
        movingTo.x = nil
    elseif orientation == "left" then
        movingTo.x = nil
    end

    self:setStateValue("movingTo", utils.tableShallowClone(movingTo))
end

function Turtle:back(distance, noRefuelAttempt)
    if distance == nil then distance = 1 end

    local orientation = self:getStateValue("orientation")
    local movingTo = utils.tableShallowClone(self:getStateValue("movingTo"))

    if orientation == "forward" then
        movingTo.z = -distance
    elseif orientation == "back" then
        movingTo.z = distance
    elseif orientation == "right" then
        movingTo.x = -distance
    elseif orientation == "left" then
        movingTo.x = distance
    end

    self:setStateValue("movingTo", utils.tableShallowClone(movingTo))

    local function updateState(increment)
        -- State update
        if orientation == "forward" then
            self:incrementAnchorZ(-increment)
            movingTo.z = movingTo.z + increment
        elseif orientation == "back" then
            self:incrementAnchorZ(increment)
            movingTo.z = movingTo.z - increment
        elseif orientation == "right" then
            self:incrementAnchorX(-increment)
            movingTo.x = movingTo.x + increment
        elseif orientation == "left" then
            self:incrementAnchorX(increment)
            movingTo.x = movingTo.x - increment
        end

        self:setStateValue("movingTo", utils.tableShallowClone(movingTo))
    end

    for _=1, distance, 1 do
        -- Turtle action
        local success, error
        while not success do
            if error then
                updateState(-1)

                if error == "Movement obstructed" and self.options.clearObstructions then
                    self:turnAround()
                    self:dig(nil, noRefuelAttempt)
                    self:turnAround()
                else
                    print("  - Movement back failed: "..error)
                    print("  - Retrying in 5 seconds...")

                    sleep(5)
                end

                self:drawHeader()
            end


            if not noRefuelAttempt then self:attemptRefuel() end

            updateState(1)
            success, error = turtle.back()
        end

        self:drawHeader()
    end

    if orientation == "forward" then
        movingTo.z = nil
    elseif orientation == "back" then
        movingTo.z = nil
    elseif orientation == "right" then
        movingTo.x = nil
    elseif orientation == "left" then
        movingTo.x = nil
    end

    self:setStateValue("movingTo", utils.tableShallowClone(movingTo))

    self:drawHeader()
end

function Turtle:up(distance, noRefuelAttempt)
    if distance == nil then distance = 1 end

    local movingTo = utils.tableShallowClone(self:getStateValue("movingTo"))

    movingTo.y = distance

    self:setStateValue("movingTo", utils.tableShallowClone(movingTo))

    local function updateState(increment)
        -- State update
        self:incrementAnchorY(increment)
        movingTo.y = movingTo.y - increment

        self:setStateValue("movingTo", utils.tableShallowClone(movingTo))
    end

    for _=1, distance, 1 do
        -- Turtle action
        local success, error
        while not success do
            if error then
                updateState(-1)

                if error == "Movement obstructed" and self.options.clearObstructions then
                    self:digUp(nil, noRefuelAttempt)
                else
                    print("  - Movement up failed: "..error)
                    print("  - Retrying in 5 seconds...")

                    sleep(5)
                end

                self:drawHeader()
            end

            if not noRefuelAttempt then self:attemptRefuel() end

            updateState(1)
            success, error = turtle.up()
        end

        self:drawHeader()
    end

    movingTo.y = nil

    self:setStateValue("movingTo", utils.tableShallowClone(movingTo))
end

function Turtle:down(distance, noRefuelAttempt)
    if distance == nil then distance = 1 end

    local movingTo = utils.tableShallowClone(self:getStateValue("movingTo"))

    movingTo.y = -distance

    self:setStateValue("movingTo", utils.tableShallowClone(movingTo))

    local function updateState(increment)
        -- State update
        self:incrementAnchorY(-increment)
        movingTo.y = movingTo.y + increment

        self:setStateValue("movingTo", utils.tableShallowClone(movingTo))
    end

    for _=1, distance, 1 do
        -- Turtle action
        local success, error
        while not success do
            if error then
                updateState(-1)

                if error == "Movement obstructed" and self.options.clearObstructions then
                    self:digDown(nil, noRefuelAttempt)
                else
                    print("  - Movement down failed: "..error)
                    print("  - Retrying in 5 seconds...")

                    sleep(5)
                end

                self:drawHeader()
            end

            if not noRefuelAttempt then self:attemptRefuel() end

            updateState(1)
            success, error = turtle.down()
        end

        self:drawHeader()
    end

    movingTo.y = nil

    self:setStateValue("movingTo", utils.tableShallowClone(movingTo))
end

function Turtle:dig(side, noRefuelAttempt)
    if not side then side = self.options.mainToolSlotSide end

    -- Turtle action
    local success, error
    while not success do
        if error then
            print("  - Dig failed: "..error)
            print("  - Retrying in 5 seconds...")

            sleep(5)
        end

        if not noRefuelAttempt then self:attemptRefuel() end
        success, error = turtle.dig(side)
    end
end

function Turtle:digDown(side, noRefuelAttempt)
    if not side then side = self.options.mainToolSlotSide end

    -- Turtle action
    local success, error
    while not success do
        if error then
            print("  - Dig down failed: "..error)
            print("  - Retrying in 5 seconds...")

            sleep(5)
        end

        if not noRefuelAttempt then self:attemptRefuel() end
        success, error = turtle.digDown(side)
    end
end

function Turtle:digUp(side, noRefuelAttempt)
    if not side then side = self.options.mainToolSlotSide end

    -- Turtle action
    local success, error
    while not success do
        if error then
            print("  - Dig up failed: "..error)
            print("  - Retrying in 5 seconds...")

            sleep(5)
        end

        if not noRefuelAttempt then self:attemptRefuel() end
        success, error = turtle.digUp(side)
    end
end

return Turtle