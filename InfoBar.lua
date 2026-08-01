--[[Perfy has instrumented this file]] local Perfy_GetTime, Perfy_Trace, Perfy_Trace_Passthrough = Perfy_GetTime, Perfy_Trace, Perfy_Trace_Passthrough; Perfy_Trace(Perfy_GetTime(), "Enter", "(main chunk) MyCustomFrames/InfoBar.lua"); --[[Perfy has instrumented this file]] local Perfy_GetTime, Perfy_Trace, Perfy_Trace_Passthrough = Perfy_GetTime, Perfy_Trace, Perfy_Trace_Passthrough; Perfy_Trace(Perfy_GetTime(), "Enter", "(main chunk) MyCustomFrames/InfoBar.lua"); -- ==========================================================================
-- MyCustomFrames - InfoBar.lua
-- INFO BAR (hora, fps, ms, zona + boton reloj-calendario + fondo decorativo).
-- Extraido de core.lua (mismo motivo/patron que Units.lua/Portraits.lua/Auras.lua),
-- usa ns.GetDB()/ns.IsUnlocked() en vez de los locals db/unlocked de core.
-- Carga DESPUES de core.lua, Units.lua, Portraits.lua y Auras.lua en el toc.
-- ==========================================================================
local ADDON, ns = ...

local infobar   -- frame del info bar (unico); ns.infobar = infobar se sincroniza en CreateInfoBar
-- ==========================================================================
-- INFO BAR: creacion y logica
-- ==========================================================================
local function InfoZoneText() Perfy_Trace(Perfy_GetTime(), "Enter", "InfoZoneText MyCustomFrames/InfoBar.lua:14:6"); Perfy_Trace(Perfy_GetTime(), "Enter", "InfoZoneText MyCustomFrames/InfoBar.lua:14:6");
    local zone = GetMinimapZoneText() or ""
    if type(zone) ~= "string" then zone = "" end
    if #zone > 25 then zone = zone:sub(1, 25) .. "..." end
    Perfy_Trace(Perfy_GetTime(), "Leave", "InfoZoneText MyCustomFrames/InfoBar.lua:14:6"); Perfy_Trace(Perfy_GetTime(), "Leave", "InfoZoneText MyCustomFrames/InfoBar.lua:14:6"); return zone
end

local function InfoTimeText() Perfy_Trace(Perfy_GetTime(), "Enter", "InfoTimeText MyCustomFrames/InfoBar.lua:21:6"); Perfy_Trace(Perfy_GetTime(), "Enter", "InfoTimeText MyCustomFrames/InfoBar.lua:21:6");
    local h, m = 0, 0
    pcall(function() Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:23:10"); Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:23:10"); h, m = GetGameTime() Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:23:10"); Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:23:10"); end)
    h = h or 0; m = m or 0
    local suffix = "AM"
    if h >= 12 then suffix = "PM"; if h > 12 then h = h - 12 end
    elseif h == 0 then h = 12 end
    return Perfy_Trace_Passthrough("Leave", "InfoTimeText MyCustomFrames/InfoBar.lua:21:6", Perfy_Trace_Passthrough("Leave", "InfoTimeText MyCustomFrames/InfoBar.lua:21:6", string.format("%d:%02d %s", h, m, suffix)))
end

local function UpdateInfoBarValues() Perfy_Trace(Perfy_GetTime(), "Enter", "UpdateInfoBarValues MyCustomFrames/InfoBar.lua:31:6"); Perfy_Trace(Perfy_GetTime(), "Enter", "UpdateInfoBarValues MyCustomFrames/InfoBar.lua:31:6");
    if not (infobar and ns.GetDB() and ns.GetDB().infobar) then Perfy_Trace(Perfy_GetTime(), "Leave", "UpdateInfoBarValues MyCustomFrames/InfoBar.lua:31:6"); Perfy_Trace(Perfy_GetTime(), "Leave", "UpdateInfoBarValues MyCustomFrames/InfoBar.lua:31:6"); return end
    local p = ns.GetDB().infobar
    infobar.zone.fs:SetText(InfoZoneText())
    infobar.time.fs:SetText(InfoTimeText())
    local fps = ns.safeVal(GetFramerate) or 0
    infobar.fps.fs:SetFormattedText("%.0f FPS", fps)
    local world = 0; pcall(function() Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:38:27"); Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:38:27"); local _, _, _, w = GetNetStats(); world = w or 0 Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:38:27"); Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:38:27"); end)
    infobar.ms.fs:SetFormattedText("%.0f MS", world)
    -- Ajusta el tamano de cada elemento a su texto (area de arrastre/mouse).
    local hgt = (p.fontSize or 14) + 6
    for _, el in ipairs({ infobar.zone, infobar.time, infobar.fps, infobar.ms }) do
        el:SetSize(math.max((el.fs:GetStringWidth() or 10) + 8, 12), hgt)
    end
Perfy_Trace(Perfy_GetTime(), "Leave", "UpdateInfoBarValues MyCustomFrames/InfoBar.lua:31:6"); Perfy_Trace(Perfy_GetTime(), "Leave", "UpdateInfoBarValues MyCustomFrames/InfoBar.lua:31:6"); end

local function InfoBarPlace() Perfy_Trace(Perfy_GetTime(), "Enter", "InfoBarPlace MyCustomFrames/InfoBar.lua:47:6"); Perfy_Trace(Perfy_GetTime(), "Enter", "InfoBarPlace MyCustomFrames/InfoBar.lua:47:6");
    local p = ns.GetDB().infobar
    ns.CompensateScale(p, "simple")   -- B3: reancla offset si la escala cambio
    local parent = _G[p.anchor]
    if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
    infobar.root:ClearAllPoints()
    infobar.root:SetPoint(p.point, parent, p.relPoint, p.offsetX, p.offsetY)
    infobar.root:SetFrameStrata(p.strata)
Perfy_Trace(Perfy_GetTime(), "Leave", "InfoBarPlace MyCustomFrames/InfoBar.lua:47:6"); Perfy_Trace(Perfy_GetTime(), "Leave", "InfoBarPlace MyCustomFrames/InfoBar.lua:47:6"); end

local function RefreshInfoBar() Perfy_Trace(Perfy_GetTime(), "Enter", "RefreshInfoBar MyCustomFrames/InfoBar.lua:57:6"); Perfy_Trace(Perfy_GetTime(), "Enter", "RefreshInfoBar MyCustomFrames/InfoBar.lua:57:6");
    if not (infobar and ns.GetDB() and ns.GetDB().infobar) then Perfy_Trace(Perfy_GetTime(), "Leave", "RefreshInfoBar MyCustomFrames/InfoBar.lua:57:6"); Perfy_Trace(Perfy_GetTime(), "Leave", "RefreshInfoBar MyCustomFrames/InfoBar.lua:57:6"); return end
    local p, ib = ns.GetDB().infobar, infobar
    ib.root:SetSize(math.max(p.bgWidth, 60), math.max((p.fontSize or 14) + 24, 30))
    ib.root:SetScale((p.scale or 1) * ns.ResScale())   -- escala general del info bar
    InfoBarPlace()

    -- Fondo decorativo (atlas del juego).
    if p.showBg then
        -- Textura custom (.tga/.blp) o, si se escribe un nombre sin extension, un atlas.
        local btex = (p.bgTexture and p.bgTexture ~= "" and p.bgTexture) or ns.INFOBAR_BG_TEX
        local ext = tostring(btex):sub(-4):lower()
        if ext == ".tga" or ext == ".blp" then
            pcall(function() Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:70:18"); Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:70:18"); ib.bg:SetTexture(btex) Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:70:18"); Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:70:18"); end)
        else
            pcall(function() Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:72:18"); Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:72:18"); ib.bg:SetAtlas(btex, false) Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:72:18"); Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:72:18"); end)
        end
        ib.bg:SetSize(p.bgWidth, p.bgHeight)
        ib.bg:ClearAllPoints(); ib.bg:SetPoint("CENTER", ib.root, "CENTER", p.bgOffsetX, p.bgOffsetY)
        ib.bg:SetAlpha(p.bgAlpha); ib.bg:Show()
    else
        ib.bg:Hide()
    end

    local gtc = p.textColor or { r = 1, g = 0.82, b = 0 }
    -- B9: cada elemento usa su Color/Alpha/Size propios; si son nil, cae al global.
    local function setupEl(el, show, prefix) Perfy_Trace(Perfy_GetTime(), "Enter", "setupEl MyCustomFrames/InfoBar.lua:83:10"); Perfy_Trace(Perfy_GetTime(), "Enter", "setupEl MyCustomFrames/InfoBar.lua:83:10");
        local size = p[prefix .. "Size"] or p.fontSize or 14
        local col  = p[prefix .. "Color"] or gtc
        local a    = p[prefix .. "Alpha"]; if a == nil then a = 1 end
        el.fs:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
        el.fs:SetTextColor(col.r, col.g, col.b, a)
        el._xKey, el._yKey = prefix .. "X", prefix .. "Y"
        el:ClearAllPoints()
        el:SetPoint("CENTER", ib.root, "CENTER", p[el._xKey] or 0, p[el._yKey] or 0)
        el:SetShown(show)
        -- Mouse: el reloj/calendario siempre; el resto solo en preview (arrastre).
        el:EnableMouse(ns.IsUnlocked() or el._isClock or false)
    Perfy_Trace(Perfy_GetTime(), "Leave", "setupEl MyCustomFrames/InfoBar.lua:83:10"); Perfy_Trace(Perfy_GetTime(), "Leave", "setupEl MyCustomFrames/InfoBar.lua:83:10"); end
    setupEl(ib.zone, p.showZone, "zone")
    setupEl(ib.time, p.showTime, "time")
    setupEl(ib.fps,  p.showFps,  "fps")
    setupEl(ib.ms,   p.showMs,   "ms")

    -- (Botones de calendario y mochila ELIMINADOS: el calendario ahora se abre clickeando el reloj.)

    if ib.editBG then ib.editBG:SetShown(ns.IsUnlocked() and not ns.GetDB().hideEditOutline) end
    -- "Hide in preview (Lock only)" (lockHide.infobar): oculta SOLO en preview.
    if ns.IsUnlocked() and ns.GetDB().lockHide and ns.GetDB().lockHide.infobar then
        ib.root:Hide()
        Perfy_Trace(Perfy_GetTime(), "Leave", "RefreshInfoBar MyCustomFrames/InfoBar.lua:57:6"); Perfy_Trace(Perfy_GetTime(), "Leave", "RefreshInfoBar MyCustomFrames/InfoBar.lua:57:6"); return
    end
    ib.root:SetShown(p.enabled or ns.IsUnlocked())
    UpdateInfoBarValues()
Perfy_Trace(Perfy_GetTime(), "Leave", "RefreshInfoBar MyCustomFrames/InfoBar.lua:57:6"); Perfy_Trace(Perfy_GetTime(), "Leave", "RefreshInfoBar MyCustomFrames/InfoBar.lua:57:6"); end
ns.RefreshInfoBar = RefreshInfoBar

-- Guarda la posicion actual del root (mover TODO junto).
local function SaveInfoRootPos() Perfy_Trace(Perfy_GetTime(), "Enter", "SaveInfoRootPos MyCustomFrames/InfoBar.lua:115:6"); Perfy_Trace(Perfy_GetTime(), "Enter", "SaveInfoRootPos MyCustomFrames/InfoBar.lua:115:6");
    local p = ns.GetDB().infobar
    local parent = _G[p.anchor]
    if type(parent) ~= "table" or type(parent.GetObjectType) ~= "function" then parent = UIParent end
    local s, ps = infobar.root:GetEffectiveScale(), parent:GetEffectiveScale()
    local fx, fy = infobar.root:GetCenter()
    local px, py = parent:GetCenter()
    if fx and px then
        p.point, p.relPoint = "CENTER", "CENTER"
        p.offsetX = (fx * s - px * ps) / s
        p.offsetY = (fy * s - py * ps) / s
    end
Perfy_Trace(Perfy_GetTime(), "Leave", "SaveInfoRootPos MyCustomFrames/InfoBar.lua:115:6"); Perfy_Trace(Perfy_GetTime(), "Leave", "SaveInfoRootPos MyCustomFrames/InfoBar.lua:115:6"); end

local function MakeInfoElement(root, isClock) Perfy_Trace(Perfy_GetTime(), "Enter", "MakeInfoElement MyCustomFrames/InfoBar.lua:129:6"); Perfy_Trace(Perfy_GetTime(), "Enter", "MakeInfoElement MyCustomFrames/InfoBar.lua:129:6");
    local el = CreateFrame(isClock and "Button" or "Frame", nil, root)
    el:SetSize(40, 20)
    el:SetMovable(true)
    el:RegisterForDrag("LeftButton")
    el:EnableMouse(false)
    el._isClock = isClock
    local fs = el:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    fs:SetPoint("CENTER")
    el.fs = fs

    el:SetScript("OnDragStart", function(self) Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:141:32"); Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:141:32");
        if not ns.IsUnlocked() or InCombatLockdown() then Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:141:32"); Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:141:32"); return end
        if ns.GetDB().infobar.moveTogether then infobar.root:StartMoving()
        else self:StartMoving() end
    Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:141:32"); Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:141:32"); end)
    el:SetScript("OnDragStop", function(self) Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:146:31"); Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:146:31");
        if ns.GetDB().infobar.moveTogether then
            infobar.root:StopMovingOrSizing()
            SaveInfoRootPos()
        else
            self:StopMovingOrSizing()
            local p = ns.GetDB().infobar
            local ex, ey = self:GetCenter()
            local rx, ry = infobar.root:GetCenter()
            if ex and rx and self._xKey then
                p[self._xKey] = ex - rx
                p[self._yKey] = ey - ry
            end
        end
        RefreshInfoBar()
        if ns.OnDragStopped then ns.OnDragStopped(INFOBAR_KEY) end
    Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:146:31"); Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:146:31"); end)
    Perfy_Trace(Perfy_GetTime(), "Leave", "MakeInfoElement MyCustomFrames/InfoBar.lua:129:6"); Perfy_Trace(Perfy_GetTime(), "Leave", "MakeInfoElement MyCustomFrames/InfoBar.lua:129:6"); return el
end

local function CreateInfoBar() Perfy_Trace(Perfy_GetTime(), "Enter", "CreateInfoBar MyCustomFrames/InfoBar.lua:166:6"); Perfy_Trace(Perfy_GetTime(), "Enter", "CreateInfoBar MyCustomFrames/InfoBar.lua:166:6");
    local root = CreateFrame("Frame", "MyCF_InfoBar", UIParent)
    root:SetSize(360, 40)
    root:SetPoint("TOP", UIParent, "TOP", 0, -4)
    root:SetMovable(true)
    root:RegisterForDrag("LeftButton")
    root:EnableMouse(false)

    local editBG = ns.MakeEditHighlight(root, "Info Bar")

    local bg = root:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetPoint("CENTER")

    local ib = { root = root, editBG = editBG, bg = bg }
    ib.zone = MakeInfoElement(root, false)
    ib.time = MakeInfoElement(root, true)   -- reloj: display + tooltip de hora (calendario = boton aparte)
    ib.fps  = MakeInfoElement(root, false)
    ib.ms   = MakeInfoElement(root, false)

    -- (Botones de calendario y mochila ELIMINADOS. El calendario se abre clickeando el reloj.)

    -- El root tambien se puede arrastrar (mover TODO) por su zona libre.
    root:SetScript("OnDragStart", function(self) Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:188:34"); Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:188:34");
        if ns.IsUnlocked() and not InCombatLockdown() then self:StartMoving() end
    Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:188:34"); Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:188:34"); end)
    root:SetScript("OnDragStop", function(self) Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:191:33"); Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:191:33");
        self:StopMovingOrSizing()
        if ns.SnapFrameToGrid then ns.SnapFrameToGrid(self) end
        SaveInfoRootPos(); RefreshInfoBar()
        if ns.OnDragStopped then ns.OnDragStopped(INFOBAR_KEY) end
    Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:191:33"); Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:191:33"); end)
    ns.AttachScaleWheel(root, function() Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:197:30"); Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:197:30"); return Perfy_Trace_Passthrough("Leave", "(anonymous) MyCustomFrames/InfoBar.lua:197:30", Perfy_Trace_Passthrough("Leave", "(anonymous) MyCustomFrames/InfoBar.lua:197:30", ns.GetDB().infobar)) end, function() Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:197:243"); Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:197:72"); if ns.RefreshInfoBar then ns.RefreshInfoBar() end Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:197:72"); Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:197:243"); end)

    -- Reloj: tooltip (reino/hora) + CLICK abre el calendario (patron de AzeriteUI Info.lua:
    -- Time_OnClick = ToggleCalendar() con guard InCombatLockdown). Es seguro ahora que la fuente
    -- real del taint global (`StaticPopupDialogs = StaticPopupDialogs or {}` en ProfilesApply, quitada
    -- en la tanda 8) ya no envenena StaticPopupDialogs: cargar Blizzard_Calendar on-demand lee una
    -- tabla LIMPIA → sin propagacion (por eso AzeriteUI, que nunca taintea ese global, lo hace sin
    -- problema). Guards: solo fuera de combate y si ToggleCalendar existe. NO en preview (ns.IsUnlocked()).
    ib.time:RegisterForClicks("AnyUp")
    ib.time:SetScript("OnClick", function() Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:206:33"); Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:206:33");
        if ns.IsUnlocked() or InCombatLockdown() then Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:206:33"); Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:206:33"); return end
        if ToggleCalendar then pcall(ToggleCalendar) end
    Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:206:33"); Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:206:33"); end)
    ib.time:SetScript("OnEnter", function(self) Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:210:33"); Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:210:33");
        if ns.IsUnlocked() or GameTooltip:IsForbidden() then Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:210:33"); Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:210:33"); return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(TIMEMANAGER_TOOLTIP_TITLE or "Hora", 1, 0.82, 0)
        pcall(function() Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:214:14"); Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:214:14"); GameTooltip:AddDoubleLine(TIMEMANAGER_TOOLTIP_LOCALTIME or "Local", date("%I:%M %p")) Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:214:14"); Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:214:14"); end)
        pcall(function() Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:215:14"); Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:215:14"); local h, m = GetGameTime(); GameTooltip:AddDoubleLine(TIMEMANAGER_TOOLTIP_REALMTIME or "Servidor", string.format("%d:%02d", h or 0, m or 0)) Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:215:14"); Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:215:14"); end)
        pcall(function() Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:216:14"); Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:216:14"); local r = GetRealmName(); if r and r ~= "" then GameTooltip:AddDoubleLine("Reino", r, 1, 1, 1, 1, 1, 1) end Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:216:14"); Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:216:14"); end)
        if ToggleCalendar then
            GameTooltip:AddLine("<" .. (GAMETIME_TOOLTIP_TOGGLE_CALENDAR or "Toggle Calendar") .. ">", 0.1, 1, 0.1)
        end
        GameTooltip:Show()
    Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:210:33"); Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:210:33"); end)
    ib.time:SetScript("OnLeave", function() Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:222:33"); Perfy_Trace(Perfy_GetTime(), "Enter", "(anonymous) MyCustomFrames/InfoBar.lua:222:33"); if not GameTooltip:IsForbidden() then GameTooltip:Hide() end Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:222:33"); Perfy_Trace(Perfy_GetTime(), "Leave", "(anonymous) MyCustomFrames/InfoBar.lua:222:33"); end)

    infobar = ib
    ns.infobar = ib
Perfy_Trace(Perfy_GetTime(), "Leave", "CreateInfoBar MyCustomFrames/InfoBar.lua:166:6"); Perfy_Trace(Perfy_GetTime(), "Leave", "CreateInfoBar MyCustomFrames/InfoBar.lua:166:6"); end

CreateInfoBar()
-- Expuestas para que core.lua (RefreshOutlineNames, SetUnlocked, ToggleEditOutline, CollectSnapLines,
-- GetElementFrame/Explorer, ticker principal) lean el frame del info bar sin depender de este local.
ns.InfoBarPlace = InfoBarPlace
ns.UpdateInfoBarValues = UpdateInfoBarValues


Perfy_Trace(Perfy_GetTime(), "Leave", "(main chunk) MyCustomFrames/InfoBar.lua");
Perfy_Trace(Perfy_GetTime(), "Leave", "(main chunk) MyCustomFrames/InfoBar.lua");