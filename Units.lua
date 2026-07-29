-- ==========================================================================
-- MyCustomFrames - Units.lua
-- UNIDADES (barras de vida/poder/cast): definiciones de logica, textos, cage,
-- relleno secret-safe, cast bar, drivers pet/party. Extraido de core.lua
-- (el chunk principal excedia margen del limite de 200 locals de Lua); mismo
-- patron que Glow/ChatBubble/MicroMenu: usa ns.GetDB()/ns.IsUnlocked() en vez
-- de los locals db/unlocked de core, y expone via ns.* lo que el ticker
-- principal y el resto del addon necesitan llamar desde afuera.
-- Carga DESPUES de core.lua en el toc.
-- ==========================================================================
local ADDON, ns = ...
-- ==========================================================================
-- LOGICA POR UNIDAD
-- ==========================================================================
local function P(u) return ns.GetDB().units[u.key] end

local function UnitColor(u)
    local p = P(u)
    if p.useBarColor and p.barColor then
        return p.barColor.r, p.barColor.g, p.barColor.b
    end
    -- (Ruta caliente — se llama por unidad por tick via UnitUpdateColor: pcall directo
    -- sin closures; issecretvalue ANTES de testear/indexar con valores de la API.)
    if u.kind == "power" then
        local okP, pType, token = pcall(UnitPowerType, u.unit)
        if okP and not (issecretvalue and (issecretvalue(pType) or issecretvalue(token))) then
            local col = (token and ns.POWER_COLORS[token]) or (token and PowerBarColor[token])
                or (pType and PowerBarColor[pType])
            if col then return col.r, col.g, col.b end
        end
        return 0.18, 0.34, 0.98
    end
    if u.fixedColor then return u.fixedColor.r, u.fixedColor.g, u.fixedColor.b end
    -- Color de clase si la unidad tiene una clase valida (jugador o NPC con clase).
    do
        local okC, _, class = pcall(UnitClass, u.unit)
        if okC and type(class) == "string" and not (issecretvalue and issecretvalue(class)) then
            local c = RAID_CLASS_COLORS[class]
            if c then return c.r, c.g, c.b end
        end
    end
    local reaction = ns.safeVal(UnitReaction, u.unit, "player")
    local col = p.colorFriendly
    if type(reaction) == "number" then
        if reaction <= 3 then col = p.colorHostile
        elseif reaction == 4 then col = p.colorNeutral
        else col = p.colorFriendly end
    end
    return col.r, col.g, col.b
end

-- CENTRALIZADO (2026-07-19, "sigue con eso"): la logica real (curva,
-- pcall, etc) vive ahora en API.lua (ns.GetHealthPercentReadable) -- unico
-- lugar que sabe leer esta API, para no repetir el mismo bug potencial en
-- cada archivo que necesita el % de vida. Este local queda como alias fino
-- para no tocar los 3 call sites de abajo.
local function GetHealthPercent(unit)
    return ns.GetHealthPercentReadable(unit)
end

-- Color secreto del porcentaje de vida. Midnight no permite evaluar
-- `pct <= 40` cuando pct es secreto, pero UnitHealthPercent acepta una
-- ColorCurve y hace la evaluacion dentro del cliente. La curva devuelve rojo
-- por debajo del umbral y el color normal del texto por encima.
--
-- El resultado se usa unicamente para envolver el fragmento "100%" con
-- C_ColorUtil. El " | 105K" conserva el SetTextColor normal del FontString.
-- Si alguna API cambia o rechaza un secreto, devolvemos nil y el caller usa
-- exactamente el formato anterior; nunca se bloquea el texto de vida.
local function GetPercentLowHealthCurve(u, p, normalColor)
    if not (p.percentLowHealthColor and C_CurveUtil and C_CurveUtil.CreateColorCurve
        and C_ColorUtil and C_ColorUtil.WrapTextInColor and CreateColor
        and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step) then
        return nil
    end

    local threshold = ns.clamp(tonumber(p.percentLowHealthThreshold) or 40, 1, 99) / 100
    if u._mcfPctCurve
       and u._mcfPctCurveThreshold == threshold
       and u._mcfPctCurveR == normalColor.r
       and u._mcfPctCurveG == normalColor.g
       and u._mcfPctCurveB == normalColor.b then
        return u._mcfPctCurve
    end

    local ok, curve = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not curve then return nil end
    local red = CreateColor(1, 0.10, 0.10, 1)
    local normal = CreateColor(normalColor.r, normalColor.g, normalColor.b, 1)
    -- Step + un punto apenas despues del umbral: <= umbral rojo, por encima
    -- vuelve directamente al color configurado, sin degradado amarillo.
    ok = pcall(function()
        curve:SetType(Enum.LuaCurveType.Step)
        curve:AddPoint(0, red)
        curve:AddPoint(threshold, red)
        curve:AddPoint(threshold + 0.0001, normal)
        curve:AddPoint(1, normal)
    end)
    if not ok then return nil end

    u._mcfPctCurve = curve
    u._mcfPctCurveThreshold = threshold
    u._mcfPctCurveR, u._mcfPctCurveG, u._mcfPctCurveB = normalColor.r, normalColor.g, normalColor.b
    return curve
end

local function SetHealthTextWithPercentColor(u, p, hpText, pct, abbreviated, normalColor)
    local curve = GetPercentLowHealthCurve(u, p, normalColor)
    if not curve then return false end

    -- Se consulta de nuevo con la curva, no con ScaleTo100: las ColorCurve
    -- reciben el porcentaje interno 0..1. Tanto el color como el texto pueden
    -- ser secretos; las APIs C usadas abajo los aceptan sin inspeccionarlos.
    local okColor, secretColor = pcall(UnitHealthPercent, u.unit, true, curve)
    if not okColor then return false end
    local okPct, percentText = pcall(string.format, "%.0f%%", pct)
    if not okPct then return false end
    local okWrap, coloredPercent = pcall(C_ColorUtil.WrapTextInColor, percentText, secretColor)
    if not okWrap then return false end

    if abbreviated then
        return pcall(hpText.SetFormattedText, hpText, "%s | %s", coloredPercent, abbreviated)
    end
    return pcall(hpText.SetFormattedText, hpText, "%s", coloredPercent)
end

-- SetText solo si el texto CAMBIO (2026-07-28). Blizzard rehace el layout del
-- FontString en CADA SetText aunque el string sea identico, y estas rutas corren
-- 10 veces por segundo por unidad: medido, UnitUpdateBar era 6.51 ms/s, el 71%
-- de TickUnits y el mayor costo del addon entero.
--
-- SOLO para strings PROPIOS. Comparar un valor secreto de Midnight no es seguro,
-- asi que las rutas que pasan un secreto crudo a SetFormattedText NO usan esto
-- -- se quedan como estaban, actualizando siempre.
local function SetTextIfChanged(fs, s)
    if fs._mcfLastText == s then return end
    fs._mcfLastText = s
    fs:SetText(s)
end

-- Contraparte OBLIGATORIA: toda escritura que NO pase por SetTextIfChanged
-- (SetFormattedText, o un SetText con un valor posiblemente secreto) tiene que
-- marcar la cache como desconocida (2026-07-29).
--
-- El invariante de SetTextIfChanged es "_mcfLastText es lo que se ve". Escribir
-- por afuera lo rompe, y lo rompe en la direccion peligrosa -- hace que una
-- llamada POSTERIOR se saltee su escritura:
--
--   showText off  -> SetTextIfChanged(hp, "")    cache=""   pantalla=""
--   showText on   -> SetFormattedText "45%"      cache=""   pantalla="45%"  <- desfase
--   showText off  -> SetTextIfChanged(hp, "")    cache==""  -> NO escribe
--                                                pantalla se queda en "45%"
--
-- Se invalida ANTES de escribir, no despues: si el pcall del SetFormattedText
-- falla, "desconocido" sigue siendo la respuesta correcta y la proxima pasada
-- redibuja. Al reves (invalidar despues) un error se saltearia la invalidacion.
--
-- No cuesta rendimiento: la cache solo existe para saltear repeticiones del
-- MISMO string, y el texto de vida cambia en casi todos los ticks igual. Lo que
-- protege es el estado estable -- vacio, muerto, texto apagado -- que es donde
-- el dedupe rendia.
local function DirtyText(fs) fs._mcfLastText = nil end

local function UnitUpdateText(u)
    local p, hpText = P(u), u.hpText
    -- Cache del dedupe de la ruta legible: se LEE aca y se invalida de
    -- inmediato. Solo esa ruta la vuelve a armar, asi que si la pasada actual
    -- termina por cualquier otra rama (muerto, showText apagado, porcentaje
    -- secreto), la proxima pasada legible redibuja igual en vez de quedarse con
    -- el texto de la otra rama pegado. Correcto por construccion: no hay que
    -- acordarse de invalidar en cada salida.
    local lastPct, lastAbbr = u._hpLastPct, u._hpLastAbbr
    u._hpLastPct, u._hpLastAbbr = nil, nil
    if not p.showText then SetTextIfChanged(hpText, "") return end

    -- (Ruta caliente: pcall(fn, args) directo, SIN closures — ver nota sobre ns.safeBool.
    -- Toda comparacion/aritmetica sobre valores potencialmente secretos va precedida
    -- de issecretvalue, o dentro de un pcall.)
    if u.kind == "power" then
        -- Esta rama dibuja con SetFormattedText (formatea en C, obligatorio para
        -- valores secretos), que no puede pasar por SetTextIfChanged. Se marca la
        -- cache como desconocida UNA vez al entrar, en vez de en cada sitio de
        -- escritura -- asi no hay forma de olvidarse de uno.
        DirtyText(hpText)
        -- CENTRALIZADO (2026-07-19, "sigue con eso"): ns.GetPowerPercent
        -- (API.lua) es el unico lugar que sabe la firma real/curva de
        -- UnitPowerPercent -- ver el historial largo de ese bug ahi.
        if UnitPowerPercent then
            local okT, pType = pcall(UnitPowerType, u.unit)
            if okT then
                local pct = ns.GetPowerPercent(u.unit, pType)
                if pct ~= nil then
                    if pcall(hpText.SetFormattedText, hpText, "%.0f%%", pct) then return end
                end
            end
        end
        local okC, cur = pcall(UnitPower, u.unit)
        local okM, max = pcall(UnitPowerMax, u.unit)
        if okC and okM and type(cur) == "number" and type(max) == "number"
           and not (issecretvalue and (issecretvalue(cur) or issecretvalue(max)))
           and max > 0 then
            hpText:SetFormattedText("%.0f%%", cur / max * 100)
            return
        end
        SetTextIfChanged(hpText, "")
        return
    end

    local dead = ns.safeBool(UnitIsDeadOrGhost, u.unit)
    if dead then SetTextIfChanged(hpText, "") return end
    -- Idem la rama de poder: de aca para abajo se dibuja con SetFormattedText.
    -- Los dos estados estables que el dedupe protege ("texto apagado" y "muerto")
    -- retornan ARRIBA de este punto, asi que lo conservan intacto -- son los que
    -- corrian a 10 Hz sin cambiar nunca, que es donde rendia.
    DirtyText(hpText)

    if UnitHealthPercent then
        local okH, readablePct, readable = pcall(GetHealthPercent, u.unit)
        if not okH then readablePct, readable = nil, false end
        -- Color del texto: personalizado (useHealthColor) o ns.GOLD. Se re-evalua cada tick.
        local col = (p.useHealthColor and p.healthColor) or ns.GOLD
        -- Dedupe: SetTextColor solo si el color realmente cambio (numeros propios, no secretos).
        if col.r ~= u._hpR or col.g ~= u._hpG or col.b ~= u._hpB then
            u._hpR, u._hpG, u._hpB = col.r, col.g, col.b
            hpText:SetTextColor(col.r, col.g, col.b, 1)
        end
        if readable then
            local abbr
            if p.showValue and type(AbbreviateNumbers) == "function" then
                local okA, a = pcall(AbbreviateNumbers, UnitHealth(u.unit))
                if okA then abbr = a end
            end
            -- DEDUPE: lo que se muestra es funcion PURA del porcentaje redondeado
            -- (se formatea con "%.0f") y del valor abreviado. Si ninguno de los
            -- dos cambio, el SetFormattedText produciria el mismo string exacto
            -- -- y Blizzard rehace el layout del FontString igual. Medido: esta
            -- ruta era el 71% de TickUnits y el mayor costo del addon.
            --
            -- Solo se deduplica si `abbr` es comparable con seguridad. Si llega
            -- secreto se saltea el dedupe y se actualiza siempre, como antes:
            -- comparar un secreto de Midnight no es seguro.
            if (abbr == nil) or (type(abbr) == "string"
                                 and not (issecretvalue and issecretvalue(abbr))) then
                local rounded = math.floor(readablePct + 0.5)
                -- La cache se restaura TAMBIEN al saltear. Se invalida al entrar
                -- a la funcion (ver arriba), asi que si al skipear no se volviera
                -- a armar quedaria en nil y la pasada siguiente redibujaria por
                -- las dudas -- alternando skip/redibuja y perdiendo la mitad del
                -- ahorro. Lo detecto una prueba de la logica antes de subirlo.
                u._hpLastPct, u._hpLastAbbr = rounded, abbr
                if lastPct == rounded and lastAbbr == abbr then return end
            end
            if abbr ~= nil then
                if SetHealthTextWithPercentColor(u, p, hpText, readablePct, abbr, col) then return end
                if pcall(hpText.SetFormattedText, hpText, "%.0f%% | %s", readablePct, abbr) then return end
            end
            if SetHealthTextWithPercentColor(u, p, hpText, readablePct, nil, col) then return end
            hpText:SetFormattedText("%.0f%%", readablePct)
            return
        end
        -- pct secreto: mostrable via SetFormattedText (formatea en C), nunca operar con el.
        local okP, pct = pcall(GetHealthPercent, u.unit)
        if okP and pct ~= nil then
            if p.showValue and type(AbbreviateNumbers) == "function" then
                local okA, abbr = pcall(AbbreviateNumbers, UnitHealth(u.unit))
                if okA and abbr ~= nil then
                    if SetHealthTextWithPercentColor(u, p, hpText, pct, abbr, col) then return end
                    if pcall(hpText.SetFormattedText, hpText, "%.0f%% | %s", pct, abbr) then return end
                end
            end
            if SetHealthTextWithPercentColor(u, p, hpText, pct, nil, col) then return end
            if pcall(hpText.SetFormattedText, hpText, "%.0f%%", pct) then return end
        end
    end
    if type(AbbreviateNumbers) == "function" then
        local ok, formatted = pcall(AbbreviateNumbers, UnitHealth(u.unit))
        if ok and formatted ~= nil then hpText:SetText(formatted) return end
    end
    SetTextIfChanged(hpText, "")
end

-- Nombre (+nivel) y texto de hechizo (fontstrings independientes).
local function UnitUpdateName(u)
    if not u.nameText then return end
    local p = P(u)
    local nameFS, spellFS = u.nameText, u.spellText

    -- No mostrar (oculto / no existe / muerto).
    local hide = (not p.showName) or (not UnitExists(u.unit))
    if not hide then
        if ns.safeBool(UnitIsDeadOrGhost, u.unit) then hide = true end
    end
    if hide then
        -- Por el helper: este es el estado estable (nombre apagado / unidad
        -- muerta) y vaciar por afuera dejaba la cache con el nombre viejo, asi
        -- que al volver a mostrarse UnitUpdateName recalculaba ESE nombre, la
        -- comparacion daba igual y no reescribia nada -- el nombre no volvia.
        nameFS:SetAlpha(0); SetTextIfChanged(nameFS, "")
        if spellFS then spellFS:SetAlpha(0); SetTextIfChanged(spellFS, "") end
        return
    end

    -- Casteo? (pcall directo, sin closures; el nombre puede ser SECRETO: solo
    -- comparar con nil.)
    local okCast, castName = pcall(UnitCastingInfo, u.unit)
    if not okCast then castName = nil end
    if castName == nil then
        local okCh, chName = pcall(UnitChannelInfo, u.unit)
        if okCh then castName = chName end
    end

    if castName ~= nil and p.showSpell and spellFS then
        -- Hechizo reemplaza al nombre.
        nameFS:SetAlpha(0)
        -- Limite de caracteres SOLO si el nombre es legible (no secreto): comparar
        -- longitud/sub de un secreto tainta. Los secretos se pasan tal cual (SetText
        -- en C) y el wrap + max 2 lineas los recorta visualmente.
        local s = castName
        if type(s) == "string" and not (issecretvalue and issecretvalue(s))
           and p.spellMaxLength and p.spellMaxLength > 0 and #s > p.spellMaxLength then
            s = s:sub(1, p.spellMaxLength) .. ".."
        end
        -- SetFormattedText obligatorio (el nombre del hechizo puede ser secreto):
        -- no pasa por el helper, asi que la cache queda desconocida.
        DirtyText(spellFS)
        pcall(spellFS.SetFormattedText, spellFS, "%s", s)
        if u._sX ~= p.spellOffsetX or u._sY ~= p.spellOffsetY then
            u._sX, u._sY = p.spellOffsetX, p.spellOffsetY
            spellFS:ClearAllPoints()
            spellFS:SetPoint("CENTER", u.bar, "CENTER", p.spellOffsetX, p.spellOffsetY)
        end
        spellFS:SetAlpha(p.spellAlpha)
        return
    end
    if spellFS then spellFS:SetAlpha(0) end

    -- Nombre + nivel (pcall directo; issecretvalue ANTES de cualquier comparacion).
    local nameReadable, nameStr = false, nil
    local okN, rawName = pcall(UnitName, u.unit)
    if okN and type(rawName) == "string" and not (issecretvalue and issecretvalue(rawName)) then
        nameReadable, nameStr = true, rawName
    end
    local lvlReadable, lvl = false, nil
    local okL, rawLvl = pcall(UnitLevel, u.unit)
    if okL and type(rawLvl) == "number" and not (issecretvalue and issecretvalue(rawLvl)) then
        lvlReadable, lvl = true, rawLvl
    end
    if nameReadable then
        if p.nameMaxLength and p.nameMaxLength > 0 and #nameStr > p.nameMaxLength then
            nameStr = nameStr:sub(1, p.nameMaxLength) .. ".."
        end
        if lvlReadable and p.nameLevelColor then
            local col
            if lvl <= 0      then col = "|cFFFF0000"
            elseif lvl <= 20 then col = "|cFF00FF00"
            elseif lvl <= 40 then col = "|cFF00FFFF"
            elseif lvl <= 60 then col = "|cFFFFFF00"
            else col = "|cFFFFA500" end
            local lvlText = (lvl > 0) and tostring(lvl) or "??"
            SetTextIfChanged(nameFS, string.format("%s %s%s|r", nameStr, col, lvlText))
        elseif lvlReadable and lvl > 0 then
            SetTextIfChanged(nameFS, string.format("%s %d", nameStr, lvl))
        else
            SetTextIfChanged(nameFS, nameStr)
        end
    else
        -- Nombre SECRETO: pasarlo tal cual a SetFormattedText (formatea en C). rawName
        -- solo se usa si el pcall de UnitName tuvo exito (si fallo, seria el mensaje
        -- de error). Comparar el secreto solo con nil.
        --
        -- No hay dedupe posible aca (comparar un secreto no es seguro), asi que
        -- la cache queda desconocida: es la rama que corre en este cliente para
        -- casi todas las unidades.
        DirtyText(nameFS)
        local okF = false
        if okN and rawName ~= nil then
            if lvlReadable and lvl > 0 then
                okF = pcall(nameFS.SetFormattedText, nameFS, "%s  %d", rawName, lvl)
            end
            if not okF then pcall(nameFS.SetFormattedText, nameFS, "%s", rawName) end
        end
    end

    if u._nX ~= p.nameOffsetX or u._nY ~= p.nameOffsetY then
        u._nX, u._nY = p.nameOffsetX, p.nameOffsetY
        nameFS:ClearAllPoints()
        nameFS:SetPoint("CENTER", u.bar, "CENTER", p.nameOffsetX, p.nameOffsetY)
    end

    -- UnitCanAttack: UNA consulta por tick (antes se hacia dos veces: autoHide + ancho).
    local atk = ns.safeBool(UnitCanAttack, "player", u.unit)
    if not p.nameAutoHide then
        nameFS:SetAlpha(p.nameAlpha)
    else
        nameFS:SetAlpha((ns.tickState.inCombat or atk or u.isMouseOver) and p.nameAlpha or 0)
    end

    local w = p.nameDynamicWidth and (atk and 111 or 200) or 1000
    if u._nW ~= w then u._nW = w; nameFS:SetWidth(w) end
end

local function UnitTextVisibility(u)
    local p, hpText = P(u), u.hpText
    -- BUG FIX (2026-07-15): esta rama ignoraba "Hide text" (ns.GetDB().lockHide.text) por completo y
    -- SIEMPRE reponia el alpha visible — como el OnEnter/OnLeave de hover llaman esta funcion
    -- tambien en preview, pasar el mouse por encima del frame pisaba el toggle de vuelta a
    -- visible (por eso el toggle "parecia no hacer nada" persistente).
    if ns.IsUnlocked() then
        local lh = ns.GetDB() and ns.GetDB().lockHide
        hpText:SetAlpha((lh and lh.text) and 0 or p.textAlpha)
        return
    end
    if not p.showText then hpText:SetAlpha(0) return end
    if not p.textAutoHide then hpText:SetAlpha(p.textAlpha) return end
    -- Hostil: la unidad del PROPIO frame es atacable (target/boss/etc) O hay un TARGET
    -- hostil seleccionado en general (para que el frame del player tambien revele su texto
    -- cuando estas encarando un enemigo, no solo en combate real; antes solo miraba u.unit,
    -- que para el player mismo nunca es "atacable" -> el texto nunca se mostraba con hostiles).
    local hostile = ns.safeBool(UnitExists, u.unit) and ns.safeBool(UnitCanAttack, "player", u.unit)
    local hostileTarget = ns.safeBool(UnitExists, "target") and ns.safeBool(UnitCanAttack, "player", "target")
    -- Vida baja: usa la fraccion LEGIBLE del relleno (secret-safe).
    local frac = u.bar._readable and u.bar._target
    local lowHP = p.textLowHealthShow and frac and frac < ((p.textLowHealthThreshold or 60) / 100)
    hpText:SetAlpha((ns.tickState.inCombat or hostile or hostileTarget or u.isMouseOver or lowHP) and p.textAlpha or 0)
end

-- Relleno MANUAL, LEFT o RIGHT (unicas 2 direcciones soportadas: con casi todos
-- los valores de vida/poder secretos en Midnight 12.0.7 no hay fraccion legible
-- para calcular CENTER, asi que no tiene sentido ofrecerlo). Tecnica de
-- WeakAuras (SetTexCoord + SetVertexOffset en las 4 esquinas) para que el
-- recorte sea pixel-perfect, sin estirar/deformar el arte -> evita el quirk de
-- Blizzard donde StatusBar:SetReverseFill "desliza" texturas custom asimetricas.
-- REVERTIDO (2026-07-19, "algo se dañó"): la version con cache/dedupe de la
-- sesion de perf quedo como sospechosa numero 1 (esta funcion corre dentro
-- del mismo camino de TickUnits que dejo de actualizar texto/valores) -- se
-- vuelve a la version simple que SIEMPRE reaplica, sin intentar adivinar de
-- nuevo que optimizar aca hasta poder probarlo en vivo con calma.
local function RenderManualFill(tex, container, frac, reverse)
    frac = ns.clamp(frac or 0, 0, 1)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    tex:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    if frac <= 0 then tex:Hide() return end
    tex:Show()

    local W = container:GetWidth() or 0
    local startP, endP = 0, frac
    if reverse then startP, endP = 1 - frac, 1 end

    tex:SetTexCoord(startP, 0, startP, 1, endP, 0, endP, 1)
    tex:SetVertexOffset(UPPER_LEFT_VERTEX, startP * W, 0)
    tex:SetVertexOffset(LOWER_LEFT_VERTEX, startP * W, 0)
    tex:SetVertexOffset(UPPER_RIGHT_VERTEX, (endP - 1) * W, 0)
    tex:SetVertexOffset(LOWER_RIGHT_VERTEX, (endP - 1) * W, 0)
end

-- Fraccion 0..1 de la unidad + si es LEGIBLE (no secreta).
-- 1) % de la API. 2) geometria renderizada del StatusBar (frame anterior).
local function GetUnitFraction(u)
    -- (Ruta caliente: pcall directo sin closures; issecretvalue ANTES de comparar/operar.)
    if u.kind == "power" then
        local okC, cur = pcall(UnitPower, u.unit)
        local okM, max = pcall(UnitPowerMax, u.unit)
        if okC and okM and type(cur) == "number" and type(max) == "number"
           and not (issecretvalue and (issecretvalue(cur) or issecretvalue(max)))
           and max > 0 then
            return cur / max, true
        end
    else
        local pct, r = GetHealthPercent(u.unit)
        if r then return pct / 100, true end
    end
    -- Fallback: ancho renderizado del relleno nativo / ancho de la barra.
    local tex = u.bar:GetStatusBarTexture()
    if tex then
        local okF, fw = pcall(tex.GetWidth, tex)
        local okB, bw = pcall(u.bar.GetWidth, u.bar)
        if okF and okB and type(fw) == "number" and type(bw) == "number"
           and not (issecretvalue and (issecretvalue(fw) or issecretvalue(bw)))
           and bw > 0 then
            return ns.clamp(fw / bw, 0, 1), true
        end
    end
    return 0, false
end

-- `doText`: los dos textos (porcentaje y nombre) son el 68% del costo de esta
-- funcion -- medido: 2.73 + 1.34 de 5.99 ms/s -- y no necesitan los 10 Hz del
-- tick. TickUnits los pide en pasadas alternas (5 Hz); el resto de llamadores
-- (UnitApplyAppearance, cambios de config) no pasan nada y los hacen siempre.
--
-- 5 Hz y no menos a proposito: PLAYER_TARGET_CHANGED no refresca el nombre --
-- solo cast bar y retratos, ver core.lua -- asi que el nombre depende SOLO de
-- este tick. Bajarlo mas dejaria el nombre del target anterior a la vista al
-- cambiar de objetivo. Para bajarlo habria que refrescarlo por evento primero.
local function UnitUpdateBar(u, doText)
    local p = P(u)

    -- Preview (modo edicion): relleno lleno + textos de muestra.
    if ns.IsUnlocked() then
        u.bar:GetStatusBarTexture():SetAlpha(0)
        if p.texture and p.texture ~= "" then
            RenderManualFill(u.fillTex, u.bar, 1)
        else
            u.fillTex:Hide()
        end
        -- "Hide text" (ns.GetDB().lockHide.text, Editing > Hide in preview): oculta TODO el texto
        -- (nombre + hechizo + vida %/numero) SOLO en preview, sin importar el showName/showSpell
        -- de cada unidad. Reemplaza al viejo toggle "Health" (2026-07-15) que solo tapaba
        -- hpText y encima no persistia: UnitTextVisibility pisaba el alpha en cada hover del
        -- mouse (rama `ns.IsUnlocked()` vieja ignoraba lockHide por completo, ver fix mas abajo).
        local lh = ns.GetDB().lockHide or {}
        local hideText = lh.text
        -- OJO: los textos de muestra van por SetTextIfChanged, NO por SetText
        -- directo (2026-07-29, reportado: "al salir de mcf on el nombre del
        -- player dice player 60"). SetTextIfChanged cachea en fs._mcfLastText
        -- lo ULTIMO que escribio; escribir por afuera deja la cache mintiendo.
        --
        -- Al salir del preview, UnitUpdateName recalcula el nombre REAL, lo
        -- compara con la cache -- que todavia guardaba ese mismo nombre real de
        -- antes de entrar -- y se saltea el SetText. El texto de muestra se
        -- quedaba en pantalla hasta un /reload.
        --
        -- La regla es que _mcfLastText SIEMPRE tiene que ser lo que se ve. Todo
        -- lo que escriba sobre estas FontStrings pasa por el helper.
        if u.hpText then
            SetTextIfChanged(u.hpText, u.kind == "power" and "100%" or "100% | 1m")
            u.hpText:SetAlpha(hideText and 0 or p.textAlpha)
        end
        if u.nameText then
            SetTextIfChanged(u.nameText, u.label .. " 60")
            u.nameText:SetAlpha(hideText and 0 or ((p.showName and p.nameAlpha) or 0))
            u.nameText:ClearAllPoints()
            u.nameText:SetPoint("CENTER", u.bar, "CENTER", p.nameOffsetX, p.nameOffsetY)
            u.nameText:SetWidth(p.nameDynamicWidth and 200 or 1000)
            u._nX, u._nW = nil, nil   -- el preview anclo por su cuenta: invalidar dedupe
        end
        if u.spellText then
            SetTextIfChanged(u.spellText, "Hechizo")
            u.spellText:SetAlpha(hideText and 0 or (p.showSpell and p.spellAlpha or 0))
            u.spellText:ClearAllPoints()
            u.spellText:SetPoint("CENTER", u.bar, "CENTER", p.spellOffsetX, p.spellOffsetY)
            u._sX = nil               -- idem
        end
        return
    end

    -- Rellena el StatusBar nativo SIEMPRE (secret-safe y para leer geometria).
    ns.Prof.Time("        - SetValue(vida/poder)", function()
    -- SetReverseFill y SetMinMaxValues se repetian en cada tick con los MISMOS
    -- valores: el maximo de vida/poder casi nunca cambia (subir de nivel, buffs
    -- de vida). SetValue si tiene que correr siempre -- es el valor actual.
    if u.bar._revApplied ~= false then
        u.bar._revApplied = false
        u.bar:SetReverseFill(false)
    end
    local maxFn = (u.kind == "power") and UnitPowerMax or UnitHealthMax
    local curFn = (u.kind == "power") and UnitPower or UnitHealth
    local max = maxFn(u.unit)
    -- Solo se deduplica si el maximo es un numero PROPIO. Si viene secreto no se
    -- puede comparar (rompe), asi que se aplica siempre, como antes.
    if type(max) == "number" and not (issecretvalue and issecretvalue(max)) then
        if u.bar._maxApplied ~= max then
            u.bar._maxApplied = max
            u.bar:SetMinMaxValues(0, max)
        end
    else
        u.bar._maxApplied = nil
        u.bar:SetMinMaxValues(0, max)
    end
    u.bar:SetValue(curFn(u.unit))
    end)

    if not (p.texture and p.texture ~= "") then
        -- Sin textura (focus): sin relleno.
        u.fillTex:Hide()
        u.bar:GetStatusBarTexture():SetAlpha(0)
        u.bar._readable = false
    else
        local frac, readable = ns.Prof.Time("        - GetUnitFraction", GetUnitFraction, u)
        if readable then
            -- Relleno MANUAL (no desliza, orientaciones correctas, permite smooth).
            u.bar:GetStatusBarTexture():SetAlpha(0)
            u.bar._readable = true
            u.bar._target = frac
            if u.bar._cur == nil or not p.smooth then u.bar._cur = frac end
            -- reverseFill: (1) archivo YA espejado (MirrorTexPath) para que el arte
            -- se vea coherente, (2) ANCLAR el recorte al lado derecho para que se
            -- vacie de izquierda a derecha (si no, solo cambia el arte pero sigue
            -- creciendo/vaciandose igual que LEFT).
            ns.Prof.Time("        - RenderManualFill", RenderManualFill, u.fillTex, u.bar, u.bar._cur, p.reverseFill)
        else
            -- Secreto e ilegible: StatusBar nativo (unico camino posible). Mismo
            -- combo: archivo espejado + SetReverseFill(true) (anclar a la derecha).
            u.bar._readable = false
            u.fillTex:Hide()
            u.bar:GetStatusBarTexture():SetAlpha(1)
            u.bar:SetReverseFill(p.reverseFill and true or false)
        end
    end
    if doText ~= false then
        ns.Prof.Time("        - UnitUpdateText", UnitUpdateText, u)
        ns.Prof.Time("        - UnitUpdateName", UnitUpdateName, u)
    end
end

local function UnitUpdateMount(u)
    if ns.IsUnlocked() then u.button:SetAlpha(1) return end
    -- Si el Explorer gestiona este elemento, el alpha es suyo (fade por frame):
    -- resetearlo a 1 aqui cada tick produce un parpadeo visible.
    if ns.GetDB().explorerEnabled ~= false and ns.GetDB().explorer and ns.GetDB().explorer[u.key] then return end
    u.button:SetAlpha(1)
end

-- Oculta el cage del unitframe si la unidad esta muerta (opcion cageHideDead).
local function UnitUpdateDeadCage(u)
    if not u.cage then return end
    local p = P(u)
    if not (p.cageHideDead and p.cageTexture and p.cageTexture ~= "") then return end
    local dead = ns.safeBool(UnitExists, u.unit) and ns.safeBool(UnitIsDeadOrGhost, u.unit)
    u.cage:SetShown(not dead)
end

-- Highlight de "unidad seleccionada": muestra el borde-highlight si la unidad de este
-- frame es tu TARGET actual. En preview (ns.IsUnlocked()) siempre visible para poder editarlo.
-- UnitIsUnit devuelve booleano (no secreto) -> seguro. Latido opcional (highlightGlow).
local function UnitUpdateHighlight(u)
    local hl = u.highlight
    if not hl then return end
    local p = P(u)
    if not p.showHighlight then
        hl:Hide()
        if u.highlightAnim then u.highlightAnim:Stop() end
        return
    end
    local isTarget
    if ns.IsUnlocked() then
        isTarget = true
    else
        isTarget = ns.safeBool(UnitExists, "target") and ns.safeBool(UnitIsUnit, u.unit, "target")
    end
    if isTarget then
        hl:Show()
        if p.highlightGlow and u.highlightAnim then
            if not u.highlightAnim:IsPlaying() then u.highlightAnim:Play() end
        elseif u.highlightAnim then
            u.highlightAnim:Stop()
            hl:SetAlpha(p.highlightAlpha or 1)
        end
    else
        hl:Hide()
        if u.highlightAnim then u.highlightAnim:Stop() end
    end
end

-- Pedido del usuario (2026-07-24, "que siempre aparezcan si existen y en el
-- explorer que esten -- que desaparezcan junto a su unitframe"): playerpower/
-- targetpower ya NO tienen condicion propia (combate/reaccion del target/
-- vivo-o-muerto) -- ahora siguen la MISMA regla generica que cualquier otra
-- power bar (mostrar si la unidad existe). Quien quiera ocultarlas segun
-- contexto ahora usa el Explorer (agrupadas junto a "Player"/"Target" en
-- EXPLORER_LIST, Options.lua -- se ocultan/reaparecen JUNTO a su unitframe).
-- EXCEPCION (2026-07-24, "el power target solo no salga si el objetivo esta
-- muerto" / "el power bar del player tambien desaparezca si estoy muerto"):
-- playerpower/targetpower conservan SOLO este chequeo -- una unidad muerta
-- no tiene power real que mostrar.
local function PowerShouldShow(u)
    if u.key == "targetpower" and ns.safeBool(UnitIsDeadOrGhost, "target") then return false end
    if u.key == "playerpower" and ns.safeBool(UnitIsDeadOrGhost, "player") then return false end
    return UnitExists(u.unit)
end

-- (Re)aplica el color de la barra (clase/reaccion/poder/override manual). Se llama
-- tambien en el ticker: el color de clase de party llega DESPUES de crear el frame,
-- asi que si solo se aplicara en el refresh completo, el color quedaria desactualizado.
local function UnitUpdateColor(u)
    local p = P(u)
    local hasTex = (p.texture and p.texture ~= "") and true or false
    local r, g, b = UnitColor(u)
    u.bar:SetStatusBarColor(r, g, b, hasTex and p.barAlpha or 0)
    u.fillTex:SetVertexColor(r, g, b, hasTex and p.barAlpha or 0)
end

local function UnitApplyLayout(u)
    local p = P(u)
    if u.kind ~= "power" and InCombatLockdown() then u.needsLayout = true return end
    ns.CompensateScale(p, "unit")   -- B3: reancla offsets si la escala cambio (sin desplazar)
    local button = u.button
    button:SetSize(p.width, p.height)
    local parent = _G[p.anchorFrame]
    if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
    button:ClearAllPoints()
    local rs = ns.ResScale()
    button:SetPoint(p.point, parent, p.relativePoint, p.offsetX, p.offsetY)
    button:SetFrameStrata(p.strata)
    button:SetScale((p.scale or 1) * rs)   -- escala general (multiplica sobre width/height, NO los altera)
    -- Area de CLICK independiente de la barra via SetHitRectInsets: no cambia la
    -- geometria del frame seguro (sin taint) y admite insets negativos (agrandar).
    -- En preview se limpia para poder arrastrar sobre todo el recuadro.
    if u.kind ~= "power" then
        local bw = (p.btnWidth and p.btnWidth > 0) and p.btnWidth or p.width
        local bh = (p.btnHeight and p.btnHeight > 0) and p.btnHeight or p.height
        local ox, oy = p.btnOffsetX or 0, p.btnOffsetY or 0
        if ns.IsUnlocked() or (bw == p.width and bh == p.height and ox == 0 and oy == 0) then
            button:SetHitRectInsets(0, 0, 0, 0)
        else
            local ix, iy = (p.width - bw) / 2, (p.height - bh) / 2
            button:SetHitRectInsets(ix + ox, ix - ox, iy - oy, iy + oy)
        end
        -- B4: preview del area de click (naranja), solo en preview y con el toggle activo.
        if u.hitPreview then
            local show = ns.IsUnlocked() and ns.GetDB() and ns.GetDB().previewSecureButton
            if show then
                u.hitPreview:ClearAllPoints()
                u.hitPreview:SetPoint("CENTER", button, "CENTER", ox, oy)
                u.hitPreview:SetSize(math.max(bw, 4), math.max(bh, 4))
            end
            u.hitPreview:SetShown(show and true or false)
        end
        -- B4: outline con tamaño propio + ocultar nombre (por unidad o por lockHide.names).
        ns.ApplyOutline(u.editBG, button, p.outlineW, p.outlineH,
            p.outlineHideName or (ns.GetDB().lockHide and ns.GetDB().lockHide.names))
    end
    u.needsLayout = nil
end

-- Con reverseFill activo, el StatusBar nativo (unico camino con vida secreta)
-- no puede recortar la textura sin distorsionarla si el arte es asimetrico
-- (ver conversacion). La solucion real es usar el archivo YA pre-espejado
-- ("nombre mirror.tga" <-> "nombre.tga") en vez de intentar espejar en runtime.
local function MirrorTexPath(path)
    if not path or path == "" then return path end
    local base, ext = path:match("^(.-)%s+[Mm][Ii][Rr][Rr][Oo][Rr]%.(%a+)$")
    if base then return base .. "." .. ext end
    base, ext = path:match("^(.-)%.(%a+)$")
    if base then return base .. " mirror." .. ext end
    return path
end

local function UnitApplyAppearance(u)
    local p = P(u)
    local hasTex = (p.texture and p.texture ~= "") and true or false
    local barTex = hasTex and p.texture or ns.BLANK_TEXTURE
    if hasTex and p.reverseFill then
        barTex = MirrorTexPath(p.texture)
    end
    -- Texturas (StatusBar nativo = fallback secreto; fillTex = relleno manual legible).
    u.bar:SetStatusBarTexture(barTex)
    u.fillTex:SetTexture(barTex)
    UnitUpdateColor(u)

    u.bg:SetColorTexture(0, 0, 0, p.bgAlpha)
    u.bg:SetShown(p.showBackground)

    if u.cage then
        if p.cageTexture and p.cageTexture ~= "" then
            u.cage:SetTexture(p.cageTexture)
            u.cage:SetSize(p.cageWidth, p.cageHeight)
            u.cage:ClearAllPoints()
            u.cage:SetPoint("CENTER", u.button, "CENTER", p.cageOffsetX, p.cageOffsetY)
            u.cage:SetAlpha(p.cageAlpha)
            u.cage:Show()
        else
            u.cage:Hide()
        end
    end

    -- Texto vida (fuente + color).
    u.hpText:SetFont("Fonts\\FRIZQT__.TTF", p.fontSize, "OUTLINE")
    local hc = p.useHealthColor and p.healthColor or ns.GOLD
    u.hpText:SetTextColor(hc.r, hc.g, hc.b, 1)
    u._hpR, u._hpG, u._hpB = hc.r, hc.g, hc.b   -- sincronizar la cache del dedupe del ticker
    u.hpText:ClearAllPoints()
    u.hpText:SetPoint("CENTER", u.bar, "CENTER", p.textOffsetX, p.textOffsetY)

    if u.nameText then
        u.nameText:SetFont("Fonts\\FRIZQT__.TTF", p.nameFontSize, "OUTLINE")
        u.nameText:SetScale(p.nameScale)
        local nc = p.useNameColor and p.nameColor or ns.GOLD
        u.nameText:SetTextColor(nc.r, nc.g, nc.b, 1)
    end
    if u.spellText then
        u.spellText:SetFont("Fonts\\FRIZQT__.TTF", p.spellFontSize, "OUTLINE")
        u.spellText:SetScale(p.spellScale)
        local sc = p.useSpellColor and p.spellColor or ns.GOLD
        u.spellText:SetTextColor(sc.r, sc.g, sc.b, 1)
        -- Nombre de hechizo largo: envolver a 2 lineas centradas. El ANCHO de
        -- envoltura (spellWrapWidth) controla donde parte: mas estrecho => se apila.
        u.spellText:SetWordWrap(true)
        if u.spellText.SetMaxLines then pcall(u.spellText.SetMaxLines, u.spellText, 2) end
        u.spellText:SetWidth(math.max(p.spellWrapWidth or 130, 30))
    end

    -- Cast bar (StatusBar): textura/color propios, centrado. El spark se ancla al
    -- borde del relleno para seguirlo sin leer el valor (que puede ser secreto).
    if u.castBar then
        local ct = (p.castTexture ~= "" and p.castTexture) or ns.BLANK_TEXTURE
        u.castBar:SetStatusBarTexture(ct)
        local cc = p.castColor
        u.castBar:SetStatusBarColor(cc.r, cc.g, cc.b, 1)
        u.castBar:SetReverseFill(p.castReverse and true or false)
        u.castBar:ClearAllPoints()
        u.castBar:SetPoint("CENTER", u.button, "CENTER", 0, 0)
        u.castBar:SetSize(p.castWidth, p.castHeight)
        if u.castSpark then
            u.castSpark:SetSize((p.castSparkWidth or 14) * (p.castSparkScale or 1), (p.castSparkHeight or 28) * (p.castSparkScale or 1))
            u.castSpark:ClearAllPoints()
            local tex = u.castBar:GetStatusBarTexture()
            -- Anclamos el BORDE del spark al frente del relleno (no su centro), asi
            -- no sobresale por fuera de la barra cuando el casteo llega al 100%.
            if p.castReverse then u.castSpark:SetPoint("LEFT", tex, "LEFT", 0, 0)
            else u.castSpark:SetPoint("RIGHT", tex, "RIGHT", 0, 0) end
        end
    end

    -- Highlight de "unidad seleccionada": textura/tamaño/escala/offset/color/opacidad.
    if u.highlight then
        local hw = (p.highlightWidth or 250) * (p.highlightScale or 1)
        local hh = (p.highlightHeight or 20) * (p.highlightScale or 1)
        u.highlight:SetTexture((p.highlightTexture and p.highlightTexture ~= "" and p.highlightTexture) or ns.HIGHLIGHT_TEX)
        u.highlight:SetSize(hw, hh)
        u.highlight:ClearAllPoints()
        u.highlight:SetPoint("CENTER", u.button, "CENTER", p.highlightOffsetX or 0, p.highlightOffsetY or 0)
        local hc = p.highlightColor or { r = 1, g = 1, b = 1 }
        u.highlight:SetVertexColor(hc.r, hc.g, hc.b)
        u.highlight:SetAlpha(p.highlightAlpha or 1)
    end

    UnitUpdateBar(u)
    UnitTextVisibility(u)
    UnitUpdateMount(u)
    UnitUpdateHighlight(u)

    -- Trinket de arena (solo arena_enemy1/2/3, ver CreateUnit) -- reaplica
    -- show/tamaño/offset EN VIVO al tocar el menu.
    if u.trinketReassert then u.trinketReassert() end
end

local function RefreshUnit(key)
    local u = ns.frames[key]
    if not u then return end
    UnitApplyLayout(u)
    UnitApplyAppearance(u)
end
ns.RefreshUnit = RefreshUnit

-- ==========================================================================
-- CAST BAR
-- ==========================================================================
local function SetSparkTexture(spark)
    local ok = false
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("Legionfall_BarSpark") then
        ok = pcall(function() spark:SetAtlas("Legionfall_BarSpark") end)
    end
    if not ok then
        spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    end
end

local function GetCastProgress(unit)
    local casting, prog = false, 0
    pcall(function()
        local name, _, _, startMS, endMS = UnitCastingInfo(unit)
        local channel = false
        if name == nil then
            name, _, _, startMS, endMS = UnitChannelInfo(unit)
            channel = true
        end
        if name ~= nil and type(startMS) == "number" and type(endMS) == "number" then
            local dur = endMS - startMS
            if dur > 0 then
                local p = (GetTime() * 1000 - startMS) / dur
                if channel then p = 1 - p end
                if p < 0 then p = 0 elseif p > 1 then p = 1 end
                casting, prog = true, p
            end
        end
    end)
    return casting, prog
end

-- Direcciones del timer de StatusBar (API C, 12.0). ElapsedTime = se llena (casteo);
-- RemainingTime = se vacia (canalizacion).
local CAST_DIR_ELAPSED, CAST_DIR_REMAINING
if Enum and Enum.StatusBarTimerDirection then
    CAST_DIR_ELAPSED   = Enum.StatusBarTimerDirection.ElapsedTime
    CAST_DIR_REMAINING = Enum.StatusBarTimerDirection.RemainingTime
end

-- Metodo de suavizado del timer (numero: Enum.StatusBarInterpolation, NO booleano).
local CAST_SMOOTH_ON, CAST_SMOOTH_OFF
if Enum and Enum.StatusBarInterpolation then
    CAST_SMOOTH_OFF = Enum.StatusBarInterpolation.Immediate
    CAST_SMOOTH_ON  = Enum.StatusBarInterpolation.Linear
        or Enum.StatusBarInterpolation.ExponentialEaseOut or CAST_SMOOTH_OFF
end

-- Modo de casteo actual, SECRET-SAFE: "cast" / "channel" / nil. Solo compara con nil
-- (permitido); NO usa el nombre/castID (secretos en enemigos), evitando el taint.
local function ReadCastMode(unit)
    -- (RUTA MUY CALIENTE: corre por FRAME por cada cast bar via CastOnUpdate — la
    -- version con closure alocaba ~1 closure/frame/unidad.) Comparar solo con nil.
    local ok, v = pcall(UnitCastingInfo, unit)
    if ok and v ~= nil then return "cast" end
    local ok2, v2 = pcall(UnitChannelInfo, unit)
    if ok2 and v2 ~= nil then return "channel" end
    return nil
end

-- OnUpdate del cast bar (StatusBar). Los tiempos de casteo son SECRETOS para enemigos
-- (Midnight): por eso NO se calcula el progreso en Lua ni se compara ningun id secreto.
-- Se detecta "cast nuevo" por el cambio de MODO (legible) y se rellena con
-- StatusBar:SetTimerDuration (en C, con el duration object absoluto). Fallback manual
-- solo para tiempos legibles (p.ej. el player).
local function CastOnUpdate(self, elapsed)
    local u = self._u
    if not ns.GetDB() then return end
    local p = P(u)

    -- Preview: barra estatica ~60%.
    if ns.IsUnlocked() then
        self:SetAlpha(p.castAlpha)
        -- SINCRONIZAR las caches del dedupe con lo que el preview acaba de
        -- aplicar (2026-07-29, reportado: "se ve las castbar estaticas" al
        -- salir del modo edicion).
        --
        -- Sin esto: estando ocioso _idleApplied quedaba en true, el preview
        -- pintaba la barra al 60% igual, y al salir la rama de ocioso de abajo
        -- veia _idleApplied == true, daba por hecho que ya estaba apagada y no
        -- hacia nada. La barra de muestra se quedaba fija hasta un /reload.
        --
        -- Los dos valores son literalmente ciertos ahora: NO estamos en estado
        -- ocioso aplicado, y el ultimo alpha escrito ES castAlpha.
        self._idleApplied = false
        self._alphaApplied = p.castAlpha
        self._castMode, self._timerActive = nil, false
        self:SetMinMaxValues(0, 1); self:SetValue(0.6)
        if u.castSpark then u.castSpark:Show() end
        return
    end

    -- PERF (2026-07-19, "arregla todo"): ReadCastMode hace 2 pcall+API por
    -- FRAME por cada cast bar, incluso el 99% del tiempo en que nadie esta
    -- casteando. Throttle el POLLEO a ~20/seg (50ms, imperceptible para el
    -- inicio/fin de un cast) -- el relleno de progreso de abajo sigue
    -- corriendo todos los frames para que la barra se vea fluida mientras
    -- SI esta casteando.
    self._castPollAcc = (self._castPollAcc or 0) + (elapsed or 0)
    local mode
    if self._castPollAcc >= 0.05 then
        self._castPollAcc = 0
        mode = ReadCastMode(u.unit)
        self._lastPolledMode = mode
    else
        mode = self._lastPolledMode
    end
    if mode == nil then
        -- Solo en la TRANSICION a ocioso. Antes esto se repetia POR FRAME sobre
        -- una barra que ya estaba en alpha 0 con el spark oculto: entre todas las
        -- barras eran 580 llamadas/s, y el 99% del tiempo nadie castea.
        if self._idleApplied ~= true then
            self._idleApplied = true
            self:SetAlpha(0)
            -- INVALIDAR la cache del alpha de casteo: esta rama acaba de poner el
            -- alpha en 0, asi que lo "ultimo aplicado" ya no es castAlpha. Sin
            -- esto, el siguiente cast comparaba _alphaApplied == p.castAlpha, se
            -- salteaba el SetAlpha y la barra quedaba invisible para siempre --
            -- el cast bar del player desaparecia tras el primer casteo.
            self._alphaApplied = nil
            if u.castSpark then u.castSpark:Hide() end
        end
        self._castMode, self._timerActive = nil, false
        return
    end
    self._idleApplied = false

    -- Mismo criterio: el alpha de casteo solo se re-aplica si cambio el perfil.
    if self._alphaApplied ~= p.castAlpha then
        self._alphaApplied = p.castAlpha
        self:SetAlpha(p.castAlpha)
    end
    -- Nuevo cast (cambio de modo o venia de nada): (re)inicia el timer una sola vez.
    if mode ~= self._castMode then
        self._castMode = mode
        self._timerActive = false
        local dur, dir
        if mode == "channel" then
            if UnitChannelDuration then
                local okD, d = pcall(UnitChannelDuration, u.unit)
                if okD then dur = d end
            end
            dir = CAST_DIR_REMAINING
        else
            if UnitCastingDuration then
                local okD, d = pcall(UnitCastingDuration, u.unit)
                if okD then dur = d end
            end
            dir = CAST_DIR_ELAPSED
        end
        if dur ~= nil and dir ~= nil and self.SetTimerDuration then
            local smoothing = p.castSmooth and CAST_SMOOTH_ON or CAST_SMOOTH_OFF
            self._timerActive = pcall(self.SetTimerDuration, self, dur, smoothing, dir)
        end
        if not self._timerActive then self:SetMinMaxValues(0, 1) end
        if u.castSpark then u.castSpark:Show() end
    end

    -- Sin timer en C (tiempos legibles): rellenar manualmente por progreso.
    -- (Por frame mientras castea: pcall directo; issecretvalue antes de testear.)
    if not self._timerActive then
        local okG, c2, pr = pcall(GetCastProgress, u.unit)
        local prog = 0
        if okG and not (issecretvalue and (issecretvalue(c2) or issecretvalue(pr))) and c2 then
            prog = pr
        end
        self:SetValue(prog)
    end
end

-- Fuerza re-deteccion del cast (al cambiar de target/focus/pet el frame reapunta a
-- otra unidad; sin esto seguiria mostrando el timer del casteo anterior).
local function ResetCastBar(key)
    local u = ns.frames[key]
    if u and u.castBar then
        u.castBar._castMode, u.castBar._timerActive = nil, false
        -- Fuerza un poll fresco YA en vez de esperar hasta 50ms al cache del
        -- throttle de ReadCastMode (ver CastOnUpdate) -- evita mostrar el
        -- estado de casteo de la unidad ANTERIOR un instante tras el cambio.
        u.castBar._castPollAcc, u.castBar._lastPolledMode = nil, nil
    end
end
ns.ResetCastBar = ResetCastBar

-- Smooth del hp/power bar (relleno manual; solo si el valor es legible).
local function BarOnUpdate(self, elapsed)
    if not self._readable then return end
    local u = self._u
    if not u then return end
    local p = P(u)
    if not p.smooth then return end
    local t = self._target or 0
    local cur = self._cur or t
    cur = cur + (t - cur) * math.min((elapsed or 0) * 10, 1)
    if math.abs(t - cur) < 0.001 then cur = t end
    self._cur = cur
    RenderManualFill(u.fillTex, self, cur, p.reverseFill)
end

-- ==========================================================================
-- CREACION DE FRAMES
-- ==========================================================================
local function CreateUnit(def)
    local u = {
        key = def.key, unit = def.unit, label = def.label,
        driver = def.driver, kind = def.kind or "health",
        fixedColor = def.fixedColor, isMouseOver = false,
    }
    local isPower = (u.kind == "power")

    local button
    if isPower then
        button = CreateFrame("Frame", "MyCF_" .. def.key, UIParent)
        button:EnableMouse(false)
    else
        button = CreateFrame("Button", "MyCF_" .. def.key, UIParent, "SecureUnitButtonTemplate")
        button._mcfOwnButton = true   -- sin WrapScript: el mouselook puede secuestrar su RMB-drag
        button:RegisterForClicks("AnyUp")
        button:SetAttribute("unit", def.unit)
        button:SetAttribute("*type1", "target")
        button:SetAttribute("*type2", "togglemenu")
    end
    button:SetSize(250, 20)
    button:SetPoint("CENTER")
    button:SetMovable(true)
    button:RegisterForDrag("LeftButton")

    local bg = button:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetAllPoints(button)
    bg:SetColorTexture(0, 0, 0, 0.5)

    local editBG = ns.MakeEditHighlight(button, def.label or def.key)
    if not isPower then u.hitPreview = ns.MakeHitPreview(button) end   -- B4: preview del area de click

    local cage = button:CreateTexture(nil, "ARTWORK")
    cage:Hide()

    local bar = CreateFrame("StatusBar", nil, button)
    bar:SetAllPoints(button)
    bar:SetFrameLevel(button:GetFrameLevel() + 1)
    bar:SetStatusBarTexture(isPower and ns.POWER_TEXTURE or ns.TEXTURE_DEFAULT)
    bar:SetOrientation("HORIZONTAL")
    bar._u = u
    bar:SetScript("OnUpdate", ns.Prof.Wrap("Units: barras (smooth)", BarOnUpdate))

    -- Textura de relleno MANUAL (para valores legibles; encima del relleno nativo).
    -- Recorte via SetTexCoord+SetVertexOffset (tecnica WeakAuras), sin mascara.
    local fillTex = bar:CreateTexture(nil, "OVERLAY")
    fillTex:Hide()

    u.button, u.bg, u.editBG, u.cage, u.bar, u.fillTex = button, bg, editBG, cage, bar, fillTex

    -- Cast bar (StatusBar) por encima del hp bar (solo vida). Es StatusBar para poder
    -- usar SetTimerDuration (rellena en C), unico modo de mostrar casteos con tiempos
    -- SECRETOS (enemigos en Midnight). El spark se ancla al borde del relleno.
    if not isPower then
        local castBar = CreateFrame("StatusBar", nil, button)
        castBar:SetPoint("CENTER", button, "CENTER", 0, 0)
        castBar:SetSize(250, 20)
        castBar:SetFrameLevel(button:GetFrameLevel() + 2)
        castBar:SetOrientation("HORIZONTAL")
        castBar:SetStatusBarTexture(ns.TEXTURE_DEFAULT)
        castBar:SetMinMaxValues(0, 1)
        castBar:SetValue(0)
        castBar:SetAlpha(0)
        local castSpark = castBar:CreateTexture(nil, "OVERLAY")
        castSpark:SetBlendMode("ADD")
        SetSparkTexture(castSpark)
        castSpark:Hide()
        castBar._u = u
        castBar:SetScript("OnUpdate", ns.Prof.Wrap("Units: cast bars", CastOnUpdate))
        u.castBar, u.castSpark = castBar, castSpark
    end

    -- Overlay para textos: por encima del cast bar para que no los tape.
    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints(button)
    overlay:SetFrameLevel(button:GetFrameLevel() + 3)
    u.overlay = overlay

    -- Highlight de "unidad seleccionada" (target): DETRAS de todas las texturas de la
    -- unidad. Va en el propio button, capa BACKGROUND sublevel minimo (-8), asi el bg,
    -- la cage (ARTWORK) y los ns.frames hijos (bar/cast/overlay) renderizan todos ENCIMA;
    -- el borde-glow asoma por detras del frame. Latido opcional.
    local highlight = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    highlight:SetPoint("CENTER")
    highlight:Hide()
    local hlAnim = highlight:CreateAnimationGroup()
    hlAnim:SetLooping("REPEAT")
    local hla1 = hlAnim:CreateAnimation("Alpha"); hla1:SetFromAlpha(1); hla1:SetToAlpha(0.4); hla1:SetDuration(0.6); hla1:SetOrder(1); hla1:SetSmoothing("IN_OUT")
    local hla2 = hlAnim:CreateAnimation("Alpha"); hla2:SetFromAlpha(0.4); hla2:SetToAlpha(1); hla2:SetDuration(0.6); hla2:SetOrder(2); hla2:SetSmoothing("IN_OUT")
    u.highlight, u.highlightAnim = highlight, hlAnim

    local hpText = overlay:CreateFontString(nil, "OVERLAY")
    hpText:SetTextColor(ns.GOLD.r, ns.GOLD.g, ns.GOLD.b, 1)
    u.hpText = hpText

    if ns.HasNameByKey(def.key) then
        local nameText = overlay:CreateFontString(nil, "OVERLAY")
        nameText:SetTextColor(ns.GOLD.r, ns.GOLD.g, ns.GOLD.b, 1)
        nameText:SetJustifyH("CENTER")
        nameText:SetWordWrap(false)
        u.nameText = nameText

        local spellText = overlay:CreateFontString(nil, "OVERLAY")
        spellText:SetTextColor(ns.GOLD.r, ns.GOLD.g, ns.GOLD.b, 1)
        spellText:SetJustifyH("CENTER")
        spellText:SetWordWrap(false)
        spellText:SetAlpha(0)
        u.spellText = spellText
    end

    if not isPower then
        button:SetScript("OnEnter", function(self)
            u.isMouseOver = true
            if ns.GetDB() then UnitTextVisibility(u) end
            if ns.GetDB() and P(u).showTooltip and UnitExists(u.unit) then
                GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
                GameTooltip:SetUnit(u.unit)
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function()
            u.isMouseOver = false
            if ns.GetDB() then UnitTextVisibility(u) end
            GameTooltip:Hide()
        end)
    end

    button:SetScript("OnDragStart", function(self)
        if ns.IsUnlocked() and not InCombatLockdown() then
            u._dragStart = { self:GetCenter() }   -- centro al empezar (para mover el grupo)
            self:StartMoving()
        end
    end)
    button:SetScript("OnDragStop", function(self)
        -- Si el combate empezo A MITAD del drag (el drag solo puede EMPEZAR fuera de
        -- combate), StopMovingOrSizing sobre el frame SEGURO esta bloqueado
        -- (ADDON_ACTION_BLOCKED). Diferir el stop + guardado a PLAYER_REGEN_ENABLED,
        -- que re-invoca este mismo handler.
        if InCombatLockdown() and self:IsProtected() then
            u._stopMovePending = true
            return
        end
        u._stopMovePending = nil
        self:StopMovingOrSizing()
        if ns.SnapFrameToGrid then ns.SnapFrameToGrid(self) end
        local p = P(u)
        -- Delta de movimiento en pantalla (para el grupo).
        local dx, dy = 0, 0
        if u._dragStart then
            local cx, cy = self:GetCenter()
            if cx and u._dragStart[1] then dx, dy = cx - u._dragStart[1], cy - u._dragStart[2] end
        end
        -- Guardar la posicion propia (relativa a su anchor, CENTER-CENTER).
        local parent = _G[p.anchorFrame]
        if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
        local s, ps = self:GetEffectiveScale(), parent:GetEffectiveScale()
        local fx, fy = self:GetCenter()
        local px, py = parent:GetCenter()
        if fx and px then
            p.point, p.relativePoint = "CENTER", "CENTER"
            p.offsetX = (fx * s - px * ps) / s
            p.offsetY = (fy * s - py * ps) / s
        end
        -- Mover el resto del grupo (misma delta) si la opcion esta activa.
        local group = ns.GetMoveGroup(u.key)
        if group then
            for _, gk in ipairs(group) do
                if gk ~= u.key then
                    local gp = ns.GetDB().units[gk]
                    gp.offsetX = (gp.offsetX or 0) + dx
                    gp.offsetY = (gp.offsetY or 0) + dy
                    RefreshUnit(gk)
                end
            end
        end
        -- Seguidores de arrastre (ns.portraits que siguen a su unitframe, party, etc.).
        if ns.MoveFollowers then ns.MoveFollowers(u.key, dx, dy) end
        u._dragStart = nil
        RefreshUnit(u.key)
        if ns.OnDragStopped then ns.OnDragStopped(u.key) end
    end)

    if not isPower then
        if def.driver then
            RegisterStateDriver(button, "visibility", def.driver)
        else
            RegisterUnitWatch(button)
        end
    end

    -- ICONO DE TRINKET DE PVP (pedido del usuario 2026-07-19, SOLO Arena Enemy
    -- 1/2/3) -- este widget UNICAMENTE dibuja (icono + CooldownFrame nativo);
    -- la deteccion/calculo del cooldown vive enteramente en ArenaTrinket.lua
    -- (separacion pedida explicitamente por el usuario). Se crea siempre para
    -- las 3 claves arena_enemy* (barato, un frame chico) pero arranca oculto;
    -- ReassertTrinket lee showTrinket/trinketSize/trinketOffsetX/Y en vivo.
    if def.key:sub(1, 11) == "arena_enemy" then
        local trinket = CreateFrame("Frame", nil, button)
        trinket:Hide()
        local tex = trinket:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints(trinket)
        tex:SetTexture(228044)   -- icono generico "PvP Trinket" (Gladiator's Medallion)
        trinket.tex = tex
        local cd = CreateFrame("Cooldown", nil, trinket, "CooldownFrameTemplate")
        cd:SetAllPoints(trinket)
        cd:SetDrawEdge(false)
        trinket.cd = cd
        u.trinket = trinket

        local function ReassertTrinket()
            -- FIX (2026-07-19, reportado por el usuario -- "Units.lua:15:
            -- attempt to index a nil value"): P(u) hace ns.GetDB().units[...]
            -- SIN chequear que GetDB() no sea nil -- a la hora en que
            -- CreateUnit corre (carga inicial del addon, ANTES de
            -- ADDON_LOADED/InitDB), ns.GetDB() todavia devuelve nil. Llamar
            -- ReassertTrinket() eager aca (como se hacia antes) crasheaba a
            -- mitad de Units.lua, y el resto del ARCHIVO nunca terminaba de
            -- ejecutar (ns.RefreshUnit y demas ns.* quedaban sin definir) --
            -- de ahi la cascada de errores en core.lua. Se saca la llamada
            -- eager de mas abajo Y se guarda esta funcion contra GetDB() nil.
            local dbRoot = ns.GetDB and ns.GetDB()
            local p = dbRoot and dbRoot.units and dbRoot.units[u.key]
            if not (p and p.showTrinket) then trinket:Hide(); return end
            local sz = p.trinketSize or 24
            trinket:ClearAllPoints()
            trinket:SetSize(sz, sz)
            trinket:SetPoint("CENTER", button, "CENTER", p.trinketOffsetX or 0, p.trinketOffsetY or -30)
            trinket:Show()
            local st = ns.ArenaTrinketState and ns.ArenaTrinketState[u.unit]
            if st and st.start and st.duration then
                pcall(cd.SetCooldown, cd, st.start, st.duration)
            end
        end
        u.trinketReassert = ReassertTrinket
        -- (sin llamada eager aca -- RefreshAll()/UnitApplyAppearance la
        -- invoca despues de ADDON_LOADED, cuando GetDB() ya existe)
    end

    -- READY CHECK (pedido del usuario 2026-07-20: "agregar lo de readycheck
    -- a mis party 1 a 5 tambien" -- lo mismo que ya tiene el raid frame).
    -- GetReadyCheckStatus(unit) devuelve "ready"/"notready"/"waiting" mientras
    -- hay un ready check activo, o nil si no hay ninguno -- se puede consultar
    -- directo cada tick, sin trackear READY_CHECK_* por separado.
    if def.key:sub(1, 5) == "party" then
        local readyCheckIcon = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
        readyCheckIcon:SetSize(20, 20)
        readyCheckIcon:SetPoint("CENTER", button, "CENTER", 0, 0)
        readyCheckIcon:Hide()
        u.readyCheckIcon = readyCheckIcon
    end

    ns.AttachScaleWheel(u.button, function() return P(u) end, function() UnitApplyLayout(u) end)

    -- Range fade / shield bar (2026-07-27, ver Indicators.lua, que carga
    -- ANTES de este archivo para que la funcion ya exista aca).
    if ns.CreateUnitIndicators then ns.CreateUnitIndicators(u) end

    ns.frames[def.key] = u
    return u
end

-- Expuesta para que ArenaTrinket.lua (deteccion pura, sin conocer frames) avise
-- cuando detecta/limpia un uso de trinket -- busca el frame arena_enemy* cuyo
-- unit coincide y reaplica su cooldown visual. Separacion total pedida por el
-- usuario: este archivo (dibujo) nunca escucha COMBAT_LOG el mismo.
function ns.RefreshArenaTrinketIcon(unit)
    for _, u in pairs(ns.frames) do
        if u.trinketReassert and u.unit == unit then u.trinketReassert() end
    end
end

for _, def in ipairs(ns.UNITS) do CreateUnit(def) end

local function PetDriverString()
    if ns.safeBool(IsInInstance) then return "[@pet,exists] show; hide" end
    return "[@pet,exists,combat] show; [@pet,exists,@target,exists] show; hide"
end

local function UpdatePetDriver()
    local u = ns.frames["pet"]
    if not u then return end
    local d = PetDriverString()
    u.driver = d
    if ns.IsUnlocked() then return end
    if InCombatLockdown() then u.needsDriver = true return end
    UnregisterStateDriver(u.button, "visibility")
    RegisterStateDriver(u.button, "visibility", d)
    u.needsDriver = nil
end

-- Party1-5: visibles SOLO en grupo pequeño (party/dungeon). Se ocultan en raid
-- y en cualquier instancia PvP (battleground/arena). En raid los tokens party1-4
-- ni existen, pero en ARENA sí → por eso hace falta el chequeo de tipo de
-- instancia en Lua (no hay condicional de macro para "arena").
local function PartyDriverString(u)
    -- Arena (grupo de party + instancia pvp): no hay condicional de macro para
    -- "arena", asi que se detecta en Lua y se oculta del todo.
    local isPvP = false
    pcall(function()
        local _, it = IsInInstance()
        isPvP = (it == "pvp" or it == "arena")
    end)
    if isPvP then return "hide" end
    -- [group:raid] es un condicional SEGURO y dinamico: oculta en raid y en
    -- CUALQUIER battleground (todos son grupos de raid al activarse), sin depender
    -- del timing del update en Lua ni del diferido por combate.
    -- CASO ESPECIAL "party5" (unit="player", pedido del usuario 2026-07-16: el 5to slot
    -- ahora muestra al propio jugador en vez de un token "party5" que no existe en WoW):
    -- `[@player,exists]` siempre es verdadero, asi que ese condicional NO sirve para
    -- ocultarlo estando solo (a diferencia de party1-4, que naturalmente no existen sin
    -- grupo). Se usa `[group]` (verdadero en CUALQUIER grupo, party o raid) en su lugar,
    -- para que se comporte igual que las otras 4 tiles: visible solo si estas agrupado.
    if u.key == "party5" then
        return "[group:raid] hide; [group] show; hide"
    end
    return "[group:raid] hide; [@" .. u.unit .. ",exists] show; hide"
end

local function UpdatePartyDrivers()
    for _, key in ipairs(ns.PARTY_KEYS) do
        local u = ns.frames[key]
        if u and u.button then
            local d = PartyDriverString(u)
            u.driver = d
            if ns.IsUnlocked() then
                -- en preview no se toca; se aplica al salir (SetUnlocked usa u.driver)
            elseif InCombatLockdown() then
                u.needsDriver = true
            else
                UnregisterUnitWatch(u.button)
                UnregisterStateDriver(u.button, "visibility")
                RegisterStateDriver(u.button, "visibility", d)
                u.needsDriver = nil
            end
        end
    end
end
-- ARENA (pedido del usuario 2026-07-19): "solo debe aparecer en arenas" -- mismo
-- patron que PartyDriverString/UpdatePartyDrivers de arriba (no hay condicional
-- de macro para "arena", se detecta en Lua via IsInInstance y se arma el driver
-- a mano). A diferencia de party, arena_player/party1/party2 usan tokens que
-- SIEMPRE existen fuera de arena tambien (player/party1/party2) -- por eso el
-- gate de "estoy en arena" es OBLIGATORIO (no alcanza con [@unit,exists]).
local function ArenaDriverString(u)
    local isArena = false
    pcall(function()
        local _, it = IsInInstance()
        isArena = (it == "arena")
    end)
    if not isArena then return "hide" end
    return "[@" .. u.unit .. ",exists] show; hide"
end

local function UpdateArenaDrivers()
    for _, key in ipairs(ns.ARENA_KEYS) do
        local u = ns.frames[key]
        if u and u.button then
            local d = ArenaDriverString(u)
            u.driver = d
            if ns.IsUnlocked() then
                -- en preview no se toca; se aplica al salir (SetUnlocked usa u.driver)
            elseif InCombatLockdown() then
                u.needsDriver = true
            else
                UnregisterUnitWatch(u.button)
                UnregisterStateDriver(u.button, "visibility")
                RegisterStateDriver(u.button, "visibility", d)
                u.needsDriver = nil
            end
        end
    end
end
ns.UpdateArenaDrivers = UpdateArenaDrivers

-- Expuestas para que core.lua (ticker principal, SetUnlocked, eventos) las invoque
-- sin depender de locals de este archivo.
ns.P = P
ns.PowerShouldShow = PowerShouldShow
ns.UnitApplyLayout = UnitApplyLayout
ns.UnitApplyAppearance = UnitApplyAppearance
ns.UnitUpdateBar = UnitUpdateBar
ns.UnitUpdateColor = UnitUpdateColor
ns.UnitTextVisibility = UnitTextVisibility
ns.UnitUpdateMount = UnitUpdateMount
ns.UnitUpdateDeadCage = UnitUpdateDeadCage
ns.UnitUpdateHighlight = UnitUpdateHighlight
ns.ReadCastMode = ReadCastMode
ns.UpdatePetDriver = UpdatePetDriver
ns.UpdatePartyDrivers = UpdatePartyDrivers

-- Apaga TODOS los cast bars, para llamar al SALIR del preview (2026-07-29,
-- reportado: "el cast bar del tot aun se muestra, si hago mcf cuando no existe
-- ningun tot ... pasa con el focus tambien").
--
-- Por que hace falta un desmontaje explicito y no alcanza con la rama de ocioso
-- de CastOnUpdate: esa rama es un OnUpdate, y un OnUpdate NO CORRE mientras su
-- frame esta oculto. La secuencia para una unidad condicional (tot/focus/boss/
-- party/arena) que no existe al entrar en preview es:
--
--   1. SetUnlocked(true) fuerza u.button:Show() en TODOS los frames, exista o no
--      la unidad -- para poder posicionarlos.
--   2. CastOnUpdate empieza a correr y pinta la barra de muestra (60%, alpha,
--      spark). No esta detras de ningun UnitExists, a diferencia de
--      UnitUpdateBar, que el tick SI saltea si la unidad no existe -- por eso se
--      quedaba pintado el cast bar y no el nombre ni el texto de vida.
--   3. Al salir, RegisterUnitWatch/el state driver vuelven a ocultar el frame
--      porque la unidad sigue sin existir. El OnUpdate se CONGELA ahi mismo, con
--      la barra de muestra aplicada.
--   4. Cuando la unidad aparece de verdad, el frame se muestra ya pintado.
--
-- Con un tot/focus presente al entrar en preview no pasaba: el frame seguia
-- visible al salir, el OnUpdate nunca se congelaba y la rama de ocioso limpiaba.
-- Esa era justo la diferencia que reporto el usuario.
--
-- Resetear en la TRANSICION es correcto pase lo que pase con la visibilidad del
-- frame, y de paso saca el parpadeo de un frame que quedaba incluso cuando el
-- OnUpdate si revivia.
function ns.ResetUnitCastBars()
    for _, u in pairs(ns.frames) do
        local cb = u.castBar
        if cb then
            cb:SetAlpha(0)
            cb:SetValue(0)
            if u.castSpark then u.castSpark:Hide() end
            -- Las banderas quedan describiendo lo que ACABA de aplicarse, mismo
            -- criterio que la rama de ocioso: idle aplicado, y el ultimo alpha
            -- escrito es 0 -- NO castAlpha. Dejar _alphaApplied en castAlpha aca
            -- haria que el proximo casteo se saltee su SetAlpha y la barra nunca
            -- reaparezca (ese fue el bug del cast bar del player, 2026-07-28).
            cb._idleApplied = true
            cb._alphaApplied = nil
            cb._castMode, cb._timerActive = nil, false
            -- El modo cacheado del throttle tambien: si no, al revivir el
            -- OnUpdate los primeros 50ms se responden con el modo de la unidad
            -- ANTERIOR que ocupaba este frame.
            cb._lastPolledMode, cb._castPollAcc = nil, 0
        end
    end
end

ns.RefreshAllUnits = function()
    for _, u in pairs(ns.frames) do
        UnitApplyLayout(u)
        UnitApplyAppearance(u)
    end
end

-- Tick por-unidad (barras/highlight/badges), llamado desde el ticker principal de core.
local tickUnitsN = 0
ns.TickUnits = function()
    local db = ns.GetDB()
    -- Textos en pasadas alternas: 5 Hz en vez de 10. Un porcentaje que cambia 5
    -- veces por segundo ya es mas rapido de lo que se puede leer, y la BARRA
    -- sigue a 10 Hz con su interpolacion suave a 60 fps, asi que no se degrada
    -- nada visible. Mismo patron que ya usa el tick principal con TickRaid
    -- (cada 2do ciclo) y MM_ReassertArt (cada 5to).
    tickUnitsN = tickUnitsN + 1
    local doText = (tickUnitsN % 2 == 0)
    for _, u in pairs(ns.frames) do
        if u.kind == "power" then u.button:SetShown(PowerShouldShow(u)) end
        if u.key == "pet" then
            local hasPet = UnitExists("pet")
            local pp = db.units.pet
            if u.cage then u.cage:SetShown(hasPet and pp.cageTexture and pp.cageTexture ~= "" and true or false) end
            if u.bg then u.bg:SetShown(hasPet and pp.showBackground and true or false) end
            if not hasPet then
                if u.fillTex then u.fillTex:Hide() end
                u.bar:GetStatusBarTexture():SetAlpha(0)
            end
            -- Por SetTextIfChanged, no SetText directo: mismo motivo que la rama
            -- de preview de UnitUpdateBar (2026-07-29). Vaciar por afuera dejaba
            -- la cache _mcfLastText con el nombre viejo del pet, asi que al
            -- volver a invocarlo UnitUpdateName recalculaba ESE MISMO nombre, la
            -- comparacion daba igual y no se reescribia nada: el frame del pet
            -- se quedaba con el nombre en blanco.
            if (not hasPet) or ns.safeBool(UnitIsDeadOrGhost, "pet") then
                if u.hpText then SetTextIfChanged(u.hpText, "") end
                if u.nameText then u.nameText:SetAlpha(0); SetTextIfChanged(u.nameText, "") end
                if u.spellText then u.spellText:SetAlpha(0); SetTextIfChanged(u.spellText, "") end
            end
        end
        if UnitExists(u.unit) then
            -- Instrumentadas por separado (2026-07-28): TickUnits resulto ser el
            -- mayor costo del addon -- 7.08 ms/s, el 77% del tick principal --
            -- y estas seis corren para CADA unidad, 10 veces por segundo, sin
            -- ningun dedupe. Antes de tocar nada hay que saber cual pesa.
            ns.Prof.Time("     . UnitUpdateBar", UnitUpdateBar, u, doText)
            ns.Prof.Time("     . UnitUpdateColor", UnitUpdateColor, u)
            ns.Prof.Time("     . UnitTextVisibility", UnitTextVisibility, u)
            ns.Prof.Time("     . UnitUpdateMount", UnitUpdateMount, u)
            ns.Prof.Time("     . UnitUpdateDeadCage", UnitUpdateDeadCage, u)
            ns.Prof.Time("     . UnitUpdateHighlight", UnitUpdateHighlight, u)
            if u.readyCheckIcon then
                local status = ns.safeVal(GetReadyCheckStatus, u.unit)
                if status == "ready" then
                    u.readyCheckIcon:SetTexture([[Interface\RaidFrame\ReadyCheck-Ready]]); u.readyCheckIcon:Show()
                elseif status == "notready" then
                    u.readyCheckIcon:SetTexture([[Interface\RaidFrame\ReadyCheck-NotReady]]); u.readyCheckIcon:Show()
                elseif status == "waiting" then
                    u.readyCheckIcon:SetTexture([[Interface\RaidFrame\ReadyCheck-Waiting]]); u.readyCheckIcon:Show()
                else
                    u.readyCheckIcon:Hide()
                end
            end
        elseif u.readyCheckIcon then
            u.readyCheckIcon:Hide()
        end
    end
end
