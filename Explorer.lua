local ADDON, ns = ...

-- EXPLORER (#11): elementos que se auto-ocultan y aparecen con MOUSEOVER (o en combate).
-- Extraido de core.lua (2026-07-22, "que se puede sacar del core") -- mismo criterio ya
-- usado con Units/Portraits/Auras/InfoBar/Editing: subsistema cohesivo, sin dependencias
-- de otros locals de core.lua salvo los ya expuestos via ns (GetDB/IsUnlocked/frames/
-- portraits/auras/tickState).

-- Mapa elementKey -> frame raiz del elemento.
local function GetElementFrame(key)
    if key == "micromenu" then return ns.micromenu end
    if key == "infobar" then return ns.infobar and ns.infobar.root end
    if ns.frames[key] then return ns.frames[key].button end
    if ns.portraits[key] then return ns.portraits[key].root end
    if ns.auras[key] then return ns.auras[key].root end
    return nil
end
ns.GetElementFrame = GetElementFrame

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
    for key, on in pairs(db.explorer) do
        if on then
            local f = GetElementFrame(key)
            -- _mcfCombatHidden: portrait "oculto" via alpha en combate (frame protegido);
            -- su alpha lo gestiona PortraitSetShown, no el Explorer.
            if f and f:IsShown() and not f._mcfCombatHidden then
                local target = (self.combat or self.showTgt or self.casting or f:IsMouseOver()) and 1 or lo
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
    elseif explorerDriver._wasOn then
        -- Se apago (zona no permitida o master off): restaurar alpha 1 UNA vez.
        if ns.ExplorerResetAll then ns.ExplorerResetAll() end
    end
    explorerDriver._wasOn = exOn and true or false
    explorerDriver:SetShown(exOn and true or false)
end
