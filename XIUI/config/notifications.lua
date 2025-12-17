--[[
* XIUI Config Menu - Notifications Settings
* Contains settings and color settings for Notifications
]]--

require('common');
require('handlers.helpers');
local components = require('config.components');
local imgui = require('imgui');
local notificationData = require('modules.notifications.data');

local M = {};

-- Test notification data for each type
-- Item IDs from FFXI resources (loaded via GetItemById)
local testData = {
    [notificationData.NOTIFICATION_TYPE.PARTY_INVITE] = {
        playerName = 'TestPlayer',
    },
    [notificationData.NOTIFICATION_TYPE.TRADE_INVITE] = {
        playerName = 'TestPlayer',
    },
    [notificationData.NOTIFICATION_TYPE.TREASURE_POOL] = {
        itemId = 13014,  -- Leaping Boots
        itemName = 'Leaping Boots',
        quantity = 1,
    },
    [notificationData.NOTIFICATION_TYPE.ITEM_OBTAINED] = {
        itemId = 4116,   -- Hi-Potion
        itemName = 'Hi-Potion',
        quantity = 3,
    },
    [notificationData.NOTIFICATION_TYPE.KEY_ITEM_OBTAINED] = {
        itemId = 1,
        itemName = 'Adventurer Certificate',
    },
    [notificationData.NOTIFICATION_TYPE.GIL_OBTAINED] = {
        amount = 12500,
    },
};

-- Trigger a test notification
local function triggerTestNotification(notifType)
    notificationData.Add(notifType, testData[notifType] or {});
end

-- Add a test item to treasure pool
local function addTestTreasurePoolItem()
    local slot = 0;
    -- Find first empty slot
    for i = 0, 9 do
        if not notificationData.treasurePool[i] then
            slot = i;
            break;
        end
    end

    -- Add test item (Leaping Boots)
    notificationData.AddTreasurePoolItem(slot, 13014, 0, 1, 0);
end

-- Draw a checkbox with a test button on the same line
local function DrawCheckboxWithTest(label, configKey, notifType)
    components.DrawCheckbox(label, configKey);
    imgui.SameLine();
    if imgui.SmallButton('Test##' .. configKey) then
        triggerTestNotification(notifType);
    end
end

-- Section: Notifications Settings
function M.DrawSettings()
    components.DrawCheckbox('Enabled', 'showNotifications', CheckVisibility);
    components.DrawCheckbox('Hide During Events', 'notificationsHideDuringEvents');

    if components.CollapsingSection('Display Options##notifications') then
        -- Direction dropdown
        local directions = {'Down', 'Up'};
        local directionValues = {'down', 'up'};
        local currentDirIndex = gConfig.notificationsDirection == 'up' and 2 or 1;
        if imgui.BeginCombo('Stack Direction', directions[currentDirIndex]) then
            for i, label in ipairs(directions) do
                if imgui.Selectable(label, i == currentDirIndex) then
                    gConfig.notificationsDirection = directionValues[i];
                    SaveSettingsOnly();
                end
            end
            imgui.EndCombo();
        end
        imgui.ShowHelp('Direction notifications stack');

        components.DrawSlider('Scale X', 'notificationsScaleX', 0.5, 2.0, '%.1f');
        components.DrawSlider('Scale Y', 'notificationsScaleY', 0.5, 2.0, '%.1f');
        components.DrawSlider('Progress Bar Scale Y', 'notificationsProgressBarScaleY', 0.5, 3.0, '%.1f');
        imgui.ShowHelp('Height scale for the countdown progress bar');
        components.DrawSlider('Padding', 'notificationsPadding', 2, 16, '%.0f px');
        components.DrawSlider('Spacing', 'notificationsSpacing', 0, 24, '%.0f px');
        imgui.ShowHelp('Space between notifications in the list');
        components.DrawSlider('Max Visible', 'notificationsMaxVisible', 1, 10, '%.0f');
        imgui.ShowHelp('Maximum notifications shown at once');
        components.DrawSlider('Display Duration', 'notificationsDisplayDuration', 1.0, 10.0, '%.1f sec');
        components.DrawSlider('Minimize Time', 'notificationsInviteMinifyTimeout', 3.0, 30.0, '%.0f sec');
        imgui.ShowHelp('Party and trade invites minimize after this time but stay pinned');
    end

    if components.CollapsingSection('Font Settings##notifications') then
        components.DrawSlider('Title Font Size', 'notificationsTitleFontSize', 8, 24, '%.0f');
        components.DrawSlider('Subtitle Font Size', 'notificationsSubtitleFontSize', 8, 24, '%.0f');
    end

    if components.CollapsingSection('Notification Types##notifications') then
        DrawCheckboxWithTest('Party Invites', 'notificationsShowPartyInvite', notificationData.NOTIFICATION_TYPE.PARTY_INVITE);
        DrawCheckboxWithTest('Trade Requests', 'notificationsShowTradeInvite', notificationData.NOTIFICATION_TYPE.TRADE_INVITE);
        DrawCheckboxWithTest('Treasure Pool', 'notificationsShowTreasure', notificationData.NOTIFICATION_TYPE.TREASURE_POOL);
        DrawCheckboxWithTest('Items Obtained', 'notificationsShowItems', notificationData.NOTIFICATION_TYPE.ITEM_OBTAINED);
        DrawCheckboxWithTest('Key Items', 'notificationsShowKeyItems', notificationData.NOTIFICATION_TYPE.KEY_ITEM_OBTAINED);
        DrawCheckboxWithTest('Gil', 'notificationsShowGil', notificationData.NOTIFICATION_TYPE.GIL_OBTAINED);
    end

    if components.CollapsingSection('Treasure Pool Window##notifications') then
        imgui.TextColored({0.7, 0.7, 0.7, 1.0}, 'Dedicated window showing all items in treasure pool');

        components.DrawCheckbox('Show Treasure Pool Window', 'notificationsTreasurePoolWindow');
        imgui.SameLine();
        if imgui.SmallButton('Test Pool') then
            addTestTreasurePoolItem();
        end
        imgui.ShowHelp('Add a test item to the treasure pool');

        imgui.Spacing();
        components.DrawCheckbox('Show Title', 'notificationsTreasurePoolShowTitle');
        imgui.ShowHelp('Show "Treasure Pool" header text at the top of the window');
        components.DrawCheckbox('Show Timer Bar', 'notificationsTreasurePoolShowTimerBar');
        imgui.ShowHelp('Show countdown progress bar at the bottom of each treasure pool item');
        components.DrawCheckbox('Show Timer', 'notificationsTreasurePoolShowTimerText');
        imgui.ShowHelp('Show countdown text (e.g., "4:32") on treasure pool items');
        components.DrawCheckbox('Show Lots', 'notificationsTreasurePoolShowLots');
        imgui.ShowHelp('Show party member lots on treasure pool items');

        imgui.Spacing();
        components.DrawSlider('Text Size', 'notificationsTreasurePoolFontSize', 8, 18, '%.0f px');
        imgui.ShowHelp('Font size for all text in the treasure pool window');
        components.DrawSlider('Scale X##TreasurePool', 'notificationsTreasurePoolScaleX', 0.5, 2.0, '%.1f');
        components.DrawSlider('Scale Y##TreasurePool', 'notificationsTreasurePoolScaleY', 0.5, 2.0, '%.1f');
    end

    if components.CollapsingSection('Split Windows##notifications') then
        imgui.TextColored({0.7, 0.7, 0.7, 1.0}, 'Display notification types in separate draggable windows');
        imgui.Spacing();

        components.DrawCheckbox('Split Party Invites', 'notificationsSplitPartyInvite');
        components.DrawCheckbox('Split Trade Requests', 'notificationsSplitTradeInvite');
        components.DrawCheckbox('Split Treasure Pool', 'notificationsSplitTreasurePool');
        components.DrawCheckbox('Split Items Obtained', 'notificationsSplitItemObtained');
        components.DrawCheckbox('Split Key Items', 'notificationsSplitKeyItemObtained');
        components.DrawCheckbox('Split Gil', 'notificationsSplitGilObtained');
    end
end

-- Section: Notifications Color Settings
function M.DrawColorSettings()
    if components.CollapsingSection('Notification Colors') then
        -- Ensure colorCustomization and notifications exist
        if not gConfig.colorCustomization then
            gConfig.colorCustomization = {};
        end
        if not gConfig.colorCustomization.notifications then
            gConfig.colorCustomization.notifications = deep_copy_table(defaultUserSettings.colorCustomization.notifications);
        end
        local colors = gConfig.colorCustomization.notifications;
        components.DrawTextColorPicker('Background', colors, 'bgColor', 'Notification card background');
        components.DrawTextColorPicker('Border', colors, 'borderColor', 'Notification card border');
        imgui.Separator();
        components.DrawTextColorPicker('Party Invite', colors, 'partyInviteColor', 'Party invite accent color');
        components.DrawTextColorPicker('Trade Request', colors, 'tradeInviteColor', 'Trade request accent color');
        components.DrawTextColorPicker('Treasure Pool', colors, 'treasurePoolColor', 'Treasure pool accent color');
        components.DrawTextColorPicker('Item Obtained', colors, 'itemObtainedColor', 'Item obtained accent color');
        components.DrawTextColorPicker('Key Item', colors, 'keyItemColor', 'Key item accent color');
        components.DrawTextColorPicker('Gil', colors, 'gilColor', 'Gil accent color');
        imgui.Separator();
        components.DrawTextColorPicker('Text', colors, 'textColor', 'Main text color');
        components.DrawTextColorPicker('Subtitle', colors, 'subtitleColor', 'Subtitle/secondary text color');
    end
end

return M;
