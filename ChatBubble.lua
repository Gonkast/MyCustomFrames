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

-- FIX RONDA 5 (2026-07-16): el usuario identifico el asset real -- "Interface\Tooltips\..." es
-- el path CLASICO de `SetBackdrop` (bgFile). Un fondo pintado por SetBackdrop se renderiza
-- INTERNAMENTE (C++) y NUNCA aparece como una region Texture accesible via GetRegions()/
-- GetChildren() en Lua -- por eso ninguna de las rondas anteriores (por nombre de campo, ni
-- recorrido recursivo de regiones) podia encontrarlo NUNCA, sin importar cuanto se recorriera.
-- El fix real es limpiar el BACKDROP en si: SetBackdrop(nil) + colores a alpha 0 como refuerzo.
local function CB_ClearBackgroundTextures(frame, depth)
    if not frame or (depth or 0) > 4 then return end
    if frame.SetBackdrop then
        pcall(frame.SetBackdrop, frame, nil)
    end
    if frame.SetBackdropColor then pcall(frame.SetBackdropColor, frame, 0, 0, 0, 0) end
    if frame.SetBackdropBorderColor then pcall(frame.SetBackdropBorderColor, frame, 0, 0, 0, 0) end
    if frame.GetNumRegions then
        for i = 1, frame:GetNumRegions() do
            local r = select(i, frame:GetRegions())
            if r and r.GetObjectType and r:GetObjectType() == "Texture" then
                r:SetTexture(nil)
                if r.SetAtlas then pcall(r.SetAtlas, r, nil) end
                r:SetAlpha(0)
            end
        end
    end
    if frame.GetNumChildren then
        for i = 1, frame:GetNumChildren() do
            local child = select(i, frame:GetChildren())
            if child then CB_ClearBackgroundTextures(child, (depth or 0) + 1) end
        end
    end
end

-- OPTIMIZACION (2026-07-16, auditoria): antes se reaplicaba SetFont/SetTextColor/backdrop a
-- TODAS las bubbles visibles en CADA tick de 0.1s (10x/seg), aunque nada hubiera cambiado —
-- ademas cada llamada envolvia un pcall(function() ... end), que ASIGNA UNA CLOSURE NUEVA por
-- llamada (basura de GC constante). Mismo patron de cache que fsState en Tracker.lua: por-bubble
-- (tabla EXTERNA weak-keyed, nunca escribimos claves propias sobre frames de Blizzard) se guarda
-- el TEXTO actual + el epoch de config; si ninguno cambio desde el tick anterior, se saltea todo
-- el trabajo. Las bubbles son frames pooled que Blizzard reutiliza para mensajes nuevos, por eso
-- el texto (no solo la config) tambien es parte de la clave de cache.
local bubbleState = setmetatable({}, { __mode = "k" })   -- outer -> { text, epoch }
local configEpoch = 0

local function CB_SkinBubble(outer, frame, fs, p)
    local text = fs:GetText()
    local st = bubbleState[outer]
    if st and st.text == text and st.epoch == configEpoch then return end
    if not st then st = {}; bubbleState[outer] = st end
    st.text, st.epoch = text, configEpoch

    if p.hideBackground then
        CB_ClearBackgroundTextures(outer)
    end
    pcall(fs.SetFont, fs, p.font or "Fonts\\FRIZQT__.TTF", p.fontSize or 13, CB_Flags(p))
    if p.useColor and p.color then
        pcall(fs.SetTextColor, fs, p.color.r, p.color.g, p.color.b)
    end
end

-- RONDA 3 (2026-07-16): se probo combinar GetAllChatBubbles(false) + (true) para cubrir bubbles
-- de NPC en calabozos, pero `true` en este cliente devuelve basura (literalmente WorldFrame,
-- confirmado con el error "bad argument #1 ... Usage: GetChildren()" al intentar iterar sus
-- miles de hijos) — se descarta esa via, vuelta a solo `false` (la que sí funciona).
-- PERF (2026-07-19, "arregla todo"): `extra` se pasa DIRECTO a fn (en vez de
-- que el llamador tenga que armar una closure `function(...) ... p end` para
-- capturar `p`) -- ambos call sites de abajo ahora pasan CB_SkinBubble tal
-- cual, sin closure nueva en cada tick del ticker de 0.1s.
local function CB_IterateBubbles(fn, extra)
    if not (C_ChatBubbles and C_ChatBubbles.GetAllChatBubbles) then return end
    local ok, list = pcall(C_ChatBubbles.GetAllChatBubbles, false)
    if not ok or type(list) ~= "table" then return end
    for _, obj in pairs(list) do
        local bubble = obj.GetChildren and obj:GetChildren() or nil
        if bubble and bubble.String and bubble.String:GetObjectType() == "FontString" then
            fn(obj, bubble, bubble.String, extra)
        end
    end
end

local function RefreshChatBubble()
    local db = ns.GetDB()
    if not (db and db.chatbubble) then return end
    local p = db.chatbubble
    if not p.enabled then return end
    configEpoch = configEpoch + 1   -- invalida la cache de CB_SkinBubble (cambio config)
    -- Fuente/color GLOBAL (afecta a todas las bubbles via su font object).
    if ChatBubbleFont then
        pcall(ChatBubbleFont.SetFont, ChatBubbleFont, p.font or "Fonts\\FRIZQT__.TTF", p.fontSize or 13, CB_Flags(p))
        if p.useColor and p.color then pcall(ChatBubbleFont.SetTextColor, ChatBubbleFont, p.color.r, p.color.g, p.color.b) end
    end
    CB_IterateBubbles(CB_SkinBubble, p)
end
ns.RefreshChatBubble = RefreshChatBubble

-- Ticker propio (las bubbles aparecen/desaparecen constantemente).
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(0.1, function()
        local db = ns.GetDB()
        if db and db.chatbubble and db.chatbubble.enabled then
            CB_IterateBubbles(CB_SkinBubble, db.chatbubble)
        end
    end)
end
