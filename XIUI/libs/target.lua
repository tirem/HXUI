--[[
* XIUI Target Utilities
* Target detection and sub-target handling
]]--

local M = {};

-- ========================================
-- ST (Sub-Target) Party Index
-- ========================================

function M.GetStPartyIndex()
    local ptr = AshitaCore:GetPointerManager():Get('party');
    ptr = ashita.memory.read_uint32(ptr);
    ptr = ashita.memory.read_uint32(ptr);
    local isActive = (ashita.memory.read_uint32(ptr + 0x54) ~= 0);
    if isActive then
        return ashita.memory.read_uint8(ptr + 0x50);
    else
        return nil;
    end
end

-- ========================================
-- Sub-Target Detection
-- ========================================

function M.GetSubTargetActive()
    local playerTarget = AshitaCore:GetMemoryManager():GetTarget();
    if (playerTarget == nil) then
        return false;
    end
    return playerTarget:GetIsSubTargetActive() == 1 or (M.GetStPartyIndex() ~= nil and playerTarget:GetTargetIndex(0) ~= 0);
end

-- ========================================
-- Target Retrieval
-- ========================================

-- Returns mainTarget, secondaryTarget indices
function M.GetTargets()
    local playerTarget = AshitaCore:GetMemoryManager():GetTarget();
    local party = AshitaCore:GetMemoryManager():GetParty();

    if (playerTarget == nil or party == nil) then
        return nil, nil;
    end

    local mainTarget = playerTarget:GetTargetIndex(0);
    local secondaryTarget = playerTarget:GetTargetIndex(1);
    local partyTarget = M.GetStPartyIndex();

    if (partyTarget ~= nil) then
        secondaryTarget = mainTarget;
        mainTarget = party:GetMemberTargetIndex(partyTarget);
    end

    return mainTarget, secondaryTarget;
end

-- ========================================
-- Lock-On Detection
-- ========================================

function M.GetIsTargetLockedOn()
    local playerTarget = AshitaCore:GetMemoryManager():GetTarget();
    if (playerTarget == nil) then
        return false;
    end

    -- Check if the target window is locked on using GetLockedOnFlags
    if (playerTarget.GetLockedOnFlags ~= nil) then
        local flags = playerTarget:GetLockedOnFlags();
        -- flags > 0 indicates target is locked on
        return flags > 0;
    end

    -- Fallback: method not available
    return false;
end

return M;
