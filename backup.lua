-- Helper: Find window under mouse
local function windowUnderMouse()
    local mousePos = hs.mouse.absolutePosition()
    -- First, check normal windows
    for _, win in ipairs(hs.window.orderedWindows()) do
        if win:isVisible() then
            local frame = win:frame()
            if mousePos.x >= frame.x and mousePos.x <= frame.x + frame.w and
               mousePos.y >= frame.y and mousePos.y <= frame.y + frame.h then
                return win
            end
        end
    end
    -- If not found, check for AXSheet/AXDialog (e.g. About menu)
    local app = hs.application.frontmostApplication()
    if app then
        local axApp = hs.axuielement.applicationElement(app)
        local children = axApp:attributeValue("AXChildren") or {}
        for _, child in ipairs(children) do
            local role = child:attributeValue("AXRole")
            if role == "AXSheet" or role == "AXDialog" then
                local pos = child:attributeValue("AXPosition")
                local size = child:attributeValue("AXSize")
                if pos and size then
                    if mousePos.x >= pos.x and mousePos.x <= pos.x + size.w and
                       mousePos.y >= pos.y and mousePos.y <= pos.y + size.h then
                        return child -- Return the AX element
                    end
                end
            end
        end
    end
    return nil
end

-- Log file setup
local logfilePath = os.getenv("HOME") .. "/hammerspoon_clickthrough.log"
local logfile = assert(io.open(logfilePath, "a"))
local function log(message, level)
    level = level or "INFO"
    local timestamp = os.date("%H:%M:%S")
    logfile:write(string.format("%s [%s] %s\n", timestamp, level, message))
    logfile:flush()
end

-- Eventtap: Focus window under mouse and log click

clickLogger = hs.eventtap.new({hs.eventtap.event.types.leftMouseDown}, function(event)
    local win = windowUnderMouse()
    local frontmost = hs.window.frontmostWindow()
    if win then
        -- If it's a normal window
        if win.id and win.title then
            if win:id() ~= (frontmost and frontmost:id()) then
                win:focus()
                log("Focused window: " .. (win:title() or "Untitled"))
            else
                log("Clicked already-focused window: " .. (win:title() or "Untitled"))
            end
        else
            -- It's an AX element (e.g. About menu)
            local role = win:attributeValue("AXRole") or "AXUIElement"
            local title = win:attributeValue("AXTitle") or role
            -- Try to focus the element (not always possible)
            if win:attributeValue("AXFocused") ~= true then
                pcall(function() win:setAttributeValue("AXFocused", true) end)
                log("Focused AX element: " .. title .. " (" .. role .. ")")
            else
                log("Clicked already-focused AX element: " .. title .. " (" .. role .. ")")
            end
        end
    else
        log("No window or AX element under mouse")
    end
    return false -- allow original click
end)

clickLogger:start()

-- Graceful shutdown
hs.shutdownCallback = function()
    log("Hammerspoon shutting down", "INFO")
    logfile:close()
end
