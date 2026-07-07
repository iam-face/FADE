// =============================================================================
// AOMission.sqf - Area of Operations (compile shell)
// =============================================================================
if (!isServer) exitWith {};

FADE_aoMissionModuleList = [
    "rsc\missions\AOMissionInfil.sqf",
    "rsc\missions\AOMissionMain.sqf",
    "rsc\missions\AOMissionRunner.sqf"
];
missionNamespace setVariable ["FADE_aoMissionModuleList", FADE_aoMissionModuleList];

{ call compile preprocessFileLineNumbers _x } forEach FADE_aoMissionModuleList;
