// =============================================================================
// FAC_GuiSpecs.sqf — data for FAC_gui_build. Handler names are strings so this
// file can compile before the GUI functions exist.
// Row shapes are documented in FAC_GuiForm.sqf.
// =============================================================================

FAC_gui_spec_scenario = [
    ["title", "SCENARIO", 0.16],
    ["handler", "FAC_scenarioGui_fnc"],
    ["frame", "full"],
    ["refresh", true],
    ["default", "scenario"],
    ["tabs", [
        ["scenario", "Scenario", 60810],
        ["weather", "Weather", 60813],
        ["factions", "Factions", 60811],
        ["admin", "Admin", 60812]
    ]],
    ["footer", [
        ["Apply and Close", 60320, "apply", [], "primary"]
    ]],
    ["page", "scenario", [
        ["section", "OPFOR"],
        ["segments", "Grenades", "Thrown HE, under-barrel HE, and grenade launchers. Smoke and flares stay.", [
            ["Normal", 60986, "setGrenade", ["Normal"], "idle"],
            ["Reduced", 60987, "setGrenade", ["Reduced"], "primary"],
            ["Minimal", 60988, "setGrenade", ["Minimal"], "idle"],
            ["None", 60989, "setGrenade", ["None"], "idle"]
        ]],
        ["segments", "Scale with players", "Garrison, patrol, and QRF counts follow alive players.", [
            ["Off", 60991, "setPlayerScale", [false], "idle"],
            ["On", 60992, "setPlayerScale", [true], "primary"]
        ]],
        ["section", "Time", 60804],
        ["stepper", "Time (Zulu)", "Steps the mission clock.", 60820, 60821, 60822, "timeStep", 60805],
        ["section", "Loadouts, time and redeploy", 60942],
        ["segments", "Limit gear (BLUFOR)", "Restricts the arsenal to the friendly faction.", [
            ["Off", 60850, "toggleLimitGear", [false], "primary"],
            ["On", 60851, "toggleLimitGear", [true], "idle"]
        ]],
        ["segments", "Ambient civs", "Foot traffic in towns.", [
            ["Off", 60852, "toggleCivs", [false], "idle"],
            ["On", 60853, "toggleCivs", [true], "primary"]
        ]],
        ["segments", "Preset loadouts only", "Players pick a saved role instead of a faction unit.", [
            ["Off", 60854, "togglePreset", [false], "primary"],
            ["On", 60855, "togglePreset", [true], "idle"]
        ]],
        ["segments", "Time scale", "How fast the clock runs.", [
            ["1x", 60856, "setTimeScale", [1], "primary"],
            ["5x", 60857, "setTimeScale", [5], "idle"],
            ["25x", 60858, "setTimeScale", [25], "idle"]
        ]],
        ["segments", "Talk to civilians", "Who can open the civilian talk menu.", [
            ["Everyone", 60341, "toggleCivTalkInterp", [false], "primary"],
            ["Interpreters only", 60342, "toggleCivTalkInterp", [true], "idle"]
        ]],
        ["segments", "Who can read Intel?", "", [
            ["Everyone", 60344, "toggleIntelSpecialists", [false], "primary"],
            ["Specialists only", 60345, "toggleIntelSpecialists", [true], "idle"]
        ]],
        ["segments", "Redeploy (teleport to player)", "Who can teleport to another player.", [
            ["All players", 60859, "setTeleportMode", [0], "primary"],
            ["SL only", 60860, "setTeleportMode", [1], "idle"]
        ]],
        ["section", "Operation and invasion zones", 60952],
        ["slider", "Number of target towns in Operation mission: 6", "", 60862, -1, 60861, "sliderChanged", "this"],
        ["section", "Ambient civilians", 60953],
        ["slider", "Walking civ global cap", "0 means no cap.", 60950, 60651, 60650, "sliderChanged", "this"],
        ["slider", "Town foot-civ density scale", "Scales capital towns down to small ones.", 60951, 60653, 60652, "sliderChanged", "this"]
    ]],
    ["page", "weather", ["columns",
        [
            ["list", "Weather preset", "A preset fills the sliders. Moving a slider keeps your mix.", 60806, "fill", 60302, "weatherPresetChanged", []]
        ],
        [
            ["section", "Weather", 60902],
            ["slider", "Overcast: 0%", "", 60831, -1, 60830, "sliderChanged", "this"],
            ["slider", "Rain: 0%", "", 60833, -1, 60832, "sliderChanged", "this"],
            ["slider", "Fog: 0%", "", 60835, -1, 60834, "sliderChanged", "this"],
            ["slider", "Wind: 0%", "", 60837, -1, 60836, "sliderChanged", "this"],
            ["slider", "Wind dir: 0 deg", "", 60839, -1, 60838, "sliderChanged", "this"],
            ["slider", "Gusts: 0%", "", 60841, -1, 60840, "sliderChanged", "this"],
            ["slider", "Waves: 0%", "", 60843, -1, 60842, "sliderChanged", "this"],
            ["structured", 60940, 0.28, ""]
        ]
    ]],
    ["page", "factions", ["fit", [
        ["band", [
            ["list", "Friendly", "", 60919, "fill", 60311, "factionListChanged", [60311]],
            ["list", "Enemy", "", 60920, "fill", 60310, "factionListChanged", [60310]],
            ["list", "Civilian", "", 60921, "fill", 60312, "factionListChanged", [60312]]
        ]],
        ["cols", [
            [
                ["section", "Enemy behaviour"],
                ["segments", "Patrols", "", [
                    ["Off", 60870, "togglePatrols", [false], "primary"],
                    ["On", 60871, "togglePatrols", [true], "idle"]
                ]],
                ["slider", "AI skill", "", 60912, 60873, 60872, "sliderChanged", "this"],
                ["segments", "Routing", "Units can break and fall back.", [
                    ["Off", 60874, "toggleRouting", [false], "primary"],
                    ["On", 60875, "toggleRouting", [true], "idle"]
                ]],
                ["segments", "AAA", "", [
                    ["Off", 60876, "setAAA", ["Off"], "primary"],
                    ["AAA", 60877, "setAAA", ["AAA"], "idle"],
                    ["AAA+MANPADS", 60878, "setAAA", ["AAA+MANPADS"], "idle"]
                ]]
            ],
            [
                ["section", "OPFOR numbers"],
                ["segments", "AT", "", [
                    ["Normal", 60881, "setLauncher", ["Normal"], "primary"],
                    ["Reduced", 60882, "setLauncher", ["Reduced"], "idle"],
                    ["Minimal", 60883, "setLauncher", ["Minimal"], "idle"],
                    ["None", 60884, "setLauncher", ["None"], "idle"]
                ]],
                ["segments", "Population", "Scales infantry. Normal is 1x.", [
                    ["V.Low (0.25x)", 60886, "setOpforPop", ["VeryLow"], "idle"],
                    ["Low (0.5x)", 60887, "setOpforPop", ["Low"], "idle"],
                    ["Normal (1x)", 60888, "setOpforPop", ["Normal"], "idle"],
                    ["High (1.5x)", 60889, "setOpforPop", ["High"], "idle"],
                    ["V.High (2x)", 60890, "setOpforPop", ["VeryHigh"], "idle"],
                    ["Insane (4x)", 60891, "setOpforPop", ["Insane"], "idle"]
                ]],
                ["segments", "Patrol town chance", "", [
                    ["Low (25%)", 60981, "setPatrolTownChance", ["Low"], "primary"],
                    ["Medium (50%)", 60982, "setPatrolTownChance", ["Medium"], "idle"],
                    ["High (75%)", 60983, "setPatrolTownChance", ["High"], "idle"],
                    ["Every (100%)", 60984, "setPatrolTownChance", ["Every"], "idle"]
                ]],
                ["segments", "Air", "", [
                    ["Off", 60892, "setOpforAir", ["Off"], "primary"],
                    ["Low", 60893, "setOpforAir", ["Low"], "idle"],
                    ["Normal", 60894, "setOpforAir", ["Normal"], "idle"],
                    ["High", 60957, "setOpforAir", ["High"], "idle"]
                ]],
                ["segments", "Drones", "", [
                    ["Off", 60959, "setOpforDrone", ["Off"], "primary"],
                    ["Low", 60960, "setOpforDrone", ["Low"], "idle"],
                    ["Normal", 60961, "setOpforDrone", ["Normal"], "idle"],
                    ["High", 60962, "setOpforDrone", ["High"], "idle"]
                ]]
            ]
        ]]
    ]]],
    ["page", "admin", [
        ["section", "Admin tools", 60930],
        ["segments", "Object list", "Anything is every prop. Realistic is a set list of fortifications, camp gear, and supplies.", [
            ["Anything", 60848, "setBuildCatalog", [0], "primary"],
            ["Realistic", 60849, "setBuildCatalog", [1], "idle"]
        ]],
        ["text", 60943, 0.03, "Destructive actions require a second click (Are you sure?)"],
        ["buttonRow", [
            ["Make me Zeus", 60895, "adminCleanup", ["makeZeus"], "primary"],
            ["Remove my Zeus", 60896, "adminCleanup", ["removeMyZeus"], "neutral"]
        ]],
        ["button", "Teleport all players to HQ", "", 60897, "adminCleanup", ["teleportAllToBase"], "primary"],
        ["button", "Abort all missions", "", 60899, "adminCleanup", ["abortAllMissions"], "danger"],
        ["button", "Despawn civilians", "", 60900, "adminCleanup", ["despawnCivilians"], "danger"],
        ["button", "Despawn OPFOR", "", 60901, "adminCleanup", ["despawnOpfor"], "danger"],
        ["button", "Remove placed objects", "", 60898, "adminCleanup", ["clearPlaced"], "danger"]
    ]]
];

FAC_gui_spec_medical = [
    ["title", "MEDICAL", 0.18],
    ["handler", "FAC_medicalTrainingGui_fnc"],
    ["frame", "full"],
    ["refresh", true],
    ["default", "main"],
    ["page", "main", ["columns",
        [
            ["section", "Training dummies", 60880],
            ["list", "On the range", "Injuries apply to the selected dummy.", -1, "fill", 60801, "dummySelChanged", []],
            ["buttonRow", [
                ["New dummy", 60814, "spawnDummy", [], "primary"],
                ["Delete", 60815, "deleteDummy", [], "warn"],
                ["Delete all", 60816, "deleteAll", [], "danger"]
            ]],
            ["structured", 60850, 0.16, ""]
        ],
        [
            ["section", "Preset scenario", 60892],
            ["combo", "Preset", "", -1, 60802, "", []],
            ["buttonRow", [
                ["Apply preset", 60830, "applyPreset", [], "primary"],
                ["Apply random injury", 60836, "applyRandomPreset", [], "neutral"]
            ]],
            ["section", "Airway / chest"],
            ["combo", "Obstruction", "", -1, 60860, "", []],
            ["combo", "Occluded", "", -1, 60861, "", []],
            ["combo", "Hemopneumothorax", "", -1, 60862, "", []],
            ["combo", "Tension PTX", "", -1, 60863, "", []],
            ["slider", "Pneumothorax 0-4", "", 60871, -1, 60864, "ptxSlider", "args"],
            ["slider", "SpO2 / PaO2 slot (0-100)", "", 60872, -1, 60865, "spo2Slider", "args"],
            ["combo", "PTX deteriorate", "", -1, 60866, "", []],
            ["combo", "Deep penetrating", "", -1, 60867, "", []],
            ["button", "Apply airway / chest", "", 60868, "applyAirwayChest", [], "primary"],
            ["section", "Cardiac rhythm"],
            ["combo", "Rhythm", "", -1, 60869, "", []],
            ["button", "Apply cardiac", "", 60870, "applyCardiac", [], "primary"],
            ["section", "Bleeding wound / part"],
            ["combo", "Body part", "", -1, 60803, "", []],
            ["combo", "Wound type", "", -1, 60804, "", []],
            ["slider", "Bleed rate: —", "", 60806, -1, 60805, "bleedSlider", "args"],
            ["combo", "Depth", "", -1, 60807, "", []],
            ["button", "Apply wound", "", 60831, "applyWound", [], "primary"],
            ["buttonRow", [
                ["Heal part", 60832, "healPart", [], "primary"],
                ["Heal all", 60833, "healAll", [], "primary"]
            ]],
            ["buttonRow", [
                ["Unconscious", 60834, "unconscious", [], "warn"],
                ["Conscious", 60835, "conscious", [], "primary"]
            ]]
        ]
    ]]
];

FAC_gui_spec_cqb = [
    ["title", "CQB", 0.12],
    ["handler", "FAC_cqbGui_fnc"],
    ["frame", "full"],
    ["refresh", true],
    ["default", "setup"],
    ["tabs", [
        ["setup", "Setup", 60520],
        ["info", "Info", 60521]
    ]],
    ["page", "setup", [
        ["section", "Drill setup", 60522],
        ["segments", "Threat type", "", [
            ["Pop-up targets", 60510, "setThreat", ["targets"], "primary"],
            ["Live OPFOR", 60511, "setThreat", ["enemies"], "idle"]
        ]],
        ["segments", "Spawn chance (per position)", "Each position rolls on its own.", [
            ["Low (20%)", 60515, "setDensity", ["Low"], "primary"],
            ["Medium (33%)", 60516, "setDensity", ["Medium"], "idle"],
            ["High (50%)", 60517, "setDensity", ["High"], "idle"]
        ]],
        ["segments", "Civilian mix (live OPFOR only)", "", [
            ["Off", 60512, "setCiv", [false], "primary"],
            ["On (15%)", 60513, "setCiv", [true], "idle"]
        ]],
        ["section", "Last run", 60526],
        ["text", 60508, 0.05, " - "],
        ["button", "Start drill", "", 60504, "drill", [], "primary"]
    ]],
    ["page", "info", [
        ["structured", 60507, 0.62, ""]
    ]]
];

FAC_gui_spec_sniper = [
    ["title", "SNIPER RANGE", 0.24],
    ["handler", "FAC_sniperGui_fnc"],
    ["frame", "full"],
    ["refresh", true],
    ["default", "main"],
    ["footer", [
        ["Start session", 60924, "session", [], "primary"]
    ]],
    ["page", "main", ["columns",
        [
            ["text", 60930, 0.03, "INACTIVE"],
            ["section", "My settings"],
            ["segments", "Projectile trace", "", [
                ["Off", 60918, "setTrace", [false], "primary"],
                ["On", 60919, "setTrace", [true], "idle"]
            ]],
            ["segments", "Hit feedback", "", [
                ["Off", 60920, "setHitTrack", [false], "primary"],
                ["On", 60921, "setHitTrack", [true], "idle"]
            ]],
            ["section", "Range settings"],
            ["segments", "Target type", "", [
                ["Pop-up targets", 60912, "setThreat", ["targets"], "primary"],
                ["Live OPFOR", 60913, "setThreat", ["enemies"], "idle"]
            ]],
            ["slider", "Number of targets", "", -1, 60916, 60915, "setTargetCount", "value"],
            ["slider", "Max range", "", -1, 60932, 60931, "setMaxRange", "value"],
            ["segments", "Mode", "", [
                ["Firing range", 60922, "setMode", ["firing"], "primary"],
                ["Time trial", 60923, "setMode", ["trial"], "idle"]
            ]]
        ],
        [
            ["section", "How it works"],
            ["structured", 60925, 0.55, ""]
        ]
    ]]
];

FAC_gui_spec_range = [
    ["title", "RANGE", 0.14],
    ["handler", "FAC_rangeGui_fnc"],
    ["frame", "full"],
    ["refresh", true],
    ["default", "range"],
    ["tabs", [
        ["range", "Range", 60960],
        ["equipment", "Equipment", 60978]
    ]],
    ["dock", [
        ["structured", 60948, 0.12, ""]
    ]],
    ["page", "range", [
        ["text", 60923, 0.03, "INACTIVE"],
        ["segments", "Mode", "", [
            ["Firing range", 60934, "setMode", ["firing"], "primary"],
            ["Time trial", 60935, "setMode", ["trial"], "idle"]
        ]],
        ["section", "Session targets", 60966],
        ["segments", "Human target type", "", [
            ["Pop-up targets", 60928, "setThreat", ["targets"], "primary"],
            ["Live OPFOR", 60929, "setThreat", ["enemies"], "idle"]
        ]],
        ["slider", "Human targets", "", 60968, 60930, 60931, "setHumanCount", "value"],
        ["slider", "Vehicle targets", "", 60969, 60932, 60933, "setVehCount", "value"],
        ["slider", "Max spawn distance (m)", "", 60971, 60936, 60937, "setMaxRange", "value"],
        ["section", "OPFOR vehicle types (session)", 60973],
        ["segments", "Enabled types", "One random class per enabled type.", [
            ["Car", 60939, "toggleVehType", ["car"], "primary"],
            ["Truck", 60940, "toggleVehType", ["truck"], "primary"],
            ["APC", 60941, "toggleVehType", ["apc"], "primary"],
            ["Tank", 60942, "toggleVehType", ["tank"], "primary"]
        ]],
        ["text", 60943, 0.04, "Random class per enabled type. Max spawn distance applies to session and equipment spawns."],
        ["section", "My settings", 60963],
        ["segments", "Projectile trace", "", [
            ["Off", 60924, "setTrace", [false], "primary"],
            ["On", 60925, "setTrace", [true], "idle"]
        ]],
        ["segments", "Hit feedback", "", [
            ["Off", 60926, "setHitTrack", [false], "primary"],
            ["On", 60927, "setHitTrack", [true], "idle"]
        ]],
        ["button", "Start session", "", 60938, "session", [], "primary"]
    ]],
    ["page", "equipment", ["columns",
        [
            ["section", "Range equipment pads", 60993],
            ["edit", "Search", "", 60982, 60983, "friendlySearchChanged", []],
            ["list", "Vehicle / equipment class", "", 60989, "fill", 60949, "friendlyVehSel", []],
            ["button", "Spawn", "", 60951, "equipmentSpawn", [], "primary"]
        ],
        [
            ["picture", 60984, "ratio"],
            ["list", "Pad (spawn here or despawn)", "", 60990, 0.22, 60950, "", []],
            ["button", "Despawn", "", 60952, "equipmentDespawn", [], "warn"]
        ]
    ]]
];

FAC_gui_spec_vehicle = [
    ["title", "VEHICLES", 0.16],
    ["handler", "FAC_vehicleGui_fnc"],
    ["frame", "full"],
    ["refresh", true],
    ["default", "new"],
    ["tabs", [
        ["new", "Spawn new", 61000],
        ["existing", "Manage existing", 61001]
    ]],
    ["headerButtons", [
        ["Delete wrecks", 61004, "deleteWrecks", [], "warn"]
    ]],
    ["page", "new", ["columns",
        [
            ["segments", "Category", "", [
                ["Aircraft", 61116, "spawnCategorySet", ["aircraft"], "primary"],
                ["Land", 61117, "spawnCategorySet", ["land"], "idle"]
            ]],
            ["button", "Aircraft whitelist: ON", "", 61118, "spawnWhitelistClick", [], "neutral"],
            ["edit", "Search...", "", 61112, 61102, "spawnFilterChanged", []],
            ["list", "Select vehicle", "", 61113, "fill", 61103, "spawnVehicleSel", []],
            ["button", "Place", "", 61107, "spawn", [], "primary"],
            ["button", "Place multiple: Off", "", 61119, "placeMultipleClick", [], "idle"]
        ],
        [
            ["list", "Faction", "", -1, 0.16, 61101, "spawnFilterChanged", []],
            ["picture", 61104, "ratio"],
            ["list", "Details", "", 61115, "fill", 61105, "", []]
        ]
    ]],
    ["page", "existing", [
        ["beside",
            [
                ["list", "Selected vehicle", "", 61240, "fill", 61200, "manageVehicleSel", []]
            ],
            [
                ["picture", 61210, "ratio", 1.778, 0.42]
            ],
            0.46
        ],
        ["list", "Selected vehicle details", "", 61241, 0.34, 61211, "", []],
        ["list", "Ammo", "", 61242, 0.14, 61220, "manageAmmoSelChanged", []],
        ["sliderApply", "Ammo load: 0 / 0", "", 61222, 61221, "manageAmmoSliderChanged", "args", ["Apply ammo", 61223, "manageApplyAmmo", [], "primary"]],
        ["sliderApply", "Fuel: 0%", "", 61225, 61224, "manageFuelSliderChanged", "args", ["Apply fuel", 61226, "manageApplyFuel", [], "primary"]],
        ["sliderApply", "Health: 0%", "", 61228, 61227, "manageHealthSliderChanged", "args", ["Apply health", 61229, "manageApplyHealth", [], "primary"]],
        ["buttonRow", [
            ["Quick repair", 61201, "servicePart", ["repair"], "primary"],
            ["Quick refuel", 61205, "servicePart", ["refuel"], "primary"],
            ["Quick rearm", 61206, "servicePart", ["rearm"], "primary"],
            ["Configure pylons...", 61230, "manageOpenPylons", [], "danger"]
        ]],
        ["buttonRow", [
            ["Despawn selected", 61202, "despawn", [], "warn"],
            ["Duplicate selected", 61232, "duplicate", [], "primary"]
        ]]
    ]]
];

FAC_gui_spec_missions = [
    ["title", "MISSIONS", 0.16],
    ["handler", "FAC_missionsGui_fnc"],
    ["frame", "full"],
    ["refresh", true],
    ["default", "browse"],
    ["tabs", [
        ["browse", "Browse", 60160],
        ["active", "Active slots", 60161]
    ]],
    ["page", "browse", ["columns",
        [
            ["text", 60133, 0.18, ""],
            ["list", "Select mission", "", 60110, "fill", 60120, "missionSelChanged", []],
            ["button", "Start mission...", "", 60121, "startMission", [], "primary"]
        ],
        [
            ["list", "Description", "", 60111, "fill", 60131, "", []]
        ],
        "fit"
    ]],
    ["page", "active", ["pin",
        [
            ["hint", "Global is one shared mission. Single is a personal task, up to three at once."]
        ],
        [
            [
                ["section", "G1 - Global [max 1]", 60112],
                ["text", 60130, 0.52, ""],
                ["button", "Abort G1", "", 60150, "abortSlot", ["G1"], "warn"]
            ],
            [
                ["section", "S1 - Single", 60113],
                ["text", 60134, 0.52, ""],
                ["button", "Abort S1", "", 60151, "abortSlot", ["S1"], "warn"]
            ],
            [
                ["section", "S2 - Single", 60114],
                ["text", 60135, 0.52, ""],
                ["button", "Abort S2", "", 60152, "abortSlot", ["S2"], "warn"]
            ],
            [
                ["section", "S3 - Single", 60115],
                ["text", 60136, 0.52, ""],
                ["button", "Abort S3", "", 60153, "abortSlot", ["S3"], "warn"]
            ]
        ],
        0.72
    ]]
];

FAC_gui_spec_loadout = [
    ["title", "LOADOUT", 0.16],
    ["handler", "FAC_loadoutGui_fnc"],
    ["frame", "full"],
    ["refresh", true],
    ["default", "main"],
    ["headerButtons", [
        ["Preset loadouts...", 60213, "sourcePick", ["preset"], "primary"],
        ["Faction units...", 60214, "sourcePick", ["std"], "idle"]
    ]],
    ["footer", [
        ["Apply to me", 60202, "apply", [], "primary"],
        ["Apply to...", 60219, "applyToToggle", [], "primary", false],
        ["Save loadout", 60204, "saveLoadout", [], "neutral"],
        ["Restore saved", 60206, "restoreLoadout", [], "neutral"]
    ]],
    ["float", [
        ["RscText", 60222, 0.22, 0.42, 0.56, 0.32, "", false],
        ["FACRscFormLabel", 60224, 0.24, 0.43, 0.52, 0.034, "Apply selected loadout to squad member:", false],
        ["FACRscListDark", 60220, 0.24, 0.47, 0.52, 0.18, "", false],
        ["FACRscPrimaryBtn", 60221, 0.24, 0.66, 0.25, 0.04, "Apply to selected", false, "applyToConfirm", []],
        ["FACRscPrimaryBtn", 60223, 0.51, 0.66, 0.25, 0.04, "Cancel", false, "applyToCancel", []]
    ]],
    ["page", "main", [
        ["list", "Faction", "", -1, 0.12, 60210, "filterChanged", []],
        ["edit", "Search", "", -1, 60211, "filterChanged", []],
        ["list", "Choose loadout", "", -1, "fill", 60201, "unitSelChanged", []],
        ["section", "Quick add items"],
        ["buttonRow", [
            ["Zip ties x2", 60215, "addZipties", [], "primary"],
            ["IR strobe", 60216, "addIrStrobe", [], "primary"],
            ["IFAK", 60217, "addIfak", [], "primary"]
        ]],
        ["buttonRow", [
            ["Bandages", 60218, "addBandages", [], "primary"],
            ["Add 343", 60207, "addRadio343", [], "primary"],
            ["Add 152", 60208, "addRadio152", [], "primary"]
        ]],
        ["section", "Manage roles"],
        ["buttonRow", [
            ["Make me interpreter", 60232, "setCivInterpreter", [], "primary"],
            ["Remove interpreter", 60233, "clearCivInterpreter", [], "neutral"]
        ]],
        ["buttonRow", [
            ["Make me Intel specialist", 60234, "setIntelSpecialist", [], "primary"],
            ["Remove Intel specialist", 60235, "clearIntelSpecialist", [], "neutral"]
        ]],
        ["buttonRow", [
            ["Make me Engineer", 60236, "setEngineer", [], "primary"],
            ["Remove Engineer", 60237, "clearEngineer", [], "neutral"]
        ]],
        ["text", 60205, 0.03, ""]
    ]]
];

FAC_gui_spec_recruit = [
    ["title", "RECRUIT", 0.16],
    ["handler", "FAC_recruitGui_fnc"],
    ["frame", "full"],
    ["refresh", true],
    ["default", "recruit"],
    ["tabs", [
        ["recruit", "Recruit", 60941],
        ["roster", "Manage", 60942]
    ]],
    ["page", "recruit", [
        ["buttonRow", [
            ["Custom loadouts...", 60943, "sourcePick", ["preset"], "primary"],
            ["Faction units...", 60944, "sourcePick", ["std"], "idle"]
        ]],
        ["list", "Assign to group", "", 60951, 0.14, 60952, "", []],
        ["list", "Faction", "", 60958, 0.14, 60949, "factionChanged", []],
        ["edit", "Search", "", 60959, 60950, "filterChanged", []],
        ["list", "Choose unit to recruit", "", 60947, "fill", 60948, "unitSelChanged", []],
        ["button", "Recruit unit", "", 60953, "recruit", [], "primary"]
    ]],
    ["page", "roster", [
        ["list", "Recruited units (select to dismiss)", "", 60954, "fill", 60955, "", []],
        ["button", "Dismiss selected", "", 60956, "dismiss", [], "danger"]
    ]]
];

FAC_gui_spec_fires = [
    ["title", "FIRES", 0.14],
    ["handler", "FAC_firesGui_fnc"],
    ["frame", "full"],
    ["refresh", true],
    ["default", "range"],
    ["tabs", [
        ["range", "Range", 60740, "setPage", [0]],
        ["drill", "Timed drill", 60741, "setPage", [1]]
    ]],
    ["shared", [
        ["list", "Slots (spawned / location)", "The drill uses the slot you select here.", 60744, 0.18, 60701, "slotSelChanged", []],
        ["text", 60739, 0.04, ""]
    ]],
    ["page", "range", ["columns",
        [
            ["list", "Approved piece", "", 60743, "fill", 60703, "selChanged", []],
            ["buttonRow", [
                ["Spawn at slot", 60706, "spawn", [], "primary"],
                ["Despawn at slot", 60707, "despawn", [], "warn"]
            ]]
        ],
        [
            ["picture", 60704, "ratio"],
            ["text", 60705, 0.06, ""],
            ["list", "Ammo type", "", 60754, 0.16, 60710, "ammoSelChanged", []],
            ["slider", "Total rounds: 0", "", 60712, -1, 60711, "ammoSliderChanged", "args"],
            ["buttonRow", [
                ["Apply ammo load", 60713, "ammoApply", [], "primary"],
                ["Full rearm", 60708, "rearm", [], "neutral"]
            ]],
            ["button", "Spawn ammo truck", "", 60714, "spawnAmmoTruck", [], "neutral"],
            ["text", 60724, 0.03, ""],
            ["buttonRow", [
                ["Place drone (map click)", 60721, "droneMapPlace", [], "neutral"],
                ["Despawn drone", 60722, "droneDespawn", [], "warn"]
            ]]
        ]
    ]],
    ["page", "drill", ["columns",
        [
            ["section", "Timed drill", 60746],
            ["edit", "Min m", "Closest random distance from the pit.", 60747, 60731, "", [], "600"],
            ["edit", "Max m", "Farthest random distance from the pit.", 60748, 60732, "", [], "1200"],
            ["combo", "Target", "", -1, 60733, "", []],
            ["combo", "Bearing / randomization", "", 60738, 60737, "", []],
            ["buttonRow", [
                ["Start drill", 60735, "drillStart", [], "primary"],
                ["End drill", 60736, "drillEnd", [], "warn"]
            ]]
        ],
        [
            ["text", 60752, 0.42, "Pick the occupied range slot the drill uses. Min and Max are the random distance band in metres from the pit. The server looks for dry land at least 500 m from base. Bearing follows the pit axis or a random approach. The drill ends when the car is damaged or destroyed."]
        ]
    ]]
];

FAC_gui_spec_teleport = [
    ["title", "FAST TRAVEL", 0.20],
    ["handler", "FAC_teleportGui_fnc"],
    ["frame", "full"],
    ["refresh", true],
    ["default", "dest"],
    ["tabs", [
        ["dest", "Destinations", 60609],
        ["players", "Players", 60619]
    ]],
    ["page", "dest", [
        ["text", 60605, 0.03, "Destinations - click twice to travel"]
    ]],
    ["page", "players", ["columns",
        [
            ["list", "Active players", "", 60616, "fill", 60611, "selChangedPlayers", []],
            ["button", "Teleport", "", 60612, "teleportPlayer", [], "primary"]
        ],
        [
            ["structured", 60614, 0.08, ""],
            ["structured", 60615, 0.40, ""]
        ]
    ]]
];

FAC_gui_spec_build = [
    ["title", "BUILD", 0.16],
    ["handler", "FAC_buildGui_fnc"],
    ["frame", "full"],
    ["refresh", true],
    ["default", "build"],
    ["tabs", [
        ["build", "Place", 60966],
        ["placed", "Placed", 60967]
    ]],
    ["page", "build", ["columns",
        [
            ["segments", "Build", "Fortifications use the object list. Each base building unlocks one service.", [
                ["Fortifications", 60969, "setStream", ["fort"], "primary"],
                ["Base buildings", 60970, "setStream", ["base"], "idle"]
            ]],
            ["text", 60956, 0.028, "Supply"],
            ["combo", "Category", "", -1, 60961, "catChanged", []],
            ["combo", "Type", "", -1, 60962, "subChanged", []],
            ["edit", "Search", "", -1, 60963, "searchChanged", []],
            ["list", "Pieces", "", -1, "fill", 60951, "selChanged", []],
            ["button", "Place", "", 60953, "place", [], "primary"]
        ],
        [
            ["picture", 60968, "ratio", 1.778, 0.32],
            ["text", 60954, 0.056, ""],
            ["buttonRow", [
                ["Simulation: On", 60980, "toggleOpt", ["sim"], "primary"],
                ["Damage: On", 60981, "toggleOpt", ["damage"], "primary"]
            ]],
            ["buttonRow", [
                ["Simple object: Off", 60982, "toggleOpt", ["simple"], "idle"],
                ["Place multiple: Off", 60983, "toggleOpt", ["multi"], "idle"]
            ]],
            ["structured", 60955, 0.24, "<t color='#9ea3ad' size='0.85'>WASD moves the camera. Mouse looks. Wheel sets distance.<br/>Q and E turn the piece. Page Up raises it. Page Down lowers it.<br/>T follows the slope. Space places the piece.<br/>Esc returns to this menu. Ctrl+Z undoes the last piece you placed.<br/>Place multiple stays in the camera.<br/>A simple object ignores simulation and damage.</t>"]
        ]
    ]],
    ["page", "placed", ["fit", [
        ["list", "Placed", "Select a piece.", -1, "fill", 60964, "", []],
        ["button", "Delete", "", 60965, "deletePlaced", [], "danger"]
    ]]]
];

FAC_gui_spec_buildSign = [
    ["title", "WRITE", 0.16],
    ["handler", "FAC_buildSignGui_fnc"],
    ["frame", "compact"],
    ["refresh", false],
    ["default", "sign"],
    ["page", "sign", [
        ["edit", "Text", "Type \n for a new line. 180 characters max. Write sets the text. Clear erases it.", -1, 60971, "", []],
        ["buttonRow", [
            ["Write", 60973, "write", [], "primary"],
            ["Clear", 60974, "clear", [], "danger"]
        ]]
    ]]
];

FAC_gui_allSpecs = [
    ["scenario", FAC_gui_spec_scenario],
    ["medical", FAC_gui_spec_medical],
    ["cqb", FAC_gui_spec_cqb],
    ["sniper", FAC_gui_spec_sniper],
    ["range", FAC_gui_spec_range],
    ["vehicle", FAC_gui_spec_vehicle],
    ["missions", FAC_gui_spec_missions],
    ["loadout", FAC_gui_spec_loadout],
    ["recruit", FAC_gui_spec_recruit],
    ["fires", FAC_gui_spec_fires],
    ["teleport", FAC_gui_spec_teleport],
    ["build", FAC_gui_spec_build],
    ["buildSign", FAC_gui_spec_buildSign]
];
