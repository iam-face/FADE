// AmbientCiviliansBoot.sqf - missionNamespace civ tuning defaults
// bis_fnc_cp_* stubs: see Config.sqf (loaded before this on server)

// Store config in missionNamespace
missionNamespace setVariable ["FADE_civTriggerIndexMax", missionNamespace getVariable ["FADE_civTriggerIndexMax", if (isNil "FADE_civTriggerIndexMax") then { 109 } else { FADE_civTriggerIndexMax }]];
missionNamespace setVariable ["FADE_civCheckInterval", missionNamespace getVariable ["FADE_civCheckInterval", 45]];
missionNamespace setVariable ["FADE_roadSpawnIntervalMin", missionNamespace getVariable ["FADE_roadSpawnIntervalMin", 90]];
missionNamespace setVariable ["FADE_roadSpawnIntervalMax", missionNamespace getVariable ["FADE_roadSpawnIntervalMax", 180]];
missionNamespace setVariable ["FADE_roadSpawnTickSec", missionNamespace getVariable ["FADE_roadSpawnTickSec", 60]];
missionNamespace setVariable ["FADE_roadSpawnChance", missionNamespace getVariable ["FADE_roadSpawnChance", 1]];
missionNamespace setVariable ["FADE_roadSpawnRingMin", missionNamespace getVariable ["FADE_roadSpawnRingMin", 1000]];
missionNamespace setVariable ["FADE_roadSpawnRingMax", missionNamespace getVariable ["FADE_roadSpawnRingMax", 2500]];
missionNamespace setVariable ["FADE_roadSpawnPlayerClear", missionNamespace getVariable ["FADE_roadSpawnPlayerClear", 500]];
missionNamespace setVariable ["FADE_roadFinalWpMinDist", missionNamespace getVariable ["FADE_roadFinalWpMinDist", 2000]];
missionNamespace setVariable ["FADE_civPlayerActivateDist", missionNamespace getVariable ["FADE_civPlayerActivateDist", 900]];
missionNamespace setVariable ["FADE_civPlayerDeactivateDist", missionNamespace getVariable ["FADE_civPlayerDeactivateDist", 1150]];
missionNamespace setVariable ["FADE_civSpawnRadius", missionNamespace getVariable ["FADE_civSpawnRadius", 1000]];
missionNamespace setVariable ["FADE_civFootSpawnRadius", missionNamespace getVariable ["FADE_civFootSpawnRadius", if (isNil "FADE_civFootSpawnRadius") then { 200 } else { FADE_civFootSpawnRadius }]];
missionNamespace setVariable ["FADE_civFootSpawnMinSep", missionNamespace getVariable ["FADE_civFootSpawnMinSep", if (isNil "FADE_civFootSpawnMinSep") then { 28 } else { FADE_civFootSpawnMinSep }]];
missionNamespace setVariable ["FADE_civParkedBuildingScanRadius", missionNamespace getVariable ["FADE_civParkedBuildingScanRadius", if (isNil "FADE_civParkedBuildingScanRadius") then { 380 } else { FADE_civParkedBuildingScanRadius }]];
missionNamespace setVariable ["FADE_civParkedRoadFromBuildingRadius", missionNamespace getVariable ["FADE_civParkedRoadFromBuildingRadius", if (isNil "FADE_civParkedRoadFromBuildingRadius") then { 100 } else { FADE_civParkedRoadFromBuildingRadius }]];
missionNamespace setVariable ["FADE_civParkedCenterRoadRadius", missionNamespace getVariable ["FADE_civParkedCenterRoadRadius", if (isNil "FADE_civParkedCenterRoadRadius") then { 260 } else { FADE_civParkedCenterRoadRadius }]];
missionNamespace setVariable ["FADE_civParkedWideRoadRadius", missionNamespace getVariable ["FADE_civParkedWideRoadRadius", if (isNil "FADE_civParkedWideRoadRadius") then { 400 } else { FADE_civParkedWideRoadRadius }]];
missionNamespace setVariable ["FADE_civParkedNearBuildingMax", missionNamespace getVariable ["FADE_civParkedNearBuildingMax", if (isNil "FADE_civParkedNearBuildingMax") then { 125 } else { FADE_civParkedNearBuildingMax }]];
missionNamespace setVariable ["FADE_civParkedMinAlongRoadM", missionNamespace getVariable ["FADE_civParkedMinAlongRoadM", if (isNil "FADE_civParkedMinAlongRoadM") then { 7 } else { FADE_civParkedMinAlongRoadM }]];
missionNamespace setVariable ["FADE_civParkedCrossRoadScan", missionNamespace getVariable ["FADE_civParkedCrossRoadScan", if (isNil "FADE_civParkedCrossRoadScan") then { 24 } else { FADE_civParkedCrossRoadScan }]];
missionNamespace setVariable ["FADE_civParkedCrossRoadClearM", missionNamespace getVariable ["FADE_civParkedCrossRoadClearM", if (isNil "FADE_civParkedCrossRoadClearM") then { 6.8 } else { FADE_civParkedCrossRoadClearM }]];
missionNamespace setVariable ["FADE_civParkedCrossRoadAngleMin", missionNamespace getVariable ["FADE_civParkedCrossRoadAngleMin", if (isNil "FADE_civParkedCrossRoadAngleMin") then { 38 } else { FADE_civParkedCrossRoadAngleMin }]];
missionNamespace setVariable ["FADE_civParkedCrossRoadHalfLen", missionNamespace getVariable ["FADE_civParkedCrossRoadHalfLen", if (isNil "FADE_civParkedCrossRoadHalfLen") then { 4.5 } else { FADE_civParkedCrossRoadHalfLen }]];
missionNamespace setVariable ["FADE_civWanderRadius", missionNamespace getVariable ["FADE_civWanderRadius", 100]];
missionNamespace setVariable ["FADE_civCountMin", missionNamespace getVariable ["FADE_civCountMin", 5]];
missionNamespace setVariable ["FADE_civCountMax", missionNamespace getVariable ["FADE_civCountMax", 15]];
missionNamespace setVariable ["FADE_civSpawnStaggerDelay", missionNamespace getVariable ["FADE_civSpawnStaggerDelay", 1.5]];
missionNamespace setVariable ["FADE_civSpawnBatchSize", missionNamespace getVariable ["FADE_civSpawnBatchSize", 2]];
missionNamespace setVariable ["FADE_roadVehicleMax", missionNamespace getVariable ["FADE_roadVehicleMax", 10]];
missionNamespace setVariable ["FADE_civMaxActiveZones", missionNamespace getVariable ["FADE_civMaxActiveZones", 4]];
missionNamespace setVariable ["FADE_civDebug", missionNamespace getVariable ["FADE_civDebug", false]];
missionNamespace setVariable ["FADE_civVehCleanupDist", missionNamespace getVariable ["FADE_civVehCleanupDist", if (isNil "FADE_civVehCleanupDist") then { 4500 } else { FADE_civVehCleanupDist }]];
missionNamespace setVariable ["FADE_civAirCleanupDist", missionNamespace getVariable ["FADE_civAirCleanupDist", if (isNil "FADE_civAirCleanupDist") then { -1 } else { FADE_civAirCleanupDist }]];
missionNamespace setVariable ["FADE_civGlobalMaxAlive", missionNamespace getVariable ["FADE_civGlobalMaxAlive", if (isNil "FADE_civGlobalMaxAlive") then { 55 } else { FADE_civGlobalMaxAlive }]];
missionNamespace setVariable ["FADE_civDensityScale", missionNamespace getVariable ["FADE_civDensityScale", if (isNil "FADE_civDensityScale") then { 1 } else { FADE_civDensityScale }]];
missionNamespace setVariable ["FADE_civUnitCullDist", missionNamespace getVariable ["FADE_civUnitCullDist", if (isNil "FADE_civUnitCullDist") then { 750 } else { FADE_civUnitCullDist }]];
// Ambient road car radio (Sig list / jukebox vehicle path): chance, proximity trigger, client vol/dist (fallback path; CfgVehicles Sound uses mission FAC_JukeVeh_*)
missionNamespace setVariable ["FADE_civCarRadioChance", missionNamespace getVariable ["FADE_civCarRadioChance", if (isNil "FADE_civCarRadioChance") then { 1 } else { FADE_civCarRadioChance }]];
missionNamespace setVariable ["FADE_civCarRadioTriggerDist", missionNamespace getVariable ["FADE_civCarRadioTriggerDist", if (isNil "FADE_civCarRadioTriggerDist") then { 1000 } else { FADE_civCarRadioTriggerDist }]];
missionNamespace setVariable ["FADE_civCarRadioVolume", missionNamespace getVariable ["FADE_civCarRadioVolume", if (isNil "FADE_civCarRadioVolume") then { 25 } else { FADE_civCarRadioVolume }]];
missionNamespace setVariable ["FADE_civCarRadioAudibleDist", missionNamespace getVariable ["FADE_civCarRadioAudibleDist", if (isNil "FADE_civCarRadioAudibleDist") then { 1000 } else { FADE_civCarRadioAudibleDist }]];
missionNamespace setVariable ["FADE_civCarRadioCheckInterval", missionNamespace getVariable ["FADE_civCarRadioCheckInterval", if (isNil "FADE_civCarRadioCheckInterval") then { 10 } else { FADE_civCarRadioCheckInterval }]];

// Filter to valid CfgVehicles classes: must exist, scope >= 2 (avoids "Cannot create non-ai vehicle" for player-only/private classes).
// When _unitsOnly is true, only classes that inherit from Man are kept (avoids "abstract type Civilian_F" / wrong type).
