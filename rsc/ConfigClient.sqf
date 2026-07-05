// =============================================================================
// ConfigClient.sqf  -  client JIP subset (map picks, debug stubs, locker room)
// Included by Config.sqf on server boot; initPlayerLocal compiles this directly.
// =============================================================================

// Scenario defaults (server sync overwrites via FADE_scenarioClientSync when connected)
FADE_scenarioTime = 18;
FADE_scenarioWeather = "Clear";
if (isNil "FADE_scenarioEnemyFaction") then { FADE_scenarioEnemyFaction = "OPF_F"; };
if (isNil "FADE_scenarioFriendlyFaction") then { FADE_scenarioFriendlyFaction = "BLU_F"; };
if (isNil "FADE_scenarioCivFaction") then { FADE_scenarioCivFaction = "CIV_F"; };

// Mission types hidden from Missions GUI and blocked on start (server uses same list from Config.sqf).
FADE_disabledMissionTypes = ["InterceptConvoy"];

// Raid map pick (client)
FADE_raidObjectiveCount = 3;
FADE_minDistBetweenMissions = 2000;

// Mission map-click (client pickers + MissionMapPick.sqf)
FADE_missionMapClickRadiusTiers = [250, 500, 1000, 2500, 5000, -1];
FADE_missionMapClickSnapCivZoneTypes = [
    "Hostage", "HVT", "SearchDestroy", "AssetRetrieval", "MineClearing",
    "ClearArea", "AreaOfOperations", "Operation", "Raid", "Invasion"
];
FADE_missionMapClickSnappedRadius = -2;
FADE_missionPlayerAnchorRadiusM = 5000;
FADE_missionMapPickTimeoutSec = 20;

// Trace bis_fnc_cp_getQueueDelay / bis_fnc_cp_main callers (installs stubs in DebugBIScpStub.sqf).
FADE_debugBIScp = false;
FADE_bisCpStubReapplyInterval = 2;
call compile preprocessFileLineNumbers "rsc\fn_bisCpPreInit.sqf";

// Locker Room ambient (client: rsc\LockerRoomAmbient.sqf)
FADE_lockerRoomCenterVar = "posLockerRoom";
FADE_lockerRoomRadius = 5;
FADE_lockerNearLockerDist = 2;
FADE_lockerPosVarMax = 64;
FADE_lockerSoundDelayMin = 3;
FADE_lockerSoundDelayRand = 3;
FADE_lockerHostageChance = 1;
