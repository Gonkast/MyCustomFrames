-- ==========================================================================
-- MyCustomFrames - MinimapButtons.lua
-- Pedido del usuario 2026-07-24: "un sistema de mouse-over para los botones
-- de addons del minimapa, como el de las auras de party/arena -- la idea es
-- no necesitar HidingBar mas". Analizado HidingBar antes de escribir esto
-- (E:\...\AddOns\HidingBar\HidingBar.lua) -- dos tecnicas de deteccion:
--   1. LibDBIcon-1.0: la libreria que usa casi todo addon con icono de
--      minimapa (WeakAuras, DBM, BigWigs, etc). Callback "LibDBIcon_IconCreated"
--      + `lib:GetButtonList()`/`GetMinimapButton(name)` para los ya existentes.
--   2. Escaneo generico de los hijos de Minimap (fallback para los pocos
--      addons que no usan LibDBIcon): frames cuadrados-ish, chicos, con algun
--      handler de click, no protegidos.
-- A diferencia de HidingBar, que le PISA Show/Hide/SetScript a cada boton
-- (proxy completo) para pelear la reubicacion, este archivo NO toca los
-- scripts del boton -- solo reparenta + reposiciona, y un ticker reasegura
-- el parent/posicion periodicamente (mismo patron que MM_ReassertArt en
-- MicroMenu.lua: "otro addon me pisa el arte cada tanto, reaplico seguido").
-- Confirmado leyendo LibDBIcon-1.0 (Masque/Libs/LibDBIcon-1.0/LibDBIcon-1.0.lua):
-- el OnUpdate que reposiciona el boton alrededor del minimapa SOLO corre
-- mientras el usuario arrastra el icono (OnDragStart/OnDragStop) -- fuera de
-- eso el boton no pelea su posicion, asi que reparentarlo es seguro.
-- Nada de esto toca frames seguros/protegidos -- cero riesgo de taint.
-- ==========================================================================
local ADDON, ns = ...

local MINIMAPBUTTONS_KEY = "minimapbuttons"
ns.MINIMAPBUTTONS_KEY = MINIMAPBUTTONS_KEY
ns.IsMinimapButtons = function(key) return key == MINIMAPBUTTONS_KEY end

local TRIGGER_BG_FILE = "point_plate.tga"       -- resuelto via skin, ver ResolveTex
local BORDER_FILE = "actionbutton-border square.tga"   -- idem, ya usado por auras/glow

-- Sistema de Skins (2026-07-24, mejora #4 pedida por el usuario): resuelve
-- contra la skin ACTIVA, mismo patron que ClassPower.lua/Raid.lua -- se llama
-- de nuevo en cada Layout()/LayoutGroup() (no solo al crear), asi que un
-- cambio de skin se refleja solo con que ns.ApplySkin llame
-- ns.RefreshMinimapButtons (ver core.lua).
local function ResolveTex(filename)
    if ns.SkinResolve then return ns.SkinResolve(filename) end
    return "Interface\\AddOns\\MyCustomFrames\\Assets\\" .. filename
end

local function MinimapButtonsDefaults()
    return {
        enabled = true,
        -- Posicion del TRIGGER (el icono siempre visible que hay que
        -- hoverear) -- mismo esquema point/relPoint/offset/anchor/scale que
        -- TopWidget.lua. FIX (2026-07-24, "donde tengo que hacer mouse
        -- over?"): el default original anclaba a UIParent TOPRIGHT (esquina
        -- de LA PANTALLA), pero el minimapa de este addon vive por default en
        -- BOTTOMRIGHT de UIParent (ver Minimap.lua) -- quedaban lejos uno del
        -- otro. Ahora ancla directo al Minimap (afuera de su borde
        -- izquierdo-arriba; abajo del minimapa ya lo ocupa el widget nativo
        -- "below minimap" de Blizzard, ver LayoutBelowMinimapWidget).
        point = "TOPRIGHT", relPoint = "TOPLEFT", offsetX = -6, offsetY = -4,
        anchor = "Minimap", scale = 1.0, strata = "MEDIUM",
        triggerSize = 28,
        -- Grilla de iconos revelados al hover.
        iconSize = 24, rowSpacing = 4, colSpacing = 4, perRow = 6,
        direction = "down",   -- "down"/"up"/"left"/"right": hacia donde crece la grilla desde el trigger
        fadeDuration = 0.15,
        leaveDelay = 0.7,
        -- Mejora #2 (2026-07-24): nombres (LDB name, case-insensitive) que
        -- NUNCA se capturan -- quedan como Blizzard/el addon dueño los
        -- maneje, sin pasar por el sistema de hover. Editable a mano por
        -- ahora (sin menu todavia) via /mcfminimapbtnsignore <nombre> o
        -- escribiendo directo aca.
        ignoreList = {},
    }
end
ns.MinimapButtonsDefaults = MinimapButtonsDefaults

local function P()
    local db = ns.GetDB and ns.GetDB()
    return db and db.minimapbuttons
end

-- ==========================================================================
-- COLECCION de botones (LibDBIcon + escaneo generico).
-- ==========================================================================
-- FIX (2026-07-24, "se siguen viendo los bordes originales"): un borde
-- pintado DETRAS del icono (ver GetBorder mas abajo) no puede tapar el borde
-- PROPIO de cada boton -- ese es parte del boton mismo, dibujado ENCIMA. La
-- unica forma real de uniformar el look es Masque (para eso existe): oculta
-- el arte nativo de cada boton (borde/fondo/icono) y aplica un skin parejo.
-- Este addon ya tiene un skin de Masque registrado (MasqueSkin.lua,
-- "Azerite HEX") -- el usuario elige a mano en el panel de Masque que skin
-- usar para ESTE grupo, igual que hace con Bartender4/etc.
local MSQ_GROUP_NAME = "Minimap Buttons"
local MSQ_BASE_ICON_SIZE = 36   -- tamaño "base" que asumen los skins de Masque (Core/Skins/Defaults)
local msqGroup
local function EnsureMasqueGroup()
    if msqGroup then return msqGroup end
    local MSQ = LibStub and LibStub("Masque", true)
    if not MSQ then return nil end
    local ok, grp = pcall(MSQ.Group, MSQ, ADDON, MSQ_GROUP_NAME)
    if ok then msqGroup = grp end
    return msqGroup
end

-- FIX (2026-07-24, "cambia el tamaño del icono, pero no del borde"): con
-- Masque activo, el borde que se ve es el que dibuja EL SKIN de Masque, con
-- su propio tamaño fijo (definido por el skin, no por nuestro iconSize) --
-- por eso el slider agrandaba el icono pero el borde quedaba clavado. Masque
-- expone justo para esto un "Scale" DE GRUPO (mismo mecanismo que usa su
-- propio panel de opciones): reescala icono+borde+highlight+todo el skin
-- junto. Se llama SOLO cuando el numero realmente cambio (evita ReSkin todo
-- el grupo en cada tick de la grilla).
local lastMsqScale
local function SyncMasqueScale(iconSize)
    local grp = EnsureMasqueGroup()
    if not grp then return end
    local scale = (iconSize or 24) / MSQ_BASE_ICON_SIZE
    if scale == lastMsqScale then return end
    lastMsqScale = scale
    pcall(grp.__Set, grp, "Scale", scale)
end

local collected = {}   -- [button] = true (ya capturado, no volver a agarrar)
local iconList = {}    -- array ordenado de botones capturados
local buttonNames = {} -- [button] = nombre (LDB name, o GetName() del scan generico)
local container        -- frame que contiene la grilla revelada
local trigger           -- icono siempre visible, arrastrable/escalable

local function IsIgnored(name)
    if not name then return false end
    local p = P()
    local list = p and p.ignoreList
    if not list then return false end
    local lower = name:lower()
    for _, n in ipairs(list) do
        if type(n) == "string" and n:lower() == lower then return true end
    end
    return false
end

-- FIX (2026-07-24, "no esta ocultando el borde dorado original"): Masque solo
-- puede ocultar regiones que DETECTA -- el aro dorado que persistia en varios
-- iconos (todos menos el de Plumber, que usa la estructura LDB "limpia") no
-- es parte de la textura del icono, es una region TEXTURA APARTE que el
-- addon dueño dibuja encima. Encontrado releyendo HidingBar.lua de nuevo
-- (setMButtonRegions, linea ~362): busca especificamente la textura NATIVA
-- de Blizzard `Interface\Minimap\MiniMap-TrackingBorder` (fileID 136430) --
-- el aro de tracking del minimapa, que MUCHOS addons reusan tal cual como
-- "borde" de su icono. Mismo chequeo aca: escanea las regiones del boton por
-- ESA textura puntual (por fileID o por nombre de archivo) y la oculta.
local NATIVE_BORDER_FILEID = 136430   -- Interface\Minimap\MiniMap-TrackingBorder
local function HideNativeBorder(btn)
    for _, region in ipairs({ btn:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture" then
            local tex = region:GetTexture()
            local isNativeBorder = tex == NATIVE_BORDER_FILEID
                or (type(tex) == "string" and tex:lower():find("minimap%-trackingborder", 1, false))
            if isNativeBorder then
                region:SetAlpha(0)
                -- Defensivo (mismo patron que HideBlizzardChrome en Core.lua
                -- de Mainmenu-Gonkast): si el addon dueño lo re-muestra en su
                -- propio refresh, esto lo vuelve a apagar sin volver a
                -- recorrer TODAS las regiones cada vez.
                if not region._mcfNativeBorderHooked then
                    region._mcfNativeBorderHooked = true
                    hooksecurefunc(region, "SetAlpha", function(self, a)
                        if a and a > 0 then self:SetAlpha(0) end
                    end)
                end
            end
        end
    end
end

local function IsCandidateButton(btn)
    if not btn or collected[btn] then return false end
    if btn == trigger or btn == container then return false end
    if btn.IsProtected and btn:IsProtected() then return false end
    if btn.IsForbidden and btn:IsForbidden() then return false end
    return true
end

-- `name` opcional: LDB name (LibDBIcon) o btn:GetName() (scan generico, puede
-- ser nil para frames anonimos) -- usado para el orden alfabetico (mejora #1)
-- y la ignore list (mejora #2).
local function AddButton(btn, name)
    if not IsCandidateButton(btn) then return end
    if IsIgnored(name) then return end   -- se deja intacto, nunca se captura
    collected[btn] = true
    buttonNames[btn] = name
    iconList[#iconList + 1] = btn
    -- Guardado por si alguna vez se quiere "devolver" el boton (desactivar
    -- el sistema) -- no usado todavia, pero barato de tener.
    btn._mcfMMOrigParent = btn._mcfMMOrigParent or btn:GetParent()
    if container then
        btn:SetParent(container)
    end
    local grp = EnsureMasqueGroup()
    if grp then pcall(grp.AddButton, grp, btn) end
    pcall(HideNativeBorder, btn)
end

-- Libera un boton capturado: lo devuelve a su parent original y lo saca del
-- sistema (usado por /mcfminimapbtnsignore cuando se ignora algo que YA
-- estaba capturado).
local function ReleaseButton(btn)
    if not collected[btn] then return end
    if msqGroup then pcall(msqGroup.RemoveButton, msqGroup, btn) end
    collected[btn] = nil
    buttonNames[btn] = nil
    for i, b in ipairs(iconList) do
        if b == btn then table.remove(iconList, i); break end
    end
    local orig = btn._mcfMMOrigParent
    if orig then btn:SetParent(orig) end
end

-- Escaneo generico (fallback, ver nota de arriba): mismos criterios que
-- HidingBar:grabMinimapAddonsButtons -- cuadrado-ish, chico respecto al
-- minimapa, con algun handler de click, no protegido.
local function ScanMinimapChildren()
    local mm = _G.Minimap
    if not mm then return end
    local mw, mh = mm:GetSize()
    if not mw or not mh or mw == 0 or mh == 0 then return end
    local halfW, halfH = mw * 0.5, mh * 0.5
    for _, child in ipairs({ mm:GetChildren() }) do
        if not collected[child] and child.GetObjectType then
            local okW, w = pcall(child.GetWidth, child)
            local okH, h = pcall(child.GetHeight, child)
            if okW and okH and w and h and w > 0 and h > 0
                and w < halfW and h < halfH
                and math.max(w, h) > 14 and math.abs(w - h) < 6
                and not (child.IsProtected and child:IsProtected())
            then
                -- FIX (error real en juego): GetScript ERRORA (no devuelve nil)
                -- si el TIPO de frame no soporta ese script en absoluto (ej.
                -- ZoomHitArea es un Frame plano, sin slot OnClick) -- HasScript
                -- primero evita eso (mismo chequeo que usa HidingBar); pcall
                -- de respaldo por si algun frame tampoco expone HasScript.
                local function SafeHasScript(scriptName)
                    if child.HasScript and not child:HasScript(scriptName) then return false end
                    local ok, handler = pcall(child.GetScript, child, scriptName)
                    return ok and handler ~= nil
                end
                if SafeHasScript("OnClick") or SafeHasScript("OnMouseUp") or SafeHasScript("OnMouseDown") then
                    local okName, cname = pcall(child.GetName, child)
                    AddButton(child, okName and cname or nil)
                end
            end
        end
    end
end

local ldbiHooked = false
local function TryLibDBIcon()
    local ldbi = LibStub and LibStub("LibDBIcon-1.0", true)
    if not ldbi then return end
    -- Botones ya registrados (creados antes de que este archivo corriera).
    local ok, names = pcall(ldbi.GetButtonList, ldbi)
    if ok and names then
        for _, name in ipairs(names) do
            local okBtn, btn = pcall(ldbi.GetMinimapButton, ldbi, name)
            if okBtn and btn then AddButton(btn, name) end
        end
    end
    -- Botones nuevos, registrados despues (addon que carga tarde, etc).
    if not ldbiHooked then
        ldbiHooked = true
        pcall(ldbi.RegisterCallback, ldbi, ns, "LibDBIcon_IconCreated", function(_, btn, name)
            AddButton(btn, name)
            if ns.RefreshMinimapButtons then ns.RefreshMinimapButtons() end
        end)
    end
end

-- ==========================================================================
-- LAYOUT de la grilla revelada.
-- ==========================================================================
-- Bordes propios por icono (mejora #3, 2026-07-24): "los iconos de cada
-- addon vienen con estilos dispares" -- un borde parejo por delante de cada
-- uno, mismo asset que ya usan auras/glow. FIX (2026-07-24, "que el borde
-- siempre este arriba del icono"): creado como hijo del BOTON mismo (no de
-- `container`) en capa OVERLAY -- un texture en `container` (capa BORDER)
-- quedaba SIEMPRE detras porque el boton es un FRAME aparte con frame level
-- mas alto que container (ver LayoutGroup: btn:SetFrameLevel(container+1)) --
-- el frame level de un FRAME entero gana sobre la capa de dibujo de otro
-- frame distinto, sin importar que capa se use. Parentado al boton, la capa
-- OVERLAY del borde SI gana dentro de ESE mismo frame contra el icono
-- (tipicamente ARTWORK/BACKGROUND). 1 borde por boton, reusado entre pasadas.
local borders = {}
local function GetBorder(btn)
    local b = borders[btn]
    if not b then
        b = btn:CreateTexture(nil, "OVERLAY")
        borders[btn] = b
    end
    return b
end

local function LayoutGroup()
    local p = P()
    if not p or not container then return end
    local iconSize = p.iconSize or 24
    local colSpacing = p.colSpacing or 4   -- hueco horizontal, entre columnas
    local rowSpacing = p.rowSpacing or 4   -- hueco vertical, entre filas
    local perRow = math.max(1, p.perRow or 6)
    local dir = p.direction or "down"
    SyncMasqueScale(iconSize)

    -- Solo los que el addon dueño tiene actualmente SHOWN (respeta su propio
    -- estado -- ej. un boton que solo aparece con un buff activo). Orden
    -- ALFABETICO por nombre (mejora #1, 2026-07-24: "el orden dependia de
    -- cuando se detecto cada boton, impredecible entre sesiones") -- los sin
    -- nombre (scan generico anonimo) quedan al final.
    local shown = {}
    for _, btn in ipairs(iconList) do
        if btn:IsShown() then shown[#shown + 1] = btn end
    end
    table.sort(shown, function(a, b)
        local na, nb = buttonNames[a], buttonNames[b]
        if na and nb then return na:lower() < nb:lower() end
        if na and not nb then return true end
        if nb and not na then return false end
        return false
    end)

    local n = #shown
    if trigger and trigger.countText then trigger.countText:SetText(tostring(n)) end
    if n == 0 then
        container:SetSize(1, 1)
        for _, b in pairs(borders) do b:Hide() end
        return
    end

    local cols, rows
    if dir == "left" or dir == "right" then
        rows = math.min(perRow, n)
        cols = math.ceil(n / rows)
    else
        cols = math.min(perRow, n)
        rows = math.ceil(n / cols)
    end

    local w = cols * iconSize + (cols - 1) * colSpacing
    local h = rows * iconSize + (rows - 1) * rowSpacing
    container:SetSize(w, h)

    -- Borde manual: SOLO como respaldo si Masque no esta disponible (con
    -- Masque, el grupo ya reemplaza el arte nativo de cada boton por un skin
    -- parejo -- dibujar TAMBIEN nuestro borde detras se veria duplicado).
    local useManualBorder = not EnsureMasqueGroup()

    local seen = {}
    for i, btn in ipairs(shown) do
        seen[btn] = true
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local x, y = col * (iconSize + colSpacing), -row * (iconSize + rowSpacing)
        btn:ClearAllPoints()
        btn:SetFrameLevel(container:GetFrameLevel() + 1)
        btn:SetPoint("TOPLEFT", container, "TOPLEFT", x, y)
        -- Pedido del usuario (2026-07-24, "quita eso, que masque controle el
        -- tamaño"): con Masque activo, SyncMasqueScale (arriba) ya reescala
        -- icono+borde+todo el skin juntos via el Scale del grupo -- forzar
        -- ADEMAS btn:SetSize/icon:SetSize a mano competia con eso. El resize
        -- manual del frame/icono queda SOLO como respaldo sin Masque.
        if useManualBorder then
            btn:SetSize(iconSize, iconSize)
            local iconTex = btn.icon or btn.Icon or (btn.GetNormalTexture and btn:GetNormalTexture())
            if iconTex and iconTex.SetSize then
                pcall(iconTex.ClearAllPoints, iconTex)
                pcall(iconTex.SetPoint, iconTex, "CENTER", btn, "CENTER", 0, 0)
                pcall(iconTex.SetSize, iconTex, iconSize, iconSize)
            end
        end

        if useManualBorder then
            local border = GetBorder(btn)
            border:SetTexture(ResolveTex(BORDER_FILE))
            border:ClearAllPoints()
            local pad = iconSize * 0.14   -- mismo criterio que AuraHoverPreview (BORDER_SCALE)
            border:SetPoint("TOPLEFT", container, "TOPLEFT", x - pad, y + pad)
            border:SetPoint("BOTTOMRIGHT", container, "TOPLEFT", x + iconSize + pad, y - iconSize - pad)
            border:Show()
        elseif borders[btn] then
            borders[btn]:Hide()
        end
    end
    -- Bordes de iconos que ya no estan visibles/capturados esta pasada.
    for btn, border in pairs(borders) do
        if not seen[btn] then border:Hide() end
    end
end
ns.RefreshMinimapButtonsLayout = LayoutGroup

-- ==========================================================================
-- HOVER: mostrar/ocultar la grilla. Fade con UIFrameFadeIn/Out (seguro --
-- `container` no es un frame seguro, a diferencia de las unitframes donde
-- ese API esta prohibido por el driver seguro, ver AttachFadeIn en core.lua).
-- ==========================================================================
-- FIX (2026-07-24, "si dejo de hacer mouse over, nunca se vuelve a ocultar"):
-- el enfoque anterior dependia de OnEnter/OnLeave del `container`. Bug real de
-- WoW con frames anidados con mouse habilitado: cuando el cursor pasa de
-- "container vacio" a "un boton HIJO" (los iconos reparentados), el ENGINE le
-- roba el foco de mouse al hijo -- eso dispara el OnLeave del container UNA
-- vez en ese momento (que se descartaba porque el chequeo geometrico
-- IsMouseOver seguia dando true), pero el container NUNCA vuelve a recibir un
-- OnEnter/OnLeave real despues de eso mientras el cursor se pasea entre
-- iconos y se va del todo -- se quedaba pegado para siempre. Mismo problema
-- que ya resolvio AuraHoverPreview.lua (comentario "cero dead zones"): en vez
-- de confiar en OnEnter/OnLeave, un TICKER geometrico (IsMouseOver, que SI es
-- confiable pase lo que pase con el foco) decide mostrar/ocultar.
local isOverGroup = false          -- estado actual (evita reiniciar el fade a cada tick)
local leaveElapsed = nil           -- nil = no contando; numero = segundos sin hover

local function ShowGroup()
    if not container then return end
    leaveElapsed = nil
    if isOverGroup then return end
    isOverGroup = true
    LayoutGroup()
    container:Show()
    UIFrameFadeIn(container, (P() and P().fadeDuration) or 0.15, container:GetAlpha(), 1)
end

local function HideGroupNow()
    if not container then return end
    isOverGroup = false
    leaveElapsed = nil
    UIFrameFadeOut(container, (P() and P().fadeDuration) or 0.15, container:GetAlpha(), 0)
    -- UIFrameFadeOut no oculta el frame solo (queda invisible pero "shown",
    -- lo que seguiria bloqueando el mouse) -- lo oculta de verdad al terminar
    -- el fade, salvo que se haya vuelto a mostrar mientras tanto.
    C_Timer.After((P() and P().fadeDuration) or 0.15, function()
        if container and not isOverGroup then container:Hide() end
    end)
end

-- ==========================================================================
-- CONSTRUCCION (holder/trigger arrastrable+escalable, mismo patron que
-- TopWidget.lua) + ticker de deteccion/reaseguro.
-- ==========================================================================
local Layout   -- forward-declarada: EnsureFrames la referencia en callbacks
                -- (OnDragStop/AttachScaleWheel) definidos ANTES de asignarla.

local function EnsureFrames()
    if trigger then return end

    trigger = CreateFrame("Button", nil, UIParent)
    ns.minimapButtonsTrigger = trigger   -- expuesto para diagnostico (/mcfscaledump)
    trigger:SetSize(22, 22)
    trigger.editBG = ns.MakeEditHighlight(trigger, "Minimap Buttons")
    trigger:SetMovable(true)
    trigger:RegisterForDrag("LeftButton")
    trigger:EnableMouse(true)

    local bg = trigger:CreateTexture(nil, "ARTWORK")
    bg:SetAllPoints()
    bg:SetTexture(ResolveTex(TRIGGER_BG_FILE))
    trigger.bg = bg

    -- Pedido del usuario (2026-07-24, "quitar el icono... que haya un numero
    -- con el alpha en 50% que diga la cantidad de botones"): reemplaza el
    -- icono fijo (que ademas se salia de la placa al achicar el trigger,
    -- "se ve por delante del borde") por un contador de texto.
    -- FIX (2026-07-24, "el numero no esta centrado al 100%, y que se
    -- reacomode con 2 digitos"): SetPoint("CENTER") solo sin JustifyH/V
    -- explicitos + auto-width por contenido puede quedar corrido con la
    -- fuente OUTLINE (padding de glifo asimetrico) -- fijado explicitamente
    -- + SetWidth ancho de sobra con JustifyH CENTER, asi 1 o 2 digitos
    -- SIEMPRE centran igual dentro de esa caja (no dependen del auto-size).
    local countText = trigger:CreateFontString(nil, "OVERLAY")
    countText:SetPoint("CENTER", 1, -0.5)
    countText:SetSize(24, 16)
    countText:SetJustifyH("CENTER")
    countText:SetJustifyV("MIDDLE")
    countText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    countText:SetTextColor(1, 1, 1, 0.5)
    trigger.countText = countText

    trigger:SetScript("OnDragStart", function(self)
        if ns.IsUnlocked() and not InCombatLockdown() then self:StartMoving() end
    end)
    trigger:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if ns.SnapFrameToGrid then ns.SnapFrameToGrid(self) end
        local p = P()
        if p then
            -- FIX (2026-07-24, "lo muevo y se reposiciona en un punto donde
            -- no lo deje"): trigger es hijo de UIParent, pero por default
            -- esta ANCLADO a Minimap (anchor != parent) -- StartMoving/
            -- StopMovingOrSizing recalcula el punto relativo al PADRE real
            -- (UIParent), no al ancla vieja. Antes se guardaba el offset
            -- nuevo (ya relativo a UIParent) pero p.anchor seguia diciendo
            -- "Minimap" -- Layout() volvia a anclar esos numeros contra el
            -- frame equivocado, saltando a otro lado. Ahora se guarda TAMBIEN
            -- el frame real al que quedo anclado tras soltar.
            local point, relativeTo, relPoint, x, y = self:GetPoint(1)
            p.point, p.relPoint, p.offsetX, p.offsetY = point, relPoint, x, y
            p.anchor = (relativeTo and relativeTo.GetName and relativeTo:GetName()) or ""
        end
        Layout()
        if ns.OnDragStopped then ns.OnDragStopped(MINIMAPBUTTONS_KEY) end
    end)
    -- OnEnter/OnLeave del trigger: SOLO tooltip. Mostrar/ocultar el grupo ya
    -- NO depende de estos eventos (ver nota arriba de ShowGroup/HideGroupNow)
    -- -- lo maneja el ticker de poll geometrico mas abajo.
    trigger:SetScript("OnEnter", function()
        GameTooltip:SetOwner(trigger, "ANCHOR_TOP")
        GameTooltip:SetText("Minimap addon buttons")
        GameTooltip:AddLine("Hover to show", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    trigger:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ns.AttachScaleWheel(trigger, P, Layout)

    container = CreateFrame("Frame", nil, UIParent)
    container:SetSize(1, 1)
    container:Hide()
    container:SetFrameStrata("MEDIUM")
    -- EnableMouse solo para que los clicks/hover de los iconos hijos
    -- funcionen con normalidad -- el show/hide del grupo entero NO usa
    -- OnEnter/OnLeave de este frame (ver nota arriba).
    container:EnableMouse(true)
end

Layout = function()
    EnsureFrames()
    local p = P()
    if not p then return end

    if not p.enabled then
        trigger:Hide()
        container:Hide()
        return
    end
    trigger:Show()
    trigger:SetFrameStrata(p.strata or "MEDIUM")
    if trigger.bg then trigger.bg:SetTexture(ResolveTex(TRIGGER_BG_FILE)) end
    ns.CompensateScale(p, "simple")
    local rs = ns.ResScale()
    trigger:SetScale((p.scale or 1) * rs)
    trigger:SetSize(p.triggerSize or 22, p.triggerSize or 22)

    local parent = _G[p.anchor]
    if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
    trigger:ClearAllPoints()
    trigger:SetPoint(p.point or "TOPRIGHT", parent, p.relPoint or "TOPRIGHT", (p.offsetX or -6) * rs, (p.offsetY or -6) * rs)

    -- Ancla el contenedor de la grilla segun la direccion de crecimiento.
    container:ClearAllPoints()
    local dir = p.direction or "down"
    local gap = 4
    if dir == "down" then
        container:SetPoint("TOP", trigger, "BOTTOM", 0, -gap)
    elseif dir == "up" then
        container:SetPoint("BOTTOM", trigger, "TOP", 0, gap)
    elseif dir == "left" then
        container:SetPoint("RIGHT", trigger, "LEFT", -gap, 0)
    else -- "right"
        container:SetPoint("LEFT", trigger, "RIGHT", gap, 0)
    end
    container:SetFrameStrata(p.strata or "MEDIUM")

    -- En preview (Lock) la grilla queda siempre visible para poder
    -- posicionar/escalar el trigger viendo donde cae -- mismo criterio que
    -- el resto del addon (unlocked = modo edicion).
    if ns.IsUnlocked() then
        ShowGroup()
    end

    LayoutGroup()
end
ns.RefreshMinimapButtons = Layout

-- Ticker: poll de hover cada frame (rapido, ver nota en ShowGroup/
-- HideGroupNow -- IsMouseOver geometrico, no depende de OnEnter/OnLeave) +,
-- cada 1s, deteccion/reintentos (LibDBIcon puede tardar en cargar segun el
-- orden de addons) + reaseguro de parent (por si algo reparenta el boton de
-- vuelta) + rescan periodico (fallback generico, addons que crean su boton
-- tarde sin pasar por LibDBIcon).
local ticker = CreateFrame("Frame")
ticker:Hide()
ticker:SetScript("OnUpdate", function(self, elapsed)
    if trigger and container then
        local unlocked = ns.IsUnlocked and ns.IsUnlocked()
        local over = trigger:IsMouseOver() or (container:IsShown() and container:IsMouseOver())
        if over or unlocked then
            ShowGroup()
        elseif isOverGroup then
            leaveElapsed = (leaveElapsed or 0) + elapsed
            if leaveElapsed >= ((P() and P().leaveDelay) or 0.35) then
                HideGroupNow()
            end
        end
    end

    self.t = (self.t or 0) + elapsed
    if self.t < 1.0 then return end
    self.t = 0

    TryLibDBIcon()
    ScanMinimapChildren()

    -- Reasegura el parent (defensivo, mismo patron que MM_ReassertArt).
    if container then
        for btn in pairs(collected) do
            if btn:GetParent() ~= container then
                btn:SetParent(container)
            end
        end
    end

    local p = P()
    if p and p.enabled and container and (container:IsShown() or ns.IsUnlocked()) then
        LayoutGroup()
    end
end)

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
    Layout()
    TryLibDBIcon()
    ScanMinimapChildren()
    LayoutGroup()
    ticker:Show()
end)

-- Temporal (2026-07-24): sin seccion de menu todavia -- resetea SOLO la
-- posicion/escala del trigger a los defaults actuales (util porque
-- FillProfile no pisa un punto ya guardado con el default viejo).
SLASH_MCFMINIMAPBTNSRESET1 = "/mcfminimapbtnsreset"
SlashCmdList["MCFMINIMAPBTNSRESET"] = function()
    if ns.ResetUnit then ns.ResetUnit(MINIMAPBUTTONS_KEY) end
end

-- Mejora #2 (2026-07-24, "lista de exclusion"): sin menu todavia, dos
-- comandos de texto para manejarla. /list imprime lo detectado (nombre real
-- si vino de LibDBIcon, o "sin nombre" para lo agarrado por el scan
-- generico) para que el usuario sepa que nombre exacto usar en /ignore.
SLASH_MCFMINIMAPBTNSLIST1 = "/mcfminimapbtnslist"
SlashCmdList["MCFMINIMAPBTNSLIST"] = function()
    print("|cff00ff00[MCF]|r Minimap buttons detected:")
    for btn in pairs(collected) do
        local name = buttonNames[btn] or "(sin nombre / scan generico)"
        print("  - " .. name .. (btn:IsShown() and "" or "  |cff888888(oculto por su addon)|r"))
    end
end

SLASH_MCFMINIMAPBTNSIGNORE1 = "/mcfminimapbtnsignore"
SlashCmdList["MCFMINIMAPBTNSIGNORE"] = function(msg)
    local name = msg and msg:match("^%s*(.-)%s*$")
    if not name or name == "" then
        print("|cff00ff00[MCF]|r Usage: /mcfminimapbtnsignore <name> (ver /mcfminimapbtnslist). Correrlo de nuevo con el mismo nombre lo saca de la lista.")
        return
    end
    local p = P()
    if not p then return end
    p.ignoreList = p.ignoreList or {}
    local lower = name:lower()
    for i, n in ipairs(p.ignoreList) do
        if type(n) == "string" and n:lower() == lower then
            table.remove(p.ignoreList, i)
            print("|cff00ff00[MCF]|r \"" .. name .. "\" removed from the ignore list.")
            return
        end
    end
    table.insert(p.ignoreList, name)
    -- Si ya estaba capturado, liberarlo YA (no esperar al proximo scan).
    for btn in pairs(collected) do
        if buttonNames[btn] and buttonNames[btn]:lower() == lower then
            ReleaseButton(btn)
            break
        end
    end
    if ns.RefreshMinimapButtonsLayout then ns.RefreshMinimapButtonsLayout() end
    print("|cff00ff00[MCF]|r \"" .. name .. "\" added to the ignore list (won't be captured).")
end
