// =============================================================================
// Config - Face's Dynamic Sandbox mission configuration
// =============================================================================
// FADE_heliClasses is built dynamically from CfgVehicles (see initServer.sqf)
// Scenario settings (weather, time, factions) are managed via Scenario GUI.
// Unit arrays below are fallbacks when faction has no units (e.g. mod not loaded).

// -----------------------------------------------------------------------------
// Scenario defaults (Scenario GUI overrides these)
// -----------------------------------------------------------------------------
FADE_scenarioTime = 18;
FADE_scenarioWeather = "Clear";
FADE_scenarioEnemyFaction = "OPF_F";
FADE_scenarioFriendlyFaction = "BLU_F";
FADE_scenarioCivFaction = "CIV_F";
// Optional exact CfgFactionClasses names — if non-empty and the class exists and side matches, wins over display-name pick in initServer (use when mod display strings drift). initServer also prefers USMC / 3CB African factions by display name when these stay empty.
FADE_startupFactionFriendly = "";
FADE_startupFactionEnemy = "";
FADE_startupFactionCiv = "";
FADE_civiliansEnabled = true;  // When false, no ambient civilians (zones, road vehicles, civ aircraft)
// Legacy upper bound for Eden CIV_T_* cleanup; runtime count is set by FADE_civZonesFromLocations_build (initServer).
FADE_civTriggerIndexMax = 109;
// Named-location civ zones: min straight-line distance from FADE_basePos (m); optional type list / anchor class in missionNamespace
FADE_civZoneMinDistFromBase = 2000;
// SMEAC / intel "Area:" label: search radius (m) for map locations; pick balances distance vs settlement size (see FADE_getTopographySummary in Missions.sqf)
FADE_topographyLocationRadius = 8000;
// FADE_civZoneLocationTypes = ["NameCityCapital","NameCity","NameVillage","NameLocal"];  // optional override
// FADE_civZoneSkipWater = true;   // optional
// FADE_civZoneAnchorClass = "Land_HelipadEmpty_F";  // optional invisible anchor
FADE_aoStrength = "Mid";       // AO mission strength: "Low", "Mid", "High" (used by AO mission type)
// Operation (global): number of enemy-held civ zones (Scenario GUI); must not exceed built zone count
FADE_operationZoneCount = 6;
// Legacy: random pool if ever needed — Operation uses FADE_operationZoneCount from scenario
FADE_operationZoneCountChoices = [4, 6, 10];
// Intercept Convoy: minimum straight-line distance (m) between road start and road end (mission picks random roads; no Eden ROAD_SP_*).
FADE_convoyMinRouteM = 5000;
// Operation: enemy-held zone spawns an extra patrol vehicle every (min..max) seconds (randomized per tick)
FADE_operationVehicleResupplyMin = 240;
FADE_operationVehicleResupplyMax = 360;
// Operation: minimum seconds between QRF waves (contested zone under attack)
FADE_operationQrfCooldown = 180;
// Operation: max fleet land vehicles (alive+canMove; QRF & aircraft excluded from count)
FADE_operationMaxFleetVehicles = 10;
// Operation: spawn position must be at least this far from all human players (m)
FADE_operationSpawnMinDistPlayers = 1000;
// Operation: delete fleet vehicles farther than this from any player every FADE_operationCleanupInterval (m)
FADE_operationCleanupDistPlayers = 2000;
FADE_operationCleanupInterval = 600;
FADE_enemySkill = 0.2;         // Default enemy AI skill (Scenario GUI can override)
FADE_opforPopulationSetting = "Auto";  // default Auto; also "VeryLow", "Low", "Normal", "High", "VeryHigh", "Insane"
FADE_opforLauncherSetting = "Normal";     // "Normal", "Reduced", "Minimal", "None" — AT launchers (not MANPADS AA)
FADE_opforAirSetting = "Off";               // "Off", "Low" (max 1, 10 min cooldown), "Medium" (max 2, 5 min) — OPFOR air after AI spots BLUFOR + random delay (initServer FADE_opforAir_*)
FADE_limitGearToFriendlyFaction = false;  // When true, Loadout and Vehicle GUIs restrict to chosen Friendly faction
FADE_limitToPresetLoadouts = false;          // When true, Loadout GUI allows preset loadouts only
FADE_teleportToPlayerMode = 0;            // 0 = all players can teleport-to-player, 1 = SL/admin/Zeus only
// Civilian talk (ambient foot civs): Scenario GUI can require FADE_civInterpreter for meaningful dialogue; non-interpreters still get the GUI with a barrier label and ??? replies only.
FADE_civTalkInterpretersOnly = false;
FADE_civTalkLangBarrierText = "You do not understand the language this person is speaking.";
FADE_civTalkNoLangReplies = ["???", "????", "? ? ?", "...?"];
FADE_civTalkMaxDistM = 6;
FADE_civTalkOpforRadiusM = 1000;
FADE_civTalkCarRadiusM = 250;
FADE_civTalkIntelChance = 0.75;
FADE_civTalkOpforFollowupIntelChance = 0.5;
FADE_civTalkBtnOpforDefault = "Seen any OPFOR?";
FADE_civTalkOpforFollowupButtonText = "Are you sure...?";
FADE_civTalkCooldownS = 45;
FADE_civTalkPositiveChance = 0.5;
FADE_civTalkGreetingPositive = ["Hello. Can I help you?", "Good day. What do you need?", "Yes? Make it quick.", "I do not want trouble—what is it?"];
FADE_civTalkGreetingNegative = ["What do you want?", "Leave me alone.", "I am busy.", "Do not point that thing at me."];
FADE_civTalkRumoursPositive = ["They say the road north is quiet.", "People talk, but I pay no attention.", "Only that strangers have been asking questions.", "I heard engines on the main road earlier.", "Folk are keeping their heads down."];
// Heard rumours — extra lines when a global mission type with QRF is active (see FADE_globalMissionTypesWithQrf; server picks ~half the time when cooperative).
FADE_civTalkRumoursPositiveQrf = [
    "Word is, when it gets loud out there, their trucks do not take long to show up.",
    "Folk say the army moves fast once someone starts shooting—best not to stick around.",
    "I heard they like to pile on quick if things go hot—just what people say.",
    "Rumour is their quick-response runs on a hair trigger lately.",
    "If you hear a firefight, expect company soon—that is what everyone whispers."
];
// Global mission types that use truck/zone QRF (excludes e.g. Intercept Convoy). Used for rumour hints only.
FADE_globalMissionTypesWithQrf = ["AreaOfOperations", "Hostage", "HVT", "ClearArea", "CAS", "SearchDestroy", "Operation", "AssetRetrieval", "CSAR", "EscapeEvasion"];
FADE_civTalkRumoursNegative = ["I do not listen to gossip.", "I have nothing to tell you.", "Why are you asking me this?", "You should not be here asking questions.", "I keep to myself."];
FADE_civTalkGestureAway = ["Fine, I am leaving.", "All right, all right.", "Okay, okay."];
FADE_civTalkGestureStay = ["I will stay.", "Okay, I will not move.", "Understood."];
FADE_civTalkGestureDown = ["I am getting down!", "Down, down!", "Do not shoot!"];
FADE_civTalkGestureNoUnderstandFmt = "%1 does not understand you.";
FADE_civTalkArrestUncooperativeRadiusM = 500;
FADE_civTalkArrestComply = ["I am not resisting.", "Okay, I will come quietly.", "Please, do not hurt me."];
FADE_civTalkArrestRefuse = ["You have no authority!", "I am not going anywhere with you.", "Leave me alone!"];
FADE_civTalkRefuseOpfor = ["I'm not telling you anything.", "I have nothing to say to you.", "Ask someone else.", "I did not see anything—understand?"];
FADE_civTalkRefuseCar = ["Go away.", "Find your own ride.", "I do not have keys for you.", "That is not how this works."];
FADE_civTalkOpforNone = ["I have not seen any soldiers.", "No, nothing like that around here."];
FADE_civTalkOpforUnsure = ["I am not sure.", "Maybe, I did not get a good look."];
FADE_civTalkCarNone = ["I do not know of any free car nearby.", "Sorry, no empty vehicle around here.", "Nothing parked that I can think of.", "If there is one, it is not mine to offer."];
// Optional second line in replies: time-of-day + nearest settlement name (server: FADE_civTalk_contextLines).
FADE_civTalkContextAppendChance = 0.35;
FADE_civTalkCtxNight = ["It is hard to see at night.", "The dark makes everyone nervous.", "You should not be out here after dark."];
FADE_civTalkCtxMorning = ["The morning is quiet.", "Barely anyone is about yet.", "Early light—easy to miss details."];
FADE_civTalkCtxAfternoon = ["Heat shimmers on the road.", "The day drags.", "Sun is high; hard to be sure of anything."];
FADE_civTalkCtxNearFmt = ["Not far from %1.", "Toward %1...", "People still talk about %1.", "We are in the shadow of %1."];
// When true, actionable civilian intel (OPFOR sighting / vehicle tip) appends an entry to map → Intel (see Briefing.sqf / FADE_civTalk_clientAppendIntelDiary).
FADE_civTalkIntelDiary = true;
// When true, building intel (hold-to-read props) and Asset Retrieval package pickup append to map → Intel (FADE_intel_clientAppendIntelDiary).
FADE_intelDiaryLog = true;
// Civilian talk — cutscene (local to initiating player) + animation names (switchMove; clear with "" before changing)
FADE_civTalkFadeOutSec = 1.2;
FADE_civTalkFadeInSec = 1;
FADE_civTalkFaceSeparationM = 3;
// Cutscene camera: modelToWorld on player — right / back / up (m) in Man space (X right, Y forward, Z up); lower FOV = more zoom (tuned to match debug).
FADE_civTalkCamBehindM = 3;
FADE_civTalkCamRightM = 2;
FADE_civTalkCamHeightAbovePlayerASL = 1;
FADE_civTalkCamFov = 0.2;
FADE_civTalkReturnIdleDelay = 5;
FADE_civTalkIntelPoseSec = 4.5;
FADE_civTalkAnimPlayerIdle = "acts_millerIdle";
// Unused while dialogue keeps the player in idle (see CivTalkGui).
FADE_civTalkAnimPlayerTalk = "Acts_StandingSpeakingUnarmed";
FADE_civTalkAnimCivIdle = "Acts_CivilIdle_2";
// Unused: dialogue keeps civ in idle; only FADE_civTalkAnimCivIntel plays on intel lines.
FADE_civTalkAnimCivTalk = "Acts_CivilTalking_1";
FADE_civTalkAnimCivIntel = "Acts_Pointing_Right";
// Building intel: spawns when a virtual garrison activates; server generates text on consume (`rsc/FADE_IntelServer.sqf`, `rsc/FADE_IntelClient.sqf`).
// **Read intel** (hold) or **pick up** the prop (e.g. ACE): both award the same FADE hint/diary when a BLUFOR player is credited.
FADE_intelEnabled = true;
FADE_intelSpawnChanceOnGarrison = 0.5;
FADE_intelHoldDurationSec = 5;
FADE_intelScopeRadiusM = 1200;
FADE_intelInteractDistM = 6;
// Random pick per spawn (only classes present in CfgVehicles are used; server also tries Land_Clipboard_F if Clipboard_F is missing).
// Avoid class names starting with "Intel_" (e.g. Intel_Photos_F): ACE Intel Items adds its own map diary for those; FADE cannot remove that duplicate row.
FADE_intelObjectClasses = [
    "Clipboard_F",
    "Land_Wallet_01_F",
    "Land_Laptop_02_unfolded_F",
    "Land_MobilePhone_smart_F",
    "Land_SatellitePhone_F",
    "Land_PortableLongRangeRadio_F"
];
FADE_intelMaxLinesPerRead = 3;
FADE_intelSpecificLineChance = 0.42;
FADE_intelBroadcastToGroup = true;
FADE_intelMapMarkerOnSpecific = true;
FADE_intelMapMarkerTTL = 480;
// Scenario GUI can require FADE_intelSpecialist role to process intel directly.
FADE_intelSpecialistsOnly = false;
// Client (initPlayerLocal): seconds between HQ auto-heal checks when inside radius of FADE_basePos.
FADE_hqHealIntervalSec = 40;

// Loadout box Eden object names - all get Manage My Loadout, Save loadout, ACE Arsenal (if loaded)
FADE_loadoutBoxNames = ["LOADOUTBOX", "LOADOUTBOX_1", "LOADOUTBOX_2", "LOADOUTBOX_3", "LOADOUTBOX_4"];
// Pad names - Eden object variable names (expand as needed)
FADE_padNames = ["HP_1", "HP_2", "HP_3", "HP_4", "HP_5", "HP_6", "HP_7", "HP_8"];
// FIRES range: game logic object names (position + direction = spawn transform). Match mission.sqm / expand as needed.
FADE_firesPosNames = ["firesPos_1", "firesPos_2", "firesPos_3", "firesPos_4", "firesPos_5", "firesPos_6"];
// FIRES GUI slot list labels (same order / length as FADE_firesPosNames).
FADE_firesPosDisplayNames = [
    "Position 1 (East)",
    "Position 2 (East)",
    "Position 3 (East)",
    "Position 4 (West)",
    "Position 5 (West)",
    "Position 6 (West)"
];
// FIRES fall-of-shot: Eden object names for per-slot impact RTT screens (same order / length as FADE_firesPosNames). Texture index 0 = video (see AGENTS_EDEN).
FADE_firesImpactScreenNames = [
    "firesScreenPos_1",
    "firesScreenPos_2",
    "firesScreenPos_3",
    "firesScreenPos_4",
    "firesScreenPos_5",
    "firesScreenPos_6"
];
// Assigned item class given to the player who spawns the range observer drone (faction-specific if needed).
FADE_firesUavTerminalClass = "B_UavTerminal";
// Range observer UAV CfgVehicles class (vanilla Darter default).
FADE_firesRangeDroneClass = "B_UAV_01_F";
// Seconds to show impact-area RTT on firesScreenPos_* after a qualifying round lands.
FADE_firesImpactFeedDuration = 10;
// Timed lane drills (FIRES GUI): hint grid/elev to players within this radius (m) of the slot logic.
FADE_firesDrillNotifyRadiusM = 100;
// Server: drill spawns FADE_firesDrillCarClass + burning barrel (smoke); optional FADE_firesDrillFireClass ("" = none).
FADE_firesDrillCarClass = "C_Offroad_01_F";
FADE_firesDrillBarrelClass = "MetalBarrel_burning_F";
FADE_firesDrillFireClass = "";
// [min, max] meters from car to smoke barrel (FADE_firesDrillBarrelClass).
FADE_firesDrillBarrelDistanceM = [4, 7];
// Timed drill spawn point: min horizontal distance from FADE_basePos (m). Ignored if base position is unset/invalid.
FADE_firesDrillMinDistFromBaseM = 500;
// Max random samples (dry land + outside base radius) before start fails with systemChat to the caller.
FADE_firesDrillSpawnMaxAttempts = 25;
// Drill completes on first real vehicle damage (splash/part damage counts) or destruction — not aggregate `damage` threshold.
// [display label, unused class] — kept for FIRES GUI combo; spawn uses FADE_firesDrillCarClass.
FADE_firesDrillTargetDefinitions = [
    ["Drill vehicle (offroad)", "C_Offroad_01_F"]
];
// RTT setObjectTextureGlobal indices on firesScreenPos_* . Use [0] for the main panel only; adding 1+ repeats the feed on PiP/bezel selections (tiled picture-in-picture).
FADE_firesImpactVideoTextureIndices = [0];
// 512+ recommended; non–power-of-two sizes often produce black RTT on some GPUs.
FADE_firesImpactVideoRttResolution = 512;
// r2t(name, aspect): 1.0 matches common PiP/RTT examples; widen/narrow if the panel looks stretched.
FADE_firesImpactRttAspect = 1;
// Server: projectile position poll for impact PiP (smaller = more accurate, more server load during arty fire).
FADE_firesProjectileTrackSleep = 0.1;
// Camera height (m) above impact for PiP (local anchor = impact point).
FADE_firesImpactCamHeightM = 90;
// Pads where planes cannot spawn (helicopters can use any pad)
FADE_planeForbiddenPads = ["HP_1", "HP_2"];
// Vehicle GUI (aircraft): when whitelist is ON, list is restricted to these CfgVehicles classnames (exact match).
FADE_aircraftSpawnWhitelist = [
    "RHS_AH64D_wd",
    "RHS_MELB_AH6M",
    "RHS_AH1Z",
    "RHS_UH1Y_UNARMED_d",
    "RHS_UH1Y_d",
    "RHS_UH1Y_FFAR_d",
    "RHS_MELB_MH6M",
    "vtx_MH60M",
    "vtx_MH60M_DAP",
    "vtx_MH60M_DAP_MLASS",
    "TF373_SOAR_MH47G",
    "TF373_SOAR_MH47G_EasyActions",
    "TF373_SOAR_MH47G_No_Rear_Guns",
    "TF373_SOAR_MH47G_No_Rear_Guns_EasyActions",
    "B_Heli_Transport_03_F",
    "B_Heli_Transport_03_unarmed_F",
    "vn_b_air_ch47_01_01",
    "vn_b_air_ch47_03_01",
    "RHS_CH_47F_light",
    "RHS_CH_47F_10_cargo",
    "rhsusf_CH53E_USMC_D",
    "rhsusf_CH53e_USMC_D_cargo",
    "rhsusf_CH53E_USMC_GAU21_D",
    "SADO_MV22",
    "vn_b_air_uh1b_01_01",
    "vn_b_air_uh1c_07_01",
    "vn_b_air_uh1c_06_01",
    "vn_b_air_uh1c_04_01",
    "vn_b_air_uh1c_02_01",
    "vn_b_air_uh1c_05_01",
    "vn_b_air_uh1c_01_01",
    "vn_b_air_uh1d_01_01",
    "vn_b_air_uh1d_02_01",
    "vn_b_air_ah1g_03",
    "vn_b_air_ah1g_04",
    "vn_b_air_ah1g_05",
    "vn_b_air_ah1g_01",
    "vn_b_air_ah1g_07",
    "vn_b_air_ah1g_08",
    "vn_b_air_ah1g_09",
    "vn_b_air_ah1g_10",
    "vn_b_air_ah1g_06",
    "dcx_generic_ch34_04",
    "dcx_generic_ch34_03",
    "RHS_Mi24P_vvs",
    "RHS_Mi24V_vvs",
    "RHS_Mi24Vt_vvs",
    "UK3CB_UN_B_Mi_24G",
    "rhsgref_cdf_b_Mi24D",
    "RHS_Mi8AMT_vvs",
    "RHS_Mi8AMTSh_vvs",
    "MMM_Mi8AMTSh_Armed",
    "MMM_Mi8AMTSh_UnArmed",
    "MMM_Mi8AMTShVM_Armed",
    "MMM_Mi8AMTShVM_UnArmed",
    "RHS_Mi8mt_vvs",
    "RHS_Mi8mt_Cargo_vvs",
    "RHS_Mi8MTV3_vvs",
    "RHS_Mi8mtv3_Cargo_vvs",
    "RHS_Mi8MTV3_heavy_vvs",
    "RHS_Mi8T_vvs",
    "USAF_F35A",
    "USAF_F35A_LIGHT",
    "USAF_F35A_STEALTH",
    "FIR_F18C_RAAF",
    "FIR_F18C_Blank_Aggressor",
    "USAF_AC130U",
    "RHS_C130J",
    "RHS_C130J_Cargo",
    "USAF_C130J",
    "USAF_C130J_Cargo",
    "RHS_A10",
    "USAF_A10",
    "RHS_Su25SM_vvs",
    "RUS_VKS_su25sm",
    "rhs_mig29s_vvs",
    "rhs_mig29sm_vvs",
    "USAF_RQ4A",
    "RHSGREF_A29B_HIDF",
    "vn_b_air_f4c_at",
    "vn_b_air_f4c_bmb",
    "vn_b_air_f4c_cap",
    "vn_b_air_f4c_cas",
    "vn_b_air_f4c_cbu",
    "vn_b_air_f4c_chico",
    "vn_b_air_f4c_ehcas",
    "vn_b_air_f4c_gbu",
    "vn_b_air_f4c_hbmb",
    "vn_b_air_f4c_hcas",
    "vn_b_air_f4c_lbmb",
    "vn_b_air_f4c_lrbmb",
    "vn_b_air_f4c_mbmb",
    "vn_b_air_f4c_mr",
    "vn_b_air_f4c_sead",
    "vn_b_air_f4c_ucas",
    "vn_b_air_f100d_at",
    "vn_b_air_f100d_bmb",
    "vn_b_air_f100d_cap",
    "vn_b_air_f100d_cas",
    "vn_b_air_f100d_cbu",
    "vn_b_air_f100d_ehcas",
    "vn_b_air_f100d_hbmb",
    "vn_b_air_f100d_hcas",
    "vn_b_air_f100d_lbmb",
    "vn_b_air_f100d_mbmb",
    "vn_b_air_f100d_mr",
    "vn_b_air_f100d_sead",
    "vn_o_air_mig19_at",
    "vn_o_air_mig19_bmb",
    "vn_o_air_mig19_cap",
    "vn_o_air_mig19_cas",
    "vn_o_air_mig19_gun",
    "vn_o_air_mig19_hbmb",
    "vn_o_air_mig19_mr",
    "vn_o_air_mig21_at",
    "vn_o_air_mig21_atgm",
    "vn_o_air_mig21_bmb",
    "vn_o_air_mig21_cap",
    "vn_o_air_mig21_cas",
    "vn_o_air_mig21_gun",
    "vn_o_air_mig21_hbmb",
    "vn_o_air_mig21_hcas",
    "vn_o_air_mig21_mr",
    "SPE_FW190F8",
    "SPE_P47"
];
// Helipad markers (map markers to update when aircraft spawn/despawn). Index = pad order in FADE_helipadList. Empty = no marker.
FADE_helipadMarkers = ["HeliMark_1", "HeliMark_2", "HeliMark_3", "HeliMark_4", "HeliMark_5", "HeliMark_6", "HeliMark_7", ""];
// Seconds between pad marker text refreshes (initServer); 8s is enough for parked aircraft display.
FADE_helipadMarkerUpdateInterval = 8;

// Friendly / enemy infantry fallbacks when FADE_getUnitsForFaction returns empty (optional: set to mod rifleman classes).
// Named FADE_fallback* so initPlayerLocal can load Config without overwriting missionNamespace
// FADE_friendlyUnits / FADE_enemyUnits built on the server (listen-server host shares missionNamespace with client).
FADE_fallbackFriendlyUnits = [
    "B_Soldier_TL_F",
    "B_Soldier_F",
    "B_Soldier_F",
    "B_Soldier_AR_F",
    "B_medic_F",
    "B_Soldier_F"
];

FADE_fallbackEnemyUnits = [
    "O_Soldier_TL_F",
    "O_Soldier_F",
    "O_Soldier_F",
    "O_Soldier_AR_F",
    "O_Soldier_F"
];

// Cargo classes for resupply (sling-load compatible preferred)
FADE_cargoClasses = [
    "B_Slingload_01_Cargo_F",
    "B_Slingload_01_Ammo_F",
    "B_Slingload_01_Fuel_F",
    "B_Slingload_01_Repair_F"
];

// -----------------------------------------------------------------------------
// Ambient civilians (CIV_T_* anchors from FADE_civZonesFromLocations). Eden ROAD_SP_* only for Intercept Convoy.
// Fallbacks when faction has no units/vehicles
// -----------------------------------------------------------------------------
FADE_civUnitClasses = [
    "C_man_1",
    "C_man_1_1_F",
    "C_man_1_2_F",
    "C_man_1_3_F",
    "C_man_polo_1_F",
    "C_man_polo_2_F",
    "C_man_polo_3_F",
    "C_man_polo_4_F",
    "C_man_polo_5_F",
    "C_man_polo_6_F"
];
FADE_civRoadVehicleClasses = [
    "C_Offroad_01_F",
    "C_Offroad_02_unarmed_F",
    "C_Hatchback_01_F",
    "C_SUV_01_F",
    "C_Van_01_transport_F",
    "C_Truck_02_covered_F"
];
FADE_civParkedVehicleClasses = [
    "C_Hatchback_01_F",
    "C_Offroad_01_F",
    "C_SUV_01_F",
    "C_Van_01_transport_F"
];
FADE_civSpawnRadius = 1000;  // enemy patrol / parked road search (foot civs use FADE_civFootSpawnRadius)
FADE_enemyPatrolMinDistFromPlayersM = 400;  // ambient enemy patrol: spawn positions must be at least this 2D m from every alive player
FADE_civFootSpawnRadius = 200;  // walking civ spawn disk around zone centre (uniform spread + min separation)
FADE_civFootSpawnMinSep = 28;   // min 2D m between new foot spawns and earlier ones in same zone (0 = off; relaxed automatically if no slot found)
// Parked empty civ cars: prefer roads beside buildings (not empty highways hundreds of m out)
FADE_civParkedBuildingScanRadius = 380;       // find buildings within this of zone centre for road sampling
FADE_civParkedRoadFromBuildingRadius = 100;   // nearRoads from each sampled building
FADE_civParkedCenterRoadRadius = 260;         // fallback ring: roads near town anchor (still require near-building for slot)
FADE_civParkedWideRoadRadius = 400;           // wider fallback + cap passed to tryRoadParkPosition
FADE_civParkedNearBuildingMax = 125;          // parked spot must have House/Building within this (0 = skip check in picker)
FADE_civParkedMinAlongRoadM = 7;              // park along segment at least this far from each end (avoids junction nodes)
FADE_civParkedCrossRoadScan = 24;           // nearRoads radius when looking for other segments near the slot
FADE_civParkedCrossRoadClearM = 6.8;        // min 2D m from crossing segment centerline (center + fore/aft samples)
FADE_civParkedCrossRoadAngleMin = 38;       // acute angle (deg): above this, other segment counts as "crossing" for clearance
FADE_civParkedCrossRoadHalfLen = 4.5;       // half vehicle length (m) for fore/aft clearance samples along heading
FADE_civWanderRadius = 100;  // max distance walking civs move from spawn before looping back
FADE_civPlayerActivateDist = 900;
FADE_civPlayerDeactivateDist = 1150;
FADE_civGlobalMaxAlive = 55;   // 0 = no cap; Scenario GUI Factions tab sliders also set missionNamespace
FADE_civDensityScale = 1;      // multiplier on tier-based foot civ min/max (capital/city/village/local)
FADE_civUnitCullDist = 750;    // delete ambient foot civ groups farther than this from every player (0 = off)
FADE_civZoneBuildingRadius = 500; // named location must have a House/Building within this (2D) to get foot/parked ambient
FADE_civCountMin = 5;
FADE_civCountMax = 5;
FADE_civSpawnStaggerDelay = 1.5;  // seconds between spawn batches (lazy-load to reduce performance hit)
FADE_civSpawnBatchSize = 2;       // civs per batch
FADE_civParkedCountMin = 2;
FADE_civParkedCountMax = 5;
FADE_civCheckInterval = 55;
FADE_civMaxActiveZones = 4;  // max civ zones (and their patrol zones) active at once
FADE_roadVehicleMax = 5;
// Legacy (unused): old ROAD_SP_* ambient interval; ambient road civs now use FADE_roadSpawnTickSec + chance
FADE_roadSpawnIntervalMin = 90;
FADE_roadSpawnIntervalMax = 180;
FADE_roadSpawnTickSec = 75;       // check interval while any civ zone is active
FADE_roadSpawnChance = 1;        // each tick: probability of attempting a spawn (1 = every tick; still capped by FADE_roadVehicleMax)
FADE_roadSpawnRingMin = 1000;    // m from active zone centre (ambient road spawn)
FADE_roadSpawnRingMax = 2500;
FADE_roadSpawnPlayerClear = 500; // spawn must be farther than this from any player
FADE_roadFinalWpMinDist = 2000;  // final waypoint: random point at least this far from furthest-zone centre
// Ambient civ road traffic: delete if farther than this from every player (0 = disable distance cleanup)
FADE_civVehCleanupDist = 3500;
// Civ ambient aircraft: same idea; -1 = use (FADE_civVehCleanupDist * 1.75) so air can stay visible a bit longer
FADE_civAirCleanupDist = -1;
FADE_civDebug = false;  // systemChat for spawn/despawn/road vehicle actions
FADE_civDebugMarkers = false;  // when true, show map markers for active civ zones (Civ: zoneId)
// Debug: systemChat for dynamic roadblocks (rsc\DynamicRoadblocks.sqf — spawn, despawn, patrols off)
FADE_checkpointDebug = false;
// Dynamic roadblocks / ambush props along base <-> mission corridor (rsc\DynamicRoadblocks.sqf). Requires Enemy Patrols ON.
// Counts all friendly players for distance (including helicopters) once beyond FADE_dynamicRoadblockMinDistFromBase.
FADE_dynamicRoadblocksEnabled = true;
FADE_dynamicRoadblockPollSec = 14;
FADE_dynamicRoadblockMinDistFromBase = 1500;  // only consider players this far from base for spawning logic
FADE_dynamicRoadblockSpawnMinM = 750;         // roadblock this far from at least one such player
FADE_dynamicRoadblockSpawnMaxM = 2800;
FADE_dynamicRoadblockDespawnM = 3600;         // delete if no friendly player within this range
// Civ-zone tied roadblock: when the zone despawns, keep the block if any alive human player is within this 2D m (0 = always despawn with zone)
FADE_dynamicRoadblockZoneGoneRetainPlayerM = 1000;
FADE_dynamicRoadblockMaxActive = 5;
FADE_dynamicRoadblockMinSpacingM = 450;
FADE_dynamicRoadblockSpawnChance = 0.28;      // corridor / aggressive spawn roll (not civ-zone roadblocks)
// RoadblockCommon.sqf: one random barricade + infantry; garrison enterable houses within radius (max positions).
FADE_roadblockGarrisonRadiusM = 25;
FADE_roadblockGarrisonMax = 16;
// FADE_VirtualGarrison.sqf: spawn building OPFOR when any player is this close (2D); manager sleep interval (server).
FADE_vgActivateRadiusM = 100;
FADE_vgPollIntervalS = 10;
// Deferred nearby-building garrison (Missions: Asset Retrieval, Search & Destroy): roll per buildingPos when registering slots. Was 0.33.
FADE_vgNearbySlotChance = 0.165;
// Secondary garrison around mission anchors (Asset / S&D / HVT / Hostage / Clear Area / EE / Operation / ambient patrols):
// wider search than legacy 200 m; only a fraction of eligible buildings get a garrison attempt (~0.25 ≈ 1 in 4).
FADE_garrisonMissionNearbyRadiusM = 450;
FADE_garrisonMissionNearbyBuildingChance = 0.25;
// Clear Area: added to _areaRadius for the building garrison scan only (patrol ring unchanged).
FADE_garrisonClearAreaSearchExtraM = 150;
// Escape & Evasion: 2D radius for building pool (was 700).
FADE_garrisonEeBuildingSearchRadiusM = 900;
// Operation: multiply zone radius used for garrison building scan (1 = legacy 0.95 * zone radius).
FADE_garrisonOperationScanMult = 1.25;
// Ambient enemy patrol zones: add to civ zone radius when scanning garrison candidates (m).
FADE_garrisonAmbientRadiusExtraM = 300;
// Lazy building garrison (FADE_VirtualGarrison): outdoor barrel/campfire hint at register (before units activate); barrelRoll applies then.
FADE_vgLazyOutdoorHintChance = 0.5;
FADE_vgLazyOutdoorHintClasses = ["MetalBarrel_burning_F", "Campfire_burning_F"];
// true: server places a yellow dot (mil_dot) at each pending virtual garrison anchor; removed on spawn/cancel/invalid building
FADE_vgDebugMarkers = false;
FADE_dynamicRoadblockCorridorSamples = 7;     // road picks along base <-> objective lerp
// Tie roadblocks to ambient civ zones (FADE_civZoneState): longest connected road edge in zone, midpoint spawn; one block per zone max.
FADE_dynamicRoadblocksCivZoneMode = true;
// While any civ zone is active: spawn roadblocks only in those towns (no corridor/aggressive on random roads). Set false to mix corridor blocks again. Always ignored during EE (corridor stays on).
FADE_dynamicRoadblockCivZoneOnly = true;
FADE_dynamicRoadblockCivZoneSpawnChance = 0.5;   // per active civ zone per poll (patrols on, not EE)
FADE_dynamicRoadblockCivZoneSpawnChanceEe = 1;   // per zone when Escape & Evasion active (FADE_dynRb_escapeZone)
FADE_dynamicRoadblockCivZonePlayerMaxM = 5200;   // need ≥1 eligible player within this of zone centre
FADE_dynamicRoadblockCivZoneSpawnMinM = 200;    // player ↔ roadblock distance band (can be < default corridor min)
FADE_dynamicRoadblockCivZoneSpawnMaxM = 3200;
// Civ-zone road pick: search roads within (FADE_civSpawnRadius * this mult), min 350 m — keeps "main road" inside the town, not a regional highway chord.
FADE_dynamicRoadblockCivZoneRoadSearchMult = 0.55;
// Prefer longest segment whose midpoint is within this distance of the zone anchor (m); 0 = no extra constraint (legacy).
FADE_dynamicRoadblockCivZoneMidMaxM = 500;
// With a mission anchor: roadblock must be at least this much CLOSER to the anchor (obj or HQ for EE) than the player — stops spawns behind you on the way to the task.
FADE_dynamicRoadblockAheadMarginM = 200;
// Extra road samples along each eligible player → anchor (merged with corridor).
FADE_dynamicRoadblockPlayerRaySamples = 5;
FADE_dynamicRoadblockPlayerRayMaxPlayers = 3;
// No structured global objective (fallback B only): spawn on roads ahead of movement, close to players.
FADE_dynamicRoadblockAggressiveMinM = 180;
FADE_dynamicRoadblockAggressiveMaxM = 950;
FADE_dynamicRoadblockAggressiveMinDistFromBase = 400;
FADE_dynamicRoadblockAggressiveChance = 0.34;
// EE dynamic roadblocks: lerp t along zone→HQ (higher = closer to base on segment).
FADE_dynamicRoadblockEeTMin = 0.2;
FADE_dynamicRoadblockEeTMax = 0.96;
// Escape & Evasion: OPFOR search heli first sortie when any evadee is this far from the civ-zone centre nearest their teleport position (m).
FADE_eeSearchHeliMinDistFromAnchor = 1500;

// Hostage mission: CfgIdentities class names (description.ext). Shuffled without replacement; if there are more hostages than entries, extras pick at random from this pool.
FADE_hostageIdentities = [
    "FADE_hostage_PhilCassidy",
    "FADE_hostage_WarrenWazzaDriscoll"
];

// Counter-attack QRF (HVT / Hostage / Clear Area): seconds to wait after first player-in-zone before wave 1 (random between min..max).
// Testing: short delay. Production: e.g. min 120, max 360.
FADE_counterAttackFirstDelayMin = 120;
FADE_counterAttackFirstDelayMax = 360;
// QRF spawn must be farther than this from FADE_basePos (road/safe pos). Cargo loads into trucks after drivers move (stagger sec).
FADE_counterAttackMinDistFromBase = 1000;
FADE_counterAttackCargoStaggerSec = 0.35;
// When QRF spawns with no players left in the objective / contested zone, driver waypoints retarget this often (friendly player centroid).
FADE_qrfHuntWaypointIntervalS = 60;

// Mission load profiling (RPT): CfgVehicles scan, client GUI compile, waitUntil. Set true temporarily to measure; leave false in production.
FADE_profileMissionLoad = false;

// Trace bis_fnc_cp_getQueueDelay / bis_fnc_cp_main callers (installs stubs in DebugBIScpStub.sqf). Leave false in normal play.
FADE_debugBIScp = false;
// Seconds between re-applies of bis_fnc_cp_* stubs (BIS can lazy-load over them). 2 Hz is enough for normal play; use 1 if RPT shows CP errors after combat.
FADE_bisCpStubReapplyInterval = 2;

// BIS Civilian Presence (Tac-Ops): see rsc\fn_bisCpPreInit.sqf - do not stub getQueueDelay with { 0 } when main is real CODE.
call compile preprocessFileLineNumbers "rsc\fn_bisCpPreInit.sqf";

// -----------------------------------------------------------------------------
// CQB Training Shoothouse - Eden object names for drill positions (triggers/objects)
// Place CQB_POS_1, CQB_POS_2, ... in Eden; direction of object = facing of spawned unit/target
// (Built with a loop - avoid "N to M" ranges; they can fail to compile under call compile in some setups.)
// -----------------------------------------------------------------------------
FADE_cqbPosNames = [];
private _cqbI = 1;
while { _cqbI <= 49 } do {
    FADE_cqbPosNames pushBack format ["CQB_POS_%1", _cqbI];
    _cqbI = _cqbI + 1;
};
// Pop-up target class (vanilla); CQB server logic + noPop + client animateSource keep it down until drill end
FADE_cqbTargetClass = "TargetP_Inf_F";

// Sniper range (terminalSniper + sniperRangeTarget_*); same pop-up class unless overridden
FADE_sniperTargetClass = "TargetP_Inf_F";
// Impact marker at bullet hit (server); falls back if class missing from modset
FADE_sniperImpactMarkerClass = "Sign_sphere25cm_EP1";

// Firing / AT range (terminalRange): session targets use Eden game logics firingRangePos_1 .. firingRangePos_210 (shared pool).
// Vehicle class toggles in GUI map to these keys: car, truck, apc, tank.
FADE_rangeVehicleTypeMap = [
    ["car", "UK3CB_CSAT_B_O_UAZ_Open"],
    ["truck", "UK3CB_CW_SOV_O_EARLY_Ural"],
    ["apc", "rhs_bmp2e_vv"],
    ["tank", "rhsgref_ins_t72bc"]
];
// Extra range equipment (label, CfgVehicles class) merged into the same list + pads as friendly land vehicles (rangeFriendlyVehPos_*).
FADE_rangeAtWeaponDefinitions = [
    ["RPG-42 [AT] (placeholder)", "launch_RPG32_F"],
    ["MRAWS [AT] (placeholder)", "launch_MRAWS_green_F"],
    ["Titan AT [placeholder]", "launch_B_Titan_short_F"]
];
// Legacy separate AT pads (rangeGunPos_*): leave empty — equipment uses rangeFriendlyVehPos_* only.
FADE_rangeGunPosNames = [];
// Friendly BLUFOR ground vehicles (same class pool as Vehicle GUI land spawn); logic positions in Eden.
FADE_rangeFriendlyVehPosNames = [
    "rangeFriendlyVehPos_1", "rangeFriendlyVehPos_2", "rangeFriendlyVehPos_3",
    "rangeFriendlyVehPos_4", "rangeFriendlyVehPos_5", "rangeFriendlyVehPos_6"
];

// -----------------------------------------------------------------------------
// Locker Room ambient (client: rsc\LockerRoomAmbient.sqf)
// Player say3D -- 250 m audible radius; timers repeat while in zone / near lockers
// Eden game logic: variable name posLockerRoom = room center. Within radius = in locker room.
// Locker proximity helpers: posLocker_0..N or posLockers_1..N (either naming; scan collects non-null).
// If none found, LockerRoomAmbient falls back to vanilla Metal_Locker_F within proximity distance.
// -----------------------------------------------------------------------------
FADE_lockerRoomCenterVar = "posLockerRoom";
FADE_lockerRoomRadius = 20;
FADE_lockerNearLockerDist = 5;
FADE_lockerPosVarMax = 64;
// Roll timing: time + min + random rand → default 3–6s (both hostage and slap)
FADE_lockerSoundDelayMin = 3;
FADE_lockerSoundDelayRand = 3;
// 1 = always play on each roll (hostage and slap are independent timers)
FADE_lockerHostageChance = 1;
