-- ==========================================================================
-- MyCustomFrames - Grouping.lua
-- AGRUPAMIENTO DE ARRASTRE (drag-linking) en modo edicion: al mover el elemento
-- LIDER, sus SEGUIDORES se mueven con la MISMA delta. Cada elemento conserva sus
-- controles independientes (offsets propios en el menu); esto solo agrupa el ARRASTRE.
-- Requerimientos del usuario:
--   * portrait_player  → arrastra tambien player + playerpower (portrait = lider)
--   * portrait_target  → arrastra tambien target + targetpower
--   * pet (unit)       → arrastra tambien portrait_pet  (unitframe = lider)
--   * targettarget     → arrastra tambien portrait_tot
--   * party (unit) con "mover todo junto" → arrastra tambien los portraits de party
-- Carga DESPUES de core (usa ns.GetDB / ns.RefreshUnit / ns.RefreshPortrait). Lo llama
-- core desde el OnDragStop de units y portraits via ns.MoveFollowers.
-- ==========================================================================
local ADDON, ns = ...

local DRAG_FOLLOW = {
    portrait_player = { { "player" }, { "playerpower" } },
    portrait_target = { { "target" }, { "targetpower" } },
    pet             = { { "portrait_pet", true } },
    targettarget    = { { "portrait_tot", true } },
    -- ARENA (pedido del usuario 2026-07-19): "el portrait debe seguir al
    -- unitframe" -- mismo patron que pet/targettarget (unitframe = lider).
    arena_player = { { "portrait_arena_player", true } },
    arena_party1 = { { "portrait_arena_party1", true } },
    arena_party2 = { { "portrait_arena_party2", true } },
    arena_enemy1 = { { "portrait_arena_enemy1", true } },
    arena_enemy2 = { { "portrait_arena_enemy2", true } },
    arena_enemy3 = { { "portrait_arena_enemy3", true } },
}
local PARTY_PORTRAITS = {
    "portrait_party1", "portrait_party2", "portrait_party3", "portrait_party4", "portrait_party5",
}

local function nudgeUnit(db, key, dx, dy)
    local p = db.units and db.units[key]
    if not p then return end
    p.offsetX = (p.offsetX or 0) + dx
    p.offsetY = (p.offsetY or 0) + dy
    if ns.RefreshUnit then ns.RefreshUnit(key) end
end

local function nudgePortrait(db, key, dx, dy)
    local p = db.portraits and db.portraits[key]
    if not p then return end
    -- Mueve la posicion que se esta editando (center/alt). Los portraits sin dualPos
    -- solo tienen "center".
    if p.editPos == "alt" then
        p.altX = (p.altX or 0) + dx
        p.altY = (p.altY or 0) + dy
    else
        p.centerX = (p.centerX or 0) + dx
        p.centerY = (p.centerY or 0) + dy
    end
    if ns.RefreshPortrait then ns.RefreshPortrait(key) end
end

-- Mueve los seguidores del LIDER por la delta (dx, dy) en unidades del frame lider.
function ns.MoveFollowers(leaderKey, dx, dy)
    if not (dx and dy) or (dx == 0 and dy == 0) then return end
    local db = ns.GetDB()
    if not db then return end
    local list = DRAG_FOLLOW[leaderKey]
    if list then
        for _, e in ipairs(list) do
            if e[2] then nudgePortrait(db, e[1], dx, dy) else nudgeUnit(db, e[1], dx, dy) end
        end
    end
    -- Party: al mover una party unit con "mover todo junto", sus portraits siguen.
    if leaderKey:sub(1, 5) == "party" and db.groupMoveParty then
        for _, pk in ipairs(PARTY_PORTRAITS) do nudgePortrait(db, pk, dx, dy) end
    end
end
