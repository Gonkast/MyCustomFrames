-- ==========================================================================
-- MyCustomFrames - core.lua
-- Logica de las unidades: definiciones, DB, relleno, textos, cage, eventos,
-- modo edicion/preview, presets. La UI del menu va en Options.lua.
--
-- NOTA (Midnight 12.0.7): vida/poder/nombres pueden ser "secret values". No se
-- puede hacer aritmetica/comparacion/concatenacion en Lua con ellos. Usamos
-- funciones en C (StatusBar:SetValue, UnitHealthPercent, SetFormattedText,
-- AbbreviateNumbers) que SI aceptan valores secretos.
-- ==========================================================================

local ADDON, ns = ...

local function hexcol(h)
    return {
        r = tonumber(h:sub(1, 2), 16) / 255,
        g = tonumber(h:sub(3, 4), 16) / 255,
        b = tonumber(h:sub(5, 6), 16) / 255,
    }
end
ns.hexcol = hexcol

-- ---- Assets (copias locales en MyCustomFrames\Assets\) ----
local A = "Interface\\AddOns\\MyCustomFrames\\Assets\\"
local TEXTURE_DEFAULT = A .. "hp_lowmid_bar_miror_s.tga"
local POWER_TEXTURE   = A .. "power_cap_s.tga"
local BOSS_TEXTURE    = A .. "hp_lowmid_bar_miror_b.tga"
local BLANK_TEXTURE   = "Interface\\Buttons\\WHITE8X8"

local CAGE_TARGET  = A .. "hp_low_case.tga"
local CAGE_PLAYER  = A .. "hp_low_case_mirror.tga"
local CAGE_POWER   = A .. "power_low_case_s.tga"
local CAGE_PETTOT  = A .. "hp_low_case_miror_s.tga"
local CAGE_BOSS    = A .. "hp_low_case_mirror_b.tga"
local HIGHLIGHT_TEX = A .. "hp_low_case_miror_s_highlight.tga"   -- highlight de unidad seleccionada
-- Expuestas para Units.lua (subsistema extraido de core, patron Glow/ChatBubble/MicroMenu).
ns.TEXTURE_DEFAULT = TEXTURE_DEFAULT
ns.POWER_TEXTURE = POWER_TEXTURE
ns.BLANK_TEXTURE = BLANK_TEXTURE
ns.HIGHLIGHT_TEX = HIGHLIGHT_TEX

-- ---- Assets de los PORTRAITS ----
local PORTRAIT_BG     = A .. "Circle_Smooth_Border.tga"      -- fondo circular (coloreable)
local PORTRAIT_ORB    = A .. "orb_case_low.tga"              -- borde/cage del orbe (player)
local PORTRAIT_PETCASE= A .. "portrait_frame_lo.tga"         -- borde/cage (pet, etc.)
local BADGE_ALLIANCE  = A .. "icon_badges_alliance.tga"
local BADGE_HORDE     = A .. "icon_badges_horde.tga"
-- Variantes con War Mode ACTIVO (icono distinto). El de alianza debe existir en Assets con
-- este nombre (icon_badges_alliance_war_on.tga); el de horda es icon_badges_horde_war_on.tga.
local BADGE_ALLIANCE_WAR = A .. "icon_badges_alliance_war_on.tga"
local BADGE_HORDE_WAR    = A .. "icon_badges_horde_war_on.tga"
local BADGE_COMBAT    = A .. "icon-combat.tga"
local RAIDTARGET_TEX  = A .. "raid_target_icons.tga"        -- marcadores de banda (grid 4x4)
local ROLE_TANK       = A .. "icon_badges_tank.tga"        -- iconos de rol/lider custom (party)
local ROLE_HEAL       = A .. "icon_badges_heal.tga"
local ROLE_DPS        = A .. "icon_badges_dps.tga"
local LEADER_TEX      = A .. "icon_badges_lider.tga"
local ATLAS_REST      = "UI-HUD-UnitFrame-Player-Rest-Flipbook"  -- flipbook 7x6 = 42 frames
local DEATH_TEX       = A .. "icon_skull_dead.tga"                -- marca de muerte (custom)
local CLASS_ICON_TEX  = "Interface\\TargetingFrame\\UI-Classes-Circles"  -- iconos de clase
-- Expuestas para Portraits.lua (subsistema extraido de core, patron Units/Glow/ChatBubble/MicroMenu).
ns.PORTRAIT_BG = PORTRAIT_BG
ns.PORTRAIT_ORB = PORTRAIT_ORB
ns.BADGE_ALLIANCE = BADGE_ALLIANCE
ns.BADGE_HORDE = BADGE_HORDE
ns.BADGE_ALLIANCE_WAR = BADGE_ALLIANCE_WAR
ns.BADGE_HORDE_WAR = BADGE_HORDE_WAR
ns.BADGE_COMBAT = BADGE_COMBAT
ns.RAIDTARGET_TEX = RAIDTARGET_TEX
ns.ROLE_TANK = ROLE_TANK
ns.ROLE_HEAL = ROLE_HEAL
ns.ROLE_DPS = ROLE_DPS
ns.LEADER_TEX = LEADER_TEX
ns.ATLAS_REST = ATLAS_REST
ns.DEATH_TEX = DEATH_TEX
ns.CLASS_ICON_TEX = CLASS_ICON_TEX
local AURA_BORDER     = A .. "actionbutton-border square.tga"           -- borde de auras
local AURA_PREVIEW_ICON = "Interface\\Icons\\Spell_Nature_Rejuvenation"  -- icono de muestra
-- Expuestas para Auras.lua (subsistema extraido de core, patron Units/Portraits/Glow/ChatBubble/MicroMenu).
ns.AURA_BORDER = AURA_BORDER
ns.AURA_PREVIEW_ICON = AURA_PREVIEW_ICON

-- ---- Libreria de texturas para el SELECTOR (WoW no puede listar archivos del disco,
-- ---- asi que se declaran aca). SKINS = subcarpetas de Assets\ con los MISMOS nombres
-- ---- de archivo; para agregar una skin: crea la carpeta, copia las texturas y agregala.
ns.ASSETS = A
ns.TEX_SKINS = {
    { folder = "",          label = "Default" },
    
    -- { folder = "Neon\\",  label = "Neon" },   -- ejemplo: Assets\Neon\<mismos archivos>
}
ns.TEX_LIB = {
    bar          = { "hp_lowmid_bar_miror_s.tga", "hp_lowmid_bar_miror_b.tga", "power_cap_s.tga", "hp_cap_bar.tga", "hp_cap_bar mirror.tga", "hp_pet_bar.tga", "hp_party_bar.tga", },
    cage         = { "hp_low_case.tga", "hp_low_case_mirror.tga", "hp_low_case_miror_s.tga", "hp_pet_cage.tga",
                     "hp_low_case_mirror_b.tga", "power_low_case_s.tga", "hp_party_cage.tga", },
    portraitbg   = { "Circle_Smooth_Border.tga" },
    portraitcage = { "orb_case_low.tga", "portrait_frame_lo.tga" },
    auraborder   = { "actionbutton-border square.tga", "actionbutton-border square2.tga",
                     "actionbutton-border.tga" },
    glow         = { "actionbuttonhighlight.tga", "actionbutton-border square.tga",
                     "cursor-highlight.tga" },
    raidtarget   = { "raid_target_icons.tga", "raid_target_icons_small.tga" },
    infobg       = { "info_bg.tga" },
    highlight    = { "hp_low_case_miror_s_highlight.tga", "actionbuttonhighlight.tga", "hp_pet_highlight.tga", "hp_party_highlight.tga", "hp_boss_highlight.tga", },
    minimapborder   = { "minimap-border.tga" },
    minimapbackdrop = { "minimap-mask-opaque.tga" },
    eye             = { "group-finder-eye-orange.tga" },
    ringbackdrop    = { "minimap-onebar-backdrop.tga" },
    ringbutton      = { "point_plate.tga" },
    dismount        = { "icon_exit_flight.tga" },
}

-- Rutas antiguas (AzeriteUI) -> copias locales, para migrar configs guardadas.
local PATH_REMAP = {
    ["Interface\\AddOns\\AzeriteUI\\Assets\\New Asset\\hp_lowmid_bar_miror_s.tga"] = TEXTURE_DEFAULT,
    ["Interface\\AddOns\\AzeriteUI\\Assets\\New Asset\\power_cap_s.tga"]           = POWER_TEXTURE,
    ["Interface\\AddOns\\AzeriteUI\\Assets\\New Asset\\hp_lowmid_bar_miror_b.tga"] = BOSS_TEXTURE,
    ["Interface\\AddOns\\AzeriteUI\\Assets\\hp_low_case.tga"]                      = CAGE_TARGET,
    ["Interface\\AddOns\\AzeriteUI\\Assets\\hp_low_case_mirror.tga"]               = CAGE_PLAYER,
    ["Interface\\AddOns\\AzeriteUI\\Assets\\New Asset\\power_low_case_s.tga"]      = CAGE_POWER,
    ["Interface\\AddOns\\AzeriteUI\\Assets\\New Asset\\hp_low_case_miror_s.tga"]   = CAGE_PETTOT,
    ["Interface\\AddOns\\AzeriteUI\\Assets\\New Asset\\hp_low_case _mirror_b.tga"] = CAGE_BOSS,
}

-- Assets de Plumber para el look del menu (se cargan por ruta; funcionan aunque
-- el addon Plumber este desactivado, mientras la carpeta exista).
ns.PL = {
    BG    = A .. "SettingsPanelBackground.jpg",
    DIV_H = A .. "Divider_Gradient_Horizontal.tga",
    DIV_V = A .. "Divider_DropShadow_Vertical.tga",
    -- 2026-07-17: Fonts\FRIZQT__.TTF (fuente por defecto de Blizzard) en vez de
    -- Lato-Bold.ttf, para que el titulo y TODO el panel de opciones (Options.lua
    -- usa esto via setFont) hagan juego con el wizard de Setup.lua, que ya usaba
    -- FRIZQT por separado.
    FONT  = "Fonts\\FRIZQT__.TTF",
}

local GOLD = { r = 1, g = 0.882, b = 0.608 }   -- FFE19B (color de texto por defecto)
ns.GOLD = GOLD

local BOSS_COLOR = hexcol("761110")

local POWER_COLORS = {
    MANA        = hexcol("2e57fa"),
    RAGE        = hexcol("c72626"),
    ENERGY      = hexcol("ffcc00"),
    RUNIC_POWER = hexcol("4dcbf9"),
    FURY        = hexcol("a330c9"),
    FOCUS       = hexcol("ff8000"),
    HOLY_POWER  = hexcol("f58cba"),
    SOUL_SHARDS = hexcol("8052cc"),
    INSANITY    = hexcol("d14dff"),
    CHI         = hexcol("00ff96"),
    LUNAR_POWER = hexcol("ffcc00"),
    MAELSTROM   = hexcol("0070dd"),
    ESSENCE     = hexcol("ffbf00"),
}
ns.POWER_COLORS = POWER_COLORS

local UNITS = {
    { key = "player",       unit = "player",       label = "Player" },
    { key = "target",       unit = "target",       label = "Target" },
    { key = "targettarget", unit = "targettarget", label = "ToT" },
    { key = "pet",  unit = "pet", label = "Pet", driver = "[@pet,exists,combat] show; [@pet,exists,@target,exists] show; hide" },
    { key = "focus", unit = "focus", label = "Focus" },
    { key = "playerpower", unit = "player", label = "P.Pwr", kind = "power" },
    { key = "targetpower", unit = "target", label = "T.Pwr", kind = "power" },
    { key = "boss1", unit = "boss1", label = "Boss1", fixedColor = BOSS_COLOR },
    { key = "boss2", unit = "boss2", label = "Boss2", fixedColor = BOSS_COLOR },
    { key = "boss3", unit = "boss3", label = "Boss3", fixedColor = BOSS_COLOR },
    { key = "boss4", unit = "boss4", label = "Boss4", fixedColor = BOSS_COLOR },
    { key = "boss5", unit = "boss5", label = "Boss5", fixedColor = BOSS_COLOR },
    { key = "party1", unit = "party1", label = "P1" },
    { key = "party2", unit = "party2", label = "P2" },
    { key = "party3", unit = "party3", label = "P3" },
    { key = "party4", unit = "party4", label = "P4" },
    -- "party5" NO es un unit token real de WoW (una party normal son 4 OTROS miembros +
    -- vos = 5 en total; UnitExists("party5") siempre da false) — pedido del usuario
    -- (2026-07-16): en vez de un 5to slot muerto, este frame ahora muestra al PROPIO
    -- jugador (unit="player"), como una tile mas dentro de la grilla de party.
    { key = "party5", unit = "player", label = "P5" },
    -- ARENA (pedido del usuario 2026-07-19): "unitframe de arenas, identicas al ToT,
    -- necesito 6" -- 3 copias INDEPENDIENTES de player/party1/party2 (aliados propios,
    -- el equipo de arena SIEMPRE es vos + hasta 2 companeros de party) + 3 nuevas
    -- (arena1/2/3, tokens NATIVOS de Blizzard para los oponentes de arena) -- NO
    -- reusan ni alteran los frames "player"/"party1"/"party2" ya existentes, son
    -- entradas de ns.frames totalmente aparte (mismo unit token, Lua object distinto).
    -- Visibilidad: ver ArenaDriverString/UpdateArenaDrivers mas abajo -- solo en arena.
    { key = "arena_player", unit = "player", label = "Arena Player" },
    { key = "arena_party1", unit = "party1", label = "Arena Ally 1" },
    { key = "arena_party2", unit = "party2", label = "Arena Ally 2" },
    { key = "arena_enemy1", unit = "arena1", label = "Arena Enemy 1" },
    { key = "arena_enemy2", unit = "arena2", label = "Arena Enemy 2" },
    { key = "arena_enemy3", unit = "arena3", label = "Arena Enemy 3" },
}
ns.UNITS = UNITS
-- Grupo de unidades de arena (mismo patron que PARTY_KEYS/BOSS_KEYS) -- expuesto para
-- que Units.lua arme el visibility driver especifico de arena (ver ArenaDriverString).
local ARENA_KEYS = { "arena_player", "arena_party1", "arena_party2", "arena_enemy1", "arena_enemy2", "arena_enemy3" }
ns.ARENA_KEYS = ARENA_KEYS

local function HasNameByKey(key)
    return key ~= "playerpower" and key ~= "targetpower"
end
ns.HasNameByKey = HasNameByKey

local function CageDefault(key)
    if key == "target" then return CAGE_TARGET end
    if key == "player" then return CAGE_PLAYER end
    if key == "playerpower" or key == "targetpower" then return CAGE_POWER end
    if key == "pet" or key == "targettarget" or key == "focus" then return CAGE_PETTOT end
    if key:sub(1, 4) == "boss" then return CAGE_BOSS end
    if key:sub(1, 5) == "party" then return CAGE_PETTOT end
    -- Arena (pedido del usuario: "visualmente identicas al ToT") -- mismo cage que ToT/pet/focus.
    if key:sub(1, 6) == "arena_" then return CAGE_PETTOT end
    return ""
end

local function DefaultsFor(key)
    local defY = {
        player = -150, target = -180, targettarget = -210, pet = -240, focus = -270,
        playerpower = -330, targetpower = -360,
        boss1 = -150, boss2 = -180, boss3 = -210, boss4 = -240, boss5 = -270,
        party1 = -150, party2 = -180, party3 = -210, party4 = -240, party5 = -270,
        -- Arena (pedido del usuario 2026-07-19): posicion inicial escalonada para que
        -- las 6 no nazcan apiladas -- el estilo/tamaño/textura sale IGUAL que el resto
        -- de esta funcion (no hay ninguna rama especial de key:sub(1,6)=="arena_" mas
        -- abajo), por eso salen "identicas al ToT" salvo la posicion.
        arena_player = -150, arena_party1 = -180, arena_party2 = -210,
        arena_enemy1 = -150, arena_enemy2 = -180, arena_enemy3 = -210,
    }
    -- Aliados a la izquierda, enemigos a la derecha (solo el offset inicial -- el
    -- usuario los puede mover libremente despues, Editing/Nameplate Designer aparte).
    local defX = {
        arena_player = -280, arena_party1 = -280, arena_party2 = -280,
        arena_enemy1 = 280, arena_enemy2 = 280, arena_enemy3 = 280,
    }
    local power = (key == "playerpower" or key == "targetpower")
    local boss  = (key:sub(1, 4) == "boss")
    local tex
    if power then tex = POWER_TEXTURE
    elseif boss then tex = BOSS_TEXTURE
    else tex = TEXTURE_DEFAULT end
    local wantValue = not power
    return {
        anchorFrame = "", point = "CENTER", relativePoint = "CENTER",
        offsetX = defX[key] or 0, offsetY = defY[key] or -150, strata = "MEDIUM",
        width = 250, height = 20, scale = 1.0,
        -- Area de CLICK del boton seguro (hit rect), independiente de la barra.
        -- 0 = sigue el tamaño de la barra (comportamiento clasico).
        btnWidth = 0, btnHeight = 0, btnOffsetX = 0, btnOffsetY = 0,
        -- Outline de edicion (B4): tamaño propio (0 = seguir al frame) + ocultar nombre.
        outlineW = 0, outlineH = 0, outlineHideName = false,
        reverseFill = false, smooth = false, texture = tex, showBackground = true,
        barAlpha = 1.0, bgAlpha = 0.5,
        -- Cage
        cageTexture = CageDefault(key),
        cageWidth = 250, cageHeight = 20, cageOffsetX = 0, cageOffsetY = 0, cageAlpha = 1.0,
        cageHideDead = (key == "target" or key == "player"),   -- oculta el cage si la unidad esta muerta
        -- Highlight de "unidad seleccionada" (si la unidad es tu target actual)
        showHighlight = false, highlightTexture = HIGHLIGHT_TEX,
        highlightWidth = 250, highlightHeight = 20, highlightScale = 1.0,
        highlightOffsetX = 0, highlightOffsetY = 0,
        highlightColor = { r = 1, g = 1, b = 1 }, highlightAlpha = 1.0,
        highlightGlow = true,   -- latido de opacidad
        -- Texto vida
        showText = true, showValue = wantValue, textAlpha = 1.0,
        textOffsetX = 0, textOffsetY = 0, textAutoHide = not power, fontSize = 14,
        -- Auto-hide: ademas de combate/hostil/mouseover, revelar si la vida baja del umbral.
        textLowHealthShow = false, textLowHealthThreshold = 60,
        useHealthColor = false, healthColor = { r = GOLD.r, g = GOLD.g, b = GOLD.b },
        -- Texto nombre
        showName = true, nameAutoHide = false, nameFontSize = 12, nameAlpha = 1.0,
        nameScale = 1.0, nameOffsetX = 0, nameOffsetY = 0,
        nameLevelColor = true, nameMaxLength = 10, nameDynamicWidth = true,
        useNameColor = false, nameColor = { r = GOLD.r, g = GOLD.g, b = GOLD.b },
        -- Texto hechizo
        showSpell = true, spellFontSize = 12, spellAlpha = 1.0, spellScale = 1.0,
        spellOffsetX = 0, spellOffsetY = 0,
        spellMaxLength = 24,     -- limite de caracteres (0 = sin limite); corta con ".."
        spellWrapWidth = 130,    -- ancho de envoltura: mas estrecho => se apila en 2 lineas
        useSpellColor = false, spellColor = { r = GOLD.r, g = GOLD.g, b = GOLD.b },
        -- Cast bar (textura configurable; por defecto la del hp bar; centrado)
        castAlpha = 1.0, castReverse = false, castSmooth = true,
        castColor = { r = 1.0, g = 0.72, b = 0.10 },
        castWidth = 250, castHeight = 20,
        castSparkWidth = 14, castSparkHeight = 28, castSparkScale = 1.0,   -- spark independiente
        castTexture = tex,
        -- Otros
        hideWhenMounted = false, showTooltip = true,
        -- Colores barra
        useBarColor = (key == "targetpower"),
        barColor = { r = 0.60, g = 0.20, b = 0.80 },
        colorHostile = { r = 0.85, g = 0.20, b = 0.20 },
        colorNeutral = { r = 0.90, g = 0.80, b = 0.20 },
        colorFriendly = { r = 0.20, g = 0.80, b = 0.20 },
        -- Icono de trinket de PvP (pedido del usuario 2026-07-19) -- SOLO para
        -- Arena Enemy 1/2/3 (ver ArenaTrinket.lua). Default ON solo para esas 3
        -- claves; el resto de las unidades simplemente no usan estos campos.
        showTrinket = (key:sub(1, 11) == "arena_enemy"),
        trinketSize = 24, trinketOffsetX = 0, trinketOffsetY = -30,
    }
end
ns.DefaultsFor = DefaultsFor

-- ==========================================================================
-- PORTRAITS (elementos aparte de las unidades: retrato 3D + iconos)
-- ==========================================================================
-- Cada portrait NO es una unidad: es un frame propio con modelo 3D, fondo
-- circular, borde/orbe, flipbook de descanso, marca de muerte y badges
-- (faccion + combate). El player portrait ademas tiene DOS posiciones:
-- "centro" (activa con target / combate / instancia) y "alterna" (el resto).
-- features = elementos "extra" del portrait: rest/faction/combat (badges de player) y
-- dualPos (2 posiciones centro/alterna). bg/pic/cage/death son universales.
-- requireExists = solo aparece si la unidad existe. deadOnly = solo si la unidad esta
-- muerta. kind = "model" (retrato 3D) o "icon" (icono de clase).
local PORTRAITS = {
    -- Pedido del usuario (2026-07-16): sin badge de LIDER en player/pet/target/tot (feature
    -- "leader" quitada) — el badge de MARCA DE RAID (raidTarget) se deja intacto. focus y las
    -- party (roleLeader, distinto flag) NO se tocan.
    { key = "portrait_player", unit = "player", label = "Player", kind = "model",
      features = { rest = true, faction = true, combat = true, dualPos = true, raidTarget = true } },
    { key = "portrait_pet", unit = "pet", label = "Pet", kind = "model",
      features = { dualPos = true, raidTarget = true }, requireExists = true },
    { key = "portrait_target", unit = "target", label = "Target", kind = "model",
      features = { raidTarget = true }, requireExists = true, deadOnly = true },
    { key = "portrait_tot", unit = "targettarget", label = "ToT", kind = "icon",
      features = { raidTarget = true }, requireExists = true },
    { key = "portrait_party1", unit = "party1", label = "Party1", kind = "icon",
      features = { raidTarget = true, roleLeader = true }, requireExists = true },
    { key = "portrait_party2", unit = "party2", label = "Party2", kind = "icon",
      features = { raidTarget = true, roleLeader = true }, requireExists = true },
    { key = "portrait_party3", unit = "party3", label = "Party3", kind = "icon",
      features = { raidTarget = true, roleLeader = true }, requireExists = true },
    { key = "portrait_party4", unit = "party4", label = "Party4", kind = "icon",
      features = { raidTarget = true, roleLeader = true }, requireExists = true },
    -- unit="player" (ver nota en UNITS de mas arriba: "party5" no es un token real).
    { key = "portrait_party5", unit = "player", label = "Party5", kind = "icon",
      features = { raidTarget = true, roleLeader = true }, requireExists = true },
    -- ARENA (pedido del usuario 2026-07-19): kind="icon" -- IGUAL que portrait_tot
    -- ("visualmente identico al ToT, tanto portrait como unitframe"). requireExists
    -- true en todos (arena_player/party1/party2 tambien, ya que solo deben aparecer
    -- en arena -- fuera de arena su unitframe esta oculto por UpdateArenaDrivers y
    -- requireExists hace que el portrait seed el mismo criterio via ns.frames[unit]).
    -- CORREGIDO (2026-07-19, "no te detengo ahi, todos los portrait de arena
    -- deben tener icon de clase, no 3d portrait"): portrait_arena_player
    -- vuelve a kind="icon" -- los 6 portraits de arena son icono de clase,
    -- ninguno usa modelo 3D. Clona valores de portrait_tot como el resto
    -- (ver CLONE_ARENA_PORTRAIT_FROM en FillDefaults).
    { key = "portrait_arena_player", unit = "player", label = "Arena Player", kind = "icon",
      features = { raidTarget = true }, requireExists = true },
    { key = "portrait_arena_party1", unit = "party1", label = "Arena Ally 1", kind = "icon",
      features = { raidTarget = true, roleLeader = true }, requireExists = true },
    { key = "portrait_arena_party2", unit = "party2", label = "Arena Ally 2", kind = "icon",
      features = { raidTarget = true, roleLeader = true }, requireExists = true },
    { key = "portrait_arena_enemy1", unit = "arena1", label = "Arena Enemy 1", kind = "icon",
      features = { raidTarget = true }, requireExists = true },
    { key = "portrait_arena_enemy2", unit = "arena2", label = "Arena Enemy 2", kind = "icon",
      features = { raidTarget = true }, requireExists = true },
    { key = "portrait_arena_enemy3", unit = "arena3", label = "Arena Enemy 3", kind = "icon",
      features = { raidTarget = true }, requireExists = true },
}
ns.PORTRAITS = PORTRAITS

local PORTRAIT_SET, PORTRAIT_DEF = {}, {}
for _, def in ipairs(PORTRAITS) do PORTRAIT_SET[def.key] = true; PORTRAIT_DEF[def.key] = def end
ns.IsPortrait = function(key) return PORTRAIT_SET[key] == true end
ns.PortraitFeatures = function(key) local d = PORTRAIT_DEF[key]; return (d and d.features) or {} end
ns.PortraitKind = function(key) local d = PORTRAIT_DEF[key]; return (d and d.kind) or "model" end

local function PortraitDefaultsFor(key)
    local d = {
        enabled = true,
        clickOpenChar = (key == "portrait_player"),   -- click abre el panel de personaje (solo player)
        charBtnScale = 1.0,   -- multiplicador del area de click del boton de personaje (solo player)
        mirrorTarget = false,   -- mostrar el modelo 3D del target en vez del player, si hay target (solo player)
        size = 90, scale = 1.0, strata = "MEDIUM",
        -- Posicion "centro" / principal
        centerAnchor = "", centerPoint = "CENTER", centerRelPoint = "CENTER",
        centerX = 0, centerY = 0,
        -- Posicion "alterna" (solo dualPos)
        altAnchor = "", altPoint = "CENTER", altRelPoint = "CENTER",
        altX = -320, altY = -120,
        -- Condiciones que fuerzan la posicion "centro" (solo dualPos)
        centerOnTarget = true, centerInCombat = true, centerInInstance = true,
        editPos = "center",   -- cual posicion se edita/arrastra en preview
        -- Fondo circular (coloreable)
        showBg = true, bgTexture = PORTRAIT_BG, bgScale = 1.0, bgAlpha = 0.9,
        bgColor = { r = 0, g = 0, b = 0 },
        -- Retrato (modelo 3D o icono de clase)
        showModel = true, modelZoom = 1.0, modelScale = 0.92, modelAlpha = 1.0,
        modelOffsetX = 0, modelOffsetY = 0,
        -- Borde / orbe (cage)
        showCage = true, cageTexture = PORTRAIT_ORB, cageScale = 1.14, cageAlpha = 1.0,
        cageOffsetX = 0, cageOffsetY = 0,
        -- Flipbook de descanso (resting) [solo player]
        showRest = true, restScale = 0.55, restAlpha = 1.0,
        restOffsetX = 0, restOffsetY = 0,
        -- Marca de muerte (coloreable + opacidad)
        showDeath = true, deathScale = 0.7, deathAlpha = 1.0,
        deathColor = { r = 1, g = 1, b = 1 }, deathOffsetX = 0, deathOffsetY = 0,
        -- Badge de faccion (alianza/horda) [solo player] (coloreable + opacidad)
        showFaction = true, factionScale = 0.5, factionAlpha = 1.0,
        factionColor = { r = 1, g = 1, b = 1 }, factionOffsetX = 0, factionOffsetY = -46,
        -- Badge de combate [solo player] (coloreable + opacidad)
        showCombat = true, combatScale = 0.55, combatAlpha = 1.0,
        combatColor = { r = 1, g = 1, b = 1 }, combatOffsetX = 0, combatOffsetY = 46,
        -- Marcador de banda (raid target icon) [solo party; feature raidTarget]. Badge
        -- ARRIBA del portrait. Solo aparece si la unidad esta marcada (GetRaidTargetIndex).
        showRaidTarget = true, raidTargetTexture = RAIDTARGET_TEX,
        raidTargetScale = 0.62, raidTargetAlpha = 1.0,
        raidTargetOffsetX = 0, raidTargetOffsetY = 32, raidTargetBounce = true,
        -- Iconos de rol (tank/heal/dps) y lider (corona) [solo party; feature roleLeader].
        showRole = true, roleScale = 0.42, roleAlpha = 1.0, roleOffsetX = 18, roleOffsetY = -18,
        showLeader = true, leaderScale = 0.42, leaderAlpha = 1.0, leaderOffsetX = -20, leaderOffsetY = 20,
    }
    if key == "portrait_pet" then
        d.size = 64; d.cageTexture = PORTRAIT_PETCASE
        d.centerX, d.centerY = 150, 0
        d.altX, d.altY = -380, -120
        d.showRest, d.showFaction, d.showCombat = false, false, false
    elseif key == "portrait_target" then
        d.size = 64; d.cageTexture = PORTRAIT_PETCASE
        d.centerX, d.centerY = 0, 160      -- una sola ubicacion; solo sale si target muerto
        d.showRest, d.showFaction, d.showCombat = false, false, false
    elseif key == "portrait_tot" then
        d.size = 52; d.cageTexture = PORTRAIT_PETCASE
        d.centerX, d.centerY = 130, -160
        d.showRest, d.showFaction, d.showCombat = false, false, false
    elseif key:sub(1, 13) == "portrait_part" then
        d.size = 54; d.cageTexture = PORTRAIT_PETCASE
        local n = tonumber(key:sub(-1)) or 1
        d.centerX, d.centerY = -430, 140 - (n - 1) * 62   -- apilados a la izquierda
        d.showRest, d.showFaction, d.showCombat = false, false, false
    end
    return d
end
ns.PortraitDefaultsFor = PortraitDefaultsFor

-- ==========================================================================
-- AURAS (buffs/debuffs de player y target; grid "centrado horizontal, hacia abajo")
-- ==========================================================================
-- Un grupo por unidad; cada grupo combina buffs + debuffs (HELPFUL + HARMFUL).
-- dualPos = 2 posiciones (principal/alterna) conmutadas por condiciones. Solo player.
local AURAS = {
    { key = "aura_player", unit = "player", label = "Player Auras", dualPos = true },
    { key = "aura_target", unit = "target", label = "Target Auras" },
}
ns.AURAS = AURAS

local AURA_SET, AURA_DEF = {}, {}
for _, def in ipairs(AURAS) do AURA_SET[def.key] = true; AURA_DEF[def.key] = def end
ns.IsAura = function(key) return AURA_SET[key] == true end
ns.AuraIsDual = function(key) local d = AURA_DEF[key]; return d and d.dualPos and true or false end

ns.AURA_SORTS_VALUES = { "index", "timeUp", "timeDown", "name" }

local function AuraDefaultsFor(key)
    local d = {
        enabled = true, strata = "MEDIUM", scale = 1.0,
        -- Ancla / posicion principal (el grid crece hacia abajo desde este punto).
        anchor = "", point = "CENTER", relPoint = "CENTER", offsetX = 0, offsetY = 0,
        -- Posicion alterna + condiciones (solo grupos dualPos = player).
        altAnchor = "", altPoint = "CENTER", altRelPoint = "CENTER", altX = 0, altY = -260,
        centerOnTarget = true, centerInCombat = true, centerInInstance = true, editPos = "center",
        -- Offset extra que se SUMA a la posicion viva cuando existe pet (solo player).
        -- Ahora INDEPENDIENTE por posicion: petOffsetX/Y para la PRINCIPAL (center),
        -- petOffsetXAlt/YAlt para la ALTERNA (alt).
        petOffsetX = 0, petOffsetY = 0,
        petOffsetXAlt = 0, petOffsetYAlt = 0,
        -- Al MORIR el player (solo dualPos): 2 posiciones — sin target (dead) y con target
        -- (deadTarget).
        useDeadPos = true,
        deadAnchor = "", deadPoint = "CENTER", deadRelPoint = "CENTER", deadX = 0, deadY = 200,
        deadTargetAnchor = "", deadTargetPoint = "CENTER", deadTargetRelPoint = "CENTER",
        deadTargetX = 0, deadTargetY = 140,
        -- Opacidad (solo dualPos = player): base; 100% al pasar el mouse por una aura
        -- o si hay combate / objetivo / instancia.
        groupAlpha = 0.5,
        -- Grid: "centrado horizontal, luego hacia abajo".
        iconSize = 30, perRow = 8, colSpace = 4, rowSpace = 10, limit = 32,
        sort = "timeUp",
        -- Texto de duracion (offset + color GLOBAL para todas las auras del grupo).
        showDuration = true, durationOffsetX = 0, durationOffsetY = 0, durationFontSize = 12,
        showSwipe = true,
        textColor = { r = 1, g = 0.82, b = 0.2 },   -- color del texto (duracion + contador)
        -- Contador de acumulaciones.
        showCount = true, countFontSize = 12,
        -- Tooltip al pasar el mouse.
        showTooltip = true,
        -- Cancelar buff con clic derecho (solo aplica a buffs propios del player).
        allowCancel = true,
        -- Borde: textura configurable (por defecto actionbutton-border square) + color/escala.
        showBorder = true, borderTexture = AURA_BORDER,
        borderColor = { r = 1, g = 1, b = 1 }, borderAlpha = 1.0, borderScale = 0.16,
    }
    if key == "aura_player"     then d.offsetX, d.offsetY = 0, 300
    elseif key == "aura_target" then d.offsetX, d.offsetY = 0, -280 end
    return d
end
ns.AuraDefaultsFor = AuraDefaultsFor

-- ==========================================================================
-- INFO BAR (hora, fps, ms, zona + boton calendario + fondo decorativo)
-- ==========================================================================
local INFOBAR_KEY = "infobar"
local INFOBAR_BG_TEX   = A .. "info_bg.tga"   -- fondo custom del info bar
ns.INFOBAR_BG_TEX = INFOBAR_BG_TEX   -- expuesta para InfoBar.lua (subsistema extraido de core)
ns.INFOBAR_KEY = INFOBAR_KEY
ns.IsInfoBar = function(key) return key == INFOBAR_KEY end

-- Declarados temprano para que ns.CurrentProfile (mas abajo) los vea como upvalue.
local MICROMENU_KEY = "micromenu"
local CHATBUBBLE_KEY = "chatbubble"
local TRACKER_KEY = "tracker"
ns.TRACKER_KEY = TRACKER_KEY
ns.IsTracker = function(key) return key == TRACKER_KEY end
local GLOW_KEY = "glow"   -- glow custom sobre el "assisted highlight" (rotacion asistida)
ns.GLOW_KEY = GLOW_KEY
ns.IsGlow = function(key) return key == GLOW_KEY end

local function InfoBarDefaults()
    return {
        enabled = true, strata = "MEDIUM", scale = 1.0,
        anchor = "", point = "TOP", relPoint = "TOP", offsetX = 0, offsetY = -4,
        fontSize = 14, textColor = { r = 1, g = 0.82, b = 0.0 },   -- globales (fallback por elemento)
        moveTogether = false,   -- en preview, arrastrar un elemento mueve TODO
        -- Elementos (mostrar + offset individual respecto al centro del root).
        -- B9: cada texto tiene Color/Alpha/Size PROPIOS (independientes; default = valor global).
        showZone = true, zoneX = 0,    zoneY = 14,  zoneAlpha = 1, zoneSize = 14, zoneColor = { r = 1, g = 0.82, b = 0.0 },
        showTime = true, timeX = 0,    timeY = -6,  timeAlpha = 1, timeSize = 14, timeColor = { r = 1, g = 0.82, b = 0.0 },
        showFps  = true, fpsX = -80,   fpsY = -6,   fpsAlpha = 1,  fpsSize = 14,  fpsColor  = { r = 1, g = 0.82, b = 0.0 },
        showMs   = true, msX = 80,     msY = -6,    msAlpha = 1,   msSize = 14,   msColor   = { r = 1, g = 0.82, b = 0.0 },
        -- (Botones de calendario y mochila eliminados; el calendario se abre clickeando el reloj.)
        -- Fondo decorativo (atlas).
        showBg = true, bgTexture = INFOBAR_BG_TEX, bgWidth = 360, bgHeight = 82, bgAlpha = 1.0, bgOffsetX = 0, bgOffsetY = -10,
    }
end
ns.InfoBarDefaults = InfoBarDefaults

ns.STRATA_VALUES = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
ns.POINT_VALUES  = { "CENTER", "TOP", "BOTTOM", "LEFT", "RIGHT", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }

-- ==========================================================================
-- ESTADO
-- ==========================================================================
local db
local unlocked = false
local frames = {}
ns.frames = frames
local portraits = {}
ns.portraits = portraits
local auras = {}
ns.auras = auras
-- El frame del info bar (unico) vive en InfoBar.lua; se lee via ns.infobar.
ns.currentEdit = "player"

-- Fade-in suave al APARECER un frame (hook de OnShow). En frames SEGUROS NO se puede
-- usar UIFrameFadeIn: internamente llama Show(), y cuando el OnShow lo dispara el
-- driver seguro (RegisterUnitWatch/state driver) ese Show() protegido se BLOQUEA.
-- Solucion: un AnimationGroup con animacion Alpha (0→1) que solo anima el alpha, sin
-- llamar Show(). El frame ya esta visible (OnShow ya disparo). Gated por db.fadeIn.
-- El fade-OUT no es viable en frames seguros (el driver los oculta al instante).
local function AttachFadeIn(frame)
    if not frame or frame._mcfFadeHooked then return end
    frame._mcfFadeHooked = true
    local ag = frame:CreateAnimationGroup()
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(0); a:SetToAlpha(1); a:SetSmoothing("OUT")
    frame._mcfFadeAnim, frame._mcfFadeA = ag, a
    frame:HookScript("OnShow", function(self)
        if not (db and db.fadeIn) or unlocked then return end
        local grp = self._mcfFadeAnim
        if grp and not grp:IsPlaying() then
            self._mcfFadeA:SetDuration(db.fadeDuration or 0.25)
            grp:Play()
        end
    end)
end
ns.AttachFadeIn = AttachFadeIn

-- Grupos que se pueden mover juntos (opcional).
local PARTY_KEYS = { "party1", "party2", "party3", "party4", "party5" }
local BOSS_KEYS  = { "boss1", "boss2", "boss3", "boss4", "boss5" }
ns.PARTY_KEYS = PARTY_KEYS
local function GetMoveGroup(key)
    if not db then return nil end
    if key:sub(1, 5) == "party" and db.groupMoveParty then return PARTY_KEYS end
    if key:sub(1, 4) == "boss" and db.groupMoveBoss then return BOSS_KEYS end
    return nil
end
ns.GetMoveGroup = GetMoveGroup

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
ns.clamp = clamp

-- Llamada segura SIN crear una closure por invocacion (a diferencia de
-- pcall(function() ... end), que aloja una closura nueva cada vez y genera basura
-- para el GC en el ticker de 0.1s). pcall(fn, ...) pasa los args sin closura.
-- safeBool: coerce el 1er retorno a booleano (o false si error). safeVal: valor o nil.
-- CLAVE (Midnight): si fn devuelve un BOOLEANO SECRETO, hacer `r and ...` (test booleano)
-- crashea ("boolean test on secret boolean value"). Por eso se chequea issecretvalue ANTES
-- de coercer; si es secreto se devuelve false (mismo resultado que el pcall-closure original,
-- donde la coercion crasheaba dentro del pcall y la variable quedaba en su valor inicial false).
local function safeBool(fn, ...)
    local ok, r = pcall(fn, ...)
    if not ok or (issecretvalue and issecretvalue(r)) then return false end
    return r and true or false
end
local function safeVal(fn, ...) local ok, r = pcall(fn, ...); if ok then return r end end
ns.safeBool = safeBool
ns.safeVal = safeVal

-- Snapshot POR TICK de estados seguros compartidos (solo booleanos, jamas secretos):
-- combate/resting se consultaban decenas de veces por tick con la misma respuesta.
-- Lo rellena el ticker principal al inicio de cada pasada; fuera del ticker puede
-- estar desfasado como mucho 0.1s (irrelevante para alphas/badges).
local tickState = {}
ns.tickState = tickState   -- misma tabla por referencia; el ticker principal muta sus campos, nunca la reasigna

-- Recuadro de EDICION (preview): en vez de un bloque verde solido, un borde fino de 1px
-- estilo "seleccion de editor" (cian suave) + relleno casi imperceptible. Es un Frame por
-- encima del contenido (borde visible, no lo tapa). Reemplaza los editBG verdes de todas las
-- unidades/portraits/auras/infobar/micromenu. SetShown/Hide siguen funcionando igual.
local EDIT_HL = { r = 0.35, g = 0.78, b = 1.0 }   -- color del recuadro de edicion
local function MakeEditHighlight(parent, label)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints(parent)
    f:SetFrameLevel(parent:GetFrameLevel() + 12)
    local fill = f:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints(f)
    fill:SetColorTexture(EDIT_HL.r, EDIT_HL.g, EDIT_HL.b, 0.07)
    local t = 1
    -- Cada borde = rectangulo fino definido por esquinas OPUESTAS (TOPLEFT + BOTTOMRIGHT)
    -- ancladas a los lados de f (mismo metodo que GlowDrawBorder).
    local function edge(rp1, x1, y1, rp2, x2, y2)
        local b = f:CreateTexture(nil, "ARTWORK")
        b:SetColorTexture(EDIT_HL.r, EDIT_HL.g, EDIT_HL.b, 0.9)
        b:SetPoint("TOPLEFT", f, rp1, x1, y1); b:SetPoint("BOTTOMRIGHT", f, rp2, x2, y2)
    end
    edge("TOPLEFT", 0, 0, "TOPRIGHT", 0, -t)          -- arriba
    edge("BOTTOMLEFT", 0, t, "BOTTOMRIGHT", 0, 0)     -- abajo
    edge("TOPLEFT", 0, 0, "BOTTOMLEFT", t, 0)         -- izquierda
    edge("TOPRIGHT", -t, 0, "BOTTOMRIGHT", 0, 0)      -- derecha
    -- Nombre del elemento ENCIMA del recuadro (visible siempre que el outline lo este).
    if label then
        local lbl = f:CreateFontString(nil, "OVERLAY")
        lbl:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        lbl:SetPoint("BOTTOM", f, "TOP", 0, 3)
        lbl:SetTextColor(EDIT_HL.r, EDIT_HL.g, EDIT_HL.b, 1)
        lbl:SetText(label)
        f.label = lbl
    end
    f:Hide()
    return f
end
ns.MakeEditHighlight = MakeEditHighlight   -- expuesto para subsistemas en archivos aparte

-- B4 — Outline configurable por unidad: tamaño propio (0 = seguir al frame) y ocultar el
-- nombre. El editBG normalmente hace SetAllPoints(parent); con w/h > 0 se ancla al CENTRO
-- del frame con ese tamaño. Se llama desde el apply de cada unidad.
local function ApplyOutline(f, parent, w, h, hideName)
    if not f then return end
    f:ClearAllPoints()
    if w and h and w > 0 and h > 0 then
        f:SetPoint("CENTER", parent, "CENTER", 0, 0)
        f:SetSize(w, h)
    else
        f:SetAllPoints(parent)
    end
    if f.label then f.label:SetShown(not hideName) end
end
ns.ApplyOutline = ApplyOutline

-- B4 — Preview del SECURE BUTTON: dibuja el AREA DE CLICK real (hit rect) como un recuadro
-- NARANJA con etiqueta "click", visible solo en preview cuando db.previewSecureButton. Es un
-- overlay decorativo (no captura mouse); refleja btnWidth/btnHeight/btnOffset (o el tamaño de
-- la barra si son 0). Se crea una vez por unidad y se actualiza en el apply.
local HIT_HL = { r = 1.0, g = 0.55, b = 0.10 }
local function MakeHitPreview(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetFrameLevel(parent:GetFrameLevel() + 13)
    local t = 1
    local function edge(rp1, x1, y1, rp2, x2, y2)
        local b = f:CreateTexture(nil, "OVERLAY")
        b:SetColorTexture(HIT_HL.r, HIT_HL.g, HIT_HL.b, 0.9)
        b:SetPoint("TOPLEFT", f, rp1, x1, y1); b:SetPoint("BOTTOMRIGHT", f, rp2, x2, y2)
    end
    edge("TOPLEFT", 0, 0, "TOPRIGHT", 0, -t)
    edge("BOTTOMLEFT", 0, t, "BOTTOMRIGHT", 0, 0)
    edge("TOPLEFT", 0, 0, "BOTTOMLEFT", t, 0)
    edge("TOPRIGHT", -t, 0, "BOTTOMRIGHT", 0, 0)
    local lbl = f:CreateFontString(nil, "OVERLAY")
    lbl:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    lbl:SetPoint("TOP", f, "BOTTOM", 0, -1)
    lbl:SetTextColor(HIT_HL.r, HIT_HL.g, HIT_HL.b, 1)
    lbl:SetText("click")
    f:Hide()
    return f
end
ns.MakeHitPreview = MakeHitPreview

local function DeepCopy(t)
    if type(t) ~= "table" then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = DeepCopy(v) end
    return r
end
ns.DeepCopy = DeepCopy

ns.IsUnlocked = function() return unlocked end
ns.GetDB = function() return db end
ns.SetUnlockedFlag = function(v) unlocked = v end   -- setter para SetUnlocked (Editing.lua)

-- Rueda del raton en modo Lock (preview) ajusta la escala del elemento. getP devuelve el
-- perfil (con campo .scale); refresh re-aplica. EnableMouseWheel se activa/desactiva en
-- SetUnlocked (solo captura la rueda en preview, no interfiere con el zoom de camara fuera).
-- B3 — Scale sin desplazamiento: al aplicar SetScale(s), los offsets de SetPoint (que van
-- en coords LOCALES del frame, escaladas por su effective scale) mapean a distinta posicion
-- en pantalla, asi que la unidad "se movia" al cambiar la escala. Compensacion: al detectar
-- que la escala cambio respecto a la ULTIMA con la que se escribieron los offsets, se
-- multiplican los offsets por (escalaVieja/escalaNueva) — la escala del parent se cancela,
-- asi que basta ese factor. El "ancla" se guarda por IDENTIDAD de la tabla de perfil (weak
-- keys, runtime-only → nunca se serializa; un preset nuevo = tabla nueva = ancla nueva sin
-- compensar). Idempotente: solo muta cuando scale != ancla, venga de slider/rueda/import.
local scaleAnchors = setmetatable({}, { __mode = "k" })
local function CompensateScale(p, kind)
    if not p then return end
    local scale = p.scale or 1
    local anchor = scaleAnchors[p]
    if anchor == nil then scaleAnchors[p] = scale; return end
    if anchor == scale or scale == 0 then return end
    local k = anchor / scale
    scaleAnchors[p] = scale
    local function mul(a, b)
        if type(p[a]) == "number" then p[a] = p[a] * k end
        if type(p[b]) == "number" then p[b] = p[b] * k end
    end
    if kind == "portrait" then
        mul("centerX", "centerY"); mul("altX", "altY")
    elseif kind == "aura" then
        mul("offsetX", "offsetY"); mul("altX", "altY"); mul("deadX", "deadY"); mul("deadTargetX", "deadTargetY")
    else
        mul("offsetX", "offsetY")
    end
end
ns.CompensateScale = CompensateScale

local function AttachScaleWheel(frame, getP, reposition)
    frame:EnableMouseWheel(false)
    frame:SetScript("OnMouseWheel", function(self, dir)
        if not unlocked or InCombatLockdown() then return end
        local p = getP(); if not p then return end
        p.scale = math.max(0.3, math.min(3.0, (p.scale or 1) + (dir > 0 and 0.05 or -0.05)))
        -- reposition (layout del elemento) compensa el offset por el cambio de escala y
        -- reancla, evitando el salto. Fallback: solo SetScale (comportamiento antiguo).
        if reposition then reposition() else self:SetScale(p.scale) end
        if ns.OnScaleWheel then ns.OnScaleWheel() end   -- refresca el slider del menu si esta abierto
    end)
end
ns.AttachScaleWheel = AttachScaleWheel   -- expuesto para subsistemas en archivos aparte
-- Tabla vacia reusada como fallback nil-safe: widgets OCULTOS de otras secciones (ej. "Anchor to"
-- de la pestaña General) igual corren su refresher via RefreshControls() sin importar que seccion
-- este visible — necesitan que getP() devuelva ALGO indexable, no nil, o `getP()[dbKey]` explota.
local EMPTY_PROFILE = {}
ns.CurrentProfile = function()
    if ns.currentEdit == INFOBAR_KEY then return db.infobar end
    if ns.currentEdit == MICROMENU_KEY then return db.micromenu end
    if ns.currentEdit == CHATBUBBLE_KEY then return db.chatbubble end
    if ns.currentEdit == TRACKER_KEY then return db.tracker end
    if ns.currentEdit == GLOW_KEY then return db.glow end
    -- 2026-07-16: "aura_party" (PartyAuraPreview.lua) es un elemento SINGLETON como Tracker/Glow,
    -- pero sus settings son GLOBALES (db.partyAuraDirection/partyAuraIconSize, no una tabla propia
    -- por-elemento) — sus widgets reales usan getTbl/onChange, nunca getP(). Sin este branch caia
    -- en `db.units["aura_party"]` (nil) y crasheaba ("attempt to index a nil value") apenas se
    -- abria el menu, porque OTROS widgets ocultos (de la pestaña General) llaman getP() siempre.
    if ns.IsPartyAura and ns.IsPartyAura(ns.currentEdit) then return EMPTY_PROFILE end
    -- "aura_arena" (ArenaAuraPreview.lua) es SINGLETON como aura_party -- mismo
    -- motivo/bug ("attempt to index a nil value") si falta este branch.
    if ns.IsArenaAura and ns.IsArenaAura(ns.currentEdit) then return EMPTY_PROFILE end
    if ns.IsMinimap and ns.IsMinimap(ns.currentEdit) then return db.minimap end
    if ns.IsNameplates and ns.IsNameplates(ns.currentEdit) then return db.nameplates end
    -- "classpower" (ClassPower.lua) es SINGLETON como los de arriba -- mismo
    -- bug ("attempt to index a nil value") que aura_party si no se agrega
    -- este branch: los widgets OCULTOS de la pestaña General llaman getP()
    -- siempre, sin importar que seccion este visible.
    if ns.IsClassPower and ns.IsClassPower(ns.currentEdit) then return db.classpower end
    if AURA_SET[ns.currentEdit] then return db.auras[ns.currentEdit] end
    if PORTRAIT_SET[ns.currentEdit] then return db.portraits[ns.currentEdit] end
    return db.units[ns.currentEdit]
end

ns.ApplyCurrent = function()
    if ns.currentEdit == INFOBAR_KEY then
        if ns.RefreshInfoBar then ns.RefreshInfoBar() end
    elseif ns.currentEdit == MICROMENU_KEY then
        if ns.RefreshMicroMenu then ns.RefreshMicroMenu() end
    elseif ns.currentEdit == CHATBUBBLE_KEY then
        if ns.RefreshChatBubble then ns.RefreshChatBubble() end
    elseif ns.currentEdit == TRACKER_KEY then
        if ns.RefreshTracker then ns.RefreshTracker() end
    elseif ns.currentEdit == GLOW_KEY then
        if ns.RefreshGlow then ns.RefreshGlow(true) end
    elseif ns.IsMinimap and ns.IsMinimap(ns.currentEdit) then
        if ns.RefreshMinimap then ns.RefreshMinimap() end
    elseif ns.IsNameplates and ns.IsNameplates(ns.currentEdit) then
        if ns.RefreshNameplateStyle then ns.RefreshNameplateStyle() end
    elseif ns.IsClassPower and ns.IsClassPower(ns.currentEdit) then
        if ns.RefreshClassPower then ns.RefreshClassPower() end
    elseif AURA_SET[ns.currentEdit] then
        if ns.RefreshAura then ns.RefreshAura(ns.currentEdit) end
    elseif PORTRAIT_SET[ns.currentEdit] then
        if ns.RefreshPortrait then ns.RefreshPortrait(ns.currentEdit) end
    elseif ns.IsRaid and ns.IsRaid(ns.currentEdit) then
        if ns.RefreshRaid then ns.RefreshRaid() end
    else
        ns.RefreshUnit(ns.currentEdit)
    end
end

-- Muestra/oculta los NOMBRES de los outlines (etiquetas encima del recuadro de edicion) de
-- TODOS los elementos, segun db.lockHide.names (toggle "Names" del Editing). Para units respeta
-- ademas su outlineHideName individual. Se llama al cambiar el toggle y en RefreshAll.
local function RefreshOutlineNames()
    local hideAll = db and db.lockHide and db.lockHide.names
    for _, u in pairs(frames) do
        if u.editBG and u.editBG.label then
            u.editBG.label:SetShown(not (hideAll or ns.P(u).outlineHideName))
        end
    end
    for _, u in pairs(portraits) do
        if u.editBG and u.editBG.label then u.editBG.label:SetShown(not hideAll) end
    end
    for _, g in pairs(auras) do
        if g.editBG and g.editBG.label then g.editBG.label:SetShown(not hideAll) end
    end
    if ns.infobar and ns.infobar.editBG and ns.infobar.editBG.label then ns.infobar.editBG.label:SetShown(not hideAll) end
    if ns.micromenu and ns.micromenu.editBG and ns.micromenu.editBG.label then
        ns.micromenu.editBG.label:SetShown(not hideAll)
    end
end
ns.RefreshOutlineNames = RefreshOutlineNames

local function RefreshAll()
    if ns.RefreshAllUnits then ns.RefreshAllUnits() end
    if ns.RefreshAllPortraits then ns.RefreshAllPortraits() end
    if ns.RefreshAllAuras then ns.RefreshAllAuras() end
    if ns.RefreshInfoBar then ns.RefreshInfoBar() end
    if ns.RefreshMicroMenu then ns.RefreshMicroMenu() end
    if ns.RefreshChatBubble then ns.RefreshChatBubble() end
    if ns.RefreshGlow then ns.RefreshGlow(true) end
    if ns.RefreshMinimap then ns.RefreshMinimap() end
    if ns.RefreshMirrorTimerPreview then ns.RefreshMirrorTimerPreview() end
    if ns.RefreshRaid then ns.RefreshRaid() end
    -- Faltaba (2026-07-20, pedido del usuario: "en el lock me salga el
    -- class power, para moverlo y escalarlo"): sin esto, ClassPower.lua
    -- nunca se enteraba de entrar/salir de Lock via el camino central
    -- (SetUnlocked -> RefreshAll), asi que ni el outline ni el mouse se
    -- activaban al togglear el Lock.
    if ns.RefreshClassPower then ns.RefreshClassPower() end
    RefreshOutlineNames()
end
ns.RefreshAll = RefreshAll


-- ==========================================================================
-- Abrir el panel de PERSONAJE desde el portrait del player — EN COMBATE (via SEGURA)
-- ==========================================================================
-- Abrir un UIPanel (CharacterFrame) EN COMBATE solo es posible por ejecucion SEGURA de Blizzard.
-- ToggleCharacter desde codigo inseguro se BLOQUEA en combate ("Interface action failed because of
-- an AddOn"). Solucion: boton(es) SEGURO(s) con `type1="macro"` + `macrotext1="/click
-- CharacterMicroButton"` — MISMO patron YA PROBADO y funcionando en este addon para el overlay de
-- cancelar auras (EnsureCancelOverlay: type2="macro"+macrotext2, numerado por boton de raton). Un
-- primer intento con `type`/`clickbutton` SIN numero (delegacion directa, patron de W2UI en su
-- portrait que es SecureUnitButtonTemplate) NO abrio ni fuera de combate — los atributos sin
-- numero de boton no aplican igual en un SecureActionButtonTemplate simple; el patron numerado+macro
-- es el que este codebase ya tiene validado. El micro menu ya NO oculta CharacterMicroButton con
-- Hide() (MM_SoftHide lo deja mostrado-invisible) para que el /click le llegue.
--
-- IMPORTANTE: mover/redimensionar un frame SEGURO en combate esta BLOQUEADO. El portrait_player
-- tiene 2 posiciones (centro/alterna) que pueden alternar incluso EN combate (centerInCombat).
-- Un solo boton "siguiendo" al portrait fallaria justo cuando mas se necesita. Solucion: DOS
-- botones ESTATICOS, uno cubriendo la posicion "centro" y otro la "alterna" (mismo anchor/point/
-- offset/escala que usa el portrait para cada una — ver PortraitUpdatePosition), creados/colocados
-- SOLO al cargar o al cambiar la configuracion (fuera de combate). NUNCA se mueven por tick: caen
-- exactamente donde el portrait aparece en cada posicion, sea cual sea la que este activa, sin
-- necesitar seguir nada en vivo.
do
    local charHost
    local function EnsureCharHost()
        if not charHost then
            charHost = CreateFrame("Frame", "MyCF_PortraitCharHost", UIParent)
            charHost:SetFrameStrata("HIGH")
        end
        return charHost
    end

    local function MakeCharButton(name)
        local b = CreateFrame("Button", name, EnsureCharHost(), "SecureActionButtonTemplate")
        b:SetFrameStrata("HIGH")
        b:SetToplevel(true)
        b:SetFrameLevel(200)
        b:EnableMouse(true)
        -- Down+Up (no solo Up): patron identico al overlay de cancelar auras (que SI funciona);
        -- el motor de atributos seguros de un SecureActionButtonTemplate espera el par down/up
        -- para disparar el snippet type1/macrotext1 correctamente.
        b:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
        b:SetAttribute("type1", "macro")
        b:SetAttribute("macrotext1", "/click CharacterMicroButton")
        b:SetScript("OnEnter", function(self)
            if GameTooltip:IsForbidden() then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Character Info", 1, 1, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() if not GameTooltip:IsForbidden() then GameTooltip:Hide() end end)
        b:Hide()
        return b
    end

    -- Coloca un boton EXACTAMENTE con el mismo metodo que PortraitUpdatePosition usa para el root
    -- del portrait (mismo parent/point/relPoint/offset + SetScale(p.scale)) → cae en el MISMO sitio
    -- en pantalla que ocuparia el portrait en esa posicion, sin necesitar coords absolutas ni
    -- seguimiento en vivo.
    local function PlaceStatic(btn, anchorName, point, relPoint, x, y, size, scale)
        local parent = _G[anchorName]
        if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
        btn:SetScale(scale or 1)
        btn:SetSize(size or 90, size or 90)
        btn:ClearAllPoints()
        btn:SetPoint(point or "CENTER", parent, relPoint or "CENTER", x or 0, y or 0)
    end

    -- Crea/reubica los 2 botones estaticos del portrait_player. Solo fuera de combate; si la
    -- config no cambio no pasa nada por llamarlo de mas (SetPoint/SetSize son baratos y no
    -- corren por tick, solo en estos puntos de entrada puntuales).
    local function LayoutPortraitCharButtons(u)
        if not u or u.key ~= "portrait_player" or InCombatLockdown() then return end
        local p = ns.PP(u)
        if not p then return end
        if unlocked or not p.clickOpenChar then
            if u.charBtnCenter then u.charBtnCenter:Hide() end
            if u.charBtnAlt then u.charBtnAlt:Hide() end
            return
        end
        if not u.charBtnCenter then u.charBtnCenter = MakeCharButton("MyCF_PortraitCharBtnCenter") end
        if not u.charBtnAlt then u.charBtnAlt = MakeCharButton("MyCF_PortraitCharBtnAlt") end
        -- charBtnScale: area de click INDEPENDIENTE del tamaño visual del portrait (p.size). El
        -- anchor sigue siendo CENTER, asi que agrandar/achicar queda centrado sobre el retrato.
        local size, scale = (p.size or 90) * (p.charBtnScale or 1), p.scale or 1
        PlaceStatic(u.charBtnCenter, p.centerAnchor, p.centerPoint, p.centerRelPoint, p.centerX, p.centerY, size, scale)
        u.charBtnCenter:Show()
        if u.features and u.features.dualPos then
            PlaceStatic(u.charBtnAlt, p.altAnchor, p.altPoint, p.altRelPoint, p.altX, p.altY, size, scale)
            u.charBtnAlt:Show()
        else
            u.charBtnAlt:Hide()
        end
    end
    ns.LayoutPortraitCharButtons = LayoutPortraitCharButtons

    ns.LayoutPortraitCharButtonsAll = function()
        if portraits and portraits["portrait_player"] then LayoutPortraitCharButtons(portraits["portrait_player"]) end
    end
end

-- NOTA: el subsistema MICRO MENU vive en MicroMenu.lua (extraido de aqui por el
-- limite de 200 locals). Expone ns.MICROMENU_KEY / ns.IsMicroMenu /
-- ns.MicroMenuDefaults / ns.RefreshMicroMenu / ns.MM_ReassertArt / ns.micromenu.
-- MICROMENU_KEY sigue como local de core (lo usa ns.CurrentProfile).

-- NOTA: el subsistema CHAT BUBBLE vive en ChatBubble.lua (extraido de aqui por el
-- limite de 200 locals). Expone ns.CHATBUBBLE_KEY / ns.IsChatBubble /
-- ns.ChatBubbleDefaults / ns.RefreshChatBubble. CHATBUBBLE_KEY sigue como local de
-- core (lo usa ns.CurrentProfile).

-- NOTA: el subsistema ASSISTED GLOW vive en Glow.lua (se movio de aqui porque el
-- chunk principal de core.lua excedia el limite de 200 locals de Lua). Expone
-- ns.RefreshGlow / ns.GlowDefaults / ns.GLOW_STYLES / ns.HasLCG.


-- Restablece una unidad (o portrait) a sus valores por defecto.
-- Default de reset: BASE = defaults de codigo (todos los campos actuales) SOBRESCRITOS por
-- el layout horneado (ns.BUILTIN / export del autor) cuando existe. Asi el reset INDIVIDUAL
-- usa el mismo layout que una instalacion limpia / "Reset ALL" (no valores de fabrica),
-- pero sin perder campos nuevos que el export no tuviera.
local function ResetDefault(domain, key, fallback)
    local base = DeepCopy(fallback())
    local b = ns.BUILTIN and ns.BUILTIN[domain]
    local src = b and (key and b[key] or (not key and b)) or nil
    if type(src) == "table" then
        for k, v in pairs(src) do base[k] = DeepCopy(v) end
    end
    return base
end

ns.ResetUnit = function(key)
    if not db then return end
    if key == INFOBAR_KEY then
        db.infobar = ResetDefault("infobar", nil, InfoBarDefaults)
        if ns.RefreshInfoBar then ns.RefreshInfoBar() end
        if ns.OnProfilePasted then ns.OnProfilePasted() end
        print("|cff00ff00[MCF]|r Info bar reset.")
        return
    end
    if key == MICROMENU_KEY then
        db.micromenu = ResetDefault("micromenu", nil, ns.MicroMenuDefaults)
        if ns.RefreshMicroMenu then ns.RefreshMicroMenu() end
        if ns.OnProfilePasted then ns.OnProfilePasted() end
        print("|cff00ff00[MCF]|r Micro menu reset.")
        return
    end
    if key == CHATBUBBLE_KEY then
        db.chatbubble = ResetDefault("chatbubble", nil, ns.ChatBubbleDefaults)
        if ns.RefreshChatBubble then ns.RefreshChatBubble() end
        if ns.OnProfilePasted then ns.OnProfilePasted() end
        print("|cff00ff00[MCF]|r Chat bubble reset.")
        return
    end
    if key == GLOW_KEY then
        if ns.GlowDefaults then db.glow = ResetDefault("glow", nil, ns.GlowDefaults) end
        if ns.RefreshGlow then ns.RefreshGlow(true) end
        if ns.OnProfilePasted then ns.OnProfilePasted() end
        print("|cff00ff00[MCF]|r Assisted glow reset.")
        return
    end
    if ns.IsMinimap and ns.IsMinimap(key) then
        if ns.MinimapDefaults then db.minimap = ResetDefault("minimap", nil, ns.MinimapDefaults) end
        if ns.RefreshMinimap then ns.RefreshMinimap() end
        if ns.OnProfilePasted then ns.OnProfilePasted() end
        print("|cff00ff00[MCF]|r Minimap reset.")
        return
    end
    if ns.IsNameplates and ns.IsNameplates(key) then
        -- Pedido del usuario: "opcion para tener la configuracion actual
        -- como preterminada" -- si el usuario guardo un default propio
        -- (ns.SetNameplateUserDefault, ver Nameplates.lua), Reset usa ESE
        -- en vez de volver siempre a los valores de fabrica.
        if db.nameplateUserDefault then
            db.nameplates = DeepCopy(db.nameplateUserDefault)
        elseif ns.NameplateDefaults then
            db.nameplates = ResetDefault("nameplates", nil, ns.NameplateDefaults)
        end
        if ns.RefreshNameplateStyle then ns.RefreshNameplateStyle() end
        if ns.OnProfilePasted then ns.OnProfilePasted() end
        print("|cff00ff00[MCF]|r Nameplates reset.")
        return
    end
    if AURA_SET[key] then
        db.auras = db.auras or {}
        db.auras[key] = ResetDefault("auras", key, function() return AuraDefaultsFor(key) end)
        if ns.RefreshAura then ns.RefreshAura(key) end
        if ns.OnProfilePasted then ns.OnProfilePasted() end
        print("|cff00ff00[MCF]|r Auras reset: " .. key)
        return
    end
    if PORTRAIT_SET[key] then
        db.portraits = db.portraits or {}
        db.portraits[key] = ResetDefault("portraits", key, function() return PortraitDefaultsFor(key) end)
        if ns.RefreshPortrait then ns.RefreshPortrait(key) end
        if ns.OnProfilePasted then ns.OnProfilePasted() end
        print("|cff00ff00[MCF]|r Portrait reset: " .. key)
        return
    end
    if ns.IsRaid and ns.IsRaid(key) then
        if ns.RaidUnitDefaults then db.units.raid = ResetDefault("units", "raid", ns.RaidUnitDefaults) end
        if ns.RefreshRaid then ns.RefreshRaid() end
        if ns.OnProfilePasted then ns.OnProfilePasted() end
        print("|cff00ff00[MCF]|r Raid frames reset.")
        return
    end
    if not db.units then return end
    db.units[key] = ResetDefault("units", key, function() return DefaultsFor(key) end)
    ns.RefreshUnit(key)
    if ns.OnProfilePasted then ns.OnProfilePasted() end
    print("|cff00ff00[MCF]|r Unit reset: " .. key)
end

-- Sub-tablas incluidas en cada preset (export/save/load/reset). Lista
-- CENTRALIZADA (2026-07-19, pedido del usuario: "el export esta
-- desactualizado") -- antes SavePreset/LoadPreset/ResetAll tenian cada
-- campo escrito a mano por separado y se fueron quedando atras cada vez que
-- se agregaba un subsistema nuevo (Minimap/Nameplates/ClassPower/Tooltip/
-- ExtraButton/MirrorTimer quedaron afuera). Un solo lugar para agregar el
-- proximo. Declarada ACA (antes de ResetAll, que la usa mas abajo) en vez
-- de junto a SavePreset (mas abajo en el archivo) para que ambos puedan
-- verla.
local PRESET_TABLE_KEYS = {
    "units", "portraits", "auras", "infobar", "micromenu", "chatbubble", "glow", "tracker",
    "minimap", "nameplates", "classpower", "tooltip", "extrabutton", "mirrortimer",
}

-- Restablece TODO. Si hay un preset marcado como Default, "Reset ALL" carga
-- ESE preset (tu default pasa a ser el "por defecto" del addon); si no, valores de fabrica.
ns.ResetAll = function()
    if not (db and db.units) then return end
    if db.defaultPreset and db.presets and db.presets[db.defaultPreset] then
        ns.LoadPreset(db.defaultPreset)
        if ns.OnProfilePasted then ns.OnProfilePasted() end
        print("|cff00ff00[MCF]|r Reset to your default preset: " .. db.defaultPreset)
        return
    end
    -- Sin preset default: volver al layout NATIVO del addon (BUILTIN), no a
    -- fabrica. FIX 2026-07-19: antes solo restauraba units/portraits/auras/
    -- infobar -- el resto de subsistemas (nameplates, classpower, etc.)
    -- quedaba con lo que tuviera el usuario, no con lo horneado en BUILTIN.
    if ns.BUILTIN then
        for _, k in ipairs(PRESET_TABLE_KEYS) do
            if ns.BUILTIN[k] then db[k] = DeepCopy(ns.BUILTIN[k]) end
        end
        if ns.FillDefaults then ns.FillDefaults() end
        RefreshAll()
        if ns.OnProfilePasted then ns.OnProfilePasted() end
        print("|cff00ff00[MCF]|r Reset to the addon's native layout.")
        return
    end
    for _, def in ipairs(UNITS) do
        db.units[def.key] = DeepCopy(DefaultsFor(def.key))
    end
    db.portraits = db.portraits or {}
    for _, def in ipairs(PORTRAITS) do
        db.portraits[def.key] = DeepCopy(PortraitDefaultsFor(def.key))
    end
    db.auras = db.auras or {}
    for _, def in ipairs(AURAS) do
        db.auras[def.key] = DeepCopy(AuraDefaultsFor(def.key))
    end
    db.infobar = DeepCopy(InfoBarDefaults())
    RefreshAll()
    if ns.OnProfilePasted then ns.OnProfilePasted() end
    print("|cff00ff00[MCF]|r Everything reset (units, portraits, auras, info bar).")
end

-- ARENA (pedido del usuario 2026-07-19: "que copien visualmente los mismos
-- valores y texturas del tot y tot portrait, incluso el portrait del player
-- para arena aliado") -- ver uso en FillDefaults.
local CLONE_ARENA_FROM_TOT = {
    arena_player = true, arena_party1 = true, arena_party2 = true,
    arena_enemy1 = true, arena_enemy2 = true, arena_enemy3 = true,
}
local ARENA_UNIT_POSITION_FIELDS = {
    anchorFrame = true, point = true, relativePoint = true, offsetX = true, offsetY = true,
}
-- CORREGIDO (2026-07-19, "todos los portrait de arena deben tener icon de
-- clase, no 3d portrait"): los 6 clonan portrait_tot (icono) por igual,
-- incluido portrait_arena_player.
local CLONE_ARENA_PORTRAIT_FROM = {
    portrait_arena_player = "portrait_tot",
    portrait_arena_party1 = "portrait_tot",
    portrait_arena_party2 = "portrait_tot",
    portrait_arena_enemy1 = "portrait_tot",
    portrait_arena_enemy2 = "portrait_tot",
    portrait_arena_enemy3 = "portrait_tot",
}
local ARENA_PORTRAIT_POSITION_FIELDS = {
    centerAnchor = true, centerPoint = true, centerRelPoint = true, centerX = true, centerY = true,
    altAnchor = true, altPoint = true, altRelPoint = true, altX = true, altY = true, editPos = true,
}

-- FIX (2026-07-20, reportado por el usuario: "instale desde 0 y mis arenas
-- estaban movidas" -- confirmado con su SavedVariables real: NO era una
-- instalacion limpia de verdad, sino una cuenta con SavedVariables de una
-- version VIEJA del addon, de antes de que existieran las 6 unidades de
-- arena/raid/etc. En ese caso freshInstall es false (MyCustomFramesDB ya
-- existe) asi que ns.BUILTIN nunca se aplica de una -- pero para las claves
-- REALMENTE nuevas para esa cuenta (que faltan en su SavedVariables vieja),
-- TODO este archivo rellenaba solo con las funciones DefaultsXxx() (defaults
-- GENERICOS de codigo) en vez de con ns.BUILTIN (el layout curado del autor).
-- SEGUNDO REPORTE del mismo bug (2026-07-20, "no esta la posicion correcta de
-- mis raids, no esta tampoco los cambios al tamaño de mis portraits de arena"):
-- el mismo problema estaba repetido en TODOS los bloques de abajo (portraits,
-- auras, infobar, micromenu, chatbubble, glow, minimap, nameplates, classpower,
-- tooltip, extrabutton, mirrortimer, raid) -- el primer fix solo cubrio units.
-- Helper unico: para cada campo AUSENTE (nil-guard igual que antes, nunca pisa
-- nada que el usuario ya tenga), prueba primero el valor horneado
-- (ns.BUILTIN[domain][key] o ns.BUILTIN[domain] para los singleton), y recien
-- si BUILTIN tampoco lo tiene cae en el default generico de codigo.
local function FillProfile(prof, builtinTable, defaultsTable)
    if type(builtinTable) == "table" then
        for k, v in pairs(builtinTable) do
            if prof[k] == nil then prof[k] = (type(v) == "table") and DeepCopy(v) or v end
        end
    end
    if type(defaultsTable) == "table" then
        for k, v in pairs(defaultsTable) do
            if prof[k] == nil then prof[k] = v end
        end
    end
end

local function FillDefaults()
    for _, def in ipairs(UNITS) do
        local isNewUnit = db.units[def.key] == nil
        db.units[def.key] = db.units[def.key] or {}
        local prof = db.units[def.key]
        FillProfile(prof, ns.BUILTIN and ns.BUILTIN.units and ns.BUILTIN.units[def.key], DefaultsFor(def.key))
        -- ARENA (pedido del usuario 2026-07-19: "que copien visualmente los
        -- mismos valores y texturas del tot") -- SOLO la primera vez que esta
        -- unidad se crea (isNewUnit), clona el perfil COMPLETO de targettarget
        -- (ToT), salvo los campos de POSICION (esos ya vienen escalonados por
        -- defX/defY en DefaultsFor, para que no nazcan todas apiladas). Se
        -- clona el perfil de targettarget YA COMPLETO (targettarget se procesa
        -- antes que arena_* en esta misma tabla UNITS), asi que refleja
        -- cualquier ajuste que el usuario ya le haya hecho a ToT, no solo los
        -- defaults de fabrica.
        -- CORREGIDO (2026-07-20): este clon pisaba SIN CHEQUEAR NIL (prof[k] = v
        -- directo) lo que el paso de arriba (ns.BUILTIN.units[def.key]) recien
        -- habia rellenado con el layout curado del autor -- quedaba dando vueltas
        -- en circulo: BUILTIN rellenaba bien, esto lo pisaba con ToT de nuevo.
        -- Ahora se salta ENTERO si BUILTIN ya tenia datos para esta clave (ya
        -- quedo completa arriba); solo corre para instalaciones viejas sin ese
        -- bake (BUILTIN sin ns.BUILTIN.units[def.key]).
        local hasBuiltinArena = ns.BUILTIN and ns.BUILTIN.units and ns.BUILTIN.units[def.key]
        if isNewUnit and CLONE_ARENA_FROM_TOT[def.key] and not hasBuiltinArena then
            local src = db.units.targettarget
            if src then
                for k, v in pairs(src) do
                    if not ARENA_UNIT_POSITION_FIELDS[k] then
                        prof[k] = (type(v) == "table") and DeepCopy(v) or v
                    end
                end
            end
        end
    end
    -- FIX (2026-07-19, pedido del usuario: "ponles las texturas de bar, cage
    -- y cast que tiene tot a mis unitframe de arena") -- el clonado de arriba
    -- (isNewUnit) solo corre la PRIMERA vez que se crea la clave; si las 6
    -- unidades de arena ya existian en el perfil de una carga anterior a este
    -- fix, se quedaron con la textura generica y nunca mas se re-clonaban.
    -- Este paso, en cambio, corre SIEMPRE (no gateado por isNewUnit) y solo
    -- sincroniza las 3 texturas puntuales pedidas -- no pisa nada mas que el
    -- usuario haya personalizado a mano en las unidades de arena.
    if db.units.targettarget then
        local totTex = db.units.targettarget.texture
        local totCage = db.units.targettarget.cageTexture
        local totCast = db.units.targettarget.castTexture
        for key in pairs(CLONE_ARENA_FROM_TOT) do
            local prof = db.units[key]
            if prof then
                if totTex then prof.texture = totTex end
                if totCage then prof.cageTexture = totCage end
                if totCast then prof.castTexture = totCast end
            end
        end
    end
    db.portraits = db.portraits or {}
    for _, def in ipairs(PORTRAITS) do
        local isNewPortrait = db.portraits[def.key] == nil
        db.portraits[def.key] = db.portraits[def.key] or {}
        local prof = db.portraits[def.key]
        FillProfile(prof, ns.BUILTIN and ns.BUILTIN.portraits and ns.BUILTIN.portraits[def.key], PortraitDefaultsFor(def.key))
        -- Portraits de arena: portrait_arena_player clona portrait_player
        -- (el jugador real SI tiene modelo 3D) -- el resto clona portrait_tot
        -- (icono), pedido explicito del usuario ("incluso el portrait del
        -- player para arena aliado"). Excluye posicion (center*/alt*).
        -- CORREGIDO (2026-07-20, mismo motivo que el clon de arena en UNITS de
        -- arriba): se salta si BUILTIN ya tenia datos para esta clave (ya
        -- quedo completa arriba via FillProfile), para no pisarla de vuelta.
        local cloneSrcKey = CLONE_ARENA_PORTRAIT_FROM[def.key]
        local hasBuiltinPortrait = ns.BUILTIN and ns.BUILTIN.portraits and ns.BUILTIN.portraits[def.key]
        if isNewPortrait and cloneSrcKey and not hasBuiltinPortrait then
            local src = db.portraits[cloneSrcKey]
            if src then
                for k, v in pairs(src) do
                    if not ARENA_PORTRAIT_POSITION_FIELDS[k] then
                        prof[k] = (type(v) == "table") and DeepCopy(v) or v
                    end
                end
            end
        end
    end
    db.auras = db.auras or {}
    for _, def in ipairs(AURAS) do
        db.auras[def.key] = db.auras[def.key] or {}
        local prof = db.auras[def.key]
        FillProfile(prof, ns.BUILTIN and ns.BUILTIN.auras and ns.BUILTIN.auras[def.key], AuraDefaultsFor(def.key))
    end
    db.infobar = db.infobar or {}
    FillProfile(db.infobar, ns.BUILTIN and ns.BUILTIN.infobar, InfoBarDefaults())
    db.micromenu = db.micromenu or {}
    FillProfile(db.micromenu, ns.BUILTIN and ns.BUILTIN.micromenu, ns.MicroMenuDefaults())
    db.chatbubble = db.chatbubble or {}
    FillProfile(db.chatbubble, ns.BUILTIN and ns.BUILTIN.chatbubble, ns.ChatBubbleDefaults())
    db.glow = db.glow or {}
    if ns.GlowDefaults then
        FillProfile(db.glow, ns.BUILTIN and ns.BUILTIN.glow, ns.GlowDefaults())
    end
    if ns.MinimapDefaults then
        db.minimap = db.minimap or {}
        FillProfile(db.minimap, ns.BUILTIN and ns.BUILTIN.minimap, ns.MinimapDefaults())
    end
    if ns.NameplateDefaults then
        db.nameplates = db.nameplates or {}
        FillProfile(db.nameplates, ns.BUILTIN and ns.BUILTIN.nameplates, ns.NameplateDefaults())
    end
    if ns.ClassPowerDefaults then
        db.classpower = db.classpower or {}
        FillProfile(db.classpower, ns.BUILTIN and ns.BUILTIN.classpower, ns.ClassPowerDefaults())
    end
    if ns.TooltipDefaults then
        db.tooltip = db.tooltip or {}
        FillProfile(db.tooltip, ns.BUILTIN and ns.BUILTIN.tooltip, ns.TooltipDefaults())
    end
    if ns.ExtraButtonDefaults then
        db.extrabutton = db.extrabutton or {}
        FillProfile(db.extrabutton, ns.BUILTIN and ns.BUILTIN.extrabutton, ns.ExtraButtonDefaults())
    end
    if ns.MirrorTimerDefaults then
        db.mirrortimer = db.mirrortimer or {}
        FillProfile(db.mirrortimer, ns.BUILTIN and ns.BUILTIN.mirrortimer, ns.MirrorTimerDefaults())
    end
    -- RAID FRAMES (Raid.lua): perfil UNICO compartido por los 40 members,
    -- vive en db.units.raid (mismo shape que cualquier otra unidad). Mismo bug
    -- que el resto: usaba solo ns.RaidUnitDefaults() (generico), nunca el
    -- layout horneado -- ver comentario grande arriba de FillProfile.
    if ns.RaidUnitDefaults then
        db.units.raid = db.units.raid or {}
        FillProfile(db.units.raid, ns.BUILTIN and ns.BUILTIN.units and ns.BUILTIN.units.raid, ns.RaidUnitDefaults())
    end
end
ns.FillDefaults = FillDefaults

-- Migra rutas de textura antiguas (AzeriteUI) a las copias locales.
local function RemapPaths(units)
    if type(units) ~= "table" then return end
    for _, prof in pairs(units) do
        if type(prof) == "table" then
            for _, k in ipairs({ "texture", "cageTexture", "castTexture" }) do
                if prof[k] and PATH_REMAP[prof[k]] then prof[k] = PATH_REMAP[prof[k]] end
            end
        end
    end
end

-- ==========================================================================
-- Campos GLOBALES (no por-unidad) que un preset/export debe guardar. Lista unica
-- reutilizada por Save/Load/Export para que nunca queden desincronizadas (antes solo
-- se guardaba/restauraba `hideEditOutline`, perdiendo Move Party/Boss, Mouselook, Hide
-- Blizzard frames, fade-in, grid/snap, Sync Edit Mode, Explorer y sus zonas).
-- ==========================================================================
-- 2026-07-19 (pedido del usuario: "revisa si el export esta tomando el 100%
-- de opciones") -- barrido de TODO el addon comparando cada `db.<campo>`/
-- `GetDB().<campo>` referenciado contra esta lista: faltaban 5 ajustes
-- GLOBALES reales (direccion/tamaño de auras de party y arena, toggle de
-- chat edit box). Quedan afuera a proposito db.panelScale (escala de la
-- VENTANA del menu, no del look del personaje), db.setupSeen/
-- bartenderAutoProfile/bartenderAutoApplied/defaultPreset (bookkeeping
-- interno/por-personaje, no "apariencia" para compartir).
local GLOBAL_FLAT_KEYS = {
    "hideEditOutline", "groupMoveParty", "groupMoveBoss", "mouselook", "hideBlizzard", "barReposition",
    "dcFix", "gridShow", "gridSnap", "snapElements", "syncBlizzEditMode",
    "previewSecureButton", "fadeIn", "fadeDuration",
    "explorerEnabled", "explorerCombat", "explorerTarget", "explorerCasting", "explorerFadeAlpha",
    "partyAuraDirection", "partyAuraIconSize", "arenaAuraDirection", "arenaAuraIconSize",
    "hideChatEditBoxTexture", "raidGhostShowAll",
}
local GLOBAL_TABLE_KEYS = { "lockHide", "explorer", "explorerZones", "nameplateUserDefault", "nameplateProfiles" }

local function CollectGlobals()
    local g = {}
    for _, k in ipairs(GLOBAL_FLAT_KEYS) do g[k] = db[k] end
    for _, k in ipairs(GLOBAL_TABLE_KEYS) do
        if type(db[k]) == "table" then g[k] = DeepCopy(db[k]) end
    end
    return g
end

local function ApplyGlobals(g)
    if type(g) ~= "table" then return end
    for _, k in ipairs(GLOBAL_FLAT_KEYS) do
        if g[k] ~= nil then db[k] = g[k] end
    end
    for _, k in ipairs(GLOBAL_TABLE_KEYS) do
        if type(g[k]) == "table" then db[k] = DeepCopy(g[k]) end
    end
end

-- Un preset = perfil de TODO el addon (todas las unidades + globales + tracker).
ns.SavePreset = function(name)
    if not name or name == "" then return end
    db.presets = db.presets or {}
    local pr = { globals = CollectGlobals() }
    for _, k in ipairs(PRESET_TABLE_KEYS) do
        if db[k] then pr[k] = DeepCopy(db[k]) end
    end
    db.presets[name] = pr
    print("|cff00ff00[MCF]|r Profile saved: " .. name)
end
ns.LoadPreset = function(name)
    local pr = db.presets and db.presets[name]
    if not pr then return end
    if pr.units then
        for _, k in ipairs(PRESET_TABLE_KEYS) do
            if pr[k] then db[k] = DeepCopy(pr[k]) end
        end
        ApplyGlobals(pr.globals)
    else
        db.units = DeepCopy(pr)   -- compatibilidad con formato antiguo
    end
    FillDefaults()
    RefreshAll()
    if ns.RefreshTracker then ns.RefreshTracker() end
    if ns.RefreshMinimap then ns.RefreshMinimap() end
    if ns.RefreshNameplateStyle then ns.RefreshNameplateStyle() end
    if ns.RefreshClassPower then ns.RefreshClassPower() end
    if ns.RefreshTooltipSkin then ns.RefreshTooltipSkin() end
    if ns.RefreshMirrorTimers then ns.RefreshMirrorTimers() end
    print("|cff00ff00[MCF]|r Profile loaded: " .. name)
end
ns.DeletePreset = function(name)
    if db.presets then db.presets[name] = nil end
    if db.defaultPreset == name then db.defaultPreset = nil end
end
ns.GetPresetNames = function()
    local t = {}
    if db.presets then for n in pairs(db.presets) do t[#t + 1] = n end end
    table.sort(t)
    return t
end
ns.SetDefaultPreset = function(name)
    db.defaultPreset = name
    print("|cff00ff00[MCF]|r Default preset: " .. tostring(name))
end
ns.GetDefaultPreset = function() return db.defaultPreset end

-- ---- Exportar / Importar perfiles (string copiable) ----
local function Serialize(v)
    local t = type(v)
    if t == "string" then return string.format("%q", v) end
    if t == "number" then
        -- notacion segura para reimportar (evita %g con precision rara)
        if v == math.floor(v) and math.abs(v) < 1e15 then return string.format("%d", v) end
        return string.format("%.9g", v)
    end
    if t == "boolean" then return tostring(v) end
    if t == "table" then
        local parts = {}
        for k, val in pairs(v) do
            local key
            if type(k) == "string" then key = "[" .. string.format("%q", k) .. "]"
            elseif type(k) == "number" then key = "[" .. tostring(k) .. "]" end
            if key then parts[#parts + 1] = key .. "=" .. Serialize(val) end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "nil"
end

-- Exporta un preset (o el layout actual si name==nil) a un string "MCF1:{...}". Incluye
-- `tracker` + TODOS los globales (ver GLOBAL_FLAT_KEYS/GLOBAL_TABLE_KEYS) — antes solo se
-- exportaba `hideEditOutline`, perdiendo Move Party/Boss, Mouselook, Hide Blizzard, fade-in,
-- grid/snap, Sync Edit Mode y Explorer al exportar/importar.
ns.ExportPreset = function(name)
    local src = { name = name and db.presets and db.presets[name] and name or "Actual" }
    local from = (name and db.presets and db.presets[name]) or db
    for _, k in ipairs(PRESET_TABLE_KEYS) do
        if from[k] then src[k] = from[k] end
    end
    src.globals = (name and db.presets and db.presets[name] and db.presets[name].globals) or CollectGlobals()
    -- Pedido del usuario 2026-07-19: "se congela un monton de tiempo
    -- pegandolo" -- Serialize devuelve TODO en una sola linea gigante sin
    -- saltos; el EditBox multi-line tarda mucho en re-envolver/renderizar
    -- eso. Insertar un salto de linea despues de cada "," seguida de un
    -- nuevo "[" (limite de una entrada de tabla) alivia MUCHO el render sin
    -- tocar el contenido -- Lua ignora espacios/saltos entre tokens.
    local out = Serialize(src)
    out = out:gsub(",%[", ",\n[")
    return "MCF1:" .. out
end

-- Importa un string a un preset nuevo. Devuelve (ok, nombreOMensaje).
ns.ImportPreset = function(str)
    if type(str) ~= "string" then return false, "vacio" end
    str = str:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^MCF1:%s*", "")
    if str == "" then return false, "vacio" end
    local loader = loadstring or load
    local f = loader("return " .. str, "mcf_import")
    if not f then return false, "formato invalido" end
    if setfenv then setfenv(f, {}) end   -- sandbox: sin acceso a globals
    local ok, data = pcall(f)
    if not ok or type(data) ~= "table" or type(data.units) ~= "table" then
        return false, "datos invalidos"
    end
    db.presets = db.presets or {}
    local base = (type(data.name) == "string" and data.name ~= "") and data.name or "Importado"
    local name, n = base, 1
    while db.presets[name] do n = n + 1; name = base .. " " .. n end
    local pr = {}
    for _, k in ipairs(PRESET_TABLE_KEYS) do
        if type(data[k]) == "table" then pr[k] = DeepCopy(data[k]) end
    end
    pr.globals = type(data.globals) == "table" and DeepCopy(data.globals) or nil
    db.presets[name] = pr
    print("|cff00ff00[MCF]|r Profile imported: " .. name)
    return true, name
end

-- ==========================================================================
-- EVENTOS + TICKER
-- ==========================================================================
local function InitDB()
    -- Instalacion LIMPIA (sin SavedVariables): aplicar el layout NATIVO (ns.BUILTIN),
    -- que es la config horneada del autor, para que salga todo organizado igual.
    local freshInstall = (MyCustomFramesDB == nil)
    ns.FreshInstall = freshInstall
    MyCustomFramesDB = MyCustomFramesDB or {}
    if freshInstall and ns.BUILTIN then
        MyCustomFramesDB = DeepCopy(ns.BUILTIN)
    end
    if not MyCustomFramesDB.units then
        if MyCustomFramesDB.width then
            local old = {}
            for k, v in pairs(MyCustomFramesDB) do old[k] = v; MyCustomFramesDB[k] = nil end
            MyCustomFramesDB.units = { player = old }
        else
            MyCustomFramesDB.units = {}
        end
    end
    db = MyCustomFramesDB
    db.units.pet2 = nil
    db.portraits = db.portraits or {}
    db.auras = db.auras or {}
    -- Migracion: antes habia grupos separados buffs/debuffs; ahora uno por unidad.
    db.auras.aura_player_buffs = nil
    db.auras.aura_player_debuffs = nil
    db.auras.aura_target_buffs = nil
    db.auras.aura_target_debuffs = nil
    db.infobar = db.infobar or {}
    db.micromenu = db.micromenu or {}
    db.chatbubble = db.chatbubble or {}
    db.glow = db.glow or {}
    if db.setupSeen == nil then db.setupSeen = false end
    db.tracker = db.tracker or {}
    if db.tracker.enabled == nil then db.tracker.enabled = true end
    if type(db.tracker.color) ~= "table" then db.tracker.color = { r = 1.0, g = 0.882, b = 0.607 } end
    if db.tracker.hideInBoss == nil then db.tracker.hideInBoss = false end
    if db.tracker.hideInCombat == nil then db.tracker.hideInCombat = false end
    if db.tracker.hideOnHostileTarget == nil then db.tracker.hideOnHostileTarget = false end
    if db.tracker.hideInArena == nil then db.tracker.hideInArena = false end
    if db.tracker.hideInBG == nil then db.tracker.hideInBG = false end
    if db.tracker.titleOffsetX == nil then db.tracker.titleOffsetX = -18 end
    if db.tracker.dungeonTitleOffsetX == nil then db.tracker.dungeonTitleOffsetX = -18 end
    -- Alineacion de texto (pedido del usuario 2026-07-21): "LEFT"/"CENTER"/"RIGHT", aplicada via
    -- SetJustifyH (mismo metodo YA probado seguro que el centrado de headers, ver Tracker.lua
    -- ApplyFontColor) -- default LEFT = comportamiento nativo de Blizzard, sin cambios visibles
    -- hasta que el usuario elija otra cosa.
    if db.tracker.textAlign == nil then db.tracker.textAlign = "LEFT" end
    -- Migracion (2026-07-21): la clave se llamaba `hideEditGreen` (nombre viejo, de
    -- cuando el highlight de edicion era verde -- hoy es un borde cian, ver
    -- MakeEditHighlight). Preserva el valor que el usuario ya tenia guardado con el
    -- nombre viejo en vez de resetearlo a false.
    if db.hideEditOutline == nil then
        db.hideEditOutline = (db.hideEditGreen ~= nil) and db.hideEditGreen or false
    end
    db.hideEditGreen = nil
    if db.groupMoveParty == nil then db.groupMoveParty = false end
    if db.groupMoveBoss == nil then db.groupMoveBoss = false end
    if db.mouselook == nil then db.mouselook = false end
    if db.panelScale == nil then db.panelScale = 1.0 end   -- escala de la VENTANA del menu (no de las unidades)
    if db.hideBlizzard == nil then db.hideBlizzard = false end
    if db.barReposition == nil then db.barReposition = false end
    if db.dcFix == nil then db.dcFix = true end   -- fix DialogueUI+DynamicCam (on por defecto)
    if db.gridShow == nil then db.gridShow = false end   -- grid de alineacion en modo Lock
    if db.gridSnap == nil then db.gridSnap = false end   -- al soltar, ajusta a la grilla
    if db.snapElements == nil then db.snapElements = true end -- B2: alinear con bordes/centros de otros
    if db.syncBlizzEditMode == nil then db.syncBlizzEditMode = true end -- abrir el lock con el Edit Mode de Blizzard
    -- Bartender4 "usar este perfil para CUALQUIER personaje nuevo de la cuenta" (Setup Wizard
    -- pagina 7). nil/"" = apagado. bartenderAutoApplied = {charKey=true} para no re-forzar el
    -- perfil en personajes que el usuario ya cambio a mano despues del primer auto-apply.
    db.bartenderAutoProfile = db.bartenderAutoProfile or nil
    -- Direccion del test de auras de party (PartyAuraPreview.lua): izq/der/arriba/abajo.
    if db.partyAuraDirection == nil then db.partyAuraDirection = "left" end
    if db.partyAuraIconSize == nil then db.partyAuraIconSize = 26 end
    -- Direccion del test de auras de arena (ArenaAuraPreview.lua) -- pedido
    -- del usuario 2026-07-19: "se despliegan hacia abajo" (default distinto
    -- al de party, que es "left").
    if db.arenaAuraDirection == nil then db.arenaAuraDirection = "down" end
    if db.arenaAuraIconSize == nil then db.arenaAuraIconSize = 26 end
    db.bartenderAutoApplied = db.bartenderAutoApplied or {}
    -- (Inyeccion AzeriteUI ELIMINADA — causaba taint. db.azerite ya no se usa.)
    if db.previewSecureButton == nil then db.previewSecureButton = false end -- B4: dibuja el area de click
    -- B4: en modo Lock, ocultar SAMPLE de estos elementos (solo preview; no afecta el juego real).
    db.lockHide = db.lockHide or {}   -- {health/names/badges/raid/death = true → ocultos en preview}
    db.explorer = db.explorer or {}                      -- {elementKey=true} auto-ocultan por mouseover
    if db.explorerEnabled == nil then db.explorerEnabled = true end -- toggle maestro del Explorer
    if db.explorerCombat == nil then db.explorerCombat = true end   -- forzar visibles en combate
    if db.explorerTarget == nil then db.explorerTarget = false end  -- forzar visibles con target
    if db.explorerCasting == nil then db.explorerCasting = true end -- forzar visibles casteando (player)
    -- Tipos de contenido donde el Explorer esta ACTIVO (true = activo). Default: en todos,
    -- para no cambiar el comportamiento previo. false = el Explorer se apaga ahi (todo visible).
    db.explorerZones = db.explorerZones or {}
    do
        local z = db.explorerZones
        for _, k in ipairs({ "world", "dungeon", "raid", "arena", "battleground", "scenario" }) do
            if z[k] == nil then z[k] = true end
        end
    end
    if db.explorerFadeAlpha == nil then db.explorerFadeAlpha = 0 end -- opacidad al ocultarse
    if db.fadeIn == nil then db.fadeIn = true end
    if db.fadeDuration == nil then db.fadeDuration = 0.25 end
    FillDefaults()
    -- NOTA: ya NO se recarga el preset marcado al entrar. El layout en vivo
    -- (db.units/portraits/auras/infobar) persiste via SavedVariables, asi que en
    -- login se conserva exactamente lo que dejaste (el perfil seleccionado/marcado).
    -- El preset marcado (db.defaultPreset) sigue usandose solo para "Reset ALL".
    -- Migrar rutas antiguas (AzeriteUI) a las copias locales (activo + presets).
    RemapPaths(db.units)
    if db.presets then
        for _, pr in pairs(db.presets) do RemapPaths(pr.units or pr) end
    end
end

-- Fix DialogueUI + DynamicCam: DialogueUI llama a BlockShoulderOffsetZoom() al abrir su
-- panel, lo que congela CvarUpdateFunction y evita que las custom situations de DynamicCam
-- apliquen su camara. Neutraliza ambos metodos (los deja en no-op que fuerzan el flag a
-- false). TOGGLEABLE via db.dcFix: al apagarlo RESTAURA los metodos originales (guardados 1
-- vez en ns.dcOrig antes de sobrescribir). Se re-aplica en cada PLAYER_ENTERING_WORLD y al
-- cambiar el toggle.
ns.ApplyDcFix = function()
    if not DynamicCam then return end
    if not ns.dcOrig then
        ns.dcOrig = {
            block = DynamicCam.BlockShoulderOffsetZoom,
            allow = DynamicCam.AllowShoulderOffsetZoom,
        }
    end
    if db and db.dcFix then
        DynamicCam.BlockShoulderOffsetZoom = function(s) s.shoulderOffsetZoomTmpDisable = false end
        DynamicCam.AllowShoulderOffsetZoom = function(s) s.shoulderOffsetZoomTmpDisable = false end
        DynamicCam.shoulderOffsetZoomTmpDisable = false
    else
        DynamicCam.BlockShoulderOffsetZoom = ns.dcOrig.block
        DynamicCam.AllowShoulderOffsetZoom = ns.dcOrig.allow
    end
end

-- PERF (2026-07-19, "arregla todo"): antes era una tabla LITERAL nueva
-- creada en cada PLAYER_TARGET_CHANGED (dispara muy seguido en combate/
-- questing). Hoisteada a modulo-nivel, se reusa siempre.
local TARGET_PORTRAIT_KEYS = { "portrait_target", "portrait_tot", "portrait_player" }

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("UNIT_PET")
events:RegisterEvent("PLAYER_FOCUS_CHANGED")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("PLAYER_FLAGS_CHANGED")   -- toggle de Modo Guerra → refresca el badge de faccion
-- REVERTIDO (2026-07-19, "algo se dañó"): el intento de perf de arriba (loop
-- de RegisterUnitEvent por unidad) rompio los retratos -- confirmado con la
-- doc de Blizzard: RegisterUnitEvent NO es acumulativo, cada llamada nueva
-- para el MISMO evento en el MISMO frame REEMPLAZA la anterior en vez de
-- sumarse. El loop de 8 unidades dejaba escuchando UNIT_MODEL_CHANGED/
-- UNIT_PORTRAIT_UPDATE solo a la ULTIMA (party4), rompiendo el resto. Vuelto
-- a RegisterEvent sin filtro (como estaba antes de la sesion de perf) -- el
-- costo de escanear pairs(portraits)/pairs(auras) por cada unidad visible en
-- pantalla es real pero MENOR que romper el addon; si se quiere retomar este
-- optimizacion, hace falta un frame SEPARADO por unidad (RegisterUnitEvent
-- filtra por FRAME, no por llamada).
events:RegisterEvent("UNIT_MODEL_CHANGED")
events:RegisterEvent("UNIT_PORTRAIT_UPDATE")
events:RegisterEvent("UNIT_AURA")
-- ARENA (pedido del usuario 2026-07-19): dispara cuando Blizzard resuelve/
-- actualiza los oponentes de arena (arena1/2/3) -- mas responsivo que esperar
-- solo a GROUP_ROSTER_UPDATE/ZONE_CHANGED_NEW_AREA para el lado enemigo.
events:RegisterEvent("ARENA_OPPONENT_UPDATE")

events:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        InitDB()
        RefreshAll()
    elseif event == "PLAYER_ENTERING_WORLD" then
        if ns.ApplyDcFix then ns.ApplyDcFix() end
        if db then ns.UpdatePetDriver() ns.UpdatePartyDrivers()
            if ns.UpdateArenaDrivers then ns.UpdateArenaDrivers() end
            RefreshAll()
            if ns.HideBlizzardFrames then ns.HideBlizzardFrames() end
            for _, u in pairs(frames) do AttachFadeIn(u.button) end
            for _, u in pairs(portraits) do AttachFadeIn(u.root) end
            if ns.LayoutPortraitCharButtonsAll then ns.LayoutPortraitCharButtonsAll() end
        end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "ZONE_CHANGED_NEW_AREA" or event == "ARENA_OPPONENT_UPDATE" then
        if db then
            ns.UpdatePartyDrivers()
            if ns.UpdateArenaDrivers then ns.UpdateArenaDrivers() end
            if ns.HideBlizzardFrames then ns.HideBlizzardFrames() end
        end
    elseif event == "PLAYER_FLAGS_CHANGED" then
        -- Modo Guerra activado/desactivado (u otros flags del player): actualiza el badge de
        -- faccion al instante (alianza/horda ↔ variante de guerra) sin esperar al ticker.
        if db then
            for _, u in pairs(portraits) do
                if u.faction and u.unit == "player" then ns.PortraitUpdateFaction(u) end
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if ns.BlizzardNeedsApply and ns.BlizzardNeedsApply() and ns.HideBlizzardFrames then ns.HideBlizzardFrames() end
        for _, u in pairs(frames) do
            if u.needsLayout then ns.UnitApplyLayout(u) end
        end
        -- Portraits con Show/Hide diferido (root protegido en combate): aplicar ahora.
        for _, u in pairs(portraits) do
            if u._pendingShown ~= nil then ns.PortraitSetShown(u, u._pendingShown) end
        end
        -- Drags interrumpidos por combate: completar el StopMovingOrSizing + guardado
        -- re-invocando el propio OnDragStop (ya fuera de combate).
        for _, u in pairs(frames) do
            if u._stopMovePending then
                u._stopMovePending = nil
                local h = u.button:GetScript("OnDragStop")
                if h then pcall(h, u.button) end
            end
        end
        if frames["pet"] and frames["pet"].needsDriver then ns.UpdatePetDriver() end
        for _, key in ipairs(PARTY_KEYS) do
            if frames[key] and frames[key].needsDriver then ns.UpdatePartyDrivers() break end
        end
        if ns.ARENA_KEYS and ns.UpdateArenaDrivers then
            for _, key in ipairs(ns.ARENA_KEYS) do
                if frames[key] and frames[key].needsDriver then ns.UpdateArenaDrivers() break end
            end
        end
        if ns.micromenu and ns.micromenu.needsLayout and ns.RefreshMicroMenu then ns.RefreshMicroMenu() end
        -- Botones estaticos de personaje: recolocar por si la config cambio mientras estabamos en combate.
        if ns.LayoutPortraitCharButtonsAll then ns.LayoutPortraitCharButtonsAll() end
        -- Auras: crea overlays de cancelacion que no se pudieron crear en combate
        -- y refresca el grupo del player para poner al dia el macrotext.
        if db then
            for _, g in pairs(auras) do
                for _, b in ipairs(g.buttons) do ns.EnsureCancelOverlay(b) end
            end
            if not unlocked then
                for _, g in pairs(auras) do
                    if g.unit == "player" then ns.UpdateAuraGroup(g) end
                end
            end
        end
    elseif event == "UNIT_MODEL_CHANGED" or event == "UNIT_PORTRAIT_UPDATE" then
        if db then
            for _, u in pairs(portraits) do
                if u.unit == arg1 then ns.PortraitUpdatePicture(u) end
            end
        end
    elseif event == "UNIT_PET" then
        -- La pet cambio: recargar el retrato del portrait de pet.
        if db and portraits["portrait_pet"] then
            portraits["portrait_pet"]._wasShown = false
            ns.PortraitUpdatePicture(portraits["portrait_pet"])
        end
        ns.ResetCastBar("pet")
    elseif event == "PLAYER_FOCUS_CHANGED" then
        ns.ResetCastBar("focus")
    elseif event == "PLAYER_TARGET_CHANGED" then
        ns.ResetCastBar("target")
        ns.ResetCastBar("targettarget")
        -- Target (y target-de-target) cambiaron: recargar sus retratos.
        for _, k in ipairs(TARGET_PORTRAIT_KEYS) do
            if db and portraits[k] then
                portraits[k]._wasShown = false
                ns.PortraitUpdatePicture(portraits[k])
            end
        end
        -- Y sus auras.
        if db and not unlocked then
            for _, g in pairs(auras) do
                if g.unit == "target" then ns.UpdateAuraGroup(g) end
            end
        end
    elseif event == "UNIT_AURA" then
        if db and not unlocked then
            for _, g in pairs(auras) do
                if g.unit == arg1 then ns.UpdateAuraGroup(g) end
            end
        end
    end
end)

-- EXPLORER (#11): extraido a Explorer.lua (2026-07-22) -- GetElementFrame/
-- explorerDriver/ExplorerReset/ExplorerResetAll/ExplorerZoneAllowed/TickExplorer.

C_Timer.NewTicker(0.1, function()
    if not db or unlocked then return end
    -- Snapshot de estados seguros del tick (booleanos, jamas secretos): antes se
    -- consultaban decenas de veces por pasada con la misma respuesta.
    tickState.n = (tickState.n or 0) + 1
    tickState.inCombat = safeBool(UnitAffectingCombat, "player")
    tickState.resting  = safeBool(IsResting)
    tickState.partyOK  = ns.PartyContentAllowed()
    tickState.arenaOK  = ns.ArenaContentAllowed and ns.ArenaContentAllowed() or false
    -- pcall: un error aqui NO debe romper el loop de unidades (frames invisibles).
    -- Tick por-unidad (barras/highlight/badges/pet): extraido a Units.lua.
    if ns.TickUnits then ns.TickUnits() end
    -- Tick por-portrait (badges/posicion/estado): extraido a Portraits.lua.
    if ns.TickPortraits then ns.TickPortraits() end
    -- Tick de auras (reposicion/opacidad/texto/overlay de cancelar): extraido a Auras.lua.
    if ns.TickAuras then ns.TickAuras() end
    -- Tick de raid (Raid.lua): 40 barras de vida no necesitan 10Hz reales, cada 2do ciclo (~0.2s).
    if tickState.n % 2 == 0 and ns.TickRaid then ns.TickRaid() end
    -- Info bar: refrescar valores ~1/seg.
    if ns.infobar and db.infobar and db.infobar.enabled then
        if GetTime() - (ns.infobar._lastVal or 0) >= 1 then
            ns.infobar._lastVal = GetTime()
            if ns.UpdateInfoBarValues then ns.UpdateInfoBarValues() end
        end
    end
    -- Micro menu: re-afirmar el skin (nunca iconos originales) + ocultar Character.
    -- Throttle a 0.5s: los hooks (Set*Texture/UpdateMicroButtons) ya reaccionan al
    -- instante; el ticker es solo la red de seguridad.
    if tickState.n % 5 == 0 and ns.MM_ReassertArt then ns.MM_ReassertArt() end
    -- RED DE SEGURIDAD (2026-07-19, reportado por el usuario: "hice /reload
    -- en combate y el PlayerFrame/cast nativos no se esconden ni saliendo
    -- de combate"): el camino normal (HideBlizzardFramesNow diferido por
    -- InCombatLockdown -> blizzNeedsApply -> reintento en PLAYER_REGEN_ENABLED)
    -- depende de que ESE evento puntual dispare en el momento correcto -- si
    -- por el timing exacto del reload/combate se pierde esa ventana, nada
    -- vuelve a reintentarlo. Throttle a ~2s (tickState.n % 20, mismo patron
    -- que MM_ReassertArt arriba): si el toggle esta ON, no estamos en
    -- combate, y el PlayerFrame nativo sigue visible, reaplica -- barato
    -- (una lectura de IsShown + posible RegisterStateDriver, nunca mas
    -- seguido que cada 2s) y garantiza que se autocorrija sin importar que
    -- evento se haya perdido.
    if tickState.n % 20 == 0 and db.hideBlizzard and not tickState.inCombat
        and _G.PlayerFrame and _G.PlayerFrame:IsShown() and ns.HideBlizzardFrames then
        ns.HideBlizzardFrames()
    end
    -- RED DE SEGURIDAD (2026-07-19, reportado por el usuario: "las
    -- unitframes/auras de arena dejan una dead zone aunque no aparezcan"):
    -- mismo bug de fondo que el de arriba -- UpdateArenaDrivers (Units.lua)
    -- diferido por InCombatLockdown (u.needsDriver=true) dependia de un
    -- unico reintento en PLAYER_REGEN_ENABLED. Si ese reintento se pierde
    -- (ej. reload en combate), el boton de arena_* queda con el fallback de
    -- creacion (RegisterUnitWatch, basado en existencia CRUDA del token --
    -- "player"/"party1"/"party2" SIEMPRE existen) en vez del driver real
    -- "solo en arena" -- el frame queda clickeable/mouseable fuera de
    -- arena aunque no se vea. Reaplica cada ~2s, fuera de combate --
    -- RegisterStateDriver es barato/idempotente, no tainta.
    if tickState.n % 20 == 0 and not tickState.inCombat and ns.UpdateArenaDrivers then
        ns.UpdateArenaDrivers()
    end
    -- RED DE SEGURIDAD (2026-07-20, reportado por el usuario con capturas de /fstack:
    -- "aun sigue viendo elementos de la barra de arena de blizzard" -- persistia
    -- incluso con hide blizzard activo): Blizzard actualiza estos frames (member
    -- healthBar/castBar/CcRemoverFrame/StealthedUnitFrame/etc.) desde su PROPIO
    -- refresh nativo, disparado por eventos que este addon no controla (y a veces
    -- crea sub-frames NUEVOS recien en ese momento, ej. el icono de sigilo). Se
    -- reaplica cada ~0.3s mientras estas en contenido de arena real (tickState.arenaOK).
    -- CORREGIDO (2026-07-20, "esto fue en una partida nueva despues de hacer reload"):
    -- antes llamaba a ns.HideBlizzardFrames() -- la funcion COMPLETA, que internamente
    -- aborta si InCombatLockdown() es true -- y una partida de arena esta en combate
    -- casi todo el tiempo, asi que esta red de seguridad nunca llegaba a correr de
    -- verdad durante el partido. Se llama a HideArenaFramesNow() DIRECTO (sin ese
    -- guard, ver definicion mas abajo -- es 100% alpha, seguro en combate) y se sube
    -- la frecuencia a cada ~0.3s (tickState.n % 3) ya que es mucho mas barata que la
    -- funcion completa (solo toca los frames de arena, no los ~15 sistemas del resto
    -- de Hide Blizzard).
    if tickState.n % 3 == 0 and db.hideBlizzard and tickState.arenaOK and ns.HideArenaFramesNow then
        ns.HideArenaFramesNow()
    end
    -- Explorer: la ANIMACION corre por frame en explorerDriver (OnUpdate, Explorer.lua);
    -- el ticker solo refresca el estado de combate/target/casteo y enciende/apaga el driver.
    if ns.TickExplorer then ns.TickExplorer() end
end)

-- ==========================================================================
-- MOUSELOOK (global, opcional): clic-derecho + ARRASTRAR rota la camara, incluso
-- empezando sobre un unitframe. Un clic derecho RAPIDO (sin arrastrar) sigue
-- funcionando normal (menu contextual / targetear). Portado de una WeakAura.
-- ==========================================================================
do
    local abs = math.abs
    local ML = { lastX = 0, lastY = 0, inLook = false, foreign = false }
    local f = CreateFrame("Frame")
    -- FIX "Cannot call restricted closure from insecure code" (RestrictedExecution:470,
    -- via MouselookStart): al iniciar mouselook con el RMB aun pulsado, el juego CANCELA
    -- el click pendiente del frame bajo el cursor; si ese frame tiene su click envuelto
    -- por un SecureHandler (WrapScript de otro addon/Blizzard), esa closure RESTRINGIDA
    -- se invoca sincronamente desde nuestra pila INSEGURA → error. Fix: si el RMB bajo
    -- sobre un frame protegido AJENO, ese click le pertenece (no rotamos camara);
    -- NUESTROS unit buttons (marcados _mcfOwnButton, sin WrapScript) siguen permitiendo
    -- el mouselook. pcall de cinturon en Start/Stop.
    local function ForeignProtectedUnderMouse()
        local foci
        if GetMouseFoci then
            local ok, r = pcall(GetMouseFoci)
            if ok then foci = r end
        elseif GetMouseFocus then
            local ok, r = pcall(GetMouseFocus)
            if ok and r then foci = { r } end
        end
        if type(foci) ~= "table" then return false end
        for _, fr in ipairs(foci) do
            if type(fr) == "table" and not fr._mcfOwnButton and fr.IsProtected then
                local ok, prot = pcall(fr.IsProtected, fr)
                if ok and prot then return true end
            end
        end
        return false
    end
    local function OnUpdate()
        if not IsMouseButtonDown(2) then
            f:SetScript("OnUpdate", nil)
            if ML.inLook then pcall(MouselookStop); ML.inLook = false end
            return
        end
        if ML.inLook or ML.foreign then return end
        local x, y = GetCursorPosition()
        if abs(x - ML.lastX) > 1 or abs(y - ML.lastY) > 1 then
            if pcall(MouselookStart) then ML.inLook = true end
        end
    end
    f:SetScript("OnEvent", function(_, event, button)
        if not (db and db.mouselook) then return end
        if event == "GLOBAL_MOUSE_DOWN" and button == "RightButton" then
            ML.inLook = false
            ML.foreign = ForeignProtectedUnderMouse()   -- evaluado UNA vez por click
            ML.lastX, ML.lastY = GetCursorPosition()
            f:SetScript("OnUpdate", OnUpdate)
        elseif event == "GLOBAL_MOUSE_UP" and button == "RightButton" then
            f:SetScript("OnUpdate", nil)
            if ML.inLook then pcall(MouselookStop); ML.inLook = false end
        end
    end)
    f:RegisterEvent("GLOBAL_MOUSE_DOWN")
    f:RegisterEvent("GLOBAL_MOUSE_UP")
end

-- ==========================================================================
-- OCULTAR UNITFRAMES DE BLIZZARD (opcional, global db.hideBlizzard):
-- player/pet/target/tot/boss/party. Solo un state driver de "visibility=hide"
-- (seguro, persistente, NO reparenta, NO toca TUS frames). Al DESACTIVAR hay
-- que /reload (restaurar los eventos nativos no es viable).
--
-- Antes esto TAMBIEN hacia frame:UnregisterAllEvents() + frame:Hide() ademas del state
-- driver. Se saco: en Midnight 12.0.7 aparecieron errores "attempt to compare a secret
-- number value (execution tainted by 'MyCustomFrames')" en TextStatusBar (al abrir el
-- panel de personaje, sobre PlayerFrame) y en CompactUnitFrame_UpdateHealthColor (sobre
-- CompactPartyFrameMember, en GROUP_ROSTER_UPDATE) — ambos frames que este codigo tocaba
-- directamente. RegisterStateDriver por si solo ya es el patron probado y seguro que usa
-- el boss-hider del tracker (nunca causo taint en ese caso); UnregisterAllEvents/Hide
-- ejecutados desde Lua inseguro sobre estos frames PROTEGIDOS (con el sistema de "secret
-- numbers" de este parche) parecen ser lo que tainteaba. El state driver solo alcanza para
-- mantenerlos ocultos.
-- ==========================================================================
local blizzHidden = {}
local blizzNeedsApply = false
-- FIX 2026-07-19 (pedido del usuario, analizando HideUnitFrames/PartyHide):
-- ninguno de esos 2 addons de referencia usa nada mas bulletproof que lo que
-- ya teniamos (RegisterStateDriver/UnregisterAllEvents/SetAlpha) -- el hueco
-- real es que esas tecnicas solo cubren los caminos de re-aparicion YA
-- CONOCIDOS (eventos especificos, el tick de 2s), no CUALQUIER Show() futuro
-- desde cualquier lado. Enganchar hooksecurefunc(frame, "Show", ...) cierra
-- ese hueco: corre SINCRONICAMENTE despues de CUALQUIER Show() (nativo o de
-- otro addon), mismo tick, cero frames visibles. Solo usamos SetAlpha(0) en
-- el hook (nunca Hide()/UnregisterAllEvents() ahi) -- SetAlpha es la tecnica
-- ya probada segura en este archivo (ver HB_HideAlpha, nunca causo el taint
-- de "secret number" que si causaban Hide()/UnregisterAllEvents() llamados
-- inline sobre estos frames protegidos). Guard por frame para no apilar el
-- mismo hook cada vez que HideBlizzardFramesNow corre (se llama seguido).
local blizzShowHooked = setmetatable({}, { __mode = "k" })
-- Guard de reentrancia para el hook de SetAlpha de mas abajo -- por FRAME, no global
-- (2 frames distintos disparando su hook al mismo tiempo no deben pisarse entre si).
local blizzAlphaReentrant = setmetatable({}, { __mode = "k" })
local function HB_HookShowAlpha(frame)
    if not frame or blizzShowHooked[frame] then return end
    blizzShowHooked[frame] = true
    pcall(hooksecurefunc, frame, "Show", function(self) self:SetAlpha(0) end)
    -- FIX (2026-07-20, reportado por el usuario con /fstack: "CompactArenaFrameMemberN
    -- SelectionHighlight" seguia visible en pantalla, confirmado SIN /fstack abierto):
    -- el hook de Show no alcanza si algo anima el alpha DIRECTO (ej. un glow/pulso de
    -- "seleccion" via AnimationGroup, que llama SetAlpha en cada frame sin pasar por
    -- Show()). Se engancha TAMBIEN SetAlpha -- si alguien mas (Blizzard u otro addon)
    -- lo pone en >0, se vuelve a forzar 0 en el mismo tick.
    -- CORREGIDO (2026-07-20, error en juego: "attempt to compare local 'a' (a secret
    -- number value...)"): el valor de alpha que pasa Blizzard internamente es SECRETO
    -- en este cliente -- comparar `a > 0` esta prohibido, ni siquiera envuelto en pcall
    -- sirve para leerlo con seguridad. Se evita LEER el valor por completo: en vez de
    -- decidir segun 'a', se usa un guard de reentrancia por-frame (el propio SetAlpha(0)
    -- de aca abajo re-dispara este mismo hook -- sin el guard seria un loop infinito).
    pcall(hooksecurefunc, frame, "SetAlpha", function(self)
        if blizzAlphaReentrant[self] then return end
        blizzAlphaReentrant[self] = true
        self:SetAlpha(0)
        blizzAlphaReentrant[self] = false
    end)
end
-- FIX (2026-07-19, reportado por el usuario: "el player y cast de Blizzard
-- reaparecieron, sin ningun error"): el guard blizzHidden[frame] hacia que
-- RegisterStateDriver se llamara UNA SOLA VEZ por frame, para siempre -- si
-- ese driver se perdia por CUALQUIER motivo externo (Edit Mode nativo, otro
-- addon, etc.), este codigo nunca lo volvia a intentar aunque siguiera
-- corriendo en cada evento (PLAYER_ENTERING_WORLD/GROUP_ROSTER_UPDATE/etc) --
-- "cree" que ya esta hecho y se lo salta, sin tirar ningun error (por eso el
-- usuario no vio nada). RegisterStateDriver es seguro/barato de llamar de
-- nuevo (no tainta, mismo patron que el resto del addon ya reaplica en cada
-- evento) -- se saca el guard, reasertando SIEMPRE que HideBlizzardFramesNow
-- corre.
local function HB_Handle(frame)
    if not frame then return end
    pcall(function() RegisterStateDriver(frame, "visibility", "hide") end)
    if frame.SetAlpha then frame:SetAlpha(0) end
    HB_HookShowAlpha(frame)
    blizzHidden[frame] = true
end

-- 2026-07-15: FIX "la cast bar nativa aparece un instante al castear". Causa: el
-- RegisterStateDriver de arriba usa una condicion CONSTANTE ("hide") — solo se evalua UNA vez al
-- registrar (y en los re-chequeos globales del motor de state drivers), no INTERCEPTA cada
-- Show() futuro. Como el UnregisterAllEvents general se saco (tainteaba PlayerFrame/party, ver
-- comentario de arriba), la cast bar SIGUE con su evento nativo UNIT_SPELLCAST_START/CHANNEL_START
-- enganchado -> al castear, Blizzard le llama Show() DIRECTO (nada que ver con el state driver) y
-- se ve un flash hasta que el driver la re-oculta. Fix ESPECIFICO solo para cast bars (no para
-- unitframes de vida): SI se puede `UnregisterAllEvents()+Hide()` en estas 3 sin el taint que
-- afectaba a PlayerFrame/CompactPartyFrameMemberN — la cast bar no muestra texto de vida/numeros
-- secretos (el taint reportado era especificamente en TextStatusBar/UpdateHealthColor, funciones
-- que la cast bar nunca ejecuta). Se mantiene TAMBIEN el RegisterStateDriver como red de
-- seguridad (por si algo mas la muestra).
local function HB_HandleCastBar(frame)
    if not frame then return end
    -- Mismo fix que HB_Handle -- sin el guard "ya hecho para siempre", que
    -- impedia reaplicar si el driver se perdia externamente.
    pcall(function()
        frame:UnregisterAllEvents()
        frame:Hide()
        RegisterStateDriver(frame, "visibility", "hide")
    end)
    -- Aca SI podemos enganchar Show->Hide (no solo SetAlpha) -- UnregisterAllEvents/Hide
    -- ya se prueban seguros en estas 3 cast bars especificamente (ver comentario de arriba,
    -- nunca tocan TextStatusBar/UpdateHealthColor). Cierra el mismo hueco que HB_HookShowAlpha
    -- pero con Hide() real en vez de solo alpha, mismo criterio ya usado en este archivo.
    if not blizzShowHooked[frame] then
        blizzShowHooked[frame] = true
        pcall(hooksecurefunc, frame, "Show", function(self) self:Hide() end)
    end
    blizzHidden[frame] = true
end

-- Ocultar por ALPHA (sin Hide/UnregisterAllEvents/RegisterStateDriver): puramente cosmetico,
-- no toca nada que el sistema de "secret numbers" de salud vigile. Tecnica confirmada en el
-- addon de referencia HideUnitFrames para CompactPartyFrame — CLAVE: se aplica al CONTENEDOR
-- (CompactPartyFrame), nunca a los CompactPartyFrameMemberN individuales (esos SI tainteaban,
-- ver comentario abajo). El alpha 0 del contenedor ya oculta a los hijos (miembros + su cast
-- bar embebida) sin llamar nada sobre ellos. No es "una vez" como RegisterStateDriver: hay que
-- reaplicar cada vez por si Blizzard resetea el alpha al reconstruir el frame (por eso se llama
-- sin guard de blizzHidden, desde los mismos puntos de entrada que ya reaplican HideBlizzardFrames).
local function HB_HideAlpha(frame)
    if not frame then return end
    if frame.SetAlpha then frame:SetAlpha(0) end
    HB_HookShowAlpha(frame)
end

-- FIX (2026-07-20, pedido del usuario: "confirma que el 100% de unitframe de arena
-- nativa este ocultada" -- vio un castbar suelto que no llego a identificar con
-- /fstack): en vez de seguir adivinando nombres de campos uno por uno (castBar,
-- healthBar, CcRemoverFrame, TempMaxHealthLoss...), esto oculta el frame Y TODOS
-- sus hijos directos por GetChildren() -- cubre cualquier sub-widget (cast bar
-- incluido) sin necesitar saber su nombre exacto. Regions (texturas/fontstrings,
-- ej. iconos sueltos) NO tienen GetChildren, pero SI heredan el alpha de su frame
-- padre automaticamente -- no hace falta tocarlas aparte. pcall por las dudas
-- (GetChildren puede fallar en frames raros/protegidos de formas inesperadas).
-- FIX (2026-07-20, pedido del usuario: "el outline de seleccion aun sale"): un solo
-- nivel de hijos no alcanzaba -- se agrega un 2do nivel (nietos) para cubrir highlight/
-- selection textures anidadas mas adentro (ej. dentro de la healthBar del member, no
-- directo del member). depth por defecto 2 (frame + hijos + nietos).
local function HB_HideAlphaDeep(frame, depth)
    if not frame then return end
    depth = depth or 2
    HB_HideAlpha(frame)
    if depth <= 0 then return end
    local ok, children = pcall(function() return { frame:GetChildren() } end)
    if not ok then return end
    for _, child in ipairs(children) do
        HB_HideAlphaDeep(child, depth - 1)
    end
end

-- FIX (2026-07-20, reportado por el usuario: "esto fue en una partida nueva despues de
-- hacer reload" -- seguian apareciendo elementos nuevos del arena nativo, ej. un icono
-- de sigilo (StealthedUnitFrameN) que no existia al momento del ultimo hide): el guard
-- `if InCombatLockdown() then return end` de HideBlizzardFramesNow bloqueaba TODA la
-- funcion durante combate -- y una partida de arena esta en combate casi todo el tiempo,
-- asi que la "red de seguridad" periodica (mas abajo en el ticker) nunca llegaba a
-- reaplicar nada nuevo durante el partido real. Se separa el hide de arena a su PROPIA
-- funcion, SIN ese guard -- es 100% alpha (HB_HideAlphaDeep), tecnica ya confirmada
-- segura en combate en todo este archivo, no necesita esperar a salir de combate.
local function HideArenaFramesNow()
    if not (db and db.hideBlizzard) then return end
    HB_HideAlphaDeep(_G.ArenaEnemyFrames)
    HB_HideAlphaDeep(_G.CompactArenaFrame)
    HB_HideAlphaDeep(_G.PreMatchFramesContainer)
    for i = 1, 5 do
        HB_HideAlphaDeep(_G["ArenaEnemyFrame" .. i])          -- alias legacy, nil-safe
        HB_HideAlphaDeep(_G["ArenaEnemyMatchFrame" .. i])
        HB_HideAlphaDeep(_G["CompactArenaFrameMember" .. i])
    end
end
ns.HideArenaFramesNow = HideArenaFramesNow

local function HideBlizzardFramesNow()
    if not (db and db.hideBlizzard) then return end
    if InCombatLockdown() then blizzNeedsApply = true; return end
    blizzNeedsApply = false
    HB_Handle(_G.PlayerFrame)
    HB_Handle(_G.PetFrame)
    HB_Handle(_G.TargetFrame)         -- incluye el ToT (hijo)
    HB_Handle(_G.TargetFrameToT)
    -- Focus (pedido del usuario 2026-07-19, "esta apareciendo, que haga
    -- parte de hide blizzard unitframes" -- ahora que Focus es una unitframe
    -- propia completa igual que Pet, el frame nativo de Blizzard tiene que
    -- ocultarse con el mismo criterio que el resto).
    HB_Handle(_G.FocusFrame)
    HB_HandleCastBar(_G.FocusCastingBarFrame)
    -- Cast bar nativa (el usuario usa la suya). HB_HandleCastBar (no HB_Handle): ademas del
    -- state driver, desengancha sus eventos nativos para que no aparezca un instante al castear.
    HB_HandleCastBar(_G.PlayerCastingBarFrame)
    HB_HandleCastBar(_G.CastingBarFrame)     -- alias legacy
    HB_HandleCastBar(_G.PetCastingBarFrame)
    HB_Handle(_G.BossTargetFrameContainer)
    for i = 1, 8 do HB_Handle(_G["Boss" .. i .. "TargetFrame"]) end
    -- Party: PartyFrame (contenedor moderno, "Raid-Style Party Frames" OFF) via el MISMO
    -- RegisterStateDriver que el resto — nunca aparecio en los taint reportados, y es la tecnica
    -- que usa el addon de referencia PartyHide especificamente para este frame.
    HB_Handle(_G.PartyFrame)
    -- CompactPartyFrame (contenedor, "Raid-Style Party Frames" ON) + PartyMemberFrameN (frames
    -- clasicos, mayormente en desuso): SOLO por alpha, y SOLO el contenedor — nunca los
    -- CompactPartyFrameMemberN individuales (esos SI causaban "attempt to compare local 'oldR'
    -- (a secret number value...)" en CompactUnitFrame_UpdateHealthColor al tocarlos, confirmado
    -- 2 veces en juego incluso con solo RegisterStateDriver). El alpha 0 del contenedor ya oculta
    -- a los miembros + su cast bar embebida sin llamar nada sobre ellos.
    HB_HideAlpha(_G.CompactPartyFrame)
    for i = 1, 5 do HB_HideAlpha(_G["PartyMemberFrame" .. i]) end
    -- CompactRaidFrameManager (pedido del usuario, ventana/fondo del "Raid
    -- Frame Manager" nativo que queda visible en pantalla aunque este vacia,
    -- ver captura de Frame Stack: TOPLEFT UIParent -200,-140).
    HB_HideAlpha(_G.CompactRaidFrameManager)
    -- CompactRaidFrameContainer (las barras REALES de los miembros del raid):
    -- reincorporada 2026-07-20 (pedido del usuario, "recuerda que ya tenemos
    -- raid bars, que se escondan las de blizzard") -- el FIX 2026-07-19 la
    -- habia sacado de esta lista porque en ese momento el addon TODAVIA no
    -- tenia su propio reskin de raid frames (Raid.lua); ahora que si lo
    -- tiene, ocultar la nativa vuelve a tener sentido -- mismo criterio de
    -- alpha (nunca RegisterStateDriver/Hide) que el resto de las barras con
    -- botones/frames protegidos, para no repetir el taint ya documentado.
    HB_HideAlpha(_G.CompactRaidFrameContainer)
    -- REFUERZO (2026-07-20, pedido del usuario: "mas simple, desactiva
    -- completamente el raid de blizzard"): ademas del alpha, se le pide al
    -- PROPIO manager nativo que no muestre raid frames -- es el MISMO flag
    -- que el checkbox "Show Raid Frames" de las opciones de Blizzard, asi
    -- que es la via OFICIAL/soportada (Blizzard maneja su propio
    -- ocultamiento internamente, cero riesgo de taint porque no tocamos
    -- ningun frame protegido nosotros mismos). pcall por las dudas -- este
    -- cliente (Midnight 12.0.7) tiene reportes de otros addons de que
    -- CompactRaidFrameManager puede comportarse raro; si la llamada fallara
    -- el alpha-hide de arriba sigue cubriendo igual.
    pcall(function()
        if CompactRaidFrameManager_SetSetting then
            CompactRaidFrameManager_SetSetting("IsShown", "0")
        end
    end)
    -- OverrideActionBar (pedido del usuario 2026-07-20): la barra nativa que
    -- aparece en vehiculos/monturas con habilidades/algunos items de racial.
    -- Por ALPHA (no HB_Handle/RegisterStateDriver): tiene botones de accion
    -- PROTEGIDOS, tocar su visibilidad por state driver arriesga el mismo
    -- taint que CompactPartyFrame -- el alpha 0 la oculta sin tocar nada
    -- protegido, mismo criterio que el resto de las barras con botones reales.
    HB_HideAlpha(_G.OverrideActionBar)
    -- Arena enemy frames nativos (pedido del usuario 2026-07-20: "las
    -- unitframe de arenas de blizzard por defecto estan saliendo, desactivalas"
    -- -- este addon no tiene un reskin propio de arena todavia, pero el
    -- usuario ya tiene su propia unitframe de "arena enemy" via Units.lua
    -- (ver ARENA_KEYS) por lo que la nativa debe ocultarse igual que
    -- party/raid). SOLO por alpha, SOLO el contenedor (ArenaEnemyFrames):
    -- mismo criterio que CompactPartyFrame -- los ArenaEnemyFrame1..5
    -- individuales tienen botones/barras protegidos, nunca tocarlos directo.
    -- FIX (2026-07-20, pedido del usuario: "confirma que el 100% de unitframe de arena
    -- nativa este ocultada" -- reporto un castbar suelto que no llego a identificar con
    -- /fstack, despues de ya haber agregado varios campos a mano uno por uno):
    -- reemplazado por HB_HideAlphaDeep (oculta el frame Y TODOS sus hijos directos por
    -- GetChildren, ver definicion) en vez de seguir adivinando nombres de campos --
    -- cubre castBar/healthBar/powerBar/CcRemoverFrame/TempMaxHealthLoss/PetFrame/lo
    -- que sea, existente o futuro, sin depender de conocer el nombre exacto. Aplicado
    -- a los 2 contenedores (ArenaEnemyFrames, CompactArenaFrame, PreMatchFramesContainer)
    -- Y a cada member individual (los hijos DIRECTOS de un member, como su cast bar, no
    -- quedan cubiertos solo con ocultar el contenedor de arriba si Blizzard les toca el
    -- alpha aparte en su propio refresh nativo).
    HideArenaFramesNow()
end
-- GROUP_ROSTER_UPDATE dispara TANTO nuestro handler como el refresh nativo de
-- CompactPartyFrame/CompactRaidFrameContainer (CompactUnitFrame_UpdateAll -> UpdateHealthColor,
-- que compara "secret numbers"). Tocar esos frames (UnregisterAllEvents/Hide/RegisterStateDriver)
-- en el MISMO tick que el refresh nativo tainta esa comparacion ("attempt to compare local
-- 'oldR' (a secret number value...), while execution tainted by 'MyCustomFrames'"). Diferir un
-- frame con C_Timer.After(0, ...) alcanza para que nuestro toque nunca coincida con el pase de
-- Blizzard sobre esos mismos frames, sin cambiar nada del comportamiento (side-effects idempotentes
-- via blizzHidden). Confirmado por el error reportado en juego con CompactPartyFrameMember.
local function HideBlizzardFrames()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, HideBlizzardFramesNow)
    else
        HideBlizzardFramesNow()
    end
end
ns.HideBlizzardFrames = HideBlizzardFrames
ns.BlizzardNeedsApply = function() return blizzNeedsApply end
