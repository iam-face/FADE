// =============================================================================
// Config - Face's Dynamic Sandbox mission configuration
// =============================================================================
// FADE_heliClasses is built dynamically from CfgVehicles (see initServer.sqf)
// Scenario settings (weather, time, factions) are managed via Scenario GUI.
// Unit arrays below are fallbacks when faction has no units (e.g. mod not loaded).

// -----------------------------------------------------------------------------
// Scenario defaults (Scenario GUI overrides these)
// -----------------------------------------------------------------------------
FADE_scenarioTime = 12;
FADE_scenarioWeather = "Clear";
FADE_scenarioEnemyFaction = "OPF_F";
FADE_scenarioFriendlyFaction = "BLU_F";
FADE_scenarioCivFaction = "CIV_F";
FADE_civiliansEnabled = true;  // When false, no ambient civilians (zones, road vehicles, civ aircraft)
FADE_aoStrength = "Mid";       // AO mission strength: "Low", "Mid", "High" (used by AO mission type)
FADE_limitGearToFriendlyFaction = false;  // When true, Loadout and Vehicle GUIs restrict to chosen Friendly faction

// Loadout box Eden object names - all get Manage My Loadout, Save loadout, ACE Arsenal (if loaded)
FADE_loadoutBoxNames = ["LOADOUTBOX", "LOADOUTBOX_2", "LOADOUTBOX_3"];
// Pad names - Eden object variable names (expand as needed)
FADE_padNames = ["HP_1", "HP_2", "HP_3", "HP_4", "HP_5", "HP_6", "HP_7", "HP_8"];
// Pads where planes cannot spawn (helicopters can use any pad)
FADE_planeForbiddenPads = ["HP_1", "HP_2"];
// Helipad markers (map markers to update when aircraft spawn/despawn). Index = pad order in FADE_helipadList. Empty = no marker.
FADE_helipadMarkers = ["HeliMark_1", "HeliMark_2", "HeliMark_3", "HeliMark_4", "HeliMark_5", "HeliMark_6", "HeliMark_7", ""];

// Friendly infantry (BLUFOR) - fallback when faction has no units
FADE_friendlyUnits = [
    "B_Soldier_TL_F",
    "B_Soldier_F",
    "B_Soldier_F",
    "B_Soldier_AR_F",
    "B_medic_F",
    "B_Soldier_F"
];

// Enemy infantry (OPFOR) - fallback when faction has no units
FADE_enemyUnits = [
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

// Trace bis_fnc_cp_getQueueDelay / bis_fnc_cp_main callers (installs stubs in DebugBIScpStub.sqf). Leave false in normal play.
FADE_debugBIScp = false;

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
// Pop-up target class (vanilla); stays down when shot if noPop is set
FADE_cqbTargetClass = "TargetP_Inf_F";
