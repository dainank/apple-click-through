local hs = rawget(_G, "hs")
local utils = require("clickthrough.utils")

local AX_ANCESTOR_DEPTH_LIMIT = 20

local function findAxWindowAncestor(elem)
    local current = elem
    for _ = 1, AX_ANCESTOR_DEPTH_LIMIT do
        if not current then
            break
        end

        if utils.getAxAttribute(current, "AXRole") == "AXWindow" then
            return current
        end

        current = utils.getAxAttribute(current, "AXParent")
    end

    return nil
end

local function hsWindowFromAxWindow(axWin)
    if not axWin then
        return nil
    end

    local pos = utils.getAxAttribute(axWin, "AXPosition")
    local size = utils.getAxAttribute(axWin, "AXSize")
    if not pos or not size then
        return nil
    end

    for _, win in ipairs(hs.window.orderedWindows() or {}) do
        local ok, frame = pcall(function()
            return win:frame()
        end)
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

return {
    findAxWindowAncestor = findAxWindowAncestor,
    hsWindowFromAxWindow = hsWindowFromAxWindow,
}
