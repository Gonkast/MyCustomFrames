local ADDON, ns = ...

-- ==========================================================================
-- MyCustomFrames - NameplateLayout.lua
--
-- FUENTE UNICA de la geometria de los nameplates (2026-07-27).
--
-- POR QUE EXISTE. Habia DOS implementaciones del mismo layout: Nameplates.lua
-- posicionaba los elementos reales y NameplateDesigner.lua reimplementaba la
-- misma cuenta para sus mocks. Mantenerlas sincronizadas a mano no funciono --
-- el usuario reporto varias veces que el panel no predecia lo que se ve en el
-- juego, y cada arreglo puntual ("hacer que el mock coincida") destapaba otra
-- diferencia: primero el gap del nombre, despues la escala, despues el ancla.
-- Con dos implementaciones eso no tiene fin: cualquier cambio futuro en una
-- vuelve a desincronizar la otra en silencio, y el bug solo se ve MIRANDO el
-- juego, nunca leyendo el codigo.
--
-- Este archivo devuelve numeros PUROS (punto de anclaje, offsets, tamaños) y
-- no toca ni un frame. Los dos consumidores aplican lo mismo a sus propios
-- frames, asi que ya no pueden divergir: si algo cambia aca, cambia en los dos
-- lados a la vez.
--
-- LAS DOS ESCALAS (clave para entender el resto). Un nameplate real tiene dos
-- regimenes conviviendo:
--   * "plate"  -> hijo directo del nameplate, SIN contra-escala: encoge con la
--                 distancia. Barra de vida, cast, clasificacion, marca de raid.
--   * "screen" -> lleva SetScale(1/effScale): queda a tamaño de PANTALLA fijo,
--                 no encoge. SOLO el nombre. Los 3 grupos de auras estuvieron
--                 aca y se pasaron a "plate" el 2026-07-28: la contra-escala es
--                 para que la FUENTE no se rasterice a tamaño fraccionario, y
--                 los iconos son texturas -- escalan suave. Tenerlos en
--                 "screen" hacia que su tamaño relativo a la barra se disparara
--                 con la distancia (1.08 alturas de cerca, 2.41 de lejos).
-- Cada elemento declara su regimen aca (campo `scaleRegime`) para que el
-- consumidor sepa que escala aplicarle -- antes esto vivia implicito y
-- repartido entre los dos archivos, y fue justamente la causa de que el panel
-- dibujara la barra ~36% mas grande de lo real respecto de las auras.
--
-- OJO CON EL REGIMEN "screen" (2026-07-28, la causa de fondo de que el panel
-- nunca coincidiera): la contra-escala existe para que la FUENTE se rasterice
-- siempre al mismo tamaño fisico (texto nitido a cualquier distancia). Pero
-- arrastraba consigo la POSICION: con escala efectiva 1, un offset de 16 son 16
-- pixeles de pantalla FIJOS, mientras la barra encoge con la distancia. O sea
-- que la separacion nombre-barra, medida en alturas de barra, variaba mas del
-- DOBLE segun lo lejos que estuviera el mob (0.71 a 1.52), y un panel dibujado
-- a una sola escala no puede predecir eso: coincidia a una distancia exacta y
-- fallaba en todas las demas.
--
-- Por eso los offsets de este archivo se interpretan SIEMPRE en unidades del
-- PLATE, tambien para los elementos "screen". Quien los aplica los multiplica
-- por la escala del plate (el real por GetEffectiveScale, el Designer por su
-- escala de referencia). Asi la proporcion queda fija a cualquier distancia, el
-- texto sigue nitido porque la contra-escala del holder no se toca, y de yapa la
-- escala de referencia del panel deja de afectar la POSICION -- se cancela en la
-- razon, asi que un valor de referencia equivocado ya no puede desalinear nada.
--
-- Carga ANTES de Nameplates.lua en el .toc (que a su vez carga antes que
-- NameplateDesigner.lua), asi ambos lo tienen disponible al construirse.
-- ==========================================================================

-- Defaults de fabrica (mismos valores que NameplateDefaults en Nameplates.lua
-- -- se repiten aca para que las funciones sean PURAS y no dependan de que la
-- DB este inicializada; el perfil siempre pisa estos valores cuando existe).
-- OJO: estos DEBEN ser los mismos que HEALTH_SIZE/CAST_SIZE en Nameplates.lua
-- (de donde salen healthWidth/healthHeight/castWidth/castHeight en
-- NameplateDefaults). Estuvieron en 150x24 y 150x12 contra los 92x24 y 92x24
-- reales -- justo la deriva silenciosa que este archivo existe para impedir,
-- pero en el archivo mismo. Se corrigio 2026-07-28 al conectar los helpers.
local HEALTH_W, HEALTH_H = 92, 24
local CAST_W, CAST_H = 73, 20
local AURA_ICON = 22
local AURA_PAD = 4
local AURA_MAX_PER_CAT = 3

-- Punto del holder de auras que queda FIJO en el offset guardado, segun la
-- direccion en que crece el grupo.
local AURA_ANCHOR_POINT = { right = "BOTTOMLEFT", left = "BOTTOMRIGHT", center = "BOTTOM" }

-- Fuente compartida del contador/tiempo de las auras de nameplate (2026-08-05,
-- "que tengan las mismas opciones... los mismos datos size y colores... y
-- que no se puedan controlar" -- mismo criterio fijo que ya se uso para
-- Player/Target: 1 sola fuente COMPARTIDA, sin slider/color picker propios).
-- Antes NameplateBuild.lua (mock del Designer) y el sistema viejo apagado
-- (Nameplates.lua) esperaban un font object llamado "MCFAuraTimeFontObj",
-- pero solo Nameplates.lua lo CREABA -- con ese archivo deshabilitado, el
-- nombre nunca resolvia a nada real y SetCountdownFont fallaba en silencio
-- (pcall). Se recrea aca (carga temprano, antes de NameplateBuild.lua/
-- NameplateAurasNext.lua) con el MISMO nombre para no tener que tocar esos
-- 2 archivos donde ya se lo pide por nombre.
local MCFAuraTimeFontObj = CreateFont("MCFAuraTimeFontObj")
MCFAuraTimeFontObj:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
if ns.GOLD then
    MCFAuraTimeFontObj:SetTextColor(ns.GOLD.r, ns.GOLD.g, ns.GOLD.b, 1)
else
    MCFAuraTimeFontObj:SetTextColor(1, 1, 1, 1)
end

local L = {}
ns.NPLayout = L

L.AURA_ANCHOR_POINT = AURA_ANCHOR_POINT
L.AURA_MAX_PER_CAT = AURA_MAX_PER_CAT

-- Valores de fabrica EXPUESTOS para que NameplateDefaults (Nameplates.lua) los
-- construya desde aca en vez de tener su propia copia. Antes habia dos juegos
-- de constantes que "debian coincidir" y no coincidian (150x24 aca contra 92x24
-- alla). Una sola fuente elimina el problema en vez de documentarlo.
L.FACTORY = {
    healthW = HEALTH_W, healthH = HEALTH_H,
    castW = CAST_W, castH = CAST_H,
    auraIcon = AURA_ICON, auraPad = AURA_PAD,
}

-- Claves de offset por grupo de auras (mismas 3 categorias que ClassifyAura).
L.AURA_GROUP_OFFSET_KEYS = {
    big      = { "bigDebuffOffsetX", "bigDebuffOffsetY" },
    personal = { "personalDebuffsOffsetX", "personalDebuffsOffsetY" },
    enemy    = { "enemyBuffsOffsetX", "enemyBuffsOffsetY" },
}
L.AURA_GROUP_DIRECTION_KEYS = {
    big = "bigDebuffDirection", personal = "personalDebuffsDirection", enemy = "enemyBuffsDirection",
}
-- Default POR GRUPO (2026-08-05, "las posiciones no son iguales"): antes de
-- que Nameplates.lua (viejo) se deshabilitara, NameplateDefaults sembraba
-- estos 3 valores en cada perfil nuevo -- bigDebuffDirection="right",
-- personalDebuffsDirection="center", enemyBuffsDirection="left" (repartidos
-- a proposito para no superponerse). L.AuraGroup (mas abajo) caia a "right"
-- PARA LOS 3 si el perfil no tenia el valor guardado -- con Nameplates.lua
-- apagado, nadie siembra el default nunca, asi que cualquier perfil sin
-- estos 3 campos EXPLICITOS (perfiles nuevos, o viejos donde nunca se toco
-- el boton de Direction) terminaba con personal/enemy tambien en "right",
-- los 3 amontonados en el mismo lado -- justo el sintoma reportado.
L.AURA_GROUP_DEFAULT_DIRECTION = { big = "right", personal = "center", enemy = "left" }

local function num(v, dflt) return (type(v) == "number") and v or dflt end

-- ---- Tamaños -------------------------------------------------------------
function L.HealthSize(p)
    return num(p and p.healthWidth, HEALTH_W), num(p and p.healthHeight, HEALTH_H)
end
function L.CastSize(p)
    return num(p and p.castWidth, CAST_W), num(p and p.castHeight, CAST_H)
end
function L.HighlightSize(p)
    local w, h = L.HealthSize(p)
    return w + 4, h + 4
end
function L.AuraIconSize(p) return num(p and p.auraIconSize, AURA_ICON) end
function L.AuraPadding(p)  return num(p and p.auraPadding, AURA_PAD) end
function L.AuraHolderSize(p)
    local sz, pad = L.AuraIconSize(p), L.AuraPadding(p)
    return sz * AURA_MAX_PER_CAT + pad * (AURA_MAX_PER_CAT - 1), sz
end
-- Posicion de un icono dentro de su holder (slot 1..AURA_MAX_PER_CAT).
function L.AuraIconOffset(p, slot)
    local sz, pad = L.AuraIconSize(p), L.AuraPadding(p)
    return (slot - 1) * (sz + pad), 0
end

-- ---- Colocacion ----------------------------------------------------------
-- Todas devuelven una tabla: { point, relTo, relPoint, x, y, scaleRegime }
--   relTo -- QUE elemento es el ancla, por nombre logico ("plate", "health",
--            "cast"). El consumidor lo traduce a su propio frame.
--
-- POSICIONES NATIVAS (2026-07-28). BASE[k] es la posicion de fabrica de cada
-- elemento; el perfil guarda solo un DELTA sobre ella, que vale 0 de fabrica.
--
-- Antes convivian DOS convenciones y eso era una trampa: el nombre y las auras
-- hacian `16 + offset` / `52 + offset` (el offset era un delta), mientras que
-- cast, valor de vida y clasificacion hacian `num(offset, -7)` (el offset ERA
-- la posicion, y el numero de al lado solo un fallback). Mezclarlas significaba
-- que "poner el offset en 0" queria decir cosas distintas segun el elemento.
-- Ahora es una sola: posicion = BASE + delta, delta 0 = fabrica.
local BASE = {
    health         = { 0,      -1     },   -- el -1 es de Blizzard, sin opcion de usuario
    name           = { 0,      -3.46  },
    healthValue    = { 0,      10.37  },
    cast           = { 0,      0.41   },
    castText       = { 0,     -13.99  },
    classification = { 11.11,  -0.41  },
    raidMark       = { 64.20,  39.12  },
}
-- Posicion nativa de cada grupo de auras (los tres difieren, por eso van aparte).
local AURA_BASE = {
    big      = {  50.00, -25.00 },
    personal = {   0.00,  19.03 },
    enemy    = { -50.02, -24.85 },
}

-- Tablas de SCRATCH, una por pieza (2026-07-28). Estas funciones devolvian una
-- tabla NUEVA en cada llamada, y el driver de nameplates las pide 5 veces por
-- segundo por cada plate visible: en una raid de 30 eran ~450 tablas/segundo
-- creadas y tiradas, presion de GC pura que no aparece en un profiler de CPU.
--
-- Reusarlas es seguro porque se verificaron las tres condiciones: ningun
-- consumidor RETIENE la tabla (B.Place lee 5 campos y los aplica; LockBar
-- recibe los valores sueltos), ninguno la MUTA, y nunca hay dos vivas a la vez
-- (LayoutPlate consume cada una antes de pedir la siguiente).
--
-- Una por pieza y no una sola compartida a proposito: asi dos elementos
-- distintos jamas pueden pisarse, y el unico modo de fallo concebible seria
-- reentrada sobre la MISMA pieza -- que no puede pasar, esto es codigo
-- sincronico sin corrutinas.
--
-- OJO si tocas esto: si algun dia escribis codigo que guarde una de estas
-- tablas o que tenga dos de la misma pieza vivas al mismo tiempo, hace una
-- copia. Devolver un scratch es la razon por la que esto no aloca.
local SCRATCH = setmetatable({}, { __index = function(t, k)
    local v = {}
    rawset(t, k, v)
    return v
end })

local function fill(key, point, relTo, relPoint, x, y, regime)
    local o = SCRATCH[key]
    o.point, o.relTo, o.relPoint = point, relTo, relPoint
    o.x, o.y, o.scaleRegime = x, y, regime
    return o
end

local function off(p, xKey, yKey, base)
    return base[1] + num(p and p[xKey], 0), base[2] + num(p and p[yKey], 0)
end

-- Barra de vida: pegada al tope del nameplate. Sin offset de usuario.
function L.Health(p)
    return fill("health", "TOP", "plate", "TOP", BASE.health[1], BASE.health[2], "plate")
end

-- Nombre: ancla al NAMEPLATE, no a la barra.
--
-- Regimen "plate" desde 2026-07-28 (pedido del usuario: "necesito que todo se
-- escale junto, para ver el verdadero tamaño de todos los elementos"). Era la
-- ultima pieza en "screen": su letra quedaba a tamaño de pantalla fijo mientras
-- el resto encogia con la distancia, asi que el editor no podia mostrar su
-- tamaño real. Cambiar el regimen NO lo mueve -- las dos convenciones dan
-- l.y * scale; lo unico que cambia es el tamaño fisico de la letra.
--
-- COSTO CONOCIDO: la contra-escala evitaba que la fuente se rasterizara a
-- tamaños fraccionarios (texto borroso a distancia). Vuelve a estar expuesta.
-- Alternativa si molesta: mantener la contra-escala y escalar nameFontSize por
-- la escala del plate -- nitido, pero el tamaño cambia en escalones.
-- `nameOnly`: en modo "solo nombre" (jugadores amistosos, sin barra) el nombre
-- usa SU PROPIO par de offsets, para poder ajustarlo sin tocar el modo normal.
-- Ese caso lo resuelve el layout, no el consumidor: Nameplates.lua lo hacia
-- pisando nl.x/nl.y con `16 + offY` DESPUES de pedir la tabla, y esa formula
-- vieja se quedo cuando la posicion nativa paso a BASE -- el nombre volvia a
-- +16 en vez de quedarse en su posicion horneada (reportado 2026-07-28).
function L.Name(p, nameOnly)
    local xKey = nameOnly and "nameOnlyOffsetX" or "nameOffsetX"
    local yKey = nameOnly and "nameOnlyOffsetY" or "nameOffsetY"
    local x, y = off(p, xKey, yKey, BASE.name)
    return fill("name", "BOTTOM", "plate", "TOP", x, y, "plate")
end

-- Valor de vida (% ): respecto de la barra.
function L.HealthValue(p)
    local x, y = off(p, "healthValueOffsetX", "healthValueOffsetY", BASE.healthValue)
    return fill("healthValue", "TOP", "health", "BOTTOM", x, y, "plate")
end

-- Cast bar: debajo de la barra de vida.
function L.Cast(p)
    local x, y = off(p, "castOffsetX", "castOffsetY", BASE.cast)
    return fill("cast", "TOP", "health", "BOTTOM", x, y, "plate")
end

-- Texto del cast: centrado en la propia cast bar.
function L.CastText(p)
    local x, y = off(p, "castTextOffsetX", "castTextOffsetY", BASE.castText)
    return fill("castText", "CENTER", "cast", "CENTER", x, y, "plate")
end

-- Icono de clasificacion (elite/rare): al borde derecho de la barra.
function L.Classification(p)
    local x, y = off(p, "classificationOffsetX", "classificationOffsetY", BASE.classification)
    return fill("classification", "RIGHT", "health", "RIGHT", x, y, "plate")
end

-- Marca de raid: respecto del centro de la barra.
function L.RaidMark(p)
    local x, y = off(p, "raidMarkOffsetX", "raidMarkOffsetY", BASE.raidMark)
    return fill("raidMark", "CENTER", "health", "CENTER", x, y, "plate")
end

-- Grupo de auras: ancla al NAMEPLATE, igual que el nombre -- NO al nombre.
--
-- Colgaba del nombre y era un error de diseño que costo caro (lo detecto el
-- usuario: "si escalo o muevo el texto se mueven esas"). Tres problemas:
--   1. Acoplamiento invisible: ajustar el nombre movia los tres grupos.
--   2. El ancla real era `uf.mcfNameHolder or uf.name or uf` -- una cadena de
--      fallback que podia dejarlos colgados de la FontString de Blizzard de
--      forma permanente, porque el dedupe no comparaba el frame de ancla.
--   3. La posicion dependia de la ALTURA del holder del nombre.
--
-- Regimen "plate", no "screen": con contra-escala los iconos quedaban a tamaño
-- de pantalla fijo mientras la barra encogia, asi que su tamaño relativo se
-- disparaba con la distancia (1.08 alturas de barra de cerca, 2.41 de lejos).
-- Son texturas, escalan suave -- no tienen el problema de rasterizado del texto.
function L.AuraGroup(p, groupKey)
    local keys = L.AURA_GROUP_OFFSET_KEYS[groupKey]
    local base = AURA_BASE[groupKey]
    if not (keys and base) then return nil end
    local dir = (p and p[L.AURA_GROUP_DIRECTION_KEYS[groupKey]]) or L.AURA_GROUP_DEFAULT_DIRECTION[groupKey] or "right"
    local x, y = off(p, keys[1], keys[2], base)
    -- scratch POR GRUPO ("aura:big" y demas): los tres se piden seguidos en el
    -- bucle de LayoutPlate, asi que compartir una sola seria correcto igual,
    -- pero separadas no hay ni que razonarlo.
    return fill("aura:" .. groupKey, AURA_ANCHOR_POINT[dir] or "BOTTOMLEFT", "plate", "TOP", x, y, "plate")
end
