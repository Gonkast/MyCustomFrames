--[[Perfy has instrumented this file]] local Perfy_GetTime, Perfy_Trace, Perfy_Trace_Passthrough = Perfy_GetTime, Perfy_Trace, Perfy_Trace_Passthrough; Perfy_Trace(Perfy_GetTime(), "Enter", "(main chunk) MyCustomFrames/NameplateBuild.lua"); local ADDON, ns = ...

-- ==========================================================================
-- MyCustomFrames - NameplateBuild.lua
--
-- CONSTRUCCION compartida de los elementos de nameplate (2026-07-28).
--
-- POR QUE EXISTE. NameplateLayout.lua ya unifico DONDE va cada cosa (numeros
-- puros: puntos de anclaje y offsets). Pero seguian existiendo dos
-- construcciones distintas de los MISMOS widgets: Nameplates.lua armaba los
-- reales y NameplateDesigner.lua armaba mocks aparte, cada uno con su copia de
-- la formula de tamaño. La duplicacion era literal -- ResizeAuraIcon/
-- ResizeAuraHolder de un lado y LayoutAuraGroupIconsMock del otro, con el 3 y
-- el 0.26 escritos a mano en el mock. Cualquier cambio en uno desincronizaba el
-- otro en silencio, y solo se notaba MIRANDO el juego.
--
-- Sintoma real de eso: los siete helpers de tamaño de ns.NPLayout
-- (AuraHolderSize, AuraIconOffset, HealthSize, CastSize, ...) tenian CERO usos.
-- Se habian escrito como fuente unica y nunca se conectaron, asi que los dos
-- lados seguian calculando por su cuenta.
--
-- QUE HACE. Un solo constructor por elemento, con un flag `preview`:
--   * preview = false -> el widget real (Button + Cooldown nativo, etc).
--   * preview = true  -> la version del panel (sin Cooldown ni datos de
--                        unidad, con relleno de mentira para poder verlo).
-- La GEOMETRIA -- tamaños, insets, anclaje de los iconos dentro del holder --
-- es la MISMA linea de codigo en los dos casos, que es todo el punto. Lo unico
-- que cambia entre real y preview es lo que no se puede tener en un panel:
-- datos de unidad en vivo y widgets restringidos.
--
-- Carga DESPUES de NameplateLayout.lua y ANTES de Nameplates.lua.
-- ==========================================================================

local L = ns.NPLayout
-- Constante, no un literal dentro del bucle: `{ "big", "personal", "enemy" }`
-- escrito en la llamada a ipairs construia una tabla en CADA LayoutPlate.
local AURA_KEYS = { "big", "personal", "enemy" }
local FONT = [[Fonts\FRIZQT__.TTF]]   -- la misma en real y preview
local B = {}
ns.NPBuild = B

-- Cuanto sobresale el marco del icono, como fraccion de su lado. Vivia como
-- local en Nameplates.lua y como literal 0.26 en el designer.
B.AURA_BORDER_SCALE = 0.26

-- Caja del holder del NOMBRE. Es FIJA a proposito y los dos lados deben usar la
-- misma: el holder se ancla por BOTTOM con el texto en CENTER, asi que el texto
-- queda a ALTURA/2 sobre el punto de anclaje. Si un lado dimensiona la caja al
-- texto y el otro no, el nombre cae a distinta altura -- y la diferencia crece
-- con el tamaño de fuente. Fue exactamente ese bug (reportado 2026-07-28): el
-- panel la ajustaba al texto, el real la tenia clavada en 220x20.
B.NAME_HOLDER_W, B.NAME_HOLDER_H = 220, 20

-- ---- Geometria de auras (una sola formula para real y preview) ------------

-- Tamaño del holder: SIEMPRE para AURA_MAX_PER_CAT iconos aunque se muestren
-- menos. Importa que sea exacto: cuando el grupo se ancla por "BOTTOM"
-- (direccion "center"), el ancho del holder decide donde cae el centro y por lo
-- tanto TODOS los iconos. Un holder de 2 iconos en el mock contra uno de 3 en
-- el real fue un bug reportado.
function B.LayoutAuraHolder(holder, p) Perfy_Trace(Perfy_GetTime(), "Enter", "B.LayoutAuraHolder MyCustomFrames/NameplateBuild.lua:61:0");
    holder:SetSize(L.AuraHolderSize(p))
Perfy_Trace(Perfy_GetTime(), "Leave", "B.LayoutAuraHolder MyCustomFrames/NameplateBuild.lua:61:0"); end

function B.LayoutAuraIcon(b, slot, p) Perfy_Trace(Perfy_GetTime(), "Enter", "B.LayoutAuraIcon MyCustomFrames/NameplateBuild.lua:65:0");
    local sz = L.AuraIconSize(p)
    b:SetSize(sz, sz)
    b:ClearAllPoints()
    b:SetPoint("BOTTOMLEFT", L.AuraIconOffset(p, slot))
    local inset = sz * B.AURA_BORDER_SCALE
    b.border:ClearAllPoints()
    b.border:SetPoint("TOPLEFT", -inset, inset)
    b.border:SetPoint("BOTTOMRIGHT", inset, -inset)
Perfy_Trace(Perfy_GetTime(), "Leave", "B.LayoutAuraIcon MyCustomFrames/NameplateBuild.lua:65:0"); end

-- Redimensiona holder + sus iconos de una. Es lo que llaman los dos lados
-- cuando cambia auraIconSize/auraPadding.
function B.LayoutAuraGroup(holder, p) Perfy_Trace(Perfy_GetTime(), "Enter", "B.LayoutAuraGroup MyCustomFrames/NameplateBuild.lua:78:0");
    B.LayoutAuraHolder(holder, p)
    for slot, b in ipairs(holder.icons or {}) do
        B.LayoutAuraIcon(b, slot, p)
    end
Perfy_Trace(Perfy_GetTime(), "Leave", "B.LayoutAuraGroup MyCustomFrames/NameplateBuild.lua:78:0"); end

-- ---- Construccion de auras -----------------------------------------------

-- `preview`: el real necesita un Button (recibe clicks/tooltip) con un widget
-- Cooldown nativo -- la cuenta regresiva la dibuja el motor en C, que es la
-- unica forma secret-safe de mostrarla (ver la nota larga en Nameplates.lua).
-- En el panel no hay unidad ni cooldown que mostrar, asi que va un Frame simple
-- con textura plana y un numero fijo para que se vea algo.
function B.AuraIcon(holder, slot, p, preview) Perfy_Trace(Perfy_GetTime(), "Enter", "B.AuraIcon MyCustomFrames/NameplateBuild.lua:92:0");
    local b = CreateFrame(preview and "Frame" or "Button", nil, holder)
    if not preview then
        -- "los numeros siempre por encima en el strata" (pedido 2026-07-19):
        -- TOOLTIP es la strata que usa el resto del addon para eso.
        --
        -- En el PREVIEW no se sube la strata a proposito: TOOLTIP pondria los
        -- iconos por encima de los controles del propio panel. El mismo orden
        -- relativo (auras arriba de la barra) se consigue alla con NIVELES --
        -- ver el bloque "ORDEN DE DIBUJADO" en NameplateDesigner.lua. Sin eso,
        -- el holder heredaba una capa por debajo del stage y las auras salian
        -- detras de la barra en el panel pero encima en el juego (reportado con
        -- capturas 2026-07-28).
        b:SetFrameStrata("TOOLTIP")
    end

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    if preview then
        icon:SetColorTexture(1, 1, 1, 0.15)
    else
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    b.icon = icon

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture(ns.AURA_BORDER)
    b.border = border

    local count = b:CreateFontString(nil, "OVERLAY")
    count:SetFont(FONT, 11, "OUTLINE")
    count:SetPoint("TOPRIGHT", 2, 2)
    count:SetTextColor(1, 1, 1, 1)
    b.count = count

    if preview then
        -- El tiempo restante del real lo dibuja el widget Cooldown CENTRADO y
        -- sin offset propio, asi que el preview lo imita fijo en CENTER -- no
        -- hay ningun *OffsetX/Y de tiempo que leer.
        count:SetText("2")
        local time = b:CreateFontString(nil, "OVERLAY")
        time:SetFont(FONT, 10, "OUTLINE")
        time:SetPoint("CENTER", 0, 0)
        time:SetTextColor(1, 1, 1, 1)
        time:SetText("5")
        b.time = time
    else
        local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
        cd:SetAllPoints()
        cd:SetDrawEdge(false)
        -- La cuenta regresiva NATIVA del widget Cooldown es secret-safe (la
        -- calcula el motor en C, no Lua). Intentar leer el numero nosotros
        -- (EvaluateRemainingTime sobre un duration object) nunca funciono: ese
        -- metodo no existe, asi que el pcall fallaba callado y el texto quedaba
        -- vacio siempre.
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
        pcall(cd.SetCountdownFont, cd, "MCFAuraTimeFontObj")
        cd:SetDrawSwipe(true)
        cd:SetSwipeColor(0, 0, 0, 0.7)
        b.cd = cd
    end

    B.LayoutAuraIcon(b, slot, p)
    if not preview then b:Hide() end
    Perfy_Trace(Perfy_GetTime(), "Leave", "B.AuraIcon MyCustomFrames/NameplateBuild.lua:92:0"); return b
end

-- Holder + sus AURA_MAX_PER_CAT iconos. La cantidad sale de ns.NPLayout en los
-- dos casos -- el mock la tenia escrita a mano como 3.
function B.AuraGroup(parent, p, preview) Perfy_Trace(Perfy_GetTime(), "Enter", "B.AuraGroup MyCustomFrames/NameplateBuild.lua:161:0");
    local holder = CreateFrame("Frame", nil, parent)
    local icons = {}
    for slot = 1, L.AURA_MAX_PER_CAT do
        icons[slot] = B.AuraIcon(holder, slot, p, preview)
    end
    holder.icons = icons
    B.LayoutAuraHolder(holder, p)
    Perfy_Trace(Perfy_GetTime(), "Leave", "B.AuraGroup MyCustomFrames/NameplateBuild.lua:161:0"); return holder
end

-- ==========================================================================
-- LAYOUT COMPLETO DE UN NAMEPLATE (2026-07-28)
--
-- POR QUE. Hasta ahora "compartir el layout" significaba que los dos lados
-- llamaban a ns.NPLayout para leer numeros, pero cada uno los APLICABA por su
-- cuenta, a su propia jerarquia de frames, con su propia idea de que escala
-- toca a quien. Seis rondas de arreglos encontraron seis diferencias reales y
-- distintas -- que es lo que pasa cuando hay dos implementaciones: se arregla
-- una y aparece la siguiente.
--
-- Esta funcion aplica el layout ENTERO a partir de una tabla de piezas. Los dos
-- lados le pasan sus frames y no queda ni una linea de posicionamiento propia.
--
-- LAS DOS ESCALAS, en un solo lugar. `scale` es la escala del plate (en el real
-- GetEffectiveScale del nameplate; en el editor su escala de referencia):
--   * regimen "plate"  -> hijo normal del root: sus offsets YA estan en
--                         unidades del plate. Factor 1.
--   * regimen "screen" -> lleva SetScale(1/scale) para que la FUENTE quede a
--                         tamaño fisico fijo (texto nitido a cualquier
--                         distancia). Eso divide sus unidades por `scale`, asi
--                         que hay que multiplicar el offset por `scale` para
--                         compensar y que la POSICION siga acompañando a la
--                         barra. Sin esa compensacion, la separacion
--                         nombre-barra variaba mas del doble con la distancia
--                         y ningun panel de escala fija podia predecirla.
-- ==========================================================================

-- Nombre logico de ancla -> frame de la tabla de piezas.
local function Resolve(P, relTo) Perfy_Trace(Perfy_GetTime(), "Enter", "Resolve MyCustomFrames/NameplateBuild.lua:200:6");
    if relTo == "health" then return Perfy_Trace_Passthrough("Leave", "Resolve MyCustomFrames/NameplateBuild.lua:200:6", P.health) end
    if relTo == "cast"   then return Perfy_Trace_Passthrough("Leave", "Resolve MyCustomFrames/NameplateBuild.lua:200:6", P.cast) end
    if relTo == "name"   then return Perfy_Trace_Passthrough("Leave", "Resolve MyCustomFrames/NameplateBuild.lua:200:6", P.name) end
    return Perfy_Trace_Passthrough("Leave", "Resolve MyCustomFrames/NameplateBuild.lua:200:6", P.root)
end

-- Redondeo al pixel FISICO. Vivia en Nameplates.lua y solo lo recibian el %% de
-- vida y el texto del cast; al pasar la colocacion a esta funcion lo reciben
-- todas las piezas de los dos lados. Existe porque una posicion sub-pixel
-- blurrea texto y texturas cuando el nameplate esta a escala chica.
local uiUnitFactor = 1
local pixelMon = CreateFrame("Frame")
local function RefreshUnitFactor() Perfy_Trace(Perfy_GetTime(), "Enter", "RefreshUnitFactor MyCustomFrames/NameplateBuild.lua:213:6");
    local _, h = GetPhysicalScreenSize()
    if h and h > 0 then uiUnitFactor = 768.0 / h end
Perfy_Trace(Perfy_GetTime(), "Leave", "RefreshUnitFactor MyCustomFrames/NameplateBuild.lua:213:6"); end
pixelMon:RegisterEvent("DISPLAY_SIZE_CHANGED")
pixelMon:SetScript("OnEvent", RefreshUnitFactor)
RefreshUnitFactor()

local function Snap(region, v) Perfy_Trace(Perfy_GetTime(), "Enter", "Snap MyCustomFrames/NameplateBuild.lua:221:6");
    if v == 0 then Perfy_Trace(Perfy_GetTime(), "Leave", "Snap MyCustomFrames/NameplateBuild.lua:221:6"); return 0 end
    local ok, scale = pcall(region.GetEffectiveScale, region)
    if not (ok and type(scale) == "number" and scale > 0) then Perfy_Trace(Perfy_GetTime(), "Leave", "Snap MyCustomFrames/NameplateBuild.lua:221:6"); return v end
    return Perfy_Trace_Passthrough("Leave", "Snap MyCustomFrames/NameplateBuild.lua:221:6", math.floor((v * scale) / uiUnitFactor + 0.5) * uiUnitFactor / scale)
end

-- Coloca UNA pieza. EXPORTADA: Nameplates.lua la llama para cada elemento real,
-- asi los dos lados no solo comparten los numeros sino la linea de codigo que
-- los aplica -- que es lo unico que impide de verdad que vuelvan a divergir.
--
-- `scale` = escala del plate (GetEffectiveScale del nameplate real, o la escala
-- de referencia del editor). Ver la nota de los regimenes en NameplateLayout.
function B.Place(elem, anchor, l, scale) Perfy_Trace(Perfy_GetTime(), "Enter", "B.Place MyCustomFrames/NameplateBuild.lua:234:0");
    if not (elem and anchor and l) then Perfy_Trace(Perfy_GetTime(), "Leave", "B.Place MyCustomFrames/NameplateBuild.lua:234:0"); return end
    scale = (type(scale) == "number" and scale > 0) and scale or 1
    local k = 1
    if l.scaleRegime == "screen" then
        -- Contra-escala para que la FUENTE quede a tamaño fisico fijo, y offset
        -- multiplicado por la escala para compensarla y que la POSICION siga
        -- acompañando a la barra.
        k = scale
        elem:SetScale(math.max(0.3, math.min(3, 1 / scale)))
    else
        -- Explicito, no implicito: si una pieza cambia de regimen (paso con los
        -- grupos de auras), hay que borrar la contra-escala que tenia puesta o
        -- se queda pegada un valor viejo.
        elem:SetScale(1)
    end
    elem:ClearAllPoints()
    elem:SetPoint(l.point, anchor, l.relPoint, Snap(elem, l.x * k), Snap(elem, l.y * k))
Perfy_Trace(Perfy_GetTime(), "Leave", "B.Place MyCustomFrames/NameplateBuild.lua:234:0"); end

local function Place(P, elem, l, scale) Perfy_Trace(Perfy_GetTime(), "Enter", "Place MyCustomFrames/NameplateBuild.lua:254:6");
    if not (elem and l) then Perfy_Trace(Perfy_GetTime(), "Leave", "Place MyCustomFrames/NameplateBuild.lua:254:6"); return end
    local anchor = Resolve(P, l.relTo)
    if not anchor then Perfy_Trace(Perfy_GetTime(), "Leave", "Place MyCustomFrames/NameplateBuild.lua:254:6"); return end
    B.Place(elem, anchor, l, scale)
Perfy_Trace(Perfy_GetTime(), "Leave", "Place MyCustomFrames/NameplateBuild.lua:254:6"); end

-- P: { root, health, healthBg, healthValue, cast, castText, name,
--      classification, raidMark, auras = { big=, personal=, enemy= } }
-- Cualquier pieza puede faltar: se saltea (el real y el editor no tienen
-- exactamente el mismo juego -- ej. el editor no dibuja fondo de highlight).
function B.LayoutPlate(P, p, scale) Perfy_Trace(Perfy_GetTime(), "Enter", "B.LayoutPlate MyCustomFrames/NameplateBuild.lua:265:0");
    if not (P and P.root) then Perfy_Trace(Perfy_GetTime(), "Leave", "B.LayoutPlate MyCustomFrames/NameplateBuild.lua:265:0"); return end
    scale = (type(scale) == "number" and scale > 0) and scale or 1
    local L2 = L

    -- Tamaños primero: varias colocaciones anclan a los bordes de la barra, asi
    -- que tiene que estar dimensionada antes de colgarle nada.
    if P.health then
        local w, h = L2.HealthSize(p)
        P.health:SetSize(w, h)
        if P.healthBg then P.healthBg:SetSize(w, h) end
    end
    if P.cast then
        local w, h = L2.CastSize(p)
        P.cast:SetSize(w, h)
        if P.castBg then P.castBg:SetSize(w, h) end
    end

    Place(P, P.health,         L2.Health(p),         scale)
    Place(P, P.healthValue,    L2.HealthValue(p),    scale)
    Place(P, P.cast,           L2.Cast(p),           scale)
    Place(P, P.castText,       L2.CastText(p),       scale)
    Place(P, P.name,           L2.Name(p),           scale)
    Place(P, P.classification, L2.Classification(p), scale)
    Place(P, P.raidMark,       L2.RaidMark(p),       scale)

    for _, key in ipairs(AURA_KEYS) do
        local holder = P.auras and P.auras[key]
        if holder then
            Place(P, holder, L2.AuraGroup(p, key), scale)
            B.LayoutAuraGroup(holder, p)
        end
    end
Perfy_Trace(Perfy_GetTime(), "Leave", "B.LayoutPlate MyCustomFrames/NameplateBuild.lua:265:0"); end

Perfy_Trace(Perfy_GetTime(), "Leave", "(main chunk) MyCustomFrames/NameplateBuild.lua");