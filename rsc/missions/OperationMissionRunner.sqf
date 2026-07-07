// OperationMissionRunner.sqf - FADE_runMission_Operation dispatch
if (!isServer) exitWith {};
FADE_runMission_Operation = {
    private _fromMapClick = missionNamespace getVariable ["FADE_missionRun_fromMapClick", false];
    private _mapAnchor = missionNamespace getVariable ["FADE_missionRun_mapAnchor", []];
    if (!_fromMapClick) then { _mapAnchor = [] };
    [
        missionNamespace getVariable ["FADE_missionRun_player", objNull],
        _mapAnchor,
        missionNamespace getVariable ["FADE_missionRun_taskId", ""],
        missionNamespace getVariable ["FADE_missionRun_basePos", [0, 0, 0]],
        missionNamespace getVariable ["FADE_missionRun_enemyUnits", []],
        missionNamespace getVariable ["FADE_missionRun_operationNameUpper", ""],
        missionNamespace getVariable ["FADE_missionRun_operationName", ""]
    ] spawn {
        params ["_player", "_mapAnchor", "_taskId", "_basePos", "_enemyUnits", "_operationNameUpper", "_operationName"];
        FADE_operationParams = [_player, _mapAnchor, _taskId, _basePos, _enemyUnits, _operationNameUpper, _operationName];
        [] call FADE_operationMissionMain;
    };
};
