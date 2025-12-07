--[[
    Inventory Tracker Module
    Tracks main inventory (container ID 0)
]]

local BaseTracker = require('modules.inventory.base');

-- Container ID for main Inventory in FFXI
local CONTAINER_INVENTORY = 0;

return BaseTracker.Create({
    windowName = 'InventoryTracker',
    containers = { CONTAINER_INVENTORY },
    containerLabels = { 'Inv' },
    configPrefix = 'inventoryTracker',
    colorKey = 'inventoryTracker',
});
