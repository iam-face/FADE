/*
    Server-only helper: find two road positions for Intercept Convoy.
    Returns [] if no valid pair, else [[x,y,z],[x,y,z]] with 2D distance >= _minRouteM.
    Params: [_basePos, _minRouteM optional — default from FADE_convoyMinRouteM / missionNamespace]
*/
params [["_basePos", [0, 0, 0]], ["_minRouteM", -1]];
if (_minRouteM < 0) then {
    _minRouteM = missionNamespace getVariable ["FADE_convoyMinRouteM", if (isNil "FADE_convoyMinRouteM") then { 5000 } else { FADE_convoyMinRouteM }];
};
private _mapMin = missionNamespace getVariable ["FADE_mapMin", 0];
private _mapMax = missionNamespace getVariable ["FADE_mapMax", worldSize];
private _minFromBase = FADE_minDistFromBase;
private _startPos = [];
private _endPos = [];
private _routeFound = false;
for "_attempt" from 1 to 90 do {
    if (_routeFound) exitWith {};
    private _sx = _mapMin + random (_mapMax - _mapMin);
    private _sy = _mapMin + random (_mapMax - _mapMin);
    private _rough = [_sx, _sy, 0];
    if (surfaceIsWater _rough) then { continue };
    private _roadsStart = _rough nearRoads 500;
    if (_roadsStart isEqualTo []) then { continue };
    private _rS = selectRandom _roadsStart;
    private _sp = getPosATL _rS;
    if (count _sp < 3) then { _sp = [(_sp select 0), (_sp select 1), 0] };
    if (surfaceIsWater _sp) then { continue };
    if ((_sp distance2D _basePos) < _minFromBase) then { continue };
    private _dir = random 360;
    private _roughEnd = _sp getPos [(_minRouteM + random 2000), _dir];
    if ((surfaceIsWater _roughEnd) || { (_roughEnd select 0) < _mapMin } || { (_roughEnd select 0) > _mapMax } || { (_roughEnd select 1) < _mapMin } || { (_roughEnd select 1) > _mapMax }) then { continue };
    private _roadsEnd = _roughEnd nearRoads 700;
    if (_roadsEnd isEqualTo []) then { continue };
    private _okEnds = _roadsEnd select {
        private _ep = getPosATL _x;
        if (count _ep < 3) then { _ep = [(_ep select 0), (_ep select 1), 0] };
        if (surfaceIsWater _ep) exitWith { false };
        if ((_ep distance2D _sp) < _minRouteM) exitWith { false };
        if ((_ep distance2D _basePos) < _minFromBase) exitWith { false };
        true
    };
    if (count _okEnds > 0) then {
        private _pick = selectRandom _okEnds;
        _endPos = getPosATL _pick;
        if (count _endPos < 3) then { _endPos = [(_endPos select 0), (_endPos select 1), 0] };
        _startPos = _sp;
        _routeFound = true;
    };
};
if (!_routeFound || { count _startPos < 2 } || { count _endPos < 2 }) exitWith { [] };
[_startPos, _endPos]
