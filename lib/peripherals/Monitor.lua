local test = require("/cc_depot/lib/peripherals/test")

local Monitor = {}

function Monitor:new(monitor)
    local resX, resY = monitor.getSize()
    monitor.x = resX
    monitor.y = resY

    local o = { monitor = monitor }
    setmetatable(o, self)
    self.__index = self

    return o
end

function Monitor:write(text, options)
    local cursorX, cursorY = term.getCursorPos()

    local prevTextColor = self.monitor.getTextColor()
    local prevBgColor = self.monitor.getBackgroundColor()

    local x = options.x or cursorX
    local y = options.y or cursorY
    local xPadding = options.xPadding or 0
    local align = options.align or "left"
    local textColor = options.textColor or prevTextColor
    local bgColor = options.bgColor or prevBgColor

    local wrap = options.wrap
    local progressCursor = options.progressCursor
    
    self.monitor.setTextColor(textColor)
    self.monitor.setBackgroundColor(bgColor)

    local outputText = text
    local overflowText = nil

    local availableWidth = self.monitor.x - x - (xPadding * 2)
    local shouldWrap = #text > availableWidth
    if shouldWrap and wrap then
        outputText = ""

        for subString in text:gmatch("([^%s]+)") do
            term.setTextColor(colors.white)
            local newOutputText = #outputText == 0 and subString or outputText.." "..subString
            if #newOutputText > availableWidth then break end
            outputText = newOutputText
        end

        if #text > #outputText then
            overflowText = text:sub(#outputText + 2)
        end
    end

    local len = outputText:len() - 2
    if align == "center" then
        x = ( ( self.monitor.x - len ) / 2 ) + x
    elseif align == "right" then
        x = self.monitor.x - len - (x + xPadding) - 1
    elseif align == "left" then
        x = 1 + (x + xPadding)
    end

    self.monitor.setCursorPos(x, y)
    self.monitor.write(outputText)
    
    self.monitor.setTextColor(prevTextColor)
    self.monitor.setBackgroundColor(prevBgColor)

    if overflowText then
        self:write(overflowText, {
            x=options.x,
            y=y + 1,
            xPadding=options.xPadding,
            align=options.align,
            textColor=options.textColor,
            bgColor=options.bgColor,
            progressCursor=options.progressCursor
        })
    else
        self.monitor.setCursorPos(x + text:len(), progressCursor and y + 1 or y)
    end
    
end

function Monitor:drawBox(x, y, dx, dy, filled, bgColor)
    local prevBgColor = self.monitor.getBackgroundColor()
    bgColor = bgColor or prevBgColor
    
    term.redirect(self.monitor)
    if filled then
        paintutils.drawFilledBox(
            x, y, dx, dy, bgColor
        )
    else
        paintutils.drawBox(
            x, y, dx, dy, bgColor
        )
    end
    term.redirect(term.native())
    self.monitor.setBackgroundColor(prevBgColor)
end

function Monitor:createButton(x, y, paddingX, paddingY, align, bgColor, textColor, text, onClick, disabled)
    local len = text:len()
    
    if align == "center" then
        x = ( ( self.monitor.x - (len + paddingX) ) / 2 ) + x
    elseif align == "right" then
        x = self.monitor.x - (len + paddingX) - x
    elseif align == "left" then
        x = x
    end

    local dx = x + len + (paddingX * 2) - 1
    local dy = y + (paddingY * 2)

    self:drawBox(self.monitor, x, y, dx, dy, true, bgColor)
    self:write(self.monitor, text, x + paddingX, y + paddingY, nil, textColor, bgColor)

    while true do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()
        
        local isTouch = (event == "monitor_touch")

        if isTouch then
            local touchX = p2 - self.monitor.posX + 1
            local touchY = p3 - self.monitor.posY + 1

            if touchX >= x and touchY >= y and touchX <= dx and touchY <= dy and not disabled then
                if onClick() then break end
            end
        end
    end
end

function Monitor:fillBackground(bgColor)
    local prevBgColor = self.monitor.getBackgroundColor()

    self.monitor.bg = bgColor
    self.monitor.setBackgroundColor(self.monitor.bg)
  
    self:drawBox(
        1, 1, self.monitor.x, self.monitor.y,
        true
    )

end

function Monitor:createModal(title, bgColor, textColor, disabledColor, cancelButtonText, submitButtonText, buttons)
    self:fillBackground(bgColor)
    self:write(title, 0, 3, "center", textColor)

    local modalInner = setup.setupWindow(
        self.monitor, 2, 6, self.monitor.x - 2, self.monitor.y - 10
    )

    local action = nil

    local awaitButtonInput = buttons

    if not awaitButtonInput then
        awaitButtonInput = function(disabled)
            function createCancelButton()
                self:createButton(self.monitor, -6, self.monitor.y - 3, 2, 1, "center", bgColor, textColor, cancelButtonText or "Cancel", function ()
                action = "cancel"
                return true
                end)
            end
            function createSubmitButton()
                self:createButton(ouself.monitortput, 6, self.monitor.y - 3, 2, 1, "center", disabled and disabledColor or textColor, bgColor, submitButtonText or "Create", function ()
                action = "submit"
                return true
                end, disabled)
            end
            
            parallel.waitForAny(createCancelButton, createSubmitButton)

            return action
        end
    end

    return modalInner, awaitButtonInput
end

return Monitor