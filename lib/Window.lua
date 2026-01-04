local Monitor = require("/lib/peripherals/Monitor")

local Window = {}

function Window:new(output, options)
    local x = options.x or 1
    local y = options.y or 1
    local width = options.width or output.width
    local height = options.height or output.height

    local win = window.create(output, x, y, width, height)

    win.x = x
    win.y = y

    return Monitor:new(win)
end

return Window