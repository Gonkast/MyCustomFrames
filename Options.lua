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

local getP = function() return ns.CurrentProfile() end
local OnEdit = function() ns.ApplyCurrent() end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local refreshers = {}
local function RefreshControls() for _, f in ipairs(refreshers) do f() end end
ns.OnProfilePasted = RefreshControls
ns.OnDragStopped = function(k) if k == ns.currentEdit then RefreshControls() end end
ns.OnScaleWheel = RefreshControls   -- la rueda en modo Lock cambio una escala: refresca sliders

-- Paleta de colores de Plumber (hex pedidos por el usuario): titulos 786553, texto de
-- descripcion 7f7a72, lineas/divisores 7f6b59, opciones/checkboxes 877866. Reemplaza el
-- dorado (1, 0.82, 0.20) que tenia el panel antes; mismos valores que usa Setup.lua.
local COLOR_TITLE  = { 0x78 / 255, 0x65 / 255, 0x53 / 255 }
local COLOR_DESC   = { 0x7f / 255, 0x7a / 255, 0x72 / 255 }
local COLOR_LINE   = { 0x7f / 255, 0x6b / 255, 0x59 / 255 }
local COLOR_OPTION = { 0x87 / 255, 0x78 / 255, 0x66 / 255 }

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
    txt:SetTextColor(0.92, 0.86, 0.70)
    b.text = txt

    function b:SetActive(on)
        if on then
            for _, t in ipairs(parts) do t:SetVertexColor(1.0, 0.82, 0.35) end
            txt:SetTextColor(1, 1, 1)          -- blanco: se lee sobre el boton oscuro
        else
            for _, t in ipairs(parts) do t:SetVertexColor(1, 1, 1) end
            txt:SetTextColor(0.90, 0.85, 0.70)
        end
    end
    return b
end

local function MakeButton(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent)
    StyleButton(b, w or 100, h or 22)
    b.text:SetText(text)
    b._label = text
    return b
end

local function MakeHeader(parent, text, x, y, width)
    local fs = parent:CreateFontString(nil, "ARTWORK")
    setFont(fs, 14)
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetTextColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
    fs:SetText(text)
    local div = parent:CreateTexture(nil, "ARTWORK")
    div:SetTexture(PL.DIV_H)
    div:SetSize(width or 250, 8)
    div:SetPoint("TOPLEFT", x, y - 16)
    div:SetVertexColor(COLOR_LINE[1], COLOR_LINE[2], COLOR_LINE[3], 0.4)
    fs.div = div   -- expuesto para que otros archivos (p.ej. Setup.lua) puedan re-tenirlo
    return fs
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
    lbl:SetTextColor(0.9, 0.88, 0.82)

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
    box:SetScript("OnEscapePressed", function(self) self:SetText(fmtVal(get()[dbKey])); self:ClearFocus() end)

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
    lbl:SetTextColor(0.9, 0.88, 0.82)
    lbl:SetText(label)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(width or 200, 20)
    eb:SetPoint("TOPLEFT", x + 4, y - 15)
    eb:SetAutoFocus(false)
    eb:SetScript("OnEnterPressed", function(self) getP()[dbKey] = self:GetText(); self:ClearFocus(); OnEdit() end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
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
    local p = CreateFrame("Frame", nil, UIParent)
    p:SetSize(252, 340)
    p:SetFrameStrata("FULLSCREEN_DIALOG")
    p:EnableMouse(true)
    p:Hide()
    local bg = p:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.04, 0.04, 0.05, 0.96)
    local ttl = p:CreateFontString(nil, "OVERLAY"); setFont(ttl, 13)
    ttl:SetPoint("TOPLEFT", 10, -8); ttl:SetTextColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3]); ttl:SetText("Choose texture")
    local close = MakeButton(p, "X", 22, 20); close:SetPoint("TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function() p:Hide() end)
    local sf = CreateFrame("ScrollFrame", nil, p)
    sf:SetPoint("TOPLEFT", 8, -34); sf:SetPoint("BOTTOMRIGHT", -8, 8)
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
        p.pool[i] = r
    end
    return r
end

local function OpenTexPopup(category, dbKey, anchor, getTbl, onChange)
    local get = getTbl or getP
    local edit = onChange or OnEdit
    local p = GetTexPopup()
    local files = (ns.TEX_LIB and ns.TEX_LIB[category]) or {}
    local i, y = 0, -2
    for _, skin in ipairs(ns.TEX_SKINS or {}) do
        if #files > 0 then
            i = i + 1; local h = AcquireTexRow(p, i)
            h.sw:Hide(); h.tx:ClearAllPoints(); h.tx:SetPoint("LEFT", 4, 0)
            h.tx:SetText("|cffffcc00" .. (skin.label or "Skin") .. "|r")
            h:SetPoint("TOPLEFT", 0, y); h:Disable(); h:Show(); y = y - 20
            for _, file in ipairs(files) do
                i = i + 1; local r = AcquireTexRow(p, i)
                local path = (ns.ASSETS or "") .. (skin.folder or "") .. file
                r.sw:Show(); r.sw:SetTexture(path)
                r.tx:ClearAllPoints(); r.tx:SetPoint("LEFT", r.sw, "RIGHT", 6, 0); r.tx:SetText(file)
                r:SetPoint("TOPLEFT", 0, y); r:Enable()
                r:SetScript("OnClick", function()
                    get()[dbKey] = path; edit(); RefreshControls(); p:Hide()
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

-- Editbox (ruta manual) + swatch de preview + boton "..." que abre el selector.
local function MakeTexturePicker(parent, label, dbKey, category, x, y, getTbl, onChange)
    local get = getTbl or getP
    local edit = onChange or OnEdit
    local lbl = parent:CreateFontString(nil, "ARTWORK"); setFont(lbl, 11)
    lbl:SetPoint("TOPLEFT", x, y); lbl:SetTextColor(0.9, 0.88, 0.82); lbl:SetText(label)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(138, 20); eb:SetPoint("TOPLEFT", x + 4, y - 15); eb:SetAutoFocus(false)
    eb:SetScript("OnEnterPressed", function(self) get()[dbKey] = self:GetText(); self:ClearFocus(); edit() end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local sw = parent:CreateTexture(nil, "OVERLAY"); sw:SetSize(20, 20); sw:SetPoint("LEFT", eb, "RIGHT", 6, 0)
    local pick = MakeButton(parent, "...", 24, 20); pick:SetPoint("LEFT", sw, "RIGHT", 6, 0)
    pick:SetScript("OnClick", function() OpenTexPopup(category, dbKey, pick, getTbl, onChange) end)
    refreshers[#refreshers + 1] = function()
        local v = get()[dbKey]
        eb:SetText(v or "")
        if v and v ~= "" then sw:SetTexture(v); sw:Show() else sw:Hide() end
    end
    return eb
end

-- ==========================================================================
-- POPUP EXPORTAR / IMPORTAR (editbox multilinea copiable)
-- ==========================================================================
local ioPopup
local function GetIOPopup()
    if ioPopup then return ioPopup end
    local p = CreateFrame("Frame", nil, UIParent)
    p:SetSize(440, 300); p:SetFrameStrata("FULLSCREEN_DIALOG"); p:EnableMouse(true); p:Hide()
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
    eb:SetMaxLetters(99999); eb:SetWidth(400)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
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
    hint:SetPoint("BOTTOMLEFT", 12, 16); hint:SetTextColor(0.7, 0.7, 0.7); p.hint = hint
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
-- ==========================================================================
local panel = CreateFrame("Frame")
panel.name = "AzeriteUI — Gonkast Preset"

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
local powerHidden, colorHidden, nameSectionKeys = {}, {}, { name = true, spell = true }
local portraitDualBoxes = {}   -- grupos visibles solo si el portrait tiene dualPos
local portraitModelOnly = {}   -- widgets visibles solo si el retrato es modelo 3D (no icono)
local portraitPlayerOnly = {}  -- widgets visibles solo en el player portrait
local portraitFocusOnly = {}   -- widgets visibles solo en el focus portrait (texto vida + highlight)
local portraitRoleOnly = {}    -- widgets visibles solo si el portrait tiene rol (party)
local auraDualBoxes = {}       -- grupos visibles solo si el aura tiene dualPos (player)
local perfilBtn                -- boton "Profile" global (esquina superior derecha)
local explorerBtn              -- boton "Explorer" global (al lado de Profile)
local editingBtn               -- boton "Editing" global (herramientas de edicion, B5)
local setupBtn                 -- boton "Setup" global (integracion / perfiles de otros addons)
local currentSection = "general"

local function ShowSection(key)
    if not sections[key] then return end
    currentSection = key
    for k, f in pairs(sections) do f:SetShown(k == key) end
    for k, b in pairs(sectionTabs) do b:SetActive(k == key) end
    if perfilBtn then perfilBtn:SetActive(key == "presets") end
    if explorerBtn then explorerBtn:SetActive(key == "explorer") end
    if editingBtn then editingBtn:SetActive(key == "editing") end
    if setupBtn then setupBtn:SetActive(key == "setup") end
    -- Nudge: fuerza el relayout de la seccion recien mostrada. El canvas de Settings a
    -- veces no posiciona/renderiza los widgets hasta un Hide/Show (de ahi el bug de
    -- "botones que no aparecen hasta salir y volver"). Aplicarlo en CADA cambio de seccion.
    local f = sections[key]
    if f and f:IsShown() then f:Hide(); f:Show() end
end

local function IsPortraitSection(k) return k:sub(1, 2) == "p_" end
local function IsAuraSection(k) return k:sub(1, 2) == "a_" end
local function IsInfoSection(k) return k:sub(1, 2) == "i_" end
local function IsMicroSection(k) return k:sub(1, 3) == "mm_" end
local function IsChatSection(k) return k:sub(1, 3) == "cb_" end
local function IsTrackerSection(k) return k:sub(1, 2) == "t_" end
local function IsGlowSection(k) return k:sub(1, 2) == "g_" end

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

    local isInfo = ns.IsInfoBar and ns.IsInfoBar(key)
    local isMicro = ns.IsMicroMenu and ns.IsMicroMenu(key)
    local isChat = ns.IsChatBubble and ns.IsChatBubble(key)
    local isTracker = ns.IsTracker and ns.IsTracker(key)
    local isGlow = ns.IsGlow and ns.IsGlow(key)
    local isAura = ns.IsAura and ns.IsAura(key)
    local isPortrait = ns.IsPortrait and ns.IsPortrait(key)
    local u = (isAura and ns.auras[key]) or (isPortrait and ns.portraits[key]) or ns.frames[key]
    local title = isInfo and "Info Bar" or isMicro and "Micro Menu" or isChat and "Chat Bubble"
        or isTracker and "Quest Tracker" or isGlow and "Assisted Glow"
        or (u and u.label) or key
    if unitTitle then unitTitle:SetText("Editing:  |cffffffff" .. title .. "|r") end

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

    if isAura then
        local dual = ns.AuraIsDual and ns.AuraIsDual(key)
        for k, b in pairs(sectionTabs) do
            if k == "a_dead" then b:SetShown(dual and true or false)
            elseif IsAuraSection(k) then b:SetShown(true)
            else b:SetShown(false) end
        end
        for _, w in ipairs(auraDualBoxes) do w:SetShown(dual and true or false) end
        local okSec = IsAuraSection(currentSection) and (currentSection ~= "a_dead" or dual)
        if not okSec then ShowSection("a_general") end
        return
    end

    if isPortrait then
        local feats = (ns.PortraitFeatures and ns.PortraitFeatures(key)) or {}
        local kind = (ns.PortraitKind and ns.PortraitKind(key)) or "model"
        local isFocus = (key == "portrait_focus")
        for k, b in pairs(sectionTabs) do
            b:SetShown(IsPortraitSection(k) and PortraitSectionAllowed(k, feats)
                and (k ~= "p_focus" or isFocus))
        end
        for _, w in ipairs(portraitDualBoxes) do w:SetShown(feats.dualPos and true or false) end
        for _, w in ipairs(portraitModelOnly) do w:SetShown(kind == "model") end
        for _, w in ipairs(portraitPlayerOnly) do w:SetShown(key == "portrait_player") end
        for _, w in ipairs(portraitFocusOnly) do w:SetShown(isFocus) end
        for _, w in ipairs(portraitRoleOnly) do w:SetShown(feats.roleLeader and true or false) end
        local okSection = IsPortraitSection(currentSection)
            and PortraitSectionAllowed(currentSection, feats)
            and (currentSection ~= "p_focus" or isFocus)
        if not okSection then ShowSection("p_general") end
        return
    end

    -- Unidad normal.
    local isPower = u and u.kind == "power"
    local noColor = isPower or (u and u.fixedColor ~= nil)
    local hasName = u and u.nameText
    for _, f in ipairs(powerHidden) do f:SetShown(not isPower) end
    for _, f in ipairs(colorHidden) do f:SetShown(not noColor) end
    for k, b in pairs(sectionTabs) do
        if IsPortraitSection(k) or IsAuraSection(k) or IsInfoSection(k) or IsMicroSection(k) or IsChatSection(k) or IsTrackerSection(k) or IsGlowSection(k) then b:SetShown(false)
        elseif nameSectionKeys[k] then b:SetShown(hasName and true or false)
        elseif k == "cast" or k == "highlight" then b:SetShown(not isPower)
        else b:SetShown(true) end
    end
    if IsPortraitSection(currentSection) or IsAuraSection(currentSection) or IsInfoSection(currentSection)
       or IsMicroSection(currentSection) or IsChatSection(currentSection) or IsTrackerSection(currentSection)
       or IsGlowSection(currentSection)
       or currentSection == "presets" or currentSection == "explorer" or currentSection == "editing"
       or currentSection == "setup"
       or (nameSectionKeys[currentSection] and not hasName)
       or ((currentSection == "cast" or currentSection == "highlight") and isPower) then
        ShowSection("general")
    end
end

-- ---- Construccion -------------------------------------------------------
local UNIT_GROUPS = {
    { title = "MAIN", keys = { "player", "target", "targettarget", "pet" } },   -- focus: config solo en su portrait (#5)
    { title = "POWER",     keys = { "playerpower", "targetpower" } },
    { title = "BOSSES",     keys = { "boss1", "boss2", "boss3", "boss4", "boss5" } },
    { title = "GROUP",     keys = { "party1", "party2", "party3", "party4", "party5" } },
    { title = "PORTRAITS", keys = { "portrait_player", "portrait_pet", "portrait_focus",
        "portrait_target", "portrait_tot",
        "portrait_party1", "portrait_party2", "portrait_party3", "portrait_party4", "portrait_party5" } },
    { title = "AURAS", keys = { "aura_player", "aura_target" } },
    { title = "INFO",  keys = { "infobar" } },
    { title = "MICRO", keys = { "micromenu" } },
    { title = "CHAT",  keys = { "chatbubble" } },
    { title = "TRACKER", keys = { "tracker" } },
    { title = "GLOW",  keys = { "glow" } },
}


local built = false
local function BuildPanel()
    -- Fondo.
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(PL.BG)
    bg:SetPoint("TOPLEFT", 4, -4); bg:SetPoint("BOTTOMRIGHT", -4, 4)
    bg:SetAlpha(0.5)
    local shade = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
    shade:SetAllPoints(bg); shade:SetColorTexture(0, 0, 0, 0.4)

    local title = panel:CreateFontString(nil, "ARTWORK")
    setFont(title, 19)
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetTextColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
    title:SetText("AzeriteUI |cffffcc00—|r Gonkast Preset")

    -- Boton PERFIL global (esquina superior derecha): abre la seccion de presets.
    perfilBtn = MakeButton(panel, "Profile", 90, 24)
    perfilBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -14, -10)
    perfilBtn:SetScript("OnClick", function() ShowSection("presets") end)
    panelButtons[#panelButtons + 1] = perfilBtn
    -- Boton EXPLORER global (al lado de Profile): auto-ocultar elementos por mouseover.
    explorerBtn = MakeButton(panel, "Explorer", 90, 24)
    explorerBtn:SetPoint("RIGHT", perfilBtn, "LEFT", -6, 0)
    explorerBtn:SetScript("OnClick", function() ShowSection("explorer") end)
    panelButtons[#panelButtons + 1] = explorerBtn
    -- Boton EDITING global (al lado de Explorer): herramientas de edicion (B5).
    editingBtn = MakeButton(panel, "Editing", 90, 24)
    editingBtn:SetPoint("RIGHT", explorerBtn, "LEFT", -6, 0)
    editingBtn:SetScript("OnClick", function() ShowSection("editing") end)
    panelButtons[#panelButtons + 1] = editingBtn
    -- Boton SETUP global (integracion / perfiles de otros addons).
    setupBtn = MakeButton(panel, "Setup", 90, 24)
    setupBtn:SetPoint("RIGHT", editingBtn, "LEFT", -6, 0)
    panelButtons[#panelButtons + 1] = setupBtn
    setupBtn:SetScript("OnClick", function() ShowSection("setup") end)

    local LABELS = {}
    for _, d in ipairs(ns.UNITS) do LABELS[d.key] = d.label end
    for _, d in ipairs(ns.PORTRAITS or {}) do LABELS[d.key] = d.label end
    for _, d in ipairs(ns.AURAS or {}) do LABELS[d.key] = d.label end
    LABELS[ns.INFOBAR_KEY or "infobar"] = "Info Bar"
    LABELS[ns.MICROMENU_KEY or "micromenu"] = "Micro Menu"
    LABELS[ns.CHATBUBBLE_KEY or "chatbubble"] = "Chat Bubble"
    LABELS[ns.TRACKER_KEY or "tracker"] = "Quest Tracker"
    LABELS[ns.GLOW_KEY or "glow"] = "Assisted Glow"

    -- ===== SIDEBAR: lista de unidades agrupada (con scroll) =====
    local sidebar = CreateFrame("Frame", nil, panel)
    sidebar:SetPoint("TOPLEFT", 10, -42)
    sidebar:SetPoint("BOTTOMLEFT", 10, 44)
    sidebar:SetWidth(140)
    local sbBg = sidebar:CreateTexture(nil, "BACKGROUND")
    sbBg:SetAllPoints(); sbBg:SetColorTexture(0, 0, 0, 0.35)

    -- Buscador: filtra la lista por nombre. RelayoutSidebar se define mas abajo.
    local searchText = ""
    local RelayoutSidebar
    -- Pildora con borde limpio (izq/centro/der 3-slice) + lupa, calcada del buscador REAL de
    -- Plumber (antes: InputBoxTemplate nativo de Blizzard, se veia como una caja azul generica).
    local searchBox = CreateFrame("EditBox", nil, sidebar)
    searchBox:SetSize(104, 20)
    searchBox:SetPoint("TOPLEFT", 10, -4)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject("GameFontNormal")
    searchBox:SetTextInsets(18, 4, 0, 0)
    searchBox:SetTextColor(0.92, 0.86, 0.70)

    -- Los caps se dibujan un poco MAS ALTOS que la caja (20+6=26) y se solapan hacia adentro
    -- (offset -2/2) para que el borde del atlas (que es una pildora completa, no un marco fino)
    -- se recorte por los bordes de la caja en vez de aplastarse en una tira casi invisible de
    -- 18-20px. Tinte con COLOR_TITLE (en vez de blanco puro) para que el marron/dorado del atlas
    -- destaque mas contra el fondo casi negro del sidebar (el arte original esta pensado para un
    -- fondo mas claro que el nuestro).
    local sbLeft = searchBox:CreateTexture(nil, "BACKGROUND")
    sbLeft:SetTexture(PLB); sbLeft:SetTexCoord(0 / 1024, 32 / 1024, 0 / 1024, 80 / 1024)
    sbLeft:SetSize(13, 26); sbLeft:SetPoint("LEFT", -3, 0)
    sbLeft:SetVertexColor(1.15, 1.05, 0.85)
    local sbRight = searchBox:CreateTexture(nil, "BACKGROUND")
    sbRight:SetTexture(PLB); sbRight:SetTexCoord(160 / 1024, 192 / 1024, 0 / 1024, 80 / 1024)
    sbRight:SetSize(13, 26); sbRight:SetPoint("RIGHT", 3, 0)
    sbRight:SetVertexColor(1.15, 1.05, 0.85)
    local sbMid = searchBox:CreateTexture(nil, "BACKGROUND")
    sbMid:SetTexture(PLB); sbMid:SetTexCoord(32 / 1024, 160 / 1024, 0 / 1024, 80 / 1024)
    sbMid:SetPoint("TOPLEFT", sbLeft, "TOPRIGHT", -3, 0); sbMid:SetPoint("BOTTOMRIGHT", sbRight, "BOTTOMLEFT", 3, 0)
    sbMid:SetVertexColor(1.15, 1.05, 0.85)

    local sbMag = searchBox:CreateTexture(nil, "OVERLAY")
    sbMag:SetTexture(PLB); sbMag:SetTexCoord(984 / 1024, 1024 / 1024, 0 / 1024, 40 / 1024)
    sbMag:SetSize(12, 12); sbMag:SetPoint("LEFT", 5, 0)
    sbMag:SetVertexColor(0.85, 0.78, 0.62)

    local searchHint = searchBox:CreateFontString(nil, "ARTWORK"); setFont(searchHint, 10)
    searchHint:SetPoint("LEFT", 18, 0); searchHint:SetTextColor(0.55, 0.5, 0.42); searchHint:SetText("Search...")
    searchBox:SetScript("OnTextChanged", function(self)
        searchText = self:GetText() or ""
        searchHint:SetShown(searchText == "")
        if RelayoutSidebar then RelayoutSidebar() end
    end)
    searchBox:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    searchBox:SetScript("OnEditFocusGained", function(self) sbMag:SetVertexColor(1, 0.9, 0.6) end)
    searchBox:SetScript("OnEditFocusLost", function(self) sbMag:SetVertexColor(0.6, 0.55, 0.45) end)

    -- ScrollFrame + scrollbar CUSTOM (thumb arrastrable + flechas; texturas Plumber).
    -- value 0 = arriba (no invertido). La lista puede ser mas alta que el panel.
    local scroll = CreateFrame("ScrollFrame", nil, sidebar)
    scroll:SetPoint("TOPLEFT", 2, -26)
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
        btn.tex = tex
        btn:SetScript("OnEnter", function() tex:SetVertexColor(1, 0.9, 0.45) end)
        btn:SetScript("OnLeave", function() tex:SetVertexColor(1, 1, 1) end)
        return btn
    end
    local upBtn   = TexBtn(396, 428); upBtn:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -1, -26)
    local downBtn = TexBtn(428, 460); downBtn:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -1, 2)

    local track = CreateFrame("Frame", nil, sidebar)
    track:SetWidth(BAR_W)
    track:SetPoint("TOPRIGHT", upBtn, "BOTTOMRIGHT", 0, -2)
    track:SetPoint("BOTTOMRIGHT", downBtn, "TOPRIGHT", 0, 2)
    local rail = track:CreateTexture(nil, "BACKGROUND")
    rail:SetAllPoints(); rail:SetTexture(WIDGET)
    rail:SetTexCoord(0 / 512, 32 / 512, 0 / 512, 128 / 512); rail:SetVertexColor(1, 1, 1, 0.22)

    local thumb = CreateFrame("Button", nil, track)
    thumb:SetPoint("TOP"); thumb:SetSize(BAR_W, 40)
    local tt = thumb:CreateTexture(nil, "ARTWORK")
    tt:SetAllPoints(); tt:SetTexture(WIDGET); tt:SetTexCoord(0 / 512, 32 / 512, 132 / 512, 260 / 512)

    local function PositionThumb()
        local usable = math.max((track:GetHeight() or 1) - (thumb:GetHeight() or 1), 0)
        local frac = (scrollRange > 0) and (scrollValue / scrollRange) or 0
        thumb:ClearAllPoints(); thumb:SetPoint("TOP", track, "TOP", 0, -frac * usable)
    end
    local function ApplyScroll(v)
        scrollValue = math.min(math.max(v or 0, 0), scrollRange)
        scroll:SetVerticalScroll(scrollValue)
        PositionThumb()
    end

    upBtn:SetScript("OnClick",   function() ApplyScroll(scrollValue - 30) end)
    downBtn:SetScript("OnClick", function() ApplyScroll(scrollValue + 30) end)

    thumb:SetScript("OnMouseDown", function(self)
        self.dragging = true; self.startY = select(2, GetCursorPosition()); self.startV = scrollValue
        tt:SetVertexColor(1, 0.9, 0.5)
    end)
    thumb:SetScript("OnMouseUp", function(self) self.dragging = false; tt:SetVertexColor(1, 1, 1) end)
    thumb:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        if not IsMouseButtonDown("LeftButton") then self.dragging = false; tt:SetVertexColor(1, 1, 1); return end
        local _, y = GetCursorPosition()
        local usable = math.max((track:GetHeight() or 1) - (thumb:GetHeight() or 1), 1)
        local dy = (self.startY - y) / (track:GetEffectiveScale() or 1)
        ApplyScroll(self.startV + (dy / usable) * scrollRange)
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
        ApplyScroll(scrollValue)
    end
    scroll:SetScript("OnSizeChanged", updateScroll)

    -- Grupos COLAPSABLES: header (boton con flecha) + botones. Se crean UNA vez y
    -- RelayoutSidebar los reubica/oculta segun colapso + busqueda (sin recrear frames).
    local collapsed = {}
    local sideHeaders = {}

    local function MakeCollapseHeader(grp)
        local h = CreateFrame("Button", nil, sbChild)
        h:SetSize(112, 15)
        local arrow = h:CreateFontString(nil, "ARTWORK"); setFont(arrow, 10)
        arrow:SetPoint("LEFT", 0, 0); arrow:SetTextColor(0.75, 0.62, 0.25)
        h.arrow = arrow
        local fs = h:CreateFontString(nil, "ARTWORK"); setFont(fs, 10)
        fs:SetPoint("LEFT", 11, 0); fs:SetTextColor(0.75, 0.62, 0.25); fs:SetText(grp.title)
        h.fs = fs
        h:SetScript("OnEnter", function() fs:SetTextColor(1, 0.9, 0.45); arrow:SetTextColor(1, 0.9, 0.45) end)
        h:SetScript("OnLeave", function() fs:SetTextColor(0.75, 0.62, 0.25); arrow:SetTextColor(0.75, 0.62, 0.25) end)
        h:SetScript("OnClick", function()
            collapsed[grp.title] = not collapsed[grp.title]
            RelayoutSidebar()
        end)
        return h
    end

    for _, grp in ipairs(UNIT_GROUPS) do
        sideHeaders[grp.title] = MakeCollapseHeader(grp)
        for _, key in ipairs(grp.keys) do
            local b = MakeButton(sbChild, LABELS[key] or key, 104, 18)
            b.text:ClearAllPoints(); b.text:SetPoint("LEFT", 10, 0)
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

    -- ===== CONTENIDO =====
    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 22, 0)
    content:SetPoint("BOTTOMRIGHT", -10, 44)
    panel._content = content   -- para el nudge de relayout en ApplyPanelView

    unitTitle = content:CreateFontString(nil, "ARTWORK")
    setFont(unitTitle, 14)
    unitTitle:SetPoint("TOPLEFT", 4, -2)
    unitTitle:SetTextColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])

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
    }
    for i, s in ipairs(secList) do
        local b = MakeButton(content, s.label, 46, 20)
        b:SetPoint("TOPLEFT", 2 + (i - 1) * 48, -26)
        b:SetScript("OnClick", function() ShowSection(s.key) end)
        sectionTabs[s.key] = b
    end

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
        { key = "p_focus",   label = "Focus" },
    }
    -- pestañas de portrait (11): un poco mas angostas/juntas para que quepan.
    for i, s in ipairs(portSecList) do
        local b = MakeButton(content, s.label, 38, 20)
        b:SetPoint("TOPLEFT", 2 + (i - 1) * 40, -26)
        b:SetScript("OnClick", function() ShowSection(s.key) end)
        b:Hide()
        sectionTabs[s.key] = b
    end

    -- Pestanas de SECCION para auras (misma fila; ocultas hasta seleccionar un grupo).
    local auraSecList = {
        { key = "a_general", label = "Gen" },
        { key = "a_grid",    label = "Grid" },
        { key = "a_pos",     label = "Pos" },
        { key = "a_dead",    label = "Death" },
        { key = "a_style",   label = "Border" },
        { key = "a_text",    label = "Text" },
    }
    for i, s in ipairs(auraSecList) do
        local b = MakeButton(content, s.label, 46, 20)
        b:SetPoint("TOPLEFT", 2 + (i - 1) * 48, -26)
        b:SetScript("OnClick", function() ShowSection(s.key) end)
        b:Hide()
        sectionTabs[s.key] = b
    end

    -- Pestanas de SECCION para el info bar (ocultas hasta seleccionar Info Bar).
    local infoSecList = {
        { key = "i_general",  label = "Gen" },
        { key = "i_pos",      label = "Pos" },
        { key = "i_elements", label = "Elem" },
        { key = "i_text",     label = "Text" },
        { key = "i_bg",       label = "Bg" },
    }
    for i, s in ipairs(infoSecList) do
        local b = MakeButton(content, s.label, 46, 20)
        b:SetPoint("TOPLEFT", 2 + (i - 1) * 48, -26)
        b:SetScript("OnClick", function() ShowSection(s.key) end)
        b:Hide()
        sectionTabs[s.key] = b
    end

    -- Pestanas de SECCION para el micro menu.
    local microSecList = { { key = "mm_general", label = "Gen" } }
    for i, s in ipairs(microSecList) do
        local b = MakeButton(content, s.label, 46, 20)
        b:SetPoint("TOPLEFT", 2 + (i - 1) * 48, -26)
        b:SetScript("OnClick", function() ShowSection(s.key) end)
        b:Hide()
        sectionTabs[s.key] = b
    end

    -- Pestanas de SECCION para el chat bubble.
    local chatSecList = { { key = "cb_general", label = "Gen" } }
    for i, s in ipairs(chatSecList) do
        local b = MakeButton(content, s.label, 46, 20)
        b:SetPoint("TOPLEFT", 2 + (i - 1) * 48, -26)
        b:SetScript("OnClick", function() ShowSection(s.key) end)
        b:Hide()
        sectionTabs[s.key] = b
    end

    -- Pestanas de SECCION para el quest tracker.
    local trackerSecList = { { key = "t_general", label = "Gen" } }
    for i, s in ipairs(trackerSecList) do
        local b = MakeButton(content, s.label, 46, 20)
        b:SetPoint("TOPLEFT", 2 + (i - 1) * 48, -26)
        b:SetScript("OnClick", function() ShowSection(s.key) end)
        b:Hide()
        sectionTabs[s.key] = b
    end

    -- Pestanas de SECCION para el assisted glow.
    local glowSecList = { { key = "g_general", label = "Gen" } }
    for i, s in ipairs(glowSecList) do
        local b = MakeButton(content, s.label, 46, 20)
        b:SetPoint("TOPLEFT", 2 + (i - 1) * 48, -26)
        b:SetScript("OnClick", function() ShowSection(s.key) end)
        b:Hide()
        sectionTabs[s.key] = b
    end

    -- Divisor horizontal (Plumber) separando la fila de pestanas del contenido.
    local tdiv = content:CreateTexture(nil, "ARTWORK")
    tdiv:SetTexture(PL.DIV_H)
    tdiv:SetPoint("TOPLEFT", 0, -50); tdiv:SetPoint("TOPRIGHT", 0, -50)
    tdiv:SetHeight(8); tdiv:SetVertexColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3], 0.35)

    -- Area de controles de la seccion activa.
    local secArea = CreateFrame("Frame", nil, content)
    secArea:SetPoint("TOPLEFT", 0, -54)
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
        MakeEditBox(f, "Anchor to (frame; empty = screen)", "anchorFrame", L, -10)
        MakeCycle(f, "Strata", ns.STRATA_VALUES, "strata", L, -52)
        MakeCycle(f, "Point (bar)", ns.POINT_VALUES, "point", L, -82)
        MakeCycle(f, "Point (target)", ns.POINT_VALUES, "relativePoint", L, -112)
        MakeSlider(f, "Scale (wheel in Lock too)", 0.3, 3, 0.02, "scale", L, -156)
        MakeSlider(f, "Offset X", -2000, 2000, 1, "offsetX", R, -20)
        MakeSlider(f, "Offset Y", -2000, 2000, 1, "offsetY", R, -62)
        MakeCheckbox(f, "Hide when mounted", "hideWhenMounted", R, -92)
        powerHidden[#powerHidden + 1] = MakeCheckbox(f, "Show tooltip", "showTooltip", R, -118)
        local resetBtn = MakeButton(f, "Reset this unit", 200, 22)
        resetBtn:SetPoint("TOPLEFT", L, -204)
        resetBtn:SetScript("OnClick", function() ns.ResetUnit(ns.currentEdit) end)
    end
    -- Barra (incluye tamaño de la barra: Width/Height, movidos desde General)
    do
        local f = Section("bar")
        MakeTexturePicker(f, "Texture (empty = none)", "texture", "bar", L, -12)
        MakeSlider(f, "Width", 10, 1000, 1, "width", L, -66)
        MakeSlider(f, "Height", 2, 300, 1, "height", L, -108)
        MakeSlider(f, "Bar opacity", 0, 1, 0.05, "barAlpha", L, -150)
        MakeSlider(f, "Background opacity", 0, 1, 0.05, "bgAlpha", R, -20)
        MakeCheckbox(f, "Inverse (right -> left)", "reverseFill", R, -50)
        MakeCheckbox(f, "Smooth progress", "smooth", R, -76)
        MakeCheckbox(f, "Show background", "showBackground", R, -102)
        -- Area de CLICK del boton seguro (independiente del tamaño de la barra).
        MakeSlider(f, "Click width (0 = bar)", 0, 1200, 1, "btnWidth", L, -192)
        MakeSlider(f, "Click height (0 = bar)", 0, 400, 1, "btnHeight", L, -234)
        MakeSlider(f, "Click offset X", -400, 400, 1, "btnOffsetX", R, -140)
        MakeSlider(f, "Click offset Y", -400, 400, 1, "btnOffsetY", R, -182)
        local cnote = f:CreateFontString(nil, "ARTWORK"); setFont(cnote, 10)
        cnote:SetPoint("TOPLEFT", R, -228); cnote:SetWidth(210); cnote:SetJustifyH("LEFT")
        cnote:SetTextColor(0.6, 0.6, 0.6)
        cnote:SetText("Click = the secure button (right-click menu / targeting). 0 follows the bar size. Applies when preview is OFF.")
        -- B4: outline de edicion propio por unidad (W/H, 0 = seguir al frame) + ocultar nombre.
        MakeSlider(f, "Outline width (0 = frame)", 0, 1200, 1, "outlineW", L, -276)
        MakeSlider(f, "Outline height (0 = frame)", 0, 400, 1, "outlineH", L, -318)
        MakeCheckbox(f, "Hide outline name", "outlineHideName", R, -276)
    end
    -- Cage
    do
        local f = Section("cage")
        MakeTexturePicker(f, "Cage texture (empty = none)", "cageTexture", "cage", L, -12)
        MakeSlider(f, "Cage width", 2, 1200, 1, "cageWidth", L, -66)
        MakeSlider(f, "Cage height", 2, 400, 1, "cageHeight", L, -108)
        MakeSlider(f, "Offset X", -400, 400, 1, "cageOffsetX", R, -20)
        MakeSlider(f, "Offset Y", -400, 400, 1, "cageOffsetY", R, -62)
        MakeSlider(f, "Cage opacity", 0, 1, 0.05, "cageAlpha", R, -104)
        MakeCheckbox(f, "Hide cage when the unit dies", "cageHideDead", L, -150)
    end
    -- Highlight de unidad seleccionada (target)
    do
        local f = Section("highlight")
        MakeCheckbox(f, "Highlight when it's my target", "showHighlight", L, -12)
        MakeTexturePicker(f, "Highlight texture", "highlightTexture", "highlight", L, -44)
        MakeSlider(f, "Width", 2, 1200, 1, "highlightWidth", L, -98)
        MakeSlider(f, "Height", 2, 400, 1, "highlightHeight", L, -140)
        MakeSlider(f, "Scale", 0.2, 3, 0.02, "highlightScale", L, -182)

        MakeSlider(f, "Offset X", -400, 400, 1, "highlightOffsetX", R, -20)
        MakeSlider(f, "Offset Y", -400, 400, 1, "highlightOffsetY", R, -62)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "highlightAlpha", R, -104)
        MakeColorButton(f, "Color", "highlightColor", R, -134)
        MakeCheckbox(f, "Glow (pulse)", "highlightGlow", R, -170)
    end
    -- Vida
    do
        local f = Section("health")
        MakeCheckbox(f, "Show text", "showText", L, -10)
        powerHidden[#powerHidden + 1] = MakeCheckbox(f, "Show value (99% | 100m)", "showValue", L, -36)
        MakeCheckbox(f, "Auto-hide (comb/hostile tgt/mo)", "textAutoHide", L, -62)
        MakeSlider(f, "Font size", 4, 60, 1, "fontSize", L, -104)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "textAlpha", L, -146)
        MakeCheckbox(f, "Also reveal on low HP", "textLowHealthShow", L, -178)
        MakeSlider(f, "Reveal below %", 5, 100, 1, "textLowHealthThreshold", L, -212)

        MakeSlider(f, "Offset X", -200, 200, 1, "textOffsetX", R, -20)
        MakeSlider(f, "Offset Y", -200, 200, 1, "textOffsetY", R, -62)
        MakeCheckbox(f, "Custom text color", "useHealthColor", R, -92)
        MakeColorButton(f, "Text color", "healthColor", R, -120)

        MakeHeader(f, "Low-health warning", R, -156, 210)
        MakeCheckbox(f, "Color health text on low HP", "lowHealthWarn", R, -180)
        MakeSlider(f, "Below %", 5, 100, 1, "lowHealthThreshold", R, -214)
        MakeColorButton(f, "Low-HP text color", "lowHealthColor", R, -256)
    end
    -- Nombre
    do
        local f = Section("name")
        MakeCheckbox(f, "Show name", "showName", L, -10)
        MakeCheckbox(f, "Auto-hide", "nameAutoHide", L, -36)
        MakeCheckbox(f, "Level color by rank", "nameLevelColor", L, -62)
        MakeCheckbox(f, "Dynamic width (200/111)", "nameDynamicWidth", L, -88)
        MakeSlider(f, "Font size", 4, 60, 1, "nameFontSize", L, -130)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "nameAlpha", L, -172)
        MakeSlider(f, "Scale", 0.5, 2, 0.05, "nameScale", R, -20)
        MakeSlider(f, "Max characters (0=off)", 0, 20, 1, "nameMaxLength", R, -62)
        MakeSlider(f, "Offset X", -200, 200, 1, "nameOffsetX", R, -104)
        MakeSlider(f, "Offset Y", -200, 200, 1, "nameOffsetY", R, -146)
        MakeCheckbox(f, "Custom name color", "useNameColor", R, -176)
        MakeColorButton(f, "Name color", "nameColor", R, -204)
    end
    -- Hechizo
    do
        local f = Section("spell")
        MakeCheckbox(f, "Show spell name", "showSpell", L, -10)
        MakeSlider(f, "Font size", 4, 60, 1, "spellFontSize", L, -52)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "spellAlpha", L, -94)
        MakeSlider(f, "Scale", 0.5, 2, 0.05, "spellScale", L, -136)
        MakeSlider(f, "Max characters (0=off)", 0, 40, 1, "spellMaxLength", L, -178)
        MakeSlider(f, "Wrap width (lower = stack)", 30, 400, 1, "spellWrapWidth", L, -220)
        MakeSlider(f, "Offset X", -200, 200, 1, "spellOffsetX", R, -20)
        MakeSlider(f, "Offset Y", -200, 200, 1, "spellOffsetY", R, -62)
        MakeCheckbox(f, "Custom spell color", "useSpellColor", R, -92)
        MakeColorButton(f, "Spell color", "spellColor", R, -120)
        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", R, -150); note:SetWidth(210); note:SetJustifyH("LEFT")
        note:SetTextColor(0.7, 0.7, 0.7)
        note:SetText("Long spell names wrap to 2 lines (within the cast bar width). Max characters truncates with '..' (readable names only).")
    end
    -- Cast bar (posicion fija: imita al hp bar).
    do
        local f = Section("cast")
        MakeSlider(f, "Width", 2, 1000, 1, "castWidth", L, -20)
        MakeSlider(f, "Height", 2, 300, 1, "castHeight", L, -62)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "castAlpha", L, -104)
        MakeColorButton(f, "Cast color", "castColor", L, -134)
        MakeTexturePicker(f, "Cast texture", "castTexture", "bar", R, -20)
        MakeCheckbox(f, "Inverse (right -> left)", "castReverse", R, -66)
        MakeCheckbox(f, "Smooth progress", "castSmooth", R, -92)
        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", R, -126); note:SetTextColor(0.7, 0.7, 0.7)
        note:SetText("Position: fixed (mimics the hp bar)")

        MakeSlider(f, "Spark width", 0, 60, 1, "castSparkWidth", L, -176)
        MakeSlider(f, "Spark height", 0, 120, 1, "castSparkHeight", L, -218)
        MakeSlider(f, "Spark scale", 0.2, 3, 0.05, "castSparkScale", L, -260)
    end
    -- Colores
    do
        local f = Section("colors")
        MakeCheckbox(f, "Manual color (ignore auto)", "useBarColor", L, -12)
        MakeColorButton(f, "Bar color", "barColor", L, -40)
        colorHidden[#colorHidden + 1] = MakeColorButton(f, "Hostile color", "colorHostile", L, -72)
        colorHidden[#colorHidden + 1] = MakeColorButton(f, "Neutral color", "colorNeutral", L, -100)
        colorHidden[#colorHidden + 1] = MakeColorButton(f, "Friendly color", "colorFriendly", L, -128)
    end
    -- Presets
    do
        local f = Section("presets")
        local selected = { name = nil }

        -- ===== IZQUIERDA: gestion de perfiles =====
        MakeHeader(f, "Profiles", L, -6, 200)

        local nlbl = f:CreateFontString(nil, "ARTWORK"); setFont(nlbl, 11)
        nlbl:SetPoint("TOPLEFT", L, -30); nlbl:SetTextColor(0.9, 0.88, 0.82)
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
            function() return ns.GetDB().hideEditGreen end,
            function(v) ns.GetDB().hideEditGreen = v; ns.ToggleGreenZone() end)
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
        MakeToggle(f, "Smooth fade-in (frames appearing)", R, -150,
            function() return ns.GetDB().fadeIn end,
            function(v) ns.GetDB().fadeIn = v end)
        local dcFixCB = MakeToggle(f, "DynamicCam camera fix", R, -174,
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
        tnote:SetPoint("TOPLEFT", R, -206); tnote:SetWidth(210); tnote:SetJustifyH("LEFT")
        tnote:SetTextColor(0.6, 0.6, 0.6)
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
        portraitPlayerOnly[#portraitPlayerOnly + 1] = playerOnly
        MakeCheckbox(playerOnly, "Left-click opens Character panel", "clickOpenChar", L, -216)
        MakeSlider(playerOnly, "Click area size", 0.3, 3, 0.05, "charBtnScale", L, -258)

        -- Doble posicion (solo portraits con dualPos: player/pet/focus).
        local dual = MakeGroup(f)
        portraitDualBoxes[#portraitDualBoxes + 1] = dual
        MakeHeader(dual, "Dual position", R, -6, 250)
        MakeCycle(dual, "Edit (preview)", { "center", "alt" }, "editPos", R, -30)
        MakeCheckbox(dual, "Center if: target", "centerOnTarget", R, -62)
        MakeCheckbox(dual, "Center if: combat", "centerInCombat", R, -88)
        MakeCheckbox(dual, "Center if: raid/dungeon", "centerInInstance", R, -114)
        local note = dual:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", R, -148); note:SetWidth(210); note:SetJustifyH("LEFT")
        note:SetTextColor(0.7, 0.7, 0.7)
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
        portraitDualBoxes[#portraitDualBoxes + 1] = alt
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
        portraitModelOnly[#portraitModelOnly + 1] = zoom
        MakeSlider(f, "Scale", 0.2, 2, 0.02, "modelScale", L, -94)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "modelAlpha", L, -136)
        MakeSlider(f, "Offset X", -200, 200, 1, "modelOffsetX", R, -20)
        MakeSlider(f, "Offset Y", -200, 200, 1, "modelOffsetY", R, -62)
        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", R, -100); note:SetWidth(200); note:SetJustifyH("LEFT")
        note:SetTextColor(0.7, 0.7, 0.7)
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
        note:SetTextColor(0.7, 0.7, 0.7)
        note:SetText("Shows the raid target icon (skull, cross, star...) as a badge over the party portrait, only when the member is marked. In preview it shows a sample skull.")
    end
    -- Portrait / Role + Leader icons. Rol = solo party (sub-grupo portraitRoleOnly);
    -- Lider = cualquier portrait con feature 'leader' (siempre visible en la seccion).
    do
        local f = Section("p_role")
        -- ROL (solo party)
        local roleG = MakeGroup(f)
        portraitRoleOnly[#portraitRoleOnly + 1] = roleG
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

    -- Portrait / FOCUS: el texto de vida (%/valor) y el highlight del focus viven en la
    -- unitframe db.units.focus (no en el portrait). Estos controles la editan directamente.
    do
        local f = Section("p_focus")
        local function fp() return ns.GetDB().units.focus end
        local function fref() if ns.RefreshUnit then ns.RefreshUnit("focus") end end
        local function fGet(k) return function() return fp()[k] end end
        local function fSet(k) return function(v) fp()[k] = v; fref() end end
        -- Texto de vida (izquierda).
        MakeHeader(f, "Health text", L, -6, 210)
        MakeToggle(f, "Show value (%  |  amount)", L, -30, fGet("showValue"), fSet("showValue"))
        MakeSlider(f, "Font size", 6, 40, 1, "fontSize", L, -68, fp, fref)
        MakeSlider(f, "Offset X", -200, 200, 1, "textOffsetX", L, -110, fp, fref)
        MakeSlider(f, "Offset Y", -200, 200, 1, "textOffsetY", L, -152, fp, fref)
        MakeToggle(f, "Custom text color", L, -186, fGet("useHealthColor"), fSet("useHealthColor"))
        MakeGlobalColor(f, "Text color", function() return fp().healthColor end, L, -216, fref)
        -- Textura del highlight (apunta a db.units.focus via getTbl/onChange).
        MakeTexturePicker(f, "Highlight texture", "highlightTexture", "highlight", L, -252, fp, fref)
        -- Highlight (derecha).
        MakeHeader(f, "Highlight (when focus = target)", R, -6, 220)
        MakeToggle(f, "Show highlight", R, -30, fGet("showHighlight"), fSet("showHighlight"))
        MakeToggle(f, "Pulse", R, -54, fGet("highlightGlow"), fSet("highlightGlow"))
        MakeSlider(f, "Scale", 0.2, 4, 0.02, "highlightScale", R, -92, fp, fref)
        MakeSlider(f, "Opacity", 0, 1, 0.05, "highlightAlpha", R, -134, fp, fref)
        MakeSlider(f, "Offset X", -200, 200, 1, "highlightOffsetX", R, -176, fp, fref)
        MakeSlider(f, "Offset Y", -200, 200, 1, "highlightOffsetY", R, -218, fp, fref)
        MakeGlobalColor(f, "Highlight color", function() return fp().highlightColor end, R, -248, fref)
        -- Width/Height como en la pestaña "Sel" de las unidades (pet incluido).
        MakeSlider(f, "Width", 2, 1200, 1, "highlightWidth", R, -286, fp, fref)
        MakeSlider(f, "Height", 2, 400, 1, "highlightHeight", R, -328, fp, fref)
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
        note:SetTextColor(0.7, 0.7, 0.7)
        note:SetText("Sort: index (API), timeUp, timeDown, name. Secret times go to the end.")

        -- Solo Player Auras: editar posicion + condiciones + opacidad.
        local dual = MakeGroup(f)
        auraDualBoxes[#auraDualBoxes + 1] = dual
        MakeHeader(dual, "Positions / Opacity", R, -6, 250)
        MakeCycle(dual, "Edit (preview)", { "center", "alt", "dead", "deadTarget" }, "editPos", R, -30)
        MakeCheckbox(dual, "Primary if: target", "centerOnTarget", R, -62)
        MakeCheckbox(dual, "Primary if: combat", "centerInCombat", R, -88)
        MakeCheckbox(dual, "Primary if: instance", "centerInInstance", R, -114)
        MakeSlider(dual, "Base opacity (hover/cond=100%)", 0, 1, 0.05, "groupAlpha", R, -150)
        local dnote = dual:CreateFontString(nil, "ARTWORK"); setFont(dnote, 10)
        dnote:SetPoint("TOPLEFT", R, -192); dnote:SetWidth(210); dnote:SetJustifyH("LEFT")
        dnote:SetTextColor(0.7, 0.7, 0.7)
        dnote:SetText("No condition = alternate. Player dead = Death pos (Death tab).")

        MakeCheckbox(dual, "Cancel buff on right-click", "allowCancel", R, -232)
        local cnote = dual:CreateFontString(nil, "ARTWORK"); setFont(cnote, 10)
        cnote:SetPoint("TOPLEFT", R, -258); cnote:SetWidth(210); cnote:SetJustifyH("LEFT")
        cnote:SetTextColor(0.7, 0.7, 0.7)
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
        note:SetTextColor(0.7, 0.7, 0.7)
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
        auraDualBoxes[#auraDualBoxes + 1] = alt
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
        auraDualBoxes[#auraDualBoxes + 1] = petg
        MakeHeader(petg, "Pet offset — primary", L, -220, 210)
        MakeSlider(petg, "Offset X", -2000, 2000, 1, "petOffsetX", L, -264)
        MakeSlider(petg, "Offset Y", -2000, 2000, 1, "petOffsetY", L, -306)
        MakeHeader(petg, "Pet offset — alternate", R, -220, 210)
        MakeSlider(petg, "Offset X", -2000, 2000, 1, "petOffsetXAlt", R, -264)
        MakeSlider(petg, "Offset Y", -2000, 2000, 1, "petOffsetYAlt", R, -306)
        local pnote = petg:CreateFontString(nil, "ARTWORK"); setFont(pnote, 10)
        pnote:SetPoint("TOPLEFT", L, -350); pnote:SetWidth(430); pnote:SetJustifyH("LEFT")
        pnote:SetTextColor(0.7, 0.7, 0.7)
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
        note:SetTextColor(0.7, 0.7, 0.7)
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
        note:SetTextColor(0.7, 0.7, 0.7)
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
        note:SetTextColor(0.7, 0.7, 0.7)
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
        note:SetTextColor(0.7, 0.7, 0.7)
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
        note:SetTextColor(0.7, 0.7, 0.7)
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
        note:SetTextColor(0.7, 0.7, 0.7)
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
        note:SetTextColor(0.7, 0.7, 0.7)
        note:SetText("Controls the world chat bubbles: hides their background and sets the text font/size/outline/color. Applies live as bubbles appear.")
        local resetBtn = MakeButton(f, "Reset chat bubble", 200, 22)
        resetBtn:SetPoint("TOPLEFT", R, -130)
        resetBtn:SetScript("OnClick", function() ns.ResetUnit(ns.currentEdit) end)
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

        MakeHeader(f, "Auto-hide", L, -182, 210)
        MakeCheckbox(f, "Hide in boss fights", "hideInBoss", L, -206)
        MakeCheckbox(f, "Hide in combat", "hideInCombat", L, -230)
        MakeCheckbox(f, "Hide on hostile target", "hideOnHostileTarget", L, -254)
        MakeCheckbox(f, "Hide in arena", "hideInArena", L, -278)
        MakeCheckbox(f, "Hide in battlegrounds", "hideInBG", L, -302)

        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", R, -10); note:SetWidth(210); note:SetJustifyH("LEFT")
        note:SetTextColor(0.7, 0.7, 0.7)
        note:SetText("Colorize titles: recolors the objective-tracker headers/quests (cosmetic, no taint). Title/Dungeon center offset: fine-tune horizontal centering of quest titles vs. scenario/dungeon titles (e.g. \"Windrunner Spire\") independently — live, no reload needed. Auto-hide toggles fold the tracker (alpha 0) via a secure driver — any combination can be active at once; the tracker reappears as soon as none of the checked conditions apply.")
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

        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 10)
        note:SetPoint("TOPLEFT", R, -160); note:SetWidth(210); note:SetJustifyH("LEFT")
        note:SetTextColor(0.7, 0.7, 0.7)
        local libNote = ns.HasLCG
            and "Replaces the assisted-rotation highlight with a custom glow on the recommended action button. 'Texture' uses your Assets image (actionbuttonhighlight)."
            or "LibCustomGlow not detected: 'Texture' and 'Border' styles work; Pixel/AutoCast/Button glows need that library."
        note:SetText(libNote)
        local resetBtn = MakeButton(f, "Reset assisted glow", 200, 22)
        resetBtn:SetPoint("TOPLEFT", R, -210)
        resetBtn:SetScript("OnClick", function() ns.ResetUnit(ns.currentEdit) end)
    end

    -- =========================== SECCION SETUP (integracion + perfiles) ===========================
    do
        local f = Section("setup")
        MakeHeader(f, "Setup  —  addon integration & profiles", L, -6, 430)
        local note = f:CreateFontString(nil, "ARTWORK"); setFont(note, 11)
        note:SetPoint("TOPLEFT", L, -34); note:SetWidth(430); note:SetJustifyH("LEFT")
        note:SetTextColor(0.85, 0.85, 0.85)
        note:SetText("AzeriteUI: runtime injection RE-ENABLED (2026-07-15) to re-test — the taint that led to removing it was later traced to unrelated bugs (StaticPopupDialogs reassignment + calendar), not this injection. Its own toggles/colors live in AzeriteUI's options panel (/az -> Gonkast Preset). If you see taint errors, open that panel and turn OFF the master toggle first.")
        -- Aplicar perfiles de otros addons (Bartender4/DynamicCam/Masque/Chattynator) +
        -- layout del HUD de Blizzard. DESTRUCTIVO: reemplaza su config con el preset y recarga.
        MakeHeader(f, "Apply bundled addon profiles", L, -110, 430)
        local prNote = f:CreateFontString(nil, "ARTWORK"); setFont(prNote, 10)
        prNote:SetPoint("TOPLEFT", L, -134); prNote:SetWidth(430); prNote:SetJustifyH("LEFT")
        prNote:SetTextColor(0.7, 0.7, 0.7)
        prNote:SetText("Installs the bundled profiles for the detected addons (Bartender4, DynamicCam, Masque, Chattynator, AzeriteUI SavedVariables) + the Blizzard HUD Edit Mode layout, then reloads. WARNING: this REPLACES those addons' current configuration.")
        local applyBtn = MakeButton(f, "Apply Profiles", 160, 24)
        applyBtn:SetPoint("TOPLEFT", L, -200)
        applyBtn:SetScript("OnClick", function() if ns.ApplyProfiles then ns.ApplyProfiles() end end)
        -- Lista de addons detectados (se refresca al abrir la seccion).
        local statusFS = f:CreateFontString(nil, "ARTWORK"); setFont(statusFS, 10)
        statusFS:SetPoint("TOPLEFT", L, -236); statusFS:SetWidth(430); statusFS:SetJustifyH("LEFT")
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
            function() return not ns.GetDB().hideEditGreen end,
            function(v) ns.GetDB().hideEditGreen = not v; if ns.ToggleGreenZone then ns.ToggleGreenZone() end end)
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
        note:SetTextColor(0.7, 0.7, 0.7)
        note:SetText("Per-unit outline width/height live in each unit's Bar tab. Move/Lock and Copy/Paste stay in the footer. 'Apply addon profiles' sets Bartender4/DynamicCam profiles and disables the AzeriteUI modules this addon replaces.")
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
            { "Focus portrait", "portrait_focus" },
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
        note:SetTextColor(0.7, 0.7, 0.7)
        note:SetText("Enabled elements fade out and reappear when you hover where they are (works even while hidden). Combat keeps them visible. 'Active in' limits Explorer to the chosen content types.")
    end

    -- ===== FOOTER: acciones =====
    -- Divisor Plumber separando el footer del contenido.
    local fdiv = panel:CreateTexture(nil, "ARTWORK")
    fdiv:SetTexture(PL.DIV_H)
    fdiv:SetPoint("BOTTOMLEFT", 10, 42); fdiv:SetPoint("BOTTOMRIGHT", -10, 42)
    fdiv:SetHeight(8); fdiv:SetVertexColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3], 0.30)

    local moveBtn = MakeButton(panel, "Move / Lock (/mcf)", 170, 24)
    moveBtn:SetPoint("BOTTOMLEFT", 10, 12)
    moveBtn:SetScript("OnClick", function() ns.SetUnlocked(not ns.IsUnlocked()) end)
    panelButtons[#panelButtons + 1] = moveBtn

    local previewBtn = MakeButton(panel, "Preview", 80, 24)
    previewBtn:SetPoint("LEFT", moveBtn, "RIGHT", 6, 0)
    previewBtn:SetScript("OnClick", function() ns.SetUnlocked(not ns.IsUnlocked()) end)
    ns.OnUnlockChanged = function(state)
        previewBtn:SetActive(state)
        if ns.ApplyTrackerPreviewHide then ns.ApplyTrackerPreviewHide() end
    end
    panelButtons[#panelButtons + 1] = previewBtn

    local greenBtn = MakeButton(panel, "Outline: ON", 104, 24)
    greenBtn:SetPoint("LEFT", previewBtn, "RIGHT", 6, 0)
    local function updGreen()
        local hidden = ns.GetDB().hideEditGreen
        local txt = hidden and "Outline: OFF" or "Outline: ON"
        greenBtn.text:SetText(txt)
        greenBtn._label = txt   -- el label es DINAMICO: ReassertLabels debe reaplicar EL ACTUAL, no el de creacion
        greenBtn:SetActive(hidden)
    end
    greenBtn:SetScript("OnClick", function()
        local d = ns.GetDB()
        d.hideEditGreen = not (d.hideEditGreen and true or false)
        ns.ToggleGreenZone(); updGreen()
    end)
    refreshers[#refreshers + 1] = updGreen
    panelButtons[#panelButtons + 1] = greenBtn

    local copyBtn = MakeButton(panel, "Copy", 70, 24)
    copyBtn:SetPoint("LEFT", greenBtn, "RIGHT", 6, 0)
    copyBtn:SetScript("OnClick", ns.CopySettings)
    panelButtons[#panelButtons + 1] = copyBtn
    local pasteBtn = MakeButton(panel, "Paste", 70, 24)
    pasteBtn:SetPoint("LEFT", copyBtn, "RIGHT", 6, 0)
    pasteBtn:SetScript("OnClick", ns.PasteSettings)
    panelButtons[#panelButtons + 1] = pasteBtn

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
local retryTicker
panel:SetScript("OnShow", function()
    if not ns.GetDB() then return end
    if not built then BuildPanel() built = true end
    ApplyPanelView()
    if retryTicker then retryTicker:Cancel(); retryTicker = nil end
    if C_Timer and C_Timer.NewTicker then
        local elapsed = 0
        retryTicker = C_Timer.NewTicker(0.1, function(self)
            elapsed = elapsed + 0.1
            if not panel:IsShown() or elapsed >= 2.0 then
                self:Cancel()
                if retryTicker == self then retryTicker = nil end
                return
            end
            ApplyPanelView()
        end)
    end
end)
panel:SetScript("OnHide", function()
    if retryTicker then retryTicker:Cancel(); retryTicker = nil end
end)

-- El canvas de Settings dispara OnSizeChanged JUSTO en su pase de layout (que es
-- cuando re-muestra secciones ocultas). Reaplicar ahi es lo mas determinista.
-- ApplyPanelView solo hace Hide/Show de secciones hijas (no redimensiona el panel),
-- asi que no hay recursion. Guardado por 'built' + panel visible.
panel:HookScript("OnSizeChanged", function()
    if built and panel:IsShown() then ApplyPanelView() end
end)

-- Construir el panel POR ADELANTADO (una vez que exista la DB) en lugar de
-- perezosamente en el primer OnShow. Construir los widgets durante el primer
-- pase de layout del canvas de Settings hacia que algunos no se dibujaran
-- hasta mostrar el panel una segunda vez (el bug de "clic afuera y volver").
local builder = CreateFrame("Frame")
builder:RegisterEvent("PLAYER_LOGIN")
builder:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if not built and ns.GetDB() then
        BuildPanel()
        built = true
    end
end)

local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
category.ID = panel.name
Settings.RegisterAddOnCategory(category)

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
