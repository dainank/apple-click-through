local hs = rawget(_G, "hs")
if not hs then
    error("This script must run inside Hammerspoon.")
end

return require("clickthrough")
