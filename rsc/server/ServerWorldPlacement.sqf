// ServerWorldPlacement.sqf - mission position finders and LZ search
// Find mission position in urban areas only (civ zones). Returns [] if no civ zones.
// Params: [["_minDistOverride", -1]]
FADE_findMissionPosUrban = {
    params [["_minDistOverride", -1]];
    private _base = FADE_basePos;
    private _minDist = if (_minDistOverride > 0) then { _minDistOverride } else { FADE_minDistFromBase };
    private _minXY = FADE_mapMin;
    private _maxXY = FADE_mapMax;
    private _civZoneRadius = 2500;
    private _civZones = missionNamespace getVariable ["FADE_civTriggerNames", []];
    if (count _civZones == 0) exitWith { [] };
    private _result = [];
    private _attempt = 0;
    while { _attempt < 25 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        private _zoneName = selectRandom _civZones;
        private _trig = missionNamespace getVariable [_zoneName, objNull];
        if (!isNull _trig) then {
            private _zoneCenter = getPosATL _trig;
            private _candidate = [[_zoneCenter, 100, _civZoneRadius, 5, 1, 0.5, 0, [], _zoneCenter], _zoneCenter] call FADE_findSafePosArray;
            if (count _candidate >= 2 && { !(surfaceIsWater _candidate) } && { (_candidate distance _base) >= _minDist }) then {
                private _sx = _candidate select 0;
                private _sy = _candidate select 1;
                if (_sx >= _minXY && { _sx <= _maxXY } && { _sy >= _minXY } && { _sy <= _maxXY }) then {
                    _result = _candidate;
                };
            };
        };
    };
    _result
};

// Like findMissionPosUrban but keeps position near zone center (50â€“400 m) so we're in the built-up area.
// Use for mission types that need buildings (e.g. Hostage). Params: [["_minDistOverride", -1]]
FADE_findMissionPosUrbanNearCenter = {
    params [["_minDistOverride", -1]];
    private _base = FADE_basePos;
    private _minDist = if (_minDistOverride > 0) then { _minDistOverride } else { FADE_minDistFromBase };
    private _minXY = FADE_mapMin;
    private _maxXY = FADE_mapMax;
    private _civZones = missionNamespace getVariable ["FADE_civTriggerNames", []];
    if (count _civZones == 0) exitWith { [] };
    private _result = [];
    private _attempt = 0;
    while { _attempt < 25 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        private _zoneName = selectRandom _civZones;
        private _trig = missionNamespace getVariable [_zoneName, objNull];
        if (!isNull _trig) then {
            private _zoneCenter = getPosATL _trig;
            private _candidate = [[_zoneCenter, 50, 400, 5, 1, 0.5, 0, [], _zoneCenter], _zoneCenter] call FADE_findSafePosArray;
            if (count _candidate >= 2 && { !(surfaceIsWater _candidate) } && { (_candidate distance _base) >= _minDist }) then {
                private _sx = _candidate select 0;
                private _sy = _candidate select 1;
                if (_sx >= _minXY && { _sx <= _maxXY } && { _sy >= _minXY } && { _sy <= _maxXY }) then {
                    _result = _candidate;
                };
            };
        };
    };
    _result
};

// Find a road position within 200 m of a random civ zone (MissionTestSuite / tooling). Returns [] if none.
FADE_findMissionPosIED = {
    private _civZones = missionNamespace getVariable ["FADE_civTriggerNames", []];
    if (_civZones isEqualTo []) exitWith { [] };
    private _base = FADE_basePos;
    private _minDist = FADE_minDistFromBase;
    private _result = [];
    for "_a" from 0 to 14 do {
        private _trig = missionNamespace getVariable [selectRandom _civZones, objNull];
        if (!isNull _trig) then {
            private _center = getPosATL _trig;
            if (count _center < 2) then { _center = [0,0,0] };
            if (_center distance _base < _minDist) then { continue };
            private _roads = _center nearRoads 200;
            if (_roads isEqualTo []) then { continue };
            private _road = selectRandom _roads;
            private _pos = getPosATL _road;
            if (count _pos >= 2 && { !(surfaceIsWater _pos) } && { _pos distance _base >= _minDist }) then {
                _result = [(_pos select 0), (_pos select 1), (_pos param [2, 0])];
            };
        };
        if (count _result >= 2) exitWith {};
    };
    _result
};
missionNamespace setVariable ["FADE_findMissionPosIED", FADE_findMissionPosIED];

// Asset Retrieval / Mine Clearing: position within _radiusM of a random civ zone center, at least _minDist from base.
// Params: [["_minDistOverride", -1], ["_radiusFromZone", 500]]
FADE_findMissionPosAssetRetrieval = {
    params [["_minDistOverride", -1], ["_radiusFromZone", 500]];
    private _base = FADE_basePos;
    private _minDist = if (_minDistOverride > 0) then { _minDistOverride } else { FADE_minDistFromBase };
    private _minXY = FADE_mapMin;
    private _maxXY = FADE_mapMax;
    private _civZones = missionNamespace getVariable ["FADE_civTriggerNames", []];
    if (count _civZones == 0) exitWith { [] };
    private _result = [];
    private _attempt = 0;
    while { _attempt < 25 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        private _zoneName = selectRandom _civZones;
        private _trig = missionNamespace getVariable [_zoneName, objNull];
        if (!isNull _trig) then {
            private _zoneCenter = getPosATL _trig;
            private _candidate = [[_zoneCenter, 5, _radiusFromZone, 5, 1, 0.5, 0, [], _zoneCenter], _zoneCenter] call FADE_findSafePosArray;
            if (count _candidate >= 2 && { !(surfaceIsWater _candidate) } && { (_candidate distance _base) >= _minDist }) then {
                private _sx = _candidate select 0;
                private _sy = _candidate select 1;
                if (_sx >= _minXY && { _sx <= _maxXY } && { _sy >= _minXY } && { _sy <= _maxXY }) then {
                    _result = _candidate;
                };
            };
        };
    };
    _result
};
missionNamespace setVariable ["FADE_findMissionPosAssetRetrieval", FADE_findMissionPosAssetRetrieval];

// Find a valid mission position: near a civ zone centre, within 2.5km of zone center,
// at least _minDistOverride (or FADE_minDistFromBase) from base, clear ground, not on water.
// Params: [["_minDistOverride", -1]] - if > 0, use instead of FADE_minDistFromBase (e.g. 1000 for enemy missions)
FADE_findMissionPos = {
    params [["_minDistOverride", -1]];
    private _base = FADE_basePos;
    private _minDist = if (_minDistOverride > 0) then { _minDistOverride } else { FADE_minDistFromBase };
    private _minXY = FADE_mapMin;
    private _maxXY = FADE_mapMax;
    private _civZoneRadius = 2500;
    private _result = [];
    private _attempt = 0;
    private _civZones = missionNamespace getVariable ["FADE_civTriggerNames", []];

    while { _attempt < 25 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        private _candidate = [];
        if (count _civZones > 0) then {
            private _zoneName = selectRandom _civZones;
            private _trig = missionNamespace getVariable [_zoneName, objNull];
            if (!isNull _trig) then {
                private _zoneCenter = getPosATL _trig;
                _candidate = [[_zoneCenter, 100, _civZoneRadius, 5, 1, 0.5, 0, [], _zoneCenter], _zoneCenter] call FADE_findSafePosArray;
            };
        };
        if (count _candidate < 2) then {
            private _x = _minXY + random (_maxXY - _minXY);
            private _y = _minXY + random (_maxXY - _minXY);
            _candidate = [_x, _y, 0];
            _candidate = [[_candidate, 0, 80, 5, 1, 0.5, 0, [], _candidate], _candidate] call FADE_findSafePosArray;
        };
        if (count _candidate >= 2 && { !(surfaceIsWater _candidate) } && { (_candidate distance _base) >= _minDist }) then {
            private _sx = _candidate select 0;
            private _sy = _candidate select 1;
            if (_sx >= _minXY && { _sx <= _maxXY } && { _sy >= _minXY } && { _sy <= _maxXY }) then {
                _result = _candidate;
            };
        };
    };
    _result
};

// Player map-click anchor: position within _radiusM of _anchor, min dist from base, clear ground.
FADE_findMissionPosNearAnchor = {
    params ["_anchor", ["_minDistOverride", -1], ["_radiusM", -1]];
    if (count _anchor < 2) exitWith { [] };
    if (_radiusM < 0) then { _radiusM = missionNamespace getVariable ["FADE_missionPlayerAnchorRadiusM", 2500] };
    private _base = FADE_basePos;
    private _minDist = if (_minDistOverride > 0) then { _minDistOverride } else { FADE_minDistFromBase };
    private _minXY = FADE_mapMin;
    private _maxXY = FADE_mapMax;
    private _result = [];
    private _attempt = 0;
    while { _attempt < 25 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        private _candidate = [[_anchor, 0, _radiusM, 5, 1, 0.5, 0, [], _anchor], _anchor] call FADE_findSafePosArray;
        if (count _candidate >= 2 && { !(surfaceIsWater _candidate) } && { (_candidate distance _base) >= _minDist }) then {
            if ((_candidate distance2D _anchor) <= _radiusM) then {
                private _sx = _candidate select 0;
                private _sy = _candidate select 1;
                if (_sx >= _minXY && { _sx <= _maxXY } && { _sy >= _minXY } && { _sy <= _maxXY }) then {
                    _result = _candidate;
                };
            };
        };
    };
    _result
};

// Hostage: built-up spot 50â€“400 m from a civ zone centre, within _radiusM of _anchor (-1 = whole map).
FADE_findMissionPosUrbanNearCenterNearAnchor = {
    params ["_anchor", ["_minDistOverride", -1], ["_radiusM", -1]];
    if (count _anchor < 2) exitWith { [] };
    if (_radiusM < 0) exitWith { [_minDistOverride] call FADE_findMissionPosUrbanNearCenter };
    private _base = FADE_basePos;
    private _minDist = if (_minDistOverride > 0) then { _minDistOverride } else { FADE_minDistFromBase };
    private _minXY = FADE_mapMin;
    private _maxXY = FADE_mapMax;
    private _result = [];
    private _attempt = 0;
    private _zoneNames = [];
    {
        private _trig = missionNamespace getVariable [_x, objNull];
        if (!isNull _trig) then {
            private _zc = getPosATL _trig;
            if (count _zc >= 2 && { (_zc distance2D _anchor) <= _radiusM } && { (_zc distance _base) >= _minDist }) then {
                _zoneNames pushBack _x;
            };
        };
    } forEach (missionNamespace getVariable ["FADE_civTriggerNames", []]);
    while { _attempt < 25 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        if (count _zoneNames == 0) exitWith {};
        private _zoneName = selectRandom _zoneNames;
        private _trig = missionNamespace getVariable [_zoneName, objNull];
        if (!isNull _trig) then {
            private _zoneCenter = getPosATL _trig;
            private _candidate = [[_zoneCenter, 50, 400, 5, 1, 0.5, 0, [], _zoneCenter], _zoneCenter] call FADE_findSafePosArray;
            if (count _candidate >= 2 && { !(surfaceIsWater _candidate) } && { (_candidate distance _base) >= _minDist }) then {
                if ((_candidate distance2D _anchor) <= _radiusM) then {
                    private _sx = _candidate select 0;
                    private _sy = _candidate select 1;
                    if (_sx >= _minXY && { _sx <= _maxXY } && { _sy >= _minXY } && { _sy <= _maxXY }) then {
                        _result = _candidate;
                    };
                };
            };
        };
    };
    _result
};

FADE_findMissionPosUrbanNearAnchor = {
    params ["_anchor", ["_minDistOverride", -1], ["_radiusM", -1]];
    if (count _anchor < 2) exitWith { [] };
    if (_radiusM < 0) exitWith { [_minDistOverride] call FADE_findMissionPosUrban };
    private _base = FADE_basePos;
    private _minDist = if (_minDistOverride > 0) then { _minDistOverride } else { FADE_minDistFromBase };
    private _minXY = FADE_mapMin;
    private _maxXY = FADE_mapMax;
    private _result = [];
    private _attempt = 0;
    private _zoneNames = [];
    {
        private _trig = missionNamespace getVariable [_x, objNull];
        if (!isNull _trig) then {
            private _zc = getPosATL _trig;
            if (count _zc >= 2 && { (_zc distance2D _anchor) <= _radiusM } && { (_zc distance _base) >= _minDist }) then {
                _zoneNames pushBack _x;
            };
        };
    } forEach (missionNamespace getVariable ["FADE_civTriggerNames", []]);
    while { _attempt < 25 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        private _candidate = [];
        if (count _zoneNames > 0) then {
            private _zoneName = selectRandom _zoneNames;
            private _trig = missionNamespace getVariable [_zoneName, objNull];
            if (!isNull _trig) then {
                private _zoneCenter = getPosATL _trig;
                _candidate = [[_zoneCenter, 50, 400, 5, 1, 0.5, 0, [], _zoneCenter], _zoneCenter] call FADE_findSafePosArray;
            };
        };
        if (count _candidate < 2) then {
            private _c = [_minDistOverride] call FADE_findMissionPosUrban;
            if (count _c >= 2 && { (_c distance2D _anchor) <= _radiusM }) then { _candidate = _c };
        };
        if (count _candidate >= 2 && { !(surfaceIsWater _candidate) } && { (_candidate distance _base) >= _minDist }) then {
            if ((_candidate distance2D _anchor) <= _radiusM) then {
                private _sx = _candidate select 0;
                private _sy = _candidate select 1;
                if (_sx >= _minXY && { _sx <= _maxXY } && { _sy >= _minXY } && { _sy <= _maxXY }) then {
                    _result = _candidate;
                };
            };
        };
    };
    _result
};

FADE_findMissionPosAssetRetrievalNearAnchor = {
    params ["_anchor", ["_minDistOverride", -1], ["_radiusFromZone", 500], ["_radiusM", -1]];
    if (count _anchor < 2) exitWith { [] };
    if (_radiusM < 0) exitWith {
        private _zoneNames = [];
        {
            private _trig = missionNamespace getVariable [_x, objNull];
            if (!isNull _trig) then {
                private _zc = getPosATL _trig;
                if (count _zc >= 2 && { (_zc distance _base) >= _minDist }) then {
                    _zoneNames pushBack _x;
                };
            };
        } forEach (missionNamespace getVariable ["FADE_civTriggerNames", []]);
        _zoneNames = [_zoneNames, [], {
            private _t = missionNamespace getVariable [_x, objNull];
            if (isNull _t) exitWith { 1e15 };
            (getPosATL _t) distance2D _anchor
        }, "ASCEND"] call BIS_fnc_sortBy;
        private _fallback = [];
        private _attempt = 0;
        while { _attempt < 25 && { count _fallback == 0 } } do {
            _attempt = _attempt + 1;
            if (count _zoneNames == 0) exitWith {};
            private _zoneName = _zoneNames select (_attempt mod count _zoneNames);
            private _trig = missionNamespace getVariable [_zoneName, objNull];
            if (!isNull _trig) then {
                private _zoneCenter = getPosATL _trig;
                private _candidate = [[_zoneCenter, 5, _radiusFromZone, 5, 1, 0.5, 0, [], _zoneCenter], _zoneCenter] call FADE_findSafePosArray;
                if (count _candidate >= 2 && { !(surfaceIsWater _candidate) } && { (_candidate distance _base) >= _minDist }) then {
                    private _sx = _candidate select 0;
                    private _sy = _candidate select 1;
                    if (_sx >= _minXY && { _sx <= _maxXY } && { _sy >= _minXY } && { _sy <= _maxXY }) then {
                        _fallback = _candidate;
                    };
                };
            };
        };
        _fallback
    };
    private _base = FADE_basePos;
    private _minDist = if (_minDistOverride > 0) then { _minDistOverride } else { FADE_minDistFromBase };
    private _minXY = FADE_mapMin;
    private _maxXY = FADE_mapMax;
    private _zoneNames = [];
    {
        private _trig = missionNamespace getVariable [_x, objNull];
        if (!isNull _trig) then {
            private _zc = getPosATL _trig;
            if (count _zc >= 2 && { (_zc distance2D _anchor) <= _radiusM } && { (_zc distance _base) >= _minDist }) then {
                _zoneNames pushBack _x;
            };
        };
    } forEach (missionNamespace getVariable ["FADE_civTriggerNames", []]);
    _zoneNames = [_zoneNames, [], {
        private _t = missionNamespace getVariable [_x, objNull];
        if (isNull _t) exitWith { 1e15 };
        (getPosATL _t) distance2D _anchor
    }, "ASCEND"] call BIS_fnc_sortBy;
    private _result = [];
    private _attempt = 0;
    while { _attempt < 25 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        if (count _zoneNames == 0) exitWith {};
        private _zoneName = _zoneNames select (_attempt mod count _zoneNames);
        private _trig = missionNamespace getVariable [_zoneName, objNull];
        if (!isNull _trig) then {
            private _zoneCenter = getPosATL _trig;
            private _candidate = [[_zoneCenter, 5, _radiusFromZone, 5, 1, 0.5, 0, [], _zoneCenter], _zoneCenter] call FADE_findSafePosArray;
            if (count _candidate >= 2 && { !(surfaceIsWater _candidate) } && { (_candidate distance _base) >= _minDist }) then {
                if ((_candidate distance2D _anchor) <= _radiusM) then {
                    private _sx = _candidate select 0;
                    private _sy = _candidate select 1;
                    if (_sx >= _minXY && { _sx <= _maxXY } && { _sy >= _minXY } && { _sy <= _maxXY }) then {
                        _result = _candidate;
                    };
                };
            };
        };
    };
    _result
};

// Civ zone names eligible for asset missions, sorted closest-first to map click (when valid).
FADE_fnc_assetZonesNearMapClick = {
    params ["_zoneNames", "_mapAnchor", ["_minDistFromBase", 1500], ["_resolvedRadius", -1]];
    private _out = [];
    {
        private _trig = missionNamespace getVariable [_x, objNull];
        if (!isNull _trig) then {
            private _zc = getPosATL _trig;
            if (count _zc >= 2 && { (_zc distance FADE_basePos) >= _minDistFromBase }) then {
                _out pushBack _x;
            };
        };
    } forEach _zoneNames;
    if (!([_mapAnchor] call FADE_fnc_isValidMapClickPos)) exitWith { _out };
    private _searchR = _resolvedRadius;
    private _snappedR = missionNamespace getVariable ["FADE_missionMapClickSnappedRadius", -2];
    if (_searchR != _snappedR && { _searchR >= 0 }) then {
        _out = _out select {
            private _t = missionNamespace getVariable [_x, objNull];
            !isNull _t && { (getPosATL _t distance2D _mapAnchor) <= _searchR }
        };
    };
    [_out, [], {
        private _t = missionNamespace getVariable [_x, objNull];
        if (isNull _t) exitWith { 1e15 };
        (getPosATL _t) distance2D _mapAnchor
    }, "ASCEND"] call BIS_fnc_sortBy
};

// Find a loose heli LZ hint near _center: dry land, moderate slope, no building/wall within clearance.
// Pilots are expected to choose the actual landing site nearby — not a pre-cleared pad.
// Params: [_center, _searchRadius] — search disc (default FADE_lzSearchRadiusDefault); each attempt jitters randomly within it.
// Returns: position array or [] if none found
FADE_findSafeLZ = {
    params ["_center", ["_searchRadius", -1]];
    if (count _center < 2) exitWith { [] };
    if (_searchRadius < 0) then {
        _searchRadius = missionNamespace getVariable ["FADE_lzSearchRadiusDefault", 80];
    };
    private _clearance = missionNamespace getVariable ["FADE_lzClearanceM", 5];
    private _maxGrad = missionNamespace getVariable ["FADE_lzMaxGrad", 0.5];
    private _maxAttempts = missionNamespace getVariable ["FADE_lzMaxAttempts", 30];
    private _localSearch = missionNamespace getVariable ["FADE_lzLocalSearchM", 25];
    private _objTypes = +(missionNamespace getVariable ["FADE_lzBlockObjectTypes", ["Building", "House", "Wall"]]);
    private _result = [];
    for "_attempt" from 1 to _maxAttempts do {
        private _tryCenter = if (_searchRadius < 1) then {
            +_center
        } else {
            [_center, random _searchRadius, random 360] call BIS_fnc_relPos
        };
        private _safe = [[_tryCenter, 0, _localSearch, _clearance, 0, _maxGrad, 0, [], _tryCenter], _tryCenter] call FADE_findLandPosWithArgs;
        if (count _safe < 2 || { surfaceIsWater _safe }) then { continue };
        private _blocking = nearestObjects [_safe, _objTypes, _clearance];
        if (({ !isNull _x } count _blocking) > 0) then { continue };
        _result = _safe;
    };
    _result
};

