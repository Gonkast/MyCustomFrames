-- ==========================================================================
-- PartyAuraPreview.lua — TEST (2026-07-16, pedido del usuario): al pasar el mouse sobre
-- Party1-5, hasta 4 auras (debuffs con prioridad, buffs de relleno) se deslizan + aparecen con
-- fade; en COMBATE se muestran fijas sin necesitar hover. Direccion configurable (izq/der/arriba/
-- abajo) desde el menu. No ocupa espacio en pantalla cuando no hay hover ni combate.
--
-- HISTORIAL DE RONDAS (mismo dia, iterando con feedback del usuario en juego):
-- R1: version inicial, solo Party1, child de u.button (bug: no se veia sin grupo real).
-- R2: carrier movido a child de UIParent + hoverZone unica (bug GRAVE: tapaba el click al
--     boton real de Party1 porque hoverZone se superponia con el).
-- R3: hoverZone re-anclada para NUNCA superponerse con el boton + LEAVE_DELAY (que se quede un
--     segundo) + SLIDE_DIST bajado 90->56->26 (se iban lejos).
-- R4: borde 0.26 (igual al resto de auras) + visible FIJO en combate (poll UnitAffectingCombat).
-- R5 (esta): generalizado a Party1-5 (data-driven) + direccion configurable (menu) + strata
--     LOW (antes HIGH, pedido del usuario).
--
-- Deliberadamente separado del sistema completo de AURAS de core.lua (grid config, color por
-- dispel real, cancelar buff): ese esta pensado para grupos SIEMPRE visibles con posicion
-- editable; este es fundamentalmente distinto (oculto por defecto, revelado por hover/combate).
-- Si el test convence del todo, fusionar mas adelante.
-- ==========================================================================
local ADDON, ns = ...

local PARTY_KEYS = { "party1", "party2", "party3", "party4", "party5" }
local MAX_ICONS   = 4
local DEFAULT_ICON_SIZE = 26
local ICON_GAP    = 4
local SLIDE_DIST  = 26    -- cuanto se desliza al revelarse (bajado 90->56->26, feedback usuario)
local LEAVE_DELAY = 0.35  -- margen (seg) antes de esconder al salir del hover
local BASE_GAP    = 4     -- separacion minima entre el frame y el grupo de auras, en reposo
local A = "Interface\\AddOns\\MyCustomFrames\\Assets\\"
local AURA_BORDER = A .. "actionbutton-border square.tga"
local BORDER_SCALE = 0.26  -- igual al borderScale default de las auras de player/target (core.lua)
local QUESTION_MARK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Direccion + tamaño configurables desde el menu (Auras > Party, Options.lua) — GLOBALES, aplican
-- a las 5 party frames por igual (no hay edicion por-unidad, a diferencia del resto del addon).
-- db.partyAuraDirection / db.partyAuraIconSize. DIR_INFO define como se ancla el carrier respecto
-- al boton por eje. `GetIconSize()` se relee EN VIVO en cada RefreshIcons/ReanchorZone (barato,
-- 1 lectura de db) asi que cambiar el slider del menu se ve al instante sin recrear frames.
local DIRECTIONS = { "left", "right", "up", "down" }
ns.PARTY_AURA_DIRECTIONS = DIRECTIONS
local DIR_INFO = {
    left  = { carrierPoint = "RIGHT",  carrierRel = "LEFT",   axis = "x", sign = -1 },
    right = { carrierPoint = "LEFT",   carrierRel = "RIGHT",  axis = "x", sign = 1 },
    up    = { carrierPoint = "BOTTOM", carrierRel = "TOP",    axis = "y", sign = 1 },
    down  = { carrierPoint = "TOP",    carrierRel = "BOTTOM", axis = "y", sign = -1 },
}
local function GetDirection()
    local d = ns.GetDB and ns.GetDB()
    local dir = d and d.partyAuraDirection
    return DIR_INFO[dir] and dir or "left"
end
local function GetIconSize()
    local d = ns.GetDB and ns.GetDB()
    local sz = d and d.partyAuraIconSize
    return (type(sz) == "number" and sz >= 12 and sz <= 48) and sz or DEFAULT_ICON_SIZE
end

-- Modo de prueba (/mcfpartytest): fuerza 4 iconos de PLACEHOLDER (signo de interrogacion) y el
-- reveal en LAS 5 party frames a la vez, sin depender de grupo real ni de auras reales.
local testMode = false

local function SafeInCombat(unit)
    local ok, r = pcall(UnitAffectingCombat, unit)
    if not ok or (issecretvalue and issecretvalue(r)) then return false end
    return r and true or false
end

-- Pedido del usuario 2026-07-19: "las auras de party estan saliendo en
-- arena" -- el "fijo visible en combate" (ver Recompute/refreshTicker mas
-- abajo) se disparaba tambien en arena, donde estas CASI SIEMPRE en combate
-- -- termina siendo un overlay permanente sobre tus companeros durante todo
-- el match, mas clutter del que sirve en un contexto tan rapido. El hover
-- manual sigue funcionando igual en arena, solo se desactiva el auto-show
-- por combate.
-- 2026-07-19 (2): confirmado con /mcfarenadiag en vivo -- el usuario estaba
-- en un BATTLEGROUND, no una arena clasica: IsInInstance() devuelve
-- instanceType="pvp" para BGs ("arena" es SOLO para arenas 2v2/3v3/shuffle
-- en la terminologia de Blizzard). Como en ambos estas casi siempre en
-- combate, se tratan igual aca -- "pvp" O "arena" desactivan el auto-show.
-- Pedido del usuario 2026-07-19: "necesito que las auras de party sean
-- exclusivos de dungeons" -- instanceType == "party" es justamente como
-- Blizzard identifica mazmorras (5-man) en IsInInstance(); mundo abierto,
-- raids, escenarios, arena y battleground quedan todos afuera.
local function InDungeon()
    local ok, _, instanceType = pcall(IsInInstance)
    return ok and instanceType == "party"
end

-- PERF (2026-07-19, "arregla todo"): InArena() se llama desde un ticker de
-- 0.3s POR unidad de party (x5) -- antes creaba 3 closures descartables
-- (`function() return C_PvP... end`) en CADA llamada solo para poder
-- pcall-earlas. Hoisteadas a nivel de modulo (no capturan nada que cambie),
-- se crean UNA vez.
local function CheckIsArena() return C_PvP and C_PvP.IsArena and C_PvP.IsArena() end
local function CheckIsRatedArena() return C_PvP and C_PvP.IsRatedArena and C_PvP.IsRatedArena() end
local function CheckIsSoloShuffle() return C_PvP and C_PvP.IsSoloShuffle and C_PvP.IsSoloShuffle() end
local function InArena()
    local ok1, isArena = pcall(CheckIsArena)
    if ok1 and isArena then return true end
    local ok2, isRated = pcall(CheckIsRatedArena)
    if ok2 and isRated then return true end
    local ok3, isShuffle = pcall(CheckIsSoloShuffle)
    if ok3 and isShuffle then return true end
    local ok4, _, instanceType = pcall(IsInInstance)
    if ok4 and (instanceType == "arena" or instanceType == "pvp") then return true end
    return false
end

-- Debuffs TIENEN PRIORIDAD; si hay menos de MAX_ICONS debuffs, se rellena con buffs normales
-- (se recalcula de cero en cada refresh, los buffs ceden apenas aparece un debuff nuevo).
-- `onlyBuffs` (pedido del usuario 2026-07-16, para party5/player): salta los debuffs del todo —
-- tus propios debuffs ya se ven en el frame de auras nativo de Blizzard; aca solo interesan tus
-- buffs (cooldowns/buffs activos), no un duplicado de lo que Blizzard ya muestra.
local function CollectPartyAuras(unit, onlyBuffs)
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

-- ResizeIcon: aplica el tamaño ACTUAL (leido de db) a un icono ya creado — se llama en cada
-- RefreshIcons (barato) para que el slider del menu se vea al instante sin recrear frames. El
-- borde no escala solo (sus anchors son offsets fijos calculados a mano), asi que hay que
-- recalcular el inset cada vez que cambia el tamaño.
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

    -- FIX (2026-07-16, pedido del usuario: "no puedo clickear el fondo/mundo/enemigos donde
    -- salen las auras"): EnableMouse(true) por si solo INTERCEPTA todo, tapando clicks al mundo
    -- 3D debajo (esa zona normalmente es viewport de juego, no UI). SetPropagateMouseClicks dejar
    -- pasar el CLICK hacia lo que este atras (hasta el WorldFrame si no hay nada mas) sin afectar
    -- el hover/tooltip (OnEnter/OnLeave siguen disparando igual, solo cambia el ruteo del click).
    -- No hay ningun OnClick propio en los iconos (solo tooltip), asi que no se pierde nada.
    -- FIX (2026-07-16): SetPropagateMouseClicks esta PROTEGIDA en combate para CUALQUIER frame
    -- (no solo frames seguros) — si Setup() se re-ejecuta en combate (ej. GROUP_ROSTER_UPDATE)
    -- tira ADDON_ACTION_BLOCKED. Se salta fuera de combate y se reintenta al salir de el.
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

ns.PartyAuraPreviewTest = {}   -- key -> {Show, Hide} expuesto para el SlashCmdList

local function Setup(key)
    local u = ns.frames and ns.frames[key]
    if not u or not u.button then return end

    -- El carrier cuelga de UIParent (NO de u.button): si la unidad esta oculta (sin grupo), los
    -- hijos de un frame oculto no se renderizan aunque ellos mismos esten Show()n. Colgar de
    -- UIParent + solo ANCLAR (SetPoint) al boton real resuelve la posicion igual (anclar a un
    -- frame oculto funciona) sin depender de que este visible.
    local carrier = CreateFrame("Frame", "MyCF_PartyAuraPreview_" .. key, UIParent)
    carrier:SetSize(1, 1)
    carrier:EnableMouse(false)
    carrier:SetFrameStrata("LOW")   -- pedido del usuario: LOW/BACKGROUND, antes HIGH
    carrier:SetAlpha(0)

    local icons = {}
    for i = 1, MAX_ICONS do icons[i] = CreateIcon(carrier) end

    local frac, target = 0, 0
    local driver = CreateFrame("Frame")
    local n = 0
    -- inCombat se declara ACA (no mas abajo, junto a hoverActive) para que ApplyFrac pueda
    -- leerla como upvalue -- pedido del usuario (2026-07-16): las auras de party a 50% de
    -- opacidad en combate (100% fuera de combate, con hover normal).
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

    local function RefreshIcons()
        local list
        if testMode then
            list = {
                { icon = QUESTION_MARK_ICON, __fake = true },
                { icon = QUESTION_MARK_ICON, __fake = true, applications = 2 },
                { icon = QUESTION_MARK_ICON, __fake = true },
                { icon = QUESTION_MARK_ICON, __fake = true },
            }
        elseif key == "party5" and not IsInGroup() then
            -- party5 usa unit="player" (ver nota en core.lua UNITS): UnitExists("player") es
            -- SIEMPRE true, a diferencia de party1-4 (que no existen sin grupo y por eso
            -- CollectPartyAuras ya devuelve vacio solo). Sin este chequeo, el hover zone
            -- (child de UIParent, sigue interactuable aunque el boton este oculto) mostraria
            -- tus propios buffs/debuffs flotando en pantalla incluso jugando solo.
            list = {}
        else
            list = CollectPartyAuras(u.unit, key == "party5")
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
                -- FIX (taint reportado en juego): `applications` puede ser un NUMERO SECRETO
                -- (auras de otras unidades en Midnight) — comparar `stacks > 1` sin chequear
                -- `issecretvalue` primero crashea ("attempt to compare... secret number value").
                -- Mismo orden de guard que usa el resto del addon: type() primero (no crashea con
                -- secretos), issecretvalue() despues, y RECIEN entonces la comparacion aritmetica.
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
                    -- Fila horizontal CENTRADA en el carrier (crece hacia los costados desde el
                    -- centro), igual criterio "centrado horizontal" que usa el grid de auras de
                    -- player/target en core.lua — solo aplica cuando el grupo se desliza arriba/abajo.
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
    hoverZone:EnableMouse(true)
    -- Deja pasar el CLICK al mundo/enemigos de abajo (mismo motivo/mecanismo que en CreateIcon):
    -- sin esto, un frame invisible con EnableMouse capturaba TODO click en esa zona, aunque
    -- visualmente ahi no hay nada nuestro (es viewport de juego, no un boton real).
    -- FIX (2026-07-16, mismo bug que en CreateIcon): SetPropagateMouseClicks esta PROTEGIDA en
    -- combate para CUALQUIER frame. Setup() corre en el login (1er personaje/instalacion limpia
    -- puede arrancar ya en combate, ej. reingresando a una mazmorra) -> ADDON_ACTION_BLOCKED si
    -- se llama sin chequear. Se salta en combate y se reintenta al salir.
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

    -- FIX (2026-07-16, pedido del usuario: "el boton del mouseover esta muy grande, se activa
    -- pasando por fuera de mi unidad"): antes `hoverZone` crecia con la cantidad/tamaño de
    -- iconos (SLIDE_DIST + 4*step), mucho mas grande que el frame real -> el mouse disparaba el
    -- reveal lejos de la barra. Ahora `hoverZone` es del MISMO tamaño que el OUTLINE de edicion
    -- (el borde que ves en modo Lock, `MakeEditHighlight` = `f:SetAllPoints(parent)`, o sea
    -- exactamente `u.button:GetWidth()/GetHeight()`) — asi el usuario puede saber su tamaño
    -- mirando el outline en /mcf, sin adivinar. Se posiciona PEGADA al lado correspondiente del
    -- boton (no superpuesta, sigue sin tapar el click real).
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
        -- Exclusivo de dungeons -- ni el hover ni el auto-show por combate
        -- funcionan afuera de una mazmorra (mundo abierto, raid, arena, BG).
        -- FIX (2026-07-19, mismo bug ya arreglado en ArenaAuraPreview.lua
        -- pero que se me paso replicar aca: "no esta funcionando asi en las
        -- de party"): /mcfpartytest fuerza target=1 al activarse, pero fuera
        -- de una mazmorra real el PRIMER hover disparaba este Recompute y lo
        -- pisaba de vuelta a 0 (InDungeon() daba false) -- se veian y se
        -- escondian al pasar el mouse. testMode ahora tambien pasa el gate,
        -- igual que ya hacia RefreshIcons().
        target = ((InDungeon() or testMode) and (hoverActive or inCombat)) and 1 or 0
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
            -- Pedido del usuario 2026-07-19: "aunque desaparecieron en BG,
            -- puedo ver el tooltip" -- el fade es por ALPHA (carrier:SetAlpha),
            -- que NO afecta IsVisible() ni la interactividad del mouse: un
            -- icono con alpha 0 sigue siendo "visible" para IsVisible() y
            -- totalmente hoverable. InDungeon() es el chequeo real que
            -- corresponde aca (mismo gate que Recompute()).
            if GameTooltip:IsForbidden() or not self:IsVisible() or not InDungeon() then return end
            if self._fake then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Test Aura " .. tostring(i), 1, 1, 1)
                GameTooltip:AddLine("Placeholder shown by /mcfpartytest.", 0.8, 0.8, 0.8, true)
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

    local refreshTicker = C_Timer.NewTicker(0.3, function()
        -- FIX (2026-07-20, mismo bug reportado y arreglado en ArenaAuraPreview.lua,
        -- "revisa que no pase tambien con los de party"): Recompute() solo se llamaba
        -- desde EvaluateHover (mouse enter/leave) o desde este ticker cuando cambiaba
        -- el combate -- si salias de la mazmorra con el mouse ENCIMA y sin cambiar de
        -- combate, target se quedaba en 1 para siempre. Se fuerza el recompute apenas
        -- se detecta la salida de la mazmorra, sin depender de mouse/combate.
        if not InDungeon() and not testMode and hoverActive then
            hoverActive = false
            Recompute()
        end
        local nowCombat = (not InArena()) and SafeInCombat(u.unit)
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

    ns.PartyAuraPreviewTest[key] = {
        Show = function() target = 1; RefreshIcons(); StartDriver() end,
        Hide = function() target = 0; StartDriver() end,
        Reanchor = ReanchorZone,
    }

    ApplyFrac()
end

-- Expuesto para el menu (Options.lua): al cambiar db.partyAuraDirection O db.partyAuraIconSize,
-- re-ancla las 5 zonas de hover de una (el carrier/iconos ya leen ambos EN VIVO en cada
-- ApplyFrac/RefreshIcons, solo el hoverZone estatico necesita re-calcularse a mano). Mismo
-- recompute sirve para los 2 settings, de ahi el alias.
function ns.RefreshPartyAuraDirection()
    for _, t in pairs(ns.PartyAuraPreviewTest) do
        if t.Reanchor then pcall(t.Reanchor) end
    end
end
ns.RefreshPartyAuraSize = ns.RefreshPartyAuraDirection

-- "Party" como elemento SINGLETON del menu (grupo AURAS, seccion propia) — igual patron que
-- Tracker/Glow/Micro Menu: una sola entrada que controla LAS 5 party frames a la vez, no
-- pestañas por-unidad.
ns.IsPartyAura = function(key) return key == "aura_party" end

-- Pedido del usuario 2026-07-19: boton en el menu para testear el hover sin
-- necesitar grupo real -- antes esto solo era accesible seteando `testMode`
-- a mano (no habia ni slash command). Devuelve el nuevo estado para que el
-- boton del footer (Options.lua) pueda reflejarlo visualmente.
local function SetTestMode(on)
    testMode = on and true or false
    for _, t in pairs(ns.PartyAuraPreviewTest) do
        if t then if testMode then t.Show() else t.Hide() end end
    end
    return testMode
end
ns.TogglePartyAuraTest = function() return SetTestMode(not testMode) end

SLASH_MCFPARTYTEST1 = "/mcfpartytest"
SlashCmdList["MCFPARTYTEST"] = function()
    print("|cff00ff00[MCF party aura test]|r " .. (ns.TogglePartyAuraTest() and "ON" or "off"))
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    C_Timer.After(1, function()
        for _, key in ipairs(PARTY_KEYS) do pcall(Setup, key) end
    end)
end)

-- Diagnostico 2026-07-19 (pedido del usuario: "se siguen mostrando en
-- arena" despues del primer intento) -- vuelca que metodo de deteccion de
-- arena esta devolviendo que, para confirmar si InArena() esta fallando.
SLASH_MCFARENADIAG1 = "/mcfarenadiag"
SlashCmdList["MCFARENADIAG"] = function()
    local ok1, isArena = pcall(function() return C_PvP and C_PvP.IsArena and C_PvP.IsArena() end)
    local ok2, isRated = pcall(function() return C_PvP and C_PvP.IsRatedArena and C_PvP.IsRatedArena() end)
    local ok3, isShuffle = pcall(function() return C_PvP and C_PvP.IsSoloShuffle and C_PvP.IsSoloShuffle() end)
    local ok4, inInst, instanceType = pcall(IsInInstance)
    print(("|cff00ff00[MCF arena diag]|r C_PvP.IsArena=%s/%s  IsRatedArena=%s/%s  IsSoloShuffle=%s/%s"):format(
        tostring(ok1), tostring(isArena), tostring(ok2), tostring(isRated), tostring(ok3), tostring(isShuffle)))
    print(("  IsInInstance: ok=%s inInstance=%s instanceType=%s"):format(tostring(ok4), tostring(inInst), tostring(instanceType)))
    print("  InArena() final result = " .. tostring(InArena()))
end
