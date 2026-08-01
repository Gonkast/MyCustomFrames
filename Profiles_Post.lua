--[[Perfy has instrumented this file]] local Perfy_GetTime, Perfy_Trace, Perfy_Trace_Passthrough = Perfy_GetTime, Perfy_Trace, Perfy_Trace_Passthrough; Perfy_Trace(Perfy_GetTime(), "Enter", "(main chunk) MyCustomFrames/Profiles_Post.lua"); -- ==========================================================================
-- Profiles_Post.lua — parte 2: captura las copias y RESTAURA los globales vivos.
-- Ver Profiles_Pre.lua. Tras esto:
--   ns.Profiles[global] = la copia (para "Aplicar Perfiles")
--   _G[global]          = el valor VIVO original (sin corromper nada)
-- ==========================================================================
local ADDON, ns = ...

ns.Profiles = ns.Profiles or {}
for _, g in ipairs(ns.ProfGlobals or {}) do
    ns.Profiles[g] = _G[g]                 -- la copia recien cargada
    _G[g] = ns._profLive and ns._profLive[g]   -- restaurar el vivo (o nil si el addon aun no cargo)
end
ns._profLive = nil

Perfy_Trace(Perfy_GetTime(), "Leave", "(main chunk) MyCustomFrames/Profiles_Post.lua");