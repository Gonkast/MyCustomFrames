-- ==========================================================================
-- MyCustomFrames - MicroMenu.lua
-- MICRO MENU: reskin de los micro-botones SEGUROS de Blizzard (movible + escalable).
-- Extraido de core.lua (el chunk principal excedia el limite de 200 locals de Lua).
-- Reutiliza los botones seguros de Blizzard (ya abren cada panel); solo se les cambia
-- el arte por iconos custom y se reagrupan en un contenedor propio. SIN fondo.
-- Carga DESPUES de core.lua en el toc: usa ns.GetDB / ns.IsUnlocked /
-- ns.MakeEditHighlight / ns.AttachScaleWheel / ns.CompensateScale / ns.SnapFrameToGrid.
-- El ticker principal (core) re-afirma el arte via ns.MM_ReassertArt.
-- ==========================================================================
local ADDON, ns = ...

local MICROMENU_KEY = "micromenu"
ns.MICROMENU_KEY = MICROMENU_KEY
ns.IsMicroMenu = function(key) return key == MICROMENU_KEY end

local MM_PATH = "Interface\\AddOns\\" .. ADDON .. "\\Assets\\"
local MM_BTN_W, MM_BTN_H, MM_SPACING, MM_ICON = 41, 46, 2, 32
local MM_ART_KEYS = { "Background", "PushedBackground", "FlashBorder", "FlashContent", "Flash",
    "Emblem", "HighlightEmblem", "MainMenuBarPerformanceBar", "NotificationOverlay", "Shadow", "PushedShadow" }
-- Orden en la fila + icono por boton (se usan solo los que existan en el cliente).
local MM_BUTTONS = {
    { "ProfessionMicroButton",   "02_crossed_hammers.tga" },
    { "ProfessionsMicroButton",  "02_crossed_hammers.tga" },
    { "SpellbookMicroButton",    "03_target_dart.tga" },
    { "PlayerSpellsMicroButton", "03_target_dart.tga" },
    { "TalentMicroButton",       "03_target_dart.tga" },
    { "AchievementMicroButton",  "04_shield.tga" },
    { "QuestLogMicroButton",     "05_exclamation.tga" },
    { "HousingMicroButton",      "06_home.tga" },
    { "GuildMicroButton",        "07_bookmark.tga" },
    { "LFDMicroButton",          "08_eye.tga" },
    { "CollectionsMicroButton",  "09_horseshoe.tga" },
    { "EJMicroButton",           "10_skull_banner.tga" },
    { "StoreMicroButton",        "11_w_emblem.tga" },
    { "MainMenuMicroButton",     "12_question_mark.tga" },
    { "HelpMicroButton",         "12_question_mark.tga" },
}
-- Micro-botones que NO queremos VER en el menu. OJO: NO se ocultan con Hide(). El portrait del
-- player abre el panel de personaje en COMBATE haciendo un clic SEGURO sobre CharacterMicroButton
-- (unica via: abrir un UIPanel en combate exige ejecucion segura de Blizzard, no vale ToggleCharacter
-- inseguro → "Interface action failed"). Un boton OCULTO no dispara su OnClick al hacer :Click(), asi
-- que lo dejamos MOSTRADO pero INVISIBLE (alpha 0) y sin raton (EnableMouse false, no intercepta).
-- NO se reparenta (SetParent desde codigo inseguro TAINTEA el boton → su ShowUIPanel se bloquearia
-- en combate). Solo alpha/mouse/icono, que NO taintean.
local MM_HIDE = { "CharacterMicroButton" }

local function MicroMenuDefaults()
    return { enabled = true, strata = "MEDIUM", scale = 1.0,
        anchor = "", point = "CENTER", relPoint = "CENTER", offsetX = 0, offsetY = -220 }
end
ns.MicroMenuDefaults = MicroMenuDefaults

local micromenu  -- frame contenedor (MyCF_MicroMenu)

-- Deja el micro-boton clickeable-en-seguro pero invisible (ver MM_HIDE). Idempotente y taint-free.
-- OJO: el comando "/click" (y por extension nuestro overlay type1=macro→"/click CharacterMicroButton")
-- EXIGE que el frame tenga `IsMouseEnabled()==true` — si no, /click no hace NADA (fallo silencioso,
-- diagnosticado con /mcfchar: alpha=0 estaba bien pero mouseEnabled=false mataba el clic). Por eso
-- EnableMouse se deja en TRUE; el boton sigue sin robar clics reales porque esta INVISIBLE (alpha 0)
-- y Blizzard no le movio la posicion (sigue en su sitio de siempre, fuera del area visible del addon).
local function MM_SoftHide(b)
    if not b then return end
    if b._mmIcon then b._mmIcon:Hide() end
    pcall(function()
        b:SetAlpha(0)
        b:EnableMouse(true)    -- REQUERIDO por /click (ver nota arriba); invisible, no molesta
        b:Show()               -- MOSTRADO (invisible) → :Click() dispara su OnClick (abre en combate)
    end)
end

-- Oculta una textura NATIVA de Blizzard sin tocar su estado real (patron EllesmereUI: "hide via
-- SetTexture(\"\") only — SetTexture(nil) and SetAlpha(0) both taint Blizzard-owned textures.
-- Tainted widget-pool textures cause arithmetic errors when the pool reuses them elsewhere").
-- SetTexture("") = queda sin archivo → no dibuja nada, sin Hide()/SetAlpha() (que si taintean si
-- Blizzard reutiliza ese mismo objeto Texture en otro widget mas adelante). Solo se ESCRIBE, nunca
-- se lee el estado de vuelta.
local function MM_HideTex(t)
    if t and t.SetTexture then pcall(t.SetTexture, t, "") end
end

local function MM_HideOriginalArt(b)
    for _, k in ipairs(MM_ART_KEYS) do MM_HideTex(b[k]) end
    MM_HideTex(b.GetNormalTexture and b:GetNormalTexture())
    MM_HideTex(b.GetPushedTexture and b:GetPushedTexture())
    MM_HideTex(b.GetDisabledTexture and b:GetDisabledTexture())
    MM_HideTex(b.GetHighlightTexture and b:GetHighlightTexture())
    if type(MicroButtonPulseStop) == "function" then pcall(MicroButtonPulseStop, b) end
end

-- Re-aplica el skin: Blizzard vuelve a poner su arte al actualizar el boton.
local function MM_RefreshArt(b)
    MM_HideOriginalArt(b)
    if b._mmIcon then b._mmIcon:Show() end
end

local function MM_SkinButton(b, iconFile)
    b:SetSize(MM_BTN_W, MM_BTN_H)
    MM_HideOriginalArt(b)
    local icon = b._mmIcon
    if not icon then
        icon = b:CreateTexture(nil, "ARTWORK", nil, 2)
        icon:SetTexCoord(0, 1, 0, 1)
        b._mmIcon = icon
    end
    icon:ClearAllPoints(); icon:SetPoint("CENTER"); icon:SetSize(MM_ICON, MM_ICON)
    icon:SetTexture(MM_PATH .. iconFile); icon:Show()
    local hover = b._mmHover
    if not hover then
        hover = b:CreateTexture(nil, "HIGHLIGHT", nil, 3)
        hover:SetBlendMode("ADD"); hover:SetVertexColor(1, 1, 1, 0.28)
        b._mmHover = hover
    end
    hover:ClearAllPoints(); hover:SetPoint("CENTER"); hover:SetSize(MM_ICON, MM_ICON)
    hover:SetTexture(MM_PATH .. iconFile)
    if not b._mmHooked then
        b._mmHooked = true
        for _, m in ipairs({ "SetNormalAtlas", "SetPushedAtlas", "SetNormalTexture", "SetPushedTexture" }) do
            if type(b[m]) == "function" then pcall(hooksecurefunc, b, m, function() MM_RefreshArt(b) end) end
        end
    end
end

-- Reparent + skin + fila (operaciones PROTEGIDAS → solo fuera de combate).
local function MM_LayoutButtons()
    if not micromenu then return end
    local unlocked = ns.IsUnlocked()
    local x, n = 0, 0
    for _, e in ipairs(MM_BUTTONS) do
        local b = _G[e[1]]
        if b then
            if not b._mmOrigParent then b._mmOrigParent = b:GetParent() end
            b:SetParent(micromenu)
            MM_SkinButton(b, e[2])
            b:ClearAllPoints()
            b:SetPoint("LEFT", micromenu, "LEFT", x, 0)
            b:SetFrameLevel(micromenu:GetFrameLevel() + 2)
            -- En preview los botones no capturan el mouse, asi se puede arrastrar la fila.
            b:EnableMouse(not unlocked)
            b:Show()
            x = x + MM_BTN_W + MM_SPACING
            n = n + 1
        end
    end
    micromenu:SetSize(math.max(x - MM_SPACING, MM_BTN_W), MM_BTN_H)
    -- Micro-botones que no queremos VER (Character): invisibles pero clickeables en seguro.
    for _, name in ipairs(MM_HIDE) do
        MM_SoftHide(_G[name])
    end
    return n
end

-- Re-afirma el skin (por si Blizzard repuso su arte) y re-oculta los no deseados.
-- NO reparenta ni reposiciona (eso es protegido); solo texturas/visibilidad de arte.
local function MM_ReassertArt()
    local db = ns.GetDB()
    if not (micromenu and db and db.micromenu and db.micromenu.enabled) then return end
    for _, e in ipairs(MM_BUTTONS) do
        local b = _G[e[1]]
        if b and b._mmIcon then MM_RefreshArt(b) end
    end
    for _, name in ipairs(MM_HIDE) do
        MM_SoftHide(_G[name])
    end
end
ns.MM_ReassertArt = MM_ReassertArt

-- Devuelve los micro-botones a Blizzard (al desactivar). Blizzard re-aplica su
-- arte y posicion en UpdateMicroButtons.
local function MM_Restore()
    for _, e in ipairs(MM_BUTTONS) do
        local b = _G[e[1]]
        if b and b._mmOrigParent then
            b:SetParent(b._mmOrigParent)
            b:ClearAllPoints()
            if b._mmIcon then b._mmIcon:Hide() end
            if b._mmHover then b._mmHover:Hide() end
        end
    end
    if micromenu then micromenu:Hide() end
    if type(UpdateMicroButtons) == "function" then pcall(UpdateMicroButtons) end
    if MicroMenu and MicroMenu.Layout then pcall(MicroMenu.Layout, MicroMenu) end
end

local function MM_Place()
    local p = ns.GetDB().micromenu
    if ns.CompensateScale then ns.CompensateScale(p, "simple") end   -- B3: reancla offset si la escala cambio
    local parent = _G[p.anchor]
    if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
    micromenu:ClearAllPoints()
    micromenu:SetPoint(p.point, parent, p.relPoint, p.offsetX, p.offsetY)
    micromenu:SetScale(p.scale or 1)
    micromenu:SetFrameStrata(p.strata)
    micromenu:SetShown(p.enabled or ns.IsUnlocked())
end

local function RefreshMicroMenu()
    local db = ns.GetDB()
    if not (micromenu and db and db.micromenu) then return end
    -- Reparent/posicion/escala/visibilidad tocan frames PROTEGIDOS → diferir en combate.
    if InCombatLockdown() then micromenu.needsLayout = true; return end
    micromenu.needsLayout = nil
    if db.micromenu.enabled or ns.IsUnlocked() then
        MM_LayoutButtons()
        MM_Place()
    else
        MM_Restore()
    end
    if micromenu.editBG then micromenu.editBG:SetShown(ns.IsUnlocked() and not db.hideEditGreen) end
end
ns.RefreshMicroMenu = RefreshMicroMenu

local function CreateMicroMenu()
    local root = CreateFrame("Frame", "MyCF_MicroMenu", UIParent)
    root:SetSize(200, MM_BTN_H)
    root:SetPoint("CENTER", UIParent, "CENTER", 0, -220)
    root:SetMovable(true)
    root:RegisterForDrag("LeftButton")
    root:EnableMouse(false)

    local editBG = ns.MakeEditHighlight(root, "Micro Menu")
    root.editBG = editBG

    root:SetScript("OnDragStart", function(self)
        if ns.IsUnlocked() and not InCombatLockdown() then self:StartMoving() end
    end)
    root:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if ns.SnapFrameToGrid then ns.SnapFrameToGrid(self) end
        local p = ns.GetDB().micromenu
        local parent = _G[p.anchor]
        if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
        local s, ps = self:GetEffectiveScale(), parent:GetEffectiveScale()
        local fx, fy = self:GetCenter(); local px, py = parent:GetCenter()
        if fx and px then
            p.point, p.relPoint = "CENTER", "CENTER"
            p.offsetX = (fx * s - px * ps) / s
            p.offsetY = (fy * s - py * ps) / s
        end
        RefreshMicroMenu()
        if ns.OnDragStopped then ns.OnDragStopped(MICROMENU_KEY) end
    end)
    ns.AttachScaleWheel(root, function() return ns.GetDB().micromenu end, function() if ns.RefreshMicroMenu then ns.RefreshMicroMenu() end end)

    micromenu = root
    ns.micromenu = root

    local function MM_Active(b)
        local db = ns.GetDB()
        return b and b._mmIcon and micromenu and db and db.micromenu
            and db.micromenu.enabled and not ns.IsUnlocked()
    end

    -- Blizzard re-coloca/re-arte los micro-botones al actualizarlos: re-afirmar.
    if type(UpdateMicroButtons) == "function" then
        hooksecurefunc("UpdateMicroButtons", function()
            if MM_Active(_G.MainMenuMicroButton) and not InCombatLockdown() then
                MM_LayoutButtons()
            end
        end)
    end

    -- FLASH / PULSE de "novedad" (nueva habilidad, etc.) re-muestra el arte
    -- original parpadeando. Lo cortamos: paramos el pulse y re-ocultamos el arte.
    if type(MicroButtonPulse) == "function" then
        hooksecurefunc("MicroButtonPulse", function(b)
            if MM_Active(b) then
                if type(MicroButtonPulseStop) == "function" then pcall(MicroButtonPulseStop, b) end
                MM_RefreshArt(b)
            end
        end)
    end
    -- Algunos alerts animan un FlashBorder propio; hookeamos el mostrar del alert.
    if type(MainMenuMicroButton_ShowAlert) == "function" then
        hooksecurefunc("MainMenuMicroButton_ShowAlert", function(b)
            if MM_Active(b) then MM_RefreshArt(b) end
        end)
    end
end

CreateMicroMenu()
