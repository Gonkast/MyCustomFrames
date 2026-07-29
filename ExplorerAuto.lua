local ADDON, ns = ...

-- ==========================================================================
-- MyCustomFrames - ExplorerAuto.lua
--
-- Automatismos OPCIONALES alrededor del Explorer (2026-07-28, pedido del
-- usuario). Los dos van apagados por defecto y tienen su toggle en
-- Options > Explorer > Conditions.
--
-- 1) HOUSING -> modo Minimal. Al entrar a tu casa/terreno aplica el perfil
--    rapido "minimal", y al salir DEVUELVE exactamente lo que tenias: otro
--    perfil, ajustes manuales, o el Explorer directamente apagado.
--
--    Restaurar "lo que tenias" no es volver a un perfil con nombre -- el
--    usuario puede tener el mapa de elementos tocado a mano, sin corresponder a
--    ningun perfil. Por eso se guarda una COPIA del estado (el toggle maestro
--    mas la tabla db.explorer entera) al entrar, y se reescribe al salir.
--
-- 2) BARRA 1 CON REEMPLAZO -> esconder las demas. Cuando la barra de accion
--    principal esta ocupada por una barra de reemplazo (vehiculo, overdrive,
--    poses de housing, etc), las BT4Bar2-10 se esconden. Es independiente del
--    Explorer: funciona con el prendido o apagado.
--
-- Ninguno de los dos toca nada en combate (SetShown sobre barras protegidas
-- seria ADDON_ACTION_BLOCKED): si el estado cambia peleando, se aplica al
-- salir de combate.
-- ==========================================================================

local f = CreateFrame("Frame")

local function DB() return ns.GetDB and ns.GetDB() end

-- ---- 1) Housing ----------------------------------------------------------

-- `C_Housing` no existe en builds sin housing y sus funciones pueden cambiar de
-- firma, asi que todo va con pcall: si algo falla, se responde "no estoy en
-- housing" y el automatismo simplemente no actua.
local function InHousing()
    if not C_Housing or not C_Housing.IsInsideHouseOrPlot then return false end
    local ok, inside = pcall(C_Housing.IsInsideHouseOrPlot)
    if not ok then return false end
    -- Se usa SOLO IsInsideHouseOrPlot, no CanEditCharter: el pedido fue "si
    -- estoy en housing", no "si estoy decorando". Para acotarlo al modo edicion,
    -- agregar aca `and pcall(C_Housing.CanEditCharter)` -- es la condicion que
    -- usa DynamicCam.
    return inside and true or false
end

-- Copia del estado del Explorer, para poder devolverlo tal cual.
local saved = nil
local housingActive = false

local function SaveExplorerState()
    local db = DB(); if not db then return end
    local copy = {}
    for k, v in pairs(db.explorer or {}) do copy[k] = v end
    saved = { enabled = db.explorerEnabled, map = copy }
end

local function RestoreExplorerState()
    local db = DB(); if not (db and saved) then return end
    -- Alpha=1 en todo antes de reescribir el mapa: mismo cuidado que toma
    -- ApplyExplorerQuickProfile, para que nada quede congelado a mitad de un
    -- desvanecido cuando cambia la membresia.
    if ns.ExplorerResetAll then ns.ExplorerResetAll() end
    -- db.explorer puede no existir todavia (perfil recien creado): wipe(nil)
    -- tira error duro. SaveExplorerState ya tolera el nil con `or {}`.
    db.explorer = db.explorer or {}
    wipe(db.explorer)
    for k, v in pairs(saved.map) do db.explorer[k] = v end
    db.explorerEnabled = saved.enabled
    saved = nil
    if ns.RefreshAll then ns.RefreshAll() end
end

local function UpdateHousing()
    local db = DB(); if not db then return end
    if not db.explorerHousingMinimal then
        -- Si se apago la opcion mientras estaba actuando, se devuelve el estado
        -- en vez de dejarlo pegado en minimal.
        if housingActive then housingActive = false; RestoreExplorerState() end
        return
    end
    local inside = InHousing()
    if inside == housingActive then return end
    housingActive = inside
    if inside then
        SaveExplorerState()
        db.explorerEnabled = true
        if ns.ApplyExplorerQuickProfile then ns.ApplyExplorerQuickProfile("minimal") end
    else
        RestoreExplorerState()
    end
end
ns.UpdateExplorerHousing = UpdateHousing

-- ---- 2) Barra 1 con reemplazo -> esconder las demas -----------------------

-- OJO: NO se reusa `explorerDriver.overrideBar` de Explorer.lua aunque parezca
-- lo mismo. Esa incluye `IsMounted()`, porque su proposito es mantener la barra
-- 1 VISIBLE al montarte. Aca haria que montarse escondiera todas las demas
-- barras, que no es lo pedido: esto es solo para cuando la barra 1 esta
-- realmente REEMPLAZADA (vehiculo, override, possess).
--
-- Mismas APIs que usa Explorer para su caso, menos IsMounted, y con el mismo
-- ns.safeBool (pueden devolver secretos en Midnight).
-- Se consultan VARIAS señales porque cada una cubre un caso distinto y ninguna
-- las cubre todas: possess (dominar mente, algunas mecanicas), vehiculo,
-- override generico, y por ultimo el propio frame nativo de Blizzard visible --
-- que es el mas confiable para variantes nuevas como las poses de housing, que
-- no disparan las APIs clasicas.
local function Bar1IsReplaced()
    if ns.safeBool(HasOverrideActionBar) then return true end
    if ns.safeBool(HasVehicleActionBar) then return true end
    if ns.safeBool(UnitHasVehicleUI, "player") then return true end
    if ns.safeBool(IsPossessBarVisible) then return true end
    local oab = _G.OverrideActionBar
    if oab and oab.IsShown and oab:IsShown() then return true end
    return false
end
ns.Bar1IsReplaced = Bar1IsReplaced

-- Diagnostico: dice QUE señal esta activa y si el force-hide deberia estar
-- actuando. Existe porque la primera version de esta feature no disparaba y no
-- habia forma de saber cual de las condiciones fallaba.
SLASH_MCFBARDIAG1 = "/mcfbardiag"
SlashCmdList["MCFBARDIAG"] = function()
    local db = DB()
    print("|cffffe19b[MCF bar]|r estado de la barra 1:")
    local checks = {
        { "HasOverrideActionBar", ns.safeBool(HasOverrideActionBar) },
        { "HasVehicleActionBar",  ns.safeBool(HasVehicleActionBar) },
        { "UnitHasVehicleUI",     ns.safeBool(UnitHasVehicleUI, "player") },
        { "IsPossessBarVisible",  ns.safeBool(IsPossessBarVisible) },
        { "OverrideActionBar visible", _G.OverrideActionBar and _G.OverrideActionBar:IsShown() or false },
    }
    for _, c in ipairs(checks) do
        print(("   %-28s %s"):format(c[1], c[2] and "|cff00ff00SI|r" or "no"))
    end
    print(("   -> reemplazada: %s"):format(Bar1IsReplaced() and "|cff00ff00SI|r" or "no"))
    print(("   opcion activada: %s   explorer: %s"):format(
        (db and db.explorerHideBarsOnReplace) and "si" or "|cffff5555NO|r",
        (db and db.explorerEnabled ~= false) and "on" or "off"))
    -- QUE barras existen de verdad. La primera version asumia BT4Bar1-10 y el
    -- diagnostico devolvio que ni BT4Bar2 existe: hay que ver los frames reales
    -- antes de decidir a cuales aplicarles el ocultamiento.
    print("   barras de Bartender4 que EXISTEN:")
    local hay = false
    for i = 1, 10 do
        local key, bar = "BT4Bar" .. i, _G["BT4Bar" .. i]
        if bar then
            hay = true
            print(("     %-9s alpha=%.2f  visible=%s  explorer=%s  force-hide=%s"):format(
                key, bar:GetAlpha(), bar:IsShown() and "si" or "no",
                (db and db.explorer and db.explorer[key]) and "si" or "no",
                ns.ExplorerBarForceHidden(key) and "SI" or "no"))
        end
    end
    if not hay then print("     |cffff5555ninguna|r -- Bartender4 no cargo o usan otro nombre") end
    for _, n2 in ipairs({ "BT4BarPetBar", "BT4BarStanceBar", "BT4BarBagBar", "BT4BarExtraActionBar" }) do
        if _G[n2] then print(("     %-22s alpha=%.2f"):format(n2, _G[n2]:GetAlpha())) end
    end
    print("   barras NATIVAS de Blizzard visibles:")
    local nat = false
    for _, n2 in ipairs({ "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight",
                          "MultiBarLeft", "MultiBarRight", "MultiBar5", "MultiBar6", "MultiBar7",
                          "StanceBar", "PetActionBar", "OverrideActionBar" }) do
        local fr = _G[n2]
        if fr and fr.IsShown and fr:IsShown() then nat = true; print("     " .. n2) end
    end
    if not nat then print("     ninguna") end
end

-- ¿Esta barra tiene que estar forzada a oculta AHORA? Lo consulta tambien el
-- bucle de Explorer.lua, para que gane sobre sus condiciones de revelado
-- (combate/target/casteo/hover) en vez de pelearse con ellas.
-- QUE se esconde. La primera version hacia `for i = 2, 10`, y el diagnostico en
-- vivo mostro por que estaba mal: en este setup solo existen BT4Bar1 y BT4Bar6.
-- "Las demas barras" que el usuario ve son sobre todo los modulos CON NOMBRE
-- (pet, stance, bolsas), que ese bucle no tocaba nunca.
--
-- BT4BarExtraActionBar queda AFUERA a proposito: es el boton de accion extra, y
-- justo en vehiculos y mecanicas de jefe -- que es cuando la barra 1 se
-- reemplaza -- suele ser el boton de la mecanica. Esconderlo seria peor que no
-- hacer nada.
local HIDE_NAMED = {
    BT4BarPetBar = true, BT4BarStanceBar = true, BT4BarBagBar = true,
}

local function IsHideable(key)
    if key == "BT4Bar1" then return false end
    if HIDE_NAMED[key] then return true end
    -- BT4Bar2..10 (numeradas): solo las que existan de verdad.
    local n = key:match("^BT4Bar(%d+)$")
    return n ~= nil and tonumber(n) >= 2
end

function ns.ExplorerBarForceHidden(key)
    local db = DB()
    if not (db and db.explorerHideBarsOnReplace) then return false end
    if not IsHideable(key) then return false end
    return Bar1IsReplaced()
end

-- Aplicacion DIRECTA, solo para las barras que el Explorer no esta gestionando
-- (apagado, o esa barra sin marcar). Las que si gestiona las resuelve su propio
-- bucle via ns.ExplorerBarForceHidden -- un solo dueño por barra, nunca los dos
-- escribiendo alpha sobre el mismo frame.
local touched = {}

local function ApplyBarHiding()
    local db = DB(); if not db then return end
    local explorerOwns = (db.explorerEnabled ~= false) and db.explorer or nil
    -- Numeradas + las de nombre propio, en una sola lista.
    local keys = {}
    for i = 2, 10 do keys[#keys + 1] = "BT4Bar" .. i end
    for k in pairs(HIDE_NAMED) do keys[#keys + 1] = k end
    for _, key in ipairs(keys) do
        local bar = _G[key]
        if bar and not (explorerOwns and explorerOwns[key]) then
            local hide = ns.ExplorerBarForceHidden(key)
            if hide then
                touched[key] = true
                bar:SetAlpha(0)
            elseif touched[key] then
                -- Solo se restaura lo que ESTA funcion escondio. Si el alpha lo
                -- puso otro (Explorer, Bartender4), no se pisa.
                touched[key] = nil
                bar:SetAlpha(1)
            end
        end
    end
end
ns.UpdateExplorerBarHiding = ApplyBarHiding

-- ---- Eventos -------------------------------------------------------------

f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("ZONE_CHANGED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
f:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
f:RegisterEvent("UNIT_ENTERED_VEHICLE")
f:RegisterEvent("UNIT_EXITED_VEHICLE")
-- Housing tiene sus propios eventos en los builds que lo traen; se registran
-- solo si existen (pcall: registrar un evento inexistente tira error duro).
for _, ev in ipairs({ "HOUSE_ENTERED", "HOUSE_EXITED", "HOUSING_MODE_CHANGED" }) do
    pcall(f.RegisterEvent, f, ev)
end

f:SetScript("OnEvent", function()
    UpdateHousing()
    ApplyBarHiding()
end)

-- Red de seguridad: los eventos de housing no estan garantizados en este build
-- (por eso se registran con pcall), y entrar a una casa puede no disparar
-- ninguno de los de zona. Un ticker lento cubre ese caso sin costar nada
-- medible -- 1 vez por segundo contra los 10 Hz del tick principal.
-- VIGIA temporal (2026-07-28): la feature "no funciona" pero no sabemos si
-- falla la DETECCION (nunca se entera de que la barra 1 cambio) o la APLICACION
-- (se entera y algo revierte el alpha). Esto avisa por chat en cada TRANSICION,
-- solo con la opcion encendida, asi el proximo reporte trae el dato en vez de
-- otra hipotesis. Se quita cuando este resuelto.
local lastReplaced = nil
local function WatchReplaced()
    local db = DB(); if not (db and db.explorerHideBarsOnReplace) then return end
    local now = Bar1IsReplaced()
    if now == lastReplaced then return end
    lastReplaced = now
    if now then
        local hidden = {}
        for _, k in ipairs({ "BT4Bar2","BT4Bar3","BT4Bar4","BT4Bar5","BT4Bar6","BT4Bar7",
                             "BT4Bar8","BT4Bar9","BT4Bar10","BT4BarPetBar","BT4BarStanceBar","BT4BarBagBar" }) do
            local f2 = _G[k]
            if f2 then hidden[#hidden + 1] = ("%s(%.1f)"):format(k, f2:GetAlpha()) end
        end
        print("|cffffe19b[MCF bar]|r barra 1 REEMPLAZADA -> ocultando: " .. table.concat(hidden, " "))
    else
        print("|cffffe19b[MCF bar]|r barra 1 volvio a la normal -> restaurando")
    end
end

C_Timer.NewTicker(1.0, function()
    UpdateHousing()
    ApplyBarHiding()
    WatchReplaced()
end)
