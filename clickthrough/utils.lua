local function getAxAttribute(elem, attrName, defaultValue)
    if not elem then
        return defaultValue
    end

    local ok, value = pcall(function()
        return elem:attributeValue(attrName)
    end)

    return ok and value or defaultValue
end

local function setAxAttribute(elem, attrName, value)
    if not elem then
        return false
    end

    local ok = pcall(function()
        elem:setAttributeValue(attrName, value)
    end)

    return ok
end

local function rectContains(mousePos, frame)
    if not frame or not mousePos then
        return false
    end

    return mousePos.x >= frame.x
       and mousePos.x <= frame.x + frame.w
       and mousePos.y >= frame.y
       and mousePos.y <= frame.y + frame.h
end

return {
    getAxAttribute = getAxAttribute,
    setAxAttribute = setAxAttribute,
    rectContains    = rectContains,
}
