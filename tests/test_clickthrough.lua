-- Run: lua tests/test_clickthrough.lua   (from the repo or ~/.hammerspoon)
-- Stubs the bits of Hammerspoon that clickthrough/event.lua touches and checks what a click does.
local root = debug.getinfo(1, "S").source:match("^@(.*)tests/[^/]*$") or ""
package.path = root .. "?.lua;" .. root .. "?/init.lua;" .. package.path
package.loaded["clickthrough.logging"] = { log = function() end, close = function() end }

local function element(attrs)
    local e = { attrs = attrs, writes = {} }
    function e:attributeValue(name) return self.attrs[name] end
    function e:setAttributeValue(name, value) table.insert(self.writes, name); self.attrs[name] = value end
    return e
end

local function window(id, frame)
    local w = { focused = 0 }
    function w:id() return id end
    function w:title() return "win" .. id end
    function w:subrole() return "AXStandardWindow" end
    function w:frame() return frame end
    function w:isVisible() return true end
    function w:isFullScreen() return false end
    function w:application() return nil end
    function w:focus() self.focused = self.focused + 1 end
    return w
end

local frame = { x = 0, y = 0, w = 800, h = 600 }
local front, back = window(1, frame), window(2, { x = 900, y = 0, w = 800, h = 600 })
local underMouse, tapCallback

_G.hs = {
    window = {
        frontmostWindow = function() return front end,
        orderedWindows = function() return { front, back } end,
    },
    mouse = {
        currentCursorType = function() return "arrowCursor" end,
        absolutePosition = function() return { x = 100, y = 100 } end,
    },
    timer = {
        secondsSinceEpoch = (function() local t = 0; return function() t = t + 1; return t end end)(),
        new = function() return { start = function() end, stop = function() end } end,
    },
    eventtap = {
        event = { types = { leftMouseDown = 1 } },
        new = function(_, fn)
            tapCallback = fn
            return { start = function() end, stop = function() end, isEnabled = function() return true end }
        end,
    },
}
package.preload["hs.axuielement"] = function()
    return { systemElementAtPosition = function() return underMouse end }
end

local event = require("clickthrough.event")
event.start()

local failures = 0
local function check(name, ok)
    print((ok and "ok   " or "FAIL ") .. name)
    if not ok then failures = failures + 1 end
end

local function scrollArea(win, f)
    local axWin = element({ AXRole = "AXWindow", AXSubrole = "AXStandardWindow",
        AXPosition = { x = f.x, y = f.y }, AXSize = { w = f.w, h = f.h } })
    return element({ AXRole = "AXScrollArea", AXFocused = false, AXParent = axWin })
end

-- Click inside the window that's already in front: the click must pass through untouched.
-- Writing AXFocused here makes browsers/Electron apps scroll the element into view (jump to top).
underMouse = scrollArea(front, frame)
check("front click passes the event through", tapCallback({}) == false)
check("front click writes no AX attribute", #underMouse.writes == 0)

-- Click inside a background window: raise that window, still no AXFocused write.
underMouse = scrollArea(back, back:frame())
tapCallback({})
check("background click focuses the window", back.focused == 1)
check("background click writes no AX attribute", #underMouse.writes == 0)

os.exit(failures == 0 and 0 or 1)
