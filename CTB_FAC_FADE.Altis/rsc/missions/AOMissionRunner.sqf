// AOMissionRunner.sqf - FADE_runMission_AreaOfOperations dispatch
if (!isServer) exitWith {};
FADE_runMission_AreaOfOperations = {
    [
        missionNamespace getVariable ["FADE_missionRun_player", objNull],
        missionNamespace getVariable ["FADE_missionRun_destPos", [0, 0, 0]],
        missionNamespace getVariable ["FADE_missionRun_taskId", ""],
        missionNamespace getVariable ["FADE_missionRun_basePos", [0, 0, 0]],
        missionNamespace getVariable ["FADE_missionRun_friendlyUnits", []],
        missionNamespace getVariable ["FADE_missionRun_enemyUnits", []],
        missionNamespace getVariable ["FADE_missionRun_operationNameUpper", ""],
        missionNamespace getVariable ["FADE_missionRun_operationName", ""]
    ] spawn {
        params ["_player", "_destPos", "_taskId", "_basePos", "_friendlyUnits", "_enemyUnits", "_operationNameUpper", "_operationName"];
        FADE_aoParams = [_player, _destPos, _taskId, _basePos, _friendlyUnits, _enemyUnits, _operationNameUpper, _operationName];
        [] call FADE_aoMissionMain;
    };
};
