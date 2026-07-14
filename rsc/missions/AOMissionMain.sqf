// AOMissionMain.sqf - Area of Operations sustain loop
if (!isServer) exitWith {};
FADE_aoMissionMain = {
if (isNil "FADE_aoParams" || { count FADE_aoParams < 7 }) exitWith {};

FADE_aoParams params ["_player", "_destPos", "_taskId", "_basePos", "_friendlyUnits", "_enemyUnits", ["_operationNameUpper", "OPERATION AO"], ["_operationName", "Operation"]];
private _mkrJitter = missionNamespace getVariable ["FADE_jitterMarkerPos", { params [["_p", [0, 0, 0]]]; [_p] call FADE_normPos3 }];

// Always use current scenario faction (config GUI); refetch so BLUFOR/OPFOR match chosen factions
_friendlyUnits = [_friendlyUnits] call FADE_resolveScenarioFriendlyUnits;
if (_friendlyUnits isEqualTo []) then {
    private _ffAo = missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"];
    private _snAo = missionNamespace getVariable ["FADE_scenarioFriendlySideNum", 1];
    _friendlyUnits = [_ffAo, _snAo] call FADE_getUnitsForFaction;
    if (!isNil "FADE_filterUnitsArmed") then { _friendlyUnits = [_friendlyUnits] call FADE_filterUnitsArmed };
};
_enemyUnits = [_enemyUnits] call FADE_resolveScenarioEnemyUnits;

private _sideFriendly = missionNamespace getVariable ["FADE_sideFriendly", west];
private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
private _markerFriendly = missionNamespace getVariable ["FADE_markerColorFriendly", "ColorWEST"];
private _markerEnemy = missionNamespace getVariable ["FADE_markerColorEnemy", "ColorEAST"];

private _scaleOpforCount = missionNamespace getVariable ["FADE_scaleOpforCount", {
    params ["_baseCount", ["_minCount", 1], ["_maxCount", -1]];
    private _base = floor (_baseCount max 0);
    if (_base <= 0) exitWith { 0 };
    private _scaled = _base max _minCount;
    if (_maxCount >= 0 && { _scaled > _maxCount }) then { _scaled = _maxCount };
    _scaled
}];

if (!(_destPos isEqualType []) || { count _destPos < 2 }) then { _destPos = [0, 0, 0] };
_destPos = [(_destPos param [0, 0]), (_destPos param [1, 0]), (_destPos param [2, 0])];
if (!(_basePos isEqualType []) || { count _basePos < 2 }) then {
    private _baseObj = missionNamespace getVariable ["BASE_1", objNull];
    _basePos = if (!isNull _baseObj) then { getPosATL _baseObj } else { [0, 0, 0] };
    if (!(_basePos isEqualType []) || { count _basePos < 2 }) then { _basePos = [0, 0, 0] };
};
_basePos = [(_basePos param [0, 0]), (_basePos param [1, 0]), (_basePos param [2, 0])];

private _minDistFromBase = 2500;  // AO must never overlap or touch player base
private _dryFn = missionNamespace getVariable ["FADE_surfaceIsDry", { params ["_p"]; count _p >= 2 && { !surfaceIsWater [_p select 0, _p select 1] } }];

// Find dry ground near _anchor (objectives / spawns must not be over water).
private _fnc_findLandPos = {
    params ["_anchor", ["_minDist", 25], ["_maxDist", 250], ["_maxAttempts", 35]];
    if (!(_anchor isEqualType []) || { count _anchor < 2 }) exitWith { [] };
    if ([_anchor] call _dryFn) exitWith {
        private _out = +_anchor;
        if (count _out < 3) then { _out set [2, 0] };
        _out
    };
    private _result = [];
    for "_a" from 0 to (_maxAttempts - 1) do {
        private _dist = if (_maxDist > _minDist) then { _minDist + random (_maxDist - _minDist) } else { _minDist };
        private _cand = [_anchor, _dist, random 360] call BIS_fnc_relPos;
        _cand = [[_cand, 0, 35, 5, 1, 0.4, 0, [], _cand], _cand] call FADE_findSafePosArray;
        if (_cand isEqualType [] && { count _cand >= 2 } && { [_cand] call _dryFn }) exitWith {
            _result = _cand;
            if (count _result < 3) then { _result set [2, 0] };
        };
    };
    if (count _result >= 2) exitWith { _result };
    private _last = [[_anchor, 0, 150, 8, 1, 0.4, 0, [], _anchor], _anchor] call FADE_findSafePosArray;
    if (_last isEqualType [] && { count _last >= 2 } && { [_last] call _dryFn }) exitWith {
        if (count _last < 3) then { _last set [2, 0] };
        _last
    };
    []
};

// AO center: only use CIV zones at least _minDistFromBase from base; else position from params or findMissionPos(2500)
private _civZones = missionNamespace getVariable ["FADE_civTriggerNames", []];
private _farCivZones = _civZones select {
    private _trig = missionNamespace getVariable [_x, objNull];
    if (isNull _trig) then { false } else {
        private _p = getPosATL _trig;
        if (count _p < 2) then { false } else { (_p distance _basePos) >= _minDistFromBase }
    };
};
private _fromMapClick = missionNamespace getVariable ["FADE_missionRun_fromMapClick", false];
private _mapAnchorAo = missionNamespace getVariable ["FADE_missionRun_mapAnchor", []];
if (_fromMapClick && { [_mapAnchorAo] call FADE_fnc_isValidMapClickPos }) then {
    _destPos = +_mapAnchorAo;
    if (count _destPos < 3) then { _destPos set [2, 0] };
    if !([_destPos] call _dryFn) then {
        private _land = [[_destPos, 0, 80, 5, 1, 0.5, 0, [], _destPos], _destPos] call FADE_findSafePosArray;
        if (_land isEqualType [] && { count _land >= 2 } && { [_land] call _dryFn }) then {
            _destPos = [(_land select 0), (_land select 1), (_land param [2, 0])];
        };
    };
} else {
    if (!_fromMapClick && { count _farCivZones > 0 }) then {
        private _zoneName = selectRandom _farCivZones;
        private _trig = missionNamespace getVariable [_zoneName, objNull];
        if (!isNull _trig) then {
            private _p = getPosATL _trig;
            if (_p isEqualType [] && { count _p >= 2 }) then { _destPos = [(_p param [0, 0]), (_p param [1, 0]), (_p param [2, 0])] };
        };
    };
};
if ((_destPos distance _basePos) < _minDistFromBase) then {
    private _fallback = [_minDistFromBase] call FADE_findMissionPos;
    if (_fallback isEqualType [] && { count _fallback >= 2 }) then { _destPos = _fallback; if (count _destPos < 3) then { _destPos set [2, 0] } };
};
// Civ zone centres can be over water (e.g. gulf triggers); anchor AO on dry ground nearby.
if !([_destPos] call _dryFn) then {
    private _landMax = if (_fromMapClick) then { 80 } else { 2500 };
    private _land = [[_destPos, 0, _landMax, 10, 1, 0.5, 0, [], _destPos], _destPos] call FADE_findSafePosArray;
    if (_land isEqualType [] && { count _land >= 2 } && { [_land] call _dryFn }) then {
        _destPos = [(_land select 0), (_land select 1), (_land param [2, 0])];
    } else {
        private _zones = +_farCivZones;
        if (count _zones > 1) then { _zones call BIS_fnc_arrayShuffle };
        {
            private _trig = missionNamespace getVariable [_x, objNull];
            if (isNull _trig) then { continue };
            private _zc = getPosATL _trig;
            private _lc = [[_zc, 100, 2000, 10, 1, 0.5, 0, [], _zc], _zc] call FADE_findSafePosArray;
            if (
                _lc isEqualType [] && { count _lc >= 2 } && { [_lc] call _dryFn }
                && { (_lc distance _basePos) >= _minDistFromBase }
            ) exitWith {
                _destPos = [(_lc select 0), (_lc select 1), (_lc param [2, 0])];
            };
        } forEach _zones;
    };
};
if !([_destPos] call _dryFn) then {
    private _landFbMax = if (_fromMapClick) then { 120 } else { 3500 };
    private _landFb = [[_destPos, 0, _landFbMax, 12, 1, 0.5, 0, [], _destPos], _destPos] call FADE_findSafePosArray;
    if (_landFb isEqualType [] && { count _landFb >= 2 } && { [_landFb] call _dryFn }) then {
        _destPos = [(_landFb select 0), (_landFb select 1), (_landFb param [2, 0])];
    };
};
if ((_destPos distance _basePos) < _minDistFromBase) exitWith {
    [_player, _taskId] call FADE_clearActiveMission;
    [_player, "AO ERROR", format ["No area of operations found at least %1 m from base. Try again.", _minDistFromBase], "#FF6666"] call FADE_missionOutcomeHint;
};
if !([_destPos] call _dryFn) exitWith {
    [_player, _taskId] call FADE_clearActiveMission;
    [_player, "AO ERROR", "Could not anchor the AO on dry land (area was over water). Try again.", "#FF6666"] call FADE_missionOutcomeHint;
};

// 2 km x 2 km square AO; BLUFOR spawn on one edge, assault along depth axis
private _zoneHalfWidth = 1000;   // half-size each axis = 2 km x 2 km square
private _zoneHalfDepth = 1000;
private _captureRadius = 50;
private _attackDir = (floor random 4) * 90;  // Random cardinal: 0=E, 90=S, 180=W, 270=N - BLUFOR spawn on this edge, attack toward opposite

// Task: side-visible so all players can join the AO with the same SMEAC task details.
private _taskBuilderAo = missionNamespace getVariable ["FADE_buildMissionTaskSmeacText", {}];
private _friendlyPlayerCountAo = [_sideFriendly] call (missionNamespace getVariable ["FADE_countFriendlyPlayers", { 0 }]);
private _acreSummaryAo = [] call (missionNamespace getVariable ["FADE_getAcreChannelSummary", { "ACRE channel names unavailable" }]);
private _actualOpforCountAo = [_sideEnemy] call FADE_getEnemyMenCount;
private _opforBaselineAo = if (_actualOpforCountAo > 0) then { _actualOpforCountAo } else { 30 };
private _opforCountFactorAo = if (random 1 < 0.5) then { 0.8 } else { 1.2 };
private _estimatedOpforCountAo = (round (_opforBaselineAo * _opforCountFactorAo)) max 0;
private _topoAo = [_destPos] call (missionNamespace getVariable ["FADE_getTopographySummary", { ["UNKNOWN", "Unknown area"] }]);
private _topoGridAo = _topoAo param [0, "UNKNOWN"];
private _topoAreaAo = _topoAo param [1, "Unknown area"];
private _enemyFactionClassAo = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
private _enemyFactionNameAo = getText (configFile >> "CfgFactionClasses" >> _enemyFactionClassAo >> "displayName");
if (_enemyFactionNameAo == "") then { _enemyFactionNameAo = _enemyFactionClassAo };
private _friendlyFactionClassAo = missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"];
private _friendlyFactionNameAo = getText (configFile >> "CfgFactionClasses" >> _friendlyFactionClassAo >> "displayName");
if (_friendlyFactionNameAo == "") then { _friendlyFactionNameAo = _friendlyFactionClassAo };
private _intelFormatterAo = missionNamespace getVariable ["FADE_formatSituationIntelHtml", {}];
private _operationNameAo = _operationName;
if (!isNil "FADE_lore_generate") then {
    private _loreAo = ["AreaOfOperations", _destPos, _operationNameAo] call FADE_lore_generate;
    if (_loreAo isEqualType [] && { count _loreAo >= 3 }) then {
        missionNamespace setVariable ["FADE_missionRun_loreSmeacHtml", _loreAo select 2];
        missionNamespace setVariable ["FADE_missionRun_loreShort", _loreAo select 0];
        missionNamespace setVariable ["FADE_missionRun_loreLong", _loreAo select 1];
    };
};
private _situationIntelAo = if (_intelFormatterAo isEqualTo {}) then {
    format [
        "<t align='left' color='#B0B0B0'>Topography: Grid %1 | Area: %2</t><br/><t align='left' color='#B0B0B0'>Enemy: %3 | Strength: ~%4 personnel (estimated).</t>",
        _topoGridAo,
        _topoAreaAo,
        _enemyFactionNameAo,
        _estimatedOpforCountAo
    ]
} else {
    [
        "AreaOfOperations",
        _destPos,
        _sideEnemy,
        _sideFriendly,
        _estimatedOpforCountAo,
        _opforCountFactorAo,
        _enemyFactionNameAo,
        _friendlyFactionNameAo,
        _friendlyPlayerCountAo,
        _topoGridAo,
        _topoAreaAo
    ] call _intelFormatterAo
};
private _loreAppendFn = missionNamespace getVariable ["FADE_lore_appendSituationHtml", { params ["_s"]; _this select 0 }];
_situationIntelAo = [_situationIntelAo] call _loreAppendFn;
private _situationIntelAoHint = if (_intelFormatterAo isEqualTo {}) then {
    format [
        "<t align='left' color='#FFFFFF'>Topography: Grid %1 | Area: %2</t><br/><t align='left' color='#FFFFFF'>Enemy: %3 | Strength: ~%4 personnel (estimated).</t>",
        _topoGridAo,
        _topoAreaAo,
        _enemyFactionNameAo,
        _estimatedOpforCountAo
    ]
} else {
    [
        "AreaOfOperations",
        _destPos,
        _sideEnemy,
        _sideFriendly,
        _estimatedOpforCountAo,
        _opforCountFactorAo,
        _enemyFactionNameAo,
        _friendlyFactionNameAo,
        _friendlyPlayerCountAo,
        _topoGridAo,
        _topoAreaAo,
        "#FFFFFF"
    ] call _intelFormatterAo
};
private _defaultAdminAo = missionNamespace getVariable ["FADE_missionRun_defaultAdminTaskText", ""];
private _defaultCommandAo = missionNamespace getVariable ["FADE_missionRun_defaultCommandTaskText", ""];
private _zeroAlphaNameAo = [] call (missionNamespace getVariable ["FADE_getZeroAlphaDisplayName", { "UNASSIGNED" }]);
private _taskDescAo = if (_taskBuilderAo isEqualTo {}) then {
    "Capture all 3 objective points (OBJ 1 -> OBJ 2 -> OBJ 3 in order)."
} else {
    [
        format ["AO objective belt at Grid %1 (%2). Capture OBJ 1 -> OBJ 2 -> OBJ 3 in sequence.", mapGridPosition _destPos, _topoAreaAo],
        _destPos,
        _situationIntelAo,
        "Insert from AO edge, clear objective depth in order, and hold each objective until secured.",
        _defaultAdminAo,
        _defaultCommandAo
    ] call _taskBuilderAo
};
[_sideFriendly, _taskId, [_taskDescAo, "AO: Capture objectives", ""], _destPos, "CREATED", 1, true, "attack", true] call BIS_fnc_taskCreate;
private _hqBoardFnAo = missionNamespace getVariable ["FADE_hqMainBoard_setObjectiveBrief", {}];
if (_hqBoardFnAo isEqualType {} && { !(_hqBoardFnAo isEqualTo {}) }) then { [_destPos] call _hqBoardFnAo };

// Zone marker: 2 km x 2 km square; BLUFOR spawn 100 m outside edge in _attackDir. Hollow border only (no fill).
// Rectangle stays on true AO center; point/icon markers use jitter so labels are not exactly on objectives.
private _zoneName = "FADE_ao_zone_" + _taskId;
private _zone = [_zoneName, _destPos, _taskId] call FADE_createRegisteredMarker;
_zone setMarkerShape "RECTANGLE";
_zone setMarkerSize [_zoneHalfDepth, _zoneHalfWidth];
_zone setMarkerDir _attackDir;
_zone setMarkerBrush "Border";
_zone setMarkerColor "ColorBlack";
_zone setMarkerAlpha 0.95;
if (!isNull _player) then {
    _player setVariable ["FADE_myMissionMarker", _zoneName, true];
    _player setVariable ["FADE_myMissionMarkerEnd", "", true];
};

// Three objectives spread inside the square: OBJ 1 closest to BLUFOR (500 m in), OBJ 2 center, OBJ 3 toward OPFOR edge.
// BLUFOR spawn 100 m outside edge so they do not sit on OBJ 1; assault order OBJ 1 -> OBJ 2 -> OBJ 3.
private _points = [];
private _aoObjPlacementFailed = false;
private _objSpecs = [
    [500, _attackDir],                      // OBJ 1: 500 m from center toward BLUFOR edge (first to capture)
    [0, _attackDir],                        // OBJ 2: center
    [500, _attackDir + 180]                 // OBJ 3: 500 m from center toward OPFOR edge
];
{
    if (_aoObjPlacementFailed) exitWith {};
    _x params ["_dist", "_dir"];
    private _pos = [];
    for "_try" from 0 to 29 do {
        private _latOffset = if (_forEachIndex == 1) then { (random 101) - 50 } else { (random 1000) - 500 };
        private _tryPos = if (_dist <= 0) then {
            [_destPos, _latOffset, _attackDir + 90] call BIS_fnc_relPos
        } else {
            private _p = [_destPos, _dist, _dir] call BIS_fnc_relPos;
            [_p, _latOffset, _dir + 90] call BIS_fnc_relPos
        };
        if (_tryPos isEqualType [] && { count _tryPos < 3 }) then { _tryPos set [2, 0] };
        _tryPos = [_tryPos, 25, 120, 5, 1, 0.4, 0, [], _tryPos] call _fnc_findLandPos;
        if (_tryPos isEqualType [] && { count _tryPos >= 2 } && { [_tryPos] call _dryFn }) exitWith { _pos = _tryPos };
    };
    if (count _pos < 2 || { !([_pos] call _dryFn) }) then { _pos = [_destPos, 50, 600] call _fnc_findLandPos };
    if (count _pos < 2 || { !([_pos] call _dryFn) }) then { _pos = [_destPos, 100, 1200] call _fnc_findLandPos };
    // OBJ 3 (OPFOR-side edge): coastal AOs may place the marker offshore — pull inland along assault axis.
    if (_forEachIndex == 2 && { count _pos >= 2 } && { !([_pos] call _dryFn) }) then {
        for "_inland" from 1 to 8 do {
            private _tryIn = [_destPos, 350 + _inland * 80, _attackDir + 180] call BIS_fnc_relPos;
            _tryIn = [[_tryIn, 0, 40, 5, 1, 0.4, 0, [], _tryIn], _tryIn] call FADE_findSafePosArray;
            if (_tryIn isEqualType [] && { count _tryIn >= 2 } && { [_tryIn] call _dryFn }) exitWith { _pos = _tryIn };
        };
    };
    if (count _pos < 2 || { !([_pos] call _dryFn) }) then { _aoObjPlacementFailed = true } else { _points pushBack _pos };
} forEach _objSpecs;
if (_aoObjPlacementFailed || { count _points < 3 }) exitWith {
    [_player, _taskId] call FADE_clearActiveMission;
    [_player, "AO ERROR", "Could not place objectives on dry land. Try again.", "#FF6666"] call FADE_missionOutcomeHint;
};

// Composition at OBJ 1 and OBJ 3 only (Cargo-style: [classname, dist, angle, dirOffset]). OBJ 2 is urban - no composition.
private _aoCompositionObjects = [];
private _objComposition = [
    ["Land_TentA_F", 8, 0, 0],
    ["Land_TentDome_F", 10, 180, 0],
    ["Land_CampingTable_F", 5, 90, 0],
    ["Land_CampingChair_V2_F", 6, 120, 0],
    ["Land_CampingChair_V2_F", 6, 60, 0],
    ["Campfire_burning_F", 4, 270, 0],
    ["Box_NATO_Ammo_F", 12, 45, 0],
    ["Box_NATO_Support_F", 12, 315, 0]
];
{
    private _pos = _x;
    private _objIdx = _forEachIndex;
    if (_objIdx != 1) then {
        private _dir = random 360;
        {
            _x params ["_class", "_dist", "_angle", "_dirObj"];
            if (isClass (configFile >> "CfgVehicles" >> _class)) then {
                private _ang = _angle + _dir;
                private _relPos = [(_pos select 0) + _dist * (cos (_ang)), (_pos select 1) + _dist * (sin (_ang)), (_pos param [2, 0])];
                private _safe = [[_relPos, 0, 2, 0, 1, 0.3, 0, [], _relPos], _relPos] call FADE_findSafePosArray;
                if (_safe isEqualType [] && { count _safe >= 2 }) then {
                    _relPos = [(_safe select 0), (_safe select 1), (_safe param [2, 0])];
                    private _obj = createVehicle [_class, _relPos, [], 0, "NONE"];
                    _obj setDir (_angle + _dir + _dirObj);
                    _obj setPosATL _relPos;
                    if (!surfaceIsWater _relPos) then { _obj setVectorUp surfaceNormal _relPos };
                    _aoCompositionObjects pushBack _obj;
                    [_taskId, _obj] call FADE_aoRegisterObject;
                };
            };
        } forEach _objComposition;
    };
} forEach _points;

private _pointMarkers = [];
{
    private _ptName = "FADE_ao_pt_" + _taskId + str _forEachIndex;
    private _m = [_ptName, [_x, 100] call _mkrJitter, _taskId] call FADE_createRegisteredMarker;
    _m setMarkerType (["unknown"] call FADE_marker_getType);
    _m setMarkerColor _markerEnemy;
    _m setMarkerText format ["OBJ %1", _forEachIndex + 1];
    _m setMarkerAlpha 0.9;
    _pointMarkers pushBack _ptName;
} forEach _points;

// --- Ground infiltrations: edge picks snapped to nearest civ zones on opposite AO halves ---
private _bluEdgeCenter = [_destPos, _zoneHalfDepth + 100, _attackDir] call BIS_fnc_relPos;
private _opforEdgeCenter = [_destPos, _zoneHalfDepth + 100, _attackDir + 180] call BIS_fnc_relPos;
private _latOffset = (random 2001) - 1000;
private _bluInfilRef = [_bluEdgeCenter, _latOffset, _attackDir + 90] call BIS_fnc_relPos;
private _bluRoads = (_bluInfilRef nearRoads 250) select {
    private _rp = getPos _x;
    _rp isEqualType [] && { count _rp >= 2 } && { [_rp] call _dryFn }
};
if (count _bluRoads > 0) then {
    private _roadPos = getPos (selectRandom _bluRoads);
    if (_roadPos isEqualType [] && { count _roadPos >= 2 } && { [_roadPos] call _dryFn }) then {
        _bluInfilRef = [(_roadPos select 0), (_roadPos select 1), (_roadPos param [2, 0])];
    };
};
_bluInfilRef = [_bluInfilRef, 50, 350] call _fnc_findLandPos;
if (!(_bluInfilRef isEqualType []) || { count _bluInfilRef < 2 } || { !([_bluInfilRef] call _dryFn) }) then {
    _bluInfilRef = [_bluEdgeCenter, 50, 600] call _fnc_findLandPos;
};
if (!(_bluInfilRef isEqualType []) || { count _bluInfilRef < 2 } || { !([_bluInfilRef] call _dryFn) }) then {
    _bluInfilRef = [_bluEdgeCenter, 100, 800] call _fnc_findLandPos;
};
if (count _bluInfilRef < 3) then { _bluInfilRef set [2, 0] };

private _opforInfilRef = [_opforEdgeCenter, 50, 500] call _fnc_findLandPos;
if (!(_opforInfilRef isEqualType []) || { count _opforInfilRef < 2 } || { !([_opforInfilRef] call _dryFn) }) then {
    _opforInfilRef = [_opforEdgeCenter, 100, 800] call _fnc_findLandPos;
};
if (!(_opforInfilRef isEqualType []) || { count _opforInfilRef < 2 } || { !([_opforInfilRef] call _dryFn) }) then { _opforInfilRef = +_opforEdgeCenter };
if (count _opforInfilRef < 3) then { _opforInfilRef set [2, 0] };

private _infilResolved = [_destPos, _attackDir, _bluInfilRef, _opforInfilRef, _dryFn, _fnc_findLandPos, _zoneHalfDepth, _zoneHalfWidth, 3000] call FADE_ao_resolveInfilCivZones;
private _bluPack = _infilResolved select 0;
private _opforPack = _infilResolved select 1;
private _infilOppositeOk = if ((count _infilResolved) > 2) then { _infilResolved select 2 } else { false };
private _bluCivZoneId = _bluPack param [0, ""];
private _bluSpawn = _bluPack param [1, +_bluInfilRef];
private _opforCivZoneId = _opforPack param [0, ""];
private _opforSpawnPos = _opforPack param [1, +_opforInfilRef];

if (!(_bluSpawn isEqualType []) || { count _bluSpawn < 2 } || { !([_bluSpawn] call _dryFn) }) exitWith {
    [_player, _taskId] call FADE_clearActiveMission;
    [_player, "AO ERROR", "Could not place BLUFOR infil on dry land. Try again.", "#FF6666"] call FADE_missionOutcomeHint;
};
if (!(_opforSpawnPos isEqualType []) || { count _opforSpawnPos < 2 } || { !([_opforSpawnPos] call _dryFn) }) exitWith {
    [_player, _taskId] call FADE_clearActiveMission;
    [_player, "AO ERROR", "Could not place OPFOR infil on dry land. Try again.", "#FF6666"] call FADE_missionOutcomeHint;
};
if (!_infilOppositeOk) exitWith {
    [_player, _taskId] call FADE_clearActiveMission;
    [_player, "AO ERROR", "Could not place BLUFOR and OPFOR infiltrations on opposite sides of the AO. Try again.", "#FF6666"] call FADE_missionOutcomeHint;
};
if (_bluCivZoneId != "" && { _bluCivZoneId isEqualTo _opforCivZoneId }) exitWith {
    [_player, _taskId] call FADE_clearActiveMission;
    [_player, "AO ERROR", "Could not place BLUFOR and OPFOR infiltrations in separate civ zones. Try again.", "#FF6666"] call FADE_missionOutcomeHint;
};

missionNamespace setVariable ["FADE_aoBluInfilPos_" + _taskId, +_bluSpawn];
missionNamespace setVariable ["FADE_aoBluInfilCivZone_" + _taskId, _bluCivZoneId];
missionNamespace setVariable ["FADE_aoOpforSpawnPos_" + _taskId, +_opforSpawnPos];
missionNamespace setVariable ["FADE_aoOpforInfilCivZone_" + _taskId, _opforCivZoneId];

private _opforReinfMarkerName = "FADE_ao_opforReinf_" + _taskId;
private _opforReinfM = [_opforReinfMarkerName, [_opforSpawnPos, 100] call _mkrJitter, _taskId] call FADE_createRegisteredMarker;
_opforReinfM setMarkerType "mil_warning";
_opforReinfM setMarkerColor _markerEnemy;
_opforReinfM setMarkerText "Expected OPFOR Reinforcements";
_opforReinfM setMarkerAlpha 0.85;

private _bluSpawnMarkerName = "FADE_ao_bluSpawn_" + _taskId;
private _bluSpawnM = [_bluSpawnMarkerName, [_bluSpawn, 100] call _mkrJitter, _taskId] call FADE_createRegisteredMarker;
_bluSpawnM setMarkerType "b_inf";
_bluSpawnM setMarkerText "BLUFOR Ground Infil";
missionNamespace setVariable ["FADE_aoMarkers_" + _taskId, [_zoneName, _opforReinfMarkerName, _bluSpawnMarkerName] + _pointMarkers];

private _startTime = time;
private _timeout = 60 * 60;

// Brief and hint
private _grid = mapGridPosition _destPos;
private _briefGuiTail = toString [10] + toString [10] + "See your Tasks panel and map markers for objectives, routes, and completion criteria.";
private _brief = format ["AREA OF OPERATIONS%1%1Battlespace anchor (approx.): Grid %2%1%1Large-sector fight with successive objectives  -  assault order and OPFOR layout on task.", toString [10], _grid] + _briefGuiTail;
_player setVariable ["FADE_myMissionBrief", _brief, true];
private _starterName = if (isNull _player) then { "Unknown" } else { name _player };
[_operationNameUpper, _starterName] remoteExec ["FADE_showMissionAssignedIntro", 0];
[_player, "Area of Operations"] call FADE_notifyOthersMissionStarted;

// OPFOR: strength from Scenario GUI (Low / Mid / High). Per objective: guard group(s), patrol groups, static turrets (Mid+, not in vehicle cap), OBJ2 movable vehicles.
private _aoStrength = missionNamespace getVariable ["FADE_aoStrength", "Medium"];
if (_aoStrength == "Mid") then { _aoStrength = "Medium" };
private _enemyFaction = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
private _opforGroups = [];
missionNamespace setVariable ["FADE_aoVehicles_" + _taskId, []];
missionNamespace setVariable ["FADE_aoEnded_" + _taskId, false];
private _enemyCount = (count _enemyUnits) max 1;
// Static turret class: faction-aware via FADE_aaa_getStaticLightClass (EnemyAAA.sqf). Empty string
// means no suitable static  -  turret spawn block (line ~585) is gated on isClass so spawn is skipped.
private _turretClass = "";
if (!isNil "FADE_aaa_getStaticLightClass") then { _turretClass = [_enemyFaction] call FADE_aaa_getStaticLightClass };
// Faction-correct vehicles: FADE_getEnemyVehiclesForFaction first, then the resolved missionNamespace
// list (FADE_enemyVehicles is built by FADE_applyScenarioSettings using the same lookup).
// Do NOT hardcode CSAT/vanilla fallbacks here  -  that would defeat the chosen OPFOR faction.
private _enemyVehicles = [_enemyFaction] call (missionNamespace getVariable ["FADE_getEnemyVehiclesForFaction", { [] }]);
if (_enemyVehicles isEqualTo []) then { _enemyVehicles = +(missionNamespace getVariable ["FADE_enemyVehicles", []]) };
// Movable OPFOR only (reinsertion / reinforcement); static turrets are spawned separately and do not count toward cap.
private _fnc_isAoMovableVehicle = {
    params ["_class"];
    if (!isClass (configFile >> "CfgVehicles" >> _class)) exitWith { false };
    if (_class == _turretClass) exitWith { false };
    if (_class isKindOf "StaticWeapon" || { _class isKindOf "Static" }) exitWith { false };
    if (!(_class isKindOf "Tank" || { _class isKindOf "Car" } || { _class isKindOf "Ship" })) exitWith { false };
    private _maxSpeed = getNumber (configFile >> "CfgVehicles" >> _class >> "maxSpeed");
    _maxSpeed > 0
};
private _aoMobileVehicles = _enemyVehicles select { [_x] call _fnc_isAoMovableVehicle };
// _aoMobileVehicles may be empty when the chosen OPFOR faction has no movable land vehicles  - 
// _fnc_spawnAoOpforVehicle exits early on count==0, and the OBJ2 vehicle block is gated on count>0.

private _fnc_aliveAoVehicles = {
    params ["_tid"];
    private _n = 0;
    { if (!isNull _x && { alive _x }) then { _n = _n + 1 } } forEach (missionNamespace getVariable ["FADE_aoVehicles_" + _tid, []]);
    _n
};

// Spawn OPFOR vehicle on the nearest clear road near _anchorPos; crew holds at _holdPos. Returns [veh, crewGrp] or [].
private _fnc_spawnAoOpforVehicle = {
    params ["_tid", "_anchorPos", "_holdPos", ["_vehClass", ""], ["_facePos", []], ["_roadCandidates", []]];
    if (count _aoMobileVehicles == 0) exitWith { [] };
    if !([_tid, _startTime, _timeout] call FADE_aoMissionActive) exitWith { [] };
    if ([_tid] call _fnc_aliveAoVehicles >= 3) exitWith { [] };
    if (_vehClass == "") then { _vehClass = selectRandom _aoMobileVehicles };
    if (!([_vehClass] call _fnc_isAoMovableVehicle)) exitWith { [] };
    private _face = if (count _facePos >= 2) then { _facePos } else { _holdPos };
    private _existingAoVehs = missionNamespace getVariable ["FADE_aoVehicles_" + _tid, []];
    private _roadSpawnFn = missionNamespace getVariable ["FADE_findOpforGroundVehicleRoadSpawn", { [] }];
    private _useRoadPool = _roadCandidates isEqualType [] && { count _roadCandidates > 0 };
    private _roadHit = [];
    private _roadCand = [];
    private _poolIdx = 0;
    private _poolCount = 0;
    if (_useRoadPool) then {
        private _pool = _roadCandidates call BIS_fnc_arrayShuffle;
        _poolCount = count _pool;
        while { _poolIdx < _poolCount && { count _roadHit < 2 } } do {
            _roadCand = [getPos (_pool select _poolIdx), 150, _existingAoVehs, -1, [], _face] call _roadSpawnFn;
            if (_roadCand isEqualType [] && { count _roadCand >= 2 }) then { _roadHit = _roadCand };
            _poolIdx = _poolIdx + 1;
        };
    } else {
        _roadHit = [_anchorPos, 250, _existingAoVehs, -1, [], _face] call _roadSpawnFn;
    };
    if (!(_roadHit isEqualType []) || { count _roadHit < 2 }) exitWith { [] };
    _roadHit params ["_vehPos", "_vehDir"];
    private _veh = createVehicle [_vehClass, _vehPos, [], 0, "NONE"];
    if (isNull _veh) exitWith { [] };
    _veh setPosATL _vehPos;
    _veh setDir _vehDir;
    _veh setVectorUp surfaceNormal _vehPos;
    private _crewGrp = createGroup _sideEnemy;
    private _driver = _crewGrp createUnit [(_enemyUnits select 0), _vehPos, [], 0, "NONE"];
    if (isNull _driver) then {
        deleteVehicle _veh;
        deleteGroup _crewGrp;
    } else {
        _driver assignAsDriver _veh;
        _driver moveInDriver _veh;
        if (_enemyCount > 1) then {
            private _gunner = _crewGrp createUnit [(_enemyUnits select 1), _vehPos, [], 0, "NONE"];
            if (!isNull _gunner) then {
                _gunner assignAsGunner _veh;
                _gunner moveInGunner _veh;
            };
        };
        [_veh, _enemyUnits] call FADE_ensureEnemyVehicleGunner;
        [_crewGrp] call (missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}]);
        _crewGrp setBehaviour "COMBAT";
        _crewGrp setCombatMode "RED";
        private _wp = _crewGrp addWaypoint [_holdPos, 0];
        _wp setWaypointType "HOLD";
        private _vList = missionNamespace getVariable ["FADE_aoVehicles_" + _tid, []];
        _vList pushBack _veh;
        missionNamespace setVariable ["FADE_aoVehicles_" + _tid, _vList];
        [_tid, _veh] call FADE_aoRegisterVehicle;
        [_tid, _crewGrp] call FADE_aoRegisterGroup;
        [_veh, _crewGrp]
    };
};

missionNamespace setVariable ["FADE_aoSpawnVehFn_" + _taskId, _fnc_spawnAoOpforVehicle];

private _tryAmbientAnim = missionNamespace getVariable ["FADE_tryAmbientCombatAnim", {}];

private _fnc_snapAoObjDry = {
    params ["_pos", ["_pullToward", _destPos], ["_preferDir", _attackDir + 180]];
    private _out = +_pos;
    if ([_out] call _dryFn) exitWith { _out };
    for "_t" from 1 to 12 do {
        private _tryIn = [_pullToward, 180 + _t * 70, _preferDir] call BIS_fnc_relPos;
        _tryIn = [[_tryIn, 0, 40, 5, 1, 0.4, 0, [], _pullToward], _pullToward] call FADE_findSafePosArray;
        if (_tryIn isEqualType [] && { count _tryIn >= 2 } && { [_tryIn] call _dryFn }) exitWith { _out = _tryIn };
    };
    if (!([_out] call _dryFn)) then {
        private _dirIn = _pos getDir _pullToward;
        for "_t" from 1 to 10 do {
            private _tryIn = [_pos, 40 + _t * 35, _dirIn] call BIS_fnc_relPos;
            _tryIn = [[_tryIn, 0, 35, 4, 1, 0.4, 0, [], _pullToward], _pullToward] call FADE_findSafePosArray;
            if (_tryIn isEqualType [] && { count _tryIn >= 2 } && { [_tryIn] call _dryFn }) exitWith { _out = _tryIn };
        };
    };
    if (count _out < 3) then { _out set [2, 0] };
    _out
};

private _fnc_pickAoGuardPos = {
    params ["_objPos", ["_fallbackCenter", _destPos]];
    private _pos = [];
    for "_try" from 1 to 20 do {
        private _cand = [_objPos, 25 + random 85, random 360] call BIS_fnc_relPos;
        _cand = [[_cand, 0, 35, 3, 1, 0.4, 0, [], _objPos], _objPos] call FADE_findSafePosArray;
        if (!(_cand isEqualType []) || { count _cand < 2 }) then { _cand = [_objPos, 40 + random 50, random 360] call BIS_fnc_relPos };
        if (count _cand < 3) then { _cand set [2, 0] };
        if ([_cand] call _dryFn) exitWith { _pos = _cand };
    };
    if (_pos isEqualTo []) then {
        private _dirIn = _objPos getDir _fallbackCenter;
        for "_t" from 1 to 12 do {
            private _cand = [_objPos, 30 + _t * 30, _dirIn] call BIS_fnc_relPos;
            _cand = [[_cand, 0, 30, 3, 1, 0.4, 0, [], _fallbackCenter], _fallbackCenter] call FADE_findSafePosArray;
            if (_cand isEqualType [] && { count _cand >= 2 } && { [_cand] call _dryFn }) exitWith { _pos = _cand };
        };
    };
    _pos
};

private _fnc_createBluSquadNear = {
    params ["_anchor", "_classes"];
    private _pos = [_anchor, random 80, random 360] call BIS_fnc_relPos;
    _pos = [[_pos, 0, 25, 3, 1, 0.4, 0, [], _anchor], _anchor] call FADE_findSafePosArray;
    if (!(_pos isEqualType []) || { count _pos < 2 } || { !([_pos] call _dryFn) }) then { _pos = +_anchor };
    if (count _pos < 3) then { _pos set [2, 0] };
    [_pos, _sideFriendly, _classes] call FADE_missionCreateInfantryGroupAt
};

// BLUFOR first so infiltrators appear while OPFOR objective layout finishes spawning.
private _bluCount = (count _friendlyUnits) max 1;
if (_friendlyUnits isEqualTo []) exitWith {
    [_player, _taskId] call FADE_clearActiveMission;
    [_player, "AO ERROR", "No friendly unit classes available for BLUFOR spawns. Check scenario faction.", "#FF6666"] call FADE_missionOutcomeHint;
};
if (!([_bluSpawn] call _dryFn)) then {
    private _landBlu = [_bluSpawn, 50, 400] call _fnc_findLandPos;
    if (_landBlu isEqualType [] && { count _landBlu >= 2 } && { [_landBlu] call _dryFn }) then { _bluSpawn = _landBlu };
};
private _bluGroups = [];
for "_g" from 0 to (1 + floor random 2) do {
    private _classes = [];
    for "_i" from 0 to (4 + floor random 3) do { _classes pushBack (_friendlyUnits select (_i % _bluCount)) };
    private _grp = [_bluSpawn, _classes] call _fnc_createBluSquadNear;
    if (isNull _grp) then { continue };
    [_grp] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
    [_grp] call FADE_attachNightStrobes;
    _grp setFormation "LINE";
    _grp setBehaviour "AWARE";
    _grp setCombatMode "RED";
    private _objectivesToTake = [_points, _captureRadius, _sideFriendly] call FADE_ao_pointsWithoutFriendlies;
    { _grp addWaypoint [_x, 0] } forEach _objectivesToTake;
    _bluGroups pushBack _grp;
    [_taskId, _grp] call FADE_aoRegisterGroup;
};
// #region agent log
diag_log format [
    "[FAC DbgBrowser 62d308] H10 aoBluSpawn friendlyClasses=%1 bluGroups=%2 bluSpawn=%3 dry=%4",
    count _friendlyUnits, count _bluGroups, _bluSpawn, [_bluSpawn] call _dryFn
];
// #endregion

// BLUFOR assault bearing for turret / vehicle orientation (from snapped infil)
_bluEdgeCenter = +_bluSpawn;

{
    private _objPos = +_x;
    private _objIdx = _forEachIndex;
    if (_objIdx == 2) then { _objPos = [_objPos, _destPos, _attackDir + 180] call _fnc_snapAoObjDry };
  // #region agent log
    diag_log format [
        "[FAC DbgBrowser 62d308] H10 aoObjStart objIdx=%1 pos=%2 dry=%3",
        _objIdx, _objPos, [_objPos] call _dryFn
    ];
    // #endregion

    // Guard group(s) at OBJ - spread positions (40-110 m), ambient combat anim on dry ground only
    private _numGuard = [if (_aoStrength == "High") then { 2 } else { 1 }, 1] call _scaleOpforCount;
    private _guardMin = if (_aoStrength == "Low") then { 3 } else { 6 };
    private _guardMax = if (_aoStrength == "Low") then { 6 } else { 10 };
    private _objGuardsSpawned = 0;
    for "_g" from 0 to (_numGuard - 1) do {
        private _nGuard = [_guardMin + floor random ((_guardMax - _guardMin) + 1), 1] call _scaleOpforCount;
        private _staticGrp = createGroup _sideEnemy;
        for "_i" from 0 to (_nGuard - 1) do {
            private _staticPos = [_objPos, _destPos] call _fnc_pickAoGuardPos;
            if (_staticPos isEqualTo []) then { continue };
            private _cls = _enemyUnits select (_i % _enemyCount);
            private _u = _staticGrp createUnit [_cls, _staticPos, [], 0, "NONE"];
            if (!isNull _u) then {
                _u setPosATL _staticPos;
                _u setUnitPos "UP";
                if (!(_tryAmbientAnim isEqualTo {})) then { [_u] call _tryAmbientAnim };
                _objGuardsSpawned = _objGuardsSpawned + 1;
            };
        };
        if (count units _staticGrp == 0) then {
            deleteGroup _staticGrp;
        } else {
            [_staticGrp] call (missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}]);
            _staticGrp setBehaviour "COMBAT";
            _staticGrp setCombatMode "RED";
            _opforGroups pushBack _staticGrp;
            [_taskId, _staticGrp] call FADE_aoRegisterGroup;
        };
    };
    // #region agent log
    diag_log format [
        "[FAC DbgBrowser 62d308] H10 aoObjGuards objIdx=%1 pos=%2 guardsSpawned=%3 dry=%4",
        _objIdx, _objPos, _objGuardsSpawned, [_objPos] call _dryFn
    ];
    // #endregion

    // Patrol groups - count and size by strength; spawn 250 m from OBJ, waypoints with 100 m per-group dispersion
    private _numPatrol = [switch (_aoStrength) do { case "Low": { 2 }; case "Medium": { 3 }; default { 4 }; }, 1] call _scaleOpforCount;
    private _patrolMin = 4;
    private _patrolMax = 8;
    for "_p" from 0 to (_numPatrol - 1) do {
        private _patrolPos = [_objPos, 250 + random 50, random 360] call BIS_fnc_relPos;
        _patrolPos = [[_patrolPos, 0, 25, 3, 1, 0.4, 0, [], _patrolPos], _patrolPos] call FADE_findSafePosArray;
        if (!(_patrolPos isEqualType []) || { count _patrolPos < 2 }) then { _patrolPos = [_objPos, 250, random 360] call BIS_fnc_relPos };
        private _nPatrol = [_patrolMin + floor random ((_patrolMax - _patrolMin) + 1), 1] call _scaleOpforCount;
        private _patrolClasses = [];
        for "_i" from 0 to (_nPatrol - 1) do { _patrolClasses pushBack (_enemyUnits select (_i % _enemyCount)) };
        private _patrolGrp = [_patrolPos, _sideEnemy, _patrolClasses] call FADE_missionCreateInfantryGroupAt;
        if (!isNull _patrolGrp) then {
            [_patrolGrp] call (missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}]);
            [_patrolGrp, _objPos, 150, 220, 4, random 360, 90] call FADE_missionApplyPatrolCycle;
            _opforGroups pushBack _patrolGrp;
            [_taskId, _patrolGrp] call FADE_aoRegisterGroup;
        };
        sleep 0;
    };

    // Static turrets (Mid and High): 2 per objective; not counted in FADE_aoVehicles_ cap. Face BLUFOR assault axis at spawn, then after 10s hull + doWatch toward nearest friendly
    if (_aoStrength != "Low" && { isClass (configFile >> "CfgVehicles" >> _turretClass) }) then {
        private _turretBaseDir = random 360;
        for "_t" from 0 to 1 do {
            // Keep each objective's pair of turrets dispersed: wider radius and near-opposite bearings.
            private _turretDir = _turretBaseDir + (_t * 180) + ((random 40) - 20);
            private _turretPos = [_objPos, 22 + random 18, _turretDir] call BIS_fnc_relPos;
            _turretPos = [[_turretPos, 0, 12, 2, 1, 0.35, 0, [], _turretPos], _turretPos] call FADE_findSafePosArray;
            if (!(_turretPos isEqualType []) || { count _turretPos < 2 }) then { _turretPos = [_objPos, 28, _turretDir] call BIS_fnc_relPos };
            if (count _turretPos < 3) then { _turretPos set [2, 0] };
            private _turret = createVehicle [_turretClass, _turretPos, [], 0, "NONE"];
            _turret setPosATL _turretPos;
            // #region agent log
            if (missionNamespace getVariable ["FADE_aaa_debug", false]) then {
                diag_log format [
                    "[FAC DbgBrowser 62d308] H22 aoTurretSpawn task=%1 obj=%2 class=%3 typeOf=%4",
                    _taskId, _objIdx, _turretClass, typeOf _turret
                ];
            };
            // #endregion
            // Match EnemyAAA / vanilla statics: hull dir = bearing to target (no arbitrary offset).
            private _faceAssault = (getPosATL _turret) getDir _bluEdgeCenter;
            _turret setDir _faceAssault;
            _aoCompositionObjects pushBack _turret;
            [_taskId, _turret] call FADE_aoRegisterObject;
            private _gunnerClass = _enemyUnits select 0;
            private _grp = createGroup _sideEnemy;
            private _gunner = _grp createUnit [_gunnerClass, _turretPos, [], 0, "NONE"];
            if (!isNull _gunner) then {
                _gunner moveInGunner _turret;
                [_grp] call (missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}]);
                _opforGroups pushBack _grp;
                [_taskId, _grp] call FADE_aoRegisterGroup;
            } else { deleteGroup _grp };
            [(_turret), _taskId] spawn {
                params ["_turret", "_taskId"];
                private _sideFriendly = missionNamespace getVariable ["FADE_sideFriendly", west];
                sleep 10;
                if (!alive _turret || { missionNamespace getVariable ["FADE_aoAborted_" + _taskId, false] }) exitWith {};
                private _blu = (_turret nearEntities ["Man", 2500]) select { side _x == _sideFriendly && { alive _x } };
                if (_blu isEqualTo []) exitWith {};
                private _nearest = objNull;
                private _minDist = 1e10;
                { private _d = _turret distance _x; if (_d < _minDist) then { _minDist = _d; _nearest = _x } } forEach _blu;
                if (isNull _nearest) exitWith {};
                private _pT = getPosATL _turret;
                private _pN = getPosATL _nearest;
                private _dirTo = _pT getDir _pN;
                _turret setDir _dirTo;
                private _gn = gunner _turret;
                if (!isNull _gn && { alive _gn }) then { _gn doWatch _nearest };
            };
        };
    };

    // OBJ 2 (center): several movable defense vehicles at all strengths (in addition to static turrets above).
    // Prefer road placement within 150 m of OBJ 2; vehicles don't need to share a road segment, and
    // _fnc_spawnAoOpforVehicle already prevents clipping into other vehicles/buildings via its safe-pos blacklist.
    if (_objIdx == 1 && { count _aoMobileVehicles > 0 }) then {
        private _obj2Roads = (_objPos nearRoads 150) select {
            private _rp = getPos _x;
            _rp isEqualType [] && { count _rp >= 2 } && { [_rp] call _dryFn }
        };
        private _numVeh = switch (_aoStrength) do {
            case "Low": { 2 };
            case "Medium": { 2 + floor random 2 };
            default { 3 };
        };
        for "_v" from 0 to (_numVeh - 1) do {
            if ([_taskId] call _fnc_aliveAoVehicles >= 3) exitWith {};
            private _bearing = (_v * (360 / (_numVeh max 1))) + random 50;
            private _anchor = [_objPos, 25 + random 20, _bearing] call BIS_fnc_relPos;
            private _spawned = [_taskId, _anchor, _objPos, "", _bluEdgeCenter, _obj2Roads] call _fnc_spawnAoOpforVehicle;
            if (_spawned isEqualType [] && { count _spawned >= 2 }) then {
                _opforGroups pushBack (_spawned select 1);
            };
        };
    };
} forEach _points;
if (!isNil "FADE_registerEnemyRetreat" && { _opforGroups isEqualType [] } && { _basePos isEqualType [] } && { count _basePos >= 2 }) then {
    [_opforGroups, _basePos] call FADE_registerEnemyRetreat;
};
private _opforTargetCount = count _opforGroups;

// Initial entity registry (reinforcement spawns use FADE_aoRegisterGroup)
private _aoAllGroups = _bluGroups + _opforGroups;
missionNamespace setVariable ["FADE_aoEntities_" + _taskId, [_aoAllGroups, _aoCompositionObjects]];

// BLUFOR reinforcements: keep 2-4 BLUFOR squads (groups) active; spawn in a wave at BLUFOR edge every 30-60s when below 2 squads
[_taskId, _bluGroups, _points, _bluSpawn, _friendlyUnits, _bluCount, _captureRadius, _startTime, _timeout] spawn {
    params ["_taskId", "_bluGroups", "_points", "_bluSpawn", "_friendlyUnits", "_bluCount", "_captureRadius", "_startTime", "_timeout"];
    private _sideFriendly = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _bluCountSafe = _bluCount max 1;
    while { [_taskId, _startTime, _timeout] call FADE_aoMissionActive } do {
        sleep (30 + random 30);
        if !([_taskId, _startTime, _timeout] call FADE_aoMissionActive) exitWith {};
        private _squadsWithAlive = 0;
        { if (count (units _x select { alive _x }) > 0) then { _squadsWithAlive = _squadsWithAlive + 1 } } forEach _bluGroups;
        if (_squadsWithAlive < 2 && { count _friendlyUnits > 0 }) then {
            private _targetSquads = 2 + floor random 3;
            private _numToSpawn = ((_targetSquads - _squadsWithAlive) max 1) min 4;
            private _objectivesToTake = [];
            private _objectivesToTake = [_points, _captureRadius, _sideFriendly] call FADE_ao_pointsWithoutFriendlies;
            for "_s" from 0 to (_numToSpawn - 1) do {
                if !([_taskId, _startTime, _timeout] call FADE_aoMissionActive) exitWith {};
                private _squadSize = 4 + floor random 4;
                private _classes = [];
                for "_i" from 0 to (_squadSize - 1) do { _classes pushBack (_friendlyUnits select (_i % _bluCountSafe)) };
                private _grp = [_bluSpawn, _classes] call _fnc_createBluSquadNear;
                if (isNull _grp) then { continue };
                [_grp] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
                [_grp] call FADE_attachNightStrobes;
                _grp setFormation "LINE";
                _grp setBehaviour "AWARE";
                _grp setCombatMode "RED";
                { _grp addWaypoint [_x, 0] } forEach _objectivesToTake;
                _bluGroups pushBack _grp;
                [_taskId, _grp] call FADE_aoRegisterGroup;
            };
        };
    };
};

// OPFOR reinforcements: maintain group count; optional vehicle wave (10%, max 3 alive).
[_taskId, _opforGroups, _points, _destPos, _zoneHalfDepth, _attackDir, _enemyUnits, _aoMobileVehicles, _opforTargetCount, _startTime, _timeout, _captureRadius] spawn {
    params ["_taskId", "_opforGroups", "_points", "_destPos", "_zoneHalfDepth", "_attackDir", "_enemyUnits", "_aoMobileVehicles", "_opforTargetCount", "_startTime", "_timeout", "_captureRadius"];
    private _sideFriendly = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _dryFnLocal = missionNamespace getVariable ["FADE_surfaceIsDry", { params ["_p"]; count _p >= 2 && { !surfaceIsWater [_p select 0, _p select 1] } }];
    private _fnc_findLandPosLocal = {
        params ["_anchor"];
        private _cand = [[_anchor, 25, 120, 5, 1, 0.4, 0, [], _anchor], _anchor] call FADE_findSafePosArray;
        if (_cand isEqualType [] && { count _cand >= 2 } && { [_cand] call _dryFnLocal }) exitWith { _cand };
        [_anchor, 50, 200] call BIS_fnc_relPos
    };
    private _scaleOpforCount = missionNamespace getVariable ["FADE_scaleOpforCount", {
        params ["_baseCount", ["_minCount", 1], ["_maxCount", -1]];
        private _base = floor (_baseCount max 0);
        if (_base <= 0) exitWith { 0 };
        private _scaled = _base max _minCount;
        if (_maxCount >= 0 && { _scaled > _maxCount }) then { _scaled = _maxCount };
        _scaled
    }];
    private _enemyCount = (count _enemyUnits) max 1;
    private _bluEdgeCenter = missionNamespace getVariable ["FADE_aoBluInfilPos_" + _taskId, [_destPos, _zoneHalfDepth + 100, _attackDir] call BIS_fnc_relPos];
    private _spawnVehFn = missionNamespace getVariable ["FADE_aoSpawnVehFn_" + _taskId, {}];
    private _fnc_aliveVeh = {
        private _n = 0;
        { if (!isNull _x && { alive _x }) then { _n = _n + 1 } } forEach (missionNamespace getVariable ["FADE_aoVehicles_" + _taskId, []]);
        _n
    };
    while { [_taskId, _startTime, _timeout] call FADE_aoMissionActive } do {
        sleep (25 + random 25);
        if !([_taskId, _startTime, _timeout] call FADE_aoMissionActive) exitWith {};
        private _squadsWithAlive = 0;
        { if (count (units _x select { alive _x }) > 0) then { _squadsWithAlive = _squadsWithAlive + 1 } } forEach _opforGroups;
        if (_squadsWithAlive < _opforTargetCount && { count _enemyUnits > 0 }) then {
            private _numToSpawn = [((_opforTargetCount - _squadsWithAlive) max 1) min 6, 1] call _scaleOpforCount;
            private _objectivesToReinforce = [_points, _captureRadius, _sideFriendly] call FADE_ao_pointsWithoutFriendlies;
            if (count _objectivesToReinforce > 0) then {
                for "_s" from 0 to (_numToSpawn - 1) do {
                    if !([_taskId, _startTime, _timeout] call FADE_aoMissionActive) exitWith {};
                    private _assignedObj = _objectivesToReinforce select (_s % (count _objectivesToReinforce));
                    private _opforEdge = missionNamespace getVariable ["FADE_aoOpforSpawnPos_" + _taskId, [_destPos, _zoneHalfDepth + 100, _attackDir + 180] call BIS_fnc_relPos];
                    private _spawnPos = [_opforEdge, (random 100) - 50, _attackDir + 90] call BIS_fnc_relPos;
                    _spawnPos = [_spawnPos] call _fnc_findLandPosLocal;
                    private _squadSize = [4 + floor random 4, 1] call _scaleOpforCount;
                    private _classes = [];
                    for "_i" from 0 to (_squadSize - 1) do { _classes pushBack (_enemyUnits select (_i % _enemyCount)) };
                    private _grp = [_spawnPos, _sideEnemy, _classes] call FADE_missionCreateInfantryGroupAt;
                    if (isNull _grp) then { continue };
                    [_grp] call (missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}]);
                    _grp setBehaviour "AWARE";
                    _grp setCombatMode "RED";
                    _grp addWaypoint [_assignedObj, 0];
                    _opforGroups pushBack _grp;
                    [_taskId, _grp] call FADE_aoRegisterGroup;
                };
            };
        };
        if !([_taskId, _startTime, _timeout] call FADE_aoMissionActive) exitWith {};
        if (
            random 1 < 0.1
            && { [] call _fnc_aliveVeh < 3 }
            && { count _aoMobileVehicles > 0 }
            && { !(_spawnVehFn isEqualTo {}) }
        ) then {
            private _objectivesToReinforce = [_points, _captureRadius, _sideFriendly] call FADE_ao_pointsWithoutFriendlies;
            if (count _objectivesToReinforce > 0) then {
                private _holdObj = selectRandom _objectivesToReinforce;
                private _opforEdge = missionNamespace getVariable ["FADE_aoOpforSpawnPos_" + _taskId, [_destPos, _zoneHalfDepth + 100, _attackDir + 180] call BIS_fnc_relPos];
                private _anchor = [_opforEdge, (random 80) - 40, _attackDir + 90] call BIS_fnc_relPos;
                [_taskId, _anchor, _holdObj, "", _bluEdgeCenter] call _spawnVehFn;
            };
        };
    };
};

// Counter-attack: when BLUFOR first captures an objective, 50% chance to spawn a wave from OPFOR edge with waypoint to that objective. Troop level by difficulty.
[_taskId, _opforGroups, _points, _destPos, _zoneHalfDepth, _attackDir, _enemyUnits, _aoStrength, _captureRadius, _startTime, _timeout] spawn {
    params ["_taskId", "_opforGroups", "_points", "_destPos", "_zoneHalfDepth", "_attackDir", "_enemyUnits", "_aoStrength", "_captureRadius", "_startTime", "_timeout"];
    private _sideFriendly = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _dryFnLocal = missionNamespace getVariable ["FADE_surfaceIsDry", { params ["_p"]; count _p >= 2 && { !surfaceIsWater [_p select 0, _p select 1] } }];
    private _fnc_findLandPosLocal = {
        params ["_anchor", "_fallback"];
        private _cand = [[_anchor, 25, 120, 5, 1, 0.4, 0, [], _anchor], _anchor] call FADE_findSafePosArray;
        if (_cand isEqualType [] && { count _cand >= 2 } && { [_cand] call _dryFnLocal }) exitWith { _cand };
        [_fallback, 50, 200] call BIS_fnc_relPos
    };
    private _enemyCount = (count _enemyUnits) max 1;
    private _capturedState = [false, false, false];
    while { [_taskId, _startTime, _timeout] call FADE_aoMissionActive } do {
        sleep 15;
        if !([_taskId, _startTime, _timeout] call FADE_aoMissionActive) exitWith {};
        {
            private _objPos = _x;
            private _idx = _forEachIndex;
            if (_capturedState select _idx) then { continue };
            private _bluIn = (_objPos nearEntities ["Man", _captureRadius]) select { side _x == _sideFriendly && { alive _x } };
            if (count _bluIn == 0) then { continue };
            _capturedState set [_idx, true];
            if (random 1 >= 0.5) then { continue };
            if !([_taskId, _startTime, _timeout] call FADE_aoMissionActive) exitWith {};
            private _numGroups = switch (_aoStrength) do { case "Low": { 1 }; case "Medium": { 1 }; default { 2 }; };
            private _minSize = if (_aoStrength == "Low") then { 3 } else { 6 };
            private _maxSize = if (_aoStrength == "Low") then { 6 } else { 10 };
            private _opforSpawn = missionNamespace getVariable ["FADE_aoOpforSpawnPos_" + _taskId, [_destPos, _zoneHalfDepth + 100, _attackDir + 180] call BIS_fnc_relPos];
            for "_g" from 0 to (_numGroups - 1) do {
                if !([_taskId, _startTime, _timeout] call FADE_aoMissionActive) exitWith {};
                private _spawnPos = [_opforSpawn, (random 80) - 40, _attackDir + 90] call BIS_fnc_relPos;
                _spawnPos = [_spawnPos, _opforSpawn] call _fnc_findLandPosLocal;
                private _squadSize = _minSize + floor random ((_maxSize - _minSize) + 1);
                private _classes = [];
                for "_i" from 0 to (_squadSize - 1) do { _classes pushBack (_enemyUnits select (_i % _enemyCount)) };
                private _grp = [_spawnPos, _sideEnemy, _classes] call FADE_missionCreateInfantryGroupAt;
                if (isNull _grp) then { continue };
                [_grp] call (missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}]);
                _grp setBehaviour "AWARE";
                _grp setCombatMode "RED";
                _grp addWaypoint [_objPos, 0];
                _opforGroups pushBack _grp;
                [_taskId, _grp] call FADE_aoRegisterGroup;
            };
        } forEach _points;
    };
};

// Capture check: all 3 points have at least one alive BLUFOR within _captureRadius
private _fnc_allCaptured = {
    params ["_points", "_captureRadius"];
    private _all = true;
    {
        private _near = (_x nearEntities ["Man", _captureRadius]) select { side _x == _sideFriendly && { alive _x } };
        if (_near isEqualTo []) then { _all = false };
    } forEach _points;
    _all
};

// Run until all captured, timeout (30 min), or mission aborted; update OBJ marker to blue when captured
private _objMarkersBlue = [false, false, false];
waitUntil {
    sleep 5;
    for "_idx" from 0 to (count _points - 1) do {
        if (!(_objMarkersBlue select _idx)) then {
            private _near = ((_points select _idx) nearEntities ["Man", _captureRadius]) select { side _x == _sideFriendly && { alive _x } };
            if (count _near > 0) then {
                private _mk = _pointMarkers select _idx;
                _mk setMarkerColor _markerFriendly;
                _mk setMarkerText format ["OBJ %1 (secured)", _idx + 1];
                _objMarkersBlue set [_idx, true];
            };
        };
    };
    if (missionNamespace getVariable ["FADE_aoAborted_" + _taskId, false]) then { true } else {
        if (time - _startTime > _timeout) then { true } else {
            [_points, _captureRadius] call _fnc_allCaptured
        }
    };
};

// End mission: stop reinforcements, despawn all units immediately
missionNamespace setVariable ["FADE_aoEnded_" + _taskId, true];

if (missionNamespace getVariable ["FADE_aoAborted_" + _taskId, false]) exitWith {
    if !(missionNamespace getVariable [format ["FADE_missionEnt_cleaned_%1", _taskId], false]) then {
        [_taskId, "AreaOfOperations", false] call FADE_cleanupMissionEntities;
    };
    [_taskId, "", _player, 0] call FADE_mission_completeCleanup;
    missionNamespace setVariable ["FADE_aoSpawnVehFn_" + _taskId, nil];
    missionNamespace setVariable ["FADE_aoVehicles_" + _taskId, nil];
};

if (time - _startTime <= _timeout) then {
    [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
    [_player, "AO CAPTURED", "All 3 objectives secured. Mission complete.", "#90EE90"] call FADE_missionOutcomeHint;
} else {
    [_taskId, "FAILED"] call BIS_fnc_taskSetState;
    [_player, "AO TIMEOUT", "60-minute time limit reached. Mission failed.", "#FF6666"] call FADE_missionOutcomeHint;
};

[_taskId, "AreaOfOperations", false] call FADE_cleanupMissionEntities;
missionNamespace setVariable ["FADE_aoSpawnVehFn_" + _taskId, nil];
missionNamespace setVariable ["FADE_aoVehicles_" + _taskId, nil];
[_taskId, "", _player, 0] call FADE_mission_completeCleanup;
missionNamespace setVariable ["FADE_currentMissionType", ""];
missionNamespace setVariable ["FADE_currentMissionPlayer", objNull];
[] call FADE_missionSlots_publish;

};
