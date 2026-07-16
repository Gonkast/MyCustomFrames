-- ==========================================================================
-- MyCustomFrames - Glow.lua
-- ASSISTED GLOW (glow custom sobre el highlight de la rotacion asistida).
-- Extraido de core.lua (el chunk principal excedia el limite de 200 locals de Lua).
-- Blizzard resalta el boton que el "Assisted Combat" recomienda pulsar; aqui lo
-- reemplazamos por un glow configurable. APIs (verificadas en Midnight):
--   C_AssistedCombat.GetNextCastSpell(onlyVisible) -> spellID recomendado
--   C_AssistedCombat.GetActionSpell()             -> hechizo de accion actual
--   C_ActionBar.FindSpellActionButtons(spellID)   -> slots que tienen la magia
--   CVar "assistedCombatHighlight" = "0" apaga el highlight nativo
-- SECRET-SAFE: el spellID PUEDE ser secreto -> SafeSid() lo descarta antes de
-- cualquier comparacion (comparar un secreto crashea). El glow usa un overlay
-- NO seguro parentado al boton (patron LibCustomGlow): visual puro, sin taint.
-- LibCustomGlow es OPCIONAL (pixel/autocast/button); si falta, cae a "Border".
-- Carga DESPUES de core.lua en el toc (usa ns.ASSETS / ns.GetDB).
-- ==========================================================================
local ADDON, ns = ...

local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)
local GLOW_STYLES = { "Texture", "Border", "Pixel Glow", "AutoCast", "Button Glow" }
ns.GLOW_STYLES = GLOW_STYLES
local GLOW_TEX_DEFAULT = (ns.ASSETS or "") .. "actionbuttonhighlight.tga"
ns.HasLCG = LCG and true or false

local GetCVarFn = (C_CVar and C_CVar.GetCVar) or GetCVar
local SetCVarFn = (C_CVar and C_CVar.SetCVar) or SetCVar

local function GlowDefaults()
    return {
        enabled = false,          -- opt-in (no molesta hasta activarlo)
        disableNative = true,     -- apaga el highlight de hormigas de Blizzard
        style = "Texture",        -- Texture (actionbuttonhighlight) por defecto
        glowTexture = GLOW_TEX_DEFAULT,
        pulse = true,             -- latido de opacidad (solo estilo Texture)
        color = { r = 1, g = 0.85, b = 0.10 },
        alpha = 1.0,
        thickness = 4,
        scale = 1.1,
        onlyVisible = true,       -- GetNextCastSpell(onlyVisible)
        checkUsable = true,       -- no brillar si no hay recurso/CD
    }
end
ns.GlowDefaults = GlowDefaults

-- Descarta valores secretos ANTES de comparar (comparar un secreto crashea).
local function SafeSid(sid)
    if type(sid) ~= "number" then return nil end
    if issecretvalue and issecretvalue(sid) then return nil end
    if sid == 0 then return nil end
    return sid
end

-- ---- Cache de botones de accion (barras Blizzard + LibActionButton) ----
local glowBtnCache = {}
local glowCacheBuilt = false
local function GlowBuildButtonCache()
    wipe(glowBtnCache)
    -- LibActionButton estandar + el fork de AzeriteUI (-GE).
    for _, libName in ipairs({ "LibActionButton-1.0", "LibActionButton-1.0-GE" }) do
        local LAB = LibStub and LibStub(libName, true)
        if LAB and type(LAB.buttonRegistry) == "table" then
            for btn in pairs(LAB.buttonRegistry) do glowBtnCache[btn] = true end
        end
    end
    -- Barras nativas de Blizzard.
    local prefixes = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
        "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button" }
    for _, pfx in ipairs(prefixes) do
        for i = 1, 12 do local b = _G[pfx .. i]; if b then glowBtnCache[b] = true end end
    end
    glowCacheBuilt = true
end

local function GlowActionSpell(action)
    if not action or action == 0 then return nil end
    local t, id = GetActionInfo(action)
    if t == "spell" then return id
    elseif t == "macro" then return (GetMacroSpell(id)) end
    return nil
end

-- Encuentra el/los botones que tienen 'sid' (sid ya es legible via SafeSid).
local glowSlots = {}
local function GlowFindButtons(sid, out)
    wipe(out)
    if not sid then return out end
    wipe(glowSlots)
    if C_ActionBar and C_ActionBar.FindSpellActionButtons then
        local slots = C_ActionBar.FindSpellActionButtons(sid)
        if slots then for _, s in ipairs(slots) do glowSlots[s] = true end end
    end
    if not glowCacheBuilt then GlowBuildButtonCache() end
    for btn in pairs(glowBtnCache) do
        if btn.IsVisible and btn:IsVisible() then
            local action = btn._state_action or btn.action or (btn.GetAttribute and btn:GetAttribute("action"))
            if type(action) == "number" and action > 0 then
                if glowSlots[action] or GlowActionSpell(action) == sid then
                    out[#out + 1] = btn
                end
            end
        end
    end
    return out
end

-- Hechizo recomendado ahora mismo (o nil).
local function GlowNextSpell(p)
    local sid
    if C_AssistedCombat and C_AssistedCombat.GetNextCastSpell then
        local ok, s = pcall(C_AssistedCombat.GetNextCastSpell, p.onlyVisible and true or false)
        if ok then sid = SafeSid(s) end
    end
    if not sid and C_AssistedCombat and C_AssistedCombat.GetActionSpell then
        sid = SafeSid(C_AssistedCombat.GetActionSpell())
    end
    if not sid then return nil end
    if p.checkUsable and C_Spell and C_Spell.IsSpellUsable then
        local _, noResource = C_Spell.IsSpellUsable(sid)
        if noResource then return nil end
    end
    return sid
end

-- ---- Overlays de glow (uno por boton, pool perezoso) ----
local glowFrames = {}   -- btn -> frame overlay
local glowActive = {}   -- btn -> true (esta brillando)

local function GlowGetOverlay(btn)
    local f = glowFrames[btn]
    if not f then
        f = CreateFrame("Frame", nil, btn)
        f:SetFrameStrata("HIGH")
        f.borders = {}
        for i = 1, 4 do
            local t = f:CreateTexture(nil, "OVERLAY")
            t:SetTexture("Interface\\Buttons\\WHITE8x8")
            f.borders[i] = t
        end
        -- Textura unica para el estilo "Texture" (actionbuttonhighlight), aditiva,
        -- con un latido de opacidad (AnimationGroup Alpha en loop).
        local gt = f:CreateTexture(nil, "OVERLAY")
        gt:SetAllPoints(f)
        gt:SetBlendMode("ADD")
        gt:Hide()
        f.glowTex = gt
        local ag = gt:CreateAnimationGroup()
        ag:SetLooping("REPEAT")
        local a1 = ag:CreateAnimation("Alpha"); a1:SetFromAlpha(1); a1:SetToAlpha(0.35); a1:SetDuration(0.5); a1:SetOrder(1); a1:SetSmoothing("IN_OUT")
        local a2 = ag:CreateAnimation("Alpha"); a2:SetFromAlpha(0.35); a2:SetToAlpha(1); a2:SetDuration(0.5); a2:SetOrder(2); a2:SetSmoothing("IN_OUT")
        f.glowPulse = ag
        glowFrames[btn] = f
    end
    return f
end

-- Glow "Border" propio (sin lib): 4 lados. t = grosor.
local function GlowDrawBorder(f, t, r, g, b, a)
    local B = f.borders
    for _, tex in ipairs(B) do tex:SetVertexColor(r, g, b, a); tex:Show() end
    B[1]:ClearAllPoints(); B[1]:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0);   B[1]:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, -t)
    B[2]:ClearAllPoints(); B[2]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0); B[2]:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, t)
    B[3]:ClearAllPoints(); B[3]:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -t);  B[3]:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", t, t)
    B[4]:ClearAllPoints(); B[4]:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -t); B[4]:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", -t, t)
end

local function GlowStop(btn)
    local f = glowFrames[btn]
    if f then
        if LCG then LCG.PixelGlow_Stop(f); LCG.AutoCastGlow_Stop(f); LCG.ButtonGlow_Stop(f) end
        for _, tex in ipairs(f.borders) do tex:Hide() end
        if f.glowPulse then f.glowPulse:Stop() end
        if f.glowTex then f.glowTex:Hide() end
        f:Hide()
    end
    glowActive[btn] = nil
end

local function GlowStart(btn, p)
    local f = GlowGetOverlay(btn)
    if f:GetParent() ~= btn then f:SetParent(btn) end
    f:ClearAllPoints()
    f:SetPoint("CENTER", btn, "CENTER", 0, 0)
    f:SetFrameLevel(btn:GetFrameLevel() + 8)
    f:SetScale(p.scale or 1)
    local w, h = btn:GetWidth(), btn:GetHeight()
    local col = p.color or { r = 1, g = 0.85, b = 0.1 }
    local a = p.alpha or 1
    local arr = { col.r, col.g, col.b, a }
    local style = p.style or "Border"
    -- limpia estado previo
    if LCG then LCG.PixelGlow_Stop(f); LCG.AutoCastGlow_Stop(f); LCG.ButtonGlow_Stop(f) end
    for _, tex in ipairs(f.borders) do tex:Hide() end
    if f.glowPulse then f.glowPulse:Stop() end
    if f.glowTex then f.glowTex:Hide() end
    f:Show()
    if style == "Texture" then
        f:SetSize(w, h)
        local gt = f.glowTex
        gt:SetTexture((p.glowTexture and p.glowTexture ~= "" and p.glowTexture) or GLOW_TEX_DEFAULT)
        gt:SetVertexColor(col.r, col.g, col.b, a)
        gt:SetAlpha(1)
        gt:Show()
        if p.pulse and f.glowPulse then f.glowPulse:Play() end
    elseif LCG and style == "Pixel Glow" then
        f:SetSize(w + (p.thickness or 4) * 2, h + (p.thickness or 4) * 2)
        LCG.PixelGlow_Start(f, arr, nil, nil, nil, p.thickness or 4, nil, nil, false)
    elseif LCG and style == "AutoCast" then
        f:SetSize(w + (p.thickness or 4) * 2, h + (p.thickness or 4) * 2)
        LCG.AutoCastGlow_Start(f, arr)
    elseif LCG and style == "Button Glow" then
        f:SetSize(w, h)
        LCG.ButtonGlow_Start(f, arr)
    else
        f:SetSize(w, h)
        GlowDrawBorder(f, p.thickness or 4, col.r, col.g, col.b, a)
    end
    glowActive[btn] = true
end

-- Fuerza el CVar del highlight nativo (solo fuera de combate; no releer secretos).
local function GlowEnforceCVar(val)
    if InCombatLockdown() then return end
    if not GetCVarFn then return end
    local cur = GetCVarFn("assistedCombatHighlight")
    if cur ~= nil and tostring(cur) ~= val and SetCVarFn then
        pcall(SetCVarFn, "assistedCombatHighlight", val)
    end
end

local glowWanted = {}
local glowFound = {}
local function RefreshGlow(force)
    local db = ns.GetDB and ns.GetDB()
    if not (db and db.glow) then return end
    local p = db.glow
    if not p.enabled then
        for btn in pairs(glowActive) do GlowStop(btn) end
        return
    end
    if p.disableNative then GlowEnforceCVar("0") end
    if force then for btn in pairs(glowActive) do GlowStop(btn) end end

    local sid = GlowNextSpell(p)
    wipe(glowWanted)
    if sid then
        GlowFindButtons(sid, glowFound)
        for _, btn in ipairs(glowFound) do glowWanted[btn] = true end
    end
    -- apaga los que ya no aplican
    for btn in pairs(glowActive) do
        if not glowWanted[btn] then GlowStop(btn) end
    end
    -- enciende los nuevos (o todos, si force ya limpio glowActive)
    for btn in pairs(glowWanted) do
        if not glowActive[btn] then GlowStart(btn, p) end
    end
end
ns.RefreshGlow = RefreshGlow

-- Invalida el cache de botones cuando cambian barras/paginacion/especializacion.
local glowEvents = CreateFrame("Frame")
glowEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
glowEvents:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
glowEvents:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
glowEvents:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
glowEvents:SetScript("OnEvent", function() glowCacheBuilt = false end)

-- Ticker propio (la rotacion cambia constantemente; corre aunque estemos en preview).
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(0.1, function()
        local db = ns.GetDB and ns.GetDB()
        if db and db.glow and db.glow.enabled then RefreshGlow(false) end
    end)
end
