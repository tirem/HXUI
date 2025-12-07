--[[
    Safe Tracker Module
    Tracks Mog Safe (container ID 1) and Mog Safe 2 (container ID 9)
]]

local BaseTracker = require('modules.inventory.base');

-- Container IDs for Mog Safe and Mog Safe 2 in FFXI
local CONTAINER_SAFE = 1;
local CONTAINER_SAFE2 = 9;

return BaseTracker.Create({
    windowName = 'SafeTracker',
    containers = { CONTAINER_SAFE, CONTAINER_SAFE2 },
    containerLabels = { 'S1', 'S2' },
    configPrefix = 'safeTracker',
    colorKey = 'safeTracker',
});
