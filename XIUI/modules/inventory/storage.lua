--[[
    Storage Tracker Module
    Tracks Mog Storage (container ID 2)
]]

local BaseTracker = require('modules.inventory.base');

-- Container ID for Mog Storage in FFXI
local CONTAINER_STORAGE = 2;

return BaseTracker.Create({
    windowName = 'StorageTracker',
    containers = { CONTAINER_STORAGE },
    configPrefix = 'storageTracker',
    colorKey = 'storageTracker',
});
