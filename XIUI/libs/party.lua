--[[
* XIUI Party Utilities
* Party member cache and membership detection
* Provides O(1) lookups for party membership checks
]]--

local M = {};

-- ========================================
-- Party Member Cache
-- ========================================
-- Caches party member target indices and server IDs to avoid O(n) lookups every frame
local partyMemberIndices = {};
local partyMemberServerIds = {};
local partyMemberIndicesDirty = true;

-- Internal function to update the party cache
local function UpdatePartyCache()
    local party = AshitaCore:GetMemoryManager():GetParty();
    if party == nil then
        partyMemberIndices = {};
        partyMemberServerIds = {};
        partyMemberIndicesDirty = false;
        return;
    end

    partyMemberIndices = {};
    partyMemberServerIds = {};
    for i = 0, 17 do
        if (party:GetMemberIsActive(i) == 1) then
            local idx = party:GetMemberTargetIndex(i);
            local serverId = party:GetMemberServerId(i);
            if idx ~= 0 then
                partyMemberIndices[idx] = true;
            end
            if serverId ~= 0 then
                partyMemberServerIds[serverId] = true;
            end
        end
    end
    partyMemberIndicesDirty = false;
end

-- ========================================
-- Public API
-- ========================================

-- Mark party cache as dirty (to be called when party changes)
function M.MarkPartyCacheDirty()
    partyMemberIndicesDirty = true;
end

-- Check if a target index belongs to a party member (uses cached data for O(1) lookup)
function M.IsPartyMemberByIndex(targetIndex)
    if partyMemberIndicesDirty then
        UpdatePartyCache();
    end
    return partyMemberIndices[targetIndex] == true;
end

-- Check if a server ID belongs to a party member (uses cached data for O(1) lookup)
function M.IsPartyMemberByServerId(serverId)
    if partyMemberIndicesDirty then
        UpdatePartyCache();
    end
    return partyMemberServerIds[serverId] == true;
end

-- Non-cached O(n) lookup - for cases where you need fresh data
function M.IsMemberOfParty(targetIndex)
    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party == nil) then
        return false;
    end
    for i = 0, 17 do
        if (party:GetMemberTargetIndex(i) == targetIndex) then
            return true;
        end
    end
    return false;
end

return M;
