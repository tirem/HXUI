--[[
* XIUI Treasure Pool - Display Module
* Handles rendering of the treasure pool mini-display
* Fonts are created by init.lua and stored in data module
*
* Each item row displays:
*   - Item icon (24x24, left-aligned)
*   - Item name (after icon)
*   - Highest lot info (middle-right)
*   - Timer text (right-aligned)
*   - Progress bar (bottom of row)
]]--

require('common');
require('handlers.helpers');
local imgui = require('imgui');
local ffi = require('ffi');
local d3d8 = require('d3d8');
local windowBg = require('libs.windowbackground');
local progressbar = require('libs.progressbar');
local data = require('modules.treasurepool.data');

local M = {};

-- ============================================
-- Constants
-- ============================================

local ICON_SIZE = 24;
local ROW_HEIGHT = 28;
local PADDING = 8;
local ICON_TEXT_GAP = 6;
local ROW_SPACING = 4;
local BAR_HEIGHT = 3;

-- ============================================
-- State
-- ============================================

M.fullWindowVisible = false;

-- Background primitive handle
local bgPrimHandle = nil;

-- Theme tracking (for detecting changes like petbar)
local loadedBgTheme = nil;

-- Item icon cache (itemId -> texture table with .image)
local iconCache = {};

-- ============================================
-- Item Icon Loading
-- ============================================

-- Load item icon from game resources
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

local function getIconPtr(texture)
    if texture and texture.image then
        return tonumber(ffi.cast("uint32_t", texture.image));
    end
    return nil;
end

-- ============================================
-- Helper Functions
-- ============================================

-- Timer gradient colors based on remaining time
local TIMER_GRADIENTS = {
    critical = { '#ff4444', '#ff6666' },  -- < 60s - red
    warning = { '#ffaa44', '#ffcc66' },   -- < 120s - orange/yellow
    normal = { '#4488ff', '#66aaff' },    -- >= 120s - blue
};

local function getTimerGradient(remaining)
    if remaining < 60 then
        return TIMER_GRADIENTS.critical;
    elseif remaining < 120 then
        return TIMER_GRADIENTS.warning;
    end
    return TIMER_GRADIENTS.normal;
end

local function getTimerColor(remaining)
    if remaining < 60 then
        return 0xFFFF6666;
    elseif remaining < 120 then
        return 0xFFFFCC66;
    end
    return 0xFFFFFFFF;
end

-- ============================================
-- Mini Display
-- ============================================

function M.DrawMiniDisplay(settings)
    local poolItems = data.GetSortedPoolItems();
    if #poolItems == 0 then
        M.HideMiniDisplay();
        return;
    end

    -- Get settings with validation
    local scaleX = gConfig.treasurePoolMiniScaleX;
    if scaleX == nil or scaleX < 0.5 then scaleX = 1.0; end

    local scaleY = gConfig.treasurePoolMiniScaleY;
    if scaleY == nil or scaleY < 0.5 then scaleY = 1.0; end

    local fontSize = gConfig.treasurePoolMiniFontSize;
    if fontSize == nil or fontSize < 8 then fontSize = 10; end

    local showTitle = gConfig.treasurePoolMiniShowTitle ~= false;
    local showTimerBar = gConfig.treasurePoolMiniShowTimerBar ~= false;
    local showTimerText = gConfig.treasurePoolMiniShowTimerText ~= false;
    local showLots = gConfig.treasurePoolMiniShowLots ~= false;
    local bgOpacity = gConfig.treasurePoolMiniOpacity or 0.87;
    local bgTheme = gConfig.treasurePoolMiniBackgroundTheme or 'Plain';

    -- Calculate dimensions
    local iconSize = math.floor(ICON_SIZE * scaleY);
    local rowHeight = math.floor(ROW_HEIGHT * scaleY);
    local padding = PADDING;  -- Fixed 8px padding, not scaled
    local iconTextGap = math.floor(ICON_TEXT_GAP * scaleX);
    local rowSpacing = math.floor(ROW_SPACING * scaleY);
    local barHeight = math.floor(BAR_HEIGHT * scaleY);
    local contentBaseWidth = math.floor(264 * scaleX);  -- Content area width (scales)
    local windowWidth = contentBaseWidth + (padding * 2);  -- Total = content + 8px on each side

    local headerHeight = 0;
    if showTitle then
        headerHeight = fontSize + math.floor(6 * scaleY);
    end

    local contentHeight = #poolItems * rowHeight + (#poolItems - 1) * rowSpacing;
    local totalHeight = padding + headerHeight + contentHeight + padding;

    -- Build window flags using helper from handlers.helpers
    local windowFlags = GetBaseWindowFlags(gConfig.lockPositions);

    imgui.SetNextWindowSize({-1, -1}, ImGuiCond_Always);

    if imgui.Begin('TreasurePoolMini', true, windowFlags) then
        -- Get cursor position as base for all positioning (consistent reference point)
        local startX, startY = imgui.GetCursorScreenPos();
        local drawList = imgui.GetBackgroundDrawList();

        imgui.Dummy({windowWidth, totalHeight});

        -- Check if theme changed and reload textures if needed (like petbar)
        if loadedBgTheme ~= bgTheme and bgPrimHandle then
            loadedBgTheme = bgTheme;
            windowBg.setTheme(bgPrimHandle, bgTheme, 1.0, 1.0);
        end

        -- Calculate content area (excluding padding)
        local contentWidth = windowWidth - (padding * 2);
        local contentHeightTotal = headerHeight + (#poolItems * rowHeight) + ((#poolItems - 1) * rowSpacing);

        -- Update background: pass content position and let windowBg add padding
        -- Content starts at (startX + padding, startY + padding)
        if bgPrimHandle then
            windowBg.update(bgPrimHandle, startX + padding, startY + padding, contentWidth, contentHeightTotal, {
                theme = bgTheme,
                padding = padding,
                bgOpacity = bgOpacity,
                bgColor = 0xFF1A1A1A,
            });
        end

        local y = startY + padding;

        -- Draw header using data.headerFont
        if showTitle and data.headerFont then
            data.headerFont:set_font_height(fontSize);
            data.headerFont:set_text('Treasure Pool');
            data.headerFont:set_position_x(startX + padding);
            data.headerFont:set_position_y(y);
            data.headerFont:set_visible(true);

            if data.lastColors.header ~= 0xFFFFFFFF then
                data.headerFont:set_font_color(0xFFFFFFFF);
                data.lastColors.header = 0xFFFFFFFF;
            end

            y = y + headerHeight;
        elseif data.headerFont then
            data.headerFont:set_visible(false);
        end

        local usedSlots = {};

        -- Draw each item row
        for i, item in ipairs(poolItems) do
            local slot = item.slot;
            usedSlots[slot] = true;

            local rowY = y + (i - 1) * (rowHeight + rowSpacing);
            local remaining = data.GetTimeRemaining(slot);
            local progress = remaining / data.POOL_TIMEOUT_SECONDS;

            -- 1. Draw item icon
            local iconTexture = loadItemIcon(item.itemId);
            local iconPtr = getIconPtr(iconTexture);
            local iconX = startX + padding;
            local iconY = rowY + (rowHeight - barHeight - iconSize) / 2;

            if iconPtr then
                drawList:AddImage(iconPtr, {iconX, iconY}, {iconX + iconSize, iconY + iconSize});
            end

            local textStartX = iconX + iconSize + iconTextGap;
            local textY = rowY + (rowHeight - barHeight - fontSize) / 2;

            -- 2. Draw item name using data.itemNameFonts[slot]
            local nameFont = data.itemNameFonts[slot];
            if nameFont then
                nameFont:set_font_height(fontSize);
                nameFont:set_text(item.itemName or 'Unknown');
                nameFont:set_position_x(textStartX);
                nameFont:set_position_y(textY);
                nameFont:set_visible(true);

                if data.lastColors.itemNames[slot] ~= 0xFFFFFFFF then
                    nameFont:set_font_color(0xFFFFFFFF);
                    data.lastColors.itemNames[slot] = 0xFFFFFFFF;
                end
            end

            -- 3. Draw timer text using data.timerFonts[slot]
            if showTimerText then
                local timerFont = data.timerFonts[slot];
                if timerFont then
                    local timerText = data.FormatTime(remaining);
                    timerFont:set_font_height(fontSize);
                    timerFont:set_text(timerText);

                    local timerWidth, _ = timerFont:get_text_size();
                    timerFont:set_position_x(startX + windowWidth - padding - timerWidth);
                    timerFont:set_position_y(textY);
                    timerFont:set_visible(true);

                    local timerColor = getTimerColor(remaining);
                    if data.lastColors.timers[slot] ~= timerColor then
                        timerFont:set_font_color(timerColor);
                        data.lastColors.timers[slot] = timerColor;
                    end
                end
            else
                if data.timerFonts[slot] then
                    data.timerFonts[slot]:set_visible(false);
                end
            end

            -- 4. Draw lot info using data.lotFonts[slot]
            if showLots and item.winningLot and item.winningLot > 0 and nameFont then
                local lotFont = data.lotFonts[slot];
                if lotFont then
                    local lotterName = item.winningLotterName or '?';
                    if #lotterName > 10 then
                        lotterName = lotterName:sub(1, 8) .. '..';
                    end
                    local lotText = string.format('%s: %d', lotterName, item.winningLot);

                    lotFont:set_font_height(fontSize - 1);
                    lotFont:set_text(lotText);

                    local nameWidth, _ = nameFont:get_text_size();
                    local lotX = textStartX + nameWidth + math.floor(10 * scaleX);
                    lotFont:set_position_x(lotX);
                    lotFont:set_position_y(textY);
                    lotFont:set_visible(true);

                    if data.lastColors.lots[slot] ~= 0xFF88FF88 then
                        lotFont:set_font_color(0xFF88FF88);
                        data.lastColors.lots[slot] = 0xFF88FF88;
                    end
                end
            else
                if data.lotFonts[slot] then
                    data.lotFonts[slot]:set_visible(false);
                end
            end

            -- 5. Draw progress bar using progressbar library
            if showTimerBar then
                local barY = rowY + rowHeight - barHeight;
                local barStartX = startX + padding;
                local barWidth = windowWidth - padding * 2;

                -- Get gradient based on remaining time
                local timerGradient = getTimerGradient(remaining);

                progressbar.ProgressBar(
                    {{math.max(0, math.min(1, progress)), timerGradient}},
                    {barWidth, barHeight},
                    {
                        decorate = false,
                        absolutePosition = {barStartX, barY},
                        drawList = drawList,
                    }
                );
            end
        end

        -- Hide fonts for unused slots
        for slot = 0, data.MAX_POOL_SLOTS - 1 do
            if not usedSlots[slot] then
                if data.itemNameFonts[slot] then data.itemNameFonts[slot]:set_visible(false); end
                if data.timerFonts[slot] then data.timerFonts[slot]:set_visible(false); end
                if data.lotFonts[slot] then data.lotFonts[slot]:set_visible(false); end
            end
        end
    end
    imgui.End();
end

function M.HideMiniDisplay()
    if data.headerFont then
        data.headerFont:set_visible(false);
    end

    for slot = 0, data.MAX_POOL_SLOTS - 1 do
        if data.itemNameFonts[slot] then data.itemNameFonts[slot]:set_visible(false); end
        if data.timerFonts[slot] then data.timerFonts[slot]:set_visible(false); end
        if data.lotFonts[slot] then data.lotFonts[slot]:set_visible(false); end
    end

    if bgPrimHandle then
        windowBg.hide(bgPrimHandle);
    end
end

-- ============================================
-- Full Window (stub)
-- ============================================

function M.DrawFullWindow(settings)
    -- TODO: Implement full window with lot/pass buttons
end

function M.HideFullWindow()
    -- TODO
end

function M.ToggleFullWindow()
    M.fullWindowVisible = not M.fullWindowVisible;
    return M.fullWindowVisible;
end

function M.ShowFullWindow()
    M.fullWindowVisible = true;
end

function M.HideFullWindowCmd()
    M.fullWindowVisible = false;
end

-- ============================================
-- Lifecycle
-- ============================================

function M.Initialize(settings)
    -- Get background theme from config (with default)
    local bgTheme = gConfig.treasurePoolMiniBackgroundTheme or 'Plain';
    loadedBgTheme = bgTheme;

    -- Create background primitive (fonts created by init.lua)
    local primData = {
        visible = false,
        can_focus = false,
        locked = true,
        width = 100,
        height = 100,
    };
    bgPrimHandle = windowBg.create(primData, bgTheme, 1.0, 1.0);
end

function M.UpdateVisuals(settings)
    -- Check if theme changed
    local bgTheme = gConfig.treasurePoolMiniBackgroundTheme or 'Plain';
    if loadedBgTheme ~= bgTheme and bgPrimHandle then
        loadedBgTheme = bgTheme;
        windowBg.setTheme(bgPrimHandle, bgTheme, 1.0, 1.0);
    end
end

function M.SetHidden(hidden)
    if hidden then
        M.HideMiniDisplay();
    end
end

function M.Cleanup()
    if bgPrimHandle then
        windowBg.destroy(bgPrimHandle);
        bgPrimHandle = nil;
    end

    loadedBgTheme = nil;
    iconCache = {};
end

return M;
