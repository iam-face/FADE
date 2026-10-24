/*
    Server-only: connected road path between two positions.
    Snaps each end to the nearest road within 80 m, then A* along roadsConnectedTo.
    Stops after 800 expanded segments. Returns [] if the ends do not connect within that cap.
    Long-range nearRoads searches belong in FADE_interceptConvoyRoadRoute, not here.
    Params: [_startPos, _endPos, _ignored]
    Returns ordered [start, ...road points..., end], or [].
*/
params [
    ["_startPos", [0, 0, 0]],
    ["_endPos", [0, 0, 0]],
    ["_ignored", 0]
];
if (count _startPos < 2 || { count _endPos < 2 }) exitWith { [] };
private _start = if (count _startPos < 3) then { [(_startPos select 0), (_startPos select 1), 0] } else { _startPos };
private _end = if (count _endPos < 3) then { [(_endPos select 0), (_endPos select 1), 0] } else { _endPos };
if (_start distance2D _end < 30) exitWith { [] };

private _nearestRoad = {
    params ["_anchor"];
    private _roads = _anchor nearRoads 80;
    private _best = objNull;
    private _bestD = 1e15;
    private _p = [0, 0, 0];
    private _d = 0;
    {
        _p = getPosATL _x;
        if (count _p < 3) then { _p = [(_p select 0), (_p select 1), 0] };
        if (!surfaceIsWater _p) then {
            _d = _p distance2D _anchor;
            if (_d < _bestD) then {
                _bestD = _d;
                _best = _x;
            };
        };
    } forEach _roads;
    _best
};

private _startRoad = [_start] call _nearestRoad;
private _endRoad = [_end] call _nearestRoad;
if (isNull _startRoad || { isNull _endRoad }) exitWith { [] };
if (_startRoad isEqualTo _endRoad) exitWith {
    private _only = getPosATL _startRoad;
    if (count _only < 3) then { _only = [(_only select 0), (_only select 1), 0] };
    [_only, _only]
};

private _cap = 800;
private _endPosRoad = getPosATL _endRoad;
if (count _endPosRoad < 3) then { _endPosRoad = [(_endPosRoad select 0), (_endPosRoad select 1), 0] };
private _gScore = createHashMap;
private _parent = createHashMap;
private _closed = createHashMap;
private _open = [_startRoad];
_gScore set [str _startRoad, 0];
private _visits = 0;
private _found = objNull;
private _bestIdx = 0;
private _bestF = 0;
private _oi = 0;
private _cand = objNull;
private _g = 0;
private _f = 0;
private _cur = objNull;
private _curKey = "";
private _nbrs = [];
private _nbr = objNull;
private _nbrKey = "";
private _step = 0;
private _tentative = 0;

while { count _open > 0 && { _visits < _cap } && { isNull _found } } do {
    _bestIdx = 0;
    _bestF = 1e15;
    for "_oi" from 0 to ((count _open) - 1) do {
        _cand = _open select _oi;
        _g = _gScore getOrDefault [str _cand, 1e15];
        _f = _g + ((getPosATL _cand) distance2D _endPosRoad);
        if (_f < _bestF) then {
            _bestF = _f;
            _bestIdx = _oi;
        };
    };
    _cur = _open deleteAt _bestIdx;
    _curKey = str _cur;
    if !(_curKey in _closed) then {
        _closed set [_curKey, true];
        _visits = _visits + 1;
        if (_cur isEqualTo _endRoad || { (getPosATL _cur) distance2D _endPosRoad < 8 }) then {
            _found = _cur;
        } else {
            _nbrs = roadsConnectedTo _cur;
            {
                _nbr = _x;
                if (!isNull _nbr) then {
                    _nbrKey = str _nbr;
                    if !(_nbrKey in _closed) then {
                        _step = (getPosATL _cur) distance2D (getPosATL _nbr);
                        if (_step < 1) then { _step = 1 };
                        _tentative = (_gScore getOrDefault [_curKey, 1e15]) + _step;
                        if (_tentative < (_gScore getOrDefault [_nbrKey, 1e15])) then {
                            _parent set [_nbrKey, _cur];
                            _gScore set [_nbrKey, _tentative];
                            _open pushBack _nbr;
                        };
                    };
                };
            } forEach _nbrs;
        };
    };
};

if (isNull _found) exitWith {
    if (_visits >= _cap) then {
        diag_log format ["[FADE] Convoy road walk hit cap %1 between %2 and %3", _cap, mapGridPosition _start, mapGridPosition _end];
    };
    []
};

private _chain = [];
private _guard = 0;
private _walk = _found;
while { !isNull _walk && { _guard < (_cap + 2) } } do {
    _chain pushBack _walk;
    _guard = _guard + 1;
    if (_walk isEqualTo _startRoad) then {
        _walk = objNull;
    } else {
        _walk = _parent getOrDefault [str _walk, objNull];
    };
};
if (count _chain < 2 || { !((_chain select ((count _chain) - 1)) isEqualTo _startRoad) }) exitWith { [] };
reverse _chain;
private _pts = [];
private _rp = [0, 0, 0];
{
    _rp = getPosATL _x;
    if (count _rp < 3) then { _rp = [(_rp select 0), (_rp select 1), 0] };
    _pts pushBack _rp;
} forEach _chain;
_pts
