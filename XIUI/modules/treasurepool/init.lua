--[[
* XIUI Treasure Pool Module
* Provides dedicated treasure pool tracking UI separate from toast notifications
* Features:
*   - Mini-display: always visible when items in pool (compact view with timers)
*   - Full window: detailed view with lot/pass buttons (toggled via command)
*   - Memory-based state: reads directly from Ashita memory API
*   - Notification integration: triggers toast notifications for new items
]]--

require('common');
require('handlers.helpers');
local gdi = require('submodules.gdifonts.include');
local windowBg = require('libs.windowbackground');

local data = require('modules.treasurepool.data');
local display = require('modules.treasurepool.display');
local actions = require('modules.treasurepool.actions');

local M = {};

-- ============================================
-- Module State
-- ============================================

M.initialized = false;
M.visible = true;

-- ============================================
-- Module Lifecycle
-- ============================================

-- Initialize the treasure pool module
function M.Initialize(settings)
    if M.initialized then return; end

    -- Ensure treasure pool settings have defaults BEFORE creating fonts
    if gConfig then
        -- Clear any stale preview state
        gConfig.treasurePoolMiniPreview = false;
        gConfig.treasurePoolFullPreview = false;

        -- Set defaults for new settings
        if gConfig.treasurePoolMiniEnabled == nil then gConfig.treasurePoolMiniEnabled = true; end
        if gConfig.treasurePoolMiniShowTitle == nil then gConfig.treasurePoolMiniShowTitle = true; end
        if gConfig.treasurePoolMiniShowTimerBar == nil then gConfig.treasurePoolMiniShowTimerBar = true; end
        if gConfig.treasurePoolMiniShowTimerText == nil then gConfig.treasurePoolMiniShowTimerText = true; end
        if gConfig.treasurePoolMiniShowLots == nil then gConfig.treasurePoolMiniShowLots = true; end
        if gConfig.treasurePoolMiniFontSize == nil or gConfig.treasurePoolMiniFontSize < 8 then
            gConfig.treasurePoolMiniFontSize = 10;
        end
        if gConfig.treasurePoolMiniScaleX == nil or gConfig.treasurePoolMiniScaleX < 0.5 then
            gConfig.treasurePoolMiniScaleX = 1.0;
        end
        if gConfig.treasurePoolMiniScaleY == nil or gConfig.treasurePoolMiniScaleY < 0.5 then
            gConfig.treasurePoolMiniScaleY = 1.0;
        end
        if gConfig.treasurePoolMiniOpacity == nil then gConfig.treasurePoolMiniOpacity = 0.87; end
        if gConfig.treasurePoolMiniBackgroundTheme == nil then gConfig.treasurePoolMiniBackgroundTheme = 'Plain'; end
    end

    -- Initialize data layer first
    data.Initialize();

    -- Create fonts using settings from gAdjustedSettings.treasurePoolSettings
    -- (passed in as 'settings' parameter by module registry)
    -- Settings include global font family/weight applied via updater.lua
    local fontSettings = settings.font_settings;
    local titleFontSettings = settings.title_font_settings;

    -- Create header font
    data.headerFont = FontManager.create(titleFontSettings);

    -- Create fonts for each pool slot (0-9)
    data.itemNameFonts = {};
    data.timerFonts = {};
    data.lotFonts = {};
    for slot = 0, data.MAX_POOL_SLOTS - 1 do
        data.itemNameFonts[slot] = FontManager.create(fontSettings);
        data.timerFonts[slot] = FontManager.create(fontSettings);
        data.lotFonts[slot] = FontManager.create(fontSettings);
    end

    -- Build allFonts list for batch visibility control
    data.allFonts = {data.headerFont};
    for slot = 0, data.MAX_POOL_SLOTS - 1 do
        table.insert(data.allFonts, data.itemNameFonts[slot]);
        table.insert(data.allFonts, data.timerFonts[slot]);
        table.insert(data.allFonts, data.lotFonts[slot]);
    end

    -- Hide all fonts initially
    data.SetAllFontsVisible(false);

    -- Initialize display layer (creates background primitive)
    display.Initialize(settings);

    M.initialized = true;
end

-- Update visual elements (fonts, themes) when settings change
function M.UpdateVisuals(settings)
    if not M.initialized then return; end

    -- Settings include global font family/weight applied via updater.lua
    local fontSettings = settings.font_settings;
    local titleFontSettings = settings.title_font_settings;

    -- Recreate header font
    data.headerFont = FontManager.recreate(data.headerFont, titleFontSettings);

    -- Recreate slot fonts
    for slot = 0, data.MAX_POOL_SLOTS - 1 do
        data.itemNameFonts[slot] = FontManager.recreate(data.itemNameFonts[slot], fontSettings);
        data.timerFonts[slot] = FontManager.recreate(data.timerFonts[slot], fontSettings);
        data.lotFonts[slot] = FontManager.recreate(data.lotFonts[slot], fontSettings);
    end

    -- Rebuild allFonts list
    data.allFonts = {data.headerFont};
    for slot = 0, data.MAX_POOL_SLOTS - 1 do
        table.insert(data.allFonts, data.itemNameFonts[slot]);
        table.insert(data.allFonts, data.timerFonts[slot]);
        table.insert(data.allFonts, data.lotFonts[slot]);
    end

    -- Clear color cache
    data.ClearColorCache();

    -- Update display layer
    display.UpdateVisuals(settings);
end

-- Main render function - called every frame
function M.DrawWindow(settings)
    if not M.initialized then return; end
    if not M.visible then return; end

    -- Read pool state from memory (skip in preview mode)
    if not data.IsPreviewActive() then
        data.ReadFromMemory();
    end

    -- Check for real items (from memory, not preview)
    local hasRealItems = data.HasRealItems();

    -- Draw mini-display if enabled and (has real items OR mini preview is on)
    local miniEnabled = gConfig.treasurePoolMiniEnabled;
    local showMini = (hasRealItems or data.miniPreviewEnabled) and miniEnabled;
    if showMini then
        display.DrawMiniDisplay(settings);
    else
        display.HideMiniDisplay();
    end

    -- Draw full window if toggled on via command OR full preview is on
    local showFull = display.fullWindowVisible or data.fullPreviewEnabled;
    if showFull and (hasRealItems or data.fullPreviewEnabled) then
        display.DrawFullWindow(settings);
    else
        display.HideFullWindow();
    end
end

-- Set module visibility
function M.SetHidden(hidden)
    M.visible = not hidden;
    if hidden then
        data.SetAllFontsVisible(false);
    end
    display.SetHidden(hidden);
end

-- Cleanup on addon unload
function M.Cleanup()
    if not M.initialized then return; end

    -- Destroy fonts
    data.headerFont = FontManager.destroy(data.headerFont);
    for slot = 0, data.MAX_POOL_SLOTS - 1 do
        if data.itemNameFonts[slot] then
            data.itemNameFonts[slot] = FontManager.destroy(data.itemNameFonts[slot]);
        end
        if data.timerFonts[slot] then
            data.timerFonts[slot] = FontManager.destroy(data.timerFonts[slot]);
        end
        if data.lotFonts[slot] then
            data.lotFonts[slot] = FontManager.destroy(data.lotFonts[slot]);
        end
    end
    data.allFonts = nil;
    data.itemNameFonts = {};
    data.timerFonts = {};
    data.lotFonts = {};

    -- Cleanup display and data layers
    display.Cleanup();
    data.Cleanup();

    M.initialized = false;
end

-- ============================================
-- Zone Change Handler
-- ============================================

function M.HandleZonePacket()
    data.Clear();
end

-- ============================================
-- Command Interface
-- ============================================

function M.ToggleFullWindow()
    return display.ToggleFullWindow();
end

function M.ShowFullWindow()
    display.ShowFullWindow();
end

function M.HideFullWindow()
    display.HideFullWindowCmd();
end

function M.LotAll()
    return actions.LotAll();
end

function M.PassAll()
    return actions.PassAll();
end

function M.LotItem(slot)
    return actions.LotItem(slot);
end

function M.PassItem(slot)
    return actions.PassItem(slot);
end

-- ============================================
-- Query Interface
-- ============================================

function M.GetPoolCount()
    return data.GetPoolCount();
end

function M.HasItems()
    return data.HasItems();
end

function M.GetPoolItems()
    return data.GetPoolItems();
end

-- ============================================
-- Preview Mode
-- ============================================

function M.SetMiniPreview(enabled)
    data.SetMiniPreview(enabled);
end

function M.SetFullPreview(enabled)
    data.SetFullPreview(enabled);
end

function M.ClearPreview()
    data.ClearPreview();
end

return M;
