-- ==========================================================================
-- MyCustomFrames - Portraits.lua
-- PORTRAITS (elementos aparte de las unidades: modelo 3D o icono de clase,
-- badges de faccion/muerte/combate/raid-target/rol-lider, doble posicion).
-- Extraido de core.lua (mismo motivo/patron que Units.lua: margen de locals),
-- usa ns.GetDB()/ns.IsUnlocked() en vez de los locals db/unlocked de core.
-- Carga DESPUES de core.lua y Units.lua en el toc.
-- ==========================================================================
local ADDON, ns = ...
-- ==========================================================================
-- ns.PORTRAITS: creacion y logica
-- ==========================================================================
local function PP(u) return ns.GetDB().portraits[u.key] end

-- Condicion para usar la posicion "centro" (target / combate / instancia).
local function PortraitCenterActive(u)
    local p = PP(u)
    local active = false
    if p.centerInCombat and ns.tickState.inCombat then active = true end
    if not active and p.centerOnTarget then
        if UnitExists("target") then active = true end
    end
    -- Solo RAID o DUNGEON (type "raid"/"party"), no cualquier instancia (BG/arena/escenario).
    -- (pcall directo sin closure; issecretvalue antes de testear/comparar.)
    if not active and p.centerInInstance then
        local ok, inInst, it = pcall(IsInInstance)
        if ok and not (issecretvalue and (issecretvalue(inInst) or issecretvalue(it)))
           and inInst and (it == "raid" or it == "party") then
            active = true
        end
    end
    return active
end

-- Coloca el portrait en la posicion que corresponda (o en la que se edita en preview).
-- Solo los ns.portraits con feature dualPos tienen 2 posiciones; el resto usan solo "centro".
local function PortraitUpdatePosition(u)
    -- Si el root quedo PROTEGIDO (p.ej. un frame seguro fue anclado a el alguna vez),
    -- ClearAllPoints/SetPoint en combate = ADDON_ACTION_BLOCKED. Se salta el tick.
    if InCombatLockdown() and u.root:IsProtected() then return end
    local p = PP(u)
    ns.CompensateScale(p, "portrait")   -- B3: reancla offsets si la escala cambio
    local dual = u.features and u.features.dualPos
    local which = "center"
    if dual then
        if ns.IsUnlocked() then which = (p.editPos == "alt") and "alt" or "center"
        elseif PortraitCenterActive(u) then which = "center"
        else which = "alt" end
    end
    local anchorName, point, relPoint, x, y
    if which == "alt" then
        anchorName, point, relPoint, x, y = p.altAnchor, p.altPoint, p.altRelPoint, p.altX, p.altY
    else
        anchorName, point, relPoint, x, y = p.centerAnchor, p.centerPoint, p.centerRelPoint, p.centerX, p.centerY
    end
    local parent = _G[anchorName]
    if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
    -- Dedupe: re-anclar cada tick con los mismos valores es trabajo inutil. Se compara
    -- contra lo ULTIMO APLICADO (datos propios del addon, nunca secretos); el parent
    -- resuelto entra en la firma (un anchor que aparece tarde re-ancla solo). El
    -- OnDragStop invalida la firma (_posParent=nil) porque StartMoving cambia el ancla real.
    if u._posParent == parent and u._posP == point and u._posRP == relPoint
       and u._posX == x and u._posY == y then return end
    u.root:ClearAllPoints()
    u.root:SetPoint(point, parent, relPoint, x, y)
    u._posParent, u._posP, u._posRP, u._posX, u._posY = parent, point, relPoint, x, y
end

-- Coordenadas del icono de clase de la unidad (nil si no tiene clase legible).
local function PortraitClassCoords(unit)
    -- (Ruta caliente: se consulta cada tick por cada portrait de icono via
    -- PortraitShouldShow.) pcall directo; el token de clase puede ser secreto:
    -- NUNCA indexar la tabla con el sin confirmar que es legible.
    local ok, _, class = pcall(UnitClass, unit)
    if ok and type(class) == "string" and not (issecretvalue and issecretvalue(class)) then
        return CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    end
end

-- Color de clase de una unidad. Para "player" nunca es secreto; para "target"
-- (mirrorTarget) se valida con issecretvalue igual que PortraitClassCoords.
local function UnitClassColorSafe(unit)
    local ok, _, classFile = pcall(UnitClass, unit)
    if not ok or type(classFile) ~= "string" or (issecretvalue and issecretvalue(classFile)) then return end
    return (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(classFile))
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile])
end

-- Actualiza el "retrato": modelo 3D (kind=model) o icono de clase (kind=icon).
local function PortraitUpdatePicture(u)
    local p = PP(u)
    if u.kind == "icon" then
        if not u.classIcon then return end
        if not p.showModel then u.classIcon:Hide() return end
        -- PREMATCH DE ARENA (pedido del usuario 2026-07-20): "se deberia mostrar el
        -- icono de clase/spec en el portrait de la arena" -- UnitClass(arenaN) todavia
        -- no resuelve nada util durante el prep (mismo motivo por el que Blizzard usa
        -- un frame aparte, PreMatchFramesContainer), pero GetArenaOpponentSpec() SI
        -- funciona ahi (ver ArenaTrinket.lua, ns.ArenaPrepSpecState). Se usa el icono
        -- de ESPECIALIZACION real (mas especifico que el generico por clase) mientras
        -- dure el prep; se limpia solo al arrancar el combate.
        if u.key:sub(1, 14) == "portrait_arena" and ns.ArenaPrepSpecState then
            local prep = ns.ArenaPrepSpecState[u.unit]
            if prep and prep.icon then
                u.classIcon:SetTexture(prep.icon)
                u.classIcon:SetTexCoord(0, 1, 0, 1)
                u.classIcon:Show()
                return
            end
        end
        local coords = PortraitClassCoords(u.unit)
        if not coords and ns.IsUnlocked() then coords = PortraitClassCoords("player") end  -- preview
        if coords then
            u.classIcon:SetTexture(ns.CLASS_ICON_TEX)
            u.classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            u.classIcon:Show()
        else
            u.classIcon:Hide()
        end
        return
    end
    if not u.model then return end
    if not p.showModel then u.model:Hide() return end
    u.model:Show()
    -- mirrorTarget (solo portrait_player): muestra el modelo 3D del target en
    -- vez del propio, si hay target. u.unit NO se toca (sigue usandose tal
    -- cual en el resto de features: faction/death/combat/etc). El patron
    -- SetUnit("target") ya esta probado y funcionando en portrait_target/tot.
    local modelUnit = u.unit
    local mirroring = false
    if u.key == "portrait_player" and p.mirrorTarget and UnitExists("target") then
        modelUnit = "target"
        mirroring = true
    end
    -- DIAG TEMPORAL (2026-07-23, "el portrait 3d no funciona para enemigos en
    -- dungeon, es un limite de la API?"): se guarda el resultado del pcall +
    -- contexto (unidad, tipo de instancia) para el diagnostico /mcfportraitdiag
    -- de mas abajo -- sacar este bloque de guardado (no el pcall en si) una vez
    -- confirmada la causa real.
    local ok, err = pcall(function()
        u.model:ClearModel()
        u.model:SetUnit(modelUnit)
        u.model:SetPortraitZoom(ns.clamp(p.modelZoom, 0, 1))
        u.model:SetPosition(0, 0, 0)
    end)
    if mirroring then
        local okInst, inInst, it = pcall(IsInInstance)
        ns._mirrorTargetDiag = {
            ok = ok, err = err, modelUnit = modelUnit,
            inInst = okInst and inInst or nil, instType = okInst and it or nil,
            hasModel = ok and u.model:HasModel() or nil,
            time = GetTime(),
        }
    end
    if u.key == "portrait_player" and p.mirrorTarget and u.bg then
        if mirroring then
            local ok, isPlayer = pcall(UnitIsPlayer, "target")
            local c = ok and isPlayer and UnitClassColorSafe("target")
            if c then
                -- Target es un jugador: color de clase (igual que el player solo).
                u.bg:SetVertexColor(c.r, c.g, c.b, p.bgAlpha)
            else
                -- Target es NPC: color por reaccion (hostil/neutral/amistoso).
                local okR, reaction = pcall(UnitReaction, "target", "player")
                reaction = okR and type(reaction) == "number" and reaction or nil
                if reaction and reaction >= 5 then
                    u.bg:SetVertexColor(0.15, 0.85, 0.15, p.bgAlpha)       -- amistoso
                elseif reaction == 4 then
                    u.bg:SetVertexColor(1, 0.9, 0.1, p.bgAlpha)           -- neutral
                else
                    u.bg:SetVertexColor(1, 0.1, 0.1, p.bgAlpha)           -- hostil (o desconocido)
                end
            end
        else
            local c = UnitClassColorSafe("player")
            if c then
                u.bg:SetVertexColor(c.r, c.g, c.b, p.bgAlpha)
            else
                u.bg:SetVertexColor(p.bgColor.r, p.bgColor.g, p.bgColor.b, p.bgAlpha)
            end
        end
    end
end

local function PortraitUpdateFaction(u)
    if not u.faction then return end
    local p = PP(u)
    if not p.showFaction then u.faction:Hide() return end
    -- En COMBATE se oculta el badge de faccion (el de combate ocupa su lugar). En
    -- preview (ns.IsUnlocked()) NO, para poder editarlo/posicionarlo.
    if not ns.IsUnlocked() and ns.tickState.inCombat then u.faction:Hide() return end
    local fac = ns.safeVal(UnitFactionGroup, "player")
    -- War Mode: usa el icono de badge de guerra segun el TOGGLE del jugador (no la zona).
    -- IsWarModeDesired = refleja el interruptor de Modo Guerra activado/desactivado (persiste entre
    -- zonas, aunque estes en una ciudad santuario donde no esta "activo"); IsWarModeActive solo es
    -- true en zonas de mundo con PvP → daba la sensacion de que el badge no cambiaba. Guard pcall.
    local warOn = false
    if C_PvP then
        local ok, v = pcall(function()
            if C_PvP.IsWarModeDesired then return C_PvP.IsWarModeDesired() end
            if C_PvP.IsWarModeActive then return C_PvP.IsWarModeActive() end
        end)
        warOn = ok and v and true or false
    end
    if fac == "Alliance" then
        u.faction:SetTexture(warOn and ns.BADGE_ALLIANCE_WAR or ns.BADGE_ALLIANCE); u.faction:Show()
    elseif fac == "Horde" then
        u.faction:SetTexture(warOn and ns.BADGE_HORDE_WAR or ns.BADGE_HORDE); u.faction:Show()
    else
        u.faction:Hide()   -- neutral / sin faccion
    end
end

-- Marcador de banda (raid target icon). Solo party (feature raidTarget). Usa la textura
-- CUSTOM manteniendo los texcoords de SetRaidTargetIconTexture (grid estandar 4x4): se
-- llama SetRaidTargetIconTexture (fija coords correctas por indice) y luego se cambia la
-- textura al asset propio (SetTexture no toca los texcoords). Igual que AzeriteUI.
-- Muestra/oculta el marcador con FADE suave (Alpha). Solo dispara la transicion al CAMBIAR de
-- estado (no cada tick). El bounce (Translation) sigue independiente del alpha.
local function RaidTargetSetVisible(u, show)
    local rt, fade = u.raidtarget, u.raidtargetFade
    if u._rtVisible == show then return end
    u._rtVisible = show
    local target = PP(u).raidTargetAlpha or 1
    if not fade or not fade.anim then
        if show then rt:SetAlpha(target); rt:Show() else rt:Hide() end
        return
    end
    fade:Stop()
    if show then
        fade:SetScript("OnFinished", nil)
        -- Alpha BASE = target (no 0): una animacion Alpha es un override temporal y al terminar
        -- revierte al alpha base; si el base fuera 0, el marcador se desvaneceria tras el fade.
        -- Con base=target y FromAlpha=0, el fade visual va 0→target y al terminar QUEDA visible.
        rt:SetAlpha(target); rt:Show()
        fade.anim:SetFromAlpha(0); fade.anim:SetToAlpha(target)
        fade:Play()
    else
        fade:SetScript("OnFinished", function() rt:Hide() end)
        fade.anim:SetFromAlpha(rt:GetAlpha()); fade.anim:SetToAlpha(0)
        fade:Play()
    end
end

local function PortraitUpdateRaidTarget(u)
    local rt = u.raidtarget
    if not rt then return end
    local p = PP(u)
    if not (u.features and u.features.raidTarget and p.showRaidTarget) then
        rt:Hide(); u._rtVisible = false; return
    end
    local index
    if ns.IsUnlocked() then
        index = 8   -- preview: calavera de muestra
    else
        index = ns.safeVal(GetRaidTargetIndex, u.unit)
    end
    -- CLAVE (Midnight): GetRaidTargetIndex devuelve un NUMERO SECRETO si la unidad esta
    -- marcada -> NUNCA comparar (>=, <=, ==) en Lua (crashea "compare secret number").
    -- type() es seguro (devuelve "number" para secretos); nil = sin marca. SetRaidTargetIconTexture
    -- es funcion en C y acepta el indice secreto para fijar los texcoords.
    if type(index) == "number" then
        pcall(SetRaidTargetIconTexture, rt, index)   -- fija texcoords del indice (acepta secreto)
        rt:SetTexture((p.raidTargetTexture and p.raidTargetTexture ~= "" and p.raidTargetTexture) or ns.RAIDTARGET_TEX)
        RaidTargetSetVisible(u, true)   -- fade-in suave (solo en la transicion)
        if p.raidTargetBounce and u.raidtargetAnim then
            if not u.raidtargetAnim:IsPlaying() then u.raidtargetAnim:Play() end
        elseif u.raidtargetAnim then
            u.raidtargetAnim:Stop()
        end
    else
        RaidTargetSetVisible(u, false)  -- fade-out suave y luego oculta
        if u.raidtargetAnim then u.raidtargetAnim:Stop() end
    end
end

-- Icono de ROL (tank/heal/dps) + LIDER. Solo party (feature roleLeader).
-- UnitGroupRolesAssigned devuelve "TANK"/"HEALER"/"DAMAGER"/"NONE"; UnitIsGroupLeader booleano.
-- Ambos legibles (no secretos). Texturas CUSTOM por rol (una textura completa cada una).
local function PortraitUpdateRoleLeader(u)
    if not (u.roleicon and u.leader) then return end
    local p = PP(u)
    local feats = u.features or {}
    -- Rol: SOLO party (feature roleLeader).
    if feats.roleLeader and p.showRole then
        local role = ns.IsUnlocked() and "HEALER" or ns.safeVal(UnitGroupRolesAssigned, u.unit)
        local tex = (role == "TANK" and ns.ROLE_TANK) or (role == "HEALER" and ns.ROLE_HEAL)
            or (role == "DAMAGER" and ns.ROLE_DPS)
        if tex then
            u.roleicon:SetTexture(tex)
            u.roleicon:Show()
        else
            u.roleicon:Hide()
        end
    else
        u.roleicon:Hide()
    end
    -- Lider: party (roleLeader) O cualquier portrait con feature 'leader'. Toggle showLeader.
    if (feats.roleLeader or feats.leader) and p.showLeader
       and (ns.IsUnlocked() or ns.safeBool(UnitIsGroupLeader, u.unit)) then
        u.leader:Show()
    else
        u.leader:Hide()
    end
end

-- Estado dinamico: descanso (flipbook), muerte, badge de combate.
-- Performance Fase 2 (2026-07-15): `skipBadges` (opcional, default nil/false = actualiza los
-- badges) permite que el ticker principal actualice faccion/raid-target/rol-lider a MENOR
-- frecuencia (cambian raramente: war mode toggle, marcar/desmarcar objetivo, reasignar rol) sin
-- tocar rest/death/combat (necesitan reaccionar cada tick para verse fluidos). El OTRO call site
-- (aplicar config / SetUnlocked, linea ~2188) NO pasa este parametro -> sigue actualizando los
-- badges siempre, para que un cambio de configuracion se vea al instante.
local function PortraitUpdateState(u, preview, skipBadges)
    local p = PP(u)
    local resting, dead, inCombat
    if preview then
        resting, dead, inCombat = true, true, true
    else
        resting  = ns.tickState.resting
        dead     = ns.safeBool(UnitIsDeadOrGhost, u.unit)
        inCombat = ns.tickState.inCombat
    end
    if u.rest then
        local on = p.showRest and resting
        u.rest:SetShown(on)
        if on then
            if u.restAnim and not u.restAnim:IsPlaying() then u.restAnim:Play() end
        elseif u.restAnim then
            u.restAnim:Stop()
        end
    end
    -- B4: en preview, ocultar SAMPLE de death/raid/badges si el toggle Lock lo pide.
    local lh = (preview and ns.GetDB() and ns.GetDB().lockHide) or nil
    if u.death  then u.death:SetShown(p.showDeath and dead and not (lh and lh.death)) end
    if u.combat then
        local showCombat = p.showCombat and inCombat and not (lh and lh.badges)
        u.combat:SetShown(showCombat)
        -- Bounce mientras esta en combate (en preview se muestra estatico).
        if u.combatAnim then
            if showCombat and not preview then
                if not u.combatAnim:IsPlaying() then u.combatAnim:Play() end
            else
                u.combatAnim:Stop()
            end
        end
    end
    if not skipBadges then
        -- Faccion (alianza/horda): se oculta en combate; se relee aqui para que sea dinamico.
        PortraitUpdateFaction(u)
        -- Marcador de banda (raid target): dinamico (la marca puede ponerse/quitarse).
        PortraitUpdateRaidTarget(u)
        -- Rol + lider (party): dinamicos.
        PortraitUpdateRoleLeader(u)
    end
    -- B4: en preview, ocultar badges/raid marks si el toggle Lock lo pide (tras los updates).
    if lh then
        if lh.badges and u.faction then u.faction:Hide() end
        if lh.raid and u.raidtarget then u.raidtarget:Hide(); u._rtVisible = false end
    end
end

-- Contenido donde tienen sentido los PARTY ns.portraits: mundo abierto, grupo normal y
-- mazmorra ("party"). Fuera (raid, arena, BG/cualquier pvp, escenario/delve, o grupo
-- de RAID aunque sea en mundo abierto): ocultos. Secret-safe: issecretvalue antes de
-- testear/comparar. El ticker lo cachea en ns.tickState.partyOK (cambia solo por zona/grupo).
local function PartyContentAllowed()
    local ok, inInst, it = pcall(IsInInstance)
    if ok and not (issecretvalue and (issecretvalue(inInst) or issecretvalue(it))) then
        if inInst and it ~= "party" then return false end
    end
    if ns.safeBool(IsInRaid) then return false end
    return true
end

-- ARENA (pedido del usuario 2026-07-19): "solo debe aparecer en arenas" -- mismo
-- patron que PartyContentAllowed, para los portraits portrait_arena_* (ver
-- PortraitShouldShow mas abajo). Poblado en el tick central (core.lua, tickState.arenaOK).
local function ArenaContentAllowed()
    local ok, inInst, it = pcall(IsInInstance)
    if not ok or (issecretvalue and (issecretvalue(inInst) or issecretvalue(it))) then return false end
    return inInst and it == "arena"
end

-- Debe mostrarse el portrait? (activado; unidad existe/muerta segun flags; clase legible si icono).
local function PortraitShouldShow(u)
    if not PP(u).enabled then return false end
    -- Party ns.portraits: gating por tipo de contenido (ns.tickState.partyOK, por tick).
    if ns.tickState.partyOK == false and u.key:sub(1, 14) == "portrait_party" then return false end
    -- portrait_party5 usa unit="player" (ver nota en UNITS/PartyDriverString): UnitExists("player")
    -- siempre es true, asi que "requireExists" no alcanza para ocultarlo estando SOLO (sin grupo).
    -- Mismo criterio que el driver del unitframe: solo visible si estas agrupado.
    if u.key == "portrait_party5" and not ns.safeBool(IsInGroup) then return false end
    -- ARENA (pedido del usuario 2026-07-19): "solo debe aparecer en arenas". Sin esto,
    -- portrait_arena_player (unit="player") mostraria SIEMPRE, ya que UnitExists("player")
    -- es siempre true -- mismo problema de fondo que portrait_party5 arriba.
    if u.key:sub(1, 14) == "portrait_arena" and ns.tickState.arenaOK == false then return false end
    -- FIX (2026-07-20, prematch de arena): UnitExists("arenaN") tambien es FALSE
    -- durante el prep (mismo motivo por el que Blizzard usa un frame aparte,
    -- PreMatchFramesContainer, en vez de reusar su ArenaEnemyMatchFrame real) --
    -- sin este bypass, requireExists bloqueaba el portrait antes de llegar siquiera
    -- al chequeo de PortraitClassCoords de mas abajo.
    if u.requireExists and not UnitExists(u.unit) then
        local hasPrepIcon = u.key:sub(1, 14) == "portrait_arena" and ns.ArenaPrepSpecState
            and ns.ArenaPrepSpecState[u.unit]
        if not hasPrepIcon then return false end
    end
    if u.deadOnly then
        local dead = ns.safeBool(UnitExists, u.unit) and ns.safeBool(UnitIsDeadOrGhost, u.unit)
        if not dead then return false end
    end
    -- FIX (2026-07-20, reportado por el usuario: "el portrait en el prematch con la
    -- clase no esta saliendo"): PortraitClassCoords usa UnitClass(unit), que durante
    -- el prep de arena todavia no resuelve nada (mismo motivo por el que se necesito
    -- GetArenaOpponentSpec en ArenaTrinket.lua) -- este gate bloqueaba el portrait
    -- ENTERO antes de llegar a PortraitUpdatePicture, que es donde vive el fallback
    -- de ns.ArenaPrepSpecState. Se agrega el mismo fallback aca.
    if u.kind == "icon" and not PortraitClassCoords(u.unit) then
        local hasPrepIcon = u.key:sub(1, 14) == "portrait_arena" and ns.ArenaPrepSpecState
            and ns.ArenaPrepSpecState[u.unit]
        if not hasPrepIcon then return false end
    end
    return true
end

-- Muestra/oculta el root de un portrait respetando las restricciones de Blizzard:
-- si el frame quedo PROTEGIDO (p.ej. porque un frame seguro fue anclado a el en algun
-- momento de la sesion), Show/Hide desde codigo inseguro esta BLOQUEADO en combate
-- (ADDON_ACTION_BLOCKED:...:Hide()). En ese caso: alpha 0 como sustituto visual y el
-- Show/Hide REAL se difiere a PLAYER_REGEN_ENABLED (_pendingShown). El flag
-- _mcfCombatHidden en el root avisa al Explorer de que no toque ese alpha.
local function PortraitSetShown(u, shown)
    shown = shown and true or false
    local root = u.root
    if InCombatLockdown() and root:IsProtected() then
        local cur = u._pendingShown
        if cur == nil then cur = root:IsShown() and true or false end
        if cur ~= shown then
            u._pendingShown = shown
            root._mcfCombatHidden = (not shown) or nil
            root:SetAlpha(shown and 1 or 0)
            -- El modelo 3D no hereda el alpha del padre: ocultarlo/restaurarlo a mano.
            if u.model then u.model:SetAlpha(shown and (PP(u).modelAlpha or 1) or 0) end
        end
        return
    end
    if u._pendingShown ~= nil then
        u._pendingShown = nil
        root._mcfCombatHidden = nil
        root:SetAlpha(1)
        if u.model then u.model:SetAlpha(PP(u).modelAlpha or 1) end
    end
    root:SetShown(shown)
end

local function PortraitApplyAppearance(u)
    local p = PP(u)
    local s = p.size
    u.root:SetSize(s, s)
    u.root:SetScale(p.scale or 1)   -- escala general (multiplica sobre size, sin alterarlo)
    u.root:SetFrameStrata(p.strata)

    -- Fondo circular (coloreable).
    u.bg:SetTexture((p.bgTexture and p.bgTexture ~= "" and p.bgTexture) or ns.PORTRAIT_BG)
    u.bg:SetSize(s * p.bgScale, s * p.bgScale)
    u.bg:ClearAllPoints(); u.bg:SetPoint("CENTER", u.root, "CENTER", 0, 0)
    u.bg:SetVertexColor(p.bgColor.r, p.bgColor.g, p.bgColor.b, p.bgAlpha)
    u.bg:SetShown(p.showBg)

    -- Retrato (modelo 3D o icono de clase).
    if u.pic then
        u.pic:SetSize(s * p.modelScale, s * p.modelScale)
        u.pic:ClearAllPoints(); u.pic:SetPoint("CENTER", u.root, "CENTER", p.modelOffsetX, p.modelOffsetY)
        u.pic:SetAlpha(p.modelAlpha)
    end

    -- Borde / orbe.
    u.cage:SetTexture((p.cageTexture and p.cageTexture ~= "" and p.cageTexture) or ns.PORTRAIT_ORB)
    u.cage:SetSize(s * p.cageScale, s * p.cageScale)
    u.cage:ClearAllPoints(); u.cage:SetPoint("CENTER", u.root, "CENTER", p.cageOffsetX, p.cageOffsetY)
    u.cage:SetAlpha(p.cageAlpha); u.cage:SetShown(p.showCage)

    -- Flipbook de descanso.
    u.rest:SetSize(s * p.restScale, s * p.restScale)
    u.rest:ClearAllPoints(); u.rest:SetPoint("CENTER", u.root, "CENTER", p.restOffsetX, p.restOffsetY)
    u.rest:SetAlpha(p.restAlpha)

    -- Marca de muerte (color + opacidad).
    u.death:SetSize(s * p.deathScale, s * p.deathScale)
    u.death:ClearAllPoints(); u.death:SetPoint("CENTER", u.root, "CENTER", p.deathOffsetX, p.deathOffsetY)
    u.death:SetVertexColor(p.deathColor.r, p.deathColor.g, p.deathColor.b)
    u.death:SetAlpha(p.deathAlpha)

    -- Badge de faccion (color + opacidad).
    u.faction:SetSize(s * p.factionScale, s * p.factionScale)
    u.faction:ClearAllPoints(); u.faction:SetPoint("CENTER", u.root, "CENTER", p.factionOffsetX, p.factionOffsetY)
    u.faction:SetVertexColor(p.factionColor.r, p.factionColor.g, p.factionColor.b)
    u.faction:SetAlpha(p.factionAlpha)

    -- Badge de combate (color + opacidad).
    u.combat:SetSize(s * p.combatScale, s * p.combatScale)
    u.combat:ClearAllPoints(); u.combat:SetPoint("CENTER", u.root, "CENTER", p.combatOffsetX, p.combatOffsetY)
    u.combat:SetVertexColor(p.combatColor.r, p.combatColor.g, p.combatColor.b)
    u.combat:SetAlpha(p.combatAlpha)

    -- Marcador de banda (raid target): tamaño/offset/opacidad configurables.
    if u.raidtarget then
        u.raidtarget:SetSize(s * (p.raidTargetScale or 0.62), s * (p.raidTargetScale or 0.62))
        u.raidtarget:ClearAllPoints()
        u.raidtarget:SetPoint("CENTER", u.root, "CENTER", p.raidTargetOffsetX or 0, p.raidTargetOffsetY or 32)
        u.raidtarget:SetAlpha(p.raidTargetAlpha or 1)
    end

    -- Iconos de rol / lider: tamaño/offset/opacidad configurables.
    if u.roleicon then
        u.roleicon:SetSize(s * (p.roleScale or 0.42), s * (p.roleScale or 0.42))
        u.roleicon:ClearAllPoints()
        u.roleicon:SetPoint("CENTER", u.root, "CENTER", p.roleOffsetX or 0, p.roleOffsetY or 0)
        u.roleicon:SetAlpha(p.roleAlpha or 1)
    end
    if u.leader then
        u.leader:SetSize(s * (p.leaderScale or 0.42), s * (p.leaderScale or 0.42))
        u.leader:ClearAllPoints()
        u.leader:SetPoint("CENTER", u.root, "CENTER", p.leaderOffsetX or 0, p.leaderOffsetY or 0)
        u.leader:SetAlpha(p.leaderAlpha or 1)
    end

    PortraitUpdatePicture(u)
    PortraitUpdateFaction(u)
    PortraitUpdateRaidTarget(u)
    PortraitUpdateRoleLeader(u)
    PortraitUpdatePosition(u)
    PortraitUpdateState(u, ns.IsUnlocked())

    -- Zona verde de edicion.
    if u.editBG then u.editBG:SetShown(ns.IsUnlocked() and not (ns.GetDB() and ns.GetDB().hideEditOutline)) end
    -- "Hide in preview (Lock only)" (lockHide.portraits): oculta TODOS los
    -- portraits SOLO mientras se edita, sin tocar su showEnabled real.
    if ns.IsUnlocked() and ns.GetDB().lockHide and ns.GetDB().lockHide.portraits then
        u.root:Hide()
        return
    end
    PortraitSetShown(u, ns.IsUnlocked() or PortraitShouldShow(u))
    -- Captura mouse en preview (arrastrar) o fuera de preview si abre el panel (clickOpenChar).
    u.root:EnableMouse(ns.IsUnlocked() or (p.clickOpenChar and true or false))
end

local function RefreshPortrait(key)
    local u = ns.portraits[key]
    if not u then return end
    PortraitApplyAppearance(u)
    if key == "portrait_player" and ns.LayoutPortraitCharButtons then ns.LayoutPortraitCharButtons(u) end
end
ns.RefreshPortrait = RefreshPortrait

local function RefreshAllPortraits()
    for _, u in pairs(ns.portraits) do PortraitApplyAppearance(u) end
end
ns.RefreshAllPortraits = RefreshAllPortraits

local function CreatePortrait(def)
    local u = {
        key = def.key, unit = def.unit, label = def.label,
        kind = def.kind or "model", deadOnly = def.deadOnly,
        features = def.features or {}, requireExists = def.requireExists,
    }

    local root = CreateFrame("Frame", "MyCF_Portrait_" .. def.key, UIParent)
    root:SetSize(90, 90)
    root:SetPoint("CENTER")
    root:SetMovable(true)
    root:RegisterForDrag("LeftButton")
    root:EnableMouse(false)

    -- Zona verde (solo en preview).
    local editBG = ns.MakeEditHighlight(root, "Portrait " .. (def.label or def.key))

    -- Fondo circular.
    local bg = root:CreateTexture(nil, "BACKGROUND", nil, 1)
    bg:SetPoint("CENTER")

    -- Retrato: modelo 3D (kind=model) o icono de clase (kind=icon), encima del fondo.
    local model, classIcon, pic
    if def.kind == "icon" then
        classIcon = root:CreateTexture(nil, "ARTWORK", nil, 1)
        classIcon:SetPoint("CENTER")
        classIcon:Hide()
        pic = classIcon
    else
        model = CreateFrame("PlayerModel", nil, root)
        model:SetFrameLevel(root:GetFrameLevel() + 1)
        model:SetPoint("CENTER")
        pic = model
    end

    -- Capa de iconos por encima del modelo (borde, flipbook, muerte, badges).
    local icons = CreateFrame("Frame", nil, root)
    icons:SetAllPoints(root)
    icons:SetFrameLevel(root:GetFrameLevel() + 2)

    -- Flipbook de descanso (7 filas x 6 columnas = 42 ns.frames). Debajo del borde.
    local rest = icons:CreateTexture(nil, "ARTWORK", nil, -1)
    rest:SetAtlas(ns.ATLAS_REST)
    rest:SetPoint("CENTER")
    rest:Hide()

    local cage = icons:CreateTexture(nil, "ARTWORK", nil, 0)
    cage:SetPoint("CENTER")
    local restAnim = rest:CreateAnimationGroup()
    restAnim:SetLooping("REPEAT")
    local flip = restAnim:CreateAnimation("FlipBook")
    flip:SetDuration(2.0)
    flip:SetFlipBookRows(7)
    flip:SetFlipBookColumns(6)
    flip:SetFlipBookFrames(42)
    flip:SetFlipBookFrameWidth(0)
    flip:SetFlipBookFrameHeight(0)

    local death = icons:CreateTexture(nil, "OVERLAY", nil, 2)
    death:SetTexture(ns.DEATH_TEX)
    death:SetPoint("CENTER")
    death:Hide()

    local faction = icons:CreateTexture(nil, "OVERLAY", nil, 3)
    faction:SetPoint("CENTER")
    faction:Hide()

    local combat = icons:CreateTexture(nil, "OVERLAY", nil, 3)
    combat:SetTexture(ns.BADGE_COMBAT)
    combat:SetPoint("CENTER")
    combat:Hide()

    -- Marcador de banda (raid target icon) — badge encima del portrait (solo party).
    local raidtarget = icons:CreateTexture(nil, "OVERLAY", nil, 4)
    raidtarget:SetPoint("CENTER")
    raidtarget:Hide()
    -- Bounce suave (como el de combate pero mas leve: menos desplazamiento y mas lento).
    local rtAnim = raidtarget:CreateAnimationGroup()
    rtAnim:SetLooping("REPEAT")
    local rta1 = rtAnim:CreateAnimation("Translation")
    rta1:SetOffset(0, 2); rta1:SetDuration(0.9); rta1:SetOrder(1); rta1:SetSmoothing("OUT")
    local rta2 = rtAnim:CreateAnimation("Translation")
    rta2:SetOffset(0, -2); rta2:SetDuration(0.9); rta2:SetOrder(2); rta2:SetSmoothing("IN")
    u.raidtargetAnim = rtAnim
    -- Fade suave al aparecer/desaparecer (Alpha, independiente del bounce que es Translation).
    local rtFade = raidtarget:CreateAnimationGroup()
    local rtFadeA = rtFade:CreateAnimation("Alpha")
    rtFadeA:SetDuration(0.3); rtFadeA:SetSmoothing("OUT")
    rtFade.anim = rtFadeA
    u.raidtargetFade = rtFade
    u._rtVisible = false

    -- Icono de ROL (tank/heal/dps) y LIDER — badges de party (feature roleLeader). Texturas
    -- CUSTOM: la del rol se asigna por rol en PortraitUpdateRoleLeader; el lider es fija.
    local roleicon = icons:CreateTexture(nil, "OVERLAY", nil, 5)
    roleicon:SetPoint("CENTER")
    roleicon:Hide()
    local leader = icons:CreateTexture(nil, "OVERLAY", nil, 5)
    leader:SetTexture(ns.LEADER_TEX)
    leader:SetPoint("CENTER")
    leader:Hide()
    u.roleicon, u.leader = roleicon, leader

    -- Bounce del badge de combate (bob suave arriba/abajo, en bucle).
    local combatAnim = combat:CreateAnimationGroup()
    combatAnim:SetLooping("REPEAT")
    local ca1 = combatAnim:CreateAnimation("Translation")
    ca1:SetOffset(0, 5); ca1:SetDuration(0.30); ca1:SetOrder(1); ca1:SetSmoothing("OUT")
    local ca2 = combatAnim:CreateAnimation("Translation")
    ca2:SetOffset(0, -5); ca2:SetDuration(0.30); ca2:SetOrder(2); ca2:SetSmoothing("IN")

    u.root, u.editBG, u.bg, u.model, u.classIcon, u.pic, u.icons =
        root, editBG, bg, model, classIcon, pic, icons
    u.cage, u.rest, u.restAnim, u.death, u.faction, u.combat =
        cage, rest, restAnim, death, faction, combat
    u.combatAnim = combatAnim
    u.raidtarget = raidtarget

    root:SetScript("OnDragStart", function(self)
        if ns.IsUnlocked() and not InCombatLockdown() then
            u._dragStart = { self:GetCenter() }   -- centro al empezar (para mover seguidores)
            self:StartMoving()
        end
    end)
    root:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if ns.SnapFrameToGrid then ns.SnapFrameToGrid(self) end
        local p = PP(u)
        -- Delta de movimiento (para los seguidores de arrastre).
        local dx, dy = 0, 0
        if u._dragStart then
            local cx, cy = self:GetCenter()
            if cx and u._dragStart[1] then dx, dy = cx - u._dragStart[1], cy - u._dragStart[2] end
        end
        local parentName = (p.editPos == "alt") and p.altAnchor or p.centerAnchor
        local parent = _G[parentName]
        if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
        local s, ps = self:GetEffectiveScale(), parent:GetEffectiveScale()
        local fx, fy = self:GetCenter()
        local px, py = parent:GetCenter()
        if fx and px then
            local ox = (fx * s - px * ps) / s
            local oy = (fy * s - py * ps) / s
            if p.editPos == "alt" then
                p.altPoint, p.altRelPoint, p.altX, p.altY = "CENTER", "CENTER", ox, oy
            else
                p.centerPoint, p.centerRelPoint, p.centerX, p.centerY = "CENTER", "CENTER", ox, oy
            end
        end
        u._posParent = nil   -- StartMoving cambio el ancla real: invalidar el dedupe
        -- Seguidores de arrastre (player/target unit + power siguen al portrait, etc.).
        if ns.MoveFollowers then ns.MoveFollowers(u.key, dx, dy) end
        u._dragStart = nil
        PortraitUpdatePosition(u)
        if ns.OnDragStopped then ns.OnDragStopped(u.key) end
    end)

    -- El click que abre el panel de personaje lo manejan los botones SEGUROS estaticos
    -- `u.charBtnCenter`/`u.charBtnAlt` (ver "Abrir el panel de PERSONAJE" mas abajo). Es la UNICA
    -- via que funciona EN COMBATE: abrir un UIPanel en combate exige ejecucion SEGURA de Blizzard;
    -- ToggleCharacter desde codigo inseguro se BLOQUEA en combate ("Interface action failed
    -- because of an AddOn"). El tooltip de aqui es la red para cuando esos botones estan ocultos
    -- (preview / clickOpenChar off).
    root:SetScript("OnEnter", function(self)
        if ns.IsUnlocked() then return end
        local p = PP(u)
        if p and p.clickOpenChar then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Character Info", 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    root:SetScript("OnLeave", function() GameTooltip:Hide() end)

    ns.AttachScaleWheel(u.root, function() return PP(u) end, function() RefreshPortrait(u.key) end)
    ns.portraits[def.key] = u
    return u
end

for _, def in ipairs(ns.PORTRAITS) do CreatePortrait(def) end
-- Expuestas para que core.lua (ticker principal, SetUnlocked, eventos, Explorer,
-- /mcfchar, LayoutPortraitCharButtons) las invoque sin depender de locals de este archivo.
ns.PP = PP
ns.PortraitUpdateFaction = PortraitUpdateFaction
ns.PortraitUpdatePicture = PortraitUpdatePicture
ns.PortraitSetShown = PortraitSetShown
ns.PortraitUpdatePosition = PortraitUpdatePosition
ns.PortraitUpdateState = PortraitUpdateState
ns.PartyContentAllowed = PartyContentAllowed
ns.ArenaContentAllowed = ArenaContentAllowed
ns.PortraitShouldShow = PortraitShouldShow

-- Tick por-portrait (badges/posicion/estado), llamado desde el ticker principal de core.
ns.TickPortraits = function()
    local slowTier = (ns.tickState.n % 3 == 0)
    for _, u in pairs(ns.portraits) do
        if PortraitShouldShow(u) then
            PortraitSetShown(u, true)
            if u.kind == "icon" then
                if u.key == "portrait_tot" or slowTier or not u._wasShown then PortraitUpdatePicture(u) end
            -- portrait_player con mirrorTarget: a diferencia del resto de portraits de
            -- modelo (que solo se refrescan al pasar de oculto a visible), este SIEMPRE
            -- esta visible -- sin este refresh periodico, PortraitUpdatePicture solo
            -- corria en PLAYER_TARGET_CHANGED, asi que si ya tenias target puesto antes
            -- de activar el toggle (o antes de un /reload), nunca se actualizaba.
            elseif u.key == "portrait_player" and PP(u).mirrorTarget then
                if slowTier or not u._wasShown then PortraitUpdatePicture(u) end
            elseif not u._wasShown then
                PortraitUpdatePicture(u)
            end
            u._wasShown = true
            PortraitUpdatePosition(u)
            PortraitUpdateState(u, false, not slowTier)
        else
            PortraitSetShown(u, false)
            u._wasShown = false
        end
    end
end

-- DIAG TEMPORAL (ver comentario en PortraitUpdatePicture): imprime el ultimo
-- intento de mirrorTarget (SetUnit("target") sobre portrait_player). Sacar
-- junto con el bloque que llena ns._mirrorTargetDiag una vez resuelto.
SLASH_MCFMIRRORTARGETDIAG1 = "/mcfmirrortargetdiag"
SlashCmdList["MCFMIRRORTARGETDIAG"] = function()
    local d = ns._mirrorTargetDiag
    if not d then
        print("|cff00ff00[MCF diag]|r sin datos todavia -- necesitas tener mirrorTarget activo y un target puesto al menos una vez.")
        return
    end
    print("|cff00ff00[MCF diag]|r mirrorTarget hace " .. string.format("%.1f", GetTime() - d.time) .. "s:")
    print("  unit=" .. tostring(d.modelUnit) .. "  pcall ok=" .. tostring(d.ok) .. "  err=" .. tostring(d.err))
    print("  inInstance=" .. tostring(d.inInst) .. "  instanceType=" .. tostring(d.instType))
    print("  model:HasModel()=" .. tostring(d.hasModel))
end
