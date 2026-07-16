# Changelog

## v1.6.1

### Modules/DamageMeter.lua
- **Fix**: The window interface now exposes `RefreshLockIcon` so external code (slash command, settings checkbox) can re-sync the header lock icon after changing `cfg.locked`.
- **Fix**: The pinned self bar now carries `deathRecapID`; clicking it in the **Deaths** category opens the Death Recap window like any other row.

### Core/Database.lua
- **Fix**: `/tdm lock` now computes a single target state (from the first window) and applies it to every window, instead of toggling each independently — windows with mixed lock states no longer drift apart. The header lock icons are refreshed on toggle.
- **Doc**: Refresh throttle comment aligned with the actual `REFRESH_INTERVAL` (150ms).

### Config/ConfigUI.lua
- **Fix**: The per-window **Locked** checkbox refreshes the header lock icon.

### Core/Utils.lua
- **Hardening**: `ns.FormatNumber` guards `nil` and secret values up front (returns a `"..."` placeholder) instead of falling through to `AbbreviateNumbers`, whose Lua-side arithmetic errors on secrets. The Actions column path (C-side `SetFormattedText`) is unaffected.

### TomoDamageMeter.toc
- Version bumped to 1.6.1.

## v1.6.0

### Modules/DeathRecap.lua (new)
- **New**: Death Recap window. Shows the last events before a player's death — spell icon, an HP%-remaining bar (green for heals, red for damage, brightest red on the fatal blow), a "-Xs SpellName" label, and the signed amount with overkill on the killing blow plus HP% remaining. Rows carry a real spell tooltip on hover (`SetSpellByID`). Opened by clicking a player in the **Deaths** category; optionally auto-pops on the local player's own death (`db.deathRecapAutoShow`, off by default). Sourced from `C_DeathRecap.GetRecapEvents` / `GetRecapMaxHealth` via the per-source `deathRecapID`, all secretvalue-guarded.

### Modules/SpellBridge.lua
- **New**: `ns.GetDeathRecap(recapID)` returns a processed, oldest-first event list (+ max health) from `C_DeathRecap`, every field secretvalue-guarded, with icon resolution and localized fallbacks (Heal / Melee / Unknown). `ns.FindLocalDeathRecap()` scans the Deaths sessions (Current then Overall) for the local player's most recent `deathRecapID` for the auto-popup.

### Modules/DamageMeter.lua
- **Changed**: Player elements now carry `deathRecapID`. In the **Deaths** category, clicking a player (either button) opens the Death Recap window instead of the inline/standalone spell breakdown (which is empty for deaths). Uses `deathRecapID` rather than the GUID so it works even if the source GUID is a secret value.

### Config/ConfigUI.lua, Core/Database.lua
- **New**: A "Modules" settings section with a toggle — **Death recap popup on death** (`deathRecapAutoShow`). New DB default (off). The module's event frame is unregistered on logout.

### Locales/enUS.lua, Locales/frFR.lua
- **New**: `DEATH_RECAP`, `DEATH_RECAP_NO_DATA`, `RECAP_HEAL`, `RECAP_MELEE`, `RECAP_UNKNOWN`, `SETTINGS_MODULES`, `SETTINGS_DEATH_RECAP_AUTO` (enUS is the fallback for all locales; frFR translated).

### TomoDamageMeter.toc
- Loads `Modules\DeathRecap.lua`. Version bumped to 1.6.0.

## v1.5.0

### Modules/DamageMeter.lua
- **New**: Inline spell breakdown (Details-style). Left-clicking a player bar now expands that player's spells as indented sub-rows directly beneath their row, in place, instead of only opening the standalone window. One player is expanded at a time; left-clicking again (or another player) collapses/switches. The sub-rows are refetched on every refresh, so the breakdown updates live during combat. Works for whatever category the window is on — Damage, Healing (incl. per-healer spells), Actions.
- **Changed**: Player-bar click handling is now split — **left-click** toggles the inline breakdown, **right-click** opens the standalone `SpellBreakdown` window (kept for its searchable player strip in full raids). Rows now `RegisterForClicks("LeftButtonUp", "RightButtonUp")`.
- **New**: `state.expandedGUID` tracks the expanded player. `CollectData` splices the expanded player's spell rows in right after their player row (via `ns.AppendSpellRows`) and silently collapses if that player leaves the list.
- **New**: Variable row heights. The linear view gains an element-extent calculator so spell sub-rows render a touch shorter than player rows (`SpellRowHeight()`); the fixed extent stays as a fallback. `UpdateSpellRow` renders each sub-row reusing the same widgets a player row uses (icon / bar / name / value columns) so the columns line up, with a left indent, spell icon, a dimmer class-tinted bar, and a rank prefix. An accent stripe (`groupAccent`) brackets the expanded player and its sub-rows into a visual group.
- **New**: The pooled-frame icon geometry is fully reset in the player-row path so a frame that just served as a spell sub-row round-trips cleanly back to a spec-icon player row.

### Core/Utils.lua
- **New**: `ns.AppendSpellRows(elements, sessionType, meterType, guid, parentTotal, classFilename)` — appends a player's spells as `kind == "spell"` element-data into an element list. Pure data shaping over `ns.GetSpellBreakdown` (already-resolved plain numbers); sets `sessionTotal` to the player's own total so the reused `PopulateColumnValues` renders the pct column as each spell's share of that player. Falls back to summing spell totals when `parentTotal` is a secret value mid-combat. Carries the Midnight extras (pet caster, overkill, avoidable / killing-blow) through for the hover tooltip.
- **Changed**: The player-bar hover tooltip footer now shows two hints — left-click to expand inline, right-click for the window.

### Locales/enUS.lua, Locales/frFR.lua
- **New**: `TIP_LEFT_EXPAND`, `TIP_RIGHT_WINDOW` (enUS is the fallback for all locales; frFR translated).

### TomoDamageMeter.toc
- Version bumped to 1.5.0.

## v1.4.0

### Modules/Skins.lua
- **New**: Skin system. A registry of four presets — `DARK` (the existing look: black background, dark-blue header, apple-green accent, flat fill), `NEON` (near-black background, `#CC44FF` TomoSuite-signature purple accent, smooth fill), `MINIMAL` (muted grey accent, near-invisible border, thin rows, zero spacing, flat fill) and `GLOSSY` (visible border, raised header, gold accent, glossy fill). Each preset bundles the structural look (background, header, header-hover, border, scrollbar thumb, default accent) plus the bar fill texture, fill alpha and row density.
- **New**: `ns.ApplySkin(key, seedDefaults)` mutates the live `ns.*` Style tables in place so a switch takes effect without a `/reload`. With `seedDefaults` (the user picked a skin in the options) it also overwrites the individual settings — accent colour, background opacity, bar height and bar texture — so a preset acts as a customizable bundle the user can still fine-tune afterwards. With `seedDefaults` false (the login re-apply in `Database.lua`) it sets only the structural look and preserves saved per-setting tweaks.
- **New**: LibSharedMedia integration. `ns.GetBarTexture()` resolves the active `barTexture` DB key to a file path (falling back to the flat `WHITE8X8` fill when LSM is missing or the key is unknown); `ns.GetTextureList()` returns every statusbar registered in LSM, sorted, for the texture picker. The three bundled textures (`Tomo Flat`, `Tomo Smooth`, `Tomo Glossy`) are registered into LSM so they appear alongside textures from any other addon the user runs.
- **New**: `ns.OnSkinChanged` callback registry with one built-in listener that re-skins every open window in place (`RefreshSkin` + `RefreshAccentColor` + `RefreshBarHeight`).

### Libs/ (LibStub, CallbackHandler-1.0, LibSharedMedia-3.0)
- **New**: Bundled the standard LibSharedMedia-3.0 stack (with its LibStub + CallbackHandler-1.0 dependencies) so "expose every LSM statusbar" is self-contained and does not depend on another addon having loaded the library first. Loaded before everything else in the `.toc`.

### Assets/Textures/statusbar-smooth.tga, statusbar-glossy.tga
- **New**: Two bundled 256×32 statusbar fills (uncompressed 32-bit BGRA, top-left origin — same format as the existing icon assets). `smooth` is a gentle top-lit gradient; `glossy` adds a bright sheen band near the top over a darker base. Both are greyscale luminance so the per-row class colour (applied via `SetStatusBarColor` and the existing horizontal `SetGradient`) tints them correctly.

### TomoDamageMeter.toc
- **New**: `Libs\` block (LibStub → CallbackHandler-1.0 → LibSharedMedia-3.0) loaded first, and `Modules\Skins.lua` loaded right after `Modules\Style.lua` (Skins reads the base Style values and registers textures at load time).
- Version bumped to 1.4.0.

### Core/Database.lua
- **New**: Global defaults `skin = "DARK"` and `barTexture = "Tomo Flat"`. First-run defaults are aligned with the `DARK` preset, so a fresh install is visually identical to v1.3.0.
- **New**: After accent setup and **before** any window is created, the saved skin's structural look is applied via `ns.ApplySkin(ns.db.skin, false)`, so windows build their chrome from the correct values on login (no first-frame flash).

### Modules/DamageMeter.lua
- **New**: Bars are created with `ns.GetBarTexture()` instead of the hardcoded flat fill, and `UpdateButton` swaps the fill texture in place when the active skin/texture changes — guarded by a cached `button._tex` so it only re-textures on an actual change, keeping the per-frame refresh path cheap. This is what makes the texture/skin switch take effect on the next refresh.
- **New**: `RefreshSkin` window method — re-tints every skin-driven chrome element (background + opacity, the four borders, both header separators, the sub-header and header backgrounds, and the category / sub-header hover highlights) from the live Style tables, then re-applies the active bar texture to every pooled row and the pinned self bar. Mirrors the existing `RefreshAccentColor` / `RefreshBarHeight` pattern.

### Config/ConfigUI.lua
- **New**: Two dropdowns at the top of the Appearance section — **Skin** (cycles the four presets; on change calls `ApplySkin(..., true)` then rebuilds the tab so the seeded accent / opacity / height / texture controls show their new values) and **Bar Texture** (every LSM statusbar; on change re-skins all open windows live).

### Locales
- **New**: `SETTINGS_SKIN`, `SETTINGS_BAR_TEXTURE`, `SKIN_DARK`, `SKIN_NEON`, `SKIN_MINIMAL`, `SKIN_GLOSSY` added and translated across all nine bundled locales (`enUS`, `frFR`, `deDE`, `esES`, `itIT`, `ptBR`, `zhCN`, `zhTW`, `ruRU`). The `Tomo Dark` / `Tomo Neon` preset names are kept as brand names; the descriptive `Minimal` / `Glossy` names and both UI labels are localized per language.


## v1.3.0

### Modules/SpellBridge.lua
- **New**: Per-spell extraction now keeps the extra fields the Midnight `C_DamageMeter` API exposes on each `combatSpells` entry: `creatureName` (casting pet / guardian), `overkillAmount`, `isAvoidable` and `isDeadly`. These were previously discarded. A new `ReadSpellExtras()` helper reads each one behind its own `issecretvalue` guard, so any field that is still secret mid-combat is simply left `nil` rather than risking taint.
- **Refactor**: The two spell-collection paths (`GetSpellBreakdown` and `GetSpellBreakdownBySegment`) shared an identical inline entry constructor and sort/percent pass. Both now route through `MakeEntry()` (build + enrich a single entry, skipping secret/zero rows) and `Finalize()` (sort by total desc, stamp per-spell `pct`). No behavioural change to the existing fields.

### Core/Utils.lua
- **New**: `ns.BuildBarTooltip(owner, ed, meterType, sessionType)` — builds the player-bar hover tooltip: class-coloured name, headline rate (DPS/HPS, rate-primary meters only), total with raid share, and a top-5 spell sublist (inline icon + per-spell %). Reuses `ns.GetSpellBreakdown`, so it shares the breakdown window's data path. Every value is `issecretvalue`-guarded; anything unreadable is omitted instead of shown.
- **New**: `ns.BuildSpellTooltip(owner, data)` — per-spell hover tooltip for breakdown rows: name, "cast by" pet line, rate, total + %, overkill, and avoidable / killing-blow flags.
- Both helpers run on hover only (never on the combat refresh path).

### Modules/DamageMeter.lua
- **New**: `BuildBarVisuals` now wires an `OnEnter`/`OnLeave` pair that calls `ns.BuildBarTooltip` for the hovered row, reading `state.meterType`/`state.sessionType` at hover time so the tooltip always matches the window's current view. Shared by both the ScrollBox rows and the pinned self bar (both go through `BuildBarVisuals`). Gated on the new `showBarTooltips` setting.

### Modules/SpellBreakdown.lua
- **New**: Pet / guardian attribution — when a spell carries a `creatureName`, the breakdown row label appends it in a muted colour (e.g. `Kill Command  (Hati)`). The clean spell name is preserved separately for the tooltip title.
- **New**: Spell rows are now mouse-enabled and show `ns.BuildSpellTooltip` on hover; the row's element data is stashed on the frame each refresh so the handler always reflects current values.
- Both `PopulateSpells` (per-player) and `ShowTargetSpells` (per-segment enemy view) carry the enriched fields through to their element tables.

### Core/Database.lua
- **New**: Global default `showBarTooltips = true`.

### Config/ConfigUI.lua
- **New**: "Bar Tooltips (hover)" checkbox in the General section.

### Locales
- **New**: `SETTINGS_BAR_TOOLTIPS`, `TIP_TOP_SPELLS`, `TIP_TOTAL`, `TIP_OVERKILL`, `TIP_AVOIDABLE`, `TIP_KILLING_BLOW`, `TIP_CAST_BY`, `TIP_CLICK_BREAKDOWN` added to `enUS` (base/fallback) and translated in `frFR`. Other locales inherit the English strings until translated.


## v1.2.0

### Modules/DamageMeter.lua
- **Fix**: Combat timer now actually displays. `state.UpdateTimer()` read `session.duration` — a field the `C_DamageMeter` session object does not expose — so the timer string was always blank. It now reads `session.durationSeconds` (the same field already used by `TargetBreakdown.lua`), with a fallback to `C_DamageMeter.GetSessionDurationSeconds(sessionType)`. Both paths are `issecretvalue`-guarded; the fallback is wrapped in `pcall`.
- **New**: Combat timer is gated to rate-based meters — shown only for DPS and HPS (`ns.RATE_PRIMARY`) and only when the new option is enabled; all other meter types clear it. `state.UpdateHeader()` now calls `UpdateTimer()` so visibility refreshes the instant the meter type or session changes.
- **New**: Pinned self bar — an optional, always-visible row mirroring the local player's stats, anchored at the bottom of the window. The local player is located across the full source list (not just the visible top N), so it stays visible even when scrolled off. A bottom-boundary helper frame (`scrollBR`) lets the bar reserve vertical space: the scroll list and scrollbar shrink to fit, with an accent separator dividing it from the list.
- **Fix**: `UpdateButton` was declared without `local`, leaking a global that every window overwrote — all element initializers resolved to the last window's closure (wrong `dataGeneration` for the bar-grow animation). It is now a forward-declared local so each window keeps its own closure. Latent before, but increasingly likely with more windows.
- **Refactor**: Bar visual construction extracted into a shared `BuildBarVisuals(button)`, used by both ScrollBox rows and the self bar, guaranteeing identical visuals, hover behaviour and click-to-breakdown.
- `RefreshFonts` now also re-applies fonts and column anchoring to the self bar (it is not part of the ScrollBox frame enumeration).

### Core/Init.lua
- **New**: `ns.MAX_WINDOWS` raised from 3 to 5. The window-management UI already references this constant, so the +/- controls and `Windows: %d / %d` counter scale automatically.

### Core/Database.lua
- **New**: Global defaults `showCombatTimer = true` and `showSelfBar = false`.

### Config/ConfigUI.lua
- **New**: "Combat Timer (DPS/HPS)" and "Pin My Own Bar" checkboxes added to the General section. Toggling the timer re-runs `win.UpdateTimer()` on every window; toggling the self bar triggers `ns.Refresh()`.

### Locales
- **New**: Simplified Chinese (`zhCN`), Traditional Chinese (`zhTW`) and Russian (`ruRU`) — full translations of the entire string set, registered in the TOC (loaded after `enUS`, which remains the base/fallback table).
- **New**: `SETTINGS_COMBAT_TIMER` and `SETTINGS_SELF_BAR` keys added to every locale (EN, FR, DE, ES, IT, PT-BR + the three new ones).

## v1.1.0
- **Fix**: SpellBreakdown player strip no longer overflows in raids — names are now inside a horizontally scrollable ScrollFrame
- **New**: Player dropdown menu with search filter — click the player count button to open a full list with class-colored dots and DPS/HPS preview
- **Fix**: Added `SetNonSpaceWrap(false)` to all name FontStrings in SpellBreakdown and TargetBreakdown for proper text truncation
- **New**: Dropdown auto-closes when selecting a player, closing the window, or pressing Escape
- **New**: `FILTER_PLAYERS` locale key added to all 6 languages

## v1.0.9
- **Fix**: All Locales
- **Fix**: Fixed Interrupt/Dispel/Death counter in combat (SetFormattedText C-side instead of Lua-side)
- **New**: Slider font size expanded — Range increased from 8–16 to 8–22, you will be able to go much higher.
- **New**: Font selector in the GUI (5 native WoW fonts)
- **New**: Fixed truncation percentages in SpellBreakdown and TargetBreakdown (COL_PCT_W 46→52)
- **New**: GUI scrollable content

## v1.0.8
- **Fix**: Throttled Refresh to prevent spamming and potential performance issues during combat

## v1.0.7
- **Fix**: Resolved `attempt to index global 'dmEventFrame'` error on logout/loading screen caused by cleanup code referencing locals declared later in the file
- **Fix**: Resolved `attempt to call global 'ShowTip'` / `'HideTip'` errors on header button hover caused by tooltip helper functions declared after their first use

- **New**: Tooltips on all header buttons (Settings, Target, Details, Lock, Report, Reset) and on Category, Type, and Session cycling areas
- **New**: 9 tooltip locale strings added for all 6 supported languages (EN, FR, DE, ES, IT, PT-BR)
- **Fix**: Event listeners (`dmEventFrame`, `instanceFrame`) are now properly unregistered on logout and loading screen via `PLAYER_LEAVING_WORLD`
- **Fix**: Combat tickers (`timerTicker`, `refreshTicker`) are now cancelled on logout/leaving world to prevent orphaned timers
- **Fix**: Silent `pcall` failures in SpellBridge now log error details when debug mode is enabled

## v1.0.6
- **New**: Segment Browser — two-level drill-down using Blizzard's `C_DamageMeter` segment API
  - Level 1 lists combat segments (boss name + duration) from `GetAvailableCombatSessions()`
  - Level 2 shows enemies within a selected segment via `GetCombatSessionFromID()`
  - Click an enemy to open the Spell Breakdown showing your per-spell damage for that segment
- **New**: Crosshair icon button in the meter header to open the Segment Browser
- **New**: Segment Browser auto-refreshes during combat and resets with session data
- **New**: Localized segment/target labels for all 6 supported languages (EN, FR, DE, ES, IT, PT-BR)

## v1.0.5
- Internal improvements

## v1.0.4
- **New**: Spell Breakdown window — standalone, resizable window with per-spell details and player selector strip
- **New**: Magnifying glass icon in the meter header to open the Spell Breakdown
- **New**: Category toggles (Damage, Healing, Actions) in the settings panel
- **New**: Spell Breakdown Opacity slider in the settings panel
- **Fix**: Tab bar overflow — long tab names (e.g. "Interruptions") are now capped and truncated
- **Fix**: Settings panel height adjusted for new sections

## v1.0.3
- Initial public release