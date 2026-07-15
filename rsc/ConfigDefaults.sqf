// ConfigDefaults.sqf - scenario/mission tuning data (no functions)
// Optional exact CfgFactionClasses names  -  if non-empty and the class exists and side matches, wins over display-name pick in initServer (use when mod display strings drift). initServer also prefers USMC / 3CB African factions by display name when these stay empty.
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
// FADE_civZoneMinBuildings = 10;  // see ambient section — named locations below this House/Building count are not civ zones
FADE_aoStrength = "Mid";       // AO mission strength: "Low", "Mid", "High" (used by AO mission type)
// Operation (global): number of enemy-held civ zones (Scenario GUI); must not exceed built zone count
FADE_operationZoneCount = 6;
// Legacy: random pool if ever needed  -  Operation uses FADE_operationZoneCount from scenario
FADE_operationZoneCountChoices = [4, 6, 10];
// Raid (global multi-objective) — FADE_raidObjectiveCount in ConfigClient.sqf
FADE_raidQrfSkipDetectionWait = false;  // false = QRF waits until BLUFOR enters zone (recommended)
FADE_raidQrfFirstDelayMin = 0;
FADE_raidQrfFirstDelayMax = 30;
FADE_raidQrfDetectionRadiusM = 350;      // QRF player-in-zone check (separate from intel refine below)
FADE_raidQrfFootWave = true;             // Raid: foot squads spawn on QRF trigger before vehicle wave
FADE_raidTimeoutSec = 0;                  // 0 = no time limit
// Shared map search-zone circle (Asset Retrieval, Search & Destroy, Raid); was 220 / 250 / 150 then 110
FADE_missionApproxZoneRadiusM = 55;
FADE_missionMarkerJitterM = 25;            // max map icon offset from objective anchor (circle shares icon centre)
FADE_missionSearchZoneEdgeMarginM = 15;    // extra metres past farthest objective so the border contains all targets
FADE_missionRadiusMarkerAlpha = 1;         // search / zone ring opacity (Border brush — no fill)
FADE_hostageSearchRadiusM = 125;           // was 250
FADE_hvtSearchRadiusM = 125;               // was 250
FADE_clearAreaTownRadiusM = 140;           // was 280
FADE_clearAreaCampRadiusM = 60;            // was 120
FADE_raidZoneDetectRadiusM = 55;           // legacy intel refine trigger (unused when building marked at spawn)
FADE_raidIntelRefineRadiusM = 28;          // was 55; legacy intel refine ring
FADE_raidBuildSearchRadiusM = 450;         // building/objective spawn scan (match HVT/Hostage standalone missions)
FADE_objectiveBuildingClusterRadiusM = 120; // neighbour scan — reject isolated infrastructure (bridges, etc.)
FADE_objectiveBuildingMinClusterSize = 2;   // objective site + at least one other enterable building nearby
FADE_raidPatrolRadiusM = 90;               // outdoor patrol waypoints within zone
FADE_raidTargetImmediateGarrisonRadiusM = 250; // immediate (non-lazy) garrison around each raid target building
FADE_raidImmediateGarrisonMaxPerBuilding = 2;  // cap men per building in immediate ring (dispersed)
FADE_raidNearbyGarrisonRadiusM = 450;      // lazy nearby-building scan outside immediate ring (subset chance below)
FADE_raidNearbyGarrisonMaxPerZone = 4;     // cap deferred garrisons per objective (3 zones × N)
FADE_raidIntelPollSec = 2;
FADE_raidPlayerDifficultyStep = 0.15;     // extra garrison scale per friendly player beyond first
FADE_raidZoneDifficultyStep = 0.1;        // extra scale per objective index (later sites harder)
FADE_raidCellNames = [
    "Volkov cell", "Kozlov network", "Red Banner group", "East Gate syndicate", "Harbor liaison"
];
// Invasion (global defensive)
FADE_invasionReinforceMin = 90;            // seconds between heliborne reinforcement waves (after first)
FADE_invasionReinforceMax = 150;
FADE_invasionHeliFirstDelaySec = 75;       // first heli wave eligible this long after sustain loop starts
FADE_invasionHelisPerWaveMax = 2;          // extra heli when many push squads are missing
FADE_invasionFrontSurgeHeliCooldown = 90;  // min seconds between bonus helis when BLUFOR holds an empty front
FADE_invasionInitialSquadsMin = 2;         // opening ground push (already landed at beachhead)
FADE_invasionInitialSquadsMax = 3;
FADE_invasionSustainSquadsMin = 3;         // target active infantry squads pressing the current zone
FADE_invasionSustainSquadsMax = 6;
FADE_invasionGroundReinforceMaxPerTick = 2; // beachhead ground squads released per sustain poll (AO-style top-up)
FADE_invasionWipedFrontSquadsMin = 2;      // minimum ground squads when push groups wiped but BLUFOR holds the front
FADE_invasionWaveVehiclesMax = 2;          // after OPFOR captures at least one other zone
FADE_invasionVehicleReinforceMin = 90;     // min seconds between vehicle spawns from captured sectors
FADE_invasionSustainCheckSec = 20;         // sustain poll interval (AO ~25–50s)
FADE_invasionHeliApproachDist = 2200;      // heli spawn distance from beachhead LZ (m)
FADE_invasionHeliDespawnDist = 2000;       // delete reinforcement heli once this far from every player (m)
FADE_invasionOpforAirSetting = "Low";      // force OPFOR air while Invasion runs (Off | Low | Normal | High)
FADE_invasionBeachheadTurretsMin = 3;
FADE_invasionBeachheadTurretsMax = 5;
FADE_invasionBluforDefGroupsMax = 1;       // defender squads per BLUFOR-held zone at start (no respawn)
FADE_invasionBluforDefSizeMin = 3;
FADE_invasionBluforDefSizeMax = 5;
// Enemy AAA (dynamic around airborne player aircraft)
FADE_aaa_debug = true;
FADE_aaa_spawnDistMin = 1500;
FADE_aaa_spawnDistMax = 2000;
FADE_aaa_playerExclusionM = 200;
FADE_aaa_maxClustersPerPlayer = 1;
FADE_aaa_respawnCooldownSec = 120;
FADE_aaa_baseExclusionM = 1500;
FADE_aaa_baseExclusionRelaxedM = 800;
FADE_aaa_baseRelaxAirDistM = 2500;
FADE_aaa_manpadsRoofChance = 0.35;           // MANPADS try a roof near ground spawn anchor (fallback: open ground)
FADE_aaa_manpadsRoofSearchM = 150;           // building search radius around ground anchor
FADE_aaa_manpadsMinBuildingHeightM = 4;      // skip low sheds / walls (bbox height)
FADE_aaa_manpadsRoofSamples = 10;            // ray samples per building for flat roof hit
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
FADE_enemySkill = 0.0;         // Default enemy AI skill (Scenario GUI can override)
FADE_scenarioPatrols = true;   // Ambient OPFOR patrols + dynamic roadblocks (Scenario GUI can override)
FADE_opforPatrolTownChanceSetting = "Low";  // "Low" 25%, "Medium" 50%, "High" 75%, "Every" 100% per civ zone
FADE_enemyPatrolTownChance = 0.25;           // Resolved from FADE_opforPatrolTownChanceSetting
FADE_opforPopulationSetting = "Low";  // "VeryLow" 0.25x, "Low" 0.5x, "Normal" 1x, "High" 1.5x, "VeryHigh" 2x, "Insane" 4x
FADE_opforLauncherSetting = "Normal";     // "Normal", "Reduced", "Minimal", "None"  -  AT launchers (not MANPADS AA)
FADE_limitGearToFriendlyFaction = false;  // When true, Loadout and Vehicle GUIs restrict to chosen Friendly faction
FADE_limitToPresetLoadouts = false;          // When true, Loadout GUI allows preset loadouts only
FADE_teleportToPlayerMode = 0;            // 0 = all players can teleport-to-player, 1 = SL/admin/Zeus only
// Civilian talk (ambient foot civs): Scenario GUI can require FADE_civInterpreter for meaningful dialogue; non-interpreters still get the GUI with a barrier label and ??? replies only.
FADE_civTalkInterpretersOnly = false;
FADE_civTalkLangBarrierText = "You do not understand what they are saying.";
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
FADE_civTalkGreetingPositive = ["Hello. Can I help you?", "What do you need?", "Yes? Make it quick.", "I do not want trouble - what is it?"];
FADE_civTalkGreetingNegative = ["What do you want?", "Leave me alone.", "I am busy.", "Do not point that thing at me."];
FADE_civTalkRumoursPositive = ["They say the road north is quiet.", "People talk. I ignore most of it.", "Strangers have been asking questions.", "I heard engines on the main road earlier.", "Folk are keeping their heads down."];
// Heard rumours  -  extra lines when a global mission type with QRF is active (see FADE_globalMissionTypesWithQrf; server picks ~half the time when cooperative).
FADE_civTalkRumoursPositiveQrf = [
    "When shooting starts, their trucks show up fast.",
    "They move quick once someone opens fire - that is what people say.",
    "If it gets loud, do not hang around. They pile on.",
    "Their reaction crews jump at the first shots lately.",
    "Hear a firefight? Expect more soon."
];
// Global mission types that use truck/zone QRF (excludes e.g. Intercept Convoy). Used for rumour hints only.
FADE_globalMissionTypesWithQrf = ["AreaOfOperations", "Hostage", "HVT", "ClearArea", "CAS", "SearchDestroy", "Operation", "Raid", "AssetRetrieval", "CSAR", "EscapeEvasion"];
FADE_civTalkRumoursNegative = ["I do not listen to gossip.", "I have nothing to tell you.", "Why ask me?", "You should not be here asking questions.", "I keep to myself."];
FADE_civTalkGestureAway = ["Fine, I am leaving.", "All right, all right.", "Okay, okay."];
FADE_civTalkGestureStay = ["I will stay.", "Okay, I will not move.", "Understood."];
FADE_civTalkGestureDown = ["I am getting down!", "Down, down!", "Do not shoot!"];
FADE_civTalkGestureNoUnderstandFmt = "%1 does not understand you.";
FADE_civTalkArrestUncooperativeRadiusM = 500;
FADE_civTalkArrestComply = ["I am not resisting.", "Okay, I will come quietly.", "Please, do not hurt me."];
FADE_civTalkArrestRefuse = ["You have no authority!", "I am not going anywhere with you.", "Leave me alone!"];
FADE_civTalkRefuseOpfor = ["I am not telling you anything.", "I have nothing to say to you.", "Ask someone else.", "I did not see anything - understand?"];
FADE_civTalkRefuseCar = ["Go away.", "Find your own ride.", "I do not have keys for you.", "That is not how this works."];
FADE_civTalkOpforNone = ["I have not seen any soldiers.", "No, nothing like that around here."];
FADE_civTalkOpforUnsure = ["I am not sure.", "Maybe. I did not get a good look."];
FADE_civTalkCarNone = ["I do not know of any free car nearby.", "No empty vehicle around here.", "Nothing parked that I can think of.", "If there is one, it is not mine."];
// Optional second line in replies: time-of-day + nearest settlement name (server: FADE_civTalk_contextLines).
FADE_civTalkContextAppendChance = 0.35;
FADE_civTalkCtxNight = ["Hard to see at night.", "Dark makes everyone nervous.", "You should not be out here after dark."];
FADE_civTalkCtxMorning = ["Morning is quiet.", "Barely anyone is about yet.", "Early light - easy to miss details."];
FADE_civTalkCtxAfternoon = ["Heat shimmers on the road.", "The day drags.", "Sun is high; hard to be sure of anything."];
FADE_civTalkCtxNearFmt = ["Not far from %1.", "Up toward %1...", "People still talk about %1.", "This side of %1."];
// When true, actionable civilian intel (OPFOR sighting / vehicle tip) appends an entry to map → Intel (see Briefing.sqf / FADE_civTalk_clientAppendIntelDiary).
FADE_civTalkIntelDiary = true;
// When true, building intel (hold-to-read props) and Asset Retrieval package pickup append to map → Intel (FADE_intel_clientAppendIntelDiary).
FADE_intelDiaryLog = true;
// Civilian talk  -  cutscene (local to initiating player) + animation names (switchMove; clear with "" before changing)
FADE_civTalkFadeOutSec = 1.2;
FADE_civTalkFadeInSec = 1;
FADE_civTalkFaceSeparationM = 3;
// Cutscene camera: modelToWorld on player  -  right / back / up (m) in Man space (X right, Y forward, Z up); lower FOV = more zoom (tuned to match debug).
FADE_civTalkCamBehindM = 3;
FADE_civTalkCamRightM = 2;
FADE_civTalkCamHeightAbovePlayerASL = 1;
FADE_civTalkCamFov = 0.2;
FADE_civTalkReturnIdleDelay = 5;
FADE_civTalkIntelPoseSec = 4.5;
// CivTalk reply box (idc 60247): structured-text size + alignment (center reads better for short NPC lines).
FADE_civTalkReplyTextSize = 1.1;
FADE_civTalkReplyTextAlign = "center";
FADE_civTalkAnimPlayerIdle = "acts_millerIdle";
// Unused while dialogue keeps the player in idle (see CivTalkGui).
FADE_civTalkAnimPlayerTalk = "Acts_StandingSpeakingUnarmed";
FADE_civTalkAnimCivIdle = "Acts_CivilIdle_2";
// Unused: dialogue keeps civ in idle; only FADE_civTalkAnimCivIntel plays on intel lines.
FADE_civTalkAnimCivTalk = "Acts_CivilTalking_1";
FADE_civTalkAnimCivIntel = "Acts_Pointing_Right";
// Base NPC (S Wordsman): server-spawned at Eden BaseNPCPos logic. Same CivTalk GUI; flat hello / mission / goodbye only.
FADE_baseNpcTalkReplies = [
    "Can I help you?",
    "Umm...",
    "I don't even play this game.",
    "I'm not going on your mission.",
    "No.",
    "Sigh",
    "Back in my day we used iron sights and we were fucking grateful for it.",
    "Mission makers just don't have the real hatred for the players they used to when I played.",
    "You kids have it so easy."
];
FADE_baseNpcTalkBtnHello = "Hello";
FADE_baseNpcTalkBtnMission = "Will you come on the mission with us?";
FADE_baseNpcTalkBtnGoodbye = "Goodbye";
FADE_baseNpcTalkActionText = "Talk to S Wordsman";
FADE_baseNpcTalkGoodbyeCloseDelay = 2.5;
// Eden Game Logic variable name (same pattern as firesPos_* / BASE_1). Fallback: FADE_baseNpcEdenPosATL.
FADE_baseNpcPosMarkerName = "BaseNPCPos";
FADE_baseNpcEdenPosATL = [14754.169, 18.171377, 16638.416];
// Mission map-click: client tunables in ConfigClient.sqf
FADE_baseNpcClass = "C_man_1";
// getUnitLoadout / setUnitLoadout format (10 elements)  -  S Wordsman appearance at base.
FADE_baseNpcLoadout = [[], [], [], ["U_I_G_Story_Protagonist_F", []], [], [], "H_Beret_blk", "G_aviator", [], ["ItemMap", "", "", "ItemCompass", "ItemWatch", ""]];
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

// Mission search zones: "grid" (100 m map grid rectangles) or "ellipse" (border ring).
FADE_missionSearchZoneMode = "grid";
FADE_mapGridCellSizeM = 100;
// Map grid SW-corner offset for Altis (100 m cells align at 50,150,250… not 0,100,200…).
FADE_mapGridOriginOffsetX = 50;
FADE_mapGridOriginOffsetY = 50;
FADE_missionGridZoneAlpha = 0.35;
// Field intel (body search): points toward 100% reveal; shrink steps at 25/50/75%.
FADE_fieldIntelEnabled = true;
FADE_fieldIntelMaxPoints = 100;
FADE_fieldIntelBodySearchPointsLeader = 30;
FADE_fieldIntelBodySearchPointsRegular = 18;
FADE_fieldIntelBodySearchEmptyChance = 0.15;
FADE_fieldIntelBodySearchHoldSec = 6;
FADE_fieldIntelBodySearchDistM = 3;
FADE_fieldIntelRevealSnapRadiusM = 45;
FADE_fieldIntelMissions = ["HVT", "Hostage", "SearchDestroy", "AssetRetrieval", "Asset Retrieval"];
// AO terrain survey (spawn / waypoint placement). See rsc/FADE_AoSurvey.sqf.
FADE_aoSurveyEnabled = true;
FADE_aoSurveyRoadSampleMax = 12;
FADE_aoSurveyFlatSampleMax = 10;
FADE_aoSurveyBuildingSampleMax = 8;
// Client (initPlayerLocal): seconds between HQ auto-heal checks when inside radius of FADE_basePos.
FADE_hqHealIntervalSec = 40;

// Loadout box Eden object names - Manage My Loadout, Save loadout, ACE Arsenal (if loaded).
// objWorkbench (FADE_workbenchEdenName): Save + attachments-only ACE Arsenal only (no loadout GUI).
FADE_workbenchEdenName = "objWorkbench";
FADE_loadoutBoxNames = ["LOADOUTBOX", "LOADOUTBOX_1", "LOADOUTBOX_2", "LOADOUTBOX_3", "LOADOUTBOX_4", FADE_workbenchEdenName];
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
// Drill completes on first real vehicle damage (splash/part damage counts) or destruction  -  not aggregate `damage` threshold.
// [display label, unused class]  -  kept for FIRES GUI combo; spawn uses FADE_firesDrillCarClass.
FADE_firesDrillTargetDefinitions = [
    ["Drill vehicle (offroad)", "C_Offroad_01_F"]
];
// RTT setObjectTextureGlobal indices on firesScreenPos_* . Use [0] for the main panel only; adding 1+ repeats the feed on PiP/bezel selections (tiled picture-in-picture).
FADE_firesImpactVideoTextureIndices = [0];
// 512+ recommended; non-power-of-two sizes often produce black RTT on some GPUs.
FADE_firesImpactVideoRttResolution = 512;
// r2t(name, aspect): 1.0 matches common PiP/RTT examples; widen/narrow if the panel looks stretched.
FADE_firesImpactRttAspect = 1;
// Server: projectile position poll for impact PiP (smaller = more accurate, more server load during arty fire).
FADE_firesProjectileTrackSleep = 0.1;
// Camera height (m) above impact for PiP (local anchor = impact point).
FADE_firesImpactCamHeightM = 90;
// Pads where planes cannot spawn (helicopters can use any pad)
FADE_planeForbiddenPads = ["HP_1", "HP_2", "HP_8"];
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
// Base pad status signs (UserTexture1m_F). Index matches FADE_helipadList (padIndicator_1 = HP_1, etc.). HP_8 has no sign.
FADE_padIndicatorNames = ["padIndicator_1", "padIndicator_2", "padIndicator_3", "padIndicator_4", "padIndicator_5", "padIndicator_6", "padIndicator_7"];

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
FADE_enemyPatrolMinDistFromPlayersM = 400;  // ambient enemy patrol: infantry/vehicle spawn positions must be at least this 2D m from every alive player
FADE_enemyPatrolSpawnMinDistM = 60;         // infantry spawn: min 2D m from civ zone centre (inner town)
FADE_enemyPatrolSpawnMaxDistM = 280;        // infantry spawn: max 2D m from civ zone centre
FADE_enemyPatrolWpMinDistM = 40;            // patrol cycle waypoint ring min from centre
FADE_enemyPatrolWpMaxDistM = 200;           // patrol cycle waypoint ring max from centre
FADE_enemyPatrolVehicleRoadSearchM = 350;   // road vehicle patrol: roads near centre only (not regional highways)
FADE_enemyPatrolSniperZoneChance = 0.45;    // garrisoned patrol zones: chance of rooftop sniper(s)
FADE_enemyPatrolSniperMaxPerZone = 2;       // max snipers per patrol zone (when zone roll succeeds)
FADE_enemyPatrolSniperBuildingTries = 8;  // buildings tested per sniper placement attempt
FADE_enemyPatrolSniperMinElevAboveTerrainM = 7; // rooftop sniper ATL minimum (m above terrain); rejects ground-level roofs
FADE_buildingRoofMinHeightM = 4;            // shared roof helper: skip low sheds
FADE_buildingRoofSamples = 10;              // ray samples per building for FADE_buildingRoofPos
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
FADE_civZoneBuildingRadius = 500; // scan radius (2D m) for House/Building count at each named location
FADE_civZoneMinBuildings = 10;    // require at least this many buildings in that radius or skip the civ zone entirely (0 = distance/water filter only)
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
// Debug: systemChat for dynamic roadblocks (rsc\DynamicRoadblocks.sqf  -  spawn, despawn, patrols off)
FADE_checkpointDebug = false;
// Dynamic roadblocks / ambush props along base <-> mission corridor (rsc\DynamicRoadblocks.sqf). Requires Enemy Patrols ON.
// Counts all friendly players for distance (including helicopters) once beyond FADE_dynamicRoadblockMinDistFromBase (also minimum roadblock spawn distance from base).
FADE_dynamicRoadblocksEnabled = true;
FADE_dynamicRoadblockPollSec = 30;
FADE_dynamicRoadblockMinDistFromBase = 2000;  // eligible players + roadblock spawn positions must be at least this far from base
FADE_dynamicRoadblockSpawnMinM = 750;         // roadblock this far from at least one such player
FADE_dynamicRoadblockSpawnMaxM = 2800;
FADE_dynamicRoadblockDespawnM = 1500;         // delete if no friendly player within this range
// Civ-zone tied roadblock: when the zone despawns, keep the block if any alive human player is within this 2D m (0 = always despawn with zone)
FADE_dynamicRoadblockZoneGoneRetainPlayerM = 1000;
FADE_dynamicRoadblockMaxActive = 5;
FADE_dynamicRoadblockMinSpacingM = 450;
FADE_dynamicRoadblockSpawnChance = 0.28;      // corridor / aggressive spawn roll (not civ-zone roadblocks)
// RoadblockCommon.sqf: one random barricade + infantry; garrison enterable houses within radius (max positions).
FADE_roadblockGarrisonRadiusM = 25;
FADE_roadblockGarrisonMax = 16;
FADE_roadblockInfOffRoadMinM = 6;       // roadblock infantry: min lateral offset from road centre (ambush)
FADE_roadblockInfOffRoadMaxM = 14;      // roadblock infantry: max lateral offset
FADE_roadblockInfAlongRoadSpreadM = 10; // roadblock infantry: spread along road axis (+/- m from barricade)
// FADE_VirtualGarrison.sqf: spawn building OPFOR when any player is this close (2D); manager sleep interval (server).
FADE_vgActivateRadiusM = 100;
FADE_vgPollIntervalS = 10;
// Search & Destroy: % of spawned ammo caches that must be destroyed (0-100). Completion is cache-only when caches spawn.
FADE_searchDestroyCacheDestroyPct = 100;
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
// Ambient enemy patrol zones: building scan radius from zone centre (not full civ ellipse).
FADE_garrisonAmbientScanRadiusM = 380;
FADE_garrisonAmbientBuildingChance = 0.55;   // per-building roll for patrol-zone garrisons (missions use FADE_garrisonMissionNearbyBuildingChance)
FADE_garrisonAmbientRadiusExtraM = 300;      // legacy extra on mission scan; patrol zones use FADE_garrisonAmbientScanRadiusM
// Lazy building garrison (FADE_VirtualGarrison): outdoor barrel/campfire hint at register (before units activate); barrelRoll applies then.
FADE_vgLazyOutdoorHintChance = 0.5;
FADE_vgLazyOutdoorHintClasses = ["MetalBarrel_burning_F", "Campfire_burning_F"];
// Min horizontal clearance from road segments for outdoor garrison hints (barrel/campfire).
FADE_vgOutdoorHintRoadClearM = 8;
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
// Civ-zone road pick: search roads within (FADE_civSpawnRadius * this mult), min 350 m  -  keeps "main road" inside the town, not a regional highway chord.
FADE_dynamicRoadblockCivZoneRoadSearchMult = 0.55;
// Prefer longest segment whose midpoint is within this distance of the zone anchor (m); 0 = no extra constraint (legacy).
FADE_dynamicRoadblockCivZoneMidMaxM = 500;
// With a mission anchor: roadblock must be at least this much CLOSER to the anchor (obj or HQ for EE) than the player  -  stops spawns behind you on the way to the task.
FADE_dynamicRoadblockAheadMarginM = 200;
// Extra road samples along each eligible player → anchor (merged with corridor).
FADE_dynamicRoadblockPlayerRaySamples = 5;
FADE_dynamicRoadblockPlayerRayMaxPlayers = 3;
// No structured global objective (fallback B only): spawn on roads ahead of movement, close to players.
FADE_dynamicRoadblockAggressiveMinM = 180;
FADE_dynamicRoadblockAggressiveMaxM = 950;
FADE_dynamicRoadblockAggressiveMinDistFromBase = 2000;
FADE_dynamicRoadblockAggressiveChance = 0.34;
// EE dynamic roadblocks: lerp t along zone→HQ (higher = closer to base on segment).
FADE_dynamicRoadblockEeTMin = 0.2;
FADE_dynamicRoadblockEeTMax = 0.96;
// Escape & Evasion: OPFOR search heli first sortie when any evadee is this far from the civ-zone centre nearest their teleport position (m).
FADE_eeSearchHeliMinDistFromAnchor = 1500;

// HVT / hostage protective gear (applied after spawn animations; reduces accidental frags).
FADE_objectiveProtectiveHelmet = "H_Helmet_Skate";
FADE_objectiveProtectiveVest = "V_CarrierRigKBT_01_Olive_F";

// HVT missions: codename suffix for FADE_hvt_* CfgIdentities (description.ext).
FADE_hvtCodenamePool = ["Viktor", "Dmitri", "Sergei", "Ivan", "Pavel", "Boris", "Volkov", "Kozlov"];

// Hostage mission: CfgIdentities class names (description.ext). Shuffled without replacement; if there are more hostages than entries, extras pick at random from this pool.
FADE_hostageIdentities = [
    "FADE_hostage_PhilCassidy",
    "FADE_hostage_WarrenWazzaDriscoll"
];
FADE_hostageFreeHoldSec = 5;
FADE_hostageFreeDistM = 3;

// Counter-attack QRF (HVT / Hostage / Clear Area): seconds to wait after first player-in-zone before wave 1 (random between min..max).
// Testing: short delay. Production: e.g. min 120, max 360.
FADE_counterAttackFirstDelayMin = 120;
FADE_counterAttackFirstDelayMax = 360;
FADE_counterAttackFootSquadsMin = 2;
FADE_counterAttackFootSquadsMax = 3;
FADE_counterAttackFootSpawnDistMin = 80;   // foot QRF tier: spawn near objective (often inside buildings)
FADE_counterAttackFootSpawnDistMax = 220;
FADE_counterAttackFootSquadSizeMin = 4;
FADE_counterAttackFootSquadSizeMax = 6;
FADE_counterAttackFootBuildingChance = 0.65; // prefer interior spawn so players do not see QRF pop-in
// QRF spawn must be farther than this from FADE_basePos (road/safe pos). Cargo loads into trucks after drivers move (stagger sec).
FADE_counterAttackMinDistFromBase = 1000;
FADE_counterAttackCargoStaggerSec = 0.35;
// When QRF spawns with no players left in the objective / contested zone, driver waypoints retarget this often (friendly player centroid).
FADE_qrfHuntWaypointIntervalS = 60;
// RPT QRF lifecycle logs (detection, foot wave, vehicle staging, cargo unload, hunt mode). Grep H21 QRF.
FADE_qrfDebug = true;

FADE_vgPollEmptyIntervalS = 30;
// Ambient civ: skip zone ticks when nearest player farther than this (defaults to activate dist).
FADE_civZoneActivationDist = 900;

// Mission load profiling (RPT): CfgVehicles scan, client GUI compile, waitUntil. Set true temporarily to measure; leave false in production.
FADE_profileMissionLoad = false;

