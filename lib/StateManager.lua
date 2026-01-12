local StateManager = {}

local function write(path, state)
    local file = fs.open(path, "w")
    file.write(textutils.serialiseJSON(state))
    file.close()
end

local function read(path)
    if not fs.exists(path) then return end
    local file = fs.open(path, "r")
    local state = textutils.unserialiseJSON(file.readAll())
    file.close()
    return state
end

function StateManager:new(options)
    local dir = options.dir
    local name = options.name
    local default = options.default

    local path = dir.."/"..name..".state.json"

    local existingState = read(path)

    if not existingState and default then
        write(path, default)
    end

    local o = { dir=dir, name=name, default=default, path=path, state=existingState or default }
    setmetatable(o, self)
    self.__index = self

    return o
end

function StateManager:save(newState)
    self.state = newState
    write(self.path, newState)
end

function StateManager:reset()
    self:save(self.default)
end

return StateManager