# Changelog — MyCustomFrames (Gonkast Preset)

Notable changes per session. Older history lives in `STRUCTURE.md`, which documents
*why* things are the way they are (including approaches that were tried and reverted —
worth reading before redoing one of them).

## Unreleased

### Added
- **Sort mode, max icons and icon padding, configurable per group, for all 5 hover aura
  displays** (Player/Target/Focus/Party/Arena) — new controls in each group's options
  section. Sort has 3 modes: `priority` (debuffs before buffs, current default behavior),
  `time` (ignore type entirely, soonest-to-expire first across the mix), and `index`
  (Blizzard's native order, no reordering — for when the sort feels too jumpy). Max icons
  is 1-8 (was a fixed 4); the icon pool is always pre-created at 8 so raising the limit
  later doesn't need a `/reload`. Padding is the gap between icons in the row (0-20,
  separate from the existing "how far from the unit frame" gap). All 3 default to the old
  fixed behavior (priority sort, 4 icons, 4px padding) — nothing changes unless touched.
- **`/mcfaurahoverdiag [key]`** — dumps the live internal state (hover/target/combat/cast/
  gate/carrier alpha) of any hover-aura group. Built to chase down a report that the
  player group stays visible after the mouse leaves — the code reads correctly on two
  passes with no bug found, so this gets real data instead of a third guess.

### Changed
- **Hover auras hide the instant the mouse leaves, no more 0.35s grace period.** That delay
  existed on purpose (avoid cutting off abruptly if the mouse just grazed past), but felt
  slow compared to how fast reveals from combat ending already were. The fade itself is
  still smooth — only the moment it *starts* changed, from delayed to immediate.
- **Player Auras: simplified to always visible, matching Target.** Went through three
  shapes the same day (target-gated, then hover-with-combat/cast-needing-a-target) before
  landing here — none of them behaved the way it was wanted in practice, so all the
  conditional logic (hover/combat/cast/target checks) was dropped. Player now just shows
  all the time, same as Target always has, no mouseover or target required.

### Added
- **Remaining-time countdown number on hover aura icons**, on top of the priority sort
  (debuffs first) and dispel-type border color already there. The swipe cooldown was
  already fed by the secret-safe `C_UnitAuras.GetAuraDuration` duration object — it just
  had its countdown text explicitly hidden; flipping that one flag was enough to show it.

### Added
- **Aura icons now sort by soonest-to-expire within their debuff/buff category**,
  on top of the existing debuff-before-buff priority. Only actually reorders where the
  game exposes a readable duration — Player's own auras always qualify; other units'
  raw `expirationTime`/`duration` are secret in Midnight (same reason the countdown swipe
  reads a duration object instead), so a `type()`+`issecretvalue()` guard makes those
  fall back to the game's native order instead of risking a crash on the comparison.

### Fixed
- **Hiding the player unitframe via Explorer took nearly a second to also hide its
  auras.** The gate checked the frame's live alpha against 0.05, but Explorer's fade is
  exponential (half-life ~0.20s) — the tail near zero crawls, so crossing under 0.05 took
  ~5 half-lives. Raised the cutoff to 0.5: same signal, but it reacts after one half-life
  instead of five, in both directions (hiding and revealing).
- **Player auras stayed visible even when Explorer had faded the player unitframe out.**
  `gateFn` was a hardcoded `true`, with no awareness of Explorer at all. Now it reads the
  player unitframe's live alpha (via `ns.GetElementFrame("player")`, from Explorer.lua)
  and gates on it being above ~0.05 — covers Explorer's fade-to-hidden-opacity, and any
  other reason that frame might be near-invisible, without hooking into Explorer's
  internals directly.
- **Player/Target auras showed empty (no icons) until you moused over them once.**
  They fade in on their own (`alwaysShowOnGate`), but the ticker only ever called
  `RefreshIcons()` — the part that actually pulls live aura data onto the icons — while
  in combat, casting, or moused over. Outside all three (the common case for an
  always-visible group), the carrier faded to full alpha with nothing drawn on it.
  Icons now refresh every tick whenever the group is actually visible, regardless of why.
- **Test mode didn't actually reveal anything for Player/Target/Focus, and likely explains
  the "Player never hides" report too.** `testMode` fed into whether the group was
  *allowed* to show (`gateOk`), but was never itself a *reason* to show — toggling test
  mode set `target = 1` directly, but the very next `Recompute()` call (the ticker runs
  every 0.3s) reset it back to 0, since nothing else was actually true. Party/Arena rarely
  hit this in a short test session since little else triggers a recompute; Player's
  cast-state check runs every tick, so it broke there reliably — and if test mode got
  left on from an earlier check, that alone would explain a group staying visible
  indefinitely.
- **Hover auras sat too close to the unit frame**, clipping into the name text (direction
  "up") or the power bar (direction "down"). Base gap bumped from 4 to 25px over several
  passes — shared by all 5 groups, no per-group override exists for this specifically.
- **Target hover aura never disappeared after losing target.** The ticker only forced a
  recheck on losing its reveal condition when you were actively hovering — true for
  Party/Arena/Focus/Player, whose only reveal paths are hover/combat/cast, but not for
  Target, which can be revealed via `alwaysShowOnGate` with no hover involved. Losing your
  target while not moused over it never re-evaluated anything, so it stayed visible
  forever. Now any gate transition, in either direction, forces a recheck.
- **`Options.lua:555: attempt to index a nil value`, still happening after the first fix.**
  The real root cause was one level deeper: `ns.CurrentProfile()` (`core.lua`) already had
  this exact problem solved for `aura_party`/`aura_arena`/`classpower` — SINGLETON keys
  with no `db.units`/`db.auras` table of their own return a nil-safe empty table, because
  hidden widgets from *other*, unrelated tabs still run their refresh callback on every
  selection regardless of which section is visible. `aura_focus`/`aura_player`/
  `aura_target` never got the same treatment when they were added, so selecting any of
  them crashed *any* hidden widget from *any* tab, not just aura-related ones — deleting
  the dead grid UI only removed one source of the crash, not the general case. The old
  always-visible aura grid's settings UI (border/duration/position/etc. for the
  since-removed Player/Target groups) was left in place as "unreachable" after the move to
  hover auras, on the assumption that dead code was harmless if nothing navigated to it.
  It wasn't: its widgets register refresh callbacks in a list that runs on *every* panel
  interaction regardless of which section is visible, and with `ns.auras` now empty their
  lookup returned `nil`. Removed the whole block instead of leaving it inert.
- **`LUA_WARNING`: `BuildPanel` (Options.lua) over Lua's 60-upvalue limit.** Adding the
  Player/Target Aura section helpers tipped it over. Removed those 2 named functions and
  inlined the prefix check at their handful of call sites instead of adding 2 more
  upvalues to an already-large function — the other 12 section-prefix helpers are
  untouched.
- **Focus was double-registered.** The revert to Player/Target-only rewrote the comment
  above the `AURAS` table but missed the actual `aura_focus` entry underneath — Focus kept
  showing both the always-visible grid and the new hover display until this was caught.
- **Hover auras (party/arena/focus) at half opacity in combat.** They were meant to reveal
  automatically in combat, but the alpha was still multiplied by 0.5 whenever
  `PlayerInCombat()` was true — even at full reveal, they showed at 50%, not 100%. All
  three groups share the same code path, so one fix covers all three.

### Added
- **Player and Target auras moved to the hover display too**, joining Focus/Party/Arena —
  `Auras.lua`'s always-visible grid is gone. Each keeps a reveal condition suited to it:
  - **Target** — always visible while you have a target (not just on hover, since the
    whole point is having it ready without needing to mouse over).
  - **Player** — always visible, no target or mouseover required (see "Changed" above —
    landed here after a couple of conditional designs that didn't feel right).

  New options sections ("Player Auras"/"Target Auras"), `/mcfplayerauratest` and
  `/mcftargetauratest`. `Auras.lua` is down to just `ns.DebuffTypeColor` — the piece all
  5 hover groups still share — everything else it used to do (the grid itself, dual
  positioning, click-to-cancel) is gone with it, since nothing calls any of it anymore.
- **Low-health percent color for Focus.** It was left out of the earlier rollout (opt-in
  by choice at the time); on by default now, migrated once for existing saves the same way
  the other units were, under its own one-time flag since the original backfill had
  already run for this account.
- **Focus auras**, on `AuraHoverPreview.lua`'s hover-triggered display — same one already
  used for Party (dungeon-only) and Arena (arena-only): up to 4 icons, debuffs prioritized
  over buffs, revealed on mouseover or automatically while you're in combat. Gated on
  simply having a focus target set, since — unlike Party/Arena — Focus is useful in any
  content. New options section ("Focus Auras"), `/mcffocusauratest` to preview without a
  live target.

  This landed after two false starts the same day, both worth remembering: Focus was
  first added as a fourth always-visible `Auras.lua` group (like Player/Target) alongside
  Party1-5 and 6 arena groups — reverted once it was clear several of those duplicated a
  unit already shown elsewhere (`party5`/`arena_player` are both `unit="player"`;
  `arena_party1`/`arena_party2` are the same `party1`/`party2` on their own frames), and
  then Focus itself moved here once it became clear `AuraHoverPreview.lua` was the
  correct home for a secondary, non-always-needed indicator like this — matching Party
  and Arena — rather than a second always-visible grid competing with Player/Target's.
  `Auras.lua` is back to its original two groups.
- **Aura sort by priority + debuff-type border colors.** Player/Target (`Auras.lua`) get
  a new "priority" sort — debuffs before buffs, ties broken by remaining time — now the
  default (was "timeUp"), plus debuff borders colored by dispel type (Magic/Curse/Poison/
  Disease, standard Blizzard colors; generic red for non-dispellable) instead of a flat
  color; buffs are unaffected. Sort has a dropdown with the old options still available,
  color can be turned off (`colorDebuffByType`).

  The Party/Arena/Focus hover display already had debuff priority; it gets the same
  per-type coloring too, upgraded from a plain red/gold split. Both systems share one
  lookup (`ns.DebuffTypeColor`, defined in `Auras.lua`, which loads first) instead of
  keeping two copies of the color table.
- **Explorer → Quick profiles.** A new third tab next to Elements/Conditions, three
  one-click buttons that replace which elements Explorer manages:
  - **Exploration** — hides almost everything, keeps minimap, your unit frame, portrait,
    info bar and micro menu always visible.
  - **Combat** — only the action bars fade out and reveal automatically when you enter
    combat (also enables "Always show in combat"); everything else stays visible.
  - **Minimal** — hides everything, no exceptions.

  Only touches Elements membership (never Conditions, aside from Combat's auto-reveal) —
  picking a profile doesn't lose your opacity/target/casting/zone settings.

  The same three buttons (compact, one line each) are also on the Setup Wizard's Explorer
  page, so a fresh install can start from one without opening the main panel first.
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
- **Native minimap icons (tracking, player arrow) not fading with the minimap.** Blizzard
  draws those with `SetIgnoreParentAlpha` — no alpha call reaches them, and `Minimap:Hide()`
  is a protected call in this client. The only lever left is position: the native `Minimap`
  widget now moves off-screen while Explorer has it hidden, and snaps back the instant it's
  revealed. `root` (the drawn backdrop/ring/border) never moves and keeps its normal smooth
  fade — only the native widget's position is binary, so the icons pop rather than fade.
- **Group-finder eye icon not fading with the minimap.** `QueueStatusButton` lives in its own
  frame (`eyeHolder`), deliberately kept out of the minimap's frame tree to avoid tainting it
  (see `LayoutEye` in `Minimap.lua`) — so it never inherited Explorer's fade. Now synced by
  hand, same fix already used for 3D portrait models.
- **Options panel clashing with the new-mail banner.** Both were on the `HIGH` frame strata,
  so which one drew on top was arbitrary. The main panel moves up to `DIALOG`; the Setup
  Wizard, the Lock-mode panel, and the nameplate designer — all reachable while the panel is
  open, all previously placed one strata above it on purpose — move up to `FULLSCREEN` so
  they keep rendering above it instead of tying with it.

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
