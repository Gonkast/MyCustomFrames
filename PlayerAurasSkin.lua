local ADDON, ns = ...

-- ==========================================================================
-- MyCustomFrames - PlayerAurasSkin.lua
--
-- Reskin del BuffFrame/DebuffFrame NATIVOS de Blizzard (2026-08-05, pedido
-- del usuario: "reskinear tambien el buff frame y debuff frame de la misma
-- forma" que ActionBarsSkin.lua). Mismo criterio cosmetico-solamente que
-- ese archivo, PERO esto es mas delicado: BuffFrame/DebuffFrame usan el
-- mismo widget AuraContainer que ya nos dio problemas en nameplates, con
-- valores SECRETOS (ancho/alto del boton, expirationTime) bajo 12.1.0.
--
-- REGLAS DE ORO -- copiadas del codigo REAL de EllesmereUIUnitFrames
-- (EllesmereUIUnitFrames_PlayerAuras.lua, leido en vivo, no adivinado --
-- ver comentarios ahi mismo con la historia completa de cada una):
--   1. NUNCA llamar BuffFrame:Update()/UpdateGridLayout()/
--      RefreshConsolidationFrameVisibility() nosotros -- eso tainea la
--      cadena de Blizzard, y su UpdateExpirationTime interna compara un
--      expirationTime SECRETO -- 2000+ errores y lag pesado en combate de
--      raid (confirmado en vivo por ellos). Solo ENGANCHAMOS esas funciones
--      con hooksecurefunc (corre DESPUES, sin taintear) -- nunca las
--      llamamos.
--   2. NUNCA medir el boton con GetWidth()/SetAllPoints(boton) -- su tamaño
--      es SECRETO en Midnight, y cualquier aritmetica (incluida la que hace
--      BackdropTemplate internamente) explota. El tamaño nativo es una
--      CONSTANTE conocida (32px boton / 30px icono visible) -- se usa fija,
--      nunca leida del frame real.
--   3. Ocultar el borde nativo con SetAlpha(0), NUNCA :Hide() (mismo motivo
--      de taint).
--   4. Iterar frame.auraFrames (tabla real de botones activos), no nombres
--      fijos como ActionButton1-12 -- BuffFrame/DebuffFrame poolean sus
--      botones, no tienen una cantidad fija.
-- ==========================================================================

local A = "Interface\\AddOns\\MyCustomFrames\\Assets\\"
local BORDER_TEX = A .. "actionbutton-border square.tga"
local BORDER_SCALE = 0.26
-- Constante nativa (2026-08-05, NUNCA leida del frame real -- ver regla #2
-- arriba): boton de aura nativo mide 32px, icono visible 30px.
local BLIZZARD_AURA_ICON_SIZE = 30
local ICON_ZOOM = 0.08

-- Encuentra la textura de icono real dentro de btn.Icon -- puede ser un
-- Frame con una sub-textura (.Icon o .icon) o directamente una Texture
-- (variaba entre builds, mismo hallazgo que EllesmereUI documenta).
local function FindIconTexture(btn)
    local iconFrame = btn.Icon
    if not iconFrame then return nil end
    if iconFrame.Icon and iconFrame.Icon.SetTexCoord then return iconFrame.Icon end
    if iconFrame.icon and iconFrame.icon.SetTexCoord then return iconFrame.icon end
    if iconFrame.SetTexCoord then return iconFrame end
    return nil
end

-- Reskinea UN boton de aura -- idempotente (border propio cacheado en
-- btn._mcfBorder, se reusa/reposiciona en vez de crear de nuevo).
local function SkinAuraButton(btn)
    if not btn or not btn.Icon or btn.isAuraAnchor then return end

    local iconTex = FindIconTexture(btn)
    if iconTex then
        iconTex:SetTexCoord(ICON_ZOOM, 1 - ICON_ZOOM, ICON_ZOOM, 1 - ICON_ZOOM)
    end

    -- Borde nativo: alpha 0, nunca Hide() (regla #3).
    if btn.DebuffBorder then btn.DebuffBorder:SetAlpha(0) end

    -- Borde propio -- tamaño FIJO (regla #2), anclado al CENTRO de
    -- btn.Icon en vez de SetAllPoints(btn) -- mismo patron/asset que
    -- ActionBarsSkin.lua para consistencia visual con el resto del preset.
    local border = btn._mcfBorder
    if not border then
        border = CreateFrame("Frame", nil, btn)
        border:EnableMouse(false)
        local tex = border:CreateTexture(nil, "OVERLAY")
        tex:SetTexture(BORDER_TEX)
        tex:SetAllPoints(border)
        border.tex = tex
        btn._mcfBorder = border
    end
    local inset = BLIZZARD_AURA_ICON_SIZE * BORDER_SCALE
    border:ClearAllPoints()
    border:SetPoint("CENTER", btn.Icon, "CENTER", 0, 0)
    border:SetSize(BLIZZARD_AURA_ICON_SIZE + inset * 2, BLIZZARD_AURA_ICON_SIZE + inset * 2)
end

-- Recorre frame.auraFrames (regla #4) -- pcall por boton, un error en uno
-- no debe cortar el resto.
local function SkinAllButtons(frame)
    if not frame or not frame.auraFrames then return end
    for _, btn in pairs(frame.auraFrames) do
        pcall(SkinAuraButton, btn)
    end
end

-- Coalescido a 1 pasada por frame (regla #1: nunca dentro del propio hook,
-- que puede correr adentro de la cadena secure de Blizzard -- diferido con
-- C_Timer.After(0, ...) para salir de ese contexto antes de tocar nada).
local refreshPending = false
local function RequestRefresh()
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0, function()
        refreshPending = false
        SkinAllButtons(BuffFrame)
        SkinAllButtons(DebuffFrame)
    end)
end

local function BartenderLoaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Bartender4")
end

-- Mismo gate que ActionBarsSkin.lua (2026-08-05, "de la misma forma") --
-- Bartender4 no toca BuffFrame/DebuffFrame en absoluto (son un sistema
-- aparte de las action bars), pero el pedido explicito fue "de la misma
-- forma" que el reskin de barras, asi que se mantiene el mismo gate por
-- consistencia -- si en el futuro se decide que esto debe ir siempre
-- activo sin importar Bartender4, alcanza con borrar este chequeo.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if BartenderLoaded() then return end
    C_Timer.After(1, function()
        -- Enganches (regla #1) -- NUNCA se llama BuffFrame:Update()/
        -- UpdateGridLayout()/RefreshConsolidationFrameVisibility() desde
        -- este addon, solo se engancha para reaccionar DESPUES de que
        -- Blizzard ya corrio su propia pasada (sin taint).
        if BuffFrame and BuffFrame.AuraContainer then
            hooksecurefunc(BuffFrame.AuraContainer, "UpdateGridLayout", RequestRefresh)
        end
        if DebuffFrame and DebuffFrame.AuraContainer then
            hooksecurefunc(DebuffFrame.AuraContainer, "UpdateGridLayout", RequestRefresh)
        end
        RequestRefresh()
    end)
end)
