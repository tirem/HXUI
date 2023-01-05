require('common');
local imgui = require('imgui');

function draw_rect(top_left, bot_right, color, radius, fill)
    local color = imgui.GetColorU32(color);
    local dimensions = {
        { top_left[1], top_left[2] },
        { bot_right[1], bot_right[2] }
    };
	if (fill == true) then
   		imgui.GetWindowDrawList():AddRectFilled(dimensions[1], dimensions[2], color, radius, ImDrawCornerFlags_All);
	else
		imgui.GetWindowDrawList():AddRect(dimensions[1], dimensions[2], color, radius, ImDrawCornerFlags_All, 3);
	end
end

function GetColorOfTarget(targetEntity, targetIndex)
    -- Obtain the entity spawn flags..

	local color = {1,1,1,1};
	if (targetIndex == nil) then
		return color;
	end
    local flag = targetEntity.SpawnFlags;

    -- Determine the entity type and apply the proper color
    if (bit.band(flag, 0x0001) == 0x0001) then --players
		local party = AshitaCore:GetMemoryManager():GetParty();
		for i = 0, 17 do
			if (party:GetMemberIsActive(i) == 1) then
				if (party:GetMemberTargetIndex(i) == targetIndex) then
					color = {0,1,1,1};
					break;
				end
			end
		end
    elseif (bit.band(flag, 0x0002) == 0x0002) then --npc
        color = {.4,1,.4,1};
    else --mob
		local entMgr = AshitaCore:GetMemoryManager():GetEntity();
		local claimStatus = entMgr:GetClaimStatus(targetIndex);
		local claimId = bit.band(claimStatus, 0xFFFF);
--		local isClaimed = (bit.band(claimStatus, 0xFFFF0000) ~= 0);

		if (claimId == 0) then
			color = {1,1,.4,1};
		else
			color = {1,.4,1,1};
			local party = AshitaCore:GetMemoryManager():GetParty();
			for i = 0, 17 do
				if (party:GetMemberIsActive(i) == 1) then
					if (party:GetMemberServerId(i) == claimId) then
						color = {1,.4,.4,1};
						break;
					end;
				end
			end
		end
	end
	return color;
end

function GetIsMob(targetEntity)
    -- Obtain the entity spawn flags..
    local flag = targetEntity.SpawnFlags;
    -- Determine the entity type
	local isMob;
    if (bit.band(flag, 0x0001) == 0x0001 or bit.band(flag, 0x0002) == 0x0002) then --players and npcs
        isMob = false;
    else --mob
		isMob = true;
    end
	return isMob;
end