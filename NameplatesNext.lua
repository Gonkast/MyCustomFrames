local ADDON, ns = ...

-- ==========================================================================
-- NAMEPLATES NEXT (2026-08-03, reescritura completa). Segunda version --
-- la primera (misma idea, menos cuidada) causaba que el click-to-target se
-- rompiera por completo apenas este archivo cargaba, confirmado
-- deshabilitando el sistema entero via .toc. Reescrito con la arquitectura
-- REAL de EllesmereUINameplates.lua (leida directo, no de memoria), pedido
-- explicito del usuario: "no utilices nada de nuestro nameplates
-- anteriores, excepto las texturas".
--
-- Piezas clave copiadas de su codigo (confirmadas via lectura directa):
--   1) frameCache = CreateFramePool("Frame", UIParent, nil, nil, false, factory)
--      -- frame 100% propio, NO hijo de nameplate.UnitFrame. El pool NO
--      lleva reset custom (4to arg nil) -- el reset de estado por-unidad
--      vive en ClearUnit(), llamado ANTES de Release(), no en un resetter
--      del pool.
--   2) SetUnit(): self:SetParent(nameplate); SetPoint("CENTER", nameplate,
--      "CENTER", 0, 0); SetFrameLevel(nameplate:GetFrameLevel()+1); Show();
--      DESPUES llama HideBlizzardFrame.
--   3) HideBlizzardFrame(nameplate, unit): uf:SetAlpha(0) (frame entero,
--      NUNCA reparentado -- reparentar uf rompia el click-to-target segun
--      su propio comentario), hijos NO esenciales a un holder offscreen,
--      hook sobre SetAlpha para que no vuelva a 1.
--   4) ClearUnit(): reset COMPLETO de estado por-unidad + restaura
--      Blizzard, ANTES de devolver el frame al pool.
--   5) Textura: SU health bar es un swatch blanco liso (WHITE8x8) teñido
--      por SetStatusBarColor -- la NUESTRA sigue usando nuestros propios
--      .tga (nameplate_bar.tga/nameplate_backdrop.tga), pedido explicito
--      del usuario ("excepto las texturas").
-- ==========================================================================

if not ns.IsMidnightNext then return end

local A = "Interface\\AddOns\\MyCustomFrames\\Assets\\"
local BAR_TEX = A .. "nameplate_bar.tga"
local BAR_TEXCOORD = { 14/256, 242/256, 14/64, 50/64 }
local BACKDROP_TEX = A .. "nameplate_backdrop.tga"

-- Clasificacion (2026-08-03): mismas texturas AzeriteUI ya usadas por el
-- sistema viejo (Nameplates.lua) -- copiadas a Assets/, se reusan tal cual.
local CLASS_TEX = {
    worldboss = A .. "icon_classification_boss.tga",
    boss      = A .. "icon_classification_boss.tga",
    elite     = A .. "icon_classification_elite.tga",
    rareelite = A .. "icon_classification_rare.tga",
    rare      = A .. "icon_classification_rare.tga",
}

local function P() return ns.GetDB() and ns.GetDB().nameplates end
local function GetHealthSize()
    return (ns.NPLayout and ns.NPLayout.HealthSize and ns.NPLayout.HealthSize(P())) or 92, 24
end

------------------------------------------------------------------------------
-- Amistosos (2026-08-03, "un poquito mas de personalizacion, como maneja
-- ellesmereui los nameplates aliados?"). Su modelo real (EllesmereUINameplates
-- Friendly.lua, leido directo) separa DOS modos, no uno:
--   "healthbar" -- plate completo igual al hostil (barra/cast/nombre), solo
--                  que coloreado por CLASE (jugadores) o verde/amarillo
--                  (NPCs), y gateado por reaccion.
--   "nameonly"  -- SIN barra/cast, solo el nombre flotando -- mucho mas
--                  liviano, pensado para el caso comun (mundo abierto, no
--                  importa la vida exacta de cada aliado).
-- Su version reusa la FontString NATIVA de Blizzard para "nameonly" (truco
-- de override de fuente global) -- no aplica aca: este addon ya reemplaza
-- el plate entero por un frame propio siempre (HideBlizzardFrame corre
-- incondicional), asi que el modo "nameonly" se logra mas simple: el MISMO
-- frame propio, pero ocultando barra/cast y anclando el nombre directo al
-- centro del nameplate en vez de arriba de la barra. Mismo resultado visual,
-- sin duplicar arquitectura.
-- NPCs amistosos: su propio toggle (Blizzard igual muestra sus plates nativos
-- por defecto sin nombrar a todos -- solo replicamos el gate on/off, no el
-- filtro fino de UnitShouldDisplayName, que no aplica: nuestro nombre viene
-- de UnitName, no de la FontString nativa filtrada).
------------------------------------------------------------------------------
local function IsFriendlyUnit(unit)
    local okAtk, canAttack = pcall(UnitCanAttack, "player", unit)
    if not okAtk or canAttack then return false end
    local okSelf, isSelf = pcall(UnitIsUnit, unit, "player")
    if okSelf and isSelf then return false end
    return true
end

-- Categoria de amistoso (2026-08-03, "separarlo de jugador aliado, npc
-- aliado, y pet"): UnitIsPlayer separa jugador de todo el resto; dentro de
-- "todo el resto", UnitPlayerControlled distingue pet/guardian/totem/vehiculo
-- CONTROLADO por un jugador (cualquiera, no solo el tuyo) de un NPC de
-- verdad (vendedor, guardia, escolta) -- mismo heuristico que usan
-- Platynator/EllesmereUI para esta misma distincion.
local function UnitCategory(unit)
    local okP, isPlayer = pcall(UnitIsPlayer, unit)
    if okP and isPlayer then return "player" end
    local okC, controlled = pcall(UnitPlayerControlled, unit)
    if okC and controlled then return "pet" end
    return "npc"
end

local function FriendlySettings()
    local p = P()
    return {
        -- "off" = plate nativo de Blizzard intacto para esa categoria (no se
        -- toca en absoluto), "nameonly" = solo el nombre flotando, sin barra
        -- (pedido: "para que tengan el nombre"), "healthbar" = plate propio
        -- completo, igual que un hostil.
        playerMode = (p and p.friendlyPlayerMode) or "nameonly",
        npcMode    = (p and p.friendlyNPCMode) or "nameonly",
        petMode    = (p and p.friendlyPetMode) or "nameonly",
        classColor = not p or p.friendlyClassColor ~= false,
        instanceNameOnly = p and p.friendlyInstanceNameOnly == true,
        instanceNameOnlySize = (p and p.friendlyInstanceNameOnlySize) or 15,
        -- Pedido del usuario 2026-08-03: "que en dungeon o raid se
        -- desactive automaticamente friendly npc nameplates y cuando salga
        -- se active de nuevo". Fuerza la categoria NPC/Pet al modo "off"
        -- (SetUnit no construye plate propio) Y ADEMAS aplica
        -- TextureLoadingGroupMixin sobre la barra nativa -- ver
        -- SetNativeShowOnlyNameFlag mas abajo, puerto literal de Plater
        -- (Plater.lua:5203-5223, confirmado leyendo su codigo real de PTR
        -- para Midnight).
        autoDisableNPCsInInstance = p and p.friendlyAutoDisableNPCsInInstance == true,
    }
end

-- IsInInstance() es liviana (no consulta el server, lee estado ya conocido
-- localmente) pero igual se cachea por 1s -- SetUnit corre por CADA plate
-- que aparece, y en una pulla de M+ con 10+ adds eso son 10+ llamadas en el
-- mismo frame si no se cachea.
local instCache, instCacheAt = nil, 0
local function InPartyOrRaidInstance()
    local now = GetTime()
    if instCacheAt ~= 0 and (now - instCacheAt) < 1 then return instCache end
    instCacheAt = now
    local okI, inInst, instanceType = pcall(IsInInstance)
    instCache = okI and inInst and (instanceType == "party" or instanceType == "raid")
    return instCache
end

------------------------------------------------------------------------------
-- 4ta TECNICA -- LA REAL (2026-08-03, usuario aporto el path de Plater en
-- PTR: E:\World of Warcraft\_ptr_\Interface\AddOns\Plater). Las 3 rondas
-- anteriores (pcall, securecall, SetAlpha directo) fallaban porque TODAS
-- llamaban un METODO sobre el objeto protegido (Hide/SetShown/GetAlpha/
-- SetAlpha/SetShowOnlyName) -- confirmado con /mcfautoalphadiag que
-- Blizzard bloquea ESO especificamente (cualquier llamada a funcion sobre
-- el objeto, lectura o escritura). Plater.lua:5203-5223 (codigo real,
-- confirmado leyendo el PTR) NUNCA llama SetShowOnlyName -- en cambio usa
-- TextureLoadingGroupMixin.AddTexture({ textures = self.HealthBarsContainer
-- .healthBar }, "showOnlyName"), que internamente hace
-- self.HealthBarsContainer.healthBar["showOnlyName"] = true -- UNA
-- ASIGNACION DE CAMPO DE TABLA PLANA, no una llamada a metodo. Escribir un
-- campo en una tabla NO esta bloqueado por el sistema de seguridad de WoW
-- (solo las llamadas a funcion lo estan) -- y el campo "showOnlyName" es
-- justo lo que el CODIGO PROPIO de Blizzard lee en su siguiente pasada
-- interna (confirmado: aparecia como campo plano legible, "showOnlyName=
-- false", en TODOS los dumps de error de rondas anteriores) para decidir
-- si llamar Hide() -- desde SU PROPIO contexto seguro, nunca el nuestro.
------------------------------------------------------------------------------
local function SetNativeShowOnlyNameFlag(uf, show)
    if not uf or not TextureLoadingGroupMixin then return end
    -- FIX (2026-08-03, "es posible centrarlo mas?" -- el nombre queda
    -- flotando donde estaria si la barra siguiera ahi, no centrado sobre la
    -- unidad): Plater.lua:5230-5238 (su hook OnUnitSet) ADEMAS pone el
    -- MISMO flag "showOnlyName" sobre el UnitFrame COMPLETO (uf), no solo
    -- sobre healthBar/castBar -- ese es el flag mas amplio que el layout
    -- nativo de Blizzard lee para decidir donde ANCLAR el nombre (centrado
    -- sobre la unidad) en vez de solo si mostrar/ocultar la barra.
    if show then
        TextureLoadingGroupMixin.AddTexture({ textures = uf }, "showOnlyName")
    else
        TextureLoadingGroupMixin.RemoveTexture({ textures = uf }, "showOnlyName")
    end
    local hbc = uf.HealthBarsContainer
    local hb = hbc and hbc.healthBar
    if hb then
        if show then
            TextureLoadingGroupMixin.AddTexture({ textures = hb }, "showOnlyName")
        else
            TextureLoadingGroupMixin.RemoveTexture({ textures = hb }, "showOnlyName")
        end
    end
    -- FIX (2026-08-03, confirmado con /mcfcastdiag en vivo -- datos reales,
    -- no supuestos): uf.castBar es SIEMPRE nil para estos frames -- el
    -- objeto real, incluso en el instante exacto que arranca el cast, vive
    -- en uf.CastBarsContainer.castBar. Plater.lua:5211 usa self.castBar
    -- directo, pero evidentemente en la variante/momento de ESTE build el
    -- nesting es distinto -- se prueban AMBOS caminos, el que exista gana.
    local cb = uf.castBar or (uf.CastBarsContainer and uf.CastBarsContainer.castBar)
    if cb then
        if show then
            TextureLoadingGroupMixin.AddTexture({ textures = cb }, "showOnlyName")
            TextureLoadingGroupMixin.AddTexture({ textures = cb }, "widgetsOnly")
        else
            TextureLoadingGroupMixin.RemoveTexture({ textures = cb }, "showOnlyName")
            TextureLoadingGroupMixin.RemoveTexture({ textures = cb }, "widgetsOnly")
        end
    end
end

-- Solo lectura de globals con el UNIT TOKEN (nunca un metodo SOBRE el
-- frame protegido) -- UnitIsFriend/UnitIsPlayer son APIs publicas, no
-- llamadas al objeto en si.
local function IsFriendlyNonPlayerUnit(unit)
    if not unit then return false end
    local okF, isFriend = pcall(UnitIsFriend, "player", unit)
    if not (okF and isFriend) then return false end
    local okP, isPlayer = pcall(UnitIsPlayer, unit)
    return not (okP and isPlayer)
end

-- Reaplicado via el MISMO hook que Plater usa (self.unit es un CAMPO
-- legible, nunca una llamada a metodo).
--
-- GENERALIZADO (2026-08-03, causa raiz real de "sigo viendo el cast bar
-- nativo" en jugadores amistosos FUERA de instancia): confirmado con
-- /mcfcastbardiag que uf.castBar NO hereda alpha 0 de uf (SetAlpha/GetAlpha
-- sobre el bloqueados igual que healthBar de un ForbiddenNamePlate -- ver
-- el comentario largo en ApplyDungeonNameOnlyCVars). El campo "showOnlyName"
-- via TextureLoadingGroupMixin es el UNICO mecanismo que si funciona.
--
-- FIX (2026-08-03, "se daño el fix de name de los npc y pet aliados en
-- dungeon" -- regresion real de la ronda anterior): angostar el gate a SOLO
-- ns.plates[unit] rompio el caso de auto-disable-en-instancia -- ESAS
-- unidades nunca llegan a ns.plates (SetUnit corta con `mode == "off"`
-- ANTES de esa asignacion, a proposito, para no tocarlas). Sin el OR de
-- abajo, el hook dejaba de reafirmar el flag para ellas apenas Blizzard lo
-- reseteaba (recambio de unidad en el mismo plate, etc), y la barra nativa
-- volvia a aparecer con el tiempo. Los DOS casos son validos y no se
-- superponen: ns.plates[unit] cubre nuestro plate propio normal (cualquier
-- categoria/modo), el segundo termino cubre el auto-disable de instancia
-- (donde SetUnit deliberadamente NO construye nada).
local autoAlphaHooked = false
local function EnsureAutoAlphaHook()
    if autoAlphaHooked or not NamePlateUnitFrameMixin then return end
    autoAlphaHooked = true
    hooksecurefunc(NamePlateUnitFrameMixin, "UpdateNameClassColor", function(self)
        local unit = self.unit
        if not unit then return end
        if not IsFriendlyNonPlayerUnit(unit) then return end
        local managed = ns.plates[unit] ~= nil
        local autoDisabled = FriendlySettings().autoDisableNPCsInInstance and InPartyOrRaidInstance()
        if not (managed or autoDisabled) then return end
        SetNativeShowOnlyNameFlag(self, true)
    end)
end
EnsureAutoAlphaHook()

-- FIX (2026-08-03, confirmado con /mcfplateralphadiag -- causa raiz real
-- de "se sigue viendo el cast bar"): uf.castBar es NIL hasta que la unidad
-- arranca a castear -- Blizzard lo crea/asigna recien ahi. El flag que
-- pusimos antes (via SetUnit/hook de UpdateNameClassColor) corrio con
-- uf.castBar todavia inexistente, asi que SetNativeShowOnlyNameFlag nunca
-- llego a tocarlo (su propio `if cb then` lo salteaba en silencio).
-- UNIT_SPELLCAST_START/CHANNEL_START son EVENTOS GLOBALES del juego (no un
-- metodo sobre ningun objeto protegido) -- disparan justo cuando Blizzard
-- recien creo/asigno el castBar, momento en el que SI existe y se le puede
-- aplicar el flag.
local castStartEv = CreateFrame("Frame")
castStartEv:RegisterEvent("UNIT_SPELLCAST_START")
castStartEv:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
castStartEv:SetScript("OnEvent", function(_, event, unit)
    -- FIX (2026-08-03, crash en vivo -- "Raid<n>/Party<n> unit tokens are
    -- not allowed for this call"): UNIT_SPELLCAST_START dispara para
    -- CUALQUIER unidad con un cast visible (party, raid, focus, target...),
    -- no solo nameplates -- GetNamePlateForUnit rechaza tokens que no son
    -- de nameplate. Filtrado al patron real antes de llamar nada.
    if not unit or not unit:match("^nameplate") then return end
    if not IsFriendlyNonPlayerUnit(unit) then return end
    local managed = ns.plates[unit] ~= nil
    local autoDisabled = FriendlySettings().autoDisableNPCsInInstance and InPartyOrRaidInstance()
    if not (managed or autoDisabled) then return end
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return end
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit, true)
    local uf = nameplate and nameplate.UnitFrame
    if uf then SetNativeShowOnlyNameFlag(uf, true) end
end)

local autoAlphaApplied = false
local function ApplyAutoDisableAlpha()
    local want = FriendlySettings().autoDisableNPCsInInstance and InPartyOrRaidInstance()
    if want == autoAlphaApplied then return end
    autoAlphaApplied = want
    if want then EnsureAutoAlphaHook() end
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, np in ipairs(C_NamePlate.GetNamePlates(true)) do
        local uf = np.UnitFrame
        if uf and IsFriendlyNonPlayerUnit(uf.unit) then
            SetNativeShowOnlyNameFlag(uf, want)
        end
    end
end
-- "Nombre solo" en dungeon/raid via CVARS NATIVOS (2026-08-03, "no funciona,
-- porque en calabozo o raid no se puede controlar el nameplate tal cual --
-- solo se puede ocultar la textura y dejar el nombre y ajustar el tamaño").
--
-- El intento anterior (bajar el modo a "nameonly" y dejar que NUESTRO
-- sistema construya su propio frame reemplazo) NO sirve aca: los NPCs/pets
-- amistosos de instancia son ForbiddenNamePlate -- reparentar sus hijos,
-- hookear SetAlpha, etc (todo lo que hace HideBlizzardFrame) es exactamente
-- el tipo de manipulacion que un frame prohibido rechaza o tainta. Los
-- CVars nativos SI funcionan sobre frames prohibidos (son ajustes de motor,
-- no llamadas Lua sobre el frame) -- confirmado en vivo en la version vieja
-- de este addon (Nameplates.lua:565-595, comentario "SI afecta incluso a
-- las ForbiddenNamePlate de NPCs de escolta/mision"). Puerto de esos mismos
-- 3 CVars + el tamaño de fuente via SystemFont_NamePlate (mismo mecanismo
-- que EllesmereUINameplatesFriendly.lua usa para su modo name-only real).
--
-- Mientras esto esta activo, SetUnit NO toca esas unidades en absoluto
-- (mismo criterio que modo "off") -- dejar que el motor nativo dibuje solo
-- nombre es la unica via que funciona ahi, nuestro plate propio ni lo
-- intenta.
------------------------------------------------------------------------------
local DUNGEON_NAMEONLY_CVARS = {
    "nameplateShowFriendlyNPCs", "nameplateShowFriendlyPlayers",
    "nameplateShowOnlyNameForFriendlyPlayerUnits",
}
local dungeonCVarsApplied = false
local origDungeonCVars, origNamePlateFont
-- Forward-declarado: la implementacion real vive mas abajo, DESPUES de
-- SetUnit/ClearUnit (que todavia no existen a esta altura del archivo) --
-- se asigna ahi. Permite que ApplyDungeonNameOnlyCVars dispare un barrido
-- inmediato de las plates YA activas cuando el checkbox se prende/apaga en
-- vivo (sin esto, el cambio solo se notaria en el proximo cambio de zona).
local SweepFriendlyPlates
-- Forward-decl (2026-08-03, patron "driver auto-ocultable" de EllesmereUI --
-- EllesmereUI_Ticker.lua:63-134, Tick.NewDriver: el frame se oculta solo
-- cuando no tiene trabajo, asi el motor deja de llamarle OnUpdate del todo
-- -- 0 costo mientras no hay ninguna plate propia activa, ej. la mayor
-- parte del tiempo en mundo abierto sin combate). Asignado mas abajo, junto
-- al resto del driver de 0.2s -- SetUnit/ClearUnit lo Show()/Hide() segun
-- si ns.plates tiene algo.
local driverFrame

local function DungeonNameOnlyShouldBeActive()
    return FriendlySettings().instanceNameOnly and InPartyOrRaidInstance()
end

-- ABANDONADO DEFINITIVAMENTE (2026-08-03, 2 tecnicas distintas confirmadas
-- rotas en vivo -- pcall Y securecall). NO REINTENTAR esto sin una tercera
-- tecnica genuinamente distinta -- el problema no es COMO se llama
-- SetShowOnlyName, es que SetShowOnlyName en si mismo, internamente, llama
-- self:Hide()/self:SetShown() sobre sus componentes hijos (HealthBar,
-- CastBar, ClassificationFrame) -- y Hide()/SetShown() estan BLOQUEADOS por
-- Blizzard para cualquier ForbiddenNamePlate, sin importar que tan "segura"
-- sea la llamada de entrada. securecall SI evita que NUESTRO codigo quede
-- marcado como origen del taint (por eso el error ahora aparece DENTRO de
-- 'securecall', no como fallo directo de nuestra llamada) -- pero la
-- proteccion de Blizzard sobre Hide/SetShown en frames forbidden es un
-- limite de seguridad INTENCIONAL, no un descuido tainted-vs-no-tainted:
-- existe especificamente para que ningun addon pueda ocultar/mostrar
-- piezas de un ForbiddenNamePlate mediante programacion, sea cual sea la
-- tecnica. Confirmado con evidencia: mismo crash exacto (Hide/SetShown on
-- bad self) en 3 widgets DISTINTOS (HealthBar, CastingBarFrame,
-- ClassificationFrame), los 3 disparados DESDE DENTRO de 'securecall' en el
-- stack trace.
--
-- CONCLUSION: no hay forma de forzar "solo nombre" en NPCs/pets amistosos
-- de instancia desde este addon. Blizzard reserva esa capacidad para su
-- propio codigo nativo (por eso el CVar de jugadores SI funciona -- ahi el
-- motor mismo decide mostrar/ocultar, nunca via un metodo Lua expuesto al
-- addon).
local function ApplyDungeonNameOnlyCVars()
    local want = DungeonNameOnlyShouldBeActive()
    if want == dungeonCVarsApplied then
        if want then
            -- Ya esta activo -- solo el tamaño puede haber cambiado en vivo
            -- (el usuario moviendo el slider), reaplicar sin re-guardar
            -- originales de nuevo.
            local size = FriendlySettings().instanceNameOnlySize
            if SystemFont_NamePlate and SystemFont_NamePlate.SetFont then
                local file, _, flags = SystemFont_NamePlate:GetFont()
                pcall(SystemFont_NamePlate.SetFont, SystemFont_NamePlate, file, size, flags)
            end
        end
        return
    end
    dungeonCVarsApplied = want
    if want then
        origDungeonCVars = {}
        for _, cv in ipairs(DUNGEON_NAMEONLY_CVARS) do
            local okG, orig = pcall(GetCVar, cv)
            origDungeonCVars[cv] = (okG and orig) or "0"
            pcall(SetCVar, cv, "1")
        end
        if SystemFont_NamePlate and SystemFont_NamePlate.GetFont then
            local file, height, flags = SystemFont_NamePlate:GetFont()
            origNamePlateFont = { file = file, height = height, flags = flags }
            pcall(SystemFont_NamePlate.SetFont, SystemFont_NamePlate, file,
                FriendlySettings().instanceNameOnlySize, flags)
        end
    else
        if origDungeonCVars then
            for _, cv in ipairs(DUNGEON_NAMEONLY_CVARS) do
                pcall(SetCVar, cv, origDungeonCVars[cv])
            end
            origDungeonCVars = nil
        end
        if origNamePlateFont and SystemFont_NamePlate and SystemFont_NamePlate.SetFont then
            pcall(SystemFont_NamePlate.SetFont, SystemFont_NamePlate,
                origNamePlateFont.file, origNamePlateFont.height, origNamePlateFont.flags or "")
            origNamePlateFont = nil
        end
    end
    if SweepFriendlyPlates then SweepFriendlyPlates() end
end
ns.RefreshFriendlyInstanceNameOnly = ApplyDungeonNameOnlyCVars

local function ClassColor(unit)
    local ok, _, classToken = pcall(UnitClass, unit)
    if ok and classToken and not (issecretvalue and issecretvalue(classToken))
        and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
        local c = RAID_CLASS_COLORS[classToken]
        return c.r, c.g, c.b
    end
    return nil
end

------------------------------------------------------------------------------
-- Suprimir el UnitFrame nativo (HideBlizzardFrame, calcado de
-- EllesmereUINameplates.lua:5533-5700). uf NUNCA se reparenta -- solo
-- alpha 0, y sus hijos no esenciales van a un holder invisible aparte.
------------------------------------------------------------------------------
local offscreenParent = CreateFrame("Frame", nil, UIParent)
offscreenParent:Hide()

local hookedUF = setmetatable({}, { __mode = "k" })
local storedParents = setmetatable({}, { __mode = "k" })

local function HideBlizzardFrame(nameplate, unit)
    local uf = nameplate.UnitFrame
    if not uf then return end
    -- FIX (2026-08-03, "algo se daño, ahora los nameplates solo se muestran
    -- o..." -- regresion real de la ronda anterior): este SetAlpha(0)
    -- explicito, en un uf YA HOOKEADO (nameplate reciclado para otra unidad,
    -- pasa todo el tiempo caminando por el mundo), disparaba el hook de mas
    -- abajo COMO SI fuera una llamada nativa -- `a=0` es truthy en Lua, asi
    -- que se guardaba en _mcfNativeAlpha, y el driver leia eso y ponia
    -- f:SetAlpha(0) -- el plate quedaba invisible hasta que Blizzard
    -- decidiera llamar SetAlpha de nuevo por su cuenta (que el diag de mas
    -- abajo confirma que CASI NUNCA pasa en este build). uf._mcfForcing
    -- distingue "esta llamada es nuestra" de "esta llamada vino del motor" --
    -- el hook la chequea ANTES de capturar nada.
    uf._mcfForcing = true
    uf:SetAlpha(0)
    uf._mcfForcing = false
    -- FIX (2026-08-03, "algunos player no se dejan seleccionar" -- click
    -- inconsistente, no roto del todo): SoftTargetFrame es un campo NATIVO
    -- real de Blizzard (visto en un dump de taint anterior en este mismo
    -- build) ligado al sistema de soft-target/click de nameplates.
    -- Reparentarlo junto con el resto de los hijos "no esenciales" puede
    -- estar interfiriendo con el click SOLO quando Blizzard lo necesita
    -- (explicaria el "algunos si, algunos no" -- no todas las unidades
    -- disparan el mismo camino de codigo nativo). Excluido, igual que
    -- AurasFrame/WidgetContainer en el codigo real de EllesmereUI.
    for i = 1, uf:GetNumChildren() do
        local child = select(i, uf:GetChildren())
        if child and child ~= uf.SoftTargetFrame and not child:IsForbidden() and not child:IsProtected() then
            if not storedParents[child] then storedParents[child] = uf end
            child:SetParent(offscreenParent)
        end
    end
    -- FIX REAL (2026-08-03, "veo el cast bar nativo -- se puede ocultar?"):
    -- SetAlpha directo sobre uf.castBar NO funciona -- confirmado con
    -- /mcfcastbardiag + /mcfautoalphadiag, mismo bloqueo que healthBar en
    -- un ForbiddenNamePlate (GetAlpha/SetAlpha fallan ambos). El unico
    -- mecanismo que SI funciona es SetNativeShowOnlyNameFlag (mas arriba
    -- en el archivo, puerto de Plater.lua:5210-5216 via TextureLoadingGroupMixin)
    -- -- se aplica aca para efecto inmediato, y el hook de UpdateNameClassColor
    -- lo reafirma si Blizzard lo resetea despues.
    if uf.castBar then pcall(uf.castBar.UnregisterAllEvents, uf.castBar) end
    SetNativeShowOnlyNameFlag(uf, true)
    if not hookedUF[uf] then
        hookedUF[uf] = true
        -- REVERTIDO (2026-08-03, "los occluded siempre se muestran cuando
        -- tengo target -- me pasa con los nameplates nativos de Blizzard
        -- pero no con los de EllesmereUI"): la captura/espejado de
        -- uf._mcfNativeAlpha (rondas anteriores) era el problema, no la
        -- solucion. Blizzard fuerza SIEMPRE alpha completo en `uf` para la
        -- unidad seleccionada -- IGNORANDO oclusion -- eso es justo el
        -- comportamiento nativo de "nunca pierdas de vista a tu target", y
        -- espejar ese valor sobre `f` importaba esa misma exencion a
        -- nuestro plate. Confirmado leyendo el comentario real de
        -- EllesmereUINameplates.lua:3780-3785: SU plate cuelga del mismo
        -- frame nativo `nameplate` que el nuestro y NO hace nada especial
        -- -- "Blizzard's own occlusion fade still multiplies in" solo -- la
        -- herencia de alpha de WoW (f hijo de nameplate) ya aplica la
        -- oclusion CRUDA, sin la exencion de target, porque esa exencion
        -- vive ENTERAMENTE en el codigo Lua de uf, no en el frame nameplate
        -- en si. No hace falta ningun hook para esto -- alcanza con NO
        -- pisarlo, que es lo que queda aca ahora (solo forzar 0, sin leer
        -- ni reenviar nada).
        hooksecurefunc(uf, "SetAlpha", function(self, a)
            if self._mcfForcing then return end
            if a and a == 0 then return end
            local u = self:GetParent() and (self:GetParent().namePlateUnitToken or self:GetParent().unitToken)
            if not u or not ns.plates[u] then return end
            self._mcfForcing = true
            self:SetAlpha(0)
            self._mcfForcing = false
        end)
    end
    -- (Hook de SetAlpha sobre uf.castBar QUITADO -- confirmado con
    -- /mcfautoalphadiag que SetAlpha esta bloqueado sobre estos widgets
    -- igual que GetAlpha, instalar un hooksecurefunc que llame self:SetAlpha
    -- SIN pcall ahi es un crash esperando pasar. La reafirmacion persistente
    -- real vive en EnsureAutoAlphaHook, via el campo showOnlyName.)
end

local function RestoreBlizzardFrame(nameplate)
    local uf = nameplate and nameplate.UnitFrame
    if not uf then return end
    pcall(uf.SetAlpha, uf, 1)
    -- SetNativeShowOnlyNameFlag(uf, false), no un SetAlpha directo sobre
    -- castBar (confirmado bloqueado) -- restaura el campo, no el metodo.
    SetNativeShowOnlyNameFlag(uf, false)
    for child, origParent in pairs(storedParents) do
        if child:GetParent() == offscreenParent then
            pcall(child.SetParent, child, origParent)
            storedParents[child] = nil
        end
    end
end

------------------------------------------------------------------------------
-- Pool: frame 100% propio, construido UNA vez (factory), reusado entre
-- unidades (SetUnit reconfigura, no recrea). Sin resetter custom en el
-- pool -- el reset de estado vive en ClearUnit.
------------------------------------------------------------------------------
local function CreatePlateFrame()
    local f = CreateFrame("Frame", nil, UIParent)
    f:Hide()

    f.health = CreateFrame("StatusBar", nil, f)
    f.health:SetStatusBarTexture(BAR_TEX)
    local tex = f.health:GetStatusBarTexture()
    if tex then tex:SetTexCoord(unpack(BAR_TEXCOORD)) end
    f.health:SetMinMaxValues(0, 100)
    f.healthBG = f.health:CreateTexture(nil, "BACKGROUND", nil, -1)
    f.healthBG:SetPoint("CENTER")
    f.healthBG:SetTexture(BACKDROP_TEX)
    f.healthValue = f.health:CreateFontString(nil, "OVERLAY")

    -- Highlight de seleccion: pedido explicito del usuario, usar la
    -- textura propia nameplate_outline.tga (no el wash de color de
    -- EllesmereUI) -- blend ADD para que se vea como un brillo/aro, no un
    -- relleno solido opaco.
    f.highlight = f.health:CreateTexture(nil, "OVERLAY", nil, 5)
    f.highlight:SetTexture(A .. "nameplate_outline.tga")
    f.highlight:SetBlendMode("ADD")
    f.highlight:Hide()

    -- Clasificacion (elite/rare/boss) -- mismo criterio que el sistema
    -- viejo (Nameplates.lua): texturas PROPIAS (AzeriteUI) alimentadas por
    -- UnitClassification(unit), en vez de reskinear el atlas nativo de
    -- Blizzard (no se puede re-texturar un atlas).
    f.classIcon = f.health:CreateTexture(nil, "OVERLAY", nil, 6)
    f.classIcon:Hide()

    -- Marca de raid target (skull, cross, etc) -- el sistema viejo
    -- reusaba uf.RaidTargetFrame nativo (uf nunca se ocultaba del todo
    -- ahi). Aca uf SI se alpha-0ea siempre que armamos plate propio, asi
    -- que RaidTargetFrame quedaria invisible -- se dibuja uno propio con
    -- el mismo atlas nativo (publico, no secreto) + GetRaidTargetIndex.
    f.raidMark = f.health:CreateTexture(nil, "OVERLAY", nil, 7)
    f.raidMark:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    f.raidMark:Hide()

    f.name = f:CreateFontString(nil, "OVERLAY")

    f.cast = CreateFrame("StatusBar", nil, f)
    f.cast:SetStatusBarTexture(BAR_TEX)
    local ctex = f.cast:GetStatusBarTexture()
    if ctex then ctex:SetTexCoord(unpack(BAR_TEXCOORD)) end
    f.cast:SetMinMaxValues(0, 1)
    f.cast.bg = f.cast:CreateTexture(nil, "BACKGROUND", nil, -1)
    f.cast.bg:SetPoint("CENTER")
    f.cast.bg:SetTexture(BACKDROP_TEX)
    -- Icono del hechizo -- a la izquierda de la barra, mismo alto.
    f.cast.icon = f.cast:CreateTexture(nil, "ARTWORK")
    f.cast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- FIX (2026-08-03, "baja el texto del hechizo para que no se
    -- sobreponga con el castbar"): antes CENTER (encima de la barra,
    -- tapandola) -- ahora debajo, como el nombre arriba de la vida.
    f.cast.text = f.cast:CreateFontString(nil, "OVERLAY")
    f.cast.text:SetPoint("TOP", f.cast, "BOTTOM", 0, -1)
    f.cast:Hide()

    return f
end

local pool = {}
local function AcquirePlateFrame()
    local f = next(pool)
    if f then
        pool[f] = nil
        return f
    end
    return CreatePlateFrame()
end
local function ReleasePlateFrame(f)
    f:Hide()
    f:ClearAllPoints()
    f:SetParent(UIParent)
    pool[f] = true
end

-- Prewarm gradual (2026-08-03, patron de EllesmereUINameplates.lua:3475-3508):
-- crear un plate propio de golpe cuesta unos ms (StatusBar+texturas+
-- FontStrings x2), y sin prewarm ese costo se paga TODO JUNTO la primera
-- vez que aparecen varias unidades a la vez (ej. entrar a una zona con
-- varios mobs, o el primer pull de una pulla). Se pre-llena el pool con
-- PREWARM_COUNT frames, 1 cada 100ms, arrancando 2s despues de
-- PLAYER_ENTERING_WORLD -- mismo timing/motivo que EllesmereUI documenta
-- ("2ms+ per-frame creation cost... visible stutter").
local PREWARM_COUNT = 15
local function PrewarmPool()
    local made = 0
    local ticker
    ticker = C_Timer.NewTicker(0.1, function()
        local f = CreatePlateFrame()
        pool[f] = true
        -- Auras tambien de antemano (ver ns.NPAurasNext_Prewarm en
        -- NameplateAurasNext.lua) -- asi los 3 AuraContainer x frame
        -- tambien se pagan en el prewarm, no en el primer pull grande.
        if ns.NPAurasNext_Prewarm then pcall(ns.NPAurasNext_Prewarm, f) end
        made = made + 1
        if made >= PREWARM_COUNT then ticker:Cancel() end
    end)
end
local prewarmEv = CreateFrame("Frame")
prewarmEv:RegisterEvent("PLAYER_ENTERING_WORLD")
prewarmEv:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    C_Timer.After(2, PrewarmPool)
end)

------------------------------------------------------------------------------
-- Layout: solo se reaplica cuando cambia algo (mismo espiritu que el
-- generation-gate de ApplyAppearance, simplificado -- comparar la firma
-- contra la ya aplicada en vez de un contador de generacion global).
------------------------------------------------------------------------------
local function ReassertLayout(f, nameOnly)
    local p = P()
    local w, h = GetHealthSize()
    local sig = w .. "|" .. h .. "|" .. tostring(nameOnly)
    if f._mcfLayoutSig == sig then return end
    f._mcfLayoutSig = sig

    f:SetSize(w, h)
    f.health:ClearAllPoints()
    f.health:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.health:SetSize(w, h)
    f.healthBG:SetSize(w, h)
    f.highlight:ClearAllPoints()
    f.highlight:SetAllPoints(f.health)

    -- Nombre/cast/valor de vida/texto de cast: (2026-08-05, "traer de
    -- vuelta el diseñador con el nuevo sistema") -- ns.NPLayout.Name/Cast/
    -- CastText/HealthValue YA EXISTEN en NameplateLayout.lua (leen
    -- nameOffsetX/Y, castOffsetX/Y, castTextOffsetX/Y, healthValueOffsetX/Y
    -- del perfil) desde que ese archivo se separo -- pero nadie los llamaba
    -- aca, los offsets estaban hardcodeados. Mismo patron que Classification/
    -- RaidMark (mas abajo), que SI ya estaban conectados. Con esto,
    -- reactivar el Nameplate Designer para estos 4 elementos es solo
    -- reconectar UI, la geometria ya la aplica este archivo.
    local castAl = ns.NPLayout and ns.NPLayout.Cast and ns.NPLayout.Cast(p)
    f.cast:ClearAllPoints()
    if castAl then
        f.cast:SetPoint(castAl.point, f.health, castAl.relPoint, castAl.x, castAl.y)
    else
        f.cast:SetPoint("TOP", f.health, "BOTTOM", 0, -4)
    end
    -- "la textura esta muy delgada" (2026-08-03): 12px se veia angosto
    -- comparado con la barra de vida -- subido a 16, mas parecido a la
    -- proporcion que usaba el cast bar del sistema viejo. castWidth/Height
    -- (perfil) ahora pisan ese default via ns.NPLayout.CastSize, igual que
    -- ya hacia GetHealthSize() para la barra de vida.
    local cw, ch
    if ns.NPLayout and ns.NPLayout.CastSize then cw, ch = ns.NPLayout.CastSize(p) end
    cw, ch = cw or w, ch or 16
    f.cast:SetSize(cw, ch)
    f.cast.bg:SetSize(cw, ch)

    local hvAl = ns.NPLayout and ns.NPLayout.HealthValue and ns.NPLayout.HealthValue(p)
    local valSize = (p and p.healthValueFontSize) or 12
    f.healthValue:SetFont("Fonts\\FRIZQT__.TTF", valSize, "OUTLINE")
    f.healthValue:ClearAllPoints()
    if hvAl then
        f.healthValue:SetPoint(hvAl.point, f.health, hvAl.relPoint, hvAl.x, hvAl.y)
    else
        f.healthValue:SetPoint("TOP", f.health, "BOTTOM", 0, -2)
    end
    -- Pedido del usuario 2026-08-03: "el porcentaje de la vida, el nombre
    -- del hechizo... que tengan el color clasico" -- ns.GOLD (FFE19B), el
    -- color de texto default de todo el addon (core.lua:351). El nombre de
    -- la unidad se excluye a proposito (tiene su propia logica de color
    -- por clase/reaccion, mas informativa ahi que un color fijo).
    if ns.GOLD then f.healthValue:SetTextColor(ns.GOLD.r, ns.GOLD.g, ns.GOLD.b) end

    local nameSize = (p and p.nameFontSize) or 15
    f.name:SetFont("Fonts\\FRIZQT__.TTF", nameSize, "OUTLINE")
    f.name:ClearAllPoints()
    -- Modo "nameonly" (amistosos, ver FriendlySettings): sin barra visible,
    -- el nombre ancla directo al CENTRO del frame en vez de arriba de la
    -- barra -- mismo criterio que FriendlyFrame:SetUnit en EllesmereUI
    -- (single center anchor, "to prevent pixel shimmer when nameplate
    -- bounces"), adaptado a que aca el nombre SI es nuestro FontString propio.
    -- OJO: L.Name(p, true) devuelve un anclaje DISTINTO (BOTTOM del plate,
    -- pensado para cuando SI hay barra) -- para nameOnly seguimos anclando
    -- a CENTER a mano, pero YA leyendo nameOnlyOffsetX/Y (mismas claves que
    -- usa L.Name internamente) en vez de dejarlas sin efecto.
    if nameOnly then
        local nx = (p and p.nameOnlyOffsetX) or 0
        local ny = (p and p.nameOnlyOffsetY) or 0
        f.name:SetPoint("CENTER", f, "CENTER", nx, ny)
    else
        local nameAl = ns.NPLayout and ns.NPLayout.Name and ns.NPLayout.Name(p, false)
        if nameAl then
            f.name:SetPoint(nameAl.point, f, nameAl.relPoint, nameAl.x, nameAl.y)
        else
            f.name:SetPoint("BOTTOM", f.health, "TOP", 0, 1)
        end
    end

    local castSize = (p and p.castTextFontSize) or 10
    f.cast.text:SetFont("Fonts\\FRIZQT__.TTF", castSize, "OUTLINE")
    local castTextAl = ns.NPLayout and ns.NPLayout.CastText and ns.NPLayout.CastText(p)
    f.cast.text:ClearAllPoints()
    if castTextAl then
        f.cast.text:SetPoint(castTextAl.point, f.cast, castTextAl.relPoint, castTextAl.x, castTextAl.y)
    else
        f.cast.text:SetPoint("TOP", f.cast, "BOTTOM", 0, -1)
    end
    if ns.GOLD then f.cast.text:SetTextColor(ns.GOLD.r, ns.GOLD.g, ns.GOLD.b) end

    -- Icono del cast, pegado al borde izquierdo, mismo alto que la barra.
    f.cast.icon:ClearAllPoints()
    f.cast.icon:SetSize(16, 16)
    f.cast.icon:SetPoint("RIGHT", f.cast, "LEFT", -2, 0)

    -- Clasificacion y marca de raid: mismos offsets/tamaños que ya vivian
    -- en NameplateLayout.lua para el sistema viejo (nunca se conectaron a
    -- este archivo nuevo).
    -- OJO: point = anchor DEL ICONO, relPoint = anchor SOBRE f.health --
    -- son distintos (ej. classification es RIGHT-a-RIGHT, pero en general
    -- no tienen por que coincidir).
    local classAl = ns.NPLayout and ns.NPLayout.Classification and ns.NPLayout.Classification(p)
    if classAl then
        local csz = (p and p.classificationSize) or 24
        f.classIcon:SetSize(csz, csz)
        f.classIcon:ClearAllPoints()
        f.classIcon:SetPoint(classAl.point, f.health, classAl.relPoint, classAl.x, classAl.y)
    end
    local raidAl = ns.NPLayout and ns.NPLayout.RaidMark and ns.NPLayout.RaidMark(p)
    if raidAl then
        local rsz = (p and p.raidMarkSize) or 20
        f.raidMark:SetSize(rsz, rsz)
        f.raidMark:ClearAllPoints()
        f.raidMark:SetPoint(raidAl.point, f.health, raidAl.relPoint, raidAl.x, raidAl.y)
    end
end

------------------------------------------------------------------------------
-- Datos: mismas APIs secret-safe ya establecidas en este addon
-- (ns.GetHealthPercent via UnitHealthPercent, UnitCastingInfo/
-- UnitChannelInfo, UnitReaction para color).
------------------------------------------------------------------------------
local function ReactionColor(unit)
    local reaction = ns.safeVal and ns.safeVal(UnitReaction, unit, "player")
    if type(reaction) == "number" then
        if reaction <= 3 then return 0.86, 0.11, 0.11 end
        if reaction == 4 then return 1, 0.85, 0 end
    end
    return 0, 0.9, 0
end

local function UpdateHealth(f, unit, isFriendly)
    local pct = ns.GetHealthPercent and ns.GetHealthPercent(unit)
    if pct ~= nil then
        pcall(f.health.SetValue, f.health, pct)
        pcall(function() f.healthValue:SetFormattedText("%d%%", pct) end)
    else
        f.healthValue:SetText("")
    end
    local r, g, b
    if isFriendly and FriendlySettings().classColor then
        local okP, isPlayer = pcall(UnitIsPlayer, unit)
        if okP and isPlayer then r, g, b = ClassColor(unit) end
    end
    if not r then r, g, b = ReactionColor(unit) end
    if f._mcfLastR ~= r or f._mcfLastG ~= g or f._mcfLastB ~= b then
        f._mcfLastR, f._mcfLastG, f._mcfLastB = r, g, b
        pcall(f.health.SetStatusBarColor, f.health, r, g, b)
    end
end

local function UpdateName(f, unit, isFriendly)
    local okN, nm = pcall(UnitName, unit)
    f.name:SetText((okN and type(nm) == "string") and nm or "")
    local okP, isPlayer = pcall(UnitIsPlayer, unit)
    -- Class color SOLO para jugadores amistosos (regla de EllesmereUI: el
    -- reaction color ya identifica hostil/neutral/amistoso por si solo, la
    -- clase solo aporta info nueva del lado amistoso -- un hostil de clase
    -- desconocida para el jugador no gana nada mostrandola, y color de
    -- reaccion sigue siendo la señal mas legible en combate).
    if okP and isPlayer and isFriendly and FriendlySettings().classColor then
        local r, g, b = ClassColor(unit)
        if r then
            f.name:SetTextColor(r, g, b)
            return
        end
    end
    if okP and isPlayer then
        f.name:SetTextColor(1, 1, 1)
    else
        local r, g, b = ReactionColor(unit)
        f.name:SetTextColor(r, g, b)
    end
end

-- FIX (2026-08-03, "el cast bar no es una textura que progrese"): la
-- version anterior inventaba un metodo GetRemainingDuration() sobre el
-- objeto que devuelve UnitCastingDuration/UnitChannelDuration -- ese
-- metodo no existe, asi que siempre fallaba y caia al fallback fijo de
-- 1.5s, dando una progresion falsa/rota para casi cualquier cast real.
-- La API REAL (ya usada con exito en este mismo addon, Nameplates.lua
-- viejo) es pasar el objeto de duracion DIRECTO a
-- StatusBar:SetTimerDuration(duration, nil, direction) -- el widget
-- calcula y anima el progreso el mismo, no hace falta OnUpdate manual.
-- Colores del cast bar (2026-08-03, "que falta implementar" -- pedido de
-- icono + escudo no-interrumpible): mismo criterio de color que casi todo
-- addon de nameplates -- amarillo/ambar normal, gris cuando
-- notInterruptible es true (no se puede interrumpir).
local CAST_COLOR = { 1, 0.7, 0 }
local CAST_COLOR_NOINT = { 0.6, 0.6, 0.6 }

local function UpdateCast(f, unit)
    local okC, name, _, texC, _, endMS, _, _, notIntC = pcall(UnitCastingInfo, unit)
    local okCh, cname, _, texCh, _, cend, _, notIntCh = pcall(UnitChannelInfo, unit)
    local isChannel = okCh and cname and true or false
    local castName = (okC and name) or (isChannel and cname)
    if not castName then
        f.cast:Hide()
        return
    end
    f.cast:Show()
    f.cast.text:SetText(castName)
    -- Icono del hechizo -- 3er valor de ambas APIs (texture), ya secret-safe
    -- via los mismos pcall de arriba.
    local icon = isChannel and texCh or texC
    if icon then f.cast.icon:SetTexture(icon); f.cast.icon:Show()
    else f.cast.icon:Hide() end
    -- FIX (2026-08-03, crash en vivo -- 2da ronda, "attempt to perform
    -- boolean test on local 'notIntCh'"): el fix anterior corria el guard
    -- DESPUES de armar `isChannel and notIntCh or notIntC` -- pero ESE
    -- `and/or` YA testea la verdad de notIntCh/notIntC como parte de su
    -- propia evaluacion (necesita saber si "isChannel and notIntCh" dio algo
    -- truthy para decidir si usar el `or notIntC`) -- crashea ANTES de que
    -- el guard de abajo pueda correr. Un if/then explicito, elegido por
    -- isChannel (nunca secreto), asigna el valor SIN testear su verdad --
    -- recien despues, ya con un solo valor en la mano, se chequea
    -- issecretvalue().
    local notInterruptible
    if isChannel then notInterruptible = notIntCh else notInterruptible = notIntC end
    if issecretvalue and issecretvalue(notInterruptible) then notInterruptible = false end
    local c = notInterruptible and CAST_COLOR_NOINT or CAST_COLOR
    pcall(f.cast.SetStatusBarColor, f.cast, c[1], c[2], c[3])
    local duration = isChannel
        and (UnitChannelDuration and UnitChannelDuration(unit))
        or (UnitCastingDuration and UnitCastingDuration(unit))
    if duration and f.cast.SetTimerDuration then
        local direction = (isChannel and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime)
            or (Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime)
        pcall(f.cast.SetTimerDuration, f.cast, duration, nil, direction)
    end
end

-- Clasificacion (elite/rare/boss) -- mismo criterio que el sistema viejo:
-- nivel < 1 fuerza "worldboss" (algunos world bosses no vienen marcados
-- directo por Blizzard).
local function UpdateClassification(f, unit)
    local ok, c = pcall(UnitClassification, unit)
    if ok then
        local okLvl, lvl = pcall(UnitLevel, unit)
        if okLvl and lvl and lvl < 1 then c = "worldboss" end
    end
    local tex = ok and CLASS_TEX[c]
    if tex then
        f.classIcon:SetTexture(tex)
        f.classIcon:Show()
    else
        f.classIcon:Hide()
    end
end

-- Marca de raid target -- API nativa publica (no secreta): GetRaidTargetIndex
-- + SetRaidTargetIconTexture sobre el mismo atlas que usa Blizzard.
local function UpdateRaidMark(f, unit)
    local okI, idx = pcall(GetRaidTargetIndex, unit)
    if okI and idx then
        pcall(SetRaidTargetIconTexture, f.raidMark, idx)
        f.raidMark:Show()
    else
        f.raidMark:Hide()
    end
end

------------------------------------------------------------------------------
-- Ciclo de vida.
------------------------------------------------------------------------------
ns.plates = ns.plates or {}

local function SetUnit(nameplate, unit)
    local friendly = IsFriendlyUnit(unit)
    local nameOnly = false
    if friendly then
        local category = UnitCategory(unit)
        -- NOTA (2026-08-03): hubo un intento de forzar "solo nombre" nativo
        -- para NPCs/pets de instancia via SetShowOnlyName -- revertido por
        -- completo (ver el comentario largo en ApplyDungeonNameOnlyCVars):
        -- tocar ESE metodo dejaba el frame marcado como tocado-por-addon, y
        -- Blizzard crasheaba solo al reciclarlo para otra unidad. NPCs/pets
        -- en instancia vuelven a pasar por el flujo normal de abajo (misma
        -- logica que en mundo abierto) -- HideBlizzardFrame ya evita tocar
        -- hijos forbidden/protected, asi que es lo mas seguro disponible.
        local fs = FriendlySettings()
        local mode = (category == "player" and fs.playerMode)
            or (category == "pet" and fs.petMode)
            or fs.npcMode
        -- Pedido del usuario 2026-08-03: "que en dungeon o raid se
        -- desactive automaticamente friendly npc nameplates y cuando salga
        -- se active de nuevo... que incluya tambien el de minions".
        -- "Minions" = pets/guardianes/totems (categoria "pet" ya existente).
        -- Fuerza "off" SOLO mientras estas en party/raid -- no toca ni
        -- reemplaza el modo configurado arriba, asi que al salir de
        -- instancia vuelve solo al valor de siempre sin guardar nada aparte.
        if category ~= "player" and fs.autoDisableNPCsInInstance and InPartyOrRaidInstance() then
            mode = "off"
        end
        if mode == "off" then return end -- categoria apagada: plate nativo de Blizzard intacto
        nameOnly = (mode == "nameonly")
    end

    local f = AcquirePlateFrame()
    nameplate._mcfNext = f
    f.unit = unit
    f.isFriendly = friendly
    f.nameOnly = nameOnly
    f:SetParent(nameplate)
    f:ClearAllPoints()
    f:SetPoint("CENTER", nameplate, "CENTER", 0, 0)
    local okLvl, lvl = pcall(nameplate.GetFrameLevel, nameplate)
    f:SetFrameLevel((okLvl and lvl or 0) + 1)
    -- Frame reciclado del pool: puede venir con el alpha nativo espejado de
    -- la unidad ANTERIOR que ocupo este mismo frame (ver el driver ticker
    -- mas abajo) -- arranca en 1 siempre, el proximo tick (0.2s) lo corrige
    -- con el valor real de esta unidad en cuanto el motor lo reporte.
    f:SetAlpha(1)
    f:Show()
    ReassertLayout(f, nameOnly)
    f.health:SetShown(not nameOnly)
    f.healthValue:SetShown(not nameOnly)
    if nameOnly then
        f.cast:Hide()
        f.classIcon:Hide()
        f.raidMark:Hide()
    end
    UpdateHealth(f, unit, friendly)
    UpdateName(f, unit, friendly)
    if not nameOnly then
        -- pcall (2026-08-03): defensa extra -- si algun caso de secreto no
        -- contemplado se cuela de nuevo, que rompa SOLO esta unidad, no el
        -- resto del loop del driver (ver el mismo pcall abajo en el ticker).
        pcall(UpdateCast, f, unit)
        UpdateClassification(f, unit)
        UpdateRaidMark(f, unit)
    end
    HideBlizzardFrame(nameplate, unit)
    if not nameOnly and ns.NPAurasNext_Update then pcall(ns.NPAurasNext_Update, f, unit) end
    ns.plates[unit] = f
    -- Primer plate propia activa: reanima el driver de 0.2s (arranca
    -- oculto/sin OnUpdate, ver el comentario en su CreateFrame).
    if driverFrame then driverFrame:Show() end
end

local function ClearUnit(nameplate, unit)
    RestoreBlizzardFrame(nameplate)
    local f = nameplate._mcfNext
    if f then
        if ns.NPAurasNext_Hide then pcall(ns.NPAurasNext_Hide, f) end
        f.unit = nil
        f.isFriendly = nil
        f.nameOnly = nil
        f.cast.endTime = nil
        nameplate._mcfNext = nil
        ReleasePlateFrame(f)
    end
    if unit then ns.plates[unit] = nil end
    -- Sin plates propias activas: apaga el driver (0 costo de OnUpdate
    -- hasta que aparezca la proxima).
    if driverFrame and not next(ns.plates) then driverFrame:Hide() end
end

-- Asignacion real del forward-decl de mas arriba (ApplyDungeonNameOnlyCVars
-- la llama cuando el modo dungeon name-only realmente cambia de estado).
-- Reconstruye CADA plate activa desde cero (ClearUnit+SetUnit) para que
-- adopte el criterio nuevo -- SetUnit ya sabe, via
-- DungeonNameOnlyShouldBeActive(), si debe abstenerse por completo para
-- NPCs/pets o volver a armar el plate propio normalmente.
SweepFriendlyPlates = function()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
        local f = nameplate._mcfNext
        if f and f.unit then
            local u = f.unit
            ClearUnit(nameplate, u)
            SetUnit(nameplate, u)
        end
    end
end

------------------------------------------------------------------------------
-- CVars nativos: escala/alpha/distancia (2026-08-03, "agrega los que tenia
-- la version anterior de escala, alpha, distancia"). Puerto literal de
-- ApplyMaxDistanceNow (Nameplates.lua:527-565, sistema viejo, DESHABILITADO
-- en el .toc para esta prueba de 12.1.0) -- el panel de Options YA TENIA las
-- pestañas np_alpha/np_scale/Range con los sliders correctos (escriben
-- directo a db.nameplates.*), pero nadie las APLICABA: ns.RefreshNameplateStyle
-- es la funcion que ApplyCurrent (core.lua:1092) llama en cada edit, y con el
-- archivo viejo apagado quedaba sin definir (guardado con `if
-- ns.RefreshNameplateStyle then`, asi que no rompia nada, solo no hacia nada).
-- SetCVar no es una API protegida, pero SI se bloquea en combate en este
-- build (ADDON_ACTION_BLOCKED) -- mismo patron de reintento en
-- PLAYER_REGEN_ENABLED que el original.
------------------------------------------------------------------------------
-- ns.IsNameplates/ns.NAMEPLATES_KEY tambien vivian solo en Nameplates.lua
-- (deshabilitado) -- sin esto, ApplyCurrent (core.lua:1091) nunca reconoce
-- que la seccion activa del panel es "nameplates" y el guard `ns.IsNameplates
-- and ...` corta antes de llegar a RefreshNameplateStyle en cada edit.
ns.NAMEPLATES_KEY = ns.NAMEPLATES_KEY or "nameplates"
ns.IsNameplates = ns.IsNameplates or function(key) return key == ns.NAMEPLATES_KEY end

-- FIX (2026-08-03, "que no se muestren los occluded nameplates cuando tengo
-- un target -- esto pasa tambien sin addon, debe ser algo de cvars"):
-- confirmado -- nameplateOccludedAlphaMult es el CVar nativo que dimea las
-- plates detras de paredes/objetos, y Blizzard lo aplica SIEMPRE, tengas
-- target o no. El pedido es condicional (solo mientras hay target
-- seleccionado, para no perder de vista enemigos detras de cobertura en
-- mundo abierto sin combate) -- por eso no alcanza con dejar alphaOccluded
-- fijo en 0 en la pestaña Alpha, hace falta reevaluar en cada cambio de
-- target. p.hideOccludedWithTarget (nuevo toggle, pestaña Alpha) fuerza el
-- CVar a 0 solo cuando UnitExists("target") es true; sin target, se respeta
-- el slider "Occluded alpha" normal.
local function EffectiveOccludedAlpha(p)
    if p and p.hideOccludedWithTarget then
        local okT, hasTarget = pcall(UnitExists, "target")
        if okT and hasTarget then return 0 end
    end
    return (p and p.alphaOccluded) or 1
end

local pendingStyleApply = false
local function ApplyNameplateStyleNow()
    local p = P()
    local dist = (p and p.maxDistance) or 40
    local minAlpha = (p and p.fadeMinAlpha) or 0.4
    local maxAlpha = (p and p.alphaMax) or 1
    local targetAlpha = (p and p.alphaTarget) or 1
    local notSelectedAlpha = (p and p.alphaNotSelected) or 1
    local occludedAlpha = EffectiveOccludedAlpha(p)
    pcall(SetCVar, "nameplateMaxDistance", tostring(dist))
    pcall(SetCVar, "nameplateMinAlpha", tostring(minAlpha))
    pcall(SetCVar, "nameplateMinAlphaDistance", "10")
    pcall(SetCVar, "nameplateMaxAlpha", tostring(maxAlpha))
    pcall(SetCVar, "nameplateMaxAlphaDistance", tostring(dist))
    pcall(SetCVar, "nameplateSelectedAlpha", tostring(targetAlpha))
    pcall(SetCVar, "nameplateNotSelectedAlpha", tostring(notSelectedAlpha))
    pcall(SetCVar, "nameplateOccludedAlphaMult", tostring(occludedAlpha))
    local globalScale = (p and p.globalScale) or 1
    local selectedScale = (p and p.selectedScale) or 1
    pcall(SetCVar, "nameplateGlobalScale", tostring(globalScale))
    pcall(SetCVar, "nameplateSelectedScale", tostring(selectedScale))
    pcall(SetCVar, "nameplateMinScale", tostring(globalScale))
    pcall(SetCVar, "nameplateMaxScale", tostring(globalScale))
    -- Mismo gate de combate que todo lo demas aca (SetCVar bloqueado en
    -- combate en este build) -- ApplyNameplateStyleNow ya solo se llama
    -- fuera de combate (o via el reintento en PLAYER_REGEN_ENABLED), asi que
    -- alcanza con colgarse de aca en vez de duplicar el pendingStyleApply.
    ApplyDungeonNameOnlyCVars()
    ApplyAutoDisableAlpha()
    -- FIX (2026-08-05, "traer de vuelta el diseñador con el nuevo sistema"):
    -- ReassertLayout (nombre/vida/cast/etc) solo corria UNA VEZ, al asignar
    -- la unidad al frame -- un cambio de offset en el panel (o del futuro
    -- Designer) no se veia hasta que la plate cambiara de unidad de nuevo.
    -- Bustear el _mcfLayoutSig y reaplicar en cada plate ACTIVA hace que
    -- cualquier edit se refleje al toque, igual que ya pasa con auras/
    -- alpha/escala -- mismo criterio que el barrido de SweepFriendlyPlates
    -- arriba.
    for _, f in pairs(ns.plates) do
        if f then
            f._mcfLayoutSig = nil
            ReassertLayout(f, f.nameOnly)
            -- FIX (2026-08-05, "que se aplique en vivo el auraIconSize"):
            -- ver el comentario largo en ns.NPAurasNext_Rebuild -- destruye
            -- los containers de esta plate y los recrea al toque si sigue
            -- siendo el target (mismo gate que ns.NPAurasNext_Update ya usa).
            if ns.NPAurasNext_Rebuild then pcall(ns.NPAurasNext_Rebuild, f) end
            if not f.nameOnly and ns.NPAurasNext_Update and UnitIsUnit(f.unit, "target") then
                pcall(ns.NPAurasNext_Update, f, f.unit)
            end
        end
    end
    -- Barrido INCONDICIONAL (2026-08-03, "auto-disable NPCs/pets in
    -- instance"): a diferencia de ApplyDungeonNameOnlyCVars (que solo
    -- barre si SU PROPIO estado cambio), este toggle es independiente --
    -- necesita reevaluarse cada vez que se edita algo en el panel de
    -- Nameplates, para que prender/apagar el checkbox surta efecto al
    -- instante sin esperar a cambiar de zona. ClearUnit/SetUnit son
    -- nuestro propio frame, siempre seguros de llamar.
    if SweepFriendlyPlates then SweepFriendlyPlates() end
end

function ns.RefreshNameplateStyle()
    if InCombatLockdown and InCombatLockdown() then
        pendingStyleApply = true
        return
    end
    ApplyNameplateStyleNow()
end

local styleEv = CreateFrame("Frame")
styleEv:RegisterEvent("PLAYER_ENTERING_WORLD")
styleEv:RegisterEvent("PLAYER_REGEN_ENABLED")
-- Dispara la reevaluacion de EffectiveOccludedAlpha en cada cambio de target
-- (adquirir/soltar target) -- sin esto, el toggle solo se aplicaria en login/
-- reload/salir de combate, no en vivo mientras jugas.
styleEv:RegisterEvent("PLAYER_TARGET_CHANGED")
styleEv:RegisterEvent("ZONE_CHANGED_NEW_AREA")
styleEv:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_TARGET_CHANGED" then
        -- FIX: target se cambia CONSTANTEMENTE en combate (tab-target, click),
        -- y SetCVar SI se bloquea en combate en este build -- tiene que pasar
        -- por el mismo gate de reintento que el resto, no aplicar directo.
        ns.RefreshNameplateStyle()
        return
    end
    if event == "ZONE_CHANGED_NEW_AREA" then
        -- FIX (2026-08-03, "en dungeon o raid... ocultar el nativo de
        -- blizzard en dungeon"): sin esto, el override de instancia solo se
        -- notaria en plates NUEVAS (NAME_PLATE_UNIT_ADDED) -- companions/
        -- pets que ya estaban en pantalla al cruzar el portal se quedarian
        -- con el modo viejo. instCacheAt=0 fuerza a InPartyOrRaidInstance a
        -- re-leer YA (su cache de 1s podria devolver el estado de ANTES de
        -- cruzar el portal si se consulta en el mismo frame que el evento).
        -- RefreshNameplateStyle ahora barre SIEMPRE al final (ver el
        -- comentario en ApplyNameplateStyleNow) -- alcanza con llamarlo.
        instCacheAt = 0
        ns.RefreshNameplateStyle()
        return
    end
    if event == "PLAYER_REGEN_ENABLED" and not pendingStyleApply then return end
    pendingStyleApply = false
    ApplyNameplateStyleNow()
end)

------------------------------------------------------------------------------
-- Ticker: refresca vida/cast/highlight de las plates activas (0.2s, mismo
-- intervalo que ya usaba el sistema viejo para esto).
------------------------------------------------------------------------------
local acc = 0
local driver = CreateFrame("Frame")
-- Arranca oculto (2026-08-03, patron de EllesmereUI_Ticker.lua) -- recien
-- se Show()ea cuando SetUnit arma la primer plate propia. Sin esto, el
-- OnUpdate corria SIEMPRE desde el login aunque no hubiera ni un solo
-- plate cerca (la mayoria del tiempo en mundo abierto).
driver:Hide()
driverFrame = driver
driver:SetScript("OnUpdate", function(self, elapsed)
    acc = acc + elapsed
    if acc < 0.2 then return end
    acc = 0
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
        local f = nameplate._mcfNext
        if f and f.unit and f:IsShown() then
            local uf = nameplate.UnitFrame
            -- REVERTIDO (2026-08-03): ya NO se espeja nada de uf sobre f --
            -- f:SetAlpha se deja fijo en 1 (puesto una sola vez en SetUnit) y
            -- la oclusion/distancia/seleccion le llegan SOLAS via herencia
            -- multiplicativa de WoW (f es hijo de `nameplate`, que es a
            -- quien el motor realmente le aplica esos CVars) -- exactamente
            -- el mecanismo que EllesmereUI documenta usar sin codigo extra.
            -- Ver el comentario largo en HideBlizzardFrame de por que el
            -- espejo via uf estaba MAL (importaba la exencion de target).
            UpdateHealth(f, f.unit, f.isFriendly)
            UpdateName(f, f.unit, f.isFriendly)
            if not f.nameOnly then
                pcall(UpdateCast, f, f.unit)
                UpdateRaidMark(f, f.unit)
                local isTarget = uf and uf.isTarget and true or false
                f.highlight:SetShown(isTarget)
                -- FIX (2026-08-03, "las auras deben estar activas en mas
                -- nameplates ademas del target -- son debuffs personales"):
                -- EllesmereUI las muestra en TODOS los plates visibles (su
                -- pool de bundles se attachea a cada plate activo, no solo
                -- al target -- confirmado leyendo EUI_Nameplates_
                -- AuraContainers.lua). Antes esto se gateaba con isTarget
                -- sin motivo real -- tus propios debuffs son igual de
                -- utiles de ver en cualquier enemigo, no solo el
                -- seleccionado.
                if ns.NPAurasNext_Update then
                    pcall(ns.NPAurasNext_Update, f, f.unit)
                end
            end
        end
    end
end)

------------------------------------------------------------------------------
-- Eventos.
------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("NAME_PLATE_UNIT_ADDED")
ev:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
ev:SetScript("OnEvent", function(self, event, unit)
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return end
    -- FIX (2026-08-03, causa raiz real de "sigo viendo el cast bar nativo"
    -- -- confirmada con /mcfcastbardiag: ourPlate(f)=false en TODAS las
    -- unidades amistosas, todas ForbiddenNamePlateUnitFrameTemplate).
    -- C_NamePlate.GetNamePlateForUnit(unit) tiene un 2do parametro
    -- includeForbidden que DEFAULT A FALSE -- sin pasar `true`, esta
    -- llamada devuelve nil para CUALQUIER ForbiddenNamePlate (no es
    -- exclusivo de instancias -- companions, NPCs de escolta, mascotas
    -- ajenas en mundo abierto tambien lo son). Este handler nunca llamaba
    -- SetUnit para NINGUNA de esas unidades -- HideBlizzardFrame nunca
    -- corria, asi que el plate nativo (barra Y cast bar) quedaba 100%
    -- intacto sin que ningun modo/toggle del panel pudiera hacer nada al
    -- respecto. No era un bug del cast bar especificamente -- era el
    -- sistema entero nunca enterandose de que esa unidad existia.
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit, true)
    if not nameplate then return end
    if event == "NAME_PLATE_UNIT_ADDED" then
        SetUnit(nameplate, unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        ClearUnit(nameplate, unit)
    end
end)

SLASH_MCFNPNEXTDIAG1 = "/mcfnpnextdiag"
SlashCmdList["MCFNPNEXTDIAG"] = function()
    print("|cff00ff00[MCF NPNext diag]|r activo=" .. tostring(ns.IsMidnightNext))
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    local plates = C_NamePlate.GetNamePlates()
    print("  nameplates visibles=" .. tostring(#plates))
    local sample, sampleUnit
    for _, np in ipairs(plates) do
        local u = np.namePlateUnitToken or np.unitToken
        local uf = np.UnitFrame
        if uf and uf.isTarget then sample = np; sampleUnit = u; break end
    end
    if not sample then sample = plates[1]; sampleUnit = sample and (sample.namePlateUnitToken or sample.unitToken) end
    if not sample then print("  sin plates visibles"); return end
    local f = sample._mcfNext
    print("  unit=" .. tostring(sampleUnit) .. " f=" .. tostring(f ~= nil))
    -- Diagnostico de clasificacion (2026-08-03, "no estoy seguro si esta el
    -- icono de elite o solo el de boss"): imprime la clasificacion CRUDA de
    -- Blizzard y el nivel, para confirmar si el override "lvl<1 -> worldboss"
    -- se esta disparando de mas (UnitLevel devuelve -1 en MUCHOS elites de
    -- nivel alto, no solo en world bosses reales).
    if sampleUnit then
        local okC, cls = pcall(UnitClassification, sampleUnit)
        local okL, lvl = pcall(UnitLevel, sampleUnit)
        print(("  UnitClassification=%s(%s) UnitLevel=%s(%s) -> textura usada=%s"):format(
            tostring(cls), tostring(okC), tostring(lvl), tostring(okL),
            tostring(f and f.classIcon and f.classIcon:GetTexture())))
    end
    if not f then return end
    print(("  f: shown=%s health.shown=%s cast.shown=%s highlight.shown=%s"):format(
        tostring(select(2, pcall(f.IsShown, f))), tostring(select(2, pcall(f.health.IsShown, f.health))),
        tostring(select(2, pcall(f.cast.IsShown, f.cast))), tostring(select(2, pcall(f.highlight.IsShown, f.highlight)))))
    if f.mcfAurasNext then
        for key, c in pairs(f.mcfAurasNext) do
            -- SIMPLIFICADO (2026-08-03, "???" en las 3 lineas de aura,
            -- 2 rondas seguidas): la version con GetSize/GetPoint/
            -- GetFrameStrata crasheaba (probablemente ESAS llamadas -- ver
            -- el patron ya confirmado de "restringido despues de
            -- AddAuraGroup"), y el mensaje de error en si no se copiaba
            -- limpio desde el chat. Vuelta a lo minimo que SI funciono
            -- rondas atras: shown/unit/children/mcfIcon, cada dato en su
            -- propio pcall individual para que UNO que falle no tape a
            -- los demas.
            local okShown, shown = pcall(function() return c:IsShown() end)
            local okN, n = pcall(function() return c:GetNumChildren() end)
            local okI, hasIcon = pcall(function()
                local kid = select(1, c:GetChildren())
                return kid and kid.mcfIcon ~= nil
            end)
            print(("  aura[%s]: shown=%s(%s) unit=%s children=%s(%s) icon=%s(%s)"):format(
                key, tostring(shown), tostring(okShown), tostring(c._mcfNextUnit),
                tostring(n), tostring(okN), tostring(hasIcon), tostring(okI)))
        end
    end
end

-- Diagnostico dedicado (2026-08-03, "sigue ocurriendo" -- 2do intento a
-- ciegas sin ver el problema real): imprime la cadena completa
-- CVar -> alpha nativo capturado -> nameplate propio -> f, para CADA plate
-- visible, asi se puede ver EXACTAMENTE en que eslabon se corta en vez de
-- seguir adivinando.
SLASH_MCFOCCDIAG1 = "/mcfoccdiag"
SlashCmdList["MCFOCCDIAG"] = function()
    local p = P()
    print("|cff00ff00[MCF Occlusion diag]|r")
    print(("  db: hideOccludedWithTarget=%s alphaOccluded=%s"):format(
        tostring(p and p.hideOccludedWithTarget), tostring(p and p.alphaOccluded)))
    local okCV, cv = pcall(GetCVar, "nameplateOccludedAlphaMult")
    print(("  CVar nameplateOccludedAlphaMult=%s (ok=%s)"):format(tostring(cv), tostring(okCV)))
    local okT, hasTarget = pcall(UnitExists, "target")
    print(("  UnitExists(target)=%s"):format(tostring(okT and hasTarget)))
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
        local f = nameplate._mcfNext
        local uf = nameplate.UnitFrame
        if f and f.unit then
            local okNPA, npA = pcall(nameplate.GetAlpha, nameplate)
            local okFA, fA = pcall(f.GetAlpha, f)
            -- GetEffectiveAlpha (2026-08-03): el valor que REALMENTE se
            -- renderiza (propio x de todos los padres en cadena) -- el
            -- GetAlpha propio de f siempre va a decir 1 ahora (ya no lo
            -- tocamos), lo que importa es este.
            local okEA, eA = pcall(f.GetEffectiveAlpha, f)
            print(("  unit=%s isTarget=%s | nameplate.alpha=%s(%s) f.alpha=%s(%s) f.EFFECTIVE=%s(%s)"):format(
                tostring(f.unit), tostring(uf and uf.isTarget),
                tostring(npA), tostring(okNPA), tostring(fA), tostring(okFA),
                tostring(eA), tostring(okEA)))
        end
    end
end

SLASH_MCFPLATERALPHADIAG1 = "/mcfplateralphadiag"
SlashCmdList["MCFPLATERALPHADIAG"] = function()
    local p = P()
    print("|cff00ff00[MCF Plater-style diag]|r")
    print(("  db.friendlyAutoDisableNPCsInInstance=%s"):format(tostring(p and p.friendlyAutoDisableNPCsInInstance)))
    print(("  InPartyOrRaidInstance()=%s autoAlphaApplied=%s autoAlphaHooked=%s TextureLoadingGroupMixin=%s"):format(
        tostring(InPartyOrRaidInstance()), tostring(autoAlphaApplied), tostring(autoAlphaHooked),
        tostring(TextureLoadingGroupMixin ~= nil)))
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, np in ipairs(C_NamePlate.GetNamePlates(true)) do
        local uf = np.UnitFrame
        if uf then
            local unit = uf.unit
            local hbc = uf.HealthBarsContainer
            local hb = hbc and hbc.healthBar
            -- Lectura de CAMPO plano, no llamada a metodo -- confirmado
            -- legible en los dumps de error de rondas anteriores.
            local showOnly = hb and hb.showOnlyName
            -- Ampliado (2026-08-03, "es muy complicado testear mientras
            -- castea"): el flag NO depende de que haya un cast activo AHORA
            -- -- se pone proactivo via el hook/sweep, deberia persistir
            -- igual. Se agrega uf.castBar (existe o no, sin depender de
            -- timing) + sus 2 flags + el flag a nivel del UnitFrame entero.
            local cb = uf.castBar
            print(("  unit=%s isFriendlyNonPlayer=%s isForbidden=%s | healthBar.showOnlyName=%s | castBar=%s castBar.showOnlyName=%s castBar.widgetsOnly=%s | uf.showOnlyName=%s"):format(
                tostring(unit), tostring(IsFriendlyNonPlayerUnit(unit)),
                tostring(np.unitFrameTemplate == "ForbiddenNamePlateUnitFrameTemplate"),
                tostring(showOnly), tostring(cb ~= nil), tostring(cb and cb.showOnlyName),
                tostring(cb and cb.widgetsOnly), tostring(uf.showOnlyName)))
        end
    end
end

-- Diagnostico dedicado (2026-08-03, "aun sigue saliendo el cast bar" pese
-- al SetAlpha(0)+hook persistente sobre uf.castBar): confirma si uf.castBar
-- existe de verdad para la unidad amistosa en cuestion, si nuestro propio
-- SetUnit siquiera construyo un plate para ella (f), y el alpha real que
-- tiene el castBar nativo AHORA MISMO.
SLASH_MCFCASTBARDIAG1 = "/mcfcastbardiag"
SlashCmdList["MCFCASTBARDIAG"] = function()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    print("|cff00ff00[MCF Castbar diag]|r")
    for _, np in ipairs(C_NamePlate.GetNamePlates(true)) do
        local uf = np.UnitFrame
        if uf then
            local unit = uf.unit
            local f = np._mcfNext
            local okFriend, isFriend = pcall(UnitIsFriend, "player", unit)
            local okPlayer, isPlayer = pcall(UnitIsPlayer, unit)
            if okFriend and isFriend then
                local cb = uf.castBar
                local okA, a = cb and pcall(cb.GetAlpha, cb)
                print(("  unit=%s isPlayer=%s ourPlate(f)=%s uf.castBar=%s alpha=%s(%s) uf.unitFrameTemplate=%s"):format(
                    tostring(unit), tostring(okPlayer and isPlayer), tostring(f ~= nil),
                    tostring(cb ~= nil), tostring(a), tostring(okA), tostring(np.unitFrameTemplate)))
            end
        end
    end
end
