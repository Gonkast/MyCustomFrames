-- ==========================================================================
-- MyCustomFrames - Tracker.lua
-- Colorea titulos/headers del ObjectiveTracker (misiones, mazmorras, escenarios), centra los
-- titulos en el eje X (offset independiente mision/escenario, ajustable en vivo desde el menu),
-- y oculta automaticamente el tracker (alpha, via SecureHandlerStateTemplate) en combate,
-- objetivo hostil, boss, arena o battleground segun toggles del menu.
--
-- HISTORIAL DE TAINT (2026-07-15, resuelto): el ADDON_ACTION_BLOCKED en
-- ObjectiveTrackerFrame:Show() (al entrar en combate justo tras interactuar con el tracker) se
-- diagnostico y descarto en este orden: (1) el boss-hider seguro — NO era la causa (desactivar
-- solo el coloreado, dejando el hider intacto, tambien arreglaba el error). (2) Tocar bloques de
-- mision individuales (SetTextColor+HookScript por bloque) — confirmado que comparte un pool de
-- widgets con los pines del mapa mundial (otro error, SetPropagateMouseClicks, en un pin AreaPOI/
-- Delve); se descarto esa via por completo. (3) TraverseFrame recorriendo TODO sin exclusiones —
-- se añadieron exclusiones (Scenario/UIWidget tracker + botones pooled de item/POI) pero el error
-- SEGUIA saliendo. (4) `PatchColorTable` (mutaba OBJECTIVE_TRACKER_COLOR, tabla GLOBAL, en cada
-- pasada) — CONFIRMADO como la causa real al desactivarla (el error desaparecio). Removida del
-- todo; el coloreado de texto sigue intacto via ApplyFontColor (SetTextColor directo, nunca toca
-- la tabla global).
-- ==========================================================================
local ADDON, ns = ...

local DEFAULT_COLOR    = { r = 1.0, g = 0.882, b = 0.607 }   -- #FFE19B
local COLOR_COMPLETA   = { r = 0.6,  g = 0.6,  b = 0.6 }
local COLOR_DIARIA     = { r = 0.53, g = 0.81, b = 0.98 }
local COLOR_RARA       = { r = 0.64, g = 0.21, b = 0.93 }
local COLOR_LEGENDARIA = { r = 1.0,  g = 0.5,  b = 0 }

local function cfg() local db = ns.GetDB and ns.GetDB(); return db and db.tracker end
local function TrackerEnabled() local c = cfg(); return c and c.enabled and true or false end
local function TitleColor() local c = cfg(); return (c and c.color) or DEFAULT_COLOR end

-- ==========================================================================
-- ESTADO EXTERNO (anti-taint). LECCION de EllesmereUI: NUNCA escribir claves propias
-- (_mcfTxt, mcfBossHider, mcfSkipTraverse...) sobre frames/tablas de BLIZZARD → las
-- contamina; Blizzard itera sus propias tablas con pairs() o llama a metodos PROTEGIDOS
-- (ObjectiveTrackerFrame:Show()) leyendo esos frames → el taint "by MyCustomFrames" se
-- propaga y BLOQUEA la funcion protegida (el bug ADDON_ACTION_BLOCKED:Show()). Todo el
-- estado por-frame vive aqui, en tablas EXTERNAS weak-keyed (setmetatable __mode="k").
-- ==========================================================================
local fsState = setmetatable({}, { __mode = "k" })      -- FontString  -> { txt, epoch, r, g, b }
local texState = setmetatable({}, { __mode = "k" })     -- Texture     -> { path, atlas, header }
local skipTraverse = setmetatable({}, { __mode = "k" }) -- frames que TraverseFrame no debe visitar
local bossHider                                          -- nuestro SecureHandler (NO se guarda en otf)

-- ==========================================================================
-- Tracker Hider (Seguro) — oculta el tracker (alpha 0, via SecureHandlerStateTemplate) segun
-- combinacion de toggles: boss fight, combate, objetivo hostil, arena, battleground. Mismo
-- mecanismo probado que ya existia solo para boss (RegisterStateDriver con conditionales de
-- macro, re-registrado SOLO si el driver cambio, NUNCA un driver constante).
-- ==========================================================================
-- Arena/Battleground NO tienen conditional de macro nativo (no existe "[arena]"/"[battleground]")
-- → se resuelven en LUA (IsInInstance) y se inyectan en el driver como un conditional SIEMPRE-
-- verdadero (`[@player,exists]`) cuando corresponde ocultar — igual patron que usa el addon en
-- PartyDriverString (UpdatePartyDrivers) para su propio caso de "ocultar por zona". Esto mantiene
-- el driver con AL MENOS un conditional real (nunca "show"/"hide" constante puro), que es lo que
-- evita la aplicacion sincrona desde codigo inseguro (ver nota abajo).
local function BuildTrackerHideDriver(c)
    local parts = {}
    if c.hideInCombat then parts[#parts + 1] = "[combat]hide" end
    if c.hideOnHostileTarget then parts[#parts + 1] = "[@target,exists,harm]hide" end
    if c.hideInBoss then
        for i = 1, 5 do parts[#parts + 1] = "[@boss" .. i .. ",exists]hide" end
    end
    if c.hideInArena or c.hideInBG then
        local ok, inInst, instType = pcall(IsInInstance)
        if ok and inInst then
            if instType == "arena" and c.hideInArena then parts[#parts + 1] = "[@player,exists]hide" end
            if instType == "pvp" and c.hideInBG then parts[#parts + 1] = "[@player,exists]hide" end
        end
    end
    if #parts == 0 then return nil end   -- nada activado: sin driver (mostrado siempre)
    parts[#parts + 1] = "show"
    return table.concat(parts, ";")
end

local function SetupBossHider()
    local otf = _G.ObjectiveTrackerFrame
    if not otf or InCombatLockdown() then return end

    if not bossHider then
        local h = CreateFrame("Frame", nil, otf, "SecureHandlerStateTemplate")
        skipTraverse[h] = true   -- TraverseFrame NO debe entrar en el handler seguro
        h:SetAttribute("_onstate-vis", [[ if newstate == "hide" then self:Hide() else self:Show() end ]])
        h:SetScript("OnHide", function() if _G.ObjectiveTrackerFrame then _G.ObjectiveTrackerFrame:SetAlpha(0) end end)
        h:SetScript("OnShow", function() if _G.ObjectiveTrackerFrame then _G.ObjectiveTrackerFrame:SetAlpha(1) end end)
        bossHider = h
    end

    local h = bossHider
    local c = cfg()
    local driver = c and BuildTrackerHideDriver(c)
    if driver then
        -- Re-registrar SOLO si cambio. Y NUNCA registrar un driver CONSTANTE ("show"):
        -- un driver sin condicionales se aplica INMEDIATO y SINCRONO dentro de nuestra
        -- llamada insegura a RegisterStateDriver → el snippet _onstate-vis se invoca
        -- desde codigo inseguro → "Cannot call restricted closure from insecure code"
        -- (RestrictedExecution.lua:470). Con condicionales, el manager lo evalua
        -- diferido en su OnUpdate seguro.
        if h._mcfDriver ~= driver then
            UnregisterStateDriver(h, "vis")
            RegisterStateDriver(h, "vis", driver)
            h._mcfDriver = driver
        end
    else
        -- Nada activado: quitar el driver del todo (nada de driver "show" constante).
        if h._mcfDriver then
            UnregisterStateDriver(h, "vis")
            h._mcfDriver = nil
        end
        h:Show()
        otf:SetAlpha(1)
    end
end

-- ==========================================================================
-- Funciones de Aplicación de Color y Centrado
-- ==========================================================================
-- NOTA (2026-07-15): existia aqui un `PatchColorTable`/`RestoreColorTable` que mutaba la tabla
-- GLOBAL `OBJECTIVE_TRACKER_COLOR` en cada pasada (cada 0.4s, sin parar). Aislado y confirmado
-- en juego (con taint.log + BugSack, varias rondas) como la causa real del
-- ADDON_ACTION_BLOCKED:ObjectiveTrackerFrame:Show() en combate — no las exclusiones de
-- TraverseFrame (que tambien se probaron y NO bastaron solas). Quitado por completo; el color de
-- titulos/headers lo sigue haciendo ApplyFontColor (SetTextColor directo sobre cada fontstring,
-- sin tocar la tabla global) via TraverseFrame, sin perder nada visible.
-- ==========================================================================
-- El NOMBRE de mision y sus OBJETIVOS usan la MISMA fuente (ObjectiveTrackerLineFont/12),
-- asi que solo se distinguen por el TEXTO. Es objetivo (NO colorear) si tiene progreso
-- "n/m", porcentaje, o empieza con "-" o con un numero. LIMITACION: objetivos SIN numero
-- ("Habla con X") son indistinguibles del titulo (misma fuente) → se colorean igual.
local function IsObjectiveLine(text)
    if not text then return false end
    if text:find("%d+%s*/%s*%d+") then return true end   -- progreso "0/10"
    if text:find("%d+%s*%%") then return true end         -- porcentaje
    if text:match("^%s*%-") then return true end          -- empieza con "-"
    if text:match("^%s*%d") then return true end          -- empieza con numero
    return false
end

-- Epoch de la cache de clasificacion: se incrementa cuando cambia la config de color
-- (RefreshTracker) para invalidar las decisiones cacheadas en los fontstrings.
local colorEpoch = 0

-- Clasifica el texto → color destino (r,g,b) o nil si no hay que tocarlo (objetivo).
-- Es la parte CARA (lower + find = basura de strings); su resultado se cachea.
local function ClassifyText(text)
    if IsObjectiveLine(text) then return nil end
    local t = text:lower()
    if t:find("completada") or t:find("complete") or t:find("terminad") then
        return COLOR_COMPLETA.r, COLOR_COMPLETA.g, COLOR_COMPLETA.b
    elseif t:find("diaria") or t:find("daily") then
        return COLOR_DIARIA.r, COLOR_DIARIA.g, COLOR_DIARIA.b
    elseif t:find("heroica") or t:find("rare") or t:find("élite") or t:find("elite") then
        return COLOR_RARA.r, COLOR_RARA.g, COLOR_RARA.b
    elseif t:find("legendaria") or t:find("legendary") then
        return COLOR_LEGENDARIA.r, COLOR_LEGENDARIA.g, COLOR_LEGENDARIA.b
    else
        local c = TitleColor()
        return c.r, c.g, c.b
    end
end

-- Distingue si un fontstring pertenece al ScenarioObjectiveTracker (titulo de mazmorra/escenario,
-- ej. "Windrunner Spire") en vez de a un bloque de mision normal (QuestObjectiveTracker, etc.) —
-- para poder darles un offset de centrado INDEPENDIENTE. Sube por la cadena de padres (acotado)
-- comparando contra el frame conocido _G.ScenarioObjectiveTracker.
local function IsScenarioTitle(fs)
    local scenario = _G.ScenarioObjectiveTracker
    if not scenario then return false end
    local ok, parent = pcall(fs.GetParent, fs)
    local depth = 0
    while ok and parent and depth < 8 do
        if parent == scenario then return true end
        depth = depth + 1
        ok, parent = pcall(parent.GetParent, parent)
    end
    return false
end

local function ApplyFontColor(fs)
    if not fs or fs:GetObjectType() ~= "FontString" then return end
    local text = fs:GetText()
    if not text or text == "" then return end

    -- Cache por fontstring (en tabla EXTERNA fsState, NO sobre el fontstring de Blizzard):
    -- si el TEXTO no cambio (y la config tampoco), se reutiliza la clasificacion y solo se
    -- re-aplica el color si Blizzard lo piso (comparacion numerica de GetTextColor, sin alocar
    -- strings). El recolor corre cada 0.4s sobre TODO el tracker: sin esta cache generaba basura
    -- de strings continuamente.
    local st = fsState[fs]
    if st and st.txt == text and st.epoch == colorEpoch then
        local r = st.r
        if r == nil then return end   -- decision cacheada: "objetivo, no tocar"
        local cr, cg, cb, a = fs:GetTextColor()
        if math.abs((cr or 0) - r) > 0.004 or math.abs((cg or 0) - st.g) > 0.004
           or math.abs((cb or 0) - st.b) > 0.004 then
            fs:SetTextColor(r, st.g, st.b, a or 1)
        end
        if fs.SetJustifyH then pcall(fs.SetJustifyH, fs, "CENTER") end
        return
    end

    local r, g, b = ClassifyText(text)
    if not st then st = {}; fsState[fs] = st end
    st.txt, st.epoch, st.r, st.g, st.b = text, colorEpoch, r, g, b
    if r == nil then return end   -- objetivo de mision: mantener su color nativo
    local a = select(4, fs:GetTextColor()) or 1
    fs:SetTextColor(r, g, b, a)
    -- Centrado en el eje X (titulos de mision, headers "Quests"/"All Objectives"...). Algunos
    -- fontstrings (ej. "All Objectives") ya tienen una caja mas ancha que su texto → SetJustifyH
    -- solo ya centra. Otros (titulos de mision) estan anclados exactamente al ancho del texto →
    -- justificar no se nota hasta darles mas ancho. El intento de anclar al PADRE con su ancho
    -- REAL fallo (el bloque de mision se auto-ajusta al contenido, sin ancho fijo confiable →
    -- volvio a verse sin centrar). Vuelta al ancho FIJO (SI se veia centrado, aunque no pixel-
    -- perfecto contra "Quests"), reusando el mismo punto/relTo/offset original (sin anclas nuevas).
    -- Solo UNA vez por fontstring (cacheado via st.widened).
    if fs.SetJustifyH then pcall(fs.SetJustifyH, fs, "CENTER") end
    -- Guarda el ancla ORIGINAL (nativa de Blizzard) UNA sola vez — leerla de nuevo en pases
    -- posteriores devolveria NUESTRO propio anclaje ya modificado, no el original, y los ajustes
    -- del slider se acumularian mal en vez de partir siempre de la misma base. Tambien clasifica
    -- UNA vez si es titulo de escenario/mazmorra (offset independiente) o de mision.
    if not st.origPoint and fs.GetNumPoints then
        local okp, point, relTo, relPoint, x, y = pcall(fs.GetPoint, fs, 1)
        if okp and point then
            st.origPoint, st.origRelTo, st.origRelPoint, st.origX, st.origY = point, relTo, relPoint, x or 0, y or 0
        end
        st.isScenario = IsScenarioTitle(fs)
    end
    -- Re-aplica si el epoch cambio (el usuario movio un slider "Title/Dungeon center offset" en
    -- el menu), no solo la primera vez — asi el ajuste se ve EN VIVO sin /reload. Siempre parte
    -- del ancla ORIGINAL guardada arriba. Offset INDEPENDIENTE segun si es titulo de mision o de
    -- escenario/mazmorra (ej. "Windrunner Spire").
    if st.widenedEpoch ~= colorEpoch and st.origPoint and fs.SetWidth then
        local c = cfg()
        local off = st.isScenario and (c and c.dungeonTitleOffsetX) or (c and c.titleOffsetX)
        local adjX = st.origX + (off or -18)
        pcall(function()
            fs:ClearAllPoints()
            fs:SetPoint(st.origPoint, st.origRelTo, st.origRelPoint, adjX, st.origY)
            fs:SetWidth(230)
        end)
        st.widenedEpoch = colorEpoch
    end
end

local function ApplyTextureColor(tex)
    if not tex or tex:GetObjectType() ~= "Texture" then return end

    -- Aplicamos color solo a texturas que parezcan separadores o headers.
    -- La CLASIFICACION (lower+find) se cachea por textura en tabla EXTERNA texState (NO sobre la
    -- textura de Blizzard); path/atlas cambian rara vez. El tinte (SetVertexColor) se re-aplica
    -- siempre por si Blizzard lo resetea.
    local path = tex:GetTexture()
    local atlas = tex.GetAtlas and tex:GetAtlas()
    local st = texState[tex]
    if not st then st = {}; texState[tex] = st end
    if st.path ~= path or st.atlas ~= atlas then
        local isHeader = false
        if type(atlas) == "string" and (atlas:lower():find("header") or atlas:lower():find("divider")) then isHeader = true end
        if type(path) == "string" and (path:lower():find("header") or path:lower():find("divider")) then isHeader = true end
        st.path, st.atlas, st.header = path, atlas, isHeader
    end

    if st.header then
        local c = TitleColor()
        if tex.SetDesaturated then tex:SetDesaturated(true) end
        tex:SetVertexColor(c.r, c.g, c.b, 1)
    end
end

-- ==========================================================================
-- Recorrido Recursivo (TraverseFrame)
-- NUNCA abortar por IsProtected. Visita propiedades, luego regions, luego children.
--
-- EXCLUSIONES (2026-07-15, evidencia de esta sesion): esta misma sesion demostro, con un
-- rewrite que tocaba bloques de mision (SetTextColor + HookScript en el bloque), que Blizzard
-- comparte un POOL DE WIDGETS entre los bloques del tracker y los PINES DEL MAPA MUNDIAL
-- (AreaPOI/Delve) — tocar esos objetos dejo el pool "tainted by MyCustomFrames" y una llamada
-- protegida POSTERIOR y AJENA (un pin de mapa, o el propio Show() del tracker) salio bloqueada.
-- TraverseFrame hace ese MISMO tipo de toque (SetTextColor/SetVertexColor via GetChildren
-- recursivo) mucho mas agresivo: sin ninguna exclusion, baja tambien dentro de los botones de
-- item/recompensa y POI de cada bloque, y dentro de ScenarioObjectiveTracker/
-- UIWidgetObjectiveTracker (que EllesmereUI documenta explicitamente como compartidos con el
-- pool de tooltips/POI). Estas exclusiones cierran esa via sin perder color de titulos/headers
-- (que viven en el bloque/header mismo, NO dentro de estos botones).
-- ==========================================================================
local visitedFrames = {}

-- Sub-trackers que comparten pool de widgets con tooltips/POI (documentado por EllesmereUI):
-- SOLO se colorea su Header; NUNCA se recorren sus bloques/hijos.
local SHALLOW_TRACKER_NAMES = {
    ScenarioObjectiveTracker = true,
    UIWidgetObjectiveTracker = true,
}

-- Campos conocidos de botones POOLED/COMPARTIDOS dentro de un bloque de mision/logro (mismos
-- nombres que usa el propio Blizzard y que referencia EllesmereUI): nunca se debe recorrer
-- (ni colorear) su interior, aunque sean hijos de un frame que si visitamos.
local RISKY_CHILD_FIELDS = {
    "ItemButton", "itemButton", "GroupFinderButton", "groupFinderButton",
    "poiButton", "rightEdgeFrame",
}

local function GetRiskyChildren(frame)
    local set
    for _, field in ipairs(RISKY_CHILD_FIELDS) do
        local child = frame[field]
        if child then
            set = set or {}
            set[child] = true
        end
    end
    return set
end

local function TraverseFrame(frame)
    if not frame or visitedFrames[frame] then return end
    -- Nuestro boss hider (SecureHandlerStateTemplate) cuelga del tracker: tocarlo desde
    -- el walk inseguro contamina su entorno restringido. Saltarlo por completo (marcado en
    -- la tabla externa skipTraverse, no con una clave sobre el frame).
    if skipTraverse[frame] then return end
    visitedFrames[frame] = true

    -- Scenario/UIWidget tracker: SOLO su Header (si lo tiene), nada de regions/children propios.
    local frameName = frame.GetName and frame:GetName()
    if frameName and SHALLOW_TRACKER_NAMES[frameName] then
        local header = frame.Header
        if header and type(header) == "table" and header.GetObjectType then
            TraverseFrame(header)
        end
        return
    end

    -- 1. Buscar en propiedades explícitas (Arquitectura de frames moderna)
    local properties = { "Text", "Title", "Header", "Label", "HeaderText" }
    for _, propName in ipairs(properties) do
        local element = frame[propName]
        if element and type(element) == "table" and element.GetObjectType then
            local objType = element:GetObjectType()
            if objType == "FontString" then
                ApplyFontColor(element)
            elseif objType == "Texture" then
                ApplyTextureColor(element)
            end
        end
    end

    -- 2. Recorrer Regions
    if frame.GetNumRegions then
        for i = 1, frame:GetNumRegions() do
            local r = select(i, frame:GetRegions())
            if r then
                local objType = r:GetObjectType()
                if objType == "FontString" then
                    ApplyFontColor(r)
                elseif objType == "Texture" then
                    ApplyTextureColor(r)
                end
            end
        end
    end

    -- 3. Recorrer Children recursivamente, EXCLUYENDO botones pooled conocidos (item/POI/group
    -- finder) — ver nota de exclusiones arriba.
    if frame.GetNumChildren then
        local risky = GetRiskyChildren(frame)
        for i = 1, frame:GetNumChildren() do
            local child = select(i, frame:GetChildren())
            if child and child ~= frame and not (risky and risky[child]) then
                TraverseFrame(child)
            end
        end
    end
end

-- ==========================================================================
-- Ejecución Principal y Eventos
-- ==========================================================================
local function RecolorTracker()
    if not TrackerEnabled() then return end
    local otf = _G.ObjectiveTrackerFrame
    if otf and (not otf.IsShown or otf:IsShown()) then
        wipe(visitedFrames)
        TraverseFrame(otf)
    end
end

ns.RefreshTracker = function()
    colorEpoch = colorEpoch + 1   -- invalida la cache de clasificacion (cambio de config)
    SetupBossHider()
    if TrackerEnabled() then
        RecolorTracker()
    end
end

-- Debounce simple para evitar ejecuciones múltiples en el mismo frame
local updatePending = false
local function ScheduleRecolor()
    if not TrackerEnabled() or updatePending then return end
    updatePending = true
    C_Timer.After(0.05, function() 
        updatePending = false
        RecolorTracker() 
    end)
end

-- Hook a las actualizaciones nativas (reemplaza el ticker permanente)
if type(_G.ObjectiveTracker_Update) == "function" then
    hooksecurefunc("ObjectiveTracker_Update", ScheduleRecolor)
end

if _G.ObjectiveTrackerFrame and type(_G.ObjectiveTrackerFrame.Update) == "function" then
    hooksecurefunc(_G.ObjectiveTrackerFrame, "Update", ScheduleRecolor)
end

local ev = CreateFrame("Frame")
local eventsToTrack = {
    "PLAYER_ENTERING_WORLD", 
    "QUEST_LOG_UPDATE", 
    "QUEST_WATCH_LIST_CHANGED",
    "QUEST_ACCEPTED", 
    "QUEST_REMOVED", 
    "SCENARIO_UPDATE", 
    "SCENARIO_CRITERIA_UPDATE",
    "ZONE_CHANGED_NEW_AREA", 
    "SUPER_TRACKING_CHANGED"
}

for _, e in ipairs(eventsToTrack) do 
    pcall(function() ev:RegisterEvent(e) end) 
end

ev:SetScript("OnEvent", function(_, event)
    -- Arena/BG se resuelven en Lua (IsInInstance) → recalcular el driver al entrar a la
    -- instancia/zona, no solo al login.
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then SetupBossHider() end
    ScheduleRecolor()
end)

-- ==========================================================================
-- DIAGNOSTICO: /mcftrackerdump — vuelca fuente/parent de cada texto del tracker
-- (solo LECTURA, no colorea) para distinguir titulo vs objetivo. Traquea una
-- mision antes de correrlo.
-- ==========================================================================
local function MCF_ShowCopyBox(text)
    local f = _G.MCFDumpFrame
    if not f then
        f = CreateFrame("Frame", "MCFDumpFrame", UIParent, "BackdropTemplate")
        f:SetSize(560, 420); f:SetPoint("CENTER"); f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 24,
            insets = { left = 6, right = 6, top = 6, bottom = 6 },
        })
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)
        local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetPoint("TOP", 0, -12); lbl:SetText("Ctrl+A  y luego  Ctrl+C  para copiar")
        local sf = CreateFrame("ScrollFrame", "MCFDumpScroll", f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 14, -34); sf:SetPoint("BOTTOMRIGHT", -32, 14)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true); eb:SetFontObject(ChatFontNormal)
        eb:SetWidth(500); eb:SetAutoFocus(false)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        sf:SetScrollChild(eb)
        f.eb = eb
    end
    f.eb:SetText(text)
    f.eb:HighlightText()
    f:Show()
    f.eb:SetFocus()
end

SLASH_MCFTRACKERDUMP1 = "/mcftrackerdump"
SlashCmdList["MCFTRACKERDUMP"] = function()
    local otf = _G.ObjectiveTrackerFrame
    if not otf then print("|cffff0000[MCF]|r No ObjectiveTrackerFrame.") return end
    local lines = { "texto | tamaño | fontObject | parent" }
    local seen = {}
    local function dumpFS(fs)
        if not fs or type(fs) ~= "table" or not fs.GetObjectType then return end
        if fs:GetObjectType() ~= "FontString" then return end
        local txt = fs:GetText()
        if not txt or txt == "" then return end
        local size, flags = "?", "?"
        pcall(function() local _; _, size, flags = fs:GetFont() end)
        local foName = "?"
        pcall(function() local fo = fs:GetFontObject(); if fo and fo.GetName then foName = fo:GetName() or "(anon)" end end)
        local parType, parName = "?", "?"
        pcall(function() local par = fs:GetParent(); if par then
            parType = (par.GetObjectType and par:GetObjectType()) or "?"
            parName = (par.GetName and par:GetName()) or "(anon)"
        end end)
        lines[#lines + 1] = string.format("%s | sz=%s fl=%s | fo=%s | par=%s(%s)",
            tostring(txt):sub(1, 30), tostring(size), tostring(flags), tostring(foName), tostring(parType), tostring(parName))
    end
    local function walk(frame, depth)
        if not frame or seen[frame] or depth > 14 then return end
        seen[frame] = true
        for _, pn in ipairs({ "Text", "Title", "Header", "Label", "HeaderText" }) do
            local e = frame[pn]
            if e and type(e) == "table" and e.GetObjectType then dumpFS(e) end
        end
        if frame.GetNumRegions then
            for i = 1, frame:GetNumRegions() do dumpFS(select(i, frame:GetRegions())) end
        end
        if frame.GetNumChildren then
            for i = 1, frame:GetNumChildren() do walk(select(i, frame:GetChildren()), depth + 1) end
        end
    end
    walk(otf, 0)
    MCF_ShowCopyBox(table.concat(lines, "\n"))
end

-- Red de seguridad LENTA: Blizzard re-colorea el TITULO de la mision tras sus
-- updates (y en mouseover / tras reload), pisando nuestro color. Este re-aplicado
-- periodico corre DESPUES y lo mantiene. Barato (solo SetTextColor cosmetico;
-- mismo perfil de taint que el hook, que ya toca los frames). Si prefieres la
-- version 100% sin ticker, borra esta linea (el titulo quedara flaky).
--
-- 2026-07-15: "Hide in preview" (db.lockHide.tracker, toggle en Editing) — oculta el
-- ObjectiveTrackerFrame SOLO mientras el addon esta en modo edicion/preview (`ns.IsUnlocked()`),
-- para que no estorbe visualmente mientras se mueven/editan otros elementos. SOLO por ALPHA
-- (SetAlpha 0/1), NUNCA Show()/Hide() del frame protegido (mismo patron que HB_HideAlpha en
-- core.lua y el boss-hider de mas arriba: el alpha no requiere permiso seguro, Show/Hide del
-- ObjectiveTrackerFrame protegido desde codigo inseguro SI puede tainear/bloquear). Corre
-- SIEMPRE (independiente de TrackerEnabled/Colorize titles) en el mismo ticker de 0.4s.
-- FIX (2026-07-16, reportado por el usuario: "hide on hostile target" del boss-hider parpadeaba,
-- desaparecia y reaparecia casi al instante): este ticker de 0.4s forzaba SIEMPRE
-- otf:SetAlpha(1) cuando NO estaba en preview, pisando el alpha=0 que el boss-hider seguro
-- (SetupBossHider/OnHide, mas arriba) acababa de aplicar al cambiar de target/combate. Ahora
-- SOLO toca el alpha para (a) esconder en preview, o (b) restaurarlo cuando ES este mismo
-- codigo el que lo habia escondido (previewApplied) — nunca pisa el alpha del boss-hider.
local previewApplied = false
local function ApplyPreviewHide()
    local otf = _G.ObjectiveTrackerFrame
    if not otf then return end
    local db = ns.GetDB and ns.GetDB()
    local hide = ns.IsUnlocked and ns.IsUnlocked() and db and db.lockHide and db.lockHide.tracker
    if hide then
        otf:SetAlpha(0)
        previewApplied = true
    elseif previewApplied then
        otf:SetAlpha(1)
        previewApplied = false
    end
end
ns.ApplyTrackerPreviewHide = ApplyPreviewHide   -- expuesto para reaccionar AL TOQUE (ver Options.lua OnUnlockChanged)
C_Timer.NewTicker(0.4, function()
    ApplyPreviewHide()
    RecolorTracker()
end)