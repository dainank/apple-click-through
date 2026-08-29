local os = os
local io = io
local pcall = pcall
local print = print
local string = string

local logDirPath = os.getenv("HOME") .. "/Library/Logs/apple-click-through"
local logfilePath = logDirPath .. "/main.log"
local MAX_LOG_SIZE = 5 * 1024 * 1024
local logfile = nil

local function rotateLogIfNeeded()
    local f = io.open(logfilePath, "r")
    if not f then
        return
    end

    local size = f:seek("end")
    f:close()

    if size > MAX_LOG_SIZE then
        local backupPath = logfilePath .. "." .. os.date("%Y%m%d_%H%M%S")
        os.rename(logfilePath, backupPath)
    end
end

local function openLogFile()
    if logfile then
        pcall(function()
            logfile:close()
        end)
    end

    pcall(function()
        os.execute("mkdir -p '" .. logDirPath .. "'")
    end)

    rotateLogIfNeeded()
    logfile = io.open(logfilePath, "a")
end

local function log(message, level)
    level = level or "INFO"
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local line = string.format("%s [%s] %s\n", timestamp, level, message)

    if not logfile then
        pcall(openLogFile)
    end

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

local function close()
    if logfile then
        pcall(function()
            logfile:close()
        end)
        logfile = nil
    end
end

openLogFile()

return {
    log = log,
    close = close,
}
