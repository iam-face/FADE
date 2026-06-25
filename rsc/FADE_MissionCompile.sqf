// =============================================================================
// FADE_MissionCompile.sqf  -  compile mission dispatcher + runners once (server boot)
// =============================================================================

FADE_missionModuleList = [
    "rsc\FADE_MissionSpawn.sqf",
    "rsc\FADE_MissionCommon.sqf",
    "rsc\Missions.sqf",
    "rsc\missions\AOMission.sqf",
    "rsc\missions\OperationMission.sqf",
    "rsc\TroopInsertTransport.sqf",
    "rsc\missions\TroopInsertMission.sqf",
    "rsc\missions\MissionAssetRetrieval.sqf",
    "rsc\missions\MissionSearchDestroy.sqf",
    "rsc\missions\MissionCasevacCsar.sqf",
    "rsc\missions\MissionInterceptConvoy.sqf",
    "rsc\missions\MissionEscapeEvasion.sqf",
    "rsc\missions\MissionCAS.sqf",
    "rsc\missions\MissionCargo.sqf",
    "rsc\missions\MissionHVT.sqf",
    "rsc\missions\MissionHostage.sqf",
    "rsc\missions\MissionClearArea.sqf",
    "rsc\missions\MissionMineClearing.sqf",
    "rsc\missions\MissionTroopExtract.sqf",
    "rsc\TroopTransport.sqf"
];

FADE_installMissionModules = {
    if (!isServer) exitWith {};
    if (missionNamespace getVariable ["FADE_missions_installed", false]) exitWith {};
    private _t0 = if (missionNamespace getVariable ["FADE_profileMissionLoad", false]) then { diag_tickTime } else { -1 };
    {
        call compile preprocessFileLineNumbers _x;
    } forEach FADE_missionModuleList;
    missionNamespace setVariable ["FADE_missions_installed", true];
    if (_t0 >= 0) then {
        ["mission modules compile", _t0] call FADE_profile_log;
    };
};

missionNamespace setVariable ["FADE_installMissionModules", FADE_installMissionModules];
