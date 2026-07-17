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
        bar:ClearAllPoints()
        bar:SetPoint(savedPoint[1], savedPoint[2], savedPoint[3], savedPoint[4], savedPoint[5])
    end
    applied = false
end

local function UpdatePosition()
    local db = ns.GetDB()
    local bar = _G["BT4Bar5"]
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
        bar:ClearAllPoints()
        bar:SetPoint(savedPoint[1], savedPoint[2], savedPoint[3], targetX, targetY)
    else
        Restore(bar)
    end
end
ns.RefreshBarReposition = UpdatePosition

f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
f:RegisterEvent("PLAYER_TARGET_CHANGED")

f:SetScript("OnEvent", function(self, event, unit)
    UpdatePosition()
end)
