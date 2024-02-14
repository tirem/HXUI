require('common');
local imgui = require('imgui');
local fonts = require('fonts');
local progressbar = require('progressbar');

local jobText;
local expText;
local percentText;

local expbar = {};

local function UpdateTextVisibility(visible)
	jobText:SetVisible(visible);
	expText:SetVisible(visible);
	percentText:SetVisible(visible);
end

--[[
* event: d3d_present
* desc : Event called when the Direct3D device is presenting a scene.
--]]
expbar.DrawWindow = function(settings)
    -- Obtain the player entity..
    local player    = AshitaCore:GetMemoryManager():GetPlayer();

	if (player == nil) then
		UpdateTextVisibility(false);
		return;
	end

	local mainJob = player:GetMainJob();

    if (player.isZoning or mainJob == 0) then
		UpdateTextVisibility(false);
        return;
	end

    local jobLevel = player:GetMainJobLevel();
    local subJob = player:GetSubJob();
    local subJobLevel = player:GetSubJobLevel();
    local currentExp = player:GetExpCurrent();
    local totalExp = player:GetExpNeeded();

    local inlineMode = gConfig.expBarInlineMode;
    local windowSize = inlineMode and settings.barWidth * 2 + imgui.GetStyle().FramePadding.x * 2 or settings.barWidth;

    imgui.SetNextWindowSize({ windowSize, -1 }, ImGuiCond_Always);
	local windowFlags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoBringToFrontOnFocus);
	if (gConfig.lockPositions) then
		windowFlags = bit.bor(windowFlags, ImGuiWindowFlags_NoMove);
	end
    if (imgui.Begin('ExpBar', true, windowFlags)) then

		-- Draw HP Bar
		local expPercent = currentExp / totalExp;
		local startX, startY = imgui.GetCursorScreenPos();
        local col2X = startX + settings.barWidth - imgui.GetStyle().FramePadding.x * 2;

        local progressBarWidth = -1;
        if inlineMode then
            progressBarWidth = settings.barWidth;
            imgui.SetCursorScreenPos({col2X, startY});
        end
		progressbar.ProgressBar({{expPercent, {'#c39040', '#e9c466'}}}, {progressBarWidth, settings.barHeight}, {decorate = gConfig.showExpBarBookends});

		imgui.SameLine();

        local textY = inlineMode and startY or startY + settings.barHeight + settings.textOffsetY;
        local textXRightAlign = startX + settings.barWidth - imgui.GetStyle().FramePadding.x * 4;

		-- Update our text objects

        if gConfig.expBarShowText then
            -- Job Text
            local mainJobString = AshitaCore:GetResourceManager():GetString('jobs.names_abbr', mainJob);
            local subJobString = AshitaCore:GetResourceManager():GetString('jobs.names_abbr', subJob);
            local jobString = mainJobString .. ' ' .. jobLevel .. ' / ' .. subJobString .. ' ' .. subJobLevel;
            jobText:SetText(jobString);
            local textW, textH = jobText:get_text_size();
            jobText:SetPositionX(startX);
            jobText:SetPositionY(inlineMode and textY + (settings.barHeight - textH) / 2 or textY); -- - jobText:GetFontHeight() / 2.5);

            -- Exp Text
            local expString = 'EXP ('..currentExp..' / '..totalExp..')';
            expText:SetText(expString);
            local textW, textH = expText:get_text_size();
            expText:SetPositionX(textXRightAlign);
            expText:SetPositionY(inlineMode and textY + (settings.barHeight - textH) / 2 or textY); -- - expText:GetFontHeight() / 2.5);

            jobText:SetVisible(true);
            expText:SetVisible(true);
        else
            jobText:SetText('');
            jobText:SetVisible(false);
            expText:SetText('');
            expText:SetVisible(false);
        end

        -- Percent Text
        if gConfig.expBarShowPercent then
            local expPercentString = ('%.f'):fmt(1 * 100);
            local percentString = 'EXP - '..expPercentString..'%';
            percentText:SetText(percentString);
            local textW, textH = percentText:get_text_size();
            local percentTextX = inlineMode and startX + windowSize or textXRightAlign;
            local percentTextY = inlineMode and textY + (settings.barHeight - textH) / 2 or startY - settings.textOffsetY;
            percentText:SetAnchor(inlineMode and 0 or 2);
            percentText:SetPositionX(percentTextX + settings.percentOffsetX);
            percentText:SetPositionY(percentTextY);
            percentText:SetRightJustified(settings.percent_font_settings.right_justified and not inlineMode);

            percentText:SetVisible(true);
        else
            percentText:SetText('');
            percentText:SetVisible(false);
        end

    end
	imgui.End();
end


expbar.Initialize = function(settings)
    jobText = fonts.new(settings.job_font_settings);
	expText = fonts.new(settings.exp_font_settings);
	percentText = fonts.new(settings.percent_font_settings);
end

expbar.UpdateFonts = function(settings)
    jobText:SetFontHeight(settings.job_font_settings.font_height);
	expText:SetFontHeight(settings.exp_font_settings.font_height);
	percentText:SetFontHeight(settings.percent_font_settings.font_height);
end

expbar.SetHidden = function(hidden)
	if (hidden == true) then
		UpdateTextVisibility(false);
	end
end

return expbar;