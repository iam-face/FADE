// MissionInvasionHelpers.sqf - zone pick, push, spawn helpers
if (!isServer) exitWith {};
FADE_invasion_pickZones = {
    params ["_civCandidates", "_wantN", ["_mapAnchor", []]];
    if (count _civCandidates == 0) exitWith { [] };

    private _fnc_entryPos = {
        params ["_entry"];
        [_entry select 1] call FADE_normPos3
    };

    private _invasionZone = [];
    if ([_mapAnchor] call FADE_fnc_isValidMapClickPos) then {
        private _byClick = [_civCandidates, [], { _mapAnchor distance2D ([_x] call _fnc_entryPos) }, "ASCEND"] call BIS_fnc_sortBy;
        if (count _byClick > 0) then { _invasionZone = _byClick select 0 };
    } else {
        private _ws = worldSize;
        private _corners = [[0, 0, 0], [_ws, 0, 0], [0, _ws, 0], [_ws, _ws, 0]];

        private _cornerPicks = [];
        {
            private _corner = _x;
            private _best = [];
            private _bestD = 1e15;
            {
                private _d = _corner distance2D ([_x] call _fnc_entryPos);
                if (_d < _bestD) then { _bestD = _d; _best = _x };
            } forEach _civCandidates;
            if (count _best >= 2) then { _cornerPicks pushBack _best };
        } forEach _corners;
        if (count _cornerPicks > 0) then { _invasionZone = selectRandom _cornerPicks };
    };
    if (count _invasionZone == 0) exitWith { [] };

    private _remaining = _civCandidates - [_invasionZone];
    if (count _remaining == 0) exitWith { [_invasionZone] };

    private _pool = [_remaining, [], { ([_invasionZone] call _fnc_entryPos) distance2D ([_x] call _fnc_entryPos) }, "ASCEND"] call BIS_fnc_sortBy;
    private _take = ((_wantN - 1) max 0) min count _pool;
    [_invasionZone] + (_pool select [0, _take])
};

FADE_invasion_getPushTargetIdx = {
    params ["_held", "_zones", "_invasionCenter"];
    private _candidates = [];
    for "_i" from 1 to (count _zones - 1) do {
        if (_held select _i) then { _candidates pushBack _i };
    };
    if (_candidates isEqualTo []) exitWith { -1 };
    ([_candidates, [], { _invasionCenter distance2D (_zones select _x) }, "ASCEND"] call BIS_fnc_sortBy) select 0
};

// FADE_getEnemyAirVehicleClasses + FADE_opforAir_fallbackHeliClasses (faction-safe transport pick).
FADE_invasion_pickTransportHeliClass = {
    private _air = call FADE_getEnemyAirVehicleClasses;
    if (_air isEqualTo []) then {
        _air = FADE_opforAir_fallbackHeliClasses select { isClass (configFile >> "CfgVehicles" >> _x) };
    };
    private _helis = _air select { _x isKindOf "Helicopter" };
    if (_helis isEqualTo []) exitWith { "" };
    _helis = [_helis, [], {
        getNumber (configFile >> "CfgVehicles" >> _x >> "transportSoldier")
    }, "DESCEND"] call BIS_fnc_sortBy;
    private _topN = (count _helis) min 3;
    selectRandom (_helis select [0, _topN])
};

FADE_invasion_findSpawnPos = {
    params ["_zoneCenter", "_zoneRadius"];
    private _zc = [_zoneCenter] call FADE_normPos3;
    private _angle = random 360;
    private _dist = random (_zoneRadius * 0.85);
    private _sp = [(_zc select 0) + _dist * cos _angle, (_zc select 1) + _dist * sin _angle, 0];
    _sp = [[_sp, 0, 25, 3, 1, 0.4, 0, [], _sp], _zc] call FADE_findSafePosArray;
    if (count _sp < 2) then { _sp = _zc };
    if (count _sp < 3) then { _sp = [(_sp select 0), (_sp select 1), 0] };
    _sp
};

FADE_invasion_assignPushWp = {
    params ["_grp", "_targetCenter", "_zoneRadius"];
    if (isNull _grp) exitWith {};
    while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
    private _wp1 = _grp addWaypoint [_targetCenter, 0];
    _wp1 setWaypointType "MOVE";
    _wp1 setWaypointCompletionRadius (15 + _zoneRadius * 0.12);
    private _wp2 = _grp addWaypoint [_targetCenter, 0];
    _wp2 setWaypointType "SAD";
    _grp setBehaviour "AWARE";
    _grp setCombatMode "RED";
};

FADE_invasion_spawnGroundSquad = {
    params ["_taskId", "_spawnPos", "_targetCenter", "_enemyUnits", "_facApply", "_sideEnemy", "_scaleOpforCount", "_zoneRadius"];
    private _ps = [4 + floor random 3, 2] call _scaleOpforCount;
    private _shuf = _enemyUnits call BIS_fnc_arrayShuffle;
    private _classes = _shuf select [0, _ps min count _shuf];
    if (count _classes == 0) then { _classes = [_enemyUnits select 0] };
    private _grp = [_spawnPos, _sideEnemy, _classes] call BIS_fnc_spawnGroup;
    if (isNull _grp || { count units _grp == 0 }) exitWith { grpNull };
    if (!(_facApply isEqualTo {})) then { [_grp] call _facApply };
    [_grp, _targetCenter, _zoneRadius] call FADE_invasion_assignPushWp;
    [_taskId, _grp] call FADE_missionEnt_registerGroup;
    private _pushGroups = missionNamespace getVariable ["FADE_invasionPushGroups_" + _taskId, []];
    _pushGroups pushBack _grp;
    missionNamespace setVariable ["FADE_invasionPushGroups_" + _taskId, _pushGroups];
    _grp
};

FADE_invasion_makePushVeh = {
    params ["_spawnPos", "_targetCenter", "_enemyUnits", "_facApply", "_existingVehs", "_zoneRadius"];
    private _sp = _spawnPos;
    if (count _sp < 2) then { _sp = [0, 0, 0] };
    if (count _sp < 3) then { _sp = [(_sp select 0), (_sp select 1), 0] };
    private _roadHit = [_sp, 450, _existingVehs, -1, [], _targetCenter] call FADE_findOpforGroundVehicleRoadSpawn;
    if (_roadHit isEqualTo []) exitWith { [objNull, grpNull, grpNull] };
    _roadHit params ["_roadSp", "_vehDir"];
    private _sideE = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _vehClasses = missionNamespace getVariable ["FADE_enemyVehicles", []];
    if (_vehClasses isEqualTo []) then {
        private _ef = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
        if (!isNil "FADE_getEnemyVehiclesForFaction") then {
            _vehClasses = [_ef] call FADE_getEnemyVehiclesForFaction;
        };
    };
    private _land = _vehClasses select {
        !(_x isKindOf "Air") && { !(_x isKindOf "Ship") } && { !(_x isKindOf "StaticWeapon") }
    };
    private _filter = missionNamespace getVariable ["FADE_counterAttack_filterClassesByMinCargo", nil];
    private _pick = if ((typeName _filter == "CODE") && { count _land > 0 }) then { [_land, 2] call _filter } else { _land };
    if (count _pick == 0) then { _pick = _land };
    if (count _pick == 0) exitWith { [objNull, grpNull, grpNull] };
    private _vClass = selectRandom _pick;
    private _veh = createVehicle [_vClass, _roadSp, [], 0, "NONE"];
    if (isNull _veh) exitWith { [objNull, grpNull, grpNull] };
    _veh setPosATL _roadSp;
    _veh setDir _vehDir;
    _veh setVectorUp surfaceNormal _roadSp;
    private _vehGrp = createGroup _sideE;
    private _driver = _vehGrp createUnit [selectRandom _enemyUnits, _roadSp, [], 0, "NONE"];
    if (!isNull _driver) then {
        _driver moveInDriver _veh;
        _vehGrp selectLeader _driver;
    };
    if (_veh emptyPositions "gunner" > 0) then {
        private _g = _vehGrp createUnit [selectRandom _enemyUnits, _roadSp, [], 0, "NONE"];
        if (!isNull _g) then { _g moveInGunner _veh };
    };
    if (!(_facApply isEqualTo {})) then { [_vehGrp] call _facApply };
    _vehGrp setBehaviour "AWARE";
    _vehGrp setCombatMode "RED";
    private _cargoGrp = grpNull;
    private _seats = (_veh emptyPositions "cargo") max 0;
    if (_seats > 0) then {
        _cargoGrp = createGroup _sideE;
        for "_c" from 0 to (_seats - 1) do {
            private _u = _cargoGrp createUnit [selectRandom _enemyUnits, _roadSp, [], 0, "NONE"];
            if (!isNull _u) then { _u moveInCargo _veh };
        };
        if (!(_facApply isEqualTo {})) then { [_cargoGrp] call _facApply };
    };
    [_veh, _enemyUnits] call FADE_ensureEnemyVehicleGunner;
    _veh setVariable ["FADE_invPushVeh", true, false];
    while { count waypoints _vehGrp > 0 } do { deleteWaypoint [_vehGrp, 0] };
    private _wpM = _vehGrp addWaypoint [_targetCenter, 0];
    _wpM setWaypointType "MOVE";
    _wpM setWaypointCompletionRadius (15 + _zoneRadius * 0.12);
    private _wpS = _vehGrp addWaypoint [_targetCenter, 0];
    _wpS setWaypointType "SAD";
    _veh engineOn true;
    [_veh, _vehGrp, _cargoGrp]
};

// Static HMG/GMG ring at the invasion beachhead (3–5); faces BLUFOR approach from base.
FADE_invasion_spawnBeachheadTurrets = {
    params ["_taskId", "_center", "_zoneRadius", "_facePos", "_enemyUnits", "_sideEnemy", "_facApply"];
    private _enemyFaction = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
    private _turretClass = "";
    if (!isNil "FADE_aaa_getStaticLightClass") then { _turretClass = [_enemyFaction] call FADE_aaa_getStaticLightClass };
    if (!isClass (configFile >> "CfgVehicles" >> _turretClass)) exitWith {};
    private _tMin = missionNamespace getVariable ["FADE_invasionBeachheadTurretsMin", 3];
    private _tMax = missionNamespace getVariable ["FADE_invasionBeachheadTurretsMax", 5];
    private _tSpan = (_tMax - _tMin) max 0;
    private _numT = _tMin + floor random (_tSpan + 1);
    private _face = if (count _facePos >= 2) then { [_facePos] call FADE_normPos3 } else { _center };
    private _baseDir = random 360;
    for "_t" from 0 to (_numT - 1) do {
        private _bearing = _baseDir + ((_t / (_numT max 1)) * 360) + ((random 36) - 18);
        private _dist = 40 + random ((_zoneRadius * 0.8 - 40) max 30);
        private _turretPos = [_center, _dist, _bearing] call BIS_fnc_relPos;
        _turretPos = [[_turretPos, 0, 12, 2, 1, 0.35, 0, [], _turretPos], _turretPos] call FADE_findSafePosArray;
        if (!(_turretPos isEqualType []) || { count _turretPos < 2 }) then { _turretPos = [_center, _dist, _bearing] call BIS_fnc_relPos };
        if (count _turretPos < 3) then { _turretPos set [2, 0] };
        private _turret = createVehicle [_turretClass, _turretPos, [], 0, "NONE"];
        if (isNull _turret) then { continue };
        _turret setPosATL _turretPos;
        _turret setDir ((getPosATL _turret) getDir _face);
        [_taskId, _turret] call FADE_missionEnt_registerObject;
        private _grp = createGroup _sideEnemy;
        private _gunner = _grp createUnit [selectRandom _enemyUnits, _turretPos, [], 0, "NONE"];
        if (isNull _gunner) then {
            deleteVehicle _turret;
            deleteGroup _grp;
        } else {
            _gunner moveInGunner _turret;
            if (!(_facApply isEqualTo {})) then { [_grp] call _facApply };
            _grp setBehaviour "COMBAT";
            _grp setCombatMode "RED";
            [_taskId, _grp] call FADE_missionEnt_registerGroup;
            [_turret, _taskId] spawn {
                params ["_turret", "_taskId"];
                private _sideFriendly = missionNamespace getVariable ["FADE_sideFriendly", west];
                sleep 10;
                if (!alive _turret || { missionNamespace getVariable ["FADE_invasionAborted_" + _taskId, false] }) exitWith {};
                private _blu = (_turret nearEntities ["Man", 2500]) select { side _x == _sideFriendly && { alive _x } };
                if (_blu isEqualTo []) exitWith {};
                private _nearest = objNull;
                private _minDist = 1e10;
                { private _d = _turret distance _x; if (_d < _minDist) then { _minDist = _d; _nearest = _x } } forEach _blu;
                if (isNull _nearest) exitWith {};
                _turret setDir ((getPosATL _turret) getDir (getPosATL _nearest));
                private _gn = gunner _turret;
                if (!isNull _gn && { alive _gn }) then { _gn doWatch _nearest };
            };
        };
    };
};

// One OPFOR vehicle holding the beachhead (road spawn near zone centre; HOLD waypoint).
FADE_invasion_spawnBeachheadVehicle = {
    params ["_taskId", "_center", "_zoneRadius", "_facePos", "_enemyUnits", "_facApply"];
    private _sideE = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _face = if (count _facePos >= 2) then { [_facePos] call FADE_normPos3 } else { _center };
    private _roadHit = [_center, _zoneRadius, [], -1, [], _face] call FADE_findOpforGroundVehicleRoadSpawn;
    if (_roadHit isEqualTo []) exitWith {};
    _roadHit params ["_roadSp", "_vehDir"];
    private _vehClasses = missionNamespace getVariable ["FADE_enemyVehicles", []];
    if (_vehClasses isEqualTo []) then {
        private _ef = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
        if (!isNil "FADE_getEnemyVehiclesForFaction") then {
            _vehClasses = [_ef] call FADE_getEnemyVehiclesForFaction;
        };
    };
    private _land = _vehClasses select {
        !(_x isKindOf "Air") && { !(_x isKindOf "Ship") } && { !(_x isKindOf "StaticWeapon") }
    };
    private _filter = missionNamespace getVariable ["FADE_counterAttack_filterClassesByMinCargo", nil];
    private _pick = if ((typeName _filter == "CODE") && { count _land > 0 }) then { [_land, 1] call _filter } else { _land };
    if (count _pick == 0) then { _pick = _land };
    if (count _pick == 0) exitWith {};
    private _vClass = selectRandom _pick;
    private _veh = createVehicle [_vClass, _roadSp, [], 0, "NONE"];
    if (isNull _veh) exitWith {};
    _veh setPosATL _roadSp;
    _veh setDir _vehDir;
    _veh setVectorUp surfaceNormal _roadSp;
    private _vehGrp = createGroup _sideE;
    private _driver = _vehGrp createUnit [selectRandom _enemyUnits, _roadSp, [], 0, "NONE"];
    if (isNull _driver) then {
        deleteVehicle _veh;
        deleteGroup _vehGrp;
    } else {
        _driver moveInDriver _veh;
        _vehGrp selectLeader _driver;
        if (_veh emptyPositions "gunner" > 0) then {
            private _g = _vehGrp createUnit [selectRandom _enemyUnits, _roadSp, [], 0, "NONE"];
            if (!isNull _g) then { _g moveInGunner _veh };
        };
        if (!(_facApply isEqualTo {})) then { [_vehGrp] call _facApply };
        [_veh, _enemyUnits] call FADE_ensureEnemyVehicleGunner;
        _vehGrp setBehaviour "COMBAT";
        _vehGrp setCombatMode "RED";
        private _wp = _vehGrp addWaypoint [_center, 0];
        _wp setWaypointType "HOLD";
        _wp setWaypointCompletionRadius (_zoneRadius * 0.5);
        _veh engineOn true;
        [_taskId, _veh] call FADE_missionEnt_registerVehicle;
        [_taskId, _vehGrp] call FADE_missionEnt_registerGroup;
    };
};

// Climb out, fly away from the LZ, despawn when clear of all players.
FADE_invasion_heliDepartDespawn = {
    params ["_veh", "_heliGrp", "_lz", "_heliApproach"];
    if (isNull _veh || { !alive _veh } || { isNull _heliGrp }) exitWith {};

    private _despawnDist = missionNamespace getVariable ["FADE_invasionHeliDespawnDist", 2000];
    private _bear = random 360;

    while { count waypoints _heliGrp > 0 } do { deleteWaypoint [_heliGrp, 0] };
    _veh engineOn true;
    _heliGrp setBehaviour "CARELESS";
    _heliGrp setCombatMode "BLUE";

    private _climb = [_lz, 300 + random 200, _bear] call BIS_fnc_relPos;
    _climb set [2, (getTerrainHeightASL _climb) + 80 + random 40];
    _veh flyInHeight 80;
    private _wpClimb = _heliGrp addWaypoint [_climb, 0];
    _wpClimb setWaypointType "MOVE";
    _wpClimb setWaypointSpeed "NORMAL";

    private _climbTimeout = time + 90;
    waitUntil {
        sleep 1;
        isNull _veh || { !alive _veh }
        || { !(isTouchingGround _veh) && { (getPosATL _veh select 2) > (getTerrainHeightASL _lz) + 20 } }
        || { time > _climbTimeout }
    };
    if (isNull _veh || { !alive _veh }) exitWith {};

    private _departDist = (_heliApproach * 0.85) max _despawnDist;
    private _depart = [_lz, _departDist, _bear] call BIS_fnc_relPos;
    _depart set [2, (getTerrainHeightASL _depart) + 120 + random 60];
    while { count waypoints _heliGrp > 0 } do { deleteWaypoint [_heliGrp, 0] };
    _veh flyInHeight 120;
    private _wpOut = _heliGrp addWaypoint [_depart, 0];
    _wpOut setWaypointType "MOVE";
    _wpOut setWaypointSpeed "NORMAL";

    private _despawnTimeout = time + 600;
    waitUntil {
        sleep 2;
        isNull _veh || { !alive _veh }
        || {
            private _vp = getPosATL _veh;
            private _minPl = 1e10;
            {
                _minPl = _minPl min (_vp distance2D _x);
            } forEach ([] call FADE_getAlivePlayerPositions);
            _minPl >= _despawnDist
        }
        || { time > _despawnTimeout }
    };

    if (!isNull _heliGrp) then {
        { if (!isNull _x) then { deleteVehicle _x } } forEach units _heliGrp;
        deleteGroup _heliGrp;
    };
    if (!isNull _veh) then { deleteVehicle _veh };
};

// Force scenario OPFOR air on for Invasion; restore previous setting when mission ends.
FADE_invasion_applyOpforAir = {
    if !(isServer) exitWith {};
    if (!isNil { missionNamespace getVariable "FADE_invasion_savedOpforAirSetting" }) exitWith {};
    private _saved = missionNamespace getVariable ["FADE_opforAirSetting", "Off"];
    missionNamespace setVariable ["FADE_invasion_savedOpforAirSetting", _saved];
    private _forced = missionNamespace getVariable ["FADE_invasionOpforAirSetting", "Low"];
    private _effective = if (_saved == "Off") then { _forced } else { _saved };
    if (_effective == "Off") exitWith {};
    missionNamespace setVariable ["FADE_opforAirSetting", _effective, true];
    missionNamespace setVariable ["FAC_scenarioGui_opforAir", _effective, true];
};

FADE_invasion_restoreOpforAir = {
    if !(isServer) exitWith {};
    private _saved = missionNamespace getVariable ["FADE_invasion_savedOpforAirSetting", nil];
    if (isNil "_saved") exitWith {};
    missionNamespace setVariable ["FADE_opforAirSetting", _saved, true];
    missionNamespace setVariable ["FAC_scenarioGui_opforAir", _saved, true];
    missionNamespace setVariable ["FADE_invasion_savedOpforAirSetting", nil];
    if (_saved == "Off" && {!isNil "FADE_opforAir_despawnAll"}) then { call FADE_opforAir_despawnAll };
};

