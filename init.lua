-- Guard flag to prevent infinite click loops
local isSyntheticClick = false

clickLogger = hs.eventtap.new({hs.eventtap.event.types.leftMouseDown}, function(event)
    if isSyntheticClick then
        isSyntheticClick = false
        return false
    end

    local mousePos = hs.mouse.absolutePosition()
    
    -- Find the window under the mouse using only standard window objects
    local allWindows = hs.window.orderedWindows()
    local targetWin = nil

    for _, win in ipairs(allWindows) do
        local frame = win:frame()
        if win:isVisible() and 
           mousePos.x >= frame.x and mousePos.x <= (frame.x + frame.w) and 
           mousePos.y >= frame.y and mousePos.y <= (frame.y + frame.h) then
            targetWin = win
            break
        end
    end

    if targetWin then
        local frontmost = hs.window.frontmostWindow()
        
        -- Only intervene if the window under the mouse isn't already focused
        if not frontmost or targetWin:id() ~= frontmost:id() then
            targetWin:focus()
            
            -- Re-send the click so it actually "hits" the button/text field
            hs.timer.doAfter(0.1, function()
                isSyntheticClick = true
                hs.eventtap.leftClick(mousePos)
            end)
            return true -- Consume the original click
        end
    end

    return false -- Pass original click through if window is already focused
end)

clickLogger:start()
