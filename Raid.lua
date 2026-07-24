-- ==========================================================================
-- MyCustomFrames - Raid.lua
-- RAID FRAMES (hasta 40 jugadores), estilo AzeriteUI. A diferencia de party1-5
-- (Units.lua: 5 SecureUnitButtonTemplate creados/posicionados a mano) esto usa
-- un SecureGroupHeaderTemplate (child pooling dinamico segun el roster real),
-- porque 40 unidades no se pueden mantener como frames fijos hand-authored.
-- Los 40 "members" fisicos se crean via Raid.xml (unico XML del addon, ver
-- ese archivo para el porque) y su construccion visual vive aca en
-- ns.BuildRaidMember/MyCF_BuildRaidMember. Reutiliza al maximo la maquinaria
-- secret-safe de Units.lua (ns.UnitApplyAppearance/UnitUpdateBar/UnitUpdateColor/
-- UnitUpdateHighlight) dandole a cada member u.key="raid" -- todos comparten
-- UN SOLO perfil de estilo (db.units.raid), no uno por jugador (no tendria
-- sentido editar 40 unidades a mano). Carga DESPUES de Units.lua en el toc.
-- ==========================================================================
local ADDON, ns = ...

-- Mismo prefijo de Assets que core.lua (ahi es local, no expuesto via ns).
local A = "Interface\\AddOns\\MyCustomFrames\\Assets\\"

-- Sistema de Skins (2026-07-23, "raid frames tambien"): health/cage/highlight
-- de raid1-40 ya salen gratis via SKIN_SLOTS/TEX_LIB (db.units.raid es una
-- entrada mas de db.units, ver core.lua) -- pero el icono/plate de ROL
-- (tank/heal) no viven en la DB (son fijos, sin picker), asi que se resuelven
-- aca a mano contra la skin activa, mismo patron que ClassPower.lua.
local function ResolveTex(filename)
    if ns.SkinResolve then return ns.SkinResolve(filename) end
    return A .. filename
end
-- roleBackdrop se texturea UNA sola vez por member al crearse (no en cada
-- refresh como roleIcon) -- se registran aca para poder reasignarles la
-- textura cuando cambia la skin (ns.RefreshRaid llama RefreshRoleBackdrops).
local roleBackdrops = {}
local function RefreshRoleBackdrops()
    local tex = ResolveTex("point_plate.tga")
    for _, t in ipairs(roleBackdrops) do t:SetTexture(tex) end
end

-- ==========================================================================
-- ESTADO
-- ==========================================================================
ns.raidFrames = {}         -- [button] = u (health, kind="health")
ns.raidPowerFrames = {}    -- [button] = u (power sub-bar, kind="power")
local raidHeader
-- Declarados ACA (no donde se usan por primera vez) para que ns.RefreshRaid
-- (definida mas arriba en el archivo) los vea como upvalue -- Lua resuelve
-- locals por posicion textual, no por orden de llamada.
local ghosts        -- [i] = frame (pool de hasta 40, ver EnsureGhosts)
local ghostUnits    -- [i] = u (health, para reposicionar/resize en vivo, ver RefreshRaid)
local ghostPowerUnits -- [i] = pu (power, idem)

-- ==========================================================================
-- ARRASTRE DEL HEADER: funciones COMPARTIDAS, llamadas tanto desde el propio
-- raidHeader (drag directo sobre un hueco vacio) como desde CADA member/ghost
-- (drag directo SOBRE una barra -- ver BuildMemberVisual). FIX (2026-07-20,
-- "si hago click sobre uno de los botones... no pasa nada"): deshabilitar el
-- mouse de los members/ghosts para que el click "atraviese" hasta el header
-- de abajo no alcanzaba de forma confiable en este cliente -- en vez de
-- depender de eso, CADA member/ghost ahora tiene su PROPIO drag que mueve
-- DIRECTAMENTE al header (mismo resultado, sin depender de pass-through).
-- ==========================================================================
local function StartRaidHeaderDrag()
    if raidHeader and ns.IsUnlocked() and not InCombatLockdown() then
        raidHeader:StartMoving()
    end
end
local function StopRaidHeaderDrag()
    if not raidHeader then return end
    raidHeader:StopMovingOrSizing()
    if ns.SnapFrameToGrid then ns.SnapFrameToGrid(raidHeader) end
    local cfg = ns.GetDB().units.raid
    local parent = _G[cfg.anchorFrame]
    if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
    local s, ps = raidHeader:GetEffectiveScale(), parent:GetEffectiveScale()
    local fx, fy = raidHeader:GetCenter()
    local px, py = parent:GetCenter()
    if fx and px then
        cfg.relativePoint = "CENTER"
        cfg.offsetX = (fx * s - px * ps) / s
        cfg.offsetY = (fy * s - py * ps) / s
    end
    ns.RefreshRaid()
    if ns.OnDragStopped then ns.OnDragStopped("raid") end
end

-- ==========================================================================
-- DEFAULTS
-- db.units.raid es un perfil UNICO compartido por los 40 members (mismo shape
-- que cualquier otra entrada de db.units.*, ver ns.DefaultsFor en core.lua) MAS
-- un puñado de campos propios para el grid (growPoint/columnAnchorPoint/
-- growXOffset/growYOffset/unitsPerColumn/maxColumns/columnSpacing) y el
-- comportamiento (enabled). point/relativePoint/offsetX/offsetY/
-- anchorFrame/scale de la base ya sirven tal cual para la POSICION DEL
-- CONTENEDOR (igual convencion que cualquier unitframe).
-- ==========================================================================
function ns.RaidUnitDefaults()
    local d = ns.DefaultsFor("raid")

    -- Tamaño del member: EXACTO al UnitSize de AzeriteUI (103x56). Las barras
    -- de vida/poder tienen tamaño FIJO independiente de esto (ver
    -- RAID_BAR_W/H arriba) -- cambiar esto solo mueve donde se ancla cada
    -- member en el grid, igual que en AzeriteUI.
    d.width, d.height = 103, 56
    d.strata = "MEDIUM"

    -- Posicion del CONTENEDOR (el header completo se arrastra en Lock, NO
    -- cada member individual -- el header reposiciona sus hijos solo).
    -- "d.point" quedo VESTIGIAL (sin uso real): el header SIEMPRE se ancla
    -- por su CENTER, nunca por un point elegido a mano (ver
    -- RepositionRaidHeaderIfChanged / fix de "los botones bloquean mover").
    -- FIX (encontrado en revision 2026-07-20): los offsets 50,-42 eran para
    -- un anclaje TOPLEFT (el header entero empezaba ahi y crecia hacia
    -- adentro de la pantalla) -- con CENTER, esos mismos numeros dejan el
    -- CENTRO del grid a solo 50px del borde izquierdo, asi que la mitad del
    -- grid (default 531x490) queda afuera de la pantalla en una instalacion
    -- nueva o tras "Reset raid frames". Offsets nuevos = mitad del tamaño
    -- default del grid, para que el CENTRO caiga bien adentro de la pantalla.
    d.anchorFrame = ""
    d.point, d.relativePoint = "TOPLEFT", "TOPLEFT"
    d.offsetX, d.offsetY = 280, -220
    d.scale = 1.0

    -- Backdrop de vida (cast_back), EXACTO a HealthBackdropSize/Position de
    -- AzeriteUI: 132x85, centrado con offset (1,-2).
    -- ResolveTex (no A directo): ns.ForceRaidStyle() reaplica estos defaults
    -- SIEMPRE en cada RefreshRaid (ver APPEARANCE_KEYS arriba, decision
    -- deliberada para que nada desvie el look) -- asi que para que el raid
    -- frame siga la skin activa, el default en si tiene que resolverse contra
    -- la skin, no apuntar siempre al Default hardcodeado.
    d.texture = ResolveTex("cast_bar.tga")
    d.cageTexture = ResolveTex("cast_back.tga")
    d.cageWidth, d.cageHeight = 132, 85
    -- NOTA: en AzeriteUI ese offset (1,-2) es relativo al CENTRO DE LA BARRA
    -- DE VIDA (health, no el boton), que esta anclada BOTTOM+16 dentro de un
    -- boton de 56px alto -- su centro cae ~5.5px mas abajo que el centro del
    -- boton. Nuestro UnitApplyAppearance (Units.lua, generico) ancla el cage
    -- al centro del BOTON, asi que se compensa sumando esa diferencia aca
    -- para caer en el mismo lugar visual: -2 + (-5.5) = -7.5.
    d.cageOffsetX, d.cageOffsetY = 1, -7.5
    d.cageAlpha = 1.0
    d.cageHideDead = true

    -- Target/focus highlight (cast_back_outline), EXACTO a
    -- TargetHighlightSize/Position de AzeriteUI: 140x90, offset (1,-2).
    -- Color = el de "target" de AzeriteUI (255,239,169); estatico, sin latido
    -- (AzeriteUI no lo anima, solo Show/Hide).
    d.showHighlight = true
    d.highlightGlow = false
    d.highlightTexture = ResolveTex("cast_back_outline.tga")
    d.highlightWidth, d.highlightHeight = 140, 90
    d.highlightOffsetX, d.highlightOffsetY = 1, -7.5   -- misma compensacion que el cage (ver nota arriba)
    d.highlightColor = { r = 255/255, g = 239/255, b = 169/255 }

    -- Nombre arriba del member (TOP, -10 en AzeriteUI); nuestro anclaje es
    -- CENTER-relativo a la barra de vida (mucho mas chica y pegada abajo), asi
    -- que el offset equivalente para caer en el mismo lugar visual es +24.
    d.showBackground = false   -- sin rectangulo negro generico: el cage YA es el fondo
    d.showText = false         -- AzeriteUI no muestra %/valor en el raid frame, solo el nombre
    d.nameFontSize, d.fontSize = 11, 11
    d.nameMaxLength = 8
    d.textOffsetY = 0
    d.nameOffsetY = 24
    d.nameDynamicWidth = false
    d.nameLevelColor = false

    -- Crecimiento del grid (atributos de SecureGroupHeaderTemplate). Nombres
    -- DISTINTOS a point/offsetX/offsetY (que ya son la posicion del
    -- contenedor) para no pisarlos.
    d.growPoint = "LEFT"          -- direccion DENTRO de cada columna/fila
    d.columnAnchorPoint = "TOP"   -- direccion ENTRE columnas/filas
    d.growXOffset, d.growYOffset = 4, 4
    d.unitsPerColumn = 5          -- limite por fila/columna
    d.maxColumns = 8
    d.columnSpacing = 6

    -- Comportamiento / auto-show. SOLO raid real y BG (pedido del usuario
    -- 2026-07-20: "quita lo de party, que solo funcione en raids y bg" --
    -- sus unitframes de party1-5 propios de Units.lua NO se tocan, son un
    -- sistema totalmente aparte).
    d.enabled = true

    -- Posicion de los iconos (raid target/ready check/resurrect/rol), UNICO
    -- rincon de la apariencia que el usuario SI puede editar via menu (todo
    -- lo demas es forzado por ns.ForceRaidStyle) -- se configura mirando
    -- raid1 y el resto de los members COPIAN estos mismos offsets (un solo
    -- perfil compartido, ver ns.PositionRaidIcons).
    d.raidTargetOffsetX, d.raidTargetOffsetY = 2, -2   -- anclado a la esquina TOPLEFT del boton (ver nota en PositionRaidIcons)
    d.readyCheckOffsetX, d.readyCheckOffsetY = 0, 0
    d.roleOffsetX, d.roleOffsetY = 25, 0

    -- Tamaño de la barra de vida y del icono de raid target (pedido del
    -- usuario 2026-07-20: "me gustaria poder cambiarles el tamaño") --
    -- editable via menu (Icons tab), a diferencia del resto de la apariencia.
    -- Defaults = medidas exactas de AzeriteUI (ver RAID_BAR_W/H mas abajo).
    d.healthBarWidth, d.healthBarHeight = 75, 13
    d.raidTargetIconSize = 14

    return d
end

-- ==========================================================================
-- APARIENCIA 100% POR CODIGO (pedido explicito del usuario 2026-07-20: "no me
-- dejes controlar la apariencia a mi desde el menu, la apariencia es 100 por
-- codigo, organizalo tu"). db.units.raid TODAVIA es la tabla que lee P(u) en
-- Units.lua (no se puede evitar, es generico) pero estos campos se
-- SOBRESCRIBEN SIEMPRE con los valores de ns.RaidUnitDefaults() -- nunca solo
-- "si estan vacios" -- para que ni datos viejos guardados de una sesion
-- anterior (antes de este ajuste) ni ningun otro codigo puedan desviar el
-- look real de AzeriteUI. El menu (Options.lua, grupo RAID) SOLO expone
-- growth/limits/spacing/tamaño/posicion -- nada de esta lista.
-- ==========================================================================
local APPEARANCE_KEYS = {
    "texture", "reverseFill", "smooth", "showBackground", "barAlpha", "bgAlpha",
    "cageTexture", "cageWidth", "cageHeight", "cageOffsetX", "cageOffsetY", "cageAlpha", "cageHideDead",
    "showHighlight", "highlightTexture", "highlightWidth", "highlightHeight",
    "highlightOffsetX", "highlightOffsetY", "highlightColor", "highlightGlow", "highlightAlpha",
    "showText", "showValue", "textAlpha", "textOffsetX", "textOffsetY", "textAutoHide", "fontSize",
    "useHealthColor", "healthColor",
    "showName", "nameAutoHide", "nameFontSize", "nameAlpha", "nameScale",
    "nameOffsetX", "nameOffsetY", "nameLevelColor", "nameMaxLength", "nameDynamicWidth",
    "useNameColor", "nameColor",
    "useBarColor", "barColor", "colorHostile", "colorNeutral", "colorFriendly",
}

function ns.ForceRaidStyle()
    local db = ns.GetDB()
    if not db then return end
    db.units = db.units or {}
    db.units.raid = db.units.raid or {}
    local defaults = ns.RaidUnitDefaults()
    for _, k in ipairs(APPEARANCE_KEYS) do
        db.units.raid[k] = defaults[k]
    end
end

-- ==========================================================================
-- SINGLETON KEY (patron identico a ns.IsMinimap/ns.IsNameplates/ns.IsClassPower)
-- ==========================================================================
ns.IsRaid = function(key) return key == "raid" end

-- ==========================================================================
-- CONSTRUCCION VISUAL (compartida entre members REALES -- creados via el
-- template XML, ver Raid.xml -- y los "ghost" del preview de Lock cuando no
-- hay raid real: mismos frames/barras/texto, pero los ghost NO se registran
-- en ns.raidFrames asi TickRaid nunca los toca).
-- ==========================================================================
-- Medidas EXACTAS de AzeriteUI (Layouts/Data/RaidUnitFrames40.lua): UnitSize
-- {103,56}, HealthBarSize {75,13} anclada BOTTOM +16, PowerBarSize {67,1}
-- anclada BOTTOM +14.5, HealthBackdrop {132,85} CENTER (1,-2), TargetHighlight
-- {140,90} CENTER (1,-2). Fijas (no siguen el slider de tamaño del member,
-- igual que en AzeriteUI: cambiar UnitSize ahi tampoco reescala las barras).
-- Reposiciona los iconos (raid target/ready check/resurrect/rol) de UN
-- member/ghost segun db.units.raid.*OffsetX/Y (pedido del usuario 2026-07-20:
-- "dejame controlar la posicion de los iconos, basado en el raid1, el resto
-- copian a ese"). Un solo perfil compartido (db.units.raid) -> mover el
-- icono de cualquiera los mueve a TODOS por igual, no hay forma de editar
-- uno distinto del resto (a proposito, ver ns.ForceRaidStyle: la apariencia
-- es 100% uniforme). Llamada en la creacion (BuildMemberVisual) y de nuevo
-- en cada ns.RefreshRaid() para que los sliders del menu se vean en vivo.
local function PositionRaidIcons(u)
    local p = ns.GetDB() and ns.GetDB().units and ns.GetDB().units.raid
    if not p then return end
    -- FIX (2026-07-20, "el icono esta super alejado del boton"): antes se
    -- anclaba a nameText "LEFT" -- pero nameText tiene un ANCHO INVISIBLE de
    -- 1000px (SetWidth fijo, ver UnitUpdateBar/Units.lua) para poder centrar
    -- nombres largos, y al estar centrado, su borde "LEFT" real queda a
    -- 500px del texto VISIBLE, no pegado a el. Se ancla al BOTON (esquina
    -- real, sin ese problema) en su lugar.
    if u.raidTargetIcon and u.button then
        u.raidTargetIcon:ClearAllPoints()
        u.raidTargetIcon:SetPoint("TOPLEFT", u.button, "TOPLEFT", p.raidTargetOffsetX or 2, p.raidTargetOffsetY or -2)
    end
    if u.readyCheckIcon and u.bar then
        u.readyCheckIcon:ClearAllPoints()
        u.readyCheckIcon:SetPoint("CENTER", u.bar, "CENTER", p.readyCheckOffsetX or 0, p.readyCheckOffsetY or 0)
    end
    if u.resurrectIcon and u.bar then
        u.resurrectIcon:ClearAllPoints()
        u.resurrectIcon:SetPoint("CENTER", u.bar, "CENTER", p.readyCheckOffsetX or 0, p.readyCheckOffsetY or 0)
    end
    if u.roleBackdrop and u.button then
        u.roleBackdrop:ClearAllPoints()
        u.roleBackdrop:SetPoint("RIGHT", u.button, "RIGHT", p.roleOffsetX or 25, p.roleOffsetY or 0)
    end
end
ns.PositionRaidIcons = PositionRaidIcons

local RAID_BAR_W, RAID_BAR_H = 75, 13
local RAID_BAR_Y = 16
local RAID_POWER_W, RAID_POWER_H = 67, 1
local RAID_POWER_Y = 14.5
local RAID_POWER_TEX = [[Interface\ChatFrame\ChatFrameBackground]]

-- Tamaño de la barra de vida/poder + icono de raid target de UN member/ghost
-- (pedido del usuario 2026-07-20: "me gustaria poder cambiarles el tamaño").
-- La barra de PODER sigue el mismo ANCHO que la de vida (para que se vean
-- alineadas), su alto se mantiene fijo (es solo una tira de 1px). Llamada en
-- la creacion y de nuevo en cada ns.RefreshRaid() para que los sliders se
-- vean en vivo.
local function ApplySizeToMember(u, pu)
    local p = ns.GetDB() and ns.GetDB().units and ns.GetDB().units.raid
    if not p then return end
    local bw = p.healthBarWidth or RAID_BAR_W
    local bh = p.healthBarHeight or RAID_BAR_H
    if u.bar then
        u.bar:SetSize(bw, bh)
        u.bar:ClearAllPoints()
        u.bar:SetPoint("BOTTOM", u.button, "BOTTOM", 0, RAID_BAR_Y)
    end
    if u.raidTargetIcon then
        local sz = p.raidTargetIconSize or 14
        u.raidTargetIcon:SetSize(sz, sz)
    end
    if pu and pu.bar then
        pu.bar:SetSize(bw, RAID_POWER_H)
        pu.bar:ClearAllPoints()
        pu.bar:SetPoint("BOTTOM", pu.button, "BOTTOM", 0, RAID_POWER_Y)
    end
end
ns.ApplySizeToMember = ApplySizeToMember

local function BuildMemberVisual(self)
    self:SetSize(103, 56)   -- tamaño provisorio; initialConfigFunction del header lo pisa
    if self.RegisterForClicks then self:RegisterForClicks("AnyUp") end   -- solo members reales (Button)
    -- Mouseover (tooltip) + click-to-target/menu (pedido del usuario 2026-07-20:
    -- "cada uno es un boton, deberia poder seleccionarlos y que funcione el
    -- mouseover"). El click-to-target/togglemenu YA funciona via los atributos
    -- "*type1"/"*type2" que el header copia a cada member (ver CreateRaidHeader)
    -- -- solo faltaba habilitar el mouse + el tooltip nativo (igual patron que
    -- CreateUnit en Units.lua).
    -- FIX (2026-07-20, "solo puedo clickear zonas por fuera de los botones
    -- para mover"): si el mouse queda habilitado en CADA member/ghost, se
    -- comen el click ANTES de que le llegue al header (que es el que
    -- arrastra) -- solo quedaba arrastrable el huequito entre barras.
    -- Los GHOSTS (frames simples, sin unidad real, "self.RegisterForClicks"
    -- ausente) SIEMPRE tienen mouse habilitado -- solo existen/se muestran
    -- durante Lock, y sin unidad real no hay tooltip/target que perder. Los
    -- members REALES (Button, unidad real) siguen el estado de Lock via
    -- ns.SetRaidMembersMouseEnabled (llamado desde Editing.lua al entrar/
    -- salir), para no perder tooltip/target en juego normal.
    if self.RegisterForClicks then
        self:EnableMouse(not ns.IsUnlocked())
    else
        self:EnableMouse(true)
    end
    -- FIX (2026-07-20, "si hago click sobre uno de los botones... no pasa
    -- nada"): en vez de depender de que el click "atraviese" el member hasta
    -- el header de abajo, CADA member/ghost reenvia su propio drag
    -- DIRECTAMENTE al header (StartRaidHeaderDrag/StopRaidHeaderDrag,
    -- definidas arriba) -- asi arrastrar funciona sin importar si el cursor
    -- esta sobre un hueco vacio o justo encima de una barra.
    self:RegisterForDrag("LeftButton")
    self:SetScript("OnDragStart", StartRaidHeaderDrag)
    self:SetScript("OnDragStop", StopRaidHeaderDrag)

    local bg = self:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetAllPoints(self)
    bg:SetColorTexture(0, 0, 0, 0.5)

    local cage = self:CreateTexture(nil, "ARTWORK")
    cage:Hide()

    -- Barra de vida: tamaño/posicion FIJOS (calcados de AzeriteUI), no llena
    -- el member entero -- el backdrop (cage, mas grande) es lo decorativo.
    local bar = CreateFrame("StatusBar", nil, self)
    bar:SetSize(RAID_BAR_W, RAID_BAR_H)
    bar:SetPoint("BOTTOM", self, "BOTTOM", 0, RAID_BAR_Y)
    bar:SetFrameLevel(self:GetFrameLevel() + 1)
    bar:SetStatusBarTexture(ns.TEXTURE_DEFAULT)
    bar:SetOrientation("HORIZONTAL")

    local fillTex = bar:CreateTexture(nil, "OVERLAY")
    fillTex:Hide()

    -- Barra de poder: tira fina de 1px pegada debajo de la de vida (igual AzeriteUI).
    local powerBar = CreateFrame("StatusBar", nil, self)
    powerBar:SetSize(RAID_POWER_W, RAID_POWER_H)
    powerBar:SetPoint("BOTTOM", self, "BOTTOM", 0, RAID_POWER_Y)
    powerBar:SetFrameLevel(self:GetFrameLevel() + 1)
    powerBar:SetStatusBarTexture(RAID_POWER_TEX)
    powerBar:SetOrientation("HORIZONTAL")

    local powerFill = powerBar:CreateTexture(nil, "OVERLAY")
    powerFill:Hide()

    local overlay = CreateFrame("Frame", nil, self)
    overlay:SetAllPoints(self)
    overlay:SetFrameLevel(self:GetFrameLevel() + 3)

    -- Highlight de "es mi target/focus" (cast_back_outline en AzeriteUI) --
    -- detras de todo, tamaño/color fijados via db.units.raid.highlight* (Style tab).
    local highlight = self:CreateTexture(nil, "BACKGROUND", nil, -8)
    highlight:SetPoint("CENTER")
    highlight:Hide()

    local hpText = overlay:CreateFontString(nil, "OVERLAY")
    hpText:SetTextColor(ns.GOLD.r, ns.GOLD.g, ns.GOLD.b, 1)

    local nameText = overlay:CreateFontString(nil, "OVERLAY")
    nameText:SetTextColor(ns.GOLD.r, ns.GOLD.g, ns.GOLD.b, 1)
    nameText:SetJustifyH("CENTER")
    nameText:SetWordWrap(false)

    -- FontString "muda" para la mitad de poder (UnitUpdateText la necesita para
    -- no crashear con u.hpText nil -- ver ns.UnitUpdateBar en Units.lua -- pero
    -- se mantiene oculta para siempre: el numero de poder no se muestra aca).
    local powerHP = overlay:CreateFontString(nil, "OVERLAY")
    powerHP:Hide()

    -- Marca de banda (raid target icon), unico icono de AzeriteUI implementado
    -- por ahora (ready-check/resurrect/role quedan pendientes). API nativa:
    -- GetRaidTargetIndex(unit) + SetRaidTargetIconTexture (calcula texcoords
    -- solo, atlas estandar de Blizzard).
    local raidTargetIcon = overlay:CreateTexture(nil, "OVERLAY")
    raidTargetIcon:SetSize(14, 14)
    raidTargetIcon:SetTexture([[Interface\TargetingFrame\UI-RaidTargetingIcons]])
    raidTargetIcon:SetPoint("RIGHT", nameText, "LEFT", -2, 0)
    raidTargetIcon:Hide()

    -- Ready check (encima de la barra, centrado -- igual AzeriteUI). Texturas
    -- nativas de Blizzard, sin asset propio.
    local readyCheckIcon = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
    readyCheckIcon:SetSize(20, 20)
    readyCheckIcon:SetPoint("CENTER", bar, "CENTER", 0, 0)
    readyCheckIcon:Hide()

    -- Icono de resurreccion pendiente (mismo lugar; en la practica casi nunca
    -- coincide en el tiempo con el ready check).
    local resurrectIcon = overlay:CreateTexture(nil, "OVERLAY", nil, 6)
    resurrectIcon:SetSize(20, 20)
    resurrectIcon:SetTexture([[Interface\RaidFrame\Raid-Icon-Rez]])
    resurrectIcon:SetPoint("CENTER", bar, "CENTER", 0, 0)
    resurrectIcon:Hide()

    -- Rol de grupo (tank/healer -- AzeriteUI no muestra DPS): plate + icono,
    -- afuera del borde derecho del member (igual GroupRolePosition de AzeriteUI).
    local roleBackdrop = overlay:CreateTexture(nil, "ARTWORK", nil, 1)
    roleBackdrop:SetSize(28, 28)
    roleBackdrop:SetTexture(ResolveTex("point_plate.tga"))
    roleBackdrop:SetPoint("RIGHT", self, "RIGHT", 25, 0)
    roleBackdrop:Hide()
    roleBackdrops[#roleBackdrops + 1] = roleBackdrop
    local roleIcon = overlay:CreateTexture(nil, "ARTWORK", nil, 2)
    roleIcon:SetSize(20, 20)
    roleIcon:SetPoint("CENTER", roleBackdrop, "CENTER", 0, 0)
    roleIcon:Hide()

    -- "raid1" como placeholder: al OnLoad todavia no corrio el paso seguro que
    -- asigna el atributo "unit" real (recien llega en el primer TickRaid) --
    -- las funciones de Units.lua reutilizadas aca (UnitHealthMax/UnitPower/etc)
    -- asumen SIEMPRE un token de unidad valido, nunca nil.
    local u = {
        key = "raid", unit = self:GetAttribute("unit") or "raid1", label = "Raid",
        kind = "health", isMouseOver = false,
        button = self, bg = bg, cage = cage, bar = bar, fillTex = fillTex,
        overlay = overlay, hpText = hpText, nameText = nameText,
        highlight = highlight, raidTargetIcon = raidTargetIcon,
        readyCheckIcon = readyCheckIcon, resurrectIcon = resurrectIcon,
        roleBackdrop = roleBackdrop, roleIcon = roleIcon,
    }
    local pu = {
        key = "raid", unit = u.unit, label = "RaidPower",
        kind = "power", isMouseOver = false,
        button = self, bg = bg, bar = powerBar, fillTex = powerFill,
        overlay = overlay, hpText = powerHP,
    }

    PositionRaidIcons(u)
    ApplySizeToMember(u, pu)

    self:SetScript("OnEnter", function()
        u.isMouseOver = true
        if UnitExists(u.unit) then
            GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
            GameTooltip:SetUnit(u.unit)
            GameTooltip:Show()
        end
    end)
    self:SetScript("OnLeave", function()
        u.isMouseOver = false
        GameTooltip:Hide()
    end)

    return u, pu
end

-- Member REAL (llamado UNA vez por frame fisico, desde el OnLoad del
-- template XML -- ver Raid.xml).
function ns.BuildRaidMember(self)
    local u, pu = BuildMemberVisual(self)
    ns.raidFrames[self] = u
    ns.raidPowerFrames[self] = pu
    ns.UnitApplyAppearance(u)
    ns.UnitApplyAppearance(pu)

    -- Click izquierdo = target, derecho = menu contextual, puestos DIRECTO en
    -- el boton (redundante con "*type1"/"*type2" que ya se setean en el
    -- header y que SecureGroupHeaderTemplate deberia propagar solo -- pero
    -- Midnight 12.0.7 tiene varios quirks propios en el sistema de secure
    -- headers de raid, asi que se fija tambien directo aca por si esa
    -- propagacion automatica no anda como en un retail normal).
    self:SetAttribute("type1", "target")
    self:SetAttribute("type2", "togglemenu")
end

-- Puente global: el OnLoad del template XML no ve el upvalue `ns` (esta fuera
-- del vararg de este chunk), asi que se expone UNA funcion global minima que
-- delega en la de arriba (que si es un closure sobre `ns`).
function MyCF_BuildRaidMember(self)
    ns.BuildRaidMember(self)
end

-- ==========================================================================
-- VISIBILIDAD AUTOMATICA
-- "aparece en cualquier raid o si mi grupo supera los 5 jugadores, y en BG":
-- [group:raid] cubre RAID y BG por igual (un BG activo es internamente un
-- grupo de raid, sin importar el tamaño) -- mismo hallazgo ya documentado para
-- PartyDriverString (Units.lua) con [group:raid] para OCULTAR party en raid/BG.
-- Un grupo de PARTY normal nunca pasa de 5 (Blizzard lo convierte a raid solo
-- al sumar el 6to), asi que "mi grupo supera los 5" ya queda cubierto por
-- [group:raid] sin necesitar chequeo Lua de tamaño.
-- ==========================================================================
-- SOLO raid real y BG (pedido del usuario 2026-07-20: "quita lo de party,
-- que solo funcione en raids y bg" -- se saco el modo party por completo,
-- las unitframes party1-5 propias del addon en Units.lua no se tocan).
-- FIX (2026-07-20, ida y vuelta con el usuario): [instance:arena] (macro)
-- excluia por error brawls tipo Deephaul Ravine (instanceType=="arena"
-- internamente aunque se jueguen como BG) -- pero [group:raid] solo NO
-- alcanza, el usuario confirmo que el raid frames SI sigue apareciendo en
-- arena real (2v2/3v3/5v5). Reemplazado por un chequeo LUA (no macro):
-- C_PvP.IsArena() -- mismo metodo ya usado en PartyAuraPreview.lua (InArena)
-- para esta misma distincion, pero SIN el fallback a instanceType=="arena"
-- (ese fallback es justamente lo que confundia los brawls con arena real).
-- Se recalcula en cada llamada a ns.UpdateRaidDrivers (PLAYER_ENTERING_WORLD/
-- GROUP_ROSTER_UPDATE/ZONE_CHANGED_NEW_AREA, ver mas abajo), asi que el driver
-- se re-registra con el string correcto al entrar/salir de una arena real.
local function IsRealArena()
    local ok, isArena = pcall(function() return C_PvP and C_PvP.IsArena and C_PvP.IsArena() end)
    return ok and isArena and true or false
end
local function RaidDriverString()
    local cfg = ns.GetDB() and ns.GetDB().units and ns.GetDB().units.raid
    if not (cfg and cfg.enabled) then return "hide" end
    if IsRealArena() then return "hide" end
    return "[group:raid] show; hide"
end

local raidNeedsDriver = false
function ns.UpdateRaidDrivers()
    if not raidHeader then return end
    -- En preview NO se toca el driver (Editing.lua ya lo desregistra + fuerza
    -- Show() a mano); re-registrarlo aca lo evaluaria al instante y, si no hay
    -- raid real, lo ocultaria de nuevo pisando el forced-show. Se aplica recien
    -- al SALIR del lock (mismo patron que UpdatePartyDrivers en Units.lua).
    if ns.IsUnlocked() then return end
    if InCombatLockdown() then raidNeedsDriver = true; return end
    raidNeedsDriver = false
    UnregisterStateDriver(raidHeader, "visibility")
    RegisterStateDriver(raidHeader, "visibility", RaidDriverString())
end

-- ==========================================================================
-- TICK (llamado desde el ticker central de core.lua, mas lento que el de
-- party/portraits/auras -- 40 barras de vida no necesitan 10Hz reales).
-- ==========================================================================
function ns.TickRaid()
    for button, u in pairs(ns.raidFrames) do
        if button:IsShown() then
            local unit = button:GetAttribute("unit")
            if type(unit) == "string" and unit ~= "" and UnitExists(unit) then
                u.unit = unit
                ns.UnitUpdateColor(u)
                ns.UnitUpdateBar(u)   -- tambien actualiza hpText/nameText
                ns.UnitUpdateHighlight(u)
                if u.raidTargetIcon then
                    -- ns.safeVal (pcall + descarta secretos): mismo criterio
                    -- de seguridad que el resto del addon para cualquier
                    -- UnitXxx/GetXxx que pueda devolver un valor secreto en
                    -- Midnight 12.0.7 (limpieza 2026-07-20, faltaba aca).
                    local idx = ns.safeVal(GetRaidTargetIndex, unit)
                    if idx then
                        SetRaidTargetIconTexture(u.raidTargetIcon, idx)
                        u.raidTargetIcon:Show()
                    else
                        u.raidTargetIcon:Hide()
                    end
                end
                -- Ready check: GetReadyCheckStatus(unit) devuelve "ready"/
                -- "notready"/"waiting" mientras hay uno activo, o nil si no
                -- hay ninguno -- se puede consultar directo, sin trackear
                -- eventos READY_CHECK_* por separado.
                if u.readyCheckIcon then
                    local status = ns.safeVal(GetReadyCheckStatus, unit)
                    if status == "ready" then
                        u.readyCheckIcon:SetTexture([[Interface\RaidFrame\ReadyCheck-Ready]]); u.readyCheckIcon:Show()
                    elseif status == "notready" then
                        u.readyCheckIcon:SetTexture([[Interface\RaidFrame\ReadyCheck-NotReady]]); u.readyCheckIcon:Show()
                    elseif status == "waiting" then
                        u.readyCheckIcon:SetTexture([[Interface\RaidFrame\ReadyCheck-Waiting]]); u.readyCheckIcon:Show()
                    else
                        u.readyCheckIcon:Hide()
                    end
                end
                if u.resurrectIcon then
                    u.resurrectIcon:SetShown(ns.safeBool(UnitHasIncomingResurrection, unit))
                end
                if u.roleIcon and u.roleBackdrop then
                    local role = ns.safeVal(UnitGroupRolesAssigned, unit)
                    if role == "TANK" or role == "HEALER" then
                        u.roleIcon:SetTexture(ResolveTex(role == "TANK" and "grouprole-icons-tank.tga" or "grouprole-icons-heal.tga"))
                        u.roleIcon:Show(); u.roleBackdrop:Show()
                    else
                        u.roleIcon:Hide(); u.roleBackdrop:Hide()
                    end
                end
                local pu = ns.raidPowerFrames[button]
                if pu then
                    pu.unit = unit
                    ns.UnitUpdateColor(pu)
                    ns.UnitUpdateBar(pu)
                end
            end
        end
    end
end

-- Tamaño MAXIMO que puede ocupar el grid (unitsPerColumn x maxColumns,
-- topeado a 40) -- se usa para dimensionar el header (asi el outline verde
-- de Lock realmente ENVUELVE el area donde van a aparecer las barras, en vez
-- de quedar un cuadrito 200x200 sin relacion con el contenido real). Solo
-- soporta las 2 combinaciones simplificadas: growPoint LEFT/RIGHT (horizontal
-- dentro de la fila) + columnAnchorPoint TOP/BOTTOM (las filas se apilan
-- verticalmente) -- pedido del usuario: "que control de layout sea mas
-- simple, que crezcan de la izquierda o derecha".
local function ComputeGridSize(cfg)
    local perRow = math.max(1, cfg.unitsPerColumn or 5)
    local maxRows = math.max(1, cfg.maxColumns or 8)
    local total = math.min(40, perRow * maxRows)
    local rows = math.min(maxRows, math.ceil(total / perRow))
    local cols = math.min(perRow, total)
    local w = cols * cfg.width + math.max(0, cols - 1) * (cfg.growXOffset or 0)
    local h = rows * cfg.height + math.max(0, rows - 1) * (cfg.columnSpacing or 0)
    return math.max(w, cfg.width), math.max(h, cfg.height)
end
ns.ComputeGridSize = ComputeGridSize

-- El header SIEMPRE se ancla via CENTER-CENTER para SU PROPIA posicion en
-- pantalla (igual convencion que Minimap/InfoBar/MicroMenu al arrastrarse).
-- FIX (2026-07-20, "sigo sin poder mover limpiamente, los botones
-- bloquean"): con CENTER, SetSize agranda el rectangulo SIMETRICAMENTE hacia
-- los 4 lados desde ese mismo centro fijo -- los members anclan a los
-- BORDES reales del header (via "LEFT"/"TOP"/etc, calculados en pantalla en
-- el momento, sin importar como el header se ancla a si mismo), asi que el
-- rectangulo del header SIEMPRE coincide con el area real del grid sin
-- importar growPoint/columnAnchorPoint. (Con un anclaje de ESQUINA fija tipo
-- TOPLEFT, en cambio, el rectangulo solo crece hacia un lado -- si el grid
-- crecia para el OTRO lado quedaba desalineado del area realmente visible.)
-- ==========================================================================
-- REPOSICION DEL CONTENEDOR: SOLO cuando algo de la posicion realmente
-- cambio (relativePoint/offsetX/offsetY/anchorFrame/scale) -- NUNCA en cada
-- RefreshRaid. FIX (2026-07-20, "se desposiciona y se daña el outline" al
-- apagar/prender el toggle de Lock): ClearAllPoints+SetPoint+SetScale se
-- ejecutaban en CADA llamada a RefreshRaid (hide-toggle, cambio de estilo,
-- roster nuevo, etc), sin relacion con si la posicion realmente cambio --
-- eso es lo que producia el salto/daño visual. Ahora se cachea la ultima
-- posicion aplicada y se compara antes de tocar nada.
-- ==========================================================================
local lastPos = {}
local function RepositionRaidHeaderIfChanged(cfg)
    if ns.CompensateScale then ns.CompensateScale(cfg) end
    if lastPos.relativePoint == cfg.relativePoint
       and lastPos.offsetX == cfg.offsetX and lastPos.offsetY == cfg.offsetY
       and lastPos.anchorFrame == cfg.anchorFrame and lastPos.scale == cfg.scale then
        return
    end
    lastPos.relativePoint = cfg.relativePoint
    lastPos.offsetX, lastPos.offsetY = cfg.offsetX, cfg.offsetY
    lastPos.anchorFrame, lastPos.scale = cfg.anchorFrame, cfg.scale

    local parent = _G[cfg.anchorFrame]
    if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
    raidHeader:ClearAllPoints()
    raidHeader:SetPoint("CENTER", parent, cfg.relativePoint, cfg.offsetX, cfg.offsetY)
    raidHeader:SetScale(cfg.scale or 1)
end

-- ==========================================================================
-- REFRESH (reconstruye atributos del header desde db.units.raid + reposiciona
-- el contenedor SOLO si hizo falta). Llamado desde ns.ApplyCurrent/
-- ns.RefreshAll y al tocar cualquier slider del menu RAID.
-- ==========================================================================
local raidNeedsRefresh = false
function ns.RefreshRaid()
    if not raidHeader then return end
    if InCombatLockdown() then raidNeedsRefresh = true; return end
    raidNeedsRefresh = false

    RefreshRoleBackdrops()

    -- Reafirma la apariencia hardcodeada ANTES de leer cfg (asi ningun dato
    -- viejo guardado ni ningun otro codigo puede desviar el look real).
    ns.ForceRaidStyle()
    local db = ns.GetDB()
    local cfg = db.units.raid

    -- Layout SIMPLIFICADO (pedido del usuario 2026-07-20): solo 2 direcciones
    -- posibles por eje, member size fijo, sin spacing vertical separado.
    if cfg.growPoint ~= "LEFT" and cfg.growPoint ~= "RIGHT" then cfg.growPoint = "LEFT" end
    if cfg.columnAnchorPoint ~= "TOP" and cfg.columnAnchorPoint ~= "BOTTOM" then cfg.columnAnchorPoint = "TOP" end
    cfg.growYOffset = 0
    cfg.width, cfg.height = 103, 56

    raidHeader:SetAttribute("point", cfg.growPoint)
    raidHeader:SetAttribute("xOffset", cfg.growXOffset)
    raidHeader:SetAttribute("yOffset", 0)
    raidHeader:SetAttribute("unitsPerColumn", cfg.unitsPerColumn)
    raidHeader:SetAttribute("maxColumns", cfg.maxColumns)
    raidHeader:SetAttribute("columnSpacing", cfg.columnSpacing)
    raidHeader:SetAttribute("columnAnchorPoint", cfg.columnAnchorPoint)
    raidHeader:SetAttribute("initial-width", cfg.width)
    raidHeader:SetAttribute("initial-height", cfg.height)
    -- Solo raid/BG (pedido del usuario 2026-07-20): showParty SIEMPRE false,
    -- el grupo chico lo cubren las unitframes party1-5 propias del addon.
    raidHeader:SetAttribute("showParty", false)

    -- Posicion del contenedor: SOLO se toca si algo realmente cambio (ver
    -- RepositionRaidHeaderIfChanged) -- toggles de Lock/estilo ya NO
    -- disparan un ClearAllPoints/SetPoint/SetScale de mas.
    RepositionRaidHeaderIfChanged(cfg)

    -- Dimensiona el header al tamaño MAXIMO configurado (ver ComputeGridSize):
    -- asi el outline de Lock (editBG, SetAllPoints el header) realmente
    -- envuelve el area del grid y se puede agarrar/escalar desde ahi.
    raidHeader:SetSize(ComputeGridSize(cfg))

    ns.UpdateRaidDrivers()

    -- Re-aplica estilo (texturas/colores/cage/fuente) a los members YA creados
    -- (el roster no cambio, solo el perfil visual) + reposiciona sus iconos
    -- (por si el usuario tocó los sliders de posicion de icono en el menu).
    for button, u in pairs(ns.raidFrames) do
        ns.UnitApplyAppearance(u)
        local pu = ns.raidPowerFrames[button]
        if pu then ns.UnitApplyAppearance(pu) end
        PositionRaidIcons(u)
        ApplySizeToMember(u, pu)
    end
    if ghostUnits then
        for i, u in ipairs(ghostUnits) do
            -- FIX (2026-07-23, "necesito reload para que se vea en el
            -- preview"): los ghosts (preview de Lock sin raid real) solo se
            -- texturean UNA vez al crearse (EnsureGhosts) -- a diferencia de
            -- los members reales (arriba), este loop nunca les reaplicaba la
            -- apariencia, asi que un cambio de skin/textura solo se veia tras
            -- reconstruir los ghosts con un /reload.
            ns.UnitApplyAppearance(u)
            local pu = ghostPowerUnits and ghostPowerUnits[i]
            if pu then ns.UnitApplyAppearance(pu) end
            PositionRaidIcons(u)
            ApplySizeToMember(u, pu)
        end
    end

    if ns.RefreshOutlineNames then ns.RefreshOutlineNames() end
    ns.ApplyRaidPreviewHide()
    if ns.UpdateRaidGhosts then ns.UpdateRaidGhosts() end
end

-- ==========================================================================
-- RESET (llamado desde ns.ResetUnit -- ver el branch agregado en core.lua).
-- ==========================================================================
function ns.ResetRaid()
    local db = ns.GetDB()
    if not db then return end
    db.units = db.units or {}
    db.units.raid = ns.RaidUnitDefaults()
    ns.RefreshRaid()
end

-- ==========================================================================
-- GHOSTS: preview visual en Lock cuando NO hay raid real. Un secure group
-- header no se puede poblar con unidades falsas fuera de un roster real, asi
-- que se dibuja un pool de hasta 40 frames NORMALES (no seguros) reusando
-- BuildMemberVisual, posicionados con el MISMO algoritmo de anclaje en
-- cadena que usa Blizzard puertas adentro para SecureGroupHeaderTemplate
-- (point/xOffset/yOffset dentro de cada columna, columnAnchorPoint/
-- columnSpacing entre columnas -- ver wowprogramming.com/docs/secure_template/
-- Group_Headers.html). Nunca se registran en ns.raidFrames -> TickRaid no
-- los toca; se quedan con el valor "de muestra" que UnitUpdateBar ya pinta
-- en preview (100%, nombre+60).
-- ==========================================================================
local GHOST_MAX = 40

local function GetRelPoint(point)
    if point == "TOP" then return "BOTTOM", 0, -1
    elseif point == "BOTTOM" then return "TOP", 0, 1
    elseif point == "LEFT" then return "RIGHT", 1, 0
    elseif point == "RIGHT" then return "LEFT", -1, 0 end
    return "CENTER", 0, 0
end

local function EnsureGhosts()
    if ghosts then return end
    ghosts, ghostUnits, ghostPowerUnits = {}, {}, {}
    for i = 1, GHOST_MAX do
        local g = CreateFrame("Frame", nil, raidHeader)
        local u, pu = BuildMemberVisual(g)
        ns.UnitApplyAppearance(u)
        ns.UnitApplyAppearance(pu)
        -- FIX (2026-07-20, reportado por el usuario: "en los nombres de raid
        -- frames sale raid 60, deberian ser del 1 al 40"): UnitApplyAppearance
        -- (rama preview de UnitUpdateBar en Units.lua) siempre escribe
        -- "u.label .. ' 60'" -- como los 40 ghosts comparten label="Raid",
        -- salian todos identicos. Los ghosts NUNCA se tickean (no tienen
        -- unidad real), asi que este SetText es definitivo, no hace falta
        -- reaplicarlo en cada refresh.
        if u.nameText then u.nameText:SetText(tostring(i)) end
        -- Pedido del usuario 2026-07-20: "que los iconos salgan en el raid 1
        -- cuando este en lock para poder previsualizarlos" -- estos iconos
        -- normalmente solo los prende TickRaid segun el estado REAL de la
        -- unidad (que un ghost no tiene), asi que sin esto quedarian
        -- invisibles para siempre y no se podria ver donde caen los sliders
        -- de posicion de la pestaña Icons. Solo el ghost #1 (member 1) los
        -- muestra de muestra; el resto se quedan ocultos como siempre.
        if i == 1 then
            if u.raidTargetIcon then SetRaidTargetIconTexture(u.raidTargetIcon, 8); u.raidTargetIcon:Show() end
            if u.readyCheckIcon then u.readyCheckIcon:SetTexture([[Interface\RaidFrame\ReadyCheck-Ready]]); u.readyCheckIcon:Show() end
            if u.roleIcon and u.roleBackdrop then
                u.roleIcon:SetTexture(ResolveTex("grouprole-icons-tank.tga"))
                u.roleIcon:Show(); u.roleBackdrop:Show()
            end
        end
        g:Hide()
        ghosts[i] = g
        ghostUnits[i] = u
        ghostPowerUnits[i] = pu
    end
end

local function LayoutGhosts()
    if not ghosts then return end
    local cfg = ns.GetDB().units.raid
    local point = cfg.growPoint or "LEFT"
    local relPoint, xMult, yMult = GetRelPoint(point)
    xMult, yMult = math.abs(xMult), math.abs(yMult)
    local xOffset, yOffset = cfg.growXOffset or 0, cfg.growYOffset or 0
    local unitsPerColumn = math.max(1, cfg.unitsPerColumn or 5)
    local maxColumns = math.max(1, cfg.maxColumns or 8)
    local columnAnchorPoint = cfg.columnAnchorPoint or "TOP"
    local colRelPoint, colXMult, colYMult = GetRelPoint(columnAnchorPoint)
    colXMult, colYMult = math.abs(colXMult), math.abs(colYMult)
    local columnSpacing = cfg.columnSpacing or 0
    local w, h = cfg.width or 80, cfg.height or 36
    -- "Ver 1 raid o los 40" (pedido del usuario): con el toggle apagado se
    -- muestra un unico member de muestra en vez del grid completo.
    local showAll = ns.GetDB().raidGhostShowAll ~= false
    local shownCount = showAll and math.min(GHOST_MAX, unitsPerColumn * maxColumns) or 1

    local buttonNum, columnUnitCount, currentAnchor = 0, 0, raidHeader
    for i, g in ipairs(ghosts) do
        if i > shownCount then
            g:Hide()
        else
            buttonNum = buttonNum + 1
            columnUnitCount = columnUnitCount + 1
            if columnUnitCount > unitsPerColumn then columnUnitCount = 1 end
            g:SetSize(w, h)
            g:ClearAllPoints()
            if buttonNum == 1 then
                -- 2 anclajes (igual que el header seguro real de Blizzard):
                -- uno fija el eje de crecimiento horizontal, el otro el
                -- vertical -- asi el primer member cae en la ESQUINA exacta
                -- combinando ambas direcciones, no solo centrado en un eje.
                g:SetPoint(point, raidHeader, point, 0, 0)
                g:SetPoint(columnAnchorPoint, raidHeader, columnAnchorPoint, 0, 0)
            elseif columnUnitCount == 1 then
                local columnAnchor = ghosts[buttonNum - unitsPerColumn]
                g:SetPoint(columnAnchorPoint, columnAnchor, colRelPoint, colXMult * columnSpacing, colYMult * columnSpacing)
            else
                g:SetPoint(point, currentAnchor, relPoint, xMult * xOffset, yMult * yOffset)
            end
            currentAnchor = g
            g:Show()
        end
    end
end

-- Habilita/deshabilita el mouse de los members REALES -- llamado desde
-- Editing.lua al entrar/salir de Lock (para no perder tooltip/target en
-- juego normal). Los ghosts SIEMPRE tienen mouse habilitado (ver
-- BuildMemberVisual) -- solo existen/se muestran durante Lock de todos
-- modos, no hace falta tocarlos aca.
function ns.SetRaidMembersMouseEnabled(enabled)
    for button in pairs(ns.raidFrames) do button:EnableMouse(enabled) end
end

-- Mostrar ghosts SOLO si estamos en Lock Y no hay members reales visibles
-- (si hay un raid real activo, se ve el grid real -- no hace falta el ghost).
function ns.UpdateRaidGhosts()
    if not raidHeader then return end
    if not ns.IsUnlocked() then
        if ghosts then for _, g in ipairs(ghosts) do g:Hide() end end
        return
    end
    -- OJO: los members reales NUNCA se destruyen al vaciarse el roster
    -- (Blizzard los recicla ocultos) -> ns.raidFrames sigue teniendo entradas
    -- de una sesion vieja de raid. Chequear SHOWN, no solo existencia.
    local hasRealMembers = false
    for button in pairs(ns.raidFrames) do
        if button:IsShown() then hasRealMembers = true; break end
    end
    if hasRealMembers then
        if ghosts then for _, g in ipairs(ghosts) do g:Hide() end end
        return
    end
    EnsureGhosts()
    LayoutGhosts()
end

-- FIX (2026-07-20, "ya no tiene outline"): el borde FINO de 1px de
-- ns.MakeEditHighlight (el mismo que usa CADA elemento del addon) queda
-- tapado por los 40 members: cada uno tiene su propio cage (cast_back.tga,
-- 132x85, MAS GRANDE que el member 103x56) que se solapa con los vecinos y
-- cubre los huecos/bordes finos. Border propio: mas GRUESO (3px), por AFUERA
-- del rectangulo real del header (offset -10/+10, no cambia tamaño/anclaje
-- de nada) y a un frame level bien alto -- siempre visible arriba de
-- cualquier cage por mas que se solape.
local function CreateThickBorder(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", -10, 10)
    f:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 10, -10)
    f:SetFrameLevel(parent:GetFrameLevel() + 20)
    local function edge(rp1, x1, y1, rp2, x2, y2)
        local b = f:CreateTexture(nil, "OVERLAY")
        b:SetColorTexture(0.35, 0.78, 1.0, 0.95)   -- mismo celeste que ns.MakeEditHighlight
        b:SetPoint("TOPLEFT", f, rp1, x1, y1); b:SetPoint("BOTTOMRIGHT", f, rp2, x2, y2)
    end
    local t = 3
    edge("TOPLEFT", 0, 0, "TOPRIGHT", 0, -t)
    edge("BOTTOMLEFT", 0, t, "BOTTOMRIGHT", 0, 0)
    edge("TOPLEFT", 0, 0, "BOTTOMLEFT", t, 0)
    edge("TOPRIGHT", -t, 0, "BOTTOMRIGHT", 0, 0)
    f:Hide()
    return f
end

-- ==========================================================================
-- CREACION DEL HEADER (una sola vez, en OnEnable-equivalente de core.lua --
-- ver el hook agregado al PLAYER_LOGIN/ADDON_LOADED existente).
-- ==========================================================================
local function CreateRaidHeader()
    if raidHeader then return end

    raidHeader = CreateFrame("Frame", "MyCF_RaidHeader", UIParent, "SecureGroupHeaderTemplate")
    raidHeader:SetSize(200, 200)
    raidHeader:SetMovable(true)
    raidHeader:RegisterForDrag("LeftButton")
    raidHeader:EnableMouse(false)

    local editBG = ns.MakeEditHighlight(raidHeader, "Raid Frames")
    raidHeader.editBG = editBG
    raidHeader.thickBorder = CreateThickBorder(raidHeader)

    -- Atributos del template de member: creado via Raid.xml (unico XML del
    -- addon). templateType="Button" porque SecureUnitButtonTemplate (heredado
    -- por MyCF_RaidMemberTemplate) es un Button.
    raidHeader:SetAttribute("template", "MyCF_RaidMemberTemplate")
    raidHeader:SetAttribute("templateType", "Button")
    raidHeader:SetAttribute("initialConfigFunction", [[
        self:SetWidth(self:GetParent():GetAttribute("initial-width"));
        self:SetHeight(self:GetParent():GetAttribute("initial-height"));
    ]])

    raidHeader:SetAttribute("showRaid", true)
    raidHeader:SetAttribute("showPlayer", true)
    raidHeader:SetAttribute("sortMethod", "INDEX")
    raidHeader:SetAttribute("sortDir", "ASC")
    raidHeader:SetAttribute("groupBy", "GROUP")
    raidHeader:SetAttribute("groupingOrder", "1,2,3,4,5,6,7,8")
    raidHeader:SetAttribute("groupFilter", "1,2,3,4,5,6,7,8")
    -- Prefijo "*": SecureGroupHeaderTemplate copia estos atributos a CADA
    -- member creado (click izquierdo = target, derecho = menu contextual
    -- nativo de unidad), mismo patron que CreateUnit en Units.lua.
    raidHeader:SetAttribute("*type1", "target")
    raidHeader:SetAttribute("*type2", "togglemenu")

    raidHeader:SetScript("OnDragStart", StartRaidHeaderDrag)
    raidHeader:SetScript("OnDragStop", StopRaidHeaderDrag)

    ns.AttachScaleWheel(raidHeader, function() return ns.GetDB().units.raid end, function() ns.RefreshRaid() end)

    ns.RefreshRaid()
end

-- "Hide in preview (Lock only)" (lockHide.raidframes): oculta el grid entero
-- SOLO mientras se edita (Editing.lua ya fuerza rh:Show() en preview -- esto
-- lo pisa despues, sin tocar la visibilidad normal fuera de Lock).
function ns.ApplyRaidPreviewHide()
    if not raidHeader then return end
    if not ns.IsUnlocked() then return end
    -- BUG FIX (2026-07-20, "se desposiciona y se daña el outline" al
    -- apagar/prender): Hide()/Show() sobre un SecureGroupHeaderTemplate
    -- fuerza a Blizzard a reevaluar/reconfigurar sus children internamente
    -- al volver a mostrarse, lo que puede pisar la posicion/tamaño que
    -- nosotros ya habiamos puesto. Alpha+EnableMouse es 100% seguro (nunca
    -- toca geometria/anclajes) y logra el mismo efecto visual -- mismo
    -- criterio que el resto del addon usa para "hide in preview" de texto/
    -- badges (alpha, nunca Show/Hide de frames con layout propio).
    local hide = ns.GetDB().lockHide and ns.GetDB().lockHide.raidframes
    raidHeader:SetAlpha(hide and 0 or 1)
    raidHeader:EnableMouse(not hide)
    -- FIX (2026-07-20, "el outline on y off no apaga el de raid frames"):
    -- el alpha del header SI cascadea a sus hijos (incluido editBG), pero se
    -- fuerza tambien EXPLICITO por las dudas -- editBG es el unico elemento
    -- de este addon con su propio SetShown independiente del padre.
    if raidHeader.editBG then
        raidHeader.editBG:SetShown((not hide) and not (ns.GetDB().hideEditOutline))
    end
    if raidHeader.thickBorder then
        raidHeader.thickBorder:SetShown((not hide) and not (ns.GetDB().hideEditOutline))
    end
end

-- ==========================================================================
-- EVENTOS
-- ==========================================================================
local raidEvents = CreateFrame("Frame")
raidEvents:RegisterEvent("ADDON_LOADED")
raidEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
raidEvents:RegisterEvent("GROUP_ROSTER_UPDATE")
raidEvents:RegisterEvent("ZONE_CHANGED_NEW_AREA")
raidEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
raidEvents:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        -- core.lua registra su propio ADDON_LOADED ANTES (carga primero en el
        -- toc) -> InitDB()/FillDefaults() ya corrieron cuando este handler
        -- se dispara, asi que db.units.raid ya existe.
        CreateRaidHeader()
        return
    end
    if not raidHeader then return end
    if event == "PLAYER_REGEN_ENABLED" then
        if raidNeedsDriver then ns.UpdateRaidDrivers() end
        if raidNeedsRefresh then ns.RefreshRaid() end
        return
    end
    ns.UpdateRaidDrivers()
end)
