-- ==========================================================================
-- MyCustomFrames - ArenaAuraPreview.lua
-- Pedido del usuario 2026-07-19: "estas 6 [arena] tienen el mismo sistema de
-- auras como las party pero se despliegan hacia abajo... todas esta auras
-- esten en una casilla juntas de arena, asi como las de party". Adaptado de
-- PartyAuraPreview.lua (NO se toca ese archivo, es una copia independiente
-- para las 6 unitframes de arena) -- mismo hover/combat reveal, direccion por
-- defecto "down", exclusivo de ARENA (instanceType=="arena"), y una sola
-- entrada de menu ("Arena Auras") controla las 6 a la vez.
-- ==========================================================================
local ADDON, ns = ...

local ARENA_KEYS = { "arena_player", "arena_party1", "arena_party2", "arena_enemy1", "arena_enemy2", "arena_enemy3" }
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

-- Direccion + tamaño (menu Auras > Arena) -- GLOBALES para las 6 a la vez, mismo
-- patron que db.partyAuraDirection/partyAuraIconSize pero namespace propio
-- (db.arenaAuraDirection/arenaAuraIconSize) para no compartir estado con party.
-- Default "down" (pedido del usuario: "se despliegan hacia abajo").
local DIRECTIONS = { "left", "right", "up", "down" }
ns.ARENA_AURA_DIRECTIONS = DIRECTIONS
local DIR_INFO = {
    left  = { carrierPoint = "RIGHT",  carrierRel = "LEFT",   axis = "x", sign = -1 },
    right = { carrierPoint = "LEFT",   carrierRel = "RIGHT",  axis = "x", sign = 1 },
    up    = { carrierPoint = "BOTTOM", carrierRel = "TOP",    axis = "y", sign = 1 },
    down  = { carrierPoint = "TOP",    carrierRel = "BOTTOM", axis = "y", sign = -1 },
}
local function GetDirection()
    local d = ns.GetDB and ns.GetDB()
    local dir = d and d.arenaAuraDirection
    return DIR_INFO[dir] and dir or "down"
end
local function GetIconSize()
    local d = ns.GetDB and ns.GetDB()
    local sz = d and d.arenaAuraIconSize
    return (type(sz) == "number" and sz >= 12 and sz <= 48) and sz or DEFAULT_ICON_SIZE
end

local testMode = false

-- "En arena" -- a diferencia de PartyAuraPreview (que EXCLUYE arena), este
-- modulo es EXCLUSIVO de arena: solo instanceType=="arena" (2v2/3v3/shuffle
-- clasicos). Los battlegrounds ("pvp") quedan afuera a proposito (mismo
-- criterio que UpdateArenaDrivers en Units.lua -- las unitframes de arena ya
-- estan ocultas fuera de instanceType=="arena", este gate es la misma regla
-- aplicada al sistema de auras).
local function InArenaNow()
    local ok, _, instanceType = pcall(IsInInstance)
    return ok and instanceType == "arena"
end

local function SafeInCombat(unit)
    local ok, r = pcall(UnitAffectingCombat, unit)
    if not ok or (issecretvalue and issecretvalue(r)) then return false end
    return r and true or false
end

local function CollectArenaAuras(unit, onlyBuffs)
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

ns.ArenaAuraPreviewTest = {}

local function Setup(key)
    local u = ns.frames and ns.frames[key]
    if not u or not u.button then return end

    local carrier = CreateFrame("Frame", "MyCF_ArenaAuraPreview_" .. key, UIParent)
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

    -- arena_player usa unit="player" (siempre existe, como party5 en el
    -- sistema de party) -- SOLO buffs propios, evita duplicar lo que ya
    -- muestra el frame de auras nativo.
    local onlyBuffs = (key == "arena_player")

    local function RefreshIcons()
        local list
        if testMode then
            list = {
                { icon = QUESTION_MARK_ICON, __fake = true },
                { icon = QUESTION_MARK_ICON, __fake = true, applications = 2 },
                { icon = QUESTION_MARK_ICON, __fake = true },
                { icon = QUESTION_MARK_ICON, __fake = true },
            }
        elseif not InArenaNow() then
            list = {}
        else
            list = CollectArenaAuras(u.unit, onlyBuffs)
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
    -- Arranca DESHABILITADO -- el ticker de mas abajo lo prende solo si
    -- InArenaNow() (evita la dead zone hasta el primer tick, ver mas abajo).
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
        -- CORREGIDO (2026-07-19, "estan y se esconden, deberia estar
        -- escondidas y salir con mouse over"): el auto-show por combate
        -- (copiado de Party Auras) hacia que quedaran visibles CASI TODO el
        -- partido -- en arena estas en combate casi permanentemente, al
        -- reves del efecto buscado (hover-reveal puntual). Ahora exclusivo
        -- de hover -- inCombat solo se usa para atenuar opacidad (ver
        -- ApplyFrac), no para forzar el show.
        -- 2do bug (mismo reporte, "paso sobre ellas y se esconden"): el gate
        -- InArenaNow() tambien corria ADENTRO de Recompute (llamado por
        -- EvaluateHover en cada mouseover) -- /mcfarenaauratest fuerza
        -- target=1 al activarse, pero fuera de una arena real el PRIMER
        -- hover disparaba este Recompute y lo pisaba de vuelta a 0 (in-arena
        -- daba false). testMode ahora tambien pasa el gate, igual que ya
        -- hacia RefreshIcons().
        target = ((InArenaNow() or testMode) and hoverActive) and 1 or 0
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
            if GameTooltip:IsForbidden() or not self:IsVisible() or not InArenaNow() then return end
            if self._fake then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Test Aura " .. tostring(i), 1, 1, 1)
                GameTooltip:AddLine("Placeholder shown by /mcfarenaauratest.", 0.8, 0.8, 0.8, true)
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

    -- Pedido del usuario 2026-07-19: "dejan una dead zone... aunque no
    -- aparezcan" -- hoverZone es un frame propio (colgado de UIParent, NO de
    -- u.button) con EnableMouse(true) permanente desde su creacion, sin
    -- importar si estas en arena o no -- queda ahi, mouse-habilitado, en la
    -- posicion del grupo de arena SIEMPRE, aunque el unitframe este oculto.
    -- Se togglea EnableMouse segun InArenaNow() (barato, ya se calcula cada
    -- 0.3s en este mismo ticker) para que fuera de arena no intercepte nada.
    local lastMouseEnabled = nil
    local refreshTicker = C_Timer.NewTicker(0.3, function()
        local inArenaNow = InArenaNow()
        if inArenaNow ~= lastMouseEnabled then
            lastMouseEnabled = inArenaNow
            hoverZone:EnableMouse(inArenaNow or testMode)
        end
        local nowCombat = inArenaNow and SafeInCombat(u.unit)
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

    ns.ArenaAuraPreviewTest[key] = {
        Show = function() target = 1; RefreshIcons(); StartDriver() end,
        Hide = function() target = 0; StartDriver() end,
        Reanchor = ReanchorZone,
    }

    ApplyFrac()
end

-- Expuesto para el menu (Options.lua): re-ancla las 6 zonas de hover al cambiar
-- direccion/tamaño (mismo patron que RefreshPartyAuraDirection).
function ns.RefreshArenaAuraDirection()
    for _, t in pairs(ns.ArenaAuraPreviewTest) do
        if t.Reanchor then pcall(t.Reanchor) end
    end
end
ns.RefreshArenaAuraSize = ns.RefreshArenaAuraDirection

-- "Arena" como elemento SINGLETON del menu (grupo AURAS) -- una sola entrada
-- controla las 6 unitframes de arena a la vez (pedido del usuario: "todas
-- esta auras esten en una casilla juntas de arena, asi como las de party").
ns.IsArenaAura = function(key) return key == "aura_arena" end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    C_Timer.After(1, function()
        for _, key in ipairs(ARENA_KEYS) do pcall(Setup, key) end
    end)
end)

-- Pedido del usuario 2026-07-19: boton en el menu para testear el hover sin
-- necesitar un partido real -- extraido del slash command para que el
-- footer (Options.lua) pueda llamarlo tambien. Devuelve el nuevo estado.
local function SetTestMode(on)
    testMode = on and true or false
    for _, key in ipairs(ARENA_KEYS) do
        local t = ns.ArenaAuraPreviewTest[key]
        if t then if testMode then t.Show() else t.Hide() end end
    end
    return testMode
end
ns.ToggleArenaAuraTest = function() return SetTestMode(not testMode) end

SLASH_MCFARENAAURATEST1 = "/mcfarenaauratest"
SlashCmdList["MCFARENAAURATEST"] = function()
    print("|cff00ff00[MCF arena aura test]|r " .. (ns.ToggleArenaAuraTest() and "ON" or "off"))
end
