### Mob Info
- New mob information system integrated from MobDB (ThornyFFXI/mobdb)
- Displays detection methods, level ranges, resistances, weaknesses, and immunities for targeted mobs
- Icons with tooltips showing detailed mob data
- Movable window separate from target bar
- Option to hide when engaged in combat

### Target Bar
- Added HP% display option for target bar
- Shows current HP percentage alongside or instead of raw HP values
- Added Helix spells to debuff tracking

### Player Bar
- HP/MP display modes: Number only, Percent only, Number (Percent), Percent (Number), Current/Max
- Text positioning controls: Alignment (left, center, right) and X/Y offsets for HP/MP/TP text
- Granular control over where text appears on bars

### Party List
- HP/MP display modes for party members (same options as player bar)
- Improved preview mode with buffs/debuffs
- Added job text customization for main/sub and level

### Enemy List
- Preview enemies option when config menu is open
- Easier to configure enemy list appearance without needing actual enemies

### Inventory Tracking
- New storage container trackers: Safe (Safe 1 & 2), Storage, Locker, Satchel, Wardrobe (1-8)
- Per-container display mode: View each wardrobe/safe separately with labels (W1, W2, S1, S2, etc.)
- Combined mode: View all containers of a type as a single combined count
- Label display options for per-container mode

### Config Menu
- Config menu sections are now collapsible for better organization
- Added credits/attributions modal in config menu

### Misc
- Added Linux support and fixed crashes with certain modules. (Steamdeck compatabilty)
- Improved cross-platform compatibility between Ashita 4 and 4.3 in preparation for release.
- Improved migration reliability when moving from HXUI to XIUI.
- Fixed imgui spam log for missing styles
- Fixed issues with MobDB sync
- Fixed migration issues with settings
- Fixed Rampart incorrect icon
- Fixed cleaning up target of target enemy list when zoning
- Fixed HP text location with bar Y scale
- Fixed subtargeting d3d_present exception
- Fixed desync between castbar and partycastbar
- Fixed hp% font size slider not updating text
- Fixed leader indicator missing in party list
- Fixed <stpc> pointer missing when already selecting party member
- Fixed targetbar bleedover on certain x scale sizes
- Potential fix for EXCEPTION_ACCESS_VIOLATION error
- Removed in-game patch notes

---

## Technical Notes

### File Changes Summary
- **73 files changed**
- **11,580 insertions**
- **8,789 deletions**
- Net result: Cleaner, more modular codebase

### Release Scripts
- Updated `scripts/release.ps1` and `scripts/release.sh` for new structure

---

## Dependencies

### New Submodule
- **MobDB** (ThornyFFXI/mobdb) - MIT License
  - Provides mob detection, level, resistance, weakness, and immunity data
  - Zone-specific data files loaded on demand
