# MyCustomFrames — estructura y notas (v8.x, "AzeriteUI — Gonkast Preset")

Addon de WoW **Midnight 12.0.7**. Barras de vida/poder + cast bar personalizables,
multi-unitframe, + portraits, auras, info bar, micro menu, chat bubble, quest tracker,
assisted glow, y varias utilidades globales. Preset del usuario **Gonkast** (corre sobre AzeriteUI5_JuNNeZ_Edition).
Titulo del toc = "AzeriteUI |cffffcc00—|r Gonkast Preset", author Gonkast; la CARPETA sigue
siendo `MyCustomFrames` (renombrarla romperia las rutas de `Assets\`). Texto visible en INGLES;
comentarios en español.

**ACTUALIZADO 2026-07-15.** Desde el 2026-07-13 se agregaron: sistema de **Perfiles desde archivos**
(`Profiles_Pre/Post.lua`, `ProfilesApply.lua`, carpeta `Profiles\`), **Integration_AzeriteUI.lua**
(bridge de skin/colores hacia AzeriteUI5_JuNNeZ_Edition), **Grouping.lua** (mover elementos
agrupados), **Setup.lua** (menú nuevo que reemplaza el botón viejo de Integrations), y `Tracker.lua`
fue REESCRITO 3 veces por una saga larga de taint (`ObjectiveTrackerFrame:Show()` bloqueado en
combate) — la causa raíz final (tanda 11, HOY) fue mutar la tabla GLOBAL `OBJECTIVE_TRACKER_COLOR`
cada 0.4s (`PatchColorTable`, YA ELIMINADO); el detalle completo de la saga (11 tandas, muchas
hipótesis descartadas) vive en la memoria `project-mycustomframes-pending-bug` — no se repite aquí
en extenso, solo el estado FINAL. Ver secciones actualizadas abajo.

## Archivos (orden de carga en el toc)
1. `Defaults.lua` — `ns.BUILTIN` = layout HORNEADO del autor (globals top-level + units + portraits +
   infobar + auras + micromenu + chatbubble + glow, SIN presets). En instalacion LIMPIA
   (`MyCustomFramesDB==nil`) InitDB copia `DeepCopy(ns.BUILTIN)` y luego FillDefaults rellena lo que falte.
   **Se re-hornea desde un Export MCF1** (2026-07-13): tomar el string `MCF1:{...}`, quitar prefijo
   `MCF1:`, aplanar `globals` a nivel superior (p.ej. `hideEditGreen`), quitar la clave `name`, e
   inyectar los globals que el Export no serializa (`groupMoveBoss`/`groupMoveParty`); envolver en
   `local ADDON, ns = ...  ns.BUILTIN = {...}`. Se validan llaves/comillas balanceadas. Backup en
   `backup/Defaults_pre_export_*`.
2. `core.lua` — TODA la logica (definiciones, DB, relleno, textos, cast, portraits, auras,
   info bar, micro menu, chat bubble, mouselook, hide-blizzard, fade-in, eventos, preview,
   presets). API por el namespace `local ADDON, ns = ...`.
3. `Glow.lua` — subsistema ASSISTED GLOW. `ChatBubble.lua` — subsistema CHAT BUBBLE (ticker propio,
   sin acoplamiento; expone ns.RefreshChatBubble/ns.ChatBubbleDefaults/ns.IsChatBubble/ns.CHATBUBBLE_KEY).
   `MicroMenu.lua` — subsistema MICRO MENU (reskin de micro-botones; expone ns.RefreshMicroMenu/
   ns.MM_ReassertArt/ns.MicroMenuDefaults/ns.IsMicroMenu/ns.MICROMENU_KEY/ns.micromenu). Los TRES se
   extrajeron de core.lua por el LIMITE DE 200 LOCALS de Lua (core quedo en ~180/200). **PATRON de
   extraccion:** el archivo hace `local ADDON, ns = ...`, usa `ns.GetDB()` (no el `db` local de core),
   `ns.IsUnlocked()` (no `unlocked`), y helpers expuestos `ns.MakeEditHighlight/ns.AttachScaleWheel/
   ns.CompensateScale/ns.SnapFrameToGrid`. Carga DESPUES de core (que expone todo eso) y ANTES de Options.
   Core conserva `MICROMENU_KEY`/`CHATBUBBLE_KEY` como locals (los usa ns.CurrentProfile) y llama a las
   funciones movidas via `ns.X` (guardado con `if ns.X then`). **Al añadir features nuevas, preferir
   extender estos archivos (o crear otro) antes que engordar core** — el limite de locals es real.
   Se MOVIO fuera de core.lua porque el chunk principal de core.lua excedia el limite de
   **200 variables locales** de Lua ("main function has more than 200 local variables" =
   addon no carga). Usa `ns.ASSETS`/`ns.GetDB()`; expone `ns.RefreshGlow/GlowDefaults/
   GLOW_STYLES/HasLCG`. LECCION: al agregar muchos `local` de nivel-archivo a core.lua, vigilar
   el limite de 200 (contar con `grep -c '^local ' core.lua`); si se acerca, mover un subsistema
   a su propio archivo del toc.
4. `Grouping.lua` — `ns.MoveFollowers`: al mover un elemento "padre" en preview (OnDragStop), mueve
   junto sus "seguidores" (portrait_player→player+playerpower, portrait_target→target+targetpower,
   pet→portrait_pet, targettarget→portrait_tot, party unit con `groupMoveParty`→party portraits).
5. `Tracker.lua` — colorea titulos/objetivos del ObjectiveTracker + lo oculta en boss fights.
   **REESCRITO 3 veces (saga de taint, ver seccion Quest Tracker mas abajo para el estado final).**
6. `Profiles_Pre.lua` → **`Profiles\<Addon>\<Addon>.lua`** (Bartender4/DynamicCam/Masque/Chattynator/
   AzeriteUI5_JuNNeZ_Edition, copias de SavedVariables del usuario) → `Profiles_Post.lua` →
   `Profiles\_Exports.lua` (strings `MCF1:`/Blizzard exportados) → `ProfilesApply.lua`. Sistema de
   "Perfiles desde archivos" (ver seccion propia mas abajo).
7. `Integration_AzeriteUI.lua` — bridge de skin/colores hacia AzeriteUI5_JuNNeZ_Edition (ver seccion
   propia). `## OptionalDeps: AzeriteUI5_JuNNeZ_Edition` en el toc.
8. `Setup.lua` — **CORRECCIÓN 2026-07-15: NO es un grupo de menú, es un WIZARD DE BIENVENIDA de
   primera instalación** (7 páginas, popup `MCFSetupWizard` centrado, 960x760). Ver sección propia
   "Setup Wizard" más abajo — se documentó mal en una entrada anterior de este archivo.
9. `Options.lua` — el menu de opciones (estilo Plumber, sidebar colapsable + buscador). CARGA AL FINAL.
- `Assets/` — copias locales de texturas/fuentes (ver abajo). `backup/` — .bak anteriores.

**Orden real del toc (2026-07-15):** Defaults → core → Glow → ChatBubble → MicroMenu → Grouping →
Tracker → Profiles_Pre → Profiles\*(6 addons) → Profiles_Post → Profiles\_Exports →
ProfilesApply → Integration_AzeriteUI → Setup → Options.

NOTA cross-addon: los tweaks de AzeriteUI (desactivar Tracker/Info/MicroMenu de AzeriteUI,
colores de texto por categoria, tamaño/offset de texto de nameplates, mostrar BuffFrame nativo)
viven en `AzeriteUI5_JuNNeZ_Edition/Components/Misc/GonkastTweaks.lua` +
`Options/OptionsPages/GonkastTweaks.lua` (se pierden si se actualiza AzeriteUI).

## Namespace `ns` (puente entre archivos)
core.lua expone: `ns.UNITS`, `ns.DefaultsFor`, `ns.STRATA_VALUES`, `ns.POINT_VALUES`,
`ns.PL`, `ns.frames`, `ns.portraits`, `ns.auras`, `ns.infobar`, `ns.micromenu`, `ns.currentEdit`,
`ns.CurrentProfile()`, `ns.ApplyCurrent()`, `ns.RefreshUnit/RefreshAll/RefreshInfoBar/
RefreshMicroMenu/RefreshChatBubble`, `ns.SetUnlocked/IsUnlocked/GetDB/ToggleGreenZone`,
`ns.CopySettings/PasteSettings`, `ns.SavePreset/LoadPreset/DeletePreset/GetPresetNames/
SetDefaultPreset/GetDefaultPreset/ExportPreset/ImportPreset`, `ns.DeepCopy/hexcol`,
`ns.AttachFadeIn`, `ns.HideBlizzardFrames/BlizzardNeedsApply`, `ns.MicroMenuDefaults/
InfoBarDefaults/ChatBubbleDefaults/AuraDefaultsFor/PortraitDefaultsFor/FillDefaults`.
Claves de "elemento unico" (routing en `CurrentProfile`): `INFOBAR_KEY`, `MICROMENU_KEY`,
`CHATBUBBLE_KEY`, `TRACKER_KEY` (+ `IsInfoBar/IsMicroMenu/IsChatBubble/IsTracker/IsAura/IsPortrait`).
Tracker.lua expone `ns.RefreshTracker`. Options.lua fija hooks opcionales:
`ns.OnUnlockChanged`, `ns.OnProfilePasted`, `ns.OnDragStopped`.

## Unidades (`UNITS` en core.lua)
player, target, targettarget (ToT), pet, focus, playerpower, targetpower,
boss1-5, party1-5. Cada `def` puede tener: `kind` ("health"/"power"),
`driver` (state driver de visibilidad), `fixedColor` (boss).
- Vida = `SecureUnitButtonTemplate` + `RegisterUnitWatch` (o state driver).
- Poder = Frame NORMAL (no seguro, sin menu) + `SetShown` en el ticker.
Cada unidad se guarda en `frames[key]` con: button, bg, editBG, cage, bar (StatusBar),
fillTex (relleno manual), castBar (Frame)+castFill+castSpark, overlay+hpText/nameText/spellText.

## Rendimiento (ticker 0.1s)
El ticker principal corre 10×/seg por cada unidad/portrait. Para consultas seguras de la API
usar los helpers **`safeBool(fn, ...)`** (booleano) y **`safeVal(fn, ...)`** (valor o nil) en vez de
`pcall(function() x = fn(a) end)`: `pcall(fn, ...)` NO crea una closura por llamada (la variante con
`function()` aloja una closura nueva cada tick → basura para el GC). Ej: `dead = safeBool(UnitIsDeadOrGhost, u.unit)`.
NOTA: `safeBool` coerce a booleano — pero si `fn` devuelve un BOOLEANO SECRETO, coercer (`r and ...`)
crashea, asi que `safeBool` chequea `issecretvalue(r)` ANTES de coercer y devuelve false si es secreto
(el pcall solo protege la LLAMADA, no la coercion posterior — por eso la coercion debe ir tras el guard).
Para valores (numeros/strings, incluidos secretos que solo se pasan a C o a `type()`) usar `safeVal`.
Quedan como `pcall(function()...end)` los casos multi-retorno, multi-linea o con efectos secundarios
(SetText/SetTexture/etc.), que no ganan nada con el helper.

## Escala general por elemento (`scale`)
Cada elemento (units/portraits/auras/infobar/micromenu) tiene un campo `scale` (default 1.0) que se
aplica con **`root:SetScale(scale)`** — multiplica el tamaño VISUAL sin tocar los Width/Height/size
guardados. Se aplica en cada apply del elemento (`UnitApplyLayout` [combat-guarded, secure],
`PortraitApplyAppearance`, `AuraGroupPlace`, `RefreshInfoBar`, `MM_Place`). **Ajustable de 2 formas:**
(1) slider "Scale" en el menu de cada elemento; (2) **rueda del raton en modo Lock** (`AttachScaleWheel`
= OnMouseWheel que hace `self:SetScale`; `EnableMouseWheel` se togglea en `SetUnlocked` solo en preview,
para no pisar el zoom de camara fuera; refresca el slider via `ns.OnScaleWheel`). Menu: Width/Height de
la barra se MOVIERON de la seccion General a la seccion **Bar** (#2); General ahora tiene el slider Scale.

## Secret numbers (Midnight) — CLAVE
Vida/poder/nombres pueden ser secretos: NO hacer aritmetica/comparacion/concatenacion en Lua.
- Relleno secret-safe: `StatusBar:SetValue(secret)` (funcion en C).
- Texto: `UnitHealthPercent`/`UnitPowerPercent` + `FontString:SetFormattedText("%.0f%%", secret)`
  (formatea en C). Valor: `AbbreviateNumbers(secret)`. Nombre: `SetFormattedText("%s", UnitName)`.
- Deteccion: `issecretvalue(v)`. `GetHealthPercent`/`GetUnitFraction` devuelven un flag "legible".

## Relleno de barras (por que hay 2 caminos)
El StatusBar nativo **desliza la textura** al invertir (reverse). Solucion estilo WeakAuras:
- **`RenderManualFill(tex, container, frac, reverse)`**: ancla la textura a un lado y la
  recorta (`SetWidth`+`SetTexCoord`). NO desliza. Requiere `frac` numerico (legible).
- `UnitUpdateBar`: si el valor es **legible** -> relleno MANUAL (`u.fillTex`, oculta el
  relleno nativo con `GetStatusBarTexture():SetAlpha(0)`). Si es **secreto** -> StatusBar
  nativo `SetValue(secret)` + `SetReverseFill` (normal OK; inverse puede deslizar, es el limite).
- `BarOnUpdate` (OnUpdate del bar): smooth (lerp del frac) con relleno manual.
- Orientacion: Left-to-Right (base), Inverse (`reverseFill`), Smooth (`smooth`).

## Cast bar (SECRET-SAFE)
`castBar` = **StatusBar** (no Frame) + `castSpark`. En Midnight los tiempos de casteo de
unidades NO-player (enemigos) son **secret values**, asi que NO se puede calcular el progreso
en Lua (`endMS - startMS` peta). Por eso `CastOnUpdate` usa **`StatusBar:SetTimerDuration(dur,
smoothing, dir)`** (rellena en C): `dur` = `UnitCastingDuration`/`UnitChannelDuration` (objeto
secret-safe), `dir` = `Enum.StatusBarTimerDirection.ElapsedTime` (casteo) / `RemainingTime`
(canal), `smoothing` = `Enum.StatusBarInterpolation` (NUMERO: Immediate/Linear, NO booleano).
**OJO (Midnight):** el `castID`/`spellID`/`name` de enemigos son SECRETOS — NO se pueden
comparar/concatenar (peta con taint). `ReadCastMode` detecta cast nuevo por el MODO
("cast"/"channel"/nil, solo compara con nil); `SetTimerDuration` se llama UNA vez por cast
(al cambiar el modo). `ResetCastBar(key)` fuerza re-deteccion en target/focus/pet change (el
frame reapunta a otra unidad). Fallback: si no hay
API/duracion, progreso manual con `GetCastProgress` + `SetValue` (solo tiempos legibles, p.ej.
player en clientes viejos). El **spark se ancla al borde del relleno**
(`GetStatusBarTexture()` RIGHT/LEFT) para seguirlo sin LEER el valor (que puede ser secreto).
Preview = barra estatica 60% (`SetValue(0.6)`). Solo se controla textura, color, opacidad,
ancho/alto, Inverse (`SetReverseFill`) y Smooth. Spark = atlas `Legionfall_BarSpark`, con tamaño
INDEPENDIENTE del resto del cast: `castSparkWidth`/`castSparkHeight`/`castSparkScale` (size = W*scale,
H*scale). Menu: sliders "Spark width/height/scale" en la seccion Cast.

## Modo edicion / preview (`/mcf` o boton Preview)
`unlocked = true`: muestra TODAS las barras llenas (preview) aunque no exista la unidad;
el ticker hace early-return. El recuadro de edicion NO es un bloque verde: es un **borde fino de
1px estilo "seleccion de editor" (cian suave) + relleno casi imperceptible**, creado por el helper
`MakeEditHighlight(parent)` (Frame por encima del contenido; reemplaza los 5 editBG verdes de
unidad/portrait/aura/infobar/micromenu). Color en `EDIT_HL` (facil de cambiar o hacer configurable).
`db.hideEditGreen` lo apaga (el dbKey conserva el nombre por compatibilidad).
Frames seguros: posicion/tamaño solo fuera de combate (se difiere a `PLAYER_REGEN_ENABLED`).

## Portraits (elementos aparte de las unidades) — `PORTRAITS` / `db.portraits`
NO son unidades: cada portrait es un frame propio (`ns.portraits[key]`, no seguro). Registro
en `PORTRAITS`: player/pet/focus (kind=model, dualPos), target (model, deadOnly), tot +
party1-5 (kind=icon). Flags por def: `kind` "model" (`PlayerModel`) o "icon" (icono de clase
via `CLASS_ICON_TCOORDS` + `UI-Classes-Circles`); `features` (rest/faction/combat/dualPos);
`requireExists` (solo si la unidad existe); `deadOnly` (solo si esta muerta — target).
bg/pic/cage/death son universales. Defaults en `PortraitDefaultsFor` (ramifica por key). DB
`db.portraits[key]`. Helpers ns: `IsPortrait/PortraitFeatures/PortraitKind`. `CurrentProfile/
ApplyCurrent/ResetUnit` enrutan a portraits. Refresh: `RefreshPortrait/RefreshAllPortraits`
(la 2da la llama `RefreshAll`). `PortraitShouldShow` = enabled + (requireExists→existe) +
(deadOnly→muerta) + (icon→clase legible via `PortraitClassCoords`). `PortraitUpdatePicture` =
modelo 3D o icono segun kind (`u.pic` = model|classIcon). Ticker 0.1s: iconos se refrescan
cada tick (tot cambia), modelos al aparecer (`_wasShown`); eventos UNIT_PET /
PLAYER_FOCUS_CHANGED / PLAYER_TARGET_CHANGED recargan el retrato. Badges (death/faction/
combat) con color (`*Color`) + opacidad (`*Alpha`). bg/cage con textura configurable
(`bgTexture`/`cageTexture`). Presets incluyen `db.portraits`.

**Raid target marker (feature `raidTarget`, solo party1-5):** badge con el marcador de banda
(calavera/cruz/estrella...) ENCIMA del portrait, solo si la unidad esta marcada. Textura CUSTOM
`Assets\raid_target_icons.tga` (grid estandar 4x4). `PortraitUpdateRaidTarget`: llama
`SetRaidTargetIconTexture(tex, GetRaidTargetIndex(unit))` (fija los texcoords correctos por indice)
y LUEGO `tex:SetTexture(customPath)` (SetTexture no toca texcoords) — mismo truco que AzeriteUI
(que aplica su media custom manteniendo los coords de SetRaidTargetIconTexture). Dinamico via el
ticker (dentro de `PortraitUpdateState`). Config `showRaidTarget/raidTargetTexture/raidTargetScale/
raidTargetAlpha/raidTargetOffsetX/raidTargetOffsetY`; gateado por `features.raidTarget`. Menu:
seccion `p_raid` (label "Mark", `PortraitSectionAllowed` la muestra solo si feats.raidTarget) +
picker categoria `raidtarget` en `ns.TEX_LIB`. Preview = calavera de muestra (index 8).
**Bounce suave** (`raidTargetBounce`, default true): `u.raidtargetAnim` = AnimationGroup Translation
±2px 0.9s loop (mas leve/lento que el de combate ±5px/0.3s); Play/Stop en `PortraitUpdateRaidTarget` segun
visible + bounce. Toggle "Bounce (gentle)" en `p_raid`.
**Fade suave al aparecer/desaparecer** (`u.raidtargetFade` = AnimationGroup Alpha 0.3s): `RaidTargetSetVisible(u, show)`
dispara la transicion SOLO al cambiar de estado (`u._rtVisible` guard, no cada tick): fade-in con alpha BASE=target
+ anim FromAlpha=0 (CLAVE: una anim Alpha es override temporal → al terminar revierte al alpha base; si el base
fuera 0 el marcador se DESVANECERIA tras el fade; con base=target queda visible), fade-out target→0 con
`OnFinished`→Hide. Independiente del bounce (Translation, otra AnimationGroup). El
`PortraitUpdateRaidTarget` llama `RaidTargetSetVisible` en vez de `rt:Show/Hide` directo (salvo el hide instantaneo
cuando la feature/toggle esta OFF).

**Iconos de ROL + LIDER (feature `roleLeader`, solo party):** badges de rol (tank/heal/dps) y lider
sobre el portrait. `PortraitUpdateRoleLeader`: rol via `UnitGroupRolesAssigned` (TANK/HEALER/DAMAGER/
NONE) → textura CUSTOM completa por rol (`ROLE_TANK/HEAL/DPS` = `Assets\icon_badges_tank/heal/dps.tga`,
`SetTexture` por rol, sin texcoords); lider via `UnitIsGroupLeader` → `LEADER_TEX` = `Assets\icon_badges_lider.tga`.
Ambos LEGIBLES (no secretos). Config `showRole/roleScale/roleAlpha/roleOffsetX/Y` +
`showLeader/leaderScale/leaderAlpha/leaderOffsetX/Y`. Menu: seccion `p_role` (label "Role", gateada por
feats.roleLeader). Preview = rol HEALER + lider de muestra. Nota: al llegar a 10 pestañas de portrait,
se achicaron a 42px ancho / 44px spacing para que quepan.

**Click abre el panel de personaje (solo player portrait):** opcion `clickOpenChar` (portrait DB,
default true SOLO en `portrait_player`). El `root` del portrait captura mouse fuera de preview si
`clickOpenChar` (ademas de en preview para arrastrar); `OnMouseUp` con click izquierdo (y `not unlocked`)
llama `ToggleCharacter("PaperDollFrame")` — NO protegida (Narcissus la llama directo), seguro sin taint
y funciona en combate. Tooltip "Character Info" en OnEnter. `EnableMouse` se recalcula en
`PortraitApplyAppearance` (`unlocked or clickOpenChar`) y en `SetUnlocked`. Menu: toggle en `p_general`
gateado por `portraitPlayerOnly` (solo visible en el player portrait). Reemplaza el
`CharacterMicroButton` que el usuario ocultó del micro menu (`MM_HIDE`).

**Cage de unidad al morir:** opcion `cageHideDead` (unit DB; true para target); en el ticker
`UnitUpdateDeadCage` oculta el cage del unitframe si la unidad esta muerta.

**Highlight de "unidad seleccionada" (target):** textura-borde que se ilumina si la unidad del
frame es tu TARGET actual (`UnitIsUnit(u.unit,"target")` — booleano, NO secreto → seguro).
Textura `u.highlight` en el propio `button`, capa BACKGROUND sublevel -8 = DETRAS de TODAS las
texturas de la unidad (bg, cage/ARTWORK y los frames hijos bar/cast/overlay renderizan encima; el
borde-glow asoma por detras del frame) + `u.highlightAnim` (AnimationGroup Alpha loop = "glow"/latido). `UnitUpdateHighlight` (ticker + fin
de `UnitApplyAppearance`): show si es target (o siempre en preview). Config unit DB:
`showHighlight` (opt-in), `highlightTexture` (default `hp_low_case_miror_s_highlight.tga`),
`highlightWidth/Height/Scale`, `highlightOffsetX/Y`, `highlightColor`, `highlightAlpha`,
`highlightGlow`. Menu: seccion unit `highlight` (label "Sel", oculta para power como Cast); picker
categoria `highlight` en `ns.TEX_LIB`. Creado para todas las unidades no-power (power nunca lo
muestra: showHighlight=false + seccion oculta).

**Aviso de VIDA BAJA (`lowHealthWarn`, opt-in):** el TEXTO de vida se colorea con `lowHealthColor`
cuando HP% < `lowHealthThreshold`, y vuelve al color configurado (`useHealthColor`/`healthColor` o GOLD)
al subir. Se re-evalua cada tick en `UnitUpdateText` (`SetTextColor` dinamico; ya NO hay codigos de
color inline). **SECRET-SAFE (clave):** NO usa `GetHealthPercent` (que puede ser SECRETO en el player →
`readable=false` → el color nunca cambiaba). Usa la fraccion LEGIBLE `u.bar._target` (con `_readable`),
que `UnitUpdateBar` computa via `GetUnitFraction` con **fallback por geometria** (ancho del relleno
nativo / ancho de la barra = fraccion legible aunque la vida sea secreta). `low = lowHealthWarn and
u.bar._readable and u.bar._target < thr/100`. Config `lowHealthWarn/lowHealthThreshold/lowHealthColor`;
menu seccion Health (col R).
(HISTORICO: antes era un overlay rojo pulsante `u.lowhp` con param Intensity — ELIMINADO por pedido;
ahora solo colorea el texto.)

**"Hide text" en preview, reemplaza "Health" (2026-07-15):** el toggle viejo `db.lockHide.health`
(solo tapaba `hpText`) "no hacia nada" segun el usuario — causa real: `UnitTextVisibility`
(llamada tambien desde `OnEnter`/`OnLeave` del hover, no solo el ticker) tenia una rama `if
unlocked then hpText:SetAlpha(p.textAlpha) return end` que IGNORABA `lockHide` por completo y
reponia el alpha visible en cada hover — el toggle se "pisaba solo" al pasar el mouse por el
frame en preview. **FIX + reemplazo:** `db.lockHide.text` (nuevo, reemplaza `.health`) oculta
TODO el texto en preview (nombre + hechizo + vida %/numero), no solo la vida; gateado en el
bloque `if unlocked` de `UnitApplyAppearance` (los 3 textos leen `hideText = lh.text`) Y en
`UnitTextVisibility` (la rama `unlocked` ahora SI respeta `lockHide.text`, arreglando el pisado
por hover). Menu: label cambiado "Health" → "Hide text" en el grupo "Hide in preview".

**Menu portraits:** sidebar con SCROLL (`UIPanelScrollFrameTemplate` + rueda), porque hay
muchas entradas. Secciones `p_general/p_pos/p_bg/p_model/p_cage/p_rest/p_death/p_badges/p_raid`.
Grupos condicionales via sub-frames: `portraitDualBoxes` (bloques de posicion alterna +
condiciones, solo dualPos), `portraitModelOnly` (slider de zoom, solo kind=model). Etiquetas
de pestana cortas para no chocar.

**Estructura del frame** (orden de capas, atras->frente): `root` (Frame) → `bg` (fondo
circular `Circle_Smooth_Border`, coloreable via SetVertexColor) → `model` (PlayerModel,
`SetUnit`+`SetPortraitZoom`, frame level root+1; el fondo del modelo es transparente asi que
no hay que enmascarar el cuadrado) → capa `icons` (frame root+2) con: `rest` (flipbook de
descanso, ARTWORK -1, debajo del borde), `cage` (borde/orbe `orb_case_low`, ARTWORK 0),
`death` (marca de muerte, textura custom `DEATH_TEX` = `Assets\icon_skull_dead.tga`, OVERLAY), `faction` (badge
alianza/horda segun `UnitFactionGroup`), `combat` (badge `icon-combat`).

**Flipbook de descanso:** atlas `UI-HUD-UnitFrame-Player-Rest-Flipbook` = **7 filas x 6
columnas = 42 frames** (dato de M33kAuras/Types_Retail.lua). Se anima con un AnimationGroup
+ animacion tipo `FlipBook` (`SetFlipBookRows/Columns/Frames`, Width/Height=0=auto),
`SetLooping("REPEAT")`; Play/Stop segun `IsResting()`. Estado dinamico (rest/muerte/combate)
en `PortraitUpdateState`; faccion en `PortraitUpdateFaction` (+ evento UNIT_PORTRAIT_UPDATE).

**Badges en COMBATE:** en combate el badge de faccion (alianza/horda) se OCULTA
(`PortraitUpdateFaction` chequea `UnitAffectingCombat("player")`, guard `not unlocked` para
poder editar en preview; se llama tambien desde `PortraitUpdateState`/ticker → dinamico). El
badge de combate tiene un BOUNCE (`u.combatAnim` = AnimationGroup en la textura `combat`, 2
Translations +5/-5 y en loop REPEAT) que Play/Stop en `PortraitUpdateState` segun `showCombat
and not preview`.

**Doble posicion (player):** `PortraitUpdatePosition` usa la posicion "centro"
(centerAnchor/centerPoint/centerRelPoint/centerX/centerY) si `PortraitCenterActive` (toggles
`centerOnTarget`/`centerInCombat`/`centerInInstance`), si no la "alterna" (alt*). Como el
frame NO es seguro, la posicion cambia en combate sin restriccion. En preview se coloca la
posicion `editPos` ("center"/"alt") y el drag guarda en ESA. Assets copiados en `Assets/`
(Circle_Smooth_Border, orb_case_low, icon_badges_alliance/horde, icon-combat).

**Menu:** grupo "PORTRAITS" en el sidebar; secciones propias `p_general/p_pos/p_bg/p_model/
p_cage/p_rest/p_death/p_badges` (tabs `p_*`, ocultas salvo con un portrait seleccionado) +
Perfil compartida. `PortraitSectionAllowed` oculta p_rest/p_badges segun `features` (el pet no
los tiene). `SelectUnit` alterna la visibilidad de tabs unidad vs portrait. El refresher de
`MakeSlider` ignora claves ausentes (nil) para tolerar el cambio unidad<->portrait.

## Auras (buffs/debuffs de player y target) — `AURAS` / `db.auras`
Sistema aparte (como portraits). **1 grupo por unidad** (`aura_player`, `aura_target`) que
COMBINA buffs+debuffs: `CollectAuras(unit)` junta HELPFUL+HARMFUL y marca `data.__filter` por
aura (para el tooltip). `ns.auras[key]` = grupo con `root` (ancla movible) + pool `buttons`.
`ns.IsAura(key)`; `CurrentProfile/ApplyCurrent/ResetUnit` enrutan a auras.
`RefreshAura`/`RefreshAllAuras` (la 2da la llama `RefreshAll`).

**Texto SIEMPRE delante del swipe:** `b.dur` y `b.count` van en un frame `b.textOverlay` (hijo de `b`,
frame level `b+2`), por ENCIMA del swipe (Cooldown = `b+1`); antes iban en la capa OVERLAY de `b` y
quedaban DETRAS del swipe radial.

**Query SECRET-SAFE:** `CollectAuras` usa `C_UnitAuras.GetAuraDataByIndex(unit, i, filter)`
(campos: `icon`, `applications`=stacks, `duration`/`expirationTime` (pueden ser secretos),
`auraInstanceID`, `name`). Sort con `SafeNum` (secretos → math.huge, van al final): index/
timeUp/timeDown/name. **Duracion (texto) secret-safe:** `C_UnitAuras.GetAuraDuration(unit,
auraInstanceID)` → duration object; **`durationObject:EvaluateRemainingTime()`** devuelve el
restante como numero LEGIBLE (Blizzard permite MOSTRARlo, no operar). Se pinta en un
**fontstring propio** (`b.dur`, offset GLOBAL del grupo) actualizado en el ticker 0.1s — NO
se usan los numeros nativos del Cooldown (dependen de un CVar). El **swipe** radial sí usa
`Cooldown:SetCooldownFromDurationObject`. Fallback legible: `expirationTime - GetTime()`.

**Grid "centrado horizontal, hacia abajo":** `UpdateAuraGroup` coloca cada boton por
CENTER a `root`: `row=floor(i/perRow)`, cada fila se centra (`startX=-rowW/2+icon/2`),
`y=-row*(icon+rowSpace)`. Controles: iconSize, perRow (ancho de fila), colSpace, rowSpace,
limit, sort. Borde = `actionbutton-border square.tga` (coloreable). Update via eventos
UNIT_AURA / PLAYER_TARGET_CHANGED (no ticker para el layout; el ticker solo refresca el texto
de duracion). Preview = auras de muestra. Menu: grupo "AURAS", secciones `a_general/a_grid/
a_pos/a_style`. Presets incluyen `db.auras`. **Tooltip:** el boton tiene OnEnter/OnLeave con
`GameTooltip:SetUnitAuraByAuraInstanceID(unit, auraInstanceID)` (fallback buff/debuff-specific);
mouse activado solo fuera de preview y con `showTooltip`. `iconSize` esta en la pestana Grid.

**Player Auras (solo dualPos):** `AuraGroupPlace` = TRI-posicion (prioridad muerte >
principal > alterna): muerte si `useDeadPos` y `UnitIsDeadOrGhost("player")`; principal si
`AuraCondActive` (target/combate/instancia); si no, alterna. `editPos` = center/alt/dead
(preview). **Opacidad:** `groupAlpha` (base, def 0.5); `UpdateAuraAlpha` la sube a 100% si hay
condicion, si el boton tiene el mouse encima (`b._hover` en OnEnter/OnLeave) o en preview.
Corre en el ticker + al hover. El mouse del boton se activa tambien para el hover-alpha.
`AuraCondActive`/`UpdateAuraAlpha` se definen ANTES de `CreateAuraButton` (su OnEnter las usa).
Menu: `auraDualBoxes` gatea editPos+condiciones+opacidad (a_general) y la posicion alterna
(a_pos) solo para player; la pestana `a_dead` (posicion de muerte) solo se muestra para player.

**Selector de texturas (menu):** WoW NO puede listar archivos del disco → manifiesto en core
`ns.ASSETS`/`ns.TEX_SKINS` (subcarpetas de `Assets\` con los MISMOS nombres de archivo)/
`ns.TEX_LIB` (por categoria: bar/cage/portraitbg/portraitcage/auraborder). `MakeTexturePicker`
= editbox (ruta manual) + swatch preview + boton "..." → `OpenTexPopup` (popup con scroll,
filas por skin con preview; click setea la ruta). Reemplaza los MakeEditBox de textura.
Para agregar una skin: crear carpeta en `Assets\`, copiar las texturas, agregar a `ns.TEX_SKINS`.

**Boton "Perfil" GLOBAL:** en la esquina sup. derecha del panel (`perfilBtn`), FUERA de las
pestañas por-elemento; abre `ShowSection("presets")`. Las ramas de `SelectUnit` ya no
exceptuan "presets" (elegir un elemento sale de esa vista). La seccion `presets` sigue siendo
la misma (guardar/cargar/borrar/default/reset/globales).

**Scrollbar del sidebar (menu):** CUSTOM estilo Plumber (no UIPanelScrollFrameTemplate).
ScrollFrame plano + `Slider` vertical con rail+thumb 3-slice de `SettingsPanelWidget.png`
(texcoords /512 x0-32: rail y0-128, thumb y132-260). `updateScroll` fija el rango (content-
visible), oculta la barra si no hay scroll y dimensiona el thumb por proporcion; rueda del
raton via el slider. Se llama tras `sbChild:SetHeight` y en OnSizeChanged.

## Info Bar (`INFOBAR_KEY`="infobar" / `db.infobar` / `ns.infobar`)
Elemento unico (no lista). Muestra hora (`GetGameTime`, 12h), fps (`GetFramerate`), ms
(`GetNetStats` world = 4to retorno), zona (`GetMinimapZoneText`, truncada a 25) + fondo
decorativo configurable (`bgTexture`, default `Assets\info_bg.tga` = `INFOBAR_BG_TEX`; si el valor
NO acaba en .tga/.blp se trata como atlas — el default previo era el atlas
`majorfaction-celebration-thewarwithin-bottomglowline`). Picker categoria `infobg` en `ns.TEX_LIB`,
seccion `i_bg`. El **reloj** es un
Button: hover = tooltip (reino/hora local+servidor, globals `TIMEMANAGER_*`), click =
`ToggleCalendar()` (guardado fuera de combate). Cada elemento es un frame propio anclado por
CENTER a `root` con su offset individual; en preview cada uno es arrastrable — mueve solo ese
elemento (guarda su offset) o TODO junto si `db.infobar.moveTogether` (mueve el root). El root
tambien se arrastra por su zona libre. Valores refrescados ~1/seg en el ticker
(`UpdateInfoBarValues`); `RefreshInfoBar` = apariencia+posicion+valores (`ns.RefreshInfoBar`,
la llama `RefreshAll`). Routing en `CurrentProfile/ApplyCurrent/ResetUnit` por `INFOBAR_KEY`.
Menu grupo "INFO" secciones `i_general/i_pos/i_elements/i_bg`. Presets/reset/InitDB lo incluyen.

## Micro Menu (`MICROMENU_KEY`="micromenu" / `db.micromenu` / `ns.micromenu`)
Reskina los micro-botones SEGUROS de Blizzard (Professions/PlayerSpells/Achievement/QuestLog/
Housing/Guild/LFD/Collections/EJ/Store/MainMenu/Help) con iconos custom (copiados de W2UI/
Media/MenuBar a `Assets\`: `02_crossed_hammers`…`12_question_mark`), los reagrupa en un frame
propio (`MyCF_MicroMenu`) movible+escalable, **SIN fondo**. `MM_SkinButton`=hide arte original
(MM_ART_KEYS + Get*Texture) + icono 32px + hover; hooks Set*Texture/Atlas + `MicroButtonPulse`
+ `UpdateMicroButtons` + `MM_ReassertArt()` en el ticker (nunca vuelve el icono original).
`MM_HIDE={"CharacterMicroButton"}` (ocultado). Reparent/posicion/escala PROTEGIDO → solo fuera
de combate (`micromenu.needsLayout`→PLAYER_REGEN_ENABLED). `MM_Restore` al desactivar. Menu:
grupo sidebar "MICRO", seccion `mm_general`.

## Chat Bubble (`CHATBUBBLE_KEY`="chatbubble" / `db.chatbubble`)
Oculta el fondo de los bocadillos del mundo + controla fuente/tamaño/outline/color. Metodo
moderno (calcado de Prat): `C_ChatBubbles.GetAllChatBubbles(false)` → `:GetChildren()` →
`.String` (fontstring) + fondo en `.Center`/`.Tail`/8 esquinas-bordes (`CB_EDGES`→SetTexture nil).
Fuente global via `ChatBubbleFont:SetFont/SetTextColor` + refuerzo por-bubble. Ticker propio
0.1s. Menu: grupo "CHAT", seccion `cb_general`.

## Quest Tracker (`Tracker.lua`, `TRACKER_KEY`="tracker" / `db.tracker` GLOBAL)
**ESTADO FINAL 2026-07-15 (tanda 11, causa raíz encontrada y arreglada — ver memoria
`project-mycustomframes-pending-bug` para la saga completa de 11 tandas).** Colorea titulos y
objetivos del ObjectiveTracker + oculta el tracker en peleas de boss.
- **Coloreado ACTUAL:** `ApplyFontColor(fs, r,g,b)` = `SetTextColor` DIRECTO por fontstring (cache
  `fsState`, weak-keyed, evita re-aplicar si no cambio), via `TraverseFrame(otf)` recursivo. Tiene
  exclusiones defensivas (no eran la causa raíz, pero se conservan): saltea
  `ScenarioObjectiveTracker`/`UIWidgetObjectiveTracker` (solo su header) y botones pooled
  (`ItemButton`/`itemButton`/`GroupFinderButton`/`groupFinderButton`/`poiButton`/`rightEdgeFrame`).
  **`PatchColorTable`/`RestoreColorTable`/`colorBackup`/`STATUS_COLOR_KEYS` FUERON ELIMINADOS POR
  COMPLETO** (eran la causa raíz real del taint, ver abajo) — YA NO EXISTEN en el archivo.
- **CAUSA RAÍZ DEL BUG `ADDON_ACTION_BLOCKED:ObjectiveTrackerFrame:Show()` (encontrada 2026-07-15):**
  NO era tocar frames protegidos con SetTextColor (se probó explícitamente y el error seguía). Era
  `PatchColorTable` **mutando campos de la tabla GLOBAL COMPARTIDA `OBJECTIVE_TRACKER_COLOR`
  (`tbl[k].r/g/b = ...`) en un loop que corría sin parar cada 0.4s** — Blizzard lee esa tabla dentro
  de su propia lógica protegida de render/Show, y la mutación repetida ininterrumpida SÍ tainteaba
  pese a ser "solo indexar campos, no reasignar la tabla". Confirmado en juego tras desactivar
  únicamente `PatchColorTable` (dejando TraverseFrame/ApplyFontColor intactos): el error desapareció.
  **REGLA DE ORO nueva: ni siquiera MUTAR CAMPOS de una tabla global compartida de Blizzard dentro de
  un ticker continuo es seguro — no solo la reasignación (`X = X or {}`) tainteaba (regla de la
  tanda 8), la mutación repetida de un valor leído por código protegido también.**
- **Titulo vs objetivo:** el nombre de mision Y sus objetivos usan la MISMA fuente
  (`ObjectiveTrackerLineFont` sz12) → indistinguibles por fuente. `IsObjectiveLine(text)` (por
  PATRON DE TEXTO: progreso `%d+/%d+`, `%d+%%`, empieza con "-" o numero) salta los objetivos.
  Limitacion: objetivos SIN numero no se distinguen del titulo. Headers usan
  `ObjectiveTrackerHeaderFont` sz14. Diagnostico: `/mcftrackerdump` (caja copiable).
- **Persistencia:** Blizzard re-colorea el titulo tras cada update/mouseover/reload → un ticker
  LENTO `C_Timer.NewTicker(0.4, RecolorTracker)` re-aplica despues + hook debounce 0.05s de
  `ObjectiveTracker_Update` + eventos. (Este ticker ahora SOLO llama TraverseFrame/ApplyFontColor,
  ya NO toca ninguna tabla global.)
- **Hide-in-boss:** `SetupBossHider` = `SecureHandlerStateTemplate` hijo del tracker,
  `_onstate-vis` + driver `[@boss1..5,exists]hide;show`; OnHide→`SetAlpha(0)` (SEGURO, NO afectado
  por la saga de taint — independiente de todo el sistema de coloreado).
  REGLAS anti-"Cannot call restricted closure from insecure code" (RestrictedExecution.lua:470):
  (1) NUNCA registrar un driver CONSTANTE ("show") — se aplica inmediato/sincrono dentro de nuestra
  llamada insegura y el snippet se invoca desde codigo inseguro; con feature OFF se UNREGISTRA el
  driver (h._mcfDriver=nil) + h:Show() + alpha 1. (2) Re-registrar solo si el driver CAMBIO
  (`h._mcfDriver`). (3) `h.mcfSkipTraverse=true` y `TraverseFrame` lo salta (el walk de recolor
  no debe entrar en el handler seguro).
- Menu: grupo sidebar "TRACKER", seccion `t_general` (Colorize titles/Title color/Hide in boss
  fights). `db.tracker` es GLOBAL (NO en presets).
- **"Hide in preview" (2026-07-15):** nuevo toggle "Quest tracker" en `db.lockHide.tracker`
  (seccion Editing, grupo "Hide in preview (Lock only)", junto a Health/Outline names/Badges/Raid
  marks/Death marks). Oculta `ObjectiveTrackerFrame` SOLO mientras el addon esta en modo
  edicion/preview (`ns.IsUnlocked()`), para que no estorbe al mover/editar otros elementos —
  **SOLO por ALPHA** (`SetAlpha(0/1)`, NUNCA `Show()/Hide()` del frame protegido: mismo patron que
  `HB_HideAlpha` y el boss-hider, el alpha no requiere permiso seguro). `ns.ApplyTrackerPreviewHide`
  (Tracker.lua) corre en el ticker de 0.4s existente (siempre, independiente de "Colorize titles")
  + se llama AL TOQUE desde `ns.OnUnlockChanged` (Options.lua, encadenado con el
  `previewBtn:SetActive`) para reaccionar instantaneo al togglear Lock, no esperar hasta 0.4s.
- **PENDIENTE:** validar con más sesiones de juego normal (el bug era intermitente/raro) antes de
  darlo 100% por cerrado, pero la señal de la tanda 11 es fuerte.
- **HERRAMIENTA CLAVE aprendida en esta saga:** `taint.log` (`E:\World of Warcraft\_retail_\Logs\
  taint.log`, activar con `/console taintLog 2`) es la ÚNICA forma confiable de encontrar la causa
  real de un taint — 5+ hipótesis previas (hook SetTexture, inyección AzeriteUI, Micro Menu,
  calendario, boss-hider) fueron descartadas leyendo el log real en vez de adivinar.

## Assisted Glow (`GLOW_KEY`="glow" / `db.glow`)
Glow custom sobre el **highlight de la rotacion asistida** (Assisted Combat): Blizzard
resalta el boton de accion que recomienda pulsar; aqui se reemplaza por un glow
configurable. APIs (verificadas en Midnight): `C_AssistedCombat.GetNextCastSpell(onlyVisible)`
(spellID recomendado), `C_AssistedCombat.GetActionSpell()`, `C_ActionBar.FindSpellActionButtons(spellID)`
(slots que tienen la magia), CVar `assistedCombatHighlight="0"` (apaga el highlight nativo).
- **SECRET-SAFE:** el spellID PUEDE ser secreto → `SafeSid()` lo descarta ANTES de cualquier
  comparacion (comparar un secreto crashea); `GetNextCastSpell` va en `pcall`.
- **Botones:** `GlowBuildButtonCache` junta LibActionButton-1.0 + el fork `-GE` (AzeriteUI) +
  barras nativas de Blizzard (ActionButton/MultiBar*). Cache invalidado por eventos
  ACTIONBAR_PAGE_CHANGED/UPDATE_BONUS_ACTIONBAR/PLAYER_SPECIALIZATION_CHANGED/PLAYER_ENTERING_WORLD.
  `GlowFindButtons(sid)` matchea por slot (`FindSpellActionButtons`) o por `GetActionInfo`.
- **Glow:** overlay NO seguro parentado al boton (patron LibCustomGlow → visual puro, sin taint).
  Estilos (`ns.GLOW_STYLES`): **"Texture"** (DEFAULT, textura propia `f.glowTex` aditiva + latido
  de opacidad `f.glowPulse` = AnimationGroup Alpha loop; textura configurable `glowTexture`, default
  `Assets\actionbuttonhighlight.tga` = `GLOW_TEX_DEFAULT`; categoria de picker `ns.TEX_LIB.glow`),
  **"Border"** (4 lados dibujados, sin lib), y **Pixel/AutoCast/Button** (requieren `LibCustomGlow-1.0`,
  opcional via `LibStub(...,true)`; si falta, esos caen a Border). `ns.HasLCG`.
- **Ticker propio 0.1s** (corre aunque estemos en preview; el glow no es un frame movible).
  `RefreshGlow(force)`: force=true (config change / ApplyCurrent / RefreshAll) reinicia todos
  los glows; el tick normal solo diffea (apaga los que ya no aplican, enciende los nuevos).
- Config: enabled, disableNative (apaga highlight de Blizzard), style, glowTexture, pulse, color,
  alpha, thickness, scale, onlyVisible, checkUsable. Menu: grupo sidebar "GLOW", seccion `g_general`
  (incluye MakeTexturePicker "Glow texture", categoria "glow"). En presets
  (Save/Load/Export/Import), como micromenu/chatbubble.

## Utilidades globales (`db.*` top-level, seccion Profile→Global options)
- **`db.mouselook`** (default false): clic-derecho + arrastrar rota la camara (aunque empieces
  sobre un frame); clic rapido = normal. Eventos GLOBAL_MOUSE_DOWN/UP + `MouselookStart/Stop`.
- **`db.hideBlizzard`** (default false): oculta unitframes NATIVAS (player/pet/target/tot/boss/
  party + cast bar). `HB_Handle` = SOLO `RegisterStateDriver("visibility", "hide")` (NO
  `UnregisterAllEvents`, se saco por taint en PlayerFrame/CompactPartyFrameMemberN — ver
  comentario largo en core.lua). Diferido en combate. Desactivar = /reload.
  **FIX 2026-07-15 "cast bar aparece un instante al castear":** `RegisterStateDriver` con
  condicion CONSTANTE ("hide") solo se evalua al registrar, NO intercepta cada `Show()` futuro —
  como la cast bar conservaba sus eventos nativos (`UnregisterAllEvents` general sacado por el
  taint de arriba), `UNIT_SPELLCAST_START` le llamaba `Show()` directo → flash hasta que el driver
  la re-ocultaba. **`HB_HandleCastBar`** (funcion NUEVA, separada de `HB_Handle`, SOLO para
  `PlayerCastingBarFrame`/`CastingBarFrame`/`PetCastingBarFrame`): SI hace
  `UnregisterAllEvents()+Hide()` ADEMAS del state driver — seguro para cast bars especificamente
  porque el taint reportado era en `TextStatusBar`/`UpdateHealthColor` (texto de vida), funciones
  que una cast bar nunca ejecuta (no tiene "secret numbers" de por medio). PENDIENTE VALIDAR EN
  JUEGO.
- **`db.fadeIn`** (default true, `db.fadeDuration` 0.25): fade-in al aparecer un frame.
  `AttachFadeIn` hookea OnShow → **AnimationGroup con animacion Alpha** (NO `UIFrameFadeIn`, que
  llama Show() y se bloquea en frames seguros). Solo fade-IN (el fade-OUT no es viable en
  frames seguros). Enganchado a `frames[].button` + `portraits[].root` en PLAYER_ENTERING_WORLD.
- **`db.hideEditGreen` / `db.groupMoveParty` / `db.groupMoveBoss`** (zona verde en preview /
  mover grupos juntos).
- **`db.dcFix`** (default true): fix cross-addon DialogueUI+DynamicCam. DialogueUI llama
  `DynamicCam:BlockShoulderOffsetZoom()` al abrir su panel (pone `shoulderOffsetZoomTmpDisable=true`,
  que cortocircuita la aplicacion de camara de las custom situations). `ns.ApplyDcFix()` neutraliza
  ambos metodos (no-op que fuerzan el flag a false) y es TOGGLEABLE: al apagarlo RESTAURA los
  originales (guardados 1 vez en `ns.dcOrig` ANTES de sobrescribir). Se llama en PLAYER_ENTERING_WORLD
  y al cambiar el toggle. `DynamicCam` es global real (`NewAddon` sin local). Toggle "DynamicCam camera
  fix" en Global options. NOTA: es neutralizacion TOTAL de Block/AllowShoulderOffsetZoom (no solo
  DialogueUI).

## Power bar al morir
`PowerShouldShow` (decide `u.button:SetShown`): playerpower se OCULTA SIEMPRE si
`UnitIsDeadOrGhost("player")` (toda la barra, no solo el cage); si no, visible en combate o con
target hostil. targetpower oculta si self-target muerto.

## Party1-5: visibilidad (driver)
`PartyDriverString`/`UpdatePartyDrivers`: solo visibles en grupo pequeño; OCULTAS en raid y en
instancia PvP (arena/BG). Driver: si `IsInInstance` type pvp/arena → "hide"; si no
`[group:raid]hide; [@partyN,exists]show; hide` (el `[group:raid]` seguro/dinamico oculta en
CUALQUIER BG sin depender del timing Lua). Recalcula en PLAYER_ENTERING_WORLD/GROUP_ROSTER_UPDATE/
ZONE_CHANGED_NEW_AREA; diferido en combate.

## Cancelar buff (auras): clic derecho
Solo buffs propios del player (`g.unit=="player"` + HELPFUL). `EnsureCancelOverlay` = boton
`SecureActionButtonTemplate` en un HOST ESTATICO (`MyCF_AuraCancelHost`), NO anclado ni
parentado al boton de aura (para no proteger la jerarquia del grupo → se mueve en combate sin
taint); `PositionCancelOverlay` lo coloca con coords ABSOLUTAS (fuera de combate). `type2=macro`
`/cancelaura <name>`, actualizado en StyleAuraButton fuera de combate. Secret-safe: si
`data.name` es secreto no es cancelable. Toggle `allowCancel` en a_general (player).

## Presets (perfil de TODO el addon)
`db.presets[name] = { units, portraits, auras, infobar, micromenu, chatbubble, globals }`.
`SavePreset` sobrescribe por nombre (boton "Overwrite" para el seleccionado). `db.defaultPreset`
ya **NO se carga al entrar** (se quito; el layout en vivo persiste via SavedVariables); solo se
usa para "Reset ALL". Export/Import via string "MCF1:{...}" (`Serialize`/loadstring sandbox).
`db.tracker` y las utilidades globales (mouselook/hideBlizzard/fadeIn) NO estan en presets.

## Menu (Options.lua) — estilo Plumber
Layout de 2 paneles: **sidebar** de elementos agrupados + **contenido** con pestañas de seccion.
- **Sidebar COLAPSABLE + BUSCADOR:** cada grupo (MAIN/POWER/BOSSES/GROUP/PORTRAITS/AURAS/INFO/
  MICRO/CHAT/TRACKER/GLOW) tiene header-boton con flecha +/- (`collapsed[grp.title]`); caja de
  busqueda arriba (`searchBox`, `searchText`) filtra por nombre. `RelayoutSidebar()` reubica/
  oculta headers+botones (creados UNA vez) segun colapso+busqueda (sin recrear frames).
- **Secciones por tipo:** unidad (Gen/Bar/Cage/Sel/Health/Name/Spell/Cast/Color; "Sel" y "Cast"
  ocultas para power) + prefijos por
  elemento: `p_*` portraits, `a_*` auras, `i_*` infobar, `mm_*` micromenu, `cb_*` chatbubble,
  `t_*` tracker, `presets`. `SelectUnit` muestra solo las pestañas del tipo seleccionado
  (`IsPortraitSection/IsAuraSection/IsInfoSection/IsMicroSection/IsChatSection/IsTrackerSection`).
- **Seccion Profile (presets):** 2 columnas. IZQ = perfiles (name+Save, `<sel>`, Load/Delete,
  Overwrite/Set default, Export/Import, Save-as-default, Reset ALL). DER = "Global options"
  (Hide green zone/Move Party/Move Boss/Mouselook/Hide Blizzard) + "Quest tracker"→movido a la
  pestaña TRACKER. Boton "Profile" global arriba-derecha.
Widgets con assets reales de Plumber (3-slice `SettingsPanelWidget.png`, fondo
`SettingsPanelBackground.jpg`, fuente `Lato-Bold`). **Checkbox estilo Plumber:** `MakeToggle` usa el
cuadro dorado de `SettingsPanelWidget.png` (mismo archivo 512x512 que Plumber; texcoords normalizados
"1024 design space": unchecked `688..736`, checked `736..784` en x, `16..64` en y) + highlight de fila
dorado sutil en hover + label que se aclara. (Antes usaba el toggle verde `OptionToggle.tga`.)

**Grid de alineacion (Lock mode):** `UpdateGrid` dibuja lineas cada `db.gridSize` px (default 32) desde
el CENTRO de la pantalla (para alinear con offsets relativos a CENTER), overlay NO seguro en
`gridFrame` (BACKGROUND). Solo visible con `unlocked and db.gridShow`. Se llama en `SetUnlocked` y al
cambiar el toggle "Alignment grid" (Global options). `db.gridShow/gridSize` globales (no en presets).
**SNAP (release, `ns.SnapFrameToGrid`):** al soltar hace DOS pasadas por eje: (1) **B2 snap ENTRE
ELEMENTOS** (`db.snapElements`, default on) — `CollectSnapLines` junta las lineas izq/der/centroX
(verticales) y abajo/arriba/centroY (horizontales) de TODOS los elementos movibles visibles
(units/portraits/auras/infobar/micromenu) en px de pantalla; `NearestLine` busca el menor delta dentro
de `SNAP_THRESHOLD`=12px por eje; si engancha, alinea exacto. (2) Para los ejes SIN match de elemento,
cae al **snap de grilla** (`db.gridSnap`). Toggle "Snap to other elements" en la seccion Editing.
El viejo `SnapFrameToGrid(frame)` recolocaba el CENTRO del
frame al punto de grilla mas cercano AL SOLTAR (se llama en cada `OnDragStop` de units/portraits/auras/
infobar-root/micromenu, ANTES del calculo del offset, asi el offset guardado queda alineado). Trabaja
en pixeles absolutos (EffectiveScale) para soportar elementos escalados. OJO: el offset final del
SetPoint se divide por la escala DEL FRAME (`/es`, no `/uies`) — los offsets de SetPoint van en la
escala del frame; dividir por la de UIParent desalineaba el snap con elementos escalados (bug historico).
Se accede via `ns.SnapFrameToGrid`
(los OnDragStop estan en Create funcs, definidos ANTES del helper). Toggle "Snap to grid" en Global options.
PENDIENTE de #3: multi-seleccion (marquee) y menu contextual al click en el outline.
**Nombre sobre el outline:** `MakeEditHighlight(parent, label)` acepta un 2º parametro: fontstring
(FRIZQT 12 OUTLINE, color EDIT_HL) anclado BOTTOM→TOP del recuadro; se ve siempre que el outline se ve.
Labels: units/portraits/auras usan `def.label` ("Player", "Portrait Player", "Aura Target"...), infobar
"Info Bar", micromenu "Micro Menu".
**Area de CLICK del boton seguro (independiente de la barra):** config por unidad `btnWidth/btnHeight/
btnOffsetX/btnOffsetY` (0 = sigue a la barra). Se aplica en `UnitApplyLayout` via **SetHitRectInsets**
(NO cambia la geometria del frame seguro → sin taint; insets negativos AGRANDAN el area). En preview se
limpia (arrastrar sobre todo el recuadro). Sliders "Click width/height/offset" en la seccion Bar.
**Dual position (portraits):** la condicion `centerInInstance` ahora es solo RAID o DUNGEON
(`IsInInstance` type `raid`/`party`), no BG/arena/escenario. (La condicion equivalente de AURAS
sigue siendo cualquier instancia.)

## Focus (#5): unitframe (texto de vida + highlight) sincronizado al portrait
El focus tiene unitframe (secure button) Y portrait (visual 3D). El VISUAL (retrato/fondo/cage) vive
en el **portrait_focus**; el unitframe NO dibuja barra/fondo/cage/nombre/hechizo PERO sí el **texto de
vida (%/valor) y el highlight**, con todas las funciones normales de unitframe (secret-safe, color,
low-health, highlight cuando el focus es tu target). SyncFocusButton lo posiciona/dimensiona sobre el
portrait, asi texto+highlight aparecen sobre el retrato.
- **InitDB** fuerza cada carga: `texture=""`, `showName/showSpell/showBackground=false`, `cageTexture=""`,
  y `showText=true`, `showValue=true` (si nil), `textAutoHide=false` (vida SIEMPRE visible con focus).
  El highlight sale de la config normal del unit (el Export del autor trae `showHighlight=true`).
- **SetUnlocked**: el focus es caso especial — NUNCA muestra editBG ni se arrastra (`RegisterForDrag()`
  vacio, wheel off); se edita desde el portrait_focus. Asi el "focus heredado" YA NO aparece en el Lock.
- **SyncFocusButton** ademas iguala strata al portrait y sube el frame level (+10) para que el texto de
  vida y el highlight rendericen ENCIMA del retrato (fuera de combate).
- **Menu (pestaña "Focus" del portrait, seccion `p_focus`, visible SOLO en portrait_focus):** como el
  texto de vida y el highlight viven en `db.units.focus` (no en el portrait), esta pestaña los edita
  directamente via `fp()=GetDB().units.focus` + `RefreshUnit("focus")`. Controla: Health text
  (show value / font size / offset X-Y / custom color), Highlight (show / pulse / scale / opacity /
  offset X-Y / color). El tab `p_focus` se muestra gateado por `key=="portrait_focus"` en SelectUnit
  (11 pestañas de portrait, ancho 38/step 40).
- **Explorer:** al desvanecer `portrait_focus`, el explorerDriver desvanece TAMBIEN
  `frames["focus"].button` (donde estan el texto de vida + highlight); `ExplorerReset` lo restaura a 1.
- **`SyncFocusButton()`** (ticker, fuera de combate): el secure button COPIA la posicion/tamaño de
  `portraits.portrait_focus.root` con coords ABSOLUTAS sobre UIParent (GetCenter × ratio de escalas,
  SetScale(1)). **NUNCA anclarlo al root del portrait** (secure→insecure): eso PROTEGE el root del
  portrait → su Hide()/SetPoint en combate se bloquea (ADDON_ACTION_BLOCKED) y el taint puede romper
  la visibilidad de TODAS las unidades. Guards: InCombatLockdown/UnitExists("focus")/GetCenter nil.
  En combate no se mueve (frame seguro); se queda en su ultima posicion.
- **`PortraitSetShown(u, shown)`**: unico camino para mostrar/ocultar roots de portraits. Si el root
  esta PROTEGIDO y hay combate: alpha 0/1 + `u._pendingShown` + flag `root._mcfCombatHidden` (el
  Explorer no toca ese alpha); el Show/Hide REAL se difiere a PLAYER_REGEN_ENABLED. Fuera de combate
  (o root no protegido): SetShown normal. `PortraitUpdatePosition` tambien se salta el tick si
  protegido+combate (ClearAllPoints bloqueado).
- Options: **focus quitado del grupo MAIN** del sidebar (su config se edita como portrait, en PORTRAITS).

## Explorer (#11): auto-ocultar + revelar por mouseover
Elementos que se atenuan (alpha→`db.explorerFadeAlpha`, default 0) y reaparecen (alpha 1) con MOUSEOVER
o en combate. Config GLOBAL: `db.explorerEnabled` (toggle MAESTRO, default true), `db.explorer =
{elementKey=true}` (que elementos), `db.explorerCombat` (forzar visibles en combate), `db.explorerFadeAlpha`.
`GetElementFrame(key)` mapea key→frame raiz (units.button/portraits.root/micromenu/infobar.root/auras.root).
**El fade corre POR FRAME** en `explorerDriver` (frame con OnUpdate) con suavizado EXPONENCIAL
independiente del framerate (half-life ~60ms al revelar, ~200ms al ocultar) — el lerp del ticker 0.1s
se veia a saltos. El ticker 0.1s solo refresca `explorerDriver.combat` (secret-safe) y hace
SetShown(driver) segun `explorerEnabled`+hay elementos. `f:IsMouseOver()` es geometrico (no requiere
EnableMouse). Elementos con `_mcfCombatHidden` (portrait protegido "oculto" via alpha en combate) se
saltan. `UnitUpdateMount` NO resetea alpha=1 de elementos gestionados por el Explorer (parpadeaba).
`ns.ExplorerReset(key)` restaura alpha 1 al apagar un elemento; `ns.ExplorerResetAll()` al apagar el
maestro (y en SetUnlocked, para limpiar la cache `_exAlpha`). Menu: seccion `explorer` (Section propia,
como `presets`) abierta por un **boton "Explorer" al lado de "Profile"** (`explorerBtn`); toggle maestro
"Enable Explorer" + lista de elementos + "Always show in combat" + "Always show on target"
(`db.explorerTarget`, default false; el ticker refresca `explorerDriver.showTgt` via UnitExists) +
slider "Hidden opacity". "Always show while casting" (`db.explorerCasting`, default true): el ticker
setea `explorerDriver.casting` con `ReadCastMode("player")` (secret-safe) → revela al castear/canalizar
sin necesidad de target. **QUIRK Model:** los frames `Model/PlayerModel` NO heredan el alpha del padre
→ el fade del Explorer (y el alpha-0 de PortraitSetShown) aplican `model:SetAlpha(alpha * modelAlpha)`
a mano; `ns.ExplorerReset` restaura `modelAlpha`.

## Robustez anti-taint (fixes 2026-07-13)
- **OnDragStop de unidades:** si el combate empieza A MITAD de un drag (solo puede empezar fuera),
  `StopMovingOrSizing` sobre el frame seguro se bloquea → el handler marca `u._stopMovePending` y
  PLAYER_REGEN_ENABLED re-invoca el propio OnDragStop (stop+snap+guardado completos).
- **Mouselook:** `MouselookStart` desde codigo inseguro con RMB pulsado CANCELA el click pendiente
  del frame bajo el cursor; si ese frame tiene click envuelto por SecureHandler (WrapScript ajeno) se
  invoca su closure restringida desde nuestra pila insegura → "Cannot call restricted closure"
  (RestrictedExecution:470). Fix: en GLOBAL_MOUSE_DOWN se evalua `ForeignProtectedUnderMouse()`
  (GetMouseFoci): frame protegido AJENO → ese click le pertenece, no se rota camara; NUESTROS unit
  buttons llevan `_mcfOwnButton=true` (sin WrapScript) y siguen permitiendo mouselook. pcall de
  cinturon en MouselookStart/Stop. El LUA_WARNING "ToDebugString '=' expected near 'end'"
  (RestrictedExecution.lua:126) es el chunk INTERNO de debug de Blizzard compilado al reportar esa
  misma violacion — no existe en ningun archivo del addon (verificado); desaparece al eliminar el trigger.
- **Party portraits (gating de contenido):** `PartyContentAllowed()` → `tickState.partyOK` (por tick):
  visibles solo en mundo abierto/grupo normal/dungeon ("party"); ocultos en raid/arena/BG/pvp/escenario
  y en grupo de RAID en mundo abierto (`IsInRaid`). Chequeo en `PortraitShouldShow` (prefijo
  `portrait_party`). Las party UNIT frames ya tenian su propio gating via state driver `[group:raid]`+arena. NOTA: `MakeSlider`/`MakeToggle` ahora aceptan get/set globales (getTbl/onChange)
para valores no-perfil (grid size, explorer). El tamaño de grilla tiene slider "Grid size" en Global options.
LOCAL LIMIT: core en ~186/200 — features grandes futuras (Interrupt, multi-select) requieren extraer subsistema.

## Performance (Fase 1 aplicada)
Reglas activas en las RUTAS CALIENTES (ticker 0.1s y OnUpdate por frame) — mantenerlas al editar:
- **pcall SIN closures:** `pcall(fn, args...)` / `pcall(obj.Metodo, obj, args...)`, nunca
  `pcall(function() ... end)` (aloca una closure por llamada → basura GC). Al sacar el codigo de la
  closure, TODO issecretvalue va ANTES de cualquier test booleano/comparacion/indexado del valor
  (dentro de la closure el crash quedaba atrapado; fuera NO). Comparar secretos SOLO con nil.
  Reescritos: UnitUpdateText/UnitUpdateName/GetUnitFraction/UnitColor/TargetReactionLE4/
  PortraitClassCoords/ReadCastMode (¡por FRAME!)/CastOnUpdate/CollectAuras/StyleAuraButton(icon)/
  PortraitCenterActive.
- **`tickState`** (local ~504): snapshot POR TICK de booleanos seguros (`inCombat`, `resting`, `n` =
  contador). Lo rellena el ticker al inicio; consumidores: UnitTextVisibility/UnitUpdateName/
  PowerShouldShow/PortraitUpdateState/PortraitUpdateFaction/AuraCondActive/PortraitCenterActive/
  explorerDriver. Fuera del ticker puede ir 0.1s por detras (aceptado). JAMAS cachear secretos.
- **Dedupe de "ultimo aplicado":** PortraitUpdatePosition y AuraGroupPlace guardan firma
  (`_posParent/_posP/_posRP/_posX/_posY` [+strata/scale en auras]) y saltan el re-anclado si nada
  cambio; los OnDragStop invalidan con `_posParent = nil` (StartMoving cambia el ancla real).
  Color del hpText (`u._hpR/G/B`, sincronizado tambien en UnitApplyAppearance), anchor/ancho del
  nombre (`u._nX/_nY/_nW`) y del hechizo (`u._sX/_sY`); el preview de UnitUpdateBar los invalida (nil).
- **CollectAuras:** tabla scratch reutilizada (`collectScratch` + wipe; se consume sincronamente en
  UpdateAuraGroup) + pcall directo (antes: tabla nueva + hasta 80 closures por UNIT_AURA).
- **MM_ReassertArt** corre cada 5 ticks (0.5s; los hooks ya reaccionan al instante).
- **Tracker:** clasificacion de color cacheada por fontstring (`_mcfTxt/_mcfEpoch/_mcfR/G/B`;
  `colorEpoch` se incrementa en RefreshTracker para invalidar al cambiar config) — si el texto no
  cambio solo se compara GetTextColor (numeros) y se re-aplica si Blizzard lo piso; texturas cachean
  la clasificacion header por path/atlas. Elimina el lower()+find() continuo del ticker 0.4s.
**Fase 2 APLICADA (2026-07-15):** `PortraitUpdateState(u, preview, skipBadges)` — parametro nuevo
`skipBadges` (opcional, default nil = actualiza badges, preserva el OTRO call site de aplicar-
config que sigue siendo instantaneo) salta faccion/raid-target/rol-lider cuando es true; el
ticker principal los actualiza cada 3 ticks (`slowTier = tickState.n % 3 == 0`, 0.3s) en vez de
cada tick — rest/death/combat quedan SIN tocar (cada tick, necesitan verse fluidos). Icono de
clase (`PortraitUpdatePicture` para `kind=="icon"`): antes se recalculaba cada tick para TODOS los
portraits de icono; ahora solo `portrait_tot` (cambia de unidad seguido, sigue al target) sigue a
cada tick — los de `party1-5` (la clase del ocupante de un slot casi nunca cambia en la sesion)
entran en el mismo `slowTier` de 0.3s. Solo 2 call sites de `PortraitUpdateState` en todo el
archivo (el ticker y `PortraitApplyAppearance` linea ~2188); el segundo no pasa el 3er argumento
asi que se comporta igual que antes (backward-compatible).
**Fase 3 (extraer Auras.lua/Portraits.lua) DESCARTADA por ahora (2026-07-15):** margen real de
locals verificado en 14 (186/200) — no esta en riesgo inminente. Es un refactor grande (cientos de
lineas entrelazadas con `frames`/`portraits`/`db`/`unlocked`/`tickState` de core) sin forma de
compilar-verificar; el usuario prefirio no arriesgar mientras no haga falta. Retomar cuando una
feature nueva empuje el limite de verdad (patron ya usado con ChatBubble/MicroMenu/Grouping), en
una sesion dedicada solo a eso — NO mezclar con otros cambios.
**Para añadir una opcion de UNIDAD:** 1) campo en `DefaultsFor` (core), 2) usarlo en la logica,
3) `MakeSlider/MakeCheckbox/MakeCycle/MakeColorButton/MakeEditBox` en la seccion (bind a
`CurrentProfile()`). **Para un ELEMENTO nuevo tipo micromenu/chatbubble/tracker:** KEY temprano
en core (que `CurrentProfile` lo vea como upvalue) + rama en CurrentProfile/ApplyCurrent +
default en InitDB/FillDefaults + `IsX`/label + grupo sidebar + `IsXSection` + rama en SelectUnit
+ tab + seccion de contenido en Options.

## Perfiles desde archivos (`Profiles_Pre/Post.lua`, `Profiles\`, `ProfilesApply.lua`) — 2026-07-14
Sistema DISTINTO de los presets internos del addon (`db.presets`): reemplaza el SavedVariables de
OTROS addons por copias guardadas en `Profiles\<Addon>\<Addon>.lua`.
- **Carga segura sin corromper el SV real:** `Profiles_Pre.lua` guarda los globales VIVOS del
  usuario en `ns._profLive` (Bartender4DB, DynamicCamDB+minZoomValues, MasqueDB,
  CHATTYNATOR_CONFIG+_MESSAGE_LOG, OPie_SavedData [luego eliminado], AzeriteUI5_DB) → las 6 copias
  en `Profiles\` clobbean esos globales al cargar → `Profiles_Post.lua` CAPTURA la copia en
  `ns.Profiles[global]` y RESTAURA el valor vivo original (así el SV real del usuario no se toca
  hasta que decida aplicar). `Profiles\_Exports.lua` (generado desde "Export Blizzard.txt"/"Export
  My addon.txt") llena `ns.ProfExports.blizzard`/`.myaddon`.
- **Aplicar (DESTRUCTIVO):** `ns.ApplyProfiles` (`ProfilesApply.lua`) — StaticPopup de confirmación
  → `_G[global] = DeepCopy(copia)` para cada addon detectado (`C_AddOns.IsAddOnLoaded`) +
  `ApplyBlizzardHUD` (layout Edit Mode via `C_EditMode.ConvertStringToLayoutInfo` +
  `EditModeManagerFrame:ImportLayout`, best-effort). **NO auto-recarga** (ver bug de taint abajo) —
  imprime "Type /reload" + popup de confirmación, recarga MANUAL.
- **BUG DE TAINT RAÍZ (tanda 8, causa del ~30% de los bugs de esta semana):**
  `StaticPopupDialogs = StaticPopupDialogs or {}` (REASIGNAR el global compartido) en
  `ProfilesApply.lua` tainteaba TODO el UI de Blizzard desde el arranque (leído por
  `PlayerSpellsMicroButton`, etc.) → causaba `ADDON_ACTION_FORBIDDEN` en ESC y "compare a secret
  number" al abrir personaje, sin relación aparente con Perfiles. **FIX: cambiado a solo INDEXAR
  `StaticPopupDialogs["KEY"] = {...}`** (StaticPopupDialogs SIEMPRE existe, indexar es seguro).
  Ver [[project-mycustomframes-pending-bug]] tanda 8 para el diagnóstico completo (usó `taint.log`).
- **Masque skin `Masque_Azerite_Hex`:** es un ADDON completo dentro de `Profiles\`; el sistema de
  Perfiles solo SELECCIONA la skin activa en `MasqueDB`, no la instala — para que Masque la use hay
  que copiarla a `AddOns\` manualmente (pendiente, avisado al usuario).
- **OPie fue ELIMINADO** de todo el sistema (owner+info en ProfilesApply, `ns.ProfGlobals`, toc,
  texto del menú Setup) — el usuario ya no lo usa.
- Menu: sección **"Setup"** (ver más abajo) tiene el botón "Apply Profiles" + status de addons
  detectados (`ns.ProfilesStatus`). El botón viejo vivía en Editing, se quitó de ahí.

## Integration_AzeriteUI.lua — bridge de skin/colores hacia AzeriteUI (2026-07-14/15)
El usuario corre **AzeriteUI5_JuNNeZ_Edition** como base. Antes tenía un archivo editado DENTRO de
AzeriteUI (`GonkastTweaks.lua`, se pierde al actualizar AzeriteUI); ahora todo vive en MCF y aplica
DESDE AFUERA sobre AzeriteUI limpio. `## OptionalDeps: AzeriteUI5_JuNNeZ_Edition` en el toc.
- **Namespace accesible:** `_G["AzeriteUI"] = ns` (Core/Core.lua:61 de AzeriteUI) → viable acceder
  desde otro addon: `_G.AzeriteUI:GetModule(name)`, `_G.AzeriteUI.GetConfig(name)` (tablas de layout
  MUTABLES), `_G.AzeriteUI:GetModule("Options"):AddGroup(...)` (registra página en `/az`),
  `_G.AzeriteUI.API.GetMedia(name,type)`.
- **Desactivar módulos (Tracker/Info/MicroMenu de AzeriteUI):** hecho en **file-load** (TOP-LEVEL
  del archivo, ANTES de PLAYER_LOGIN) via `SetEnabledState(false)` leyendo
  `MyCustomFramesDB.azerite` CRUDO (ns.GetDB() aún no existe) — AzeriteUI carga antes que MCF y hace
  su OnEnable en PLAYER_LOGIN, así que desactivar en file-load evita necesitar /reload en la
  primera carga. También neutraliza `Auras.DisableBlizzard` en file-load para mostrar el
  `BuffFrame` nativo si `db.azerite.showBlizzardBuffFrame`.
- **Colores por categoría:** `ApplyColors`/`ApplyNameplates` mutan `_G.AzeriteUI.GetConfig(name)`
  (PlayerFrame/TargetFrame/.../NamePlates) — NameColor/HealthValueColor/PowerValueColor/etc, con
  backup del original 1 vez. Nameplates: tamaño de fuente vía `CreateFont` propio (no se puede
  reusar `GetFont` con tamaños no pre-registrados), offset se relee en vivo si placement="below".
- **Skin de assets (reemplazo de texturas):** wrap de `API.GetMedia` es INÚTIL (cada archivo captura
  `local GetMedia` antes de que MCF cargue). Método PRIMARIO: `ApplyAssetConfigs()` en file-load
  recorre 25 tablas de `ALL_ASSET_CONFIGS` (`ns.GetConfig`) y reemplaza rutas de string que
  coincidan (case-insensitive) con `ASSET_REMAP` (19 nombres → `Assets\AzeriteUI Assets\<name>.tga`)
  — determinista, no depende de timing de hooks. Método SECUNDARIO (para assets en tablas LOCALES de
  componentes, no en config, ej. minimap-border): hook de `Texture:SetTexture` instalado en
  FILE-LOAD (antes del OnEnable de AzeriteUI), matcheando el ARGUMENTO string pasado (NO
  `GetTexture()`, que en 12.0 devuelve un fileDataID numérico). Diagnóstico: **`/mcfskin`**.
- **LÍMITE CRÍTICO DE TAINT (tanda 4, el usuario debe conocerlo):** mutar tablas de config de
  AzeriteUI DESDE OTRO ADDON contamina "by MyCustomFrames" ese config → cuando AzeriteUI lee vida/
  poder SECRETOS (Midnight) con ese config envenenado, falla la comparación secreta en OTROS lugares
  (TextStatusBar del PlayerFrame, SpellStopCasting/ESC). **NO hay forma taint-free de mutar tablas
  de OTRO addon en 12.0** (por eso GonkastTweaks DENTRO de AzeriteUI no tainteaba: mismo dueño). FIX:
  2 toggles `db.azerite.injectionEnabled` (maestro) y `.colorInjection` (solo colores/skin, no
  módulos) — si el usuario quiere 0% riesgo de taint, apagar `colorInjection` (pierde colores/skin,
  conserva desactivar-módulos + BuffFrame nativo). Página de opciones registrada en `/az` (menú Ace3
  de AzeriteUI), grupo "Gonkast Preset".
- **`Integrations.lua`** (archivo viejo, `ns.ApplyAddonProfiles` con AceDB `SetProfile` para
  Bartender4/DynamicCam) sigue existiendo pero SIN botón en el menú — superado por el sistema de
  Perfiles desde archivos (arriba). Considerar deprecarlo del todo si no se usa.

## Setup.lua — menú "Setup"
Grupo de sidebar nuevo (junto a Explorer/Editing/Profile) con: nota informativa sobre la
integración AzeriteUI (automática, sin botón — se aplica sola en file-load/login), botón
**"Apply Profiles"** (dispara `ns.ApplyProfiles`, ver sección Perfiles arriba), y status de addons
detectados (`ns.ProfilesStatus`). Reemplaza el botón viejo que vivía en Editing.

## Bug del panel, ronda 4 (2026-07-15) — el SetText no forzaba el re-render
Tras la ronda 3 (cobertura de `panelButtons`), el usuario reporto que "Paste" y el tab "ToT" del
sidebar (AMBOS ya cubiertos por panelButtons/unitTabs) SEGUIAN en blanco. Sospecha: llamar
`FontString:SetText(x)` cuando `x` es IGUAL al texto que el FontString YA tiene puede ser un
no-op interno de WoW (optimizacion que salta el recomputo) — si el glyph esta en blanco por un
fallo de rasterizado del atlas de fuente durante el pase de layout del canvas, reasertar el MISMO
string nunca dispara un nuevo intento de render. **FIX: `ReassertText(fs, label)` vacia primero
(`SetText("")`) y RECIEN DESPUES pone el label** — fuerza una diferencia real que WoW no puede
saltear. Reemplaza el `SetText` directo en las 3 tablas de `ReassertLabels`
(sectionTabs/unitTabs/panelButtons). PENDIENTE VALIDAR EN JUEGO — si esto tampoco alcanza, el
proximo paso seria intentar `fs:Hide(); fs:Show()` (ademas del SetText) o investigar si el bug es
en realidad del BOTON (frame) y no del FontString (probar `b:Hide(); b:Show()` del boton entero).

## Bug del panel, ronda 3 — CAUSA REAL ENCONTRADA (2026-07-15)
Tras 2 rondas de fix (guard event-driven + timers puntuales + ticker de 2s), el usuario mando
screenshot mostrando que el bug SEGUIA: labels en blanco en el sidebar (ej. "Target" entre Player
y Pet) y en la barra de botones de abajo ("Paste" en blanco). **CAUSA RAIZ REAL, recien
encontrada:** los botones **Profile/Explorer/Editing/Setup** (arriba) y
**Move-Lock/Preview/Outline/Copy/Paste** (abajo) estan parentados DIRECTO a `panel`
(`MakeButton(panel, ...)`), NO a `panel._content`. **NINGUNA de las mitigaciones anteriores los
tocaba:** `ReassertLabels` solo recorria `sectionTabs`/`unitTabs`; el nudge
`panel._content:Hide()/Show()` de `ApplyPanelView` solo afecta descendientes de `content` — estos
9 botones quedaban 100% FUERA de la red de seguridad, pese a que el ticker de 2s SI corria (el bug
no era de timing, era de COBERTURA).
**FIX: tabla nueva `panelButtons`** (declarada junto a `sectionTabs`/`unitTabs`), cada uno de los 9
botones se registra ahi al crearse (`panelButtons[#panelButtons+1] = btn`), y `ReassertLabels` los
recorre igual que los otros dos grupos. **CASO ESPECIAL `greenBtn` ("Outline: ON/OFF"):** su texto
es DINAMICO (cambia segun `db.hideEditGreen`) — `updGreen()` ahora tambien actualiza
`greenBtn._label` al texto ACTUAL cada vez que cambia, para que `ReassertLabels` no lo pise de
vuelta a "Outline: ON" fijo. Los otros 8 tienen label fijo (el `_label` que ya setea `MakeButton`
en la creacion alcanza). **Esta es probablemente la causa real de TODAS las apariciones previas
del bug** (rondas 1 y 2 solo tapaban una parte del problema).

## Buscador del sidebar reskineado con Plumber REAL (2026-07-15)
El usuario comparó nuestro panel con el de Plumber y señaló el buscador como ejemplo concreto de
acabado que quería igualar — SIN cambiar layout, solo apariencia/texturas/bordes. Investigación:
el buscador viejo usaba `InputBoxTemplate` NATIVO de Blizzard (caja azul genérica) — no tenía
nada que ver con el estilo de Plumber. Se leyó el codigo FUENTE real de Plumber
(`Modules/ControlCenter/SettingsPanelNew.lua`, `CreateSearchBox`/`SearchBoxMixin`) para sacar las
coordenadas exactas: usa un atlas cuadrado **1024×1024** `Art/ControlCenter/SettingsPanel.png`
(`Def.TextureFile`, DISTINTO de `SettingsPanelWidget.png` que ya usamos para botones/sliders —
Plumber tiene 2 atlas separados, uno por cada version vieja/nueva de su panel). `SetTexCoord` en
Plumber divide todo por 1024 (aunque las franjas y sean 0-80, no son proporcionales — el atlas es
cuadrado igual). Coords copiadas 1:1: pildora Left(0,32,0,80) / Center(32,160,0,80) /
Right(160,192,0,80), lupa (984,1024,0,40).
**HECHO:** copiado `Plumber/Art/ControlCenter/SettingsPanel.png` → `Assets\PlumberSettingsPanel.png`.
El `searchBox` del sidebar (Options.lua, junto a `RelayoutSidebar`) paso de `InputBoxTemplate` a un
EditBox custom con 3-slice (Left/Center/Right texturas) + lupa (`sbMag`, cambia de color opaco a
dorado brillante on focus, igual que el original) — MISMO tamaño/posicion/comportamiento que
antes (104×18, mismo `OnTextChanged`/`OnEscapePressed`/filtro), solo cambio visual.
**RONDA 2 (mismo dia, feedback del usuario "no tiene bordes, sigue en amarillo basico"):**
(1) Caps del buscador agrandados 9×18→13×26 con overlap (-3/3px hacia adentro) — a 18-20px de
alto la pildora completa del atlas se aplastaba casi invisible; ahora se recorta contra los bordes
de la caja en vez de estirarse plana. Tinte `SetVertexColor(1.15,1.05,0.85)` en los 3 (antes sin
tocar = 1,1,1) para que el marron/dorado del atlas (pensado para un fondo mas claro que el
nuestro) contraste mejor contra el sidebar casi negro. (2) **Amarillo residual sin migrar
encontrado y arreglado:** quedaban 9 lugares en `Options.lua` con el dorado SATURADO viejo
`(1, 0.82, 0.20)` sin migrar a la paleta Plumber (`COLOR_TITLE` 786553) pese a que el comentario
de cabecera decia que ya se habia reemplazado — titulo del panel, titulo "Editing: X", titulos de
popups (texture picker + IO popup), 2 headers de seccion (Zones/Explorer), 2 divisores, 1 tooltip,
y el color del scrollbar del sidebar (track/thumb). Todos migrados a `COLOR_TITLE[1..3]`
(conservando el alpha propio de cada uno). **LECCION: una migracion de paleta "hecha" en una
sesion vieja puede quedar PARCIAL — verificar con grep el color viejo exacto (`grep -n "1, 0.82"`)
en vez de confiar en que quedo completa.**
**PENDIENTE si el usuario pide mas:** el mismo atlas tiene el "square button" (fondo+icono+
highlight, coords 192-272/272-320/368-416) que Plumber usa para su boton de filtro — podria
reusarse para dar el mismo acabado a OTROS botones del panel si se pide extender el reskin.
PENDIENTE VALIDAR EN JUEGO si el borde ya se ve bien a este tamaño/tinte.

## Bug del panel de opciones (botones/labels en blanco al entrar) — ronda 2026-07-15
El canvas de Settings de Blizzard hace su propio pase de layout DESPUES de nuestro `OnShow`, y ese
pase a veces re-muestra secciones ocultas o deja botones con la FontString en blanco hasta salir y
volver a entrar (bug viejo, ya documentado en la memoria `project-mycustomframes`). Mitigado antes
con 5 `C_Timer.After` puntuales (0/0.05/0.15/0.3/0.6s) que reaplican `ApplyPanelView()`
(Hide/Show de secciones + `ReassertLabels()` que fuerza `SetText` en los FontStrings de
`sectionTabs`/`unitTabs`). **SEGUIA fallando** (confirmado por el usuario, screenshot con varios
labels en blanco en sidebar y en las pestañas de seccion) — el pase de layout del canvas no tiene
tiempo fijo, en este panel (muchas secciones/sliders) a veces tarda mas de 0.6s.
**FIX: reemplazados los 5 timers puntuales por un `C_Timer.NewTicker(0.1, ...)`** que reintenta
`ApplyPanelView()` cada 0.1s durante 2 segundos completos (20 intentos) mientras el panel este
visible — se cancela solo (vencida la ventana, o si el panel se oculta antes via el nuevo
`panel:SetScript("OnHide", ...)`). Cubre pases de layout lentos sin adivinar un numero magico de
timers. Barato (`ApplyPanelView` no crea frames, solo Hide/Show + SetText). Codigo en
`Options.lua` cerca de `panel:SetScript("OnShow", ...)` (busqueda: `retryTicker`).
**PENDIENTE VALIDAR EN JUEGO** que esto termine de resolver el bug (es la 2da ronda de mitigacion).

## Masque skin embebido (`MasqueSkin.lua`) — 2026-07-15
El skin de action bars **"Azerite HEX"** (antes addon separado `Masque_Azerite_Hex`, portado desde
`E:\...\AddOns\Masque_Azerite_Hex\main.lua`) ahora vive DENTRO de MyCustomFrames — ya NO hace falta
instalarlo como addon aparte. Assets copiados a `Assets\MasqueSkin\` (mismos .tga: actionbutton-
border/backdrop/glow-white/pushed, actionbutton_circular_mask). Carga temprano en el toc (tras
Grouping, antes del bridge de perfiles) porque no depende de nada del resto del addon.
- **Registro:** `RegisterSkin()` (`ns.RegisterMasqueSkin`) llama `LibStub("Masque", true):AddSkin(
  "Azerite HEX", {...}, true)` — SILENCIOSO si Masque no esta cargado (igual que el addon
  original). Se intenta en `PLAYER_LOGIN` (LibStub ya deberia tener a Masque para entonces).
  **Guard anti-duplicado:** si el addon STANDALONE viejo `Masque_Azerite_Hex` TAMBIEN esta cargado
  (el usuario no lo desinstalo), se deja que sea EL quien registre (mismo nombre = mismos datos,
  pero evita duplicar el hook `SetDrawBling`/anti-bling dos veces). Definicion del skin IDENTICA a
  la original (Shape Circle, Normal/Border/Highlight/Backdrop/Checked/Icon/Flash/Pushed/Gloss/
  Cooldown/etc, helper `scale()` para el factor 36pt de Masque).
- **FIX de crash (2026-07-15, mismo dia):** el primer intento llamaba `MSQ:GetGroups()` para
  iterar TODOS los grupos ya registrados y re-skinearlos en vivo — **esa funcion NO EXISTE en la
  API publica de Masque** (verificado leyendo `Masque\Core\Groups.lua`/`Skins.lua`: solo exponen
  `MSQ:Group(Addon,Group,StaticID)` y `MSQ:GetGroupByID(StaticID)`, ninguno sirve para enumerar
  sin conocer de antemano los nombres de grupo de cada addon de barras). Crasheaba con
  `attempt to call a nil value` en cuanto el usuario apretaba "Apply now" en el Setup Wizard con
  Masque tildado. **ADEMAS Masque `AddSkin` NO dispara ningun re-skin de grupos ya creados** — si
  el skin se registra DESPUES de que Bartender4 ya creo sus grupos, esos grupos quedan con el skin
  de fallback y no hay forma publica de forzar el refresh desde afuera.
- **FIX aplicado:** `RegisterSkin()` se llama INMEDIATO en **file-load** (al final de
  `MasqueSkin.lua`, sin esperar ningun evento) — igual que hacia el `main.lua` del addon original
  standalone (llamaba `AddSkin` directo en el cuerpo del archivo). Como Masque esta en
  `## OptionalDeps` del toc, el cliente lo carga ANTES que MyCustomFrames, asi que
  `LibStub("Masque")` ya esta disponible en ese punto. `ns.ApplyMasqueSkinAll()` (llamado desde el
  Setup Wizard) ya NO enumera/reskinea grupos — solo confirma que el registro esta hecho y devuelve
  un mensaje informativo (el usuario puede necesitar seleccionar el skin a mano en el panel de
  Masque si una barra no lo toma sola tras el /reload).
- **Integracion en el Setup Wizard (pagina 6, "Apply the Gonkast preset"):** si el usuario dejo
  tildado "Masque" en la pagina 2, tras `ApplyProfilesFiltered` (que reemplaza `MasqueDB` con la
  copia — el perfil exportado ya trae "Azerite HEX" seleccionado por nombre, y ese nombre ahora lo
  registra MyCustomFrames en vez del addon viejo) se confirma el registro del skin y se muestra el
  mensaje de resultado.
- **Recomendacion pendiente para el usuario:** desinstalar el addon standalone
  `Masque_Azerite_Hex` (`E:\...\AddOns\Masque_Azerite_Hex\`) ya que quedo redundante — el guard
  anti-duplicado lo tolera si se lo deja, pero no hace falta.

## Blizzard Edit Mode HUD layout — de auto-import a manual (2026-07-15)
El layout HUD de Blizzard ("Gonkast Preset": Bartender4/portraits/etc, formato propio de
`C_EditMode`) antes se auto-importaba con `EditModeManagerFrame:ImportLayout` (via `securecall`,
ver `ProfilesApply.lua`). **Esto SIEMPRE disparaba un `LUA_WARNING` ruidoso pero inofensivo**
(`CompactUnitFrame.lua:692: attempt to compare local 'oldR' (a secret number value... tainted by
'MyCustomFrames')`, stack: `MakeNewLayout → OnLayoutAdded → UpdateLayoutInfo → UpdateSystems`) —
Blizzard refresca sus "systems" internos (incluye unit frames) al CREAR cualquier layout nuevo,
sin importar si se selecciona como activo o no; `securecall` no evita el warning porque el
click que dispara todo se origina en un botón de MyCustomFrames (queda "tainted" igual). El
usuario pidió eliminarlo del todo — la única forma real es **no llamar `ImportLayout` desde
nuestro código**. **FIX: se eliminó por completo `ApplyBlizzardHUD`/`EnsureEditMode`** (ya no
existen en `ProfilesApply.lua`) y en su lugar:
- `ns.GetBlizzardHUDCode()` — devuelve el string exportado (`ns.ProfExports.blizzard`) o nil.
- `ns.ShowBlizzardHUDCode()` — popup autocontenido (no depende de `ns.UI`/Options.lua, que carga
  DESPUÉS en el toc) con un editbox multilínea de solo-copia + instrucciones ("Esc > Edit Mode >
  Import Layout > pegar > Import"). Slash command **`/mcfhud`** la abre en cualquier momento.
- `ns.ApplyProfilesFiltered(selected)` perdió el parámetro `includeHUD` y los retornos
  `hud`/`hudReason` (breaking change interno, ya actualizado en Setup.lua) — solo reemplaza
  SavedVariables de addons, nunca toca Edit Mode.
- Setup Wizard página 6: el toggle "Also add the Blizzard Edit Mode HUD layout" fue reemplazado
  por un botón separado "Get Blizzard HUD import code" que abre el popup — la importación real la
  hace el USUARIO, con código de Blizzard, sin taint.
- El menú principal (grupo "Setup", `ns.ApplyProfiles`/`DoApply`) también perdió el auto-import;
  ahora solo imprime un aviso por chat sugiriendo `/mcfhud` si hay HUD bundleado.

## Setup Wizard (`Setup.lua`) — asistente de primera instalación
**Descubierto/documentado 2026-07-15** (se había construido en una sesión no registrada en memoria).
Popup propio `MCFSetupWizard` (960×760, centrado, DIALOG strata, movible) con **7 páginas**, botones
de navegación (Skip/Back/Next/Finish) y puntos de página, con assets 100% propios del usuario en
`Assets\Setup Assets\` (`Background_Setup.tga`, `Exit_Button.tga`, `Apply_Button.tga`,
`skip_next_back_finish_Button.tga`, `Page.tga`/`Curret_Page.tga`) + assets de Plumber en `Assets\`
(`Setup_Divider.tga`/`Setup_ChecklistIcon.png`/`Setup_CheckmarkGreen.blp`/`Setup_Checkbox.png`).
Fuente **FRIZQT** (distinta de la Lato del panel de opciones principal). Carga AL FINAL del toc
(necesita `ns.UI`/`ns.PL`/`ns.GetDB`/el sistema de perfiles ya listos).
- **Cuándo se abre:** automático UNA sola vez, 1.5s después de `PLAYER_LOGIN`, si
  `db.setupSeen == false` (nil en instalación limpia). Al cerrarlo (X o "Skip setup") se marca
  `db.setupSeen = true` y no vuelve a aparecer solo. **Reabrible a mano en cualquier momento con el
  slash command `/mcfsetup`** (no depende de `setupSeen`).
- **Página 1 — "What this addon does":** resumen de features (unit frames/portraits/auras/tracker/
  info bar/micro menu/extras), texto fijo (`INTRO_LINES`).
- **Página 2 — "Bundled profiles for other addons":** lista dinámica (`RefreshPage2`, usa
  `ns.ProfilesStatus()`/`ns.ProfilesInfo`) de los addons detectados con perfil Gonkast incluido
  (Bartender4/DynamicCam/Masque/Chattynator/AzeriteUI) — checkbox por addon (tildado por defecto,
  el usuario puede destildar los que NO quiere reemplazar) + check verde de "detectado".
- **Página 3 — "Global options":** subset de 3 opciones globales con tooltip largo al hover
  (mouselook/hideBlizzard/dcFix), cada una con sufijo "(recommended)" (`REC`) y **forzada al valor
  recomendado la PRIMERA VEZ que se construye la página** (no en cada Show — las páginas se arman
  una sola vez con `contentPages[n] = BuildPageN(content)` y después solo se ocultan/muestran).
- **Página 4 — "Unit & quest tracker options":** 2 columnas — "Hide when mounted" por unidad
  (player/target/playerpower/targetpower, `hideWhenMounted`) + "Quest tracker auto-hide"
  (hideInBoss/hideInCombat/hideOnHostileTarget/hideInArena/hideInBG, `db.tracker`). Mismo patrón de
  forzado de recomendados al construir.
- **Página 5 — "Explorer Mode":** replica las opciones del Explorer del menú principal (master
  switch, 10 elementos en 2 columnas, 3 "Always show", 6 zonas) con recomendados pre-forzados
  (master OFF, 5 elementos ON, todos los "always show" ON, solo "Open world" ON).
- **Página 6 — "Apply the Gonkast preset":** botón "Apply now" (`ns.ApplyProfilesFiltered(selected)`,
  del sistema de Perfiles desde archivos) que reemplaza el SavedVariables de los addons tildados en
  la página 2. **CAMBIO 2026-07-15: el HUD de Blizzard Edit Mode YA NO se auto-importa** (ver
  `ProfilesApply.lua` sección "Blizzard Edit Mode HUD layout" más abajo) — botón separado "Get
  Blizzard HUD import code" abre un popup con el string copiable (`ns.ShowBlizzardHUDCode()`,
  también accesible con `/mcfhud` en cualquier momento) para que el usuario lo pegue a mano en
  Esc > Edit Mode > Import Layout. Resultado del "Apply now" mostrado en texto (aplicados/error),
  pide `/reload` manual (mismo patrón anti-taint: NUNCA auto-reload).
- **Página 7 — "Bartender4 profile":** Bartender4 es AceDB multi-perfil; a veces NO cae en
  "Default" tras el /reload de la página 6 pese al fallback estándar de AceDB → esta página fuerza
  `profileKeys[personaje] = perfil elegido` DIRECTO (selector de perfiles vía
  `GetBartenderProfiles()`, lee `ns.Profiles["Bartender4DB"].profiles`).
- **NOTA:** el comentario de cabecera del archivo dice "6 paginas" pero el código construye 7
  (`contentPages[1..7]`) — desactualizado, no corregido (no afecta funcionamiento).
- Para resetear y volver a ver el wizard automático (sin usar `/mcfsetup`): poner
  `MyCustomFramesDB.setupSeen = nil` (o `false`) y `/reload`.

## Assets locales (`Assets/`)
Copiados de AzeriteUI (texturas de barras/cages) y Plumber (menu). Rutas en core via
`local A = "Interface\\AddOns\\MyCustomFrames\\Assets\\"`. `PATH_REMAP` + `RemapPaths`
migran configs guardadas con rutas antiguas de AzeriteUI a las copias locales.
El usuario hace las WeakAuras; el addon solo dibuja las barras.
