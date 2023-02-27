require('common');
require('helpers');
local imgui = require('imgui');
local fonts = require('fonts');
local progressbar = require('progressbar');
local buffTable = require('bufftable');

local resetPosNextFrame = false;

local playerbar = {};

local _HXUI_DEV_DEBUG_INTERPOLATION = false;
local _HXUI_DEV_DEBUG_INTERPOLATION_DELAY, _HXUI_DEV_DEBUG_INTERPOLATION_NEXT_TIME;

if _HXUI_DEV_DEBUG_INTERPOLATION then
	_HXUI_DEV_DEBUG_INTERPOLATION_DELAY = 2;
	_HXUI_DEV_DEBUG_INTERPOLATION_NEXT_TIME = os.time() + _HXUI_DEV_DEBUG_INTERPOLATION_DELAY;
end

local function UpdateTextVisibility(visible)
end

local nextCursorPos = nil;

playerbar.DrawWindow = function(settings)
    -- Obtain the player entity..
    local party = AshitaCore:GetMemoryManager():GetParty();
    local player = AshitaCore:GetMemoryManager():GetPlayer();
	local playerEnt = GetPlayerEntity();
	
	if (party == nil or player == nil or playerEnt == nil) then
		UpdateTextVisibility(false);
		return;
	end

	local currJob = player:GetMainJob();

    if (player.isZoning or currJob == 0) then
		UpdateTextVisibility(false);	
        return;
	end
	
	if (party == nil or player == nil) then
		return;
	end

	local SelfHP = party:GetMemberHP(0);
	local SelfHPMax = player:GetHPMax();
	local SelfHPPercent = math.clamp(party:GetMemberHPPercent(0), 0, 100);
	local SelfMP = party:GetMemberMP(0);
	local SelfMPMax = player:GetMPMax();
	local SelfMPPercent = math.clamp(party:GetMemberMPPercent(0), 0, 100);
	local SelfTP = party:GetMemberTP(0);

	local currentTime = os.clock();

    if playerbar.previousHPP then
    	if SelfHPPercent < playerbar.currentHPP then
    		playerbar.previousHPP = playerbar.currentHPP;
    		playerbar.currentHPP = SelfHPPercent;
    		playerbar.lastHitTime = currentTime;
    	end
    else
    	playerbar.currentHPP = SelfHPPercent;
    	playerbar.previousHPP = SelfHPPercent;
    end

    if _HXUI_DEV_DEBUG_INTERPOLATION then
	    if os.time() > _HXUI_DEV_DEBUG_INTERPOLATION_NEXT_TIME then
	    	playerbar.previousHPP = 75;
	    	playerbar.currentHPP = 50;
			playerbar.lastHitTime = currentTime;

			_HXUI_DEV_DEBUG_INTERPOLATION_NEXT_TIME = os.time() + 2;
	    end
	end

    local interpolationPercent;
    local interpolationOverlayAlpha = 0;

    if playerbar.currentHPP < playerbar.previousHPP then
    	local hppDelta = playerbar.previousHPP - playerbar.currentHPP;

    	if currentTime > playerbar.lastHitTime + settings.hitDelayLength then
    		-- local interpolationTimeTotal = settings.hitInterpolationMaxTime * (hppDelta / 100);
    		local interpolationTimeTotal = settings.hitInterpolationMaxTime;
    		local interpolationTimeElapsed = currentTime - playerbar.lastHitTime - settings.hitDelayLength;

    		if interpolationTimeElapsed <= interpolationTimeTotal then
    			local interpolationTimeElapsedPercent = easeOutPercent(interpolationTimeElapsed / interpolationTimeTotal);

    			interpolationPercent = hppDelta * (1 - interpolationTimeElapsedPercent);
    		end
    	elseif currentTime - playerbar.lastHitTime <= settings.hitDelayLength then
    		interpolationPercent = hppDelta;

			if gConfig.healthBarFlashEnabled then
				local hitDelayTime = currentTime - playerbar.lastHitTime;
				local hitDelayHalfDuration = settings.hitDelayLength / 2;

				if hitDelayTime > hitDelayHalfDuration then
					interpolationOverlayAlpha = 1 - ((hitDelayTime - hitDelayHalfDuration) / hitDelayHalfDuration);
				else
					interpolationOverlayAlpha = hitDelayTime / hitDelayHalfDuration;
				end
			end
    	end
    end

	-- Draw the player window
	if (resetPosNextFrame) then
		imgui.SetNextWindowPos({0,0});
		resetPosNextFrame = false;
	end
		
	local windowFlags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoBringToFrontOnFocus);

	if (gConfig.lockPositions) then
		windowFlags = bit.bor(windowFlags, ImGuiWindowFlags_NoMove);
	end

	local bShowMp = buffTable.IsSpellcaster(SelfJob) or buffTable.IsSpellcaster(SelfSubJob) or gConfig.alwaysShowMpBar;

	local SelfJob = GetJobStr(party:GetMemberMainJob(0));
	local SelfSubJob = GetJobStr(party:GetMemberSubJob(0));
	local bShowMp = buffTable.IsSpellcaster(SelfJob) or buffTable.IsSpellcaster(SelfSubJob) or gConfig.alwaysShowMpBar;

	local barCount = 2;

	if bShowMp then
		barCount = 3;
	end

	imgui.SetNextWindowSize({settings.barWidth, -1});

    if (imgui.Begin('PlayerBar', true, windowFlags)) then
		-- Horizontal center snapping
		--[[
		if imgui.IsMouseDragging(0) and imgui.IsWindowHovered() then
			local mousePosX, mousePosY = imgui.GetMousePos();
			local cursorPosX, cursorPosY = imgui.GetCursorScreenPos();
		
			local displayCenterX = imgui.GetIO().DisplaySize.x / 2;

			if math.abs((cursorPosX + (settings.barWidth / 2)) - displayCenterX) < 20 then
				imgui.SetWindowPos({displayCenterX - (settings.barWidth / 2), cursorPosY});
			end
		end
		]]--

		local hpNameColor, hpGradient = GetHpColors(SelfHPPercent/100);

		local hpX = imgui.GetCursorPosX();

		local hpPercentData = {{SelfHPPercent / 100, hpGradient}};

		if _HXUI_DEV_DEBUG_INTERPOLATION then
			hpPercentData[1][1] = 0.5;
		end

		if interpolationPercent then
			local interpolationOverlay;

			if gConfig.healthBarFlashEnabled then
				interpolationOverlay = {
					'#ffacae', -- overlay color,
					interpolationOverlayAlpha -- overlay alpha
				};
			end

			table.insert(
				hpPercentData,
				{
					interpolationPercent / 100, -- interpolation percent
					{'#cf3437', '#c54d4d'}, -- interpolation gradient
					interpolationOverlay
				}
			);
		end

		imgui.Columns(barCount, 'playerbar_columns', false);

		-- HP bar
		svgrenderer.text('playerbar_hp_label', 'HP', 12, HXUI_COL_WHITE, {marginX=10, delayDrawing=true});

		imgui.SetCursorPosY(imgui.GetCursorPosY() - 15);
		
		progressbar.ProgressBar(hpPercentData, {-1, settings.barHeight}, {decorate = gConfig.showPlayerBarBookends});

		svgrenderer.popDelayedDraws(1);

		imgui.SetCursorPosY(imgui.GetCursorPosY() - 15);

		svgrenderer.text('playerbar_hp_hpp', SelfHP, 16, HXUI_COL_WHITE, {justify='right', marginX=16});

		imgui.NextColumn();

		if bShowMp then
			-- MP bar
			svgrenderer.text('playerbar_mp_label', 'MP', 12, HXUI_COL_WHITE, {marginX=10, delayDrawing=true});

			imgui.SetCursorPosY(imgui.GetCursorPosY() - 15);
			
			progressbar.ProgressBar({{SelfMPPercent / 100, {'#9abb5a', '#bfe07d'}}}, {-1, settings.barHeight}, {decorate = gConfig.showPlayerBarBookends});

			svgrenderer.popDelayedDraws(1);

			imgui.SetCursorPosY(imgui.GetCursorPosY() - 15);

			svgrenderer.text('targetbar_mp_mpp', SelfMP, 16, HXUI_COL_WHITE, {justify='right', marginX=16});

			imgui.NextColumn();
		end

		-- TP bar
		svgrenderer.text('playerbar_tp_label', 'TP', 12, HXUI_COL_WHITE, {marginX=10, delayDrawing=true});

		imgui.SetCursorPosY(imgui.GetCursorPosY() - 15);

		local tpGradient = {'#3898ce', '#78c4ee'};
		local mainPercent;
		local tpOverlay;
		
		if (SelfTP >= 1000) then
			mainPercent = (SelfTP - 1000) / 2000;

			local tpOverlayGradient = {'#0078CC', '#0078CC'};

			tpOverlay = {
				{
					1, -- overlay percent
					tpOverlayGradient -- overlay gradient
				},
				math.ceil(settings.barHeight * 2/7), -- overlay height
				1, -- overlay vertical padding
				{
					'#2fa9ff', -- overlay pulse color
					1 -- overlay pulse seconds
				}
			};
		else
			mainPercent = SelfTP / 1000;
		end
		
		progressbar.ProgressBar({{mainPercent, tpGradient}}, {-1, settings.barHeight}, {overlayBar=tpOverlay, decorate = gConfig.showPlayerBarBookends});

		svgrenderer.popDelayedDraws(1);

		imgui.SetCursorPosY(imgui.GetCursorPosY() - 15);

		svgrenderer.text('targetbar_tp_tpp', SelfTP, 16, HXUI_COL_WHITE, {justify='right', marginX=16});

		imgui.NextColumn();

		imgui.Columns(1);
    end

	imgui.End();
end


playerbar.Initialize = function(settings)
end

playerbar.UpdateFonts = function(settings)
end

playerbar.SetHidden = function(hidden)
end

return playerbar;