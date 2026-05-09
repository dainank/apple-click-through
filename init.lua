--[[
Apple Click-Through Script for Hammerspoon

This script enables click-through behavior on macOS by automatically focusing
the window or accessibility element under the mouse pointer when clicked.
It logs all interactions to a file for debugging and monitoring.

Features:
  - Auto-focuses windows on click
  - Handles dialogs, menus, and AX elements
  - Comprehensive logging with rotation
  - Graceful error handling
]]

local ax = require("hs.axuielement")

-- ============================================================================
-- HELPERS: Safe Attribute Access
-- ============================================================================

-- Safely get an AX element attribute with error handling
local function getAxAttribute(elem, attrName, defaultValue)
    if not elem then return defaultValue end
    local ok, value = pcall(function() return elem:attributeValue(attrName) end)
    return ok and value or defaultValue
end

-- Safely set an AX element attribute
local function setAxAttribute(elem, attrName, value)
    if not elem then return false end
    local ok = pcall(function() elem:setAttributeValue(attrName, value) end)
    return ok
end

-- ============================================================================
-- LOGGING with Rotation
-- ============================================================================

local logfilePath = os.getenv("HOME") .. "/hammerspoon_clickthrough.log"
local MAX_LOG_SIZE = 5 * 1024 * 1024  -- 5 MB
local logfile = nil

local function rotateLogIfNeeded()
    local f = io.open(logfilePath, "r")
    if f then
        local size = f:seek("end")
        f:close()
        
        if size > MAX_LOG_SIZE then
            local backupPath = logfilePath .. ".1"
            os.rename(logfilePath, backupPath)
        end
    end
end

local function openLogFile()
    rotateLogIfNeeded()
    logfile = io.open(logfilePath, "a")
    if not logfile then
        error("Failed to open log file: " .. logfilePath)
    end
end

openLogFile()

local function log(message, level)
    if not logfile then openLogFile() end
    level = level or "INFO"
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local success = pcall(function()
        logfile:write(string.format("%s [%s] %s\n", timestamp, level, message))
        logfile:flush()
    end)
    if not success then
        openLogFile()
    end
end

-- ============================================================================
-- WINDOW DETECTION
-- ============================================================================

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
        
        local role = getAxAttribute(elem, "AXRole")
        if not role then return nil end

        local pos = getAxAttribute(elem, "AXPosition")
        local size = getAxAttribute(elem, "AXSize")
        local visible = getAxAttribute(elem, "AXVisible")

        if pos and size then
            -- If AXVisible is not provided, assume visible (some apps omit it)
            if (visible == nil) or (visible == true) then
                if rectContains(pos, size) then
                    return elem
                end
            end
        end

        -- Recurse into AXChildren
        local children = getAxAttribute(elem, "AXChildren")
        if children and type(children) == "table" then
            for _, child in ipairs(children) do
                local found = findAxElementAtPoint(child)
                if found then return found end
            end
        end

        -- Also check AXWindows attribute if present
        local winChildren = getAxAttribute(elem, "AXWindows")
        if winChildren and type(winChildren) == "table" then
            for _, child in ipairs(winChildren) do
                local found = findAxElementAtPoint(child)
                if found then return found end
            end
        end

        return nil
    end

    -- Iterate all running applications to catch panels, popovers, toolbars, etc.
    for _, app in ipairs(hs.application.runningApplications()) do
        local ok, axApp = pcall(function() return ax.applicationElement(app) end)
        if ok and axApp then
            local windowsAttr = getAxAttribute(axApp, "AXWindows")
            if windowsAttr and type(windowsAttr) == "table" then
                for _, e in ipairs(windowsAttr) do
                    local found = findAxElementAtPoint(e)
                    if found then return found end
                end
            end

            local children = getAxAttribute(axApp, "AXChildren")
            if children and type(children) == "table" then
                for _, e in ipairs(children) do
                    local found = findAxElementAtPoint(e)
                    if found then return found end
                end
            end
        end
    end

    -- 4) As a last resort, check the system-wide accessibility tree (menus, status items)
    local ok, sys = pcall(function() return ax.systemWide() end)
    if ok and sys then
        local found = findAxElementAtPoint(sys)
        if found then return found end
    end

    return nil
end

-- ============================================================================
-- EVENT TAP: Focus window/element under mouse on click
-- ============================================================================

clickLogger = hs.eventtap.new({hs.eventtap.event.types.leftMouseDown}, function(event)
    local element = ax.systemElementAtPosition(hs.mouse.absolutePosition())

    -- Skip clicks on menus
    if element then
        local role = getAxAttribute(element, "AXRole")
        log("role: " .. (role or "Untitled role"))
        if role == "AXMenu" or role == "AXMenuItem" then
            log("Skip on role: " .. role)
            return false -- allow original click
        end
    end

    -- Skip clicks on dialogs
    local frontmost = hs.window.frontmostWindow()
    if frontmost and frontmost:subrole() == "AXDialog" then
        log("Skip on subrole: " .. frontmost:subrole())
        return false -- allow original click
    end

    local target = windowUnderMouse()
    if target then
        -- If it's a normal window
        if target.id and target.title then
            if target:id() ~= (frontmost and frontmost:id()) then
                target:focus()
                log("Focused window: " .. (target:title() or "Untitled"))
            else
                log("Clicked already-focused window: " .. (target:title() or "Untitled"))
            end
        else
            -- It's an AX element (e.g. About menu, popover, etc.)
            local role = getAxAttribute(target, "AXRole") or "AXUIElement"
            local title = getAxAttribute(target, "AXTitle") or role
            local isFocused = getAxAttribute(target, "AXFocused")
            
            if isFocused ~= true then
                setAxAttribute(target, "AXFocused", true)
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

-- ============================================================================
-- SHUTDOWN: Graceful cleanup
-- ============================================================================

hs.shutdownCallback = function()
    log("Hammerspoon shutting down", "INFO")
    if logfile then
        pcall(function() logfile:close() end)
    end
end
