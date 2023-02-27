require('common');
local imgui = require('imgui');
local fonts = require('fonts');
local progressbar = require('progressbar');

local castbar = {
	previousPercent = 0,
	currentSpellId = nil,
	currentItemId = nil,
};

castbar.GetSpellName = function(spellId)
	return AshitaCore:GetResourceManager():GetSpellById(spellId).Name[1];
end

castbar.GetItemName = function(itemId)
	return AshitaCore:GetResourceManager():GetItemById(itemId).Name[1];
end

castbar.GetLabelText = function()
	if (castbar.currentSpellId) then
		return castbar.GetSpellName(castbar.currentSpellId);
	elseif (castbar.currentItemId) then
		return castbar.GetItemName(castbar.currentItemId)
	else
		return '';
	end
end

castbar.DrawWindow = function(settings)
	local percent = AshitaCore:GetMemoryManager():GetCastBar():GetPercent();

	if ((percent < 1 and percent ~= castbar.previousPercent) or showConfig[1]) then
		imgui.SetNextWindowSize({settings.barWidth, -1});

		local windowFlags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoBringToFrontOnFocus);

		if (gConfig.lockPositions) then
			windowFlags = bit.bor(windowFlags, ImGuiWindowFlags_NoMove);
		end

		if (imgui.Begin('CastBar', true, windowFlags)) then
			progressbar.ProgressBar({{showConfig[1] and 0.5 or percent, {'#3798ce', '#78c5ee'}}}, {-1, settings.barHeight}, {decorate = gConfig.showCastBarBookends});

			imgui.SetCursorPosY(imgui.GetCursorPosY() - 15);

			local labelString = showConfig[1] and 'Configuration Mode' or castbar.GetLabelText();

			svgrenderer.text('castbar_label', labelString, 14, HXUI_COL_WHITE, {marginX=7});

			imgui.SameLine();

			local percentString = showConfig[1] and '50%' or math.floor(percent * 100) .. '%';

			svgrenderer.text('castbar_percent', percentString, 14, HXUI_COL_WHITE, {justify='right', marginX=7});
		end

		imgui.End();
	end

	castbar.previousPercent = percent;
end

castbar.UpdateFonts = function(settings)
end

castbar.SetHidden = function(hidden)
end

castbar.Initialize = function(settings)
end

castbar.HandleActionPacket = function(actionPacket)
	local localPlayerId = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0);

	-- We only care about:
	-- - Actions originating from the player
	-- - Actions that are spell or item casts
	-- - The aforementioned action is starting
	if (actionPacket.UserId == localPlayerId and (actionPacket.Type == 8 or actionPacket.Type == 9) and actionPacket.Param == 0x6163) then
		castbar.currentSpellId = nil;
		castbar.currentItemId = nil;

		if (actionPacket.Type == 8) then
			castbar.currentSpellId = actionPacket.Targets[1].Actions[1].Param;
		else
			castbar.currentItemId = actionPacket.Targets[1].Actions[1].Param;
		end
	end
end

return castbar;