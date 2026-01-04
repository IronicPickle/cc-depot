-- Deps
local Monitor = require("/lib/peripherals/Monitor")
local Window = require("/lib/Window")
local StateManager = require("/lib/StateManager")

-- Config
local CONFIG = textutils.unserialiseJSON(arg[1])
local DIR = arg[2]

-- Peripherals
if not peripheral.find("monitor") then error("An attached monitor is required") end

local MONITOR = Monitor:new(peripheral.find("monitor"), {
    textScale=0.5
})

local MODEM = peripheral.find("modem")
local SPEAKER = peripheral.find("speaker")

-- Globals
local STATE_MANAGER = StateManager:new({
    dir=DIR,
    name="toggle",
    default={
        mode="closed"
    }
})

-- Windows
local HEADER_HEIGHT = 4
local FOOTER_HEIGHT = MONITOR.output.height - HEADER_HEIGHT

local HEADER = Window:new(MONITOR.output, {
    x=1,
    y=1,
    height=HEADER_HEIGHT
})
local FOOTER = Window:new(MONITOR.output, {
    x=1,
    y=HEADER_HEIGHT + 1,
    height=FOOTER_HEIGHT
})

-- Main


local function outputToRedstone(rsState)
    if CONFIG.redstoneOutputSide == nil then return end

    if(CONFIG.redstoneOutputType == "switch") then
        rs.setAnalogOutput(CONFIG.redstoneOutputSide, rsState and 15 or 0)
    else
        rs.setAnalogOutput(CONFIG.redstoneOutputSide, 15)
        os.sleep(0.5)
        rs.setAnalogOutput(CONFIG.redstoneOutputSide, 0)
    end
end

local function drawHeader()
    local bgColors = {
        on = colors.green,
        off = colors.red
    }
    HEADER:fillBackground({
        bgColor=bgColors[STATE_MANAGER.state.mode]
    })
    HEADER:drawBox({
        x=1,
        y=HEADER.output.height,
        width=HEADER.output.width,
        height=1,
        filled=true,
        bgColor=colors.white
    })

    HEADER:write(msgs[STATE_MANAGER.state.mode], {
        x=0,
        y=2,
        align="center"
    })
end

local function drawFooter()
    local bgColors = {
        on = colors.green,
        off = colors.red
    }
    FOOTER:fillBackground({
        bgColor=bgColors[STATE_MANAGER.state.mode]
    })

    FOOTER:drawBox({
        x=1,
        y=1,
        width=FOOTER.output.width,
        height=1,
        filled=true,
        bgColor=colors.white
    })
    
    local msgs = {
        on = "Enabled",
        off = "Disabled"
    }
    
    FOOTER:write(msgs[STATE_MANAGER.state.mode], {
        x=0,
        y=3,
        align="center"
    })
    
    FOOTER:write("Click to Toggle", {
        x=0,
        y=FOOTER.output.height - 1,
        align="center"
    })
end

local function off(isInitial)
    if(not isInitial or CONFIG.redstoneOutputType == "switch") then outputToRedstone(false) end
    if(SPEAKER) then
        SPEAKER.playSound(
            "minecraft:block.lever.click",
            1, 0.8
        )
    end
    STATE_MANAGER:save({
        mode="off"
    })
    drawHeader()
    drawFooter()
end

local function on(isInitial)
    if(not isInitial or CONFIG.redstoneOutputType == "switch") then outputToRedstone(true) end
    if(SPEAKER) then
        SPEAKER.playSound(
            "minecraft:block.lever.click",
            1, 1
        )
    end
    STATE_MANAGER:save({
        mode="on"
    })
    drawHeader()
    drawFooter()
end

function await()
    while(true) do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()
        
        local isTouch = (event == "monitor_touch")
        
        local isModemMessage = (event == "modem_message")
        
        if(isTouch) then
            MODEM.transmit(CONFIG.channel, CONFIG.channel,
                { type = STATE_MANAGER.state.mode }
            )
            if(STATE_MANAGER.state.mode == "on") then
                off()
            elseif(STATE_MANAGER.state.mode == "off") then
                on()
            end
        elseif(isModemMessage) then
            local body = p4
            if(body.type == "on") then
                off()
            elseif(body.type == "off") then
                on()
            end
        end
    end
end

local function start()
    print("# Program Started")
    MODEM.open(CONFIG.channel)
    
    drawHeader()
    drawFooter()
    
    
    parallel.waitForAll(await, function ()
        if(STATE_MANAGER.state.mode == "on") then
            on(true)
        else
            off(true)
        end
    end)
end

start()