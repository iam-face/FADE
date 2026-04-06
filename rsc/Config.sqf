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
FADE_aoStrength = "Mid";       // AO mission strength: "Low", "Mid", "High" (used by AO mission type)
// Operation (global): number of enemy-held civ zones (Scenario GUI); must match available CIV_T_* zones
FADE_operationZoneCount = 6;
// Legacy: random pool if ever needed — Operation uses FADE_operationZoneCount from scenario
FADE_operationZoneCountChoices = [4, 6, 10];
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

// Loadout box Eden object names - all get Manage My Loadout, Save loadout, ACE Arsenal (if loaded)
FADE_loadoutBoxNames = ["LOADOUTBOX", "LOADOUTBOX_2", "LOADOUTBOX_3", "LOADOUTBOX_4"];
// Pad names - Eden object variable names (expand as needed)
FADE_padNames = ["HP_1", "HP_2", "HP_3", "HP_4", "HP_5", "HP_6", "HP_7", "HP_8"];
// FIRES range: game logic object names (position + direction = spawn transform). Match mission.sqm / expand as needed.
FADE_firesPosNames = ["firesPos_1", "firesPos_2", "firesPos_3", "firesPos_4", "firesPos_5", "firesPos_6"];
// FIRES GUI slot list labels (same order / length as FADE_firesPosNames).
FADE_firesPosDisplayNames = [
    "Position 1 (South)",
    "Position 2 (South)",
    "Position 3 (South)",
    "Position 4 (North)",
    "Position 5 (North)",
    "Position 6 (North)"
];
// Pads where planes cannot spawn (helicopters can use any pad)
FADE_planeForbiddenPads = ["HP_1", "HP_2"];
// Helipad markers (map markers to update when aircraft spawn/despawn). Index = pad order in FADE_helipadList. Empty = no marker.
FADE_helipadMarkers = ["HeliMark_1", "HeliMark_2", "HeliMark_3", "HeliMark_4", "HeliMark_5", "HeliMark_6", "HeliMark_7", ""];

// Full repair / refuel / rearm while stationary within this radius of any HP_* or VEH_* pad (server: rsc\PadVehicleService.sqf)
FADE_padServiceRadius = 22;
FADE_padServiceInterval = 7;
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
// Ambient civilians (CIV_T_* triggers, ROAD_SP_* road spawn points)
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
FADE_civCheckInterval = 45;
FADE_civMaxActiveZones = 4;  // max civ zones (and their patrol zones) active at once
FADE_roadVehicleMax = 5;
FADE_roadSpawnIntervalMin = 90;
FADE_roadSpawnIntervalMax = 180;
FADE_civDebug = false;  // systemChat for spawn/despawn/road vehicle actions
FADE_civDebugMarkers = false;  // when true, show map markers for active civ zones (Civ: zoneId)
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
// Seconds between re-applies of bis_fnc_cp_* stubs (BIS can lazy-load over them). 1 is plenty; lower only if RPT shows CP errors after combat.
FADE_bisCpStubReapplyInterval = 1;

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
