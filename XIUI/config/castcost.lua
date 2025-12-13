--[[
* XIUI Config Menu - Cast Cost Settings
* Contains settings and color settings for Cast Cost display
]]--

require('common');
require('handlers.helpers');
local components = require('config.components');
local imgui = require('imgui');
local statusHandler = require('handlers.statushandler');

local M = {};

-- Section: Cast Cost Settings
function M.DrawSettings()
    components.DrawCheckbox('Enabled', 'showCastCost', CheckVisibility);

    if components.CollapsingSection('Display Options##castCost') then
        components.DrawSlider('Scale', 'castCostScaleX', 0.5, 2.0, '%.1f');
        components.DrawSlider('Font Size', 'castCostFontSize', 8, 24);

        imgui.Spacing();
        imgui.Text('Show Information:');
        components.DrawCheckbox('MP Cost', 'castCostShowMpCost');
        components.DrawCheckbox('Cast Time', 'castCostShowCastTime');
        components.DrawCheckbox('Recast Time', 'castCostShowRecast');
    end

    if components.CollapsingSection('Background##castCost') then
        -- Background theme dropdown
        local themes = statusHandler.get_background_paths();
        local currentTheme = gConfig.castCostBackgroundTheme or 'Window1';
        local themeIndex = 1;
        for i, theme in ipairs(themes) do
            if theme == currentTheme then
                themeIndex = i;
                break;
            end
        end

        if imgui.BeginCombo('Theme##castCostTheme', currentTheme) then
            for i, theme in ipairs(themes) do
                local isSelected = (theme == currentTheme);
                if imgui.Selectable(theme, isSelected) then
                    gConfig.castCostBackgroundTheme = theme;
                    UpdateCastCostVisuals();
                end
                if isSelected then
                    imgui.SetItemDefaultFocus();
                end
            end
            imgui.EndCombo();
        end

        components.DrawSlider('Background Opacity', 'castCostBackgroundOpacity', 0.0, 1.0, '%.2f');
        components.DrawSlider('Border Opacity', 'castCostBorderOpacity', 0.0, 1.0, '%.2f');
    end
end

-- Section: Cast Cost Color Settings
function M.DrawColorSettings()
    if components.CollapsingSection('Text Colors##castCostColor') then
        components.DrawTextColorPicker("Name Text", gConfig.colorCustomization.castCost, 'nameTextColor', "Color of spell/ability name");
        components.DrawTextColorPicker("MP Cost Text", gConfig.colorCustomization.castCost, 'mpCostTextColor', "Color of MP cost display");
        components.DrawTextColorPicker("TP Cost Text", gConfig.colorCustomization.castCost, 'tpCostTextColor', "Color of TP cost display (weapon skills)");
        components.DrawTextColorPicker("Time Text", gConfig.colorCustomization.castCost, 'timeTextColor', "Color of cast/recast time display");
    end

    if components.CollapsingSection('Background Colors##castCostColor') then
        components.DrawTextColorPicker("Background", gConfig.colorCustomization.castCost, 'bgColor', "Background tint color");
        components.DrawTextColorPicker("Border", gConfig.colorCustomization.castCost, 'borderColor', "Border tint color");
    end
end

return M;
