--[[
* XIUI Config Menu - Treasure Pool Settings
* Contains settings for Treasure Pool module
]]--

require('common');
require('handlers.helpers');
local components = require('config.components');
local imgui = require('imgui');
local treasurePool = require('modules.treasurepool.init');

local M = {};

-- Preview toggle callbacks
local function onMiniPreviewChanged()
    treasurePool.SetMiniPreview(gConfig.treasurePoolMiniPreview);
    SaveSettingsOnly();
end

local function onFullPreviewChanged()
    treasurePool.SetFullPreview(gConfig.treasurePoolFullPreview);
    SaveSettingsOnly();
end

-- Ensure defaults exist before drawing (config may draw before module init)
local function ensureDefaults()
    if gConfig.treasurePoolMiniEnabled == nil then gConfig.treasurePoolMiniEnabled = true; end
    if gConfig.treasurePoolMiniShowTitle == nil then gConfig.treasurePoolMiniShowTitle = true; end
    if gConfig.treasurePoolMiniShowTimerBar == nil then gConfig.treasurePoolMiniShowTimerBar = true; end
    if gConfig.treasurePoolMiniShowTimerText == nil then gConfig.treasurePoolMiniShowTimerText = true; end
    if gConfig.treasurePoolMiniShowLots == nil then gConfig.treasurePoolMiniShowLots = true; end
    -- Font size MUST be valid (slider min is 8)
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

-- Get available background themes
local function getBackgroundThemes()
    local themes = { '-None-', 'Plain' };
    for i = 1, 8 do
        table.insert(themes, 'Window' .. i);
    end
    return themes;
end

-- Section: Treasure Pool Settings
function M.DrawSettings()
    -- Ensure defaults before drawing sliders
    ensureDefaults();

    components.DrawCheckbox('Enabled', 'showTreasurePool', CheckVisibility);

    if components.CollapsingSection('Mini Display', true) then
        components.DrawCheckbox('Show Mini Display', 'treasurePoolMiniEnabled');
        imgui.ShowHelp('Show compact treasure pool display when items are in pool');

        imgui.SameLine();
        components.DrawCheckbox('Preview##mini', 'treasurePoolMiniPreview', onMiniPreviewChanged);

        if gConfig.treasurePoolMiniEnabled then
            components.DrawCheckbox('Show Title', 'treasurePoolMiniShowTitle');
            imgui.ShowHelp('Show "Treasure Pool" header text');

            components.DrawCheckbox('Show Timer Bar', 'treasurePoolMiniShowTimerBar');
            imgui.ShowHelp('Show countdown progress bar on pool items');

            components.DrawCheckbox('Show Timer Text', 'treasurePoolMiniShowTimerText');
            imgui.ShowHelp('Show timer text (countdown like "4:32")');

            components.DrawCheckbox('Show Lots', 'treasurePoolMiniShowLots');
            imgui.ShowHelp('Show winning lot info');

            -- Size settings
            components.DrawSlider('Text Size', 'treasurePoolMiniFontSize', 8, 16);
            imgui.ShowHelp('Font size for item names, timers, and lot info');
            components.DrawSlider('Scale X', 'treasurePoolMiniScaleX', 0.5, 2.0, '%.1f');
            imgui.ShowHelp('Horizontal scale factor');
            components.DrawSlider('Scale Y', 'treasurePoolMiniScaleY', 0.5, 2.0, '%.1f');
            imgui.ShowHelp('Vertical scale factor');
            components.DrawSlider('Background Opacity', 'treasurePoolMiniOpacity', 0.0, 1.0, '%.2f');
            imgui.ShowHelp('Background transparency (0 = transparent, 1 = opaque)');

            -- Background theme dropdown
            local themes = getBackgroundThemes();
            local currentTheme = gConfig.treasurePoolMiniBackgroundTheme or 'Plain';
            if imgui.BeginCombo('Background Theme', currentTheme) then
                for _, theme in ipairs(themes) do
                    local isSelected = (theme == currentTheme);
                    if imgui.Selectable(theme, isSelected) then
                        gConfig.treasurePoolMiniBackgroundTheme = theme;
                        UpdateSettings();
                    end
                    if isSelected then
                        imgui.SetItemDefaultFocus();
                    end
                end
                imgui.EndCombo();
            end
            imgui.ShowHelp('Window background style (Plain = solid, Window1-8 = themed with borders)');
        end
    end

    if components.CollapsingSection('Full Window##treasurepool') then
        imgui.TextDisabled('Full treasure pool window with lot/pass controls');
        imgui.TextDisabled('Toggle with /xiui treasure or /xiui pool');
        imgui.Spacing();
        components.DrawCheckbox('Preview##full', 'treasurePoolFullPreview', onFullPreviewChanged);
        imgui.ShowHelp('Show full window preview with test items');
    end

    if components.CollapsingSection('Commands##treasurepool') then
        imgui.TextDisabled('Toggle full window:');
        imgui.BulletText('/xiui treasure');
        imgui.BulletText('/xiui pool');
        imgui.Spacing();
        imgui.TextDisabled('Batch actions:');
        imgui.BulletText('/xiui lotall - Lot on all items');
        imgui.BulletText('/xiui passall - Pass on all items');
    end
end

-- Section: Treasure Pool Color Settings
function M.DrawColorSettings()
    if components.CollapsingSection('Treasure Pool Colors') then
        imgui.TextDisabled('Color settings coming soon');
    end
end

return M;
