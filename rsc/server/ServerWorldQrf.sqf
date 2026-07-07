// ServerWorldQrf.sqf - counter-attack / QRF spawn loop
// -----------------------------------------------------------------------------
// Counter-attack helpers - cargo capacity (cached per classname), RHS/vanilla fallbacks
// -----------------------------------------------------------------------------
// Returns emptyPositions "cargo" for a classname; caches in missionNamespace (spawn test once per class).
FADE_counterAttack_cargoSeatsForClass = {
    params ["_class"];
    private _key = "FADE_counterAttack_cargo_" + _class;
    private _cached = missionNamespace getVariable [_key, -1];
    if (_cached >= 0) exitWith { _cached };
    if (!(isClass (configFile >> "CfgVehicles" >> _class))) exitWith {
        missionNamespace setVariable [_key, 0];
        0
    };
    private _testPos = [[FADE_basePos, 1500, 5000, 15, 1, 0.4, 0, [], FADE_basePos], FADE_basePos] call FADE_findSafePosArray;
    if (count _testPos < 2) then { _testPos = [FADE_basePos select 0, FADE_basePos select 1, 0] };
    private _v = createVehicle [_class, _testPos, [], 0, "NONE"];
    if (isNull _v) exitWith {
        missionNamespace setVariable [_key, 0];
        0
    };
    private _n = _v emptyPositions "cargo";
    deleteVehicle _v;
    missionNamespace setVariable [_key, _n];
    _n
};

// Filter classnames to those with at least _minCargo cargo seats (uses cache above).
FADE_counterAttack_filterClassesByMinCargo = {
    params ["_classes", "_minCargo"];
    private _out = [];
    {
        if (([_x] call FADE_counterAttack_cargoSeatsForClass) >= _minCargo) then {
            _out pushBack _x;
        };
    } forEach _classes;
    _out
};

// -----------------------------------------------------------------------------
// QRF hint: red flare high in the air near _center (optionally biased toward friendly players in radius). Server only.
// Params: [_centerATL, _radiusM, _heightM (optional)]
// Uses setPosASL — F_40mm_Red ignores createVehicle ATL and otherwise lands at ground level (feet).
// -----------------------------------------------------------------------------
FADE_qrfSpawnHintFlare = {
    params [["_center", [0, 0, 0]], ["_radiusM", 500], ["_heightM", 100]];
    if (!isServer) exitWith {};
    if (count _center < 2) exitWith {};
    private _centerN = [_center] call FADE_normPos3;
    private _sf = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _acc = [0, 0, 0];
    private _n = 0;
    {
        if (isPlayer _x && { alive _x } && { side _x == _sf } && { (_x distance2D _centerN) <= _radiusM }) then {
            private _p = getPosASL _x;
            if (count _p < 3) then { _p = [(_p select 0), (_p select 1), 0] };
            _acc = _acc vectorAdd _p;
            _n = _n + 1;
        };
    } forEach allPlayers;
    private _gx = _centerN select 0;
    private _gy = _centerN select 1;
    private _groundRefAsl = getTerrainHeightASL [_gx, _gy];
    if (_n > 0) then {
        private _avg = _acc vectorMultiply (1 / _n);
        _gx = _avg select 0;
        _gy = _avg select 1;
        _groundRefAsl = (_groundRefAsl max (_avg select 2));
    };
    private _flareAsl = [_gx, _gy, _groundRefAsl + (_heightM max 80) + random 25];
    private _flare = createVehicle ["F_40mm_Red", [0, 0, 0], [], 0, "NONE"];
    if (isNull _flare) exitWith {};
    _flare setPosASL _flareAsl;
    _flare setVelocity [0, 0, 0];
    [_flare, 50] spawn {
        params ["_f", "_ttl"];
        sleep _ttl;
        if (!isNull _f) then { deleteVehicle _f };
    };
};
missionNamespace setVariable ["FADE_qrfSpawnHintFlare", FADE_qrfSpawnHintFlare];

// Server: ATL centroid of alive friendly-side players; else any alive player; else _fallback (2â€“3 elements).
FADE_qrfFriendlyCentroidATL = {
    params [["_fallback", [0, 0, 0]]];
    if (count _fallback < 2) exitWith { [0, 0, 0] };
    private _sf = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _acc = [0, 0, 0];
    private _n = 0;
    {
        if (isPlayer _x && { alive _x } && { side _x == _sf }) then {
            private _p = getPosATL _x;
            if (count _p < 3) then { _p = [(_p select 0), (_p select 1), 0] };
            _acc = _acc vectorAdd _p;
            _n = _n + 1;
        };
    } forEach allPlayers;
    if (_n > 0) exitWith {
        private _avg = _acc vectorMultiply (1 / _n);
        [(_avg select 0), (_avg select 1), (_avg select 2) max 0]
    };
    _acc = [0, 0, 0];
    _n = 0;
    {
        if (isPlayer _x && { alive _x }) then {
            private _p = getPosATL _x;
            if (count _p < 3) then { _p = [(_p select 0), (_p select 1), 0] };
            _acc = _acc vectorAdd _p;
            _n = _n + 1;
        };
    } forEach allPlayers;
    if (_n > 0) exitWith {
        private _avg = _acc vectorMultiply (1 / _n);
        [(_avg select 0), (_avg select 1), (_avg select 2) max 0]
    };
    if (count _fallback < 3) then { [(_fallback select 0), (_fallback select 1), 0] } else { +_fallback }
};
missionNamespace setVariable ["FADE_qrfFriendlyCentroidATL", FADE_qrfFriendlyCentroidATL];

// -----------------------------------------------------------------------------
// Counter-attack / QRF (HVT, Hostage, Clear Area, Search & Destroy, Troop Extract, CASEVAC, CSAR, Asset Retrieval, CAS) - reusable server spawn loop.
// Stages truck-mounted infantry from the second-nearest civ zone (by distance
// to the objective); falls back to offset from nearest zone if only one trigger exists.
// Params: [_taskId, _objectivePos, _basePos, _enemyUnits, _allGroups, _detectionRadius, _skipDetectionWait]
//   _allGroups - reference array; new enemy groups are pushBack'd for mission cleanup.
//   _detectionRadius - optional; <= 0 uses missionNamespace FADE_counterAttackDetectionRadius (default 450).
//   _skipDetectionWait - optional; if true, skip polling for player-in-zone and start first-wave delay immediately (CAS: when friendlies mark).
// Timing defaults (optional missionNamespace): FADE_counterAttackFirstDelayMin/Max (120â€“360s),
//   FADE_counterAttackBetweenMin/Max (540â€“660s), FADE_counterAttackTruckCount (3).
// Vehicle filter: FADE_counterAttackMinCargoSeats (default 4). Fallback trucks if faction has none:
//   FADE_counterAttackRhsFallbacks (RHS GAZ/ZIL/Kamaz/Ural-style), then FADE_counterAttackVanillaFallbacks.
// Poll interval: FADE_counterAttackPollInterval (default 10s) for zone/task checks (not per-frame).
// Wave cap: 1â€“3 waves per mission instance (chosen at random when the counter-attack thread starts).
// If no player remains inside the objective detection radius when a wave spawns, trucks hunt a friendly
// player centroid; driver MOVE+SAD waypoints refresh every FADE_qrfHuntWaypointIntervalS (default 60).
// Not registered with FADE_registerEnemyRetreat (QRF keeps pressure); cleaned with mission groups.
// -----------------------------------------------------------------------------
FADE_counterAttack_spawnFootWave = {
    params ["_taskId", "_objectivePos", "_enemyUnits", "_allGroups", "_applyGrp"];
    if (count _objectivePos < 2 || { count _enemyUnits == 0 }) exitWith {};
    private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _sqMin = (missionNamespace getVariable ["FADE_counterAttackFootSquadsMin", 2]) max 1;
    private _sqMax = (missionNamespace getVariable ["FADE_counterAttackFootSquadsMax", 3]) max _sqMin;
    private _distMin = (missionNamespace getVariable ["FADE_counterAttackFootSpawnDistMin", 200]) max 50;
    private _distMax = (missionNamespace getVariable ["FADE_counterAttackFootSpawnDistMax", 500]) max _distMin;
    private _sizeMin = (missionNamespace getVariable ["FADE_counterAttackFootSquadSizeMin", 4]) max 2;
    private _sizeMax = (missionNamespace getVariable ["FADE_counterAttackFootSquadSizeMax", 6]) max _sizeMin;
    private _numSquads = _sqMin + floor random (1 + _sqMax - _sqMin);
    private _obj3 = if (count _objectivePos >= 3) then { +_objectivePos } else { [(_objectivePos select 0), (_objectivePos select 1), 0] };
    private _bearings = [];
    for "_i" from 1 to _numSquads do {
        private _bearing = random 360;
        private _tooClose = true;
        for "_t" from 0 to 11 do {
            _bearing = random 360;
            _tooClose = false;
            { if (abs ((_bearing - _x + 540) % 360 - 180) < 45) exitWith { _tooClose = true } } forEach _bearings;
            if (!_tooClose) exitWith {};
        };
        _bearings pushBack _bearing;
        private _dist = _distMin + random (_distMax - _distMin);
        private _raw = _obj3 getPos [_dist, _bearing];
        private _spawnPos = [[_raw, 0, 35, 4, 1, 0.4, 0, [], _obj3], _raw] call FADE_findSafePosArray;
        if (surfaceIsWater _spawnPos) then {
            _spawnPos = [[_obj3, _distMin + random ((_distMax - _distMin) * 0.5), 40, 4, 1, 0.4, 0, [], _obj3], _spawnPos] call FADE_findSafePosArray;
        };
        if (surfaceIsWater _spawnPos) then { continue };
        private _sz = _sizeMin + floor random (1 + _sizeMax - _sizeMin);
        private _cls = [];
        for "_u" from 1 to _sz do { _cls pushBack (selectRandom _enemyUnits) };
        private _grp = [_spawnPos, _sideEnemy, _cls] call BIS_fnc_spawnGroup;
        if (isNull _grp || { count units _grp == 0 }) then { continue };
        [_grp] call _applyGrp;
        _grp setBehaviour "COMBAT";
        _grp setCombatMode "RED";
        _grp setSpeedMode "FULL";
        private _wpM = _grp addWaypoint [_obj3, 30];
        _wpM setWaypointType "MOVE";
        _wpM setWaypointSpeed "FULL";
        private _wpS = _grp addWaypoint [_obj3, 0];
        _wpS setWaypointType "SAD";
        _allGroups pushBack _grp;
        if (_taskId != "") then { [_taskId, _grp] call FADE_missionEnt_bindGroups };
    };
};
missionNamespace setVariable ["FADE_counterAttack_spawnFootWave", FADE_counterAttack_spawnFootWave];

FADE_counterAttackStart = {
    params [
        "_taskId",
        "_objectivePos",
        "_basePos",
        "_enemyUnits",
        "_allGroups",
        ["_detectionRadius", -1],
        ["_skipDetectionWait", false],
        ["_firstDelayMin", -1],
        ["_firstDelayMax", -1],
        ["_ambientSingleWave", false],
        ["_footWave", false]
    ];
    if (!isServer) exitWith {};
    if (count _objectivePos < 2 || { count _enemyUnits == 0 }) exitWith {};
    if (_detectionRadius <= 0) then {
        _detectionRadius = missionNamespace getVariable ["FADE_counterAttackDetectionRadius", 450];
    };
    private _firstMin = if (_firstDelayMin >= 0) then { _firstDelayMin } else { missionNamespace getVariable ["FADE_counterAttackFirstDelayMin", 120] };
    private _firstMax = if (_firstDelayMax >= 0) then { _firstDelayMax } else { missionNamespace getVariable ["FADE_counterAttackFirstDelayMax", 360] };
    if (_firstMax < _firstMin) then { _firstMax = _firstMin };
    private _betMin = missionNamespace getVariable ["FADE_counterAttackBetweenMin", 540];
    private _betMax = missionNamespace getVariable ["FADE_counterAttackBetweenMax", 660];
    private _numTrucks = (missionNamespace getVariable ["FADE_counterAttackTruckCount", 3]) max 1;
    private _pollInterval = (missionNamespace getVariable ["FADE_counterAttackPollInterval", 10]) max 1;
    private _applyGrp = missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}];
    if (_applyGrp isEqualTo {}) exitWith {};

    [_taskId, _objectivePos, _basePos, _enemyUnits, _allGroups, _detectionRadius, _firstMin, _firstMax, _betMin, _betMax, _numTrucks, _applyGrp, _pollInterval, _skipDetectionWait, _ambientSingleWave, _footWave] spawn {
        params [
            "_taskId", "_objectivePos", "_basePos", "_enemyUnits", "_allGroups", "_detectionRadius",
            "_firstMin", "_firstMax", "_betMin", "_betMax", "_numTrucks", "_applyGrp", "_pollInterval", "_skipDetectionWait", "_ambientSingleWave", "_footWave"
        ];
        private _taskDone = if (_ambientSingleWave) then {
            { false }
        } else {
            { (_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"] }
        };
        private _playersInZone = {
            private _ok = false;
            {
                if (isPlayer _x && { alive _x } && { (_x distance2D _objectivePos) < _detectionRadius }) exitWith { _ok = true };
            } forEach allPlayers;
            _ok
        };
        private _detectionLogged = false;
        if (!_skipDetectionWait) then {
            // Wait for first contact in zone or mission end (slow poll - not per-frame)
            waitUntil {
                sleep _pollInterval;
                if (call _taskDone) exitWith { true };
                private _in = call _playersInZone;
                if (_in && { !_detectionLogged }) then {
                    _detectionLogged = true;
                };
                _in
            };
            if (call _taskDone) exitWith {};
        } else {
            if (call _taskDone) exitWith {};
        };
        private _maxWaves = if (_ambientSingleWave) then { 1 } else { 1 + floor random 3 };
        if (_footWave) then {
            [_taskId, _objectivePos, _enemyUnits, _allGroups, _applyGrp] call FADE_counterAttack_spawnFootWave;
        };
        private _firstDelaySec = _firstMin + random (_firstMax - _firstMin);
        sleep _firstDelaySec;

        private _waveFn = {
            params ["_taskId", "_objectivePos", "_enemyUnits", "_allGroups", "_numTrucks", "_applyGrp", "_pollInterval", "_detectionRadius"];
            private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
            private _pairs = [];
            {
                private _trig = missionNamespace getVariable [_x, objNull];
                if (!isNull _trig) then {
                    private _zc = getPosATL _trig;
                    if (count _zc >= 2) then {
                        _pairs pushBack [_zc distance2D _objectivePos, _zc];
                    };
                };
            } forEach (missionNamespace getVariable ["FADE_civTriggerNames", []]);
            if (count _pairs == 0) exitWith {};
            _pairs = [_pairs, [], { _x select 0 }, "ASCEND"] call BIS_fnc_sortBy;
            private _minBase = missionNamespace getVariable ["FADE_counterAttackMinDistFromBase", 1000];
            private _baseQ = FADE_basePos;
            private _roadPos = [];
            private _staging = [];
            private _stagingResolved = false;
            private _stCandidates = [];
            if (count _pairs >= 2) then { _stCandidates pushBack [1, (_pairs select 1) select 1] };
            if (count _pairs >= 3) then { _stCandidates pushBack [2, (_pairs select 2) select 1] };
            _stCandidates pushBack [0, (_pairs select 0) select 1];
            if (count _pairs >= 4) then { _stCandidates pushBack [3, (_pairs select 3) select 1] };
            private _nearOnly = (_pairs select 0) select 1;
            _stCandidates pushBack [-1, _nearOnly getPos [600 min ((_nearOnly distance2D _objectivePos) + 400), (_nearOnly getDir _objectivePos) + 180]];
            private _si = 0;
            while { _si < count _stCandidates && { !_stagingResolved } } do {
                private _st = (_stCandidates select _si) select 1;
                _staging = _st;
                if (count _staging < 3) then { _staging = [(_staging select 0), (_staging select 1), 0] };
                private _roadHit = [_staging, 450, [], _minBase, _baseQ, _objectivePos] call FADE_findOpforGroundVehicleRoadSpawn;
                if !(_roadHit isEqualTo []) then {
                    _roadHit params ["_roadPos", "_dir"];
                    _stagingResolved = true;
                };
                _si = _si + 1;
            };
            if (!_stagingResolved) then {
                private _dirFromBase = _baseQ getDir _objectivePos;
                private _fallbackPos = _baseQ getPos [(_minBase + 50), _dirFromBase];
                private _roadHit2 = [_fallbackPos, 250, [], _minBase, _baseQ, _objectivePos] call FADE_findOpforGroundVehicleRoadSpawn;
                if !(_roadHit2 isEqualTo []) then {
                    _roadHit2 params ["_roadPos", "_dir"];
                    _staging = _fallbackPos;
                    _stagingResolved = true;
                };
            };
            if (!_stagingResolved) exitWith {};
            if ((_roadPos isEqualType []) && { count _roadPos >= 2 } && { count _roadPos < 3 }) then {
                _roadPos = [(_roadPos select 0), (_roadPos select 1), 0];
            };
            private _flF = missionNamespace getVariable ["FADE_qrfSpawnHintFlare", {}];
            if (!(_flF isEqualTo {})) then { [_objectivePos, _detectionRadius] call _flF };
            private _anyPlayersInObjectiveZone = {
                private _ok = false;
                {
                    if (isPlayer _x && { alive _x } && { (_x distance2D _objectivePos) < _detectionRadius }) exitWith { _ok = true };
                } forEach allPlayers;
                _ok
            };
            private _huntQrf = !(call _anyPlayersInObjectiveZone);
            private _centF = missionNamespace getVariable ["FADE_qrfFriendlyCentroidATL", {}];
            private _tgtMove = if (_huntQrf && {!(_centF isEqualTo {})}) then { [_objectivePos] call _centF } else { +_objectivePos };
            if (count _tgtMove < 3) then { _tgtMove = [(_tgtMove select 0), (_tgtMove select 1), 0] };
            private _dir = [_roadPos, _tgtMove] call BIS_fnc_dirTo;
            private _huntIv = (missionNamespace getVariable ["FADE_qrfHuntWaypointIntervalS", 60]) max 15;

            private _vehClasses = missionNamespace getVariable ["FADE_enemyVehicles", []];
            if (_vehClasses isEqualTo []) then {
                private _ef = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
                _vehClasses = [_ef] call FADE_getEnemyVehiclesForFaction;
            };
            private _soft = [];
            {
                if (!(_x isKindOf "Air") && { !(_x isKindOf "Ship") } && { !(_x isKindOf "StaticWeapon") }) then {
                    if (!(_x isKindOf "Tank") && { !(_x isKindOf "Wheeled_APC_F") }) then { _soft pushBack _x };
                };
            } forEach _vehClasses;
            private _minCargo = missionNamespace getVariable ["FADE_counterAttackMinCargoSeats", 4];
            private _vehPick = [];
            private _softOk = [_soft, _minCargo] call FADE_counterAttack_filterClassesByMinCargo;
            if (count _softOk > 0) then {
                _vehPick = _softOk;
            } else {
                private _landAll = _vehClasses select {
                    !(_x isKindOf "Air") && { !(_x isKindOf "Ship") } && { !(_x isKindOf "StaticWeapon") }
                };
                _vehPick = [_landAll, _minCargo] call FADE_counterAttack_filterClassesByMinCargo;
            };
            if (count _vehPick == 0) then {
                private _rhsFb = missionNamespace getVariable ["FADE_counterAttackRhsFallbacks", [
                    "rhs_gaz66_msv",
                    "rhs_zil131_msv",
                    "rhs_kamaz5350_msv",
                    "rhs_kamaz5350_open_msv",
                    "RHS_Ural_Civ_01",
                    "rhsgref_cdf_ural_open"
                ]];
                _vehPick = [_rhsFb, _minCargo] call FADE_counterAttack_filterClassesByMinCargo;
            };
            if (count _vehPick == 0) then {
                private _snCa = missionNamespace getVariable ["FADE_scenarioEnemySideNum", 0];
                private _vanFbDefault = switch (_snCa) do {
                    case 1: { ["B_Truck_01_transport_F", "B_T_Truck_01_transport_F", "I_Truck_02_transport_F", "O_Truck_02_transport_F"] };
                    case 2: { ["I_Truck_02_transport_F", "I_G_Offroad_01_transport_F", "O_Truck_02_transport_F", "B_Truck_01_transport_F"] };
                    default { ["O_Truck_03_transport_F", "O_Truck_02_transport_F", "I_Truck_02_transport_F", "B_Truck_01_transport_F"] };
                };
                private _vanFb = missionNamespace getVariable ["FADE_counterAttackVanillaFallbacks", _vanFbDefault];
                _vehPick = [_vanFb, _minCargo] call FADE_counterAttack_filterClassesByMinCargo;
            };
            if (count _vehPick == 0) exitWith {
                private _sz = 4 + floor random 4;
                private _cls = (_enemyUnits select [0, _sz min count _enemyUnits]);
                for "_k" from (count _cls) to (_sz - 1) do { _cls pushBack (_enemyUnits select 0) };
                private _grp = [_roadPos, _sideEnemy, _cls] call BIS_fnc_spawnGroup;
                if (!isNull _grp && { count units _grp > 0 }) then {
                    [_grp] call _applyGrp;
                    _grp setBehaviour "COMBAT";
                    _grp setCombatMode "RED";
                    private _wp = _grp addWaypoint [_tgtMove, 0];
                    _wp setWaypointType "SAD";
                    _allGroups pushBack _grp;
                    if (_huntQrf) then {
                        [_grp, _taskId, _objectivePos, _huntIv] spawn {
                            params ["_grp", "_taskId", "_objectivePos", "_iv"];
                            private _cf = missionNamespace getVariable ["FADE_qrfFriendlyCentroidATL", {}];
                            private _td = { (_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"] };
                            while { !(isNull _grp) && { count units _grp > 0 } && { !(call _td) } } do {
                                sleep _iv;
                                if (isNull _grp || { count units _grp == 0 } || { call _td }) exitWith {};
                                private _p = if (!(_cf isEqualTo {})) then { [_objectivePos] call _cf } else { +_objectivePos };
                                if (count _p < 3) then { _p = [(_p select 0), (_p select 1), 0] };
                                while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
                                private _w = _grp addWaypoint [_p, 0];
                                _w setWaypointType "SAD";
                            };
                        };
                    };
                };
            };

            private _cargoStagger = missionNamespace getVariable ["FADE_counterAttackCargoStaggerSec", 0.35];
            private _spawnedVehs = [];
            private _roadHit = [];
            private _vClass = "";
            private _anchor = [0, 0, 0];
            private _spawnPos = [0, 0, 0];
            private _spawnDir = 0;
            private _vehGrp = grpNull;
            private _veh = objNull;
            private _driver = objNull;
            private _g = objNull;
            private _wpM = objNull;
            private _wpS = objNull;
            private _prev = objNull;
            for "_vi" from 0 to (_numTrucks - 1) do {
                if (_vi > 0) then { sleep 8 };
                _vClass = selectRandom _vehPick;
                _anchor = if (_vi == 0) then {
                    _roadPos
                } else {
                    _prev = _spawnedVehs select ((count _spawnedVehs) - 1);
                    if (isNull _prev) then { _roadPos } else { (getPosATL _prev) getPos [14, _dir + 180] }
                };
                _roadHit = [_anchor, 450, _spawnedVehs, _minBase, _baseQ, _tgtMove] call FADE_findOpforGroundVehicleRoadSpawn;
                if (_roadHit isEqualTo []) then { continue };
                _roadHit params ["_spawnPos", "_spawnDir"];
                if (_spawnPos distance2D _baseQ <= _minBase) then { continue };
                _vehGrp = createGroup _sideEnemy;
                _veh = createVehicle [_vClass, _spawnPos, [], 0, "NONE"];
                if (isNull _veh) then { deleteGroup _vehGrp; continue };
                _veh setPosATL _spawnPos;
                _veh setDir _spawnDir;
                _veh setVectorUp surfaceNormal _spawnPos;
                _veh setVelocity [(sin _dir) * 2, (cos _dir) * 2, 0];
                _veh engineOn true;
                _spawnedVehs pushBack _veh;
                [_taskId, _veh] call FADE_missionEnt_registerVehicle;
                _driver = _vehGrp createUnit [selectRandom _enemyUnits, _spawnPos, [], 0, "NONE"];
                if (!isNull _driver) then {
                    _driver moveInDriver _veh;
                    _vehGrp selectLeader _driver;
                };
                if (_veh emptyPositions "gunner" > 0) then {
                    _g = _vehGrp createUnit [selectRandom _enemyUnits, _spawnPos, [], 0, "NONE"];
                    if (!isNull _g) then { _g moveInGunner _veh };
                };
                [_vehGrp] call _applyGrp;
                _vehGrp setBehaviour "AWARE";
                _vehGrp setCombatMode "RED";
                _vehGrp setSpeedMode "NORMAL";
                _wpM = _vehGrp addWaypoint [_tgtMove, 25];
                _wpM setWaypointType "MOVE";
                _wpM setWaypointSpeed "NORMAL";
                _wpS = _vehGrp addWaypoint [_tgtMove, 0];
                _wpS setWaypointType "SAD";
                _allGroups pushBack _vehGrp;
                if (_huntQrf) then {
                    [_vehGrp, _veh, _taskId, _objectivePos, _huntIv] spawn {
                        params ["_vehGrp", "_veh", "_taskId", "_objectivePos", "_iv"];
                        private _cf = missionNamespace getVariable ["FADE_qrfFriendlyCentroidATL", {}];
                        private _td = { (_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"] };
                        while { alive _veh && {!isNull _veh} && {!isNull _vehGrp} && { !(call _td) } } do {
                            sleep _iv;
                            if (!alive _veh || { isNull _veh } || { isNull _vehGrp }) exitWith {};
                            private _p = if (!(_cf isEqualTo {})) then { [_objectivePos] call _cf } else { getPosATL _veh };
                            if (count _p < 3) then { _p = [(_p select 0), (_p select 1), 0] };
                            while { count waypoints _vehGrp > 0 } do { deleteWaypoint [_vehGrp, 0] };
                            private _wM = _vehGrp addWaypoint [_p, 25];
                            _wM setWaypointType "MOVE";
                            _wM setWaypointSpeed "NORMAL";
                            private _wS = _vehGrp addWaypoint [_p, 0];
                            _wS setWaypointType "SAD";
                        };
                    };
                };
                [_veh, _vehGrp, _enemyUnits, _applyGrp, _objectivePos, _pollInterval, _allGroups, _cargoStagger, _sideEnemy, _huntQrf, _taskId] spawn {
                    params ["_veh", "_vehGrp", "_enemyUnits", "_applyGrp", "_objectivePos", "_pollInterval", "_allGroups", "_cargoStagger", "_sideEnemy", "_huntQrf", "_taskId"];
                    private _cf = missionNamespace getVariable ["FADE_qrfFriendlyCentroidATL", {}];
                    private _seats = (_veh emptyPositions "cargo") max 0;
                    if (_seats <= 0) exitWith {};
                    private _cargoGrp = createGroup _sideEnemy;
                    for "_c" from 0 to (_seats - 1) do {
                        sleep _cargoStagger;
                        private _u = _cargoGrp createUnit [selectRandom _enemyUnits, getPosATL _veh, [], 0, "NONE"];
                        if (!isNull _u) then { _u moveInCargo _veh };
                    };
                    [_cargoGrp] call _applyGrp;
                    _allGroups pushBack _cargoGrp;
                    [_veh, _enemyUnits] call FADE_ensureEnemyVehicleGunner;
                    [_vehGrp] call _applyGrp;
                    waitUntil {
                        sleep _pollInterval;
                        if (!alive _veh || { isNull _veh }) then {
                            true
                        } else {
                            if (_huntQrf) then {
                                private _c = if (!(_cf isEqualTo {})) then { [_objectivePos] call _cf } else { +_objectivePos };
                                (_veh distance2D _c) < 140
                            } else {
                                (_veh distance2D _objectivePos) < 130
                            }
                        };
                    };
                    if (!alive _veh || { isNull _veh }) exitWith {};
                    if (!isNull _cargoGrp && { count units _cargoGrp > 0 }) then {
                        {
                            unassignVehicle _x;
                            _x action ["GetOut", _veh];
                        } forEach units _cargoGrp;
                        sleep 4;
                        _cargoGrp setBehaviour "COMBAT";
                        _cargoGrp setCombatMode "RED";
                        private _drop = if (_huntQrf && {!(_cf isEqualTo {})}) then { [_objectivePos] call _cf } else { +_objectivePos };
                        if (count _drop < 3) then { _drop = [(_drop select 0), (_drop select 1), 0] };
                        private _wp = _cargoGrp addWaypoint [_drop, 0];
                        _wp setWaypointType "SAD";
                    };
                };
            };
        };

        private _waveNum = 0;
        while { _waveNum < _maxWaves && { !(call _taskDone) } } do {
            _waveNum = _waveNum + 1;
            [_taskId, _objectivePos, _enemyUnits, _allGroups, _numTrucks, _applyGrp, _pollInterval, _detectionRadius] call _waveFn;
            if (call _taskDone) exitWith {};
            if (_waveNum >= _maxWaves) exitWith {};
            private _bw = _betMin + random (_betMax - _betMin);
            sleep _bw;
            if (call _taskDone) exitWith {};
            waitUntil {
                sleep _pollInterval;
                call _taskDone || { call _playersInZone }
            };
            if (call _taskDone) exitWith {};
        };
    };
};
missionNamespace setVariable ["FADE_counterAttackStart", FADE_counterAttackStart];
