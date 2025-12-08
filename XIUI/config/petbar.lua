--[[
* XIUI Config Menu - Pet Bar Settings
* Contains settings and color settings for Pet Bar and Pet Target (SMN, BST, DRG, PUP)
]]--

require('common');
require('handlers.helpers');
local components = require('config.components');
local imgui = require('imgui');
local petData = require('modules.petbar.data');

local M = {};

-- Track selected avatar in config dropdown
local selectedAvatarIndex = 1;

-- Pet type definitions for sub-tabs
-- previewType maps to data.PREVIEW_* constants: WYVERN=1, AVATAR=2, AUTOMATON=3, JUG=4, CHARM=5
local PET_TYPES = {
    { key = 'Avatar', configKey = 'petBarAvatar', label = 'Avatar', previewType = 2 },
    { key = 'Charm', configKey = 'petBarCharm', label = 'Charm', previewType = 5 },
    { key = 'Jug', configKey = 'petBarJug', label = 'Jug', previewType = 4 },
    { key = 'Automaton', configKey = 'petBarAutomaton', label = 'Automaton', previewType = 3 },
    { key = 'Wyvern', configKey = 'petBarWyvern', label = 'Wyvern', previewType = 1 },
};

-- Copy settings between pet types
local function CopyPetTypeSettings(sourceKey, targetKey)
    local source = gConfig[sourceKey];
    local target = gConfig[targetKey];
    -- Validate both source and target are tables
    if source and target and type(source) == 'table' and type(target) == 'table' then
        for k, v in pairs(source) do
            if type(v) == 'table' then
                target[k] = deep_copy_table(v);
            else
                target[k] = v;
            end
        end
        SaveSettingsOnly();
    end
end

-- Copy color settings between pet types
local function CopyPetTypeColors(sourceKey, targetKey)
    local colorSource = gConfig.colorCustomization and gConfig.colorCustomization[sourceKey];
    -- Validate source is a table
    if colorSource and type(colorSource) == 'table' then
        gConfig.colorCustomization[targetKey] = deep_copy_table(colorSource);
        SaveSettingsOnly();
    end
end

-- Helper: Draw per-pet-type visual settings
local function DrawPetTypeVisualSettings(configKey, petTypeLabel)
    local typeSettings = gConfig[configKey];
    -- Validate typeSettings is a table with expected properties
    if not typeSettings or type(typeSettings) ~= 'table' or typeSettings.hpScaleX == nil then
        imgui.TextColored({1.0, 0.5, 0.5, 1.0}, 'Settings not initialized for ' .. petTypeLabel);
        imgui.Text('Please reload the addon to initialize per-type settings.');
        return;
    end

    if components.CollapsingSection('Display Options##' .. configKey) then
        components.DrawPartyCheckbox(typeSettings, 'Show Pet Level##' .. configKey, 'showLevel');
        imgui.ShowHelp('Show pet level before the name (e.g., "Lv.35 FunguarFamiliar").');

        imgui.Spacing();
        imgui.Text('Distance');
        components.DrawPartyCheckbox(typeSettings, 'Show Distance##' .. configKey, 'showDistance');
        imgui.ShowHelp('Show distance from player to pet.');

        if typeSettings.showDistance then
            -- Position mode
            local positionModes = {'Next to Name', 'Absolute'};
            local currentMode = typeSettings.distanceAbsolute and 'Absolute' or 'Next to Name';
            imgui.SetNextItemWidth(150);
            if imgui.BeginCombo('Position Mode##dist' .. configKey, currentMode) then
                for _, mode in ipairs(positionModes) do
                    if imgui.Selectable(mode, mode == currentMode) then
                        typeSettings.distanceAbsolute = (mode == 'Absolute');
                        SaveSettingsOnly();
                    end
                end
                imgui.EndCombo();
            end
            imgui.ShowHelp('Next to Name: Distance appears after pet name.\nAbsolute: Distance positioned relative to window.');

            if typeSettings.distanceAbsolute then
                components.DrawPartySlider(typeSettings, 'Offset X##dist' .. configKey, 'distanceOffsetX', -200, 200);
                imgui.ShowHelp('Horizontal offset from window left.');
                components.DrawPartySlider(typeSettings, 'Offset Y##dist' .. configKey, 'distanceOffsetY', -200, 200);
                imgui.ShowHelp('Vertical offset from window top.');
            end
        end
    end

    if components.CollapsingSection('Bar Settings##' .. configKey) then
        -- HP Bar
        components.DrawPartyCheckbox(typeSettings, 'Show HP Bar##' .. configKey, 'showHP');
        imgui.ShowHelp('Show pet HP bar.');
        if typeSettings.showHP then
            components.DrawPartySlider(typeSettings, 'Scale X##hp' .. configKey, 'hpScaleX', 0.5, 2.0, '%.1f');
            components.DrawPartySlider(typeSettings, 'Scale Y##hp' .. configKey, 'hpScaleY', 0.5, 2.0, '%.1f');
        end

        imgui.Spacing();

        -- MP Bar
        components.DrawPartyCheckbox(typeSettings, 'Show MP Bar##' .. configKey, 'showMP');
        imgui.ShowHelp('Show pet MP bar.');
        if typeSettings.showMP then
            components.DrawPartySlider(typeSettings, 'Scale X##mp' .. configKey, 'mpScaleX', 0.5, 2.0, '%.1f');
            components.DrawPartySlider(typeSettings, 'Scale Y##mp' .. configKey, 'mpScaleY', 0.5, 2.0, '%.1f');
        end

        imgui.Spacing();

        -- TP Bar
        components.DrawPartyCheckbox(typeSettings, 'Show TP Bar##' .. configKey, 'showTP');
        imgui.ShowHelp('Show pet TP bar.');
        if typeSettings.showTP then
            components.DrawPartySlider(typeSettings, 'Scale X##tp' .. configKey, 'tpScaleX', 0.5, 2.0, '%.1f');
            components.DrawPartySlider(typeSettings, 'Scale Y##tp' .. configKey, 'tpScaleY', 0.5, 2.0, '%.1f');
        end
    end

    if components.CollapsingSection('Font Sizes##' .. configKey) then
        components.DrawPartySlider(typeSettings, 'Pet Name##' .. configKey, 'nameFontSize', 8, 24);
        components.DrawPartySlider(typeSettings, 'Distance##' .. configKey, 'distanceFontSize', 6, 18);
        components.DrawPartySlider(typeSettings, 'HP Text##' .. configKey, 'hpFontSize', 6, 18);
        components.DrawPartySlider(typeSettings, 'MP Text##' .. configKey, 'mpFontSize', 6, 18);
        components.DrawPartySlider(typeSettings, 'TP Text##' .. configKey, 'tpFontSize', 6, 18);
    end

    if components.CollapsingSection('Background##' .. configKey) then
        local bgThemes = {'-None-', 'Plain', 'Window1', 'Window2', 'Window3', 'Window4', 'Window5', 'Window6', 'Window7', 'Window8'};
        local currentTheme = typeSettings.backgroundTheme or 'Window1';
        components.DrawPartyComboBox(typeSettings, 'Theme##bg' .. configKey, 'backgroundTheme', bgThemes, DeferredUpdateVisuals);
        imgui.ShowHelp('Select the background window theme for this pet type.');
        components.DrawPartySlider(typeSettings, 'Background Opacity##' .. configKey, 'backgroundOpacity', 0.0, 1.0, '%.2f');
        imgui.ShowHelp('Opacity of the background.');
        components.DrawPartySlider(typeSettings, 'Border Opacity##' .. configKey, 'borderOpacity', 0.0, 1.0, '%.2f');
        imgui.ShowHelp('Opacity of the window borders (Window themes only).');
    end

    if components.CollapsingSection('Ability Icons##' .. configKey) then
        components.DrawPartyCheckbox(typeSettings, 'Show Ability Timers##' .. configKey, 'showTimers');
        imgui.ShowHelp('Show pet-related ability recast timers (Blood Pact, Ready, Sic, etc.).');

        if typeSettings.showTimers then
            imgui.Spacing();

            -- Position mode
            local positionModes = {'In Container', 'Absolute'};
            local currentMode = typeSettings.iconsAbsolute and 'Absolute' or 'In Container';
            imgui.SetNextItemWidth(150);
            if imgui.BeginCombo('Position Mode##icons' .. configKey, currentMode) then
                for _, mode in ipairs(positionModes) do
                    if imgui.Selectable(mode, mode == currentMode) then
                        typeSettings.iconsAbsolute = (mode == 'Absolute');
                        SaveSettingsOnly();
                    end
                end
                imgui.EndCombo();
            end
            imgui.ShowHelp('In Container: Icons flow within the pet bar.\nAbsolute: Icons positioned independently.');

            components.DrawPartySlider(typeSettings, 'Scale##icons' .. configKey, 'iconsScale', 0.5, 2.0, '%.1f');
            imgui.ShowHelp('Scale of the ability icons.');
            components.DrawPartySlider(typeSettings, 'Offset X##icons' .. configKey, 'iconsOffsetX', -200, 200);
            imgui.ShowHelp('Horizontal offset for ability icons.');
            components.DrawPartySlider(typeSettings, 'Offset Y##icons' .. configKey, 'iconsOffsetY', -200, 200);
            imgui.ShowHelp('Vertical offset for ability icons.');

            -- Avatar (SMN) specific ability toggles
            if configKey == 'petBarAvatar' then
                imgui.Spacing();
                imgui.Separator();
                imgui.Spacing();
                components.DrawCheckbox('Blood Pact: Rage', 'petBarSmnShowBPRage');
                imgui.ShowHelp('Show Blood Pact: Rage ability timer (offensive blood pacts).');
                components.DrawCheckbox('Blood Pact: Ward', 'petBarSmnShowBPWard');
                imgui.ShowHelp('Show Blood Pact: Ward ability timer (defensive/support blood pacts).');
                components.DrawCheckbox('Apogee', 'petBarSmnShowApogee');
                imgui.ShowHelp('Show Apogee ability timer (enhances next blood pact).');
                components.DrawCheckbox('Mana Cede', 'petBarSmnShowManaCede');
                imgui.ShowHelp('Show Mana Cede ability timer (transfer MP to avatar).');
            end
        end
    end

    -- ============================================
    -- Pet-Type-Specific Settings
    -- ============================================

    -- Avatar (SMN) specific settings
    if configKey == 'petBarAvatar' then
        if components.CollapsingSection('Avatar Image##avatar') then
            components.DrawCheckbox('Show Avatar Image', 'petBarShowImage');
            imgui.ShowHelp('Show avatar image overlay on the pet bar.');

            if gConfig.petBarShowImage then
                imgui.Spacing();

                -- Ensure petBarAvatarSettings exists
                if gConfig.petBarAvatarSettings == nil then
                    gConfig.petBarAvatarSettings = T{};
                end

                -- Avatar dropdown
                local avatarList = petData.avatarList;
                -- Sync selectedAvatarIndex with saved preview avatar
                if gConfig.petBarPreviewAvatar then
                    for i, name in ipairs(avatarList) do
                        if name == gConfig.petBarPreviewAvatar then
                            selectedAvatarIndex = i;
                            break;
                        end
                    end
                end
                local currentAvatar = avatarList[selectedAvatarIndex] or 'Carbuncle';

                if imgui.BeginCombo('Avatar##petBarAvatarSelect', currentAvatar) then
                    for i, avatarName in ipairs(avatarList) do
                        local isSelected = (i == selectedAvatarIndex);
                        if imgui.Selectable(avatarName, isSelected) then
                            selectedAvatarIndex = i;
                            -- Update preview avatar name so preview shows this avatar
                            gConfig.petBarPreviewAvatar = avatarName;
                            SaveSettingsOnly();
                        end
                        if isSelected then
                            imgui.SetItemDefaultFocus();
                        end
                    end
                    imgui.EndCombo();
                end
                imgui.ShowHelp('Select an avatar to adjust its image settings. Preview will show this avatar.');

                imgui.Spacing();
                imgui.Separator();
                imgui.Spacing();

                -- Get settings key for current avatar
                local settingsKey = petData.GetPetSettingsKey(currentAvatar);

                -- Ensure this avatar has settings
                if gConfig.petBarAvatarSettings[settingsKey] == nil then
                    gConfig.petBarAvatarSettings[settingsKey] = T{
                        scale = 0.4,
                        opacity = 0.3,
                        offsetX = 0,
                        offsetY = 0,
                        clipToBackground = false,
                    };
                end

                local avatarSettings = gConfig.petBarAvatarSettings[settingsKey];

                -- Scale slider
                local scaleValue = { avatarSettings.scale or 0.4 };
                if imgui.SliderFloat('Scale##petBarAvatarScale', scaleValue, 0.1, 2.0, '%.2f') then
                    avatarSettings.scale = scaleValue[1];
                    SaveSettingsOnly();
                end
                imgui.ShowHelp('Scale of the avatar image overlay.');

                -- Opacity slider
                local opacityValue = { avatarSettings.opacity or 0.3 };
                if imgui.SliderFloat('Opacity##petBarAvatarOpacity', opacityValue, 0.0, 1.0, '%.2f') then
                    avatarSettings.opacity = opacityValue[1];
                    SaveSettingsOnly();
                end
                imgui.ShowHelp('Opacity of the avatar image overlay.');

                -- Offset X slider
                local offsetXValue = { avatarSettings.offsetX or 0 };
                if imgui.SliderInt('Offset X##petBarAvatarOffsetX', offsetXValue, -600, 600) then
                    avatarSettings.offsetX = offsetXValue[1];
                    SaveSettingsOnly();
                end
                imgui.ShowHelp('Horizontal offset for the avatar image.');

                -- Offset Y slider
                local offsetYValue = { avatarSettings.offsetY or 0 };
                if imgui.SliderInt('Offset Y##petBarAvatarOffsetY', offsetYValue, -600, 600) then
                    avatarSettings.offsetY = offsetYValue[1];
                    SaveSettingsOnly();
                end
                imgui.ShowHelp('Vertical offset for the avatar image.');

                -- Clip to Background checkbox
                local clipValue = { avatarSettings.clipToBackground or false };
                if imgui.Checkbox('Clip to Background##petBarAvatarClip', clipValue) then
                    avatarSettings.clipToBackground = clipValue[1];
                    SaveSettingsOnly();
                end
                imgui.ShowHelp('Clip the avatar image to the pet bar background bounds.');
            end
        end
    end

    -- Charm (BST charmed pets) specific settings
    if configKey == 'petBarCharm' then
        if components.CollapsingSection('Ability Icons##charm') then
            components.DrawCheckbox('Ready/Sic', 'petBarBstShowReady');
            imgui.ShowHelp('Show Ready/Sic ability timer (offensive pet command).');
            components.DrawCheckbox('Reward', 'petBarBstShowReward');
            imgui.ShowHelp('Show Reward ability timer (pet healing).');
        end

        if components.CollapsingSection('Charm Indicator##charm') then
            components.DrawCheckbox('Show Charm Indicator', 'petBarShowCharmIndicator');
            imgui.ShowHelp('Show heart icon and elapsed timer for charmed pets.');

            imgui.Spacing();

            -- Icon size
            components.DrawSlider('Icon Size##petBarCharm', 'petBarCharmIconSize', 8, 32);
            imgui.ShowHelp('Size of the heart icon.');

            -- Timer font size
            components.DrawSlider('Timer Font Size##petBarCharm', 'petBarCharmTimerFontSize', 6, 18);
            imgui.ShowHelp('Font size for charm duration timer.');

            imgui.Spacing();
            imgui.Text('Position (relative to window)');

            -- X/Y Offset
            components.DrawSlider('Offset X##petBarCharm', 'petBarCharmOffsetX', -200, 200);
            imgui.ShowHelp('Horizontal offset from window left.');
            components.DrawSlider('Offset Y##petBarCharm', 'petBarCharmOffsetY', -200, 200);
            imgui.ShowHelp('Vertical offset from window top.');
        end
    end

    -- Jug (BST jug pets) specific settings
    if configKey == 'petBarJug' then
        if components.CollapsingSection('Ability Icons##jug') then
            components.DrawCheckbox('Ready/Sic', 'petBarBstShowReady');
            imgui.ShowHelp('Show Ready/Sic ability timer (offensive pet command).');
            components.DrawCheckbox('Reward', 'petBarBstShowReward');
            imgui.ShowHelp('Show Reward ability timer (pet healing).');
            components.DrawCheckbox('Call Beast', 'petBarBstShowCallBeast');
            imgui.ShowHelp('Show Call Beast ability timer (summon jug pet).');
            components.DrawCheckbox('Bestial Loyalty', 'petBarBstShowBestialLoyalty');
            imgui.ShowHelp('Show Bestial Loyalty ability timer (summon jug pet without charm).');
        end

        if components.CollapsingSection('Jug Pet Timer##jug') then
            components.DrawCheckbox('Show Jug Pet Timer', 'petBarShowJugTimer');
            imgui.ShowHelp('Show countdown timer for jug pet duration (time remaining).');
        end
    end

    -- Automaton (PUP) specific settings
    if configKey == 'petBarAutomaton' then
        if components.CollapsingSection('Ability Icons##automaton') then
            components.DrawCheckbox('Activate', 'petBarPupShowActivate');
            imgui.ShowHelp('Show Activate ability timer (summon automaton).');
            components.DrawCheckbox('Repair', 'petBarPupShowRepair');
            imgui.ShowHelp('Show Repair ability timer (heal automaton).');
            components.DrawCheckbox('Deus Ex Automata', 'petBarPupShowDeusExAutomata');
            imgui.ShowHelp('Show Deus Ex Automata ability timer (revive automaton).');
            components.DrawCheckbox('Deploy', 'petBarPupShowDeploy');
            imgui.ShowHelp('Show Deploy ability timer (send automaton to engage).');
            components.DrawCheckbox('Deactivate', 'petBarPupShowDeactivate');
            imgui.ShowHelp('Show Deactivate ability timer (dismiss automaton).');
            components.DrawCheckbox('Retrieve', 'petBarPupShowRetrieve');
            imgui.ShowHelp('Show Retrieve ability timer (call automaton back).');
        end
    end

    -- Wyvern (DRG) specific settings
    if configKey == 'petBarWyvern' then
        if components.CollapsingSection('Ability Icons##wyvern') then
            components.DrawCheckbox('Call Wyvern', 'petBarDrgShowCallWyvern');
            imgui.ShowHelp('Show Call Wyvern ability timer (summon wyvern).');
            components.DrawCheckbox('Spirit Link', 'petBarDrgShowSpiritLink');
            imgui.ShowHelp('Show Spirit Link ability timer (heal wyvern).');
            components.DrawCheckbox('Deep Breathing', 'petBarDrgShowDeepBreathing');
            imgui.ShowHelp('Show Deep Breathing ability timer (enhance wyvern breath).');
            components.DrawCheckbox('Steady Wing', 'petBarDrgShowSteadyWing');
            imgui.ShowHelp('Show Steady Wing ability timer (wyvern stoneskin).');
        end
    end
end

-- Helper: Draw copy buttons for pet type settings
local function DrawPetTypeCopyButtons(currentConfigKey, currentLabel, settingsType)
    if components.CollapsingSection('Copy Settings##' .. currentConfigKey .. settingsType) then
        imgui.TextColored({0.7, 0.7, 0.7, 1.0}, 'Copy ' .. settingsType .. ' from:');
        for _, petType in ipairs(PET_TYPES) do
            if petType.configKey ~= currentConfigKey then
                imgui.SameLine();
                if imgui.Button(petType.label .. '##copy' .. settingsType .. petType.configKey .. 'to' .. currentConfigKey) then
                    if settingsType == 'Settings' then
                        CopyPetTypeSettings(petType.configKey, currentConfigKey);
                    else
                        CopyPetTypeColors(petType.configKey, currentConfigKey);
                    end
                end
            end
        end
    end
end

-- Helper: Draw per-pet-type color settings
local function DrawPetTypeColorSettings(configKey, petTypeLabel)
    local colorConfig = gConfig.colorCustomization and gConfig.colorCustomization[configKey];
    -- Validate colorConfig is a table with expected properties
    if not colorConfig or type(colorConfig) ~= 'table' or colorConfig.hpGradient == nil then
        imgui.TextColored({1.0, 0.5, 0.5, 1.0}, 'Color settings not initialized for ' .. petTypeLabel);
        imgui.Text('Please reload the addon to initialize per-type colors.');
        return;
    end

    if components.CollapsingSection('Bar Colors##' .. configKey .. 'color') then
        -- Column headers
        imgui.Text("HP Bar");
        imgui.SameLine(components.COLOR_COLUMN_SPACING);
        imgui.Text("MP Bar");
        imgui.SameLine(components.COLOR_COLUMN_SPACING * 2);
        imgui.Text("TP Bar");

        -- HP Bar
        if colorConfig.hpGradient then
            components.DrawGradientPickerColumn("HP Bar##" .. configKey, colorConfig.hpGradient, "HP bar color gradient");
        end

        imgui.SameLine(components.COLOR_COLUMN_SPACING);

        -- MP Bar
        if colorConfig.mpGradient then
            components.DrawGradientPickerColumn("MP Bar##" .. configKey, colorConfig.mpGradient, "MP bar color gradient");
        end

        imgui.SameLine(components.COLOR_COLUMN_SPACING * 2);

        -- TP Bar
        if colorConfig.tpGradient then
            components.DrawGradientPickerColumn("TP Bar##" .. configKey, colorConfig.tpGradient, "TP bar color gradient");
        end
    end

    if components.CollapsingSection('Text Colors##' .. configKey .. 'color') then
        components.DrawTextColorPicker("Pet Name##" .. configKey, colorConfig, 'nameTextColor', "Color of pet name text");
        components.DrawTextColorPicker("Distance##" .. configKey, colorConfig, 'distanceTextColor', "Color of distance text");
        components.DrawTextColorPicker("HP Text##" .. configKey, colorConfig, 'hpTextColor', "Color of HP value text");
        components.DrawTextColorPicker("MP Text##" .. configKey, colorConfig, 'mpTextColor', "Color of MP value text");
        components.DrawTextColorPicker("TP Text##" .. configKey, colorConfig, 'tpTextColor', "Color of TP value text");
    end

    -- ============================================
    -- Pet-Type-Specific Color Settings
    -- ============================================

    -- Avatar (SMN) specific color settings
    if configKey == 'petBarAvatar' then
        if components.CollapsingSection('Ability Timer Colors##' .. configKey .. 'color') then
            -- Ensure timer colors exist
            if colorConfig.timerBPRageReadyColor == nil then colorConfig.timerBPRageReadyColor = 0xE6FF3333; end
            if colorConfig.timerBPRageRecastColor == nil then colorConfig.timerBPRageRecastColor = 0xD9FF6666; end
            if colorConfig.timerBPWardReadyColor == nil then colorConfig.timerBPWardReadyColor = 0xE600CCCC; end
            if colorConfig.timerBPWardRecastColor == nil then colorConfig.timerBPWardRecastColor = 0xD966DDDD; end
            if colorConfig.timer2hReadyColor == nil then colorConfig.timer2hReadyColor = 0xE6FF00FF; end
            if colorConfig.timer2hRecastColor == nil then colorConfig.timer2hRecastColor = 0xD9FF66FF; end

            imgui.Text('Blood Pact: Rage');
            components.DrawTextColorPicker("Ready##rage" .. configKey, colorConfig, 'timerBPRageReadyColor', "Color when ability is ready");
            components.DrawTextColorPicker("Recast##rage" .. configKey, colorConfig, 'timerBPRageRecastColor', "Color when on cooldown");

            imgui.Spacing();
            imgui.Text('Blood Pact: Ward');
            components.DrawTextColorPicker("Ready##ward" .. configKey, colorConfig, 'timerBPWardReadyColor', "Color when ability is ready");
            components.DrawTextColorPicker("Recast##ward" .. configKey, colorConfig, 'timerBPWardRecastColor', "Color when on cooldown");

            imgui.Spacing();
            imgui.Text('Two-Hour (Astral Flow)');
            components.DrawTextColorPicker("Ready##2h" .. configKey, colorConfig, 'timer2hReadyColor', "Color when ability is ready");
            components.DrawTextColorPicker("Recast##2h" .. configKey, colorConfig, 'timer2hRecastColor', "Color when on cooldown");
        end
    end

    -- Charm (BST charmed pets) specific color settings
    if configKey == 'petBarCharm' then
        if components.CollapsingSection('Charm Indicator Colors##' .. configKey .. 'color') then
            if colorConfig.charmHeartColor == nil then colorConfig.charmHeartColor = 0xFFFF6699; end
            if colorConfig.charmTimerColor == nil then colorConfig.charmTimerColor = 0xFFFFFFFF; end
            if colorConfig.durationWarningColor == nil then colorConfig.durationWarningColor = 0xFFFF6600; end

            components.DrawTextColorPicker("Charm Heart##" .. configKey, colorConfig, 'charmHeartColor', "Color of heart icon for charmed pets");
            components.DrawTextColorPicker("Timer Text##" .. configKey, colorConfig, 'charmTimerColor', "Color of pet timer text");
            components.DrawTextColorPicker("Duration Warning##" .. configKey, colorConfig, 'durationWarningColor', "Color when charm is about to break");
        end

        if components.CollapsingSection('Ability Timer Colors##' .. configKey .. 'color') then
            if colorConfig.timer2hReadyColor == nil then colorConfig.timer2hReadyColor = 0xE6FF00FF; end
            if colorConfig.timer2hRecastColor == nil then colorConfig.timer2hRecastColor = 0xD9FF66FF; end

            imgui.Text('Two-Hour (Familiar)');
            components.DrawTextColorPicker("Ready##2h" .. configKey, colorConfig, 'timer2hReadyColor', "Color when ability is ready");
            components.DrawTextColorPicker("Recast##2h" .. configKey, colorConfig, 'timer2hRecastColor', "Color when on cooldown");
        end
    end

    -- Jug (BST jug pets) specific color settings
    if configKey == 'petBarJug' then
        if components.CollapsingSection('Jug Pet Indicator Colors##' .. configKey .. 'color') then
            if colorConfig.jugIconColor == nil then colorConfig.jugIconColor = 0xFFFFFFFF; end
            if colorConfig.charmTimerColor == nil then colorConfig.charmTimerColor = 0xFFFFFFFF; end
            if colorConfig.durationWarningColor == nil then colorConfig.durationWarningColor = 0xFFFF6600; end

            components.DrawTextColorPicker("Jug Icon##" .. configKey, colorConfig, 'jugIconColor', "Color of jug icon");
            components.DrawTextColorPicker("Timer Text##" .. configKey, colorConfig, 'charmTimerColor', "Color of pet timer text");
            components.DrawTextColorPicker("Duration Warning##" .. configKey, colorConfig, 'durationWarningColor', "Color when jug pet duration is low");
        end

        if components.CollapsingSection('Ability Timer Colors##' .. configKey .. 'color') then
            if colorConfig.timer2hReadyColor == nil then colorConfig.timer2hReadyColor = 0xE6FF00FF; end
            if colorConfig.timer2hRecastColor == nil then colorConfig.timer2hRecastColor = 0xD9FF66FF; end

            imgui.Text('Two-Hour (Familiar)');
            components.DrawTextColorPicker("Ready##2h" .. configKey, colorConfig, 'timer2hReadyColor', "Color when ability is ready");
            components.DrawTextColorPicker("Recast##2h" .. configKey, colorConfig, 'timer2hRecastColor', "Color when on cooldown");
        end
    end

    -- Automaton (PUP) specific color settings
    if configKey == 'petBarAutomaton' then
        if components.CollapsingSection('Ability Timer Colors##' .. configKey .. 'color') then
            if colorConfig.timer2hReadyColor == nil then colorConfig.timer2hReadyColor = 0xE6FF00FF; end
            if colorConfig.timer2hRecastColor == nil then colorConfig.timer2hRecastColor = 0xD9FF66FF; end

            imgui.Text('Two-Hour (Overdrive)');
            components.DrawTextColorPicker("Ready##2h" .. configKey, colorConfig, 'timer2hReadyColor', "Color when ability is ready");
            components.DrawTextColorPicker("Recast##2h" .. configKey, colorConfig, 'timer2hRecastColor', "Color when on cooldown");
        end
    end

    -- Wyvern (DRG) specific color settings
    if configKey == 'petBarWyvern' then
        if components.CollapsingSection('Ability Timer Colors##' .. configKey .. 'color') then
            if colorConfig.timer2hReadyColor == nil then colorConfig.timer2hReadyColor = 0xE6FF00FF; end
            if colorConfig.timer2hRecastColor == nil then colorConfig.timer2hRecastColor = 0xD9FF66FF; end

            imgui.Text('Two-Hour (Spirit Surge)');
            components.DrawTextColorPicker("Ready##2h" .. configKey, colorConfig, 'timer2hReadyColor', "Color when ability is ready");
            components.DrawTextColorPicker("Recast##2h" .. configKey, colorConfig, 'timer2hRecastColor', "Color when on cooldown");
        end
    end

    if components.CollapsingSection('Background Colors##' .. configKey .. 'color') then
        if colorConfig.bgColor == nil then colorConfig.bgColor = 0xFFFFFFFF; end
        if colorConfig.borderColor == nil then colorConfig.borderColor = 0xFFFFFFFF; end

        components.DrawTextColorPicker("Background Tint##" .. configKey, colorConfig, 'bgColor', "Tint color for background");
        components.DrawTextColorPicker("Border Color##" .. configKey, colorConfig, 'borderColor', "Color of window borders");
    end
end

-- Helper: Draw Pet Bar specific settings (used in tab)
local function DrawPetBarSettingsContent()
    components.DrawCheckbox('Enabled', 'showPetBar', CheckVisibility);
    components.DrawCheckbox('Hide During Events', 'petBarHideDuringEvents');
    components.DrawCheckbox('Preview Mode', 'petBarPreview');
    imgui.ShowHelp('Show the pet bar with mock data. Preview shows the pet type from the selected tab below.');
end

-- Helper: Draw Pet Target specific settings (used in tab)
local function DrawPetTargetSettingsContent()
    components.DrawCheckbox('Show Pet Target', 'petBarShowTarget');
    imgui.ShowHelp('Show information about what the pet is targeting in a separate window.');

    if components.CollapsingSection('Display Options##petTarget') then
        components.DrawSlider('Font Size', 'petBarTargetFontSize', 6, 24);
        imgui.ShowHelp('Font size for pet target text.');

        imgui.Spacing();

        -- Target Name positioning
        imgui.Text('Target Name');
        imgui.SameLine();
        imgui.SetNextItemWidth(120);
        local namePositionModes = {'Inline', 'Absolute'};
        local nameCurrentMode = gConfig.petTargetNameAbsolute and 'Absolute' or 'Inline';
        components.DrawComboBox('Position Mode##petTargetName', nameCurrentMode, namePositionModes, function(newValue)
            local wasAbsolute = gConfig.petTargetNameAbsolute;
            gConfig.petTargetNameAbsolute = (newValue == 'Absolute');
            -- Reset offsets when switching modes
            if wasAbsolute ~= gConfig.petTargetNameAbsolute and not gConfig.petTargetNameAbsolute then
                gConfig.petTargetNameOffsetX = 0;
                gConfig.petTargetNameOffsetY = 0;
            end
            SaveSettingsOnly();
        end);
        imgui.ShowHelp('Inline: Name flows within layout.\nAbsolute: Name positioned relative to window top-left.');

        if gConfig.petTargetNameAbsolute then
            components.DrawSlider('Offset X##petTargetName', 'petTargetNameOffsetX', -200, 200);
            imgui.ShowHelp('Horizontal offset from window left.');
            components.DrawSlider('Offset Y##petTargetName', 'petTargetNameOffsetY', -200, 200);
            imgui.ShowHelp('Vertical offset from window top.');
        end

        imgui.Spacing();

        -- HP% positioning
        imgui.Text('HP%');
        imgui.SameLine();
        imgui.SetNextItemWidth(120);
        local hpPositionModes = {'Inline', 'Absolute'};
        local hpCurrentMode = gConfig.petTargetHpAbsolute and 'Absolute' or 'Inline';
        components.DrawComboBox('Position Mode##petTargetHp', hpCurrentMode, hpPositionModes, function(newValue)
            local wasAbsolute = gConfig.petTargetHpAbsolute;
            gConfig.petTargetHpAbsolute = (newValue == 'Absolute');
            -- Reset offsets when switching modes
            if wasAbsolute ~= gConfig.petTargetHpAbsolute and not gConfig.petTargetHpAbsolute then
                gConfig.petTargetHpOffsetX = 0;
                gConfig.petTargetHpOffsetY = 0;
            end
            SaveSettingsOnly();
        end);
        imgui.ShowHelp('Inline: HP% right-aligned on name row.\nAbsolute: HP% positioned relative to window top-left.');

        if gConfig.petTargetHpAbsolute then
            components.DrawSlider('Offset X##petTargetHp', 'petTargetHpOffsetX', -200, 200);
            imgui.ShowHelp('Horizontal offset from window left.');
            components.DrawSlider('Offset Y##petTargetHp', 'petTargetHpOffsetY', -200, 200);
            imgui.ShowHelp('Vertical offset from window top.');
        end

        imgui.Spacing();

        -- Distance positioning
        imgui.Text('Distance');
        imgui.SameLine();
        imgui.SetNextItemWidth(120);
        local distPositionModes = {'Inline', 'Absolute'};
        local distCurrentMode = gConfig.petTargetDistanceAbsolute and 'Absolute' or 'Inline';
        components.DrawComboBox('Position Mode##petTargetDistance', distCurrentMode, distPositionModes, function(newValue)
            local wasAbsolute = gConfig.petTargetDistanceAbsolute;
            gConfig.petTargetDistanceAbsolute = (newValue == 'Absolute');
            -- Reset offsets when switching modes
            if wasAbsolute ~= gConfig.petTargetDistanceAbsolute and not gConfig.petTargetDistanceAbsolute then
                gConfig.petTargetDistanceOffsetX = 0;
                gConfig.petTargetDistanceOffsetY = 0;
            end
            SaveSettingsOnly();
        end);
        imgui.ShowHelp('Inline: Distance below HP bar.\nAbsolute: Distance positioned relative to window top-left.');

        if gConfig.petTargetDistanceAbsolute then
            components.DrawSlider('Offset X##petTargetDistance', 'petTargetDistanceOffsetX', -200, 200);
            imgui.ShowHelp('Horizontal offset from window left.');
            components.DrawSlider('Offset Y##petTargetDistance', 'petTargetDistanceOffsetY', -200, 200);
            imgui.ShowHelp('Vertical offset from window top.');
        end
    end

    if components.CollapsingSection('Background##petTarget') then
        local bgThemes = {'-None-', 'Plain', 'Window1', 'Window2', 'Window3', 'Window4', 'Window5', 'Window6', 'Window7', 'Window8'};
        local currentTheme = gConfig.petTargetBackgroundTheme or gConfig.petBarBackgroundTheme or 'Window1';
        components.DrawComboBox('Theme##petTargetBg', currentTheme, bgThemes, function(newValue)
            gConfig.petTargetBackgroundTheme = newValue;
            DeferredUpdateVisuals();
        end);
        imgui.ShowHelp('Select the background window theme for pet target. Uses Pet Bar theme by default.');
        components.DrawSlider('Background Opacity##petTargetBg', 'petTargetBackgroundOpacity', 0.0, 1.0, '%.2f');
        imgui.ShowHelp('Opacity of the background. Uses Pet Bar opacity by default.');
        components.DrawSlider('Border Opacity##petTargetBg', 'petTargetBorderOpacity', 0.0, 1.0, '%.2f');
        imgui.ShowHelp('Opacity of the window borders. Uses Pet Bar border opacity by default.');
    end
end

-- Section: Pet Bar Settings (with tabs for Pet Bar / Pet Target)
-- state.selectedPetBarTab: tab selection state
-- state.selectedPetTypeTab: pet type sub-tab selection (1=Avatar, 2=Charm, etc.)
function M.DrawSettings(state)
    local selectedPetBarTab = state.selectedPetBarTab or 1;
    local selectedPetTypeTab = state.selectedPetTypeTab or 1;

    -- Sync preview type with selected pet type tab
    local currentPetType = PET_TYPES[selectedPetTypeTab];
    if currentPetType and gConfig.petBarPreviewType ~= currentPetType.previewType then
        gConfig.petBarPreviewType = currentPetType.previewType;
    end

    -- Tab styling colors
    local tabHeight = 24;
    local tabPadding = 12;
    local gold = {0.957, 0.855, 0.592, 1.0};
    local bgMedium = {0.098, 0.090, 0.075, 1.0};
    local bgLight = {0.137, 0.125, 0.106, 1.0};
    local bgLighter = {0.176, 0.161, 0.137, 1.0};

    -- Calculate tab widths based on text size
    local petBarTextWidth = imgui.CalcTextSize('Pet Bar');
    local petTargetTextWidth = imgui.CalcTextSize('Pet Target');
    local petBarTabWidth = petBarTextWidth + tabPadding * 2;
    local petTargetTabWidth = petTargetTextWidth + tabPadding * 2;

    -- Pet Bar tab button
    local petBarPosX, petBarPosY = imgui.GetCursorScreenPos();
    if selectedPetBarTab == 1 then
        imgui.PushStyleColor(ImGuiCol_Button, {0, 0, 0, 0});
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, {0, 0, 0, 0});
        imgui.PushStyleColor(ImGuiCol_ButtonActive, {0, 0, 0, 0});
    else
        imgui.PushStyleColor(ImGuiCol_Button, bgMedium);
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, bgLight);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, bgLighter);
    end
    if imgui.Button('Pet Bar##petBarTab', { petBarTabWidth, tabHeight }) then
        selectedPetBarTab = 1;
    end
    if selectedPetBarTab == 1 then
        local draw_list = imgui.GetWindowDrawList();
        draw_list:AddRectFilled(
            {petBarPosX + 4, petBarPosY + tabHeight - 2},
            {petBarPosX + petBarTabWidth - 4, petBarPosY + tabHeight},
            imgui.GetColorU32(gold),
            1.0
        );
    end
    imgui.PopStyleColor(3);

    -- Pet Target tab button
    imgui.SameLine();
    local petTargetPosX, petTargetPosY = imgui.GetCursorScreenPos();
    if selectedPetBarTab == 2 then
        imgui.PushStyleColor(ImGuiCol_Button, {0, 0, 0, 0});
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, {0, 0, 0, 0});
        imgui.PushStyleColor(ImGuiCol_ButtonActive, {0, 0, 0, 0});
    else
        imgui.PushStyleColor(ImGuiCol_Button, bgMedium);
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, bgLight);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, bgLighter);
    end
    if imgui.Button('Pet Target##petBarTab', { petTargetTabWidth, tabHeight }) then
        selectedPetBarTab = 2;
    end
    if selectedPetBarTab == 2 then
        local draw_list = imgui.GetWindowDrawList();
        draw_list:AddRectFilled(
            {petTargetPosX + 4, petTargetPosY + tabHeight - 2},
            {petTargetPosX + petTargetTabWidth - 4, petTargetPosY + tabHeight},
            imgui.GetColorU32(gold),
            1.0
        );
    end
    imgui.PopStyleColor(3);

    imgui.Spacing();
    imgui.Separator();
    imgui.Spacing();

    -- Draw settings based on selected tab
    if selectedPetBarTab == 1 then
        -- Draw global pet bar settings first
        DrawPetBarSettingsContent();

        imgui.Spacing();
        imgui.Separator();
        imgui.Spacing();

        -- Pet Type Sub-Tabs
        imgui.TextColored({0.957, 0.855, 0.592, 1.0}, 'Per-Pet-Type Visual Settings');
        imgui.ShowHelp('Customize the appearance for each pet type independently.');
        imgui.Spacing();

        -- Draw pet type sub-tabs
        local smallTabHeight = 20;
        local smallTabPadding = 8;
        for i, petType in ipairs(PET_TYPES) do
            local tabTextWidth = imgui.CalcTextSize(petType.label);
            local tabWidth = tabTextWidth + smallTabPadding * 2;
            local tabPosX, tabPosY = imgui.GetCursorScreenPos();

            if selectedPetTypeTab == i then
                imgui.PushStyleColor(ImGuiCol_Button, {0, 0, 0, 0});
                imgui.PushStyleColor(ImGuiCol_ButtonHovered, {0, 0, 0, 0});
                imgui.PushStyleColor(ImGuiCol_ButtonActive, {0, 0, 0, 0});
            else
                imgui.PushStyleColor(ImGuiCol_Button, bgMedium);
                imgui.PushStyleColor(ImGuiCol_ButtonHovered, bgLight);
                imgui.PushStyleColor(ImGuiCol_ButtonActive, bgLighter);
            end

            if imgui.Button(petType.label .. '##petTypeTab', { tabWidth, smallTabHeight }) then
                selectedPetTypeTab = i;
                -- Update preview type to match selected tab
                gConfig.petBarPreviewType = petType.previewType;
            end

            if selectedPetTypeTab == i then
                local draw_list = imgui.GetWindowDrawList();
                draw_list:AddRectFilled(
                    {tabPosX + 2, tabPosY + smallTabHeight - 2},
                    {tabPosX + tabWidth - 2, tabPosY + smallTabHeight},
                    imgui.GetColorU32(gold),
                    1.0
                );
            end
            imgui.PopStyleColor(3);

            if i < #PET_TYPES then
                imgui.SameLine();
            end
        end

        imgui.Spacing();
        imgui.Separator();
        imgui.Spacing();

        -- Draw per-type settings for selected pet type
        local currentPetType = PET_TYPES[selectedPetTypeTab];
        if currentPetType then
            -- Copy buttons
            DrawPetTypeCopyButtons(currentPetType.configKey, currentPetType.label, 'Settings');

            -- Per-type visual settings
            DrawPetTypeVisualSettings(currentPetType.configKey, currentPetType.label);
        end
    else
        DrawPetTargetSettingsContent();
    end

    -- Return updated state
    return { selectedPetBarTab = selectedPetBarTab, selectedPetTypeTab = selectedPetTypeTab };
end

-- Helper: Draw Pet Bar specific color settings (used in tab)
local function DrawPetBarColorSettingsContent()
    -- Ensure petBar color config exists
    if gConfig.colorCustomization.petBar == nil then
        gConfig.colorCustomization.petBar = T{
            hpGradient = T{ enabled = true, start = '#e26c6c', stop = '#fa9c9c' },
            mpGradient = T{ enabled = true, start = '#9abb5a', stop = '#bfe07d' },
            tpGradient = T{ enabled = true, start = '#3898ce', stop = '#78c4ee' },
            nameTextColor = 0xFFFFFFFF,
            distanceTextColor = 0xFFFFFFFF,
            hpTextColor = 0xFFFFA7A7,
            mpTextColor = 0xFFD4FF97,
            tpTextColor = 0xFF8DC7FF,
            targetTextColor = 0xFFFFFFFF,
            -- Rage timer colors (offensive abilities)
            timerRageReadyColor = 0xE6FF6600,
            timerRageRecastColor = 0xD9FF9933,
            -- Ward timer colors (defensive abilities)
            timerWardReadyColor = 0xE600CCFF,
            timerWardRecastColor = 0xD966E0FF,
            -- 2-Hour timer colors
            timer2hReadyColor = 0xE6FF00FF,
            timer2hRecastColor = 0xD9FF66FF,
            -- Other timer colors (utility - legacy)
            timerReadyColor = 0xE600FF00,
            timerRecastColor = 0xD9FFFF00,
            bgColor = 0xFFFFFFFF,
            borderColor = 0xFFFFFFFF,
        };
    end
    -- Ensure borderColor exists (for existing configs)
    if gConfig.colorCustomization.petBar.borderColor == nil then
        gConfig.colorCustomization.petBar.borderColor = 0xFFFFFFFF;
    end

    if components.CollapsingSection('Bar Colors##petBarColor') then
        -- Column headers
        imgui.Text("HP Bar");
        imgui.SameLine(components.COLOR_COLUMN_SPACING);
        imgui.Text("MP Bar");
        imgui.SameLine(components.COLOR_COLUMN_SPACING * 2);
        imgui.Text("TP Bar");

        -- HP Bar
        components.DrawGradientPickerColumn("HP Bar##petBar", gConfig.colorCustomization.petBar.hpGradient, "Pet HP bar color gradient");

        imgui.SameLine(components.COLOR_COLUMN_SPACING);

        -- MP Bar
        components.DrawGradientPickerColumn("MP Bar##petBar", gConfig.colorCustomization.petBar.mpGradient, "Pet MP bar color gradient");

        imgui.SameLine(components.COLOR_COLUMN_SPACING * 2);

        -- TP Bar
        components.DrawGradientPickerColumn("TP Bar##petBar", gConfig.colorCustomization.petBar.tpGradient, "Pet TP bar color gradient");
    end

    if components.CollapsingSection('Text Colors##petBarColor') then
        components.DrawTextColorPicker("Pet Name", gConfig.colorCustomization.petBar, 'nameTextColor', "Color of pet name text");
        components.DrawTextColorPicker("Distance", gConfig.colorCustomization.petBar, 'distanceTextColor', "Color of distance text");
        components.DrawTextColorPicker("HP Text", gConfig.colorCustomization.petBar, 'hpTextColor', "Color of HP value text");
        components.DrawTextColorPicker("MP Text", gConfig.colorCustomization.petBar, 'mpTextColor', "Color of MP value text");
        components.DrawTextColorPicker("TP Text", gConfig.colorCustomization.petBar, 'tpTextColor', "Color of TP value text");
    end

    if components.CollapsingSection('Background Colors##petBarColor') then
        components.DrawTextColorPicker("Background Tint", gConfig.colorCustomization.petBar, 'bgColor', "Tint color for background");
        components.DrawTextColorPicker("Border Color", gConfig.colorCustomization.petBar, 'borderColor', "Color of window borders (Window themes only)");
    end
end

-- Helper: Draw Pet Target specific color settings (used in tab)
local function DrawPetTargetColorSettingsContent()
    -- Ensure petTarget color config exists
    if gConfig.colorCustomization.petTarget == nil then
        gConfig.colorCustomization.petTarget = T{
            hpGradient = T{ enabled = true, start = '#e26c6c', stop = '#fb9494' },
            bgColor = 0xFFFF8D8D,
            targetTextColor = 0xFFFFFFFF,
            hpTextColor = 0xFFFFA7A7,
            distanceTextColor = 0xFFFFFFFF,
            borderColor = 0xFFFF8D8D,
        };
    end
    -- Ensure borderColor exists (for existing configs)
    if gConfig.colorCustomization.petTarget.borderColor == nil then
        gConfig.colorCustomization.petTarget.borderColor = 0xFFFF8D8D;
    end
    -- Ensure hpGradient exists (for existing configs)
    if gConfig.colorCustomization.petTarget.hpGradient == nil then
        gConfig.colorCustomization.petTarget.hpGradient = T{ enabled = true, start = '#e26c6c', stop = '#fb9494' };
    end
    -- Ensure hpTextColor exists (for existing configs)
    if gConfig.colorCustomization.petTarget.hpTextColor == nil then
        gConfig.colorCustomization.petTarget.hpTextColor = 0xFFFFA7A7;
    end
    -- Ensure distanceTextColor exists (for existing configs)
    if gConfig.colorCustomization.petTarget.distanceTextColor == nil then
        gConfig.colorCustomization.petTarget.distanceTextColor = 0xFFFFFFFF;
    end

    if components.CollapsingSection('Bar Colors##petTargetColor') then
        components.DrawGradientPickerColumn("HP Bar##petTarget", gConfig.colorCustomization.petTarget.hpGradient, "Pet target HP bar color gradient");
    end

    if components.CollapsingSection('Text Colors##petTargetColor') then
        components.DrawTextColorPicker("Target Name", gConfig.colorCustomization.petTarget, 'targetTextColor', "Color of pet target name text");
        components.DrawTextColorPicker("HP%", gConfig.colorCustomization.petTarget, 'hpTextColor', "Color of HP percent text");
        components.DrawTextColorPicker("Distance", gConfig.colorCustomization.petTarget, 'distanceTextColor', "Color of distance text");
    end

    if components.CollapsingSection('Background Colors##petTargetColor') then
        components.DrawTextColorPicker("Background Tint", gConfig.colorCustomization.petTarget, 'bgColor', "Tint color for background");
        components.DrawTextColorPicker("Border Color", gConfig.colorCustomization.petTarget, 'borderColor', "Color of window borders (Window themes only)");
    end
end

-- Section: Pet Bar Color Settings (with tabs for Pet Bar / Pet Target)
-- state.selectedPetBarColorTab: tab selection state
-- state.selectedPetTypeColorTab: pet type sub-tab selection for colors
function M.DrawColorSettings(state)
    local selectedPetBarColorTab = state.selectedPetBarColorTab or 1;
    local selectedPetTypeColorTab = state.selectedPetTypeColorTab or 1;

    -- Sync preview type with selected pet type color tab
    local currentPetType = PET_TYPES[selectedPetTypeColorTab];
    if currentPetType and gConfig.petBarPreviewType ~= currentPetType.previewType then
        gConfig.petBarPreviewType = currentPetType.previewType;
    end

    -- Tab styling colors
    local tabHeight = 24;
    local tabPadding = 12;
    local gold = {0.957, 0.855, 0.592, 1.0};
    local bgMedium = {0.098, 0.090, 0.075, 1.0};
    local bgLight = {0.137, 0.125, 0.106, 1.0};
    local bgLighter = {0.176, 0.161, 0.137, 1.0};

    -- Calculate tab widths based on text size
    local petBarTextWidth = imgui.CalcTextSize('Pet Bar');
    local petTargetTextWidth = imgui.CalcTextSize('Pet Target');
    local petBarTabWidth = petBarTextWidth + tabPadding * 2;
    local petTargetTabWidth = petTargetTextWidth + tabPadding * 2;

    -- Pet Bar tab button
    local petBarPosX, petBarPosY = imgui.GetCursorScreenPos();
    if selectedPetBarColorTab == 1 then
        imgui.PushStyleColor(ImGuiCol_Button, {0, 0, 0, 0});
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, {0, 0, 0, 0});
        imgui.PushStyleColor(ImGuiCol_ButtonActive, {0, 0, 0, 0});
    else
        imgui.PushStyleColor(ImGuiCol_Button, bgMedium);
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, bgLight);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, bgLighter);
    end
    if imgui.Button('Pet Bar##petBarColorTab', { petBarTabWidth, tabHeight }) then
        selectedPetBarColorTab = 1;
    end
    if selectedPetBarColorTab == 1 then
        local draw_list = imgui.GetWindowDrawList();
        draw_list:AddRectFilled(
            {petBarPosX + 4, petBarPosY + tabHeight - 2},
            {petBarPosX + petBarTabWidth - 4, petBarPosY + tabHeight},
            imgui.GetColorU32(gold),
            1.0
        );
    end
    imgui.PopStyleColor(3);

    -- Pet Target tab button
    imgui.SameLine();
    local petTargetPosX, petTargetPosY = imgui.GetCursorScreenPos();
    if selectedPetBarColorTab == 2 then
        imgui.PushStyleColor(ImGuiCol_Button, {0, 0, 0, 0});
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, {0, 0, 0, 0});
        imgui.PushStyleColor(ImGuiCol_ButtonActive, {0, 0, 0, 0});
    else
        imgui.PushStyleColor(ImGuiCol_Button, bgMedium);
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, bgLight);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, bgLighter);
    end
    if imgui.Button('Pet Target##petBarColorTab', { petTargetTabWidth, tabHeight }) then
        selectedPetBarColorTab = 2;
    end
    if selectedPetBarColorTab == 2 then
        local draw_list = imgui.GetWindowDrawList();
        draw_list:AddRectFilled(
            {petTargetPosX + 4, petTargetPosY + tabHeight - 2},
            {petTargetPosX + petTargetTabWidth - 4, petTargetPosY + tabHeight},
            imgui.GetColorU32(gold),
            1.0
        );
    end
    imgui.PopStyleColor(3);

    imgui.Spacing();
    imgui.Separator();
    imgui.Spacing();

    -- Draw color settings based on selected tab
    if selectedPetBarColorTab == 1 then
        -- Draw pet type sub-tabs
        local smallTabHeight = 20;
        local smallTabPadding = 8;
        for i, petType in ipairs(PET_TYPES) do
            local tabTextWidth = imgui.CalcTextSize(petType.label);
            local tabWidth = tabTextWidth + smallTabPadding * 2;
            local tabPosX, tabPosY = imgui.GetCursorScreenPos();

            if selectedPetTypeColorTab == i then
                imgui.PushStyleColor(ImGuiCol_Button, {0, 0, 0, 0});
                imgui.PushStyleColor(ImGuiCol_ButtonHovered, {0, 0, 0, 0});
                imgui.PushStyleColor(ImGuiCol_ButtonActive, {0, 0, 0, 0});
            else
                imgui.PushStyleColor(ImGuiCol_Button, bgMedium);
                imgui.PushStyleColor(ImGuiCol_ButtonHovered, bgLight);
                imgui.PushStyleColor(ImGuiCol_ButtonActive, bgLighter);
            end

            if imgui.Button(petType.label .. '##petTypeColorTab', { tabWidth, smallTabHeight }) then
                selectedPetTypeColorTab = i;
                -- Update preview type to match selected tab
                gConfig.petBarPreviewType = petType.previewType;
            end

            if selectedPetTypeColorTab == i then
                local draw_list = imgui.GetWindowDrawList();
                draw_list:AddRectFilled(
                    {tabPosX + 2, tabPosY + smallTabHeight - 2},
                    {tabPosX + tabWidth - 2, tabPosY + smallTabHeight},
                    imgui.GetColorU32(gold),
                    1.0
                );
            end
            imgui.PopStyleColor(3);

            if i < #PET_TYPES then
                imgui.SameLine();
            end
        end

        imgui.Spacing();
        imgui.Separator();
        imgui.Spacing();

        -- Draw per-type color settings for selected pet type
        local currentPetType = PET_TYPES[selectedPetTypeColorTab];
        if currentPetType then
            -- Copy buttons
            DrawPetTypeCopyButtons(currentPetType.configKey, currentPetType.label, 'Colors');

            -- Per-type color settings
            DrawPetTypeColorSettings(currentPetType.configKey, currentPetType.label);
        end
    else
        DrawPetTargetColorSettingsContent();
    end

    -- Return updated state
    return { selectedPetBarColorTab = selectedPetBarColorTab, selectedPetTypeColorTab = selectedPetTypeColorTab };
end

return M;
