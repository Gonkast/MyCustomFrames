-- ==========================================================================
-- MyCustomFrames - BarReposition.lua
-- BAR REPOSITION: reposiciona la barra possess/vehicle de Bartender4 (BT4Bar5)
-- a una posicion fija cuando el jugador esta MONTADO en una montura (IsMounted),
-- y a otra posicion si ademas tiene target.
-- BT4Bar5 no es un frame protegido (solo los botones de accion dentro lo son),
-- asi que SetPoint es seguro incluso en combate.
-- IMPORTANTE: nunca se toca el anclaje si no esta mounted -- Bartender controla
-- su propio point/relativeTo/relativePoint y no se puede asumir que sea
-- "BOTTOM, UIParent, BOTTOM". Solo se sobreescribe el anclaje mientras esta
-- mounted, guardando el anclaje ORIGINAL real (capturado con GetPoint) para
-- restaurarlo exacto al desmontar.
-- Carga DESPUES de core.lua en el toc: usa ns.GetDB.
-- ==========================================================================
local ADDON, ns = ...

local MOUNT_X, MOUNT_Y = -366, -255
local MOUNT_TARGET_X, MOUNT_TARGET_Y = -326, -255

local f = CreateFrame("Frame")

local savedPoint   -- { point, relativeTo, relativePoint, x, y } anclaje original de Bartender
local applied = false

local function Restore(bar)
    if applied and savedPoint then
        pcall(bar.ClearAllPoints, bar)
        pcall(bar.SetPoint, bar, savedPoint[1], savedPoint[2], savedPoint[3], savedPoint[4], savedPoint[5])
    end
    applied = false
end

-- FIX 2026-07-19 (error reportado por el usuario en vivo:
-- "ADDON_ACTION_BLOCKED... AddOn 'Bartender4' tried to call the protected
-- function 'BT4Bar5:ClearAllPoints()'") -- el supuesto de arriba ("BT4Bar5
-- no es un frame protegido") resulto ser falso en este cliente: cuando la
-- barra de vehiculo/possess tiene botones de accion activos (montado +
-- alguna habilidad de montura utilizable), el frame se vuelve protegido de
-- verdad y mover/reposicionar en combate tira ADDON_ACTION_BLOCKED -- mismo
-- patron ya usado en el resto del addon (SetCVar de Nameplates.lua, etc.):
-- si estas en combate, difiere y reintenta al salir (PLAYER_REGEN_ENABLED),
-- ademas de un pequeño helper `SafeReposition` con pcall como red de
-- seguridad extra (por si el bloqueo llega de una forma que
-- InCombatLockdown() no anticipa).
local pendingUpdate = false

local function SafeClearAndSet(bar, point, relTo, relPoint, x, y)
    local ok1 = pcall(bar.ClearAllPoints, bar)
    local ok2 = pcall(bar.SetPoint, bar, point, relTo, relPoint, x, y)
    return ok1 and ok2
end

local function UpdatePosition()
    local db = ns.GetDB()
    local bar = _G["BT4Bar5"]
    if bar and InCombatLockdown() then
        pendingUpdate = true
        return
    end
    if not (db and db.barReposition and bar) then
        if bar then Restore(bar) end
        return
    end

    if IsMounted() then
        if not applied then
            local point, relTo, relPoint, x, y = bar:GetPoint()
            savedPoint = { point, relTo or UIParent, relPoint, x, y }
            applied = true
        end
        local targetX, targetY = MOUNT_X, MOUNT_Y
        if UnitExists("target") then
            targetX, targetY = MOUNT_TARGET_X, MOUNT_TARGET_Y
        end
        SafeClearAndSet(bar, savedPoint[1], savedPoint[2], savedPoint[3], targetX, targetY)
    else
        Restore(bar)
    end
end
ns.RefreshBarReposition = UpdatePosition

f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")

f:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingUpdate then
            pendingUpdate = false
            UpdatePosition()
        end
        return
    end
    UpdatePosition()
end)
