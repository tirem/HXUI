-- Pulled from statustimers - Copyright (c) 2022 Heals

-------------------------------------------------------------------------------
-- imports
-------------------------------------------------------------------------------
local ffi = require('ffi');
local imgui = require('imgui');
-------------------------------------------------------------------------------
-- local state
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- local constants
-------------------------------------------------------------------------------

local buffIcon = nil;
local debuffIcon = nil;

local jobIcons = T{};

-------------------------------------------------------------------------------
-- exported functions
-------------------------------------------------------------------------------
local assetLoader = {};

-- return a list of all sub directories
---@return table theme_paths
assetLoader.get_job_theme_paths = function()
    local path = ('%s\\addons\\%s\\assets\\jobs\\'):fmt(AshitaCore:GetInstallPath(), 'HXUI');
    local directories = ashita.fs.get_directory(path);
    if (directories ~= nil) then
        directories[#directories+1] = '-None-';
        return directories;
    end
    return T{'-None-'};
end

-- return a list of all sub directories
---@return table theme_paths
assetLoader.get_background_paths = function()
    local path = ('%s\\addons\\%s\\assets\\backgrounds\\'):fmt(AshitaCore:GetInstallPath(), 'HXUI');
    local directories = ashita.fs.get_dir(path, '.*.png', true);
    if (directories ~= nil) then
        return directories;
    end
    return T{};
end 

-- return a list of all sub directories
---@return table theme_paths
assetLoader.get_cursor_paths = function()
    local path = ('%s\\addons\\%s\\assets\\cursors\\'):fmt(AshitaCore:GetInstallPath(), 'HXUI');
    local directories = ashita.fs.get_dir(path, '.*.png', true);
    if (directories ~= nil) then
        return directories;
    end
    return T{};
end 

-- reset the icon cache and release all resources
assetLoader.clear_cache = function()
    buffIcon = nil;
    debuffIcon = nil;
    jobIcons = T{};
end;

assetLoader.GetBackground = function(isBuff)
    if (isBuff) then
        if (buffIcon == nil) then
            buffIcon = LoadTexture("BuffIcon")
        end
        return tonumber(ffi.cast("uint32_t", buffIcon.image));
    else
        if (debuffIcon == nil) then
            debuffIcon = LoadTexture("DebuffIcon")
        end
        return tonumber(ffi.cast("uint32_t", debuffIcon.image));
    end
end


assetLoader.GetJobIcon = function(jobIdx)

    if (jobIdx == nil or jobIdx == 0 or jobIdx == -1) then
        return nil;
    end

    local jobStr = AshitaCore:GetResourceManager():GetString("jobs.names_abbr", jobIdx);

    if (jobIcons[jobStr] == nil) then
        jobIcons[jobStr] = LoadTexture(string.format('jobs/%s/%s', gConfig.jobIconTheme, jobStr))
    end
    if (jobIcons[jobStr] == nil) then
        return nil;
    end
    return tonumber(ffi.cast("uint32_t", jobIcons[jobStr].image));
end

return assetLoader;
