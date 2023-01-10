-- Pulled from statustimers - Copyright (c) 2022 Heals

-------------------------------------------------------------------------------
-- imports
-------------------------------------------------------------------------------
local d3d8 = require('d3d8');
local ffi = require('ffi');
-------------------------------------------------------------------------------
-- local state
-------------------------------------------------------------------------------
local d3d8_device = d3d8.get_device();
-------------------------------------------------------------------------------
-- local constants
-------------------------------------------------------------------------------
local icon_cache = T{
};

-- this table implements overrides for certain icons to handle
-- local buffs_table = nil;
local id_overrides = T{
};
-------------------------------------------------------------------------------
-- local functions
-------------------------------------------------------------------------------

-- load a dummy icon placeholder for a missing status and return a texture pointer
---@return ffi.cdata* texture_ptr the loaded texture object or nil on error
local function load_dummy_icon()
    local icon_path = ('%s\\addons\\%s\\ladybug.png'):fmt(AshitaCore:GetInstallPath(), 'statustimers');
    local dx_texture_ptr = ffi.new('IDirect3DTexture8*[1]');

    if (ffi.C.D3DXCreateTextureFromFileA(d3d8_device, icon_path, dx_texture_ptr) == ffi.C.S_OK) then
        return d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', dx_texture_ptr[0]));
    end

    return nil;
end

-- load a status icon from the games own resources and return a texture pointer
---@param status_id number the status id to load the icon for
---@return ffi.cdata* texture_ptr the loaded texture object or nil on error
local function load_status_icon_from_resource(status_id)
    if (status_id == nil or status_id < 0 or status_id > 0x3FF) then
        print(('attempting to display status effect "%d" which is out of range 0...1023 - crashing.'):fmt(status_id));
        return nil;
    end

    local id_key = ("_%d"):fmt(status_id);
    if (id_overrides:haskey(id_key)) then
        status_id = id_overrides[id_key];
    end

    local icon = AshitaCore:GetResourceManager():GetStatusIconByIndex(status_id);
    if (icon ~= nil) then
        local dx_texture_ptr = ffi.new('IDirect3DTexture8*[1]');
        if (ffi.C.D3DXCreateTextureFromFileInMemoryEx(d3d8_device, icon.Bitmap, compat.icon_size(icon), 0xFFFFFFFF, 0xFFFFFFFF, 1, 0, ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED, ffi.C.D3DX_DEFAULT, ffi.C.D3DX_DEFAULT, 0xFF000000, nil, nil, dx_texture_ptr) == ffi.C.S_OK) then
            return d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', dx_texture_ptr[0]));
        end
    end
    return load_dummy_icon();
end

-- load a status icon from a theme pack and return a texture pointer
---@param theme string path to the theme's root directory
---@param status_id number the status id to load the icon for
---@return ffi.cdata* texture_ptr the loaded texture object or nil on error
local function load_status_icon_from_theme(theme, status_id)
    if (status_id == nil or status_id < 0 or status_id > 0x3FF) then
        print(('attempting to display status effect "%d" which is out of range 0...1023 - crashing.'):fmt(status_id));
        return nil;
    end

    local icon_path = nil;
    local supports_alpha = false;
    T{'.png', '.jpg', '.jpeg', '.bmp'}:forieach(function(ext, _)
        if (icon_path ~= nil) then
            return;
        end

        supports_alpha = ext == '.png';
        icon_path = ('%s\\addons\\%s\\themes\\%s\\%d'):append(ext):fmt(AshitaCore:GetInstallPath(), 'statustimers', theme, status_id);
        local handle = io.open(icon_path, 'r');
        if (handle ~= nil) then
            handle.close();
        else
            icon_path = nil;
        end
    end);

    if (icon_path == nil) then
        -- fallback to internal icon resources
        return load_status_icon_from_resource(status_id);
    end

    local dx_texture_ptr = ffi.new('IDirect3DTexture8*[1]');
    if (supports_alpha) then
        -- use the native transaparency
        if (ffi.C.D3DXCreateTextureFromFileA(d3d8_device, icon_path, dx_texture_ptr) == ffi.C.S_OK) then
            return d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', dx_texture_ptr[0]));
        end
    else
        -- use black as colour-key for transparency
        if (ffi.C.D3DXCreateTextureFromFileExA(d3d8_device, icon_path, 0xFFFFFFFF, 0xFFFFFFFF, 1, 0, ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED, ffi.C.D3DX_DEFAULT, ffi.C.D3DX_DEFAULT, 0xFF000000, nil, nil, dx_texture_ptr) == ffi.C.S_OK) then
            return d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', dx_texture_ptr[0]));
        end
    end

    return load_dummy_icon();
end
-------------------------------------------------------------------------------
-- exported functions
-------------------------------------------------------------------------------
local module = {};

-- return an image pointer for a status_id for use with imgui.Image
---@param status_id number the status id number of the requested icon
---@return number texture_ptr_id a number representing the texture_ptr or nil
module.get_icon_image = function(status_id)
    if (not icon_cache:haskey(status_id)) then
        local tex_ptr = load_status_icon_from_resource(status_id);
        if (tex_ptr == nil) then
            return nil;
        end
        icon_cache[status_id] = tex_ptr;
    end
    return tonumber(ffi.cast("uint32_t", icon_cache[status_id]));
end

-- return an image pointer for a status_id for use with imgui.Image
---@param theme string the name of the theme directory
---@param status_id number the status id number of the requested icon
---@return number texture_ptr_id a number representing the texture_ptr or nil
module.get_icon_from_theme = function(theme, status_id)
    if (not icon_cache:haskey(status_id)) then
        local tex_ptr = load_status_icon_from_theme(theme, status_id);
        if (tex_ptr == nil) then
            return nil;
        end
        icon_cache[status_id] = tex_ptr;
    end
    return tonumber(ffi.cast("uint32_t", icon_cache[status_id]));
end

-- return a list of all sub directories of statustimers\themes\
---@return table theme_paths
module.get_theme_paths = function()
    local path = ('%s\\addons\\%s\\themes\\'):fmt(AshitaCore:GetInstallPath(), 'statustimers');
    local directories = ashita.fs.get_directory(path);
    if (directories ~= nil) then
        directories[#directories+1] = '-default-';
        return directories;
    end
    return T{'-default-'};
end

-- return index of the currently active theme in module.get_theme_paths()
---@return number theme_index
module.get_theme_index = function(theme)
    local paths = module.get_theme_paths();
    for i = 1,#paths,1 do
        if (paths[i] == theme) then
            return i;
        end
    end
    return nil;
end

-- reset the icon cache and release all resources
module.clear_cache = function()
    icon_cache = T{};
end;

-- return the name for a status index from the resource table
---@param status_id number the status id to look up
---@return string
module.get_status_name = function(status_id)
    return AshitaCore:GetResourceManager():GetString(compat.buffs_table(), status_id);
end

return module;
