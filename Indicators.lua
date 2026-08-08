local ADDON, ns = ...

-- ==========================================================================
-- INDICADORES DE UTILIDAD (2026-07-27, pedido del usuario): range fade y
-- shield bar (absorb) para las unitframes individuales -- player/target/
-- focus/party1-5/arena_* (NO el raid header de hasta 40 de Raid.lua, eso
-- queda para despues si se quiere).
--
-- Carga ANTES de Units.lua (ver .toc, justo despues de API.lua) porque
-- CreateUnit() alla llama a ns.CreateUnitIndicators(u) de forma SINCRONICA
-- al final de ese archivo (`for _, def in ipairs(ns.UNITS) do CreateUnit(def)
-- end` corre en cuanto Units.lua termina de cargar, no diferido a un evento).
--
-- Secret-safe siguiendo patrones YA probados en el resto del addon:
--   - Range: UnitInRange(unit) -- CORREGIDO en juego (ver SafeBool mas abajo):
--     resulto SI devolver booleanos secretos para arena/party, a pesar de que
--     la investigacion previa decia que era dato posicional nunca secreto.
--   - Shield: UnitGetTotalAbsorbs(unit)/UnitHealthMax(unit) se pasan DIRECTO
--     a StatusBar:SetMinMaxValues/SetValue sin operarlos en Lua -- mismo
--     principio que SetCooldownFromDurationObject/SetTimerDuration, ya
--     usados en AuraHoverPreview.lua/Units.lua. La barra de shield es
--     INDEPENDIENTE de la de vida (mismo rango 0..healthMax, su propio valor
--     = absorb) en vez de "extension pegada al borde de la vida" -- eso
--     necesitaria sumar vida+absorb, mezclando 2 valores potencialmente
--     secretos en Lua. Blizzard resuelve ese caso con un
--     UnitHealPredictionCalculator dedicado (lo que usa Cell) -- queda como
--     posible v2 una vez validado en vivo que hace falta.
--
-- QUITADO (2026-07-27, pedido del usuario: "creo que es mejor quitar lo de
-- dispel por ahora, no le veo utilidad ni forma de aplicarlo y testearlo de
-- momento"): el dispel glow (borde/aura recoloreado cuando la unidad tiene
-- un debuff dispelleable) se implemento completo -- deteccion via
-- IsAuraFilteredOutByInstanceID(unit, id, "HARMFUL|RAID"), textura/color/
-- tamaño/offset configurables por unidad, pestaña propia en Options.lua --
-- pero se saco por falta de un caso de uso claro para probarlo en la
-- practica. Si se retoma mas adelante, el commit donde se agrego/saco queda
-- en el historial de git como referencia (no hace falta rehacerlo de cero).
-- ==========================================================================

local INDICATOR_KEYS = {
    player = true, target = true, focus = true,
    party1 = true, party2 = true, party3 = true, party4 = true, party5 = true,
    arena_player = true, arena_party1 = true, arena_party2 = true,
    arena_enemy1 = true, arena_enemy2 = true, arena_enemy3 = true,
}

local function UnitProfile(u)
    local db = ns.GetDB and ns.GetDB()
    return db and db.units and db.units[u.key]
end

-- Crea los 2 elementos (ocultos) para una unitframe. Llamado desde
-- CreateUnit() en Units.lua, SOLO para las keys de INDICATOR_KEYS (u.key,
-- no u.unit -- party5/arena_player usan unit="player" pero son keys propias).
function ns.CreateUnitIndicators(u)
    if not INDICATOR_KEYS[u.key] then return end
    local button, bar = u.button, u.bar

    -- Range fade: overlay oscuro APARTE del alpha del frame -- Explorer/
    -- fade-in/combat-hidden ya se pelean por esa propiedad (ver
    -- explorerDriver en Explorer.lua), asi que esto es una capa visual
    -- independiente que solo oscurece, nunca toca SetAlpha del button.
    local rangeDim = button:CreateTexture(nil, "OVERLAY", nil, 6)
    rangeDim:SetAllPoints(button)
    rangeDim:SetColorTexture(0, 0, 0, 0.55)
    rangeDim:Hide()
    u.rangeDim = rangeDim

    -- Shield bar: StatusBar independiente, misma textura que la barra de
    -- vida de ESTA unidad especifica (p.texture, releida en cada refresh --
    -- pedido del usuario: "player, target, focus, party y arenas utilizan
    -- texturas diferentes, tenlo en cuenta"; si la textura cambia mas
    -- adelante, se refleja sola, sin tocar este archivo).
    local shieldBar = CreateFrame("StatusBar", nil, bar)
    shieldBar:SetAllPoints(bar)
    shieldBar:SetFrameLevel(bar:GetFrameLevel() + 1)
    shieldBar:SetOrientation("HORIZONTAL")
    shieldBar:SetMinMaxValues(0, 1)
    shieldBar:SetValue(0)
    shieldBar:SetStatusBarColor(1, 1, 1, 0.45)
    -- Textura inicial EXPLICITA (2026-07-27, reportado con captura: "una
    -- textura negra con baja opacidad"): un StatusBar sin textura asignada
    -- puede dibujarse como un placeholder negro/solido hasta que el primer
    -- tick de ApplyShieldTexture le ponga la textura real. Un valor inicial
    -- sensato cierra esa ventana en vez de confiar en que el primer tick
    -- llegue antes de que el usuario mire.
    shieldBar:SetStatusBarTexture(ns.TEXTURE_DEFAULT)
    local shieldTex = shieldBar:GetStatusBarTexture()
    if shieldTex then shieldTex:SetBlendMode("ADD") end
    u.shieldBar = shieldBar
end

-- Test mode (2026-07-27, pedido del usuario: "hay una forma en la que pueda
-- testear sin estar en la situacion que lo requiera?") -- fuerza los
-- indicadores a mostrarse en TODAS las unidades trackeadas que existan ahora
-- mismo, sin depender de estar realmente fuera de rango o con un shield
-- encima. Mismo patron que testMode en AuraHoverPreview.lua
-- (SetTestMode/ToggleTestMode).
local testMode = false

-- CORREGIDO (2026-07-27, reportado en juego: "attempt to perform boolean
-- test on local 'checked' (a secret boolean value...)", 210x, arena_party2):
-- la investigacion previa (UnitInRange = dato posicional, "nunca secreto")
-- resulto ser INCORRECTA para este build -- devuelve booleanos SECRETOS al
-- menos para unidades de arena/party (mismo criterio anti-scouting que ya
-- documenta ArenaTrinket.lua para UnitGUID). type()+issecretvalue() ANTES
-- de cualquier "if" sobre el resultado, como en el resto del addon -- si
-- alguno de los 2 sale secreto, se trata como "no se puede saber" y
-- simplemente no se oscurece (mejor no mostrar nada que mostrar un dato
-- adivinado). Posiblemente solo sea secreto en contenido restringido
-- (arena/M+/raid) -- fuera de eso puede que siga funcionando normal.
local function SafeBool(v)
    if type(v) ~= "boolean" then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function UpdateRange(u)
    local dim = u.rangeDim
    if not dim then return end
    -- Toggle del menu (2026-07-28). `~= false` y no `== true`: la opcion nace
    -- ausente en perfiles viejos y el comportamiento previo era estar siempre
    -- encendida, asi que ausente tiene que seguir significando encendida.
    local db = ns.GetDB and ns.GetDB()
    if db and db.indicatorRange == false then dim:Hide(); return end
    if u.unit == "player" then dim:Hide(); return end
    if testMode then dim:Show(); return end
    local ok, inRange, checked = pcall(UnitInRange, u.unit)
    if not ok then dim:Hide(); return end
    if SafeBool(checked) == true and SafeBool(inRange) == false then
        dim:Show()
    else
        dim:Hide()
    end
end

-- CORREGIDO (2026-07-27, reportado: "shield bar solo parece estar en el
-- player" -- las claves basadas en unit="player" -party5, arena_player- son
-- las UNICAS donde UnitExists(u.unit) es trivialmente true sin estar
-- agrupado/en arena; party1-4/arena_party1-2/arena_enemy1-3 necesitan estar
-- realmente en grupo/arena para que su unit token exista). testMode debia
-- bypasear ese chequeo (igual que ya hace en AuraHoverPreview.lua, donde el
-- modo test nunca toca datos reales de la unidad) -- estaba ANTES del
-- chequeo de UnitExists en vez de saltarlo.
local function ApplyShieldTexture(bar, u)
    local p = UnitProfile(u)
    local tex = (p and p.texture and p.texture ~= "") and p.texture or ns.TEXTURE_DEFAULT
    if bar._lastTex ~= tex then
        bar._lastTex = tex
        bar:SetStatusBarTexture(tex)
        local t = bar:GetStatusBarTexture()
        if t then t:SetBlendMode("ADD") end
    end
end

local function UpdateShield(u)
    local bar = u.shieldBar
    if not bar then return end
    local db = ns.GetDB and ns.GetDB()
    if db and db.indicatorShield == false then bar:Hide(); return end

    if testMode then
        ApplyShieldTexture(bar, u)
        -- Escala PROPIA (0..1, valor fijo 0.35) en vez de la real (0..hMax):
        -- hMax puede ser secreto para otras unidades, y esto es solo preview
        -- visual -- no hace falta ni conviene operar sobre el numero real.
        pcall(bar.SetMinMaxValues, bar, 0, 1)
        pcall(bar.SetValue, bar, 0.35)
        return
    end

    if not (u.unit and UnitExists(u.unit)) then bar:SetValue(0); return end
    ApplyShieldTexture(bar, u)

    -- FIX (2026-08-05, auditoria): antes truth-testeaba hMax/absorb
    -- directo (`and hMax`) -- mismo criterio "type()+issecretvalue() ANTES
    -- de cualquier if" que ya usa SafeBool aca arriba y SafeMax en
    -- ClassPower.lua, aplicado ahora tambien aca por consistencia.
    local okMax, hMax = pcall(UnitHealthMax, u.unit)
    local okAbs, absorb = pcall(UnitGetTotalAbsorbs, u.unit)
    local maxOK = okMax and type(hMax) == "number" and not (issecretvalue and issecretvalue(hMax))
    local absOK = okAbs and type(absorb) == "number" and not (issecretvalue and issecretvalue(absorb))
    if not (maxOK and absOK) then bar:SetValue(0); return end
    pcall(bar.SetMinMaxValues, bar, 0, hMax)
    pcall(bar.SetValue, bar, absorb)
end

-- Ticker compartido (2026-07-27): misma cadencia (0.3s) ya establecida en
-- AuraHoverPreview.lua para los grupos de auras hover.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    C_Timer.After(1, function()
        C_Timer.NewTicker(0.3, ns.Prof.Wrap("Indicators: range/shield 0.3s", function()
            for key in pairs(INDICATOR_KEYS) do
                local u = ns.frames and ns.frames[key]
                if u then
                    UpdateRange(u)
                    UpdateShield(u)
                end
            end
        end))
    end)
end)

-- Expuesto en ns (2026-07-27) para el boton "Preview" de Options.lua. Devuelve
-- el estado NUEVO, que el boton usa para quedar marcado mientras este activo.
function ns.ToggleIndicatorTest()
    testMode = not testMode
    return testMode
end

SLASH_MCFINDICATORTEST1 = "/mcfindicatortest"
SlashCmdList["MCFINDICATORTEST"] = function()
    print("|cff00ff00[MCF indicator test]|r " .. (ns.ToggleIndicatorTest() and "ON" or "off") ..
        " -- range/shield forced on every tracked unit that exists right now.")
end

-- Reaplica los dos indicadores en todas las unidades ahora mismo. Lo llaman los
-- toggles del menu: sin esto el cambio no se veria hasta el siguiente tick.
function ns.RefreshIndicators()
    for _, u in pairs(ns.frames or {}) do
        UpdateRange(u)
        UpdateShield(u)
    end
end
