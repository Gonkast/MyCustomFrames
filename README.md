# Gonkast Preset (MyCustomFrames)

A full AzeriteUI-styled HUD replacement for **World of Warcraft Midnight (12.0.7)**: unit frames,
40-player raid frames, class resource bars, portraits, auras, minimap/nameplate reskins, info bar,
quest tracker recoloring, assisted-rotation glow, and a bundled Masque skin. Secret-number safe
(handles this client's stricter Lua sandboxing on other players' unit data). Personal preset of
**Gonkast** — originally built on top of AzeriteUI, now fully standalone (see Credits).

## Requirements

None to load — no other addon is a hard dependency. That said, this preset is designed and tuned to be used alongside **Gonkast's own [Bartender4](https://www.curseforge.com/wow/addons/bartender4) profile** (action bar layout/positions) and **[DynamicCam](https://www.curseforge.com/wow/addons/dynamiccam)** (camera) — the bundled Bartender4 profile (see Setup Wizard) is part of the intended setup, not just an optional pairing.

> **Note:** designed and tested for **16:9 resolutions** with WoW's UI Scale set to **100%** (System > Video). Other aspect ratios (ultrawide 21:9, etc.) or a custom UI Scale may cause positions/sizes to look off.

## Recommended (Setup Wizard can auto-configure these)

- **[Bartender4](https://www.curseforge.com/wow/addons/bartender4)** — action bars
- **[DynamicCam](https://www.curseforge.com/wow/addons/dynamiccam)** — camera
- **[Masque](https://www.curseforge.com/wow/addons/masque)** — action button skinning (skin bundled, `MasqueSkin.lua`)
- **[Chattynator](https://www.curseforge.com/wow/addons/chattynator)** — chat

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
- **Auras** — buffs/debuffs everywhere, all through one hover-triggered display (debuff
  priority, colored border by dispel type): party (dungeon-only), arena (arena-only) and
  focus reveal on mouseover or in combat; player and target are always visible, no
  mouseover or target required
- **Unit indicators** (`Indicators.lua`) — out-of-range dimming and an absorb/shield overlay
  on player/target/focus/party/arena, drawn with each unit's own bar texture
- **Loss of Control** (`LossOfControl.lua`) — icon + countdown on the player portrait while
  you're stunned/silenced/rooted/feared
- **Minimap reskin** (`Minimap.lua`) — custom ring/border, coordinates, mail/eye/dismount/tracking icons, mail notification banner
- **Nameplate reskin** (`Nameplates.lua` + `NameplateDesigner.lua`) — custom bars, aura filtering, per-zone profiles, in-game designer, optional class-colored enemy player names
- **Quest tracker** — recoloring, text alignment, context-aware auto-hide
- **Info bar** — clock, calendar, zone, FPS/MS
- **Game Menu (Esc) reskin** (`MainMenu.lua`) — custom frame/buttons, follows the active skin
- **Explorer Mode** — fades elements out until you hover where they are; combat/target/casting can
  force them fully visible. Three one-click **quick profiles** (Setup Wizard and the Explorer
  options section) pick which elements it manages:
  - **Exploration** — hides almost everything, keeps the minimap, your unit frame, portrait, info
    bar and micro menu always visible.
  - **Combat** — only the action bars fade out, revealing automatically when you enter combat;
    everything else stays visible.
  - **Minimal** — hides everything, no exceptions.

  Picking a profile only replaces *which elements* Explorer manages — it never touches opacity,
  target/casting rules, or zone filters, so those stay exactly as you set them.
- Micro menu, chat bubble text, mouselook, native frame hiding, assisted glow, mirror timer, tooltip, extra button — all reskinned
- **Lock/Edit mode** (`/mcf`) — drag/scale/reposition everything, "Hide in Lock" panel, syncs with Blizzard's Edit Mode
- **Setup Wizard** (`/mcfsetup`) — first-run walkthrough, optionally applies bundled profiles
- **Preset system** — save/load/export/import the whole config as a string

## What's *not* inside

So you know before installing. None of this is planned — it's here to set expectations, not
as a roadmap.

- **No action bars.** This preset positions and scales Bartender4's bars; it doesn't provide
  any. Without Bartender4 you keep Blizzard's default bars.
- **No chat, bag, or damage-meter replacement.** Pairs with Chattynator for chat; bags and
  meters are your own choice.
- **No boss-mod integration.** DBM/BigWigs bars aren't skinned or repositioned.
- **No world map or dungeon-journal reskin.** Only the minimap is themed.
- **No range or dispel indicators on the 40-player raid frames.** The range fade and shield
  bar only cover the individual frames (player/target/focus/party/arena).
- **No threat/aggro indicator.** Attempted several ways and dropped — see the Midnight
  limits below.
- **No dispel-type highlight on unit frames.** Nameplates do filter and colour auras by
  dispel type; unit frames only colour the aura icon's own border.
- **No aura whitelist/blacklist on unit frames.** You choose how many icons and how they
  sort, not which specific spells appear. Nameplates *do* have real filtering.
- **No localisation.** English only, hardcoded.
- **No profile-per-character or per-spec.** One config per account, plus the preset
  save/load system.
- **Tuned for 16:9 at 100% UI scale.** Other aspect ratios or a custom UI scale will need
  manual repositioning.

## Midnight (12.0) API limits that shape this addon

Midnight wraps a lot of combat data in "secret values" — an addon can pass them to Blizzard
widgets but can't read, compare, or do maths on them. These are limits of the client, not
bugs to report, and every one below was confirmed in-game on 12.0.7:

- **Health and power of other units are unreadable.** Bars are filled by handing the secret
  straight to a `StatusBar`; text uses `UnitHealthPercent`, which stays readable. Exact
  values (`123456 / 200000`) are not obtainable for anyone but yourself.
- **Aura timers on other units are secret.** `expirationTime`/`duration` can't be read, so
  the countdown is drawn by Blizzard's own cooldown widget from a duration object. The
  "sort by time remaining" option therefore only truly reorders *your own* auras; elsewhere
  it falls back to the game's native order.
- **Stack counts and dispel types are secret.** Dispel colouring goes through
  `C_UnitAuras.GetAuraDispelTypeColor` / `IsAuraFilteredOutByInstanceID` instead of reading
  the type directly.
- **`UnitInRange` returns secret booleans for party and arena units.** The range fade
  simply won't show for those units rather than guessing — it works in open world.
- **`UnitGUID`, `UnitCreatureType` and `UnitReaction` go secret inside dungeons**
  (anti-scouting). This is why filtering nameplates off world objects needs a fallback
  chain, and why arena opponents can't be identified by GUID.
- **`COMBAT_LOG_EVENT_UNFILTERED` is gone for addons.** The arena trinket tracker detects
  the buff via `UNIT_AURA` instead; anything that genuinely needs the combat log can't be
  done.
- **Threat data proved unusable for a visible indicator.** Four different approaches, none
  produced a reliable on-screen change — Blizzard's own recolouring reasserts on its own
  schedule and the native highlight rarely fires. Dropped rather than shipped half-working.
- **Native minimap pins ignore parent alpha** (`SetIgnoreParentAlpha`), so Explorer can't
  fade them — it moves the minimap off-screen instead. That makes minimap hiding snap
  instantly rather than fade.
- **Many calls are blocked in combat**, including `SetCVar`, `EnableMouse`, `Show`/`Hide`
  and `SetPoint` on protected frames, and `Minimap:ClearAllPoints()`. Anything that lands
  mid-combat is deferred to when you leave combat, so a few changes apply a moment late.
- **The `AuraContainer` widget doesn't exist on 12.0.7** — it's from a later build — so
  nameplate aura classification leans on Blizzard's own already-computed lists.

## Slash commands

| Command | Effect |
|---|---|
| `/mcf` | Toggle Move/Lock (edit mode) |
| `/mcfmenu` | Open the options panel |
| `/mcfsetup` | Reopen the setup wizard |
| `/mcfnpdesigner` | Open the in-game nameplate designer |
| `/mcfundo` | Restore the auto-backup taken before the last Reset ALL or profile apply (one level of undo) |
| `/mcfskincheck` | Check the active skin ships every file it needs — a missing one renders **invisible**, with no other clue |
| `/mcfhud` | Show the Blizzard Edit Mode HUD code (import manually via Esc > Edit Mode > Import Layout) |

A few elements have no menu section yet and are driven from chat instead:

| Command | Effect |
|---|---|
| `/mcfmirror <toggle\|width\|height\|offsetx\|offsety>` | Mirror timer (breath / fatigue bar) |
| `/mcftooltip <toggle\|scale>` | Tooltip reskin |
| `/mcfextrabtn border` | Extra action button border |
| `/mcfminimapbtnslist` | List the minimap buttons the collector picked up |
| `/mcfminimapbtnsignore <name>` | Exclude one of them from the collector |
| `/mcfminimapbtnsreset` | Reset the collector trigger's position and scale |

## Diagnostics

**`/mcfdiag` is the index for everything below — you don't need this table.** It lists every
diagnostic and preview grouped by type, plus the commands that aren't run through it, and
`/mcfdiag <name>` runs one. The table here is a reference for reading on the web.

Diagnostics dump what a subsystem is *actually* seeing right now, which usually beats guessing.
Previews (`/mcfdiag test…`) are toggles — run them again to turn them off.

| Command | Reports on |
|---|---|
| `/mcfscaledump` | Position and scale of every element at the current resolution — the tool for checking the 16:9 auto-scale |
| `/mcfbt4diag` | Which Bartender4 bar frames exist and under what names |
| `/mcfaurasdiag` | Aura data for the current target |
| `/mcfnpdiag`, `/mcfcastwatch` | Nameplates; `castwatch` toggles live cast logging |
| `/mcfnpobjdiag` | Per-nameplate unit/GUID/creature-type dump — for chasing nameplates that shouldn't be there (world objects, furniture) |
| `/mcfmmdiag`, `/mcfringdiag`, `/mcfmapiconsdiag` | Minimap: general state, XP/reputation/honor/renown rings, icons |
| `/mcfpartytest`, `/mcfarenaauratest`, `/mcffocusauratest`, `/mcfplayerauratest`, `/mcftargetauratest` | Toggle the party / arena / focus / player / target hover aura previews for placement without a real group, match or target |
| `/mcfaurahoverdiag [key]` | Live internal state of a hover aura group (hover/target/combat/cast/gate/alpha) |
| `/mcfindicatortest` | Force the range fade and shield bar on every tracked unit, to preview them without being out of range or shielded |
| `/mcfloctest` | Fake a Loss of Control icon on the player portrait, to preview it without a real stun |
| `/mcftrinkettest` | Fake the arena trinket cooldown on the 3 arena enemy frames (needs `/mcf` to see them outside a match). Tests the icon only, not detection |
| `/mcfarenadiag` | Which arena-detection method is returning what |
| `/mcfclasspowerdiag` | Class resource detection for your class and spec |
| `/mcfmirrordiag`, `/mcfmirrortargetdiag` | Mirror timer, and the mirrored-target portrait |
| `/mcfpaneldiag` | Mouse dead-zones over the options panel — run it while standing on the stuck spot |
| `/mcfmenudiag` | Texture paths the Game Menu (Esc) skin resolves |
| `/mcftrackerdump` | Quest tracker text classification |
| `/mcfchar` | The portrait's "open character panel" button |

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
- **[W2UI](https://www.curseforge.com/wow/addons/w2ui)** — the micro menu icons come from its `Media/MenuBar` set.
- **M33kAuras** — player-rest flipbook animation data.
- **["You've got mail!"](https://wago.io/1wKfUxJ8U)** WeakAura — inspired the new-mail banner, rebuilt with native Blizzard textures.
- **Platynator** — the idea for the Nameplate Designer. No code from it was used.

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).

## Note

Claude (Anthropic) helped organize the git repository and this README.
