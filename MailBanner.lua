-- ==========================================================================
-- MyCustomFrames - MailBanner.lua
-- Header de correo nuevo (pedido del usuario 2026-07-21): "un header que salga
-- cuando tengo un mail, que se deslice suavemente hacia abajo". 3 fases estilo
-- WeakAuras (Start/Main/Finish, misma estructura que la referencia que paso el
-- usuario, https://wago.io/1wKfUxJ8U) sobre texturas 100% NATIVAS de Blizzard,
-- sin arte propio:
--   - Fondo: "Objective-Header-CampaignAlliance"/"...Horde" segun faccion.
--   - Icono en el borde DERECHO: "communities-icon-invitemail".
--   - Texto centrado: "You have new mail, check your mailbox!"
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

local banner = CreateFrame("Frame", "MCF_MailBanner", UIParent)
banner:SetFrameStrata("HIGH")
banner:Hide()

local bg = banner:CreateTexture(nil, "ARTWORK")
bg:SetPoint("CENTER")

-- Tamaño real del banner = tamaño nativo del atlas, escalado por HEADER_SCALE
-- (pedido del usuario, ronda 3: "haz el header mas grande") -- NO se usa
-- banner:SetScale() (agrandaria el icono/texto tambien, y el pedido es agrandar
-- SOLO el header); en cambio se agranda el SIZE de "bg" (y el frame "banner" que
-- lo envuelve) directamente, dejando icono/texto con su tamaño propio, sin heredar
-- el escalado.
local HEADER_SCALE = 1.4
-- Mismo color dorado del texto (pedido del usuario, ronda 5: "coloriza el header
-- con el mismo color del texto, pero no el icono") -- se tiñe SOLO "bg" via
-- SetVertexColor, el icono ("icon") queda sin tocar/con sus colores nativos.
local TEXT_COLOR = { 1, 0.882, 0.608 }
local function ApplyFactionTexture()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    local atlas = (faction == "Horde") and "Objective-Header-CampaignHorde" or "Objective-Header-CampaignAlliance"
    bg:SetAtlas(atlas, true)
    bg:SetVertexColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3])
    local w, h = bg:GetSize()
    if w and w > 0 then
        bg:SetSize(w * HEADER_SCALE, h * HEADER_SCALE)
        banner:SetSize(w * HEADER_SCALE, h * HEADER_SCALE)
    end
end

-- Icono en el borde DERECHO (pedido del usuario, ronda 2 -- antes iba a la
-- izquierda, corregido segun captura de referencia). Tamaño propio mas chico
-- (pedido ronda 3: "el icono de mail mas pequeño"), independiente de HEADER_SCALE.
local icon = banner:CreateTexture(nil, "OVERLAY")
icon:SetAtlas("communities-icon-invitemail", true)
local iw, ih = icon:GetSize()
if iw and iw > 0 then icon:SetSize(iw * 0.65, ih * 0.65) end
icon:SetPoint("RIGHT", banner, "RIGHT", 4, 2)

-- Texto centrado (pedido del usuario, ronda 2, con captura de referencia):
-- "You have new mail, check your mailbox!". Ronda 4: ambos corridos un poco
-- mas a la derecha.
local text = banner:CreateFontString(nil, "OVERLAY")
text:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
text:SetPoint("CENTER", banner, "CENTER", 6, 2)
text:SetTextColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3])
text:SetText("You have new mail, check your mailbox!")

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
-- Pedido del usuario ronda 3 ("el pulse tiene un rebote extraño al final, que sea
-- mas suave"): menos amplitud (1.18->1.1) y mas duracion (0.6->0.9) para un
-- pulso mas calmo -- el "rebote" se notaba mas con un cambio de escala grande en
-- poco tiempo.
local pulseAnim = icon:CreateAnimationGroup()
pulseAnim:SetLooping("BOUNCE")
local pulseScale = pulseAnim:CreateAnimation("Scale")
pulseScale:SetOrigin("CENTER", 0, 0)
pulseScale:SetScale(1.1, 1.1)
pulseScale:SetDuration(0.9); pulseScale:SetSmoothing("IN_OUT")

-- ===================== FINISH: fade-out + slide hacia arriba =====================
local finishAnim = banner:CreateAnimationGroup()
local finishFade = finishAnim:CreateAnimation("Alpha")
finishFade:SetFromAlpha(1); finishFade:SetToAlpha(0)
finishFade:SetDuration(0.4); finishFade:SetSmoothing("IN")
local finishSlide = finishAnim:CreateAnimation("Translation")
finishSlide:SetOffset(0, SLIDE_DIST)
finishSlide:SetDuration(0.4); finishSlide:SetSmoothing("IN")

-- FIX (2026-07-21, medido con /mcfmailtest: a los 0.6s el punto ya estaba en su
-- lugar -90 pero el alpha seguia en 0): la Translation SI persiste porque el
-- punto se fija A MANO aca abajo, pero el alpha de la animacion NO persiste solo
-- -- hay que "clavarlo" a 1 explicitamente aca, igual que ya se hacia con el punto,
-- o revierte al alpha base (0, el que se puso a mano en ShowBanner) apenas la
-- animacion termina de tocar.
startAnim:SetScript("OnFinished", function()
    banner:SetPoint("TOP", UIParent, "TOP", 0, REST_Y)
    banner:SetAlpha(1)
    pulseAnim:Play()
end)
finishAnim:SetScript("OnFinished", function()
    pulseAnim:Stop()
    banner:SetAlpha(0)
    banner:Hide()
end)

local function ShowBanner()
    if not (bg.SetAtlas and icon.SetAtlas) then return end
    ApplyFactionTexture()
    banner:SetPoint("TOP", UIParent, "TOP", 0, REST_Y + SLIDE_DIST)
    banner:SetAlpha(0)
    banner:Show()
    finishAnim:Stop()
    pulseAnim:Stop()
    startAnim:Play()
    print(("|cffff8800[MCF MailBanner DEBUG]|r t0 shown=%s w=%s h=%s alpha=%s startPlaying=%s"):format(
        tostring(banner:IsShown()), tostring(banner:GetWidth()), tostring(banner:GetHeight()),
        tostring(banner:GetAlpha()), tostring(startAnim:IsPlaying())))
    C_Timer.After(0.6, function()
        print(("|cffff8800[MCF MailBanner DEBUG]|r t+0.6s shown=%s alpha=%s point=%s,%s pulsePlaying=%s"):format(
            tostring(banner:IsShown()), tostring(banner:GetAlpha()),
            tostring(select(4, banner:GetPoint())), tostring(select(5, banner:GetPoint())),
            tostring(pulseAnim:IsPlaying())))
    end)
end
ns.ShowMailBanner = ShowBanner

-- DIAGNOSTICO temporal: /mcfmailtest fuerza el banner sin depender de HasNewMail,
-- para aislar si el problema es la deteccion de correo o el dibujado en si.
SLASH_MCFMAILTEST1 = "/mcfmailtest"
SlashCmdList["MCFMAILTEST"] = function()
    print("|cffff8800[MCF MailBanner DEBUG]|r HasNewMail=" .. tostring(HasNewMail and HasNewMail()))
    ShowBanner()
end

local function HideBanner()
    if not banner:IsShown() then return end
    startAnim:Stop()
    finishAnim:Play()
end

-- FIX (2026-07-21, reportado por el usuario: "sale un milisegundo y se esconde,
-- debe quedarse mientras tenga un mail pendiente"): antes se cerraba solo con un
-- timer fijo (MAIN_DURATION) sin importar si seguias con correo sin leer. Ahora
-- el banner queda mostrado MIENTRAS HasNewMail() sea true, y recien dispara
-- FINISH cuando deja de haber correo pendiente (lo leiste/recogiste todo).
-- FIX (2026-07-21, reportado por el usuario: "no esta saliendo, y tengo un correo
-- pendiente"): faltaba PLAYER_ENTERING_WORLD -- UPDATE_PENDING_MAIL solo dispara
-- cuando el estado CAMBIA, asi que si ya tenias correo pendiente de ANTES de este
-- login/reload, nunca se disparaba de nuevo y el handler jamas corria (mismo
-- patron que Minimap.lua SI tiene para el icono, que por eso andaba bien).
local hadMail = false
local ev = CreateFrame("Frame")
ev:RegisterEvent("UPDATE_PENDING_MAIL")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
    local has = HasNewMail and HasNewMail() and true or false
    if has and not hadMail then
        ShowBanner()
    elseif not has and hadMail then
        HideBanner()
    end
    hadMail = has
end)
