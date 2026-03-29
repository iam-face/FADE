// =============================================================================
// AOMission.sqf - Area of Operations: 2 km x 2 km square zone, 3 capture points,
// BLUFOR vs OPFOR. AO center from CIV zone >= 2500m from base (never overlap base).
// Runs on server. Params from FADE_aoParams: [_player, _destPos, _taskId, _basePos, _friendlyUnits, _enemyUnits]
// =============================================================================
if (!isServer) exitWith {};
if (isNil "FADE_aoParams" || { count FADE_aoParams < 6 }) exitWith {};

FADE_aoParams params ["_player", "_destPos", "_taskId", "_basePos", "_friendlyUnits", "_enemyUnits"];

// Always use current scenario faction (config GUI); refetch so BLUFOR/OPFOR match chosen factions
private _friendlyUnits = missionNamespace getVariable ["FADE_friendlyUnits", _friendlyUnits];
private _enemyUnits = missionNamespace getVariable ["FADE_enemyUnits", _enemyUnits];
if (_friendlyUnits isEqualTo []) then {
    private _ff = missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"];
    _friendlyUnits = [_ff, 1] call (missionNamespace getVariable ["FADE_getUnitsForFaction", { [] }]);
    if (_friendlyUnits isEqualTo []) then { _friendlyUnits = ["B_Soldier_TL_F", "B_Soldier_F", "B_Soldier_AR_F", "B_medic_F"] };
};
if (_enemyUnits isEqualTo []) then {
    private _ef = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
    _enemyUnits = [_ef, 0] call (missionNamespace getVariable ["FADE_getUnitsForFaction", { [] }]);
    if (_enemyUnits isEqualTo []) then { _enemyUnits = ["O_Soldier_TL_F", "O_Soldier_F", "O_Soldier_AR_F"] };
};
_enemyUnits = [_enemyUnits] call (missionNamespace getVariable ["FADE_filterEnemyUnitsArmed", { _this select 0 }]);

if (!(_destPos isEqualType []) || { count _destPos < 2 }) then { _destPos = [0, 0, 0] };
_destPos = [(_destPos param [0, 0]), (_destPos param [1, 0]), (_destPos param [2, 0])];
if (!(_basePos isEqualType []) || { count _basePos < 2 }) then {
    private _baseObj = missionNamespace getVariable ["BASE_1", objNull];
    _basePos = if (!isNull _baseObj) then { getPosATL _baseObj } else { [0, 0, 0] };
    if (!(_basePos isEqualType []) || { count _basePos < 2 }) then { _basePos = [0, 0, 0] };
};
_basePos = [(_basePos param [0, 0]), (_basePos param [1, 0]), (_basePos param [2, 0])];

private _minDistFromBase = 2500;  // AO must never overlap or touch player base

// AO center: only use CIV zones at least _minDistFromBase from base; else position from params or findMissionPos(2500)
private _civZones = missionNamespace getVariable ["FADE_civTriggerNames", []];
private _farCivZones = _civZones select {
    private _trig = missionNamespace getVariable [_x, objNull];
    if (isNull _trig) then { false } else {
        private _p = getPosATL _trig;
        if (count _p < 2) then { false } else { (_p distance _basePos) >= _minDistFromBase }
    };
};
if (count _farCivZones > 0) then {
    private _zoneName = selectRandom _farCivZones;
    private _trig = missionNamespace getVariable [_zoneName, objNull];
    if (!isNull _trig) then {
        private _p = getPosATL _trig;
        if (_p isEqualType [] && { count _p >= 2 }) then { _destPos = [(_p param [0, 0]), (_p param [1, 0]), (_p param [2, 0])] };
    };
};
if ((_destPos distance _basePos) < _minDistFromBase) then {
    private _fallback = [_minDistFromBase] call FADE_findMissionPos;
    if (_fallback isEqualType [] && { count _fallback >= 2 }) then { _destPos = _fallback; if (count _destPos < 3) then { _destPos set [2, 0] } };
};
if ((_destPos distance _basePos) < _minDistFromBase) exitWith {
    [_player, _taskId] call FADE_clearActiveMission;
    [format ["<t size='1.2' color='#FF6666'>AO ERROR</t><br/><br/><t color='#E0E0E0'>No area of operations found at least %1 m from base. Try again.</t>", _minDistFromBase]] remoteExec ["FADE_showMissionHint", _player];
};

// 2 km x 2 km square AO; BLUFOR spawn on one edge, assault along depth axis
private _zoneHalfWidth = 1000;   // half-size each axis = 2 km x 2 km square
private _zoneHalfDepth = 1000;
private _captureRadius = 50;
private _attackDir = (floor random 4) * 90;  // Random cardinal: 0=E, 90=S, 180=W, 270=N - BLUFOR spawn on this edge, attack toward opposite

// Task: starter only, ASSIGNED (same pattern as Missions.sqf _fnc_createMissionTask - P4)
if (!isNull _player) then {
    [_player, _taskId, ["Capture all 3 objective points (OBJ 1 → 2 → 3 in order).", "AO: Capture objectives", ""], _destPos, "ASSIGNED", 1, true, "attack", true] call BIS_fnc_taskCreate;
} else {
    [west, _taskId, ["Capture all 3 objective points (OBJ 1 → 2 → 3 in order).", "AO: Capture objectives", ""], _destPos, "CREATED", 1, false, "attack", true] call BIS_fnc_taskCreate;
};

// Zone marker: 2 km x 2 km square; BLUFOR spawn 100 m outside edge in _attackDir. Thick black border (outer band + inner border).
private _borderThick = 40;  // metres extra each side for border thickness
private _zoneOuterName = "FADE_ao_zone_outer_" + _taskId;
private _zoneOuter = createMarker [_zoneOuterName, _destPos];
_zoneOuter setMarkerShape "RECTANGLE";
_zoneOuter setMarkerSize [_zoneHalfDepth + _borderThick, _zoneHalfWidth + _borderThick];
_zoneOuter setMarkerDir _attackDir;
_zoneOuter setMarkerBrush "Solid";
_zoneOuter setMarkerColor "ColorBlack";
_zoneOuter setMarkerAlpha 0.9;
private _zoneName = "FADE_ao_zone_" + _taskId;
private _zone = createMarker [_zoneName, _destPos];
_zone setMarkerShape "RECTANGLE";
_zone setMarkerSize [_zoneHalfDepth, _zoneHalfWidth];
_zone setMarkerDir _attackDir;
_zone setMarkerBrush "Border";
_zone setMarkerColor "ColorBlack";
_zone setMarkerAlpha 0.95;
_player setVariable ["FADE_myMissionMarker", _zoneName, true];
_player setVariable ["FADE_myMissionMarkerEnd", "", true];

// Three objectives spread inside the square: OBJ 1 closest to BLUFOR (500 m in), OBJ 2 center, OBJ 3 toward OPFOR edge.
// BLUFOR spawn 100 m outside edge so they do not sit on OBJ 1; assault order OBJ 1 -> OBJ 2 -> OBJ 3.
private _points = [];
private _objSpecs = [
    [500, _attackDir],                      // OBJ 1: 500 m from center toward BLUFOR edge (first to capture)
    [0, _attackDir],                        // OBJ 2: center
    [500, _attackDir + 180]                 // OBJ 3: 500 m from center toward OPFOR edge
];
{
    _x params ["_dist", "_dir"];
    private _latOffset = if (_forEachIndex == 1) then { (random 101) - 50 } else { (random 1000) - 500 };  // OBJ2 (urban) 50 m radius of civ center; OBJ1/3 ±500 m
    private _pos = if (_dist <= 0) then {
        [_destPos, _latOffset, _attackDir + 90] call BIS_fnc_relPos
    } else {
        private _p = [_destPos, _dist, _dir] call BIS_fnc_relPos;
        [_p, _latOffset, _dir + 90] call BIS_fnc_relPos
    };
    if (_pos isEqualType [] && { count _pos < 3 }) then { _pos set [2, 0] };
    private _safe = [_pos, 0, 25, 5, 0, 0.4, 0, [], _pos] call BIS_fnc_findSafePos;
    if (_safe isEqualType [] && { count _safe >= 2 }) then { _pos = _safe; if (count _pos < 3) then { _pos set [2, 0] } };
    _points pushBack _pos;
} forEach _objSpecs;

// Composition at OBJ 1 and OBJ 3 only (Cargo-style: [classname, dist, angle, dirOffset]). OBJ 2 is urban - no composition.
private _aoCompositionObjects = [];
private _objComposition = [
    ["Land_TentA_F", 8, 0, 0],
    ["Land_TentDome_F", 10, 180, 0],
    ["Land_CampingTable_F", 5, 90, 0],
    ["Land_CampingChair_V2_F", 6, 120, 0],
    ["Land_CampingChair_V2_F", 6, 60, 0],
    ["Campfire_burning_F", 4, 270, 0],
    ["Box_NATO_Ammo_F", 12, 45, 0],
    ["Box_NATO_Support_F", 12, 315, 0]
];
{
    private _pos = _x;
    private _objIdx = _forEachIndex;
    if (_objIdx != 1) then {
        private _dir = random 360;
        {
            _x params ["_class", "_dist", "_angle", "_dirObj"];
            if (isClass (configFile >> "CfgVehicles" >> _class)) then {
                private _ang = _angle + _dir;
                private _relPos = [(_pos select 0) + _dist * (cos (_ang)), (_pos select 1) + _dist * (sin (_ang)), (_pos param [2, 0])];
                private _safe = [_relPos, 0, 2, 0, 0, 0.3, 0, [], _relPos] call BIS_fnc_findSafePos;
                if (_safe isEqualType [] && { count _safe >= 2 }) then {
                    _relPos = [(_safe select 0), (_safe select 1), (_safe param [2, 0])];
                    private _obj = createVehicle [_class, _relPos, [], 0, "NONE"];
                    _obj setDir (_angle + _dir + _dirObj);
                    _obj setPosATL _relPos;
                    if (!surfaceIsWater _relPos) then { _obj setVectorUp surfaceNormal _relPos };
                    _aoCompositionObjects pushBack _obj;
                };
            };
        } forEach _objComposition;
    };
} forEach _points;

private _pointMarkers = [];
{
    private _m = createMarker ["FADE_ao_pt_" + _taskId + str _forEachIndex, _x];
    _m setMarkerType "o_unknown";
    _m setMarkerColor "ColorEAST";
    _m setMarkerText (["ALPHA", "BRAVO", "DELTA"] select _forEachIndex);
    _m setMarkerAlpha 0;  // hidden
    _pointMarkers pushBack _m;
} forEach _points;
missionNamespace setVariable ["FADE_aoMarkers_" + _taskId, [_zoneOuterName, _zoneName] + _pointMarkers];

private _startTime = time;
private _timeout = 30 * 60;

// Brief and hint
private _grid = mapGridPosition _destPos;
private _brief = format ["AREA OF OPERATIONS%1%1ZONE: 2 km x 2 km at Grid %2. BLUFOR spawn 100 m outside one edge; assault OBJ 1 (closest), then OBJ 2, then OBJ 3. OPFOR on objectives and patrolling around each.%1%1Secure all 3 objectives to complete.", toString [10], _grid];
_player setVariable ["FADE_myMissionBrief", _brief, true];
[format ["<t size='1.3' color='#FFD700'>MISSION ASSIGNED</t><br/><br/><t size='1.1' color='#E0E0E0'>Area of Operations</t><br/><t color='#B0B0B0'>Zone: 2 km x 2 km at Grid %1</t><br/><t color='#A0A0A0'>OBJ 1 → OBJ 2 → OBJ 3. OPFOR on objectives + patrols.</t><br/><br/><t color='#C0C0C0'>Capture all 3. JTAC on station for CAS.</t>", _grid]] remoteExec ["FADE_showMissionHint", _player];
[_player, "Area of Operations"] call FADE_notifyOthersMissionStarted;

// OPFOR: strength from Scenario GUI (Low / Mid / High). Per objective: guard group(s), patrol groups, turrets (Mid+), vehicle (High only).
private _aoStrength = missionNamespace getVariable ["FADE_aoStrength", "Medium"];
if (_aoStrength == "Mid") then { _aoStrength = "Medium" };
private _enemyFaction = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
private _opforGroups = [];
private _aoDefenseVehicles = [[], [], []];  // per objective, for High respawn
private _enemyCount = (count _enemyUnits) max 1;
private _turretClass = "O_HMG_01_high_F";
if (!isNil "FADE_aaa_getStaticLightClass") then { _turretClass = [_enemyFaction] call FADE_aaa_getStaticLightClass };
private _enemyVehicles = [_enemyFaction] call (missionNamespace getVariable ["FADE_getEnemyVehiclesForFaction", { [] }]);
if (_enemyVehicles isEqualTo []) then { _enemyVehicles = ["O_MRAP_02_F", "O_APC_Wheeled_02_rcws_v2_F"] };

// BLUFOR edge direction for turret orientation (face approach)
private _bluEdgeCenter = [_destPos, _zoneHalfDepth + 100, _attackDir] call BIS_fnc_relPos;

{
    private _objPos = _x;
    private _objIdx = _forEachIndex;

    // Guard group(s) at OBJ - spread positions (40–110 m, double previous dispersion), ambient combat anim like HVT/Hostage/Clear Area
    private _numGuard = if (_aoStrength == "High") then { 2 } else { 1 };
    private _guardMin = if (_aoStrength == "Low") then { 3 } else { 6 };
    private _guardMax = if (_aoStrength == "Low") then { 6 } else { 10 };
    for "_g" from 0 to (_numGuard - 1) do {
        private _nGuard = _guardMin + floor random ((_guardMax - _guardMin) + 1);
        private _staticGrp = createGroup EAST;
        for "_i" from 0 to (_nGuard - 1) do {
            private _staticPos = [_objPos, 40 + random 70, random 360] call BIS_fnc_relPos;
            _staticPos = [_staticPos, 0, 35, 3, 0, 0.4, 0, [], _staticPos] call BIS_fnc_findSafePos;
            if (!(_staticPos isEqualType []) || { count _staticPos < 2 }) then { _staticPos = [_objPos, 50 + random 50, random 360] call BIS_fnc_relPos };
            if (count _staticPos < 3) then { _staticPos set [2, 0] };
            private _cls = _enemyUnits select (_i % _enemyCount);
            private _u = _staticGrp createUnit [_cls, _staticPos, [], 0, "NONE"];
            if (!isNull _u) then {
                _u setUnitPos "MIDDLE";
                [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
            };
        };
        [_staticGrp] call (missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}]);
        _staticGrp setBehaviour "COMBAT";
        _staticGrp setCombatMode "RED";
        _opforGroups pushBack _staticGrp;
    };

    // Patrol groups - count and size by strength; spawn 250 m from OBJ, waypoints with 100 m per-group dispersion
    private _numPatrol = switch (_aoStrength) do { case "Low": { 2 }; case "Medium": { 3 }; default { 4 }; };
    private _patrolMin = 4;
    private _patrolMax = 8;
    for "_p" from 0 to (_numPatrol - 1) do {
        private _patrolPos = [_objPos, 250 + random 50, random 360] call BIS_fnc_relPos;
        _patrolPos = [_patrolPos, 0, 25, 3, 0, 0.4, 0, [], _patrolPos] call BIS_fnc_findSafePos;
        if (!(_patrolPos isEqualType []) || { count _patrolPos < 2 }) then { _patrolPos = [_objPos, 250, random 360] call BIS_fnc_relPos };
        private _nPatrol = _patrolMin + floor random ((_patrolMax - _patrolMin) + 1);
        private _patrolClasses = [];
        for "_i" from 0 to (_nPatrol - 1) do { _patrolClasses pushBack (_enemyUnits select (_i % _enemyCount)) };
        private _patrolGrp = [_patrolPos, EAST, _patrolClasses] call BIS_fnc_spawnGroup;
        [_patrolGrp] call (missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}]);
        _patrolGrp setBehaviour "SAFE";
        _patrolGrp setCombatMode "YELLOW";
        for "_w" from 0 to 3 do {
            private _wpDist = 150 + random 50;  // waypoints at least 150 m from OBJ center
            private _wpDir = _w * 90 + random 45;
            private _wpPos = [_objPos, _wpDist, _wpDir] call BIS_fnc_relPos;
            _wpPos = [_wpPos, random 100, random 360] call BIS_fnc_relPos;  // 0–100 m dispersion per waypoint so groups don't share same path
            if (!(_wpPos isEqualType []) || { count _wpPos < 2 }) then { _wpPos = [_objPos, _wpDist, _wpDir] call BIS_fnc_relPos };
            if (_wpPos isEqualType [] && { count _wpPos >= 2 }) then {
                private _wpSafe = [_wpPos, 0, 15, 2, 0, 0.4, 0, [], _wpPos] call BIS_fnc_findSafePos;
                if (_wpSafe isEqualType [] && { count _wpSafe >= 2 }) then { _wpPos = _wpSafe };
            };
            private _wp = _patrolGrp addWaypoint [_wpPos, 0];
            _wp setWaypointType "MOVE";
            _wp setWaypointSpeed "LIMITED";
            if (_w == 3) then { _wp setWaypointType "CYCLE" };
        };
        _opforGroups pushBack _patrolGrp;
    };

    // Turrets (Mid and High): 2 per objective, findSafePos; after 10s orient toward nearest BLUFOR
    if (_aoStrength != "Low" && { isClass (configFile >> "CfgVehicles" >> _turretClass) }) then {
        for "_t" from 0 to 1 do {
            private _turretPos = [_objPos, 8 + random 12, random 360] call BIS_fnc_relPos;
            _turretPos = [_turretPos, 0, 10, 2, 0, 0.35, 0, [], _turretPos] call BIS_fnc_findSafePos;
            if (!(_turretPos isEqualType []) || { count _turretPos < 2 }) then { _turretPos = [_objPos, 10, _t * 180] call BIS_fnc_relPos };
            if (count _turretPos < 3) then { _turretPos set [2, 0] };
            private _turret = createVehicle [_turretClass, _turretPos, [], 0, "NONE"];
            _turret setPosATL _turretPos;
            _aoCompositionObjects pushBack _turret;
            private _gunnerClass = _enemyUnits select 0;
            private _grp = createGroup EAST;
            private _gunner = _grp createUnit [_gunnerClass, _turretPos, [], 0, "NONE"];
            if (!isNull _gunner) then {
                _gunner moveInGunner _turret;
                [_grp] call (missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}]);
                _opforGroups pushBack _grp;
            } else { deleteGroup _grp };
            [(_turret), _taskId] spawn {
                params ["_turret", "_taskId"];
                sleep 10;
                if (!alive _turret || { missionNamespace getVariable ["FADE_aoAborted_" + _taskId, false] }) exitWith {};
                private _blu = (_turret nearEntities ["Man", 2500]) select { side _x == WEST && { alive _x } };
                if (_blu isEqualTo []) exitWith {};
                private _nearest = objNull;
                private _minDist = 1e10;
                { private _d = _turret distance _x; if (_d < _minDist) then { _minDist = _d; _nearest = _x } } forEach _blu;
                if (!isNull _nearest) then {
                    _turret setDir ((_turret getDir _nearest) + 90);  // +90 for static HMG barrel vs vehicle forward
                };
            };
        };
    };

    // Defense vehicle (High only): 1 per objective, hold position; can respawn in waves
    if (_aoStrength == "High" && { count _enemyVehicles > 0 }) then {
        private _vehClass = selectRandom _enemyVehicles;
        if (isClass (configFile >> "CfgVehicles" >> _vehClass)) then {
            private _vehPos = [_objPos, 5 + random 15, random 360] call BIS_fnc_relPos;
            _vehPos = [_vehPos, 0, 12, 3, 0, 0.35, 0, [], _vehPos] call BIS_fnc_findSafePos;
            if (!(_vehPos isEqualType []) || { count _vehPos < 2 }) then { _vehPos = [_objPos, 10, random 360] call BIS_fnc_relPos };
            if (count _vehPos < 3) then { _vehPos set [2, 0] };
            private _veh = createVehicle [_vehClass, _vehPos, [], 0, "NONE"];
            _veh setPosATL _vehPos;
            _veh setDir (_veh getDir _bluEdgeCenter);
            _aoCompositionObjects pushBack _veh;
            (_aoDefenseVehicles select _objIdx) pushBack _veh;
            private _crewGrp = createGroup EAST;
            private _driver = _crewGrp createUnit [(_enemyUnits select 0), _vehPos, [], 0, "NONE"];
            if (!isNull _driver) then {
                _driver assignAsDriver _veh;
                _driver moveInDriver _veh;
                private _gunner = _crewGrp createUnit [(_enemyUnits select (1 min (_enemyCount - 1))), _vehPos, [], 0, "NONE"];
                if (!isNull _gunner) then {
                    _gunner assignAsGunner _veh;
                    _gunner moveInGunner _veh;
                };
                [_crewGrp] call (missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}]);
                _crewGrp setBehaviour "COMBAT";
                _crewGrp setCombatMode "RED";
                private _wp = _crewGrp addWaypoint [_objPos, 0];
                _wp setWaypointType "HOLD";
                _opforGroups pushBack _crewGrp;
            } else { deleteGroup _crewGrp };
        };
    };
} forEach _points;
if (!isNil "FADE_registerEnemyRetreat") then { [_opforGroups, _basePos] call FADE_registerEnemyRetreat };
private _opforTargetCount = count _opforGroups;

// Spawn BLUFOR on the attack edge (just outside zone), offset along zone width (±1000 m); prefer a road in that area
private _edgeCenter = [_destPos, _zoneHalfDepth + 100, _attackDir] call BIS_fnc_relPos;
private _latOffset = (random 2001) - 1000;  // ±1000 m along zone width
private _candidate = [_edgeCenter, _latOffset, _attackDir + 90] call BIS_fnc_relPos;
private _roads = _candidate nearRoads 250;
private _bluSpawn = _candidate;
if (count _roads > 0) then {
    _bluSpawn = getPos (selectRandom _roads);
    if (!(_bluSpawn isEqualType []) || { count _bluSpawn < 2 }) then { _bluSpawn = _candidate } else { if (count _bluSpawn < 3) then { _bluSpawn set [2, 0] } };
} else {
    _bluSpawn = [_candidate, 0, 50, 5, 0, 0.3, 0, [], _candidate] call BIS_fnc_findSafePos;
};
if (!(_bluSpawn isEqualType []) || { count _bluSpawn < 2 }) then { _bluSpawn = _candidate };
if (count _bluSpawn < 3) then { _bluSpawn set [2, 0] };
private _bluSpawnMarkerName = "FADE_ao_bluSpawn_" + _taskId;
private _bluSpawnM = createMarker [_bluSpawnMarkerName, _bluSpawn];
_bluSpawnM setMarkerType "b_inf";
_bluSpawnM setMarkerText "BLUFOR Insertion/Reinforcement Point";
missionNamespace setVariable ["FADE_aoMarkers_" + _taskId, (missionNamespace getVariable ["FADE_aoMarkers_" + _taskId, []]) + [_bluSpawnMarkerName]];
private _bluCount = (count _friendlyUnits) max 1;
private _bluGroups = [];
for "_g" from 0 to (1 + floor random 2) do {
    private _pos = [_bluSpawn, random 80, random 360] call BIS_fnc_relPos;
    private _classes = [];
    for "_i" from 0 to (4 + floor random 3) do { _classes pushBack (_friendlyUnits select (_i % _bluCount)) };
    private _grp = [_pos, WEST, _classes] call BIS_fnc_spawnGroup;
    [_grp] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
    [_grp] call FADE_attachNightStrobes;
    _grp setFormation "LINE";
    _grp setBehaviour "AWARE";
    _grp setCombatMode "RED";
    private _objectivesToTake = [];
    { if ((_x nearEntities ["Man", _captureRadius]) select { side _x == WEST && { alive _x } } isEqualTo []) then { _objectivesToTake pushBack _x } } forEach _points;
    { _grp addWaypoint [_x, 0] } forEach _objectivesToTake;
    _bluGroups pushBack _grp;
};

// Define before JTAC block so JTAC respawn spawn can receive _aoAllGroups; JTAC group added when created
private _aoAllGroups = _bluGroups + _opforGroups;
missionNamespace setVariable ["FADE_aoEntities_" + _taskId, [_aoAllGroups, _aoCompositionObjects]];

// JTAC unit (BLUFOR, faction from config GUI) - independent of assault BLUFOR; moves to high ground between objectives as each is captured. Respawns when wiped.
private _fnc_startJtacMovement = {
    params ["_jtacGrp", "_points", "_destPos", "_zoneHalfDepth", "_zoneHalfWidth", "_attackDir", "_captureRadius", "_taskId"];
    [_jtacGrp, _points, _destPos, _zoneHalfDepth, _zoneHalfWidth, _attackDir, _captureRadius, _taskId] spawn {
        params ["_jtacGrp", "_points", "_destPos", "_zoneHalfDepth", "_zoneHalfWidth", "_attackDir", "_captureRadius", "_taskId"];
        private _fnc_inAO = {
            params ["_p", "_center", "_halfDepth", "_halfWidth", "_angleDeg"];
            if (!(_p isEqualType []) || { count _p < 2 }) exitWith { false };
            private _dx = (_p select 0) - (_center select 0);
            private _dy = (_p select 1) - (_center select 1);
            private _rad = _angleDeg * 3.14159 / 180;
            private _lx = _dx * (cos _rad) + _dy * (sin _rad);
            private _ly = -_dx * (sin _rad) + _dy * (cos _rad);
            (abs _lx <= _halfDepth) && (abs _ly <= _halfWidth)
        };
        private _fnc_highestBetween = {
            params ["_posA", "_posB", "_center", "_halfDepth", "_halfWidth", "_angleDeg", "_fncInAO"];
            private _best = [(_posA select 0), (_posA select 1), 0];
            private _bestH = getTerrainHeightASL _best;
            for "_i" from 0 to 24 do {
                private _t = _i / 24;
                private _px = (_posA select 0) + ((_posB select 0) - (_posA select 0)) * _t;
                private _py = (_posA select 1) + ((_posB select 1) - (_posA select 1)) * _t;
                private _p = [_px, _py, 0];
                if ([_p, _center, _halfDepth, _halfWidth, _angleDeg] call _fncInAO) then {
                    private _h = getTerrainHeightASL _p;
                    if (_h > _bestH) then { _bestH = _h; _best = _p };
                };
            };
            _best
        };
        private _jtacStart = getPosATL (leader _jtacGrp);
        if (count _jtacStart < 2) then { _jtacStart = [0, 0, 0] };
        {
            if (missionNamespace getVariable ["FADE_aoAborted_" + _taskId, false]) exitWith {};
            private _from = if (_forEachIndex == 0) then { _jtacStart } else { _points select (_forEachIndex - 1) };
            private _to = _points select _forEachIndex;
            private _highPos = [_from, _to, _destPos, _zoneHalfDepth, _zoneHalfWidth, _attackDir, _fnc_inAO] call _fnc_highestBetween;
            _jtacGrp addWaypoint [_highPos, 0];
            (leader _jtacGrp) doMove _highPos;
            waitUntil {
                sleep 2;
                missionNamespace getVariable ["FADE_aoAborted_" + _taskId, false]
                || { count ((_points select _forEachIndex) nearEntities ["Man", _captureRadius] select { side _x == WEST && { alive _x } }) > 0 }
            };
            if (missionNamespace getVariable ["FADE_aoAborted_" + _taskId, false]) exitWith {};
            while { count (waypoints _jtacGrp) > 0 } do { deleteWaypoint ((waypoints _jtacGrp) select 0) };
        } forEach _points;
    };
};
if (missionNamespace getVariable ["FADE_aoJtacEnabled", true]) then {
    private _jtacPos = [_bluSpawn, 20, _attackDir + 90] call BIS_fnc_relPos;
    private _jtacKeywords = ["jtac", "observer", "jfo", "joint", "fires"];
    private _jtacCandidates = _friendlyUnits select {
        if (!isClass (configFile >> "CfgVehicles" >> _x)) then { false } else {
            private _dn = toLower (getText (configFile >> "CfgVehicles" >> _x >> "displayName"));
            private _cl = toLower _x;
            private _match = false;
            { if (_dn find _x >= 0 || { _cl find _x >= 0 }) then { _match = true } } forEach _jtacKeywords;
            _match
        };
    };
    private _jtacClass = if (count _jtacCandidates > 0) then { selectRandom _jtacCandidates } else { if (count _friendlyUnits > 0) then { selectRandom _friendlyUnits } else { "B_Soldier_TL_F" } };
    private _jtacGrp = [_jtacPos, WEST, [_jtacClass]] call BIS_fnc_spawnGroup;
    _jtacGrp setFormation "LINE";
    _bluGroups pushBack _jtacGrp;
    _aoAllGroups pushBack _jtacGrp;
    private _jtac = leader _jtacGrp;
    _jtac setRank "SERGEANT";
    [_jtacGrp] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
    _jtacGrp setVariable ["FADE_callsign", "Eagle Eye", true];
    missionNamespace setVariable ["FADE_aoJtacGrp_" + _taskId, _jtacGrp];
    [_jtacGrp] call FADE_attachNightStrobes;
    private _callsign = _jtacGrp getVariable ["FADE_callsign", "JTAC"];
    (leader _jtacGrp) sideChat format ["All callsigns, this is %1. AO established Grid %2. I am moving to observe and will advise targets. Out.", _callsign, _grid];
    [_jtacGrp, _points, _destPos, _zoneHalfDepth, _zoneHalfWidth, _attackDir, _captureRadius, _taskId] call _fnc_startJtacMovement;

    // JTAC respawn: same timing as BLUFOR (30–60s); when JTAC group has no alive units, spawn new JTAC and re-run movement script
    [_taskId, _bluSpawn, _attackDir, _friendlyUnits, _jtacKeywords, _jtacClass, _points, _destPos, _zoneHalfDepth, _zoneHalfWidth, _captureRadius, _bluGroups, _aoAllGroups, _grid, _fnc_startJtacMovement, _startTime, _timeout] spawn {
        params ["_taskId", "_bluSpawn", "_attackDir", "_friendlyUnits", "_jtacKeywords", "_jtacClass", "_points", "_destPos", "_zoneHalfDepth", "_zoneHalfWidth", "_captureRadius", "_bluGroups", "_aoAllGroups", "_grid", "_fnc_startJtacMovement", "_startTime", "_timeout"];
        while {
            !(missionNamespace getVariable ["FADE_aoAborted_" + _taskId, false])
            && { time - _startTime < _timeout }
            && { (_taskId call BIS_fnc_taskState) != "SUCCEEDED" }
        } do {
            sleep (30 + random 30);
            if (!(missionNamespace getVariable ["FADE_aoJtacEnabled", true])) then { sleep 30; continue };
            private _grp = missionNamespace getVariable ["FADE_aoJtacGrp_" + _taskId, grpNull];
            if (!isNull _grp && { count (units _grp select { alive _x }) > 0 }) then { continue };
            private _jtacPos = [_bluSpawn, 20, _attackDir + 90] call BIS_fnc_relPos;
            private _jtacCandidates = _friendlyUnits select {
                if (!isClass (configFile >> "CfgVehicles" >> _x)) then { false } else {
                    private _dn = toLower (getText (configFile >> "CfgVehicles" >> _x >> "displayName"));
                    private _cl = toLower _x;
                    private _match = false;
                    { if (_dn find _x >= 0 || { _cl find _x >= 0 }) then { _match = true } } forEach _jtacKeywords;
                    _match
                };
            };
            private _class = if (count _jtacCandidates > 0) then { selectRandom _jtacCandidates } else { if (count _friendlyUnits > 0) then { selectRandom _friendlyUnits } else { "B_Soldier_TL_F" } };
            private _newGrp = [_jtacPos, WEST, [_class]] call BIS_fnc_spawnGroup;
            _newGrp setFormation "LINE";
            _newGrp setVariable ["FADE_callsign", "Eagle Eye", true];
            missionNamespace setVariable ["FADE_aoJtacGrp_" + _taskId, _newGrp];
            (leader _newGrp) setRank "SERGEANT";
            [_newGrp] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
            [_newGrp] call FADE_attachNightStrobes;
            _bluGroups pushBack _newGrp;
            _aoAllGroups pushBack _newGrp;
            (leader _newGrp) sideChat format ["Eagle Eye back on station. Grid %1. Out.", _grid];
            [_newGrp, _points, _destPos, _zoneHalfDepth, _zoneHalfWidth, _attackDir, _captureRadius, _taskId] call _fnc_startJtacMovement;
        };
    };
};

// BLUFOR reinforcements: keep 2-4 BLUFOR squads (groups) active; spawn in a wave at BLUFOR edge every 30-60s when below 2 squads
[_taskId, _bluGroups, _aoAllGroups, _points, _bluSpawn, _friendlyUnits, _bluCount, _captureRadius, _startTime, _timeout] spawn {
    params ["_taskId", "_bluGroups", "_aoAllGroups", "_points", "_bluSpawn", "_friendlyUnits", "_bluCount", "_captureRadius", "_startTime", "_timeout"];
    private _bluCountSafe = _bluCount max 1;
    while {
        !(missionNamespace getVariable ["FADE_aoAborted_" + _taskId, false])
        && { time - _startTime < _timeout }
        && { (_taskId call BIS_fnc_taskState) != "SUCCEEDED" }
    } do {
        sleep (30 + random 30);
        private _squadsWithAlive = 0;
        { if (count (units _x select { alive _x }) > 0) then { _squadsWithAlive = _squadsWithAlive + 1 } } forEach _bluGroups;
        if (_squadsWithAlive < 2 && { count _friendlyUnits > 0 }) then {
            private _targetSquads = 2 + floor random 3;
            private _numToSpawn = ((_targetSquads - _squadsWithAlive) max 1) min 4;
            private _objectivesToTake = [];
            { if ((_x nearEntities ["Man", _captureRadius]) select { side _x == WEST && { alive _x } } isEqualTo []) then { _objectivesToTake pushBack _x } } forEach _points;
            for "_s" from 0 to (_numToSpawn - 1) do {
                private _pos = [_bluSpawn, 25 + random 50, random 360] call BIS_fnc_relPos;
                private _squadSize = 4 + floor random 4;
                private _classes = [];
                for "_i" from 0 to (_squadSize - 1) do { _classes pushBack (_friendlyUnits select (_i % _bluCountSafe)) };
                private _grp = [_pos, WEST, _classes] call BIS_fnc_spawnGroup;
                [_grp] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
                [_grp] call FADE_attachNightStrobes;
                _grp setFormation "LINE";
                _grp setBehaviour "AWARE";
                _grp setCombatMode "RED";
                { _grp addWaypoint [_x, 0] } forEach _objectivesToTake;
                _bluGroups pushBack _grp;
                _aoAllGroups pushBack _grp;
            };
        };
    };
};

// OPFOR reinforcements: check every 25–50 s; maintain initial OPFOR group count (any group that dies can be replaced). Spawn wave at OPFOR edge, spread across uncaptured OBJs. No spawn if all objectives captured. High strength: replace destroyed defense vehicles at uncaptured objectives.
[_taskId, _opforGroups, _aoAllGroups, _points, _destPos, _zoneHalfDepth, _attackDir, _enemyUnits, _aoStrength, _aoDefenseVehicles, _aoCompositionObjects, _enemyVehicles, _opforTargetCount, _startTime, _timeout, _captureRadius] spawn {
    params ["_taskId", "_opforGroups", "_aoAllGroups", "_points", "_destPos", "_zoneHalfDepth", "_attackDir", "_enemyUnits", "_aoStrength", "_aoDefenseVehicles", "_aoCompositionObjects", "_enemyVehicles", "_opforTargetCount", "_startTime", "_timeout", "_captureRadius"];
    private _enemyCount = (count _enemyUnits) max 1;
    private _bluEdgeCenter = [_destPos, _zoneHalfDepth + 100, _attackDir] call BIS_fnc_relPos;
    while {
        !(missionNamespace getVariable ["FADE_aoAborted_" + _taskId, false])
        && { time - _startTime < _timeout }
        && { (_taskId call BIS_fnc_taskState) != "SUCCEEDED" }
    } do {
        private _squadsWithAlive = 0;
        { if (count (units _x select { alive _x }) > 0) then { _squadsWithAlive = _squadsWithAlive + 1 } } forEach _opforGroups;
        if (_squadsWithAlive < _opforTargetCount && { count _enemyUnits > 0 }) then {
            private _numToSpawn = ((_opforTargetCount - _squadsWithAlive) max 1) min 6;
            private _objectivesToReinforce = [];
            { if (count ((_x nearEntities ["Man", _captureRadius]) select { side _x == WEST && { alive _x } }) == 0) then { _objectivesToReinforce pushBack _x } } forEach _points;
            if (count _objectivesToReinforce > 0) then {
                for "_s" from 0 to (_numToSpawn - 1) do {
                    private _assignedObj = _objectivesToReinforce select (_s % (count _objectivesToReinforce));
                    private _spawnPos = [_destPos, _zoneHalfDepth + 100, _attackDir + 180] call BIS_fnc_relPos;
                    _spawnPos = [_spawnPos, (random 100) - 50, _attackDir + 90] call BIS_fnc_relPos;
                    _spawnPos = [_spawnPos, 0, 30, 5, 0, 0.4, 0, [], _spawnPos] call BIS_fnc_findSafePos;
                    if (!(_spawnPos isEqualType []) || { count _spawnPos < 2 }) then { _spawnPos = [_destPos, _zoneHalfDepth + 100, _attackDir + 180] call BIS_fnc_relPos };
                    private _squadSize = 4 + floor random 4;
                    private _classes = [];
                    for "_i" from 0 to (_squadSize - 1) do { _classes pushBack (_enemyUnits select (_i % _enemyCount)) };
                    private _grp = [_spawnPos, EAST, _classes] call BIS_fnc_spawnGroup;
                    [_grp] call (missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}]);
                    _grp setBehaviour "AWARE";
                    _grp setCombatMode "RED";
                    _grp addWaypoint [_assignedObj, 0];
                    _opforGroups pushBack _grp;
                    _aoAllGroups pushBack _grp;
                };
            };
        };
        // High strength: respawn destroyed defense vehicles at OPFOR insertion point, then waypoint to objective
        if (_aoStrength == "High" && { count _enemyVehicles > 0 }) then {
            {
                private _objPos = _x;
                private _objIdx = _forEachIndex;
                if (count ((_objPos nearEntities ["Man", _captureRadius]) select { side _x == WEST && { alive _x } }) > 0) then { continue };
                private _vehList = _aoDefenseVehicles param [_objIdx, []];
                private _alive = _vehList select { !isNull _x && { alive _x } };
                if (count _alive > 0) then { continue };
                private _vehClass = selectRandom _enemyVehicles;
                if (!isClass (configFile >> "CfgVehicles" >> _vehClass)) then { continue };
                private _vehPos = [_destPos, _zoneHalfDepth + 100, _attackDir + 180] call BIS_fnc_relPos;
                _vehPos = [_vehPos, (random 100) - 50, _attackDir + 90] call BIS_fnc_relPos;
                _vehPos = [_vehPos, 0, 30, 5, 0, 0.35, 0, [], _vehPos] call BIS_fnc_findSafePos;
                if (!(_vehPos isEqualType []) || { count _vehPos < 2 }) then { _vehPos = [_destPos, _zoneHalfDepth + 100, _attackDir + 180] call BIS_fnc_relPos };
                if (count _vehPos < 3) then { _vehPos set [2, 0] };
                private _veh = createVehicle [_vehClass, _vehPos, [], 0, "NONE"];
                _veh setPosATL _vehPos;
                _veh setDir (_veh getDir _bluEdgeCenter);
                _aoCompositionObjects pushBack _veh;
                (_aoDefenseVehicles select _objIdx) pushBack _veh;
                private _crewGrp = createGroup EAST;
                private _driver = _crewGrp createUnit [(_enemyUnits select 0), _vehPos, [], 0, "NONE"];
                if (!isNull _driver) then {
                    _driver assignAsDriver _veh;
                    _driver moveInDriver _veh;
                    private _gunner = _crewGrp createUnit [(_enemyUnits select (1 min (_enemyCount - 1))), _vehPos, [], 0, "NONE"];
                    if (!isNull _gunner) then {
                        _gunner assignAsGunner _veh;
                        _gunner moveInGunner _veh;
                    };
                    [_crewGrp] call (missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}]);
                    _crewGrp setBehaviour "COMBAT";
                    _crewGrp setCombatMode "RED";
                    private _wp = _crewGrp addWaypoint [_objPos, 0];
                    _wp setWaypointType "HOLD";
                    _opforGroups pushBack _crewGrp;
                    _aoAllGroups pushBack _crewGrp;
                } else { deleteGroup _crewGrp };
            } forEach _points;
        };
        sleep (25 + random 25);
    };
};

// Counter-attack: when BLUFOR first captures an objective, 50% chance to spawn a wave from OPFOR edge with waypoint to that objective. Troop level by difficulty.
[_taskId, _opforGroups, _aoAllGroups, _points, _destPos, _zoneHalfDepth, _attackDir, _enemyUnits, _aoStrength, _captureRadius, _startTime, _timeout] spawn {
    params ["_taskId", "_opforGroups", "_aoAllGroups", "_points", "_destPos", "_zoneHalfDepth", "_attackDir", "_enemyUnits", "_aoStrength", "_captureRadius", "_startTime", "_timeout"];
    private _enemyCount = (count _enemyUnits) max 1;
    private _capturedState = [false, false, false];
    while {
        !(missionNamespace getVariable ["FADE_aoAborted_" + _taskId, false])
        && { time - _startTime < _timeout }
        && { (_taskId call BIS_fnc_taskState) != "SUCCEEDED" }
    } do {
        sleep 15;
        {
            private _objPos = _x;
            private _idx = _forEachIndex;
            if (_capturedState select _idx) then { continue };
            private _bluIn = (_objPos nearEntities ["Man", _captureRadius]) select { side _x == WEST && { alive _x } };
            if (count _bluIn == 0) then { continue };
            _capturedState set [_idx, true];
            if (random 1 >= 0.5) then { continue };
            private _numGroups = switch (_aoStrength) do { case "Low": { 1 }; case "Medium": { 1 }; default { 2 }; };
            private _minSize = if (_aoStrength == "Low") then { 3 } else { 6 };
            private _maxSize = if (_aoStrength == "Low") then { 6 } else { 10 };
            private _opforSpawn = [_destPos, _zoneHalfDepth + 100, _attackDir + 180] call BIS_fnc_relPos;
            for "_g" from 0 to (_numGroups - 1) do {
                private _spawnPos = [_opforSpawn, (random 80) - 40, _attackDir + 90] call BIS_fnc_relPos;
                _spawnPos = [_spawnPos, 0, 25, 5, 0, 0.4, 0, [], _spawnPos] call BIS_fnc_findSafePos;
                if (!(_spawnPos isEqualType []) || { count _spawnPos < 2 }) then { _spawnPos = [_opforSpawn, 20, _g * 120] call BIS_fnc_relPos };
                private _squadSize = _minSize + floor random ((_maxSize - _minSize) + 1);
                private _classes = [];
                for "_i" from 0 to (_squadSize - 1) do { _classes pushBack (_enemyUnits select (_i % _enemyCount)) };
                private _grp = [_spawnPos, EAST, _classes] call BIS_fnc_spawnGroup;
                [_grp] call (missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}]);
                _grp setBehaviour "AWARE";
                _grp setCombatMode "RED";
                _grp addWaypoint [_objPos, 0];
                _opforGroups pushBack _grp;
                _aoAllGroups pushBack _grp;
            };
        } forEach _points;
    };
};

// Capture check: all 3 points have at least one alive BLUFOR within _captureRadius
private _fnc_allCaptured = {
    params ["_points", "_captureRadius"];
    private _all = true;
    {
        private _near = (_x nearEntities ["Man", _captureRadius]) select { side _x == WEST && { alive _x } };
        if (_near isEqualTo []) then { _all = false };
    } forEach _points;
    _all
};

// Run until all captured, timeout (30 min), or mission aborted; update OBJ marker to blue when captured
private _objMarkersBlue = [false, false, false];
waitUntil {
    sleep 5;
    for "_idx" from 0 to (count _points - 1) do {
        if (!(_objMarkersBlue select _idx)) then {
            private _near = ((_points select _idx) nearEntities ["Man", _captureRadius]) select { side _x == WEST && { alive _x } };
            if (count _near > 0) then {
                (_pointMarkers select _idx) setMarkerColor "ColorWEST";
                _objMarkersBlue set [_idx, true];
            };
        };
    };
    if (missionNamespace getVariable ["FADE_aoAborted_" + _taskId, false]) then { true } else {
        if (time - _startTime > _timeout) then { true } else {
            [_points, _captureRadius] call _fnc_allCaptured
        }
    };
};

// If aborted, abort handler already cleaned entities and markers; just clear refs and exit
if (missionNamespace getVariable ["FADE_aoAborted_" + _taskId, false]) exitWith {
    missionNamespace setVariable ["FADE_aoMarkers_" + _taskId, nil];
    missionNamespace setVariable ["FADE_aoEntities_" + _taskId, nil];
    missionNamespace setVariable ["FADE_aoAborted_" + _taskId, nil];
};

// Success or timeout
if (time - _startTime <= _timeout) then {
    [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
    [format ["<t size='1.2' color='#90EE90'>AO CAPTURED</t><br/><br/><t color='#E0E0E0'>All 3 objectives secured. Mission complete.</t>"] ] remoteExec ["FADE_showMissionHint", _player];
} else {
    [_taskId, "FAILED"] call BIS_fnc_taskSetState;
    ["<t size='1.2' color='#FF6666'>AO TIMEOUT</t><br/><br/><t color='#E0E0E0'>Time limit reached. Mission failed.</t>"] remoteExec ["FADE_showMissionHint", _player];
};

// 60 s delay before cleanup (match Cargo/Resupply and other modes)
sleep 60;

// Cleanup: markers, all AO groups (BLUFOR, OPFOR, reinforcements), composition objects, mission state
{ [_x] call FADE_deleteMarkerSafe } forEach (_pointMarkers + [_zoneOuterName, _zoneName, _bluSpawnMarkerName]);
{ if (!isNull _x) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } } forEach _aoAllGroups;
{ if (!isNull _x) then { deleteVehicle _x } } forEach _aoCompositionObjects;
missionNamespace setVariable ["FADE_aoMarkers_" + _taskId, nil];
missionNamespace setVariable ["FADE_aoEntities_" + _taskId, nil];
[_player, _taskId] call FADE_clearActiveMission;
missionNamespace setVariable ["FADE_currentMissionType", ""];
missionNamespace setVariable ["FADE_currentMissionPlayer", objNull];
publicVariable "FADE_currentMissionType";
