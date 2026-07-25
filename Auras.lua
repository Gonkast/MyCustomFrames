-- ==========================================================================
-- MyCustomFrames - Auras.lua
-- AURAS (buffs/debuffs de player y target, grid, cancelar buff con clic derecho).
-- Extraido de core.lua (mismo motivo/patron que Units.lua/Portraits.lua): margen
-- de locals, usa ns.GetDB()/ns.IsUnlocked() en vez de los locals db/unlocked de core.
-- Carga DESPUES de core.lua, Units.lua y Portraits.lua en el toc.
-- ==========================================================================
local ADDON, ns = ...



-- ==========================================================================
-- ns.AURAS: creacion y logica
-- ==========================================================================
local function AP(g) return ns.GetDB().auras[g.key] end

-- Numero legible (no secreto), o fallback.
local function SafeNum(v, fb)
    if type(v) ~= "number" then return fb end
    if issecretvalue and issecretvalue(v) then return fb end
    return v
end

-- Condicion "engaged": combate / objetivo / instancia (segun toggles). Solo dualPos.
local function AuraCondActive(p)
    local a = false
    if p.centerInCombat and ns.tickState.inCombat then a = true end
    if not a and p.centerOnTarget then if UnitExists("target") then a = true end end
    if not a and p.centerInInstance and ns.safeBool(IsInInstance) then a = true end
    return a
end

-- Opacidad del grupo (solo dualPos = player): base p.groupAlpha; 100% si hay condicion
-- (combate/objetivo/instancia) o si la aura tiene el mouse encima (b._hover).
local function UpdateAuraAlpha(g)
    if not g.dualPos then return end
    local p = AP(g)
    local base = p.groupAlpha or 1
    local full = ns.IsUnlocked() or (base >= 1) or AuraCondActive(p)
    for _, b in ipairs(g.buttons) do
        if b:IsShown() then b:SetAlpha((full or b._hover) and 1 or base) end
    end
end

-- Clave de tiempo para ordenar: permanentes (dur 0) al final; secretos al final.
local function AuraTimeKey(d)
    local dur = SafeNum(d.duration, 0)
    if dur == 0 then return math.huge end
    return SafeNum(d.expirationTime, math.huge)
end

local AURA_SORTS = {
    index    = nil,   -- orden de la API
    timeUp   = function(a, b) return AuraTimeKey(a) < AuraTimeKey(b) end,
    timeDown = function(a, b) return AuraTimeKey(a) > AuraTimeKey(b) end,
    name     = function(a, b) return tostring(a.name or "") < tostring(b.name or "") end,
}

-- Recolecta las ns.auras de la unidad combinando buffs + debuffs (secret-safe).
-- Etiqueta cada aura con __filter para el tooltip (HELPFUL/HARMFUL).
local collectScratch = {}   -- tabla reutilizada (se consume sincronamente en UpdateAuraGroup)
local function CollectAuras(unit)
    -- Corre en cada UNIT_AURA: antes creaba una tabla nueva + hasta 80 closures
    -- por pasada (basura para el GC en combate). Ahora: scratch + pcall directo.
    local list = collectScratch
    wipe(list)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return list end
    for f = 1, 2 do
        local filter = (f == 1) and "HELPFUL" or "HARMFUL"
        for i = 1, 40 do
            local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
            if not ok or data == nil then break end
            data.__filter = filter
            list[#list + 1] = data
        end
    end
    return list
end

-- Aplica el cooldown de la aura (duracion). SECRET-SAFE: usa el "duration object"
-- (SetCooldownFromDurationObject); los numeros de cuenta atras los formatea C.
local function ApplyAuraCooldown(cd, unit, data)
    if not cd then return end
    local aid = data.auraInstanceID
    if aid ~= nil and C_UnitAuras and C_UnitAuras.GetAuraDuration and cd.SetCooldownFromDurationObject then
        local ok, durObj = pcall(C_UnitAuras.GetAuraDuration, unit, aid)
        if ok and durObj ~= nil then
            if pcall(cd.SetCooldownFromDurationObject, cd, durObj) then return end
        end
    end
    if cd.SetAuraFallbackData and data.expirationTime ~= nil and data.duration ~= nil then
        if pcall(cd.SetAuraFallbackData, cd, data.expirationTime, data.duration) then return end
    end
    local exp, dur = SafeNum(data.expirationTime, nil), SafeNum(data.duration, nil)
    if exp and dur and dur > 0 then cd:SetCooldown(exp - dur, dur)
    elseif cd.Clear then cd:Clear() end
end

local function AbbreviateTime(t)
    if t >= 3600 then return string.format("%.0fh", t / 3600) end
    if t >= 60   then return string.format("%.0fm", t / 60) end
    if t >= 10   then return string.format("%.0f", t) end
    if t >= 0    then return string.format("%.1f", t) end
    return ""
end

-- Actualiza el texto de duracion (SECRET-SAFE): el "duration object" tiene
-- EvaluateRemainingTime, que devuelve el restante como numero LEGIBLE aunque la
-- expiracion cruda sea secreta (Blizzard permite MOSTRARlo, no operar con el).
local function UpdateAuraButtonTime(b)
    if not b.dur then return end
    if not b._showDur then b.dur:SetText("") return end
    local remaining
    local obj = b._durObj
    if obj and obj.EvaluateRemainingTime then
        local ok, v = pcall(obj.EvaluateRemainingTime, obj)
        if ok and type(v) == "number" and not (issecretvalue and issecretvalue(v)) then remaining = v end
    end
    if remaining == nil and b._fbExp and b._fbDur and b._fbDur > 0 then
        remaining = b._fbExp - GetTime()
    end
    local text = (remaining and remaining > 0) and AbbreviateTime(remaining) or ""
    -- PERF (2026-07-19, "arregla todo"): AbbreviateTime ya redondea (ej "5"
    -- en vez de "4.87") -- entre dos ticks de 0.1s el texto formateado suele
    -- ser el MISMO string aunque `remaining` haya cambiado un poco. Saltea el
    -- SetText (rasterizado de fontstring) cuando el texto visible no cambio.
    if b.dur._mcfLastText ~= text then
        b.dur._mcfLastText = text
        b.dur:SetText(text)
    end
end

-- Overlay SEGURO para cancelar buffs con clic derecho. Va encima del icono,
-- anclado con SetAllPoints (sigue al boton sin reposicionarse), asi el layout
-- del grid (frame normal) sigue funcionando en combate. Solo el macrotext se
-- actualiza (fuera de combate). Crear frames seguros esta bloqueado en combate,
-- por eso se difiere via EnsureCancelOverlay en PLAYER_REGEN_ENABLED.
-- Host ESTATICO para los overlays seguros: nunca se mueve ni se oculta por el
-- layout, asi la jerarquia de los grupos de aura NO contiene frames seguros y
-- se puede reposicionar en combate sin taint.
local auraCancelHost

-- Posiciona el overlay SOBRE el boton con coordenadas ABSOLUTAS respecto a
-- UIParent, SIN anclarlo al boton. Anclarlo (SetPoint/SetAllPoints al boton)
-- crearia una dependencia de posicion: mover el grupo de ns.auras en combate
-- moveria el overlay (protegido) → taint. Como no hay ancla, g.root se mueve
-- libre en combate. Solo se llama FUERA de combate (mover un frame seguro en
-- combate esta bloqueado). Ajusta por diferencia de escala.
local function PositionCancelOverlay(c, b)
    local w, h = b:GetSize()
    local l, bottom = b:GetLeft(), b:GetBottom()
    if not (w and w > 0 and l and bottom) then return end
    local cs = c:GetEffectiveScale()
    if not (cs and cs > 0) then return end
    local k = b:GetEffectiveScale() / cs
    -- PERF (2026-07-19, "arregla todo"): esto corre 10x/seg (TickAuras) por
    -- cada overlay de cancelar visible -- SetSize/ClearAllPoints/SetPoint
    -- siempre, aunque el boton no se haya movido/redimensionado desde el
    -- ultimo tick (caso comun: nada se movio). Saltea el relayout si l/bottom/
    -- w/h/k son iguales a la ultima pasada.
    if c._mcfLastL == l and c._mcfLastBottom == bottom and c._mcfLastK == k
        and c._mcfLastW == w and c._mcfLastH == h then
        return
    end
    c._mcfLastL, c._mcfLastBottom, c._mcfLastK, c._mcfLastW, c._mcfLastH = l, bottom, k, w, h
    c:SetSize(w * k, h * k)
    c:ClearAllPoints()
    c:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * k, bottom * k)
end

local function EnsureCancelOverlay(b)
    if b.cancel or InCombatLockdown() then return end
    if not auraCancelHost then
        auraCancelHost = CreateFrame("Frame", "MyCF_AuraCancelHost", UIParent)
        auraCancelHost:SetFrameStrata("HIGH")
    end
    -- Parentado al host y SIN ancla al boton (ver PositionCancelOverlay).
    local c = CreateFrame("Button", nil, auraCancelHost, "SecureActionButtonTemplate")
    c:SetFrameStrata("HIGH")
    c:SetToplevel(true)
    c:SetFrameLevel(50)
    c:RegisterForClicks("RightButtonUp", "RightButtonDown")
    c:SetAttribute("type2", "macro")
    c:EnableMouse(true)
    -- Deja pasar el movimiento del raton al icono de abajo (para el tooltip/hover).
    if c.SetPropagateMouseMotion then c:SetPropagateMouseMotion(true) end
    c:Hide()
    b.cancel = c
end

local function CreateAuraButton(g)
    local b = CreateFrame("Frame", nil, g.root)
    b:SetSize(30, 30)
    b._group = g

    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints(b)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.icon = icon

    -- Swipe radial (secret-safe via SetCooldownFromDurationObject).
    local swipe = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    swipe:SetAllPoints(b)
    swipe:SetDrawEdge(false)
    if swipe.SetHideCountdownNumbers then swipe:SetHideCountdownNumbers(true) end
    swipe:SetFrameLevel(b:GetFrameLevel() + 1)
    swipe:EnableMouse(false)   -- no debe robar el clic del overlay de cancelar
    b.swipe = swipe

    -- Borde (encima del icono/swipe).
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture(ns.AURA_BORDER)
    b.border = border

    -- Los textos (duracion/contador) van en un frame POR ENCIMA del swipe (Cooldown = b+1)
    -- para que siempre queden DELANTE del swipe radial (antes quedaban detras).
    local textOverlay = CreateFrame("Frame", nil, b)
    textOverlay:SetAllPoints(b)
    textOverlay:SetFrameLevel(b:GetFrameLevel() + 2)
    b.textOverlay = textOverlay

    -- Texto de duracion: fontstring PROPIO (posicionable con offset GLOBAL del grupo).
    local dur = textOverlay:CreateFontString(nil, "OVERLAY")
    dur:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    dur:SetTextColor(1, 0.82, 0.2, 1)
    b.dur = dur

    -- Contador de acumulaciones.
    local count = textOverlay:CreateFontString(nil, "OVERLAY")
    count:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, 0)
    count:SetTextColor(1, 1, 1, 1)
    b.count = count

    -- Hover: sube la opacidad de ESA aura (grupos dualPos) + tooltip (secret-safe).
    b:SetScript("OnEnter", function(self)
        self._hover = true
        if self._group and self._group.dualPos then UpdateAuraAlpha(self._group) end
        if not (self._showTip and self._auraID and self._unit) then return end
        if GameTooltip:IsForbidden() or not self:IsVisible() then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local ok
        if GameTooltip.SetUnitAuraByAuraInstanceID then
            ok = pcall(GameTooltip.SetUnitAuraByAuraInstanceID, GameTooltip, self._unit, self._auraID)
        end
        if not ok then
            if self._filter == "HARMFUL" and GameTooltip.SetUnitDebuffByAuraInstanceID then
                ok = pcall(GameTooltip.SetUnitDebuffByAuraInstanceID, GameTooltip, self._unit, self._auraID)
            elseif GameTooltip.SetUnitBuffByAuraInstanceID then
                ok = pcall(GameTooltip.SetUnitBuffByAuraInstanceID, GameTooltip, self._unit, self._auraID)
            end
        end
        if ok then GameTooltip:Show() else GameTooltip:Hide() end
    end)
    b:SetScript("OnLeave", function(self)
        self._hover = false
        if self._group and self._group.dualPos then UpdateAuraAlpha(self._group) end
        if not GameTooltip:IsForbidden() then GameTooltip:Hide() end
    end)

    EnsureCancelOverlay(b)
    return b
end

local function StyleAuraButton(b, g, p, data, iconSize)
    b:SetSize(iconSize, iconSize)

    if p.showBorder then
        local inset = iconSize * (p.borderScale or 0.16)
        b.border:SetTexture((p.borderTexture and p.borderTexture ~= "" and p.borderTexture) or ns.AURA_BORDER)
        b.border:SetVertexColor(p.borderColor.r, p.borderColor.g, p.borderColor.b, p.borderAlpha or 1)
        b.border:ClearAllPoints()
        b.border:SetPoint("TOPLEFT", b, "TOPLEFT", -inset, inset)
        b.border:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", inset, -inset)
        b.border:Show()
    else
        b.border:Hide()
    end

    -- Color del texto (duracion + contador).
    local tc = p.textColor or { r = 1, g = 0.82, b = 0.2 }
    b.count:SetFont("Fonts\\FRIZQT__.TTF", p.countFontSize or 12, "OUTLINE")
    b.count:SetTextColor(tc.r, tc.g, tc.b, 1)

    -- Texto de duracion: fuente + color + posicion (centrado + offset GLOBAL del grupo).
    b.dur:SetFont("Fonts\\FRIZQT__.TTF", p.durationFontSize or 12, "OUTLINE")
    b.dur:SetTextColor(tc.r, tc.g, tc.b, 1)
    b.dur:ClearAllPoints()
    b.dur:SetPoint("CENTER", b, "CENTER", p.durationOffsetX or 0, p.durationOffsetY or 0)
    b._showDur = p.showDuration and true or false

    b.swipe:SetShown(p.showSwipe and true or false)

    -- Mouse fuera de preview si: tooltip activo, o hover-alpha (grupo dualPos con base <1).
    -- D: si este grupo PARTICIPA en el Explorer (y esta activo), se DESACTIVA su mouseover
    -- (tooltip/hover) para que revelar por mouseover no dispare tooltip. El clic-derecho de
    -- cancelar buff es un overlay seguro aparte (no afectado por este EnableMouse).
    b._showTip = p.showTooltip and true or false
    local inExplorer = ns.GetDB().explorerEnabled ~= false and ns.GetDB().explorer and ns.GetDB().explorer[g.key] and true or false
    local wantHover = (p.showTooltip or (g.dualPos and (p.groupAlpha or 1) < 1)) and not inExplorer
    b:EnableMouse((not ns.IsUnlocked()) and wantHover and true or false)
    b._unit, b._filter = g.unit, data.__filter

    -- Clic derecho para cancelar: SOLO buffs propios del player. No se tocan
    -- atributos/visibilidad de frames seguros en combate (queda el ultimo estado
    -- previo al combate; un buff nuevo en combate no sera cancelable hasta salir).
    if b.cancel and not InCombatLockdown() then
        -- SECRET-SAFE: el nombre (y el spellId) de un buff pueden ser SECRETOS en
        -- Midnight. NUNCA comparar el nombre salvo con nil o TRAS confirmar que no
        -- es secreto (comparar un secreto = taint/crash). Sin nombre legible no se
        -- puede construir "/cancelaura <nombre>", asi que esa aura no es cancelable.
        -- type() e issecretvalue() son seguros sobre secretos; NO comparar con nil
        -- ni con "" hasta CONFIRMAR que el valor no es secreto.
        local name = data and data.name
        local usable = false
        if type(name) == "string" and not (issecretvalue and issecretvalue(name)) then
            usable = (name ~= "")   -- seguro: name ya es legible
        end
        -- Fallback por spellId, solo si es legible.
        if not usable then
            local sid = data and data.spellId
            if type(sid) == "number" and not (issecretvalue and issecretvalue(sid)) and C_Spell and C_Spell.GetSpellName then
                local ok, sn = pcall(C_Spell.GetSpellName, sid)
                if ok and type(sn) == "string" and not (issecretvalue and issecretvalue(sn)) and sn ~= "" then
                    name = sn
                    usable = true
                end
            end
        end
        local canCancel = (not ns.IsUnlocked()) and (not data.__preview)
            and g.unit == "player" and data.__filter == "HELPFUL"
            and p.allowCancel and usable
        if canCancel then
            b.cancel:SetAttribute("macrotext2", "/cancelaura " .. name)
            PositionCancelOverlay(b.cancel, b)
            b.cancel:Show()
        else
            b.cancel:SetAttribute("macrotext2", "")
            b.cancel:Hide()
        end
    end

    -- Preview: icono de muestra + tiempo falso legible.
    if data.__preview then
        b._auraID = nil
        b.icon:SetTexture(ns.AURA_PREVIEW_ICON)
        b.count:SetText((data.__count and data.__count > 1) and tostring(data.__count) or "")
        b._durObj, b._fbExp, b._fbDur = nil, GetTime() + 12, 12
        if p.showSwipe then b.swipe:SetCooldown(GetTime() - 2, 14) end
        UpdateAuraButtonTime(b)
        return
    end

    b._auraID = data.auraInstanceID
    -- Icono: data.icon puede ser secreto — NUNCA testearlo con or/and (solo comparar
    -- con nil); SetTexture lo acepta en C. pcall directo, sin closure.
    local icon = data.icon
    if icon == nil then icon = 134400 end
    pcall(b.icon.SetTexture, b.icon, icon)

    local cnt = SafeNum(data.applications, 0)
    if p.showCount and cnt and cnt > 1 then b.count:SetText(cnt) else b.count:SetText("") end

    if p.showSwipe then ApplyAuraCooldown(b.swipe, g.unit, data)
    elseif b.swipe.Clear then b.swipe:Clear() end

    -- Guarda el duration object (o fallback legible) para el ticker del texto.
    b._durObj, b._fbExp, b._fbDur = nil, nil, nil
    if p.showDuration then
        local aid = data.auraInstanceID
        if aid ~= nil and C_UnitAuras and C_UnitAuras.GetAuraDuration then
            local ok, durObj = pcall(C_UnitAuras.GetAuraDuration, g.unit, aid)
            if ok then b._durObj = durObj end
        end
        b._fbExp = SafeNum(data.expirationTime, nil)
        b._fbDur = SafeNum(data.duration, nil)
    end
    UpdateAuraButtonTime(b)
end

-- Coloca el frame ancla del grupo. Los grupos dualPos (player) tienen 3 posiciones:
-- muerte (player muerto, prioridad), principal (condicion cumplida) y alterna (el resto).
-- En preview se usa editPos ("center"/"alt"/"dead").
local function AuraGroupPlace(g)
    local p = AP(g)
    ns.CompensateScale(p, "aura")   -- B3: reancla offsets si la escala cambio
    local anchor, point, relPoint, x, y = p.anchor, p.point, p.relPoint, p.offsetX, p.offsetY
    if g.dualPos then
        local which
        if ns.IsUnlocked() then
            which = p.editPos or "center"
        else
            local dead = ns.safeBool(UnitIsDeadOrGhost, "player")
            if p.useDeadPos and dead then
                which = UnitExists("target") and "deadTarget" or "dead"
            elseif AuraCondActive(p) then which = "center"
            else which = "alt" end
        end
        if which == "alt" then
            anchor, point, relPoint, x, y = p.altAnchor, p.altPoint, p.altRelPoint, p.altX, p.altY
        elseif which == "dead" then
            anchor, point, relPoint, x, y = p.deadAnchor, p.deadPoint, p.deadRelPoint, p.deadX, p.deadY
        elseif which == "deadTarget" then
            anchor, point, relPoint, x, y = p.deadTargetAnchor, p.deadTargetPoint, p.deadTargetRelPoint, p.deadTargetX, p.deadTargetY
        end
        -- Offset extra si hay pet: se SUMA a la posicion viva. Cada posicion tiene su PROPIO
        -- offset (center → petOffsetX/Y, alt → petOffsetXAlt/YAlt). Solo en vivo (en preview se
        -- editan las posiciones base). Se aplica ANTES del dedupe → si el pet aparece/desaparece,
        -- x/y cambian y AuraGroupPlace re-coloca solo. nil-safe (perfiles viejos).
        if not ns.IsUnlocked() and UnitExists("pet") then
            local pox, poy
            if which == "center" then
                pox, poy = p.petOffsetX or 0, p.petOffsetY or 0
            elseif which == "alt" then
                pox, poy = p.petOffsetXAlt or 0, p.petOffsetYAlt or 0
            end
            if pox and (pox ~= 0 or poy ~= 0) then
                x = x + pox
                y = y + poy
            end
        end
    end
    local parent = _G[anchor]
    if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
    local scale = p.scale or 1
    -- Dedupe: los grupos dualPos se re-colocaban cada tick con los mismos valores
    -- (ClearAllPoints+SetPoint+strata+escala). Firma = ultimo aplicado (datos propios).
    -- El OnDragStop invalida (_posParent=nil) porque StartMoving cambia el ancla real.
    if g._posParent == parent and g._posP == point and g._posRP == relPoint
       and g._posX == x and g._posY == y
       and g._posStrata == p.strata and g._posScale == scale then return end
    g.root:ClearAllPoints()
    g.root:SetPoint(point, parent, relPoint, x, y)
    g.root:SetFrameStrata(p.strata)
    g.root:SetScale(scale)   -- escala general del grupo de ns.auras
    g._posParent, g._posP, g._posRP, g._posX, g._posY, g._posStrata, g._posScale =
        parent, point, relPoint, x, y, p.strata, scale
end

-- Reconstruye el grid: "centrado horizontal, luego hacia abajo".
local function UpdateAuraGroup(g)
    local p = AP(g)
    AuraGroupPlace(g)

    if not (p.enabled or ns.IsUnlocked()) then
        g.root:Hide()
        for _, b in ipairs(g.buttons) do
            b:Hide()
            if b.cancel and not InCombatLockdown() then b.cancel:Hide() end
        end
        return
    end
    g.root:Show()
    if g.editBG then g.editBG:SetShown(ns.IsUnlocked() and not (ns.GetDB() and ns.GetDB().hideEditOutline)) end

    local list
    if ns.IsUnlocked() then
        list = {}
        local sample = math.min(math.max(p.limit or 8, 1), 10)
        for i = 1, sample do list[i] = { __preview = true, __count = (i % 3 == 0) and 3 or 1 } end
    else
        list = CollectAuras(g.unit)
        local cmp = AURA_SORTS[p.sort]
        if cmp then pcall(table.sort, list, cmp) end
    end

    local limit    = math.max(1, p.limit or 32)
    local n        = math.min(#list, limit)
    local perRow   = math.max(1, p.perRow or 8)
    local iconSize = math.max(4, p.iconSize or 30)
    local colSpace = p.colSpace or 4
    local rowSpace = p.rowSpace or 8

    for i = 1, n do
        local b = g.buttons[i]
        if not b then b = CreateAuraButton(g); g.buttons[i] = b end
        local idx = i - 1
        local row = math.floor(idx / perRow)
        local col = idx % perRow
        local itemsThisRow = math.min(perRow, n - row * perRow)
        local rowW = itemsThisRow * iconSize + (itemsThisRow - 1) * colSpace
        local startX = -rowW / 2 + iconSize / 2
        local x = startX + col * (iconSize + colSpace)
        local y = -row * (iconSize + rowSpace)
        b:ClearAllPoints()
        b:SetPoint("CENTER", g.root, "CENTER", x, y)
        StyleAuraButton(b, g, p, list[i], iconSize)
        b:Show()
    end
    for i = n + 1, #g.buttons do
        g.buttons[i]:Hide()
        local bc = g.buttons[i].cancel
        if bc and not InCombatLockdown() then bc:Hide() end
    end
    UpdateAuraAlpha(g)
end

local function RefreshAura(key)
    local g = ns.auras[key]
    if g then UpdateAuraGroup(g) end
end
ns.RefreshAura = RefreshAura

local function RefreshAllAuras()
    for _, g in pairs(ns.auras) do UpdateAuraGroup(g) end
end
ns.RefreshAllAuras = RefreshAllAuras

local function CreateAuraGroup(def)
    local g = { key = def.key, unit = def.unit, label = def.label, dualPos = def.dualPos, buttons = {} }

    local root = CreateFrame("Frame", "MyCF_Aura_" .. def.key, UIParent)
    root:SetSize(40, 40)
    root:SetPoint("CENTER")
    root:SetMovable(true)
    root:RegisterForDrag("LeftButton")
    root:EnableMouse(false)

    local editBG = ns.MakeEditHighlight(root, "Aura " .. (def.label or def.key))
    g.root, g.editBG = root, editBG

    root:SetScript("OnDragStart", function(self)
        if ns.IsUnlocked() and not InCombatLockdown() then self:StartMoving() end
    end)
    root:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if ns.SnapFrameToGrid then ns.SnapFrameToGrid(self) end
        local p = AP(g)
        local which = g.dualPos and (p.editPos or "center") or "center"
        local anchorName = (which == "alt" and p.altAnchor) or (which == "dead" and p.deadAnchor)
            or (which == "deadTarget" and p.deadTargetAnchor) or p.anchor
        local parent = _G[anchorName]
        if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
        local s, ps = self:GetEffectiveScale(), parent:GetEffectiveScale()
        local fx, fy = self:GetCenter()
        local px, py = parent:GetCenter()
        if fx and px then
            local ox = (fx * s - px * ps) / s
            local oy = (fy * s - py * ps) / s
            if which == "alt" then p.altPoint, p.altRelPoint, p.altX, p.altY = "CENTER", "CENTER", ox, oy
            elseif which == "dead" then p.deadPoint, p.deadRelPoint, p.deadX, p.deadY = "CENTER", "CENTER", ox, oy
            elseif which == "deadTarget" then p.deadTargetPoint, p.deadTargetRelPoint, p.deadTargetX, p.deadTargetY = "CENTER", "CENTER", ox, oy
            else p.point, p.relPoint, p.offsetX, p.offsetY = "CENTER", "CENTER", ox, oy end
        end
        g._posParent = nil   -- StartMoving cambio el ancla real: invalidar el dedupe
        AuraGroupPlace(g)
        if ns.OnDragStopped then ns.OnDragStopped(g.key) end
    end)

    ns.AttachScaleWheel(g.root, function() return ns.GetDB().auras[g.key] end, function() AuraGroupPlace(g) end)
    ns.auras[def.key] = g
    return g
end

for _, def in ipairs(ns.AURAS) do CreateAuraGroup(def) end
-- Expuestas para que core.lua (ticker principal, evento PLAYER_REGEN_ENABLED/
-- PLAYER_TARGET_CHANGED/UNIT_AURA) las invoque sin depender de locals de este archivo.
ns.AP = AP
ns.EnsureCancelOverlay = EnsureCancelOverlay
ns.UpdateAuraGroup = UpdateAuraGroup
ns.AuraGroupPlace = AuraGroupPlace
ns.UpdateAuraAlpha = UpdateAuraAlpha
ns.UpdateAuraButtonTime = UpdateAuraButtonTime
ns.PositionCancelOverlay = PositionCancelOverlay

-- Tick de auras (reposicion dualPos + opacidad + texto de duracion + overlay de cancelar),
-- llamado desde el ticker principal de core.
ns.TickAuras = function()
    local outOfCombat = not InCombatLockdown()
    for _, g in pairs(ns.auras) do
        if g.dualPos then AuraGroupPlace(g); UpdateAuraAlpha(g) end
        for _, b in ipairs(g.buttons) do
            if b:IsShown() then
                UpdateAuraButtonTime(b)
                if outOfCombat and b.cancel and b.cancel:IsShown() then
                    PositionCancelOverlay(b.cancel, b)
                end
            end
        end
    end
end
