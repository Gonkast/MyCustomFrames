-- ==========================================================================
-- MyCustomFrames - ChatBubble.lua
-- CHAT BUBBLE: ocultar el fondo de los bocadillos del mundo + control de
-- fuente/tamaño/outline/color. Extraido de core.lua (el chunk principal excedia
-- el limite de 200 locals de Lua; mismo motivo que Glow.lua).
-- Metodo moderno (como Prat): C_ChatBubbles.GetAllChatBubbles -> :GetChildren()
-- -> .String (fontstring) + .Center/.Tail/esquinas/bordes (fondo).
-- Carga DESPUES de core.lua en el toc (usa ns.GetDB). Sin acoplamiento con el
-- ticker principal / SetUnlocked / snap (tiene su PROPIO ticker; las bubbles no
-- son elementos movibles).
-- ==========================================================================
local ADDON, ns = ...

local CHATBUBBLE_KEY = "chatbubble"
ns.CHATBUBBLE_KEY = CHATBUBBLE_KEY
ns.IsChatBubble = function(key) return key == CHATBUBBLE_KEY end

local CB_EDGES = {
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
}

local function ChatBubbleDefaults()
    return {
        enabled = true, hideBackground = true,
        fontSize = 13, font = "Fonts\\FRIZQT__.TTF", outline = "OUTLINE",
        useColor = false, color = { r = 1, g = 1, b = 1 },
    }
end
ns.ChatBubbleDefaults = ChatBubbleDefaults

local function CB_Flags(p)
    local f = p.outline or ""
    if f == "NONE" then f = "" end
    return f
end

-- Skinea una bubble (fondo + fuente/color por-bubble como refuerzo del font global).
local function CB_SkinBubble(frame, fs, p)
    if p.hideBackground then
        for _, e in ipairs(CB_EDGES) do
            if frame[e] then frame[e]:SetTexture(nil) end
        end
        if frame.Center then frame.Center:SetTexture(nil) end
        if frame.Tail then frame.Tail:SetTexture(nil) end
    end
    pcall(function() fs:SetFont(p.font or "Fonts\\FRIZQT__.TTF", p.fontSize or 13, CB_Flags(p)) end)
    if p.useColor and p.color then
        pcall(function() fs:SetTextColor(p.color.r, p.color.g, p.color.b) end)
    end
end

local function CB_IterateBubbles(fn)
    if not (C_ChatBubbles and C_ChatBubbles.GetAllChatBubbles) then return end
    local ok, list = pcall(C_ChatBubbles.GetAllChatBubbles, false)
    if not ok or type(list) ~= "table" then return end
    for _, obj in pairs(list) do
        local bubble = obj.GetChildren and obj:GetChildren() or nil
        if bubble and bubble.String and bubble.String:GetObjectType() == "FontString" then
            fn(bubble, bubble.String)
        end
    end
end

local function RefreshChatBubble()
    local db = ns.GetDB()
    if not (db and db.chatbubble) then return end
    local p = db.chatbubble
    if not p.enabled then return end
    -- Fuente/color GLOBAL (afecta a todas las bubbles via su font object).
    if ChatBubbleFont then
        pcall(function() ChatBubbleFont:SetFont(p.font or "Fonts\\FRIZQT__.TTF", p.fontSize or 13, CB_Flags(p)) end)
        if p.useColor and p.color then pcall(function() ChatBubbleFont:SetTextColor(p.color.r, p.color.g, p.color.b) end) end
    end
    CB_IterateBubbles(function(frame, fs) CB_SkinBubble(frame, fs, p) end)
end
ns.RefreshChatBubble = RefreshChatBubble

-- Ticker propio (las bubbles aparecen/desaparecen constantemente).
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(0.1, function()
        local db = ns.GetDB()
        if db and db.chatbubble and db.chatbubble.enabled then
            local p = db.chatbubble
            CB_IterateBubbles(function(frame, fs) CB_SkinBubble(frame, fs, p) end)
        end
    end)
end
