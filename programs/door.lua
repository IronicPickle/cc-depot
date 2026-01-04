-- Deps
local Monitor = require("/lib/peripherals/Monitor")
local Window = require("/lib/Window")

-- Config
local CONFIG = textutils.serialiseJSON(arg[1])

-- Peripherals
if not peripheral.find("monitor") then error("An attached monitor is required") end

local MONITOR = Monitor:new(peripheral.find("monitor"), {
    textScale=0.5
})

local MODEM = peripheral.find("modem")
local SPEAKER = peripheral.find("speaker")

-- Globals
local STATE_DATA = "closed"
local DEFAULT_DATA = "closed"
local STATE = STATE_DATA or DEFAULT_DATA

-- Windows
local HEADER_HEIGHT = 4
local FOOTER_HEIGHT = 4
local BODY_HEIGHT = MONITOR.output.height - HEADER_HEIGHT - FOOTER_HEIGHT

local HEADER = Window:new(MONITOR.output, {
    x=1,
    y=1,
    height=HEADER_HEIGHT
})
local BODY = Window:new(MONITOR.output, {
    x=1,
    y=HEADER_HEIGHT + 1,
    height=FOOTER_HEIGHT
})
local FOOTER = Window:new(MONITOR.output, {
    x=1,
    y=HEADER_HEIGHT + BODY_HEIGHT + 1,
    height=FOOTER_HEIGHT
})

local function outputToRedstone(rsState)
    if(CONFIG.redstoneOutputType == "switch") then
        rs.setAnalogOutput(CONFIG.redstoneOutputSide, rsState and 15 or 0)
    else
        rs.setAnalogOutput(CONFIG.redstoneOutputSide, 15)
        os.sleep(0.5)
        rs.setAnalogOutput(CONFIG.redstoneOutputSide, 0)
    end
end


local function updateState()
    -- stateHandler.updateState("door", state)
end

local function drawHeader(timeLeft)
    local bgColors = {
        open = colors.green,
        opening = colors.red,
        closed = colors.red,
        closing = colors.green
    }
    
    HEADER:fillBackground({
        bgColor=bgColors[STATE]
    })
    HEADER:drawBox({
        x=1,
        y=HEADER.output.height,
        width=HEADER.output.width,
        height=1,
        filled=true,
        bgColor=colors.white
    })
    timeLeft = timeLeft or 10
    local msgs = {
        open = "Sealing in: " .. timeLeft,
        opening = "Opening",
        closed = name,
        closing = "Sealing"
    }
    
    HEADER:write({
        text=msgs[STATE],
        x=0,
        y=2,
        align="center"
    })
end

local function drawFooter()
    local bgColors = {
        open = colors.green,
        opening = colors.red,
        closed = colors.red,
        closing = colors.green
    }
    FOOTER:fillBackground(bgColors[STATE])

    FOOTER:drawBox({
        x=1,
        y=1,
        width=FOOTER.output.width,
        height=1,
        filled=true,
        bgColor=colors.white
    })
    
    local msgs = {
        open = "Click to Seal",
        opening = "Please Wait",
        closed = "Click to Open",
        closing = "Please Wait"
    }
    
    FOOTER:write({
        text=msgs[STATE],
        x=0,
        y=3,
        align="center"
    })
end

local function drawBody(timeLeft, timeMax)
    local bgColors = {
        open = {colors.green, colors.red},
        opening = {colors.green, colors.red},
        closed = {colors.red, colors.green},
        closing = {colors.red, colors.green}
    }
    BODY:fillBackground(bgColors[STATE][1])

    if(STATE ~= "closed") then
        local single = monitor.x / timeMax
        local width = timeLeft * single
        
        BODY:drawBox({
            x=1,
            y=1,
            width=width,
            height=BODY.output.height,
            filled=true,
            bgColor=bgColors[STATE][2]
        })
    end
end

local function close(isInitial)
    if(not isInitial or CONFIG.redstoneOutputType == "switch") then outputToRedstone(false) end
    if(SPEAKER) then
        SPEAKER.playSound(
            "minecraft:item.lodestone_compass.lock",
            1, 0.7
        )
    end
    STATE = "closing"
    updateState()
    drawHeader()
    drawFooter()
    for i = CONFIG.closeTime, 0, -0.1 do
        drawBody(i, CONFIG.closeTime)
        os.sleep(0.1)
    end
    STATE = "closed"
    updateState()
    drawHeader()
    drawFooter()
    drawBody()
end

local function open(isInitial)
    parallel.waitForAny(await,
        function()
            if not isInitial or CONFIG.redstoneOutputType == "switch" then outputToRedstone(true) end
            if SPEAKER  then
                SPEAKER.playSound(
                    "minecraft:item.lodestone_compass.lock",
                    1, 1
                )
            end
            STATE = "opening"
            updateState()
            drawHeader()
            drawFooter()
            for i = CONFIG.openTime, 0, -0.1 do
                drawBody(i, CONFIG.openTime)
                os.sleep(0.1)
            end
            STATE = "open"
            updateState()
            drawFooter()
            for i = CONFIG.delay, 0, -0.1 do
                drawHeader(math.floor(i))
                drawBody(i, CONFIG.delay)
                os.sleep(0.1)
            end
        end
    )
    close()
end

function await()
    while(true) do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()
        
        local isTouch = (event == "monitor_touch")
        
        local isModemMessage = (event == "modem_message")
        
        
        if(isTouch) then
            if MODEM then
                MODEM.transmit(CONFIG.channel, CONFIG.channel,
                    { type = STATE }
                )
            end
            if(STATE == "open") then
                break
            elseif(STATE == "closed") then
                open()
            end
        elseif(isModemMessage) then
            local body = p4
            if(body.type == "open") then
                break
            elseif(body.type == "closed") then
                open()
            end
        end
    end
end

local function start()
    print("# Door program started")

    MONITOR.output.clear()
    MONITOR:write("Test", {
        x=1,
        y=2,
        textColor=colors.white
    })

    if MODEM then
        MODEM.open(CONFIG.channel)
    end
    
    parallel.waitForAll(await, function ()
        if(STATE == "open" or STATE == "opening") then
            open(true)
        else
            close(true)
        end
    end)
end

start()