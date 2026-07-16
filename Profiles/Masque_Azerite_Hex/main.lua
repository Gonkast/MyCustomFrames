-- Masque_Azerite_Hex/main.lua

-- Grab the Masque library (silent if missing)
local MSQ = LibStub and LibStub("Masque", true)
if not MSQ then
    return
end

-- Your addon’s folder name as passed in by the .toc
local ADDON = ...

-- Masque expects buttons to be 36×36 points.
-- This helper adjusts sizes based on your source textures.
local mod = 1.5
local function scale(contentSize, sourceTextureSize)
    sourceTextureSize = sourceTextureSize or contentSize
    return sourceTextureSize / contentSize * 36 * mod
end

-- Helper for your media folder
local function path(name)
    return ("Interface\\AddOns\\%s\\media\\%s.tga"):format(ADDON, name)
end

-- Disable the “bling” animation on all cooldown spirals
-- Use pcall to safely iterate through globals and avoid protected table errors
for _, v in pairs(_G) do
    pcall(function()
        if type(v) == "table" and type(v.SetDrawBling) == "function" then
            v:SetDrawBling(false)
        end
    end)
end
hooksecurefunc(getmetatable(ActionButton1Cooldown).__index, "SetCooldown", function(self)
    self:SetDrawBling(false)
end)

local API_VERSION = 110210

-- Register the skin
MSQ:AddSkin("Azerite HEX", {
    API_VERSION    = API_VERSION,
    Shape          = "Circle",

    Description = "Designed to match the buttons in AzeriteUI.",
    Version     = "1.0",  -- Hard-coded version
    Authors     = { "Daniel Troko", "|cff999999Lars Norberg|r" },
    Websites    = {
        "https://github.com/AzeriteTeam/Masque_Azerite",
        "https://www.curseforge.com/wow/addons/masque-azerite"
    },

    -- Normal (border & empty)
    Normal = {
        Width        = scale(256, 256),
        Height       = scale(256, 256),
        Texture      = path("actionbutton-border"),
        EmptyTexture = path("actionbutton-border"),
        TexCoords    = {0,1,0,1},
        Color        = {1,1,1,1},
        EmptyColor   = {1,1,1,1},
    },

    Border = {
        Width     = scale(256, 256),
        Height    = scale(256, 256),
        TexCoords = {0,1,0,1},
        BlendMode = "BLEND",
        Color     = {1,1,1,1},
        Texture   = path("actionbutton-border"),
    },

    Highlight = {
        Width     = scale(256, 256),
        Height    = scale(256, 256),
        TexCoords = {0,1,0,1},
        BlendMode = "ADD",
        Color     = {1,1,1,0.25},
        Texture   = path("actionbutton-border"),
    },

    Backdrop = {
        Width     = scale(256, 256),
        Height    = scale(256, 256),
        TexCoords = {0,1,0,1},
        Color     = {1,1,1,1},
        Texture   = path("actionbutton-backdrop"),
    },

    Checked = {
        Width     = scale(256, 256),
        Height    = scale(256, 256),
        TexCoords = {0,1,0,1},
        BlendMode = "BLEND",
        Color     = {1,1,1,1},
        Texture   = path("actionbutton-border"),
    },

    Icon = {
        Width     = scale(64, 42),
        Height    = scale(64, 42),
        Mask      = path("actionbutton_circular_mask"),
        TexCoords = {0,1,0,1},
    },

    Flash = {
        Width     = scale(64, 42),
        Height    = scale(64, 42),
        Color     = {0.7,0,0,0.3},
        Texture   = path("actionbutton-pushed"),
    },

    Pushed = {
        Width     = scale(32, 32),
        Height    = scale(32, 32),
        Color     = {1,1,1,0.15},
        Texture   = path("actionbutton-pushed"),
    },

    Gloss = {
        Width     = scale(256, 256),
        Height    = scale(256, 256),
        TexCoords = {0,1,0,1},
        BlendMode = "BLEND",
        Color     = {1,1,1,1},
        Texture   = path("actionbutton-glow-white"),
    },

    Cooldown = {
        Width   = 54,
        Height  = 54,
        Color   = {0,0,0,0.7},
        Texture = path("actionbutton-pushed"),
    },

    ChargeCooldown = {
        Width  = 34,
        Height = 34,
    },

    AutoCast = {
        Width   = 32,
        Height  = 32,
        OffsetX = 1,
        OffsetY = -1,
    },

    AutoCastable = {
        Width   = 62,
        Height  = 62,
        OffsetX = 1,
        OffsetY = 0,
        Texture = [[Interface\Buttons\UI-AutoCastableOverlay]],
    },

    Disabled = {
        Hide = true,
    },

    Name = {
        Hide = true,
    },

    Count = {
        Width   = 36,
        Height  = 12,
        OffsetX = -22,
        OffsetY = 0,
    },

    HotKey = {
        Width   = 25,
        Height  = 12,
        OffsetX = -22,
        OffsetY = 0,
    },

    Duration = {
        Width   = 36,
        Height  = 12,
        OffsetX = 0,
        OffsetY = 0,
    },
}, true)