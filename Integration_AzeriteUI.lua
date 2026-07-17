-- ==========================================================================
-- MyCustomFrames - Integration_AzeriteUI.lua
-- BRIDGE con AzeriteUI (JuNNeZ Edition) SIN tocar sus archivos ni borrar assets.
-- Porta lo que hacia GonkastTweaks.lua (que vivia DENTRO de AzeriteUI) pero desde MyCustomFrames.
-- Se aplica AUTOMATICAMENTE si AzeriteUI esta instalado y activo (no requiere boton).
--
-- CLAVE de TIMING: AceAddon llama OnInitialize en ADDON_LOADED y OnEnable en PLAYER_LOGIN.
-- AzeriteUI carga ANTES que nosotros (OptionalDeps + orden alfabetico), asi que cuando ESTE
-- archivo se ejecuta (durante la pantalla de carga, ANTES de PLAYER_LOGIN):
--   * `_G.AzeriteUI` ya existe y sus modulos estan INICIALIZADOS pero NO habilitados aun.
--   * Por eso desactivamos AQUI MISMO (top-level) via SetEnabledState(false): cuando AzeriteUI
--     corra su pase de OnEnable en PLAYER_LOGIN, esos modulos se SALTAN (desactivado LIMPIO,
--     sin /reload). Igual que GonkastTweaks lo hacia en OnInitialize.
--   * `ns.GetDB()` todavia es nil aqui (InitDB corre en ADDON_LOADED de MCF), asi que leemos la
--     config del SavedVariable crudo `MyCustomFramesDB.azerite` (default = todo desactivado).
-- Lo demas (colores/nameplates/opciones/skin) se hace tras PLAYER_LOGIN.
--
-- Todo con pcall/guardas: si AzeriteUI no esta o su API cambia, NO rompe nada.
-- ==========================================================================
local ADDON, ns = ...

-- Carpeta de assets de reemplazo (solo se reskinnean los que EXISTEN aqui, por MISMO nombre).
local REMAP_DIR = "Interface\\AddOns\\MyCustomFrames\\Assets\\AzeriteUI Assets\\"
-- Nombres (sin extension) que EXISTEN fisicamente en esa carpeta → solo estos se sobrescriben.
local REMAP_SET = {}
for _, n in ipairs({
    "actionbutton-border", "border-tooltip", "cast_back", "cast_back_spiked", "cast_back_wooden",
    "config_button", "group-finder-eye-orange", "icon-heart-red", "icon_exit_flight",
    "icon_skull_dead", "icon_target_blue", "minimap-border", "party_portrait_border",
    "partyrole_dps", "partyrole_heal", "partyrole_tank", "point_block", "point_diamond", "point_plate",
}) do REMAP_SET[n] = true end

-- Definido temprano porque ApplyAssetConfigs (mas abajo) lo captura como upvalue y corre en file-load.
local function AZ()
    local az = _G.AzeriteUI
    if type(az) == "table" and az.GetModule then return az end
end

-- Mapa [ruta original de AzeriteUI en minusculas] = ruta de reemplazo nuestra.
-- GetMedia formatea: Interface\AddOns\AzeriteUI5_JuNNeZ_Edition\Assets\<name>.<type> (def "tga").
local ASSET_REMAP = {}
do
    local base = "interface\\addons\\azeriteui5_junnez_edition\\assets\\"
    for name in pairs(REMAP_SET) do
        ASSET_REMAP[base .. name .. ".tga"] = REMAP_DIR .. name .. ".tga"
    end
end

-- TODAS las tablas de layout de AzeriteUI (ns.RegisterConfig). AzeriteUI guarda los
-- resultados de GetMedia como valores string EN ESTAS TABLAS al cargar, y las lee al construir
-- los frames en su OnEnable (PLAYER_LOGIN). Si mutamos las rutas de textura AQUI, en file-load
-- (antes del OnEnable), AzeriteUI construye sus frames leyendo NUESTRAS rutas. Metodo garantizado
-- (no depende de GetTexture ni del timing de hooks). Mismo patron que ApplyColors usa para colores.
local ALL_ASSET_CONFIGS = {
    "ActionButton", "AlertFrames", "ArenaFrames", "BossFrames", "ExtraActionButton",
    "FocusFrame", "Info", "Minimap", "MirrorTimers", "NamePlates", "PartyFrames",
    "PetActionButton", "PetFrame", "PlayerCastBar", "PlayerClassPower", "PlayerFrame",
    "PlayerFrameAlternate", "Raid5Frames", "RaidFrames", "StanceButton", "StatusBars",
    "TargetFrame", "ToTFrame", "Tooltips", "VehicleExitButton",
}

-- Reemplaza recursivamente en una tabla de config cualquier valor string que sea una ruta
-- de asset de AzeriteUI en ASSET_REMAP, por la nuestra. `seen` evita ciclos/tablas compartidas.
local function RemapConfigTable(t, seen)
    if type(t) ~= "table" or seen[t] then return end
    seen[t] = true
    for k, v in pairs(t) do
        local tv = type(v)
        if tv == "string" then
            local repl = ASSET_REMAP[v:lower()]
            if repl then t[k] = repl end
        elseif tv == "table" then
            RemapConfigTable(v, seen)
        end
    end
end

-- Muta las rutas de textura en TODAS las tablas de config de AzeriteUI. Idempotente
-- (una ruta ya reemplazada no vuelve a estar en ASSET_REMAP). Corre en file-load y post-login.
local function ApplyAssetConfigs()
    local az = AZ(); if not (az and az.GetConfig) then return end
    local seen = {}
    for _, name in ipairs(ALL_ASSET_CONFIGS) do
        local ok, cfg = pcall(az.GetConfig, name)
        if ok and type(cfg) == "table" then RemapConfigTable(cfg, seen) end
    end
end

-- ---- Red SECUNDARIA: barrido UNICO (WalkRemap) tras el login. NO se hookea Texture:SetTexture
-- ---- de forma persistente: un hook global sobre ese metodo se dispara durante operaciones de
-- ---- Blizzard (menu de juego, panel de personaje...) e inyecta codigo insecure en ellas →
-- ---- CONTAMINA (taint) esas rutas (ADDON_ACTION_FORBIDDEN SpellStopCasting/callback, y el compare
-- ---- de numeros secretos del PlayerFrame). El barrido es taint-safe: corre en un timer nuestro,
-- ---- no en la ejecucion de Blizzard. LIMITACION: usa GetTexture() que en 12.0 puede devolver
-- ---- fileDataID numerico → NO puede reskinnear el borde del minimapa (ruta en local de componente).
local remapReentry = false
-- Re-apunta `tex` si `path` esta en ASSET_REMAP.
local function RemapPath(tex, path)
    if remapReentry then return end
    if type(path) ~= "string" then return end
    if not path:find("AzeriteUI5_JuNNeZ_Edition", 1, true) then return end   -- pre-filtro barato
    local repl = ASSET_REMAP[path:lower()]
    if repl then
        remapReentry = true
        pcall(tex.SetTexture, tex, repl)
        remapReentry = false
    end
end
local function RemapTexture(tex)
    local ok, cur = pcall(tex.GetTexture, tex)
    if ok then RemapPath(tex, cur) end
end

-- Hook de Texture:SetTexture: re-apunta assets que NO estan en tablas de config (el borde del
-- minimapa: su ruta vive en un local del componente Minimap.lua, se aplica via
-- object:SetTexture(data.Path) en el OnEnable). Matcheamos el ARGUMENTO (ruta string), no
-- GetTexture (que en 12.0 da fileID). Se instala en file-load para estar activo ANTES del OnEnable.
-- NOTA: el hook NO es la fuente del taint (el taint persistio sin el, y viene de mutar tablas de
-- config); va bajo el mismo toggle de skin (colorInjection) que la mutacion de assets.
local texHookInstalled = false
local function InstallTextureHook()
    if texHookInstalled then return end
    local probe = UIParent and UIParent.CreateTexture and UIParent:CreateTexture()
    if not probe then return end
    local mt = getmetatable(probe); mt = mt and mt.__index
    if type(mt) == "table" and type(mt.SetTexture) == "function" then
        hooksecurefunc(mt, "SetTexture", function(self, path) RemapPath(self, path) end)
        texHookInstalled = true
    end
end

local UNIT_CONFIGS = {
    "PlayerFrame", "PlayerFrameAlternate", "PlayerCastBar",
    "TargetFrame", "ToTFrame", "FocusFrame", "PetFrame",
    "PartyFrames", "RaidFrames", "Raid5Frames",
    "BossFrames", "ArenaFrames", "NamePlates",
}
local COLOR_KEYS = {
    names   = { "NameColor", "CastBarNameColor" },
    health  = { "HealthValueColor" },
    power   = { "PowerValueColor", "ManaValueColor", "ManaTextColor" },
    percent = { "HealthPercentageColor", "PowerPercentageColor", "ManaPercentageColor" },
    cast    = { "CastBarTextColor", "CastBarValueColor" },
}
local MODULE_MAP = { disableTracker = "Tracker", disableInfo = "Info", disableMicroMenu = "MicroMenu" }

local originals, npOrig = {}, {}

-- ---- Config: en file-load leemos el SV crudo; luego ns.GetDB(). Defaults = como InitDB. ----
local function RawCfg()
    -- SavedVariable crudo (disponible ya en file-load si existe de una sesion previa).
    local db = ns.GetDB and ns.GetDB()
    if db then return db.azerite end
    local sv = _G.MyCustomFramesDB
    return sv and sv.azerite
end
local function DisableWanted(setting)
    local c = RawCfg()
    if c and c[setting] ~= nil then return c[setting] and true or false end
    return true   -- default: desactivado (el preset Gonkast reemplaza esos modulos)
end

-- Interruptor MAESTRO de la inyeccion. Mutar las tablas de config de AzeriteUI desde MCF las
-- CONTAMINA (taint cruzado); AzeriteUI las lee al procesar numeros SECRETOS (vida/poder) →
-- envenena el sistema de secretos con taint de MCF → fallan comparaciones secretas ajenas
-- (PlayerFrame, ToggleGameMenu/SpellStopCasting). Este toggle apaga TODA la inyeccion para
-- diagnosticar/mitigar. Default true (comportamiento actual). db.azerite.injectionEnabled.
local function InjectionOn()
    local c = RawCfg()
    if c and c.injectionEnabled ~= nil then return c.injectionEnabled and true or false end
    return true
end
-- Sub-toggle: mutacion de COLORES + NAMEPLATES (la fuente MAS probable del taint, porque esas
-- claves se leen durante el formateo de vida/poder secretos). Se puede apagar dejando el resto
-- (desactivar modulos + skin de texturas). Default true. db.azerite.colorInjection.
local function ColorInjectionOn()
    local c = RawCfg()
    if c and c.colorInjection ~= nil then return c.colorInjection and true or false end
    return true
end

-- Preset Gonkast por defecto: color dorado FFE19B para TODOS los textos.
local PRESET_R, PRESET_G, PRESET_B = 1, 0xE1 / 255, 0x9B / 255   -- FFE19B

-- Rellena estructura de db.azerite (colors/nameplates/showBlizzardAuras). Solo tras InitDB.
local function EnsureDefaults()
    local db = ns.GetDB and ns.GetDB(); if not db then return nil end
    local c = db.azerite; if not c then c = {}; db.azerite = c end
    if c.showBlizzardAuras == nil then c.showBlizzardAuras = true end
    c.colors = c.colors or {}
    for _, cat in ipairs({ "names", "health", "power", "percent", "cast" }) do
        -- DEFAULT preset: colores ACTIVADOS con dorado FFE19B (antes use=false → no aplicaba nada).
        if type(c.colors[cat]) ~= "table" then
            c.colors[cat] = { use = true, r = PRESET_R, g = PRESET_G, b = PRESET_B }
        end
    end
    c.nameplates = c.nameplates or {}
    local np = c.nameplates
    if np.nameSize == nil then np.nameSize = 12 end
    if np.nameX == nil then np.nameX = 0 end
    if np.nameY == nil then np.nameY = 16 end
    if np.healthSize == nil then np.healthSize = 12 end
    if np.healthX == nil then np.healthX = 0 end
    if np.healthY == nil then np.healthY = -25 end

    -- MIGRACION UNA VEZ: como esto lo inyecta MCF (no se guarda en el SV de AzeriteUI), el preset
    -- "de fabrica" (todo ON, dorado, tamaños/offsets de nameplate) se FUERZA una sola vez sobre
    -- configs viejas que tenian colores en use=false. Respeta cambios futuros del usuario (flag).
    if not c._gonkastPreset then
        c._gonkastPreset = true
        c.disableTracker, c.disableInfo, c.disableMicroMenu = true, true, true   -- replaced modules ON
        for _, cat in ipairs({ "names", "health", "power", "percent", "cast" }) do
            local o = c.colors[cat]
            o.use, o.r, o.g, o.b = true, PRESET_R, PRESET_G, PRESET_B
        end
        np.nameSize, np.nameX, np.nameY = 12, 0, 16
        np.healthSize, np.healthX, np.healthY = 12, 0, -25
    end
    return c
end

-- ================== TIMING-CRITICO: corre en FILE-LOAD (antes de PLAYER_LOGIN) ==================
-- Desactiva los modulos y neutraliza Auras:DisableBlizzard ANTES de que AzeriteUI los habilite.
local function ApplyPreEnable()
    local az = AZ(); if not az then return end
    for setting, modName in pairs(MODULE_MAP) do
        local ok, mod = pcall(az.GetModule, az, modName, true)
        if ok and type(mod) == "table" and mod.SetEnabledState then
            pcall(mod.SetEnabledState, mod, not DisableWanted(setting))
        end
    end
    -- BuffFrame nativo: neutralizar DisableBlizzard antes del OnEnable de Auras.
    local c = RawCfg()
    local showBlizz = not c or c.showBlizzardAuras ~= false
    if showBlizz then
        local ok, auras = pcall(az.GetModule, az, "Auras", true)
        if ok and type(auras) == "table" and auras.DisableBlizzard then
            auras.DisableBlizzard = function() end
        end
    end
end
if InjectionOn() then
    ApplyPreEnable()             -- <-- top-level, se ejecuta al cargar el archivo.
    -- Skin (mutacion de config + hook del minimapa): SOLO si colorInjection esta activo
    -- (comparten el riesgo de taint de tocar AzeriteUI). Con colorInjection off, no se muta
    -- NINGUNA tabla de config ni se hookea nada → sin taint.
    if ColorInjectionOn() then
        pcall(ApplyAssetConfigs)
        pcall(InstallTextureHook)   -- activo ANTES del OnEnable (borde del minimapa)
    end
end

-- ================== Post-login: colores / nameplates / buffframe / opciones / skin ==================
local function ApplyModuleState()
    local az = AZ(); local c = EnsureDefaults(); if not (az and c) then return end
    for setting, modName in pairs(MODULE_MAP) do
        local ok, mod = pcall(az.GetModule, az, modName, true)
        if ok and type(mod) == "table" then
            if c[setting] then
                if mod.IsEnabled and mod:IsEnabled() and mod.Disable then pcall(mod.Disable, mod)
                elseif mod.SetEnabledState then pcall(mod.SetEnabledState, mod, false) end
            else
                if mod.SetEnabledState then pcall(mod.SetEnabledState, mod, true) end
                if mod.IsEnabled and not mod:IsEnabled() and mod.Enable then pcall(mod.Enable, mod) end
            end
        end
    end
end

local function ShowBlizzardBuffFrame()
    local az = AZ(); local c = EnsureDefaults(); if not (az and c and c.showBlizzardAuras) then return end
    local ok, auras = pcall(az.GetModule, az, "Auras", true)
    if ok and type(auras) == "table" then
        if auras.DisableBlizzard then auras.DisableBlizzard = function() end end
        if auras.blizzardBuffWatcher then
            if auras.CancelTimer then pcall(auras.CancelTimer, auras, auras.blizzardBuffWatcher) end
            auras.blizzardBuffWatcher = nil
        end
    end
    if BuffFrame then pcall(BuffFrame.SetParent, BuffFrame, UIParent) end
    if DebuffFrame then pcall(DebuffFrame.SetParent, DebuffFrame, UIParent) end
end

local function ApplyColors()
    local az = AZ(); local c = EnsureDefaults(); if not (az and az.GetConfig and c) then return end
    local colors = c.colors
    for _, cfgName in ipairs(UNIT_CONFIGS) do
        local cfg = az.GetConfig(cfgName)
        if type(cfg) == "table" then
            originals[cfgName] = originals[cfgName] or {}
            local store = originals[cfgName]
            for cat, keys in pairs(COLOR_KEYS) do
                local override = colors[cat]
                for _, key in ipairs(keys) do
                    local current = cfg[key]
                    if type(current) == "table" then
                        if store[key] == nil then store[key] = { current[1], current[2], current[3], current[4] } end
                        local orig = store[key]
                        if override and override.use then
                            cfg[key] = { override.r, override.g, override.b, orig[4] or 1 }
                        else
                            cfg[key] = { orig[1], orig[2], orig[3], orig[4] }
                        end
                    end
                end
            end
        end
    end
end

local fontCache, fontCount = {}, 0
local function BuildFont(origFont, size)
    if type(origFont) ~= "table" then return origFont end
    local face, _, flags = origFont:GetFont()
    if not face then return origFont end
    local key = face .. ":" .. size .. ":" .. (flags or "")
    local f = fontCache[key]
    if not f then
        fontCount = fontCount + 1
        f = CreateFont("MCFAzeriteNPFont" .. fontCount)
        f:SetFont(face, size, flags)
        if origFont.GetJustifyH then f:SetJustifyH(origFont:GetJustifyH() or "LEFT") end
        fontCache[key] = f
    end
    return f
end
local function ApplyNameplates()
    local az = AZ(); local c = EnsureDefaults(); if not (az and az.GetConfig and c) then return end
    local cfg = az.GetConfig("NamePlates"); if type(cfg) ~= "table" then return end
    local np = c.nameplates
    if npOrig.NameFont == nil then npOrig.NameFont = cfg.NameFont end
    if npOrig.HealthValueFont == nil then npOrig.HealthValueFont = cfg.HealthValueFont end
    if npOrig.NamePosition == nil and type(cfg.NamePosition) == "table" then
        npOrig.NamePosition = { cfg.NamePosition[1], cfg.NamePosition[2], cfg.NamePosition[3] }
    end
    if npOrig.HealthValuePosition == nil and type(cfg.HealthValuePosition) == "table" then
        npOrig.HealthValuePosition = { cfg.HealthValuePosition[1], cfg.HealthValuePosition[2], cfg.HealthValuePosition[3] }
    end
    cfg.NameFont = BuildFont(npOrig.NameFont, np.nameSize)
    cfg.HealthValueFont = BuildFont(npOrig.HealthValueFont, np.healthSize)
    if npOrig.NamePosition then cfg.NamePosition = { npOrig.NamePosition[1], np.nameX, np.nameY } end
    if npOrig.HealthValuePosition then cfg.HealthValuePosition = { npOrig.HealthValuePosition[1], np.healthX, np.healthY } end
    -- Empujar a los nameplates visibles para que el OFFSET se vea en tiempo real (best-effort).
    local ok, npMod = pcall(az.GetModule, az, "NamePlates", true)
    if ok and type(npMod) == "table" then
        for _, m in ipairs({ "UpdateAllElements", "UpdateNamePlates", "Update" }) do
            if type(npMod[m]) == "function" then pcall(npMod[m], npMod); break end
        end
    end
end

local function ApplyRuntime()
    if not InjectionOn() then return end
    ApplyModuleState()
    ShowBlizzardBuffFrame()
    -- Mutacion de tablas de config (colores/nameplates/texturas) = fuente probable del taint.
    -- Solo si colorInjection esta activo. Apagarlo detiene TODA escritura a las tablas de AzeriteUI.
    if ColorInjectionOn() then
        ApplyColors()
        ApplyNameplates()
        ApplyAssetConfigs()
    end
end
ns.ApplyAzeriteBridge = ApplyRuntime

-- ================== Skin de assets: red SECUNDARIA (barrido) ==================
-- El metodo PRIMARIO es ApplyAssetConfigs (muta las tablas de config en file-load). Esto de abajo
-- es el barrido UNICO del arbol de frames (en un timer, taint-safe) para re-apuntar texturas ya
-- puestas por vias que la config no cubrio. NO se toca ni borra ningun archivo de AzeriteUI.

-- Barrido: re-apunta las texturas ya puestas (usa RemapTexture, definida arriba).
local function WalkRemap(frame, depth)
    if depth > 40 or type(frame) ~= "table" then return end
    if frame.GetRegions then
        local ok, r1 = pcall(frame.GetRegions, frame)
        if ok and r1 ~= nil then
            for _, r in ipairs({ frame:GetRegions() }) do
                if type(r) == "table" and r.GetObjectType and r:GetObjectType() == "Texture" then
                    RemapTexture(r)
                end
            end
        end
    end
    if frame.GetChildren then
        local ok, c1 = pcall(frame.GetChildren, frame)
        if ok and c1 ~= nil then
            for _, c in ipairs({ frame:GetChildren() }) do WalkRemap(c, depth + 1) end
        end
    end
end

local assetHooked = false
local function HookAssets()
    if assetHooked then return end
    InstallTextureHook()   -- respaldo idempotente (por si el install en file-load no corrio)
    -- Envolvemos API.GetMedia (barato; cubre llamadas de GetMedia en runtime de AzeriteUI).
    local az = AZ()
    if az and az.API and az.API.GetMedia then
        local orig = az.API.GetMedia
        az.API.GetMedia = function(name, mtype)
            if name and REMAP_SET[name] then
                return REMAP_DIR .. name .. "." .. (mtype or "tga")
            end
            return orig(name, mtype)
        end
    end
    assetHooked = true
    -- 3) Barrido de las texturas ya aplicadas (diferido para no hitchear en la carga).
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function() pcall(WalkRemap, UIParent, 0) end)
    else
        pcall(WalkRemap, UIParent, 0)
    end
end

-- Pagina "Gonkast Preset" en el panel de opciones de AzeriteUI (/az).
local optionsRegistered = false
local function RegisterOptions()
    if optionsRegistered then return end
    local az = AZ(); if not az then return end
    local ok, Options = pcall(az.GetModule, az, "Options", true)
    if not ok or type(Options) ~= "table" or not Options.AddGroup then return end
    local function C() return EnsureDefaults() end
    local function tgl(info) return C()[info[#info]] end
    local function tglSet(info, v) C()[info[#info]] = v and true or false; ApplyModuleState() end
    -- Toggles con default TRUE (injectionEnabled / colorInjection). Requieren /reload.
    local function injGet(info) return C()[info[#info]] ~= false end
    local function injSet(info, v) C()[info[#info]] = v and true or false end
    local function blizzGet() return C().showBlizzardAuras end
    local function blizzSet(_, v) C().showBlizzardAuras = v and true or false; ShowBlizzardBuffFrame() end
    local function colUse(info) return C().colors[info[#info]:gsub("Use$", "")].use end
    local function colUseSet(info, v) C().colors[info[#info]:gsub("Use$", "")].use = v and true or false; ApplyColors() end
    local function colGet(info) local o = C().colors[info[#info]:gsub("Color$", "")]; return o.r, o.g, o.b end
    local function colSet(info, r, g, b) local o = C().colors[info[#info]:gsub("Color$", "")]; o.r, o.g, o.b = r, g, b; ApplyColors() end
    local function npGet(info) return C().nameplates[info[#info]] end
    local function npSet(info, v) C().nameplates[info[#info]] = v; ApplyNameplates() end
    local function merge(d, s) for k, v in pairs(s) do d[k] = v end end
    local function colorArgs(order, cat, label)
        return {
            [cat .. "Use"]   = { order = order, type = "toggle", name = "Custom " .. label .. " color", get = colUse, set = colUseSet },
            [cat .. "Color"] = { order = order + 0.5, type = "color", name = label, hasAlpha = false, get = colGet, set = colSet },
        }
    end
    local function gen()
        local args = {
            desc = { order = 1, type = "description", fontSize = "medium",
                name = "Injected by MyCustomFrames onto a clean AzeriteUI. Module toggles apply cleanly on the next /reload; colors and nameplate offsets apply live (health/power VALUE colors need /reload)." },
            taintHeader = { order = 2, type = "header", name = "Taint control (read if you get errors)" },
            taintNote = { order = 3, type = "description",
                name = "|cffff6666If you get taint errors (character panel 'secret number', ESC menu 'SpellStopCasting'), turn OFF 'Inject colors + nameplates + skin'.|r Writing AzeriteUI's config tables from another addon taints its secret (health/power) processing. The taint-free way to color AzeriteUI is editing it directly (GonkastTweaks). Requires /reload." },
            injectionEnabled = { order = 4, type = "toggle", width = "full", get = injGet, set = injSet,
                name = "Enable AzeriteUI injection (master; off = clean AzeriteUI, no taint)" },
            colorInjection = { order = 5, type = "toggle", width = "full", get = injGet, set = injSet,
                name = "Inject colors + nameplates + skin (turn OFF to stop taint)" },
            modHeader = { order = 10, type = "header", name = "Replaced modules" },
            disableTracker   = { order = 11, type = "toggle", width = "full", get = tgl, set = tglSet, name = "Disable AzeriteUI Objective Tracker" },
            disableInfo      = { order = 12, type = "toggle", width = "full", get = tgl, set = tglSet, name = "Disable AzeriteUI Info / Clock bar" },
            disableMicroMenu = { order = 13, type = "toggle", width = "full", get = tgl, set = tglSet, name = "Disable AzeriteUI Micro Menu" },
            showBlizzardAuras= { order = 14, type = "toggle", width = "full", get = blizzGet, set = blizzSet, name = "Show Blizzard buff/debuff frame" },
            colHeader = { order = 20, type = "header", name = "Text colors" },
            npHeader = { order = 40, type = "header", name = "Nameplate text" },
            nameSize   = { order = 41, type = "range", name = "Name size",   min = 6, max = 24, step = 1, get = npGet, set = npSet },
            nameX      = { order = 42, type = "range", name = "Name X",      min = -150, max = 150, step = 1, get = npGet, set = npSet },
            nameY      = { order = 43, type = "range", name = "Name Y",      min = -150, max = 150, step = 1, get = npGet, set = npSet },
            healthSize = { order = 44, type = "range", name = "Health size", min = 6, max = 24, step = 1, get = npGet, set = npSet },
            healthX    = { order = 45, type = "range", name = "Health X",    min = -150, max = 150, step = 1, get = npGet, set = npSet },
            healthY    = { order = 46, type = "range", name = "Health Y",    min = -150, max = 150, step = 1, get = npGet, set = npSet },
            reload = { order = 90, type = "execute", name = "Reload Interface", func = function() ReloadUI() end },
        }
        merge(args, colorArgs(21, "names", "Names"))
        merge(args, colorArgs(23, "health", "Health value"))
        merge(args, colorArgs(25, "power", "Power value"))
        merge(args, colorArgs(27, "percent", "Percentages"))
        merge(args, colorArgs(29, "cast", "Cast text"))
        return { name = "Gonkast Preset", type = "group", args = args }
    end
    if pcall(Options.AddGroup, Options, "Gonkast Preset", gen, -2750) then optionsRegistered = true end
end

-- Post-login: aplica todo lo runtime + registra opciones + hook de assets (auto, sin boton).
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    local tries = 0
    local function run()
        if not AZ() then return false end
        -- HookAssets (GetMedia wrap + walk) solo si la inyeccion de skin esta activa.
        if InjectionOn() and ColorInjectionOn() then HookAssets() end
        ApplyRuntime()      -- self-gated por InjectionOn/ColorInjectionOn
        RegisterOptions()   -- SIEMPRE: para que el toggle sea visible aunque la inyeccion este off
        return true
    end
    f:SetScript("OnEvent", function() run() end)
    if C_Timer and C_Timer.NewTicker then
        local t; t = C_Timer.NewTicker(1, function()
            tries = tries + 1
            if not AZ() and tries >= 8 then if t then t:Cancel() end return end
            if run() and optionsRegistered then if t then t:Cancel() end end
        end)
    end
end

-- ================== DIAGNOSTICO: /mcfskin ==================
-- Vuelca por que el reskin de assets NO se aplica: si el hook esta puesto, si GetTexture
-- devuelve string o fileDataID numerico (12.0 puede devolver numeros → nuestro match por
-- ruta fallaria), que rutas de AzeriteUI hay REALMENTE en uso, y cuantas coinciden/aplicaron.
-- Ademas fuerza un nuevo barrido de remap al final.
SLASH_MCFSKIN1 = "/mcfskin"
SlashCmdList["MCFSKIN"] = function()
    local az = AZ()
    print("|cffffcc00[MCF skin]|r AzeriteUI:", az and "detectado" or "NO", "| hook SetTexture:", assetHooked and "instalado" or "NO")

    local seen, nStr, nNum, nAz, nMatch, nMine = {}, 0, 0, 0, 0, 0
    local samples, nSamples = {}, 0
    local function scan(frame, depth)
        if depth > 40 or type(frame) ~= "table" then return end
        if frame.GetRegions then
            local ok, r1 = pcall(frame.GetRegions, frame)
            if ok and r1 ~= nil then
                for _, r in ipairs({ frame:GetRegions() }) do
                    if type(r) == "table" and r.GetObjectType and r:GetObjectType() == "Texture" then
                        local ok2, cur = pcall(r.GetTexture, r)
                        if ok2 then
                            if type(cur) == "string" then
                                nStr = nStr + 1
                                local low = cur:lower()
                                if low:find("azeriteui5_junnez_edition", 1, true) then
                                    nAz = nAz + 1
                                    if ASSET_REMAP[low] then nMatch = nMatch + 1 end
                                    if not seen[low] then
                                        seen[low] = true
                                        if nSamples < 25 then nSamples = nSamples + 1; samples[nSamples] = cur end
                                    end
                                elseif low:find("mycustomframes", 1, true) then
                                    nMine = nMine + 1
                                end
                            elseif type(cur) == "number" then
                                nNum = nNum + 1
                            end
                        end
                    end
                end
            end
        end
        if frame.GetChildren then
            local ok, c1 = pcall(frame.GetChildren, frame)
            if ok and c1 ~= nil then for _, c in ipairs({ frame:GetChildren() }) do scan(c, depth + 1) end end
        end
    end
    scan(UIParent, 0)

    print(("|cffffcc00[MCF skin]|r texturas: string=%d, fileID-numerico=%d"):format(nStr, nNum))
    print(("|cffffcc00[MCF skin]|r rutas AzeriteUI(string)=%d | coinciden con REMAP=%d | ya-MyCustomFrames=%d"):format(nAz, nMatch, nMine))
    print(("|cffffcc00[MCF skin]|r REMAP tiene %d entradas. REMAP_DIR=%s"):format((function() local n=0 for _ in pairs(ASSET_REMAP) do n=n+1 end return n end)(), REMAP_DIR))
    if nSamples > 0 then
        print("|cffffcc00[MCF skin]|r rutas AzeriteUI en uso ahora mismo (distintas):")
        for i = 1, nSamples do
            local low = samples[i]:lower()
            print(("   [%s] %s"):format(ASSET_REMAP[low] and "EN REMAP" or "no", samples[i]))
        end
    else
        print("|cffff5555[MCF skin]|r NO se hallo ninguna textura con ruta string de AzeriteUI. Si fileID-numerico>0, en 12.0 GetTexture devuelve IDs y hay que reskinnear de otra forma.")
    end
    -- Reporta la mutacion de config (metodo primario) y verifica cuantas rutas de textura
    -- de las tablas de config YA apuntan a nuestra carpeta.
    local cfgMine, cfgAz = 0, 0
    if AZ() and AZ().GetConfig then
        local seenC = {}
        local function scanCfg(t)
            if type(t) ~= "table" or seenC[t] then return end
            seenC[t] = true
            for _, v in pairs(t) do
                if type(v) == "string" then
                    local low = v:lower()
                    if low:find("mycustomframes", 1, true) and low:find("azeriteui assets", 1, true) then cfgMine = cfgMine + 1
                    elseif low:find("azeriteui5_junnez_edition", 1, true) then cfgAz = cfgAz + 1 end
                elseif type(v) == "table" then scanCfg(v) end
            end
        end
        for _, name in ipairs(ALL_ASSET_CONFIGS) do
            local ok, cfg = pcall(AZ().GetConfig, name)
            if ok then scanCfg(cfg) end
        end
    end
    print(("|cffffcc00[MCF skin]|r config tables: rutas ya-MyCustomFrames=%d, rutas AzeriteUI restantes=%d"):format(cfgMine, cfgAz))

    -- Forzar re-mutacion de config + barrido de remap ahora.
    pcall(ApplyAssetConfigs)
    pcall(WalkRemap, UIParent, 0)
    print("|cffffcc00[MCF skin]|r Metodo PRIMARIO = mutacion de config en file-load → los frames se")
    print("|cffffcc00[MCF skin]|r construyen con tus texturas. Si config 'ya-MyCustomFrames'>0 pero no lo ves,")
    print("|cffffcc00[MCF skin]|r haz |cffffff00/reload|r (los frames YA construidos no releen la config sin recargar).")
end
