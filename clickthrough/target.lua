local hs = rawget(_G, "hs")
local ax = require("hs.axuielement")
local utils = require("clickthrough.utils")

local function findTarget(mousePos)
    local ok, elem = pcall(function()
        return ax.systemElementAtPosition(mousePos)
    end)
    if ok and elem then
        return { kind = "ax", elem = elem }
    end

    for _, win in ipairs(hs.window.orderedWindows() or {}) do
        local okWin, vis = pcall(function()
            return win:isVisible()
        end)
        if okWin and vis then
            local frame = win:frame()
            if frame and utils.rectContains(mousePos, frame) then
                return { kind = "window", win = win }
            end
        end
    end

    return nil
end

return {
    findTarget = findTarget,
}
