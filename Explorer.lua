local ADDON, ns = ...

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
local function GetElementFrame(key)
    if key == "micromenu" then return ns.micromenu end
    if key == "infobar" then return ns.infobar and ns.infobar.root end
    if key == "tracker" then return _G.ObjectiveTrackerFrame end
    if key == "minimap" then return ns.minimap and ns.minimap.root end
    if key == "topwidget" then return ns.topWidgetHolder end
    if key == "classpower" then return _G.MyCF_ClassPower end
    if key == "raid" then return _G.MyCF_RaidHeader end
    -- Barras de Bartender4 (2026-07-24, pedido del usuario) -- mismos nombres
    -- reales ya usados/confirmados en BartenderScale.lua (BT4Bar1-10 +
    -- BT4BarPetBar/StanceBar/BagBar/ExtraActionBar). SetAlpha nada mas, mismo
    -- criterio que classpower/raid arriba.
    if key:sub(1, 6) == "BT4Bar" then return _G[key] end
    if ns.frames[key] then return ns.frames[key].button end
    if ns.portraits[key] then return ns.portraits[key].root end
    if ns.auras[key] then return ns.auras[key].root end
    return nil
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
    { label = "Target auras", keys = { "aura_target" } },
    { label = "Target of Target", keys = { "targettarget", "portrait_tot" } },
    { label = "Focus unit frame", keys = { "focus" }, wizard = true, wizardRecommended = true },
    { label = "Player auras", keys = { "aura_player" }, wizard = true },
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
local function IsMouseOverElement(f, key)
    if f:IsMouseOver() then return true end
    if key:sub(1, 6) ~= "BT4Bar" then return false end
    local ok, children = pcall(function() return { f:GetChildren() } end)
    if not ok then return false end
    for _, c in ipairs(children) do
        if c.IsMouseOver and c:IsMouseOver() then return true end
    end
    return false
end

-- Fade por MOUSEOVER (`IsMouseOver` funciona sin EnableMouse = geometrico). El fade corre
-- por FRAME (OnUpdate de explorerDriver) con suavizado EXPONENCIAL independiente del
-- framerate: el lerp fijo del ticker de 0.1s se veia a saltos (10 pasos/seg = "lag").
-- Revelar es mas rapido que ocultar (mas natural). El estado de combate lo refresca el
-- ticker (secret-safe via pcall); aqui solo se anima. db.explorerEnabled = toggle maestro.
local explorerDriver = CreateFrame("Frame", nil, UIParent)
explorerDriver:Hide()
explorerDriver:SetScript("OnUpdate", function(self, dt)
    local db = ns.GetDB()
    if not (db and db.explorer and db.explorerEnabled ~= false) or ns.IsUnlocked() then return end
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
                -- de reemplazo o posses bar, se muestre aunque este el explorer on" -- cuando
                -- Bartender4 reasigna BT4Bar1 (Player) para reflejar la override/vehicle/
                -- possess bar de Blizzard, se fuerza visible SIEMPRE, sin importar mouseover/
                -- combate/etc (ver self.overrideBar, calculado en TickExplorer).
                local forceOverride = (key == "BT4Bar1") and self.overrideBar
                local myLo = (eAlpha and eAlpha[key]) or lo
                local target = (self.combat or self.showTgt or self.casting or forceOverride or IsMouseOverElement(f, key)) and 1 or myLo
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
            end
        end
    end
end)
ns.ExplorerReset = function(key)   -- llamar al APAGAR el explorer de un elemento
    local f = GetElementFrame(key)
    if f then f._exAlpha = nil; f:SetAlpha(1) end
    -- Restaurar tambien el alpha manual del modelo 3D (no hereda del padre).
    local pu = ns.portraits[key]
    local db = ns.GetDB()
    if pu and pu.model and db then pu.model:SetAlpha(ns.PP(pu).modelAlpha or 1) end
end
ns.ExplorerResetAll = function()   -- llamar al APAGAR el toggle maestro
    local db = ns.GetDB()
    if not (db and db.explorer) then return end
    for key in pairs(db.explorer) do ns.ExplorerReset(key) end
end

-- Tipo de contenido actual → clave de db.explorerZones. IsInInstance devuelve:
-- "none"(mundo)/"party"(mazmorra)/"raid"/"arena"/"pvp"(BG)/"scenario"(escenario/delve).
local EXPLORER_ZONE_MAP = {
    none = "world", party = "dungeon", raid = "raid",
    arena = "arena", pvp = "battleground", scenario = "scenario",
}
local function ExplorerZoneAllowed()
    local db = ns.GetDB()
    local z = db and db.explorerZones
    if not z then return true end
    local key = "world"
    local ok, inInst, it = pcall(IsInInstance)
    if ok and not (issecretvalue and (issecretvalue(inInst) or issecretvalue(it))) then
        if inInst and it then key = EXPLORER_ZONE_MAP[it] or "world" end
    end
    return z[key] ~= false
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
ns.TickExplorer = function()
    local db = ns.GetDB()
    if not db then return end
    local exOn = db.explorerEnabled ~= false and db.explorer and next(db.explorer) ~= nil
        and ExplorerZoneAllowed()
    if exOn then
        explorerDriver.combat = (db.explorerCombat and ns.tickState.inCombat) or false
        explorerDriver.showTgt = (db.explorerTarget and UnitExists("target")) or false
        -- Casteo/canalizacion del PLAYER: revela al instante (ReadCastMode es secret-safe;
        -- el fade de revelado tiene half-life ~60ms → se percibe inmediato).
        explorerDriver.casting = (db.explorerCasting and ns.ReadCastMode("player") ~= nil) or false
        -- BT4Bar1 forzado visible si se convirtio en la override/vehicle/possess bar
        -- (ver el "forceOverride" del OnUpdate de arriba). Secret-safe via ns.safeBool
        -- (mismo criterio que el resto del addon para cualquier UnitXxx/HasXxx que
        -- pueda devolver un valor secreto en Midnight 12.0.7).
        explorerDriver.overrideBar = ns.safeBool(HasOverrideActionBar)
            or ns.safeBool(HasVehicleActionBar)
            or ns.safeBool(UnitHasVehicleUI, "player")
    elseif explorerDriver._wasOn then
        -- Se apago (zona no permitida o master off): restaurar alpha 1 UNA vez.
        if ns.ExplorerResetAll then ns.ExplorerResetAll() end
    end
    explorerDriver._wasOn = exOn and true or false
    explorerDriver:SetShown(exOn and true or false)
end
