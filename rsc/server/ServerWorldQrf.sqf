// ServerWorldQrf.sqf - counter-attack / QRF spawn loop
// -----------------------------------------------------------------------------
// RPT debug: grep "[FAC DbgBrowser 62d308] H21 QRF" (toggle FADE_qrfDebug in ConfigDefaults).
FADE_qrfDbgLog = {
    if !(missionNamespace getVariable ["FADE_qrfDebug", false]) exitWith {};
    if (count _this < 1) exitWith {};
    diag_log format (["[FAC DbgBrowser 62d308] H21 QRF " + (_this select 0)] + (_this select [1, count _this - 1]));
};
missionNamespace setVariable ["FADE_qrfDbgLog", FADE_qrfDbgLog];

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
// One composition for a wave. Population and player count are applied once.
// Returns [footSquads, squadSize, trucks, cargoCap, waveCount].
// -----------------------------------------------------------------------------
FADE_qrfWaveComposition = {
    private _pop = missionNamespace getVariable ["FADE_opforPopulationScale", 1];
    private _playerFactor = if (!isNil "FADE_opforPlayerScaleFactor") then { [] call FADE_opforPlayerScaleFactor } else { 1 };
    private _s = _pop * _playerFactor;
    private _squads = ((round (2 * _s)) max 1) min 3;
    private _size = 4;
    if (_s >= 0.85) then { _size = 5 };
    if (_s >= 1.5) then { _size = 6 };
    private _trucks = ((round (1 * _s)) max 0) min 3;
    private _cargoCap = 8;
    if (_s < 0.75) then { _cargoCap = 4 };
    if (_s >= 0.75 && { _s < 1.5 }) then { _cargoCap = 6 };
    private _waves = (round (missionNamespace getVariable ["FADE_qrfWaveCount", 2])) max 1;
    [_squads, _size, _trucks, _cargoCap, _waves]
};
missionNamespace setVariable ["FADE_qrfWaveComposition", FADE_qrfWaveComposition];

FADE_qrfEnsureWavesLeft = {
    params ["_taskId"];
    private _key = "FADE_qrfWavesLeft_" + _taskId;
    if (isNil { missionNamespace getVariable _key }) then {
        private _n = ([] call FADE_qrfWaveComposition) select 4;
        missionNamespace setVariable [_key, _n];
    };
    missionNamespace getVariable [_key, 0]
};
missionNamespace setVariable ["FADE_qrfEnsureWavesLeft", FADE_qrfEnsureWavesLeft];

FADE_qrfTakeWave = {
    params ["_taskId"];
    private _key = "FADE_qrfWavesLeft_" + _taskId;
    private _n = missionNamespace getVariable [_key, 0];
    if (_n <= 0) exitWith { false };
    missionNamespace setVariable [_key, _n - 1];
    true
};
missionNamespace setVariable ["FADE_qrfTakeWave", FADE_qrfTakeWave];

FADE_qrfNorm3 = {
    params ["_p"];
    if (!(_p isEqualType []) || { count _p < 2 }) exitWith { [0, 0, 0] };
    if (count _p < 3) then { [(_p select 0), (_p select 1), 0] } else { +_p }
};

FADE_counterAttack_missionEnded = {
    params ["_taskId"];
    if (_taskId == "") exitWith { false };
    if (missionNamespace getVariable [format ["FADE_missionEnt_cleaned_%1", _taskId], false]) exitWith { true };
    if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]) exitWith { true };
    if (missionNamespace getVariable ["FADE_raidAborted_" + _taskId, false]) exitWith { true };
    if (missionNamespace getVariable ["FADE_operationAborted_" + _taskId, false]) exitWith { true };
    if (missionNamespace getVariable ["FADE_eeAborted_" + _taskId, false]) exitWith { true };
    false
};
missionNamespace setVariable ["FADE_counterAttack_missionEnded", FADE_counterAttack_missionEnded];

FADE_qrfFriendliesInRadius = {
    params ["_center", ["_radius", 450]];
    if (count _center < 2) exitWith { [] };
    private _sf = missionNamespace getVariable ["FADE_sideFriendly", west];
    allPlayers select {
        alive _x && { isPlayer _x } && { side _x == _sf } && { (_x distance2D _center) <= _radius }
    }
};
missionNamespace setVariable ["FADE_qrfFriendliesInRadius", FADE_qrfFriendliesInRadius];

FADE_qrfKnowsPlayer = {
    params ["_knower", "_player", "_thr"];
    if (isNull _knower || { isNull _player }) exitWith { false };
    private _k = _knower knowsAbout _player;
    private _g = grpNull;
    if (_knower isKindOf "CAManBase") then {
        _g = group _knower;
    } else {
        if (!isNull driver _knower) then {
            _k = _k max ((driver _knower) knowsAbout _player);
            _g = group driver _knower;
        };
    };
    if (!isNull _g) then { _k = _k max (_g knowsAbout _player) };
    _k >= _thr
};

// True when any OPFOR man near the sensor, or an active enemy UAV, knows a friendly player inside it.
FADE_qrfSensorDetected = {
    params ["_center", ["_radius", 450]];
    if (count _center < 2) exitWith { false };
    private _players = [_center, _radius] call FADE_qrfFriendliesInRadius;
    if (_players isEqualTo []) exitWith { false };
    private _thr = missionNamespace getVariable ["FADE_qrfKnowsAboutThreshold", 1.5];
    private _sideE = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _search = (_radius + 600) max 800;
    private _men = (_center nearEntities ["CAManBase", _search]) select {
        alive _x && { !isPlayer _x } && { side _x == _sideE }
    };
    private _found = false;
    {
        private _man = _x;
        {
            if ([_man, _x, _thr] call FADE_qrfKnowsPlayer) exitWith { _found = true };
        } forEach _players;
        if (_found) exitWith {};
    } forEach _men;
    if (_found) exitWith { true };
    {
        private _uav = _x;
        if (!isNull _uav && { alive _uav }) then {
            {
                if ([_uav, _x, _thr] call FADE_qrfKnowsPlayer) exitWith { _found = true };
            } forEach _players;
        };
        if (_found) exitWith {};
    } forEach (missionNamespace getVariable ["FADE_opforDrone_active", []]);
    _found
};
missionNamespace setVariable ["FADE_qrfSensorDetected", FADE_qrfSensorDetected];

// Clear line from a player's eyes to a spawn eye. Terrain and objects both block.
// terrainIntersectASL and lineIntersects return true when the segment is blocked.
FADE_qrfClearLos = {
    params ["_fromASL", "_toASL"];
    if (count _fromASL < 3 || { count _toASL < 3 }) exitWith { false };
    if (terrainIntersectASL [_fromASL, _toASL]) exitWith { false };
    if (lineIntersects [_fromASL, _toASL, objNull, objNull]) exitWith { false };
    true
};
missionNamespace setVariable ["FADE_qrfClearLos", FADE_qrfClearLos];

FADE_qrfPosHiddenFromPlayers = {
    params ["_pos"];
    private _p = [_pos] call FADE_qrfNorm3;
    private _minD = missionNamespace getVariable ["FADE_qrfFootMinFromPlayers", 200];
    private _eyeH = 1.65;
    private _to = (ATLToASL _p) vectorAdd [0, 0, _eyeH];
    private _ok = true;
    private _d = 0;
    private _sideF = missionNamespace getVariable ["FADE_sideFriendly", west];
    {
        if (!isPlayer _x || { !alive _x }) then { continue };
        if (side _x != _sideF) then { continue };
        _d = _x distance2D _p;
        if (_d < _minD) exitWith { _ok = false };
        if ([eyePos _x, _to] call FADE_qrfClearLos) exitWith { _ok = false };
    } forEach allPlayers;
    _ok
};
missionNamespace setVariable ["FADE_qrfPosHiddenFromPlayers", FADE_qrfPosHiddenFromPlayers];

FADE_qrfTrackGroup = {
    params ["_taskId", "_grp", "_allGroups"];
    if (isNull _grp) exitWith {};
    if (_allGroups isEqualType []) then { _allGroups pushBack _grp };
    if (_taskId != "") then { [_taskId, _grp] call FADE_missionEnt_registerGroup };
};

FADE_qrfRandomSpan = {
    params ["_minKey", "_minDef", "_maxKey", "_maxDef"];
    private _a = missionNamespace getVariable [_minKey, _minDef];
    private _b = missionNamespace getVariable [_maxKey, _maxDef];
    if (_b < _a) then { _b = _a };
    _a + random (_b - _a)
};

// Scheduled. Returns "ended", "left", or "ready".
FADE_qrfWaitDelayOrLeave = {
    params ["_taskId", "_center", "_radius", "_seconds", "_poll"];
    private _until = time + _seconds;
    private _state = "ready";
    waitUntil {
        sleep _poll;
        if ([_taskId] call FADE_counterAttack_missionEnded) exitWith { _state = "ended"; true };
        if (([_center, _radius] call FADE_qrfFriendliesInRadius) isEqualTo []) exitWith { _state = "left"; true };
        time >= _until
    };
    _state
};
missionNamespace setVariable ["FADE_qrfWaitDelayOrLeave", FADE_qrfWaitDelayOrLeave];

// Foot squads outside the objective, hidden from players. Returns the groups spawned.
FADE_counterAttack_spawnFootWave = {
    params ["_taskId", "_objectivePos", "_enemyUnits", "_allGroups", ["_squadCount", -1], ["_squadSize", -1]];
    if ([_taskId] call FADE_counterAttack_missionEnded) exitWith {
        ["footWave aborted missionEnded task=%1", _taskId] call FADE_qrfDbgLog;
        []
    };
    if (count _objectivePos < 2 || { count _enemyUnits == 0 }) exitWith {
        ["footWave aborted badArgs task=%1", _taskId] call FADE_qrfDbgLog;
        []
    };
    private _comp = [] call FADE_qrfWaveComposition;
    if (_squadCount < 1) then { _squadCount = _comp select 0 };
    if (_squadSize < 2) then { _squadSize = _comp select 1 };
    private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _distMin = missionNamespace getVariable ["FADE_qrfFootDistMin", 280];
    private _distMax = missionNamespace getVariable ["FADE_qrfFootDistMax", 450];
    if (_distMax < _distMin) then { _distMax = _distMin + 80 };
    private _bldChance = ((missionNamespace getVariable ["FADE_qrfFootBuildingChance", 0.4]) min 1) max 0;
    private _obj3 = [_objectivePos] call FADE_qrfNorm3;
    private _rings = [[_distMin, _distMax], [_distMax, _distMax + 150]];
    private _bearings = [];
    private _spawned = [];
    private _bearing = 0;
    private _tooClose = false;
    private _try = 0;
    private _ring = [];
    private _rMin = 0;
    private _rMax = 0;
    private _unitPositions = [];
    private _usedBuilding = false;
    private _bld = objNull;
    private _bps = [];
    private _spawnPos = [];
    private _raw = [];
    private _cand = [];
    private _tryBearing = 0;
    private _tryDist = 0;
    private _cls = [];
    private _grp = grpNull;
    private _placed = false;
    private _bldCandidates = [];
    private _want = 0;
    private _bp = [];
    private _off = [0, 0];
    private _up = [0, 0, 0];
    private _unitPos = "";
    private _wpM = objNull;
    private _wpS = objNull;
    ["footWave start task=%1 squads=%2 size=%3 obj=%4 dist=%5-%6", _taskId, _squadCount, _squadSize, _obj3, _distMin, _distMax] call FADE_qrfDbgLog;
    for "_i" from 1 to _squadCount do {
        _placed = false;
        {
            if (_placed) exitWith {};
            _ring = _x;
            _rMin = _ring select 0;
            _rMax = _ring select 1;
            for "_t" from 0 to 11 do {
                if (_placed) exitWith {};
                _bearing = random 360;
                _tooClose = true;
                _try = 0;
                while { _tooClose && { _try < 12 } } do {
                    _bearing = random 360;
                    _tooClose = false;
                    { if (abs ((_bearing - _x + 540) % 360 - 180) < 45) exitWith { _tooClose = true } } forEach _bearings;
                    _try = _try + 1;
                };
                _unitPositions = [];
                _usedBuilding = false;
                if (_forEachIndex == 0 && { random 1 < _bldChance }) then {
                    _bldCandidates = nearestObjects [_obj3, ["House", "Building"], _rMax];
                    if (count _bldCandidates > 24) then {
                        _bldCandidates = (_bldCandidates call BIS_fnc_arrayShuffle) select [0, 24];
                    };
                    _bldCandidates = _bldCandidates select {
                        private _housePos = getPosATL _x;
                        (_housePos distance2D _obj3) >= _rMin &&
                        { [_housePos] call FADE_qrfPosHiddenFromPlayers } &&
                        { count (_x buildingPos -1) >= 1 }
                    };
                    if (count _bldCandidates > 0) then {
                        _bld = selectRandom _bldCandidates;
                        _bps = (_bld buildingPos -1) call BIS_fnc_arrayShuffle;
                        _want = _squadSize min count _bps;
                        for "_bi" from 0 to (_want - 1) do {
                            _bp = [_bps select _bi] call FADE_qrfNorm3;
                            if ([_bp] call FADE_qrfPosHiddenFromPlayers && { [_bp, 12] call FADE_posClearOfWater }) then {
                                _unitPositions pushBack _bp;
                            };
                        };
                        if (count _unitPositions > 0) then { _usedBuilding = true } else { _unitPositions = [] };
                    };
                };
                if (!_usedBuilding) then {
                    _tryBearing = _bearing;
                    _tryDist = _rMin + random ((_rMax - _rMin) max 1);
                    _raw = [_obj3 getPos [_tryDist, _tryBearing]] call FADE_qrfNorm3;
                    _cand = [[_raw, 0, 28, 2, 0, 0.55, 0, [], _raw]] call FADE_findLandPosWithArgs;
                    if (count _cand < 2) then { continue };
                    _cand = [_cand] call FADE_qrfNorm3;
                    if !([_cand, 15] call FADE_posClearOfWater) then { continue };
                    if ((_cand distance2D _obj3) < (_rMin * 0.85)) then { continue };
                    if ((_cand distance2D _obj3) > (_rMax + 35)) then { continue };
                    if !([_cand] call FADE_qrfPosHiddenFromPlayers) then { continue };
                    _spawnPos = _cand;
                    _bearing = _tryBearing;
                    for "_u" from 1 to _squadSize do {
                        _off = if (_u == 1) then { [0, 0] } else { [3 + random 6, random 360] };
                        _up = if (_off isEqualTo [0, 0]) then { +_spawnPos } else { _spawnPos getPos [_off select 0, _off select 1] };
                        _up = [_up] call FADE_qrfNorm3;
                        if !([_up, 8] call FADE_posClearOfWater) then { _up = +_spawnPos };
                        _unitPositions pushBack _up;
                    };
                };
                if (_unitPositions isEqualTo []) then { continue };
                _bearings pushBack _bearing;
                _cls = [];
                for "_u" from 1 to (count _unitPositions) do { _cls pushBack (selectRandom _enemyUnits) };
                _unitPos = if (_usedBuilding) then { "MIDDLE" } else { "" };
                _grp = [_unitPositions, _sideEnemy, _cls, _unitPos, false, "zip"] call FADE_spawnInfantryAtPositions;
                if (isNull _grp || { count units _grp == 0 }) then { continue };
                _grp setBehaviour "COMBAT";
                _grp setCombatMode "RED";
                _grp setSpeedMode "FULL";
                _wpM = _grp addWaypoint [_obj3, 30];
                _wpM setWaypointType "MOVE";
                _wpM setWaypointSpeed "FULL";
                _wpS = _grp addWaypoint [_obj3, 0];
                _wpS setWaypointType "SAD";
                [_taskId, _grp, _allGroups] call FADE_qrfTrackGroup;
                _spawned pushBack _grp;
                _placed = true;
                ["footWave squad task=%1 grp=%2 units=%3 building=%4 bearing=%5", _taskId, _grp, count units _grp, _usedBuilding, _bearing] call FADE_qrfDbgLog;
            };
        } forEach _rings;
        if (!_placed) then {
            ["footWave skipSquad task=%1 noHiddenPos", _taskId] call FADE_qrfDbgLog;
        };
    };
    ["footWave done task=%1 spawned=%2/%3", _taskId, count _spawned, _squadCount] call FADE_qrfDbgLog;
    _spawned
};
missionNamespace setVariable ["FADE_counterAttack_spawnFootWave", FADE_counterAttack_spawnFootWave];

FADE_qrfRetargetGroup = {
    params ["_grp", "_pos", ["_completion", 25]];
    if (isNull _grp || { count _pos < 2 }) exitWith {};
    private _p = [_pos] call FADE_qrfNorm3;
    while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
    private _wM = _grp addWaypoint [_p, _completion];
    _wM setWaypointType "MOVE";
    _wM setWaypointSpeed "NORMAL";
    private _wS = _grp addWaypoint [_p, 0];
    _wS setWaypointType "SAD";
};
missionNamespace setVariable ["FADE_qrfRetargetGroup", FADE_qrfRetargetGroup];

FADE_qrfReleaseCargo = {
    params ["_veh", "_cargoGrp", "_dest"];
    if (isNull _cargoGrp || { count units _cargoGrp == 0 }) exitWith {};
    {
        if (!isNull _x && { alive _x }) then {
            unassignVehicle _x;
            if (!isNull _veh && { alive _veh } && { vehicle _x == _veh }) then {
                _x action ["GetOut", _veh];
            };
        };
    } forEach units _cargoGrp;
    if (!isNull _veh && { alive _veh }) then { sleep 4 };
    if (isNull _cargoGrp || { count units _cargoGrp == 0 }) exitWith {};
    _cargoGrp setBehaviour "COMBAT";
    _cargoGrp setCombatMode "RED";
    private _drop = [_dest] call FADE_qrfNorm3;
    ["cargoUnload units=%1 drop=%2 vehAlive=%3", { alive _x } count units _cargoGrp, _drop, (!isNull _veh && { alive _veh })] call FADE_qrfDbgLog;
    private _wp = _cargoGrp addWaypoint [_drop, 0];
    _wp setWaypointType "SAD";
};
missionNamespace setVariable ["FADE_qrfReleaseCargo", FADE_qrfReleaseCargo];

FADE_qrfPickTransportClasses = {
    private _vehClasses = missionNamespace getVariable ["FADE_enemyVehicles", []];
    if (_vehClasses isEqualTo []) then {
        private _ef = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
        if (!isNil "FADE_getEnemyVehiclesForFaction") then {
            _vehClasses = [_ef] call FADE_getEnemyVehiclesForFaction;
        };
    };
    private _soft = [];
    {
        if (!(_x isKindOf "Air") && { !(_x isKindOf "Ship") } && { !(_x isKindOf "StaticWeapon") }) then {
            if (!(_x isKindOf "Tank") && { !(_x isKindOf "Wheeled_APC_F") }) then { _soft pushBack _x };
        };
    } forEach _vehClasses;
    private _minCargo = missionNamespace getVariable ["FADE_qrfMinCargoSeats", 4];
    private _vehPick = [_soft, _minCargo] call FADE_counterAttack_filterClassesByMinCargo;
    if (count _vehPick == 0) then {
        private _rhsFb = missionNamespace getVariable ["FADE_qrfRhsFallbacks", [
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
        private _vanFb = missionNamespace getVariable ["FADE_qrfVanillaFallbacks", _vanFbDefault];
        _vehPick = [_vanFb, _minCargo] call FADE_counterAttack_filterClassesByMinCargo;
    };
    _vehPick
};
missionNamespace setVariable ["FADE_qrfPickTransportClasses", FADE_qrfPickTransportClasses];

// Returns [posATL, dir] or []. Optional _stagingAnchor is tried before civ-zone offsets.
FADE_qrfResolveRoadSpawn = {
    params ["_taskId", "_objectivePos", ["_stagingAnchor", []]];
    private _obj = [_objectivePos] call FADE_qrfNorm3;
    private _pairs = [];
    {
        private _trig = missionNamespace getVariable [_x, objNull];
        if (!isNull _trig) then {
            private _zc = getPosATL _trig;
            if (count _zc >= 2) then { _pairs pushBack [_zc distance2D _obj, [_zc] call FADE_qrfNorm3] };
        };
    } forEach (missionNamespace getVariable ["FADE_civTriggerNames", []]);
    if (_pairs isEqualTo [] && { count _stagingAnchor < 2 }) exitWith {
        ["vehicleWave aborted noCivZones task=%1", _taskId] call FADE_qrfDbgLog;
        []
    };
    if !(_pairs isEqualTo []) then {
        _pairs = [_pairs, [], { _x select 0 }, "ASCEND"] call BIS_fnc_sortBy;
    };
    private _minBase = missionNamespace getVariable ["FADE_qrfMinDistFromBase", 1000];
    private _baseQ = [FADE_basePos] call FADE_qrfNorm3;
    private _roadPos = [];
    private _roadDir = 0;
    private _stagingResolved = false;
    private _nearOnly = if (_pairs isEqualTo []) then { _obj } else { (_pairs select 0) select 1 };
    private _stCandidates = [];
    private _anchor3 = [];
    if (count _stagingAnchor >= 2) then {
        _anchor3 = [_stagingAnchor] call FADE_qrfNorm3;
        _stCandidates pushBack _anchor3;
        _stCandidates pushBack (_anchor3 getPos [400 + random 300, _anchor3 getDir _obj]);
        _stCandidates pushBack (_anchor3 getPos [700 + random 400, (_anchor3 getDir _obj) + 180]);
    };
    private _zoneIdxList = [];
    if (count _pairs >= 2) then { _zoneIdxList pushBack 1 };
    if (count _pairs >= 3) then { _zoneIdxList pushBack 2 };
    if (count _pairs >= 1) then { _zoneIdxList pushBack 0 };
    if (count _pairs >= 4) then { _zoneIdxList pushBack 3 };
    {
        private _zc = (_pairs select _x) select 1;
        private _away = _obj getDir _zc;
        if (_zc distance2D _obj < 50) then { _away = _baseQ getDir _obj };
        _stCandidates pushBack (_zc getPos [700 + random 500, _away]);
        _stCandidates pushBack (_zc getPos [1100 + random 700, _away + 40 + random 80]);
        _stCandidates pushBack (_zc getPos [900 + random 600, _away + 180]);
        _stCandidates pushBack _zc;
    } forEach _zoneIdxList;
    if !(_pairs isEqualTo []) then {
        _stCandidates pushBack (_nearOnly getPos [600 min ((_nearOnly distance2D _obj) + 400), (_nearOnly getDir _obj) + 180]);
    };
    _stCandidates pushBack (_obj getPos [1200 + random 800, random 360]);
    private _dirFromBase = _baseQ getDir _obj;
    _stCandidates pushBack (_baseQ getPos [(_minBase + 80 + random 200), _dirFromBase]);
    private _tryRoad = {
        params ["_anchor", "_searchM", "_terrClear"];
        if (count _anchor < 2) exitWith { [] };
        private _a = [_anchor] call FADE_qrfNorm3;
        [_a, _searchM, [], _minBase, _baseQ, _obj, 12, 8, _terrClear] call FADE_findOpforGroundVehicleRoadSpawn
    };
    private _si = 0;
    private _hit = [];
    private _staging = [];
    while { _si < count _stCandidates && { !_stagingResolved } } do {
        _staging = _stCandidates select _si;
        _hit = [_staging, 700, 10] call _tryRoad;
        if (_hit isEqualTo []) then { _hit = [_staging, 900, 4] call _tryRoad };
        if (_hit isEqualTo []) then { _hit = [_staging, 1200, 2] call _tryRoad };
        if !(_hit isEqualTo []) then {
            _roadPos = +(_hit select 0);
            _roadDir = _hit select 1;
            _stagingResolved = true;
        };
        _si = _si + 1;
    };
    if (!_stagingResolved) then {
        private _fbAnchors = [_obj getPos [1400 + random 600, random 360]];
        if (count _stagingAnchor >= 2) then { _fbAnchors pushBack _anchor3 };
        if !(_pairs isEqualTo []) then {
            _fbAnchors pushBack (_nearOnly getPos [1000 + random 500, random 360]);
        };
        _fbAnchors pushBack (_baseQ getPos [(_minBase + 100), _dirFromBase]);
        private _anc = [0, 0, 0];
        private _roads = [];
        private _rp = [0, 0, 0];
        private _probe = [];
        {
            if (_stagingResolved) exitWith {};
            _anc = [_x] call FADE_qrfNorm3;
            _roads = _anc nearRoads 1500;
            if (count _roads > 24) then {
                _roads = _roads call BIS_fnc_arrayShuffle;
                _roads = _roads select [0, 24];
            };
            {
                _rp = [getPosATL _x] call FADE_qrfNorm3;
                if (surfaceIsWater _rp) then { continue };
                if (_rp distance2D _baseQ <= _minBase) then { continue };
                _probe = [[_rp, 0, 12, 6, 0, 0.4, 0, [], _rp], _rp] call FADE_findSafePosArray;
                if (!(_probe isEqualType []) || { count _probe < 2 } || { surfaceIsWater _probe }) then { continue };
                _probe = [_probe] call FADE_qrfNorm3;
                if (_probe distance2D _baseQ <= _minBase) then { continue };
                _roadPos = _probe;
                _roadDir = [_probe, _obj] call BIS_fnc_dirTo;
                _stagingResolved = true;
                break;
            } forEach _roads;
        } forEach _fbAnchors;
    };
    if (!_stagingResolved) exitWith {
        ["vehicleWave aborted noRoadSpawn task=%1 obj=%2 candidates=%3", _taskId, _obj, count _stCandidates] call FADE_qrfDbgLog;
        []
    };
    if (count _roadPos < 3) then { _roadPos = [_roadPos] call FADE_qrfNorm3 };
    [_roadPos, _roadDir]
};
missionNamespace setVariable ["FADE_qrfResolveRoadSpawn", FADE_qrfResolveRoadSpawn];

// Scheduled. Returns spawned trucks. _followUnit retargets the driver until dismount (Escape & Evasion).
FADE_qrfSpawnTrucks = {
    params [
        "_taskId", "_objectivePos", "_enemyUnits", "_allGroups",
        "_truckCount", "_cargoCap", ["_stagingAnchor", []], ["_followUnit", objNull], ["_markOpQrf", false]
    ];
    if (_truckCount <= 0) exitWith { [] };
    if ([_taskId] call FADE_counterAttack_missionEnded) exitWith { [] };
    private _obj = [_objectivePos] call FADE_qrfNorm3;
    private _roadPack = [_taskId, _obj, _stagingAnchor] call FADE_qrfResolveRoadSpawn;
    if (_roadPack isEqualTo []) exitWith { [] };
    private _roadPos = _roadPack select 0;
    private _roadDir = _roadPack select 1;
    private _vehPick = [] call FADE_qrfPickTransportClasses;
    private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _applyGrp = missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}];
    private _poll = (missionNamespace getVariable ["FADE_qrfPollInterval", 10]) max 1;
    private _stagger = missionNamespace getVariable ["FADE_qrfCargoStaggerSec", 0.35];
    private _followIv = (missionNamespace getVariable ["FADE_qrfFollowIntervalS", 60]) max 15;
    private _baseQ = [FADE_basePos] call FADE_qrfNorm3;
    private _minBase = missionNamespace getVariable ["FADE_qrfMinDistFromBase", 1000];
    private _spawned = [];
    private _dir = [_roadPos, _obj] call BIS_fnc_dirTo;
    if (_vehPick isEqualTo []) exitWith {
        ["vehicleWave aborted noTruckClass task=%1", _taskId] call FADE_qrfDbgLog;
        []
    };
        ["vehicleWave trucks task=%1 count=%2 cargoCap=%3 road=%4", _taskId, _truckCount, _cargoCap, _roadPos] call FADE_qrfDbgLog;
        private _vClass = "";
        private _anchor = [0, 0, 0];
        private _spawnPos = [0, 0, 0];
        private _spawnDir = 0;
        private _roadHit = [];
        private _crewPack = [];
        private _veh = objNull;
        private _vehGrp = grpNull;
        private _prev = objNull;
        private _fbRoads = [];
        private _rp = [0, 0, 0];
        private _gapOk = true;
        private _firstDest = [0, 0, 0];
        for "_vi" from 0 to (_truckCount - 1) do {
            if (_vi > 0) then { sleep 8 };
            if ([_taskId] call FADE_counterAttack_missionEnded) exitWith {};
            _vClass = selectRandom _vehPick;
            if (_vi == 0) then {
                _spawnPos = +_roadPos;
                _spawnDir = _roadDir;
            } else {
                if (count _spawned > 0) then {
                    _prev = _spawned select ((count _spawned) - 1);
                    _anchor = if (isNull _prev) then { +_roadPos } else { (getPosATL _prev) getPos [14, _dir + 180] };
                } else {
                    _anchor = _roadPos getPos [14 * _vi, _dir + 180];
                };
                _anchor = [_anchor] call FADE_qrfNorm3;
                _roadHit = [_anchor, 700, _spawned, _minBase, _baseQ, _obj, 12, 8, 4] call FADE_findOpforGroundVehicleRoadSpawn;
                if (_roadHit isEqualTo []) then {
                    _roadHit = [_anchor, 900, _spawned, _minBase, _baseQ, _obj, 12, 8, 2] call FADE_findOpforGroundVehicleRoadSpawn;
                };
                if (_roadHit isEqualTo []) then {
                    _fbRoads = _anchor nearRoads 600;
                    if (count _fbRoads > 16) then {
                        _fbRoads = _fbRoads call BIS_fnc_arrayShuffle;
                        _fbRoads = _fbRoads select [0, 16];
                    };
                    _roadHit = [];
                    {
                        _rp = [getPosATL _x] call FADE_qrfNorm3;
                        if (surfaceIsWater _rp) then { continue };
                        if (_rp distance2D _baseQ <= _minBase) then { continue };
                        _gapOk = true;
                        {
                            if (!isNull _x && { alive _x } && { (_x distance2D _rp) < 12 }) then { _gapOk = false };
                        } forEach _spawned;
                        if (!_gapOk) then { continue };
                        _roadHit = [_rp, [_rp, _obj] call BIS_fnc_dirTo];
                        break;
                    } forEach _fbRoads;
                };
                if (_roadHit isEqualTo []) then {
                    ["vehicleWave skipTruck task=%1 idx=%2 noRoadNear", _taskId, _vi] call FADE_qrfDbgLog;
                    continue
                };
                _spawnPos = [_roadHit select 0] call FADE_qrfNorm3;
                _spawnDir = _roadHit select 1;
            };
            if (_spawnPos distance2D _baseQ <= _minBase) then {
                ["vehicleWave skipTruck task=%1 idx=%2 tooNearBase", _taskId, _vi] call FADE_qrfDbgLog;
                continue
            };
            _crewPack = [
                _vClass, _spawnPos, _spawnDir, _enemyUnits, _sideEnemy,
                ["driver", "gunner"], "random", true, -1, 2, _dir, 1, _taskId
            ] call FADE_spawnCrewedGroundVehicle;
            _veh = _crewPack select 0;
            _vehGrp = _crewPack select 1;
            if (isNull _veh) then {
                ["vehicleWave skipTruck task=%1 idx=%2 createFailed class=%3", _taskId, _vi, _vClass] call FADE_qrfDbgLog;
                continue
            };
            _spawned pushBack _veh;
            if (isNull _vehGrp) then { _vehGrp = createGroup _sideEnemy };
            _vehGrp setBehaviour "AWARE";
            _vehGrp setCombatMode "RED";
            _vehGrp setSpeedMode "NORMAL";
            _veh engineOn true;
            if (_markOpQrf) then { _veh setVariable ["FADE_opVehQrf", true, false] };
            [_taskId, _vehGrp, _allGroups] call FADE_qrfTrackGroup;
            if (_taskId != "") then { [_taskId, _veh] call FADE_missionEnt_registerVehicle };
            ["vehicleWave spawned task=%1 idx=%2 class=%3 pos=%4", _taskId, _vi, _vClass, _spawnPos] call FADE_qrfDbgLog;
            _firstDest = _obj;
            if (!isNull _followUnit && { alive _followUnit }) then { _firstDest = [getPosATL _followUnit] call FADE_qrfNorm3 };
            [_vehGrp, _firstDest, 25] call FADE_qrfRetargetGroup;
            [_veh, _vehGrp, _enemyUnits, _applyGrp, _obj, _poll, _allGroups, _stagger, _sideEnemy, _followUnit, _taskId, _cargoCap, _followIv, _markOpQrf] spawn {
                params [
                    "_veh", "_vehGrp", "_enemyUnits", "_applyGrp", "_obj", "_poll", "_allGroups",
                    "_stagger", "_sideEnemy", "_followUnit", "_taskId", "_cargoCap", "_followIv", "_markOpQrf"
                ];
                private _seats = (_veh emptyPositions "cargo") max 0;
                private _fill = _seats min (_cargoCap max 0);
                if (_fill <= 0) exitWith {};
                private _cargoGrp = createGroup _sideEnemy;
                for "_c" from 0 to (_fill - 1) do {
                    sleep _stagger;
                    if (isNull _veh || { !alive _veh }) exitWith {};
                    private _u = _cargoGrp createUnit [selectRandom _enemyUnits, getPosATL _veh, [], 0, "NONE"];
                    if (!isNull _u) then { _u moveInCargo _veh };
                };
                if (!(_applyGrp isEqualTo {})) then {
                    [_cargoGrp] call _applyGrp;
                    [_vehGrp] call _applyGrp;
                };
                [_taskId, _cargoGrp, _allGroups] call FADE_qrfTrackGroup;
                _veh setVariable ["FADE_qrfCargoGrp", _cargoGrp, false];
                if (_markOpQrf) then { _veh setVariable ["FADE_opCargoGrp", _cargoGrp, false] };
                if (!isNull _followUnit) then { _veh setVariable ["FADE_eeQrfCargoGrp", _cargoGrp, false] };
                if (!isNil "FADE_ensureEnemyVehicleGunner") then { [_veh, _enemyUnits] call FADE_ensureEnemyVehicleGunner };
                private _next = time;
                private _dest = _obj;
                waitUntil {
                    sleep _poll;
                    if (!alive _veh || { isNull _veh }) exitWith { true };
                    if ([_taskId] call FADE_counterAttack_missionEnded) exitWith { true };
                    _dest = _obj;
                    if (!isNull _followUnit && { alive _followUnit }) then { _dest = [getPosATL _followUnit] call FADE_qrfNorm3 };
                    if (!isNull _followUnit && { time >= _next }) then {
                        [_vehGrp, _dest, 25] call FADE_qrfRetargetGroup;
                        _next = time + _followIv;
                    };
                    (_veh distance2D _dest) < 130
                };
                if ([_taskId] call FADE_counterAttack_missionEnded) exitWith {};
                if (isNull _followUnit || { !alive _followUnit }) then { _dest = _obj };
                [_veh, _cargoGrp, _dest] call FADE_qrfReleaseCargo;
            };
        };
    ["vehicleWave done task=%1 trucksSpawned=%2/%3", _taskId, count _spawned, _truckCount] call FADE_qrfDbgLog;
    _spawned
};
missionNamespace setVariable ["FADE_qrfSpawnTrucks", FADE_qrfSpawnTrucks];

// Scheduled. Returns [footGroups, trucks]. Does not spend a wave; the caller does that.
FADE_qrfSpawnWave = {
    params [
        "_taskId", "_objectivePos", "_enemyUnits", "_allGroups",
        ["_stagingAnchor", []], ["_followUnit", objNull], ["_markOpQrf", false]
    ];
    if ([_taskId] call FADE_counterAttack_missionEnded) exitWith { [[], []] };
    private _comp = [] call FADE_qrfWaveComposition;
    _comp params ["_squads", "_sqSize", "_trucks", "_cargoCap"];
    private _radius = missionNamespace getVariable ["FADE_qrfDetectionRadius", 450];
    private _fl = missionNamespace getVariable ["FADE_qrfSpawnHintFlare", {}];
    if !(_fl isEqualTo {}) then { [_objectivePos, _radius] call _fl };
    ["spawnWave task=%1 squads=%2 size=%3 trucks=%4 cargo=%5", _taskId, _squads, _sqSize, _trucks, _cargoCap] call FADE_qrfDbgLog;
    private _foot = [_taskId, _objectivePos, _enemyUnits, _allGroups, _squads, _sqSize] call FADE_counterAttack_spawnFootWave;
    private _vehs = [_taskId, _objectivePos, _enemyUnits, _allGroups, _trucks, _cargoCap, _stagingAnchor, _followUnit, _markOpQrf] call FADE_qrfSpawnTrucks;
    [_foot, _vehs]
};
missionNamespace setVariable ["FADE_qrfSpawnWave", FADE_qrfSpawnWave];

// One loop per task. Later calls only add sensors: [pos, radius, groupArray, unitClasses].
FADE_counterAttackStart = {
    params [
        "_taskId",
        "_objectivePos",
        "_basePos",
        "_enemyUnits",
        "_allGroups",
        ["_detectionRadius", -1]
    ];
    if (!isServer) exitWith {};
    if (_taskId == "" || { count _objectivePos < 2 } || { count _enemyUnits == 0 }) exitWith {
        ["start aborted badArgs task=%1", _taskId] call FADE_qrfDbgLog;
    };
    if (_detectionRadius <= 0) then {
        _detectionRadius = missionNamespace getVariable ["FADE_qrfDetectionRadius", 450];
    };
    private _obj3 = [_objectivePos] call FADE_qrfNorm3;
    private _key = "FADE_qrfSensors_" + _taskId;
    private _sensors = missionNamespace getVariable [_key, []];
    _sensors pushBack [_obj3, _detectionRadius, _allGroups, _enemyUnits];
    missionNamespace setVariable [_key, _sensors];
    if (missionNamespace getVariable ["FADE_qrfController_" + _taskId, false]) exitWith {
        ["sensorAdded task=%1 sensors=%2 radius=%3", _taskId, count _sensors, _detectionRadius] call FADE_qrfDbgLog;
    };
    missionNamespace setVariable ["FADE_qrfController_" + _taskId, true];
    [_taskId] call FADE_qrfEnsureWavesLeft;
    ["start task=%1 obj=%2 radius=%3 waves=%4", _taskId, _obj3, _detectionRadius, missionNamespace getVariable ["FADE_qrfWavesLeft_" + _taskId, 0]] call FADE_qrfDbgLog;
    [_taskId, _key] spawn {
        params ["_taskId", "_key"];
        private _poll = (missionNamespace getVariable ["FADE_qrfPollInterval", 10]) max 1;
        private _holding = false;
        private _center = [0, 0, 0];
        private _radius = 450;
        private _groups = [];
        private _units = [];
        private _found = [];
        private _sensors = [];
        private _state = "";
        private _pack = [];
        private _foot = [];
        private _vehs = [];
        private _delay = 0;
        private _bw = 0;
        while {
            !([_taskId] call FADE_counterAttack_missionEnded) &&
            { (missionNamespace getVariable ["FADE_qrfWavesLeft_" + _taskId, 0]) > 0 }
        } do {
            _poll = (missionNamespace getVariable ["FADE_qrfPollInterval", 10]) max 1;
            if (!_holding) then {
                _found = [];
                _state = "";
                waitUntil {
                    sleep _poll;
                    if ([_taskId] call FADE_counterAttack_missionEnded) exitWith { true };
                    _sensors = missionNamespace getVariable [_key, []];
                    {
                        _x params ["_c", "_r", "_grps", "_u"];
                        if ([_c, _r] call FADE_qrfSensorDetected) exitWith {
                            _found = [_c, _r, _grps, _u];
                        };
                    } forEach _sensors;
                    count _found > 0
                };
                if ([_taskId] call FADE_counterAttack_missionEnded) then {
                    _state = "ended";
                } else {
                    _center = _found select 0;
                    _radius = _found select 1;
                    _groups = _found select 2;
                    _units = _found select 3;
                    ["playerDetected task=%1 obj=%2 radius=%3 via=opforKnowsAbout", _taskId, _center, _radius] call FADE_qrfDbgLog;
                    _delay = ["FADE_qrfFirstDelayMin", 120, "FADE_qrfFirstDelayMax", 360] call FADE_qrfRandomSpan;
                    ["firstDelay task=%1 sleeping %2s", _taskId, round _delay] call FADE_qrfDbgLog;
                    _state = [_taskId, _center, _radius, _delay, _poll] call FADE_qrfWaitDelayOrLeave;
                };
            } else {
                _bw = ["FADE_qrfBetweenMin", 540, "FADE_qrfBetweenMax", 660] call FADE_qrfRandomSpan;
                ["betweenWaves task=%1 sleeping %2s", _taskId, round _bw] call FADE_qrfDbgLog;
                _state = [_taskId, _center, _radius, _bw, _poll] call FADE_qrfWaitDelayOrLeave;
            };
            if (_state == "ended" || { [_taskId] call FADE_counterAttack_missionEnded }) exitWith {};
            if (_state == "left") then {
                ["cancelled task=%1 reason=zoneEmpty", _taskId] call FADE_qrfDbgLog;
                _holding = false;
                continue
            };
            if (([_center, _radius] call FADE_qrfFriendliesInRadius) isEqualTo []) then {
                ["cancelled task=%1 reason=zoneEmpty atSpawn", _taskId] call FADE_qrfDbgLog;
                _holding = false;
                continue
            };
            _pack = [_taskId, _center, _units, _groups, [], objNull, false] call FADE_qrfSpawnWave;
            _foot = _pack select 0;
            _vehs = _pack select 1;
            if ((count _foot) == 0 && { (count _vehs) == 0 }) then {
                ["spawnWave empty task=%1 waveNotSpent", _taskId] call FADE_qrfDbgLog;
                _holding = false;
            } else {
                [_taskId] call FADE_qrfTakeWave;
                _holding = (missionNamespace getVariable ["FADE_qrfWavesLeft_" + _taskId, 0]) > 0;
                ["spawnWave committed task=%1 foot=%2 trucks=%3 wavesLeft=%4", _taskId, count _foot, count _vehs, missionNamespace getVariable ["FADE_qrfWavesLeft_" + _taskId, 0]] call FADE_qrfDbgLog;
            };
        };
        missionNamespace setVariable ["FADE_qrfController_" + _taskId, false];
        ["controllerStop task=%1", _taskId] call FADE_qrfDbgLog;
    };
};
missionNamespace setVariable ["FADE_counterAttackStart", FADE_counterAttackStart];

