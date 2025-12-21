--[[
* XIUI hotbar - Display Module
]]--

require('common');
require('handlers.helpers');
local imgui = require('imgui');
local ffi = require('ffi');
local d3d8 = require('d3d8');
local windowBg = require('libs.windowbackground');
local progressbar = require('libs.progressbar');
local button = require('libs.button');
local data = require('modules.hotbar.data');
local actions = require('modules.hotbar.actions');

local M = {};

-- ============================================
-- Constants
-- ============================================

local ICON_SIZE = 24;
local ROW_HEIGHT = 32;  -- Icon (24) + top offset (2) + gap (4) + bar (3) - 1
local PADDING = 8;
local ICON_TEXT_GAP = 6;
local ROW_SPACING = 4;
local BAR_HEIGHT = 3;

-- ============================================
-- State
-- ============================================

-- Background primitive handle
local bgPrimHandle = nil;

-- Theme tracking (for detecting changes like petbar)
local loadedBgTheme = nil;

-- Item icon cache (itemId -> texture table with .image)
local iconCache = {};

-- Tab state: 1 = Pool view, 2 = History view
local selectedTab = 1;

-- ============================================
-- Item Icon Loading
-- ============================================

-- ============================================
-- Helper Functions
-- ============================================

-- ============================================
-- History View Constants
-- ============================================


-- ============================================
-- Treasure Pool Window
-- ============================================



-- Helper to build a comma-separated list of names

local drawing = require('libs.drawing');

function M.DrawWindow(settings)
    -- Basic implementation: draw a square with text underneath

    -- Validate primitive
    if not bgPrimHandle then
        return;
    end

    -- Scales from config
    local scaleX = gConfig.hotbarScaleX or 1.0;
    local scaleY = gConfig.hotbarScaleY or 1.0;

    -- Dimensions
    local iconSize = math.floor(ICON_SIZE * scaleY);
    local padding = PADDING;
    local text = 'Hotbar';
    local textWidth = imgui.CalcTextSize(text) or 0;

    local contentWidth = iconSize + (padding * 2);
    local contentHeight = iconSize + 4 + imgui.GetTextLineHeight() + (padding * 2);

    --@TODO: 
    -- Position (default top-left offset). 
    local winX = 100;
    local winY = 100;

    -- Background options
    local bgTheme = gConfig.hotbarBackgroundTheme or 'Plain';
    local bgScale = gConfig.hotbarBgScale or 1.0;
    local borderScale = gConfig.hotbarBorderScale or 1.0;
    local bgOpacity = gConfig.hotbarBackgroundOpacity or 0.87;
    local borderOpacity = gConfig.hotbarBorderOpacity or 1.0;

    local bgOptions = {
        theme = bgTheme,
        padding = padding,
        paddingY = padding,
        bgScale = bgScale,
        borderScale = borderScale,
        bgOpacity = bgOpacity,
        borderOpacity = borderOpacity,
    };

    -- Update background primitive
    windowBg.update(bgPrimHandle, winX, winY, contentWidth, contentHeight, bgOptions);

    -- Draw the square and text using the appropriate draw list
    local drawList = drawing.GetUIDrawList();

    local squareLeft = winX + padding;
    local squareTop = winY + padding;
    local squareRight = squareLeft + iconSize;
    local squareBottom = squareTop + iconSize;

    -- Colors (simple neutral colors)
    local squareColor = imgui.GetColorU32({0.32, 0.45, 0.34, 1.0});
    local outlineColor = imgui.GetColorU32({0, 0, 0, 1.0});
    local textColor = imgui.GetColorU32({0.9, 0.9, 0.9, 1.0});

    -- Draw filled square and outline
    drawList:AddRectFilled({squareLeft, squareTop}, {squareRight, squareBottom}, squareColor, 4.0);
    drawList:AddRect({squareLeft, squareTop}, {squareRight, squareBottom}, outlineColor, 4.0, ImDrawCornerFlags_All, 1);

    -- Center text under square
    local centerX = squareLeft + (iconSize / 2);
    local textX = centerX - (textWidth / 2);
    local textY = squareBottom + 4;
    drawList:AddText({textX, textY}, textColor, text);
end

function M.HideWindow()
    if bgPrimHandle then
        windowBg.hide(bgPrimHandle);
    end
end

-- ============================================
-- Lifecycle
-- ============================================

function M.Initialize(settings)
    -- Get background theme and scales from config (with defaults)
    local bgTheme = gConfig.hotbarBackgroundTheme or 'Plain';
    local bgScale = gConfig.hotbarBgScale or 1.0;
    local borderScale = gConfig.hotbarBorderScale or 1.0;
    loadedBgTheme = bgTheme;

    -- Create background primitive (fonts created by init.lua)
    local primData = {
        visible = false,
        can_focus = false,
        locked = true,
        width = 100,
        height = 100,
    };
    bgPrimHandle = windowBg.create(primData, bgTheme, bgScale, borderScale);
end

function M.UpdateVisuals(settings)
    -- Check if theme changed
    local bgTheme = gConfig.hotbarBackgroundTheme or 'Plain';
    local bgScale = gConfig.hotbarBgScale or 1.0;
    local borderScale = gConfig.hotbarBorderScale or 1.0;
    if loadedBgTheme ~= bgTheme and bgPrimHandle then
        loadedBgTheme = bgTheme;
        windowBg.setTheme(bgPrimHandle, bgTheme, bgScale, borderScale);
    end
end

function M.SetHidden(hidden)
    if hidden then
        M.HideWindow();
    end
end

function M.Cleanup()
    if bgPrimHandle then
        windowBg.destroy(bgPrimHandle);
        bgPrimHandle = nil;
    end
end

return M;
