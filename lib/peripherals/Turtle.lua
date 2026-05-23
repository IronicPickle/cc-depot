-- Deps
local utils = require("/lib/utils")

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

function Turtle:new(stateManager)
    local o = {
        stateManager = stateManager
    }

    stateManager.default = DEFAULT_STATE
    if not stateManager.state then
        stateManager:save(DEFAULT_STATE)
    end
    
    setmetatable(o, self)
    self.__index = self

    return o
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

function Turtle:moveTo(coords)
    -- Save target destination to state
    local movingTo = utils.tableShallowClone(self:getStateValue(coords))

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
        self:forward(coords.z)
    elseif coords.z < 0 then
        self:faceBack()
        self:forward(coords.z)
    end

    -- Move to anchor x
    if coords.x > 0 then
        self:faceRight()
        self:forward(coords.x)
    elseif coords.x < 0 then
        self:faceLeft()
        self:forward(coords.x)
    end

    -- Move to anchor y
    if coords.y > 0 then
        self:up(coords.y)
    elseif coords.y < 0 then
        self:down(coords.y)
    end
end

function Turtle:returnToAnchor()
    -- Retain and reset anchorOffset
    local anchorOffset = utils.tableShallowClone(self:getStateValue("anchorOffset"))
    self:resetAnchor()

    -- Save current anchor to previousAnchorOffset
    self:setStateValue("previousAnchorOffset", anchorOffset)

    self:moveTo({
        x = 0 - anchorOffset.x,
        y = 0 - anchorOffset.y,
        z = 0 - anchorOffset.z
    })

    -- Reset position
    self:forward()
end

function Turtle:resumePosition()
    -- Retain and reset previousAnchorOffset
    local previousAnchorOffset = utils.tableShallowClone(self:getStateValue("previousAnchorOffset"))
    self:resetAnchor()

    self:moveTo({
        x = 0 - previousAnchorOffset.x,
        y = 0 - previousAnchorOffset.y,
        z = 0 - previousAnchorOffset.z
    })

    -- Reset position
    self:forward()
end

function Turtle:incrementAnchor(increments)
    local anchorOffset = utils.tableShallowClone(self:getStateValue("anchorOffset"))

    if increments.x ~= nil then
        anchorOffset.x = increments.x
    end

    if increments.z ~= nil then
        anchorOffset.z = increments.z
    end

    if increments.y ~= nil then
        anchorOffset.y = increments.y
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

function Turtle:forward(distance)
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

    for _=1, distance, 1 do
        -- State update
        if orientation == "forward" then
            self:incrementAnchorZ(1)
            movingTo.z = movingTo.z - 1
        elseif orientation == "back" then
            self:incrementAnchorZ(-1)
            movingTo.z = movingTo.z + 1
        elseif orientation == "right" then
            self:incrementAnchorX(1)
            movingTo.x = movingTo.x + 1
        elseif orientation == "left" then
            self:incrementAnchorX(-1)
            movingTo.x = movingTo.x - 1
        end

        self:setStateValue("movingTo", utils.tableShallowClone(movingTo))

        -- Turtle action
        turtle.forward()
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

function Turtle:back(distance)
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

    for _=1, distance, 1 do
        -- State update
        if orientation == "forward" then
            self:incrementAnchorZ(-1)
            movingTo.z = movingTo.z + 1
        elseif orientation == "back" then
            self:incrementAnchorZ(1)
            movingTo.z = movingTo.z - 1
        elseif orientation == "right" then
            self:incrementAnchorX(-1)
            movingTo.x = movingTo.x + 1
        elseif orientation == "left" then
            self:incrementAnchorX(1)
            movingTo.x = movingTo.x - 1
        end

        self:setStateValue("movingTo", utils.tableShallowClone(movingTo))

        -- Turtle action
        turtle.back()
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

function Turtle:up(distance)
    if distance == nil then distance = 1 end

    local movingTo = utils.tableShallowClone(self:getStateValue("movingTo"))

    movingTo.y = distance

    self:setStateValue("movingTo", utils.tableShallowClone(movingTo))

    for _=1, distance, 1 do
        -- State update
        self:incrementAnchorY(1)
        movingTo.y = distance + 1

        self:setStateValue("movingTo", utils.tableShallowClone(movingTo))

        -- Turtle action
        turtle.up()
    end

    movingTo.y = nil

    self:setStateValue("movingTo", utils.tableShallowClone(movingTo))
end

function Turtle:down(distance)
    if distance == nil then distance = 1 end

    local movingTo = utils.tableShallowClone(self:getStateValue("movingTo"))

    movingTo.y = -distance

    self:setStateValue("movingTo", utils.tableShallowClone(movingTo))

    for _=1, distance, 1 do
        -- State update
        self:incrementAnchorY(-1)
        movingTo.y = distance - 1

        self:setStateValue("movingTo", utils.tableShallowClone(movingTo))

        -- Turtle action
        turtle.down()
    end

    movingTo.y = nil

    self:setStateValue("movingTo", utils.tableShallowClone(movingTo))
end

return Turtle