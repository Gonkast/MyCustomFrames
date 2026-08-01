--[[Perfy has instrumented this file]] local Perfy_GetTime, Perfy_Trace, Perfy_Trace_Passthrough = Perfy_GetTime, Perfy_Trace, Perfy_Trace_Passthrough; Perfy_Trace(Perfy_GetTime(), "Enter", "(main chunk) MyCustomFrames/TopWidget.lua"); -- ==========================================================================
-- MyCustomFrames - TopWidget.lua
-- Reposiciona/escala el widget TOP-CENTER nativo de Blizzard
-- (UIWidgetTopCenterContainerFrame -- barras de progreso de eventos de zona,
-- delves, invasiones, etc). Standalone, no le toca el arte -- mismo patron
-- que el "below minimap widget" de Minimap.lua (holder propio, el frame
-- nativo se reparenta a ese holder, sin contaminar nuestros propios frames).
-- Pedido del usuario 2026-07-23: "poder cambiar el tamaño y mover el Widget top".
-- ==========================================================================
local ADDON, ns = ...

local TOPWIDGET_KEY = "topwidget"
ns.TOPWIDGET_KEY = TOPWIDGET_KEY

local function TopWidgetDefaults() Perfy_Trace(Perfy_GetTime(), "Enter", "TopWidgetDefaults MyCustomFrames/TopWidget.lua:15:6");
    return Perfy_Trace_Passthrough("Leave", "TopWidgetDefaults MyCustomFrames/TopWidget.lua:15:6", {
        enabled = true,
        -- Mismo anclaje que usa Blizzard nativamente (confirmado contra
        -- Blizzard_UIWidgetTopCenterFrame.xml, fuente real via wow-ui-source):
        -- TOP, 0, -15 -- por default el widget queda exactamente donde
        -- Blizzard lo pone, sin ningun offset artistico nuestro.
        point = "TOP", relPoint = "TOP", offsetX = 0, offsetY = -15,
        anchor = "", scale = 0.70, strata = "MEDIUM",
    })
end
ns.TopWidgetDefaults = TopWidgetDefaults

local function P() Perfy_Trace(Perfy_GetTime(), "Enter", "P MyCustomFrames/TopWidget.lua:28:6");
    local db = ns.GetDB and ns.GetDB()
    return Perfy_Trace_Passthrough("Leave", "P MyCustomFrames/TopWidget.lua:28:6", db and db.topwidget)
end

local holder

local function Layout() Perfy_Trace(Perfy_GetTime(), "Enter", "Layout MyCustomFrames/TopWidget.lua:35:6");
    local p = P()
    if not p then Perfy_Trace(Perfy_GetTime(), "Leave", "Layout MyCustomFrames/TopWidget.lua:35:6"); return end
    local w = _G.UIWidgetTopCenterContainerFrame
    if not w then Perfy_Trace(Perfy_GetTime(), "Leave", "Layout MyCustomFrames/TopWidget.lua:35:6"); return end

    if not holder then
        holder = CreateFrame("Frame", nil, UIParent)
        ns.topWidgetHolder = holder
        holder:SetSize(300, 40)
        holder.editBG = ns.MakeEditHighlight(holder, "Top Widget")
        holder:SetMovable(true)
        holder:RegisterForDrag("LeftButton")
        holder:EnableMouse(ns.IsUnlocked() and true or false)
        holder:SetScript("OnDragStart", function(self) Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/TopWidget.lua:49:40");
            if ns.IsUnlocked() and not InCombatLockdown() then self:StartMoving() end
        Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/TopWidget.lua:49:40"); end)
        holder:SetScript("OnDragStop", function(self) Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/TopWidget.lua:52:39");
            self:StopMovingOrSizing()
            if ns.SnapFrameToGrid then ns.SnapFrameToGrid(self) end
            local pp = P()
            if pp then
                local point, _, relPoint, x, y = self:GetPoint(1)
                pp.point, pp.relPoint, pp.offsetX, pp.offsetY = point, relPoint, x, y
            end
            Layout()
            if ns.OnDragStopped then ns.OnDragStopped(TOPWIDGET_KEY) end
        Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/TopWidget.lua:52:39"); end)
        ns.AttachScaleWheel(holder, P, Layout)
    end

    if not p.enabled then
        holder:Hide()
        Perfy_Trace(Perfy_GetTime(), "Leave", "Layout MyCustomFrames/TopWidget.lua:35:6"); return
    end
    holder:Show()
    holder:SetFrameStrata(p.strata or "MEDIUM")
    -- FIX ("se reposiciona cuando escalo"): offsetX/offsetY se guardan en el
    -- espacio de coordenadas de ANTES de escalar -- sin compensar, cambiar
    -- scale corre visualmente el anchor. Mismo utilitario que ya usa InfoBar
    -- (InfoBarPlace: "reancla offset si la escala cambio").
    ns.CompensateScale(p, "simple")
    holder:SetScale((p.scale or 1) * ns.ResScale())

    local parent = _G[p.anchor]
    if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
    holder:ClearAllPoints()
    holder:SetPoint(p.point or "TOP", parent, p.relPoint or "TOP", p.offsetX or 0, p.offsetY or -12)

    local ok = pcall(function() Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/TopWidget.lua:84:21");
        w:SetParent(holder)
        w:ClearAllPoints()
        w:SetPoint("TOP", holder, "TOP", 0, 0)
    Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/TopWidget.lua:84:21"); end)
    if not ok then Perfy_Trace(Perfy_GetTime(), "Leave", "Layout MyCustomFrames/TopWidget.lua:35:6"); return end

    if not ns._topWidgetHooked then
        ns._topWidgetHooked = true
        -- Blizzard reposiciona/reancla este contenedor solo cuando entra/sale un
        -- widget (UIWidgetManager) -- reafirmar cuando eso pasa, mismo patron y
        -- guard anti-recursion que LayoutBelowMinimapWidget (Minimap.lua).
        local reasserting = false
        pcall(hooksecurefunc, w, "SetPoint", function() Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/TopWidget.lua:97:45");
            if reasserting or not holder then Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/TopWidget.lua:97:45"); return end
            reasserting = true
            Layout()
            reasserting = false
        Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/TopWidget.lua:97:45"); end)
    end
Perfy_Trace(Perfy_GetTime(), "Leave", "Layout MyCustomFrames/TopWidget.lua:35:6"); end
ns.RefreshTopWidget = Layout

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LOGIN")
-- El widget top-center puede aparecer/desaparecer con el contenido (eventos
-- de zona, delves) -- ADDON_LOADED de Blizzard_UIWidgets cubre el caso de
-- carga diferida, igual que ExtraButton.lua con Blizzard_ZoneAbility.
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, event, addon) Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/TopWidget.lua:114:23");
    if event == "ADDON_LOADED" and addon ~= "Blizzard_UIWidgets" then Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/TopWidget.lua:114:23"); return end
    Layout()
Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/TopWidget.lua:114:23"); end)
if _G.UIWidgetTopCenterContainerFrame then
    hooksecurefunc(_G.UIWidgetTopCenterContainerFrame, "Show", Layout)
end

Perfy_Trace(Perfy_GetTime(), "Leave", "(main chunk) MyCustomFrames/TopWidget.lua");