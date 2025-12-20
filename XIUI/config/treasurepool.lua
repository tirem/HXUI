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

-- Preview toggle callback
local function onPreviewChanged()
    treasurePool.SetPreview(gConfig.treasurePoolPreview);
    SaveSettingsOnly();
end

-- Ensure defaults exist before drawing (config may draw before module init)
local function ensureDefaults()
    if gConfig.treasurePoolEnabled == nil then gConfig.treasurePoolEnabled = true; end
    if gConfig.treasurePoolShowTitle == nil then gConfig.treasurePoolShowTitle = true; end
    if gConfig.treasurePoolShowTimerBar == nil then gConfig.treasurePoolShowTimerBar = true; end
    if gConfig.treasurePoolShowTimerText == nil then gConfig.treasurePoolShowTimerText = true; end
    if gConfig.treasurePoolShowLots == nil then gConfig.treasurePoolShowLots = true; end
    -- Font size MUST be valid (slider min is 8)
    if gConfig.treasurePoolFontSize == nil or gConfig.treasurePoolFontSize < 8 then
        gConfig.treasurePoolFontSize = 10;
    end
    if gConfig.treasurePoolScaleX == nil or gConfig.treasurePoolScaleX < 0.5 then
        gConfig.treasurePoolScaleX = 1.0;
    end
    if gConfig.treasurePoolScaleY == nil or gConfig.treasurePoolScaleY < 0.5 then
        gConfig.treasurePoolScaleY = 1.0;
    end
    if gConfig.treasurePoolOpacity == nil then gConfig.treasurePoolOpacity = 0.87; end
    if gConfig.treasurePoolBackgroundTheme == nil then gConfig.treasurePoolBackgroundTheme = 'Plain'; end
    if gConfig.treasurePoolExpanded == nil then gConfig.treasurePoolExpanded = false; end
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

    if components.CollapsingSection('Display Settings', true) then
        components.DrawCheckbox('Show Treasure Pool', 'treasurePoolEnabled');
        imgui.ShowHelp('Show treasure pool display when items are in pool');

        imgui.SameLine();
        components.DrawCheckbox('Preview', 'treasurePoolPreview', onPreviewChanged);

        if gConfig.treasurePoolEnabled then
            components.DrawCheckbox('Show Title', 'treasurePoolShowTitle');
            imgui.ShowHelp('Show "Treasure Pool" header text');

            components.DrawCheckbox('Show Timer Bar', 'treasurePoolShowTimerBar');
            imgui.ShowHelp('Show countdown progress bar on pool items');

            components.DrawCheckbox('Show Timer Text', 'treasurePoolShowTimerText');
            imgui.ShowHelp('Show timer text (countdown like "4:32")');

            components.DrawCheckbox('Show Lots', 'treasurePoolShowLots');
            imgui.ShowHelp('Show winning lot info');

            components.DrawCheckbox('Start Expanded', 'treasurePoolExpanded');
            imgui.ShowHelp('Start with expanded view showing all lot details');

            -- Size settings
            components.DrawSlider('Text Size', 'treasurePoolFontSize', 8, 16);
            imgui.ShowHelp('Font size for item names, timers, and lot info');
            components.DrawSlider('Scale X', 'treasurePoolScaleX', 0.5, 2.0, '%.1f');
            imgui.ShowHelp('Horizontal scale factor');
            components.DrawSlider('Scale Y', 'treasurePoolScaleY', 0.5, 2.0, '%.1f');
            imgui.ShowHelp('Vertical scale factor');
            components.DrawSlider('Background Opacity', 'treasurePoolOpacity', 0.0, 1.0, '%.2f');
            imgui.ShowHelp('Background transparency (0 = transparent, 1 = opaque)');

            -- Background theme dropdown
            local themes = getBackgroundThemes();
            local currentTheme = gConfig.treasurePoolBackgroundTheme or 'Plain';
            if imgui.BeginCombo('Background Theme', currentTheme) then
                for _, theme in ipairs(themes) do
                    local isSelected = (theme == currentTheme);
                    if imgui.Selectable(theme, isSelected) then
                        gConfig.treasurePoolBackgroundTheme = theme;
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

    if components.CollapsingSection('Usage##treasurepool') then
        imgui.TextDisabled('Window Controls:');
        imgui.BulletText('[v]/[^] - Toggle expanded/collapsed view');
        imgui.BulletText('Lot/Pass buttons - Act on all items');
        imgui.BulletText('L/P buttons (expanded) - Act on single item');
        imgui.Spacing();
        imgui.TextDisabled('Chat Commands:');
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
