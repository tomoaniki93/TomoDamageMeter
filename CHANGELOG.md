# Changelog

## v2.0.6

Fixes from a full in-game pass: two keystone runs, spell breakdowns and death recaps.

### Modules/RunRecap.lua
- **Fix (headers stacked)**: the five column labels were created with the offset advancing by a flat 4px instead of by the column width, so all of them piled into the top-right corner and rendered as one unreadable smear. Header positioning moved into `LayoutHeaderColumns`, which advances by the measured width and runs on every open.
- **Fix (missing player names)**: the window was a fixed 470px while its columns scale with the font. At font size 14 the five numeric columns consumed the entire width and the name column collapsed to nothing — end-of-run recaps showed rows of numbers with no names at all. The window is now sized from its contents: a 13-character name budget plus the five columns, so it comes out at roughly 418px at font 10 and 544px at font 14.
- Row name anchoring moved out of the creation path into the layout pass, so it follows a font change.

### Core/Utils.lua
- **Fix**: action-type values rendered with a trailing full stop — interrupts showed `8.` instead of `8`, which reads as a typo.

### Modules/SpellBreakdown.lua
- **Fix**: the breakdown total column always formatted as `1dec`, so interrupt counts displayed as `5.0`, `3.0`, `2.0`. ACTIONS meters count events rather than damage, so they now use `int`. `ns.RATE_PRIMARY` is false for exactly those types.

## v2.0.5

### Modules/DamageMeter.lua
- **Fix (font pulsing in combat)**: bar text grew and shrank several times a second during a fight, on every meter type.
- Root cause: the row initialiser set its FontStrings from the `ns.BAR_FONT_SIZE` constant (10) while `RefreshFonts` set existing rows from `ns.GetFontSize()` (the user's setting). The two agree only at the factory default, which is why the bug appeared once the font size was changed. The ScrollBox pool grows during a fight and `Flush` / `InsertTable` reassigns which frame renders which row on every pass, so a given screen row alternated between a frame born at the constant and one `RefreshFonts` had corrected.
- The initialiser now reads `ns.GetFontSize()`, and the update path re-applies the font whenever a row's stored font no longer matches the current setting. The guard means `SetFont` only fires on a row that is actually out of date, so the hot path pays nothing once everything agrees — and any row pooled while a change happened corrects itself on its next draw instead of waiting for a `RefreshFonts` it may never receive.
- `RefreshFonts` stamps the same marker so the two paths cannot disagree.

Note: the header timer and session label stay on `ns.BAR_FONT_SIZE` at both
creation and refresh. They are consistent with each other and never flickered;
they simply do not follow the bar font setting, which appears to be deliberate.

## v2.0.4

### Modules/Skins.lua
- **Changed**: the Parchment preset is disabled. It carries `hidden = true` and is filtered out of the skin picker; the definition is kept in full, so re-enabling it means deleting one line.
- **New**: `ns.ApplySkin` falls back to Tomo Dark when the saved skin is hidden, and rewrites `db.skin`. A hidden preset can still be sitting in someone's saved variables — including anyone who had Parchment selected — so it degrades instead of erroring.

Everything Parchment forced into existence stays, and every preset benefits:
the tint and surface registries that made a skin change reach text and secondary
surfaces at all, the fourth text role, the contrast-corrected panel accent, and
`ns.ClassColor`. The settings panel also keeps its own fixed palette, which is
the right call regardless of which skin is active.

## v2.0.3

Second round of Parchment testing, in combat and with the settings panel open.

### Config/ConfigUI.lua, Config/Widgets.lua
- **Fix**: the panel reverted to a fixed dark palette in 2.0.2, but its widgets still coloured their text through `ns.Tint` with the *skin's* roles. Under Parchment that painted dark brown text on dark blue dropdown buttons. All 16 sites in the panel now use fixed panel colours, with the accent going through `ns.PanelAccent()`. The panel is now fully independent of the active skin.

### Modules/Style.lua
- **Changed**: `ns.ClassColor` normalises to a target luminance instead of applying a flat scale. A flat factor moves every class by the same ratio and leaves the spread intact — Priest at 1.00 and Death Knight at 0.27 stay four luminance stops apart however hard they are darkened.
- The constraint that drives this: no single text colour is readable over both a light background and a dark bar. At a bar luminance of 0.30 the row text scored a contrast of 2.02 over the fill; at 0.68 it scores 4.21 while the bar still reads 1.24 against the background, which is enough to see given the hue difference. So the bar is what has to move, not the text.
- Each class colour is pushed onto the target — blended toward white when too dark, scaled toward black when too bright — which preserves hue. Luminance is linear, so both mixes land exactly.

### Modules/Skins.lua
- **Changed**: `classScale` replaced by `classLum`. Parchment targets 0.68; every class now lands at a contrast of 1.24 against the background and 4.19-4.21 under the row text, against 1.05 and 2.02 before. Dark presets leave the field unset and are untouched.
- **Changed**: Parchment `barAlpha` back to 1.00. With the colour computed for a specific luminance, blending it toward the background would undo the calculation.

## v2.0.2

Follow-up to in-game testing of the Parchment skin.

### Config/ConfigUI.lua, Config/Widgets.lua
- **Reverted (deliberate)**: the settings panel no longer follows the skin. It is a tool, not a HUD element — a preset tuned to stay readable over a game world is not automatically readable as a dense form, and 2.0.1 made that obvious. The panel keeps a fixed dark palette and its own surfaces.

### Modules/Style.lua
- **New**: `ns.PanelAccent()`. The panel still borrows the skin's accent so it does not look disconnected, but lifts it toward a luminance floor of 0.42 when it is too dark to sit on a dark panel — keeping the hue. Parchment's rust accent on a black panel was the case that exposed this.
- **New**: `ns.ClassColor(classFile)`, applying the active skin's `classScale`. `RAID_CLASS_COLORS` is tuned for a dark UI: Priest is pure white, Rogue pale yellow, Mage pale blue. Painted on a light background they read as almost nothing.

### Modules/Skins.lua
- **New**: `classScale` on every preset. Dark presets sit at 1.00 and are unaffected.
- **Changed**: Parchment uses `classScale = 0.30` and `barAlpha` raised from 0.55 to 0.85. Measured against the parchment background, the worst case — a white Priest bar — goes from a contrast ratio of 1.05 (indistinguishable) to 2.08. Every other class lands between 2.17 and 2.82.

### Modules/DamageMeter.lua
- **Changed**: both bar fills go through `ns.ClassColor`. Player names keep the untouched class colour: their black outline already carries them against any background, and darkening them would only muddy the text.

## v2.0.1

Fixes found by running the Parchment skin against the settings panel. All three
are the same root cause: surfaces and text roles that were never driven by the
skin, which stayed invisible for as long as every preset was dark.

### Modules/Skins.lua
- **Fix**: skins carried `textPrimary`, `textSecondary` and `textMuted` but not `textLabel`, so `ns.TEXT_LABEL` was never updated and every settings label kept its light grey — unreadable the moment the panel itself follows a light skin. All nine presets now carry the fourth role, and `ApplySkin` copies it.
- **Changed**: the skin callback also calls `ns.ResurfaceAll()`.

### Modules/Style.lua
- **New**: `ns.Surface(texture, alpha)` and `ns.ResurfaceAll()`, the texture equivalent of `ns.Tint`. Secondary surfaces derive from `HEADER_BG` and re-tint on a skin change.

### Config/ConfigUI.lua
- **Fix**: the settings panel background was hard-coded to `(0, 0, 0, 0.88)` and never followed the skin at all. Under Parchment that left a black panel wearing the skin's rust accent — a colour chosen for a light background — at very low contrast. It now derives from `ns.BG`, floored at 0.92 alpha because the panel has to stay readable over whatever is behind it, and re-applies on refresh along with the border.

### Modules/DamageMeter.lua, Modules/SpellBreakdown.lua, Modules/TargetBreakdown.lua, Config/ConfigUI.lua, Config/Widgets.lua
- **Fix**: twelve hard-coded dark navy surfaces now route through `ns.Surface`. The most visible was `stripBG` in the meter window — the action-icon column — which stayed dark navy and left a strip of the old theme down the right edge of a Parchment window. The others: the breakdown search box, its player strip and dropdown toggle, both column headers, the unselected player-strip rows, the settings tab and add/remove button backgrounds, and the dropdown button background in the widget library.

## v2.0.0

### Modules/Snap.lua (new)
- **New feature**: edge-to-edge window docking. Drop a window within 12px of another's edge and it locks on.
- **Design**: a docked window is anchored by **two** points on the shared edge, not one. Docking B under A anchors B's `TOPLEFT` to A's `BOTTOMLEFT` *and* its `TOPRIGHT` to A's `BOTTOMRIGHT`, so B's width is A's width by construction — permanently, including when A is resized. Docking side by side anchors both top and bottom corners and the height follows the same way. There is no size-synchronisation code in this module: the engine resolves it. The same property gives group movement for free, since dragging A moves everything anchored to it.
- **Behaviour**: dragging a docked window detaches it (pull away = unhook); dragging the head moves the whole chain; a docked window hides its resize grip, because the constrained axis now belongs to the window it is docked to.
- **Cycle prevention**: circular anchors raise a WoW error, so a dock is refused when the dragged window is already an ancestor of its target. The chain walk also carries a visited set, so a corrupt saved chain cannot loop forever.
- A dock requires at least 40px of overlap on the perpendicular axis, which stops a window from latching onto a neighbour it merely passes near. When several edges qualify, the closest wins.

### Core/Database.lua
- **New**: stable per-window ids (`cfg.id`, counter in `db.nextWindowId`), backfilled onto configs saved before docking existed. Dock relations are stored by id rather than array index: `RemoveWindow` shifts every index after the removed one, which would silently repoint a saved dock at the wrong window.
- **New**: `ns.RestoreSnaps()` runs as a second pass once every window has been created — a window cannot anchor to one that does not exist yet.
- **Fix**: `RemoveWindow` detaches the removed window's followers first. Left anchored to a hidden frame, they would have been stranded off-screen with no way to grab them.

### Modules/DamageMeter.lua
- **New**: `OnDragStart` detaches, `OnDragStop` attempts a dock, the resize grip refreshes the chain on release so followers re-measure their columns against their new width.
- **New**: `SetResizeHandleShown` on the window handle.
- **Fix**: `SavePosition` no longer overwrites the absolute coordinates of a docked window, which would have fought the restore pass on the next login.

### Config/ConfigUI.lua
- **New**: "Snap windows to each other" toggle (`db.snapEnabled`, on by default).

### Locales/enUS.lua, Locales/frFR.lua
- **New**: `SETTINGS_SNAP`.

### TomoDamageMeter.toc
- Loads `Modules\\Snap.lua`; version bumped to 2.0.0.

## v1.9.0

### Modules/Skins.lua
- **New**: five presets, taking the roster from four to nine. They were chosen to occupy design positions the existing four leave open — temperature, density, transparency, luminosity — rather than to add hues.
  - **Ember** and **Frost**: the warm and cold counterparts to Tomo Dark. Same structure and density, different mood.
  - **Terminal**: a density preset. 15px rows, zero spacing, and `barAlpha` at 0.30 instead of 0.50 so the bars read as a trace behind the numbers rather than as blocks.
  - **Void**: a transparency preset. Background at 0.55 and a border at 0.03 alpha, so the window floats over the game instead of sitting on it. Row spacing raised to 2 to compensate for the missing chrome.
  - **Parchment**: the first light preset. It works without touching class colours because every FontString in the addon is created with the `"OUTLINE"` flag, which draws a black outline — even a white Priest name keeps its edge against a light background.
- **New**: skins carry `textPrimary`, `textSecondary` and `textMuted`, copied into the live Style tables by `ApplySkin`. The four existing presets are backfilled with the values that were previously hard-coded, so their appearance is unchanged.
- **Changed**: the skin-change callback now calls `ns.RetintAll()` before re-skinning the windows.

### Modules/Style.lua
- **New**: `ns.Tint(fontString, role)` and `ns.RetintAll()`. `Tint` applies a role colour and registers the FontString so a later skin change can re-apply it. The registry is keyed by the FontString itself, so the hot render path can call it without the table growing.
- **Fix (latent)**: only the bar rows followed a skin change, because they are recoloured on every render. Every header label, column title, breakdown heading and settings label kept the colour it was given at creation. That was invisible while every preset was dark and would have been fatal the moment a light preset existed. All 72 call sites across seven files now route through `ns.Tint`.

### Locales (all nine)
- **New**: `SKIN_EMBER`, `SKIN_FROST`, `SKIN_TERMINAL`, `SKIN_VOID`, `SKIN_PARCHMENT`, translated in every locale to match the existing skin-name parity. The ruRU / zhCN / zhTW entries are worth a native read.

### TomoDamageMeter.toc
- Version bumped to 1.9.0.

## v1.8.0

### Modules/RunRecap.lua (new)
- **New feature**: an end-of-run group scoreboard in its own window — DPS, HPS, interrupts, deaths and avoidable damage taken, one row per group member, sorted by any column.
- **Architecture**: the recap accumulates rather than queries. Reading `C_DamageMeter` when the dungeon ends does not work: `CHALLENGE_MODE_COMPLETED`, `LFG_COMPLETION_REWARD` and zone changes are not `DAMAGE_METER_*` events, so outside those handlers the API returns secret values and the recap could not even rank players. Instead a snapshot is taken at every `PLAYER_REGEN_ENABLED`, inside a handler where values are readable and names have resolved. The Overall session is cumulative, so the last snapshot of a run is the run total — nothing is summed. Roughly fifteen snapshots per key.
- Values that come back secret are skipped rather than written, so a player's last readable figure survives. Overall totals only grow, which makes keeping the previous value strictly better than blanking it.
- Interrupts, deaths and avoidable damage cost the same API call as DPS/HPS and answer the question the other three cannot: not who played well, but why the run went wrong.
- **Triggers**: `CHALLENGE_MODE_START` / `CHALLENGE_MODE_COMPLETED` for keystones, `LFG_COMPLETION_REWARD` for the dungeon finder, and `PLAYER_ENTERING_WORLD` for both entry and exit — leaving the instance is the only "finished" signal a manual run ever produces. `/tdm recap` reopens the last one.
- **Persistence**: each finished run is stored in `db.runHistory`, keyed by `mapID` then player GUID, capped at 10 per map. The shape is chosen so a later "your DPS versus your last five runs here" reads it directly with no migration.
- **Public API**: `TomoDamageMeter.GetRunSnapshot()` and `TomoDamageMeter.GetRunHistory(mapID)`. TomoScore (shipped in TomoMod) can consume these when both are installed, while TomoDamageMeter never depends on anything of TomoMod's — the dependency only runs in the direction that costs nothing. This is the one intentional global besides the saved-variables table.
- Column widths are measured through `ns.ColWidth`, so the recap cannot repeat the clipping the breakdown windows had at larger font sizes.

### Core/Database.lua
- **New**: `ns.RunRecapSnapshot()` is called from the `PLAYER_REGEN_ENABLED` handler, immediately after the trailing-edge refresh.
- **New**: `/tdm recap`.

### Config/ConfigUI.lua
- **New**: "Show run recap at the end of a dungeon" toggle (`db.runRecapAutoShow`, on by default).

### Locales/enUS.lua, Locales/frFR.lua
- **New**: `RUN_RECAP`, `RUN_RECAP_NO_DATA`, `RECAP_COL_INT`, `RECAP_COL_DEATHS`, `RECAP_COL_AVOIDABLE`, `SETTINGS_RUN_RECAP_AUTO`, `CMD_HELP_RECAP`.

### TomoDamageMeter.toc
- Loads `Modules\RunRecap.lua`; version bumped to 1.8.0.

## v1.7.0

Structural change: no C_DamageMeter read is deferred any more. Every data pass
now runs synchronously inside the event handler that triggered it, which is the
only context where the API returns readable values instead of secret ones.

### Modules/DamageMeter.lua
- **Changed (structural)**: `state.ScheduleRefresh` no longer hops through `C_Timer.After(0)` before calling `CollectData`. That single deferral pushed every `C_DamageMeter` read outside the `DAMAGE_METER_*` handler, where the same fields come back as secret values — which is why the percentage column rendered as `-`, the chat report bailed out, and no Lua-side aggregation (sorting, cross-pull comparison) was possible mid-combat. The guards throughout the renderer are unchanged, so a build where values stay secret degrades to the previous behaviour rather than breaking.
- **New**: `CollectData` keeps its collected rows on `state.elements`, so consumers that necessarily run outside an event handler can work from values captured inside one.
- **Changed**: the report button feeds `state.elements` to `ns.SnapshotReportData`.

### Core/Database.lua
- **Changed (structural)**: the refresh throttle is now leading-edge and drops updates instead of deferring them. The old trailing branch re-entered through `C_Timer.After(REFRESH_INTERVAL)`, so even the throttled path read the API from a timer. During combat the `DAMAGE_METER_*` stream is continuous, so a dropped update is superseded within ~100ms, and `PLAYER_REGEN_ENABLED` now forces a final pass to cover the trailing edge of the fight.
- **New**: `DoRefresh` centralises the pass and carries a re-entrancy guard.
- **Fix (performance)**: `ns.RefreshTargetBreakdown` was invoked on every refresh (~6.6 Hz), re-querying one session per segment and rebuilding its entire data provider. On the old deferred path that cost was hidden inside a timer; running in-handler it would have stalled the event loop. It now has its own 1s gate.
- **New**: `/tdm diag` arms a one-shot probe that reads the same session twice — once in-handler, once from `C_Timer.After(0)` — and prints, field by field, whether the values came back readable or secret. The refresh architecture depends on that contrast, so it is worth being able to re-verify it against future builds rather than assuming it holds.
- **Doc**: the ACTIONS polling ticker is annotated as the one deliberate exception: those meters emit no event to hook, and their totals render through `SetFormattedText`, a C-side setter that accepts secret values.

### Core/Utils.lua
- **Changed**: `ns.SnapshotReportData` takes the window's captured rows as an optional third argument and builds the report from them. The report button is a click handler, so its previous live query returned secrets and aborted the whole report on the first row. A live query remains as the fallback for the out-of-combat case.
- **Fix**: the function no longer returns a snapshot with zero lines; callers get `nil` and print the existing "no data" message.

### Config/ConfigUI.lua
- **New**: a **Columns** section in the settings. `ns.db.columns` and `ns.FORMAT_OPTIONS` have driven the renderer since the first release but were never exposed, so the rate / total / percent columns and their number formats were unreachable — while the CurseForge description advertised them. Each column now has a visibility toggle and a format picker, both re-anchoring the live rows since `AnchorColumns` derives its widths from the active format.

### Modules/SpellBreakdown.lua
- **Fix (overflow)**: the player dropdown positioned every matching row while capping only the container height, and the container did not clip. Past twelve players the rows were drawn straight through the bottom edge and over whatever sat behind the dropdown, and there was no way to reach them short of typing a filter. The list now clips, scrolls with the mouse wheel, and shows a `13-24 / 30` position hint when it overflows. Filtering and scrolling share a single layout pass.

### Modules/SpellBridge.lua
- **Fix**: entries resolving to the same spell name are folded into one row. Several spellIDs can share a name — rank variants, trinket and embellishment procs, class effects with a hidden secondary ID — and listed side by side they read as a duplicate-row bug even though both lines are correct. Pet / guardian attribution is part of the merge key, so the same spell cast by two different guardians stays split. Summing is secret-value guarded via the new `AddNum`: an unreadable rate falls back to the `-` placeholder instead of erroring.

### Modules/SpellBreakdown.lua, Modules/TargetBreakdown.lua
- **Fix (visible clipping)**: both windows rendered their rows at `ns.GetFontSize()` but sized their columns with hard-coded pixel constants (`RANK_WIDTH = 22`, `COL_PCT_W = 52`, ...). Any font size above the default silently clipped: ranks past `9.` collapsed to an ellipsis, and two-digit percentages such as `32.4%` were cut to `32...`. Column widths are now measured against the active font through the new `ns.ColWidth`, exactly as the main meter already did, and the column headers follow the same measurement. Character budgets replace the pixel constants.
- **Fix**: the numeric column FontStrings had word wrap left on, so overflow wrapped into a clipped second line rather than truncating. `SetWordWrap(false)` on rank, total, per-second and percent.

### Core/Utils.lua, Core/Init.lua, Core/Database.lua
- **New**: a `"3dec"` number format. `AbbreviateLargeNumbers` — what `"full"` used to call — pins the unit at K and never rolls over to M, so 900,000 read `900 K` while 16,156,000 read `16156 K`: correct at one scale, unreadable at the next, and getting worse as totals grow. `"3dec"` keeps every significant digit of a five-figure thousands value while still rolling the unit: the same number reads `16.156M`. Added to `ns.FORMAT_OPTIONS` for the rate and total columns.
- **Changed**: one-time migration of any column saved as `"full"` to `"3dec"`, guarded by `db.fmtFullMigrated`. `"full"` was never a deliberate choice — the broken legacy seeding assigned it — and `"3dec"` carries the same precision in a readable unit. `"full"` remains selectable for anyone who wants raw digits.

### Core/Utils.lua
- **New**: `ns.ColWidth(chars, fontSize)` exposes the existing character-to-pixel measurement to the breakdown windows.
- **Fix**: `FORMAT_CHARS.full` was 7, sized for an abbreviated value. Now that `"full"` prints the unabbreviated number it needs room for 9-10 digits; raised to 11.

### Locales/enUS.lua, Locales/frFR.lua
- **New**: `CMD_HELP_DIAG`, `CMD_DIAG_ARMED`, `FMT_3DEC`, `SETTINGS_FORMAT` (enUS is the fallback layer for the other seven locales).

### Packaging (new files)
- **New** `.pkgmeta`: BigWigs packager manifest. Vendored libraries ship as-is; the `externals` alternative is documented but commented out, since declaring an external over a tracked `Libs/` folder makes the two copies drift.
- **New** `.github/workflows/release.yml`: tag-triggered publish to GitHub and CurseForge. The packager reads `## Version` and `## Interface` from the TOC, so the CurseForge game-version tags can no longer drift away from what the addon actually declares — which is exactly how the client ended up flagging the addon out of date.
- **New** `.github/workflows/validate.yml`: the manual pre-delivery pipeline as CI — Lua 5.1 syntax on every file, the forbidden-pattern scan (`goto`, `::label::`, `SetParent(nil)`, `COMBAT_LOG_EVENT_UNFILTERED`), and a check that every file listed in the TOC exists. Runs on every push and pull request.
- **New** `.gitattributes`: disables end-of-line normalization. `Config/Widgets.lua` and `Modules/DeathRecap.lua` are committed as CRLF while the rest is LF; letting git guess would silently rewrite them on checkout.
- **New** `.gitignore`.
- **New** `THIRD-PARTY-LICENSES.md`: per-library provenance and licence, taken from the headers of the files actually shipped. LibStub is public domain; LibSharedMedia-3.0 declares LGPL v2.1, which makes a blanket "All Rights Reserved" over the repository inaccurate while it is bundled. CallbackHandler-1.0 ships without a licence header and is flagged as needing the upstream Ace3 text.

### TomoDamageMeter.toc
- **New**: `## X-Curse-Project-ID: 1483230`, required for the packager to publish to the existing CurseForge project.
- **New**: `## Notes-*` for the eight non-English locales, so the in-game addon list shows a localized description. Worth a native read on the ruRU / zhCN / zhTW lines.
- **New**: `## X-License` pointing at `THIRD-PARTY-LICENSES.md`.
- **Fix**: `## Interface` was still declaring `120007, 120005` while the live client is Midnight 12.1.0 (TOC `120100`). WoW flags any addon whose interface version is older than the client as out of date, so every player on 12.1.0 had to enable "Load out of date AddOns" to run it at all. Now declares `120100, 120007`.
- Version bumped to 1.7.0.

## v1.6.3

### Modules/SpellBreakdown.lua
- **Fix (frame leak)**: `BuildPlayerStrip` called `wipe(playerButtons)` after hiding the pool, so `playerButtons[n]` was always `nil` on the next pass and a fresh `Button` was allocated for every player, every rebuild. WoW frames are never garbage collected, so each open of the breakdown window permanently added one frame per group member. The pool is now hidden but kept, and indexed 1..n for genuine reuse.
- **Fix**: `ns.ShowSpellBreakdown` built the whole player strip **twice** per call — once to obtain the first GUID, once to re-apply the selection highlight. Selection tinting is split out into `UpdatePlayerStripSelection`, which only re-colours the existing buttons, so the strip is built once.
- **Fix**: the first-player lookup compared `src.sourceGUID == sourceGUID` without an `issecretvalue` guard, while the two neighbouring loops guarded correctly. A secret GUID reaching a Lua comparison errors. The source name is now guarded on the same path.
- **Fix**: the dropdown toggle captured `selectedGUID` as an upvalue, which went stale once the selection changed without a rebuild. It now reads the live `currentGUID`.

### Config/ConfigUI.lua
- **Fix (frame leak)**: `RebuildTabs` hid the tabs and content frames, wiped both tables and recreated everything — tab buttons, content frames and roughly twenty-five sliders / checkboxes / dropdowns. It ran on every settings open, every skin change and every category toggle, orphaning a full panel each time. Replaced by `LayoutTabs`: tabs and content frames are pooled and reused, each tab's widgets are built lazily on first activation (`buildContent`) and never rebuilt. Surplus tabs are parked when a window is removed.
- **New**: `frame.Refresh()` (tab relayout + widget value refresh) replaces the rebuild at every call site. Registered widgets re-read the DB through their existing `Refresh` methods; accent-tinted section labels are re-tinted in place. `frame.RebuildTabs` is kept as an alias.
- **Changed**: the meter-type dropdown resolves its option list on click, so enabling / disabling a category is reflected without touching the panel structure.
- **Changed**: the bar-texture dropdown now reads `ns.GetTextureList` live. Previously the list was captured when the panel was first built, so LibSharedMedia textures registered by addons loading after TomoDamageMeter never appeared.
- **Removed**: unused `windowMgmtIndex` local.

### Config/Widgets.lua
- **New**: `ns.Widgets.CreateDropdown` accepts a function in place of a static option array, evaluated on each read. This is what makes the live meter-type and texture lists possible.
- **Fix**: the click handler declared `local next = ...`, shadowing the global `next` inside the closure. Renamed to `nextIdx`. Empty option lists are now a no-op instead of a modulo by zero.

### Core/Utils.lua
- **Fix**: `ns.FormatNumber(value, "full")` routed to `AbbreviateLargeNumbers`, which performs its breakpoint comparisons in Lua and therefore errors on a secret value mid-combat. It now uses `AbbreviateNumbers` with a pass-through breakpoint table (`OPTS_FULL`), consistent with the other three formats. This path was reachable in normal play — see the Database fix below.
- **Changed**: the sub-1000 branch for `"full"` returns `%.0f` rather than `%.1f`, matching what "no abbreviation" is meant to show.

### Core/Database.lua
- **Fix**: the legacy-column migration seeded missing formats from an inline `{ rate = "full", total = "full" }` table that contradicted `ns.DEFAULT_COLUMNS` (`"1dec"`), pushing every pre-fmt saved variable set onto the crashing `"full"` path. Defaults are now derived from `ns.DEFAULT_COLUMNS`, and any saved format not present in `ns.FORMAT_OPTIONS` for its column is discarded and reseeded.

### Modules/SpellBridge.lua
- **Fix**: `timestamp` was the only field in `ns.GetDeathRecap` copied out without an `issecretvalue` guard. It is now guarded like the rest and left `nil` when unreadable.

### Modules/DeathRecap.lua
- **Fix**: `Populate` computed `deathTime - ev.timestamp` and fed the result to `string.format`, so a secret timestamp reached Lua arithmetic and errored out of the whole recap. Both timestamps are now checked; when either is missing the row shows the spell name without the time-before-death prefix instead of failing.

### TomoDamageMeter.toc
- Version bumped to 1.6.3.

## v1.6.2

### Core/Utils.lua
- **Fix (regression from 1.6.1)**: mid-combat values were displayed as `"..."` / `"(...)"` in every column. The secret-value guard added in 1.6.1 was wrong: under Midnight, `AbbreviateNumbers` is secret-tolerant (C-side) and its output renders fine through text setters — confirmed against EUI StandaloneDamageMeters, which passes secrets straight into `AbbreviateNumbers` with no guard. `ns.FormatNumber` now only skips the sub-1000 Lua formatting branch for secrets (Lua comparison/format would error) and routes them to `AbbreviateNumbers`, restoring the 1.6.0 display. The `nil` guard is kept (returns `"0"`).

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