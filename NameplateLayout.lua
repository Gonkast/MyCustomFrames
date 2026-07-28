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
--                 no encoge. Nombre y los 3 grupos de auras.
-- Cada elemento declara su regimen aca (campo `scaleRegime`) para que el
-- consumidor sepa que escala aplicarle -- antes esto vivia implicito y
-- repartido entre los dos archivos, y fue justamente la causa de que el panel
-- dibujara la barra ~36% mas grande de lo real respecto de las auras.
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
local CAST_W, CAST_H = 92, 24
local AURA_ICON = 26
local AURA_PAD = 4
local AURA_MAX_PER_CAT = 3
-- Altura base de los grupos de auras sobre el tope del nameplate. Sale de donde
-- quedaban cuando colgaban del nombre (nombre en +16, holder de alto 20, gap de
-- 6+10) -- se fija como constante para que ya no dependa del nombre. Ver
-- L.AuraGroup.
local AURA_BASE_Y = 52
-- X de fabrica POR GRUPO, para que los tres no queden apilados al resetear.
-- Tienen que seguir siendo los mismos valores que NameplateDefaults (este
-- archivo promete eso en la cabecera y es facil que se desincronice).
local AURA_BASE_X = { big = 0, personal = -100, enemy = 100 }

-- Punto del holder de auras que queda FIJO en el offset guardado, segun la
-- direccion en que crece el grupo.
local AURA_ANCHOR_POINT = { right = "BOTTOMLEFT", left = "BOTTOMRIGHT", center = "BOTTOM" }

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
    auraBaseX = AURA_BASE_X, auraBaseY = AURA_BASE_Y,
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
--            "name"). El consumidor lo traduce a su propio frame: el real usa
--            uf/uf.healthBar/uf.mcfNameHolder, el Designer sus mocks.
--
-- Barra de vida: pegada al tope del nameplate (el -1 es de Blizzard, no del
-- perfil -- no hay opcion de usuario para eso).
function L.Health(p)
    return { point = "TOP", relTo = "plate", relPoint = "TOP", x = 0, y = -1, scaleRegime = "plate" }
end

-- Nombre: ancla al NAMEPLATE (no a la barra). El 16 es el gap base de fabrica.
-- OJO -- que el ancla sea "plate" y no "health" importa: el Designer lo tenia
-- anclado a la barra, y aunque la diferencia sea de ~1px, es el tipo de
-- divergencia que este archivo existe para impedir.
function L.Name(p)
    return { point = "BOTTOM", relTo = "plate", relPoint = "TOP",
             x = num(p and p.nameOffsetX, 0), y = 16 + num(p and p.nameOffsetY, 0),
             scaleRegime = "screen" }
end

-- Valor de vida: debajo de la barra.
function L.HealthValue(p)
    return { point = "TOP", relTo = "health", relPoint = "BOTTOM",
             x = num(p and p.healthValueOffsetX, 0), y = num(p and p.healthValueOffsetY, -2),
             scaleRegime = "plate" }
end

-- Cast bar: debajo de la barra de vida.
function L.Cast(p)
    return { point = "TOP", relTo = "health", relPoint = "BOTTOM",
             x = num(p and p.castOffsetX, 0), y = num(p and p.castOffsetY, -7),
             scaleRegime = "plate" }
end

-- Texto del cast: centrado en la propia cast bar.
function L.CastText(p)
    return { point = "CENTER", relTo = "cast", relPoint = "CENTER",
             x = num(p and p.castTextOffsetX, 0), y = num(p and p.castTextOffsetY, 0),
             scaleRegime = "plate" }
end

-- Icono de clasificacion (elite/rare): al borde derecho de la barra.
function L.Classification(p)
    return { point = "RIGHT", relTo = "health", relPoint = "RIGHT",
             x = num(p and p.classificationOffsetX, 20), y = num(p and p.classificationOffsetY, -1),
             scaleRegime = "plate" }
end

-- Marca de raid: centrada en la barra.
function L.RaidMark(p)
    return { point = "CENTER", relTo = "health", relPoint = "CENTER",
             x = num(p and p.raidMarkOffsetX, 0), y = num(p and p.raidMarkOffsetY, 0),
             scaleRegime = "plate" }
end

-- Grupo de auras: ancla al NAMEPLATE, igual que el nombre -- NO al nombre.
--
-- Antes colgaba del nombre (relTo = "name") y eso era un error de diseño que
-- costo caro (lo detecto el usuario 2026-07-28: "si escalo o muevo el texto se
-- mueven esas"). Tres problemas, en orden de gravedad:
--   1. Acoplamiento invisible: ajustar el nombre movia los tres grupos de auras,
--      asi que no se podia afinar uno sin desajustar el otro.
--   2. El ancla real era `uf.mcfNameHolder or uf.name or uf` -- una cadena de
--      fallback. Si el holder propio todavia no existia cuando se colocaba el
--      grupo, quedaba anclado a la FontString de Blizzard (`uf.name`), que esta
--      en otro lado; y como el dedupe de ReassertAuraGroupGeometry compara
--      escala/punto/offsets pero NO el frame de ancla, ese anclaje equivocado
--      no se corregia nunca. El Designer, en cambio, siempre usaba el holder --
--      o sea que los dos lados podian estar anclados a frames distintos.
--   3. La posicion dependia de la ALTURA del holder del nombre (el ancla es su
--      TOP), otro numero mas que tenia que coincidir entre real y mock.
-- Anclando al plate los tres desaparecen de una: cada grupo es independiente,
-- no hay cadena de fallback posible, y no depende del tamaño de nadie.
--
-- AURA_BASE_Y reproduce donde quedaban antes (nombre en +16, alto 20, gap 16),
-- asi que el aspecto de fabrica no cambia -- lo que cambia es de QUE cuelgan.
function L.AuraGroup(p, groupKey)
    local keys = L.AURA_GROUP_OFFSET_KEYS[groupKey]
    if not keys then return nil end
    local dir = (p and p[L.AURA_GROUP_DIRECTION_KEYS[groupKey]]) or "right"
    return { point = AURA_ANCHOR_POINT[dir] or "BOTTOMLEFT", relTo = "plate", relPoint = "TOP",
             x = num(p and p[keys[1]], AURA_BASE_X[groupKey] or 0),
             y = AURA_BASE_Y + num(p and p[keys[2]], 0),
             scaleRegime = "screen" }
end
