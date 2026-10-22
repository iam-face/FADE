/*
    Server-only: subdivided convoy route between road-snapped start/end.
    Inserts midpoints (snapped to nearest road) until _totalCount waypoints (default 9).
    Returns ordered [start, ...intermediate..., end]; [] if inputs invalid.
    Params: [_startPos, _endPos, _totalCount optional]
*/
params [
    ["_startPos", [0, 0, 0]],
    ["_endPos", [0, 0, 0]],
    ["_totalCount", 9]
];
if (count _startPos < 2 || { count _endPos < 2 }) exitWith { [] };
private _start = [_startPos] call FADE_normPos3;
private _end = [_endPos] call FADE_normPos3;
if (_start distance2D _end < 50) exitWith { [_start, _end] };
_totalCount = (_totalCount max 2) min 17;

private _snapMidToRoad = {
    params ["_a", "_b"];
    private _mid = [
        ((_a select 0) + (_b select 0)) / 2,
        ((_a select 1) + (_b select 1)) / 2,
        0
    ];
    private _roads = _mid nearRoads 600;
    if (_roads isEqualTo []) exitWith { _mid };
    _roads = [_roads, [], { (getPosATL _x) distance2D _mid }, "ASCEND"] call BIS_fnc_sortBy;
    private _rp = getPosATL (_roads select 0);
    if (count _rp < 3) then { _rp = [(_rp select 0), (_rp select 1), 0] };
    if (surfaceIsWater _rp) then { _mid } else { _rp };
};

private _pts = [_start, _end];
while { count _pts < _totalCount } do {
    private _next = [];
    for "_i" from 0 to ((count _pts) - 2) do {
        private _a = _pts select _i;
        private _b = _pts select (_i + 1);
        _next pushBack _a;
        _next pushBack ([_a, _b] call _snapMidToRoad);
    };
    _next pushBack (_pts select ((count _pts) - 1));
    _pts = _next;
};
_pts
