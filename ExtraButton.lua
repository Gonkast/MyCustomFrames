--[[Perfy has instrumented this file]] local Perfy_GetTime, Perfy_Trace, Perfy_Trace_Passthrough = Perfy_GetTime, Perfy_Trace, Perfy_Trace_Passthrough; Perfy_Trace(Perfy_GetTime(), "Enter", "(main chunk) MyCustomFrames/ExtraButton.lua"); -- ==========================================================================
-- MyCustomFrames - ExtraButton.lua
-- Reskin del boton NATIVO de "Extra Action" (ExtraActionButton1 -- el boton
-- grande que aparece durante mecanicas de boss/quests) estilo AzeriteUI:
-- icono redondo enmascarado + borde circular. Portado de
-- AzeriteUI5_JuNNeZ_Edition/Components/ActionBars/Elements/ExtraButtons.lua,
-- simplificado (sin ns.Widgets.RegisterCooldown -- usamos el numero de cuenta
-- regresiva NATIVO del widget Cooldown, mismo patron que el fix de auras de
-- nameplate de hoy: es secret-safe porque lo calcula el motor en C).
-- Standalone, no reemplaza el boton -- solo lo reviste, igual que
-- Nameplates.lua/Minimap.lua.
-- ==========================================================================
local ADDON, ns = ...

local A = ns.ASSETS
local MASK_TEX = A .. "actionbutton-mask-circular.tga"
local BORDER_TEX = A .. "actionbutton-border.tga"

local function ExtraButtonDefaults() Perfy_Trace(Perfy_GetTime(), "Enter", "ExtraButtonDefaults MyCustomFrames/ExtraButton.lua:19:6");
    return Perfy_Trace_Passthrough("Leave", "ExtraButtonDefaults MyCustomFrames/ExtraButton.lua:19:6", {
        enabled = true,
        size = 64,
        borderScale = 1.25,
        borderColor = { r = 192 / 255, g = 192 / 255, b = 192 / 255, a = 1 },
    })
end
ns.ExtraButtonDefaults = ExtraButtonDefaults

local function P() Perfy_Trace(Perfy_GetTime(), "Enter", "P MyCustomFrames/ExtraButton.lua:29:6");
    local db = ns.GetDB and ns.GetDB()
    return Perfy_Trace_Passthrough("Leave", "P MyCustomFrames/ExtraButton.lua:29:6", db and db.extrabutton)
end

local styledButtons = setmetatable({}, { __mode = "k" })

local function StyleButton(button) Perfy_Trace(Perfy_GetTime(), "Enter", "StyleButton MyCustomFrames/ExtraButton.lua:36:6");
    if not button or button.mcfStyled then Perfy_Trace(Perfy_GetTime(), "Leave", "StyleButton MyCustomFrames/ExtraButton.lua:36:6"); return end
    button.mcfStyled = true
    styledButtons[button] = true

    -- Apaga las texturas nativas (fondo cuadrado, normal/pushed/checked) --
    -- con hooksecurefunc para que Blizzard no pueda volver a mostrarlas en
    -- una actualizacion posterior (mismo patron que AzeriteUI).
    local icon = button.icon or button.Icon
    if icon then icon:SetAlpha(0) end
    if button.NormalTexture then button.NormalTexture:SetAlpha(0) end
    if button.Flash then button.Flash:SetTexture(nil) end
    if button.style then button.style:SetAlpha(0) end
    if button.SpellActivationAlert then button.SpellActivationAlert:SetAlpha(0) end

    if button.SetNormalTexture then
        if button:GetNormalTexture() then button:GetNormalTexture():SetTexture(nil) end
        hooksecurefunc(button, "SetNormalTexture", function(b, tex) Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/ExtraButton.lua:53:51"); if tex ~= "" then b:SetNormalTexture("") end Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/ExtraButton.lua:53:51"); end)
    end
    if button.SetHighlightTexture then
        if button:GetHighlightTexture() then button:GetHighlightTexture():SetTexture(nil) end
    end
    if button.SetPushedTexture then
        if button:GetPushedTexture() then button:GetPushedTexture():SetTexture(nil) end
        hooksecurefunc(button, "SetPushedTexture", function(b, tex) Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/ExtraButton.lua:60:51"); if tex ~= "" then b:SetPushedTexture("") end Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/ExtraButton.lua:60:51"); end)
    end

    local p = P() or ExtraButtonDefaults()
    button:SetSize(p.size, p.size)

    -- Overlay: aloja borde/cooldown/count/keybind por encima de todo.
    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetFrameLevel(button:GetFrameLevel() + 3)
    overlay:SetAllPoints()
    button.mcfOverlay = overlay

    -- Icono propio, enmascarado en circulo -- refleja lo que Blizzard ponga
    -- en el icono original via hook (nunca leemos/mutamos datos de spell,
    -- solo espejamos la textura que Blizzard ya decidio mostrar).
    local newIcon = button:CreateTexture(nil, "BACKGROUND", nil, 1)
    newIcon:SetPoint("CENTER", 0, 0)
    newIcon:SetSize(p.size * 0.6875, p.size * 0.6875)   -- 44/64 = proporcion de AzeriteUI
    if newIcon.SetMask then newIcon:SetMask(MASK_TEX) end
    button.mcfIcon = newIcon
    if icon then
        local function SyncIcon() Perfy_Trace(Perfy_GetTime(), "Enter", "SyncIcon MyCustomFrames/ExtraButton.lua:81:14"); pcall(newIcon.SetTexture, newIcon, icon:GetTexture()) Perfy_Trace(Perfy_GetTime(), "Leave", "SyncIcon MyCustomFrames/ExtraButton.lua:81:14"); end
        SyncIcon()
        hooksecurefunc(icon, "SetTexture", SyncIcon)
        hooksecurefunc(icon, "Show", SyncIcon)
    end

    -- Borde decorativo (misma textura que ya usan las auras de esta unitframe
    -- -- actionbutton-border.tga, ya copiada en Assets). El 2.1x que usa
    -- AzeriteUI es para SU PROPIA textura de borde (proporcion distinta) --
    -- con esta (un marco hexagonal que ya calza ajustado al icono) queda
    -- gigante -- pedido del usuario "el borde esta muy grande en
    -- comparacion". borderScale es configurable.
    local border = overlay:CreateTexture(nil, "BORDER", nil, 1)
    border:SetPoint("CENTER", 0, 0)
    local bs = p.borderScale or 1.25
    border:SetSize(p.size * bs, p.size * bs)
    border:SetTexture(BORDER_TEX)
    local bc = p.borderColor
    border:SetVertexColor(bc.r, bc.g, bc.b, bc.a)
    button.mcfBorder = border

    -- Cooldown: swipe con la MISMA mascara circular (secret-safe via el
    -- widget nativo, no leemos expirationTime/duration crudos), numero de
    -- cuenta regresiva NATIVO habilitado (igual que las auras de nameplate).
    local cd = button.cooldown or button.Cooldown
    if cd then
        cd:SetFrameLevel(button:GetFrameLevel() + 1)
        cd:ClearAllPoints()
        cd:SetPoint("CENTER", 0, 0)
        cd:SetSize(p.size * 0.6875, p.size * 0.6875)
        pcall(cd.SetSwipeTexture, cd, MASK_TEX)
        pcall(cd.SetDrawBling, cd, false)
        pcall(cd.SetDrawEdge, cd, false)
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
    end

    -- Keybind/count nativos: solo reancla (Blizzard ya los actualiza solo).
    if button.HotKey then
        button.HotKey:SetParent(overlay)
        button.HotKey:ClearAllPoints()
        button.HotKey:SetPoint("TOPLEFT", button, "TOPLEFT", -10, -5)
    end
    if button.Count then
        button.Count:SetParent(overlay)
        button.Count:ClearAllPoints()
        button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    end
Perfy_Trace(Perfy_GetTime(), "Leave", "StyleButton MyCustomFrames/ExtraButton.lua:36:6"); end

-- ZoneAbilityFrame = el mismo tipo de boton grande, pero para habilidades de
-- ZONA (escenarios/questlines con "Restless Heart" etc, ver el Frame Stack
-- que pego el usuario: ZoneAbilityFrame.SpellButtonContainer). Blizzard crea
-- estos botones de forma DINAMICA (EnumerateActive), a diferencia de
-- ExtraActionButton1 que siempre existe -- hay que hookear
-- UpdateDisplayedZoneAbilities para agarrar los nuevos a medida que aparecen.
local function StyleZoneButtons() Perfy_Trace(Perfy_GetTime(), "Enter", "StyleZoneButtons MyCustomFrames/ExtraButton.lua:136:6");
    local p = P()
    if not p or not p.enabled then Perfy_Trace(Perfy_GetTime(), "Leave", "StyleZoneButtons MyCustomFrames/ExtraButton.lua:136:6"); return end
    local frame = _G.ZoneAbilityFrame
    if not frame then Perfy_Trace(Perfy_GetTime(), "Leave", "StyleZoneButtons MyCustomFrames/ExtraButton.lua:136:6"); return end
    if frame.Style then frame.Style:SetAlpha(0) end
    if frame.SpellButtonContainer and frame.SpellButtonContainer.EnumerateActive then
        for button in frame.SpellButtonContainer:EnumerateActive() do
            if button then StyleButton(button) end
        end
    end
Perfy_Trace(Perfy_GetTime(), "Leave", "StyleZoneButtons MyCustomFrames/ExtraButton.lua:136:6"); end

local function StyleAll() Perfy_Trace(Perfy_GetTime(), "Enter", "StyleAll MyCustomFrames/ExtraButton.lua:149:6");
    local p = P()
    if not p or not p.enabled then Perfy_Trace(Perfy_GetTime(), "Leave", "StyleAll MyCustomFrames/ExtraButton.lua:149:6"); return end
    StyleButton(_G.ExtraActionButton1)
    StyleZoneButtons()
Perfy_Trace(Perfy_GetTime(), "Leave", "StyleAll MyCustomFrames/ExtraButton.lua:149:6"); end

local zoneHooked = false
local function HookZoneAbilityFrame() Perfy_Trace(Perfy_GetTime(), "Enter", "HookZoneAbilityFrame MyCustomFrames/ExtraButton.lua:157:6");
    if zoneHooked or not _G.ZoneAbilityFrame then Perfy_Trace(Perfy_GetTime(), "Leave", "HookZoneAbilityFrame MyCustomFrames/ExtraButton.lua:157:6"); return end
    zoneHooked = true
    hooksecurefunc(_G.ZoneAbilityFrame, "UpdateDisplayedZoneAbilities", StyleZoneButtons)
    StyleZoneButtons()
Perfy_Trace(Perfy_GetTime(), "Leave", "HookZoneAbilityFrame MyCustomFrames/ExtraButton.lua:157:6"); end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
-- Blizzard_ZoneAbility es un addon de carga DIFERIDA (solo se carga cuando
-- una zona/escenario realmente tiene una zone ability que mostrar) -- no
-- podemos asumir que ZoneAbilityFrame ya existe al login, hay que escuchar
-- ADDON_LOADED y engancharlo apenas aparezca.
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, event, addon) Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/ExtraButton.lua:172:23");
    if event == "ADDON_LOADED" then
        if addon == "Blizzard_ZoneAbility" then HookZoneAbilityFrame() end
        Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/ExtraButton.lua:172:23"); return
    end
    StyleAll()
    HookZoneAbilityFrame()
Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/ExtraButton.lua:172:23"); end)
if _G.ExtraActionBarFrame then
    hooksecurefunc(_G.ExtraActionBarFrame, "Show", StyleAll)
end

-- Reaplica tamaño/color de borde en vivo (slash command) a los botones ya
-- estilizados, sin esperar a que vuelvan a aparecer.
ns.RefreshExtraButtonSkin = function() Perfy_Trace(Perfy_GetTime(), "Enter", "ns.RefreshExtraButtonSkin MyCustomFrames/ExtraButton.lua:186:28");
    local p = P()
    if not p then Perfy_Trace(Perfy_GetTime(), "Leave", "ns.RefreshExtraButtonSkin MyCustomFrames/ExtraButton.lua:186:28"); return end
    for button in pairs(styledButtons) do
        if button.mcfBorder then
            local bs = p.borderScale or 1.25
            button.mcfBorder:SetSize(p.size * bs, p.size * bs)
            local bc = p.borderColor
            button.mcfBorder:SetVertexColor(bc.r, bc.g, bc.b, bc.a)
        end
    end
Perfy_Trace(Perfy_GetTime(), "Leave", "ns.RefreshExtraButtonSkin MyCustomFrames/ExtraButton.lua:186:28"); end

SLASH_MCFEXTRABTN1 = "/mcfextrabtn"
SlashCmdList["MCFEXTRABTN"] = function(msg) Perfy_Trace(Perfy_GetTime(), "Enter", "SlashCmdList.MCFEXTRABTN MyCustomFrames/ExtraButton.lua:200:30");
    local p = P()
    if not p then Perfy_Trace(Perfy_GetTime(), "Leave", "SlashCmdList.MCFEXTRABTN MyCustomFrames/ExtraButton.lua:200:30"); return end
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "border" and tonumber(arg) then
        p.borderScale = math.max(0.5, math.min(3, tonumber(arg)))
        ns.RefreshExtraButtonSkin()
        print("|cffffe19bMyCustomFrames|r: extra button border scale = " .. p.borderScale)
    else
        print("|cffffe19bMyCustomFrames|r: /mcfextrabtn border <0.5-3> (actual: " .. (p.borderScale or 1.25) .. ")")
    end
Perfy_Trace(Perfy_GetTime(), "Leave", "SlashCmdList.MCFEXTRABTN MyCustomFrames/ExtraButton.lua:200:30"); end
HookZoneAbilityFrame()

Perfy_Trace(Perfy_GetTime(), "Leave", "(main chunk) MyCustomFrames/ExtraButton.lua");