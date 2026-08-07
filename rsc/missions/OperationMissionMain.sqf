// OperationMissionMain.sqf - multi-zone capture loop
if (!isServer) exitWith {};
FADE_operationMissionMain = {
if (isNil "FADE_operationParams" || { count FADE_operationParams < 6 }) exitWith {};

FADE_operationParams params ["_player", ["_mapAnchor", []], "_taskId", "_basePos", "_enemyUnits", ["_operationNameUpper", "OPERATION"], ["_operationName", "Operation"]];
if (!([_mapAnchor] call FADE_fnc_isValidMapClickPos)) then {
    _mapAnchor = [];
};
private _mkrJitter = missionNamespace getVariable ["FADE_jitterMarkerPos", { params [["_p", [0, 0, 0]]]; [_p] call FADE_normPos3 }];

_enemyUnits = [_enemyUnits] call FADE_resolveScenarioEnemyUnits;

private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
private _sideFriendly = missionNamespace getVariable ["FADE_sideFriendly", west];
private _markerFriendlyOp = missionNamespace getVariable ["FADE_markerColorFriendly", "ColorWEST"];
private _markerEnemyOp = missionNamespace getVariable ["FADE_markerColorEnemy", "ColorEAST"];

// bis_fnc_tasksetparent: ensured once in initServer (FADE_ensureBisTaskSetParent); safe to call again if needed
[] call FADE_ensureBisTaskSetParent;

if (count _enemyUnits == 0) exitWith {
    if (!isNull _player) then { [_player] call FADE_clearActiveMission };
    [_player, "MISSION ERROR", "No enemy units configured."] call FADE_missionErrorHint;
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
    [_player, "MISSION ERROR", "No civ zones (dynamic build found none). Check map locations vs HQ distance (FADE_civZoneMinDistFromBase)."] call FADE_missionErrorHint;
};

private _minDistFromBase = 1000;
private _civCandidates = [];
{
    private _trig = missionNamespace getVariable [_x, objNull];
    if (!isNull _trig) then {
        private _p = getPosATL _trig;
        if (count _p >= 2 && { (_p distance _basePos) >= _minDistFromBase }) then {
            _civCandidates pushBack [_x, [(_p select 0), (_p select 1), (_p param [2, 0])]];
        };
    };
} forEach _civNames;

if (count _civCandidates == 0) exitWith {
    if (!isNull _player) then { [_player] call FADE_clearActiveMission };
    [_player, "MISSION ERROR", "No civ zones far enough from base."] call FADE_missionErrorHint;
};

private _useMapAnchor = [_mapAnchor] call FADE_fnc_isValidMapClickPos;
private _wantN = missionNamespace getVariable ["FADE_operationZoneCount", 6];
_wantN = (round _wantN) max 2 min 10;
private _mapAnchorPick = if (_useMapAnchor) then { _mapAnchor } else { [] };
private _zoneEntries = [_civCandidates, _wantN, _mapAnchorPick] call FADE_operation_pickZones;
if (count _zoneEntries < 2) exitWith {
    if (!isNull _player) then { [_player] call FADE_clearActiveMission };
    [_player, "MISSION ERROR", "Not enough civ zones to build an operation (need hub + at least one outer zone)."] call FADE_missionErrorHint;
};

private _zoneCivIds = _zoneEntries apply { _x select 0 };
private _zones = _zoneEntries apply { _x select 1 };
private _hqIdx = 0;
{
    if (!isNil "FADE_enemyPatrol_despawnForZone") then { [_x] call FADE_enemyPatrol_despawnForZone };
    if (!isNil "FADE_dynamicRoadblocks_despawnForZone") then { [_x] call FADE_dynamicRoadblocks_despawnForZone };
} forEach _zoneCivIds;
missionNamespace setVariable ["FADE_operationCivZoneIds_" + _taskId, +_zoneCivIds];
if (!isNil "FADE_civ_pinZones") then { [_zoneCivIds] call FADE_civ_pinZones };

private _zoneCodenames = [_taskId, count _zones] call FADE_raid_pickObjectiveCodenames;
private _maxFleet = missionNamespace getVariable ["FADE_operationMaxFleetVehicles", 10];
private _spawnMinDistPl = missionNamespace getVariable ["FADE_operationSpawnMinDistPlayers", 1000];
private _cleanupInterval = missionNamespace getVariable ["FADE_operationCleanupInterval", 600];
private _cleanupDist = missionNamespace getVariable ["FADE_operationCleanupDistPlayers", 2000];
private _operationCenter = [_zones select _hqIdx] call FADE_normPos3;

private _zoneRadius = 250;
private _opAllGroups = [];
[_taskId, _opAllGroups] call FADE_missionEnt_bindGroups;
private _allVehs = [];
private _barrels = [];
private _markerNames = [];

private _facApply = missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}];

private _fnc_opPlayers = FADE_getAlivePlayers;
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
        [[_zoneCenter, 0, _zoneRadius * 0.85, 10, 1, 0.4, 0, [], _zoneCenter], _zoneCenter] call FADE_findSafePosArray
    };
    private _zc = [_zoneCenter] call FADE_normPos3;
    private _try = 0;
    private _r = [];
    while { _try < 45 && count _r < 2 } do {
        _try = _try + 1;
        private _angle = random 360;
        private _dist = random (_zoneRadius * 0.95);
        private _sp = [(_zc select 0) + _dist * cos _angle, (_zc select 1) + _dist * sin _angle, 0];
        _sp = [[_sp, 0, 25, 3, 1, 0.4, 0, [], _sp], _zc] call FADE_findSafePosArray;
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
    _sp = [[_sp, 0, 50, 5, 1, 0.4, 0, [], _sp], _zc] call FADE_findSafePosArray;
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

// Returns [vehicle, driverGroup, cargoGroup]  -  cargoGroup may be grpNull
// Must not close over other private locals: stored in missionNamespace and called from resupply/QRF after this script ends.
private _fnc_opMakeVeh = {
    params ["_spawnPos", "_enemyUnits", "_facApply", ["_existingVehs", []], ["_dirToward", []], ["_roadSearchM", 450]];
    private _sp = _spawnPos;
    if (count _sp < 2) then { _sp = [0, 0, 0] };
    if (count _sp < 3) then { _sp = [(_sp select 0), (_sp select 1), 0] };
    private _roadHit = [_sp, _roadSearchM, _existingVehs, -1, [], _dirToward] call FADE_findOpforGroundVehicleRoadSpawn;
    if (_roadHit isEqualTo []) exitWith { [objNull, grpNull, grpNull] };
    _roadHit params ["_sp", "_vehDir"];
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
    _veh setDir _vehDir;
    _veh setVectorUp surfaceNormal _sp;
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
    [_veh, _enemyUnits] call FADE_ensureEnemyVehicleGunner;
    if (!(_facApply isEqualTo {})) then { [_vehGrp] call _facApply };
    _veh setVariable ["FADE_opCargoGrp", _cargoGrp, false];
    [_veh, _vehGrp, _cargoGrp]
};

{
    private _idx = _forEachIndex;
    private _center = [_x] call FADE_normPos3;
    private _codename = _zoneCodenames select _idx;
    private _markerText = if (_idx == _hqIdx) then {
        format ["%1 (OPFOR HQ)", _codename]
    } else {
        _codename
    };
    [_taskId, "FADE_op", _idx, _center, _zoneRadius, _markerEnemyOp, _markerText, _mkrJitter, _markerNames] call FADE_zone_createCaptureMarkerPair;

    // --- Patrols (2 groups, loop around the ellipse) ---
    private _numPatrol = [2, 1] call _scaleOpforCount;
    for "_pg" from 0 to (_numPatrol - 1) do {
        private _angle0 = (_pg / (_numPatrol max 1)) * 360 + random 45;
        private _dist0 = 50 + random ((_zoneRadius - 50) max 0);
        private _sp = [(_center select 0) + _dist0 * (cos _angle0), (_center select 1) + _dist0 * (sin _angle0), 0];
        _sp = [[_sp, 0, 25, 3, 1, 0.4, 0, [], _sp], _center] call FADE_findSafePosArray;
        private _ps = [3 + floor random 3, 2] call _scaleOpforCount;
        private _shuf = _enemyUnits call BIS_fnc_arrayShuffle;
        private _classes = _shuf select [0, _ps min count _shuf];
        if (count _classes == 0) then { _classes = [_enemyUnits select 0] };
        private _grp = [_sp, _sideEnemy, _classes] call FADE_missionCreateInfantryGroupAt;
        if (!isNull _grp) then {
            if (!(_facApply isEqualTo {})) then { [_grp] call _facApply };
            [_grp, _center, 60, (_zoneRadius - 10) max 80, 4, _angle0, 90, "AWARE", "RED", "LIMITED", true] call FADE_missionApplyPatrolCycle;
            _opAllGroups pushBack _grp;
        };
    };

    // --- Garrison in buildings + optional smoking barrel (subset of buildings in widened scan; deferred spawn) ---
    private _vgOp = missionNamespace getVariable ["FADE_vg_register", {}];
    private _opGarMult = missionNamespace getVariable ["FADE_garrisonOperationScanMult", 1.25];
    private _opBChance = missionNamespace getVariable ["FADE_garrisonMissionNearbyBuildingChance", 0.25];
    private _blds = nearestObjects [_center, ["House", "Building"], _zoneRadius * 0.95 * _opGarMult];
    _blds = (_blds select { count (_x buildingPos -1) >= 2 }) call BIS_fnc_arrayShuffle;
    private _bldsPick = _blds select { random 1 < _opBChance };
    if (count _bldsPick < 1) then { _bldsPick = +_blds };
    private _maxB = (2 min count _bldsPick);
    for "_b" from 0 to (_maxB - 1) do {
        private _building = _bldsPick select _b;
        private _bps = _building buildingPos -1;
        private _slotATL = [];
        private _addedSlots = 0;
        for "_i" from 0 to (count _bps - 1) do {
            if (_addedSlots >= 3) exitWith {};
            private _pos = _bps select _i;
            if (count _pos >= 2) then {
                if (count _pos < 3) then { _pos = [(_pos select 0), (_pos select 1), 0] };
                _slotATL pushBack _pos;
                _addedSlots = _addedSlots + 1;
            };
        };
        if (count _slotATL > 0 && { !(_vgOp isEqualTo {}) }) then {
            private _bc = getPosATL _building;
            _bc = [_bc] call FADE_normPos3;
            private _st = createHashMap;
            _st set ["owner", format ["op:%1", _taskId]];
            _st set ["groupsRef", _opAllGroups];
            _st set ["barrelsRef", _barrels];
            _st set ["tryBarrel", true];
            _st set ["barrelMinDistPlayersM", -1];
            _st set ["barrelRoll", missionNamespace getVariable ["FADE_vgLazyOutdoorHintChance", 0.5]];
            _st set ["barrelClasses", missionNamespace getVariable ["FADE_vgLazyOutdoorHintClasses", ["MetalBarrel_burning_F"]]];
            _st set ["barrelCenter", _bc];
            _st set ["facApply", !(_facApply isEqualTo {})];
            [_building, _slotATL, [], _st] call _vgOp;
        } else {
            if (count _slotATL > 0) then {
                private _grpG = createGroup _sideEnemy;
                {
                    private _pos = +_x;
                    private _cls = selectRandom _enemyUnits;
                    private _u = _grpG createUnit [_cls, _pos, [], 0, "NONE"];
                    if (!isNull _u) then {
                        if (!(_facApply isEqualTo {})) then { [_grpG] call _facApply };
                        _u setPos _pos;
                        _u setUnitPos "MIDDLE";
                        [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                    };
                } forEach _slotATL;
                if (count units _grpG > 0) then {
                    _grpG setBehaviour "AWARE";
                    _grpG setCombatMode "RED";
                    _opAllGroups pushBack _grpG;
                    if (random 1 < 0.5) then {
                        private _bc2 = getPosATL _building;
                        _bc2 = [_bc2] call FADE_normPos3;
                        private _barrelPos = [_bc2, 0, 18] call FADE_findOutdoorHintPos;
                        if (count _barrelPos >= 2) then {
                            private _bar = createVehicle ["MetalBarrel_burning_F", _barrelPos, [], 0, "NONE"];
                            if (!isNull _bar) then {
                                _bar setPosATL _barrelPos;
                                _barrels pushBack _bar;
                            };
                        };
                    };
                } else {
                    deleteGroup _grpG;
                };
            };
        };
    };

    // --- One vehicle per zone at start (up to _maxFleet) + traffic loop (spawn ≥ _spawnMinDistPl from all players)
    if (count _allVehs < _maxFleet) then {
        private _vsp = [_center, _zoneRadius, _spawnMinDistPl] call _fnc_opFindSpawnPos;
        private _pack = [_vsp, _enemyUnits, _facApply, _allVehs, _center, _zoneRadius] call _fnc_opMakeVeh;
        _pack params ["_veh", "_vGrp", "_cGrp"];
        if (!isNull _veh) then {
            _veh setVariable ["FADE_opHomeIdx", _idx, false];
            _allVehs pushBack _veh;
            [_taskId, _veh] call FADE_missionEnt_registerVehicle;
            _opAllGroups pushBack _vGrp;
            if (!isNull _cGrp) then { _opAllGroups pushBack _cGrp };
            _veh engineOn true;
            // Traffic spawn runs after missionNamespace (zone centers / cap) is set  -  see below.
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
missionNamespace setVariable ["FADE_operationHqIdx_" + _taskId, _hqIdx];

private _captured = [];
{ _captured pushBack false } forEach _zones;
missionNamespace setVariable ["FADE_operationCapState_" + _taskId, +_captured];

missionNamespace setVariable ["FADE_operationEntities_" + _taskId, [_opAllGroups, _markerNames, _zones, _zoneRadius, _allVehs, _barrels]];

private _taskBuilderOp = missionNamespace getVariable ["FADE_buildMissionTaskSmeacText", {}];
private _friendlyPlayerCountOp = [_sideFriendly] call (missionNamespace getVariable ["FADE_countFriendlyPlayers", { 0 }]);
private _acreSummaryOp = [] call (missionNamespace getVariable ["FADE_getAcreChannelSummary", { "ACRE channel names unavailable" }]);
private _actualOpforCountOp = [_sideEnemy] call FADE_getEnemyMenCount;
private _opforBaselineOp = if (_actualOpforCountOp > 0) then { _actualOpforCountOp } else { 36 };
private _opforCountFactorOp = if (random 1 < 0.5) then { 0.8 } else { 1.2 };
private _estimatedOpforCountOp = (round (_opforBaselineOp * _opforCountFactorOp)) max 0;
private _topoOp = [_operationCenter] call (missionNamespace getVariable ["FADE_getTopographySummary", { ["UNKNOWN", "Unknown area"] }]);
private _topoGridOp = _topoOp param [0, "UNKNOWN"];
private _topoAreaOp = _topoOp param [1, "Unknown area"];
private _enemyFactionClassOp = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
private _enemyFactionNameOp = getText (configFile >> "CfgFactionClasses" >> _enemyFactionClassOp >> "displayName");
if (_enemyFactionNameOp == "") then { _enemyFactionNameOp = _enemyFactionClassOp };
private _friendlyFactionClassOp = missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"];
private _friendlyFactionNameOp = getText (configFile >> "CfgFactionClasses" >> _friendlyFactionClassOp >> "displayName");
if (_friendlyFactionNameOp == "") then { _friendlyFactionNameOp = _friendlyFactionClassOp };
private _intelFormatterOp = missionNamespace getVariable ["FADE_formatSituationIntelHtml", {}];
if (!isNil "FADE_lore_generate") then {
    private _loreOp = ["Operation", _operationCenter, _operationName] call FADE_lore_generate;
    if (_loreOp isEqualType [] && { count _loreOp >= 3 }) then {
        missionNamespace setVariable ["FADE_missionRun_loreSmeacHtml", _loreOp select 2];
        missionNamespace setVariable ["FADE_missionRun_loreShort", _loreOp select 0];
        missionNamespace setVariable ["FADE_missionRun_loreLong", _loreOp select 1];
    };
};
private _situationIntelOp = if (_intelFormatterOp isEqualTo {}) then {
    format [
        "<t align='left' color='#B0B0B0'>Topography: Grid %1 | Area: %2</t><br/><t align='left' color='#B0B0B0'>Enemy: %3 | Strength: ~%4 personnel (estimated).</t>",
        _topoGridOp,
        _topoAreaOp,
        _enemyFactionNameOp,
        _estimatedOpforCountOp
    ]
} else {
    [
        "Operation",
        _operationCenter,
        _sideEnemy,
        _sideFriendly,
        _estimatedOpforCountOp,
        _opforCountFactorOp,
        _enemyFactionNameOp,
        _friendlyFactionNameOp,
        _friendlyPlayerCountOp,
        _topoGridOp,
        _topoAreaOp
    ] call _intelFormatterOp
};
private _loreAppendFn = missionNamespace getVariable ["FADE_lore_appendSituationHtml", { params ["_s"]; _this select 0 }];
_situationIntelOp = [_situationIntelOp] call _loreAppendFn;
private _situationIntelOpHint = if (_intelFormatterOp isEqualTo {}) then {
    format [
        "<t align='left' color='#FFFFFF'>Topography: Grid %1 | Area: %2</t><br/><t align='left' color='#FFFFFF'>Enemy: %3 | Strength: ~%4 personnel (estimated).</t>",
        _topoGridOp,
        _topoAreaOp,
        _enemyFactionNameOp,
        _estimatedOpforCountOp
    ]
} else {
    [
        "Operation",
        _operationCenter,
        _sideEnemy,
        _sideFriendly,
        _estimatedOpforCountOp,
        _opforCountFactorOp,
        _enemyFactionNameOp,
        _friendlyFactionNameOp,
        _friendlyPlayerCountOp,
        _topoGridOp,
        _topoAreaOp,
        "#FFFFFF"
    ] call _intelFormatterOp
};
private _defaultAdminOp = missionNamespace getVariable ["FADE_missionRun_defaultAdminTaskText", ""];
private _defaultCommandOp = missionNamespace getVariable ["FADE_missionRun_defaultCommandTaskText", ""];
private _zeroAlphaNameOp = [] call (missionNamespace getVariable ["FADE_getZeroAlphaDisplayName", { "UNASSIGNED" }]);
private _taskDescOp = if (_taskBuilderOp isEqualTo {}) then {
    format [
        "Capture all outer zones, then secure the OPFOR HQ (%1). Clear OPFOR, enter each zone to secure it, then prevent enemy re-entry.",
        _zoneCodenames select _hqIdx
    ]
} else {
    private _outerNames = [];
    for "_zi" from 0 to (count _zones - 1) do {
        if (_zi != _hqIdx) then { _outerNames pushBack (_zoneCodenames select _zi) };
    };
    [
        format [
            "Clear and capture outer zones (%1), then assault OPFOR HQ %2 (%3) at Grid %4.",
            _outerNames joinString ", ",
            _zoneCodenames select _hqIdx,
            mapGridPosition _operationCenter,
            _topoGridOp
        ],
        _operationCenter,
        _situationIntelOp,
        "Work outward from the nearest sectors, then collapse the hub once every spoke is secured.",
        _defaultAdminOp,
        _defaultCommandOp
    ] call _taskBuilderOp
};
[_sideFriendly, _taskId, [_taskDescOp, "Operation", ""], _operationCenter, "CREATED", 1, true, "attack", true] call BIS_fnc_taskCreate;
private _hqBoardFnOp = missionNamespace getVariable ["FADE_hqMainBoard_setObjectiveBrief", {}];
if (_hqBoardFnOp isEqualType {} && { !(_hqBoardFnOp isEqualTo {}) }) then { [_operationCenter] call _hqBoardFnOp };

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

private _briefGuiTail = toString [10] + toString [10] + "See Tasks and map markers for grids, routes, and win/fail criteria.";
private _brief = format [
    "OPERATION%1%1Hub-and-spoke fight: clear outer zones first, then the OPFOR HQ. Reinforcements spawn from the hub.%1%1Capture rules and evaluation are on task.",
    toString [10]
] + _briefGuiTail;
if (!isNull _player) then {
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    private _starterName = if (isNull _player) then { "Unknown" } else { name _player };
    [_operationNameUpper, _starterName] remoteExec ["FADE_showMissionAssignedIntro", 0];
    [_player, "Operation"] call FADE_notifyOthersMissionStarted;
};

// Fleet resupply (enemy-held zones only): one global timer; spawn at zone flag nearest players, ≥1000m from players, cap _maxFleet (QRF/air excluded from count)
private _resMin = missionNamespace getVariable ["FADE_operationVehicleResupplyMin", 240];
private _resMax = missionNamespace getVariable ["FADE_operationVehicleResupplyMax", 360];
private _resSpan = (_resMax - _resMin) max 0;
[_taskId, _zones, _zoneRadius, _enemyUnits, _facApply, _resMin, _resMax, _resSpan, _maxFleet, _spawnMinDistPl] spawn {
    params ["_taskId", "_zones", "_zoneRadius", "_enemyUnits", "_facApply", "_resMin", "_resMax", "_resSpan", "_maxFleet", "_spawnMinDistPl"];
    scriptName "FADE_op_resupply";
    private _fncPlayers = FADE_getAlivePlayers;
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
            [[_zoneCenter, 0, _zr * 0.85, 10, 1, 0.4, 0, [], _zoneCenter], _zoneCenter] call FADE_findSafePosArray
        };
        private _zc = [_zoneCenter] call FADE_normPos3;
        private _try = 0;
        private _r = [];
        while { _try < 45 && count _r < 2 } do {
            _try = _try + 1;
            private _angle = random 360;
            private _dist = random (_zr * 0.95);
            private _sp = [(_zc select 0) + _dist * cos _angle, (_zc select 1) + _dist * sin _angle, 0];
            _sp = [[_sp, 0, 25, 3, 1, 0.4, 0, [], _sp], _zc] call FADE_findSafePosArray;
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
        _sp = [[_sp, 0, 50, 5, 1, 0.4, 0, [], _sp], _zc] call FADE_findSafePosArray;
        if (count _sp < 2) then { _sp = _zc };
        _sp
    };
    while { !(missionNamespace getVariable ["FADE_operationAborted_" + _taskId, false]) } do {
        sleep ((_resMin min _resMax) + random _resSpan);
        if (missionNamespace getVariable ["FADE_operationAborted_" + _taskId, false]) exitWith {};
        if ([_taskId] call _fncCountFleet < _maxFleet) then {
            private _cap = missionNamespace getVariable ["FADE_operationCapState_" + _taskId, []];
            private _hqI = missionNamespace getVariable ["FADE_operationHqIdx_" + _taskId, 0];
            if (count _cap == count _zones && { !(_cap select _hqI) }) then {
                private _center = [_zones select _hqI] call FADE_normPos3;
                private _sp3 = [_center, _zoneRadius, _spawnMinDistPl] call _fncFindSpawn;
                private _ent = missionNamespace getVariable ["FADE_operationEntities_" + _taskId, []];
                if (count _ent >= 6) then {
                    private _grps = _ent select 0;
                    private _vehs = _ent select 4;
                    private _fncMake = missionNamespace getVariable ["FADE_operationMakeVehFn_" + _taskId, {}];
                    if (!(_fncMake isEqualTo {})) then {
                        private _pack = [_sp3, _enemyUnits, _facApply, _vehs, _center, _zoneRadius] call _fncMake;
                        _pack params ["_veh", "_vGrp", "_cGrp"];
                        if (!isNull _veh) then {
        _vehs pushBack _veh;
        [_taskId, _veh] call FADE_missionEnt_registerVehicle;
        _grps pushBack _vGrp;
        if (!isNull _cGrp) then { _grps pushBack _cGrp };
        missionNamespace setVariable ["FADE_operationEntities_" + _taskId, [_grps, _ent select 1, _ent select 2, _ent select 3, _vehs, _ent select 5]];
        _veh engineOn true;
        _veh setVariable ["FADE_opHomeIdx", _hqI, false];
        [_veh, _taskId, _hqI, _zoneRadius] spawn {
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

// Delete fleet vehicles (not QRF) > _cleanupDist from any player every _cleanupInterval to free spawn cap
[_taskId, _cleanupInterval, _cleanupDist] spawn {
    params ["_taskId", "_cleanupInterval", "_cleanupDist"];
    scriptName "FADE_op_fleetCleanup";
    private _fncPlayers = FADE_getAlivePlayers;
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

missionNamespace setVariable ["FADE_operationQrfLast_" + _taskId, time];

[_player, _taskId, _zones, _zoneRadius, _opAllGroups, _markerNames, _basePos, _enemyUnits, _facApply, _markerFriendlyOp, _markerEnemyOp, _hqIdx] spawn {
    params ["_player", "_taskId", "_zones", "_zoneRadius", "_opAllGroups", "_markerNames", "_basePos", "_enemyUnits", "_facApply", "_markerFriendlyOp", "_markerEnemyOp", "_hqIdx"];
    scriptName "FADE_op_main";
    private _captured = [];
    { _captured pushBack false } forEach _zones;
    private _opOwner = format ["op:%1", _taskId];
    private _vgCancelEllipse = missionNamespace getVariable ["FADE_vg_cancelPendingInEllipse", {}];
    private _fnc_spokesCaptured = {
        params ["_cap", "_hqI"];
        private _ok = true;
        for "_si" from 0 to (count _cap - 1) do {
            if (_si == _hqI) then { continue };
            if (!(_cap select _si)) exitWith { _ok = false };
        };
        _ok
    };

    waitUntil {
        sleep 5;
        if (missionNamespace getVariable ["FADE_operationAborted_" + _taskId, false]) exitWith { true };
        if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]) exitWith { true };

        private _hqUnlocked = [_captured, _hqIdx] call _fnc_spokesCaptured;
        {
            private _center = _x;
            private _i = _forEachIndex;
            private _wasCap = _captured select _i;
            private _bluforCnt = [_center, _zoneRadius] call FADE_op_countBluforInRadius;
            private _eCnt = [_center, _zoneRadius] call FADE_op_countEnemyMenSpawnedInRadius;
            private _mArea = _markerNames select (_i * 2);
            private _mIcon = _markerNames select (_i * 2 + 1);
            private _captureAllowed = (_i != _hqIdx) || _hqUnlocked;
            _captured set [_i, [
                _center, _zoneRadius, _wasCap, _bluforCnt, _eCnt,
                _mArea, _mIcon, _markerFriendlyOp, _markerEnemyOp,
                _vgCancelEllipse, _opOwner, _captureAllowed
            ] call FADE_zone_tickOperationCapture];
        } forEach _zones;
        missionNamespace setVariable ["FADE_operationCapState_" + _taskId, +_captured];

        private _allCap = { _x } count _captured == count _zones && count _zones > 0;
        if (_allCap) exitWith {
            [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
            [_player, "All zones captured."] call FADE_missionSuccessHint;
            true
        };
        false
    };

    missionNamespace setVariable ["FADE_operationAborted_" + _taskId, true];
    private _vgOpX = missionNamespace getVariable ["FADE_vg_cancelPendingByOwner", {}];
    if (!(_vgOpX isEqualTo {})) then { [format ["op:%1", _taskId]] call _vgOpX };
    sleep 1;
    if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
    [_taskId, "", _player, 60] call FADE_mission_completeCleanup;
};

[_player, _taskId, _zones, _zoneRadius, _enemyUnits, _facApply, _spawnMinDistPl] spawn {
    params ["_player", "_taskId", "_zones", "_zoneRadius", "_enemyUnits", "_facApply", "_spawnMinDistPl"];
    scriptName "FADE_op_qrf";
    // QRF runs in a separate scheduled scope; redefine helpers here because
    // _fnc_opFindSpawnPos / _spawnMinDistPl from the main script body are not visible inside this spawn.
    private _fncPlayersQ = FADE_getAlivePlayers;
    private _fncFindSpawn = {
        params ["_zoneCenter", "_zr", "_minD"];
        private _players = [] call _fncPlayersQ;
        if (count _players == 0) exitWith {
            [[_zoneCenter, 0, _zr * 0.85, 10, 1, 0.4, 0, [], _zoneCenter], _zoneCenter] call FADE_findSafePosArray
        };
        private _zc = [_zoneCenter] call FADE_normPos3;
        private _try = 0;
        private _r = [];
        while { _try < 45 && count _r < 2 } do {
            _try = _try + 1;
            private _angle = random 360;
            private _dist = random (_zr * 0.95);
            private _sp = [(_zc select 0) + _dist * cos _angle, (_zc select 1) + _dist * sin _angle, 0];
            _sp = [[_sp, 0, 25, 3, 1, 0.4, 0, [], _sp], _zc] call FADE_findSafePosArray;
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
        _sp = [[_sp, 0, 50, 5, 1, 0.4, 0, [], _sp], _zc] call FADE_findSafePosArray;
        if (count _sp < 2) then { _sp = _zc };
        _sp
    };
    private _qrfCd = missionNamespace getVariable ["FADE_operationQrfCooldown", 180];
    while {
        !(missionNamespace getVariable ["FADE_operationAborted_" + _taskId, false])
        && { !((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]) }
    } do {
        sleep 5;
        if ((time - (missionNamespace getVariable ["FADE_operationQrfLast_" + _taskId, 0])) >= _qrfCd) then {
        private _cap = missionNamespace getVariable ["FADE_operationCapState_" + _taskId, []];
        private _hqI = missionNamespace getVariable ["FADE_operationHqIdx_" + _taskId, 0];
        if (count _cap == count _zones && { !(_cap select _hqI) }) then {
        private _didQrf = false;
        {
            if (_didQrf) exitWith {};
            private _zoneCenter = _x;
            private _i = _forEachIndex;
            if (!(_cap select _i)) then {
            private _w = [_zoneCenter, _zoneRadius] call FADE_op_countBluforPlayersInRadius;
            private _e = [_zoneCenter, _zoneRadius] call FADE_op_countEnemyMenSpawnedInRadius;
            if (_w > 0 && _e > 0) then {
                    missionNamespace setVariable ["FADE_operationQrfLast_" + _taskId, time];
                    _didQrf = true;
                    ["opQrf trigger task=%1 zoneIdx=%2 blu=%3 enemy=%4 center=%5", _taskId, _i, _w, _e, _zoneCenter] call FADE_qrfDbgLog;
                    private _from = _zones select _hqI;
                    private _footGrps = [];
                    private _footFn = missionNamespace getVariable ["FADE_counterAttack_spawnFootWave", {}];
                    if (!(_footFn isEqualTo {})) then {
                        ["opQrf footWave task=%1 zone=%2", _taskId, _zoneCenter] call FADE_qrfDbgLog;
                        [_taskId, _zoneCenter, _enemyUnits, _footGrps, _facApply] call _footFn;
                        private _entFoot = missionNamespace getVariable ["FADE_operationEntities_" + _taskId, []];
                        if (count _entFoot >= 1 && { count _footGrps > 0 }) then {
                            private _grpsFoot = _entFoot select 0;
                            { _grpsFoot pushBack _x } forEach _footGrps;
                            _entFoot set [0, _grpsFoot];
                            missionNamespace setVariable ["FADE_operationEntities_" + _taskId, _entFoot];
                        };
                    };
                    private _flOp = missionNamespace getVariable ["FADE_qrfSpawnHintFlare", {}];
                    if (!(_flOp isEqualTo {})) then { [_from, _zoneRadius] call _flOp };
                    private _nVeh = 1 + floor random 3;
                    ["opQrf vehicles task=%1 fromHQ=%2 nVeh=%3 zone=%4", _taskId, _from, _nVeh, _zoneCenter] call FADE_qrfDbgLog;
                    [_from, _zoneCenter, _enemyUnits, _facApply, _taskId, _nVeh, _zoneRadius, _spawnMinDistPl, _fncFindSpawn] call {
                        params ["_fromCenter", "_toCenter", "_enemyUnits", "_facApply", "_taskId", "_nVehs", "_zoneRadius", "_spawnMinDistPl", "_fncFindSpawn"];
                        private _sp = [_fromCenter, _zoneRadius, _spawnMinDistPl] call _fncFindSpawn;
                        private _to3 = [_toCenter] call {
                            params ["_p"];
                            if (count _p < 2) exitWith { [0, 0, 0] };
                            if (count _p < 3) then { [(_p select 0), (_p select 1), 0] } else { _p }
                        };
                        private _huntOp = (([_to3, _zoneRadius] call FADE_op_countBluforPlayersInRadius) == 0);
                        ["opQrf vehPlan task=%1 spawn=%2 tgt=%3 hunt=%4", _taskId, _sp, _to3, _huntOp] call FADE_qrfDbgLog;
                        private _centFO = missionNamespace getVariable ["FADE_qrfFriendlyCentroidATL", {}];
                        private _wpTgt = if (_huntOp && {!(_centFO isEqualTo {})}) then { [_to3] call _centFO } else { +_to3 };
                        if (count _wpTgt < 3) then { _wpTgt = [(_wpTgt select 0), (_wpTgt select 1), 0] };
                        private _dir = _sp getDir _wpTgt;
                        private _huntIvOp = (missionNamespace getVariable ["FADE_qrfHuntWaypointIntervalS", 60]) max 15;
                        private _fncMake = missionNamespace getVariable ["FADE_operationMakeVehFn_" + _taskId, {}];
                        private _qrfVehs = [];
                        for "_qv" from 0 to (_nVehs - 1) do {
                            if (_qv > 0) then { sleep 6 };
                            private _off = if (_qv == 0) then { +_sp } else {
                                private _prev = _qrfVehs select ((count _qrfVehs) - 1);
                                if (isNull _prev) then { +_sp } else {
                                    (getPosATL _prev) getPos [14, _dir + 180]
                                }
                            };
                            if (count _off < 3) then { _off = [(_off select 0), (_off select 1), 0] };
                            private _pack = [_off, _enemyUnits, _facApply, _qrfVehs, _wpTgt, _zoneRadius] call _fncMake;
                            _pack params ["_veh", "_vGrp", "_cGrp"];
                            if (!isNull _veh) then {
                                _qrfVehs pushBack _veh;
                                ["opQrf vehSpawned task=%1 idx=%2 veh=%3 class=%4", _taskId, _qv, _veh, typeOf _veh] call FADE_qrfDbgLog;
                                _veh setVariable ["FADE_opVehQrf", true, false];
                                _veh engineOn true;
                                private _wp1 = _vGrp addWaypoint [_wpTgt, 0];
                                _wp1 setWaypointType "MOVE";
                                _wp1 setWaypointCompletionRadius 20;
                                private _wp2 = _vGrp addWaypoint [_wpTgt, 0];
                                _wp2 setWaypointType "SAD";
                                private _ent = missionNamespace getVariable ["FADE_operationEntities_" + _taskId, []];
                                if (count _ent >= 6) then {
                                    private _vehs = _ent select 4;
                                    _vehs pushBack _veh;
                                    [_taskId, _veh] call FADE_missionEnt_registerVehicle;
                                    _ent set [4, _vehs];
                                    private _grps = _ent select 0;
                                    _grps pushBack _vGrp;
                                    if (!isNull _cGrp) then { _grps pushBack _cGrp };
                                    _ent set [0, _grps];
                                    missionNamespace setVariable ["FADE_operationEntities_" + _taskId, _ent];
                                };
                                if (_huntOp) then {
                                    [_vGrp, _veh, _taskId, _to3, _huntIvOp] spawn {
                                        params ["_vehGrp", "_veh", "_taskId", "_fall", "_iv"];
                                        private _cf = missionNamespace getVariable ["FADE_qrfFriendlyCentroidATL", {}];
                                        private _td = { (_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"] };
                                        while { alive _veh && {!isNull _veh} && {!isNull _vehGrp} && { !(call _td) } } do {
                                            sleep _iv;
                                            if (!alive _veh || { isNull _veh } || { isNull _vehGrp }) exitWith {};
                                            private _p = if (!(_cf isEqualTo {})) then { [_fall] call _cf } else { getPosATL _veh };
                                            if (count _p < 3) then { _p = [(_p select 0), (_p select 1), 0] };
                                            while { count waypoints _vehGrp > 0 } do { deleteWaypoint [_vehGrp, 0] };
                                            private _wM = _vehGrp addWaypoint [_p, 0];
                                            _wM setWaypointType "MOVE";
                                            _wM setWaypointCompletionRadius 20;
                                            private _wS = _vehGrp addWaypoint [_p, 0];
                                            _wS setWaypointType "SAD";
                                        };
                                    };
                                };
                                [_veh, _vGrp, _cGrp, _to3, _enemyUnits, _facApply, _huntOp, _taskId] spawn {
                                    params ["_veh", "_vehGrp", "_cargoGrp", "_to3", "_enemyUnits", "_facApply", "_huntOp", "_taskId"];
                                    private _poll = missionNamespace getVariable ["FADE_counterAttackPollInterval", 10];
                                    private _cf = missionNamespace getVariable ["FADE_qrfFriendlyCentroidATL", {}];
                                    waitUntil {
                                        sleep _poll;
                                        if (!alive _veh || { isNull _veh }) then {
                                            true
                                        } else {
                                            if (_huntOp) then {
                                                private _g = if (!(_cf isEqualTo {})) then { [_to3] call _cf } else { +_to3 };
                                                (_veh distance2D _g) < 130
                                            } else {
                                                (_veh distance2D _to3) < 130
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
                                        private _drop = if (_huntOp && {!(_cf isEqualTo {})}) then { [_to3] call _cf } else { +_to3 };
                                        if (count _drop < 3) then { _drop = [(_drop select 0), (_drop select 1), 0] };
                                        ["opQrf cargoUnload task=%1 veh=%2 units=%3 drop=%4", _taskId, _veh, count units _cargoGrp, _drop] call FADE_qrfDbgLog;
                                        private _wp = _cargoGrp addWaypoint [_drop, 0];
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

};

