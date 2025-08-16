-- Helper: Find window under mouse
local function windowUnderMouse()
    local mousePos = hs.mouse.absolutePosition()
    for _, win in ipairs(hs.window.orderedWindows()) do
        if win:isVisible() then
            local frame = win:frame()
            if mousePos.x >= frame.x and mousePos.x <= frame.x + frame.w and
               mousePos.y >= frame.y and mousePos.y <= frame.y + frame.h then
                return win
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
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    logfile:write(string.format("%s [%s] %s\n", timestamp, level, message))
    logfile:flush()
end

-- Eventtap: Focus window under mouse and log click
local clickLogger = hs.eventtap.new({hs.eventtap.event.types.leftMouseDown}, function(event)
    local win = windowUnderMouse()
    local frontmost = hs.window.frontmostWindow()
    if win then
        if win:id() ~= (frontmost and frontmost:id()) then
            win:focus()
            log("Focused window: " .. (win:title() or "Untitled"))
        else
            log("Clicked already-focused window: " .. (win:title() or "Untitled"))
        end
    else
        log("No window under mouse")
    end
    return false -- allow original click
end)

clickLogger:start()

-- Graceful shutdown
hs.shutdownCallback = function()
    log("Hammerspoon shutting down", "INFO")
    logfile:close()
end
