--[[
* XIUI Cast Cost Shared State
* Exposes current spell/ability cost data for other modules to consume
* (e.g., playerbar and partylist can show MP cost preview on their bars)
]]--

local M = {};

-- Current selection state (updated by castcost data layer)
local currentState = {
    active = false,      -- Whether a spell/ability menu is open with valid selection
    itemType = nil,      -- 'spell', 'ability', or 'mount'
    mpCost = 0,          -- MP cost of selected spell (0 for abilities/mounts)
    tpCost = 0,          -- TP cost (for weapon skills, future use)
    hasEnoughMp = true,  -- Whether player has enough MP
};

-- Update the shared state (called by castcost data/display layer)
function M.Update(itemInfo, itemType, playerMp)
    if itemInfo == nil then
        currentState.active = false;
        currentState.itemType = nil;
        currentState.mpCost = 0;
        currentState.tpCost = 0;
        currentState.hasEnoughMp = true;
        return;
    end

    currentState.active = true;
    currentState.itemType = itemType;
    currentState.mpCost = (itemType == 'spell' and itemInfo.mpCost) or 0;
    currentState.tpCost = 0; -- Future: weapon skill TP cost
    currentState.hasEnoughMp = (playerMp or 0) >= currentState.mpCost;
end

-- Clear the shared state (called when menu closes)
function M.Clear()
    currentState.active = false;
    currentState.itemType = nil;
    currentState.mpCost = 0;
    currentState.tpCost = 0;
    currentState.hasEnoughMp = true;
end

-- Get current MP cost for display on other modules' MP bars
-- Returns: mpCost (number), hasEnoughMp (boolean), isActive (boolean)
function M.GetMpCost()
    if not currentState.active or currentState.itemType ~= 'spell' then
        return 0, true, false;
    end
    return currentState.mpCost, currentState.hasEnoughMp, true;
end

-- Check if there's an active spell selection
function M.IsSpellActive()
    return currentState.active and currentState.itemType == 'spell';
end

-- Get the full current state (for debugging or advanced use)
function M.GetState()
    return currentState;
end

return M;
