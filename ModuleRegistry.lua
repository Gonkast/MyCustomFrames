-- ===========================================================================
-- MyCustomFrames - ModuleRegistry.lua
-- Registro declarativo de los subsistemas persistentes.
--
-- No crea frames, no modifica SavedVariables y no llama APIs protegidas. Su
-- unico fin es que Maintenance pueda comprobar que el contrato minimo de cada
-- modulo sigue completo despues de una refactorizacion o una actualizacion de
-- Midnight. Mantenerlo separado evita sumar locals/upvalues a core/Options.
-- ===========================================================================
local ADDON, ns = ...

local FEATURES = {
    { key = "units",          label = "Unit frames",       refresh = "RefreshAllUnits" },
    { key = "portraits",      label = "Portraits",         refresh = "RefreshAllPortraits" },
    { key = "auras",          label = "Auras",             refresh = "RefreshAllAuras" },
    { key = "infobar",        label = "Info bar",          refresh = "RefreshInfoBar" },
    { key = "micromenu",      label = "Micro menu",        defaults = "MicroMenuDefaults", refresh = "RefreshMicroMenu" },
    { key = "chatbubble",     label = "Chat bubbles",      defaults = "ChatBubbleDefaults", refresh = "RefreshChatBubble" },
    { key = "glow",           label = "Glow",              defaults = "GlowDefaults", refresh = "RefreshGlow" },
    { key = "tracker",        label = "Quest tracker",     refresh = "RefreshTracker" },
    { key = "minimap",        label = "Minimap",           defaults = "MinimapDefaults", refresh = "RefreshMinimap" },
    { key = "nameplates",     label = "Nameplates",        defaults = "NameplateDefaults", refresh = "RefreshNameplateStyle" },
    { key = "classpower",     label = "Class power",       defaults = "ClassPowerDefaults", refresh = "RefreshClassPower" },
    { key = "tooltip",        label = "Tooltips",          defaults = "TooltipDefaults", refresh = "RefreshTooltipSkin" },
    { key = "extrabutton",    label = "Extra button",      defaults = "ExtraButtonDefaults", refresh = "RefreshExtraButtonSkin" },
    { key = "mirrortimer",    label = "Mirror timers",     defaults = "MirrorTimerDefaults", refresh = "RefreshMirrorTimers" },
    { key = "topwidget",      label = "Top widget",        defaults = "TopWidgetDefaults", refresh = "RefreshTopWidget" },
    { key = "minimapbuttons", label = "Minimap buttons",   defaults = "MinimapButtonsDefaults", refresh = "RefreshMinimapButtons" },
}

ns.FEATURE_REGISTRY = FEATURES

function ns.GetFeatureRegistry()
    return FEATURES
end
