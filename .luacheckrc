std = "lua51"
max_line_length = false

-- La API de WoW expone miles de globals (CreateFrame, UnitClass, C_Timer, etc.)
-- que luacheck no conoce de fabrica. No tiene sentido enumerarlas todas: se
-- ignora el warning de LECTURA de variable no declarada (113) -- son, casi
-- siempre, llamadas legitimas a la API de Blizzard. Se dejan ACTIVOS los de
-- ESCRITURA (111/112): olvidarse el `local` y filtrar una variable al scope
-- global SI es un bug real que vale la pena pescar (fue justamente el tipo de
-- error de la sesion "BOM bug" con ns.BUILTIN, aunque ese caso puntual era otra
-- causa -- este chequeo cubre la clase de bug en general).
ignore = {
    "113",
}

-- Globals que este addon SI escribe/muta a proposito (SavedVariables, slash
-- commands, y compat con otros addons via Profiles/ProfilesApply.lua) -- no
-- son el "olvide el local" que 111/112 buscan pescar.
globals = {
    "MyCustomFramesDB",
    "SlashCmdList",
    "StaticPopupDialogs",
    "DynamicCam",
    "MyCF_BuildRaidMember",
    "SLASH_MYCUSTOMFRAMES1", "SLASH_MCFCHAR1", "SLASH_MCFSETUP1", "SLASH_MCFHUD1",
    "SLASH_MCFTRACKERDUMP1", "SLASH_MCFTOOLTIP1", "SLASH_MCFEXTRABTN1",
    "SLASH_MCFCLASSPOWERDIAG1", "SLASH_MCFPANELDIAG1", "SLASH_MCFMENU1",
    "SLASH_MCFMMDIAG1", "SLASH_MCFMAPICONSDIAG1", "SLASH_MCFRINGDIAG1",
    "SLASH_MCFMIRRORDIAG1", "SLASH_MCFMIRROR1", "SLASH_MCFNPDESIGNER1",
    "SLASH_MCFAURASDIAG1", "SLASH_MCFCASTWATCH1", "SLASH_MCFNPDIAG1",
    "SLASH_MCFPARTYTEST1", "SLASH_MCFARENADIAG1", "SLASH_MCFARENAAURATEST1",
    "SLASH_MCFMIRRORTARGETDIAG1",
}

exclude_files = {
    "Libs/**",
    "Profiles/Bartender4/**",
    "Profiles/DynamicCam/**",
    "Profiles/Masque/**",
    "Profiles/Chattynator/**",
}
