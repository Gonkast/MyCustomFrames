-- ==========================================================================
-- MyCustomFrames - Minimap.lua
-- Minimapa estilo AzeriteUI: mascara redonda + borde decorativo + brujula +
-- coordenadas + indicador de correo + icono de LFG (eye) + anillo circular de
-- XP/Reputacion/Honor/Renown (usa LibSpinBar-1.0, vendorizada en Libs/).
-- Standalone: NO depende de AzeriteUI ni de oUF/AceAddon. El zoom (rueda del
-- raton), el click izquierdo (abrir mapa) y el click derecho (menu de
-- tracking) del minimapa nativo de Blizzard se conservan gratis porque solo
-- reparentamos/enmascaramos el frame Minimap, sin tocar sus scripts nativos.
-- Carga DESPUES de core.lua/Units.lua/.../Editing.lua en el toc.
-- ==========================================================================
local ADDON, ns = ...

local LSB = LibStub and LibStub("LibSpinBar-1.0", true)

-- ---- Assets ----
local A = ns.ASSETS
local MASK_TRANSPARENT   = A .. "minimap-mask-transparent.tga"
local MASK_OPAQUE        = A .. "minimap-mask-opaque.tga"
local BORDER_TEX         = A .. "minimap-border.tga"
local EYE_TEX            = A .. "group-finder-eye-orange.tga"
local BUTTON_TEX         = A .. "point_plate.tga"
local RING_BACKDROP_TEX  = A .. "minimap-onebar-backdrop.tga"
local RING_TEX           = A .. "minimap-bars-single.tga"
local DISMOUNT_TEX       = A .. "icon_exit_flight.tga"

-- ---- Colores (extraidos de AzeriteUI Core/Common/Colors.lua) ----
local UI_COLOR           = { 192/255, 192/255, 192/255 }
-- Paleta propia del addon (mismo dorado/ambar que el resto de MyCustomFrames)
-- en vez del morado original de AzeriteUI.
local XP_COLOR           = { 1, 0.882, 0.608 }        -- GOLD (FFE19B), color de texto por defecto del addon
local RESTED_COLOR       = { 0.922, 0.686, 0.353 }    -- ambar mas vivo (mismo tono que COLOR_GROUP de Options.lua)
local RESTED_BONUS_COLOR = { 0.580, 0.486, 0.400 }    -- marron-dorado apagado (mismo tono que COLOR_LINE)
local RENOWN_COLOR       = { 0x00/255, 0x59/255, 0x79/255 }   -- #005979, pedido por el usuario para renown
local GRAY_COLOR         = { 0.6, 0.6, 0.6 }

-- Gradiente rojo->amarillo->verde segun % de progreso (0..1). Usado para las
-- facciones tipo "amistad" (Acquaintance/Preferred/Anomaly/etc, sin reaction
-- numerico para usar el color nativo FACTION_BAR_COLORS de Blizzard).
local function ProgressGradientColor(pct)
    pct = math.max(0, math.min(1, pct or 0))
    if pct < 0.5 then
        local t = pct * 2
        return 0.85, 0.25 + t * 0.55, 0.15   -- rojo -> amarillo
    else
        local t = (pct - 0.5) * 2
        return 0.85 - t * 0.65, 0.80, 0.15 + t * 0.15   -- amarillo -> verde
    end
end

local function MinimapDefaults()
    return {
        enabled = true,
        scale = 1,
        point = "BOTTOMRIGHT", relativePoint = "BOTTOMRIGHT", anchorFrame = "UIParent",
        offsetX = -40, offsetY = 40,
        showCompass = true,
        showCoordinates = false,
        showMail = true,
        showEye = true,
        showRing = true,
        showTracking = true,
        -- Texturas personalizables (default = las mismas que ya tenia el addon).
        -- Solo el RELLENO/arco del anillo (minimap-bars-single) queda fijo, a
        -- pedido del usuario, para no romper la lectura del progreso de XP/Rep.
        borderTexture = "",
        backdropTexture = "",
        eyeTexture = "",
        ringBackdropTexture = "",
        ringButtonTexture = "",
        dismountTexture = "",
        -- Offsets de los iconos.
        eyeOffsetX = 82, eyeOffsetY = 82,
        -- Al lado de las coordenadas (pedido del usuario 2026-07-21), no espejando al eye.
        trackingOffsetX = -26, trackingOffsetY = 23,
        mailOffsetX = 0, mailOffsetY = 30,
        dismountOffsetX = 0, dismountOffsetY = 42,
        coordsOffsetX = 3, coordsOffsetY = 23,
        -- Pedido del usuario 2026-07-19: "quiero poder moverlo, y que siga al
        -- minimap de mi addon" (UIWidgetBelowMinimapContainerFrame -- catch-up
        -- buffs, barras de faccion, etc).
        showBelowMinimapWidget = true,
        widgetOffsetX = 0, widgetOffsetY = -6,
    }
end
ns.MinimapDefaults = MinimapDefaults

local mm = {}   -- referencias internas del modulo
ns.minimap = mm

local function P() return ns.GetDB() and ns.GetDB().minimap end
ns.MINIMAP_KEY = "minimap"
ns.IsMinimap = function(key) return key == ns.MINIMAP_KEY end

-- ==========================================================================
-- FORMA: mascara redonda + fondo opaco + borde decorativo
-- ==========================================================================
-- IMPORTANTE (encontrado tras varias rondas fallidas de ajustar numeros a mano):
-- Minimap:SetSize() NO tiene efecto duradero -- el tamaño real del minimapa lo
-- gestiona el propio Blizzard (CVar/Edit Mode "Minimap Size"), y algo lo
-- reafirma despues de nuestro SetSize (por eso cambiar el numero no cambiaba
-- NADA en pantalla en las pruebas anteriores). AzeriteUI mismo NUNCA llama
-- Minimap:SetSize en su Minimap.lua -- construye el borde/backdrop ALREDEDOR
-- del tamaño que Minimap YA tenga, no al reves. Replicamos ese enfoque: leemos
-- Minimap:GetSize() y dimensionamos backdrop/borde PROPORCIONALES a eso (misma
-- proporcion 398/198 de los valores originales de AzeriteUI).
local BORDER_RATIO = 398 / 198

local function LayoutShape()
    local root = mm.root
    if not root then return end
    local mapW = Minimap:GetWidth() or 198
    if not mapW or mapW <= 0 then mapW = 198 end
    local borderSize = mapW * BORDER_RATIO
    root.backdrop:SetSize(mapW, mapW)
    root.border:SetSize(borderSize, borderSize)
    root:SetSize(borderSize + 2, borderSize + 2)

    -- Texturas personalizables (default = las mismas que ya tenia el addon).
    local p = P()
    if p then
        root.backdrop:SetTexture((p.backdropTexture and p.backdropTexture ~= "" and p.backdropTexture) or MASK_OPAQUE)
        root.border:SetTexture((p.borderTexture and p.borderTexture ~= "" and p.borderTexture) or BORDER_TEX)
    end
end
ns.LayoutMinimapShape = LayoutShape

local function CreateShape()
    local root = CreateFrame("Frame", "MyCF_MinimapRoot", UIParent)
    root:SetSize(408, 408)
    root:SetPoint("CENTER")
    root:SetMovable(true)
    -- root es un CUADRADO (~408x408, el marco ornamentado) bastante mas grande
    -- que el circulo visible del mapa -- con el mouse SIEMPRE habilitado (bug:
    -- se dejo asi por error) bloqueaba clicks hacia el mundo/UI en las esquinas
    -- transparentes de ese cuadrado todo el tiempo, no solo en Lock ("zona
    -- muerta" reportada). Ahora arranca deshabilitado y RefreshMinimap lo
    -- prende/apaga en sync con el modo de edicion (mismo criterio que editBG).
    root:EnableMouse(false)
    root:RegisterForDrag("LeftButton")
    root:SetFrameStrata("LOW")

    local editBG = ns.MakeEditHighlight(root, "Minimap")

    -- Fondo opaco DETRAS del mapa (se ve a traves de la mascara transparente).
    local backdrop = root:CreateTexture(nil, "BACKGROUND", nil, -7)
    backdrop:SetTexture(MASK_OPAQUE)
    backdrop:SetPoint("CENTER")
    backdrop:SetVertexColor(0, 0, 0, 0.75)

    -- Borde decorativo (mas grande que el mapa, tipo marco tallado).
    local border = root:CreateTexture(nil, "BORDER", nil, 1)
    border:SetTexture(BORDER_TEX)
    border:SetPoint("CENTER")
    border:SetVertexColor(UI_COLOR[1], UI_COLOR[2], UI_COLOR[3])

    root.backdrop, root.border = backdrop, border

    -- El outline de edicion por defecto (MakeEditHighlight) cubre TODO "root",
    -- que incluye el marco ornamentado (border, mas grande que el circulo
    -- visible) -- se ve enorme comparado con el mapa redondo real. Se re-ancla
    -- al tamaño del circulo visible (backdrop, == Minimap:GetWidth()) en vez
    -- de a root; como backdrop se resize en LayoutShape, el anclaje "sigue" el
    -- tamaño real del mapa sin necesidad de tocarlo de nuevo ahi.

    -- El Minimap real de Blizzard: reparentado, enmascarado, sin tocar sus
    -- scripts (zoom con rueda, click izq = abrir mapa, click der = tracking
    -- menu siguen funcionando nativos). NO se le fuerza tamaño: se deja el que
    -- Blizzard le de, y nuestro borde/backdrop se ajustan a ESE tamaño.
    Minimap:SetParent(root)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("CENTER", root, "CENTER", 0, 0)
    Minimap:SetMaskTexture(MASK_TRANSPARENT)
    Minimap:SetFrameLevel(root:GetFrameLevel() + 2)
    Minimap:HookScript("OnSizeChanged", LayoutShape)

    -- MinimapCluster (el contenedor nativo) y sus piezas de borde/fondo propias
    -- (MinimapBackdrop/MinimapBorder/MinimapBorderTop, globals APARTE de
    -- MinimapCluster en este cliente) quedan en su posicion ORIGINAL una vez que
    -- Minimap se reparento afuera -> hay que ocultarlas todas, si no se ven
    -- "flotando" detras/encima del nuestro. Minimap ya NO es hijo de ninguna de
    -- estas, asi que ocultarlas no nos afecta. HookScript OnShow por si Blizzard
    -- las vuelve a mostrar (p.ej. al cambiar de zona).
    local function HideForever(f)
        if not f then return end
        f:Hide()
        if not f._mcfHideHooked then
            f._mcfHideHooked = true
            f:HookScript("OnShow", function(self) self:Hide() end)
        end
    end
    HideForever(MinimapCluster)
    HideForever(_G.MinimapBackdrop)
    HideForever(_G.MinimapBorder)
    HideForever(_G.MinimapBorderTop)
    -- Botones +/- de zoom nativos: ocultos (estilo AzeriteUI, se usa la rueda del
    -- mouse para zoom, que sigue funcionando nativo sin estos botones visibles).
    HideForever(Minimap.ZoomIn)
    HideForever(Minimap.ZoomOut)

    -- Calendario/AddonCompartment/reloj nativos de MinimapCluster (pedido del
    -- usuario 2026-07-19: "el backdrop del ring sale por debajo de otros
    -- iconos") -- confirmado con /mcfmapiconsdiag: aunque MinimapCluster esta
    -- oculto, estos 3 botones (GameTimeFrame/AddonCompartmentFrame/
    -- TimeManagerClockButton) seguian mostrandose con un FrameLevel mas alto
    -- que nuestro anillo/backdrop, flotando encima de forma inconsistente.
    -- Mismo criterio ya usado para los botones de zoom -- este addon reemplaza
    -- todo el minimapa con un look propio, sin necesitar estos extras nativos.
    HideForever(_G.GameTimeFrame)
    HideForever(_G.AddonCompartmentFrame)
    HideForever(_G.TimeManagerClockButton)

    -- (Feature de menu de tracking removida a pedido del usuario 2026-07-17: quedaba
    -- funcional -- checkboxes marcaban/desmarcaban bien, submenu Hunter Tracking,
    -- icono propio -- pero con una demora perceptible al clickear que no se pudo
    -- diagnosticar con certeza sin poder perfilar en vivo. Si se retoma: el ultimo
    -- estado funcional usaba C_Minimap.GetNumTrackingTypes()/GetTrackingInfo(i)/
    -- SetTracking(i,state) por INDICE [no GetTrackingOptions, no existe en este
    -- cliente] + MenuUtil.CreateContextMenu [MiniMapTrackingDropDown/Minimap_OnClick/
    -- Tracking.OpenMenu confirmados ausentes via /mcfmapdiag]. Reparentar el boton
    -- nativo MinimapCluster.Tracking NO funciona -- ni AzeriteUI lo hace, lo oculta.)

    editBG:ClearAllPoints()
    editBG:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 0, 0)
    editBG:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)

    root.editBG = editBG
    mm.root = root
    LayoutShape()

    local function StartDrag(self)
        if ns.IsUnlocked() and not InCombatLockdown() and not self.isMoving then
            self.isMoving = true
            self:StartMoving()
        end
    end
    local function FinishDrag(self)
        if not self.isMoving then return end
        self.isMoving = false
        self:StopMovingOrSizing()
        if ns.SnapFrameToGrid then ns.SnapFrameToGrid(self) end
        local p = P()
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
        if ns.OnDragStopped then ns.OnDragStopped("minimap") end
    end

    root:SetScript("OnDragStart", StartDrag)
    root:SetScript("OnDragStop", FinishDrag)
    root:SetScript("OnHide", function(self) FinishDrag(self) end)

    -- El Minimap real (hijo, mouse propio) no propaga el drag de "root" -- por
    -- eso en Lock solo se podia mover agarrando el marco/fondo, no el circulo
    -- del mapa en si. `editBG` (el outline verde) esta a un nivel de frame MAS
    -- ALTO que Minimap y ahora se habilita (EnableMouse/EnableMouseWheel) solo
    -- en Lock (ver RefreshMinimap) -- eso lo pone a EL, no al mapa nativo, a
    -- recibir el click/rueda dentro del circulo. Los hooks sobre Minimap son
    -- un respaldo (por si editBG esta oculto por "hideEditOutline"); en juego
    -- normal, bloqueado, ninguno de los dos interfiere con el click/zoom nativo.
    Minimap:HookScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then StartDrag(root) end
    end)
    Minimap:HookScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then FinishDrag(root) end
    end)
    editBG:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then StartDrag(root) end
    end)
    editBG:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then FinishDrag(root) end
    end)

    -- Red de seguridad (2026-07-18): si el boton se suelta fuera de root/Minimap
    -- (o el click nativo del mapa consume el evento y OnMouseUp nunca llega),
    -- el frame quedaba "pegado" siguiendo al mouse sin forma de soltarlo. Un
    -- ticker barato (solo corre mientras se esta arrastrando) chequea el boton
    -- fisico del mouse y corta el movimiento apenas se suelta.
    local moveWatcher = CreateFrame("Frame")
    moveWatcher:Hide()
    moveWatcher:SetScript("OnUpdate", function()
        if root.isMoving and not IsMouseButtonDown("LeftButton") then FinishDrag(root) end
        if not root.isMoving then moveWatcher:Hide() end
    end)
    hooksecurefunc(root, "StartMoving", function() moveWatcher:Show() end)

    -- La rueda se ata a `editBG` (no a `root`): root nunca queda ARRIBA de
    -- Minimap en nivel de frame, asi que la rueda pasaba de largo a traves de
    -- el hacia el zoom nativo de camara del mapa. editBG si esta arriba, y
    -- solo tiene el mouse habilitado en Lock (ver RefreshMinimap), asi que
    -- fuera de Lock el zoom nativo de camara sigue intacto.
    ns.AttachScaleWheel(editBG, function() return P() end, function() if ns.RefreshMinimap then ns.RefreshMinimap() end end)
end

-- ==========================================================================
-- BRUJULA (N que rota con la camara si "rotateMinimap" esta activo)
-- ==========================================================================
local function CreateCompass()
    local f = CreateFrame("Frame", nil, mm.root)
    f:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    -- Anclado al MINIMAP real (no a los bordes de "root", que es mucho mas grande
    -- que el mapa visible -- ~408px vs ~200px -- por eso la "N" quedaba flotando
    -- lejos del mapa, cerca del borde exterior de root).
    f:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 14, -14)
    f:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", -14, 14)

    local north = f:CreateFontString(nil, "ARTWORK", nil, 1)
    north:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    north:SetTextColor(0.9, 0.9, 0.9, 0.75)
    north:SetText("N")
    f.north = north
    mm.compass = f

    local halfPi = math.pi / 2
    -- PERF (2026-07-19, "arregla todo"): esto corria SIN throttle (60+/seg) y
    -- reaplicaba ClearAllPoints/SetPoint/SetAlpha todos los frames aunque el
    -- angulo no hubiera cambiado (o la brujula ni siquiera estuviera activa).
    -- Throttle a 0.05s (20/seg, de sobra para que la rotacion se vea fluida)
    -- + cache del ultimo estado aplicado para saltar el relayout si no cambio.
    local compassAcc = 0
    f._mcfLastMode, f._mcfLastAngle, f._mcfLastAlpha = nil, nil, nil
    f:SetScript("OnUpdate", function(self, elapsed)
        compassAcc = compassAcc + elapsed
        if compassAcc < 0.05 then return end
        compassAcc = 0
        local p = P()
        if not (p and p.showCompass) then
            if self._mcfLastMode ~= "off" then
                self._mcfLastMode = "off"
                self.north:SetAlpha(0)
            end
            return
        end
        local rotate = GetCVarBool and GetCVarBool("rotateMinimap")
        if not rotate then
            if self._mcfLastMode ~= "static" then
                self._mcfLastMode = "static"
                self.north:ClearAllPoints()
                self.north:SetPoint("TOP", self, "TOP", 0, 0)
                self.north:SetAlpha(0.75)
            end
            return
        end
        local facing = GetPlayerFacing and ns.safeVal(GetPlayerFacing)
        if type(facing) ~= "number" then
            if self._mcfLastMode ~= "off" then
                self._mcfLastMode = "off"
                self.north:SetAlpha(0)
            end
            return
        end
        local angle = -facing + halfPi
        if self._mcfLastMode == "rotate" and self._mcfLastAngle == angle then return end
        self._mcfLastMode, self._mcfLastAngle = "rotate", angle
        local radius = self:GetWidth() / 2
        self.north:ClearAllPoints()
        self.north:SetPoint("CENTER", self, "CENTER", radius * math.cos(angle), radius * math.sin(angle))
        self.north:SetAlpha(0.75)
    end)
end

-- ==========================================================================
-- COORDENADAS
-- ==========================================================================
local function CreateCoordinates()
    local fs = mm.root:CreateFontString(nil, "OVERLAY", nil, 1)
    fs:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    fs:SetTextColor(0.77, 0.77, 0.77, 0.75)
    mm.coords = fs
    mm.LayoutCoords = function()
        local p = P()
        fs:ClearAllPoints()
        fs:SetPoint("BOTTOM", (p and p.coordsOffsetX or 3), (p and p.coordsOffsetY or 23))
    end
    mm.LayoutCoords()

    -- FontString no admite SetScript: el ticker va en un Frame "driver" aparte.
    local driver = CreateFrame("Frame", nil, mm.root)
    local acc = 0
    driver:SetScript("OnUpdate", function(self, elapsed)
        acc = acc + elapsed
        if acc < 0.2 then return end
        acc = 0
        local p = P()
        if not (p and p.showCoordinates) then fs:SetText("") return end
        local ok, x, y = pcall(function()
            local mapID = C_Map.GetBestMapForUnit("player")
            if not mapID then return nil end
            local pos = C_Map.GetPlayerMapPosition(mapID, "player")
            if not pos then return nil end
            return pos:GetXY()
        end)
        if ok and x and y then
            fs:SetFormattedText("%.1f, %.1f", x * 100, y * 100)
        else
            fs:SetText("")
        end
    end)
end

-- ==========================================================================
-- CORREO (icono/texto + tooltip)
-- ==========================================================================
local function CreateMail()
    local btn = CreateFrame("Button", nil, mm.root)
    btn:SetSize(90, 20)
    btn:SetFrameLevel(Minimap:GetFrameLevel() + 5)

    -- Icono (pedido del usuario 2026-07-21, ronda 2: "quita el icono viejo del
    -- minimapa, reemplazalo por el nuevo icono" -- el mismo atlas que usa el
    -- banner de correo, MailBanner.lua) -- sigue al lado del texto "Mail" que ya
    -- se controla via el menu (Minimap > Icons 2).
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", btn, "LEFT", 0, 0)
    icon:SetAtlas("communities-icon-invitemail")
    mm.mailIcon = icon

    -- Animacion de "correo nuevo" (pedido del usuario 2026-07-21, referencia
    -- https://wago.io/1wKfUxJ8U): en vez de una WeakAura aparte, se replica el sistema
    -- NATIVO de Blizzard para esto mismo (mismo MiniMapMailFrame que ya investigamos para
    -- el atlas del icono) -- 2 flipbooks atlas propios del juego, sin arte nuevo: uno
    -- llamativo la PRIMERA vez que llega correo nuevo, y uno mas sutil de "recordatorio"
    -- las veces siguientes (mismo criterio/cvar "notifiedOfNewMail" que usa Blizzard).
    local newFlip = btn:CreateTexture(nil, "ARTWORK", nil, 1)
    newFlip:SetSize(52, 52)
    newFlip:SetPoint("CENTER", icon, "CENTER")
    newFlip:SetAtlas("UI-HUD-Minimap-Mail-New-Flipbook")
    newFlip:SetAlpha(0)
    local reminderFlip = btn:CreateTexture(nil, "ARTWORK", nil, 1)
    reminderFlip:SetSize(52, 52)
    reminderFlip:SetPoint("CENTER", icon, "CENTER")
    reminderFlip:SetAtlas("UI-HUD-Minimap-Mail-Reminder-Flipbook")
    reminderFlip:SetAlpha(0)

    local function MakeMailAnim(flipTex, duration, rows, cols, frames)
        local ag = flipTex:CreateAnimationGroup()
        local a = ag:CreateAnimation("Alpha")
        a:SetDuration(0); a:SetFromAlpha(1); a:SetToAlpha(1); a:SetOrder(1)
        local fb = ag:CreateAnimation("FlipBook")
        fb:SetDuration(duration); fb:SetOrder(2); fb:SetSmoothing("NONE")
        fb:SetFlipBookRows(rows); fb:SetFlipBookColumns(cols); fb:SetFlipBookFrames(frames)
        ag:SetScript("OnPlay", function() icon:SetShown(false) end)
        ag:SetScript("OnFinished", function()
            flipTex:SetAlpha(0)
            icon:SetShown((HasNewMail and HasNewMail()) and true or false)
        end)
        return ag
    end
    local newMailAnim = MakeMailAnim(newFlip, 0.5, 5, 4, 20)
    local reminderAnim = MakeMailAnim(reminderFlip, 0.4, 3, 4, 12)

    local function PlayMailNotification()
        if newMailAnim:IsPlaying() or reminderAnim:IsPlaying() then return end
        if GetCVarBool and GetCVarBool("notifiedOfNewMail") then
            reminderAnim:Play()
        else
            newMailAnim:Play()
            if SetCVar then SetCVar("notifiedOfNewMail", true) end
        end
    end
    mm.PlayMailNotification = PlayMailNotification

    -- fs se ancla a btn (su propio padre), NUNCA al reves: btn:SetAllPoints(fs)
    -- crearia una dependencia circular ("Cannot anchor to a region dependent on it").
    local fs = btn:CreateFontString(nil, "OVERLAY", nil, 1)
    fs:SetFont("Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
    fs:SetTextColor(0.77, 0.77, 0.77, 0.85)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("BOTTOM")
    fs:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    fs:SetPoint("RIGHT", btn, "RIGHT", 0, 0)
    fs:SetHeight(20)
    fs:SetText(MAIL_LABEL or "Mail")
    mm.mailText, mm.mailBtn = fs, btn

    -- Arrastre libre (mismo mecanismo que el boton de tracking, ver CreateTracking) --
    -- ANCLA "BOTTOM" (no CENTER) para no cambiar la posicion default de toda la vida
    -- (offsetX=0, offsetY=30 = exactamente donde estaba antes de poder arrastrarse):
    -- el delta se calcula sobre el punto BOTTOM-centro de self vs de mm.root, no sobre
    -- GetCenter() (que daria un numero distinto para el mismo punto visual).
    btn.editBG = ns.MakeEditHighlight(btn, "Mail")
    btn:SetMovable(true)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        if ns.IsUnlocked() and not InCombatLockdown() then self:StartMoving() end
    end)
    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p = P()
        if not p then return end
        local s, ps = self:GetEffectiveScale(), mm.root:GetEffectiveScale()
        local l, r, b = self:GetLeft(), self:GetRight(), self:GetBottom()
        local pl, pr, pb = mm.root:GetLeft(), mm.root:GetRight(), mm.root:GetBottom()
        if l and pl then
            p.mailOffsetX = (((l + r) / 2) * s - ((pl + pr) / 2) * ps) / s
            p.mailOffsetY = (b * s - pb * ps) / s
        end
        if mm.LayoutMail then mm.LayoutMail() end
    end)

    local function Update()
        local p = P()
        local hasMail = HasNewMail and HasNewMail()
        local show = (p and p.showMail) and hasMail
        fs:SetShown(show and true or false)
        icon:SetShown(show and true or false)
        btn:SetShown(show and true or false)
    end
    mm.UpdateMail = Update

    mm.LayoutMail = function()
        local p = P()
        btn:ClearAllPoints()
        btn:SetPoint("BOTTOM", mm.root, "BOTTOM", (p and p.mailOffsetX) or 0, (p and p.mailOffsetY) or 30)
        local locked_edit = ns.IsUnlocked and ns.IsUnlocked()
        if btn.editBG then
            btn.editBG:SetShown(locked_edit and not (ns.GetDB() and ns.GetDB().hideEditOutline))
        end
    end
    mm.LayoutMail()

    btn:SetScript("OnEnter", function(self)
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        if HasNewMail and HasNewMail() then
            local senders = { GetLatestThreeSenders and GetLatestThreeSenders() }
            if #senders > 0 then
                GameTooltip:AddLine(HAVE_MAIL_FROM or "Unread mail from:", 0.4, 1, 0.4)
                for _, s in ipairs(senders) do GameTooltip:AddLine(s, 1, 1, 1) end
            else
                GameTooltip:AddLine(HAVE_MAIL or "You have unread mail", 1, 0.82, 0)
            end
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local f = CreateFrame("Frame")
    f:RegisterEvent("UPDATE_PENDING_MAIL")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(_, event)
        Update()
        -- Solo dispara la animacion en UPDATE_PENDING_MAIL (mismo evento que usa
        -- Blizzard para esto), nunca en PLAYER_ENTERING_WORLD -- asi no aparece un
        -- flash cada /reload/login si ya tenias correo pendiente de antes.
        if event == "UPDATE_PENDING_MAIL" and HasNewMail and HasNewMail() and P() and P().showMail then
            PlayMailNotification()
        end
    end)
end

-- ==========================================================================
-- TRACKING (icono + menu propio, pedido del usuario 2026-07-21 -- ya se habia
-- intentado antes y se saco por una demora perceptible al clickear sin poder
-- diagnosticar la causa. Reintentado copiando el patron REAL de Blizzard
-- (Blizzard_Minimap/Mainline/Minimap.lua, MiniMapTrackingButtonMixin:OnLoad,
-- via wow-ui-source) en vez de reinventar uno propio: Blizzard TAMBIEN
-- reconstruye el menu entero en cada clic (nada de cache), asi que reconstruir
-- no era la causa real -- se sospecha que el intento anterior hacia algo mas
-- caro adentro del generador (por eso este va con timing real, ver abajo).
--
-- DropdownButton (mismo tipo de widget que usa el boton nativo de Blizzard,
-- MinimapCluster.Tracking) trae soporte de :SetupMenu(generador) integrado --
-- no hace falta MenuUtil.CreateContextMenu a mano. Atlas nativo
-- "ui-hud-minimap-tracking-up" (el mismo binocular que usa Blizzard), sin
-- necesitar arte propio.
-- ==========================================================================
local function CreateTracking()
    local btn = CreateFrame("DropdownButton", nil, mm.root)
    btn:SetSize(20, 20)
    btn:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetAtlas("ui-hud-minimap-tracking-up")
    tex:SetAllPoints()
    mm.trackingBtn = btn

    -- Arrastre libre (pedido del usuario 2026-07-21), SOLO en modo Lock -- mismo criterio
    -- que el resto del addon (root del minimapa incluido): mouse normal abre el menu de
    -- tracking, drag solo cuenta si ns.IsUnlocked(). Guarda la posicion como offset
    -- relativo al CENTRO del minimapa (mm.root), nunca a UIParent -- asi "sigue siempre
    -- al minimapa": si el usuario despues mueve el minimapa entero, este boton viaja con
    -- el sin tocarse nada mas (mismo mecanismo que el resto de los iconos, offsetX/Y).
    btn.editBG = ns.MakeEditHighlight(btn, "Tracking")
    btn:SetMovable(true)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        if ns.IsUnlocked() and not InCombatLockdown() then self:StartMoving() end
    end)
    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p = P()
        if not p then return end
        local s, ps = self:GetEffectiveScale(), mm.root:GetEffectiveScale()
        local fx, fy = self:GetCenter()
        local px, py = mm.root:GetCenter()
        if fx and px then
            p.trackingOffsetX = (fx * s - px * ps) / s
            p.trackingOffsetY = (fy * s - py * ps) / s
        end
        if mm.LayoutTracking then mm.LayoutTracking() end
    end)

    -- Estado OPTIMISTA: medido en juego (ver mensajes de debug ya sacados), el build del
    -- menu tardaba <1.1ms -- el "no se activan/se demora" que reporto el usuario era
    -- C_Minimap.SetTracking sin confirmar instantaneo, no el armado del menu. Blizzard
    -- resuelve esto mismo con su propio wrapper interno "trackingState", no expuesto a
    -- addons. Version liviana: guarda el valor que el usuario eligio por indice y lo
    -- muestra de una, hasta que la API real confirme lo mismo (ahi se limpia solo).
    local predicted = {}

    btn:SetupMenu(function(dropdown, rootDescription)
        rootDescription:SetTag("MCF_MINIMAP_TRACKING")

        if not (C_Minimap and C_Minimap.GetNumTrackingTypes) then return end
        local class = select(2, UnitClass("player"))
        local isHunter = class == "HUNTER"
        local hunterInfo, otherInfo = {}, {}

        for index = 1, C_Minimap.GetNumTrackingTypes() do
            local ok, info = pcall(C_Minimap.GetTrackingInfo, index)
            if ok and info then
                info.index = index
                if predicted[index] ~= nil then
                    if predicted[index] == info.active then predicted[index] = nil
                    else info.active = predicted[index] end
                end
                if isHunter and info.subType == HUNTER_TRACKING then
                    table.insert(hunterInfo, info)
                else
                    table.insert(otherInfo, info)
                end
            end
        end

        local function AddEntry(parentDesc, info)
            local desc = parentDesc:CreateCheckbox(
                info.name,
                function(data) return data.active end,
                function(data)
                    -- FIX (bug real encontrado 2026-07-21, "tengo que salir del panel y
                    -- volver a entrar para que se actualice"): isSelectedFn (arriba) leia
                    -- SIEMPRE data.active, el snapshot congelado de cuando se armo el menu
                    -- -- nunca se volvia a leer nada tras el clic dentro de la MISMA
                    -- apertura. Mutar data.active ACA (ademas de "predicted", que persiste
                    -- entre aperturas hasta que la API real confirme) hace que el propio
                    -- checkbox se vea tildado/destildado al toque, sin cerrar el menu.
                    local newVal = not data.active
                    predicted[data.index] = newVal
                    data.active = newVal
                    pcall(C_Minimap.SetTracking, data.index, newVal)
                end,
                info)
            if info.texture then
                desc:AddInitializer(function(button)
                    local icon = button:AttachTexture()
                    icon:SetSize(16, 16)
                    icon:SetPoint("RIGHT")
                    icon:SetTexture(info.texture)
                    if info.type == "spell" then icon:SetTexCoord(0.0625, 0.9, 0.0625, 0.9) end
                end)
            end
        end

        if #hunterInfo > 0 then
            local hunterMenu = (#hunterInfo > 1) and rootDescription:CreateButton(HUNTER_TRACKING_TEXT or "Hunter Tracking") or rootDescription
            for _, info in ipairs(hunterInfo) do AddEntry(hunterMenu, info) end
        end
        for _, info in ipairs(otherInfo) do AddEntry(rootDescription, info) end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:SetText(TRACKING or "Tracking")
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local function Layout()
        local p = P()
        btn:SetShown(p and p.showTracking and true or false)
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", mm.root, "CENTER", (p and p.trackingOffsetX) or 0, (p and p.trackingOffsetY) or 0)
        -- Outline de edicion (mismo criterio que root.editBG en RefreshMinimap): visible
        -- SOLO en Lock, y respeta el toggle "hideEditOutline" global.
        local locked_edit = ns.IsUnlocked and ns.IsUnlocked()
        if btn.editBG then
            btn.editBG:SetShown(locked_edit and not (ns.GetDB() and ns.GetDB().hideEditOutline))
        end
    end
    mm.LayoutTracking = Layout
    Layout()
end

-- ==========================================================================
-- EYE (icono de cola de LFG) — se reparenta el boton nativo de Blizzard y se le
-- pone una textura PROPIA encima (ocultando el arte original), igual que hace
-- AzeriteUI: SetParent(UIHider) a las sub-texturas .Eye/.Highlight nativas +
-- textura custom dibujada aparte. Personalizable via db.minimap.eyeTexture.
-- ==========================================================================
local UIHider = CreateFrame("Frame")
UIHider:Hide()

local function LayoutEye()
    local p = P()
    local eye = _G.QueueStatusButton
    if not eye then return end
    if not (p and p.showEye) then return end

    -- 2026-07-18: reparentar el boton NATIVO/protegido de Blizzard adentro de
    -- `root` contaminaba ("taint") ese frame de forma PERMANENTE -- root
    -- dejaba de poder llamar SetScale() nunca mas (ADDON_ACTION_BLOCKED),
    -- incluso diferido a otro frame con C_Timer.After (el taint viaja con el
    -- FRAME, no con el momento de ejecucion). Fix: un frame propio
    -- ("eyeHolder"), sin relacion de parentesco con root, que se posiciona
    -- visualmente ANCLADO a root (SetPoint no necesita parentesco) -- el ojo
    -- se reparenta a ESE holder en vez de a root, asi root nunca se contamina.
    if not mm.eyeHolder then
        local holder = CreateFrame("Frame", nil, UIParent)
        holder:SetSize(64, 64)
        holder:SetFrameStrata("HIGH")
        mm.eyeHolder = holder
    end
    local holder = mm.eyeHolder
    holder:ClearAllPoints()
    holder:SetPoint("CENTER", mm.root, "CENTER", (p.eyeOffsetX or 82), (p.eyeOffsetY or 82))

    eye:SetParent(holder)
    eye:SetFrameLevel(10)
    eye:SetSize(64, 64)
    eye:ClearAllPoints()
    eye:SetPoint("CENTER", holder, "CENTER", 0, 0)
    -- 2026-07-18: EnableMouse(false) rompia el click (cancelar cola) y el
    -- tooltip nativos -- el pedido real era que Blizzard no le "gane" la
    -- POSICION al icono, no que deje de responder al mouse. Eso ya se cubre
    -- abajo con el hook a SetPoint (reasertar posicion) + OnShow; el click y
    -- tooltip nativos quedan intactos.

    if not mm.eyeTex then
        -- Ocultar el arte nativo (Eye/Highlight) reparentandolo a un frame oculto.
        if eye.Eye then eye.Eye:SetParent(UIHider) end
        if eye.Highlight then eye.Highlight:SetParent(UIHider) end
        local tex = eye:CreateTexture(nil, "OVERLAY")
        tex:SetPoint("CENTER")
        mm.eyeTex = tex

        -- Blizzard reparenta/reposiciona QueueStatusButton por su cuenta cuando
        -- cambia el estado de cola (Show() propio), pisando nuestra posicion un
        -- rato despues del reload -> reafirmar la posicion cada vez que Blizzard
        -- lo vuelve a mostrar.
        --
        -- 2026-07-18: llamar RefreshMinimap() ENTERO aca (que de paso hace
        -- root:SetScale) seguia dando "ADDON_ACTION_BLOCKED" pese a diferirlo
        -- con C_Timer.After -- el taint de la llamada protegida de Blizzard
        -- (eye:SetPoint via su propio MicroMenuContainer:Layout) viaja CON el
        -- hooksecurefunc, no con el momento en que se ejecuta. La solucion de
        -- fondo: no llamar SetScale ACA para nada -- este hook solo necesita
        -- reacomodar al ojo, asi que llama solo LayoutEye() (que no toca
        -- root:SetScale en absoluto), nunca RefreshMinimap completo.
        eye:HookScript("OnShow", function() LayoutEye() end)

        -- Blizzard tambien llama SetPoint directo sobre el boton (fuera de
        -- OnShow) cuando cambia de estado de cola -- guard contra recursion
        -- infinita (nuestro propio SetPoint mas abajo dispara este mismo hook).
        local reasserting = false
        hooksecurefunc(eye, "SetPoint", function()
            if reasserting or not mm.root then return end
            reasserting = true
            LayoutEye()
            reasserting = false
        end)
    end
    mm.eyeTex:SetSize(64, 64)
    mm.eyeTex:SetTexture((p.eyeTexture and p.eyeTexture ~= "" and p.eyeTexture) or EYE_TEX)
end

-- ==========================================================================
-- WIDGET "below minimap" NATIVO de Blizzard (UIWidgetBelowMinimapContainerFrame
-- -- catch-up buffs, barras de faccion, contadores de escenario, etc) -- pedido
-- del usuario 2026-07-19 ("quiero poder moverlo, y que siga al minimap de mi
-- addon"): identificado con /fstack (Blizzard_UIWidgets/Mainline/
-- Blizzard_UIWidgetManager.lua). MISMO patron que el ojo de LFG arriba: un
-- holder PROPIO (sin parentesco con root, asi root nunca se contamina) que se
-- ancla visualmente a mm.root, y el frame nativo se reparenta a ESE holder.
-- No se le toca el arte (a diferencia del ojo) -- solo se reposiciona.
-- ==========================================================================
local function LayoutBelowMinimapWidget()
    local p = P()
    local w = _G.UIWidgetBelowMinimapContainerFrame
    if not w then return end
    if not (p and p.showBelowMinimapWidget ~= false) then return end

    if not mm.widgetHolder then
        local holder = CreateFrame("Frame", nil, UIParent)
        holder:SetSize(200, 40)
        holder:SetFrameStrata("MEDIUM")
        mm.widgetHolder = holder
    end
    local holder = mm.widgetHolder
    holder:ClearAllPoints()
    holder:SetPoint("TOP", mm.root, "BOTTOM", (p.widgetOffsetX or 0), (p.widgetOffsetY or -6))

    local ok = pcall(function()
        w:SetParent(holder)
        w:ClearAllPoints()
        w:SetPoint("TOP", holder, "TOP", 0, 0)
    end)
    if not ok then return end

    if not mm._widgetHooked then
        mm._widgetHooked = true
        -- Blizzard reposiciona este contenedor solo cada vez que un widget
        -- entra/sale (UIWidgetManager) -- reafirmar cuando eso pasa, mismo
        -- guard anti-recursion que el ojo (nuestro propio SetPoint de arriba
        -- dispara este mismo hook).
        local reasserting = false
        local ok2 = pcall(hooksecurefunc, w, "SetPoint", function()
            if reasserting or not mm.root then return end
            reasserting = true
            LayoutBelowMinimapWidget()
            reasserting = false
        end)
        if ok2 then w:HookScript("OnShow", function() LayoutBelowMinimapWidget() end) end
    end
end

-- ==========================================================================
-- BOTON DE DESMONTAR / SALIR DE VEHICULO (accion protegida -> frame seguro,
-- mismo patron que el overlay de cancelar buff de Auras.lua: SecureActionButtonTemplate
-- + macrotext + RegisterStateDriver para mostrar/ocultar sin taint).
-- ==========================================================================
local function CreateDismountButton()
    local btn = CreateFrame("Button", "MyCF_MinimapDismount", mm.root, "SecureActionButtonTemplate")
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(mm.root:GetFrameLevel() + 10)
    btn:SetSize(72, 72)

    -- Reposicion en su propia funcion (no solo al crear) para que el slider de
    -- offset del menu se refleje EN VIVO via RefreshMinimap, igual que el eye.
    -- SetPoint en un frame SECURE fuera de combate es seguro; se salta si
    -- InCombatLockdown (igual que el resto de los frames movibles del addon).
    mm.LayoutDismount = function()
        if InCombatLockdown() then return end
        local p = P()
        btn:ClearAllPoints()
        btn:SetPoint("TOP", Minimap, "TOP", (p and p.dismountOffsetX or 0), (p and p.dismountOffsetY or 42))
    end
    mm.LayoutDismount()

    btn:SetAttribute("type", "macro")
    btn:SetAttribute("macrotext", "/leavevehicle [@vehicle,exists,canexitvehicle]\n/dismount [mounted]")
    btn:RegisterForClicks("AnyUp", "AnyDown")
    if not InCombatLockdown() then
        RegisterStateDriver(btn, "visibility", "[@vehicle,exists,canexitvehicle][possessbar][mounted] show; hide")
    end

    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(btn)
    tex:SetTexture(DISMOUNT_TEX)
    btn.tex = tex
    mm.dismountTex = tex

    btn:SetScript("OnEnter", function(self)
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        if UnitOnTaxi and UnitOnTaxi("player") then
            GameTooltip:AddLine(TAXI_CANCEL or "Cancel Flight")
        elseif IsMounted and IsMounted() then
            GameTooltip:AddLine(BINDING_NAME_DISMOUNT or "Dismount")
        else
            GameTooltip:AddLine(BINDING_NAME_VEHICLEEXIT or "Leave Vehicle")
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() if not GameTooltip:IsForbidden() then GameTooltip:Hide() end end)

    mm.dismountBtn = btn
end

-- ==========================================================================
-- ANILLO DE XP / REPUTACION / HONOR / RENOWN (LibSpinBar)
-- ==========================================================================
local function CreateRing()
    if not LSB then return end

    -- Los numeros originales de AzeriteUI (213/208/410/56/100/etc.) estan pensados
    -- para un Minimap de referencia de 198px; como ya NO forzamos el tamaño del
    -- Minimap (ver LayoutShape), escalamos todo por k = tamaño real / 198.
    local k = (Minimap:GetWidth() or 198) / 198

    -- "frame" (el anillo/backdrop) va parentado a mm.root con un nivel base propio;
    -- "button" (el icono/toggle) se pone POR ENCIMA sumando, nunca restando del nivel
    -- de otro frame (restar puede irse a negativo -> "outside of expected range").
    local frame = CreateFrame("Frame", nil, mm.root)
    -- strata MEDIUM (pedido del usuario 2026-07-19, "los iconos del mapa se
    -- siguen viendo encima del anillo") -- Minimap:SetAlpha(0) NO alcanza
    -- para tapar los PINES del minimapa (vendedor, cluster, etc): confirmado
    -- en vivo que Blizzard los dibuja con SetIgnoreParentAlpha (no heredan la
    -- transparencia del Minimap). Como este frame solo se MUESTRA durante el
    -- hover (:Hide() el resto del tiempo, ver OnUpdate mas abajo), subirle la
    -- strata por encima de Minimap (que se queda en LOW) garantiza que tape
    -- todo por ORDEN DE CAPAS en vez de depender de alpha.
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(mm.root:GetFrameLevel() + 1)
    frame:SetSize(213 * k, 213 * k)
    frame:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
    frame:Hide()

    local button = CreateFrame("Frame", "MyCF_MinimapRing", mm.root)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(frame:GetFrameLevel() + 10)
    button:SetSize(56 * k, 56 * k)
    button:SetPoint("CENTER", Minimap, "BOTTOM", 2 * k, -6 * k)
    button:Hide()

    local btex = button:CreateTexture(nil, "BACKGROUND")
    btex:SetSize(100 * k, 100 * k)
    btex:SetPoint("CENTER")
    btex:SetTexture(BUTTON_TEX)
    btex:SetVertexColor(UI_COLOR[1], UI_COLOR[2], UI_COLOR[3])
    mm.ringButtonTex = btex

    local percent = button:CreateFontString(nil, "OVERLAY")
    percent:SetFont("Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
    percent:SetPoint("CENTER")
    button.percent = percent

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(410 * k, 410 * k)
    bg:SetPoint("CENTER")
    bg:SetTexture(RING_BACKDROP_TEX)
    bg:SetVertexColor(UI_COLOR[1], UI_COLOR[2], UI_COLOR[3])
    mm.ringBackdropTex = bg

    local ring = LSB:CreateSpinBar("MyCF_MinimapRingBar", frame)
    ring:SetFrameLevel(frame:GetFrameLevel() + 5)
    ring:SetSize(208 * k, 208 * k)
    ring:SetPoint("CENTER", 0, 2 * k)
    ring:SetStatusBarTexture(RING_TEX)
    ring:SetSparkTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
    ring:SetSparkOffset(-1 / 10)
    ring:SetSparkInset((24 * 208 / 256) * k)
    ring:SetSparkSize(34 * 208 / 256 * k, 30 * k)
    ring:SetSparkBlendMode("ADD")
    ring:SetClockwise(true)
    ring:SetDegreeOffset(90 * 3 - 14)
    ring:SetDegreeSpan(360 - 14 * 2)

    local bonus = LSB:CreateSpinBar("MyCF_MinimapRingBonusBar", frame)
    bonus:SetFrameLevel(frame:GetFrameLevel() + 2)
    bonus:SetAllPoints(ring)
    bonus:SetStatusBarTexture(RING_TEX)
    bonus:SetClockwise(true)
    bonus:SetDegreeOffset(90 * 3 - 14)
    bonus:SetDegreeSpan(360 - 14 * 2)
    bonus:SetStatusBarColor(RESTED_BONUS_COLOR[1], RESTED_BONUS_COLOR[2], RESTED_BONUS_COLOR[3])

    local value = frame:CreateFontString(nil, "OVERLAY")
    value:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
    value:SetPoint("CENTER", 0, 1)

    local desc = frame:CreateFontString(nil, "OVERLAY")
    desc:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    desc:SetWidth(100)
    desc:SetPoint("CENTER", 0, -16)
    desc:SetTextColor(GRAY_COLOR[1], GRAY_COLOR[2], GRAY_COLOR[3])

    button.frame, button.ring, button.bonus, button.value, button.desc = frame, ring, bonus, value, desc
    mm.ringButton = button

    -- Fade in/out del anillo (solo visible con mouse encima del boton). Al mostrarse
    -- debe OCULTAR POR COMPLETO el mapa (no un overlay semitransparente encima):
    -- Minimap queda con nivel de frame MAS ALTO que el anillo (root+2 vs root+1),
    -- asi que aunque el anillo tape visualmente, el mapa seguiria ganando el
    -- z-order -> hay que Hide()/Show() el Minimap real, no solo la alpha del anillo.
    local FADE_IN, FADE_OUT = 0.4, 0.4
    button:SetScript("OnUpdate", function(self, elapsed)
        -- SOLO el boton chico ("49") activa el hover -- self.frame (el anillo
        -- grande) ocupa casi todo el minimapa, si tambien contara aca se activaria
        -- con el mouse en cualquier parte del mapa, no solo en el boton.
        local hovering = self:IsMouseOver()
        local target = hovering and 1 or 0
        local cur = self.frame._alpha or 0
        -- 2026-07-18: Minimap:Hide()/Show() estan PROTEGIDOS en este cliente
        -- para addons ("ADDON_ACTION_BLOCKED", confirmado en vivo, sin
        -- importar el contexto/timing) -- SetAlpha(0) logra el mismo
        -- resultado visual (invisible) sin llamar una funcion protegida.
        if target == 1 and Minimap:GetAlpha() > 0 then Minimap:SetAlpha(0) end
        if cur == target then
            if target == 0 then
                if self.frame:IsShown() then self.frame:Hide() end
                if Minimap:GetAlpha() < 1 then Minimap:SetAlpha(1) end
            end
            return
        end
        local speed = (target > cur) and (1 / FADE_IN) or (1 / FADE_OUT)
        cur = cur + (target - cur >= 0 and 1 or -1) * speed * elapsed
        if (target == 1 and cur > 1) or (target == 0 and cur < 0) then cur = target end
        self.frame._alpha = cur
        if cur > 0 and not self.frame:IsShown() then self.frame:Show() end
        self.frame:SetAlpha(cur)
        if cur == 0 and Minimap:GetAlpha() < 1 then Minimap:SetAlpha(1) end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        if self._mode == "xp" then
            GameTooltip:AddLine(COMBAT_XP_GAIN or "Experience", 1, 0.82, 0)
            GameTooltip:AddLine(self._label or "", 1, 1, 1)
            if type(self._restedXP) == "number" and self._restedXP > 0 then
                GameTooltip:AddLine(TUTORIAL_TITLE26 or "Rested", 0.6, 0.6, 0.9)
                GameTooltip:AddLine(EXHAUST_TOOLTIP1 or "You will earn experience faster while rested.", 0.6, 0.6, 0.9, true)
            end
        elseif self._mode == "reputation" then
            GameTooltip:AddLine(self._label or "", 1, 1, 1)
            if self._desc2 and self._desc2 ~= "" then GameTooltip:AddLine(self._desc2, 1, 0.82, 0) end
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() if not GameTooltip:IsForbidden() then GameTooltip:Hide() end end)
    button:EnableMouse(true)
    button:SetMouseClickEnabled(false)
end

-- Diagnostico de la "zona muerta" reportada 2026-07-18: imprime el estado real
-- de mouse/lock del minimapa para confirmar si root/editBG quedaron prendidos
-- fuera de Lock, o si el bloqueo viene de otro frame flotando encima (ej. un
-- popup del menu que no se cerro).
SLASH_MCFMMDIAG1 = "/mcfmmdiag"
SlashCmdList["MCFMMDIAG"] = function()
    local root = mm.root
    print("|cff00ff00[MCF diag]|r IsUnlocked=" .. tostring(ns.IsUnlocked and ns.IsUnlocked()))
    if not root then print("  root=nil"); return end
    print(("  root: mouse=%s w=%.0f h=%.0f strata=%s"):format(
        tostring(root:IsMouseEnabled()), root:GetWidth() or -1, root:GetHeight() or -1, root:GetFrameStrata()))
    if root.editBG then
        print(("  editBG: mouse=%s shown=%s"):format(tostring(root.editBG:IsMouseEnabled()), tostring(root.editBG:IsShown())))
    end
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    x, y = x / scale, y / scale
    local f = GetMouseFocus and GetMouseFocus()
    print(("  cursor screen=(%.0f,%.0f)  mouseFocus=%s"):format(x, y, f and (f:GetName() or "<anon>") or "nil"))
end

-- Diagnostico 2026-07-19 (pedido del usuario: "el backdrop del ring sale por
-- debajo de otros iconos") -- recorre TODOS los frames visibles cuyo CENTRO
-- cae dentro del radio del anillo (no solo hijos de MinimapCluster -- varios
-- botones de Blizzard son frames SUELTOS anclados cerca del minimapa, no
-- hijos reales de el, y por eso HideForever(MinimapCluster) no los alcanza).
-- Imprime nombre/strata/nivel de cada uno para identificar cual es cual.
SLASH_MCFMAPICONSDIAG1 = "/mcfmapiconsdiag"
SlashCmdList["MCFMAPICONSDIAG"] = function()
    if not mm.root then print("|cff00ff00[MCF]|r minimap no inicializado"); return end
    local rx, ry = mm.root:GetCenter()
    if not rx then print("|cff00ff00[MCF]|r root sin centro (oculto?)"); return end
    local radius = (mm.root:GetWidth() or 200)
    print(("|cff00ff00[MCF mapicons diag]|r root strata=%s level=%d centro=(%.0f,%.0f) radio~%.0f"):format(
        mm.root:GetFrameStrata(), mm.root:GetFrameLevel(), rx, ry, radius))
    local seen, count = {}, 0
    local function scan(frame, depth)
        if depth > 6 or type(frame) ~= "table" or seen[frame] then return end
        seen[frame] = true
        local okShown, shown = pcall(frame.IsShown, frame)
        if okShown and shown and frame ~= mm.root then
            local ok, fx, fy = pcall(frame.GetCenter, frame)
            if ok and fx then
                local dist = math.sqrt((fx - rx) ^ 2 + (fy - ry) ^ 2)
                if dist < radius then
                    count = count + 1
                    local okN, name = pcall(frame.GetName, frame)
                    name = (okN and name) or "<anon>"
                    local okS, strata = pcall(frame.GetFrameStrata, frame)
                    local okL, level = pcall(frame.GetFrameLevel, frame)
                    local parentName = "?"
                    local okP, parent = pcall(frame.GetParent, frame)
                    if okP and parent then
                        local okPN, pn = pcall(parent.GetName, parent)
                        if okPN and pn then parentName = pn end
                    end
                    print(("  #%d %s  strata=%s level=%s dist=%.0f parent=%s"):format(
                        count, name, okS and strata or "?", okL and tostring(level) or "?", dist, parentName))
                end
            end
        end
        if frame.GetChildren then
            local ok, c1 = pcall(frame.GetChildren, frame)
            if ok and c1 ~= nil then
                for _, c in ipairs({ frame:GetChildren() }) do scan(c, depth + 1) end
            end
        end
    end
    scan(UIParent, 0)
    print(("|cff00ff00[MCF mapicons diag]|r %d frames visibles dentro del radio"):format(count))
end

-- Actualiza el anillo: prioridad reputacion vigilada > paragon > major
-- faction/renown > friendship > reputacion normal > XP (igual que AzeriteUI).
SLASH_MCFRINGDIAG1 = "/mcfringdiag"
SlashCmdList["MCFRINGDIAG"] = function()
    print("|cff00ff00[MCF diag]|r GetWatchedFactionInfo=" .. tostring(GetWatchedFactionInfo ~= nil))
    if GetWatchedFactionInfo then
        local ok, name, reaction, minv, maxv, curv, factionID = pcall(GetWatchedFactionInfo)
        print("  pcall ok=" .. tostring(ok) .. " name=" .. tostring(name) .. " factionID=" .. tostring(factionID))
    end
    print("  C_Reputation=" .. tostring(C_Reputation ~= nil))
    if C_Reputation then
        for k in pairs(C_Reputation) do
            if type(k) == "string" and (k:lower():find("watch") or k:lower():find("xpbar") or k:lower():find("experience")) then
                print("  C_Reputation." .. k)
            end
        end
    end
    print("  C_MajorFactions=" .. tostring(C_MajorFactions ~= nil))
    if C_Reputation and C_Reputation.GetWatchedFactionData then
        local ok, data = pcall(C_Reputation.GetWatchedFactionData)
        print("  GetWatchedFactionData() ok=" .. tostring(ok))
        if ok and data then
            print("  --- todos los campos de la tabla ---")
            for k, v in pairs(data) do
                print("    " .. tostring(k) .. " = " .. tostring(v))
            end
            local fid = data.factionID
            if fid and C_MajorFactions and C_MajorFactions.GetMajorFactionData then
                local mOk, mdata = pcall(C_MajorFactions.GetMajorFactionData, fid)
                print("  GetMajorFactionData(" .. tostring(fid) .. ") ok=" .. tostring(mOk))
                if mOk and mdata then
                    for k, v in pairs(mdata) do print("    MF." .. tostring(k) .. " = " .. tostring(v)) end
                end
            end
            if fid and C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
                local fOk, fdata = pcall(C_GossipInfo.GetFriendshipReputation, fid)
                print("  GetFriendshipReputation(" .. tostring(fid) .. ") ok=" .. tostring(fOk))
                if fOk and fdata then
                    for k, v in pairs(fdata) do print("    FR." .. tostring(k) .. " = " .. tostring(v)) end
                end
            end
        end
    end
    mm._ringDebug = true
    if ns.UpdateMinimapRing then ns.UpdateMinimapRing() end
    if mm.ringButton then
        local ring = mm.ringButton.ring
        print("  ring:IsShown()=" .. tostring(ring:IsShown()))
        print("  ring frame:IsShown()=" .. tostring(mm.ringButton.frame:IsShown()) .. " alpha=" .. tostring(mm.ringButton.frame:GetAlpha()))
        print("  ring:GetSize()=" .. tostring(select(1, ring:GetSize())) .. "x" .. tostring(select(2, ring:GetSize())))
    end
end

local function UpdateRing()
    local btn = mm.ringButton
    if not btn then return end
    local p = P()
    if not (p and p.showRing) then btn:Hide() return end

    -- /mcfringdiag confirmo: GetWatchedFactionInfo NO existe en este cliente, el
    -- reemplazo es C_Reputation.GetWatchedFactionData() (devuelve UNA tabla, no
    -- multiples valores).
    local name, reaction, minv, maxv, curv, factionID
    if C_Reputation and C_Reputation.GetWatchedFactionData then
        local ok, data = pcall(C_Reputation.GetWatchedFactionData)
        if ok and data then
            name, reaction, minv, maxv, curv, factionID =
                data.name, data.reaction, data.currentReactionThreshold, data.nextReactionThreshold,
                data.currentStanding, data.factionID
        end
    end
    local mode, barMin, barMax, barVal, label, desc, color = nil, 0, 1, 0, "", "", nil

    -- /mcfringdiag con una faccion de RENOWN real (Council of Dornogal) confirmo la
    -- causa: currentReactionThreshold/currentStanding de GetWatchedFactionData son
    -- de la escala de reaccion VIEJA, ya topeada en Exalted (reaction=5) para
    -- cualquier faccion de renown -- no sirven para la barra. El progreso REAL vive
    -- en C_MajorFactions.GetMajorFactionData: renownReputationEarned/renownLevelThreshold.
    -- El chequeo previo `C_Reputation.IsMajorFaction(factionID)` no detectaba esto
    -- bien (mostraba 0/10000/0) -- ahora se prueba GetMajorFactionData DIRECTO y se
    -- usa si devuelve datos validos, en vez de confiar en el checker.
    local isRenown = false
    if name and factionID then
        local mOk, mdata = pcall(C_MajorFactions.GetMajorFactionData, factionID)
        if mOk and mdata and mdata.renownLevelThreshold and mdata.renownLevelThreshold > 0 then
            mode = "reputation"
            isRenown = true
            barMin, barMax, barVal = 0, mdata.renownLevelThreshold, mdata.renownReputationEarned or 0
            label = name
            desc = (RENOWN_LEVEL_LABEL and RENOWN_LEVEL_LABEL:format(mdata.renownLevel)) or ("Renown " .. tostring(mdata.renownLevel))
        end
        if not mode then
            -- /mcfringdiag con Sabellian mostro los campos reales: reactionThreshold=0
            -- (inicio del RANGO actual), nextThreshold=8400 (ancho del rango actual),
            -- standing=2200 (progreso), maxRep=42000 (tope ACUMULADO de TODOS los
            -- rangos juntos -- no sirve como maximo de la barra, usarlo hacia que
            -- 2200/42000=5% se viera como una raya invisible en vez del 26% real
            -- dentro del rango actual, 2200/8400).
            local fOk, fdata = pcall(C_GossipInfo.GetFriendshipReputation, factionID)
            if fOk and fdata and fdata.friendshipFactionID and fdata.friendshipFactionID > 0 then
                mode = "reputation"
                barMin, barMax, barVal = fdata.reactionThreshold or 0, fdata.nextThreshold or 1, fdata.standing or 0
                label, desc = name, fdata.reaction or ""
                -- Sin reaction NUMERICO para usar FACTION_BAR_COLORS -- color por
                -- gradiente segun el % de progreso dentro del rango actual.
                local span = barMax - barMin
                local r, g, b = ProgressGradientColor(span > 0 and (barVal - barMin) / span or 0)
                color = { r = r, g = g, b = b }
            end
        end
        if not mode then
            mode = "reputation"
            barMin, barMax, barVal = minv or 0, maxv or 1, curv or 0
            label = name
            desc = (reaction and _G["FACTION_STANDING_LABEL" .. reaction]) or ""
            color = FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
        end
    end

    if not mode then
        if (IsPlayerAtEffectiveMaxLevel and IsPlayerAtEffectiveMaxLevel()) or (IsXPUserDisabled and IsXPUserDisabled()) then
            btn:Hide()
            return
        end
        mode = "xp"
        barMin, barMax = 0, UnitXPMax("player") or 1
        barVal = UnitXP("player") or 0
        label = LEVEL and string.format("%s %d", LEVEL, UnitLevel("player")) or tostring(UnitLevel("player"))
        desc = "to level " .. (UnitLevel("player") + 1)
    end

    btn:Show()
    if mm._ringDebug then
        print(string.format("|cff00ff00[MCF ring]|r mode=%s barMin=%s barMax=%s barVal=%s",
            tostring(mode), tostring(barMin), tostring(barMax), tostring(barVal)))
    end
    -- LibSpinBar calcula el % de relleno como valor/(max-min) -- SIN restar min al
    -- valor primero. Con barMin=0 (XP, renown) da igual, pero para reputacion clasica
    -- (donde cada rango arranca en un umbral > 0, ej Friendly 3000-9000 con curv
    -- absoluto ~6650) esa formula queda mal (600%+ de relleno, arco roto/chico visto).
    -- Se normaliza SIEMPRE a un min de 0 antes de pasarselo a la libreria.
    local ringMax, ringVal = barMax - barMin, barVal - barMin
    btn.ring:SetMinMaxValues(0, ringMax)
    -- overrideSmoothing=true: salta al valor real de una, sin depender de la
    -- animacion de suavizado (que anima desde el valor anterior con el tiempo,
    -- podia tardar en mostrarse o no notarse en una prueba corta).
    btn.ring:SetValue(ringVal, true)

    local restedXP
    local rc, gc, bc  -- color activo, compartido entre la barra y los 3 textos
    if mode == "xp" then
        restedXP = GetXPExhaustion and ns.safeVal(GetXPExhaustion)
        if type(restedXP) == "number" and restedXP > 0 then
            rc, gc, bc = RESTED_COLOR[1], RESTED_COLOR[2], RESTED_COLOR[3]
            btn.ring:SetStatusBarColor(rc, gc, bc)
            btn.bonus:SetMinMaxValues(barMin, barMax)
            btn.bonus:SetValue(math.min(barMax, barVal + restedXP), true)
            btn.bonus:Show()
        else
            rc, gc, bc = XP_COLOR[1], XP_COLOR[2], XP_COLOR[3]
            btn.ring:SetStatusBarColor(rc, gc, bc)
            btn.bonus:Hide()
        end
        btn.percent:SetFormattedText("%d", barMax > 0 and (barVal / barMax * 100) or 0)
    else
        btn.bonus:Hide()
        if isRenown then
            rc, gc, bc = RENOWN_COLOR[1], RENOWN_COLOR[2], RENOWN_COLOR[3]
        else
            local c = color or { r = UI_COLOR[1], g = UI_COLOR[2], b = UI_COLOR[3] }
            rc, gc, bc = c.r or c[1], c.g or c[2], c.b or c[3]
        end
        -- % en el boton para TODA reputacion (no solo renown). barMin no siempre es 0
        -- (reputacion clasica/friendship arrancan en su propio umbral), asi que hay
        -- que restarlo para el porcentaje real dentro del tramo actual.
        local span = barMax - barMin
        btn.percent:SetFormattedText("%d", span > 0 and ((barVal - barMin) / span * 100) or 0)
        btn.ring:SetStatusBarColor(rc, gc, bc)
    end

    -- El numero (49 / 215K) COMPARTE color con la barra activa; la descripcion
    -- ("to level X") se queda con su color gris original, sin cambiar.
    btn.percent:SetTextColor(rc, gc, bc)
    btn.value:SetTextColor(rc, gc, bc)

    -- Numero grande: cantidad REAL restante (abreviada, ej "215.3K"), no un %.
    local remaining = math.max(0, barMax - barVal)
    if AbbreviateNumbers then
        btn.value:SetText(AbbreviateNumbers(remaining))
    else
        btn.value:SetFormattedText("%d", remaining)
    end
    btn.desc:SetText(desc)
    btn._mode, btn._label, btn._desc2 = mode, label, desc
    btn._barMin, btn._barMax, btn._barVal, btn._restedXP = barMin, barMax, barVal, restedXP
end
ns.UpdateMinimapRing = UpdateRing

-- ==========================================================================
-- REFRESH / APPLY (posicion, escala, visibilidad)
-- ==========================================================================
local function RefreshMinimap()
    local p = P()
    if not p then return end
    local root = mm.root
    -- Puede llamarse desde core.lua (RefreshAll en ADDON_LOADED) ANTES de que
    -- Init() de este archivo haya corrido (su frame de eventos se registra
    -- despues del de core.lua, asi que ese ADDON_LOADED le llega segundo).
    if not root then return end
    -- B3 (mismo fix que unidades/portraits/auras, ver CompensateScale en core.lua):
    -- sin esto, cambiar la escala con la rueda "movia" el minimapa porque los
    -- offsets de SetPoint quedaban calculados para la escala VIEJA.
    if ns.CompensateScale then ns.CompensateScale(p) end
    root:SetScale(p.scale or 1)
    local parent = _G[p.anchorFrame]
    if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
    root:ClearAllPoints()
    root:SetPoint(p.point, parent, p.relativePoint, p.offsetX, p.offsetY)
    root:SetShown(p.enabled ~= false)
    do
        local locked_edit = ns.IsUnlocked()
        -- root (el cuadrado grande del marco) solo necesita mouse para poder
        -- arrastrarlo/soltarlo DESDE su zona vacia mientras se edita.
        root:EnableMouse(locked_edit)
        if root.editBG then
            root.editBG:SetShown(locked_edit and not ns.GetDB().hideEditOutline)
            -- A pedido del usuario: en Lock, el outline debe BLOQUEAR el minimapa
            -- real (que esta debajo, con su propio zoom/click nativo) para poder
            -- arrastrarlo/escalarlo sin que la rueda haga zoom al mapa por error.
            root.editBG:EnableMouse(locked_edit)
            root.editBG:EnableMouseWheel(locked_edit)
        end
        -- "Hide in preview (Lock only)" (Options.lua Editing, lista LH): oculta
        -- el minimapa SOLO mientras se edita, sin tocar showEnabled real.
        if locked_edit and ns.GetDB().lockHide and ns.GetDB().lockHide.minimap then
            root:Hide()
        end
    end

    LayoutShape()

    if mm.compass then mm.compass:SetShown(p.showCompass and true or false) end
    if mm.coords then mm.coords:SetShown(p.showCoordinates and true or false) end
    if mm.LayoutCoords then mm.LayoutCoords() end
    if mm.UpdateMail then mm.UpdateMail() end
    if mm.LayoutMail then mm.LayoutMail() end
    if mm.LayoutTracking then mm.LayoutTracking() end
    LayoutEye()
    LayoutBelowMinimapWidget()
    if mm.LayoutDismount then mm.LayoutDismount() end
    if mm.dismountTex then
        mm.dismountTex:SetTexture((p.dismountTexture and p.dismountTexture ~= "" and p.dismountTexture) or DISMOUNT_TEX)
    end
    if mm.ringBackdropTex then
        mm.ringBackdropTex:SetTexture((p.ringBackdropTexture and p.ringBackdropTexture ~= "" and p.ringBackdropTexture) or RING_BACKDROP_TEX)
    end
    if mm.ringButtonTex then
        mm.ringButtonTex:SetTexture((p.ringButtonTexture and p.ringButtonTexture ~= "" and p.ringButtonTexture) or BUTTON_TEX)
    end
    UpdateRing()
end
ns.RefreshMinimap = RefreshMinimap

-- ==========================================================================
-- INICIALIZACION
-- ==========================================================================
local initialized = false
local function Init()
    if initialized then return end
    if not ns.GetDB() then return end
    if not (ns.GetDB().minimap) then return end
    initialized = true

    -- Migracion puntual (2026-07-21): el boton de tracking se guardo con su primer
    -- default (-82,82, copiado del eye) antes de reposicionarse "al lado de las
    -- coordenadas" (-26,23) un commit despues -- FillDefaults solo llena si esta nil,
    -- asi que quien ya lo cargo una vez se quedo pegado en el default viejo para
    -- siempre. Como el feature tiene minutos de vida, es seguro asumir que nadie
    -- movio esto a mano todavia: si sigue EXACTO en el valor viejo, lo actualiza.
    do
        local p = ns.GetDB().minimap
        if p.trackingOffsetX == -82 and p.trackingOffsetY == 82 then
            p.trackingOffsetX, p.trackingOffsetY = -26, 23
        end
    end

    CreateShape()
    CreateCompass()
    CreateCoordinates()
    CreateMail()
    CreateTracking()
    CreateDismountButton()
    CreateRing()
    RefreshMinimap()

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_XP_UPDATE")
    f:RegisterEvent("UPDATE_EXHAUSTION")
    f:RegisterEvent("UPDATE_FACTION")
    f:RegisterEvent("HONOR_XP_UPDATE")
    f:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
    f:SetScript("OnEvent", function() UpdateRing() end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 ~= ADDON then return end
    Init()
end)
