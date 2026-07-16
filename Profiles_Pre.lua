-- ==========================================================================
-- Profiles_Pre.lua — parte 1 de la carga SEGURA de perfiles de otros addons.
-- Las copias de SavedVariables en Profiles\ setean sus globales reales (Bartender4DB, etc.).
-- Cargarlas via el toc CLOBBEA esos globales vivos → en logout el juego los guardaria y
-- CORROMPERIA el SV real del otro addon. Para evitarlo:
--   * Este archivo (ANTES de las copias) guarda el valor VIVO de cada global.
--   * Las copias cargan (clobbean).
--   * Profiles_Post.lua (DESPUES) captura la copia en ns.Profiles[global] y RESTAURA el vivo.
-- Asi nunca corrompemos el SV de otros addons.
-- ==========================================================================
local ADDON, ns = ...

-- Globales que setean las copias de SavedVariables en Profiles\.
ns.ProfGlobals = {
    "AzeriteUI5_DB",
    "Bartender4DB",
    "CHATTYNATOR_CONFIG", "CHATTYNATOR_MESSAGE_LOG",
    "DynamicCamDB", "minZoomValues",
    "MasqueDB",
}

ns._profLive = {}
for _, g in ipairs(ns.ProfGlobals) do
    ns._profLive[g] = _G[g]
end
