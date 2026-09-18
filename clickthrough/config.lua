local DEFAULT_EXCLUDED_BUNDLE_IDS = {
    ["com.apple.controlcenter"] = true,
    ["com.apple.notificationcenterui"] = true,
    ["com.apple.systemuiserver"] = true,
}

local DEFAULT_EXCLUDED_WINDOW_TITLES = {
    ["Sharing Indicator"] = true,
}

local function addConfiguredValues(values, destination)
    for _, value in ipairs(values or {}) do
        destination[value] = true
    end
end

local function loadUserConfig()
    local ok, userConfig = pcall(require, "clickthrough_config")
    if ok and type(userConfig) == "table" then
        return userConfig
    end
    return {}
end

local userConfig = loadUserConfig()
local excludedBundleIDs = {}
local excludedAppNames = {}
local excludedWindowTitles = {}

for bundleID in pairs(DEFAULT_EXCLUDED_BUNDLE_IDS) do
    excludedBundleIDs[bundleID] = true
end
for title in pairs(DEFAULT_EXCLUDED_WINDOW_TITLES) do
    excludedWindowTitles[title] = true
end

addConfiguredValues(userConfig.excludedBundleIDs, excludedBundleIDs)
addConfiguredValues(userConfig.excludedAppNames, excludedAppNames)
addConfiguredValues(userConfig.excludedWindowTitles, excludedWindowTitles)

local function applicationDetails(win)
    local okApp, app = pcall(function()
        return win:application()
    end)
    if not okApp or not app then
        return nil, nil
    end

    local okName, name = pcall(function()
        return app:name()
    end)
    local okBundleID, bundleID = pcall(function()
        return app:bundleID()
    end)
    return okName and name or nil, okBundleID and bundleID or nil
end

local function isExcluded(win)
    if not win then
        return false
    end

    local appName, bundleID = applicationDetails(win)
    return (bundleID and excludedBundleIDs[bundleID])
        or (appName and excludedAppNames[appName])
        or false
end

local function describeWindow(win)
    if not win then
        return "app: unknown, bundle ID: unknown, window: unknown"
    end

    local appName, bundleID = applicationDetails(win)
    local okTitle, title = pcall(function()
        return win:title()
    end)
    return string.format(
        "app: %s, bundle ID: %s, window: %s",
        appName or "unknown",
        bundleID or "unknown",
        (okTitle and title) or "Untitled"
    )
end

local function isExcludedWindowTitle(title)
    return title and excludedWindowTitles[title] or false
end

return {
    isExcluded = isExcluded,
    isExcludedWindowTitle = isExcludedWindowTitle,
    describeWindow = describeWindow,
}