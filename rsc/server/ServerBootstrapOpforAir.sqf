// ServerBootstrapOpforAir.sqf - OPFOR rotary response after BLUFOR detection
FADE_opforAir_knowsAboutThreshold = 1.2;
// Random delay (seconds) after detection before spawn: min + random extra (comms + takeoff).
FADE_opforAir_responseDelayMin = 40;
FADE_opforAir_responseDelayExtra = 200;
// While every friendly player is within this distance (2D) of BASE_1: despawn ambient OPFOR air and hold spawns/pending.
FADE_opforAir_hqSafeRadius = 1000;

// Minimum AGL when OPFOR air assets spawn (terrain + these meters ASL).
FADE_opforAir_spawnAglMin = 280;
FADE_opforAir_spawnAglExtra = 220;

FADE_opforAir_sideFromFactionCfg = {
    params ["_faction"];
    private _n = getNumber (configFile >> "CfgFactionClasses" >> _faction >> "side");
    switch (_n) do {
        case 0: { east };
        case 1: { west };
        case 2: { resistance };
        case 3: { civilian };
        default { east };
    };
};

// True if any living enemy-faction infantry/crew has sufficient knowsAbout on any BLUFOR player.
FADE_opforAir_opforDetectsBlufor = {
    private _enemySide = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _friendlySide = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _players = playableUnits select { side _x == _friendlySide && { alive _x } && { isPlayer _x } };
    if (_players isEqualTo []) exitWith { false };
    private _thr = missionNamespace getVariable ["FADE_opforAir_knowsAboutThreshold", 1.2];
    private _found = false;
    {
        private _pl = _x;
        private _nearEnemy = (_pl nearEntities ["CAManBase", 2500]) select {
            alive _x && { side _x == _enemySide } && { _x isKindOf "CAManBase" }
        };
        {
            if ((_x knowsAbout _pl) >= _thr) exitWith { _found = true };
        } forEach _nearEnemy;
        if (_found) exitWith {};
    } forEach _players;
    _found
};

FADE_opforAir_allFriendliesAtHq = {
    params [["_hqR", 1000]];
    private _base = missionNamespace getVariable ["BASE_1", objNull];
    if (isNull _base) exitWith { false };
    private _bp = getPosATL _base;
    private _friendlySide = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _hasPl = false;
    private _allInside = true;
    {
        if (side _x == _friendlySide && { alive _x } && { isPlayer _x }) then {
            _hasPl = true;
            if ((getPosATL _x) distance2D _bp > _hqR) then { _allInside = false };
        };
    } forEach playableUnits;
    _hasPl && _allInside
};

FADE_opforAir_anyPlayerFarFromHq = {
    params [["_hqR", 900]];
    private _base = missionNamespace getVariable ["BASE_1", objNull];
    if (isNull _base) exitWith { true };
    private _bp = getPosATL _base;
    private _friendlySide = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _found = false;
    {
        if (side _x == _friendlySide && { alive _x } && { isPlayer _x } && { (getPosATL _x) distance2D _bp > _hqR }) then {
            _found = true;
        };
    } forEach playableUnits;
    _found
};

FADE_opforAir_despawnAll = {
    if (!isServer) exitWith {};
    missionNamespace setVariable ["FADE_opforAir_pendingUntil", -1];
    private _arr = missionNamespace getVariable ["FADE_opforAir_active", []];
    {
        if (!isNull _x && { alive _x }) then {
            private _cargoG = _x getVariable ["FADE_opforAirCargoGrp", grpNull];
            if (!isNull _cargoG) then {
                { deleteVehicle _x } forEach units _cargoG;
                deleteGroup _cargoG;
            };
            private _g = group _x;
            { deleteVehicle _x } forEach (crew _x);
            deleteVehicle _x;
            if (!isNull _g) then { deleteGroup _g };
        };
    } forEach _arr;
    missionNamespace setVariable ["FADE_opforAir_active", []];
};

FADE_opforAir_getTargetASL = {
    private _friendlySide = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _acc = [0, 0, 0];
    private _n = 0;
    {
        if (side _x == _friendlySide && { alive _x } && { isPlayer _x }) then {
            _acc = _acc vectorAdd (getPosASL _x);
            _n = _n + 1;
        };
    } forEach playableUnits;
    if (_n > 0) exitWith { _acc vectorMultiply (1 / _n) };
    private _base = missionNamespace getVariable ["BASE_1", objNull];
    if (!isNull _base) exitWith { getPosASL _base };
    private _mapMin = missionNamespace getVariable ["FADE_mapMin", 0];
    private _mapMax = missionNamespace getVariable ["FADE_mapMax", worldSize];
    private _hs = (_mapMin + _mapMax) / 2;
    [_hs, _hs, 100]
};

// FADE_enemyVehicles excludes aircraft (land + ships only); air must be resolved from CfgVehicles like FADE_getFriendlyVehicleClasses.
FADE_getEnemyAirVehicleClasses = {
    private _cached = missionNamespace getVariable ["FADE_enemyAirVehicleClasses_cache", []];
    if (count _cached > 0) exitWith { +_cached };
    private _faction = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
    private _wantSide = missionNamespace getVariable ["FADE_scenarioEnemySideNum", 0];
    if (_faction == "") exitWith { [] };
    private _out = [];
    {
        private _c = _x;
        private _cl = toLower _c;
        if ((_cl find "uav" >= 0) || { _cl find "drone" >= 0 }) then { continue };
        if (!(_c isKindOf "Helicopter") && { !(_c isKindOf "Plane") }) then { continue };
        private _cfg = configFile >> "CfgVehicles" >> _c;
        if (getText (_cfg >> "faction") == _faction && { getNumber (_cfg >> "side") == _wantSide }) then {
            _out pushBack _c;
        };
    } forEach FADE_heliClasses;
    if (count _out > 0) exitWith {
        missionNamespace setVariable ["FADE_enemyAirVehicleClasses_cache", +_out];
        _out
    };
    {
        private _c = _x;
        private _cl = toLower _c;
        if ((_cl find "uav" >= 0) || { _cl find "drone" >= 0 }) then { continue };
        if (!(_c isKindOf "Helicopter") && { !(_c isKindOf "Plane") }) then { continue };
        if (getNumber (configFile >> "CfgVehicles" >> _c >> "side") == _wantSide) then {
            _out pushBack _c;
        };
    } forEach FADE_heliClasses;
    missionNamespace setVariable ["FADE_enemyAirVehicleClasses_cache", +_out];
    _out
};

// Used only when FADE_getEnemyAirVehicleClasses is empty (no faction-matched air in loaded addons).
FADE_opforAir_fallbackHeliClasses = [
    "RHS_Mi8mt_vvs",
    "rhsgref_ins_Mi8amt",
    "UK3CB_TKC_O_Mi8AMT",
    "UK3CB_ADA_O_UH1H_M240",
    "UK3CB_ION_O_Urban_UH1H_M240",
    "UK3CB_MEC_O_UH1H",
    "UK3CB_ADC_I_Mi8AMT",
    "UK3CB_ION_I_Desert_Orca",
    "UK3CB_ION_I_Urban_Merlin",
    "UK3CB_MEC_I_Bell412",
    "I_Heli_light_03_unarmed_F",
    "I_Heli_EC_01A_military_RF",
    "I_C_Heli_Light_01_civil_F",
    "C_IDAP_Heli_EC_01A_civ_RF",
    "C_IDAP_Heli_Transport_02_F",
    "UK3CB_C_Bell412_Civ_IDAP",
    "UK3CB_C_UH1H",
    "C_Heli_Light_01_civil_F",
    "RHS_Mi8t_civilian",
    "rhs_mi8amt_civilian"
];

// If the BLUFOR centroid is within _minDist m of BASE_1 (2D), push SAD/LZ target outward so fixed-wing does not get a point on top of HQ.
FADE_opforAir_adjustTargetAwayFromBase = {
    params ["_target2", ["_minDist", 1000]];
    if (count _target2 < 2) exitWith { _target2 };
    private _base = missionNamespace getVariable ["BASE_1", objNull];
    if (isNull _base) exitWith { _target2 };
    private _bp = getPosATL _base;
    if ((_target2 distance2D _bp) >= _minDist) exitWith { _target2 };
    private _dir = _bp getDir _target2;
    private _p = _bp getPos [_minDist + 150, _dir];
    [_p select 0, _p select 1]
};

FADE_opforAir_pickVehicleClass = {
    private _air = call FADE_getEnemyAirVehicleClasses;
    if (_air isEqualTo []) then {
        _air = FADE_opforAir_fallbackHeliClasses select { isClass (configFile >> "CfgVehicles" >> _x) };
    };
    if (_air isEqualTo []) exitWith { "O_Heli_Light_02_dynamicLoadout_F" };
    selectRandom _air
};

// Force _veh airborne at _spawnASL with heading; returns false if still on/near ground.
FADE_opforAir_placeAirborne = {
    params ["_veh", "_spawnASL", "_heading", ["_flyInH", -1]];
    if (isNull _veh || { count _spawnASL < 3 }) exitWith { false };
    private _terrainASL = getTerrainHeightASL [_spawnASL select 0, _spawnASL select 1];
    private _agl = (_spawnASL select 2) - _terrainASL;
    if (_flyInH < 0) then { _flyInH = _agl max 180 };
    _veh setPosASL _spawnASL;
    _veh setDir _heading;
    _veh enableSimulation true;
    _veh engineOn true;
    if (_veh isKindOf "Plane") then {
        _veh setVelocityModelSpace [0, 120 + random 40, 0];
    } else {
        _veh flyInHeight _flyInH;
        _veh setVelocityModelSpace [0, 25 + random 20, 0];
    };
    // Heli "FLY" create can still settle — bump ASL if near ground.
    if (isTouchingGround _veh || { (getPosATL _veh select 2) < 25 }) then {
        private _retryASL = [
            _spawnASL select 0,
            _spawnASL select 1,
            _terrainASL + _flyInH + 60
        ];
        _veh setPosASL _retryASL;
        if (!(_veh isKindOf "Plane")) then { _veh flyInHeight _flyInH + 60 };
        if (_veh isKindOf "Plane") then { _veh setVelocityModelSpace [0, 140, 0] };
    };
    !(isTouchingGround _veh) && { (getPosATL _veh select 2) >= 20 }
};

FADE_opforAir_doSpawn = {
    if (!isServer) exitWith {};
    private _arr = missionNamespace getVariable ["FADE_opforAir_active", []];
    private _targetASL = call FADE_opforAir_getTargetASL;
    private _target2 = [_targetASL select 0, _targetASL select 1];
    private _dirFrom = random 360;
    private _dist = 2800 + random 700;
    private _spawn2 = [
        (_target2 select 0) + _dist * (sin _dirFrom),
        (_target2 select 1) + _dist * (cos _dirFrom)
    ];
    private _mapMinA = missionNamespace getVariable ["FADE_mapMin", 0];
    private _mapMaxA = missionNamespace getVariable ["FADE_mapMax", worldSize];
    private _edgePad = 200;
    _spawn2 set [0, (_spawn2 select 0) max (_mapMinA + _edgePad) min (_mapMaxA - _edgePad)];
    _spawn2 set [1, (_spawn2 select 1) max (_mapMinA + _edgePad) min (_mapMaxA - _edgePad)];
    private _aglMin = missionNamespace getVariable ["FADE_opforAir_spawnAglMin", 280];
    private _aglExtra = missionNamespace getVariable ["FADE_opforAir_spawnAglExtra", 220];
    private _alt = (getTerrainHeightASL [_spawn2 select 0, _spawn2 select 1]) + _aglMin + random _aglExtra;
    private _spawnPosASL = [_spawn2 select 0, _spawn2 select 1, _alt];
    private _class = call FADE_opforAir_pickVehicleClass;
    private _face = ((_target2 select 1) - (_spawn2 select 1)) atan2 ((_target2 select 0) - (_spawn2 select 0));
    private _flyInH = 180 + random 120;

    private _veh = createVehicle [_class, _spawnPosASL, [], 0, "FLY"];
    if (isNull _veh) exitWith {};
    if (!([_veh, _spawnPosASL, _face, _flyInH] call FADE_opforAir_placeAirborne)) exitWith {
        // #region agent log
        diag_log format [
            "[FAC DbgBrowser 62d308] H17 opforAir groundSpawnAbort class=%1 asl=%2 touching=%3",
            _class, _spawnPosASL, isTouchingGround _veh
        ];
        // #endregion
        { if (!isNull _x) then { deleteVehicle _x } } forEach crew _veh;
        deleteVehicle _veh;
    };
    private _cargoCap0 = _veh emptyPositions "cargo";
    private _crewUnits = missionNamespace getVariable ["FADE_enemyUnits", []];
    if (_crewUnits isEqualTo []) then { _crewUnits = [] call (missionNamespace getVariable ["FADE_resolveScenarioEnemyUnits", { [] }]) };
    if (_crewUnits isEqualTo []) then { _crewUnits = +(missionNamespace getVariable ["FADE_fallbackEnemyUnits", ["O_Soldier_F"]]) };
    { if (!isNull _x) then { deleteVehicle _x } } forEach crew _veh;
    private _sideE = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _grp = createGroup _sideE;
    private _crewSpawnASL = +_spawnPosASL;
    private _driver = _grp createUnit [selectRandom _crewUnits, _crewSpawnASL, [], 0, "NONE"];
    if (!isNull _driver) then { _driver moveInDriver _veh; _grp selectLeader _driver };
    if (_veh emptyPositions "gunner" > 0) then {
        private _gun = _grp createUnit [selectRandom _crewUnits, _crewSpawnASL, [], 0, "NONE"];
        if (!isNull _gun) then { _gun moveInGunner _veh };
    };
    if (_veh emptyPositions "commander" > 0) then {
        private _cmd = _grp createUnit [selectRandom _crewUnits, _crewSpawnASL, [], 0, "NONE"];
        if (!isNull _cmd) then { _cmd moveInCommander _veh };
    };
    if (isNull driver _veh) exitWith { { if (!isNull _x) then { deleteVehicle _x } } forEach units _grp; deleteGroup _grp; deleteVehicle _veh };
    [_veh, _spawnPosASL, _face, _flyInH] call FADE_opforAir_placeAirborne;
    private _facApply = missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}];
    if (!(_facApply isEqualTo {})) then { [_grp] call _facApply };
    _grp setGroupIdGlobal [format ["OPF-AIR-%1", floor random 999]];
    _grp setBehaviour "COMBAT";
    _grp setCombatMode "RED";

    private _sadTgt = [_target2, 1000] call FADE_opforAir_adjustTargetAwayFromBase;
    private _isPlane = _veh isKindOf "Plane";
    private _isHeli = _veh isKindOf "Helicopter";
    private _cargoCap = _cargoCap0;

    if (_isPlane) then {
        private _wp = _grp addWaypoint [_sadTgt + [0], 0];
        _wp setWaypointType "SAD";
        _wp setWaypointBehaviour "COMBAT";
        _wp setWaypointCombatMode "RED";
    } else {
        if (_isHeli) then {
            private _grpInf = grpNull;
            if (_cargoCap >= 2) then {
                _grpInf = createGroup _sideE;
                private _maxFill = _cargoCap min 12;
                private _k = 0;
                while { _veh emptyPositions "cargo" > 0 && _k < _maxFill } do {
                    _k = _k + 1;
                    private _u = _grpInf createUnit [selectRandom _crewUnits, _crewSpawnASL, [], 0, "NONE"];
                    if (isNull _u) exitWith {};
                    _u moveInCargo _veh;
                };
                if (count units _grpInf == 0) then {
                    deleteGroup _grpInf;
                    _grpInf = grpNull;
                } else {
                    if (!(_facApply isEqualTo {})) then { [_grpInf] call _facApply };
                    _grpInf setGroupIdGlobal [format ["OPF-AIR-INF-%1", floor random 999]];
                    _grpInf setBehaviour "COMBAT";
                    _grpInf setCombatMode "RED";
                    private _wpMove = _grpInf addWaypoint [_target2 + [0], 0];
                    _wpMove setWaypointType "MOVE";
                    _wpMove setWaypointBehaviour "COMBAT";
                    _wpMove setWaypointCombatMode "RED";
                    private _wpInfSad = _grpInf addWaypoint [_target2 + [0], 0];
                    _wpInfSad setWaypointType "SAD";
                    _wpInfSad setWaypointBehaviour "COMBAT";
                    _wpInfSad setWaypointCombatMode "RED";
                    _veh setVariable ["FADE_opforAirCargoGrp", _grpInf];
                };
            } else {
                if (_cargoCap > 0) then {
                    _grpInf = createGroup _sideE;
                    private _k = 0;
                    while { _veh emptyPositions "cargo" > 0 && _k < _cargoCap } do {
                        _k = _k + 1;
                        private _u = _grpInf createUnit [selectRandom _crewUnits, _crewSpawnASL, [], 0, "NONE"];
                        if (isNull _u) exitWith {};
                        _u moveInCargo _veh;
                    };
                    if (count units _grpInf == 0) then {
                        deleteGroup _grpInf;
                    } else {
                        if (!(_facApply isEqualTo {})) then { [_grpInf] call _facApply };
                        _veh setVariable ["FADE_opforAirCargoGrp", _grpInf];
                    };
                };
                private _wpSad = _grp addWaypoint [_sadTgt + [0], 0];
                _wpSad setWaypointType "SAD";
                _wpSad setWaypointBehaviour "COMBAT";
                _wpSad setWaypointCombatMode "RED";
            };

            if (_cargoCap >= 2 && { !isNull (_veh getVariable ["FADE_opforAirCargoGrp", grpNull]) }) then {
                private _lz = [_target2] call FADE_findSafeLZ;
                if (_lz isEqualTo []) then { _lz = +_target2 };
                private _lz2 = [_lz select 0, _lz select 1];
                private _wpUnload = _grp addWaypoint [_lz2 + [0], 0];
                _wpUnload setWaypointType "TR UNLOAD";
                _wpUnload setWaypointBehaviour "COMBAT";
                _wpUnload setWaypointCombatMode "RED";
                private _wpHeliSad = _grp addWaypoint [_sadTgt + [0], 0];
                _wpHeliSad setWaypointType "SAD";
                _wpHeliSad setWaypointBehaviour "COMBAT";
                _wpHeliSad setWaypointCombatMode "RED";
            };
            if (count waypoints _grp == 0) then {
                private _wpSadOnly = _grp addWaypoint [_sadTgt + [0], 0];
                _wpSadOnly setWaypointType "SAD";
                _wpSadOnly setWaypointBehaviour "COMBAT";
                _wpSadOnly setWaypointCombatMode "RED";
            };
        } else {
            private _wp = _grp addWaypoint [_sadTgt + [0], 0];
            _wp setWaypointType "SAD";
            _wp setWaypointBehaviour "COMBAT";
            _wp setWaypointCombatMode "RED";
        };
    };

    [_veh, _crewUnits] call FADE_ensureEnemyVehicleGunner;
    private _airborneOk = [_veh, _spawnPosASL, _face, _flyInH] call FADE_opforAir_placeAirborne;
    if (!_airborneOk) then {
        // #region agent log
        diag_log format [
            "[FAC DbgBrowser 62d308] H17 opforAir groundAfterCrew class=%1 agl=%2",
            _class, (getPosATL _veh select 2) - (getTerrainHeightASL (getPosATL _veh))
        ];
        // #endregion
        private _cargoG = _veh getVariable ["FADE_opforAirCargoGrp", grpNull];
        if (!isNull _cargoG) then {
            { deleteVehicle _x } forEach units _cargoG;
            deleteGroup _cargoG;
        };
        { deleteVehicle _x } forEach crew _veh;
        deleteVehicle _veh;
        deleteGroup _grp;
    };
    if (!_airborneOk) exitWith {};

    _arr pushBack _veh;
    missionNamespace setVariable ["FADE_opforAir_active", _arr];
    missionNamespace setVariable ["FADE_opforAir_lastSpawnTime", time];
    _veh setVariable ["FADE_opforAirAsset", true, true];
    _grp setVariable ["FADE_opforAirAsset", true, true];
    // #region agent log
    private _spawnAgl = (getPosATL _veh select 2) - (getTerrainHeightASL (getPosATL _veh));
    diag_log format [
        "[FAC DbgBrowser 62d308] H17 opforAir spawned class=%1 asl=%2 agl=%3 airborne=%4 active=%5",
        _class, getPosASL _veh, _spawnAgl, !(isTouchingGround _veh), count _arr
    ];
    // #endregion
};

FADE_opforAir_trySpawn = {
    if (!isServer) exitWith {};
    private _friendlySide = missionNamespace getVariable ["FADE_sideFriendly", west];
    if ([missionNamespace getVariable ["FADE_opforAir_hqSafeRadius", 1000]] call FADE_opforAir_allFriendliesAtHq) then {
        private _arrH = missionNamespace getVariable ["FADE_opforAir_active", []];
        _arrH = _arrH select { !isNull _x && { alive _x } };
        missionNamespace setVariable ["FADE_opforAir_active", _arrH];
        if (count _arrH > 0) then { call FADE_opforAir_despawnAll };
        missionNamespace setVariable ["FADE_opforAir_pendingUntil", -1];
        // #region agent log
        diag_log "[FAC DbgBrowser 62d308] H17 opforAir suppressed (all friendlies at HQ)";
        // #endregion
        exitWith {};
    };
    private _setting = [missionNamespace getVariable ["FADE_opforAirSetting", "Off"]] call FADE_normalizeOpforThreatSetting;
    if (_setting == "Off") exitWith {};
    private _settingLower = toLower _setting;
    private _intensity = [_setting] call FADE_opforThreatIntensity;
    _intensity params ["_maxActive", "_cooldown"];
    private _arr = missionNamespace getVariable ["FADE_opforAir_active", []];
    _arr = _arr select { !isNull _x && { alive _x } };
    missionNamespace setVariable ["FADE_opforAir_active", _arr];
    if (count _arr >= _maxActive) exitWith { missionNamespace setVariable ["FADE_opforAir_pendingUntil", -1]; };
    private _last = missionNamespace getVariable ["FADE_opforAir_lastSpawnTime", -1e9];
    if (time - _last < _cooldown) exitWith {};
    private _hasPl = (playableUnits findIf { side _x == _friendlySide && { alive _x } && { isPlayer _x } }) >= 0;
    if (!_hasPl) exitWith { missionNamespace setVariable ["FADE_opforAir_pendingUntil", -1]; };

    private _detected = call FADE_opforAir_opforDetectsBlufor;
    private _farFromHq = call FADE_opforAir_anyPlayerFarFromHq;
    private _allowAmbient = _farFromHq && { _settingLower in ["normal", "high"] };
    if (!_detected && { !_allowAmbient }) exitWith {
        missionNamespace setVariable ["FADE_opforAir_pendingUntil", -1];
        // #region agent log
        if (random 1 < 0.08) then {
            diag_log format [
                "[FAC DbgBrowser 62d308] H17 opforAir waiting detection=%1 farFromHq=%2 setting=%3",
                _detected, _farFromHq, _setting
            ];
        };
        // #endregion
    };

    private _pending = missionNamespace getVariable ["FADE_opforAir_pendingUntil", -1];
    private _dMin = if (_settingLower == "high") then { 25 } else {
        missionNamespace getVariable ["FADE_opforAir_responseDelayMin", 40]
    };
    private _dExt = if (_settingLower == "high") then { 75 } else {
        missionNamespace getVariable ["FADE_opforAir_responseDelayExtra", 200]
    };
    if (_pending < 0) then {
        missionNamespace setVariable ["FADE_opforAir_pendingUntil", time + _dMin + random _dExt];
        // #region agent log
        diag_log format [
            "[FAC DbgBrowser 62d308] H17 opforAir pending until %1 (detected=%2 ambient=%3)",
            missionNamespace getVariable ["FADE_opforAir_pendingUntil", -1], _detected, _allowAmbient
        ];
        // #endregion
    } else {
        if (time >= _pending) then {
            _arr = missionNamespace getVariable ["FADE_opforAir_active", []];
            _arr = _arr select { !isNull _x && { alive _x } };
            missionNamespace setVariable ["FADE_opforAir_active", _arr];
            if (count _arr >= _maxActive) exitWith { missionNamespace setVariable ["FADE_opforAir_pendingUntil", -1]; };
            private _stillOk = (call FADE_opforAir_opforDetectsBlufor) || { _allowAmbient };
            if (!_stillOk) exitWith { missionNamespace setVariable ["FADE_opforAir_pendingUntil", -1]; };
            call FADE_opforAir_doSpawn;
            missionNamespace setVariable ["FADE_opforAir_pendingUntil", -1];
        };
    };
};
