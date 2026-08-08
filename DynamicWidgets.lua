-- ==========================================================================
-- MyCustomFrames - DynamicWidgets.lua
--
-- Frames dinamicos de Blizzard que solo existen en contextos puntuales
-- (BuffTimer1-5 y PlayerPowerBarAlt: minijuegos de la feria tipo
-- Whack-a-Gnoll, algun evento de zona). Este archivo es SOLO diagnostico +
-- un override manual; el ocultado real vive en core.lua, dentro de
-- HideBlizzardFramesNow (o sea que sigue al toggle "Hide Blizzard Elements").
--
-- POR QUE NO SE PUEDEN MOVER (2026-08-08, intentado y descartado):
-- se intento darles holder propio para arrastrarlos/escalarlos con /mcf,
-- por el mismo patron que TopWidget.lua. No se puede en 12.1.0:
--   * `BuffTimer1:GetCenter()` devuelve **secret numbers** -- cualquier
--     aritmetica sobre ellos (comparar la distancia al holder para decidir
--     si re-anclar) revienta con "attempt to perform arithmetic on local
--     'wx' (a secret number value, while execution tainted by
--     'MyCustomFrames')".
--   * `SetPoint` sobre ellos es **"a secret function value"** -- llamarlo
--     desde codigo nuestro tainta UnitPowerBarAlt.lua:887.
-- Reparentarlos tampoco agarra: Blizzard los reasigna a UIParent /
-- PlayerPowerBarAlt en su propio refresh. El unico verbo que si funciona
-- sobre ellos es Hide()/SetAlpha, que es lo que hace core.lua.
-- ==========================================================================

local ADDON, ns = ...
local _ = ADDON

-- Los frames que este archivo inspecciona. Misma lista que oculta core.lua.
local WATCHED = {
	"BuffTimer1", "BuffTimer2", "BuffTimer3", "BuffTimer4", "BuffTimer5",
	"PlayerPowerBarAlt", "PlayerPowerBarAltCounterBar",
}

-- ---- Override manual (independiente de Hide Blizzard Elements) ----
-- Util para probar sin togglear la opcion global, o para esconder uno suelto
-- que aparezca en un evento nuevo antes de agregarlo a la lista de core.lua.
function ns.ToggleDynamicWidget(frameName, hide)
	local f = _G[frameName]
	if not f then return false end
	if hide then f:Hide() else f:Show() end
	return true
end

-- ---- Diagnostico ----
local function DiagnosticFrames()
	print("|cff00ff00[MCF]|r Widgets dinamicos (BuffTimer / PlayerPowerBarAlt):")
	local anyFound = false
	for _, name in ipairs(WATCHED) do
		local f = _G[name]
		if f then
			anyFound = true
			local shown = f:IsVisible() and "|cff00ff00VISIBLE|r" or "|cff808080oculto|r"
			local parent = f:GetParent()
			local pname = (parent and parent.GetName and parent:GetName()) or "?"
			print(format("  |cffffcc00%-28s|r %s  parent: %s  %dx%d",
				name, shown, pname, f:GetWidth() or 0, f:GetHeight() or 0))
		end
	end
	if not anyFound then
		print("  |cff808080(ninguno existe ahora mismo -- solo se crean en eventos/minijuegos)|r")
	end
	local db = ns.GetDB and ns.GetDB()
	print(format("  Hide Blizzard Elements: %s",
		(db and db.hideBlizzard) and "|cff00ff00ON|r" or "|cffff5555OFF|r"))
end

-- El registro en el router /mcfdiag vive en Maintenance.lua (que carga
-- ULTIMO y resuelve el handler de forma perezosa via Cmd"..."), no aca:
-- este archivo carga mucho antes, cuando ns.RegisterDiag todavia no existe.
SlashCmdList["MCFDYNDIAG"] = DiagnosticFrames
SLASH_MCFDYNDIAG1 = "/mcfdyndiag"
