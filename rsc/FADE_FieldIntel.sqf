// =============================================================================
// FADE_FieldIntel.sqf — body search intel + search-zone refinement (server)
// State: 0 taskId, 1 missionType, 2 truePos, 3 anchorPos, 4 objectivePositions,
// 5 mode, 6 iconMarker, 7 zoneKey, 8 gridNames, 9 initialRadius,
// 10 points, 11 revealLevel, 12 markerColor, 13 destTaskId,
// 14 trackUnit, 15 currentCentre, 16 currentHalfSize
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

FADE_fieldIntel_normalisePos = {
    params ["_p"];
    if !(_p isEqualType []) exitWith { [] };
    if (count _p < 2) exitWith { [] };
    if (count _p < 3) then { _p = [(_p select 0), (_p select 1), 0] };
    _p
};

FADE_fieldIntel_objectivePositions = {
    params ["_state"];
    private _out = [];
    if (count _state > 4 && { (_state select 4) isEqualType [] }) then {
        {
            private _p = [_x] call FADE_fieldIntel_normalisePos;
            if (count _p >= 2) then { _out pushBack _p };
        } forEach (_state select 4);
    };
    if (_out isEqualTo [] && { count _state > 2 }) then {
        private _p = [_state select 2] call FADE_fieldIntel_normalisePos;
        if (count _p >= 2) then { _out pushBack _p };
    };
    _out
};

// Stored objectives, plus the tracked unit's position at this moment (HVT).
FADE_fieldIntel_containPositions = {
    params ["_state"];
    private _contain = [_state] call FADE_fieldIntel_objectivePositions;
    if (count _state > 14) then {
        private _track = _state select 14;
        if (!isNull _track && { alive _track }) then {
            private _p = [getPosATL _track] call FADE_fieldIntel_normalisePos;
            if (count _p >= 2) then { _contain pushBack _p };
        };
    };
    _contain
};

FADE_fieldIntel_bodyRankValue = {
    params ["_unit"];
    if (isNull _unit) exitWith { 0 };
    private _isLeader = _unit == leader (group _unit);
    private _cls = toLower (typeOf _unit);
    private _isOfficer = ("officer" in _cls) || { rank _unit in ["LIEUTENANT", "CAPTAIN", "MAJOR", "COLONEL", "GENERAL"] };
    if (_isLeader || _isOfficer) then { 2 } else { 1 }
};

FADE_fieldIntel_hintText = {
    params ["_level", ["_objectiveCount", 1]];
    private _many = _objectiveCount > 1;
    switch (true) do {
        case (_level >= 100): {
            if (_many) then {
                "The marked area contains the objectives."
            } else {
                "The marked area contains the objective."
            }
        };
        case (_level >= 75): {
            if (_many) then {
                "The marked area is much smaller. The objectives are still inside it."
            } else {
                "The marked area is much smaller. The objective is still inside it."
            }
        };
        case (_level >= 50): {
            if (_many) then {
                "The marked area is tighter. The objectives are still inside it."
            } else {
                "The marked area is tighter. The objective is still inside it."
            }
        };
        default {
            if (_many) then {
                "Partial intel. The marked area is smaller. The objectives are still inside it."
            } else {
                "Partial intel. The marked area is smaller. The objective is still inside it."
            }
        };
    }
};

FADE_fieldIntel_diaryBody = {
    params ["_contain", "_confirmed", ["_namedCount", 1]];
    if (_confirmed) then {
        private _grids = [];
        {
            if (_x isEqualType [] && { count _x >= 2 }) then {
                _grids pushBackUnique (mapGridPosition _x);
            };
        } forEach _contain;
        if (count _grids <= 1) then {
            format ["Objective grid: %1.", _grids param [0, "unknown"]]
        } else {
            format ["Objective grids: %1.", _grids joinString ", "]
        }
    } else {
        if (_namedCount > 1) then {
            "The marked area is smaller. The objectives are still inside it."
        } else {
            "The marked area is smaller. The objective is still inside it."
        }
    }
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
    if (isNil { _corpse getVariable "FADE_fieldIntel_rankValue" }) then {
        _corpse setVariable ["FADE_fieldIntel_rankValue", [_corpse] call FADE_fieldIntel_bodyRankValue, true];
    };
    [_corpse] remoteExecCall ["FADE_fieldIntel_clientRegisterBody", 0, _corpse];
};

FADE_fieldIntel_registerGroups = {
    params ["_taskId", "_groups"];
    if (_taskId == "") exitWith {};
    private _state = [_taskId] call FADE_fieldIntel_getState;
    if !(_state isEqualType []) exitWith {};
    if (count _state < 13) exitWith {};
    {
        if (isNull _x) then { continue };
        {
            if (alive _x) then {
                if (_x getVariable ["FADE_fieldIntel_missionTaskId", ""] == _taskId) then { continue };
                _x setVariable ["FADE_fieldIntel_missionTaskId", _taskId, true];
                _x setVariable ["FADE_fieldIntel_rankValue", [_x] call FADE_fieldIntel_bodyRankValue, true];
                _x addEventHandler ["Killed", {
                    params ["_unit"];
                    private _tid = _unit getVariable ["FADE_fieldIntel_missionTaskId", ""];
                    if (_tid == "") exitWith {};
                    [_unit, _tid] call FADE_fieldIntel_registerBody;
                }];
            };
        } forEach units _x;
    } forEach _groups;
};

FADE_fieldIntel_applyGeometry = {
    params ["_state", "_revealLevel", ["_snapToTrue", false]];
    if !(_state isEqualType []) exitWith { [] };
    if (count _state < 13) exitWith { _state };
    _state params [
        "_taskId", "_missionType", "_truePos", "_anchorPos", "_objectivePositions",
        "_mode", "_iconMarker", "_zoneKey", "_gridNames", "_initialRadius",
        "_points", "_revealLevelOld", "_markerColor"
    ];
    private _maxPts = missionNamespace getVariable ["FADE_fieldIntelMaxPoints", 100];
    private _frac = (_revealLevel / _maxPts) min 1 max 0;
    private _contain = [_state] call FADE_fieldIntel_containPositions;
    private _snapR = missionNamespace getVariable ["FADE_fieldIntelRevealSnapRadiusM", 45];
    private _nominal = if (_snapToTrue) then {
        _snapR
    } else {
        (_initialRadius * (1 - (_frac * 0.75))) max _snapR
    };
    private _computed = [_anchorPos, _nominal, 0, _contain] call FADE_mission_computeSearchZone;
    _computed params ["_markerPos", "_radius"];
    if (_zoneKey != "") then {
        _gridNames = [_taskId, _zoneKey, _markerPos, _radius, _markerColor, _contain] call FADE_mission_createGridZoneMarkers;
        if (getMarkerColor _zoneKey != "") then {
            private _centre = getMarkerPos _zoneKey;
            _state set [15, _centre];
            _state set [16, getMarkerSize _zoneKey];
            if (_iconMarker != "" && { getMarkerColor _iconMarker != "" }) then {
                _iconMarker setMarkerPos ([_centre] call FADE_normPos3);
            };
        } else {
            _state set [15, _markerPos];
            _state set [16, [_radius, _radius]];
        };
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
    private _pts = ((_state select 10) + _delta) min _maxPts max 0;
    _state set [10, _pts];
    missionNamespace setVariable [[_taskId] call FADE_fieldIntel_missionKey, _state];
    private _prevLevel = _state select 11;
    private _newLevel = 0;
    {
        if (_pts >= _x) then { _newLevel = _x };
    } forEach [25, 50, 75, 100];
    if (_newLevel > _prevLevel) then {
        private _confirmed = _newLevel >= 100;
        private _applied = [_state, _pts, _confirmed] call FADE_fieldIntel_applyGeometry;
        if (_applied isEqualType [] && { count _applied >= 13 }) then { _state = _applied };
        _state set [11, _newLevel];
        missionNamespace setVariable [[_taskId] call FADE_fieldIntel_missionKey, _state];
        private _namedCount = count ([_state] call FADE_fieldIntel_objectivePositions);
        private _contain = [_state] call FADE_fieldIntel_containPositions;
        private _msg = [_newLevel, _namedCount] call FADE_fieldIntel_hintText;
        [_msg] remoteExec ["FADE_showMissionHint", 0];
        if (_confirmed && { !isNil "BIS_fnc_taskSetDestination" }) then {
            private _destTask = if (count _state > 13 && { (_state select 13) isEqualType "" && { (_state select 13) != "" } }) then {
                _state select 13
            } else {
                _taskId
            };
            if ((_destTask call BIS_fnc_taskState) in ["ASSIGNED", "CREATED"]) then {
                private _destPos = [];
                if (count _state > 14) then {
                    private _track = _state select 14;
                    if (!isNull _track && { alive _track }) then { _destPos = getPosATL _track };
                };
                if (count _destPos < 2 && { count _contain > 0 }) then { _destPos = _contain select 0 };
                if (count _destPos >= 2) then {
                    [_destTask, _destPos] call BIS_fnc_taskSetDestination;
                };
            };
        };
        if (missionNamespace getVariable ["FADE_intelDiaryLog", false]) then {
            private _whenStr = format ["Mission +%1 min", floor (time / 60) max 0];
            private _body = [_contain, _confirmed, _namedCount] call FADE_fieldIntel_diaryBody;
            ["Body search", _whenStr, _body, "Body search"] remoteExec ["FADE_intel_clientAppendIntelDiary", 0];
        };
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
        ["_destTaskId", ""],
        ["_objectivePositions", []],
        ["_trackUnit", objNull]
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
    private _positions = [];
    {
        private _p = [_x] call FADE_fieldIntel_normalisePos;
        if (count _p >= 2) then { _positions pushBack _p };
    } forEach _objectivePositions;
    if (_positions isEqualTo []) then {
        private _p = [_truePos] call FADE_fieldIntel_normalisePos;
        if (count _p >= 2) then { _positions = [_p] };
    };
    private _track = if (isNull _trackUnit) then { objNull } else { _trackUnit };
    private _state = [
        _taskId,
        _missionType,
        +_truePos,
        +_markerPos,
        _positions,
        _mode,
        _icon,
        _zoneKey,
        +_gridNames,
        _radius,
        0,
        0,
        _markerColor,
        _destTaskId,
        _track,
        +_markerPos,
        [_radius, _radius]
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
