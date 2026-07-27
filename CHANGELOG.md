# Changelog — MyCustomFrames (Gonkast Preset)

Notable changes per session. Older history lives in `STRUCTURE.md`, which documents
*why* things are the way they are (including approaches that were tried and reverted —
worth reading before redoing one of them).

## Unreleased

### Added
- **Module registry + `/mcfdiag verify`.** A passive registry now describes the persistent
  modules, their DB key and public APIs. `verify` checks that each one is initialized and
  included in presets/export/reset, without calling protected frame APIs.
- **Secret-safe low-health percent color.** Health text now renders only its percentage red at
  or below 40%, using Midnight `ColorCurve`/`C_ColorUtil` instead of comparing secret health in
  Lua. The absolute value keeps its configured color. On by default for every health unit
  (player, pet, target, ToT, party, boss, arena) — existing saves are migrated once, so turning
  it off by hand sticks across `/reload`.

### Documentation
- **All 32 slash commands are listed in the README**, up from 6. Split into commands you'd
  actually use, the handful of elements still driven from chat because they have no menu
  section yet, and the diagnostics — with `/mcfdiag` called out as the entry point so the
  list doesn't have to be memorized.
- Corrected a comment in `Setup.lua` that referred to `ns.ApplyBartenderAutoProfile`. The
  function is a file-local in `ProfilesApply.lua` and was never exposed on `ns`.

### Fixed
- **`ADDON_ACTION_BLOCKED` from the pet bar.** Hiding the Bartender4 pet bar when you have no
  pet called `EnableMouse` without checking for combat. It now defers to
  `PLAYER_REGEN_ENABLED`, same as the bar-scaling code alongside it.
- **Same bug in the native-frame hider.** `HB_HideAlpha` called `EnableMouse` on Blizzard's
  protected arena/party frames, and `HideArenaFramesNow` deliberately runs *during* combat
  (an arena match is in combat almost end to end), so the ticker was spamming the error every
  third tick. The `SetAlpha` that does the actual hiding is genuinely combat-safe and stays
  unguarded; only `EnableMouse` is deferred.

  A comment in `core.lua` had asserted that `EnableMouse` was safe on protected frames. It
  isn't — that belief is what put both bugs there. Corrected in place.

## 8.1 — 2026-07-25

### Added
- **Automatic backup before destructive actions.** `Reset ALL` and `Apply addon profiles`
  now save a `~ Auto-backup (before reset)` preset first. Restore it with `/mcfundo` or by
  loading it from the profile list. One level of undo (a full history would grow
  SavedVariables without bound).
- **`/mcfskincheck`** — validates that the active skin ships every file the skin system
  expects (the `SKINNABLE` whitelist + `MasqueSkin\`) and lists what's missing. Needed
  because a missing file renders **invisible** with no other clue.
- **`/mcfdiag`** — single router for the diagnostic commands, and the only way to *discover*
  them (`/mcfdiag` with no argument lists what's available).
- **Dead-key purge** — fields left behind by removed features are cleaned from the saved DB
  (and from saved presets) once per session, instead of lingering forever.
- Bartender4 action bars can be managed by Explorer Mode, and are covered by the
  resolution auto-scale.
- Minimap masks (`minimap-mask-transparent`, `minimap-mask-opaque`) are now skinnable.
- Game Menu (ESC) skin merged in from the standalone `Mainmenu-Gonkast` addon, and it
  follows the active skin.

### Changed
- **Skins now use an explicit whitelist.** Only the 25 listed filenames are looked up in the
  skin folder; everything else always comes from the addon's own `Assets\`. A skin must
  ship all 25 plus a complete `MasqueSkin\` — there is no per-file fallback.
- Explorer Mode: one shared element registry (`ns.EXPLORER_ELEMENTS`) for both the options
  panel and the setup wizard, +18 elements, per-element hidden opacity, and a scrollbar in
  the Elements/Conditions tabs.
- Setup wizard: dropped from 8 pages to 7 (the quest tracker page is gone) and the Explorer
  page is now just an on/off toggle plus a description.

### Removed
- `hideWhenMounted` (all units), the aura hover-fade, the Bartender4 mounted-bar reposition
  (`BarReposition.lua`), and the tracker wizard page. Explorer Mode replaces them.

### Fixed
- Resolution auto-scale (`ns.ResScale`) for 16:9, applied to every root widget and to
  Bartender4's bars. The quest tracker is deliberately excluded: Edit Mode repositions it
  with its own logic, so scaling it only fights that system.
- Raid frames: growth direction now applies to the real header, not just the Lock preview;
  the preview no longer lingers on top of real frames; `SetSize`/`SetAttribute` no longer
  get blocked when the roster changes mid-combat.
- Native Blizzard frames hidden by alpha now also get `EnableMouse(false)` — invisible
  frames were still stealing hover and clicks (visible in arena via `/fstack`).
- Minimap button group: captured buttons are normalized to one strata, and the container no
  longer swallows its own children's clicks.
- Aura tooltips work again for Explorer-managed groups.
- Game Menu background is sized after the frame is laid out (it came out small after
  `/reload`).
- Explorer → Conditions: the footer note no longer overlaps the zone toggles.

## Earlier

See `STRUCTURE.md` — every session before this one is documented there in detail, including
the reasoning behind decisions and the dead ends.
