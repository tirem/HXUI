require('common');
local imgui = require('imgui');
local progressbar = require('progressbar');

local expbar = {};

function addCommas(amount)
	local formatted = amount;

	while true do  
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2');

		if (k==0) then
			break;
		end
	end

	return formatted;
end

expbar.DrawWindow = function(settings)
    -- Obtain the player entity..
    local player = AshitaCore:GetMemoryManager():GetPlayer();

	if (player == nil) then
		return;
	end

	local mainJob = player:GetMainJob();
	local jobLevel = player:GetMainJobLevel();
	local subJob = player:GetSubJob();
	local subJobLevel = player:GetSubJobLevel();
	local currentExp = player:GetExpCurrent();
	local totalExp = player:GetExpNeeded();

    imgui.SetNextWindowSize({ settings.barWidth, -1, }, ImGuiCond_Always);

	local windowFlags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoBringToFrontOnFocus);

	if (gConfig.lockPositions) then
		windowFlags = bit.bor(windowFlags, ImGuiWindowFlags_NoMove);
	end

    if (imgui.Begin('ExpBar', true, windowFlags)) then
		local expPercent = currentExp / totalExp;

		svgrenderer.text('expbar_label', 'EXP', 12, HXUI_COL_WHITE, {marginX=10, delayDrawing=true, static=true});

		imgui.SetCursorPosY(imgui.GetCursorPosY() - 13);

		progressbar.ProgressBar({{expPercent, {'#c39040', '#e9c466'}}}, {-1, settings.barHeight}, {decorate = gConfig.showExpBarBookends});

		svgrenderer.popDelayedDraws(1);

		local jobString = string.format('%s %d', AshitaCore:GetResourceManager():GetString("jobs.names_abbr", mainJob), jobLevel);

		imgui.SetCursorPosY(imgui.GetCursorPosY() - 3);

		if subJobLevel > 0 then
			jobString = string.format('%s / %s %d', jobString, AshitaCore:GetResourceManager():GetString("jobs.names_abbr", subJob), subJobLevel);
		end

		svgrenderer.text('expbar_job', jobString, 14, HXUI_COL_WHITE, {marginX=2});

		imgui.SameLine();

		local xpString = string.format('%s / %s', addCommas(currentExp), addCommas(totalExp));

		svgrenderer.text('expbar_xp', xpString, 14, HXUI_COL_WHITE, {justify='right', marginX=2});
    end

	imgui.End();
end

expbar.Initialize = function(settings)
end

return expbar;