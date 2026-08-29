local hs = rawget(_G, "hs")
if not hs then
    error("This module must run inside Hammerspoon.")
end

return require("clickthrough.main")
