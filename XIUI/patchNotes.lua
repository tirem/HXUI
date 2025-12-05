require('common');
local imgui = require('imgui');
local ffi = require('ffi');

local XIUITexture;
local PatchVerTexture;
local NewTexture;
gShowPatchNotes = { true };

local patchNotes = {};

local function InitializeTextures()
	if (XIUITexture == nil) then
		XIUITexture = LoadTexture("patchNotes/xiui");
	end
	if (PatchVerTexture == nil) then
		PatchVerTexture = LoadTexture("patchNotes/patch");
	end
	if (NewTexture == nil) then
		NewTexture = LoadTexture("patchNotes/new");
	end
end

--[[
* event: d3d_present
* desc : Event called when the Direct3D device is presenting a scene.
--]]
patchNotes.DrawWindow = function()
	-- Early exit if patch notes window isn't shown
	if (not gShowPatchNotes[1]) then
		XIUITexture = nil;
		PatchVerTexture = nil;
		NewTexture = nil;
		gConfig.patchNotesVer = gAdjustedSettings.currentPatchVer;
		UpdateSettings();
		return;
	end

	if (XIUITexture == nil or PatchVerTexture == nil or NewTexture == nil) then
		InitializeTextures();
	end
	if (XIUITexture == nil or PatchVerTexture == nil or NewTexture == nil) then
		return;
	end

	imgui.PushStyleColor(ImGuiCol_WindowBg, {0,0.06,.16,.9});
	imgui.PushStyleColor(ImGuiCol_TitleBg, {0,0.06,.16, .7});
	imgui.PushStyleColor(ImGuiCol_TitleBgActive, {0,0.06,.16, .9});
	imgui.PushStyleColor(ImGuiCol_TitleBgCollapsed, {0,0.06,.16, .5});
	imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 8, 6 });
	if (imgui.Begin('XIUI PatchNotes', gShowPatchNotes, bit.bor(ImGuiWindowFlags_NoSavedSettings, ImGuiWindowFlags_NoDocking))) then
		-- Save starting Y position for button alignment
		local startY = imgui.GetCursorPosY();

		-- Draw logo and version text
		imgui.Image(tonumber(ffi.cast("uint32_t", XIUITexture.image)), { 83, 53});
		imgui.SameLine();
		imgui.BulletText('UPDATE 1.5.0');
		imgui.SameLine();
		imgui.BulletText('');

		local buttonWidth = 120;
		local buttonHeight = 30;
		local imageHeight = 53;
		-- Use GetContentRegionAvail + GetCursorPosX to calculate max X position
		local contentAvail = imgui.GetContentRegionAvail();
		local cursorX = imgui.GetCursorPosX();
		local buttonX = cursorX + contentAvail - buttonWidth;
		local buttonY = startY + (imageHeight - buttonHeight) / 2;

		imgui.SetCursorPos({ buttonX, buttonY });
		if(imgui.Button("Open Config", { buttonWidth, buttonHeight })) then
			showConfig[1] = true;
			gShowPatchNotes[1] = false;
		end

		imgui.NewLine();
		imgui.TextColored({0.4, 0.8, 1.0, 1.0}, 'Performance Improvements');
		imgui.BulletText('Major enemy list performance optimizations - fixed O(n) bottlenecks');
		imgui.BulletText('Party list rendering performance improvements');
		imgui.BulletText('Reduced memory allocations and garbage collection pressure');
		imgui.BulletText('Optimized debuff handler with caching');
		imgui.NewLine();
		imgui.TextColored({0.4, 0.8, 1.0, 1.0}, 'New Features');
		imgui.BulletText('Per-party color settings - customize colors for each party');
		imgui.BulletText('Per-party display settings - show/hide elements per party');
		imgui.BulletText('HP gradient enabled by default');
		imgui.BulletText('Color interpolation configuration');
		imgui.BulletText('Castbar accuracy improvements for self and party members');
		imgui.NewLine();
		imgui.TextColored({0.4, 0.8, 1.0, 1.0}, 'UI Improvements');
		imgui.BulletText('Redesigned config menu with new layout');
		imgui.BulletText('Added Discord and GitHub links to config');
	end
	imgui.End();
	imgui.PopStyleVar(1);
	imgui.PopStyleColor(4);
end

return patchNotes;