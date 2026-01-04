-- Deps
local Monitor = require("/lib/peripherals/Monitor")
local Window = require("/lib/Window")

-- Peripherals
local TERMINAL = Monitor:new(term.current())
local MODEM = peripheral.find("modem")

-- Windows
local HEADER_HEIGHT = 4
local HEADER = Window:new(TERMINAL.output, {
    x=1,
    y=1,
    height=HEADER_HEIGHT
})
local BODY = Window:new(TERMINAL.output, {
    x=1,
    y=HEADER_HEIGHT + 1,
    height=TERMINAL.output.height - HEADER_HEIGHT
})

-- Globals
local RUNNER_UPDATE_CHANNEL = 59941
local QUEUED_COMMAND = nil

local function drawHeader()
    HEADER:fillBackground({
        bgColor=colors.red
    })

end

local function drawBody()
    BODY:fillBackground({
        bgColor=colors.lightGray
    })
end

local function awaitCommand()
    local ctrlHeld = false

    -- print("\n- Available commands:")
    -- print("  | Ctrl + S - Stop program")
    -- print("  | Ctrl + R - Restart program")
    -- print("")
    -- print("  | Ctrl + U - Update program")
    -- print("  | Ctrl + C - Reconfigure program")
    -- print("  | Ctrl + D - Full system reset")



    while true do
        local event, p1, _p2, _p3, p4 = os.pullEvent()

        if event == "key_up" then
            local key = p1

            if key == keys.s then
                QUEUED_COMMAND = "STOP"
                return
            elseif key == keys.r then
                QUEUED_COMMAND = "RESTART"
                return
            elseif key == keys.u then
                QUEUED_COMMAND = "UPDATE"
                return
            elseif key == keys.c then
                QUEUED_COMMAND = "CONFIGURE"
                return
            elseif key == keys.d then
                QUEUED_COMMAND = "RESET"
                return
            end
        end

        ::continue::
    end
end

local function start()
    -- Allow for runner commands to print
    os.sleep(1)

    TERMINAL.output.clear()

    drawHeader()
    drawBody()

    while true do
        awaitCommand()
    end
end

start()