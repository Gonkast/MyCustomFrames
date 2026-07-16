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
local AURA_BORDER     = A .. "actionbutton-border square.tga"           -- borde de auras
local AURA_PREVIEW_ICON = "Interface\\Icons\\Spell_Nature_Rejuvenation"  -- icono de muestra

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
    FONT  = A .. "Lato-Bold.ttf",
}

local GOLD = { r = 1, g = 0.882, b = 0.608 }   -- FFE19B (color de texto por defecto)

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
    { key = "party5", unit = "party5", label = "P5" },
}
ns.UNITS = UNITS

local function HasNameByKey(key)
    return key ~= "focus" and key ~= "playerpower" and key ~= "targetpower"
end

local function CageDefault(key)
    if key == "target" then return CAGE_TARGET end
    if key == "player" then return CAGE_PLAYER end
    if key == "playerpower" or key == "targetpower" then return CAGE_POWER end
    if key == "pet" or key == "targettarget" then return CAGE_PETTOT end
    if key:sub(1, 4) == "boss" then return CAGE_BOSS end
    if key:sub(1, 5) == "party" then return CAGE_PETTOT end
    return ""
end

local function DefaultsFor(key)
    local defY = {
        player = -150, target = -180, targettarget = -210, pet = -240, focus = -270,
        playerpower = -330, targetpower = -360,
        boss1 = -150, boss2 = -180, boss3 = -210, boss4 = -240, boss5 = -270,
        party1 = -150, party2 = -180, party3 = -210, party4 = -240, party5 = -270,
    }
    local power = (key == "playerpower" or key == "targetpower")
    local boss  = (key:sub(1, 4) == "boss")
    local tex
    if power then tex = POWER_TEXTURE
    elseif boss then tex = BOSS_TEXTURE
    elseif key == "focus" then tex = ""
    else tex = TEXTURE_DEFAULT end
    local wantValue = (not power) and (key ~= "focus")
    return {
        anchorFrame = "", point = "CENTER", relativePoint = "CENTER",
        offsetX = 0, offsetY = defY[key] or -150, strata = "MEDIUM",
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
        -- Aviso de vida baja (tinte rojo que pulsa cuando HP% < umbral). Opt-in; usa el
        -- porcentaje LEGIBLE de la API (secret-safe). Util sobre todo en el player.
        lowHealthWarn = false, lowHealthThreshold = 35,
        lowHealthColor = { r = 1, g = 0.1, b = 0.1 },
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
    { key = "portrait_player", unit = "player", label = "Player", kind = "model",
      features = { rest = true, faction = true, combat = true, dualPos = true, leader = true, raidTarget = true } },
    { key = "portrait_pet", unit = "pet", label = "Pet", kind = "model",
      features = { dualPos = true, leader = true, raidTarget = true }, requireExists = true },
    { key = "portrait_focus", unit = "focus", label = "Focus", kind = "model",
      features = { dualPos = true, leader = true, raidTarget = true }, requireExists = true },
    { key = "portrait_target", unit = "target", label = "Target", kind = "model",
      features = { leader = true, raidTarget = true }, requireExists = true, deadOnly = true },
    { key = "portrait_tot", unit = "targettarget", label = "ToT", kind = "icon",
      features = { leader = true, raidTarget = true }, requireExists = true },
    { key = "portrait_party1", unit = "party1", label = "Party1", kind = "icon",
      features = { raidTarget = true, roleLeader = true }, requireExists = true },
    { key = "portrait_party2", unit = "party2", label = "Party2", kind = "icon",
      features = { raidTarget = true, roleLeader = true }, requireExists = true },
    { key = "portrait_party3", unit = "party3", label = "Party3", kind = "icon",
      features = { raidTarget = true, roleLeader = true }, requireExists = true },
    { key = "portrait_party4", unit = "party4", label = "Party4", kind = "icon",
      features = { raidTarget = true, roleLeader = true }, requireExists = true },
    { key = "portrait_party5", unit = "party5", label = "Party5", kind = "icon",
      features = { raidTarget = true, roleLeader = true }, requireExists = true },
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
    elseif key == "portrait_focus" then
        d.size = 64; d.cageTexture = PORTRAIT_PETCASE
        d.centerX, d.centerY = -150, 0
        d.altX, d.altY = -380, -200
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
local infobar          -- frame del info bar (unico)
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
local function GetMoveGroup(key)
    if not db then return nil end
    if key:sub(1, 5) == "party" and db.groupMoveParty then return PARTY_KEYS end
    if key:sub(1, 4) == "boss" and db.groupMoveBoss then return BOSS_KEYS end
    return nil
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

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

-- Snapshot POR TICK de estados seguros compartidos (solo booleanos, jamas secretos):
-- combate/resting se consultaban decenas de veces por tick con la misma respuesta.
-- Lo rellena el ticker principal al inicio de cada pasada; fuera del ticker puede
-- estar desfasado como mucho 0.1s (irrelevante para alphas/badges).
local tickState = {}

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

local function DeepCopy(t)
    if type(t) ~= "table" then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = DeepCopy(v) end
    return r
end
ns.DeepCopy = DeepCopy

ns.IsUnlocked = function() return unlocked end
ns.GetDB = function() return db end

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
ns.CurrentProfile = function()
    if ns.currentEdit == INFOBAR_KEY then return db.infobar end
    if ns.currentEdit == MICROMENU_KEY then return db.micromenu end
    if ns.currentEdit == CHATBUBBLE_KEY then return db.chatbubble end
    if ns.currentEdit == TRACKER_KEY then return db.tracker end
    if ns.currentEdit == GLOW_KEY then return db.glow end
    if AURA_SET[ns.currentEdit] then return db.auras[ns.currentEdit] end
    if PORTRAIT_SET[ns.currentEdit] then return db.portraits[ns.currentEdit] end
    return db.units[ns.currentEdit]
end

-- ==========================================================================
-- LOGICA POR UNIDAD
-- ==========================================================================
local function P(u) return db.units[u.key] end

local function UnitColor(u)
    local p = P(u)
    if p.useBarColor and p.barColor then
        return p.barColor.r, p.barColor.g, p.barColor.b
    end
    -- (Ruta caliente — se llama por unidad por tick via UnitUpdateColor: pcall directo
    -- sin closures; issecretvalue ANTES de testear/indexar con valores de la API.)
    if u.kind == "power" then
        local okP, pType, token = pcall(UnitPowerType, u.unit)
        if okP and not (issecretvalue and (issecretvalue(pType) or issecretvalue(token))) then
            local col = (token and POWER_COLORS[token]) or (token and PowerBarColor[token])
                or (pType and PowerBarColor[pType])
            if col then return col.r, col.g, col.b end
        end
        return 0.18, 0.34, 0.98
    end
    if u.fixedColor then return u.fixedColor.r, u.fixedColor.g, u.fixedColor.b end
    -- Color de clase si la unidad tiene una clase valida (jugador o NPC con clase).
    do
        local okC, _, class = pcall(UnitClass, u.unit)
        if okC and type(class) == "string" and not (issecretvalue and issecretvalue(class)) then
            local c = RAID_CLASS_COLORS[class]
            if c then return c.r, c.g, c.b end
        end
    end
    local reaction = safeVal(UnitReaction, u.unit, "player")
    local col = p.colorFriendly
    if type(reaction) == "number" then
        if reaction <= 3 then col = p.colorHostile
        elseif reaction == 4 then col = p.colorNeutral
        else col = p.colorFriendly end
    end
    return col.r, col.g, col.b
end

local function GetHealthPercent(unit)
    local pct
    if CurveConstants and CurveConstants.ScaleTo100 then
        pct = UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
    else
        pct = UnitHealthPercent(unit)
    end
    local readable = (type(pct) == "number") and not (issecretvalue and issecretvalue(pct))
    return pct, readable
end

local function UnitUpdateText(u)
    local p, hpText = P(u), u.hpText
    if not p.showText then hpText:SetText("") return end

    -- (Ruta caliente: pcall(fn, args) directo, SIN closures — ver nota sobre safeBool.
    -- Toda comparacion/aritmetica sobre valores potencialmente secretos va precedida
    -- de issecretvalue, o dentro de un pcall.)
    if u.kind == "power" then
        if UnitPowerPercent then
            local okT, pType = pcall(UnitPowerType, u.unit)
            if okT then
                local ok, pct
                if CurveConstants and CurveConstants.ScaleTo100 then
                    ok, pct = pcall(UnitPowerPercent, u.unit, pType, true, CurveConstants.ScaleTo100)
                else
                    ok, pct = pcall(UnitPowerPercent, u.unit, pType)
                end
                -- pct puede ser secreto: comparar solo con nil; SetFormattedText formatea en C.
                if ok and pct ~= nil and pcall(hpText.SetFormattedText, hpText, "%.0f%%", pct) then return end
            end
        end
        local okC, cur = pcall(UnitPower, u.unit)
        local okM, max = pcall(UnitPowerMax, u.unit)
        if okC and okM and type(cur) == "number" and type(max) == "number"
           and not (issecretvalue and (issecretvalue(cur) or issecretvalue(max)))
           and max > 0 then
            hpText:SetFormattedText("%.0f%%", cur / max * 100)
            return
        end
        hpText:SetText("")
        return
    end

    local dead = safeBool(UnitIsDeadOrGhost, u.unit)
    if dead then hpText:SetText("") return end

    if UnitHealthPercent then
        local okH, readablePct, readable = pcall(GetHealthPercent, u.unit)
        if not okH then readablePct, readable = nil, false end
        -- Color del texto: rojo (lowHealthColor) si la vida esta bajo el umbral configurado
        -- (IGNORA el color custom); si no, el color personalizado (o GOLD). Se re-evalua cada tick.
        -- SECRET-SAFE: usa la fraccion LEGIBLE del relleno (u.bar._target, con fallback por
        -- geometria del ancho del relleno) — NO readablePct, que puede ser SECRETO en el player.
        local frac = u.bar._readable and u.bar._target
        local low = p.lowHealthWarn and frac and frac < ((p.lowHealthThreshold or 35) / 100)
        local col = (low and (p.lowHealthColor or GOLD)) or (p.useHealthColor and p.healthColor or GOLD)
        -- Dedupe: SetTextColor solo si el color realmente cambio (numeros propios, no secretos).
        if col.r ~= u._hpR or col.g ~= u._hpG or col.b ~= u._hpB then
            u._hpR, u._hpG, u._hpB = col.r, col.g, col.b
            hpText:SetTextColor(col.r, col.g, col.b, 1)
        end
        if readable then
            if p.showValue and type(AbbreviateNumbers) == "function" then
                local okA, abbr = pcall(AbbreviateNumbers, UnitHealth(u.unit))
                if okA and abbr ~= nil
                   and pcall(hpText.SetFormattedText, hpText, "%.0f%% | %s", readablePct, abbr) then return end
            end
            hpText:SetFormattedText("%.0f%%", readablePct)
            return
        end
        -- pct secreto: mostrable via SetFormattedText (formatea en C), nunca operar con el.
        local okP, pct = pcall(GetHealthPercent, u.unit)
        if okP and pct ~= nil then
            if p.showValue and type(AbbreviateNumbers) == "function" then
                local okA, abbr = pcall(AbbreviateNumbers, UnitHealth(u.unit))
                if okA and abbr ~= nil
                   and pcall(hpText.SetFormattedText, hpText, "%.0f%% | %s", pct, abbr) then return end
            end
            if pcall(hpText.SetFormattedText, hpText, "%.0f%%", pct) then return end
        end
    end
    if type(AbbreviateNumbers) == "function" then
        local ok, formatted = pcall(AbbreviateNumbers, UnitHealth(u.unit))
        if ok and formatted ~= nil then hpText:SetText(formatted) return end
    end
    hpText:SetText("")
end

-- Nombre (+nivel) y texto de hechizo (fontstrings independientes).
local function UnitUpdateName(u)
    if not u.nameText then return end
    local p = P(u)
    local nameFS, spellFS = u.nameText, u.spellText

    -- No mostrar (oculto / no existe / muerto).
    local hide = (not p.showName) or (not UnitExists(u.unit))
    if not hide then
        if safeBool(UnitIsDeadOrGhost, u.unit) then hide = true end
    end
    if hide then
        nameFS:SetAlpha(0); nameFS:SetText("")
        if spellFS then spellFS:SetAlpha(0); spellFS:SetText("") end
        return
    end

    -- Casteo? (pcall directo, sin closures; el nombre puede ser SECRETO: solo
    -- comparar con nil.)
    local okCast, castName = pcall(UnitCastingInfo, u.unit)
    if not okCast then castName = nil end
    if castName == nil then
        local okCh, chName = pcall(UnitChannelInfo, u.unit)
        if okCh then castName = chName end
    end

    if castName ~= nil and p.showSpell and spellFS then
        -- Hechizo reemplaza al nombre.
        nameFS:SetAlpha(0)
        -- Limite de caracteres SOLO si el nombre es legible (no secreto): comparar
        -- longitud/sub de un secreto tainta. Los secretos se pasan tal cual (SetText
        -- en C) y el wrap + max 2 lineas los recorta visualmente.
        local s = castName
        if type(s) == "string" and not (issecretvalue and issecretvalue(s))
           and p.spellMaxLength and p.spellMaxLength > 0 and #s > p.spellMaxLength then
            s = s:sub(1, p.spellMaxLength) .. ".."
        end
        pcall(spellFS.SetFormattedText, spellFS, "%s", s)
        if u._sX ~= p.spellOffsetX or u._sY ~= p.spellOffsetY then
            u._sX, u._sY = p.spellOffsetX, p.spellOffsetY
            spellFS:ClearAllPoints()
            spellFS:SetPoint("CENTER", u.bar, "CENTER", p.spellOffsetX, p.spellOffsetY)
        end
        spellFS:SetAlpha(p.spellAlpha)
        return
    end
    if spellFS then spellFS:SetAlpha(0) end

    -- Nombre + nivel (pcall directo; issecretvalue ANTES de cualquier comparacion).
    local nameReadable, nameStr = false, nil
    local okN, rawName = pcall(UnitName, u.unit)
    if okN and type(rawName) == "string" and not (issecretvalue and issecretvalue(rawName)) then
        nameReadable, nameStr = true, rawName
    end
    local lvlReadable, lvl = false, nil
    local okL, rawLvl = pcall(UnitLevel, u.unit)
    if okL and type(rawLvl) == "number" and not (issecretvalue and issecretvalue(rawLvl)) then
        lvlReadable, lvl = true, rawLvl
    end
    if nameReadable then
        if p.nameMaxLength and p.nameMaxLength > 0 and #nameStr > p.nameMaxLength then
            nameStr = nameStr:sub(1, p.nameMaxLength) .. ".."
        end
        if lvlReadable and p.nameLevelColor then
            local col
            if lvl <= 0      then col = "|cFFFF0000"
            elseif lvl <= 20 then col = "|cFF00FF00"
            elseif lvl <= 40 then col = "|cFF00FFFF"
            elseif lvl <= 60 then col = "|cFFFFFF00"
            else col = "|cFFFFA500" end
            local lvlText = (lvl > 0) and tostring(lvl) or "??"
            nameFS:SetText(string.format("%s %s%s|r", nameStr, col, lvlText))
        elseif lvlReadable and lvl > 0 then
            nameFS:SetText(string.format("%s %d", nameStr, lvl))
        else
            nameFS:SetText(nameStr)
        end
    else
        -- Nombre SECRETO: pasarlo tal cual a SetFormattedText (formatea en C). rawName
        -- solo se usa si el pcall de UnitName tuvo exito (si fallo, seria el mensaje
        -- de error). Comparar el secreto solo con nil.
        local okF = false
        if okN and rawName ~= nil then
            if lvlReadable and lvl > 0 then
                okF = pcall(nameFS.SetFormattedText, nameFS, "%s  %d", rawName, lvl)
            end
            if not okF then pcall(nameFS.SetFormattedText, nameFS, "%s", rawName) end
        end
    end

    if u._nX ~= p.nameOffsetX or u._nY ~= p.nameOffsetY then
        u._nX, u._nY = p.nameOffsetX, p.nameOffsetY
        nameFS:ClearAllPoints()
        nameFS:SetPoint("CENTER", u.bar, "CENTER", p.nameOffsetX, p.nameOffsetY)
    end

    -- UnitCanAttack: UNA consulta por tick (antes se hacia dos veces: autoHide + ancho).
    local atk = safeBool(UnitCanAttack, "player", u.unit)
    if not p.nameAutoHide then
        nameFS:SetAlpha(p.nameAlpha)
    else
        nameFS:SetAlpha((tickState.inCombat or atk or u.isMouseOver) and p.nameAlpha or 0)
    end

    local w = p.nameDynamicWidth and (atk and 111 or 200) or 1000
    if u._nW ~= w then u._nW = w; nameFS:SetWidth(w) end
end

local function UnitTextVisibility(u)
    local p, hpText = P(u), u.hpText
    -- BUG FIX (2026-07-15): esta rama ignoraba "Hide text" (db.lockHide.text) por completo y
    -- SIEMPRE reponia el alpha visible — como el OnEnter/OnLeave de hover llaman esta funcion
    -- tambien en preview, pasar el mouse por encima del frame pisaba el toggle de vuelta a
    -- visible (por eso el toggle "parecia no hacer nada" persistente).
    if unlocked then
        local lh = db and db.lockHide
        hpText:SetAlpha((lh and lh.text) and 0 or p.textAlpha)
        return
    end
    if not p.showText then hpText:SetAlpha(0) return end
    if not p.textAutoHide then hpText:SetAlpha(p.textAlpha) return end
    -- Hostil: la unidad del PROPIO frame es atacable (target/boss/etc) O hay un TARGET
    -- hostil seleccionado en general (para que el frame del player tambien revele su texto
    -- cuando estas encarando un enemigo, no solo en combate real; antes solo miraba u.unit,
    -- que para el player mismo nunca es "atacable" -> el texto nunca se mostraba con hostiles).
    local hostile = safeBool(UnitExists, u.unit) and safeBool(UnitCanAttack, "player", u.unit)
    local hostileTarget = safeBool(UnitExists, "target") and safeBool(UnitCanAttack, "player", "target")
    -- Vida baja: usa la fraccion LEGIBLE del relleno (secret-safe, misma fuente que lowHealthWarn).
    local frac = u.bar._readable and u.bar._target
    local lowHP = p.textLowHealthShow and frac and frac < ((p.textLowHealthThreshold or 60) / 100)
    hpText:SetAlpha((tickState.inCombat or hostile or hostileTarget or u.isMouseOver or lowHP) and p.textAlpha or 0)
end

-- Relleno MANUAL estilo WeakAuras: la textura queda anclada a un lado y se
-- recorta (SetWidth + SetTexCoord); asi NO se desliza al invertir. Requiere la
-- fraccion (0..1) como numero legible. container = el frame de la barra.
local function RenderManualFill(tex, container, frac, reverse)
    frac = clamp(frac or 0, 0, 1)
    if frac <= 0 then tex:Hide() return end
    tex:Show()
    local w = math.max((container:GetWidth() or 0) * frac, 0.1)
    tex:ClearAllPoints()
    if reverse then
        tex:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
        tex:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
        tex:SetWidth(w)
        tex:SetTexCoord(1 - frac, 1, 0, 1)
    else
        tex:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        tex:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
        tex:SetWidth(w)
        tex:SetTexCoord(0, frac, 0, 1)
    end
end

-- Fraccion 0..1 de la unidad + si es LEGIBLE (no secreta).
-- 1) % de la API. 2) geometria renderizada del StatusBar (frame anterior).
local function GetUnitFraction(u)
    -- (Ruta caliente: pcall directo sin closures; issecretvalue ANTES de comparar/operar.)
    if u.kind == "power" then
        local okC, cur = pcall(UnitPower, u.unit)
        local okM, max = pcall(UnitPowerMax, u.unit)
        if okC and okM and type(cur) == "number" and type(max) == "number"
           and not (issecretvalue and (issecretvalue(cur) or issecretvalue(max)))
           and max > 0 then
            return cur / max, true
        end
    else
        local pct, r = GetHealthPercent(u.unit)
        if r then return pct / 100, true end
    end
    -- Fallback: ancho renderizado del relleno nativo / ancho de la barra.
    local tex = u.bar:GetStatusBarTexture()
    if tex then
        local okF, fw = pcall(tex.GetWidth, tex)
        local okB, bw = pcall(u.bar.GetWidth, u.bar)
        if okF and okB and type(fw) == "number" and type(bw) == "number"
           and not (issecretvalue and (issecretvalue(fw) or issecretvalue(bw)))
           and bw > 0 then
            return clamp(fw / bw, 0, 1), true
        end
    end
    return 0, false
end

local function UnitUpdateBar(u)
    local p = P(u)

    -- Preview (modo edicion): relleno lleno + textos de muestra.
    if unlocked then
        u.bar:GetStatusBarTexture():SetAlpha(0)
        if p.texture and p.texture ~= "" then
            RenderManualFill(u.fillTex, u.bar, 1, p.reverseFill)
        else
            u.fillTex:Hide()
        end
        -- "Hide text" (db.lockHide.text, Editing > Hide in preview): oculta TODO el texto
        -- (nombre + hechizo + vida %/numero) SOLO en preview, sin importar el showName/showSpell
        -- de cada unidad. Reemplaza al viejo toggle "Health" (2026-07-15) que solo tapaba
        -- hpText y encima no persistia: UnitTextVisibility pisaba el alpha en cada hover del
        -- mouse (rama `unlocked` vieja ignoraba lockHide por completo, ver fix mas abajo).
        local lh = db.lockHide or {}
        local hideText = lh.text
        if u.hpText then
            u.hpText:SetText(u.kind == "power" and "100%" or "100% | 1m")
            u.hpText:SetAlpha(hideText and 0 or p.textAlpha)
        end
        if u.nameText then
            u.nameText:SetText(u.label .. " 60")
            u.nameText:SetAlpha(hideText and 0 or ((p.showName and p.nameAlpha) or 0))
            u.nameText:ClearAllPoints()
            u.nameText:SetPoint("CENTER", u.bar, "CENTER", p.nameOffsetX, p.nameOffsetY)
            u.nameText:SetWidth(p.nameDynamicWidth and 200 or 1000)
            u._nX, u._nW = nil, nil   -- el preview anclo por su cuenta: invalidar dedupe
        end
        if u.spellText then
            u.spellText:SetText("Hechizo")
            u.spellText:SetAlpha(hideText and 0 or (p.showSpell and p.spellAlpha or 0))
            u.spellText:ClearAllPoints()
            u.spellText:SetPoint("CENTER", u.bar, "CENTER", p.spellOffsetX, p.spellOffsetY)
            u._sX = nil               -- idem
        end
        return
    end

    -- Rellena el StatusBar nativo SIEMPRE (secret-safe y para leer geometria).
    u.bar:SetReverseFill(false)
    if u.kind == "power" then
        u.bar:SetMinMaxValues(0, UnitPowerMax(u.unit)); u.bar:SetValue(UnitPower(u.unit))
    else
        u.bar:SetMinMaxValues(0, UnitHealthMax(u.unit)); u.bar:SetValue(UnitHealth(u.unit))
    end

    if not (p.texture and p.texture ~= "") then
        -- Sin textura (focus): sin relleno.
        u.fillTex:Hide()
        u.bar:GetStatusBarTexture():SetAlpha(0)
        u.bar._readable = false
    else
        local frac, readable = GetUnitFraction(u)
        if readable then
            -- Relleno MANUAL (no desliza, orientaciones correctas, permite smooth).
            u.bar:GetStatusBarTexture():SetAlpha(0)
            u.bar._readable = true
            u.bar._target = frac
            if u.bar._cur == nil or not p.smooth then u.bar._cur = frac end
            RenderManualFill(u.fillTex, u.bar, u.bar._cur, p.reverseFill)
        else
            -- Secreto e ilegible: StatusBar nativo (normal OK; inverse puede deslizar).
            u.bar._readable = false
            u.fillTex:Hide()
            u.bar:GetStatusBarTexture():SetAlpha(1)
            u.bar:SetReverseFill(p.reverseFill)
        end
    end
    UnitUpdateText(u)
    UnitUpdateName(u)
end

local function UnitUpdateMount(u)
    if unlocked then u.button:SetAlpha(1) return end
    local p = P(u)
    if p.hideWhenMounted and IsMounted() then u.button:SetAlpha(0) return end
    -- Si el Explorer gestiona este elemento, el alpha es suyo (fade por frame):
    -- resetearlo a 1 aqui cada tick produce un parpadeo visible.
    if db.explorerEnabled ~= false and db.explorer and db.explorer[u.key] then return end
    u.button:SetAlpha(1)
end

-- Oculta el cage del unitframe si la unidad esta muerta (opcion cageHideDead).
local function UnitUpdateDeadCage(u)
    if not u.cage then return end
    local p = P(u)
    if not (p.cageHideDead and p.cageTexture and p.cageTexture ~= "") then return end
    local dead = safeBool(UnitExists, u.unit) and safeBool(UnitIsDeadOrGhost, u.unit)
    u.cage:SetShown(not dead)
end

-- Highlight de "unidad seleccionada": muestra el borde-highlight si la unidad de este
-- frame es tu TARGET actual. En preview (unlocked) siempre visible para poder editarlo.
-- UnitIsUnit devuelve booleano (no secreto) -> seguro. Latido opcional (highlightGlow).
local function UnitUpdateHighlight(u)
    local hl = u.highlight
    if not hl then return end
    -- El focus NO usa el highlight del boton (quedaria DELANTE del retrato); su highlight
    -- se dibuja en el propio portrait_focus, DETRAS de todos sus elementos. Ver
    -- UpdateFocusPortraitHighlight. Aqui lo mantenemos oculto.
    if u.key == "focus" then hl:Hide(); if u.highlightAnim then u.highlightAnim:Stop() end return end
    local p = P(u)
    if not p.showHighlight then
        hl:Hide()
        if u.highlightAnim then u.highlightAnim:Stop() end
        return
    end
    local isTarget
    if unlocked then
        isTarget = true
    else
        isTarget = safeBool(UnitExists, "target") and safeBool(UnitIsUnit, u.unit, "target")
    end
    if isTarget then
        hl:Show()
        if p.highlightGlow and u.highlightAnim then
            if not u.highlightAnim:IsPlaying() then u.highlightAnim:Play() end
        elseif u.highlightAnim then
            u.highlightAnim:Stop()
            hl:SetAlpha(p.highlightAlpha or 1)
        end
    else
        hl:Hide()
        if u.highlightAnim then u.highlightAnim:Stop() end
    end
end

-- (El aviso de vida baja ya NO es un overlay rojo: ahora el TEXTO de vida se colorea con
-- lowHealthColor bajo el umbral, en UnitUpdateText. Ver #6.)

local function TargetReactionLE4()
    local ok, reaction = pcall(UnitReaction, "target", "player")
    return (ok and type(reaction) == "number"
        and not (issecretvalue and issecretvalue(reaction))
        and reaction <= 4) or false
end

local function PowerShouldShow(u)
    if u.key == "playerpower" then
        -- Montado (con el toggle activo): ocultar SIEMPRE, ANTES de cualquier otra
        -- condicion. Antes esto solo se aplicaba despues via UnitUpdateMount (alpha=0),
        -- pero SetShown(true) ya se habia disparado este mismo tick si habia target
        -- valido -> el Show() dispara el fade-in y se ve parpadear un instante antes
        -- de que el alpha=0 lo tape. Cortando aca no llega a hacer Show() nunca.
        if P(u).hideWhenMounted and IsMounted() then return false end
        -- Muerto: ocultar SIEMPRE la power bar del player (no solo el cage).
        if safeBool(UnitIsDeadOrGhost, "player") then return false end
        if tickState.inCombat then return true end
        if not UnitExists("target") then return false end
        return TargetReactionLE4()
    elseif u.key == "targetpower" then
        if not UnitExists("target") then return false end
        -- Si me tengo a mi mismo de target y estoy muerto: ocultar (bar + cage).
        if safeBool(UnitIsUnit, "target", "player") then
            if safeBool(UnitIsDeadOrGhost, "player") then return false end
        end
        return safeBool(UnitIsPlayer, "target")
    end
    return UnitExists(u.unit)
end

-- (Re)aplica el color de la barra (clase/reaccion/poder/override manual). Se llama
-- tambien en el ticker: el color de clase de party llega DESPUES de crear el frame,
-- asi que si solo se aplicara en el refresh completo, el color quedaria desactualizado.
local function UnitUpdateColor(u)
    local p = P(u)
    local hasTex = (p.texture and p.texture ~= "") and true or false
    local r, g, b = UnitColor(u)
    u.bar:SetStatusBarColor(r, g, b, hasTex and p.barAlpha or 0)
    u.fillTex:SetVertexColor(r, g, b, hasTex and p.barAlpha or 0)
end

local function UnitApplyLayout(u)
    local p = P(u)
    if u.kind ~= "power" and InCombatLockdown() then u.needsLayout = true return end
    CompensateScale(p, "unit")   -- B3: reancla offsets si la escala cambio (sin desplazar)
    local button = u.button
    button:SetSize(p.width, p.height)
    local parent = _G[p.anchorFrame]
    if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
    button:ClearAllPoints()
    button:SetPoint(p.point, parent, p.relativePoint, p.offsetX, p.offsetY)
    button:SetFrameStrata(p.strata)
    button:SetScale(p.scale or 1)   -- escala general (multiplica sobre width/height, NO los altera)
    -- Area de CLICK independiente de la barra via SetHitRectInsets: no cambia la
    -- geometria del frame seguro (sin taint) y admite insets negativos (agrandar).
    -- En preview se limpia para poder arrastrar sobre todo el recuadro.
    if u.kind ~= "power" then
        local bw = (p.btnWidth and p.btnWidth > 0) and p.btnWidth or p.width
        local bh = (p.btnHeight and p.btnHeight > 0) and p.btnHeight or p.height
        local ox, oy = p.btnOffsetX or 0, p.btnOffsetY or 0
        if unlocked or (bw == p.width and bh == p.height and ox == 0 and oy == 0) then
            button:SetHitRectInsets(0, 0, 0, 0)
        else
            local ix, iy = (p.width - bw) / 2, (p.height - bh) / 2
            button:SetHitRectInsets(ix + ox, ix - ox, iy - oy, iy + oy)
        end
        -- B4: preview del area de click (naranja), solo en preview y con el toggle activo.
        if u.hitPreview then
            local show = unlocked and db and db.previewSecureButton
            if show then
                u.hitPreview:ClearAllPoints()
                u.hitPreview:SetPoint("CENTER", button, "CENTER", ox, oy)
                u.hitPreview:SetSize(math.max(bw, 4), math.max(bh, 4))
            end
            u.hitPreview:SetShown(show and true or false)
        end
        -- B4: outline con tamaño propio + ocultar nombre (por unidad o por lockHide.names).
        ApplyOutline(u.editBG, button, p.outlineW, p.outlineH,
            p.outlineHideName or (db.lockHide and db.lockHide.names))
    end
    u.needsLayout = nil
end

local function UnitApplyAppearance(u)
    local p = P(u)
    local hasTex = (p.texture and p.texture ~= "") and true or false
    local barTex = hasTex and p.texture or BLANK_TEXTURE
    -- Texturas (StatusBar nativo = fallback secreto; fillTex = relleno manual legible).
    u.bar:SetStatusBarTexture(barTex)
    u.fillTex:SetTexture(barTex)
    UnitUpdateColor(u)

    u.bg:SetColorTexture(0, 0, 0, p.bgAlpha)
    u.bg:SetShown(p.showBackground)

    if u.cage then
        if p.cageTexture and p.cageTexture ~= "" then
            u.cage:SetTexture(p.cageTexture)
            u.cage:SetSize(p.cageWidth, p.cageHeight)
            u.cage:ClearAllPoints()
            u.cage:SetPoint("CENTER", u.button, "CENTER", p.cageOffsetX, p.cageOffsetY)
            u.cage:SetAlpha(p.cageAlpha)
            u.cage:Show()
        else
            u.cage:Hide()
        end
    end

    -- Texto vida (fuente + color).
    u.hpText:SetFont("Fonts\\FRIZQT__.TTF", p.fontSize, "OUTLINE")
    local hc = p.useHealthColor and p.healthColor or GOLD
    u.hpText:SetTextColor(hc.r, hc.g, hc.b, 1)
    u._hpR, u._hpG, u._hpB = hc.r, hc.g, hc.b   -- sincronizar la cache del dedupe del ticker
    u.hpText:ClearAllPoints()
    u.hpText:SetPoint("CENTER", u.bar, "CENTER", p.textOffsetX, p.textOffsetY)

    if u.nameText then
        u.nameText:SetFont("Fonts\\FRIZQT__.TTF", p.nameFontSize, "OUTLINE")
        u.nameText:SetScale(p.nameScale)
        local nc = p.useNameColor and p.nameColor or GOLD
        u.nameText:SetTextColor(nc.r, nc.g, nc.b, 1)
    end
    if u.spellText then
        u.spellText:SetFont("Fonts\\FRIZQT__.TTF", p.spellFontSize, "OUTLINE")
        u.spellText:SetScale(p.spellScale)
        local sc = p.useSpellColor and p.spellColor or GOLD
        u.spellText:SetTextColor(sc.r, sc.g, sc.b, 1)
        -- Nombre de hechizo largo: envolver a 2 lineas centradas. El ANCHO de
        -- envoltura (spellWrapWidth) controla donde parte: mas estrecho => se apila.
        u.spellText:SetWordWrap(true)
        if u.spellText.SetMaxLines then pcall(u.spellText.SetMaxLines, u.spellText, 2) end
        u.spellText:SetWidth(math.max(p.spellWrapWidth or 130, 30))
    end

    -- Cast bar (StatusBar): textura/color propios, centrado. El spark se ancla al
    -- borde del relleno para seguirlo sin leer el valor (que puede ser secreto).
    if u.castBar then
        local ct = (p.castTexture ~= "" and p.castTexture) or BLANK_TEXTURE
        u.castBar:SetStatusBarTexture(ct)
        local cc = p.castColor
        u.castBar:SetStatusBarColor(cc.r, cc.g, cc.b, 1)
        u.castBar:SetReverseFill(p.castReverse and true or false)
        u.castBar:ClearAllPoints()
        u.castBar:SetPoint("CENTER", u.button, "CENTER", 0, 0)
        u.castBar:SetSize(p.castWidth, p.castHeight)
        if u.castSpark then
            u.castSpark:SetSize((p.castSparkWidth or 14) * (p.castSparkScale or 1), (p.castSparkHeight or 28) * (p.castSparkScale or 1))
            u.castSpark:ClearAllPoints()
            local tex = u.castBar:GetStatusBarTexture()
            -- Anclamos el BORDE del spark al frente del relleno (no su centro), asi
            -- no sobresale por fuera de la barra cuando el casteo llega al 100%.
            if p.castReverse then u.castSpark:SetPoint("LEFT", tex, "LEFT", 0, 0)
            else u.castSpark:SetPoint("RIGHT", tex, "RIGHT", 0, 0) end
        end
    end

    -- Highlight de "unidad seleccionada": textura/tamaño/escala/offset/color/opacidad.
    if u.highlight then
        local hw = (p.highlightWidth or 250) * (p.highlightScale or 1)
        local hh = (p.highlightHeight or 20) * (p.highlightScale or 1)
        u.highlight:SetTexture((p.highlightTexture and p.highlightTexture ~= "" and p.highlightTexture) or HIGHLIGHT_TEX)
        u.highlight:SetSize(hw, hh)
        u.highlight:ClearAllPoints()
        u.highlight:SetPoint("CENTER", u.button, "CENTER", p.highlightOffsetX or 0, p.highlightOffsetY or 0)
        local hc = p.highlightColor or { r = 1, g = 1, b = 1 }
        u.highlight:SetVertexColor(hc.r, hc.g, hc.b)
        u.highlight:SetAlpha(p.highlightAlpha or 1)
    end

    UnitUpdateBar(u)
    UnitTextVisibility(u)
    UnitUpdateMount(u)
    UnitUpdateHighlight(u)
end

local function RefreshUnit(key)
    local u = frames[key]
    if not u then return end
    UnitApplyLayout(u)
    UnitApplyAppearance(u)
end
ns.RefreshUnit = RefreshUnit
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
    elseif AURA_SET[ns.currentEdit] then
        if ns.RefreshAura then ns.RefreshAura(ns.currentEdit) end
    elseif PORTRAIT_SET[ns.currentEdit] then
        if ns.RefreshPortrait then ns.RefreshPortrait(ns.currentEdit) end
    else
        RefreshUnit(ns.currentEdit)
    end
end

-- Muestra/oculta los NOMBRES de los outlines (etiquetas encima del recuadro de edicion) de
-- TODOS los elementos, segun db.lockHide.names (toggle "Names" del Editing). Para units respeta
-- ademas su outlineHideName individual. Se llama al cambiar el toggle y en RefreshAll.
local function RefreshOutlineNames()
    local hideAll = db and db.lockHide and db.lockHide.names
    for _, u in pairs(frames) do
        if u.editBG and u.editBG.label then
            u.editBG.label:SetShown(not (hideAll or P(u).outlineHideName))
        end
    end
    for _, u in pairs(portraits) do
        if u.editBG and u.editBG.label then u.editBG.label:SetShown(not hideAll) end
    end
    for _, g in pairs(auras) do
        if g.editBG and g.editBG.label then g.editBG.label:SetShown(not hideAll) end
    end
    if infobar and infobar.editBG and infobar.editBG.label then infobar.editBG.label:SetShown(not hideAll) end
    if ns.micromenu and ns.micromenu.editBG and ns.micromenu.editBG.label then
        ns.micromenu.editBG.label:SetShown(not hideAll)
    end
end
ns.RefreshOutlineNames = RefreshOutlineNames

local function RefreshAll()
    for _, u in pairs(frames) do
        UnitApplyLayout(u)
        UnitApplyAppearance(u)
    end
    if ns.RefreshAllPortraits then ns.RefreshAllPortraits() end
    if ns.RefreshAllAuras then ns.RefreshAllAuras() end
    if ns.RefreshInfoBar then ns.RefreshInfoBar() end
    if ns.RefreshMicroMenu then ns.RefreshMicroMenu() end
    if ns.RefreshChatBubble then ns.RefreshChatBubble() end
    if ns.RefreshGlow then ns.RefreshGlow(true) end
    RefreshOutlineNames()
end
ns.RefreshAll = RefreshAll

-- ==========================================================================
-- CAST BAR
-- ==========================================================================
local function SetSparkTexture(spark)
    local ok = false
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("Legionfall_BarSpark") then
        ok = pcall(function() spark:SetAtlas("Legionfall_BarSpark") end)
    end
    if not ok then
        spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    end
end

local function GetCastProgress(unit)
    local casting, prog = false, 0
    pcall(function()
        local name, _, _, startMS, endMS = UnitCastingInfo(unit)
        local channel = false
        if name == nil then
            name, _, _, startMS, endMS = UnitChannelInfo(unit)
            channel = true
        end
        if name ~= nil and type(startMS) == "number" and type(endMS) == "number" then
            local dur = endMS - startMS
            if dur > 0 then
                local p = (GetTime() * 1000 - startMS) / dur
                if channel then p = 1 - p end
                if p < 0 then p = 0 elseif p > 1 then p = 1 end
                casting, prog = true, p
            end
        end
    end)
    return casting, prog
end

-- Direcciones del timer de StatusBar (API C, 12.0). ElapsedTime = se llena (casteo);
-- RemainingTime = se vacia (canalizacion).
local CAST_DIR_ELAPSED, CAST_DIR_REMAINING
if Enum and Enum.StatusBarTimerDirection then
    CAST_DIR_ELAPSED   = Enum.StatusBarTimerDirection.ElapsedTime
    CAST_DIR_REMAINING = Enum.StatusBarTimerDirection.RemainingTime
end

-- Metodo de suavizado del timer (numero: Enum.StatusBarInterpolation, NO booleano).
local CAST_SMOOTH_ON, CAST_SMOOTH_OFF
if Enum and Enum.StatusBarInterpolation then
    CAST_SMOOTH_OFF = Enum.StatusBarInterpolation.Immediate
    CAST_SMOOTH_ON  = Enum.StatusBarInterpolation.Linear
        or Enum.StatusBarInterpolation.ExponentialEaseOut or CAST_SMOOTH_OFF
end

-- Modo de casteo actual, SECRET-SAFE: "cast" / "channel" / nil. Solo compara con nil
-- (permitido); NO usa el nombre/castID (secretos en enemigos), evitando el taint.
local function ReadCastMode(unit)
    -- (RUTA MUY CALIENTE: corre por FRAME por cada cast bar via CastOnUpdate — la
    -- version con closure alocaba ~1 closure/frame/unidad.) Comparar solo con nil.
    local ok, v = pcall(UnitCastingInfo, unit)
    if ok and v ~= nil then return "cast" end
    local ok2, v2 = pcall(UnitChannelInfo, unit)
    if ok2 and v2 ~= nil then return "channel" end
    return nil
end

-- OnUpdate del cast bar (StatusBar). Los tiempos de casteo son SECRETOS para enemigos
-- (Midnight): por eso NO se calcula el progreso en Lua ni se compara ningun id secreto.
-- Se detecta "cast nuevo" por el cambio de MODO (legible) y se rellena con
-- StatusBar:SetTimerDuration (en C, con el duration object absoluto). Fallback manual
-- solo para tiempos legibles (p.ej. el player).
local function CastOnUpdate(self, elapsed)
    local u = self._u
    if not db then return end
    local p = P(u)

    -- Preview: barra estatica ~60%.
    if unlocked then
        self:SetAlpha(p.castAlpha)
        self._castMode, self._timerActive = nil, false
        self:SetMinMaxValues(0, 1); self:SetValue(0.6)
        if u.castSpark then u.castSpark:Show() end
        return
    end

    local mode = ReadCastMode(u.unit)
    if mode == nil then
        self:SetAlpha(0)
        self._castMode, self._timerActive = nil, false
        if u.castSpark then u.castSpark:Hide() end
        return
    end

    self:SetAlpha(p.castAlpha)
    -- Nuevo cast (cambio de modo o venia de nada): (re)inicia el timer una sola vez.
    if mode ~= self._castMode then
        self._castMode = mode
        self._timerActive = false
        local dur, dir
        if mode == "channel" then
            if UnitChannelDuration then
                local okD, d = pcall(UnitChannelDuration, u.unit)
                if okD then dur = d end
            end
            dir = CAST_DIR_REMAINING
        else
            if UnitCastingDuration then
                local okD, d = pcall(UnitCastingDuration, u.unit)
                if okD then dur = d end
            end
            dir = CAST_DIR_ELAPSED
        end
        if dur ~= nil and dir ~= nil and self.SetTimerDuration then
            local smoothing = p.castSmooth and CAST_SMOOTH_ON or CAST_SMOOTH_OFF
            self._timerActive = pcall(self.SetTimerDuration, self, dur, smoothing, dir)
        end
        if not self._timerActive then self:SetMinMaxValues(0, 1) end
        if u.castSpark then u.castSpark:Show() end
    end

    -- Sin timer en C (tiempos legibles): rellenar manualmente por progreso.
    -- (Por frame mientras castea: pcall directo; issecretvalue antes de testear.)
    if not self._timerActive then
        local okG, c2, pr = pcall(GetCastProgress, u.unit)
        local prog = 0
        if okG and not (issecretvalue and (issecretvalue(c2) or issecretvalue(pr))) and c2 then
            prog = pr
        end
        self:SetValue(prog)
    end
end

-- Fuerza re-deteccion del cast (al cambiar de target/focus/pet el frame reapunta a
-- otra unidad; sin esto seguiria mostrando el timer del casteo anterior).
local function ResetCastBar(key)
    local u = frames[key]
    if u and u.castBar then u.castBar._castMode, u.castBar._timerActive = nil, false end
end
ns.ResetCastBar = ResetCastBar

-- Smooth del hp/power bar (relleno manual; solo si el valor es legible).
local function BarOnUpdate(self, elapsed)
    if not self._readable then return end
    local u = self._u
    if not u then return end
    local p = P(u)
    if not p.smooth then return end
    local t = self._target or 0
    local cur = self._cur or t
    cur = cur + (t - cur) * math.min((elapsed or 0) * 10, 1)
    if math.abs(t - cur) < 0.001 then cur = t end
    self._cur = cur
    RenderManualFill(u.fillTex, self, cur, p.reverseFill)
end

-- ==========================================================================
-- CREACION DE FRAMES
-- ==========================================================================
local function CreateUnit(def)
    local u = {
        key = def.key, unit = def.unit, label = def.label,
        driver = def.driver, kind = def.kind or "health",
        fixedColor = def.fixedColor, isMouseOver = false,
    }
    local isPower = (u.kind == "power")

    local button
    if isPower then
        button = CreateFrame("Frame", "MyCF_" .. def.key, UIParent)
        button:EnableMouse(false)
    else
        button = CreateFrame("Button", "MyCF_" .. def.key, UIParent, "SecureUnitButtonTemplate")
        button._mcfOwnButton = true   -- sin WrapScript: el mouselook puede secuestrar su RMB-drag
        button:RegisterForClicks("AnyUp")
        button:SetAttribute("unit", def.unit)
        button:SetAttribute("*type1", "target")
        button:SetAttribute("*type2", "togglemenu")
    end
    button:SetSize(250, 20)
    button:SetPoint("CENTER")
    button:SetMovable(true)
    button:RegisterForDrag("LeftButton")

    local bg = button:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetAllPoints(button)
    bg:SetColorTexture(0, 0, 0, 0.5)

    local editBG = MakeEditHighlight(button, def.label or def.key)
    if not isPower then u.hitPreview = MakeHitPreview(button) end   -- B4: preview del area de click

    local cage = button:CreateTexture(nil, "ARTWORK")
    cage:Hide()

    local bar = CreateFrame("StatusBar", nil, button)
    bar:SetAllPoints(button)
    bar:SetFrameLevel(button:GetFrameLevel() + 1)
    bar:SetStatusBarTexture(isPower and POWER_TEXTURE or TEXTURE_DEFAULT)
    bar:SetOrientation("HORIZONTAL")
    bar._u = u
    bar:SetScript("OnUpdate", BarOnUpdate)

    -- Textura de relleno MANUAL (para valores legibles; encima del relleno nativo).
    local fillTex = bar:CreateTexture(nil, "OVERLAY")
    fillTex:Hide()

    u.button, u.bg, u.editBG, u.cage, u.bar, u.fillTex = button, bg, editBG, cage, bar, fillTex

    -- Cast bar (StatusBar) por encima del hp bar (solo vida). Es StatusBar para poder
    -- usar SetTimerDuration (rellena en C), unico modo de mostrar casteos con tiempos
    -- SECRETOS (enemigos en Midnight). El spark se ancla al borde del relleno.
    if not isPower then
        local castBar = CreateFrame("StatusBar", nil, button)
        castBar:SetPoint("CENTER", button, "CENTER", 0, 0)
        castBar:SetSize(250, 20)
        castBar:SetFrameLevel(button:GetFrameLevel() + 2)
        castBar:SetOrientation("HORIZONTAL")
        castBar:SetStatusBarTexture(TEXTURE_DEFAULT)
        castBar:SetMinMaxValues(0, 1)
        castBar:SetValue(0)
        castBar:SetAlpha(0)
        local castSpark = castBar:CreateTexture(nil, "OVERLAY")
        castSpark:SetBlendMode("ADD")
        SetSparkTexture(castSpark)
        castSpark:Hide()
        castBar._u = u
        castBar:SetScript("OnUpdate", CastOnUpdate)
        u.castBar, u.castSpark = castBar, castSpark
    end

    -- Overlay para textos: por encima del cast bar para que no los tape.
    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints(button)
    overlay:SetFrameLevel(button:GetFrameLevel() + 3)
    u.overlay = overlay

    -- Highlight de "unidad seleccionada" (target): DETRAS de todas las texturas de la
    -- unidad. Va en el propio button, capa BACKGROUND sublevel minimo (-8), asi el bg,
    -- la cage (ARTWORK) y los frames hijos (bar/cast/overlay) renderizan todos ENCIMA;
    -- el borde-glow asoma por detras del frame. Latido opcional.
    local highlight = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    highlight:SetPoint("CENTER")
    highlight:Hide()
    local hlAnim = highlight:CreateAnimationGroup()
    hlAnim:SetLooping("REPEAT")
    local hla1 = hlAnim:CreateAnimation("Alpha"); hla1:SetFromAlpha(1); hla1:SetToAlpha(0.4); hla1:SetDuration(0.6); hla1:SetOrder(1); hla1:SetSmoothing("IN_OUT")
    local hla2 = hlAnim:CreateAnimation("Alpha"); hla2:SetFromAlpha(0.4); hla2:SetToAlpha(1); hla2:SetDuration(0.6); hla2:SetOrder(2); hla2:SetSmoothing("IN_OUT")
    u.highlight, u.highlightAnim = highlight, hlAnim

    local hpText = overlay:CreateFontString(nil, "OVERLAY")
    hpText:SetTextColor(GOLD.r, GOLD.g, GOLD.b, 1)
    u.hpText = hpText

    if HasNameByKey(def.key) then
        local nameText = overlay:CreateFontString(nil, "OVERLAY")
        nameText:SetTextColor(GOLD.r, GOLD.g, GOLD.b, 1)
        nameText:SetJustifyH("CENTER")
        nameText:SetWordWrap(false)
        u.nameText = nameText

        local spellText = overlay:CreateFontString(nil, "OVERLAY")
        spellText:SetTextColor(GOLD.r, GOLD.g, GOLD.b, 1)
        spellText:SetJustifyH("CENTER")
        spellText:SetWordWrap(false)
        spellText:SetAlpha(0)
        u.spellText = spellText
    end

    if not isPower then
        button:SetScript("OnEnter", function(self)
            u.isMouseOver = true
            if db then UnitTextVisibility(u) end
            if db and P(u).showTooltip and UnitExists(u.unit) then
                GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
                GameTooltip:SetUnit(u.unit)
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function()
            u.isMouseOver = false
            if db then UnitTextVisibility(u) end
            GameTooltip:Hide()
        end)
    end

    button:SetScript("OnDragStart", function(self)
        if unlocked and not InCombatLockdown() then
            u._dragStart = { self:GetCenter() }   -- centro al empezar (para mover el grupo)
            self:StartMoving()
        end
    end)
    button:SetScript("OnDragStop", function(self)
        -- Si el combate empezo A MITAD del drag (el drag solo puede EMPEZAR fuera de
        -- combate), StopMovingOrSizing sobre el frame SEGURO esta bloqueado
        -- (ADDON_ACTION_BLOCKED). Diferir el stop + guardado a PLAYER_REGEN_ENABLED,
        -- que re-invoca este mismo handler.
        if InCombatLockdown() and self:IsProtected() then
            u._stopMovePending = true
            return
        end
        u._stopMovePending = nil
        self:StopMovingOrSizing()
        if ns.SnapFrameToGrid then ns.SnapFrameToGrid(self) end
        local p = P(u)
        -- Delta de movimiento en pantalla (para el grupo).
        local dx, dy = 0, 0
        if u._dragStart then
            local cx, cy = self:GetCenter()
            if cx and u._dragStart[1] then dx, dy = cx - u._dragStart[1], cy - u._dragStart[2] end
        end
        -- Guardar la posicion propia (relativa a su anchor, CENTER-CENTER).
        local parent = _G[p.anchorFrame]
        if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
        local s, ps = self:GetEffectiveScale(), parent:GetEffectiveScale()
        local fx, fy = self:GetCenter()
        local px, py = parent:GetCenter()
        if fx and px then
            p.point, p.relativePoint = "CENTER", "CENTER"
            p.offsetX = (fx * s - px * ps) / s
            p.offsetY = (fy * s - py * ps) / s
        end
        -- Mover el resto del grupo (misma delta) si la opcion esta activa.
        local group = GetMoveGroup(u.key)
        if group then
            for _, gk in ipairs(group) do
                if gk ~= u.key then
                    local gp = db.units[gk]
                    gp.offsetX = (gp.offsetX or 0) + dx
                    gp.offsetY = (gp.offsetY or 0) + dy
                    RefreshUnit(gk)
                end
            end
        end
        -- Seguidores de arrastre (portraits que siguen a su unitframe, party, etc.).
        if ns.MoveFollowers then ns.MoveFollowers(u.key, dx, dy) end
        u._dragStart = nil
        RefreshUnit(u.key)
        if ns.OnDragStopped then ns.OnDragStopped(u.key) end
    end)

    if not isPower then
        if def.driver then
            RegisterStateDriver(button, "visibility", def.driver)
        else
            RegisterUnitWatch(button)
        end
    end

    AttachScaleWheel(u.button, function() return P(u) end, function() UnitApplyLayout(u) end)
    frames[def.key] = u
    return u
end

for _, def in ipairs(UNITS) do CreateUnit(def) end

local function PetDriverString()
    if safeBool(IsInInstance) then return "[@pet,exists] show; hide" end
    return "[@pet,exists,combat] show; [@pet,exists,@target,exists] show; hide"
end

local function UpdatePetDriver()
    local u = frames["pet"]
    if not u then return end
    local d = PetDriverString()
    u.driver = d
    if unlocked then return end
    if InCombatLockdown() then u.needsDriver = true return end
    UnregisterStateDriver(u.button, "visibility")
    RegisterStateDriver(u.button, "visibility", d)
    u.needsDriver = nil
end

-- Party1-5: visibles SOLO en grupo pequeño (party/dungeon). Se ocultan en raid
-- y en cualquier instancia PvP (battleground/arena). En raid los tokens party1-4
-- ni existen, pero en ARENA sí → por eso hace falta el chequeo de tipo de
-- instancia en Lua (no hay condicional de macro para "arena").
local function PartyDriverString(u)
    -- Arena (grupo de party + instancia pvp): no hay condicional de macro para
    -- "arena", asi que se detecta en Lua y se oculta del todo.
    local isPvP = false
    pcall(function()
        local _, it = IsInInstance()
        isPvP = (it == "pvp" or it == "arena")
    end)
    if isPvP then return "hide" end
    -- [group:raid] es un condicional SEGURO y dinamico: oculta en raid y en
    -- CUALQUIER battleground (todos son grupos de raid al activarse), sin depender
    -- del timing del update en Lua ni del diferido por combate.
    return "[group:raid] hide; [@" .. u.unit .. ",exists] show; hide"
end

local function UpdatePartyDrivers()
    for _, key in ipairs(PARTY_KEYS) do
        local u = frames[key]
        if u and u.button then
            local d = PartyDriverString(u)
            u.driver = d
            if unlocked then
                -- en preview no se toca; se aplica al salir (SetUnlocked usa u.driver)
            elseif InCombatLockdown() then
                u.needsDriver = true
            else
                UnregisterUnitWatch(u.button)
                UnregisterStateDriver(u.button, "visibility")
                RegisterStateDriver(u.button, "visibility", d)
                u.needsDriver = nil
            end
        end
    end
end

-- ==========================================================================
-- PORTRAITS: creacion y logica
-- ==========================================================================
local function PP(u) return db.portraits[u.key] end

-- Condicion para usar la posicion "centro" (target / combate / instancia).
local function PortraitCenterActive(u)
    local p = PP(u)
    local active = false
    if p.centerInCombat and tickState.inCombat then active = true end
    if not active and p.centerOnTarget then
        if UnitExists("target") then active = true end
    end
    -- Solo RAID o DUNGEON (type "raid"/"party"), no cualquier instancia (BG/arena/escenario).
    -- (pcall directo sin closure; issecretvalue antes de testear/comparar.)
    if not active and p.centerInInstance then
        local ok, inInst, it = pcall(IsInInstance)
        if ok and not (issecretvalue and (issecretvalue(inInst) or issecretvalue(it)))
           and inInst and (it == "raid" or it == "party") then
            active = true
        end
    end
    return active
end

-- Coloca el portrait en la posicion que corresponda (o en la que se edita en preview).
-- Solo los portraits con feature dualPos tienen 2 posiciones; el resto usan solo "centro".
local function PortraitUpdatePosition(u)
    -- Si el root quedo PROTEGIDO (p.ej. un frame seguro fue anclado a el alguna vez),
    -- ClearAllPoints/SetPoint en combate = ADDON_ACTION_BLOCKED. Se salta el tick.
    if InCombatLockdown() and u.root:IsProtected() then return end
    local p = PP(u)
    CompensateScale(p, "portrait")   -- B3: reancla offsets si la escala cambio
    local dual = u.features and u.features.dualPos
    local which = "center"
    if dual then
        if unlocked then which = (p.editPos == "alt") and "alt" or "center"
        elseif PortraitCenterActive(u) then which = "center"
        else which = "alt" end
    end
    local anchorName, point, relPoint, x, y
    if which == "alt" then
        anchorName, point, relPoint, x, y = p.altAnchor, p.altPoint, p.altRelPoint, p.altX, p.altY
    else
        anchorName, point, relPoint, x, y = p.centerAnchor, p.centerPoint, p.centerRelPoint, p.centerX, p.centerY
    end
    local parent = _G[anchorName]
    if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
    -- Dedupe: re-anclar cada tick con los mismos valores es trabajo inutil. Se compara
    -- contra lo ULTIMO APLICADO (datos propios del addon, nunca secretos); el parent
    -- resuelto entra en la firma (un anchor que aparece tarde re-ancla solo). El
    -- OnDragStop invalida la firma (_posParent=nil) porque StartMoving cambia el ancla real.
    if u._posParent == parent and u._posP == point and u._posRP == relPoint
       and u._posX == x and u._posY == y then return end
    u.root:ClearAllPoints()
    u.root:SetPoint(point, parent, relPoint, x, y)
    u._posParent, u._posP, u._posRP, u._posX, u._posY = parent, point, relPoint, x, y
end

-- Coordenadas del icono de clase de la unidad (nil si no tiene clase legible).
local function PortraitClassCoords(unit)
    -- (Ruta caliente: se consulta cada tick por cada portrait de icono via
    -- PortraitShouldShow.) pcall directo; el token de clase puede ser secreto:
    -- NUNCA indexar la tabla con el sin confirmar que es legible.
    local ok, _, class = pcall(UnitClass, unit)
    if ok and type(class) == "string" and not (issecretvalue and issecretvalue(class)) then
        return CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    end
end

-- Actualiza el "retrato": modelo 3D (kind=model) o icono de clase (kind=icon).
local function PortraitUpdatePicture(u)
    local p = PP(u)
    if u.kind == "icon" then
        if not u.classIcon then return end
        if not p.showModel then u.classIcon:Hide() return end
        local coords = PortraitClassCoords(u.unit)
        if not coords and unlocked then coords = PortraitClassCoords("player") end  -- preview
        if coords then
            u.classIcon:SetTexture(CLASS_ICON_TEX)
            u.classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            u.classIcon:Show()
        else
            u.classIcon:Hide()
        end
        return
    end
    if not u.model then return end
    if not p.showModel then u.model:Hide() return end
    u.model:Show()
    pcall(function()
        u.model:ClearModel()
        u.model:SetUnit(u.unit)
        u.model:SetPortraitZoom(clamp(p.modelZoom, 0, 1))
        u.model:SetPosition(0, 0, 0)
    end)
end

local function PortraitUpdateFaction(u)
    if not u.faction then return end
    local p = PP(u)
    if not p.showFaction then u.faction:Hide() return end
    -- En COMBATE se oculta el badge de faccion (el de combate ocupa su lugar). En
    -- preview (unlocked) NO, para poder editarlo/posicionarlo.
    if not unlocked and tickState.inCombat then u.faction:Hide() return end
    local fac = safeVal(UnitFactionGroup, "player")
    -- War Mode: usa el icono de badge de guerra segun el TOGGLE del jugador (no la zona).
    -- IsWarModeDesired = refleja el interruptor de Modo Guerra activado/desactivado (persiste entre
    -- zonas, aunque estes en una ciudad santuario donde no esta "activo"); IsWarModeActive solo es
    -- true en zonas de mundo con PvP → daba la sensacion de que el badge no cambiaba. Guard pcall.
    local warOn = false
    if C_PvP then
        local ok, v = pcall(function()
            if C_PvP.IsWarModeDesired then return C_PvP.IsWarModeDesired() end
            if C_PvP.IsWarModeActive then return C_PvP.IsWarModeActive() end
        end)
        warOn = ok and v and true or false
    end
    if fac == "Alliance" then
        u.faction:SetTexture(warOn and BADGE_ALLIANCE_WAR or BADGE_ALLIANCE); u.faction:Show()
    elseif fac == "Horde" then
        u.faction:SetTexture(warOn and BADGE_HORDE_WAR or BADGE_HORDE); u.faction:Show()
    else
        u.faction:Hide()   -- neutral / sin faccion
    end
end

-- Marcador de banda (raid target icon). Solo party (feature raidTarget). Usa la textura
-- CUSTOM manteniendo los texcoords de SetRaidTargetIconTexture (grid estandar 4x4): se
-- llama SetRaidTargetIconTexture (fija coords correctas por indice) y luego se cambia la
-- textura al asset propio (SetTexture no toca los texcoords). Igual que AzeriteUI.
-- Muestra/oculta el marcador con FADE suave (Alpha). Solo dispara la transicion al CAMBIAR de
-- estado (no cada tick). El bounce (Translation) sigue independiente del alpha.
local function RaidTargetSetVisible(u, show)
    local rt, fade = u.raidtarget, u.raidtargetFade
    if u._rtVisible == show then return end
    u._rtVisible = show
    local target = PP(u).raidTargetAlpha or 1
    if not fade or not fade.anim then
        if show then rt:SetAlpha(target); rt:Show() else rt:Hide() end
        return
    end
    fade:Stop()
    if show then
        fade:SetScript("OnFinished", nil)
        -- Alpha BASE = target (no 0): una animacion Alpha es un override temporal y al terminar
        -- revierte al alpha base; si el base fuera 0, el marcador se desvaneceria tras el fade.
        -- Con base=target y FromAlpha=0, el fade visual va 0→target y al terminar QUEDA visible.
        rt:SetAlpha(target); rt:Show()
        fade.anim:SetFromAlpha(0); fade.anim:SetToAlpha(target)
        fade:Play()
    else
        fade:SetScript("OnFinished", function() rt:Hide() end)
        fade.anim:SetFromAlpha(rt:GetAlpha()); fade.anim:SetToAlpha(0)
        fade:Play()
    end
end

local function PortraitUpdateRaidTarget(u)
    local rt = u.raidtarget
    if not rt then return end
    local p = PP(u)
    if not (u.features and u.features.raidTarget and p.showRaidTarget) then
        rt:Hide(); u._rtVisible = false; return
    end
    local index
    if unlocked then
        index = 8   -- preview: calavera de muestra
    else
        index = safeVal(GetRaidTargetIndex, u.unit)
    end
    -- CLAVE (Midnight): GetRaidTargetIndex devuelve un NUMERO SECRETO si la unidad esta
    -- marcada -> NUNCA comparar (>=, <=, ==) en Lua (crashea "compare secret number").
    -- type() es seguro (devuelve "number" para secretos); nil = sin marca. SetRaidTargetIconTexture
    -- es funcion en C y acepta el indice secreto para fijar los texcoords.
    if type(index) == "number" then
        pcall(SetRaidTargetIconTexture, rt, index)   -- fija texcoords del indice (acepta secreto)
        rt:SetTexture((p.raidTargetTexture and p.raidTargetTexture ~= "" and p.raidTargetTexture) or RAIDTARGET_TEX)
        RaidTargetSetVisible(u, true)   -- fade-in suave (solo en la transicion)
        if p.raidTargetBounce and u.raidtargetAnim then
            if not u.raidtargetAnim:IsPlaying() then u.raidtargetAnim:Play() end
        elseif u.raidtargetAnim then
            u.raidtargetAnim:Stop()
        end
    else
        RaidTargetSetVisible(u, false)  -- fade-out suave y luego oculta
        if u.raidtargetAnim then u.raidtargetAnim:Stop() end
    end
end

-- Icono de ROL (tank/heal/dps) + LIDER. Solo party (feature roleLeader).
-- UnitGroupRolesAssigned devuelve "TANK"/"HEALER"/"DAMAGER"/"NONE"; UnitIsGroupLeader booleano.
-- Ambos legibles (no secretos). Texturas CUSTOM por rol (una textura completa cada una).
local function PortraitUpdateRoleLeader(u)
    if not (u.roleicon and u.leader) then return end
    local p = PP(u)
    local feats = u.features or {}
    -- Rol: SOLO party (feature roleLeader).
    if feats.roleLeader and p.showRole then
        local role = unlocked and "HEALER" or safeVal(UnitGroupRolesAssigned, u.unit)
        local tex = (role == "TANK" and ROLE_TANK) or (role == "HEALER" and ROLE_HEAL)
            or (role == "DAMAGER" and ROLE_DPS)
        if tex then
            u.roleicon:SetTexture(tex)
            u.roleicon:Show()
        else
            u.roleicon:Hide()
        end
    else
        u.roleicon:Hide()
    end
    -- Lider: party (roleLeader) O cualquier portrait con feature 'leader'. Toggle showLeader.
    if (feats.roleLeader or feats.leader) and p.showLeader
       and (unlocked or safeBool(UnitIsGroupLeader, u.unit)) then
        u.leader:Show()
    else
        u.leader:Hide()
    end
end

-- Estado dinamico: descanso (flipbook), muerte, badge de combate.
-- Performance Fase 2 (2026-07-15): `skipBadges` (opcional, default nil/false = actualiza los
-- badges) permite que el ticker principal actualice faccion/raid-target/rol-lider a MENOR
-- frecuencia (cambian raramente: war mode toggle, marcar/desmarcar objetivo, reasignar rol) sin
-- tocar rest/death/combat (necesitan reaccionar cada tick para verse fluidos). El OTRO call site
-- (aplicar config / SetUnlocked, linea ~2188) NO pasa este parametro -> sigue actualizando los
-- badges siempre, para que un cambio de configuracion se vea al instante.
local function PortraitUpdateState(u, preview, skipBadges)
    local p = PP(u)
    local resting, dead, inCombat
    if preview then
        resting, dead, inCombat = true, true, true
    else
        resting  = tickState.resting
        dead     = safeBool(UnitIsDeadOrGhost, u.unit)
        inCombat = tickState.inCombat
    end
    if u.rest then
        local on = p.showRest and resting
        u.rest:SetShown(on)
        if on then
            if u.restAnim and not u.restAnim:IsPlaying() then u.restAnim:Play() end
        elseif u.restAnim then
            u.restAnim:Stop()
        end
    end
    -- B4: en preview, ocultar SAMPLE de death/raid/badges si el toggle Lock lo pide.
    local lh = (preview and db and db.lockHide) or nil
    if u.death  then u.death:SetShown(p.showDeath and dead and not (lh and lh.death)) end
    if u.combat then
        local showCombat = p.showCombat and inCombat and not (lh and lh.badges)
        u.combat:SetShown(showCombat)
        -- Bounce mientras esta en combate (en preview se muestra estatico).
        if u.combatAnim then
            if showCombat and not preview then
                if not u.combatAnim:IsPlaying() then u.combatAnim:Play() end
            else
                u.combatAnim:Stop()
            end
        end
    end
    if not skipBadges then
        -- Faccion (alianza/horda): se oculta en combate; se relee aqui para que sea dinamico.
        PortraitUpdateFaction(u)
        -- Marcador de banda (raid target): dinamico (la marca puede ponerse/quitarse).
        PortraitUpdateRaidTarget(u)
        -- Rol + lider (party): dinamicos.
        PortraitUpdateRoleLeader(u)
    end
    -- B4: en preview, ocultar badges/raid marks si el toggle Lock lo pide (tras los updates).
    if lh then
        if lh.badges and u.faction then u.faction:Hide() end
        if lh.raid and u.raidtarget then u.raidtarget:Hide(); u._rtVisible = false end
    end
end

-- Contenido donde tienen sentido los PARTY portraits: mundo abierto, grupo normal y
-- mazmorra ("party"). Fuera (raid, arena, BG/cualquier pvp, escenario/delve, o grupo
-- de RAID aunque sea en mundo abierto): ocultos. Secret-safe: issecretvalue antes de
-- testear/comparar. El ticker lo cachea en tickState.partyOK (cambia solo por zona/grupo).
local function PartyContentAllowed()
    local ok, inInst, it = pcall(IsInInstance)
    if ok and not (issecretvalue and (issecretvalue(inInst) or issecretvalue(it))) then
        if inInst and it ~= "party" then return false end
    end
    if safeBool(IsInRaid) then return false end
    return true
end

-- Debe mostrarse el portrait? (activado; unidad existe/muerta segun flags; clase legible si icono).
local function PortraitShouldShow(u)
    if not PP(u).enabled then return false end
    -- Party portraits: gating por tipo de contenido (tickState.partyOK, por tick).
    if tickState.partyOK == false and u.key:sub(1, 14) == "portrait_party" then return false end
    if u.requireExists and not UnitExists(u.unit) then return false end
    if u.deadOnly then
        local dead = safeBool(UnitExists, u.unit) and safeBool(UnitIsDeadOrGhost, u.unit)
        if not dead then return false end
    end
    if u.kind == "icon" and not PortraitClassCoords(u.unit) then return false end
    return true
end

-- Muestra/oculta el root de un portrait respetando las restricciones de Blizzard:
-- si el frame quedo PROTEGIDO (p.ej. porque un frame seguro fue anclado a el en algun
-- momento de la sesion), Show/Hide desde codigo inseguro esta BLOQUEADO en combate
-- (ADDON_ACTION_BLOCKED:...:Hide()). En ese caso: alpha 0 como sustituto visual y el
-- Show/Hide REAL se difiere a PLAYER_REGEN_ENABLED (_pendingShown). El flag
-- _mcfCombatHidden en el root avisa al Explorer de que no toque ese alpha.
local function PortraitSetShown(u, shown)
    shown = shown and true or false
    local root = u.root
    if InCombatLockdown() and root:IsProtected() then
        local cur = u._pendingShown
        if cur == nil then cur = root:IsShown() and true or false end
        if cur ~= shown then
            u._pendingShown = shown
            root._mcfCombatHidden = (not shown) or nil
            root:SetAlpha(shown and 1 or 0)
            -- El modelo 3D no hereda el alpha del padre: ocultarlo/restaurarlo a mano.
            if u.model then u.model:SetAlpha(shown and (PP(u).modelAlpha or 1) or 0) end
        end
        return
    end
    if u._pendingShown ~= nil then
        u._pendingShown = nil
        root._mcfCombatHidden = nil
        root:SetAlpha(1)
        if u.model then u.model:SetAlpha(PP(u).modelAlpha or 1) end
    end
    root:SetShown(shown)
end

-- Dibuja el highlight del FOCUS en su portrait, DETRAS de todos los elementos (textura hl en
-- BACKGROUND -8 del root). Usa la config de db.units.focus (showHighlight/highlightTexture/
-- width/height/scale/color/alpha/offset/glow) + "el focus es mi target". En preview siempre
-- visible (para editarlo). Se llama desde PortraitApplyAppearance y desde el ticker.
local function UpdateFocusPortraitHighlight()
    local pu = portraits["portrait_focus"]
    if not (pu and pu.hl) then return end
    local p = db and db.units and db.units.focus
    if not p or not p.showHighlight then
        pu.hl:Hide(); if pu.hlAnim then pu.hlAnim:Stop() end; return
    end
    local isTarget = unlocked
        or (safeBool(UnitExists, "focus") and safeBool(UnitIsUnit, "focus", "target"))
    if not isTarget then
        pu.hl:Hide(); if pu.hlAnim then pu.hlAnim:Stop() end; return
    end
    pu.hl:SetTexture((p.highlightTexture and p.highlightTexture ~= "" and p.highlightTexture) or HIGHLIGHT_TEX)
    local w = (p.highlightWidth or 250) * (p.highlightScale or 1)
    local h = (p.highlightHeight or 20) * (p.highlightScale or 1)
    pu.hl:SetSize(w, h)
    pu.hl:ClearAllPoints()
    pu.hl:SetPoint("CENTER", pu.root, "CENTER", p.highlightOffsetX or 0, p.highlightOffsetY or 0)
    local c = p.highlightColor or { r = 1, g = 1, b = 1 }
    pu.hl:SetVertexColor(c.r, c.g, c.b)
    pu.hl:SetAlpha(p.highlightAlpha or 1)
    pu.hl:Show()
    if p.highlightGlow and pu.hlAnim then
        if not pu.hlAnim:IsPlaying() then pu.hlAnim:Play() end
    elseif pu.hlAnim then
        pu.hlAnim:Stop(); pu.hl:SetAlpha(p.highlightAlpha or 1)
    end
end
ns.UpdateFocusPortraitHighlight = UpdateFocusPortraitHighlight

local function PortraitApplyAppearance(u)
    local p = PP(u)
    local s = p.size
    u.root:SetSize(s, s)
    u.root:SetScale(p.scale or 1)   -- escala general (multiplica sobre size, sin alterarlo)
    u.root:SetFrameStrata(p.strata)

    -- Fondo circular (coloreable).
    u.bg:SetTexture((p.bgTexture and p.bgTexture ~= "" and p.bgTexture) or PORTRAIT_BG)
    u.bg:SetSize(s * p.bgScale, s * p.bgScale)
    u.bg:ClearAllPoints(); u.bg:SetPoint("CENTER", u.root, "CENTER", 0, 0)
    u.bg:SetVertexColor(p.bgColor.r, p.bgColor.g, p.bgColor.b, p.bgAlpha)
    u.bg:SetShown(p.showBg)

    -- Retrato (modelo 3D o icono de clase).
    if u.pic then
        u.pic:SetSize(s * p.modelScale, s * p.modelScale)
        u.pic:ClearAllPoints(); u.pic:SetPoint("CENTER", u.root, "CENTER", p.modelOffsetX, p.modelOffsetY)
        u.pic:SetAlpha(p.modelAlpha)
    end

    -- Borde / orbe.
    u.cage:SetTexture((p.cageTexture and p.cageTexture ~= "" and p.cageTexture) or PORTRAIT_ORB)
    u.cage:SetSize(s * p.cageScale, s * p.cageScale)
    u.cage:ClearAllPoints(); u.cage:SetPoint("CENTER", u.root, "CENTER", p.cageOffsetX, p.cageOffsetY)
    u.cage:SetAlpha(p.cageAlpha); u.cage:SetShown(p.showCage)

    -- Flipbook de descanso.
    u.rest:SetSize(s * p.restScale, s * p.restScale)
    u.rest:ClearAllPoints(); u.rest:SetPoint("CENTER", u.root, "CENTER", p.restOffsetX, p.restOffsetY)
    u.rest:SetAlpha(p.restAlpha)

    -- Marca de muerte (color + opacidad).
    u.death:SetSize(s * p.deathScale, s * p.deathScale)
    u.death:ClearAllPoints(); u.death:SetPoint("CENTER", u.root, "CENTER", p.deathOffsetX, p.deathOffsetY)
    u.death:SetVertexColor(p.deathColor.r, p.deathColor.g, p.deathColor.b)
    u.death:SetAlpha(p.deathAlpha)

    -- Badge de faccion (color + opacidad).
    u.faction:SetSize(s * p.factionScale, s * p.factionScale)
    u.faction:ClearAllPoints(); u.faction:SetPoint("CENTER", u.root, "CENTER", p.factionOffsetX, p.factionOffsetY)
    u.faction:SetVertexColor(p.factionColor.r, p.factionColor.g, p.factionColor.b)
    u.faction:SetAlpha(p.factionAlpha)

    -- Badge de combate (color + opacidad).
    u.combat:SetSize(s * p.combatScale, s * p.combatScale)
    u.combat:ClearAllPoints(); u.combat:SetPoint("CENTER", u.root, "CENTER", p.combatOffsetX, p.combatOffsetY)
    u.combat:SetVertexColor(p.combatColor.r, p.combatColor.g, p.combatColor.b)
    u.combat:SetAlpha(p.combatAlpha)

    -- Marcador de banda (raid target): tamaño/offset/opacidad configurables.
    if u.raidtarget then
        u.raidtarget:SetSize(s * (p.raidTargetScale or 0.62), s * (p.raidTargetScale or 0.62))
        u.raidtarget:ClearAllPoints()
        u.raidtarget:SetPoint("CENTER", u.root, "CENTER", p.raidTargetOffsetX or 0, p.raidTargetOffsetY or 32)
        u.raidtarget:SetAlpha(p.raidTargetAlpha or 1)
    end

    -- Iconos de rol / lider: tamaño/offset/opacidad configurables.
    if u.roleicon then
        u.roleicon:SetSize(s * (p.roleScale or 0.42), s * (p.roleScale or 0.42))
        u.roleicon:ClearAllPoints()
        u.roleicon:SetPoint("CENTER", u.root, "CENTER", p.roleOffsetX or 0, p.roleOffsetY or 0)
        u.roleicon:SetAlpha(p.roleAlpha or 1)
    end
    if u.leader then
        u.leader:SetSize(s * (p.leaderScale or 0.42), s * (p.leaderScale or 0.42))
        u.leader:ClearAllPoints()
        u.leader:SetPoint("CENTER", u.root, "CENTER", p.leaderOffsetX or 0, p.leaderOffsetY or 0)
        u.leader:SetAlpha(p.leaderAlpha or 1)
    end

    PortraitUpdatePicture(u)
    PortraitUpdateFaction(u)
    PortraitUpdateRaidTarget(u)
    PortraitUpdateRoleLeader(u)
    PortraitUpdatePosition(u)
    PortraitUpdateState(u, unlocked)

    -- Zona verde de edicion.
    if u.editBG then u.editBG:SetShown(unlocked and not (db and db.hideEditGreen)) end
    PortraitSetShown(u, unlocked or PortraitShouldShow(u))
    -- Captura mouse en preview (arrastrar) o fuera de preview si abre el panel (clickOpenChar).
    u.root:EnableMouse(unlocked or (p.clickOpenChar and true or false))
    -- Focus: refrescar su highlight (detras del retrato) al aplicar apariencia (incl. preview).
    if u.key == "portrait_focus" then UpdateFocusPortraitHighlight() end
end

local function RefreshPortrait(key)
    local u = portraits[key]
    if not u then return end
    PortraitApplyAppearance(u)
    if key == "portrait_player" and ns.LayoutPortraitCharButtons then ns.LayoutPortraitCharButtons(u) end
end
ns.RefreshPortrait = RefreshPortrait

local function RefreshAllPortraits()
    for _, u in pairs(portraits) do PortraitApplyAppearance(u) end
end
ns.RefreshAllPortraits = RefreshAllPortraits

local function CreatePortrait(def)
    local u = {
        key = def.key, unit = def.unit, label = def.label,
        kind = def.kind or "model", deadOnly = def.deadOnly,
        features = def.features or {}, requireExists = def.requireExists,
    }

    local root = CreateFrame("Frame", "MyCF_Portrait_" .. def.key, UIParent)
    root:SetSize(90, 90)
    root:SetPoint("CENTER")
    root:SetMovable(true)
    root:RegisterForDrag("LeftButton")
    root:EnableMouse(false)

    -- Zona verde (solo en preview).
    local editBG = MakeEditHighlight(root, "Portrait " .. (def.label or def.key))

    -- FOCUS: highlight de "es mi target" DETRAS de todo (sublayer -8, debajo del bg=1 y de
    -- los frames hijos model/icons). Se dibuja aqui, no en el boton (que va delante). Lo
    -- gestiona UpdateFocusPortraitHighlight con la config de db.units.focus.
    if def.key == "portrait_focus" then
        local hl = root:CreateTexture(nil, "BACKGROUND", nil, -8)
        hl:SetPoint("CENTER")
        hl:Hide()
        local hlAnim = hl:CreateAnimationGroup()
        hlAnim:SetLooping("REPEAT")
        local a1 = hlAnim:CreateAnimation("Alpha"); a1:SetFromAlpha(1); a1:SetToAlpha(0.4); a1:SetDuration(0.6); a1:SetOrder(1); a1:SetSmoothing("IN_OUT")
        local a2 = hlAnim:CreateAnimation("Alpha"); a2:SetFromAlpha(0.4); a2:SetToAlpha(1); a2:SetDuration(0.6); a2:SetOrder(2); a2:SetSmoothing("IN_OUT")
        u.hl, u.hlAnim = hl, hlAnim
    end

    -- Fondo circular.
    local bg = root:CreateTexture(nil, "BACKGROUND", nil, 1)
    bg:SetPoint("CENTER")

    -- Retrato: modelo 3D (kind=model) o icono de clase (kind=icon), encima del fondo.
    local model, classIcon, pic
    if def.kind == "icon" then
        classIcon = root:CreateTexture(nil, "ARTWORK", nil, 1)
        classIcon:SetPoint("CENTER")
        classIcon:Hide()
        pic = classIcon
    else
        model = CreateFrame("PlayerModel", nil, root)
        model:SetFrameLevel(root:GetFrameLevel() + 1)
        model:SetPoint("CENTER")
        pic = model
    end

    -- Capa de iconos por encima del modelo (borde, flipbook, muerte, badges).
    local icons = CreateFrame("Frame", nil, root)
    icons:SetAllPoints(root)
    icons:SetFrameLevel(root:GetFrameLevel() + 2)

    -- Flipbook de descanso (7 filas x 6 columnas = 42 frames). Debajo del borde.
    local rest = icons:CreateTexture(nil, "ARTWORK", nil, -1)
    rest:SetAtlas(ATLAS_REST)
    rest:SetPoint("CENTER")
    rest:Hide()

    local cage = icons:CreateTexture(nil, "ARTWORK", nil, 0)
    cage:SetPoint("CENTER")
    local restAnim = rest:CreateAnimationGroup()
    restAnim:SetLooping("REPEAT")
    local flip = restAnim:CreateAnimation("FlipBook")
    flip:SetDuration(2.0)
    flip:SetFlipBookRows(7)
    flip:SetFlipBookColumns(6)
    flip:SetFlipBookFrames(42)
    flip:SetFlipBookFrameWidth(0)
    flip:SetFlipBookFrameHeight(0)

    local death = icons:CreateTexture(nil, "OVERLAY", nil, 2)
    death:SetTexture(DEATH_TEX)
    death:SetPoint("CENTER")
    death:Hide()

    local faction = icons:CreateTexture(nil, "OVERLAY", nil, 3)
    faction:SetPoint("CENTER")
    faction:Hide()

    local combat = icons:CreateTexture(nil, "OVERLAY", nil, 3)
    combat:SetTexture(BADGE_COMBAT)
    combat:SetPoint("CENTER")
    combat:Hide()

    -- Marcador de banda (raid target icon) — badge encima del portrait (solo party).
    local raidtarget = icons:CreateTexture(nil, "OVERLAY", nil, 4)
    raidtarget:SetPoint("CENTER")
    raidtarget:Hide()
    -- Bounce suave (como el de combate pero mas leve: menos desplazamiento y mas lento).
    local rtAnim = raidtarget:CreateAnimationGroup()
    rtAnim:SetLooping("REPEAT")
    local rta1 = rtAnim:CreateAnimation("Translation")
    rta1:SetOffset(0, 2); rta1:SetDuration(0.9); rta1:SetOrder(1); rta1:SetSmoothing("OUT")
    local rta2 = rtAnim:CreateAnimation("Translation")
    rta2:SetOffset(0, -2); rta2:SetDuration(0.9); rta2:SetOrder(2); rta2:SetSmoothing("IN")
    u.raidtargetAnim = rtAnim
    -- Fade suave al aparecer/desaparecer (Alpha, independiente del bounce que es Translation).
    local rtFade = raidtarget:CreateAnimationGroup()
    local rtFadeA = rtFade:CreateAnimation("Alpha")
    rtFadeA:SetDuration(0.3); rtFadeA:SetSmoothing("OUT")
    rtFade.anim = rtFadeA
    u.raidtargetFade = rtFade
    u._rtVisible = false

    -- Icono de ROL (tank/heal/dps) y LIDER — badges de party (feature roleLeader). Texturas
    -- CUSTOM: la del rol se asigna por rol en PortraitUpdateRoleLeader; el lider es fija.
    local roleicon = icons:CreateTexture(nil, "OVERLAY", nil, 5)
    roleicon:SetPoint("CENTER")
    roleicon:Hide()
    local leader = icons:CreateTexture(nil, "OVERLAY", nil, 5)
    leader:SetTexture(LEADER_TEX)
    leader:SetPoint("CENTER")
    leader:Hide()
    u.roleicon, u.leader = roleicon, leader

    -- Bounce del badge de combate (bob suave arriba/abajo, en bucle).
    local combatAnim = combat:CreateAnimationGroup()
    combatAnim:SetLooping("REPEAT")
    local ca1 = combatAnim:CreateAnimation("Translation")
    ca1:SetOffset(0, 5); ca1:SetDuration(0.30); ca1:SetOrder(1); ca1:SetSmoothing("OUT")
    local ca2 = combatAnim:CreateAnimation("Translation")
    ca2:SetOffset(0, -5); ca2:SetDuration(0.30); ca2:SetOrder(2); ca2:SetSmoothing("IN")

    u.root, u.editBG, u.bg, u.model, u.classIcon, u.pic, u.icons =
        root, editBG, bg, model, classIcon, pic, icons
    u.cage, u.rest, u.restAnim, u.death, u.faction, u.combat =
        cage, rest, restAnim, death, faction, combat
    u.combatAnim = combatAnim
    u.raidtarget = raidtarget

    root:SetScript("OnDragStart", function(self)
        if unlocked and not InCombatLockdown() then
            u._dragStart = { self:GetCenter() }   -- centro al empezar (para mover seguidores)
            self:StartMoving()
        end
    end)
    root:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if ns.SnapFrameToGrid then ns.SnapFrameToGrid(self) end
        local p = PP(u)
        -- Delta de movimiento (para los seguidores de arrastre).
        local dx, dy = 0, 0
        if u._dragStart then
            local cx, cy = self:GetCenter()
            if cx and u._dragStart[1] then dx, dy = cx - u._dragStart[1], cy - u._dragStart[2] end
        end
        local parentName = (p.editPos == "alt") and p.altAnchor or p.centerAnchor
        local parent = _G[parentName]
        if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
        local s, ps = self:GetEffectiveScale(), parent:GetEffectiveScale()
        local fx, fy = self:GetCenter()
        local px, py = parent:GetCenter()
        if fx and px then
            local ox = (fx * s - px * ps) / s
            local oy = (fy * s - py * ps) / s
            if p.editPos == "alt" then
                p.altPoint, p.altRelPoint, p.altX, p.altY = "CENTER", "CENTER", ox, oy
            else
                p.centerPoint, p.centerRelPoint, p.centerX, p.centerY = "CENTER", "CENTER", ox, oy
            end
        end
        u._posParent = nil   -- StartMoving cambio el ancla real: invalidar el dedupe
        -- Seguidores de arrastre (player/target unit + power siguen al portrait, etc.).
        if ns.MoveFollowers then ns.MoveFollowers(u.key, dx, dy) end
        u._dragStart = nil
        PortraitUpdatePosition(u)
        if ns.OnDragStopped then ns.OnDragStopped(u.key) end
    end)

    -- El click que abre el panel de personaje lo manejan los botones SEGUROS estaticos
    -- `u.charBtnCenter`/`u.charBtnAlt` (ver "Abrir el panel de PERSONAJE" mas abajo). Es la UNICA
    -- via que funciona EN COMBATE: abrir un UIPanel en combate exige ejecucion SEGURA de Blizzard;
    -- ToggleCharacter desde codigo inseguro se BLOQUEA en combate ("Interface action failed
    -- because of an AddOn"). El tooltip de aqui es la red para cuando esos botones estan ocultos
    -- (preview / clickOpenChar off).
    root:SetScript("OnEnter", function(self)
        if unlocked then return end
        local p = PP(u)
        if p and p.clickOpenChar then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Character Info", 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    root:SetScript("OnLeave", function() GameTooltip:Hide() end)

    AttachScaleWheel(u.root, function() return PP(u) end, function() RefreshPortrait(u.key) end)
    portraits[def.key] = u
    return u
end

for _, def in ipairs(PORTRAITS) do CreatePortrait(def) end

-- ==========================================================================
-- AURAS: creacion y logica
-- ==========================================================================
local function AP(g) return db.auras[g.key] end

-- Numero legible (no secreto), o fallback.
local function SafeNum(v, fb)
    if type(v) ~= "number" then return fb end
    if issecretvalue and issecretvalue(v) then return fb end
    return v
end

-- Condicion "engaged": combate / objetivo / instancia (segun toggles). Solo dualPos.
local function AuraCondActive(p)
    local a = false
    if p.centerInCombat and tickState.inCombat then a = true end
    if not a and p.centerOnTarget then if UnitExists("target") then a = true end end
    if not a and p.centerInInstance and safeBool(IsInInstance) then a = true end
    return a
end

-- Opacidad del grupo (solo dualPos = player): base p.groupAlpha; 100% si hay condicion
-- (combate/objetivo/instancia) o si la aura tiene el mouse encima (b._hover).
local function UpdateAuraAlpha(g)
    if not g.dualPos then return end
    local p = AP(g)
    local base = p.groupAlpha or 1
    local full = unlocked or (base >= 1) or AuraCondActive(p)
    for _, b in ipairs(g.buttons) do
        if b:IsShown() then b:SetAlpha((full or b._hover) and 1 or base) end
    end
end

-- Clave de tiempo para ordenar: permanentes (dur 0) al final; secretos al final.
local function AuraTimeKey(d)
    local dur = SafeNum(d.duration, 0)
    if dur == 0 then return math.huge end
    return SafeNum(d.expirationTime, math.huge)
end

local AURA_SORTS = {
    index    = nil,   -- orden de la API
    timeUp   = function(a, b) return AuraTimeKey(a) < AuraTimeKey(b) end,
    timeDown = function(a, b) return AuraTimeKey(a) > AuraTimeKey(b) end,
    name     = function(a, b) return tostring(a.name or "") < tostring(b.name or "") end,
}

-- Recolecta las auras de la unidad combinando buffs + debuffs (secret-safe).
-- Etiqueta cada aura con __filter para el tooltip (HELPFUL/HARMFUL).
local collectScratch = {}   -- tabla reutilizada (se consume sincronamente en UpdateAuraGroup)
local function CollectAuras(unit)
    -- Corre en cada UNIT_AURA: antes creaba una tabla nueva + hasta 80 closures
    -- por pasada (basura para el GC en combate). Ahora: scratch + pcall directo.
    local list = collectScratch
    wipe(list)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return list end
    for f = 1, 2 do
        local filter = (f == 1) and "HELPFUL" or "HARMFUL"
        for i = 1, 40 do
            local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
            if not ok or data == nil then break end
            data.__filter = filter
            list[#list + 1] = data
        end
    end
    return list
end

-- Aplica el cooldown de la aura (duracion). SECRET-SAFE: usa el "duration object"
-- (SetCooldownFromDurationObject); los numeros de cuenta atras los formatea C.
local function ApplyAuraCooldown(cd, unit, data)
    if not cd then return end
    local aid = data.auraInstanceID
    if aid ~= nil and C_UnitAuras and C_UnitAuras.GetAuraDuration and cd.SetCooldownFromDurationObject then
        local ok, durObj = pcall(C_UnitAuras.GetAuraDuration, unit, aid)
        if ok and durObj ~= nil then
            if pcall(cd.SetCooldownFromDurationObject, cd, durObj) then return end
        end
    end
    if cd.SetAuraFallbackData and data.expirationTime ~= nil and data.duration ~= nil then
        if pcall(cd.SetAuraFallbackData, cd, data.expirationTime, data.duration) then return end
    end
    local exp, dur = SafeNum(data.expirationTime, nil), SafeNum(data.duration, nil)
    if exp and dur and dur > 0 then cd:SetCooldown(exp - dur, dur)
    elseif cd.Clear then cd:Clear() end
end

local function AbbreviateTime(t)
    if t >= 3600 then return string.format("%.0fh", t / 3600) end
    if t >= 60   then return string.format("%.0fm", t / 60) end
    if t >= 10   then return string.format("%.0f", t) end
    if t >= 0    then return string.format("%.1f", t) end
    return ""
end

-- Actualiza el texto de duracion (SECRET-SAFE): el "duration object" tiene
-- EvaluateRemainingTime, que devuelve el restante como numero LEGIBLE aunque la
-- expiracion cruda sea secreta (Blizzard permite MOSTRARlo, no operar con el).
local function UpdateAuraButtonTime(b)
    if not b.dur then return end
    if not b._showDur then b.dur:SetText("") return end
    local remaining
    local obj = b._durObj
    if obj and obj.EvaluateRemainingTime then
        local ok, v = pcall(obj.EvaluateRemainingTime, obj)
        if ok and type(v) == "number" and not (issecretvalue and issecretvalue(v)) then remaining = v end
    end
    if remaining == nil and b._fbExp and b._fbDur and b._fbDur > 0 then
        remaining = b._fbExp - GetTime()
    end
    if remaining and remaining > 0 then b.dur:SetText(AbbreviateTime(remaining))
    else b.dur:SetText("") end
end

-- Overlay SEGURO para cancelar buffs con clic derecho. Va encima del icono,
-- anclado con SetAllPoints (sigue al boton sin reposicionarse), asi el layout
-- del grid (frame normal) sigue funcionando en combate. Solo el macrotext se
-- actualiza (fuera de combate). Crear frames seguros esta bloqueado en combate,
-- por eso se difiere via EnsureCancelOverlay en PLAYER_REGEN_ENABLED.
-- Host ESTATICO para los overlays seguros: nunca se mueve ni se oculta por el
-- layout, asi la jerarquia de los grupos de aura NO contiene frames seguros y
-- se puede reposicionar en combate sin taint.
local auraCancelHost

-- Posiciona el overlay SOBRE el boton con coordenadas ABSOLUTAS respecto a
-- UIParent, SIN anclarlo al boton. Anclarlo (SetPoint/SetAllPoints al boton)
-- crearia una dependencia de posicion: mover el grupo de auras en combate
-- moveria el overlay (protegido) → taint. Como no hay ancla, g.root se mueve
-- libre en combate. Solo se llama FUERA de combate (mover un frame seguro en
-- combate esta bloqueado). Ajusta por diferencia de escala.
local function PositionCancelOverlay(c, b)
    local w, h = b:GetSize()
    local l, bottom = b:GetLeft(), b:GetBottom()
    if not (w and w > 0 and l and bottom) then return end
    local cs = c:GetEffectiveScale()
    if not (cs and cs > 0) then return end
    local k = b:GetEffectiveScale() / cs
    c:SetSize(w * k, h * k)
    c:ClearAllPoints()
    c:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * k, bottom * k)
end

local function EnsureCancelOverlay(b)
    if b.cancel or InCombatLockdown() then return end
    if not auraCancelHost then
        auraCancelHost = CreateFrame("Frame", "MyCF_AuraCancelHost", UIParent)
        auraCancelHost:SetFrameStrata("HIGH")
    end
    -- Parentado al host y SIN ancla al boton (ver PositionCancelOverlay).
    local c = CreateFrame("Button", nil, auraCancelHost, "SecureActionButtonTemplate")
    c:SetFrameStrata("HIGH")
    c:SetToplevel(true)
    c:SetFrameLevel(50)
    c:RegisterForClicks("RightButtonUp", "RightButtonDown")
    c:SetAttribute("type2", "macro")
    c:EnableMouse(true)
    -- Deja pasar el movimiento del raton al icono de abajo (para el tooltip/hover).
    if c.SetPropagateMouseMotion then c:SetPropagateMouseMotion(true) end
    c:Hide()
    b.cancel = c
end

local function CreateAuraButton(g)
    local b = CreateFrame("Frame", nil, g.root)
    b:SetSize(30, 30)
    b._group = g

    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints(b)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.icon = icon

    -- Swipe radial (secret-safe via SetCooldownFromDurationObject).
    local swipe = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    swipe:SetAllPoints(b)
    swipe:SetDrawEdge(false)
    if swipe.SetHideCountdownNumbers then swipe:SetHideCountdownNumbers(true) end
    swipe:SetFrameLevel(b:GetFrameLevel() + 1)
    swipe:EnableMouse(false)   -- no debe robar el clic del overlay de cancelar
    b.swipe = swipe

    -- Borde (encima del icono/swipe).
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture(AURA_BORDER)
    b.border = border

    -- Los textos (duracion/contador) van en un frame POR ENCIMA del swipe (Cooldown = b+1)
    -- para que siempre queden DELANTE del swipe radial (antes quedaban detras).
    local textOverlay = CreateFrame("Frame", nil, b)
    textOverlay:SetAllPoints(b)
    textOverlay:SetFrameLevel(b:GetFrameLevel() + 2)
    b.textOverlay = textOverlay

    -- Texto de duracion: fontstring PROPIO (posicionable con offset GLOBAL del grupo).
    local dur = textOverlay:CreateFontString(nil, "OVERLAY")
    dur:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    dur:SetTextColor(1, 0.82, 0.2, 1)
    b.dur = dur

    -- Contador de acumulaciones.
    local count = textOverlay:CreateFontString(nil, "OVERLAY")
    count:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, 0)
    count:SetTextColor(1, 1, 1, 1)
    b.count = count

    -- Hover: sube la opacidad de ESA aura (grupos dualPos) + tooltip (secret-safe).
    b:SetScript("OnEnter", function(self)
        self._hover = true
        if self._group and self._group.dualPos then UpdateAuraAlpha(self._group) end
        if not (self._showTip and self._auraID and self._unit) then return end
        if GameTooltip:IsForbidden() or not self:IsVisible() then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local ok
        if GameTooltip.SetUnitAuraByAuraInstanceID then
            ok = pcall(GameTooltip.SetUnitAuraByAuraInstanceID, GameTooltip, self._unit, self._auraID)
        end
        if not ok then
            if self._filter == "HARMFUL" and GameTooltip.SetUnitDebuffByAuraInstanceID then
                ok = pcall(GameTooltip.SetUnitDebuffByAuraInstanceID, GameTooltip, self._unit, self._auraID)
            elseif GameTooltip.SetUnitBuffByAuraInstanceID then
                ok = pcall(GameTooltip.SetUnitBuffByAuraInstanceID, GameTooltip, self._unit, self._auraID)
            end
        end
        if ok then GameTooltip:Show() else GameTooltip:Hide() end
    end)
    b:SetScript("OnLeave", function(self)
        self._hover = false
        if self._group and self._group.dualPos then UpdateAuraAlpha(self._group) end
        if not GameTooltip:IsForbidden() then GameTooltip:Hide() end
    end)

    EnsureCancelOverlay(b)
    return b
end

local function StyleAuraButton(b, g, p, data, iconSize)
    b:SetSize(iconSize, iconSize)

    if p.showBorder then
        local inset = iconSize * (p.borderScale or 0.16)
        b.border:SetTexture((p.borderTexture and p.borderTexture ~= "" and p.borderTexture) or AURA_BORDER)
        b.border:SetVertexColor(p.borderColor.r, p.borderColor.g, p.borderColor.b, p.borderAlpha or 1)
        b.border:ClearAllPoints()
        b.border:SetPoint("TOPLEFT", b, "TOPLEFT", -inset, inset)
        b.border:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", inset, -inset)
        b.border:Show()
    else
        b.border:Hide()
    end

    -- Color del texto (duracion + contador).
    local tc = p.textColor or { r = 1, g = 0.82, b = 0.2 }
    b.count:SetFont("Fonts\\FRIZQT__.TTF", p.countFontSize or 12, "OUTLINE")
    b.count:SetTextColor(tc.r, tc.g, tc.b, 1)

    -- Texto de duracion: fuente + color + posicion (centrado + offset GLOBAL del grupo).
    b.dur:SetFont("Fonts\\FRIZQT__.TTF", p.durationFontSize or 12, "OUTLINE")
    b.dur:SetTextColor(tc.r, tc.g, tc.b, 1)
    b.dur:ClearAllPoints()
    b.dur:SetPoint("CENTER", b, "CENTER", p.durationOffsetX or 0, p.durationOffsetY or 0)
    b._showDur = p.showDuration and true or false

    b.swipe:SetShown(p.showSwipe and true or false)

    -- Mouse fuera de preview si: tooltip activo, o hover-alpha (grupo dualPos con base <1).
    -- D: si este grupo PARTICIPA en el Explorer (y esta activo), se DESACTIVA su mouseover
    -- (tooltip/hover) para que revelar por mouseover no dispare tooltip. El clic-derecho de
    -- cancelar buff es un overlay seguro aparte (no afectado por este EnableMouse).
    b._showTip = p.showTooltip and true or false
    local inExplorer = db.explorerEnabled ~= false and db.explorer and db.explorer[g.key] and true or false
    local wantHover = (p.showTooltip or (g.dualPos and (p.groupAlpha or 1) < 1)) and not inExplorer
    b:EnableMouse((not unlocked) and wantHover and true or false)
    b._unit, b._filter = g.unit, data.__filter

    -- Clic derecho para cancelar: SOLO buffs propios del player. No se tocan
    -- atributos/visibilidad de frames seguros en combate (queda el ultimo estado
    -- previo al combate; un buff nuevo en combate no sera cancelable hasta salir).
    if b.cancel and not InCombatLockdown() then
        -- SECRET-SAFE: el nombre (y el spellId) de un buff pueden ser SECRETOS en
        -- Midnight. NUNCA comparar el nombre salvo con nil o TRAS confirmar que no
        -- es secreto (comparar un secreto = taint/crash). Sin nombre legible no se
        -- puede construir "/cancelaura <nombre>", asi que esa aura no es cancelable.
        -- type() e issecretvalue() son seguros sobre secretos; NO comparar con nil
        -- ni con "" hasta CONFIRMAR que el valor no es secreto.
        local name = data and data.name
        local usable = false
        if type(name) == "string" and not (issecretvalue and issecretvalue(name)) then
            usable = (name ~= "")   -- seguro: name ya es legible
        end
        -- Fallback por spellId, solo si es legible.
        if not usable then
            local sid = data and data.spellId
            if type(sid) == "number" and not (issecretvalue and issecretvalue(sid)) and C_Spell and C_Spell.GetSpellName then
                local ok, sn = pcall(C_Spell.GetSpellName, sid)
                if ok and type(sn) == "string" and not (issecretvalue and issecretvalue(sn)) and sn ~= "" then
                    name = sn
                    usable = true
                end
            end
        end
        local canCancel = (not unlocked) and (not data.__preview)
            and g.unit == "player" and data.__filter == "HELPFUL"
            and p.allowCancel and usable
        if canCancel then
            b.cancel:SetAttribute("macrotext2", "/cancelaura " .. name)
            PositionCancelOverlay(b.cancel, b)
            b.cancel:Show()
        else
            b.cancel:SetAttribute("macrotext2", "")
            b.cancel:Hide()
        end
    end

    -- Preview: icono de muestra + tiempo falso legible.
    if data.__preview then
        b._auraID = nil
        b.icon:SetTexture(AURA_PREVIEW_ICON)
        b.count:SetText((data.__count and data.__count > 1) and tostring(data.__count) or "")
        b._durObj, b._fbExp, b._fbDur = nil, GetTime() + 12, 12
        if p.showSwipe then b.swipe:SetCooldown(GetTime() - 2, 14) end
        UpdateAuraButtonTime(b)
        return
    end

    b._auraID = data.auraInstanceID
    -- Icono: data.icon puede ser secreto — NUNCA testearlo con or/and (solo comparar
    -- con nil); SetTexture lo acepta en C. pcall directo, sin closure.
    local icon = data.icon
    if icon == nil then icon = 134400 end
    pcall(b.icon.SetTexture, b.icon, icon)

    local cnt = SafeNum(data.applications, 0)
    if p.showCount and cnt and cnt > 1 then b.count:SetText(cnt) else b.count:SetText("") end

    if p.showSwipe then ApplyAuraCooldown(b.swipe, g.unit, data)
    elseif b.swipe.Clear then b.swipe:Clear() end

    -- Guarda el duration object (o fallback legible) para el ticker del texto.
    b._durObj, b._fbExp, b._fbDur = nil, nil, nil
    if p.showDuration then
        local aid = data.auraInstanceID
        if aid ~= nil and C_UnitAuras and C_UnitAuras.GetAuraDuration then
            local ok, durObj = pcall(C_UnitAuras.GetAuraDuration, g.unit, aid)
            if ok then b._durObj = durObj end
        end
        b._fbExp = SafeNum(data.expirationTime, nil)
        b._fbDur = SafeNum(data.duration, nil)
    end
    UpdateAuraButtonTime(b)
end

-- Coloca el frame ancla del grupo. Los grupos dualPos (player) tienen 3 posiciones:
-- muerte (player muerto, prioridad), principal (condicion cumplida) y alterna (el resto).
-- En preview se usa editPos ("center"/"alt"/"dead").
local function AuraGroupPlace(g)
    local p = AP(g)
    CompensateScale(p, "aura")   -- B3: reancla offsets si la escala cambio
    local anchor, point, relPoint, x, y = p.anchor, p.point, p.relPoint, p.offsetX, p.offsetY
    if g.dualPos then
        local which
        if unlocked then
            which = p.editPos or "center"
        else
            local dead = safeBool(UnitIsDeadOrGhost, "player")
            if p.useDeadPos and dead then
                which = UnitExists("target") and "deadTarget" or "dead"
            elseif AuraCondActive(p) then which = "center"
            else which = "alt" end
        end
        if which == "alt" then
            anchor, point, relPoint, x, y = p.altAnchor, p.altPoint, p.altRelPoint, p.altX, p.altY
        elseif which == "dead" then
            anchor, point, relPoint, x, y = p.deadAnchor, p.deadPoint, p.deadRelPoint, p.deadX, p.deadY
        elseif which == "deadTarget" then
            anchor, point, relPoint, x, y = p.deadTargetAnchor, p.deadTargetPoint, p.deadTargetRelPoint, p.deadTargetX, p.deadTargetY
        end
        -- Offset extra si hay pet: se SUMA a la posicion viva. Cada posicion tiene su PROPIO
        -- offset (center → petOffsetX/Y, alt → petOffsetXAlt/YAlt). Solo en vivo (en preview se
        -- editan las posiciones base). Se aplica ANTES del dedupe → si el pet aparece/desaparece,
        -- x/y cambian y AuraGroupPlace re-coloca solo. nil-safe (perfiles viejos).
        if not unlocked and UnitExists("pet") then
            local pox, poy
            if which == "center" then
                pox, poy = p.petOffsetX or 0, p.petOffsetY or 0
            elseif which == "alt" then
                pox, poy = p.petOffsetXAlt or 0, p.petOffsetYAlt or 0
            end
            if pox and (pox ~= 0 or poy ~= 0) then
                x = x + pox
                y = y + poy
            end
        end
    end
    local parent = _G[anchor]
    if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
    local scale = p.scale or 1
    -- Dedupe: los grupos dualPos se re-colocaban cada tick con los mismos valores
    -- (ClearAllPoints+SetPoint+strata+escala). Firma = ultimo aplicado (datos propios).
    -- El OnDragStop invalida (_posParent=nil) porque StartMoving cambia el ancla real.
    if g._posParent == parent and g._posP == point and g._posRP == relPoint
       and g._posX == x and g._posY == y
       and g._posStrata == p.strata and g._posScale == scale then return end
    g.root:ClearAllPoints()
    g.root:SetPoint(point, parent, relPoint, x, y)
    g.root:SetFrameStrata(p.strata)
    g.root:SetScale(scale)   -- escala general del grupo de auras
    g._posParent, g._posP, g._posRP, g._posX, g._posY, g._posStrata, g._posScale =
        parent, point, relPoint, x, y, p.strata, scale
end

-- Reconstruye el grid: "centrado horizontal, luego hacia abajo".
local function UpdateAuraGroup(g)
    local p = AP(g)
    AuraGroupPlace(g)

    if not (p.enabled or unlocked) then
        g.root:Hide()
        for _, b in ipairs(g.buttons) do
            b:Hide()
            if b.cancel and not InCombatLockdown() then b.cancel:Hide() end
        end
        return
    end
    g.root:Show()
    if g.editBG then g.editBG:SetShown(unlocked and not (db and db.hideEditGreen)) end

    local list
    if unlocked then
        list = {}
        local sample = math.min(math.max(p.limit or 8, 1), 10)
        for i = 1, sample do list[i] = { __preview = true, __count = (i % 3 == 0) and 3 or 1 } end
    else
        list = CollectAuras(g.unit)
        local cmp = AURA_SORTS[p.sort]
        if cmp then pcall(table.sort, list, cmp) end
    end

    local limit    = math.max(1, p.limit or 32)
    local n        = math.min(#list, limit)
    local perRow   = math.max(1, p.perRow or 8)
    local iconSize = math.max(4, p.iconSize or 30)
    local colSpace = p.colSpace or 4
    local rowSpace = p.rowSpace or 8

    for i = 1, n do
        local b = g.buttons[i]
        if not b then b = CreateAuraButton(g); g.buttons[i] = b end
        local idx = i - 1
        local row = math.floor(idx / perRow)
        local col = idx % perRow
        local itemsThisRow = math.min(perRow, n - row * perRow)
        local rowW = itemsThisRow * iconSize + (itemsThisRow - 1) * colSpace
        local startX = -rowW / 2 + iconSize / 2
        local x = startX + col * (iconSize + colSpace)
        local y = -row * (iconSize + rowSpace)
        b:ClearAllPoints()
        b:SetPoint("CENTER", g.root, "CENTER", x, y)
        StyleAuraButton(b, g, p, list[i], iconSize)
        b:Show()
    end
    for i = n + 1, #g.buttons do
        g.buttons[i]:Hide()
        local bc = g.buttons[i].cancel
        if bc and not InCombatLockdown() then bc:Hide() end
    end
    UpdateAuraAlpha(g)
end

local function RefreshAura(key)
    local g = auras[key]
    if g then UpdateAuraGroup(g) end
end
ns.RefreshAura = RefreshAura

local function RefreshAllAuras()
    for _, g in pairs(auras) do UpdateAuraGroup(g) end
end
ns.RefreshAllAuras = RefreshAllAuras

local function CreateAuraGroup(def)
    local g = { key = def.key, unit = def.unit, label = def.label, dualPos = def.dualPos, buttons = {} }

    local root = CreateFrame("Frame", "MyCF_Aura_" .. def.key, UIParent)
    root:SetSize(40, 40)
    root:SetPoint("CENTER")
    root:SetMovable(true)
    root:RegisterForDrag("LeftButton")
    root:EnableMouse(false)

    local editBG = MakeEditHighlight(root, "Aura " .. (def.label or def.key))
    g.root, g.editBG = root, editBG

    root:SetScript("OnDragStart", function(self)
        if unlocked and not InCombatLockdown() then self:StartMoving() end
    end)
    root:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if ns.SnapFrameToGrid then ns.SnapFrameToGrid(self) end
        local p = AP(g)
        local which = g.dualPos and (p.editPos or "center") or "center"
        local anchorName = (which == "alt" and p.altAnchor) or (which == "dead" and p.deadAnchor)
            or (which == "deadTarget" and p.deadTargetAnchor) or p.anchor
        local parent = _G[anchorName]
        if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
        local s, ps = self:GetEffectiveScale(), parent:GetEffectiveScale()
        local fx, fy = self:GetCenter()
        local px, py = parent:GetCenter()
        if fx and px then
            local ox = (fx * s - px * ps) / s
            local oy = (fy * s - py * ps) / s
            if which == "alt" then p.altPoint, p.altRelPoint, p.altX, p.altY = "CENTER", "CENTER", ox, oy
            elseif which == "dead" then p.deadPoint, p.deadRelPoint, p.deadX, p.deadY = "CENTER", "CENTER", ox, oy
            elseif which == "deadTarget" then p.deadTargetPoint, p.deadTargetRelPoint, p.deadTargetX, p.deadTargetY = "CENTER", "CENTER", ox, oy
            else p.point, p.relPoint, p.offsetX, p.offsetY = "CENTER", "CENTER", ox, oy end
        end
        g._posParent = nil   -- StartMoving cambio el ancla real: invalidar el dedupe
        AuraGroupPlace(g)
        if ns.OnDragStopped then ns.OnDragStopped(g.key) end
    end)

    AttachScaleWheel(g.root, function() return db.auras[g.key] end, function() AuraGroupPlace(g) end)
    auras[def.key] = g
    return g
end

for _, def in ipairs(AURAS) do CreateAuraGroup(def) end

-- ==========================================================================
-- INFO BAR: creacion y logica
-- ==========================================================================
local function InfoZoneText()
    local zone = GetMinimapZoneText() or ""
    if type(zone) ~= "string" then zone = "" end
    if #zone > 25 then zone = zone:sub(1, 25) .. "..." end
    return zone
end

local function InfoTimeText()
    local h, m = 0, 0
    pcall(function() h, m = GetGameTime() end)
    h = h or 0; m = m or 0
    local suffix = "AM"
    if h >= 12 then suffix = "PM"; if h > 12 then h = h - 12 end
    elseif h == 0 then h = 12 end
    return string.format("%d:%02d %s", h, m, suffix)
end

local function UpdateInfoBarValues()
    if not (infobar and db and db.infobar) then return end
    local p = db.infobar
    infobar.zone.fs:SetText(InfoZoneText())
    infobar.time.fs:SetText(InfoTimeText())
    local fps = safeVal(GetFramerate) or 0
    infobar.fps.fs:SetFormattedText("%.0f FPS", fps)
    local world = 0; pcall(function() local _, _, _, w = GetNetStats(); world = w or 0 end)
    infobar.ms.fs:SetFormattedText("%.0f MS", world)
    -- Ajusta el tamano de cada elemento a su texto (area de arrastre/mouse).
    local hgt = (p.fontSize or 14) + 6
    for _, el in ipairs({ infobar.zone, infobar.time, infobar.fps, infobar.ms }) do
        el:SetSize(math.max((el.fs:GetStringWidth() or 10) + 8, 12), hgt)
    end
end

local function InfoBarPlace()
    local p = db.infobar
    CompensateScale(p, "simple")   -- B3: reancla offset si la escala cambio
    local parent = _G[p.anchor]
    if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
    infobar.root:ClearAllPoints()
    infobar.root:SetPoint(p.point, parent, p.relPoint, p.offsetX, p.offsetY)
    infobar.root:SetFrameStrata(p.strata)
end

local function RefreshInfoBar()
    if not (infobar and db and db.infobar) then return end
    local p, ib = db.infobar, infobar
    ib.root:SetSize(math.max(p.bgWidth, 60), math.max((p.fontSize or 14) + 24, 30))
    ib.root:SetScale(p.scale or 1)   -- escala general del info bar
    InfoBarPlace()

    -- Fondo decorativo (atlas del juego).
    if p.showBg then
        -- Textura custom (.tga/.blp) o, si se escribe un nombre sin extension, un atlas.
        local btex = (p.bgTexture and p.bgTexture ~= "" and p.bgTexture) or INFOBAR_BG_TEX
        local ext = tostring(btex):sub(-4):lower()
        if ext == ".tga" or ext == ".blp" then
            pcall(function() ib.bg:SetTexture(btex) end)
        else
            pcall(function() ib.bg:SetAtlas(btex, false) end)
        end
        ib.bg:SetSize(p.bgWidth, p.bgHeight)
        ib.bg:ClearAllPoints(); ib.bg:SetPoint("CENTER", ib.root, "CENTER", p.bgOffsetX, p.bgOffsetY)
        ib.bg:SetAlpha(p.bgAlpha); ib.bg:Show()
    else
        ib.bg:Hide()
    end

    local gtc = p.textColor or { r = 1, g = 0.82, b = 0 }
    -- B9: cada elemento usa su Color/Alpha/Size propios; si son nil, cae al global.
    local function setupEl(el, show, prefix)
        local size = p[prefix .. "Size"] or p.fontSize or 14
        local col  = p[prefix .. "Color"] or gtc
        local a    = p[prefix .. "Alpha"]; if a == nil then a = 1 end
        el.fs:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
        el.fs:SetTextColor(col.r, col.g, col.b, a)
        el._xKey, el._yKey = prefix .. "X", prefix .. "Y"
        el:ClearAllPoints()
        el:SetPoint("CENTER", ib.root, "CENTER", p[el._xKey] or 0, p[el._yKey] or 0)
        el:SetShown(show)
        -- Mouse: el reloj/calendario siempre; el resto solo en preview (arrastre).
        el:EnableMouse(unlocked or el._isClock or false)
    end
    setupEl(ib.zone, p.showZone, "zone")
    setupEl(ib.time, p.showTime, "time")
    setupEl(ib.fps,  p.showFps,  "fps")
    setupEl(ib.ms,   p.showMs,   "ms")

    -- (Botones de calendario y mochila ELIMINADOS: el calendario ahora se abre clickeando el reloj.)

    if ib.editBG then ib.editBG:SetShown(unlocked and not db.hideEditGreen) end
    ib.root:SetShown(p.enabled or unlocked)
    UpdateInfoBarValues()
end
ns.RefreshInfoBar = RefreshInfoBar

-- Guarda la posicion actual del root (mover TODO junto).
local function SaveInfoRootPos()
    local p = db.infobar
    local parent = _G[p.anchor]
    if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
    local s, ps = infobar.root:GetEffectiveScale(), parent:GetEffectiveScale()
    local fx, fy = infobar.root:GetCenter()
    local px, py = parent:GetCenter()
    if fx and px then
        p.point, p.relPoint = "CENTER", "CENTER"
        p.offsetX = (fx * s - px * ps) / s
        p.offsetY = (fy * s - py * ps) / s
    end
end

local function MakeInfoElement(root, isClock)
    local el = CreateFrame(isClock and "Button" or "Frame", nil, root)
    el:SetSize(40, 20)
    el:SetMovable(true)
    el:RegisterForDrag("LeftButton")
    el:EnableMouse(false)
    el._isClock = isClock
    local fs = el:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    fs:SetPoint("CENTER")
    el.fs = fs

    el:SetScript("OnDragStart", function(self)
        if not unlocked or InCombatLockdown() then return end
        if db.infobar.moveTogether then infobar.root:StartMoving()
        else self:StartMoving() end
    end)
    el:SetScript("OnDragStop", function(self)
        if db.infobar.moveTogether then
            infobar.root:StopMovingOrSizing()
            SaveInfoRootPos()
        else
            self:StopMovingOrSizing()
            local p = db.infobar
            local ex, ey = self:GetCenter()
            local rx, ry = infobar.root:GetCenter()
            if ex and rx and self._xKey then
                p[self._xKey] = ex - rx
                p[self._yKey] = ey - ry
            end
        end
        RefreshInfoBar()
        if ns.OnDragStopped then ns.OnDragStopped(INFOBAR_KEY) end
    end)
    return el
end

local function CreateInfoBar()
    local root = CreateFrame("Frame", "MyCF_InfoBar", UIParent)
    root:SetSize(360, 40)
    root:SetPoint("TOP", UIParent, "TOP", 0, -4)
    root:SetMovable(true)
    root:RegisterForDrag("LeftButton")
    root:EnableMouse(false)

    local editBG = MakeEditHighlight(root, "Info Bar")

    local bg = root:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetPoint("CENTER")

    local ib = { root = root, editBG = editBG, bg = bg }
    ib.zone = MakeInfoElement(root, false)
    ib.time = MakeInfoElement(root, true)   -- reloj: display + tooltip de hora (calendario = boton aparte)
    ib.fps  = MakeInfoElement(root, false)
    ib.ms   = MakeInfoElement(root, false)

    -- (Botones de calendario y mochila ELIMINADOS. El calendario se abre clickeando el reloj.)

    -- El root tambien se puede arrastrar (mover TODO) por su zona libre.
    root:SetScript("OnDragStart", function(self)
        if unlocked and not InCombatLockdown() then self:StartMoving() end
    end)
    root:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if ns.SnapFrameToGrid then ns.SnapFrameToGrid(self) end
        SaveInfoRootPos(); RefreshInfoBar()
        if ns.OnDragStopped then ns.OnDragStopped(INFOBAR_KEY) end
    end)
    AttachScaleWheel(root, function() return db.infobar end, function() if ns.RefreshInfoBar then ns.RefreshInfoBar() end end)

    -- Reloj: tooltip (reino/hora) + CLICK abre el calendario (patron de AzeriteUI Info.lua:
    -- Time_OnClick = ToggleCalendar() con guard InCombatLockdown). Es seguro ahora que la fuente
    -- real del taint global (`StaticPopupDialogs = StaticPopupDialogs or {}` en ProfilesApply, quitada
    -- en la tanda 8) ya no envenena StaticPopupDialogs: cargar Blizzard_Calendar on-demand lee una
    -- tabla LIMPIA → sin propagacion (por eso AzeriteUI, que nunca taintea ese global, lo hace sin
    -- problema). Guards: solo fuera de combate y si ToggleCalendar existe. NO en preview (unlocked).
    ib.time:RegisterForClicks("AnyUp")
    ib.time:SetScript("OnClick", function()
        if unlocked or InCombatLockdown() then return end
        if ToggleCalendar then pcall(ToggleCalendar) end
    end)
    ib.time:SetScript("OnEnter", function(self)
        if unlocked or GameTooltip:IsForbidden() then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(TIMEMANAGER_TOOLTIP_TITLE or "Hora", 1, 0.82, 0)
        pcall(function() GameTooltip:AddDoubleLine(TIMEMANAGER_TOOLTIP_LOCALTIME or "Local", date("%I:%M %p")) end)
        pcall(function() local h, m = GetGameTime(); GameTooltip:AddDoubleLine(TIMEMANAGER_TOOLTIP_REALMTIME or "Servidor", string.format("%d:%02d", h or 0, m or 0)) end)
        pcall(function() local r = GetRealmName(); if r and r ~= "" then GameTooltip:AddDoubleLine("Reino", r, 1, 1, 1, 1, 1, 1) end end)
        if ToggleCalendar then
            GameTooltip:AddLine("<" .. (GAMETIME_TOOLTIP_TOGGLE_CALENDAR or "Toggle Calendar") .. ">", 0.1, 1, 0.1)
        end
        GameTooltip:Show()
    end)
    ib.time:SetScript("OnLeave", function() if not GameTooltip:IsForbidden() then GameTooltip:Hide() end end)

    infobar = ib
    ns.infobar = ib
end

CreateInfoBar()

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
        local p = PP(u)
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

-- ==========================================================================
-- MODO EDICION / PREVIEW
-- ==========================================================================
-- Grid de alineacion (solo en modo Lock), estilo addon "eAlignUpdated": divide la PANTALLA
-- en 64 columnas x 36 filas (proporcional; en 16:9 las celdas salen cuadradas), con la CRUZ
-- CENTRAL (columna 32 / fila 18) resaltada en amarillo. El snap usa las MISMAS lineas.
-- Overlay NO seguro.
local GRID_COLS, GRID_ROWS = 64, 36
local gridFrame
local function UpdateGrid()
    if not db then return end
    local show = unlocked and db.gridShow
    if not gridFrame then
        if not show then return end
        gridFrame = CreateFrame("Frame", nil, UIParent)
        gridFrame:SetAllPoints(UIParent)
        gridFrame:SetFrameStrata("BACKGROUND")
        gridFrame.lines = {}
    end
    for _, t in ipairs(gridFrame.lines) do t:Hide() end
    if not show then gridFrame:Hide(); return end
    gridFrame:Show()
    local w = GetScreenWidth() / GRID_COLS    -- ancho de celda (unidades UIParent)
    local h = GetScreenHeight() / GRID_ROWS   -- alto de celda
    local idx = 0
    local function getLine()
        idx = idx + 1
        local t = gridFrame.lines[idx]
        if not t then t = gridFrame:CreateTexture(nil, "BACKGROUND"); gridFrame.lines[idx] = t end
        return t
    end
    -- Verticales (64 columnas + borde); la central (32) en amarillo.
    for i = 0, GRID_COLS do
        local t = getLine()
        if i == GRID_COLS / 2 then t:SetColorTexture(1, 1, 0, 0.5) else t:SetColorTexture(1, 1, 1, 0.15) end
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", i * w - 1, 0)
        t:SetPoint("BOTTOMRIGHT", gridFrame, "BOTTOMLEFT", i * w + 1, 0)
        t:Show()
    end
    -- Horizontales (36 filas + borde); la central (18) en amarillo.
    for i = 0, GRID_ROWS do
        local t = getLine()
        if i == GRID_ROWS / 2 then t:SetColorTexture(1, 1, 0, 0.5) else t:SetColorTexture(1, 1, 1, 0.15) end
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", 0, -i * h + 1)
        t:SetPoint("BOTTOMRIGHT", gridFrame, "TOPRIGHT", 0, -i * h - 1)
        t:Show()
    end
end
ns.UpdateGrid = UpdateGrid

-- B2 — Snap ENTRE ELEMENTOS (estilo EditMode): al soltar, si un borde/centro del frame
-- queda cerca (umbral) del borde/centro de OTRO elemento, se alinea exactamente con él.
-- Recolecta las lineas candidatas (izq/der/centroX = verticales; abajo/arriba/centroY =
-- horizontales) de todos los elementos movibles visibles, en pixeles de pantalla.
local SNAP_THRESHOLD = 12   -- px de pantalla para "engancharse"
local function CollectSnapLines(exclude)
    local vx, hy = {}, {}
    local function add(fr)
        if not fr or fr == exclude or not fr:IsShown() then return end
        local esc = fr:GetEffectiveScale(); if not (esc and esc > 0) then return end
        local l, r, cx = fr:GetLeft(), fr:GetRight(), fr:GetCenter()
        local b, t = fr:GetBottom(), fr:GetTop()
        local _, cy = fr:GetCenter()
        if l and r and cx then vx[#vx + 1] = l * esc; vx[#vx + 1] = r * esc; vx[#vx + 1] = cx * esc end
        if b and t and cy then hy[#hy + 1] = b * esc; hy[#hy + 1] = t * esc; hy[#hy + 1] = cy * esc end
    end
    for _, u in pairs(frames) do add(u.button) end
    for _, u in pairs(portraits) do add(u.root) end
    for _, g in pairs(auras) do add(g.root) end
    if infobar then add(infobar.root) end
    if ns.micromenu then add(ns.micromenu) end
    return vx, hy
end
-- Menor delta (line - ref) en magnitud dentro del umbral, o nil.
local function NearestLine(refs, lines, thr)
    local best, bestAbs
    for i = 1, #refs do
        local ref = refs[i]
        for j = 1, #lines do
            local d = lines[j] - ref
            local a = d >= 0 and d or -d
            if a <= thr and (not bestAbs or a < bestAbs) then best, bestAbs = d, a end
        end
    end
    return best
end

-- Snap AL SOLTAR: primero entre elementos (por eje), luego grilla en los ejes sin match.
-- Se llama en cada OnDragStop ANTES de calcular el offset guardado, asi queda alineado.
-- Trabaja en pixeles absolutos (via EffectiveScale) para soportar elementos escalados.
local function SnapFrameToGrid(frame)
    if not (db and unlocked) then return end
    local es = frame:GetEffectiveScale()
    local uies = UIParent:GetEffectiveScale()
    local fx, fy = frame:GetCenter()
    if not (fx and es and uies and es > 0 and uies > 0) then return end
    local fpx, fpy = fx * es, fy * es               -- centro del frame (px abs)
    local nx, ny = fpx, fpy
    local snappedX, snappedY = false, false

    -- 1) Snap ENTRE ELEMENTOS (bordes/centros).
    if db.snapElements then
        local l, r = frame:GetLeft(), frame:GetRight()
        local b, t = frame:GetBottom(), frame:GetTop()
        if l and r and b and t then
            local vx, hy = CollectSnapLines(frame)
            local dx = NearestLine({ l * es, r * es, fpx }, vx, SNAP_THRESHOLD)
            local dy = NearestLine({ b * es, t * es, fpy }, hy, SNAP_THRESHOLD)
            if dx then nx = fpx + dx; snappedX = true end
            if dy then ny = fpy + dy; snappedY = true end
        end
    end

    -- 2) Snap A GRILLA (64x36, mismo que dibuja UpdateGrid) para los ejes sin match de elemento.
    -- Celda en px abs: ancho = screenWpx/64, alto = screenHpx/36. Origen esquina (0,0). Asi el
    -- snap cae exactamente sobre las lineas del grid de eAlign.
    if db.gridSnap then
        local cw = (GetScreenWidth() * uies) / GRID_COLS
        local ch = (GetScreenHeight() * uies) / GRID_ROWS
        if not snappedX and cw > 0 then nx = math.floor(fpx / cw + 0.5) * cw end
        if not snappedY and ch > 0 then ny = math.floor(fpy / ch + 0.5) * ch end
    end

    if nx == fpx and ny == fpy then return end
    frame:ClearAllPoints()
    -- Los offsets de SetPoint van en la escala DEL FRAME (posicion abs = offset * es).
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", nx / es, ny / es)
end
ns.SnapFrameToGrid = SnapFrameToGrid

local function SetUnlocked(state)
    if InCombatLockdown() then
        print("|cffff0000[MCF]|r You can't edit in combat.")
        return
    end
    unlocked = state
    local hideGreen = db and db.hideEditGreen
    for _, u in pairs(frames) do
        if u.key == "focus" then
            -- El focus NO se edita como unitframe: su layout vive en el portrait_focus.
            -- Nunca muestra outline ni se arrastra; mantiene su unit watch (area de click
            -- para el menu contextual + texto de vida/highlight, posicionados sobre el
            -- portrait por SyncFocusButton). Asi el "focus heredado" no aparece en el Lock.
            u.editBG:Hide()
            u.button:EnableMouseWheel(false)
            u.button:RegisterForDrag()
        else
        u.button:EnableMouseWheel(state)   -- rueda ajusta escala solo en preview
        if state then
            if u.kind == "power" then
                u.button:EnableMouse(true)
            elseif u.driver then
                UnregisterStateDriver(u.button, "visibility")
            else
                UnregisterUnitWatch(u.button)
            end
            u.button:Show()
            u.button:SetAlpha(1)
            u.editBG:SetShown(not hideGreen)
        else
            u.editBG:Hide()
            if u.kind == "power" then
                u.button:EnableMouse(false)
                u.button:SetShown(PowerShouldShow(u))
            elseif u.driver then
                RegisterStateDriver(u.button, "visibility", u.driver)
            else
                RegisterUnitWatch(u.button)
            end
        end
        end
    end
    for _, u in pairs(portraits) do
        -- Fuera de preview conserva el mouse si abre el panel de personaje (clickOpenChar).
        u.root:EnableMouse(state or (PP(u) and PP(u).clickOpenChar and true or false))
        u.root:EnableMouseWheel(state)
        -- En preview oculta los botones estaticos (para poder arrastrar/editar el portrait sin
        -- que el area de click tape la zona; al salir se recolocan con la posicion final).
        if state then
            if u.charBtnCenter then u.charBtnCenter:Hide() end
            if u.charBtnAlt then u.charBtnAlt:Hide() end
        end
    end
    if not state and ns.LayoutPortraitCharButtonsAll then ns.LayoutPortraitCharButtonsAll() end
    for _, g in pairs(auras) do
        g.root:EnableMouse(state and true or false)
        g.root:EnableMouseWheel(state)
    end
    if infobar then infobar.root:EnableMouse(state and true or false); infobar.root:EnableMouseWheel(state) end
    if ns.micromenu then ns.micromenu:EnableMouse(state and true or false); ns.micromenu:EnableMouseWheel(state) end
    if not state then UpdatePetDriver() end
    -- Al entrar/salir de preview el alpha se fuerza a 1: limpiar la cache del Explorer
    -- (_exAlpha) para que no arranque desde un valor viejo al retomar el fade.
    if ns.ExplorerResetAll then ns.ExplorerResetAll() end
    RefreshAll()
    UpdateGrid()
    if ns.OnUnlockChanged then ns.OnUnlockChanged(state) end
    print(state and "|cff00ff00[MCF]|r Preview ON." or "|cff00ff00[MCF]|r Preview OFF.")
end
ns.SetUnlocked = SetUnlocked
ns.ToggleGreenZone = function()
    if unlocked then
        local hideGreen = db and db.hideEditGreen
        for _, u in pairs(frames) do u.editBG:SetShown(not hideGreen) end
        for _, u in pairs(portraits) do if u.editBG then u.editBG:SetShown(not hideGreen) end end
        for _, g in pairs(auras) do if g.editBG then g.editBG:SetShown(not hideGreen) end end
        if infobar and infobar.editBG then infobar.editBG:SetShown(not hideGreen) end
    end
end

SLASH_MYCUSTOMFRAMES1 = "/mcf"
SlashCmdList["MYCUSTOMFRAMES"] = function() SetUnlocked(not unlocked) end

-- DIAGNOSTICO: /mcfchar — vuelca el estado del boton de abrir personaje (existe/visible/
-- tamaño/posicion + estado de CharacterMicroButton) para saber POR QUE no abre sin adivinar.
SLASH_MCFCHAR1 = "/mcfchar"
SlashCmdList["MCFCHAR"] = function()
    local u = portraits and portraits["portrait_player"]
    print("|cff00ff00[MCF diag]|r portrait_player existe: " .. tostring(u ~= nil))
    if not u then return end
    local p = PP(u)
    print("  clickOpenChar=" .. tostring(p and p.clickOpenChar) .. "  unlocked=" .. tostring(unlocked))
    for _, name in ipairs({ "charBtnCenter", "charBtnAlt" }) do
        local b = u[name]
        if not b then
            print("  " .. name .. " = NO CREADO")
        else
            local shown = b:IsShown()
            local w, h = b:GetSize()
            local l, bt = b:GetLeft(), b:GetBottom()
            print(string.format("  %s shown=%s size=%.0fx%.0f pos(L,B)=%s,%s scale=%.2f frameLevel=%d",
                name, tostring(shown), w or -1, h or -1, tostring(l), tostring(bt), b:GetScale(), b:GetFrameLevel()))
        end
    end
    local root = u.root
    print(string.format("  portrait root shown=%s size=%.0fx%.0f pos(L,B)=%s,%s scale=%.2f",
        tostring(root:IsShown()), select(1, root:GetSize()), select(2, root:GetSize()),
        tostring(root:GetLeft()), tostring(root:GetBottom()), root:GetScale()))
    local cmb = _G.CharacterMicroButton
    print("  CharacterMicroButton existe=" .. tostring(cmb ~= nil))
    if cmb then
        print(string.format("  CharacterMicroButton shown=%s alpha=%.2f mouseEnabled=%s",
            tostring(cmb:IsShown()), cmb:GetAlpha(), tostring(cmb:IsMouseEnabled())))
    end
    print("  InCombatLockdown=" .. tostring(InCombatLockdown()))
end

-- Integracion con el EDIT MODE de Blizzard (menu del juego → Edit Mode): al ABRIRLO,
-- abre tambien el modo edicion del addon (y al cerrarlo, lo cierra), asi mueves los frames
-- de Blizzard Y los del addon en la misma sesion. Opcional (db.syncBlizzEditMode, default on).
-- Se engancha el OnShow/OnHide del EditModeManagerFrame (existe en Blizzard_EditMode, addon
-- que puede cargar bajo demanda → se reintenta en ADDON_LOADED). No hay taint: SetUnlocked ya
-- no corre en combate (guard propio) y el Edit Mode tampoco se abre en combate.
-- (do-block: sin locals top-level nuevos, para no acercarnos al limite de 200 de core.)
do
    local hooked = false
    local function HookBlizzEditMode()
        if hooked then return end
        local emf = _G.EditModeManagerFrame
        if not emf or not emf.HookScript then return end
        hooked = true
        emf:HookScript("OnShow", function()
            local d = db
            if d and d.syncBlizzEditMode ~= false and not unlocked and not InCombatLockdown() then
                SetUnlocked(true)
            end
        end)
        emf:HookScript("OnHide", function()
            local d = db
            if d and d.syncBlizzEditMode ~= false and unlocked and not InCombatLockdown() then
                SetUnlocked(false)
            end
        end)
    end
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(_, event, name)
        if event == "ADDON_LOADED" and name ~= "Blizzard_EditMode" then return end
        HookBlizzEditMode()
    end)
end

-- ==========================================================================
-- COPIAR / PEGAR + PRESETS
-- ==========================================================================
local copyBuffer = nil
local COPY_EXCLUDE = { texture = true, cageTexture = true, castTexture = true, anchorFrame = true }
ns.CopySettings = function()
    copyBuffer = DeepCopy(ns.CurrentProfile())
    print("|cff00ff00[MCF]|r Copied from: " .. ns.currentEdit)
end
ns.PasteSettings = function()
    if not copyBuffer then print("|cffff0000[MCF]|r Nothing copied.") return end
    local p = ns.CurrentProfile()
    for k, v in pairs(copyBuffer) do
        if not COPY_EXCLUDE[k] then p[k] = DeepCopy(v) end
    end
    RefreshUnit(ns.currentEdit)
    if ns.OnProfilePasted then ns.OnProfilePasted() end
    print("|cff00ff00[MCF]|r Pasted into: " .. ns.currentEdit)
end

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
    if not db.units then return end
    db.units[key] = ResetDefault("units", key, function() return DefaultsFor(key) end)
    RefreshUnit(key)
    if ns.OnProfilePasted then ns.OnProfilePasted() end
    print("|cff00ff00[MCF]|r Unit reset: " .. key)
end

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
    -- Sin preset default: volver al layout NATIVO del addon (BUILTIN), no a fabrica.
    if ns.BUILTIN then
        db.units    = DeepCopy(ns.BUILTIN.units or {})
        db.portraits = DeepCopy(ns.BUILTIN.portraits or {})
        db.auras    = DeepCopy(ns.BUILTIN.auras or {})
        db.infobar  = DeepCopy(ns.BUILTIN.infobar or {})
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

local function FillDefaults()
    for _, def in ipairs(UNITS) do
        db.units[def.key] = db.units[def.key] or {}
        local prof = db.units[def.key]
        for k, v in pairs(DefaultsFor(def.key)) do
            if prof[k] == nil then prof[k] = v end
        end
    end
    db.portraits = db.portraits or {}
    for _, def in ipairs(PORTRAITS) do
        db.portraits[def.key] = db.portraits[def.key] or {}
        local prof = db.portraits[def.key]
        for k, v in pairs(PortraitDefaultsFor(def.key)) do
            if prof[k] == nil then prof[k] = v end
        end
    end
    db.auras = db.auras or {}
    for _, def in ipairs(AURAS) do
        db.auras[def.key] = db.auras[def.key] or {}
        local prof = db.auras[def.key]
        for k, v in pairs(AuraDefaultsFor(def.key)) do
            if prof[k] == nil then prof[k] = v end
        end
    end
    db.infobar = db.infobar or {}
    for k, v in pairs(InfoBarDefaults()) do
        if db.infobar[k] == nil then db.infobar[k] = v end
    end
    db.micromenu = db.micromenu or {}
    for k, v in pairs(ns.MicroMenuDefaults()) do
        if db.micromenu[k] == nil then db.micromenu[k] = v end
    end
    db.chatbubble = db.chatbubble or {}
    for k, v in pairs(ns.ChatBubbleDefaults()) do
        if db.chatbubble[k] == nil then db.chatbubble[k] = v end
    end
    db.glow = db.glow or {}
    if ns.GlowDefaults then
        for k, v in pairs(ns.GlowDefaults()) do
            if db.glow[k] == nil then db.glow[k] = v end
        end
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
-- se guardaba/restauraba `hideEditGreen`, perdiendo Move Party/Boss, Mouselook, Hide
-- Blizzard frames, fade-in, grid/snap, Sync Edit Mode, Explorer y sus zonas).
-- ==========================================================================
local GLOBAL_FLAT_KEYS = {
    "hideEditGreen", "groupMoveParty", "groupMoveBoss", "mouselook", "hideBlizzard",
    "dcFix", "gridShow", "gridSnap", "snapElements", "syncBlizzEditMode",
    "previewSecureButton", "fadeIn", "fadeDuration",
    "explorerEnabled", "explorerCombat", "explorerTarget", "explorerCasting", "explorerFadeAlpha",
}
local GLOBAL_TABLE_KEYS = { "lockHide", "explorer", "explorerZones" }

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
    db.presets[name] = {
        units = DeepCopy(db.units),
        portraits = DeepCopy(db.portraits),
        auras = DeepCopy(db.auras),
        infobar = DeepCopy(db.infobar),
        micromenu = DeepCopy(db.micromenu),
        chatbubble = DeepCopy(db.chatbubble),
        glow = DeepCopy(db.glow),
        tracker = DeepCopy(db.tracker),
        globals = CollectGlobals(),
    }
    print("|cff00ff00[MCF]|r Profile saved: " .. name)
end
ns.LoadPreset = function(name)
    local pr = db.presets and db.presets[name]
    if not pr then return end
    if pr.units then
        db.units = DeepCopy(pr.units)
        if pr.portraits then db.portraits = DeepCopy(pr.portraits) end
        if pr.auras then db.auras = DeepCopy(pr.auras) end
        if pr.infobar then db.infobar = DeepCopy(pr.infobar) end
        if pr.micromenu then db.micromenu = DeepCopy(pr.micromenu) end
        if pr.chatbubble then db.chatbubble = DeepCopy(pr.chatbubble) end
        if pr.glow then db.glow = DeepCopy(pr.glow) end
        if pr.tracker then db.tracker = DeepCopy(pr.tracker) end
        ApplyGlobals(pr.globals)
    else
        db.units = DeepCopy(pr)   -- compatibilidad con formato antiguo
    end
    FillDefaults()
    RefreshAll()
    if ns.RefreshTracker then ns.RefreshTracker() end
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
-- exportaba `hideEditGreen`, perdiendo Move Party/Boss, Mouselook, Hide Blizzard, fade-in,
-- grid/snap, Sync Edit Mode y Explorer al exportar/importar.
ns.ExportPreset = function(name)
    local src
    if name and db.presets and db.presets[name] then
        local pr = db.presets[name]
        src = { name = name, units = pr.units, portraits = pr.portraits, auras = pr.auras,
                infobar = pr.infobar, micromenu = pr.micromenu, chatbubble = pr.chatbubble, glow = pr.glow,
                tracker = pr.tracker, globals = pr.globals }
    else
        src = { name = "Actual", units = db.units, portraits = db.portraits, auras = db.auras,
                infobar = db.infobar, micromenu = db.micromenu, chatbubble = db.chatbubble, glow = db.glow,
                tracker = db.tracker, globals = CollectGlobals() }
    end
    return "MCF1:" .. Serialize(src)
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
    db.presets[name] = {
        units     = DeepCopy(data.units),
        portraits = type(data.portraits) == "table" and DeepCopy(data.portraits) or nil,
        auras     = type(data.auras) == "table" and DeepCopy(data.auras) or nil,
        infobar   = type(data.infobar) == "table" and DeepCopy(data.infobar) or nil,
        micromenu = type(data.micromenu) == "table" and DeepCopy(data.micromenu) or nil,
        chatbubble= type(data.chatbubble) == "table" and DeepCopy(data.chatbubble) or nil,
        glow      = type(data.glow) == "table" and DeepCopy(data.glow) or nil,
        tracker   = type(data.tracker) == "table" and DeepCopy(data.tracker) or nil,
        globals   = type(data.globals) == "table" and DeepCopy(data.globals) or nil,
    }
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
    -- Focus (#5): el VISUAL (retrato/fondo/cage) vive en el portrait_focus. El unitframe
    -- seguro NO dibuja barra/fondo/cage/nombre/hechizo, PERO sí el TEXTO DE VIDA (%/valor)
    -- y el highlight, con todas las funciones de una unitframe normal (secret-safe, color,
    -- low-health). SyncFocusButton lo posiciona/dimensiona sobre el portrait, asi el texto
    -- y el highlight aparecen sobre el retrato. Forzamos esta config en cada carga.
    if db.units.focus then
        local ff = db.units.focus
        ff.texture, ff.showName, ff.showSpell, ff.showBackground = "", false, false, false
        ff.cageTexture = ""
        ff.showText = true                              -- texto de vida visible
        if ff.showValue == nil then ff.showValue = true end
        ff.textAutoHide = false                         -- siempre visible cuando hay focus
    end
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
    if db.hideEditGreen == nil then db.hideEditGreen = false end
    if db.groupMoveParty == nil then db.groupMoveParty = false end
    if db.groupMoveBoss == nil then db.groupMoveBoss = false end
    if db.mouselook == nil then db.mouselook = false end
    if db.hideBlizzard == nil then db.hideBlizzard = false end
    if db.dcFix == nil then db.dcFix = true end   -- fix DialogueUI+DynamicCam (on por defecto)
    if db.gridShow == nil then db.gridShow = false end   -- grid de alineacion en modo Lock
    if db.gridSnap == nil then db.gridSnap = false end   -- al soltar, ajusta a la grilla
    if db.snapElements == nil then db.snapElements = true end -- B2: alinear con bordes/centros de otros
    if db.syncBlizzEditMode == nil then db.syncBlizzEditMode = true end -- abrir el lock con el Edit Mode de Blizzard
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

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("UNIT_MODEL_CHANGED")
events:RegisterEvent("UNIT_PORTRAIT_UPDATE")
events:RegisterEvent("UNIT_PET")
events:RegisterEvent("PLAYER_FOCUS_CHANGED")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("UNIT_AURA")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("PLAYER_FLAGS_CHANGED")   -- toggle de Modo Guerra → refresca el badge de faccion

events:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        InitDB()
        RefreshAll()
    elseif event == "PLAYER_ENTERING_WORLD" then
        if ns.ApplyDcFix then ns.ApplyDcFix() end
        if db then UpdatePetDriver() UpdatePartyDrivers() RefreshAll()
            if ns.HideBlizzardFrames then ns.HideBlizzardFrames() end
            for _, u in pairs(frames) do AttachFadeIn(u.button) end
            for _, u in pairs(portraits) do AttachFadeIn(u.root) end
            if ns.LayoutPortraitCharButtonsAll then ns.LayoutPortraitCharButtonsAll() end
        end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "ZONE_CHANGED_NEW_AREA" then
        if db then UpdatePartyDrivers(); if ns.HideBlizzardFrames then ns.HideBlizzardFrames() end end
    elseif event == "PLAYER_FLAGS_CHANGED" then
        -- Modo Guerra activado/desactivado (u otros flags del player): actualiza el badge de
        -- faccion al instante (alianza/horda ↔ variante de guerra) sin esperar al ticker.
        if db then
            for _, u in pairs(portraits) do
                if u.faction and u.unit == "player" then PortraitUpdateFaction(u) end
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if ns.BlizzardNeedsApply and ns.BlizzardNeedsApply() and ns.HideBlizzardFrames then ns.HideBlizzardFrames() end
        for _, u in pairs(frames) do
            if u.needsLayout then UnitApplyLayout(u) end
        end
        -- Portraits con Show/Hide diferido (root protegido en combate): aplicar ahora.
        for _, u in pairs(portraits) do
            if u._pendingShown ~= nil then PortraitSetShown(u, u._pendingShown) end
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
        if frames["pet"] and frames["pet"].needsDriver then UpdatePetDriver() end
        for _, key in ipairs(PARTY_KEYS) do
            if frames[key] and frames[key].needsDriver then UpdatePartyDrivers() break end
        end
        if ns.micromenu and ns.micromenu.needsLayout and ns.RefreshMicroMenu then ns.RefreshMicroMenu() end
        -- Botones estaticos de personaje: recolocar por si la config cambio mientras estabamos en combate.
        if ns.LayoutPortraitCharButtonsAll then ns.LayoutPortraitCharButtonsAll() end
        -- Auras: crea overlays de cancelacion que no se pudieron crear en combate
        -- y refresca el grupo del player para poner al dia el macrotext.
        if db then
            for _, g in pairs(auras) do
                for _, b in ipairs(g.buttons) do EnsureCancelOverlay(b) end
            end
            if not unlocked then
                for _, g in pairs(auras) do
                    if g.unit == "player" then UpdateAuraGroup(g) end
                end
            end
        end
    elseif event == "UNIT_MODEL_CHANGED" or event == "UNIT_PORTRAIT_UPDATE" then
        if db then
            for _, u in pairs(portraits) do
                if u.unit == arg1 then PortraitUpdatePicture(u) end
            end
        end
    elseif event == "UNIT_PET" then
        -- La pet cambio: recargar el retrato del portrait de pet.
        if db and portraits["portrait_pet"] then
            portraits["portrait_pet"]._wasShown = false
            PortraitUpdatePicture(portraits["portrait_pet"])
        end
        ResetCastBar("pet")
    elseif event == "PLAYER_FOCUS_CHANGED" then
        if db and portraits["portrait_focus"] then
            portraits["portrait_focus"]._wasShown = false
            PortraitUpdatePicture(portraits["portrait_focus"])
        end
        ResetCastBar("focus")
    elseif event == "PLAYER_TARGET_CHANGED" then
        ResetCastBar("target")
        ResetCastBar("targettarget")
        -- Target (y target-de-target) cambiaron: recargar sus retratos.
        for _, k in ipairs({ "portrait_target", "portrait_tot" }) do
            if db and portraits[k] then
                portraits[k]._wasShown = false
                PortraitUpdatePicture(portraits[k])
            end
        end
        -- Y sus auras.
        if db and not unlocked then
            for _, g in pairs(auras) do
                if g.unit == "target" then UpdateAuraGroup(g) end
            end
        end
    elseif event == "UNIT_AURA" then
        if db and not unlocked then
            for _, g in pairs(auras) do
                if g.unit == arg1 then UpdateAuraGroup(g) end
            end
        end
    end
end)

-- Focus (#5): el secure button del focus SIGUE al portrait_focus (posicion/tamaño/escala),
-- para que el click derecho SOBRE EL RETRATO abra el menu contextual. Solo fuera de combate
-- (mover un frame seguro en combate esta bloqueado; en combate se queda donde estaba).
-- CLAVE anti-taint: NUNCA anclar el frame SEGURO al portrait (frame inseguro) — eso taintea
-- el entorno seguro y puede romper la visibilidad (RegisterUnitWatch) de TODAS las unidades.
-- En su lugar se copia la posicion con coords ABSOLUTAS respecto a UIParent.
local function SyncFocusButton()
    if InCombatLockdown() then return end
    if not UnitExists("focus") then return end
    local ff, fp = frames["focus"], portraits["portrait_focus"]
    if not (ff and fp and ff.button and fp.root) then return end
    local px, py = fp.root:GetCenter()
    if not px then return end
    local es, uies = fp.root:GetEffectiveScale(), UIParent:GetEffectiveScale()
    local r = es / uies
    local w = math.max(fp.root:GetWidth() or 60, 10)
    local h = math.max(fp.root:GetHeight() or 60, 10)
    ff.button:SetScale(1)
    ff.button:ClearAllPoints()
    ff.button:SetPoint("CENTER", UIParent, "BOTTOMLEFT", px * r, py * r)
    ff.button:SetSize(w * r, h * r)
    -- El texto de vida y el highlight del focus deben renderizar ENCIMA del retrato:
    -- misma strata que el portrait, nivel por encima de sus capas (root+1 modelo, root+2
    -- iconos). Fuera de combate (SetFrameStrata/Level en frame seguro).
    ff.button:SetFrameStrata(fp.root:GetFrameStrata())
    -- +30 de nivel para que el highlight y el texto de vida queden CLARAMENTE por encima
    -- del retrato (fondo/cage/modelo/badges van hasta root+2..+5).
    ff.button:SetFrameLevel((fp.root:GetFrameLevel() or 1) + 30)
end
ns.SyncFocusButton = SyncFocusButton

-- EXPLORER (#11): elementos que se auto-ocultan y aparecen con MOUSEOVER (o en combate).
-- Mapa elementKey -> frame raiz del elemento.
local function GetElementFrame(key)
    if key == "micromenu" then return ns.micromenu end
    if key == "infobar" then return infobar and infobar.root end
    if frames[key] then return frames[key].button end
    if portraits[key] then return portraits[key].root end
    if auras[key] then return auras[key].root end
    return nil
end
ns.GetElementFrame = GetElementFrame

-- Fade por MOUSEOVER (`IsMouseOver` funciona sin EnableMouse = geometrico). El fade corre
-- por FRAME (OnUpdate de explorerDriver) con suavizado EXPONENCIAL independiente del
-- framerate: el lerp fijo del ticker de 0.1s se veia a saltos (10 pasos/seg = "lag").
-- Revelar es mas rapido que ocultar (mas natural). El estado de combate lo refresca el
-- ticker (secret-safe via pcall); aqui solo se anima. db.explorerEnabled = toggle maestro.
local explorerDriver = CreateFrame("Frame", nil, UIParent)
explorerDriver:Hide()
explorerDriver:SetScript("OnUpdate", function(self, dt)
    if not (db and db.explorer and db.explorerEnabled ~= false) or unlocked then return end
    local lo = db.explorerFadeAlpha or 0
    -- Factor por half-life: el alpha recorre la mitad de la distancia cada X segundos.
    local kIn  = 1 - 0.5 ^ (dt / 0.06)   -- revelar (half-life ~60ms)
    local kOut = 1 - 0.5 ^ (dt / 0.20)   -- ocultar (mas pausado)
    for key, on in pairs(db.explorer) do
        if on then
            local f = GetElementFrame(key)
            -- _mcfCombatHidden: portrait "oculto" via alpha en combate (frame protegido);
            -- su alpha lo gestiona PortraitSetShown, no el Explorer.
            if f and f:IsShown() and not f._mcfCombatHidden then
                local target = (self.combat or self.showTgt or self.casting or f:IsMouseOver()) and 1 or lo
                local cur = f._exAlpha; if cur == nil then cur = f:GetAlpha() end
                cur = cur + (target - cur) * (target > cur and kIn or kOut)
                if math.abs(target - cur) < 0.003 then cur = target end
                f._exAlpha = cur
                f:SetAlpha(cur)
                -- QUIRK de WoW: los frames Model/PlayerModel NO heredan el alpha del
                -- padre → el retrato 3D no se desvanecia con el resto. Se aplica a
                -- mano, multiplicado por su opacidad configurada (modelAlpha).
                local pu = portraits[key]
                if pu and pu.model then
                    pu.model:SetAlpha(cur * (PP(pu).modelAlpha or 1))
                end
                -- El texto de vida + highlight del FOCUS viven en frames["focus"] (unitframe
                -- aparte, sobre el retrato): desvanecerlo junto al portrait_focus.
                if key == "portrait_focus" and frames["focus"] then
                    frames["focus"].button:SetAlpha(cur)
                end
            end
        end
    end
end)
ns.ExplorerReset = function(key)   -- llamar al APAGAR el explorer de un elemento
    local f = GetElementFrame(key)
    if f then f._exAlpha = nil; f:SetAlpha(1) end
    -- Restaurar tambien el alpha manual del modelo 3D (no hereda del padre).
    local pu = portraits[key]
    if pu and pu.model and db then pu.model:SetAlpha(PP(pu).modelAlpha or 1) end
    -- Restaurar el boton del focus (texto de vida + highlight).
    if key == "portrait_focus" and frames["focus"] then frames["focus"].button:SetAlpha(1) end
end
ns.ExplorerResetAll = function()   -- llamar al APAGAR el toggle maestro
    if not (db and db.explorer) then return end
    for key in pairs(db.explorer) do ns.ExplorerReset(key) end
end

-- Tipo de contenido actual → clave de db.explorerZones. IsInInstance devuelve:
-- "none"(mundo)/"party"(mazmorra)/"raid"/"arena"/"pvp"(BG)/"scenario"(escenario/delve).
local EXPLORER_ZONE_MAP = {
    none = "world", party = "dungeon", raid = "raid",
    arena = "arena", pvp = "battleground", scenario = "scenario",
}
local function ExplorerZoneAllowed()
    local z = db.explorerZones
    if not z then return true end
    local key = "world"
    local ok, inInst, it = pcall(IsInInstance)
    if ok and not (issecretvalue and (issecretvalue(inInst) or issecretvalue(it))) then
        if inInst and it then key = EXPLORER_ZONE_MAP[it] or "world" end
    end
    return z[key] ~= false
end

C_Timer.NewTicker(0.1, function()
    if not db or unlocked then return end
    -- Snapshot de estados seguros del tick (booleanos, jamas secretos): antes se
    -- consultaban decenas de veces por pasada con la misma respuesta.
    tickState.n = (tickState.n or 0) + 1
    tickState.inCombat = safeBool(UnitAffectingCombat, "player")
    tickState.resting  = safeBool(IsResting)
    tickState.partyOK  = PartyContentAllowed()
    -- pcall: un error aqui NO debe romper el loop de unidades (frames invisibles).
    pcall(SyncFocusButton)
    pcall(UpdateFocusPortraitHighlight)   -- highlight del focus DETRAS del retrato (dinamico)
    for _, u in pairs(frames) do
        if u.kind == "power" then u.button:SetShown(PowerShouldShow(u)) end
        -- Pet: sin pet, la decoracion (cage/bg/relleno) no debe verse.
        if u.key == "pet" then
            local hasPet = UnitExists("pet")
            local pp = db.units.pet
            if u.cage then u.cage:SetShown(hasPet and pp.cageTexture and pp.cageTexture ~= "" and true or false) end
            if u.bg then u.bg:SetShown(hasPet and pp.showBackground and true or false) end
            if not hasPet then
                if u.fillTex then u.fillTex:Hide() end
                u.bar:GetStatusBarTexture():SetAlpha(0)
            end
            -- Sin pet o pet muerta: el texto de nombre y de vida NO deben quedar visibles.
            -- (Sin pet el bloque de update de abajo se salta por UnitExists → texto stale.)
            if (not hasPet) or safeBool(UnitIsDeadOrGhost, "pet") then
                if u.hpText then u.hpText:SetText("") end
                if u.nameText then u.nameText:SetAlpha(0); u.nameText:SetText("") end
                if u.spellText then u.spellText:SetAlpha(0); u.spellText:SetText("") end
            end
        end
        if UnitExists(u.unit) then
            UnitUpdateBar(u)
            UnitUpdateColor(u)
            UnitTextVisibility(u)
            UnitUpdateMount(u)
            UnitUpdateDeadCage(u)
            UnitUpdateHighlight(u)
        end
    end
    -- Performance Fase 2: badges (faccion/raid-target/rol-lider) a 0.3s en vez de 0.1s (cambian
    -- raramente); el icono de clase de PARTY (no tot: tot debe seguir al target al instante) igual.
    local slowTier = (tickState.n % 3 == 0)
    for _, u in pairs(portraits) do
        if PortraitShouldShow(u) then
            PortraitSetShown(u, true)
            -- Iconos de clase: tot puede cambiar de unidad seguido (sigue al target) -> cada
            -- tick. Party casi nunca cambia de clase en la sesion (solo si cambia el ocupante
            -- del slot) -> alcanza con el tier lento. Modelos, solo al aparecer.
            if u.kind == "icon" then
                if u.key == "portrait_tot" or slowTier or not u._wasShown then PortraitUpdatePicture(u) end
            elseif not u._wasShown then
                PortraitUpdatePicture(u)
            end
            u._wasShown = true
            PortraitUpdatePosition(u)
            PortraitUpdateState(u, false, not slowTier)
        else
            PortraitSetShown(u, false)
            u._wasShown = false
        end
    end
    -- Auras: reposicionar grupos dualPos + opacidad por condicion + texto de duracion.
    local outOfCombat = not InCombatLockdown()
    for _, g in pairs(auras) do
        if g.dualPos then AuraGroupPlace(g); UpdateAuraAlpha(g) end
        for _, b in ipairs(g.buttons) do
            if b:IsShown() then
                UpdateAuraButtonTime(b)
                -- El overlay no esta anclado al boton; hay que reposicionarlo
                -- cuando el grupo se mueve (solo fuera de combate).
                if outOfCombat and b.cancel and b.cancel:IsShown() then
                    PositionCancelOverlay(b.cancel, b)
                end
            end
        end
    end
    -- Info bar: refrescar valores ~1/seg.
    if infobar and db.infobar and db.infobar.enabled then
        if GetTime() - (infobar._lastVal or 0) >= 1 then
            infobar._lastVal = GetTime()
            UpdateInfoBarValues()
        end
    end
    -- Micro menu: re-afirmar el skin (nunca iconos originales) + ocultar Character.
    -- Throttle a 0.5s: los hooks (Set*Texture/UpdateMicroButtons) ya reaccionan al
    -- instante; el ticker es solo la red de seguridad.
    if tickState.n % 5 == 0 and ns.MM_ReassertArt then ns.MM_ReassertArt() end
    -- Explorer: la ANIMACION corre por frame en explorerDriver (OnUpdate); el ticker
    -- solo refresca el estado de combate (del snapshot) y enciende/apaga el driver.
    local exOn = db.explorerEnabled ~= false and db.explorer and next(db.explorer) ~= nil
        and ExplorerZoneAllowed()
    if exOn then
        explorerDriver.combat = (db.explorerCombat and tickState.inCombat) or false
        explorerDriver.showTgt = (db.explorerTarget and UnitExists("target")) or false
        -- Casteo/canalizacion del PLAYER: revela al instante (ReadCastMode es secret-safe;
        -- el fade de revelado tiene half-life ~60ms → se percibe inmediato).
        explorerDriver.casting = (db.explorerCasting and ReadCastMode("player") ~= nil) or false
    elseif explorerDriver._wasOn then
        -- Se apago (zona no permitida o master off): restaurar alpha 1 UNA vez.
        if ns.ExplorerResetAll then ns.ExplorerResetAll() end
    end
    explorerDriver._wasOn = exOn and true or false
    explorerDriver:SetShown(exOn and true or false)
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
local function HB_Handle(frame)
    if not frame or blizzHidden[frame] then return end
    pcall(function() RegisterStateDriver(frame, "visibility", "hide") end)
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
    if not frame or blizzHidden[frame] then return end
    pcall(function()
        frame:UnregisterAllEvents()
        frame:Hide()
        RegisterStateDriver(frame, "visibility", "hide")
    end)
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
    if frame and frame.SetAlpha then frame:SetAlpha(0) end
end

local function HideBlizzardFramesNow()
    if not (db and db.hideBlizzard) then return end
    if InCombatLockdown() then blizzNeedsApply = true; return end
    blizzNeedsApply = false
    HB_Handle(_G.PlayerFrame)
    HB_Handle(_G.PetFrame)
    HB_Handle(_G.TargetFrame)         -- incluye el ToT (hijo)
    HB_Handle(_G.TargetFrameToT)
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
