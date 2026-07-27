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
    f:SetSize(22, 22)
    f:SetPoint("CENTER", portrait.root, "CENTER", 18, -18)
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

local function Refresh()
    local f = EnsureHolder()
    if not f then return end
    if not (C_LossOfControl and C_LossOfControl.GetActiveLossOfControlDataCount
        and C_LossOfControl.GetActiveLossOfControlData) then
        f:Hide()
        return
    end

    if testMode then
        f.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        f.cd:SetCooldown(GetTime(), 6)
        f:Show()
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
            return
        end
    end
    f:Hide()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    C_Timer.After(1, function()
        local watcher = CreateFrame("Frame")
        watcher:RegisterEvent("LOSS_OF_CONTROL_UPDATE")
        watcher:SetScript("OnEvent", Refresh)
        -- Red de seguridad (2026-07-27, mismo patron que el resto del addon
        -- este sesion): un vencimiento NATURAL sin ningun cambio de estado
        -- puede no disparar el evento de nuevo -- el ticker se asegura de
        -- ocultar el icono poco despues igual.
        C_Timer.NewTicker(0.3, Refresh)
        Refresh()
    end)
end)

SLASH_MCFLOCTEST1 = "/mcfloctest"
SlashCmdList["MCFLOCTEST"] = function()
    testMode = not testMode
    print("|cff00ff00[MCF Loss of Control test]|r " .. (testMode and "ON" or "off"))
    Refresh()
end
