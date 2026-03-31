-- Helper: Find window under mouse
local function windowUnderMouse()
    local mousePos = hs.mouse.absolutePosition()

    local function rectContains(pos, size)
        if not pos or not size then return false end
        local x = pos.x or pos.X or pos[1]
        local y = pos.y or pos.Y or pos[2]
        local w = size.w or size.width or size[1]
        local h = size.h or size.height or size[2]
        if not (x and y and w and h) then return false end
        return mousePos.x >= x and mousePos.x <= (x + w) and mousePos.y >= y and mousePos.y <= (y + h)
    end

    -- 1) Check normal Hammerspoon window objects (ordered by z-order)
    for _, win in ipairs(hs.window.orderedWindows()) do
        local ok, vis = pcall(function() return win:isVisible() end)
        if ok and vis then
            local frame = win:frame()
            if frame and rectContains({x = frame.x, y = frame.y}, {w = frame.w, h = frame.h}) then
                return win
            end
        end
    end

    -- 2) Also check any visible windows listing (some windows may not appear in orderedWindows)
    if hs.window.visibleWindows then
        for _, win in ipairs(hs.window.visibleWindows()) do
            local ok, vis = pcall(function() return win:isVisible() end)
            if ok and vis then
                local frame = win:frame()
                if frame and rectContains({x = frame.x, y = frame.y}, {w = frame.w, h = frame.h}) then
                    return win
                end
            end
        end
    end

    -- 3) Recursively scan accessibility (AX) elements across all running applications.
    local function findAxElementAtPoint(elem)
        if not elem then return nil end
        local okRole, role = pcall(function() return elem:attributeValue("AXRole") end)
        if not okRole then return nil end

        local okPos, pos = pcall(function() return elem:attributeValue("AXPosition") end)
        local okSize, size = pcall(function() return elem:attributeValue("AXSize") end)
        local okVisible, visible = pcall(function() return elem:attributeValue("AXVisible") end)

        if okPos and okSize and pos and size then
            -- If AXVisible is not provided, assume visible (some apps omit it)
            if (visible == nil) or (visible == true) then
                if rectContains(pos, size) then
                    return elem
                end
            end
        end

        -- Recurse into AXChildren
        local okChildren, children = pcall(function() return elem:attributeValue("AXChildren") end)
        if okChildren and children and type(children) == "table" then
            for _, child in ipairs(children) do
                local found = findAxElementAtPoint(child)
                if found then return found end
            end
        end

        -- Also check AXWindows attribute if present
        local okWindows, winChildren = pcall(function() return elem:attributeValue("AXWindows") end)
        if okWindows and winChildren and type(winChildren) == "table" then
            for _, child in ipairs(winChildren) do
                local found = findAxElementAtPoint(child)
                if found then return found end
            end
        end

        return nil
    end

    -- Iterate all running applications to catch panels, popovers, toolbars, etc.
    for _, app in ipairs(hs.application.runningApplications()) do
        local axApp = nil
        local okApp, appElem = pcall(function() return hs.axuielement.applicationElement(app) end)
        if okApp then axApp = appElem end
        if axApp then
            local ok, windowsAttr = pcall(function() return axApp:attributeValue("AXWindows") end)
            if ok and windowsAttr and type(windowsAttr) == "table" then
                for _, e in ipairs(windowsAttr) do
                    local found = findAxElementAtPoint(e)
                    if found then return found end
                end
            end

            local okC, children = pcall(function() return axApp:attributeValue("AXChildren") end)
            if okC and children and type(children) == "table" then
                for _, e in ipairs(children) do
                    local found = findAxElementAtPoint(e)
                    if found then return found end
                end
            end
        end
    end

    -- 4) As a last resort, check the system-wide accessibility tree (menus, status items)
    local okSys, sys = pcall(function() return hs.axuielement.systemWide() end)
    if okSys and sys then
        local found = findAxElementAtPoint(sys)
        if found then return found end
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

-- Guard flag: synthetic clicks re-trigger the event tap, so we detect and pass them through
local isSyntheticClick = false

-- Eventtap: Focus window under mouse and log click (with menu/dialog handling)

clickLogger = hs.eventtap.new({hs.eventtap.event.types.leftMouseDown}, function(event)
    if isSyntheticClick then
        isSyntheticClick = false
        return false
    end
    local ax = require("hs.axuielement")
    local mousePos = hs.mouse.absolutePosition()
    local element = ax.systemElementAtPosition(mousePos)

    if element then
        local role = element:attributeValue("AXRole")
        log("role: " .. (role or "Untitled role"))
        if role == "AXMenu" or role == "AXMenuItem" then
            log("Skip on role: " .. role)
            return false -- allow original click
        end
    end

    local frontmost = hs.window.frontmostWindow()
    if frontmost and frontmost:subrole() == "AXDialog" then
        log("Skip on subrole: " .. frontmost:subrole())
        return false -- allow original click
    end

    local win = windowUnderMouse()
    if win then
        -- If it's a normal window
        if win.id and win.title then
            if win:id() ~= (frontmost and frontmost:id()) then
                win:focus()
                log("Focused window: " .. (win:title() or "Untitled"))
                -- Consume original click, then post a synthetic click after
                -- macOS completes the focus transition (~30-60ms).
                -- Without this, text fields in the newly-focused window
                -- swallow the click before they're properly active.
                local clickPos = mousePos
                hs.timer.doAfter(0.08, function()
                    isSyntheticClick = true
                    hs.eventtap.leftClick(clickPos)
                end)
                return true -- consume original click
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
