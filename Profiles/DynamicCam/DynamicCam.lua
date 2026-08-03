
DynamicCamDB = {
  ["global"] = {
    ["popOutFrame"] = {
      ["height"] = 720.00018310547,
      ["left"] = 1024.9997558594,
      ["opacity"] = 0,
      ["top"] = 973.59295654297,
    },
  },
  ["profiles"] = {
    ["Default"] = {
      ["situations"] = {
        ["001"] = {
          ["priority"] = 200,
          ["situationSettings"] = {
            ["cvars"] = {
              ["test_cameraOverShoulder"] = 0,
            },
          },
        },
        ["020"] = {
          ["enabled"] = true,
          ["priority"] = 180,
          ["situationSettings"] = {
            ["cvars"] = {
              ["test_cameraOverShoulder"] = 0,
            },
            ["cvarsZoomBased"] = {
              ["test_cameraOverShoulder"] = {
                ["enabled"] = false,
                ["points"] = {
                  [1] = {
                    ["value"] = 0,
                    ["zoom"] = 0,
                  },
                  [2] = {
                    ["value"] = 0,
                    ["zoom"] = 39,
                  },
                },
              },
            },
            ["shoulderOffsetZoomEnabled"] = true,
            ["shoulderOffsetZoomLowerBound"] = 0.9,
            ["shoulderOffsetZoomUpperBound"] = 7,
          },
          ["transitionTime"] = {
            ["timeToEnter"] = 0.5,
            ["timeToExit"] = 0.5,
          },
        },
        ["021"] = {
          ["enabled"] = true,
        },
        ["050"] = {
          ["enabled"] = true,
          ["priority"] = 170,
          ["situationSettings"] = {
            ["cvars"] = {
              ["test_cameraOverShoulder"] = 0,
            },
            ["shoulderOffsetZoomEnabled"] = true,
            ["shoulderOffsetZoomLowerBound"] = 0.8,
            ["shoulderOffsetZoomUpperBound"] = 10,
          },
          ["transitionTime"] = {
            ["timeToEnter"] = 0.5,
            ["timeToExit"] = 0.5,
          },
        },
        ["060"] = {
          ["enabled"] = true,
          ["priority"] = 190,
          ["situationSettings"] = {
            ["cvars"] = {
              ["test_cameraOverShoulder"] = 0,
            },
            ["shoulderOffsetZoomEnabled"] = true,
            ["shoulderOffsetZoomLowerBound"] = 0.8,
            ["shoulderOffsetZoomUpperBound"] = 10,
          },
          ["transitionTime"] = {
            ["timeToEnter"] = 0.5,
            ["timeToExit"] = 0.5,
          },
        },
        ["100"] = {
          ["enabled"] = true,
          ["priority"] = 200,
          ["situationSettings"] = {
            ["cvars"] = {
              ["cameraFov"] = 90,
              ["test_cameraDynamicPitch"] = 1,
              ["test_cameraDynamicPitchBaseFovPad"] = 0.99,
              ["test_cameraDynamicPitchBaseFovPadDownScale"] = 1,
              ["test_cameraDynamicPitchBaseFovPadFlying"] = 1,
              ["test_cameraDynamicPitchSmartPivotCutoffDist"] = 39,
              ["test_cameraOverShoulder"] = 1.7,
            },
            ["cvarsZoomBased"] = {
              ["test_cameraOverShoulder"] = {
                ["enabled"] = true,
                ["points"] = {
                  [1] = {
                    ["value"] = 1.7,
                    ["zoom"] = 0,
                  },
                  [2] = {
                    ["value"] = 1.7,
                    ["zoom"] = 39,
                  },
                },
              },
            },
            ["shoulderOffsetZoomEnabled"] = true,
            ["shoulderOffsetZoomLowerBound"] = 2,
            ["shoulderOffsetZoomUpperBound"] = 7,
          },
          ["viewZoom"] = {
            ["viewZoomType"] = "view",
          },
        },
        ["106"] = {
          ["situationSettings"] = {
            ["cvars"] = {
              ["test_cameraOverShoulder"] = 7.9,
            },
            ["cvarsZoomBased"] = {
              ["test_cameraOverShoulder"] = {
                ["enabled"] = true,
                ["points"] = {
                  [1] = {
                    ["value"] = 0,
                    ["zoom"] = 0,
                  },
                  [2] = {
                    ["value"] = 0,
                    ["zoom"] = 0.8,
                  },
                  [3] = {
                    ["value"] = 7.9,
                    ["zoom"] = 10,
                  },
                  [4] = {
                    ["value"] = 7.9,
                    ["zoom"] = 39,
                  },
                },
              },
            },
            ["shoulderOffsetZoomEnabled"] = true,
            ["shoulderOffsetZoomLowerBound"] = 0.9,
            ["shoulderOffsetZoomUpperBound"] = 7,
          },
          ["transitionTime"] = {
            ["timeToEnter"] = 0,
            ["timeToExit"] = 0,
          },
        },
        ["115"] = {
          ["enabled"] = true,
          ["priority"] = 500,
          ["situationSettings"] = {
            ["cvars"] = {
              ["test_cameraOverShoulder"] = 0.3,
            },
          },
          ["transitionTime"] = {
            ["timeToEnter"] = 1.5,
            ["timeToExit"] = 1.5,
          },
        },
        ["170"] = {
          ["situationSettings"] = {
            ["cvars"] = {
              ["cameraDistanceMaxZoomFactor"] = 1.9,
              ["cameraPitchMoveSpeed"] = 90,
              ["cameraYawMoveSpeed"] = 180,
              ["cameraZoomSpeed"] = 20,
              ["test_cameraDynamicPitch"] = 1,
              ["test_cameraDynamicPitchBaseFovPad"] = 0.31,
              ["test_cameraDynamicPitchBaseFovPadDownScale"] = 0.67,
              ["test_cameraDynamicPitchBaseFovPadFlying"] = 0,
              ["test_cameraDynamicPitchSmartPivotCutoffDist"] = 11,
              ["test_cameraOverShoulder"] = 1.5,
            },
            ["cvarsZoomBased"] = {
              ["test_cameraOverShoulder"] = {
                ["enabled"] = true,
                ["points"] = {
                  [1] = {
                    ["value"] = 0,
                    ["zoom"] = 0,
                  },
                  [2] = {
                    ["value"] = 0,
                    ["zoom"] = 0.8,
                  },
                  [3] = {
                    ["value"] = 1.5,
                    ["zoom"] = 10,
                  },
                  [4] = {
                    ["value"] = 1.5,
                    ["zoom"] = 39,
                  },
                },
              },
            },
            ["reactiveZoomAddIncrements"] = 2.5,
            ["reactiveZoomAddIncrementsAlways"] = 1,
            ["reactiveZoomEnabled"] = true,
            ["reactiveZoomIncAddDifference"] = 1.2,
            ["reactiveZoomMaxZoomTime"] = 0.1,
            ["shoulderOffsetZoomEnabled"] = true,
            ["shoulderOffsetZoomLowerBound"] = 0.8,
            ["shoulderOffsetZoomUpperBound"] = 6.9,
          },
          ["transitionTime"] = {
            ["timeToEnter"] = 0,
            ["timeToExit"] = 0,
          },
        },
        ["300"] = {
          ["executeOnInit"] = "this.frames = {\
  \"AuctionHouseFrame\",\
  \"BagnonBankFrame1\",\
  \"BankFrame\",\
  \"ClassTrainerFrame\",\
  \"GarrisonCapacitiveDisplayFrame\",\
  \"GossipFrame\",\
  \"GuildRegistrarFrame\",\
  \"ImmersionFrame\",\
  \"MerchantFrame\",\
  \"PetStableFrame\",\
  \"QuestFrame\",\
  \"TabardFrame\",\
  \"WardrobeFrame\",\
  \"DUIQuestFrame\" -- añadido\
}\
\
this.excludedFrames = {\"FlightMapFrame\"}\
\
this.mountVendors = {\
  [\"62821\"] = 460, -- Grand Expedition Yak\
  [\"62822\"] = 460, -- Grand Expedition Yak\
  [\"227773\"] = 2237, -- Grizzly Hills Packmaster\
  [\"227774\"] = 2237, -- Grizzly Hills Packmaster\
  [\"231085\"] = 2265, -- Trader's Gilded Brutosaur\
  -- Add more npcId and mountId pairs here.\
  -- To find them, uncomment print command in condition script.\
}\
",
          ["hideUI"] = {
            ["customFramesToKeep"] = {
              ["SortedPrimaryFrame"] = true,
              ["WeakAurasFrame"] = true,
            },
            ["fadeOpacity"] = 0,
            ["keepChatFrame"] = true,
            ["keepCustomFrames"] = true,
            ["keepEncounterBar"] = true,
            ["keepMinimap"] = true,
            ["keepPartyRaidFrame"] = true,
            ["keepTrackingBar"] = true,
          },
          ["situationSettings"] = {
            ["cvars"] = {
              ["cameraDistanceMaxZoomFactor"] = 2.6,
              ["cameraZoomSpeed"] = 50,
              ["test_cameraOverShoulder"] = 5.6,
            },
            ["reactiveZoomAddIncrements"] = 2.5,
            ["reactiveZoomAddIncrementsAlways"] = 1,
            ["reactiveZoomEnabled"] = true,
            ["reactiveZoomIncAddDifference"] = 1.2,
            ["reactiveZoomMaxZoomTime"] = 0.1,
            ["shoulderOffsetZoomEnabled"] = true,
            ["shoulderOffsetZoomLowerBound"] = 0.8,
            ["shoulderOffsetZoomUpperBound"] = 10,
          },
          ["transitionTime"] = {
            ["timeToEnter"] = 0,
            ["timeToExit"] = 0,
          },
        },
        ["custom10"] = {
          ["condition"] = "if C_Housing and C_Housing.IsInsideHouseOrPlot() then\
    -- Intentamos verificar si el modo edición está activo mediante una \
    -- función lógica de la API de Housing que detectaste\
    if C_Housing.CanEditCharter() then\
        return true\
    end\
end\
return false",
          ["delay"] = 0,
          ["enabled"] = false,
          ["events"] = {
          },
          ["executeOnEnter"] = "",
          ["executeOnExit"] = "",
          ["executeOnInit"] = "",
          ["hideUI"] = {
            ["customFramesToKeep"] = {
              ["AuctionHouseFrame"] = true,
              ["BagnonBankFrame1"] = true,
              ["BankFrame"] = true,
              ["BuffFrame"] = true,
              ["ClassTrainerFrame"] = true,
              ["DebuffFrame"] = true,
              ["GossipFrame"] = true,
              ["MerchantFrame"] = true,
              ["PetStableFrame"] = true,
              ["QuestFrame"] = true,
              ["StaticPopup1"] = true,
              ["WardrobeFrame"] = true,
            },
            ["emergencyShowEscEnabled"] = true,
            ["enabled"] = false,
            ["fadeOpacity"] = 0.6,
            ["hideEntireUI"] = false,
            ["keepAlertFrames"] = true,
            ["keepChatFrame"] = false,
            ["keepCustomFrames"] = false,
            ["keepEncounterBar"] = false,
            ["keepFrameRate"] = false,
            ["keepMinimap"] = false,
            ["keepPartyRaidFrame"] = false,
            ["keepTooltip"] = true,
            ["keepTrackingBar"] = false,
          },
          ["name"] = "Housing",
          ["priority"] = 500,
          ["rotation"] = {
            ["enabled"] = false,
            ["pitchDegrees"] = 0,
            ["rotateBack"] = true,
            ["rotationSpeed"] = 10,
            ["rotationType"] = "continuous",
            ["yawDegrees"] = 0,
          },
          ["situationSettings"] = {
            ["cvars"] = {
              ["cameraDistanceMaxZoomFactor"] = 2.6,
              ["cameraFov"] = 90,
              ["cameraZoomSpeed"] = 50,
              ["test_cameraDynamicPitch"] = 1,
              ["test_cameraDynamicPitchBaseFovPad"] = 0.4,
              ["test_cameraDynamicPitchBaseFovPadDownScale"] = 0.25,
              ["test_cameraDynamicPitchBaseFovPadFlying"] = 0.75,
              ["test_cameraDynamicPitchSmartPivotCutoffDist"] = 10,
              ["test_cameraOverShoulder"] = 0,
            },
            ["reactiveZoomAddIncrements"] = 2.5,
            ["reactiveZoomAddIncrementsAlways"] = 1,
            ["reactiveZoomEnabled"] = true,
            ["reactiveZoomIncAddDifference"] = 1.2,
            ["reactiveZoomMaxZoomTime"] = 0.1,
          },
          ["transitionTime"] = {
            ["timeToEnter"] = 2,
            ["timeToExit"] = 2,
          },
          ["viewZoom"] = {
            ["enabled"] = false,
            ["restoreDefaultViewNumber"] = 1,
            ["viewInstant"] = false,
            ["viewNumber"] = 2,
            ["viewRestore"] = true,
            ["viewZoomType"] = "zoom",
            ["zoomMax"] = 15,
            ["zoomMin"] = 5,
            ["zoomTimeIsMax"] = false,
            ["zoomType"] = "set",
            ["zoomValue"] = 10,
          },
        },
        ["custom2"] = {
          ["condition"] = "-- Solo se activa si NO está abierto DUIQuest\
return CheckHostileHarmTarget()\
\
\
\
\
\
",
          ["delay"] = 0,
          ["enabled"] = true,
          ["events"] = {
            [1] = "PLAYER_TARGET_CHANGED",
            [2] = "PLAYER_ENTERING_WORLD",
            [3] = "PLAYER_REGEN_ENABLED",
            [4] = "PLAYER_REGEN_DISABLED",
            [5] = "UNIT_TARGET",
          },
          ["executeOnEnter"] = "",
          ["executeOnExit"] = "",
          ["executeOnInit"] = "-- Ensure DynamicCam API is available\
if not DynamicCam then return end\
\
-- Ensure hostile target check exists\
if not _G.CheckHostileHarmTarget then\
    _G.CheckHostileHarmTarget = function()\
        return UnitExists(\"target\") and not UnitIsDead(\"target\")\
    end\
end\
\
\
\
\
\
",
          ["hideUI"] = {
            ["customFramesToKeep"] = {
              ["AuctionHouseFrame"] = true,
              ["BagnonBankFrame1"] = true,
              ["BankFrame"] = true,
              ["BuffFrame"] = true,
              ["ClassTrainerFrame"] = true,
              ["DebuffFrame"] = true,
              ["GossipFrame"] = true,
              ["MerchantFrame"] = true,
              ["PetStableFrame"] = true,
              ["QuestFrame"] = true,
              ["StaticPopup1"] = true,
              ["WardrobeFrame"] = true,
            },
            ["emergencyShowEscEnabled"] = true,
            ["enabled"] = false,
            ["fadeOpacity"] = 0.6,
            ["hideEntireUI"] = false,
            ["keepAlertFrames"] = true,
            ["keepChatFrame"] = false,
            ["keepCustomFrames"] = false,
            ["keepEncounterBar"] = false,
            ["keepFrameRate"] = false,
            ["keepMinimap"] = false,
            ["keepPartyRaidFrame"] = false,
            ["keepTooltip"] = true,
            ["keepTrackingBar"] = false,
          },
          ["name"] = "Target Harm",
          ["priority"] = 200,
          ["rotation"] = {
            ["enabled"] = false,
            ["pitchDegrees"] = 0,
            ["rotateBack"] = true,
            ["rotationSpeed"] = 10,
            ["rotationType"] = "continuous",
            ["yawDegrees"] = 0,
          },
          ["situationSettings"] = {
            ["cvars"] = {
              ["test_cameraDynamicPitch"] = 1,
              ["test_cameraDynamicPitchBaseFovPad"] = 0.99,
              ["test_cameraDynamicPitchBaseFovPadDownScale"] = 1,
              ["test_cameraDynamicPitchBaseFovPadFlying"] = 1,
              ["test_cameraDynamicPitchSmartPivotCutoffDist"] = 39,
              ["test_cameraOverShoulder"] = 0,
            },
            ["shoulderOffsetZoomEnabled"] = true,
            ["shoulderOffsetZoomLowerBound"] = 0.8,
            ["shoulderOffsetZoomUpperBound"] = 10,
          },
          ["transitionTime"] = {
            ["timeToEnter"] = 0.5,
            ["timeToExit"] = 0.5,
          },
          ["viewZoom"] = {
            ["enabled"] = false,
            ["restoreDefaultViewNumber"] = 1,
            ["viewInstant"] = false,
            ["viewNumber"] = 2,
            ["viewRestore"] = true,
            ["viewZoomType"] = "zoom",
            ["zoomMax"] = 15,
            ["zoomMin"] = 5,
            ["zoomTimeIsMax"] = false,
            ["zoomType"] = "set",
            ["zoomValue"] = 10,
          },
        },
        ["custom3"] = {
          ["condition"] = "-- Condition to activate the situation (focus target exists)\
return CheckFocusTarget()\
",
          ["delay"] = 0,
          ["enabled"] = true,
          ["events"] = {
            [1] = "PLAYER_FOCUS_CHANGED",
          },
          ["executeOnEnter"] = "",
          ["executeOnExit"] = "",
          ["executeOnInit"] = "-- Ensure DynamicCam API is available\
if not DynamicCam then return end\
\
-- Function to check if the player has a focus target\
function CheckFocusTarget()\
    -- Check if a focus target exists\
    return UnitExists(\"focus\")\
end\
\
",
          ["hideUI"] = {
            ["customFramesToKeep"] = {
              ["AuctionHouseFrame"] = true,
              ["BagnonBankFrame1"] = true,
              ["BankFrame"] = true,
              ["BuffFrame"] = true,
              ["ClassTrainerFrame"] = true,
              ["DebuffFrame"] = true,
              ["GossipFrame"] = true,
              ["MerchantFrame"] = true,
              ["PetStableFrame"] = true,
              ["QuestFrame"] = true,
              ["StaticPopup1"] = true,
              ["WardrobeFrame"] = true,
            },
            ["emergencyShowEscEnabled"] = true,
            ["enabled"] = false,
            ["fadeOpacity"] = 0.6,
            ["hideEntireUI"] = false,
            ["keepAlertFrames"] = true,
            ["keepChatFrame"] = false,
            ["keepCustomFrames"] = false,
            ["keepEncounterBar"] = false,
            ["keepFrameRate"] = false,
            ["keepMinimap"] = false,
            ["keepPartyRaidFrame"] = false,
            ["keepTooltip"] = true,
            ["keepTrackingBar"] = false,
          },
          ["name"] = "Focus",
          ["priority"] = 150,
          ["rotation"] = {
            ["enabled"] = false,
            ["pitchDegrees"] = 0,
            ["rotateBack"] = true,
            ["rotationSpeed"] = 10,
            ["rotationType"] = "continuous",
            ["yawDegrees"] = 0,
          },
          ["situationSettings"] = {
            ["cvars"] = {
              ["test_cameraDynamicPitch"] = 1,
              ["test_cameraDynamicPitchBaseFovPad"] = 0.99,
              ["test_cameraDynamicPitchBaseFovPadDownScale"] = 1,
              ["test_cameraDynamicPitchBaseFovPadFlying"] = 1,
              ["test_cameraDynamicPitchSmartPivotCutoffDist"] = 39,
              ["test_cameraOverShoulder"] = 0,
            },
            ["shoulderOffsetZoomEnabled"] = true,
            ["shoulderOffsetZoomLowerBound"] = 0.8,
            ["shoulderOffsetZoomUpperBound"] = 10,
          },
          ["transitionTime"] = {
            ["timeToEnter"] = 0.5,
            ["timeToExit"] = 0.5,
          },
          ["viewZoom"] = {
            ["enabled"] = false,
            ["restoreDefaultViewNumber"] = 1,
            ["viewInstant"] = false,
            ["viewNumber"] = 2,
            ["viewRestore"] = true,
            ["viewZoomType"] = "zoom",
            ["zoomMax"] = 15,
            ["zoomMin"] = 5,
            ["zoomTimeIsMax"] = false,
            ["zoomType"] = "set",
            ["zoomValue"] = 10,
          },
        },
        ["custom4"] = {
          ["condition"] = "-- Condition to activate the situation (player is in combat)\
return CheckInCombat()\
\
\
",
          ["delay"] = 0,
          ["enabled"] = true,
          ["events"] = {
            [1] = "PLAYER_REGEN_DISABLED",
          },
          ["executeOnEnter"] = "\
",
          ["executeOnExit"] = "",
          ["executeOnInit"] = "-- Ensure DynamicCam API is available\
if not DynamicCam then return end\
\
-- Function to check if the player is in combat\
function CheckInCombat()\
    -- Check if the player is in combat\
    return UnitAffectingCombat(\"player\")\
end\
\
\
",
          ["hideUI"] = {
            ["customFramesToKeep"] = {
              ["AuctionHouseFrame"] = true,
              ["BagnonBankFrame1"] = true,
              ["BankFrame"] = true,
              ["BuffFrame"] = true,
              ["ClassTrainerFrame"] = true,
              ["DebuffFrame"] = true,
              ["GossipFrame"] = true,
              ["MerchantFrame"] = true,
              ["PetStableFrame"] = true,
              ["QuestFrame"] = true,
              ["StaticPopup1"] = true,
              ["WardrobeFrame"] = true,
            },
            ["emergencyShowEscEnabled"] = true,
            ["enabled"] = false,
            ["fadeOpacity"] = 0.6,
            ["hideEntireUI"] = false,
            ["keepAlertFrames"] = true,
            ["keepChatFrame"] = false,
            ["keepCustomFrames"] = false,
            ["keepEncounterBar"] = false,
            ["keepFrameRate"] = false,
            ["keepMinimap"] = false,
            ["keepPartyRaidFrame"] = false,
            ["keepTooltip"] = true,
            ["keepTrackingBar"] = false,
          },
          ["name"] = "Combat",
          ["priority"] = 100,
          ["rotation"] = {
            ["enabled"] = false,
            ["pitchDegrees"] = 0,
            ["rotateBack"] = true,
            ["rotationSpeed"] = 10,
            ["rotationType"] = "continuous",
            ["yawDegrees"] = 0,
          },
          ["situationSettings"] = {
            ["cvars"] = {
              ["test_cameraDynamicPitch"] = 1,
              ["test_cameraDynamicPitchBaseFovPad"] = 0.99,
              ["test_cameraDynamicPitchBaseFovPadDownScale"] = 1,
              ["test_cameraDynamicPitchBaseFovPadFlying"] = 1,
              ["test_cameraDynamicPitchSmartPivotCutoffDist"] = 39,
              ["test_cameraOverShoulder"] = 0,
            },
            ["shoulderOffsetZoomEnabled"] = true,
            ["shoulderOffsetZoomLowerBound"] = 2,
            ["shoulderOffsetZoomUpperBound"] = 7,
          },
          ["transitionTime"] = {
            ["timeToEnter"] = 0.5,
            ["timeToExit"] = 1,
          },
          ["viewZoom"] = {
            ["enabled"] = false,
            ["restoreDefaultViewNumber"] = 1,
            ["viewInstant"] = false,
            ["viewNumber"] = 2,
            ["viewRestore"] = true,
            ["viewZoomType"] = "zoom",
            ["zoomMax"] = 15,
            ["zoomMin"] = 5,
            ["zoomTimeIsMax"] = false,
            ["zoomType"] = "set",
            ["zoomValue"] = 10,
          },
        },
        ["custom6"] = {
          ["condition"] = "local race = UnitRace(\"player\")\
return (\
    race == \"Troll\"\
    or race == \"Tauren\"\
    or race == \"Highmountain Tauren\"\
    or race == \"Draenei\"\
    or race == \"Pandaren\"\
    or race == \"Night Elf\"\
    or race == \"Zandalari Troll\"\
    or race == \"Kul Tiran\"\
    or race == \"Dracthyr\"\
)\
\
\
",
          ["delay"] = 0,
          ["enabled"] = true,
          ["events"] = {
            [1] = "PLAYER_ENTERING_WORLD",
            [2] = "PLAYER_LOGIN",
            [3] = "UNIT_MODEL_CHANGED",
          },
          ["executeOnEnter"] = "",
          ["executeOnExit"] = "",
          ["executeOnInit"] = "this.race = UnitRace(\"player\")\
",
          ["hideUI"] = {
            ["customFramesToKeep"] = {
              ["AuctionHouseFrame"] = true,
              ["BagnonBankFrame1"] = true,
              ["BankFrame"] = true,
              ["BuffFrame"] = true,
              ["ClassTrainerFrame"] = true,
              ["DebuffFrame"] = true,
              ["GossipFrame"] = true,
              ["MerchantFrame"] = true,
              ["PetStableFrame"] = true,
              ["QuestFrame"] = true,
              ["StaticPopup1"] = true,
              ["WardrobeFrame"] = true,
            },
            ["emergencyShowEscEnabled"] = true,
            ["enabled"] = false,
            ["fadeOpacity"] = 0.6,
            ["hideEntireUI"] = false,
            ["keepAlertFrames"] = true,
            ["keepChatFrame"] = false,
            ["keepCustomFrames"] = false,
            ["keepEncounterBar"] = false,
            ["keepFrameRate"] = false,
            ["keepMinimap"] = false,
            ["keepPartyRaidFrame"] = false,
            ["keepTooltip"] = true,
            ["keepTrackingBar"] = false,
          },
          ["name"] = "2 m tall",
          ["priority"] = 100,
          ["rotation"] = {
            ["enabled"] = false,
            ["pitchDegrees"] = 0,
            ["rotateBack"] = true,
            ["rotationSpeed"] = 10,
            ["rotationType"] = "continuous",
            ["yawDegrees"] = 0,
          },
          ["situationSettings"] = {
            ["cvars"] = {
              ["cameraDistanceMaxZoomFactor"] = 2.6,
              ["cameraZoomSpeed"] = 50,
              ["test_cameraDynamicPitch"] = 1,
              ["test_cameraDynamicPitchBaseFovPad"] = 0.99,
              ["test_cameraDynamicPitchBaseFovPadDownScale"] = 1,
              ["test_cameraDynamicPitchBaseFovPadFlying"] = 1,
              ["test_cameraDynamicPitchSmartPivotCutoffDist"] = 39,
              ["test_cameraOverShoulder"] = 0.9,
            },
            ["cvarsZoomBased"] = {
              ["test_cameraOverShoulder"] = {
                ["enabled"] = true,
                ["points"] = {
                  [1] = {
                    ["value"] = 0,
                    ["zoom"] = 0,
                  },
                  [2] = {
                    ["value"] = 0,
                    ["zoom"] = 0.8,
                  },
                  [3] = {
                    ["value"] = 0.9,
                    ["zoom"] = 10,
                  },
                  [4] = {
                    ["value"] = 0.9,
                    ["zoom"] = 39,
                  },
                },
              },
            },
            ["reactiveZoomAddIncrements"] = 2.5,
            ["reactiveZoomAddIncrementsAlways"] = 1,
            ["reactiveZoomEnabled"] = true,
            ["reactiveZoomIncAddDifference"] = 1.2,
            ["reactiveZoomMaxZoomTime"] = 0.1,
            ["shoulderOffsetZoomEnabled"] = true,
            ["shoulderOffsetZoomLowerBound"] = 0.8,
            ["shoulderOffsetZoomUpperBound"] = 10,
          },
          ["transitionTime"] = {
            ["timeToEnter"] = 0.5,
            ["timeToExit"] = 0.5,
          },
          ["viewZoom"] = {
            ["enabled"] = false,
            ["restoreDefaultViewNumber"] = 1,
            ["viewInstant"] = false,
            ["viewNumber"] = 2,
            ["viewRestore"] = true,
            ["viewZoomType"] = "zoom",
            ["zoomMax"] = 15,
            ["zoomMin"] = 5,
            ["zoomTimeIsMax"] = false,
            ["zoomType"] = "set",
            ["zoomValue"] = 20,
          },
        },
        ["custom7"] = {
          ["condition"] = "local race = UnitRace(\"player\")\
return (race == \"Gnome\" or race == \"Goblin\" or race == \"Mechagnome\")\
   and not CheckDUIQuestFrame()\
   and not CheckHostileHarmTarget()\
\
\
\
\
\
",
          ["delay"] = 0,
          ["enabled"] = true,
          ["events"] = {
            [1] = "PLAYER_ENTERING_WORLD",
            [2] = "PLAYER_LOGIN",
            [3] = "UNIT_MODEL_CHANGED",
          },
          ["executeOnEnter"] = "",
          ["executeOnExit"] = "",
          ["executeOnInit"] = "-- Ensure DynamicCam API is available\
if not DynamicCam then return end\
\
-- Ensure global quest check exists\
if not _G.CheckDUIQuestFrame then\
    _G.CheckDUIQuestFrame = function()\
        return DUIQuestFrame and DUIQuestFrame:IsShown()\
    end\
end\
\
-- Ensure hostile target check exists\
if not _G.CheckHostileHarmTarget then\
    _G.CheckHostileHarmTarget = function()\
        return UnitExists(\"target\") and not UnitIsDead(\"target\")\
    end\
end\
\
\
",
          ["hideUI"] = {
            ["customFramesToKeep"] = {
              ["AuctionHouseFrame"] = true,
              ["BagnonBankFrame1"] = true,
              ["BankFrame"] = true,
              ["BuffFrame"] = true,
              ["ClassTrainerFrame"] = true,
              ["DebuffFrame"] = true,
              ["GossipFrame"] = true,
              ["MerchantFrame"] = true,
              ["PetStableFrame"] = true,
              ["QuestFrame"] = true,
              ["StaticPopup1"] = true,
              ["WardrobeFrame"] = true,
            },
            ["emergencyShowEscEnabled"] = true,
            ["enabled"] = false,
            ["fadeOpacity"] = 0.6,
            ["hideEntireUI"] = false,
            ["keepAlertFrames"] = true,
            ["keepChatFrame"] = false,
            ["keepCustomFrames"] = false,
            ["keepEncounterBar"] = false,
            ["keepFrameRate"] = false,
            ["keepMinimap"] = false,
            ["keepPartyRaidFrame"] = false,
            ["keepTooltip"] = true,
            ["keepTrackingBar"] = false,
          },
          ["name"] = "S Race",
          ["priority"] = 100,
          ["rotation"] = {
            ["enabled"] = false,
            ["pitchDegrees"] = 0,
            ["rotateBack"] = true,
            ["rotationSpeed"] = 10,
            ["rotationType"] = "continuous",
            ["yawDegrees"] = 0,
          },
          ["situationSettings"] = {
            ["cvars"] = {
              ["test_cameraDynamicPitch"] = 1,
              ["test_cameraDynamicPitchBaseFovPad"] = 0.99,
              ["test_cameraDynamicPitchBaseFovPadDownScale"] = 1,
              ["test_cameraDynamicPitchBaseFovPadFlying"] = 1,
              ["test_cameraDynamicPitchSmartPivotCutoffDist"] = 39,
              ["test_cameraOverShoulder"] = 1.3,
            },
            ["cvarsZoomBased"] = {
              ["test_cameraOverShoulder"] = {
                ["enabled"] = true,
                ["points"] = {
                  [1] = {
                    ["value"] = 0,
                    ["zoom"] = 0,
                  },
                  [2] = {
                    ["value"] = 0,
                    ["zoom"] = 0.8,
                  },
                  [3] = {
                    ["value"] = 0.43,
                    ["zoom"] = 3.2,
                  },
                  [4] = {
                    ["value"] = 0.43,
                    ["zoom"] = 5.8,
                  },
                  [5] = {
                    ["value"] = 1.11,
                    ["zoom"] = 10.8,
                  },
                  [6] = {
                    ["value"] = 1.3,
                    ["zoom"] = 39,
                  },
                },
              },
            },
            ["shoulderOffsetZoomEnabled"] = true,
            ["shoulderOffsetZoomLowerBound"] = 0.8,
            ["shoulderOffsetZoomUpperBound"] = 10,
          },
          ["transitionTime"] = {
            ["timeToEnter"] = 0.5,
            ["timeToExit"] = 0.5,
          },
          ["viewZoom"] = {
            ["enabled"] = false,
            ["restoreDefaultViewNumber"] = 1,
            ["viewInstant"] = false,
            ["viewNumber"] = 2,
            ["viewRestore"] = true,
            ["viewZoomType"] = "zoom",
            ["zoomMax"] = 15,
            ["zoomMin"] = 5,
            ["zoomTimeIsMax"] = false,
            ["zoomType"] = "set",
            ["zoomValue"] = 10,
          },
        },
        ["custom8"] = {
          ["condition"] = "local race = UnitRace(\"player\")\
return (\
    race == \"Human\"\
    or race == \"Worgen\"\
    or race == \"Orc\"\
    or race == \"Blood Elf\"\
    or race == \"Dwarf\"\
    or race == \"Undead\"\
    or race == \"Nightborne\"\
    or race == \"Mag'har Orc\"\
    or race == \"Void Elf\"\
    or race == \"Vulpera\"\
    or race == \"Earthen\"        -- Earthen (added)\
    or race == \"Earthen Dwarf\"  -- fallback por si aparece con espacio\
    or race == \"Dark Iron Dwarf\")",
          ["delay"] = 0,
          ["enabled"] = true,
          ["events"] = {
            [1] = "PLAYER_ENTERING_WORLD",
            [2] = "PLAYER_LOGIN",
            [3] = "UNIT_MODEL_CHANGED",
          },
          ["executeOnEnter"] = "",
          ["executeOnExit"] = "",
          ["executeOnInit"] = "this.race = UnitRace(\"player\")",
          ["hideUI"] = {
            ["customFramesToKeep"] = {
              ["AuctionHouseFrame"] = true,
              ["BagnonBankFrame1"] = true,
              ["BankFrame"] = true,
              ["BuffFrame"] = true,
              ["ClassTrainerFrame"] = true,
              ["DebuffFrame"] = true,
              ["GossipFrame"] = true,
              ["MerchantFrame"] = true,
              ["PetStableFrame"] = true,
              ["QuestFrame"] = true,
              ["StaticPopup1"] = true,
              ["WardrobeFrame"] = true,
            },
            ["emergencyShowEscEnabled"] = true,
            ["enabled"] = false,
            ["fadeOpacity"] = 0.6,
            ["hideEntireUI"] = false,
            ["keepAlertFrames"] = true,
            ["keepChatFrame"] = false,
            ["keepCustomFrames"] = false,
            ["keepEncounterBar"] = false,
            ["keepFrameRate"] = false,
            ["keepMinimap"] = false,
            ["keepPartyRaidFrame"] = false,
            ["keepTooltip"] = true,
            ["keepTrackingBar"] = false,
          },
          ["name"] = "m race",
          ["priority"] = 100,
          ["rotation"] = {
            ["enabled"] = false,
            ["pitchDegrees"] = 0,
            ["rotateBack"] = true,
            ["rotationSpeed"] = 10,
            ["rotationType"] = "continuous",
            ["yawDegrees"] = 0,
          },
          ["situationSettings"] = {
            ["cvars"] = {
              ["test_cameraDynamicPitch"] = 1,
              ["test_cameraDynamicPitchBaseFovPad"] = 0.99,
              ["test_cameraDynamicPitchBaseFovPadDownScale"] = 1,
              ["test_cameraDynamicPitchBaseFovPadFlying"] = 1,
              ["test_cameraDynamicPitchSmartPivotCutoffDist"] = 39,
              ["test_cameraOverShoulder"] = 0.6,
            },
            ["cvarsZoomBased"] = {
              ["test_cameraOverShoulder"] = {
                ["enabled"] = true,
                ["points"] = {
                  [1] = {
                    ["value"] = 0,
                    ["zoom"] = 0,
                  },
                  [2] = {
                    ["value"] = 0.35,
                    ["zoom"] = 3.5,
                  },
                  [3] = {
                    ["value"] = 0.75,
                    ["zoom"] = 6.4,
                  },
                  [4] = {
                    ["value"] = 0.85,
                    ["zoom"] = 10.2,
                  },
                  [5] = {
                    ["value"] = 2.83,
                    ["zoom"] = 31.2,
                  },
                  [6] = {
                    ["value"] = 0.6,
                    ["zoom"] = 39,
                  },
                },
              },
            },
            ["shoulderOffsetZoomEnabled"] = true,
            ["shoulderOffsetZoomLowerBound"] = 0.8,
            ["shoulderOffsetZoomUpperBound"] = 10,
          },
          ["transitionTime"] = {
            ["timeToEnter"] = 0.5,
            ["timeToExit"] = 0.5,
          },
          ["viewZoom"] = {
            ["enabled"] = false,
            ["restoreDefaultViewNumber"] = 1,
            ["viewInstant"] = false,
            ["viewNumber"] = 2,
            ["viewRestore"] = true,
            ["viewZoomType"] = "zoom",
            ["zoomMax"] = 15,
            ["zoomMin"] = 5,
            ["zoomTimeIsMax"] = false,
            ["zoomType"] = "set",
            ["zoomValue"] = 10,
          },
        },
        ["custom9"] = {
          ["condition"] = "if not C_PlayerInteractionManager then return false end\
local t = Enum.PlayerInteractionType\
return C_PlayerInteractionManager.IsInteractingWithNpcOfType(t.QuestGiver)\
    or C_PlayerInteractionManager.IsInteractingWithNpcOfType(t.Gossip)",
          ["delay"] = 0,
          ["enabled"] = true,
          ["events"] = {
            [1] = "GOSSIP_SHOW",
            [2] = "GOSSIP_CLOSED",
            [3] = "QUEST_GREETING",
            [4] = "QUEST_DETAIL",
            [5] = "QUEST_PROGRESS",
            [6] = "QUEST_COMPLETE",
            [7] = "QUEST_FINISHED",
            [8] = "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
            [9] = "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
          },
          ["executeOnEnter"] = "",
          ["executeOnExit"] = "",
          ["executeOnInit"] = "",
          ["hideUI"] = {
            ["customFramesToKeep"] = {
              ["AuctionHouseFrame"] = true,
              ["BagnonBankFrame1"] = true,
              ["BankFrame"] = true,
              ["BuffFrame"] = true,
              ["ClassTrainerFrame"] = true,
              ["DebuffFrame"] = true,
              ["GossipFrame"] = true,
              ["MerchantFrame"] = true,
              ["PetStableFrame"] = true,
              ["QuestFrame"] = true,
              ["StaticPopup1"] = true,
              ["WardrobeFrame"] = true,
            },
            ["emergencyShowEscEnabled"] = true,
            ["enabled"] = false,
            ["fadeOpacity"] = 0.6,
            ["hideEntireUI"] = false,
            ["keepAlertFrames"] = true,
            ["keepChatFrame"] = false,
            ["keepCustomFrames"] = false,
            ["keepEncounterBar"] = false,
            ["keepFrameRate"] = false,
            ["keepMinimap"] = false,
            ["keepPartyRaidFrame"] = false,
            ["keepTooltip"] = true,
            ["keepTrackingBar"] = false,
          },
          ["name"] = "Dialogue",
          ["priority"] = 250,
          ["rotation"] = {
            ["enabled"] = false,
            ["pitchDegrees"] = 0,
            ["rotateBack"] = true,
            ["rotationSpeed"] = 2,
            ["rotationType"] = "continuous",
            ["yawDegrees"] = 0,
          },
          ["situationSettings"] = {
            ["cvars"] = {
              ["cameraFov"] = 68.5,
              ["test_cameraDynamicPitch"] = 1,
              ["test_cameraDynamicPitchBaseFovPad"] = 0.99,
              ["test_cameraDynamicPitchBaseFovPadDownScale"] = 1,
              ["test_cameraDynamicPitchBaseFovPadFlying"] = 0.92,
              ["test_cameraDynamicPitchSmartPivotCutoffDist"] = 39,
              ["test_cameraHeadMovementDeadZone"] = 0.015,
              ["test_cameraHeadMovementFirstPersonDampRate"] = 20,
              ["test_cameraHeadMovementMovingDampRate"] = 10,
              ["test_cameraHeadMovementMovingStrength"] = 0.5,
              ["test_cameraHeadMovementRangeScale"] = 5,
              ["test_cameraHeadMovementStandingDampRate"] = 10,
              ["test_cameraHeadMovementStandingStrength"] = 0.3,
              ["test_cameraHeadMovementStrength"] = 1,
              ["test_cameraOverShoulder"] = -0.2,
              ["test_cameraTargetFocusEnemyEnable"] = 0,
              ["test_cameraTargetFocusEnemyStrengthPitch"] = 0.4,
              ["test_cameraTargetFocusEnemyStrengthYaw"] = 0.5,
              ["test_cameraTargetFocusInteractEnable"] = 1,
              ["test_cameraTargetFocusInteractStrengthPitch"] = 0.75,
              ["test_cameraTargetFocusInteractStrengthYaw"] = 1,
            },
          },
          ["transitionTime"] = {
            ["timeToEnter"] = 1,
            ["timeToExit"] = 5,
          },
          ["viewZoom"] = {
            ["enabled"] = false,
            ["restoreDefaultViewNumber"] = 1,
            ["viewInstant"] = false,
            ["viewNumber"] = 2,
            ["viewRestore"] = true,
            ["viewZoomType"] = "zoom",
            ["zoomMax"] = 15,
            ["zoomMin"] = 5,
            ["zoomTimeIsMax"] = false,
            ["zoomType"] = "set",
            ["zoomValue"] = 10,
          },
        },
      },
      ["standardSettings"] = {
        ["cvars"] = {
          ["cameraDistanceMaxZoomFactor"] = 2.6,
          ["cameraZoomSpeed"] = 50,
          ["test_cameraDynamicPitch"] = 1,
          ["test_cameraDynamicPitchBaseFovPad"] = 0.99,
          ["test_cameraDynamicPitchBaseFovPadDownScale"] = 1,
          ["test_cameraDynamicPitchBaseFovPadFlying"] = 1,
          ["test_cameraDynamicPitchSmartPivotCutoffDist"] = 39,
          ["test_cameraOverShoulder"] = 1.4,
        },
        ["cvarsZoomBased"] = {
          ["test_cameraOverShoulder"] = {
            ["enabled"] = false,
            ["points"] = {
              [1] = {
                ["value"] = 0,
                ["zoom"] = 0,
              },
              [2] = {
                ["value"] = 0,
                ["zoom"] = 0.8,
              },
              [3] = {
                ["value"] = 1.3,
                ["zoom"] = 10,
              },
              [4] = {
                ["value"] = 1.3,
                ["zoom"] = 39,
              },
            },
          },
        },
      },
      ["version"] = 5,
      ["zoomRestoreSetting"] = "never",
    },
  },
}
