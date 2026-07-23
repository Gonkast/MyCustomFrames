-- ==========================================================================
-- MyCustomFrames - Editing.lua
-- MODO EDICION/PREVIEW: grid de alineacion, snap entre elementos, SetUnlocked
-- (entra/sale de preview), integracion con el Edit Mode de Blizzard, copiar/pegar
-- settings entre elementos. Extraido de core.lua (mismo motivo/patron que
-- Units.lua/Portraits.lua/Auras.lua/InfoBar.lua), usa ns.GetDB()/ns.IsUnlocked()
-- en vez de los locals db/unlocked de core (SetUnlocked usa ns.SetUnlockedFlag
-- para escribir el flag, ya que "unlocked" sigue siendo un local PROPIO de core.lua).
-- Carga DESPUES de core.lua, Units.lua, Portraits.lua, Auras.lua e InfoBar.lua.
-- ==========================================================================
local ADDON, ns = ...
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
    if not ns.GetDB() then return end
    local show = ns.IsUnlocked() and ns.GetDB().gridShow
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
    for _, u in pairs(ns.frames) do add(u.button) end
    for _, u in pairs(ns.portraits) do add(u.root) end
    for _, g in pairs(ns.auras) do add(g.root) end
    if ns.infobar then add(ns.infobar.root) end
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
    if not (ns.GetDB() and ns.IsUnlocked()) then return end
    local es = frame:GetEffectiveScale()
    local uies = UIParent:GetEffectiveScale()
    local fx, fy = frame:GetCenter()
    if not (fx and es and uies and es > 0 and uies > 0) then return end
    local fpx, fpy = fx * es, fy * es               -- centro del frame (px abs)
    local nx, ny = fpx, fpy
    local snappedX, snappedY = false, false

    -- 1) Snap ENTRE ELEMENTOS (bordes/centros).
    if ns.GetDB().snapElements then
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
    if ns.GetDB().gridSnap then
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

-- ==========================================================================
-- PANEL FLOTANTE DE VISIBILIDAD EN LOCK (pedido del usuario 2026-07-20: "en
-- el move lock me gustaria que salga un panel para controlar que se ve o no
-- durante el lock... eso no deberia afectar nada fuera del lock"). Aparece
-- SOLO mientras ns.IsUnlocked(). Agrupado por UNIDAD (no por subsistema): el
-- toggle "Player" apaga el unitframe Y el portrait del player JUNTOS, etc
-- (pedido explicito: "el player incluye portrait y unitframe player, lo
-- mismo con target/pet, boss1-5 juntos, arena1-6 juntos incluye portraits,
-- party1-5 juntos incluye portraits"). Estetica calcada del menu principal:
-- mismo fondo (ns.PL.BG), mismo divisor (ns.PL.DIV_H), misma fuente/colores
-- y mismo estilo de checkbox que MakeToggle en Options.lua.
-- ==========================================================================
local LOCK_COLOR_TITLE  = { 215/255, 192/255, 163/255 }
local LOCK_COLOR_OPTION = { 226/255, 216/255, 199/255 }

-- unit* = claves de ns.frames a ocultar; portrait* = claves de ns.portraits;
-- aura* = claves de ns.auras. Player/Target incluyen su power bar (playerpower/
-- targetpower) Y su grupo de auras (pedido del usuario 2026-07-20: "debe
-- incluir el player por ejemplo las power bar y tambien el target, auras").
local LOCK_GROUPS = {
    { label = "Player",  key = "player", units = { "player", "playerpower" },
      portraits = { "portrait_player" }, auras = { "aura_player" } },
    { label = "Target",  key = "target", units = { "target", "targetpower" },
      portraits = { "portrait_target" }, auras = { "aura_target" } },
    { label = "Pet",     key = "pet",    units = { "pet" },     portraits = { "portrait_pet" } },
    { label = "ToT",     key = "tot",    units = { "targettarget" }, portraits = { "portrait_tot" } },
    { label = "Focus",   key = "focus",  units = { "focus" },   portraits = { "portrait_focus" } },
    { label = "Boss 1-5", key = "boss",  units = { "boss1", "boss2", "boss3", "boss4", "boss5" }, portraits = {} },
    { label = "Party 1-5", key = "party", units = { "party1", "party2", "party3", "party4", "party5" },
      portraits = { "portrait_party1", "portrait_party2", "portrait_party3", "portrait_party4", "portrait_party5" } },
    { label = "Arena 1-6", key = "arena", units = { "arena_player", "arena_party1", "arena_party2",
        "arena_enemy1", "arena_enemy2", "arena_enemy3" },
      portraits = { "portrait_arena_player", "portrait_arena_party1", "portrait_arena_party2",
        "portrait_arena_enemy1", "portrait_arena_enemy2", "portrait_arena_enemy3" } },
    { label = "Minimap",     key = "minimap" },     -- guard propio en Minimap.lua
    { label = "Mirror Timer", key = "mirrortimer" },-- guard propio en MirrorTimers.lua
    { label = "Raid frames", key = "raidframes" },  -- guard propio en Raid.lua
    { label = "Micro menu",  key = "micromenu" },   -- guard propio en MicroMenu.lua
    { label = "Info bar",    key = "infobar" },     -- guard propio en InfoBar.lua
    { label = "Quest Tracker", key = "tracker" },   -- guard propio en Tracker.lua (ApplyPreviewHide)
}

-- Solo player/target/pet/boss/party/arena necesitan aplicarse desde aca (los
-- otros 3 ya se leen adentro de Minimap.lua/MirrorTimers.lua/Raid.lua). Corre
-- SOLO en Lock -- fuera de Lock nunca se toca (TickUnits/TickPortraits/
-- TickAuras no corren en preview, asi que esto no compite con nada mas).
local function ApplyGlobalLockHide()
    if not ns.IsUnlocked() then return end
    local lh = ns.GetDB().lockHide or {}
    for _, grp in ipairs(LOCK_GROUPS) do
        if grp.units then
            local hide = lh[grp.key] and true or false
            for _, uk in ipairs(grp.units) do
                local u = ns.frames[uk]
                if u and u.button then u.button:SetShown(not hide) end
            end
            for _, pk in ipairs(grp.portraits or {}) do
                local p = ns.portraits[pk]
                if p and p.root then p.root:SetShown(not hide) end
            end
            for _, ak in ipairs(grp.auras or {}) do
                local g = ns.auras[ak]
                if g and g.root then g.root:SetShown(not hide) end
            end
        end
    end
end
ns.ApplyGlobalLockHide = ApplyGlobalLockHide

local ROW_H = 22
local lockPanel
local function MakeLockCheckbox(parent, label, y, getf, setf)
    local cb = CreateFrame("Button", nil, parent)
    cb:SetPoint("TOPLEFT", 8, y)
    cb:SetSize(174, ROW_H)
    local hl = cb:CreateTexture(nil, "BACKGROUND")
    hl:SetColorTexture(1, 1, 1, 0.08)
    hl:SetPoint("TOPLEFT", -4, 1); hl:SetPoint("BOTTOMRIGHT", 4, -1)
    hl:Hide()
    local box = cb:CreateTexture(nil, "ARTWORK")
    box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
    box:SetSize(18, 18)
    box:SetPoint("LEFT", 0, 0)
    local check = cb:CreateTexture(nil, "OVERLAY")
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:SetSize(18, 18)
    check:SetPoint("LEFT", 0, 0)
    check:SetVertexColor(LOCK_COLOR_OPTION[1], LOCK_COLOR_OPTION[2], LOCK_COLOR_OPTION[3])
    local lbl = cb:CreateFontString(nil, "ARTWORK")
    lbl:SetFont(ns.PL and ns.PL.FONT or "Fonts\\FRIZQT__.TTF", 11)
    lbl:SetPoint("LEFT", box, "RIGHT", 4, 0)
    lbl:SetTextColor(LOCK_COLOR_OPTION[1], LOCK_COLOR_OPTION[2], LOCK_COLOR_OPTION[3])
    lbl:SetText(label)
    local function refresh() check:SetShown(getf() and true or false) end
    cb:SetScript("OnEnter", function() hl:Show() end)
    cb:SetScript("OnLeave", function() hl:Hide() end)
    cb:SetScript("OnClick", function() setf(not (getf() and true or false)); refresh() end)
    cb.refresh = refresh
    return cb
end

local function BuildLockPanel()
    if lockPanel then return lockPanel end
    local rows = #LOCK_GROUPS + 1   -- +1 fila del toggle "1 / 40"
    local f = CreateFrame("Frame", "MyCF_LockPanel", UIParent)
    f:SetSize(190, 40 + rows * ROW_H)
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -220)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    -- Mismo fondo que el panel principal de opciones (ns.PL.BG, Plumber).
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    if ns.PL and ns.PL.BG then bg:SetTexture(ns.PL.BG) else bg:SetColorTexture(0, 0, 0, 0.85) end

    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont(ns.PL and ns.PL.FONT or "Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    title:SetPoint("TOP", f, "TOP", 0, -8)
    title:SetText("Hide in Lock")
    title:SetTextColor(LOCK_COLOR_TITLE[1], LOCK_COLOR_TITLE[2], LOCK_COLOR_TITLE[3])

    local div = f:CreateTexture(nil, "ARTWORK")
    div:SetPoint("TOPLEFT", 6, -26); div:SetPoint("TOPRIGHT", -6, -26); div:SetHeight(2)
    if ns.PL and ns.PL.DIV_H then div:SetTexture(ns.PL.DIV_H) else div:SetColorTexture(1, 1, 1, 0.2) end

    local checks = {}
    for i, grp in ipairs(LOCK_GROUPS) do
        local key = grp.key
        local cb = MakeLockCheckbox(f, grp.label, -34 - (i - 1) * ROW_H,
            function() return ns.GetDB().lockHide and ns.GetDB().lockHide[key] end,
            function(v)
                local db = ns.GetDB()
                db.lockHide = db.lockHide or {}
                db.lockHide[key] = v or nil
                if key == "minimap" or key == "mirrortimer" or key == "raidframes"
                   or key == "micromenu" or key == "infobar" then
                    if ns.RefreshAll then ns.RefreshAll() end
                end
                if key == "tracker" and ns.ApplyTrackerPreviewHide then ns.ApplyTrackerPreviewHide() end
                ApplyGlobalLockHide()
            end)
        checks[#checks + 1] = cb
    end

    -- "Ver 1 raid o los 40" (pedido del usuario) -- solo afecta al preview
    -- fantasma de Raid.lua cuando no hay un raid real (con raid real, se ve
    -- el roster real completo siempre).
    local raidCb = MakeLockCheckbox(f, "Raid preview: all 40", -34 - #LOCK_GROUPS * ROW_H,
        function() return ns.GetDB().raidGhostShowAll ~= false end,
        function(v)
            ns.GetDB().raidGhostShowAll = v and true or false
            if ns.UpdateRaidGhosts then ns.UpdateRaidGhosts() end
        end)
    checks[#checks + 1] = raidCb

    f._checks = checks
    lockPanel = f
    return f
end

local function RefreshLockPanel(show)
    if not show then
        if lockPanel then lockPanel:Hide() end
        return
    end
    local f = BuildLockPanel()
    for _, cb in ipairs(f._checks) do cb.refresh() end
    f:Show()
end

local function SetUnlocked(state)
    if InCombatLockdown() then
        print("|cffff0000[MCF]|r You can't edit in combat.")
        return
    end
    ns.SetUnlockedFlag(state)
    local hideGreen = ns.GetDB() and ns.GetDB().hideEditOutline
    for _, u in pairs(ns.frames) do
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
                u.button:SetShown(ns.PowerShouldShow(u))
            elseif u.driver then
                RegisterStateDriver(u.button, "visibility", u.driver)
            else
                RegisterUnitWatch(u.button)
            end
        end
    end
    for _, u in pairs(ns.portraits) do
        -- Fuera de preview conserva el mouse si abre el panel de personaje (clickOpenChar).
        u.root:EnableMouse(state or (ns.PP(u) and ns.PP(u).clickOpenChar and true or false))
        u.root:EnableMouseWheel(state)
        -- En preview oculta los botones estaticos (para poder arrastrar/editar el portrait sin
        -- que el area de click tape la zona; al salir se recolocan con la posicion final).
        if state then
            if u.charBtnCenter then u.charBtnCenter:Hide() end
            if u.charBtnAlt then u.charBtnAlt:Hide() end
        end
    end
    if not state and ns.LayoutPortraitCharButtonsAll then ns.LayoutPortraitCharButtonsAll() end
    for _, g in pairs(ns.auras) do
        g.root:EnableMouse(state and true or false)
        g.root:EnableMouseWheel(state)
    end
    if ns.infobar then ns.infobar.root:EnableMouse(state and true or false); ns.infobar.root:EnableMouseWheel(state) end
    if ns.topWidgetHolder then
        ns.topWidgetHolder:EnableMouse(state and true or false)
        ns.topWidgetHolder:EnableMouseWheel(state)
    end
    if ns.micromenu then ns.micromenu:EnableMouse(state and true or false); ns.micromenu:EnableMouseWheel(state) end
    if _G.MyCF_RaidHeader then
        local rh = _G.MyCF_RaidHeader
        rh:EnableMouse(state and true or false)
        rh:EnableMouseWheel(state)
        if rh.editBG then rh.editBG:SetShown(state and not hideGreen or false) end
        if rh.thickBorder then rh.thickBorder:SetShown(state and not hideGreen or false) end
        -- FIX (2026-07-20, "es dificil encontrar la zona para mover el
        -- outline"): apaga el mouse de CADA member/ghost individual en Lock
        -- (si no, se comen el click antes de que le llegue al header) y lo
        -- repone al salir (para tooltip/target normal).
        if ns.SetRaidMembersMouseEnabled then ns.SetRaidMembersMouseEnabled(not state) end
        -- Igual patron que Units.lua: en preview se fuerza visible (sin el
        -- state driver) para poder arrastrar el grid aunque no haya raid real;
        -- al salir se restaura el driver de auto-show normal.
        if state then
            UnregisterStateDriver(rh, "visibility")
            rh:Show()
            if ns.ApplyRaidPreviewHide then ns.ApplyRaidPreviewHide() end
        elseif ns.UpdateRaidDrivers then
            -- Saliendo del Lock: lockHide NUNCA debe afectar nada fuera de
            -- preview, asi que el alpha se repone a 1 SIEMPRE aca (sin
            -- importar el estado del toggle "Raid frames" en el panel).
            rh:SetAlpha(1)
            ns.UpdateRaidDrivers()
        end
    end
    if not state and ns.UpdatePetDriver then ns.UpdatePetDriver() end
    -- Al entrar/salir de preview el alpha se fuerza a 1: limpiar la cache del Explorer
    -- (_exAlpha) para que no arranque desde un valor viejo al retomar el fade.
    if ns.ExplorerResetAll then ns.ExplorerResetAll() end
    ns.RefreshAll()
    UpdateGrid()
    RefreshLockPanel(state)
    ApplyGlobalLockHide()
    if ns.OnUnlockChanged then ns.OnUnlockChanged(state) end
    print(state and "|cff00ff00[MCF]|r Preview ON." or "|cff00ff00[MCF]|r Preview OFF.")
end
ns.SetUnlocked = SetUnlocked
ns.ToggleEditOutline = function()
    if ns.IsUnlocked() then
        local hideGreen = ns.GetDB() and ns.GetDB().hideEditOutline
        for _, u in pairs(ns.frames) do u.editBG:SetShown(not hideGreen) end
        for _, u in pairs(ns.portraits) do if u.editBG then u.editBG:SetShown(not hideGreen) end end
        for _, g in pairs(ns.auras) do if g.editBG then g.editBG:SetShown(not hideGreen) end end
        if ns.infobar and ns.infobar.editBG then ns.infobar.editBG:SetShown(not hideGreen) end
        if ns.topWidgetHolder and ns.topWidgetHolder.editBG then ns.topWidgetHolder.editBG:SetShown(not hideGreen) end
        if _G.MyCF_RaidHeader then
            local rh = _G.MyCF_RaidHeader
            if rh.editBG then rh.editBG:SetShown(not hideGreen) end
            if rh.thickBorder then rh.thickBorder:SetShown(not hideGreen) end
        end
        if _G.MyCF_ClassPower and _G.MyCF_ClassPower.editBG then
            _G.MyCF_ClassPower.editBG:SetShown(not hideGreen)
        end
        -- Pedido del usuario 2026-07-19: "cuando apago el outline de todas
        -- las barras no se apagan las de el mirror timer" -- este toggle
        -- rapido (sin salir de Lock) no incluia el preview de MirrorTimers.lua,
        -- que maneja su propio editBG por separado (ver RefreshPreview alla).
        if ns.RefreshMirrorTimerPreview then ns.RefreshMirrorTimerPreview() end
    end
end

SLASH_MYCUSTOMFRAMES1 = "/mcf"
SlashCmdList["MYCUSTOMFRAMES"] = function() SetUnlocked(not ns.IsUnlocked()) end

-- DIAGNOSTICO: /mcfchar — vuelca el estado del boton de abrir personaje (existe/visible/
-- tamaño/posicion + estado de CharacterMicroButton) para saber POR QUE no abre sin adivinar.
SLASH_MCFCHAR1 = "/mcfchar"
SlashCmdList["MCFCHAR"] = function()
    local u = ns.portraits and ns.portraits["portrait_player"]
    print("|cff00ff00[MCF diag]|r portrait_player existe: " .. tostring(u ~= nil))
    if not u then return end
    local p = ns.PP(u)
    print("  clickOpenChar=" .. tostring(p and p.clickOpenChar) .. "  ns.IsUnlocked()=" .. tostring(ns.IsUnlocked()))
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
-- abre tambien el modo edicion del addon (y al cerrarlo, lo cierra), asi mueves los ns.frames
-- de Blizzard Y los del addon en la misma sesion. Opcional (ns.GetDB().syncBlizzEditMode, default on).
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
            local d = ns.GetDB()
            if d and d.syncBlizzEditMode ~= false and not ns.IsUnlocked() and not InCombatLockdown() then
                SetUnlocked(true)
            end
        end)
        emf:HookScript("OnHide", function()
            local d = ns.GetDB()
            if d and d.syncBlizzEditMode ~= false and ns.IsUnlocked() and not InCombatLockdown() then
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
    copyBuffer = ns.DeepCopy(ns.CurrentProfile())
    print("|cff00ff00[MCF]|r Copied from: " .. ns.currentEdit)
end
ns.PasteSettings = function()
    if not copyBuffer then print("|cffff0000[MCF]|r Nothing copied.") return end
    local p = ns.CurrentProfile()
    for k, v in pairs(copyBuffer) do
        if not COPY_EXCLUDE[k] then p[k] = ns.DeepCopy(v) end
    end
    ns.RefreshUnit(ns.currentEdit)
    if ns.OnProfilePasted then ns.OnProfilePasted() end
    print("|cff00ff00[MCF]|r Pasted into: " .. ns.currentEdit)
end
