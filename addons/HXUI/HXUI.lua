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

addon.name      = 'HXUI';
addon.author    = 'Team HXUI (Tirem, Shuu, colorglut, RheaCloud)';
addon.version   = '1.1.1';
addon.desc      = 'Multiple UI elements with manager';
addon.link      = 'https://github.com/tirem/HXUI'

require('common');
local settings = require('settings');
local playerBar = require('playerbar');
local targetBar = require('targetbar');
local enemyList = require('enemylist');
local expBar = require('expbar');
local gilTracker = require('giltracker');
local inventoryTracker = require('inventorytracker');
local partyList = require('partylist');
local castBar = require('castbar');
local recastBar = require('recastbar');
local configMenu = require('configmenu');
local patchNotes = require('patchNotes');
svgrenderer = require('svgrenderer/svgrenderer');
require('colors');

-- Initialize our status lib and begin tracking by packet
gStatusLib = require('status.status');

-- =================
-- = HXUI DEV ONLY =
-- =================
-- Hot reloading of development files functionality
local _HXUI_DEV_HOT_RELOADING_ENABLED = false;
local _HXUI_DEV_HOT_RELOAD_POLL_TIME_SECONDS = 1;
local _HXUI_DEV_HOT_RELOAD_LAST_RELOAD_TIME;
local _HXUI_DEV_HOT_RELOAD_FILES = {};

function string:split(sep)
   local sep, fields = sep or ":", {}
   local pattern = string.format("([^%s]+)", sep)
   self:gsub(pattern, function(c) fields[#fields+1] = c end)
   return fields
end

function _check_hot_reload()
	local path = string.gsub(addon.path, '\\\\', '\\');

	local result = io.popen("forfiles /P " .. path .. ' /M *.lua /C "cmd /c echo @file @fdate @ftime"');

	local needsReload = false;

	for line in result:lines() do
		if #line > 0 then
			local splitLine = line:split(" ");
			local filename = splitLine[1];
			local dateModified = splitLine[2];
			local timeModified = splitLine[3];

			filename = string.gsub(filename, '"', '');

			local fileTable = {dateModified, timeModified};

			if _HXUI_DEV_HOT_RELOAD_FILES[filename] ~= nil then
				if table.concat(_HXUI_DEV_HOT_RELOAD_FILES[filename]) ~= table.concat(fileTable) then
					needsReload = true;
					print("[HXUI] Development file " .. filename .. " changed, reloading HXUI.")
				end
			end

			_HXUI_DEV_HOT_RELOAD_FILES[filename] = fileTable;
		end
	end

	result:close();

	if needsReload then
		AshitaCore:GetChatManager():QueueCommand(-1, '/addon reload hxui', channelCommand);
	end
end
-- ==================
-- = /HXUI DEV ONLY =
-- ==================

local user_settings = 
T{
	patchNotesVer = -1,

	noBookendRounding = 4,
	lockPositions = false,


	showPlayerBar = true,
	showTargetBar = true,
	showEnemyList = true,
	showExpBar = true,
	showGilTracker = true,
	showInventoryTracker = true,
	showPartyList = true,
	showCastBar = true,

	statusIconTheme = 'XIView';
	jobIconTheme = 'FFXI',

	showPartyListWhenSolo = false,
	maxEnemyListEntries = 8,

	playerBarScaleX = 1,
	playerBarScaleY = 1,
	playerBarFontOffset = 0,
	showPlayerBarBookends = true,
	alwaysShowMpBar = true,

	targetBarScaleX = 1,
	targetBarScaleY = 1,
	targetBarFontOffset = 0,
	targetBarIconScale = 1,
	showTargetBarBookends = true,
	showEnemyId = false;
	alwaysShowHealthPercent = false,

	enemyListScaleX = 1,
	enemyListScaleY = 1,
	enemyListFontScale = 1,
	enemyListIconScale = 1,
	showEnemyListBookends = true,

	expBarScaleX = 1,
	expBarScaleY = 1,
	showExpBarBookends = true,
	expBarFontOffset = 0,

	gilTrackerScale = 1,
	gilTrackerFontOffset = 0,

	inventoryTrackerScale = 1,
	inventoryTrackerFontOffset = 0,

	partyListScaleX = 1,
	partyListScaleY = 1,
	partyListBuffScale = 1,
	partyListFontOffset = 0,
	partyListStatusTheme = 0, -- 0: HorizonXI-L, 1: HorizonXI-R 2: XIV1.0, 3: XIV, 4: Disabled
	partyListTheme = 0, 
	partyListBgOpacity = 200;
	showPartyListBookends = true,
	partyListCursor = 'GreyArrow.png',
	partyListBackground = 'BlueGradient.png',
	partyListEntrySpacing = 0,

	castBarScaleX = 1,
	castBarScaleY = 1,
	showCastBarBookends = true,
	castBarFontOffset = 0,

	healthBarFlashEnabled = true,
};

local user_settings_container = 
T{
	userSettings = user_settings;
};

local default_settings =
T{
	-- global settings
	currentPatchVer = 2,
	tpEmptyColor = 0xFF9acce8,
	tpFullColor = 0xFF2fa9ff,
	mpColor = 0xFFdef2db,

	-- settings for the targetbar
	targetBarSettings =
	T{
		-- Damage interpolation
		hitInterpolationDecayPercentPerSecond = 150,
		hitDelayDuration = 0.5,
		hitFlashDuration = 0.4,

		-- Everything else
		barWidth = 500,
		barHeight = 18,
		totBarHeight = 14,
		totBarOffset = -1,
		textScale = 1.2,
		cornerOffset = 5,
		nameXOffset = 12,
		nameYOffset = 9,
		iconSize = 22,
		arrowSize = 30,
		maxIconColumns = 12,
		topTextYOffset = 0,
		topTextXOffset = 5,
		bottomTextYOffset = -3,
		bottomTextXOffset = 15,
		name_font_settings = 
		T{
			visible = true,
			locked = true,
			font_family = 'Consolas',
			font_height = 13,
			color = 0xFFFFFFFF,
			bold = true,
			color_outline = 0xFF000000,
			draw_flags = 0x10,
			background = 
			T{
				visible = false,
			},
			right_justified = false;
		};
		totName_font_settings = 
		T{
			visible = true,
			locked = true,
			font_family = 'Consolas',
			font_height = 12,
			color = 0xFFFFFFFF,
			bold = true,
			color_outline = 0xFF000000,
			draw_flags = 0x10,
			background = 
			T{
				visible = false,
			},
			right_justified = false;
		};
		distance_font_settings = 
		T{
			visible = true,
			locked = true,
			font_family = 'Consolas',
			font_height = 11,
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
		percent_font_settings = 
		T{
			visible = true,
			locked = true,
			font_family = 'Consolas',
			font_height = 11,
			color = 0xFFFFFFFF,
			bold = true,
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

	-- settings for the playerbar
	playerBarSettings =
	T{
		hitInterpolationMaxTime = 0.5,
		hitDelayLength = 0.5,
		barWidth = 500,
		barSpacing = 10,
		barHeight = 20,
		textYOffset = -3,
		font_settings = 
		T{
			visible = true,
			locked = true,
			font_family = 'Consolas',
			font_height = 15,
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
		entrySpacing = 1;
		bgPadding = 7;
		bgTopPadding = -3;
		maxIcons = 5;
		iconSize = 18;
		debuffOffsetX = -10;
		debuffOffsetY = 0;
	};

	-- settings for the exp bar
	expBarSettings =
	T{
		barWidth = 550;
		barHeight = 12;
		jobOffsetY = 0;
		expOffsetY = 0;
		percentOffsetY = 2;
		percentOffsetX = -10;
		job_font_settings = 
		T{
			visible = true,
			locked = true,
			font_family = 'Consolas',
			font_height = 11,
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
			font_height = 11,
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
			font_height = 8,
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
		iconScale = 30;
		offsetX = -5;
		offsetY = -7;
		font_settings = 
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
	};

	inventoryTrackerSettings = 
	T{
		columnCount = 5;
		rowCount = 6;
		dotRadius = 5;
		dotSpacing = 1;
		groupSpacing = 8;
		textOffsetY = -3;
		font_settings = 
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
	};

	partyListSettings = 
	T{
		hpBarWidth = 150,
		tpBarWidth = 100,
		mpBarWidth = 100,
		barHeight = 20,
		barSpacing = 8,

		nameTextOffsetX = 1,
		nameTextOffsetY = 0,
		hpTextOffsetX = -2,
		hpTextOffsetY = -3,
		mpTextOffsetX = -2,
		mpTextOffsetY = -3,
		tpTextOffsetX = -2,
		tpTextOffsetY = -3,

		backgroundPaddingX1 = 0,
		backgroundPaddingX2 = 0,
		backgroundPaddingY1 = 0,
		backgroundPaddingY2 = 0,

		cursorPaddingX1 = 5,
		cursorPaddingX2 = 5,
		cursorPaddingY1 = 4,
		cursorPaddingY2 = 4,
		dotRadius = 3,

		arrowSize = 1;

		subtargetArrowTint = 0xFFfdd017,

		iconSize = 22,
		maxIconColumns = 6,
		buffOffset = 10,
		xivBuffOffsetY = 1,
		entrySpacing = 8,

		hp_font_settings = 
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
		tp_font_settings = 
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
		name_font_settings = 
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
			right_justified = false;
		};
		prim_data = {
			texture_offset_x= 0.0,
			texture_offset_y= 0.0,
			border_visible  = false,
			border_flags    = FontBorderFlags.None,
			border_sizes    = '0,0,0,0',
			visible         = true,
			position_x      = 0,
			position_y      = 0,
			can_focus       = false,
			locked          = true,
			lockedz         = true,
			scale_x         = 1.0,
			scale_y         = 1.0,
			width           = 0.0,
			height          = 0.0,
		};
	};

	castBarSettings =
	T{
		barWidth = 500,
		barHeight = 20,
		spellOffsetY = 0,
		percentOffsetY = 2,
		percentOffsetX = -10,
		spell_font_settings = 
		T{
			visible = true,
			locked = true,
			font_family = 'Consolas',
			font_height = 11,
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
		percent_font_settings = 
		T{
			visible = true,
			locked = true,
			font_family = 'Consolas',
			font_height = 11,
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
	};
};

gAdjustedSettings = deep_copy_table(default_settings);
local defaultUserSettings = deep_copy_table(user_settings);

local config = settings.load(user_settings_container);
gConfig = config.userSettings;

showConfig = { false };

function ResetSettings()
	local patchNotesVer = gConfig.patchNotesVer;
	gConfig = deep_copy_table(defaultUserSettings);
	gConfig.patchNotesVer = patchNotesVer;
	UpdateSettings();
end

local function CheckVisibility()
	if (gConfig.showGilTracker == false) then
		gilTracker.SetHidden(true);
	end
	if (gConfig.showInventoryTracker == false) then
		inventoryTracker.SetHidden(true);
	end
	if (gConfig.showPartyList == false) then
		partyList.SetHidden(true);
	end
end

local function ForceHide()
	gilTracker.SetHidden(true);
	inventoryTracker.SetHidden(true);
	partyList.SetHidden(true);
end

local function UpdateFonts()
	gilTracker.UpdateFonts(gAdjustedSettings.gilTrackerSettings);
	inventoryTracker.UpdateFonts(gAdjustedSettings.inventoryTrackerSettings);
	partyList.UpdateFonts(gAdjustedSettings.partyListSettings);
end

local function UpdateUserSettings()
    local ns = default_settings;
	local us = gConfig;

	-- Target Bar
	gAdjustedSettings.targetBarSettings.barWidth = round(ns.targetBarSettings.barWidth * us.targetBarScaleX);
	gAdjustedSettings.targetBarSettings.barHeight = round(ns.targetBarSettings.barHeight * us.targetBarScaleY);
	gAdjustedSettings.targetBarSettings.totBarHeight = round(ns.targetBarSettings.totBarHeight * us.targetBarScaleY);
	gAdjustedSettings.targetBarSettings.name_font_settings.font_height = math.max(ns.targetBarSettings.name_font_settings.font_height + us.targetBarFontOffset, 1);
    gAdjustedSettings.targetBarSettings.totName_font_settings.font_height = math.max(ns.targetBarSettings.totName_font_settings.font_height + us.targetBarFontOffset, 1);
	gAdjustedSettings.targetBarSettings.distance_font_settings.font_height = math.max(ns.targetBarSettings.distance_font_settings.font_height + us.targetBarFontOffset, 1);
    gAdjustedSettings.targetBarSettings.percent_font_settings.font_height = math.max(ns.targetBarSettings.percent_font_settings.font_height + us.targetBarFontOffset, 1);
	gAdjustedSettings.targetBarSettings.iconSize = round(ns.targetBarSettings.iconSize * us.targetBarIconScale);
	gAdjustedSettings.targetBarSettings.arrowSize = round(ns.targetBarSettings.arrowSize * us.targetBarScaleY);

	-- Party List
    gAdjustedSettings.partyListSettings.hpBarWidth = round(ns.partyListSettings.hpBarWidth * us.partyListScaleX);
    gAdjustedSettings.partyListSettings.barHeight = round(ns.partyListSettings.barHeight * us.partyListScaleY);
    gAdjustedSettings.partyListSettings.tpBarWidth = round(ns.partyListSettings.tpBarWidth * us.partyListScaleX);
	gAdjustedSettings.partyListSettings.mpBarWidth = round(ns.partyListSettings.mpBarWidth * us.partyListScaleX);
	gAdjustedSettings.partyListSettings.barSpacing = round(ns.partyListSettings.barSpacing * us.partyListScaleX);
    gAdjustedSettings.partyListSettings.hp_font_settings.font_height = math.max(ns.partyListSettings.hp_font_settings.font_height + us.partyListFontOffset, 1);
    gAdjustedSettings.partyListSettings.mp_font_settings.font_height = math.max(ns.partyListSettings.mp_font_settings.font_height + us.partyListFontOffset, 1);
	gAdjustedSettings.partyListSettings.tp_font_settings.font_height = math.max(ns.partyListSettings.tp_font_settings.font_height + us.partyListFontOffset, 1);
    gAdjustedSettings.partyListSettings.name_font_settings.font_height = math.max(ns.partyListSettings.name_font_settings.font_height + us.partyListFontOffset, 1);
	gAdjustedSettings.partyListSettings.iconSize = round(ns.partyListSettings.iconSize * us.partyListBuffScale);
	gAdjustedSettings.partyListSettings.entrySpacing = ns.partyListSettings.entrySpacing + us.partyListEntrySpacing;

	-- Player Bar
	gAdjustedSettings.playerBarSettings.barWidth = round(ns.playerBarSettings.barWidth * us.playerBarScaleX);
	gAdjustedSettings.playerBarSettings.barSpacing = round(ns.playerBarSettings.barSpacing * us.playerBarScaleX);
	gAdjustedSettings.playerBarSettings.barHeight = round(ns.playerBarSettings.barHeight * us.playerBarScaleY);
	gAdjustedSettings.playerBarSettings.font_settings.font_height = math.max(ns.playerBarSettings.font_settings.font_height + us.playerBarFontOffset, 1);

	-- Exp Bar
	gAdjustedSettings.expBarSettings.barWidth = round(ns.expBarSettings.barWidth * us.expBarScaleX);
	gAdjustedSettings.expBarSettings.barHeight = round(ns.expBarSettings.barHeight * us.expBarScaleY);
	gAdjustedSettings.expBarSettings.job_font_settings.font_height = math.max(ns.expBarSettings.job_font_settings.font_height + us.expBarFontOffset, 1);
	gAdjustedSettings.expBarSettings.exp_font_settings.font_height = math.max(ns.expBarSettings.exp_font_settings.font_height + us.expBarFontOffset, 1);
	gAdjustedSettings.expBarSettings.percent_font_settings.font_height = math.max(ns.expBarSettings.percent_font_settings.font_height + us.expBarFontOffset, 1);

	-- Gil Tracker
	gAdjustedSettings.gilTrackerSettings.iconScale = round(ns.gilTrackerSettings.iconScale * us.gilTrackerScale);
	gAdjustedSettings.gilTrackerSettings.font_settings.font_height = math.max(ns.gilTrackerSettings.font_settings.font_height + us.gilTrackerFontOffset, 1);
	
	-- Inventory Tracker
	gAdjustedSettings.inventoryTrackerSettings.dotRadius = round(ns.inventoryTrackerSettings.dotRadius * us.inventoryTrackerScale);
	gAdjustedSettings.inventoryTrackerSettings.dotSpacing = round(ns.inventoryTrackerSettings.dotSpacing * us.inventoryTrackerScale);
	gAdjustedSettings.inventoryTrackerSettings.groupSpacing = round(ns.inventoryTrackerSettings.groupSpacing * us.inventoryTrackerScale);
	gAdjustedSettings.inventoryTrackerSettings.font_settings.font_height = math.max(ns.inventoryTrackerSettings.font_settings.font_height + us.inventoryTrackerFontOffset, 1);

	-- Enemy List
	gAdjustedSettings.enemyListSettings.barWidth = round(ns.enemyListSettings.barWidth * us.enemyListScaleX);
	gAdjustedSettings.enemyListSettings.barHeight = round(ns.enemyListSettings.barHeight * us.enemyListScaleY);
	gAdjustedSettings.enemyListSettings.textScale = round(ns.enemyListSettings.textScale * us.enemyListFontScale);
	gAdjustedSettings.enemyListSettings.iconSize = round(ns.enemyListSettings.iconSize * us.enemyListIconScale);

	-- Cast Bar
	gAdjustedSettings.castBarSettings.barWidth = round(ns.castBarSettings.barWidth * us.castBarScaleX);
	gAdjustedSettings.castBarSettings.barHeight = round(ns.castBarSettings.barHeight * us.castBarScaleY);
	gAdjustedSettings.castBarSettings.spell_font_settings.font_height = math.max(ns.castBarSettings.spell_font_settings.font_height + us.castBarFontOffset, 1);
	gAdjustedSettings.castBarSettings.percent_font_settings.font_height = math.max(ns.castBarSettings.percent_font_settings.font_height + us.castBarFontOffset, 1);
end

function UpdateSettings()
    -- Save the current settings..
    settings.save();

	UpdateUserSettings();
	CheckVisibility();
	UpdateFonts();
end;

settings.register('settings', 'settings_update', function (s)
    if (s ~= nil) then
        config = s;
		gConfig = config.userSettings;
		UpdateSettings();
    end
end);

--[[
* event: d3d_present
* desc : Event called when the Direct3D device is presenting a scene.
--]]
ashita.events.register('d3d_present', 'present_cb', function ()

	if (gStatusLib.helpers.GetGameInterfaceHidden() == false) then
		if (gConfig.showPlayerBar) then
			playerBar.DrawWindow(gAdjustedSettings.playerBarSettings);
		end
		if (gConfig.showTargetBar) then
			targetBar.DrawWindow(gAdjustedSettings.targetBarSettings);
		end
		if (gConfig.showEnemyList) then
			enemyList.DrawWindow(gAdjustedSettings.enemyListSettings);
		end
		if (gConfig.showExpBar) then
			expBar.DrawWindow(gAdjustedSettings.expBarSettings);
		end
		if (gConfig.showGilTracker) then
			gilTracker.DrawWindow(gAdjustedSettings.gilTrackerSettings);
		end
		if (gConfig.showInventoryTracker) then
			inventoryTracker.DrawWindow(gAdjustedSettings.inventoryTrackerSettings);
		end
		if (gConfig.showPartyList) then
			partyList.DrawWindow(gAdjustedSettings.partyListSettings);
		end
		if (gConfig.showCastBar) then
			castBar.DrawWindow(gAdjustedSettings.castBarSettings);
		end

		recastBar.DrawWindow();

		configMenu.DrawWindow();

		if (gConfig.patchNotesVer < gAdjustedSettings.currentPatchVer) then
			patchNotes.DrawWindow();
		end
	else
		ForceHide();
	end

	-- HXUI DEV ONLY
	if _HXUI_DEV_HOT_RELOADING_ENABLED then
		local currentTime = os.time();

		if not _HXUI_DEV_HOT_RELOAD_LAST_RELOAD_TIME then
			_HXUI_DEV_HOT_RELOAD_LAST_RELOAD_TIME = currentTime;
		end

		if _HXUI_DEV_HOT_RELOAD_LAST_RELOAD_TIME and currentTime - _HXUI_DEV_HOT_RELOAD_LAST_RELOAD_TIME > _HXUI_DEV_HOT_RELOAD_POLL_TIME_SECONDS then
			_check_hot_reload();

			_HXUI_DEV_HOT_RELOAD_LAST_RELOAD_TIME = currentTime;
		end
	end
end);

ashita.events.register('load', 'load_cb', function ()
	UpdateUserSettings();

    playerBar.Initialize(gAdjustedSettings.playerBarSettings);
	targetBar.Initialize(gAdjustedSettings.targetBarSettings);
	expBar.Initialize(gAdjustedSettings.expBarSettings);
	gilTracker.Initialize(gAdjustedSettings.gilTrackerSettings);
	inventoryTracker.Initialize(gAdjustedSettings.inventoryTrackerSettings);
	partyList.Initialize(gAdjustedSettings.partyListSettings);
	castBar.Initialize(gAdjustedSettings.castBarSettings);
end);

ashita.events.register('command', 'command_cb', function (e)
	-- Parse the command arguments
	local command_args = e.command:lower():args()
    if table.contains({'/horizonui', '/hui', '/hxui', '/horizonxiui'}, command_args[1]) then
		-- Toggle the config menu
		showConfig[1] = not showConfig[1];
		e.blocked = true;
	end

end);

-- Track our packets
ashita.events.register('packet_in', 'packet_in_cb', function (e)
	if (e.id == 0x0028) then
		local actionPacket = ParseActionPacket(e);
		if actionPacket then
			if (gConfig.showCastBar) then
				castBar.HandleActionPacket(actionPacket);
			end
		end
	elseif (e.id == 0x00A) then
		partyList.HandleZonePacket(e);
	end
end);