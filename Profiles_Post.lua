-- ==========================================================================
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
