--[[Perfy has instrumented this file]] local Perfy_GetTime, Perfy_Trace, Perfy_Trace_Passthrough = Perfy_GetTime, Perfy_Trace, Perfy_Trace_Passthrough; Perfy_Trace(Perfy_GetTime(), "Enter", "(main chunk) MyCustomFrames/Profiler.lua"); local ADDON, ns = ...

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

-- Se define ns.Prof lo antes posible y con Wrap tolerante: si algun archivo
-- envuelto llegara a cargar antes que este (paso: core.lua creaba su ticker
-- a nivel de archivo y reventaba con 'attempt to index field ?'), lo peor
-- que puede pasar es quedarse sin medir, no romper el addon.
local active = false
local acc, calls = {}, {}
local since = 0

ns.Prof = {}

-- Envuelve `fn` para que sume su tiempo bajo la etiqueta `name`.
-- Devuelve la funcion envuelta; el llamador la usa en lugar de la original.
function ns.Prof.Wrap(name, fn) Perfy_Trace(Perfy_GetTime(), "Enter", "Prof.Wrap MyCustomFrames/Profiler.lua:36:0");
    if type(fn) ~= "function" then Perfy_Trace(Perfy_GetTime(), "Leave", "Prof.Wrap MyCustomFrames/Profiler.lua:36:0"); return fn end
    return Perfy_Trace_Passthrough("Leave", "Prof.Wrap MyCustomFrames/Profiler.lua:36:0", function(...) Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/Profiler.lua:38:11");
        if not active then return Perfy_Trace_Passthrough("Leave", "(anonymous) MyCustomFrames/Profiler.lua:38:11", fn(...)) end
        local t0 = debugprofilestop()
        -- Se preservan hasta 4 retornos: alcanza para todo lo que envolvemos
        -- (los OnUpdate y los tickers no devuelven nada), y evita el coste de
        -- empaquetar en tabla con `...` en un camino que corre 10 veces/seg.
        local a, b, c, d = fn(...)
        acc[name] = (acc[name] or 0) + (debugprofilestop() - t0)
        calls[name] = (calls[name] or 0) + 1
        Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/Profiler.lua:38:11"); return a, b, c, d
    end)
end

-- Cronometra UNA llamada ya existente, sin envolverla. Wrap() crea una funcion
-- nueva, asi que usarlo dentro de un ticker alocaria un closure por pasada --
-- justo lo que estamos tratando de reducir. Esto se llama en el sitio.
function ns.Prof.Time(name, fn, ...) Perfy_Trace(Perfy_GetTime(), "Enter", "Prof.Time MyCustomFrames/Profiler.lua:54:0");
    if not active then return Perfy_Trace_Passthrough("Leave", "Prof.Time MyCustomFrames/Profiler.lua:54:0", fn(...)) end
    local t0 = debugprofilestop()
    local a, b, c, d = fn(...)
    acc[name] = (acc[name] or 0) + (debugprofilestop() - t0)
    calls[name] = (calls[name] or 0) + 1
    Perfy_Trace(Perfy_GetTime(), "Leave", "Prof.Time MyCustomFrames/Profiler.lua:54:0"); return a, b, c, d
end

function ns.Prof.Start() Perfy_Trace(Perfy_GetTime(), "Enter", "Prof.Start MyCustomFrames/Profiler.lua:63:0");
    wipe(acc); wipe(calls)
    since = GetTime()
    active = true
Perfy_Trace(Perfy_GetTime(), "Leave", "Prof.Start MyCustomFrames/Profiler.lua:63:0"); end

function ns.Prof.IsActive() Perfy_Trace(Perfy_GetTime(), "Enter", "Prof.IsActive MyCustomFrames/Profiler.lua:69:0"); Perfy_Trace(Perfy_GetTime(), "Leave", "Prof.IsActive MyCustomFrames/Profiler.lua:69:0"); return active end

-- Devuelve una lista ordenada { name, ms, msPerSec, callsPerSec } y los segundos
-- transcurridos. No apaga la medicion: se puede pedir el reporte varias veces.
function ns.Prof.Report() Perfy_Trace(Perfy_GetTime(), "Enter", "Prof.Report MyCustomFrames/Profiler.lua:73:0");
    local elapsed = GetTime() - since
    if elapsed <= 0 then return Perfy_Trace_Passthrough("Leave", "Prof.Report MyCustomFrames/Profiler.lua:73:0", {}, 0) end
    local list = {}
    for name, ms in pairs(acc) do
        list[#list + 1] = {
            name = name, ms = ms,
            msPerSec = ms / elapsed,
            callsPerSec = (calls[name] or 0) / elapsed,
        }
    end
    table.sort(list, function(a, b) Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/Profiler.lua:84:21"); return Perfy_Trace_Passthrough("Leave", "(anonymous) MyCustomFrames/Profiler.lua:84:21", a.ms > b.ms) end)
    Perfy_Trace(Perfy_GetTime(), "Leave", "Prof.Report MyCustomFrames/Profiler.lua:73:0"); return list, elapsed
end

function ns.Prof.Stop() Perfy_Trace(Perfy_GetTime(), "Enter", "Prof.Stop MyCustomFrames/Profiler.lua:88:0");
    active = false
Perfy_Trace(Perfy_GetTime(), "Leave", "Prof.Stop MyCustomFrames/Profiler.lua:88:0"); end

Perfy_Trace(Perfy_GetTime(), "Leave", "(main chunk) MyCustomFrames/Profiler.lua");