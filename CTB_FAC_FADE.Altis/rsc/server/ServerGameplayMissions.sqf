// =============================================================================
// ServerGameplayMissions.sqf - thin compile shell
// =============================================================================

FADE_serverGameplayMissionsModuleList = [
    "rsc\server\ServerGameplayMissionsStart.sqf",
    "rsc\server\ServerGameplayMissionsPick.sqf",
    "rsc\server\ServerGameplayMissionsCore.sqf"
];
missionNamespace setVariable ["FADE_serverGameplayMissionsModuleList", FADE_serverGameplayMissionsModuleList];

{ call compile preprocessFileLineNumbers _x } forEach FADE_serverGameplayMissionsModuleList;
