-- ==========================================================================
-- MasqueSkin.lua — registra el skin de Masque "Azerite HEX" (portado de la skin del usuario
-- Masque_Azerite_Hex, E:\...\AddOns\Masque_Azerite_Hex\main.lua) DIRECTAMENTE desde
-- MyCustomFrames, sin necesitar el addon separado. Assets copiados a
-- Assets\MasqueSkin\ (mismos .tga, mismos nombres). Carga tras core (usa ns.GetDB opcionalmente
-- para el auto-apply del Setup Wizard, pero el registro del skin en si no depende de db).
-- Si Masque no esta cargado, esta funcion no hace nada (silencioso, como el original).
-- ==========================================================================
local ADDON, ns = ...

local A = "Interface\\AddOns\\MyCustomFrames\\Assets\\MasqueSkin\\"
local function path(name) return A .. name .. ".tga" end

local SKIN_NAME = "Azerite HEX"

-- Masque espera botones de 36x36 puntos; el mismo helper de escala que traia el addon original.
local mod = 1.5
local function scale(contentSize, sourceTextureSize)
    sourceTextureSize = sourceTextureSize or contentSize
    return sourceTextureSize / contentSize * 36 * mod
end

local registered = false

-- Registra el skin en Masque. Idempotente (Masque:AddSkin sobre el mismo nombre solo actualiza
-- los datos, no duplica) — se puede llamar mas de una vez sin problema.
local function RegisterSkin()
    if registered then return true end
    local MSQ = LibStub and LibStub("Masque", true)
    if not MSQ then return false end

    -- Si el addon STANDALONE viejo (Masque_Azerite_Hex) tambien esta cargado, dejalo a EL
    -- registrar el skin (mismo nombre, mismos datos) para no duplicar el hook anti-bling de
    -- abajo dos veces. Con que uno de los dos lo registre alcanza.
    local oldLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Masque_Azerite_Hex"))
        or (IsAddOnLoaded and IsAddOnLoaded("Masque_Azerite_Hex"))
    if oldLoaded then registered = true; return true end

    -- Apaga la animacion "bling" de los cooldowns (igual que el addon original): pcall por si
    -- algun otro addon ya lo desactivo o el metodo no existe en este objeto.
    for _, v in pairs(_G) do
        pcall(function()
            if type(v) == "table" and type(v.SetDrawBling) == "function" then
                v:SetDrawBling(false)
            end
        end)
    end
    -- El pcall de ANTES solo protegia el REGISTRO del hook -- el hook en si
    -- corre SIN pcall cada vez que CUALQUIER Cooldown del juego llama
    -- SetCooldown (via metatable compartida, no solo botones de accion).
    -- Bug real (2026-07-19): con el swipe de las auras de nameplate nuevo,
    -- self a veces es un Cooldown alimentado con un valor SECRETO -- indexar
    -- self para llamar :SetDrawBling ahi explota ("attempt to index... a
    -- secret table value"). El PRIMER intento (`pcall(self.SetDrawBling,
    -- self, false)`) seguia roto: `self.SetDrawBling` es un ARGUMENTO de
    -- pcall, se evalua/indexa ANTES de que pcall entre en juego, asi que el
    -- indexado quedaba SIN proteger igual. Fix real: el indexado tiene que
    -- pasar DENTRO del cuerpo de la funcion que pcall llama.
    -- PERF (2026-07-19, "arregla todo"): este hook corre para TODOS los
    -- cooldowns del juego (metatable compartida), no solo los del addon --
    -- antes creaba una closure NUEVA `function() self:SetDrawBling(false) end`
    -- en cada llamada solo para poder envolverla en pcall. DisableBling de
    -- abajo no captura ningun upvalue (self llega como parametro), asi que se
    -- puede declarar UNA sola vez a nivel de modulo y pasarla a pcall junto
    -- con self como argumento -- el indexado sigue pasando DENTRO del cuerpo
    -- protegido (mismo fix de fondo que antes), pero sin alocar closure.
    local function DisableBling(self) self:SetDrawBling(false) end
    pcall(function()
        hooksecurefunc(getmetatable(ActionButton1Cooldown).__index, "SetCooldown", function(self)
            pcall(DisableBling, self)
        end)
    end)

    MSQ:AddSkin(SKIN_NAME, {
        API_VERSION    = 110210,
        Shape          = "Circle",

        Description = "Designed to match the buttons in AzeriteUI. Bundled with MyCustomFrames.",
        Version     = "1.0",
        Authors     = { "Daniel Troko", "|cff999999Lars Norberg|r" },

        Normal = {
            Width = scale(256, 256), Height = scale(256, 256),
            Texture = path("actionbutton-border"), EmptyTexture = path("actionbutton-border"),
            TexCoords = { 0, 1, 0, 1 }, Color = { 1, 1, 1, 1 }, EmptyColor = { 1, 1, 1, 1 },
        },
        Border = {
            Width = scale(256, 256), Height = scale(256, 256),
            TexCoords = { 0, 1, 0, 1 }, BlendMode = "BLEND", Color = { 1, 1, 1, 1 },
            Texture = path("actionbutton-border"),
        },
        Highlight = {
            Width = scale(256, 256), Height = scale(256, 256),
            TexCoords = { 0, 1, 0, 1 }, BlendMode = "ADD", Color = { 1, 1, 1, 0.25 },
            Texture = path("actionbutton-border"),
        },
        Backdrop = {
            Width = scale(256, 256), Height = scale(256, 256),
            TexCoords = { 0, 1, 0, 1 }, Color = { 1, 1, 1, 1 },
            Texture = path("actionbutton-backdrop"),
        },
        Checked = {
            Width = scale(256, 256), Height = scale(256, 256),
            TexCoords = { 0, 1, 0, 1 }, BlendMode = "BLEND", Color = { 1, 1, 1, 1 },
            Texture = path("actionbutton-border"),
        },
        Icon = {
            Width = scale(64, 42), Height = scale(64, 42),
            Mask = path("actionbutton_circular_mask"), TexCoords = { 0, 1, 0, 1 },
        },
        Flash = {
            Width = scale(64, 42), Height = scale(64, 42),
            Color = { 0.7, 0, 0, 0.3 }, Texture = path("actionbutton-pushed"),
        },
        Pushed = {
            Width = scale(32, 32), Height = scale(32, 32),
            Color = { 1, 1, 1, 0.15 }, Texture = path("actionbutton-pushed"),
        },
        Gloss = {
            Width = scale(256, 256), Height = scale(256, 256),
            TexCoords = { 0, 1, 0, 1 }, BlendMode = "BLEND", Color = { 1, 1, 1, 1 },
            Texture = path("actionbutton-glow-white"),
        },
        Cooldown = {
            Width = 54, Height = 54, Color = { 0, 0, 0, 0.7 }, Texture = path("actionbutton-pushed"),
        },
        ChargeCooldown = { Width = 34, Height = 34 },
        AutoCast = { Width = 32, Height = 32, OffsetX = 1, OffsetY = -1 },
        AutoCastable = {
            Width = 62, Height = 62, OffsetX = 1, OffsetY = 0,
            Texture = [[Interface\Buttons\UI-AutoCastableOverlay]],
        },
        Disabled = { Hide = true },
        Name = { Hide = true },
        Count = { Width = 36, Height = 12, OffsetX = -22, OffsetY = 0 },
        HotKey = { Width = 25, Height = 12, OffsetX = -22, OffsetY = 0 },
        Duration = { Width = 36, Height = 12, OffsetX = 0, OffsetY = 0 },
    }, true)

    registered = true
    return true
end
ns.RegisterMasqueSkin = RegisterSkin

-- IMPORTANTE: la API PUBLICA de Masque (Core\Groups.lua, Core\Skins.lua) NO expone forma de
-- ENUMERAR grupos ya registrados por otros addons -- no existe `MSQ:GetGroups()` (confirmado
-- leyendo el codigo fuente actual: los unicos metodos publicos son Group/GetGroupByID/
-- Get{Normal,Backdrop,Gloss,Shadow}/SetEmpty, ninguno enumera).
--
-- 2026-07-23: se probo automatizar esto leyendo bar.MasqueGroup directo de Bartender4 (metodo
-- "interno" __Set de Masque) -- funcionaba, pero el usuario prefirio revertirlo (mas simple/
-- predecible: un aviso pidiendo elegir la skin a mano en el panel de Masque). Si se quiere
-- retomar el auto-reskin de Bartender4 mas adelante, ver el historial de esta sesion.
--
-- Llamada desde ns.ApplySkin (core.lua) cada vez que el usuario cambia de skin visual.
-- `skin` = la entrada de ns.TEX_SKINS recien aplicada. Solo guarda cual skin de Masque
-- corresponde y le pide al usuario que la seleccione a mano en el panel de Masque (mismo
-- nombre que la skin visual, ej. "Midnight" -> skin de Masque "Midnight").
function ns.ApplyMasqueSkinAll(skin)
    local ok = RegisterSkin()
    if not ok then return false, "Masque not loaded" end

    local db = ns.GetDB and ns.GetDB()
    local target = skin and skin.msqSkin
    if db then db.activeMsqSkin = target end

    if not target then
        return true, "skin registered (this visual skin has no Masque skin declared)"
    end

    print("|cff00ff00[MCF]|r This skin uses the Masque skin \"" .. target ..
        "\" for action bars -- open Masque's panel and select \"" .. target ..
        "\" there (Masque remembers it, so a /reload also picks it up once you've chosen it before).")
    return true, "skin registered, Masque skin \"" .. target .. "\" noted (pick it manually in Masque's panel)"
end

-- Registro INMEDIATO en file-load (no diferido a PLAYER_LOGIN): asi el skin esta disponible
-- ANTES de que Bartender4 (u otro addon de barras) cree sus grupos de Masque, sin importar el
-- orden relativo de carga entre addons regulares.
RegisterSkin()
