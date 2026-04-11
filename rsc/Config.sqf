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
// Highest CIV_T_* index placed in Eden (mission.sqm); AmbientCivilians scans CIV_T_1 .. this number
FADE_civTriggerIndexMax = 109;
FADE_aoStrength = "Mid";       // AO mission strength: "Low", "Mid", "High" (used by AO mission type)
// Operation (global): number of enemy-held civ zones (Scenario GUI); must match available CIV_T_* zones
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
FADE_opforPopulationSetting = "Normal";  // "Auto", "VeryLow", "Low", "Normal", "High", "VeryHigh", "Insane"
FADE_opforLauncherSetting = "Normal";     // "Normal", "Reduced", "Minimal", "None" — AT launchers (not MANPADS AA)
FADE_opforAirSetting = "Off";               // "Off", "Low" (max 1, 10 min cooldown), "Medium" (max 2, 5 min) — OPFOR air after AI spots BLUFOR + random delay (initServer FADE_opforAir_*)
FADE_limitGearToFriendlyFaction = false;  // When true, Loadout and Vehicle GUIs restrict to chosen Friendly faction
FADE_limitToCtbLoadouts = false;          // When true, Loadout GUI allows CTB presets only
FADE_teleportToPlayerMode = 0;            // 0 = all players can teleport-to-player, 1 = SL/admin/Zeus only
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
// Helipad markers (map markers to update when aircraft spawn/despawn). Index = pad order in FADE_helipadList. Empty = no marker.
FADE_helipadMarkers = ["HeliMark_1", "HeliMark_2", "HeliMark_3", "HeliMark_4", "HeliMark_5", "HeliMark_6", "HeliMark_7", ""];
// Seconds between pad marker text refreshes (initServer); 8s is enough for parked aircraft display.
FADE_helipadMarkerUpdateInterval = 8;

// Full repair / refuel / rearm while stationary within this radius of any HP_* or VEH_* pad (server: rsc\PadVehicleService.sqf)
FADE_padServiceRadius = 22;
FADE_padServiceInterval = 10;
// Merge pad sample points within this distance (m) so one nearestObjects covers nearby HP_/VEH_ markers.
FADE_padServiceDedupeDist = 12;
FADE_padServiceMaxSpeedKmh = 8;

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
// Ambient civilians (CIV_T_* triggers). Eden ROAD_SP_* only needed for Intercept Convoy mission.
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
FADE_civSpawnRadius = 1000;
FADE_civWanderRadius = 100;  // max distance walking civs move from spawn before looping back
FADE_civPlayerActivateDist = 1000;
FADE_civPlayerDeactivateDist = 1400;
FADE_civCountMin = 5;
FADE_civCountMax = 15;
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
// Dynamic enemy checkpoints / roadblocks (rsc\EnemyCheckpoints.sqf at checkPointPos_*). Off until Eden spawn markers exist again.
FADE_enemyCheckpointsEnabled = false;
FADE_checkpointDebug = false;  // set true: systemChat for enemy checkpoints / roadblocks (spawn, despawn, patrols off)

// Counter-attack QRF (HVT / Hostage / Clear Area): seconds to wait after first player-in-zone before wave 1 (random between min..max).
// Testing: short delay. Production: e.g. min 120, max 360.
FADE_counterAttackFirstDelayMin = 120;
FADE_counterAttackFirstDelayMax = 360;
// QRF spawn must be farther than this from FADE_basePos (road/safe pos). Cargo loads into trucks after drivers move (stagger sec).
FADE_counterAttackMinDistFromBase = 1000;
FADE_counterAttackCargoStaggerSec = 0.35;

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

// Firing / AT range (terminalRange)
// Vehicle class toggles in GUI map to these keys: car, truck, apc, tank.
FADE_rangeVehicleTypeMap = [
    ["car", "UK3CB_CSAT_B_O_UAZ_Open"],
    ["truck", "UK3CB_CW_SOV_O_EARLY_Ural"],
    ["apc", "rhs_bmp2e_vv"],
    ["tank", "rhsgref_ins_t72bc"]
];
// AT weapons list for rangeGunPos_* slots (label, class).
FADE_rangeAtWeaponDefinitions = [
    ["RPG-42 [AT] (placeholder)", "launch_RPG32_F"],
    ["MRAWS [AT] (placeholder)", "launch_MRAWS_green_F"],
    ["Titan AT [placeholder]", "launch_B_Titan_short_F"]
];
FADE_rangeGunPosNames = ["rangeGunPos_1", "rangeGunPos_2", "rangeGunPos_3", "rangeGunPos_4", "rangeGunPos_5", "rangeGunPos_6"];
// Friendly BLUFOR ground vehicles (same class pool as Vehicle GUI land spawn); logic positions in Eden.
FADE_rangeFriendlyVehPosNames = [
    "rangeFriendlyVehPos_1", "rangeFriendlyVehPos_2", "rangeFriendlyVehPos_3",
    "rangeFriendlyVehPos_4", "rangeFriendlyVehPos_5", "rangeFriendlyVehPos_6"
];

// -----------------------------------------------------------------------------
// CTB Locker Room ambient (client: rsc\LockerRoomAmbient.sqf)
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
