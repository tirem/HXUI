# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HXUI is a comprehensive UI addon for Final Fantasy XI (specifically for HorizonXI private server) built using the Ashita addon framework. It provides multiple customizable UI elements including player bars, target bars, party lists, enemy lists, cast bars, and various trackers.

## Technology Stack

- **Language**: Lua
- **Framework**: Ashita v4 addon system
- **UI Library**: ImGui (via Ashita's imgui bindings)
- **Graphics**: Direct3D 8 (d3d8) for custom texture rendering

## Development Commands

This addon runs within the Final Fantasy XI client via the Ashita framework. There are no traditional build/test commands.

### Loading and Testing
- Load addon: `/addon load hxui` (in-game command)
- Reload addon: `/addon reload hxui` (in-game command)
- Open config: `/hxui` (in-game command)

### Hot Reloading (Development Mode)
The addon includes a hot reload feature for development:
- Enable by setting `_HXUI_DEV_HOT_RELOADING_ENABLED = true` in HXUI.lua:50
- Automatically reloads when .lua files are modified
- Polls every second (configurable via `_HXUI_DEV_HOT_RELOAD_POLL_TIME_SECONDS`)

## Git Workflow and Release Process

### IMPORTANT: Never Push Directly to Main from CLI

**All changes to main must go through GitHub PRs using the GitHub UI.**

When asked to work on PRs or merge changes:
1. **Checkout the PR branch** using `gh pr checkout <number>`
2. **Make changes and commit** to the PR branch
3. **Push changes to the PR branch** (NOT to main)
4. **Let the user merge the PR through GitHub UI**

### Release Process

When creating a new release:

1. **Update version numbers**:
   - `HXUI/HXUI.lua`: Update `addon.version` (line ~27)
   - `HXUI/patchNotes.lua`: Update version in BulletText (line ~59)
   - `HXUI/patchNotes.lua`: Update patch notes content to reflect the actual changes

2. **Create and push a version tag**:
   ```bash
   git tag -a v1.x.x -m "Release v1.x.x: Brief description"
   git push origin v1.x.x
   ```

3. **GitHub Actions will automatically**:
   - Package HXUI with submodules into a zip file
   - Create a GitHub release
   - Upload the zip file as a release asset

**DO NOT** attempt to create releases manually through the GitHub UI - always use version tags to trigger the automated release workflow.

## Code Architecture

### Entry Point and Module System
**HXUI.lua** is the main entry point that:
- Defines addon metadata (name, version, author)
- Loads all module dependencies using `require()`
- Manages global settings via the `settings` library
- Registers event handlers for game events
- Coordinates all UI modules

### Core Modules

**helpers.lua** - Central utility library containing:
- Drawing primitives (`draw_rect`, `draw_circle`)
- Entity color determination (`GetColorOfTarget`, `GetColorOfTargetRGBA`)
- Target management (`GetTargets`, `GetSubTargetActive`)
- Entity type checking (`GetIsMob`, `IsMemberOfParty`)
- Number formatting (`FormatInt`, `SeparateNumbers`)
- Packet parsing (`ParseActionPacket`, `ParseMessagePacket`, `ParseMobUpdatePacket`)
- Status icon rendering (`DrawStatusIcons`)
- HP color gradients and easing functions (`GetHpColors`, `easeOutPercent`)
- Texture loading (`LoadTexture`)

**configmenu.lua** - ImGui-based configuration interface:
- Manages all user-configurable settings
- Organized into collapsing sections per UI element
- Handles theme selection for status/job icons
- Provides scale, position, and visibility controls
- Calls `UpdateSettings()` to persist changes

**statushandler.lua** - Icon and buff/debuff management:
- Loads status icons from themes or game resources
- Caches textures for performance (D3D8 texture pointers)
- Manages buff/debuff icon backgrounds
- Handles job icon themes (Classic, FFXI, FFXIV)
- Tracks party member status effects via packet sniffing
- Provides tooltip rendering for status effects

**debuffhandler.lua** - Enemy debuff tracking:
- Monitors debuffs applied to enemies
- Parses action packets to track debuff timers
- Handles special cases (Bio, Dia spells with different durations)
- Maintains enemy debuff state tables

### UI Components

Each UI module follows a similar pattern:
- `DrawWindow(settings)` function as the main render entry point
- Uses ImGui for layout and rendering
- Accesses game state via `AshitaCore:GetMemoryManager()`
- Applies user scale/position/visibility settings

**playerbar.lua** - Player HP/MP/TP bars with:
- HP damage interpolation and flash effects
- Smooth transitions using easing functions
- Font objects for stat text display
- Configurable bookend graphics

**targetbar.lua** - Main target and target-of-target display:
- Shows entity name, HP percentage, distance
- Displays buffs and debuffs
- Color-coded based on entity type (player/NPC/mob) and claim status
- Supports subtarget indicators

**partylist.lua** - Party member overview with:
- HP/MP/TP bars for each member
- Job icons (theme-selectable)
- Status effect icons
- Target and subtarget indicators
- Sync level indicators
- Zone status (grayed out if in different zone)

**enemylist.lua** - Claimed enemy list with:
- Shows all claimed mobs in range
- Displays debuffs on each enemy (tracked by debuffhandler)
- Configurable max entries
- Distance and claim status indicators

**castbar.lua** - Player cast progress bar
**expbar.lua** - Experience/level progress bar
**giltracker.lua** - Current gil display
**inventorytracker.lua** - Inventory space display

### Shared Components

**progressbar.lua** - Reusable progress bar rendering with gradient support
**bufftable.lua** - Buff/debuff ID classification (distinguishes buffs from debuffs)
**patchNotes.lua** - In-game patch notes display window

### Asset Organization

All assets are located in the `assets/` directory and organized by type:

#### Root-Level Assets
Located directly in `assets/`:
- **arrow.png** - UI arrow indicator
- **bookend.png** - Decorative bookends for playerbar HP/MP/TP bars
- **BuffIcon.png** - Background texture for buff icons
- **DebuffIcon.png** - Background texture for debuff icons
- **chain.png** - Skillchain indicator graphic
- **gil.png** - Currency icon used by giltracker module
- **PartyList-Titles.png** - Party list header graphics
- **Selector.png** - Selection indicator graphic

#### Status Effect Icons (`assets/status/`)
Status effect icons organized by theme. Each theme folder contains numbered PNG files (0-999+) representing different status effects:
- **HD/** - High-definition status icons
- **XIView/** - Alternative status icon theme

#### Job Icons (`assets/jobs/`)
Job icons organized by theme. Each theme contains all 22 FFXI jobs:
- **Classic/** - Classic FFXI job icons (includes credits.txt)
  - Jobs: war, mnk, whm, blm, rdm, thf, pld, drk, bst, brd, rng, sam, nin, drg, smn, blu, cor, pup, dnc, sch, geo, run
- **FFXI/** - Official FFXI style job icons
  - Jobs: (same 22 jobs as Classic)
- **FFXIV/** - Final Fantasy XIV style job icons
  - Jobs: (same 22 jobs as Classic)

#### Backgrounds (`assets/backgrounds/`)
UI window background textures and frames:
- **BlackBox.png** - Solid black background
- **BlueGradient.png** - Blue gradient background
- **Plain-bg.png** - Plain background texture
- **Window1-8 themes** - 8 complete window frame themes (Window1-Window8)
  - Each theme has 5 components: `-bg` (background), `-bl` (bottom-left), `-br` (bottom-right), `-tl` (top-left), `-tr` (top-right)

#### Cursors (`assets/cursors/`)
Party list cursor and indicator graphics:
- **Hand.png** - Hand cursor graphic
- **GreyArrow.png** - Grey arrow indicator
- **BlueArrow.png** - Blue arrow indicator

#### Patch Notes (`assets/patchNotes/`)
Graphics for the patch notes display window:
- **hxui.png** - HXUI logo/branding
- **new.png** - "New" indicator graphic
- **patch.png** - Patch notes icon/graphic

**Asset Loading**: All textures are loaded using `LoadTexture()` helper from helpers.lua, which uses FFI and Direct3D 8 (`ffi.C.D3DXCreateTextureFromFileA`). Paths should be constructed using `addon.path` for relative paths.

## Settings Management

Settings are managed through Ashita's `settings` library:
- **user_settings** (HXUI.lua:101-173): User-configurable options (visibility, scales, themes)
- **default_settings** (HXUI.lua:180+): Per-module default configurations (dimensions, colors, fonts)
- Settings are persisted to: `HorizonXI/Game/config/addons/hxui/settings.json`
- `UpdateSettings()` saves changes
- `ResetSettings()` restores defaults

## Game State Access Pattern

All modules access game state via `AshitaCore:GetMemoryManager()`:
```lua
local party = AshitaCore:GetMemoryManager():GetParty()
local player = AshitaCore:GetMemoryManager():GetPlayer()
local entity = AshitaCore:GetMemoryManager():GetEntity()
local target = AshitaCore:GetMemoryManager():GetTarget()
local recast = AshitaCore:GetMemoryManager():GetRecast()
```

Check for `nil` and handle zoning states (`player.isZoning` or `currJob == 0`).

## Event System

The addon registers event handlers in HXUI.lua for:
- `d3d_present`: Rendering loop for all UI elements
- `packet_in`: Incoming packet parsing for buff/debuff tracking
- `command`: Slash command handling (`/hxui`)
- `load`: Initialization
- `unload`: Cleanup

## Key Patterns and Conventions

### Texture Loading
- Uses FFI and Direct3D 8 (`ffi.C.D3DXCreateTextureFromFileA`)
- Textures are garbage-collection safe via `d3d.gc_safe_release()`
- Cached in module-local tables to avoid repeated loads

### Entity Type Detection
Entities have `SpawnFlags` that indicate type:
- `0x0001`: Player
- `0x0002`: NPC
- Other: Mob/Enemy

### Color Conventions
- Colors are ARGB hex values (e.g., `0xFFFFFFFF` for white)
- Claim status determines mob colors (unclaimed yellow, party claimed red, other claimed magenta)

### Target Management
- Main target: `playerTarget:GetTargetIndex(0)`
- Subtarget: `playerTarget:GetTargetIndex(1)` or party subtarget
- Subtarget mode activated via `<st>` command or subtarget key
- `GetTargets()` helper resolves which target indices are active

### Font Objects
- Created via `fonts.new()` from Ashita
- Positioned absolutely on screen
- Visibility controlled via `:SetVisible(bool)`
- Text set via `:SetText(string)`

## Common Gotchas

- **Zoning**: Always check `player.isZoning` or `currJob == 0` before rendering
- **Nil Checks**: Party members, entities, and targets can be nil - always validate
- **Packet Parsing**: Action packets have variable structure based on `Type` field
- **Index vs ServerId**: Entities have both a target index (0-2303) and server ID; use appropriate conversion functions
- **ImGui State**: Some ImGui functions modify cursor position; use `SetCursorPos`/`SetCursorScreenPos` to reset when needed
- **Texture Paths**: Use `addon.path` for relative paths to assets

## Naming Conventions

- Module names: lowercase (e.g., `playerbar.lua`)
- Global config: `gConfig` (set in HXUI.lua)
- Module functions: PascalCase (e.g., `DrawWindow`)
- Local functions: snake_case or camelCase depending on module
- Constants: UPPER_SNAKE_CASE for dev flags (e.g., `_HXUI_DEV_HOT_RELOADING_ENABLED`)
