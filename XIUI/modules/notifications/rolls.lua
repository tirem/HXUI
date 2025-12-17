--[[
* XIUI Rolls Window Module
* Displays detailed treasure pool information with all rolls/passes
* Toggled via /xiui rolls command
]]--

require('common');
require('handlers.helpers');
local imgui = require('imgui');
local ffi = require('ffi');
local gdi = require('submodules.gdifonts.include');
local windowBg = require('libs.windowbackground');
local notificationData = require('modules.notifications.data');
local textures = require('libs.textures');
local d3d8 = require('d3d8');

local M = {};

-- ============================================
-- Module State
-- ============================================

-- Window visibility (toggled by /xiui rolls command)
M.isVisible = false;

-- Constants
local MAX_POOL_ITEMS = 10;
local MAX_HISTORY_ITEMS = 10;
local MAX_LOTS_PER_ITEM = 18;  -- Full alliance
local PARTY_SIZE = 6;
local NUM_PARTIES = 3;

-- Font objects
local fonts = {
    title = nil,            -- "Treasure Pool" title
    header = nil,           -- "Recent History" header
    itemNames = {},         -- Item name fonts (indexed by display slot)
    timers = {},            -- Timer fonts
    partyHeaders = {},      -- "Party A", "Party B", "Party C" headers
    lotters = {},           -- Lotter name/value fonts (3D: [itemSlot][partyIdx][memberIdx])
    historyItems = {},      -- History item name fonts
    historyWinners = {},    -- History winner fonts
};
local allFonts = {};

-- Background primitives
local bgPrims = {
    main = nil,             -- Main window background
};

-- Cached colors
local lastTitleColor = nil;
local lastHeaderColor = nil;
local lastItemNameColors = {};
local lastTimerColors = {};
local lastPartyHeaderColors = {};
local lastLotterColors = {};
local lastHistoryItemColors = {};
local lastHistoryWinnerColors = {};

-- Icon cache (reuse from notifications display pattern)
local iconCache = {};

-- ============================================
-- Icon Loading (same pattern as notifications/display.lua)
-- ============================================

local function loadItemIcon(itemId)
    if itemId == nil or itemId == 0 or itemId == -1 or itemId == 65535 then
        return nil;
    end

    if iconCache[itemId] then
        return iconCache[itemId];
    end

    local success, result = pcall(function()
        local device = GetD3D8Device();
        if device == nil then return nil; end

        local item = AshitaCore:GetResourceManager():GetItemById(itemId);
        if item == nil then return nil; end

        if item.Bitmap == nil or item.ImageSize == nil or item.ImageSize <= 0 then
            return nil;
        end

        local dx_texture_ptr = ffi.new('IDirect3DTexture8*[1]');
        if ffi.C.D3DXCreateTextureFromFileInMemoryEx(
            device, item.Bitmap, item.ImageSize,
            0xFFFFFFFF, 0xFFFFFFFF, 1, 0,
            ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED,
            ffi.C.D3DX_DEFAULT, ffi.C.D3DX_DEFAULT,
            0xFF000000, nil, nil, dx_texture_ptr
        ) == ffi.C.S_OK then
            return {
                image = d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', dx_texture_ptr[0]))
            };
        end
        return nil;
    end);

    if success and result then
        iconCache[itemId] = result;
    end

    return iconCache[itemId];
end

-- ============================================
-- Window Flags
-- ============================================

local baseWindowFlags = nil;

local function getWindowFlags()
    if baseWindowFlags == nil then
        baseWindowFlags = bit.bor(
            ImGuiWindowFlags_NoDecoration,
            ImGuiWindowFlags_AlwaysAutoResize,
            ImGuiWindowFlags_NoFocusOnAppearing,
            ImGuiWindowFlags_NoNav,
            ImGuiWindowFlags_NoBackground,
            ImGuiWindowFlags_NoBringToFrontOnFocus,
            ImGuiWindowFlags_NoDocking
        );
    end

    local flags = baseWindowFlags;
    if gConfig.lockPositions then
        flags = bit.bor(flags, ImGuiWindowFlags_NoMove);
    end
    return flags;
end

-- ============================================
-- Helper Functions
-- ============================================

-- Sort lots by lot value (highest first), passes last, pending at end
-- Returns array with party index (1-3) assigned based on order
local function sortAndAssignParties(lots)
    local sorted = {};
    for playerId, lotInfo in pairs(lots) do
        table.insert(sorted, {
            playerId = playerId,
            name = lotInfo.name,
            lot = lotInfo.lot,
            passed = lotInfo.passed,
            pending = lotInfo.pending or (lotInfo.lot == nil and not lotInfo.passed),
        });
    end

    -- Sort: lotted (highest first) > passed > pending
    table.sort(sorted, function(a, b)
        -- Pending always last
        if a.pending and not b.pending then return false; end
        if not a.pending and b.pending then return true; end
        -- Passes before pending but after lots
        if a.passed and not b.passed then return false; end
        if not a.passed and b.passed then return true; end
        return (a.lot or 0) > (b.lot or 0);
    end);

    -- Assign to parties based on position (simulating alliance order)
    -- In real usage, we'd use actual party membership
    local parties = {{}, {}, {}};
    for i, lotInfo in ipairs(sorted) do
        local partyIdx = math.ceil(i / PARTY_SIZE);
        if partyIdx > NUM_PARTIES then partyIdx = NUM_PARTIES; end
        table.insert(parties[partyIdx], lotInfo);
    end

    return parties;
end

-- ============================================
-- Lifecycle Functions
-- ============================================

function M.Initialize(settings)
    local fontSettings = settings and settings.font_settings or {};
    local titleFontSettings = settings and settings.title_font_settings or {};

    -- Title font ("Treasure Pool")
    fonts.title = FontManager.create({
        font_alignment = gdi.Alignment.Left,
        font_family = titleFontSettings.font_family or 'Consolas',
        font_height = 14,
        font_color = 0xFFFFFFFF,
        font_flags = gdi.FontFlags.Bold,
        outline_color = 0xFF000000,
        outline_width = 2,
    });
    table.insert(allFonts, fonts.title);

    -- Header font ("Recent History")
    fonts.header = FontManager.create({
        font_alignment = gdi.Alignment.Left,
        font_family = titleFontSettings.font_family or 'Consolas',
        font_height = 14,
        font_color = 0xFFFFFFFF,
        font_flags = gdi.FontFlags.Bold,
        outline_color = 0xFF000000,
        outline_width = 2,
    });
    table.insert(allFonts, fonts.header);

    -- Party header fonts
    for p = 1, NUM_PARTIES do
        fonts.partyHeaders[p] = FontManager.create({
            font_alignment = gdi.Alignment.Left,
            font_family = fontSettings.font_family or 'Consolas',
            font_height = 10,
            font_color = 0xFFAAAAFF,
            font_flags = gdi.FontFlags.Bold,
            outline_color = 0xFF000000,
            outline_width = 2,
        });
        table.insert(allFonts, fonts.partyHeaders[p]);
    end

    -- Create fonts for pool items (up to MAX_POOL_ITEMS)
    for i = 1, MAX_POOL_ITEMS do
        -- Item name font
        fonts.itemNames[i] = FontManager.create({
            font_alignment = gdi.Alignment.Left,
            font_family = fontSettings.font_family or 'Consolas',
            font_height = 12,
            font_color = 0xFFFFFFFF,
            font_flags = gdi.FontFlags.Bold,
            outline_color = 0xFF000000,
            outline_width = 2,
        });
        table.insert(allFonts, fonts.itemNames[i]);

        -- Timer font
        fonts.timers[i] = FontManager.create({
            font_alignment = gdi.Alignment.Left,
            font_family = fontSettings.font_family or 'Consolas',
            font_height = 10,
            font_color = 0xFFFFFF4D,
            font_flags = gdi.FontFlags.None,
            outline_color = 0xFF000000,
            outline_width = 2,
        });
        table.insert(allFonts, fonts.timers[i]);

        -- Lotter fonts organized by party (3 parties x 6 members each)
        fonts.lotters[i] = {};
        for p = 1, NUM_PARTIES do
            fonts.lotters[i][p] = {};
            for m = 1, PARTY_SIZE do
                fonts.lotters[i][p][m] = FontManager.create({
                    font_alignment = gdi.Alignment.Left,
                    font_family = fontSettings.font_family or 'Consolas',
                    font_height = 10,
                    font_color = 0xFFCCCCCC,
                    font_flags = gdi.FontFlags.None,
                    outline_color = 0xFF000000,
                    outline_width = 2,
                });
                table.insert(allFonts, fonts.lotters[i][p][m]);
            end
        end
    end

    -- Create fonts for history items
    for i = 1, MAX_HISTORY_ITEMS do
        fonts.historyItems[i] = FontManager.create({
            font_alignment = gdi.Alignment.Left,
            font_family = fontSettings.font_family or 'Consolas',
            font_height = 11,
            font_color = 0xFFCCCCCC,
            font_flags = gdi.FontFlags.None,
            outline_color = 0xFF000000,
            outline_width = 2,
        });
        table.insert(allFonts, fonts.historyItems[i]);

        fonts.historyWinners[i] = FontManager.create({
            font_alignment = gdi.Alignment.Left,
            font_family = fontSettings.font_family or 'Consolas',
            font_height = 11,
            font_color = 0xFF4DFF4D,
            font_flags = gdi.FontFlags.None,
            outline_color = 0xFF000000,
            outline_width = 2,
        });
        table.insert(allFonts, fonts.historyWinners[i]);
    end

    -- Create background primitive
    local primData = {
        visible = false,
        can_focus = false,
        locked = true,
    };
    bgPrims.main = windowBg.create(primData, 'Plain', 1.0);
end

function M.UpdateVisuals(settings)
    local fontSettings = settings and settings.font_settings or {};
    local titleFontSettings = settings and settings.title_font_settings or {};

    -- Recreate title font
    if fonts.title then
        fonts.title = FontManager.recreate(fonts.title, {
            font_alignment = gdi.Alignment.Left,
            font_family = titleFontSettings.font_family or 'Consolas',
            font_height = 14,
            font_color = 0xFFFFFFFF,
            font_flags = gdi.FontFlags.Bold,
            outline_color = 0xFF000000,
            outline_width = 2,
        });
    end

    -- Recreate header font
    if fonts.header then
        fonts.header = FontManager.recreate(fonts.header, {
            font_alignment = gdi.Alignment.Left,
            font_family = titleFontSettings.font_family or 'Consolas',
            font_height = 14,
            font_color = 0xFFFFFFFF,
            font_flags = gdi.FontFlags.Bold,
            outline_color = 0xFF000000,
            outline_width = 2,
        });
    end

    -- Recreate party header fonts
    for p = 1, NUM_PARTIES do
        if fonts.partyHeaders[p] then
            fonts.partyHeaders[p] = FontManager.recreate(fonts.partyHeaders[p], {
                font_alignment = gdi.Alignment.Left,
                font_family = fontSettings.font_family or 'Consolas',
                font_height = 10,
                font_color = 0xFFAAAAFF,
                font_flags = gdi.FontFlags.Bold,
                outline_color = 0xFF000000,
                outline_width = 2,
            });
        end
    end

    -- Recreate pool item fonts
    for i = 1, MAX_POOL_ITEMS do
        if fonts.itemNames[i] then
            fonts.itemNames[i] = FontManager.recreate(fonts.itemNames[i], {
                font_alignment = gdi.Alignment.Left,
                font_family = fontSettings.font_family or 'Consolas',
                font_height = 12,
                font_color = 0xFFFFFFFF,
                font_flags = gdi.FontFlags.Bold,
                outline_color = 0xFF000000,
                outline_width = 2,
            });
        end

        if fonts.timers[i] then
            fonts.timers[i] = FontManager.recreate(fonts.timers[i], {
                font_alignment = gdi.Alignment.Left,
                font_family = fontSettings.font_family or 'Consolas',
                font_height = 10,
                font_color = 0xFFFFFF4D,
                font_flags = gdi.FontFlags.None,
                outline_color = 0xFF000000,
                outline_width = 2,
            });
        end

        if fonts.lotters[i] then
            for p = 1, NUM_PARTIES do
                if fonts.lotters[i][p] then
                    for m = 1, PARTY_SIZE do
                        if fonts.lotters[i][p][m] then
                            fonts.lotters[i][p][m] = FontManager.recreate(fonts.lotters[i][p][m], {
                                font_alignment = gdi.Alignment.Left,
                                font_family = fontSettings.font_family or 'Consolas',
                                font_height = 10,
                                font_color = 0xFFCCCCCC,
                                font_flags = gdi.FontFlags.None,
                                outline_color = 0xFF000000,
                                outline_width = 2,
                            });
                        end
                    end
                end
            end
        end
    end

    -- Recreate history fonts
    for i = 1, MAX_HISTORY_ITEMS do
        if fonts.historyItems[i] then
            fonts.historyItems[i] = FontManager.recreate(fonts.historyItems[i], {
                font_alignment = gdi.Alignment.Left,
                font_family = fontSettings.font_family or 'Consolas',
                font_height = 11,
                font_color = 0xFFCCCCCC,
                font_flags = gdi.FontFlags.None,
                outline_color = 0xFF000000,
                outline_width = 2,
            });
        end

        if fonts.historyWinners[i] then
            fonts.historyWinners[i] = FontManager.recreate(fonts.historyWinners[i], {
                font_alignment = gdi.Alignment.Left,
                font_family = fontSettings.font_family or 'Consolas',
                font_height = 11,
                font_color = 0xFF4DFF4D,
                font_flags = gdi.FontFlags.None,
                outline_color = 0xFF000000,
                outline_width = 2,
            });
        end
    end

    -- Rebuild allFonts list
    allFonts = {};
    if fonts.title then table.insert(allFonts, fonts.title); end
    if fonts.header then table.insert(allFonts, fonts.header); end
    for p = 1, NUM_PARTIES do
        if fonts.partyHeaders[p] then table.insert(allFonts, fonts.partyHeaders[p]); end
    end
    for i = 1, MAX_POOL_ITEMS do
        if fonts.itemNames[i] then table.insert(allFonts, fonts.itemNames[i]); end
        if fonts.timers[i] then table.insert(allFonts, fonts.timers[i]); end
        if fonts.lotters[i] then
            for p = 1, NUM_PARTIES do
                if fonts.lotters[i][p] then
                    for m = 1, PARTY_SIZE do
                        if fonts.lotters[i][p][m] then table.insert(allFonts, fonts.lotters[i][p][m]); end
                    end
                end
            end
        end
    end
    for i = 1, MAX_HISTORY_ITEMS do
        if fonts.historyItems[i] then table.insert(allFonts, fonts.historyItems[i]); end
        if fonts.historyWinners[i] then table.insert(allFonts, fonts.historyWinners[i]); end
    end

    -- Clear cached colors
    lastTitleColor = nil;
    lastHeaderColor = nil;
    lastItemNameColors = {};
    lastTimerColors = {};
    lastPartyHeaderColors = {};
    lastLotterColors = {};
    lastHistoryItemColors = {};
    lastHistoryWinnerColors = {};
end

function M.DrawWindow(settings)
    -- Hide all fonts first
    SetFontsVisible(allFonts, false);

    -- Hide background
    if bgPrims.main then
        windowBg.hide(bgPrims.main);
    end

    -- Early exit if not visible or player not valid
    if not M.isVisible then return; end

    local player = GetPlayerSafe();
    if not player or player.isZoning then return; end

    -- Get treasure pool and history data
    local poolItems = notificationData.GetSortedTreasurePool();
    local history = notificationData.GetAwardedHistory();

    local poolCount = poolItems and #poolItems or 0;
    local historyCount = history and #history or 0;

    -- If nothing to show, hide the window
    if poolCount == 0 and historyCount == 0 then
        return;
    end

    -- Layout constants
    local padding = 12;
    local iconSize = 20;
    local itemSpacing = 6;
    local sectionSpacing = 16;
    local columnWidth = 120;
    local columnGap = 8;
    local lotterLineHeight = 13;
    local titleHeight = 18;
    local headerHeight = 16;
    local itemNameHeight = 16;
    local historyLineHeight = 16;

    -- Calculate window width (3 columns + gaps + padding)
    local contentWidth = (columnWidth * 3) + (columnGap * 2);
    local windowWidth = contentWidth + (padding * 2);

    -- Calculate heights
    local poolSectionHeight = 0;
    if poolCount > 0 then
        poolSectionHeight = titleHeight + itemSpacing;  -- "Treasure Pool" title
        for idx, item in ipairs(poolItems) do
            if idx > MAX_POOL_ITEMS then break; end
            local parties = sortAndAssignParties(item.lots or {});
            local maxPartySize = 0;
            for p = 1, NUM_PARTIES do
                maxPartySize = math.max(maxPartySize, #parties[p]);
            end
            -- Item row + lotter rows + border padding
            local itemBoxPaddingY = 8;
            poolSectionHeight = poolSectionHeight + itemBoxPaddingY;  -- Top padding
            poolSectionHeight = poolSectionHeight + itemNameHeight + itemSpacing;
            poolSectionHeight = poolSectionHeight + (maxPartySize * lotterLineHeight);
            poolSectionHeight = poolSectionHeight + itemBoxPaddingY + itemSpacing;  -- Bottom padding + spacing
        end
    end

    local historySectionHeight = 0;
    if historyCount > 0 then
        if poolCount > 0 then
            historySectionHeight = sectionSpacing;
        end
        historySectionHeight = historySectionHeight + headerHeight + itemSpacing;
        historySectionHeight = historySectionHeight + (math.min(historyCount, MAX_HISTORY_ITEMS) * historyLineHeight);
    end

    local totalContentHeight = poolSectionHeight + historySectionHeight;

    -- Create ImGui window
    local windowFlags = getWindowFlags();

    if imgui.Begin('RollsWindow', true, windowFlags) then
        local success, err = pcall(function()
            local windowPosX, windowPosY = imgui.GetWindowPos();
            local drawList = imgui.GetWindowDrawList();

            -- Create dummy for draggable area
            imgui.Dummy({windowWidth, totalContentHeight + (padding * 2)});

            -- Update background with correct dimensions
            if bgPrims.main then
                windowBg.update(bgPrims.main, windowPosX, windowPosY,
                    windowWidth, totalContentHeight + (padding * 2), {
                    theme = 'Plain',
                    padding = 0,
                    bgOpacity = 0.92,
                    bgColor = 0xFF1A1A1A,
                });
            end

            local contentX = windowPosX + padding;
            local contentY = windowPosY + padding;
            local currentY = contentY;

            -- Draw close button (X) in top right
            local closeBtnSize = 16;
            local closeBtnX = windowPosX + windowWidth - padding - closeBtnSize + 4;
            local closeBtnY = windowPosY + 6;

            -- Draw X
            local xColor = 0xFF888888;
            local xHoverColor = 0xFFFFFFFF;

            -- Check if mouse is hovering over close button area
            local mouseX, mouseY = imgui.GetMousePos();
            local isHovering = mouseX >= closeBtnX and mouseX <= closeBtnX + closeBtnSize
                           and mouseY >= closeBtnY and mouseY <= closeBtnY + closeBtnSize;

            if isHovering then
                xColor = xHoverColor;
                if imgui.IsMouseClicked(0) then
                    M.isVisible = false;
                end
            end

            if drawList then
                local x1, y1 = closeBtnX + 3, closeBtnY + 3;
                local x2, y2 = closeBtnX + closeBtnSize - 3, closeBtnY + closeBtnSize - 3;
                drawList:AddLine({x1, y1}, {x2, y2}, xColor, 2);
                drawList:AddLine({x2, y1}, {x1, y2}, xColor, 2);
            end

            -- ========================================
            -- Draw Treasure Pool Section
            -- ========================================
            if poolCount > 0 then
                -- Title: "Treasure Pool"
                if fonts.title then
                    fonts.title:set_font_height(14);
                    fonts.title:set_position_x(contentX);
                    fonts.title:set_position_y(currentY);
                    fonts.title:set_text('Treasure Pool');
                    if lastTitleColor ~= 0xFFFFFFFF then
                        fonts.title:set_font_color(0xFFFFFFFF);
                        lastTitleColor = 0xFFFFFFFF;
                    end
                    fonts.title:set_visible(true);
                end
                currentY = currentY + titleHeight + itemSpacing;

                -- Draw each pool item
                for idx, item in ipairs(poolItems) do
                    if idx > MAX_POOL_ITEMS then break; end

                    -- Calculate item box dimensions first
                    local parties = sortAndAssignParties(item.lots or {});
                    local maxPartySize = 0;
                    for p = 1, NUM_PARTIES do
                        maxPartySize = math.max(maxPartySize, #parties[p]);
                    end

                    local itemBoxPaddingY = 8;
                    local itemBoxPaddingX = 8;
                    local itemBoxHeight = itemBoxPaddingY + itemNameHeight + itemSpacing + (maxPartySize * lotterLineHeight) + itemBoxPaddingY;

                    -- Draw item container border
                    if drawList then
                        drawList:AddRect(
                            {contentX - 2, currentY},
                            {contentX + contentWidth + 2, currentY + itemBoxHeight},
                            0xFF444444, 4, 0, 1
                        );
                    end

                    currentY = currentY + itemBoxPaddingY;
                    local itemX = contentX + itemBoxPaddingX;
                    local itemY = currentY;
                    local itemContentWidth = contentWidth - (itemBoxPaddingX * 2);

                    -- Draw item icon
                    local icon = loadItemIcon(item.itemId);
                    if icon and icon.image and drawList then
                        pcall(function()
                            drawList:AddImage(
                                tonumber(ffi.cast("uint32_t", icon.image)),
                                {itemX, itemY},
                                {itemX + iconSize, itemY + iconSize},
                                {0, 0}, {1, 1},
                                0xFFFFFFFF
                            );
                        end);
                    end

                    -- Draw item name
                    local nameFont = fonts.itemNames[idx];
                    if nameFont then
                        nameFont:set_font_height(12);
                        nameFont:set_position_x(itemX + iconSize + 6);
                        nameFont:set_position_y(itemY + 2);
                        nameFont:set_text(item.itemName or 'Unknown Item');
                        if lastItemNameColors[idx] ~= 0xFFFFFFFF then
                            nameFont:set_font_color(0xFFFFFFFF);
                            lastItemNameColors[idx] = 0xFFFFFFFF;
                        end
                        nameFont:set_visible(true);
                    end

                    -- Draw timer on right side
                    local remaining = notificationData.GetTreasurePoolTimeRemaining(item.slot);
                    local timerText = notificationData.FormatPoolTimer(remaining);
                    local timerColor;
                    if remaining > 60 then
                        timerColor = 0xFFFFFF4D;
                    elseif remaining > 30 then
                        timerColor = 0xFFFF9933;
                    else
                        timerColor = 0xFFFF4D4D;
                    end

                    local timerFont = fonts.timers[idx];
                    if timerFont then
                        timerFont:set_font_height(10);
                        timerFont:set_text(timerText);
                        local timerWidth, _ = timerFont:get_text_size();
                        timerFont:set_position_x(itemX + itemContentWidth - timerWidth);
                        timerFont:set_position_y(itemY + 3);
                        if lastTimerColors[idx] ~= timerColor then
                            timerFont:set_font_color(timerColor);
                            lastTimerColors[idx] = timerColor;
                        end
                        timerFont:set_visible(true);
                    end

                    currentY = currentY + itemNameHeight + itemSpacing;

                    -- Draw lot entries for each party (parties already calculated above)
                    local colWidthAdjusted = (itemContentWidth - (columnGap * 2)) / 3;
                    for row = 1, maxPartySize do
                        for p = 1, NUM_PARTIES do
                            local colX = itemX + ((p - 1) * (colWidthAdjusted + columnGap));
                            local lotInfo = parties[p][row];

                            if lotInfo then
                                local lotterFont = fonts.lotters[idx] and fonts.lotters[idx][p] and fonts.lotters[idx][p][row];
                                if lotterFont then
                                    local lotText;
                                    local lotColor;

                                    -- Truncate name if needed
                                    local displayName = lotInfo.name;
                                    if #displayName > 10 then
                                        displayName = displayName:sub(1, 9) .. '.';
                                    end

                                    if lotInfo.pending then
                                        lotText = string.format('%s - ...', displayName);
                                        lotColor = 0xFFE5B84D;  -- Light yellow/orange for pending
                                    elseif lotInfo.passed then
                                        lotText = string.format('%s - Pass', displayName);
                                        lotColor = 0xFF888888;
                                    else
                                        lotText = string.format('%s - %d', displayName, lotInfo.lot or 0);
                                        if lotInfo.lot == item.highestLot then
                                            lotColor = 0xFF4DFF4D;  -- Green for highest
                                        else
                                            lotColor = 0xFFCCCCCC;
                                        end
                                    end

                                    lotterFont:set_font_height(10);
                                    lotterFont:set_position_x(colX);
                                    lotterFont:set_position_y(currentY + ((row - 1) * lotterLineHeight));
                                    lotterFont:set_text(lotText);

                                    local colorKey = idx * 1000 + p * 100 + row;
                                    if lastLotterColors[colorKey] ~= lotColor then
                                        lotterFont:set_font_color(lotColor);
                                        lastLotterColors[colorKey] = lotColor;
                                    end
                                    lotterFont:set_visible(true);
                                end
                            end
                        end
                    end

                    currentY = currentY + (maxPartySize * lotterLineHeight) + itemBoxPaddingY + itemSpacing;
                end
            end

            -- ========================================
            -- Draw Recent History Section
            -- ========================================
            if historyCount > 0 then
                if poolCount > 0 then
                    currentY = currentY + sectionSpacing;

                    -- Draw separator line
                    if drawList then
                        local lineY = currentY - (sectionSpacing / 2);
                        drawList:AddLine(
                            {contentX, lineY},
                            {contentX + contentWidth, lineY},
                            0xFF444444, 1
                        );
                    end
                end

                -- Header: "Recent History"
                if fonts.header then
                    fonts.header:set_font_height(14);
                    fonts.header:set_position_x(contentX);
                    fonts.header:set_position_y(currentY);
                    fonts.header:set_text('Recent History');
                    if lastHeaderColor ~= 0xFFFFFFFF then
                        fonts.header:set_font_color(0xFFFFFFFF);
                        lastHeaderColor = 0xFFFFFFFF;
                    end
                    fonts.header:set_visible(true);
                end
                currentY = currentY + headerHeight + itemSpacing;

                -- Draw history items
                for idx, historyItem in ipairs(history) do
                    if idx > MAX_HISTORY_ITEMS then break; end

                    local histX = contentX;
                    local histY = currentY;

                    -- Draw item icon
                    local icon = loadItemIcon(historyItem.itemId);
                    if icon and icon.image and drawList then
                        pcall(function()
                            drawList:AddImage(
                                tonumber(ffi.cast("uint32_t", icon.image)),
                                {histX, histY},
                                {histX + 16, histY + 16},
                                {0, 0}, {1, 1},
                                0xFFFFFFFF
                            );
                        end);
                    end

                    -- Draw item name
                    local itemFont = fonts.historyItems[idx];
                    if itemFont then
                        itemFont:set_font_height(11);
                        itemFont:set_position_x(histX + 20);
                        itemFont:set_position_y(histY + 2);
                        itemFont:set_text(historyItem.itemName or 'Unknown Item');
                        if lastHistoryItemColors[idx] ~= 0xFFCCCCCC then
                            itemFont:set_font_color(0xFFCCCCCC);
                            lastHistoryItemColors[idx] = 0xFFCCCCCC;
                        end
                        itemFont:set_visible(true);
                    end

                    -- Draw winner name on right
                    local winnerFont = fonts.historyWinners[idx];
                    if winnerFont then
                        local winnerText = historyItem.winnerName or 'No Winner';
                        local winnerColor = historyItem.winnerName and 0xFF4DFF4D or 0xFF888888;

                        winnerFont:set_font_height(11);
                        winnerFont:set_text(winnerText);
                        local winnerWidth, _ = winnerFont:get_text_size();
                        winnerFont:set_position_x(contentX + contentWidth - winnerWidth);
                        winnerFont:set_position_y(histY + 2);
                        if lastHistoryWinnerColors[idx] ~= winnerColor then
                            winnerFont:set_font_color(winnerColor);
                            lastHistoryWinnerColors[idx] = winnerColor;
                        end
                        winnerFont:set_visible(true);
                    end

                    currentY = currentY + historyLineHeight;
                end
            end
        end);

        if not success and err then
            print('[XIUI RollsWindow] Render error: ' .. tostring(err));
        end
    end
    imgui.End();
end

function M.SetHidden(hidden)
    if hidden then
        SetFontsVisible(allFonts, false);
        if bgPrims.main then
            windowBg.hide(bgPrims.main);
        end
    end
end

function M.Cleanup()
    -- Destroy all fonts
    if fonts.title then
        fonts.title = FontManager.destroy(fonts.title);
    end
    if fonts.header then
        fonts.header = FontManager.destroy(fonts.header);
    end

    for p = 1, NUM_PARTIES do
        if fonts.partyHeaders[p] then
            fonts.partyHeaders[p] = FontManager.destroy(fonts.partyHeaders[p]);
        end
    end

    for i = 1, MAX_POOL_ITEMS do
        if fonts.itemNames[i] then
            fonts.itemNames[i] = FontManager.destroy(fonts.itemNames[i]);
        end
        if fonts.timers[i] then
            fonts.timers[i] = FontManager.destroy(fonts.timers[i]);
        end
        if fonts.lotters[i] then
            for p = 1, NUM_PARTIES do
                if fonts.lotters[i][p] then
                    for m = 1, PARTY_SIZE do
                        if fonts.lotters[i][p][m] then
                            fonts.lotters[i][p][m] = FontManager.destroy(fonts.lotters[i][p][m]);
                        end
                    end
                end
            end
        end
    end

    for i = 1, MAX_HISTORY_ITEMS do
        if fonts.historyItems[i] then
            fonts.historyItems[i] = FontManager.destroy(fonts.historyItems[i]);
        end
        if fonts.historyWinners[i] then
            fonts.historyWinners[i] = FontManager.destroy(fonts.historyWinners[i]);
        end
    end

    allFonts = {};
    fonts = {
        title = nil,
        header = nil,
        itemNames = {},
        timers = {},
        partyHeaders = {},
        lotters = {},
        historyItems = {},
        historyWinners = {},
    };

    -- Destroy background
    if bgPrims.main then
        windowBg.destroy(bgPrims.main);
        bgPrims.main = nil;
    end

    -- Clear icon cache
    iconCache = {};

    -- Clear cached colors
    lastTitleColor = nil;
    lastHeaderColor = nil;
    lastItemNameColors = {};
    lastTimerColors = {};
    lastPartyHeaderColors = {};
    lastLotterColors = {};
    lastHistoryItemColors = {};
    lastHistoryWinnerColors = {};
end

-- ============================================
-- Toggle Function (called by command handler)
-- ============================================

function M.Toggle()
    M.isVisible = not M.isVisible;
    return M.isVisible;
end

function M.Show()
    M.isVisible = true;
end

function M.Hide()
    M.isVisible = false;
end

return M;
