// =============================================================================
// ServerEntityRegistry.sqf  -  server netId registry for talkable civs + enemy scans
// =============================================================================
if (!isServer) exitWith {};

if (isNil "FADE_entityRegistry_byNetId") then {
    FADE_entityRegistry_byNetId = createHashMap;
};
if (isNil "FADE_entityRegistry_talkable") then {
    FADE_entityRegistry_talkable = createHashMap;
};

FADE_entityRegistry_isTalkable = {
    params ["_u"];
    !isNull _u && { alive _u } && {
        _u getVariable ["FADE_ambientCiv", false] || { _u getVariable ["FADE_baseNpcTalk", false] }
    }
};

FADE_entityRegistry_register = {
    params ["_u"];
    if (isNull _u || {!(_u isKindOf "Man")}) exitWith {};
    private _id = netId _u;
    if (_id == "") exitWith {};
    FADE_entityRegistry_byNetId set [_id, _u];
    if ([_u] call FADE_entityRegistry_isTalkable) then {
        FADE_entityRegistry_talkable set [_id, _u];
    };
};

FADE_entityRegistry_unregister = {
    params ["_u"];
    if (isNull _u) exitWith {};
    private _id = netId _u;
    FADE_entityRegistry_byNetId deleteAt _id;
    FADE_entityRegistry_talkable deleteAt _id;
};

FADE_entityRegistry_resolveNetId = {
    params [["_netId", ""]];
    if (!(_netId isEqualType "") || { _netId == "" }) exitWith { objNull };
    private _u = _netId call BIS_fnc_objectFromNetId;
    if (isNull _u) then {
        _u = FADE_entityRegistry_byNetId getOrDefault [_netId, objNull];
    };
    if (isNull _u || {!alive _u}) exitWith { objNull };
    _u
};

FADE_entityRegistry_refreshEnemyMenCount = {
    private _enemySide = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _n = 0;
    {
        if (alive _x && { _x isKindOf "CAManBase" } && { side _x == _enemySide }) then { _n = _n + 1 };
    } forEach (values FADE_entityRegistry_byNetId);
    if (_n == 0) then {
        _n = { alive _x && { side group _x == _enemySide } } count allUnits;
    };
    missionNamespace setVariable ["FADE_entityRegistry_enemyMenCount", _n];
    _n
};

// Cached registry count when available; else full-map scan (briefing / AO / Operation sizing).
FADE_getEnemyMenCount = {
    params [["_sideEnemy", east]];
    private _registryCount = missionNamespace getVariable ["FADE_entityRegistry_enemyMenCount", -1];
    if (_registryCount >= 0) exitWith { _registryCount };
    { alive _x && { side group _x == _sideEnemy } } count allUnits
};

FADE_entityRegistry_debugSpawnSideName = {
    params ["_side"];
    switch (_side) do {
        case west: { "BLUFOR" };
        case east: { "OPFOR" };
        case resistance: { "INDEP" };
        case civilian: { "CIV" };
        default { str _side };
    };
};

FADE_entityRegistry_onManCreated = {
    params ["_ent"];
    if (!(_ent isKindOf "Man") || { isPlayer _ent }) exitWith {};
    if !(missionNamespace getVariable ["FADE_spawnDebugPrint", false]) exitWith {};
    [_ent] spawn {
        params ["_u"];
        sleep 0.05;
        if (isNull _u || {!alive _u}) exitWith {};
        private _dn = getText (configFile >> "CfgVehicles" >> typeOf _u >> "displayName");
        if (_dn == "") then { _dn = typeOf _u };
        private _grid = mapGridPosition _u;
        private _msg = format [
            "SPAWN: %1 %2 @ %3",
            [side _u] call FADE_entityRegistry_debugSpawnSideName,
            _dn,
            _grid
        ];
        [_msg] remoteExec ["systemChat", 0];
    };
};

FADE_entityRegistry_install = {
    if (!isServer) exitWith {};
    if (missionNamespace getVariable ["FADE_entityRegistry_installed", false]) exitWith {};
    missionNamespace setVariable ["FADE_entityRegistry_installed", true];

    {
        if (alive _x && { _x isKindOf "Man" }) then { [_x] call FADE_entityRegistry_register };
    } forEach allUnits;

    addMissionEventHandler ["EntityCreated", {
        params ["_ent"];
        if (!(_ent isKindOf "Man")) exitWith {};
        [_ent] call FADE_entityRegistry_register;
        [_ent] call FADE_entityRegistry_onManCreated;
        [_ent] spawn {
            params ["_e"];
            sleep 0.05;
            if (!isNull _e && { alive _e }) then { [_e] call FADE_entityRegistry_register };
        };
    }];

    addMissionEventHandler ["EntityKilled", {
        params ["_unit"];
        [_unit] call FADE_entityRegistry_unregister;
    }];

    [] spawn {
        while { true } do {
            sleep 30;
            if (!isServer) exitWith {};
            call FADE_entityRegistry_refreshEnemyMenCount;
            private _stale = [];
            {
                private _id = _x;
                private _u = FADE_entityRegistry_byNetId get _id;
                if (isNull _u || {!alive _u}) then { _stale pushBack _id };
            } forEach (keys FADE_entityRegistry_byNetId);
            { FADE_entityRegistry_byNetId deleteAt _x; FADE_entityRegistry_talkable deleteAt _x } forEach _stale;
        };
    };
};

missionNamespace setVariable ["FADE_entityRegistry_register", FADE_entityRegistry_register];
missionNamespace setVariable ["FADE_entityRegistry_resolveNetId", FADE_entityRegistry_resolveNetId];
missionNamespace setVariable ["FADE_entityRegistry_install", FADE_entityRegistry_install];
missionNamespace setVariable ["FADE_getEnemyMenCount", FADE_getEnemyMenCount];

[] call FADE_entityRegistry_install;
