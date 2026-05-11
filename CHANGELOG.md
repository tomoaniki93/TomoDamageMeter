# Changelog

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