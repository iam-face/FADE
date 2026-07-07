// ServerGameplayMissionsPick.sqf - map-click dest pickers
FADE_fnc_isValidMapClickPos = {
    params ["_p"];
    if (!(_p isEqualType []) || { count _p < 2 }) exitWith { false };
    private _x = _p select 0;
    private _y = _p select 1;
    if (!(_x isEqualType 0) || {!(_y isEqualType 0)}) exitWith { false };
    true
};

// Map-click tier helpers: _radiusM < 0 = whole-map random (no anchor distance cap).
FADE_fnc_anchorWithinRadius = {
    params ["_pos", "_anchor", "_radiusM"];
    if (_radiusM < 0) exitWith { true };
    if (count _pos < 2 || { count _anchor < 2 }) exitWith { false };
    (_pos distance2D _anchor) <= _radiusM
};

// Map click ? nearest civ zone centre (eligible zones only: >= _minDistFromBase from HQ).
FADE_fnc_snapMapClickToNearestCivZone = {
    params ["_mapClick", ["_minDistFromBase", -1]];
    if (!([_mapClick] call FADE_fnc_isValidMapClickPos)) exitWith { [] };
    private _base = FADE_basePos;
    private _minDist = if (_minDistFromBase > 0) then { _minDistFromBase } else { FADE_minDistFromBase };
    private _best = [];
    private _bestD = 1e15;
    {
        private _trig = missionNamespace getVariable [_x, objNull];
        if (!isNull _trig) then {
            private _zc = getPosATL _trig;
            if (count _zc >= 2 && { (_zc distance _base) >= _minDist }) then {
                private _d = _zc distance2D _mapClick;
                if (_d < _bestD) then {
                    _bestD = _d;
                    _best = [(_zc select 0), (_zc select 1), (_zc param [2, 0])];
                };
            };
        };
    } forEach (missionNamespace getVariable ["FADE_civTriggerNames", []]);
    _best
};

// Civ zone centres eligible for troop insert/extract (>= _minDistFromBase from HQ).
FADE_fnc_eligibleCivZoneCenters = {
    params [["_minDistFromBase", 2000]];
    private _base = +FADE_basePos;
    if (count _base < 2) exitWith { [] };
    private _out = [];
    {
        private _trig = missionNamespace getVariable [_x, objNull];
        if (!isNull _trig) then {
            private _zc = getPosATL _trig;
            if (count _zc >= 2 && { (_zc distance2D _base) >= _minDistFromBase }) then {
                _out pushBack [(_zc select 0), (_zc select 1), (_zc param [2, 0])];
            };
        };
    } forEach (missionNamespace getVariable ["FADE_civTriggerNames", []]);
    _out
};

// Pick a heli landing site: random eligible civ zone -> point 0..FADE_troopHeliSiteMaxDistFromCivZone -> FADE_findSafeLZ.
// Optional _preferredZoneCenter (map-click snap) is tried first; _minDistFromRef enforces distance from _refPos when > 0.
FADE_fnc_pickTroopHeliSiteAtCivZone = {
    params [
        ["_minDistFromBase", 2000],
        ["_excludePositions", []],
        ["_preferredZoneCenter", []],
        ["_minDistFromRef", -1],
        ["_refPos", []]
    ];
    private _zones = [_minDistFromBase] call FADE_fnc_eligibleCivZoneCenters;
    if (_zones isEqualTo []) exitWith { [] };
    private _base = +FADE_basePos;
    private _maxDistFromZone = missionNamespace getVariable ["FADE_troopHeliSiteMaxDistFromCivZone", 250];
    private _triesPerZone = 20;

    private _fnc_tryZone = {
        params ["_zoneCenter"];
        private _out = [];
        for "_try" from 0 to (_triesPerZone - 1) do {
            private _dist = random _maxDistFromZone;
            private _cand = if (_dist < 1) then { +_zoneCenter } else { [_zoneCenter, _dist, random 360] call BIS_fnc_relPos };
            if (surfaceIsWater _cand) then { continue };
            private _dryCand = [_cand, _zoneCenter] call FADE_ensureDryLandPos;
            if (count _dryCand < 2 || { surfaceIsWater _dryCand }) then { continue };
            if ((_dryCand distance2D _zoneCenter) > _maxDistFromZone) then { continue };
            private _lzSearch = (_maxDistFromZone - (_dryCand distance2D _zoneCenter)) max 10 min 120;
            private _lz = [_dryCand, _lzSearch] call FADE_findSafeLZ;
            if (count _lz < 2) then { _lz = _dryCand };
            if (count _lz < 2 || { surfaceIsWater _lz }) then { continue };
            if ((_lz distance2D _zoneCenter) > _maxDistFromZone) then { continue };
            if ((_lz distance2D _base) < _minDistFromBase) then { continue };
            if (_minDistFromRef > 0 && { count _refPos >= 2 } && { _lz distance2D _refPos < _minDistFromRef }) then { continue };
            private _blocked = false;
            { if (_lz distance2D _x < 2000) exitWith { _blocked = true } } forEach _excludePositions;
            if (_blocked) then { continue };
            if !([_lz] call FADE_missionPosClear) then { continue };
            _out = _lz;
        };
        _out
    };

    private _pool = +_zones;
    if (count _preferredZoneCenter >= 2) then {
        private _nearest = [_zones, _preferredZoneCenter] call BIS_fnc_nearestPosition;
        if (_nearest isEqualType [] && { count _nearest >= 2 }) then {
            private _preferredHit = [_nearest] call _fnc_tryZone;
            if (count _preferredHit >= 2) exitWith { _preferredHit };
            _pool = _pool select { (_x distance2D _nearest) >= 1 };
        };
    };

    private _result = [];
    while { count _pool > 0 && { count _result < 2 } } do {
        private _zoneCenter = selectRandom _pool;
        _pool = _pool select { (_x distance2D _zoneCenter) >= 1 };
        _result = [_zoneCenter] call _fnc_tryZone;
    };
    _result
};

// Built-up position near a civ zone centre (50�400 m by default).
FADE_fnc_urbanPosNearZoneCenter = {
    params ["_zoneCenter", "_minDist", ["_innerMin", 50], ["_innerMax", 400]];
    if (count _zoneCenter < 2) exitWith { [] };
    private _base = FADE_basePos;
    private _minXY = FADE_mapMin;
    private _maxXY = FADE_mapMax;
    private _candidate = [[_zoneCenter, _innerMin, _innerMax, 5, 1, 0.5, 0, [], _zoneCenter], _zoneCenter] call FADE_findSafePosArray;
    if (count _candidate < 2 || { surfaceIsWater _candidate } || { (_candidate distance _base) < _minDist }) exitWith { [] };
    private _sx = _candidate select 0;
    private _sy = _candidate select 1;
    if (_sx < _minXY || { _sx > _maxXY } || { _sy < _minXY } || { _sy > _maxXY }) exitWith { [] };
    _candidate
};

FADE_fnc_tryHostageDestAtZoneCenter = {
    params ["_zoneCenter", "_minDist", ["_attempt", 1]];
    private _site = [_zoneCenter, _minDist, 40, _attempt] call FADE_fnc_posAtCivZoneCenter;
    private _buildings = nearestObjects [_zoneCenter, ["House", "Building"], 450];
    if (({ count (_x buildingPos -1) >= 5 } count _buildings) < 2) exitWith { [] };
    _site
};

FADE_fnc_tryHvtDestAtZoneCenter = {
    params ["_zoneCenter", "_minDist", ["_attempt", 1]];
    private _site = [_zoneCenter, _minDist, 40, _attempt] call FADE_fnc_posAtCivZoneCenter;
    private _buildRadius = if (_attempt <= 1) then { 450 } else { 550 };
    private _buildings = nearestObjects [_zoneCenter, ["House", "Building"], _buildRadius];
    if (({ count (_x buildingPos -1) >= 10 } count _buildings) < 1) exitWith { [] };
    _site
};

FADE_fnc_trySearchDestroySiteAtZoneCenter = {
    params ["_zoneCenter", "_minDist", ["_attempt", 1]];
    private _site = [_zoneCenter, _minDist, 40, _attempt] call FADE_fnc_posAtCivZoneCenter;
    private _buildings = nearestObjects [_zoneCenter, ["House", "Building"], 250];
    private _pickedTrial = [];
    {
        if (count _pickedTrial >= 3) exitWith {};
        if (count (_x buildingPos -1) >= 2) then { _pickedTrial pushBack _x };
    } forEach (_buildings call BIS_fnc_arrayShuffle);
    if (count _pickedTrial < 3) exitWith { [] };
    _site
};

FADE_fnc_assetPosAtZoneCenter = {
    params ["_zoneCenter", "_minDist", ["_maxOffset", 80], ["_attempt", 1]];
    [_zoneCenter, _minDist, _maxOffset, _attempt] call FADE_fnc_posAtCivZoneCenter
};

// Dry land at civ zone centre (tight offset for map-click snap).
FADE_fnc_posAtCivZoneCenter = {
    params ["_zoneCenter", "_minDist", ["_maxOffset", 40], ["_attempt", 1]];
    if (count _zoneCenter < 2) exitWith { [] };
    private _innerMin = if (_attempt <= 1) then { 0 } else { 5 };
    private _innerMax = if (_attempt <= 1) then { _maxOffset } else { (_maxOffset + 40) min 80 };
    private _c = [_zoneCenter, _minDist, _innerMin, _innerMax] call FADE_fnc_urbanPosNearZoneCenter;
    if (count _c >= 2) then { _c } else { +_zoneCenter }
};

// One placement attempt at a snapped civ zone centre (map click).
FADE_fnc_pickDestAtCivZoneCenter = {
    params ["_missionType", "_minDistForPos", "_needsLZ", "_zoneCenter", ["_attempt", 1]];
    if (count _zoneCenter < 2) exitWith { [] };
    if (_missionType == "Hostage") exitWith { [_zoneCenter, _minDistForPos, _attempt] call FADE_fnc_tryHostageDestAtZoneCenter };
    if (_missionType == "HVT") exitWith { [_zoneCenter, _minDistForPos, _attempt] call FADE_fnc_tryHvtDestAtZoneCenter };
    if (_missionType == "SearchDestroy") exitWith { [_zoneCenter, _minDistForPos, _attempt] call FADE_fnc_trySearchDestroySiteAtZoneCenter };
    if (_missionType in ["AssetRetrieval", "MineClearing", "TroopExtract"]) exitWith {
        [_zoneCenter, _minDistForPos, 80, _attempt] call FADE_fnc_assetPosAtZoneCenter
    };
    if (_missionType in ["ClearArea", "AreaOfOperations"]) exitWith {
        [_zoneCenter, _minDistForPos, 40, _attempt] call FADE_fnc_posAtCivZoneCenter
    };
    if (_missionType == "Operation") exitWith { +_zoneCenter };
    if (_missionType == "Raid") exitWith { +_zoneCenter };
    private _candidate = [_zoneCenter, _minDistForPos, 50, 500] call FADE_fnc_urbanPosNearZoneCenter;
    if (count _candidate < 2) exitWith { [] };
    if (_needsLZ) then {
        private _lz = [_candidate] call FADE_findSafeLZ;
        if (count _lz < 2) exitWith { [] };
        _lz
    } else {
        _candidate
    }
};

FADE_fnc_tryHostageDestAtRadius = {
    params ["_anchor", "_minDist", "_radiusM"];
    private _buildRadius = 450;
    private _minSlots = 5;
    private _minBld = 2;
    private _attempt = 0;
    private _result = [];
    while { _attempt < 20 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        private _destPos = if (_radiusM < 0) then {
            [_minDist] call FADE_findMissionPosUrbanNearCenter
        } else {
            [_anchor, _minDist, _radiusM] call FADE_findMissionPosUrbanNearCenterNearAnchor
        };
        if (count _destPos >= 2) then {
            private _buildings = nearestObjects [_destPos, ["House", "Building"], _buildRadius];
            private _candidates = _buildings select { count (_x buildingPos -1) >= _minSlots };
            if (count _candidates >= _minBld) then {
                private _center = getPosATL (_candidates select 0);
                if (_radiusM < 0 || { (_center distance2D _anchor) <= _radiusM }) then {
                    _result = _destPos;
                };
            };
        };
    };
    _result
};

FADE_fnc_tryHvtDestAtRadius = {
    params ["_anchor", "_minDist", "_radiusM", "_minSlots", "_buildRadius"];
    private _attempt = 0;
    private _result = [];
    while { _attempt < 20 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        private _destPos = if (_radiusM < 0) then {
            [_minDist] call FADE_findMissionPosUrban
        } else {
            [_anchor, _minDist, _radiusM] call FADE_findMissionPosUrbanNearAnchor
        };
        if (count _destPos >= 2) then {
            private _buildings = nearestObjects [_destPos, ["House", "Building"], _buildRadius];
            private _found = _buildings findIf { count (_x buildingPos -1) >= _minSlots };
            if (_found >= 0) then {
                private _center = getPosATL (_buildings select _found);
                if (_radiusM < 0 || { (_center distance2D _anchor) <= _radiusM }) then {
                    _result = [(_destPos select 0), (_destPos select 1), (_destPos param [2, 0])];
                };
            };
        };
    };
    _result
};

FADE_fnc_trySearchDestroySiteAtRadius = {
    params ["_anchor", "_minDist", "_radiusM"];
    private _areaRadius = missionNamespace getVariable ["FADE_missionApproxZoneRadiusM", 55];
    private _attempt = 0;
    private _result = [];
    while { _attempt < 20 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        private _tryPos = if (_radiusM < 0) then {
            [_minDist] call FADE_findMissionPosUrbanNearCenter
        } else {
            [_anchor, _minDist, _radiusM] call FADE_findMissionPosUrbanNearCenterNearAnchor
        };
        if (count _tryPos >= 2) then {
            private _c = +_tryPos;
            if (count _c < 3) then { _c = [(_c select 0), (_c select 1), 0] };
            private _buildings = nearestObjects [_c, ["House", "Building"], _areaRadius];
            private _cands = _buildings call BIS_fnc_arrayShuffle;
            private _pickedTrial = [];
            {
                if (count _pickedTrial >= 3) exitWith {};
                if (count (_x buildingPos -1) >= 2) then { _pickedTrial pushBack _x };
            } forEach _cands;
            if (count _pickedTrial >= 3) then {
                if (_radiusM < 0 || { (_c distance2D _anchor) <= _radiusM }) then {
                    _result = _c;
                };
            };
        };
    };
    _result
};

// Asset Retrieval: building with >=6 buildingPos slots within 500 m of a civ zone (dry land, min dist from base).
// Returns [centerATL, house, houseBps] or [[], objNull, []].
FADE_fnc_tryAssetRetrievalBuildingAtZone = {
    params ["_zoneCenter", "_minDist", ["_searchM", 500], ["_minSlots", 6]];
    if (count _zoneCenter < 2) exitWith { [[], objNull, []] };
    private _dryPos = missionNamespace getVariable ["FADE_surfaceIsDry", {}];
    private _buildings = nearestObjects [_zoneCenter, ["House", "Building"], _searchM];
    if (count _buildings > 28) then {
        _buildings = (_buildings call BIS_fnc_arrayShuffle) select [0, 28];
    };
    private _suitable = [];
    {
        private _bps = _x buildingPos -1;
        if (count _bps >= _minSlots && { [getPosATL _x] call _dryPos }) then {
            _suitable pushBack [_x, _bps];
        };
    } forEach _buildings;
    if (_suitable isEqualTo []) exitWith { [[], objNull, []] };
    private _pick = selectRandom _suitable;
    private _house = _pick param [0, objNull];
    private _houseBps = _pick param [1, []];
    private _center = getPosATL _house;
    if (count _center < 3) then { _center = [(_center select 0), (_center select 1), 0] };
    if ((_center distance FADE_basePos) < _minDist) exitWith { [[], objNull, []] };
    [_center, _house, _houseBps]
};
missionNamespace setVariable ["FADE_fnc_tryAssetRetrievalBuildingAtZone", FADE_fnc_tryAssetRetrievalBuildingAtZone];

// Random / map-click Asset Retrieval anchor: civ zone with a suitable objective building.
FADE_fnc_tryAssetRetrievalDestAtRadius = {
    params ["_anchor", "_minDist", "_radiusM"];
    private _useAnchor = [_anchor] call FADE_fnc_isValidMapClickPos;
    private _eligible = [];
    {
        private _trig = missionNamespace getVariable [_x, objNull];
        if (!isNull _trig) then {
            private _zc = getPosATL _trig;
            if (count _zc >= 2 && { (_zc distance FADE_basePos) >= _minDist }) then {
                if (!_useAnchor || { _radiusM < 0 } || { (_zc distance2D _anchor) <= _radiusM }) then {
                    _eligible pushBack _x;
                };
            };
        };
    } forEach (missionNamespace getVariable ["FADE_civTriggerNames", []]);
    if (_eligible isEqualTo []) exitWith { [] };
    if (_useAnchor) then {
        _eligible = [_eligible, [], {
            private _t = missionNamespace getVariable [_x, objNull];
            if (isNull _t) exitWith { 1e15 };
            (getPosATL _t) distance2D _anchor
        }, "ASCEND"] call BIS_fnc_sortBy;
    } else {
        _eligible = _eligible call BIS_fnc_arrayShuffle;
    };
    private _attempt = 0;
    private _result = [];
    private _tryFn = missionNamespace getVariable ["FADE_fnc_tryAssetRetrievalBuildingAtZone", {}];
    while { _attempt < 20 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        private _zoneName = selectRandom _eligible;
        private _trig = missionNamespace getVariable [_zoneName, objNull];
        if (isNull _trig) then { continue };
        private _hit = [getPosATL _trig, _minDist] call _tryFn;
        _hit params ["_center", "_house", "_bps"];
        if (count _center >= 2 && { !isNull _house }) then { _result = _center };
    };
    _result
};
missionNamespace setVariable ["FADE_fnc_tryAssetRetrievalDestAtRadius", FADE_fnc_tryAssetRetrievalDestAtRadius];

// One candidate at a fixed search radius from map click (server).
FADE_startMission_pickDestPosAtRadius = {
    params ["_missionType", "_minDistForPos", "_needsLZ", "_anchorPos", "_radiusM"];
    private _useAnchor = [_anchorPos] call FADE_fnc_isValidMapClickPos;
    if (_missionType == "InterceptConvoy") exitWith {
        if (_useAnchor) then {
            if (_radiusM < 0 || { [_anchorPos, _anchorPos, _radiusM] call FADE_fnc_anchorWithinRadius }) then { +_anchorPos } else { [] }
        } else { [0, 0, 0] }
    };
    if (_missionType == "Hostage") exitWith {
        if (!_useAnchor) exitWith { [_minDistForPos] call FADE_findMissionPosUrbanNearCenter };
        [_anchorPos, _minDistForPos, _radiusM] call FADE_fnc_tryHostageDestAtRadius
    };
    if (_missionType == "HVT") exitWith {
        if (!_useAnchor) exitWith { [_minDistForPos] call FADE_findMissionPosUrban };
        [_anchorPos, _minDistForPos, _radiusM, 10, 450] call FADE_fnc_tryHvtDestAtRadius
    };
    if (_missionType == "SearchDestroy") exitWith {
        if (!_useAnchor) exitWith { [_minDistForPos] call FADE_findMissionPosUrbanNearCenter };
        [_anchorPos, _minDistForPos, _radiusM] call FADE_fnc_trySearchDestroySiteAtRadius
    };
    if (_missionType == "Operation") exitWith {
        if (_useAnchor) then { +_anchorPos } else { +FADE_basePos }
    };
    if (_missionType in ["Raid", "Invasion"]) exitWith {
        if (_useAnchor) then { +_anchorPos } else { +FADE_basePos }
    };
    if (_missionType == "TroopExtract") exitWith {
        if (_useAnchor) then {
            [_anchorPos, _minDistForPos, 500, _radiusM] call FADE_findMissionPosAssetRetrievalNearAnchor
        } else {
            [_minDistForPos, 500] call FADE_findMissionPosAssetRetrieval
        }
    };
    if (_missionType == "ClearArea" || { _missionType == "AreaOfOperations" }) exitWith {
        private _wholeR = missionNamespace getVariable ["FADE_missionPlayerAnchorRadiusM", 5000];
        private _candidate = if (_useAnchor) then {
            if (_radiusM < 0) then {
                [_anchorPos, _minDistForPos, _wholeR] call FADE_findMissionPosNearAnchor
            } else {
                [_anchorPos, _minDistForPos, _radiusM] call FADE_findMissionPosNearAnchor
            }
        } else {
            [_minDistForPos] call FADE_findMissionPos
        };
        if (count _candidate >= 2) then { _candidate } else { [] }
    };
    if (_missionType == "AssetRetrieval") exitWith {
        if (_useAnchor) then {
            [_anchorPos, _minDistForPos, _radiusM] call FADE_fnc_tryAssetRetrievalDestAtRadius
        } else {
            [[], _minDistForPos, -1] call FADE_fnc_tryAssetRetrievalDestAtRadius
        }
    };
    if (_missionType == "MineClearing") exitWith {
        if (_useAnchor) then {
            [_anchorPos, _minDistForPos, 500, _radiusM] call FADE_findMissionPosAssetRetrievalNearAnchor
        } else {
            [_minDistForPos, 500] call FADE_findMissionPosAssetRetrieval
        }
    };
    private _wholeR = missionNamespace getVariable ["FADE_missionPlayerAnchorRadiusM", 5000];
    private _candidate = if (_useAnchor) then {
        if (_radiusM < 0) then {
            [_anchorPos, _minDistForPos, _wholeR] call FADE_findMissionPosNearAnchor
        } else {
            [_anchorPos, _minDistForPos, _radiusM] call FADE_findMissionPosNearAnchor
        }
    } else {
        [_minDistForPos] call FADE_findMissionPos
    };
    if (count _candidate < 2) exitWith { [] };
    private _dryFn = missionNamespace getVariable ["FADE_surfaceIsDry", {}];
    if (_missionType in ["CASEVAC", "CSAR", "CAS"] && { !(_dryFn isEqualTo {}) } && { !([_candidate] call _dryFn) }) exitWith { [] };
    if (_needsLZ) then {
        private _lz = [_candidate] call FADE_findSafeLZ;
        if (count _lz < 2) exitWith { [] };
        if (_useAnchor) then {
            private _lzR = if (_radiusM < 0) then { _wholeR } else { _radiusM };
            if (!([_lz, _anchorPos, _lzR] call FADE_fnc_anchorWithinRadius)) exitWith { [] };
        };
        if (_missionType in ["CASEVAC", "CSAR", "CAS"] && { !(_dryFn isEqualTo {}) } && { !([_lz] call _dryFn) }) exitWith { [] };
        _lz
    } else {
        if (_missionType in ["CASEVAC", "CSAR", "CAS"] && { !(_dryFn isEqualTo {}) } && { !([_candidate] call _dryFn) }) exitWith { [] };
        _candidate
    }
};

// Returns [destPos, resolvedRadius, snappedZoneCenter]. resolvedRadius -2 = civ-zone snap (Config).
FADE_fnc_mapPickCandidatePasses = {
    params ["_candidate", "_missionType", "_pickupRef", "_minPickupDistM"];
    if (count _candidate < 2) exitWith { false };
    private _ok = _missionType in ["InterceptConvoy", "Operation", "AreaOfOperations"] || { [_candidate] call FADE_missionPosClear };
    if (!_ok) exitWith { false };
    if (_minPickupDistM >= 0 && { count _pickupRef >= 2 } && { (_candidate distance2D _pickupRef) < _minPickupDistM }) exitWith { false };
    true
};

// Map click: civ-zone missions snap to nearest settlement; others expand 250m -> whole map.
FADE_fnc_pickMissionDestNearMapClick = {
    params [
        "_anchor", "_missionType", "_minDistForPos", "_needsLZ",
        ["_pickupRef", []], ["_minPickupDistM", -1]
    ];
    private _snapTypes = missionNamespace getVariable ["FADE_missionMapClickSnapCivZoneTypes", []];
    if (_missionType in _snapTypes) then {
        private _zoneCenter = [_anchor, _minDistForPos] call FADE_fnc_snapMapClickToNearestCivZone;
        if (count _zoneCenter < 2) exitWith { [], -1, [] };
        private _snappedR = missionNamespace getVariable ["FADE_missionMapClickSnappedRadius", -2];
        private _result = [];
        for "_a" from 1 to 25 do {
            private _candidate = [_missionType, _minDistForPos, _needsLZ, _zoneCenter, _a] call FADE_fnc_pickDestAtCivZoneCenter;
            if (
                count _candidate >= 2
                && { [_candidate, _missionType, _pickupRef, _minPickupDistM] call FADE_fnc_mapPickCandidatePasses }
            ) then { _result = _candidate };
            if (count _result >= 2) exitWith {};
        };
        [_result, _snappedR, +_zoneCenter]
    } else {
        private _tiers = missionNamespace getVariable ["FADE_missionMapClickRadiusTiers", [250, 500, 1000, 2500, 5000, -1]];
        private _result = [];
        private _usedR = -1;
        {
            private _r = _x;
            for "_a" from 1 to 10 do {
                private _candidate = [_missionType, _minDistForPos, _needsLZ, _anchor, _r] call FADE_startMission_pickDestPosAtRadius;
                if (
                    count _candidate >= 2
                    && { [_candidate, _missionType, _pickupRef, _minPickupDistM] call FADE_fnc_mapPickCandidatePasses }
                ) then {
                    _result = _candidate;
                    _usedR = _r;
                };
                if (count _result >= 2) exitWith {};
            };
            if (count _result >= 2) exitWith {};
        } forEach _tiers;
        [_result, _usedR, []]
    };
};

// Troop Insert first LZ: shared tier search + pickup-distance filter (strict then relaxed).
FADE_fnc_pickTroopInsertLzNearMapClick = {
    params ["_lzAnchor", "_minDistForPos", "_pickupRef", "_lzMinStrict", "_lzMinRelaxed"];
    private _destPos = [];
    private _usedR = -1;
    private _snapped = [];
    for "_pass" from 0 to 1 do {
        private _needDist = if (_pass == 0) then { _lzMinStrict } else { _lzMinRelaxed };
        private _pick = [_lzAnchor, "TroopInsert", _minDistForPos, true, _pickupRef, _needDist] call FADE_fnc_pickMissionDestNearMapClick;
        _pick params ["_picked", "_r", "_snap"];
        if (count _picked >= 2) exitWith {
            _destPos = _picked;
            _usedR = _r;
            _snapped = _snap;
        };
    };
    [_destPos, _usedR, _snapped]
};

// Brief hint to mission starter after map-click placement resolves (grid + offset from click).
FADE_fnc_mapPickResultHint = {
    params ["_player", "_destPos", "_rawClick", "_snappedCenter", "_resolvedRadius"];
    if (isNull _player || { count _destPos < 2 }) exitWith {};
    private _grid = mapGridPosition _destPos;
    private _lines = [];
    private _snappedR = missionNamespace getVariable ["FADE_missionMapClickSnappedRadius", -2];
    if (count _snappedCenter >= 2 && { _resolvedRadius == _snappedR }) then {
        _lines pushBack format ["Snapped to nearest settlement (grid %1).", mapGridPosition _snappedCenter];
    };
    if (count _rawClick >= 2) then {
        private _d = round (_destPos distance2D _rawClick);
        if (_resolvedRadius >= 0) then {
            _lines pushBack format ["%1 m from your click (%2 m search tier).", _d, _resolvedRadius];
        } else {
            if (_resolvedRadius == _snappedR) then {
                _lines pushBack format ["%1 m from your click (settlement snap).", _d];
            } else {
                _lines pushBack format ["%1 m from your click.", _d];
            };
        };
    };
    private _detail = if (count _lines > 0) then { _lines joinString "<br/>" } else { "Loading mission details..." };
    [
        format [
            "<t size='1.1' color='#A0D0A0'>Mission area: grid %1</t><br/><t color='#808080'>%2</t>",
            _grid,
            _detail
        ]
    ] remoteExec ["FADE_showMissionHint", _player];
};

// -----------------------------------------------------------------------------
// One candidate anchor for FADE_startMission (server). Flat exitWith flow � avoids brittle nested if/else braces.
// -----------------------------------------------------------------------------
FADE_startMission_pickDestPos = {
    params ["_missionType", "_minDistForPos", "_needsLZ", ["_anchorPos", []], ["_radiusM", -1]];
    [_missionType, _minDistForPos, _needsLZ, _anchorPos, _radiusM] call FADE_startMission_pickDestPosAtRadius
};
