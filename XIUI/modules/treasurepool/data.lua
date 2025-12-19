--[[
* XIUI Treasure Pool - Data Module
* Reads treasure pool state from Ashita memory API
* Memory is single source of truth - no packet handling for pool state
]]--

require('common');

local M = {};

-- ============================================
-- Constants
-- ============================================

M.MAX_POOL_SLOTS = 10;              -- Maximum treasure pool slots (0-9)
M.POOL_TIMEOUT_SECONDS = 300;       -- 5 minutes pool timeout

-- ============================================
-- State
-- ============================================

-- Current pool state from memory (slot -> item data)
M.poolItems = {};

-- Previous frame pool state (for detecting new items)
M.previousPoolState = {};

-- Timestamp cache for expiration times
-- Maps DropTime -> cached expiration time
M.timestampCache = {};

-- Sorted pool cache (avoid allocation every frame)
M.sortedCache = {};
M.sortedCacheDirty = true;

-- Preview mode state (separate for mini and full)
M.miniPreviewEnabled = false;
M.fullPreviewEnabled = false;
M.previewItems = {};

-- ============================================
-- Helper Functions
-- ============================================

-- Get notifications module lazily (avoid circular require)
local notificationsModule = nil;
local function getNotificationsModule()
    if notificationsModule == nil then
        local success, mod = pcall(require, 'modules.notifications.init');
        if success then
            notificationsModule = mod;
        end
    end
    return notificationsModule;
end

-- Get item name from resource manager
local function getItemName(itemId)
    if itemId == nil or itemId == 0 or itemId == -1 or itemId == 65535 then
        return 'Unknown Item';
    end
    local item = AshitaCore:GetResourceManager():GetItemById(itemId);
    if item and item.Name and item.Name[1] then
        local name = item.Name[1];
        if name ~= nil and name ~= '' then
            return name;
        end
    end
    return 'Unknown Item';
end

-- Mark sorted cache as needing rebuild
local function markCacheDirty()
    M.sortedCacheDirty = true;
end

-- ============================================
-- Memory Reading
-- ============================================

-- Read treasure pool state from memory API
-- Call this every frame in DrawWindow
-- Returns true if pool has items, false otherwise
function M.ReadFromMemory()
    local memMgr = AshitaCore:GetMemoryManager();
    if not memMgr then return false; end

    local inventory = memMgr:GetInventory();
    if not inventory then return false; end

    local now = os.time();
    local hasItems = false;
    local activeSlots = {};

    -- Read all 10 pool slots from memory
    for slot = 0, M.MAX_POOL_SLOTS - 1 do
        local item = inventory:GetTreasurePoolItem(slot);

        if item ~= nil and item.ItemId ~= nil and item.ItemId > 0 and item.ItemId ~= 65535 then
            hasItems = true;
            activeSlots[slot] = true;

            -- Check if this is a NEW item we haven't seen
            local isNewItem = not M.previousPoolState[slot] or
                             M.previousPoolState[slot].itemId ~= item.ItemId;

            -- Cache expiration time
            if not M.timestampCache[item.DropTime] then
                M.timestampCache[item.DropTime] = now + M.POOL_TIMEOUT_SECONDS;
            end

            -- Build pool item data
            M.poolItems[slot] = {
                slot = slot,
                itemId = item.ItemId,
                itemName = getItemName(item.ItemId),
                count = 1,
                expiresAt = M.timestampCache[item.DropTime],
                dropTime = item.DropTime,
                -- Lot info from memory
                playerLot = item.Lot,
                winningLot = item.WinningLot,
                winningLotterName = item.WinningEntityName or '',
            };

            -- Trigger toast notification for NEW items
            if isNewItem then
                -- Check if notifications are enabled
                if gConfig and gConfig.notificationsShowTreasure then
                    local notifMod = getNotificationsModule();
                    if notifMod and notifMod.AddTreasurePoolNotification then
                        notifMod.AddTreasurePoolNotification(item.ItemId, 1);
                    end
                end
            end

            markCacheDirty();
        end
    end

    -- Remove items no longer in memory
    for slot, _ in pairs(M.poolItems) do
        if not activeSlots[slot] then
            M.poolItems[slot] = nil;
            markCacheDirty();
        end
    end

    -- Update previous state for next frame comparison
    M.previousPoolState = {};
    for slot, item in pairs(M.poolItems) do
        M.previousPoolState[slot] = {
            itemId = item.itemId,
        };
    end

    return hasItems;
end

-- ============================================
-- Pool State Queries
-- ============================================

-- Get pool item by slot
function M.GetPoolItem(slot)
    return M.poolItems[slot];
end

-- Check if any preview mode is active
function M.IsPreviewActive()
    return M.miniPreviewEnabled or M.fullPreviewEnabled;
end

-- Get all pool items (returns the internal table directly)
function M.GetPoolItems()
    if M.IsPreviewActive() then
        return M.previewItems;
    end
    return M.poolItems;
end

-- Get sorted pool items for display (cached to avoid allocation every frame)
function M.GetSortedPoolItems()
    local sourceItems = M.IsPreviewActive() and M.previewItems or M.poolItems;

    if M.sortedCacheDirty then
        M.sortedCache = {};
        local idx = 1;
        for slot, item in pairs(sourceItems) do
            if item and item.slot ~= nil and item.slot >= 0 and item.slot < M.MAX_POOL_SLOTS then
                M.sortedCache[idx] = item;
                idx = idx + 1;
            end
        end
        -- Sort by slot index
        table.sort(M.sortedCache, function(a, b)
            return (a.slot or 999) < (b.slot or 999);
        end);
        M.sortedCacheDirty = false;
    end
    return M.sortedCache;
end

-- Get pool item count
function M.GetPoolCount()
    local count = 0;
    for _ in pairs(M.poolItems) do
        count = count + 1;
    end
    return count;
end

-- Check if pool has items (includes preview items when preview is active)
function M.HasItems()
    if M.IsPreviewActive() then
        return next(M.previewItems) ~= nil;
    end
    return next(M.poolItems) ~= nil;
end

-- Check if pool has real items (from memory, ignores preview)
function M.HasRealItems()
    return next(M.poolItems) ~= nil;
end

-- Get time remaining for a pool item (in seconds)
function M.GetTimeRemaining(slot)
    local sourceItems = M.IsPreviewActive() and M.previewItems or M.poolItems;
    local item = sourceItems[slot];
    if not item then return 0; end

    local remaining = item.expiresAt - os.time();
    return math.max(0, remaining);
end

-- Format time as M:SS
function M.FormatTime(seconds)
    local mins = math.floor(seconds / 60);
    local secs = seconds % 60;
    return string.format("%d:%02d", mins, secs);
end

-- Check if player has lotted on this item
-- Returns: 'lotted' (1-999), 'passed' (65535), 'pending' (0 or nil)
function M.GetPlayerLotStatus(slot)
    local item = M.poolItems[slot];
    if not item then return 'pending'; end

    local lot = item.playerLot;
    if lot == nil or lot == 0 then
        return 'pending';
    elseif lot >= 65535 then
        return 'passed';
    else
        return 'lotted';
    end
end

-- Get player's lot value (nil if not lotted)
function M.GetPlayerLotValue(slot)
    local item = M.poolItems[slot];
    if not item then return nil; end

    local lot = item.playerLot;
    if lot and lot > 0 and lot < 65535 then
        return lot;
    end
    return nil;
end

-- ============================================
-- Preview Mode
-- ============================================

-- Test item IDs for preview (8 items)
local PREVIEW_ITEMS = {
    { itemId = 13014, name = 'Leaping Boots' },
    { itemId = 16465, name = 'Kraken Club' },
    { itemId = 14525, name = 'Scorpion Harness' },
    { itemId = 4116, name = 'Hi-Potion' },
    { itemId = 4148, name = 'Elixir' },
    { itemId = 644, name = 'Mythril Ore' },
    { itemId = 1313, name = 'Sirens Hair' },
    { itemId = 844, name = 'Phoenix Feather' },
};

-- Populate preview items if not already done
local function ensurePreviewItems()
    if next(M.previewItems) ~= nil then return; end

    local now = os.time();
    for i, item in ipairs(PREVIEW_ITEMS) do
        local slot = i - 1;
        M.previewItems[slot] = {
            slot = slot,
            itemId = item.itemId,
            itemName = item.name,
            count = 1,
            expiresAt = now + (300 - (i * 30)),  -- Stagger expiration times (30s apart)
            dropTime = 0,
            playerLot = 0,
            winningLot = (i % 3 == 0) and math.random(100, 999) or 0,  -- Some items have winning lots
            winningLotterName = (i % 3 == 0) and 'Testplayer' or '',
        };
    end
    markCacheDirty();
end

-- Set mini-display preview mode
function M.SetMiniPreview(enabled)
    M.miniPreviewEnabled = enabled;
    if enabled then
        ensurePreviewItems();
    elseif not M.fullPreviewEnabled then
        M.previewItems = {};
    end
    markCacheDirty();
end

-- Set full window preview mode
function M.SetFullPreview(enabled)
    M.fullPreviewEnabled = enabled;
    if enabled then
        ensurePreviewItems();
    elseif not M.miniPreviewEnabled then
        M.previewItems = {};
    end
    markCacheDirty();
end

-- Clear all preview state (call when config closes)
function M.ClearPreview()
    M.miniPreviewEnabled = false;
    M.fullPreviewEnabled = false;
    M.previewItems = {};
    markCacheDirty();
end

-- ============================================
-- Font Storage (created by init.lua, used by display.lua)
-- ============================================

M.headerFont = nil;
M.itemNameFonts = {};   -- slot -> font
M.timerFonts = {};      -- slot -> font
M.lotFonts = {};        -- slot -> font
M.allFonts = nil;

-- Color cache (to avoid expensive set_font_color calls)
M.lastColors = {
    header = nil,
    itemNames = {},
    timers = {},
    lots = {},
};

-- Helper to set all fonts visible/hidden
function M.SetAllFontsVisible(visible)
    if M.allFonts then
        SetFontsVisible(M.allFonts, visible);
    end
end

-- Clear color cache
function M.ClearColorCache()
    M.lastColors = {
        header = nil,
        itemNames = {},
        timers = {},
        lots = {},
    };
end

-- ============================================
-- Lifecycle
-- ============================================

-- Initialize data module
function M.Initialize()
    M.poolItems = {};
    M.previousPoolState = {};
    M.timestampCache = {};
    M.sortedCache = {};
    M.sortedCacheDirty = true;
    M.miniPreviewEnabled = false;
    M.fullPreviewEnabled = false;
    M.previewItems = {};
end

-- Clear all state (call on zone change)
function M.Clear()
    M.poolItems = {};
    M.previousPoolState = {};
    M.timestampCache = {};
    M.sortedCache = {};
    M.sortedCacheDirty = true;
end

-- Cleanup (call on addon unload)
function M.Cleanup()
    M.Clear();
end

return M;
