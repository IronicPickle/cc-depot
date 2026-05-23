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
      x=0,
      z=0,
      y=0
    }
})
local TURTLE = Turtle:new(StateManager:new({
    dir=DIR,
    name="quarry-turtle"
}))

-- Main
function start()
  print("# Quarry program started")

  TURTLE:forward(5)
end

start()

