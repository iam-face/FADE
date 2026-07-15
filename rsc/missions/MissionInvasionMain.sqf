// MissionInvasionMain.sqf - defensive invasion sustain loop
if (!isServer) exitWith {};
FADE_invasionMissionMain = {
if (isNil "FADE_invasionParams" || { count FADE_invasionParams < 6 }) exitWith {};

FADE_invasionParams params ["_player", ["_mapAnchor", []], "_taskId", "_basePos", "_enemyUnits", ["_invasionNameUpper", "INVASION"], ["_invasionName", "Invasion"]];

[] call FADE_invasion_applyOpforAir;

private _mkrJitter = missionNamespace getVariable ["FADE_jitterMarkerPos", { params [["_p", [0, 0, 0]]]; [_p] call FADE_normPos3 }];

_enemyUnits = [_enemyUnits] call FADE_resolveScenarioEnemyUnits;

private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
private _sideFriendly = missionNamespace getVariable ["FADE_sideFriendly", west];
private _markerFriendlyInv = missionNamespace getVariable ["FADE_markerColorFriendly", "ColorWEST"];
private _markerEnemyInv = missionNamespace getVariable ["FADE_markerColorEnemy", "ColorEAST"];

[] call FADE_ensureBisTaskSetParent;

if (count _enemyUnits == 0) exitWith {
    [] call FADE_invasion_restoreOpforAir;
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
    [] call FADE_invasion_restoreOpforAir;
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
    [] call FADE_invasion_restoreOpforAir;
    if (!isNull _player) then { [_player] call FADE_clearActiveMission };
    [_player, "MISSION ERROR", "No civ zones far enough from base."] call FADE_missionErrorHint;
};

private _wantN = missionNamespace getVariable ["FADE_operationZoneCount", 6];
_wantN = (round _wantN) max 2 min 10;

private _zoneEntries = [_civCandidates, _wantN, _mapAnchor] call FADE_invasion_pickZones;
if (count _zoneEntries < 2) exitWith {
    [] call FADE_invasion_restoreOpforAir;
    if (!isNull _player) then { [_player] call FADE_clearActiveMission };
    [_player, "MISSION ERROR", "Not enough civ zones to build an invasion route."] call FADE_missionErrorHint;
};

private _zoneCivIds = _zoneEntries apply { _x select 0 };
private _zones = _zoneEntries apply { _x select 1 };
// Clear ambient OPFOR (patrol / roadblock) in route towns — mission spawns OPFOR at beachhead only.
{
    if (!isNil "FADE_enemyPatrol_despawnForZone") then { [_x] call FADE_enemyPatrol_despawnForZone };
    if (!isNil "FADE_dynamicRoadblocks_despawnForZone") then { [_x] call FADE_dynamicRoadblocks_despawnForZone };
} forEach _zoneCivIds;
missionNamespace setVariable ["FADE_invasionCivZoneIds_" + _taskId, +_zoneCivIds];
if (!isNil "FADE_civ_pinZones") then { [_zoneCivIds] call FADE_civ_pinZones };

private _zoneRadius = 250;
private _invasionCenter = [_zones select 0] call FADE_normPos3;
private _zoneCodenames = [_taskId, (count _zones - 1) max 1] call FADE_raid_pickObjectiveCodenames;
private _allGroups = [];
[_taskId, _allGroups] call FADE_missionEnt_bindGroups;
private _markerNames = [];
private _pushVehicles = [];

private _facApply = missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}];
private _vgReg = missionNamespace getVariable ["FADE_vg_register", {}];
private _vgCancelEllipse = missionNamespace getVariable ["FADE_vg_cancelPendingInEllipse", {}];
private _vgCancelByOwner = missionNamespace getVariable ["FADE_vg_cancelPendingByOwner", {}];
private _invOwner = format ["invasion:%1", _taskId];

// --- Markers ---
{
    private _idx = _forEachIndex;
    private _center = [_x] call FADE_normPos3;
    private _isInvasionZone = (_idx == 0);
    private _markerColor = if (_isInvasionZone) then { _markerEnemyInv } else { _markerFriendlyInv };
    private _markerText = if (_isInvasionZone) then { "INVASION" } else { _zoneCodenames select (_idx - 1) };
    [_taskId, "FADE_inv", _idx, _center, _zoneRadius, _markerColor, _markerText, _mkrJitter, _markerNames] call FADE_zone_createCaptureMarkerPair;
} forEach _zones;

missionNamespace setVariable ["FADE_invasionZoneCenters_" + _taskId, _zones];
private _held = [];
{ _held pushBack (_forEachIndex != 0) } forEach _zones;
missionNamespace setVariable ["FADE_invasionHeldState_" + _taskId, +_held];
missionNamespace setVariable ["FADE_invasionEntities_" + _taskId, [_allGroups, _markerNames, _zones, _zoneRadius]];
missionNamespace setVariable ["FADE_invasionPushGroups_" + _taskId, []];
missionNamespace setVariable ["FADE_invasionPushVehicles_" + _taskId, _pushVehicles];
missionNamespace setVariable ["FADE_invasionAborted_" + _taskId, false];

private _enemyFactionNameInv = missionNamespace getVariable ["FADE_missionRun_enemyFactionName", ""];
private _zeroAlphaInv = missionNamespace getVariable ["FADE_missionRun_zeroAlphaDisplayName", "UNASSIGNED"];
private _situationInv = missionNamespace getVariable ["FADE_missionRun_defaultSituationHtml", ""];
private _refreshInvFn = missionNamespace getVariable ["FADE_missionRefreshBriefingAtPos", {}];
if (!(_refreshInvFn isEqualTo {}) && { count _invasionCenter >= 2 }) then {
    private _refInv = [
        "Invasion", _invasionCenter, _sideFriendly, _sideEnemy, _enemyFactionNameInv, _zeroAlphaInv, _invasionName
    ] call _refreshInvFn;
    if (count _refInv > 0) then {
        _situationInv = _refInv getOrDefault ["defaultSituationTaskText", _situationInv];
        private _loreSmeacInv = _refInv getOrDefault ["loreSmeacHtml", ""];
        if (_loreSmeacInv != "") then {
            missionNamespace setVariable ["FADE_missionRun_loreSmeacHtml", _loreSmeacInv];
        };
    };
};
private _defaultAdminInv = missionNamespace getVariable ["FADE_missionRun_defaultAdminTaskText", ""];
private _defaultCommandInv = missionNamespace getVariable ["FADE_missionRun_defaultCommandTaskText", ""];
private _taskBuilderInv = missionNamespace getVariable ["FADE_buildMissionTaskSmeacText", {}];
private _topoInv = [_invasionCenter] call (missionNamespace getVariable ["FADE_getTopographySummary", { ["UNKNOWN", "Unknown area"] }]);
private _missionTxtInv = format [
    "OPFOR has seized a beachhead at Grid %2 (%3) and is pushing through the nearest %1 marked zones. Hold the line, counter-attack lost sectors, and retake the INVASION beachhead to win.",
    count _zones,
    mapGridPosition _invasionCenter,
    (_topoInv param [1, "Unknown area"])
];
private _taskDescInv = if (_taskBuilderInv isEqualTo {} || { _situationInv isEqualTo "" }) then {
    _missionTxtInv
} else {
    [
        _missionTxtInv,
        _invasionCenter,
        _situationInv,
        "Defend marked zones; retake the INVASION beachhead to win.",
        _defaultAdminInv,
        _defaultCommandInv
    ] call _taskBuilderInv
};
[_sideFriendly, _taskId, [_taskDescInv, "Invasion", ""], _invasionCenter, "CREATED", 1, true, "defend", true] call BIS_fnc_taskCreate;
private _hqBoardFnInv = missionNamespace getVariable ["FADE_hqMainBoard_setObjectiveBrief", {}];
if (_hqBoardFnInv isEqualType {} && { !(_hqBoardFnInv isEqualTo {}) }) then { [_invasionCenter] call _hqBoardFnInv };

private _briefGuiTail = toString [10] + toString [10] + "See Tasks and map markers for grids, routes, and win/fail criteria.";
private _brief = format [
    "INVASION%1%1OPFOR has landed at the beachhead and is pushing zone by zone. Heliborne reinforcements continue while they hold it; vehicles join from captured sectors.%1%1Retake the INVASION beachhead to win. Lose if OPFOR holds every zone.",
    toString [10]
] + _briefGuiTail;
if (!isNull _player) then {
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    private _starterName = if (isNull _player) then { "Unknown" } else { name _player };
    private _loreShortInv = missionNamespace getVariable ["FADE_missionRun_loreShort", ""];
    if (_loreShortInv != "") then {
        [_invasionNameUpper, _starterName, _loreShortInv] remoteExec ["FADE_showMissionAssignedIntro", 0];
    } else {
        [_invasionNameUpper, _starterName] remoteExec ["FADE_showMissionAssignedIntro", 0];
    };
    [_player, "Invasion"] call FADE_notifyOthersMissionStarted;
};

// --- BLUFOR zone defenders (one-time spawn per friendly sector; no respawn) ---
private _friendlyUnits = [] call FADE_resolveScenarioFriendlyUnits;
private _bluDefSizeMin = missionNamespace getVariable ["FADE_invasionBluforDefSizeMin", 3];
private _bluDefSizeMax = missionNamespace getVariable ["FADE_invasionBluforDefSizeMax", 5];
private _assignCallsign = missionNamespace getVariable ["FADE_assignGroupCallsign", {}];
private _bluDefSpan = (_bluDefSizeMax - _bluDefSizeMin) max 0;

if (count _friendlyUnits > 0) then {
    for "_zi" from 1 to (count _zones - 1) do {
        private _zoneCenter = [_zones select _zi] call FADE_normPos3;
        private _angle0 = random 360;
        private _dist0 = 50 + random ((_zoneRadius - 50) max 0);
        private _sp = [(_zoneCenter select 0) + _dist0 * (cos _angle0), (_zoneCenter select 1) + _dist0 * (sin _angle0), 0];
        _sp = [[_sp, 0, 25, 3, 1, 0.4, 0, [], _sp], _zoneCenter] call FADE_findSafePosArray;
        private _squadSize = _bluDefSizeMin + floor random (_bluDefSpan + 1);
        private _shuf = _friendlyUnits call BIS_fnc_arrayShuffle;
        private _classes = _shuf select [0, _squadSize min count _shuf];
        if (count _classes == 0) then { _classes = [_friendlyUnits select 0] };
        private _grp = [_sp, _sideFriendly, _classes] call FADE_missionCreateInfantryGroupAt;
        if (!isNull _grp) then {
            if (!(_assignCallsign isEqualTo {})) then { [_grp] call _assignCallsign };
            [_grp] call FADE_attachNightStrobes;
            [_grp, _zoneCenter, 60, (_zoneRadius - 10) max 80, 4, _angle0, 90, "AWARE", "RED", "LIMITED", true] call FADE_missionApplyPatrolCycle;
            _allGroups pushBack _grp;
            [_taskId, _grp] call FADE_missionEnt_registerGroup;
        };
    };
};

// --- Beachhead garrison ---
private _numPatrol = 2;
for "_pg" from 0 to (_numPatrol - 1) do {
    private _angle0 = (_pg / _numPatrol) * 360 + random 45;
    private _dist0 = 50 + random ((_zoneRadius - 50) max 0);
    private _sp = [(_invasionCenter select 0) + _dist0 * (cos _angle0), (_invasionCenter select 1) + _dist0 * (sin _angle0), 0];
    _sp = [[_sp, 0, 25, 3, 1, 0.4, 0, [], _sp], _invasionCenter] call FADE_findSafePosArray;
    private _ps = [3 + floor random 3, 2] call _scaleOpforCount;
    private _shuf = _enemyUnits call BIS_fnc_arrayShuffle;
    private _classes = _shuf select [0, _ps min count _shuf];
    if (count _classes == 0) then { _classes = [_enemyUnits select 0] };
    private _grp = [_sp, _sideEnemy, _classes] call FADE_missionCreateInfantryGroupAt;
    if (!isNull _grp) then {
        if (!(_facApply isEqualTo {})) then { [_grp] call _facApply };
        [_grp, _invasionCenter, 60, (_zoneRadius - 10) max 80, 4, _angle0, 90, "AWARE", "RED", "LIMITED", true] call FADE_missionApplyPatrolCycle;
        _allGroups pushBack _grp;
        [_taskId, _grp] call FADE_missionEnt_registerGroup;
    };
};

private _blds = nearestObjects [_invasionCenter, ["House", "Building"], _zoneRadius * 0.9];
_blds = (_blds select { count (_x buildingPos -1) >= 2 }) call BIS_fnc_arrayShuffle;
private _maxB = 2 min count _blds;
for "_b" from 0 to (_maxB - 1) do {
    private _building = _blds select _b;
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
    if (count _slotATL > 0 && { !(_vgReg isEqualTo {}) }) then {
        private _st = createHashMap;
        _st set ["owner", _invOwner];
        _st set ["groupsRef", _allGroups];
        _st set ["facApply", !(_facApply isEqualTo {})];
        [_building, _slotATL, [], _st] call _vgReg;
    } else {
        if (count _slotATL > 0) then {
            private _grpG = createGroup _sideEnemy;
            {
                private _pos = +_x;
                private _u = _grpG createUnit [selectRandom _enemyUnits, _pos, [], 0, "NONE"];
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
                _allGroups pushBack _grpG;
                [_taskId, _grpG] call FADE_missionEnt_registerGroup;
            } else {
                deleteGroup _grpG;
            };
        };
    };
};

// --- Beachhead static defense (turrets + hold vehicle) ---
[_taskId, _invasionCenter, _zoneRadius, _basePos, _enemyUnits, _sideEnemy, _facApply] call FADE_invasion_spawnBeachheadTurrets;
[_taskId, _invasionCenter, _zoneRadius, _basePos, _enemyUnits, _facApply] call FADE_invasion_spawnBeachheadVehicle;

missionNamespace setVariable ["FADE_invasionEntities_" + _taskId, [_allGroups, _markerNames, _zones, _zoneRadius]];

// --- Opening ground push (already landed) ---
private _initSqMin = missionNamespace getVariable ["FADE_invasionInitialSquadsMin", 2];
private _initSqMax = missionNamespace getVariable ["FADE_invasionInitialSquadsMax", 3];
private _initSpan = (_initSqMax - _initSqMin) max 0;
private _initSquads = _initSqMin + floor random (_initSpan + 1);
private _initPushIdx = [+_held, _zones, _invasionCenter] call FADE_invasion_getPushTargetIdx;
if (_initPushIdx >= 0) then {
    private _initTarget = [_zones select _initPushIdx] call FADE_normPos3;
    for "_is" from 0 to (_initSquads - 1) do {
        private _sp = [_invasionCenter, _zoneRadius] call FADE_invasion_findSpawnPos;
        [_taskId, _sp, _initTarget, _enemyUnits, _facApply, _sideEnemy, _scaleOpforCount, _zoneRadius] call FADE_invasion_spawnGroundSquad;
    };
};

private _reinforceMin = missionNamespace getVariable ["FADE_invasionReinforceMin", 180];
private _reinforceMax = missionNamespace getVariable ["FADE_invasionReinforceMax", 300];
private _reinforceSpan = (_reinforceMax - _reinforceMin) max 0;
private _sustainCheck = missionNamespace getVariable ["FADE_invasionSustainCheckSec", 30];
private _sqMin = missionNamespace getVariable ["FADE_invasionSustainSquadsMin", 1];
private _sqMax = missionNamespace getVariable ["FADE_invasionSustainSquadsMax", 3];
private _sqSpan = (_sqMax - _sqMin) max 0;
private _vehMax = missionNamespace getVariable ["FADE_invasionWaveVehiclesMax", 2];
private _heliApproach = missionNamespace getVariable ["FADE_invasionHeliApproachDist", 2200];
private _groundMaxPerTick = missionNamespace getVariable ["FADE_invasionGroundReinforceMaxPerTick", 2];
private _wipedFrontMin = missionNamespace getVariable ["FADE_invasionWipedFrontSquadsMin", 2];
private _heliFirstDelay = missionNamespace getVariable ["FADE_invasionHeliFirstDelaySec", 75];
private _helisPerWaveMax = missionNamespace getVariable ["FADE_invasionHelisPerWaveMax", 2];
private _surgeHeliCd = missionNamespace getVariable ["FADE_invasionFrontSurgeHeliCooldown", 90];
private _vehReinforceMin = missionNamespace getVariable ["FADE_invasionVehicleReinforceMin", 90];

[_taskId, _zones, _zoneRadius, _invasionCenter, _enemyUnits, _facApply, _sideEnemy, _scaleOpforCount, _reinforceMin, _reinforceMax, _reinforceSpan, _sustainCheck, _sqMin, _sqSpan, _vehMax, _heliApproach, _groundMaxPerTick, _wipedFrontMin, _heliFirstDelay, _helisPerWaveMax, _surgeHeliCd, _vehReinforceMin] spawn {
    params ["_taskId", "_zones", "_zoneRadius", "_invasionCenter", "_enemyUnits", "_facApply", "_sideEnemy", "_scaleOpforCount", "_reinforceMin", "_reinforceMax", "_reinforceSpan", "_sustainCheck", "_sqMin", "_sqSpan", "_vehMax", "_heliApproach", "_groundMaxPerTick", "_wipedFrontMin", "_heliFirstDelay", "_helisPerWaveMax", "_surgeHeliCd", "_vehReinforceMin"];
    scriptName "FADE_inv_sustain";

    private _lastHeliTime = time - _heliFirstDelay;
    private _lastSurgeHeliTime = -1e9;
    private _lastVehTime = -1e9;
    private _targetSquads = _sqMin + floor random (_sqSpan + 1);

    private _fnc_missionActive = {
        !(missionNamespace getVariable ["FADE_invasionAborted_" + _taskId, false])
        && { !((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]) }
    };

    private _aliveEnemyFn = missionNamespace getVariable ["FADE_invasion_countAliveEnemyInRadius", {}];
    private _fnc_aliveEnemyAt = {
        params ["_center", "_radius"];
        if (_aliveEnemyFn isEqualTo {}) then {
            [_center, _radius] call FADE_op_countEnemyMenSpawnedInRadius
        } else {
            [_center, _radius] call _aliveEnemyFn
        };
    };

    private _fnc_prunePushGroups = {
        private _arr = missionNamespace getVariable ["FADE_invasionPushGroups_" + _taskId, []];
        _arr = _arr select { !isNull _x && { ({ alive _x } count units _x) > 0 } };
        missionNamespace setVariable ["FADE_invasionPushGroups_" + _taskId, _arr];
        count _arr
    };

    private _fnc_alivePushVehs = {
        private _arr = missionNamespace getVariable ["FADE_invasionPushVehicles_" + _taskId, []];
        _arr = _arr select { !isNull _x && { alive _x } && { canMove _x } };
        missionNamespace setVariable ["FADE_invasionPushVehicles_" + _taskId, _arr];
        count _arr
    };

    private _fnc_heliInsertSquad = {
        params ["_dropPos", "_targetCenter"];
        private _heliClass = call FADE_invasion_pickTransportHeliClass;
        if (_heliClass == "") exitWith { false };

        private _drop2 = [_dropPos select 0, _dropPos select 1];
        private _approachDir = random 360;
        private _spawn2 = [
            (_drop2 select 0) + _heliApproach * (sin _approachDir),
            (_drop2 select 1) + _heliApproach * (cos _approachDir)
        ];
        private _mapMinA = missionNamespace getVariable ["FADE_mapMin", 0];
        private _mapMaxA = missionNamespace getVariable ["FADE_mapMax", worldSize];
        private _pad = 200;
        _spawn2 set [0, (_spawn2 select 0) max (_mapMinA + _pad) min (_mapMaxA - _pad)];
        _spawn2 set [1, (_spawn2 select 1) max (_mapMinA + _pad) min (_mapMaxA - _pad)];
        private _alt = (getTerrainHeightASL [_spawn2 select 0, _spawn2 select 1]) + 120 + random 80;
        private _spawnPos = [_spawn2 select 0, _spawn2 select 1, _alt];

        private _veh = createVehicle [_heliClass, _spawnPos, [], 0, "FLY"];
        if (isNull _veh) exitWith { false };
        private _face = ((_drop2 select 1) - (_spawn2 select 1)) atan2 ((_drop2 select 0) - (_spawn2 select 0));
        _veh setDir _face;
        { if (!isNull _x) then { deleteVehicle _x } } forEach crew _veh;

        private _heliGrp = createGroup _sideEnemy;
        private _driver = _heliGrp createUnit [selectRandom _enemyUnits, _spawnPos, [], 0, "NONE"];
        if (isNull _driver) exitWith { deleteVehicle _veh; deleteGroup _heliGrp; false };
        _driver moveInDriver _veh;
        _heliGrp selectLeader _driver;
        if (!(_facApply isEqualTo {})) then { [_heliGrp] call _facApply };

        private _infGrp = createGroup _sideEnemy;
        private _cargoCap = (_veh emptyPositions "cargo") max 0;
        private _fill = [4 + floor random 3, 2] call _scaleOpforCount;
        _fill = _fill min (_cargoCap max 1);
        for "_k" from 0 to (_fill - 1) do {
            private _u = _infGrp createUnit [selectRandom _enemyUnits, _spawnPos, [], 0, "NONE"];
            if (!isNull _u) then {
                _u assignAsCargo _veh;
                _u moveInCargo _veh;
                _u disableAI "PATH";
                _u disableAI "MOVE";
            };
        };
        if (count units _infGrp == 0) exitWith {
            { deleteVehicle _x } forEach units _heliGrp;
            deleteGroup _heliGrp;
            deleteGroup _infGrp;
            deleteVehicle _veh;
            false
        };
        if (!(_facApply isEqualTo {})) then { [_infGrp] call _facApply };
        (units _infGrp) orderGetIn false;
        _veh flyInHeight (60 + random 40);

        private _lz = +_dropPos;
        if (count _lz < 3) then { _lz set [2, 0] };
        private _wpLand = _heliGrp addWaypoint [_lz, 0];
        _wpLand setWaypointType "LAND";
        _wpLand setWaypointSpeed "LIMITED";
        _wpLand setWaypointBehaviour "CARELESS";

        [_veh, _heliGrp, _infGrp, _lz, _targetCenter, _taskId, _zoneRadius, _heliApproach] spawn {
            params ["_veh", "_heliGrp", "_infGrp", "_lz", "_targetCenter", "_taskId", "_zoneRadius", "_heliApproach"];
            scriptName "FADE_inv_heliInsert";
            private _timeout = time + 420;
            private _fnc_disembarkCargo = {
                params ["_forcePos"];
                {
                    if (!isNull _x && { alive _x }) then {
                        if (vehicle _x != _x) then {
                            private _v = vehicle _x;
                            _x enableAI "PATH";
                            _x enableAI "MOVE";
                            unassignVehicle _x;
                            _x setUnitPos "AUTO";
                            _x moveOut _v;
                            if (vehicle _x == _v) then {
                                private _exitPos = _v modelToWorld [2 + random 2, (random 4) - 2, 0];
                                _x setPosATL _exitPos;
                            };
                        } else {
                            if (_forcePos && { count _lz >= 2 }) then { _x setPosATL _lz };
                        };
                    };
                    sleep 0.35;
                } forEach units _infGrp;
            };
            waitUntil {
                sleep 1;
                isNull _veh || { !alive _veh }
                || { isTouchingGround _veh && { (_veh distance2D _lz) < 100 } }
                || { time > _timeout }
            };
            if (isNull _veh || { !alive _veh }) exitWith {
                [true] call _fnc_disembarkCargo;
                if ({ alive _x } count units _infGrp > 0) then {
                    [_infGrp, _targetCenter, _zoneRadius] call FADE_invasion_assignPushWp;
                    private _pg = missionNamespace getVariable ["FADE_invasionPushGroups_" + _taskId, []];
                    _pg pushBack _infGrp;
                    missionNamespace setVariable ["FADE_invasionPushGroups_" + _taskId, _pg];
                    [_taskId, _infGrp] call FADE_missionEnt_registerGroup;
                } else {
                    deleteGroup _infGrp;
                };
            };
            if !(isTouchingGround _veh) then {
                while { count waypoints _heliGrp > 0 } do { deleteWaypoint [_heliGrp, 0] };
                _veh land "LAND";
                private _landTimeout = time + 90;
                waitUntil {
                    sleep 1;
                    isNull _veh || { !alive _veh } || { isTouchingGround _veh } || { time > _landTimeout }
                };
            };
            sleep 2;
            [false] call _fnc_disembarkCargo;
            sleep 1;
            if ({ alive _x } count units _infGrp > 0) then {
                [_infGrp, _targetCenter, _zoneRadius] call FADE_invasion_assignPushWp;
                private _pg = missionNamespace getVariable ["FADE_invasionPushGroups_" + _taskId, []];
                _pg pushBack _infGrp;
                missionNamespace setVariable ["FADE_invasionPushGroups_" + _taskId, _pg];
                [_taskId, _infGrp] call FADE_missionEnt_registerGroup;
            } else {
                deleteGroup _infGrp;
            };
            if (!isNull _veh && { alive _veh }) then {
                [_veh, _heliGrp, _lz, _heliApproach] call FADE_invasion_heliDepartDespawn;
            };
        };
        true
    };

    while { call _fnc_missionActive } do {
        sleep _sustainCheck;
        if !(call _fnc_missionActive) exitWith {};

        private _held = missionNamespace getVariable ["FADE_invasionHeldState_" + _taskId, []];
        if (count _held != count _zones) then {
            // #region agent log
            diag_log format [
                "[FAC DbgBrowser 62d308] H24 invasionSustain heldMismatch task=%1 held=%2 zones=%3",
                _taskId, count _held, count _zones
            ];
            // #endregion
        } else {
        if (_held select 0) exitWith {
            // #region agent log
            diag_log format ["[FAC DbgBrowser 62d308] H24 invasionSustain stop beachheadLost task=%1", _taskId];
            // #endregion
        };

        private _bhPlayers = [_invasionCenter, _zoneRadius] call FADE_op_countBluforPlayersInRadius;
        private _bhAliveE = [_invasionCenter, _zoneRadius] call _fnc_aliveEnemyAt;
        if (_bhPlayers > 0 && { _bhAliveE == 0 }) then {
            // #region agent log
            diag_log format [
                "[FAC DbgBrowser 62d308] H25 invasionSustain paused beachheadSecure task=%1 players=%2",
                _taskId, _bhPlayers
            ];
            // #endregion
        } else {

        private _pushIdx = [+_held, _zones, _invasionCenter] call FADE_invasion_getPushTargetIdx;
        if (_pushIdx < 0) then {
            // #region agent log
            diag_log format ["[FAC DbgBrowser 62d308] H24 invasionSustain noPushTarget task=%1 held=%2", _taskId, _held];
            // #endregion
        } else {

        private _targetCenter = [_zones select _pushIdx] call FADE_normPos3;
        private _aliveSquads = call _fnc_prunePushGroups;

        // Re-point surviving push squads at the current nearest target.
        {
            [_x, _targetCenter, _zoneRadius] call FADE_invasion_assignPushWp;
        } forEach (missionNamespace getVariable ["FADE_invasionPushGroups_" + _taskId, []]);

        private _eCnt = [_targetCenter, _zoneRadius] call _fnc_aliveEnemyAt;
        private _bluCnt = [_targetCenter, _zoneRadius] call FADE_op_countBluforInRadius;
        private _frontHot = (_bluCnt > 0) && { (_eCnt == 0 || { _aliveSquads < 2 }) };

        // AO-style beachhead ground releases: top up toward target squad count each poll.
        private _deficit = (_targetSquads - _aliveSquads) max 0;
        private _groundSpawn = _deficit min _groundMaxPerTick;
        if (_frontHot && { _aliveSquads == 0 }) then {
            _groundSpawn = (_groundSpawn max _wipedFrontMin) min (_groundMaxPerTick + 1);
        };
        private _groundSpawned = 0;
        for "_gs" from 1 to _groundSpawn do {
            private _sp = [_invasionCenter, _zoneRadius] call FADE_invasion_findSpawnPos;
            private _g = [_taskId, _sp, _targetCenter, _enemyUnits, _facApply, _sideEnemy, _scaleOpforCount, _zoneRadius] call FADE_invasion_spawnGroundSquad;
            if (!isNull _g) then { _groundSpawned = _groundSpawned + 1 };
        };
        _aliveSquads = call _fnc_prunePushGroups;

        private _heliDue = (time - _lastHeliTime) >= (_reinforceMin + random _reinforceSpan);
        private _surgeHeli = _frontHot && { _aliveSquads <= 1 } && { (time - _lastSurgeHeliTime) >= _surgeHeliCd };
        private _helisSpawned = 0;
        if (_heliDue || _surgeHeli) then {
            if (_aliveSquads < _targetSquads || _surgeHeli) then {
                private _helisWant = 1;
                if (_deficit >= 3) then { _helisWant = _helisPerWaveMax };
                private _lz = [_invasionCenter, 80] call FADE_findSafeLZ;
                if (count _lz < 2) then { _lz = [_invasionCenter, _zoneRadius] call FADE_invasion_findSpawnPos };
                for "_hi" from 1 to _helisWant do {
                    if ([_lz, _targetCenter] call _fnc_heliInsertSquad) then {
                        _helisSpawned = _helisSpawned + 1;
                    } else {
                        private _spG = [_invasionCenter, _zoneRadius] call FADE_invasion_findSpawnPos;
                        if (!isNull ([_taskId, _spG, _targetCenter, _enemyUnits, _facApply, _sideEnemy, _scaleOpforCount, _zoneRadius] call FADE_invasion_spawnGroundSquad)) then {
                            _groundSpawned = _groundSpawned + 1;
                        };
                    };
                    sleep 2;
                };
            };

            _lastHeliTime = time;
            if (_surgeHeli) then { _lastSurgeHeliTime = time };
            _targetSquads = _sqMin + floor random (_sqSpan + 1);
        };

        private _capturedIdx = [];
        for "_zi" from 1 to (count _zones - 1) do {
            if !(_held select _zi) then { _capturedIdx pushBack _zi };
        };
        private _vehSpawned = false;
        if (
            count _capturedIdx > 0
            && { (time - _lastVehTime) >= _vehReinforceMin }
            && { call _fnc_alivePushVehs < _vehMax }
        ) then {
            private _spawnZoneIdx = ([_capturedIdx, [], { (_zones select _x) distance2D _targetCenter }, "ASCEND"] call BIS_fnc_sortBy) select 0;
            private _spawnZone = [_zones select _spawnZoneIdx] call FADE_normPos3;
            private _vehSp = [_spawnZone, _zoneRadius] call FADE_invasion_findSpawnPos;
            private _existing = missionNamespace getVariable ["FADE_invasionPushVehicles_" + _taskId, []];
            private _pack = [_vehSp, _targetCenter, _enemyUnits, _facApply, _existing, _zoneRadius] call FADE_invasion_makePushVeh;
            _pack params [["_veh", objNull], ["_vGrp", grpNull], ["_cGrp", grpNull]];
            if (!isNull _veh) then {
                _vehSpawned = true;
                _lastVehTime = time;
                _existing pushBack _veh;
                missionNamespace setVariable ["FADE_invasionPushVehicles_" + _taskId, _existing];
                [_taskId, _veh] call FADE_missionEnt_registerVehicle;
                if (!isNull _vGrp) then { [_taskId, _vGrp] call FADE_missionEnt_registerGroup };
                if (!isNull _cGrp) then { [_taskId, _cGrp] call FADE_missionEnt_registerGroup };
            };
        };

        // #region agent log
        diag_log format [
            "[FAC DbgBrowser 62d308] H24 invasionSustain tick task=%1 pushIdx=%2 target=%3 squads=%4/%5 ground=%6 heliDue=%7 helis=%8 surge=%9 veh=%10 captured=%11 blu=%12 enemy=%13 frontHot=%14",
            _taskId, _pushIdx, _targetCenter, _aliveSquads, _targetSquads, _groundSpawned, _heliDue, _helisSpawned, _surgeHeli, _vehSpawned, count _capturedIdx, _bluCnt, _eCnt, _frontHot
        ];
        // #endregion

        }; // pushIdx >= 0
        }; // beachhead not player-secured
        }; // held count match
    };

};

// --- Main poll loop (5s): capture state, markers, win/lose ---
[_player, _taskId, _zones, _zoneRadius, _markerFriendlyInv, _markerEnemyInv, _invOwner, _vgCancelEllipse, _vgCancelByOwner] spawn {
    params ["_player", "_taskId", "_zones", "_zoneRadius", "_markerFriendlyInv", "_markerEnemyInv", "_invOwner", "_vgCancelEllipse", "_vgCancelByOwner"];
    scriptName "FADE_inv_main";
    private _zoneCivIds = missionNamespace getVariable ["FADE_invasionCivZoneIds_" + _taskId, []];
    private _townNameFn = missionNamespace getVariable ["FADE_civZoneGetDisplayName", {}];
    private _aliveEnemyFn = missionNamespace getVariable ["FADE_invasion_countAliveEnemyInRadius", {}];
    private _held = [];
    { _held pushBack (_forEachIndex != 0) } forEach _zones;
    private _markerNames = (missionNamespace getVariable ["FADE_invasionEntities_" + _taskId, [[], []]]) select 1;

    waitUntil {
        sleep 5;
        if (missionNamespace getVariable ["FADE_invasionAborted_" + _taskId, false]) exitWith { true };
        if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]) exitWith { true };

        private _bhCenter = [_zones select 0] call FADE_normPos3;
        private _bhPlayers = [_bhCenter, _zoneRadius] call FADE_op_countBluforPlayersInRadius;
        private _bhAliveE = if (_aliveEnemyFn isEqualTo {}) then {
            [_bhCenter, _zoneRadius] call FADE_op_countEnemyMenSpawnedInRadius
        } else {
            [_bhCenter, _zoneRadius] call _aliveEnemyFn
        };
        if (_bhPlayers > 0 && { _bhAliveE == 0 }) exitWith {
            if (!(_vgCancelByOwner isEqualTo {})) then { [_invOwner] call _vgCancelByOwner };
            if (!(_vgCancelEllipse isEqualTo {})) then { [_bhCenter, _zoneRadius, _invOwner] call _vgCancelEllipse };
            missionNamespace setVariable ["FADE_invasionAborted_" + _taskId, true];
            _held set [0, true];
            missionNamespace setVariable ["FADE_invasionHeldState_" + _taskId, +_held];
            // #region agent log
            diag_log format [
                "[FAC DbgBrowser 62d308] H25 invasionBeachheadWin task=%1 players=%2 aliveEnemy=%3",
                _taskId, _bhPlayers, _bhAliveE
            ];
            // #endregion
            [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
            [_player, "The beachhead has been retaken. Invasion broken."] call FADE_missionSuccessHint;
            true
        };

        {
            private _center = _x;
            private _i = _forEachIndex;
            private _wasHeld = _held select _i;
            private _bluforCnt = [_center, _zoneRadius] call FADE_op_countBluforInRadius;
            private _eCnt = if (_aliveEnemyFn isEqualTo {}) then {
                [_center, _zoneRadius] call FADE_op_countEnemyMenSpawnedInRadius
            } else {
                [_center, _zoneRadius] call _aliveEnemyFn
            };
            private _mArea = _markerNames select (_i * 2);
            private _mIcon = _markerNames select (_i * 2 + 1);
            private _nowHeld = [
                _center, _zoneRadius, _wasHeld, _bluforCnt, _eCnt,
                _mArea, _mIcon, _markerFriendlyInv, _markerEnemyInv,
                _vgCancelEllipse, _invOwner
            ] call FADE_zone_tickInvasionHold;
            if (_i > 0 && { _wasHeld } && { !_nowHeld }) then {
                private _civId = _zoneCivIds param [_i, ""];
                private _townName = if (!(_townNameFn isEqualTo {})) then {
                    [_civId, _center] call _townNameFn
                } else {
                    "Unknown area"
                };
                private _msg = format ["ZERO ALPHA: OPFOR HAS CAPTURED %1", _townName];
                [_msg] remoteExec ["systemChat", 0];
                // #region agent log
                diag_log format [
                    "[FAC DbgBrowser 62d308] H23 invasionOpforCapture zone=%1 town=%2 civId=%3 blu=%4 enemy=%5",
                    _i, _townName, _civId, _bluforCnt, _eCnt
                ];
                // #endregion
            };
            _held set [_i, _nowHeld];
        } forEach _zones;
        missionNamespace setVariable ["FADE_invasionHeldState_" + _taskId, +_held];

        // Win: BLUFOR recaptured the invasion beachhead.
        if (_held select 0) exitWith {
            [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
            [_player, "The beachhead has been retaken. Invasion broken."] call FADE_missionSuccessHint;
            true
        };

        // Lose: OPFOR holds every zone.
        if (({ _x } count _held) == 0) exitWith {
            [_taskId, "FAILED"] call BIS_fnc_taskSetState;
            [_player, "OPFOR has overrun every zone."] call FADE_missionFailHint;
            true
        };

        false
    };

    missionNamespace setVariable ["FADE_invasionAborted_" + _taskId, true];
    [] call FADE_invasion_restoreOpforAir;
    if (!(_vgCancelByOwner isEqualTo {})) then { [_invOwner] call _vgCancelByOwner };
    private _zoneCivIdsEnd = missionNamespace getVariable ["FADE_invasionCivZoneIds_" + _taskId, []];
    if (!isNil "FADE_civ_unpinZones" && { _zoneCivIdsEnd isNotEqualTo [] }) then { [_zoneCivIdsEnd] call FADE_civ_unpinZones };
    missionNamespace setVariable ["FADE_invasionCivZoneIds_" + _taskId, nil];
    sleep 1;
    if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
    [_taskId, "", _player, 60] call FADE_mission_completeCleanup;
};

};

