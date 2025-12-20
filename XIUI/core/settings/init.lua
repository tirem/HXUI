--[[
* XIUI Settings Init
* Re-exports all settings modules for backward compatibility
*
* Structure:
*   settings/factories.lua  - Factory functions for creating defaults with overrides
*   settings/colors.lua     - Color customization defaults
*   settings/user.lua       - User-configurable settings (gConfig defaults)
*   settings/modules.lua    - Internal module defaults (dimensions, fonts, etc.)
]]--

local factories = require('core.settings.factories');
local colors = require('core.settings.colors');
local user = require('core.settings.user');
local modules = require('core.settings.modules');

local M = {};

-- Re-export factory functions for external use
M.createPartyDefaults = factories.createPartyDefaults;
M.createPetBarTypeDefaults = factories.createPetBarTypeDefaults;
M.createPetBarTypeColorDefaults = factories.createPetBarTypeColorDefaults;
M.createPartyColorDefaults = factories.createPartyColorDefaults;

-- Re-export color customization creator
M.createColorCustomizationDefaults = colors.createColorCustomizationDefaults;

-- Create the main settings tables (called at load time)
M.user_settings = user.createUserSettingsDefaults();
M.default_settings = modules.createModuleDefaults();

return M;
