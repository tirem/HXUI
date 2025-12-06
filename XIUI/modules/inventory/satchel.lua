--[[
    Satchel Tracker Module
    Tracks Mog Satchel (container ID 5)
]]

local BaseTracker = require('modules.inventory.base');

-- Container ID for Mog Satchel in FFXI
local CONTAINER_SATCHEL = 5;

return BaseTracker.Create({
    windowName = 'SatchelTracker',
    containers = { CONTAINER_SATCHEL },
    configPrefix = 'satchelTracker',
    colorKey = 'satchelTracker',
});
