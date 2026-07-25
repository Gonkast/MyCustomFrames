-- ==========================================================================
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
local BORDER_TEX = A .. "border-tooltip.tga"
local BG_TEX = "Interface\\Tooltips\\UI-Tooltip-Background"   -- textura propia de Blizzard, reusada (igual que AzeriteUI)

local function TooltipDefaults()
    return {
        enabled = true,
        scale = 1,
        backdropColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.95 },
        borderColor = { r = 1, g = 1, b = 1, a = 1 },
    }
end
ns.TooltipDefaults = TooltipDefaults

local function P()
    local db = ns.GetDB and ns.GetDB()
    return db and db.tooltip
end

local BACKDROP = {
    bgFile = BG_TEX,
    edgeFile = BORDER_TEX,
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
    __index = function(t, tooltip)
        local bg = CreateFrame("Frame", nil, tooltip, "BackdropTemplate")
        bg:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 0, 0)
        bg:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", 0, 0)
        if bg.EnableMouse then bg:EnableMouse(false) end
        pcall(bg.SetFrameLevel, bg, tooltip:GetFrameLevel())

        for _, methodName in ipairs({ "OnBackdropSizeChanged", "ApplyBackdrop", "SetupTextureCoordinates" }) do
            local original = bg[methodName]
            if original then
                bg[methodName] = function(self, ...) pcall(original, self, ...) end
            end
        end

        hooksecurefunc(tooltip, "SetFrameLevel", function(self)
            pcall(bg.SetFrameLevel, bg, self:GetFrameLevel())
        end)

        rawset(t, tooltip, bg)
        return bg
    end,
})

local function ApplySkin(tooltip)
    if not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
    local p = P()
    if not p or not p.enabled then return end

    pcall(tooltip.DisableDrawLayer, tooltip, "BACKGROUND")
    pcall(tooltip.DisableDrawLayer, tooltip, "BORDER")
    if tooltip.NineSlice and tooltip.NineSlice.GetParent and tooltip.NineSlice:GetParent() ~= UIHider then
        tooltip.NineSlice:SetParent(UIHider)
    end

    local bg = Backdrops[tooltip]
    local ok = pcall(function()
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
    end)
    if ok and not bg:IsShown() then bg:Show() end
    pcall(tooltip.SetScale, tooltip, p.scale or 1)
end

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
local function HookTooltip(tt)
    if not tt or hookedTooltips[tt] or not tt.HookScript then return end
    hookedTooltips[tt] = true
    for _, ev in ipairs(CONTENT_EVENTS) do
        pcall(tt.HookScript, tt, ev, function() ApplySkin(tt) end)
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function()
    for _, name in ipairs(TOOLTIPS) do HookTooltip(_G[name]) end
end)

if SharedTooltip_SetBackdropStyle then
    hooksecurefunc("SharedTooltip_SetBackdropStyle", ApplySkin)
end

-- Reaplica a todos los tooltips ya skineados (scale/color en vivo desde el
-- slash command), sin esperar al proximo hover.
ns.RefreshTooltipSkin = function()
    for tooltip in pairs(hookedTooltips) do ApplySkin(tooltip) end
end

SLASH_MCFTOOLTIP1 = "/mcftooltip"
SlashCmdList["MCFTOOLTIP"] = function(msg)
    local p = P()
    if not p then return end
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
end
