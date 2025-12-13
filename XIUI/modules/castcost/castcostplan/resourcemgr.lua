local ability = AshitaCore:GetResourceManager():GetAbilityById(get_selected_ability());
if (ability ~= nil) then
    print('A: ' .. ability.Name[1]);
end

local spell = AshitaCore:GetResourceManager():GetSpellById(get_selected_spell());
if (spell ~= nil) then
    print('S: ' .. spell.Name[1]);
end

local mount = AshitaCore:GetResourceManager():GetString('mounts.names', get_selected_mount());
if (mount ~= nil) then
    print('M: ' .. mount);
end