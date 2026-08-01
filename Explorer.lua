--[[Perfy has instrumented this file]] local Perfy_GetTime, Perfy_Trace, Perfy_Trace_Passthrough = Perfy_GetTime, Perfy_Trace, Perfy_Trace_Passthrough; Perfy_Trace(Perfy_GetTime(), "Enter", "(main chunk) MyCustomFrames/Explorer.lua"); local ADDON, ns = ...

-- EXPLORER (#11): elementos que se auto-ocultan y aparecen con MOUSEOVER (o en combate).
-- Extraido de core.lua (2026-07-22, "que se puede sacar del core") -- mismo criterio ya
-- usado con Units/Portraits/Auras/InfoBar/Editing: subsistema cohesivo, sin dependencias
-- de otros locals de core.lua salvo los ya expuestos via ns (GetDB/IsUnlocked/frames/
-- portraits/auras/tickState).

-- Mapa elementKey -> frame raiz del elemento.
-- Ampliado (2026-07-24, pedido del usuario: "que tal probable es agregar
-- minimap/topwidget/classpower/raid al explorer"): minimap/topwidget usan
-- root propio (mismo patron que infobar); classpower/raid son SecureFrame
-- (raidHeader = SecureGroupHeaderTemplate) -- SOLO se les toca SetAlpha
-- (nunca Show/Hide/SetPoint/RegisterEvent), la MISMA tecnica que ya usa
-- este archivo para portraits/units protegidos en combate (ver
-- _mcfCombatHidden y el comentario de HB_HideAlpha en core.lua: SetAlpha
-- esta probado seguro en frames protegidos, nunca causo taint) -- no hay
-- riesgo nuevo de ADDON_ACTION_FORBIDDEN por esto.
local function GetElementFrame(key) Perfy_Trace(Perfy_GetTime(), "Enter", "GetElementFrame MyCustomFrames/Explorer.lua:19:6");
    if key == "micromenu" then return Perfy_Trace_Passthrough("Leave", "GetElementFrame MyCustomFrames/Explorer.lua:19:6", ns.micromenu) end
    if key == "infobar" then return Perfy_Trace_Passthrough("Leave", "GetElementFrame MyCustomFrames/Explorer.lua:19:6", ns.infobar and ns.infobar.root) end
    if key == "tracker" then return Perfy_Trace_Passthrough("Leave", "GetElementFrame MyCustomFrames/Explorer.lua:19:6", _G.ObjectiveTrackerFrame) end
    if key == "minimap" then return Perfy_Trace_Passthrough("Leave", "GetElementFrame MyCustomFrames/Explorer.lua:19:6", ns.minimap and ns.minimap.root) end
    if key == "topwidget" then return Perfy_Trace_Passthrough("Leave", "GetElementFrame MyCustomFrames/Explorer.lua:19:6", ns.topWidgetHolder) end
    if key == "classpower" then return Perfy_Trace_Passthrough("Leave", "GetElementFrame MyCustomFrames/Explorer.lua:19:6", _G.MyCF_ClassPower) end
    if key == "raid" then return Perfy_Trace_Passthrough("Leave", "GetElementFrame MyCustomFrames/Explorer.lua:19:6", _G.MyCF_RaidHeader) end
    -- Barras de Bartender4 (2026-07-24, pedido del usuario) -- mismos nombres
    -- reales ya usados/confirmados en BartenderScale.lua (BT4Bar1-10 +
    -- BT4BarPetBar/StanceBar/BagBar/ExtraActionBar). SetAlpha nada mas, mismo
    -- criterio que classpower/raid arriba.
    if key:sub(1, 6) == "BT4Bar" then return Perfy_Trace_Passthrough("Leave", "GetElementFrame MyCustomFrames/Explorer.lua:19:6", _G[key]) end
    if ns.frames[key] then return Perfy_Trace_Passthrough("Leave", "GetElementFrame MyCustomFrames/Explorer.lua:19:6", ns.frames[key].button) end
    if ns.portraits[key] then return Perfy_Trace_Passthrough("Leave", "GetElementFrame MyCustomFrames/Explorer.lua:19:6", ns.portraits[key].root) end
    if ns.auras[key] then return Perfy_Trace_Passthrough("Leave", "GetElementFrame MyCustomFrames/Explorer.lua:19:6", ns.auras[key].root) end
    Perfy_Trace(Perfy_GetTime(), "Leave", "GetElementFrame MyCustomFrames/Explorer.lua:19:6"); return nil
end
ns.GetElementFrame = GetElementFrame

-- ==========================================================================
-- Registro MAESTRO de elementos controlables por Explorer (2026-07-24,
-- "unificar" -- antes Options.lua y Setup.lua mantenian 2 listas
-- HARDCODEADAS por separado; se desincronizaron una vez ya (playerpower no
-- se agregaba solo a un usuario que ya tenia "Player" prendido de antes).
-- Una sola fuente: Options.lua (menu principal) y Setup.lua (wizard) leen
-- de ns.EXPLORER_ELEMENTS en vez de mantener su propia copia.
-- wizard=true -> aparece en la pagina 5 del Setup Wizard.
-- wizardRecommended=true -> ahi mismo, pre-marcado como recomendado.
-- ==========================================================================
ns.EXPLORER_ELEMENTS = {
    { label = "Player", keys = { "player", "playerpower" }, wizard = true, wizardRecommended = true },
    { label = "Player portrait", keys = { "portrait_player" }, wizard = true },
    { label = "Micro menu", keys = { "micromenu" }, wizard = true, wizardRecommended = true },
    { label = "Info bar", keys = { "infobar" }, wizard = true },
    { label = "Pet", keys = { "pet", "portrait_pet" }, wizard = true, wizardRecommended = true },
    { label = "Target", keys = { "target", "targetpower", "portrait_target" }, wizard = true },
    { label = "Target of Target", keys = { "targettarget", "portrait_tot" } },
    { label = "Focus unit frame", keys = { "focus" }, wizard = true, wizardRecommended = true },
    -- Player/Target/Focus/Party/Arena auras: NINGUNA gestionable desde Explorer
    -- (2026-07-27). Las 5 viven en AuraHoverPreview.lua, con SU PROPIO sistema
    -- de revelado (hover/combate/casteo/siempre-si-existe-target segun el
    -- grupo) -- Explorer las manejaba cuando Player/Target eran un grid fijo
    -- en Auras.lua, pero ese sistema ya no existe (ver el comentario largo en
    -- core.lua, AURAS).
    { label = "Party 1", keys = { "party1", "portrait_party1" } },
    { label = "Party 2", keys = { "party2", "portrait_party2" } },
    { label = "Party 3", keys = { "party3", "portrait_party3" } },
    { label = "Party 4", keys = { "party4", "portrait_party4" } },
    { label = "Party 5", keys = { "party5", "portrait_party5" } },
    { label = "Boss 1", keys = { "boss1" } },
    { label = "Boss 2", keys = { "boss2" } },
    { label = "Boss 3", keys = { "boss3" } },
    { label = "Boss 4", keys = { "boss4" } },
    { label = "Boss 5", keys = { "boss5" } },
    { label = "Arena Player", keys = { "arena_player", "portrait_arena_player" } },
    { label = "Arena Ally 1", keys = { "arena_party1", "portrait_arena_party1" } },
    { label = "Arena Ally 2", keys = { "arena_party2", "portrait_arena_party2" } },
    { label = "Arena Enemy 1", keys = { "arena_enemy1", "portrait_arena_enemy1" } },
    { label = "Arena Enemy 2", keys = { "arena_enemy2", "portrait_arena_enemy2" } },
    { label = "Arena Enemy 3", keys = { "arena_enemy3", "portrait_arena_enemy3" } },
    { label = "Quest tracker", keys = { "tracker" } },
    -- Nuevos (2026-07-24): minimap/topwidget/classpower/raid.
    { label = "Minimap", keys = { "minimap" } },
    { label = "Top widget", keys = { "topwidget" } },
    { label = "Class power", keys = { "classpower" } },
    { label = "Raid frames", keys = { "raid" } },
    -- Barras de accion de Bartender4 (2026-07-24, pedido del usuario). Los
    -- keys son los nombres REALES de frame (BT4Bar1-10 + los 4 con nombre
    -- propio, confirmados via /mcfbt4diag) -- GetElementFrame los resuelve
    -- directo por ese mismo nombre, sin mapeo aparte.
    { label = "Action Bar 1", keys = { "BT4Bar1" } },
    { label = "Action Bar 2", keys = { "BT4Bar2" } },
    { label = "Action Bar 3", keys = { "BT4Bar3" } },
    { label = "Action Bar 4", keys = { "BT4Bar4" } },
    { label = "Action Bar 5", keys = { "BT4Bar5" } },
    { label = "Action Bar 6", keys = { "BT4Bar6" } },
    { label = "Action Bar 7", keys = { "BT4Bar7" } },
    { label = "Action Bar 8", keys = { "BT4Bar8" } },
    { label = "Action Bar 9", keys = { "BT4Bar9" } },
    { label = "Action Bar 10", keys = { "BT4Bar10" } },
    { label = "Pet Bar", keys = { "BT4BarPetBar" } },
    { label = "Stance Bar", keys = { "BT4BarStanceBar" } },
    { label = "Bag Bar", keys = { "BT4BarBagBar" } },
    { label = "Extra Action Bar", keys = { "BT4BarExtraActionBar" } },
}

-- FIX (2026-07-24, "las de bartender tambien deberian mostrarse en mouse
-- over"): Bartender4 NO redimensiona el frame de la barra para que envuelva
-- SUS botones (el frame de la barra puede quedar mas chico/desalineado que
-- la grilla real de botones que dibuja encima) -- f:IsMouseOver() sobre la
-- barra en si no detectaba el mouse sobre sus propios botones. Para keys
-- "BT4Bar*" se chequea TAMBIEN cada hijo directo (los botones de accion),
-- no solo el frame contenedor. Acotado a Bartender4 (no a los ~45 elementos
-- restantes) para no pagar un GetChildren()+loop extra cada frame en todo
-- lo demas, que ya funciona bien solo con el frame propio.
local function IsMouseOverElement(f, key) Perfy_Trace(Perfy_GetTime(), "Enter", "IsMouseOverElement MyCustomFrames/Explorer.lua:115:6");
    if f:IsMouseOver() then Perfy_Trace(Perfy_GetTime(), "Leave", "IsMouseOverElement MyCustomFrames/Explorer.lua:115:6"); return true end
    if key:sub(1, 6) ~= "BT4Bar" then Perfy_Trace(Perfy_GetTime(), "Leave", "IsMouseOverElement MyCustomFrames/Explorer.lua:115:6"); return false end
    local ok, children = pcall(function() Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/Explorer.lua:118:31"); return Perfy_Trace_Passthrough("Leave", "(anonymous) MyCustomFrames/Explorer.lua:118:31", { f:GetChildren() }) end)
    if not ok then Perfy_Trace(Perfy_GetTime(), "Leave", "IsMouseOverElement MyCustomFrames/Explorer.lua:115:6"); return false end
    for _, c in ipairs(children) do
        if c.IsMouseOver and c:IsMouseOver() then Perfy_Trace(Perfy_GetTime(), "Leave", "IsMouseOverElement MyCustomFrames/Explorer.lua:115:6"); return true end
    end
    Perfy_Trace(Perfy_GetTime(), "Leave", "IsMouseOverElement MyCustomFrames/Explorer.lua:115:6"); return false
end

-- Fade por MOUSEOVER (`IsMouseOver` funciona sin EnableMouse = geometrico). El fade corre
-- por FRAME (OnUpdate de explorerDriver) con suavizado EXPONENCIAL independiente del
-- framerate: el lerp fijo del ticker de 0.1s se veia a saltos (10 pasos/seg = "lag").
-- Revelar es mas rapido que ocultar (mas natural). El estado de combate lo refresca el
-- ticker (secret-safe via pcall); aqui solo se anima. db.explorerEnabled = toggle maestro.
local explorerDriver = CreateFrame("Frame", nil, UIParent)
explorerDriver:Hide()
explorerDriver:SetScript("OnUpdate", ns.Prof.Wrap("Explorer: driver", function(self, dt) Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/Explorer.lua:133:70");
    local db = ns.GetDB()
    if not (db and db.explorer and db.explorerEnabled ~= false) or ns.IsUnlocked() then Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/Explorer.lua:133:70"); return end
    local lo = db.explorerFadeAlpha or 0
    -- Factor por half-life: el alpha recorre la mitad de la distancia cada X segundos.
    local kIn  = 1 - 0.5 ^ (dt / 0.06)   -- revelar (half-life ~60ms)
    local kOut = 1 - 0.5 ^ (dt / 0.20)   -- ocultar (mas pausado)
    -- Opacidad oculta CUSTOM por elemento (2026-07-24, pedido del usuario):
    -- db.explorerElementAlpha[key] pisa el "Hidden opacity" global SOLO para
    -- ESE key puntual -- nil/ausente = usa el default global (lo) como
    -- siempre. Guardado por key RAW (no por grupo/label): cada companion key
    -- de un grupo (ej. "player" y "playerpower") puede tener su propio
    -- override independiente si hace falta, sin logica extra.
    local eAlpha = db.explorerElementAlpha
    for key, on in pairs(db.explorer) do
        if on then
            local f = GetElementFrame(key)
            -- _mcfCombatHidden: portrait "oculto" via alpha en combate (frame protegido);
            -- su alpha lo gestiona PortraitSetShown, no el Explorer.
            if f and f:IsShown() and not f._mcfCombatHidden then
                -- Pedido del usuario 2026-07-24: "si la barra uno de bartender se vuelve la
                -- de reemplazo o posses bar, se muestre aunque este el explorer on" -- SOLO
                -- BT4Bar1 (el usuario aclaro despues "solo me interesa en la 1", no todas).
                -- FIX previo: HasOverrideActionBar/HasVehicleActionBar solo detectan
                -- VEHICULOS reales, no el caso comun de estar simplemente MONTADO (una
                -- montura normal no dispara esas API) -- se agrego IsMounted() tambien.
                local forceOverride = (key == "BT4Bar1") and self.overrideBar
                local myLo = (eAlpha and eAlpha[key]) or lo
                local target = (self.combat or self.showTgt or self.casting or forceOverride or IsMouseOverElement(f, key)) and 1 or myLo
                -- "Solo ver la barra 1" (2026-07-28, ExplorerAuto.lua): cuando la
                -- barra 1 esta REEMPLAZADA (vehiculo/override/possess) y la opcion
                -- esta puesta, las BT4Bar2-10 se ocultan del todo. Va DESPUES de
                -- calcular `target` y lo pisa a proposito: tiene que ganarle a
                -- combate, target, casteo y hover, que si no la volverian a
                -- revelar. Alpha 0 y no `myLo` porque el pedido es no verlas.
                --
                -- La condicion vive en ExplorerAuto y NO usa IsMounted -- a
                -- diferencia de `overrideBar` de arriba, que si lo usa porque su
                -- proposito es el contrario (mantener la 1 visible al montarte).
                if ns.ExplorerBarForceHidden and ns.ExplorerBarForceHidden(key) then
                    -- Le gana a combate, target y casteo, pero NO al hover: con
                    -- la barra escondida el mouseover la sigue revelando, igual
                    -- que en el modo normal del Explorer (pedido del usuario).
                    -- Un frame en alpha 0 sigue recibiendo eventos de mouse --
                    -- es de hecho como funciona todo el Explorer.
                    target = IsMouseOverElement(f, key) and 1 or 0
                end
                local cur = f._exAlpha; if cur == nil then cur = f:GetAlpha() end
                cur = cur + (target - cur) * (target > cur and kIn or kOut)
                if math.abs(target - cur) < 0.003 then cur = target end
                f._exAlpha = cur
                f:SetAlpha(cur)
                -- QUIRK de WoW: los frames Model/PlayerModel NO heredan el alpha del
                -- padre → el retrato 3D no se desvanecia con el resto. Se aplica a
                -- mano, multiplicado por su opacidad configurada (modelAlpha).
                local pu = ns.portraits[key]
                if pu and pu.model then
                    pu.model:SetAlpha(cur * (ns.PP(pu).modelAlpha or 1))
                end
                -- MISMO QUIRK, otra causa (2026-07-27, reportado con captura: "quedan
                -- algunos iconos apareciendo" cuando se esconde el minimapa): el ojo
                -- de cola de grupo (QueueStatusButton, LayoutEye en Minimap.lua) se
                -- reparenta a `mm.eyeHolder`, un frame PROPIO -- nunca hijo de `root`
                -- a proposito, para no tainear root (ver el comentario largo de
                -- LayoutEye: reparentar el boton PROTEGIDO de Blizzard adentro de
                -- root dejaba root sin poder llamar SetScale nunca mas). Al no ser
                -- descendiente de root, nunca heredo su alpha -- se sincroniza a mano
                -- aca, igual que el modelo 3D arriba.
                if key == "minimap" and ns.minimap and ns.minimap.eyeHolder then
                    ns.minimap.eyeHolder:SetAlpha(cur)
                end
                -- FIX (2026-07-27, la parte que realmente faltaba de ese mismo
                -- reporte -- ver el comentario largo en Minimap.lua/
                -- ns.SetMinimapPinsShown): los pines nativos (tracking, flecha del
                -- jugador) ni siquiera son hijos alcanzables desde Lua, e ignoran
                -- CUALQUIER alpha por SetIgnoreParentAlpha -- la unica salida es
                -- reposicionar el Minimap entero fuera de pantalla. Se ata a
                -- `target` (no a `cur`, el valor YA suavizado) para que la
                -- decision sea binaria e inmediata: en cuanto deja de estar
                -- revelado (target < 1), los pines desaparecen ya mismo, aunque
                -- el resto (backdrop/anillo/ojo) siga su fade suave de costumbre.
                if key == "minimap" and ns.SetMinimapPinsShown then
                    ns.SetMinimapPinsShown(target == 1)
                end
            end
        end
    end
Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/Explorer.lua:133:70"); end))
ns.ExplorerReset = function(key) Perfy_Trace(Perfy_GetTime(), "Enter", "ns.ExplorerReset MyCustomFrames/Explorer.lua:221:19");   -- llamar al APAGAR el explorer de un elemento
    local f = GetElementFrame(key)
    if f then f._exAlpha = nil; f:SetAlpha(1) end
    -- Restaurar tambien el alpha manual del modelo 3D (no hereda del padre).
    local pu = ns.portraits[key]
    local db = ns.GetDB()
    if pu and pu.model and db then pu.model:SetAlpha(ns.PP(pu).modelAlpha or 1) end
    -- Mismo motivo que arriba: el ojo de cola vive en un frame propio, aparte
    -- de root -- sin esto, al apagar Explorer para "minimap" el ojo se podia
    -- quedar congelado en el alpha bajo del ultimo fade.
    if key == "minimap" and ns.minimap and ns.minimap.eyeHolder then
        ns.minimap.eyeHolder:SetAlpha(1)
    end
    if key == "minimap" and ns.SetMinimapPinsShown then
        ns.SetMinimapPinsShown(true)
    end
    -- Mismo motivo (2026-07-27): apagar SOLO "Pet Bar" en la lista de
    -- elementos del Explorer (no el master toggle) pasa por aca, no por
    -- ExplorerResetAll -- necesita el mismo parche.
    if key == "BT4BarPetBar" and ns.RefreshPetBarVisibility then
        ns.RefreshPetBarVisibility()
    end
Perfy_Trace(Perfy_GetTime(), "Leave", "ns.ExplorerReset MyCustomFrames/Explorer.lua:221:19"); end
ns.ExplorerResetAll = function() Perfy_Trace(Perfy_GetTime(), "Enter", "ns.ExplorerResetAll MyCustomFrames/Explorer.lua:244:22");   -- llamar al APAGAR el toggle maestro
    local db = ns.GetDB()
    if not (db and db.explorer) then Perfy_Trace(Perfy_GetTime(), "Leave", "ns.ExplorerResetAll MyCustomFrames/Explorer.lua:244:22"); return end
    for key in pairs(db.explorer) do ns.ExplorerReset(key) end
Perfy_Trace(Perfy_GetTime(), "Leave", "ns.ExplorerResetAll MyCustomFrames/Explorer.lua:244:22"); end

-- ==========================================================================
-- PERFILES RAPIDOS (2026-07-27, pedido del usuario): 3 configuraciones de
-- "que elementos gestiona el Explorer" para aplicar de un click, en vez de
-- tocar los ~31 toggles de la pestaña Elements a mano cada vez que se quiere
-- cambiar de modo.
--
-- ALCANCE (deliberadamente acotado): solo tocan MEMBRESIA (db.explorer, que
-- elemento esta prendido/apagado). NINGUNO toca Hidden opacity/Always show on
-- target/Always show while casting/Active in -- el usuario no pidio eso, y
-- cambiarlo en silencio pisaria ajustes suyos que no vienen al caso. La UNICA
-- excepcion es "Combat", que ademas prende "Always show in combat": sin eso
-- el perfil no cumpliria lo que promete (barras que se revelan solas al
-- entrar en combate) -- las mantendria SIEMPRE ocultas hasta pasar el mouse,
-- incluso en pelea.
-- ==========================================================================
local QUICK_PROFILES = {
    exploration = {
        label = "Exploration",
        -- Ampliado (2026-07-27, pedido del usuario): "deberia mantener el
        -- info bar y micromenu" -- se suman a las 3 excepciones de antes.
        desc = "Hides almost everything until you mouse over it. Minimap, your unit frame, portrait, info bar and micro menu stay always visible.",
        mode = "all_except",
        exceptLabels = {
            Minimap = true, Player = true, ["Player portrait"] = true,
            ["Info bar"] = true, ["Micro menu"] = true,
        },
    },
    combat = {
        label = "Combat",
        desc = "Only your action bars fade out, revealing automatically when you enter combat. Everything else stays visible.",
        mode = "keys_matching",
        match = function(key) Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/Explorer.lua:281:16"); return Perfy_Trace_Passthrough("Leave", "(anonymous) MyCustomFrames/Explorer.lua:281:16", key:sub(1, 6) == "BT4Bar") end,
        forceCombat = true,
    },
    minimal = {
        label = "Minimal",
        -- Cambiado (2026-07-27, pedido del usuario): "el minimal si apagar
        -- todo" -- ya no exceptua el minimapa. Sin exceptLabels, "all_except"
        -- no exceptua nada -> las 61 claves quedan gestionadas.
        desc = "Hides everything, no exceptions.",
        mode = "all_except",
    },
}
ns.EXPLORER_QUICK_PROFILES = QUICK_PROFILES

function ns.ApplyExplorerQuickProfile(name) Perfy_Trace(Perfy_GetTime(), "Enter", "ns.ApplyExplorerQuickProfile MyCustomFrames/Explorer.lua:295:0");
    local prof = QUICK_PROFILES[name]
    local db = ns.GetDB and ns.GetDB()
    if not prof or not db then Perfy_Trace(Perfy_GetTime(), "Leave", "ns.ApplyExplorerQuickProfile MyCustomFrames/Explorer.lua:295:0"); return end
    db.explorer = db.explorer or {}
    -- Alpha=1 en TODO lo que estaba gestionado antes de pisar el mapa entero --
    -- mismo camino que ya usa el toggle maestro al apagarse (ver arriba), evita
    -- que algo quede congelado a mitad de un desvanecido.
    ns.ExplorerResetAll()

    for _, e in ipairs(ns.EXPLORER_ELEMENTS) do
        for _, k in ipairs(e.keys) do
            local on
            if prof.mode == "all_except" then
                on = not (prof.exceptLabels and prof.exceptLabels[e.label])
            else
                on = prof.match(k) and true or false
            end
            -- Mismo patron que el toggle manual (Options.lua MakeToggle): nunca
            -- se guarda `false` explicito, solo `true` o ausente (nil).
            db.explorer[k] = on or nil
        end
    end

    db.explorerEnabled = true
    if prof.forceCombat then db.explorerCombat = true end
Perfy_Trace(Perfy_GetTime(), "Leave", "ns.ApplyExplorerQuickProfile MyCustomFrames/Explorer.lua:295:0"); end

-- Tipo de contenido actual → clave de db.explorerZones. IsInInstance devuelve:
-- "none"(mundo)/"party"(mazmorra)/"raid"/"arena"/"pvp"(BG)/"scenario"(escenario/delve).
local EXPLORER_ZONE_MAP = {
    none = "world", party = "dungeon", raid = "raid",
    arena = "arena", pvp = "battleground", scenario = "scenario",
}
local function ExplorerZoneAllowed() Perfy_Trace(Perfy_GetTime(), "Enter", "ExplorerZoneAllowed MyCustomFrames/Explorer.lua:329:6");
    local db = ns.GetDB()
    local z = db and db.explorerZones
    if not z then Perfy_Trace(Perfy_GetTime(), "Leave", "ExplorerZoneAllowed MyCustomFrames/Explorer.lua:329:6"); return true end
    local key = "world"
    local ok, inInst, it = pcall(IsInInstance)
    if ok and not (issecretvalue and (issecretvalue(inInst) or issecretvalue(it))) then
        if inInst and it then key = EXPLORER_ZONE_MAP[it] or "world" end
    end
    return Perfy_Trace_Passthrough("Leave", "ExplorerZoneAllowed MyCustomFrames/Explorer.lua:329:6", z[key] ~= false)
end
ns.ExplorerZoneAllowed = ExplorerZoneAllowed

-- ==========================================================================
-- Condicion "recibi daño" -- REVERTIDA (2026-07-24). Intentada via
-- COMBAT_LOG_EVENT_UNFILTERED, pero el RegisterEvent de ese evento resulto
-- estar bloqueado (ADDON_ACTION_FORBIDDEN) en la cuenta/sesion del usuario
-- de forma persistente, NO solo durante combate -- el intento de reintentar
-- con C_Timer + pcall solo logro que el error se repitiera en loop (pcall
-- NO protege contra ADDON_ACTION_FORBIDDEN, ese error se reporta igual). Sin
-- una forma confiable de registrar ese evento en este cliente, se saca la
-- funcion entera en vez de dejar un addon que spamea errores.

-- Llamado desde el ticker central de core.lua (10Hz) -- solo refresca el estado de
-- combate/target/casteo (del snapshot ns.tickState) y enciende/apaga el driver de
-- animacion; la animacion en si corre en el OnUpdate de arriba, no aqui.
ns.TickExplorer = function() Perfy_Trace(Perfy_GetTime(), "Enter", "ns.TickExplorer MyCustomFrames/Explorer.lua:355:18");
    local db = ns.GetDB()
    if not db then Perfy_Trace(Perfy_GetTime(), "Leave", "ns.TickExplorer MyCustomFrames/Explorer.lua:355:18"); return end
    local exOn = db.explorerEnabled ~= false and db.explorer and next(db.explorer) ~= nil
        and ExplorerZoneAllowed()
    if exOn then
        explorerDriver.combat = (db.explorerCombat and ns.tickState.inCombat) or false
        explorerDriver.showTgt = (db.explorerTarget and UnitExists("target")) or false
        -- Casteo/canalizacion del PLAYER: revela al instante (ReadCastMode es secret-safe;
        -- el fade de revelado tiene half-life ~60ms → se percibe inmediato).
        explorerDriver.casting = (db.explorerCasting and ns.ReadCastMode("player") ~= nil) or false
        -- Barras de Bartender4 forzadas visibles si el player esta montado o en un
        -- vehiculo/override/possess real (ver el "forceOverride" del OnUpdate de
        -- arriba). Secret-safe via ns.safeBool (mismo criterio que el resto del
        -- addon para cualquier UnitXxx/HasXxx/IsMounted que pueda devolver un valor
        -- secreto en Midnight 12.0.7).
        -- MISMA definicion de "la barra 1 esta reemplazada" que usa el
        -- ocultamiento de las otras barras: la condicional de macro que evalua
        -- Blizzard (ver ns.Bar1IsReplaced en ExplorerAuto.lua). Antes esto tenia
        -- su propia lista de APIs e incluia IsMounted(), asi que una montura
        -- NORMAL forzaba la barra 1 visible -- reportado 2026-07-28: "si es una
        -- montura normal, no deberia porque estar activa". Montarse no reemplaza
        -- la barra; las condicionales overridebar/possessbar/vehicleui si
        -- describen exactamente cuando pasa.
        --
        -- Tener las dos features leyendo la MISMA condicion tambien evita que se
        -- contradigan: seria absurdo que una considere reemplazada la barra 1 y
        -- la otra no.
        explorerDriver.overrideBar = (ns.Bar1IsReplaced and ns.Bar1IsReplaced()) or false
    elseif explorerDriver._wasOn then
        -- Se apago (zona no permitida o master off): restaurar alpha 1 UNA vez.
        if ns.ExplorerResetAll then ns.ExplorerResetAll() end
        -- FIX (2026-07-27, reportado: "el pet bar volvio a salir entre cambio de
        -- explorer mode on y off, aun sin tener pet activa, necesito reload para
        -- ocultarla"): mismo bug ya arreglado el 2026-07-25 para Lock mode (ver
        -- ApplyAllBarScales en BartenderScale.lua) pero por OTRA via -- este
        -- ticker central tambien llama ExplorerResetAll() (SetAlpha(1) a TODO lo
        -- gestionado, incluida BT4BarPetBar) cada vez que el Explorer se apaga
        -- (master toggle off, o zona no permitida), sin reaplicar despues el
        -- ocultado por "sin mascota". Mismo parche: reaplicar ahora mismo.
        if ns.RefreshPetBarVisibility then ns.RefreshPetBarVisibility() end
    end
    explorerDriver._wasOn = exOn and true or false
    explorerDriver:SetShown(exOn and true or false)
Perfy_Trace(Perfy_GetTime(), "Leave", "ns.TickExplorer MyCustomFrames/Explorer.lua:355:18"); end

Perfy_Trace(Perfy_GetTime(), "Leave", "(main chunk) MyCustomFrames/Explorer.lua");