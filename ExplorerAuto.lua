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

-- Blizzard reemplaza la barra principal por una "override"/"vehicle" bar en
-- vehiculos, en algunas mecanicas de jefe, en overdrive y en las poses de
-- housing. Las tres APIs cubren variantes distintas del mismo estado, asi que
-- se consultan las tres.
local function Bar1IsReplaced()
    local ok, v
    ok, v = pcall(HasOverrideActionBar);  if ok and v then return true end
    ok, v = pcall(HasVehicleActionBar);   if ok and v then return true end
    ok, v = pcall(HasTempShapeshiftActionBar); if ok and v then return true end
    return false
end

local barsHidden = false

local function ApplyBarHiding()
    local db = DB(); if not db then return end
    local want = db.explorerHideBarsOnReplace and Bar1IsReplaced() or false
    if want == barsHidden then return end
    -- En combate no se tocan: son frames protegidos y seria
    -- ADDON_ACTION_BLOCKED. Queda pendiente para PLAYER_REGEN_ENABLED.
    if InCombatLockdown() then return end
    barsHidden = want
    -- 2 a 10: la 1 es justamente la que lleva el reemplazo y tiene que quedar.
    for i = 2, 10 do
        local bar = _G["BT4Bar" .. i]
        if bar then pcall(bar.SetShown, bar, not want) end
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
C_Timer.NewTicker(1.0, function()
    UpdateHousing()
    ApplyBarHiding()
end)
