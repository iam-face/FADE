// =============================================================================
// MissionInvasion.sqf - Global defensive invasion (compile shell)
// =============================================================================
if (!isServer) exitWith {};

FADE_invasionMissionModuleList = [
    "rsc\missions\MissionInvasionHelpers.sqf",
    "rsc\missions\MissionInvasionMain.sqf",
    "rsc\missions\MissionInvasionRunner.sqf"
];
missionNamespace setVariable ["FADE_invasionMissionModuleList", FADE_invasionMissionModuleList];

{ call compile preprocessFileLineNumbers _x } forEach FADE_invasionMissionModuleList;
