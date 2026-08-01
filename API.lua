-- ==========================================================================
-- MyCustomFrames - API.lua
-- Pedido del usuario 2026-07-19 ("como esta estructurado mi addon, que sean
-- faciles de actualizar si Blizzard cambia la API"): unico punto que sabe
-- COMO leer valores de la API de Blizzard que ya cambiaron de comportamiento
-- una vez esta sesion (UnitHealthPercent/UnitPowerPercent + curva). Antes
-- esto estaba duplicado a mano en Nameplates.lua y Units.lua -- un bug
-- (CurveConstants.ScaleTo100) se arreglo en un archivo y se paso el otro,
-- volviendo a fallar en juego. Ahora hay UN solo lugar para arreglar si
-- Blizzard vuelve a tocar esta API -- todo el resto del addon llama a estas
-- funciones, nunca a la API cruda directamente.
--
-- Carga TEMPRANO (justo despues de core.lua en el .toc) para que cualquier
-- archivo posterior pueda usarlas.
-- ==========================================================================
local ADDON, ns = ...

-- % de vida 0-100 (o nil si no se pudo leer). Firma real confirmada via
-- warcraft.wiki.gg/wiki/API_UnitHealthPercent:
--   UnitHealthPercent(unit [, usePredicted [, curve]])
-- SIN curva devuelve una FRACCION 0-1 (no 0-100) -- por eso hace falta
-- CurveConstants.ScaleTo100 para el 0-100 que el resto del addon espera.
-- El resultado puede ser un valor SECRETO en contextos de combate real, pero
-- SetFormattedText (y las demas APIs "consumidoras" que ya usa este addon)
-- lo aceptan tal cual -- no hace falta gatear en issecretvalue antes de
-- pasarlo a mostrar, alcanza con comparar contra nil.
function ns.GetHealthPercent(unit)
    if not (UnitHealthPercent and unit) then return nil end
    local ok, pct = pcall(UnitHealthPercent, unit, true, CurveConstants and CurveConstants.ScaleTo100)
    if not ok then return nil end
    return pct
end

-- Igual que GetHealthPercent, pero ADEMAS informa si el resultado es un
-- NUMERO LEGIBLE (no secreto) -- para el caso en que el llamador necesita
-- saber si tambien es seguro pedir el valor ABSOLUTO (UnitHealth) para
-- mostrarlo abreviado junto al %, no solo el porcentaje.
function ns.GetHealthPercentReadable(unit)
    local pct = ns.GetHealthPercent(unit)
    local readable = (type(pct) == "number") and not (issecretvalue and issecretvalue(pct))
    return pct, readable
end

-- % de poder 0-100 (o nil). Firma real: UnitPowerPercent(unit, powerType
-- [, usePredicted [, curve]]) -- mismo motivo de la curva que la de arriba.
function ns.GetPowerPercent(unit, powerType)
    if not (UnitPowerPercent and unit) then return nil end
    local ok, pct = pcall(UnitPowerPercent, unit, powerType, true, CurveConstants and CurveConstants.ScaleTo100)
    if not ok then return nil end
    return pct
end
