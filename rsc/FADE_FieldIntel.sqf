// =============================================================================
// FADE_FieldIntel.sqf — body search intel + search-zone refinement (server)
// =============================================================================

if (!isServer) exitWith {};
if (!isNil "FADE_fieldIntel_installed") exitWith {};
FADE_fieldIntel_installed = true;

FADE_fieldIntel_missionKey = {
    params ["_taskId"];
    "FADE_fieldIntel_" + _taskId
};

FADE_fieldIntel_getState = {
    params ["_taskId"];
    missionNamespace getVariable [[_taskId] call FADE_fieldIntel_missionKey, []]
};

FADE_fieldIntel_isEnabledForType = {
    params ["_missionType"];
    if !(missionNamespace getVariable ["FADE_fieldIntelEnabled", true]) exitWith { false };
    private _list = missionNamespace getVariable ["FADE_fieldIntelMissions", []];
    _missionType in _list
};

FADE_fieldIntel_bodyRankValue = {
    params ["_unit"];
    if (isNull _unit) exitWith { 0 };
    private _isLeader = _unit == leader (group _unit);
    private _cls = toLower (typeOf _unit);
    private _isOfficer = ("officer" in _cls) || { rank _unit in ["CAPTAIN", "MAJOR", "COLONEL", "GENERAL"] };
    if (_isLeader || _isOfficer) then { 2 } else { 1 }
};

FADE_fieldIntel_registerBody = {
    params ["_corpse", "_taskId", ["_bodyId", ""]];
    if (isNull _corpse || { _taskId == "" }) exitWith {};
    if (_corpse getVariable ["FADE_fieldIntel_searched", false]) exitWith {};
    if (_bodyId == "") then {
        _bodyId = format ["%1_%2", _taskId, floor (random 1e9)];
    };
    _corpse setVariable ["FADE_fieldIntel_taskId", _taskId, true];
    _corpse setVariable ["FADE_fieldIntel_bodyId", _bodyId, true];
    _corpse setVariable ["FADE_fieldIntel_rankValue", [_corpse] call FADE_fieldIntel_bodyRankValue, true];
    [_corpse] remoteExecCall ["FADE_fieldIntel_clientRegisterBody", 0, _corpse];
};

FADE_fieldIntel_registerGroups = {
    params ["_taskId", "_groups"];
    if (_taskId == "") exitWith {};
    {
        if (isNull _x) then { continue };
        {
            if (alive _x) then {
                _x addEventHandler ["Killed", {
                    params ["_unit"];
                    private _tid = _unit getVariable ["FADE_fieldIntel_missionTaskId", ""];
                    if (_tid == "") exitWith {};
                    [_unit, _tid] call FADE_fieldIntel_registerBody;
                }];
                _x setVariable ["FADE_fieldIntel_missionTaskId", _taskId, true];
            };
        } forEach units _x;
    } forEach _groups;
};

FADE_fieldIntel_applyGeometry = {
    params ["_state", "_revealLevel", ["_snapToTrue", false]];
    if (_state isEqualType [] && { count _state < 13 }) exitWith {};
    _state params [
        "_taskId", "_missionType", "_truePos", "_anchorPos", "_mustContain",
        "_mode", "_iconMarker", "_zoneKey", "_gridNames", "_initialRadius",
        "_points", "_revealLevelOld", "_markerColor"
    ];
    private _maxPts = missionNamespace getVariable ["FADE_fieldIntelMaxPoints", 100];
    private _frac = (_revealLevel / _maxPts) min 1 max 0;
    private _markerPos = +_anchorPos;
    private _radius = _initialRadius;
    private _contain = +_mustContain;
    _contain pushBackUnique +_truePos;
    if (_snapToTrue) then {
        _markerPos = +_truePos;
        _radius = missionNamespace getVariable ["FADE_fieldIntelRevealSnapRadiusM", 45];
    } else {
        private _shrink = 1 - (_frac * 0.75);
        private _nominal = (_initialRadius * _shrink) max (missionNamespace getVariable ["FADE_fieldIntelRevealSnapRadiusM", 45]);
        private _computed = [_anchorPos, _nominal, 0, _contain] call FADE_mission_computeSearchZone;
        _computed params ["_markerPos", "_radius"];
    };
    if (_mode == "grid") then {
        if (_snapToTrue) then {
            _gridNames = [_taskId, _zoneKey, _markerPos, _radius, _markerColor, _contain] call FADE_mission_createGridZoneMarkers;
        } else {
            if (_frac > 0 && { _zoneKey != "" } && { getMarkerColor _zoneKey != "" }) then {
                _zoneKey setMarkerShape "ELLIPSE";
                _zoneKey setMarkerBrush "Border";
                _zoneKey setMarkerAlpha (missionNamespace getVariable ["FADE_missionRadiusMarkerAlpha", 1]);
                [_zoneKey, _markerPos, _radius] call FADE_mission_setRadiusMarkerGeometry;
                _gridNames = [_zoneKey];
            } else {
                _gridNames = [_taskId, _zoneKey, _markerPos, _radius, _markerColor, _contain] call FADE_mission_createGridZoneMarkers;
            };
        };
    } else {
        if (_zoneKey != "" && { markerShape _zoneKey != "" }) then {
            [_zoneKey, _markerPos, _radius] call FADE_mission_setRadiusMarkerGeometry;
        };
    };
    if (_iconMarker != "" && { getMarkerColor _iconMarker != "" }) then {
        private _iconPos = if (_snapToTrue) then { +_truePos } else { +_markerPos };
        _iconMarker setMarkerPos ([_iconPos] call FADE_normPos3);
    };
    _state set [8, _gridNames];
    missionNamespace setVariable [[_taskId] call FADE_fieldIntel_missionKey, _state];
    _state
};

FADE_fieldIntel_addPoints = {
    params ["_taskId", "_delta", ["_sourceLabel", "Intel"]];
    private _state = [_taskId] call FADE_fieldIntel_getState;
    if !(_state isEqualType []) exitWith { false };
    if (count _state < 13) exitWith { false };
    private _maxPts = missionNamespace getVariable ["FADE_fieldIntelMaxPoints", 100];
    private _pts = (_state select 10) + _delta;
    _pts = _pts min _maxPts max 0;
    _state set [10, _pts];
    missionNamespace setVariable [[_taskId] call FADE_fieldIntel_missionKey, _state];
    private _prevLevel = _state select 11;
    private _thresholds = [25, 50, 75, 100];
    private _newLevel = 0;
    {
        if (_pts >= _x) then { _newLevel = _x };
    } forEach _thresholds;
    if (_delta > 0) then {
        [_state, _pts, _pts >= _maxPts] call FADE_fieldIntel_applyGeometry;
        // #region agent log
        diag_log format [
            "[FAC DbgBrowser 62d308] H16 fieldIntel refine task=%1 pts=%2/%3 level=%4 radiusMode=%5",
            _taskId, _pts, _maxPts, _newLevel, _state select 5
        ];
        // #endregion
    };
    if (_newLevel > _prevLevel) then {
        _state set [11, _newLevel];
        missionNamespace setVariable [[_taskId] call FADE_fieldIntel_missionKey, _state];
        private _msg = switch (true) do {
            case (_newLevel >= 100): { "Intel confirms objective location — search area refined to grid." };
            case (_newLevel >= 75): { "Intel narrows the search area significantly." };
            case (_newLevel >= 50): { "Intel refines the search area." };
            default { "Partial intel received — search area slightly reduced." };
        };
        [_msg] remoteExec ["FADE_showMissionHint", 0];
        if (_newLevel >= 100 && { !isNil "BIS_fnc_taskSetDestination" }) then {
            private _truePos = _state select 2;
            private _destTask = if (count _state > 13 && { (_state select 13) != "" }) then { _state select 13 } else { _taskId };
            [_destTask, _truePos] call BIS_fnc_taskSetDestination;
        };
    };
    if (missionNamespace getVariable ["FADE_intelDiaryLog", false]) then {
        private _cumPct = round ((_pts / _maxPts) * 100);
        private _grid = mapGridPosition (_state select 2);
        private _line = format [
            "%1: objective grid %2 (search %3%% refined, +%4%% this find).",
            _sourceLabel, _grid, _cumPct, round (_delta / _maxPts * 100)
        ];
        [_line] remoteExec ["FADE_intel_clientAppendIntelDiary", 0];
    };
    true
};

FADE_fieldIntel_serverBodySearch = {
    params ["_corpse", "_searcher"];
    if (!isServer) exitWith {};
    if (isNull _corpse || { isNull _searcher }) exitWith {};
    if !(_searcher isKindOf "Man") exitWith {};
    if (_corpse getVariable ["FADE_fieldIntel_searched", false]) exitWith {};
    private _taskId = _corpse getVariable ["FADE_fieldIntel_taskId", ""];
    if (_taskId == "") exitWith {};
    if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "FAILED", "CANCELED"]) exitWith {};
    private _distM = missionNamespace getVariable ["FADE_fieldIntelBodySearchDistM", 3];
    if ((getPosATL _searcher) distance (getPosATL _corpse) > (_distM + 1.5)) exitWith {};
    _corpse setVariable ["FADE_fieldIntel_searched", true, true];
    private _emptyChance = missionNamespace getVariable ["FADE_fieldIntelBodySearchEmptyChance", 0.15];
    if (random 1 < _emptyChance) exitWith {
        [format ["No usable intel on %1.", name _corpse]] remoteExec ["FADE_showMissionHint", owner _searcher];
    };
    private _rankVal = _corpse getVariable ["FADE_fieldIntel_rankValue", 1];
    private _pts = if (_rankVal >= 2) then {
        missionNamespace getVariable ["FADE_fieldIntelBodySearchPointsLeader", 30]
    } else {
        missionNamespace getVariable ["FADE_fieldIntelBodySearchPointsRegular", 18]
    };
    [_taskId, _pts, "Body search"] call FADE_fieldIntel_addPoints;
    [format ["Recovered intel from %1.", name _corpse]] remoteExec ["FADE_showMissionHint", owner _searcher];
};

FADE_fieldIntel_startForMission = {
    params [
        "_taskId",
        "_missionType",
        "_truePos",
        "_markerOut",
        "_enemyGroups",
        ["_markerColor", "ColorEAST"],
        ["_destTaskId", ""]
    ];
    if !([_missionType] call FADE_fieldIntel_isEnabledForType) exitWith {};
    if (_taskId == "" || { _markerOut isEqualType [] && { count _markerOut < 4 } }) exitWith {};
    if (_destTaskId == "") then { _destTaskId = _taskId };
    private _icon = _markerOut select 0;
    private _zoneKey = _markerOut select 1;
    private _markerPos = _markerOut select 2;
    private _radius = _markerOut select 3;
    private _gridNames = if (count _markerOut > 4) then { _markerOut select 4 } else { [] };
    private _mode = if (_zoneKey find "_grid" >= 0) then { "grid" } else { "ellipse" };
    private _mustContain = [+_truePos];
    private _state = [
        _taskId,
        _missionType,
        +_truePos,
        +_markerPos,
        [+_truePos],
        _mode,
        _icon,
        _zoneKey,
        +_gridNames,
        _radius,
        0,
        0,
        _markerColor,
        _destTaskId
    ];
    missionNamespace setVariable [[_taskId] call FADE_fieldIntel_missionKey, _state];
    [_taskId, _enemyGroups] call FADE_fieldIntel_registerGroups;
};

FADE_fieldIntel_endRaidZones = {
    params ["_parentTaskId", "_zoneCount"];
    if (_parentTaskId == "" || { _zoneCount < 1 }) exitWith {};
    for "_i" from 1 to _zoneCount do {
        [format ["%1_raid_obj_%2", _parentTaskId, _i]] call FADE_fieldIntel_endMission;
    };
};

FADE_fieldIntel_endMission = {
    params ["_taskId"];
    private _state = [_taskId] call FADE_fieldIntel_getState;
    if (_state isEqualType [] && { count _state >= 9 }) then {
        private _zoneKey = _state select 7;
        private _gridNames = _state select 8;
        if (_zoneKey != "") then { [_zoneKey, _gridNames] call FADE_mission_deleteGridZoneMarkers };
    };
    missionNamespace setVariable [[_taskId] call FADE_fieldIntel_missionKey, nil];
};

missionNamespace setVariable ["FADE_fieldIntel_registerGroups", FADE_fieldIntel_registerGroups];
missionNamespace setVariable ["FADE_fieldIntel_endRaidZones", FADE_fieldIntel_endRaidZones];
missionNamespace setVariable ["FADE_fieldIntel_serverBodySearch", FADE_fieldIntel_serverBodySearch];
missionNamespace setVariable ["FADE_fieldIntel_startForMission", FADE_fieldIntel_startForMission];
missionNamespace setVariable ["FADE_fieldIntel_endMission", FADE_fieldIntel_endMission];
missionNamespace setVariable ["FADE_fieldIntel_addPoints", FADE_fieldIntel_addPoints];
publicVariable "FADE_fieldIntel_serverBodySearch";
