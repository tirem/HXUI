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
        components.DrawCheckbox('Spell/Ability Name', 'castCostShowName');
        components.DrawCheckbox('MP Cost', 'castCostShowMpCost');
        components.DrawCheckbox('Recast Time', 'castCostShowRecast');

        imgui.Spacing();
        imgui.Text('Font Sizes:');
        components.DrawSlider('Name Font Size', 'castCostNameFontSize', 8, 24);
        components.DrawSlider('Cost Font Size', 'castCostCostFontSize', 8, 24);
        components.DrawSlider('Recast Font Size', 'castCostTimeFontSize', 8, 24);
        components.DrawSlider('Cooldown Timer Font Size', 'castCostRecastFontSize', 8, 24);

        imgui.Spacing();
        imgui.Text('Cooldown:');
        components.DrawCheckbox('Show Cooldown', 'castCostShowCooldown');
        imgui.ShowHelp('Shows "Next: ready" when available, or progress bar with timer when on cooldown');
        components.DrawSlider('Bar Scale Y', 'castCostBarScaleY', 0.5, 2.0, '%.1f');
    end

    if components.CollapsingSection('Layout##castCost') then
        components.DrawSlider('Minimum Width', 'castCostMinWidth', 50, 300);
        components.DrawSlider('Padding (Horizontal)', 'castCostPadding', 0, 20);
        components.DrawSlider('Padding (Vertical)', 'castCostPaddingY', 0, 20);
        components.DrawCheckbox('Align Bottom', 'castCostAlignBottom');
        imgui.ShowHelp('When enabled, content grows upward instead of downward');
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

        components.DrawSlider('Background Scale', 'castCostScaleX', 0.5, 2.0, '%.1f');
        components.DrawSlider('Background Opacity', 'castCostBackgroundOpacity', 0.0, 1.0, '%.2f');
        components.DrawSlider('Border Opacity', 'castCostBorderOpacity', 0.0, 1.0, '%.2f');
    end
end

-- Section: Cast Cost Color Settings
function M.DrawColorSettings()
    if components.CollapsingSection('Text Colors##castCostColor') then
        components.DrawTextColorPicker("Name Text", gConfig.colorCustomization.castCost, 'nameTextColor', "Color of spell/ability name");
        components.DrawTextColorPicker("Name (On Cooldown)", gConfig.colorCustomization.castCost, 'nameOnCooldownColor', "Greyed out color when spell is on cooldown");
        components.DrawTextColorPicker("MP Cost Text", gConfig.colorCustomization.castCost, 'mpCostTextColor', "Color of MP cost display");
        components.DrawTextColorPicker("Not Enough MP", gConfig.colorCustomization.castCost, 'mpNotEnoughColor', "Color when you don't have enough MP");
        components.DrawTextColorPicker("TP Cost Text", gConfig.colorCustomization.castCost, 'tpCostTextColor', "Color of TP cost display (weapon skills)");
        components.DrawTextColorPicker("Time Text", gConfig.colorCustomization.castCost, 'timeTextColor', "Color of cast/recast time display");
    end

    if components.CollapsingSection('Cooldown##castCostColor') then
        components.DrawTextColorPicker("Ready Text", gConfig.colorCustomization.castCost, 'readyTextColor', "Color of 'Next: ready' text");
        components.DrawGradientPicker("Cooldown Bar", gConfig.colorCustomization.castCost.cooldownBarGradient, "Cooldown bar gradient (fills as spell comes off cooldown)");
        components.DrawTextColorPicker("Cooldown Timer", gConfig.colorCustomization.castCost, 'cooldownTextColor', "Color of countdown timer text on cooldown bar");
    end

    if components.CollapsingSection('Background Colors##castCostColor') then
        components.DrawTextColorPicker("Background", gConfig.colorCustomization.castCost, 'bgColor', "Background tint color");
        components.DrawTextColorPicker("Border", gConfig.colorCustomization.castCost, 'borderColor', "Border tint color");
    end
end

return M;
