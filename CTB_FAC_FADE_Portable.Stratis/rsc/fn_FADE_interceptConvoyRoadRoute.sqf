/*
    Server-only: one convoy road path for Intercept Convoy.
    Map click (start + end): one nearRoads snap at each click (500 m), then one road walk.
    Random, or a start click with no end: up to 12 civ-zone snaps, then at most 4 walks,
    shortest straight-line pair first.
    Returns [] or an ordered path of positions (first = start, last = end).
    Params: [_basePos, _minRouteM optional (-1 = scaled), _mapStartAnchor optional, _resolvedRadius ignored,
             _mapEndAnchor optional]
*/

FADE_convoyEffectiveMinM = {
    params [["_mapClick", false]];
    private _cap = missionNamespace getVariable ["FADE_convoyMinRouteM", 5000];
    private _floor = missionNamespace getVariable ["FADE_convoyRouteFloorM", 1200];
    private _floorUse = _floor min _cap;
    if (_mapClick) exitWith { _floorUse };
    private _mapMinX = missionNamespace getVariable ["FADE_mapMinX", missionNamespace getVariable ["FADE_mapMin", 0]];
    private _mapMaxX = missionNamespace getVariable ["FADE_mapMaxX", missionNamespace getVariable ["FADE_mapMax", worldSize]];
    private _mapMinY = missionNamespace getVariable ["FADE_mapMinY", missionNamespace getVariable ["FADE_mapMin", 0]];
    private _mapMaxY = missionNamespace getVariable ["FADE_mapMaxY", missionNamespace getVariable ["FADE_mapMax", worldSize]];
    private _span = (_mapMaxX - _mapMinX) min (_mapMaxY - _mapMinY);
    ((_span * 0.35) max _floorUse) min _cap
};

FADE_interceptConvoyRoadRoute = {
    params [["_basePos", [0, 0, 0]], ["_minRouteM", -1], ["_mapAnchor", []], ["_resolvedRadius", -1], ["_mapEndAnchor", []]];
    if (isNil "FADE_interceptConvoyRouteWaypoints") exitWith { [] };
    private _minFromBase = FADE_minDistFromBase;
    private _useAnchor = [_mapAnchor] call FADE_fnc_isValidMapClickPos;
    private _useEndAnchor = [_mapEndAnchor] call FADE_fnc_isValidMapClickPos;
    private _randomMin = if (_minRouteM >= 0) then { _minRouteM } else { [false] call FADE_convoyEffectiveMinM };
    private _clickMin = if (_minRouteM >= 0) then { _minRouteM } else { [true] call FADE_convoyEffectiveMinM };

    private _nearestRoad = {
        params ["_anchor"];
        private _roads = _anchor nearRoads 500;
        private _best = objNull;
        private _bestD = 1e15;
        private _p = [0, 0, 0];
        private _d = 0;
        {
            _p = getPosATL _x;
            if (count _p < 3) then { _p = [(_p select 0), (_p select 1), 0] };
            if (!surfaceIsWater _p && { (_p distance2D _basePos) >= _minFromBase }) then {
                _d = _p distance2D _anchor;
                if (_d < _bestD) then {
                    _bestD = _d;
                    _best = _x;
                };
            };
        } forEach _roads;
        if (isNull _best) exitWith { [] };
        private _out = getPosATL _best;
        if (count _out < 3) then { _out = [(_out select 0), (_out select 1), 0] };
        _out
    };

    private _acceptPath = {
        params ["_path", "_needM"];
        if (!(_path isEqualType []) || { count _path < 2 }) exitWith { [] };
        private _a = _path select 0;
        private _b = _path select ((count _path) - 1);
        if (_a distance2D _b < _needM) exitWith { [] };
        _path
    };

    if (_useAnchor && { _useEndAnchor }) exitWith {
        private _sp = [_mapAnchor] call _nearestRoad;
        private _ep = [_mapEndAnchor] call _nearestRoad;
        if (_sp isEqualTo [] || { _ep isEqualTo [] }) exitWith { [] };
        if (_sp distance2D _ep < _clickMin) exitWith { [] };
        private _path = [_sp, _ep] call FADE_interceptConvoyRouteWaypoints;
        [_path, _clickMin] call _acceptPath
    };

    private _zoneNames = missionNamespace getVariable ["FADE_civTriggerNames", []];
    private _cands = [];
    private _zi = 0;
    private _tr = objNull;
    private _zc = [];
    private _snapped = [];
    while { _zi < count _zoneNames && { count _cands < 12 } } do {
        _tr = missionNamespace getVariable [_zoneNames select _zi, objNull];
        _zi = _zi + 1;
        if (isNull _tr) then { continue };
        _zc = getPosATL _tr;
        if (count _zc < 2) then { continue };
        _snapped = [_zc] call _nearestRoad;
        if (_snapped isEqualTo []) then { continue };
        _cands pushBack _snapped;
    };

    private _fixedStart = [];
    if (_useAnchor) then {
        _fixedStart = [_mapAnchor] call _nearestRoad;
    };
    if (_useAnchor && { _fixedStart isEqualTo [] }) exitWith { [] };

    private _pairs = [];
    private _ai = 0;
    private _bi = 0;
    private _spair = [];
    private _epair = [];
    private _pairD = 0;
    if (count _fixedStart >= 2) then {
        {
            _epair = _x;
            _pairD = _fixedStart distance2D _epair;
            if (_pairD >= _randomMin) then { _pairs pushBack [_pairD, _fixedStart, _epair] };
        } forEach _cands;
    } else {
        while { _ai < count _cands } do {
            _spair = _cands select _ai;
            _ai = _ai + 1;
            _bi = _ai;
            while { _bi < count _cands } do {
                _epair = _cands select _bi;
                _bi = _bi + 1;
                _pairD = _spair distance2D _epair;
                if (_pairD >= _randomMin) then { _pairs pushBack [_pairD, _spair, _epair] };
            };
        };
    };
    if (_pairs isEqualTo []) exitWith {
        diag_log format ["[FADE] Convoy route search failed: zones=%1 cands=%2 needM=%3", count _zoneNames, count _cands, round _randomMin];
        []
    };
    _pairs = [_pairs, [], { _x select 0 }, "ASCEND"] call BIS_fnc_sortBy;
    if (isNil "_pairs" || { !(_pairs isEqualType []) }) then { _pairs = [] };

    private _path = [];
    private _attempts = 0;
    private _tryPair = [];
    {
        if (count _path >= 2 || { _attempts >= 4 }) exitWith {};
        _attempts = _attempts + 1;
        _tryPair = _x;
        _path = [(_tryPair select 1), (_tryPair select 2)] call FADE_interceptConvoyRouteWaypoints;
        _path = [_path, _randomMin] call _acceptPath;
    } forEach _pairs;
    if (count _path < 2) then {
        diag_log format [
            "[FADE] Convoy route search failed: zones=%1 cands=%2 pairs=%3 tried=%4 needM=%5",
            count _zoneNames, count _cands, count _pairs, _attempts, round _randomMin
        ];
        _path = [];
    };
    _path
};
