// =============================================================================
// EnemyAAA.sqf - AAA spawning governed by Scenario GUI "Enemy AAA" level
// =============================================================================
// Server-only. Level "None": no spawns. Light/Medium/Heavy: up to 5 AA units at
// high ground near random civ zones (within 5 km, highest point, safe pos).
// MANPADS: 25% chance per active civ zone, max 2 infantry with shoulder-launched
// AA per zone, non-respawning; SAD waypoint at spawn.
// =============================================================================

if (!isServer) exitWith {};

private _scaleOpforCount = missionNamespace getVariable ["FADE_scaleOpforCount", {
    params ["_baseCount", ["_minCount", 1], ["_maxCount", -1]];
    private _base = floor (_baseCount max 0);
    if (_base <= 0) exitWith { 0 };
    private _scaled = _base max _minCount;
    if (_maxCount >= 0 && { _scaled > _maxCount }) then { _scaled = _maxCount };
    _scaled
}];

// Storage for cleanup: static/vehicle AA and MANPADS groups
FADE_aaa_units = [];           // static weapons + crew groups/objects
FADE_aaa_vehicles = [];        // AA vehicles (for delete)
FADE_aaa_manpadsZones = createHashMap;  // zoneId -> array of groups (for despawn per zone)
FADE_aaa_manpadsGroups = [];   // all MANPADS groups (for full despawn)

// Fallback classnames (vanilla East) when faction has no matching asset
FADE_aaa_fallbackStatic = "O_HMG_01_high_F";
FADE_aaa_fallbackVehicle = "O_APC_Tracked_02_AA_F";
FADE_aaa_fallbackManpads = "O_Soldier_AA_F";

// -----------------------------------------------------------------------------
// Resolve AA classnames from Scenario GUI enemy faction (config-driven).
// -----------------------------------------------------------------------------
FADE_aaa_getStaticLightClass = {
    params [["_faction", ""]];
    if (_faction == "") then { _faction = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"] };
    private _fallback = missionNamespace getVariable ["FADE_aaa_fallbackStatic", "O_HMG_01_high_F"];
    private _out = "";
    {
        private _cfg = _x;
        private _class = configName _cfg;
        if (getNumber (_cfg >> "scope") < 2) then { continue };
        if (getNumber (_cfg >> "side") != 0) then { continue };
        if (!(_class isKindOf "StaticWeapon")) then { continue };
        private _dn = toLower getText (_cfg >> "displayName");
        if ((_dn find "hmg" < 0) && { _dn find "gmg" < 0 }) then { continue };
        if (getText (_cfg >> "faction") == _faction) exitWith { _out = _class };
        if (_out == "") then { _out = _class };
    } forEach ("true" configClasses (configFile >> "CfgVehicles"));
    if (_out == "") then { _fallback } else { _out }
};

FADE_aaa_getAAVehicleClass = {
    params [["_faction", ""]];
    if (_faction == "") then { _faction = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"] };
    private _fallback = missionNamespace getVariable ["FADE_aaa_fallbackVehicle", "O_APC_Tracked_02_AA_F"];
    private _vehicles = [_faction] call FADE_getEnemyVehiclesForFaction;
    if (_vehicles isEqualTo []) exitWith { _fallback };
    private _aa = [];
    {
        private _cfg = configFile >> "CfgVehicles" >> _x;
        if (!isClass _cfg) then { continue };
        private _dn = toLower getText (_cfg >> "displayName");
        private _threat = getArray (_cfg >> "threat");
        private _airThreat = if (count _threat > 1) then { _threat select 1 } else { 0 };
        if ((_dn find "aa" >= 0) || { _airThreat > 0 }) then { _aa pushBack _x };
    } forEach _vehicles;
    if (_aa isEqualTo []) then { _vehicles select 0 } else { _aa select (floor random count _aa) }
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
            if ((_w find "titan" >= 0) || { _w find "stinger" >= 0 } || { _w find "igla" >= 0 } || { (_w find "launch_" >= 0) && { _w find "aa" >= 0 } }) exitWith {
                _manpads pushBack _x;
            };
        } forEach _weapons;
    } forEach _units;
    if (_manpads isEqualTo []) then { _fallback } else { _manpads select (floor random count _manpads) }
};

// -----------------------------------------------------------------------------
// Despawn all AAA (static, vehicles, MANPADS). Call on scenario apply or level None.
// -----------------------------------------------------------------------------
FADE_aaa_despawnAll = {
    // Groups first (so crew are removed from vehicles/statics), then objects
    {
        if (!isNull _x) then {
            if (_x isEqualType grpNull) then {
                { deleteVehicle _x } forEach units _x;
                deleteGroup _x;
            };
        };
    } forEach FADE_aaa_units;
    {
        if (!isNull _x && { _x isEqualType objNull }) then {
            deleteVehicle _x;
        };
    } forEach FADE_aaa_units;
    FADE_aaa_units = [];

    {
        if (!isNull _x) then {
            { deleteVehicle _x } forEach (crew _x);
            deleteVehicle _x;
        };
    } forEach FADE_aaa_vehicles;
    FADE_aaa_vehicles = [];

    {
        if (!isNull _x) then {
            { deleteVehicle _x } forEach units _x;
            deleteGroup _x;
        };
    } forEach FADE_aaa_manpadsGroups;
    FADE_aaa_manpadsGroups = [];
    FADE_aaa_manpadsZones = createHashMap;
};

// -----------------------------------------------------------------------------
// Despawn MANPADS for one zone (when civ zone despawns).
// -----------------------------------------------------------------------------
FADE_aaa_despawnManpadsInZone = {
    params ["_zoneId"];
    private _groups = FADE_aaa_manpadsZones get _zoneId;
    if (isNil "_groups" || { !(_groups isEqualType []) }) exitWith {};
    {
        if (!isNull _x) then {
            { deleteVehicle _x } forEach units _x;
            deleteGroup _x;
            FADE_aaa_manpadsGroups = FADE_aaa_manpadsGroups - [_x];
        };
    } forEach _groups;
    FADE_aaa_manpadsZones deleteAt _zoneId;
};

// -----------------------------------------------------------------------------
// Find a safe spawn position within _radius of _center (no water, clear of objects).
// Uses BIS_fnc_findSafePos so not in building etc. Returns [x,y,z] or _center on fail.
// -----------------------------------------------------------------------------
FADE_aaa_findSafeSpawnInRadius = {
    params ["_center", ["_radius", 500]];
    if (count _center < 2) exitWith { _center };
    private _flat = [_center, 20, _radius, 8, 0, 0.4, 0, [], _center] call BIS_fnc_findSafePos;
    if (_flat isEqualType [] && { count _flat >= 2 }) then {
        if (count _flat < 3) then { _flat set [2, 0] };
        _flat
    } else {
        _center
    };
};

// -----------------------------------------------------------------------------
// Spawn one Light AA: static HMG + one gunner (scenario enemy units).
// -----------------------------------------------------------------------------
FADE_aaa_spawnLight = {
    params ["_pos"];
    private _se = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _faction = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
    private _staticClass = [_faction] call FADE_aaa_getStaticLightClass;
    if (!isClass (configFile >> "CfgVehicles" >> _staticClass)) exitWith {};
    private _enemyUnits = missionNamespace getVariable ["FADE_enemyUnits", ["O_Soldier_F"]];
    if (_enemyUnits isEqualTo []) exitWith {};
    private _gunnerClass = _enemyUnits select 0;
    private _static = createVehicle [_staticClass, _pos, [], 0, "NONE"];
    if (isNull _static) exitWith {};
    private _base = missionNamespace getVariable ["BASE_1", objNull];
    private _dir = if (!isNull _base) then { _pos getDir (getPosATL _base) } else { random 360 };
    _static setDir _dir;
    private _grp = createGroup _se;
    private _gunner = _grp createUnit [_gunnerClass, _pos, [], 0, "NONE"];
    if (isNull _gunner) then {
        deleteVehicle _static;
        deleteGroup _grp;
    } else {
        _gunner moveInGunner _static;
        _gunner setSkill (missionNamespace getVariable ["FADE_enemySkill", 0.2]);
        private _routing = missionNamespace getVariable ["FADE_enemyRouting", 0];
        _grp setVariable ["FADE_allowFleeing", _routing];
        _grp allowFleeing _routing;
        FADE_aaa_units pushBack _static;
        FADE_aaa_units pushBack _grp;
        if (!isNil "FADE_applyOpforLauncherPolicyToUnit") then {
            { [_x] call FADE_applyOpforLauncherPolicyToUnit } forEach units _grp;
        };
    };
};

// -----------------------------------------------------------------------------
// Spawn one Medium AA: emplaced vehicle (no waypoints). Crew from scenario enemy.
// -----------------------------------------------------------------------------
FADE_aaa_spawnMedium = {
    params ["_pos"];
    private _se = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _faction = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
    private _vehClass = [_faction] call FADE_aaa_getAAVehicleClass;
    if (!isClass (configFile >> "CfgVehicles" >> _vehClass)) exitWith {};
    private _enemyUnits = missionNamespace getVariable ["FADE_enemyUnits", ["O_Soldier_F"]];
    if (count _enemyUnits < 3) then { _enemyUnits = _enemyUnits + [_enemyUnits select 0] + [_enemyUnits select 0] };
    private _veh = createVehicle [_vehClass, _pos, [], 0, "NONE"];
    if (isNull _veh) exitWith {};
    private _base = missionNamespace getVariable ["BASE_1", objNull];
    private _dir = if (!isNull _base) then { _pos getDir (getPosATL _base) } else { random 360 };
    _veh setDir _dir;
    private _grp = createGroup _se;
    private _driver = _grp createUnit [(_enemyUnits select 0), _pos, [], 0, "NONE"];
    private _gunner = _grp createUnit [(_enemyUnits select (1 min (count _enemyUnits - 1))), _pos, [], 0, "NONE"];
    private _commander = _grp createUnit [(_enemyUnits select (2 min (count _enemyUnits - 1))), _pos, [], 0, "NONE"];
    _driver moveInDriver _veh;
    _gunner moveInGunner _veh;
    _commander moveInCommander _veh;
    { _x setSkill (missionNamespace getVariable ["FADE_enemySkill", 0.2]) } forEach units _grp;
    _grp allowFleeing (missionNamespace getVariable ["FADE_enemyRouting", 0]);
    FADE_aaa_vehicles pushBack _veh;
    FADE_aaa_units pushBack _grp;
    if (!isNil "FADE_applyOpforLauncherPolicyToUnit") then {
        { [_x] call FADE_applyOpforLauncherPolicyToUnit } forEach units _grp;
    };
};

// -----------------------------------------------------------------------------
// Spawn one Heavy AA: vehicle with SAD waypoint at spawn (roving).
// -----------------------------------------------------------------------------
FADE_aaa_spawnHeavy = {
    params ["_pos"];
    private _se = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _faction = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
    private _vehClass = [_faction] call FADE_aaa_getAAVehicleClass;
    if (!isClass (configFile >> "CfgVehicles" >> _vehClass)) exitWith {};
    private _enemyUnits = missionNamespace getVariable ["FADE_enemyUnits", ["O_Soldier_F"]];
    if (count _enemyUnits < 3) then { _enemyUnits = _enemyUnits + [_enemyUnits select 0] + [_enemyUnits select 0] };
    private _veh = createVehicle [_vehClass, _pos, [], 0, "NONE"];
    if (isNull _veh) exitWith {};
    private _base = missionNamespace getVariable ["BASE_1", objNull];
    private _dir = if (!isNull _base) then { _pos getDir (getPosATL _base) } else { random 360 };
    _veh setDir _dir;
    private _grp = createGroup _se;
    private _driver = _grp createUnit [(_enemyUnits select 0), _pos, [], 0, "NONE"];
    private _gunner = _grp createUnit [(_enemyUnits select (1 min (count _enemyUnits - 1))), _pos, [], 0, "NONE"];
    private _commander = _grp createUnit [(_enemyUnits select (2 min (count _enemyUnits - 1))), _pos, [], 0, "NONE"];
    _driver moveInDriver _veh;
    _gunner moveInGunner _veh;
    _commander moveInCommander _veh;
    { _x setSkill (missionNamespace getVariable ["FADE_enemySkill", 0.2]) } forEach units _grp;
    _grp allowFleeing (missionNamespace getVariable ["FADE_enemyRouting", 0]);
    private _wp = _grp addWaypoint [_pos, 0];
    _wp setWaypointType "SAD";
    FADE_aaa_vehicles pushBack _veh;
    FADE_aaa_units pushBack _grp;
    if (!isNil "FADE_applyOpforLauncherPolicyToUnit") then {
        { [_x] call FADE_applyOpforLauncherPolicyToUnit } forEach units _grp;
    };
};

// -----------------------------------------------------------------------------
// Spawn up to 5 AA units (Light/Medium/Heavy): pick 5 random civ zones, for each
// find safe pos within 500 m of civ center (no building/water), spawn one unit.
// -----------------------------------------------------------------------------
FADE_aaa_spawnAll = {
    private _level = missionNamespace getVariable ["FADE_enemyAAALevel", "None"];
    if (_level == "None") exitWith {};

    if (_level != "Light" && { _level != "Medium" } && { _level != "Heavy" }) exitWith {};

    private _triggerNames = missionNamespace getVariable ["FADE_civTriggerNames", []];
    if (_triggerNames isEqualTo []) exitWith {};

    private _max = [5, 1] call _scaleOpforCount;
    private _spawnFnc = switch (_level) do {
        case "Light": { FADE_aaa_spawnLight };
        case "Medium": { FADE_aaa_spawnMedium };
        case "Heavy": { FADE_aaa_spawnHeavy };
        default { {} };
    };
    if (_spawnFnc isEqualTo {}) exitWith {};

    private _shuffled = _triggerNames call BIS_fnc_arrayShuffle;
    private _toUse = _shuffled select [0, (_max min count _shuffled)];
    {
        private _trig = missionNamespace getVariable [_x, objNull];
        if (!isNull _trig) then {
            private _center = getPosATL _trig;
            if (count _center >= 2) then {
                private _spawnPos = [_center, 500] call FADE_aaa_findSafeSpawnInRadius;
                [_spawnPos] call _spawnFnc;
            };
        };
    } forEach _toUse;
};

// -----------------------------------------------------------------------------
// Apply AAA level: despawn all, then spawn static/vehicle if Light/Medium/Heavy.
// MANPADS are spawned per-zone when zone activates (FADE_aaa_maybeSpawnManpadsInZone).
// -----------------------------------------------------------------------------
FADE_aaa_applyLevel = {
    call FADE_aaa_despawnAll;
    private _level = missionNamespace getVariable ["FADE_enemyAAALevel", "None"];
    if (_level in ["Light", "Medium", "Heavy"]) then {
        call FADE_aaa_spawnAll;
    };
};

// -----------------------------------------------------------------------------
// MANPADS: 25% chance to spawn in this (active) civ zone; max 2 units, non-respawning.
// Give SAD waypoint at _center. Call from AmbientCivilians when zone activates.
// -----------------------------------------------------------------------------
FADE_aaa_maybeSpawnManpadsInZone = {
    params ["_zoneId", "_center"];
    private _level = missionNamespace getVariable ["FADE_enemyAAALevel", "None"];
    if (_level != "MANPADS") exitWith {};
    if (!(isNil { FADE_aaa_manpadsZones get _zoneId })) exitWith {};  // already decided/spawned for this zone
    if (random 1 > 0.25) exitWith {
        FADE_aaa_manpadsZones set [_zoneId, []];  // mark as "no spawn" so we don't roll again
    };

    private _faction = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
    private _unitClass = [_faction] call FADE_aaa_getManpadsUnitClass;
    if (!isClass (configFile >> "CfgVehicles" >> _unitClass)) then { _unitClass = missionNamespace getVariable ["FADE_aaa_fallbackManpads", "O_Soldier_AA_F"] };

    private _count = [2, 1] call _scaleOpforCount;
    private _groups = [];
    private _grp = createGroup (missionNamespace getVariable ["FADE_sideEnemy", east]);
    for "_i" from 0 to (_count - 1) do {
        private _pos = [_center, 0, 30, 4, 0, 0.3, 0, [], _center] call BIS_fnc_findSafePos;
        if (count _pos < 2) then { _pos = _center };
        if (count _pos < 3) then { _pos set [2, 0] };
        private _u = _grp createUnit [_unitClass, _pos, [], 0, "NONE"];
        if (!isNull _u) then { _u setSkill (missionNamespace getVariable ["FADE_enemySkill", 0.2]) };
    };
    if (count units _grp > 0) then {
        { _x setSkill (missionNamespace getVariable ["FADE_enemySkill", 0.2]) } forEach units _grp;
        _grp allowFleeing (missionNamespace getVariable ["FADE_enemyRouting", 0]);
        private _wp = _grp addWaypoint [_center, 0];
        _wp setWaypointType "SAD";
        _groups pushBack _grp;
        FADE_aaa_manpadsGroups pushBack _grp;
        FADE_aaa_manpadsZones set [_zoneId, _groups];
        if (!isNil "FADE_applyOpforLauncherPolicyToUnit") then {
            { [_x] call FADE_applyOpforLauncherPolicyToUnit } forEach units _grp;
        };
    } else {
        deleteGroup _grp;
        FADE_aaa_manpadsZones set [_zoneId, []];
    };
};

// -----------------------------------------------------------------------------
// Init: apply current level (e.g. after mission load or first run).
// -----------------------------------------------------------------------------
call FADE_aaa_applyLevel;
