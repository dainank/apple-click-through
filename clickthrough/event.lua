local hs = rawget(_G, "hs")
local logging = require("clickthrough.logging")
local utils = require("clickthrough.utils")
local target = require("clickthrough.target")
local ax_utils = require("clickthrough.ax_utils")

local log = logging.log
local clickLogger
local debugTimer
local watchdogTimer
local lastClickTime = 0

local function shouldDisableClickThrough()
    local frontmost = hs.window.frontmostWindow()
    if not frontmost then
        return false
    end

    local ok, isFullScreen = pcall(function()
        return frontmost:isFullScreen()
    end)
    if ok and isFullScreen then
        return true
    end

    local okApp, app = pcall(function()
        return frontmost:application()
    end)
    if okApp and app and utils.getAxAttribute(app, "AXFullScreen", false) then
        return true
    end

    return false
end

local function onClick(event)
    if shouldDisableClickThrough() then
        log("Skipping click-through: fullscreen mode detected")
        return false
    end

    local now = hs.timer.secondsSinceEpoch()
    if (now - lastClickTime) < 0.05 then
        return false
    end
    lastClickTime = now

    local mouseCursorType = hs.mouse.currentCursorType()
    local cursorName = tostring(mouseCursorType or "")
    local skipOnCursor = {
        operationNotAllowedCursor = true,
        contextualMenuCursor = true,
        closedHandCursor = true,
        crosshairCursor = true,
        disappearingItemCursor = true,
        dragCopyCursor = true,
        dragLinkCursor = true,
        resizeDownCursor = true,
        resizeLeftCursor = true,
        resizeLeftRightCursor = true,
        resizeRightCursor = true,
        resizeUpCursor = true,
        resizeUpDownCursor = true,
        unknown = true,
        unknownCursor = true,
    }

    log("mouseCursorType: " .. cursorName)
    if cursorName ~= "" and skipOnCursor[cursorName] then
        log("Skip on mouseCursorType: " .. cursorName)
        return false
    end

    local mousePos = hs.mouse.absolutePosition()
    local targetResult = target.findTarget(mousePos)
    if not targetResult then
        log("No window or AX element under mouse")
        return false
    end

    if targetResult.kind == "window" then
        local win = targetResult.win
        local ok, subrole = pcall(function()
            return win:subrole()
        end)
        if ok and subrole == "AXDialog" then
            log("Skip: target window is a dialog (" .. (win:title() or "?") .. ")")
            return false
        end

        local SKIP_FOR_WINDOW_TITLES = {
            ["Sharing Indicator"] = true,
        }

        local frontmost = hs.window.frontmostWindow()
        local winTitle = win:title() or "-Untitled-"
        if win:id() == (frontmost and frontmost:id()) then
            log("Clicked already-focused window: " .. (win:title() or "Untitled"))
        elseif SKIP_FOR_WINDOW_TITLES[winTitle] then
            log("Skip: special window: " .. winTitle)
            return false
        else
            win:focus()
            log("Focused window: " .. (win:title() or "Untitled"))
        end
    else
        local elem = targetResult.elem
        local role = utils.getAxAttribute(elem, "AXRole") or "AXUIElement"
        local title = utils.getAxAttribute(elem, "AXTitle") or role

        local MENU_ROLES = {
            AXMenu = true,
            AXMenuItem = true,
            AXMenuBar = true,
            AXMenuBarItem = true,
        }
        if MENU_ROLES[role] then
            log("Skip: clicked menu element (" .. role .. ")")
            return false
        end

        local axWin = ax_utils.findAxWindowAncestor(elem)
        if axWin then
            local subrole = utils.getAxAttribute(axWin, "AXSubrole")
            if subrole == "AXDialog" then
                log("Skip: AX element is inside a dialog (" .. title .. ")")
                return false
            end

            local parentWin = ax_utils.hsWindowFromAxWindow(axWin)
            if parentWin then
                local frontmost = hs.window.frontmostWindow()
                if parentWin:id() ~= (frontmost and frontmost:id()) then
                    parentWin:focus()
                    log("Raised parent window: " .. (parentWin:title() or "Untitled"))
                end
            end
        end

        local isFocused = utils.getAxAttribute(elem, "AXFocused")
        if isFocused ~= true then
            utils.setAxAttribute(elem, "AXFocused", true)
            log("Focused AX element: " .. title .. " (" .. role .. ")")
        else
            log("Clicked already-focused AX element: " .. title .. " (" .. role .. ")")
        end
    end

    return false
end

local function start()
    if clickLogger then
        return
    end

    clickLogger = hs.eventtap.new({ hs.eventtap.event.types.leftMouseDown }, function(event)
        return onClick(event)
    end)
    clickLogger:start()
    log("Click-through event tap started", "INFO")

    debugTimer = hs.timer.new(10, function()
        local enabled = clickLogger and clickLogger:isEnabled()
        log(string.format("Event tap health check — isEnabled: %s", tostring(enabled)), "DEBUG")
    end)
    debugTimer:start()
    log("Debug health-check timer started (10 s interval)", "DEBUG")

    watchdogTimer = hs.timer.new(5, function()
        if clickLogger and not clickLogger:isEnabled() then
            log("Event tap was disabled by macOS watchdog — restarting", "WARN")
            clickLogger:start()
        end
    end)
    watchdogTimer:start()
    log("Watchdog timer started (5 s interval)", "INFO")
end

local function stop()
    if watchdogTimer then
        watchdogTimer:stop()
        watchdogTimer = nil
    end
    if debugTimer then
        debugTimer:stop()
        debugTimer = nil
    end
    if clickLogger then
        clickLogger:stop()
        clickLogger = nil
    end
end

return {
    start = start,
    stop = stop,
}
