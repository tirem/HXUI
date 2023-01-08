--[[
* MIT License
* 
* Copyright (c) 2023 tirem [github.com/tirem]
* 
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
* 
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
* 
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
]]--

addon.name      = 'consolidatedui';
addon.author    = 'Tirem';
addon.version   = '0.1';
addon.desc      = 'Multiple UI elements with manager';
addon.link      = 'https://github.com/tirem/ConsolidatedUI'

require('common');
local imgui = require('imgui');
local settings = require('settings');
local playerBar = require('playerbar');
local targetBar = require('targetbar');
local enemyList = require('enemylist');
local expBar = require('expbar');
local gilTracker = require('giltracker');
local inventoryTracker = require('inventorytracker');
local partyList = require('partylist');

local default_settings =
T{
	showPlayerBar = true;
	showTargetBar = true;
	showEnemyList = true;
	showExpBar = true;
	showGilTracker = true;
	showInventoryTracker = true;
	showPartyList = true;

	-- settings for the targetbar
	targetBarSettings =
	T{
		barWidth = 600,
		barHeight = 20,
		totBarHeight = 16,
		totBarOffset = 1,
		textScale = 1.2,
		showBarPercent = true;
	};

	-- settings for the playerbar
	playerBarSettings =
	T{
		hitAnimSpeed = 2;
		hitDelayLength = .5;
		barWidth = 600;
		barSpacing = 10;
		barHeight = 25;
		textYOffset = -3;
		font_settings = 
		T{
			visible = true,
			locked = true,
			font_family = 'Consolas',
			font_height = 16,
			color = 0xFFFFFFFF,
			bold = true,
			color_outline = 0xFF000000,
			draw_flags = 0x10,
			background = 
			T{
				visible = false,
			},
			right_justified = true;
		};
	};

	-- settings for enemy list
	enemyListSettings = 
	T{
		barWidth = 125;
		barHeight = 10;
		textScale = 1;
		maxEntries = 8;
		entrySpacing = 1;
	};

	-- settings for the exp bar
	expBarSettings =
	T{
		barWidth = 700;
		barHeight = 10;
		jobOffsetY = 0;
		expOffsetY = 0;
		percentOffsetY = -2;
		percentOffsetX = -10;
		job_font_settings = 
		T{
			visible = true,
			locked = true,
			font_family = 'Consolas',
			font_height = 12,
			color = 0xFFFFFFFF,
			bold = false,
			italic = true;
			color_outline = 0xFF000000,
			draw_flags = 0x10,
			background = 
			T{
				visible = false,
			},
			right_justified = false;
		};
		exp_font_settings = 
		T{
			visible = true,
			locked = true,
			font_family = 'Consolas',
			font_height = 12,
			color = 0xFFFFFFFF,
			bold = false,
			italic = true;
			color_outline = 0xFF000000,
			draw_flags = 0x10,
			background = 
			T{
				visible = false,
			},
			right_justified = true;
		};
		percent_font_settings = 
		T{
			visible = true,
			locked = true,
			font_family = 'Consolas',
			font_height = 9,
			color = 0xFFFFFF00,
			bold = false,
			italic = true;
			color_outline = 0xFF000000,
			draw_flags = 0x10,
			background = 
			T{
				visible = false,
			},
			right_justified = true;
		};
	};

	-- settings for gil tracker
	gilTrackerSettings = 
	T{
		iconScale = 1;
		offsetX = -5;
		offsetY = 5;
		font_settings = 
		T{
			visible = true,
			locked = true,
			font_family = 'Consolas',
			font_height = 14,
			color = 0xFFFFFFFF,
			bold = true,
			italic = false;
			color_outline = 0xFF000000,
			draw_flags = 0x10,
			background = 
			T{
				visible = false,
			},
			right_justified = true;
		};
	};

	inventoryTrackerSettings = 
	T{
		columnCount = 5;
		rowCount = 6;
		dotRadius = 6;
		dotSpacing = 3;
		groupSpacing = 10;
		textOffsetY = -5;
		font_settings = 
		T{
			visible = true,
			locked = true,
			font_family = 'Consolas',
			font_height = 14,
			color = 0xFFFFFFFF,
			bold = true,
			italic = false;
			color_outline = 0xFF000000,
			draw_flags = 0x10,
			background = 
			T{
				visible = false,
			},
			right_justified = true;
		};
	};

	partyListSettings = 
	T{
		hpBarWidth = 250,
		hpBarHeight = 25,
		mpBarWidth = 175,
		mpBarHeight = 15,
		tpBarWidth = 75,
		tpBarHeight = 10,
		entrySpacing = 15,
		hpTextOffsetX = -10,
		hpTextOffsetY = -3,
		mpTextOffsetY = -3,
		nameSpacing = 100;
		tpBarOffsetY = 8;
		hpBarOffsetY = 1;
		showWhenSolo = false,
		backgroundPaddingX1 = 30,
		backgroundPaddingX2 = 200,
		backgroundPaddingY1 = 20,
		backgroundPaddingY2 = 10,
		cursorPaddingX1 = 15,
		cursorPaddingX2 = 10,
		cursorPaddingY1 = 30,
		cursorPaddingY2 = -25,
		leaderDotRadius = 4,
		hp_font_settings = 
		T{
			visible = true,
			locked = true,
			font_family = 'Consolas',
			font_height = 14,
			color = 0xFFFFFFFF,
			bold = true,
			italic = false;
			color_outline = 0xFF000000,
			draw_flags = 0x10,
			background = 
			T{
				visible = false,
			},
			right_justified = true;
		};
		mp_font_settings = 
		T{
			visible = true,
			locked = true,
			font_family = 'Consolas',
			font_height = 13,
			color = 0xFFFFFFFF,
			bold = true,
			italic = false;
			color_outline = 0xFF000000,
			draw_flags = 0x10,
			background = 
			T{
				visible = false,
			},
			right_justified = true;
		};
		zone_font_settings = 
		T{
			visible = true,
			locked = true,
			font_family = 'Consolas',
			font_height = 16,
			color = 0xFFFFFFFF,
			bold = true,
			italic = false;
			color_outline = 0xFF000000,
			draw_flags = 0x10,
			background = 
			T{
				visible = false,
			},
			right_justified = true;
		};
		name_font_settings = 
		T{
			visible = true,
			locked = true,
			font_family = 'Consolas',
			font_height = 16,
			color = 0xFFFFFFFF,
			bold = true,
			italic = false;
			color_outline = 0xFF000000,
			draw_flags = bit.bor(0x10, 0x2),
			background = 
			T{
				visible = false,
			},
			right_justified = false;
		};
		primData = {
			texture_offset_x= 0.0,
			texture_offset_y= 0.0,
			border_visible  = false,
			border_flags    = FontBorderFlags.None,
			border_sizes    = '0,0,0,0',
			visible         = true,
			position_x      = 0,
			position_y      = 0,
			can_focus       = true,
			locked          = false,
			lockedz         = true,
			scale_x         = 1.0,
			scale_y         = 1.0,
			width           = 0.0,
			height          = 0.0,
		};
	};
};

local config = default_settings;

function UpdateSettings(s)
    -- Update the settings table..
    if (s ~= nil) then
        config = s;
    end

    -- Save the current settings..
    settings.save();
end;

settings.register('settings', 'settings_update', UpdateSettings);

--[[
* event: d3d_present
* desc : Event called when the Direct3D device is presenting a scene.
--]]
ashita.events.register('d3d_present', 'present_cb', function ()

	if (config.showPlayerBar) then
		playerBar.DrawWindow(config.playerBarSettings);
	end
	if (config.showTargetBar) then
		targetBar.DrawWindow(config.targetBarSettings);
	end
	if (config.showEnemyList) then
		enemyList.DrawWindow(config.enemyListSettings);
	end
	if (config.showExpBar) then
		expBar.DrawWindow(config.expBarSettings);
	end
	if (config.showGilTracker) then
		gilTracker.DrawWindow(config.gilTrackerSettings);
	end
	if (config.showInventoryTracker) then
		inventoryTracker.DrawWindow(config.inventoryTrackerSettings);
	end
	if (config.showPartyList) then
		partyList.DrawWindow(config.partyListSettings);
	end
end);

ashita.events.register('load', 'load_cb', function ()
    playerBar.Initialize(config.playerBarSettings);
	expBar.Initialize(config.expBarSettings);
	gilTracker.Initialize(config.gilTrackerSettings);
	inventoryTracker.Initialize(config.inventoryTrackerSettings);
	partyList.Initialize(config.partyListSettings);
end);

ashita.events.register('command', 'command_cb', function (e)
   
	-- Parse the command arguments
	local command_args = e.command:lower():args()
    if table.contains({'/consolidatedui', '/cui', '/horizonui', '/hui'}, command_args[1]) then
        if table.contains({'playerbar'}, command_args[2]) then
			config.showPlayerBar = not config.showPlayerBar;
			if (config.showPlayerBar == false) then
				playerBar.SetHidden(true);
			end
			UpdateSettings();

			if (config.showPlayerBar) then
				print('CONSOLIDATED UI: Enabled PlayerBar');
			else
				print('CONSOLIDATED UI: Disabled PlayerBar');
			end
		elseif table.contains({'targetbar'}, command_args[2]) then
			config.showTargetBar = not config.showTargetBar;
			UpdateSettings();

			if (config.showTargetBar) then
				print('CONSOLIDATED UI: Enabled TargetBar');
			else
				print('CONSOLIDATED UI: Disabled TargetBar');
			end
        elseif table.contains({'enemylist'}, command_args[2]) then
			config.showEnemyList = not config.showEnemyList;
			UpdateSettings();

			if (config.showEnemyList) then
				print('CONSOLIDATED UI: Enabled EnemyList');
			else
				print('CONSOLIDATED UI: Disabled EnemyList');
			end
		elseif table.contains({'expbar'}, command_args[2]) then
			config.showExpBar = not config.showExpBar;
			if (config.showExpBar == false) then
				expBar.SetHidden(true);
			end
			UpdateSettings();

			if (config.showExpBar) then
				print('CONSOLIDATED UI: Enabled EXPBar');
			else
				print('CONSOLIDATED UI: Disabled EXPBar');
			end
		elseif table.contains({'giltracker'}, command_args[2]) then
			config.showGilTracker = not config.showGilTracker;
			if (config.showGilTracker == false) then
				gilTracker.SetHidden(true);
			end
			UpdateSettings();

			if (config.showGilTracker) then
				print('CONSOLIDATED UI: Enabled GilTracker');
			else
				print('CONSOLIDATED UI: Disabled GilTracker');
			end
		elseif table.contains({'inventorytracker'}, command_args[2]) then
			config.showInventoryTracker = not config.showInventoryTracker;
			if (config.showInventoryTracker == false) then
				inventoryTracker.SetHidden(true);
			end
			UpdateSettings();

			if (config.showInventoryTracker) then
				print('CONSOLIDATED UI: Enabled InventoryTracker');
			else
				print('CONSOLIDATED UI: Disabled InventoryTracker');
			end
		elseif table.contains({'partylist'}, command_args[2]) then
			config.showPartyList = not config.showPartyList;
			if (config.showPartyList == false) then
				partyList.SetHidden(true);
			end
			UpdateSettings();

			if (config.showPartyList) then
				print('CONSOLIDATED UI: Enabled PartyList');
			else
				print('CONSOLIDATED UI: Disabled PartyList');
			end
		else
			print('CONSOLIDATED UI: HELP /consolidatedui /cui');
			print('CONSOLIDATED UI: Toggle elements with the following commands');
			print('CONSOLIDATED UI: /cui playerbar');
			print('CONSOLIDATED UI: /cui targetbar');
			print('CONSOLIDATED UI: /cui enemylist');
			print('CONSOLIDATED UI: /cui expbar');
			print('CONSOLIDATED UI: /cui giltracker');
			print('CONSOLIDATED UI: /cui inventorytracker');
			print('CONSOLIDATED UI: /cui partylist');
		end
		
	e.blocked = true;
    end

end);