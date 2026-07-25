-- ==========================================================================
-- MyCustomFrames - ClassPower.lua
-- Pedido del usuario 2026-07-19: "Class power, tal cual como lo tiene
-- azeriteui, mismas texturas etc" -- combo points / holy power / chi / soul
-- shards / arcane charges / essence / runas, con el layout exacto (posicion,
-- tamaño, rotacion POR PUNTO formando un arco) portado de AzeriteUI5
-- (Layouts/Data/PlayerClassPower.lua, JuNNeZ/AzeriteUI5-JuNNeZ-Edition en
-- GitHub) -- assets copiados 1:1 (point_crystal/point_diamond/point_hearth/
-- point_rune1-4/point_dk_block/point_plate).
--
-- ARQUITECTURA: AzeriteUI original esta construido sobre oUF (framework
-- completo, con su propio sistema de perfiles/anclaje) -- ese codigo NO se
-- puede portar tal cual a este addon (que reskinea frames NATIVOS de
-- Blizzard, no reemplaza nada con oUF). Standalone, mismo patron que
-- Glow.lua/InfoBar.lua: frame propio, event-driven, con Position/Size/
-- BackdropSize/Rotation identicos a los del layout original.
--
-- SECRET-SAFE (Midnight): el poder de clase del PROPIO jugador (combo
-- points, holy power, etc) NO es informacion de combate ajena -- es el dato
-- MAS basico para jugar tu propia rotacion, asi que UnitPower/UnitPowerMax
-- sobre "player" no deberian venir secretos (a diferencia de vida/poder de
-- OTRAS unidades) -- igual todo pasa por pcall como el resto del addon, por
-- las dudas. Runas: GetRuneCooldown(i) devuelve start/duration/ready, mismos
-- tipos que ya usamos de forma segura para el swipe de cooldown de auras
-- (Nameplates.lua) -- se pasan crudos a Cooldown:SetCooldown (consumidora).
--
-- v2 (2026-07-20, pedido del usuario "implementa los que faltan"): agregado
-- Death Knight (runas, el layout YA estaba portado pero nunca se conectaba
-- a nada -- DetectResource no tenia rama para esa clase), Demon Hunter
-- (Soul Fragments, via Enum.PowerType.SoulFragments) y Shaman Enhancement
-- (Maelstrom Weapon -- a diferencia de TODO lo demas de este archivo, NO es
-- un UnitPower: es el CONTADOR DE STACKS de un buff propio (spellID 344179),
-- asi que necesita su propio camino de deteccion/actualizacion via
-- C_UnitAuras.GetPlayerAuraBySpellID + evento UNIT_AURA, en vez de
-- UnitPower/UNIT_POWER_FREQUENT). Monk Brewmaster (Stagger) queda AFUERA a
-- proposito: es una BARRA continua de daño diferido, no puntos discretos --
-- necesitaria un widget completamente distinto a este sistema de "arco de
-- puntos", fuera del alcance de este archivo.
-- ==========================================================================
local ADDON, ns = ...
local A = ns.ASSETS

local TEX = {
    crystal  = A .. "point_crystal.tga",
    diamond  = A .. "point_diamond.tga",
    hearth   = A .. "point_hearth.tga",
    plate    = A .. "point_plate.tga",
    rune1    = A .. "point_rune1.tga",
    rune2    = A .. "point_rune2.tga",
    rune3    = A .. "point_rune3.tga",
    rune4    = A .. "point_rune4.tga",
    dkblock  = A .. "point_dk_block.tga",
}

-- Sistema de Skins (2026-07-23, pedido del usuario "el class power tambien se
-- reskinee"): los paths de TEX se hornean UNA vez al cargar el archivo, asi
-- que LAYOUTS.tex/btex quedan fijos en el Default -- resolver el BASENAME
-- contra la skin activa recien al DIBUJAR cada punto (LayoutPoints) en vez de
-- guardar el path resuelto, mismo patron que SkinResolve usa en todos lados.
local function ResolveTex(path)
    if not ns.SkinResolve then return path end
    local base = path:match("([^\\]+)$") or path
    return ns.SkinResolve(base)
end

-- Colores por recurso (los que ya existen en ns.POWER_COLORS se reusan; los
-- que faltan -- combo points, arcane charges, runas -- se agregan aca).
local POINT_COLOR = setmetatable({
    COMBO_POINTS   = { r = 1, g = 0.8, b = 0.13 },
    ARCANE_CHARGES = { r = 0.1, g = 0.5, b = 1 },
    RUNES          = { r = 0.77, g = 0.12, b = 0.23 },
    ESSENCE        = ns.POWER_COLORS and ns.POWER_COLORS.ESSENCE,
    HOLY_POWER     = ns.POWER_COLORS and ns.POWER_COLORS.HOLY_POWER,
    CHI            = ns.POWER_COLORS and ns.POWER_COLORS.CHI,
    SOUL_SHARDS    = ns.POWER_COLORS and ns.POWER_COLORS.SOUL_SHARDS,
    -- Nuevos (2026-07-20): Demon Hunter / Shaman Enhancement.
    SOUL_FRAGMENTS   = { r = 0.64, g = 0.85, b = 0.42 },   -- verde felido (Vengeance)
    MAELSTROM_WEAPON = { r = 0.20, g = 0.55, b = 0.95 },   -- azul electrico (Maelstrom)
}, { __index = function() return { r = 1, g = 1, b = 1 } end })

local function ClassPowerDefaults()
    return {
        enabled = true,
        anchorFrame = "", point = "CENTER", relativePoint = "CENTER",
        offsetX = 220, offsetY = -160, scale = 1.0, strata = "MEDIUM",
        caseColor = { r = 211 / 255, g = 200 / 255, b = 169 / 255 },
        useClassColor = true,   -- puntos "prendidos" con el color del recurso; si no, blanco
        dimAlpha = 0.35,        -- opacidad de los puntos "apagados" (aun no ganados)
    }
end
ns.ClassPowerDefaults = ClassPowerDefaults

-- ==========================================================================
-- LAYOUTS: posicion/tamaño/rotacion EXACTOS de AzeriteUI (grados -> radianes
-- via math.rad, mismo toRadians que el original). Los nombres son solo
-- layouts (cantidad de puntos + forma del arco), no power types -- el mismo
-- layout se reusa para distintos recursos con la MISMA cantidad de puntos
-- (comentario original de AzeriteUI, se mantiene el criterio).
-- ==========================================================================
local function P(x, y, sz, bsz, tex, btex, rotDeg)
    return {
        x = x, y = y, w = sz[1], h = sz[2], bw = bsz[1], bh = bsz[2],
        tex = tex, btex = btex, rot = rotDeg and math.rad(rotDeg) or nil,
    }
end

local LAYOUTS = {
    ArcaneCharges = { -- 4
        P(78, -139, { 13, 13 }, { 58, 58 }, TEX.crystal, TEX.plate, 6),
        P(57, -111, { 13, 13 }, { 60, 60 }, TEX.crystal, TEX.plate, 5),
        P(49, -76,  { 13, 13 }, { 60, 60 }, TEX.crystal, TEX.plate, 4),
        P(72, -33,  { 51, 52 }, { 104, 104 }, TEX.hearth, TEX.plate, nil),
    },
    ComboPoints = { -- 5 (combo points / holy power / soul shards enteros / essence base)
        P(82, -137, { 13, 13 }, { 58, 58 }, TEX.crystal, TEX.plate, 6),
        P(64, -111, { 13, 13 }, { 60, 60 }, TEX.crystal, TEX.plate, 5),
        P(54, -79,  { 13, 13 }, { 60, 60 }, TEX.crystal, TEX.plate, 4),
        P(60, -44,  { 13, 13 }, { 60, 60 }, TEX.crystal, TEX.plate, nil),
        P(82, -11,  { 14, 21 }, { 82, 96 }, TEX.crystal, TEX.diamond, 1),
    },
    Chi = { -- 6 (monk / essence con talento)
        P(82, -137, { 13, 13 }, { 58, 58 }, TEX.crystal, TEX.plate, 6),
        P(70, -111, { 13, 13 }, { 60, 60 }, TEX.crystal, TEX.plate, 5),
        P(61, -79,  { 12, 12 }, { 56, 56 }, TEX.crystal, TEX.plate, -2),
        P(58, -44,  { 13, 13 }, { 60, 60 }, TEX.crystal, TEX.plate, nil),
        P(61, -11,  { 13, 13 }, { 60, 60 }, TEX.crystal, TEX.plate, nil),
        P(70, 31,   { 39, 40 }, { 80, 80 }, TEX.hearth, TEX.plate, nil),
    },
    SoulShards = { -- 5
        P(82, -137, { 12, 12 }, { 54, 54 }, TEX.crystal, TEX.plate, 6),
        P(64, -111, { 13, 13 }, { 60, 60 }, TEX.crystal, TEX.plate, 5),
        P(50, -80,  { 11, 15 }, { 65, 60 }, TEX.crystal, TEX.diamond, 3),
        P(58, -44,  { 12, 18 }, { 78, 79 }, TEX.crystal, TEX.diamond, 3),
        P(82, -11,  { 14, 21 }, { 82, 96 }, TEX.crystal, TEX.diamond, 1),
    },
    ComboPointsRogue = { -- 7 (arco parabolico simple, calcado de CreateRogueComboPointLayout)
        -- generado abajo, ver GenerateRogue7()
    },
    Runes = { -- 6 (Death Knight)
        P(82, -131, { 28, 28 }, { 58, 58 }, TEX.rune2, TEX.dkblock, nil),
        P(58, -107, { 28, 28 }, { 68, 68 }, TEX.rune4, TEX.dkblock, nil),
        P(32, -83,  { 30, 30 }, { 74, 74 }, TEX.rune1, TEX.dkblock, nil),
        P(65, -64,  { 28, 28 }, { 68, 68 }, TEX.rune3, TEX.dkblock, nil),
        P(39, -38,  { 32, 32 }, { 78, 78 }, TEX.rune2, TEX.dkblock, nil),
        P(79, -10,  { 40, 40 }, { 98, 98 }, TEX.rune1, TEX.dkblock, nil),
    },
}

-- Rogue 7-punto: mismo arco parabolico simple que el original (apexX=58,
-- edgeX=82, mirrorY=-45, edgeDistanceY=92) -- valores de Y calcados 1:1.
do
    local apexX, edgeX, mirrorY, edgeDistanceY = 58, 82, -45, 92
    local ys = { -137, -111, -79, -44, -11, 21, 47 }
    local rots = { 6, 5, 4, nil, -4, -5, -1 }
    for i, y in ipairs(ys) do
        local ny = (y - mirrorY) / edgeDistanceY
        local x = math.floor(apexX + ((edgeX - apexX) * ny * ny) + 0.5)
        local sz, bsz = { 13, 13 }, { 60, 60 }
        if i == 1 then bsz = { 58, 58 } end
        if i == 7 then sz, bsz = { 14, 21 }, { 82, 96 } end
        LAYOUTS.ComboPointsRogue[i] = P(x, y, sz, bsz, TEX.crystal,
            (i == 7) and TEX.diamond or TEX.plate, rots[i])
    end
end

-- ==========================================================================
-- Deteccion del recurso activo del jugador -- devuelve (layoutName,
-- powerType, colorKey) o nil si la clase/spec actual no tiene class power
-- soportado todavia. Runas (DK) se manejan aparte (no son un numero simple).
-- ==========================================================================
local function SafeMax(unit, ptype)
    local ok, v = pcall(UnitPowerMax, unit, ptype)
    if not ok or type(v) ~= "number" or (issecretvalue and issecretvalue(v)) then return 0 end
    return v
end

-- Maelstrom Weapon (Shaman Enhancement): NO es un UnitPower, es el CONTADOR
-- DE STACKS de un buff propio (spellID 344179) -- se lee via
-- C_UnitAuras.GetPlayerAuraBySpellID, no UnitPower/UnitPowerMax.
local MAELSTROM_WEAPON_SPELLID = 344179
local function GetMaelstromStacks()
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return 0 end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, MAELSTROM_WEAPON_SPELLID)
    if ok and aura and type(aura.applications) == "number" then return aura.applications end
    return 0
end

-- El buff de Maelstrom Weapon esta ausente tanto si el jugador no es
-- Enhancement COMO si es Enhancement con 0 stacks acumulados -- no se puede
-- distinguir "clase/spec sin este recurso" de "con el recurso en 0" mirando
-- solo el aura. Se chequea el SPEC directamente (Enhancement = specID 263)
-- para decidir si mostrar el widget en absoluto.
local ENHANCEMENT_SPEC_ID = 263
local function IsEnhancementShaman()
    local ok1, specIndex = pcall(GetSpecialization)
    if not (ok1 and specIndex) then return false end
    local ok2, specID = pcall(GetSpecializationInfo, specIndex)
    return ok2 and specID == ENHANCEMENT_SPEC_ID
end

local function DetectResource()
    local _, class = UnitClass("player")
    if class == "ROGUE" or class == "DRUID" then
        local max = SafeMax("player", Enum.PowerType.ComboPoints)
        if max <= 0 then return nil end
        if max >= 7 then return "ComboPointsRogue", Enum.PowerType.ComboPoints, "COMBO_POINTS" end
        if max == 6 then return "Chi", Enum.PowerType.ComboPoints, "COMBO_POINTS" end
        return "ComboPoints", Enum.PowerType.ComboPoints, "COMBO_POINTS"
    elseif class == "PALADIN" then
        if SafeMax("player", Enum.PowerType.HolyPower) <= 0 then return nil end
        return "ComboPoints", Enum.PowerType.HolyPower, "HOLY_POWER"
    elseif class == "MONK" then
        if SafeMax("player", Enum.PowerType.Chi) <= 0 then return nil end
        return "Chi", Enum.PowerType.Chi, "CHI"
    elseif class == "WARLOCK" then
        if SafeMax("player", Enum.PowerType.SoulShards) <= 0 then return nil end
        return "SoulShards", Enum.PowerType.SoulShards, "SOUL_SHARDS"
    elseif class == "MAGE" then
        if SafeMax("player", Enum.PowerType.ArcaneCharges) <= 0 then return nil end
        return "ArcaneCharges", Enum.PowerType.ArcaneCharges, "ARCANE_CHARGES"
    elseif class == "EVOKER" then
        local max = SafeMax("player", Enum.PowerType.Essence)
        if max <= 0 then return nil end
        if max == 6 then return "Chi", Enum.PowerType.Essence, "ESSENCE" end
        return "ComboPoints", Enum.PowerType.Essence, "ESSENCE"
    elseif class == "DEATHKNIGHT" then
        -- Sin SafeMax: las runas no son un UnitPower simple (6 cooldowns
        -- independientes, ver UpdateRunes). "powerType" se usa aca como
        -- SENTINEL para que Refresh() rutee a UpdateRunes en vez de
        -- UpdateSimplePoints.
        return "Runes", "RUNES", "RUNES"
    elseif class == "DEMONHUNTER" then
        -- Guard extra: si este cliente no tiene Enum.PowerType.SoulFragments
        -- (nil), pasarlo igual a UnitPowerMax NO fallaria -- un powerType nil
        -- devuelve el poder PRIMARIO (fury), un numero > 0 falso positivo.
        if Enum.PowerType.SoulFragments == nil then return nil end
        local max = SafeMax("player", Enum.PowerType.SoulFragments)
        if max <= 0 then return nil end
        if max >= 6 then return "Chi", Enum.PowerType.SoulFragments, "SOUL_FRAGMENTS" end
        return "ComboPoints", Enum.PowerType.SoulFragments, "SOUL_FRAGMENTS"
    elseif class == "SHAMAN" then
        if not IsEnhancementShaman() then return nil end
        -- Idem DEATHKNIGHT: sentinel "MAELSTROM_WEAPON" en vez de un
        -- Enum.PowerType real, Refresh() rutea a UpdateMaelstrom.
        return "ComboPoints", "MAELSTROM_WEAPON", "MAELSTROM_WEAPON"
    end
    -- MONK brewmaster (stagger): NO implementado a proposito -- es una barra
    -- continua de daño diferido, no puntos discretos; necesitaria un widget
    -- distinto a este sistema de "arco de puntos" (ver comentario grande
    -- arriba del archivo).
    return nil
end

-- ==========================================================================
-- Frame propio + puntos
-- ==========================================================================
-- "root" (posicion, SIEMPRE escala 1) + "content" (hijo, escala real) --
-- pedido del usuario 2026-07-19: "aumentar la escala lo esta desplazando".
-- SetPoint aplica el offset multiplicado por la escala PROPIA del frame que
-- lo llama -- si scale se aplicaba directo sobre el frame posicionado, subir
-- la escala tambien agrandaba el offsetX/Y guardado, "corriendo" el ancla en
-- vez de solo agrandar el contenido. Separando ambos, root nunca cambia de
-- escala (el ancla queda fija) y content (con todos los puntos adentro) es
-- el unico que crece/encoge alrededor de su propio centro.
local root, content, points
local currentLayout

local function P_DB() return ns.GetDB() and ns.GetDB().classpower end

local function CreateRoot()
    if root then return root end
    root = CreateFrame("Frame", "MyCF_ClassPower", UIParent)
    root:SetSize(124, 168)
    root:Hide()
    root:SetMovable(true)
    root:RegisterForDrag("LeftButton")
    root:EnableMouse(false)

    -- Mover/escalar desde el Lock (pedido del usuario 2026-07-20: "me
    -- gustaria que en el lock me salga el class power, para poder moverlo y
    -- escalarlo... recuerda el escalado no reposicione"). El offset se
    -- guarda en el espacio de ROOT (nunca se escala el mismo, ver el
    -- comentario grande arriba de esta seccion) -- por eso NO hace falta
    -- ns.CompensateScale aca: "scale" solo agranda/encoge "content" (hijo),
    -- el ancla de root queda siempre fija sin importar el valor de escala.
    local editBG = ns.MakeEditHighlight(root, "Class Power")
    root.editBG = editBG

    root:SetScript("OnDragStart", function(self)
        if ns.IsUnlocked() and not InCombatLockdown() then self:StartMoving() end
    end)
    root:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if ns.SnapFrameToGrid then ns.SnapFrameToGrid(self) end
        local p = P_DB()
        if p then
            local parent = _G[p.anchorFrame]
            if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
            local s, ps = self:GetEffectiveScale(), parent:GetEffectiveScale()
            local fx, fy = self:GetCenter(); local px, py = parent:GetCenter()
            if fx and px then
                p.point, p.relativePoint = "CENTER", "CENTER"
                p.offsetX = (fx * s - px * ps) / s
                p.offsetY = (fy * s - py * ps) / s
            end
        end
        -- ns.RefreshClassPower (no el local "Refresh"): esta closure se
        -- ESCRIBE antes de que "local function Refresh" exista mas abajo en
        -- el archivo -- Lua resuelve upvalues por posicion TEXTUAL, asi que
        -- un "Refresh()" directo aca apuntaria al global (nil). La tabla
        -- ns.* se resuelve recien al LLAMARSE, sin ese problema de orden.
        if ns.RefreshClassPower then ns.RefreshClassPower() end
        if ns.OnDragStopped then ns.OnDragStopped("classpower") end
    end)
    ns.AttachScaleWheel(root, P_DB, function() if ns.RefreshClassPower then ns.RefreshClassPower() end end)

    content = CreateFrame("Frame", nil, root)
    content:SetAllPoints()
    points = {}
    for i = 1, 7 do
        local b = CreateFrame("Frame", nil, content)
        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        b.bg = bg
        local icon = b:CreateTexture(nil, "ARTWORK")
        b.icon = icon
        -- Cooldown widget (solo lo usa el modo Runas -- ver UpdateRunes --
        -- pero se crea siempre en los 7 slots, mismo patron que bg/icon;
        -- inerte/oculto para el resto de los recursos).
        local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
        cd:SetAllPoints()
        cd:SetHideCountdownNumbers(true)
        cd:SetDrawBling(false)
        cd:Hide()
        b.cd = cd
        b:Hide()
        points[i] = b
    end
    return root
end

-- PERF (2026-07-19, "arregla todo"): Refresh() (y por lo tanto ApplyPosition)
-- se llama en UNIT_POWER_FREQUENT, que dispara MUY seguido con regen de
-- energia/foco/etc -- antes reaplicaba ClearAllPoints/SetPoint/SetFrameStrata/
-- SetScale SIEMPRE aunque el anchor/offset/scale de la config no hayan
-- cambiado un pelo desde la ultima vez. Cachea la ultima config aplicada y
-- saltea el relayout si es identica.
local function ApplyPosition()
    local p = P_DB(); if not (root and p) then return end
    local point, relativePoint = p.point or "CENTER", p.relativePoint or "CENTER"
    local offsetX, offsetY = p.offsetX or 220, p.offsetY or -160
    local strata, scale = p.strata or "MEDIUM", p.scale or 1
    local anchorName = p.anchorFrame or ""
    if root._mcfLastPoint == point and root._mcfLastRelPoint == relativePoint
        and root._mcfLastOffX == offsetX and root._mcfLastOffY == offsetY
        and root._mcfLastStrata == strata and root._mcfLastScale == scale
        and root._mcfLastAnchorName == anchorName then
        return
    end
    root._mcfLastPoint, root._mcfLastRelPoint = point, relativePoint
    root._mcfLastOffX, root._mcfLastOffY = offsetX, offsetY
    root._mcfLastStrata, root._mcfLastScale, root._mcfLastAnchorName = strata, scale, anchorName

    root:ClearAllPoints()
    local anchor = (anchorName ~= "" and _G[anchorName]) or UIParent
    root:SetPoint(point, anchor, relativePoint, offsetX, offsetY)
    root:SetFrameStrata(strata)
    content:SetScale(scale)
end

local function LayoutPoints(layoutName, colorKey)
    local p = P_DB(); if not p then return end
    local defs = LAYOUTS[layoutName]
    if not defs then return end
    local lit = (p.useClassColor ~= false) and POINT_COLOR[colorKey] or { r = 1, g = 1, b = 1 }
    local case = p.caseColor or { r = 211 / 255, g = 200 / 255, b = 169 / 255 }
    for i = 1, 7 do
        local b = points[i]
        local d = defs[i]
        if d then
            b:ClearAllPoints()
            -- root (no content) a proposito: root nunca escala, es la
            -- esquina FIJA desde la que se miden los offsets de diseño --
            -- b hereda la escala de content igual, asi que el offset SI
            -- crece/encoge con la escala, solo que sin mover el ancla.
            b:SetPoint("TOPLEFT", root, "TOPLEFT", d.x, d.y)
            b:SetSize(d.w, d.h)
            b.bg:ClearAllPoints()
            b.bg:SetPoint("CENTER", b, "CENTER", 0, 0)
            b.bg:SetSize(d.bw, d.bh)
            b.bg:SetTexture(ResolveTex(d.btex))
            b.bg:SetVertexColor(case.r, case.g, case.b)
            b.icon:SetAllPoints()
            b.icon:SetTexture(ResolveTex(d.tex))
            b.icon:SetVertexColor(lit.r, lit.g, lit.b)
            if d.rot then
                pcall(b.icon.SetRotation, b.icon, d.rot)
                pcall(b.bg.SetRotation, b.bg, d.rot)
            end
            -- Reset del cooldown al reconstruir el layout (ej. cambio de
            -- spec DK -> otra clase): sin esto, un swipe de runa podria
            -- quedar pegado sobre un punto que ahora es combo point/etc.
            if b.cd then b.cd:Hide() end
            b:Show()
        else
            b:Hide()
        end
    end
    currentLayout = layoutName
end

-- ==========================================================================
-- Update: puntos simples (combo points, holy power, chi, soul shards,
-- arcane charges, essence, soul fragments) -- prender/apagar segun UnitPower
-- actual.
-- ==========================================================================
local function UpdateSimplePoints(powerType)
    local p = P_DB(); if not p then return end
    local ok, cur = pcall(UnitPower, "player", powerType)
    if not ok or type(cur) ~= "number" or (issecretvalue and issecretvalue(cur)) then cur = 0 end
    local dim = p.dimAlpha or 0.35
    for i = 1, 7 do
        local b = points[i]
        if b:IsShown() then
            b:SetAlpha(i <= cur and 1 or dim)
        end
    end
    root:SetShown(cur > 0 or true) -- el "case"/backdrop queda visible siempre que haya recurso activo
end

-- ==========================================================================
-- Update: Runas de Death Knight -- 6 cooldowns INDEPENDIENTES (no un simple
-- "cur/max" como el resto), via GetRuneCooldown(i). Alpha siempre llena
-- (visible), con un swipe de cooldown oscuro encima mientras recarga -- asi
-- se ve el PROGRESO de recarga, no solo on/off.
-- ==========================================================================
local function UpdateRunes()
    local p = P_DB(); if not p then return end
    for i = 1, 6 do
        local b = points[i]
        if b:IsShown() then
            b:SetAlpha(1)
            local ok, start, duration, ready = pcall(GetRuneCooldown, i)
            if b.cd then
                if ok and not ready and type(start) == "number" and type(duration) == "number" and duration > 0 then
                    pcall(b.cd.SetCooldown, b.cd, start, duration)
                    b.cd:Show()
                else
                    b.cd:Hide()
                end
            end
        end
    end
    root:Show()
end

-- ==========================================================================
-- Update: Maelstrom Weapon (Shaman Enhancement) -- stacks del buff propio,
-- NO un UnitPower (ver GetMaelstromStacks). Mismo prendido/apagado binario
-- que UpdateSimplePoints, pero leyendo el aura en vez de UnitPower.
-- ==========================================================================
local function UpdateMaelstrom()
    local p = P_DB(); if not p then return end
    local stacks = GetMaelstromStacks()
    local dim = p.dimAlpha or 0.35
    for i = 1, 7 do
        local b = points[i]
        if b:IsShown() then
            b:SetAlpha(i <= stacks and 1 or dim)
            if b.cd then b.cd:Hide() end
        end
    end
    root:Show()
end

-- ==========================================================================
-- Refresh completo: re-detecta el recurso activo (cambia con spec/forma) y
-- re-arma el layout si cambio. Se llama en PLAYER_ENTERING_WORLD,
-- PLAYER_SPECIALIZATION_CHANGED, UPDATE_SHAPESHIFT_FORM, cada UNIT_POWER,
-- RUNE_POWER_UPDATE (Death Knight) y UNIT_AURA (Shaman Enhancement).
-- ==========================================================================
local function Refresh()
    local p = P_DB()
    local unlocked = ns.IsUnlocked()
    -- "Enabled=false" (o sin perfil todavia) solo oculta DEFINITIVO fuera de
    -- Lock -- en Lock se sigue mostrando (con outline) para poder
    -- posicionarlo/escalarlo sin tener que activarlo primero (pedido del
    -- usuario 2026-07-20).
    if not p or p.enabled == false then
        if not unlocked then if root then root:Hide() end; return end
        CreateRoot()
        if not p then root:Hide(); return end
    else
        CreateRoot()
    end
    ApplyPosition()
    root.editBG:SetShown(unlocked and not (ns.GetDB() and ns.GetDB().hideEditOutline))
    root:EnableMouse(unlocked)

    local layoutName, powerType, colorKey = DetectResource()
    -- Pedido del usuario: "si la clase no tiene, aun salga el outline, pero
    -- quiero controlarlo desde el lock" -- una clase sin recurso soportado
    -- no detecta layout -- en Lock se usa un layout de MUESTRA (ComboPoints,
    -- 5 puntos) solo para poder ver/mover/escalar el marco, igual criterio
    -- que el preview de otros elementos del addon.
    if not layoutName then
        if not unlocked then root:Hide(); return end
        layoutName, colorKey = "ComboPoints", "COMBO_POINTS"
    end
    if layoutName ~= currentLayout then LayoutPoints(layoutName, colorKey) end
    root:Show()

    if not powerType then
        -- Rama de muestra (sin recurso real detectado, solo en Lock): puntos
        -- a mitad de alpha, sin actualizacion dinamica -- es un placeholder
        -- de posicion, no datos reales.
        local dim = (p and p.dimAlpha) or 0.35
        for i = 1, 5 do
            local b = points[i]
            if b:IsShown() then b:SetAlpha(dim); if b.cd then b.cd:Hide() end end
        end
        return
    end
    -- "powerType" duplica como SENTINEL para Runas/Maelstrom (no son
    -- Enum.PowerType reales, ver DetectResource) -- rutea a la funcion de
    -- update correcta segun cual sea.
    if powerType == "RUNES" then
        UpdateRunes()
    elseif powerType == "MAELSTROM_WEAPON" then
        UpdateMaelstrom()
    else
        UpdateSimplePoints(powerType)
    end
end
ns.RefreshClassPower = Refresh
-- Fuerza un re-layout completo aunque el layout detectado no haya cambiado
-- (usado por el menu cuando cambian color/case, que LayoutPoints aplica pero
-- Refresh() solo llama si currentLayout cambio).
ns.ClassPowerForceRelayout = function() currentLayout = nil; Refresh() end
-- "classpower" como elemento SINGLETON del menu (como aura_party) -- una
-- sola entrada, sin edicion por-unidad.
ns.IsClassPower = function(key) return key == "classpower" end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
ev:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
ev:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
ev:RegisterUnitEvent("UNIT_MAXPOWER", "player")
ev:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
-- Death Knight (runas): evento dedicado, mas preciso que esperar el proximo
-- UNIT_POWER generico.
ev:RegisterEvent("RUNE_POWER_UPDATE")
-- Shaman Enhancement (Maelstrom Weapon): NO es un UnitPower, asi que ningun
-- evento UNIT_POWER_* lo dispara -- se necesita UNIT_AURA para enterarse de
-- cambios de stacks del buff.
ev:RegisterUnitEvent("UNIT_AURA", "player")
ev:SetScript("OnEvent", function() Refresh() end)

SLASH_MCFCLASSPOWERDIAG1 = "/mcfclasspowerdiag"
SlashCmdList["MCFCLASSPOWERDIAG"] = function()
    local layoutName, powerType, colorKey = DetectResource()
    print(("|cff00ff00[MCF classpower]|r layout=%s powerType=%s colorKey=%s currentLayout=%s"):format(
        tostring(layoutName), tostring(powerType), tostring(colorKey), tostring(currentLayout)))
    if layoutName then
        local ok, cur, max = pcall(function() return UnitPower("player", powerType), UnitPowerMax("player", powerType) end)
        print("  ok=" .. tostring(ok) .. " cur=" .. tostring(cur) .. " max=" .. tostring(max))
    end
end
