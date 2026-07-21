# Gonkast Preset (MyCustomFrames)

A full AzeriteUI-styled HUD replacement for **World of Warcraft Midnight (12.0.7)**: unit frames,
40-player raid frames, class resource bars, portraits, auras, minimap/nameplate reskins, info bar,
quest tracker recoloring, assisted-rotation glow, and a bundled Masque skin. Secret-number safe
(handles this client's stricter Lua sandboxing on other players' unit data). Personal preset of
**Gonkast** — originally built on top of AzeriteUI, now fully standalone (see Credits).

## Requirements

None — fully standalone, no other addon required.

## Recommended (Setup Wizard can auto-configure these)

- **[Bartender4](https://www.curseforge.com/wow/addons/bartender4)** — action bars
- **[DynamicCam](https://www.curseforge.com/wow/addons/dynamiccam)** — camera
- **[Masque](https://www.curseforge.com/wow/addons/masque)** — action button skinning (skin bundled, `MasqueSkin.lua`)
- **[Chattynator](https://www.curseforge.com/wow/addons/chattynator)** — chat
- **[BetterBags](https://www.curseforge.com/wow/addons/better-bags)** + **[BetterBagsSkinGonkast](https://github.com/Gonkast/BetterBagsSkinGonkast)** — bags
- **[Mainmenu-Gonkast](https://github.com/Gonkast/Mainmenu-Gonkast)** — Esc menu reskin

## Other addons that pair well (not auto-configured)

- **[Plumber](https://github.com/Peterodox/Plumber)** — the menu styling is based on it
- **[DialogueUI](https://www.curseforge.com/wow/addons/dialogueui)** — includes a DynamicCam compatibility fix (`db.dcFix`); turn off DialogueUI's own "Camera Movement" for it to work
- **[WaypointUI](https://www.curseforge.com/wow/addons/waypointui)** — waypoint/map arrow
- **[Bartender4 Animations](https://www.curseforge.com/wow/addons/bartender4-animations)** — button-press animations
- **[DF Friendly Nameplates](https://www.curseforge.com/wow/addons/df-friendly-nameplates)** — friendly nameplate visibility
- **Masque Skinner: Blizz Buffs** — skins native buff/debuff icons
- **[ChatBubbleReplacements](https://github.com/Luckyone961/ChatBubbleReplacements)** — bubble textures (this preset only reskins the *text*)

## What's inside

- **Unit frames** — player/target/ToT/pet/focus/boss1-5/party1-5/arena1-6, hand-built secure frame reskins (no oUF)
- **Raid frames** (`Raid.lua`) — up to 40 players, auto-shows in raids/battlegrounds, configurable grid layout
- **Class Power** (`ClassPower.lua`) — combo points, holy power, chi, soul shards, arcane charges, essence, runes, soul fragments, maelstrom weapon
- **Portraits** — 3D model or class icon, cage/background/role/leader/raid-mark badges
- **Auras** — buffs/debuffs, click-to-cancel, dual positioning (combat vs idle)
- **Minimap reskin** (`Minimap.lua`) — custom ring/border, coordinates, mail/eye/dismount/tracking icons, mail notification banner
- **Nameplate reskin** (`Nameplates.lua` + `NameplateDesigner.lua`) — custom bars, aura filtering, per-zone profiles, in-game designer
- **Quest tracker** — recoloring, text alignment, context-aware auto-hide
- **Info bar** — clock, calendar, zone, FPS/MS
- Micro menu, chat bubble text, mouselook, native frame hiding, Explorer Mode (auto-fade), assisted glow, mirror timer, tooltip, extra button — all reskinned
- **Lock/Edit mode** (`/mcf`) — drag/scale/reposition everything, "Hide in Lock" panel, syncs with Blizzard's Edit Mode
- **Setup Wizard** (`/mcfsetup`) — first-run walkthrough, auto-applies bundled profiles
- **Preset system** — save/load/export/import the whole config as a string

## Slash commands

| Command | Effect |
|---|---|
| `/mcf` | Toggle Move/Lock (edit mode) |
| `/mcfmenu` | Open the options panel |
| `/mcfsetup` | Reopen the setup wizard |
| `/mcfhud` | Show the Blizzard Edit Mode HUD code (import manually via Esc > Edit Mode > Import Layout) |
| `/mcftrackerdump` | Diagnostics: quest tracker text classification |
| `/mcfchar` | Diagnostics: portrait "open character panel" button |

## Installation

1. **Code → Download ZIP** above, extract it.
2. Rename the extracted folder from `MyCustomFrames-main` to **`MyCustomFrames`** (must match the `.toc`).
3. Move it into `World of Warcraft\_retail_\Interface\AddOns\`.
4. Restart WoW (or reload the AddOns list at the character screen).
5. Log in — the Setup Wizard opens automatically.

## Credits

- **[AzeriteUI](https://github.com/AzeriteTeam/Azerite5)** by Daniel Troko and Lars Norberg — original source of the textures/visual language this preset is built on. Wouldn't exist without it.
- **[AzeriteUI JuNNeZ Edition (Midnight)](https://www.curseforge.com/wow/addons/azeriteui-junnez-edition-wow12)** — the Midnight-compatible fork this preset was originally built to run on.
- **[Plumber](https://github.com/Peterodox/Plumber)** by Peterodox — menu styling, using real assets from its `Art/` folder. This project ships under **Plumber's license (GPLv3)** as a result.
- **M33kAuras** — player-rest flipbook animation data.
- **["You've got mail!"](https://wago.io/1wKfUxJ8U)** WeakAura — inspired the new-mail banner, rebuilt with native Blizzard textures.

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).

## Note

Claude (Anthropic) helped organize the git repository and this README.
