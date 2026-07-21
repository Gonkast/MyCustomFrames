-- ==========================================================================
-- MyCustomFrames - MirrorTimers.lua
-- Reskin de las barras "Mirror Timer" NATIVAS de Blizzard (respiracion,
-- descanso/exhaustion, fingir muerte) -- MirrorTimer1/2/3 en el XML de
-- Blizzard, StatusBars que Blizzard REUSA dinamicamente segun que timers
-- esten activos (no hay una barra fija "de respiracion", Blizzard le asigna
-- el slot 1/2/3 que tenga libre en ese momento).
--
-- Investigado el reskin real de AzeriteUI5_JuNNeZ_Edition
-- (Components/Misc/MirrorTimers.lua) antes de tocar nada, como pidio el
-- usuario: AzeriteUI las REEMPLAZA por completo (esconde las 3 nativas +
-- arma barras propias desde cero, identificando el tipo via el string que
-- devuelve el evento/GetMirrorTimerInfo -- "BREATH"/"EXHAUSTION"/
-- "FEIGNDEATH" -- en vez de intentar mapear que slot 1/2/3 es cual).
--
-- Portado con la filosofia YA establecida en este addon (Nameplates.lua/
-- Minimap.lua/ExtraButton.lua: reskinear el frame NATIVO en su lugar, nunca
-- reemplazarlo) en vez de la de AzeriteUI (esconder+reconstruir todo) --
-- mas simple y menos superficie de riesgo.
--
-- CAMBIO 2026-07-19 (pedido del usuario: "que tenga exactamente la misma
-- apariencia que la de azeriteui, copia las texturas... no me dejes elegir
-- texturas desde el menu"): se descarta el intento anterior (texturas propias
-- del addon + selector en el menu) -- ahora usa las MISMAS texturas que
-- AzeriteUI usa para esto (Assets/cast_bar.tga + Assets/cast_back.tga,
-- copiadas a Assets/ de este addon) fijas, sin selector, y la misma
-- PROPORCION bar/backdrop que su Layouts/Data/MirrorTimers.lua
-- (backdrop = barra * 1.739 ancho, * 7.75 alto -- 193/111 y 93/12).
-- ==========================================================================
local ADDON, ns = ...

local A = ns.ASSETS
local BAR_TEX = A .. "cast_bar.tga"
local BACKDROP_TEX = A .. "cast_back.tga"
local BAR_TEXCOORD = { 0, 1, 0, 1 }

local function MirrorTimerDefaults()
    return {
        enabled = true,
        -- Mismo tamaño de barra/cage por defecto que AzeriteUI (111x12 la
        -- barra, 193x93 el cage) -- pedido del usuario 2026-07-19: "dejame
        -- elegir el w h de ambas" -- ahora son 4 campos independientes en vez
        -- de derivar el cage de una proporcion fija sobre el tamaño de barra.
        width = 111,
        height = 12,
        cageWidth = 193,
        cageHeight = 93,
        offsetX = 0,
        offsetY = -80,
        spacing = 6,
        barColor = { r = 0.922, g = 0.686, b = 0.353 },
        labelColor = { r = 1, g = 1, b = 1 },
        labelFontSize = 11,
        -- Pedido del usuario 2026-07-19: "controlar la posicion X Y y el
        -- texto tambien -- x, y, size y color". Offset del texto relativo a
        -- su posicion nativa (CENTER de la barra).
        labelOffsetX = 0,
        labelOffsetY = 0,
        -- Pedido del usuario 2026-07-19: "controlar la escala en el lock" --
        -- misma rueda-del-mouse-en-Lock que el resto del addon (ver
        -- ns.AttachScaleWheel en core.lua).
        scale = 1,
    }
end
ns.MirrorTimerDefaults = MirrorTimerDefaults

local function P()
    local db = ns.GetDB and ns.GetDB()
    return db and db.mirrortimer
end

local skinned = {}

-- FIX 2026-07-19 (confirmado en vivo con el error real): cada entrada de
-- container.mirrorTimers NO es la StatusBar en si -- es un Frame WRAPPER
-- (MirrorTimer.xml) sin nombre global (frame:GetName()==nil, por eso
-- concatenar tiraba error) que contiene .StatusBar/.Text/.Border/.TextBorder
-- como hijos con nombre. Reescrito para operar sobre esos hijos reales.
-- FIX 2026-07-19 (reportado por el usuario: "el bar realmente no se esta
-- cambiando" -- confirmado por /mcfmirrordiag que la textura SI quedaba
-- guardada/aplicada del lado de nuestro codigo, pero visualmente seguia
-- nativa): Blizzard reasigna su propia textura/color a esta StatusBar en
-- cada tick de progreso (la barra se actualiza constantemente mientras el
-- timer corre), pisando la nuestra despues de que la seteamos -- MISMO
-- patron ya resuelto hoy en ExtraButton.lua (cooldown/texturas nativas que
-- se auto-reafirman). Fix: hooksecurefunc sobre SetStatusBarTexture/
-- SetStatusBarColor de CADA bar, forzando de vuelta nuestro valor si
-- Blizzard intenta cambiarlo a otra cosa.
local hookedBars = setmetatable({}, { __mode = "k" })
local function HookBarForced(bar, wrapper)
    if hookedBars[bar] then return end
    hookedBars[bar] = true
    hooksecurefunc(bar, "SetStatusBarTexture", function(self, tex)
        local want = wrapper._mcfLastBarTex
        if want and tex ~= want then
            self:SetStatusBarTexture(want)
            local t = self:GetStatusBarTexture()
            if t then t:SetTexCoord(unpack(BAR_TEXCOORD)) end
        end
    end)
    hooksecurefunc(bar, "SetStatusBarColor", function(self, r, g, b)
        local want = wrapper._mcfLastBarColor
        if want and (math.abs((r or 0) - want.r) > 0.01 or math.abs((g or 0) - want.g) > 0.01 or math.abs((b or 0) - want.b) > 0.01) then
            self:SetStatusBarColor(want.r, want.g, want.b)
        end
    end)
end

-- `standalone`: true SOLO para el preview (hijo directo de UIParent, sin
-- contenedor que lo escale) -- los wrappers de las barras REALES son hijos
-- de MirrorTimerContainer, que ya se escala entero en PositionContainer;
-- escalarlos TAMBIEN individualmente aca duplicaba la escala (0.5 de
-- container * 0.5 del wrapper = 0.25 visual) -- por eso el mismatch
-- reportado por el usuario entre Lock y la barra real.
local function SkinOne(wrapper, standalone)
    if not wrapper then return end
    local bar = wrapper.StatusBar
    if not bar then return end
    if not skinned[wrapper] then
        skinned[wrapper] = true
        -- Backdrop FIJO (misma textura/proporcion que AzeriteUI, sin selector
        -- -- pedido explicito del usuario) -- se crea y texturea UNA vez,
        -- ANTES de esconder el resto para poder excluirla del barrido.
        local bg = wrapper:CreateTexture(nil, "BACKGROUND", nil, -1)
        bg:SetPoint("CENTER", 1, -2)
        bg:SetTexture(BACKDROP_TEX)
        wrapper.mcfBg = bg

        -- FIX 2026-07-19 (reportado por el usuario, confirmado via
        -- /framestack: "MirrorTimerContainer...19245682c00", una region
        -- ANONIMA sin campo con nombre -- .Border/.TextBorder no eran las
        -- unicas). En vez de seguir adivinando nombres de campo uno por uno,
        -- se recorren TODAS las regiones (texturas/fontstrings) del wrapper
        -- via GetRegions() y se ocultan las que no sean nuestras (mcfBg) ni
        -- el texto (Text, lo re-usamos para el label). SetAlpha(0) una sola
        -- vez no alcanzaba -- Blizzard reafirma esto en cada tick de progreso,
        -- por eso el hooksecurefunc sobre SetAlpha/Show de cada una.
        for _, region in ipairs({ wrapper:GetRegions() }) do
            if region ~= wrapper.mcfBg and region ~= wrapper.Text and region.SetAlpha then
                pcall(region.SetAlpha, region, 0)
                hooksecurefunc(region, "SetAlpha", function(self, a) if a and a > 0 then self:SetAlpha(0) end end)
                if region.Hide then
                    hooksecurefunc(region, "Show", function(self) self:Hide() end)
                end
            end
        end

        HookBarForced(bar, wrapper)
    end

    local p = P()
    if not p or not p.enabled then wrapper:SetAlpha(1); return end

    if standalone then wrapper:SetScale(p.scale or 1) end
    wrapper._mcfLastBarTex = BAR_TEX
    bar:SetStatusBarTexture(BAR_TEX)
    local tex = bar:GetStatusBarTexture()
    if tex then tex:SetTexCoord(unpack(BAR_TEXCOORD)) end

    if wrapper.mcfBg then
        wrapper.mcfBg:SetSize(p.cageWidth or 193, p.cageHeight or 93)
    end

    wrapper:SetSize(p.width or 111, p.height or 12)
    bar:SetAllPoints(wrapper)
    local bc = p.barColor or { r = 0.922, g = 0.686, b = 0.353 }
    wrapper._mcfLastBarColor = bc
    bar:SetStatusBarColor(bc.r, bc.g, bc.b)
    if wrapper.Text then
        local lc = p.labelColor or { r = 1, g = 1, b = 1 }
        pcall(wrapper.Text.SetTextColor, wrapper.Text, lc.r, lc.g, lc.b, 1)
        pcall(wrapper.Text.SetFont, wrapper.Text, "Fonts\\FRIZQT__.TTF", p.labelFontSize or 11, "OUTLINE")
        pcall(wrapper.Text.ClearAllPoints, wrapper.Text)
        pcall(wrapper.Text.SetPoint, wrapper.Text, "CENTER", p.labelOffsetX or 0, p.labelOffsetY or 0)
    end
end

-- Blizzard apila MirrorTimer1/2/3 dentro de MirrorTimerContainer con su
-- propio layout -- no lo tocamos (posicion del CONTENEDOR), solo reskineamos
-- las barras individuales dentro. Si el usuario quiere reposicionar todo el
-- grupo, se ancla el contenedor (offsetX/Y del perfil) sin romper el stacking
-- interno nativo entre las 3 barras.
-- FIX 2026-07-19 (confirmado en vivo via /mcfmirrordiag): en este cliente
-- _G.MirrorTimer1/2/3 NO EXISTEN como globales (a diferencia de lo que
-- asumia el codigo de AzeriteUI que revise, escrito para clientes viejos) --
-- solo existe MirrorTimerContainer. Las barras viven como hijos anonimos
-- ahi adentro. Se buscan de 3 formas, de la mas especifica a la mas generica,
-- por si el nombre del campo tambien cambio entre parches.
local function GetMirrorTimerBars(container)
    if not container then return {} end
    if container.mirrorTimers then
        local list = {}
        for _, bar in pairs(container.mirrorTimers) do list[#list + 1] = bar end
        if #list > 0 then return list end
    end
    if container.timerPool and container.timerPool.EnumerateActive then
        local list = {}
        for bar in container.timerPool:EnumerateActive() do list[#list + 1] = bar end
        if #list > 0 then return list end
    end
    -- Ultimo recurso: cualquier hijo que sea un StatusBar de verdad.
    local list = {}
    for _, child in ipairs({ container:GetChildren() }) do
        if child.GetObjectType and child:GetObjectType() == "StatusBar" then
            list[#list + 1] = child
        end
    end
    return list
end

-- Pedido del usuario 2026-07-19: "desactivalo por completo el control de
-- edit mode, que el 100% se controle por mi addon" -- confirmado que Mirror
-- Timer SI es un sistema manejado por el Edit Mode nativo (aparece
-- arrastrable ahi tambien). El intento anterior (hooksecurefunc reafirmando
-- DESPUES) dejaba una ventana visible con la posicion vieja de Blizzard.
-- Fix real (mismo tecnica que usa Bartender4 con MainMenuBarVehicleLeaveButton,
-- otro frame manejado por Edit Mode): Blizzard le pone a la INSTANCIA del
-- frame (no a la clase Frame en general) su propio SetPoint/ClearAllPoints/
-- SetScale que redirige al sistema de Edit Mode -- nil-earlos elimina ESE
-- override puntual y el frame vuelve a su comportamiento nativo de Frame
-- normal, momento en el que nuestras llamadas ya no son interceptadas por
-- nadie. Guardamos las funciones originales (las de Frame, no las de
-- Blizzard) ANTES de nil-ear, para poder seguir posicionandolo nosotros.
local containerFreed = false
local origSetPoint, origClearAllPoints, origSetScale
local function FreeContainerFromEditMode(container)
    if containerFreed or not container then return end
    containerFreed = true
    origSetPoint = container.SetPoint
    origClearAllPoints = container.ClearAllPoints
    origSetScale = container.SetScale
    container.SetPoint = nil
    container.ClearAllPoints = nil
    container.SetScale = nil
    -- Si Blizzard reasigna su override de nuevo en algun momento posterior
    -- (ej. al reabrir Edit Mode), lo volvemos a sacar apenas se detecte.
    -- pcall defensivo: si EditModeManagerFrame.OnShow no resulta ser una
    -- funcion hookeable (nombre/estructura distinta a la esperada), esto no
    -- debe romper el resto del archivo -- el nil-eo de arriba ya alcanza
    -- para el caso comun (una sola vez, al cargar).
    if EditModeManagerFrame then
        pcall(hooksecurefunc, EditModeManagerFrame, "OnShow", function()
            C_Timer.After(0, function()
                if container.SetPoint ~= origSetPoint then
                    origSetPoint = container.SetPoint or origSetPoint
                    origClearAllPoints = container.ClearAllPoints or origClearAllPoints
                    origSetScale = container.SetScale or origSetScale
                end
                container.SetPoint = nil
                container.ClearAllPoints = nil
                container.SetScale = nil
            end)
        end)
    end
end

local function PositionContainer(container, p)
    if not container then return end
    local setPoint = origSetPoint or container.SetPoint
    local clearAll = origClearAllPoints or container.ClearAllPoints
    local setScale = origSetScale or container.SetScale
    -- FIX 2026-07-19 (reportado por el usuario: "se sigue moviendo entre mi
    -- lock y donde queda por fuera"): el preview (dentro del Lock) SI se
    -- escala con la rueda (ver SkinOne/wrapper:SetScale), pero el
    -- contenedor REAL nunca se escalaba -- offsets iguales en escalas
    -- distintas caen en pixeles distintos de pantalla. Aplicar la MISMA
    -- escala aca cierra la diferencia.
    if setScale then setScale(container, p.scale or 1) end
    if clearAll then clearAll(container) end
    if setPoint then setPoint(container, "TOP", UIParent, "TOP", p.offsetX or 0, p.offsetY or -80) end
end

local function SkinContainer()
    local p = P()
    if not p or not p.enabled then return end
    local container = _G.MirrorTimerContainer or _G.MirrorTimerFrame
    if container then
        FreeContainerFromEditMode(container)
        PositionContainer(container, p)
    end
    for _, bar in ipairs(GetMirrorTimerBars(container)) do
        SkinOne(bar)
    end
end

-- Pedido del usuario 2026-07-19: "quiero que salga en el lock con un
-- outline para poder moverlo" -- se descarta el boton/modo de prueba
-- separado de antes: ahora usa EXACTAMENTE el mismo sistema de Lock/
-- edit-mode que el resto del addon (ns.IsUnlocked(), MakeEditHighlight,
-- reevaluado en cada ns.RefreshAll() -- mismo patron que Minimap.lua
-- root:EnableMouse(locked_edit)/editBG:SetShown(locked_edit)). El frame de
-- preview se crea UNA vez al cargar (no lazy), se muestra SOLO durante Lock
-- (ns.IsUnlocked()==true), y ahi se puede arrastrar -- fuera de Lock queda
-- oculto y el contenedor real de Blizzard hace lo suyo como siempre.
local previewFrame
local function GetPreviewFrame()
    if previewFrame then return previewFrame end
    local wrapper = CreateFrame("Frame", nil, UIParent)
    wrapper:SetSize(143, 40)
    -- FIX (2026-07-20, reportado por el usuario: "el mirror timer tiene un
    -- strata muy alto"): HIGH lo dejaba por encima del panel de opciones y de
    -- practicamente todo lo demas mientras se edita. MEDIUM = mismo strata que
    -- el resto de los previews de Lock (minimap/infobar/raid header).
    wrapper:SetFrameStrata("MEDIUM")
    wrapper:SetMovable(true)
    wrapper:RegisterForDrag("LeftButton")
    wrapper.StatusBar = CreateFrame("StatusBar", nil, wrapper)
    wrapper.StatusBar:SetMinMaxValues(0, 1)
    wrapper.StatusBar:SetValue(0.6)
    wrapper.Text = wrapper:CreateFontString(nil, "OVERLAY")
    wrapper.Text:SetPoint("CENTER")
    wrapper.Text:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    wrapper.Text:SetText("Feign Death")
    wrapper.editBG = ns.MakeEditHighlight and ns.MakeEditHighlight(wrapper, "Mirror Timer") or nil
    if wrapper.editBG then wrapper.editBG:ClearAllPoints(); wrapper.editBG:SetAllPoints(wrapper) end
    wrapper:SetScript("OnDragStart", function(self)
        if not ns.IsUnlocked() or InCombatLockdown() then return end
        self:StartMoving()
    end)
    wrapper:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p = P()
        if not p then return end
        local fx, fy = self:GetCenter()
        local px, py = UIParent:GetCenter()
        if fx and px then
            p.offsetX = fx - px
            p.offsetY = fy - (py + UIParent:GetHeight() / 2)
        end
        SkinContainer()
    end)
    -- Pedido del usuario 2026-07-19: "controlar la escala en el lock" --
    -- ns.RefreshMirrorTimerPreview se referencia DIFERIDO (closure) porque
    -- todavia no existe en este punto del archivo (se define mas abajo) --
    -- para cuando el usuario efectivamente use la rueda, el modulo ya cargo
    -- completo y esa funcion ya esta asignada.
    if ns.AttachScaleWheel then
        ns.AttachScaleWheel(wrapper, P, function()
            if ns.RefreshMirrorTimerPreview then ns.RefreshMirrorTimerPreview() end
        end)
    end
    wrapper:Hide()
    previewFrame = wrapper
    return wrapper
end

-- Llamado desde SkinContainer (a su vez llamado por ns.RefreshAll(), que
-- corre cada vez que se togglea Lock -- ver Editing.lua SetUnlocked) para
-- que el preview aparezca/desaparezca en sync, mismo criterio que Minimap.
local function RefreshPreview()
    local p = P()
    -- FIX 2026-07-19 (reportado por el usuario: "la escala lo reposiciona")
    -- -- mismo problema que ya tiene resuelto el resto del addon (ver
    -- CompensateScale en core.lua): los offsets de SetPoint se interpretan
    -- en el espacio de coordenadas propio del frame, escalado -- sin esto,
    -- cambiar la escala con la rueda corre el offsetX/Y guardado a otro
    -- pixel de pantalla. CompensateScale reescala esos offsets EN el perfil
    -- para compensar, mismo criterio que Minimap.lua/RefreshMinimap.
    if p and ns.CompensateScale then ns.CompensateScale(p) end
    local wrapper = GetPreviewFrame()
    local unlocked = ns.IsUnlocked and ns.IsUnlocked()
    -- FIX 2026-07-19 (reportado por el usuario: "cuando lock otra barra
    -- sigue existiendo de fondo, como que hay 2") -- si un mirror timer de
    -- verdad esta activo (ej. Rested) justo cuando entras en Lock, el
    -- contenedor REAL de Blizzard sigue mostrandose al mismo tiempo que
    -- nuestro preview, superpuestos. Por alpha (mismo criterio ya usado en
    -- este addon para ocultar frames nativos de Blizzard sin tocarlos por
    -- Lua -- ver HB_HideAlpha en core.lua) en vez de Hide()/eventos, para no
    -- interferir con la logica interna de Blizzard mientras el timer sigue
    -- corriendo de verdad.
    local container = _G.MirrorTimerContainer or _G.MirrorTimerFrame
    local lh = ns.GetDB() and ns.GetDB().lockHide
    if unlocked and p and p.enabled and not (lh and lh.mirrortimer) then
        wrapper:ClearAllPoints()
        wrapper:SetPoint("TOP", UIParent, "TOP", p.offsetX or 0, p.offsetY or -80)
        SkinOne(wrapper, true)
        wrapper:EnableMouse(true)
        wrapper:EnableMouseWheel(true)
        if wrapper.editBG then wrapper.editBG:SetShown(not (ns.GetDB() and ns.GetDB().hideEditOutline)) end
        wrapper:Show()
        if container then container:SetAlpha(0) end
    else
        wrapper:EnableMouse(false)
        wrapper:EnableMouseWheel(false)
        wrapper:Hide()
        if container then container:SetAlpha(1) end
    end
end
ns.RefreshMirrorTimerPreview = RefreshPreview
ns.RefreshMirrorTimers = function() SkinContainer(); RefreshPreview() end

-- FIX 2026-07-19 (reportado por el usuario: "no se esta actualizando en
-- tiempo real, use fingir muerte y solo aparece hasta despues del reload")
-- -- al reload, SkinContainer corre en PLAYER_ENTERING_WORLD, DESPUES de que
-- Blizzard ya tuvo tiempo de terminar de armar el widget interno de la
-- barra. En vivo, MIRROR_TIMER_START puede llegar ANTES de que Blizzard
-- termine de crear/poblar container.mirrorTimers para ese timer especifico
-- -- GetMirrorTimerBars encuentra la lista vacia/vieja ese mismo tick.
-- Reintento diferido (0 y 0.15s) ademas del inmediato, sin sacar el
-- inmediato (para no perder el caso que SI llega a tiempo).
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("MIRROR_TIMER_START")
f:RegisterEvent("MIRROR_TIMER_PAUSE")
f:RegisterEvent("MIRROR_TIMER_STOP")
f:SetScript("OnEvent", function(self, event)
    SkinContainer()
    if event == "MIRROR_TIMER_START" then
        C_Timer.After(0, SkinContainer)
        C_Timer.After(0.15, SkinContainer)
    end
end)

-- Diagnostico (pedido implicito del usuario: "sigue saliendo la barra de
-- blizzard" -- necesito confirmar si MirrorTimer1/2/3/Container siquiera
-- existen con esos nombres en este cliente antes de seguir adivinando).
SLASH_MCFMIRRORDIAG1 = "/mcfmirrordiag"
SlashCmdList["MCFMIRRORDIAG"] = function()
    local p = P()
    print("|cff00ff00[MCF mirrordiag]|r db.mirrortimer=" .. tostring(p ~= nil)
        .. " enabled=" .. tostring(p and p.enabled))
    print("  MirrorTimerContainer=" .. tostring(_G.MirrorTimerContainer ~= nil)
        .. " MirrorTimerFrame=" .. tostring(_G.MirrorTimerFrame ~= nil))
    local container = _G.MirrorTimerContainer or _G.MirrorTimerFrame
    local bars = GetMirrorTimerBars(container)
    print("  Barras encontradas dentro del contenedor: " .. #bars)
    for idx, fr in ipairs(bars) do
        print(("  #%d: shown=%s skinned=%s texture=%s"):format(
            idx, tostring(fr:IsShown()), tostring(skinned[fr]), tostring(fr._mcfLastBarTex)))
    end
    -- Pedido del usuario 2026-07-19: "la barra sigue desposicionandose
    -- cuando salgo del lock" -- diagnostico directo de GetPoint() +
    -- si nuestro nil-eo de SetPoint/ClearAllPoints sigue vigente, para
    -- confirmar la causa real en vez de seguir adivinando.
    if container then
        local point, relTo, relPoint, x, y = container:GetPoint(1)
        print(("  container:GetPoint()= %s, %s, %s, %.1f, %.1f"):format(
            tostring(point), tostring(relTo and relTo.GetName and relTo:GetName() or relTo), tostring(relPoint),
            tonumber(x) or -1, tonumber(y) or -1))
        print(("  container.SetPoint es nil (liberado de Edit Mode)=%s  scale=%.2f  containerFreed=%s"):format(
            tostring(container.SetPoint == nil), container:GetScale(), tostring(containerFreed)))
        print(("  IsUnlocked=%s  perfil offsetX=%s offsetY=%s scale=%s"):format(
            tostring(ns.IsUnlocked and ns.IsUnlocked()), tostring(p and p.offsetX), tostring(p and p.offsetY), tostring(p and p.scale)))
    end
end

SLASH_MCFMIRROR1 = "/mcfmirror"
SlashCmdList["MCFMIRROR"] = function(msg)
    local p = P()
    if not p then return end
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "width" and tonumber(arg) then
        p.width = math.max(60, math.min(400, tonumber(arg))); SkinContainer()
    elseif cmd == "height" and tonumber(arg) then
        p.height = math.max(8, math.min(40, tonumber(arg))); SkinContainer()
    elseif cmd == "offsetx" and tonumber(arg) then
        p.offsetX = tonumber(arg); ns.RefreshMirrorTimers()
    elseif cmd == "offsety" and tonumber(arg) then
        p.offsetY = tonumber(arg); ns.RefreshMirrorTimers()
    elseif cmd == "toggle" or cmd == "" then
        p.enabled = not p.enabled
        print("|cffffe19bMyCustomFrames|r: mirror timer skin " .. (p.enabled and "ON" or "OFF (reload para restaurar el look nativo)"))
    else
        print("|cffffe19bMyCustomFrames|r: /mcfmirror toggle | width <60-400> | height <8-40> | offsetx/offsety <n> -- para moverla, entra en Lock (mismo boton de siempre) y arrastrala.")
    end
end
