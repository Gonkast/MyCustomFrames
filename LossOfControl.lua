local ADDON, ns = ...

-- ==========================================================================
-- LOSS OF CONTROL INDICATOR (2026-07-27, pedido del usuario): icono con
-- swipe cuando VOS quedas stuneado/silenciado/rooteado/etc -- anclado al
-- portrait_player, esquina inferior-derecha (mismo offset que usaria el
-- badge de "role", que portrait_player nunca activa -- ver PORTRAITS en
-- core.lua: no tiene la feature roleLeader -- ese slot esta libre).
--
-- API: C_LossOfControl.GetActiveLossOfControlDataCount()/
-- GetActiveLossOfControlData(i) -- estable desde 9.0.1 (reemplazo del viejo
-- GetEventInfo/GetNumEvents), pensada especificamente para esto. A
-- diferencia del dispel/shield de Indicators.lua, esto es SIEMPRE dato
-- PROPIO (tu propio control, nunca el de otra unidad) -- sin restriccion de
-- secret values de por medio, se lee y opera directo.
--
-- Standalone en el .toc, sin orden especial: a diferencia de Indicators.lua
-- (que Units.lua necesita SINCRONICAMENTE al cargar), esto solo necesita
-- ns.portraits.portrait_player.root, leido reactivamente 1s despues de
-- PLAYER_LOGIN -- para entonces todos los archivos ya cargaron.
-- ==========================================================================

local holder

local function EnsureHolder()
    if holder then return holder end
    local portrait = ns.portraits and ns.portraits["portrait_player"]
    if not (portrait and portrait.root) then return nil end

    local f = CreateFrame("Frame", nil, portrait.root)
    -- Nivel POR ENCIMA de todo lo del retrato (2026-07-28, reportado: "el Loss
    -- of Control esta por debajo del portrait"). Sin esto heredaba el nivel del
    -- root y quedaba tapado: Portraits.lua pone el modelo 3D en root+1 y los
    -- badges en root+2. +5 deja margen por si mas adelante se agrega otra capa.
    f:SetFrameLevel(portrait.root:GetFrameLevel() + 5)
    f:SetSize(22, 22)
    -- Centrado en el borde SUPERIOR del retrato (2026-07-28, pedido con captura:
    -- estaba abajo a la derecha y se pidio arriba al centro). Se ancla el CENTER
    -- del icono al TOP del retrato, asi queda montado sobre el borde y sigue
    -- centrado aunque cambie el tamaño del retrato.
    f:SetPoint("CENTER", portrait.root, "TOP", 0, 0)
    f:Hide()

    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.tex = tex

    local border = f:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", -3, 3)
    border:SetPoint("BOTTOMRIGHT", 3, -3)
    border:SetTexture(ns.AURA_BORDER)
    border:SetVertexColor(1, 0.2, 0.2)

    local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    cd:SetAllPoints(f)
    cd:SetDrawEdge(false)
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
    f.cd = cd

    holder = f
    return holder
end

local testMode = false
local testCdSet = false

-- DRIVER AUTO-DESARMABLE (2026-08-08) -- ver el comentario largo abajo, junto
-- a su creacion. Declarados antes que Refresh porque Refresh los llama.
local ArmDriver, DisarmDriver

local function Refresh()
    local f = EnsureHolder()
    if not f then return end
    if not (C_LossOfControl and C_LossOfControl.GetActiveLossOfControlDataCount
        and C_LossOfControl.GetActiveLossOfControlData) then
        f:Hide()
        DisarmDriver()
        return
    end

    if testMode then
        f.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        -- Una sola vez por activacion (2026-08-08): antes esto corria en cada
        -- tick del ticker de 0.3s, o sea que el swipe se REINICIABA 3 veces por
        -- segundo y nunca avanzaba -- la preview mostraba un cooldown congelado.
        if not testCdSet then
            testCdSet = true
            f.cd:SetCooldown(GetTime(), 6)
        end
        f:Show()
        -- En test no hace falta el driver: no hay vencimiento real que vigilar,
        -- el swipe lo dibuja el propio Cooldown en C.
        DisarmDriver()
        return
    end

    local n = C_LossOfControl.GetActiveLossOfControlDataCount()
    for i = 1, n do
        local ok, data = pcall(C_LossOfControl.GetActiveLossOfControlData, i)
        if ok and data and data.priority and data.priority > 0 and data.iconTexture then
            f.tex:SetTexture(data.iconTexture)
            if data.startTime and data.duration and data.duration > 0 then
                pcall(f.cd.SetCooldown, f.cd, data.startTime, data.duration)
            else
                pcall(f.cd.Clear, f.cd)
            end
            f:Show()
            -- Hay un CC activo: recien AHORA hace falta vigilar su vencimiento.
            ArmDriver()
            return
        end
    end
    f:Hide()
    -- Nada activo: no hay nada que vencer, el driver no tiene trabajo.
    DisarmDriver()
end

-- RED DE SEGURIDAD, AHORA AUTO-DESARMABLE (2026-08-08)
--
-- Sigue haciendo falta: un vencimiento NATURAL del CC puede no volver a
-- disparar LOSS_OF_CONTROL_UPDATE, asi que sin esto el icono podria quedarse
-- pegado en pantalla. Lo que cambia es CUANDO corre.
--
-- Antes era un `C_Timer.NewTicker(0.3, Refresh)` creado en el login y sin
-- forma de pararse: 200 llamadas por minuto, para siempre, aunque no te
-- hubieran controlado en toda la sesion. Y la abrumadora mayoria de esas
-- llamadas no tenian nada que hacer -- salian por el `f:Hide()` del final.
--
-- Ahora es un OnUpdate que se arma SOLO mientras hay un CC activo (mismo
-- patron self-hiding que Units.lua y MinimapButtons.lua, que es la convencion
-- del addon para esto). Con el icono oculto no corre ni una linea de Lua por
-- frame; el evento sigue siendo quien lo enciende.
local driver = CreateFrame("Frame")
driver:Hide()
local driverArmed, acc = false, 0

ArmDriver = function()
    if driverArmed then return end
    driverArmed = true
    acc = 0
    driver:Show()
end

DisarmDriver = function()
    if not driverArmed then return end
    driverArmed = false
    driver:Hide()
end

driver:SetScript("OnUpdate", ns.Prof.Wrap("LossOfControl: driver 0.3s", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.3 then return end
    acc = 0
    Refresh()   -- se desarma solo si ya no hay nada activo
end))

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    C_Timer.After(1, function()
        local watcher = CreateFrame("Frame")
        watcher:RegisterEvent("LOSS_OF_CONTROL_UPDATE")
        watcher:SetScript("OnEvent", Refresh)
        Refresh()
    end)
end)

-- Expuesto en ns (2026-07-27) para el boton "Preview" de Options.lua. Devuelve
-- el estado NUEVO, que el boton usa para quedar marcado mientras este activo.
function ns.ToggleLossOfControlTest()
    testMode = not testMode
    testCdSet = false   -- que la proxima activacion vuelva a arrancar el swipe
    Refresh()
    return testMode
end

SLASH_MCFLOCTEST1 = "/mcfloctest"
SlashCmdList["MCFLOCTEST"] = function()
    print("|cff00ff00[MCF Loss of Control test]|r " .. (ns.ToggleLossOfControlTest() and "ON" or "off"))
end
