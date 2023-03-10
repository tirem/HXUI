require('common');
require('helpers');
local imgui = require('imgui');
local assetLoader = require('assetLoader');
local progressbar = require('progressbar');
local fonts = require('fonts');
local ffi = require("ffi");

local bgAlpha = 0.4;
local bgRadius = 3;

local arrowTexture;

local targetbar = {
	interpolation = {}
};

local _HXUI_DEV_DEBUG_INTERPOLATION = falsed;
local _HXUI_DEV_DEBUG_INTERPOLATION_DELAY = 1;
local _HXUI_DEV_DEBUG_HP_PERCENT_PERSISTENT = 100;
local _HXUI_DEV_DAMAGE_SET_TIMES = {};

targetbar.drawStatusIcons = function(player, playerEnt, playerTarget, targetEntity, targetIndex)

	local statusIds = gStatusLib.GetStatusIdsByIndex(targetIndex);
	if not statusIds then
		return;
	end

	local buffIds = {};
	local debuffIds = {};

	for i = 1, #statusIds do
		if statusIds[i] ~= -1 then
			if gStatusLib.helpers.GetIsBuff(statusIds[i]) then
				table.insert(buffIds, statusIds[i]);
			else
				gStatusLib.insert(debuffIds, statusIds[i]);
			end
		end
	end

	-- You can uncomment these for debug purposes, just make sure you comment out the above logic
	-- local buffIds = {253, 445, 198, 199};
	-- local debuffIds = {2, 6};

	local bgSize = {24, 28};
	local iconSize = {18, 18};

	local buffTopPadding = 7;
	local buffLeftPadding = 3;

	imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, {4, imgui.GetStyle().ItemSpacing.y});

	-- ==========
	-- Draw buffs
	-- ==========
	for i, buffId in ipairs(buffIds) do
		if i == 1 then
			imgui.SetCursorPosX(imgui.GetCursorPosX() + 10);
		end

		local iconStartX, iconStartY  = imgui.GetCursorScreenPos();

		local bgTexture = assetLoader.GetBackground(true);

		local iconTexture = gStatusLib.GetIconForStatusId(buffId, gConfig.statusIconTheme);

		imgui.Image(bgTexture, bgSize);

		imgui.GetWindowDrawList():AddImage(
			iconTexture,
			{
				iconStartX + buffLeftPadding,
				iconStartY + buffTopPadding;
			},
			{
				iconStartX + buffLeftPadding + iconSize[1],
				iconStartY + buffTopPadding + iconSize[2] 
			},
			{0, 0},
			{1, 1},
			IM_COL32_WHITE
		);

		if i < #buffIds then
			imgui.SameLine();
		end
	end

	local debuffTopPadding = 3;
	local debuffLeftPadding = 3;

	-- ==========
	-- Draw debuffs
	-- ==========
	for i, debuffId in ipairs(debuffIds) do
		if i == 1 then
			imgui.SetCursorPosX(imgui.GetCursorPosX() + 10);
		end

		local iconStartX, iconStartY = imgui.GetCursorScreenPos();

		local bgTexture = assetLoader.GetBackground(false);

		local iconTexture = gStatusLib.GetIconForStatusId(debuffId, gConfig.statusIconTheme);

		imgui.Image(bgTexture, bgSize);

		imgui.GetWindowDrawList():AddImage(
			iconTexture,
			{
				iconStartX + debuffLeftPadding,
				iconStartY + debuffTopPadding;
			},
			{
				iconStartX + debuffLeftPadding + iconSize[1],
				iconStartY + debuffTopPadding + iconSize[2] 
			},
			{0, 0},
			{1, 1},
			IM_COL32_WHITE
		);

		if i < #debuffIds  then
			imgui.SameLine();
		end
	end

	imgui.PopStyleVar(1);
end

targetbar.DrawWindow = function(settings)
    -- Obtain the player entity..
    local playerEnt = GetPlayerEntity();
	local player = AshitaCore:GetMemoryManager():GetPlayer();

    if (playerEnt == nil or player == nil) then
        return;
    end

    -- Obtain the player target entity (account for subtarget)
	local playerTarget = AshitaCore:GetMemoryManager():GetTarget();

	local targetIndex;
	local targetEntity;
	
	if (playerTarget ~= nil) then
		targetIndex, _ = gStatusLib.helpers.GetTargets();
		targetEntity = GetEntity(targetIndex);
	end

    if (targetEntity == nil or targetEntity.Name == nil) then
		targetbar.interpolation.interpolationDamagePercent = 0;

        return;
    end

	local currentTime = os.clock();

	local hppPercent = targetEntity.HPPercent;

	-- Mimic damage taken
	if _HXUI_DEV_DEBUG_INTERPOLATION then
		if _HXUI_DEV_DAMAGE_SET_TIMES[1] and currentTime > _HXUI_DEV_DAMAGE_SET_TIMES[1][1] then
			_HXUI_DEV_DEBUG_HP_PERCENT_PERSISTENT = _HXUI_DEV_DAMAGE_SET_TIMES[1][2];

			table.remove(_HXUI_DEV_DAMAGE_SET_TIMES, 1);
		end

		if #_HXUI_DEV_DAMAGE_SET_TIMES == 0 then
			local previousHitTime = currentTime + 1;
			local previousHp = 100;

			local totalDamageInstances = 10;

			for i = 1, totalDamageInstances do
				local hitDelay = math.random(0.25 * 100, 1.25 * 100) / 100;
				local damageAmount = math.random(1, 20);

				if i > 1 and i < totalDamageInstances then
					previousHp = math.max(previousHp - damageAmount, 0);
				end

				if i < totalDamageInstances then
					previousHitTime = previousHitTime + hitDelay;
				else
					previousHitTime = previousHitTime + _HXUI_DEV_DEBUG_INTERPOLATION_DELAY;
				end

				_HXUI_DEV_DAMAGE_SET_TIMES[i] = {previousHitTime, previousHp};
			end
		end

		hppPercent = _HXUI_DEV_DEBUG_HP_PERCENT_PERSISTENT;
	end

	-- If we change targets, reset the interpolation
	if targetbar.interpolation.currentTargetId ~= targetIndex then
		targetbar.interpolation.currentTargetId = targetIndex;
		targetbar.interpolation.currentHpp = hppPercent;
		targetbar.interpolation.interpolationDamagePercent = 0;
	end

	-- If the target takes damage
	if hppPercent < targetbar.interpolation.currentHpp then
		local previousInterpolationDamagePercent = targetbar.interpolation.interpolationDamagePercent;

		local damageAmount = targetbar.interpolation.currentHpp - hppPercent;

		targetbar.interpolation.interpolationDamagePercent = targetbar.interpolation.interpolationDamagePercent + damageAmount;

		if previousInterpolationDamagePercent > 0 and targetbar.interpolation.lastHitAmount and damageAmount > targetbar.interpolation.lastHitAmount then
			targetbar.interpolation.lastHitTime = currentTime;
			targetbar.interpolation.lastHitAmount = damageAmount;
		elseif previousInterpolationDamagePercent == 0 then
			targetbar.interpolation.lastHitTime = currentTime;
			targetbar.interpolation.lastHitAmount = damageAmount;
		end

		if not targetbar.interpolation.lastHitTime or currentTime > targetbar.interpolation.lastHitTime + (settings.hitFlashDuration * 0.25) then
			targetbar.interpolation.lastHitTime = currentTime;
			targetbar.interpolation.lastHitAmount = damageAmount;
		end

		-- If we previously were interpolating with an empty bar, reset the hit delay effect
		if previousInterpolationDamagePercent == 0 then
			targetbar.interpolation.hitDelayStartTime = currentTime;
		end
	elseif hppPercent > targetbar.interpolation.currentHpp then
		-- If the target heals
		targetbar.interpolation.interpolationDamagePercent = 0;
		targetbar.interpolation.hitDelayStartTime = nil;
	end

	targetbar.interpolation.currentHpp = hppPercent;

	-- Reduce the HP amount to display based on the time passed since last frame
	if targetbar.interpolation.interpolationDamagePercent > 0 and targetbar.interpolation.hitDelayStartTime and currentTime > targetbar.interpolation.hitDelayStartTime + settings.hitDelayDuration then
		if targetbar.interpolation.lastFrameTime then
			local deltaTime = currentTime - targetbar.interpolation.lastFrameTime;

			local animSpeed = 0.1 + (0.9 * (targetbar.interpolation.interpolationDamagePercent / 100));

			-- animSpeed = math.max(settings.hitDelayMinAnimSpeed, animSpeed);

			targetbar.interpolation.interpolationDamagePercent = targetbar.interpolation.interpolationDamagePercent - (settings.hitInterpolationDecayPercentPerSecond * deltaTime * animSpeed);

			-- Clamp our percent to 0
			targetbar.interpolation.interpolationDamagePercent = math.max(0, targetbar.interpolation.interpolationDamagePercent);
		end
	end

	if gConfig.healthBarFlashEnabled then
		if targetbar.interpolation.lastHitTime and currentTime < targetbar.interpolation.lastHitTime + settings.hitFlashDuration then
			local hitFlashTime = currentTime - targetbar.interpolation.lastHitTime;
			local hitFlashTimePercent = hitFlashTime / settings.hitFlashDuration;

			local maxAlphaHitPercent = 20;
			local maxAlpha = math.min(targetbar.interpolation.lastHitAmount, maxAlphaHitPercent) / maxAlphaHitPercent;

			maxAlpha = math.max(maxAlpha * 0.6, 0.4);

			targetbar.interpolation.overlayAlpha = math.pow(1 - hitFlashTimePercent, 2) * maxAlpha;
		end
	end

	targetbar.interpolation.lastFrameTime = currentTime;

	local color = GetColorOfTarget(targetEntity, targetIndex);
	local isMonster = GetIsMob(targetEntity);

	-- Draw the main target window
	local windowFlags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoBringToFrontOnFocus);

	windowFlags = bit.bor(windowFlags, ImGuiWindowFlags_NoBackground);

	if (gConfig.lockPositions) then
		windowFlags = bit.bor(windowFlags, ImGuiWindowFlags_NoMove);
	end

	imgui.SetNextWindowSize({settings.barWidth, -1});

	local mainWindowPosX, mainWindowPosY, mainWindowWidth;

    if (imgui.Begin('TargetBar', true, windowFlags)) then
		-- Obtain and prepare target information..
        local dist  = ('%.1f'):fmt(math.sqrt(targetEntity.Distance));
		local targetNameText = targetEntity.Name;
		local targetHpPercent = targetEntity.HPPercent..'%';

		if (gConfig.showEnemyId and isMonster) then
			local targetServerId = AshitaCore:GetMemoryManager():GetEntity():GetServerId(targetIndex);
			local targetServerIdHex = string.format('0x%X', targetServerId);

			targetNameText = targetNameText .. " [".. string.sub(targetServerIdHex, -3) .."]";
		end

		svgrenderer.text('targetbar_name', {text=targetNameText, size=18, color=getTargetGradient(targetEntity, targetIndex), marginX=10});

		imgui.SameLine();

		svgrenderer.text('targetbar_dist', {text=dist .. 'Y', size=18, color=HXUI_COL_WHITE, justify='right', marginX=10});

		local hpGradientStart = '#e26c6c';
		local hpGradientEnd = '#fb9494';

		local hpPercentData = {{targetEntity.HPPercent / 100, {hpGradientStart, hpGradientEnd}}};

		if _HXUI_DEV_DEBUG_INTERPOLATION then
			hpPercentData[1][1] = targetbar.interpolation.currentHpp / 100;
		end

		if targetbar.interpolation.interpolationDamagePercent > 0 then
			local interpolationOverlay;

			if gConfig.healthBarFlashEnabled then
				interpolationOverlay = {
					'#FFFFFF', -- overlay color,
					targetbar.interpolation.overlayAlpha -- overlay alpha,
				};
			end

			table.insert(
				hpPercentData,
				{
					targetbar.interpolation.interpolationDamagePercent / 100, -- interpolation percent
					{'#cf3437', '#c54d4d'},
					interpolationOverlay
				}
			);
		end
		
		progressbar.ProgressBar(hpPercentData, {-1, settings.barHeight}, {decorate = gConfig.showTargetBarBookends});

		if isMonster or gConfig.alwaysShowHealthPercent then
			local currentCursorPosX = imgui.GetCursorPosX();

			imgui.SetCursorPosY(imgui.GetCursorPosY() - 15);

			svgrenderer.text('targetbar_hpp', {text=string.format('%d%%', targetEntity.HPPercent), size=16, color=HXUI_COL_WHITE, justify='right', marginX=16});
			
			imgui.SameLine();

			imgui.SetCursorPosY(imgui.GetCursorPosY() + 15);

			imgui.SetCursorPosX(currentCursorPosX);
		end

		targetbar.drawStatusIcons(player, playerEnt, playerTarget, targetEntity, targetIndex);

		mainWindowPosX, mainWindowPosY = imgui.GetWindowPos();
		mainWindowWidth = imgui.GetWindowWidth();
    end
    
	imgui.End();

	local totEntity;
	local totIndex;

	if (targetEntity == playerEnt) then
		totIndex = targetIndex
		totEntity = targetEntity;
	end

	if (totEntity == nil) then
		totIndex = targetEntity.TargetedIndex;
		if (totIndex ~= nil) then
			totEntity = GetEntity(totIndex);
		end
	end

	if (totEntity ~= nil and totEntity.Name ~= nil) then
		local totWindowFlags = bit.bor(ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoBringToFrontOnFocus);

		totWindowFlags = bit.bor(totWindowFlags, ImGuiWindowFlags_NoBackground);

		imgui.SetNextWindowSize({settings.barWidth / 2, -1});

		imgui.SetNextWindowPos({mainWindowPosX + mainWindowWidth, mainWindowPosY});

		if (imgui.Begin('TargetOfTargetBar', true, totWindowFlags)) then
			imgui.BeginGroup();

			imgui.SetCursorPosY(imgui.GetCursorPosY() + 30);

			imgui.Image(tonumber(ffi.cast("uint32_t", arrowTexture.image)), {24, 24});

			imgui.EndGroup();

			imgui.SameLine();

			imgui.BeginGroup();

			svgrenderer.text('targetbar_tot_name', {text=totEntity.Name, size=18, color=getTargetGradient(targetEntity, targetIndex), marginX=10});

			local hpGradientStart = '#e26c6c';
			local hpGradientEnd = '#fb9494';

			local hpPercentData = {{totEntity.HPPercent / 100, {hpGradientStart, hpGradientEnd}}};

			progressbar.ProgressBar(hpPercentData, {-1, settings.barHeight}, {decorate = gConfig.showTargetBarBookends});

			imgui.EndGroup();
		end

		imgui.End();
	end
end

targetbar.Initialize = function(settings)
	arrowTexture = LoadTexture("arrow");
end

return targetbar;