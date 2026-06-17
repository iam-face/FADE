// =============================================================================
// BaseNpcTalk.sqf — S Wordsman at base: server-spawned unit + CivTalk scroll action
// Spawn position: Eden Game Logic named BaseNPCPos (FADE_baseNpcPosMarkerName).
// No Eden soldier — only the BaseNPCPos logic should exist in mission.sqm.
// =============================================================================

// Global variable name exposed for the spawned NPC (also used by older scripts that
// referenced baseNPC_1 as a missionNamespace key — kept stable for back-compat).
if (isNil "FADE_baseNpc_globalVarName") then { FADE_baseNpc_globalVarName = "baseNPC_1" };
if (isNil "FADE_baseNpc_identityKey") then { FADE_baseNpc_identityKey = "FAC_baseNPC_wordsman" };
if (isNil "FADE_baseNpcClass") then { FADE_baseNpcClass = "C_man_1" };
if (isNil "FADE_baseNpcPosMarkerName") then { FADE_baseNpcPosMarkerName = "BaseNPCPos" };
if (isNil "FADE_baseNpcEdenPosATL") then { FADE_baseNpcEdenPosATL = [14754.169, 18.171377, 16638.416] };

FADE_baseNpc_identityCfg = {
    params ["_idKey"];
    missionConfigFile >> "CfgIdentities" >> _idKey
};

FADE_baseNpc_fnc_findLogicByEdenName = {
    params ["_edenName"];
    if (_edenName isEqualTo "") exitWith { objNull };
    private _o = missionNamespace getVariable [_edenName, objNull];
    if (!isNull _o) exitWith { _o };
    {
        if (vehicleVarName _x == _edenName) exitWith { _o = _x };
    } forEach allMissionObjects "Logic";
    if (isNull _o) then {
        {
            if ((name _x) == _edenName) exitWith { _o = _x };
        } forEach allMissionObjects "Logic";
    };
    _o
};

FADE_baseNpc_resolveSpawnData = {
    if (!isServer) exitWith { [[0, 0, 0], 0, ""] };
    private _markerName = missionNamespace getVariable ["FADE_baseNpcPosMarkerName", "BaseNPCPos"];
    private _obj = [_markerName] call FADE_baseNpc_fnc_findLogicByEdenName;
    // SQF parses "+missionNamespace" as unary + on the namespace — always parenthesize getVariable.
    private _pos = +(missionNamespace getVariable ["FADE_baseNpcEdenPosATL", [14754.169, 18.171377, 16638.416]]);
    private _dir = 0;
    private _src = "config";
    if (!isNull _obj) then {
        _pos = getPosATL _obj;
        _dir = getDir _obj;
        _src = _markerName;
    } else {
        diag_log format [
            "[BaseNpcTalk] Eden marker %1 not found — using FADE_baseNpcEdenPosATL %2",
            _markerName, _pos
        ];
    };
    [_pos, _dir, _src]
};

FADE_baseNpc_resolveUnit = {
    private _u = missionNamespace getVariable ["FADE_baseNpc_unit", objNull];
    if (!isNull _u && { alive _u }) exitWith { _u };
    private _nid = missionNamespace getVariable ["FADE_baseNpcTalk_netId", ""];
    if (_nid isEqualTo "") exitWith { objNull };
    _u = _nid call BIS_fnc_objectFromNetId;
    if (isNull _u) then {
        { if (netId _x == _nid) exitWith { _u = _x } } forEach allUnits;
    };
    _u
};

FADE_baseNpc_clientSetIdentity = {
    params [["_unit", objNull], ["_idKey", ""]];
    if (!hasInterface) exitWith {};
    if (isNull _unit || {_idKey isEqualTo ""}) exitWith {};
    private _cfg = [_idKey] call FADE_baseNpc_identityCfg;
    if (isClass _cfg) then {
        _unit setIdentity _idKey;
        private _dn = getText (_cfg >> "name");
        if (_dn != "") then { _unit setName _dn };
    };
};

FADE_baseNpc_registerUnit = {
    if (!isServer) exitWith {};
    params [["_npc", objNull], ["_from", ""]];
    if (isNull _npc) then { _npc = call FADE_baseNpc_resolveUnit };
    if (isNull _npc || {!(_npc isKindOf "Man")}) exitWith {
        diag_log format ["[BaseNpcTalk] register FAIL (%1): no unit", _from];
    };
    if (isPlayer _npc) exitWith {
        diag_log format ["[BaseNpcTalk] register FAIL (%1): refused player object", _from];
    };
    if (_npc getVariable ["FADE_baseNpcInitDone", false]) exitWith {};
    _npc setVariable ["FADE_baseNpcInitDone", true, true];
    missionNamespace setVariable ["FADE_baseNpc_initDone", true];
    missionNamespace setVariable ["FADE_baseNpc_unit", _npc, true];
    private _globalName = missionNamespace getVariable ["FADE_baseNpc_globalVarName", "baseNPC_1"];
    missionNamespace setVariable [_globalName, _npc, true];
    _npc setVariable ["FADE_baseNpcTalk", true, true];
    private _netId = netId _npc;
    missionNamespace setVariable ["FADE_baseNpcTalk_netId", _netId, true];
    publicVariable "FADE_baseNpcTalk_netId";
    private _loadout = missionNamespace getVariable ["FADE_baseNpcLoadout", []];
    if (_loadout isEqualType [] && { count _loadout >= 10 }) then {
        _npc setUnitLoadout _loadout;
    } else {
        removeAllWeapons _npc;
    };
    _npc allowDamage false;
    _npc disableAI "MOVE";
    _npc disableAI "PATH";
    _npc setUnitPos "UP";
    doStop _npc;
    private _idKey = missionNamespace getVariable ["FADE_baseNpc_identityKey", "FAC_baseNPC_wordsman"];
    private _cfg = [_idKey] call FADE_baseNpc_identityCfg;
    if (isClass _cfg) then {
        _npc setIdentity _idKey;
    } else {
        diag_log format ["[BaseNpcTalk] missionConfigFile CfgIdentities %1 missing", _idKey];
    };
    [_npc, _idKey] remoteExec ["FADE_baseNpc_clientSetIdentity", 0, _npc];
    missionNamespace setVariable ["FADE_baseNpc_registered", true, true];
    publicVariable "FADE_baseNpc_registered";
    diag_log format [
        "[BaseNpcTalk] registered OK (%1) name=%2 netId=%3 pos=%4",
        _from, name _npc, _netId, getPosATL _npc
    ];
};

FADE_baseNpc_spawnAndRegister = {
    if (!isServer) exitWith { objNull };
    private _existing = call FADE_baseNpc_resolveUnit;
    if (!isNull _existing && { _existing getVariable ["FADE_baseNpcInitDone", false] }) exitWith {
        diag_log "[BaseNpcTalk] spawn skipped — already active";
        _existing
    };
    if (!isNull _existing) then { deleteVehicle _existing };

    (call FADE_baseNpc_resolveSpawnData) params ["_pos", "_dir", "_src"];
    private _class = missionNamespace getVariable ["FADE_baseNpcClass", "C_man_1"];
    if (!isClass (configFile >> "CfgVehicles" >> _class)) then {
        diag_log format ["[BaseNpcTalk] invalid class %1 — using C_man_1", _class];
        _class = "C_man_1";
    };
    // Skip findEmptyPosition: it nudges to terrain "open" spots, pushing indoor placements outside walls.
    // CAN_COLLIDE + setPosATL forces the unit to stay at the game logic's exact ATL (incl. building floors).
    private _spawnPos = +(_pos);

    private _grp = createGroup civilian;
    private _npc = _grp createUnit [_class, _spawnPos, [], 0, "CAN_COLLIDE"];
    if (isNull _npc) then {
        deleteGroup _grp;
        _npc = createAgent [_class, _spawnPos, [], 0, "CAN_COLLIDE"];
    };
    if (isNull _npc) exitWith {
        diag_log format ["[BaseNpcTalk] spawn FAIL class=%1 pos=%2 src=%3", _class, _spawnPos, _src];
        objNull
    };

    _npc setPosATL _spawnPos;
    _npc setDir _dir;
    missionNamespace setVariable ["FADE_baseNpc_spawned", true];
    diag_log format [
        "[BaseNpcTalk] spawned at %1 (src=%2) dir=%3 actualPos=%4",
        _spawnPos, _src, _dir, getPosATL _npc
    ];
    [_npc, "spawn"] call FADE_baseNpc_registerUnit;
    _npc
};

FADE_baseNpc_clientEnsureInteractOnce = {
    if (!hasInterface) exitWith { false };
    private _u = call FADE_baseNpc_resolveUnit;
    if (isNull _u) exitWith { false };
    if (isNil "FAC_ensureCivTalkGui") then {
        call compile preprocessFileLineNumbers "rsc\FAC_ClientGuiEnsure.sqf";
    };
    if (!isNil "FAC_ensureCivTalkGui") then { call FAC_ensureCivTalkGui };
    private _idKey = missionNamespace getVariable ["FADE_baseNpc_identityKey", "FAC_baseNPC_wordsman"];
    [_u, _idKey] call FADE_baseNpc_clientSetIdentity;
    private _fn = missionNamespace getVariable ["FADE_civTalk_addLocalAction", {}];
    if !(_fn isEqualType {}) exitWith {
        diag_log "[BaseNpcTalk] clientEnsureInteract: FADE_civTalk_addLocalAction missing";
        false
    };
    [_u] call _fn;
    if (!isNil "ace_interact_menu_fnc_createAction" && {!(_u getVariable ["FADE_baseNpc_aceAdded", false])}) then {
        private _aceAct = [
            "FADE_base_npc_talk",
            missionNamespace getVariable ["FADE_baseNpcTalkActionText", "Talk to S Wordsman"],
            "",
            {
                params ["_target", "_caller"];
                [_caller, netId _target] remoteExec ["FADE_civTalk_start", 2];
            },
            {
                params ["_target", "_caller"];
                private _maxD = missionNamespace getVariable ["FADE_civTalkMaxDistM", 6];
                alive _target && { _caller distance _target < (_maxD + 1) }
            }
        ] call ace_interact_menu_fnc_createAction;
        [_u, 0, ["ACE_MainActions"], _aceAct] call ace_interact_menu_fnc_addActionToObject;
        _u setVariable ["FADE_baseNpc_aceAdded", true, false];
    };
    true
};

FADE_baseNpc_clientEnsureInteract = {
    if (!hasInterface) exitWith {};
    if ([] call FADE_baseNpc_clientEnsureInteractOnce) exitWith {};
    if (missionNamespace getVariable ["FADE_baseNpc_clientRetryScheduled", false]) exitWith {};
    missionNamespace setVariable ["FADE_baseNpc_clientRetryScheduled", true];
    [] spawn {
        private _delays = [1, 2, 4, 8, 15];
        {
            sleep _x;
            if ([] call FADE_baseNpc_clientEnsureInteractOnce) exitWith {};
        } forEach _delays;
        missionNamespace setVariable ["FADE_baseNpc_clientRetryScheduled", false];
    };
};

// Server: if BaseNPCPos resolves after spawn, snap unit to logic ATL once.
FADE_baseNpc_serverReanchorIfNeeded = {
    if (!isServer) exitWith {};
    if (missionNamespace getVariable ["FADE_baseNpc_reanchored", false]) exitWith {};
    private _u = call FADE_baseNpc_resolveUnit;
    if (isNull _u || {!alive _u}) exitWith {};
    (call FADE_baseNpc_resolveSpawnData) params ["_pos", "_dir", "_src"];
    if (_src == "config") exitWith {};
    if ((getPosATL _u) distance2D _pos > 5) then {
        _u setPosATL _pos;
        _u setDir _dir;
        diag_log format ["[BaseNpcTalk] re-anchored to %1 (was >5m from %2)", getPosATL _u, _src];
    };
    missionNamespace setVariable ["FADE_baseNpc_reanchored", true];
};

FADE_baseNpc_postInitBootstrap = {
    if (isNil "FADE_baseNpc_spawnAndRegister") then {
        call compile preprocessFileLineNumbers "rsc\BaseNpcTalk.sqf";
    };
    if (isServer) then {
        [] call FADE_baseNpc_spawnAndRegister;
    };
    if (hasInterface) then {
        [] spawn {
            sleep 1;
            [] call FADE_baseNpc_clientEnsureInteract;
        };
    };
};
