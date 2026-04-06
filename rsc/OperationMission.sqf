// =============================================================================
// OperationMission.sqf - Multi-zone capture (global). Random civ zones; players
// only (BLUFOR). Main loop polls every 5s (abort/task); zone evaluation every 60s
// using distance2D vs ellipse radius — captured if 0 OPFOR and ≥1 BLUFOR player;
// recaptured if OPFOR count > BLUFOR player count.
// Infantry: patrols + building garrison (optional smoking barrel). Vehicles with
// cargo run between enemy-held zones; periodic resupply vehicles per zone; QRF
// from nearest enemy-held zone when zone is contested (BLUFOR + OPFOR present).
// Params: FADE_operationParams = [_player, _taskId, _basePos, _enemyUnits]
// =============================================================================
if (!isServer) exitWith {};
if (isNil "FADE_operationParams" || { count FADE_operationParams < 4 }) exitWith {};

FADE_operationParams params ["_player", "_taskId", "_basePos", "_enemyUnits"];

_enemyUnits = [_enemyUnits] call FADE_resolveScenarioEnemyUnits;

private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
private _sideFriendly = missionNamespace getVariable ["FADE_sideFriendly", west];
private _markerFriendlyOp = missionNamespace getVariable ["FADE_markerColorFriendly", "ColorWEST"];
private _markerEnemyOp = missionNamespace getVariable ["FADE_markerColorEnemy", "ColorEAST"];

// bis_fnc_tasksetparent: ensured once in initServer (FADE_ensureBisTaskSetParent); safe to call again if needed
[] call FADE_ensureBisTaskSetParent;

if (count _enemyUnits == 0) exitWith {
    if (!isNull _player) then { [_player] call FADE_clearActiveMission };
    ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No enemy units configured.</t>"] remoteExec ["FADE_showMissionHint", _player];
};

private _scaleOpforCount = missionNamespace getVariable ["FADE_scaleOpforCount", {
    params ["_baseCount", ["_minCount", 1], ["_maxCount", -1]];
    private _base = floor (_baseCount max 0);
    if (_base <= 0) exitWith { 0 };
    private _scaled = _base max _minCount;
    if (_maxCount >= 0 && { _scaled > _maxCount }) then { _scaled = _maxCount };
    _scaled
}];

private _civNames = missionNamespace getVariable ["FADE_civTriggerNames", []];
if (count _civNames == 0) exitWith {
    if (!isNull _player) then { [_player] call FADE_clearActiveMission };
    ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No CIV_T_* zones. Place civ triggers in Eden.</t>"] remoteExec ["FADE_showMissionHint", _player];
};

private _minDistFromBase = 1000;
private _zoneCandidates = [];
{
    private _trig = missionNamespace getVariable [_x, objNull];
    if (!isNull _trig) then {
        private _p = getPosATL _trig;
        if (count _p >= 2 && { (_p distance _basePos) >= _minDistFromBase }) then {
            _zoneCandidates pushBack [(_p select 0), (_p select 1), (_p param [2, 0])];
        };
    };
} forEach _civNames;

if (count _zoneCandidates == 0) exitWith {
    if (!isNull _player) then { [_player] call FADE_clearActiveMission };
    ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No civ zones far enough from base.</t>"] remoteExec ["FADE_showMissionHint", _player];
};

private _wantN = missionNamespace getVariable ["FADE_operationZoneCount", 6];
_wantN = (round _wantN) max 2 min 10;
_wantN = _wantN min count _zoneCandidates;
_zoneCandidates = _zoneCandidates call BIS_fnc_arrayShuffle;
private _zones = _zoneCandidates select [0, _wantN];
private _maxFleet = missionNamespace getVariable ["FADE_operationMaxFleetVehicles", 10];
private _spawnMinDistPl = missionNamespace getVariable ["FADE_operationSpawnMinDistPlayers", 1000];
private _cleanupInterval = missionNamespace getVariable ["FADE_operationCleanupInterval", 600];
private _cleanupDist = missionNamespace getVariable ["FADE_operationCleanupDistPlayers", 2000];
private _playersOpSort = [];
{ if (alive _x && { isPlayer _x }) then { _playersOpSort pushBack _x } } forEach allPlayers;
if (count _playersOpSort == 0) then { _playersOpSort = [_player] };
_zones = [_zones, [], {
    private _c = [_x] call FADE_normPos3;
    private _m = 1e15;
    { _m = _m min (_c distance2D _x) } forEach _playersOpSort;
    _m
}, "ASCEND"] call BIS_fnc_sortBy;

private _zoneRadius = 250;
private _opAllGroups = [];
private _allVehs = [];
private _barrels = [];
private _markerNames = [];

private _facApply = missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}];

private _fnc_opPlayers = {
    private _pl = [];
    { if (alive _x && { isPlayer _x }) then { _pl pushBack _x } } forEach allPlayers;
    _pl
};
private _fnc_opCountFleet = {
    params ["_taskId"];
    private _ent = missionNamespace getVariable ["FADE_operationEntities_" + _taskId, []];
    if (count _ent < 5) exitWith { 0 };
    private _n = 0;
    {
        private _v = _x;
        if (!isNull _v && { alive _v } && { canMove _v } && { !(_v getVariable ["FADE_opVehQrf", false]) } && { !(_v isKindOf "Air") }) then {
            _n = _n + 1;
        };
    } forEach (_ent select 4);
    _n
};
private _fnc_opFindSpawnPos = {
    params ["_zoneCenter", "_zoneRadius", "_minDist"];
    private _players = [] call _fnc_opPlayers;
    if (count _players == 0) exitWith {
        [[_zoneCenter, 0, _zoneRadius * 0.85, 10, 0, 0.4, 0, [], _zoneCenter], _zoneCenter] call FADE_findSafePosArray
    };
    private _zc = [_zoneCenter] call FADE_normPos3;
    private _try = 0;
    private _r = [];
    while { _try < 45 && count _r < 2 } do {
        _try = _try + 1;
        private _angle = random 360;
        private _dist = random (_zoneRadius * 0.95);
        private _sp = [(_zc select 0) + _dist * cos _angle, (_zc select 1) + _dist * sin _angle, 0];
        _sp = [[_sp, 0, 25, 3, 0, 0.4, 0, [], _sp], _zc] call FADE_findSafePosArray;
        if (count _sp < 2) then { _sp = _zc };
        if (count _sp < 3) then { _sp = [(_sp select 0), (_sp select 1), 0] };
        private _ok = true;
        { if (_sp distance2D _x < _minDist) then { _ok = false } } forEach _players;
        if (_ok) then { _r = _sp };
    };
    if (count _r >= 2) exitWith { _r };
    private _nearestP = _players select 0;
    private _minPd = 1e15;
    { if (_zc distance2D _x < _minPd) then { _minPd = _zc distance2D _x; _nearestP = _x } } forEach _players;
    private _dirAway = _nearestP getDir _zc;
    private _sp = _nearestP getPos [_minDist + _zoneRadius + 50, _dirAway];
    _sp = [[_sp, 0, 50, 5, 0, 0.4, 0, [], _sp], _zc] call FADE_findSafePosArray;
    if (count _sp < 2) then { _sp = _zc };
    _sp
};
private _fnc_opDeleteVehWithCrews = {
    params ["_veh"];
    if (isNull _veh) exitWith {};
    private _cg = _veh getVariable ["FADE_opCargoGrp", grpNull];
    if (!isNull _cg) then {
        { if (!isNull _x) then { deleteVehicle _x } } forEach units _cg;
        deleteGroup _cg;
    };
    { if (!isNull _x) then { deleteVehicle _x } } forEach crew _veh;
    private _g = group driver _veh;
    if (!isNull _g) then {
        { if (!isNull _x) then { deleteVehicle _x } } forEach units _g;
        deleteGroup _g;
    };
    if (!isNull _veh) then { deleteVehicle _veh };
};

// Returns [vehicle, driverGroup, cargoGroup] — cargoGroup may be grpNull
// Must not close over other private locals: stored in missionNamespace and called from resupply/QRF after this script ends.
private _fnc_opMakeVeh = {
    params ["_spawnPos", "_enemyUnits", "_facApply"];
    private _sp = _spawnPos;
    if (count _sp < 2) then { _sp = [0, 0, 0] };
    if (count _sp < 3) then { _sp = [(_sp select 0), (_sp select 1), 0] };
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
    private _minC = 2;
    private _pick = if ((typeName _filter == "CODE") && { count _land > 0 }) then { [_land, _minC] call _filter } else { _land };
    if (count _pick == 0) then { _pick = _land };
    if (count _pick == 0) then {
        private _sn = missionNamespace getVariable ["FADE_scenarioEnemySideNum", 0];
        private _fb = switch (_sn) do {
            case 1: { ["B_Truck_01_transport_F", "B_T_Truck_01_transport_F", "B_LSV_01_unarmed_F"] };
            case 2: { ["I_Truck_02_transport_F", "I_G_Offroad_01_transport_F", "I_C_Offroad_02_unarmed_F"] };
            default { ["O_Truck_02_transport_F", "O_Truck_03_transport_F", "O_LSV_02_unarmed_F"] };
        };
        _pick = _fb select { isClass (configFile >> "CfgVehicles" >> _x) };
    };
    if (count _pick == 0) exitWith { [objNull, grpNull, grpNull] };
    private _vClass = selectRandom _pick;
    private _veh = createVehicle [_vClass, _sp, [], 0, "NONE"];
    if (isNull _veh) exitWith { [objNull, grpNull, grpNull] };
    _veh setPosATL _sp;
    private _vehGrp = createGroup _sideE;
    private _driver = _vehGrp createUnit [selectRandom _enemyUnits, _sp, [], 0, "NONE"];
    if (!isNull _driver) then {
        _driver moveInDriver _veh;
        _vehGrp selectLeader _driver;
    };
    if (_veh emptyPositions "gunner" > 0) then {
        private _g = _vehGrp createUnit [selectRandom _enemyUnits, _sp, [], 0, "NONE"];
        if (!isNull _g) then { _g moveInGunner _veh };
    };
    if (!(_facApply isEqualTo {})) then { [_vehGrp] call _facApply };
    _vehGrp setBehaviour "AWARE";
    _vehGrp setCombatMode "RED";
    private _cargoGrp = grpNull;
    private _seats = (_veh emptyPositions "cargo") max 0;
    if (_seats > 0) then {
        _cargoGrp = createGroup _sideE;
        // No sleep here: _fnc_opMakeVeh runs via call from unscheduled Missions.sqf (sleep would error / abort).
        for "_c" from 0 to (_seats - 1) do {
            private _u = _cargoGrp createUnit [selectRandom _enemyUnits, _sp, [], 0, "NONE"];
            if (!isNull _u) then { _u moveInCargo _veh };
        };
        if (!(_facApply isEqualTo {})) then { [_cargoGrp] call _facApply };
    };
    _veh setVariable ["FADE_opCargoGrp", _cargoGrp, false];
    [_veh, _vehGrp, _cargoGrp]
};

{
    private _idx = _forEachIndex;
    private _center = [_x] call FADE_normPos3;
    private _mName = format ["FADE_op_%1_%2", _taskId, _idx];
    _markerNames pushBack _mName;
    private _m = createMarker [_mName, _center];
    _m setMarkerShape "ELLIPSE";
    _m setMarkerSize [_zoneRadius, _zoneRadius];
    _m setMarkerBrush "Border";
    _m setMarkerColor _markerEnemyOp;
    _m setMarkerAlpha 0.5;

    private _iconName = _mName + "_icon";
    private _mi = createMarker [_iconName, _center];
    _mi setMarkerType "hd_flag";
    _mi setMarkerColor _markerEnemyOp;
    _mi setMarkerText format ["Zone %1", _idx + 1];
    _markerNames pushBack _iconName;

    // --- Patrols (2 groups, loop around the ellipse) ---
    private _numPatrol = [2, 1] call _scaleOpforCount;
    for "_pg" from 0 to (_numPatrol - 1) do {
        private _angle0 = (_pg / (_numPatrol max 1)) * 360 + random 45;
        private _dist0 = 50 + random ((_zoneRadius - 50) max 0);
        private _sp = [(_center select 0) + _dist0 * (cos _angle0), (_center select 1) + _dist0 * (sin _angle0), 0];
        _sp = [[_sp, 0, 25, 3, 0, 0.4, 0, [], _sp], _center] call FADE_findSafePosArray;
        private _ps = [3 + floor random 3, 2] call _scaleOpforCount;
        private _shuf = _enemyUnits call BIS_fnc_arrayShuffle;
        private _classes = _shuf select [0, _ps min count _shuf];
        if (count _classes == 0) then { _classes = [_enemyUnits select 0] };
        private _grp = [_sp, _sideEnemy, _classes] call BIS_fnc_spawnGroup;
        if (!(_facApply isEqualTo {})) then { [_grp] call _facApply };
        _grp setBehaviour "AWARE";
        _grp setCombatMode "RED";
        for "_w" from 0 to 3 do {
            private _a = _angle0 + _w * 90 + random 25;
            private _d = 60 + random ((_zoneRadius - 70) max 0);
            private _wp = [(_center select 0) + _d * (cos _a), (_center select 1) + _d * (sin _a), 0];
            _wp = [[_wp, 0, 20, 3, 0, 0.4, 0, [], _wp], _center] call FADE_findSafePosArray;
            private _way = _grp addWaypoint [_wp, _w];
            _way setWaypointType "MOVE";
            _way setWaypointSpeed "LIMITED";
        };
        private _cyc = _grp addWaypoint [_sp, 4];
        _cyc setWaypointType "CYCLE";
        _opAllGroups pushBack _grp;
    };

    // --- Garrison in buildings + optional smoking barrel (50% per building) ---
    private _blds = nearestObjects [_center, ["House", "Building"], _zoneRadius * 0.95];
    _blds = (_blds select { count (_x buildingPos -1) >= 2 }) call BIS_fnc_arrayShuffle;
    private _maxB = (2 min count _blds);
    for "_b" from 0 to (_maxB - 1) do {
        private _building = _blds select _b;
        private _bps = _building buildingPos -1;
        private _added = 0;
        for "_i" from 0 to (count _bps - 1) do {
            if (_added >= 3) exitWith {};
            private _pos = _bps select _i;
            if (count _pos >= 2) then {
                if (count _pos < 3) then { _pos = [(_pos select 0), (_pos select 1), 0] };
                private _cls = selectRandom _enemyUnits;
                private _grpG = createGroup _sideEnemy;
                private _u = _grpG createUnit [_cls, _pos, [], 0, "NONE"];
                if (!isNull _u) then {
                    if (!(_facApply isEqualTo {})) then { [_grpG] call _facApply };
                    _u setPos _pos;
                    _u setUnitPos "MIDDLE";
                    [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                    _grpG setBehaviour "AWARE";
                    _grpG setCombatMode "RED";
                    _opAllGroups pushBack _grpG;
                    _added = _added + 1;
                    if (_added == 1 && { random 1 < 0.5 }) then {
                        private _bc = getPosATL _building;
                        _bc = [_bc] call FADE_normPos3;
                        private _barrelPos = [[_bc, 0, 18, 2, 0, 0.3, 0, [], _bc], _bc] call FADE_findSafePosArray;
                        if (count _barrelPos >= 2) then {
                            private _bar = createVehicle ["MetalBarrel_burning_F", _barrelPos, [], 0, "NONE"];
                            if (!isNull _bar) then {
                                _bar setPosATL _barrelPos;
                                _barrels pushBack _bar;
                            };
                        };
                    };
                };
            };
        };
    };

    // --- One vehicle per zone at start (up to _maxFleet) + traffic loop (spawn ≥ _spawnMinDistPl from all players)
    if (count _allVehs < _maxFleet) then {
        private _vsp = [_center, _zoneRadius, _spawnMinDistPl] call _fnc_opFindSpawnPos;
        private _vehPack = [_vsp, _enemyUnits, _facApply] call _fnc_opMakeVeh;
        _vehPack params ["_veh", "_vGrp", "_cGrp"];
        if (!isNull _veh) then {
            _veh setVariable ["FADE_opHomeIdx", _idx, false];
            _allVehs pushBack _veh;
            _opAllGroups pushBack _vGrp;
            if (!isNull _cGrp) then { _opAllGroups pushBack _cGrp };
            _veh engineOn true;
            // Traffic spawn runs after missionNamespace (zone centers / cap) is set — see below.
        };
    };
} forEach _zones;

// Retreat: exclude driver/cargo groups of Operation vehicles so waypoints are not cleared by FADE_doEnemyRetreat.
private _groupsForRetreat = _opAllGroups select {
    private _grp = _x;
    if (isNull _grp) exitWith { false };
    private _ldr = leader _grp;
    if (isNull _ldr) exitWith { true };
    private _v = vehicle _ldr;
    if (_v == _ldr) exitWith { true };
    (_allVehs find _v) < 0
};
[_groupsForRetreat, _basePos] call FADE_registerEnemyRetreat;

missionNamespace setVariable ["FADE_operationMakeVehFn_" + _taskId, _fnc_opMakeVeh];

missionNamespace setVariable ["FADE_operationZoneCenters_" + _taskId, _zones]; // copy for spawned scripts

private _captured = [];
{ _captured pushBack false } forEach _zones;
missionNamespace setVariable ["FADE_operationCapState_" + _taskId, +_captured];

missionNamespace setVariable ["FADE_operationEntities_" + _taskId, [_opAllGroups, _markerNames, _zones, _zoneRadius, _allVehs, _barrels]];

if (!isNull _player) then {
    [_player, _taskId, [
        format [
            "Capture all %1 marked zones. OPFOR must be cleared while BLUFOR players hold each ellipse. Zones can be recaptured if OPFOR outnumber friendly players inside the zone. Evaluation every 60 seconds.",
            count _zones
        ],
        "Operation",
        ""
    ], _basePos, "ASSIGNED", 1, true, "attack", true] call BIS_fnc_taskCreate;
};

missionNamespace setVariable ["FADE_operationAborted_" + _taskId, false];

// Inter-zone traffic (deferred until zone centers + cap state exist; resolve driver group each tick).
{
    private _veh = _x;
    private _homeIdx = _veh getVariable ["FADE_opHomeIdx", -1];
    if (_homeIdx >= 0) then {
        [_veh, _taskId, _homeIdx, _zoneRadius] spawn {
        params ["_veh", "_taskId", "_homeIdx", "_zoneRadius"];
        scriptName "FADE_op_traffic";
        sleep (random 1);
        while { alive _veh } do {
            private _vehGrp = group driver _veh;
            if (isNull _vehGrp || { isNull driver _veh }) exitWith {};
            if (missionNamespace getVariable ["FADE_operationAborted_" + _taskId, false]) exitWith {};
            if (((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"])) exitWith {};
            private _cap = missionNamespace getVariable ["FADE_operationCapState_" + _taskId, []];
            private _zc = missionNamespace getVariable ["FADE_operationZoneCenters_" + _taskId, []];
            if (count _cap == 0 || { count _zc == 0 }) exitWith {};
            private _opts = [];
            { if (!(_cap select _forEachIndex)) then { _opts pushBack _forEachIndex } } forEach _cap;
            _opts = _opts - [_homeIdx];
            if (count _opts == 0) exitWith {};
            private _destIdx = selectRandom _opts;
            private _dest = (missionNamespace getVariable ["FADE_operationZoneCenters_" + _taskId, []]) select _destIdx;
            _dest = [_dest] call {
                params ["_p"];
                if (count _p < 2) exitWith { [0, 0, 0] };
                if (count _p < 3) then { [(_p select 0), (_p select 1), 0] } else { _p }
            };
            _vehGrp = group driver _veh;
            if (isNull _vehGrp) exitWith {};
            while { count waypoints _vehGrp > 0 } do { deleteWaypoint [_vehGrp, 0] };
            private _wp = _vehGrp addWaypoint [_dest, 0];
            _wp setWaypointType "MOVE";
            _wp setWaypointCompletionRadius (15 + _zoneRadius * 0.12);
            _vehGrp setCurrentWaypoint _wp;
            private _drv = driver _veh;
            if (!isNull _drv) then { _drv doMove _dest };
            waitUntil {
                sleep 4;
                (
                    missionNamespace getVariable ["FADE_operationAborted_" + _taskId, false]
                    || ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"])
                    || (!alive _veh)
                    || ((driver _veh) isEqualTo objNull)
                    || ((_veh distance2D _dest) < (25 + _zoneRadius * 0.12))
                )
            };
            if (!alive _veh) exitWith {};
            sleep 2 + random 4;
        };
        };
    };
} forEach _allVehs;

private _brief = format [
    "OPERATION%1%1Capture %2 zones across the AO. Clear all OPFOR in each ellipse and keep BLUFOR players inside while holding — OPFOR can retake a zone if they outnumber you.%1%1Enemy patrols, garrisoned buildings, and vehicles move between zones; QRF may respond when you are engaged in a zone.%1%1Evaluation runs every 60 seconds.",
    toString [10],
    count _zones
];
if (!isNull _player) then {
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#B0B0B0'>Zones: %1</t><br/><br/><t color='#C0C0C0'>Clear and hold all zones concurrently.</t>", count _zones]] remoteExec ["FADE_showMissionHint", _player];
    [_player, "Operation"] call FADE_notifyOthersMissionStarted;
};

// Fleet resupply (enemy-held zones only): one global timer; spawn at zone flag nearest players, ≥1000m from players, cap _maxFleet (QRF/air excluded from count)
private _resMin = missionNamespace getVariable ["FADE_operationVehicleResupplyMin", 240];
private _resMax = missionNamespace getVariable ["FADE_operationVehicleResupplyMax", 360];
private _resSpan = (_resMax - _resMin) max 0;
[_taskId, _zones, _zoneRadius, _enemyUnits, _facApply, _resMin, _resMax, _resSpan, _maxFleet, _spawnMinDistPl] spawn {
    params ["_taskId", "_zones", "_zoneRadius", "_enemyUnits", "_facApply", "_resMin", "_resMax", "_resSpan", "_maxFleet", "_spawnMinDistPl"];
    scriptName "FADE_op_resupply";
    private _fncPlayers = { private _pl = []; { if (alive _x && { isPlayer _x }) then { _pl pushBack _x } } forEach allPlayers; _pl };
    private _fncCountFleet = {
        params ["_tid"];
        private _ent = missionNamespace getVariable ["FADE_operationEntities_" + _tid, []];
        if (count _ent < 5) exitWith { 0 };
        private _n = 0;
        {
            private _v = _x;
            if (!isNull _v && { alive _v } && { canMove _v } && { !(_v getVariable ["FADE_opVehQrf", false]) } && { !(_v isKindOf "Air") }) then { _n = _n + 1 };
        } forEach (_ent select 4);
        _n
    };
    private _fncFindSpawn = {
        params ["_zoneCenter", "_zr", "_minD"];
        private _players = [] call _fncPlayers;
        if (count _players == 0) exitWith {
            [[_zoneCenter, 0, _zr * 0.85, 10, 0, 0.4, 0, [], _zoneCenter], _zoneCenter] call FADE_findSafePosArray
        };
        private _zc = [_zoneCenter] call FADE_normPos3;
        private _try = 0;
        private _r = [];
        while { _try < 45 && count _r < 2 } do {
            _try = _try + 1;
            private _angle = random 360;
            private _dist = random (_zr * 0.95);
            private _sp = [(_zc select 0) + _dist * cos _angle, (_zc select 1) + _dist * sin _angle, 0];
            _sp = [[_sp, 0, 25, 3, 0, 0.4, 0, [], _sp], _zc] call FADE_findSafePosArray;
            if (count _sp < 2) then { _sp = _zc };
            if (count _sp < 3) then { _sp = [(_sp select 0), (_sp select 1), 0] };
            private _ok = true;
            { if (_sp distance2D _x < _minD) then { _ok = false } } forEach _players;
            if (_ok) then { _r = _sp };
        };
        if (count _r >= 2) exitWith { _r };
        private _nearestP = _players select 0;
        private _minPd = 1e15;
        { if (_zc distance2D _x < _minPd) then { _minPd = _zc distance2D _x; _nearestP = _x } } forEach _players;
        private _dirAway = _nearestP getDir _zc;
        private _sp = _nearestP getPos [_minD + _zr + 50, _dirAway];
        _sp = [[_sp, 0, 50, 5, 0, 0.4, 0, [], _sp], _zc] call FADE_findSafePosArray;
        if (count _sp < 2) then { _sp = _zc };
        _sp
    };
    while { !(missionNamespace getVariable ["FADE_operationAborted_" + _taskId, false]) } do {
        sleep ((_resMin min _resMax) + random _resSpan);
        if (missionNamespace getVariable ["FADE_operationAborted_" + _taskId, false]) exitWith {};
        if ([_taskId] call _fncCountFleet < _maxFleet) then {
            private _cap = missionNamespace getVariable ["FADE_operationCapState_" + _taskId, []];
            if (count _cap == count _zones) then {
                private _cand = [];
                {
                    private _i = _forEachIndex;
                    if (!(_cap select _i)) then {
                        private _cen = [_x] call FADE_normPos3;
                        private _near = 1e15;
                        { _near = _near min (_cen distance2D _x) } forEach ([] call _fncPlayers);
                        _cand pushBack [_near, _i];
                    };
                } forEach _zones;
                if (count _cand > 0) then {
                    _cand = [_cand, [], { _x select 0 }, "ASCEND"] call BIS_fnc_sortBy;
                    private _zi = (_cand select 0) select 1;
                    private _center = [_zones select _zi] call FADE_normPos3;
                    private _sp3 = [_center, _zoneRadius, _spawnMinDistPl] call _fncFindSpawn;
                    private _ent = missionNamespace getVariable ["FADE_operationEntities_" + _taskId, []];
                    if (count _ent >= 6) then {
                        private _grps = _ent select 0;
                        private _vehs = _ent select 4;
                        private _fncMake = missionNamespace getVariable ["FADE_operationMakeVehFn_" + _taskId, {}];
                        if (!(_fncMake isEqualTo {})) then {
                            private _pack = [_sp3, _enemyUnits, _facApply] call _fncMake;
                            _pack params ["_veh", "_vGrp", "_cGrp"];
                            if (!isNull _veh) then {
        _vehs pushBack _veh;
        _grps pushBack _vGrp;
        if (!isNull _cGrp) then { _grps pushBack _cGrp };
        missionNamespace setVariable ["FADE_operationEntities_" + _taskId, [_grps, _ent select 1, _ent select 2, _ent select 3, _vehs, _ent select 5]];
        _veh engineOn true;
        _veh setVariable ["FADE_opHomeIdx", _zi, false];
        [_veh, _taskId, _zi, _zoneRadius] spawn {
            params ["_veh", "_taskId", "_homeIdx", "_zoneRadius"];
            scriptName "FADE_op_traffic_resup";
            sleep (random 0.5);
            while { alive _veh } do {
                private _vehGrp = group driver _veh;
                if (isNull _vehGrp || { isNull driver _veh }) exitWith {};
                if (missionNamespace getVariable ["FADE_operationAborted_" + _taskId, false]) exitWith {};
                if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]) exitWith {};
                private _cap2 = missionNamespace getVariable ["FADE_operationCapState_" + _taskId, []];
                private _zc = missionNamespace getVariable ["FADE_operationZoneCenters_" + _taskId, []];
                if (count _cap2 == 0 || { count _zc == 0 }) exitWith {};
                private _opts = [];
                { if (!(_cap2 select _forEachIndex)) then { _opts pushBack _forEachIndex } } forEach _cap2;
                _opts = _opts - [_homeIdx];
                if (count _opts == 0) exitWith {};
                private _destIdx = selectRandom _opts;
                private _dest = _zc select _destIdx;
                _dest = [_dest] call {
                    params ["_p"];
                    if (count _p < 2) exitWith { [0, 0, 0] };
                    if (count _p < 3) then { [(_p select 0), (_p select 1), 0] } else { _p }
                };
                _vehGrp = group driver _veh;
                if (isNull _vehGrp) exitWith {};
                while { count waypoints _vehGrp > 0 } do { deleteWaypoint [_vehGrp, 0] };
                private _wp = _vehGrp addWaypoint [_dest, 0];
                _wp setWaypointType "MOVE";
                _wp setWaypointCompletionRadius (15 + _zoneRadius * 0.12);
                _vehGrp setCurrentWaypoint _wp;
                private _drv = driver _veh;
                if (!isNull _drv) then { _drv doMove _dest };
                waitUntil {
                    sleep 4;
                    (
                        missionNamespace getVariable ["FADE_operationAborted_" + _taskId, false]
                        || ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"])
                        || (!alive _veh)
                        || ((driver _veh) isEqualTo objNull)
                        || ((_veh distance2D _dest) < (25 + _zoneRadius * 0.12))
                    )
                };
                if (!alive _veh) exitWith {};
                sleep 2 + random 4;
            };
        };
                            };
                        };
                    };
                };
            };
        };
    };
};

// Delete fleet vehicles (not QRF) > _cleanupDist from any player every _cleanupInterval to free spawn cap
[_taskId, _cleanupInterval, _cleanupDist] spawn {
    params ["_taskId", "_cleanupInterval", "_cleanupDist"];
    scriptName "FADE_op_fleetCleanup";
    private _fncPlayers = { private _pl = []; { if (alive _x && { isPlayer _x }) then { _pl pushBack _x } } forEach allPlayers; _pl };
    while { !(missionNamespace getVariable ["FADE_operationAborted_" + _taskId, false]) } do {
        sleep _cleanupInterval;
        if (missionNamespace getVariable ["FADE_operationAborted_" + _taskId, false]) exitWith {};
        private _players = [] call _fncPlayers;
        if (count _players > 0) then {
            private _ent = missionNamespace getVariable ["FADE_operationEntities_" + _taskId, []];
            if (count _ent >= 6) then {
                private _vehs = _ent select 4;
                private _grps = _ent select 0;
                private _newVehs = [];
                {
                    private _v = _x;
                    if (isNull _v) then { } else {
                        if (_v getVariable ["FADE_opVehQrf", false]) then {
                            _newVehs pushBack _v;
                        } else {
                            private _minD = 1e15;
                            { _minD = _minD min (_v distance2D _x) } forEach _players;
                            if (_minD > _cleanupDist) then {
                                private _cg = _v getVariable ["FADE_opCargoGrp", grpNull];
                                if (!isNull _cg) then {
                                    { if (!isNull _x) then { deleteVehicle _x } } forEach units _cg;
                                    deleteGroup _cg;
                                };
                                { if (!isNull _x) then { deleteVehicle _x } } forEach crew _v;
                                private _g = group driver _v;
                                if (!isNull _g) then {
                                    { if (!isNull _x) then { deleteVehicle _x } } forEach units _g;
                                    deleteGroup _g;
                                };
                                if (!isNull _v) then { deleteVehicle _v };
                            } else {
                                _newVehs pushBack _v;
                            };
                        };
                    };
                } forEach _vehs;
                missionNamespace setVariable ["FADE_operationEntities_" + _taskId, [_grps, _ent select 1, _ent select 2, _ent select 3, _newVehs, _ent select 5]];
            };
        };
    };
};

missionNamespace setVariable ["FADE_operationQrfLast_" + _taskId, 0];

[_player, _taskId, _zones, _zoneRadius, _opAllGroups, _markerNames, _basePos, _enemyUnits, _facApply, _markerFriendlyOp, _markerEnemyOp] spawn {
    params ["_player", "_taskId", "_zones", "_zoneRadius", "_opAllGroups", "_markerNames", "_basePos", "_enemyUnits", "_facApply", "_markerFriendlyOp", "_markerEnemyOp"];
    scriptName "FADE_op_main";
    private _captured = [];
    { _captured pushBack false } forEach _zones;

    // Poll every 5s for abort; evaluate zones every 60s (matches ellipse markers — distance2D)
    private _evalInterval = 60;
    private _evalNext = time + _evalInterval;
    waitUntil {
        sleep 5;
        if (missionNamespace getVariable ["FADE_operationAborted_" + _taskId, false]) exitWith { true };
        if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]) exitWith { true };
        if (time < _evalNext) exitWith { false };
        _evalNext = time + _evalInterval;
        missionNamespace setVariable ["FADE_operationCapState_" + _taskId, +_captured];
        {
            private _center = _x;
            private _i = _forEachIndex;
            private _wCnt = [_center, _zoneRadius] call FADE_op_countBluforPlayersInRadius;
            private _eCnt = [_center, _zoneRadius] call FADE_op_countEnemyMenInRadius;
            if (_eCnt > _wCnt) then {
                _captured set [_i, false];
                (_markerNames select (_i * 2)) setMarkerColor _markerEnemyOp;
                (_markerNames select (_i * 2 + 1)) setMarkerColor _markerEnemyOp;
            } else {
                if (_eCnt == 0 && _wCnt > 0) then {
                    _captured set [_i, true];
                    (_markerNames select (_i * 2)) setMarkerColor _markerFriendlyOp;
                    (_markerNames select (_i * 2 + 1)) setMarkerColor _markerFriendlyOp;
                } else {
                    _captured set [_i, false];
                    (_markerNames select (_i * 2)) setMarkerColor "ColorOrange";
                    (_markerNames select (_i * 2 + 1)) setMarkerColor "ColorOrange";
                };
            };
        } forEach _zones;
        missionNamespace setVariable ["FADE_operationCapState_" + _taskId, +_captured];

        private _allCap = { _x } count _captured == count _zones && count _zones > 0;
        if (_allCap) exitWith {
            [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
            ["<t size='1.2' color='#90EE90'>MISSION COMPLETE</t><br/><br/><t color='#E0E0E0'>All zones captured.</t>"] remoteExec ["FADE_showMissionHint", _player];
            true
        };
        false
    };

    missionNamespace setVariable ["FADE_operationAborted_" + _taskId, true];
    sleep 1;
    { [_x] call FADE_deleteMarkerSafe } forEach _markerNames;
    if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
    private _entEnd = missionNamespace getVariable ["FADE_operationEntities_" + _taskId, []];
    if (count _entEnd >= 6) then {
        { if (!isNull _x) then { deleteVehicle _x } } forEach (_entEnd select 4);
        { if (!isNull _x) then { deleteVehicle _x } } forEach (_entEnd select 5);
    };
    missionNamespace setVariable ["FADE_operationEntities_" + _taskId, nil];
    missionNamespace setVariable ["FADE_operationMakeVehFn_" + _taskId, nil];
    missionNamespace setVariable ["FADE_operationCapState_" + _taskId, nil];
    missionNamespace setVariable ["FADE_operationZoneCenters_" + _taskId, nil];
    missionNamespace setVariable ["FADE_operationQrfLast_" + _taskId, nil];

    sleep 60;
    { if (!isNull _x) then { { deleteVehicle _x } forEach units _x; deleteGroup _x } } forEach _opAllGroups;
};

[_player, _taskId, _zones, _zoneRadius, _enemyUnits, _facApply] spawn {
    params ["_player", "_taskId", "_zones", "_zoneRadius", "_enemyUnits", "_facApply"];
    scriptName "FADE_op_qrf";
    private _qrfCd = missionNamespace getVariable ["FADE_operationQrfCooldown", 180];
    while {
        !(missionNamespace getVariable ["FADE_operationAborted_" + _taskId, false])
        && { !((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]) }
    } do {
        sleep 5;
        if ((time - (missionNamespace getVariable ["FADE_operationQrfLast_" + _taskId, 0])) >= _qrfCd) then {
        private _cap = missionNamespace getVariable ["FADE_operationCapState_" + _taskId, []];
        if (count _cap == count _zones) then {
        private _didQrf = false;
        {
            if (_didQrf) exitWith {};
            private _zoneCenter = _x;
            private _i = _forEachIndex;
            private _w = [_zoneCenter, _zoneRadius] call FADE_op_countBluforPlayersInRadius;
            private _e = [_zoneCenter, _zoneRadius] call FADE_op_countEnemyMenInRadius;
            if (_w > 0 && _e > 0) then {
                private _bestJ = -1;
                private _bestD = 1e15;
                {
                    private _j = _forEachIndex;
                    if (_j != _i && !(_cap select _j)) then {
                        private _d = (_zones select _j) distance2D _zoneCenter;
                        if (_d < _bestD) then { _bestD = _d; _bestJ = _j };
                    };
                } forEach _zones;
                if (_bestJ >= 0) then {
                    missionNamespace setVariable ["FADE_operationQrfLast_" + _taskId, time];
                    _didQrf = true;
                    private _from = _zones select _bestJ;
                    private _nVeh = 1 + floor random 3;
                    [_from, _zoneCenter, _enemyUnits, _facApply, _taskId, _nVeh, _zoneRadius] call {
                        params ["_fromCenter", "_toCenter", "_enemyUnits", "_facApply", "_taskId", "_nVehs", "_zoneRadius"];
                        private _sp = [_fromCenter, _zoneRadius, _spawnMinDistPl] call _fnc_opFindSpawnPos;
                        private _to3 = [_toCenter] call {
                            params ["_p"];
                            if (count _p < 2) exitWith { [0, 0, 0] };
                            if (count _p < 3) then { [(_p select 0), (_p select 1), 0] } else { _p }
                        };
                        private _dir = _sp getDir _to3;
                        private _fncMake = missionNamespace getVariable ["FADE_operationMakeVehFn_" + _taskId, {}];
                        for "_qv" from 0 to (_nVehs - 1) do {
                            if (_qv > 0) then { sleep 6 };
                            private _off = _sp getPos [12 * _qv, _dir + 90];
                            if (count _off < 3) then { _off = [(_off select 0), (_off select 1), 0] };
                            private _pack = [_off, _enemyUnits, _facApply] call _fncMake;
                            _pack params ["_veh", "_vGrp", "_cGrp"];
                            if (!isNull _veh) then {
                                _veh setVariable ["FADE_opVehQrf", true, false];
                                _veh setDir _dir;
                                _veh engineOn true;
                                private _wp1 = _vGrp addWaypoint [_to3, 0];
                                _wp1 setWaypointType "MOVE";
                                _wp1 setWaypointCompletionRadius 20;
                                private _wp2 = _vGrp addWaypoint [_to3, 0];
                                _wp2 setWaypointType "SAD";
                                private _ent = missionNamespace getVariable ["FADE_operationEntities_" + _taskId, []];
                                if (count _ent >= 6) then {
                                    private _vehs = _ent select 4;
                                    _vehs pushBack _veh;
                                    _ent set [4, _vehs];
                                    private _grps = _ent select 0;
                                    _grps pushBack _vGrp;
                                    if (!isNull _cGrp) then { _grps pushBack _cGrp };
                                    _ent set [0, _grps];
                                    missionNamespace setVariable ["FADE_operationEntities_" + _taskId, _ent];
                                };
                                [_veh, _vGrp, _cGrp, _to3, _enemyUnits, _facApply] spawn {
                                    params ["_veh", "_vehGrp", "_cargoGrp", "_to3", "_enemyUnits", "_facApply"];
                                    private _poll = missionNamespace getVariable ["FADE_counterAttackPollInterval", 10];
                                    waitUntil {
                                        sleep _poll;
                                        !alive _veh || { isNull _veh } || { (_veh distance2D _to3) < 130 }
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
                                        private _wp = _cargoGrp addWaypoint [_to3, 0];
                                        _wp setWaypointType "SAD";
                                    };
                                };
                            };
                        };
                    };
                };
            };
        } forEach _zones;
        };
        };
    };
};
