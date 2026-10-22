// =============================================================================
// FADE_AoSurvey.sqf — terrain bucket survey for spawn / waypoint placement (server)
// =============================================================================

if (!isNil "FADE_aoSurvey_installed") exitWith {};
FADE_aoSurvey_installed = true;

FADE_aoSurvey_cacheKey = {
    params ["_center", "_radiusM"];
    private _c = [_center] call FADE_normPos3;
    format ["%1_%2_%3", round (_c select 0), round (_c select 1), round _radiusM]
};

FADE_aoSurvey_build = {
    params ["_center", ["_radiusM", 500]];
    if !(missionNamespace getVariable ["FADE_aoSurveyEnabled", true]) exitWith { createHashMap };
    private _key = [_center, _radiusM] call FADE_aoSurvey_cacheKey;
    private _cached = missionNamespace getVariable ["FADE_aoSurvey_cache_" + _key, objNull];
    if (_cached isEqualType createHashMap) exitWith { +_cached };

    private _c = [_center] call FADE_normPos3;
    private _r = _radiusM max 100;
    private _out = createHashMapFromArray [
        ["center", _c],
        ["radiusM", _r],
        ["roadsNear", []],
        ["roadsFar", []],
        ["groundNear", []],
        ["flatNear", []],
        ["forest", []],
        ["buildings", []]
    ];

    private _roadMax = missionNamespace getVariable ["FADE_aoSurveyRoadSampleMax", 12];
    private _flatMax = missionNamespace getVariable ["FADE_aoSurveyFlatSampleMax", 10];
    private _bldMax = missionNamespace getVariable ["FADE_aoSurveyBuildingSampleMax", 8];

    private _roads = _c nearRoads (_r * 0.45);
    private _roadPos = [];
    {
        if (_x isEqualType objNull && { !isNull _x }) then {
            _roadPos pushBackUnique (getPos _x);
        };
    } forEach (_roads select [0, _roadMax min count _roads]);
    _out set ["roadsNear", _roadPos];

    private _roadsFar = [];
    {
        private _rp = getPos _x;
        if ((_rp distance2D _c) > (_r * 0.35) && { (_rp distance2D _c) < _r }) then {
            _roadsFar pushBackUnique _rp;
        };
    } forEach (_roads select [0, (_roadMax * 2) min count _roads]);
    _out set ["roadsFar", _roadsFar select [0, _roadMax min count _roadsFar]];

    for "_i" from 1 to _flatMax do {
        private _gp = [[_c, 0, (_r * 0.4), 2, 0, 0.35, 0, [], _c], _c] call FADE_findSafePosArray;
        if (_gp isEqualType [] && { count _gp >= 2 }) then {
            _gp = [(_gp select 0), (_gp select 1), 0];
            private _list = _out getOrDefault ["groundNear", []];
            _list pushBackUnique _gp;
            _out set ["groundNear", _list];
        };
    };

    private _bestFlat = selectBestPlaces [_c, (_r * 0.35), "(2*meadow) - houses - forest - trees - sea", 40, _flatMax];
    {
        private _fp = (_x select 0);
        if (_fp isEqualType [] && { count _fp >= 2 }) then {
            private _flat = _fp isFlatEmpty [6, -1, 0.25, 12, 0, false];
            if (_flat isEqualType [] && { count _flat > 0 }) then {
                private _list = _out getOrDefault ["flatNear", []];
                _list pushBack [(_flat select 0), (_flat select 1), 0];
                _out set ["flatNear", _list];
            };
        };
    } forEach _bestFlat;

    private _bestForest = selectBestPlaces [_c, (_r * 0.5), "forest - houses - sea", 35, _flatMax];
    {
        private _fp = (_x select 0);
        if (_fp isEqualType [] && { count _fp >= 2 }) then {
            private _list = _out getOrDefault ["forest", []];
            _list pushBack [(_fp select 0), (_fp select 1), 0];
            _out set ["forest", _list];
        };
    } forEach _bestForest;

    private _houses = nearestObjects [_c, ["House", "Building"], _r, false];
    {
        private _bp = getPosATL _x;
        if (count _bp >= 2) then {
            private _list = _out getOrDefault ["buildings", []];
            if (count _list < _bldMax) then {
                _list pushBack [(_bp select 0), (_bp select 1), 0];
                _out set ["buildings", _list];
            };
        };
    } forEach _houses;

    missionNamespace setVariable ["FADE_aoSurvey_cache_" + _key, _out];
    +_out
};

FADE_aoSurvey_pick = {
    params ["_survey", "_bucket", ["_fallback", []]];
    if (_survey isEqualType createHashMap) then {
        private _list = _survey getOrDefault [_bucket, []];
        if (_list isEqualType [] && { count _list > 0 }) exitWith { selectRandom _list };
    };
    if (_fallback isEqualType [] && { count _fallback >= 2 }) then { +_fallback } else { [] }
};

FADE_aoSurvey_pickRoadWaypoint = {
    params ["_survey", "_nearPos", ["_fallbackCenter", [0, 0, 0]]];
    private _roads = if (_survey isEqualType createHashMap) then { _survey getOrDefault ["roadsNear", []] } else { [] };
    if (_roads isEqualTo []) exitWith {
        if (count _fallbackCenter >= 2) then { +_fallbackCenter } else { [] }
    };
    private _best = _roads select 0;
    private _bestD = 1e9;
    {
        private _d = _nearPos distance2D _x;
        if (_d < _bestD) then {
            _bestD = _d;
            _best = _x;
        };
    } forEach _roads;
    +_best
};

missionNamespace setVariable ["FADE_aoSurvey_build", FADE_aoSurvey_build];
missionNamespace setVariable ["FADE_aoSurvey_pick", FADE_aoSurvey_pick];
missionNamespace setVariable ["FADE_aoSurvey_pickRoadWaypoint", FADE_aoSurvey_pickRoadWaypoint];
