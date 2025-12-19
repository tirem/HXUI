# XIUI Refactoring Plan

This document outlines architectural improvements to address code quality, performance, and maintainability concerns.

---

## 1. Remove `string:split` Monkeypatch

**Priority:** High
**Effort:** Low
**Risk:** Low

### Problem
`XIUI.lua` defines `function string:split(...)` globally, which monkeypatches Lua's string metatable. This can collide with other addons that define their own `string:split` or expect different behavior.

### Solution
1. Create a local `split` function in `libs/format.lua`
2. Find all usages of `string:split()` across the codebase
3. Replace with `format.split(str, delimiter)` calls
4. Remove the global monkeypatch from `XIUI.lua`

### Files to Modify
- `XIUI/XIUI.lua` - remove monkeypatch
- `XIUI/libs/format.lua` - add split function
- Any files using `string:split()` - update calls

---

## 2. Memory Signature Safety Audit

**Priority:** High
**Effort:** Low
**Risk:** Low

### Problem
Memory signature lookups can return 0 if signatures aren't found (game updates, different client versions). While some locations have guards, consistency needs verification.

### Solution
Audit all `ashita.memory.find` and `ashita.memory.read_*` usage to ensure:
1. Initial signature result is checked for `== 0`
2. Any derived pointer reads are also guarded
3. Functions return safe defaults (false, nil, empty string) on failure

### Files to Audit
- `XIUI/core/gamestate.lua` - already has guards, verify completeness
- `XIUI/modules/castcost/data.lua` - verify guards
- `XIUI/libs/memory.lua` - verify all safe accessors
- Any other files using `ashita.memory.*`

### Pattern to Follow
```lua
function M.GetSomething()
    if (pSignature == 0) then
        return defaultValue;
    end
    local ptr = ashita.memory.read_uint32(pSignature + offset);
    if (ptr == 0) then
        return defaultValue;
    end
    return ashita.memory.read_uint8(ptr + finalOffset);
end
```

---

## 3. Split settingsdefaults.lua

**Priority:** Medium
**Effort:** Medium
**Risk:** Low

### Problem
`core/settingsdefaults.lua` is ~1850 lines containing:
- User settings defaults
- Module-specific settings (fonts, dimensions)
- Color theme definitions
- Factory functions for party/pet settings

This makes it hard to review and easy to introduce typos (e.g., the `#bbbbbbbe6` hex bug).

### Solution
Split into focused files under `XIUI/core/settings/`:

```
XIUI/core/settings/
├── init.lua              -- Re-exports all settings tables
├── user.lua              -- User-configurable settings (gConfig defaults)
├── modules.lua           -- Internal module defaults (dimensions, fonts)
├── colors.lua            -- Color customization defaults
└── factories.lua         -- Factory functions (createPartyDefaults, etc.)
```

### Implementation Steps
1. Create `XIUI/core/settings/` directory
2. Extract factory functions to `factories.lua`
3. Extract `M.user_settings` to `user.lua`
4. Extract `M.default_settings` to `modules.lua`
5. Extract color-related tables to `colors.lua`
6. Create `init.lua` that requires and re-exports everything
7. Update `settingsdefaults.lua` to just require from `settings/init.lua` (backward compat)
8. Update any direct imports

### Validation
- Addon loads without errors
- Settings save/load correctly
- All modules render properly
- Color customization works

---

## 4. Centralize Global State

**Priority:** Medium
**Effort:** Medium
**Risk:** Medium

### Problem
Multiple globals are scattered throughout the codebase:
- `gConfig` - user settings
- `gAdjustedSettings` - computed module settings
- `showConfig` - config menu visibility
- `HzLimitedMode` - private server feature gating (e.g., Horizon XI rules compliance)
- Various module-specific globals

This increases coupling and makes it hard to track state changes.

### Solution
Create `XIUI/core/context.lua` as a centralized state container:

```lua
local M = {
    -- Settings
    config = nil,           -- User settings (gConfig)
    adjustedSettings = nil, -- Computed settings (gAdjustedSettings)

    -- UI State
    showConfig = { false }, -- Config menu visibility

    -- Runtime State
    hzLimitedMode = false,  -- Private server feature gating
    isLoggedIn = false,     -- Login state cache

    -- Module References
    modules = {},           -- Registered modules
};

return M;
```

### Implementation Steps
1. Create `core/context.lua` with state container
2. Update `XIUI.lua` to initialize context
3. Gradually migrate globals to context table
4. Update modules to use `context.config` instead of `gConfig`
5. Keep backward-compat aliases during transition:
   ```lua
   gConfig = context.config  -- Temporary alias
   ```

### Migration Order
1. Start with new/less-used state (`HzLimitedMode`)
2. Move `showConfig`
3. Move `gAdjustedSettings`
4. Finally move `gConfig` (most references)

---

## 5. Entity Cache Optimization

**Priority:** Low
**Effort:** Medium
**Risk:** Low

### Problem
`libs/packets.lua` `GetIndexFromId()` scans entity indices 1..0x8FF on cache miss. In high-entity scenarios with many unique server IDs, this could become a hotspot.

### Current Behavior
- Cache hit: O(1)
- Cache miss: O(2303) scan
- Cache cleared on zone change

### Potential Optimizations

#### Option A: Batch Cache Population
On zone load or first miss, scan entire entity table once and cache all valid ID->index mappings.

```lua
local function PopulateEntityCache()
    local entity = AshitaCore:GetMemoryManager():GetEntity();
    for i = 1, 0x8FF do
        local serverId = entity:GetServerId(i);
        if serverId and serverId > 0 and serverId < 0x1000000 then
            entityCache[serverId] = i;
        end
    end
    cachePopulated = true;
end
```

#### Option B: Cache Misses with TTL
Track "known missing" IDs to avoid repeated scans:

```lua
local missingCache = {};
local MISS_TTL = 5; -- seconds

local function GetIndexFromId(serverId)
    if entityCache[serverId] then
        return entityCache[serverId];
    end

    -- Check if recently missed
    local missTime = missingCache[serverId];
    if missTime and (os.clock() - missTime) < MISS_TTL then
        return nil;
    end

    -- Full scan...
    -- If not found, cache the miss
    missingCache[serverId] = os.clock();
    return nil;
end
```

#### Option C: Incremental Updates via Packets
Listen for entity spawn/despawn packets to update cache incrementally instead of relying on full scans.

### Recommendation
Start with **Option A** (batch population on zone) as it's simplest and handles the common case. Profile before implementing Option B or C.

### Files to Modify
- `XIUI/libs/packets.lua` - cache logic
- `XIUI/XIUI.lua` - trigger population on zone

---

## Implementation Order

| Phase | Items | Estimated Effort |
|-------|-------|------------------|
| 1 | Remove `string:split`, Memory signature audit | Small |
| 2 | Split settingsdefaults.lua | Medium |
| 3 | Centralize globals | Medium |
| 4 | Entity cache optimization | Small-Medium |

Phases 1-2 can be done independently. Phase 3 is larger and should be done incrementally. Phase 4 should be deferred until profiling indicates it's needed.

---

## Validation Checklist

After each phase:
- [ ] Addon loads without Lua errors
- [ ] All UI modules render correctly
- [ ] Settings persist across reload
- [ ] Config menu functions properly
- [ ] No performance regression in `/xiui` stress test
- [ ] Works on both Ashita 4.0 and 4.3
