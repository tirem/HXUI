--[[
    Mob Info Module for XIUI
    Main entry point that provides access to both data and display modules
]]

local mobinfo = {};

-- Load sub-modules
mobinfo.data = require('modules.mobinfo.data');
mobinfo.display = require('modules.mobinfo.display');

return mobinfo;
