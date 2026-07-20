-- ==========================================================================
-- ProfilesApply.lua — "Aplicar Perfiles": instala los presets del setup Gonkast en los
-- addons detectados, reemplazando su SavedVariables con la copia de Profiles\ (capturada de
-- forma segura por Profiles_Pre/Post) y recargando la UI para que cada addon la relea.
-- DESTRUCTIVO (sobrescribe la config actual de esos addons) → confirma antes.
-- Carga tras core/Profiles_Post/_Exports en el toc. Todo con pcall/guardas.
--
-- HUD de Edit Mode de Blizzard (2026-07-15, CAMBIO DE ENFOQUE): ANTES se auto-importaba via
-- `EditModeManagerFrame:ImportLayout` (securecall) — funcionaba, pero SIEMPRE disparaba un
-- LUA_WARNING ruidoso ("compare secret number... tainted by MyCustomFrames") porque ImportLayout
-- hace un refresh interno (UpdateSystems) que toca CompactUnitFrame, y la llamada se origina
-- desde un boton nuestro (tainted by MyCustomFrames) sin importar que se llame por securecall.
-- El usuario pidio eliminar el warning del todo -> unica forma real: NO llamar ImportLayout
-- desde nuestro codigo. Ahora solo MOSTRAMOS el string exportado (`ns.ProfExports.blizzard`) en
-- una caja copiable para que el usuario lo pegue A MANO en el importador NATIVO de Blizzard
-- (Esc > Edit Mode > Import Layout) — esa llamada la dispara codigo de Blizzard, sin taint.
-- ==========================================================================
local ADDON, ns = ...

-- global de SavedVariables → addon que lo posee (para detectar si esta instalado).
local OWNER = {
    Bartender4DB           = "Bartender4",
    CHATTYNATOR_CONFIG     = "Chattynator",
    CHATTYNATOR_MESSAGE_LOG= "Chattynator",
    DynamicCamDB           = "DynamicCam",
    minZoomValues          = "DynamicCam",
    MasqueDB               = "Masque",
}
-- Etiqueta + perfil objetivo (solo informativo; el SV reemplazado ya trae su perfil activo).
local INFO = {
    Bartender4 = "Bartender4 (profile: GonkastUI)",
    DynamicCam = "DynamicCam (profile: default)",
    Masque     = "Masque (default profile + \"Azerite HEX\" skin)",
    Chattynator= "Chattynator (default)",
}

local function loaded(addon)
    if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(addon) end
    return IsAddOnLoaded and IsAddOnLoaded(addon)
end

-- Que addons con copia estan instalados/cargados?
local function DetectAddons()
    local seen, list = {}, {}
    for g, addon in pairs(OWNER) do
        if ns.Profiles and ns.Profiles[g] ~= nil and loaded(addon) and not seen[addon] then
            seen[addon] = true
            list[#list + 1] = addon
        end
    end
    return list, seen
end

-- El string exportado del layout HUD de Blizzard ("MCF1:..." no, este es el formato propio de
-- C_EditMode: un string opaco de Blizzard, NO nuestro Serialize). Solo lectura.
function ns.GetBlizzardHUDCode()
    local str = ns.ProfExports and ns.ProfExports.blizzard
    if str and str ~= "" then return str end
    return nil
end

-- Popup simple y AUTOCONTENIDO (no depende de ns.UI/Options.lua: este archivo carga ANTES en
-- el toc) con un editbox multilinea de solo-copia + instrucciones para importar el HUD a mano
-- por el importador NATIVO de Blizzard. Reusado por Setup.lua (wizard) y por el boton del menu
-- principal (grupo "Setup").
local hudPopup
function ns.ShowBlizzardHUDCode()
    local code = ns.GetBlizzardHUDCode()
    if not code then
        print("|cffffcc00[MCF]|r No Blizzard HUD layout bundled.")
        return
    end
    if not hudPopup then
        local p = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        p:SetSize(480, 320); p:SetPoint("CENTER"); p:SetFrameStrata("FULLSCREEN_DIALOG")
        p:EnableMouse(true); p:SetMovable(true)
        p:RegisterForDrag("LeftButton")
        p:SetScript("OnDragStart", p.StartMoving); p:SetScript("OnDragStop", p.StopMovingOrSizing)
        local bg = p:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(); bg:SetColorTexture(0.04, 0.04, 0.05, 0.97)
        local ttl = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        ttl:SetPoint("TOPLEFT", 14, -12)
        ttl:SetText("Blizzard Edit Mode HUD layout")
        local close = CreateFrame("Button", nil, p, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 2, 2)
        local hint = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 14, -34)
        hint:SetWidth(452); hint:SetJustifyH("LEFT"); hint:SetWordWrap(true)
        hint:SetText("Copy this code (Ctrl+C, already selected), then in-game: Esc > Edit Mode > "
            .. "Import Layout > paste it > Import. Doing it this way (instead of automatically) "
            .. "avoids a harmless-but-noisy taint warning in the error log.")
        local box = CreateFrame("Frame", nil, p, "BackdropTemplate")
        box:SetPoint("TOPLEFT", 14, -84); box:SetPoint("BOTTOMRIGHT", -14, 14)
        local boxbg = box:CreateTexture(nil, "BACKGROUND")
        boxbg:SetAllPoints(); boxbg:SetColorTexture(0, 0, 0, 0.5)
        local sf = CreateFrame("ScrollFrame", nil, box)
        sf:SetPoint("TOPLEFT", 4, -4); sf:SetPoint("BOTTOMRIGHT", -4, 4)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetFontObject(ChatFontNormal)
        eb:SetMaxLetters(999999); eb:SetWidth(430)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        sf:SetScrollChild(eb)
        sf:EnableMouseWheel(true)
        sf:SetScript("OnMouseWheel", function(self, d)
            local mx = math.max((eb:GetHeight() or 0) - (self:GetHeight() or 0), 0)
            self:SetVerticalScroll(math.min(math.max(self:GetVerticalScroll() - d * 30, 0), mx))
        end)
        box:EnableMouse(true); box:SetScript("OnMouseDown", function() eb:SetFocus() end)
        sf:EnableMouse(true); sf:SetScript("OnMouseDown", function() eb:SetFocus() end)
        p.eb = eb
        p:Hide()
        hudPopup = p
    end
    hudPopup.eb:SetText(code)
    hudPopup:Show()
    hudPopup.eb:SetFocus(); hudPopup.eb:HighlightText()
end

-- Variante FILTRADA de DoApply para el wizard de primera instalacion (Setup.lua): solo toca
-- los addons marcados en `selected` (tabla addon -> true). Sin popup de confirmacion (el wizard
-- ya es la confirmacion) y sin avisos por chat (el wizard muestra su propio resumen). El HUD de
-- Blizzard NO se toca aca (ver comentario de cabecera): Setup.lua lo ofrece aparte, a mano, con
-- ns.ShowBlizzardHUDCode().
function ns.ApplyProfilesFiltered(selected)
    local db = ns.GetDB and ns.GetDB()
    local copy = ns.DeepCopy or function(t) return t end
    local applied = {}
    local _, seen = DetectAddons()
    for g, addon in pairs(OWNER) do
        if selected[addon] and seen[addon] and ns.Profiles and ns.Profiles[g] ~= nil then
            _G[g] = copy(ns.Profiles[g])
            applied[addon] = true
        end
    end
    return applied
end

-- Etiquetas legibles por addon (para el wizard). Solo lectura: no modificar desde afuera.
ns.ProfilesInfo = INFO

-- Ejecuta el reemplazo (tras confirmar) y recarga.
local function DoApply()
    local db = ns.GetDB and ns.GetDB()
    local copy = ns.DeepCopy or function(t) return t end
    local applied = {}
    local _, seen = DetectAddons()
    for g, addon in pairs(OWNER) do
        if seen[addon] and ns.Profiles and ns.Profiles[g] ~= nil then
            _G[g] = copy(ns.Profiles[g])   -- reemplaza el SV vivo con la copia (se relee al recargar)
            applied[addon] = true
        end
    end
    for a in pairs(applied) do print("|cff00ff00[MCF]|r Profile queued: " .. (INFO[a] or a)) end
    if ns.GetBlizzardHUDCode() then
        print("|cff00ff00[MCF]|r Blizzard HUD layout available — type |cffffff00/mcfhud|r to get the import code.")
    end
    -- NO auto-ReloadUI: escribir los SV de otros addons contamina la ejecucion; un ReloadUI()
    -- desde ese contexto contaminado dispara ADDON_ACTION_BLOCKED 'Reload()'. La unica via
    -- fiable es que el usuario recargue a mano. Avisamos claramente (texto + popup sin auto-reload).
    print("|cff00ff00[MCF]|r Profiles queued. Type |cffffff00/reload|r now to apply them.")
    if StaticPopup_Show then StaticPopup_Show("MCF_APPLY_PROFILES_DONE") end
end

-- Aviso de "recarga a mano" (no llama a ReloadUI: seria bloqueado por taint).
-- NO reasignar el global StaticPopupDialogs (= StaticPopupDialogs or {}): reasignar ese global
-- COMPARTIDO lo TAINTEA "by MyCustomFrames", y como lo lee todo el UI de Blizzard (panel manager,
-- micro botones), ENVENENA el sistema seguro/secreto entero (ADDON_ACTION_FORBIDDEN en ESC:
-- SpellStopCasting/ClearTarget, "compare a secret number" en el personaje). Solo INDEXAR es seguro
-- (StaticPopupDialogs siempre existe en WoW). CONFIRMADO via taint.log.
StaticPopupDialogs["MCF_APPLY_PROFILES_DONE"] = {
    text = "Profiles queued.\n\nType |cffffff00/reload|r in chat to apply them (a manual reload is required).",
    button1 = OKAY or "Okay",
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

-- Confirmacion (destructivo).
StaticPopupDialogs["MCF_APPLY_PROFILES"] = {
    text = "Apply the Gonkast preset profiles to the detected addons?\n\nThis REPLACES their current configuration with the bundled profiles and reloads the UI.\n\n%s",
    button1 = ACCEPT or "Accept", button2 = CANCEL or "Cancel",
    OnAccept = function() DoApply() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function ns.ApplyProfiles()
    local list = DetectAddons()
    if #list == 0 then
        print("|cffffcc00[MCF]|r No supported addons with bundled profiles detected.")
        return
    end
    local lines = {}
    for _, a in ipairs(list) do lines[#lines + 1] = "- " .. (INFO[a] or a) end
    StaticPopup_Show("MCF_APPLY_PROFILES", table.concat(lines, "\n"))
end

-- Estado para el menu: lista de addons detectados con copia.
function ns.ProfilesStatus()
    local list = DetectAddons()
    return list
end

SLASH_MCFHUD1 = "/mcfhud"
SlashCmdList["MCFHUD"] = function() ns.ShowBlizzardHUDCode() end

-- ==========================================================================
-- Bartender4: "usar este perfil para CUALQUIER personaje nuevo de la cuenta" (2026-07-16,
-- pedido por el usuario en la pagina 7 del Setup Wizard). Distinto del boton "Apply to this
-- character" (que escribe `profileKeys[charKey]` directo en el SavedVariables crudo, sin
-- garantia de timing): esto usa la API VIVA de AceDB (`Bartender4.db:SetProfile`), que NO
-- depende de si Bartender4 carga antes o despues de MyCustomFrames.
--
-- POR QUE NO alcanza con tocar el SavedVariables crudo aca: Bartender4 llama
-- `AceDB:New("Bartender4DB", defaults)` (SIN 3er argumento defaultProfile) en su propio
-- OnInitialize — eso resuelve el perfil del personaje UNA sola vez, en el momento en que
-- Bartender4 carga (que en la practica siempre pasa en el MISMO orden relativo a este addon,
-- sesion tras sesion). Si escribieramos `profileKeys[charKey]` en el SavedVariables crudo
-- ANTES de que Bartender4 lo lea, dependeriamos de cargar antes que Bartender4 SIEMPRE — fragil
-- y dificil de garantizar. La API viva, en cambio, se puede llamar en CUALQUIER momento despues
-- de que Bartender4 ya inicializo (PLAYER_LOGIN es tarde de sobra para eso), y
-- `AceDBObject:SetProfile(name)` tanto cambia el perfil EN VIVO como escribe
-- `profileKeys[charKey]` en el SavedVariables para la proxima sesion — mismo efecto que el boton
-- manual de la pagina 7, pero sin la carrera de timing.
local function ApplyBartenderAutoProfile()
    local d = ns.GetDB and ns.GetDB()
    local wanted = d and d.bartenderAutoProfile
    if not wanted or wanted == "" then return end
    local addon = _G.Bartender4
    if not (addon and addon.db and addon.db.GetCurrentProfile and addon.db.SetProfile) then return end
    local charKey = (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?")
    d.bartenderAutoApplied = d.bartenderAutoApplied or {}
    -- Ya se aplico una vez para ESTE personaje: no forzar de nuevo (si el usuario cambio a mano
    -- a otro perfil despues, respetamos su eleccion en vez de pisarla en cada login).
    if d.bartenderAutoApplied[charKey] then return end
    local ok, cur = pcall(addon.db.GetCurrentProfile, addon.db)
    if not ok then return end
    -- Solo forzar si el personaje NO tiene perfil propio configurado todavia: AceDB usa el
    -- charKey como nombre de perfil de fallback (ver initdb en AceDB-3.0) cuando no hay entrada
    -- previa en profileKeys — eso es la señal de "personaje nunca configurado".
    if cur == charKey and cur ~= wanted then
        pcall(addon.db.SetProfile, addon.db, wanted)
    end
    d.bartenderAutoApplied[charKey] = true
end

local btAutoFrame = CreateFrame("Frame")
btAutoFrame:RegisterEvent("PLAYER_LOGIN")
btAutoFrame:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if C_Timer and C_Timer.After then
        C_Timer.After(2, function() pcall(ApplyBartenderAutoProfile) end)
    else
        pcall(ApplyBartenderAutoProfile)
    end
end)
