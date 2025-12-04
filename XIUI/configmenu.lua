require ("common");
require('helpers');
local statusHandler = require('statushandler');
local imgui = require("imgui");

local config = {};

-- State for confirmation dialogs
local showRestoreDefaultsConfirm = false;
local showRestoreColorsConfirm = false;

-- Navigation state
local selectedCategory = 1;  -- 1-indexed category selection
local selectedTab = 1;       -- 1 = settings, 2 = color settings

-- Category definitions
local categories = {
    { name = 'global', label = 'Global' },
    { name = 'playerBar', label = 'Player Bar' },
    { name = 'targetBar', label = 'Target Bar' },
    { name = 'enemyList', label = 'Enemy List' },
    { name = 'partyList', label = 'Party List' },
    { name = 'expBar', label = 'Exp Bar' },
    { name = 'gilTracker', label = 'Gil Tracker' },
    { name = 'inventoryTracker', label = 'Inventory' },
    { name = 'castBar', label = 'Cast Bar' },
};

-- List of common Windows fonts
local available_fonts = {
    'Arial',
    'Calibri',
    'Consolas',
    'Courier New',
    'Georgia',
    'Lucida Console',
    'Microsoft Sans Serif',
    'Tahoma',
    'Times New Roman',
    'Trebuchet MS',
    'Verdana',
};

-- Color picker helper functions (for color settings tabs)
local function DrawGradientPicker(label, gradientTable, helpText)
    if not gradientTable then return; end

    local enabled = { gradientTable.enabled };
    if (imgui.Checkbox('Use Gradient##'..label, enabled)) then
        gradientTable.enabled = enabled[1];
        SaveSettingsOnly();
    end
    imgui.ShowHelp('Enable gradient (2 colors) or use static color (single color)');

    local startColor = HexToImGui(gradientTable.start);
    if (imgui.ColorEdit4(label..' Start##'..label, startColor, bit.bor(ImGuiColorEditFlags_NoInputs, ImGuiColorEditFlags_AlphaBar))) then
        gradientTable.start = ImGuiToHex(startColor);
    end
    if (imgui.IsItemDeactivatedAfterEdit()) then SaveSettingsOnly(); end

    if gradientTable.enabled then
        local stopColor = HexToImGui(gradientTable.stop);
        if (imgui.ColorEdit4(label..' End##'..label, stopColor, bit.bor(ImGuiColorEditFlags_NoInputs, ImGuiColorEditFlags_AlphaBar))) then
            gradientTable.stop = ImGuiToHex(stopColor);
        end
        if (imgui.IsItemDeactivatedAfterEdit()) then SaveSettingsOnly(); end
    end

    if helpText then imgui.ShowHelp(helpText); end
end

local function DrawHexColorPicker(label, parentTable, key, helpText)
    if not parentTable or not parentTable[key] then return; end

    local colorValue = parentTable[key];
    local colorRGBA = HexToImGui(colorValue);

    if (imgui.ColorEdit4(label, colorRGBA, bit.bor(ImGuiColorEditFlags_NoInputs, ImGuiColorEditFlags_AlphaBar))) then
        parentTable[key] = ImGuiToHex(colorRGBA);
    end
    if (imgui.IsItemDeactivatedAfterEdit()) then SaveSettingsOnly(); end

    if helpText then imgui.ShowHelp(helpText); end
end

local function DrawThreeStepGradientPicker(label, gradientTable, helpText)
    if not gradientTable then return; end

    local startColor = HexToImGui(gradientTable.start);
    if (imgui.ColorEdit4(label..' Top##'..label, startColor, bit.bor(ImGuiColorEditFlags_NoInputs, ImGuiColorEditFlags_AlphaBar))) then
        gradientTable.start = ImGuiToHex(startColor);
    end
    if (imgui.IsItemDeactivatedAfterEdit()) then SaveSettingsOnly(); end

    local midColor = HexToImGui(gradientTable.mid);
    if (imgui.ColorEdit4(label..' Middle##'..label, midColor, bit.bor(ImGuiColorEditFlags_NoInputs, ImGuiColorEditFlags_AlphaBar))) then
        gradientTable.mid = ImGuiToHex(midColor);
    end
    if (imgui.IsItemDeactivatedAfterEdit()) then SaveSettingsOnly(); end

    local stopColor = HexToImGui(gradientTable.stop);
    if (imgui.ColorEdit4(label..' Bottom##'..label, stopColor, bit.bor(ImGuiColorEditFlags_NoInputs, ImGuiColorEditFlags_AlphaBar))) then
        gradientTable.stop = ImGuiToHex(stopColor);
    end
    if (imgui.IsItemDeactivatedAfterEdit()) then SaveSettingsOnly(); end

    if helpText then imgui.ShowHelp(helpText); end
end

local function DrawTextColorPicker(label, parentTable, key, helpText)
    if not parentTable or not parentTable[key] then return; end

    local colorValue = parentTable[key];
    local colorRGBA = ARGBToImGui(colorValue);

    if (imgui.ColorEdit4(label, colorRGBA, bit.bor(ImGuiColorEditFlags_AlphaBar, ImGuiColorEditFlags_NoInputs))) then
        parentTable[key] = ImGuiToARGB(colorRGBA);
    end
    if (imgui.IsItemDeactivatedAfterEdit()) then SaveSettingsOnly(); end

    if helpText then imgui.ShowHelp(helpText); end
end

-- Helper function for checkbox with auto-save
local function DrawCheckbox(label, configKey, callback)
    if (imgui.Checkbox(label, { gConfig[configKey] })) then
        gConfig[configKey] = not gConfig[configKey];
        SaveSettingsOnly();
        if callback then callback() end
    end
end

-- Helper function for slider with deferred save
local function DrawSlider(label, configKey, min, max, format, callback)
    local value = { gConfig[configKey] };
    local changed = false;

    -- Use SliderFloat if format is specified, otherwise check if value is integer
    if format ~= nil then
        -- Format specified, use float slider
        changed = imgui.SliderFloat(label, value, min, max, format);
    elseif type(gConfig[configKey]) == 'number' and math.floor(gConfig[configKey]) == gConfig[configKey] then
        -- No format and value is integer, use int slider
        changed = imgui.SliderInt(label, value, min, max);
    else
        -- No format but value is float, use float slider with default format
        changed = imgui.SliderFloat(label, value, min, max, '%.2f');
    end

    if changed then
        gConfig[configKey] = value[1];
        if callback then callback() end
        UpdateUserSettings();
    end

    if (imgui.IsItemDeactivatedAfterEdit()) then
        SaveSettingsToDisk();
    end
end

-- Helper function for party layout-specific checkbox (saves to current layout table)
local function DrawPartyLayoutCheckbox(label, configKey, callback)
    local currentLayout = (gConfig.partyListLayout == 1) and gConfig.partyListLayout2 or gConfig.partyListLayout1;
    if (imgui.Checkbox(label, { currentLayout[configKey] })) then
        currentLayout[configKey] = not currentLayout[configKey];
        SaveSettingsOnly();
        if callback then callback() end
    end
end

-- Helper function for party layout-specific slider (saves to current layout table)
local function DrawPartyLayoutSlider(label, configKey, min, max, format, callback)
    local currentLayout = (gConfig.partyListLayout == 1) and gConfig.partyListLayout2 or gConfig.partyListLayout1;
    local value = { currentLayout[configKey] };
    local changed = false;

    -- Use SliderFloat if format is specified, otherwise check if value is integer
    if format ~= nil then
        -- Format specified, use float slider
        changed = imgui.SliderFloat(label, value, min, max, format);
    elseif type(currentLayout[configKey]) == 'number' and math.floor(currentLayout[configKey]) == currentLayout[configKey] then
        -- No format and value is integer, use int slider
        changed = imgui.SliderInt(label, value, min, max);
    else
        -- No format but value is float, use float slider with default format
        changed = imgui.SliderFloat(label, value, min, max, '%.2f');
    end

    if changed then
        currentLayout[configKey] = value[1];
        if callback then callback() end
        UpdateUserSettings();
    end

    if (imgui.IsItemDeactivatedAfterEdit()) then
        SaveSettingsToDisk();
    end
end

-- Helper function for combo box selection
local function DrawComboBox(label, currentValue, items, callback)
    local changed = false;
    local newValue = currentValue;

    if (imgui.BeginCombo(label, currentValue)) then
        for i = 1, #items do
            local is_selected = items[i] == currentValue;

            if (imgui.Selectable(items[i], is_selected) and items[i] ~= currentValue) then
                newValue = items[i];
                changed = true;
            end

            if (is_selected) then
                imgui.SetItemDefaultFocus();
            end
        end
        imgui.EndCombo();
    end

    if changed and callback then
        callback(newValue);
    end

    return changed, newValue;
end

-- Section: Global Settings (combines General, Font, and Bar settings)
local function DrawGlobalSettings()
    imgui.Text("General");
    imgui.Separator();
    imgui.Spacing();

    DrawCheckbox('Lock HUD Position', 'lockPositions');

    -- Status Icon Theme
    local status_theme_paths = statusHandler.get_status_theme_paths();
    DrawComboBox('Status Icon Theme', gConfig.statusIconTheme, status_theme_paths, function(newValue)
        gConfig.statusIconTheme = newValue;
        SaveSettingsOnly();
        DeferredUpdateVisuals();
    end);
    imgui.ShowHelp('The folder to pull status icons from. [XIUI\\assets\\status]');

    -- Job Icon Theme
    local job_theme_paths = statusHandler.get_job_theme_paths();
    DrawComboBox('Job Icon Theme', gConfig.jobIconTheme, job_theme_paths, function(newValue)
        gConfig.jobIconTheme = newValue;
        SaveSettingsOnly();
        DeferredUpdateVisuals();
    end);
    imgui.ShowHelp('The folder to pull job icons from. [XIUI\\assets\\jobs]');

    DrawSlider('Tooltip Scale', 'tooltipScale', 0.1, 3.0, '%.2f');
    imgui.ShowHelp('Scales the size of the tooltip. Note that text may appear blured if scaled too large.');

    DrawCheckbox('Hide During Events', 'hideDuringEvents');

    imgui.Spacing();
    imgui.Text("Fonts");
    imgui.Separator();
    imgui.Spacing();

    -- Font Family Selector
    DrawComboBox('Font Family', gConfig.fontFamily, available_fonts, function(newValue)
        gConfig.fontFamily = newValue;
        ClearDebuffFontCache();
        UpdateSettings();
    end);
    imgui.ShowHelp('The font family to use for all text in XIUI. Fonts must be installed on your system.');

    -- Font Weight Selector
    DrawComboBox('Font Weight', gConfig.fontWeight, {'Normal', 'Bold'}, function(newValue)
        gConfig.fontWeight = newValue;
        ClearDebuffFontCache();
        UpdateSettings();
    end);
    imgui.ShowHelp('The font weight (boldness) to use for all text in XIUI.');

    -- Font Outline Width Slider
    DrawSlider('Font Outline Width', 'fontOutlineWidth', 0, 5, nil, function()
        ClearDebuffFontCache();
        DeferredUpdateVisuals();
    end);
    imgui.ShowHelp('The thickness of the text outline/stroke for all text in XIUI.');

    imgui.Spacing();
    imgui.Text("Bar Settings");
    imgui.Separator();
    imgui.Spacing();

    DrawCheckbox('Show Bookends', 'showBookends');
    imgui.ShowHelp('Global setting to show or hide bookends on all progress bars.');

    DrawCheckbox('Health Bar Flash Effects', 'healthBarFlashEnabled');
    imgui.ShowHelp('Flash effect when taking damage on health bars.');

    DrawCheckbox('TP Bar Flash Effects', 'tpBarFlashEnabled');
    imgui.ShowHelp('Flash effect when TP reaches 100% or higher.');

    DrawSlider('Bar Roundness', 'noBookendRounding', 0, 10);
    imgui.ShowHelp('Corner roundness for bars without bookends (0 = square corners, 10 = very rounded).');

    DrawSlider('Bar Border Thickness', 'barBorderThickness', 0, 5);
    imgui.ShowHelp('Thickness of the border around all progress bars.');
end

-- Section: Global Color Settings
local function DrawGlobalColorSettings()
    imgui.Text("Background Color:");
    imgui.Separator();
    DrawGradientPicker("Bar Background", gConfig.colorCustomization.shared.backgroundGradient, "Background color for all progress bars");

    imgui.Spacing();
    imgui.Text("Bookend Gradient:");
    imgui.Separator();
    DrawThreeStepGradientPicker("Bookend", gConfig.colorCustomization.shared.bookendGradient, "3-step gradient for progress bar bookends (top -> middle -> bottom)");

    imgui.Spacing();
    imgui.Text("Entity Name Colors (by type):");
    imgui.Separator();
    DrawTextColorPicker("Party/Alliance Player", gConfig.colorCustomization.shared, 'playerPartyTextColor', "Color for party/alliance member names");
    DrawTextColorPicker("Other Player", gConfig.colorCustomization.shared, 'playerOtherTextColor', "Color for other player names");
    DrawTextColorPicker("NPC", gConfig.colorCustomization.shared, 'npcTextColor', "Color for NPC names");
    DrawTextColorPicker("Unclaimed Mob", gConfig.colorCustomization.shared, 'mobUnclaimedTextColor', "Color for unclaimed mob names");
    DrawTextColorPicker("Party-Claimed Mob", gConfig.colorCustomization.shared, 'mobPartyClaimedTextColor', "Color for mobs claimed by your party");
    DrawTextColorPicker("Other-Claimed Mob", gConfig.colorCustomization.shared, 'mobOtherClaimedTextColor', "Color for mobs claimed by others");

    imgui.Spacing();
    imgui.Text("HP Bar Effects (Damage/Healing):");
    imgui.Separator();
    DrawGradientPicker("Damage Effect", gConfig.colorCustomization.shared.hpDamageGradient, "Color of the trailing bar when HP decreases");
    DrawHexColorPicker("Damage Flash", gConfig.colorCustomization.shared, 'hpDamageFlashColor', "Flash overlay color when taking damage");
    DrawGradientPicker("Healing Effect", gConfig.colorCustomization.shared.hpHealGradient, "Color of the leading bar when HP increases");
    DrawHexColorPicker("Healing Flash", gConfig.colorCustomization.shared, 'hpHealFlashColor', "Flash overlay color when healing");
end

-- Section: Player Bar Settings
local function DrawPlayerBarSettings()
    DrawCheckbox('Enabled', 'showPlayerBar', CheckVisibility);
    DrawCheckbox('Show Bookends', 'showPlayerBarBookends');
    DrawCheckbox('Hide During Events', 'playerBarHideDuringEvents');
    DrawCheckbox('Always Show MP Bar', 'alwaysShowMpBar');
    imgui.ShowHelp('Always display the MP Bar even if your current jobs cannot cast spells.');

    DrawSlider('Scale X', 'playerBarScaleX', 0.1, 3.0, '%.1f');
    DrawSlider('Scale Y', 'playerBarScaleY', 0.1, 3.0, '%.1f');
    DrawSlider('Font Size', 'playerBarFontSize', 8, 36);
end

-- Section: Player Bar Color Settings
local function DrawPlayerBarColorSettings()
    imgui.Text("HP Bar Colors:");
    imgui.Separator();
    DrawGradientPicker("HP High (75-100%)", gConfig.colorCustomization.playerBar.hpGradient.high, "HP bar color when health is above 75%");
    DrawGradientPicker("HP Med-High (50-75%)", gConfig.colorCustomization.playerBar.hpGradient.medHigh, "HP bar color when health is 50-75%");
    DrawGradientPicker("HP Med-Low (25-50%)", gConfig.colorCustomization.playerBar.hpGradient.medLow, "HP bar color when health is 25-50%");
    DrawGradientPicker("HP Low (0-25%)", gConfig.colorCustomization.playerBar.hpGradient.low, "HP bar color when health is below 25%");

    imgui.Spacing();
    imgui.Text("MP/TP Bar Colors:");
    imgui.Separator();
    DrawGradientPicker("MP Bar", gConfig.colorCustomization.playerBar.mpGradient, "MP bar color gradient");
    DrawGradientPicker("TP Bar", gConfig.colorCustomization.playerBar.tpGradient, "TP bar color gradient");

    imgui.Spacing();
    imgui.Text("Text Colors:");
    imgui.Separator();
    DrawTextColorPicker("HP Text", gConfig.colorCustomization.playerBar, 'hpTextColor', "Color of HP number text");
    DrawTextColorPicker("MP Text", gConfig.colorCustomization.playerBar, 'mpTextColor', "Color of MP number text");
    DrawTextColorPicker("TP Text (Empty, <1000)", gConfig.colorCustomization.playerBar, 'tpEmptyTextColor', "Color of TP number text when below 1000");
    DrawTextColorPicker("TP Text (Full, >=1000)", gConfig.colorCustomization.playerBar, 'tpFullTextColor', "Color of TP number text when 1000 or higher");
end

-- Section: Target Bar Settings
local function DrawTargetBarSettings()
    DrawCheckbox('Enabled', 'showTargetBar', CheckVisibility);
    DrawCheckbox('Show Distance', 'showTargetDistance');
    DrawCheckbox('Show Bookends', 'showTargetBarBookends');
    DrawCheckbox('Show Lock On', 'showTargetBarLockOnBorder');
    imgui.ShowHelp('Display the lock icon and colored border when locked on to a target.');
    if (not HzLimitedMode) then
        DrawCheckbox('Show Cast Bar', 'showTargetBarCastBar');
        imgui.ShowHelp('Display the enemy cast bar under the HP bar when the target is casting.');
    end
    DrawCheckbox('Hide During Events', 'targetBarHideDuringEvents');
    DrawCheckbox('Show Enemy Id', 'showEnemyId');
    imgui.ShowHelp('Display the internal ID of the monster next to its name.');

    DrawCheckbox('Always Show Health Percent', 'alwaysShowHealthPercent');
    imgui.ShowHelp('Always display the percent of HP remanining regardless if the target is an enemy or not.');

    DrawCheckbox('Split Target Bars', 'splitTargetOfTarget');
    imgui.ShowHelp('Separate the Target of Target bar into its own window that can be moved independently.');

    DrawSlider('Scale X', 'targetBarScaleX', 0.1, 3.0, '%.1f');
    DrawSlider('Scale Y', 'targetBarScaleY', 0.1, 3.0, '%.1f');
    DrawSlider('Name Font Size', 'targetBarNameFontSize', 8, 36);
    DrawSlider('Distance Font Size', 'targetBarDistanceFontSize', 8, 36);
    DrawSlider('HP% Font Size', 'targetBarPercentFontSize', 8, 36);

    -- Cast bar settings (only show if cast bar is enabled)
    if (gConfig.showTargetBarCastBar and (not HzLimitedMode)) then
        DrawSlider('Cast Font Size', 'targetBarCastFontSize', 8, 36);
        imgui.ShowHelp('Font size for enemy cast text that appears under the HP bar.');

        imgui.Text('Cast Bar Position & Scale:');
        DrawSlider('Cast Bar Offset Y', 'targetBarCastBarOffsetY', 0, 50, '%.0f');
        imgui.ShowHelp('Vertical distance below the HP bar (in pixels).');
        DrawSlider('Cast Bar Scale X', 'targetBarCastBarScaleX', 0.1, 3.0, '%.1f');
        imgui.ShowHelp('Horizontal scale multiplier for cast bar width.');
        DrawSlider('Cast Bar Scale Y', 'targetBarCastBarScaleY', 0.1, 3.0, '%.1f');
        imgui.ShowHelp('Vertical scale multiplier for cast bar height.');
    end

    imgui.Text('Buffs/Debuffs Position:');
    DrawSlider('Buffs Offset Y', 'targetBarBuffsOffsetY', -20, 50, '%.0f');
    imgui.ShowHelp('Vertical offset for buffs/debuffs below the HP bar (in pixels).');

    DrawSlider('Icon Scale', 'targetBarIconScale', 0.1, 3.0, '%.1f');
    DrawSlider('Icon Font Size', 'targetBarIconFontSize', 8, 36);

    -- Target of Target Bar settings (only show when split is enabled)
    if (gConfig.splitTargetOfTarget) then
        imgui.Spacing();
        imgui.Text('Target of Target Bar');
        imgui.Separator();

        DrawSlider('ToT Scale X', 'totBarScaleX', 0.1, 3.0, '%.1f');
        DrawSlider('ToT Scale Y', 'totBarScaleY', 0.1, 3.0, '%.1f');
        DrawSlider('ToT Font Size', 'totBarFontSize', 8, 36);
    end
end

-- Section: Target Bar Color Settings
local function DrawTargetBarColorSettings()
    imgui.Text("Bar Colors:");
    imgui.Separator();
    DrawGradientPicker("Target HP Bar", gConfig.colorCustomization.targetBar.hpGradient, "Target HP bar color");
    if (not HzLimitedMode) then
        DrawGradientPicker("Cast Bar", gConfig.colorCustomization.targetBar.castBarGradient, "Enemy cast bar color");
    end

    imgui.Spacing();
    imgui.Text("Text Colors:");
    imgui.Separator();
    DrawTextColorPicker("Distance Text", gConfig.colorCustomization.targetBar, 'distanceTextColor', "Color of distance text");
    if (not HzLimitedMode) then
        DrawTextColorPicker("Cast Text", gConfig.colorCustomization.targetBar, 'castTextColor', "Color of enemy cast text");
    end
    imgui.ShowHelp("Target name colors are in the Global section\nHP Percent text color is set dynamically based on HP amount");

    -- Target of Target colors
    imgui.Spacing();
    imgui.Text("Target of Target:");
    imgui.Separator();
    DrawGradientPicker("ToT HP Bar", gConfig.colorCustomization.totBar.hpGradient, "Target of Target HP bar color");
    DrawTextColorPicker("ToT Name Text", gConfig.colorCustomization.totBar, 'nameTextColor', "Color of target of target name text");
end

-- Section: Enemy List Settings
local function DrawEnemyListSettings()
    DrawCheckbox('Enabled', 'showEnemyList', CheckVisibility);
    DrawCheckbox('Show Distance', 'showEnemyDistance');
    if (gConfig.showEnemyDistance) then
        DrawSlider('Distance Font Size', 'enemyListDistanceFontSize', 8, 36);
    end
    DrawCheckbox('Show HP% Text', 'showEnemyHPPText');
    if (gConfig.showEnemyHPPText) then
        DrawSlider('HP% Font Size', 'enemyListPercentFontSize', 8, 36);
    end
    DrawCheckbox('Show Debuffs', 'showEnemyListDebuffs');
    if (gConfig.showEnemyListDebuffs) then
        DrawCheckbox('Right Align Debuffs', 'enemyListDebuffsRightAlign');
        imgui.ShowHelp('When enabled, debuff icons align to the right edge of each enemy entry instead of the left.');
        DrawSlider('Debuff Offset X', 'enemyListDebuffOffsetX', -100, 200);
        imgui.ShowHelp('Horizontal offset for debuff icons. Offsets from left edge (or right edge if right-aligned).');
        DrawSlider('Debuff Offset Y', 'enemyListDebuffOffsetY', -100, 200);
        imgui.ShowHelp('Vertical offset for debuff icons from top of entry.');
        DrawSlider('Status Effect Icon Size', 'enemyListIconScale', 0.1, 3.0, '%.1f');
    end
    DrawCheckbox('Show Enemy Targets', 'showEnemyListTargets');
    imgui.ShowHelp('Shows who each enemy is targeting based on their last action.');
    DrawCheckbox('Show Bookends', 'showEnemyListBookends');
    if (not HzLimitedMode) then
        DrawCheckbox('Click to Target', 'enableEnemyListClickTarget');
        imgui.ShowHelp('Click on an enemy entry to target it. Requires /shorthand to be enabled.');
    end

    DrawSlider('Scale X', 'enemyListScaleX', 0.1, 3.0, '%.1f');
    DrawSlider('Scale Y', 'enemyListScaleY', 0.1, 3.0, '%.1f');
    DrawSlider('Name Font Size', 'enemyListNameFontSize', 8, 36);
    DrawSlider('Rows Per Column', 'enemyListRowsPerColumn', 1, 20);
    imgui.ShowHelp('Number of enemies to show per column before starting a new column.');
    DrawSlider('Max Columns', 'enemyListMaxColumns', 1, 5);
    imgui.ShowHelp('Maximum number of columns to display. Total enemies = Rows x Columns.');
    DrawSlider('Row Spacing', 'enemyListRowSpacing', 0, 20);
    imgui.ShowHelp('Vertical space between enemy entries.');
    DrawSlider('Column Spacing', 'enemyListColumnSpacing', 0, 50);
    imgui.ShowHelp('Horizontal space between columns.');
end

-- Section: Enemy List Color Settings
local function DrawEnemyListColorSettings()
    imgui.Text("HP Bar Color:");
    imgui.Separator();
    DrawGradientPicker("Enemy HP Bar", gConfig.colorCustomization.enemyList.hpGradient, "Enemy HP bar color");

    imgui.Spacing();
    imgui.Text("Text Colors:");
    imgui.Separator();
    DrawTextColorPicker("Distance Text", gConfig.colorCustomization.enemyList, 'distanceTextColor', "Color of distance text");
    DrawTextColorPicker("HP% Text", gConfig.colorCustomization.enemyList, 'percentTextColor', "Color of HP percentage text");
    imgui.ShowHelp("Enemy name colors are in the Global section");

    imgui.Spacing();
    imgui.Text("Border Colors:");
    imgui.Separator();
    DrawTextColorPicker("Target Border", gConfig.colorCustomization.enemyList, 'targetBorderColor', "Border color for currently targeted enemy");
    DrawTextColorPicker("Subtarget Border", gConfig.colorCustomization.enemyList, 'subtargetBorderColor', "Border color for subtargeted enemy");
end

-- Section: Party List Settings
local function DrawPartyListSettings()
    DrawCheckbox('Enabled', 'showPartyList', CheckVisibility);

    -- Layout Selector
    local layoutItems = { [0] = 'Layout 1 (Horizontal)', [1] = 'Layout 2 (Compact Vertical)' };
    if imgui.BeginCombo('Layout', layoutItems[gConfig.partyListLayout]) then
        for i = 0, 1 do
            local is_selected = i == gConfig.partyListLayout;
            if imgui.Selectable(layoutItems[i], is_selected) then
                if gConfig.partyListLayout ~= i then
                    gConfig.partyListLayout = i;
                    UpdateSettings();
                    SaveSettingsOnly();
                    if partyList ~= nil then
                        partyList.UpdateVisuals(gAdjustedSettings.partyListSettings);
                    end
                end
            end
            if is_selected then
                imgui.SetItemDefaultFocus();
            end
        end
        imgui.EndCombo();
    end
    imgui.ShowHelp('Select between horizontal (Layout 1) and compact vertical (Layout 2) party list layouts. Each layout has independent settings.');

    DrawCheckbox('Preview Full Party (when config open)', 'partyListPreview');
    if gConfig.partyListLayout ~= 2 then
        DrawCheckbox('Flash TP at 100%', 'partyListFlashTP');
    end
    DrawCheckbox('Show Distance', 'showPartyListDistance');
    if gConfig.showPartyListDistance then
        DrawSlider('Distance Highlighting', 'partyListDistanceHighlight', 0.0, 50.0, '%.1f');
    end
    DrawCheckbox('Show Job Icons', 'showPartyJobIcon');
    DrawCheckbox('Show Job/Subjob', 'showPartyListJob');
    imgui.ShowHelp('Display job and subjob info on the right side of the name row (Layout 1 only).');
    DrawCheckbox('Show Cast Bars', 'partyListCastBars');
    if (gConfig.partyListCastBars) then
        DrawSlider('Cast Bar Scale Y', 'partyListCastBarScaleY', 0.1, 3.0, '%.1f');
        imgui.ShowHelp('Fast cast settings are shared with Cast Bar config section.');
    end

    DrawCheckbox('Show Bookends', 'showPartyListBookends');
    DrawCheckbox('Show When Solo', 'showPartyListWhenSolo');
    DrawCheckbox('Show Title', 'showPartyListTitle');
    DrawCheckbox('Hide During Events', 'partyListHideDuringEvents');
    DrawCheckbox('Align Bottom', 'partyListAlignBottom');
    DrawCheckbox('Expand Height', 'partyListExpandHeight');
    DrawCheckbox('Alliance Windows', 'partyListAlliance');

    -- Background
    DrawSlider('Background Scale', 'partyListBgScale', 0.1, 3.0, '%.2f', UpdatePartyListVisuals);

    local bg_theme_paths = statusHandler.get_background_paths();
    DrawComboBox('Background', gConfig.partyListBackgroundName, bg_theme_paths, function(newValue)
        gConfig.partyListBackgroundName = newValue;
        SaveSettingsOnly();
        DeferredUpdateVisuals();
    end);
    imgui.ShowHelp('The image to use for the party list background. [Resolution: 512x512 @ XIUI\\assets\\backgrounds]');

    -- Cursor
    local cursor_paths = statusHandler.get_cursor_paths();
    DrawComboBox('Cursor', gConfig.partyListCursor, cursor_paths, function(newValue)
        gConfig.partyListCursor = newValue;
        SaveSettingsOnly();
        DeferredUpdateVisuals();
    end);
    imgui.ShowHelp('The image to use for the party list cursor. [@ XIUI\\assets\\cursors]');

    -- Status Theme
    local comboBoxItems = { [0] = 'HorizonXI', [1] = 'HorizonXI-R', [2] = 'FFXIV', [3] = 'FFXI', [4] = 'Disabled' };
    gConfig.partyListStatusTheme = math.clamp(gConfig.partyListStatusTheme, 0, 4);
    if(imgui.BeginCombo('Status Theme', comboBoxItems[gConfig.partyListStatusTheme])) then
        for i = 0, #comboBoxItems do
            local is_selected = i == gConfig.partyListStatusTheme;

            if (imgui.Selectable(comboBoxItems[i], is_selected) and gConfig.partyListStatusTheme ~= i) then
                gConfig.partyListStatusTheme = i;
                SaveSettingsOnly();
            end
            if(is_selected) then
                imgui.SetItemDefaultFocus();
            end
        end
        imgui.EndCombo();
    end

    DrawSlider('Status Icon Scale', 'partyListBuffScale', 0.1, 3.0, '%.1f');

    -- Main Party Settings
    imgui.Spacing();
    imgui.Text('Party');
    imgui.Separator();

    DrawPartyLayoutCheckbox('Show TP', 'partyListTP');
    DrawPartyLayoutSlider('Min Rows', 'partyListMinRows', 1, 6);

    -- Layout 1: General Scale X and Y
    if gConfig.partyListLayout == 0 then
        DrawPartyLayoutSlider('Scale X', 'partyListScaleX', 0.1, 3.0, '%.2f');
        DrawPartyLayoutSlider('Scale Y', 'partyListScaleY', 0.1, 3.0, '%.2f');
    end

    -- Layout 2: Individual HP and MP bar X and Y scales
    if gConfig.partyListLayout == 1 then
        DrawPartyLayoutSlider('HP Bar Scale X', 'hpBarScaleX', 0.1, 3.0, '%.2f');
        DrawPartyLayoutSlider('MP Bar Scale X', 'mpBarScaleX', 0.1, 3.0, '%.2f');
        DrawPartyLayoutSlider('HP Bar Scale Y', 'hpBarScaleY', 0.1, 3.0, '%.2f');
        DrawPartyLayoutSlider('MP Bar Scale Y', 'mpBarScaleY', 0.1, 3.0, '%.2f');
    end

    -- Font Size: Layout 2 has separate controls, Layout 1 has single control
    if gConfig.partyListLayout == 1 then
        DrawPartyLayoutSlider('Name Font Size', 'partyListNameFontSize', 8, 36);
        DrawPartyLayoutSlider('HP Font Size', 'partyListHpFontSize', 8, 36);
        DrawPartyLayoutSlider('MP Font Size', 'partyListMpFontSize', 8, 36);
        DrawPartyLayoutSlider('TP Font Size', 'partyListTpFontSize', 8, 36);
    else
        DrawPartyLayoutSlider('Font Size', 'partyListFontSize', 8, 36);
    end
    if gConfig.showPartyJobIcon then
        DrawPartyLayoutSlider('Job Icon Scale', 'partyListJobIconScale', 0.1, 3.0, '%.1f');
    end
    DrawPartyLayoutSlider('Entry Spacing', 'partyListEntrySpacing', -4, 16);
    DrawPartyLayoutSlider('Selection Box Scale Y', 'selectionBoxScaleY', 0.5, 2.0, '%.2f');

    -- Party B (Alliance)
    if (gConfig.partyListAlliance) then
        imgui.Spacing();
        imgui.Text('Party B (Alliance)');
        imgui.Separator();

        DrawPartyLayoutCheckbox('Show TP', 'partyList2TP');
        DrawPartyLayoutSlider('Scale X', 'partyList2ScaleX', 0.1, 3.0, '%.2f');
        DrawPartyLayoutSlider('Scale Y', 'partyList2ScaleY', 0.1, 3.0, '%.2f');

        -- Layout 2: Individual HP and MP bar X and Y scales
        if gConfig.partyListLayout == 1 then
            DrawPartyLayoutSlider('HP Bar Scale X', 'partyList2HpBarScaleX', 0.1, 3.0, '%.2f');
            DrawPartyLayoutSlider('MP Bar Scale X', 'partyList2MpBarScaleX', 0.1, 3.0, '%.2f');
            DrawPartyLayoutSlider('HP Bar Scale Y', 'partyList2HpBarScaleY', 0.1, 3.0, '%.2f');
            DrawPartyLayoutSlider('MP Bar Scale Y', 'partyList2MpBarScaleY', 0.1, 3.0, '%.2f');
        end

        -- Font Size: Layout 2 has separate controls, Layout 1 has single control
        if gConfig.partyListLayout == 1 then
            DrawPartyLayoutSlider('Name Font Size', 'partyList2NameFontSize', 8, 36);
            DrawPartyLayoutSlider('HP Font Size', 'partyList2HpFontSize', 8, 36);
            DrawPartyLayoutSlider('MP Font Size', 'partyList2MpFontSize', 8, 36);
        else
            DrawPartyLayoutSlider('Font Size', 'partyList2FontSize', 8, 36);
        end

        if gConfig.showPartyJobIcon then
            DrawPartyLayoutSlider('Job Icon Scale', 'partyList2JobIconScale', 0.1, 3.0, '%.1f');
        end
        DrawPartyLayoutSlider('Entry Spacing', 'partyList2EntrySpacing', -4, 16);
    end

    -- Party C (Alliance)
    if (gConfig.partyListAlliance) then
        imgui.Spacing();
        imgui.Text('Party C (Alliance)');
        imgui.Separator();

        DrawPartyLayoutCheckbox('Show TP', 'partyList3TP');
        DrawPartyLayoutSlider('Scale X', 'partyList3ScaleX', 0.1, 3.0, '%.2f');
        DrawPartyLayoutSlider('Scale Y', 'partyList3ScaleY', 0.1, 3.0, '%.2f');

        -- Layout 2: Individual HP and MP bar X and Y scales
        if gConfig.partyListLayout == 1 then
            DrawPartyLayoutSlider('HP Bar Scale X', 'partyList3HpBarScaleX', 0.1, 3.0, '%.2f');
            DrawPartyLayoutSlider('MP Bar Scale X', 'partyList3MpBarScaleX', 0.1, 3.0, '%.2f');
            DrawPartyLayoutSlider('HP Bar Scale Y', 'partyList3HpBarScaleY', 0.1, 3.0, '%.2f');
            DrawPartyLayoutSlider('MP Bar Scale Y', 'partyList3MpBarScaleY', 0.1, 3.0, '%.2f');
        end

        -- Font Size: Layout 2 has separate controls, Layout 1 has single control
        if gConfig.partyListLayout == 1 then
            DrawPartyLayoutSlider('Name Font Size', 'partyList3NameFontSize', 8, 36);
            DrawPartyLayoutSlider('HP Font Size', 'partyList3HpFontSize', 8, 36);
            DrawPartyLayoutSlider('MP Font Size', 'partyList3MpFontSize', 8, 36);
        else
            DrawPartyLayoutSlider('Font Size', 'partyList3FontSize', 8, 36);
        end

        if gConfig.showPartyJobIcon then
            DrawPartyLayoutSlider('Job Icon Scale', 'partyList3JobIconScale', 0.1, 3.0, '%.1f');
        end
        DrawPartyLayoutSlider('Entry Spacing', 'partyList3EntrySpacing', -4, 16);
    end
end

-- Section: Party List Color Settings
local function DrawPartyListColorSettings()
    imgui.Text("HP Bar Colors:");
    imgui.Separator();
    DrawGradientPicker("Party HP High (75-100%)", gConfig.colorCustomization.partyList.hpGradient.high, "Party member HP bar when health is above 75%");
    DrawGradientPicker("Party HP Med-High (50-75%)", gConfig.colorCustomization.partyList.hpGradient.medHigh, "Party member HP bar when health is 50-75%");
    DrawGradientPicker("Party HP Med-Low (25-50%)", gConfig.colorCustomization.partyList.hpGradient.medLow, "Party member HP bar when health is 25-50%");
    DrawGradientPicker("Party HP Low (0-25%)", gConfig.colorCustomization.partyList.hpGradient.low, "Party member HP bar when health is below 25%");

    imgui.Spacing();
    imgui.Text("MP/TP Bar Colors:");
    imgui.Separator();
    DrawGradientPicker("Party MP Bar", gConfig.colorCustomization.partyList.mpGradient, "Party member MP bar color");
    DrawGradientPicker("Party TP Bar", gConfig.colorCustomization.partyList.tpGradient, "Party member TP bar color");

    imgui.Spacing();
    imgui.Text("Cast Bar Colors:");
    imgui.Separator();
    DrawGradientPicker("Party Cast Bar", gConfig.colorCustomization.partyList.castBarGradient, "Party member cast bar color (appears when casting)");

    imgui.Spacing();
    imgui.Text("Bar Background Override:");
    imgui.Separator();
    local overrideActive = {gConfig.colorCustomization.partyList.barBackgroundOverride.active};
    if (imgui.Checkbox("Enable Background Override", overrideActive)) then
        gConfig.colorCustomization.partyList.barBackgroundOverride.active = overrideActive[1];
        UpdateSettings();
    end
    imgui.ShowHelp("When enabled, uses the colors below instead of the global bar background color");
    if gConfig.colorCustomization.partyList.barBackgroundOverride.active then
        DrawGradientPicker("Background Color", gConfig.colorCustomization.partyList.barBackgroundOverride, "Override color for party list bar backgrounds");
    end

    imgui.Spacing();
    imgui.Text("Bar Border Override:");
    imgui.Separator();
    local borderOverrideActive = {gConfig.colorCustomization.partyList.barBorderOverride.active};
    if (imgui.Checkbox("Enable Border Override", borderOverrideActive)) then
        gConfig.colorCustomization.partyList.barBorderOverride.active = borderOverrideActive[1];
        UpdateSettings();
    end
    imgui.ShowHelp("When enabled, uses the color below instead of the global bar background color for borders");
    if gConfig.colorCustomization.partyList.barBorderOverride.active then
        local borderColor = HexToImGui(gConfig.colorCustomization.partyList.barBorderOverride.color);
        if (imgui.ColorEdit4('Border Color##barBorderOverride', borderColor, bit.bor(ImGuiColorEditFlags_NoInputs, ImGuiColorEditFlags_AlphaBar))) then
            gConfig.colorCustomization.partyList.barBorderOverride.color = ImGuiToHex(borderColor);
        end
        if (imgui.IsItemDeactivatedAfterEdit()) then
            SaveSettingsOnly();
        end
        imgui.ShowHelp("Override color for party list bar borders");
    end

    imgui.Spacing();
    imgui.Text("Text Colors:");
    imgui.Separator();
    DrawTextColorPicker("Name Text", gConfig.colorCustomization.partyList, 'nameTextColor', "Color of party member name");
    DrawTextColorPicker("HP Text", gConfig.colorCustomization.partyList, 'hpTextColor', "Color of HP numbers");
    DrawTextColorPicker("MP Text", gConfig.colorCustomization.partyList, 'mpTextColor', "Color of MP numbers");
    DrawTextColorPicker("TP Text (Empty, <1000)", gConfig.colorCustomization.partyList, 'tpEmptyTextColor', "Color of TP numbers when below 1000");
    DrawTextColorPicker("TP Text (Full, >=1000)", gConfig.colorCustomization.partyList, 'tpFullTextColor', "Color of TP numbers when 1000 or higher");

    imgui.Spacing();
    imgui.Text("Background Colors:");
    imgui.Separator();
    DrawTextColorPicker("Background Color", gConfig.colorCustomization.partyList, 'bgColor', "Color of party list background");
    DrawTextColorPicker("Border Color", gConfig.colorCustomization.partyList, 'borderColor', "Color of party list borders");

    imgui.Spacing();
    imgui.Text("Selection Colors:");
    imgui.Separator();
    DrawGradientPicker("Selection Box", gConfig.colorCustomization.partyList.selectionGradient, "Color gradient for the selection box around targeted party members");
    DrawTextColorPicker("Selection Border", gConfig.colorCustomization.partyList, 'selectionBorderColor', "Color of the selection box border");
end

-- Section: Exp Bar Settings
local function DrawExpBarSettings()
    DrawCheckbox('Enabled', 'showExpBar', CheckVisibility);
    DrawCheckbox('Limit Points Mode', 'expBarLimitPointsMode');
    imgui.ShowHelp('Shows Limit Points if character is set to earn Limit Points in the game.');

    DrawCheckbox('Inline Mode', 'expBarInlineMode');
    DrawCheckbox('Show Bookends', 'showExpBarBookends');
    DrawCheckbox('Show Text', 'expBarShowText');
    DrawCheckbox('Show Percent', 'expBarShowPercent');

    DrawSlider('Scale X', 'expBarScaleX', 0.1, 3.0, '%.2f');
    DrawSlider('Scale Y', 'expBarScaleY', 0.1, 3.0, '%.2f');
    DrawSlider('Font Size', 'expBarFontSize', 8, 36);
end

-- Section: Exp Bar Color Settings
local function DrawExpBarColorSettings()
    imgui.Text("Bar Color:");
    imgui.Separator();
    DrawGradientPicker("Exp/Merit Bar", gConfig.colorCustomization.expBar.barGradient, "Color for EXP/Merit/Capacity bar");

    imgui.Spacing();
    imgui.Text("Text Colors:");
    imgui.Separator();
    DrawTextColorPicker("Job Text", gConfig.colorCustomization.expBar, 'jobTextColor', "Color of job level text");
    DrawTextColorPicker("Exp Text", gConfig.colorCustomization.expBar, 'expTextColor', "Color of experience numbers");
    DrawTextColorPicker("Percent Text", gConfig.colorCustomization.expBar, 'percentTextColor', "Color of percentage text");
end

-- Section: Gil Tracker Settings
local function DrawGilTrackerSettings()
    DrawCheckbox('Enabled', 'showGilTracker', CheckVisibility);
    DrawSlider('Scale', 'gilTrackerScale', 0.1, 3.0, '%.1f');
    DrawSlider('Font Size', 'gilTrackerFontSize', 8, 36);
    DrawCheckbox('Right Align', 'gilTrackerRightAlign', UpdateGilTrackerVisuals);
end

-- Section: Gil Tracker Color Settings
local function DrawGilTrackerColorSettings()
    imgui.Text("Text Color:");
    imgui.Separator();
    DrawTextColorPicker("Gil Text", gConfig.colorCustomization.gilTracker, 'textColor', "Color of gil amount text");
end

-- Section: Inventory Tracker Settings
local function DrawInventoryTrackerSettings()
    DrawCheckbox('Enabled', 'showInventoryTracker', CheckVisibility);
    DrawCheckbox('Show Count', 'inventoryShowCount');

    local columnCount = { gConfig.inventoryTrackerColumnCount };
    if (imgui.SliderInt('Columns', columnCount, 1, 80)) then
        gConfig.inventoryTrackerColumnCount = columnCount[1];
        UpdateUserSettings();
    end
    if (imgui.IsItemDeactivatedAfterEdit()) then
        SaveSettingsOnly();
    end

    local rowCount = { gConfig.inventoryTrackerRowCount };
    if (imgui.SliderInt('Rows', rowCount, 1, 80)) then
        gConfig.inventoryTrackerRowCount = rowCount[1];
        UpdateUserSettings();
    end
    if (imgui.IsItemDeactivatedAfterEdit()) then
        SaveSettingsOnly();
    end

    DrawSlider('Scale', 'inventoryTrackerScale', 0.5, 3.0, '%.1f');
    DrawSlider('Font Size', 'inventoryTrackerFontSize', 8, 36);
end

-- Section: Inventory Tracker Color Settings
local function DrawInventoryTrackerColorSettings()
    imgui.Text("Text Color:");
    imgui.Separator();
    DrawTextColorPicker("Count Text", gConfig.colorCustomization.inventoryTracker, 'textColor', "Color of inventory count text");

    imgui.Spacing();
    imgui.Text("Dot Colors:");
    imgui.Separator();

    local emptySlot = {
        gConfig.colorCustomization.inventoryTracker.emptySlotColor.r,
        gConfig.colorCustomization.inventoryTracker.emptySlotColor.g,
        gConfig.colorCustomization.inventoryTracker.emptySlotColor.b,
        gConfig.colorCustomization.inventoryTracker.emptySlotColor.a
    };
    if (imgui.ColorEdit4('Empty Slot', emptySlot, bit.bor(ImGuiColorEditFlags_AlphaBar, ImGuiColorEditFlags_NoInputs))) then
        gConfig.colorCustomization.inventoryTracker.emptySlotColor.r = emptySlot[1];
        gConfig.colorCustomization.inventoryTracker.emptySlotColor.g = emptySlot[2];
        gConfig.colorCustomization.inventoryTracker.emptySlotColor.b = emptySlot[3];
        gConfig.colorCustomization.inventoryTracker.emptySlotColor.a = emptySlot[4];
    end
    if (imgui.IsItemDeactivatedAfterEdit()) then SaveSettingsOnly(); end
    imgui.ShowHelp('Color for empty inventory slots');

    local usedSlot = {
        gConfig.colorCustomization.inventoryTracker.usedSlotColor.r,
        gConfig.colorCustomization.inventoryTracker.usedSlotColor.g,
        gConfig.colorCustomization.inventoryTracker.usedSlotColor.b,
        gConfig.colorCustomization.inventoryTracker.usedSlotColor.a
    };
    if (imgui.ColorEdit4('Used Slot (Normal)', usedSlot, bit.bor(ImGuiColorEditFlags_AlphaBar, ImGuiColorEditFlags_NoInputs))) then
        gConfig.colorCustomization.inventoryTracker.usedSlotColor.r = usedSlot[1];
        gConfig.colorCustomization.inventoryTracker.usedSlotColor.g = usedSlot[2];
        gConfig.colorCustomization.inventoryTracker.usedSlotColor.b = usedSlot[3];
        gConfig.colorCustomization.inventoryTracker.usedSlotColor.a = usedSlot[4];
    end
    if (imgui.IsItemDeactivatedAfterEdit()) then SaveSettingsOnly(); end
    imgui.ShowHelp('Color for used inventory slots (normal)');

    local usedSlotThreshold1 = {
        gConfig.colorCustomization.inventoryTracker.usedSlotColorThreshold1.r,
        gConfig.colorCustomization.inventoryTracker.usedSlotColorThreshold1.g,
        gConfig.colorCustomization.inventoryTracker.usedSlotColorThreshold1.b,
        gConfig.colorCustomization.inventoryTracker.usedSlotColorThreshold1.a
    };
    if (imgui.ColorEdit4('Used Slot (Warning)', usedSlotThreshold1, bit.bor(ImGuiColorEditFlags_AlphaBar, ImGuiColorEditFlags_NoInputs))) then
        gConfig.colorCustomization.inventoryTracker.usedSlotColorThreshold1.r = usedSlotThreshold1[1];
        gConfig.colorCustomization.inventoryTracker.usedSlotColorThreshold1.g = usedSlotThreshold1[2];
        gConfig.colorCustomization.inventoryTracker.usedSlotColorThreshold1.b = usedSlotThreshold1[3];
        gConfig.colorCustomization.inventoryTracker.usedSlotColorThreshold1.a = usedSlotThreshold1[4];
    end
    if (imgui.IsItemDeactivatedAfterEdit()) then SaveSettingsOnly(); end
    imgui.ShowHelp('Color for used inventory slots when at warning threshold');

    local usedSlotThreshold2 = {
        gConfig.colorCustomization.inventoryTracker.usedSlotColorThreshold2.r,
        gConfig.colorCustomization.inventoryTracker.usedSlotColorThreshold2.g,
        gConfig.colorCustomization.inventoryTracker.usedSlotColorThreshold2.b,
        gConfig.colorCustomization.inventoryTracker.usedSlotColorThreshold2.a
    };
    if (imgui.ColorEdit4('Used Slot (Critical)', usedSlotThreshold2, bit.bor(ImGuiColorEditFlags_AlphaBar, ImGuiColorEditFlags_NoInputs))) then
        gConfig.colorCustomization.inventoryTracker.usedSlotColorThreshold2.r = usedSlotThreshold2[1];
        gConfig.colorCustomization.inventoryTracker.usedSlotColorThreshold2.g = usedSlotThreshold2[2];
        gConfig.colorCustomization.inventoryTracker.usedSlotColorThreshold2.b = usedSlotThreshold2[3];
        gConfig.colorCustomization.inventoryTracker.usedSlotColorThreshold2.a = usedSlotThreshold2[4];
    end
    if (imgui.IsItemDeactivatedAfterEdit()) then SaveSettingsOnly(); end
    imgui.ShowHelp('Color for used inventory slots when at critical threshold');

    imgui.Spacing();
    imgui.Text("Color Thresholds:");
    imgui.Separator();

    local threshold1 = { gConfig.inventoryTrackerColorThreshold1 };
    if (imgui.SliderInt('Warning Threshold', threshold1, 0, 80)) then
        gConfig.inventoryTrackerColorThreshold1 = threshold1[1];
    end
    if (imgui.IsItemDeactivatedAfterEdit()) then SaveSettingsOnly(); end
    imgui.ShowHelp('Inventory count at which dots turn to warning color');

    local threshold2 = { gConfig.inventoryTrackerColorThreshold2 };
    if (imgui.SliderInt('Critical Threshold', threshold2, 0, 80)) then
        gConfig.inventoryTrackerColorThreshold2 = threshold2[1];
    end
    if (imgui.IsItemDeactivatedAfterEdit()) then SaveSettingsOnly(); end
    imgui.ShowHelp('Inventory count at which dots turn to critical color');
end

-- Helper for Cast Bar: Draw a single fast cast slider
local function DrawFastCastSlider(jobName, jobIndex)
    local value = { gConfig.castBarFastCast[jobIndex] };
    if (imgui.SliderFloat('Fast Cast - ' .. jobName, value, 0.00, 1.00, '%.2f')) then
        gConfig.castBarFastCast[jobIndex] = value[1];
    end
    if (imgui.IsItemDeactivatedAfterEdit()) then
        SaveSettingsOnly();
    end
end

-- Section: Cast Bar Settings
local function DrawCastBarSettings()
    DrawCheckbox('Enabled', 'showCastBar', CheckVisibility);
    DrawCheckbox('Show Bookends', 'showCastBarBookends');

    DrawSlider('Scale X', 'castBarScaleX', 0.1, 3.0, '%.1f');
    DrawSlider('Scale Y', 'castBarScaleY', 0.1, 3.0, '%.1f');
    DrawSlider('Font Size', 'castBarFontSize', 8, 36);

    DrawCheckbox('Enable Fast Cast / True Display', 'castBarFastCastEnabled');

    -- Special fast cast sliders
    local castBarFCRDMSJ = { gConfig.castBarFastCastRDMSJ };
    if (imgui.SliderFloat('Fast Cast - RDM SubJob', castBarFCRDMSJ, 0.00, 1.00, '%.2f')) then
        gConfig.castBarFastCastRDMSJ = castBarFCRDMSJ[1];
    end
    if (imgui.IsItemDeactivatedAfterEdit()) then SaveSettingsOnly(); end

    local castBarFCWHMCureSpeed = { gConfig.castBarFastCastWHMCureSpeed };
    if (imgui.SliderFloat('WHM Cure Speed', castBarFCWHMCureSpeed, 0.00, 1.00, '%.2f')) then
        gConfig.castBarFastCastWHMCureSpeed = castBarFCWHMCureSpeed[1];
    end
    if (imgui.IsItemDeactivatedAfterEdit()) then SaveSettingsOnly(); end

    local castBarFCBRDSingSpeed = { gConfig.castBarFastCastBRDSingSpeed };
    if (imgui.SliderFloat('BRD Sing Speed', castBarFCBRDSingSpeed, 0.00, 1.00, '%.2f')) then
        gConfig.castBarFastCastBRDSingSpeed = castBarFCBRDSingSpeed[1];
    end
    if (imgui.IsItemDeactivatedAfterEdit()) then SaveSettingsOnly(); end

    -- Job-specific fast cast sliders (using helper function)
    local jobs = { 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG', 'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP', 'DNC', 'SCH', 'GEO', 'RUN' };
    for i = 1, #jobs do
        DrawFastCastSlider(jobs[i], i);
    end
end

-- Section: Cast Bar Color Settings
local function DrawCastBarColorSettings()
    imgui.Text("Bar Color:");
    imgui.Separator();
    DrawGradientPicker("Cast Bar", gConfig.colorCustomization.castBar.barGradient, "Color of casting progress bar");

    imgui.Spacing();
    imgui.Text("Text Colors:");
    imgui.Separator();
    DrawTextColorPicker("Spell Text", gConfig.colorCustomization.castBar, 'spellTextColor', "Color of spell/ability name");
    DrawTextColorPicker("Percent Text", gConfig.colorCustomization.castBar, 'percentTextColor', "Color of cast percentage");
end

-- Dispatch tables for settings and color settings
local settingsDrawFunctions = {
    DrawGlobalSettings,
    DrawPlayerBarSettings,
    DrawTargetBarSettings,
    DrawEnemyListSettings,
    DrawPartyListSettings,
    DrawExpBarSettings,
    DrawGilTrackerSettings,
    DrawInventoryTrackerSettings,
    DrawCastBarSettings,
};

local colorSettingsDrawFunctions = {
    DrawGlobalColorSettings,
    DrawPlayerBarColorSettings,
    DrawTargetBarColorSettings,
    DrawEnemyListColorSettings,
    DrawPartyListColorSettings,
    DrawExpBarColorSettings,
    DrawGilTrackerColorSettings,
    DrawInventoryTrackerColorSettings,
    DrawCastBarColorSettings,
};

config.DrawWindow = function(us)
    -- Colors
    local bgColor = {0.18, 0.18, 0.18, 0.95};
    local sidebarBgColor = {0.22, 0.22, 0.22, 1.0};
    local buttonColor = {0.25, 0.25, 0.25, 1.0};
    local buttonHoverColor = {0.35, 0.35, 0.35, 1.0};
    local buttonActiveColor = {0.45, 0.45, 0.45, 1.0};
    local selectedButtonColor = {0.4, 0.4, 0.4, 1.0};
    local tabColor = {0.25, 0.25, 0.25, 1.0};
    local tabHoverColor = {0.35, 0.35, 0.35, 1.0};
    local tabActiveColor = {0.3, 0.3, 0.3, 1.0};
    local tabSelectedColor = {0.18, 0.18, 0.18, 1.0};
    local contentBorderColor = {0.5, 0.5, 0.5, 1.0};
    local headerTextColor = {0.9, 0.9, 0.9, 1.0};

    imgui.PushStyleColor(ImGuiCol_WindowBg, bgColor);
    imgui.PushStyleColor(ImGuiCol_TitleBg, {0.15, 0.15, 0.15, 1.0});
    imgui.PushStyleColor(ImGuiCol_TitleBgActive, {0.2, 0.2, 0.2, 1.0});
    imgui.PushStyleColor(ImGuiCol_TitleBgCollapsed, {0.1, 0.1, 0.1, 0.8});
    imgui.PushStyleColor(ImGuiCol_FrameBg, {0.15, 0.15, 0.15, 1.0});
    imgui.PushStyleColor(ImGuiCol_FrameBgHovered, {0.2, 0.2, 0.2, 1.0});
    imgui.PushStyleColor(ImGuiCol_FrameBgActive, {0.25, 0.25, 0.25, 1.0});
    imgui.PushStyleColor(ImGuiCol_Header, {0.2, 0.2, 0.2, 1.0});
    imgui.PushStyleColor(ImGuiCol_HeaderHovered, {0.25, 0.25, 0.25, 1.0});
    imgui.PushStyleColor(ImGuiCol_HeaderActive, {0.3, 0.3, 0.3, 1.0});
    imgui.PushStyleColor(ImGuiCol_Border, contentBorderColor);
    imgui.PushStyleColor(ImGuiCol_Text, headerTextColor);

    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, {12, 12});
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, {6, 4});
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, {8, 6});

    imgui.SetNextWindowSize({ 900, 650 }, ImGuiCond_FirstUseEver);
    if(showConfig[1] and imgui.Begin("xiui config", showConfig, bit.bor(ImGuiWindowFlags_NoSavedSettings))) then
        local windowWidth = imgui.GetContentRegionAvail();
        local sidebarWidth = 180;
        local contentWidth = windowWidth - sidebarWidth - 20;

        -- Top bar with restore defaults buttons
        imgui.PushStyleColor(ImGuiCol_Button, buttonColor);
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, buttonHoverColor);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, buttonActiveColor);

        if(imgui.Button("restore defaults", { 120, 22 })) then
            showRestoreDefaultsConfirm = true;
        end
        imgui.SameLine();
        imgui.SetCursorPosX(windowWidth - 120);
        if(imgui.Button("restore defaults", { 120, 22 })) then
            showRestoreColorsConfirm = true;
        end

        imgui.PopStyleColor(3);

        -- Reset Settings confirmation popup
        if (showRestoreDefaultsConfirm) then
            imgui.OpenPopup("Confirm Reset Settings");
            showRestoreDefaultsConfirm = false;
        end

        if (imgui.BeginPopupModal("Confirm Reset Settings", true, ImGuiWindowFlags_AlwaysAutoResize)) then
            imgui.Text("Are you sure you want to reset all settings to defaults?");
            imgui.Text("This will reset all your customizations including:");
            imgui.BulletText("UI positions, scales, and visibility");
            imgui.BulletText("Font settings");
            imgui.NewLine();

            if (imgui.Button("Confirm", { 120, 0 })) then
                ResetSettings();
                UpdateSettings();
                imgui.CloseCurrentPopup();
            end
            imgui.SameLine();
            if (imgui.Button("Cancel", { 120, 0 })) then
                imgui.CloseCurrentPopup();
            end

            imgui.EndPopup();
        end

        -- Reset Colors confirmation popup
        if (showRestoreColorsConfirm) then
            imgui.OpenPopup("Confirm Restore Colors");
            showRestoreColorsConfirm = false;
        end

        if (imgui.BeginPopupModal("Confirm Restore Colors", true, ImGuiWindowFlags_AlwaysAutoResize)) then
            imgui.Text("Are you sure you want to restore all colors to defaults?");
            imgui.Text("This will reset all your custom colors.");
            imgui.NewLine();

            if (imgui.Button("Confirm", { 120, 0 })) then
                gConfig.colorCustomization = deep_copy_table(defaultUserSettings.colorCustomization);
                UpdateSettings();
                imgui.CloseCurrentPopup();
            end
            imgui.SameLine();
            if (imgui.Button("Cancel", { 120, 0 })) then
                imgui.CloseCurrentPopup();
            end

            imgui.EndPopup();
        end

        imgui.Spacing();

        -- Main layout: sidebar + content area
        -- Left sidebar with category buttons
        imgui.PushStyleColor(ImGuiCol_ChildBg, sidebarBgColor);
        imgui.BeginChild("Sidebar", { sidebarWidth, 0 }, false);

        imgui.PushStyleVar(ImGuiStyleVar_FramePadding, {10, 8});
        imgui.SetWindowFontScale(1.1);

        for i, category in ipairs(categories) do
            -- Style the button differently if selected
            if i == selectedCategory then
                imgui.PushStyleColor(ImGuiCol_Button, selectedButtonColor);
                imgui.PushStyleColor(ImGuiCol_ButtonHovered, selectedButtonColor);
                imgui.PushStyleColor(ImGuiCol_ButtonActive, selectedButtonColor);
            else
                imgui.PushStyleColor(ImGuiCol_Button, {0, 0, 0, 0});
                imgui.PushStyleColor(ImGuiCol_ButtonHovered, buttonHoverColor);
                imgui.PushStyleColor(ImGuiCol_ButtonActive, buttonActiveColor);
            end

            if (imgui.Button(category.label, { sidebarWidth - 16, 32 })) then
                selectedCategory = i;
            end

            imgui.PopStyleColor(3);
        end

        imgui.PopStyleVar();
        imgui.EndChild();
        imgui.PopStyleColor();

        imgui.SameLine();

        -- Right content area
        imgui.BeginChild("ContentArea", { 0, 0 }, false);

        -- Tab bar at top of content area
        local tabWidth = 140;
        local tabHeight = 28;

        imgui.PushStyleVar(ImGuiStyleVar_FramePadding, {12, 6});
        imgui.SetWindowFontScale(1.05);

        -- Settings tab
        if selectedTab == 1 then
            imgui.PushStyleColor(ImGuiCol_Button, tabSelectedColor);
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, tabSelectedColor);
            imgui.PushStyleColor(ImGuiCol_ButtonActive, tabSelectedColor);
        else
            imgui.PushStyleColor(ImGuiCol_Button, tabColor);
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, tabHoverColor);
            imgui.PushStyleColor(ImGuiCol_ButtonActive, tabActiveColor);
        end
        if (imgui.Button("settings", { tabWidth, tabHeight })) then
            selectedTab = 1;
        end
        imgui.PopStyleColor(3);

        imgui.SameLine();

        -- Color settings tab
        if selectedTab == 2 then
            imgui.PushStyleColor(ImGuiCol_Button, tabSelectedColor);
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, tabSelectedColor);
            imgui.PushStyleColor(ImGuiCol_ButtonActive, tabSelectedColor);
        else
            imgui.PushStyleColor(ImGuiCol_Button, tabColor);
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, tabHoverColor);
            imgui.PushStyleColor(ImGuiCol_ButtonActive, tabActiveColor);
        end
        if (imgui.Button("color settings", { tabWidth, tabHeight })) then
            selectedTab = 2;
        end
        imgui.PopStyleColor(3);

        imgui.PopStyleVar();

        -- Content panel with border
        imgui.PushStyleColor(ImGuiCol_ChildBg, bgColor);
        imgui.PushStyleColor(ImGuiCol_Border, contentBorderColor);
        imgui.BeginChild("SettingsContent", { 0, 0 }, true);

        imgui.SetWindowFontScale(0.95);

        -- Draw the appropriate settings based on selected category and tab
        if selectedTab == 1 then
            if settingsDrawFunctions[selectedCategory] then
                settingsDrawFunctions[selectedCategory]();
            end
        else
            if colorSettingsDrawFunctions[selectedCategory] then
                colorSettingsDrawFunctions[selectedCategory]();
            end
        end

        imgui.EndChild();
        imgui.PopStyleColor(2);

        imgui.EndChild();
    end

    imgui.PopStyleVar(3);
    imgui.PopStyleColor(12);
    imgui.End();
end

return config;
