// =============================================================================
// FAC_DebugLobbyServerApply.sqf  -  apply DEBUG lobby params (indices 18-20) on server
// Loaded from initServer.sqf after ServerBootstrap (patches FAC_LobbyParams at runtime).
// =============================================================================

if (!isServer) exitWith {};

if (isNil "FAC_lobbyParams_debugPatch_installed") then {
    call compile preprocessFileLineNumbers "rsc\FAC_LobbyParamsDebugPatch.sqf";
};
call FAC_lobbyParams_read;

missionNamespace setVariable [
    "FADE_vgDebugMarkers",
    (missionNamespace getVariable ["FAC_param_debugVgMarkers", 0]) > 0,
    true
];
missionNamespace setVariable [
    "FADE_civTownDebugMarkers",
    (missionNamespace getVariable ["FAC_param_debugCivTownMarkers", 0]) > 0,
    true
];
missionNamespace setVariable [
    "FADE_spawnDebugPrint",
    (missionNamespace getVariable ["FAC_param_debugPrintSpawns", 0]) > 0,
    true
];
