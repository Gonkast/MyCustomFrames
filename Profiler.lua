local ADDON, ns = ...

-- ==========================================================================
-- MyCustomFrames - Profiler.lua
--
-- POR QUE EXISTE. El profiler de Blizzard (scriptProfile) mide por ADDON, no
-- por funcion: te dice que MyCustomFrames gasta 13.78 ms/s -- el 50% del CPU de
-- todos los addons juntos, medido en vivo 2026-07-28 -- pero no en QUE. Y sin
-- eso, optimizar es adivinar cual de los ~10 caminos calientes es el caro.
--
-- Esto envuelve cada camino caliente conocido (los tickers de 0.1s y 0.3s y los
-- OnUpdate permanentes) y acumula cuanto tarda cada uno con debugprofilestop(),
-- que devuelve milisegundos con precision de microsegundo.
--
-- COSTE CUANDO ESTA APAGADO: una comparacion booleana por llamada. El wrapper
-- chequea `active` ANTES de leer el reloj, asi que con el profiling apagado no
-- se llama a debugprofilestop() ni se toca ninguna tabla. Por eso puede quedar
-- puesto en produccion sin medir nada.
--
-- Se enciende con /mcfdiag hot (ver Maintenance.lua), que ademas es quien
-- reporta. Carga TEMPRANO (antes que los modulos que envuelve).
-- ==========================================================================

local active = false
local acc, calls = {}, {}
local since = 0

ns.Prof = {}

-- Envuelve `fn` para que sume su tiempo bajo la etiqueta `name`.
-- Devuelve la funcion envuelta; el llamador la usa en lugar de la original.
function ns.Prof.Wrap(name, fn)
    if type(fn) ~= "function" then return fn end
    return function(...)
        if not active then return fn(...) end
        local t0 = debugprofilestop()
        -- Se preservan hasta 4 retornos: alcanza para todo lo que envolvemos
        -- (los OnUpdate y los tickers no devuelven nada), y evita el coste de
        -- empaquetar en tabla con `...` en un camino que corre 10 veces/seg.
        local a, b, c, d = fn(...)
        acc[name] = (acc[name] or 0) + (debugprofilestop() - t0)
        calls[name] = (calls[name] or 0) + 1
        return a, b, c, d
    end
end

function ns.Prof.Start()
    wipe(acc); wipe(calls)
    since = GetTime()
    active = true
end

function ns.Prof.IsActive() return active end

-- Devuelve una lista ordenada { name, ms, msPerSec, callsPerSec } y los segundos
-- transcurridos. No apaga la medicion: se puede pedir el reporte varias veces.
function ns.Prof.Report()
    local elapsed = GetTime() - since
    if elapsed <= 0 then return {}, 0 end
    local list = {}
    for name, ms in pairs(acc) do
        list[#list + 1] = {
            name = name, ms = ms,
            msPerSec = ms / elapsed,
            callsPerSec = (calls[name] or 0) / elapsed,
        }
    end
    table.sort(list, function(a, b) return a.ms > b.ms end)
    return list, elapsed
end

function ns.Prof.Stop()
    active = false
end
