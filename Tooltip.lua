--[[Perfy has instrumented this file]] local Perfy_GetTime, Perfy_Trace, Perfy_Trace_Passthrough = Perfy_GetTime, Perfy_Trace, Perfy_Trace_Passthrough; Perfy_Trace(Perfy_GetTime(), "Enter", "(main chunk) MyCustomFrames/Tooltip.lua"); -- ==========================================================================
-- MyCustomFrames - Tooltip.lua
-- Reskin de los tooltips NATIVOS de Blizzard estilo AzeriteUI -- portado de
-- AzeriteUI5_JuNNeZ_Edition/Components/Misc/Tooltips.lua.
--
-- FIX 2026-07-19 (v3): v1 (frame hijo) y v2 (backdrop directo en el tooltip)
-- no se veian, SIN error visible. Leyendo el codigo REAL de AzeriteUI
-- (Components/Misc/Tooltips.lua linea ~256) encontramos la causa: en este
-- cliente (Midnight, "secret values"), SetBackdrop puede fallar
-- SILENCIOSAMENTE si el motor interno del backdrop (OnBackdropSizeChanged /
-- ApplyBackdrop / SetupTextureCoordinates) intenta operar sobre dimensiones
-- del frame que resultan ser secretas -- SIN pcall ahi, el error se traga y
-- no pasa nada (ni se aplica el backdrop, ni se ve un error). AzeriteUI
-- parchea esos 3 metodos del frame hijo para envolverlos en pcall ANTES de
-- pedirle que dibuje nada. v3 replica eso exactamente.
-- ==========================================================================
local ADDON, ns = ...

local A = ns.ASSETS
-- Funcion, no local fijo (2026-07-24, pedido del usuario: "border-tooltip
-- tambien reskineable"): se resuelve contra la skin ACTIVA en cada llamada,
-- mismo patron que ClassPower.lua/Raid.lua/MirrorTimers.lua -- un local
-- horneado una sola vez al cargar el archivo nunca se enteraba de un cambio
-- de skin.
local function BorderTex() Perfy_Trace(Perfy_GetTime(), "Enter", "BorderTex MyCustomFrames/Tooltip.lua:25:6");
    return Perfy_Trace_Passthrough("Leave", "BorderTex MyCustomFrames/Tooltip.lua:25:6", (ns.SkinResolve and ns.SkinResolve("border-tooltip.tga")) or (A .. "border-tooltip.tga"))
end
local BG_TEX = "Interface\\Tooltips\\UI-Tooltip-Background"   -- textura propia de Blizzard, reusada (igual que AzeriteUI)

local function TooltipDefaults() Perfy_Trace(Perfy_GetTime(), "Enter", "TooltipDefaults MyCustomFrames/Tooltip.lua:30:6");
    return Perfy_Trace_Passthrough("Leave", "TooltipDefaults MyCustomFrames/Tooltip.lua:30:6", {
        enabled = true,
        scale = 1,
        backdropColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.95 },
        borderColor = { r = 1, g = 1, b = 1, a = 1 },
    })
end
ns.TooltipDefaults = TooltipDefaults

local function P() Perfy_Trace(Perfy_GetTime(), "Enter", "P MyCustomFrames/Tooltip.lua:40:6");
    local db = ns.GetDB and ns.GetDB()
    return Perfy_Trace_Passthrough("Leave", "P MyCustomFrames/Tooltip.lua:40:6", db and db.tooltip)
end

-- Tabla REUSADA (no una nueva por llamada) pero con edgeFile refrescado en
-- cada ApplySkin -- ver BorderTex() arriba: la skin activa puede cambiar en
-- vivo, y SetBackdrop lee esta tabla en el momento de la llamada.
local BACKDROP = {
    bgFile = BG_TEX,
    edgeFile = nil,   -- se completa en ApplySkin con BorderTex()
    edgeSize = 32,
    tile = true,
    insets = { left = 8, right = 8, top = 16, bottom = 16 },
}
-- Insets del FRAME hijo respecto del tooltip (calcados de AzeriteUI
-- Layouts/Data/Tooltips.lua backdropStyle.offsetLeft/Right/Top/Bottom).
local OFF_LEFT, OFF_RIGHT, OFF_TOP, OFF_BOTTOM = -10, 10, 18, -18

-- Frame invisible reusado como "papelera" para parentear el NineSlice nativo
-- de Blizzard (mismo truco que ns.Hider de AzeriteUI: un frame padre oculto
-- desconecta la textura de la jerarquia visible sin destruirla).
local UIHider = CreateFrame("Frame")
UIHider:Hide()

-- Cache de frames hijo de backdrop por tooltip (clave debil: si el tooltip
-- se destruye, el hijo se recolecta solo). Parchea los 3 metodos que en este
-- cliente pueden recibir dimensiones secretas -- SIN esto, SetBackdrop podia
-- fallar en silencio (ver nota arriba).
local Backdrops = setmetatable({}, {
    __index = function(t, tooltip) Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/Tooltip.lua:70:14");
        local bg = CreateFrame("Frame", nil, tooltip, "BackdropTemplate")
        bg:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 0, 0)
        bg:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", 0, 0)
        if bg.EnableMouse then bg:EnableMouse(false) end
        pcall(bg.SetFrameLevel, bg, tooltip:GetFrameLevel())

        for _, methodName in ipairs({ "OnBackdropSizeChanged", "ApplyBackdrop", "SetupTextureCoordinates" }) do
            local original = bg[methodName]
            if original then
                bg[methodName] = function(self, ...) Perfy_Trace(Perfy_GetTime(), "Enter", "bg.? MyCustomFrames/Tooltip.lua:80:33"); pcall(original, self, ...) Perfy_Trace(Perfy_GetTime(), "Leave", "bg.? MyCustomFrames/Tooltip.lua:80:33"); end
            end
        end

        hooksecurefunc(tooltip, "SetFrameLevel", function(self) Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/Tooltip.lua:84:49");
            pcall(bg.SetFrameLevel, bg, self:GetFrameLevel())
        Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/Tooltip.lua:84:49"); end)

        rawset(t, tooltip, bg)
        Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/Tooltip.lua:70:14"); return bg
    end,
})

local function ApplySkin(tooltip) Perfy_Trace(Perfy_GetTime(), "Enter", "ApplySkin MyCustomFrames/Tooltip.lua:93:6");
    if not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then Perfy_Trace(Perfy_GetTime(), "Leave", "ApplySkin MyCustomFrames/Tooltip.lua:93:6"); return end
    local p = P()
    if not p or not p.enabled then Perfy_Trace(Perfy_GetTime(), "Leave", "ApplySkin MyCustomFrames/Tooltip.lua:93:6"); return end

    pcall(tooltip.DisableDrawLayer, tooltip, "BACKGROUND")
    pcall(tooltip.DisableDrawLayer, tooltip, "BORDER")
    if tooltip.NineSlice and tooltip.NineSlice.GetParent and tooltip.NineSlice:GetParent() ~= UIHider then
        tooltip.NineSlice:SetParent(UIHider)
    end

    local bg = Backdrops[tooltip]
    BACKDROP.edgeFile = BorderTex()   -- skin activa (puede haber cambiado desde la ultima vez)
    local ok = pcall(function() Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/Tooltip.lua:106:21");
        bg:SetBackdrop(nil)
        bg:SetBackdrop(BACKDROP)
        bg:ClearAllPoints()
        bg:SetPoint("LEFT", OFF_LEFT, 0)
        bg:SetPoint("RIGHT", OFF_RIGHT, 0)
        bg:SetPoint("TOP", 0, OFF_TOP)
        bg:SetPoint("BOTTOM", 0, OFF_BOTTOM)
        local bgc, bc = p.backdropColor, p.borderColor
        bg:SetBackdropColor(bgc.r, bgc.g, bgc.b, bgc.a)
        bg:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a)
    Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/Tooltip.lua:106:21"); end)
    if ok and not bg:IsShown() then bg:Show() end
    pcall(tooltip.SetScale, tooltip, p.scale or 1)
Perfy_Trace(Perfy_GetTime(), "Leave", "ApplySkin MyCustomFrames/Tooltip.lua:93:6"); end

-- Lista fija de tooltips "shared" conocidos (misma lista que AzeriteUI usa en
-- UpdateTooltipThemes) + reaplicado en CADA evento de contenido, porque
-- Blizzard reescribe su propio backdrop nativo en esos eventos, no solo al
-- mostrarse la primera vez.
local TOOLTIPS = {
    "GameTooltip", "ItemRefTooltip", "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2",
    "ShoppingTooltip1", "ShoppingTooltip2", "FriendsTooltip", "WarCampaignTooltip",
    "EmbeddedItemTooltip", "ReputationParagonTooltip", "QuickKeybindTooltip",
}
local CONTENT_EVENTS = { "OnShow", "OnTooltipSetItem", "OnTooltipSetUnit", "OnTooltipSetSpell" }

local hookedTooltips = {}
local function HookTooltip(tt) Perfy_Trace(Perfy_GetTime(), "Enter", "HookTooltip MyCustomFrames/Tooltip.lua:134:6");
    if not tt or hookedTooltips[tt] or not tt.HookScript then Perfy_Trace(Perfy_GetTime(), "Leave", "HookTooltip MyCustomFrames/Tooltip.lua:134:6"); return end
    hookedTooltips[tt] = true
    for _, ev in ipairs(CONTENT_EVENTS) do
        pcall(tt.HookScript, tt, ev, function() Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/Tooltip.lua:138:37"); ApplySkin(tt) Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/Tooltip.lua:138:37"); end)
    end
Perfy_Trace(Perfy_GetTime(), "Leave", "HookTooltip MyCustomFrames/Tooltip.lua:134:6"); end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function() Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/Tooltip.lua:144:31");
    for _, name in ipairs(TOOLTIPS) do HookTooltip(_G[name]) end
Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/Tooltip.lua:144:31"); end)

if SharedTooltip_SetBackdropStyle then
    hooksecurefunc("SharedTooltip_SetBackdropStyle", ApplySkin)
end

-- Reaplica a todos los tooltips ya skineados (scale/color en vivo desde el
-- slash command), sin esperar al proximo hover.
ns.RefreshTooltipSkin = function() Perfy_Trace(Perfy_GetTime(), "Enter", "ns.RefreshTooltipSkin MyCustomFrames/Tooltip.lua:154:24");
    for tooltip in pairs(hookedTooltips) do ApplySkin(tooltip) end
Perfy_Trace(Perfy_GetTime(), "Leave", "ns.RefreshTooltipSkin MyCustomFrames/Tooltip.lua:154:24"); end

SLASH_MCFTOOLTIP1 = "/mcftooltip"
SlashCmdList["MCFTOOLTIP"] = function(msg) Perfy_Trace(Perfy_GetTime(), "Enter", "SlashCmdList.MCFTOOLTIP MyCustomFrames/Tooltip.lua:159:29");
    local p = P()
    if not p then Perfy_Trace(Perfy_GetTime(), "Leave", "SlashCmdList.MCFTOOLTIP MyCustomFrames/Tooltip.lua:159:29"); return end
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "scale" and tonumber(arg) then
        p.scale = math.max(0.5, math.min(2, tonumber(arg)))
        ns.RefreshTooltipSkin()
        print("|cffffe19bMyCustomFrames|r: tooltip scale = " .. p.scale)
    elseif cmd == "toggle" or cmd == "" then
        p.enabled = not p.enabled
        print("|cffffe19bMyCustomFrames|r: tooltip skin " .. (p.enabled and "ON" or "OFF (reload para restaurar el look nativo)"))
    else
        print("|cffffe19bMyCustomFrames|r: /mcftooltip toggle | /mcftooltip scale <0.5-2>")
    end
Perfy_Trace(Perfy_GetTime(), "Leave", "SlashCmdList.MCFTOOLTIP MyCustomFrames/Tooltip.lua:159:29"); end

Perfy_Trace(Perfy_GetTime(), "Leave", "(main chunk) MyCustomFrames/Tooltip.lua");