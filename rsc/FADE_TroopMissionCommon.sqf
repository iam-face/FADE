// =============================================================================
// FADE_TroopMissionCommon.sqf  -  shared Troop Insert / Extract server helpers
// =============================================================================
if (!isServer) exitWith {};

FADE_troopMission_metaChat = {
    params ["_participants", "_msg"];
    { [_msg] remoteExec ["systemChat", _x] } forEach _participants;
};

FADE_troopMission_liveParticipants = {
    params ["_participants"];
    _participants select { !isNull _x && { alive _x } }
};

FADE_troopMission_unitClassesForParticipant = {
    params ["_participant", "_friendlyUnits"];
    if (isNull _participant || { !alive _participant }) exitWith { _friendlyUnits };
    private _cfgRoot = configFile >> "CfgVehicles";
    private _pFac = getText (_cfgRoot >> typeOf _participant >> "faction");
    if (_pFac == "") exitWith { _friendlyUnits };
    private _matched = _friendlyUnits select { getText (_cfgRoot >> _x >> "faction") == _pFac };
    if (count _matched > 0) then { _matched } else { _friendlyUnits }
};

FADE_troopMission_squadRadio = {
    params ["_grp", "_msg"];
    if (isNull _grp || { count units _grp == 0 }) exitWith {};
    private _ldr = leader _grp;
    if (isNull _ldr || { !alive _ldr }) exitWith {};
    [_ldr, _msg] call FADE_aiSideChat;
};

FADE_troopMission_createPickupMarker = {
    params ["_taskId", "_markerPrefix", "_markerFriendly", "_pickupMarkers", "_owner", "_pos", "_label"];
    if (isNull _owner) exitWith { "" };
    private _mkr = format ["FADE_%1_pick_%2_%3", _markerPrefix, _taskId, getPlayerUID _owner];
    private _labelOut = if (_label != "") then { _label } else { "Squad link-up" };
    [_mkr, _pos, _labelOut, _markerFriendly] remoteExec ["FAC_troopInsertClient_createPickupMarker", _owner];
    _pickupMarkers pushBack [_mkr, _owner];
    _mkr
};

FADE_troopMission_clearPickupMarkers = {
    params ["_pickupMarkers"];
    {
        _x params ["_mkrName", "_owner"];
        if (!isNull _owner) then {
            [_mkrName] remoteExec ["FAC_troopInsertClient_deletePickupMarker", _owner];
        };
    } forEach _pickupMarkers;
    _pickupMarkers resize 0;
};

FADE_troopMission_deleteFriendlyGroups = {
    params ["_groups", "_cleanupVar"];
    {
        if (!isNull _x) then {
            _x setVariable [_cleanupVar, true, true];
            { if (!isNull _x) then { detach _x; deleteVehicle _x } } forEach (_x getVariable ["FADE_irStrobes", []]);
            { if (!isNull _x) then { deleteVehicle _x } } forEach units _x;
            deleteGroup _x;
        };
    } forEach _groups;
};

FADE_troopMission_waveAllTransportOk = {
    params ["_pairList", "_waveIdx", "_taskId", "_modePrefix", "_transportDoneVar"];
    if (_pairList isEqualTo []) exitWith { false };
    private _waveOkKey = format ["FADE_%1WaveOk_%2_%3", _modePrefix, _taskId, _waveIdx];
    private _ok = true;
    {
        _x params ["_grp", "_owner"];
        private _ownerOk = !isNull _owner && { _owner getVariable [_waveOkKey, false] };
        private _grpOk = !isNull _grp && { _grp getVariable [_transportDoneVar, false] };
        if (!_ownerOk && { !_grpOk }) then { _ok = false };
    } forEach _pairList;
    _ok
};

FADE_troopMission_runTransportWave = {
    params [
        "_pairs",
        "_waveIdx",
        "_waveTotal",
        "_runFn",
        "_taskId",
        "_markerName",
        "_abortFlag",
        "_claimedVehKey",
        "_waveTimeout",
        "_missionEnded",
        "_modePrefix",
        "_transportDoneVar",
        "_cleanupVar",
        "_spawnArgs",
        ["_pickFallback", []]
    ];
    if (_missionEnded) exitWith { [] };
    if (isNil "_runFn") exitWith { [] };
    missionNamespace setVariable [_claimedVehKey, [], true];
    private _waveOkKeyPrefix = format ["FADE_%1WaveOk_%2_", _modePrefix, _taskId];
    private _scripts = [];
    private _waveStart = time;
    {
        _x params ["_grp", "_owner", ["_pick", []], ["_pickMkr", ""]];
        private _pickUse = if (count _pick >= 2) then { _pick } else { _pickFallback };
        if (!isNull _owner) then {
            _owner setVariable [_waveOkKeyPrefix + str _waveIdx, false, false];
        };
        if (!isNull _grp && { count units _grp > 0 }) then {
            _grp setVariable [_transportDoneVar, false, true];
            private _scr = [_grp, _owner, _pickUse, _spawnArgs, _taskId, _markerName, _abortFlag, _claimedVehKey, _pickMkr, _waveIdx, _waveTotal] spawn _runFn;
            _scripts pushBack [_scr, _grp, _owner];
        };
    } forEach _pairs;
    if (count _scripts == 0) exitWith { _scripts };
    waitUntil {
        sleep 2;
        if (_missionEnded || { missionNamespace getVariable [_abortFlag, false] }) exitWith { true };
        ({ scriptDone (_x select 0) } count _scripts) == count _scripts || { time - _waveStart > _waveTimeout }
    };
    private _modeLabel = if (_modePrefix == "ti") then { "TROOP INSERT" } else { "TROOP EXTRACT" };
    {
        _x params ["_scr", "_grp", "_owner"];
        private _ownerOk = !isNull _owner && { _owner getVariable [_waveOkKeyPrefix + str _waveIdx, false] };
        private _grpOk = !isNull _grp && { _grp getVariable [_transportDoneVar, false] };
        if (!_ownerOk && { !_grpOk }) then {
            if (!isNull _grp && { !(_grp getVariable [_cleanupVar, false]) }) then {
                if (_modePrefix == "te") then {
                    [_grp] call FADE_missionEnt_deleteGroupFull;
                } else {
                    { if (!isNull _x) then { detach _x; deleteVehicle _x } } forEach (_grp getVariable ["FADE_irStrobes", []]);
                    { if (!isNull _x) then { deleteVehicle _x } } forEach units _grp;
                    deleteGroup _grp;
                };
            };
            if (!isNull _owner) then {
                [format ["%1: Your squad transport failed or timed out (wave %2/%3).", _modeLabel, _waveIdx, _waveTotal]] remoteExec ["systemChat", _owner];
            };
        };
    } forEach _scripts;
    _scripts
};

FADE_troopMission_clearParticipantMissionVars = {
    params ["_participants"];
    {
        if (!isNull _x) then {
            _x setVariable ["FADE_myMission", "", true];
            _x setVariable ["FADE_myMissionTaskId", nil, true];
            _x setVariable ["FADE_myMissionMarker", nil, true];
            _x setVariable ["FADE_myMissionMarkerEnd", nil, true];
            _x setVariable ["FADE_myMissionBrief", nil, true];
        };
    } forEach _participants;
};

missionNamespace setVariable ["FADE_troopMission_metaChat", FADE_troopMission_metaChat];
missionNamespace setVariable ["FADE_troopMission_liveParticipants", FADE_troopMission_liveParticipants];
missionNamespace setVariable ["FADE_troopMission_unitClassesForParticipant", FADE_troopMission_unitClassesForParticipant];
missionNamespace setVariable ["FADE_troopMission_squadRadio", FADE_troopMission_squadRadio];
missionNamespace setVariable ["FADE_troopMission_createPickupMarker", FADE_troopMission_createPickupMarker];
missionNamespace setVariable ["FADE_troopMission_clearPickupMarkers", FADE_troopMission_clearPickupMarkers];
missionNamespace setVariable ["FADE_troopMission_deleteFriendlyGroups", FADE_troopMission_deleteFriendlyGroups];
missionNamespace setVariable ["FADE_troopMission_waveAllTransportOk", FADE_troopMission_waveAllTransportOk];
missionNamespace setVariable ["FADE_troopMission_runTransportWave", FADE_troopMission_runTransportWave];
missionNamespace setVariable ["FADE_troopMission_clearParticipantMissionVars", FADE_troopMission_clearParticipantMissionVars];
