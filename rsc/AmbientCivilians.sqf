// =============================================================================
// AmbientCivilians.sqf - thin compile shell (civ zones, road traffic, patrols)
// =============================================================================
if (!isServer) exitWith {};
diag_log "[AmbientCivilians] v4 loading (GUI faction only)";

FADE_ambientCiviliansModuleList = [
    "rsc\AmbientCiviliansBoot.sqf",
    "rsc\AmbientCiviliansPatrol.sqf",
    "rsc\AmbientCiviliansSpawn.sqf",
    "rsc\AmbientCiviliansMain.sqf"
];
missionNamespace setVariable ["FADE_ambientCiviliansModuleList", FADE_ambientCiviliansModuleList];

{ call compile preprocessFileLineNumbers _x } forEach FADE_ambientCiviliansModuleList;
