-- ==========================================================================
-- MyCustomFrames - NameplateDesigner.lua
-- Canvas de diseño para Nameplates.lua (pedido del usuario, calcado del tab
-- "Designer" de Platynator pero adaptado a los elementos reales de este
-- addon, NO al motor de widgets generico de Platynator -- ver el plan de
-- implementacion). Una nameplate de MENTIRA, standalone (no depende de un
-- enemigo real cerca), donde cada pieza se ARRASTRA para reposicionar y se
-- le pasa la RUEDA del mouse para redimensionar -- escribe DIRECTO en los
-- mismos campos del perfil que ya usa el menu de texto (/mcfmenu >
-- NAMEPLATES), asi que arrastrar aca mueve la nameplate REAL (llama
-- ns.RefreshNameplateStyle() despues de cada cambio). La barra de vida NO se
-- arrastra (Blizzard la ancla siempre al TOP de la plate, no es configurable
-- en la version real) -- solo se redimensiona con la rueda.
--
-- Piezas, cada una independiente (pedido del usuario 2026-07-18): nombre,
-- valor de vida, cast bar, TEXTO de cast (sigue a la cast bar pero se puede
-- mover aparte -- usa castTextOffsetX/Y, que ReassertCastGeometry en
-- Nameplates.lua ya lee), y los 3 grupos de auras (Enemy Buffs / Personal
-- Debuffs / Big Debuff, cada uno con su PROPIO offset -- ver AURA_GROUPS en
-- Nameplates.lua).
--
-- No es una nameplate protegida de Blizzard, asi que a diferencia del drag
-- real de unitframes (Units.lua) no hace falta lidiar con InCombatLockdown.
-- Carga DESPUES de Nameplates.lua (usa ns.NameplateDefaults/ns.RefreshNameplateStyle).
-- ==========================================================================
local ADDON, ns = ...

local A = ns.ASSETS
local BAR_TEX      = A .. "nameplate_bar.tga"
local BACKDROP_TEX = A .. "nameplate_backdrop.tga"
local BAR_TEXCOORD = { 14/256, 242/256, 14/64, 50/64 }
local FONT = "Fonts\\FRIZQT__.TTF"

local function P() return ns.GetDB() and ns.GetDB().nameplates end

-- La escala de referencia del lienzo vive en la RAIZ de la DB, NO en
-- db.nameplates (2026-07-27). Dos motivos, el primero es un bug real que costo
-- encontrar:
--   1. db.nameplates se REEMPLAZA entera al cargar un perfil de nameplates
--      (Nameplates.lua: `d.nameplates = ns.DeepCopy(p)`) y al resetear
--      (core.lua). Guardada ahi, la referencia desaparecia en silencio y el
--      panel volvia a dibujar a escala 1 -- el sintoma era desconcertante
--      porque `stageScale` (variable Lua en memoria) seguia con el valor bueno
--      mientras la clave del perfil ya no existia.
--   2. Conceptualmente no es un ajuste de ASPECTO: no afecta al nameplate real,
--      solo a con que proporcion se dibuja el editor. No tiene por que viajar
--      dentro de un perfil exportado -- la escala muestreada en la UI de una
--      persona no sirve para la de otra.
-- No hace falta migrar el valor viejo: si falta, se vuelve a muestrear solo en
-- medio segundo (ver el reintento en ToggleNameplateDesigner). La copia vieja se
-- limpia de perfiles/presets via DEAD_NAMEPLATE_FIELDS en Maintenance.lua.
local function GetRefScale()
    local d = ns.GetDB()
    return d and d.designerRefScale
end
local function SetRefScale(v)
    local d = ns.GetDB()
    if d then d.designerRefScale = v end
end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- Dropdown estilo Setup Wizard paso 7 (pedido del usuario) -- MISMO asset
-- 3-slice ("Setup_Dropdown.png") y patron boton+lista que DropdownButton en
-- Setup.lua, copiado aca en vez de expuesto porque Setup.lua depende de
-- locals propios (SF/COLOR_OPTION) que no estan en ns.
local DROPDOWN_TEX = "Interface\\AddOns\\MyCustomFrames\\Assets\\Setup_Dropdown.png"
local function MakeDropdownButton(parent, w, h, text)
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
    fs:SetFont(FONT, 12, "")
    fs:SetPoint("LEFT", 10, 0); fs:SetPoint("RIGHT", -22, 0)
    fs:SetJustifyH("LEFT"); fs:SetMaxLines(1)
    fs:SetTextColor(0.886, 0.847, 0.780)
    fs:SetText(text or "")
    b.text = fs

    local arrow = b:CreateFontString(nil, "OVERLAY")
    arrow:SetFont(FONT, 12, "")
    arrow:SetPoint("RIGHT", -8, 0)
    arrow:SetTextColor(0.58, 0.49, 0.4)
    arrow:SetText("v")
    return b
end

-- Orden de aparicion en el dropdown de seleccion (pedido del usuario).
local ELEMENT_ORDER = {
    "healthBar", "name", "healthValue", "castBar", "castText",
    "bigDebuff", "personalDebuffs", "enemyBuffs", "classification", "raidMark",
}

-- Forward declare TEMPRANO (bug reportado por el usuario: BindSlider/
-- BindColorButton, definidos mas abajo pero ANTES de donde esto vivia
-- originalmente, cerraban sobre un `Reflow` GLOBAL inexistente en vez de
-- este local -- en Lua un `local` declarado DESPUES de un closure no lo
-- afecta, tiene que estar ANTES de cualquier funcion que lo use).
local Reflow

-- Boton con el MISMO skin Plumber que el resto del menu (pedido del
-- usuario: "sigue el formato de diseño de mi menu") -- usa ns.MakeButton,
-- expuesto por Options.lua (carga DESPUES en el .toc, pero esto recien se
-- llama en runtime via CreateDesigner, mucho despues de que TODO cargo).
-- `:SetLabel(text)` uniforme porque ns.MakeButton no tiene :SetText nativo
-- (solo btn.text:SetText), a diferencia de UIPanelButtonTemplate. Declarado
-- ANTES de MakeMiniSlider porque este lo usa para los botones -/+.
local function MakeStyledButton(parent, text, w, h)
    if ns.MakeButton then
        local b = ns.MakeButton(parent, text, w, h)
        b.SetLabel = function(self, t) self.text:SetText(t) end
        return b
    end
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h)
    b:SetText(text)
    b.SetLabel = function(self, t) self:SetText(t) end
    return b
end

-- ==========================================================================
-- Widgets minimos propios (slider + boton de color) para el panel de
-- control de abajo (pedido del usuario: click en un elemento -> aparecen
-- sus opciones, calcado del menu de texto que tenia width/height/color).
-- Options.lua tiene sus propios MakeSlider/MakeColorButton, pero son
-- LOCALES a ese archivo y ademas carga DESPUES de este -- se arman
-- versiones chicas aca en vez de exponer todo ese modulo.
-- ==========================================================================
-- Pedido del usuario: "necesito que los sliders sean como los de mi menu,
-- con opciones para poner el manualmente el numero" -- mismo layout que
-- MakeSlider en Options.lua: label arriba, -/+ y editbox abajo.
local function MakeMiniSlider(parent)
    local s = CreateFrame("Slider", nil, parent)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(110, 14)
    -- false (pedido del usuario: "mas suaves y fluidos") -- con true el
    -- thumb SALTA de a un step entero mientras arrastras, se siente
    -- entrecortado. false deja que el thumb siga al mouse en continuo; el
    -- VALOR guardado se sigue redondeando al step en BindSlider igual.
    s:SetObeyStepOnDrag(false)
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(1, 0.88, 0.6, 0.25)
    track:SetHeight(3)
    track:SetPoint("LEFT", 0, 0); track:SetPoint("RIGHT", 0, 0)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(1, 0.88, 0.6, 0.95)
    thumb:SetSize(8, 14)
    s:SetThumbTexture(thumb)
    local lbl = s:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(FONT, 10, "")
    lbl:SetPoint("BOTTOM", s, "TOP", 0, 2)
    s.lbl = lbl

    -- Fila de abajo: -  [editbox]  +  (mismo patron que Options.lua MakeSlider).
    local minus = MakeStyledButton(s, "-", 16, 14)
    minus:SetPoint("TOP", s, "BOTTOM", -28, -2)
    local box = CreateFrame("EditBox", nil, s, "InputBoxTemplate")
    box:SetSize(40, 14)
    box:SetPoint("LEFT", minus, "RIGHT", 2, 0)
    box:SetAutoFocus(false); box:SetJustifyH("CENTER")
    if box.Left then box.Left:SetAlpha(0) end
    if box.Middle then box.Middle:SetAlpha(0) end
    if box.Right then box.Right:SetAlpha(0) end
    local boxBg = box:CreateTexture(nil, "BACKGROUND", nil, -1)
    boxBg:SetColorTexture(0, 0, 0, 0.45)
    boxBg:SetPoint("TOPLEFT", -3, 1); boxBg:SetPoint("BOTTOMRIGHT", 3, -1)
    local plus = MakeStyledButton(s, "+", 16, 14)
    plus:SetPoint("LEFT", box, "RIGHT", 2, 0)
    s.minus, s.box, s.plus = minus, box, plus
    s:Hide()
    return s
end

-- (re)liga el slider a un campo del perfil especifico -- se llama cada vez
-- que cambia la seleccion, reusando los mismos widgets (ver ControlPanel).
local function BindSlider(slider, label, minV, maxV, step, getV, setV)
    slider:SetScript("OnValueChanged", nil)   -- evita que el SetValue de abajo dispare el handler VIEJO
    slider:SetMinMaxValues(minV, maxV)
    slider:SetValueStep(step)
    slider.lbl:SetText(label)

    local decimals = (step < 1) and 2 or 0
    local fmt = "%." .. decimals .. "f"
    local function roundStep(v) return math.floor(v / step + 0.5) * step end
    local function fmtVal(v) return string.format(fmt, v) end

    local syncing = false
    local function applyValue(nv)
        nv = clamp(roundStep(nv), minV, maxV)
        setV(nv)
        syncing = true; slider:SetValue(nv); syncing = false
        slider.box:SetText(fmtVal(nv))
        Reflow()
    end

    local v = getV() or minV
    slider:SetValue(v)
    slider.box:SetText(fmtVal(v))

    slider:SetScript("OnValueChanged", function(self, nv)
        nv = roundStep(nv)
        setV(nv)
        if not syncing then slider.box:SetText(fmtVal(nv)) end
        Reflow()
    end)
    slider.minus:SetScript("OnClick", function() applyValue((getV() or minV) - step) end)
    slider.plus:SetScript("OnClick", function() applyValue((getV() or minV) + step) end)
    slider.box:SetScript("OnEnterPressed", function(self)
        local nv = tonumber(self:GetText())
        if nv then applyValue(nv) else self:SetText(fmtVal(getV() or minV)) end
        self:ClearFocus()
    end)
    slider.box:SetScript("OnEscapePressed", function(self)
        self:SetText(fmtVal(getV() or minV))
        self:ClearFocus()
    end)
    slider:Show()
end

local function MakeMiniColorButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(22, 22)
    local border = b:CreateTexture(nil, "BACKGROUND")
    border:SetPoint("TOPLEFT", -1, 1); border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0, 0, 0, 1)
    local sw = b:CreateTexture(nil, "OVERLAY")
    sw:SetAllPoints()
    b.sw = sw
    local lbl = b:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(FONT, 10, "")
    lbl:SetPoint("BOTTOM", b, "TOP", 0, 2)
    b.lbl = lbl
    b:Hide()
    return b
end

-- Mismo patron que MakeColorButton en Options.lua (ColorPickerFrame API).
local function BindColorButton(btn, label, c)
    btn.lbl:SetText(label)
    btn.sw:SetColorTexture(c.r, c.g, c.b)
    local r0, g0, b0 = c.r, c.g, c.b
    btn:SetScript("OnClick", function()
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c.r, g = c.g, b = c.b, hasOpacity = false,
            swatchFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                c.r, c.g, c.b = nr, ng, nb
                btn.sw:SetColorTexture(nr, ng, nb)
                Reflow()
            end,
            cancelFunc = function()
                c.r, c.g, c.b = r0, g0, b0
                btn.sw:SetColorTexture(r0, g0, b0)
                Reflow()
            end,
        })
    end)
    btn:Show()
end

local designer   -- root frame, creado la 1ra vez que se abre
-- Tabla de PIEZAS del nameplate de mentira, con los mismos nombres logicos que
-- consume ns.NPBuild.LayoutPlate. El editor ya no tiene lista de colocacion
-- propia: entrega sus frames y la MISMA funcion que posiciona el nameplate
-- real los posiciona a estos (2026-07-28, rehecho desde cero). Antes habia una
-- lista `els` con el ancla y el layout de cada elemento escritos aca -- o sea
-- una segunda implementacion, que es lo que hacia aparecer una diferencia
-- nueva cada vez que se arreglaba la anterior.
local pieces = { auras = {} }
-- ns.MakeEditHighlight() crea el borde/etiqueta pero lo deja OCULTO por
-- defecto (el resto del addon lo muestra/oculta a mano segun el modo
-- edicion) -- aca se muestran SIEMPRE mientras el designer esta abierto, asi
-- se ve que es arrastrable cada pieza. Se juntan todos aca para Show()/Hide()
-- de una sola vez.
local highlights = {}
local function TrackHighlight(hl) highlights[#highlights + 1] = hl; return hl end
-- Toggle de outlines (pedido del usuario): controla si los bordes de
-- highlight se muestran mientras el panel esta abierto -- por defecto ON.
local outlinesVisible = true

-- Empuja el cambio a las nameplates REALES visibles ahora mismo (la misma
-- funcion que ya usa Options.lua al mover un slider del menu).
local function PushLive()
    if ns.RefreshNameplateStyle then ns.RefreshNameplateStyle() end
end

-- Escala actual del "stage" (ver CreateDesigner/UpdateStageScale mas abajo) --
-- pedido del usuario (2026-07-18): que la barra del Designer se vea del
-- mismo tamaño relativo que la nameplate REAL de tu target ahora mismo, para
-- editar con la proporcion correcta en vez de un tamaño fijo arbitrario.
--
-- ESCALA DE REFERENCIA (2026-07-27). No es cosmetica: el nameplate real tiene
-- DOS escalas conviviendo, y esta variable es la que las diferencia.
--   * barra de vida / cast / clasificacion / marca de raid -> hijos de `uf`,
--     SIN contra-escala: encogen con la distancia (escala = effScale).
--   * nombre y los 3 grupos de auras -> `SetScale(1/effScale)` (Nameplates.lua
--     lineas ~816 y ~1254): quedan a escala de PANTALLA fija, no encogen.
-- YA NO hay dos divisores (2026-07-28). Desde que TODOS los offsets de
-- ns.NPLayout estan en unidades del plate -- tambien los del regimen
-- "screen" -- el factor es el mismo para todos: stageScale * ZOOM. Antes el
-- nombre y las auras usaban uno sin stageScale, que era coherente con como se
-- dibujaban entonces pero acoplaba su posicion a la distancia del mob.
--
-- Si stageScale = 1 los dos divisores colapsan y el panel dibuja todo a la
-- misma escala -- que es exactamente lo que se reporto: "las posiciones no
-- concuerdan" / los personal debuffs "se ven muy lejos" en el juego. Con
-- nameplates corriendo a ~0.64, en el juego la barra es ~36% mas chica
-- respecto de las auras de lo que mostraba el panel.
--
-- Antes esto se sincronizaba con un ticker que leia el target cada 0.2s, y eso
-- traia el problema opuesto (el lienzo se re-escalaba solo mientras editabas,
-- ver la nota donde estaba scaleDriver). Ahora es un valor de REFERENCIA:
-- se muestrea UNA vez, se persiste, y solo cambia si el usuario lo pide.
local stageScale = 1

-- Escala efectiva de un nameplate REAL para usar como referencia. Prueba
-- primero el del target y si no hay, cualquiera visible -- asi funciona sin
-- necesidad de tener algo seleccionado.
-- GetEffectiveScale (NO GetScale): la geometria real (ReassertNameGeometry)
-- usa la escala ACUMULADA -- propia por la de todos los padres -- mientras que
-- GetScale() devuelve solo la propia de la plate, sin UIParent/WorldFrame. Con
-- uiScale != 1 el stage quedaba desincronizado; eso explicaba el mismatch
-- reportado el 2026-07-19 ("en el panel esta mas junto, en la realidad esta
-- mas lejos").
local function SampleNameplateScale()
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local plates = {}
    if UnitExists("target") then
        local t = C_NamePlate.GetNamePlateForUnit("target")
        if t then plates[#plates + 1] = t end
    end
    if C_NamePlate.GetNamePlates then
        for _, pl in ipairs(C_NamePlate.GetNamePlates()) do plates[#plates + 1] = pl end
    end
    for _, plate in ipairs(plates) do
        local uf = plate.UnitFrame or plate
        local ok, s = pcall(uf.GetEffectiveScale, uf)
        if ok and type(s) == "number" and s > 0 then return s end
    end
    return nil
end

-- ZOOM (pedido del usuario): "ver los elementos mas grande DENTRO del
-- panel", no solo agrandar la ventana -- multiplicador puramente visual que
-- se APLICA junto con stageScale (stage) o solo (nombre, que en la
-- nameplate real no escala con la distancia). Como es parte de la escala
-- real que se le aplica al frame, hay que dividir por el mismo factor al
-- guardar el delta del drag (ver divisor mas abajo) para que arrastrar Npx
-- en pantalla siga guardando el mismo offset de siempre, zoom aparte.
local ZOOM = 1.6
local function StageDivisor() return stageScale * ZOOM end

-- (`anyDragActive` eliminado 2026-07-27: existia solo para congelar el ticker
-- de escala del stage a mitad de un arrastre. Ese ticker ya no existe -- el
-- lienzo no espeja la escala del target -- asi que no hay nada que congelar.)

-- ==========================================================================
-- Helper: sub-elemento ARRASTRABLE (mueve un par offsetX/offsetY del perfil).
-- Delta-based: como el frame no cambia de escala entre el inicio y el fin
-- del arrastre, el delta de GetCenter() ANTES/DESPUES del mismo frame es
-- directamente el delta a sumarle al offset guardado (no hace falta
-- convertir escalas, a diferencia de comparar centros de frames DISTINTOS).
--
-- `getDivisor` (funcion opcional): los handles que viven DENTRO de un frame
-- escalado (stage, o el propio nombre con ZOOM) se arrastran en pixeles de
-- pantalla REALES, pero el campo del perfil representa unidades LOCALES
-- (se multiplican por la escala al dibujarse, igual que en Nameplates.lua)
-- -- hay que DIVIDIR el delta de pantalla por esa escala antes de guardarlo,
-- o arrastrar 20px se guardaria como "20 unidades locales" y se veria movido
-- 20*escala px, mas de lo que arrastraste aca. nil = sin escalar (divisor 1).
--
-- BUG (reportado por el usuario, 2026-07-18): StartMoving()/StopMovingOrSizing()
-- de Blizzard DESANCLA el frame (lo deja en un punto absoluto, ya no relativo
-- a su anchor real) -- sin re-anclarlo depues, el elemento queda "flotando"
-- ahi para siempre y deja de seguir al resto cuando se mueve la ventana del
-- Designer. Fix: llamar Reflow() (no solo PushLive()) al soltar, que vuelve a
-- hacer SetPoint(point, anchor, relPoint, ...) sobre el ancla real.
-- ==========================================================================
-- Pedido del usuario 2026-07-19: "que no pueda alterar las auras en
-- combate, me salga un cartel señalando" -- UIErrorsFrame es el mismo
-- "cartel" rojo que usa Blizzard para "No se puede hacer eso ahora" (no es
-- una restriccion real de Blizzard sobre estos datos -- son solo tablas Lua
-- nuestras -- es una eleccion del usuario para no arruinar el layout sin
-- querer en medio de un pull).
local function CombatBlocked()
    if not InCombatLockdown or not InCombatLockdown() then return false end
    UIErrorsFrame:AddMessage("No podés editar las auras en combate.", 1, 0.2, 0.2)
    return true
end

-- 2026-07-19: reescrito de raiz -- la version anterior usaba
-- StartMoving()/StopMovingOrSizing() (mueve el frame LIBRE, desanclado) y
-- despues trataba de "traducir" el desplazamiento a un offset via
-- GetCenter() antes/despues. Confirmado con debug en vivo: para handles con
-- anclaje de ESQUINA (BOTTOMLEFT/BOTTOMRIGHT, usado por las auras segun
-- direccion), esa traduccion queda con un error proporcional al
-- desplazamiento (el "salto/tironeo" que reporto el usuario, persistente
-- incluso reiniciando el juego) -- el frame LIBRE y el frame RE-ANCLADO via
-- SetPoint no son matematicamente equivalentes para puntos de esquina.
-- Fix real: el drag YA NO desancla el frame -- en cada tick del arrastre se
-- recalcula el offset desde el cursor y se llama Reflow(), asi la posicion
-- SIEMPRE se dibuja por el mismo camino (SetPoint anclado), sin una fase
-- "libre" que despues haya que reconciliar. Elimina la clase de bug entera,
-- sin importar cual haya sido la causa exacta.
local function MakeDraggable(handle, xKey, yKey, getDivisor, combatGuard)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function(self)
        if combatGuard and CombatBlocked() then return end
        local p = P(); if not p then return end
        local startCursorX, startCursorY = GetCursorPosition()
        local startValX, startValY = p[xKey] or 0, p[yKey] or 0
        self:SetScript("OnUpdate", function()
            local p2 = P(); if not p2 then return end
            local div = (getDivisor and getDivisor() or 1) * UIParent:GetEffectiveScale()
            if not (div and div > 0) then div = 1 end
            local cx, cy = GetCursorPosition()
            p2[xKey] = startValX + (cx - startCursorX) / div
            p2[yKey] = startValY + (cy - startCursorY) / div
            Reflow()
        end)
    end)
    handle:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        if combatGuard and CombatBlocked() then return end
        Reflow()
    end)
end

-- `root`/`key`: pedido del usuario 2026-07-19 ("que los elementos solo los
-- pueda escalar con el scroll si los tengo seleccionado") -- antes la rueda
-- funcionaba con solo pasar el mouse por encima, sin importar si estaba
-- seleccionado, lo que hacia facil des-escalar sin querer al mover el mouse
-- sobre el panel. `key` es nil para handles que no participan del sistema
-- de seleccion (no deberia pasar, pero por las dudas deja pasar la rueda).
local function MakeWheelResize(handle, onWheel, root, key, combatGuard)
    handle:EnableMouseWheel(true)
    handle:SetScript("OnMouseWheel", function(self, dir)
        if key and (not root or root.selectedKey ~= key) then return end
        if combatGuard and CombatBlocked() then return end
        local p = P(); if not p then return end
        onWheel(p, dir)
        Reflow()
    end)
end

-- 2026-07-19, pedido del usuario: "volvamos al metodo de controlar
-- posicion, escala y apariencia de mis auras... separadas como habia dicho
-- antes" -- de vuelta a 3 grupos INDEPENDIENTES (2 iconos de mentira cada
-- uno, alcanza para ver posicion/tamaño), cada uno con su propio checkbox
-- de "shown" (mismo patron que antes de pasar a auras nativas).
-- 3 iconos de mentira (NO 2) -- tiene que ser EXACTO al AURA_MAX_PER_CAT=3
-- real (Nameplates.lua): el holder real SIEMPRE se dimensiona para 3 iconos
-- aunque muestre menos, y como se ancla por el punto "BOTTOM" (centrado
-- horizontal), un ancho de holder distinto entre mock y real corre el
-- centro -- y por lo tanto TODOS los iconos -- a un X distinto. Con 2 en vez
-- de 3 el mock quedaba desalineado del real incluso con el mismo offsetX
-- guardado (bug reportado 2026-07-19, "no concuerda con la ubicacion real").
local function MakeAuraGroupMock(root, label, showKey)
    -- Holder + iconos vienen de ns.NPBuild con preview=true: EL MISMO codigo
    -- que arma los reales en Nameplates.lua, con la misma cuenta de iconos y la
    -- misma formula de tamaño/inset. Lo unico que cambia es lo que no puede
    -- existir en un panel (widget Cooldown y datos de unidad en vivo).
    local holder = ns.NPBuild.AuraGroup(root, P(), true)
    local hl = TrackHighlight(ns.MakeEditHighlight(holder, label))

    local shownCB = CreateFrame("CheckButton", nil, root, "UICheckButtonTemplate")
    shownCB:SetSize(16, 16)
    shownCB:SetPoint("BOTTOMLEFT", hl, "TOPLEFT", -18, -1)
    shownCB:SetScript("OnClick", function(self)
        if CombatBlocked() then
            -- Revierte el check visual -- el click ya cambio GetChecked()
            -- antes de que corra este script.
            self:SetChecked(not self:GetChecked())
            return
        end
        local p = P(); if not p then return end
        p[showKey] = self:GetChecked() and true or false
        Reflow()
    end)

    return holder, hl, shownCB
end

-- (AURA_ANCHOR_POINT local ELIMINADO 2026-07-27: era una tercera copia del
-- mismo mapeo -- una aca, otra en Nameplates.lua -- justo la clase de
-- duplicacion que desincronizaba el panel del juego. Vive en ns.NPLayout y lo
-- resuelve ns.NPLayout.AuraGroup, que ya devuelve el punto correcto.)

-- Recuadro placeholder cuadrado CON icono de vista previa real (pedido del
-- usuario) -- para elite/clasificacion usa la MISMA textura de AzeriteUI que
-- el addon real (CLASS_TEX en Nameplates.lua). `raidIndex` (1-8): si se pasa,
-- usa la API NATIVA SetRaidTargetIconTexture (mismo metodo que usa Blizzard
-- para dibujar las marcas de raid en cualquier frame) en vez de texcoords a
-- mano -- pedido del usuario: que sea la calavera/death mark (indice 8).
-- FrameLevel alto (pedido del usuario 2026-07-19: "deberian estar encima de
-- todo, no solo en el panel") -- espeja el mismo tratamiento que
-- CreateCustomClassification/LockRaidMark en Nameplates.lua (strata TOOLTIP
-- alla; aca alcanza con un nivel alto ya que todo el panel vive en su propia
-- strata "HIGH").
local function MakeBadgeMock(root, size, previewTex, raidIndex)
    local holder = CreateFrame("Frame", nil, root)
    holder:SetSize(size, size)
    holder:SetFrameLevel(100)
    local icon = holder:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    if raidIndex then
        icon:SetTexture(previewTex)
        SetRaidTargetIconTexture(icon, raidIndex)
    else
        icon:SetTexture(previewTex)
    end
    holder.icon = icon
    local hl = TrackHighlight(ns.MakeEditHighlight(holder))
    return holder, hl
end

-- ==========================================================================
-- Construccion (una sola vez, perezosa -- se llama desde ToggleNameplateDesigner).
-- ==========================================================================
local function CreateDesigner()
    local root = CreateFrame("Frame", "MyCF_NameplateDesigner", UIParent)
    -- 620 (antes 580, +40 pedido del usuario 2026-07-19: la fila de
    -- padding/direccion quedaba fuera de la ventana) -- el margen inferior
    -- del viewport crece la MISMA cantidad (ver viewport:SetPoint mas abajo)
    -- para que el viewport en si NO cambie de tamaño, todo el espacio extra
    -- va a la franja de controles de abajo.
    root:SetSize(480, 630)
    root:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    -- Pedido del usuario 2026-07-19: "que el strata de mi panel de
    -- nameplates este por encima del menu" -- el panel principal (Options.lua)
    -- tambien usaba "HIGH" en ese momento, asi que cual quedaba arriba dependia
    -- del orden de creacion/nivel, no garantizado. Un escalon arriba en la
    -- jerarquia de strata de Blizzard aseguraba que el Designer SIEMPRE quedara
    -- por encima del menu, sin importar el orden.
    -- ACTUALIZADO (2026-07-27): el panel principal subio de "HIGH" a "DIALOG"
    -- (pedido del usuario, chocaba raro con MailBanner.lua -- ver su comentario
    -- en Options.lua) -- este frame sube un escalon MAS, a "FULLSCREEN", para
    -- conservar la MISMA garantia de arriba (sin esto, ambos quedarian
    -- empatados en DIALOG y el problema original volveria, esta vez entre
    -- Options.lua y este Designer).
    root:SetFrameStrata("FULLSCREEN")
    -- Pedido del usuario 2026-07-19: "si lo muevo a los bordes de la
    -- pantalla no se esconde" -- mismo SetClampedToScreen(true) que ya usa
    -- el panel principal (Options.lua), evita arrastrarlo mas alla del borde
    -- visible de la pantalla.
    root:SetClampedToScreen(true)
    root:SetMovable(true)
    root:EnableMouse(true)
    root:RegisterForDrag("LeftButton")
    root:SetScript("OnDragStart", function(self) self:StartMoving() end)
    root:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Forward-declare (pedido del usuario: "que siempre este centrado" al
    -- zoomear) -- se asigna mas abajo, junto con el viewport/content, pero
    -- el slider de zoom (arriba en el panel) lo necesita ANTES.
    local RecenterContent

    -- Fondo Plumber (pedido del usuario: "sigue el formato de diseño de mi
    -- menu") -- mismo ns.PL.BG que usa Options.lua, expuesto en core.lua.
    local bg = root:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    if ns.PL and ns.PL.BG then
        bg:SetTexture(ns.PL.BG)
        bg:SetVertexColor(1, 1, 1, 0.92)
    else
        bg:SetColorTexture(0, 0, 0, 0.35)
    end

    local title = root:CreateFontString(nil, "OVERLAY")
    title:SetFont(FONT, 12, "OUTLINE")
    title:SetPoint("TOP", root, "TOP", 0, -6)
    title:SetText("|cffffe19bNameplate Designer|r")

    local hint = root:CreateFontString(nil, "OVERLAY")
    hint:SetFont(FONT, 9, "")
    hint:SetPoint("BOTTOM", root, "BOTTOM", 0, 6)
    hint:SetWidth(440)
    hint:SetJustifyH("CENTER")
    hint:SetTextColor(0.8, 0.8, 0.8)
    hint:SetText("Click a piece to select it (options appear below) — drag to move, scroll to resize. Drag the dark background to reposition this window. /mcfnpdesigner to close.")

    -- Forward-declares (pedido del usuario: click en un elemento -> aparecen
    -- sus opciones abajo, las que tenia el menu de texto: width/height/color).
    -- selSpecs se llena mas abajo, a medida que se crea cada pieza.
    local selSpecs = {}
    local selectedKey
    local SelectElement
    local DeselectElement

    local closeBtn = CreateFrame("Button", nil, root, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", root, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() root:Hide() end)

    -- Reset (pedido del usuario): mismo reset que el boton "Reset nameplates"
    -- de Options.lua (np_general) -- vuelve TODO el perfil de nameplates
    -- (posiciones, tamaños Y colores) a los defaults de NameplateDefaults.
    local resetBtn = MakeStyledButton(root, "Reset", 90, 20)
    -- y=-28 (pedido del usuario, "organiceme el panel"): misma fila que la
    -- columna de perfiles a la derecha (antes esta arrancaba en -4 y
    -- quedaba desalineada, chocando en altura con el boton de cerrar).
    resetBtn:SetPoint("TOPLEFT", root, "TOPLEFT", 8, -28)
    resetBtn:SetScript("OnClick", function()
        if ns.ResetUnit then ns.ResetUnit(ns.NAMEPLATES_KEY) end
        Reflow()
    end)

    -- Toggle de outlines/regiones (pedido del usuario, faltaba): apaga/prende
    -- los bordes verdes de edicion de TODOS los elementos sin cerrar el
    -- panel -- util para ver como queda "limpio" sin las guias encima.
    local outlineBtn = MakeStyledButton(root, "Outlines: On", 90, 20)
    outlineBtn:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -4)
    outlineBtn:SetScript("OnClick", function(self)
        outlinesVisible = not outlinesVisible
        self:SetLabel(outlinesVisible and "Outlines: On" or "Outlines: Off")
        for _, hl in ipairs(highlights) do hl:SetShown(outlinesVisible) end
    end)

    -- Texto FIJO desde 2026-07-27: el lienzo ya no espeja la escala del target
    -- (ver la nota larga donde estaba el scaleDriver). Se deja el cartel para
    -- que quede claro QUE escala estas viendo -- si no, al comparar con un
    -- nameplate real de cerca o de lejos parece que el panel "miente".
    local scaleLabel = root:CreateFontString(nil, "OVERLAY")
    scaleLabel:SetFont(FONT, 10, "")
    scaleLabel:SetPoint("TOP", title, "BOTTOM", 0, -4)
    scaleLabel:SetTextColor(0.7, 0.85, 1)
    scaleLabel:SetText("Reference scale 1.00")

    -- Zoom del panel (pedido del usuario: "poder hacer un zoom en el panel,
    -- para ver mas grande los elementos") -- ANTES era un multiplicador fijo
    -- (1.6), ahora ajustable en vivo. Liga a la variable local ZOOM (no un
    -- campo del perfil, es solo una preferencia visual del Designer).
    local zoomSlider = MakeMiniSlider(root)
    zoomSlider:SetPoint("TOP", scaleLabel, "BOTTOM", 0, -18)
    BindSlider(zoomSlider, "Panel zoom", 1, 3, 0.1,
        function() return ZOOM end,
        function(v)
            ZOOM = v
            -- "Que siempre este centrado" -- recentra al cambiar el zoom,
            -- asi nunca se pierde de vista por quedar paneado a un costado.
            if RecenterContent then RecenterContent() end
        end)

    -- Escala de REFERENCIA (2026-07-27) -- ver la nota larga de `stageScale`.
    -- Distinta del Panel zoom: el zoom agranda TODO por igual (comodidad
    -- visual), esto reproduce la proporcion REAL entre lo que encoge con la
    -- distancia (barra) y lo que no (nombre y auras). Es lo unico que hace que
    -- el panel prediga de verdad como se ve en el juego.
    -- No se toca sola mientras editas: se muestrea al abrir (con reintento
    -- acotado hasta conseguir un nameplate real, ver ToggleNameplateDesigner) y
    -- de ahi en mas solo si el usuario mueve el slider o aprieta Sample.
    local refSlider = MakeMiniSlider(root)
    refSlider:SetPoint("TOP", zoomSlider, "BOTTOM", 0, -18)
    BindSlider(refSlider, "Reference scale", 0.3, 2, 0.01,
        function() return stageScale end,
        function(v)
            stageScale = v
            SetRefScale(v)
            designer.scaleLabel:SetText(("Reference scale %.2f"):format(stageScale))
            designer.stage:SetScale(stageScale * ZOOM)
            Reflow()
        end)

    -- Lee la escala de un nameplate real y la vuelca en el slider. Delega en
    -- SetValue a proposito: dispara el OnValueChanged del propio slider, que ya
    -- persiste, actualiza el cartel, re-escala el stage y hace Reflow -- una
    -- sola implementacion en vez de repetirla aca y que se desincronicen.
    local sampleBtn = MakeStyledButton(root, "Sample", 60, 18)
    sampleBtn:SetPoint("LEFT", refSlider, "RIGHT", 8, 0)
    sampleBtn:SetScript("OnClick", function()
        local s = SampleNameplateScale()
        if not s then
            print("|cffff5555[MCF]|r No visible nameplate to sample from -- get one on screen first.")
            return
        end
        refSlider:SetValue(clamp(s, 0.3, 2))
    end)

    -- ---- Perfiles (pedido del usuario: "necesito crear perfiles, y opcion
    -- para tener la configuracion actual como preterminada") -- guardar
    -- snapshots con nombre (ns.SaveNameplateProfile) y cargarlos despues
    -- (ns.LoadNameplateProfile), o fijar el estado actual como lo que Reset
    -- restaura de ahi en mas (ns.SetNameplateUserDefault). Todo en
    -- Nameplates.lua, esto solo arma los widgets.
    local profileBox = CreateFrame("EditBox", nil, root, "InputBoxTemplate")
    profileBox:SetSize(100, 20)
    profileBox:SetPoint("TOPRIGHT", root, "TOPRIGHT", -8, -28)
    profileBox:SetAutoFocus(false)
    profileBox:SetText("My Profile")

    local saveProfileBtn = MakeStyledButton(root, "Save As", 70, 20)
    saveProfileBtn:SetPoint("RIGHT", profileBox, "LEFT", -4, 0)
    saveProfileBtn:SetScript("OnClick", function()
        local name = profileBox:GetText()
        if name and name ~= "" and ns.SaveNameplateProfile then ns.SaveNameplateProfile(name) end
    end)

    local defaultBtn = MakeStyledButton(root, "Set as Default", 174, 20)
    defaultBtn:SetPoint("TOPRIGHT", profileBox, "BOTTOMRIGHT", 0, -4)
    defaultBtn:SetScript("OnClick", function()
        if ns.SetNameplateUserDefault then ns.SetNameplateUserDefault() end
    end)

    -- Dropdown para CARGAR un perfil guardado (mismo estilo Setup Wizard).
    local profileDropdown = MakeDropdownButton(root, 174, 20, "Load profile...")
    profileDropdown:SetPoint("TOPRIGHT", defaultBtn, "BOTTOMRIGHT", 0, -4)
    local profileList = CreateFrame("Frame", nil, root)
    profileList:SetFrameLevel(profileDropdown:GetFrameLevel() + 5)
    profileList:SetPoint("TOP", profileDropdown, "BOTTOM", 0, -2)
    profileList:Hide()
    local profileListBg = profileList:CreateTexture(nil, "BACKGROUND")
    profileListBg:SetAllPoints()
    profileListBg:SetColorTexture(0, 0, 0, 0.75)
    local profileRows = {}
    local function RebuildProfileList()
        for _, r in ipairs(profileRows) do r:Hide() end
        wipe(profileRows)
        local names = ns.ListNameplateProfiles and ns.ListNameplateProfiles() or {}
        profileList:SetSize(174, math.max(#names * 22, 4))
        for i, name in ipairs(names) do
            -- 174 - 20 (pedido del usuario 2026-07-19: "que pueda eliminar
            -- perfiles" -- ya existia via click derecho, pero sin ninguna
            -- pista visual, asi que nadie lo encontraba) -- deja 20px a la
            -- derecha para un boton "x" visible; el click derecho se deja
            -- funcionando igual, como atajo.
            local rb = MakeDropdownButton(profileList, 154, 22, name)
            rb:SetPoint("TOPLEFT", 0, -(i - 1) * 22)
            rb:SetScript("OnClick", function()
                if ns.LoadNameplateProfile then ns.LoadNameplateProfile(name) end
                profileBox:SetText(name)
                profileList:Hide()
                Reflow()
            end)
            rb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            rb:HookScript("OnClick", function(_, button)
                if button == "RightButton" and ns.DeleteNameplateProfile then
                    ns.DeleteNameplateProfile(name)
                    RebuildProfileList()
                    profileList:Show()
                end
            end)
            profileRows[#profileRows + 1] = rb

            -- Boton "x" visible -- pide confirmacion con un StaticPopup nativo
            -- (borrar es irreversible) antes de llamar DeleteNameplateProfile.
            local delBtn = MakeStyledButton(profileList, "x", 20, 22)
            delBtn:SetPoint("TOPRIGHT", 0, -(i - 1) * 22)
            delBtn:SetScript("OnClick", function()
                StaticPopupDialogs["MCF_DELETE_NP_PROFILE"] = StaticPopupDialogs["MCF_DELETE_NP_PROFILE"] or {
                    text = "Delete nameplate profile '%s'?",
                    button1 = YES or "Yes",
                    button2 = NO or "No",
                    OnAccept = function(self)
                        if ns.DeleteNameplateProfile then ns.DeleteNameplateProfile(self.data) end
                        RebuildProfileList()
                        profileList:Show()
                    end,
                    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
                }
                local dlg = StaticPopup_Show("MCF_DELETE_NP_PROFILE", name)
                if dlg then dlg.data = name end
            end)
            profileRows[#profileRows + 1] = delBtn
        end
    end
    profileDropdown:SetScript("OnClick", function()
        if profileList:IsShown() then profileList:Hide() else RebuildProfileList(); profileList:Show() end
    end)

    -- ---- Panel de control (pedido del usuario): click en cualquier pieza de
    -- arriba selecciona su anillo verde y muestra aca abajo X/Y + width/
    -- height (o font size + opacidad) + color -- los mismos controles que
    -- antes vivian en el menu de texto (/mcfmenu), ahora todo en un solo
    -- lugar, y con sliders de X/Y para mover mas organizado que a ojo con
    -- el drag solo.
    -- Dropdown de seleccion (pedido del usuario: "para no tener que
    -- clickear siempre", el click en el mock sigue funcionando igual) --
    -- lista TODOS los elementos por nombre, sin tener que encontrarlos a
    -- ojo en el canvas.
    local elementDropdown = MakeDropdownButton(root, 200, 24, "Select element")
    -- y=195 (antes 168, pedido del usuario 2026-07-19: "subelo un poquito"
    -- + reorganizacion general de toda la franja de abajo, ver comentario en
    -- ctrlTitle/sliderX/paddingSlider mas abajo).
    elementDropdown:SetPoint("BOTTOM", root, "BOTTOM", 0, 195)

    local elementList = CreateFrame("Frame", nil, root)
    elementList:SetFrameLevel(elementDropdown:GetFrameLevel() + 5)
    -- Abre hacia ABAJO (pedido del usuario, antes abria hacia arriba).
    elementList:SetPoint("TOP", elementDropdown, "BOTTOM", 0, -2)
    elementList:Hide()
    -- Fondo (pedido del usuario: "no tiene fondo, con opacidad baja estaria
    -- bien") -- las filas ya tienen su propio 3-slice, pero sin esto se veia
    -- el mundo/canvas detras entre ellas.
    local listBg = elementList:CreateTexture(nil, "BACKGROUND")
    listBg:SetAllPoints()
    listBg:SetColorTexture(0, 0, 0, 0.75)

    local elementRows = {}
    local function RebuildElementList()
        for _, r in ipairs(elementRows) do r:Hide() end
        wipe(elementRows)
        -- La lista se ABRE hacia arriba desde el boton -- pedido del
        -- usuario: que el orden se lea de arriba a abajo igual que
        -- ELEMENT_ORDER (antes quedaba al reves, el primero abajo del
        -- todo). Primero se mide el total y se ancla cada fila por TOP,
        -- asi la primera queda arriba y la ultima pegada al boton.
        local n = 0
        for _, key in ipairs(ELEMENT_ORDER) do if selSpecs[key] then n = n + 1 end end
        elementList:SetSize(200, math.max(n * 24, 4))
        local i = 0
        for _, key in ipairs(ELEMENT_ORDER) do
            local spec = selSpecs[key]
            if spec then
                local rb = MakeDropdownButton(elementList, 200, 22, spec.title)
                rb:SetPoint("TOPLEFT", 0, -i * 24)
                rb:SetScript("OnClick", function()
                    elementDropdown.text:SetText(spec.title)
                    elementList:Hide()
                    if SelectElement then SelectElement(key) end
                end)
                elementRows[#elementRows + 1] = rb
                i = i + 1
            end
        end
    end
    elementDropdown:SetScript("OnClick", function()
        if elementList:IsShown() then elementList:Hide() else RebuildElementList(); elementList:Show() end
    end)

    -- Franja de controles reorganizada 2026-07-19 (pedido del usuario:
    -- "reorganiza el panel... algunos sliders de las auras aun estan muy al
    -- borde inferior") -- toda la franja usa el rango completo disponible
    -- (0-250, ver viewport:SetPoint mas arriba) con espaciado parejo de
    -- ~55-60px entre filas, en vez de quedar todo apretado contra el fondo.
    local ctrlTitle = root:CreateFontString(nil, "OVERLAY")
    ctrlTitle:SetFont(FONT, 12, "OUTLINE")
    ctrlTitle:SetPoint("BOTTOM", root, "BOTTOM", 0, 225)
    ctrlTitle:SetTextColor(1, 0.882, 0.608)
    ctrlTitle:SetText("Click a piece above to edit it")

    -- Fila 1: posicion (X/Y) -- mismos campos que ya mueve el drag, para
    -- ajustar fino con numeros en vez de a ojo.
    local sliderX = MakeMiniSlider(root)
    sliderX:SetPoint("BOTTOM", root, "BOTTOM", -140, 175)
    local sliderY = MakeMiniSlider(root)
    sliderY:SetPoint("BOTTOM", root, "BOTTOM", 40, 175)

    -- Fila 2: tamaño (width/height O font size + opacidad, segun el tipo de
    -- pieza) + color.
    local sliderW = MakeMiniSlider(root)
    sliderW:SetPoint("BOTTOM", root, "BOTTOM", -140, 110)
    local sliderH = MakeMiniSlider(root)
    sliderH:SetPoint("BOTTOM", root, "BOTTOM", 40, 110)
    local colorBtn = MakeMiniColorButton(root)
    colorBtn:SetPoint("BOTTOM", root, "BOTTOM", 195, 130)

    -- Fila 3 (SOLO grupos de auras): padding entre iconos + direccion de
    -- crecimiento (right/left/center). y=45 (antes 30/-8, seguia muy pegado
    -- al borde/al hint de abajo) -- ahora tiene margen real tanto contra la
    -- fila 2 (arriba) como contra el hint (abajo, y=6).
    local paddingSlider = MakeMiniSlider(root)
    paddingSlider:SetPoint("BOTTOM", root, "BOTTOM", -140, 50)
    local directionBtn = MakeStyledButton(root, "Direction: Right", 140, 20)
    directionBtn:SetPoint("BOTTOM", root, "BOTTOM", 60, 54)
    local AURA_DIRECTIONS = { "right", "left", "center" }
    directionBtn:SetScript("OnClick", function(self)
        if CombatBlocked() then return end
        local key = self._dirKey
        local p = P(); if not p or not key then return end
        local cur, idx = p[key] or "right", 1
        for i, v in ipairs(AURA_DIRECTIONS) do if v == cur then idx = i break end end
        local nxt = AURA_DIRECTIONS[(idx % #AURA_DIRECTIONS) + 1]
        p[key] = nxt
        self:SetLabel("Direction: " .. nxt:sub(1, 1):upper() .. nxt:sub(2))
        Reflow()
    end)

    -- Fila extra (SOLO grupos de auras): boton que cicla entre editar el
    -- tamaño/color del ICONO (comportamiento de siempre) y editar el
    -- offset/tamaño de fuente/color del texto de CARGAS o del texto de
    -- TIEMPO restante -- pedido del usuario 2026-07-19 ("desde el panel
    -- debo controlar offset, size, y color de eso tiempo remaining y
    -- cargas"). Reutiliza sliderW/sliderH/colorBtn/paddingSlider en vez de
    -- sumar mas widgets (no hay espacio libre en la franja inferior).
    local textModeBtn = MakeStyledButton(root, "Edit: Icon", 140, 20)
    textModeBtn:SetPoint("BOTTOM", root, "BOTTOM", 195, 175)
    local TEXT_MODES = { "icon", "count", "time" }
    local TEXT_MODE_LABEL = { icon = "Edit: Icon", count = "Edit: Count Text", time = "Edit: Time Text" }
    local textMode = "icon"

    -- Divisores (pedido del usuario: "organiceme el panel un poquito") --
    -- mismo asset que separa secciones en Options.lua, marca donde termina
    -- cada bloque de controles sin tocar el viewport en si.
    local function Divider(y)
        local d = root:CreateTexture(nil, "ARTWORK")
        if ns.PL and ns.PL.DIV_H then
            d:SetTexture(ns.PL.DIV_H)
        else
            d:SetColorTexture(1, 0.88, 0.6, 0.25)
        end
        d:SetPoint("TOPLEFT", root, "TOPLEFT", 8, y)
        d:SetPoint("TOPRIGHT", root, "TOPRIGHT", -8, y)
        d:SetHeight(2)
        return d
    end
    -- root es 580 de alto; viewport va de -110 (TOP) a -380 (= 580-200,
    -- BOTTOM) medido desde el TOP -- los divisores van pegados a cada
    -- borde, AFUERA del viewport (no lo tocan).
    Divider(-102)   -- cierra el bloque de arriba (reset/outlines/zoom/perfiles), justo antes del viewport
    Divider(-388)   -- abre el bloque de abajo (dropdown + controles), justo despues del viewport

    -- ---- Viewport (pedido del usuario: "el zoom se sale del panel, que
    -- siempre este centrado y este en una seccion propia que pueda
    -- desplazar y mover todo") -- recuadro con CLIPPING real (SetClipsChildren)
    -- entre los controles de arriba y la tira de controles de abajo. Todo lo
    -- que antes colgaba directo de `root` (stage, nombre, crosshair) ahora
    -- cuelga de `content`, que vive DENTRO del viewport y se puede arrastrar
    -- (pan) libremente sin que nada se salga del recuadro.
    local viewport = CreateFrame("Frame", nil, root)
    viewport:SetPoint("TOPLEFT", root, "TOPLEFT", 8, -110)
    -- 240 (antes 200, +40 -- ver comentario en root:SetSize): mismo tamaño
    -- de viewport que antes, el espacio extra del root mas alto queda TODO
    -- abajo del viewport para la nueva fila de padding/direccion.
    viewport:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -8, 250)
    viewport:SetClipsChildren(true)
    local viewportBg = viewport:CreateTexture(nil, "BACKGROUND")
    viewportBg:SetAllPoints()
    viewportBg:SetColorTexture(0, 0, 0, 0.22)
    local viewportBorder = CreateFrame("Frame", nil, viewport, "BackdropTemplate")
    viewportBorder:SetAllPoints()
    viewportBorder:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    viewportBorder:SetBackdropBorderColor(1, 0.88, 0.6, 0.35)

    -- `content`: grande (para que arrastrar sobre "vacio" en cualquier zoom
    -- siempre encuentre su area de click) y ARRASTRABLE -- pan libre dentro
    -- del viewport, clippeado por el mismo.
    local content = CreateFrame("Frame", nil, viewport)
    content:SetSize(2000, 2000)
    content:SetPoint("CENTER", viewport, "CENTER", 0, 0)
    content:SetMovable(true)
    content:EnableMouse(true)
    content:RegisterForDrag("LeftButton")
    content:SetScript("OnDragStart", function(self) self:StartMoving() end)
    content:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    -- Pedido del usuario 2026-07-19: click en "vacio" del viewport
    -- deselecciona el elemento actual -- los elementos individuales capturan
    -- el mouse primero (frames hijos mas chicos), asi que esto solo dispara
    -- cuando el click cae afuera de todos ellos.
    content:SetScript("OnMouseDown", function() if DeselectElement then DeselectElement() end end)
    -- Zoom con la RUEDA sobre "vacio" (pedido del usuario) -- los elementos
    -- individuales (hp, nombre, etc) ya usan la rueda para SU tamaño; esto
    -- solo agarra el scroll cuando NO estas sobre ninguno de ellos (los
    -- hijos mas chicos capturan el mouse primero, como siempre en WoW).
    -- Mismo campo ZOOM que el slider de arriba, asi que se mantienen
    -- sincronizados sin importar cual de los dos uses.
    content:EnableMouseWheel(true)
    content:SetScript("OnMouseWheel", function(self, dir)
        ZOOM = clamp(ZOOM + (dir > 0 and 0.1 or -0.1), 1, 3)
        if zoomSlider then
            zoomSlider:SetValue(ZOOM)
            zoomSlider.box:SetText(string.format("%.1f", ZOOM))
        end
        if RecenterContent then RecenterContent() end
        Reflow()
    end)

    RecenterContent = function()
        content:ClearAllPoints()
        content:SetPoint("CENTER", viewport, "CENTER", 0, 0)
    end

    local centerBtn = MakeStyledButton(viewport, "Center", 56, 18)
    centerBtn:SetFrameLevel(viewport:GetFrameLevel() + 20)
    centerBtn:SetPoint("BOTTOMRIGHT", viewport, "BOTTOMRIGHT", -4, 4)
    centerBtn:SetScript("OnClick", RecenterContent)

    -- Anillo verde alrededor de la pieza seleccionada -- hijo del VIEWPORT
    -- (no de root): asi se clippea igual que el resto si el elemento
    -- seleccionado queda paneado cerca del borde.
    local selRing = CreateFrame("Frame", nil, viewport, "BackdropTemplate")
    selRing:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
    selRing:SetBackdropBorderColor(0.3, 1, 0.4, 1)
    -- Por encima de TODOS los elementos: es hermano de `content`, asi que sin
    -- esto quedaba debajo de cualquier cosa colgada del stage (el anillo verde
    -- desaparecia detras de la barra). Tiene que superar el +10 que se le da a
    -- auras/clasificacion mas abajo, en "ORDEN DE DIBUJADO".
    selRing:SetFrameLevel(viewport:GetFrameLevel() + 30)
    selRing:Hide()

    -- "Stage": envuelve vida/valor de vida/cast bar/texto de cast -- su
    -- ESCALA se sincroniza en vivo con la nameplate REAL de tu target (ver
    -- UpdateStageScale mas abajo), pedido del usuario: "que muestre como
    -- esta la barra original para editar mas preciso". Cuelga de `content`
    -- (pannable/clippeado), no de root directo.
    local stage = CreateFrame("Frame", nil, content)
    pieces.root = stage
    stage:SetPoint("CENTER", content, "CENTER", 0, 0)
    stage:SetSize(1, 1)

    -- ---- Crosshair (pedido del usuario): marca el CENTRO real -- el punto
    -- (0,0) del que cuelgan todos los anclajes (hp:SetPoint("CENTER", stage,
    -- "CENTER", 0, 0)). Hijo de `content` (SIN escalar el) porque
    -- `stage:SetPoint` ancla por CENTER, que queda FIJO en pantalla sin
    -- importar la escala mirroreada -- asi el crosshair sigue marcando el
    -- centro real aunque la barra crezca/achique.
    local crossH = content:CreateTexture(nil, "ARTWORK")
    crossH:SetColorTexture(1, 1, 0, 0.35)
    crossH:SetHeight(1)
    crossH:SetPoint("LEFT", stage, "CENTER", -230, 0)
    crossH:SetPoint("RIGHT", stage, "CENTER", 230, 0)
    local crossV = content:CreateTexture(nil, "ARTWORK")
    crossV:SetColorTexture(1, 1, 0, 0.35)
    crossV:SetWidth(1)
    crossV:SetPoint("TOP", stage, "CENTER", 0, 150)
    crossV:SetPoint("BOTTOM", stage, "CENTER", 0, -150)

    -- ---- Barra de vida (mock): SOLO redimensionable, no arrastrable (igual
    -- que la real -- Blizzard siempre la ancla al TOP de la nameplate). ----
    local hp = CreateFrame("StatusBar", nil, stage)
    pieces.health = hp
    hp:SetPoint("CENTER", stage, "CENTER", 0, 0)
    hp:SetStatusBarTexture(BAR_TEX)
    hp:GetStatusBarTexture():SetTexCoord(unpack(BAR_TEXCOORD))
    hp:SetMinMaxValues(0, 100)
    hp:SetValue(71)
    hp:SetStatusBarColor(0.85, 0.15, 0.15)
    local hpBg = hp:CreateTexture(nil, "BACKGROUND", nil, -1)
    hpBg:SetPoint("CENTER")
    hpBg:SetTexture(BACKDROP_TEX)
    hp.bg = hpBg
    pieces.healthBg = hpBg
    TrackHighlight(ns.MakeEditHighlight(hp))
    MakeWheelResize(hp, function(p, dir)
        local w, h = ns.NPLayout.HealthSize(p)
        p.healthWidth  = clamp(w + (dir > 0 and 4 or -4), 40, 200)
        p.healthHeight = clamp(h + (dir > 0 and 1 or -1), 12, 48)
    end, root, "healthBar")
    hp:EnableMouse(true)
    hp:SetScript("OnMouseDown", function() if SelectElement then SelectElement("healthBar") end end)
    selSpecs.healthBar = { title = "Health Bar", handle = hp,
        widthKey = "healthWidth", widthRange = { 40, 200, 1 },
        heightKey = "healthHeight", heightRange = { 12, 48, 1 },
        colorKey = "highlightColor", colorLabel = "Highlight Color" }

    -- ---- Nombre ---- (ZOOM fijo: el nombre real NO escala con la
    -- distancia, asi que aca no sigue al stage -- solo se agranda para
    -- verlo mejor en el panel, pedido del usuario).
    local nameHolder = CreateFrame("Frame", nil, stage)
    pieces.name = nameHolder
    nameHolder:SetSize(ns.NPBuild.NAME_HOLDER_W, ns.NPBuild.NAME_HOLDER_H)
    local nameFS = nameHolder:CreateFontString(nil, "OVERLAY")
    nameFS:SetFont(FONT, 16, "OUTLINE")
    nameFS:SetPoint("CENTER")
    nameFS:SetText("Cheesanator")
    nameHolder.fs = nameFS
    TrackHighlight(ns.MakeEditHighlight(nameHolder))
    MakeDraggable(nameHolder, "nameOffsetX", "nameOffsetY", StageDivisor)
    MakeWheelResize(nameHolder, function(p, dir)
        p.nameFontSize = clamp((p.nameFontSize or 16) + (dir > 0 and 1 or -1), 8, 28)
    end, root, "name")
    -- point="BOTTOM" (NO "TOP"): la real ancla el BOTTOM del holder al TOP
    -- de la plate, asi el texto se extiende hacia ARRIBA con el hueco de 16
    -- unidades -- con "TOP" el texto colgaba hacia ABAJO, casi tocando la
    -- barra (bug reportado por el usuario, confirmado comparando contra
    -- ReassertNameGeometry en Nameplates.lua).
    -- Ancla al STAGE, no a `hp` (2026-07-27): en el nameplate real el nombre
    -- cuelga del NAMEPLATE (`uf`), no de la barra -- ver ns.NPLayout.Name. El
    -- stage es el equivalente del `uf` aca (el (0,0) del que cuelga todo), asi
    -- que anclando ahi la cadena nombre->auras queda igual que en el juego.
    nameHolder:SetScript("OnMouseDown", function() if SelectElement then SelectElement("name") end end)
    selSpecs.name = { title = "Name", handle = nameHolder,
        xKey = "nameOffsetX", yKey = "nameOffsetY", xyRange = { -150, 150, 1 },
        fontKey = "nameFontSize", fontRange = { 8, 28, 1 },
        alphaKey = "nameAlpha", alphaRange = { 0, 1, 0.05 },
        colorKey = "nameColor", colorLabel = "Color" }

    -- ---- Valor de vida (dentro del stage: escala con la barra, igual que
    -- en la nameplate real -- solo el nombre queda fijo). ----
    local hvHolder = CreateFrame("Frame", nil, stage)
    pieces.healthValue = hvHolder
    hvHolder:SetSize(60, 16)
    local hvFS = hvHolder:CreateFontString(nil, "OVERLAY")
    hvFS:SetFont(FONT, 12, "OUTLINE")
    hvFS:SetPoint("CENTER")
    hvFS:SetText("71%")
    hvHolder.fs = hvFS
    TrackHighlight(ns.MakeEditHighlight(hvHolder))
    MakeDraggable(hvHolder, "healthValueOffsetX", "healthValueOffsetY", StageDivisor)
    MakeWheelResize(hvHolder, function(p, dir)
        p.healthValueFontSize = clamp((p.healthValueFontSize or 12) + (dir > 0 and 1 or -1), 8, 28)
    end, root, "healthValue")
    -- base=(0,0): SkinHealthValue en Nameplates.lua usa el offset guardado
    -- DIRECTO, sin sumarle ninguna constante -- sumar -2 aca (bug anterior)
    -- corria el mock -2 unidades de mas respecto de la nameplate real.
    hvHolder:SetScript("OnMouseDown", function() if SelectElement then SelectElement("healthValue") end end)
    selSpecs.healthValue = { title = "Health Value", handle = hvHolder,
        xKey = "healthValueOffsetX", yKey = "healthValueOffsetY", xyRange = { -150, 150, 1 },
        fontKey = "healthValueFontSize", fontRange = { 8, 28, 1 },
        alphaKey = "healthValueAlpha", alphaRange = { 0, 1, 0.05 },
        colorKey = "healthValueColor", colorLabel = "Color" }

    -- ---- Cast bar (mock, siempre visible mientras el designer esta abierto;
    -- dentro del stage, escala junto con la vida). ----
    local cb = CreateFrame("StatusBar", nil, stage)
    pieces.cast = cb
    cb:SetStatusBarTexture(BAR_TEX)
    cb:GetStatusBarTexture():SetTexCoord(unpack(BAR_TEXCOORD))
    cb:SetMinMaxValues(0, 100)
    cb:SetValue(60)
    local cbBg = cb:CreateTexture(nil, "BACKGROUND", nil, -1)
    cbBg:SetPoint("CENTER")
    cbBg:SetTexture(BACKDROP_TEX)
    cb.bg = cbBg
    pieces.castBg = cbBg
    TrackHighlight(ns.MakeEditHighlight(cb))
    MakeDraggable(cb, "castOffsetX", "castOffsetY", StageDivisor)
    MakeWheelResize(cb, function(p, dir)
        local w, h = ns.NPLayout.CastSize(p)
        p.castWidth  = clamp(w + (dir > 0 and 4 or -4), 40, 200)
        p.castHeight = clamp(h + (dir > 0 and 1 or -1), 12, 48)
    end, root, "castBar")
    -- base=(0,0): ReassertCastGeometry en Nameplates.lua usa el offset
    -- guardado DIRECTO tambien (el -7 es solo el valor DEFAULT del campo,
    -- no una constante sumada aparte) -- sumar -7 aca (bug anterior)
    -- duplicaba el desplazamiento hacia abajo.
    cb:SetScript("OnMouseDown", function() if SelectElement then SelectElement("castBar") end end)
    selSpecs.castBar = { title = "Cast Bar", handle = cb,
        xKey = "castOffsetX", yKey = "castOffsetY", xyRange = { -150, 150, 1 },
        widthKey = "castWidth", widthRange = { 40, 200, 1 },
        heightKey = "castHeight", heightRange = { 12, 48, 1 },
        colorKey = "castColor", colorLabel = "Bar Color" }

    -- ---- Texto de cast: SIGUE a la cast bar (anclado a `cb`) pero se puede
    -- mover aparte -- pedido del usuario. Usa castTextOffsetX/Y, el MISMO
    -- campo que ReassertCastGeometry ya lee en Nameplates.lua.
    -- Se superpone visualmente con `cb` (el texto va CENTRADO en la barra) --
    -- sin subir su nivel de frame por encima de `cb`, el click/drag lo
    -- capturaba la barra de abajo en vez del texto (pedido del usuario:
    -- "es dificil seleccionar el texto del cast").
    local ctHolder = CreateFrame("Frame", nil, stage)
    pieces.castText = ctHolder
    ctHolder:SetSize(90, 20)
    ctHolder:SetFrameLevel(cb:GetFrameLevel() + 5)
    local ctFS = ctHolder:CreateFontString(nil, "OVERLAY")
    ctFS:SetFont(FONT, 10, "OUTLINE")
    ctFS:SetPoint("CENTER")
    ctFS:SetText("Arcane Flurry")
    ctHolder.fs = ctFS
    TrackHighlight(ns.MakeEditHighlight(ctHolder))
    MakeDraggable(ctHolder, "castTextOffsetX", "castTextOffsetY", StageDivisor)
    MakeWheelResize(ctHolder, function(p, dir)
        p.castTextFontSize = clamp((p.castTextFontSize or 10) + (dir > 0 and 1 or -1), 6, 20)
    end, root, "castText")
    ctHolder:SetScript("OnMouseDown", function() if SelectElement then SelectElement("castText") end end)
    selSpecs.castText = { title = "Cast Text", handle = ctHolder,
        xKey = "castTextOffsetX", yKey = "castTextOffsetY", xyRange = { -100, 100, 1 },
        fontKey = "castTextFontSize", fontRange = { 6, 20, 1 },
        alphaKey = "castTextAlpha", alphaRange = { 0, 1, 0.05 },
        colorKey = "castTextColor", colorLabel = "Color" }

    -- ---- Auras: 3 grupos INDEPENDIENTES (Big Debuff/Personal Debuffs/Enemy
    -- Buffs), cada uno con su propio offset -- ver AURA_GROUPS/ClassifyAura en
    -- Nameplates.lua.
    --
    -- ANCLAJE (2026-07-28): al `stage`, o sea al nameplate, NO al nombre. Antes
    -- colgaban de nameHolder en los dos lados, y el usuario lo detecto desde el
    -- sintoma: "si escalo o muevo el texto se mueven esas". Era un acoplamiento
    -- que impedia afinar el nombre sin desajustar las auras, y del lado real
    -- traia ademas una cadena de fallback que podia dejarlas colgadas del
    -- FontString de Blizzard para siempre. El motivo completo esta en
    -- L.AuraGroup (NameplateLayout.lua); aca solo hay que reflejarlo.
    --
    -- ESCALA: el holder real lleva contra-escala fija (ver
    -- ReassertAuraGroupGeometry), asi que el mock es hijo de `content` con
    -- escala ZOOM fija -- igual que nameHolder, y NO de `stage` (que mezcla
    -- stageScale*ZOOM, el regimen de la barra). Ser hijo de `content` pero
    -- anclarse a `stage` es a proposito: el padre define la ESCALA, el ancla
    -- define la POSICION, y aca hacen falta distintos. Con esto ambos lados
    -- interpretan el offset guardado en la misma unidad (pixeles de pantalla
    -- reales por el zoom del panel).
    --
    -- combatGuard=true en TODO lo de auras (drag/rueda/checkbox) -- pedido del
    -- usuario 2026-07-19: "que no pueda alterar las auras en combate".
    local bigHolder, bigHL, bigShownCB = MakeAuraGroupMock(stage, "Big Debuff", "auraShowBigDebuff")
    pieces.auras.big = bigHolder
    MakeDraggable(bigHolder, "bigDebuffOffsetX", "bigDebuffOffsetY", StageDivisor, true)

    local personalHolder, personalHL, personalShownCB = MakeAuraGroupMock(stage, "Personal Debuffs", "auraShowPersonalDebuffs")
    pieces.auras.personal = personalHolder
    MakeDraggable(personalHolder, "personalDebuffsOffsetX", "personalDebuffsOffsetY", StageDivisor, true)

    local enemyHolder, enemyHL, enemyShownCB = MakeAuraGroupMock(stage, "Enemy Buffs", "auraShowEnemyBuffs")
    pieces.auras.enemy = enemyHolder
    MakeDraggable(enemyHolder, "enemyBuffsOffsetX", "enemyBuffsOffsetY", StageDivisor, true)

    -- Tamaño de icono COMPARTIDO por las 3 categorias (auraIconSize, igual
    -- que en Nameplates.lua) -- la rueda sobre CUALQUIERA de los 3 grupos
    -- ajusta el mismo campo.
    for holder, auraKey in pairs({ [bigHolder] = "bigDebuff", [personalHolder] = "personalDebuffs", [enemyHolder] = "enemyBuffs" }) do
        MakeWheelResize(holder, function(p, dir)
            p.auraIconSize = clamp(ns.NPLayout.AuraIconSize(p) + (dir > 0 and 2 or -2), 8, 40)
        end, root, auraKey, true)
    end
    bigHolder:SetScript("OnMouseDown", function() if SelectElement then SelectElement("bigDebuff") end end)
    selSpecs.bigDebuff = { title = "Big Debuff", handle = bigHolder,
        xKey = "bigDebuffOffsetX", yKey = "bigDebuffOffsetY", xyRange = { -150, 150, 1 },
        sizeKey = "auraIconSize", sizeRange = { 8, 40, 2 },
        paddingKey = "auraPadding", paddingRange = { 0, 20, 1 }, directionKey = "bigDebuffDirection",
        colorKey = "auraCountColor", colorLabel = "Count/swipe color", hasAuraText = true }
    personalHolder:SetScript("OnMouseDown", function() if SelectElement then SelectElement("personalDebuffs") end end)
    selSpecs.personalDebuffs = { title = "Personal Debuffs", handle = personalHolder,
        xKey = "personalDebuffsOffsetX", yKey = "personalDebuffsOffsetY", xyRange = { -150, 150, 1 },
        sizeKey = "auraIconSize", sizeRange = { 8, 40, 2 },
        paddingKey = "auraPadding", paddingRange = { 0, 20, 1 }, directionKey = "personalDebuffsDirection",
        colorKey = "auraCountColor", colorLabel = "Count/swipe color", hasAuraText = true }
    enemyHolder:SetScript("OnMouseDown", function() if SelectElement then SelectElement("enemyBuffs") end end)
    selSpecs.enemyBuffs = { title = "Enemy Buffs", handle = enemyHolder,
        xKey = "enemyBuffsOffsetX", yKey = "enemyBuffsOffsetY", xyRange = { -150, 150, 1 },
        sizeKey = "auraIconSize", sizeRange = { 8, 40, 2 },
        paddingKey = "auraPadding", paddingRange = { 0, 20, 1 }, directionKey = "enemyBuffsDirection",
        colorKey = "auraCountColor", colorLabel = "Count/swipe color", hasAuraText = true }

    -- ---- Icono de clasificacion (elite/rare/boss, texturas de AzeriteUI --
    -- ver CLASS_TEX en Nameplates.lua) -- anclado a la DERECHA de la barra,
    -- offset (20,-1) por defecto, calcado de AzeriteUI. Dentro de `stage`:
    -- es un hijo normal de la barra de vida, escala con la distancia.
    local classHolder = MakeBadgeMock(stage, 40, A .. "icon_classification_elite.tga")
    pieces.classification = classHolder
    MakeDraggable(classHolder, "classificationOffsetX", "classificationOffsetY", StageDivisor)
    MakeWheelResize(classHolder, function(p, dir)
        p.classificationSize = clamp((p.classificationSize or 40) + (dir > 0 and 2 or -2), 12, 64)
    end, root, "classification")
    classHolder:SetScript("OnMouseDown", function() if SelectElement then SelectElement("classification") end end)
    selSpecs.classification = { title = "Elite/Rare/Boss icon", handle = classHolder,
        xKey = "classificationOffsetX", yKey = "classificationOffsetY", xyRange = { -100, 100, 1 },
        sizeKey = "classificationSize", sizeRange = { 12, 64, 2 } }

    -- ---- Marca de raid (native, ver LockRaidMark en Nameplates.lua) --
    -- centrada en la barra por defecto.
    local raidHolder = MakeBadgeMock(stage, 32, "Interface\\TargetingFrame\\UI-RaidTargetingIcons", 8)
    pieces.raidMark = raidHolder
    MakeDraggable(raidHolder, "raidMarkOffsetX", "raidMarkOffsetY", StageDivisor)
    MakeWheelResize(raidHolder, function(p, dir)
        p.raidMarkSize = clamp((p.raidMarkSize or 64) + (dir > 0 and 4 or -4), 16, 96)
    end, root, "raidMark")
    raidHolder:SetScript("OnMouseDown", function() if SelectElement then SelectElement("raidMark") end end)
    selSpecs.raidMark = { title = "Raid Mark", handle = raidHolder,
        xKey = "raidMarkOffsetX", yKey = "raidMarkOffsetY", xyRange = { -100, 100, 1 },
        sizeKey = "raidMarkSize", sizeRange = { 16, 96, 4 } }

    -- ---- ORDEN DE DIBUJADO (2026-07-28) -------------------------------
    -- Reportado por el usuario con dos capturas: en el panel el NOMBRE salia
    -- detras de la barra y las AURAS por debajo, mientras que en el nameplate
    -- real los dos van encima. No era posicion -- era profundidad, y de ahi que
    -- moverlos nunca lo arreglara.
    --
    -- La causa es estructural: `stage` es hijo de `content`, y de `stage`
    -- cuelgan barra/valor/cast/clasificacion/marca. Pero el nombre y los 3
    -- grupos de auras cuelgan de `content` DIRECTAMENTE (tienen que hacerlo:
    -- van a escala de pantalla, no a la del stage). Como en WoW un hijo se
    -- dibuja sobre su padre, todo lo de `stage` quedaba una capa POR ENCIMA de
    -- ellos. Justo los cuatro elementos que fallaban, y solo esos.
    --
    -- Se reproduce el orden del nameplate real, que es (de abajo hacia arriba):
    --   barra de vida -> nombre -> clasificacion / marca de raid / auras
    -- En el real las tres ultimas van a strata TOOLTIP nivel 200 (ver
    -- CreateCustomClassification y ns.NPBuild.AuraIcon). Aca se hace con NIVELES
    -- dentro de la misma strata a proposito: subirlas a TOOLTIP las pondria por
    -- encima de los controles del propio panel.
    local zBase = stage:GetFrameLevel()
    nameHolder:SetFrameLevel(zBase + 5)
    for _, h in ipairs({ classHolder, raidHolder, bigHolder, personalHolder, enemyHolder }) do
        h:SetFrameLevel(zBase + 10)
    end

    -- Deselecciona todo (pedido del usuario: click en "vacio" del viewport) --
    -- oculta el anillo verde y los sliders/color de la fila de control, y
    -- limpia selectedKey (asi MakeWheelResize vuelve a bloquear el scroll de
    -- TODOS los elementos hasta que se seleccione uno de nuevo).
    DeselectElement = function()
        if not selectedKey then return end
        selectedKey = nil
        root.selectedKey = nil
        selRing:Hide()
        ctrlTitle:SetText("(none selected)")
        elementDropdown.text:SetText("Select element...")
        sliderX:Hide(); sliderY:Hide(); sliderW:Hide(); sliderH:Hide(); colorBtn:Hide()
        paddingSlider:Hide(); directionBtn:Hide(); textModeBtn:Hide()
    end

    -- Selecciona el elemento `key` de selSpecs: mueve el anillo verde encima,
    -- y (re)liga sliderW/sliderH/colorBtn a sus campos del perfil segun el
    -- spec (width+height O font size O icon size; color si aplica).
    SelectElement = function(key)
        local spec = selSpecs[key]
        if not spec then return end
        selectedKey = key
        root.selectedKey = key
        ctrlTitle:SetText(spec.title)
        elementDropdown.text:SetText(spec.title)
        selRing:ClearAllPoints()
        selRing:SetPoint("TOPLEFT", spec.handle, "TOPLEFT", -3, 3)
        selRing:SetPoint("BOTTOMRIGHT", spec.handle, "BOTTOMRIGHT", 3, -3)
        selRing:SetFrameLevel((spec.handle:GetFrameLevel() or 0) + 10)
        selRing:Show()

        sliderX:Hide(); sliderY:Hide(); sliderW:Hide(); sliderH:Hide(); colorBtn:Hide()
        paddingSlider:Hide(); directionBtn:Hide(); textModeBtn:Hide()
        local p = P()
        if not p then return end

        -- Fila 1: X/Y -- mismos campos que mueve el drag, para ajuste fino
        -- con numeros (pedido del usuario). No todas las piezas tienen
        -- offset propio en la nameplate real (la barra de vida no).
        if spec.xKey then
            BindSlider(sliderX, "Offset X", spec.xyRange[1], spec.xyRange[2], spec.xyRange[3],
                function() return p[spec.xKey] end, function(v) p[spec.xKey] = v end)
        end
        if spec.yKey then
            BindSlider(sliderY, "Offset Y", spec.xyRange[1], spec.xyRange[2], spec.xyRange[3],
                function() return p[spec.yKey] end, function(v) p[spec.yKey] = v end)
        end

        if spec.hasAuraText then textModeBtn:Show() end
        if spec.hasAuraText and textMode ~= "icon" then
            -- Modo texto (cargas o tiempo restante): sliderW/H pasan a ser
            -- offset X/Y del texto, y paddingSlider pasa a ser tamaño de
            -- fuente -- reusa los mismos 4 widgets que en modo icono, no hay
            -- espacio libre en la franja para sumar mas sliders.
            local isCount = (textMode == "count")
            local fsKey = isCount and "auraCountFontSize" or "auraTimeFontSize"
            local clrKey = isCount and "auraCountColor" or "auraTimeColor"
            if isCount then
                -- Cargas: SI tiene offset propio (es un FontString nuestro).
                BindSlider(sliderW, "Offset X", -50, 50, 1,
                    function() return p.auraCountOffsetX end, function(v) p.auraCountOffsetX = v end)
                BindSlider(sliderH, "Offset Y", -50, 50, 1,
                    function() return p.auraCountOffsetY end, function(v) p.auraCountOffsetY = v end)
            else
                -- Tiempo: NO tiene offset propio -- lo dibuja el widget
                -- Cooldown nativo de Blizzard, siempre centrado en el icono.
                sliderW:Hide(); sliderH:Hide()
            end
            paddingSlider:Show()
            BindSlider(paddingSlider, "Font Size", 6, 24, 1,
                function() return p[fsKey] end, function(v) p[fsKey] = v end)
            directionBtn:Hide(); directionBtn._dirKey = nil
            if p[clrKey] then BindColorButton(colorBtn, isCount and "Count Color" or "Time Color", p[clrKey]) end
            textModeBtn:SetLabel(TEXT_MODE_LABEL[textMode])
            return
        end
        if spec.hasAuraText then textModeBtn:SetLabel(TEXT_MODE_LABEL[textMode]) end

        -- Fila 2, slot izquierdo: width O font size O icon size (segun tipo).
        if spec.widthKey then
            BindSlider(sliderW, "Width", spec.widthRange[1], spec.widthRange[2], spec.widthRange[3],
                function() return p[spec.widthKey] end, function(v) p[spec.widthKey] = v end)
        elseif spec.fontKey then
            BindSlider(sliderW, "Font size", spec.fontRange[1], spec.fontRange[2], spec.fontRange[3],
                function() return p[spec.fontKey] end, function(v) p[spec.fontKey] = v end)
        elseif spec.sizeKey then
            BindSlider(sliderW, "Icon size (shared)", spec.sizeRange[1], spec.sizeRange[2], spec.sizeRange[3],
                function() return p[spec.sizeKey] end, function(v) p[spec.sizeKey] = v end)
        end
        -- Fila 2, slot derecho: height (barras) O opacidad (texto, pedido
        -- del usuario) -- las barras no tienen alpha configurable, y el
        -- texto no tiene height, asi que comparten el mismo slot sin pisarse.
        if spec.heightKey then
            BindSlider(sliderH, "Height", spec.heightRange[1], spec.heightRange[2], spec.heightRange[3],
                function() return p[spec.heightKey] end, function(v) p[spec.heightKey] = v end)
        elseif spec.alphaKey then
            BindSlider(sliderH, "Opacity", spec.alphaRange[1], spec.alphaRange[2], spec.alphaRange[3],
                function() return p[spec.alphaKey] end, function(v) p[spec.alphaKey] = v end)
        end
        if spec.colorKey and p[spec.colorKey] then
            BindColorButton(colorBtn, spec.colorLabel or "Color", p[spec.colorKey])
        end

        -- Fila 3 (SOLO grupos de auras): padding + direccion.
        if spec.paddingKey then
            paddingSlider:Show()
            BindSlider(paddingSlider, "Padding", spec.paddingRange[1], spec.paddingRange[2], spec.paddingRange[3],
                function() return p[spec.paddingKey] end, function(v) p[spec.paddingKey] = v end)
        else
            paddingSlider:Hide()
        end
        if spec.directionKey then
            directionBtn:Show()
            directionBtn._dirKey = spec.directionKey
            local cur = p[spec.directionKey] or "right"
            directionBtn:SetLabel("Direction: " .. cur:sub(1, 1):upper() .. cur:sub(2))
        else
            directionBtn:Hide()
            directionBtn._dirKey = nil
        end
    end

    textModeBtn:SetScript("OnClick", function(self)
        local idx = 1
        for i, v in ipairs(TEXT_MODES) do if v == textMode then idx = i break end end
        textMode = TEXT_MODES[(idx % #TEXT_MODES) + 1]
        if selectedKey then SelectElement(selectedKey) end
    end)

    root.stage, root.scaleLabel = stage, scaleLabel
    root.refSlider = refSlider   -- lo sincroniza ToggleNameplateDesigner al abrir
    root.hp, root.nameHolder, root.hvHolder, root.cb, root.ctHolder = hp, nameHolder, hvHolder, cb, ctHolder
    root.bigHolder, root.personalHolder, root.enemyHolder = bigHolder, personalHolder, enemyHolder
    root.bigShownCB, root.personalShownCB, root.enemyShownCB = bigShownCB, personalShownCB, enemyShownCB
    root.classHolder, root.raidHolder = classHolder, raidHolder
    root.SelectElement = SelectElement
    -- Seleccion inicial: la barra de vida, asi el panel de control no arranca vacio.
    SelectElement("healthBar")
    -- BUG (reportado por el usuario, 2026-07-18): un frame recien creado
    -- esta VISIBLE por defecto -- como el panel ahora se pre-construye al
    -- login (ver mas abajo), sin este Hide() se abria solo con cada /reload
    -- en vez de quedarse oculto hasta el primer /mcfnpdesigner.
    root:Hide()
    return root
end

-- QUITADO el espejado de escala del target (2026-07-27, pedido del usuario:
-- "no me gusta que cambie de escala el panel si tengo o no seleccionado un
-- target... hace que los cambios no los entienda bien").
--
-- Habia un ticker que cada 0.2s leia la escala EFECTIVA del nameplate del
-- target y se la aplicaba al stage, para que el lienzo mostrara el tamaño real
-- a esa distancia. En la practica hacia lo contrario de lo que un editor
-- necesita: el lienzo se re-escalaba solo mientras trabajabas -- al elegir
-- target, al perderlo, o simplemente al caminar (la escala del nameplate
-- depende de la distancia) -- asi que el MISMO ajuste se veia distinto de un
-- segundo a otro y era imposible juzgar un cambio.
--
-- Ahora `stageScale` queda FIJO en 1: el lienzo siempre muestra la escala por
-- defecto, y lo unico que cambia el tamaño es el slider "Panel zoom", que es
-- explicito y lo maneja el usuario. Con esto tambien se va el ticker entero y
-- el motivo de `anyDragActive` (existia solo para congelar esa escala a mitad
-- de un arrastre y que el frame no "tironeara" respecto del cursor) -- sin
-- escala cambiante, no hay nada que congelar.
--
-- Si algun dia se quiere un boton "previsualizar a la distancia del target"
-- (puntual y a pedido, NO automatico -- esa fue justamente la molestia), el
-- dato clave que costo encontrar la primera vez: hay que leer
-- `uf:GetEffectiveScale()`, NO `GetScale()`. La geometria real
-- (ReassertNameGeometry en Nameplates.lua) usa la escala ACUMULADA -- propia
-- por la de todos los padres -- mientras que GetScale() devuelve solo la
-- propia de la plate, sin UIParent/WorldFrame. Con uiScale != 1 el stage
-- quedaba desincronizado, y eso explicaba el mismatch reportado el 2026-07-19
-- ("en el panel esta mas junto, en la realidad esta mas lejos").

-- ==========================================================================
-- Reflow: reaplica tamaño/posicion de TODO segun el perfil actual -- se
-- llama al abrir el designer y despues de cada cambio (drag/wheel), asi el
-- mock queda siempre sincronizado con lo que se ve en la nameplate real Y
-- cada pieza queda RE-ANCLADA a su anchor de verdad (fix del bug de
-- "elementos que se quedan atras al mover la ventana", ver MakeDraggable).
-- ==========================================================================
Reflow = function()
    if not designer or not designer:IsShown() then PushLive(); return end
    local p = P(); if not p then return end

    -- Zoom del panel (pedido del usuario, slider propio -- ver zoomSlider):
    -- aplicar aca tambien, no solo en el ticker de escala, para que cambiar
    -- el zoom se sienta INSTANTANEO en vez de esperar hasta 0.2s.
    -- Solo se escala el PLATE. Las escalas de las piezas las pone LayoutPlate,
    -- que le aplica 1/scale a las del regimen "screen" -- exactamente la misma
    -- contra-escala que lleva el nameplate real. Antes se les fijaba ZOOM a mano
    -- aca, que era una tercera idea de las escalas conviviendo con las otras dos.
    designer.stage:SetScale(stageScale * ZOOM)

    -- COLOCACION: una sola llamada, la MISMA funcion que posiciona los
    -- nameplates de verdad (ns.NPBuild.LayoutPlate). Tamaños incluidos. El
    -- editor no vuelve a tener ni una linea de posicionamiento propia -- que era
    -- de donde salia una diferencia nueva cada vez que se arreglaba la anterior.
    --
    -- `stageScale` entra como la escala del plate, igual que GetEffectiveScale
    -- del nameplate real. Como los offsets del regimen "screen" se multiplican
    -- por ella y las piezas se dividen por ella, se cancela en las proporciones:
    -- el panel muestra lo mismo aunque la referencia este mal muestreada.
    ns.NPBuild.LayoutPlate(pieces, p, stageScale)

    -- TAMAÑO DE LOS HOLDERS DE TEXTO -- tiene que copiar la ESTRUCTURA del real,
    -- no ajustarse al texto (2026-07-28, bug reportado con capturas: el nombre
    -- no caia donde el panel lo mostraba, y empeoraba cuanto mas grande la
    -- fuente). Antes los tres holders se redimensionaban al texto
    -- (GetStringWidth/Height + padding) para que el aro de seleccion quedara
    -- ajustado. Eso es incompatible con como esta armado el nameplate real:
    --
    --   * NOMBRE  -> el real usa un holder de tamaño FIJO 220x20 con el texto
    --     en CENTER, y ancla ese holder por BOTTOM. Con el ancla en BOTTOM, el
    --     texto queda a altura/2 por encima del punto de anclaje: SIEMPRE +10
    --     en el real, pero altura_del_texto/2 en el panel -- o sea que la
    --     diferencia CRECIA con el tamaño de fuente. Por eso ningun arrastre lo
    --     corregia: cada Reflow volvia a redimensionar el holder.
    --   * VALOR DE VIDA -> el real no tiene holder: ancla el FontString por TOP
    --     directamente. Para que anclar el holder equivalga a anclar el texto,
    --     los bordes del holder tienen que ser EXACTAMENTE los del texto (el
    --     padding de +4 lo bajaba 2px).
    --   * TEXTO DE CAST -> tambien FontString directo, pero anclado por CENTER,
    --     y un padding simetrico no mueve un CENTER. Se deja exacto igual, para
    --     que nadie reintroduzca el bug si algun dia pasa a anclarse por TOP.
    designer.nameHolder.fs:SetFont(FONT, p.nameFontSize or 16, "OUTLINE")
    local nc = p.nameColor
    if nc then designer.nameHolder.fs:SetTextColor(nc.r, nc.g, nc.b, p.nameAlpha or 1) end
    designer.nameHolder:SetSize(ns.NPBuild.NAME_HOLDER_W, ns.NPBuild.NAME_HOLDER_H)

    designer.hvHolder.fs:SetFont(FONT, p.healthValueFontSize or 12, "OUTLINE")
    local hvc = p.healthValueColor
    if hvc then designer.hvHolder.fs:SetTextColor(hvc.r, hvc.g, hvc.b, p.healthValueAlpha or 1) end
    designer.hvHolder:SetSize(math.max(1, designer.hvHolder.fs:GetStringWidth()),
        math.max(1, designer.hvHolder.fs:GetStringHeight()))


    designer.ctHolder.fs:SetFont(FONT, p.castTextFontSize or 10, "OUTLINE")
    local ctc = p.castTextColor
    if ctc then designer.ctHolder.fs:SetTextColor(ctc.r, ctc.g, ctc.b, p.castTextAlpha or 1) end
    designer.ctHolder:SetSize(math.max(1, designer.ctHolder.fs:GetStringWidth()),
        math.max(1, designer.ctHolder.fs:GetStringHeight()))

    -- Mismo LayoutAuraGroup que corre sobre los nameplates reales -- ya no hay
    -- una copia local de la formula ni un `or 26`/`or 4` que pueda quedar
    -- desfasado de los defaults (los toma ns.NPLayout).
    ns.NPBuild.LayoutAuraGroup(designer.bigHolder, p)
    ns.NPBuild.LayoutAuraGroup(designer.personalHolder, p)
    ns.NPBuild.LayoutAuraGroup(designer.enemyHolder, p)

    -- Pedido del usuario 2026-07-19: "el panel de auras no previsualiza mis
    -- cambios de carga/tiempo restante" -- reaplica offset/tamaño/color de
    -- AMBOS textos en los 3 grupos, en vivo, mismos campos que usa el real
    -- (ver ReassertAuraTextStyle en Nameplates.lua). El tiempo NO tiene
    -- offset propio (native, siempre CENTER) -- mismo criterio ya aplicado
    -- alla, solo tamaño/color aca.
    do
        local ccx, ccy = p.auraCountOffsetX or 2, p.auraCountOffsetY or 2
        local cSize = p.auraCountFontSize or 11
        local cc = p.auraCountColor or { r = 1, g = 1, b = 1 }
        local tSize = p.auraTimeFontSize or 10
        local tc = p.auraTimeColor or { r = 1, g = 1, b = 1 }
        for _, holder in ipairs({ designer.bigHolder, designer.personalHolder, designer.enemyHolder }) do
            for _, b in ipairs(holder.icons) do
                if b.count then
                    b.count:SetFont(FONT, cSize, "OUTLINE")
                    b.count:ClearAllPoints()
                    b.count:SetPoint("TOPRIGHT", ccx, ccy)
                    b.count:SetTextColor(cc.r, cc.g, cc.b, 1)
                end
                if b.time then
                    b.time:SetFont(FONT, tSize, "OUTLINE")
                    b.time:SetTextColor(tc.r, tc.g, tc.b, 1)
                end
            end
        end
    end

    local showBig = p.auraShowBigDebuff ~= false
    local showPersonal = p.auraShowPersonalDebuffs ~= false
    local showEnemy = p.auraShowEnemyBuffs ~= false
    designer.bigShownCB:SetChecked(showBig)
    designer.personalShownCB:SetChecked(showPersonal)
    designer.enemyShownCB:SetChecked(showEnemy)
    designer.bigHolder:SetAlpha(showBig and 1 or 0.3)
    designer.personalHolder:SetAlpha(showPersonal and 1 or 0.3)
    designer.enemyHolder:SetAlpha(showEnemy and 1 or 0.3)

    local csz = p.classificationSize or 40
    designer.classHolder:SetSize(csz, csz)
    local rsz = p.raidMarkSize or 64
    designer.raidHolder:SetSize(rsz, rsz)

    -- Refresca el panel de control de abajo por si el valor cambio desde
    -- afuera (ej. boton Reset) mientras un elemento seguia seleccionado.
    if designer.selectedKey and designer.SelectElement then
        designer.SelectElement(designer.selectedKey)
    end

    PushLive()
end

-- ==========================================================================
-- Toggle publico (menu/slash command).
-- ==========================================================================
ns.ToggleNameplateDesigner = function()
    if not designer then designer = CreateDesigner() end
    if designer:IsShown() then
        designer:Hide()
        for _, hl in ipairs(highlights) do hl:Hide() end
    else
        -- Escala de REFERENCIA al abrir (2026-07-27, ver la nota de stageScale).
        -- Se resuelve UNA vez aca y no se vuelve a tocar sola mientras el panel
        -- este abierto -- ese "cambiar solo" era justamente la molestia del
        -- ticker viejo. Orden: valor guardado -> muestreo de un nameplate real
        -- (y se guarda, asi la proxima vez ya arranca bien) -> 1 como ultimo
        -- recurso si no hay ninguno en pantalla.
        local ref = GetRefScale()
        if not ref then
            ref = SampleNameplateScale()
            if ref then SetRefScale(clamp(ref, 0.3, 2)) end
        end
        stageScale = clamp(ref or 1, 0.3, 2)

        -- Reintento ACOTADO si todavia no hay una referencia real (2026-07-27).
        -- Confirmado con /mcfnplayoutdiag: `designerRefScale` quedaba en nil y el
        -- panel dibujaba a escala 1 con nameplates reales a 0.768 -- un 30% de
        -- error, que es exactamente el desajuste reportado. La causa es de
        -- TIMING: lo normal es abrir el Designer y DESPUES apuntar a algo, y en
        -- ese instante no habia ningun nameplate del cual muestrear.
        -- Esto NO es el ticker viejo que se saco por hacer saltar el lienzo: solo
        -- corre mientras no tengamos un valor real, se detiene apenas consigue
        -- uno (o a los 20s), y nunca vuelve a tocar la escala despues. O sea,
        -- asienta una vez al principio en vez de re-escalar mientras editas.
        if not GetRefScale() then
            local tries = 0
            C_Timer.NewTicker(0.5, function(self)
                tries = tries + 1
                if not (designer and designer:IsShown()) or tries > 40 then self:Cancel(); return end
                local s = SampleNameplateScale()
                if not s then return end
                self:Cancel()
                -- Via el slider, igual que el boton Sample: su OnValueChanged ya
                -- persiste, actualiza el cartel, re-escala el stage y hace
                -- Reflow -- una sola implementacion en vez de repetirla aca.
                if designer.refSlider then designer.refSlider:SetValue(clamp(s, 0.3, 2)) end
            end)
        end
        if designer.scaleLabel then
            designer.scaleLabel:SetText(("Reference scale %.2f"):format(stageScale))
        end
        if designer.stage then designer.stage:SetScale(stageScale * ZOOM) end
        if designer.refSlider then designer.refSlider:SetValue(stageScale) end

        designer:Show()
        for _, hl in ipairs(highlights) do hl:SetShown(outlinesVisible) end
        Reflow()
    end
end

-- Pre-construye el panel (oculto) al login en vez de la primera vez que se
-- llama /mcfnpdesigner -- pedido del usuario ("se demora un poco en abrir"):
-- CreateDesigner crea bastantes frames/texturas/fontstrings de una, y hacerlo
-- recien en el primer toggle causaba un hitch perceptible esa vez. Corriendo
-- el costo 1 vez al login (con un pequeño delay, mismo patron que
-- PartyAuraPreview.lua) deja el primer /mcfnpdesigner tan instantaneo como
-- los siguientes.
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        C_Timer.After(2, function()
            if not designer then designer = CreateDesigner() end
        end)
    end)
end

SLASH_MCFNPDESIGNER1 = "/mcfnpdesigner"
SlashCmdList["MCFNPDESIGNER"] = function() ns.ToggleNameplateDesigner() end

-- ==========================================================================
-- DIAGNOSTICO /mcfnplayoutdiag (2026-07-27)
--
-- Por que existe: el panel seguia sin coincidir con el juego despues de varios
-- arreglos razonados LEYENDO el codigo. La matematica cerraba en papel y en
-- pantalla no, asi que hacian falta NUMEROS REALES en vez de otra hipotesis.
--
-- La primera version intentaba comparar POSICIONES (cada elemento respecto de
-- la barra de vida, normalizado). No se puede: medido en vivo sobre un
-- nameplate real, GetRect / GetLeft / GetBottom / GetCenter estan TODOS
-- bloqueados ("Can't measure restricted regions"). Lo unico que responde es
-- GetWidth, GetHeight y GetEffectiveScale. O sea que verificar el 1:1
-- comparando posicion contra posicion es imposible en este cliente, y los
-- helpers que lo intentaban se borraron en vez de dejarlos ahi sugiriendo que
-- el dato existe.
--
-- Pero tampoco hace falta. Desde que la geometria vive en ns.NPLayout, los dos
-- lados aplican EXACTAMENTE los mismos offsets: ya no pueden divergir por
-- posicion. Lo unico que queda capaz de desalinear el resultado es que el panel
-- dibuje a una ESCALA distinta de la real -- y eso si es medible. Fue
-- justamente el problema: designerRefScale estaba en nil, el panel corria a 1.0
-- y los nameplates reales a 0.768 (30% de error).
-- ==========================================================================
SLASH_MCFNPLAYOUTDIAG1 = "/mcfnplayoutdiag"
SlashCmdList["MCFNPLAYOUTDIAG"] = function()
    local plate = UnitExists("target") and C_NamePlate and C_NamePlate.GetNamePlateForUnit
        and C_NamePlate.GetNamePlateForUnit("target")
    local uf = plate and (plate.UnitFrame or plate)
    if not uf or not uf.healthBar then
        print("|cffff5555[MCF]|r Necesito un target con nameplate visible.")
        return
    end

    -- LIMITACION CONFIRMADA EN VIVO (2026-07-27): en un nameplate real,
    -- GetRect/GetLeft/GetBottom/GetCenter estan BLOQUEADOS ("Can't measure
    -- restricted regions"). Solo GetWidth/GetHeight/GetEffectiveScale
    -- responden. O sea: la POSICION real no se puede leer desde Lua, y por lo
    -- tanto no se puede comparar posicion contra posicion.
    -- Pero no hace falta: con el layout ya compartido (ns.NPLayout) los dos
    -- lados aplican los mismos offsets, asi que lo unico que puede desalinear
    -- el resultado es que el panel use una ESCALA distinta a la real. Eso si se
    -- puede medir, y es lo que compara este comando.
    local okS, effScale = pcall(uf.GetEffectiveScale, uf)
    local okW, realW = pcall(uf.healthBar.GetWidth, uf.healthBar)
    local okH, realH = pcall(uf.healthBar.GetHeight, uf.healthBar)
    local p = P()

    print("|cffffe19b[MCF layout]|r nameplate real vs panel:")
    print(("  escala real del nameplate : %s"):format(okS and string.format("%.3f", effScale) or "ilegible"))
    -- Se imprime el valor CRUDO guardado, no un si/no. La primera version decia
    -- "sin guardar" mientras stageScale ya valia 0.770 -- y 0.770 solo puede
    -- salir del setter del slider, que persiste en la misma linea. Esa
    -- contradiccion fue justamente la pista: el setter SI escribia, pero la
    -- tabla donde escribia (db.nameplates) se reemplaza entera al cargar un
    -- perfil o resetear. Un booleano lo habria seguido tapando.
    print(("  escala de referencia panel: %.3f   (guardado: %s)"):format(
        stageScale, tostring(GetRefScale())))
    if okS and effScale then
        local err = math.abs(stageScale - effScale) / effScale
        if err < 0.02 then
            print("  |cff00ff00coinciden|r -- las proporciones del panel son las del juego.")
        else
            print(("  |cffff5555DIFIEREN en %.0f%%|r -- el panel dibuja la barra %s de lo que deberia"):format(
                err * 100, stageScale > effScale and "MAS GRANDE" or "MAS CHICA"))
            print("  Arreglo: apreta |cffffff00Sample|r en el Designer (o move Reference scale a "
                .. string.format("%.2f", effScale) .. ").")
        end
    end
    print(("  barra de vida  real=%sx%s  perfil=%sx%s"):format(
        okW and string.format("%.0f", realW) or "?", okH and string.format("%.0f", realH) or "?",
        tostring(p and p.healthWidth), tostring(p and p.healthHeight)))
    print("  (posicion real no medible: GetRect/GetLeft/GetCenter estan bloqueados en nameplates)")
end

-- ==========================================================================
-- DIAGNOSTICO /mcfnpanchordiag (2026-07-28)
--
-- La primera version intentaba MEDIR la distancia entre el tope de `uf` y el
-- tope de la barra anclando dos sondas propias. No sirve: anclar a un frame
-- restringido restringe tambien la posicion de la sonda, asi que tampoco se
-- pueden medir. (Y la pregunta quedo respondida por codigo: LockBar ancla la
-- barra real a uf TOP/TOP con y=-1, o sea que el panel modela bien el origen.)
--
-- Esta version NO MIDE NADA: CALCULA lo que cada lado dibuja, a partir de
-- numeros que si se pueden obtener (offsets del perfil, altura configurada,
-- GetEffectiveScale, stageScale, ZOOM). Compara la unica cosa que tiene que
-- coincidir para que el panel prediga el juego: la separacion nombre-barra
-- EXPRESADA EN ALTURAS DE BARRA. Esa razon no depende del zoom ni de la
-- distancia, asi que si los dos lados no dan el mismo numero, ahi esta el bug
-- -- y el desglose muestra en cual de los factores se separa.
-- ==========================================================================
SLASH_MCFNPANCHORDIAG1 = "/mcfnpanchordiag"
SlashCmdList["MCFNPANCHORDIAG"] = function()
    local plate = UnitExists("target") and C_NamePlate and C_NamePlate.GetNamePlateForUnit
        and C_NamePlate.GetNamePlateForUnit("target")
    local uf = plate and (plate.UnitFrame or plate)
    if not uf then
        print("|cffff5555[MCF]|r Necesito un target con nameplate visible.")
        return
    end
    local p = P()
    if not p then print("|cffff5555[MCF]|r Sin perfil."); return end
    local okS, eff = pcall(uf.GetEffectiveScale, uf)
    if not (okS and type(eff) == "number" and eff > 0) then
        print("|cffff5555[MCF]|r No pude leer la escala del nameplate.")
        return
    end

    local nl = ns.NPLayout.Name(p)
    local hl = ns.NPLayout.Health(p)
    local _, barH = ns.NPLayout.HealthSize(p)

    -- REAL: el holder del nombre lleva contra-escala, o sea escala efectiva 1
    -- -- sus offsets son pixeles de pantalla tal cual. La barra va a `eff`.
    local realGap  = nl.y * 1.0 + math.abs(hl.y) * eff
    local realBar  = barH * eff
    -- PANEL: el nombre va a escala ZOOM, la barra a stageScale*ZOOM.
    local panelGap = nl.y * ZOOM + math.abs(hl.y) * stageScale * ZOOM
    local panelBar = barH * stageScale * ZOOM

    print("|cffffe19b[MCF anchor]|r separacion nombre-barra, en ALTURAS DE BARRA:")
    print(("  perfil: nameOffsetY=%s  ->  L.Name.y=%s   |   healthHeight=%s  L.Health.y=%s"):format(
        tostring(p.nameOffsetY), tostring(nl.y), tostring(barH), tostring(hl.y)))
    print(("  escalas: nameplate real=%.3f   panel stage=%.3f  zoom=%.2f"):format(eff, stageScale, ZOOM))
    print(("  REAL  : hueco %.1f px / barra %.1f px = |cff00ff00%.3f|r"):format(
        realGap, realBar, realGap / realBar))
    print(("  PANEL : hueco %.1f px / barra %.1f px = |cff00ff00%.3f|r"):format(
        panelGap, panelBar, panelGap / panelBar))
    local d = math.abs(realGap / realBar - panelGap / panelBar)
    if d < 0.02 then
        print("  |cff00ff00Coinciden.|r El modelo geometrico NO es la causa -- el problema")
        print("  esta en el dibujado (tamaño de fuente, punto del texto o capa), no en la")
        print("  posicion. Decimelo y busco por ese lado.")
    else
        print(("  |cffff5555DIFIEREN por %.3f alturas de barra|r -- aca esta el bug."):format(d))
        print(("  El nombre del panel esta %s que en el juego."):format(
            (panelGap / panelBar > realGap / realBar) and "MAS LEJOS de la barra" or "MAS CERCA de la barra"))
    end
end
