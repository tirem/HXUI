-- Recast parsing logic from the recast addon included in Ashita V4.
-- Credit goes to the Ashita team for their work on this.
require('common');
local imgui = require('imgui');
local progressbar = require('progressbar');

local resMgr = AshitaCore:GetResourceManager();
local mmRecast = AshitaCore:GetMemoryManager():GetRecast();
local player = AshitaCore:GetMemoryManager():GetPlayer();

local recastbar = T{
    abilityRecasts = T{},
    spellRecasts = T{},
    twoHours = T{
        [1] = 'Mighty Strikes', -- WAR
        [2] = 'Hundred Fists', -- MNK
        [3] = 'Benediction', -- WHM
        [4] = 'Manafont', -- BLM
        [5] = 'Chainspell', -- RDM
        [6] = 'Perfect Dodge', -- THF
        [7] = 'Invincible', -- PLD
        [8] = 'Blood Weapon', -- DRK
        [9] = 'Familiar', -- BST
        [10] = 'Soul Voice', -- BRD
        [11] = 'Eagle Eye Shot', -- RNG
        [12] = 'Meikyo Shisui', -- SAM
        [13] = 'Mijin Gakure', -- NIN
        [14] = 'Spirit Surge', -- DRG
        [15] = 'Astral Flow' -- SMN
    }
};

local function format_timestamp(timer)
    local h = math.floor(timer / (60 * 60));
    local m = math.floor(timer / 60 - h * 60);
    local s = math.floor(timer - (m + h * 60) * 60);

    if h > 0 then
        return ('%02i:%02i:%02i'):fmt(h, m, s);
    elseif m > 0 then
        return ('%02i:%02i'):fmt(m, s);
    else
        return ('%is'):fmt(s);
    end
end

local function get_ability_fallback(id)
    local resMgr = AshitaCore:GetResourceManager();
    for x = 0, 2048 do
        local ability = resMgr:GetAbilityById(x);
        if (ability ~= nil and ability.RecastTimerId == id) then
            return ability;
        end
    end
    return nil;
end

recastbar.getGradientColor = function(percent)
    local gradient;

    if (percent < .25) then 
        gradient = {"#e16b6b", "#fe9999"}; -- red
    elseif (percent < .50) then;
        gradient = {"#c2583f", "#ea9d67"}; -- orange
    elseif (percent < .75) then
        gradient = {"#c28e3e", "#eac467"}; -- yellow
    else
        gradient = {"#9abb5a", "#bfe07d"}; -- green
    end

    return gradient;
end

recastbar.updateRecasts = function()
    local currentTime = os.clock();

    recastbar.abilityRecasts = recastbar.abilityRecasts:filter(function(timer)
        return currentTime < timer.timer;
    end);

    recastbar.spellRecasts = recastbar.spellRecasts:filter(function(timer)
        return currentTime < timer.timer;
    end);

    -- Ability recasts
    for x = 0, 31 do
        local id = mmRecast:GetAbilityTimerId(x);
        local timer = mmRecast:GetAbilityTimer(x) / 60;

        if (id ~= 0 or x == 0) and timer > 0 then
            local ability = resMgr:GetAbilityByTimerId(id);
            local name = ('(Unknown: %d)'):fmt(id);

            if x == 0 then
                name = recastbar.twoHours[player:GetMainJob()];
            elseif ability ~= nil then
                name = ability.Name[1];
            elseif ability == nil then
                ability = get_ability_fallback(id);
                if ability ~= nil then
                    name = ability.Name[1];
                end
            end

            if not recastbar.abilityRecasts[id] then
                recastbar.abilityRecasts[id] = T{
                    name=name,
                    timer=currentTime + timer,
                    totalTime=timer
                };
            end
        end
    end

    -- Spell recasts
    for x = 0, 1024 do
        local id = x;
        local timer = mmRecast:GetSpellTimer(x) / 60;

        if timer > 0 then
            local spell = resMgr:GetSpellById(id);
            local name = '(Unknown Spell)';

            -- Determine the name to be displayed..
            if spell ~= nil then
                name = spell.Name[1];
            end

            if spell == nil or name:len() == 0 then
                name = ('Unknown Spell: %d'):fmt(id);
            end

            if not recastbar.spellRecasts[id] then
                recastbar.spellRecasts[id] = T{
                    name=name,
                    timer=currentTime + timer,
                    totalTime=timer
                };
            end
        end
    end
end

recastbar.DrawWindow = function()
    recastbar.updateRecasts();

    if recastbar.abilityRecasts:length() == 0 and recastbar.spellRecasts:length() == 0 then
        return;
    end

    imgui.SetNextWindowSize({300, -1}, ImGuiCond_Always);

	local windowFlags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoBringToFrontOnFocus);

	if (gConfig.lockPositions) then
		windowFlags = bit.bor(windowFlags, ImGuiWindowFlags_NoMove);
	end

    local currentTime = os.clock();

    if (imgui.Begin('Recast_Bar', true, windowFlags)) then
        -- Ability recasts
        recastbar.abilityRecasts:each(function(timer, id)
            local timeRemaining = timer.timer - os.clock();
            local percent = timeRemaining / timer.totalTime;

            progressbar.ProgressBar({{percent, recastbar.getGradientColor(percent)}}, {-1, 20}, {decorate = gConfig.showExpBarBookends});

            imgui.SetCursorPosY(imgui.GetCursorPosY() - 15);

            svgrenderer.text('recast_abil_name_' .. id, timer.name, 14, HXUI_COL_WHITE, {marginX=7});

            imgui.SameLine();

            svgrenderer.text('recast_abil_timer_' .. id, format_timestamp(timeRemaining), 14, HXUI_COL_WHITE, {marginX=7, justify='right'});
        end);


        -- Spell recasts
        recastbar.spellRecasts:each(function(timer, id)
            local timeRemaining = timer.timer - os.clock();
            local percent = timeRemaining / timer.totalTime;

            progressbar.ProgressBar({{percent, recastbar.getGradientColor(percent)}}, {-1, 20}, {decorate = gConfig.showExpBarBookends});

            imgui.SetCursorPosY(imgui.GetCursorPosY() - 15);

            svgrenderer.text('recast_spell_name_' .. id, timer.name, 14, HXUI_COL_WHITE, {marginX=7});

            imgui.SameLine();

            svgrenderer.text('recast_spell_timer_' .. id, format_timestamp(timeRemaining), 14, HXUI_COL_WHITE, {marginX=7, justify='right'});
        end);
    end

    imgui.End();
end

recastbar.Initialize = function(settings)
end

return recastbar;