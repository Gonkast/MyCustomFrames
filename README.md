# Gonkast Preset (MyCustomFrames)

A full AzeriteUI-styled HUD replacement: unit frames (player/target/pet/focus/ToT/boss1-5/party1-5/
arena1-6), a 40-player raid frame system, class resource bars for every spec that has one (combo
points, holy power, chi, soul shards, arcane charges, essence, runes, soul fragments, maelstrom
weapon), portraits, buffs/debuffs, a minimap reskin, nameplate reskin, info bar, quest tracker
recoloring, assisted-rotation glow, and a bundled Masque skin — built for World of Warcraft
**Midnight (12.0.7)**. Secret-number safe (works around this client's stricter Lua sandboxing on
other players' unit data). This is the personal preset of **Gonkast**, originally built to run on
top of AzeriteUI and now fully standalone (see Credits for how much of it still traces back there).

## Requirements

None. As of this release, MyCustomFrames is fully standalone — it no longer needs
AzeriteUI5_JuNNeZ_Edition installed (see Credits below for how much this project owes to that
codebase).

## Recommended (optional, but the Setup Wizard can auto-configure these)

- **[Bartender4](https://www.curseforge.com/wow/addons/bartender4)** — action bars.
- **[DynamicCam](https://www.curseforge.com/wow/addons/dynamiccam)** — camera.
- **[Masque](https://www.curseforge.com/wow/addons/masque)** — action button skinning; this addon
  bundles its own "Azerite HEX" Masque skin (`MasqueSkin.lua`), so you don't need a separate skin
  addon for it.
- **[Chattynator](https://www.curseforge.com/wow/addons/chattynator)** — chat.

## Other recommended addons (not part of the Setup Wizard)

These pair well with this preset visually/functionally but aren't auto-configured — install and
set them up on your own:

- **[Plumber](https://github.com/Peterodox/Plumber)** — quality-of-life modules; this preset's
  menu styling is based on it (see Credits below).
- **[DialogueUI](https://www.curseforge.com/wow/addons/dialogueui)** — cleaner NPC dialogue/quest
  UI. This preset includes a **DynamicCam compatibility fix** (`db.dcFix`, toggle in Global
  options): DialogueUI calls a DynamicCam method that freezes its camera and never releases it,
  breaking DynamicCam's custom camera situations — this addon neutralizes that call. Only matters
  if you run both DialogueUI and DynamicCam together, and DialogueUI's own "Camera Movement"
  option must be turned off for it to work.
- **[WaypointUI](https://www.curseforge.com/wow/addons/waypointui)** — waypoint/map arrow display.
- **[Sorted](https://www.curseforge.com/wow/addons/sorted)** — bag sorting.
- **[Bartender4 Animations](https://www.curseforge.com/wow/addons/bartender4-animations)** — extra
  button-press animations for Bartender4.
- **[DF Friendly Nameplates](https://www.curseforge.com/wow/addons/df-friendly-nameplates)** —
  friendly nameplate visibility on Midnight.
- **Masque Skinner: Blizz Buffs** — Masque skin for the native Blizzard buff/debuff icons.
- **[ChatBubbleReplacements](https://github.com/Luckyone961/ChatBubbleReplacements)** — replaces
  Blizzard's chat bubble textures. Pairs well with this preset's own chat bubble text styling
  (`ChatBubble.lua`, which only reskins the *text*, not the bubble background/border) for a fully
  reskinned chat bubble.

## What's inside

- Unit frames: player, target, ToT, pet, focus, boss1-5, party1-5, arena1-6 (health/power/cast
  bars, hand-built reskins of Blizzard's own secure frames — no oUF).
- **Raid frames** (`Raid.lua`): up to 40 players, AzeriteUI look, auto-shows in raid groups and
  battlegrounds only (never in normal 2-4 player parties). Fully code-controlled grid (growth
  direction, units per row, row/column spacing all configurable from the menu); appearance
  (textures/colors) is fixed by design, not user-editable.
- **Class Power** (`ClassPower.lua`): combo points, holy power, chi, soul shards, arcane charges,
  essence — plus Death Knight runes (with recharge swipe), Demon Hunter soul fragments, and
  Enhancement Shaman maelstrom weapon stacks. Movable/scalable in Lock mode even for specs without
  a supported resource, so you can pre-position it.
- Portraits (3D model or class icon) with cage, background, role/leader/raid-mark badges.
- Buffs/debuffs with click-to-cancel, dual positioning (in-combat vs idle).
- **Minimap reskin** (`Minimap.lua`): custom ring/border, coordinates, mail/eye/dismount icons,
  below-minimap widget.
- **Nameplate reskin** (`Nameplates.lua` + `NameplateDesigner.lua`): custom health/cast bars, aura
  filtering (enemy buffs, big debuffs, personal debuffs), a separate visual profile per zone type
  (dungeon/raid/world/etc.), and an in-game designer tool to build your own.
- Quest tracker recoloring + context-aware auto-hide (boss fights, combat, hostile target, arena,
  battlegrounds).
- Info bar (clock, calendar, zone, FPS/MS) in the AzeriteUI style.
- Micro menu reskin, chat bubble text styling, mouselook, native Blizzard unit frame hiding,
  Explorer Mode (auto-fade on mouseover), assisted-rotation glow, mirror timer reskin, tooltip
  reskin, extra action button reskin.
- **Lock/Edit mode** (`/mcf`): drag, scale and reposition almost every element above without
  affecting normal gameplay display; a floating "Hide in Lock" panel lets you temporarily hide
  groups of elements (by unit, or whole systems like the raid frames/minimap/tracker) just to get
  a clear view while editing something else. Auto-syncs with Blizzard's native Edit Mode.
- **First-run Setup Wizard** (`/mcfsetup`): a multi-page walkthrough that explains the addon, detects
  installed addons with a bundled profile, and applies the whole preset in a few clicks.
- Full preset/profile system: save, load, export as a copy-paste string, and import — covers every
  subsystem above in one shot (see `core.lua`'s `PRESET_TABLE_KEYS`).

## Slash commands

| Command | Effect |
|---|---|
| `/mcf` | Toggle Move/Lock (edit mode) |
| `/mcfsetup` | Reopen the first-run setup wizard |
| `/mcfhud` | Show the Blizzard Edit Mode HUD layout code (import it manually via Esc > Edit Mode > Import Layout) |
| `/mcfskin` | Diagnostics for the AzeriteUI asset-remap bridge |
| `/mcftrackerdump` | Diagnostics for the quest tracker text classification |
| `/mcfchar` | Diagnostics for the portrait "open character panel" button |

## Installation

1. Click **Code → Download ZIP** above.
2. Extract it. The extracted folder will be named `MyCustomFrames-main` — **rename it to exactly
   `MyCustomFrames`** (no `-main` suffix). WoW requires the folder name to match the `.toc` file
   inside it, or the addon won't show up in-game.
3. Move that folder into `World of Warcraft\_retail_\Interface\AddOns\`.
4. Restart WoW (or reload the AddOns list at the character screen).
5. Log in — the first-run Setup Wizard opens automatically after a couple seconds.

## Credits

Menu styling (fonts, borders, layout patterns) is adapted from **[Plumber](https://github.com/Peterodox/Plumber)**
by Peterodox — used with real assets copied from Plumber's `Art/` folder. Because of that, this
project ships under the **same license as Plumber (GPLv3)**.

This project owes an enormous amount to **[AzeriteUI](https://github.com/AzeriteTeam/Azerite5)
by Daniel Troko and Lars Norberg**. It started as a preset meant to run on top of AzeriteUI, and
even though it no longer requires it, huge parts of this addon — the unit frame/portrait/cage/badge
textures in `Assets/`, the raid frame layout and look, the bundled Masque skin ("Azerite HEX",
adapted from `Masque_Azerite_Hex`), and the overall visual language this whole preset is built
around — are directly copied, modified, or learned from studying that codebase. This addon would
not exist in its current form without it. The player-rest flipbook animation data is sourced from
**M33kAuras**.

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).
