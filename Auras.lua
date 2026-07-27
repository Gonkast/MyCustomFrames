-- ==========================================================================
-- MyCustomFrames - Auras.lua
--
-- HISTORIAL (2026-07-27): este archivo dibujaba un grid SIEMPRE VISIBLE de
-- buffs/debuffs para Player/Target (CreateAuraGroup/UpdateAuraGroup/etc, un
-- grupo por unidad via ns.AURAS en core.lua). Pedido final del usuario:
-- "quitar el sistema de auras de player y target y agregarle el de hover"
-- -- Player/Target se mudaron a AuraHoverPreview.lua, el mismo sistema que
-- ya cubria Party/Arena/Focus (revelado por hover/combate, en vez de un grid
-- fijo siempre a la vista). `ns.AURAS` (core.lua) quedo vacio -- ver el
-- comentario largo ahi para el recorrido completo (incluye 2 rondas
-- anteriores con Party/Arena/Focus, tambien revertidas).
--
-- Lo que queda ACA es lo unico que sigue en uso real: el color de borde por
-- tipo de dispel (Magic/Curse/Poison/Disease), que AuraHoverPreview.lua
-- consume para sus 5 grupos (Player/Target/Focus/Party/Arena) via
-- ns.DebuffTypeColor. Vive en este archivo (no en AuraHoverPreview.lua)
-- simplemente porque se escribio aca primero -- y este archivo carga ANTES
-- que AuraHoverPreview.lua en el .toc, asi que la funcion ya existe para
-- cuando ese otro archivo la necesita.
-- ==========================================================================
local ADDON, ns = ...

-- Colores ESTANDAR de Blizzard por tipo de dispel (los mismos que usan los
-- unitframes nativos) -- pedido del usuario 2026-07-27: "que tengan colores
-- diferentes". Solo se aplican a DEBUFFS.
local DEBUFF_TYPE_COLORS = {
    Magic   = { r = 0.20, g = 0.60, b = 1.00 },
    Curse   = { r = 0.64, g = 0.19, b = 0.79 },
    Disease = { r = 0.60, g = 0.40, b = 0.00 },
    Poison  = { r = 0.00, g = 0.60, b = 0.00 },
}
-- Debuff sin tipo (no dispellable) -- rojo generico, igual que Blizzard.
local DEBUFF_GENERIC_COLOR = { r = 0.80, g = 0.00, b = 0.00 }

-- Color de tipo de dispel para UN debuff puntual (el generico si no tiene tipo
-- o no es legible). Asume que YA se confirmo que es un debuff -- no chequea
-- __filter, eso queda a cargo del caller. SECRET-SAFE: dispelName puede ser
-- secreto en Midnight -- solo se usa como CLAVE de tabla despues de confirmar
-- type()+issecretvalue(), nunca se compara/concatena directo (comparar un
-- secreto revienta con taint).
local function DebuffTypeColor(data)
    local dn = data.dispelName
    if type(dn) == "string" and not (issecretvalue and issecretvalue(dn)) and dn ~= "" then
        return DEBUFF_TYPE_COLORS[dn] or DEBUFF_GENERIC_COLOR
    end
    return DEBUFF_GENERIC_COLOR
end
ns.DebuffTypeColor = DebuffTypeColor
