--[[Perfy has instrumented this file]] local Perfy_GetTime, Perfy_Trace, Perfy_Trace_Passthrough = Perfy_GetTime, Perfy_Trace, Perfy_Trace_Passthrough; Perfy_Trace(Perfy_GetTime(), "Enter", "(main chunk) MyCustomFrames/Profiles/Bartender4/Bartender4.lua");
Bartender4DB = {
["namespaces"] = {
["ActionBars"] = {
["profiles"] = {
["Default"] = {
["actionbars"] = {
[1] = {
["WoW10Layout"] = true,
["elements"] = {
["count"] = {
["font"] = "Friz Quadrata TT",
["fontColor"] = {
[2] = 0.88235300779342651,
[3] = 0.60784316062927246,
},
["fontSize"] = 21,
["textAnchor"] = "CENTER",
["textJustifyH"] = "CENTER",
["textOffsetX"] = 2,
["textOffsetY"] = 2,
},
["hotkey"] = {
["font"] = "Friz Quadrata TT",
["fontColor"] = {
[1] = 1,
[2] = 0.88235300779342651,
[3] = 0.60784316062927246,
},
["textAnchor"] = "TOP",
["textOffsetX"] = 10,
["textOffsetY"] = 10,
},
["macro"] = {
["fontColor"] = {
[2] = 0.88235300779342651,
[3] = 0.60784316062927246,
},
},
},
["fadeoutalpha"] = 0,
["fadeoutdelay"] = 0,
["padding"] = 17,
["position"] = {
["point"] = "BOTTOM",
["scale"] = 0.67000001668930054,
["x"] = -250,
["y"] = 213,
},
["rows"] = 2,
["showgrid"] = true,
["states"] = {
["actionbar"] = true,
},
["version"] = 3,
["visibility"] = {
["custom"] = false,
["customdata"] = "[@player,dead] fade; [overridebar][possessbar][bonusbar][vehicleui] hide; [mounted] hide; [@target,dead] hide; [combat][@target,exists,harm][@focus,exists] show; fade\
",
},
},
[2] = {
["WoW10Layout"] = true,
["enabled"] = false,
["position"] = {
["point"] = "CENTER",
["x"] = -284.50003051757812,
["y"] = -224,
},
["version"] = 3,
},
[3] = {
["WoW10Layout"] = true,
["buttons"] = 4,
["elements"] = {
["count"] = {
["font"] = "Friz Quadrata TT",
["fontColor"] = {
[2] = 0.88235300779342651,
[3] = 0.60784316062927246,
},
["fontSize"] = 18,
},
["hotkey"] = {
["font"] = "Friz Quadrata TT",
["fontColor"] = {
[1] = 1,
[2] = 0.88235300779342651,
[3] = 0.60784316062927246,
},
["fontSize"] = 18,
["textOffsetX"] = 10,
["textOffsetY"] = 10,
},
["macro"] = {
["fontColor"] = {
[2] = 0.88235300779342651,
[3] = 0.60784316062927246,
},
["fontSize"] = 14,
},
},
["enabled"] = false,
["fadeoutalpha"] = 0,
["fadeoutdelay"] = 0,
["flyoutDirection"] = "LEFT",
["padding"] = 20,
["position"] = {
["point"] = "CENTER",
["scale"] = 0.60000002384185791,
["x"] = 436.75003108779492,
["y"] = 80.823462169304548,
},
["rows"] = 6,
["showgrid"] = true,
["states"] = {
["actionbar"] = true,
["custom"] = "[pet] petbar; actionbar:1\
\
",
["customEnabled"] = true,
["default"] = 14,
["possess"] = true,
},
["version"] = 3,
["visibility"] = {
["custom"] = false,
["customdata"] = "[@player,dead] fade; [overridebar][possessbar][bonusbar][vehicleui] hide; [mounted] hide; [@target,dead] hide; [combat][@target,exists,harm][@focus,exists] show; fade\
",
["nopet"] = false,
},
},
[4] = {
["WoW10Layout"] = true,
["enabled"] = false,
["flyoutDirection"] = "LEFT",
["position"] = {
["point"] = "RIGHT",
["x"] = -104,
["y"] = 193,
},
["rows"] = 12,
["version"] = 3,
},
[5] = {
["WoW10Layout"] = true,
["buttons"] = 8,
["elements"] = {
["count"] = {
["font"] = "Friz Quadrata TT",
},
["hotkey"] = {
["font"] = "Friz Quadrata TT",
},
},
["enabled"] = false,
["fadeoutdelay"] = 0,
["padding"] = 17,
["position"] = {
["point"] = "CENTER",
["scale"] = 0.67000001668930054,
["x"] = 467.99977556085651,
["y"] = 41.00003827607361,
},
["rows"] = 2,
["showgrid"] = true,
["states"] = {
["enabled"] = true,
},
["version"] = 3,
["visibility"] = {
["custom"] = false,
["customdata"] = "[overridebar][possessbar][bonusbar:5d]show; hide",
},
},
[6] = {
["WoW10Layout"] = true,
["elements"] = {
["count"] = {
["font"] = "Friz Quadrata TT",
["fontSize"] = 24,
},
["hotkey"] = {
["font"] = "Friz Quadrata TT",
["fontColor"] = {
[1] = 1,
[2] = 0.88235300779342651,
[3] = 0.60784316062927246,
},
["fontSize"] = 15,
["textOffsetX"] = 10,
["textOffsetY"] = 10,
},
},
["fadeoutalpha"] = 0,
["fadeoutdelay"] = 0,
["padding"] = 17,
["position"] = {
["point"] = "BOTTOM",
["scale"] = 0.67000001668930054,
["x"] = 4,
["y"] = 213,
},
["rows"] = 2,
["showgrid"] = true,
["version"] = 3,
["visibility"] = {
["custom"] = false,
["customdata"] = "[@player,dead] fade; [overridebar][possessbar][bonusbar][vehicleui] hide; [mounted] hide; [@target,dead] hide; [combat][@target,exists,harm][@focus,exists] show; fade\
\
\
",
["overridebar"] = false,
["vehicleui"] = false,
},
},
[7] = {
["WoW10Layout"] = true,
["position"] = {
["point"] = "CENTER",
["x"] = -284.5,
["y"] = -223.99981689453131,
},
["version"] = 3,
},
[8] = {
["WoW10Layout"] = true,
},
[9] = {
["WoW10Layout"] = true,
},
[10] = {
["WoW10Layout"] = true,
},
[13] = {
["WoW10Layout"] = true,
["position"] = {
["point"] = "CENTER",
["x"] = -284.5,
["y"] = -223.99981689453131,
},
["version"] = 3,
},
[14] = {
["WoW10Layout"] = true,
["position"] = {
["point"] = "CENTER",
["x"] = -284.5,
["y"] = -223.99981689453131,
},
["version"] = 3,
},
[15] = {
["WoW10Layout"] = true,
["position"] = {
["point"] = "CENTER",
["x"] = -284.5,
["y"] = -223.99981689453131,
},
["version"] = 3,
},
},
},
},
},
["BagBar"] = {
["profiles"] = {
["Default"] = {
["onebag"] = true,
["onebagreagents"] = false,
["position"] = {
["point"] = "BOTTOMRIGHT",
["scale"] = 0.85000002384185791,
["x"] = -139.51848033227731,
["y"] = 185.99769885112801,
},
["version"] = 3,
},
},
},
["BlizzardArt"] = {
["profiles"] = {
["Default"] = {
["artLayout"] = "TWOBAR",
["position"] = {
["point"] = "BOTTOM",
["scale"] = 0.70000000000000007,
["x"] = -288.5,
["y"] = 87,
},
["version"] = 3,
},
},
},
["ExtraActionBar"] = {
["profiles"] = {
["Default"] = {
["fadeoutalpha"] = 0.65000000000000002,
["position"] = {
["point"] = "BOTTOMRIGHT",
["scale"] = 0.69999998807907104,
["x"] = -321.65000280567619,
["y"] = 209.64999642968181,
},
["version"] = 3,
["visibility"] = {
["always"] = false,
["custom"] = true,
["customdata"] = "[@player,dead] fade; [overridebar][possessbar][bonusbar][vehicleui] hide; [mounted] hide; [@target,dead] hide; [combat][@target,exists,harm][@focus,exists] show; fade\
",
["nocombat"] = true,
},
},
},
},
["LibDualSpec-1.0"] = {
["char"] = {
},
},
["MicroMenu"] = {
["profiles"] = {
["Default"] = {
["enabled"] = false,
["position"] = {
["point"] = "LEFT",
["scale"] = 1.5,
["x"] = 43.879983901977539,
["y"] = 35.250007629394531,
},
["version"] = 3,
},
},
},
["PetBar"] = {
["profiles"] = {
["Default"] = {
["fadeoutalpha"] = 0,
["padding"] = 10,
["position"] = {
["point"] = "BOTTOM",
["scale"] = 0.95000000000000007,
["x"] = -189.04994201660159,
["y"] = 259.57437972030681,
},
["showgrid"] = true,
["version"] = 3,
["visibility"] = {
["custom"] = false,
["customdata"] = "[overridebar][possessbar][bonusbar][vehicleui] hide; [mounted] hide; [nopet] hide; [pet,@target,dead] hide; [pet,combat][pet,@target,exists,harm][pet,@focus,exists] show; fade\
\
",
["nopet"] = false,
["overridebar"] = false,
["possess"] = true,
["vehicle"] = false,
["vehicleui"] = false,
},
},
},
},
["QueueStatus"] = {
["profiles"] = {
["Default"] = {
["enabled"] = false,
["position"] = {
["point"] = "RIGHT",
["scale"] = 0.69999998807907104,
["x"] = -214.64087740170359,
["y"] = -230.06737385362609,
},
["version"] = 3,
},
},
},
["StanceBar"] = {
["profiles"] = {
["Default"] = {
["fadeoutalpha"] = 0,
["padding"] = 9,
["position"] = {
["point"] = "BOTTOM",
["scale"] = 1.1000000000000001,
["x"] = -63.800008392333993,
["y"] = 265.25073075496039,
},
["version"] = 3,
["visibility"] = {
["custom"] = false,
["customdata"] = "[@player,dead] fade; [overridebar][possessbar][bonusbar][vehicleui] hide; [mounted] hide; [@target,dead] hide; [combat][@target,exists,harm][@focus,exists] show; fade\
\
\
",
},
},
},
},
["StatusTrackingBar"] = {
["profiles"] = {
["Default"] = {
["position"] = {
["point"] = "BOTTOM",
["x"] = -289.5,
["y"] = 29,
},
["version"] = 3,
},
},
},
["Vehicle"] = {
["profiles"] = {
["Default"] = {
["enabled"] = false,
["position"] = {
["point"] = "BOTTOM",
["scale"] = 0.75,
["x"] = -271.95166015625,
["y"] = 71.478567123413086,
},
["version"] = 3,
},
},
},
},
["profileKeys"] = {
},
["profiles"] = {
["Default"] = {
["blizzardVehicle"] = true,
["focuscastmodifier"] = false,
["minimapIcon"] = {
["hide"] = false,
["minimapPos"] = 175.30623380993549,
},
["outofrange"] = "hotkey",
["snapping"] = false,
},
},
}

Perfy_Trace(Perfy_GetTime(), "Leave", "(main chunk) MyCustomFrames/Profiles/Bartender4/Bartender4.lua");