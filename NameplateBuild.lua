local ADDON, ns = ...

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
function B.LayoutAuraHolder(holder, p)
    holder:SetSize(L.AuraHolderSize(p))
end

function B.LayoutAuraIcon(b, slot, p)
    local sz = L.AuraIconSize(p)
    b:SetSize(sz, sz)
    b:ClearAllPoints()
    b:SetPoint("BOTTOMLEFT", L.AuraIconOffset(p, slot))
    local inset = sz * B.AURA_BORDER_SCALE
    b.border:ClearAllPoints()
    b.border:SetPoint("TOPLEFT", -inset, inset)
    b.border:SetPoint("BOTTOMRIGHT", inset, -inset)
end

-- Redimensiona holder + sus iconos de una. Es lo que llaman los dos lados
-- cuando cambia auraIconSize/auraPadding.
function B.LayoutAuraGroup(holder, p)
    B.LayoutAuraHolder(holder, p)
    for slot, b in ipairs(holder.icons or {}) do
        B.LayoutAuraIcon(b, slot, p)
    end
end

-- ---- Construccion de auras -----------------------------------------------

-- `preview`: el real necesita un Button (recibe clicks/tooltip) con un widget
-- Cooldown nativo -- la cuenta regresiva la dibuja el motor en C, que es la
-- unica forma secret-safe de mostrarla (ver la nota larga en Nameplates.lua).
-- En el panel no hay unidad ni cooldown que mostrar, asi que va un Frame simple
-- con textura plana y un numero fijo para que se vea algo.
function B.AuraIcon(holder, slot, p, preview)
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
    return b
end

-- Holder + sus AURA_MAX_PER_CAT iconos. La cantidad sale de ns.NPLayout en los
-- dos casos -- el mock la tenia escrita a mano como 3.
function B.AuraGroup(parent, p, preview)
    local holder = CreateFrame("Frame", nil, parent)
    local icons = {}
    for slot = 1, L.AURA_MAX_PER_CAT do
        icons[slot] = B.AuraIcon(holder, slot, p, preview)
    end
    holder.icons = icons
    B.LayoutAuraHolder(holder, p)
    return holder
end
