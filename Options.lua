-- ==========================================================================
-- MyCustomFrames - Options.lua
-- Menu de opciones con estilo inspirado en Plumber (fondo, divisores, fuente
-- Lato, botones custom) y organizado por secciones (pestanas).
-- ==========================================================================

local ADDON, ns = ...
local PL = ns.PL
local FONT = PL.FONT

local function setFont(fs, size, flags)
    if not fs:SetFont(FONT, size, flags or "") then fs:SetFontObject("GameFontNormal") end
end

-- ==========================================================================
-- Ocultar la textura NATIVA del EditBox de chat (el borde/fondo ornamentado
-- de Blizzard donde escribis) -- pedido del usuario 2026-07-19: "eso es de
-- blizzard, se puede ocultar, azeriteui lo hace". No depende de AzeriteUI:
-- oculta TODAS las Texture (no FontString) del EditBox -- el borde/fondo son
-- texturas, el texto que escribis es un FontString aparte, no se toca.
-- Cubre ChatFrame1..N (dock general) + hookea FCF_OpenTemporaryWindow para
-- las ventanas temporales (susurros) que Blizzard crea sobre la marcha.
-- ==========================================================================
local function SetChatEditBoxTexture(eb, hide)
    if not eb then return end
    local ok, regions = pcall(function() return { eb:GetRegions() } end)
    if not ok then return end
    for _, r in ipairs(regions) do
        if r.GetObjectType and r:GetObjectType() == "Texture" then
            pcall(r.SetAlpha, r, hide and 0 or 1)
        end
    end
    if eb.NineSlice then eb.NineSlice:SetShown(not hide) end
end
local function RefreshChatEditBoxSkin()
    local hide = ns.GetDB and ns.GetDB() and ns.GetDB().hideChatEditBoxTexture
    for i = 1, (NUM_CHAT_WINDOWS or 10) + 10 do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb then SetChatEditBoxTexture(eb, hide) end
    end
end
ns.RefreshChatEditBoxSkin = RefreshChatEditBoxSkin
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function()
        RefreshChatEditBoxSkin()
        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            C_Timer.After(0, RefreshChatEditBoxSkin)
        end)
    end)
end

local getP = function() return ns.CurrentProfile() end
local OnEdit = function() ns.ApplyCurrent() end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local refreshers = {}
local function RefreshControls() for _, f in ipairs(refreshers) do f() end end
ns.OnProfilePasted = RefreshControls
ns.OnDragStopped = function(k) if k == ns.currentEdit then RefreshControls() end end
ns.OnScaleWheel = RefreshControls   -- la rueda en modo Lock cambio una escala: refresca sliders

-- Paleta LITERAL de Plumber (2026-07-16, extraida directo de su Def table en
-- Modules/ControlCenter/SettingsPanelNew.lua:15-38 — reemplaza los valores mas
-- oscuros/apagados que tenia el panel antes, que eran una aproximacion a mano).
-- 2026-07-17 (ronda 4): el dorado-ambar vivo de la ronda 3 se probo en TODO
-- el panel (headers, botones, etc) y resulto DEMASIADO — al usuario le gusto
-- especificamente en los headers de GRUPO de la sidebar (MAIN/POWER/BOSSES/...)
-- nada mas. Esos ahora usan su PROPIA constante (COLOR_GROUP); todo lo demas
-- que usaba COLOR_TITLE/COLOR_OPTION vuelve a los valores de la ronda 2.
local COLOR_TITLE  = { 215 / 255, 192 / 255, 163 / 255 }   -- Def.TextColorNormal (dorado-tostado)
local COLOR_DESC   = { 163 / 255, 157 / 255, 147 / 255 }   -- Def.TextColorReadable
local COLOR_LINE   = { 148 / 255, 124 / 255, 102 / 255 }   -- Def.TextColorNonInteractable
local COLOR_OPTION = { 226 / 255, 216 / 255, 199 / 255 }   -- casi blanco calido, mas legible/neutro que TITLE
local COLOR_HIGHLIGHT = { 1, 1, 1 }                        -- Def.TextColorHighlight (hover/seleccionado)
local COLOR_GROUP  = { 235 / 255, 175 / 255, 90 / 255 }    -- dorado-ambar vivo, SOLO headers de grupo (sidebar)

-- ==========================================================================
-- WIDGETS ESTILO PLUMBER (usan los assets reales de Plumber\Art)
-- ==========================================================================
local WIDGET = "Interface\\AddOns\\MyCustomFrames\\Assets\\SettingsPanelWidget.png"
local TOGGLE = "Interface\\AddOns\\MyCustomFrames\\Assets\\OptionToggle"
-- Atlas 1024x1024 copiado DIRECTO del Plumber real (Modules/ControlCenter/SettingsPanelNew.lua,
-- Def.TextureFile) — usado SOLO para el buscador (pildora con borde limpio + lupa), que el
-- usuario pidio explicitamente igualar (2026-07-15). Coords tomadas 1:1 del código fuente de
-- Plumber (SetTexCoord ahi divide todo por 1024, mismo atlas cuadrado).
local PLB = "Interface\\AddOns\\MyCustomFrames\\Assets\\PlumberSettingsPanel.png"

-- Fondo 3-slice del atlas de Plumber (cap izq/der + centro estirado).
local function ThreeSlice(frame, capW)
    local left = frame:CreateTexture(nil, "BACKGROUND")
    left:SetTexture(WIDGET)
    left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(capW)
    left:SetTexCoord(36 / 512, 68 / 512, 0, 80 / 512)
    local right = frame:CreateTexture(nil, "BACKGROUND")
    right:SetTexture(WIDGET)
    right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT"); right:SetWidth(capW)
    right:SetTexCoord(132 / 512, 164 / 512, 0, 80 / 512)
    local mid = frame:CreateTexture(nil, "BACKGROUND")
    mid:SetTexture(WIDGET)
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT"); mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    mid:SetTexCoord(68 / 512, 132 / 512, 0, 80 / 512)
    return { left, mid, right }
end

local function StyleButton(b, w, h)
    b:SetSize(w, h)
    local parts = ThreeSlice(b, 14)
    b.bgparts = parts

    -- Highlight en capa ARTWORK (debajo del texto OVERLAY) con blend aditivo,
    -- para que el glow NO tape el texto. Se muestra con hover.
    local hl = b:CreateTexture(nil, "ARTWORK")
    hl:SetTexture(WIDGET)
    hl:SetTexCoord(168 / 512, 296 / 512, 0, 80 / 512)
    hl:SetPoint("TOPLEFT", -6, 3); hl:SetPoint("BOTTOMRIGHT", 6, -3)
    hl:SetBlendMode("ADD")
    hl:SetAlpha(0.5)
    hl:Hide()
    b:SetScript("OnEnter", function() hl:Show() end)
    b:SetScript("OnLeave", function() hl:Hide() end)

    local txt = b:CreateFontString(nil, "OVERLAY")
    setFont(txt, 12)
    txt:SetPoint("CENTER")
    b.text = txt

    function b:SetActive(on)
        if on then
            for _, t in ipairs(parts) do t:SetVertexColor(1.0, 0.82, 0.35) end
            txt:SetTextColor(1, 1, 1)          -- blanco: se lee sobre el boton oscuro
        else
            -- 2026-07-17: tinte tostado en vez de blanco puro (el WIDGET.png es gris
            -- piedra plano al pasarlo sin tenir; con blanco se veia gris/plano y
            -- desentonaba con la paleta dorada del resto del panel).
            for _, t in ipairs(parts) do t:SetVertexColor(0.62, 0.52, 0.40) end
            txt:SetTextColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
        end
    end
    b:SetActive(false)
    return b
end

local function MakeButton(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent)
    StyleButton(b, w or 100, h or 22)
    b.text:SetText(text)
    b._label = text
    return b
end
-- Expuesto para NameplateDesigner.lua (pedido del usuario: "sigue el
-- formato de diseño de mi menu") -- carga DESPUES en el .toc, pero esto se
-- llama recien en runtime (CreateDesigner, mucho despues de que TODOS los
-- archivos ya corrieron), asi que el orden de carga no importa aca.
ns.MakeButton = MakeButton

-- Tab "pildora" 3-slice de Plumber (PlumberTabButtonTemplate, ver
-- SettingsPanelNew.lua:1997-2013 y TabButtonMixin:UpdateVisual:1965-1981) — usado
-- SOLO para la fila superior (Close/Profile/Explorer/Editing/Setup), que hace de
-- "TabButtonContainer" de Plumber. Mismas coordenadas exactas de su atlas.
local TAB_UNSEL = { left = { 392, 440 }, center = { 440, 552 }, right = { 552, 600 }, y = { 176, 272 } }
local TAB_SEL   = { left = { 600, 648 }, center = { 648, 760 }, right = { 760, 808 }, y = { 176, 272 } }
-- flipY (2026-07-17): voltea verticalmente la textura de la pildora (la parte
-- "plana" queda abajo en vez de arriba) — pedido puntual para Copy/Paste, sin
-- afectar al resto de los botones que usan esta misma factory.
local function MakeTabButton(parent, text, w, h, flipY)
    w = w or 90
    h = h or 32
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)

    local function tex(coords)
        local t = b:CreateTexture(nil, "BACKGROUND")
        t:SetTexture(PLB)
        local y1, y2 = TAB_UNSEL.y[1], TAB_UNSEL.y[2]
        if flipY then y1, y2 = y2, y1 end
        t:SetTexCoord(coords[1] / 1024, coords[2] / 1024, y1 / 1024, y2 / 1024)
        return t
    end
    local capW = (h < 26) and 14 or 24
    local left = tex(TAB_UNSEL.left); left:SetSize(capW, h); left:SetPoint("LEFT")
    local right = tex(TAB_UNSEL.right); right:SetSize(capW, h); right:SetPoint("RIGHT")
    local center = tex(TAB_UNSEL.center)
    center:SetPoint("TOPLEFT", left, "TOPRIGHT"); center:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    b._tex = { left = left, center = center, right = right }

    local txt = b:CreateFontString(nil, "OVERLAY")
    setFont(txt, (h < 26) and 10 or 12)
    txt:SetPoint("CENTER")
    txt:SetTextColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
    b.text = txt
    b._label = text
    txt:SetText(text)

    -- 2026-07-17: auto-ancho — labels largos (Border/Death/Mark/Role) se salian
    -- de la pildora porque el ancho quedaba fijo en el valor pedido por el
    -- caller sin importar cuanto media el texto. Si el texto necesita mas
    -- espacio que `w`, se agranda el boton (los caps quedan igual, solo el
    -- centro se estira, ya que esta anclado por relacion a left/right).
    local needed = txt:GetStringWidth() + capW * 2 + 12
    if needed > w then b:SetWidth(needed) end

    local function applyCoords(set)
        local y1, y2 = set.y[1], set.y[2]
        if flipY then y1, y2 = y2, y1 end
        left:SetTexCoord(set.left[1] / 1024, set.left[2] / 1024, y1 / 1024, y2 / 1024)
        center:SetTexCoord(set.center[1] / 1024, set.center[2] / 1024, y1 / 1024, y2 / 1024)
        right:SetTexCoord(set.right[1] / 1024, set.right[2] / 1024, y1 / 1024, y2 / 1024)
    end
    function b:SetActive(on)
        b._active = on
        applyCoords(on and TAB_SEL or TAB_UNSEL)
        txt:SetTextColor(on and 1 or COLOR_TITLE[1], on and 1 or COLOR_TITLE[2], on and 1 or COLOR_TITLE[3])
    end
    b:SetScript("OnEnter", function() if not b._active then txt:SetTextColor(1, 1, 1) end end)
    b:SetScript("OnLeave", function() if not b._active then txt:SetTextColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3]) end end)
    return b
end

-- Item de lista SIN chrome de boton por defecto (estilo sidebar real de Plumber:
-- las categorias son texto plano, solo se ve una caja al pasar el mouse o al
-- estar seleccionada). 2026-07-17: la version anterior dibujaba un rectangulo de
-- esquinas duras y borde muy marcado (el usuario lo comparo contra Plumber, que
-- usa una pildora suave de esquinas redondeadas) — se reemplaza por la MISMA
-- pildora 3-slice del atlas PLB que ya usa el buscador, tenida mas tenue.
-- `prominent` (2026-07-17): usado por los 4 items globales Setup/Editing/Explorer/
-- Profile — el usuario noto que se confundian visualmente con la lista de unidades
-- de abajo (mismo tamaño/color, parecia que "Setup" era otro elemento mas de las
-- unitframes). Con prominent=true: fuente mas grande, tinte SIEMPRE visible (no
-- solo en hover/seleccion) y color mas brillante en reposo.
local function MakeListItem(parent, text, w, h, prominent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 104, h or 18)

    local function pillPiece(x1, x2)
        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetTexture(PLB)
        t:SetTexCoord(x1 / 1024, x2 / 1024, 0 / 1024, 80 / 1024)
        return t
    end
    local pLeft = pillPiece(0, 32); pLeft:SetSize(10, (h or 18) + 4); pLeft:SetPoint("LEFT", -2, 0)
    local pRight = pillPiece(160, 192); pRight:SetSize(10, (h or 18) + 4); pRight:SetPoint("RIGHT", 2, 0)
    local pMid = pillPiece(32, 160)
    pMid:SetPoint("TOPLEFT", pLeft, "TOPRIGHT"); pMid:SetPoint("BOTTOMRIGHT", pRight, "BOTTOMLEFT")
    local pill = { pLeft, pMid, pRight }
    local idleAlpha = prominent and 0.30 or 0
    for _, t in ipairs(pill) do t:SetAlpha(idleAlpha); t:SetVertexColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3]) end
    if not prominent then for _, t in ipairs(pill) do t:Hide() end end

    local idleColor = prominent and COLOR_TITLE or COLOR_OPTION
    local txt = b:CreateFontString(nil, "OVERLAY")
    setFont(txt, prominent and 13 or 11)
    txt:SetPoint("LEFT", 6, 0)
    txt:SetTextColor(idleColor[1], idleColor[2], idleColor[3])
    txt:SetText(text)
    b.text = txt
    b._label = text

    -- 2026-07-17: fade suave en vez de Show/Hide instantaneo al seleccionar/pasar
    -- el mouse (UIFrameFadeIn/Out son las utilidades estandar de Blizzard, animan
    -- alpha solas via su propio OnUpdate compartido).
    for _, t in ipairs(pill) do t:SetVertexColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3]) end
    local function fadePillTo(a, duration)
        for _, t in ipairs(pill) do
            if UIFrameFadeIn then
                if not t:IsShown() then t:SetAlpha(0) end
                t:Show()
                UIFrameFadeIn(t, duration or 0.12, t:GetAlpha(), a)
            else
                t:SetAlpha(a); t:Show()
            end
        end
    end
    function b:SetActive(on)
        b._active = on
        if on then
            fadePillTo(0.85)
        elseif prominent then
            fadePillTo(idleAlpha)
        else
            fadePillTo(0, 0.15)
        end
        txt:SetTextColor(on and 1 or idleColor[1], on and 1 or idleColor[2], on and 1 or idleColor[3])
    end
    b:SetScript("OnEnter", function()
        if not b._active then fadePillTo(0.35); txt:SetTextColor(1, 1, 1) end
    end)
    b:SetScript("OnLeave", function()
        if not b._active then
            fadePillTo(prominent and idleAlpha or 0, 0.15)
            txt:SetTextColor(idleColor[1], idleColor[2], idleColor[3])
        end
    end)
    return b
end

local function MakeHeader(parent, text, x, y, width)
    -- Diamante (2026-07-17): rombo de textura solida rotada 45 grados en vez de un
    -- glyph de fuente (evita tofu si la fuente no tiene el caracter), calcando el
    -- iconito que Plumber pone a la izquierda de cada header de seccion.
    -- BUG (2026-07-17): "LEFT" ancla al CENTRO VERTICAL del padre, no al top —
    -- con Section frames de ~330px de alto, el rombo terminaba ~165px mas abajo
    -- del titulo real (el usuario lo vio flotando cerca de una fila de checkbox
    -- muy por debajo del header). Debe ser TOPLEFT, igual que el texto/divisor.
    local fs = parent:CreateFontString(nil, "ARTWORK")
    setFont(fs, 14)
    fs:SetPoint("TOPLEFT", x + 12, y)
    fs:SetTextColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
    fs:SetText(text)

    -- 2026-07-17 (ronda 2): quedaba unos px mas abajo que el centro visual del
    -- texto. Anclado al CENTRO VERTICAL de `fs` (que ya sabe su propio alto real
    -- via GetHeight) en vez de un offset fijo a ojo relativo a `y`.
    local diamond = parent:CreateTexture(nil, "ARTWORK")
    diamond:SetColorTexture(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
    diamond:SetSize(6, 6)
    diamond:SetRotation(math.rad(45))
    diamond:SetPoint("CENTER", fs, "LEFT", -6, 0)
    local div = parent:CreateTexture(nil, "ARTWORK")
    div:SetTexture(PL.DIV_H)
    div:SetSize((width or 250) - 12, 8)
    div:SetPoint("TOPLEFT", x + 12, y - 16)
    div:SetVertexColor(COLOR_LINE[1], COLOR_LINE[2], COLOR_LINE[3], 0.4)
    fs.div = div   -- expuesto para que otros archivos (p.ej. Setup.lua) puedan re-tenirlo
    fs.diamond = diamond
    return fs
end

-- Lista de bullets (2026-07-17): parrafos largos como texto plano se leen como
-- una pared de texto (el usuario lo noto en la seccion Setup). Mismo estilo que
-- el panel de preview: cuadradito + linea, con el ALTO calculado dinamicamente
-- via GetStringHeight() en vez de offsets fijos adivinados a mano (eso era lo
-- que dejaba todo apretado/desalineado). Devuelve el Y final para encadenar.
local function MakeBulletList(parent, lines, x, y, width)
    local cy = y
    for _, line in ipairs(lines) do
        local dot = parent:CreateTexture(nil, "ARTWORK")
        dot:SetColorTexture(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
        dot:SetSize(5, 5)
        dot:SetPoint("TOPLEFT", x + 3, cy - 6)
        local fs = parent:CreateFontString(nil, "ARTWORK")
        setFont(fs, 11)
        fs:SetPoint("TOPLEFT", x + 14, cy)
        fs:SetWidth(width - 14)
        fs:SetJustifyH("LEFT"); fs:SetWordWrap(true)
        fs:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        fs:SetText(line)
        cy = cy - (fs:GetStringHeight() or 14) - 10
    end
    return cy
end

-- Checkbox: recuadro + check clasicos de Blizzard (cargan SIEMPRE, los usa Ace3), con el
-- check y el texto en la paleta de Plumber + highlight de fila en hover. (El asset .png de
-- Plumber no mostraba la region del checkbox de forma fiable; estos paths son a prueba de balas.)
local function MakeToggle(parent, label, x, y, getf, setf)
    local cb = CreateFrame("Button", nil, parent)
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetSize(210, 24)
    -- Highlight de fila (sutil tinte) al pasar el mouse.
    local hl = cb:CreateTexture(nil, "BACKGROUND")
    hl:SetColorTexture(COLOR_LINE[1], COLOR_LINE[2], COLOR_LINE[3], 0.09)
    hl:SetPoint("TOPLEFT", -4, 1); hl:SetPoint("BOTTOMRIGHT", 4, -1)
    hl:Hide()
    -- Recuadro (siempre) + check (solo si activo).
    local box = cb:CreateTexture(nil, "ARTWORK")
    box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
    box:SetSize(24, 24)
    box:SetPoint("LEFT", 0, 0)
    local check = cb:CreateTexture(nil, "OVERLAY")
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:SetSize(24, 24)
    check:SetPoint("LEFT", 0, 0)
    check:SetVertexColor(COLOR_OPTION[1], COLOR_OPTION[2], COLOR_OPTION[3])
    local lbl = cb:CreateFontString(nil, "ARTWORK")
    setFont(lbl, 12)
    lbl:SetPoint("LEFT", box, "RIGHT", 3, 0)
    lbl:SetTextColor(COLOR_OPTION[1], COLOR_OPTION[2], COLOR_OPTION[3])
    lbl:SetText(label)
    cb.label = lbl   -- expuesto para que otros archivos (p.ej. Setup.lua) puedan re-fontear
    cb.box, cb.check = box, check   -- idem: permite reskinear el checkbox (p.ej. Setup.lua)
    local function refresh() check:SetShown(getf() and true or false) end
    cb:SetScript("OnEnter", function() hl:Show(); lbl:SetTextColor(1, 1, 1) end)
    cb:SetScript("OnLeave", function() hl:Hide(); lbl:SetTextColor(COLOR_OPTION[1], COLOR_OPTION[2], COLOR_OPTION[3]) end)
    cb:SetScript("OnClick", function() setf(not (getf() and true or false)); refresh() end)
    cb.refresh = refresh
    refreshers[#refreshers + 1] = refresh
    return cb
end

local function MakeCheckbox(parent, label, dbKey, x, y)
    return MakeToggle(parent, label, x, y,
        function() return getP()[dbKey] end,
        function(v) getP()[dbKey] = v; OnEdit() end)
end

-- getTbl/onChange opcionales: por defecto usa el perfil actual + ApplyCurrent. Para valores
-- GLOBALES (p.ej. tamaño de grilla) pasar getTbl = function() return ns.GetDB() end.
local function MakeSlider(parent, label, minV, maxV, step, dbKey, x, y, getTbl, onChange)
    local get = getTbl or getP
    local edit = onChange or OnEdit
    local s = CreateFrame("Slider", nil, parent)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(200, 14)
    s:SetPoint("TOPLEFT", x, y)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)

    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3], 0.18)
    track:SetHeight(3)
    track:SetPoint("LEFT", 0, 0); track:SetPoint("RIGHT", 0, 0)

    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3], 0.95)
    thumb:SetSize(8, 16)
    s:SetThumbTexture(thumb)

    local lbl = s:CreateFontString(nil, "ARTWORK")
    setFont(lbl, 11)
    lbl:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 3)
    lbl:SetTextColor(COLOR_OPTION[1], COLOR_OPTION[2], COLOR_OPTION[3])

    local syncing = false
    local decimals = (step < 1) and 2 or 0
    local fmt = "%." .. decimals .. "f"
    local function roundStep(v) return math.floor(v / step + 0.5) * step end
    local function fmtVal(v) return string.format(fmt, v) end

    local plus = MakeButton(s, "+", 18, 16)
    plus:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT", 0, 2)
    local box = CreateFrame("EditBox", nil, s, "InputBoxTemplate")
    box:SetSize(44, 16)
    box:SetPoint("RIGHT", plus, "LEFT", -4, 0)
    box:SetAutoFocus(false); box:SetJustifyH("RIGHT")
    -- Reskin FLAT (2026-07-17): el InputBoxTemplate de Blizzard (bordes azules 3-slice)
    -- desentona con el resto del panel (oscuro/dorado, todo flat). Ocultamos el arte
    -- default y dibujamos fondo plano + 2 lineas finas (mismo lenguaje visual que
    -- COLOR_LINE ya usa en dividers/tracks). Cambio centralizado: afecta TODOS los
    -- sliders del menu de una sola vez.
    if box.Left then box.Left:SetAlpha(0) end
    if box.Middle then box.Middle:SetAlpha(0) end
    if box.Right then box.Right:SetAlpha(0) end
    local boxBg = box:CreateTexture(nil, "BACKGROUND", nil, -1)
    boxBg:SetColorTexture(0, 0, 0, 0.45)
    boxBg:SetPoint("TOPLEFT", -3, 1)
    boxBg:SetPoint("BOTTOMRIGHT", 3, -1)
    local boxTop = box:CreateTexture(nil, "BORDER")
    boxTop:SetColorTexture(COLOR_LINE[1], COLOR_LINE[2], COLOR_LINE[3], 0.5)
    boxTop:SetPoint("TOPLEFT", boxBg, "TOPLEFT", 0, 0)
    boxTop:SetPoint("TOPRIGHT", boxBg, "TOPRIGHT", 0, 0)
    boxTop:SetHeight(1)
    local boxBot = box:CreateTexture(nil, "BORDER")
    boxBot:SetColorTexture(COLOR_LINE[1], COLOR_LINE[2], COLOR_LINE[3], 0.5)
    boxBot:SetPoint("BOTTOMLEFT", boxBg, "BOTTOMLEFT", 0, 0)
    boxBot:SetPoint("BOTTOMRIGHT", boxBg, "BOTTOMRIGHT", 0, 0)
    boxBot:SetHeight(1)
    local minus = MakeButton(s, "-", 18, 16)
    minus:SetPoint("RIGHT", box, "LEFT", -2, 0)

    -- La etiqueta y la caja de valor comparten la fila de ARRIBA del slider. Sin acotarla, las
    -- etiquetas largas (p.ej. "Base opacity (hover/cond=100%)") se montan sobre el editbox/botones.
    -- Limitamos el ancho de la etiqueta al hueco libre a la izquierda de los controles de valor y
    -- desactivamos el wrap → se trunca en vez de colisionar. Arreglo GLOBAL para todos los sliders.
    lbl:SetWidth(128)
    lbl:SetWordWrap(false)

    local function setValue(v)
        v = clamp(roundStep(v), minV, maxV)
        get()[dbKey] = v
        syncing = true; s:SetValue(v); syncing = false
        box:SetText(fmtVal(v)); edit()
    end
    s:SetScript("OnValueChanged", function(self, value)
        value = roundStep(value)
        get()[dbKey] = value
        if not syncing then box:SetText(fmtVal(value)) end
        edit()
    end)
    plus:SetScript("OnClick",  function() setValue(get()[dbKey] + step) end)
    minus:SetScript("OnClick", function() setValue(get()[dbKey] - step) end)
    box:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if v then setValue(v) else self:SetText(fmtVal(get()[dbKey])) end
        self:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText(fmtVal(get()[dbKey])); self:ClearFocus()
        if ns.CloseMainPanel then ns.CloseMainPanel() end
    end)

    refreshers[#refreshers + 1] = function()
        local v = get()[dbKey]
        if v == nil then return end   -- clave ausente (p.ej. unidad vs portrait): no tocar
        lbl:SetText(label)
        syncing = true; s:SetValue(clamp(v, minV, maxV)); syncing = false
        box:SetText(fmtVal(v))
    end
    return s
end

local function MakeCycle(parent, label, values, dbKey, x, y)
    local btn = MakeButton(parent, "", 200, 22)
    btn:SetPoint("TOPLEFT", x, y)
    local function txt() btn.text:SetText(label .. ": " .. tostring(getP()[dbKey])) end
    btn:SetScript("OnClick", function()
        local cur, idx = getP()[dbKey], 1
        for i, v in ipairs(values) do if v == cur then idx = i break end end
        getP()[dbKey] = values[(idx % #values) + 1]
        txt(); OnEdit()
    end)
    refreshers[#refreshers + 1] = txt
    return btn
end

local function MakeEditBox(parent, label, dbKey, x, y, width)
    local lbl = parent:CreateFontString(nil, "ARTWORK")
    setFont(lbl, 11)
    lbl:SetPoint("TOPLEFT", x, y)
    lbl:SetTextColor(COLOR_OPTION[1], COLOR_OPTION[2], COLOR_OPTION[3])
    lbl:SetText(label)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(width or 200, 20)
    eb:SetPoint("TOPLEFT", x + 4, y - 15)
    eb:SetAutoFocus(false)
    eb:SetScript("OnEnterPressed", function(self) getP()[dbKey] = self:GetText(); self:ClearFocus(); OnEdit() end)
    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        if ns.CloseMainPanel then ns.CloseMainPanel() end
    end)
    refreshers[#refreshers + 1] = function() eb:SetText(getP()[dbKey] or "") end
    return eb
end

local function MakeColorButton(parent, label, dbKey, x, y)
    local btn = MakeButton(parent, label, 150, 22)
    btn:SetPoint("TOPLEFT", x, y)
    local sw = btn:CreateTexture(nil, "OVERLAY")
    sw:SetSize(14, 14); sw:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    local function refreshSw() local c = getP()[dbKey]; if c then sw:SetColorTexture(c.r, c.g, c.b) end end
    btn:SetScript("OnClick", function()
        local c = getP()[dbKey]
        local r, g, b = c.r, c.g, c.b
        local function apply()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            local cc = getP()[dbKey]; cc.r, cc.g, cc.b = nr, ng, nb
            refreshSw(); OnEdit()
        end
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b, hasOpacity = false, swatchFunc = apply,
            cancelFunc = function() local cc = getP()[dbKey]; cc.r, cc.g, cc.b = r, g, b; refreshSw(); OnEdit() end,
        })
    end)
    refreshers[#refreshers + 1] = refreshSw
    return btn
end

-- Boton de color para una tabla arbitraria (no ligado a getP; para opciones globales).
local function MakeGlobalColor(parent, label, getTbl, x, y, onChange)
    local btn = MakeButton(parent, label, 180, 22); btn:SetPoint("TOPLEFT", x, y)
    local sw = btn:CreateTexture(nil, "OVERLAY")
    sw:SetSize(14, 14); sw:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    local function refreshSw() local c = getTbl(); if c then sw:SetColorTexture(c.r, c.g, c.b) end end
    btn:SetScript("OnClick", function()
        local c = getTbl(); if not c then return end
        local r, g, b = c.r, c.g, c.b
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = function() local nr, ng, nb = ColorPickerFrame:GetColorRGB(); c.r, c.g, c.b = nr, ng, nb; refreshSw(); if onChange then onChange() end end,
            cancelFunc = function() c.r, c.g, c.b = r, g, b; refreshSw(); if onChange then onChange() end end,
        })
    end)
    refreshers[#refreshers + 1] = refreshSw
    return btn
end

-- ==========================================================================
-- SELECTOR DE TEXTURAS (browse + preview; libreria en ns.TEX_LIB / ns.TEX_SKINS)
-- ==========================================================================
local texPopup
local function GetTexPopup()
    if texPopup then return texPopup end
    local p = CreateFrame("Frame", "MyCF_TexPopup", UIParent)
    p:SetSize(252, 340)
    p:SetFrameStrata("FULLSCREEN_DIALOG")
    p:EnableMouse(true)
    p:Hide()
    -- Cerrable con ESC via UISpecialFrames (el intento de manejarlo a mano con
    -- OnKeyDown, 2026-07-18, resulto no disparar nunca -- ver nota igual en el
    -- panel principal). Ademas se cierra solo si el panel principal se oculta
    -- (ver el HookScript OnHide de `panel`, mas abajo en el archivo).
    tinsert(UISpecialFrames, "MyCF_TexPopup")
    local bg = p:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.04, 0.04, 0.05, 0.96)
    local ttl = p:CreateFontString(nil, "OVERLAY"); setFont(ttl, 13)
    ttl:SetPoint("TOPLEFT", 10, -8); ttl:SetTextColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3]); ttl:SetText("Choose texture")
    local close = MakeButton(p, "X", 22, 20); close:SetPoint("TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function() p:Hide() end)   -- cierra SIN aplicar (cancelar)
    -- Fila de botones fija abajo (Accept/Cancel): el click en una fila ya NO aplica
    -- directo, solo selecciona/marca; hace falta Accept para confirmar.
    local acceptBtn = MakeButton(p, "Accept", 106, 22)
    acceptBtn:SetPoint("BOTTOMLEFT", 8, 8)
    acceptBtn:SetScript("OnClick", function() if p.applySelected then p.applySelected() end end)
    local cancelBtn = MakeButton(p, "Cancel", 106, 22)
    cancelBtn:SetPoint("BOTTOMRIGHT", -8, 8)
    cancelBtn:SetScript("OnClick", function() p:Hide() end)
    p.acceptBtn = acceptBtn
    local sf = CreateFrame("ScrollFrame", nil, p)
    sf:SetPoint("TOPLEFT", 8, -34); sf:SetPoint("BOTTOMRIGHT", -8, 38)
    local child = CreateFrame("Frame", nil, sf); child:SetSize(232, 10); sf:SetScrollChild(child)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, d)
        local mx = math.max((child:GetHeight() or 0) - (self:GetHeight() or 0), 0)
        self:SetVerticalScroll(math.min(math.max(self:GetVerticalScroll() - d * 30, 0), mx))
    end)
    p.child, p.pool = child, {}
    texPopup = p
    return p
end

local function AcquireTexRow(p, i)
    local r = p.pool[i]
    if not r then
        r = CreateFrame("Button", nil, p.child)
        r:SetSize(228, 22)
        local sw = r:CreateTexture(nil, "ARTWORK"); sw:SetPoint("LEFT", 2, 0); sw:SetSize(52, 16)
        r.sw = sw
        local tx = r:CreateFontString(nil, "OVERLAY"); setFont(tx, 11)
        tx:SetPoint("LEFT", sw, "RIGHT", 6, 0); tx:SetJustifyH("LEFT"); tx:SetTextColor(0.92, 0.9, 0.85)
        r.tx = tx
        local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 0.82, 0.2, 0.14)
        -- Marca de SELECCIONADO (distinta del highlight de mouse-over): queda
        -- prendida en la fila elegida hasta que se confirme con Accept o se
        -- elija otra.
        local sel = r:CreateTexture(nil, "ARTWORK", nil, 1)
        sel:SetAllPoints(); sel:SetColorTexture(1, 0.82, 0.2, 0.30); sel:Hide()
        r.sel = sel
        p.pool[i] = r
    end
    return r
end

local function OpenTexPopup(category, dbKey, anchor, getTbl, onChange)
    local get = getTbl or getP
    local edit = onChange or OnEdit
    local p = GetTexPopup()
    local files = (ns.TEX_LIB and ns.TEX_LIB[category]) or {}
    local currentPath = get()[dbKey]
    p.selectedRow, p.selectedPath = nil, nil
    p.applySelected = function()
        if p.selectedPath then get()[dbKey] = p.selectedPath; edit(); RefreshControls() end
        p:Hide()
    end
    local i, y = 0, -2
    for _, skin in ipairs(ns.TEX_SKINS or {}) do
        if #files > 0 then
            i = i + 1; local h = AcquireTexRow(p, i)
            h.sw:Hide(); h.tx:ClearAllPoints(); h.tx:SetPoint("LEFT", 4, 0)
            h.tx:SetText("|cffffcc00" .. (skin.label or "Skin") .. "|r")
            h.sel:Hide()
            h:SetPoint("TOPLEFT", 0, y); h:Disable(); h:Show(); y = y - 20
            for _, file in ipairs(files) do
                i = i + 1; local r = AcquireTexRow(p, i)
                local path = (ns.ASSETS or "") .. (skin.folder or "") .. file
                r.sw:Show(); r.sw:SetTexture(path)
                r.tx:ClearAllPoints(); r.tx:SetPoint("LEFT", r.sw, "RIGHT", 6, 0); r.tx:SetText(file)
                r:SetPoint("TOPLEFT", 0, y); r:Enable()
                r.sel:SetShown(path == currentPath)   -- preselecciona la textura actual
                if path == currentPath then p.selectedRow, p.selectedPath = r, path end
                r:SetScript("OnClick", function()
                    if p.selectedRow then p.selectedRow.sel:Hide() end
                    p.selectedRow, p.selectedPath = r, path
                    r.sel:Show()
                end)
                r:Show(); y = y - 24
            end
        end
    end
    for j = i + 1, #p.pool do p.pool[j]:Hide() end
    p.child:SetHeight(math.max(-y + 4, 10))
    p:ClearAllPoints(); p:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 30, -2)
    p:Show(); p:Raise()
end

-- Editbox (ruta manual, reskin flat) + boton "..." que abre el selector.
-- (2026-07-17: sacada la swatch de preview al lado, el usuario no la necesita
-- — solo el editbox + el boton para abrir el selector.)
local function MakeTexturePicker(parent, label, dbKey, category, x, y, getTbl, onChange)
    local get = getTbl or getP
    local edit = onChange or OnEdit
    local lbl = parent:CreateFontString(nil, "ARTWORK"); setFont(lbl, 11)
    lbl:SetPoint("TOPLEFT", x, y); lbl:SetTextColor(COLOR_OPTION[1], COLOR_OPTION[2], COLOR_OPTION[3]); lbl:SetText(label)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(138, 20); eb:SetPoint("TOPLEFT", x + 4, y - 15); eb:SetAutoFocus(false)
    eb:SetScript("OnEnterPressed", function(self) get()[dbKey] = self:GetText(); self:ClearFocus(); edit() end)
    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        if ns.CloseMainPanel then ns.CloseMainPanel() end
    end)
    -- Reskin FLAT (mismo lenguaje visual que MakeSlider): oculta el arte azul
    -- default de InputBoxTemplate y dibuja fondo plano + lineas finas.
    if eb.Left then eb.Left:SetAlpha(0) end
    if eb.Middle then eb.Middle:SetAlpha(0) end
    if eb.Right then eb.Right:SetAlpha(0) end
    local ebBg = eb:CreateTexture(nil, "BACKGROUND", nil, -1)
    ebBg:SetColorTexture(0, 0, 0, 0.45)
    ebBg:SetPoint("TOPLEFT", -3, 1)
    ebBg:SetPoint("BOTTOMRIGHT", 3, -1)
    local ebTop = eb:CreateTexture(nil, "BORDER")
    ebTop:SetColorTexture(COLOR_LINE[1], COLOR_LINE[2], COLOR_LINE[3], 0.5)
    ebTop:SetPoint("TOPLEFT", ebBg, "TOPLEFT", 0, 0)
    ebTop:SetPoint("TOPRIGHT", ebBg, "TOPRIGHT", 0, 0)
    ebTop:SetHeight(1)
    local ebBot = eb:CreateTexture(nil, "BORDER")
    ebBot:SetColorTexture(COLOR_LINE[1], COLOR_LINE[2], COLOR_LINE[3], 0.5)
    ebBot:SetPoint("BOTTOMLEFT", ebBg, "BOTTOMLEFT", 0, 0)
    ebBot:SetPoint("BOTTOMRIGHT", ebBg, "BOTTOMRIGHT", 0, 0)
    ebBot:SetHeight(1)

    local pick = MakeButton(parent, "...", 24, 20); pick:SetPoint("LEFT", eb, "RIGHT", 10, 0)
    pick:SetScript("OnClick", function() OpenTexPopup(category, dbKey, pick, getTbl, onChange) end)
    refreshers[#refreshers + 1] = function()
        local v = get()[dbKey]
        eb:SetText(v or "")
    end
    return eb
end

-- ==========================================================================
-- POPUP EXPORTAR / IMPORTAR (editbox multilinea copiable)
-- ==========================================================================
local ioPopup
local function GetIOPopup()
    if ioPopup then return ioPopup end
    local p = CreateFrame("Frame", "MyCF_IOPopup", UIParent)
    p:SetSize(440, 300); p:SetFrameStrata("FULLSCREEN_DIALOG"); p:EnableMouse(true); p:Hide()
    tinsert(UISpecialFrames, "MyCF_IOPopup")   -- mismo motivo que MyCF_TexPopup
    p:SetMovable(true); p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", p.StartMoving); p:SetScript("OnDragStop", p.StopMovingOrSizing)
    local bg = p:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.04, 0.04, 0.05, 0.97)
    local ttl = p:CreateFontString(nil, "OVERLAY"); setFont(ttl, 14)
    ttl:SetPoint("TOPLEFT", 12, -10); ttl:SetTextColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3]); p.ttl = ttl
    local close = MakeButton(p, "X", 22, 20); close:SetPoint("TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function() p:Hide() end)

    local box = CreateFrame("Frame", nil, p)
    box:SetPoint("TOPLEFT", 12, -36); box:SetPoint("BOTTOMRIGHT", -12, 40)
    local boxbg = box:CreateTexture(nil, "BACKGROUND"); boxbg:SetAllPoints(); boxbg:SetColorTexture(0, 0, 0, 0.5)
    local sf = CreateFrame("ScrollFrame", nil, box)
    sf:SetPoint("TOPLEFT", 4, -4); sf:SetPoint("BOTTOMRIGHT", -4, 4)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetFontObject(ChatFontNormal)
    -- FIX 2026-07-19 (reportado por el usuario: "el export nuevo no esta
    -- funcionando... formato invalido" -- el string de export ahora incluye
    -- MUCHAS mas sub-tablas que antes (nameplates/classpower/tooltip/etc,
    -- ver PRESET_TABLE_KEYS en core.lua) y supera el limite viejo de 99999
    -- caracteres -- SetText() lo trunca en SILENCIO al mostrarlo, asi que
    -- lo que el usuario copiaba ya venia cortado (Lua invalido al
    -- reimportar). 0 = sin limite.
    eb:SetMaxLetters(0); eb:SetWidth(400)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); p:Hide() end)
    sf:SetScrollChild(eb)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, d)
        local mx = math.max((eb:GetHeight() or 0) - (self:GetHeight() or 0), 0)
        self:SetVerticalScroll(math.min(math.max(self:GetVerticalScroll() - d * 30, 0), mx))
    end)
    -- Clic en cualquier parte de la caja = enfocar el editbox (si esta vacio es diminuto
    -- y no se puede clicar para pegar). Sin esto Ctrl+V no tiene donde ir.
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function() eb:SetFocus() end)
    sf:EnableMouse(true)
    sf:SetScript("OnMouseDown", function() eb:SetFocus() end)
    p.eb = eb

    local action = MakeButton(p, "Import", 110, 24); action:SetPoint("BOTTOMRIGHT", -12, 10); p.action = action
    local hint = p:CreateFontString(nil, "ARTWORK"); setFont(hint, 10)
    hint:SetPoint("BOTTOMLEFT", 12, 16); hint:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3]); p.hint = hint
    ioPopup = p
    return p
end

local function ShowExport(name)
    local p = GetIOPopup()
    p.ttl:SetText("Export profile")
    p.hint:SetText("Ctrl+C to copy (already selected).")
    p.eb:SetText(ns.ExportPreset(name) or "")
    p.action:Hide()
    p:ClearAllPoints(); p:SetPoint("CENTER"); p:Show()
    p.eb:SetFocus(); p.eb:HighlightText()
end

local function ShowImport(onDone)
    local p = GetIOPopup()
    p.ttl:SetText("Import profile")
    p.hint:SetText("Paste the code and press Import.")
    p.eb:SetText("")
    p.action:Show()
    p.action:SetScript("OnClick", function()
        local ok, res = ns.ImportPreset(p.eb:GetText())
        if ok then p:Hide(); if onDone then onDone(res) end
        else p.hint:SetText("|cffff5555Error: " .. tostring(res) .. "|r") end
    end)
    p:ClearAllPoints(); p:SetPoint("CENTER"); p:Show()
    p.eb:SetFocus()
end

-- ==========================================================================
-- PANEL
-- 2026-07-16: convertido de categoria embebida en Blizzard Settings a frame
-- STANDALONE (estilo Plumber real: ventana propia con borde, arrastrable,
-- cerrable con ESC y con boton Close) — Settings.RegisterCanvasLayoutCategory
-- imponia el chrome de Blizzard alrededor del panel; un frame propio permite
-- calcar el layout de 3 columnas de Plumber (sidebar / contenido / preview).
-- Se abre con /mcfmenu (Setup.lua ya usa /mcfsetup, core.lua usa /mcf para
-- el toggle de unlock — no colisiona).
-- ==========================================================================
local PANEL_W, PANEL_H = 900, 576   -- 576 = mismo PageHeight que usa Plumber
local PREVIEW_W = 200               -- ancho de la 3ra columna (preview/descripcion)

local panel = CreateFrame("Frame", "MyCF_ControlCenter", UIParent, "BackdropTemplate")
panel.name = "AzeriteUI — Gonkast Preset"
panel:SetSize(PANEL_W, PANEL_H)
panel:SetPoint("CENTER")
panel:SetFrameStrata("HIGH")
-- Fondo solido simple (SIN edgeFile): el borde ornamentado real se dibuja aparte
-- abajo, recortado del atlas PLB (mismas piezas 512-1024/832-1024 que usa el
-- MainFrame.NineSlice de Plumber real, ver SettingsPanelNew.lua:2143-2166).
panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
panel:SetBackdropColor(0.10, 0.08, 0.06, 0.97)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:SetClampedToScreen(true)
panel:Hide()
-- 2026-07-18: se probo reemplazar esto por un OnKeyDown manual (teoria: ESC via
-- UISpecialFrames hacia un fundido diferido) -- el diagnostico en vivo
-- (/mcfpaneldiag) confirmo que el OnKeyDown NUNCA disparaba (panel quedaba
-- shown=true despues de ESC) y, peor, sin estar en UISpecialFrames el ESC
-- pasaba de largo a abrir el menu de Blizzard ENCIMA del panel, que seguia
-- vivo y bloqueando el mouse debajo. El culpable real de la "zona muerta"
-- original eran los popups de textura/import (ver GetTexPopup/GetIOPopup),
-- ya corregidos aparte -- se revierte esto a lo que SI funcionaba.
tinsert(UISpecialFrames, "MyCF_ControlCenter")   -- permite cerrar con ESC

-- 2026-07-18 (intento definitivo): con TODOS los caminos "normales" ya
-- probados y confirmados rotos en vivo (/mcfpaneldiag: panel sigue
-- shown=true despues de ESC, con o sin UISpecialFrames, con o sin OnKeyDown
-- manual, con o sin editbox enfocado) -- lo mas probable es que
-- CloseSpecialWindows() no este reconociendo este frame por algun motivo
-- propio del cliente 12.0.7, y ESC termina en ToggleGameMenu() de todas
-- formas (abriendo el menu de Blizzard ENCIMA, dejando el panel vivo debajo
-- -- eso explicaria la "zona muerta"). En vez de seguir dependiendo de que
-- Blizzard reconozca el panel, se engancha DIRECTO la funcion que ESC
-- realmente ejecuta: si se llega a abrir el menu de Blizzard mientras
-- nuestro panel sigue abierto, se cierra al toque.
if ToggleGameMenu then
    hooksecurefunc("ToggleGameMenu", function()
        if panel:IsShown() then panel:Hide() end
    end)
end

-- Borde (2026-07-17, intento 2): Background_complete1.tga — version nueva del
-- usuario, exportada ya cerca del aspect ratio del panel (2592x1632 = 1.588:1
-- vs panel 900x576 = 1.5625:1, mucho mas parecido que el intento anterior de
-- 1.157:1). Padding medido con el mismo script de analisis de canal alfa:
-- izq/der ~3.05%, arriba ~6.13%, abajo ~3.98%.
local borderTex = panel:CreateTexture(nil, "ARTWORK")
borderTex:SetTexture("Interface\\AddOns\\MyCustomFrames\\Assets\\Background_complete1.tga")
borderTex:SetPoint("TOPLEFT", -44, 54)
borderTex:SetPoint("BOTTOMRIGHT", 44, -41)

-- Arrastre (2026-07-17, v3): antes solo se podia mover desde una franja fija
-- arriba (con un icono de "agarre" que quedo feo) — ahora se puede arrastrar
-- desde CUALQUIER zona vacia de la ventana. El panel entero recibe el mouse
-- down; los widgets interactivos (botones, sliders, editboxes, tabs) viven en
-- frames propios con su propio mouse habilitado, asi que capturan el click
-- ANTES de que llegue a `panel` — solo el fondo/espacios vacios arrastran.
panel:SetScript("OnMouseDown", function(self, btn)
    if btn == "LeftButton" and not self.isMoving then self.isMoving = true; self:StartMoving() end
end)
local function PanelFinishMove(self)
    if not self.isMoving then return end
    self.isMoving = false
    self:StopMovingOrSizing()
end
panel:SetScript("OnMouseUp", PanelFinishMove)
-- Red de seguridad (2026-07-18): si el boton se suelta fuera del panel (p.ej.
-- sobre el boton de cerrar, que captura el click antes de llegar a `panel`),
-- OnMouseUp nunca dispara y el panel queda "pegado" siguiendo al mouse -- eso
-- es lo que se veia como un "fantasma" bloqueando esa zona de la pantalla.
-- Un ticker barato chequea el boton fisico del mouse y corta el movimiento
-- ni bien se suelta, sin depender de que el evento llegue a este frame.
local moveWatcher = CreateFrame("Frame")
moveWatcher:Hide()
moveWatcher:SetScript("OnUpdate", function()
    if panel.isMoving and not IsMouseButtonDown("LeftButton") then PanelFinishMove(panel) end
    if not panel.isMoving then moveWatcher:Hide() end
end)
panel:HookScript("OnMouseDown", function() if panel.isMoving then moveWatcher:Show() end end)
-- Si el panel se oculta (ESC, boton de cerrar, toggle rapido) mientras se
-- estaba arrastrando, forzar el corte del movimiento tambien aca.
panel:HookScript("OnHide", function(self)
    PanelFinishMove(self)
    -- A pedido del usuario: cerrar el menu cancela el modo Lock/edicion.
    if ns.IsUnlocked and ns.IsUnlocked() and ns.SetUnlocked then ns.SetUnlocked(false) end
    -- Red de seguridad: si el popup de textura o de import/export quedo abierto,
    -- se cierra junto con el menu principal (ya no deberia ocurrir porque ambos
    -- se cierran solos con ESC, pero por si el panel se oculta por otra via).
    if texPopup then texPopup:Hide() end
    if ioPopup then ioPopup:Hide() end
end)

ns.OpenControlCenter = function() panel:Show() end
ns.ToggleControlCenter = function() if panel:IsShown() then panel:Hide() else panel:Show() end end
-- 2026-07-18: el motivo real de "ESC no cierra el panel" (confirmado con
-- /mcfpaneldiag: panel quedaba shown=true despues de ESC) es un comportamiento
-- NATIVO de EditBox -- si CUALQUIERA de los editbox del panel (sliders con
-- valor tipeable, campos de textura, buscador, etc.) tiene el foco, ESC solo
-- le saca el foco a ESE editbox y NUNCA llega a UISpecialFrames -- hace falta
-- un SEGUNDO ESC para cerrar el panel. Los OnEscapePressed de esos editbox
-- ahora llaman esto ademas de ClearFocus(), para que UN solo ESC alcance
-- siempre, tenga foco un editbox o no.
ns.CloseMainPanel = function() panel:Hide() end

-- Diagnostico 2026-07-18: correr esto PARADO SOBRE la zona muerta, ANTES de
-- clickear nada mas (el click en el boton del minimapa "libera" la zona, asi
-- que hay que capturar el estado mientras sigue trabada).
SLASH_MCFPANELDIAG1 = "/mcfpaneldiag"
SlashCmdList["MCFPANELDIAG"] = function()
    print(("|cff00ff00[MCF diag]|r panel: shown=%s mouse=%s alpha=%.2f isMoving=%s strata=%s point=%s"):format(
        tostring(panel:IsShown()), tostring(panel:IsMouseEnabled()), panel:GetAlpha() or -1,
        tostring(panel.isMoving), panel:GetFrameStrata(), tostring(select(1, panel:GetPoint()))))
    if texPopup then print(("  texPopup: shown=%s mouse=%s"):format(tostring(texPopup:IsShown()), tostring(texPopup:IsMouseEnabled()))) end
    if ioPopup then print(("  ioPopup: shown=%s mouse=%s"):format(tostring(ioPopup:IsShown()), tostring(ioPopup:IsMouseEnabled()))) end
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    x, y = x / scale, y / scale
    local f = GetMouseFocus and GetMouseFocus()
    print(("  cursor=(%.0f,%.0f) mouseFocus=%s"):format(x, y, f and (f:GetName() or "<anon>") or "nil"))
end

local sections = {}          -- key -> frame
local sectionTabs = {}       -- key -> button
local unitTabs = {}
-- Botones parentados DIRECTO a `panel` (no a `panel._content`): los globales de arriba
-- (Profile/Explorer/Editing/Setup) y los de la barra de abajo (Move-Lock/Preview/Outline/
-- Copy/Paste). El nudge de ApplyPanelView (Hide/Show de panel._content) NO los toca porque no
-- son descendientes de content -> quedaban FUERA de la red de seguridad del bug de labels en
-- blanco (2026-07-15, encontrado tras varias rondas de fix que no alcanzaban). Se registran aca
-- y ReassertLabels los recorre igual que sectionTabs/unitTabs.
local panelButtons = {}
local unitTitle              -- fontstring del titulo de la unidad editada
local unitCopyBtn, unitPasteBtn   -- Copy/Paste junto al titulo, solo visibles para unidades/portraits/etc
-- fila Gen/Bar/Cage/... + su scrollbar horizontal (tabla en vez de 3 locals
-- sueltas: BuildPanel ya estaba al limite de 60 upvalues de Lua por funcion).
local tabScrollUI = {}
-- Consolidado en tablas (2026-07-17): BuildPanel se paso del limite de 60
-- upvalues de Lua por funcion; cada grupo de variables relacionadas pasa de
-- N locals sueltas a 1 sola tabla (misma logica, menos upvalues).
local HIDEGRP = { powerHidden = {}, colorHidden = {}, nameSectionKeys = { name = true, spell = true } }
local VIS = {
    portraitDualBoxes = {},   -- grupos visibles solo si el portrait tiene dualPos
    portraitModelOnly = {},   -- widgets visibles solo si el retrato es modelo 3D (no icono)
    portraitPlayerOnly = {},  -- widgets visibles solo en el player portrait
    portraitRoleOnly = {},    -- widgets visibles solo si el portrait tiene rol (party)
    auraDualBoxes = {},       -- grupos visibles solo si el aura tiene dualPos (player)
}
local NAVBTN = {}   -- .presets/.explorer/.editing/.setup: botones globales (esquina sup. derecha)
local currentSection = "general"
local UpdatePreview   -- asignada en BuildPanel (3ra columna estilo Plumber, ver mas abajo)

-- Secciones "globales" (Setup/Editing/Explorer/Profile): no pertenecen a ninguna
-- unidad, asi que NO tienen fila de sub-tabs propia. Antes esa fila se quedaba
-- mostrando los sub-tabs de la ULTIMA unidad seleccionada (ej: entrar a Explorer
-- dejaba visible "Gen/Bar/Cage/Sel/Health/Name/Spell/Cast/Color" de ToT debajo),
-- dando la sensacion de estar en dos secciones a la vez. Se ocultan explicito aca.
local GLOBAL_SECTION_TITLE = { presets = "Profile", explorer = "Explorer", editing = "Editing", setup = "Setup", extras = "Extras" }

local function ShowSection(key)
    if not sections[key] then return end
    currentSection = key
    for k, f in pairs(sections) do f:SetShown(k == key) end
    if GLOBAL_SECTION_TITLE[key] then
        for k, b in pairs(sectionTabs) do b:Hide() end
        if unitTitle then unitTitle:SetText(GLOBAL_SECTION_TITLE[key]) end
        if unitCopyBtn then unitCopyBtn:Hide() end
        if unitPasteBtn then unitPasteBtn:Hide() end
        -- Setup/Editing/Explorer/Profile no tienen sub-tabs (Gen/Bar/Cage/...),
        -- asi que tampoco necesitan SU scrollbar horizontal - antes quedaba
        -- visible "pegada" de la ultima unidad seleccionada.
        if tabScrollUI.frame then tabScrollUI.frame:Hide() end
        if tabScrollUI.track then tabScrollUI.track:Hide() end
        if tabScrollUI.thumb then tabScrollUI.thumb:Hide() end
    else
        for k, b in pairs(sectionTabs) do b:SetActive(k == key) end
        if unitCopyBtn then unitCopyBtn:Show() end
        if unitPasteBtn then unitPasteBtn:Show() end
        if tabScrollUI.frame then tabScrollUI.frame:Show() end
    end
    if NAVBTN.presets then NAVBTN.presets:SetActive(key == "presets") end
    if NAVBTN.explorer then NAVBTN.explorer:SetActive(key == "explorer") end
    if NAVBTN.editing then NAVBTN.editing:SetActive(key == "editing") end
    if NAVBTN.setup then NAVBTN.setup:SetActive(key == "setup") end
    if NAVBTN.extras then NAVBTN.extras:SetActive(key == "extras") end
    if UpdatePreview then UpdatePreview() end
    -- Nudge: fuerza el relayout de la seccion recien mostrada. El canvas de Settings a
    -- veces no posiciona/renderiza los widgets hasta un Hide/Show (de ahi el bug de
    -- "botones que no aparecen hasta salir y volver"). Aplicarlo en CADA cambio de seccion.
    local f = sections[key]
    if f and f:IsShown() then f:Hide(); f:Show() end
    -- Transicion suave (2026-07-17): un fade-in corto en vez de aparecer de golpe,
    -- calcando el pulido de Plumber al cambiar de categoria.
    if f and UIFrameFadeIn then
        f:SetAlpha(0)
        UIFrameFadeIn(f, 0.15, 0, 1)
    end
end

local function IsPortraitSection(k) return k:sub(1, 2) == "p_" end
local function IsAuraSection(k) return k:sub(1, 2) == "a_" end
local function IsInfoSection(k) return k:sub(1, 2) == "i_" end
local function IsMicroSection(k) return k:sub(1, 3) == "mm_" end
local function IsChatSection(k) return k:sub(1, 3) == "cb_" end
local function IsTrackerSection(k) return k:sub(1, 2) == "t_" end
local function IsGlowSection(k) return k:sub(1, 2) == "g_" end
local function IsPartyAuraSection(k) return k:sub(1, 3) == "ap_" end
local function IsArenaAuraSection(k) return k:sub(1, 3) == "aa_" end
local function IsMinimapSection(k) return k:sub(1, 3) == "mn_" end
local function IsNameplatesSection(k) return k:sub(1, 3) == "np_" end
local function IsClassPowerSection(k) return k:sub(1, 3) == "cp_" end
local function IsRaidSection(k) return k:sub(1, 2) == "r_" end

-- p_rest / p_badges dependen de features del portrait; el resto siempre aplican.
local function PortraitSectionAllowed(k, feats)
    if k == "p_rest"   then return feats.rest and true or false end
    if k == "p_badges" then return (feats.faction or feats.combat) and true or false end
    if k == "p_raid"   then return feats.raidTarget and true or false end
    if k == "p_role"   then return (feats.roleLeader or feats.leader) and true or false end
    return true
end

local function SelectUnit(key)
    ns.currentEdit = key
    for k, b in pairs(unitTabs) do b:SetActive(k == key) end
    RefreshControls()
    if ns.ResetTabRowScroll then ns.ResetTabRowScroll() end

    local isInfo = ns.IsInfoBar and ns.IsInfoBar(key)
    local isMicro = ns.IsMicroMenu and ns.IsMicroMenu(key)
    local isChat = ns.IsChatBubble and ns.IsChatBubble(key)
    local isTracker = ns.IsTracker and ns.IsTracker(key)
    local isGlow = ns.IsGlow and ns.IsGlow(key)
    local isMinimap = ns.IsMinimap and ns.IsMinimap(key)
    local isNameplates = ns.IsNameplates and ns.IsNameplates(key)
    local isRaid = ns.IsRaid and ns.IsRaid(key)
    local isAura = ns.IsAura and ns.IsAura(key)
    local isPortrait = ns.IsPortrait and ns.IsPortrait(key)
    local isPartyAuraTitle = ns.IsPartyAura and ns.IsPartyAura(key)
    local isArenaAuraTitle = ns.IsArenaAura and ns.IsArenaAura(key)
    local u = (isAura and ns.auras[key]) or (isPortrait and ns.portraits[key]) or ns.frames[key]
    local title = isInfo and "Info Bar" or isMicro and "Micro Menu" or isChat and "Chat Bubble"
        or isTracker and "Quest Tracker" or isGlow and "Assisted Glow" or isMinimap and "Minimap"
        or isNameplates and "Nameplates" or isRaid and "Raid Frames" or isPartyAuraTitle and "Party Auras"
        or isArenaAuraTitle and "Arena Auras"
        or (u and u.label) or key
    if unitTitle then unitTitle:SetText("Editing:  |cffffffff" .. title .. "|r") end
    if UpdatePreview then UpdatePreview() end

    if isInfo then
        for k, b in pairs(sectionTabs) do b:SetShown(IsInfoSection(k)) end
        if not IsInfoSection(currentSection) then ShowSection("i_general") end
        return
    end

    if isMicro then
        for k, b in pairs(sectionTabs) do b:SetShown(IsMicroSection(k)) end
        if not IsMicroSection(currentSection) then ShowSection("mm_general") end
        return
    end

    if isChat then
        for k, b in pairs(sectionTabs) do b:SetShown(IsChatSection(k)) end
        if not IsChatSection(currentSection) then ShowSection("cb_general") end
        return
    end

    if isTracker then
        for k, b in pairs(sectionTabs) do b:SetShown(IsTrackerSection(k)) end
        if not IsTrackerSection(currentSection) then ShowSection("t_general") end
        return
    end

    if isGlow then
        for k, b in pairs(sectionTabs) do b:SetShown(IsGlowSection(k)) end
        if not IsGlowSection(currentSection) then ShowSection("g_general") end
        return
    end

    if isMinimap then
        for k, b in pairs(sectionTabs) do b:SetShown(IsMinimapSection(k)) end
        if not IsMinimapSection(currentSection) then ShowSection("mn_general") end
        return
    end

    if isNameplates then
        for k, b in pairs(sectionTabs) do b:SetShown(IsNameplatesSection(k)) end
        if not IsNameplatesSection(currentSection) then ShowSection("np_general") end
        return
    end

    if isRaid then
        for k, b in pairs(sectionTabs) do b:SetShown(IsRaidSection(k)) end
        if not IsRaidSection(currentSection) then ShowSection("r_general") end
        return
    end

    local isPartyAura = ns.IsPartyAura and ns.IsPartyAura(key)
    if isPartyAura then
        for k, b in pairs(sectionTabs) do b:SetShown(IsPartyAuraSection(k)) end
        if not IsPartyAuraSection(currentSection) then ShowSection("ap_general") end
        return
    end

    local isArenaAura = ns.IsArenaAura and ns.IsArenaAura(key)
    if isArenaAura then
        for k, b in pairs(sectionTabs) do b:SetShown(IsArenaAuraSection(k)) end
        if not IsArenaAuraSection(currentSection) then ShowSection("aa_general") end
        return
    end

    local isClassPower = ns.IsClassPower and ns.IsClassPower(key)
    if isClassPower then
        for k, b in pairs(sectionTabs) do b:SetShown(IsClassPowerSection(k)) end
        if not IsClassPowerSection(currentSection) then ShowSection("cp_general") end
        return
    end

    if isAura then
        local dual = ns.AuraIsDual and ns.AuraIsDual(key)
        for k, b in pairs(sectionTabs) do
            if k == "a_dead" then b:SetShown(dual and true or false)
            elseif IsAuraSection(k) then b:SetShown(true)
            else b:SetShown(false) end
        end
        for _, w in ipairs(VIS.auraDualBoxes) do w:SetShown(dual and true or false) end
        local okSec = IsAuraSection(currentSection) and (currentSection ~= "a_dead" or dual)
        if not okSec then ShowSection("a_general") end
        return
    end

    if isPortrait then
        local feats = (ns.PortraitFeatures and ns.PortraitFeatures(key)) or {}
        local kind = (ns.PortraitKind and ns.PortraitKind(key)) or "model"
        for k, b in pairs(sectionTabs) do
            b:SetShown(IsPortraitSection(k) and PortraitSectionAllowed(k, feats))
        end
        for _, w in ipairs(VIS.portraitDualBoxes) do w:SetShown(feats.dualPos and true or false) end
        for _, w in ipairs(VIS.portraitModelOnly) do w:SetShown(kind == "model") end
        for _, w in ipairs(VIS.portraitPlayerOnly) do w:SetShown(key == "portrait_player") end
        for _, w in ipairs(VIS.portraitRoleOnly) do w:SetShown(feats.roleLeader and true or false) end
        local okSection = IsPortraitSection(currentSection)
            and PortraitSectionAllowed(currentSection, feats)
        if not okSection then ShowSection("p_general") end
        return
    end

    -- Unidad normal.
    local isPower = u and u.kind == "power"
    local noColor = isPower or (u and u.fixedColor ~= nil)
    local hasName = u and u.nameText
    -- Trinket de PvP: solo Arena Enemy 1/2/3 (pedido del usuario -- "no añadir
    -- funciones propias de addons PvP avanzados", esta pestaña solo aparece
    -- donde el widget realmente existe, ver CreateUnit en Units.lua).
    local isArenaEnemy = key:sub(1, 11) == "arena_enemy"
    for _, f in ipairs(HIDEGRP.powerHidden) do f:SetShown(not isPower) end
    for _, f in ipairs(HIDEGRP.colorHidden) do f:SetShown(not noColor) end
    for k, b in pairs(sectionTabs) do
        if IsPortraitSection(k) or IsAuraSection(k) or IsInfoSection(k) or IsMicroSection(k) or IsChatSection(k) or IsTrackerSection(k) or IsGlowSection(k) or IsPartyAuraSection(k) or IsArenaAuraSection(k) or IsMinimapSection(k) or IsNameplatesSection(k) or IsClassPowerSection(k) or IsRaidSection(k) then b:SetShown(false)
        elseif HIDEGRP.nameSectionKeys[k] then b:SetShown(hasName and true or false)
        elseif k == "cast" or k == "highlight" then b:SetShown(not isPower)
        elseif k == "trinket" then b:SetShown(isArenaEnemy)
        else b:SetShown(true) end
    end
    if currentSection == "trinket" and not isArenaEnemy then ShowSection("general") end
    if IsPortraitSection(currentSection) or IsAuraSection(currentSection) or IsInfoSection(currentSection)
       or IsMicroSection(currentSection) or IsChatSection(currentSection) or IsTrackerSection(currentSection)
       or IsGlowSection(currentSection) or IsPartyAuraSection(currentSection) or IsArenaAuraSection(currentSection)
       or IsMinimapSection(currentSection)
       or IsNameplatesSection(currentSection) or IsClassPowerSection(currentSection) or IsRaidSection(currentSection)
       or currentSection == "presets" or currentSection == "explorer" or currentSection == "editing"
       or currentSection == "setup" or currentSection == "extras"
       or (HIDEGRP.nameSectionKeys[currentSection] and not hasName)
       or ((currentSection == "cast" or currentSection == "highlight") and isPower) then
        ShowSection("general")
    end
end

-- ---- Construccion -------------------------------------------------------
local UNIT_GROUPS = {
    { title = "MAIN", keys = { "player", "target", "targettarget", "pet", "focus" } },
    { title = "POWER",     keys = { "playerpower", "targetpower" } },
    { title = "BOSSES",     keys = { "boss1", "boss2", "boss3", "boss4", "boss5" } },
    { title = "GROUP",     keys = { "party1", "party2", "party3", "party4", "party5" } },
    { title = "RAID", keys = { "raid" } },
    -- ARENA (pedido del usuario 2026-07-19): 6 unitframes propias, copias
    -- INDEPENDIENTES de player/party1/party2 (aliados) + arena1/2/3 nativos
    -- (enemigos) -- ver ARENA_KEYS en core.lua. Usan el MISMO sistema generico
    -- de edicion por-unidad que GROUP/BOSSES, nada especial que registrar aca.
    { title = "ARENA", keys = { "arena_player", "arena_party1", "arena_party2",
        "arena_enemy1", "arena_enemy2", "arena_enemy3" } },
    { title = "PORTRAITS", keys = { "portrait_player", "portrait_pet",
        "portrait_target", "portrait_tot",
        "portrait_party1", "portrait_party2", "portrait_party3", "portrait_party4", "portrait_party5" } },
    { title = "ARENA PORTRAITS", keys = { "portrait_arena_player", "portrait_arena_party1",
        "portrait_arena_party2", "portrait_arena_enemy1", "portrait_arena_enemy2", "portrait_arena_enemy3" } },
    { title = "AURAS", keys = { "aura_player", "aura_target", "aura_party", "aura_arena" } },
    { title = "INFO",  keys = { "infobar" } },
    { title = "MICRO", keys = { "micromenu" } },
    { title = "CHAT",  keys = { "chatbubble" } },
    { title = "TRACKER", keys = { "tracker" } },
    { title = "GLOW",  keys = { "glow" } },
    { title = "MINIMAP", keys = { "minimap" } },
    { title = "NAMEPLATES", keys = { "nameplates" } },
    { title = "CLASS POWER", keys = { "classpower" } },
}


local built = false
local function BuildPanel()
    -- Fondo.
    -- 2026-07-17 (ronda 2): el usuario sigue viendolo muy oscuro — ademas del
    -- velo negro de aca, sidebar (sbBg) y preview (pvBg) suman SUS PROPIOS
    -- overlays negros encima, y se acumulan. Se aclaran los tres a la vez.
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(PL.BG)
    bg:SetPoint("TOPLEFT", 4, -4); bg:SetPoint("BOTTOMRIGHT", -4, 4)
    bg:SetAlpha(1)
    local shade = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
    shade:SetAllPoints(bg); shade:SetColorTexture(0, 0, 0, 0.08)

    local title = panel:CreateFontString(nil, "ARTWORK")
    setFont(title, 16)
    title:SetPoint("TOP", panel, "TOP", 0, -16)
    title:SetTextColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
    title:SetText("AzeriteUI |cffffcc00—|r Gonkast Preset")

    -- Unico tab arriba a la derecha: Close. Setup/Editing/Explorer/Profile se
    -- movieron a la sidebar como categorias propias (2026-07-17, Fase B: antes
    -- vivian aparte en esta fila, ahora son items de lista igual que las unidades).
    local closeBtn = MakeTabButton(panel, "Close", 70)
    closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -62, -7)
    closeBtn:SetScript("OnClick", function() panel:Hide() end)
    panelButtons[#panelButtons + 1] = closeBtn

    -- Escala de la VENTANA del menu (no confundir con "scale" de las unidades,
    -- que es por-unidad). Global (db.panelScale), no por preset.
    -- 2026-07-17: reemplazado el drag-slider (80px mapeando un rango de 0.9 ->
    -- cada pixel de arrastre saltaba mucho, "muy grande o muy chico") por un
    -- stepper -/valor editable/+ de paso fijo (0.05) — mismo control preciso
    -- que ya usa MakeSlider, sin el drag impreciso.
    do
        local step = 0.05
        local minV, maxV = 0.6, 1.5
        local function clampScale(v) return math.max(minV, math.min(maxV, v)) end
        local function roundScale(v) return math.floor(v / step + 0.5) * step end

        local scalePlus = MakeButton(panel, "+", 20, 20)
        scalePlus:SetPoint("RIGHT", closeBtn, "LEFT", -8, 0)

        local scaleVal = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        scaleVal:SetSize(40, 20)
        scaleVal:SetPoint("RIGHT", scalePlus, "LEFT", -2, 0)
        scaleVal:SetAutoFocus(false); scaleVal:SetJustifyH("CENTER")
        if scaleVal.Left then scaleVal.Left:SetAlpha(0) end
        if scaleVal.Middle then scaleVal.Middle:SetAlpha(0) end
        if scaleVal.Right then scaleVal.Right:SetAlpha(0) end
        local svBg = scaleVal:CreateTexture(nil, "BACKGROUND", nil, -1)
        svBg:SetColorTexture(0, 0, 0, 0.45)
        svBg:SetPoint("TOPLEFT", -3, 1); svBg:SetPoint("BOTTOMRIGHT", 3, -1)
        local svTop = scaleVal:CreateTexture(nil, "BORDER")
        svTop:SetColorTexture(COLOR_LINE[1], COLOR_LINE[2], COLOR_LINE[3], 0.5)
        svTop:SetPoint("TOPLEFT", svBg, "TOPLEFT", 0, 0); svTop:SetPoint("TOPRIGHT", svBg, "TOPRIGHT", 0, 0); svTop:SetHeight(1)
        local svBot = scaleVal:CreateTexture(nil, "BORDER")
        svBot:SetColorTexture(COLOR_LINE[1], COLOR_LINE[2], COLOR_LINE[3], 0.5)
        svBot:SetPoint("BOTTOMLEFT", svBg, "BOTTOMLEFT", 0, 0); svBot:SetPoint("BOTTOMRIGHT", svBg, "BOTTOMRIGHT", 0, 0); svBot:SetHeight(1)

        local scaleMinus = MakeButton(panel, "-", 20, 20)
        scaleMinus:SetPoint("RIGHT", scaleVal, "LEFT", -2, 0)

        local scaleLbl = panel:CreateFontString(nil, "ARTWORK"); setFont(scaleLbl, 11)
        scaleLbl:SetPoint("RIGHT", scaleMinus, "LEFT", -8, 0)
        scaleLbl:SetTextColor(COLOR_OPTION[1], COLOR_OPTION[2], COLOR_OPTION[3])
        scaleLbl:SetText("Scale")

        local function setScale(v)
            v = clampScale(roundScale(v))
            ns.GetDB().panelScale = v
            panel:SetScale(v)
            scaleVal:SetText(string.format("%.2f", v))
        end
        scalePlus:SetScript("OnClick", function() setScale(((ns.GetDB() and ns.GetDB().panelScale) or 1.0) + step) end)
        scaleMinus:SetScript("OnClick", function() setScale(((ns.GetDB() and ns.GetDB().panelScale) or 1.0) - step) end)
        scaleVal:SetScript("OnEnterPressed", function(self)
            local v = tonumber(self:GetText())
            if v then setScale(v) else self:SetText(string.format("%.2f", (ns.GetDB() and ns.GetDB().panelScale) or 1.0)) end
            self:ClearFocus()
        end)
        scaleVal:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            if ns.CloseMainPanel then ns.CloseMainPanel() end
        end)

        refreshers[#refreshers + 1] = function()
            local v = (ns.GetDB() and ns.GetDB().panelScale) or 1.0
            scaleVal:SetText(string.format("%.2f", v))
            panel:SetScale(v)
        end
    end

    local LABELS = {}
    for _, d in ipairs(ns.UNITS) do LABELS[d.key] = d.label end
    for _, d in ipairs(ns.PORTRAITS or {}) do LABELS[d.key] = d.label end
    for _, d in ipairs(ns.AURAS or {}) do LABELS[d.key] = d.label end
    LABELS[ns.INFOBAR_KEY or "infobar"] = "Info Bar"
    LABELS[ns.MICROMENU_KEY or "micromenu"] = "Micro Menu"
    LABELS[ns.CHATBUBBLE_KEY or "chatbubble"] = "Chat Bubble"
    LABELS[ns.TRACKER_KEY or "tracker"] = "Quest Tracker"
    LABELS[ns.GLOW_KEY or "glow"] = "Assisted Glow"
    LABELS["minimap"] = "Minimap"
    LABELS["nameplates"] = "Nameplates"
    LABELS["aura_party"] = "Party"
    LABELS["aura_arena"] = "Arena"

    -- ===== SIDEBAR: lista de unidades agrupada (con scroll) =====
    local sidebar = CreateFrame("Frame", nil, panel)
    sidebar:SetPoint("TOPLEFT", 10, -42)
    sidebar:SetPoint("BOTTOMLEFT", 10, 44)
    sidebar:SetWidth(140)
    local sbBg = sidebar:CreateTexture(nil, "BACKGROUND")
    -- 2026-07-17: un poco mas oscura que content (que no tiene overlay propio)
    -- para que las 3 columnas (sidebar/contenido/preview) se lean como zonas
    -- distintas en vez de un unico fondo continuo.
    sbBg:SetAllPoints(); sbBg:SetColorTexture(0, 0, 0, 0.22)

    -- Buscador: filtra la lista por nombre. RelayoutSidebar se define mas abajo.
    -- sortBtn (boton cuadrado a la derecha del buscador, estilo el "sort/filter" de
    -- Plumber): aca solo se crea el widget; el OnClick se conecta mas abajo, una vez
    -- que existe la tabla `collapsed` (expande/colapsa TODOS los grupos de un tiron).
    local searchText = ""
    local RelayoutSidebar
    -- Buscador (2026-07-17, agrandado): fila propia, ancho casi completo del
    -- sidebar (antes compartia fila con "All" y quedaba muy chico/apretado).
    -- "All" bajo a su propia fila, a la derecha.
    local searchBox = CreateFrame("EditBox", nil, sidebar)
    searchBox:SetSize(118, 28)
    searchBox:SetPoint("TOPLEFT", 10, -6)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject("GameFontNormal")
    searchBox:SetTextInsets(22, 6, 0, 0)
    searchBox:SetTextColor(0.92, 0.86, 0.70)

    -- Los caps se dibujan un poco MAS ALTOS que la caja (28+6=34) y se solapan hacia adentro
    -- (offset -2/2) para que el borde del atlas (que es una pildora completa, no un marco fino)
    -- se recorte por los bordes de la caja en vez de aplastarse en una tira casi invisible.
    -- Vertex color mas fuerte (2026-07-16: el usuario pidio un borde mas visible/grande,
    -- comparando contra el buscador real de Plumber) para que el marco se note mas.
    local sbLeft = searchBox:CreateTexture(nil, "BACKGROUND")
    sbLeft:SetTexture(PLB); sbLeft:SetTexCoord(0 / 1024, 32 / 1024, 0 / 1024, 80 / 1024)
    sbLeft:SetSize(17, 34); sbLeft:SetPoint("LEFT", -3, 0)
    sbLeft:SetVertexColor(1.35, 1.2, 0.95)
    local sbRight = searchBox:CreateTexture(nil, "BACKGROUND")
    sbRight:SetTexture(PLB); sbRight:SetTexCoord(160 / 1024, 192 / 1024, 0 / 1024, 80 / 1024)
    sbRight:SetSize(17, 34); sbRight:SetPoint("RIGHT", 3, 0)
    sbRight:SetVertexColor(1.35, 1.2, 0.95)
    local sbMid = searchBox:CreateTexture(nil, "BACKGROUND")
    sbMid:SetTexture(PLB); sbMid:SetTexCoord(32 / 1024, 160 / 1024, 0 / 1024, 80 / 1024)
    sbMid:SetPoint("TOPLEFT", sbLeft, "TOPRIGHT", -3, 0); sbMid:SetPoint("BOTTOMRIGHT", sbRight, "BOTTOMLEFT", 3, 0)
    sbMid:SetVertexColor(1.35, 1.2, 0.95)

    local sbMag = searchBox:CreateTexture(nil, "OVERLAY")
    sbMag:SetTexture(PLB); sbMag:SetTexCoord(984 / 1024, 1024 / 1024, 0 / 1024, 40 / 1024)
    sbMag:SetSize(15, 15); sbMag:SetPoint("LEFT", 6, 0)
    sbMag:SetVertexColor(0.85, 0.78, 0.62)

    local searchHint = searchBox:CreateFontString(nil, "ARTWORK"); setFont(searchHint, 11)
    searchHint:SetPoint("LEFT", 22, 0); searchHint:SetTextColor(0.55, 0.5, 0.42); searchHint:SetText("Search...")

    local sortBtn = MakeButton(sidebar, "All", 40, 22)
    sortBtn:SetPoint("TOPRIGHT", -2, -40)
    local RelayoutGlobalNav   -- asignada mas abajo (bloque de la fila global Setup/Editing/...)
    searchBox:SetScript("OnTextChanged", function(self)
        searchText = self:GetText() or ""
        searchHint:SetShown(searchText == "")
        if RelayoutSidebar then RelayoutSidebar() end
        if RelayoutGlobalNav then RelayoutGlobalNav() end
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText(""); self:ClearFocus()
        if ns.CloseMainPanel then ns.CloseMainPanel() end
    end)
    searchBox:SetScript("OnEditFocusGained", function(self) sbMag:SetVertexColor(1, 0.9, 0.6) end)
    searchBox:SetScript("OnEditFocusLost", function(self) sbMag:SetVertexColor(0.6, 0.55, 0.45) end)

    -- Fila FIJA (no scrollea, pero SI filtra por busqueda via RelayoutGlobalNav mas
    -- abajo) con las 4 categorias globales Setup/Editing/Explorer/Profile — viven
    -- arriba de la lista de unidades, cada una llama ShowSection() en vez de
    -- SelectUnit(). MakeListItem con prominent=true (2026-07-17: el usuario las
    -- confundia con items de la lista de unidades de abajo — fuente mas grande,
    -- tinte siempre visible + fondo propio para separarlas).
    local globalNav = CreateFrame("Frame", nil, sidebar)
    globalNav:SetPoint("TOPLEFT", 2, -70)
    globalNav:SetPoint("TOPRIGHT", -2, -70)
    local navBg = globalNav:CreateTexture(nil, "BACKGROUND")
    navBg:SetPoint("TOPLEFT", -2, 2); navBg:SetPoint("BOTTOMRIGHT", 2, -2)
    navBg:SetColorTexture(COLOR_LINE[1], COLOR_LINE[2], COLOR_LINE[3], 0.12)
    local GLOBAL_NAV_ITEMS = {
        { key = "setup",    label = "Setup" },
        { key = "editing",  label = "Editing" },
        { key = "explorer", label = "Explorer" },
        { key = "presets",  label = "Profile" },
        { key = "extras",   label = "Extras" },
    }
    local navDiv = sidebar:CreateTexture(nil, "ARTWORK")
    navDiv:SetTexture(PL.DIV_H)
    navDiv:SetHeight(6)
    navDiv:SetVertexColor(COLOR_LINE[1], COLOR_LINE[2], COLOR_LINE[3], 0.4)

    for i, e in ipairs(GLOBAL_NAV_ITEMS) do
        local b = MakeListItem(globalNav, e.label, 118, 18, true)
        b:SetScript("OnClick", function() ShowSection(e.key) end)
        panelButtons[#panelButtons + 1] = b
        e.btn = b
        if e.key == "setup" then NAVBTN.setup = b
        elseif e.key == "editing" then NAVBTN.editing = b
        elseif e.key == "explorer" then NAVBTN.explorer = b
        elseif e.key == "presets" then NAVBTN.presets = b
        elseif e.key == "extras" then NAVBTN.extras = b end
    end

    -- Reposiciona/filtra los items globales por busqueda (2026-07-17: antes
    -- quedaban fuera del filtro; buscar "setup" no los ocultaba/mostraba como
    -- al resto de la sidebar). Sin busqueda entran todos siempre.
    RelayoutGlobalNav = function()
        local q = (searchText or ""):lower()
        local sy = -4
        local anyVisible = false
        for _, e in ipairs(GLOBAL_NAV_ITEMS) do
            if q == "" or e.label:lower():find(q, 1, true) then
                e.btn:ClearAllPoints(); e.btn:SetPoint("TOPLEFT", 6, sy); e.btn:Show()
                sy = sy - 25
                anyVisible = true
            else
                e.btn:Hide()
            end
        end
        globalNav:SetHeight(math.max(-sy + 4, 4))
        globalNav:SetShown(anyVisible)
        navBg:SetShown(anyVisible)
        navDiv:ClearAllPoints()
        navDiv:SetPoint("TOPLEFT", globalNav, "BOTTOMLEFT", 4, anyVisible and -2 or 0)
        navDiv:SetPoint("TOPRIGHT", globalNav, "BOTTOMRIGHT", -4, anyVisible and -2 or 0)
        navDiv:SetShown(anyVisible)
    end
    RelayoutGlobalNav()

    -- ScrollFrame + scrollbar CUSTOM (thumb arrastrable + flechas; texturas Plumber).
    -- value 0 = arriba (no invertido). La lista puede ser mas alta que el panel.
    local scroll = CreateFrame("ScrollFrame", nil, sidebar)
    scroll:SetPoint("TOPLEFT", globalNav, "BOTTOMLEFT", 0, -10)
    scroll:SetPoint("BOTTOMRIGHT", -14, 2)
    local sbChild = CreateFrame("Frame", nil, scroll)
    sbChild:SetSize(118, 10)
    scroll:SetScrollChild(sbChild)

    local BAR_W, ARROW = 10, 12
    local scrollValue, scrollRange = 0, 0

    local function TexBtn(y1, y2)
        local btn = CreateFrame("Button", nil, sidebar)
        btn:SetSize(ARROW, ARROW)
        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints(); tex:SetTexture(WIDGET); tex:SetTexCoord(0 / 512, 32 / 512, y1 / 512, y2 / 512)
        tex:SetVertexColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
        btn.tex = tex
        btn:SetScript("OnEnter", function() tex:SetVertexColor(1, 0.9, 0.45) end)
        btn:SetScript("OnLeave", function() tex:SetVertexColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3]) end)
        return btn
    end
    -- 2026-07-17: antes anclado a un offset FIJO desde arriba de la sidebar (-26),
    -- que asumia que la lista scrolleable empezaba justo debajo del buscador. Desde
    -- que se agrego el bloque fijo de las 4 categorias globales (Setup/Editing/...)
    -- la lista arranca mas abajo (y su altura varia con la busqueda) — se ancla
    -- directo a `scroll` (que ya seguia ese movimiento) en vez de un numero fijo,
    -- asi el scrollbar siempre arranca justo donde arranca la lista de unidades.
    local upBtn   = TexBtn(396, 428); upBtn:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 13, 2)
    local downBtn = TexBtn(428, 460); downBtn:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -1, 2)

    local track = CreateFrame("Frame", nil, sidebar)
    track:SetWidth(BAR_W)
    track:SetPoint("TOPRIGHT", upBtn, "BOTTOMRIGHT", 0, -2)
    track:SetPoint("BOTTOMRIGHT", downBtn, "TOPRIGHT", 0, 2)
    local rail = track:CreateTexture(nil, "BACKGROUND")
    rail:SetAllPoints(); rail:SetTexture(WIDGET)
    rail:SetTexCoord(0 / 512, 32 / 512, 0 / 512, 128 / 512)
    rail:SetVertexColor(COLOR_LINE[1], COLOR_LINE[2], COLOR_LINE[3], 0.4)

    local thumb = CreateFrame("Button", nil, track)
    thumb:SetPoint("TOP"); thumb:SetSize(BAR_W, 40)
    local tt = thumb:CreateTexture(nil, "ARTWORK")
    tt:SetAllPoints(); tt:SetTexture(WIDGET); tt:SetTexCoord(0 / 512, 32 / 512, 132 / 512, 260 / 512)
    tt:SetVertexColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])

    -- Scroll SUAVE (2026-07-17): `scrollValue` es el destino, `displayValue` es la
    -- posicion realmente dibujada — un OnUpdate la va acercando al destino en vez
    -- de saltar de golpe (rueda del mouse / flechas). Arrastrando el thumb SI es
    -- 1:1 inmediato (instant=true), un lag ahi se siente mal.
    local displayValue = 0
    local function PositionThumb()
        local usable = math.max((track:GetHeight() or 1) - (thumb:GetHeight() or 1), 0)
        local frac = (scrollRange > 0) and (displayValue / scrollRange) or 0
        thumb:ClearAllPoints(); thumb:SetPoint("TOP", track, "TOP", 0, -frac * usable)
    end
    local function ApplyScroll(v, instant)
        scrollValue = math.min(math.max(v or 0, 0), scrollRange)
        if instant then
            displayValue = scrollValue
            scroll:SetVerticalScroll(displayValue)
            PositionThumb()
        end
    end
    scroll:SetScript("OnUpdate", function(self, elapsed)
        if displayValue == scrollValue then return end
        local diff = scrollValue - displayValue
        if math.abs(diff) < 0.5 then
            displayValue = scrollValue
        else
            displayValue = displayValue + diff * math.min(elapsed * 14, 1)
        end
        scroll:SetVerticalScroll(displayValue)
        PositionThumb()
    end)

    upBtn:SetScript("OnClick",   function() ApplyScroll(scrollValue - 30) end)
    downBtn:SetScript("OnClick", function() ApplyScroll(scrollValue + 30) end)

    thumb:SetScript("OnMouseDown", function(self)
        self.dragging = true; self.startY = select(2, GetCursorPosition()); self.startV = scrollValue
        tt:SetVertexColor(1, 0.9, 0.5)
    end)
    thumb:SetScript("OnMouseUp", function(self) self.dragging = false; tt:SetVertexColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3]) end)
    thumb:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        if not IsMouseButtonDown("LeftButton") then self.dragging = false; tt:SetVertexColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3]); return end
        local _, y = GetCursorPosition()
        local usable = math.max((track:GetHeight() or 1) - (thumb:GetHeight() or 1), 1)
        local dy = (self.startY - y) / (track:GetEffectiveScale() or 1)
        ApplyScroll(self.startV + (dy / usable) * scrollRange, true)
    end)

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta) ApplyScroll(scrollValue - delta * 30) end)

    local function updateScroll()
        local content, visible = sbChild:GetHeight() or 1, scroll:GetHeight() or 1
        scrollRange = math.max(content - visible, 0)
        local scrollable = scrollRange > 1
        track:SetShown(scrollable); upBtn:SetShown(scrollable); downBtn:SetShown(scrollable)
        local trackH = track:GetHeight() or 1
        thumb:SetSize(BAR_W, math.max(24, trackH * math.min(visible / math.max(content, 1), 1)))
        ApplyScroll(scrollValue, true)
    end
    scroll:SetScript("OnSizeChanged", updateScroll)

    -- Grupos COLAPSABLES: header (boton con flecha) + botones. Se crean UNA vez y
    -- RelayoutSidebar los reubica/oculta segun colapso + busqueda (sin recrear frames).
    local collapsed = {}
    local sideHeaders = {}

    -- sortBtn (creado antes, junto al buscador): expande/colapsa TODOS los grupos
    -- de un tiron. Analogo funcional al boton "sort/filter" de Plumber (icono T que
    -- abre un popup) — aca no aplica un "sort by" real (nuestras categorias no
    -- tienen fecha), asi que se reutiliza el espacio para algo util: colapsar todo.
    local allCollapsed = false
    sortBtn:SetScript("OnClick", function()
        allCollapsed = not allCollapsed
        for _, grp in ipairs(UNIT_GROUPS) do collapsed[grp.title] = allCollapsed end
        if RelayoutSidebar then RelayoutSidebar() end
    end)
    sortBtn:HookScript("OnEnter", function()
        if GameTooltip:IsForbidden() then return end
        GameTooltip:SetOwner(sortBtn, "ANCHOR_LEFT")
        GameTooltip:SetText("Expand / collapse all groups", 1, 1, 1)
        GameTooltip:Show()
    end)
    sortBtn:HookScript("OnLeave", function() if not GameTooltip:IsForbidden() then GameTooltip:Hide() end end)

    local function MakeCollapseHeader(grp)
        local h = CreateFrame("Button", nil, sbChild)
        h:SetSize(112, 15)
        -- COLOR_GROUP (dorado-ambar vivo): SOLO estos headers de grupo de la
        -- sidebar (MAIN/POWER/BOSSES/...), no el resto del panel.
        local arrow = h:CreateFontString(nil, "ARTWORK"); setFont(arrow, 10)
        arrow:SetPoint("LEFT", 0, 0); arrow:SetTextColor(COLOR_GROUP[1], COLOR_GROUP[2], COLOR_GROUP[3])
        h.arrow = arrow
        local fs = h:CreateFontString(nil, "ARTWORK"); setFont(fs, 10)
        fs:SetPoint("LEFT", 11, 0); fs:SetTextColor(COLOR_GROUP[1], COLOR_GROUP[2], COLOR_GROUP[3]); fs:SetText(grp.title)
        h.fs = fs
        h:SetScript("OnEnter", function() fs:SetTextColor(1, 0.9, 0.45); arrow:SetTextColor(1, 0.9, 0.45) end)
        h:SetScript("OnLeave", function()
            fs:SetTextColor(COLOR_GROUP[1], COLOR_GROUP[2], COLOR_GROUP[3])
            arrow:SetTextColor(COLOR_GROUP[1], COLOR_GROUP[2], COLOR_GROUP[3])
        end)
        h:SetScript("OnClick", function()
            collapsed[grp.title] = not collapsed[grp.title]
            RelayoutSidebar()
        end)
        return h
    end

    for _, grp in ipairs(UNIT_GROUPS) do
        sideHeaders[grp.title] = MakeCollapseHeader(grp)
        for _, key in ipairs(grp.keys) do
            local b = MakeListItem(sbChild, LABELS[key] or key, 104, 18)
            b:SetScript("OnClick", function() SelectUnit(key) end)
            unitTabs[key] = b
        end
    end

    function RelayoutSidebar()
        local q = (searchText or ""):lower()
        local sy = -6
        for _, grp in ipairs(UNIT_GROUPS) do
            local h = sideHeaders[grp.title]
            local titleMatch = q ~= "" and grp.title:lower():find(q, 1, true)
            -- Que botones coinciden con la busqueda.
            local visible = {}
            for _, key in ipairs(grp.keys) do
                if q == "" or titleMatch or (LABELS[key] or key):lower():find(q, 1, true) then
                    visible[key] = true
                end
            end
            local anyVisible = false
            for _ in pairs(visible) do anyVisible = true break end
            if not anyVisible then
                h:Hide()
                for _, key in ipairs(grp.keys) do unitTabs[key]:Hide() end
            else
                -- Con busqueda activa se fuerza expandido.
                local isCollapsed = collapsed[grp.title] and q == ""
                h:ClearAllPoints(); h:SetPoint("TOPLEFT", 8, sy); h:Show()
                h.arrow:SetText(isCollapsed and "+" or "-")
                sy = sy - 17
                for _, key in ipairs(grp.keys) do
                    local b = unitTabs[key]
                    if visible[key] and not isCollapsed then
                        b:ClearAllPoints(); b:SetPoint("TOPLEFT", 8, sy); b:Show()
                        sy = sy - 19
                    else
                        b:Hide()
                    end
                end
                sy = sy - 6
            end
        end
        sbChild:SetHeight(math.max(-sy + 6, 10))
        updateScroll()
    end

    RelayoutSidebar()

    -- Divisor vertical sidebar / contenido.
    local vdiv = panel:CreateTexture(nil, "ARTWORK")
    vdiv:SetTexture(PL.DIV_V)
    vdiv:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 2, 10)
    vdiv:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", 2, -10)
    vdiv:SetWidth(16); vdiv:SetVertexColor(1, 1, 1, 0.35)

    -- ===== PREVIEW (3ra columna, estilo Plumber: descripcion de la categoria activa) =====
    local preview = CreateFrame("Frame", nil, panel)
    preview:SetPoint("TOPRIGHT", -12, -42)
    preview:SetPoint("BOTTOMRIGHT", -12, 44)
    preview:SetWidth(PREVIEW_W)
    local pvBg = preview:CreateTexture(nil, "BACKGROUND")
    pvBg:SetAllPoints(); pvBg:SetColorTexture(0, 0, 0, 0.16)

    local pvdiv = panel:CreateTexture(nil, "ARTWORK")
    pvdiv:SetTexture(PL.DIV_V)
    pvdiv:SetPoint("TOPLEFT", preview, "TOPRIGHT", -18, 10)
    pvdiv:SetPoint("BOTTOMLEFT", preview, "BOTTOMRIGHT", -18, -10)
    pvdiv:SetWidth(16); pvdiv:SetVertexColor(1, 1, 1, 0.35)

    -- Icono decorativo (2026-07-17): Plumber muestra una imagen/preview arriba del
    -- texto; no hay arte por-categoria disponible, asi que se usa el icono del addon
    -- como acento visual generico en vez de dejar el panel puramente texto plano.
    local pvIcon = preview:CreateTexture(nil, "ARTWORK")
    pvIcon:SetTexture("Interface\\AddOns\\MyCustomFrames\\Assets\\addon_icon.tga")
    pvIcon:SetSize(40, 40)
    pvIcon:SetPoint("TOP", 0, -12)
    pvIcon:SetVertexColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])

    local pvTitle = preview:CreateFontString(nil, "ARTWORK")
    setFont(pvTitle, 14)
    pvTitle:SetPoint("TOP", pvIcon, "BOTTOM", 0, -8)
    pvTitle:SetPoint("LEFT", 10, 0)
    pvTitle:SetPoint("RIGHT", -10, 0)
    pvTitle:SetJustifyH("CENTER"); pvTitle:SetWordWrap(true)
    pvTitle:SetTextColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])

    -- Lista de bullets (2026-07-17: el usuario pidio que las descripciones se vean
    -- organizadas en puntos, con un cuadradito antes de cada uno — calcando el estilo
    -- del changelog real de Plumber). Pool reutilizable, UpdatePreview la rearma.
    local pvBullets = {}
    local function GetBullet(i)
        local b = pvBullets[i]
        if not b then
            local dot = preview:CreateTexture(nil, "ARTWORK")
            dot:SetColorTexture(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
            dot:SetSize(5, 5)
            local fs = preview:CreateFontString(nil, "ARTWORK")
            setFont(fs, 11)
            fs:SetJustifyH("LEFT"); fs:SetWordWrap(true)
            fs:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
            b = { dot = dot, fs = fs }
            pvBullets[i] = b
        end
        return b
    end

    -- Descripcion corta por familia de seccion (arrays = puntos separados con
    -- bullet). Se resuelve por prefijo de key (mismo criterio que
    -- IsPortraitSection/IsAuraSection/etc, definidas mas arriba).
    local FAMILY_DESC = {
        { test = function(k) return IsPortraitSection(k) end, title = "Portraits", desc = {
            "Portrait: frame, 3D model or icon.", "Badges and raid role/target marker." } },
        { test = function(k) return IsAuraSection(k) end, title = "Auras", desc = {
            "Grid, position and border of the group.", "Death/no-target icons and text." } },
        { test = function(k) return IsInfoSection(k) end, title = "Info Bar", desc = {
            "Visible elements and their position.", "Text and background of the bar." } },
        { test = function(k) return IsMicroSection(k) end, title = "Micro Menu", desc = {
            "Reskin of Blizzard's micro buttons.", "Movable and scalable." } },
        { test = function(k) return IsChatSection(k) end, title = "Chat Bubble", desc = {
            "Background of world chat bubbles.", "Font and text color." } },
        { test = function(k) return IsTrackerSection(k) end, title = "Quest Tracker", desc = {
            "Colors of the quest tracker.", "Auto-hide in combat/instances." } },
        { test = function(k) return IsGlowSection(k) end, title = "Assisted Glow", desc = {
            "Assisted highlight for available abilities." } },
        { test = function(k) return IsPartyAuraSection(k) end, title = "Party Auras", desc = {
            "Auras for Party1-5.", "Revealed on hover or in combat." } },
        { test = function(k) return IsArenaAuraSection(k) end, title = "Arena Auras", desc = {
            "Auras for the 6 arena frames.", "Revealed on hover or in combat, arena-only." } },
        { test = function(k) return IsMinimapSection(k) end, title = "Minimap", desc = {
            "Round custom skin around the native map.", "Compass, coordinates, LFG eye, XP/Rep ring." } },
        { test = function(k) return IsNameplatesSection(k) end, title = "Nameplates", desc = {
            "Reskin of Blizzard's native nameplates.", "Size/offsets via the Nameplate Designer (drag + wheel)." } },
        { test = function(k) return IsClassPowerSection(k) end, title = "Class Power", desc = {
            "Combo Points/Holy Power/Chi/Soul Shards/Arcane Charges/Essence/Runes/Soul Fragments/Maelstrom Weapon.",
            "Movable and scalable in Lock, even without an active class resource." } },
        { test = function(k) return IsRaidSection(k) end, title = "Raid Frames", desc = {
            "Up to 40 players, AzeriteUI look. Shows in raid groups and battlegrounds only.",
            "Growth direction, spacing, and icon position/size are configurable — the rest of the look is fixed by design." } },
        { test = function(k) return k == "presets" end, title = "Profiles", desc = {
            "Save and load full profiles.", "Export and import across accounts." } },
        { test = function(k) return k == "explorer" end, title = "Explorer", desc = {
            "Auto-hide UI elements.", "Revealed on mouseover." } },
        { test = function(k) return k == "editing" end, title = "Editing", desc = {
            "Grid, snap and layout preview.", "Lock mode to move elements." } },
        { test = function(k) return k == "setup" end, title = "Setup", desc = {
            "Integration with other addons.", "Bundled profiles ready to apply." } },
        { test = function(k) return k == "extras" end, title = "Extras", desc = {
            "Tooltip skin and Mirror Timers (breath/rested/feign death).", "Global, not per-unit." } },
    }
    -- Pedido del usuario 2026-07-19 ("me gustaria que sea PER UNIDAD... si
    -- estoy en tot me resuma lo que puedo hacer ahi"): antes esto era una UNICA
    -- descripcion generica ("Unit Frames") para CUALQUIER unidad normal
    -- (player/target/ToT/pet/focus/boss/party/arena/power), sin importar cual
    -- estuviera editando. Ahora resume lo especifico de CADA unidad -- las
    -- familias especiales (portraits/auras/tracker/etc, ver FAMILY_DESC arriba)
    -- siguen igual, esto solo reemplaza el fallback generico del final.
    local function GetUnitDescription(key)
        local u = ns.frames[key]
        local label = (u and u.label) or key
        if key == "playerpower" or key == "targetpower" then
            return label, { "Power bar only.", "No name, spell, cast or highlight tabs." }
        end
        if key:sub(1, 4) == "boss" then
            return label, { "Boss encounter frame, fixed color.", "Shows automatically during boss fights." }
        end
        if key == "targettarget" then
            return label, { "Target-of-target — small frame under Target.", "Shows what your current target is looking at." }
        end
        if key == "pet" then
            return label, { "Pet frame — auto-hides without an active pet.", "Bar, cage, highlight and health, like the rest." }
        end
        if key == "focus" then
            return label, { "Focus frame — set/clear focus via UI or macro.", "Bar, cage, highlight and health, like the rest." }
        end
        if key == "party5" then
            return label, { "5th party slot — shows YOUR OWN frame.", "Visible whenever you're in any group (party or raid)." }
        end
        if key:sub(1, 5) == "party" then
            return label, { "Party member — visible only in a 5-man group.", "Hidden in raids, arenas and battlegrounds." }
        end
        if key == "arena_player" or key == "arena_party1" or key == "arena_party2" then
            return label, { "Arena ally — visible ONLY in an arena match.", "Independent copy, doesn't affect your normal frames." }
        end
        if key:sub(1, 11) == "arena_enemy" then
            return label, { "Arena enemy — visible ONLY in an arena match.", "Also has a PvP Trinket icon (see Trinket tab)." }
        end
        return label, { "Bar, cage, highlight and health.", "Name, spell, cast bar and colors." }
    end
    local function GetFamilyDescription(key)
        for _, f in ipairs(FAMILY_DESC) do
            if f.test(key) then return f.title, f.desc end
        end
        return GetUnitDescription(ns.currentEdit)
    end
    UpdatePreview = function()
        local t, d = GetFamilyDescription(currentSection)
        pvTitle:SetText(t)
        local anchor = pvTitle
        for i, line in ipairs(d) do
            local b = GetBullet(i)
            b.dot:ClearAllPoints()
            b.dot:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, (i == 1) and -12 or -10)
            b.fs:ClearAllPoints()
            b.fs:SetPoint("TOPLEFT", b.dot, "TOPRIGHT", 6, 2)
            b.fs:SetPoint("RIGHT", preview, "RIGHT", -10, 0)
            b.fs:SetText(line)
            b.dot:Show(); b.fs:Show()
            anchor = b.fs
        end
        for i = #d + 1, #pvBullets do
            pvBullets[i].dot:Hide(); pvBullets[i].fs:Hide()
        end
    end
    UpdatePreview()

    -- ===== CONTENIDO =====
    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 22, 0)
    content:SetPoint("BOTTOMRIGHT", preview, "BOTTOMLEFT", -10, 0)
    panel._content = content   -- para el nudge de relayout en ApplyPanelView

    unitTitle = content:CreateFontString(nil, "ARTWORK")
    setFont(unitTitle, 14)
    unitTitle:SetPoint("TOPLEFT", 4, -2)
    unitTitle:SetTextColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])

    -- 2026-07-17: Copy/Paste movidos aca (esquina superior derecha del contenido)
    -- desde el footer — el usuario los queria a mano cerca del titulo de la
    -- unidad, visibles SOLO al editar una unidad/portrait/etc (no en las
    -- secciones globales Setup/Editing/Explorer/Profile). ShowSection() los
    -- oculta/muestra igual que hace con sectionTabs para esas secciones.
    unitPasteBtn = MakeTabButton(content, "Paste", 60, 20, true)
    unitPasteBtn:SetPoint("TOPRIGHT", 0, -3)
    unitPasteBtn:SetScript("OnClick", ns.PasteSettings)
    unitCopyBtn = MakeTabButton(content, "Copy", 60, 20, true)
    unitCopyBtn:SetPoint("RIGHT", unitPasteBtn, "LEFT", -4, 0)
    unitCopyBtn:SetScript("OnClick", ns.CopySettings)

    -- 2026-07-17: las filas de sub-tabs se armaban con posiciones fijas por indice
    -- (2 + (i-1)*48), asumiendo que TODOS los labels entraban en ese ancho — labels
    -- largos (Border/Death/Mark/Role) se salian de la pildora Y se superponian con
    -- el panel de preview de la derecha. Ahora viven dentro de un ScrollFrame
    -- HORIZONTAL propio (tabScroll/tabRow), clippeado al ancho de `content`, con
    -- rueda del mouse + una barrita fina arrastrable debajo.
    local tabScroll = CreateFrame("ScrollFrame", nil, content)
    tabScroll:SetPoint("TOPLEFT", 0, -34)
    tabScroll:SetPoint("TOPRIGHT", 0, -34)
    tabScroll:SetHeight(20)
    tabScroll:EnableMouseWheel(true)
    local tabRow = CreateFrame("Frame", nil, tabScroll)
    tabRow:SetSize(10, 20)
    tabScroll:SetScrollChild(tabRow)
    local tabRowWidth = 0
    local tabScrollX = 0

    -- 2026-07-17: usaba SetColorTexture (rectangulos solidos lisos) en vez del
    -- mismo atlas WIDGET que usa el scrollbar VERTICAL de la sidebar (rail/thumb
    -- con textura), por eso no hacian juego. Coords UV rotadas 90 grados a mano
    -- (8-arg SetTexCoord, sin SetRotation) para que el patron vertical del atlas
    -- se estire en el eje correcto en vez de deformarse.
    local hbTrack = content:CreateTexture(nil, "ARTWORK")
    hbTrack:SetPoint("TOPLEFT", tabScroll, "BOTTOMLEFT", 0, -2)
    hbTrack:SetPoint("TOPRIGHT", tabScroll, "BOTTOMRIGHT", 0, -2)
    hbTrack:SetHeight(3)
    hbTrack:SetTexture(WIDGET)
    hbTrack:SetTexCoord(0 / 512, 0 / 512, 0 / 512, 128 / 512, 32 / 512, 128 / 512, 32 / 512, 0 / 512)
    hbTrack:SetVertexColor(COLOR_LINE[1], COLOR_LINE[2], COLOR_LINE[3], 0.4)
    local hbThumb = content:CreateTexture(nil, "OVERLAY")
    hbThumb:SetHeight(3)
    hbThumb:SetTexture(WIDGET)
    hbThumb:SetTexCoord(0 / 512, 132 / 512, 0 / 512, 260 / 512, 32 / 512, 260 / 512, 32 / 512, 132 / 512)
    hbThumb:SetVertexColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3], 0.9)

    local function UpdateHScroll()
        local visibleW = tabScroll:GetWidth() or 1
        local maxX = math.max(tabRowWidth - visibleW, 0)
        tabScrollX = math.min(math.max(tabScrollX, 0), maxX)
        tabScroll:SetHorizontalScroll(tabScrollX)
        local scrollable = maxX > 1
        hbTrack:SetShown(scrollable)
        hbThumb:SetShown(scrollable)
        if scrollable then
            local frac = visibleW / math.max(tabRowWidth, 1)
            local thumbW = math.max(20, visibleW * frac)
            hbThumb:ClearAllPoints()
            hbThumb:SetPoint("LEFT", hbTrack, "LEFT", (tabScrollX / maxX) * (visibleW - thumbW), 0)
            hbThumb:SetWidth(thumbW)
        end
    end
    tabScroll:SetScript("OnMouseWheel", function(self, delta)
        tabScrollX = tabScrollX - delta * 40
        UpdateHScroll()
    end)
    tabScroll:SetScript("OnSizeChanged", UpdateHScroll)
    tabScrollUI.frame, tabScrollUI.track, tabScrollUI.thumb = tabScroll, hbTrack, hbThumb

    local function BuildTabRow(list, minW, hiddenByDefault)
        local prevBtn
        for _, s in ipairs(list) do
            local b = MakeTabButton(tabRow, s.label, minW, 20)
            if prevBtn then b:SetPoint("TOPLEFT", prevBtn, "TOPRIGHT", 2, 0)
            else b:SetPoint("TOPLEFT", 0, 0) end
            b:SetScript("OnClick", function() ShowSection(s.key) end)
            if hiddenByDefault then b:Hide() end
            sectionTabs[s.key] = b
            prevBtn = b
        end
        if prevBtn then
            local right = (prevBtn:GetRight() or 0) - (tabRow:GetLeft() or 0)
            tabRowWidth = math.max(tabRowWidth, right)
        end
    end

    -- Pestanas de SECCION.
    local secList = {
        { key = "general", label = "Gen" },
        { key = "bar",     label = "Bar" },
        { key = "cage",    label = "Cage" },
        { key = "highlight", label = "Sel" },
        { key = "health",  label = "Health" },
        { key = "name",    label = "Name" },
        { key = "spell",   label = "Spell" },
        { key = "cast",    label = "Cast" },
        { key = "colors",  label = "Color" },
        -- Trinket de PvP (pedido del usuario 2026-07-19) -- pestaña visible
        -- SOLO para arena_enemy1/2/3 (ver SelectUnit, filtro por key:sub(1,11)).
        { key = "trinket", label = "Trinket" },
    }
    BuildTabRow(secList, 40, false)

    -- Pestanas de SECCION para portraits (misma fila; ocultas hasta seleccionar un portrait).
    local portSecList = {
        { key = "p_general", label = "Gen" },
        { key = "p_pos",     label = "Pos" },
        { key = "p_bg",      label = "Bg" },
        { key = "p_model",   label = "Image" },
        { key = "p_cage",    label = "Border" },
        { key = "p_rest",    label = "Rest" },
        { key = "p_death",   label = "Death" },
        { key = "p_badges",  label = "Badge" },
        { key = "p_raid",    label = "Mark" },
        { key = "p_role",    label = "Role" },
    }
    BuildTabRow(portSecList, 34, true)

    -- Pestanas de SECCION para auras (misma fila; ocultas hasta seleccionar un grupo).
    local auraSecList = {
        { key = "a_general", label = "Gen" },
        { key = "a_grid",    label = "Grid" },
        { key = "a_pos",     label = "Pos" },
        { key = "a_dead",    label = "Death" },
        { key = "a_style",   label = "Border" },
        { key = "a_text",    label = "Text" },
    }
    BuildTabRow(auraSecList, 40, true)

    -- Pestanas de SECCION para el info bar (ocultas hasta seleccionar Info Bar).
    local infoSecList = {
        { key = "i_general",  label = "Gen" },
        { key = "i_pos",      label = "Pos" },
        { key = "i_elements", label = "Elem" },
        { key = "i_text",     label = "Text" },
        { key = "i_bg",       label = "Bg" },
    }
    BuildTabRow(infoSecList, 40, true)

    -- Pestanas de SECCION para el micro menu.
    local microSecList = { { key = "mm_general", label = "Gen" } }
    BuildTabRow(microSecList, 40, true)

    -- Pestanas de SECCION para el chat bubble.
    local chatSecList = { { key = "cb_general", label = "Gen" } }
    BuildTabRow(chatSecList, 40, true)

    -- Pestanas de SECCION para el quest tracker.
    local trackerSecList = { { key = "t_general", label = "Gen" } }
    BuildTabRow(trackerSecList, 40, true)

    -- Pestanas de SECCION para el assisted glow.
    local glowSecList = { { key = "g_general", label = "Gen" } }
    BuildTabRow(glowSecList, 40, true)

    -- Pestanas de SECCION para el Minimap (singleton).
    local minimapSecList = {
        { key = "mn_general",  label = "Gen" },
        { key = "mn_display",  label = "Display" },
        { key = "mn_icons",    label = "Icons" },
        { key = "mn_textures", label = "Textures" },
    }
    BuildTabRow(minimapSecList, 40, true)

    -- Pestanas de SECCION para Raid Frames (singleton). SIN pestaña "Style":
    -- pedido explicito del usuario (2026-07-20) -- la apariencia (texturas/
    -- colores/tamaños de barra) es 100% codigo (Raid.lua, ns.ForceRaidStyle),
    -- el menu solo controla comportamiento/layout/posicion.
    local raidSecList = {
        { key = "r_general", label = "Gen" },
        { key = "r_layout",  label = "Layout" },
        { key = "r_pos",     label = "Pos" },
        { key = "r_icons",   label = "Icons" },
    }
    BuildTabRow(raidSecList, 40, true)

    -- Pestanas de SECCION para Nameplates -- 2do tab "Alpha" agregado
    -- 2026-07-19 (pedido del usuario, 5 controles de alpha nuevos): el panel
    -- NO tiene scroll (content:SetPoint BOTTOMRIGHT contra preview, corte
    -- duro en el borde) -- meterlos todos en "Gen" empujaba "Name-only mode"
    -- y sus offsets fuera de la ventana. Pestaña propia = espacio de sobra
    -- para cada grupo, sin apretar pixeles.
    local nameplatesSecList = { { key = "np_general", label = "Gen" }, { key = "np_alpha", label = "Alpha" } }
    BuildTabRow(nameplatesSecList, 40, true)

    -- Pestanas de SECCION para Party Auras (singleton, 1 sola pestaña "Gen" — igual patron que
    -- Tracker/Glow arriba).
    local partyAuraSecList = { { key = "ap_general", label = "Gen" } }
    BuildTabRow(partyAuraSecList, 40, true)

    -- Pestanas de SECCION para Arena Auras (singleton, mismo patron que Party Auras --
    -- pedido del usuario 2026-07-19: "todas esta auras esten en una casilla juntas de arena").
    local arenaAuraSecList = { { key = "aa_general", label = "Gen" } }
    BuildTabRow(arenaAuraSecList, 40, true)

    -- Pestanas de SECCION para Class Power (singleton, 1 sola pestaña "Gen" -- igual patron
    -- que Party Auras/Nameplates arriba).
    local classPowerSecList = { { key = "cp_general", label = "Gen" } }
    BuildTabRow(classPowerSecList, 40, true)

    tabRow:SetWidth(math.max(tabRowWidth, 10))
    UpdateHScroll()
    -- Cuando cambia de unidad/familia (otro grupo de sub-tabs, otro ancho total)
    -- hay que resetear el scroll horizontal, si no algunas filas mas angostas
    -- podrian quedar "cortadas" con un scroll heredado de la fila anterior.
    ns.ResetTabRowScroll = function() tabScrollX = 0; UpdateHScroll() end

    -- Divisor horizontal (Plumber) separando la fila de pestanas del contenido.
    -- 2026-07-17 (ronda 2): movida de DEBAJO a ENCIMA de la fila de sub-tabs
    -- (entre el titulo "Editing: X" y "Gen/Bar/Cage/..."), separandola del
    -- titulo en vez de flotar sin nada arriba.
    local tdiv = content:CreateTexture(nil, "ARTWORK")
    tdiv:SetTexture(PL.DIV_H)
    tdiv:SetPoint("TOPLEFT", 0, -25); tdiv:SetPoint("TOPRIGHT", 0, -25)
    tdiv:SetHeight(6); tdiv:SetVertexColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3], 0.7)

    -- Area de controles de la seccion activa. (2026-07-17: bajada de -54 a -70,
    -- el usuario la queria mas separada de la fila de pestañas Gen/Bar/Cage/...)
    local secArea = CreateFrame("Frame", nil, content)
    secArea:SetPoint("TOPLEFT", 0, -70)
    secArea:SetPoint("BOTTOMRIGHT", 0, 0)

    local cdiv = secArea:CreateTexture(nil, "ARTWORK")
    cdiv:SetTexture(PL.DIV_V)
    cdiv:SetPoint("TOP", secArea, "TOPLEFT", 220, -2)
    cdiv:SetHeight(330); cdiv:SetWidth(14); cdiv:SetVertexColor(1, 1, 1, 0.22)

    local function Section(key)
        local f = CreateFrame("Frame", nil, secArea)
        f:SetAllPoints(secArea)
        sections[key] = f
        return f
    end
    local L, R = 6, 232

    -- General
    do
        local f = Section("general")
        MakeHeader(f, "Anchor & position", L, -6, 210)
        MakeEditBox(f, "Anchor to (frame; empty = screen)", "anchorFrame", L, -32)
        MakeCycle(f, "Strata", ns.STRATA_VALUES, "strata", L, -74)
        MakeCycle(f, "Point (bar)", ns.POINT_VALUES, "point", L, -104)
        MakeCycle(f, "Point (target)", ns.POINT_VALUES, "relativePoint", L, -134)
        MakeSlider(f, "Scale (wheel in Lock too)", 0.3, 3, 0.02, "scale", L, -178)
        local resetBtn = MakeButton(f, "Reset this unit", 200, 22)
        resetBtn:SetPoint("TOPLEFT", L, -226)
        resetBtn:SetScript("OnClick", function() ns.ResetUnit(ns.currentEdit) end)

        MakeHeader(f, "Position offset", R, -6, 210)
        MakeSlider(f, "Offset X", -2000, 2000, 1, "offsetX", R, -48)
        MakeSlider(f, "Offset Y", -2000, 2000, 1, "offsetY", R, -90)

        MakeHeader(f, "Behavior", R, -132, 210)
        MakeCheckbox(f, "Hide when mounted", "hideWhenMounted", R, -156)
        HIDEGRP.powerHidden[#HIDEGRP.powerHidden + 1] = MakeCheckbox(f, "Show tooltip", "showTooltip", R, -182)
    end
    -- Barra: reorganizada en grupos con header (2026-07-17) — antes era una
    -- columna larga de sliders sin agrupar, dificil de escanear. Ahora:
    -- izquierda = Texture & size + Secure click area; derecha = Appearance +
    -- Edit outline. Mismo patron MakeHeader que ya usan el resto de las secciones.
    do
        local f = Section("bar")

        -- NOTA: MakeSlider ancla su label FLOTANDO arriba del punto Y (BOTTOMLEFT
        -- del label = TOPLEFT del slider + 3px), no en el propio Y -> un header
        -- seguido de un slider necesita ~42px de hueco (no ~24) para no pisarse;
        -- header seguido de checkbox/texture-picker (label sin flotar) si funciona
        -- con ~26-30px.
        MakeHeader(f, "Texture & size", L, -6, 210)
        MakeTexturePicker(f, "Texture (empty = none)", "texture", "bar", L, -32)
        MakeSlider(f, "Width", 10, 1000, 1, "width", L, -88)
        MakeSlider(f, "Height", 2, 300, 1, "height", L, -130)

        MakeHeader(f, "Secure click area", L, -174, 210)
        MakeSlider(f, "Click width (0 = bar)", 0, 1200, 1, "btnWidth", L, -216)
        MakeSlider(f, "Click height (0 = bar)", 0, 400, 1, "btnHeight", L, -258)
        MakeSlider(f, "Click offset X", -400, 400, 1, "btnOffsetX", L, -300)
        MakeSlider(f, "Click offset Y", -400, 400, 1, "btnOffsetY", L, -342)
        local cnote = f:CreateFontString(nil, "ARTWORK"); setFont(cnote, 10)
        cnote:SetPoint("TOPLEFT", L, -388); cnote:SetWidth(210); cnote:SetJustifyH("LEFT")
        cnote:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        cnote:SetText("Click = the secure button (right-click menu / targeting). 0 follows the bar size. Applies when preview is OFF.")

        MakeHeader(f, "Appearance", R, -6, 210)
        MakeSlider(f, "Bar opacity", 0, 1, 0.05, "barAlpha", R, -48)
        MakeSlider(f, "Background opacity", 0, 1, 0.05, "bgAlpha", R, -90)
        MakeCheckbox(f, "Show background", "showBackground", R, -132)
        MakeCheckbox(f, "Smooth progress", "smooth", R, -158)
        MakeCheckbox(f, "Reverse fill (right -> left)", "reverseFill", R, -184)

        -- B4: outline de edicion propio por unidad (W/H, 0 = seguir al frame) + ocultar nombre.
        MakeHeader(f, "Edit outline", R, -224, 210)
        MakeSlider(f, "Outline width (0 = frame)", 0, 1200, 1, "outlineW", R, -266)
        MakeSlider(f, "Outline height (0 = frame)", 0, 400, 1, "outlineH", R, -308)
        MakeCheckbox(f, "Hide outline name", "outlineHideName", R, -350)
    end
    -- Cage
    do
        local f = Section("cage")
        MakeHeader(f, "Texture & size", L, -6, 210)
        MakeTexturePicker(f, "Cage texture (empty = none)", "cageTexture", "cage", L, -32)
        MakeSlider(f, "Cage width", 2, 1200, 1, "cageWidth", L, -86)
        MakeSlider(f, "Cage height", 2, 400, 1, "cageHeight", L, -128)

        MakeHeader(f, "Behavior", L, -172, 210)
        MakeCheckbox(f, "Hide cage when the unit dies", "cageHideDead", L, -196)

        MakeHeader(f, "Position & opacity", R, -6, 210)
        MakeSlider(f, "Offset X", -400, 400, 1, "cageOffsetX", R, -48)
        MakeSlider(f, "Offset Y", -400, 400, 1, "cageOffsetY", R, -90)
        MakeSlider(f, "Cage opacity", 0, 1, 0.05, "cageAlpha", R, -132)
    end
    -- Highlight de unidad seleccionada (target)
    do
        local f = Section("highlight")
        MakeHeader(f, "Highlight", L, -6, 210)
        MakeCheckbox(f, "Highlight when it's my target", "showHighlight", L, -30)
        MakeTexturePicker(f, "Highlight texture", "highlightTexture", "highlight", L, -62)
        MakeSlider(f, "Width", 2, 1200, 1, "highlightWidth", L, -116)
        MakeSlider(f, "Height", 2, 400, 1, "highlightHeight", L, -158)
        MakeSlider(f, "Scale", 0.2, 3, 0.02, "highlightScale", L, -200)

        MakeHeader(f, "Position & style", R, -6, 210)
        MakeSlider(f, "Offset X", -400, 400, 1, "highlightOffsetX", R, -48)
        MakeSlider(f, "Offset Y", -400, 400, 1, "highlightOffsetY", R, -90)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "highlightAlpha", R, -132)
        MakeColorButton(f, "Color", "highlightColor", R, -162)
        MakeCheckbox(f, "Glow (pulse)", "highlightGlow", R, -198)
    end
    -- Trinket de PvP (pedido del usuario 2026-07-19, SOLO Arena Enemy 1/2/3) --
    -- deliberadamente MINIMO: "permitir UNICAMENTE opciones visuales: mostrar/
    -- ocultar, posicion, tamaño. No añadir funciones propias de addons PvP
    -- avanzados (DR tracker, etc)". Usa getP()/OnEdit genericos como el resto
    -- de las pestañas por-unidad (no es singleton, cada Arena Enemy tiene su
    -- propio icono independiente).
    do
        local f = Section("trinket")
        MakeHeader(f, "PvP Trinket", L, -6, 210)
        MakeCheckbox(f, "Show", "showTrinket", L, -30)
        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", L, -56); note:SetWidth(210); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("Detected via combat log only (public API) -- same as Blizzard's own arena frames.")

        MakeHeader(f, "Position & size", R, -6, 210)
        MakeSlider(f, "Size", 8, 64, 1, "trinketSize", R, -48)
        MakeSlider(f, "Offset X", -200, 200, 1, "trinketOffsetX", R, -90)
        MakeSlider(f, "Offset Y", -200, 200, 1, "trinketOffsetY", R, -132)
    end
    -- Vida
    do
        local f = Section("health")
        MakeHeader(f, "Visibility", L, -6, 210)
        MakeCheckbox(f, "Show text", "showText", L, -30)
        HIDEGRP.powerHidden[#HIDEGRP.powerHidden + 1] = MakeCheckbox(f, "Show value (99% | 100m)", "showValue", L, -56)
        MakeCheckbox(f, "Smart auto-hide", "textAutoHide", L, -82)
        MakeCheckbox(f, "Also reveal on low HP", "textLowHealthShow", L, -108)
        MakeSlider(f, "Reveal below %", 5, 100, 1, "textLowHealthThreshold", L, -150)

        MakeHeader(f, "Text style", L, -196, 210)
        MakeSlider(f, "Font size", 4, 60, 1, "fontSize", L, -238)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "textAlpha", L, -280)

        MakeHeader(f, "Position & color", R, -6, 210)
        MakeSlider(f, "Offset X", -200, 200, 1, "textOffsetX", R, -48)
        MakeSlider(f, "Offset Y", -200, 200, 1, "textOffsetY", R, -90)
        MakeCheckbox(f, "Custom text color", "useHealthColor", R, -122)
        MakeColorButton(f, "Text color", "healthColor", R, -150)
    end
    -- Nombre
    do
        local f = Section("name")
        MakeHeader(f, "Behavior", L, -6, 210)
        MakeCheckbox(f, "Show name", "showName", L, -30)
        MakeCheckbox(f, "Auto-hide", "nameAutoHide", L, -56)
        MakeCheckbox(f, "Level color by rank", "nameLevelColor", L, -82)
        MakeCheckbox(f, "Dynamic width (200/111)", "nameDynamicWidth", L, -108)

        MakeHeader(f, "Text style", L, -148, 210)
        MakeSlider(f, "Font size", 4, 60, 1, "nameFontSize", L, -190)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "nameAlpha", L, -232)

        MakeHeader(f, "Size & position", R, -6, 210)
        MakeSlider(f, "Scale", 0.5, 2, 0.05, "nameScale", R, -48)
        MakeSlider(f, "Max characters (0=off)", 0, 20, 1, "nameMaxLength", R, -90)
        MakeSlider(f, "Offset X", -200, 200, 1, "nameOffsetX", R, -132)
        MakeSlider(f, "Offset Y", -200, 200, 1, "nameOffsetY", R, -174)
        MakeCheckbox(f, "Custom name color", "useNameColor", R, -206)
        MakeColorButton(f, "Name color", "nameColor", R, -234)
    end
    -- Hechizo
    do
        local f = Section("spell")
        MakeHeader(f, "Text style", L, -6, 210)
        MakeCheckbox(f, "Show spell name", "showSpell", L, -30)
        MakeSlider(f, "Font size", 4, 60, 1, "spellFontSize", L, -72)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "spellAlpha", L, -114)
        MakeSlider(f, "Scale", 0.5, 2, 0.05, "spellScale", L, -156)
        MakeSlider(f, "Max characters (0=off)", 0, 40, 1, "spellMaxLength", L, -198)
        MakeSlider(f, "Wrap width (lower = stack)", 30, 400, 1, "spellWrapWidth", L, -240)

        MakeHeader(f, "Position & color", R, -6, 210)
        MakeSlider(f, "Offset X", -200, 200, 1, "spellOffsetX", R, -48)
        MakeSlider(f, "Offset Y", -200, 200, 1, "spellOffsetY", R, -90)
        MakeCheckbox(f, "Custom spell color", "useSpellColor", R, -122)
        MakeColorButton(f, "Spell color", "spellColor", R, -150)
        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", R, -182); note:SetWidth(210); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("Long spell names wrap to 2 lines (within the cast bar width). Max characters truncates with '..' (readable names only).")
    end
    -- Cast bar (posicion fija: imita al hp bar).
    do
        local f = Section("cast")
        MakeHeader(f, "Bar", L, -6, 210)
        MakeSlider(f, "Width", 2, 1000, 1, "castWidth", L, -48)
        MakeSlider(f, "Height", 2, 300, 1, "castHeight", L, -90)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "castAlpha", L, -132)
        MakeColorButton(f, "Cast color", "castColor", L, -162)

        MakeHeader(f, "Spark", L, -198, 210)
        MakeSlider(f, "Spark width", 0, 60, 1, "castSparkWidth", L, -240)
        MakeSlider(f, "Spark height", 0, 120, 1, "castSparkHeight", L, -282)
        MakeSlider(f, "Spark scale", 0.2, 3, 0.05, "castSparkScale", L, -324)

        MakeHeader(f, "Texture & fill", R, -6, 210)
        MakeTexturePicker(f, "Cast texture", "castTexture", "bar", R, -32)
        MakeCheckbox(f, "Inverse (right -> left)", "castReverse", R, -88)
        MakeCheckbox(f, "Smooth progress", "castSmooth", R, -114)
        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", R, -148); note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("Position: fixed (mimics the hp bar)")
    end
    -- Colores
    do
        local f = Section("colors")
        MakeCheckbox(f, "Manual color (ignore auto)", "useBarColor", L, -12)
        MakeColorButton(f, "Bar color", "barColor", L, -40)
        HIDEGRP.colorHidden[#HIDEGRP.colorHidden + 1] = MakeColorButton(f, "Hostile color", "colorHostile", L, -72)
        HIDEGRP.colorHidden[#HIDEGRP.colorHidden + 1] = MakeColorButton(f, "Neutral color", "colorNeutral", L, -100)
        HIDEGRP.colorHidden[#HIDEGRP.colorHidden + 1] = MakeColorButton(f, "Friendly color", "colorFriendly", L, -128)
    end
    -- Presets
    do
        local f = Section("presets")
        local selected = { name = nil }

        -- ===== IZQUIERDA: gestion de perfiles =====
        MakeHeader(f, "Profiles", L, -6, 200)

        local nlbl = f:CreateFontString(nil, "ARTWORK"); setFont(nlbl, 11)
        nlbl:SetPoint("TOPLEFT", L, -30); nlbl:SetTextColor(COLOR_OPTION[1], COLOR_OPTION[2], COLOR_OPTION[3])
        nlbl:SetText("New preset name")
        local nameBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        nameBox:SetSize(130, 20)
        nameBox:SetPoint("TOPLEFT", L + 4, -48)
        nameBox:SetAutoFocus(false)
        local saveBtn = MakeButton(f, "Save", 60, 22)
        saveBtn:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)

        local prevBtn = MakeButton(f, "<", 24, 22); prevBtn:SetPoint("TOPLEFT", L, -78)
        local selBtn  = MakeButton(f, "", 140, 22); selBtn:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
        local nextBtn = MakeButton(f, ">", 24, 22); nextBtn:SetPoint("LEFT", selBtn, "RIGHT", 4, 0)

        local loadBtn = MakeButton(f, "Load", 92, 22);        loadBtn:SetPoint("TOPLEFT", L, -106)
        local delBtn  = MakeButton(f, "Delete", 92, 22);      delBtn:SetPoint("LEFT", loadBtn, "RIGHT", 6, 0)
        local ovrBtn  = MakeButton(f, "Overwrite", 92, 22);   ovrBtn:SetPoint("TOPLEFT", L, -134)
        local defBtn  = MakeButton(f, "Set default", 92, 22); defBtn:SetPoint("LEFT", ovrBtn, "RIGHT", 6, 0)
        local exportBtn = MakeButton(f, "Export", 92, 22);    exportBtn:SetPoint("TOPLEFT", L, -162)
        local importBtn = MakeButton(f, "Import", 92, 22);    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 6, 0)

        local defLbl = f:CreateFontString(nil, "ARTWORK"); setFont(defLbl, 11)
        defLbl:SetPoint("TOPLEFT", L, -192); defLbl:SetTextColor(0.7, 0.9, 0.7)

        local defNowBtn = MakeButton(f, "Save current layout as default", 210, 22)
        defNowBtn:SetPoint("TOPLEFT", L, -220)
        local resetAllBtn = MakeButton(f, "Reset ALL", 210, 22)
        resetAllBtn:SetPoint("TOPLEFT", L, -250)

        -- ===== DERECHA: opciones globales + quest tracker =====
        MakeHeader(f, "Global options", R, -6, 200)
        MakeToggle(f, "Hide edit outline in preview", R, -30,
            function() return ns.GetDB().hideEditOutline end,
            function(v) ns.GetDB().hideEditOutline = v; ns.ToggleEditOutline() end)
        MakeToggle(f, "Move Party 1-5 together", R, -54,
            function() return ns.GetDB().groupMoveParty end,
            function(v) ns.GetDB().groupMoveParty = v end)
        MakeToggle(f, "Move Boss 1-5 together", R, -78,
            function() return ns.GetDB().groupMoveBoss end,
            function(v) ns.GetDB().groupMoveBoss = v end)
        MakeToggle(f, "Mouselook (right-click drag)", R, -102,
            function() return ns.GetDB().mouselook end,
            function(v) ns.GetDB().mouselook = v end)
        MakeToggle(f, "Hide Blizzard unit frames", R, -126,
            function() return ns.GetDB().hideBlizzard end,
            function(v)
                ns.GetDB().hideBlizzard = v
                if v then
                    if ns.HideBlizzardFrames then ns.HideBlizzardFrames() end
                    print("|cff00ff00[MCF]|r Blizzard player/pet/target/tot/boss/party/cast frames hidden.")
                else
                    print("|cffffcc00[MCF]|r Reload (/reload) to restore the Blizzard frames.")
                end
            end)
        local barRepoCB = MakeToggle(f, "Bartender bar (mounted)", R, -150,
            function() return ns.GetDB().barReposition end,
            function(v) ns.GetDB().barReposition = v; if ns.RefreshBarReposition then ns.RefreshBarReposition() end end)
        barRepoCB:HookScript("OnEnter", function(self)
            if GameTooltip:IsForbidden() then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Bartender: move possess bar while mounted", COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
            GameTooltip:AddLine("Moves Bartender4's possess/vehicle bar (BT4Bar5) to (-246, -175) while the " ..
                "player is mounted. Restores its original Bartender position automatically when dismounting.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        barRepoCB:HookScript("OnLeave", function() if not GameTooltip:IsForbidden() then GameTooltip:Hide() end end)
        MakeToggle(f, "Smooth fade-in (frames appearing)", R, -174,
            function() return ns.GetDB().fadeIn end,
            function(v) ns.GetDB().fadeIn = v end)
        local dcFixCB = MakeToggle(f, "DynamicCam camera fix", R, -198,
            function() return ns.GetDB().dcFix end,
            function(v) ns.GetDB().dcFix = v; if ns.ApplyDcFix then ns.ApplyDcFix() end end)
        dcFixCB:HookScript("OnEnter", function(self)
            if GameTooltip:IsForbidden() then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("DynamicCam camera fix", COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
            GameTooltip:AddLine("Fixes DialogueUI's compatibility with DynamicCam: opening DialogueUI's " ..
                "panel calls a method that freezes DynamicCam's camera and never releases it, breaking its " ..
                "custom camera situations. This neutralizes that call. Only matters if you use BOTH " ..
                "DialogueUI and DynamicCam — and DialogueUI's own \"Camera Movement\" option must be " ..
                "turned OFF for this to work.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        dcFixCB:HookScript("OnLeave", function() if not GameTooltip:IsForbidden() then GameTooltip:Hide() end end)
        local tnote = f:CreateFontString(nil, "ARTWORK"); setFont(tnote, 10)
        tnote:SetPoint("TOPLEFT", R, -230); tnote:SetWidth(210); tnote:SetJustifyH("LEFT")
        tnote:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        tnote:SetText("Grid, Snap and Preview moved to the EDITING tab (top). Quest tracker options are in the TRACKER tab.")

        -- ===== Logica (handlers) =====
        local function refreshSel() selBtn.text:SetText(selected.name or "(no presets)") end
        local function updateLabels()
            defLbl:SetText("Default (Reset ALL): |cff88ff88" .. (ns.GetDefaultPreset() or "none") .. "|r")
        end
        local function cycleSelect(dir)
            local names = ns.GetPresetNames()
            if #names == 0 then selected.name = nil return end
            local idx = 1
            for i, n in ipairs(names) do if n == selected.name then idx = i break end end
            idx = ((idx - 1 + dir) % #names) + 1
            selected.name = names[idx]
        end

        prevBtn:SetScript("OnClick", function() cycleSelect(-1); refreshSel() end)
        nextBtn:SetScript("OnClick", function() cycleSelect(1); refreshSel() end)
        saveBtn:SetScript("OnClick", function()
            local n = nameBox:GetText()
            if n and n ~= "" then
                ns.SavePreset(n); selected.name = n
                nameBox:SetText(""); nameBox:ClearFocus(); refreshSel(); updateLabels()
            end
        end)
        loadBtn:SetScript("OnClick", function() if selected.name then ns.LoadPreset(selected.name); RefreshControls() end end)
        delBtn:SetScript("OnClick", function()
            if selected.name then ns.DeletePreset(selected.name); selected.name = nil; refreshSel(); updateLabels() end
        end)
        defBtn:SetScript("OnClick", function() if selected.name then ns.SetDefaultPreset(selected.name); updateLabels() end end)
        -- Pedido del usuario 2026-07-19: mismo boton "Set default" tambien
        -- accesible desde el footer -- selected/updateLabels son locals de
        -- ESTE bloque (Section("presets")), se exponen via ns.* para que el
        -- footer los pueda llamar sin duplicar la logica.
        ns.SetDefaultToSelectedPreset = function()
            if selected.name then ns.SetDefaultPreset(selected.name); updateLabels() end
        end
        ns.GetSelectedPresetName = function() return selected.name end
        exportBtn:SetScript("OnClick", function() ShowExport(selected.name) end)
        importBtn:SetScript("OnClick", function()
            ShowImport(function(newName) selected.name = newName; refreshSel(); updateLabels() end)
        end)
        defNowBtn:SetScript("OnClick", function()
            ns.SavePreset("Default"); ns.SetDefaultPreset("Default")
            selected.name = "Default"; refreshSel(); updateLabels()
        end)

        StaticPopupDialogs["MYCF_RESETALL"] = {
            text = "Reset EVERYTHING?\n(If you marked a preset as Default, that one loads; otherwise factory values.)",
            button1 = YES, button2 = NO, timeout = 0, whileDead = true,
            hideOnEscape = true, preferredIndex = 3,
            OnAccept = function() ns.ResetAll() end,
        }
        resetAllBtn:SetScript("OnClick", function() StaticPopup_Show("MYCF_RESETALL") end)

        StaticPopupDialogs["MYCF_OVERWRITE"] = {
            text = "Overwrite the selected profile with the CURRENT layout?\n|cffff8080%s|r",
            button1 = YES, button2 = NO, timeout = 0, whileDead = true,
            hideOnEscape = true, preferredIndex = 3,
            OnAccept = function()
                if selected.name then ns.SavePreset(selected.name); refreshSel(); updateLabels() end
            end,
        }
        ovrBtn:SetScript("OnClick", function()
            if selected.name then StaticPopup_Show("MYCF_OVERWRITE", selected.name) end
        end)

        refreshers[#refreshers + 1] = function() refreshSel(); updateLabels() end
    end

    -- Extras (pedido del usuario 2026-07-19: "muevelo todo a una seccion
    -- aparte, no en profile") -- tooltip + mirror timers, ambos GLOBALES
    -- (no por-unidad), separados de Profile en su propia pestaña de sidebar.
    do
        local f = Section("extras")

        MakeHeader(f, "Tooltip", L, -6, 210)
        local function TTDB() return ns.GetDB() and ns.GetDB().tooltip end
        MakeToggle(f, "Enable tooltip skin", L, -30,
            function() return TTDB() and TTDB().enabled end,
            function(v) if TTDB() then TTDB().enabled = v end; if ns.RefreshTooltipSkin then ns.RefreshTooltipSkin() end end)
        MakeSlider(f, "Scale", 0.5, 2, 0.05, "scale", L, -74, TTDB,
            function() if ns.RefreshTooltipSkin then ns.RefreshTooltipSkin() end end)
        local ttNote = f:CreateFontString(nil, "ARTWORK"); setFont(ttNote, 10)
        ttNote:SetPoint("TOPLEFT", L, -128); ttNote:SetWidth(210); ttNote:SetJustifyH("LEFT")
        ttNote:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        ttNote:SetText("Reskins GameTooltip and related tooltips (items, units, comparisons) to match this preset.")

        MakeHeader(f, "Mirror Timers (breath/rested/feign death)", R, -6, 210)
        local function MTDB() return ns.GetDB() and ns.GetDB().mirrortimer end
        local function RefreshMT() if ns.RefreshMirrorTimers then ns.RefreshMirrorTimers() end end
        MakeToggle(f, "Enable", R, -30,
            function() return MTDB() and MTDB().enabled end,
            function(v) if MTDB() then MTDB().enabled = v end; RefreshMT() end)
        MakeSlider(f, "Bar Width", 60, 400, 5, "width", R, -74, MTDB, RefreshMT)
        MakeSlider(f, "Bar Height", 8, 40, 1, "height", R, -126, MTDB, RefreshMT)
        -- Pedido del usuario 2026-07-19: "dejame elegir el w h de ambas" --
        -- cage (fondo/marco) con tamaño INDEPENDIENTE de la barra, ya no
        -- derivado por proporcion fija.
        MakeSlider(f, "Cage Width", 60, 500, 5, "cageWidth", R, -178, MTDB, RefreshMT)
        MakeSlider(f, "Cage Height", 20, 200, 2, "cageHeight", R, -230, MTDB, RefreshMT)
        MakeSlider(f, "Offset X", -500, 500, 1, "offsetX", R, -282, MTDB, RefreshMT)
        MakeSlider(f, "Offset Y", -300, 100, 1, "offsetY", R, -334, MTDB, RefreshMT)
        -- Pedido del usuario 2026-07-19: "no me dejes elegir texturas desde
        -- el menu" -- textura fija (misma que AzeriteUI, ver MirrorTimers.lua),
        -- sin selector. Solo tamaño/posicion/color quedan configurables.
        local mtNote = f:CreateFontString(nil, "ARTWORK"); setFont(mtNote, 10)
        mtNote:SetPoint("TOPLEFT", R, -386); mtNote:SetWidth(210); mtNote:SetJustifyH("LEFT")
        mtNote:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        mtNote:SetText("Fixed texture (same as AzeriteUI). To move it: enter Lock (top bar) — it shows with a draggable outline.")

        -- Texto (pedido del usuario 2026-07-19: "quiero controlar el texto,
        -- x y size y color tambien") -- columna izquierda, debajo de Tooltip.
        MakeHeader(f, "Mirror Timer Text", L, -180, 210)
        MakeSlider(f, "Text Offset X", -100, 100, 1, "labelOffsetX", L, -224, MTDB, RefreshMT)
        MakeSlider(f, "Text Offset Y", -100, 100, 1, "labelOffsetY", L, -276, MTDB, RefreshMT)
        MakeSlider(f, "Text Size", 6, 24, 1, "labelFontSize", L, -328, MTDB, RefreshMT)
        MakeGlobalColor(f, "Text Color", function() return MTDB() and MTDB().labelColor end, L, -370, RefreshMT)
    end

    -- =========================== SECCIONES PORTRAIT ===========================
    -- Grupo (sub-frame) para poder mostrar/ocultar bloques enteros de widgets.
    local function MakeGroup(parent)
        local g = CreateFrame("Frame", nil, parent)
        g:SetAllPoints(parent)
        return g
    end

    -- Portrait / General
    do
        local f = Section("p_general")
        MakeCheckbox(f, "Enabled", "enabled", L, -10)
        MakeSlider(f, "Size", 20, 300, 1, "size", L, -52)
        MakeSlider(f, "Scale (wheel in Lock too)", 0.3, 3, 0.02, "scale", L, -94)
        MakeCycle(f, "Strata", ns.STRATA_VALUES, "strata", L, -136)
        local resetBtn = MakeButton(f, "Reset portrait", 200, 22)
        resetBtn:SetPoint("TOPLEFT", L, -176)
        resetBtn:SetScript("OnClick", function() ns.ResetUnit(ns.currentEdit) end)

        -- Solo player: click izquierdo abre el panel de personaje.
        local playerOnly = MakeGroup(f)
        VIS.portraitPlayerOnly[#VIS.portraitPlayerOnly + 1] = playerOnly
        MakeCheckbox(playerOnly, "Left-click opens Character panel", "clickOpenChar", L, -216)
        MakeSlider(playerOnly, "Click area size", 0.3, 3, 0.05, "charBtnScale", L, -258)

        -- Doble posicion (solo portraits con dualPos: player/pet/focus).
        local dual = MakeGroup(f)
        VIS.portraitDualBoxes[#VIS.portraitDualBoxes + 1] = dual
        MakeHeader(dual, "Dual position", R, -6, 250)
        MakeCycle(dual, "Edit (preview)", { "center", "alt" }, "editPos", R, -30)
        MakeCheckbox(dual, "Center if: target", "centerOnTarget", R, -62)
        MakeCheckbox(dual, "Center if: combat", "centerInCombat", R, -88)
        MakeCheckbox(dual, "Center if: raid/dungeon", "centerInInstance", R, -114)
        local note = dual:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", R, -148); note:SetWidth(210); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("If no condition is met, the alternate position is used.")
    end
    -- Portrait / Posicion
    do
        local f = Section("p_pos")
        MakeHeader(f, "Primary position", L, -6, 210)
        MakeEditBox(f, "Anchor to (empty = screen)", "centerAnchor", L, -30, 200)
        MakeCycle(f, "Point", ns.POINT_VALUES, "centerPoint", L, -70)
        MakeCycle(f, "Rel. point", ns.POINT_VALUES, "centerRelPoint", L, -100)
        MakeSlider(f, "Offset X", -2000, 2000, 1, "centerX", L, -140)
        MakeSlider(f, "Offset Y", -2000, 2000, 1, "centerY", L, -182)

        -- Posicion alterna (solo dualPos).
        local alt = MakeGroup(f)
        VIS.portraitDualBoxes[#VIS.portraitDualBoxes + 1] = alt
        MakeHeader(alt, "Alternate position", R, -6, 210)
        MakeEditBox(alt, "Anchor to (empty = screen)", "altAnchor", R, -30, 200)
        MakeCycle(alt, "Point", ns.POINT_VALUES, "altPoint", R, -70)
        MakeCycle(alt, "Rel. point", ns.POINT_VALUES, "altRelPoint", R, -100)
        MakeSlider(alt, "Offset X", -2000, 2000, 1, "altX", R, -140)
        MakeSlider(alt, "Offset Y", -2000, 2000, 1, "altY", R, -182)
    end
    -- Portrait / Fondo
    do
        local f = Section("p_bg")
        MakeCheckbox(f, "Show circular background", "showBg", L, -10)
        MakeTexturePicker(f, "Background texture (empty = circle)", "bgTexture", "portraitbg", L, -44)
        MakeSlider(f, "Background scale", 0.2, 3, 0.05, "bgScale", L, -96)
        MakeSlider(f, "Background opacity", 0, 1, 0.05, "bgAlpha", L, -138)
        MakeColorButton(f, "Background color", "bgColor", L, -168)
    end
    -- Portrait / Imagen (modelo 3D o icono de clase)
    do
        local f = Section("p_model")
        MakeCheckbox(f, "Show portrait", "showModel", L, -10)
        local zoom = MakeSlider(f, "Zoom (3D model only)", 0, 1, 0.01, "modelZoom", L, -52)
        VIS.portraitModelOnly[#VIS.portraitModelOnly + 1] = zoom
        MakeSlider(f, "Scale", 0.2, 2, 0.02, "modelScale", L, -94)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "modelAlpha", L, -136)
        MakeSlider(f, "Offset X", -200, 200, 1, "modelOffsetX", R, -20)
        MakeSlider(f, "Offset Y", -200, 200, 1, "modelOffsetY", R, -62)
        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", R, -100); note:SetWidth(200); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("ToT and Party use a class icon (no 3D model or zoom).")
    end
    -- Portrait / Borde (orbe)
    do
        local f = Section("p_cage")
        MakeCheckbox(f, "Show border", "showCage", L, -10)
        MakeTexturePicker(f, "Border texture (empty = orb)", "cageTexture", "portraitcage", L, -44)
        MakeSlider(f, "Border scale", 0.2, 3, 0.02, "cageScale", L, -96)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "cageAlpha", L, -138)
        MakeSlider(f, "Offset X", -200, 200, 1, "cageOffsetX", R, -20)
        MakeSlider(f, "Offset Y", -200, 200, 1, "cageOffsetY", R, -62)
    end
    -- Portrait / Descanso (resting, solo player)
    do
        local f = Section("p_rest")
        MakeHeader(f, "Resting", L, -6, 210)
        MakeCheckbox(f, "Show flipbook", "showRest", L, -30)
        MakeSlider(f, "Scale", 0.1, 2, 0.02, "restScale", L, -72)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "restAlpha", L, -114)
        MakeSlider(f, "Offset X", -200, 200, 1, "restOffsetX", R, -20)
        MakeSlider(f, "Offset Y", -200, 200, 1, "restOffsetY", R, -62)
    end
    -- Portrait / Muerte (color + opacidad)
    do
        local f = Section("p_death")
        MakeHeader(f, "Death mark", L, -6, 210)
        MakeCheckbox(f, "Show on death", "showDeath", L, -30)
        MakeSlider(f, "Scale", 0.1, 2, 0.02, "deathScale", L, -72)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "deathAlpha", L, -114)
        MakeColorButton(f, "Color", "deathColor", L, -144)
        MakeSlider(f, "Offset X", -200, 200, 1, "deathOffsetX", R, -20)
        MakeSlider(f, "Offset Y", -200, 200, 1, "deathOffsetY", R, -62)
    end
    -- Portrait / Badges (faccion + combate; color + opacidad)
    do
        local f = Section("p_badges")
        MakeHeader(f, "Faction (alliance/horde)", L, -6, 210)
        MakeCheckbox(f, "Show badge", "showFaction", L, -30)
        MakeSlider(f, "Scale", 0.1, 2, 0.02, "factionScale", L, -72)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "factionAlpha", L, -114)
        MakeColorButton(f, "Color", "factionColor", L, -144)
        MakeSlider(f, "Offset X", -200, 200, 1, "factionOffsetX", L, -186)
        MakeSlider(f, "Offset Y", -200, 200, 1, "factionOffsetY", L, -228)

        MakeHeader(f, "Combat", R, -6, 210)
        MakeCheckbox(f, "Show in combat", "showCombat", R, -30)
        MakeSlider(f, "Scale", 0.1, 2, 0.02, "combatScale", R, -72)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "combatAlpha", R, -114)
        MakeColorButton(f, "Color", "combatColor", R, -144)
        MakeSlider(f, "Offset X", -200, 200, 1, "combatOffsetX", R, -186)
        MakeSlider(f, "Offset Y", -200, 200, 1, "combatOffsetY", R, -228)
    end
    -- Portrait / Raid target marker (solo party): badge encima del portrait.
    do
        local f = Section("p_raid")
        MakeHeader(f, "Raid target marker", L, -6, 210)
        MakeCheckbox(f, "Show when marked", "showRaidTarget", L, -30)
        MakeCheckbox(f, "Bounce (gentle)", "raidTargetBounce", L, -62)
        MakeSlider(f, "Scale", 0.1, 2, 0.02, "raidTargetScale", L, -100)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "raidTargetAlpha", L, -142)
        MakeSlider(f, "Offset X", -200, 200, 1, "raidTargetOffsetX", L, -184)
        MakeSlider(f, "Offset Y", -200, 200, 1, "raidTargetOffsetY", L, -226)

        MakeTexturePicker(f, "Marker texture", "raidTargetTexture", "raidtarget", R, -20)
        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", R, -66); note:SetWidth(210); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("Shows the raid target icon (skull, cross, star...) as a badge over the party portrait, only when the member is marked. In preview it shows a sample skull.")
    end
    -- Portrait / Role + Leader icons. Rol = solo party (sub-grupo portraitRoleOnly);
    -- Lider = cualquier portrait con feature 'leader' (siempre visible en la seccion).
    do
        local f = Section("p_role")
        -- ROL (solo party)
        local roleG = MakeGroup(f)
        VIS.portraitRoleOnly[#VIS.portraitRoleOnly + 1] = roleG
        MakeHeader(roleG, "Role icon (tank/heal/dps)", L, -6, 210)
        MakeCheckbox(roleG, "Show role", "showRole", L, -30)
        MakeSlider(roleG, "Scale", 0.1, 2, 0.02, "roleScale", L, -68)
        MakeSlider(roleG, "Opacity", 0, 1, 0.05, "roleAlpha", L, -110)
        MakeSlider(roleG, "Offset X", -200, 200, 1, "roleOffsetX", L, -152)
        MakeSlider(roleG, "Offset Y", -200, 200, 1, "roleOffsetY", L, -194)

        -- LIDER (todos los que tengan la feature)
        MakeHeader(f, "Leader icon", R, -6, 210)
        MakeCheckbox(f, "Show leader", "showLeader", R, -30)
        MakeSlider(f, "Scale", 0.1, 2, 0.02, "leaderScale", R, -68)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "leaderAlpha", R, -110)
        MakeSlider(f, "Offset X", -200, 200, 1, "leaderOffsetX", R, -152)
        MakeSlider(f, "Offset Y", -200, 200, 1, "leaderOffsetY", R, -194)
    end

    -- =========================== SECCIONES AURAS ===========================
    -- Aura / General
    do
        local f = Section("a_general")
        MakeCheckbox(f, "Enabled", "enabled", L, -10)
        MakeCycle(f, "Strata", ns.STRATA_VALUES, "strata", L, -44)
        MakeCycle(f, "Sort", ns.AURA_SORTS_VALUES, "sort", L, -74)
        MakeSlider(f, "Scale (wheel in Lock too)", 0.3, 3, 0.02, "scale", L, -116)
        local resetBtn = MakeButton(f, "Reset group", 200, 22)
        resetBtn:SetPoint("TOPLEFT", L, -152)
        resetBtn:SetScript("OnClick", function() ns.ResetUnit(ns.currentEdit) end)
        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", L, -186); note:SetWidth(210); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("Sort: index (API), timeUp, timeDown, name. Secret times go to the end.")

        -- Solo Player Auras: editar posicion + condiciones + opacidad.
        local dual = MakeGroup(f)
        VIS.auraDualBoxes[#VIS.auraDualBoxes + 1] = dual
        MakeHeader(dual, "Positions / Opacity", R, -6, 250)
        MakeCycle(dual, "Edit (preview)", { "center", "alt", "dead", "deadTarget" }, "editPos", R, -30)
        MakeCheckbox(dual, "Primary if: target", "centerOnTarget", R, -62)
        MakeCheckbox(dual, "Primary if: combat", "centerInCombat", R, -88)
        MakeCheckbox(dual, "Primary if: instance", "centerInInstance", R, -114)
        MakeSlider(dual, "Base opacity (hover/cond=100%)", 0, 1, 0.05, "groupAlpha", R, -150)
        local dnote = dual:CreateFontString(nil, "ARTWORK"); setFont(dnote, 10)
        dnote:SetPoint("TOPLEFT", R, -192); dnote:SetWidth(210); dnote:SetJustifyH("LEFT")
        dnote:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        dnote:SetText("No condition = alternate. Player dead = Death pos (Death tab).")

        MakeCheckbox(dual, "Cancel buff on right-click", "allowCancel", R, -232)
        local cnote = dual:CreateFontString(nil, "ARTWORK"); setFont(cnote, 10)
        cnote:SetPoint("TOPLEFT", R, -258); cnote:SetWidth(210); cnote:SetJustifyH("LEFT")
        cnote:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        cnote:SetText("Right-click a buff to cancel it (mounts, toys, self-buffs). Buffs only; not in combat for buffs gained while fighting.")
    end
    -- Aura / Grid (centrado horizontal, hacia abajo)
    do
        local f = Section("a_grid")
        MakeSlider(f, "Icon size", 8, 100, 1, "iconSize", L, -20)
        MakeSlider(f, "Row width (icons/row)", 1, 20, 1, "perRow", L, -62)
        MakeSlider(f, "Column space", 0, 40, 1, "colSpace", L, -104)
        MakeSlider(f, "Row space", 0, 60, 1, "rowSpace", L, -146)
        MakeSlider(f, "Limit (max auras)", 1, 40, 1, "limit", R, -62)

        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", R, -110); note:SetWidth(210); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("Grid direction: centered horizontally then downward. Each row is centered under the anchor.")
    end
    -- Aura / Posicion (una sola ubicacion)
    do
        local f = Section("a_pos")
        MakeHeader(f, "Primary position", L, -6, 210)
        MakeEditBox(f, "Anchor to (empty = screen)", "anchor", L, -30, 200)
        MakeCycle(f, "Point", ns.POINT_VALUES, "point", L, -70)
        MakeCycle(f, "Rel. point", ns.POINT_VALUES, "relPoint", L, -100)
        MakeSlider(f, "Offset X", -2000, 2000, 1, "offsetX", L, -140)
        MakeSlider(f, "Offset Y", -2000, 2000, 1, "offsetY", L, -182)

        -- Posicion alterna (solo Player Auras).
        local alt = MakeGroup(f)
        VIS.auraDualBoxes[#VIS.auraDualBoxes + 1] = alt
        MakeHeader(alt, "Alternate position", R, -6, 210)
        MakeEditBox(alt, "Anchor to (empty = screen)", "altAnchor", R, -30, 200)
        MakeCycle(alt, "Point", ns.POINT_VALUES, "altPoint", R, -70)
        MakeCycle(alt, "Rel. point", ns.POINT_VALUES, "altRelPoint", R, -100)
        MakeSlider(alt, "Offset X", -2000, 2000, 1, "altX", R, -140)
        MakeSlider(alt, "Offset Y", -2000, 2000, 1, "altY", R, -182)

        -- Offset extra si hay pet (solo Player Auras): se SUMA a la posicion viva. Cada posicion
        -- (primaria / alterna) tiene su PROPIO offset independiente.
        -- OJO de espaciado: un slider dibuja su ETIQUETA POR ENCIMA de si mismo (ver MakeSlider,
        -- BOTTOMLEFT+3 → sube ~17px); un header ocupa hasta ~24px bajo su texto (divisor incluido).
        -- Con solo 24px entre header y el primer slider (bug anterior) la etiqueta del slider caia
        -- ENCIMA del divisor/texto del header (colision vista en captura). Minimo seguro: ~44px.
        local petg = MakeGroup(f)
        VIS.auraDualBoxes[#VIS.auraDualBoxes + 1] = petg
        MakeHeader(petg, "Pet offset — primary", L, -220, 210)
        MakeSlider(petg, "Offset X", -2000, 2000, 1, "petOffsetX", L, -264)
        MakeSlider(petg, "Offset Y", -2000, 2000, 1, "petOffsetY", L, -306)
        MakeHeader(petg, "Pet offset — alternate", R, -220, 210)
        MakeSlider(petg, "Offset X", -2000, 2000, 1, "petOffsetXAlt", R, -264)
        MakeSlider(petg, "Offset Y", -2000, 2000, 1, "petOffsetYAlt", R, -306)
        local pnote = petg:CreateFontString(nil, "ARTWORK"); setFont(pnote, 10)
        pnote:SetPoint("TOPLEFT", L, -350); pnote:SetWidth(430); pnote:SetJustifyH("LEFT")
        pnote:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        pnote:SetText("Added to the primary / alternate position while you have a pet (live only, not in preview). Each position has its own independent offset.")
    end
    -- Aura / Muerte (3a posicion cuando el player esta muerto; solo Player Auras)
    do
        local f = Section("a_dead")
        MakeCheckbox(f, "Reposition on death", "useDeadPos", L, -10)

        MakeHeader(f, "Dead WITHOUT target (dead)", L, -40, 210)
        MakeEditBox(f, "Anchor to", "deadAnchor", L, -62, 150)
        MakeSlider(f, "Offset X", -2000, 2000, 1, "deadX", L, -108)
        MakeSlider(f, "Offset Y", -2000, 2000, 1, "deadY", L, -150)

        MakeHeader(f, "Dead WITH target (deadTarget)", R, -40, 210)
        MakeEditBox(f, "Anchor to", "deadTargetAnchor", R, -62, 150)
        MakeSlider(f, "Offset X", -2000, 2000, 1, "deadTargetX", R, -108)
        MakeSlider(f, "Offset Y", -2000, 2000, 1, "deadTargetY", R, -150)

        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", L, -192); note:SetWidth(430); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("On death, auras go to one of these 2 depending on whether you have a target. In preview pick 'dead' or 'deadTarget' in 'Edit' (Gen tab) to place them.")
    end
    -- Aura / Estilo (borde, duracion, contador)
    do
        local f = Section("a_style")
        MakeCheckbox(f, "Show border", "showBorder", L, -10)
        MakeTexturePicker(f, "Border texture (empty = default)", "borderTexture", "auraborder", L, -44)
        MakeColorButton(f, "Border color", "borderColor", L, -92)
        MakeSlider(f, "Border opacity", 0, 1, 0.05, "borderAlpha", L, -134)
        MakeSlider(f, "Border size", 0, 0.6, 0.02, "borderScale", L, -176)

        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", R, -10); note:SetWidth(210); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("Default texture: actionbutton-border square. You can enter another texture path.")
    end
    -- Aura / Texto (duracion + contador + tooltip)
    do
        local f = Section("a_text")
        MakeColorButton(f, "Text color (dur+count)", "textColor", L, -10)
        MakeCheckbox(f, "Show duration", "showDuration", L, -42)
        MakeSlider(f, "Duration size", 6, 30, 1, "durationFontSize", L, -84)
        MakeSlider(f, "Duration offset X (all)", -100, 100, 1, "durationOffsetX", L, -126)
        MakeSlider(f, "Duration offset Y (all)", -100, 100, 1, "durationOffsetY", L, -168)

        MakeCheckbox(f, "Show count", "showCount", R, -10)
        MakeSlider(f, "Count size", 6, 30, 1, "countFontSize", R, -52)
        MakeCheckbox(f, "Show swipe (radial)", "showSwipe", R, -82)
        MakeCheckbox(f, "Show tooltip (hover)", "showTooltip", R, -108)
        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", R, -142); note:SetWidth(210); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("The duration offset is global: it moves the text of ALL auras equally.")
    end

    -- =========================== SECCIONES INFO BAR ===========================
    -- Info / General
    do
        local f = Section("i_general")
        MakeCheckbox(f, "Enabled", "enabled", L, -10)
        MakeCycle(f, "Strata", ns.STRATA_VALUES, "strata", L, -44)
        MakeSlider(f, "Font size", 6, 40, 1, "fontSize", L, -84)
        MakeSlider(f, "Scale (wheel in Lock too)", 0.3, 3, 0.02, "scale", L, -126)
        MakeColorButton(f, "Text color", "textColor", R, -134)
        MakeCheckbox(f, "Move ALL together (in preview)", "moveTogether", L, -158)

        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", R, -10); note:SetWidth(210); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("Global font size/color here are the base. Per-text Size/Color/Alpha are in the TEXT tab; the calendar button is in the CAL tab. In preview, drag each element to move it.")
        local resetBtn = MakeButton(f, "Reset info bar", 200, 22)
        resetBtn:SetPoint("TOPLEFT", R, -110)
        resetBtn:SetScript("OnClick", function() ns.ResetUnit(ns.currentEdit) end)
    end
    -- Info / Posicion (mover todo)
    do
        local f = Section("i_pos")
        MakeEditBox(f, "Anchor to (empty = screen)", "anchor", L, -12, 200)
        MakeCycle(f, "Point", ns.POINT_VALUES, "point", L, -56)
        MakeCycle(f, "Rel. point", ns.POINT_VALUES, "relPoint", L, -86)
        MakeSlider(f, "Offset X", -2000, 2000, 1, "offsetX", R, -20)
        MakeSlider(f, "Offset Y", -2000, 2000, 1, "offsetY", R, -62)
    end
    -- Info / Elementos (mostrar + offset individual)
    do
        local f = Section("i_elements")
        MakeCheckbox(f, "Show zone", "showZone", L, -10)
        MakeSlider(f, "Zone X", -400, 400, 1, "zoneX", L, -52)
        MakeSlider(f, "Zone Y", -200, 200, 1, "zoneY", L, -94)
        MakeCheckbox(f, "Show time", "showTime", L, -124)
        MakeSlider(f, "Time X", -400, 400, 1, "timeX", L, -166)
        MakeSlider(f, "Time Y", -200, 200, 1, "timeY", L, -208)

        MakeCheckbox(f, "Show FPS", "showFps", R, -10)
        MakeSlider(f, "FPS X", -400, 400, 1, "fpsX", R, -52)
        MakeSlider(f, "FPS Y", -200, 200, 1, "fpsY", R, -94)
        MakeCheckbox(f, "Show MS", "showMs", R, -124)
        MakeSlider(f, "MS X", -400, 400, 1, "msX", R, -166)
        MakeSlider(f, "MS Y", -200, 200, 1, "msY", R, -208)
    end
    -- Info / Texto por elemento (B9): Color / Alpha / Size independientes.
    do
        local f = Section("i_text")
        MakeHeader(f, "Zone", L, -6, 100)
        MakeSlider(f, "Size", 6, 40, 1, "zoneSize", L, -30)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "zoneAlpha", L, -72)
        MakeColorButton(f, "Color", "zoneColor", L, -102)
        MakeHeader(f, "Time", L, -136, 100)
        MakeSlider(f, "Size", 6, 40, 1, "timeSize", L, -160)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "timeAlpha", L, -202)
        MakeColorButton(f, "Color", "timeColor", L, -232)

        MakeHeader(f, "FPS", R, -6, 100)
        MakeSlider(f, "Size", 6, 40, 1, "fpsSize", R, -30)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "fpsAlpha", R, -72)
        MakeColorButton(f, "Color", "fpsColor", R, -102)
        MakeHeader(f, "MS", R, -136, 100)
        MakeSlider(f, "Size", 6, 40, 1, "msSize", R, -160)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "msAlpha", R, -202)
        MakeColorButton(f, "Color", "msColor", R, -232)
    end
    -- (Seccion "Cal" ELIMINADA: los botones de calendario y mochila se quitaron; el calendario
    -- ahora se abre clickeando el reloj.)
    -- Info / Fondo decorativo
    do
        local f = Section("i_bg")
        MakeCheckbox(f, "Show background", "showBg", L, -10)
        MakeSlider(f, "Width", 20, 1000, 1, "bgWidth", L, -52)
        MakeSlider(f, "Height", 4, 300, 1, "bgHeight", L, -94)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "bgAlpha", L, -136)
        MakeSlider(f, "Offset X", -400, 400, 1, "bgOffsetX", R, -20)
        MakeSlider(f, "Offset Y", -400, 400, 1, "bgOffsetY", R, -62)
        MakeTexturePicker(f, "Background texture", "bgTexture", "infobg", R, -100)
        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", R, -146); note:SetWidth(210); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("Custom texture (default info_bg). A path ending in .tga/.blp is loaded as a texture; anything else is treated as an atlas name.")
    end

    -- =========================== SECCION MICRO MENU ===========================
    do
        local f = Section("mm_general")
        MakeCheckbox(f, "Enabled", "enabled", L, -10)
        MakeCycle(f, "Strata", ns.STRATA_VALUES, "strata", L, -44)
        MakeSlider(f, "Scale", 0.5, 2.0, 0.05, "scale", L, -84)
        MakeEditBox(f, "Anchor to (empty = screen)", "anchor", L, -128, 200)
        MakeSlider(f, "Offset X", -2000, 2000, 1, "offsetX", R, -20)
        MakeSlider(f, "Offset Y", -2000, 2000, 1, "offsetY", R, -62)

        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", R, -104); note:SetWidth(210); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("In preview (/mcf): drag the row to move it. Reskins the Blizzard micro buttons (no background). Repositioning applies out of combat.")
        local resetBtn = MakeButton(f, "Reset micro menu", 200, 22)
        resetBtn:SetPoint("TOPLEFT", R, -150)
        resetBtn:SetScript("OnClick", function() ns.ResetUnit(ns.currentEdit) end)
    end

    -- =========================== SECCION CHAT BUBBLE ===========================
    do
        local f = Section("cb_general")
        MakeCheckbox(f, "Enabled", "enabled", L, -10)
        MakeCheckbox(f, "Hide background", "hideBackground", L, -42)
        MakeSlider(f, "Font size", 6, 30, 1, "fontSize", L, -84)
        MakeCycle(f, "Outline", { "NONE", "OUTLINE", "THICKOUTLINE" }, "outline", L, -126)
        MakeEditBox(f, "Font path", "font", L, -170, 210)

        MakeCheckbox(f, "Custom text color", "useColor", R, -10)
        MakeColorButton(f, "Text color", "color", R, -38)
        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", R, -74); note:SetWidth(210); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("Controls the world chat bubbles: hides their background and sets the text font/size/outline/color. Applies live as bubbles appear.")
        local resetBtn = MakeButton(f, "Reset chat bubble", 200, 22)
        resetBtn:SetPoint("TOPLEFT", R, -130)
        resetBtn:SetScript("OnClick", function() ns.ResetUnit(ns.currentEdit) end)

        -- Pedido del usuario 2026-07-19: "eso es de blizzard, se puede
        -- ocultar, azeriteui lo hace" -- el borde/fondo nativo del EditBox de
        -- CHAT (donde escribis, distinto de las burbujas de arriba) -- global,
        -- no por-unidad, por eso usa ns.GetDB() directo en vez de getP()/OnEdit.
        -- No depende de AzeriteUI, ver SetChatEditBoxTexture/
        -- RefreshChatEditBoxSkin al principio del archivo.
        MakeHeader(f, "Chat window", L, -210, 440)
        MakeToggle(f, "Hide chat edit box border texture", L, -234,
            function() local d = ns.GetDB(); return d and d.hideChatEditBoxTexture end,
            function(v)
                local d = ns.GetDB(); if not d then return end
                d.hideChatEditBoxTexture = v and true or false
                if ns.RefreshChatEditBoxSkin then ns.RefreshChatEditBoxSkin() end
            end)
    end

    -- =========================== SECCION QUEST TRACKER ===========================
    do
        local f = Section("t_general")
        MakeCheckbox(f, "Colorize titles", "enabled", L, -10)
        MakeColorButton(f, "Title color", "color", L, -42)
        MakeSlider(f, "Title center offset", -100, 100, 1, "titleOffsetX", L, -84,
            function() return ns.GetDB().tracker end,
            function() if ns.RefreshTracker then ns.RefreshTracker() end end)
        MakeSlider(f, "Dungeon title offset", -100, 100, 1, "dungeonTitleOffsetX", L, -126,
            function() return ns.GetDB().tracker end,
            function() if ns.RefreshTracker then ns.RefreshTracker() end end)
        -- Pedido del usuario 2026-07-21: "controlar el text alignment leading/justified/
        -- trailing" -- WoW solo tiene LEFT/CENTER/RIGHT (no un 4to modo "justified" real de
        -- texto), asi que se mapea a esos 3. Aplica a TODO texto que el tracker toca (headers,
        -- titulos de mision y lineas de objetivo), no solo headers -- ver Tracker.lua ApplyFontColor.
        MakeCycle(f, "Text align", { "LEFT", "CENTER", "RIGHT" }, "textAlign", L, -170)

        MakeHeader(f, "Auto-hide", L, -212, 210)
        MakeCheckbox(f, "Hide in boss fights", "hideInBoss", L, -236)
        MakeCheckbox(f, "Hide in combat", "hideInCombat", L, -260)
        MakeCheckbox(f, "Hide on hostile target", "hideOnHostileTarget", L, -284)
        MakeCheckbox(f, "Hide in arena", "hideInArena", L, -308)
        MakeCheckbox(f, "Hide in battlegrounds", "hideInBG", L, -332)

        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", R, -10); note:SetWidth(210); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("Colorize titles: recolors the objective-tracker headers/quests (cosmetic, no taint). Title/Dungeon center offset: fine-tune horizontal centering of quest titles vs. scenario/dungeon titles (e.g. \"Windrunner Spire\") independently — live, no reload needed. Text align: LEFT/CENTER/RIGHT justification for every line the tracker touches (headers, quest titles, objectives). Auto-hide toggles fold the tracker (alpha 0) via a secure driver — any combination can be active at once; the tracker reappears as soon as none of the checked conditions apply.")
    end

    -- =========================== SECCION ASSISTED GLOW ===========================
    do
        local f = Section("g_general")
        MakeCheckbox(f, "Enabled", "enabled", L, -10)
        MakeCheckbox(f, "Hide Blizzard highlight", "disableNative", L, -42)
        MakeCycle(f, "Style", ns.GLOW_STYLES or { "Texture" }, "style", L, -78)
        MakeColorButton(f, "Color", "color", L, -112)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "alpha", L, -156)
        MakeTexturePicker(f, "Glow texture (Texture style)", "glowTexture", "glow", L, -196)
        MakeCheckbox(f, "Pulse (texture style)", "pulse", L, -238)

        MakeSlider(f, "Thickness (Border/Pixel)", 1, 20, 1, "thickness", R, -20)
        MakeSlider(f, "Scale", 0.5, 3.0, 0.1, "scale", R, -62)
        MakeCheckbox(f, "Only visible buttons", "onlyVisible", R, -96)
        MakeCheckbox(f, "Check usable (resource/CD)", "checkUsable", R, -128)
        -- Pedido del usuario 2026-07-19: "me gustaria poder controlar el
        -- strata" -- antes hardcodeado a "HIGH" (ver GlowStart en Glow.lua).
        MakeCycle(f, "Strata", ns.STRATA_VALUES, "strata", R, -158)

        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", R, -200); note:SetWidth(210); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        local libNote = ns.HasLCG
            and "Replaces the assisted-rotation highlight with a custom glow on the recommended action button. 'Texture' uses your Assets image (actionbuttonhighlight)."
            or "LibCustomGlow not detected: 'Texture' and 'Border' styles work; Pixel/AutoCast/Button glows need that library."
        note:SetText(libNote)
        local resetBtn = MakeButton(f, "Reset assisted glow", 200, 22)
        resetBtn:SetPoint("TOPLEFT", R, -250)
        resetBtn:SetScript("OnClick", function() ns.ResetUnit(ns.currentEdit) end)
    end

    -- =========================== SECCIONES MINIMAP ===========================
    -- Minimap / General (enabled, escala, posicion del contenedor).
    do
        local f = Section("mn_general")
        MakeCheckbox(f, "Enabled", "enabled", L, -10)
        MakeSlider(f, "Scale (wheel in Lock too)", 0.3, 3, 0.02, "scale", L, -50)

        MakeEditBox(f, "Anchor to (empty = screen)", "anchorFrame", R, -10, 200)
        MakeCycle(f, "Point", ns.POINT_VALUES, "point", R, -54)
        MakeCycle(f, "Rel. point", ns.POINT_VALUES, "relativePoint", R, -84)
        MakeSlider(f, "Offset X", -2000, 2000, 1, "offsetX", L, -100)
        MakeSlider(f, "Offset Y", -2000, 2000, 1, "offsetY", L, -142)

        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", L, -180); note:SetWidth(430); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("The map itself keeps whatever size Blizzard's Edit Mode gives it — this only moves/scales the round frame (border, icons, ring) built around it. Drag in Lock mode to reposition; mouse wheel over it in Lock adjusts scale.")
        local resetBtn = MakeButton(f, "Reset minimap", 200, 22)
        resetBtn:SetPoint("TOPLEFT", L, -230)
        resetBtn:SetScript("OnClick", function() ns.ResetUnit(ns.currentEdit) end)
    end
    -- Minimap / Display (que elementos mostrar).
    do
        local f = Section("mn_display")
        MakeCheckbox(f, "Show compass (N)", "showCompass", L, -10)
        MakeCheckbox(f, "Show coordinates", "showCoordinates", L, -42)
        MakeCheckbox(f, "Show mail indicator", "showMail", L, -74)
        MakeCheckbox(f, "Show LFG eye", "showEye", L, -106)
        MakeCheckbox(f, "Show XP/Reputation ring", "showRing", L, -138)
        MakeCheckbox(f, "Show tracking button", "showTracking", L, -170)
        -- Pedido del usuario 2026-07-19: "quiero poder moverlo, y que siga al
        -- minimap de mi addon" (UIWidgetBelowMinimapContainerFrame nativo --
        -- catch-up buffs, barras de faccion, etc).
        MakeCheckbox(f, "Follow native below-minimap widget (catch-up buffs, etc)", "showBelowMinimapWidget", L, -202)
    end
    -- Minimap / Icons (offsets del eye y del boton de desmontar). Reorganizado
    -- 2026-07-19 (pedido del usuario, "esta muy desorganizado, los ultimos
    -- sliders pasan la ventana y los titulos estan muy juntos"): las 4
    -- columnas de antes iban TODAS apiladas en una sola columna y se pasaban
    -- del panel -- ahora van 2 en L y 2 en R, con mas aire entre header y
    -- primer slider (40px en vez de 30) y entre sliders (44px en vez de 44,
    -- pero el header ahora tiene su PROPIA fila en vez de compartir espacio).
    do
        local f = Section("mn_icons")
        MakeHeader(f, "LFG eye", L, -6, 200)
        MakeSlider(f, "Eye offset X", -200, 200, 1, "eyeOffsetX", L, -46)
        MakeSlider(f, "Eye offset Y", -200, 200, 1, "eyeOffsetY", L, -100)

        MakeHeader(f, "Mail indicator", R, -326, 210)
        MakeSlider(f, "Mail offset X", -200, 200, 1, "mailOffsetX", R, -366)
        MakeSlider(f, "Mail offset Y", -200, 200, 1, "mailOffsetY", R, -420)

        MakeHeader(f, "Coordinates", L, -166, 200)
        MakeSlider(f, "Coords offset X", -200, 200, 1, "coordsOffsetX", L, -206)
        MakeSlider(f, "Coords offset Y", -200, 200, 1, "coordsOffsetY", L, -260)

        MakeHeader(f, "Dismount button", R, -6, 210)
        MakeSlider(f, "Dismount offset X", -200, 200, 1, "dismountOffsetX", R, -46)
        MakeSlider(f, "Dismount offset Y", -200, 200, 1, "dismountOffsetY", R, -100)

        MakeHeader(f, "Below-minimap widget", R, -166, 210)
        MakeSlider(f, "Widget offset X", -200, 200, 1, "widgetOffsetX", R, -206)
        MakeSlider(f, "Widget offset Y", -200, 200, 1, "widgetOffsetY", R, -260)

        -- Pedido del usuario 2026-07-21: boton de tracking, arrastrable libremente en
        -- Lock (ver Minimap.lua CreateTracking) -- estos sliders son el equivalente
        -- fino/numerico, para cuando arrastrar a mano no alcanza.
        MakeHeader(f, "Tracking button", L, -326, 200)
        MakeSlider(f, "Tracking offset X", -200, 200, 1, "trackingOffsetX", L, -366)
        MakeSlider(f, "Tracking offset Y", -200, 200, 1, "trackingOffsetY", L, -420)

        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", L, -486); note:SetWidth(430); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("Offsets are relative to the minimap's own center (LFG eye, tracking button), top edge (dismount button), bottom edge (coordinates, mail indicator), or bottom edge again (below-minimap widget). The tracking button and mail indicator can also be dragged freely while in Lock mode.")
    end
    -- Minimap / Textures (borde, fondo, eye — la barra de XP/Reputacion NO se
    -- personaliza, a pedido del usuario, para no romper el layout del anillo).
    do
        local f = Section("mn_textures")
        MakeTexturePicker(f, "Border texture", "borderTexture", "minimapborder", L, -10)
        MakeTexturePicker(f, "Backdrop texture", "backdropTexture", "minimapbackdrop", L, -50)
        MakeTexturePicker(f, "LFG eye texture", "eyeTexture", "eye", L, -90)
        MakeTexturePicker(f, "Dismount icon", "dismountTexture", "dismount", L, -130)

        MakeTexturePicker(f, "Ring backdrop texture", "ringBackdropTexture", "ringbackdrop", R, -10)
        MakeTexturePicker(f, "Ring button plate", "ringButtonTexture", "ringbutton", R, -50)

        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", R, -100); note:SetWidth(210); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("Leave the path empty to use the addon's default texture. Only the ring's actual fill/progress arc isn't customizable, to keep the XP/Reputation reading intact.")
    end

    -- =========================== SECCIONES RAID FRAMES ===========================
    -- Raid / General (enabled, backdrop de muerte/highlight, reset). Sin
    -- "also show in normal parties" (pedido del usuario 2026-07-20: "quita
    -- lo de party, que solo funcione en raids y bg" -- sus unitframes de
    -- party1-5 propias NO se tocan, son un sistema aparte).
    do
        local f = Section("r_general")
        MakeCheckbox(f, "Enabled", "enabled", L, -10)
        MakeCheckbox(f, "Highlight my current target", "showHighlight", R, -10)
        MakeCheckbox(f, "Hide backdrop when dead", "cageHideDead", R, -42)

        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", L, -80); note:SetWidth(430); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("Shows automatically in any raid group and in battlegrounds only. Growth direction, per-row/column limits and spacing live in the Layout tab; the container's own screen position lives in Pos; icon positions live in Icons.")
        local resetBtn = MakeButton(f, "Reset raid frames", 200, 22)
        resetBtn:SetPoint("TOPLEFT", L, -130)
        resetBtn:SetScript("OnClick", function() ns.ResetUnit(ns.currentEdit) end)
    end
    -- Raid / Icons (posicion de raid target/ready check-resurrect/rol,
    -- pedido del usuario 2026-07-20: "dejame controlar la posicion de los
    -- iconos, basado en el raid1, el resto copian a ese" -- un solo perfil
    -- compartido, ver ns.PositionRaidIcons en Raid.lua).
    do
        local f = Section("r_icons")
        MakeHeader(f, "Raid target icon", L, -6, 210)
        MakeSlider(f, "Offset X", -60, 60, 1, "raidTargetOffsetX", L, -46)
        MakeSlider(f, "Offset Y", -60, 60, 1, "raidTargetOffsetY", L, -90)

        MakeHeader(f, "Ready check / Resurrect", R, -6, 210)
        MakeSlider(f, "Offset X", -60, 60, 1, "readyCheckOffsetX", R, -46)
        MakeSlider(f, "Offset Y", -60, 60, 1, "readyCheckOffsetY", R, -90)

        MakeHeader(f, "Role icon (tank/healer)", L, -134, 210)
        MakeSlider(f, "Offset X", -60, 80, 1, "roleOffsetX", L, -174)
        MakeSlider(f, "Offset Y", -60, 60, 1, "roleOffsetY", L, -218)

        -- Tamaños (pedido del usuario 2026-07-20: "me gustaria poder
        -- cambiarles el tamaño" -- barra de vida/poder + icono de raid target).
        MakeHeader(f, "Sizes", R, -134, 210)
        MakeSlider(f, "Health bar width", 30, 200, 1, "healthBarWidth", R, -174)
        MakeSlider(f, "Health bar height", 6, 40, 1, "healthBarHeight", R, -218)
        MakeSlider(f, "Raid target icon size", 6, 32, 1, "raidTargetIconSize", R, -262)

        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", L, -262); note:SetWidth(210); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("These position/size the icons and bar on member #1 in the Lock preview — every other member (real or preview) copies the same values, since all 40 share one style profile. The power bar's width follows the health bar's automatically.")
    end
    -- Raid / Layout — SIMPLIFICADO (pedido del usuario 2026-07-20): solo
    -- izquierda/derecha + arriba/abajo, sin spacing vertical suelto ni
    -- tamaño de member (fijo en codigo, ver Raid.lua ComputeGridSize).
    do
        local f = Section("r_layout")
        MakeHeader(f, "Growth direction", L, -6, 210)
        MakeCycle(f, "Grow to", { "LEFT", "RIGHT" }, "growPoint", L, -46)
        MakeCycle(f, "New rows stack", { "TOP", "BOTTOM" }, "columnAnchorPoint", L, -90)

        MakeHeader(f, "Limits", R, -6, 210)
        MakeSlider(f, "Units per row", 1, 40, 1, "unitsPerColumn", R, -46)
        MakeSlider(f, "Max rows", 1, 40, 1, "maxColumns", R, -100)

        MakeHeader(f, "Spacing", L, -140, 210)
        MakeSlider(f, "Between members (row)", -40, 40, 1, "growXOffset", L, -180)
        MakeSlider(f, "Between rows", -40, 60, 1, "columnSpacing", R, -180)

        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", L, -222); note:SetWidth(430); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("The grid always grows in rows: each row fills horizontally (left or right), and new rows stack either upward or downward. Member size is fixed to match AzeriteUI exactly.")
    end
    -- Raid / Pos (posicion del CONTENEDOR completo; se arrastra en Lock).
    do
        local f = Section("r_pos")
        MakeEditBox(f, "Anchor to (empty = screen)", "anchorFrame", L, -10, 200)
        -- Sin selector "Point" propio: el header SIEMPRE se ancla por su
        -- CENTER (fix 2026-07-20 de "los botones bloquean mover" -- asi
        -- SetSize agranda parejo hacia los 4 lados y los members, anclados a
        -- los bordes reales del header, siempre coinciden sin importar la
        -- direccion de crecimiento elegida en Layout).
        MakeCycle(f, "Rel. point", ns.POINT_VALUES, "relativePoint", L, -54)
        MakeSlider(f, "Offset X", -2000, 2000, 1, "offsetX", R, -10)
        MakeSlider(f, "Offset Y", -2000, 2000, 1, "offsetY", R, -54)
        MakeSlider(f, "Scale (wheel in Lock too)", 0.3, 3, 0.02, "scale", R, -98)

        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", L, -140); note:SetWidth(430); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("Only the whole grid moves as one in Lock mode — individual members are positioned by the grid itself, not draggable one by one.")
    end
    -- Nameplates / General. 2026-07-18 (pedido del usuario): TODO el control
    -- de posicion/tamaño (offsets, font size, width/height, icon size) vive
    -- ahora EXCLUSIVAMENTE en el Nameplate Designer (drag + rueda) -- los
    -- sliders equivalentes que habia aca se sacaron. Este menu de texto solo
    -- conserva lo que el Designer NO cubre: on/off, distancia/fade (CVars
    -- nativos), y colores (pestaña Colors).
    do
        local f = Section("np_general")

        -- Grupo 1: on/off + accesos rapidos (reorganizado 2026-07-19, pedido
        -- del usuario "organice un poco el menu de nameplates").
        MakeHeader(f, "General", L, -6, 430)
        MakeCheckbox(f, "Enabled", "enabled", L, -30)
        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", L, -54); note:SetWidth(430); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        -- Acortado 2026-07-19 (pedido del usuario: "aun siento que hay mucho
        -- texto, intenta resumirlo").
        note:SetText("Reskins Blizzard's nameplates to match this preset. Position/size are set in the Nameplate Designer, not here.")
        local resetBtn = MakeButton(f, "Reset nameplates", 200, 22)
        resetBtn:SetPoint("TOPLEFT", L, -84)
        resetBtn:SetScript("OnClick", function() ns.ResetUnit(ns.currentEdit) end)

        -- Canvas de diseño (drag + rueda) -- ver NameplateDesigner.lua. TODO
        -- el control de posicion/tamaño vive aca, no en sliders de texto.
        -- SetActive(true) (pedido del usuario: "que resalte mas") -- mismo
        -- estilo dorado que StyleButton ya usa para botones "activos", asi
        -- se distingue de Reset como la accion PRINCIPAL de esta pagina.
        local designBtn = MakeButton(f, "Open Nameplate Designer", 200, 24)
        designBtn:SetPoint("TOPLEFT", R, -83)
        designBtn:SetActive(true)
        -- Pedido del usuario 2026-07-19: "quiero que cuando abras el panel del
        -- nameplate, se cierre el menu" -- antes quedaban superpuestos.
        designBtn:SetScript("OnClick", function()
            if ns.ToggleNameplateDesigner then ns.ToggleNameplateDesigner() end
            if ns.CloseMainPanel then ns.CloseMainPanel() end
        end)

        -- Grupo 2: rango (CVar nativo de Blizzard).
        MakeHeader(f, "Range", L, -126, 430)
        MakeSlider(f, "Max distance", 10, 60, 1, "maxDistance", L, -176)
        local distNote = f:CreateFontString(nil, "ARTWORK"); setFont(distNote, 10)
        distNote:SetPoint("TOPLEFT", L, -220); distNote:SetWidth(210); distNote:SetJustifyH("LEFT")
        distNote:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        distNote:SetText("How far away nameplates render.")

        -- Grupo 3: modo "solo nombre" para jugadores + NPCs amistosos (sin pets).
        MakeHeader(f, "Name-only mode (friendly)", L, -252, 430)
        -- CAMBIADO (2026-07-19): jugadores amistosos (nombre con color de
        -- CLASE) + NPCs amistosos como vendedores/guardias (nombre con el
        -- color preestablecido del perfil) -- excluye mascotas/totems/
        -- guardianes con dueño jugador. El campo interno sigue llamandose
        -- nameOnlyFriendlyNeutral, no vale la pena migrarlo. Ver
        -- ShouldHideExceptName/ReassertNameGeometry en Nameplates.lua.
        -- FIX (2026-07-20, reportado por el usuario con captura: el texto largo de este
        -- checkbox se pisaba con el de al lado en la columna R -- L/R estan pensados para
        -- labels cortos, "Only show name on friendly players/NPCs" es demasiado largo para
        -- 226px de columna). Apilados en la misma columna (L) en vez de lado a lado.
        MakeCheckbox(f, "Only show name on friendly players/NPCs", "nameOnlyFriendlyNeutral", L, -276)
        -- Pedido del usuario 2026-07-19: solo nombre para NPCs de escolta/
        -- mision EN DUNGEON, via CVars nativos (funciona incluso en
        -- ForbiddenNamePlate, confirmado en vivo -- ver ApplyMaxDistanceNow
        -- en Nameplates.lua). Independiente del checkbox de arriba.
        MakeCheckbox(f, "Dungeon escort NPCs (native)", "showFriendlyNPCPlates", L, -300)
        local onlyNameNote = f:CreateFontString(nil, "ARTWORK"); setFont(onlyNameNote, 10)
        onlyNameNote:SetPoint("TOPLEFT", L, -324); onlyNameNote:SetWidth(430); onlyNameNote:SetJustifyH("LEFT")
        onlyNameNote:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        onlyNameNote:SetText("Players: colored by class. NPCs (vendors, guards, etc): preset color. Excludes pets and hostiles.")

        -- Offset PROPIO del modo de arriba (pedido del usuario): sin la barra
        -- visible, la posicion normal del nombre puede no quedar bien.
        MakeSlider(f, "Offset X", -100, 100, 1, "nameOnlyOffsetX", L, -374)
        MakeSlider(f, "Offset Y", -100, 100, 1, "nameOnlyOffsetY", R, -374)
    end

    -- Nueva pestaña "Alpha" (2026-07-19, pedido del usuario): 5 controles
    -- nativos de Blizzard (CVars) para la opacidad segun estado -- separados
    -- de "Gen" porque el panel no tiene scroll y no entraban todos juntos
    -- sin salirse de la ventana. Ver ApplyMaxDistanceNow/NameplateDefaults
    -- en Nameplates.lua.
    do
        local f = Section("np_alpha")
        MakeHeader(f, "Alpha", L, -6, 430)
        local intro = f:CreateFontString(nil, "ARTWORK"); setFont(intro, 10)
        intro:SetPoint("TOPLEFT", L, -30); intro:SetWidth(430); intro:SetJustifyH("LEFT")
        intro:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        intro:SetText("Native Blizzard nameplate opacity CVars, per state.")

        MakeSlider(f, "Min alpha", 0, 1, 0.05, "fadeMinAlpha", L, -80)
        MakeSlider(f, "Max alpha", 0, 1, 0.05, "alphaMax", R, -80)
        local minMaxNote = f:CreateFontString(nil, "ARTWORK"); setFont(minMaxNote, 10)
        minMaxNote:SetPoint("TOPLEFT", L, -124); minMaxNote:SetWidth(430); minMaxNote:SetJustifyH("LEFT")
        minMaxNote:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        minMaxNote:SetText("Opacity range across the max distance (see Gen tab).")

        MakeSlider(f, "Non-selected alpha", 0, 1, 0.05, "alphaNotSelected", L, -174)
        MakeSlider(f, "Target alpha", 0, 1, 0.05, "alphaTarget", R, -174)
        local selNote = f:CreateFontString(nil, "ARTWORK"); setFont(selNote, 10)
        selNote:SetPoint("TOPLEFT", L, -218); selNote:SetWidth(430); selNote:SetJustifyH("LEFT")
        selNote:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        selNote:SetText("Opacity override for your current target vs everything else.")

        MakeSlider(f, "Occluded alpha", 0, 1, 0.05, "alphaOccluded", L, -268)
        local occNote = f:CreateFontString(nil, "ARTWORK"); setFont(occNote, 10)
        occNote:SetPoint("TOPLEFT", L, -312); occNote:SetWidth(430); occNote:SetJustifyH("LEFT")
        occNote:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        occNote:SetText("Opacity when the plate is behind walls/objects.")
    end

    -- =========================== SECCION PARTY AURAS (TEST, 2026-07-16) ===========================
    -- Elemento SINGLETON (como Tracker/Glow): una sola seccion controla LAS 5 party frames a la
    -- vez (no hay edicion por-unidad, PartyAuraPreview.lua es deliberadamente global). Los
    -- settings (db.partyAuraDirection/partyAuraIconSize) son GLOBALES, no van en db.units — por
    -- eso los widgets usan getTbl/onChange en vez de getP()/OnEdit (patron ya usado para grid
    -- size/explorer en el resto del menu).
    do
        local f = Section("ap_general")
        MakeHeader(f, "Party Auras  —  hover/combat reveal", L, -6, 430)
        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", L, -32); note:SetWidth(430); note:SetJustifyH("LEFT")
        note:SetTextColor(0.8, 0.8, 0.8)
        note:SetText("Applies to ALL 5 party frames at once. Shows up to 4 auras (debuffs take " ..
            "priority, buffs fill empty slots) on mouseover, or fixed while the unit is in combat. " ..
            "Try /mcfpartytest to preview without a real group.")

        -- Direccion: boton ciclico (no hay MakeCycle generico para valores GLOBALES, se arma a
        -- mano igual que el resto de los botones ciclicos del addon).
        local dirBtn = MakeButton(f, "", 220, 24)
        dirBtn:SetPoint("TOPLEFT", L, -76)
        local function DirText()
            local d = ns.GetDB() and ns.GetDB().partyAuraDirection or "left"
            dirBtn.text:SetText("Direction: " .. d)
        end
        dirBtn:SetScript("OnClick", function()
            local list = ns.PARTY_AURA_DIRECTIONS or { "left", "right", "up", "down" }
            local d = ns.GetDB(); if not d then return end
            local cur, idx = d.partyAuraDirection or "left", 1
            for i, v in ipairs(list) do if v == cur then idx = i break end end
            d.partyAuraDirection = list[(idx % #list) + 1]
            DirText()
            if ns.RefreshPartyAuraDirection then ns.RefreshPartyAuraDirection() end
        end)
        refreshers[#refreshers + 1] = DirText

        MakeSlider(f, "Icon size", 12, 48, 1, "partyAuraIconSize", L, -120,
            function() return ns.GetDB() end,
            function() if ns.RefreshPartyAuraSize then ns.RefreshPartyAuraSize() end end)
    end

    -- =========================== SECCION ARENA AURAS (2026-07-19) ===========================
    -- Mismo patron que Party Auras (SINGLETON, settings GLOBALES db.arenaAuraDirection/
    -- arenaAuraIconSize) -- pedido del usuario: "todas esta auras esten en una casilla juntas
    -- de arena, asi como las de party", direccion por defecto "down".
    do
        local f = Section("aa_general")
        MakeHeader(f, "Arena Auras  —  hover/combat reveal", L, -6, 430)
        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", L, -32); note:SetWidth(430); note:SetJustifyH("LEFT")
        note:SetTextColor(0.8, 0.8, 0.8)
        note:SetText("Applies to ALL 6 arena frames at once (allies + enemies). Shows up to 4 auras " ..
            "(debuffs take priority, buffs fill empty slots) on mouseover, or fixed while the unit is " ..
            "in combat. Arena-only. Try /mcfarenaauratest to preview without a real match.")

        local dirBtn = MakeButton(f, "", 220, 24)
        dirBtn:SetPoint("TOPLEFT", L, -76)
        local function DirText()
            local d = ns.GetDB() and ns.GetDB().arenaAuraDirection or "down"
            dirBtn.text:SetText("Direction: " .. d)
        end
        dirBtn:SetScript("OnClick", function()
            local list = ns.ARENA_AURA_DIRECTIONS or { "left", "right", "up", "down" }
            local d = ns.GetDB(); if not d then return end
            local cur, idx = d.arenaAuraDirection or "down", 1
            for i, v in ipairs(list) do if v == cur then idx = i break end end
            d.arenaAuraDirection = list[(idx % #list) + 1]
            DirText()
            if ns.RefreshArenaAuraDirection then ns.RefreshArenaAuraDirection() end
        end)
        refreshers[#refreshers + 1] = DirText

        MakeSlider(f, "Icon size", 12, 48, 1, "arenaAuraIconSize", L, -120,
            function() return ns.GetDB() end,
            function() if ns.RefreshArenaAuraSize then ns.RefreshArenaAuraSize() end end)
    end

    -- =========================== SECCION CLASS POWER (2026-07-19) ===========================
    -- Singleton (como Party Auras/Tracker/Glow) -- combo points/holy power/chi/soul shards/
    -- arcane charges/essence, layout+texturas portadas de AzeriteUI. db.classpower es una
    -- SUB-TABLA (no el root de db), por eso getTbl devuelve ns.GetDB().classpower en vez de
    -- ns.GetDB() directo (patron distinto al de Party Auras, que SI guarda en el root).
    do
        local f = Section("cp_general")
        local function CPDB() return ns.GetDB() and ns.GetDB().classpower end
        MakeHeader(f, "Class Power", L, -6, 430)
        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", L, -32); note:SetWidth(430); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("Combo points, Holy Power, Chi, Soul Shards, Arcane Charges, Essence — auto-detects your class/spec's resource. Same layout and textures as AzeriteUI. Runes (Death Knight), Stagger (Brewmaster) and Soul Fragments (Demon Hunter) aren't supported yet. Try /mcfclasspowerdiag to check detection live.")

        local function Refresh() if ns.RefreshClassPower then ns.RefreshClassPower() end end
        local function RefreshRelayout()
            if ns.ClassPowerForceRelayout then ns.ClassPowerForceRelayout() end
            Refresh()
        end

        MakeToggle(f, "Enabled", L, -90,
            function() local d = CPDB(); return d and d.enabled end,
            function(v) local d = CPDB(); if d then d.enabled = v end; Refresh() end)

        MakeSlider(f, "Offset X", -800, 800, 1, "offsetX", L, -134, CPDB, Refresh)
        MakeSlider(f, "Offset Y", -800, 800, 1, "offsetY", R, -134, CPDB, Refresh)
        MakeSlider(f, "Scale", 0.3, 3, 0.02, "scale", L, -176, CPDB, Refresh)

        local ebLbl = f:CreateFontString(nil, "ARTWORK"); setFont(ebLbl, 11)
        ebLbl:SetPoint("TOPLEFT", R, -176); ebLbl:SetTextColor(COLOR_OPTION[1], COLOR_OPTION[2], COLOR_OPTION[3])
        ebLbl:SetText("Anchor to (frame; empty = screen)")
        local eb = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        eb:SetSize(180, 20); eb:SetPoint("TOPLEFT", ebLbl, "BOTTOMLEFT", 4, -4)
        eb:SetAutoFocus(false)
        eb:SetScript("OnShow", function(self) local d = CPDB(); self:SetText((d and d.anchorFrame) or "") end)
        eb:SetScript("OnEnterPressed", function(self)
            local d = CPDB(); if d then d.anchorFrame = self:GetText() or "" end
            Refresh(); self:ClearFocus()
        end)
        eb:SetScript("OnEditFocusLost", function(self)
            local d = CPDB(); self:SetText((d and d.anchorFrame) or "")
        end)
        refreshers[#refreshers + 1] = function() local d = CPDB(); eb:SetText((d and d.anchorFrame) or "") end

        MakeToggle(f, "Use resource color for lit points", L, -220,
            function() local d = CPDB(); return d and d.useClassColor ~= false end,
            function(v) local d = CPDB(); if d then d.useClassColor = v end; RefreshRelayout() end)
        MakeSlider(f, "Unlit point opacity", 0, 1, 0.05, "dimAlpha", R, -220, CPDB, Refresh)

        MakeGlobalColor(f, "Case/backdrop color", function() local d = CPDB(); return d and d.caseColor end,
            L, -252, RefreshRelayout)
    end

    -- =========================== SECCION SETUP (integracion + perfiles) ===========================
    -- 2026-07-17: reorganizada — los 2 parrafos densos ahora son bullets (via
    -- MakeBulletList) y todo el flujo vertical se calcula dinamicamente en vez
    -- de offsets fijos adivinados (que dejaban el header/parrafo siguiente muy
    -- pegados o el boton flotando lejos de su texto).
    do
        local f = Section("setup")
        MakeHeader(f, "Setup  —  addon integration & profiles", L, -6, 440)
        MakeHeader(f, "Apply bundled addon profiles", L, -32, 440)
        local y = MakeBulletList(f, {
            "Installs the bundled profiles for detected addons (Bartender4, DynamicCam, Masque, Chattynator) plus the Blizzard HUD Edit Mode layout, then reloads.",
            "|cffff5555Warning:|r this REPLACES those addons' current configuration.",
        }, L, -62, 440)

        local applyBtn = MakeButton(f, "Apply Profiles", 160, 24)
        applyBtn:SetPoint("TOPLEFT", L, y - 16)
        applyBtn:SetScript("OnClick", function() if ns.ApplyProfiles then ns.ApplyProfiles() end end)

        -- Lista de addons detectados (se refresca al abrir la seccion).
        local statusFS = f:CreateFontString(nil, "ARTWORK"); setFont(statusFS, 10)
        statusFS:SetPoint("TOPLEFT", applyBtn, "BOTTOMLEFT", 0, -12)
        statusFS:SetWidth(440); statusFS:SetJustifyH("LEFT"); statusFS:SetWordWrap(true)
        statusFS:SetTextColor(0.55, 0.85, 0.55)
        local function refreshStatus()
            local list = (ns.ProfilesStatus and ns.ProfilesStatus()) or {}
            if #list == 0 then statusFS:SetText("Detected: (none of the supported addons are loaded)")
            else statusFS:SetText("Detected: " .. table.concat(list, ", ")) end
        end
        refreshers[#refreshers + 1] = refreshStatus
    end

    -- =========================== SECCION EDITING (B5) ===========================
    do
        local f = Section("editing")
        MakeHeader(f, "Editing  —  layout tools", L, -6, 430)
        MakeToggle(f, "Preview / Move mode (/mcf)", L, -40,
            function() return ns.IsUnlocked() end,
            function() ns.SetUnlocked(not ns.IsUnlocked()) end)
        MakeToggle(f, "Show edit outline", L, -64,
            function() return not ns.GetDB().hideEditOutline end,
            function(v) ns.GetDB().hideEditOutline = not v; if ns.ToggleEditOutline then ns.ToggleEditOutline() end end)
        MakeToggle(f, "Secure button preview (hit area)", L, -88,
            function() return ns.GetDB().previewSecureButton end,
            function(v) ns.GetDB().previewSecureButton = v; if ns.RefreshAll then ns.RefreshAll() end end)
        -- Grid + Snap (movidos aqui desde Global options).
        MakeToggle(f, "Alignment grid", L, -120,
            function() return ns.GetDB().gridShow end,
            function(v) ns.GetDB().gridShow = v; if ns.UpdateGrid then ns.UpdateGrid() end end)
        MakeToggle(f, "Snap to grid (on release)", L, -144,
            function() return ns.GetDB().gridSnap end,
            function(v) ns.GetDB().gridSnap = v end)
        -- Texto acortado (el original, "Snap to other elements (edges/centers)", desbordaba la
        -- columna y se montaba sobre "Hide in preview" a la derecha — MakeToggle no envuelve ni
        -- trunca el texto). Detalle completo movido a un tooltip.
        local snapBtn = MakeToggle(f, "Snap to other elements", L, -168,
            function() return ns.GetDB().snapElements ~= false end,
            function(v) ns.GetDB().snapElements = v and true or false end)
        snapBtn:HookScript("OnEnter", function(self)
            if GameTooltip:IsForbidden() then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Snap to other elements' edges and centers while dragging.", 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        snapBtn:HookScript("OnLeave", function() if not GameTooltip:IsForbidden() then GameTooltip:Hide() end end)
        MakeToggle(f, "Open with Blizzard Edit Mode", L, -192,
            function() return ns.GetDB().syncBlizzEditMode ~= false end,
            function(v) ns.GetDB().syncBlizzEditMode = v and true or false end)
        -- Accesos directos a las otras secciones globales.
        local exBtn = MakeButton(f, "Explorer Mode", 150, 22)
        exBtn:SetPoint("TOPLEFT", R, -34)
        exBtn:SetScript("OnClick", function() ShowSection("explorer") end)
        local prBtn = MakeButton(f, "Profiles", 150, 22)
        prBtn:SetPoint("TOPLEFT", R, -64)
        prBtn:SetScript("OnClick", function() ShowSection("presets") end)
        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", L, -222); note:SetWidth(210); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("Per-unit outline width/height live in each unit's Bar tab. Move/Lock and Copy/Paste stay in the footer. 'Apply addon profiles' sets Bartender4/DynamicCam/Masque/Chattynator profiles.")
        -- B4: ocultar SAMPLE de elementos SOLO en preview (no afecta el juego real).
        local lhdr = f:CreateFontString(nil, "ARTWORK"); setFont(lhdr, 12)
        lhdr:SetPoint("TOPLEFT", R, -142); lhdr:SetTextColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
        lhdr:SetText("Hide in preview (Lock only):")
        local LH = { { "Hide text", "text" }, { "Outline names", "names" }, { "Badges", "badges" },
                     { "Raid marks", "raid" }, { "Death marks", "death" }, { "Quest tracker", "tracker" } }
        for i, e in ipairs(LH) do
            local lk = e[2]
            MakeToggle(f, e[1], R, -164 - (i - 1) * 24,
                function() return ns.GetDB().lockHide[lk] end,
                function(v)
                    ns.GetDB().lockHide[lk] = v or nil
                    if lk == "names" and ns.RefreshOutlineNames then ns.RefreshOutlineNames()
                    elseif lk == "tracker" and ns.ApplyTrackerPreviewHide then ns.ApplyTrackerPreviewHide()
                    elseif ns.RefreshAll then ns.RefreshAll() end
                end)
        end
        -- Segunda columna de "Hide in preview" (2026-07-20): la lista de arriba
        -- ya no tenia lugar vertical para mas entradas (se salia del panel,
        -- "no veo el panel" reportado) -- estas van en L, debajo de las demas
        -- opciones de esta seccion.
        local lhdr2 = f:CreateFontString(nil, "ARTWORK"); setFont(lhdr2, 12)
        lhdr2:SetPoint("TOPLEFT", L, -300); lhdr2:SetTextColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
        lhdr2:SetText("Hide in preview (cont.):")
        -- 2 mini-columnas (3 + 2) en vez de apilar las 5 en una sola columna:
        -- una sola columna se salia del panel (altura fija, sin scroll).
        local LH2 = { { "Minimap", "minimap" }, { "Portraits", "portraits" }, { "Info bar", "infobar" },
                      { "Micro menu", "micromenu" }, { "Raid frames", "raidframes" } }
        for i, e in ipairs(LH2) do
            local lk = e[2]
            local col = (i <= 3) and L or (L + 110)
            local row = (i <= 3) and i or (i - 3)
            MakeToggle(f, e[1], col, -322 - (row - 1) * 24,
                function() return ns.GetDB().lockHide[lk] end,
                function(v)
                    ns.GetDB().lockHide[lk] = v or nil
                    if ns.RefreshAll then ns.RefreshAll() end
                end)
        end
    end

    -- =========================== SECCION EXPLORER (#11) ===========================
    do
        local f = Section("explorer")
        MakeHeader(f, "Explorer  —  auto-hide, reveal on mouseover", L, -6, 430)
        local EXPLORER_LIST = {
            { "Player unit frame", "player" },
            { "Player portrait", "portrait_player" },
            { "Micro menu", "micromenu" },
            { "Info bar", "infobar" },
            { "Pet unit frame", "pet" },
            { "Target unit frame", "target" },
            { "Target portrait", "portrait_target" },
            { "Player auras", "aura_player" },
            { "Pet portrait", "portrait_pet" },
            { "Focus unit frame", "focus" },
        }
        -- Toggle MAESTRO: apaga el Explorer entero (los toggles por elemento se conservan).
        MakeToggle(f, "Enable Explorer (master switch)", L, -36,
            function() return ns.GetDB().explorerEnabled ~= false end,
            function(v)
                ns.GetDB().explorerEnabled = v and true or false
                if not v and ns.ExplorerResetAll then ns.ExplorerResetAll() end
            end)
        for i, e in ipairs(EXPLORER_LIST) do
            local col = (i <= 5) and L or R
            local yy = -70 - ((i - 1) % 5) * 28
            local key = e[2]
            MakeToggle(f, e[1], col, yy,
                function() return ns.GetDB().explorer[key] end,
                function(v)
                    ns.GetDB().explorer[key] = v or nil
                    if not v and ns.ExplorerReset then ns.ExplorerReset(key) end
                end)
        end
        MakeToggle(f, "Always show in combat", L, -206,
            function() return ns.GetDB().explorerCombat end,
            function(v) ns.GetDB().explorerCombat = v end)
        MakeToggle(f, "Always show on target", L, -230,
            function() return ns.GetDB().explorerTarget end,
            function(v) ns.GetDB().explorerTarget = v end)
        MakeToggle(f, "Always show while casting", R, -206,
            function() return ns.GetDB().explorerCasting end,
            function(v) ns.GetDB().explorerCasting = v end)
        MakeSlider(f, "Hidden opacity", 0, 1, 0.05, "explorerFadeAlpha", L, -272,
            function() return ns.GetDB() end, function() end)
        -- Filtro por TIPO DE CONTENIDO: donde el Explorer esta activo (B1b).
        local zhdr = f:CreateFontString(nil, "ARTWORK"); setFont(zhdr, 12)
        zhdr:SetPoint("TOPLEFT", R, -236); zhdr:SetTextColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
        zhdr:SetText("Active in:")
        local ZONES = {
            { "Open world", "world" }, { "Dungeons", "dungeon" }, { "Raids", "raid" },
            { "Arenas", "arena" }, { "Battlegrounds", "battleground" }, { "Scenarios / Delves", "scenario" },
        }
        for i, z in ipairs(ZONES) do
            local zk = z[2]
            MakeToggle(f, z[1], R, -258 - (i - 1) * 24,
                function() return ns.GetDB().explorerZones[zk] ~= false end,
                function(v)
                    ns.GetDB().explorerZones[zk] = v and true or false
                    if not v and ns.ExplorerResetAll then ns.ExplorerResetAll() end
                end)
        end
        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", L, -302); note:SetWidth(210); note:SetJustifyH("LEFT")
        note:SetTextColor(COLOR_DESC[1], COLOR_DESC[2], COLOR_DESC[3])
        note:SetText("Enabled elements fade out and reappear when you hover where they are (works even while hidden). Combat keeps them visible. 'Active in' limits Explorer to the chosen content types.")
    end

    -- ===== FOOTER: acciones =====
    -- Divisor Plumber separando el footer del contenido.
    local fdiv = panel:CreateTexture(nil, "ARTWORK")
    fdiv:SetTexture(PL.DIV_H)
    fdiv:SetPoint("BOTTOMLEFT", 10, 42); fdiv:SetPoint("BOTTOMRIGHT", -10, 42)
    fdiv:SetHeight(8); fdiv:SetVertexColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3], 0.30)

    -- 2026-07-17: tooltips para los botones del footer (antes no explicaban nada,
    -- a diferencia del resto del panel que ya tiene tooltips en varios lugares).
    local function AddTooltip(btn, title, desc)
        btn:HookScript("OnEnter", function()
            if GameTooltip:IsForbidden() then return end
            GameTooltip:SetOwner(btn, "ANCHOR_TOP")
            GameTooltip:SetText(title, COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
            if desc then GameTooltip:AddLine(desc, 1, 1, 1, true) end
            GameTooltip:Show()
        end)
        btn:HookScript("OnLeave", function() if not GameTooltip:IsForbidden() then GameTooltip:Hide() end end)
    end

    local moveBtn = MakeTabButton(panel, "Move / Lock (/mcf)", 170, 24)
    moveBtn:SetPoint("BOTTOMLEFT", 10, 22)
    moveBtn:SetScript("OnClick", function() ns.SetUnlocked(not ns.IsUnlocked()) end)
    panelButtons[#panelButtons + 1] = moveBtn
    AddTooltip(moveBtn, "Move / Lock", "Toggles edit mode: drag any element to reposition it. Same as typing /mcf.")

    -- 2026-07-17: se saco el boton "Preview" — hacia LITERAL lo mismo que
    -- Move/Lock (mismo click handler, `ns.SetUnlocked(not ns.IsUnlocked())`),
    -- confirmado con el usuario que era un duplicado sin proposito propio.
    -- Mientras esta en modo edicion (Move/Lock activo), la ventana se atenua al
    -- 30% para poder organizar los elementos de fondo sin cerrarla — vuelve a
    -- 100% en cuanto el mouse pasa por encima del panel (mouseover = opaco,
    -- mouseout = atenuado, SOLO mientras esta lockeado/en edicion).
    -- 2026-07-17 (ronda 2): transicion animada (UIFrameFadeIn/Out) en vez del
    -- salto brusco de SetAlpha.
    local editAlphaActive = false
    local function UpdatePanelAlpha()
        -- FIX (2026-07-20, "el edit mode nativo me abre el menu del addon"):
        -- UIFrameFadeIn/UIFrameFadeOut llaman Show() INTERNAMENTE para poder
        -- animar el fade -- si esta funcion corre con el panel CERRADO (ej.
        -- ns.OnUnlockChanged disparado por el hook de Edit Mode nativo, sin
        -- que el usuario haya abierto el panel el mismo), esos Show() lo
        -- abren solo. El dimming al entrar/salir de Lock solo tiene sentido
        -- si el panel YA esta abierto -- si esta cerrado, no hay nada que
        -- atenuar, listo.
        if not panel:IsShown() then return end
        local target = (editAlphaActive and not panel:IsMouseOver()) and 0.3 or 1
        if UIFrameFadeIn and UIFrameFadeOut then
            if target == 1 then UIFrameFadeIn(panel, 0.25, panel:GetAlpha(), 1)
            else UIFrameFadeOut(panel, 0.25, panel:GetAlpha(), 0.3) end
        else
            panel:SetAlpha(target)
        end
    end
    panel:HookScript("OnEnter", UpdatePanelAlpha)
    panel:HookScript("OnLeave", UpdatePanelAlpha)

    ns.OnUnlockChanged = function(state)
        moveBtn:SetActive(state)
        if ns.ApplyTrackerPreviewHide then ns.ApplyTrackerPreviewHide() end
        editAlphaActive = state
        UpdatePanelAlpha()
    end

    local greenBtn = MakeTabButton(panel, "Outline: ON", 104, 24)
    greenBtn:SetPoint("LEFT", moveBtn, "RIGHT", 6, 0)
    local function updGreen()
        local hidden = ns.GetDB().hideEditOutline
        local txt = hidden and "Outline: OFF" or "Outline: ON"
        greenBtn.text:SetText(txt)
        greenBtn._label = txt   -- el label es DINAMICO: ReassertLabels debe reaplicar EL ACTUAL, no el de creacion
        greenBtn:SetActive(hidden)
    end
    greenBtn:SetScript("OnClick", function()
        local d = ns.GetDB()
        d.hideEditOutline = not (d.hideEditOutline and true or false)
        ns.ToggleEditOutline(); updGreen()
    end)
    refreshers[#refreshers + 1] = updGreen
    panelButtons[#panelButtons + 1] = greenBtn
    AddTooltip(greenBtn, "Outline", "Toggles the edit outline shown around elements while in Move/Lock mode.")

    -- 2026-07-17: Copy/Paste se movieron junto al titulo de unidad (esquina
    -- superior derecha del contenido, ver unitCopyBtn/unitPasteBtn). En su
    -- lugar en el footer van 2 accesos rapidos: Reset ALL y abrir el wizard
    -- de Setup.
    local resetAllFooterBtn = MakeTabButton(panel, "Reset ALL", 100, 24)
    resetAllFooterBtn:SetPoint("LEFT", greenBtn, "RIGHT", 6, 0)
    resetAllFooterBtn:SetScript("OnClick", function() StaticPopup_Show("MYCF_RESETALL") end)
    panelButtons[#panelButtons + 1] = resetAllFooterBtn
    AddTooltip(resetAllFooterBtn, "Reset ALL", "Resets everything to the default preset (or factory values if none is marked as default).")

    local wizardBtn = MakeTabButton(panel, "Setup Wizard", 120, 24)
    wizardBtn:SetPoint("LEFT", resetAllFooterBtn, "RIGHT", 6, 0)
    wizardBtn:SetScript("OnClick", function() if ns.ShowSetupWizard then ns.ShowSetupWizard() end end)
    panelButtons[#panelButtons + 1] = wizardBtn
    AddTooltip(wizardBtn, "Setup Wizard", "Reopens the first-install wizard (addon integration, profiles, Explorer Mode, etc).")

    -- Pedido del usuario 2026-07-19: boton para testear el hover de las
    -- auras de Party + Arena sin necesitar grupo/partido real -- togglea
    -- AMBOS sistemas a la vez (PartyAuraPreview.lua/ArenaAuraPreview.lua).
    local auraTestBtn = MakeTabButton(panel, "Test Aura Hover", 150, 24)
    auraTestBtn:SetPoint("LEFT", wizardBtn, "RIGHT", 6, 0)
    auraTestBtn:SetScript("OnClick", function()
        local state = false
        if ns.TogglePartyAuraTest then state = ns.TogglePartyAuraTest() end
        if ns.ToggleArenaAuraTest then state = ns.ToggleArenaAuraTest() end
        auraTestBtn:SetActive(state and true or false)
    end)
    panelButtons[#panelButtons + 1] = auraTestBtn
    AddTooltip(auraTestBtn, "Test Aura Hover", "Shows placeholder auras on Party + Arena frames to test the hover/combat reveal, without needing a real group or match. Same as /mcfpartytest + /mcfarenaauratest.")

    -- Pedido del usuario 2026-07-19: mismo boton "Set default" de la pestaña
    -- Profile, tambien accesible desde el footer (usa el preset seleccionado
    -- ahi mismo -- ver ns.SetDefaultToSelectedPreset/GetSelectedPresetName).
    local setDefaultBtn = MakeTabButton(panel, "Set Default", 110, 24)
    setDefaultBtn:SetPoint("LEFT", auraTestBtn, "RIGHT", 6, 0)
    setDefaultBtn:SetScript("OnClick", function()
        if ns.SetDefaultToSelectedPreset then ns.SetDefaultToSelectedPreset() end
    end)
    panelButtons[#panelButtons + 1] = setDefaultBtn
    AddTooltip(setDefaultBtn, "Set Default", "Marks the preset currently selected in the Profile tab as the default (used by Reset ALL and fresh installs).")

    -- 2026-07-17: centrar el grupo entero (estaba pegado a la izquierda). Como
    -- greenBtn/resetAllFooterBtn/wizardBtn/auraTestBtn/setDefaultBtn estan
    -- anclados EN CADENA relativos a moveBtn, alcanza con re-anclar solo
    -- moveBtn — el resto se mueve con el.
    local totalW = setDefaultBtn:GetRight() - moveBtn:GetLeft()
    moveBtn:ClearAllPoints()
    moveBtn:SetPoint("BOTTOM", panel, "BOTTOM", -totalW / 2 + moveBtn:GetWidth() / 2, 22)

    -- GUARD permanente contra el bug del canvas de Settings: su pase de layout a veces
    -- RE-MUESTRA secciones que ya habiamos ocultado, superponiendolas sobre la activa
    -- (de ahi el "el menu se desordena/desaparece y se arregla al salir y volver").
    -- Cada seccion se AUTO-OCULTA si el canvas la muestra sin ser la seccion activa.
    -- Es event-driven (sin polling) y permanente, no depende del timing de los timers.
    for key, f in pairs(sections) do
        f:HookScript("OnShow", function(self)
            if currentSection and key ~= currentSection then self:Hide() end
        end)
    end
end

-- El bug del canvas de Settings no solo re-muestra secciones ocultas: a veces tambien
-- deja botones existentes y VISIBLES con su FontString en blanco (el boton se ve, el
-- texto no) tras un pase de layout, hasta salir y volver a entrar. Reasertar el texto
-- (no solo la visibilidad) fuerza a WoW a recachear el glyph string. Barato: son punteros
-- a FontStrings ya creados, sin crear frames nuevos.
-- 2026-07-15 (ronda 4): reaplicar `SetText(mismo string que ya tiene)` NO alcanzaba — el bug
-- seguia en botones YA cubiertos por panelButtons/unitTabs (ej. "Paste", "ToT"). Sospecha: si el
-- string nuevo es IGUAL al actual, FontString:SetText puede saltarse el recomputo interno (no-op
-- de optimizacion) y el glyph en blanco (bug del cliente al rasterizar el atlas de fuente durante
-- el pase de layout del canvas) nunca se vuelve a intentar. FIX: forzar un cambio REAL vaciando
-- primero (`SetText("")`) y recien despues poniendo el label — eso garantiza que WoW detecte una
-- diferencia y re-renderice el glyph, sin importar si el string visible ya "parecia" correcto.
local function ReassertText(fs, label)
    fs:SetText("")
    fs:SetText(label)
end
local function ReassertLabels()
    for _, b in pairs(sectionTabs) do
        if b._label and b.text then ReassertText(b.text, b._label) end
    end
    for _, b in pairs(unitTabs) do
        if b._label and b.text then ReassertText(b.text, b._label) end
    end
    -- panelButtons: botones parentados directo a `panel` (Profile/Explorer/Editing/Setup arriba,
    -- Move-Lock/Preview/Outline/Copy/Paste abajo) — quedaban FUERA de esta red de seguridad hasta
    -- la ronda 3 (ver comentario en la declaracion de `panelButtons`).
    for _, b in ipairs(panelButtons) do
        if b._label and b.text then ReassertText(b.text, b._label) end
    end
end

local function ApplyPanelView()
    SelectUnit(ns.currentEdit or "player")
    ShowSection(currentSection)   -- ShowSection ya hace el nudge de la seccion activa
    ReassertLabels()
    -- Nudge del CONTENEDOR completo: fuerza el relayout de tabs + botones globales que a
    -- veces no aparecen hasta salir y volver (bug del canvas de Settings).
    if panel._content and panel._content:IsShown() then
        panel._content:Hide(); panel._content:Show()
    end
end

-- 2026-07-15: los 5 reintentos puntuales (0/0.05/0.15/0.3/0.6s) seguian sin alcanzar a veces
-- (el usuario seguia viendo botones/labels en blanco al entrar, "arreglado" solo saliendo y
-- volviendo a entrar) — el pase de layout del canvas de Settings no tiene un tiempo fijo, en
-- paneles grandes (muchas secciones/sliders) puede tardar mas que 0.6s. En vez de agregar MAS
-- timers puntuales a mano (parche sobre parche), se reemplaza por un TICKER corto: reintenta
-- cada 0.1s durante 2s completos (20 intentos) mientras el panel este visible, y se auto-cancela
-- al terminar la ventana o si el panel se cierra antes. Barato (ApplyPanelView es solo Hide/Show +
-- SetText, no crea nada) y cubre pases de layout lentos sin adivinar un numero magico de reintentos.
-- 2026-07-17: el retryTicker (reintentaba ApplyPanelView cada 0.1s durante 2s
-- completos) era un parche para un bug especifico del CANVAS de Blizzard Settings
-- (su pase de layout no tenia tiempo fijo). Desde que el panel es un frame
-- standalone (Fase A, ya no usa Settings.RegisterCanvasLayoutCategory) ese bug ya
-- no aplica — y el ticker causaba el parpadeo real que reporto el usuario: cada
-- reintento volvia a llamar ShowSection(), que re-dispara el fade-in de la
-- seccion activa, o sea la seccion se desvanecia y reaparecia ~20 veces seguidas
-- en los primeros 2 segundos tras abrir. Se elimina el ticker por completo.
panel:SetScript("OnShow", function()
    if not ns.GetDB() then return end
    if not built then BuildPanel() built = true end
    ApplyPanelView()
    panel:SetAlpha(1)
end)

-- Construir el panel POR ADELANTADO (una vez que exista la DB) en lugar de
-- perezosamente en el primer OnShow, para que este listo apenas se invoque
-- /mcfmenu por primera vez.
local builder = CreateFrame("Frame")
builder:RegisterEvent("PLAYER_LOGIN")
builder:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if not built and ns.GetDB() then
        BuildPanel()
        built = true
    end
    -- AddOn Compartment (2026-07-17): el icono de rompecabezas junto al minimapa,
    -- disponible desde Dragonflight — el usuario no quiere depender solo de
    -- /mcfmenu. Es el reemplazo moderno de "clic derecho > Opciones" para addons
    -- que no usan un panel nativo de Blizzard Settings (dejamos de usar ese
    -- sistema en la Fase A al pasar a frame standalone estilo Plumber). Se
    -- registra aca (PLAYER_LOGIN) en vez de al cargar el archivo, para asegurar
    -- que AddonCompartmentFrame ya exista.
    if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
        AddonCompartmentFrame:RegisterAddon({
            -- 2026-07-17: nombre de VISUALIZACION, no el nombre real del addon
            -- (que sigue siendo MyCustomFrames en el .toc) — el usuario quiere
            -- ver "AzeriteUI - Gonkast Preset" en el minimapa/menu de addons.
            text = "AzeriteUI - Gonkast Preset",
            icon = "Interface\\AddOns\\" .. ADDON .. "\\Assets\\addon_icon.tga",
            notCheckable = true,
            func = function()
                if not built and ns.GetDB() then BuildPanel(); built = true end
                if built then ns.ToggleControlCenter() end
            end,
        })
    end

    -- FALLBACK garantizado (2026-07-17): el usuario no encontro el icono del
    -- AddOn Compartment (puede no existir todavia en este build de Midnight, o
    -- estar oculto). Settings.RegisterCanvasLayoutCategory es una API mucho mas
    -- vieja/estable — se registra una entrada MINIMA (no el panel entero, que ya
    -- es standalone) en Interface Options > AddOns con solo un boton "Open Panel".
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local miniPanel = CreateFrame("Frame")
        miniPanel.name = "AzeriteUI - Gonkast Preset"
        local openBtn = CreateFrame("Button", nil, miniPanel, "UIPanelButtonTemplate")
        openBtn:SetSize(200, 26)
        openBtn:SetPoint("TOPLEFT", 16, -16)
        openBtn:SetText("Open Options Panel")
        openBtn:SetScript("OnClick", function()
            if not built and ns.GetDB() then BuildPanel(); built = true end
            if built then ns.ToggleControlCenter() end
        end)
        local hint = miniPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        hint:SetPoint("TOPLEFT", openBtn, "BOTTOMLEFT", 0, -10)
        hint:SetText("Or type /mcfmenu, or click the AddOn Compartment icon (puzzle piece near the minimap).")
        local miniCategory = Settings.RegisterCanvasLayoutCategory(miniPanel, miniPanel.name)
        miniCategory.ID = miniPanel.name
        Settings.RegisterAddOnCategory(miniCategory)
    end

    -- Boton de MINIMAPA (2026-07-17): el addon no tiene ninguna libreria tipo
    -- LibDBIcon embebida, asi que se implementa a mano — arrastrable alrededor
    -- del minimapa (angulo guardado en db), click abre/cierra el panel.
    local mmBtn = CreateFrame("Button", "MyCF_MinimapButton", Minimap)
    mmBtn:SetSize(31, 31)
    mmBtn:SetFrameStrata("MEDIUM")
    mmBtn:SetFrameLevel(8)
    mmBtn:RegisterForClicks("LeftButtonUp")
    mmBtn:RegisterForDrag("LeftButton")

    local mmIcon = mmBtn:CreateTexture(nil, "ARTWORK")
    mmIcon:SetTexture("Interface\\AddOns\\" .. ADDON .. "\\Assets\\addon_icon.tga")
    mmIcon:SetSize(20, 20)
    mmIcon:SetPoint("CENTER", 0, 1)

    local mmBorder = mmBtn:CreateTexture(nil, "OVERLAY")
    mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    mmBorder:SetSize(54, 54)
    mmBorder:SetPoint("TOPLEFT")

    local function UpdateMinimapPos()
        local d = ns.GetDB()
        local angle = (d and d.minimapButtonAngle) or 200
        local rad = math.rad(angle)
        local r = 80
        mmBtn:ClearAllPoints()
        mmBtn:SetPoint("CENTER", Minimap, "CENTER", r * math.cos(rad), r * math.sin(rad))
    end

    mmBtn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            px, py = px / scale, py / scale
            local angle = math.deg(math.atan2(py - my, px - mx))
            local d = ns.GetDB()
            if d then d.minimapButtonAngle = angle end
            UpdateMinimapPos()
        end)
    end)
    mmBtn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    -- Shift+click abre el Nameplate Designer directo (pedido del usuario
    -- 2026-07-19) -- click normal sigue abriendo el panel de siempre.
    mmBtn:SetScript("OnClick", function()
        if IsShiftKeyDown() then
            if ns.ToggleNameplateDesigner then ns.ToggleNameplateDesigner() end
            return
        end
        if not built and ns.GetDB() then BuildPanel(); built = true end
        if built then ns.ToggleControlCenter() end
    end)
    mmBtn:SetScript("OnEnter", function(self)
        if GameTooltip:IsForbidden() then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("AzeriteUI - Gonkast Preset", COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
        GameTooltip:AddLine("Click to open the options panel.", 1, 1, 1)
        GameTooltip:AddLine("Shift+click to open the Nameplate Designer.", 1, 1, 1)
        GameTooltip:AddLine("Drag to move this button.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    mmBtn:SetScript("OnLeave", function() if not GameTooltip:IsForbidden() then GameTooltip:Hide() end end)

    UpdateMinimapPos()
end)

-- Abre el panel de opciones standalone (reemplaza la categoria de Blizzard Settings).
SLASH_MCFMENU1 = "/mcfmenu"
SlashCmdList["MCFMENU"] = function()
    if not built and ns.GetDB() then BuildPanel(); built = true end
    if built then ns.ToggleControlCenter() end
end

-- Expone el toolkit de estilo del panel (botones/toggles/headers Plumber-style) para otros
-- archivos que necesiten la misma UI sin duplicarla, p.ej. el wizard de primera instalacion
-- (Setup.lua).
ns.UI = {
    MakeButton = MakeButton,
    MakeToggle = MakeToggle,
    MakeHeader = MakeHeader,
    ThreeSlice = ThreeSlice,
    setFont    = setFont,
    clamp      = clamp,
}
