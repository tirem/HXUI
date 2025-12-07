--[[
    Locker Tracker Module
    Tracks Mog Locker (container ID 4)
]]

local BaseTracker = require('modules.inventory.base');

-- Container ID for Mog Locker in FFXI
local CONTAINER_LOCKER = 4;

return BaseTracker.Create({
    windowName = 'LockerTracker',
    containers = { CONTAINER_LOCKER },
    containerLabels = { 'Locker' },
    configPrefix = 'lockerTracker',
    colorKey = 'lockerTracker',
});
