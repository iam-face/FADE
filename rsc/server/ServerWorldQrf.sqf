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
// Counter-attack / QRF (HVT, Hostage, Clear Area, Search & Destroy, Troop Extract, CASEVAC, CSAR, Asset Retrieval, CAS) - reusable server spawn loop.
// Stages truck-mounted infantry from offsets near secondary civ zones (town centres fail strict road clear);
// falls back to looser terrainClear / nearRoads soft spawn if needed.
// Params: [_taskId, _objectivePos, _basePos, _enemyUnits, _allGroups, _detectionRadius, _skipDetectionWait]
//   _allGroups - reference array; new enemy groups are pushBack'd for mission cleanup.
//   _detectionRadius - optional; <= 0 uses missionNamespace FADE_counterAttackDetectionRadius (default 450).
//   _skipDetectionWait - optional; if true, skip detection poll and start first-wave delay immediately (CAS: when friendlies mark).
// Detection (when not skipped): non-civ AI in radius knowsAbout a player (BLUFOR/OPFOR), OR player proximity fallback.
// Timing defaults (optional missionNamespace): FADE_counterAttackFirstDelayMin/Max (120-360s),
//   FADE_counterAttackBetweenMin/Max (540-660s), FADE_counterAttackTruckCount (3).
// Vehicle filter: FADE_counterAttackMinCargoSeats (default 4). Fallback trucks if faction has none:
//   FADE_counterAttackRhsFallbacks (RHS GAZ/ZIL/Kamaz/Ural-style), then FADE_counterAttackVanillaFallbacks.
// Poll interval: FADE_counterAttackPollInterval (default 10s) for zone/task checks (not per-frame).
// Wave cap: 1-3 waves per mission instance (chosen at random when the counter-attack thread starts).
// Truck staging: offsets from civ zones + loose terrainClear retry + nearRoads soft fallback (town centres fail strict clear).
// If no player remains inside the objective detection radius when a wave spawns, trucks hunt a friendly
// player centroid; driver MOVE+SAD waypoints refresh every FADE_qrfHuntWaypointIntervalS (default 60).
// Not registered with FADE_registerEnemyRetreat (QRF keeps pressure); cleaned with mission groups.
// -----------------------------------------------------------------------------
FADE_counterAttack_missionEnded = {
    params ["_taskId"];
    if (_taskId == "") exitWith { false };
    if (missionNamespace getVariable [format ["FADE_missionEnt_cleaned_%1", _taskId], false]) exitWith { true };
    if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]) exitWith { true };
    if (missionNamespace getVariable ["FADE_raidAborted_" + _taskId, false]) exitWith { true };
    false
};

// True when any non-civilian AI within _radius of _center has knowsAbout >= threshold on an alive player.
// Includes BLUFOR and OPFOR (and resistance): RAID QRF reacts to contact / spotting in the AO, not only player proximity.
FADE_counterAttack_aiDetectsPlayersInArea = {
    params ["_center", ["_radius", 350], ["_knowsThr", -1]];
    if (count _center < 2) exitWith { false };
    if (_knowsThr < 0) then {
        _knowsThr = missionNamespace getVariable ["FADE_counterAttackKnowsAboutThreshold", 1.2];
    };
    private _players = allPlayers select { alive _x && { isPlayer _x } };
    if (_players isEqualTo []) exitWith { false };
    private _aiNear = (_center nearEntities ["CAManBase", _radius]) select {
        alive _x && { !isPlayer _x } && { side _x != civilian }
    };
    if (_aiNear isEqualTo []) exitWith { false };
    private _found = false;
    {
        private _ai = _x;
        {
            if ((_ai knowsAbout _x) >= _knowsThr) exitWith { _found = true };
        } forEach _players;
        if (_found) exitWith {};
    } forEach _aiNear;
    _found
};
missionNamespace setVariable ["FADE_counterAttack_aiDetectsPlayersInArea", FADE_counterAttack_aiDetectsPlayersInArea];

FADE_counterAttack_spawnFootWave = {
    params ["_taskId", "_objectivePos", "_enemyUnits", "_allGroups", "_applyGrp"];
    if ([_taskId] call FADE_counterAttack_missionEnded) exitWith {
        ["footWave aborted missionEnded task=%1", _taskId] call FADE_qrfDbgLog;
    };
    if (count _objectivePos < 2 || { count _enemyUnits == 0 }) exitWith {
        ["footWave aborted badArgs task=%1 objCount=%2 enemyUnits=%3", _taskId, count _objectivePos, count _enemyUnits] call FADE_qrfDbgLog;
    };
    private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _sqMin = (missionNamespace getVariable ["FADE_counterAttackFootSquadsMin", 2]) max 1;
    private _sqMax = (missionNamespace getVariable ["FADE_counterAttackFootSquadsMax", 3]) max _sqMin;
    // Floor keeps standoff even if older ConfigDefaults (80–220) is still published to missionNamespace.
    private _distMin = (missionNamespace getVariable ["FADE_counterAttackFootSpawnDistMin", 280]) max 250;
    private _distMax = (missionNamespace getVariable ["FADE_counterAttackFootSpawnDistMax", 450]) max (_distMin + 80);
    private _sizeMin = (missionNamespace getVariable ["FADE_counterAttackFootSquadSizeMin", 4]) max 2;
    private _sizeMax = (missionNamespace getVariable ["FADE_counterAttackFootSquadSizeMax", 6]) max _sizeMin;
    private _bldChance = (missionNamespace getVariable ["FADE_counterAttackFootBuildingChance", 0.4]) min 0.45;
    private _minFromPlayers = (missionNamespace getVariable ["FADE_counterAttackFootMinDistFromPlayers", 150]) max 80;
    private _numSquads = _sqMin + floor random (1 + _sqMax - _sqMin);
    private _obj3 = if (count _objectivePos >= 3) then { +_objectivePos } else { [(_objectivePos select 0), (_objectivePos select 1), 0] };
    private _fnc_nearPlayers = {
        params ["_pos"];
        private _close = false;
        {
            if (isPlayer _x && { alive _x } && { (_x distance2D _pos) < _minFromPlayers }) exitWith { _close = true };
        } forEach allPlayers;
        _close
    };
    ["footWave start task=%1 squads=%2 obj=%3 dist=%4-%5 minFromPl=%6", _taskId, _numSquads, _obj3, _distMin, _distMax, _minFromPlayers] call FADE_qrfDbgLog;
    private _bearings = [];
    private _squadsSpawned = 0;
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
        private _sz = _sizeMin + floor random (1 + _sizeMax - _sizeMin);
        private _unitPositions = [];
        private _usedBuilding = false;
        if (random 1 < _bldChance) then {
            // Require full distMin from objective (was distMin*0.5 — spawned in buildings next to players).
            private _bldCandidates = (nearestObjects [_obj3, ["House", "Building"], _distMax]) select {
                private _bp = getPosATL _x;
                (_bp distance2D _obj3) >= _distMin &&
                { !([_bp] call _fnc_nearPlayers) } &&
                { count (_x buildingPos -1) >= 1 }
            };
            if (count _bldCandidates > 0) then {
                private _bld = selectRandom _bldCandidates;
                private _bps = (_bld buildingPos -1) call BIS_fnc_arrayShuffle;
                private _want = _sz min count _bps;
                for "_bi" from 0 to (_want - 1) do {
                    private _p = _bps select _bi;
                    if (count _p < 3) then { _p = [(_p select 0), (_p select 1), (_p param [2, 0])] };
                    if !([_p] call _fnc_nearPlayers) then { _unitPositions pushBack _p };
                };
                if (count _unitPositions > 0) then { _usedBuilding = true } else { _unitPositions = [] };
            };
        };
        if (!_usedBuilding) then {
            private _spawnPos = [];
            for "_try" from 0 to 7 do {
                private _tryBearing = if (_try == 0) then { _bearing } else { random 360 };
                private _tryDist = _distMin + random (_distMax - _distMin);
                private _raw = _obj3 getPos [_tryDist, _tryBearing];
                private _cand = [[_raw, 0, 40, 4, 1, 0.4, 0, [], _raw], _raw] call FADE_findSafePosArray;
                if (surfaceIsWater _cand) then { continue };
                if ((_cand distance2D _obj3) < (_distMin * 0.85)) then { continue };
                if ([_cand] call _fnc_nearPlayers) then { continue };
                _spawnPos = _cand;
                _bearing = _tryBearing;
                _dist = _tryDist;
                break;
            };
            if (_spawnPos isEqualTo []) then { continue };
            for "_u" from 1 to _sz do {
                private _off = if (_u == 1) then { [0, 0] } else { [3 + random 6, random 360] };
                private _p = if (_off isEqualTo [0, 0]) then { +_spawnPos } else { _spawnPos getPos [_off select 0, _off select 1] };
                if (count _p < 3) then { _p = [(_p select 0), (_p select 1), 0] };
                _unitPositions pushBack _p;
            };
        };
        if (_unitPositions isEqualTo []) then { continue };
        private _cls = [];
        for "_u" from 1 to (count _unitPositions) do { _cls pushBack (selectRandom _enemyUnits) };
        private _grp = createGroup _sideEnemy;
        {
            private _u = _grp createUnit [_cls select _forEachIndex, _x, [], 0, "NONE"];
            if (!isNull _u) then {
                _u setPosATL _x;
                if (_usedBuilding) then { _u setUnitPos "MIDDLE" };
            };
        } forEach _unitPositions;
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
        _squadsSpawned = _squadsSpawned + 1;
        ["footWave squad task=%1 grp=%2 units=%3 building=%4 bearing=%5 dist=%6", _taskId, _grp, count units _grp, _usedBuilding, _bearing, _dist] call FADE_qrfDbgLog;
    };
    ["footWave done task=%1 spawned=%2/%3", _taskId, _squadsSpawned, _numSquads] call FADE_qrfDbgLog;
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
    if (count _objectivePos < 2 || { count _enemyUnits == 0 }) exitWith {
        ["start aborted badArgs task=%1 obj=%2 units=%3", _taskId, count _objectivePos, count _enemyUnits] call FADE_qrfDbgLog;
    };
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
    if (_applyGrp isEqualTo {}) exitWith {
        ["start aborted no FAC_applyEnemyScenarioToGroup task=%1", _taskId] call FADE_qrfDbgLog;
    };
    ["start task=%1 obj=%2 detectR=%3 skipDetect=%4 footWave=%5 ambient1=%6 firstDelay=%7-%8 trucks=%9",
        _taskId, _objectivePos, _detectionRadius, _skipDetectionWait, _footWave, _ambientSingleWave, _firstMin, _firstMax, _numTrucks
    ] call FADE_qrfDbgLog;

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
        // Primary: AI in AO knowsAbout player (BLUFOR/OPFOR). Fallback: player proximity so QRF cannot stall.
        private _qrfTriggered = {
            if (call _playersInZone) exitWith { true };
            [_objectivePos, _detectionRadius] call FADE_counterAttack_aiDetectsPlayersInArea
        };
        private _detectionLogged = false;
        if (!_skipDetectionWait) then {
            ["waitingDetection task=%1 radius=%2 obj=%3 (aiKnowsAbout|playerProximity)", _taskId, _detectionRadius, _objectivePos] call FADE_qrfDbgLog;
            waitUntil {
                sleep _pollInterval;
                if (call _taskDone) exitWith { true };
                private _trig = call _qrfTriggered;
                if (_trig && { !_detectionLogged }) then {
                    _detectionLogged = true;
                    private _viaProx = call _playersInZone;
                    ["playerDetected task=%1 obj=%2 radius=%3 via=%4", _taskId, _objectivePos, _detectionRadius, if (_viaProx) then { "proximity" } else { "aiKnowsAbout" }] call FADE_qrfDbgLog;
                };
                _trig
            };
            if (call _taskDone) exitWith {
                ["endedBeforeQrf task=%1 (during detection wait)", _taskId] call FADE_qrfDbgLog;
            };
        } else {
            ["skipDetectionWait task=%1 — first delay starts now", _taskId] call FADE_qrfDbgLog;
            if (call _taskDone) exitWith {
                ["endedBeforeQrf task=%1 (skipDetection)", _taskId] call FADE_qrfDbgLog;
            };
        };
        private _maxWaves = if (_ambientSingleWave) then { 1 } else { 1 + floor random 3 };
        ["plan task=%1 maxWaves=%2 footWave=%3", _taskId, _maxWaves, _footWave] call FADE_qrfDbgLog;
        if (_footWave) then {
            [_taskId, _objectivePos, _enemyUnits, _allGroups, _applyGrp] call FADE_counterAttack_spawnFootWave;
        } else {
            ["footWave skipped task=%1 (footWave=false — only Raid passes true by default)", _taskId] call FADE_qrfDbgLog;
        };
        private _firstDelaySec = _firstMin + random (_firstMax - _firstMin);
        ["firstDelay task=%1 sleeping %2s before vehicle wave(s)", _taskId, round _firstDelaySec] call FADE_qrfDbgLog;
        sleep _firstDelaySec;

        private _waveFn = {
            params ["_taskId", "_objectivePos", "_enemyUnits", "_allGroups", "_numTrucks", "_applyGrp", "_pollInterval", "_detectionRadius"];
            if ([_taskId] call FADE_counterAttack_missionEnded) exitWith {
                ["vehicleWave aborted missionEnded task=%1", _taskId] call FADE_qrfDbgLog;
            };
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
            if (count _pairs == 0) exitWith {
                ["vehicleWave aborted noCivZones task=%1", _taskId] call FADE_qrfDbgLog;
            };
            _pairs = [_pairs, [], { _x select 0 }, "ASCEND"] call BIS_fnc_sortBy;
            private _minBase = missionNamespace getVariable ["FADE_counterAttackMinDistFromBase", 1000];
            private _baseQ = FADE_basePos;
            // Assign with select (not params) — params inside if/while shadows outer _roadPos (SQF scope).
            private _roadPos = [];
            private _roadDir = 0;
            private _staging = [];
            private _stagingResolved = false;
            private _nearOnly = (_pairs select 0) select 1;
            // Town-centre anchors fail FADE_findOpforGroundVehicleRoadSpawn (10 m TREE/HOUSE clear).
            // Prefer offsets from secondary civ zones (same idea as EscapeEvasion staging away from cores).
            private _stCandidates = [];
            private _zoneIdxList = [];
            if (count _pairs >= 2) then { _zoneIdxList pushBack 1 };
            if (count _pairs >= 3) then { _zoneIdxList pushBack 2 };
            _zoneIdxList pushBack 0;
            if (count _pairs >= 4) then { _zoneIdxList pushBack 3 };
            {
                private _zc = (_pairs select _x) select 1;
                private _away = _objectivePos getDir _zc;
                if (_zc distance2D _objectivePos < 50) then { _away = _baseQ getDir _objectivePos };
                _stCandidates pushBack (_zc getPos [700 + random 500, _away]);
                _stCandidates pushBack (_zc getPos [1100 + random 700, _away + 40 + random 80]);
                _stCandidates pushBack (_zc getPos [900 + random 600, _away + 180]);
                _stCandidates pushBack _zc;
            } forEach _zoneIdxList;
            _stCandidates pushBack (_nearOnly getPos [600 min ((_nearOnly distance2D _objectivePos) + 400), (_nearOnly getDir _objectivePos) + 180]);
            _stCandidates pushBack (_objectivePos getPos [1200 + random 800, random 360]);
            private _dirFromBase = _baseQ getDir _objectivePos;
            _stCandidates pushBack (_baseQ getPos [(_minBase + 80 + random 200), _dirFromBase]);

            private _tryRoad = {
                params ["_anchor", "_searchM", "_terrClear"];
                if (count _anchor < 2) exitWith { [] };
                private _a = if (count _anchor < 3) then { [(_anchor select 0), (_anchor select 1), 0] } else { +_anchor };
                [_a, _searchM, [], _minBase, _baseQ, _objectivePos, 12, 8, _terrClear] call FADE_findOpforGroundVehicleRoadSpawn
            };

            private _si = 0;
            private _hit = [];
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
            // Soft fallback: nearRoads + findSafePos (skip TREE/HOUSE filter that rejects urban/scrub roads).
            if (!_stagingResolved) then {
                private _fbAnchors = [
                    _objectivePos getPos [1400 + random 600, random 360],
                    _nearOnly getPos [1000 + random 500, random 360],
                    _baseQ getPos [(_minBase + 100), _dirFromBase]
                ];
                {
                    private _anc = _x;
                    if (count _anc < 3) then { _anc = [(_anc select 0), (_anc select 1), 0] };
                    private _roads = _anc nearRoads 1500;
                    if (count _roads > 24) then {
                        _roads = _roads call BIS_fnc_arrayShuffle;
                        _roads = _roads select [0, 24];
                    };
                    {
                        private _rp = getPosATL _x;
                        if (count _rp < 3) then { _rp = [(_rp select 0), (_rp select 1), 0] };
                        if (surfaceIsWater _rp) then { continue };
                        if (_rp distance2D _baseQ <= _minBase) then { continue };
                        private _probe = [[_rp, 0, 12, 6, 0, 0.4, 0, [], _rp], _rp] call FADE_findSafePosArray;
                        if (!(_probe isEqualType []) || { count _probe < 2 } || { surfaceIsWater _probe }) then { continue };
                        if (count _probe < 3) then { _probe = [(_probe select 0), (_probe select 1), 0] };
                        if (_probe distance2D _baseQ <= _minBase) then { continue };
                        _roadPos = _probe;
                        _roadDir = [_probe, _objectivePos] call BIS_fnc_dirTo;
                        _staging = _anc;
                        _stagingResolved = true;
                        break;
                    } forEach _roads;
                    if (_stagingResolved) then { break };
                } forEach _fbAnchors;
            };
            if (!_stagingResolved) exitWith {
                ["vehicleWave aborted noRoadSpawn task=%1 obj=%2 nearestZone=%3 candidates=%4", _taskId, _objectivePos, _nearOnly, count _stCandidates] call FADE_qrfDbgLog;
            };
            ["vehicleWave staging task=%1 road=%2 zoneCandidates=%3", _taskId, _roadPos, count _pairs] call FADE_qrfDbgLog;
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
            ["vehicleWave huntMode=%1 task=%2 tgt=%3", _huntQrf, _taskId, _tgtMove] call FADE_qrfDbgLog;
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
                ["vehicleWave infantryFallback task=%1 (no cargo trucks) road=%2", _taskId, _roadPos] call FADE_qrfDbgLog;
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

            ["vehicleWave trucks task=%1 count=%2 classes=%3 road=%4", _taskId, _numTrucks, count _vehPick, _roadPos] call FADE_qrfDbgLog;
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
            // Do not declare private inside for+continue (SQF re-entry bug).
            private _fbRoads = [];
            private _fbHit = [];
            private _rp = [0, 0, 0];
            private _gapOk = true;
            // Staging already resolved a clear road with relaxed terrainClear; reuse it for truck 0.
            // Re-running FADE_findOpforGroundVehicleRoadSpawn with default terrClear=10 often returns []
            // on the same scrub/town roads that staging accepted (RPT: skipTruck noRoadNear).
            for "_vi" from 0 to (_numTrucks - 1) do {
                if (_vi > 0) then { sleep 8 };
                _vClass = selectRandom _vehPick;
                if (_vi == 0) then {
                    _spawnPos = +_roadPos;
                    _spawnDir = _roadDir;
                    _anchor = _spawnPos;
                } else {
                    if (count _spawnedVehs > 0) then {
                        _prev = _spawnedVehs select ((count _spawnedVehs) - 1);
                        _anchor = if (isNull _prev) then { +_roadPos } else { (getPosATL _prev) getPos [14, _dir + 180] };
                    } else {
                        _anchor = _roadPos getPos [14 * _vi, _dir + 180];
                    };
                    if (count _anchor < 3) then { _anchor = [(_anchor select 0), (_anchor select 1), 0] };
                    // Match staging: relaxed clear + wider search, then soft nearRoads fallback.
                    _roadHit = [_anchor, 700, _spawnedVehs, _minBase, _baseQ, _tgtMove, 12, 8, 4] call FADE_findOpforGroundVehicleRoadSpawn;
                    if (_roadHit isEqualTo []) then {
                        _roadHit = [_anchor, 900, _spawnedVehs, _minBase, _baseQ, _tgtMove, 12, 8, 2] call FADE_findOpforGroundVehicleRoadSpawn;
                    };
                    if (_roadHit isEqualTo []) then {
                        _fbRoads = _anchor nearRoads 600;
                        if (count _fbRoads > 16) then {
                            _fbRoads = _fbRoads call BIS_fnc_arrayShuffle;
                            _fbRoads = _fbRoads select [0, 16];
                        };
                        _fbHit = [];
                        {
                            _rp = getPosATL _x;
                            if (count _rp < 3) then { _rp = [(_rp select 0), (_rp select 1), 0] };
                            if (surfaceIsWater _rp) then { continue };
                            if (_rp distance2D _baseQ <= _minBase) then { continue };
                            _gapOk = true;
                            {
                                if (!isNull _x && { alive _x } && { (_x distance2D _rp) < 12 }) then { _gapOk = false };
                            } forEach _spawnedVehs;
                            if (!_gapOk) then { continue };
                            _fbHit = [_rp, [_rp, _tgtMove] call BIS_fnc_dirTo];
                            break;
                        } forEach _fbRoads;
                        _roadHit = _fbHit;
                    };
                    if (_roadHit isEqualTo []) then {
                        ["vehicleWave skipTruck task=%1 idx=%2 noRoadNear anchor=%3", _taskId, _vi, _anchor] call FADE_qrfDbgLog;
                        continue
                    };
                    _spawnPos = +(_roadHit select 0);
                    _spawnDir = _roadHit select 1;
                    if (count _spawnPos < 3) then { _spawnPos = [(_spawnPos select 0), (_spawnPos select 1), 0] };
                };
                if (_spawnPos distance2D _baseQ <= _minBase) then {
                    ["vehicleWave skipTruck task=%1 idx=%2 tooNearBase dist=%3 min=%4", _taskId, _vi, _spawnPos distance2D _baseQ, _minBase] call FADE_qrfDbgLog;
                    continue
                };
                _vehGrp = createGroup _sideEnemy;
                _veh = createVehicle [_vClass, _spawnPos, [], 0, "NONE"];
                if (isNull _veh) then {
                    ["vehicleWave skipTruck task=%1 idx=%2 createFailed class=%3", _taskId, _vi, _vClass] call FADE_qrfDbgLog;
                    deleteGroup _vehGrp;
                    continue
                };
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
                ["vehicleWave spawned task=%1 idx=%2 class=%3 pos=%4 cargoSeats=%5 hunt=%6", _taskId, _vi, _vClass, _spawnPos, _veh emptyPositions "cargo", _huntQrf] call FADE_qrfDbgLog;
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
                        ["cargoUnload task=%1 veh=%2 units=%3 hunt=%4 drop=%5", _taskId, _veh, count units _cargoGrp, _huntQrf, _drop] call FADE_qrfDbgLog;
                        private _wp = _cargoGrp addWaypoint [_drop, 0];
                        _wp setWaypointType "SAD";
                    };
                };
            };
            ["vehicleWave done task=%1 trucksSpawned=%2/%3", _taskId, count _spawnedVehs, _numTrucks] call FADE_qrfDbgLog;
        };

        private _waveNum = 0;
        while { _waveNum < _maxWaves && { !(call _taskDone) } } do {
            _waveNum = _waveNum + 1;
            ["vehicleWave begin task=%1 wave=%2/%3", _taskId, _waveNum, _maxWaves] call FADE_qrfDbgLog;
            [_taskId, _objectivePos, _enemyUnits, _allGroups, _numTrucks, _applyGrp, _pollInterval, _detectionRadius] call _waveFn;
            if (call _taskDone) exitWith {
                ["endedAfterWave task=%1 wave=%2", _taskId, _waveNum] call FADE_qrfDbgLog;
            };
            if (_waveNum >= _maxWaves) exitWith {
                ["allWavesDone task=%1 waves=%2", _taskId, _waveNum] call FADE_qrfDbgLog;
            };
            private _bw = _betMin + random (_betMax - _betMin);
            ["betweenWaves task=%1 sleeping %2s waitingForQrfTrigger", _taskId, round _bw] call FADE_qrfDbgLog;
            sleep _bw;
            if (call _taskDone) exitWith {};
            waitUntil {
                sleep _pollInterval;
                call _taskDone || { call _qrfTriggered }
            };
            if (call _taskDone) exitWith {};
            ["betweenWaves ready task=%1 wave=%2 qrfTriggered=true", _taskId, _waveNum + 1] call FADE_qrfDbgLog;
        };
    };
};
missionNamespace setVariable ["FADE_counterAttack_missionEnded", FADE_counterAttack_missionEnded];
missionNamespace setVariable ["FADE_counterAttackStart", FADE_counterAttackStart];
