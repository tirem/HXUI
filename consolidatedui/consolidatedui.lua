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
addon.version   = '1.0';
addon.desc      = 'Multiple UI element manager';
addon.link      = 'https://github.com/tirem/'

require('common');
local imgui = require('imgui');
local settings = require('settings');
local playerBar = require('playerbar');
local targetBar = require('targetbar');
local enemyList = require('enemylist');

local default_settings =
T{
	showPlayerBar = true;
	showTargetBar = true;
	showEnemyList = true;
	showExpBar = true;
	showGil = true;
	showInventory = true;

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
};

local settings = settings.load(default_settings);


--[[
* event: d3d_present
* desc : Event called when the Direct3D device is presenting a scene.
--]]
ashita.events.register('d3d_present', 'present_cb', function ()

	if (settings.showPlayerBar) then
		playerBar.DrawWindow(settings.playerBarSettings);
	end
	if (settings.showTargetBar) then
		targetBar.DrawWindow(settings.targetBarSettings);
	end
	if (settings.showEnemyList) then
		enemyList.DrawWindow(settings.enemyListSettings);
	end
	if (settings.showExpBar) then
		
	end
	if (settings.showGil) then
		
	end
	if (settings.showInventory) then
		
	end
end);

ashita.events.register('load', 'load_cb', function ()
    playerBar.Initialize(settings.playerBarSettings);
end);

ashita.events.register('command', 'command_cb', function (ee)
    -- Parse the command arguments
    local args = ee.command:args();
    if (#args == 0 or args[1] ~= '/consolidatedui, /horizonui') then
        return;
    end

    -- Block all targetinfo related commands
    ee.blocked = true;

end);