-- ==========================================================================
-- MyCustomFrames - Maintenance.lua
-- Herramientas de mantenimiento / calidad de vida (2026-07-25):
--   1. `/mcfskincheck` -- valida que la skin ACTIVA traiga todos los archivos
--      que el sistema de skins espera. Sin esto, un archivo faltante se
--      renderiza INVISIBLE y no hay ninguna pista de cual es (ver el FIX
--      CRITICO de SkinResolve en core.lua: no se puede detectar si un archivo
--      existe, por eso hace falta este chequeo MANUAL contra la lista).
--   2. `/mcfdiag <sub>` -- router unico de los ~20 comandos de diagnostico que
--      antes ocupaban un slash global cada uno.
--   3. Purga de claves MUERTAS en la DB guardada (features ya eliminadas que
--      seguian ocupando lugar en los SavedVariables del usuario para siempre).
-- Carga al final del toc: usa ns.GetDB/ns.SKINNABLE/ns.TEX_SKINS ya listos.
-- ==========================================================================
local ADDON, ns = ...

-- ==========================================================================
-- 1) VALIDADOR DE SKINS
-- ==========================================================================
-- Archivos que una skin DEBE traer ademas de la lista blanca `ns.SKINNABLE`
-- (esos son texturas del addon; estos son del skin de Masque, que NO tiene
-- fallback al Assets\ principal -- ver el comentario de Load.lua de cada skin).
local MASQUE_FILES = {
    "actionbutton-backdrop.tga",
    "actionbutton-border.tga",
    "actionbutton-glow-white.tga",
    "actionbutton-pushed.tga",
    "actionbutton_circular_mask.tga",
}

-- Unica forma de "preguntar" por un archivo en WoW: pedirle a una textura que
-- lo cargue y ver si quedo algo. OJO: `SetTexture()` devuelve `true` aunque el
-- archivo NO exista (por eso se abandono como prueba de existencia en
-- SkinResolve), pero `GetTexture()` despues de un SetTexture fallido devuelve
-- el path igual... asi que tampoco sirve. Lo que SI distingue es el TAMAÑO
-- REAL del contenido: una textura que no cargo no tiene dimensiones utiles.
-- Se usa GetWidth() del objeto textura tras hacerlo visible en un frame de
-- tamaño conocido -- no es perfecto, asi que el reporte se presenta como
-- "sospechoso", nunca como verdad absoluta.
local probeFrame = CreateFrame("Frame", nil, UIParent)
probeFrame:SetSize(64, 64)
probeFrame:SetPoint("CENTER")
probeFrame:Hide()
local probeTex = probeFrame:CreateTexture(nil, "BACKGROUND")
probeTex:SetAllPoints()

local function FileLoads(path)
    probeTex:SetTexture(nil)
    local ok = probeTex:SetTexture(path)
    if not ok then return false end
    -- GetTextureFileID devuelve nil para rutas que el cliente no resolvio a un
    -- archivo real. Es el chequeo mas confiable disponible desde Lua.
    if probeTex.GetTextureFileID then
        local id = probeTex:GetTextureFileID()
        if id ~= nil then return true end
        -- Un .tga suelto de addon no siempre tiene fileID (esos son de los
        -- archivos empaquetados del cliente) -> no se puede concluir que falte.
        return nil   -- desconocido
    end
    return nil
end

local function ActiveSkin()
    local db = ns.GetDB and ns.GetDB()
    local label = db and db.activeSkinLabel
    if not label or label == "Default" then return nil, label or "Default" end
    for _, skin in ipairs(ns.TEX_SKINS or {}) do
        if skin.label == label then return skin, label end
    end
    return nil, label
end

local function SkinCheck()
    local skin, label = ActiveSkin()
    print("|cffffe19b[MCF]|r Skin check -- skin activa: |cff00ff00" .. tostring(label) .. "|r")
    if not skin then
        if label == "Default" then
            print("  La skin Default usa el Assets\\ del addon: no hay nada que validar.")
        else
            print("  |cffff5555No se encontro esa skin registrada|r (¿el addon-skin esta desactivado?).")
        end
        return
    end
    local base = skin.basePath
    if not base or base == "" then
        print("  Skin interna (subcarpeta de Assets\\), sin basePath propio: no se valida.")
        return
    end

    local missing, unknown, okCount = {}, 0, 0
    local function check(path, name)
        local r = FileLoads(path)
        if r == false then missing[#missing + 1] = name
        elseif r == nil then unknown = unknown + 1
        else okCount = okCount + 1 end
    end

    for file in pairs(ns.SKINNABLE or {}) do check(base .. file, file) end
    for _, file in ipairs(MASQUE_FILES) do check(base .. "MasqueSkin\\" .. file, "MasqueSkin\\" .. file) end

    print(("  Ruta: %s"):format(base))
    if #missing > 0 then
        print(("  |cffff5555FALTAN %d archivo(s)|r -- se renderizan INVISIBLES:"):format(#missing))
        table.sort(missing)
        for _, f in ipairs(missing) do print("    - " .. f) end
    else
        print("  |cff00ff00No se detectaron archivos faltantes.|r")
    end
    if unknown > 0 then
        print(("  (%d no se pudieron verificar desde Lua -- normal para .tga de addon; "):format(unknown)
            .. "si algo se ve invisible, revisa que el NOMBRE coincida exacto)")
    end
    print(("  Verificados OK: %d | total esperado: %d"):format(okCount, unknown + okCount + #missing))
end
ns.SkinCheck = SkinCheck

-- ==========================================================================
-- 3) PURGA DE CLAVES MUERTAS EN LA DB
-- ==========================================================================
-- Cuando se elimina una feature, su campo sigue viviendo en los SavedVariables
-- del usuario para siempre (FillDefaults solo AGREGA lo que falta, nunca borra).
-- Se acumula basura y confunde al leer un export. Agregar aca el campo al
-- quitar una feature.
local DEAD_UNIT_FIELDS = {
    "hideWhenMounted",   -- feature quitada 2026-07-24 (reemplazo: Explorer)
    "textLowHealthShow",       -- antiguo reveal por HP: no era secret-safe en Midnight
    "textLowHealthThreshold",  -- reemplazado por percentLowHealthThreshold + ColorCurve
    -- Dispel glow (2026-07-27): se implemento completo (deteccion + pestaña
    -- propia en Options) y se quito el mismo dia -- sin forma practica de
    -- probarlo. Cualquiera que corriera esa version intermedia tiene los 7
    -- campos guardados en cada unidad.
    "dispelGlowTexture", "dispelGlowWidth", "dispelGlowHeight",
    "dispelGlowOffsetX", "dispelGlowOffsetY", "dispelGlowColor", "dispelGlowAlpha",
}
local DEAD_GLOBALS = {
    "barReposition",     -- BarReposition.lua borrado 2026-07-24
    "explorerDamage",    -- condicion "recibi daño" revertida 2026-07-24
}
-- Claves muertas dentro de db.nameplates (2026-07-27). Categoria NUEVA: hasta
-- ahora solo se purgaba db.units[*] y la raiz de db, asi que una feature
-- quitada de una SUB-TABLA de modulo (nameplates/minimap/etc) no tenia forma
-- de limpiarse. El indicador de amenaza paso por 4 versiones el mismo dia y se
-- descarto; quien corriera alguna de las intermedias arrastra estas 3.
local DEAD_NAMEPLATE_FIELDS = {
    "showThreat", "threatScale", "threatAlpha",
    -- Se mudo a la raiz de la DB (db.designerRefScale, 2026-07-27): aca dentro
    -- se perdia cada vez que se cargaba un perfil de nameplates o se reseteaba,
    -- porque esas dos operaciones reemplazan db.nameplates ENTERA. Ademas es un
    -- ajuste del editor, no del aspecto -- no debe viajar en un perfil exportado.
    "designerRefScale",
}
-- Entradas ENTERAS muertas de db.auras (2026-07-27). El grid siempre-visible de
-- Auras.lua se elimino (Player/Target/Focus pasaron a AuraHoverPreview.lua, que
-- guarda su config en claves GLOBALES planas -- playerAuraDirection y demas, no
-- en db.auras). ns.AURAS quedo vacio, asi que NADA lee ya estas tablas, pero
-- seguian viajando en cada export: ~54 campos por entrada de peso muerto.
local DEAD_AURA_KEYS = { "aura_player", "aura_target", "aura_focus" }

function ns.PurgeDeadKeys(verbose)
    local db = ns.GetDB and ns.GetDB()
    if not db then return 0 end
    local n = 0
    for _, t in pairs(db.units or {}) do
        for _, f in ipairs(DEAD_UNIT_FIELDS) do
            if t[f] ~= nil then t[f] = nil; n = n + 1 end
        end
    end
    for _, g in ipairs(DEAD_GLOBALS) do
        if db[g] ~= nil then db[g] = nil; n = n + 1 end
    end
    for _, f in ipairs(DEAD_NAMEPLATE_FIELDS) do
        if db.nameplates and db.nameplates[f] ~= nil then db.nameplates[f] = nil; n = n + 1 end
    end
    for _, k in ipairs(DEAD_AURA_KEYS) do
        if db.auras and db.auras[k] ~= nil then db.auras[k] = nil; n = n + 1 end
    end
    -- Los presets guardados arrastran lo mismo.
    for _, pr in pairs(db.presets or {}) do
        for _, t in pairs(pr.units or {}) do
            for _, f in ipairs(DEAD_UNIT_FIELDS) do
                if t[f] ~= nil then t[f] = nil; n = n + 1 end
            end
        end
        for _, g in ipairs(DEAD_GLOBALS) do
            if pr.globals and pr.globals[g] ~= nil then pr.globals[g] = nil; n = n + 1 end
        end
        for _, f in ipairs(DEAD_NAMEPLATE_FIELDS) do
            if pr.nameplates and pr.nameplates[f] ~= nil then pr.nameplates[f] = nil; n = n + 1 end
        end
        for _, k in ipairs(DEAD_AURA_KEYS) do
            if pr.auras and pr.auras[k] ~= nil then pr.auras[k] = nil; n = n + 1 end
        end
    end
    if verbose then
        print(("|cffffe19b[MCF]|r Claves muertas purgadas: %d"):format(n))
    end
    return n
end

-- Corre UNA vez por sesion, al entrar al mundo (despues de InitDB).
local purgeFrame = CreateFrame("Frame")
purgeFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
purgeFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    if ns.PurgeDeadKeys then ns.PurgeDeadKeys(false) end
end)

-- ==========================================================================
-- 2) ROUTER DE DIAGNOSTICOS -- `/mcfdiag <sub>`
-- ==========================================================================
-- Los subsistemas se registran solos con ns.RegisterDiag(nombre, desc, fn).
-- `/mcfdiag` sin argumentos lista lo disponible (antes no habia forma de saber
-- que comandos existian: eran ~20 slashes globales sueltos, sin indice).
local diags = {}
-- `kind` (2026-07-27, opcional, default "diag"): agrupa la salida de /mcfdiag.
--   "diag" -> vuelca el estado real de un subsistema (solo lee, no cambia nada)
--   "test" -> togglea una previsualizacion (SI cambia lo que se ve, es un toggle)
-- Sin agrupar, con ~30 entradas la lista era un muro alfabetico donde no se
-- distinguia lo que solo informa de lo que modifica la pantalla.
function ns.RegisterDiag(name, desc, fn, kind)
    if type(name) ~= "string" or type(fn) ~= "function" then return end
    diags[name:lower()] = { desc = desc or "", fn = fn, kind = kind or "diag" }
end

ns.RegisterDiag("skincheck", "Valida que la skin activa traiga todos sus archivos", SkinCheck)
ns.RegisterDiag("purge", "Purga claves de features ya eliminadas de la DB", function()
    ns.PurgeDeadKeys(true)
end)

-- Verificacion pasiva del contrato de modulos. No intenta refrescar nada: en
-- Midnight llamar SetPoint/Show/SetScale sobre un frame de otro sistema puede
-- estar protegido durante combate. Solo informa lo que falte para detectar
-- errores de carga, claves que no entran en presets o APIs renombradas.
local function VerifyInstallation()
    local db = ns.GetDB and ns.GetDB()
    local registry = ns.GetFeatureRegistry and ns.GetFeatureRegistry()
    local presetKeys = ns.GetPresetTableKeys and ns.GetPresetTableKeys()
    if type(db) ~= "table" then
        print("|cffff5555[MCF]|r verify: la base de datos no esta disponible.")
        return
    end
    if type(registry) ~= "table" or type(presetKeys) ~= "table" then
        print("|cffff5555[MCF]|r verify: falta ModuleRegistry o la API de presets.")
        return
    end

    local inPreset = {}
    for _, key in ipairs(presetKeys) do inPreset[key] = true end

    local problems, checked = {}, 0
    for _, feature in ipairs(registry) do
        checked = checked + 1
        local issue = nil
        if db[feature.key] == nil then
            issue = "falta su tabla en DB"
        elseif not inPreset[feature.key] then
            issue = "no participa en presets/export/reset"
        elseif feature.defaults and type(ns[feature.defaults]) ~= "function" then
            issue = "falta API " .. feature.defaults
        elseif feature.refresh and type(ns[feature.refresh]) ~= "function" then
            issue = "falta API " .. feature.refresh
        end
        if issue then problems[#problems + 1] = (feature.label or feature.key) .. ": " .. issue end
    end

    if #problems == 0 then
        print(("|cff00ff00[MCF]|r verify: %d modulos persistentes OK; DB y presets coherentes."):format(checked))
    else
        print(("|cffff5555[MCF]|r verify: %d problema(s) de %d modulo(s):"):format(#problems, checked))
        for _, issue in ipairs(problems) do print("  - " .. issue) end
    end
end
ns.VerifyInstallation = VerifyInstallation
ns.RegisterDiag("verify", "Comprueba modulos, DB y cobertura de presets (sin tocar frames)", VerifyInstallation)

-- ==========================================================================
-- REGISTRO CENTRAL de los comandos sueltos (2026-07-27).
--
-- El addon tiene ~40 slash commands y hasta hoy solo 4 estaban en el router:
-- los otros 36 no habia forma de descubrirlos dentro del juego, habia que leer
-- el README. Se registran TODOS aca en vez de en sus 15 archivos por dos
-- razones: (1) un solo lugar para leer que existe, en vez de un grep por el
-- repo, y (2) no hace falta refactorizar 15 handlers anonimos a funciones con
-- nombre solo para poder referenciarlos.
--
-- La resolucion es DIFERIDA (se busca en SlashCmdList al invocar, no al
-- registrar): asi no importa el orden de carga del .toc, y si un comando se
-- elimina en el futuro esto avisa en vez de reventar.
local function Cmd(handler, arg)
    return function()
        local fn = SlashCmdList[handler]
        if type(fn) ~= "function" then
            print("|cffff5555[MCF]|r El comando /" .. handler:lower() .. " ya no existe en esta version.")
            return
        end
        fn(arg or "")
    end
end

-- Diagnosticos: vuelcan estado, no tocan nada.
ns.RegisterDiag("scaledump",    "Posicion y escala de cada elemento en la resolucion actual", Cmd("MCFSCALEDUMP"))
ns.RegisterDiag("bt4",          "Que barras de Bartender4 existen y con que nombre", Cmd("MCFBT4DIAG"))
ns.RegisterDiag("auras",        "Datos de auras del objetivo actual", Cmd("MCFAURASDIAG"))
ns.RegisterDiag("aurahover",    "Estado interno de un grupo de auras hover (hover/combate/gate/alpha)", Cmd("MCFAURAHOVERDIAG"))
ns.RegisterDiag("nameplates",   "Estado general de los nameplates", Cmd("MCFNPDIAG"))
ns.RegisterDiag("npobjects",    "unit/GUID/tipo por nameplate -- para plates que no deberian estar (objetos)", Cmd("MCFNPOBJDIAG"))
ns.RegisterDiag("castwatch",    "Togglea el log en vivo de casteos de nameplates", Cmd("MCFCASTWATCH"))
ns.RegisterDiag("minimap",      "Estado general del minimapa", Cmd("MCFMMDIAG"))
ns.RegisterDiag("rings",        "Anillos de XP/reputacion/honor/renombre del minimapa", Cmd("MCFRINGDIAG"))
ns.RegisterDiag("mapicons",     "Iconos y pines del minimapa", Cmd("MCFMAPICONSDIAG"))
ns.RegisterDiag("minimapbtns",  "Botones de minimapa que recogio el colector", Cmd("MCFMINIMAPBTNSLIST"))
ns.RegisterDiag("arena",        "Que metodo de deteccion de arena esta devolviendo que", Cmd("MCFARENADIAG"))
ns.RegisterDiag("classpower",   "Deteccion del recurso de clase para tu clase y spec", Cmd("MCFCLASSPOWERDIAG"))
ns.RegisterDiag("mirror",       "Temporizadores espejo (respiracion/fatiga)", Cmd("MCFMIRRORDIAG"))
ns.RegisterDiag("mirrortarget", "Retrato del objetivo espejado", Cmd("MCFMIRRORTARGETDIAG"))
ns.RegisterDiag("panel",        "Zonas muertas del mouse sobre el panel de opciones", Cmd("MCFPANELDIAG"))
ns.RegisterDiag("tracker",      "Clasificacion del texto del rastreador de misiones", Cmd("MCFTRACKERDUMP"))
ns.RegisterDiag("charbutton",   "Boton de \"abrir panel de personaje\" del retrato", Cmd("MCFCHAR"))

-- Previsualizaciones: TOGGLES, cambian lo que se ve hasta volver a ejecutarlos.
ns.RegisterDiag("testauras",     "Previsualiza las auras hover de party", Cmd("MCFPARTYTEST"), "test")
ns.RegisterDiag("testarena",     "Previsualiza las auras hover de arena", Cmd("MCFARENAAURATEST"), "test")
ns.RegisterDiag("testfocus",     "Previsualiza las auras hover de focus", Cmd("MCFFOCUSAURATEST"), "test")
ns.RegisterDiag("testplayer",    "Previsualiza las auras hover del jugador", Cmd("MCFPLAYERAURATEST"), "test")
ns.RegisterDiag("testtarget",    "Previsualiza las auras hover del objetivo", Cmd("MCFTARGETAURATEST"), "test")
ns.RegisterDiag("testindicator", "Fuerza el atenuado por rango y la barra de escudo", Cmd("MCFINDICATORTEST"), "test")
ns.RegisterDiag("testloc",       "Simula un icono de perdida de control en el retrato", Cmd("MCFLOCTEST"), "test")
ns.RegisterDiag("testtrinket",   "Simula el cooldown del trinket en los 3 enemigos de arena", Cmd("MCFTRINKETTEST"), "test")

-- Comandos que NO pasan por el router (abren ventanas, cambian config o hacen
-- una accion): se LISTAN para que /mcfdiag sea el indice unico, pero se ejecutan
-- directo. Tabla curada a proposito -- son pocos y estables, y meterlos en el
-- router significaria "ejecutar /mcf desde /mcfdiag", que no tiene sentido.
local OTHER_COMMANDS = {
    { "/mcf",            "Modo mover/bloquear (edicion)" },
    { "/mcfmenu",        "Abre el panel de opciones" },
    { "/mcfsetup",       "Reabre el asistente de instalacion" },
    { "/mcfnpdesigner",  "Abre el diseñador de nameplates" },
    { "/mcfundo",        "Restaura el respaldo previo al ultimo Reset ALL o perfil aplicado" },
    { "/mcfskincheck",   "Comprueba que la skin activa traiga todos sus archivos" },
    { "/mcfhud",         "Muestra el codigo del HUD del Edit Mode de Blizzard" },
    { "/mcfmirror",      "Temporizador espejo: toggle/width/height/offsetx/offsety" },
    { "/mcftooltip",     "Reskin del tooltip: toggle/scale" },
    { "/mcfextrabtn",    "Borde del boton de accion extra" },
    { "/mcfminimapbtnsignore", "Excluye un boton del colector de minimapa" },
    { "/mcfminimapbtnsreset",  "Reinicia posicion y escala del colector" },
}

SLASH_MCFDIAG1 = "/mcfdiag"
SlashCmdList["MCFDIAG"] = function(msg)
    local sub = (msg or ""):match("^%s*(%S*)"):lower()
    if sub == "" or sub == "help" then
        local byKind = { diag = {}, test = {} }
        for k, d in pairs(diags) do
            local bucket = byKind[d.kind] or byKind.diag
            bucket[#bucket + 1] = k
        end
        table.sort(byKind.diag); table.sort(byKind.test)

        print("|cffffe19b[MCF]|r Diagnosticos (|cff00ff00/mcfdiag <nombre>|r) -- solo informan:")
        for _, k in ipairs(byKind.diag) do
            print(("  |cff00ff00%-14s|r %s"):format(k, diags[k].desc))
        end
        print("|cffffe19b[MCF]|r Previsualizaciones -- son TOGGLES, volve a ejecutarlas para apagarlas:")
        for _, k in ipairs(byKind.test) do
            print(("  |cff00ff00%-14s|r %s"):format(k, diags[k].desc))
        end
        print("|cffffe19b[MCF]|r Otros comandos (se ejecutan directo, no por /mcfdiag):")
        for _, c in ipairs(OTHER_COMMANDS) do
            print(("  |cffffff00%-22s|r %s"):format(c[1], c[2]))
        end
        return
    end
    local d = diags[sub]
    if not d then
        print("|cffff5555[MCF]|r No existe el diagnostico \"" .. sub .. "\". Usa /mcfdiag para ver la lista.")
        return
    end
    d.fn()
end

-- Atajo directo (el mas usado, se deja como slash propio).
SLASH_MCFSKINCHECK1 = "/mcfskincheck"
SlashCmdList["MCFSKINCHECK"] = SkinCheck
