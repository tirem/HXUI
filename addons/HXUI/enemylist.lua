require('common');
require('helpers');
local imgui = require('imgui');
local progressbar = require('progressbar');

-- TODO: Calculate these instead of manually setting them
local bgAlpha = 0.4;
local bgRadius = 3;
local enemylist = {};

local function GetIsValidMob(mobIdx)
	-- Check if we are valid, are above 0 hp, and are rendered

    local renderflags = AshitaCore:GetMemoryManager():GetEntity():GetRenderFlags0(mobIdx);
    if bit.band(renderflags, 0x200) ~= 0x200 or bit.band(renderflags, 0x4000) ~= 0 then
        return false;
    end
	return true;
end

enemylist.DrawWindow = function(settings)

	imgui.SetNextWindowSize({ settings.barWidth, -1, }, ImGuiCond_Always);
	-- Draw the main target window
	local windowFlags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoBringToFrontOnFocus);
	if (gConfig.lockPositions) then
		windowFlags = bit.bor(windowFlags, ImGuiWindowFlags_NoMove);
	end
	if (imgui.Begin('EnemyList', true, windowFlags)) then
		imgui.SetWindowFontScale(settings.textScale);
		local winStartX, _ = imgui.GetWindowPos();
		local playerTarget = AshitaCore:GetMemoryManager():GetTarget();
		local targetIndex;
		local subTargetIndex;
		local subTargetActive = false;
		if (playerTarget ~= nil) then
			subTargetActive = GetSubTargetActive();
			targetIndex, subTargetIndex = gStatusLib.helpers.GetTargets();
			if (subTargetActive) then
				local tempTarget = targetIndex;
				targetIndex = subTargetIndex;
				subTargetIndex = tempTarget;
			end
		end
		
		local numTargets = 0;
		for k,v in pairs(gStatusLib.GetRelevantEnemies()) do
			local ent = GetEntity(k);
			if (v ~= nil and ent ~= nil and GetIsValidMob(k)) then
				-- Obtain and prepare target information..
				local targetNameText = ent.Name;
				if (targetNameText ~= nil) then

					local color = GetColorOfTargetRGBA(ent, k);
					imgui.Dummy({0,settings.entrySpacing});
					local rectLength = imgui.GetColumnWidth() + imgui.GetStyle().FramePadding.x;
					
					-- draw background to entry
					local winX, winY  = imgui.GetCursorScreenPos();

					-- Figure out sizing on the background
					local cornerOffset = settings.bgTopPadding;
					local _, yDist = imgui.CalcTextSize(targetNameText);
					if (yDist > settings.barHeight) then
						yDist = yDist + yDist;
					else
						yDist = yDist + settings.barHeight;
					end

					draw_rect({winX + cornerOffset , winY + cornerOffset}, {winX + rectLength, winY + yDist + settings.bgPadding}, {0,0,0,bgAlpha}, bgRadius, true);

					-- Draw outlines for our target and subtarget
					if (subTargetIndex ~= nil and k == subTargetIndex) then
						draw_rect({winX + cornerOffset, winY + cornerOffset}, {winX + rectLength - 1, winY + yDist + settings.bgPadding}, {.5,.5,1,1}, bgRadius, false);
					elseif (targetIndex ~= nil and k == targetIndex) then
						draw_rect({winX + cornerOffset, winY + cornerOffset}, {winX + rectLength - 1, winY + yDist + settings.bgPadding}, {1,1,1,1}, bgRadius, false);
					end

					-- Display the targets information..
					imgui.TextColored(color, targetNameText);
					local percentText  = ('%.f'):fmt(ent.HPPercent);
					local x, _  = imgui.CalcTextSize(percentText);
					local fauxX, _  = imgui.CalcTextSize('100');

					-- Draw buffs and debuffs
					local buffIds = gStatusLib.GetStatusIdsByIndex(k);
					if (buffIds ~= nil and #buffIds > 0) then
						imgui.SetNextWindowPos({winStartX + settings.barWidth + settings.debuffOffsetX, winY + settings.debuffOffsetY});
						if (imgui.Begin('EnemyDebuffs'..k, true, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoSavedSettings))) then
							imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, {1, 1});
							DrawStatusIcons(buffIds, settings.iconSize, settings.maxIcons, 1);
							imgui.PopStyleVar(1);
						end 
						imgui.End();
					end

					imgui.SetCursorPosX(imgui.GetCursorPosX() + fauxX - x);
					imgui.Text(percentText);
					imgui.SameLine();
					imgui.SetCursorPosX(imgui.GetCursorPosX() - 3);
					-- imgui.ProgressBar(ent.HPPercent / 100, { -1, settings.barHeight}, '');
					progressbar.ProgressBar({{ent.HPPercent / 100, {'#e16c6c', '#fb9494'}}}, {-1, settings.barHeight}, {decorate = gConfig.showEnemyListBookends});
					imgui.SameLine();

					imgui.Separator();

					numTargets = numTargets + 1;
					if (numTargets >= gConfig.maxEnemyListEntries) then
						break;
					end
				end
			end
		end
	end
	imgui.End();
end

return enemylist;