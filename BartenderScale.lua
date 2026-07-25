-- ==========================================================================
-- MyCustomFrames - BartenderScale.lua
-- Aplica ns.ResScale() (mismo auto-scale por resolucion/tamaño de ventana que
-- ya usan Units/Portraits/Auras/InfoBar/etc, ver core.lua) a las barras de
-- accion de Bartender4 (BT4Bar1-10), MULTIPLICANDO sobre la escala que el
-- USUARIO ya le configuro a cada barra en Bartender4 -- nunca la pisa.
--
-- Pedido del usuario (2026-07-24): mismo problema que el resto del addon
-- (offset fijo en pixeles se desproporciona si cambia la resolucion, ver
-- ns.ResScale en core.lua), pero para Bartender4 en vez de frames propios.
-- Bartender4 gestiona sus barras con SetPoint/SetScale desde su PROPIO
-- perfil (AceDB) -- a diferencia del ObjectiveTrackerFrame de Blizzard (Edit
-- Mode, revertido en este mismo commit set por REPOSICIONARSE con su propia
-- logica en cada cambio de resolucion, no un offset fijo), Bartender4 NO
-- tiene un sistema activo que reposicione sus barras solo -- su anchor
-- offset SI es constante hasta que el usuario lo cambia a mano, igual que
-- cualquier frame propio de este addon. Mismo principio ya validado: SetScale
-- escala PROPORCIONALMENTE tanto tamaño como distancia al anchor -- no hace
-- falta timing tocar el SetPoint de Bartender4 para nada.
--
-- Guard de reentrancia + hooksecurefunc (mismo patron ya usado en el intento
-- de Tracker.lua) por si el usuario cambia el slider de escala de una barra
-- DESDE Bartender4 en vivo -- se reinterpreta como la nueva escala BASE y se
-- reaplica base*rs encima, sin pisar la eleccion del usuario.
--
-- SEGURIDAD: SetScale sobre una barra con botones de accion activos puede
-- estar protegido/dar ADDON_ACTION_BLOCKED en combate igual que SetPoint (ver
-- BarReposition.lua, mismo caso real con BT4Bar5) -- todo pcall + diferido a
-- PLAYER_REGEN_ENABLED si esta en combate.
-- ==========================================================================
local ADDON, ns = ...

local BT4_BARS = {}
for i = 1, 10 do BT4_BARS[i] = "BT4Bar" .. i end
-- Modulos con nombre propio (no numerados como BT4Bar1-10): pet/stance/bag bar,
-- barra de reputacion/experiencia, micro menu propio de Bartender4.
for _, name in ipairs({ "BT4PetBar", "BT4StanceBar", "BT4BagBar", "BT4RepBar", "BT4XPBar", "BT4MicroMenu" }) do
    BT4_BARS[#BT4_BARS + 1] = name
end

local baseScale = {}      -- [barName] = escala BASE de Bartender4 (sin nuestro rs)
local applying = {}       -- [barName] = true mientras nosotros mismos llamamos SetScale
local hooked = {}         -- [barName] = true una vez enganchado el hook

local ApplyBarScale, HookBarScale

HookBarScale = function(name, bar)
    if hooked[name] then return end
    hooked[name] = true
    hooksecurefunc(bar, "SetScale", function(self, s)
        if applying[name] or not s then return end
        local rs = ns.ResScale and ns.ResScale() or 1
        if rs <= 0 then return end
        local newBase = s / rs
        if not baseScale[name] or math.abs(newBase - baseScale[name]) > 0.001 then
            baseScale[name] = newBase
            ApplyBarScale(name)
        end
    end)
end

ApplyBarScale = function(name)
    local bar = _G[name]
    if not bar or not ns.ResScale then return end
    if InCombatLockdown() then return end   -- red de seguridad: reintenta en PLAYER_REGEN_ENABLED
    HookBarScale(name, bar)
    if not baseScale[name] then baseScale[name] = bar:GetScale() or 1 end
    applying[name] = true
    pcall(bar.SetScale, bar, baseScale[name] * ns.ResScale())
    applying[name] = false
end

local pendingApply = false
local function ApplyAllBarScales()
    if InCombatLockdown() then pendingApply = true; return end
    pendingApply = false
    for _, name in ipairs(BT4_BARS) do
        if _G[name] then ApplyBarScale(name) end
    end
end
ns.RefreshBartenderScale = ApplyAllBarScales

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingApply then ApplyAllBarScales() end
        return
    end
    ApplyAllBarScales()
end)

-- DIAGNOSTICO: /mcfbt4diag -- lista TODOS los frames globales cuyo nombre
-- empieza con "BT4" (nombres reales en este cliente, en vez de adivinar --
-- reportado 2026-07-24: "la pet bar no lo esta haciendo" / "y tampoco la de
-- bag" -- BT4PetBar/BT4BagBar/etc no existen con esos nombres exactos).
SLASH_MCFBT4DIAG1 = "/mcfbt4diag"
SlashCmdList["MCFBT4DIAG"] = function()
    local names = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and k:sub(1, 3) == "BT4" and type(v) == "table" and v.GetObjectType then
            names[#names + 1] = k
        end
    end
    table.sort(names)
    print("|cffffe19b[MCF]|r BT4 frames found (" .. #names .. "):")
    for _, n in ipairs(names) do print("  " .. n) end
end
