// =============================================================================
// FADE_civZonesFromLocations.sqf  -  build CIV_T_* zone anchors from map Locations
// =============================================================================
// Server-only. Loaded from initServer after FADE_basePos is set.
// Per-zone metadata in FADE_civZoneMeta (HashMap): locType, hasAmbientPop, buildingCount,
// parkedVehicles (2-6 by tier), footMult for walking civ count scaling.
// Named locations with fewer than FADE_civZoneMinBuildings House/Building within
// FADE_civZoneBuildingRadius are not designated as civ zones (no CIV_T_* anchor).
// =============================================================================

if (!isServer) exitWith {};

FADE_civZonesFromLocations_build = {
    if (!isServer) exitWith {};

    private _minDist = missionNamespace getVariable ["FADE_civZoneMinDistFromBase", 2000];
    private _locTypes = missionNamespace getVariable ["FADE_civZoneLocationTypes", ["NameCityCapital", "NameCity", "NameVillage", "NameLocal"]];
    private _skipWater = missionNamespace getVariable ["FADE_civZoneSkipWater", true];
    private _anchorClass = missionNamespace getVariable ["FADE_civZoneAnchorClass", "Land_HelipadEmpty_F"];
    private _bldRadius = missionNamespace getVariable ["FADE_civZoneBuildingRadius", if (!isNil "FADE_civZoneBuildingRadius") then { FADE_civZoneBuildingRadius } else { 500 }];
    private _minBld = missionNamespace getVariable ["FADE_civZoneMinBuildings", if (!isNil "FADE_civZoneMinBuildings") then { FADE_civZoneMinBuildings } else { 10 }];

    private _base = missionNamespace getVariable ["FADE_basePos", []];
    if (count _base < 2) exitWith {
        diag_log "[FADE_civZonesFromLocations] Aborted: FADE_basePos unset.";
    };

    if (!(isClass (configFile >> "CfgVehicles" >> _anchorClass))) then {
        _anchorClass = "Land_HelipadEmpty_F";
    };

    private _base2 = [_base select 0, _base select 1];
    private _worldC = worldSize / 2;
    private _locs = nearestLocations [[_worldC, _worldC, 0], _locTypes, worldSize * 0.75];

    // [location object, ATL position]
    private _accepted = [];
    {
        private _loc = _x;
        private _lp = locationPosition _loc;
        if (count _lp >= 2) then {
            if (([_lp select 0, _lp select 1] distance2D _base2) >= _minDist) then {
                private _pos = [(_lp select 0), (_lp select 1), 0];
                if (!(_skipWater && { surfaceIsWater _pos })) then {
                    _accepted pushBack [_loc, _pos];
                };
            };
        };
    } forEach _locs;

    private _n = count _accepted;
    diag_log format ["[FADE_civZonesFromLocations] %1 named location(s) accepted (>= %2 m from HQ, water filter %3).", _n, _minDist, _skipWater];

    private _legacyMax = missionNamespace getVariable ["FADE_civTriggerIndexMax", 109];
    if (_legacyMax > 0) then {
        for "_j" from 1 to _legacyMax do {
            private _vn2 = format ["CIV_T_%1", _j];
            private _old = missionNamespace getVariable [_vn2, objNull];
            if (!isNull _old) then { deleteVehicle _old };
            missionNamespace setVariable [_vn2, objNull];
        };
    };

    FADE_civZoneMeta = createHashMap;

    private _created = 0;
    private _skippedBld = 0;
    {
        _x params ["_location", "_posATL"];
        private _lt = type _location;
        private _nBld = count (nearestObjects [_posATL, ["House", "Building"], _bldRadius]);
        if (_nBld < _minBld) then {
            _skippedBld = _skippedBld + 1;
            diag_log format [
                "[FADE_civZonesFromLocations] Skip '%1' (%2): %3 building(s) in %4m (need >= %5).",
                text _location, _lt, _nBld, _bldRadius, _minBld
            ];
        } else {
        private _hasPop = _nBld > 0;

        private _parked = 0;
        private _footMult = 0.7;
        switch _lt do {
            case "NameCityCapital": { _parked = 6; _footMult = 1.35; };
            case "NameCity": { _parked = 5; _footMult = 1.15; };
            case "NameVillage": { _parked = 3; _footMult = 0.9; };
            case "NameLocal": { _parked = 2; _footMult = 0.65; };
            default { _parked = 2; _footMult = 0.65; };
        };
        if (!_hasPop) then { _parked = 0; _footMult = 0; };

        private _obj = createVehicle [_anchorClass, [0, 0, 1000], [], 0, "NONE"];
        if (isNull _obj) then {
            diag_log format ["[FADE_civZonesFromLocations] createVehicle failed (class %1)", _anchorClass];
        } else {
            _created = _created + 1;
            _obj setPosATL _posATL;
            _obj enableSimulationGlobal false;
            private _zname = format ["CIV_T_%1", _created];
            missionNamespace setVariable [_zname, _obj];

            private _meta = createHashMap;
            _meta set ["locType", _lt];
            _meta set ["hasAmbientPop", _hasPop];
            _meta set ["buildingCount", _nBld];
            _meta set ["parkedVehicles", _parked];
            _meta set ["footMult", _footMult];
            FADE_civZoneMeta set [_zname, _meta];
        };
        };
    } forEach _accepted;

    missionNamespace setVariable ["FADE_civTriggerIndexMax", _created];
    private _popN = 0;
    {
        private _m = FADE_civZoneMeta get _x;
        if (!isNil "_m" && { _m get "hasAmbientPop" }) then { _popN = _popN + 1 };
    } forEach (keys FADE_civZoneMeta);
    diag_log format [
        "[FADE_civZonesFromLocations] Anchors %1 | skipped (<%2 buildings in %3m): %4 | zones with ambient pop: %5",
        _created, _minBld, _bldRadius, _skippedBld, _popN
    ];
};

true
