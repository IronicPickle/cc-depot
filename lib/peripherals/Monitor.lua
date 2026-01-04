local Monitor = {}

function Monitor:new(output, options)
    if not options then options = {} end

    local textScale = options.textScale or 1

    if output.setTextScale then
        output.setTextScale(textScale)
    end

    local resX, resY = output.getSize()
    output.width = resX
    output.height = resY

    output.bgColor = output.getBackgroundColor()

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

function Monitor:drawBox(options)
    local prevBgColor = self.output.getBackgroundColor()

    local x = options.x
    local y = options.y
    local width = options.width
    local height = options.height
    local filled = options.filled or true
    local bgColor = options.bgColor or prevBgColor

    local dx = x + width
    local dy = y + height

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

function Monitor:createButton(options)
    local x = options.x
    local y = options.y
    local paddingX = options.paddingX or 0
    local paddingY = options.paddingY or 0
    local align = options.align or "left"
    local bgColor = options.bgColor
    local textColor = options.textColor
    local text = options.text or "Button"
    local onClick = options.onClick
    local disabled = options.disabled

    local len = text:len()
    
    if align == "center" then
        x = ( ( self.output.width - (len + paddingX) ) / 2 ) + x
    elseif align == "right" then
        x = self.output.width - (len + paddingX) - x
    elseif align == "left" then
        x = x
    end

    local width = len + (paddingX * 2) - 1
    local height = (paddingY * 2)

    local dx = x + width
    local dy = y + height

    self:drawBox({
        x=x,
        y=y,
        width=width,
        height=height,
        filled=true,
        bgColor=bgColor
    })
    self:write({
        text=text,
        x=x + paddingX,
        y=y + paddingY,
        textColor=textColor,
        bgColor=bgColor
    })

    while true do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()
        
        local isTouch = (event == "monitor_touch")

        if isTouch then
            local touchX = p2 - self.output.x + 1
            local touchY = p3 - self.output.y + 1

            if touchX >= x and touchY >= y and touchX <= dx and touchY <= dy and not disabled then
                if onClick() then break end
            end
        end
    end
end

function Monitor:fillBackground(options)
    local bgColor = options.bgColor or self.output.getBackgroundColor()

    self.output.bgColor = bgColor
    self.output.setBackgroundColor(self.output.bgColor)
  
    self:drawBox({
        x=1,
        y=1,
        width=self.output.width,
        height=self.output.height,
        filled=true
    })
end

function Monitor:createModal(options)
    local Window = require("/lib/Window")

    local title = options.title or "Unnamed Modal"
    local bgColor = options.bgColor
    local textColor = options.textColor
    local disabledColor = options.disabledColor
    local cancelButtonText = options.cancelButtonText or "Cancel"
    local submitButtonText = options.submitButtonText or "Submit"
    local buttons = options.buttons

    self:fillBackground({
        bgColor=bgColor
    })
    self:write({
        text=title,
        x=0,
        y=3,
        align="center",
        textColor=textColor
    })

    local INNER = Window:new(self.output, {
        x=2,
        y=6,
        width=self.output.width - 2,
        height=self.output.height - 10
    })

    local action = nil

    local awaitButtonInput = buttons

    if not awaitButtonInput then
        awaitButtonInput = function(disabled)
            function createCancelButton()
                self:createButton({
                    x=-6,
                    y=self.output.height - 3,
                    paddingX=2,
                    paddingY=1,
                    align="center",
                    bgColor=bgColor,
                    textColor=textColor,
                    text=cancelButtonText,
                    onClick=function ()
                        action = "cancel"
                        return true
                    end
                })
            end
            function createSubmitButton()
                self:createButton({
                    x=6,
                    y=self.output.height - 3,
                    paddingX=2,
                    paddingY=1,
                    align="center",
                    bgColor=bgColor,
                    textColor=disabled and disabledColor or textColor,
                    text=submitButtonText,
                    disabled=disabled,
                    onClick=function ()
                        action = "submit"
                        return true
                    end
                })
            end
            
            parallel.waitForAny(createCancelButton, createSubmitButton)

            return action
        end
    end

    return INNER, awaitButtonInput
end

return Monitor