local ptrs = T{
    ability_sel     = ashita.memory.find(':ffximain', 0, '81EC80000000568B35????????8BCE8B463050E8', 0x09, 0),
    magic_sel       = ashita.memory.find(':ffximain', 0, '81EC80000000568B35????????578BCE8B7E3057', 0x09, 0),
    mount_sel       = ashita.memory.find(':ffximain', 0, '8B4424048B0D????????50E8????????8B0D????????C7411402000000C3', 0x06, 0),
    getitem_ability = ashita.memory.find(':ffximain', 0, '8B44240485C07C??3B41447D??8B49208D04C185C075??83C8FFC204008B108B', 0, 0),
    getitem_spell   = ashita.memory.find(':ffximain', 0, '8B44240485C07C??3B41447D??8B49208D04C185C075??83C8FFC204008B108B', 0, 1),
    getitem         = ashita.memory.find(':ffximain', 0, '8B44240485C07C??3B41447D??8B49208D04C185C075??83C8FFC204008B00C20400', 0, 0),
};

ffi.cdef[[
    typedef int32_t (__thiscall* KaListBox_GetItem_f)(uint32_t, int32_t);
]];

local function get_KaMenuAbilitySel()
    local ptr = ashita.memory.read_uint32(ptrs.ability_sel);
    if (ptr == 0) then return 0; end
    ptr = ashita.memory.read_uint32(ptr);
    if (ptr == 0) then return 0; end
    return ptr;
end

local function get_KaMenuMagicSel()
    local ptr = ashita.memory.read_uint32(ptrs.magic_sel);
    if (ptr == 0) then return 0; end
    ptr = ashita.memory.read_uint32(ptr);
    if (ptr == 0) then return 0; end
    return ptr;
end

local function get_KaMenuMountSel()
    local ptr = ashita.memory.read_uint32(ptrs.mount_sel);
    if (ptr == 0) then return 0; end
    ptr = ashita.memory.read_uint32(ptr);
    if (ptr == 0) then return 0; end
    return ptr;
end

local function get_selected_ability()
    local obj = get_KaMenuAbilitySel();
    if (obj == 0) then
        return -1;
    end

    if (ashita.memory.read_int32(obj + 0x40) <= 0) then
        return -1;
    end

    local idx   = ashita.memory.read_int32(obj + 0x30);
    local func  = ffi.cast('KaListBox_GetItem_f', ptrs.getitem_ability);

    return func(obj, idx);
end

local function get_selected_spell()
    local obj = get_KaMenuMagicSel();
    if (obj == 0) then
        return -1;
    end

    if (ashita.memory.read_int32(obj + 0x40) <= 0) then
        return -1;
    end

    local idx   = ashita.memory.read_int32(obj + 0x30);
    local func  = ffi.cast('KaListBox_GetItem_f', ptrs.getitem_spell);

    return func(obj, idx);
end

local function get_selected_mount()
    local obj = get_KaMenuMountSel();
    if (obj == 0) then
        return -1;
    end

    if (ashita.memory.read_int32(obj + 0x40) <= 0) then
        return -1;
    end

    local idx   = ashita.memory.read_int32(obj + 0x30);
    local func  = ffi.cast('KaListBox_GetItem_f', ptrs.getitem);

    return func(obj, idx);
end