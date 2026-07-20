-- ==========================================================================
-- MyCustomFrames - ArenaTrinket.lua
-- Pedido del usuario 2026-07-19: icono de trinket de PvP SOLO en Arena Enemy
-- 1/2/3, replicando el comportamiento de Blizzard con APIs publicas
-- unicamente -- NO se lee el item equipado, el cooldown del slot de trinket,
-- ni informacion de inventario del enemigo.
--
-- CAMBIADO (2026-07-19, "sigue el error con RegisterEvent"): la guia original
-- pedia detectar via COMBAT_LOG_EVENT_UNFILTERED, pero confirmado en vivo
-- (ADDON_ACTION_FORBIDDEN persistente, aislado sin ningun otro error) que en
-- Midnight 12.0 ese evento fue ELIMINADO del acceso de addons por completo --
-- RegisterEvent para el mismo tira forbidden SIEMPRE, no es un tema de
-- contexto/instancia. Nueva deteccion: usar el trinket otorga el buff
-- "Gladiator's Medallion" (MISMO spellID que la habilidad, 208683) -- se
-- detecta su APARICION vía UNIT_AURA + C_UnitAuras, exactamente el mismo
-- patron ya probado/funcionando en ArenaAuraPreview.lua/Nameplates.lua para
-- estas mismas unidades de arena (secret-safe, API publica, sin combat log).
--
-- Arquitectura (separacion total, pedido del usuario): este archivo SOLO
-- detecta y calcula -- no sabe nada de frames/iconos. Units.lua (el widget del
-- Arena Enemy Frame) SOLO dibuja lo que este modulo le informa via
-- ns.ArenaTrinketState + ns.RefreshArenaTrinketIcon.
-- ==========================================================================
local ADDON, ns = ...

-- Tabla spellID -> duracion (segundos) del cooldown REAL del trinket -- el
-- buff que otorga al usarlo dura solo unos segundos (inmunidad a CC), MUCHO
-- menos que el cooldown real (120s); por eso el temporizador que mostramos
-- lo armamos nosotros con esta duracion conocida, no con la del buff.
-- Gladiator's Medallion (moderno, unico trinket de PvP activo en este
-- cliente -- "Adaptation"/195756 fue removido en 9.0.1) = spell 208683.
local TRINKET_SPELLS = {
    [208683] = 120,   -- Gladiator's Medallion
}

local ENEMY_UNITS = { "arena1", "arena2", "arena3" }

-- Estado PUBLICO leido por el widget del frame (Units.lua): unit -> {start, duration}.
ns.ArenaTrinketState = {}

-- auraInstanceID ya vistos por unidad -- para disparar el timer SOLO cuando
-- el buff aparece de nuevo (no en cada UNIT_AURA mientras sigue activo).
local seenInstance = {}

local function ScanUnit(unit)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
    local seen = seenInstance[unit] or {}
    local stillThere = {}
    for i = 1, 40 do
        local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
        if not ok or data == nil then break end
        -- FIX (2026-07-20, error en juego: "attempted to index a table that
        -- cannot be indexed with secret keys"): data.spellId es un numero
        -- SECRETO en este cliente -- usarlo directo como indice de
        -- TRINKET_SPELLS[...] tira ese error. El lookup en si (no solo la
        -- lectura del campo) tiene que ir envuelto en pcall.
        local sid = data.spellId
        local dur
        if sid then
            local ok2, res = pcall(function() return TRINKET_SPELLS[sid] end)
            if ok2 then dur = res end
        end
        if dur and data.auraInstanceID then
            stillThere[data.auraInstanceID] = true
            if not seen[data.auraInstanceID] then
                -- Aparicion NUEVA de la aura -> el enemigo acaba de usar el trinket.
                ns.ArenaTrinketState[unit] = { start = GetTime(), duration = dur }
                if ns.RefreshArenaTrinketIcon then ns.RefreshArenaTrinketIcon(unit) end
            end
        end
    end
    seenInstance[unit] = stillThere
end

-- Un frame POR unidad (RegisterUnitEvent NO es acumulativo -- llamarlo varias
-- veces para el MISMO evento en el MISMO frame reemplaza, no suma; leccion ya
-- aprendida esta sesion con los retratos en core.lua).
for _, unit in ipairs(ENEMY_UNITS) do
    local f = CreateFrame("Frame")
    f:RegisterUnitEvent("UNIT_AURA", unit)
    f:SetScript("OnEvent", function() ScanUnit(unit) end)
end

-- Limpia el estado guardado al entrar a un mundo nuevo (nueva instancia de
-- arena = partido nuevo).
-- CAMBIADO (2026-07-20, error en juego: "attempt to compare local 'guid' (a
-- secret string value...)"): UnitGUID(unit) para unidades de arena enemigas
-- devuelve un STRING SECRETO en este cliente (anti-scouting) -- compararlo
-- (guid ~= lastGUID[unit]) esta bloqueado sin excepcion, ni siquiera dentro
-- de pcall sirve para detectar el cambio de forma confiable. Se saca el
-- reset por-GUID via ARENA_OPPONENT_UPDATE (disparaba varias veces por
-- partido de todas formas) y se limpia SIEMPRE en PLAYER_ENTERING_WORLD, que
-- ya cubre el caso real (partido nuevo = loading screen nuevo).
local resetWatcher = CreateFrame("Frame")
resetWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
resetWatcher:SetScript("OnEvent", function()
    for _, unit in ipairs(ENEMY_UNITS) do
        seenInstance[unit] = nil
        ns.ArenaTrinketState[unit] = nil
        if ns.RefreshArenaTrinketIcon then ns.RefreshArenaTrinketIcon(unit) end
    end
end)
