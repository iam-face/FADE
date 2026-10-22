// =============================================================================
// OperationMission.sqf - Global multi-zone capture (compile shell)
// =============================================================================
if (!isServer) exitWith {};

FADE_operationMissionModuleList = [
    "rsc\missions\OperationMissionPick.sqf",
    "rsc\missions\OperationMissionMain.sqf",
    "rsc\missions\OperationMissionRunner.sqf"
];
missionNamespace setVariable ["FADE_operationMissionModuleList", FADE_operationMissionModuleList];

{ call compile preprocessFileLineNumbers _x } forEach FADE_operationMissionModuleList;
