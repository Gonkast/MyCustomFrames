# Changelog — MyCustomFrames (Gonkast Preset)

Notable changes per session. Older history lives in `STRUCTURE.md`, which documents
*why* things are the way they are (including approaches that were tried and reverted —
worth reading before redoing one of them).

## Unreleased

### Added
- **`/mcfnpobjdiag`** — dumps unit/GUID-prefix/name/`IsObjectNameplate` result for every
  currently visible nameplate. Built after a report that object nameplates were still
  getting skinned even after the `IsObjectNameplate` fix ("Hall of the High Command", a
  dungeon-entrance-looking plate) — rather than guess a second GUID-prefix assumption
  blindly, this gets real data on what that plate's GUID actually looks like.
- **Range fade and shield (absorb) bar for Player/Target/Focus/Party/Arena**
  (`Indicators.lua`, new file, loads before `Units.lua`). Secret-safe using patterns
  already proven elsewhere in the addon: range uses `UnitInRange`; the shield bar hands
  `UnitGetTotalAbsorbs`/`UnitHealthMax` straight to a native `StatusBar`
  (`SetMinMaxValues`/`SetValue`) without ever reading them in Lua, same as the existing
  cooldown/cast-timer widgets. The shield bar reuses each unit's own `texture`, re-read
  live every tick, so per-unit texture differences (and future texture changes) are
  picked up automatically. Not yet exposed in Options.lua — always on for now.
  **`/mcfindicatortest`** toggles both forced-on for every tracked unit that currently
  exists, so they can be previewed without needing to actually be out of range or get
  shielded. A dispel-glow indicator (borde recoloreado por debuff dispelleable) was also
  built and shipped briefly, but got pulled — no clear way to trigger/test it in
  practice; see git history if it's worth revisiting later.
- **Loss of Control icon** (`LossOfControl.lua`, new file) — shows on the player portrait
  (bottom-right corner, the slot `portrait_player` never uses since it has no role/leader
  badge) whenever you're stunned/silenced/rooted/feared/etc, with a cooldown swipe for how
  long is left. Uses `C_LossOfControl.GetActiveLossOfControlData` — always your own data,
  never another unit's, so no secret-value concerns here at all. `/mcfloctest` toggles a
  fake 6-second placeholder to preview it without needing a real CC.
- **`/mcftrinkettest`** (`ArenaTrinket.lua`) — fakes the arena trinket (Gladiator's
  Medallion) cooldown state on all 3 arena enemy frames and redraws the icon, so the
  draw path (size/position/whether `showTrinket` is even on) can be checked without a
  real opponent using their trinket. Doesn't test the *detection* itself (whether the
  tracked spellID still matches this build) — only a live match confirms that. Needs
  Lock/Edit mode (`/mcf`) too, since arena frames are otherwise hidden outside a real
  match.
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
- **Hover aura text (countdown number + stack count) is smaller and gold now**, matching
  the rest of the addon's text color (`ns.GOLD`) instead of Blizzard's default
  white/whatever-size countdown font. The countdown number needed its own font object
  (`SetCountdownFont`) — a dedicated one, not the one `Nameplates.lua` already uses for
  the same purpose on nameplates, since sharing it would have the two systems fight over
  its size/color.
- **Threat/aggro indicator was pulled.** Went through 4 versions the same day (scaling
  the native `aggroHighlight` glow, copying its rendered color onto the health bar,
  reading `UnitDetailedThreatSituation` directly on a per-frame `OnUpdate`, then finally
  a `hooksecurefunc` hook on `SetStatusBarColor` to win the race against Blizzard's own
  native recolor) — the last version should have worked (same override pattern this file
  already uses for `LockSize`/`LockBar`), but the user still saw no visible change, so it
  got removed rather than debugged further. `SkinThreat`'s original one-time texture
  swap on the native highlight (pre-existing, from before this session) is untouched.
- **Reorganized the Nameplates options menu** ("reacomoda el menu de nameplates") — the
  "Gen" tab had grown to 4 stacked groups (General, Range, Name-only mode, Enemy player
  class colors) and the panel has no scroll, so the last checkbox was getting clipped by
  the bottom button row. "Name-only mode" and "Enemy player class colors" (the two
  longest groups, both about name color/visibility) moved to a new "Names" tab; "Gen" is
  back to just General + Range.
- **Enemy player nameplate class colors** (`Nameplates.lua`), off by default — matches
  the native "Color-Coding Enemy Nameplates" capability Blizzard re-enabled in Midnight,
  but implemented as our own name-color override rather than the native
  `ShowClassColorInEnemyNameplate` CVar: this addon draws its own name text in place of
  Blizzard's, so that CVar has nothing left to color. Reuses the existing
  `GetClassColorForUnit` helper already used for the friendly name-only mode, scoped to
  hostile *players* only (never NPCs — `UnitIsPlayer` gates it before even trying).

### Fixed
- **Nameplate Designer didn't match the real nameplate 1:1** — the reference scale was
  never actually sampled. Root cause found by *measuring* instead of reasoning, after
  three reasoned fixes in a row failed: `designerRefScale` was `nil` in the live profile
  while real nameplates were running at `GetEffectiveScale() = 0.768`, so the panel fell
  back to **1.0** and drew the health bar ~30% too large relative to everything else. The
  cause was pure timing — the scale is sampled when the Designer opens, and the natural
  order is to open the panel *and then* target something, so at that instant there was no
  plate to sample from and nothing got persisted. There is now a **bounded retry**: while
  no real reference exists, it re-checks every 0.5s until it gets one (or gives up after
  20s), then stops for good. This is deliberately *not* the old scale ticker that was
  removed for making the canvas jump — it settles once, at the start, and never re-scales
  while you're editing.

  Worth knowing, because it's a genuine limit and not a bug: **there is no single "1:1"**.
  The health bar is a plain child of the plate and shrinks with distance, while the name
  and aura holders get `SetScale(1/effScale)` so they stay at constant screen size (that's
  what keeps text and icons crisp). So the *proportion* between them really does change as
  a mob gets closer or farther, and the panel can only match one distance at a time —
  whichever the **Reference scale** slider is set to. `Sample` sets it from the plate
  you're currently looking at, which is normally what you want.
- **`/mcfnplayoutdiag` was built to compare something that can't be read.** Its first
  version compared each element's *position* relative to the health bar. Measured in vivo
  on a real nameplate, `GetRect`, `GetLeft`, `GetBottom` and `GetCenter` are **all**
  blocked (`Can't measure restricted regions`); only `GetWidth`, `GetHeight` and
  `GetEffectiveScale` answer. Position-vs-position verification is therefore impossible on
  this client, and the helpers that attempted it were deleted rather than left around
  implying the data exists. The command now compares the one thing that both matters and
  is measurable — real effective scale vs the panel's reference scale — and prints the
  fix when they diverge. Since geometry moved into `ns.NPLayout`, both sides apply
  identical offsets by construction, so scale is the only remaining way they can disagree.
- **`LUA_WARNING: function at line 1396 has more than 60 upvalues`.** `BuildPanel` had been
  sitting at exactly 60 — Lua 5.1's hard ceiling — for a while, and the aura-hover move
  earlier this session pushed it to 61, where it stayed for several commits before being
  noticed. Traced with `luac -l -p` rather than guessing: **14 of the 61 were
  `IsXxxSection` helpers**, one-line prefix checks, all used in a single place (the
  section-family description table). Inlining the prefix comparison there drops
  `BuildPanel` to **47**, so there's real headroom again instead of being one addition away
  from breaking. The helpers still exist and are still used from `SelectUnit`/`ShowSection`,
  which have their own budgets.

### Changed
- **Nameplate geometry now has a single source of truth** (`NameplateLayout.lua`, new file).
  The layout existed **twice**: `Nameplates.lua` positioned the real elements and
  `NameplateDesigner.lua` re-implemented the same maths for its mock, kept in sync by hand.
  That never held — the panel repeatedly failed to predict the game, and each targeted fix
  ("make the mock match") uncovered another difference: first the name gap, then the scale,
  then the anchor. With two implementations there's no end to it, since any future change
  to one silently desyncs the other and the bug is only visible by *looking at the game*,
  never by reading the code.
  The new module returns pure numbers — anchor point, offsets, sizes, and which of the two
  scale regimes an element belongs to — and touches no frames. Both consumers apply the
  same values, so they can't diverge again. It also absorbed three duplicated constant
  tables (`AURA_ANCHOR_POINT` existed in *both* files, plus the offset/direction key maps).
  Two concrete bugs fell out of the merge: the Designer anchored the name to the **health
  bar** while the real one anchors it to the **nameplate**, and the aura gap was written in
  both files independently.

### Fixed
- **Designer positions didn't match the real nameplate** — personal debuffs sat far from the
  plate in game while looking close in the panel. A real nameplate runs **two scales at
  once**: the health bar, cast bar, classification and raid mark are plain children of the
  plate and shrink with distance, while the name and the three aura groups are
  counter-scaled (`SetScale(1/effScale)`) so they stay a fixed on-screen size. The Designer
  modelled this with two divisors whose only difference was `stageScale` — and pinning that
  to 1 (the fix below, for the canvas rescaling itself) collapsed both to the same value,
  so the panel drew everything at one scale. With nameplates running at ~0.64, the bar was
  ~36% larger relative to the auras than it really is.
  `stageScale` is now a **reference scale**: sampled once from a real nameplate the first
  time the Designer opens, saved, and never changed on its own afterwards — so proportions
  are truthful *and* the canvas still doesn't move while you work. A **Reference scale**
  slider plus a **Sample** button make it explicit, and it's separate from Panel zoom
  (which magnifies everything equally for comfort). Exact 1:1 at every distance isn't
  possible — real scale follows distance — so this is 1:1 at a reference distance you pick.

### Changed
- **The Nameplate Designer canvas no longer mirrors your target's scale.** A ticker read the
  target nameplate's effective scale every 0.2s and applied it to the canvas, so the editor
  would rescale itself while you worked — on picking a target, on losing one, or just from
  walking, since nameplate scale follows distance. The same edit looked different one
  second to the next, which made changes hard to judge. The canvas now always shows scale
  **1.00**, and the only thing that changes its size is the explicit **Panel zoom** slider.
  Removing the ticker also retires `anyDragActive`, which existed solely to freeze that
  scale mid-drag so the dragged piece wouldn't tug against the cursor.
- **Section "Preview" buttons.** Each section that has a preview now has its own button next
  to the controls it affects, scoped to that group, and it stays visibly lit while the
  preview is on — a forgotten test mode is now something you can see rather than invisible
  state toggled from chat (which bit this session: auras that "wouldn't hide" were a stuck
  `testMode`). Replaces the single **Test Aura Hover** button in the footer, which was
  global and had gone stale: it toggled Party+Arena only, so once Focus/Player/Target
  joined the same system it silently previewed 2 of 5 groups. `ns.ToggleArenaTrinketTest`,
  `ns.ToggleIndicatorTest` and `ns.ToggleLossOfControlTest` are exposed for it, with the
  slash commands now routing through the same functions.
- **All ~40 slash commands are discoverable in-game now.** The `/mcfdiag` router existed but
  only 4 commands were registered with it; the other 36 could only be found by reading the
  README. Everything is registered now, and the listing is grouped rather than one flat
  alphabetical wall: **diagnostics** (read-only state dumps), **previews** (toggles that
  change what you see — labelled as such, since running one and not knowing it stays on is
  its own trap), and **other commands** that open windows or change settings, listed for
  reference but not run through the router. Registration is centralised in
  `Maintenance.lua` and resolves the handler lazily at call time, so 15 files didn't need
  their anonymous handlers refactored into named functions, load order doesn't matter, and
  a command removed later reports itself instead of erroring.
- **The options panel's section area scrolls now.** It never did: each section was a plain
  frame pinned to the edge of the content area, so anything that didn't fit was clipped —
  no error, no scrollbar, no way to reach the control. It had already forced splitting
  sections into extra tabs purely for room (the Nameplates "Alpha" and "Names" tabs both
  exist for that reason), and the most recent case was a checkbox hidden behind the bottom
  button row. Adding options no longer has a ceiling.
  Since sections declare no height — every control is hand-placed at a negative Y offset —
  the height is measured from the lowest rendered element each time a section is shown,
  walking children recursively (composite controls like sliders park their label and edit
  box as children) and counting only what's visible, so sections that hide widgets per unit
  don't scroll into empty space. Mouse wheel plus a thin draggable bar that stays hidden
  when everything fits, which is most sections.
- **Setup Wizard page 2 now states the recommendation in yellow**, above the red warning:
  ticking all of them is what the preset is designed around, and nothing is pre-selected on
  purpose so you have to tick them yourself. Without this the opt-in change below reads as
  "leave it empty" — which gives a half-applied look and no way to tell that was the wrong
  call.
- **Bundled third-party profiles are now opt-in, not opt-out.** Setup Wizard page 2 used to
  pre-tick every detected addon and say "untick any you DON'T want replaced" — so the
  default path, clicking Next without reading, permanently destroyed the user's
  Bartender4 / DynamicCam / Masque / Chattynator configuration. That's fine on a personal
  install where you made the bundled copies yourself; it isn't something to ship. All
  boxes now start **unticked** (ticking nothing is safe and changes nothing), with a red
  warning that this overwrites the addon's entire config and cannot be undone — `/mcfundo`
  only ever covered `MyCustomFramesDB`, since you can't write another addon's
  SavedVariables from your own. The standalone "Apply Profiles" button's confirmation was
  reworded the same way; it applies to every detected addon at once with no per-addon
  choice, so it needed the warning even more.
- **Stripped personal character data from the bundled third-party profiles.** `Masque.lua`
  shipped a `profileKeys` map of **36 character names across 4 realms**, and
  `Bartender4.lua` had one left in `LibDualSpec-1.0.char`. These are per-character
  pointers, not settings, and no configuration was lost: Masque still has all 456 skin
  groups, Bartender4 all 11 namespaces, zero differences in the actual profile data.
  Chattynator's "Gonkast" profile was **left alone** on purpose — it's the author/brand
  name (already in the addon title) and it holds 7 real settings that differ from its
  DEFAULT profile, so removing it would have lost configuration.
  *(Correction: an earlier version of this entry claimed AceDB falls back to "Default" for
  unlisted characters. It doesn't — see the `bartenderAutoProfile` fix below.)*
- **`Defaults.lua` regenerated from a fresh export.** Picks up everything this session
  added: all 25 hover-aura settings across the 5 groups (direction/size/max icons/padding/
  sort — 21 of them brand new to the baked defaults), `classColorEnemyNames`, and the
  expanded Explorer element selection. Verified against the previous file: **zero keys
  lost**, every module sub-table the same size except the two that were meant to grow.
  The dead aura-grid entries (`auras.aura_player`/`aura_target`) are gone, since the new
  purge cleared them before the export was taken.
- **Baked new nameplate range/alpha defaults**: max distance 40 → **60**, max alpha
  0.6 → **0.80**, min alpha **0.20**. Also forced onto `nameplateUserDefault` during the
  bake — the export carried the user's live snapshot of it (10 / 1 / 0), and that's what
  "Reset nameplates" restores, so shipping it as-is would have made Reset drop render
  distance to 10 yards and contradict the shipped default immediately.
- **Explorer ships disabled by default** (`explorerEnabled = false`), per request.

### Fixed
- **Every new character came up without the Bartender4 layout, so the setup had to be
  redone per character.** `bartenderAutoProfile` — the setting whose entire job is "use
  this profile for any new character on the account" — shipped as `nil`, i.e. off unless
  you found it on wizard page 7 and enabled it by hand. Without it, a character with no
  entry in `profileKeys` hits AceDB's fallback chain (`sv.profileKeys[charKey] or
  defaultProfile or charKey`) and, since Bartender4 calls `AceDB:New` with no
  `defaultProfile`, ends up on its **own empty profile named "Name - Realm"** rather than
  the preset's. Now defaults to `"Default"` and is baked into `Defaults.lua`. Still safe:
  the profile is only forced on characters that were never configured (current profile
  still equals the character key) and only once each, so a manual profile choice is never
  overwritten.
- **…and the auto-apply marked characters as done even when it hadn't worked.**
  `bartenderAutoApplied[charKey] = true` was set unconditionally, including when
  `SetProfile` had no effect — and since that mark blocks all future retries, an affected
  character could never fix itself. Found by comparing the author's real saved data: **8
  characters marked applied, only 6 actually present in Bartender4's `profileKeys`** — two
  flagged "done" with no profile, which is exactly the "I have to redo it per character"
  report. The profile is now read back after setting and the mark is only written if it
  actually took, so a failure retries on the next login. Existing marks are cleared once
  so the two stuck characters get their retry; a manually chosen profile is still detected
  and respected rather than overwritten.
- **Audit pass: removed dead call sites left behind by the aura-grid removal.** When
  `Auras.lua` was stripped down to just `ns.DebuffTypeColor` this session, four call sites
  in `core.lua` were left calling functions that no longer exist
  (`ns.EnsureCancelOverlay`, `ns.UpdateAuraGroup` ×3) with no nil-guard. They never fired
  — the `auras` runtime table is permanently empty now — but they were landmines: the day
  anything repopulated it, they'd have thrown "attempt to call a nil value". Also dropped
  `core.lua`'s blanket `UNIT_AURA` registration, whose only handler was one of those: it
  was waking that frame on one of the game's highest-frequency events to do nothing.
  (`ArenaTrinket.lua`/`ClassPower.lua` register `UNIT_AURA` on their own frames and are
  unaffected.) Plus the now-dead `ns.TickAuras` per-tick call and `ns.RefreshAllAuras`.
- **`PurgeDeadKeys` couldn't clean keys inside module sub-tables**, only `db.units[*]` and
  the root of `db`. That left no way to retire a setting belonging to a module like
  nameplates or minimap. Added a nameplate-scoped list (applied to the live DB *and*
  saved presets), and populated both lists with this session's abandoned experiments —
  the 7 per-unit `dispelGlow*` fields and the 3 `threat*` nameplate fields — so anyone who
  ran an intermediate build doesn't keep carrying them in their saved config or exports.
- **`db.auras` was never purged either, and was still carrying the entire removed aura
  grid** — `aura_player` and `aura_target`, ~54 config fields each, found by inspecting a
  real export (108 dead fields riding along in every export and preset). Nothing has read
  them since `Auras.lua` was reduced to `ns.DebuffTypeColor`; the hover display keeps its
  settings in flat globals (`playerAuraDirection` etc.) instead. Now purged as whole
  entries, live DB and saved presets alike.
- **Pet action bar reappeared (even without an active pet) when toggling Explorer mode
  on/off, needing a `/reload` to hide it again.** Same bug class already fixed once
  (2026-07-25) for entering/exiting Lock mode, but through a different path this time:
  `ns.ExplorerResetAll()` force-sets alpha 1 on every Explorer-managed element, including
  `BT4BarPetBar` — undoing the "no pet, stay hidden" state from `BartenderScale.lua` — and
  3 separate call sites do this without ever reapplying it afterward: `Explorer.lua`'s
  central ticker (`TickExplorer`, fires whenever the master toggle or a zone filter turns
  Explorer off), and 2 checkbox handlers in `Options.lua` (the master switch, and each
  per-zone toggle). All 3 now call `ns.RefreshPetBarVisibility()` right after — same fix,
  applied everywhere the underlying reset can happen instead of just the one path that
  was reported last time.
- **Shield bar occasionally showed as a low-opacity black patch.** `SetStatusBarTexture`
  was never called at creation — only later, on the first real update tick — so an
  untextured `StatusBar` could render its default placeholder in the gap. Now given an
  explicit initial texture at creation time, closing that window.
- **`attempt to perform boolean test on local 'checked' (a secret boolean value)`, 210x,
  range fade on arena_party2.** The earlier research claim that `UnitInRange` is purely
  positional and never secret was wrong for this build — it returns secret booleans for
  at least arena/party units (same anti-scouting treatment `ArenaTrinket.lua` already
  documents for `UnitGUID`). Added a `type()`+`issecretvalue()` guard before ever testing
  the result; if either value comes back secret, the range fade just doesn't show for that
  unit right then instead of crashing — probably still works fine outside
  arena/M+/raid where the data likely isn't secret.
- **`/mcfindicatortest` only showed the shield bar on Player-based frames** (Player,
  Party5, Arena Player — all `unit="player"`). Test mode required `UnitExists(u.unit)`
  before showing the fake preview, same as the real logic — but
  `UnitExists("party1")`/`UnitExists("arena1")` etc. are only true while actually grouped
  or in an arena match, so solo/out-of-arena testing silently skipped everything except
  the player-based frames. Test mode now bypasses that check entirely, same as
  `AuraHoverPreview.lua`'s test mode already does — it never touches real unit data in
  the first place, so there was never a reason to gate it on the unit existing.
- **This addon's own name/health/highlight styling was bleeding onto interactable world
  object nameplates** (reported with a screenshot: a "Postbox Parcel" mailbox showing a
  styled name and health bar) — `SkinNamePlate` never filtered by unit type, so any frame
  Blizzard created a nameplate for got the full treatment. Added `IsObjectNameplate`,
  which reads the unit's GUID prefix (`GameObject-...`) to detect non-creature/player
  nameplates and skip them entirely. `UnitGUID` can be secret for some units (arena
  enemies, per `ArenaTrinket.lua`) — when unreadable, it's treated as "not an object" so a
  real (secret-GUID) enemy never gets skipped by mistake.
- **Still bleeding after the fix above — confirmed via `/mcfnpobjdiag`: "Wooden Chair"
  correctly evaluated `IsObjectNameplate=true` but still showed skinned.** Root cause was
  frame reuse: Blizzard recycles the same Lua nameplate frame across different units, and
  this particular frame had already been skinned earlier for a real creature — a plain
  `return` prevented any *new* skin from applying, but never undid the old one (this
  file's skinning is one-way; there's no "revert to native" for the bar texture/name
  font). Now the whole `uf` gets explicitly `:Hide()`n for objects instead — its custom
  child overlays (auras/class icon/cast bar) go invisible along with it for free, no need
  to unwind each one individually. Blizzard shows it again on its own once the frame gets
  reassigned to a real unit.
- **Object nameplates kept showing inside dungeons specifically.** `/mcfnpobjdiag` showed
  `UnitGUID` coming back fully secret for *every* nameplate in there — including objects
  already correctly detected in open world — so the GUID-prefix check had nothing to work
  with. No native CVar exists to suppress object nameplates specifically either (checked —
  the only relevant ones are the friendly-NPC/player visibility CVars this addon already
  turns on in dungeons for the escort-NPC feature, and those are exactly what's making
  decorative furniture nameplate-eligible in the first place; turning them off would kill
  that feature too). Added a fallback for when the GUID is unreadable: `UnitCreatureType`
  returns a real `nil` for non-creature units but a *secret* (protected, non-nil) value
  for actual creatures — confirmed side-by-side via the diagnostic (a "Bench" object vs.
  an "Over-Indulged Patron" NPC) — `UnitReaction` backs up the same nil-vs-secret split as
  a second signal.

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
