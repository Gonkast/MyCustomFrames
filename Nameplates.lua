-- ==========================================================================
-- MyCustomFrames - Nameplates.lua
-- Reskin de los nameplates NATIVOS de Blizzard (CompactUnitFrame) para que
-- se vean como los de AzeriteUI: NO se reemplaza el frame, NO se usa oUF --
-- se retexturan/redimensionan los elementos que Blizzard ya crea y ya
-- actualiza (color de vida, texto, threat, etc siguen siendo 100% nativos,
-- cero riesgo de secret-value taint porque no leemos/mutamos esos datos).
-- Standalone, mismo patron que Minimap.lua. Carga DESPUES de Minimap.lua.
-- ==========================================================================
local ADDON, ns = ...

-- ---- Assets (copiados de AzeriteUI5_JuNNeZ_Edition/Assets) ----
local A = ns.ASSETS
local BAR_TEX        = A .. "nameplate_bar.tga"
local BACKDROP_TEX   = A .. "nameplate_backdrop.tga"
local OUTLINE_TEX    = A .. "nameplate_outline.tga"
local GLOW_TEX       = A .. "nameplate_glow.tga"

-- Texcoord de la barra: la textura original de AzeriteUI tiene padding en los
-- bordes (pensada para un StatusBar de 256x64) -- hay que recortarlo o se ve
-- un marco fino de mas alrededor del relleno real.
local BAR_TEXCOORD = { 14/256, 242/256, 14/64, 50/64 }

-- (HEALTH_SIZE/CAST_SIZE se mudaron a ns.NPLayout.FACTORY -- eran una
-- segunda copia que debia coincidir con la de alla y no coincidia.)
-- El highlight de seleccion es un poco mas grande que la barra de vida (ver
-- GetHighlightSize, mas abajo) -- ya no es una constante fija, se deriva EN
-- VIVO del tamaño de vida configurado (healthWidth/healthHeight).
-- (AURA_BORDER_SCALE se mudo a ns.NPBuild: el designer tenia su propia copia
-- como literal 0.26 -- ahora hay una sola.)
-- (AURA_ICON_SIZE/AURA_SPACING tambien viven en ns.NPLayout.FACTORY.)

-- Font object global para el numero de "tiempo restante" que Blizzard dibuja
-- de forma NATIVA/secret-safe dentro del widget Cooldown (ver CreateAuraIcon)
-- -- CreateFont crea un objeto de fuente reusable que Cooldown:SetCountdownFont
-- acepta por NOMBRE. Tamaño/color se actualizan en vivo desde el perfil (ver
-- ReassertAuraTextStyle), y como es UN SOLO objeto compartido por todos los
-- iconos, actualizarlo una vez alcanza para todos.
local MCFAuraTimeFontObj = CreateFont("MCFAuraTimeFontObj")
MCFAuraTimeFontObj:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
MCFAuraTimeFontObj:SetTextColor(1, 1, 1, 1)
-- Defaults en HEX (#FFE19B, el dorado/ambar del resto del addon) usados
-- cuando el perfil todavia no tiene el campo -- ver NameplateDefaults.
local DEFAULT_TEXT_COLOR = { r = 0xFF/255, g = 0xE1/255, b = 0x9B/255 }
-- Rojo plano para jugadores enemigos (2026-08-03, "que los player enemigos
-- tenga el color rojo sin mas... quita la opcion"): reemplaza el toggle
-- "Color enemy player names by class" -- ya no es opcional, y el color de
-- clase se saca del todo (era la fuente del reporte "en arena es confuso
-- ver de que clase es un enemigo con solo mirar el nombre"). Mismo rojo
-- que colorHostile en core.lua (Units.lua), para que el nombre combine con
-- como el resto del addon pinta hostiles.
local HOSTILE_PLAYER_COLOR = { r = 0.85, g = 0.20, b = 0.20 }
-- "Dorado opaco" pedido originalmente = TargetHighlightTargetColor de
-- AzeriteUI (Layouts/Data/NamePlates.lua): 255/239/169.
local DEFAULT_HIGHLIGHT_COLOR = { r = 255/255, g = 239/255, b = 169/255 }

-- Texto "roto"/borroso a escala chica (pedido del usuario): Platynator tiene
-- un modulo dedicado para esto (Core/PixelPerfect.lua) -- redondea offsets al
-- pixel FISICO mas cercano segun la escala efectiva del momento, evitando
-- posiciones sub-pixel que blurrean texto/texturas cuando el nameplate se
-- achica por distancia. Misma tecnica, version chica solo para texto.
-- (SnapToPixel se mudo a NameplateBuild.lua: ahora lo aplica B.Place, asi el
-- redondeo al pixel fisico lo reciben las piezas reales Y las del editor.)

-- hooksecurefunc en vez de HookScript: highlight/bgTexture son Texture (no
-- Frame, sin scripts como OnSizeChanged -- confirmado por error en vivo), y
-- hooksecurefunc funciona sobre cualquier objeto con el metodo, Frame o no.
-- w/h aceptan un NUMERO fijo o una funcion `() -> w, h` (leida EN VIVO en cada
-- Reassert) -- el Designer/menu cambian tamaño en caliente sin tener que
-- recrear los hooks, misma idea que P() para offsets/colores.
local function LockSize(region, w, h)
    if not region then return end
    local locking = false
    local function GetWH()
        if type(w) == "function" then return w() end
        return w, h
    end
    local function Reassert()
        if locking then return end
        local tw, th = GetWH()
        -- FIX (2026-07-19, reportado por el usuario): region:GetSize() para
        -- ciertas regiones nativas del nameplate (ej. selectionHighlight)
        -- ahora puede devolver valores SECRETOS en este cliente -- comparar
        -- "cw == tw" sin chequear issecretvalue antes CRASHEA ("attempt to
        -- compare... a secret number value"). Si no se puede leer con
        -- certeza, se salta el dedupe y se reaplica directo (mismo costo que
        -- antes de que este dedupe existiera, seguro por diseño).
        local okGet, cw, ch = pcall(region.GetSize, region)
        local readable = okGet and type(cw) == "number" and type(ch) == "number"
            and not (issecretvalue and (issecretvalue(cw) or issecretvalue(ch)))
        if readable and cw == tw and ch == th then return end
        locking = true
        region:SetSize(tw, th)
        locking = false
    end
    hooksecurefunc(region, "SetSize", Reassert)
    if region.SetWidth then hooksecurefunc(region, "SetWidth", Reassert) end
    if region.SetHeight then hooksecurefunc(region, "SetHeight", Reassert) end
    region._mcfReassertSize = Reassert
    Reassert()
end

-- /mcfnpdiag en vivo confirmo el motivo real de la barra estirada: Blizzard
-- NO usa SetSize para dimensionar healthBar/castBar -- las ancla con DOS
-- puntos (numPoints=2, ej TOPLEFT+TOPRIGHT), y el ancho queda DERIVADO de la
-- distancia entre esos anclajes. Mientras existan 2 anclajes en conflicto,
-- SetSize no tiene efecto (por eso LockSize solo no alcanzaba). Fix: forzar
-- UN SOLO punto de anclaje (relativo al nameplate) + tamaño fijo, reafirmado
-- cada vez que Blizzard vuelve a llamar SetPoint.
-- w/h aceptan numero fijo o funcion `() -> w, h` (ver LockSize).
local function LockBar(region, parent, point, relPoint, x, y, w, h)
    if not region then return end
    local locking = false
    local function GetWH()
        if type(w) == "function" then return w() end
        return w, h
    end
    local function Reassert()
        if locking then return end
        locking = true
        local tw, th = GetWH()
        region:ClearAllPoints()
        region:SetPoint(point, parent, relPoint, x, y)
        region:SetSize(tw, th)
        locking = false
    end
    hooksecurefunc(region, "SetPoint", Reassert)
    hooksecurefunc(region, "SetSize", Reassert)
    if region.SetWidth then hooksecurefunc(region, "SetWidth", Reassert) end
    if region.SetHeight then hooksecurefunc(region, "SetHeight", Reassert) end
    region._mcfReassertBar = Reassert
    Reassert()
end

-- El highlight de seleccion (target/focus) y el glow de amenaza los sigue
-- coloreando Blizzard SOLO -- CompactUnitFrame_UpdateSelectionHighlight ya
-- les pone el vertex color correcto (focus celeste, target dorado, etc);
-- aca solo se cambia la TEXTURA de base, sin tocar esa logica de color.

local function P() return ns.GetDB() and ns.GetDB().nameplates end
-- Tamaños: los resuelve ns.NPLayout, la MISMA fuente que consulta el Designer
-- (2026-07-28). Antes cada lado tenia su cuenta con su propio fallback, y los
-- fallbacks ni siquiera coincidian entre si.
local function GetHealthSize()    return ns.NPLayout.HealthSize(P()) end
local function GetCastSize()      return ns.NPLayout.CastSize(P()) end
local function GetHighlightSize() return ns.NPLayout.HighlightSize(P()) end
local function GetAuraIconSize()  return ns.NPLayout.AuraIconSize(P()) end
ns.NAMEPLATES_KEY = "nameplates"
ns.IsNameplates = function(key) return key == ns.NAMEPLATES_KEY end

-- CAMBIADO (2026-07-19, pedido del usuario: primero "solo jugadores
-- amistosos", despues "agregame tambien NPCs amistosos (vendedores, guardias,
-- etc) pero no pets"). Aplica a: JUGADORES amistosos (color de clase, ver
-- ReassertNameGeometry) O NPCs amistosos que NO sean mascotas/guardianes de
-- un jugador (color preestablecido del perfil). UnitReaction(unit,"player")
-- NO es un valor secreto (info basica de reaccion, no de combate/vida) --
-- devuelve 1-8: <=3 hostil, 4 neutral, >=5 amistoso.
local function ShouldHideExceptName(unit)
    local p = P()
    if not (p and p.nameOnlyFriendlyNeutral) then return false end
    if not unit then return false end
    local okP, isPlayer = pcall(UnitIsPlayer, unit)
    if not okP then return false end
    if not isPlayer then
        -- NPC (incluye tu pet, ver isOwnPet mas abajo): excluir mascotas/
        -- totems/guardianes con dueño jugador por defecto (pedido del
        -- usuario: "pero no pets") -- opcional desde 2026-08-03
        -- (nameOnlyIncludePet, checkbox debajo del toggle principal): con
        -- eso prendido, entran al mismo "solo nombre" que cualquier otro
        -- NPC amistoso. Va ANTES del auto-apagado de abajo: si esto ya
        -- excluyo al pet aca (checkbox apagado), nunca tiene que llegar a
        -- evaluarse como candidato de auto-apagado.
        if not (p and p.nameOnlyIncludePet) then
            local okC, playerControlled = pcall(UnitPlayerControlled, unit)
            if okC and playerControlled then return false end
        end
    end
    -- Es TU PROPIO pet? (UnitIsUnit, no secreto -- compara tokens, no datos
    -- de la unidad). Ni "isPlayer" ni un UnitPlayerControlled generico
    -- alcanzan para distinguir esto del pet de OTRO jugador o un totem/
    -- guardian cualquiera -- el auto-apagado de abajo es especificamente
    -- para TU pet, no para cualquier cosa player-controlled.
    local isOwnPet = ns.safeBool(UnitIsUnit, unit, "pet")
    if isPlayer or isOwnPet then
        -- Auto-apagado para JUGADORES y TU PET (2026-08-03, pedido del
        -- usuario: primero "que se apague automaticamente para los player,
        -- en combate... por ejemplo en arena", despues aclarado "solo me
        -- importa con pet y jugadores aliados" al ver que con "Include
        -- pets" prendido el pet quedaba afuera de este chequeo -- solo
        -- miraba isPlayer). En esos momentos importa mas ver la info
        -- completa que ahorrar espacio; el resto de NPCs amistosos sigue
        -- funcionando igual que siempre, esto no los afecta.
        if ns.tickState and ns.tickState.inCombat then return false end
        local okInst, inInst, it = pcall(IsInInstance)
        if okInst and not (issecretvalue and (issecretvalue(inInst) or issecretvalue(it)))
           and inInst and it == "arena" then
            return false
        end
    end
    local okR, reaction = pcall(UnitReaction, unit, "player")
    -- REVERTIDO 2026-07-19: el intento de incluir reaction==4 (neutral,
    -- pensado para NPCs de escolta) termino afectando tambien a NPCs
    -- HOSTILES reportados por el usuario -- en la practica, varios mobs de
    -- dungeon que SI atacan igual devuelven reaction 4 (no son "neutral"
    -- de verdad en el sentido de UnitReaction que uno esperaria). Vuelve al
    -- comportamiento original y probado: solo reaction>=5 (amistoso puro).
    return okR and type(reaction) == "number" and reaction >= 5
end

-- Color de clase del NOMBRE cuando esta en modo "solo nombre" (pedido del
-- usuario 2026-07-19: "si esta tachado, los nombres tengan el color de la
-- clase"). UnitClass da el token de clase (info basica, no secreta) --
-- C_ClassColor.GetClassColor es la fuente oficial de color por clase.
local function GetClassColorForUnit(unit)
    local okC, _, classToken = pcall(UnitClass, unit)
    if not okC or not classToken then return nil end
    local okCol, col = pcall(function()
        return (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(classToken))
            or RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    end)
    if okCol and col and col.r then return col end
    return nil
end

local function NameplateDefaults()
    return {
        enabled = true,
        -- Pedido del usuario 2026-07-19: "que solo se vea el name en npc
        -- amistosos y neutrales" -- oculta barra/valor de vida, cast bar,
        -- auras, icono de clasificacion y marca de raid en esos NPCs,
        -- dejando SOLO el nombre (mismo color/tamaño/posicion configurados,
        -- sin tocar nada de eso). Ver ShouldHideExceptName mas abajo.
        nameOnlyFriendlyNeutral = false,
        -- Pedido del usuario 2026-08-03: "el nameplate del pet se muestra
        -- siempre... una opcion para toglear si quiero que este efecto haga
        -- tambien en el pet" -- off por default, mismo comportamiento de
        -- siempre (pets/totems/guardianes excluidos). Ver ShouldHideExceptName.
        nameOnlyIncludePet = false,
        -- Pedido del usuario 2026-07-19: solo nombre para NPCs aliados/
        -- escolta EN DUNGEON, via los 3 CVars nativos combinados (ver
        -- ApplyMaxDistanceNow) -- confirmado en vivo que funciona incluso en
        -- ForbiddenNamePlate. Independiente de nameOnlyFriendlyNeutral de
        -- arriba (ese es nuestro propio hide en Lua, este es 100% nativo).
        showFriendlyNPCPlates = true,
        -- Offset PROPIO para cuando el modo de arriba esta activo -- pedido
        -- del usuario 2026-07-19 ("podria controlar el offset de only show
        -- name"), independiente de nameOffsetX/Y (que sigue rigiendo el modo
        -- normal, con la barra visible).
        nameOnlyOffsetX = 0, nameOnlyOffsetY = 0,
        -- classColorEnemyNames QUITADO (2026-08-03): un jugador hostil real
        -- ahora SIEMPRE sale en rojo plano (HOSTILE_PLAYER_COLOR), sin
        -- opcion -- confundia en arena no poder saber la clase de un
        -- enemigo con solo mirar el color del nombre.
        -- Nombre: offset relativo al anclaje que YA usa Blizzard (TOP del
        -- nameplate), tamaño de fuente y color.
        nameOffsetX = 0, nameOffsetY = 0,
        nameFontSize = 12,
        nameColor = { r = DEFAULT_TEXT_COLOR.r, g = DEFAULT_TEXT_COLOR.g, b = DEFAULT_TEXT_COLOR.b },
        nameAlpha = 1,
        -- Valor de vida (texto propio, debajo de la barra). Pedido del
        -- usuario (2026-07-18): default en 0,0 igual que el nombre, no -2.
        healthValueOffsetX = 0, healthValueOffsetY = 0,
        healthValueFontSize = 13,
        healthValueColor = { r = DEFAULT_TEXT_COLOR.r, g = DEFAULT_TEXT_COLOR.g, b = DEFAULT_TEXT_COLOR.b },
        healthValueAlpha = 1,
        -- Highlight de seleccion (target/focus).
        highlightColor = { r = DEFAULT_HIGHLIGHT_COLOR.r, g = DEFAULT_HIGHLIGHT_COLOR.g, b = DEFAULT_HIGHLIGHT_COLOR.b },
        -- Auras: 2026-07-19, pedido del usuario -- de vuelta a 3 grupos
        -- PROPIOS independientes (Big Debuff/Personal Debuffs/Enemy Buffs),
        -- cada uno con su offset -- ver ClassifyAura mas abajo para el
        -- mapeo real via IsAuraFilteredOutByInstanceID.
        auraIconSize = ns.NPLayout.FACTORY.auraIcon,
        -- Y = 0: la altura base de los grupos ahora vive en AURA_BASE_Y dentro
        -- de ns.NPLayout (antes el +10 estaba aca, sumado a un gap disperso).
        -- X separa los tres grupos para que al resetear no queden apilados.
        bigDebuffOffsetX = 0, bigDebuffOffsetY = 0,
        personalDebuffsOffsetX = 0, personalDebuffsOffsetY = 0,
        enemyBuffsOffsetX = 0, enemyBuffsOffsetY = 0,
        auraShowBigDebuff = true,
        auraShowPersonalDebuffs = true,
        auraShowEnemyBuffs = true,
        -- Padding entre iconos (compartido por los 3 grupos) y direccion de
        -- crecimiento POR GRUPO -- pedido del usuario 2026-07-19: "right,
        -- left o center". Con menos de 3 auras activas, la direccion decide
        -- de que lado del punto de offset se van agregando (ver
        -- AURA_SLOT_ORDER mas abajo).
        auraPadding = ns.NPLayout.FACTORY.auraPad,
        bigDebuffDirection = "right",
        personalDebuffsDirection = "center",
        enemyBuffsDirection = "left",
        -- Numero de cargas/stacks -- pedido del usuario 2026-07-19: ademas
        -- del color (ya existia), ahora tambien offset y tamaño de fuente
        -- controlables ("debo controlar offset, size y color de eso").
        auraCountOffsetX = 2, auraCountOffsetY = 2,
        auraCountFontSize = 11,
        auraCountColor = { r = 255/255, g = 239/255, b = 169/255 },
        -- Texto de "tiempo restante" (pedido del usuario 2026-07-19: "los
        -- seconds remaining no estan saliendo, solo las cargas" -- se habia
        -- reemplazado por el swipe rotativo, ahora vuelve ADEMAS del swipe,
        -- no en su lugar). Compartido por los 3 grupos, esquina inferior.
        auraTimeOffsetX = 0, auraTimeOffsetY = -2,
        auraTimeFontSize = 10,
        auraTimeColor = { r = 255/255, g = 239/255, b = 169/255 },
        -- Icono de clasificacion (elite/rare/boss) y marca de raid -- pedido
        -- del usuario: controlar offset y tamaño de los dos desde el Designer
        -- (antes eran tamaño fijo, sin posicion configurable).
        classificationOffsetX = 0, classificationOffsetY = 0, classificationSize = 46,
        raidMarkOffsetX = 0, raidMarkOffsetY = 0, raidMarkSize = 20,
        -- Cast bar: offset relativo al BOTTOM de la barra de vida, y color
        -- fijo (amarillo/ambar por defecto, en vez del color nativo por
        -- escuela de magia).
        castOffsetX = 0, castOffsetY = 0,
        castColor = { r = DEFAULT_TEXT_COLOR.r, g = DEFAULT_TEXT_COLOR.g, b = DEFAULT_TEXT_COLOR.b },
        -- Pedido del usuario 2026-07-19 ("algo relacionado sobre si interrumpo
        -- un cast?"): la cast bar propia no distinguia casts NO interrumpibles
        -- (gris nativo de Blizzard) ni reaccionaba al interrumpirlos (flash
        -- rojo nativo) -- ver UpdateCastBar/UNIT_SPELLCAST_INTERRUPTED.
        castUninterruptibleColor = { r = 0.7, g = 0.7, b = 0.7 },
        castInterruptFlashColor = { r = 1, g = 0.2, b = 0.2 },
        castWidth = ns.NPLayout.FACTORY.castW, castHeight = ns.NPLayout.FACTORY.castH,
        -- Texto del nombre del hechizo, DENTRO de la cast bar.
        castTextFontSize = 12,
        castTextColor = { r = 255/255, g = 239/255, b = 169/255 },
        castTextAlpha = 1,
        castTextOffsetX = 0, castTextOffsetY = 0,
        -- Tamaño de la barra de vida (pedido del usuario: control de escala, no
        -- solo posicion -- ver NameplateDesigner.lua). El highlight de seleccion
        -- se deriva de esto (HIGHLIGHT_SIZE ya no es una constante fija).
        healthWidth = ns.NPLayout.FACTORY.healthW, healthHeight = ns.NPLayout.FACTORY.healthH,
        -- Distancia maxima de renderizado de nameplates (CVar nativo de
        -- Blizzard "nameplateMaxDistance").
        maxDistance = 40,
        -- Escala GLOBAL de los nameplates (CVar nativo). 1 = tamaño normal.
        globalScale = 1,
        -- Escala del nameplate del TARGET, relativa a la normal. 1 = igual que
        -- el resto; 1.2 = un 20% mas grande.
        selectedScale = 1,
        -- Fade por distancia: las que NO son tu target se atenuan a
        -- fadeMinAlpha a partir de cierta distancia -- tu target siempre
        -- queda al 100% (nameplateSelectedAlpha).
        fadeMinAlpha = 0.4,
        -- Controles de Alpha nativos de Blizzard (pedido del usuario
        -- 2026-07-19) -- CVars que antes estaban hardcodeados/sin tocar en
        -- ApplyMaxDistanceNow. alphaMax/alphaTarget default en 1 porque
        -- nuestro propio codigo YA los forzaba a "1" siempre (no cambia nada
        -- de la apariencia actual al agregar el control). alphaNotSelected/
        -- alphaOccluded nunca se tocaban -- default = valor ACTUAL del CVar
        -- en el cliente, asi agregar el control tampoco cambia nada hasta
        -- que el usuario mueva el slider.
        alphaMax = 1,
        alphaTarget = 1,
        alphaNotSelected = 1,
        alphaOccluded = 0,
    }
end
ns.NameplateDefaults = NameplateDefaults

-- ==========================================================================
-- PERFILES de nameplates (pedido del usuario: "necesito crear perfiles, y
-- opcion para tener la configuracion actual como preterminada"). Guardados
-- en db.nameplateProfiles (nombre -> snapshot completo de db.nameplates) y
-- db.nameplateUserDefault (snapshot usado por Reset -- ver ResetUnit en
-- core.lua). Todo vive en el MISMO SavedVariable de siempre (MyCustomFramesDB),
-- no hay un sistema de perfiles nuevo por separado.
-- ==========================================================================
ns.SetNameplateUserDefault = function()
    local d = ns.GetDB()
    if not d then return end
    d.nameplateUserDefault = ns.DeepCopy(d.nameplates)
    print("|cff00ff00[MCF]|r Current nameplate settings saved as your default (Reset will use this).")
end

ns.SaveNameplateProfile = function(name)
    local d = ns.GetDB()
    if not d or not name or name == "" then return end
    d.nameplateProfiles = d.nameplateProfiles or {}
    d.nameplateProfiles[name] = ns.DeepCopy(d.nameplates)
    print(("|cff00ff00[MCF]|r Saved nameplate profile: %s"):format(name))
end

ns.LoadNameplateProfile = function(name)
    local d = ns.GetDB()
    local p = d and d.nameplateProfiles and d.nameplateProfiles[name]
    if not p then return end
    d.nameplates = ns.DeepCopy(p)
    if ns.RefreshNameplateStyle then ns.RefreshNameplateStyle() end
    print(("|cff00ff00[MCF]|r Loaded nameplate profile: %s"):format(name))
end

ns.DeleteNameplateProfile = function(name)
    local d = ns.GetDB()
    if d and d.nameplateProfiles then
        d.nameplateProfiles[name] = nil
        print(("|cff00ff00[MCF]|r Deleted nameplate profile: %s"):format(name))
    end
end

ns.ListNameplateProfiles = function()
    local d = ns.GetDB()
    local list = {}
    if d and d.nameplateProfiles then
        for name in pairs(d.nameplateProfiles) do list[#list + 1] = name end
        table.sort(list)
    end
    return list
end

-- Todo esto son CVars NATIVOS de Blizzard (nameplateMaxDistance/MinAlpha/
-- MinAlphaDistance/MaxAlpha/MaxAlphaDistance/SelectedAlpha) -- SetCVar no es
-- una funcion protegida (a diferencia de Minimap:Hide()/SetScale de frames
-- Blizzard), cualquier addon puede tocarlos libremente. Nada de esto lee/
-- toca valores secretos: es la MISMA perilla que usa el Edit Mode nativo.
-- BUG (reportado por el usuario 2026-07-19, ADDON_ACTION_BLOCKED en
-- SetCVar): este cliente ("secrets") SI bloquea SetCVar EN COMBATE para
-- estos CVars puntuales, aunque normalmente no sea protegida -- el pcall ya
-- evitaba que rompiera algo, pero el bloqueo se seguia disparando/logueando
-- cada vez que el usuario arrastraba el slider de "Max distance" en el
-- designer estando en combate (ej. probando contra un dummy en zona de
-- combate). Fix: si InCombatLockdown(), no llamar SetCVar -- se reintenta
-- solo una vez, automaticamente, al salir de combate.
local pendingMaxDistanceApply = false
local ApplyMaxDistanceNow
local combatWatcher = CreateFrame("Frame")
combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
combatWatcher:SetScript("OnEvent", function()
    if pendingMaxDistanceApply then
        pendingMaxDistanceApply = false
        ApplyMaxDistanceNow()
    end
end)

ApplyMaxDistanceNow = function()
    local p = P()
    local dist = (p and p.maxDistance) or 40
    local minAlpha = (p and p.fadeMinAlpha) or 0.4
    -- Controles de Alpha (pedido del usuario 2026-07-19): antes maxAlpha/
    -- selectedAlpha estaban hardcodeados a "1" y notSelected/occluded nunca
    -- se tocaban -- ahora los 5 salen del perfil (ver NameplateDefaults).
    local maxAlpha = (p and p.alphaMax) or 1
    local targetAlpha = (p and p.alphaTarget) or 1
    local notSelectedAlpha = (p and p.alphaNotSelected) or 1
    local occludedAlpha = (p and p.alphaOccluded) or 1
    pcall(SetCVar, "nameplateMaxDistance", tostring(dist))
    pcall(SetCVar, "nameplateMinAlpha", tostring(minAlpha))
    pcall(SetCVar, "nameplateMinAlphaDistance", "10")
    pcall(SetCVar, "nameplateMaxAlpha", tostring(maxAlpha))
    pcall(SetCVar, "nameplateMaxAlphaDistance", tostring(dist))
    pcall(SetCVar, "nameplateSelectedAlpha", tostring(targetAlpha))
    pcall(SetCVar, "nameplateNotSelectedAlpha", tostring(notSelectedAlpha))
    pcall(SetCVar, "nameplateOccludedAlphaMult", tostring(occludedAlpha))
    -- ESCALA GLOBAL (pedido del usuario 2026-07-28: "aumentar o reducir el
    -- tamaño de los nameplates globalmente, sin tocar el Designer"). Son CVars
    -- nativos, misma familia que los de alpha/distancia de arriba, asi que
    -- escalan el nameplate ENTERO -- barra, nombre, auras, todo junto -- sin
    -- tocar ni un offset del perfil. El Designer sigue trabajando en sus propias
    -- unidades y no se entera: esto multiplica por encima.
    --
    -- selectedScale es RELATIVO al tamaño normal (1.2 = el target un 20% mas
    -- grande), que es justo lo que se pidio.
    local globalScale   = (p and p.globalScale) or 1
    local selectedScale = (p and p.selectedScale) or 1
    pcall(SetCVar, "nameplateGlobalScale", tostring(globalScale))
    pcall(SetCVar, "nameplateSelectedScale", tostring(selectedScale))
    -- Min/Max de escala por DISTANCIA: si quedaran en su default, acotarian el
    -- efecto de globalScale (el juego interpola entre estos dos segun lo lejos
    -- que este la unidad). Se mueven junto con la escala global para que subirla
    -- realmente se note a cualquier distancia.
    pcall(SetCVar, "nameplateMinScale", tostring(globalScale))
    pcall(SetCVar, "nameplateMaxScale", tostring(globalScale))
    -- Pedido del usuario 2026-07-19: "que solo se vea el name en NPCs
    -- aliados de dungeon" -- COMPROBADO EN VIVO por el usuario (via /dump
    -- GetCVar despues de probar manualmente) que la combinacion real -- 3
    -- CVars, no 1 solo -- SI afecta incluso a las ForbiddenNamePlate de NPCs
    -- de escolta/mision (CVars son ajustes de motor, no tocan el frame Lua
    -- directamente, por eso alcanzan incluso a un frame "Forbidden"):
    --   nameplateShowFriendlyNPCs=1 + nameplateShowFriendlyPlayers=1
    --   + nameplateShowOnlyNameForFriendlyPlayerUnits=1
    -- SOLO dentro de mazmorra (IsInInstance()=="party"), restaurando el
    -- valor original al salir -- mismo patron ya usado en el resto de esta
    -- funcion para no afectar mundo abierto/raid/ciudad.
    if p and p.showFriendlyNPCPlates ~= false then
        local okI, inInst, instanceType = pcall(IsInInstance)
        local isDungeon = okI and inInst and instanceType == "party"
        local DUNGEON_CVARS = { "nameplateShowFriendlyNPCs", "nameplateShowFriendlyPlayers",
            "nameplateShowOnlyNameForFriendlyPlayerUnits" }
        if isDungeon then
            ns._mcfOrigDungeonCVars = ns._mcfOrigDungeonCVars or {}
            for _, cv in ipairs(DUNGEON_CVARS) do
                if ns._mcfOrigDungeonCVars[cv] == nil then
                    local okG, orig = pcall(GetCVar, cv)
                    ns._mcfOrigDungeonCVars[cv] = (okG and orig) or "0"
                end
                pcall(SetCVar, cv, "1")
            end
        elseif ns._mcfOrigDungeonCVars then
            for _, cv in ipairs(DUNGEON_CVARS) do
                pcall(SetCVar, cv, ns._mcfOrigDungeonCVars[cv])
            end
        end
    end
end

local function ApplyMaxDistance()
    if InCombatLockdown and InCombatLockdown() then
        pendingMaxDistanceApply = true
        return
    end
    ApplyMaxDistanceNow()
end

-- ==========================================================================
-- SKIN de un nameplate individual (se aplica UNA vez por frame; Blizzard
-- reusa los mismos frames de nameplate entre unidades, asi que basta con una
-- bandera para no reprocesar).
-- ==========================================================================
-- El borde/backdrop nativo de Blizzard (region separada, `.border`) queda
-- DETRAS de nuestra textura pero se sigue viendo alrededor porque es mas
-- ancha -- se oculta (no se puede quitar del template, asi que Hide() + un
-- guard por si Blizzard la vuelve a mostrar, mismo patron que MinimapCluster
-- en Minimap.lua).
local function HideNativeBorder(region)
    if not region then return end
    region:Hide()
    if not region._mcfHideHooked then
        region._mcfHideHooked = true
        -- hooksecurefunc en vez de HookScript("OnShow"): esta region suele
        -- ser una Texture, que no soporta ese script (mismo motivo que
        -- LockSize usa hooksecurefunc en vez de OnSizeChanged).
        hooksecurefunc(region, "Show", function(self) self:Hide() end)
        -- Blizzard (CompactUnitFrame_UpdateSelectionHighlight y similares)
        -- suele togglear estas overlays con SetShown(bool), NO con Show() --
        -- un hook solo en "Show" no alcanza a interceptar eso (confirmado en
        -- vivo: seguian apareciendo pese al hook anterior).
        if region.SetShown then
            -- NO inspeccionar `shown`: puede ser un booleano SECRETO (viene
            -- de estado de combate/cast) -- comparar/testear eso crashea
            -- ("boolean test on secret boolean value", confirmado en vivo).
            -- No hace falta mirarlo: la intencion siempre es "quedate oculto"
            -- sin importar que haya pasado Blizzard.
            hooksecurefunc(region, "SetShown", function(self) self:Hide() end)
        end
    end
end

local function SkinHealthBar(uf)
    local hp = uf.healthBar
    if not hp or hp._mcfSkinned then return end
    hp._mcfSkinned = true

    -- Punto/offset desde ns.NPLayout, no escritos a mano: el editor dibuja su
    -- barra con L.Health y esto tiene que ser lo MISMO. Estaban duplicados
    -- ("TOP","TOP",0,-1 aca; L.Health alla) y coincidian de casualidad --
    -- justo el tipo de pareja que se desincroniza al primer cambio.
    local hl0 = ns.NPLayout.Health(P())
    LockBar(hp, uf, hl0.point, hl0.relPoint, hl0.x, hl0.y, GetHealthSize)
    hp:SetStatusBarTexture(BAR_TEX)
    local tex = hp:GetStatusBarTexture()
    if tex then tex:SetTexCoord(unpack(BAR_TEXCOORD)) end
    -- El "borde" nativo visible es `bgTexture` (confirmado via /mcfnpdiag en
    -- vivo -- el campo `border` no existe en este cliente, por eso no se
    -- ocultaba antes).
    HideNativeBorder(hp.bgTexture)
    -- El "bloque negro detras" (confirmado via /mcfnpdiag: deselectedOverlay
    -- shown=true) es el dimming nativo que Blizzard le pone a las plates que
    -- NO son el target -- AzeriteUI tampoco lo usa, se oculta igual.
    HideNativeBorder(hp.deselectedOverlay)
    -- Texto nativo de vida (ej "100%" pegado a la barra, blanco, sin
    -- respetar el menu) -- es el propio de Blizzard (hp.Text/TextString/
    -- LeftText/RightText), NO el nuestro (mcfValue, aparte y anclado
    -- ABAJO). Se oculta para que solo se vea el texto propio configurable.
    HideNativeBorder(hp.Text)
    HideNativeBorder(hp.TextString)
    HideNativeBorder(hp.LeftText)
    HideNativeBorder(hp.RightText)
    -- Pedido del usuario 2026-07-19: "la textura de absorbido esta un poco
    -- sobresaliendo la barra de vida y el highlight" -- los overlays nativos
    -- de shield/prediccion de curacion (totalAbsorb con su franja
    -- diagonal, heal prediction propia/ajena, glow de overabsorb) estan
    -- anclados/dimensionados por Blizzard para el tamaño ORIGINAL de la
    -- barra, no el nuestro (mas chico/distinto) -- se salen del cage. Este
    -- addon no tiene un visual propio para esto, asi que se ocultan.
    HideNativeBorder(uf.myHealPrediction)
    HideNativeBorder(uf.otherHealPrediction)
    HideNativeBorder(uf.myHealAbsorb)
    HideNativeBorder(uf.myHealAbsorbLeftShadow)
    HideNativeBorder(uf.myHealAbsorbRightShadow)
    HideNativeBorder(uf.overHealAbsorbGlow)
    HideNativeBorder(uf.totalAbsorb)
    HideNativeBorder(uf.totalAbsorbOverlay)
    HideNativeBorder(uf.overAbsorbGlow)

    -- Backdrop DETRAS de la barra (pedido de nuevo por el usuario). La 1ra
    -- vez se le aplico el MISMO texcoord recortado que la barra y eso era el
    -- "bloque negro" -- esta textura NO tiene el mismo padding que
    -- nameplate_bar.tga, asi que va SIN recortar (texcoord por defecto).
    if not hp.mcfBackdrop then
        local bg = hp:CreateTexture(nil, "BACKGROUND", nil, -1)
        bg:SetPoint("CENTER")
        local w, h = GetHealthSize()
        bg:SetSize(w, h)
        bg:SetTexture(BACKDROP_TEX)
        hp.mcfBackdrop = bg
    end
end

-- 2026-07-18: dejamos de intentar reskinear la cast bar NATIVA. Analizando
-- Platynator (fork de Plater, ya adaptado a este cliente) se confirma el
-- enfoque correcto para Midnight: la barra de cast nativa viene de un
-- template con icono/candado dificiles de limpiar, y en este cliente
-- conviene CONSTRUIR la barra desde cero, alimentada por UnitCastingInfo/
-- UnitChannelInfo (que a diferencia de la vida NO estan bloqueados/secretos
-- -- son datos necesarios para cualquier addon de interrupts). Se oculta la
-- nativa por completo y se dibuja una barra 100% propia con la MISMA
-- textura/tamaño/backdrop que la de vida.
local function HideNativeCastBar(uf)
    local cb = uf.castBar or uf.CastBar or uf.castbar or uf.Castbar or uf.CastingBarFrame
    if cb then HideNativeBorder(cb) end
end

-- 2026-07-19 (pedido del usuario: "volvamos al metodo de controlar
-- posicion, escala y apariencia de mis auras... separadas como habia dicho
-- antes") -- de vuelta a iconos PROPIOS (3 grupos independientes: Big
-- Debuff / Personal Debuffs / Enemy Buffs), pero esta vez con las DOS APIs
-- que confirmamos funcionando de verdad en este cliente ("secrets"),
-- despues de toda la vuelta con /mcfaurasdiag:
--   1) C_UnitAuras.GetUnitAuras(unit, filter) -- BATCH, no el loop viejo de
--      GetAuraDataByIndex (ese no devolvia NADA para tokens de nameplate).
--   2) C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, id, filterToken) para
--      CLASIFICAR -- NO leer campos crudos como isBossDebuff/isPlayerAura
--      (esos SI pueden ser secretos y crashean en un simple `if`); esta API
--      le pasa el trabajo a Blizzard, que evalua sus propios datos
--      (potencialmente secretos) INTERNAMENTE sin exponernoslos.
-- Se oculta el AurasFrame nativo (HideNativeBorder, mismo patron que
-- cast bar) y se dibujan iconos propios encima.
local function HideNativeAuras(uf)
    if uf.AurasFrame then HideNativeBorder(uf.AurasFrame) end
end

local function CreateCustomCastBar(uf)
    if uf.mcfCast then return uf.mcfCast end
    local cb = CreateFrame("StatusBar", nil, uf)
    cb:Hide()
    cb:SetStatusBarTexture(BAR_TEX)
    local tex = cb:GetStatusBarTexture()
    if tex then tex:SetTexCoord(unpack(BAR_TEXCOORD)) end

    local bg = cb:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetPoint("CENTER")
    local cw, ch = GetCastSize()
    bg:SetSize(cw, ch)
    bg:SetTexture(BACKDROP_TEX)
    cb.bg = bg

    local text = cb:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    text:SetPoint("CENTER")
    text:SetWidth(cw - 6)
    text:SetJustifyH("CENTER")
    cb.text = text

    uf.mcfCast = cb
    return cb
end

local function ReassertCastGeometry(uf)
    local cb = uf.mcfCast
    if not cb then return end
    local p = P()
    -- Colocada por ns.NPBuild.Place, la MISMA funcion que usa el editor.
    ns.NPBuild.Place(cb, uf.healthBar or uf, ns.NPLayout.Cast(p), uf:GetEffectiveScale())
    local cw, ch = GetCastSize()
    cb:SetSize(cw, ch)
    if cb.bg then cb.bg:SetSize(cw, ch) end
    if cb.text then cb.text:SetWidth(cw - 6) end
    local c = (p and p.castColor) or DEFAULT_TEXT_COLOR
    cb:SetStatusBarColor(c.r, c.g, c.b)
    local tsize = (p and p.castTextFontSize) or 10
    local tc = (p and p.castTextColor) or { r = 1, g = 1, b = 1 }
    if cb.text._mcfLastSize ~= tsize then
        cb.text._mcfLastSize = tsize
        cb.text:SetFont("Fonts\\FRIZQT__.TTF", tsize, "OUTLINE")
    end
    cb.text:SetTextColor(tc.r, tc.g, tc.b, (p and p.castTextAlpha) or 1)
    ns.NPBuild.Place(cb.text, cb, ns.NPLayout.CastText(p), cb:GetEffectiveScale())
end

-- Se llama desde el ticker de mas abajo (no por evento): UnitCastingInfo/
-- UnitChannelInfo se pueden pedir en cualquier momento, no hace falta
-- suscribirse a UNIT_SPELLCAST_* por unidad.
-- /mcfnpdiag/[UpdateCastBar] en vivo confirmaron: name/startMS/endMS de
-- UnitCastingInfo/UnitChannelInfo son SECRETOS de verdad en este cliente
-- (secretName=true secretStart=true secretEnd=true) -- nuestro chequeo de
-- seguridad estaba funcionando BIEN al rechazarlos, no era un bug. La
-- aritmetica manual (endMS-startMS) esta prohibida sobre secretos, pero
-- Platynator (ver su Display/CastBar.lua + Display/Cache.lua, rama
-- IsSecretsActive) muestra el camino correcto para este cliente:
--   1) el NOMBRE se puede pasar directo a SetText() aunque sea secreto (fijar
--      texto es una operacion "segura" sobre secretos, a diferencia de leerlo).
--   2) el progreso/duracion se pide con UnitCastingDuration/UnitChannelDuration
--      (funciones NUEVAS de este cliente) que devuelven un objeto Duration
--      seguro, y se lo pasa DIRECTO a StatusBar:SetTimerDuration() -- nunca
--      tocamos un numero de tiempo crudo nosotros mismos.
local function UpdateCastBar(uf, unit, verbose)
    unit = unit or uf.unit
    if not unit then return end
    local cb = uf.mcfCast
    -- No pisar el flash rojo de interrupcion (ver interruptWatch mas abajo) --
    -- sin esto, el proximo tick de 0.2s escondia la barra antes de que se
    -- alcance a ver el flash (el cast ya termino, name vuelve nil de inmediato).
    if cb and cb.mcfFlashTicker then return end
    local ok, err = pcall(function()
        local name, _, _, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
        local isChannel = false
        if not name then
            name, _, _, _, _, _, notInterruptible = UnitChannelInfo(unit)
            isChannel = true
        end
        if verbose then
            print(("  [UpdateCastBar] unit=%s name=%s secretName=%s"):format(
                tostring(unit), tostring(name), tostring(issecretvalue and issecretvalue(name))))
        end
        if not name then
            if cb then cb:Hide() end
            return
        end
        if not cb then cb = CreateCustomCastBar(uf); ReassertCastGeometry(uf) end
        cb.text:SetText(name)

        -- Pedido del usuario: distinguir casts NO interrumpibles (gris, igual
        -- que el nativo de Blizzard) -- notInterruptible puede ser un booleano
        -- SECRETO en este cliente, mismo guard que ya se usa con lvl/creatureType
        -- en otras partes del archivo (type() + issecretvalue() antes de comparar).
        local p0 = P()
        local isSafeNI = type(notInterruptible) == "boolean" and not (issecretvalue and issecretvalue(notInterruptible))
        local color = (isSafeNI and notInterruptible and p0 and p0.castUninterruptibleColor)
            or (p0 and p0.castColor) or DEFAULT_TEXT_COLOR
        if cb._mcfLastNI ~= (isSafeNI and notInterruptible or false) then
            cb._mcfLastNI = isSafeNI and notInterruptible or false
            cb:SetStatusBarColor(color.r, color.g, color.b)
        end

        local duration = isChannel
            and (UnitChannelDuration and UnitChannelDuration(unit))
            or (UnitCastingDuration and UnitCastingDuration(unit))
        if duration and cb.SetTimerDuration then
            local direction = (isChannel and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime)
                or (Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime)
            cb:SetTimerDuration(duration, nil, direction)
        end
        cb:Show()
    end)
    if not ok then
        if cb then cb:Hide() end
        ns._mcfLastCastErr = err
    end
end

-- /mcfnpdiag en vivo confirmo que setear font/color/punto UNA vez no alcanza:
-- Blizzard repinta el nombre (color de clase/reaccion) y lo reancla en cada
-- actualizacion -- y ademas guarda una referencia PROPIA a SetTextColor y la
-- llama directo (hooksecurefunc sobre el METODO del objeto no alcanzaba a
-- interceptar eso). Fix: reafirmar TODO (font/color/punto) leyendo el perfil
-- EN VIVO, colgado tanto de los hooks del objeto como de la funcion global
-- CompactUnitFrame_UpdateName -- asi tambien sirve para que el menu pueda
-- cambiar tamaño/color/posicion en caliente via ns.RefreshNameplateStyle().
-- 2026-07-18: el nameplate SIEMPRE cambia de escala por distancia (SetScale
-- nativo, continuo/suave) -- CUALQUIER FontString DENTRO de esa jerarquia se
-- re-rasteriza a un tamaño fisico fraccionario tarde o temprano. En vez de
-- sacar el texto a UIParent (perdiendo alpha/visibilidad heredados, y
-- necesitando sincronizarlos a mano), el holder queda como HIJO de `uf` pero
-- con su PROPIA escala puesta al INVERSO de la escala efectiva del padre en
-- cada momento -- asi su escala efectiva final siempre da 1 (texto nunca
-- distorsionado), sin salir de la jerarquia: sigue heredando alpha/mostrar-
-- ocultar del nameplate automaticamente, gratis.
local function CreateNameHolder(uf)
    if uf.mcfNameHolder then return uf.mcfNameHolder end
    local holder = CreateFrame("Frame", nil, uf)
    holder:SetSize(ns.NPBuild.NAME_HOLDER_W, ns.NPBuild.NAME_HOLDER_H)
    local fs = holder:CreateFontString(nil, "OVERLAY")
    fs:SetPoint("CENTER")
    fs:SetJustifyH("CENTER")
    holder.text = fs
    uf.mcfNameHolder = holder
    return holder
end

local function ReassertNameGeometry(uf)
    local holder = uf.mcfNameHolder
    if not holder then return end
    local p = P()
    local size = (p and p.nameFontSize) or 16
    local c = (p and p.nameColor) or DEFAULT_TEXT_COLOR
    -- Pedido del usuario 2026-07-19: en modo "solo nombre" (ahora exclusivo
    -- de jugadores amistosos), el nombre usa el color de CLASE del jugador
    -- en vez del color configurado -- no afecta el modo normal.
    if uf.mcfNameOnlyMode then
        local classColor = GetClassColorForUnit(uf.unit)
        if classColor then c = classColor end
    else
        -- 2026-08-03 ("los player enemigos ahora mismo tienen el color de
        -- clase... hace que sea confuso en arena, quita la opcion"): ya NO
        -- es opcional -- un jugador HOSTIL real siempre sale en rojo plano,
        -- sin color de clase de por medio. UnitIsPlayer primero (evita el
        -- intento en el 99% de las plates, que son creaturas), UnitIsFriend
        -- para no recolorear jugadores amistosos por error.
        local okP, isPlayer = pcall(UnitIsPlayer, uf.unit)
        if okP and isPlayer then
            local okF, isFriend = pcall(UnitIsFriend, "player", uf.unit)
            if okF and not isFriend then c = HOSTILE_PLAYER_COLOR end
        end
    end
    local fs = holder.text
    -- Solo re-rasterizar si el tamaño realmente cambio (barato, evita
    -- SetFont redundante -- con la escala efectiva siempre en 1, el
    -- rasterizado ahora es al mismo tamaño fisico real SIEMPRE).
    if fs._mcfLastSize ~= size then
        fs._mcfLastSize = size
        fs:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
    end
    -- PERF (2026-07-19, pedido del usuario "que afecte lo minimo posible al
    -- rendimiento"): mismo criterio que el SetFont de arriba -- esto corre
    -- SIN throttle (nameScaleDriver, todos los frames, por CADA nameplate
    -- visible) y el color casi nunca cambia entre un frame y el siguiente.
    -- Cachear y saltear el SetTextColor cuando no cambio es identico en
    -- efecto (mismo color final aplicado), solo evita la llamada redundante.
    local na = (p and p.nameAlpha) or 1
    if fs._mcfLastR ~= c.r or fs._mcfLastG ~= c.g or fs._mcfLastB ~= c.b or fs._mcfLastA ~= na then
        fs._mcfLastR, fs._mcfLastG, fs._mcfLastB, fs._mcfLastA = c.r, c.g, c.b, na
        fs:SetTextColor(c.r, c.g, c.b, na)
    end

    -- Contra-escala: con holder:GetScale() = 1/uf:GetEffectiveScale(), la
    -- escala EFECTIVA de holder (su propia escala * la de su padre) siempre
    -- da 1 -- los offsets de SetPoint de aca en mas quedan en pixeles de
    -- pantalla reales, sin importar cuanto haya achicado Blizzard la plate.
    -- BUG (reportado por el usuario, 2026-07-19): "letra enorme por unos
    -- milisegundos" al aparecer una nameplate nueva -- Blizzard anima la
    -- ESCALA de la plate de 0 a su valor final al aparecer; si esto corre
    -- justo en ese instante, effScale puede estar casi en 0, y 1/effScale
    -- se dispara a un numero gigante por ese frame. Clamp a un rango
    -- razonable (mismo 0.3-3 que usa el resto del addon para escalas de
    -- nameplate) evita el flash sin afectar el resultado final una vez que
    -- la animacion termina.
    -- PERF (2026-07-19, pedido del usuario "limpia eso"): esto corre TODOS
    -- los frames (nameScaleDriver, sin throttle) para cada plate visible --
    -- fuera de la ventana de animacion de escala de Blizzard, effScale/offsets
    -- casi siempre son los mismos que el frame anterior. Evita el
    -- SetScale/ClearAllPoints/SetPoint (relayout) cuando nada cambio.
    local effScale = uf:GetEffectiveScale()
    local offX, offY
    if uf.mcfNameOnlyMode then
        offX, offY = (p and p.nameOnlyOffsetX) or 0, (p and p.nameOnlyOffsetY) or 0
    else
        offX, offY = (p and p.nameOffsetX) or 0, (p and p.nameOffsetY) or 0
    end
    -- El dedupe YA NO mira effScale (2026-07-28). Con el nombre en regimen
    -- "plate", su posicion no depende de la escala: el offset va crudo y lo
    -- escala el propio nameplate. Seguir comparando effScale hacia que este
    -- bloque reubicara el nombre en CADA frame mientras te movias (la escala
    -- cambia continuamente con la distancia) para dejarlo exactamente donde ya
    -- estaba. Ahora solo corre cuando cambian los offsets de verdad.
    if holder._mcfLastOffX == offX and holder._mcfLastOffY == offY then
        return
    end
    holder._mcfLastOffX, holder._mcfLastOffY = offX, offY
    -- (La escala y el ClearAllPoints los hace ns.NPBuild.Place segun el regimen.
    -- Aca habia un SetScale(1/effScale) suelto: quedo muerto cuando el nombre
    -- paso al regimen "plate", y Place lo pisaba igual.)
    -- Offset SEPARADO en modo "solo nombre" (uf.mcfNameOnlyMode, seteado por
    -- el ticker segun ShouldHideExceptName) -- pedido del usuario 2026-07-19:
    -- sin la barra visible, la posicion normal del nombre puede no quedar
    -- bien, asi que se puede ajustar aparte sin afectar el modo normal.
    --
    -- La colocacion sale ENTERA de ns.NPLayout: misma fuente y misma funcion que
    -- usa el Designer. El modo solo-nombre lo resuelve L.Name por su 2do
    -- argumento -- aca se inyectaban los offsets pisando nl.x/nl.y, y esa
    -- formula (`16 + offY`) sobrevivio a que la posicion nativa se mudara a la
    -- tabla BASE: el nombre volvia a +16 en vez de quedarse donde estaba
    -- horneado. `offX/offY` de arriba siguen usandose, pero SOLO para el dedupe.
    ns.NPBuild.Place(holder, uf, ns.NPLayout.Name(p, uf.mcfNameOnlyMode), effScale)
end

-- El nombre de la unidad NO es secreto (es informacion basica de UI, igual
-- que el nombre de un hechizo) -- UnitName funciona normal. Al ser `holder`
-- hijo de `uf` (ver ReassertNameGeometry), hereda alpha/mostrar-ocultar del
-- nameplate automaticamente -- no hace falta sincronizar nada de eso a mano.
local function UpdateNameText(uf, unit)
    local holder = uf.mcfNameHolder
    if not holder or not unit then return end
    local ok, nm = pcall(UnitName, unit)
    if ok and nm then holder.text:SetText(nm) end
end

local function SkinName(uf)
    local name = uf.name
    if not name or name._mcfSkinned then return end
    name._mcfSkinned = true
    HideNativeBorder(name)
    CreateNameHolder(uf)
    ReassertNameGeometry(uf)
end

-- Texto de vida ABAJO del nameplate (ej "66%" -- ver el ticker mas abajo por
-- que es porcentaje y no un numero absoluto). Es un FontString propio (no de
-- Blizzard), asi que no hace falta reafirmar contra el -- solo releer el
-- perfil cada vez que se llama Reassert (al crearse, o desde el menu via
-- ns.RefreshNameplateStyle()).
local function SkinHealthValue(uf)
    local hp = uf.healthBar
    if not hp or hp.mcfValue then return end
    local fs = hp:CreateFontString(nil, "OVERLAY")
    local function Reassert()
        local p = P()
        local size = (p and p.healthValueFontSize) or 12
        local c = (p and p.healthValueColor) or DEFAULT_TEXT_COLOR
        -- Mismo guard que SkinName: solo re-rasterizar si el tamaño cambio.
        if fs._mcfLastSize ~= size then
            fs._mcfLastSize = size
            fs:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
        end
        fs:SetTextColor(c.r, c.g, c.b, (p and p.healthValueAlpha) or 1)
        ns.NPBuild.Place(fs, hp, ns.NPLayout.HealthValue(p), hp:GetEffectiveScale())
    end
    Reassert()
    fs._mcfReassert = Reassert
    hp.mcfValue = fs
end

-- Pedido del usuario (2026-07-19): "usa los iconos del AzeriteUI" -- Blizzard
-- decide la clasificacion (boss/elite/rare/rareelite) via un ATLAS propio
-- que no podemos re-texturar, asi que en vez de reskinear el
-- classificationIndicator NATIVO se oculta y se dibuja uno 100% propio,
-- alimentado por UnitClassification(unit) (dato basico de UI, no secreto),
-- con las MISMAS texturas que usa AzeriteUI para esto (copiadas a
-- Assets/icon_classification_*.tga -- mismo patron que la barra de vida,
-- "copiados de AzeriteUI5_JuNNeZ_Edition/Assets"). Anclaje/tamaño default
-- (RIGHT, 20, -1, 40x40) calcado de Layouts/Data/NamePlates.lua de AzeriteUI.
local CLASS_TEX = {
    worldboss = A .. "icon_classification_boss.tga",
    boss      = A .. "icon_classification_boss.tga",
    elite     = A .. "icon_classification_elite.tga",
    rareelite = A .. "icon_classification_rare.tga",
    rare      = A .. "icon_classification_rare.tga",
}

-- Pedido del usuario 2026-07-19: "deberian estar encima de todo" -- una
-- textura simple sobre hp queda al nivel/strata de hp, que puede terminar
-- DETRAS de otros hijos (barra de cast, iconos de aura) segun orden de
-- creacion. Frame PROPIO con strata elevada (igual que RaidTargetFrame mas
-- abajo) garantiza que siempre dibuje encima, sin importar que mas haya.
local function CreateCustomClassification(uf)
    if uf.mcfClass then return uf.mcfClass end
    local holder = CreateFrame("Frame", nil, uf)
    holder:SetFrameStrata("TOOLTIP")
    holder:SetFrameLevel(200)
    local tex = holder:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    holder.tex = tex
    holder:Hide()
    uf.mcfClass = holder
    return holder
end

local function ReassertClassification(uf)
    local holder = uf.mcfClass
    if not holder then return end
    local p = P()
    local sz = (p and p.classificationSize) or 40
    holder:SetSize(sz, sz)
    ns.NPBuild.Place(holder, uf.healthBar or uf, ns.NPLayout.Classification(p), uf:GetEffectiveScale())
end

local function UpdateClassification(uf, unit)
    unit = unit or uf.unit
    if not unit then return end
    local holder = uf.mcfClass or CreateCustomClassification(uf)
    if not uf.mcfClassGeoSet then ReassertClassification(uf); uf.mcfClassGeoSet = true end
    local ok, c = pcall(UnitClassification, unit)
    -- Mismo override que AzeriteUI: nivel < 1 fuerza "worldboss" (algunos
    -- world bosses no vienen marcados "worldboss" directo por Blizzard).
    -- BUG (reportado por el usuario 2026-07-19, "el icono elite se muestra
    -- en entidades que no lo son" -- Training Dummy con el icono de boss):
    -- los Training Dummy TAMBIEN devuelven UnitLevel() == -1 (el mismo truco
    -- que usan los jefes de mundo para "nivel siempre mas alto que el tuyo"),
    -- asi que el heuristico de arriba les pegaba por error. Blizzard los
    -- clasifica internamente con creatureType "Totem" (quirk conocido/estable
    -- de los dummies) -- se excluyen antes de aplicar el override.
    local okL, lvl = pcall(UnitLevel, unit)
    local okCT, creatureType = pcall(UnitCreatureType, unit)
    local isDummy = okCT and type(creatureType) == "string" and not (issecretvalue and issecretvalue(creatureType))
        and creatureType == "Totem"
    if not isDummy and okL and type(lvl) == "number" and not (issecretvalue and issecretvalue(lvl)) and lvl < 1 then
        c = "worldboss"
    end
    local path = ok and c and CLASS_TEX[c]
    if path then
        holder.tex:SetTexture(path)
        holder:Show()
    else
        holder:Hide()
    end
end

local function ReassertRaidMark(uf)
    local rt = uf.RaidTargetFrame
    if not rt then return end
    local p = P()
    local sz = (p and p.raidMarkSize) or 64
    rt:SetSize(sz, sz)
    ns.NPBuild.Place(rt, uf.healthBar or uf, ns.NPLayout.RaidMark(p), uf:GetEffectiveScale())
end
local function LockRaidMark(uf)
    local rt = uf.RaidTargetFrame
    if not rt or rt._mcfAuraLocked then return end
    rt._mcfAuraLocked = true
    -- Pedido del usuario 2026-07-19: "deberian estar encima de todo" -- es
    -- un frame NATIVO de Blizzard (no una textura nuestra), asi que se puede
    -- subir strata/nivel directo, igual que el holder de clasificacion.
    rt:SetFrameStrata("TOOLTIP")
    rt:SetFrameLevel(200)
    local locking = false
    local function Reassert()
        if locking then return end
        locking = true
        ReassertRaidMark(uf)
        locking = false
    end
    hooksecurefunc(rt, "SetPoint", Reassert)
    hooksecurefunc(rt, "SetSize", Reassert)
    hooksecurefunc(rt, "SetFrameStrata", function(self)
        if self:GetFrameStrata() ~= "TOOLTIP" then self:SetFrameStrata("TOOLTIP") end
    end)
    Reassert()
end

local function SkinHighlight(uf)
    local hl = uf.selectionHighlight
    if not hl or hl._mcfSkinned then return end
    hl._mcfSkinned = true
    hl:SetTexture(OUTLINE_TEX)
    -- Color FIJO (configurable en el menu, "dorado opaco" por defecto) en vez
    -- de que Blizzard lo pinte distinto segun focus/target/soft-target -- se
    -- fuerza SIEMPRE al mismo tono (leido del perfil EN VIVO), reafirmado
    -- cada vez que Blizzard le vuelve a poner SU color
    -- (CompactUnitFrame_UpdateSelectionHighlight).
    local colorLocking = false
    local function ReassertColor()
        if colorLocking then return end
        colorLocking = true
        local c = (P() and P().highlightColor) or DEFAULT_HIGHLIGHT_COLOR
        hl:SetVertexColor(c.r, c.g, c.b)
        colorLocking = false
    end
    ReassertColor()
    hl._mcfReassertColor = ReassertColor
    hooksecurefunc(hl, "SetVertexColor", ReassertColor)
    -- `healthBar.selectedBorder` es un marco BLANCO nativo separado que
    -- Blizzard sigue dibujando al seleccionar (visto en vivo: el rectangulo
    -- blanco que quedaba encima de nuestro highlight ya reskineado).
    HideNativeBorder(uf.healthBar and uf.healthBar.selectedBorder)
    -- Blizzard lo ancla/dimensiona en base al tamaño NATIVO de healthBar (mas
    -- grande que el nuestro) -- sin reanclarlo a nuestra barra ya achicada
    -- queda corrido/desalineado. Se recentra sobre healthBar con el tamaño
    -- fijo que usa AzeriteUI para este mismo marco.
    LockSize(hl, GetHighlightSize)
    local hp = uf.healthBar
    if not hp then return end
    local reasserting = false
    local function Reanchor()
        if reasserting then return end
        reasserting = true
        hl:ClearAllPoints()
        hl:SetPoint("CENTER", hp, "CENTER", 0, 0)
        reasserting = false
    end
    -- Blizzard reancla esto solo cada vez que cambia el estado de seleccion
    -- (CompactUnitFrame_UpdateSelectionHighlight) usando el tamaño NATIVO de
    -- healthBar -- sin reafirmar aca quedaba corrido apenas cambiaba target.
    Reanchor()
    hooksecurefunc(hl, "SetPoint", Reanchor)
end

-- QUITADO (2026-07-27, pedido del usuario: "no parece esta funcionando, mejor quita
-- eso"): un indicador de amenaza/agro paso por 4 versiones el mismo dia (glow nativo
-- escalado, tinte copiando el color del glow, lectura directa de
-- UnitDetailedThreatSituation vía OnUpdate, y por ultimo un hook sobre
-- SetStatusBarColor con hooksecurefunc para ganarle la carrera al color nativo) -- la
-- ultima version deberia haber funcionado en teoria (mismo patron ya probado que usan
-- LockSize/LockBar en este archivo), pero el usuario reporto que seguia sin notarse
-- ningun cambio. Se saco todo -- SkinThreat (el reskin de textura original,
-- PRE-EXISTENTE de antes de esta sesion) se queda igual que siempre, sin nada
-- adicional encima. Si se retoma mas adelante, el historial de git tiene las 4
-- versiones intentadas como referencia de que NO funciono.
local function SkinThreat(uf)
    local th = uf.aggroHighlight
    if th and not th._mcfSkinned then
        th._mcfSkinned = true
        th:SetTexture(GLOW_TEX)
    end
end

-- ==========================================================================
-- AURAS (2026-07-19, REESCRITO DE NUEVO): 3 grupos (Big Debuff / Personal
-- Debuffs / Enemy Buffs).
--
-- INTENTO 1 (revertido): C_UnitAuras.IsAuraFilteredOutByInstanceID con
-- filtros "PLAYER" -- descartado porque PLAYER es solo un ESTRECHAMIENTO del
-- mismo filtro base ("personal" siempre subconjunto de "big"), nunca dos
-- poblaciones independientes -- Harpoon (tuyo) siempre caia en "personal"
-- aunque Blizzard lo muestre como "Big".
-- INTENTO 2 (revertido): widget "AuraContainer" (CreateFrame("AuraContainer",
-- ..., "CustomAuraContainerTemplate")) -- confirmado en vivo (/mcfaurasdiag,
-- unsupported=true en los 3 grupos) que ESE WIDGET NO EXISTE en este build
-- (Interface 120007) -- es exclusivo de un build de Midnight mas nuevo
-- (Platynator lo gatea con IsMidnightNext = GetBuildInfo() >= 120100).
--
-- SOLUCION REAL para este build (confirmada leyendo Platynator,
-- Display/Auras/ManagerPrev.lua + Display/Initialize.lua:84-102,517-537,
-- la rama que Platynator SI usa en 120007): Blizzard NO expone "importante"
-- via ningun filtro string en este build -- pero el AurasFrame NATIVO del
-- nameplate (uf.AurasFrame, el que ocultamos con HideNativeBorder) SIGUE
-- corriendo su propio RefreshAuras internamente (Hide() no lo desactiva).
-- Ese metodo nativo YA CALCULA cuales auras son "importantes" (boss/big) y
-- las guarda en uf.AurasFrame.buffList/debuffList (listas iterables). Nos
-- enganchamos a RefreshAuras con hooksecurefunc (no toca nada, solo LEE el
-- resultado que Blizzard ya calculo) y usamos esas listas como la señal de
-- "importante" que nosotros no podemos calcular -- exactamente lo que hace
-- Platynator en este mismo build.
-- ==========================================================================
-- Constantes de auras COMPARTIDAS con el Nameplate Designer (2026-07-27): se
-- toman de ns.NPLayout en vez de tener una copia aca y otra alla. Tenerlas
-- duplicadas fue una de las causas de que el panel no coincidiera con el juego.
local AURA_MAX_PER_CAT = ns.NPLayout.AURA_MAX_PER_CAT
local AURA_GROUP_OFFSET_KEYS = ns.NPLayout.AURA_GROUP_OFFSET_KEYS
local AURA_GROUP_DIRECTION_KEYS = ns.NPLayout.AURA_GROUP_DIRECTION_KEYS
-- (AURA_ANCHOR_POINT ya no se aliasea aca: el punto de anclaje lo resuelve
-- ns.NPLayout.AuraGroup y viene dentro de la tabla que devuelve.)

local AURA_GROUPS = { "big", "personal", "enemy" }
local AURA_GROUP_SHOW_KEYS = {
    big = "auraShowBigDebuff", personal = "auraShowPersonalDebuffs", enemy = "auraShowEnemyBuffs",
}
local AURA_SLOT_ORDER = {
    right  = { 1, 2, 3 },
    left   = { 3, 2, 1 },
    center = { 2, 1, 3 },
}

local function GetAuraPadding() return ns.NPLayout.AuraPadding(P()) end

-- Engancha uf.AurasFrame.RefreshAuras UNA VEZ por frame (guard con
-- _mcfImportantHooked) -- vuelca buffList/debuffList (ya calculados por
-- Blizzard) a uf.mcfKnownImportant[auraInstanceID] = true. hooksecurefunc
-- sobre un metodo NATIVO leido despues (nunca escrito) no tainta nada --
-- mismo principio que el resto de HideNativeBorder en este archivo.
local function HookAurasImportance(uf)
    local af = uf.AurasFrame
    if not af or af._mcfImportantHooked then return end
    if not (af.buffList and af.buffList.Iterate and af.debuffList and af.debuffList.Iterate) then return end
    af._mcfImportantHooked = true
    uf.mcfKnownImportant = uf.mcfKnownImportant or {}
    local function Refresh()
        local known = uf.mcfKnownImportant
        for k in pairs(known) do known[k] = nil end
        pcall(af.buffList.Iterate, af.buffList, function(id) known[id] = true end)
        pcall(af.debuffList.Iterate, af.debuffList, function(id) known[id] = true end)
    end
    hooksecurefunc(af, "RefreshAuras", Refresh)
    Refresh()
end

-- CORREGIDO (2026-07-19, "Freezing Trap/Harpoon salen en Personal, deberian
-- ser Big; Wildfire Bomb al reves"): el intento anterior (buffList/debuffList
-- del AurasFrame nativo como señal de "importante") no distinguia el patron
-- real -- Freezing Trap/Harpoon son CROWD CONTROL (raiz/incapacitar/etc),
-- que Blizzard SIEMPRE muestra como Big sin importar quien lo aplico; un DoT
-- tuyo (Wildfire Bomb) no es CC y va en Personal aunque tambien sea tuyo. A
-- diferencia de "IMPORTANT" (removido de la API), el filtro "CROWD_CONTROL"
-- SI sigue disponible -- es la señal real, confiable, no secreta.
-- Orden de prioridad: CC (cualquier origen) -> Big. Tuyo, no-CC -> Personal.
-- Ni tuyo ni CC pero Blizzard igual lo marco importante (buffList/debuffList
-- nativos, ver HookAurasImportance) -> Big (catch-all, boss mechanics
-- ajenos). Resto -> no se muestra.
local function ClassifyAura(data, isHarmful, unit, uf)
    if not (data.auraInstanceID and unit and C_UnitAuras and C_UnitAuras.IsAuraFilteredOutByInstanceID) then
        return nil
    end
    local id = data.auraInstanceID
    local function passes(filterToken)
        local ok, filteredOut = pcall(C_UnitAuras.IsAuraFilteredOutByInstanceID, unit, id, filterToken)
        return ok and filteredOut == false
    end
    local ok, group = pcall(function()
        if isHarmful then
            if not passes("HARMFUL|INCLUDE_NAME_PLATE_ONLY") then return nil end
            if passes("HARMFUL|INCLUDE_NAME_PLATE_ONLY|CROWD_CONTROL") then return "big" end
            if passes("HARMFUL|INCLUDE_NAME_PLATE_ONLY|PLAYER") then return "personal" end
            if uf.mcfKnownImportant and uf.mcfKnownImportant[id] then return "big" end
            return nil
        end
        if passes("HELPFUL|INCLUDE_NAME_PLATE_ONLY") then return "enemy" end
        return nil
    end)
    if not ok then return nil end
    local p = P()
    if group and p and p[AURA_GROUP_SHOW_KEYS[group]] == false then return nil end
    return group
end

-- Construccion y geometria de auras: DELEGADAS a ns.NPBuild (2026-07-28), que
-- es el mismo codigo que usa el Nameplate Designer para su preview. Antes cada
-- lado tenia su copia de la formula (aca ResizeAuraIcon/ResizeAuraHolder, alla
-- LayoutAuraGroupIconsMock con el 3 y el 0.26 escritos a mano) y se
-- desincronizaban sin aviso -- ver la cabecera de NameplateBuild.lua.
local function CreateAuraGroup(uf, groupKey)
    uf.mcfAuraGroups = uf.mcfAuraGroups or {}
    if uf.mcfAuraGroups[groupKey] then return uf.mcfAuraGroups[groupKey] end
    local p = P()
    local holder = ns.NPBuild.AuraGroup(uf, p, false)
    holder._mcfLastPadding = ns.NPLayout.AuraPadding(p)
    uf.mcfAuraGroups[groupKey] = holder
    return holder
end

local function ReassertAuraGroupGeometry(uf, groupKey)
    local holder = uf.mcfAuraGroups and uf.mcfAuraGroups[groupKey]
    if not holder then return end
    local effScale = uf:GetEffectiveScale()
    -- TODO el emplazamiento sale de ns.NPLayout, incluidos los offsets. Antes se
    -- recalculaban aca y del layout solo se tomaba el punto relativo -- o sea
    -- que seguian existiendo dos cuentas, que es exactamente lo que ese archivo
    -- existe para impedir. El dedupe compara los valores YA resueltos, y NO la
    -- escala: igual que el nombre, los grupos pasaron a regimen "plate", asi que
    -- su posicion no depende de effScale y compararla solo provocaba un relayout
    -- por frame mientras te movias, para dejar todo donde ya estaba.
    local al = ns.NPLayout.AuraGroup(P(), groupKey)
    if not al then return end
    if holder._mcfLastAnchor == al.point
        and holder._mcfLastOffX == al.x and holder._mcfLastOffY == al.y then
        return
    end
    holder._mcfLastAnchor = al.point
    holder._mcfLastOffX, holder._mcfLastOffY = al.x, al.y
    -- Ancla al NAMEPLATE, no al nombre (ver la nota larga en L.AuraGroup). Se
    -- acabo la cadena `uf.mcfNameHolder or uf.name or uf`: esa podia dejar el
    -- grupo colgado de la FontString de Blizzard de forma permanente, porque el
    -- dedupe de arriba nunca comparo el frame de ancla.
    -- La escala tambien la pone B.Place segun el regimen -- ya no se fija aca.
    ns.NPBuild.Place(holder, uf, al, effScale)
end
-- Reaplica offset/tamaño de fuente/color de los textos de cargas Y tiempo
-- restante de TODOS los iconos de un grupo -- SEPARADO de
-- ReassertAuraGroupGeometry (que solo reaplica cuando cambia la POSICION del
-- holder) porque el usuario puede cambiar solo el tamaño de fuente del
-- numero sin mover nada, y eso no debe quedar bloqueado por ese dedupe.
local function ReassertAuraTextStyle(uf, groupKey)
    local holder = uf.mcfAuraGroups and uf.mcfAuraGroups[groupKey]
    if not holder or not holder.icons then return end
    local p = P()
    local ccx, ccy = (p and p.auraCountOffsetX) or 2, (p and p.auraCountOffsetY) or 2
    local cSize = (p and p.auraCountFontSize) or 11
    local cc = (p and p.auraCountColor) or { r = 1, g = 1, b = 1 }
    -- El texto de tiempo NO tiene offset propio (lo dibuja el widget Cooldown
    -- nativamente, centrado) -- solo tamaño/color, via el font object
    -- compartido MCFAuraTimeFontObj (ver arriba del archivo).
    local tSize = (p and p.auraTimeFontSize) or 10
    local tc = (p and p.auraTimeColor) or { r = 1, g = 1, b = 1 }
    if MCFAuraTimeFontObj._mcfLastSize ~= tSize then
        MCFAuraTimeFontObj._mcfLastSize = tSize
        MCFAuraTimeFontObj:SetFont("Fonts\\FRIZQT__.TTF", tSize, "OUTLINE")
    end
    MCFAuraTimeFontObj:SetTextColor(tc.r, tc.g, tc.b, 1)
    if holder._mcfLastCcx == ccx and holder._mcfLastCcy == ccy and holder._mcfLastCSize == cSize then
        return
    end
    holder._mcfLastCcx, holder._mcfLastCcy, holder._mcfLastCSize = ccx, ccy, cSize
    for _, b in ipairs(holder.icons) do
        if b.count then
            if b.count._mcfLastSize ~= cSize then
                b.count._mcfLastSize = cSize
                b.count:SetFont("Fonts\\FRIZQT__.TTF", cSize, "OUTLINE")
            end
            b.count:ClearAllPoints()
            b.count:SetPoint("TOPRIGHT", ccx, ccy)
            b.count:SetTextColor(cc.r, cc.g, cc.b, 1)
        end
    end
end
local function ReassertAurasGeometry(uf)
    for _, g in ipairs(AURA_GROUPS) do
        ReassertAuraGroupGeometry(uf, g)
        ReassertAuraTextStyle(uf, g)
    end
end

local auraShown = { big = 0, personal = 0, enemy = 0 }
local auraUsedSlots = { big = {}, personal = {}, enemy = {} }
local function AuraShowOne(uf, unit, p0, data, isHarmful)
    if not data then return end
    local group = ClassifyAura(data, isHarmful, unit, uf)
    if not group or auraShown[group] >= AURA_MAX_PER_CAT then return end
    auraShown[group] = auraShown[group] + 1
    local dir = (p0 and p0[AURA_GROUP_DIRECTION_KEYS[group]]) or "right"
    local slot = (AURA_SLOT_ORDER[dir] or AURA_SLOT_ORDER.right)[auraShown[group]]
    auraUsedSlots[group][slot] = true
    local b = uf.mcfAuraGroups[group].icons[slot]
    b.icon:SetTexture(data.icon)
    -- Swipe + numero de cuenta regresiva: SECRET-SAFE via duration object
    -- (data.expirationTime/data.duration crudos son secretos -- SetCooldown
    -- directo con ellos tira error y cae siempre al Clear()). El numero lo
    -- dibuja el widget internamente (ver SetCountdownFont en CreateAuraIcon),
    -- no hace falta (ni se puede) leerlo desde Lua.
    local okCD = false
    if data.auraInstanceID and C_UnitAuras.GetAuraDuration and b.cd.SetCooldownFromDurationObject then
        local ok, durObj = pcall(C_UnitAuras.GetAuraDuration, unit, data.auraInstanceID)
        if ok and durObj then
            okCD = pcall(b.cd.SetCooldownFromDurationObject, b.cd, durObj)
        end
    end
    if not okCD then pcall(b.cd.Clear, b.cd) end
    local okCount = pcall(function()
        b.count:SetText((data.applications and data.applications > 1) and data.applications or "")
    end)
    if not okCount then b.count:SetText("") end
    local cc = (p0 and p0.auraCountColor) or { r = 1, g = 1, b = 1 }
    b.count:SetTextColor(cc.r, cc.g, cc.b, 1)
    pcall(b.cd.SetSwipeColor, b.cd, cc.r, cc.g, cc.b, 0.7)
    b:Show()
end

local function AuraShowFilter(uf, unit, p0, filter, isHarmful)
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, filter)
    if not ok or type(list) ~= "table" then return end
    for _, data in ipairs(list) do
        AuraShowOne(uf, unit, p0, data, isHarmful)
        if auraShown.big + auraShown.personal + auraShown.enemy >= AURA_MAX_PER_CAT * 3 then break end
    end
end

local function UpdateAuras(uf, unit)
    unit = unit or uf.unit
    if not unit then return end
    if not UnitIsUnit(unit, "target") then
        if uf.mcfAuraGroups then
            for _, g in ipairs(AURA_GROUPS) do uf.mcfAuraGroups[g]:Hide() end
        end
        return
    end
    HookAurasImportance(uf)
    if not uf.mcfAuraGroups then for _, g in ipairs(AURA_GROUPS) do CreateAuraGroup(uf, g) end end
    if not uf.mcfAurasGeoSet then ReassertAurasGeometry(uf); uf.mcfAurasGeoSet = true end

    local sz, padding = GetAuraIconSize(), GetAuraPadding()
    local p0 = P()
    auraShown.big, auraShown.personal, auraShown.enemy = 0, 0, 0
    for slot in pairs(auraUsedSlots.big) do auraUsedSlots.big[slot] = nil end
    for slot in pairs(auraUsedSlots.personal) do auraUsedSlots.personal[slot] = nil end
    for slot in pairs(auraUsedSlots.enemy) do auraUsedSlots.enemy[slot] = nil end
    for _, g in ipairs(AURA_GROUPS) do
        local holder = uf.mcfAuraGroups[g]
        if holder._mcfLastIconSize ~= sz or holder._mcfLastPadding ~= padding then
            holder._mcfLastIconSize = sz
            holder._mcfLastPadding = padding
            ns.NPBuild.LayoutAuraGroup(holder, p0)
        end
    end

    AuraShowFilter(uf, unit, p0, "HARMFUL", true)
    AuraShowFilter(uf, unit, p0, "HELPFUL", false)
    for _, g in ipairs(AURA_GROUPS) do
        local holder = uf.mcfAuraGroups[g]
        for slot = 1, AURA_MAX_PER_CAT do
            if not auraUsedSlots[g][slot] then holder.icons[slot]:Hide() end
        end
        holder:SetShown(auraShown[g] > 0)
    end
end

-- Diagnostico 2026-07-18 (pedido del usuario: "no se ven mis debuffs y
-- buffs"): recorre las auras de tu TARGET una por una y muestra a que grupo
-- clasifica cada una (o por que se descarta), asi se ve de una si el
-- problema es el filtro (ninguna aura clasifica), un toggle apagado, o algo
-- mas (holder nunca creado, etc).
SLASH_MCFAURASDIAG1 = "/mcfaurasdiag"
SlashCmdList["MCFAURASDIAG"] = function()
    local unit = "target"
    if not UnitExists(unit) then
        print("|cff00ff00[MCF auras diag]|r No target selected.")
        return
    end
    local p = P()
    print(("|cff00ff00[MCF auras diag]|r target=%s  showBig=%s showPersonal=%s showEnemy=%s  auraIconSize=%s"):format(
        UnitName(unit) or "?", tostring(p and p.auraShowBigDebuff), tostring(p and p.auraShowPersonalDebuffs),
        tostring(p and p.auraShowEnemyBuffs), tostring(p and p.auraIconSize)))
    -- Offsets guardados de los 3 grupos -- para chequear si de verdad estan
    -- separados en el perfil (pedido 2026-07-19, "las 3 auras salen juntas").
    for _, g in ipairs(AURA_GROUPS) do
        local xKey, yKey = AURA_GROUP_OFFSET_KEYS[g][1], AURA_GROUP_OFFSET_KEYS[g][2]
        print(("  offset[%s]: x=%s y=%s"):format(g, tostring(p and p[xKey]), tostring(p and p[yKey])))
    end
    print(("  healthValueOffsetX=%s healthValueOffsetY=%s"):format(
        tostring(p and p.healthValueOffsetX), tostring(p and p.healthValueOffsetY)))

    -- Campos crudos del AuraData -- pedido del usuario 2026-07-19 ("Harpoon
    -- sale Big en Blizzard, Personal en el nuestro"): PLAYER es solo un
    -- ESTRECHAMIENTO del mismo filtro base (todo lo "personal" TAMBIEN pasa
    -- "big" por definicion, son subconjunto/superconjunto, no dos
    -- poblaciones distintas) -- necesitamos una señal de "importante"
    -- INDEPENDIENTE de quien la aplico para clasificar bien. Vuelca los
    -- flags candidatos (con guard de secretos) para elegir cual usar.
    local function safeField(data, key)
        local ok, v = pcall(function() return data[key] end)
        if not ok then return "ERR" end
        if v == nil then return "nil" end
        if issecretvalue and issecretvalue(v) then return "SECRET" end
        return tostring(v)
    end
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
    local uf = plate and (plate.UnitFrame or plate)
    print("  uf.AurasFrame.buffList/debuffList disponibles=" ..
        tostring(uf and uf.AurasFrame and uf.AurasFrame.buffList and uf.AurasFrame.buffList.Iterate ~= nil))
    print("  uf._mcfImportantHooked=" .. tostring(uf and uf.AurasFrame and uf.AurasFrame._mcfImportantHooked))
    local knownCount = 0
    if uf and uf.mcfKnownImportant then for _ in pairs(uf.mcfKnownImportant) do knownCount = knownCount + 1 end end
    print("  uf.mcfKnownImportant entries=" .. tostring(knownCount))

    -- Clasificacion real: ClassifyAura (usa uf.mcfKnownImportant, ver
    -- HookAurasImportance mas arriba) -- muestra exactamente lo que el
    -- juego va a dibujar.
    local function dump(filter, isHarmful)
        local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, filter)
        print(("  [%s] ok=%s count=%s"):format(filter, tostring(ok), type(list) == "table" and tostring(#list) or "n/a"))
        if ok and type(list) == "table" and uf then
            for i, data in ipairs(list) do
                local group = ClassifyAura(data, isHarmful, unit, uf)
                local important = uf.mcfKnownImportant and data.auraInstanceID and uf.mcfKnownImportant[data.auraInstanceID]
                print(("    #%d name=%s important=%s -> %s"):format(
                    i, safeField(data, "name"), tostring(important and true or false), tostring(group or "REJECTED")))
            end
        end
    end
    dump("HARMFUL", true)
    dump("HELPFUL", false)

    if not uf then
        print("  no nameplate frame found for target (out of range / not skinned yet)")
        return
    end
    print("  uf.mcfAuraGroups=" .. tostring(uf.mcfAuraGroups ~= nil))
    -- REVERTIDO (2026-07-19): GetCenter() en frames colgados de una
    -- nameplate esta BLOQUEADO en este cliente ("Can't measure restricted
    -- regions") -- Blizzard no deja medir posicion de regiones dentro de la
    -- jerarquia protegida del nameplate, ni para lectura. Sin diagnostico de
    -- posicion real posible; solo se puede volcar el offset GUARDADO.
    if uf.mcfAuraGroups then
        for _, g in ipairs(AURA_GROUPS) do
            local holder = uf.mcfAuraGroups[g]
            print(("  group=%s shown=%s icons=%d dir=%s"):format(
                g, tostring(holder:IsShown()), #holder.icons,
                tostring(p and p[AURA_GROUP_DIRECTION_KEYS[g]])))
        end
    end
end

-- CORREGIDO (2026-07-27, reportado con captura: nombre/barra/badges de este
-- addon apareciendo sobre un objeto interactuable del mundo -- "Postbox
-- Parcel", un buzon): SkinNamePlate nunca filtraba por TIPO de unidad --
-- cualquier frame que Blizzard cree via NAME_PLATE_UNIT_ADDED se skineaba
-- igual, sea criatura/jugador real u objeto interactuable (buzones, cofres,
-- etc. tambien pueden tener nameplate segun CVars). El GUID codifica el tipo
-- en su prefijo ("GameObject-...", "Creature-...", "Player-...", etc).
--
-- CORREGIDO DE NUEVO (2026-07-27, reportado: "en dungeon se siguen
-- mostrando nameplates en objetos" -- confirmado con /mcfnpobjdiag:
-- guidPrefix=SECRET para TODO dentro de la mazmorra, hasta para un objeto
-- ya confirmado antes en mundo abierto). El chequeo por GUID solo funciona
-- FUERA de contenido restringido -- adentro, se necesita una señal aparte.
-- Comparando un objeto real (Bench) contra un NPC real (Over-Indulged
-- Patron) con el mismo diagnostico: UnitCreatureType da `nil` DE VERDAD
-- (pcall exitoso, resultado no pasa por issecretvalue) para el objeto, pero
-- un valor SECRETO (protegido, pero PRESENTE -- no nil) para el NPC real.
-- nil y "secreto" son estados distintos y se pueden diferenciar sin leer
-- nada -- UnitReaction confirma lo mismo (nil vs numero) como 2da señal,
-- para no depender de una sola API.
local function IsObjectNameplate(frame)
    local unit = frame.namePlateUnitToken or frame.unitToken
    if not unit then return false end

    local okG, guid = pcall(UnitGUID, unit)
    if okG and type(guid) == "string" and not (issecretvalue and issecretvalue(guid)) then
        return guid:match("^GameObject%-") ~= nil
    end

    -- GUID no disponible/secreto (contenido restringido) -- respaldo via
    -- UnitCreatureType/UnitReaction, que dan nil REAL (no secreto) para
    -- unidades que no son criaturas.
    local okT, creatureType = pcall(UnitCreatureType, unit)
    local okR, reaction = pcall(UnitReaction, "player", unit)
    return okT and creatureType == nil and okR and reaction == nil
end

local function SkinNamePlate(frame)
    if not frame then return end
    local uf = frame.UnitFrame or frame
    -- CORREGIDO (2026-07-27, confirmado con /mcfnpobjdiag: "Wooden Chair" ya
    -- detectaba IsObjectNameplate=true pero seguia MOSTRANDOSE skineado --
    -- skinned=true en el diagnostico). Causa real: Blizzard RECICLA el mismo
    -- frame Lua para unidades distintas -- este frame especifico ya habia
    -- sido skineado antes para una criatura REAL, y el chequeo viejo solo
    -- evitaba un skin NUEVO, sin revertir el anterior (barra/nombre siguen
    -- siendo mutaciones directas de una sola via, no hay "des-skinear" en
    -- este archivo). Ocultar el `uf` entero es mas simple y confiable que
    -- intentar revertir cada pieza -- sus hijos (auras/clase/cast custom)
    -- quedan ocultos automaticamente al ocultar el padre, sin tocarlos uno
    -- por uno. Blizzard lo vuelve a mostrar solo cuando reasigna el frame a
    -- una unidad real de nuevo (mismo ciclo NAME_PLATE_UNIT_ADDED).
    if IsObjectNameplate(frame) then
        if uf then uf:Hide() end
        return
    end
    if not uf or uf._mcfNPSkinned then return end
    uf._mcfNPSkinned = true

    SkinHealthBar(uf)
    HideNativeCastBar(uf)
    HideNativeAuras(uf)
    SkinName(uf)
    SkinHealthValue(uf)
    HideNativeBorder(uf.classificationIndicator)
    LockRaidMark(uf)
    SkinHighlight(uf)
    SkinThreat(uf)
end

-- Llamada desde Options.lua (ApplyCurrent) cada vez que el usuario cambia
-- algo en el menu de Nameplates -- reaplica tamaño/color/posicion de nombre,
-- valor de vida y highlight en TODAS las plates visibles ahora mismo (las que
-- aparezcan despues ya nacen con el perfil actual via Skin* al crearse).
local function RefreshNameplateStyle()
    ApplyMaxDistance()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, frame in ipairs(C_NamePlate.GetNamePlates()) do
        local uf = frame.UnitFrame or frame
        if uf then
            if uf.mcfNameHolder then ReassertNameGeometry(uf) end
            local hp = uf.healthBar
            if hp and hp.mcfValue and hp.mcfValue._mcfReassert then hp.mcfValue._mcfReassert() end
            -- Tamaño de vida (healthWidth/healthHeight) puede haber cambiado --
            -- reafirma la barra (LockBar) y el backdrop pegado a ella.
            if hp and hp._mcfReassertBar then hp._mcfReassertBar() end
            if hp and hp.mcfBackdrop then local w, h = GetHealthSize(); hp.mcfBackdrop:SetSize(w, h) end
            if uf.selectionHighlight then
                if uf.selectionHighlight._mcfReassertColor then uf.selectionHighlight._mcfReassertColor() end
                if uf.selectionHighlight._mcfReassertSize then uf.selectionHighlight._mcfReassertSize() end
            end
            if uf.mcfAuraGroups then
                uf.mcfAurasGeoSet = false; ReassertAurasGeometry(uf); uf.mcfAurasGeoSet = true
                local sz, padding = GetAuraIconSize(), GetAuraPadding()
                for _, g in ipairs(AURA_GROUPS) do
                    local holder = uf.mcfAuraGroups[g]
                    if holder._mcfLastIconSize ~= sz or holder._mcfLastPadding ~= padding then
                        holder._mcfLastIconSize = sz
                        holder._mcfLastPadding = padding
                        ns.NPBuild.LayoutAuraGroup(holder, P())
                    end
                end
            end
            if uf.mcfClass then ReassertClassification(uf) end
            if uf.RaidTargetFrame then
                if not uf.RaidTargetFrame._mcfAuraLocked then LockRaidMark(uf) end
                ReassertRaidMark(uf)
            end
            if uf.mcfCast then ReassertCastGeometry(uf) end
        end
    end
end
ns.RefreshNameplateStyle = RefreshNameplateStyle

-- Aplica (o revierte) el modo "solo nombre" para UN uf -- factoreado aparte
-- (2026-07-19, "no esta siendo inmediato, aparece el resto un milisegundo y
-- se esconde") para poder llamarlo TANTO desde el ticker de 0.2s COMO de
-- entrada, apenas Blizzard crea/reusa la plate (NAME_PLATE_UNIT_ADDED) --
-- antes solo corria en el ticker, asi que la barra/cast/auras nativas
-- alcanzaban a mostrarse un instante (hasta 200ms) antes del primer chequeo.
local function ApplyNameOnlyMode(uf, unit)
    local hideExceptName = ShouldHideExceptName(unit)
    if uf.mcfNameOnlyMode ~= hideExceptName then
        uf.mcfNameOnlyMode = hideExceptName
        if uf.mcfNameHolder then ReassertNameGeometry(uf) end
    end
    -- Solo TOCA visibilidad (Show/Hide) -- nunca color/tamaño/posicion del
    -- nombre, que sigue leyendose del perfil normal sin cambios.
    local hp = uf.healthBar
    if hp then hp:SetShown(not hideExceptName) end
    -- BUG (2026-07-19, "parece que tuviera todas seleccionadas al mismo
    -- tiempo"): esto forzaba SetShown(true) en TODAS las nameplates cada
    -- 0.2s (hideExceptName es false en el caso normal), pisando la logica
    -- NATIVA de Blizzard que decide cuando el highlight de target/focus
    -- realmente corresponde mostrarse. Solo debemos FORZAR el ocultado en
    -- modo "solo nombre" -- nunca forzar el mostrado, eso es 100% de Blizzard.
    if hideExceptName and uf.selectionHighlight then uf.selectionHighlight:Hide() end
    -- Pedido del usuario 2026-07-19: "en el name mode, que tambien se vea el
    -- raid mark" -- la marca de raid (RaidTargetFrame) queda visible en
    -- ambos modos, Blizzard controla su Show/Hide real (si la unidad tiene
    -- marca o no); solo hace falta mantener el LockRaidMark enganchado.
    if uf.RaidTargetFrame and not uf.RaidTargetFrame._mcfAuraLocked then LockRaidMark(uf) end
    if not hideExceptName then
        UpdateCastBar(uf, unit)
        UpdateAuras(uf, unit)
        UpdateClassification(uf, unit)
    else
        if uf.mcfCast then uf.mcfCast:Hide() end
        if uf.mcfAuraGroups then for _, g in ipairs(AURA_GROUPS) do uf.mcfAuraGroups[g]:Hide() end end
        if uf.mcfClass then uf.mcfClass:Hide() end
    end
end

-- ==========================================================================
-- TICKER: refresca el texto de vida de abajo. UnitHealth/UnitHealthMax
-- (y hp:GetValue()/GetMinMaxValues()) resultaron ser SECRETOS de verdad para
-- nameplates ajenos en este cliente -- confirmado en vivo: ni siquiera se
-- podia imprimir/formatear un valor derivado de ellos (se corta en silencio,
-- sin error atrapable -- el sistema de secretos bloquea hasta el intento de
-- mostrarlo). Mismo motivo por el que el resto del addon (ver GetHealthPercent
-- en Units.lua) usa PORCENTAJE en vez de numero absoluto: UnitHealthPercent
-- esta especificamente diseñada para devolver un 0-100 legible.
-- ==========================================================================
local htAcc = 0
local healthValueDriver = CreateFrame("Frame")
healthValueDriver:SetScript("OnUpdate", ns.Prof.Wrap("Nameplates: valor de vida", function(self, elapsed)
    htAcc = htAcc + elapsed
    if htAcc < 0.2 then return end
    htAcc = 0
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, frame in ipairs(C_NamePlate.GetNamePlates()) do
        local uf = frame.UnitFrame or frame
        local hp = uf and uf.healthBar
        local fs = hp and hp.mcfValue
        local unit = frame.namePlateUnitToken or frame.unitToken
        -- CENTRALIZADO (2026-07-19, "sigue con eso"): ns.GetHealthPercent
        -- (API.lua) es el unico lugar que sabe la firma real/curva de
        -- UnitHealthPercent -- ver el historial largo de ese bug ahi (se
        -- repitio en este mismo archivo Y en Units.lua por tener la logica
        -- duplicada, motivo exacto de esta centralizacion).
        if fs and unit then
            local pct = ns.GetHealthPercent(unit)
            if pct ~= nil then
                if not pcall(fs.SetFormattedText, fs, "%d%%", pct) then fs:SetText("") end
            else
                fs:SetText("")
            end
        end
        if uf then
            ApplyNameOnlyMode(uf, unit)
            UpdateNameText(uf, frame.namePlateUnitToken or frame.unitToken)
        end
    end
end))

-- BUG (reportado por el usuario, 2026-07-19): "el tamaño del nombre cambia
-- por unos segundos cuando selecciono un target" -- Blizzard anima la
-- ESCALA de la nameplate SUAVEMENTE (varios frames) cuando pasa a ser tu
-- target (nameplateSelectedScale/highlight), no de golpe. Reafirmar la
-- contra-escala del nombre solo cada 0.2s (junto con cast/auras arriba)
-- muestreaba esa animacion en "escalones" -- se notaba como el nombre
-- cambiando de tamaño en pasos durante esa transicion. Driver PROPIO sin
-- throttle (corre TODOS los frames) solo para esto -- es barato (nada mas
-- que SetScale+SetPoint por nameplate visible) y sigue la animacion suave
-- de Blizzard sin escalones visibles.
-- Las auras (solo se crean/muestran para tu TARGET actual, ver UpdateAuras)
-- tenian el MISMO bug de fondo que el nombre pero sin el fix: su contra-
-- escala se calculaba UNA sola vez (guardia mcfAurasGeoSet) y nunca se
-- volvia a tocar -- justo cuando seleccionas un target es cuando Blizzard
-- anima la escala, asi que las auras quedaban con la contra-escala
-- congelada desde el instante en que se crearon. Se suman al mismo driver
-- sin throttle -- barato (mismo costo por nameplate que el nombre).
-- PERF (2026-07-20, pedido del usuario: "lo de OnUpdate para nameplates"):
-- este driver corre SIN throttle (todos los frames, a proposito, ver
-- comentario de arriba) -- C_NamePlate.GetNamePlates() ALOCA UNA TABLA
-- NUEVA cada vez que se llama (comportamiento documentado/conocido de esta
-- API), asi que llamarla 60 veces por segundo generaba basura constante
-- (GC) solo para este driver, con nameplates visibles en pantalla. Se
-- reemplaza por `activeUF` (set mantenido por evento, ver NAME_PLATE_UNIT_
-- ADDED/REMOVED mas abajo y SkinExistingNamePlates) -- cero allocations por
-- frame, mismo resultado.
local activeUF = setmetatable({}, { __mode = "k" })
-- Este driver corria SIN throttle (todos los frames, por cada nameplate
-- visible). Tenia sentido cuando el nombre y las auras llevaban contra-escala:
-- habia que seguir la animacion de escala de Blizzard cuadro a cuadro o el
-- tamaño se veia cambiar en escalones. Desde que todo pasó al regimen "plate"
-- (2026-07-28) no hay contra-escala que seguir, y los dedupes de las dos
-- funciones ya no miran effScale -- o sea que en una raid con 30 nameplates
-- eran ~3600 llamadas por segundo que salian por `return` sin hacer nada.
--
-- Se THROTTLEA en vez de eliminarse, a proposito. Ademas de posicion, estas dos
-- reaplican el COLOR del nombre, que depende de la unidad (color de clase de
-- jugadores hostiles, color del modo solo-nombre) y no solo del perfil. Los
-- otros tres llamadores cubren los casos conocidos -- al skinear, al cambiar el
-- perfil y al alternar modo solo-nombre -- pero dejar esa red sin nada a cambio
-- de un ahorro ya conseguido no vale la pena: con 0.2s la correccion sigue
-- llegando y el costo baja de 60 pasadas por segundo a 5.
local NAME_DRIVER_INTERVAL = 0.2
local nameScaleDriver = CreateFrame("Frame")
local nameDriverElapsed = 0
nameScaleDriver:SetScript("OnUpdate", ns.Prof.Wrap("Nameplates: nombre/auras", function(_, dt)
    nameDriverElapsed = nameDriverElapsed + (dt or 0)
    if nameDriverElapsed < NAME_DRIVER_INTERVAL then return end
    nameDriverElapsed = 0
    for uf in pairs(activeUF) do
        if uf.mcfNameHolder then ReassertNameGeometry(uf) end
        if uf.mcfAuraGroups then ReassertAurasGeometry(uf) end
    end
end))

-- ==========================================================================
-- INICIALIZACION: reskin de cada nameplate cuando aparece + pasada sobre las
-- que ya esten visibles (recarga en combate, zonas, etc).
-- ==========================================================================
local function SkinExistingNamePlates()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, frame in ipairs(C_NamePlate.GetNamePlates()) do
        SkinNamePlate(frame)
        -- Semilla de activeUF (ver nameScaleDriver arriba) -- cubre plates que
        -- ya estaban visibles ANTES de que este addon se enganchara a
        -- NAME_PLATE_UNIT_ADDED (reload/zona nueva con NPCs ya en pantalla).
        local uf = frame.UnitFrame or frame
        if uf then activeUF[uf] = true end
    end
end

local ev = CreateFrame("Frame")
-- RESET CENTRALIZADO (2026-07-19, "revisa vs Platynator" -> "implementalo"):
-- Blizzard REUSA el mismo frame Lua de nameplate para unidades DISTINTAS al
-- moverte por el mundo; todo lo que colgamos de `uf` (mcfClass, mcfCast,
-- mcfAuraGroups, mcfNameOnlyMode...) persiste en ese frame reciclado. Hasta
-- ahora solo se limpiaba mcfClass a mano en el ADD (parche puntual, tras el
-- bug del icono de boss en la pet) -- cualquier otro campo nuevo quedaba sin
-- proteger contra el mismo problema (justo la clase de bug que causo el leak
-- de auras en Training Dummies). Platynator resuelve esto con un choke point
-- unico: SetUnit(nil) en NAME_PLATE_UNIT_REMOVED limpia TODO el estado del
-- widget de una vez, antes de que el frame se reasigne. Replicamos la misma
-- idea aca: un solo lugar que oculta/resetea todo lo addon-propio, llamado
-- TANTO en REMOVED (limpieza al liberar) COMO al principio de ADD (defensivo,
-- por si REMOVED no llega a tiempo en un cambio muy rapido de unidad).
local function ResetNameplateState(uf)
    if not uf then return end
    if uf.mcfClass then uf.mcfClass:Hide() end
    if uf.mcfCast then uf.mcfCast:Hide() end
    if uf.mcfAuraGroups then
        for _, g in ipairs(AURA_GROUPS) do
            uf.mcfAuraGroups[g]:Hide()
        end
    end
    -- nil (no false): fuerza a ApplyNameOnlyMode a re-evaluar Y reasertar la
    -- geometria del nombre la proxima vez, en vez de asumir que "no cambio"
    -- solo porque coincide por casualidad con el ultimo modo de la unidad
    -- ANTERIOR que ocupaba este frame.
    uf.mcfNameOnlyMode = nil
    if uf.healthBar and uf.healthBar.mcfValue then uf.healthBar.mcfValue:SetText("") end
end

ev:RegisterEvent("NAME_PLATE_UNIT_ADDED")
ev:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(self, event, unit)
    local p = P()
    if not (p and p.enabled ~= false) then return end
    if event == "NAME_PLATE_UNIT_ADDED" then
        if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
            local plate = C_NamePlate.GetNamePlateForUnit(unit)
            -- MISMO chequeo que SkinNamePlate (2026-07-27): UpdateNameText/
            -- ApplyNameOnlyMode mas abajo NO pasan por SkinNamePlate, asi que
            -- su propio guard interno no alcanzaba -- un objeto (buzon, etc)
            -- seguia recibiendo el nombre/modo estilizados igual.
            --
            -- CORREGIDO (2026-07-27, confirmado con /mcfnpobjdiag: "Wooden
            -- Chair" ya daba IsObjectNameplate=true pero seguia
            -- MOSTRANDOSE): un simple `return` aca no alcanzaba si este
            -- frame reciclado YA estaba skineado de una unidad real
            -- anterior -- el skin viejo (barra/nombre) queda pegado para
            -- siempre sin un Hide() explicito. Oculta el uf entero (mismo
            -- criterio que SkinNamePlate) y limpia el estado custom
            -- (ResetNameplateState) antes de salir.
            if plate and IsObjectNameplate(plate) then
                local objUf = plate.UnitFrame or plate
                if objUf then
                    objUf:Hide()
                    activeUF[objUf] = nil
                    ResetNameplateState(objUf)
                end
                return
            end
            SkinNamePlate(plate)
            -- Actualiza el nombre YA (no esperar el ticker de 0.2s) --
            -- perceptible sobre todo al entrar en zonas con muchos NPCs.
            local uf = plate and (plate.UnitFrame or plate)
            if uf then
                activeUF[uf] = true   -- ver nameScaleDriver arriba
                -- Reset defensivo ACA, antes de leer nada de la unidad nueva
                -- (ver ResetNameplateState arriba) -- el peor caso pasa a ser
                -- "sin icono/aura/cast un instante" en vez de "dato de la
                -- unidad ANTERIOR mostrado por error".
                ResetNameplateState(uf)
                UpdateNameText(uf, unit)
                -- Inmediato, no esperar el ticker de 0.2s (pedido del
                -- usuario 2026-07-19) -- si no, la barra/cast/auras nativas
                -- alcanzan a mostrarse un instante antes de ocultarse.
                ApplyNameOnlyMode(uf, unit)
            end
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        -- Blizzard esta por liberar/reciclar este frame -- limpiar YA en vez
        -- de esperar a que la proxima unidad lo ocupe.
        if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
            local plate = C_NamePlate.GetNamePlateForUnit(unit)
            local uf = plate and (plate.UnitFrame or plate)
            if uf then activeUF[uf] = nil end   -- ver nameScaleDriver arriba
            ResetNameplateState(uf)
        end
    else
        ApplyMaxDistance()
        SkinExistingNamePlates()
    end
end)

-- Diagnostico 2026-07-18: en vez de que el usuario adivine el instante exacto
-- de un cast para correr /mcfnpdiag, esto se engancha a los eventos de
-- casteo DIRECTO y avisa apenas Blizzard dispara uno para una nameplate --
-- confirma de una vez si UnitCastingInfo/UnitChannelInfo devuelven algo util
-- en el momento REAL del evento (sin depender de timing manual).
-- PERF (2026-07-19, pedido del usuario "limpia eso"): esto quedo siempre
-- activo -- en dungeon/raid/bg dispara un print() por CADA cast de CUALQUIER
-- unidad (registro global sin filtro de unidad, ademas de 120 RegisterUnitEvent
-- redundantes -- el registro global ya cubre lo mismo, se filtra a mano abajo).
-- Ahora apagado por default, activable con /mcfcastwatch para cuando haga
-- falta debuggear cast bars de nuevo.
local castWatchEnabled = false
local castWatch = CreateFrame("Frame")
castWatch:RegisterEvent("UNIT_SPELLCAST_START")
castWatch:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
castWatch:SetScript("OnEvent", function(self, event, unit)
    if not castWatchEnabled then return end
    if type(unit) ~= "string" or not unit:match("^nameplate") then return end
    local okC, name, _, _, startMS, endMS = pcall(UnitCastingInfo, unit)
    local okCh, cname, _, _, cstart, cend = pcall(UnitChannelInfo, unit)
    print(("|cff00ff00[MCF cast-watch]|r %s en %s -- UnitCastingInfo: ok=%s name=%s start=%s end=%s | UnitChannelInfo: ok=%s name=%s start=%s end=%s"):format(
        event, unit, tostring(okC), tostring(name), tostring(startMS), tostring(endMS),
        tostring(okCh), tostring(cname), tostring(cstart), tostring(cend)))

    -- Forzar UpdateCastBar YA (no esperar el ticker de 0.2s) y reportar el
    -- estado real del frame propio despues de eso.
    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        local uf = plate and (plate.UnitFrame or plate)
        if uf then
            UpdateCastBar(uf, unit, true)
            local cb = uf.mcfCast
            if cb then
                local w, h = cb:GetSize()
                print(("  mcfCast: shown=%s w=%.0f h=%.0f alpha=%.2f strata=%s level=%d parentShown=%s text=%s"):format(
                    tostring(cb:IsShown()), w or -1, h or -1, cb:GetAlpha() or -1, cb:GetFrameStrata(),
                    cb:GetFrameLevel(), tostring(uf:IsShown()), tostring(cb.text and cb.text:GetText())))
            else
                print("  mcfCast=nil (UpdateCastBar no lo creo) err=" .. tostring(ns._mcfLastCastErr))
            end
        else
            print("  no se encontro la nameplate/UnitFrame para " .. unit)
        end
    end
end)

SLASH_MCFCASTWATCH1 = "/mcfcastwatch"
SlashCmdList["MCFCASTWATCH"] = function()
    castWatchEnabled = not castWatchEnabled
    print("|cff00ff00[MCF cast-watch]|r " .. (castWatchEnabled and "ACTIVADO" or "desactivado"))
end

-- Pedido del usuario 2026-07-19 ("algo relacionado sobre si interrumpo un
-- cast?"): la cast bar nativa de Blizzard flashea en ROJO un instante cuando
-- el cast se interrumpe -- la nuestra (polling cada 0.2s via UpdateCastBar,
-- no por evento) simplemente la esconde en el siguiente tick sin feedback
-- alguno, se ve como si el cast hubiera terminado normal. Este handler SI es
-- por evento (UNIT_SPELLCAST_INTERRUPTED existe puntualmente para esto) y
-- fuerza un flash rojo breve antes de esconder la barra.
local interruptWatch = CreateFrame("Frame")
interruptWatch:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
interruptWatch:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
interruptWatch:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
interruptWatch:SetScript("OnEvent", function(self, event, unit)
    if type(unit) ~= "string" or not unit:match("^nameplate") then return end
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    local uf = plate and (plate.UnitFrame or plate)
    local cb = uf and uf.mcfCast
    if not cb then return end
    if event == "UNIT_SPELLCAST_INTERRUPTED" then
        if cb.mcfFlashTicker then cb.mcfFlashTicker:Cancel() end
        -- Pedido del usuario: la BARRA (relleno) desaparece, solo queda el
        -- texto "Interrupted" visible ese segundo -- oculta el fill/cd/bg,
        -- deja cb.text solo (reparentado a uf para que siga visible aunque
        -- cb:Hide() en algun punto intermedio, aunque aca no lo escondemos
        -- hasta que termine el timer).
        local fill = cb:GetStatusBarTexture()
        if fill then fill:Hide() end
        if cb.bg then cb.bg:Hide() end
        -- Pedido del usuario: texto fijo "Interrupted" (en ingles). NO se
        -- muestra el nombre de quien interrumpio -- eso requeriria combat log
        -- (SPELL_INTERRUPT), API confirmada bloqueada para addons en este
        -- cliente (ver ArenaTrinket.lua, mismo hallazgo esta sesion).
        cb.text:SetText(_G.INTERRUPTED or "Interrupted")
        cb:Show()
        cb.mcfFlashTicker = C_Timer.NewTimer(0.5, function()
            cb.mcfFlashTicker = nil
            if fill then fill:Show() end
            if cb.bg then cb.bg:Show() end
            cb:Hide()
        end)
    else
        -- Cambio de interrumpibilidad a mitad de cast (ej. un boss se vuelve
        -- inmune al stun/kick): reaplica el color correcto de inmediato, sin
        -- esperar al proximo tick de 0.2s.
        UpdateCastBar(uf, unit)
    end
end)

SLASH_MCFNPDIAG1 = "/mcfnpdiag"
SlashCmdList["MCFNPDIAG"] = function()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then
        print("|cff00ff00[MCF diag]|r C_NamePlate.GetNamePlates no existe en este cliente")
        return
    end
    local plates = C_NamePlate.GetNamePlates()
    print("|cff00ff00[MCF diag]|r nameplates visibles=" .. tostring(#plates))
    -- Fuerza bruta: prueba "nameplate1".."nameplate40" DIRECTO (no confia en
    -- frame.UnitFrame.unit, por si ese campo quedo desactualizado) + target/
    -- focus/mouseover, para descartar que el problema sea el token en si.
    local found = false
    for _, u in ipairs({ "target", "focus", "mouseover" }) do
        local okC, name = pcall(UnitCastingInfo, u)
        local okCh, cname = pcall(UnitChannelInfo, u)
        if (okC and name) or (okCh and cname) then
            found = true
            print("  " .. u .. " ESTA CASTEANDO: cast=" .. tostring(name) .. " channel=" .. tostring(cname))
        end
    end
    for i = 1, 40 do
        local u = "nameplate" .. i
        local okC, name = pcall(UnitCastingInfo, u)
        local okCh, cname = pcall(UnitChannelInfo, u)
        if (okC and name) or (okCh and cname) then
            found = true
            print("  " .. u .. " ESTA CASTEANDO: cast=" .. tostring(name) .. " channel=" .. tostring(cname))
        end
    end
    if not found then print("  |cffff5555ningun unit token detecto casteo|r") end
    for _, frame in ipairs(plates) do
        local u = frame.UnitFrame and frame.UnitFrame.unit
        if u then
            local okC, name = pcall(UnitCastingInfo, u)
            local okCh, cname = pcall(UnitChannelInfo, u)
            if (okC and name) or (okCh and cname) then
                print("  " .. u .. " ESTA CASTEANDO: cast=" .. tostring(name) .. " channel=" .. tostring(cname))
            end
        end
    end
    local sample = plates[1]
    if sample then
        local uf = sample.UnitFrame or sample
        print("  isTarget=" .. tostring(uf and uf.isTarget) .. " _mcfNPSkinned=" .. tostring(uf and uf._mcfNPSkinned)
            .. " healthBar._mcfSkinned=" .. tostring(uf and uf.healthBar and uf.healthBar._mcfSkinned))
        local unit = sample.namePlateUnitToken or sample.unitToken
        print("  unit=" .. tostring(unit) .. " uf.unit=" .. tostring(uf and uf.unit))
        do
            local u = uf and uf.unit
            print("  mcfCast=" .. tostring(uf and uf.mcfCast ~= nil)
                .. (uf and uf.mcfCast and (" shown=" .. tostring(uf.mcfCast:IsShown())) or ""))
            if u then
                local okC, name, _, _, startMS, endMS = pcall(UnitCastingInfo, u)
                print(("  UnitCastingInfo(%s): ok=%s name=%s start=%s end=%s"):format(
                    u, tostring(okC), tostring(name), tostring(startMS), tostring(endMS)))
                local okCh, cname, _, _, cstart, cend = pcall(UnitChannelInfo, u)
                print(("  UnitChannelInfo(%s): ok=%s name=%s start=%s end=%s"):format(
                    u, tostring(okCh), tostring(cname), tostring(cstart), tostring(cend)))
            end
        end
        local af = uf and uf.AurasFrame
        if af then
            local kids = { af:GetChildren() }
            print(("  AurasFrame: children=%d _mcfSkinned=%s _baseArgs=%s"):format(
                #kids, tostring(af._mcfSkinned), tostring(af._baseArgs ~= nil)))
            for i, k in ipairs(kids) do
                -- GetWidth/Height puede devolver SECRETO (confirmado en vivo,
                -- crasheaba al formatearlo con %.0f) -- pcall + chequeo antes
                -- de intentar imprimirlo.
                local okW, w = pcall(k.GetWidth, k)
                if not okW or type(w) ~= "number" or (issecretvalue and issecretvalue(w)) then w = -1 end
                print(("    child %d: %s shown=%s width=%s _mcfAuraSkinned=%s"):format(
                    i, k:GetObjectType() or "?", tostring(k:IsShown()), tostring(w), tostring(k._mcfAuraSkinned)))
            end
        else
            print("  AurasFrame=nil")
        end
        do
            local cb = uf and (uf.castBar or uf.CastBar or uf.castbar or uf.Castbar or uf.CastingBarFrame)
            print("  castBar=" .. tostring(uf and uf.castBar ~= nil) .. " CastBar=" .. tostring(uf and uf.CastBar ~= nil)
                .. " CastingBarFrame=" .. tostring(uf and uf.CastingBarFrame ~= nil)
                .. " chosen._mcfSkinned=" .. tostring(cb and cb._mcfSkinned))
        end
        -- UnitHealth/UnitHealthMax confirmados SECRETOS para nameplates
        -- ajenos (ni imprimirlos andaba) -- el texto de vida usa
        -- UnitHealthPercent en su lugar, que si es legible. Se prueba TAMBIEN
        -- con "target" (mismo token que usa el UI default de Blizzard para
        -- mostrar el numero exacto) por si el generico "nameplateN" esta mas
        -- restringido.
        if unit then
            local okP, pct = pcall(UnitHealthPercent, unit, true)
            print("  UnitHealthPercent(" .. unit .. "): ok=" .. tostring(okP) .. " val=" .. tostring(pct))
        end
        if uf and uf.isTarget then
            local okP2, pct2 = pcall(UnitHealthPercent, "target", true)
            print("  UnitHealthPercent(target): ok=" .. tostring(okP2) .. " val=" .. tostring(pct2))
        end
        if uf and uf.name then
            local n = uf.name
            local fontName, fontHeight = n:GetFont()
            local r, g, b, a = n:GetTextColor()
            print(("  name: _mcfSkinned=%s font=%s size=%.1f color=(%.2f,%.2f,%.2f,%.2f)"):format(
                tostring(n._mcfSkinned), tostring(fontName), fontHeight or -1, r or -1, g or -1, b or -1, a or -1))
        end
        print("  UnitFrame=" .. tostring(uf ~= nil) .. " healthBar=" .. tostring(uf and uf.healthBar ~= nil)
            .. " castBar=" .. tostring(uf and uf.castBar ~= nil) .. " name=" .. tostring(uf and uf.name ~= nil)
            .. " classificationIndicator=" .. tostring(uf and uf.classificationIndicator ~= nil)
            .. " RaidTargetFrame=" .. tostring(uf and uf.RaidTargetFrame ~= nil)
            .. " selectionHighlight=" .. tostring(uf and uf.selectionHighlight ~= nil)
            .. " aggroHighlight=" .. tostring(uf and uf.aggroHighlight ~= nil))
        local hp = uf and uf.healthBar
        if hp then
            -- GetPoint()/GetNumPoints() estan BLOQUEADOS en nameplates (son
            -- frames restringidos de verdad, "Can't measure restricted
            -- regions" -- confirmado en vivo) -- NO llamarlos aca.
            local w, h = hp:GetSize()
            print(("  healthBar: w=%.1f h=%.1f"):format(w or -1, h or -1))
            local function reg(name, r)
                if not r then print("    " .. name .. "=nil"); return end
                local ok, shown = pcall(function() return r:IsShown() end)
                print("    " .. name .. "=Texture shown=" .. tostring(ok and shown))
            end
            reg("bgTexture", hp.bgTexture)
            reg("selectedBorder", hp.selectedBorder)
            reg("deselectedOverlay", hp.deselectedOverlay)
            print("    mcfValue=" .. tostring(hp.mcfValue ~= nil)
                .. (hp.mcfValue and (" shown=" .. tostring(hp.mcfValue:IsShown()) .. " text=" .. tostring(hp.mcfValue:GetText())) or ""))
            local tex = hp:GetStatusBarTexture()
            if tex then
                local l, r, t, b = tex:GetTexCoord()
                print(("  statusBarTexture: w=%.1f h=%.1f texcoord=(%.3f,%.3f,%.3f,%.3f)"):format(
                    tex:GetWidth() or -1, tex:GetHeight() or -1, l or -1, r or -1, t or -1, b or -1))
            end
        end
    end
end

-- Diagnostico (2026-07-27, reportado con captura DESPUES de agregar
-- IsObjectNameplate: "aun sigo viendo nameplates en objetos" -- en "Hall of
-- the High Command", que suena a portal/entrada de mazmorra, no un buzon).
-- El filtro anterior asume prefijo de GUID "GameObject-" -- si esta plate
-- usa otro tipo (o el token/GUID no sale como se esperaba), el filtro no lo
-- agarra y no hay forma de saberlo sin datos reales en vez de adivinar una
-- tercera vez. Vuelca unit/GUID(prefijo)/nombre/IsObjectNameplate para CADA
-- plate visible ahora mismo.
SLASH_MCFNPOBJDIAG1 = "/mcfnpobjdiag"
SlashCmdList["MCFNPOBJDIAG"] = function()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then
        print("|cff00ff00[MCF obj diag]|r C_NamePlate.GetNamePlates no existe en este cliente")
        return
    end
    local plates = C_NamePlate.GetNamePlates()
    print("|cff00ff00[MCF obj diag]|r nameplates visibles=" .. tostring(#plates))
    local function safeField(fn, ...)
        local ok, v = pcall(fn, ...)
        if not ok then return "err" end
        if v == nil then return "nil" end
        if issecretvalue and issecretvalue(v) then return "SECRET" end
        return tostring(v)
    end
    for _, frame in ipairs(plates) do
        local unit = frame.namePlateUnitToken or frame.unitToken
        local uf = frame.UnitFrame or frame
        local name = "?"
        if unit then
            local okN, n = pcall(UnitName, unit)
            if okN and type(n) == "string" then name = n end
        end
        local guidPrefix = "n/a"
        if unit then
            local okG, guid = pcall(UnitGUID, unit)
            if okG and type(guid) == "string" then
                if issecretvalue and issecretvalue(guid) then
                    guidPrefix = "SECRET"
                else
                    guidPrefix = guid:match("^(%a+)%-") or ("unmatched:" .. guid)
                end
            else
                guidPrefix = "unreadable(ok=" .. tostring(okG) .. ")"
            end
        end
        local isObj = frame and IsObjectNameplate(frame)
        -- Ampliado (2026-07-27, reportado: "en dungeon se siguen mostrando
        -- nameplates en objetos" -- guidPrefix salio SECRET para TODO en
        -- dungeon, incluida la Silla que en mundo abierto SI se detectaba
        -- bien). Volcado de mas señales candidatas (todas envueltas en
        -- pcall + type()+issecretvalue() antes de imprimir, nunca se opera
        -- sobre el valor) para comparar cual sigue siendo legible en
        -- contenido restringido -- sin esto seria adivinar una 4ta vez.
        print(("  unit=%s name=%s guidPrefix=%s IsObjectNameplate=%s skinned=%s"):format(
            tostring(unit), name, guidPrefix, tostring(isObj), tostring(uf and uf._mcfNPSkinned)))
        if unit then
            print(("    creatureType=%s classification=%s reaction=%s canAttack=%s isPlayer=%s level=%s"):format(
                safeField(UnitCreatureType, unit), safeField(UnitClassification, unit),
                safeField(UnitReaction, "player", unit), safeField(UnitCanAttack, "player", unit),
                safeField(UnitIsPlayer, unit), safeField(UnitLevel, unit)))
        end
    end
end

