-- Profiles\Chattynator\Chattynator.lua -- copia SEGURA de CHATTYNATOR_CONFIG (perfil
-- 'Gonkast': ventanas, colores, tabs, fuente) para el sistema de Aplicar Perfiles.
-- Re-capturado Thu Jul 16 18:58:23 2026 desde el SavedVariables real de la cuenta.
-- DELIBERADAMENTE excluye CHATTYNATOR_MESSAGE_LOG (historial de chat con nombres reales de
-- otros jugadores) -- ver Profiles_Pre.lua/ProfilesApply.lua: al no setear ese global aqui,
-- ns.Profiles.CHATTYNATOR_MESSAGE_LOG queda nil y "Apply Profiles" simplemente lo saltea
-- (no se distribuye ni se sobreescribe nada de eso).
CHATTYNATOR_CONFIG = {
["CharacterSpecific"] = {
},
["Version"] = 1,
["Profiles"] = {
["DEFAULT"] = {
["store_messages"] = false,
["shorten_format"] = "letter",
["enable_message_fade"] = true,
["message_fade_time"] = 33,
["locked"] = true,
["message_spacing"] = 4,
["message_font"] = "Friz Quadrata TT",
["debug"] = false,
["show_timestamp_separator"] = true,
["force_tab_overflow"] = false,
["applied_message_ids"] = true,
["chat_colors"] = {
["CHANNEL12"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["CHANNEL6"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["CHANNEL"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["CHANNEL20"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["CHANNEL_LIST"] = {
["b"] = 0.501960813999176,
["g"] = 0.501960813999176,
["r"] = 0.7529412508010864,
},
["SYSTEM"] = {
["b"] = 0,
["g"] = 1,
["r"] = 1,
},
["RAID_BOSS_EMOTE"] = {
["b"] = 0,
["g"] = 0.8666667342185974,
["r"] = 1,
},
["CHANNEL7"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["CHANNEL_LocalDefense"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["CHANNEL1"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["VOICE_TEXT"] = {
["b"] = 0.988235354423523,
["g"] = 1,
["r"] = 0.6196078658103943,
},
["BATTLENET"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["PET_BATTLE_INFO"] = {
["b"] = 0.364705890417099,
["g"] = 0.8705883026123047,
["r"] = 0.8823530077934265,
},
["LOOT"] = {
["b"] = 0,
["g"] = 0.6666666865348816,
["r"] = 0,
},
["CHANNEL14"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["IGNORED"] = {
["b"] = 0,
["g"] = 0,
["r"] = 1,
},
["BN_WHISPER_PLAYER_OFFLINE"] = {
["b"] = 0,
["g"] = 1,
["r"] = 1,
},
["CHANNEL_General"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["YELL"] = {
["b"] = 0.250980406999588,
["g"] = 0.250980406999588,
["r"] = 1,
},
["BN_INLINE_TOAST_BROADCAST_INFORM"] = {
["b"] = 1,
["g"] = 0.7725490927696228,
["r"] = 0.5098039507865906,
},
["COMBAT_MISC_INFO"] = {
["b"] = 1,
["g"] = 0.501960813999176,
["r"] = 0.501960813999176,
},
["SAY"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["DND"] = {
["b"] = 1,
["g"] = 0.501960813999176,
["r"] = 1,
},
["GUILD_ACHIEVEMENT"] = {
["b"] = 0.250980406999588,
["g"] = 1,
["r"] = 0.250980406999588,
},
["MONSTER_PARTY"] = {
["b"] = 1,
["g"] = 0.6666666865348816,
["r"] = 0.6666666865348816,
},
["BN_INLINE_TOAST_ALERT"] = {
["b"] = 1,
["g"] = 0.7725490927696228,
["r"] = 0.5098039507865906,
},
["CHANNEL4"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["WHISPER_FOREIGN"] = {
["b"] = 1,
["g"] = 0.501960813999176,
["r"] = 1,
},
["RAID_WARNING"] = {
["b"] = 0,
["g"] = 0.2823529541492462,
["r"] = 1,
},
["BG_SYSTEM_HORDE"] = {
["b"] = 0,
["g"] = 0,
["r"] = 1,
},
["MONSTER_WHISPER"] = {
["b"] = 0.9215686917304993,
["g"] = 0.7098039388656616,
["r"] = 1,
},
["CHANNEL_JOIN"] = {
["b"] = 0.501960813999176,
["g"] = 0.501960813999176,
["r"] = 0.7529412508010864,
},
["WHISPER_INFORM"] = {
["b"] = 1,
["g"] = 0.501960813999176,
["r"] = 1,
},
["QUEST_BOSS_EMOTE"] = {
["b"] = 0.250980406999588,
["g"] = 0.501960813999176,
["r"] = 1,
},
["COMBAT_HONOR_GAIN"] = {
["b"] = 0.03921568766236305,
["g"] = 0.7921569347381592,
["r"] = 0.8784314393997192,
},
["CHANNEL5"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["TRADESKILLS"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["CHANNEL_NOTICE_USER"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 0.7529412508010864,
},
["OFFICER"] = {
["b"] = 0.250980406999588,
["g"] = 0.7529412508010864,
["r"] = 0.250980406999588,
},
["SKILL"] = {
["b"] = 1,
["g"] = 0.3333333432674408,
["r"] = 0.3333333432674408,
},
["BN_WHISPER"] = {
["b"] = 0.9647059440612793,
["g"] = 1,
["r"] = 0,
},
["BG_SYSTEM_NEUTRAL"] = {
["b"] = 0.03921568766236305,
["g"] = 0.4705882668495178,
["r"] = 1,
},
["FILTERED"] = {
["b"] = 0,
["g"] = 0,
["r"] = 1,
},
["TEXT_EMOTE"] = {
["b"] = 0.250980406999588,
["g"] = 0.501960813999176,
["r"] = 1,
},
["WHISPER"] = {
["b"] = 1,
["g"] = 0.501960813999176,
["r"] = 1,
},
["GUILD_ITEM_LOOTED"] = {
["b"] = 0.250980406999588,
["g"] = 1,
["r"] = 0.250980406999588,
},
["MONSTER_SAY"] = {
["b"] = 0.6235294342041016,
["g"] = 1,
["r"] = 1,
},
["CHANNEL15"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["GUILD"] = {
["b"] = 0.250980406999588,
["g"] = 1,
["r"] = 0.250980406999588,
},
["OPENING"] = {
["b"] = 1,
["g"] = 0.501960813999176,
["r"] = 0.501960813999176,
},
["PING"] = {
["b"] = 1,
["g"] = 0.6666666865348816,
["r"] = 0.6666666865348816,
},
["CHANNEL16"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["INSTANCE_CHAT_LEADER"] = {
["b"] = 0.03529411926865578,
["g"] = 0.2823529541492462,
["r"] = 1,
},
["COMBAT_FACTION_CHANGE"] = {
["b"] = 1,
["g"] = 0.501960813999176,
["r"] = 0.501960813999176,
},
["MONSTER_EMOTE"] = {
["b"] = 0.250980406999588,
["g"] = 0.501960813999176,
["r"] = 1,
},
["CHANNEL_LEAVE"] = {
["b"] = 0.501960813999176,
["g"] = 0.501960813999176,
["r"] = 0.7529412508010864,
},
["CHANNEL18"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["CHANNEL_Services"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["CHANNEL13"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["PET_INFO"] = {
["b"] = 1,
["g"] = 0.501960813999176,
["r"] = 0.501960813999176,
},
["CHANNEL10"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["PARTY"] = {
["b"] = 1,
["g"] = 0.6666666865348816,
["r"] = 0.6666666865348816,
},
["ARENA_POINTS"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["BN_WHISPER_INFORM"] = {
["b"] = 0.9647059440612793,
["g"] = 1,
["r"] = 0,
},
["CHANNEL11"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["EMOTE"] = {
["b"] = 0.250980406999588,
["g"] = 0.501960813999176,
["r"] = 1,
},
["COMBAT_XP_GAIN"] = {
["b"] = 1,
["g"] = 0.4352941513061523,
["r"] = 0.4352941513061523,
},
["CHANNEL9"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["CHANNEL2"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["CHANNEL8"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["BG_SYSTEM_ALLIANCE"] = {
["b"] = 0.9372549653053284,
["g"] = 0.6823529601097107,
["r"] = 0,
},
["CHANNEL19"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["PARTY_LEADER"] = {
["b"] = 1,
["g"] = 0.7843137979507446,
["r"] = 0.4627451300621033,
},
["RAID_LEADER"] = {
["b"] = 0.03529411926865578,
["g"] = 0.2823529541492462,
["r"] = 1,
},
["CHANNEL_NOTICE"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 0.7529412508010864,
},
["RAID_BOSS_WHISPER"] = {
["b"] = 0,
["g"] = 0.8666667342185974,
["r"] = 1,
},
["AFK"] = {
["b"] = 1,
["g"] = 0.501960813999176,
["r"] = 1,
},
["CHANNEL17"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["TARGETICONS"] = {
["b"] = 0,
["g"] = 1,
["r"] = 1,
},
["COMMUNITIES_CHANNEL"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["INSTANCE_CHAT"] = {
["b"] = 0,
["g"] = 0.4980392456054688,
["r"] = 1,
},
["ENCOUNTER_EVENT"] = {
["b"] = 0,
["g"] = 0.8666667342185974,
["r"] = 1,
},
["ACHIEVEMENT"] = {
["b"] = 0,
["g"] = 1,
["r"] = 1,
},
["MONEY"] = {
["b"] = 0,
["g"] = 1,
["r"] = 1,
},
["BN_INLINE_TOAST_CONVERSATION"] = {
["b"] = 1,
["g"] = 0.7725490927696228,
["r"] = 0.5098039507865906,
},
["CHANNEL3"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["BN_INLINE_TOAST_BROADCAST"] = {
["b"] = 1,
["g"] = 0.7725490927696228,
["r"] = 0.5098039507865906,
},
["RAID"] = {
["b"] = 0,
["g"] = 0.4980392456054688,
["r"] = 1,
},
["CHANNEL_Trade"] = {
["b"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["r"] = 1,
},
["PET_BATTLE_COMBAT_LOG"] = {
["b"] = 0.6705882549285889,
["g"] = 0.8705883026123047,
["r"] = 0.9058824181556702,
},
["MONSTER_YELL"] = {
["b"] = 0.250980406999588,
["g"] = 0.250980406999588,
["r"] = 1,
},
["CURRENCY"] = {
["b"] = 0,
["g"] = 0.6666666865348816,
["r"] = 0,
},
["RESTRICTED"] = {
["b"] = 0,
["g"] = 0,
["r"] = 1,
},
},
["enable_combat_messages"] = false,
["keep_edit_box_visible"] = true,
["enable_smooth_scrolling_combat"] = false,
["show_font_shadow"] = true,
["disabled_skins"] = {
},
["remove_old_messages"] = true,
["show_buttons"] = "always",
["skins"] = {
["blizzard"] = {
["tab_transparency"] = 1,
["chat_transparency"] = 1,
},
["dark"] = {
["tab_transparency"] = 1,
["chat_transparency"] = 1,
["solid_chat_background"] = true,
},
},
["applied_player_table_5"] = true,
["timestamp_format"] = " ",
["windows"] = {
{
["position"] = {
"TOPLEFT",
"UIParent",
"TOPLEFT",
26.39688873291016,
-729.7464599609375,
},
["tabs"] = {
{
["tabColor"] = "06a1ff",
["addons"] = {
},
["whispersTemp"] = {
},
["name"] = "GENERAL",
["groups"] = {
["COMBAT_MISC_INFO"] = false,
["PET_BATTLE_COMBAT_LOG"] = false,
["COMBAT_XP_GAIN"] = false,
["OPENING"] = false,
["VOICE_TEXT"] = false,
["PET_INFO"] = false,
["TRADESKILLS"] = false,
},
["invert"] = true,
["channels"] = {
},
["isTemporary"] = false,
["backgroundColor"] = "1a1a1a",
["filters"] = {
},
},
{
["tabColor"] = "309944",
["addons"] = {
},
["whispersTemp"] = {
},
["isTemporary"] = false,
["name"] = "GUILD",
["groups"] = {
["GUILD_ACHIEVEMENT"] = true,
["OFFICER"] = true,
["GUILD"] = true,
},
["channels"] = {
},
["backgroundColor"] = "1a1a1a",
["filters"] = {
},
},
},
["size"] = {
409.1748962402344,
146.7303924560547,
},
},
},
["edit_box_position"] = "bottom",
["copy_timestamps"] = true,
["whisper_sounds"] = "first",
["tab_flash_on"] = "all",
["show_tabs_1"] = "hover",
["message_font_size"] = 11,
["reduce_redundant_text"] = true,
["show_buttons_on_hover"] = false,
["current_skin"] = "blizzard",
["link_urls"] = true,
["button_position"] = "outside_tabs",
["timestamp_spacing"] = 2,
["new_whisper_new_tab"] = 0,
["combat_log_migration"] = 1,
["line_spacing_2"] = 0,
["show_combat_log"] = true,
["class_colors"] = true,
["message_font_outline"] = "none",
},
["Gonkast"] = {
["tab_flash_on"] = "all",
["shorten_format"] = "letter",
["enable_message_fade"] = true,
["message_fade_time"] = 33,
["windows"] = {
{
["size"] = {
409.1748962402344,
146.7303924560547,
},
["tabs"] = {
{
["tabColor"] = "06a1ff",
["channels"] = {
},
["whispersTemp"] = {
},
["name"] = "GENERAL",
["isTemporary"] = false,
["backgroundColor"] = "1a1a1a",
["addons"] = {
},
["groups"] = {
["COMBAT_MISC_INFO"] = false,
["OPENING"] = false,
["VOICE_TEXT"] = false,
["PET_BATTLE_COMBAT_LOG"] = false,
["COMBAT_XP_GAIN"] = false,
["PET_INFO"] = false,
["TRADESKILLS"] = false,
},
["invert"] = true,
["filters"] = {
},
},
{
["tabColor"] = "309944",
["channels"] = {
},
["whispersTemp"] = {
},
["name"] = "GUILD",
["groups"] = {
["GUILD_ACHIEVEMENT"] = true,
["OFFICER"] = true,
["GUILD"] = true,
},
["isTemporary"] = false,
["addons"] = {
},
["backgroundColor"] = "1a1a1a",
["filters"] = {
},
},
},
["position"] = {
"TOPLEFT",
"UIParent",
"TOPLEFT",
26.39688873291016,
-729.7464599609375,
},
},
},
["message_spacing"] = 4,
["message_font"] = "Friz Quadrata TT",
["debug"] = false,
["show_timestamp_separator"] = true,
["force_tab_overflow"] = false,
["applied_message_ids"] = true,
["chat_colors"] = {
["CHANNEL12"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["CHANNEL6"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["CHANNEL"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["CHANNEL20"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["CHANNEL_LIST"] = {
["r"] = 0.7529412508010864,
["g"] = 0.501960813999176,
["b"] = 0.501960813999176,
},
["SYSTEM"] = {
["r"] = 1,
["g"] = 1,
["b"] = 0,
},
["RAID_BOSS_EMOTE"] = {
["r"] = 1,
["g"] = 0.8666667342185974,
["b"] = 0,
},
["CHANNEL7"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["SKILL"] = {
["r"] = 0.3333333432674408,
["g"] = 0.3333333432674408,
["b"] = 1,
},
["CHANNEL1"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["VOICE_TEXT"] = {
["r"] = 0.6196078658103943,
["g"] = 1,
["b"] = 0.988235354423523,
},
["BATTLENET"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["PET_BATTLE_INFO"] = {
["r"] = 0.8823530077934265,
["g"] = 0.8705883026123047,
["b"] = 0.364705890417099,
},
["LOOT"] = {
["r"] = 0,
["g"] = 0.6666666865348816,
["b"] = 0,
},
["CHANNEL14"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["IGNORED"] = {
["r"] = 1,
["g"] = 0,
["b"] = 0,
},
["BN_WHISPER_PLAYER_OFFLINE"] = {
["r"] = 1,
["g"] = 1,
["b"] = 0,
},
["OFFICER"] = {
["r"] = 0.250980406999588,
["g"] = 0.7529412508010864,
["b"] = 0.250980406999588,
},
["YELL"] = {
["r"] = 1,
["g"] = 0.250980406999588,
["b"] = 0.250980406999588,
},
["BN_INLINE_TOAST_BROADCAST_INFORM"] = {
["r"] = 0.5098039507865906,
["g"] = 0.7725490927696228,
["b"] = 1,
},
["COMBAT_MISC_INFO"] = {
["r"] = 0.501960813999176,
["g"] = 0.501960813999176,
["b"] = 1,
},
["BN_WHISPER"] = {
["r"] = 0,
["g"] = 1,
["b"] = 0.9647059440612793,
},
["DND"] = {
["r"] = 1,
["g"] = 0.501960813999176,
["b"] = 1,
},
["GUILD_ACHIEVEMENT"] = {
["r"] = 0.250980406999588,
["g"] = 1,
["b"] = 0.250980406999588,
},
["MONSTER_PARTY"] = {
["r"] = 0.6666666865348816,
["g"] = 0.6666666865348816,
["b"] = 1,
},
["BN_INLINE_TOAST_ALERT"] = {
["r"] = 0.5098039507865906,
["g"] = 0.7725490927696228,
["b"] = 1,
},
["CHANNEL4"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["WHISPER_FOREIGN"] = {
["r"] = 1,
["g"] = 0.501960813999176,
["b"] = 1,
},
["RAID_WARNING"] = {
["r"] = 1,
["g"] = 0.2823529541492462,
["b"] = 0,
},
["BG_SYSTEM_HORDE"] = {
["r"] = 1,
["g"] = 0,
["b"] = 0,
},
["MONSTER_WHISPER"] = {
["r"] = 1,
["g"] = 0.7098039388656616,
["b"] = 0.9215686917304993,
},
["CHANNEL_JOIN"] = {
["r"] = 0.7529412508010864,
["g"] = 0.501960813999176,
["b"] = 0.501960813999176,
},
["WHISPER_INFORM"] = {
["r"] = 1,
["g"] = 0.501960813999176,
["b"] = 1,
},
["QUEST_BOSS_EMOTE"] = {
["r"] = 1,
["g"] = 0.501960813999176,
["b"] = 0.250980406999588,
},
["COMBAT_HONOR_GAIN"] = {
["r"] = 0.8784314393997192,
["g"] = 0.7921569347381592,
["b"] = 0.03921568766236305,
},
["CHANNEL5"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["TRADESKILLS"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["RESTRICTED"] = {
["r"] = 1,
["g"] = 0,
["b"] = 0,
},
["SAY"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["CHANNEL_General"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["MONSTER_SAY"] = {
["r"] = 1,
["g"] = 1,
["b"] = 0.6235294342041016,
},
["CHANNEL_Trade"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["MONEY"] = {
["r"] = 1,
["g"] = 1,
["b"] = 0,
},
["TEXT_EMOTE"] = {
["r"] = 1,
["g"] = 0.501960813999176,
["b"] = 0.250980406999588,
},
["WHISPER"] = {
["r"] = 1,
["g"] = 0.501960813999176,
["b"] = 1,
},
["GUILD_ITEM_LOOTED"] = {
["r"] = 0.250980406999588,
["g"] = 1,
["b"] = 0.250980406999588,
},
["CHANNEL_LocalDefense"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["RAID"] = {
["r"] = 1,
["g"] = 0.4980392456054688,
["b"] = 0,
},
["GUILD"] = {
["r"] = 0.250980406999588,
["g"] = 1,
["b"] = 0.250980406999588,
},
["OPENING"] = {
["r"] = 0.501960813999176,
["g"] = 0.501960813999176,
["b"] = 1,
},
["PING"] = {
["r"] = 0.6666666865348816,
["g"] = 0.6666666865348816,
["b"] = 1,
},
["INSTANCE_CHAT_LEADER"] = {
["r"] = 1,
["g"] = 0.2823529541492462,
["b"] = 0.03529411926865578,
},
["BG_SYSTEM_NEUTRAL"] = {
["r"] = 1,
["g"] = 0.4705882668495178,
["b"] = 0.03921568766236305,
},
["COMBAT_FACTION_CHANGE"] = {
["r"] = 0.501960813999176,
["g"] = 0.501960813999176,
["b"] = 1,
},
["MONSTER_EMOTE"] = {
["r"] = 1,
["g"] = 0.501960813999176,
["b"] = 0.250980406999588,
},
["CHANNEL_LEAVE"] = {
["r"] = 0.7529412508010864,
["g"] = 0.501960813999176,
["b"] = 0.501960813999176,
},
["CHANNEL_Services"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["CHANNEL18"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["CHANNEL16"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["PET_INFO"] = {
["r"] = 0.501960813999176,
["g"] = 0.501960813999176,
["b"] = 1,
},
["CHANNEL10"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["ACHIEVEMENT"] = {
["r"] = 1,
["g"] = 1,
["b"] = 0,
},
["ARENA_POINTS"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["BN_WHISPER_INFORM"] = {
["r"] = 0,
["g"] = 1,
["b"] = 0.9647059440612793,
},
["CHANNEL11"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["EMOTE"] = {
["r"] = 1,
["g"] = 0.501960813999176,
["b"] = 0.250980406999588,
},
["COMBAT_XP_GAIN"] = {
["r"] = 0.4352941513061523,
["g"] = 0.4352941513061523,
["b"] = 1,
},
["INSTANCE_CHAT"] = {
["r"] = 1,
["g"] = 0.4980392456054688,
["b"] = 0,
},
["CHANNEL2"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["COMMUNITIES_CHANNEL"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["BG_SYSTEM_ALLIANCE"] = {
["r"] = 0,
["g"] = 0.6823529601097107,
["b"] = 0.9372549653053284,
},
["CHANNEL19"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["PARTY_LEADER"] = {
["r"] = 0.4627451300621033,
["g"] = 0.7843137979507446,
["b"] = 1,
},
["AFK"] = {
["r"] = 1,
["g"] = 0.501960813999176,
["b"] = 1,
},
["CHANNEL_NOTICE"] = {
["r"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["RAID_BOSS_WHISPER"] = {
["r"] = 1,
["g"] = 0.8666667342185974,
["b"] = 0,
},
["RAID_LEADER"] = {
["r"] = 1,
["g"] = 0.2823529541492462,
["b"] = 0.03529411926865578,
},
["CHANNEL17"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["TARGETICONS"] = {
["r"] = 1,
["g"] = 1,
["b"] = 0,
},
["CHANNEL8"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["CHANNEL9"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["ENCOUNTER_EVENT"] = {
["r"] = 1,
["g"] = 0.8666667342185974,
["b"] = 0,
},
["PARTY"] = {
["r"] = 0.6666666865348816,
["g"] = 0.6666666865348816,
["b"] = 1,
},
["CHANNEL13"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["BN_INLINE_TOAST_CONVERSATION"] = {
["r"] = 0.5098039507865906,
["g"] = 0.7725490927696228,
["b"] = 1,
},
["CHANNEL3"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["BN_INLINE_TOAST_BROADCAST"] = {
["r"] = 0.5098039507865906,
["g"] = 0.7725490927696228,
["b"] = 1,
},
["CHANNEL15"] = {
["r"] = 1,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
["FILTERED"] = {
["r"] = 1,
["g"] = 0,
["b"] = 0,
},
["PET_BATTLE_COMBAT_LOG"] = {
["r"] = 0.9058824181556702,
["g"] = 0.8705883026123047,
["b"] = 0.6705882549285889,
},
["MONSTER_YELL"] = {
["r"] = 1,
["g"] = 0.250980406999588,
["b"] = 0.250980406999588,
},
["CURRENCY"] = {
["r"] = 0,
["g"] = 0.6666666865348816,
["b"] = 0,
},
["CHANNEL_NOTICE_USER"] = {
["r"] = 0.7529412508010864,
["g"] = 0.7529412508010864,
["b"] = 0.7529412508010864,
},
},
["reduce_redundant_text"] = true,
["show_tabs_1"] = "hover",
["enable_smooth_scrolling_combat"] = false,
["show_font_shadow"] = true,
["disabled_skins"] = {
},
["message_font_outline"] = "none",
["whisper_sounds"] = "first",
["class_colors"] = true,
["show_combat_log"] = true,
["skins"] = {
["blizzard"] = {
["chat_transparency"] = 1,
["tab_transparency"] = 1,
},
["dark"] = {
["solid_chat_background"] = true,
["chat_transparency"] = 1,
["tab_transparency"] = 1,
},
},
["locked"] = true,
["edit_box_position"] = "bottom",
["show_buttons"] = "hover",
["combat_log_migration"] = 1,
["store_messages"] = false,
["keep_edit_box_visible"] = true,
["link_urls"] = true,
["enable_combat_messages"] = false,
["show_buttons_on_hover"] = false,
["current_skin"] = "blizzard",
["message_font_size"] = 11,
["button_position"] = "outside_left",
["timestamp_spacing"] = 2,
["new_whisper_new_tab"] = 0,
["copy_timestamps"] = true,
["line_spacing_2"] = 0,
["applied_player_table_5"] = true,
["timestamp_format"] = " ",
["remove_old_messages"] = true,
},
},
}
