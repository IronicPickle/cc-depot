local StateManager = {}

local function write(path, state)
    local file = fs.open(path, "w")
    file.write(textutils.unserialiseJSON(state))
    file.close()
end

local function read(path)
    if not fs.exists(path) then return end
    local file = fs.open(path, "r")
    local state = textutils.serialiseJSON(file.readAll())
    file.close()
    return state
end

function StateManager:new(options)
    local dir = options.dir
    local name = options.name
    local default = options.default

    local path = dir.."/"..name..".state.json"

    local o = { dir=dir, name=name, default=options.default, path=path }
    setmetatable(o, self)
    self.__index = self

    local existingState = read()

    if existingState then
        self.state = existingState
    else
        self.state = default
        write(path, default)
    end

    return o
end

function StateManager:save(newState)
    self.state = newState
    write(newState)
end

function StateManager:reset()
    self:save(self.default)
end

return StateManager