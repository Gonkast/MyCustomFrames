--[[Perfy has instrumented this file]] local Perfy_GetTime, Perfy_Trace, Perfy_Trace_Passthrough = Perfy_GetTime, Perfy_Trace, Perfy_Trace_Passthrough; Perfy_Trace(Perfy_GetTime(), "Enter", "(main chunk) MyCustomFrames/LossOfControl.lua"); local ADDON, ns = ...

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

local function EnsureHolder() Perfy_Trace(Perfy_GetTime(), "Enter", "EnsureHolder MyCustomFrames/LossOfControl.lua:25:6");
    if holder then Perfy_Trace(Perfy_GetTime(), "Leave", "EnsureHolder MyCustomFrames/LossOfControl.lua:25:6"); return holder end
    local portrait = ns.portraits and ns.portraits["portrait_player"]
    if not (portrait and portrait.root) then Perfy_Trace(Perfy_GetTime(), "Leave", "EnsureHolder MyCustomFrames/LossOfControl.lua:25:6"); return nil end

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
    Perfy_Trace(Perfy_GetTime(), "Leave", "EnsureHolder MyCustomFrames/LossOfControl.lua:25:6"); return holder
end

local testMode = false

local function Refresh() Perfy_Trace(Perfy_GetTime(), "Enter", "Refresh MyCustomFrames/LossOfControl.lua:67:6");
    local f = EnsureHolder()
    if not f then Perfy_Trace(Perfy_GetTime(), "Leave", "Refresh MyCustomFrames/LossOfControl.lua:67:6"); return end
    if not (C_LossOfControl and C_LossOfControl.GetActiveLossOfControlDataCount
        and C_LossOfControl.GetActiveLossOfControlData) then
        f:Hide()
        Perfy_Trace(Perfy_GetTime(), "Leave", "Refresh MyCustomFrames/LossOfControl.lua:67:6"); return
    end

    if testMode then
        f.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        f.cd:SetCooldown(GetTime(), 6)
        f:Show()
        Perfy_Trace(Perfy_GetTime(), "Leave", "Refresh MyCustomFrames/LossOfControl.lua:67:6"); return
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
            Perfy_Trace(Perfy_GetTime(), "Leave", "Refresh MyCustomFrames/LossOfControl.lua:67:6"); return
        end
    end
    f:Hide()
Perfy_Trace(Perfy_GetTime(), "Leave", "Refresh MyCustomFrames/LossOfControl.lua:67:6"); end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self) Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/LossOfControl.lua:102:32");
    self:UnregisterAllEvents()
    C_Timer.After(1, function() Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/LossOfControl.lua:104:21");
        local watcher = CreateFrame("Frame")
        watcher:RegisterEvent("LOSS_OF_CONTROL_UPDATE")
        watcher:SetScript("OnEvent", Refresh)
        -- Red de seguridad (2026-07-27, mismo patron que el resto del addon
        -- este sesion): un vencimiento NATURAL sin ningun cambio de estado
        -- puede no disparar el evento de nuevo -- el ticker se asegura de
        -- ocultar el icono poco despues igual.
        C_Timer.NewTicker(0.3, ns.Prof.Wrap("LossOfControl: 0.3s", Refresh))
        Refresh()
    Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/LossOfControl.lua:104:21"); end)
Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/LossOfControl.lua:102:32"); end)

-- Expuesto en ns (2026-07-27) para el boton "Preview" de Options.lua. Devuelve
-- el estado NUEVO, que el boton usa para quedar marcado mientras este activo.
function ns.ToggleLossOfControlTest() Perfy_Trace(Perfy_GetTime(), "Enter", "ns.ToggleLossOfControlTest MyCustomFrames/LossOfControl.lua:119:0");
    testMode = not testMode
    Refresh()
    Perfy_Trace(Perfy_GetTime(), "Leave", "ns.ToggleLossOfControlTest MyCustomFrames/LossOfControl.lua:119:0"); return testMode
end

SLASH_MCFLOCTEST1 = "/mcfloctest"
SlashCmdList["MCFLOCTEST"] = function() Perfy_Trace(Perfy_GetTime(), "Enter", "SlashCmdList.MCFLOCTEST MyCustomFrames/LossOfControl.lua:126:29");
    print("|cff00ff00[MCF Loss of Control test]|r " .. (ns.ToggleLossOfControlTest() and "ON" or "off"))
Perfy_Trace(Perfy_GetTime(), "Leave", "SlashCmdList.MCFLOCTEST MyCustomFrames/LossOfControl.lua:126:29"); end

Perfy_Trace(Perfy_GetTime(), "Leave", "(main chunk) MyCustomFrames/LossOfControl.lua");