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
--  4. Transiciones limpias al sacar el mouse -- REVERTIDO (2026-07-27, pedido
--     del usuario: "no debe depender de mouse over, salgan inmediatamente,
--     al igual que en combate"). Tenia un margen (LEAVE_DELAY, 0.35s) antes
--     de empezar a esconder al salir del hover, para no cortar de golpe si
--     el mouse pasaba de largo un instante -- se sentia mas lento que
--     terminar combate (que esconde apenas cambia el estado). Ahora
--     EvaluateHover reacciona YA, sin timer -- el fade en si sigue siendo
--     suave (frac lerpando, no un corte abrupto), solo que arranca al toque.
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

-- CAMBIADO (2026-07-27, pedido del usuario: "que este en el menu opcion de
-- elegir... limite de auras mostradas... y el padding"): antes MAX_ICONS/
-- ICON_GAP eran constantes fijas, iguales para los 5 grupos. Ahora son
-- valores POR GRUPO, configurables en Options.lua via cfg.maxDBKey/
-- cfg.paddingDBKey (mismo patron que dirDBKey/sizeDBKey) -- estas 2
-- constantes quedan como el TOPE del pool de iconos pre-creados (siempre se
-- crean HARD_MAX_ICONS, se muestran/ocultan segun el limite configurado, sin
-- necesidad de recrear frames si el usuario sube el limite despues) y el
-- default de relleno cuando no hay nada guardado todavia.
local HARD_MAX_ICONS = 8
local DEFAULT_MAX_ICONS = 4
local DEFAULT_ICON_SIZE = 26
local DEFAULT_ICON_GAP = 4
local SLIDE_DIST  = 26
-- Historia (2026-07-27): empezo compartida por los 5 grupos, subida de 4 a
-- 14, 17, 20, 25 y 27 (pedido del usuario: "un poco mas de distancia...
-- estan chocando con el texto de name si es up y con el power bar si es
-- down"). Despues el usuario pidio que el aumento fuera SOLO para
-- Player/Target ("el gap solo para player y target, el focus, arena o party
-- igual que como estaban") -- Party/Arena/Focus vuelven al valor original
-- (4), Player/Target quedan en 30. `cfg.gap` (por grupo, opcional) manda
-- sobre este default cuando esta presente.
local DEFAULT_GAP = 4
local PLAYER_TARGET_GAP = 30
local A = "Interface\\AddOns\\MyCustomFrames\\Assets\\"
local AURA_BORDER = A .. "actionbutton-border square.tga"
local BORDER_SCALE = 0.26
local QUESTION_MARK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Fuente compartida para el numero de cuenta regresiva NATIVO del swipe
-- (2026-07-27, pedido del usuario: "bajarle el tamaño al texto, de todas un
-- poco, y tambien ponerle el color del addon"). Objeto PROPIO (no el
-- MCFAuraTimeFontObj que ya usa Nameplates.lua para lo mismo en las
-- nameplates) -- son 2 sistemas de aura totalmente separados con sus
-- propios ajustes; compartir el mismo objeto haria que uno pisara al otro.
-- ns.GOLD (core.lua) es el color de texto default de TODO el addon.
local MCFAuraHoverTimeFontObj = CreateFont("MCFAuraHoverTimeFontObj")
MCFAuraHoverTimeFontObj:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
MCFAuraHoverTimeFontObj:SetTextColor(ns.GOLD.r, ns.GOLD.g, ns.GOLD.b, 1)

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

-- Tiempo restante para ordenar (2026-07-27, pedido del usuario: "que salgan
-- primero los que tengan menos duracion"): data.expirationTime/data.duration
-- CRUDOS son secretos para auras de otras unidades en Midnight (mismo motivo
-- por el que el swipe/numero de cuenta regresiva se alimenta via
-- SetCooldownFromDurationObject en vez de leerlos -- ver el comentario largo
-- en Nameplates.lua linea ~1284). type() SIEMPRE devuelve "number" aunque el
-- valor sea secreto -- solo issecretvalue() lo distingue, y hay que chequear
-- ANTES de usarlo en aritmetica o comparacion (un "if" sobre un booleano
-- secreto crashea). Por eso esta funcion es la UNICA que toca esos 2 campos:
-- si cualquiera resulta secreto/no-numero, devuelve nil ("sin dato") en vez
-- de arriesgar una comparacion -- funciona de verdad para Player (datos
-- propios, nunca secretos) y cae de vuelta al orden nativo de Blizzard para
-- cualquier unidad donde el juego SI los oculte, sin romper nada.
local function SafeRemaining(data)
    local exp, dur = data.expirationTime, data.duration
    if type(exp) ~= "number" or (issecretvalue and issecretvalue(exp)) then return nil end
    if type(dur) ~= "number" or (issecretvalue and issecretvalue(dur)) then return nil end
    if dur <= 0 then return nil end -- sin duracion (permanente) -- nunca "esta por vencer"
    return exp
end
-- Ordena ascendente por tiempo de vencimiento (el que vence antes, primero).
-- Auras sin dato legible (secreto o permanente) van al final -- no hay forma
-- segura de decir que "ya casi vencen".
local function ByRemaining(a, b)
    local ra, rb = SafeRemaining(a), SafeRemaining(b)
    if ra == nil then return false end
    if rb == nil then return true end
    return ra < rb
end

-- Sort modes (2026-07-27, pedido del usuario: "que este en el menu option
-- de elegir sort, limite de auras mostradas y el padding" -- para los 5
-- grupos). Antes esto era fijo (siempre "priority"); ahora es 1 de 3 modos,
-- configurable por grupo via cfg.sortDBKey:
--   "priority" -- debuffs primero (prioridad original), buffs rellenan lo
--                 que sobra; DENTRO de cada categoria, por ByRemaining.
--   "time"     -- ignora el tipo, mezcla debuffs+buffs en una sola lista y
--                 ordena todo junto por ByRemaining (el que vence antes,
--                 sin importar si es buff o debuff, primero).
--   "index"    -- sin reordenar nada: el orden nativo que devuelve Blizzard
--                 (debuffs primero iguel, pero SIN el sub-orden por tiempo)
--                 -- por si el reordenado se siente "saltarin".
ns.AURA_SORT_MODES = { "priority", "time", "index" }

-- Debuffs tienen prioridad (menos en modo "time"); si hay menos que el limite
-- configurado, se rellena con buffs (onlyBuffs salta los debuffs del todo --
-- unidades "propias", como party5/arena_player, ya muestran sus debuffs en
-- el frame nativo de Blizzard). Se junta TODA la categoria antes de ordenar
-- y recien ahi recortar al limite -- no se puede cortar mientras se escanea
-- como antes de tener sort, porque el orden final depende de todas.
local function CollectAuras(unit, onlyBuffs, maxIcons, sortMode)
    maxIcons = maxIcons or DEFAULT_MAX_ICONS
    local list = {}
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return list end
    local debuffs = {}
    if not onlyBuffs then
        for i = 1, 40 do
            local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HARMFUL")
            if not ok or data == nil then break end
            data.__filter = "HARMFUL"
            debuffs[#debuffs + 1] = data
        end
    end
    local buffs = {}
    for i = 1, 40 do
        local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
        if not ok or data == nil then break end
        data.__filter = "HELPFUL"
        buffs[#buffs + 1] = data
    end

    if sortMode == "time" then
        for _, data in ipairs(buffs) do debuffs[#debuffs + 1] = data end
        pcall(table.sort, debuffs, ByRemaining)
        for _, data in ipairs(debuffs) do
            list[#list + 1] = data
            if #list >= maxIcons then break end
        end
        return list
    end

    if sortMode ~= "index" then
        pcall(table.sort, debuffs, ByRemaining)
        pcall(table.sort, buffs, ByRemaining)
    end
    for _, data in ipairs(debuffs) do
        list[#list + 1] = data
        if #list >= maxIcons then return list end
    end
    for _, data in ipairs(buffs) do
        list[#list + 1] = data
        if #list >= maxIcons then break end
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

-- Registro de TODOS los iconos creados (party+arena) para poder reasignar su
-- borde en vivo cuando cambia la skin global -- antes este archivo usaba un
-- AURA_BORDER local fijo, la unica pieza de auras que NO seguia el sistema
-- de Skins (ver STRUCTURE.md "Hallazgo pendiente" 2026-07-23; Auras.lua y
-- Nameplates.lua ya usaban ns.AURA_BORDER dinamico).
local iconRegistry = {}
ns.RefreshAuraHoverBorder = function()
    local tex = ns.AURA_BORDER or AURA_BORDER
    for _, b in ipairs(iconRegistry) do
        if b.border then b.border:SetTexture(tex) end
    end
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
    -- CAMBIADO (2026-07-27, pedido del usuario: "que se muestren, en
    -- prioridad, debuff, buff y tiempo restante"): antes se ocultaba el
    -- numero de cuenta regresiva a proposito -- ahora se deja visible.
    -- `SetCooldownFromDurationObject` (mas abajo, en RefreshIcons) ya
    -- alimenta este swipe via el objeto de duracion secret-safe de
    -- C_UnitAuras.GetAuraDuration, asi que el numero que Blizzard dibuja
    -- encima tambien lo es -- sin tocar ningun valor secreto a mano.
    if swipe.SetHideCountdownNumbers then swipe:SetHideCountdownNumbers(false) end
    -- Fuente/color propios en vez del default de Blizzard (2026-07-27,
    -- pedido del usuario: texto mas chico, color del addon).
    pcall(swipe.SetCountdownFont, swipe, "MCFAuraHoverTimeFontObj")
    b.swipe = swipe

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture(ns.AURA_BORDER or AURA_BORDER)
    b.border = border
    iconRegistry[#iconRegistry + 1] = b
    ResizeIcon(b, DEFAULT_ICON_SIZE)

    -- Numero de cargas (2026-07-27): 11->9 y blanco->ns.GOLD, mismo pedido
    -- que el swipe de arriba.
    local count = b:CreateFontString(nil, "OVERLAY")
    count:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    count:SetPoint("BOTTOMRIGHT", 1, 0)
    count:SetTextColor(ns.GOLD.r, ns.GOLD.g, ns.GOLD.b)
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
--         onlyBuffs(key)->bool, skipIfSolo(key)->bool, maxDBKey, paddingDBKey,
--         sortDBKey }
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
    -- Mismo patron que GetDirection/GetIconSize arriba (2026-07-27, pedido
    -- del usuario: menu options para limite de auras, padding y sort, los 5
    -- grupos). Leidas EN VIVO cada RefreshIcons -- igual que direccion/
    -- tamaño, un cambio en Options.lua se ve solo en el proximo refresh
    -- (ticker cada 0.3s como mucho, o al toque si estas con el mouse
    -- encima), sin necesidad de un callback de refresco dedicado.
    local function GetMaxIcons()
        local d = ns.GetDB and ns.GetDB()
        local v = d and d[cfg.maxDBKey]
        v = (type(v) == "number") and math.floor(v + 0.5) or nil
        return (v and v >= 1 and v <= HARD_MAX_ICONS) and v or DEFAULT_MAX_ICONS
    end
    local function GetPadding()
        local d = ns.GetDB and ns.GetDB()
        local v = d and d[cfg.paddingDBKey]
        return (type(v) == "number" and v >= 0 and v <= 30) and v or DEFAULT_ICON_GAP
    end
    local function GetSortMode()
        local d = ns.GetDB and ns.GetDB()
        local v = d and d[cfg.sortDBKey]
        for _, m in ipairs(ns.AURA_SORT_MODES) do if m == v then return v end end
        return "priority"
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
        for i = 1, HARD_MAX_ICONS do icons[i] = CreateIcon(carrier) end

        local frac, target = 0, 0
        local driver = CreateFrame("Frame")
        local n = 0
        local inCombat = false
        -- SOLO para Player (2026-07-27, pedido del usuario: "el de player se
        -- muestre si estoy casteando algo, ademas del hover/combate"). Mismo
        -- chequeo SECRET-SAFE ya usado por Explorer para su condicion
        -- "Always show while casting" (ns.ReadCastMode, definido en Units.lua
        -- -- solo compara con nil, nunca opera con el modo en si).
        local isCasting = false
        -- SOLO para Player (2026-07-27, corregido -- pedido del usuario:
        -- "el player debe seguir usando mouse over aunque no tenga target,
        -- solo que con target y combate o cast se muestre siempre; sin
        -- target, solo salga en mouse over igual que party/arena/focus").
        -- El hover NUNCA requiere target (gateFn se queda en "siempre
        -- true"); combate/casteo como auto-reveal SI lo requieren --
        -- acotado por cfg.combatCastNeedsTarget para no afectar a los otros
        -- 4 grupos, que no tienen este concepto.
        local hasTarget = false
        local onlyBuffs = cfg.onlyBuffs and cfg.onlyBuffs(key) or false
        local gap = cfg.gap or DEFAULT_GAP

        local function ApplyFrac()
            local dir = DIR_INFO[GetDirection()]
            local shift = gap + frac * SLIDE_DIST
            carrier:ClearAllPoints()
            if dir.axis == "x" then
                carrier:SetPoint(dir.carrierPoint, u.button, dir.carrierRel, dir.sign * shift, 0)
            else
                carrier:SetPoint(dir.carrierPoint, u.button, dir.carrierRel, 0, dir.sign * shift)
            end
            -- ERA frac*0.5 en combate (2026-07-27, pedido del usuario: "que
            -- los buffs/debuffs tengan el 100% de alpha en combate, tanto
            -- para party, arena y focus") -- antes, revelar por hover EN
            -- COMBATE se veia a mitad de opacidad. Como los 3 grupos pasan
            -- por esta misma funcion, un solo cambio los cubre a los 3.
            carrier:SetAlpha(frac)
        end

        local function RefreshIcons()
            local maxIcons = GetMaxIcons()
            local list
            if testMode then
                -- Refleja el limite configurado en vez de un fijo de 4, para
                -- que el toggle de test sirva de verdad como preview del
                -- limite (2026-07-27, pedido del usuario).
                list = {}
                for i = 1, maxIcons do
                    list[i] = { icon = QUESTION_MARK_ICON, __fake = true, applications = (i == 2) and 2 or nil }
                end
            elseif cfg.skipIfSolo and cfg.skipIfSolo(key) and not IsInGroup() then
                list = {}
            elseif not cfg.gateFn() then
                list = {}
            else
                list = CollectAuras(u.unit, onlyBuffs, maxIcons, GetSortMode())
            end
            n = math.min(#list, maxIcons)
            local dir = DIR_INFO[GetDirection()]
            local sz = GetIconSize()
            local padding = GetPadding()
            local step = sz + padding
            local rowW = n * sz + math.max(n - 1, 0) * padding
            local startX = -rowW / 2 + sz / 2
            for i = 1, HARD_MAX_ICONS do
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
                    -- Color por tipo de dispel (2026-07-27, pedido del usuario):
                    -- mismo lookup que Auras.lua (ns.DebuffTypeColor, expuesto
                    -- ahi -- ese archivo carga ANTES que este en el .toc), en
                    -- vez de duplicar la tabla Magic/Curse/Poison/Disease aca.
                    -- Fallback al rojo generico de siempre si por lo que sea
                    -- ns.DebuffTypeColor no esta disponible.
                    if data.__filter == "HARMFUL" then
                        local c = ns.DebuffTypeColor and ns.DebuffTypeColor(data)
                        if c then
                            b.border:SetVertexColor(c.r, c.g, c.b)
                        else
                            b.border:SetVertexColor(0.85, 0.15, 0.15)
                        end
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
            -- combatCastOk: para el 99% de los grupos (sin cfg.combatCastNeedsTarget)
            -- esto es simplemente `true` -- no cambia nada. SOLO Player lo
            -- necesita: combate/casteo cuentan como auto-reveal UNICAMENTE
            -- si ademas hay target (`hasTarget`, cacheado por el ticker). El
            -- hover (`hoverActive` mas abajo) NUNCA pasa por este chequeo --
            -- sigue funcionando sin target, como Party/Arena/Focus.
            local combatCastOk = (not cfg.combatCastNeedsTarget) or hasTarget
            local showByCombat = cfg.autoShowOnCombat and inCombat and combatCastOk
            local showByCast = cfg.autoShowOnCast and isCasting and combatCastOk
            -- Target (2026-07-27, pedido del usuario: "el de target siempre
            -- se muestre si existe target"): a diferencia de Party/Arena/
            -- Focus (fade in/out por hover/combate), Target queda SIEMPRE
            -- revelado mientras el gate (UnitExists("target")) sea verdadero
            -- -- sin esto seguiria escondido hasta pasar el mouse, que no es
            -- lo pedido.
            local alwaysShow = cfg.alwaysShowOnGate and gateOk
            -- CORREGIDO (2026-07-27, reportado: "el test no funciona con
            -- player/target/focus" + "player sigue activo despues del
            -- hover" -- misma causa para las dos cosas). `testMode` ya
            -- entraba en `gateOk` (linea de arriba), pero NUNCA era motivo
            -- de revelado en si mismo -- Show() (SetTestMode) pone target=1
            -- DIRECTO al togglear, pero cualquier Recompute() posterior (el
            -- ticker corre cada 0.3s) lo reseteaba a 0 porque testMode no
            -- estaba en esta lista. Con Party/Arena rara vez se notaba (nada
            -- mas dispara Recompute() en una sesion de prueba corta); Player
            -- lo dispara seguro (chequeo de casteo en cada tick), asi que
            -- ahi SIEMPRE se rompia -- y si quedaba testMode=true trabado de
            -- una prueba anterior, eso explica el "sigue activo" tambien.
            target = (gateOk and (testMode or alwaysShow or hoverActive or showByCombat or showByCast)) and 1 or 0
            StartDriver()
        end

        -- CAMBIADO (2026-07-27, pedido del usuario: "se queda activo mas
        -- tiempo de lo que me gustaria despues de salir del mouse over...
        -- no debe depender de mouse over, salgan inmediatamente, al igual
        -- que en combate"): antes, salir del hover esperaba LEAVE_DELAY
        -- (0.35s, "Regla #4" original -- pensado para no cortar de golpe si
        -- el mouse pasa de largo un instante) antes de recien ahi empezar a
        -- esconder. Ahora hoverActive se actualiza YA, sin timer -- el fade
        -- visual (frac lerpando hacia target, half-life 0.07s) sigue siendo
        -- suave, pero arranca de inmediato en vez de 0.35s despues, igual
        -- que ya pasaba al terminar el combate.
        local function EvaluateHover()
            local over = u.button:IsMouseOver() or hoverZone:IsMouseOver()
            hoverActive = over
            Recompute()
        end

        u.button:HookScript("OnEnter", function() RefreshIcons(); EvaluateHover() end)
        u.button:HookScript("OnLeave", EvaluateHover)
        hoverZone:SetScript("OnEnter", function() RefreshIcons(); EvaluateHover() end)
        hoverZone:SetScript("OnLeave", EvaluateHover)

        for i = 1, HARD_MAX_ICONS do
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
            --
            -- CORREGIDO (2026-07-27, reportado: "la de target sigue aunque ya
            -- no tenga target"): antes, perder el gate SOLO forzaba un
            -- Recompute si `hoverActive` era true -- valido para Party/Arena/
            -- Focus/Player (su UNICA forma de estar revelados es hover o
            -- combate/casteo, asi que sin hover no habia nada que esconder).
            -- Target rompe ese supuesto: con alwaysShowOnGate, puede estar
            -- revelado SIN haber hover nunca -- si perdias el target sin
            -- estar mirando el mouse justo ahi, nunca se recalculaba, y
            -- quedaba visible para siempre. Recompute() ahora corre en
            -- CUALQUIER transicion del gate, en cualquier direccion.
            if gateOk ~= lastGateOk then
                lastGateOk = gateOk
                hoverZone:EnableMouse(gateOk or testMode)
                if not gateOk then hoverActive = false end
                Recompute()
            end
            -- Regla #3: SIEMPRE combate del propio jugador, nunca u.unit.
            local nowCombat = gateOk and PlayerInCombat()
            if nowCombat ~= inCombat then
                inCombat = nowCombat
                if inCombat then RefreshIcons() end
                Recompute()
            end
            -- Player (2026-07-27): mismo patron que el combate de arriba,
            -- pero para "estoy casteando". Acotado a cfg.autoShowOnCast (solo
            -- Player lo pide) para no gastar ReadCastMode en los grupos que
            -- no lo necesitan.
            if cfg.autoShowOnCast then
                local nowCasting = gateOk and ns.ReadCastMode and ns.ReadCastMode("player") ~= nil
                if nowCasting ~= isCasting then
                    isCasting = nowCasting
                    if isCasting then RefreshIcons() end
                    Recompute()
                end
            end
            -- Player (2026-07-27, corregido): combate/casteo como auto-reveal
            -- SOLO cuentan con target puesto -- sin esto, perder el target
            -- mientras seguis en combate no apagaria el auto-reveal (inCombat
            -- no cambia con el target, asi que nada mas re-evaluaba nada).
            if cfg.combatCastNeedsTarget then
                local nowHasTarget = UnitExists("target") and true or false
                if nowHasTarget ~= hasTarget then
                    hasTarget = nowHasTarget
                    Recompute()
                end
            end
            -- CORREGIDO (2026-07-27, reportado: "que no necesite mouse over
            -- para que salgan a la primera"): Player/Target usan
            -- alwaysShowOnGate, asi que target==1 la mayor parte del tiempo
            -- SIN combate/casteo/hover -- con la condicion vieja, el carrier
            -- se hacia visible (alpha 1) pero RefreshIcons() nunca corria,
            -- asi que quedaban vacios hasta el primer mouseover. Si esta
            -- visible (target==1), sus iconos deben reflejar auras reales,
            -- sin importar el motivo de la revelacion.
            if target == 1 then
                RefreshIcons()
            end
        end)
        carrier._refreshTicker = refreshTicker

        groupTest[key] = {
            Show = function() target = 1; RefreshIcons(); StartDriver() end,
            Hide = function() target = 0; StartDriver() end,
            Reanchor = ReanchorZone,
            -- Diagnostico (2026-07-27, reportado: "la de player sigue activa
            -- despues de salir del hover" -- 2 revisiones del codigo sin
            -- encontrar la causa). Vuelca el estado INTERNO real en vez de
            -- seguir revisando en teoria.
            Debug = function()
                return {
                    hoverActive = hoverActive, target = target, frac = frac,
                    inCombat = inCombat, isCasting = isCasting, hasTarget = hasTarget,
                    gateOk = cfg.gateFn(), buttonOver = u.button:IsMouseOver() and true or false,
                    zoneOver = hoverZone:IsMouseOver() and true or false,
                    carrierAlpha = carrier:GetAlpha(),
                }
            end,
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
    maxDBKey = "partyAuraMaxIcons", paddingDBKey = "partyAuraPadding", sortDBKey = "partyAuraSort",
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
    maxDBKey = "arenaAuraMaxIcons", paddingDBKey = "arenaAuraPadding", sortDBKey = "arenaAuraSort",
    gateFn = InArenaNow, autoShowOnCombat = false,
    onlyBuffs = function(key) return key == "arena_player" end,
})
-- Focus (2026-07-27, pedido del usuario): "quita el de Auras.lua, agregale un
-- sistema similar al de AuraHover" -- Focus paso de ser un grid SIEMPRE
-- visible (como Player/Target) a este mismo sistema hover-only, igual que
-- Party/Arena. A diferencia de esos 2 (gateados por tipo de contenido:
-- dungeon/arena), Focus tiene sentido en CUALQUIER contenido -- el gate real
-- es simplemente "tengo un focus puesto ahora mismo".
local focus = MakeAuraHoverGroup({
    id = "focus", keys = { "focus" },
    dirDBKey = "focusAuraDirection", sizeDBKey = "focusAuraIconSize", defaultDir = "down",
    maxDBKey = "focusAuraMaxIcons", paddingDBKey = "focusAuraPadding", sortDBKey = "focusAuraSort",
    gateFn = function() return UnitExists("focus") end,
    -- autoShowOnCombat=true (como party, no como arena): un focus target se
    -- usa tipicamente para vigilar a alguien puntual DURANTE una pelea (un
    -- healer vigilando al tank, por ejemplo) -- quereer verlo fijo en combate,
    -- sin depender de tener el mouse encima, es el caso de uso real.
    autoShowOnCombat = true,
})
-- Player/Target (2026-07-27, pedido del usuario): "quitar el sistema de
-- auras de player y target [el grid siempre-visible de Auras.lua] y
-- agregarle el de hover" -- se mueven al mismo sistema que Party/Arena/Focus.
-- Pasaron por varios diseños condicionales (hover/combate/casteo/target) el
-- mismo dia -- SIMPLIFICADO al final (pedido del usuario: "deja las auras de
-- player y target siempre activas, no esta funcionando como quiero"): ambos
-- SIEMPRE visibles, sin depender de hover ni de nada mas. Target sigue
-- necesitando que exista target (no hay auras que leer sin uno); Player no
-- necesita ningun gate. `cfg.autoShowOnCombat`/`autoShowOnCast`/
-- `combatCastNeedsTarget` (usados por la version anterior de Player, y
-- todavia por Party/Focus) quedan intactos en MakeAuraHoverGroup por si se
-- necesitan de nuevo -- simplemente ninguno de los 2 los pide ahora.
--
-- FIX (2026-07-27, pedido del usuario: "ojo con el explorer y las auras del
-- player, si el unitframe del player esta oculto, que se oculten tambien"):
-- gateFn ya no es un simple `true` fijo -- lee el alpha EN VIVO del propio
-- unitframe del player (ns.GetElementFrame("player"), expuesto por
-- Explorer.lua) y se apaga si esta practicamente invisible. Cubre Explorer
-- (fade a "Hidden opacity"), pero tambien cualquier otra razon por la que
-- ese frame este en alpha ~0 -- una sola señal, sin acoplarse a la logica
-- interna de Explorer.
--
-- Umbral SUBIDO de 0.05 a 0.5 (2026-07-27, pedido del usuario: "que se
-- oculte y aparezca mas rapido, no haya tanto delay"): el fade de Explorer
-- es EXPONENCIAL (kOut, half-life ~0.20s) -- cruzar por debajo de un umbral
-- muy bajo como 0.05 tarda ~5 half-lives (~1s) porque la cola de la curva se
-- acerca a 0 cada vez mas despacio. Con 0.5 alcanza el corte en 1 sola
-- half-life (~0.2s) -- se siente inmediato en vez de rezagado, y en la
-- direccion contraria (aparecer, kIn mucho mas rapido) sigue siendo
-- practicamente instantaneo.
local function PlayerFrameVisible()
    local f = ns.GetElementFrame and ns.GetElementFrame("player")
    if not f then return true end
    return f:GetAlpha() > 0.5
end
local playerHover = MakeAuraHoverGroup({
    id = "player", keys = { "player" },
    dirDBKey = "playerAuraDirection", sizeDBKey = "playerAuraIconSize", defaultDir = "down",
    maxDBKey = "playerAuraMaxIcons", paddingDBKey = "playerAuraPadding", sortDBKey = "playerAuraSort",
    gateFn = PlayerFrameVisible,
    alwaysShowOnGate = true,
    gap = PLAYER_TARGET_GAP,
})
local targetHover = MakeAuraHoverGroup({
    id = "target", keys = { "target" },
    dirDBKey = "targetAuraDirection", sizeDBKey = "targetAuraIconSize", defaultDir = "down",
    maxDBKey = "targetAuraMaxIcons", paddingDBKey = "targetAuraPadding", sortDBKey = "targetAuraSort",
    gateFn = function() return UnitExists("target") end,
    alwaysShowOnGate = true,
    gap = PLAYER_TARGET_GAP,
})

-- ==========================================================================
-- API publica (nombres preservados EXACTOS -- Options.lua/core.lua los usan).
-- ==========================================================================
ns.PartyAuraPreviewTest = party.test
ns.ArenaAuraPreviewTest = arena.test
ns.FocusAuraPreviewTest = focus.test
ns.PlayerAuraPreviewTest = playerHover.test
ns.TargetAuraPreviewTest = targetHover.test
ns.RefreshPartyAuraDirection = party.RefreshDirection
ns.RefreshPartyAuraSize = party.RefreshDirection
ns.RefreshArenaAuraDirection = arena.RefreshDirection
ns.RefreshArenaAuraSize = arena.RefreshDirection
ns.RefreshFocusAuraDirection = focus.RefreshDirection
ns.RefreshFocusAuraSize = focus.RefreshDirection
ns.RefreshPlayerAuraDirection = playerHover.RefreshDirection
ns.RefreshPlayerAuraSize = playerHover.RefreshDirection
ns.RefreshTargetAuraDirection = targetHover.RefreshDirection
ns.RefreshTargetAuraSize = targetHover.RefreshDirection
-- Max icons/padding/sort (2026-07-27): mismo "nudge" que Direction/Size --
-- GetMaxIcons/GetPadding/GetSortMode ya se leen EN VIVO en cada RefreshIcons,
-- asi que Reanchor (lo que RefreshDirection ejecuta) alcanza para que
-- Options.lua tenga algo que llamar tras cambiar el valor guardado.
ns.RefreshPartyAuraMaxIcons = party.RefreshDirection
ns.RefreshPartyAuraPadding = party.RefreshDirection
ns.RefreshPartyAuraSort = party.RefreshDirection
ns.RefreshArenaAuraMaxIcons = arena.RefreshDirection
ns.RefreshArenaAuraPadding = arena.RefreshDirection
ns.RefreshArenaAuraSort = arena.RefreshDirection
ns.RefreshFocusAuraMaxIcons = focus.RefreshDirection
ns.RefreshFocusAuraPadding = focus.RefreshDirection
ns.RefreshFocusAuraSort = focus.RefreshDirection
ns.RefreshPlayerAuraMaxIcons = playerHover.RefreshDirection
ns.RefreshPlayerAuraPadding = playerHover.RefreshDirection
ns.RefreshPlayerAuraSort = playerHover.RefreshDirection
ns.RefreshTargetAuraMaxIcons = targetHover.RefreshDirection
ns.RefreshTargetAuraPadding = targetHover.RefreshDirection
ns.RefreshTargetAuraSort = targetHover.RefreshDirection
ns.TogglePartyAuraTest = party.ToggleTestMode
ns.ToggleArenaAuraTest = arena.ToggleTestMode
ns.ToggleFocusAuraTest = focus.ToggleTestMode
ns.TogglePlayerAuraTest = playerHover.ToggleTestMode
ns.ToggleTargetAuraTest = targetHover.ToggleTestMode
ns.IsPartyAura = function(key) return key == "aura_party" end
ns.IsArenaAura = function(key) return key == "aura_arena" end
ns.IsFocusAura = function(key) return key == "aura_focus" end
ns.IsPlayerAura = function(key) return key == "aura_player" end
ns.IsTargetAura = function(key) return key == "aura_target" end
ns.FOCUS_AURA_DIRECTIONS = DIRECTIONS
ns.PLAYER_AURA_DIRECTIONS = DIRECTIONS
ns.TARGET_AURA_DIRECTIONS = DIRECTIONS

SLASH_MCFPARTYTEST1 = "/mcfpartytest"
SlashCmdList["MCFPARTYTEST"] = function()
    print("|cff00ff00[MCF party aura test]|r " .. (ns.TogglePartyAuraTest() and "ON" or "off"))
end
SLASH_MCFARENAAURATEST1 = "/mcfarenaauratest"
SlashCmdList["MCFARENAAURATEST"] = function()
    print("|cff00ff00[MCF arena aura test]|r " .. (ns.ToggleArenaAuraTest() and "ON" or "off"))
end
SLASH_MCFFOCUSAURATEST1 = "/mcffocusauratest"
SlashCmdList["MCFFOCUSAURATEST"] = function()
    print("|cff00ff00[MCF focus aura test]|r " .. (ns.ToggleFocusAuraTest() and "ON" or "off"))
end
SLASH_MCFPLAYERAURATEST1 = "/mcfplayerauratest"
SlashCmdList["MCFPLAYERAURATEST"] = function()
    print("|cff00ff00[MCF player aura test]|r " .. (ns.TogglePlayerAuraTest() and "ON" or "off"))
end
SLASH_MCFTARGETAURATEST1 = "/mcftargetauratest"
SlashCmdList["MCFTARGETAURATEST"] = function()
    print("|cff00ff00[MCF target aura test]|r " .. (ns.ToggleTargetAuraTest() and "ON" or "off"))
end

-- Diagnostico (2026-07-27, reportado: "la de player sigue activa despues de
-- salir del hover"): vuelca el estado interno REAL del grupo (hoverActive/
-- target/frac/inCombat/isCasting/gateOk/mouse-over) en vez de seguir
-- revisando la logica en teoria sin poder verla correr en vivo.
SLASH_MCFAURAHOVERDIAG1 = "/mcfaurahoverdiag"
SlashCmdList["MCFAURAHOVERDIAG"] = function(msg)
    local key = (msg or ""):match("^%s*(%S*)")
    if key == "" then key = "player" end
    local groups = { player = playerHover, target = targetHover, focus = focus, party = party, arena = arena }
    local grp
    for _, g in pairs(groups) do if g.test[key] then grp = g.test[key]; break end end
    if not grp or not grp.Debug then
        print("|cffff5555[MCF aurahover diag]|r sin grupo para la key '" .. key .. "' -- probar: player, target, focus, party1-5, arena_player, arena_party1-2, arena_enemy1-3")
        return
    end
    local d = grp.Debug()
    print(("|cff00ff00[MCF aurahover diag]|r key=%s hoverActive=%s target=%s frac=%.2f inCombat=%s isCasting=%s hasTarget=%s gateOk=%s buttonOver=%s zoneOver=%s carrierAlpha=%.2f"):format(
        key, tostring(d.hoverActive), tostring(d.target), d.frac, tostring(d.inCombat), tostring(d.isCasting),
        tostring(d.hasTarget), tostring(d.gateOk), tostring(d.buttonOver), tostring(d.zoneOver), d.carrierAlpha))
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
