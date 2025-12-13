--[[
* XIUI Config Menu - Gil Tracker Settings
* Contains settings and color settings for Gil Tracker
]]--

require('common');
require('handlers.helpers');
local components = require('config.components');
local imgui = require('imgui');

local M = {};

-- Section: Gil Tracker Settings
function M.DrawSettings()
    components.DrawCheckbox('Enabled', 'showGilTracker', CheckVisibility);
    components.DrawCheckbox('Show Icon', 'gilTrackerShowIcon');
    imgui.ShowHelp('Show gil icon. Disable for text-only mode.');
    components.DrawSlider('Scale', 'gilTrackerScale', 0.1, 3.0, '%.1f');
    components.DrawSlider('Font Size', 'gilTrackerFontSize', 8, 36);
    components.DrawCheckbox('Icon Right', 'gilTrackerIconRight');
    imgui.ShowHelp('Position icon to the right of text (when icon enabled).');
    components.DrawCheckbox('Right Align Text', 'gilTrackerRightAlign', UpdateGilTrackerVisuals);
    imgui.ShowHelp('Right-align text so numbers anchor at the right edge.');
end

-- Section: Gil Tracker Color Settings
function M.DrawColorSettings()
    imgui.Text("Text Color:");
    imgui.Separator();
    imgui.Spacing();
    components.DrawTextColorPicker("Gil Text", gConfig.colorCustomization.gilTracker, 'textColor', "Color of gil amount text");
end

return M;
