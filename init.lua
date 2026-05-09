--[[
Apple Click-Through Script for Hammerspoon

Enables click-through behavior on macOS: automatically focuses the window or
accessibility element under the mouse on click, so a single click both focuses
the window and activates the clicked control.
--]]

local ax = require("hs.axuielement")

-- ============================================================================
-- HELPERS: Safe Attribute Access
-- ============================================================================

-- Safely read an AX attribute; returns defaultValue on any error.
local function getAxAttribute(elem, attrName, defaultValue)
    if not elem then return defaultValue end
    local ok, value = pcall(function() return elem:attributeValue(attrName) end)
    return ok and value or defaultValue
end

-- Safely write an AX attribute; returns true on success.
local function setAxAttribute(elem, attrName, value)
    if not elem then return false end
    local ok = pcall(function() elem:setAttributeValue(attrName, value) end)
    return ok
end

-- ============================================================================
-- LOGGING
-- ============================================================================

local logfilePath = os.getenv("HOME") .. "/hammerspoon_clickthrough.log"
local MAX_LOG_SIZE = 5 * 1024 * 1024  -- 5 MB
local logfile = nil

local function rotateLogIfNeeded()
    local f = io.open(logfilePath, "r")
    if not f then return end
    local size = f:seek("end")
    f:close()
    if size > MAX_LOG_SIZE then
        local backupPath = logfilePath .. "." .. os.date("%Y%m%d_%H%M%S")
        os.rename(logfilePath, backupPath)
    end
end

local function openLogFile()
    if logfile then pcall(function() logfile:close() end) end
    rotateLogIfNeeded()
    logfile = io.open(logfilePath, "a")
end

do
    local ok, err = pcall(openLogFile)
    if not ok or not logfile then
        print(string.format(
            "[clickthrough] WARNING: cannot open log file '%s': %s",
            logfilePath, tostring(err)
        ))
    end
end

local function log(message, level)
    level = level or "INFO"
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local line = string.format("%s [%s] %s\n", timestamp, level, message)

    if not logfile then pcall(openLogFile) end

    if logfile then
        local ok = pcall(function()
            logfile:write(line)
            logfile:flush()
        end)
        if not ok then
            pcall(openLogFile)
            if logfile then
                pcall(function()
                    logfile:write(line)
                    logfile:flush()
                end)
            else
                print(line)
            end
        end
    else
        print(line)
    end
end

-- ============================================================================
-- GEOMETRY
-- ============================================================================

-- AX always delivers proper {x,y}/{w,h} tables — dead .X and [1]
-- fallback branches removed. frame is an hs.geometry rect or equivalent table.
local function rectContains(mousePos, frame)
    if not frame or not mousePos then return false end
    return mousePos.x >= frame.x
       and mousePos.x <= frame.x + frame.w
       and mousePos.y >= frame.y
       and mousePos.y <= frame.y + frame.h
end

-- ============================================================================
-- AX UTILITIES
-- ============================================================================

local AX_ANCESTOR_DEPTH_LIMIT = 20

-- enclosing AXWindow element. Prevents stack overflow on cyclic/deep trees.
local function findAxWindowAncestor(elem)
    local current = elem
    for _ = 1, AX_ANCESTOR_DEPTH_LIMIT do
        if not current then break end
        if getAxAttribute(current, "AXRole") == "AXWindow" then
            return current
        end
        current = getAxAttribute(current, "AXParent")
    end
    return nil
end

-- frame coordinates (2 px tolerance for sub-pixel rendering differences).
local function hsWindowFromAxWindow(axWin)
    if not axWin then return nil end
    local pos  = getAxAttribute(axWin, "AXPosition")
    local size = getAxAttribute(axWin, "AXSize")
    if not pos or not size then return nil end

    for _, win in ipairs(hs.window.orderedWindows()) do
        local ok, frame = pcall(function() return win:frame() end)
        if ok and frame then
            if math.abs(frame.x - pos.x) <= 2
            and math.abs(frame.y - pos.y) <= 2
            and math.abs(frame.w - size.w) <= 2
            and math.abs(frame.h - size.h) <= 2 then
                return win
            end
        end
    end
    return nil
end

-- ============================================================================
-- TARGET DETECTION
-- ============================================================================

-- Returns a tagged result so callers never need to duck-type the return value:
--
--   { kind = "window", win  = <hs.window>  }   normal application window
--   { kind = "ax",     elem = <AX element> }   panel, popover, toolbar item, …
--   nil                                         nothing found
--
--         ax.systemElementAtPosition(), which performs the same search natively
--         and is orders of magnitude faster.
local function findTarget(mousePos)
    for _, win in ipairs(hs.window.orderedWindows()) do
        local ok, vis = pcall(function() return win:isVisible() end)
        if ok and vis then
            local frame = win:frame()
            if frame and rectContains(mousePos, frame) then
                return { kind = "window", win = win }
            end
        end
    end

    local ok, elem = pcall(function()
        return ax.systemElementAtPosition(mousePos)
    end)
    if ok and elem then
        return { kind = "ax", elem = elem }
    end

    return nil
end

-- ============================================================================
-- EVENT TAP
-- ============================================================================

local lastClickTime = 0

local clickLogger = hs.eventtap.new({ hs.eventtap.event.types.leftMouseDown },
function(event)  -- luacheck: ignore event (reserved for future use)

    -- skip clicks that arrive within 50 ms of the previous one
    -- (double-clicks, triple-clicks, OS auto-repeat) to avoid redundant work.
    local now = hs.timer.secondsSinceEpoch()
    if (now - lastClickTime) < 0.05 then
        return false
    end
    lastClickTime = now

    local mousePos = hs.mouse.absolutePosition()

    -- single detection call shared by both inspection and focus logic.
    local target = findTarget(mousePos)

    if not target then
        log("No window or AX element under mouse")
        return false
    end

    -- ── Normal window ─────────────────────────────────────────────────────────

    if target.kind == "window" then
        local win = target.win

        -- check the *target* window's subrole, not the frontmost one's.
        -- The original code skipped click-through only when the already-focused
        -- window was a dialog — the more important case (clicking *into* a
        -- background dialog) was never caught.
        local ok, subrole = pcall(function() return win:subrole() end)
        if ok and subrole == "AXDialog" then
            log("Skip: target window is a dialog (" .. (win:title() or "?") .. ")")
            return false
        end

        local frontmost = hs.window.frontmostWindow()
        if win:id() ~= (frontmost and frontmost:id()) then
            win:focus()
            log("Focused window: " .. (win:title() or "Untitled"))
        else
            log("Clicked already-focused window: " .. (win:title() or "Untitled"))
        end

    -- ── AX element (panel, popover, toolbar item, status-bar widget, …) ───────

    else
        local elem  = target.elem
        local role  = getAxAttribute(elem, "AXRole")  or "AXUIElement"
        local title = getAxAttribute(elem, "AXTitle") or role

        -- test the *element's* role for menu membership, not the
        -- frontmost window's class.
        local MENU_ROLES = {
            AXMenu        = true,
            AXMenuItem    = true,
            AXMenuBar     = true,
            AXMenuBarItem = true,
        }
        if MENU_ROLES[role] then
            log("Skip: clicked menu element (" .. role .. ")")
            return false
        end

        -- Walk up to the enclosing AXWindow for two purposes:
        --   detect if this element lives inside a dialog.
        --   raise the parent hs.window before focusing the element.
        local axWin = findAxWindowAncestor(elem)

        if axWin then
            -- Skip if the element is inside a dialog window.
            local subrole = getAxAttribute(axWin, "AXSubrole")
            if subrole == "AXDialog" then
                log("Skip: AX element is inside a dialog (" .. title .. ")")
                return false
            end

            -- focus (raise) the parent hs.window first so the element's
            -- window is actually in front before we activate the element itself.
            local parentWin = hsWindowFromAxWindow(axWin)
            if parentWin then
                local frontmost = hs.window.frontmostWindow()
                if parentWin:id() ~= (frontmost and frontmost:id()) then
                    parentWin:focus()
                    log("Raised parent window: " .. (parentWin:title() or "Untitled"))
                end
            end
        end

        -- Now focus the AX element itself.
        local isFocused = getAxAttribute(elem, "AXFocused")
        if isFocused ~= true then
            setAxAttribute(elem, "AXFocused", true)
            log("Focused AX element: " .. title .. " (" .. role .. ")")
        else
            log("Clicked already-focused AX element: " .. title .. " (" .. role .. ")")
        end
    end

    return false  -- always pass the original click through to the application
end)

clickLogger:start()
log("Click-through event tap started", "INFO")

-- ============================================================================
-- DEBUG TIMER  (W1)
-- Logs the event tap's enabled state every 10 seconds.
-- This lets you confirm whether macOS is silently killing the tap:
--   • You'll see "isEnabled: true" while everything works.
--   • The first "isEnabled: false" entry marks exactly when the tap died.
-- Remove or comment out this block once the root cause is confirmed.
-- ============================================================================

local debugTimer = hs.timer.new(10, function()
    local enabled = clickLogger:isEnabled()
    log(string.format("Event tap health check — isEnabled: %s", tostring(enabled)), "DEBUG")
end)

debugTimer:start()
log("Debug health-check timer started (10 s interval)", "DEBUG")

-- ============================================================================
-- WATCHDOG TIMER  (W2)
-- macOS silently disables event taps that block for too long (the OS watchdog).
-- This timer checks every 5 seconds and restarts the tap if that happened.
-- The WARN log entry tells you how often macOS is killing it.
-- ============================================================================

local watchdogTimer = hs.timer.new(5, function()
    if not clickLogger:isEnabled() then
        log("Event tap was disabled by macOS watchdog — restarting", "WARN")
        clickLogger:start()
    end
end)

watchdogTimer:start()
log("Watchdog timer started (5 s interval)", "INFO")

-- ============================================================================
-- SHUTDOWN
-- ============================================================================

-- preserve any shutdownCallback set by other modules instead of
-- silently replacing it.
local prevShutdownCallback = hs.shutdownCallback

hs.shutdownCallback = function()
    log("Hammerspoon shutting down — closing log", "INFO")
    watchdogTimer:stop()
    debugTimer:stop()
    if logfile then
        pcall(function() logfile:close() end)
        logfile = nil
    end
    if prevShutdownCallback then
        prevShutdownCallback()
    end
end