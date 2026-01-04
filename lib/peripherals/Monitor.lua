local Monitor = {}

function Monitor:new(output)
    local resX, resY = output.getSize()
    output.width = resX
    output.height = resY

    local o = { output = output }
    setmetatable(o, self)
    self.__index = self

    return o
end

function Monitor:write(text, options)
    local cursorX, cursorY = term.getCursorPos()

    local prevTextColor = self.output.getTextColor()
    local prevBgColor = self.output.getBackgroundColor()

    local x = options.x or cursorX
    local y = options.y or cursorY
    local xPadding = options.xPadding or 0
    local align = options.align or "left"
    local textColor = options.textColor or prevTextColor
    local bgColor = options.bgColor or prevBgColor

    local wrap = options.wrap
    local progressCursor = options.progressCursor
    
    self.output.setTextColor(textColor)
    self.output.setBackgroundColor(bgColor)

    local outputText = text
    local overflowText = nil

    local availableWidth = self.output.width - x - (xPadding * 2)
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
        x = ( ( self.output.width - len ) / 2 ) + x
    elseif align == "right" then
        x = self.output.width - len - (x + xPadding) - 1
    elseif align == "left" then
        x = 1 + (x + xPadding)
    end

    self.output.setCursorPos(x, y)
    self.output.write(outputText)
    
    self.output.setTextColor(prevTextColor)
    self.output.setBackgroundColor(prevBgColor)

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
        self.output.setCursorPos(x + text:len(), progressCursor and y + 1 or y)
    end
    
end

function Monitor:drawBox(x, y, dx, dy, filled, bgColor)
    local prevBgColor = self.output.getBackgroundColor()
    bgColor = bgColor or prevBgColor
    
    term.redirect(self.output)
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
    self.output.setBackgroundColor(prevBgColor)
end

function Monitor:createButton(x, y, paddingX, paddingY, align, bgColor, textColor, text, onClick, disabled)
    local len = text:len()
    
    if align == "center" then
        x = ( ( self.output.width - (len + paddingX) ) / 2 ) + x
    elseif align == "right" then
        x = self.output.width - (len + paddingX) - x
    elseif align == "left" then
        x = x
    end

    local dx = x + len + (paddingX * 2) - 1
    local dy = y + (paddingY * 2)

    self:drawBox(self.output, x, y, dx, dy, true, bgColor)
    self:write(self.output, text, x + paddingX, y + paddingY, nil, textColor, bgColor)

    while true do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()
        
        local isTouch = (event == "monitor_touch")

        if isTouch then
            local touchX = p2 - self.output.posX + 1
            local touchY = p3 - self.output.posY + 1

            if touchX >= x and touchY >= y and touchX <= dx and touchY <= dy and not disabled then
                if onClick() then break end
            end
        end
    end
end

function Monitor:fillBackground(bgColor)
    local prevBgColor = self.output.getBackgroundColor()

    self.output.bg = bgColor
    self.output.setBackgroundColor(self.output.bg)
  
    self:drawBox(
        1, 1, self.output.width, self.output.height,
        true
    )

end

function Monitor:createModal(title, bgColor, textColor, disabledColor, cancelButtonText, submitButtonText, buttons)
    self:fillBackground(bgColor)
    self:write(title, 0, 3, "center", textColor)

    local modalInner = setup.setupWindow(
        self.output, 2, 6, self.output.width - 2, self.output.height - 10
    )

    local action = nil

    local awaitButtonInput = buttons

    if not awaitButtonInput then
        awaitButtonInput = function(disabled)
            function createCancelButton()
                self:createButton(self.output, -6, self.output.height - 3, 2, 1, "center", bgColor, textColor, cancelButtonText or "Cancel", function ()
                action = "cancel"
                return true
                end)
            end
            function createSubmitButton()
                self:createButton(self.output, 6, self.output.height - 3, 2, 1, "center", disabled and disabledColor or textColor, bgColor, submitButtonText or "Create", function ()
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