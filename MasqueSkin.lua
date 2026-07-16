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
    pcall(function()
        hooksecurefunc(getmetatable(ActionButton1Cooldown).__index, "SetCooldown", function(self)
            self:SetDrawBling(false)
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

-- IMPORTANTE (fix de un crash real, 2026-07-15): la API PUBLICA de Masque (Core\Groups.lua,
-- Core\Skins.lua) NO expone forma de ENUMERAR los grupos ya registrados por otros addons — no
-- existe `MSQ:GetGroups()` (eso fue un supuesto mio erroneo, causo "attempt to call a nil value").
-- Los unicos metodos publicos son `MSQ:Group(Addon, Group, StaticID)` (crea O devuelve un grupo
-- EXISTENTE, si conoces el Addon/Group/StaticID exactos) y `MSQ:GetGroupByID(StaticID)`. Sin
-- conocer de antemano los nombres de grupo que usa cada addon de barras (Bartender4 los arma
-- dinamicamente por bar id), no hay un "aplicar a todos" generico y seguro. Por eso NO existe
-- ns.ApplyMasqueSkinAll: la unica via confiable es que el skin ESTE REGISTRADO ANTES de que el
-- addon de barras cree sus grupos (Masque NO re-skinea grupos existentes cuando se agrega un
-- skin nuevo — AddSkin no dispara ningun refresh). Por eso se registra EN FILE-LOAD (abajo, sin
-- esperar ningun evento) igual que hacia el addon original Masque_Azerite_Hex (su main.lua
-- llamaba MSQ:AddSkin(...) directo en el cuerpo del archivo, sin diferir a ningun evento) — con
-- el addon declarado en `## OptionalDeps: ..., Masque, ...` del toc, el cliente carga Masque
-- ANTES que MyCustomFrames, asi que LibStub("Masque") ya esta disponible en este punto.
function ns.ApplyMasqueSkinAll()
    local ok = RegisterSkin()
    if not ok then return false, "Masque not loaded" end
    return true, "skin registered (existing action bars pick it up on their next /reload; " ..
        "select it manually in Masque's panel if a bar doesn't switch automatically)"
end

-- Registro INMEDIATO en file-load (no diferido a PLAYER_LOGIN): asi el skin esta disponible
-- ANTES de que Bartender4 (u otro addon de barras) cree sus grupos de Masque, sin importar el
-- orden relativo de carga entre addons regulares.
RegisterSkin()
