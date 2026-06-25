// =============================================================================
// EnemyAAA.sqf - dynamic AAA around airborne player aircraft
// =============================================================================
// Modes:
// - Off
// - AAA (3 static AA threats)
// - AAA+MANPADS (mix of static + AA specialist + AT/RPG infantry threats)
// Spawn trigger: player-controlled airborne Air vehicles only.
// Spawn geometry: relative bearings [0, 120, 200], 1500-2000m (wider on retries if exclusions bite).
// Exclusions: no spawn within 200m of any human player; none within 1500m of FADE_basePos / BASE_1.
// Height bias: each point snaps to highest terrain in 500m around raw point.
// =============================================================================

if (!isServer) exitWith {};

FADE_aaa_fallbackStatic = "O_HMG_01_high_F";
FADE_aaa_fallbackManpads = "O_Soldier_AA_F";
FADE_aaa_clusters = createHashMap; // vehicleNetId -> hashMap(cluster state)

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

// Returns a static weapon classname for the given enemy faction. Prefers, in order:
//   1) Faction-tagged static whose displayName matches the heuristic (HMG / GMG / AA).
//   2) Any faction-tagged static (side-correct).
//   3) Heuristic-matched static of any side-correct faction (cross-faction borrow).
//   4) FADE_aaa_fallbackStatic as a last resort (CSAT HMG, only when no side-correct static exists).
// This avoids silently picking a CSAT turret when the chosen OPFOR faction has none whose
// displayName mentions HMG/GMG/AA  -  a previous bug where mod factions defaulted to CSAT.
FADE_aaa_getStaticLightClass = {
    params [["_faction", ""]];
    if (_faction == "") then { _faction = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"] };
    private _fallback = missionNamespace getVariable ["FADE_aaa_fallbackStatic", "O_HMG_01_high_F"];
    private _wantSide = [_faction, 0] call (missionNamespace getVariable ["FADE_getFactionSideNum", { 0 }]);
    private _factionHeuristic = "";
    private _factionAny = "";
    private _otherHeuristic = "";
    {
        private _cfg = _x;
        private _class = configName _cfg;
        if (getNumber (_cfg >> "scope") < 2) then { continue };
        if (getNumber (_cfg >> "side") != _wantSide) then { continue };
        if (!(_class isKindOf "StaticWeapon")) then { continue };
        private _dn = toLower getText (_cfg >> "displayName");
        private _matchesHeuristic = (_dn find "hmg" >= 0) || { _dn find "gmg" >= 0 } || { _dn find "aa" >= 0 };
        private _isFaction = getText (_cfg >> "faction") == _faction;
        if (_isFaction && _matchesHeuristic) exitWith { _factionHeuristic = _class };
        if (_isFaction && _factionAny == "") then { _factionAny = _class };
        if (_matchesHeuristic && _otherHeuristic == "") then { _otherHeuristic = _class };
    } forEach ("true" configClasses (configFile >> "CfgVehicles"));
    if (_factionHeuristic != "") exitWith { _factionHeuristic };
    if (_factionAny != "") exitWith { _factionAny };
    if (_otherHeuristic != "") exitWith { _otherHeuristic };
    _fallback
};

FADE_aaa_getManpadsUnitClass = {
    params [["_faction", ""]];
    if (_faction == "") then { _faction = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"] };
    private _fallback = missionNamespace getVariable ["FADE_aaa_fallbackManpads", "O_Soldier_AA_F"];
    private _units = [_faction, 0] call FADE_getUnitsForFaction;
    if (_units isEqualTo []) exitWith { _fallback };
    private _manpads = [];
    {
        private _cfg = configFile >> "CfgVehicles" >> _x;
        if (!isClass _cfg || { !(_x isKindOf "Man") }) then { continue };
        private _weapons = getArray (_cfg >> "weapons");
        {
            private _w = toLower _x;
            if ((_w find "titan_aa" >= 0) || { _w find "stinger" >= 0 } || { _w find "igla" >= 0 } || { (_w find "launch_" >= 0) && { _w find "aa" >= 0 } }) exitWith {
                _manpads pushBack _x;
            };
        } forEach _weapons;
    } forEach _units;
    if (_manpads isEqualTo []) then { _fallback } else { _manpads select (floor random (count _manpads)) }
};

FADE_aaa_getATUnitClass = {
    params [["_faction", ""]];
    if (_faction == "") then { _faction = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"] };
    private _units = [_faction, 0] call FADE_getUnitsForFaction;
    private _fallbackUnits = missionNamespace getVariable ["FADE_enemyUnits", ["O_Soldier_LAT_F"]];
    if (_units isEqualTo []) then { _units = +_fallbackUnits };
    private _candidates = [];
    {
        private _cfg = configFile >> "CfgVehicles" >> _x;
        if (!isClass _cfg || { !(_x isKindOf "Man") }) then { continue };
        private _weapons = getArray (_cfg >> "weapons");
        private _isAT = false;
        {
            private _w = toLower _x;
            if ((_w find "launch_" >= 0) && { (_w find "aa" < 0) && { _w find "stinger" < 0 } && { _w find "igla" < 0 } && { _w find "titan_aa" < 0 } }) exitWith {
                _isAT = true;
            };
        } forEach _weapons;
        if (_isAT) then { _candidates pushBack _x };
    } forEach _units;
    if (_candidates isEqualTo []) then { _fallbackUnits select 0 } else { _candidates select (floor random (count _candidates)) }
};

FADE_aaa_isVehicleAirborne = {
    params ["_veh"];
    if (isNull _veh || { !alive _veh }) exitWith { false };
    if !(_veh isKindOf "Air") exitWith { false };
    private _alt = (getPosATL _veh) select 2;
    (_alt > 20) && { !isTouchingGround _veh }
};

FADE_aaa_getAirbornePlayerVehicles = {
    private _out = [];
    {
        if (!isPlayer _x) then { continue };
        if (!alive _x) then { continue };
        private _veh = vehicle _x;
        if (_veh == _x) then { continue };
        if ([_veh] call FADE_aaa_isVehicleAirborne) then {
            _out pushBackUnique _veh;
        };
    } forEach allPlayers;
    _out
};

FADE_aaa_findHighestPointInRadius = {
    params ["_center", ["_radius", 500]];
    private _best = +_center;
    if (count _best < 3) then { _best set [2, 0] };
    private _bestH = getTerrainHeightASL _best;
    for "_ring" from 1 to 3 do {
        private _r = (_radius / 3) * _ring;
        for "_a" from 0 to 330 step 30 do {
            private _p = [(_center select 0) + ((sin _a) * _r), (_center select 1) + ((cos _a) * _r), 0];
            if (surfaceIsWater _p) then { continue };
            private _h = getTerrainHeightASL _p;
            if (_h > _bestH) then {
                _bestH = _h;
                _best = _p;
            };
        };
    };
    if (surfaceIsWater _best) then { _best = +_center };
    _best set [2, 0];
    _best
};

// HQ / base centre for exclusion radius (same source as civ patrol logic).
FADE_aaa_getBasePos = {
    private _bp = missionNamespace getVariable ["FADE_basePos", []];
    if (count _bp >= 2) exitWith { _bp };
    private _o = missionNamespace getVariable ["BASE_1", objNull];
    if (!isNull _o) exitWith { getPosATL _o };
    []
};

// True if _pos may host AAA/MANPADS: >=1500m from base, >=200m from every human player.
FADE_aaa_spawnPosAllowed = {
    params ["_pos"];
    if (count _pos < 2) exitWith { false };
    private _base = [] call FADE_aaa_getBasePos;
    if (count _base >= 2 && { (_pos distance2D _base) < 1500 }) exitWith { false };
    if ({ alive _x && { (_pos distance2D _x) < 200 } } count allPlayers > 0) exitWith { false };
    true
};

FADE_aaa_pickSpawnPos = {
    params ["_originVeh", "_bearingOffset"];
    private _baseDir = getDir _originVeh;
    private _result = [];
    for "_attempt" from 0 to 39 do {
        private _bearing = _bearingOffset;
        private _dist = 1500 + random 500;
        if (_attempt > 0) then { _bearing = _bearingOffset + (random 161) - 80 };
        if (_attempt > 22) then { _dist = 1750 + random 750 };
        if (_attempt > 32) then { _dist = 2000 + random 1000 };
        private _raw = _originVeh getPos [_dist, _baseDir + _bearing];
        private _peak = [_raw, 500] call FADE_aaa_findHighestPointInRadius;
        private _safe = [[_peak, 10, 60, 6, 0, 0.4, 0, [], _peak], _peak] call FADE_findSafePosArray;
        private _cand = if (_safe isEqualType [] && { count _safe >= 2 }) then {
            if (count _safe < 3) then { _safe set [2, 0] };
            _safe
        } else {
            _peak
        };
        if ([_cand] call FADE_aaa_spawnPosAllowed) then {
            _result = _cand;
        };
        if (count _result >= 2) exitWith {};
    };
    _result
};

FADE_aaa_applyGroupPolicy = {
    params ["_grp"];
    if (isNull _grp) exitWith {};
    private _skill = missionNamespace getVariable ["FADE_enemySkill", 0.2];
    private _routing = missionNamespace getVariable ["FADE_enemyRouting", 0];
    { _x setSkill _skill } forEach units _grp;
    _grp setVariable ["FADE_allowFleeing", _routing];
    _grp allowFleeing _routing;
    if (!isNil "FADE_applyOpforLauncherPolicyToUnit") then {
        { [_x] call FADE_applyOpforLauncherPolicyToUnit } forEach units _grp;
    };
};

FADE_aaa_spawnStaticThreat = {
    params ["_pos"];
    private _faction = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
    private _staticClass = [_faction] call FADE_aaa_getStaticLightClass;
    if (!isClass (configFile >> "CfgVehicles" >> _staticClass)) exitWith { [[], []] };
    private _enemyUnits = missionNamespace getVariable ["FADE_enemyUnits", ["O_Soldier_F"]];
    if (_enemyUnits isEqualTo []) exitWith { [[], []] };
    private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _static = createVehicle [_staticClass, _pos, [], 0, "NONE"];
    if (isNull _static) exitWith { [[], []] };
    _static setDir (random 360);
    private _grp = createGroup _sideEnemy;
    private _gunner = _grp createUnit [_enemyUnits select 0, _pos, [], 0, "NONE"];
    if (isNull _gunner) then {
        deleteVehicle _static;
        deleteGroup _grp;
        [[], []]
    } else {
        _gunner moveInGunner _static;
        [_grp] call FADE_aaa_applyGroupPolicy;
        [[_static], [_grp]]
    };
};

FADE_aaa_spawnInfantryThreat = {
    params ["_pos", "_unitClass"];
    if (!isClass (configFile >> "CfgVehicles" >> _unitClass)) exitWith { [[], []] };
    private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _grp = createGroup _sideEnemy;
    private _u = _grp createUnit [_unitClass, _pos, [], 0, "NONE"];
    if (isNull _u) then {
        deleteGroup _grp;
        [[], []]
    } else {
        private _wp = _grp addWaypoint [_pos, 0];
        _wp setWaypointType "SAD";
        [_grp] call FADE_aaa_applyGroupPolicy;
        [[], [_grp]]
    };
};

FADE_aaa_deleteCluster = {
    params ["_cluster"];
    if (isNil "_cluster") exitWith {};
    private _groups = _cluster getOrDefault ["groups", []];
    {
        if (!isNull _x) then {
            { deleteVehicle _x } forEach units _x;
            deleteGroup _x;
        };
    } forEach _groups;
    private _objects = _cluster getOrDefault ["objects", []];
    {
        if (!isNull _x) then { deleteVehicle _x };
    } forEach _objects;
};

FADE_aaa_despawnAll = {
    {
        [_y] call FADE_aaa_deleteCluster;
    } forEach FADE_aaa_clusters;
    FADE_aaa_clusters = createHashMap;
};

// Compatibility shim: AAA no longer ties into civ-zone activation.
FADE_aaa_maybeSpawnManpadsInZone = {};
FADE_aaa_despawnManpadsInZone = {};

FADE_aaa_spawnClusterForVehicle = {
    params ["_veh", "_mode"];
    private _roles = if (_mode == "AAA+MANPADS") then {
        (["static", "manpads", "at"] call BIS_fnc_arrayShuffle)
    } else {
        ["static", "static", "static"]
    };
    private _bearings = [0, 120, 200];
    private _faction = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
    private _manpadsClass = [_faction] call FADE_aaa_getManpadsUnitClass;
    private _atClass = [_faction] call FADE_aaa_getATUnitClass;
    private _objects = [];
    private _groups = [];
    private _center = [0, 0, 0];
    private _nSpawned = 0;
    for "_i" from 0 to 2 do {
        private _pos = [_veh, _bearings select _i] call FADE_aaa_pickSpawnPos;
        if (count _pos < 2) then { continue };
        _center = _center vectorAdd _pos;
        _nSpawned = _nSpawned + 1;
        private _role = _roles select _i;
        private _spawned = switch (_role) do {
            case "manpads": { [_pos, _manpadsClass] call FADE_aaa_spawnInfantryThreat };
            case "at": { [_pos, _atClass] call FADE_aaa_spawnInfantryThreat };
            default { [_pos] call FADE_aaa_spawnStaticThreat };
        };
        _objects append (_spawned select 0);
        _groups append (_spawned select 1);
    };
    if (_nSpawned > 0) then {
        _center = _center vectorMultiply (1 / _nSpawned);
    } else {
        _center = getPosATL _veh;
    };
    private _cluster = createHashMap;
    _cluster set ["vehicle", _veh];
    _cluster set ["spawnedAt", time];
    _cluster set ["center", _center];
    _cluster set ["objects", _objects];
    _cluster set ["groups", _groups];
    _cluster
};

FADE_aaa_applyLevel = {
    private _lvl = missionNamespace getVariable ["FADE_enemyAAALevel", "Off"];
    _lvl = [_lvl] call FADE_aaa_normalizeLevel;
    missionNamespace setVariable ["FADE_enemyAAALevel", _lvl];
    if (_lvl == "Off") then {
        call FADE_aaa_despawnAll;
    };
};

if (isNil "FADE_aaa_monitorStarted") then {
    FADE_aaa_monitorStarted = true;
    [] spawn {
        while { true } do {
            if ((allPlayers findIf { alive _x }) < 0) then {
                sleep 30;
            } else {
            private _mode = [missionNamespace getVariable ["FADE_enemyAAALevel", "Off"]] call FADE_aaa_normalizeLevel;
            if (_mode == "Off") then {
                if ((count (keys FADE_aaa_clusters)) > 0) then { call FADE_aaa_despawnAll };
                sleep 10;
            } else {
                private _activeVehicles = call FADE_aaa_getAirbornePlayerVehicles;
                private _activeNetIds = _activeVehicles apply { netId _x };

                {
                    private _id = _x;
                    private _cluster = FADE_aaa_clusters get _id;
                    private _veh = _cluster getOrDefault ["vehicle", objNull];
                    if (!(_id in _activeNetIds) || { !([_veh] call FADE_aaa_isVehicleAirborne) }) then {
                        [_cluster] call FADE_aaa_deleteCluster;
                        FADE_aaa_clusters deleteAt _id;
                    };
                } forEach (keys FADE_aaa_clusters);

                {
                    private _id = netId _x;
                    if (isNil { FADE_aaa_clusters get _id }) then {
                        private _cluster = [_x, _mode] call FADE_aaa_spawnClusterForVehicle;
                        FADE_aaa_clusters set [_id, _cluster];
                    };
                } forEach _activeVehicles;

                sleep 10;
            };
            };
        };
    };
};

call FADE_aaa_applyLevel;
