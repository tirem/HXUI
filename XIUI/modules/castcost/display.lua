--[[
* XIUI Cast Cost Display Layer
* Handles rendering of cast cost information with GDI fonts and window backgrounds
]]--

require('common');
require('handlers.helpers');
local imgui = require('imgui');
local gdi = require('submodules.gdifonts.include');
local windowBg = require('libs.windowbackground');

local M = {};

-- Font handles
local nameFont;
local costFont;
local timeFont;
local allFonts;

-- Background handle
local bgHandle;

-- Cached colors (avoid expensive set_font_color calls)
local lastNameColor;
local lastCostColor;
local lastTimeColor;

-- ============================================
-- Initialization
-- ============================================

function M.Initialize(settings)
    -- Create fonts via FontManager
    nameFont = FontManager.create(settings.name_font_settings);
    costFont = FontManager.create(settings.cost_font_settings);
    timeFont = FontManager.create(settings.time_font_settings);
    allFonts = { nameFont, costFont, timeFont };

    -- Create window background
    bgHandle = windowBg.create(settings.prim_data, settings.backgroundTheme or 'Window1', settings.bgScale or 1.0);
end

-- ============================================
-- Update Visuals (font/theme changes)
-- ============================================

function M.UpdateVisuals(settings)
    -- Recreate fonts when family/weight changes
    nameFont = FontManager.recreate(nameFont, settings.name_font_settings);
    costFont = FontManager.recreate(costFont, settings.cost_font_settings);
    timeFont = FontManager.recreate(timeFont, settings.time_font_settings);
    allFonts = { nameFont, costFont, timeFont };

    -- Reset cached colors
    lastNameColor = nil;
    lastCostColor = nil;
    lastTimeColor = nil;

    -- Update background theme
    if bgHandle then
        windowBg.setTheme(bgHandle, settings.backgroundTheme or 'Window1', settings.bgScale or 1.0);
    end
end

-- ============================================
-- Visibility Control
-- ============================================

function M.SetHidden(hidden)
    SetFontsVisible(allFonts, not hidden);
    if bgHandle then
        windowBg.hide(bgHandle);
    end
end

-- ============================================
-- Cleanup
-- ============================================

function M.Cleanup()
    nameFont = FontManager.destroy(nameFont);
    costFont = FontManager.destroy(costFont);
    timeFont = FontManager.destroy(timeFont);
    allFonts = nil;

    if bgHandle then
        windowBg.destroy(bgHandle);
        bgHandle = nil;
    end
end

-- ============================================
-- Rendering Helpers
-- ============================================

local function formatTime(seconds)
    if seconds == nil or seconds <= 0 then return ''; end
    if seconds >= 60 then
        local mins = math.floor(seconds / 60);
        local secs = seconds % 60;
        return string.format('%dm %ds', mins, secs);
    end
    return string.format('%ds', seconds);
end

-- ============================================
-- Main Render Function
-- ============================================

function M.Render(itemInfo, itemType, settings, colors)
    if itemInfo == nil then
        SetFontsVisible(allFonts, false);
        if bgHandle then
            windowBg.hide(bgHandle);
        end
        return;
    end

    -- Build display strings based on item type
    local nameText = itemInfo.name or '';
    local costText = '';
    local timeText = '';

    if itemType == 'spell' then
        -- Spell: Show MP cost, cast time, recast
        if settings.showMpCost and itemInfo.mpCost and itemInfo.mpCost > 0 then
            costText = string.format('MP: %d', itemInfo.mpCost);
        end
        local timeParts = {};
        if settings.showCastTime and itemInfo.castTime and itemInfo.castTime > 0 then
            -- Cast time is in 1/4 seconds
            local castSeconds = itemInfo.castTime / 4;
            table.insert(timeParts, string.format('Cast: %.1fs', castSeconds));
        end
        if settings.showRecast and itemInfo.recastDelay and itemInfo.recastDelay > 0 then
            table.insert(timeParts, string.format('Recast: %s', formatTime(itemInfo.recastDelay)));
        end
        timeText = table.concat(timeParts, '  ');

    elseif itemType == 'ability' then
        -- Ability: Show recast
        if settings.showRecast and itemInfo.recastDelay and itemInfo.recastDelay > 0 then
            timeText = string.format('Recast: %s', formatTime(itemInfo.recastDelay));
        end

    elseif itemType == 'mount' then
        -- Mount: Just show name
        -- No additional info needed
    end

    -- Set up ImGui window
    imgui.SetNextWindowSize({ -1, -1 }, ImGuiCond_Always);
    local windowFlags = bit.bor(
        ImGuiWindowFlags_NoDecoration,
        ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoFocusOnAppearing,
        ImGuiWindowFlags_NoNav,
        ImGuiWindowFlags_NoBackground,
        ImGuiWindowFlags_NoBringToFrontOnFocus,
        ImGuiWindowFlags_NoDocking
    );
    if gConfig.lockPositions then
        windowFlags = bit.bor(windowFlags, ImGuiWindowFlags_NoMove);
    end

    if imgui.Begin('CastCost', true, windowFlags) then
        local cursorX, cursorY = imgui.GetCursorScreenPos();

        -- Calculate content dimensions
        nameFont:set_font_height(settings.name_font_settings.font_height);
        nameFont:set_text(nameText);
        local nameWidth, nameHeight = nameFont:get_text_size();

        costFont:set_font_height(settings.cost_font_settings.font_height);
        costFont:set_text(costText);
        local costWidth, costHeight = costFont:get_text_size();
        if costText == '' then costWidth, costHeight = 0, 0; end

        timeFont:set_font_height(settings.time_font_settings.font_height);
        timeFont:set_text(timeText);
        local timeWidth, timeHeight = timeFont:get_text_size();
        if timeText == '' then timeWidth, timeHeight = 0, 0; end

        -- Calculate total content size
        local lineSpacing = 2;
        local contentWidth = math.max(nameWidth, costWidth, timeWidth);
        local contentHeight = nameHeight;
        if costHeight > 0 then
            contentHeight = contentHeight + lineSpacing + costHeight;
        end
        if timeHeight > 0 then
            contentHeight = contentHeight + lineSpacing + timeHeight;
        end

        -- Minimum size for background
        contentWidth = math.max(contentWidth, 100);

        -- Create dummy for dragging
        local padding = settings.bgPadding or 8;
        local paddingY = settings.bgPaddingY or padding;
        imgui.Dummy({ contentWidth, contentHeight });

        -- Update background
        if bgHandle then
            windowBg.update(bgHandle, cursorX, cursorY, contentWidth, contentHeight, {
                theme = settings.backgroundTheme or 'Window1',
                padding = padding,
                paddingY = paddingY,
                bgScale = settings.bgScale or 1.0,
                bgOpacity = settings.backgroundOpacity or 1.0,
                bgColor = colors.bgColor or 0xFFFFFFFF,
                borderSize = settings.borderSize or 21,
                bgOffset = settings.bgOffset or 1,
                borderOpacity = settings.borderOpacity or 1.0,
                borderColor = colors.borderColor or 0xFFFFFFFF,
            });
        end

        -- Position and render fonts
        local yPos = cursorY;

        -- Name
        nameFont:set_position_x(cursorX);
        nameFont:set_position_y(yPos);
        if lastNameColor ~= colors.nameTextColor then
            nameFont:set_font_color(colors.nameTextColor or 0xFFFFFFFF);
            lastNameColor = colors.nameTextColor;
        end
        yPos = yPos + nameHeight + lineSpacing;

        -- Cost (if present)
        if costText ~= '' then
            costFont:set_position_x(cursorX);
            costFont:set_position_y(yPos);
            local costColor = colors.mpCostTextColor or colors.tpCostTextColor or 0xFFD4FF97;
            if lastCostColor ~= costColor then
                costFont:set_font_color(costColor);
                lastCostColor = costColor;
            end
            yPos = yPos + costHeight + lineSpacing;
        end

        -- Time info (if present)
        if timeText ~= '' then
            timeFont:set_position_x(cursorX);
            timeFont:set_position_y(yPos);
            if lastTimeColor ~= colors.timeTextColor then
                timeFont:set_font_color(colors.timeTextColor or 0xFFCCCCCC);
                lastTimeColor = colors.timeTextColor;
            end
        end

        -- Show fonts
        nameFont:set_visible(true);
        costFont:set_visible(costText ~= '');
        timeFont:set_visible(timeText ~= '');
    end
    imgui.End();
end

return M;
