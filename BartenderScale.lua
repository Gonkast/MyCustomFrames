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
-- estar protegido/dar ADDON_ACTION_BLOCKED en combate igual que SetPoint --
-- todo pcall + diferido a PLAYER_REGEN_ENABLED si esta en combate.
-- ==========================================================================
local ADDON, ns = ...

local BT4_BARS = {}
for i = 1, 10 do BT4_BARS[i] = "BT4Bar" .. i end
-- Modulos con nombre propio (no numerados como BT4Bar1-10) -- nombres REALES
-- confirmados via /mcfbt4diag (2026-07-24, los adivinados "BT4PetBar" etc. no
-- existian; el prefijo real es "BT4Bar<Modulo>", no "BT4<Modulo>Bar").
for _, name in ipairs({ "BT4BarPetBar", "BT4BarStanceBar", "BT4BarBagBar", "BT4BarExtraActionBar" }) do
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
local UpdatePetBarVisibility   -- fwd-declarada (definida mas abajo)
local function ApplyAllBarScales()
    if InCombatLockdown() then pendingApply = true; return end
    pendingApply = false
    for _, name in ipairs(BT4_BARS) do
        if _G[name] then ApplyBarScale(name) end
    end
    -- FIX (2026-07-25, reportado: "el pet bar queda despues de entrar al lock
    -- mode, estando en explorer mode, sin tener pet"): al entrar/salir de Lock,
    -- SetUnlocked (Editing.lua) llama ns.ExplorerResetAll(), que hace
    -- SetAlpha(1) a TODOS los elementos del Explorer -- incluida la pet bar,
    -- deshaciendo el ocultado por "sin mascota". Justo despues corre
    -- ns.RefreshAll() -> esta funcion, asi que reaplicarlo aca lo corrige en el
    -- mismo tick (y de paso cubre cualquier otro camino que pase por RefreshAll).
    if UpdatePetBarVisibility then UpdatePetBarVisibility() end
end
ns.RefreshBartenderScale = ApplyAllBarScales

-- Pedido del usuario (2026-07-24): "la barra de pet, que desaparezca si no
-- existe pet" -- alpha+EnableMouse(false) (mismo criterio ya usado en
-- core.lua para frames nativos: SetAlpha nunca esta protegido, ni siquiera
-- en frames con botones de accion reales, a diferencia de Show/Hide).
-- _mcfCombatHidden se reusa (mismo flag que ya respeta el driver de
-- Explorer.lua) para que, si el usuario ADEMAS tiene "Pet Bar" prendido en
-- Explorer, este chequeo GANE -- sin pet, se queda oculta pase lo que pase
-- con mouseover/combate.
local petBarHiddenNoPet = false
-- Sin `local`: asigna a la fwd-declarada arriba, que ApplyAllBarScales ya
-- referencia (si se re-declarara con `local`, esa referencia quedaria en nil).
function UpdatePetBarVisibility()
    local bar = _G.BT4BarPetBar
    if not bar then return end
    local hasPet = UnitExists("pet")
    if not hasPet then
        petBarHiddenNoPet = true
        bar._mcfCombatHidden = true
        bar:SetAlpha(0)
        pcall(bar.EnableMouse, bar, false)
    elseif petBarHiddenNoPet then
        petBarHiddenNoPet = false
        bar._mcfCombatHidden = false
        bar:SetAlpha(1)
        pcall(bar.EnableMouse, bar, true)
    end
end
ns.RefreshPetBarVisibility = UpdatePetBarVisibility

local evFrame = CreateFrame("Frame")
evFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
evFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
evFrame:RegisterEvent("UNIT_PET")
evFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingApply then ApplyAllBarScales() end
        return
    end
    if event == "UNIT_PET" and unit ~= "player" then return end
    ApplyAllBarScales()
    UpdatePetBarVisibility()
end)

-- DIAGNOSTICO: /mcfbt4diag -- lista los frames CONTENEDOR (barras, no botones
-- individuales) cuyo nombre empieza con "BT4", en una caja copiable (el chat
-- corta el scrollback y se perdian las primeras lineas -- reportado
-- 2026-07-24 al pegar el resultado de la version con print()). Excluye
-- cualquier nombre que contenga "Button" (botones individuales y sus
-- sub-regiones Icon/Name/Cooldown/etc, que son ruido para este diagnostico).
local function ShowCopyBox(text)
    local f = _G.MCFBT4DiagFrame
    if not f then
        f = CreateFrame("Frame", "MCFBT4DiagFrame", UIParent, "BackdropTemplate")
        f:SetSize(420, 380); f:SetPoint("CENTER"); f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 24,
            insets = { left = 6, right = 6, top = 6, bottom = 6 },
        })
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)
        local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetPoint("TOP", 0, -12); lbl:SetText("Ctrl+A y Ctrl+C para copiar")
        local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 14, -34); sf:SetPoint("BOTTOMRIGHT", -32, 14)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true); eb:SetFontObject(ChatFontNormal)
        eb:SetWidth(360); eb:SetAutoFocus(false)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        sf:SetScrollChild(eb)
        f.eb = eb
    end
    f.eb:SetText(text)
    f.eb:HighlightText()
    f:Show()
    f.eb:SetFocus()
end

SLASH_MCFBT4DIAG1 = "/mcfbt4diag"
SlashCmdList["MCFBT4DIAG"] = function()
    local names = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and k:sub(1, 3) == "BT4" and not k:find("Button")
           and type(v) == "table" and v.GetObjectType then
            names[#names + 1] = k
        end
    end
    table.sort(names)
    ShowCopyBox(table.concat(names, "\n"))
end
