-- ==========================================================================
-- MyCustomFrames - AuraHoverPreview.lua
-- Fusion de PartyAuraPreview.lua + ArenaAuraPreview.lua (2026-07-23, pedido
-- del usuario tras revisar ambos archivos: "son ~95% el mismo codigo
-- copiado" -- ver analisis en el historial de conversacion). Los dos
-- archivos originales quedaban ~400 lineas casi identicas cada uno, y esa
-- duplicacion YA causo una regresion real: el fix de la "dead zone" del
-- hoverZone (2026-07-19) se hizo solo en ArenaAuraPreview.lua y nunca se
-- porto a PartyAuraPreview.lua -- por eso este archivo unico, data-driven
-- por grupo (party/arena), donde un fix futuro se escribe UNA vez.
--
-- Reglas explicitas pedidas por el usuario al fusionar (2026-07-23):
--  1. Arena SOLO en arena; party SOLO en dungeon (gateFn por grupo, sin cambios
--     de fondo respecto al comportamiento previo de cada uno).
--  2. Cero dead zones para NINGUNO de los 2 grupos (antes solo arena tenia el
--     fix) -- hoverZone arranca deshabilitado, el ticker lo prende/apaga.
--  3. El auto-show/atenuado por combate usa el combate del PROPIO JUGADOR
--     ("aparece cuando yo estoy en combate, no ellos") -- antes cada archivo
--     chequeaba SafeInCombat(u.unit) (el companero/rival), ahora siempre
--     PlayerInCombat() sin importar de que unidad sea el grupo.
--  4. Transiciones limpias al sacar el mouse (LEAVE_DELAY + Recompute forzado
--     al perder el gate) -- preservado tal cual.
--  5. El boton/slash de test del menu se mantiene para cada grupo por
--     separado (mismos nombres publicos: ns.TogglePartyAuraTest/
--     ToggleArenaAuraTest, /mcfpartytest, /mcfarenaauratest).
--
-- API publica preservada EXACTA (Options.lua/core.lua la referencian por
-- estos nombres, no se tocaron esos archivos): ns.PARTY_AURA_DIRECTIONS,
-- ns.ARENA_AURA_DIRECTIONS, ns.PartyAuraPreviewTest, ns.ArenaAuraPreviewTest,
-- ns.RefreshPartyAuraDirection/Size, ns.RefreshArenaAuraDirection/Size,
-- ns.TogglePartyAuraTest, ns.ToggleArenaAuraTest, ns.IsPartyAura, ns.IsArenaAura.
-- ==========================================================================
local ADDON, ns = ...

local MAX_ICONS   = 4
local DEFAULT_ICON_SIZE = 26
local ICON_GAP    = 4
local SLIDE_DIST  = 26
local LEAVE_DELAY = 0.35
local BASE_GAP    = 4
local A = "Interface\\AddOns\\MyCustomFrames\\Assets\\"
local AURA_BORDER = A .. "actionbutton-border square.tga"
local BORDER_SCALE = 0.26
local QUESTION_MARK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local DIRECTIONS = { "left", "right", "up", "down" }
ns.PARTY_AURA_DIRECTIONS = DIRECTIONS
ns.ARENA_AURA_DIRECTIONS = DIRECTIONS
local DIR_INFO = {
    left  = { carrierPoint = "RIGHT",  carrierRel = "LEFT",   axis = "x", sign = -1 },
    right = { carrierPoint = "LEFT",   carrierRel = "RIGHT",  axis = "x", sign = 1 },
    up    = { carrierPoint = "BOTTOM", carrierRel = "TOP",    axis = "y", sign = 1 },
    down  = { carrierPoint = "TOP",    carrierRel = "BOTTOM", axis = "y", sign = -1 },
}

local function SafeInCombat(unit)
    local ok, r = pcall(UnitAffectingCombat, unit)
    if not ok or (issecretvalue and issecretvalue(r)) then return false end
    return r and true or false
end
-- Regla #3 del usuario: SIEMPRE el propio jugador, nunca la unidad del grupo.
local function PlayerInCombat() return SafeInCombat("player") end

local function InDungeon()
    local ok, _, instanceType = pcall(IsInInstance)
    return ok and instanceType == "party"
end
local function CheckIsArena() return C_PvP and C_PvP.IsArena and C_PvP.IsArena() end
local function CheckIsRatedArena() return C_PvP and C_PvP.IsRatedArena and C_PvP.IsRatedArena() end
local function CheckIsSoloShuffle() return C_PvP and C_PvP.IsSoloShuffle and C_PvP.IsSoloShuffle() end
local function InArenaNow()
    local ok1, isArena = pcall(CheckIsArena)
    if ok1 and isArena then return true end
    local ok2, isRated = pcall(CheckIsRatedArena)
    if ok2 and isRated then return true end
    local ok3, isShuffle = pcall(CheckIsSoloShuffle)
    if ok3 and isShuffle then return true end
    local ok4, inInst, instanceType = pcall(IsInInstance)
    return ok4 and inInst and instanceType == "arena"
end

-- Debuffs tienen prioridad; si hay menos de MAX_ICONS debuffs, se rellena con
-- buffs (onlyBuffs salta los debuffs del todo -- unidades "propias", como
-- party5/arena_player, ya muestran sus debuffs en el frame nativo de Blizzard).
local function CollectAuras(unit, onlyBuffs)
    local list = {}
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return list end
    if not onlyBuffs then
        for i = 1, 40 do
            local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HARMFUL")
            if not ok or data == nil then break end
            data.__filter = "HARMFUL"
            list[#list + 1] = data
            if #list >= MAX_ICONS then return list end
        end
    end
    for i = 1, 40 do
        local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
        if not ok or data == nil then break end
        data.__filter = "HELPFUL"
        list[#list + 1] = data
        if #list >= MAX_ICONS then break end
    end
    return list
end

local function ResizeIcon(b, sz)
    b:SetSize(sz, sz)
    local inset = sz * BORDER_SCALE
    b.border:ClearAllPoints()
    b.border:SetPoint("TOPLEFT", -inset, inset)
    b.border:SetPoint("BOTTOMRIGHT", inset, -inset)
end

local function CreateIcon(parent)
    local b = CreateFrame("Frame", nil, parent)

    local tex = b:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.tex = tex

    local swipe = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    swipe:SetAllPoints(b)
    swipe:SetDrawEdge(false)
    if swipe.SetHideCountdownNumbers then swipe:SetHideCountdownNumbers(true) end
    b.swipe = swipe

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture(AURA_BORDER)
    b.border = border
    ResizeIcon(b, DEFAULT_ICON_SIZE)

    local count = b:CreateFontString(nil, "OVERLAY")
    count:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    count:SetPoint("BOTTOMRIGHT", 1, 0)
    count:SetTextColor(1, 1, 1)
    b.count = count

    -- Deja pasar el CLICK al mundo/enemigos debajo (protegido en combate: se
    -- reintenta al salir si Setup() corrio mientras estabas en combate).
    b:EnableMouse(true)
    if b.SetPropagateMouseClicks then
        if not InCombatLockdown() then
            b:SetPropagateMouseClicks(true)
        else
            local waiter = CreateFrame("Frame")
            waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
            waiter:SetScript("OnEvent", function(self)
                self:UnregisterAllEvents()
                if b.SetPropagateMouseClicks then pcall(b.SetPropagateMouseClicks, b, true) end
            end)
        end
    end
    b:Hide()
    return b
end

-- ==========================================================================
-- Factory: arma un grupo completo (party o arena) a partir de su config.
-- cfg = { id, keys, dirDBKey, sizeDBKey, defaultDir, gateFn, autoShowOnCombat,
--         onlyBuffs(key)->bool, skipIfSolo(key)->bool }
-- ==========================================================================
local function MakeAuraHoverGroup(cfg)
    local testMode = false
    local groupTest = {}   -- key -> {Show, Hide, Reanchor}, expuesto tal cual

    local function GetDirection()
        local d = ns.GetDB and ns.GetDB()
        local dir = d and d[cfg.dirDBKey]
        return DIR_INFO[dir] and dir or cfg.defaultDir
    end
    local function GetIconSize()
        local d = ns.GetDB and ns.GetDB()
        local sz = d and d[cfg.sizeDBKey]
        return (type(sz) == "number" and sz >= 12 and sz <= 48) and sz or DEFAULT_ICON_SIZE
    end

    local function Setup(key)
        local u = ns.frames and ns.frames[key]
        if not u or not u.button then return end

        -- Carrier cuelga de UIParent (no de u.button): si la unidad esta
        -- oculta (sin grupo/partido), los hijos de un frame oculto no se
        -- renderizan aunque ellos mismos esten Show()n.
        local carrier = CreateFrame("Frame", "MyCF_AuraHover_" .. cfg.id .. "_" .. key, UIParent)
        carrier:SetSize(1, 1)
        carrier:EnableMouse(false)
        carrier:SetFrameStrata("LOW")
        carrier:SetAlpha(0)

        local icons = {}
        for i = 1, MAX_ICONS do icons[i] = CreateIcon(carrier) end

        local frac, target = 0, 0
        local driver = CreateFrame("Frame")
        local n = 0
        local inCombat = false
        local onlyBuffs = cfg.onlyBuffs and cfg.onlyBuffs(key) or false

        local function ApplyFrac()
            local dir = DIR_INFO[GetDirection()]
            local shift = BASE_GAP + frac * SLIDE_DIST
            carrier:ClearAllPoints()
            if dir.axis == "x" then
                carrier:SetPoint(dir.carrierPoint, u.button, dir.carrierRel, dir.sign * shift, 0)
            else
                carrier:SetPoint(dir.carrierPoint, u.button, dir.carrierRel, 0, dir.sign * shift)
            end
            carrier:SetAlpha(frac * (inCombat and 0.5 or 1))
        end

        local function RefreshIcons()
            local list
            if testMode then
                list = {
                    { icon = QUESTION_MARK_ICON, __fake = true },
                    { icon = QUESTION_MARK_ICON, __fake = true, applications = 2 },
                    { icon = QUESTION_MARK_ICON, __fake = true },
                    { icon = QUESTION_MARK_ICON, __fake = true },
                }
            elseif cfg.skipIfSolo and cfg.skipIfSolo(key) and not IsInGroup() then
                list = {}
            elseif not cfg.gateFn() then
                list = {}
            else
                list = CollectAuras(u.unit, onlyBuffs)
            end
            n = math.min(#list, MAX_ICONS)
            local dir = DIR_INFO[GetDirection()]
            local sz = GetIconSize()
            local step = sz + ICON_GAP
            local rowW = n * sz + math.max(n - 1, 0) * ICON_GAP
            local startX = -rowW / 2 + sz / 2
            for i = 1, MAX_ICONS do
                local b, data = icons[i], list[i]
                if i <= n and data then
                    ResizeIcon(b, sz)
                    b.tex:SetTexture(data.icon)
                    if data.__fake then
                        if b.swipe.Clear then b.swipe:Clear() end
                    else
                        pcall(function()
                            local aid = data.auraInstanceID
                            if aid and C_UnitAuras.GetAuraDuration and b.swipe.SetCooldownFromDurationObject then
                                local durObj = C_UnitAuras.GetAuraDuration(u.unit, aid)
                                if durObj then b.swipe:SetCooldownFromDurationObject(durObj) end
                            end
                        end)
                    end
                    -- `applications` puede ser un numero SECRETO (auras de otras
                    -- unidades en Midnight): type() primero, issecretvalue()
                    -- despues, recien entonces la comparacion aritmetica.
                    local stacks = data.applications
                    local showStacks = type(stacks) == "number" and not (issecretvalue and issecretvalue(stacks)) and stacks > 1
                    b.count:SetText(showStacks and stacks or "")
                    b._auraID = data.auraInstanceID
                    b._fake = data.__fake
                    b._filter = data.__filter
                    if data.__filter == "HARMFUL" then
                        b.border:SetVertexColor(0.85, 0.15, 0.15)
                    else
                        b.border:SetVertexColor(1, 0.82, 0.2)
                    end
                    b:ClearAllPoints()
                    if dir.axis == "x" then
                        local edgePoint = (dir.sign < 0) and "RIGHT" or "LEFT"
                        b:SetPoint(edgePoint, carrier, edgePoint, dir.sign * (i - 1) * step, 0)
                    else
                        b:SetPoint("CENTER", carrier, "CENTER", startX + (i - 1) * step, 0)
                    end
                    b:Show()
                else
                    b:Hide()
                end
            end
        end

        local function OnUpdateHandler(self, elapsed)
            local speed = 1 - 0.5 ^ (elapsed / 0.07)
            frac = frac + (target - frac) * speed
            if math.abs(target - frac) < 0.01 then frac = target end
            ApplyFrac()
            if frac == 0 and target == 0 then
                self:SetScript("OnUpdate", nil)
                self._running = false
            end
        end
        local function StartDriver()
            if driver._running then return end
            driver._running = true
            driver:SetScript("OnUpdate", OnUpdateHandler)
        end

        local hoverZone = CreateFrame("Frame", nil, UIParent)
        hoverZone:SetFrameStrata("LOW")
        -- Regla #2 del usuario ("cero dead zones"): arranca DESHABILITADO,
        -- el ticker de mas abajo lo prende/apaga segun cfg.gateFn() -- antes
        -- este fix solo existia en ArenaAuraPreview.lua, PartyAuraPreview.lua
        -- quedaba con EnableMouse(true) fijo escuchando SIEMPRE, incluso
        -- fuera de dungeon.
        hoverZone:EnableMouse(false)
        if hoverZone.SetPropagateMouseClicks then
            if not InCombatLockdown() then
                hoverZone:SetPropagateMouseClicks(true)
            else
                local waiter = CreateFrame("Frame")
                waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
                waiter:SetScript("OnEvent", function(self)
                    self:UnregisterAllEvents()
                    if hoverZone.SetPropagateMouseClicks then pcall(hoverZone.SetPropagateMouseClicks, hoverZone, true) end
                end)
            end
        end

        -- hoverZone del mismo tamaño que el outline de edicion del boton real
        -- (u.button:GetWidth/Height), pegada al lado correspondiente segun
        -- direccion -- asi el usuario puede saber su area mirando el outline
        -- de Lock, sin adivinar, y nunca tapa el click al boton real.
        local function ReanchorZone()
            local dir = DIR_INFO[GetDirection()]
            local bw = u.button:GetWidth() or GetIconSize()
            local bh = u.button:GetHeight() or GetIconSize()
            hoverZone:ClearAllPoints()
            hoverZone:SetSize(bw, bh)
            hoverZone:SetPoint(dir.carrierPoint, u.button, dir.carrierRel, 0, 0)
        end
        ReanchorZone()

        local hoverActive = false
        local function Recompute()
            local gateOk = cfg.gateFn() or testMode
            local showByCombat = cfg.autoShowOnCombat and inCombat
            target = (gateOk and (hoverActive or showByCombat)) and 1 or 0
            StartDriver()
        end

        local leaveTimer
        local function EvaluateHover()
            local over = u.button:IsMouseOver() or hoverZone:IsMouseOver()
            if over then
                if leaveTimer then leaveTimer:Cancel(); leaveTimer = nil end
                hoverActive = true
                Recompute()
            elseif not leaveTimer then
                -- Regla #4 (transiciones limpias): margen antes de esconder
                -- al salir del hover, no se corta de golpe.
                leaveTimer = C_Timer.NewTimer(LEAVE_DELAY, function()
                    leaveTimer = nil
                    if not (u.button:IsMouseOver() or hoverZone:IsMouseOver()) then
                        hoverActive = false
                        Recompute()
                    end
                end)
            end
        end

        u.button:HookScript("OnEnter", function() RefreshIcons(); EvaluateHover() end)
        u.button:HookScript("OnLeave", EvaluateHover)
        hoverZone:SetScript("OnEnter", function() RefreshIcons(); EvaluateHover() end)
        hoverZone:SetScript("OnLeave", EvaluateHover)

        for i = 1, MAX_ICONS do
            local b = icons[i]
            b:SetScript("OnEnter", function(self)
                -- El fade es por ALPHA (carrier:SetAlpha), que NO afecta
                -- IsVisible()/interactividad: un icono con alpha 0 sigue
                -- siendo hoverable -- cfg.gateFn() es el chequeo real.
                if GameTooltip:IsForbidden() or not self:IsVisible() or not cfg.gateFn() then return end
                if self._fake then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Test Aura " .. tostring(i), 1, 1, 1)
                    GameTooltip:AddLine("Placeholder shown by the test toggle.", 0.8, 0.8, 0.8, true)
                    GameTooltip:Show()
                    return
                end
                if not self._auraID then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local ok = false
                if GameTooltip.SetUnitAuraByAuraInstanceID then
                    ok = pcall(GameTooltip.SetUnitAuraByAuraInstanceID, GameTooltip, u.unit, self._auraID)
                end
                if not ok then
                    if self._filter == "HARMFUL" and GameTooltip.SetUnitDebuffByAuraInstanceID then
                        ok = pcall(GameTooltip.SetUnitDebuffByAuraInstanceID, GameTooltip, u.unit, self._auraID)
                    elseif self._filter == "HELPFUL" and GameTooltip.SetUnitBuffByAuraInstanceID then
                        ok = pcall(GameTooltip.SetUnitBuffByAuraInstanceID, GameTooltip, u.unit, self._auraID)
                    end
                end
                if ok then GameTooltip:Show() else GameTooltip:Hide() end
            end)
            b:SetScript("OnLeave", function()
                if not GameTooltip:IsForbidden() then GameTooltip:Hide() end
            end)
        end

        local lastGateOk = nil
        local refreshTicker = C_Timer.NewTicker(0.3, function()
            local gateOk = cfg.gateFn()
            -- Regla #2: togglea EnableMouse segun el gate -- fuera del tipo de
            -- contenido correcto, el hoverZone no intercepta absolutamente nada.
            if gateOk ~= lastGateOk then
                lastGateOk = gateOk
                hoverZone:EnableMouse(gateOk or testMode)
            end
            -- Si se sale del gate (ej. termina la dungeon/el partido) con el
            -- mouse encima, forzar el recompute sin depender de que el mouse
            -- se mueva o el combate cambie (mismo fix que ya tenia arena).
            if not gateOk and not testMode and hoverActive then
                hoverActive = false
                Recompute()
            end
            -- Regla #3: SIEMPRE combate del propio jugador, nunca u.unit.
            local nowCombat = gateOk and PlayerInCombat()
            if nowCombat ~= inCombat then
                inCombat = nowCombat
                if inCombat then RefreshIcons() end
                Recompute()
            end
            if target == 1 and (testMode or inCombat or u.button:IsMouseOver() or hoverZone:IsMouseOver()) then
                RefreshIcons()
            end
        end)
        carrier._refreshTicker = refreshTicker

        groupTest[key] = {
            Show = function() target = 1; RefreshIcons(); StartDriver() end,
            Hide = function() target = 0; StartDriver() end,
            Reanchor = ReanchorZone,
        }
        ApplyFrac()
    end

    local function RefreshDirection()
        for _, t in pairs(groupTest) do
            if t.Reanchor then pcall(t.Reanchor) end
        end
    end
    local function SetTestMode(on)
        testMode = on and true or false
        for _, t in pairs(groupTest) do
            if t then if testMode then t.Show() else t.Hide() end end
        end
        return testMode
    end

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        C_Timer.After(1, function()
            for _, key in ipairs(cfg.keys) do pcall(Setup, key) end
        end)
    end)

    return {
        test = groupTest,
        RefreshDirection = RefreshDirection,
        ToggleTestMode = function() return SetTestMode(not testMode) end,
    }
end

-- ==========================================================================
-- Instancias: Party (dungeon-only, auto-show en combate) y Arena
-- (arena-only, SOLO hover -- combate constante en arena haria que quedara
-- visible casi todo el partido, mismo criterio ya establecido).
-- ==========================================================================
local party = MakeAuraHoverGroup({
    id = "party", keys = { "party1", "party2", "party3", "party4", "party5" },
    dirDBKey = "partyAuraDirection", sizeDBKey = "partyAuraIconSize", defaultDir = "left",
    gateFn = InDungeon, autoShowOnCombat = true,
    onlyBuffs = function(key) return key == "party5" end,
    -- party5 usa unit="player" (UnitExists("player") siempre true, a
    -- diferencia de party1-4): sin este check, el hoverZone (interactuable
    -- aunque el boton este oculto) mostraria tus propios buffs incluso
    -- jugando solo dentro de una mazmorra.
    skipIfSolo = function(key) return key == "party5" end,
})
local arena = MakeAuraHoverGroup({
    id = "arena", keys = { "arena_player", "arena_party1", "arena_party2", "arena_enemy1", "arena_enemy2", "arena_enemy3" },
    dirDBKey = "arenaAuraDirection", sizeDBKey = "arenaAuraIconSize", defaultDir = "down",
    gateFn = InArenaNow, autoShowOnCombat = false,
    onlyBuffs = function(key) return key == "arena_player" end,
})

-- ==========================================================================
-- API publica (nombres preservados EXACTOS -- Options.lua/core.lua los usan).
-- ==========================================================================
ns.PartyAuraPreviewTest = party.test
ns.ArenaAuraPreviewTest = arena.test
ns.RefreshPartyAuraDirection = party.RefreshDirection
ns.RefreshPartyAuraSize = party.RefreshDirection
ns.RefreshArenaAuraDirection = arena.RefreshDirection
ns.RefreshArenaAuraSize = arena.RefreshDirection
ns.TogglePartyAuraTest = party.ToggleTestMode
ns.ToggleArenaAuraTest = arena.ToggleTestMode
ns.IsPartyAura = function(key) return key == "aura_party" end
ns.IsArenaAura = function(key) return key == "aura_arena" end

SLASH_MCFPARTYTEST1 = "/mcfpartytest"
SlashCmdList["MCFPARTYTEST"] = function()
    print("|cff00ff00[MCF party aura test]|r " .. (ns.TogglePartyAuraTest() and "ON" or "off"))
end
SLASH_MCFARENAAURATEST1 = "/mcfarenaauratest"
SlashCmdList["MCFARENAAURATEST"] = function()
    print("|cff00ff00[MCF arena aura test]|r " .. (ns.ToggleArenaAuraTest() and "ON" or "off"))
end

-- Diagnostico (ya existia en ArenaAuraPreview.lua): vuelca que metodo de
-- deteccion de arena esta devolviendo que.
SLASH_MCFARENADIAG1 = "/mcfarenadiag"
SlashCmdList["MCFARENADIAG"] = function()
    local ok1, isArena = pcall(CheckIsArena)
    local ok2, isRated = pcall(CheckIsRatedArena)
    local ok3, isShuffle = pcall(CheckIsSoloShuffle)
    local ok4, inInst, instanceType = pcall(IsInInstance)
    print(("|cff00ff00[MCF arena diag]|r C_PvP.IsArena=%s/%s  IsRatedArena=%s/%s  IsSoloShuffle=%s/%s"):format(
        tostring(ok1), tostring(isArena), tostring(ok2), tostring(isRated), tostring(ok3), tostring(isShuffle)))
    print(("  IsInInstance: ok=%s inInstance=%s instanceType=%s"):format(tostring(ok4), tostring(inInst), tostring(instanceType)))
    print("  InArenaNow() final result = " .. tostring(InArenaNow()))
end
