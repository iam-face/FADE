// =============================================================================
// Config — Face's Dynamic Sandbox mission configuration
// =============================================================================
// heliOps_heliClasses is built dynamically from CfgVehicles (see initServer.sqf)
// Scenario settings (weather, time, factions) are managed via Scenario GUI.
// Unit arrays below are fallbacks when faction has no units (e.g. mod not loaded).

// -----------------------------------------------------------------------------
// Scenario defaults (Scenario GUI overrides these)
// -----------------------------------------------------------------------------
heliOps_scenarioTime = 12;
heliOps_scenarioWeather = "Clear";
heliOps_scenarioEnemyFaction = "OPF_F";
heliOps_scenarioFriendlyFaction = "BLU_F";
heliOps_scenarioCivFaction = "CIV_F";
heliOps_limitGearToFriendlyFaction = false;  // When true, Loadout and Vehicle GUIs restrict to chosen Friendly faction

// Pad names — Eden object variable names (expand as needed)
heliOps_padNames = ["HP_1", "HP_2", "HP_3", "HP_4", "HP_5", "HP_6", "HP_7", "HP_8"];
// Pads where planes cannot spawn (helicopters can use any pad)
heliOps_planeForbiddenPads = ["HP_1", "HP_2"];
// Helipad markers (map markers to update when aircraft spawn/despawn). Index = pad order in heliOps_helipadList. Empty = no marker.
heliOps_helipadMarkers = ["HeliMark_1", "HeliMark_2", "HeliMark_3", "HeliMark_4", "HeliMark_5", "HeliMark_6", "HeliMark_7", ""];

// Friendly infantry (BLUFOR) — fallback when faction has no units
heliOps_friendlyUnits = [
    "B_Soldier_TL_F",
    "B_Soldier_F",
    "B_Soldier_F",
    "B_Soldier_AR_F",
    "B_medic_F",
    "B_Soldier_F"
];

// Enemy infantry (OPFOR) — fallback when faction has no units
heliOps_enemyUnits = [
    "O_Soldier_TL_F",
    "O_Soldier_F",
    "O_Soldier_F",
    "O_Soldier_AR_F",
    "O_Soldier_F"
];

// Cargo classes for resupply (sling-load compatible preferred)
heliOps_cargoClasses = [
    "B_Slingload_01_Cargo_F",
    "B_Slingload_01_Ammo_F",
    "B_Slingload_01_Fuel_F",
    "B_Slingload_01_Repair_F"
];

// -----------------------------------------------------------------------------
// Ambient civilians (CIV_T_* triggers, ROAD_SP_* road spawn points)
// Fallbacks when faction has no units/vehicles
// -----------------------------------------------------------------------------
heliOps_civUnitClasses = [
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
heliOps_civRoadVehicleClasses = [
    "C_Offroad_01_F",
    "C_Offroad_02_unarmed_F",
    "C_Hatchback_01_F",
    "C_SUV_01_F",
    "C_Van_01_transport_F",
    "C_Truck_02_covered_F"
];
heliOps_civParkedVehicleClasses = [
    "C_Hatchback_01_F",
    "C_Offroad_01_F",
    "C_SUV_01_F",
    "C_Van_01_transport_F"
];
heliOps_civSpawnRadius = 1000;
heliOps_civWanderRadius = 100;  // max distance walking civs move from spawn before looping back
heliOps_civPlayerActivateDist = 1000;
heliOps_civPlayerDeactivateDist = 1400;
heliOps_civCountMin = 5;
heliOps_civCountMax = 15;
heliOps_civSpawnStaggerDelay = 1.5;  // seconds between spawn batches (lazy-load to reduce performance hit)
heliOps_civSpawnBatchSize = 2;       // civs per batch
heliOps_civParkedCountMin = 2;
heliOps_civParkedCountMax = 5;
heliOps_civCheckInterval = 45;
heliOps_civMaxActiveZones = 4;  // max civ zones (and their patrol zones) active at once
heliOps_roadVehicleMax = 5;
heliOps_roadSpawnIntervalMin = 90;
heliOps_roadSpawnIntervalMax = 180;
heliOps_civDebug = false;  // systemChat for spawn/despawn/road vehicle actions
heliOps_civDebugMarkers = false;  // when true, show map markers for active civ zones (Civ: zoneId)
