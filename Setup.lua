-- ==========================================================================
-- Setup.lua — asistente de PRIMERA INSTALACION (6 paginas: que hace el addon, que addons
-- con perfil incluido tenes instalados, opciones globales reducidas, hide-when-mounted +
-- auto-hide del tracker, Explorer Mode, y aplicar el preset Gonkast (perfiles de Bartender4/
-- DynamicCam/Masque/Chattynator) + el HUD de Blizzard Edit Mode). Se muestra UNA sola vez
-- (db.setupSeen); reabrible a mano con /mcfsetup.
-- Reusa el toolkit visual de Options.lua (ns.UI) y la deteccion/aplicacion de
-- perfiles de ProfilesApply.lua (ns.ProfilesStatus/ns.ProfilesInfo/ns.ApplyProfilesFiltered).
-- Carga al final del toc: necesita ns.UI, ns.PL, ns.GetDB y el sistema de perfiles ya listos.
-- ==========================================================================
local ADDON, ns = ...

-- Assets tomados de Plumber (Icons/Button), copiados localmente para no depender de que
-- Plumber este instalado. El "ExpansionBorder" y el fondo "checklist" resultaron ser atlas
-- con varios widgets empaquetados (se veian rotos al estirarlos) y se descartaron: solo se
-- usan aca piezas simples de un solo sprite (divisor, icono, check verde).
local A = "Interface\\AddOns\\MyCustomFrames\\Assets\\"
local ART = {
    DIVIDER     = A .. "Setup_Divider.tga",
    CHECK_ICON  = A .. "Setup_ChecklistIcon.png",
    CHECK_GREEN = A .. "Setup_CheckmarkGreen.blp",
    CHECKBOX    = A .. "Setup_Checkbox.png",
}

-- Assets PROPIOS del usuario para este wizard (carpeta "Setup Assets").
local U = A .. "Setup Assets\\"
local CUSTOM = {
    BG       = U .. "Background_Setup.tga",
    EXIT     = U .. "Exit_Button.tga",
    APPLY    = U .. "Apply_Button.tga",
    NAVBTN   = U .. "skip_next_back_finish_Button.tga",
    PAGE     = U .. "Page.tga",
    PAGE_CUR = U .. "Curret_Page.tga",
}

-- Ancho de contenido comun a las 3 paginas (con margen respecto al marco del fondo propio).
local CONTENT_W = 720

-- Fuente pedida para el wizard (Blizzard FRIZQT, distinta de la Lato del panel de opciones).
local FRIZQT = "Fonts\\FRIZQT__.TTF"
local function SF(fs, size, flags)
    if not fs:SetFont(FRIZQT, size, flags or "") then fs:SetFontObject("GameFontNormal") end
end

-- 2026-07-17: actualizada para que coincida EXACTO con la paleta final de
-- Options.lua (misma jerarquia con contraste real entre roles: titulo dorado
-- saturado, texto de opcion casi blanco, descripcion gris-tostado apagado,
-- lineas marron oscuro). Antes tenia sus propios valores viejos (786553 etc),
-- todos muy parecidos entre si — mismo problema de falta de contraste que
-- tenia Options.lua antes de esta ronda de ajustes. NO se tocan texturas.
local COLOR_TITLE  = { 215 / 255, 192 / 255, 163 / 255 }   -- dorado-tostado (headers/titulos)
local COLOR_DESC   = { 163 / 255, 157 / 255, 147 / 255 }   -- gris-tostado apagado (notas/descripciones)
local COLOR_LINE   = { 148 / 255, 124 / 255, 102 / 255 }   -- marron oscuro (separadores, nunca texto)
local COLOR_OPTION = { 226 / 255, 216 / 255, 199 / 255 }   -- casi blanco calido (checkboxes/labels)

-- Parrafo de una linea (con wrap) en el ancho de contenido comun: usado para el cuerpo de
-- texto de cada pagina (evita repetir SetWidth/SetJustifyH/SetWordWrap/SetTextColor 3 veces).
-- Color fijo (COLOR_DESC): antes cada llamada pasaba su propio r,g,b, pero Plumber usa un
-- unico color de descripcion en todos lados.
local function Paragraph(parent, x, y, size, text)
    local fs = parent:CreateFontString(nil, "ARTWORK")
    SF(fs, size)
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetWidth(CONTENT_W); fs:SetJustifyH("LEFT"); fs:SetWordWrap(true)
    fs:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
    fs:SetText(text)
    return fs
end

-- Boton generico con textura propia: normal = la textura tal cual; hover = LA MISMA
-- textura en capa ADD (se ilumina); presionado = la misma textura un poco mas oscura.
-- Asi no hace falta un asset de "highlight" separado, como pidio el usuario.
local function TexButton(parent, texturePath, w, h, text, fontSize)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    b:SetNormalTexture(texturePath)
    b:SetHighlightTexture(texturePath, "ADD")
    b:SetPushedTexture(texturePath)
    local pt = b:GetPushedTexture()
    if pt then pt:SetVertexColor(0.75, 0.75, 0.75) end
    if text then
        local fs = b:CreateFontString(nil, "OVERLAY")
        SF(fs, fontSize or 13)
        fs:SetPoint("CENTER", 0, 1)
        -- 2026-07-17: (1,0.92,0.75) era un tono propio, no el COLOR_TITLE
        -- compartido con el resto del wizard/panel principal.
        fs:SetTextColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
        fs:SetText(text)
        b.text = fs
    end
    return b
end

-- Dropdown 3-slice (asset "EditModeDropdown.png" de Plumber, copiado local: Setup_Dropdown.png):
-- la textura de nav (pill grande para Skip/Back/Next) se veia rara achicada a tamaño de
-- dropdown, asi que este usa el mismo patron 3-slice + texcoords que Plumber usa para SU
-- propio dropdown (fondo BACKGROUND recortado en 3 franjas + highlight ADD al pasar el mouse).
local DROPDOWN_TEX = "Interface\\AddOns\\MyCustomFrames\\Assets\\Setup_Dropdown.png"
local function DropdownButton(parent, w, h, text, fontSize)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    local capW = 16
    local function slice(layer, top, bottom)
        local left = b:CreateTexture(nil, layer)
        left:SetTexture(DROPDOWN_TEX)
        left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(capW)
        left:SetTexCoord(0, 32 / 256, top, bottom)
        local right = b:CreateTexture(nil, layer)
        right:SetTexture(DROPDOWN_TEX)
        right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT"); right:SetWidth(capW)
        right:SetTexCoord(176 / 256, 1, top, bottom)
        local mid = b:CreateTexture(nil, layer)
        mid:SetTexture(DROPDOWN_TEX)
        mid:SetPoint("TOPLEFT", left, "TOPRIGHT"); mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
        mid:SetTexCoord(32 / 256, 176 / 256, top, bottom)
        return { left, mid, right }
    end
    slice("BACKGROUND", 0, 80 / 256)
    local hl = slice("HIGHLIGHT", 160 / 256, 240 / 256)
    for _, t in ipairs(hl) do t:SetVertexColor(0.3, 0.3, 0.3); t:SetBlendMode("ADD") end

    local fs = b:CreateFontString(nil, "OVERLAY")
    SF(fs, fontSize or 12)
    fs:SetPoint("LEFT", 10, 0); fs:SetPoint("RIGHT", -22, 0)
    fs:SetJustifyH("LEFT"); fs:SetMaxLines(1)
    fs:SetTextColor(COLOR_OPTION[1], COLOR_OPTION[2], COLOR_OPTION[3])
    fs:SetText(text or "")
    b.text = fs

    local arrow = b:CreateFontString(nil, "OVERLAY")
    SF(arrow, fontSize or 12)
    arrow:SetPoint("RIGHT", -8, 0)
    arrow:SetTextColor(COLOR_LINE[1], COLOR_LINE[2], COLOR_LINE[3])
    arrow:SetText("v")
    return b
end

-- Sufijo visual para toggles "recomendados" (Plumber no tiene un skin de checkbox dedicado
-- para esto — se investigo su codigo y lo unico parecido es un icono de "tiene sub-opciones"
-- y un tag de "nueva funcion", ninguno es realmente "recomendado". Un sufijo de texto en
-- dorado es el equivalente honesto mas simple).
-- Un tono mas claro que COLOR_TITLE (mismo matiz, mas luminosidad) para que resalte sobre
-- el resto del texto en vez de mezclarse con el.
local REC = "  |cffd6b896(recommended)|r"

local PAGE_COUNT = 8
local frame, contentPages, selected = nil, {}, {}
local curPage = 1
local pageDots, backBtn, nextBtn, skipBtn, stepLabel

local function UI() return ns.UI end

-- Headers/toggles del toolkit compartido nacen con la fuente Lato del panel de opciones;
-- estos wrappers los crean igual y despues fuerzan FRIZQT sobre sus FontStrings.
local function Header(parent, text, x, y, width)
    local fs = UI().MakeHeader(parent, text, x, y, width or CONTENT_W)
    SF(fs, 14)
    fs:SetTextColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
    if fs.div then fs.div:SetVertexColor(COLOR_LINE[1], COLOR_LINE[2], COLOR_LINE[3], 0.6) end
    return fs
end
local function Toggle(parent, label, x, y, getf, setf)
    local cb = UI().MakeToggle(parent, label, x, y, getf, setf)
    if cb.label then
        SF(cb.label, 12)
        cb.label:SetTextColor(COLOR_OPTION[1], COLOR_OPTION[2], COLOR_OPTION[3])
        -- MakeToggle ya pone su propio OnEnter/OnLeave (blanco al pasar el mouse, vuelve a SU
        -- color hardcodeado al salir) — HookScript solo AGREGA, asi que hay que re-aplicar
        -- COLOR_OPTION en OnLeave o el hover lo dejaria en el color viejo al soltar el mouse.
        cb:HookScript("OnLeave", function() cb.label:SetTextColor(COLOR_OPTION[1], COLOR_OPTION[2], COLOR_OPTION[3]) end)
    end
    -- Reskin del checkbox con el atlas de checkbox de Plumber (EditModeCheckbox.png):
    -- mismos texcoords que su propio CreateCheckbox (SharedWidgets.lua) — cuadro en el
    -- cuadrante superior-izquierdo, tilde en el sub-cuadrante superior-derecho del inferior-
    -- derecho. Mas limpio que el "UI-Checkbox-Check" de Blizzard que usa el panel principal.
    if cb.box then
        cb.box:SetTexture(ART.CHECKBOX)
        cb.box:SetTexCoord(0, 0.5, 0, 0.5)
        cb.box:SetSize(22, 22)
    end
    if cb.check then
        cb.check:SetTexture(ART.CHECKBOX)
        cb.check:SetTexCoord(0.5, 0.75, 0.5, 0.75)
        -- Plumber usa box=32/check=16 (mitad exacta); nuestro box=22 => check~11 mantiene la
        -- misma proporcion. El tilde se veia corrido porque antes era desproporcionadamente
        -- grande (14, casi 2/3 del box en vez de 1/2), lo que sacaba el glifo del recorte
        -- centrado visualmente.
        cb.check:SetSize(11, 11)
        cb.check:ClearAllPoints()
        cb.check:SetPoint("CENTER", cb.box, "CENTER", 0, 0)
        cb.check:SetVertexColor(1, 1, 1)
    end
    -- BUG real: MakeToggle crea el tilde SIEMPRE visible y solo lo sincroniza con el valor
    -- real al hacer click, o cuando el panel de Options.lua recorre su lista interna de
    -- "refreshers" al abrirse (algo que el wizard nunca dispara). Sin este refresh() inicial,
    -- TODOS los toggles del wizard se ven tildados sin importar el valor real hasta que se
    -- clickean una vez — exactamente el bug reportado ("los no recomendados siguen prendidos").
    if cb.refresh then cb.refresh() end
    return cb
end
-- Toggle con tooltip: HookScript (no SetScript) para no pisar el OnEnter/OnLeave que ya
-- pone MakeToggle (highlight de fila al pasar el mouse) — solo se AGREGA el tooltip encima.
local function TooltipToggle(parent, label, x, y, getf, setf, tip)
    local cb = Toggle(parent, label, x, y, getf, setf)
    if tip then
        cb:HookScript("OnEnter", function(self)
            if GameTooltip:IsForbidden() then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:HookScript("OnLeave", function() if not GameTooltip:IsForbidden() then GameTooltip:Hide() end end)
    end
    return cb
end

-- Glow pulsante para llamar la atencion sobre el boton de accion principal de una pagina
-- (pedido del usuario 2026-07-20: "la mayoria clickea Next hasta el final" -- necesita algo
-- OBVIO en los botones Apply de las paginas 6/7, no solo texto que se puede seguir ignorando).
-- Reusa la misma textura que el glow de action bar del addon (Assets\actionbuttonhighlight.tga)
-- para que se sienta parte del mismo addon, no un elemento ajeno.
local GLOW_TEX = A .. "actionbuttonhighlight.tga"
local function AttentionGlow(btn, pad)
    pad = pad or 10
    local g = btn:CreateTexture(nil, "OVERLAY", nil, 1)
    g:SetTexture(GLOW_TEX)
    g:SetBlendMode("ADD")
    g:SetPoint("TOPLEFT", btn, "TOPLEFT", -pad, pad)
    g:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", pad, -pad)
    local ag = g:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(0.25); a:SetToAlpha(1); a:SetDuration(0.7); a:SetSmoothing("IN_OUT")
    ag:Play()
    btn.attentionGlow = g
    -- Al clickear el boton, la pagina ya cumplio su proposito -- apaga el glow para no
    -- seguir insistiendo despues de que el usuario ya hizo lo que se le pedia.
    btn:HookScript("OnClick", function() ag:Stop(); g:Hide() end)
    return g
end

-- Fade suave al cambiar de pagina (en vez de Show/Hide seco).
local function FadeIn(f, duration)
    f:Show(); f:SetAlpha(0)
    if UIFrameFadeIn then
        UIFrameFadeIn(f, duration or 0.18, 0, 1)
    else
        f:SetAlpha(1)
    end
end

local function BuildFrame()
    local f = CreateFrame("Frame", "MCFSetupWizard", UIParent, "BackdropTemplate")
    f:SetSize(960, 760)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true); f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    -- El fondo del usuario (Background_Setup.tga) ya trae su propio marco ornamentado
    -- horneado en la imagen: no se le agrega un borde separado encima.
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(CUSTOM.BG)
    bg:SetAllPoints()

    local title = f:CreateFontString(nil, "ARTWORK")
    SF(title, 20)
    title:SetPoint("TOP", 0, -80)
    title:SetTextColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
    title:SetText("Welcome to Gonkast Preset")

    local tdiv = f:CreateTexture(nil, "ARTWORK")
    tdiv:SetTexture(ART.DIVIDER)
    tdiv:SetPoint("TOP", title, "BOTTOM", 0, 2)
    tdiv:SetSize(680, 16)
    tdiv:SetVertexColor(COLOR_LINE[1], COLOR_LINE[2], COLOR_LINE[3])

    -- "Step X of Y" ahora va ABAJO de los puntos de pagina (ver pageDots mas abajo),
    -- centrado, en vez de arriba pegado al titulo.
    stepLabel = f:CreateFontString(nil, "ARTWORK")
    SF(stepLabel, 12)
    stepLabel:SetPoint("BOTTOM", f, "BOTTOM", 0, 82)
    stepLabel:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])

    local closeBtn = TexButton(f, CUSTOM.EXIT, 38, 38)
    closeBtn:SetPoint("TOPRIGHT", -26, -40)
    closeBtn:SetScript("OnClick", function() ns.CloseSetupWizard(true) end)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", 76, -140)
    content:SetPoint("BOTTOMRIGHT", -76, 150)
    f._content = content

    -- Barra inferior, de arriba a abajo: puntos de pagina, "Step X of Y" centrado debajo de
    -- ellos, y los botones de navegacion mas adentro del fondo (propios: Page.tga /
    -- Curret_Page.tga para los puntos; skip_next_back_finish_Button para los botones).
    pageDots = {}
    for i = 1, PAGE_COUNT do
        local d = f:CreateTexture(nil, "OVERLAY")
        d:SetSize(20, 20)
        d:SetPoint("BOTTOM", f, "BOTTOM", (i - (PAGE_COUNT + 1) / 2) * 24, 104)
        d:SetTexture(CUSTOM.PAGE)
        pageDots[i] = d
    end

    skipBtn = TexButton(f, CUSTOM.NAVBTN, 160, 40, "Skip setup", 13)
    skipBtn:SetPoint("BOTTOMLEFT", 64, 64)
    skipBtn:SetScript("OnClick", function() ns.CloseSetupWizard(true) end)

    backBtn = TexButton(f, CUSTOM.NAVBTN, 130, 40, "< Back", 13)
    backBtn:SetPoint("BOTTOMRIGHT", -214, 64)
    backBtn:SetScript("OnClick", function() ns.SetupGoTo(curPage - 1) end)

    nextBtn = TexButton(f, CUSTOM.NAVBTN, 130, 40, "Next >", 13)
    nextBtn:SetPoint("BOTTOMRIGHT", -64, 64)
    nextBtn:SetScript("OnClick", function()
        if curPage < PAGE_COUNT then ns.SetupGoTo(curPage + 1) else ns.SetupFinish() end
    end)

    f:Hide()
    frame = f
    return content
end

-- ---------------- Pagina 1: que hace el addon ----------------
-- 2026-07-16: rediseño pedido por el usuario ("mas organizado y simplificado, mas limpio") — la
-- version vieja era una lista vertical de parrafos largos que dejaba muchisimo espacio vacio
-- abajo. Ahora es una GRILLA de 2 columnas x 3 filas (6 items cortos, titulo + descripcion en 1
-- linea) + un item "Extras" ancho completo abajo + nota de cierre en una franja separada por un
-- divisor, para usar el espacio de forma pareja en vez de un bloque de texto con hueco al final.
local FEATURES = {
    { title = "Unit frames",   desc = "Health/power/cast for player, target, pet, focus, boss1-5 and party1-5." },
    { title = "Raid frames",   desc = "Up to 40 players, AzeriteUI look. Raid groups and battlegrounds only." },
    { title = "Portraits",     desc = "Cage, background, model, role, leader and raid marker." },
    { title = "Class power",   desc = "All class resource points/runes, for every spec that has one." },
    { title = "Auras",         desc = "Buffs/debuffs with click-to-cancel, dual in-combat/idle positions." },
    { title = "Quest tracker", desc = "Colors the tracker, auto-hides in combat/boss/hostile target/PvP." },
    { title = "Info bar",      desc = "Clock, calendar, zone, FPS/MS, above the minimap." },
    { title = "Micro menu",    desc = "Replaces Blizzard's micro buttons with the preset's style." },
}
local EXTRAS_LINE = "Extras — minimap and nameplate reskins, mouselook, hide Blizzard UI, assisted glow, chat bubbles, Explorer Mode (fade on mouseover)."

local function FeatureCard(parent, x, y, w, title, desc)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ART.CHECK_ICON)
    icon:SetSize(15, 15)
    icon:SetPoint("TOPLEFT", x, y)

    local ttl = parent:CreateFontString(nil, "ARTWORK")
    SF(ttl, 13)
    ttl:SetPoint("TOPLEFT", x + 20, y + 1)
    ttl:SetTextColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
    ttl:SetText(title)

    local fs = parent:CreateFontString(nil, "ARTWORK")
    SF(fs, 11)
    fs:SetPoint("TOPLEFT", x + 20, y - 18)
    fs:SetWidth(w - 20); fs:SetJustifyH("LEFT"); fs:SetWordWrap(true)
    fs:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
    fs:SetText(desc)
end

local function BuildPage1(content)
    local p = CreateFrame("Frame", nil, content)
    p:SetAllPoints()
    Header(p, "What this addon does", 0, -2)

    local colW = (CONTENT_W - 24) / 2
    local L, R = 0, colW + 24
    -- ROW_H mas chico que antes (2026-07-20: se sumaron Raid Frames/Class
    -- Power, 6->8 features = 3->4 filas) para que las 4 filas + la fila
    -- "Extras" sigan entrando en el alto fijo de la pagina sin superponerse
    -- con el parrafo/boton de navegacion de abajo.
    local ROW_H = 56
    local numRows = math.ceil(#FEATURES / 2)
    for i, f in ipairs(FEATURES) do
        local col = ((i - 1) % 2 == 0) and L or R
        local row = math.floor((i - 1) / 2)
        FeatureCard(p, col, -34 - row * ROW_H, colW, f.title, f.desc)
    end
    local extrasY = -34 - numRows * ROW_H
    FeatureCard(p, L, extrasY, CONTENT_W, "Extras", EXTRAS_LINE)

    local divY = extrasY - 46
    local div = p:CreateTexture(nil, "ARTWORK")
    div:SetTexture(ART.DIVIDER)
    div:SetSize(CONTENT_W, 16)
    div:SetPoint("TOPLEFT", 0, divY)
    div:SetVertexColor(COLOR_LINE[1], COLOR_LINE[2], COLOR_LINE[3])

    Paragraph(p, 0, divY - 16, 11,
        "Everything is editable later with /mcfmenu (options panel), or /mcf to move/lock frames.")
    return p
end

-- ---------------- Pagina 2: addons detectados con perfil incluido ----------------
local function BuildPage2(content)
    local p = CreateFrame("Frame", nil, content)
    p:SetAllPoints()
    local icon = p:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ART.CHECK_ICON)
    icon:SetSize(18, 18)
    icon:SetPoint("TOPLEFT", 0, 1)
    Header(p, "Bundled profiles for other addons", 22, -2, CONTENT_W - 20)
    Paragraph(p, 4, -26, 11,
        "These addons are loaded and have a bundled Gonkast profile. Untick any you DON'T want replaced:")
    p._list = p._list or {}
    return p
end

local function RefreshPage2(p)
    for _, w in ipairs(p._list) do w:Hide() end
    wipe(p._list)
    local list = (ns.ProfilesStatus and ns.ProfilesStatus()) or {}
    local y = -50
    if #list == 0 then
        local fs = Paragraph(p, 4, y, 12,
            "No supported addons detected (Bartender4, DynamicCam, Masque, Chattynator).")
        table.insert(p._list, fs)
        return
    end
    for _, addon in ipairs(list) do
        if selected[addon] == nil then selected[addon] = true end
        local label = (ns.ProfilesInfo and ns.ProfilesInfo[addon]) or addon
        local cb = Toggle(p, label, 4, y,
            function() return selected[addon] end,
            function(v) selected[addon] = v end)
        table.insert(p._list, cb)
        -- Check "detectado" (addon cargado + con copia de SavedVariables lista para inyectar),
        -- independiente del tilde interactivo de la izquierda. COLUMNA FIJA a x=380 (2026-07-16,
        -- prolijidad pedida por el usuario): antes se anclaba a la derecha del LABEL (X distinta
        -- segun el largo de cada nombre) Y se pisaba con el label de Masque, el mas largo de
        -- todos (acortado aparte en ProfilesApply.lua INFO). **Color DORADO, no verde** (pedido
        -- del usuario): reusa el MISMO recorte de tilde que ya usan los checkboxes interactivos
        -- (ART.CHECKBOX, texcoords del glifo en Toggle) en vez de Setup_CheckmarkGreen.blp, para
        -- que combine con la paleta del resto del wizard.
        local detected = p:CreateTexture(nil, "ARTWORK")
        detected:SetTexture(ART.CHECKBOX)
        detected:SetTexCoord(0.5, 0.75, 0.5, 0.75)
        detected:SetSize(16, 16)
        detected:SetPoint("LEFT", p, "LEFT", 380, 0)
        detected:SetPoint("TOP", cb, "TOP", 0, -3)
        table.insert(p._list, detected)
        y = y - 26
    end
end

-- ---------------- Pagina 3: opciones globales (subset reducido, con tooltips) ----------------
-- Solo las 3 mas relevantes para alguien recien instalando (el resto sigue disponible
-- en el panel de opciones principal, seccion "Global options").
local function BuildPage3(content)
    local p = CreateFrame("Frame", nil, content)
    p:SetAllPoints()
    Header(p, "Global options", 0, -2)
    Paragraph(p, 4, -26, 11,
        "Turn any of these on or off now, or change them later from the addon's options panel. Hover each one for details.")

    -- Fuerza el estado recomendado al construir la pagina (UNA sola vez: las paginas se
    -- arman una vez y despues solo se muestran/ocultan). Sin esto, un personaje que ya
    -- tenia estas opciones en otro valor (de una sesion previa) mostraba el checkbox
    -- desincronizado del texto "(recommended)".
    do
        local d = ns.GetDB()
        if d then
            d.mouselook = true
            d.hideBlizzard = true
            d.dcFix = true
            if ns.HideBlizzardFrames then ns.HideBlizzardFrames() end
            if ns.ApplyDcFix then ns.ApplyDcFix() end
        end
    end

    local y = -56
    local function row(label, key, tip, onSet)
        TooltipToggle(p, label, 4, y, function() return ns.GetDB() and ns.GetDB()[key] end, function(v)
            local d = ns.GetDB(); if not d then return end
            d[key] = v
            if onSet then onSet(v) end
        end, tip)
        y = y - 26
    end

    row("Mouselook (right-click drag)" .. REC, "mouselook",
        "Holding the right mouse button turns the camera AND your character together, like most modern " ..
        "third-person games, instead of Blizzard's default free-camera drag.")
    row("Hide Blizzard unit frames" .. REC, "hideBlizzard",
        "Hides the default Blizzard player/pet/target/target-of-target/boss/party frames and cast bars, " ..
        "since this addon draws its own. Turning this OFF requires a /reload to bring them back.",
        function(v) if v and ns.HideBlizzardFrames then ns.HideBlizzardFrames() end end)
    row("DynamicCam camera fix" .. REC, "dcFix",
        "Fixes DialogueUI's compatibility with DynamicCam: opening DialogueUI's panel calls a method " ..
        "that freezes DynamicCam's camera and never releases it, breaking its custom camera situations. " ..
        "This neutralizes that call. Only matters if you use BOTH DialogueUI and DynamicCam — and " ..
        "DialogueUI's own \"Camera Movement\" option must be turned OFF for this to work.",
        function() if ns.ApplyDcFix then ns.ApplyDcFix() end end)

    -- Cierre visual (2026-07-16, prolijidad pedida por el usuario): esta pagina solo tiene 3
    -- toggles y dejaba un vacio grande hasta el final — un divisor + nota, igual que las paginas
    -- 1 y 6, cierra la pagina en vez de terminar en la nada.
    local div = p:CreateTexture(nil, "ARTWORK")
    div:SetTexture(ART.DIVIDER)
    div:SetSize(CONTENT_W, 16)
    div:SetPoint("TOPLEFT", 0, -150)
    div:SetVertexColor(COLOR_LINE[1], COLOR_LINE[2], COLOR_LINE[3])
    Paragraph(p, 0, -166, 11,
        "The full options panel (Interface Options > AddOns > this addon) has many more settings " ..
        "beyond these 3 — this page only surfaces the ones most people want to decide on day one.")
    return p
end

-- ---------------- Pagina 4: toggles por unidad (hide when mounted) + quest tracker ----------------
local UNIT_MOUNT_ROWS = {
    { "Player",       "player",      true },
    { "Target",       "target" },
    { "Player power", "playerpower", true },
    { "Target power", "targetpower" },
}
local TRACKER_AUTOHIDE_ROWS = {
    { "Hide in boss fights",      "hideInBoss",           true },
    { "Hide in combat",           "hideInCombat",         true },
    { "Hide on hostile target",   "hideOnHostileTarget" },
    { "Hide in arena",            "hideInArena" },
    { "Hide in battlegrounds",    "hideInBG" },
}
local function BuildPage4(content)
    local p = CreateFrame("Frame", nil, content)
    p:SetAllPoints()
    Header(p, "Unit & quest tracker options", 0, -2)
    Paragraph(p, 4, -26, 11,
        "Hide these unit frames while mounted, and auto-hide the quest tracker in the situations below.")

    -- Fuerza el estado recomendado al construir (ver comentario igual en BuildPage3).
    do
        local d = ns.GetDB()
        if d and d.units then
            for _, row in ipairs(UNIT_MOUNT_ROWS) do
                local key = row[2]
                if d.units[key] then d.units[key].hideWhenMounted = row[3] or false end
            end
        end
        if d and d.tracker then
            for _, row in ipairs(TRACKER_AUTOHIDE_ROWS) do d.tracker[row[2]] = row[3] or false end
        end
    end

    Header(p, "Hide when mounted", 4, -56, 340)
    local y = -80
    for _, row in ipairs(UNIT_MOUNT_ROWS) do
        local key = row[2]
        Toggle(p, row[1] .. (row[3] and REC or ""), 4, y,
            function() local d = ns.GetDB(); return d and d.units and d.units[key] and d.units[key].hideWhenMounted end,
            function(v)
                local d = ns.GetDB(); if not (d and d.units and d.units[key]) then return end
                d.units[key].hideWhenMounted = v
                if ns.RefreshUnit then ns.RefreshUnit(key) end
            end)
        y = y - 26
    end

    Header(p, "Quest tracker auto-hide", 380, -56, 336)
    y = -80
    for _, row in ipairs(TRACKER_AUTOHIDE_ROWS) do
        local key = row[2]
        Toggle(p, row[1] .. (row[3] and REC or ""), 380, y,
            function() local d = ns.GetDB(); return d and d.tracker and d.tracker[key] end,
            function(v)
                local d = ns.GetDB(); if not (d and d.tracker) then return end
                d.tracker[key] = v
            end)
        y = y - 26
    end

    -- Cierre visual (2026-07-16, misma prolijidad que las paginas 1/3/6): las 2 columnas terminan
    -- a distinta altura, dejaba un vacio irregular abajo.
    local div = p:CreateTexture(nil, "ARTWORK")
    div:SetTexture(ART.DIVIDER)
    div:SetSize(CONTENT_W, 16)
    div:SetPoint("TOPLEFT", 0, -226)
    div:SetVertexColor(COLOR_LINE[1], COLOR_LINE[2], COLOR_LINE[3])
    Paragraph(p, 0, -242, 11,
        "\"(recommended)\" items are pre-checked; the rest are up to you. All of this stays " ..
        "editable per-unit later from the main options panel.")
    return p
end

-- ---------------- Pagina 5: Explorer Mode (mismas opciones que el menu) ----------------
local EXPLORER_LIST = {
    { "Player unit frame", "player", true }, { "Player portrait", "portrait_player" },
    { "Micro menu", "micromenu", true }, { "Info bar", "infobar" }, { "Pet unit frame", "pet", true },
    { "Target unit frame", "target" }, { "Target portrait", "portrait_target" },
    { "Player auras", "aura_player" }, { "Pet portrait", "portrait_pet", true }, { "Focus unit frame", "focus", true },
}
local EXPLORER_ZONES = {
    { "Open world", "world", true }, { "Dungeons", "dungeon" }, { "Raids", "raid" },
    { "Arenas", "arena" }, { "Battlegrounds", "battleground" }, { "Scenarios / Delves", "scenario" },
}
local function BuildPage5(content)
    local p = CreateFrame("Frame", nil, content)
    p:SetAllPoints()
    Header(p, "Explorer Mode", 0, -2)
    Paragraph(p, 4, -26, 11,
        "Enabled elements fade out and reappear on mouseover (even while hidden). Combat/target/casting can force them visible.")

    -- Fuerza el estado recomendado al construir (ver comentario igual en BuildPage3): master
    -- OFF, solo los 5 elementos marcados ON, los 3 "always show" ON, solo "Open world" ON.
    do
        local d = ns.GetDB()
        if d then
            d.explorerEnabled = false
            d.explorer = d.explorer or {}
            for _, e in ipairs(EXPLORER_LIST) do d.explorer[e[2]] = e[3] or nil end
            d.explorerCombat = true
            d.explorerTarget = true
            d.explorerCasting = true
            d.explorerZones = d.explorerZones or {}
            for _, z in ipairs(EXPLORER_ZONES) do d.explorerZones[z[2]] = z[3] and true or false end
        end
    end

    Toggle(p, "Enable Explorer (master switch)", 4, -56,
        function() local d = ns.GetDB(); return d and d.explorerEnabled ~= false end,
        function(v)
            local d = ns.GetDB(); if not d then return end
            d.explorerEnabled = v and true or false
            if not v and ns.ExplorerResetAll then ns.ExplorerResetAll() end
        end)

    local L, R = 4, 380
    for i, e in ipairs(EXPLORER_LIST) do
        local col = (i <= 5) and L or R
        local yy = -86 - ((i - 1) % 5) * 26
        local key = e[2]
        Toggle(p, e[1] .. (e[3] and REC or ""), col, yy,
            function() local d = ns.GetDB(); return d and d.explorer and d.explorer[key] end,
            function(v)
                local d = ns.GetDB(); if not (d and d.explorer) then return end
                d.explorer[key] = v or nil
                if not v and ns.ExplorerReset then ns.ExplorerReset(key) end
            end)
    end

    Header(p, "Always show", L, -226, 340)
    Toggle(p, "Always show in combat" .. REC, L, -250,
        function() local d = ns.GetDB(); return d and d.explorerCombat end,
        function(v) local d = ns.GetDB(); if d then d.explorerCombat = v end end)
    Toggle(p, "Always show on target" .. REC, L, -276,
        function() local d = ns.GetDB(); return d and d.explorerTarget end,
        function(v) local d = ns.GetDB(); if d then d.explorerTarget = v end end)
    Toggle(p, "Always show while casting" .. REC, L, -302,
        function() local d = ns.GetDB(); return d and d.explorerCasting end,
        function(v) local d = ns.GetDB(); if d then d.explorerCasting = v end end)

    Header(p, "Active in", R, -226, 336)
    for i, z in ipairs(EXPLORER_ZONES) do
        local zk = z[2]
        Toggle(p, z[1] .. (z[3] and REC or ""), R, -250 - (i - 1) * 26,
            function() local d = ns.GetDB(); return d and d.explorerZones and d.explorerZones[zk] ~= false end,
            function(v)
                local d = ns.GetDB(); if not (d and d.explorerZones) then return end
                d.explorerZones[zk] = v and true or false
                if not v and ns.ExplorerResetAll then ns.ExplorerResetAll() end
            end)
    end
    return p
end

-- ---------------- Pagina 6: aplicar el preset (+ HUD de Edit Mode, MANUAL) ----------------
-- 2026-07-15: el HUD de Blizzard Edit Mode YA NO se auto-importa (antes disparaba SIEMPRE un
-- LUA_WARNING ruidoso al crear el layout, ver ProfilesApply.lua comentario de cabecera) — ahora
-- "Apply now" solo reemplaza el SavedVariables de los addons tildados; el HUD se muestra como
-- codigo copiable (boton propio) para que el usuario lo importe A MANO desde el Edit Mode nativo
-- de Blizzard, sin pasar por codigo tainted por MyCustomFrames.
local function BuildPage6(content)
    local p = CreateFrame("Frame", nil, content)
    p:SetAllPoints()
    Header(p, "Apply the Gonkast preset", 0, -2)
    Paragraph(p, 4, -30, 12,
        "This REPLACES the SavedVariables of the addons you kept ticked on the previous page " ..
        "with the bundled Gonkast profile (Bartender4 bars, DynamicCam, Masque skin, " ..
        "Chattynator chat). A manual /reload is required afterwards. Only one profile is bundled per " ..
        "addon (\"Default\" for Bartender4/DynamicCam) — that's the recommended one, applied automatically.")

    -- Boton propio del usuario (Apply_Button.tga): la accion principal de la pagina. Separado un
    -- poco mas del parrafo de arriba (2026-07-16, pedido del usuario: se veian pegados).
    local applyBtn = TexButton(p, CUSTOM.APPLY, 200, 40, "Apply now", 14)
    applyBtn:SetPoint("TOPLEFT", 2, -100)
    AttentionGlow(applyBtn)

    local hudBtn = TexButton(p, CUSTOM.NAVBTN, 180, 40, "Edit Mode Code", 14)
    hudBtn:SetPoint("LEFT", applyBtn, "RIGHT", 14, 0)
    hudBtn:SetScript("OnClick", function() ns.ShowBlizzardHUDCode() end)
    Paragraph(p, 4, -150, 10,
        "The HUD layout (\"Gonkast Preset\", Bartender4/portrait positions etc) is a separate, MANUAL " ..
        "step: the button above shows a copyable code — paste it yourself via Esc > Edit Mode > Import " ..
        "Layout. Doing it by hand avoids a harmless-but-noisy taint warning that an automatic import " ..
        "always triggered. Also reachable any time later with |cffffff00/mcfhud|r.")

    local resultFs = p:CreateFontString(nil, "ARTWORK")
    SF(resultFs, 11)
    resultFs:SetPoint("TOPLEFT", 4, -194)
    resultFs:SetWidth(CONTENT_W); resultFs:SetJustifyH("LEFT"); resultFs:SetWordWrap(true)
    resultFs:SetTextColor(0.6, 0.9, 0.6)

    applyBtn:SetScript("OnClick", function()
        local applied = ns.ApplyProfilesFiltered(selected)
        local names = {}
        for a in pairs(applied) do names[#names + 1] = (ns.ProfilesInfo and ns.ProfilesInfo[a]) or a end

        -- Masque: el skin "Azerite HEX" vive DENTRO de MyCustomFrames (MasqueSkin.lua), registrado
        -- en Masque desde que este addon cargo (file-load, ver MasqueSkin.lua). Masque NO expone
        -- una API para re-skinear en caliente los grupos de OTRO addon (ni para enumerarlos), asi
        -- que solo confirmamos que el registro esta hecho — el skin ya deberia estar disponible en
        -- el panel de Masque y aplicarse solo a las barras cuya config (recien copiada de MasqueDB)
        -- ya lo tenia seleccionado, tras el /reload.
        local masqueOk, masqueInfo
        if applied.Masque then
            masqueOk, masqueInfo = ns.ApplyMasqueSkinAll and ns.ApplyMasqueSkinAll()
        end

        local msg
        if #names == 0 then
            msg = "Nothing selected to apply."
        else
            msg = "Applied: " .. table.concat(names, ", ")
            if applied.Masque then
                if masqueOk then
                    msg = msg .. "\n\"Azerite HEX\" skin is registered — select it in Masque's panel " ..
                        "if a bar doesn't switch automatically after /reload."
                else
                    msg = msg .. "\n|cffff5555Masque skin not registered:|r " .. tostring(masqueInfo)
                end
            end
            msg = msg .. "\nType /reload now."
        end
        resultFs:SetText(msg)
    end)
    return p
end

-- ---------------- Pagina 7: perfil de Bartender4 (el unico que a veces no persiste tras /reload) ----------------
-- Bartender4 es AceDB (multi-perfil): tras el Apply de la pagina anterior, un personaje sin
-- entrada propia en profileKeys DEBERIA caer solo en "Default" (fallback estandar de AceDB),
-- pero en la practica a veces no ocurre. Esto fuerza la asociacion profileKeys[personaje] =
-- perfil elegido DIRECTAMENTE, sin depender de ese fallback.
local selectedBTProfile = "Default"
local function GetBartenderProfiles()
    local list = {}
    local src = ns.Profiles and ns.Profiles["Bartender4DB"]
    if src and type(src.profiles) == "table" then
        for name in pairs(src.profiles) do list[#list + 1] = name end
        table.sort(list)
    end
    if #list == 0 then list[1] = "Default" end
    return list
end

local function BuildPage7(content)
    local p = CreateFrame("Frame", nil, content)
    p:SetAllPoints()
    Header(p, "Bartender4 profile", 0, -2)
    Paragraph(p, 4, -26, 12,
        "Bartender4 is the one addon that sometimes keeps using its own profile even after a /reload. " ..
        "Pick a profile below and click Apply to force it for THIS character specifically.")

    -- Pedido del usuario 2026-07-20: "que señale que deberia activar todo" -- esta pagina se
    -- construye UNA sola vez por apertura del wizard (ver contentPages[7] = BuildPage7(content)
    -- en BuildFrame), asi que esto prende los 2 toggles de abajo por default al abrir el wizard
    -- en vez de dejarlos apagados esperando que el usuario los note. Solo un empujon inicial:
    -- el usuario los puede apagar de nuevo libremente despues, esto no se vuelve a forzar.
    do
        local d = ns.GetDB()
        if d then
            if d.bartenderAutoProfile == nil then d.bartenderAutoProfile = selectedBTProfile end
            d.barReposition = true
            if ns.RefreshBarReposition then ns.RefreshBarReposition() end
        end
    end

    local dropBtn = DropdownButton(p, 240, 26, selectedBTProfile, 12)
    dropBtn:SetPoint("TOPLEFT", 4, -76)

    local listFrame = CreateFrame("Frame", nil, p)
    listFrame:SetFrameLevel(dropBtn:GetFrameLevel() + 5)
    listFrame:SetPoint("TOPLEFT", dropBtn, "BOTTOMLEFT", 0, -2)
    listFrame:Hide()
    local rows = {}
    local function RebuildList()
        for _, r in ipairs(rows) do r:Hide() end
        wipe(rows)
        local profiles = GetBartenderProfiles()
        local yy = 0
        for _, name in ipairs(profiles) do
            local rb = DropdownButton(listFrame, 240, 24, name, 12)
            rb:SetPoint("TOPLEFT", 0, yy)
            rb:SetScript("OnClick", function()
                selectedBTProfile = name
                dropBtn.text:SetText(name)
                listFrame:Hide()
            end)
            rows[#rows + 1] = rb
            yy = yy - 28
        end
        listFrame:SetSize(240, math.max(#profiles * 28, 4))
    end
    dropBtn:SetScript("OnClick", function()
        if listFrame:IsShown() then listFrame:Hide() else RebuildList(); listFrame:Show() end
    end)

    -- 2026-07-16: "usar este perfil para cualquier personaje NUEVO de la cuenta" — distinto del
    -- boton de abajo (que solo fuerza ESTE personaje). Guardado en db.bartenderAutoProfile;
    -- ns.ApplyBartenderAutoProfile (ProfilesApply.lua) lo aplica en cada login via la API viva de
    -- AceDB (Bartender4.db:SetProfile), sin depender del orden de carga entre addons.
    -- Posicion FIJA a -122 (2026-07-16, fix de prolijidad): la version original lo puso a -240,
    -- una posicion que en la practica caia ENCIMA/pegado del boton Apply y el texto de resultado
    -- de abajo (que estaban mas arriba, a -136/-186) — se reordeno todo en una columna logica:
    -- dropdown -> checkbox "any new char" -> boton Apply -> resultado.
    local autoCB = Toggle(p, "Also use this profile for any NEW character on this account",
        4, -122,
        function() local d = ns.GetDB(); return d and d.bartenderAutoProfile == selectedBTProfile and d.bartenderAutoProfile ~= nil end,
        function(v)
            local d = ns.GetDB(); if not d then return end
            d.bartenderAutoProfile = v and selectedBTProfile or nil
        end)

    -- 2026-07-16: mueve la barra possess/vehicle de Bartender4 (BT4Bar5) a una posicion
    -- fija mientras el jugador esta MONTADO (ver BarReposition.lua). Guardado en
    -- db.barReposition, mismo toggle que en Options.lua (Editing tab) — solo se agrega
    -- aca tambien para que quede visible durante el setup inicial.
    local barRepoCB = Toggle(p, "Move Bartender possess bar while mounted", 4, -146,
        function() local d = ns.GetDB(); return d and d.barReposition end,
        function(v)
            local d = ns.GetDB(); if not d then return end
            d.barReposition = v
            if ns.RefreshBarReposition then ns.RefreshBarReposition() end
        end)

    local applyBtn = TexButton(p, CUSTOM.APPLY, 240, 40, "Apply to this character", 13)
    applyBtn:SetPoint("TOPLEFT", 2, -184)
    AttentionGlow(applyBtn)

    local resultFs = p:CreateFontString(nil, "ARTWORK")
    SF(resultFs, 11)
    resultFs:SetPoint("TOPLEFT", applyBtn, "BOTTOMLEFT", 0, -12)
    resultFs:SetWidth(CONTENT_W); resultFs:SetJustifyH("LEFT"); resultFs:SetWordWrap(true)
    resultFs:SetTextColor(0.6, 0.9, 0.6)

    applyBtn:SetScript("OnClick", function()
        local charKey = (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?")
        local bt = _G.Bartender4DB
        if type(bt) ~= "table" then
            resultFs:SetText("|cffff5555Bartender4DB not found — is Bartender4 loaded?|r")
            return
        end
        bt.profileKeys = bt.profileKeys or {}
        bt.profileKeys[charKey] = selectedBTProfile
        -- Si el toggle "any NEW character" esta marcado, actualizamos el nombre guardado por si
        -- el usuario cambio de dropdown despues de tildarlo (deben quedar sincronizados).
        local d = ns.GetDB()
        if d and d.bartenderAutoProfile then d.bartenderAutoProfile = selectedBTProfile end
        local msg = "Set \"" .. charKey .. "\" to use the \"" .. selectedBTProfile .. "\" profile.\nType /reload now."
        if d and d.bartenderAutoProfile then
            msg = msg .. "\nFuture new characters will also default to \"" .. selectedBTProfile .. "\" (no /reload needed for that part)."
        end
        resultFs:SetText(msg)
    end)
    return p
end

-- ---------------- Pagina 8: Nameplates (pedido del usuario 2026-07-19, "que salga esta
-- pestaña de nameplate para configurar el nameplate") ----------------
-- No duplica los controles finos (esos viven en el Nameplate Designer, /mcfnpdesigner) -- esta
-- pagina es solo el punto de entrada: encender el reskin, y un boton grande para abrir el
-- Designer directo desde el wizard, asi el usuario no tiene que buscarlo despues en el menu.
local function BuildPage8(content)
    local p = CreateFrame("Frame", nil, content)
    p:SetAllPoints()
    Header(p, "Nameplates", 0, -2)
    Paragraph(p, 4, -26, 12,
        "Reskins Blizzard's own nameplates (health/cast bar, name, target highlight, auras, " ..
        "elite/rare/boss icon, raid marks) to match this preset's look — the underlying frames " ..
        "and coloring logic stay 100% Blizzard's own, no oUF, no addon replacement.")

    local enableCB = Toggle(p, "Enable nameplate reskin", 4, -74,
        function() local d = ns.GetDB(); return d and d.nameplates and d.nameplates.enabled end,
        function(v)
            local d = ns.GetDB(); if not d then return end
            d.nameplates = d.nameplates or {}
            d.nameplates.enabled = v
            if ns.RefreshNameplateStyle then ns.RefreshNameplateStyle() end
        end)

    Paragraph(p, 4, -104, 11,
        "Position, size, colors, aura categories, classification/raid mark icons — everything " ..
        "is drag-and-scroll editable in the Nameplate Designer, a visual panel (not sliders/text " ..
        "fields). Open it now to set it up, or later anytime with |cffffff00/mcfnpdesigner|r.")

    local designBtn = TexButton(p, CUSTOM.APPLY, 220, 40, "Open Nameplate Designer", 14)
    designBtn:SetPoint("TOPLEFT", 2, -148)
    designBtn:SetScript("OnClick", function()
        -- Pedido del usuario 2026-07-19: abrir el Designer desde el Setup NO
        -- debe quedar superpuesto/detras del wizard -- corre el wizard a la
        -- izquierda y el Designer a la derecha (960+480 de ancho con margen
        -- entre los dos, ver numeros abajo) para poder previsualizar ambos
        -- a la vez.
        if frame then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", -380, 0)
        end
        if ns.ToggleNameplateDesigner then ns.ToggleNameplateDesigner() end
        local designer = _G["MyCF_NameplateDesigner"]
        if designer then
            designer:ClearAllPoints()
            designer:SetPoint("CENTER", UIParent, "CENTER", 380, 60)
        end
    end)

    Paragraph(p, 4, -204, 10,
        "Max render distance, non-target fade opacity, and colors also live in the full menu " ..
        "(|cffffff00/mcfmenu|r > NAMEPLATES) if you'd rather type exact numbers than drag.")
    return p
end

-- ---------------- Navegacion ----------------
function ns.SetupGoTo(page)
    if not frame then return end
    page = math.max(1, math.min(PAGE_COUNT, page))
    curPage = page
    for i, f in ipairs(contentPages) do
        if i == page then FadeIn(f) else f:Hide() end
    end
    for i, d in ipairs(pageDots) do
        d:SetTexture(i == page and CUSTOM.PAGE_CUR or CUSTOM.PAGE)
    end
    stepLabel:SetText("Step " .. page .. " of " .. PAGE_COUNT)
    backBtn:SetShown(page > 1)
    nextBtn.text:SetText(page < PAGE_COUNT and "Next >" or "Finish")
    if page == 2 then RefreshPage2(contentPages[2]) end
end

-- ReloadUI() es una funcion PROTEGIDA: Blizzard NO deja que ningun addon la llame, ni
-- diferida ni en pcall (confirmado en juego: ADDON_ACTION_BLOCKED), y da igual COMO se
-- invoque (RunSlashCmd/el comando de chat internamente terminan llamando a la MISMA funcion
-- protegida) — no hay boton posible que dispare el reload por si solo. Misma restriccion que
-- ya documenta DoApply en ProfilesApply.lua. Este popup es puramente informativo (un solo
-- boton que cierra), el jugador tiene que escribir /reload el mismo.
StaticPopupDialogs["MCF_SETUP_FINISH_RELOAD"] = {
    text = "Setup finished!\n\nType |cffffff00/reload|r in chat now to apply everything.",
    button1 = "Got it",
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function ns.SetupFinish()
    local db = ns.GetDB and ns.GetDB()
    if db then db.setupSeen = true end
    if frame then frame:Hide() end
    if StaticPopup_Show then StaticPopup_Show("MCF_SETUP_FINISH_RELOAD") end
end

function ns.CloseSetupWizard(markSeen)
    if markSeen then
        local db = ns.GetDB and ns.GetDB()
        if db then db.setupSeen = true end
    end
    if frame then frame:Hide() end
end

function ns.ShowSetupWizard()
    if not frame then
        local content = BuildFrame()
        contentPages[1] = BuildPage1(content)
        contentPages[2] = BuildPage2(content)
        contentPages[3] = BuildPage3(content)
        contentPages[4] = BuildPage4(content)
        contentPages[5] = BuildPage5(content)
        contentPages[6] = BuildPage6(content)
        contentPages[7] = BuildPage7(content)
        contentPages[8] = BuildPage8(content)
    end
    if UIFrameFadeIn then
        frame:Show(); frame:SetAlpha(0)
        UIFrameFadeIn(frame, 0.2, 0, 1)
    else
        frame:Show()
    end
    ns.SetupGoTo(1)
end

SLASH_MCFSETUP1 = "/mcfsetup"
SlashCmdList["MCFSETUP"] = function() ns.ShowSetupWizard() end

-- Disparo automatico: solo la PRIMERA vez (db.setupSeen == false). Se espera un poco
-- tras PLAYER_LOGIN para que el resto de addons (deteccion de perfiles) ya haya cargado.
local trigger = CreateFrame("Frame")
trigger:RegisterEvent("PLAYER_LOGIN")
trigger:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if C_Timer and C_Timer.After then
        C_Timer.After(1.5, function()
            local db = ns.GetDB and ns.GetDB()
            if db and not db.setupSeen then ns.ShowSetupWizard() end
        end)
    end
end)
