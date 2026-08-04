local ADDON, ns = ...

-- ==========================================================================
-- NAMEPLATE AURAS NEXT (2026-08-03, prep 12.1.0 "Curse of Ula'tek").
--
-- Reemplazo del sistema de auras de nameplates SOLO para 12.1.0+
-- (ns.IsMidnightNext, ver AuraContainerProbe.lua) -- en 12.0.7 este archivo
-- no hace nada, Nameplates.lua sigue usando el sistema viejo (GetUnitAuras +
-- ClassifyAura + iconos propios en slots fijos) sin cambios.
--
-- POR QUE: en 12.1.0 las auras son secretas en combate/mythic+/PvP, y
-- af.buffList/debuffList del AurasFrame nativo (la señal que el sistema
-- viejo usaba para el catch-all "importante") puede venir como tabla
-- PROHIBIDA (confirmado en vivo, ver el fix de HookAurasImportance mas
-- arriba en Nameplates.lua). La solucion sancionada por Blizzard es el
-- widget AuraContainer/AuraGroup: Blizzard dibuja los iconos EL MISMO, sin
-- exponerle nunca la data secreta al addon.
--
-- Confirmado leyendo el codigo YA ACTUALIZADO de Platynator y EllesmereUI
-- (ambos con soporte real de 12.1.0), y verificado en vivo con
-- /mcfauracontainer contra este mismo cliente:
--   1) CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
--      ("ManagedAuraContainer" NO es heredable via CreateFrame en este build).
--   2) container:AddAuraGroup(key, filterString, {opts}) ANTES de asociar unidad.
--   3) container:SetUnit(unit) DESPUES de declarar los grupos.
--   4) initializeFrame(button) es la UNICA ventana segura para construir
--      icono/cooldown/cuenta incluso con auras secretas.
--
-- ALCANCE reducido a proposito frente al sistema viejo: el catch-all "Big"
-- (boss mechanics ajenos, detectados antes via el buffList nativo) SE
-- PIERDE -- ya no hay forma de leerlo sin ese dato, y EllesmereUI llega a
-- la misma conclusion en su modelo base (su "Debuffs" container tambien es
-- SOLO personal + CC aparte, el catch-all "importante" es una feature
-- avanzada con su propio sistema de filtros editable que no vale la pena
-- replicar aca). 3 grupos, cada uno con un filtro 100% preciso (nunca
-- muestra algo que no corresponde):
--   cc       = CROWD_CONTROL (cualquier origen) -- iba a "big" antes, sigue
--              siendo la señal mas confiable e inequivoca.
--   personal = tus propios debuffs no-CC, mostrados en nameplate.
--   enemy    = buffs del enemigo.
-- ==========================================================================

local widgetOK
local function WidgetAvailable()
    if widgetOK ~= nil then return widgetOK end
    if not ns.IsMidnightNext or (ns.GetDB() and ns.GetDB()._npSafeMode) then widgetOK = false; return false end
    local ok, test = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
    if ok and test then
        test:Hide()
        test:SetParent(nil)
    end
    widgetOK = ok and test ~= nil
    return widgetOK
end
ns.NPAurasNext_Available = WidgetAvailable

-- key -> (filterString, candidateFilters). El color es solo cosmetico (borde
-- fino), para distinguir a simple vista los 3 grupos como ya distinguia el
-- sistema viejo por posicion.
-- RESTAURADO (2026-08-03, causa real encontrada: faltaba button:SetSize() en
-- BuildAuraButton -- "an unsized button renders nothing", ver AK.MakeInitializer/
-- ApplyStyleToRegions en EllesmereUI_AuraKit.lua). El filtro simplificado
-- HARMFUL|PLAYER de la ronda anterior NUNCA fue la causa -- era una pista
-- falsa, porque NADA se veia pasara lo que pasara con el filtro. Vuelve la
-- regla NATIVA exacta de Blizzard (Blizzard_NamePlateAuras.AddAura, confirmada
-- leyendo EUI_Nameplates_AuraContainers.lua:9-13,534-540): fetch
-- HARMFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY, filtrado por el candidato booleano
-- nameplateShowPersonal (la MISMA señal que alimentaba el viejo debuffList
-- nativo) -- eso es "personal debuffs y big debuffs" en un solo grupo, tal
-- como pidio el usuario.
-- Color de borde por grupo (2026-08-03, "que tengan mis bordes"): auras
-- secretas en 12.1.0 -- no hay forma de leer el debuff TYPE real (veneno/
-- magia/enfermedad/maldicion) como hace ns.DebuffTypeColor en
-- AuraHoverPreview.lua para party/arena, asi que el color va por GRUPO
-- (misma idea que el sistema viejo distinguia por posicion): cc=violeta
-- (control), personal=rojo (debuff propio), enemy=dorado (buff enemigo,
-- mismo tono que AuraHoverPreview usa para HELPFUL).
local GROUP_SPECS = {
    cc       = { filter = "HARMFUL|CROWD_CONTROL", color = { 0.64, 0.21, 0.93 } },
    personal = { filter = "HARMFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY", candidateFilters = { nameplateShowPersonal = true }, color = { 0.85, 0.15, 0.15 } },
    enemy    = { filter = "HELPFUL", candidateFilters = { isStealable = true }, color = { 1, 0.82, 0.2 } },
}
-- Mapeo a las claves de POSICION que ya existen en el Nameplate Designer
-- (ns.NPLayout.AuraGroup espera "big"/"personal"/"enemy") -- "cc" hereda el
-- anclaje de "big" (era practicamente lo mismo antes: CC SIEMPRE caia ahi).
local ANCHOR_KEY = { cc = "big", personal = "personal", enemy = "enemy" }

local function P() return ns.GetDB() and ns.GetDB().nameplates end

-- Mismo border/inset que AuraHoverPreview.lua (party/arena) -- pedido del
-- usuario "que tengan mis bordes", asi las auras de nameplate se ven
-- consistentes con el resto del addon en vez del borde generico de Blizzard.
local A = "Interface\\AddOns\\MyCustomFrames\\Assets\\"
local AURA_BORDER = A .. "actionbutton-border square.tga"
local BORDER_SCALE = 0.26

-- Fabrica (2026-08-03): antes UN SOLO BuildAuraButton servia para los 3
-- grupos sin diferenciarlos -- ahora necesita saber el color de borde de SU
-- grupo, asi que EnsureContainers pide un initializeFrame por-key via este
-- factory en vez de pasar la funcion pelada.
-- FIX (2026-08-05, "las posiciones no concuerdan" -- comparando nameplate
-- real vs el mock del Designer): el boton SIEMPRE se creaba a 24x24 fijo,
-- sin importar `sz` (ns.NPLayout.AuraIconSize, el mismo numero que
-- ReassertGeometry ya usa para el tamaño de la CAJA del container y para
-- elementWidth/Height del flow de Blizzard, mas abajo). El motor de
-- Blizzard hace su matematica de espaciado asumiendo botones de tamaño
-- `sz` (lo que le dijimos en SetAuraGroupLayout), pero el boton en si
-- renderizaba a 24 -- si `sz` (default 20, o lo que sea que el usuario
-- puso en el slider) no es exactamente 24, el icono real queda desplazado/
-- recortado respecto de donde la caja/flow dicen que deberia estar. El
-- mock del Designer (ns.NPBuild) SI usa `sz` de verdad, por eso mock y
-- juego real se veian en posiciones distintas.
local function MakeAuraButtonBuilder(color, sz)
    sz = sz or 20
    return function(button)
        -- FIX (2026-08-03, port literal de AK.MakeInitializer/ApplyStyleToRegions
        -- en EllesmereUI_AuraKit.lua): el motor SOLO usa elementWidth/Height del
        -- `layout` de AddAuraGroup para la MATEMATICA del flow (espaciado entre
        -- botones) -- el tamaño real y renderizable de CADA boton es responsa-
        -- bilidad nuestra, via SetSize explicito aca dentro. Nunca lo llamabamos
        -- -- su comentario literal es "an unsized button renders nothing", que
        -- explica exactamente el sintoma (0 iconos visibles pese a todo lo demas
        -- confirmado correcto).
        button:SetSize(sz, sz)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(button)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cd:SetAllPoints(button)
        cd:SetReverse(true)
        cd:SetDrawEdge(false)
        local count = button:CreateFontString(nil, "OVERLAY")
        count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, 2)
        -- Border propio (mismo patron que ResizeIcon/CreateIcon en
        -- AuraHoverPreview.lua): la textura se dibuja MAS GRANDE que el
        -- icono (inset negativo = BORDER_SCALE del tamaño) porque el arte
        -- del marco incluye el borde alrededor, no encima.
        local border = button:CreateTexture(nil, "OVERLAY")
        border:SetTexture(AURA_BORDER)
        local inset = sz * BORDER_SCALE
        border:SetPoint("TOPLEFT", -inset, inset)
        border:SetPoint("BOTTOMRIGHT", inset, -inset)
        if color then border:SetVertexColor(color[1], color[2], color[3]) end
        -- Los 3 setters publicos confirmados por EllesmereUI/Platynator -- es la
        -- unica forma soportada de "engancharle" visuales al boton sin leer nada
        -- de la aura en si (Blizzard resuelve icono/duracion/cuenta solo).
        pcall(button.SetIcon, button, icon)
        pcall(button.SetDurationCooldown, button, cd)
        pcall(button.SetApplicationCount, button, count, {})
        -- Fuente COMPARTIDA fija (2026-08-05, "mismos datos size y colores
        -- que player/target... y que no se puedan controlar"): MCFAuraTimeFontObj
        -- ahora vive en NameplateLayout.lua (creado con datos fijos, sin
        -- slider/color picker) -- cubre tanto el numero de cuenta regresiva
        -- del swipe (antes sin fuente propia en absoluto, dependia del
        -- default de Blizzard) como el contador de stacks (antes fijo a 11
        -- sin color, ahora 12 dorado como el resto del addon). Aplicada
        -- DESPUES de SetDurationCooldown/SetApplicationCount (arriba) --
        -- esas 2 llamadas de Blizzard pueden reestilar el cooldown/
        -- fontstring que les pasamos a su fuente por defecto, mismo motivo
        -- por el que AuraHoverPreview.lua aplica la suya al final.
        pcall(cd.SetCountdownFont, cd, "MCFAuraTimeFontObj")
        count:SetFontObject("MCFAuraTimeFontObj")
        button.mcfIcon, button.mcfCd, button.mcfCount, button.mcfBorder = icon, cd, count, border
    end
end

-- FIX CLAVE (2026-08-03, "en el addon que te dije funciona -- revisalo
-- bien"): releyendo EllesmereUI_AuraKit.lua:816-864 (AK.SetContainerAnchor/
-- SetContainerGrowth/ApplyContainerLayout) se confirma la pieza que
-- faltaba -- el container necesita que se le diga EXPLICITAMENTE el punto
-- de anclaje y direccion de crecimiento de su LAYOUT INTERNO
-- (SetFlowLayoutAnchorPoint/SetFlowLayoutGrowthDirection, o los nombres
-- viejos SetAuraLayoutAnchorPoint/SetAuraLayoutGrowthDirection segun el
-- build -- mismo fallback que usan ellos, "68914 replaced the
-- SetAuraLayout* family with SetFlowLayout*"). container:SetPoint() solo
-- posiciona el FRAME contenedor respecto a su padre -- es una API
-- COMPLETAMENTE DISTINTA a esta, que le dice al motor interno donde/como
-- acomodar los botones DENTRO del container. Sin esto, los botones existen
-- (pool preasignado, initializeFrame corrido) pero el motor no tiene
-- referencia para activarlos -- coincide exacto con "todo bien atado,
-- GetAuraGroupFrame siempre nil".
local function SetContainerFlowLayout(container, anchorPoint, growthH, growthV)
    local fAnchor = container.SetFlowLayoutAnchorPoint or container.SetAuraLayoutAnchorPoint
    if fAnchor then pcall(fAnchor, container, anchorPoint) end
    local fGrowth = container.SetFlowLayoutGrowthDirection or container.SetAuraLayoutGrowthDirection
    if fGrowth and growthH and growthV then pcall(fGrowth, container, growthH, growthV) end
end

-- Crea (una vez por uf) los 3 containers + sus grupos. No asocia unidad
-- todavia -- eso lo hace ns.NPAurasNext_Update en cada refresh, siguiendo
-- el mismo ciclo target-only que ya tenia el sistema viejo.
local function EnsureContainers(uf)
    if uf.mcfAurasNext then return uf.mcfAurasNext end
    -- Mismo `sz` que ReassertGeometry usa para la caja/flow -- ver el
    -- comentario largo en MakeAuraButtonBuilder arriba.
    local sz = (ns.NPLayout.AuraIconSize and ns.NPLayout.AuraIconSize(P())) or 20
    local containers = {}
    for key, spec in pairs(GROUP_SPECS) do
        local ok, c = pcall(CreateFrame, "AuraContainer", nil, uf, "CustomAuraContainerTemplate")
        if ok and c then
            -- FIX (2026-08-03, "sigo sin ver auras" -- confirmado leyendo
            -- EllesmereUI_AuraKit.lua:886 directo, el motor real): el
            -- container necesita un tamaño NO-CERO desde el instante que se
            -- crea, ANTES de declarar grupos -- "the engine drains its
            -- parse and layout phases from an OnUpdate armed in
            -- run-when-visible mode, so the container needs a renderable
            -- rect from the very first dirty mark." Un CreateFrame sin
            -- SetSize arranca en 0x0 -- si el tamaño real llega recien en
            -- ReassertGeometry (despues de AddAuraGroup), puede que el
            -- ciclo interno nunca se arme. Tamaño provisorio 1x1 aca,
            -- ReassertGeometry lo reemplaza con el real despues.
            c:SetSize(1, 1)
            -- FIX (2026-08-03, "sigo sin ver auras" -- releida
            -- EllesmereUI_AuraKit.lua:898-907, AK.AddGroupToContainer):
            -- SIEMPRE pasan maxFrameCount -- nunca lo mandaba, quedaba nil.
            -- Si el default real es 0 (no "ilimitado" como asumi), el grupo
            -- queda con limite de display CERO -- coincide exacto con
            -- "todo bien atado, nada visible nunca".
            local okAdd = pcall(c.AddAuraGroup, c, "np", spec.filter, {
                initializeFrame = MakeAuraButtonBuilder(spec.color, sz),
                maxFrameCount = 5,
                candidateFilters = spec.candidateFilters or {},
            })
            if okAdd then
                -- El anclaje/direccion de crecimiento del flow interno se fija
                -- recien en ReassertGeometry (abajo), una vez que sabemos que
                -- direccion configuro el usuario (right/left/center) para este
                -- grupo -- aca solo se crea el container, sin asumir "siempre
                -- BOTTOMLEFT/derecha" como antes (eso rompia los grupos con
                -- direction="left" -- crecian para el lado equivocado, tapando
                -- la barra de vida en vez de alejarse de ella).
                containers[key] = c
            end
        end
    end
    uf.mcfAurasNext = containers
    return containers
end

-- Reasienta tamaño/anclaje del CONTAINER (no de cada boton individual --
-- eso lo maneja Blizzard con SetAuraGroupLayout). Mismo criterio que
-- ReassertAuraGroupGeometry del sistema viejo: solo tocar cuando cambio
-- algo, comparado contra lo YA aplicado.
-- al.point (de NameplateLayout.lua, L.AuraGroup) es BOTTOMLEFT/BOTTOMRIGHT/
-- BOTTOM segun la direccion configurada por el usuario (right/left/center) --
-- el mismo punto sirve DOBLE proposito: donde se ancla el FRAME contenedor
-- (container:SetPoint) y hacia donde tiene que crecer el FLOW interno de
-- botones (SetFlowLayoutAnchorPoint/GrowthDirection), exactamente como
-- AnchorNPContainer en EUI_Nameplates_AuraContainers.lua deriva anchorPoint/
-- gH/gV de un solo slotVal. Antes el flow SIEMPRE crecia a la derecha sin
-- importar esto -- un grupo con direction="left" (ej. para no tapar la barra)
-- igual crecia hacia la derecha, sobre la barra.
local FLOW_ANCHOR = {
    BOTTOMLEFT  = { anchor = "BOTTOMLEFT",  gH = "Right", gV = "Up" },
    BOTTOMRIGHT = { anchor = "BOTTOMRIGHT", gH = "Left",  gV = "Up" },
    BOTTOM      = { anchor = "BOTTOMLEFT",  gH = "Right", gV = "Up" },
}

local function ReassertGeometry(uf, key, container)
    local p = P()
    local al = ns.NPLayout.AuraGroup(p, ANCHOR_KEY[key])
    if not al then return end
    local sz = (ns.NPLayout.AuraIconSize and ns.NPLayout.AuraIconSize(p)) or 20
    local padding = (ns.NPLayout.AuraPadding and ns.NPLayout.AuraPadding(p)) or 2
    local sig = al.point .. "|" .. al.x .. "|" .. al.y .. "|" .. sz .. "|" .. padding
    if container._mcfNextSig == sig then return end
    container._mcfNextSig = sig
    container:ClearAllPoints()
    -- FIX (2026-08-05, "las posiciones no son las mismas"): usaba al.point
    -- DOS VECES (ancla del container Y punto relativo en `uf`) -- NPLayout.
    -- AuraGroup en realidad devuelve al.relPoint = "TOP" (el grupo se ancla
    -- arriba del nameplate, ver L.AuraGroup en NameplateLayout.lua), campo
    -- que quedaba completamente ignorado. Con esto anclaba esquina-contra-
    -- la-misma-esquina en vez de esquina-contra-TOP -- quedaba pegado cerca
    -- del fondo de la plate en vez de arriba, bien lejos de donde el mock
    -- del Designer (que SI usa relPoint, igual que Classification/RaidMark
    -- ya hacian en NameplatesNext.lua) lo mostraba.
    container:SetPoint(al.point, uf, al.relPoint, al.x, al.y)
    container:SetSize(sz * 3 + padding * 2, sz) -- hasta 3 iconos por fila, igual que el sistema viejo
    pcall(container.SetAuraGroupLayout, container, "np", {
        elementWidth = sz, elementHeight = sz,
        elementSpacing = padding, lineSpacing = padding,
    })
    local fa = FLOW_ANCHOR[al.point] or FLOW_ANCHOR.BOTTOMLEFT
    local FD = AnchorUtil and AnchorUtil.FlowDirection
    SetContainerFlowLayout(container, fa.anchor, FD and FD[fa.gH], FD and FD[fa.gV])
end

-- Prewarm (2026-08-03, patron de EllesmereUI: crear los 3 AuraContainer de
-- un frame reciclable POR ADELANTADO, durante el prewarm gradual del pool
-- de plates -- no durante el primer pull grande de la sesion). Sin unidad
-- asociada todavia (SetUnit real la asigna despues, en el flujo normal) --
-- solo paga el costo de CreateFrame+AddAuraGroup x3 de antemano.
function ns.NPAurasNext_Prewarm(f)
    if not WidgetAvailable() then return end
    pcall(EnsureContainers, f)
end

-- Llamado desde Nameplates.lua UpdateAuras cuando ns.IsMidnightNext Y el
-- widget esta disponible -- mismo call site, mismo gate target-only que
-- ya tenia el sistema viejo (ver el `if not UnitIsUnit(unit, "target")`).
function ns.NPAurasNext_Update(uf, unit)
    local containers = EnsureContainers(uf)
    for key, c in pairs(containers) do
        -- FIX (2026-08-03, "/mcfnpnextdiag: shown=false(true)" -- confirmado
        -- REAL, no secreto): en ningun lado se llamaba container:Show() --
        -- solo ns.NPAurasNext_Hide llamaba :Hide(). Si el container se
        -- ocultaba UNA vez (ej. antes de que la unidad fuera target), se
        -- quedaba oculto para siempre -- nada lo volvia a mostrar aca.
        c:Show()
        ReassertGeometry(uf, key, c)
        if c._mcfNextUnit ~= unit then
            -- FIX (2026-08-03, "0/10 shown pese a tener buffs/debuffs
            -- reales"): la version anterior guardaba c._mcfNextUnit=unit
            -- ANTES de chequear si SetUnit/UpdateAllAuras realmente
            -- funcionaron -- si el 1er intento fallaba (ok=false), esta
            -- misma comparacion de arriba lo daba por "ya hecho" y NUNCA
            -- reintentaba, aunque el error se hubiera resuelto despues
            -- (ej. la unidad todavia no estaba lista en el primer intento).
            -- Ahora solo se marca como aplicado si las DOS llamadas
            -- devuelven ok -- si falla, se reintenta en el proximo update
            -- (mismo ciclo target-only, corre seguido). Resultado guardado
            -- en c._mcfNextOK para diagnostico (ver /mcfnpdiag).
            --
            -- FIX (2026-08-03, "sigue sin salir ninguna aura" pese a
            -- containers/unit/initializeFrame todos confirmados ok):
            -- Platynator (AurasNext.lua, ya investigado) llama
            -- `self.buffs:SetEnabled(true)` ANTES de SetUnit -- el
            -- container puede arrancar DESHABILITADO por defecto y quedarse
            -- asi para siempre sin este paso, sin tirar ningun error (solo
            -- no dibuja nada). No estaba en el probe original.
            pcall(c.SetEnabled, c, true)
            local okSet, errSet = pcall(c.SetUnit, c, unit)
            local okUpd, errUpd = pcall(c.UpdateAllAuras, c)
            c._mcfNextOK = okSet and okUpd
            c._mcfNextErr = (not okSet and tostring(errSet)) or (not okUpd and tostring(errUpd)) or nil
            if okSet and okUpd then
                c._mcfNextUnit = unit
                -- FIX (2026-08-03, "se siguen sin ver" -- todo confirmado
                -- bien atado, cero errores, aun asi nada visible): probando
                -- si el motor interno del widget necesita al menos 1 frame
                -- para procesar AddAuraGroup/SetSize ANTES de que
                -- UpdateAllAuras encuentre algo -- 2do llamado con demora,
                -- despues de que el primero ya confirmo exito.
                local unitAtCall = unit
                C_Timer.After(0, function()
                    if c._mcfNextUnit == unitAtCall then
                        pcall(c.UpdateAllAuras, c)
                    end
                end)
            end
        end
    end
end

-- Llamado cuando el uf deja de ser el target (o se recicla) -- oculta los 3
-- containers sin destruirlos, mismo criterio que el Hide() del sistema
-- viejo sobre uf.mcfAuraGroups.
function ns.NPAurasNext_Hide(uf)
    local containers = uf.mcfAurasNext
    if not containers then return end
    for key, c in pairs(containers) do
        c._mcfNextUnit = nil
        pcall(c.SetUnit, c, "none")
        c:Hide()
    end
end

-- FIX (2026-08-05, "que se aplique en vivo el auraIconSize"): EnsureContainers
-- solo crea los 3 containers/botones UNA VEZ por uf, con el `sz` de ESE
-- momento horneado en el boton (ver MakeAuraButtonBuilder) -- cambiar el
-- slider "Icon size" despues no movia nada hasta un /reload, mismo problema
-- que ya se resolvio para las auras de Party/Arena/Focus/Player/Target
-- (DestroyContainers+recrear). Destruye los 3 containers de un uf para que
-- EnsureContainers los recree frescos, con el `sz` actual, la proxima vez
-- que ns.NPAurasNext_Update corra para esa plate.
function ns.NPAurasNext_Rebuild(uf)
    local containers = uf.mcfAurasNext
    if not containers then return end
    for _, c in pairs(containers) do
        pcall(c.SetUnit, c, "none")
        c:Hide()
        pcall(c.SetParent, c, nil)
    end
    uf.mcfAurasNext = nil
end
