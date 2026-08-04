local ADDON, ns = ...

-- ==========================================================================
-- AURA CONTAINER PROBE (2026-08-03, prep para 12.1.0 "Curse of Ula'tek").
--
-- 12.1.0 vuelve las auras COMPLETAMENTE secretas en combate/mythic+/PvP, y
-- af.buffList/debuffList del AurasFrame nativo del nameplate puede venir
-- como tabla PROHIBIDA (confirmado en vivo, ver el fix en Nameplates.lua
-- HookAurasImportance) -- el sistema viejo de este addon (index-loop +
-- lectura del buffList nativo como señal de "importante") se queda ciego en
-- esas ventanas.
--
-- La solucion sancionada por Blizzard: el widget nuevo AuraContainer/
-- AuraGroup/AuraSlot -- dibuja los iconos EL MISMO, sin exponerle nunca la
-- data secreta al addon. Confirmado leyendo el codigo YA ACTUALIZADO de
-- Platynator (Display/Auras/AurasNext.lua) y EllesmereUI
-- (EllesmereUI_AuraKit.lua + EllesmereUINameplates/EUI_Nameplates_
-- AuraContainers.lua), ambos con soporte real para 12.1.0 en disco:
--
-- 1) local c = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
--    ("ManagedAuraContainer" NO es heredable via CreateFrame -- confirmado
--    en la ronda 1 de este mismo probe, "Couldn't find inherited node".)
-- 2) c:AddAuraGroup(groupKey, filterString, { candidateFilters=..,
--    initializeFrame=fn, maxFrameCount=.., sortMethod=.., layout=.. })
--    -- SE LLAMA ANTES de asociar la unidad (ronda 1 lo hizo al reves, por
--    eso GetAuraGroupFrame devolvio nil).
-- 3) c:SetUnit(unit) -- DESPUES de declarar los grupos.
-- 4) initializeFrame(button) es la UNICA ventana garantizada segura para
--    construir icono/cooldown/cuenta/borde incluso con auras secretas --
--    despues de eso, el motor le mete la proteccion
--    DenyTaintedAccessWhenAurasAreSecret al boton (documentado por
--    EllesmereUI) y cualquier escritura posterior necesita pcall y puede
--    fallar en combate.
-- 5) "Big" vs "Personal" en nameplates: candidateFilters={nameplateShowPersonal=true}
--    en el filtro del grupo, NO leyendo af.buffList/debuffList (que es
--    justo lo prohibido ahora). Blizzard hace la clasificacion, el addon
--    nunca toca el dato.
--
-- Esta ronda 2 del probe corrige el orden (grupo -> SetUnit, no al reves) y
-- agrega un initializeFrame real para confirmar que se llama y con que args.
-- Sigue sin integrar nada en produccion -- una vez confirmado esto en vivo,
-- se escribe la migracion real de Nameplates.lua.
-- ==========================================================================

local function TocVersion()
    local ok, v1, v2, v3, toc = pcall(GetBuildInfo)
    if not ok then return nil end
    return tonumber(toc)
end

ns.IsMidnightNext = (TocVersion() or 0) >= 120100

local function DumpKeys(label, t, limit)
    if type(t) ~= "table" then print(("  %s no es tabla (%s)"):format(label, type(t))); return end
    print(("  %s (primeras %d claves):"):format(label, limit or 20))
    local n = 0
    for k, v in pairs(t) do
        print(("    %s = %s (%s)"):format(tostring(k), tostring(v), type(v)))
        n = n + 1
        if n >= (limit or 20) then print("    ..."); break end
    end
end

local function Probe(unit, filterStr)
    unit = unit or "player"
    filterStr = filterStr or "HELPFUL"
    print(("|cff00ff00[MCF AuraContainer probe]|r unit=%s filter=%s"):format(unit, filterStr))
    local toc = TocVersion()
    print(("  TOC actual = %s (IsMidnightNext = %s)"):format(tostring(toc), tostring(ns.IsMidnightNext)))

    local ok, container = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
    print(("  CreateFrame(\"AuraContainer\", nil, UIParent, \"CustomAuraContainerTemplate\") -> ok=%s")
        :format(tostring(ok)))
    if not ok or not container then
        print("  |cffff5555Sin soporte todavia en este build.|r")
        return
    end

    -- FIX (2026-08-03, "no funciona, pero en EllesmereUI si" -- una
    -- investigacion mas profunda no encontro ningun paso extra en su AK,
    -- solo confirmo que la visibilidad del container NUNCA la maneja el
    -- motor mismo -- depende 100% de IsShown()/IsVisible() en TODA la
    -- cadena hasta UIParent, ya que su OnUpdate interno de parseo/layout
    -- corre en "run-when-visible mode". CreateFrame deberia arrancar
    -- shown por default, pero se confirma explicito por si acaso, ANTES
    -- de declarar el grupo.
    container:Show()
    local okVis, isVisible = pcall(container.IsVisible, container)
    print(("  container:IsShown()=%s IsVisible()=%s (cadena completa hasta UIParent)"):format(
        tostring(select(2, pcall(container.IsShown, container))), tostring(okVis and isVisible)))

    local initCalls = 0
    local lastButton
    local function InitFrame(button)
        initCalls = initCalls + 1
        lastButton = button
        -- FIX (2026-08-03, releida AK.MakeInitializer/ApplyStyleToRegions
        -- completa): NUNCA llamabamos button:SetSize() -- su comentario
        -- literal es "an unsized button renders nothing". layout.elementWidth/
        -- Height en AddAuraGroup solo alimenta la matematica del flow, no el
        -- tamaño real del boton.
        button:SetSize(24, 24)
        local okIcon, icon = pcall(button.CreateTexture, button, nil, "ARTWORK")
        if okIcon and icon then
            icon:SetAllPoints(button)
            pcall(button.SetIcon, button, icon)
        end
        print(("  initializeFrame() llamado #%d, button=%s (SetSize 24x24 + icon=%s)"):format(
            initCalls, tostring(button), tostring(okIcon)))
    end

    -- FIX (2026-08-03, "no vi nada" -- el probe NUNCA le puso tamaño al
    -- container antes de AddAuraGroup, solo al final -- exactamente la
    -- condicion que EllesmereUI_AuraKit.lua:879-882 dice que rompe el
    -- motor interno: "the container needs a renderable rect from the very
    -- first dirty mark". Invalida TODOS los resultados anteriores de este
    -- probe -- se corrige aca.
    container:SetSize(300, 40)
    container:ClearAllPoints()
    container:SetPoint("CENTER", UIParent, "CENTER", 0, 100)

    -- ORDEN CORREGIDO (ronda 2): grupo ANTES que SetUnit. filterStr ahora
    -- parametrizable (2026-08-03, "debia haber un personal debuff" -- el
    -- probe SOLO probaba HELPFUL/buffs, nunca HARMFUL/debuffs). AHORA
    -- TAMBIEN con `layout` DIRECTO en las opciones de AddAuraGroup (2026-08-03,
    -- releida AK.AddGroupToContainer: "layout = g.layout" va en la MISMA
    -- llamada, no solo despues via SetAuraGroupLayout).
    -- FIX (2026-08-03, "en EllesmereUI SI funciona, revisa bien" -- releida
    -- AK.AddGroupToContainer/DebuffCand/NPF_Cand: SIEMPRE pasan
    -- candidateFilters, aunque sea tabla VACIA ({} si no hay exclusiones
    -- configuradas) -- nunca lo omiten/nil. nil vs {} pueden comportarse
    -- distinto en el motor -- probando con tabla vacia explicita.
    local okAdd, err = pcall(container.AddAuraGroup, container, "probe", filterStr, {
        initializeFrame = InitFrame,
        maxFrameCount = 5,
        layout = { elementWidth = 24, elementHeight = 24, elementSpacing = 4, lineSpacing = 4 },
        candidateFilters = {},
    })
    print(("  AddAuraGroup(container, \"probe\", %q, {initializeFrame=fn}) -> ok=%s%s")
        :format(filterStr, tostring(okAdd), (not okAdd) and (" err=" .. tostring(err)) or ""))

    -- FIX CLAVE (2026-08-03, releida EllesmereUI_AuraKit.lua:816-864): el
    -- container necesita SetFlowLayoutAnchorPoint/SetFlowLayoutGrowthDirection
    -- (o los nombres viejos SetAuraLayoutAnchorPoint/...GrowthDirection)
    -- para que el motor interno sepa donde/como acomodar los botones --
    -- container:SetPoint() (mas abajo, no en este probe) es una API
    -- DISTINTA que solo posiciona el frame contenedor en si.
    local fAnchor = container.SetFlowLayoutAnchorPoint or container.SetAuraLayoutAnchorPoint
    local okAnchor = fAnchor and pcall(fAnchor, container, "BOTTOMLEFT")
    local fGrowth = container.SetFlowLayoutGrowthDirection or container.SetAuraLayoutGrowthDirection
    local FD = AnchorUtil and AnchorUtil.FlowDirection
    local okGrowth = fGrowth and FD and pcall(fGrowth, container, FD.Right, FD.Up)
    print(("  SetFlowLayoutAnchorPoint/Old=%s ok=%s | SetFlowLayoutGrowthDirection/Old=%s ok=%s FD=%s"):format(
        tostring(fAnchor ~= nil), tostring(okAnchor), tostring(fGrowth ~= nil), tostring(okGrowth), tostring(FD ~= nil)))

    if type(container.SetUnit) == "function" then
        local okSet, errSet = pcall(container.SetUnit, container, unit)
        print(("  container:SetUnit(%q) -> ok=%s%s"):format(unit, tostring(okSet), (not okSet) and (" err=" .. tostring(errSet)) or ""))
    else
        print("  container.SetUnit no existe como metodo.")
    end

    for _, m in ipairs({ "UpdateAllAuras", "RefreshAuras", "ForceUpdate" }) do
        if type(container[m]) == "function" then
            local okU, errU = pcall(container[m], container)
            print(("  container:%s() -> ok=%s%s"):format(m, tostring(okU), (not okU) and (" err=" .. tostring(errU)) or ""))
        end
    end

    print(("  initializeFrame se llamo %d veces."):format(initCalls))
    if lastButton then DumpKeys("Claves del ultimo button", lastButton, 25) end

    local okC, n = pcall(container.GetNumChildren, container)
    print(("  container:GetNumChildren() -> ok=%s n=%s"):format(tostring(okC), tostring(n)))

    if type(container.GetAuraGroupFrame) == "function" then
        for i = 1, 3 do
            local ok2, child = pcall(container.GetAuraGroupFrame, container, i)
            print(("  GetAuraGroupFrame(container, %d) -> ok=%s child=%s"):format(i, tostring(ok2), tostring(child)))
        end
    end

    -- FIX (2026-08-03, "revisa bien" -- el probe SIEMPRE terminaba con
    -- container:Hide()+SetParent(nil), asi que aunque el motor hubiera
    -- poblado los 10 botones con datos reales, NUNCA se vio en pantalla --
    -- GetAuraGroupFrame puede simplemente no ser la API correcta para
    -- verificar un GRUPO (a lo mejor es para slots). En vez de seguir
    -- confiando en esa API, dejarlo VISIBLE en el centro de la pantalla
    -- unos segundos para confirmar a simple vista si hay iconos reales.
    container:ClearAllPoints()
    container:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    container:SetSize(300, 40)
    container:Show()
    print("  |cff00ff00Container dejado VISIBLE en el centro de la pantalla (un poco arriba) por 8 segundos -- mira si aparece algun icono.|r")
    C_Timer.After(8, function()
        container:Hide()
        container:SetParent(nil)
    end)
end

SLASH_MCFAURACONTAINER1 = "/mcfauracontainer"
SlashCmdList["MCFAURACONTAINER"] = function(msg)
    -- "/mcfauracontainer player HARMFUL" -- 2do argumento opcional, default HELPFUL.
    local unit, filterStr = "player", "HELPFUL"
    if msg and msg ~= "" then
        local a, b = msg:match("^(%S+)%s*(%S*)$")
        unit = a or unit
        if b and b ~= "" then filterStr = b end
    end
    Probe(unit, filterStr)
end
