// AUTO-EXTRACTED from Missions.sqf  -  run via FADE_runMission_* (compile once)
// Legacy single-player runner superseded by FADE_troopExtractMissionMain (multi-participant + waves).
if (!isServer) exitWith {};
FADE_runMission_TroopExtract = {
    if (isNil "FADE_troopExtractParams") exitWith {
        private _p = missionNamespace getVariable ["FADE_missionRun_player", objNull];
        if (!isNull _p) then { [_p] call FADE_clearActiveMission };
        ["TROOP EXTRACT: Use START to open the participant list (include yourself)."] remoteExec ["systemChat", _p];
    };
    [] call FADE_troopExtractMissionMain;
};
