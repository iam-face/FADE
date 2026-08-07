// ServerBootstrapOpforDrones.sqf — ambient OPFOR UAV patrol / ISR + QRF vectoring (server)
// Setting: FADE_opforDroneSetting Off | Low | Normal | High (see FADE_opforDroneIntensity in Config.sqf)

if (!isServer) exitWith {};

missionNamespace setVariable ["FADE_opforDrone_active", []];
missionNamespace setVariable ["FADE_opforDrone_lastSpawnTime", -1e9];
missionNamespace setVariable ["FADE_opforDrone_lastQrfTime", -1e9];
missionNamespace setVariable ["FADE_opforDrone_qrfGroups", []];
missionNamespace setVariable ["FADE_opforDrone_spotThreshold", 1.25];

FADE_opforDrone_fallbackClasses = [
    "O_UAV_01_F",
    "O_UAV_06_F",
    "O_T_UAV_04_CAS_backpack_F",
    "I_UAV_01_F",
    "I_UAV_06_F",
    "B_UAV_01_F",
    "B_UAV_06_F"
];

// Faction-matched UAV only (FADE_heliClasses + CfgVehicles). No side-wide scrape — that
// pulls unrelated mod packs. Empty → FADE_opforDrone_pickClass uses FADE_opforDrone_fallbackClasses.
FADE_getEnemyDroneVehicleClasses = {
    private _cached = missionNamespace getVariable ["FADE_enemyDroneVehicleClasses_cache", []];
    if (count _cached > 0) exitWith { +_cached };
    private _faction = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
    private _wantSide = missionNamespace getVariable ["FADE_scenarioEnemySideNum", 0];
    if (_faction == "") exitWith { [] };

    private _isDroneClass = {
        params ["_c"];
        private _cl = toLower _c;
        if (_cl find "backpack" >= 0) exitWith { false };
        if (_cl find "static" >= 0) exitWith { false };
        if (_cl find "portable" >= 0) exitWith { false };
        if (_cl find "ugv" >= 0) exitWith { false };
        (_c isKindOf "UAV") || { _cl find "uav" >= 0 } || { _cl find "drone" >= 0 }
    };

    private _out = [];
    {
        private _c = _x;
        if !([_c] call _isDroneClass) then { continue };
        private _cfg = configFile >> "CfgVehicles" >> _c;
        if (getText (_cfg >> "faction") == _faction && { getNumber (_cfg >> "side") == _wantSide }) then {
            _out pushBack _c;
        };
    } forEach (missionNamespace getVariable ["FADE_heliClasses", []]);

    if (count _out == 0) then {
        {
            private _c = configName _x;
            if !([_c] call _isDroneClass) then { continue };
            if (getNumber (_x >> "side") != _wantSide) then { continue };
            if (getText (_x >> "faction") == _faction) then { _out pushBack _c };
        } forEach ("true" configClasses (configFile >> "CfgVehicles"));
    };

    _out = _out arrayIntersect _out;
    if (count _out > 0) then {
        missionNamespace setVariable ["FADE_enemyDroneVehicleClasses_cache", +_out];
    };
    _out
};

FADE_opforDrone_pickClass = {
    private _drones = call FADE_getEnemyDroneVehicleClasses;
    if (_drones isEqualTo []) then {
        _drones = FADE_opforDrone_fallbackClasses select { isClass (configFile >> "CfgVehicles" >> _x) };
    };
    if (_drones isEqualTo []) exitWith { "O_UAV_01_F" };
    selectRandom _drones
};

FADE_opforDrone_isGroundPlayer = {
    params ["_u"];
    isPlayer _u && { alive _u } && { !(_u isKindOf "Air") } && { !(vehicle _u isKindOf "Air") }
};

FADE_opforDrone_allFriendliesAtHq = {
    params ["_hqR"];
    private _base = missionNamespace getVariable ["BASE_1", objNull];
    if (isNull _base) exitWith { false };
    private _bp = getPosATL _base;
    private _friendlySide = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _hasPl = false;
    private _allInside = true;
    {
        if (side _x == _friendlySide && { alive _x } && { isPlayer _x }) then {
            _hasPl = true;
            if ((_x distance2D _bp) > _hqR) then { _allInside = false };
        };
    } forEach playableUnits;
    _hasPl && _allInside
};

FADE_opforDrone_patrolCenter = {
    private _friendlySide = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _acc = [0, 0, 0];
    private _n = 0;
    {
        if (side _x == _friendlySide && { alive _x } && { isPlayer _x }) then {
            private _p = getPosATL _x;
            _acc = _acc vectorAdd _p;
            _n = _n + 1;
        };
    } forEach playableUnits;
    if (_n > 0) exitWith { _acc vectorMultiply (1 / _n) };

    private _names = missionNamespace getVariable ["FADE_civTriggerNames", []];
    if (count _names > 0) then {
        private _pick = selectRandom _names;
        private _tr = missionNamespace getVariable [_pick, objNull];
        if (!isNull _tr) exitWith { getPosATL _tr };
    };
    private _base = missionNamespace getVariable ["BASE_1", objNull];
    if (!isNull _base) exitWith { getPosATL _base };
    [worldSize / 2, worldSize / 2, 0]
};

FADE_opforDrone_assignPatrol = {
    params ["_uav", "_center2"];
    if (isNull _uav) exitWith {};
    private _grp = group (driver _uav);
    if (isNull _grp) then { _grp = group _uav };
    if (isNull _grp) exitWith {};
    while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
    // Ingress to player AO first (NORMAL), then tight search orbit — small UAVs are slow.
    private _in = _grp addWaypoint [_center2, 80];
    _in setWaypointType "MOVE";
    _in setWaypointSpeed "NORMAL";
    _in setWaypointBehaviour "AWARE";
    private _r = 450 + random 350;
    for "_i" from 0 to 3 do {
        private _ang = _i * 90 + random 50;
        private _p = [(_center2 select 0) + _r * sin _ang, (_center2 select 1) + _r * cos _ang, 0];
        private _wp = _grp addWaypoint [_p, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "NORMAL";
        _wp setWaypointBehaviour "AWARE";
    };
    private _cyc = _grp addWaypoint [_center2, 0];
    _cyc setWaypointType "CYCLE";
    _grp setBehaviour "AWARE";
    _grp setCombatMode "RED";
};

FADE_opforDrone_despawnAll = {
    if (!isServer) exitWith {};
    private _arr = missionNamespace getVariable ["FADE_opforDrone_active", []];
    {
        if (!isNull _x) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach crew _x;
            deleteVehicle _x;
        };
    } forEach _arr;
    missionNamespace setVariable ["FADE_opforDrone_active", []];
};

FADE_opforDrone_doSpawn = {
    if (!isServer) exitWith {};
    private _center = call FADE_opforDrone_patrolCenter;
    private _center2 = [_center select 0, _center select 1];
    private _dirFrom = random 360;
    // ~700–1100 m: close enough for slow ISR quads to reach the AO quickly, still off the player stack.
    private _dist = 700 + random 400;
    private _spawn2 = [
        (_center2 select 0) + _dist * sin _dirFrom,
        (_center2 select 1) + _dist * cos _dirFrom
    ];
    private _edgePad = 250;
    _spawn2 = [_spawn2, _edgePad] call (missionNamespace getVariable ["FADE_mapClampPos2D", {
        params ["_xy", ["_p", 0]];
        private _mn = missionNamespace getVariable ["FADE_mapMin", 0];
        private _mx = missionNamespace getVariable ["FADE_mapMax", worldSize];
        [(_xy select 0) max (_mn + _p) min (_mx - _p), (_xy select 1) max (_mn + _p) min (_mx - _p)]
    }]);
    private _alt = (getTerrainHeightASL [_spawn2 select 0, _spawn2 select 1]) + 120 + random 60;
    private _spawnPos = [_spawn2 select 0, _spawn2 select 1, _alt];
    private _class = call FADE_opforDrone_pickClass;
    private _uav = createVehicle [_class, _spawnPos, [], 0, "FLY"];
    if (isNull _uav) exitWith {};
    _uav setPosASL _spawnPos;
    createVehicleCrew _uav;
    if (isNull driver _uav) then {
        private _sideE = missionNamespace getVariable ["FADE_sideEnemy", east];
        private _crewGrp = createGroup _sideE;
        private _crewUnits = missionNamespace getVariable ["FADE_enemyUnits", ["O_Soldier_F"]];
        private _pilot = _crewGrp createUnit [selectRandom _crewUnits, _spawnPos, [], 0, "NONE"];
        if (!isNull _pilot) then { _pilot moveInDriver _uav };
        if (isNull driver _uav) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach units _crewGrp;
            deleteGroup _crewGrp;
            deleteVehicle _uav;
            // #region agent log
            diag_log format ["[FAC DbgBrowser 62d308] H17 opforDrone spawn failed no crew class=%1", _class];
            // #endregion
        };
    };
    // Bare exitWith inside then {} fails SQF parse ("Missing ;"); abort doSpawn here instead.
    if (isNull _uav || { isNull driver _uav }) exitWith {};
    private _grp = group (driver _uav);
    if (!isNull _grp) then {
        private _apply = missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}];
        if (!(_apply isEqualTo {})) then { [_grp] call _apply };
        { _x enableAI "TARGET"; _x enableAI "AUTOTARGET" } forEach units _grp;
    };
    _uav flyInHeight (_alt - getTerrainHeightASL _spawn2);
    _uav setVariable ["FADE_opforDroneAsset", true, true];
    [_uav, _center2] call FADE_opforDrone_assignPatrol;
    private _arr = missionNamespace getVariable ["FADE_opforDrone_active", []];
    _arr pushBack _uav;
    missionNamespace setVariable ["FADE_opforDrone_active", _arr];
    missionNamespace setVariable ["FADE_opforDrone_lastSpawnTime", time];
    // #region agent log
    diag_log format [
        "[FAC DbgBrowser 62d308] H17 opforDrone spawned class=%1 at=%2 active=%3",
        _class, _spawnPos, count _arr
    ];
    // #endregion
};

FADE_opforDrone_trySpawn = {
    if (!isServer) exitWith {};
    private _setting = [missionNamespace getVariable ["FADE_opforDroneSetting", "Off"]] call FADE_normalizeOpforThreatSetting;
    if (_setting == "Off") exitWith {};

    private _hqR = missionNamespace getVariable ["FADE_opforAir_hqSafeRadius", 1000];
    if ([_hqR] call FADE_opforDrone_allFriendliesAtHq) exitWith {
        if ((count (missionNamespace getVariable ["FADE_opforDrone_active", []])) > 0) then { call FADE_opforDrone_despawnAll };
        // #region agent log
        if (random 1 < 0.05) then {
            diag_log "[FAC DbgBrowser 62d308] H17 opforDrone suppressed (all friendlies at HQ)";
        };
        // #endregion
    };

    private _friendlySide = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _hasPl = (playableUnits findIf { side _x == _friendlySide && { alive _x } && { isPlayer _x } }) >= 0;
    if (!_hasPl) exitWith {};

    private _intensity = [_setting] call FADE_opforDroneIntensity;
    _intensity params ["_maxActive", "_spawnCd", "_qrfCdUnused"];
    private _arr = missionNamespace getVariable ["FADE_opforDrone_active", []];
    _arr = _arr select { !isNull _x && { alive _x } };
    missionNamespace setVariable ["FADE_opforDrone_active", _arr];
    if (count _arr >= _maxActive) exitWith {};
    private _last = missionNamespace getVariable ["FADE_opforDrone_lastSpawnTime", -1e9];
    if (time - _last < _spawnCd) exitWith {};
    call FADE_opforDrone_doSpawn;
};

FADE_opforDrone_triggerQrf = {
    params ["_contactPos"];
    if (!isServer) exitWith {};
    if (count _contactPos < 2) exitWith {};
    private _setting = [missionNamespace getVariable ["FADE_opforDroneSetting", "Off"]] call FADE_normalizeOpforThreatSetting;
    if (_setting == "Off") exitWith {};

    private _intensity = [_setting] call FADE_opforDroneIntensity;
    _intensity params ["_maxActiveUnused", "_spawnCdUnused", "_qrfCd"];
    private _last = missionNamespace getVariable ["FADE_opforDrone_lastQrfTime", -1e9];
    if (time - _last < _qrfCd) exitWith {};
    missionNamespace setVariable ["FADE_opforDrone_lastQrfTime", time];

    private _enemyUnits = missionNamespace getVariable ["FADE_enemyUnits", []];
    if (_enemyUnits isEqualTo []) exitWith {};
    private _groups = missionNamespace getVariable ["FADE_opforDrone_qrfGroups", []];
    private _base = missionNamespace getVariable ["FADE_basePos", [0, 0, 0]];
    private _pos3 = if (count _contactPos >= 3) then { +_contactPos } else { [(_contactPos select 0), (_contactPos select 1), 0] };
    private _taskId = format ["fade_drone_qrf_%1", floor time];

    private _fl = missionNamespace getVariable ["FADE_qrfSpawnHintFlare", {}];
    if (!(_fl isEqualTo {})) then { [_pos3, 450] call _fl };

    if (isNil "FADE_counterAttackStart" || { FADE_counterAttackStart isEqualTo {} }) exitWith {
        ["droneQrf aborted counterAttackStart missing pos=%1", _pos3] call FADE_qrfDbgLog;
    };
    ["droneQrf start task=%1 pos=%2 ambientSingleWave", _taskId, _pos3] call FADE_qrfDbgLog;
    [_taskId, _pos3, _base, _enemyUnits, _groups, 450, true, 45, 120, true] call FADE_counterAttackStart;
};

FADE_opforDrone_tickSpotting = {
    if (!isServer) exitWith {};
    private _setting = missionNamespace getVariable ["FADE_opforDroneSetting", "Off"];
    if (_setting == "Off") exitWith {};

    private _thr = missionNamespace getVariable ["FADE_opforDrone_spotThreshold", 1.25];
    private _arr = missionNamespace getVariable ["FADE_opforDrone_active", []];
    _arr = _arr select { !isNull _x && { alive _x } };
    missionNamespace setVariable ["FADE_opforDrone_active", _arr];
    if (_arr isEqualTo []) exitWith {};

    private _bestPos = [];
    private _bestK = 0;
    {
        private _pl = _x;
        if ([_pl] call FADE_opforDrone_isGroundPlayer) then {
            {
                private _uav = _x;
                private _grp = group (driver _uav);
                private _ka = _uav knowsAbout _pl;
                if (!isNull _grp) then {
                    { _ka = _ka max (_x knowsAbout _pl) } forEach units _grp;
                };
                if (_ka >= _thr && { _ka > _bestK }) then {
                    _bestK = _ka;
                    _bestPos = getPosATL _pl;
                };
            } forEach _arr;
        };
    } forEach playableUnits;

    if (count _bestPos >= 2) then {
        [_bestPos] call FADE_opforDrone_triggerQrf;
    };
};

[] spawn {
    sleep 60;
    while { true } do {
        sleep 45;
        if (!isServer) exitWith {};
        call FADE_opforDrone_trySpawn;
    };
};

[] spawn {
    sleep 135;
    while { true } do {
        sleep 22;
        if (!isServer) exitWith {};
        call FADE_opforDrone_tickSpotting;
    };
};
