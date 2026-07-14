// =============================================================================
// FADE_MissionSpawn.sqf  -  shared mission spawn helpers (server, compile once)
// =============================================================================

FADE_spawnEnemyGroupAt = {
    params ["_pos", "_side", "_classes", ["_anchor", []]];
    private _ensureDry = missionNamespace getVariable ["FADE_ensureDryLandPos", {}];
    private _spawnPos = if (_ensureDry isEqualTo {}) then { [_pos] call FADE_normPos3 } else { [_pos, _anchor] call _ensureDry };
    [_spawnPos, _side, _classes] call BIS_fnc_spawnGroup
};

FADE_createEnemyUnitAt = {
    params ["_group", "_class", "_pos", ["_anchor", []]];
    private _ensureDry = missionNamespace getVariable ["FADE_ensureDryLandPos", {}];
    private _spawnPos = if (_ensureDry isEqualTo {}) then { [_pos] call FADE_normPos3 } else { [_pos, _anchor] call _ensureDry };
    private _u = _group createUnit [_class, _spawnPos, [], 0, "NONE"];
    if (!isNull _u) then { _u setPosATL _spawnPos };
    _u
};

FADE_vg_registerMissionSite = {
    params [
        "_center",
        ["_tryBarrel", true],
        ["_groupsRef", []],
        ["_barrelClasses", ["Land_BarrelSand_F", "Land_MetalBarrel_F"]]
    ];
    if (!isNil "FADE_vg_register") then {
        [
            _center,
            _tryBarrel,
            random 1 < 0.5,
            _barrelClasses,
            _center,
            _groupsRef
        ] call FADE_vg_register;
    };
};

// createGroup + createUnit at one ATL (patrol groups; avoids BIS_fnc_spawnGroup stale-waypoint issues).
FADE_missionEnsureInfantryGroupLeader = {
    params ["_grp"];
    if (isNull _grp) exitWith { grpNull };
    {
        if (!(_x isKindOf "Man")) then {
            // #region agent log
            diag_log format [
                "[FAC DbgBrowser 62d308] H19 deleteNonMan type=%1 grp=%2",
                typeOf _x, _grp
            ];
            // #endregion
            deleteVehicle _x;
        };
    } forEach units _grp;
    private _men = units _grp select { _x isKindOf "Man" && { alive _x } };
    if (count _men == 0) exitWith {
        deleteGroup _grp;
        grpNull
    };
    private _ldr = leader _grp;
    if (isNull _ldr || { !(_ldr isKindOf "Man") } || { !alive _ldr }) then {
        _grp selectLeader (_men select 0);
        // #region agent log
        diag_log format [
            "[FAC DbgBrowser 62d308] H19 selectLeader type=%1 grp=%2",
            typeOf (leader _grp), _grp
        ];
        // #endregion
    };
    _grp
};

FADE_missionCreateInfantryGroupAt = {
    params ["_pos", "_side", "_classes"];
    private _spawnPos = [_pos] call FADE_normPos3;
    private _clsIn = [_classes] call FADE_filterInfantryManClasses;
    if (_clsIn isEqualTo []) exitWith { grpNull };
    private _grp = createGroup _side;
    {
        if (!([_x] call FADE_isInfantryManClass)) then {
            // #region agent log
            diag_log format ["[FAC DbgBrowser 62d308] H19 skipNonInfantry class=%1", _x];
            // #endregion
        } else {
            private _u = _grp createUnit [_x, _spawnPos, [], 0, "NONE"];
            if (!isNull _u) then {
                if (_u isKindOf "Man") then {
                    _u setPosATL _spawnPos;
                } else {
                    // #region agent log
                    diag_log format [
                        "[FAC DbgBrowser 62d308] H19 badCreateUnit class=%1 type=%2",
                        _x, typeOf _u
                    ];
                    // #endregion
                    deleteVehicle _u;
                };
            };
        };
    } forEach _clsIn;
    [_grp] call FADE_missionEnsureInfantryGroupLeader
};

// BLUFOR / friendly mission spawns: infantry-only classes + leader sanity check.
FADE_spawnFriendlyInfantryGroupAt = {
    params ["_pos", "_side", "_classes"];
    private _filtered = [_classes] call FADE_filterInfantryManClasses;
    if (_filtered isEqualTo []) then {
        private _fallback = +(missionNamespace getVariable ["FADE_fallbackFriendlyUnits", ["B_Soldier_F"]]);
        _filtered = [_fallback] call FADE_filterInfantryManClasses;
        // #region agent log
        diag_log format [
            "[FAC DbgBrowser 62d308] H19 friendlySpawn emptyPool fallbackCount=%1 side=%2",
            count _filtered, _side
        ];
        // #endregion
    };
    if (_filtered isEqualTo []) exitWith { grpNull };
    private _grp = [_pos, _side, _filtered] call FADE_missionCreateInfantryGroupAt;
    if (!isNull _grp) then {
        private _ldr = leader _grp;
        // #region agent log
        diag_log format [
            "[FAC DbgBrowser 62d308] H19 friendlySpawn ok count=%1 leader=%2 leaderIsMan=%3",
            count units _grp, if (isNull _ldr) then { "null" } else { typeOf _ldr }, if (isNull _ldr) then { false } else { _ldr isKindOf "Man" }
        ];
        // #endregion
    };
    _grp
};

// Skip ambient combat on water/invalid ATL (avoids BIS_fnc_position scalar spam in ACE console).
FADE_tryAmbientCombatAnim = {
    params ["_unit", ["_stance", "STAND"], ["_variant", "FULL"]];
    if (isNull _unit || { !alive _unit }) exitWith {};
    private _dryFn = missionNamespace getVariable ["FADE_surfaceIsDry", { params ["_p"]; count _p >= 2 && { !surfaceIsWater [_p select 0, _p select 1] } }];
    private _p = getPosATL _unit;
    if (!(_p isEqualType []) || { count _p < 2 } || { !([_p] call _dryFn) }) exitWith {};
    [_unit, _stance, _variant, { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
};

// Cyclic patrol route around _center. Clears existing waypoints, sets group orders, adds MOVE + CYCLE.
FADE_missionApplyPatrolCycle = {
    params [
        "_grp",
        "_center",
        ["_minDist", 50],
        ["_maxDist", 180],
        ["_numWp", 4],
        ["_angleOffset", 0],
        ["_angleStep", 90],
        ["_behaviour", "SAFE"],
        ["_combatMode", "YELLOW"],
        ["_speedMode", "LIMITED"],
        ["_requireDry", true]
    ];
    if (isNull _grp || { ({ alive _x } count units _grp) == 0 }) exitWith { false };
    if (count _center < 2) exitWith { false };
    private _cx = _center select 0;
    private _cy = _center select 1;
    private _dryFn = missionNamespace getVariable ["FADE_surfaceIsDry", { true }];
    {
        if (alive _x) then {
            _x switchMove "";
            _x setUnitPos "AUTO";
        };
    } forEach units _grp;
    while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
    _grp setBehaviour _behaviour;
    _grp setCombatMode _combatMode;
    _grp setSpeedMode _speedMode;
    private _added = 0;
    for "_w" from 0 to (_numWp - 1) do {
        private _wpPos = [];
        private _fallback = [];
        for "_try" from 1 to 14 do {
            private _a = _angleOffset + _w * _angleStep + (random 40);
            private _d = _minDist + random ((_maxDist - _minDist) max 1);
            private _rough = [_cx + _d * (cos _a), _cy + _d * (sin _a), 0];
            _fallback = +_rough;
            _wpPos = [[_rough, 0, 12, 3, 1, 0.4, 0, [], _rough], _rough] call FADE_findSafePosArray;
            if (_wpPos isEqualType [] && { count _wpPos >= 2 }) then {
                if (!_requireDry || { [_wpPos] call _dryFn }) exitWith {};
            };
            _wpPos = [];
        };
        if (count _wpPos < 2) then { _wpPos = _fallback };
        if (count _wpPos >= 2) then {
            if (count _wpPos < 3) then { _wpPos = [(_wpPos select 0), (_wpPos select 1), 0] };
            private _wp = _grp addWaypoint [_wpPos, 20];
            _wp setWaypointType "MOVE";
            _wp setWaypointSpeed _speedMode;
            _wp setWaypointBehaviour _behaviour;
            _wp setWaypointCombatMode _combatMode;
            _added = _added + 1;
        };
    };
    if (_added > 0) then {
        private _cyc = _grp addWaypoint [waypointPosition [_grp, 0], 20];
        _cyc setWaypointType "CYCLE";
        true
    } else {
        false
    };
};

FADE_missionSpawnGuards = {
    params [
        "_center",
        "_count",
        "_enemyClasses",
        "_sideEnemy",
        "_taskId",
        ["_minDist", 12],
        ["_maxDist", 100],
        ["_cap", 20]
    ];
    private _spawned = 0;
    private _groups = [];
    private _dryPos = missionNamespace getVariable ["FADE_surfaceIsDry", { true }];
    private _scaleFn = missionNamespace getVariable ["FADE_scaleOpforCount", nil];
    private _scaledCount = _count;
    if (_scaleFn isEqualType {}) then {
        private _scaled = [_count, 1] call _scaleFn;
        if (_scaled isEqualType 0) then { _scaledCount = _scaled };
    };
    private _n = (_scaledCount min _cap) max 0;
    for "_g" from 0 to (_n - 1) do {
        if (_spawned >= _cap) exitWith {};
        private _guardPos = [];
        for "_tryG" from 1 to 16 do {
            _guardPos = [[_center, _minDist, _maxDist, 3, 1, 0.3, 0, [], _center], _center] call FADE_findSafePosArray;
            if (_guardPos isEqualType [] && { count _guardPos >= 2 } && { [_guardPos] call _dryPos }) exitWith {};
            _guardPos = [];
        };
        if (_guardPos isEqualType [] && { count _guardPos >= 2 }) then {
            if (count _guardPos < 3) then { _guardPos = [(_guardPos select 0), (_guardPos select 1), 0] };
            private _guardGrp = createGroup _sideEnemy;
            private _u = _guardGrp createUnit [selectRandom _enemyClasses, _guardPos, [], 0, "NONE"];
            if (!isNull _u) then {
                [_guardGrp] call FAC_applyEnemyScenarioToGroup;
                _u setPosATL _guardPos;
                _u setUnitPos "MIDDLE";
                [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                _groups pushBack _guardGrp;
                if (_taskId != "") then { [_taskId, _guardGrp] call FADE_missionEnt_registerGroup };
                _spawned = _spawned + 1;
            } else {
                deleteGroup _guardGrp;
            };
        };
    };
    _groups
};

// Optional field contact: enemy groups in a ring around pickup (CASEVAC, Troop Extract, etc.).
FADE_mission_spawnFieldContactEnemies = {
    params [
        "_atPos",
        "_basePos",
        "_enemyUnits",
        "_sideEnemy",
        "_taskId",
        "_scaleOpforCount",
        ["_contactChance", 0.5],
        ["_groupsBase", 1],
        ["_groupsRand", 5],
        ["_grpSizeMin", 3],
        ["_grpSizeRand", 5],
        ["_minDistFromBase", 1000],
        ["_registerEach", false],
        ["_useScenarioSpawn", false]
    ];
    private _groups = [];
    if (count _enemyUnits == 0) exitWith { _groups };
    if (random 1 >= _contactChance) exitWith { _groups };

    private _spawnEnemyGrp = missionNamespace getVariable ["FADE_spawnEnemyGroupAt", BIS_fnc_spawnGroup];
    private _ensureDry = missionNamespace getVariable ["FADE_ensureDryLandPos", {}];
    private _numEnemyGroups = [_groupsBase + floor random _groupsRand, 1] call _scaleOpforCount;

    for "_g" from 0 to (_numEnemyGroups - 1) do {
        private _grpPos = [];
        for "_try" from 0 to 10 do {
            private _dist = 500 + random 1500;
            private _candidate = _atPos getPos [_dist, random 360];
            _candidate = [[_candidate, 0, 30, 3, 1, 0.4, 0, [], _candidate], _candidate] call FADE_findSafePosArray;
            if (count _candidate < 2) then { _candidate = _atPos getPos [_dist, random 360] };
            if ((_candidate distance _basePos) >= _minDistFromBase) exitWith { _grpPos = _candidate };
        };
        if (count _grpPos < 2) then {
            _grpPos = _atPos getPos [800, (_atPos getDir _basePos) + 180];
        };
        if (!(_ensureDry isEqualTo {})) then { _grpPos = [_grpPos, _atPos] call _ensureDry };

        private _grpSize = [_grpSizeMin + floor random _grpSizeRand, 2] call _scaleOpforCount;
        private _shuffled = _enemyUnits call BIS_fnc_arrayShuffle;
        private _grpUnits = (_shuffled select [0, _grpSize min count _shuffled]);
        if (count _grpUnits == 0) then { _grpUnits = [_enemyUnits select 0] };

        private _grp = if (_useScenarioSpawn) then {
            [_grpPos, _sideEnemy, _grpUnits, _atPos] call _spawnEnemyGrp
        } else {
            [_grpPos, _sideEnemy, _grpUnits] call BIS_fnc_spawnGroup
        };
        [_grp] call FAC_applyEnemyScenarioToGroup;
        _grp setBehaviour "AWARE";
        _grp setCombatMode "RED";
        _grp addWaypoint [_atPos, 0];
        if (_registerEach && { _taskId != "" }) then {
            [_taskId, _grp] call FADE_missionEnt_registerGroup;
        };
        _groups pushBack _grp;
    };

    if (count _groups > 0) then {
        [_groups, _basePos] call FADE_registerEnemyRetreat;
    };
    _groups
};

// Single hollow ring (Border brush only — no fill, no companion _outer marker).
FADE_mission_radiusBorderThick = {
    missionNamespace getVariable ["FADE_missionRadiusBorderThick", 40]
};

FADE_mission_setRadiusMarkerColor = {
    params ["_markerName", "_color"];
    if (_markerName == "" || { markerShape _markerName == "" }) exitWith {};
    _markerName setMarkerColor _color;
};

FADE_mission_setRadiusMarkerGeometry = {
    params ["_markerName", "_center", "_radiusM"];
    if (_markerName == "" || { _radiusM <= 0 } || { markerShape _markerName == "" }) exitWith {};
    private _centerN = [_center] call FADE_normPos3;
    _markerName setMarkerPos _centerN;
    _markerName setMarkerSize [_radiusM, _radiusM];
};

// Centroid of 2D positions (ATL Z flattened to 0).
FADE_mission_positionsCentroid = {
    params [["_positions", []]];
    if (_positions isEqualTo []) exitWith { [0, 0, 0] };
    private _sumX = 0;
    private _sumY = 0;
    {
        if (_x isEqualType [] && { count _x >= 2 }) then {
            _sumX = _sumX + (_x select 0);
            _sumY = _sumY + (_x select 1);
        };
    } forEach _positions;
    private _n = count _positions max 1;
    [(_sumX / _n), (_sumY / _n), 0]
};

// Marker icon + search circle share one centre; icon is jittered from anchor; radius fits all mustContain points.
FADE_mission_computeSearchZone = {
    params [
        "_anchorPos",
        ["_nominalRadiusM", 55],
        ["_jitterMaxM", -1],
        ["_mustContain", []],
        ["_edgeMarginM", -1]
    ];
    private _anchorN = [_anchorPos] call FADE_normPos3;
    private _jitterM = if (_jitterMaxM < 0) then {
        missionNamespace getVariable ["FADE_missionMarkerJitterM", 25]
    } else {
        _jitterMaxM max 0
    };
    private _marginM = if (_edgeMarginM < 0) then {
        missionNamespace getVariable ["FADE_missionSearchZoneEdgeMarginM", 15]
    } else {
        _edgeMarginM max 0
    };
    private _mkrFn = missionNamespace getVariable ["FADE_jitterMarkerPos", { params [["_p", [0, 0, 0]]]; [_p] call FADE_normPos3 }];
    private _markerPos = if (_jitterM > 0) then {
        [_anchorN, _jitterM] call _mkrFn
    } else {
        +_anchorN
    };
    private _points = [+_anchorN];
    {
        if (_x isEqualType [] && { count _x >= 2 }) then {
            _points pushBack ([_x] call FADE_normPos3);
        };
    } forEach _mustContain;
    private _maxSpan = 0;
    {
        _maxSpan = _maxSpan max (_markerPos distance2D _x);
    } forEach _points;
    private _displayRadius = (_nominalRadiusM max (_maxSpan + _marginM));
    [_markerPos, _displayRadius]
};

// Delete grid search-zone marker and any legacy per-cell markers from older builds.
FADE_mission_deleteGridZoneMarkers = {
    params ["_zoneMarkerName", ["_markerNames", []]];
    if (_zoneMarkerName == "") exitWith {};
    [_zoneMarkerName] call FADE_deleteMarkerSafe;
    {
        if (_x find (_zoneMarkerName + "_") == 0) then {
            [_x] call FADE_deleteMarkerSafe;
        };
    } forEach allMapMarkers;
    if (_markerNames isEqualType []) then {
        {
            if (_x isEqualType "" && { _x != _zoneMarkerName }) then {
                if (_x find (_zoneMarkerName + "_") == 0) then {
                    [_x] call FADE_deleteMarkerSafe;
                };
            };
        } forEach _markerNames;
    };
};

// Single map-grid-aligned rectangle for a search zone (shrinks via field intel by recomputing bounds).
FADE_mission_createGridZoneMarkers = {
    params [
        "_taskId",
        "_zoneMarkerName",
        "_center",
        "_radiusM",
        ["_markerColor", "ColorEAST"],
        ["_mustInclude", []],
        ["_alpha", -1]
    ];
    if (_zoneMarkerName == "") exitWith { [] };
    private _boundsFn = missionNamespace getVariable ["FADE_map_gridBoundsForSearchZone", {}];
    if (_boundsFn isEqualTo {}) exitWith { [] };
    private _bounds = [_center, _radiusM, _mustInclude] call _boundsFn;
    _bounds params ["_centre", "_halfSize", "_cellCount"];
    if (_cellCount < 1) exitWith { [] };
    private _zoneAlpha = if (_alpha < 0) then {
        missionNamespace getVariable ["FADE_missionGridZoneAlpha", 0.35]
    } else {
        _alpha
    };
    {
        if (_x find (_zoneMarkerName + "_") == 0) then {
            [_x] call FADE_deleteMarkerSafe;
        };
    } forEach allMapMarkers;
    private _m = if (getMarkerColor _zoneMarkerName != "") then {
        _zoneMarkerName setMarkerPos _centre;
        _zoneMarkerName
    } else {
        [_zoneMarkerName, _centre, _taskId] call FADE_createRegisteredMarker
    };
    _m setMarkerShape "RECTANGLE";
    _m setMarkerSize _halfSize;
    _m setMarkerBrush "SolidBorder";
    _m setMarkerColor _markerColor;
    _m setMarkerAlpha _zoneAlpha;
    [_zoneMarkerName]
};

// Hollow ellipse border for mission search / completion radii (one marker, no fill).
FADE_mission_createRadiusMarker = {
    params [
        "_taskId",
        "_markerName",
        "_center",
        "_radiusM",
        ["_markerColor", "ColorEAST"],
        ["_alpha", -1]
    ];
    if (_markerName == "" || { _radiusM <= 0 }) exitWith { "" };
    private _centerN = [_center] call FADE_normPos3;
    private _ringAlpha = if (_alpha < 0) then {
        missionNamespace getVariable ["FADE_missionRadiusMarkerAlpha", 1]
    } else {
        _alpha
    };
    private _zoneMarker = [_markerName, _centerN, _taskId] call FADE_createRegisteredMarker;
    _zoneMarker setMarkerShape "ELLIPSE";
    _zoneMarker setMarkerSize [_radiusM, _radiusM];
    _zoneMarker setMarkerBrush "Border";
    _zoneMarker setMarkerColor _markerColor;
    _zoneMarker setMarkerAlpha _ringAlpha;
    _markerName
};

// Zone marker: one grid-aligned search rectangle (or ellipse) + centred objective icon. Returns
// [_iconMarker, _zoneMarkerName, _markerPos, _displayRadius, _gridMarkerNames].
FADE_mission_createObjectiveMarker = {
    params [
        "_taskId",
        "_markerBaseName",
        "_anchorPos",
        ["_nominalZoneRadius", 0],
        ["_markerColor", "ColorEAST"],
        ["_markerType", "mil_objective"],
        ["_markerText", ""],
        ["_jitterMaxM", -1],
        ["_zoneAlpha", -1],
        ["_mustContain", []],
        ["_searchMode", ""]
    ];
    private _mode = _searchMode;
    if (_mode == "") then {
        _mode = missionNamespace getVariable ["FADE_missionSearchZoneMode", "grid"];
    };
    private _markerPosN = [_anchorPos] call FADE_normPos3;
    private _zoneRadius = _nominalZoneRadius;
    private _gridNames = [];
    private _zoneName = "";
    if (_nominalZoneRadius > 0) then {
        private _computed = [_anchorPos, _nominalZoneRadius, _jitterMaxM, _mustContain] call FADE_mission_computeSearchZone;
        _computed params ["_markerPosN", "_zoneRadius"];
    } else {
        if (_jitterMaxM != 0) then {
            private _jitterM = if (_jitterMaxM < 0) then {
                missionNamespace getVariable ["FADE_missionMarkerJitterM", 25]
            } else {
                _jitterMaxM
            };
            if (_jitterM > 0) then {
                private _mkrFn = missionNamespace getVariable ["FADE_jitterMarkerPos", { params [["_p", [0, 0, 0]]]; [_p] call FADE_normPos3 }];
                _markerPosN = [_markerPosN, _jitterM] call _mkrFn;
            };
        };
    };
    if (_nominalZoneRadius > 0) then {
        if (_mode == "grid") then {
            _zoneName = _markerBaseName + "_grid";
            _gridNames = [_taskId, _zoneName, _markerPosN, _zoneRadius, _markerColor, _mustContain, _zoneAlpha] call FADE_mission_createGridZoneMarkers;
        } else {
            _zoneName = _markerBaseName + "_zone";
            [_taskId, _zoneName, _markerPosN, _zoneRadius, _markerColor, _zoneAlpha] call FADE_mission_createRadiusMarker;
        };
    };
    private _iconType = _markerType;
    if (_markerType in (keys (missionNamespace getVariable ["FADE_marker_typeMap", createHashMap]))) then {
        _iconType = [_markerType] call FADE_marker_getType;
    };
    private _icon = [_markerBaseName, _markerPosN, _taskId] call FADE_createRegisteredMarker;
    _icon setMarkerType _iconType;
    _icon setMarkerColor _markerColor;
    if (_markerText != "") then { _icon setMarkerText _markerText };
    [_markerBaseName, _zoneName, _markerPosN, _zoneRadius, _gridNames]
};

// Cargo camp delayed despawn (success / fail / timeout paths).
FADE_cargo_cleanupSiteDeferred = {
    params [["_campObjects", []], ["_garrisonGroup", grpNull], ["_cargo", objNull], ["_patrolGroups", []], ["_delay", 60]];
    [_campObjects, _garrisonGroup, _cargo, _patrolGroups, _delay] spawn {
        params ["_campObjects", "_garrisonGroup", "_cargo", "_pgGrps", "_delay"];
        sleep _delay;
        { if (!isNull _x) then { deleteVehicle _x } } forEach _campObjects;
        if (!isNull _garrisonGroup) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach units _garrisonGroup;
            deleteGroup _garrisonGroup;
        };
        if (!isNull _cargo) then { deleteVehicle _cargo };
        {
            if (!isNull _x) then {
                { if (!isNull _x) then { deleteVehicle _x } } forEach units _x;
                deleteGroup _x;
            };
        } forEach _pgGrps;
    };
};

missionNamespace setVariable ["FADE_vg_registerMissionSite", FADE_vg_registerMissionSite];
missionNamespace setVariable ["FADE_spawnEnemyGroupAt", FADE_spawnEnemyGroupAt];
missionNamespace setVariable ["FADE_createEnemyUnitAt", FADE_createEnemyUnitAt];
missionNamespace setVariable ["FADE_missionEnsureInfantryGroupLeader", FADE_missionEnsureInfantryGroupLeader];
missionNamespace setVariable ["FADE_missionCreateInfantryGroupAt", FADE_missionCreateInfantryGroupAt];
missionNamespace setVariable ["FADE_spawnFriendlyInfantryGroupAt", FADE_spawnFriendlyInfantryGroupAt];
missionNamespace setVariable ["FADE_tryAmbientCombatAnim", FADE_tryAmbientCombatAnim];
missionNamespace setVariable ["FADE_missionApplyPatrolCycle", FADE_missionApplyPatrolCycle];
missionNamespace setVariable ["FADE_missionSpawnGuards", FADE_missionSpawnGuards];
missionNamespace setVariable ["FADE_mission_spawnFieldContactEnemies", FADE_mission_spawnFieldContactEnemies];
missionNamespace setVariable ["FADE_mission_radiusBorderThick", FADE_mission_radiusBorderThick];
missionNamespace setVariable ["FADE_mission_setRadiusMarkerColor", FADE_mission_setRadiusMarkerColor];
missionNamespace setVariable ["FADE_mission_setRadiusMarkerGeometry", FADE_mission_setRadiusMarkerGeometry];
missionNamespace setVariable ["FADE_mission_positionsCentroid", FADE_mission_positionsCentroid];
missionNamespace setVariable ["FADE_mission_computeSearchZone", FADE_mission_computeSearchZone];
missionNamespace setVariable ["FADE_mission_deleteGridZoneMarkers", FADE_mission_deleteGridZoneMarkers];
missionNamespace setVariable ["FADE_mission_createGridZoneMarkers", FADE_mission_createGridZoneMarkers];
missionNamespace setVariable ["FADE_mission_createRadiusMarker", FADE_mission_createRadiusMarker];
missionNamespace setVariable ["FADE_mission_createObjectiveMarker", FADE_mission_createObjectiveMarker];
missionNamespace setVariable ["FADE_cargo_cleanupSiteDeferred", FADE_cargo_cleanupSiteDeferred];
