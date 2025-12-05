--[[
* ImGui Compatibility Layer for Ashita v4beta
*
* This module provides compatibility between the current Ashita v4beta (main)
* and the upcoming Ashita 4.3 (2025_q3_update branch) which has breaking ImGui changes.
*
* Set _XIUI_USE_ASHITA_4_3 = true in XIUI.lua to enable 4.3 mode.
*
* Changes in 4.3:
*   - BeginChild: cflags default changed, now needs explicit ImGuiChildFlags_Borders
*   - PushStyleColor: idx param no longer optional, nil check needed
*   - ImGuiCol_Tab* constants renamed (TabActive -> TabSelected, etc.)
*   - ImDrawCornerFlags renamed to ImDrawFlags_RoundCorners*
]]--

local imgui = require('imgui');

-- Store original functions
local orig_imgui_BeginChild = imgui.BeginChild;
local orig_imgui_PushStyleColor = imgui.PushStyleColor;

-- Check if we're targeting Ashita 4.3 or main branch
-- This global should be set in XIUI.lua before requiring this module
local use43 = rawget(_G, '_XIUI_USE_ASHITA_4_3') or false;

-- ImDrawCornerFlags -> ImDrawFlags_RoundCorners* aliases (both branches use new naming)
-- These old names were used in older ImGui versions but Ashita uses the new names
ImDrawCornerFlags_None = ImDrawFlags_RoundCornersNone;
ImDrawCornerFlags_TopLeft = ImDrawFlags_RoundCornersTopLeft;
ImDrawCornerFlags_TopRight = ImDrawFlags_RoundCornersTopRight;
ImDrawCornerFlags_BotLeft = ImDrawFlags_RoundCornersBottomLeft;
ImDrawCornerFlags_BotRight = ImDrawFlags_RoundCornersBottomRight;
ImDrawCornerFlags_Top = ImDrawFlags_RoundCornersTop;
ImDrawCornerFlags_Bot = ImDrawFlags_RoundCornersBottom;
ImDrawCornerFlags_Left = ImDrawFlags_RoundCornersLeft;
ImDrawCornerFlags_Right = ImDrawFlags_RoundCornersRight;
ImDrawCornerFlags_All = ImDrawFlags_RoundCornersAll;

if use43 then
    -- Running on 4.3 branch - add backwards compatibility aliases for old constant names
    -- These were renamed in ImGui 1.90+
    if ImGuiCol_TabSelected ~= nil then
        ImGuiCol_TabActive = ImGuiCol_TabSelected;
        ImGuiCol_TabUnfocused = ImGuiCol_TabDimmed;
        ImGuiCol_TabUnfocusedActive = ImGuiCol_TabDimmedSelected;
    end

    -- BeginChild: Handle boolean->flags conversion for backwards compat
    imgui.BeginChild = function(id, size, cflags, wflags)
        if cflags == true then
            cflags = ImGuiChildFlags_Borders;
        elseif cflags == false then
            cflags = ImGuiChildFlags_None;
        end
        return orig_imgui_BeginChild(id, size, cflags, wflags);
    end

else
    -- Running on MAIN branch - apply compatibility shims for 4.3-style code

    -- BeginChild: 4.3 changed default cflags behavior
    -- On main, true = ImGuiChildFlags_Borders, on 4.3 it's more explicit
    imgui.BeginChild = function(id, size, cflags, wflags)
        return orig_imgui_BeginChild(id, size, cflags == true and ImGuiChildFlags_Borders or ImGuiChildFlags_None, wflags);
    end

    -- PushStyleColor: 4.3 requires idx to not be nil
    imgui.PushStyleColor = function(idx, col)
        if (idx == nil) then return; end
        orig_imgui_PushStyleColor(idx, col);
    end

end

-- Return module info for debugging
return {
    version = '1.0.0',
    mode = use43 and '4.3' or 'main',
    description = 'ImGui compatibility layer for Ashita v4beta main/4.3'
};
