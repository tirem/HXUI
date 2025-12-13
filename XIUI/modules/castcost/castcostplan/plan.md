# Cast Cost Module Implementation Plan

## Overview
Create a module that displays information about the currently selected spell, ability, or mount in the game's selection menus. This helps players see MP/TP costs, cast times, and other relevant information before confirming their selection.

## Data Layer

### Menu Detection
Use `gamestate.GetMenuName()` to detect which menu is currently open:
- **Spells**: Menu name contains `'menu    magic'` (note: 4 spaces)
- **Abilities**: Menu name contains `'menu    ability'` (note: 4 spaces)
- **Mounts**: Menu name contains `'menu    mount'` (note: 4 spaces)

### Memory Signatures (Provided)
Memory signatures and selection functions are provided in `atomos_code.lua`:

```lua
local ffi = require('ffi');

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
```

### Selection Functions (Provided)
Functions to get the selected item ID from each menu type:

```lua
-- Get KaMenu object pointers
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

-- Get selected item IDs (returns -1 if no valid selection)
local function get_selected_ability()
    local obj = get_KaMenuAbilitySel();
    if (obj == 0) then return -1; end
    if (ashita.memory.read_int32(obj + 0x40) <= 0) then return -1; end
    local idx = ashita.memory.read_int32(obj + 0x30);
    local func = ffi.cast('KaListBox_GetItem_f', ptrs.getitem_ability);
    return func(obj, idx);
end

local function get_selected_spell()
    local obj = get_KaMenuMagicSel();
    if (obj == 0) then return -1; end
    if (ashita.memory.read_int32(obj + 0x40) <= 0) then return -1; end
    local idx = ashita.memory.read_int32(obj + 0x30);
    local func = ffi.cast('KaListBox_GetItem_f', ptrs.getitem_spell);
    return func(obj, idx);
end

local function get_selected_mount()
    local obj = get_KaMenuMountSel();
    if (obj == 0) then return -1; end
    if (ashita.memory.read_int32(obj + 0x40) <= 0) then return -1; end
    local idx = ashita.memory.read_int32(obj + 0x30);
    local func = ffi.cast('KaListBox_GetItem_f', ptrs.getitem);
    return func(obj, idx);
end
```

### Resource Data Access
Once we have the selected item ID, use Ashita's ResourceManager to get details:

**Spells** (`GetSpellById(spellId)`):
- `Name[1]` - Spell name (language index)
- `Skill` - Skill type (Healing, Enfeebling, etc.)
- `ManaCost` - MP cost (needs verification)
- `CastTime` - Cast time (needs verification)
- `RecastDelay` - Recast time (needs verification)

**Abilities** (`GetAbilityById(abilityId)`):
- `Name[1]` - Ability name
- `RecastDelay` - Recast time (needs verification)
- TP cost for weapon skills (needs research)

**Mounts** (`GetString('mounts.names', mountId)`):
- Returns mount name string

## Module Structure

### Files to Create

```
XIUI/
├── modules/
│   └── castcost/
│       ├── init.lua      # Entry point, lifecycle methods
│       ├── data.lua      # Memory reading, menu detection
│       └── display.lua   # UI rendering
├── config/
│   └── castcost.lua      # Config menu UI
```

### Module Lifecycle (init.lua)

```lua
-- Following existing module patterns (giltracker, castbar)
local castcost = {};

function castcost.Initialize(settings)
    -- Create fonts via FontManager
    -- Create window background primitives via windowbackground.lua
    -- Initialize data layer
end

function castcost.DrawWindow(settings)
    -- Check if relevant menu is open
    -- Get selected item data
    -- Update font text/positions
    -- Render UI
end

function castcost.UpdateVisuals(settings)
    -- Recreate fonts when family/weight changes
    -- Update background theme
end

function castcost.SetHidden(hidden)
    -- Hide/show fonts and primitives
end

function castcost.Cleanup()
    -- Destroy fonts via FontManager
    -- Destroy background primitives
end

return castcost;
```

### Data Layer (data.lua)

```lua
require('common');
local ffi = require('ffi');
local gamestate = require('core.gamestate');

local M = {};

-- Memory signatures for menu selection
local ptrs = T{
    ability_sel     = ashita.memory.find(':ffximain', 0, '81EC80000000568B35????????8BCE8B463050E8', 0x09, 0),
    magic_sel       = ashita.memory.find(':ffximain', 0, '81EC80000000568B35????????578BCE8B7E3057', 0x09, 0),
    mount_sel       = ashita.memory.find(':ffximain', 0, '8B4424048B0D????????50E8????????8B0D????????C7411402000000C3', 0x06, 0),
    getitem_ability = ashita.memory.find(':ffximain', 0, '8B44240485C07C??3B41447D??8B49208D04C185C075??83C8FFC204008B108B', 0, 0),
    getitem_spell   = ashita.memory.find(':ffximain', 0, '8B44240485C07C??3B41447D??8B49208D04C185C075??83C8FFC204008B108B', 0, 1),
    getitem         = ashita.memory.find(':ffximain', 0, '8B44240485C07C??3B41447D??8B49208D04C185C075??83C8FFC204008B00C20400', 0, 0),
};

-- FFI declaration for native listbox function
ffi.cdef[[
    typedef int32_t (__thiscall* KaListBox_GetItem_f)(uint32_t, int32_t);
]];

-- Internal: Get KaMenu object pointers
local function get_KaMenuAbilitySel()
    local ptr = ashita.memory.read_uint32(ptrs.ability_sel);
    if (ptr == 0) then return 0; end
    ptr = ashita.memory.read_uint32(ptr);
    return ptr or 0;
end

local function get_KaMenuMagicSel()
    local ptr = ashita.memory.read_uint32(ptrs.magic_sel);
    if (ptr == 0) then return 0; end
    ptr = ashita.memory.read_uint32(ptr);
    return ptr or 0;
end

local function get_KaMenuMountSel()
    local ptr = ashita.memory.read_uint32(ptrs.mount_sel);
    if (ptr == 0) then return 0; end
    ptr = ashita.memory.read_uint32(ptr);
    return ptr or 0;
end

-- Menu detection
function M.GetActiveMenu()
    local menuName = gamestate.GetMenuName();
    if menuName:match('menu    magic') then return 'spell'; end
    if menuName:match('menu    ability') then return 'ability'; end
    if menuName:match('menu    mount') then return 'mount'; end
    return nil;
end

-- Get selected item IDs (returns -1 if no valid selection)
function M.GetSelectedAbilityId()
    local obj = get_KaMenuAbilitySel();
    if (obj == 0) then return -1; end
    if (ashita.memory.read_int32(obj + 0x40) <= 0) then return -1; end
    local idx = ashita.memory.read_int32(obj + 0x30);
    local func = ffi.cast('KaListBox_GetItem_f', ptrs.getitem_ability);
    return func(obj, idx);
end

function M.GetSelectedSpellId()
    local obj = get_KaMenuMagicSel();
    if (obj == 0) then return -1; end
    if (ashita.memory.read_int32(obj + 0x40) <= 0) then return -1; end
    local idx = ashita.memory.read_int32(obj + 0x30);
    local func = ffi.cast('KaListBox_GetItem_f', ptrs.getitem_spell);
    return func(obj, idx);
end

function M.GetSelectedMountId()
    local obj = get_KaMenuMountSel();
    if (obj == 0) then return -1; end
    if (ashita.memory.read_int32(obj + 0x40) <= 0) then return -1; end
    local idx = ashita.memory.read_int32(obj + 0x30);
    local func = ffi.cast('KaListBox_GetItem_f', ptrs.getitem);
    return func(obj, idx);
end

-- Resource lookups
function M.GetSpellInfo(spellId)
    if spellId < 0 then return nil; end
    return AshitaCore:GetResourceManager():GetSpellById(spellId);
end

function M.GetAbilityInfo(abilityId)
    if abilityId < 0 then return nil; end
    return AshitaCore:GetResourceManager():GetAbilityById(abilityId);
end

function M.GetMountName(mountId)
    if mountId < 0 then return nil; end
    return AshitaCore:GetResourceManager():GetString('mounts.names', mountId);
end

return M;
```

### Display Layer (display.lua)

```lua
local M = {};

-- Font handles
local nameFont;
local costFont;
local castTimeFont;

-- Background handle
local bgHandle;

-- Rendering
function M.RenderSpellInfo(spellData, settings, cursorX, cursorY) ... end
function M.RenderAbilityInfo(abilityData, settings, cursorX, cursorY) ... end
function M.RenderMountInfo(mountData, settings, cursorX, cursorY) ... end

return M;
```

## Settings

### User Settings (settingsdefaults.lua additions)

```lua
-- Add to M.user_settings:
showCastCost = true,
castCostScaleX = 1.0,
castCostScaleY = 1.0,
castCostFontSize = 12,
castCostBackgroundTheme = 'Window1',
castCostBackgroundOpacity = 1.0,
castCostShowCastTime = true,
castCostShowRecast = true,
castCostShowMpCost = true,
castCostShowTpCost = true,  -- For weapon skills
```

### Default Settings (settingsdefaults.lua additions)

```lua
-- Add to M.default_settings:
castCostSettings = T{
    bgPadding = 8,
    bgPaddingY = 8,
    borderSize = 21,
    bgOffset = 1,
    name_font_settings = T{
        font_alignment = gdi.Alignment.Left,
        font_family = 'Consolas',
        font_height = 12,
        font_color = 0xFFFFFFFF,
        font_flags = gdi.FontFlags.None,
        outline_color = 0xFF000000,
        outline_width = 2,
    },
    cost_font_settings = T{
        font_alignment = gdi.Alignment.Left,
        font_family = 'Consolas',
        font_height = 12,
        font_color = 0xFFD4FF97,  -- Green like MP color
        font_flags = gdi.FontFlags.None,
        outline_color = 0xFF000000,
        outline_width = 2,
    },
    time_font_settings = T{
        font_alignment = gdi.Alignment.Left,
        font_family = 'Consolas',
        font_height = 10,
        font_color = 0xFFCCCCCC,
        font_flags = gdi.FontFlags.None,
        outline_color = 0xFF000000,
        outline_width = 2,
    },
    prim_data = T{
        visible = false,
        can_focus = false,
        locked = true,
        width = 100,
        height = 100,
    },
},
```

### Color Customization (settingsdefaults.lua)

```lua
-- Add to colorCustomization:
castCost = T{
    nameTextColor = 0xFFFFFFFF,
    mpCostTextColor = 0xFFD4FF97,   -- Green
    tpCostTextColor = 0xFF8DC7FF,   -- Blue
    castTimeTextColor = 0xFFCCCCCC,
    recastTextColor = 0xFFFFAA00,   -- Orange
    bgColor = 0xFFFFFFFF,
    borderColor = 0xFFFFFFFF,
},
```

## Module Registration (XIUI.lua)

```lua
-- Add import
local castCost = uiMods.castcost;

-- Add registration
uiModules.Register('castCost', {
    module = castCost,
    settingsKey = 'castCostSettings',
    configKey = 'showCastCost',
    hasSetHidden = true,
});
```

## Font Settings Updater (settingsupdater.lua)

```lua
-- Add to applyGlobalSettings function:
applyGlobalFontSettings(gAdjustedSettings.castCostSettings.name_font_settings,
    us.fontFamily, fontWeightFlags, us.fontOutlineWidth);
applyGlobalFontSettings(gAdjustedSettings.castCostSettings.cost_font_settings,
    us.fontFamily, fontWeightFlags, us.fontOutlineWidth);
applyGlobalFontSettings(gAdjustedSettings.castCostSettings.time_font_settings,
    us.fontFamily, fontWeightFlags, us.fontOutlineWidth);
```

## Config Menu (config/castcost.lua)

```lua
-- Standard config UI with:
-- - Visibility toggle
-- - Scale sliders
-- - Font size slider
-- - Background theme dropdown
-- - Background opacity slider
-- - Toggle for showing cast time
-- - Toggle for showing recast
-- - Toggle for showing cost
-- - Color customization
```

## Implementation Steps

### Phase 1: Core Structure
1. Create `modules/castcost/init.lua` with basic lifecycle methods
2. Create `modules/castcost/data.lua` with memory signatures and selection functions from `atomos_code.lua`
3. Create `modules/castcost/display.lua` with font creation and basic rendering
4. Add module to `modules/init.lua` exports
5. Add settings to `settingsdefaults.lua`
6. Register module in `XIUI.lua`
7. Add to `settingsupdater.lua` for font propagation

### Phase 2: Resource Data
1. Verify spell resource properties (ManaCost, CastTime, RecastDelay)
2. Verify ability resource properties
3. Research weapon skill TP cost location
4. Implement data lookup functions

### Phase 3: Display
1. Implement spell info rendering
2. Implement ability info rendering
3. Implement mount info rendering
4. Add window background using `windowbackground.lua`
5. Implement proper positioning and scaling

### Phase 4: Config UI
1. Create `config/castcost.lua`
2. Add to config menu tabs

## Technical Notes

### Window Background Usage
```lua
local windowBg = require('libs.windowbackground');

-- In Initialize:
bgHandle = windowBg.create(settings.prim_data, themeName, bgScale);

-- In DrawWindow:
windowBg.update(bgHandle, x, y, width, height, {
    theme = themeName,
    padding = settings.bgPadding,
    paddingY = settings.bgPaddingY,
    bgScale = bgScale,
    bgOpacity = opacity,
    bgColor = colors.bgColor,
    borderSize = settings.borderSize,
    bgOffset = settings.bgOffset,
    borderOpacity = 1.0,
    borderColor = colors.borderColor,
});

-- In Cleanup:
windowBg.destroy(bgHandle);
```

### Font Usage Pattern
```lua
-- In Initialize:
nameFont = FontManager.create(settings.name_font_settings);
allFonts = {nameFont, costFont, ...};

-- In DrawWindow:
nameFont:set_font_height(fontSize);
nameFont:set_position_x(x);
nameFont:set_position_y(y);
nameFont:set_text(text);
nameFont:set_visible(true);

-- In UpdateVisuals:
nameFont = FontManager.recreate(nameFont, settings.name_font_settings);

-- In SetHidden:
SetFontsVisible(allFonts, not hidden);

-- In Cleanup:
FontManager.destroy(nameFont);
```

## Open Questions

1. **Spell Resource Properties**: Need to verify which properties are available on spell resources beyond Name and Skill. Properties like ManaCost, CastTime, RecastDelay need verification. May need to check Ashita SDK documentation or test in-game.

2. **Weapon Skill TP Cost**: Weapon skills have varying TP costs based on TP level. Need to research how this is stored/calculated.

3. **Menu Positioning**: Should the module appear near the menu cursor, or in a fixed position? Consider making this configurable.

4. **Trust Handling**: Trusts are spells but may have different display needs. Consider special handling if needed.

5. **FFI Safety**: The code uses FFI to call native game functions. Need to ensure proper error handling if signatures fail to find.
