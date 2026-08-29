local hs = rawget(_G, "hs")
local event = require("clickthrough.event")
local logging = require("clickthrough.logging")

local prevShutdownCallback = hs.shutdownCallback

local function shutdown()
    logging.log("Hammerspoon shutting down — closing log", "INFO")
    event.stop()
    logging.close()
    if prevShutdownCallback then
        prevShutdownCallback()
    end
end

event.start()
hs.shutdownCallback = shutdown

return {
    start = event.start,
    stop = event.stop,
}
