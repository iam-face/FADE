/*
    Server-only helper: find two road positions for Intercept Convoy.
    Returns [] if no valid pair, else [[x,y,z],[x,y,z]] with 2D distance >= _minRouteM.
    Params: [_basePos, _minRouteM optional, _mapAnchor optional, _resolvedRadius optional — prefer routes near map click]
*/
params [["_basePos", [0, 0, 0]], ["_minRouteM", -1], ["_mapAnchor", []], ["_resolvedRadius", -1]];
if (_minRouteM < 0) then {
    _minRouteM = missionNamespace getVariable ["FADE_convoyMinRouteM", if (isNil "FADE_convoyMinRouteM") then { 5000 } else { FADE_convoyMinRouteM }];
};
private _mapMin = missionNamespace getVariable ["FADE_mapMin", 0];
private _mapMax = missionNamespace getVariable ["FADE_mapMax", worldSize];
private _minFromBase = FADE_minDistFromBase;
private _useAnchor = [_mapAnchor] call FADE_fnc_isValidMapClickPos;
private _anchorSearchR = if (_useAnchor) then {
    private _snappedR = missionNamespace getVariable ["FADE_missionMapClickSnappedRadius", -2];
    if (_resolvedRadius == _snappedR || { _resolvedRadius < 0 }) then {
        missionNamespace getVariable ["FADE_missionPlayerAnchorRadiusM", 5000]
    } else {
        _resolvedRadius
    }
} else { 0 };

private _tryRouteFromStart = {
    params ["_sp", "_minRouteM", "_basePos", "_minFromBase", "_mapMin", "_mapMax"];
    private _endPos = [];
    if (count _sp < 3) then { _sp = [(_sp select 0), (_sp select 1), 0] };
    if (surfaceIsWater _sp) exitWith { [] };
    if ((_sp distance2D _basePos) < _minFromBase) exitWith { [] };
    private _dir = random 360;
    private _roughEnd = _sp getPos [(_minRouteM + random 2000), _dir];
    if ((surfaceIsWater _roughEnd) || { (_roughEnd select 0) < _mapMin } || { (_roughEnd select 0) > _mapMax } || { (_roughEnd select 1) < _mapMin } || { (_roughEnd select 1) > _mapMax }) exitWith { [] };
    private _roadsEnd = _roughEnd nearRoads 700;
    if (_roadsEnd isEqualTo []) exitWith { [] };
    private _okEnds = _roadsEnd select {
        private _ep = getPosATL _x;
        if (count _ep < 3) then { _ep = [(_ep select 0), (_ep select 1), 0] };
        if (surfaceIsWater _ep) exitWith { false };
        if ((_ep distance2D _sp) < _minRouteM) exitWith { false };
        if ((_ep distance2D _basePos) < _minFromBase) exitWith { false };
        true
    };
    if (count _okEnds == 0) exitWith { [] };
    private _pick = selectRandom _okEnds;
    _endPos = getPosATL _pick;
    if (count _endPos < 3) then { _endPos = [(_endPos select 0), (_endPos select 1), 0] };
    [_sp, _endPos]
};

private _startPos = [];
private _endPos = [];
private _routeFound = false;

if (_useAnchor) then {
    private _roadsNear = _mapAnchor nearRoads (_anchorSearchR max 500);
    _roadsNear = [_roadsNear, [], { (getPosATL _x) distance2D _mapAnchor }, "ASCEND"] call BIS_fnc_sortBy;
    private _ri = 0;
    while { _ri < (count _roadsNear min 40) && { !_routeFound } } do {
        private _rS = _roadsNear select _ri;
        _ri = _ri + 1;
        private _sp = getPosATL _rS;
        private _pair = [_sp, _minRouteM, _basePos, _minFromBase, _mapMin, _mapMax] call _tryRouteFromStart;
        if (count _pair == 2) then {
            _pair params ["_s", "_e"];
            _startPos = _s;
            _endPos = _e;
            _routeFound = true;
        };
    };
};

for "_attempt" from 1 to 90 do {
    if (_routeFound) exitWith {};
    private _rough = if (_useAnchor && { _attempt <= 30 }) then {
        private _a = random 360;
        private _d = random (_anchorSearchR max 250);
        [(_mapAnchor select 0) + _d * (cos _a), (_mapAnchor select 1) + _d * (sin _a), 0]
    } else {
        [_mapMin + random (_mapMax - _mapMin), _mapMin + random (_mapMax - _mapMin), 0]
    };
    if (surfaceIsWater _rough) then { continue };
    private _roadsStart = _rough nearRoads 500;
    if (_roadsStart isEqualTo []) then { continue };
    private _rS = selectRandom _roadsStart;
    private _sp = getPosATL _rS;
    private _pair = [_sp, _minRouteM, _basePos, _minFromBase, _mapMin, _mapMax] call _tryRouteFromStart;
    if (count _pair == 2) then {
        _pair params ["_s", "_e"];
        _startPos = _s;
        _endPos = _e;
        _routeFound = true;
    };
};

if (!_routeFound || { count _startPos < 2 } || { count _endPos < 2 }) exitWith { [] };
[_startPos, _endPos]
