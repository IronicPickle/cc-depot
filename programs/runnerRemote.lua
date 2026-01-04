-- Deps
local Monitor = require("/lib/peripherals/Monitor")
local Window = require("/lib/Window")

-- Peripherals
if not peripheral.find("modem") then error("An attached modem is required") end

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
local QUEUED_PROGRAM = nil

local function drawHeader()
    HEADER:fillBackground({
        bgColor=colors.red
    })

    HEADER:write("Runner Remote", {
        x=0,
        y=2,
        align="center",
        textColor=colors.white
    })
    HEADER:write("Emit channel: "..RUNNER_UPDATE_CHANNEL, {
        x=0,
        y=3,
        align="center",
        textColor=colors.black
    })
end

local function drawBody()
    BODY:fillBackground({
        bgColor=colors.lightGray
    })

    if QUEUED_PROGRAM and QUEUED_COMMAND then
        BODY:write("Sending command...", {
            x=0,
            xPadding=1,
            y=2,
            textColor=colors.white,
            wrap=true,
            progressCursor=true
        })
        BODY:write("", {
            x=1,
            progressCursor=true
        })
        BODY:write("Command: "..QUEUED_COMMAND, {
            x=0,
            xPadding=1,
            textColor=colors.white,
            wrap=true,
            progressCursor=true
        })
        BODY:write("Target: "..QUEUED_PROGRAM, {
            x=0,
            xPadding=1,
            textColor=colors.white,
            wrap=true,
            progressCursor=true
        })
    elseif QUEUED_COMMAND then
        BODY:write("Command: "..QUEUED_COMMAND, {
            x=0,
            xPadding=1,
            y=2,
            textColor=colors.white,
            wrap=true,
            progressCursor=true
        })
        BODY:write("Target program", {
            x=0,
            xPadding=1,
            textColor=colors.white,
            wrap=true,
            progressCursor=true
        })
        local cursorX, cursorY = BODY.output.getCursorPos()
        BODY:write("(leave empty for all)", {
            x=0,
            xPadding=1,
            y=cursorY + 2,
            textColor=colors.white,
            wrap=true
        })
        BODY.output.setCursorPos(cursorX, cursorY)
        BODY:write("> ", {
            x=1,
            textColor=colors.white
        })
    else
        BODY:write("S - Stop Program", {
            x=0,
            xPadding=1,
            y=2,
            textColor=colors.white,
            wrap=true,
            progressCursor=true
        })
        BODY:write("R - Restart Program", {
            x=0,
            xPadding=1,
            textColor=colors.white,
            wrap=true,
            progressCursor=true
        })
        BODY:write("", {
            x=0,
            progressCursor=true
        })
        BODY:write("U - Update program", {
            x=0,
            xPadding=1,
            textColor=colors.white,
            wrap=true,
            progressCursor=true
        })
        BODY:write("C - Reconfigure program", {
            x=0,
            xPadding=1,
            textColor=colors.white,
            wrap=true,
            progressCursor=true
        })
        BODY:write("D - Full system reset", {
            x=0,
            xPadding=1,
            textColor=colors.white,
            wrap=true,
            progressCursor=true
        })
        BODY:write("", {
            x=0,
            progressCursor=true
        })
    end

end

local function awaitCommand()
    local ctrlHeld = false

    while true do
        local event, p1, _p2, _p3, p4 = os.pullEvent()
        if event == "key" then
            local key = p1

            if key == keys.leftCtrl then
                ctrlHeld = true
            end
        elseif event == "key_up" then
            local key = p1

            if key == keys.leftCtrl then
                ctrlHeld = false
            end

            if ctrlHeld then goto continue end

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

local function awaitProgramInput()
    local value = read()

    if #value == 0 then
        value = "all"
    end

    QUEUED_PROGRAM = value
end

local function sendRemoteCommand()
    MODEM.transmit(RUNNER_UPDATE_CHANNEL, RUNNER_UPDATE_CHANNEL,
        {
            type="/runner/command",
            command=QUEUED_COMMAND,
            program=QUEUED_PROGRAM
        }
    )
end

local function start()
    -- Allow for runner commands to print
    os.sleep(1)

    TERMINAL.output.clear()

    drawHeader()

    while true do
        drawBody()


        if QUEUED_PROGRAM then
            os.sleep(1.5)
            QUEUED_COMMAND = nil
            QUEUED_PROGRAM = nil

            goto continue
        elseif QUEUED_COMMAND then
            awaitProgramInput()
            sendRemoteCommand()

            goto continue
        end
        
        awaitCommand()

        ::continue::
    end
end

start()