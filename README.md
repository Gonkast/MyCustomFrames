# AzeriteUI — Gonkast Preset (MyCustomFrames)

Custom unit frames, portraits, auras, info bar, quest tracker coloring, assisted glow and a
Masque skin, built for World of Warcraft **Midnight (12.0.7)**. Secret-number safe. This is the
personal preset of **Gonkast**, tuned to sit on top of AzeriteUI.

## Requirements

- **[AzeriteUI5_JuNNeZ_Edition](https://github.com/AzeriteTeam/Azerite5) — essential, required.**
  This addon is designed to run *on top of* AzeriteUI; it hides AzeriteUI's own Tracker/Info/
  MicroMenu modules and replaces them, and its whole visual language (colors, fonts, borders)
  assumes AzeriteUI is present. It will not look right without it.

## Recommended (optional, but the Setup Wizard can auto-configure these)

- **[Bartender4](https://www.curseforge.com/wow/addons/bartender4)** — action bars.
- **[DynamicCam](https://www.curseforge.com/wow/addons/dynamiccam)** — camera.
- **[Masque](https://www.curseforge.com/wow/addons/masque)** — action button skinning; this addon
  bundles its own "Azerite HEX" Masque skin (`MasqueSkin.lua`), so you don't need a separate skin
  addon for it.
- **[Chattynator](https://www.curseforge.com/wow/addons/chattynator)** — chat.

## What's inside

- Multi-unitframe health/power/cast bars (player, target, ToT, pet, focus, boss1-5, party1-5).
- Portraits (3D model or class icon) with cage, background, role/leader/raid-mark badges.
- Buffs/debuffs with click-to-cancel, dual positioning (in-combat vs idle).
- Quest tracker recoloring + context-aware auto-hide (boss fights, combat, hostile target, arena,
  battlegrounds).
- Info bar (clock, calendar, zone, FPS/MS) in the AzeriteUI style.
- Micro menu reskin, chat bubble styling, mouselook, native Blizzard unit frame hiding, Explorer
  Mode (auto-fade on mouseover), assisted-rotation glow.
- **First-run Setup Wizard** (`/mcfsetup`): a 7-page walkthrough that explains the addon, detects
  installed addons with a bundled profile, and applies the whole preset in a few clicks.

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

Many of the bundled unit frame/portrait/cage/badge textures in `Assets/` are **edited versions of
the original AzeriteUI assets by Daniel Troko and Lars Norberg** — copied and modified from
[AzeriteUI](https://github.com/AzeriteTeam/Azerite5) to fit this preset. The bundled Masque skin
("Azerite HEX") is likewise adapted from `Masque_Azerite_Hex`, also by Daniel Troko and Lars
Norberg. The player-rest flipbook animation data is sourced from **M33kAuras**.

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).
