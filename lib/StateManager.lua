local StateManager = {}

function StateManager:new(options)
    local dir = options.dir
    local name = options.name
    local default = options.default

    local path = dir.."/"..name..".state.json"

    local o = { dir=dir, name=name, default=options.default, path=path }
    setmetatable(o, self)
    self.__index = self

    local existingState = self:read()

    if existingState then
        self.state = existingState
    else
        self:save(default)
    end

    return o
end

function StateManager:save(newState)
    self.state = newState
    local file = fs.open(self.path, "w")
    file.write(textutils.serialiseJSON(newState))
    file.close()
end

function StateManager:reset()
    self:save(self.default)
end

function StateManager:read()
    if not fs.exists(self.path) then return end
    local file = fs.open(self.path, "r")
    local state = textutils.unserialiseJSON(file.readAll())
    file.close()
    return state
end

return StateManager