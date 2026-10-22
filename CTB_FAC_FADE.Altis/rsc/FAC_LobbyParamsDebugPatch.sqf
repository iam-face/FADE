// =============================================================================
// FAC_LobbyParamsDebugPatch.sqf  -  DEBUG lobby params (indices 11-14; see FAC_LobbyParams.sqf)
// Load immediately after FAC_LobbyParams.sqf (ServerBootstrap, FAC_ensureLobbyParams).
// =============================================================================

if (missionNamespace getVariable ["FAC_lobbyParams_debugPatch_installed", false]) exitWith {};

missionNamespace setVariable ["FAC_lobbyParams_read_preDebugPatch", FAC_lobbyParams_read];
FAC_lobbyParams_read = {
    call (missionNamespace getVariable "FAC_lobbyParams_read_preDebugPatch");
    private _p = call FAC_lobbyParams_getArray;
    missionNamespace setVariable ["FAC_param_debugVgMarkers", _p param [FAC_LOBBY_IDX_DEBUG_VG_MARKERS, 0]];
    missionNamespace setVariable ["FAC_param_debugCivTownMarkers", _p param [FAC_LOBBY_IDX_DEBUG_CIV_TOWNS, 0]];
    missionNamespace setVariable ["FAC_param_debugPrintSpawns", _p param [FAC_LOBBY_IDX_DEBUG_PRINT_SPAWNS, 0]];
};

missionNamespace setVariable ["FAC_lobbyParams_applyScenarioDefaults_preDebugPatch", FAC_lobbyParams_applyScenarioDefaults];
FAC_lobbyParams_applyScenarioDefaults = {
    call (missionNamespace getVariable "FAC_lobbyParams_applyScenarioDefaults_preDebugPatch");
    if (!isServer) exitWith {};
    missionNamespace setVariable ["FADE_vgDebugMarkers", (missionNamespace getVariable ["FAC_param_debugVgMarkers", 0]) > 0, true];
    missionNamespace setVariable ["FADE_civTownDebugMarkers", (missionNamespace getVariable ["FAC_param_debugCivTownMarkers", 0]) > 0, true];
    missionNamespace setVariable ["FADE_spawnDebugPrint", (missionNamespace getVariable ["FAC_param_debugPrintSpawns", 0]) > 0, true];
};

missionNamespace setVariable ["FAC_lobbyParams_read", FAC_lobbyParams_read];
missionNamespace setVariable ["FAC_lobbyParams_applyScenarioDefaults", FAC_lobbyParams_applyScenarioDefaults];
missionNamespace setVariable ["FAC_lobbyParams_debugPatch_installed", true];
