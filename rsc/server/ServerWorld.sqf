// =============================================================================
// ServerWorld.sqf - thin compile shell (world, placement, QRF, mission entity registry)
// =============================================================================
if (!isServer) exitWith {};

FADE_serverWorldModuleList = [
    "rsc\server\ServerWorldWeather.sqf",
    "rsc\server\ServerWorldEden.sqf",
    "rsc\server\ServerWorldPlacementConsts.sqf",
    "rsc\server\ServerWorldMissionEnt.sqf",
    "rsc\server\ServerWorldQrf.sqf",
    "rsc\server\ServerWorldPlacement.sqf"
];
missionNamespace setVariable ["FADE_serverWorldModuleList", FADE_serverWorldModuleList];

call compile preprocessFileLineNumbers "rsc\RoadblockCommon.sqf";
if (missionNamespace getVariable ["FADE_dynamicRoadblocksEnabled", false]) then {
    [] execVM "rsc\DynamicRoadblocks.sqf";
};
[] execVM "rsc\DummyUnits.sqf";

{
    call compile preprocessFileLineNumbers _x;
} forEach FADE_serverWorldModuleList;
