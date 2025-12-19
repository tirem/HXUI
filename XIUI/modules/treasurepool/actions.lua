--[[
* XIUI Treasure Pool - Actions Module
* Handles lot/pass packet sending for treasure pool items
]]--

require('common');

local data = require('modules.treasurepool.data');

local M = {};

-- ============================================
-- Packet Constants
-- ============================================

local PACKET_LOT_ITEM = 0x041;   -- Lot on treasure pool item
local PACKET_PASS_ITEM = 0x042;  -- Pass on treasure pool item

-- ============================================
-- Single Item Actions
-- ============================================

-- Lot on a specific treasure pool item by slot
function M.LotItem(slot)
    local packetManager = AshitaCore:GetPacketManager();
    if not packetManager then
        print('[XIUI TreasurePool] Cannot access packet manager');
        return false;
    end

    -- Validate slot
    if slot == nil or slot < 0 or slot >= data.MAX_POOL_SLOTS then
        return false;
    end

    -- Check if item exists in pool
    local item = data.GetPoolItem(slot);
    if not item then
        return false;
    end

    -- Check if already lotted
    local status = data.GetPlayerLotStatus(slot);
    if status == 'lotted' then
        return false;  -- Already lotted
    end

    -- Send Lot Item packet (0x041)
    -- Packet structure: { 0x00, 0x00, 0x00, 0x00, slot }
    packetManager:AddOutgoingPacket(PACKET_LOT_ITEM, { 0x00, 0x00, 0x00, 0x00, slot });
    return true;
end

-- Pass on a specific treasure pool item by slot
function M.PassItem(slot)
    local packetManager = AshitaCore:GetPacketManager();
    if not packetManager then
        print('[XIUI TreasurePool] Cannot access packet manager');
        return false;
    end

    -- Validate slot
    if slot == nil or slot < 0 or slot >= data.MAX_POOL_SLOTS then
        return false;
    end

    -- Check if item exists in pool
    local item = data.GetPoolItem(slot);
    if not item then
        return false;
    end

    -- Check if already passed or lotted
    local status = data.GetPlayerLotStatus(slot);
    if status == 'passed' or status == 'lotted' then
        return false;  -- Already decided
    end

    -- Send Pass Item packet (0x042)
    -- Packet structure: { 0x00, 0x00, 0x00, 0x00, slot }
    packetManager:AddOutgoingPacket(PACKET_PASS_ITEM, { 0x00, 0x00, 0x00, 0x00, slot });
    return true;
end

-- ============================================
-- Batch Actions
-- ============================================

-- Lot on all items that player has NOT already lotted/passed on
function M.LotAll()
    local packetManager = AshitaCore:GetPacketManager();
    if not packetManager then
        print('[XIUI TreasurePool] Cannot access packet manager');
        return 0;
    end

    local inventory = AshitaCore:GetMemoryManager():GetInventory();
    if not inventory then
        print('[XIUI TreasurePool] Cannot access inventory');
        return 0;
    end

    local count = 0;
    for slot = 0, data.MAX_POOL_SLOTS - 1 do
        local item = inventory:GetTreasurePoolItem(slot);
        if item and item.ItemId and item.ItemId > 0 and item.ItemId ~= 65535 then
            local lot = item.Lot;
            -- Only lot if pending (0, nil, or 65535+ means not lotted)
            if lot == nil or lot == 0 or lot >= 65535 then
                packetManager:AddOutgoingPacket(PACKET_LOT_ITEM, { 0x00, 0x00, 0x00, 0x00, slot });
                count = count + 1;
            end
        end
    end

    if count > 0 then
        print('[XIUI TreasurePool] Lotted on ' .. count .. ' item(s)');
    else
        print('[XIUI TreasurePool] No items to lot on');
    end

    return count;
end

-- Pass on all items that player has NOT already lotted/passed on
function M.PassAll()
    local packetManager = AshitaCore:GetPacketManager();
    if not packetManager then
        print('[XIUI TreasurePool] Cannot access packet manager');
        return 0;
    end

    local inventory = AshitaCore:GetMemoryManager():GetInventory();
    if not inventory then
        print('[XIUI TreasurePool] Cannot access inventory');
        return 0;
    end

    local count = 0;
    for slot = 0, data.MAX_POOL_SLOTS - 1 do
        local item = inventory:GetTreasurePoolItem(slot);
        if item and item.ItemId and item.ItemId > 0 and item.ItemId ~= 65535 then
            local lot = item.Lot;
            -- Only pass if pending (0, nil means not decided, 65535 means already passed)
            if lot == nil or lot == 0 then
                packetManager:AddOutgoingPacket(PACKET_PASS_ITEM, { 0x00, 0x00, 0x00, 0x00, slot });
                count = count + 1;
            end
        end
    end

    if count > 0 then
        print('[XIUI TreasurePool] Passed on ' .. count .. ' item(s)');
    else
        print('[XIUI TreasurePool] No items to pass on');
    end

    return count;
end

return M;
