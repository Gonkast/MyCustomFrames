-- ==========================================================================
-- MyCustomFrames - MailBanner.lua
-- Header de correo nuevo (pedido del usuario 2026-07-21): "un header que salga
-- cuando tengo un mail, que se deslice suavemente hacia abajo". 3 fases estilo
-- WeakAuras (Start/Main/Finish, misma estructura que la referencia que paso el
-- usuario, https://wago.io/1wKfUxJ8U) sobre texturas 100% NATIVAS de Blizzard,
-- sin arte propio:
--   - Fondo: "Objective-Header-CampaignAlliance"/"...Horde" segun faccion.
--   - Icono en el borde: "communities-icon-invitemail".
-- START:  fondo+icono aparecen con fade-in MIENTRAS el banner se desliza hacia
--         abajo desde arriba de su posicion final (pedido explicito del usuario).
-- MAIN:   el icono pulsa en loop mientras el banner queda mostrado.
-- FINISH: el banner se desliza de vuelta hacia arriba mientras se desvanece,
--         y recien ahi se oculta.
-- Carga despues de Minimap.lua en el toc (reusa HasNewMail/UPDATE_PENDING_MAIL,
-- mismo patron de deteccion de "correo nuevo" que ya usa CreateMail alla).
-- ==========================================================================
local ADDON, ns = ...

-- Cuanto se desplaza (px) al entrar/salir. Anclado por "TOP": Y menos negativo
-- (mas cerca del 0) = mas arriba/afuera de pantalla; Y mas negativo = mas abajo,
-- hacia su posicion final. REST_Y es la posicion final de reposo del banner.
local REST_Y = -90
local SLIDE_DIST = 40
local MAIN_DURATION = 3.5

local banner = CreateFrame("Frame", "MCF_MailBanner", UIParent)
banner:SetFrameStrata("HIGH")
banner:Hide()

local bg = banner:CreateTexture(nil, "ARTWORK")
bg:SetPoint("CENTER")

-- Tamaño real del banner = tamaño nativo del atlas (useAtlasSize=true), para no
-- estirar/deformar la textura de Blizzard con un tamaño propio inventado.
local function ApplyFactionTexture()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    local atlas = (faction == "Horde") and "Objective-Header-CampaignHorde" or "Objective-Header-CampaignAlliance"
    bg:SetAtlas(atlas, true)
    local w, h = bg:GetSize()
    if w and w > 0 then banner:SetSize(w, h) end
end

-- Icono en el borde (pedido del usuario): borde IZQUIERDO del banner.
local icon = banner:CreateTexture(nil, "OVERLAY")
icon:SetAtlas("communities-icon-invitemail", true)
icon:SetPoint("LEFT", banner, "LEFT", 10, 0)

banner:SetPoint("TOP", UIParent, "TOP", 0, REST_Y + SLIDE_DIST)

-- ===================== START: fade-in + slide hacia abajo =====================
local startAnim = banner:CreateAnimationGroup()
local startFade = startAnim:CreateAnimation("Alpha")
startFade:SetFromAlpha(0); startFade:SetToAlpha(1)
startFade:SetDuration(0.4); startFade:SetSmoothing("OUT")
local startSlide = startAnim:CreateAnimation("Translation")
startSlide:SetOffset(0, -SLIDE_DIST)
startSlide:SetDuration(0.4); startSlide:SetSmoothing("OUT")

-- ===================== MAIN: el icono pulsa en loop =====================
local pulseAnim = icon:CreateAnimationGroup()
pulseAnim:SetLooping("BOUNCE")
local pulseScale = pulseAnim:CreateAnimation("Scale")
pulseScale:SetOrigin("CENTER", 0, 0)
pulseScale:SetScale(1.18, 1.18)
pulseScale:SetDuration(0.6); pulseScale:SetSmoothing("IN_OUT")

-- ===================== FINISH: fade-out + slide hacia arriba =====================
local finishAnim = banner:CreateAnimationGroup()
local finishFade = finishAnim:CreateAnimation("Alpha")
finishFade:SetFromAlpha(1); finishFade:SetToAlpha(0)
finishFade:SetDuration(0.4); finishFade:SetSmoothing("IN")
local finishSlide = finishAnim:CreateAnimation("Translation")
finishSlide:SetOffset(0, SLIDE_DIST)
finishSlide:SetDuration(0.4); finishSlide:SetSmoothing("IN")

startAnim:SetScript("OnFinished", function()
    banner:SetPoint("TOP", UIParent, "TOP", 0, REST_Y)
    pulseAnim:Play()
end)
finishAnim:SetScript("OnFinished", function()
    pulseAnim:Stop()
    banner:Hide()
end)

local hideTimer
local function ShowBanner()
    if not (bg.SetAtlas and icon.SetAtlas) then return end
    ApplyFactionTexture()
    banner:SetPoint("TOP", UIParent, "TOP", 0, REST_Y + SLIDE_DIST)
    banner:SetAlpha(0)
    banner:Show()
    finishAnim:Stop()
    pulseAnim:Stop()
    startAnim:Play()
    if hideTimer then hideTimer:Cancel() end
    hideTimer = C_Timer.NewTimer(MAIN_DURATION, function() finishAnim:Play() end)
end
ns.ShowMailBanner = ShowBanner

-- Mismo criterio de "flanco ascendente" que Minimap.lua usa para el flipbook del
-- icono (no re-dispara mientras el correo pendiente sigue siendo el mismo).
local hadMail = false
local ev = CreateFrame("Frame")
ev:RegisterEvent("UPDATE_PENDING_MAIL")
ev:SetScript("OnEvent", function()
    local has = HasNewMail and HasNewMail()
    if has and not hadMail then ShowBanner() end
    hadMail = has and true or false
end)
