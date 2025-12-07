--[[
* XIUI Entity Utilities
* Entity type detection and color handling
]]--

local M = {};

-- ========================================
-- Entity Spawn and Render Flag Constants
-- ========================================
M.SPAWN_FLAG_PLAYER = 0x0001;  -- Entity is a player character
M.SPAWN_FLAG_NPC = 0x0002;     -- Entity is an NPC
M.RENDER_FLAG_VISIBLE = 0x200;  -- Entity is visible and rendered
M.RENDER_FLAG_HIDDEN = 0x4000;  -- Entity is hidden (cutscene, menu, etc.)

-- ========================================
-- Entity Type Detection
-- ========================================

function M.GetIsMob(targetEntity)
    if (targetEntity == nil) then
        return false;
    end
    local flag = targetEntity.SpawnFlags;
    if (bit.band(flag, M.SPAWN_FLAG_PLAYER) == M.SPAWN_FLAG_PLAYER or bit.band(flag, M.SPAWN_FLAG_NPC) == M.SPAWN_FLAG_NPC) then
        return false;
    end
    return true;
end

function M.GetIsMobByIndex(index)
    return (bit.band(AshitaCore:GetMemoryManager():GetEntity():GetSpawnFlags(index), 0x10) ~= 0);
end

-- ========================================
-- Entity Name Color Functions
-- ========================================
-- Note: These require color.lua for ARGBToRGBA/RGBAToARGB and party.lua for cache functions
-- They will be set up after helpers.lua wires everything together

-- Generic function to get entity name color based on type and claim status
-- Takes a colorConfig table (e.g., gConfig.colorCustomization.targetBar or .enemyList)
-- Returns color in RGBA format
-- Dependencies: partyLib (for cache functions), colorLib (for ARGBToRGBA)
function M.GetEntityNameColorRGBA(targetEntity, targetIndex, colorConfig, partyLib, colorLib)
    -- Default to other player color
    local color = {1,1,1,1};
    if colorConfig then
        color = colorLib.ARGBToRGBA(colorConfig.playerOtherTextColor);
    end

    if (targetEntity == nil) then
        return color;
    end
    if (targetIndex == nil) then
        return color;
    end

    local flag = targetEntity.SpawnFlags;

    if (bit.band(flag, M.SPAWN_FLAG_PLAYER) == M.SPAWN_FLAG_PLAYER) then
        color = colorLib.ARGBToRGBA(colorConfig.playerOtherTextColor);
        if (partyLib.IsPartyMemberByIndex(targetIndex)) then
            color = colorLib.ARGBToRGBA(colorConfig.playerPartyTextColor);
        end
    elseif (bit.band(flag, M.SPAWN_FLAG_NPC) == M.SPAWN_FLAG_NPC) then
        color = colorLib.ARGBToRGBA(colorConfig.npcTextColor);
    else
        local entMgr = AshitaCore:GetMemoryManager():GetEntity();
        local claimStatus = entMgr:GetClaimStatus(targetIndex);
        local claimId = bit.band(claimStatus, 0xFFFF);

        if (claimId == 0) then
            color = colorLib.ARGBToRGBA(colorConfig.mobUnclaimedTextColor);
        else
            color = colorLib.ARGBToRGBA(colorConfig.mobOtherClaimedTextColor);
            if (partyLib.IsPartyMemberByServerId(claimId)) then
                color = colorLib.ARGBToRGBA(colorConfig.mobPartyClaimedTextColor);
            end
        end
    end
    return color;
end

-- Returns ARGB format instead of RGBA
function M.GetEntityNameColor(targetEntity, targetIndex, colorConfig, partyLib, colorLib)
    local rgba = M.GetEntityNameColorRGBA(targetEntity, targetIndex, colorConfig, partyLib, colorLib);
    return colorLib.RGBAToARGB(rgba);
end

return M;
