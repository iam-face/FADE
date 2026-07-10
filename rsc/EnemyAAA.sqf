// =============================================================================
// EnemyAAA.sqf — dynamic AAA / MANPADS around airborne player aircraft (server)
// Modes: Off | AAA (3 static AA) | AAA+MANPADS (static + 2 MANPADS infantry)
// =============================================================================

if (!isServer) exitWith {};

FADE_aaa_fallbackStatic = "O_HMG_01_high_F";
FADE_aaa_fallbackManpads = "O_Soldier_AA_F";
FADE_aaa_clusters = createHashMap;
FADE_aaa_staticLightClassCache = createHashMap;
missionNamespace setVariable ["FADE_aaa_staticLightClassCache", FADE_aaa_staticLightClassCache];

FADE_aaa_cfgVehicleSideNum = {
    params ["_cfg"];
    private _sideCfg = _cfg >> "side";
    if (isNumber _sideCfg) then { getNumber _sideCfg } else { -1 }
};

FADE_aaa_normalizeLevel = {
    params [["_lvl", "Off"]];
    switch (toUpper _lvl) do {
        case "NONE": { "Off" };
        case "LIGHT";
        case "MEDIUM";
        case "HEAVY": { "AAA" };
        case "MANPADS": { "AAA+MANPADS" };
        case "AAA+MANPADS": { "AAA+MANPADS" };
        case "AAA": { "AAA" };
        default { "Off" };
    };
};

FADE_aaa_getStaticLightClass = {
    params [["_faction", ""]];
    if (_faction == "") then { _faction = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"] };
    private _cache = missionNamespace getVariable ["FADE_aaa_staticLightClassCache", createHashMap];
    if (_faction in _cache) exitWith { _cache get _faction };
    private _fallback = missionNamespace getVariable ["FADE_aaa_fallbackStatic", "O_HMG_01_high_F"];
    private _side = [_faction, 0] call (missionNamespace getVariable ["FADE_getFactionSideNum", { 0 }]);
    private _pick = "";
    {
        private _cfg = _x;
        private _class = configName _cfg;
        if (getNumber (_cfg >> "scope") < 2) then { continue };
        if ([_cfg] call FADE_aaa_cfgVehicleSideNum != _side) then { continue };
        if !(_class isKindOf "StaticWeapon") then { continue };
        if (getText (_cfg >> "faction") != _faction) then { continue };
        private _dn = toLower getText (_cfg >> "displayName");
        if ((_dn find "hmg" >= 0) || { _dn find "gmg" >= 0 } || { _dn find "aa" >= 0 }) exitWith { _pick = _class };
        if (_pick == "") then { _pick = _class };
    } forEach ("true" configClasses (configFile >> "CfgVehicles"));
    private _result = if (_pick != "") then { _pick } else { _fallback };
    _cache set [_faction, _result];
    missionNamespace setVariable ["FADE_aaa_staticLightClassCache", _cache];
    _result
};

FADE_aaa_getStaticAAClass = {
    params [["_faction", ""]];
    if (_faction == "") then { _faction = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"] };
    private _side = [_faction, 0] call (missionNamespace getVariable ["FADE_getFactionSideNum", { 0 }]);
    private _pick = "";
    {
        private _cfg = _x;
        private _class = configName _cfg;
        if (getNumber (_cfg >> "scope") < 2) then { continue };
        if ([_cfg] call FADE_aaa_cfgVehicleSideNum != _side) then { continue };
        if !(_class isKindOf "StaticWeapon") then { continue };
        private _dn = toLower getText (_cfg >> "displayName");
        private _isAA = (getNumber (_cfg >> "airLock") > 0) || { getNumber (_cfg >> "maneuvrability") > 0 };
        private _nameAA = (_dn find "sam" >= 0) || { _dn find "flak" >= 0 } || { (_dn find "aa" >= 0) && { _dn find "hmg" < 0 } };
        if (_isAA || _nameAA) then {
            if (getText (_cfg >> "faction") == _faction) exitWith { _pick = _class };
            if (_pick == "") then { _pick = _class };
        };
    } forEach ("true" configClasses (configFile >> "CfgVehicles"));
    if (_pick != "") then { _pick } else { [_faction] call FADE_aaa_getStaticLightClass }
};

FADE_aaa_getManpadsUnitClass = {
    params [["_faction", ""]];
    if (_faction == "") then { _faction = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"] };
    private _fallback = missionNamespace getVariable ["FADE_aaa_fallbackManpads", "O_Soldier_AA_F"];
    private _units = [_faction, 0] call FADE_getUnitsForFaction;
    if (_units isEqualTo []) exitWith { _fallback };
    private _candidates = [];
    {
        if !(_x isKindOf "Man") then { continue };
        private _weapons = getArray (configFile >> "CfgVehicles" >> _x >> "weapons");
        private _hit = false;
        {
            private _w = toLower _x;
            if ((_w find "stinger" >= 0) || { _w find "igla" >= 0 } || { _w find "titan_aa" >= 0 } || { (_w find "launch_" >= 0) && { _w find "aa" >= 0 } }) exitWith { _hit = true };
        } forEach _weapons;
        if (_hit) then { _candidates pushBack _x };
    } forEach _units;
    if (_candidates isEqualTo []) then { _fallback } else { _candidates select (floor random (count _candidates)) }
};

FADE_aaa_isVehicleAirborne = {
    params ["_veh"];
    if (isNull _veh || { !alive _veh }) exitWith { false };
    if !(_veh isKindOf "Air") exitWith { false };
    private _alt = (getPosATL _veh) select 2;
    private _vz = (velocity _veh) select 2;
    (_alt > 20) && { (!isTouchingGround _veh) || { _vz > 5 } }
};

FADE_aaa_getAirbornePlayerVehicles = {
    private _out = [];
    {
        if (isPlayer _x && { alive _x }) then {
            private _veh = vehicle _x;
            if (_veh != _x && { [_veh] call FADE_aaa_isVehicleAirborne }) then {
                _out pushBackUnique _veh;
            };
        };
    } forEach allPlayers;
    _out
};

FADE_aaa_getBasePos = {
    private _bp = missionNamespace getVariable ["FADE_basePos", []];
    if (count _bp >= 2) exitWith { _bp };
    private _o = missionNamespace getVariable ["BASE_1", objNull];
    if (!isNull _o) exitWith { getPosATL _o };
    []
};

FADE_aaa_spawnPosAllowed = {
    params ["_pos", ["_originVeh", objNull]];
    if (count _pos < 2) exitWith { false };
    private _base = [] call FADE_aaa_getBasePos;
    if (count _base >= 2) then {
        private _baseExcl = missionNamespace getVariable ["FADE_aaa_baseExclusionM", 1500];
        if (!isNull _originVeh) then {
            private _airDistBase = (getPosATL _originVeh) distance2D _base;
            private _relaxAt = missionNamespace getVariable ["FADE_aaa_baseRelaxAirDistM", 2500];
            if (_airDistBase >= _relaxAt) then {
                _baseExcl = missionNamespace getVariable ["FADE_aaa_baseExclusionRelaxedM", 800];
            };
        };
        if ((_pos distance2D _base) < _baseExcl) exitWith { false };
    };
    private _excl = missionNamespace getVariable ["FADE_aaa_playerExclusionM", 200];
    if (({ alive _x && { (_pos distance2D _x) < _excl } } count allPlayers) > 0) exitWith { false };
    true
};

FADE_aaa_pickSpawnPos = {
    params ["_originVeh", "_bearingOffset"];
    private _minD = missionNamespace getVariable ["FADE_aaa_spawnDistMin", 1500];
    private _maxD = missionNamespace getVariable ["FADE_aaa_spawnDistMax", 2000];
    private _result = [];
    for "_i" from 0 to 19 do {
        private _dist = _minD + random (_maxD - _minD);
        private _bearing = _bearingOffset + (if (_i > 0) then { (random 120) - 60 } else { 0 });
        private _raw = _originVeh getPos [_dist, (getDir _originVeh) + _bearing];
        private _safe = [[_raw, 10, 60, 6, 0, 0.4, 0, [], _raw], _raw] call FADE_findSafePosArray;
        if !(_safe isEqualType []) then { _safe = _raw };
        if (count _safe < 2) then { _safe = _raw };
        if ([_safe, _originVeh] call FADE_aaa_spawnPosAllowed) then {
            _result = _safe;
        };
        if (count _result >= 2) exitWith {};
    };
    _result
};

// Flat roof ATL near building top (delegates to FADE_Common).
FADE_aaa_buildingRoofPos = {
    params ["_building"];
    [_building] call FADE_buildingRoofPos
};

// MANPADS spawn: optional roof near ground anchor from FADE_aaa_pickSpawnPos.
FADE_aaa_pickManpadsSpawnPos = {
    params ["_originVeh", "_bearingOffset"];
    private _ground = [_originVeh, _bearingOffset] call FADE_aaa_pickSpawnPos;
    if (count _ground < 2) exitWith { [] };
    private _chance = missionNamespace getVariable ["FADE_aaa_manpadsRoofChance", 0.35];
    if (random 1 > _chance) exitWith { _ground };
    private _searchR = missionNamespace getVariable ["FADE_aaa_manpadsRoofSearchM", 150];
    private _buildings = nearestObjects [_ground, ["House", "Building"], _searchR];
    _buildings = _buildings select { !isNull _x && { damage _x < 0.9 } };
    if (_buildings isEqualTo []) exitWith { _ground };
    _buildings = _buildings call BIS_fnc_arrayShuffle;
    private _roof = [];
    {
        if (count _roof >= 2) exitWith {};
        private _candidate = [_x] call FADE_aaa_buildingRoofPos;
        if (count _candidate >= 2 && { [_candidate, _originVeh] call FADE_aaa_spawnPosAllowed }) then {
            _roof = _candidate;
        };
    } forEach _buildings;
    if (count _roof >= 2) then {
        if (missionNamespace getVariable ["FADE_aaa_debug", false]) then {
            diag_log format ["[FADE AAA] MANPADS roof spawn at %1", mapGridPosition _roof];
        };
        _roof
    } else {
        _ground
    };
};

FADE_aaa_applyGroupPolicy = {
    params ["_grp"];
    if (isNull _grp) exitWith {};
    private _skill = missionNamespace getVariable ["FADE_enemySkill", 0.0];
    private _routing = missionNamespace getVariable ["FADE_enemyRouting", 0];
    { _x setSkill _skill } forEach units _grp;
    _grp setVariable ["FADE_allowFleeing", _routing];
    _grp allowFleeing _routing;
    if (!isNil "FADE_applyOpforLauncherPolicyToUnit") then {
        { [_x] call FADE_applyOpforLauncherPolicyToUnit } forEach units _grp;
    };
};

FADE_aaa_spawnStatic = {
    params ["_pos"];
    private _faction = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
    private _class = [_faction] call FADE_aaa_getStaticAAClass;
    if (!isClass (configFile >> "CfgVehicles" >> _class)) exitWith { [[], []] };
    private _units = missionNamespace getVariable ["FADE_enemyUnits", ["O_Soldier_F"]];
    if (_units isEqualTo []) exitWith { [[], []] };
    private _side = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _static = createVehicle [_class, _pos, [], 0, "NONE"];
    if (isNull _static) exitWith { [[], []] };
    _static setDir (random 360);
    private _grp = createGroup _side;
    private _gunner = _grp createUnit [_units select 0, _pos, [], 0, "NONE"];
    if (isNull _gunner) exitWith {
        deleteVehicle _static;
        deleteGroup _grp;
        [[], []]
    };
    _gunner moveInGunner _static;
    [_grp] call FADE_aaa_applyGroupPolicy;
    [[_static], [_grp]]
};

FADE_aaa_spawnManpads = {
    params ["_pos", "_targetVeh"];
    private _faction = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
    private _class = [_faction] call FADE_aaa_getManpadsUnitClass;
    if (!isClass (configFile >> "CfgVehicles" >> _class)) exitWith { [[], []] };
    private _side = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _grp = createGroup _side;
    private _u = _grp createUnit [_class, _pos, [], 0, "NONE"];
    if (isNull _u) exitWith {
        deleteGroup _grp;
        [[], []]
    };
    _u setPosATL _pos;
    if ((_pos select 2) > 3) then {
        _u setUnitPos "MIDDLE";
        _u disableAI "PATH";
    };
    if (!isNull _targetVeh) then {
        _u reveal [_targetVeh, 4];
        _u doTarget _targetVeh;
        _grp setCombatMode "RED";
        _u enableAI "TARGET";
        _u enableAI "AUTOTARGET";
    };
    [_grp] call FADE_aaa_applyGroupPolicy;
    [[], [_grp]]
};

FADE_aaa_deleteCluster = {
    params ["_cluster"];
    if (_cluster isEqualType createHashMap) then {
        private _veh = _cluster getOrDefault ["vehicle", objNull];
        if (!isNull _veh) then {
            missionNamespace setVariable [format ["FADE_aaa_lastDespawn_%1", netId _veh], time];
        };
        { if (!isNull _x) then { { deleteVehicle _x } forEach units _x; deleteGroup _x } } forEach (_cluster getOrDefault ["groups", []]);
        { if (!isNull _x) then { deleteVehicle _x } } forEach (_cluster getOrDefault ["objects", []]);
    };
};

FADE_aaa_despawnAll = {
    { [_y] call FADE_aaa_deleteCluster } forEach FADE_aaa_clusters;
    FADE_aaa_clusters = createHashMap;
};

FADE_aaa_maybeSpawnManpadsInZone = {};
FADE_aaa_despawnManpadsInZone = {};

FADE_aaa_spawnClusterForVehicle = {
    params ["_veh", "_mode"];
    private _bearings = [0, 120, 200];
    private _roles = if (_mode == "AAA+MANPADS") then {
        ["static", "manpads", "manpads"]
    } else {
        ["static", "static", "static"]
    };
    private _objects = [];
    private _groups = [];
    private _gunners = [];
    {
        private _role = _roles select _forEachIndex;
        private _pos = if (_role == "manpads") then {
            [_veh, _x] call FADE_aaa_pickManpadsSpawnPos
        } else {
            [_veh, _x] call FADE_aaa_pickSpawnPos
        };
        if (count _pos < 2) then { continue };
        private _spawned = if (_role == "manpads") then {
            [_pos, _veh] call FADE_aaa_spawnManpads
        } else {
            [_pos] call FADE_aaa_spawnStatic
        };
        _objects append (_spawned select 0);
        _groups append (_spawned select 1);
        {
            if (!isNull _x) then {
                { if (alive _x) then { _gunners pushBack _x } } forEach units _x;
            };
        } forEach (_spawned select 1);
    } forEach _bearings;
    private _cluster = createHashMapFromArray [
        ["vehicle", _veh],
        ["spawnedAt", time],
        ["objects", _objects],
        ["groups", _groups],
        ["gunners", _gunners]
    ];
    if ((count _groups) == 0 && { count _objects == 0 }) then {
        diag_log format ["[FADE AAA] WARN: no threats spawned for airborne %1 (placement or base exclusion?)", typeOf _veh];
    };
    _cluster
};

FADE_aaa_clusterTick = {
    params ["_cluster"];
    private _air = _cluster getOrDefault ["vehicle", objNull];
    if (isNull _air || { !([_air] call FADE_aaa_isVehicleAirborne) }) exitWith {};
    {
        if (alive _x) then {
            _x reveal [_air, 4];
            _x doTarget _air;
            _x enableAI "TARGET";
            _x enableAI "AUTOTARGET";
            if (group _x != grpNull) then { group _x setCombatMode "RED" };
        };
    } forEach (_cluster getOrDefault ["gunners", []]);
    {
        if (!isNull _x && { alive _x }) then {
            _x setVehicleAmmo 1;
        };
    } forEach (_cluster getOrDefault ["objects", []]);
};

FADE_aaa_applyLevel = {
    private _lvl = [missionNamespace getVariable ["FADE_enemyAAALevel", "Off"]] call FADE_aaa_normalizeLevel;
    missionNamespace setVariable ["FADE_enemyAAALevel", _lvl];
    call FADE_aaa_despawnAll;
};

if (isNil "FADE_aaa_monitorStarted") then {
    FADE_aaa_monitorStarted = true;
    [] spawn {
        while { true } do {
            private _mode = [missionNamespace getVariable ["FADE_enemyAAALevel", "Off"]] call FADE_aaa_normalizeLevel;
            if (_mode == "Off") then {
                if ((count FADE_aaa_clusters) > 0) then { call FADE_aaa_despawnAll };
                sleep 10;
            } else {
                if ((allPlayers findIf { alive _x }) < 0) then {
                    sleep 10;
                } else {
                    private _active = call FADE_aaa_getAirbornePlayerVehicles;
                    private _activeIds = _active apply { netId _x };
                    private _cooldown = missionNamespace getVariable ["FADE_aaa_respawnCooldownSec", 120];
                    private _maxPerPlayer = missionNamespace getVariable ["FADE_aaa_maxClustersPerPlayer", 1];

                    {
                        private _cluster = FADE_aaa_clusters get _x;
                        private _veh = _cluster getOrDefault ["vehicle", objNull];
                        if !(_x in _activeIds) then {
                            [_cluster] call FADE_aaa_deleteCluster;
                            FADE_aaa_clusters deleteAt _x;
                        } else {
                            if (!([_veh] call FADE_aaa_isVehicleAirborne)) then {
                                [_cluster] call FADE_aaa_deleteCluster;
                                FADE_aaa_clusters deleteAt _x;
                            } else {
                                [_cluster] call FADE_aaa_clusterTick;
                            };
                        };
                    } forEach (keys FADE_aaa_clusters);

                    {
                        private _id = netId _x;
                        if (_id in (keys FADE_aaa_clusters)) then { continue };
                        private _owner = "";
                        { if (isPlayer _x) exitWith { _owner = getPlayerUID _x } } forEach crew _x;
                        if (_owner != "") then {
                            private _playerClusters = 0;
                            {
                                private _cv = (FADE_aaa_clusters get _x) getOrDefault ["vehicle", objNull];
                                if (!isNull _cv) then {
                                    { if (isPlayer _y && { getPlayerUID _y == _owner }) exitWith { _playerClusters = _playerClusters + 1 } } forEach crew _cv;
                                };
                            } forEach (keys FADE_aaa_clusters);
                            if (_playerClusters >= _maxPerPlayer) then { continue };
                        };
                        private _last = missionNamespace getVariable [format ["FADE_aaa_lastDespawn_%1", _id], -1e9];
                        if ((time - _last) < _cooldown) then { continue };
                        private _cluster = [_x, _mode] call FADE_aaa_spawnClusterForVehicle;
                        if ((count (_cluster getOrDefault ["groups", []])) > 0 || { count (_cluster getOrDefault ["objects", []]) > 0 }) then {
                            FADE_aaa_clusters set [_id, _cluster];
                            [_cluster] call FADE_aaa_clusterTick;
                            if (missionNamespace getVariable ["FADE_aaa_debug", false]) then {
                                diag_log format ["[FADE AAA] cluster for %1 (%2 groups, %3 objects)", typeOf _x, count (_cluster get "groups"), count (_cluster get "objects")];
                            };
                        };
                    } forEach _active;

                    sleep (if ((count FADE_aaa_clusters) > 0) then { 3 } else { 10 });
                };
            };
        };
    };
};

call FADE_aaa_applyLevel;
