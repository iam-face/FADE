// =============================================================================
// FADE_VirtualGarrison.sqf -- Deferred OPFOR building garrison (server)
// =============================================================================
// Loaded from initServer after FADE_op_countEnemyMenInRadius. Registers intent
// to place units at fixed ATL positions; spawns one group when a player is
// within FADE_vgActivateRadiusM (horizontal, default 100 m) of the anchor, every
// FADE_vgPollIntervalS. Cancels if building destroyed (when building ref set).
//
// Settings hash keys (all optional except owner recommended):
//   "owner" (string)           -- FADE_vg_cancelPendingByOwner / pending counts
//   "groupsRef" (array ref)    -- pushBack group after spawn (same-array ref)
//   "anchorPos" ([x,y,z])      -- proximity center if building is objNull
//   "classPool" (strings)      -- selectRandom per slot; else mission FADE_enemyUnits
//   "facApply" (bool)          -- default true: FAC_applyEnemyScenarioToGroup
//   "ambientCombat" (bool)     -- default true: BIS_fnc_ambientAnimCombat
//   "disablePath" (bool)       -- roadblock style: disableAI PATH, MIDDLE
//   "faceToward" (pos)         -- setDir each unit toward position
//   "behaviour" / "combatMode" -- group after spawn (default AWARE / RED)
//   "barrelsRef" (array)       -- pushBack outdoor fire object when tryBarrel spawns hint
//   "tryBarrel" (bool)         -- at register: spawn outdoor fire hint before garrison activates
//   "barrelCenter" (pos)       -- BIS_fnc_findSafePos seed (required if tryBarrel)
//   "barrelRoll" (0..1)        -- random chance for hint at register (default 1)
//   "barrelClasses" (strings)  -- optional: pickRandom valid CfgVehicles class (default: MetalBarrel_burning_F)
//   "barrelMinDistPlayersM"    -- skip hint if any player closer (horizontal); -1 = off (missions use -1)
//   "groupApply" (code)        -- optional server code [_grp] call after fac apply
// =============================================================================

if (!isServer) exitWith {};

if (isNil "FADE_vg_pending") then { FADE_vg_pending = [] };

FADE_vg_debugMarkersEnabled = {
    missionNamespace getVariable ["FADE_vgDebugMarkers", false]
};

// Remove pending debug dot (entry key "debugMarker" = marker name).
FADE_vg_deleteDebugMarker = {
    params ["_entry"];
    if (!(_entry isEqualType createHashMap)) exitWith {};
    private _m = _entry get "debugMarker";
    if (!isNil "_m" && { _m isEqualType "" } && { _m != "" } && { getMarkerColor _m != "" }) then {
        deleteMarker _m;
    };
};

FADE_vg_buildingValid = {
    params ["_b"];
    !isNull _b && { alive _b } && { damage _b < 0.99 }
};

FADE_vg_nearestPlayerDist2D = {
    params ["_pos", ["_playerPosList", []]];
    if (count _pos < 2) exitWith { 1e15 };
    private _d = 1e15;
    if (_playerPosList isEqualTo []) then {
        {
            if (alive _x && { isPlayer _x }) then { _d = _d min (_x distance2D _pos) };
        } forEach allPlayers;
    } else {
        private _px = _pos select 0;
        private _py = _pos select 1;
        {
            if (_x isEqualType [] && { count _x >= 2 }) then {
                _d = _d min ([_px, _py] distance2D [_x select 0, _x select 1]);
            };
        } forEach _playerPosList;
    };
    _d
};

// Returns anchor position for proximity checks [x,y,z]
FADE_vg_entryAnchor = {
    params ["_entry"];
    private _b = _entry get "building";
    private _st = _entry get "settings";
    if (!isNull _b) exitWith { [getPosATL _b] call FADE_normPos3 };
    private _ap = _st getOrDefault ["anchorPos", []];
    if (_ap isEqualType [] && { count _ap >= 2 }) exitWith {
        if (count _ap < 3) then { [(_ap select 0), (_ap select 1), 0] } else { +_ap }
    };
    private _pp = _entry get "positions";
    if (_pp isEqualType [] && { count _pp > 0 }) exitWith {
        private _p0 = _pp select 0;
        if (count _p0 < 3) then { [(_p0 select 0), (_p0 select 1), 0] } else { +_p0 }
    };
    [0, 0, 0]
};

// Sum of reserved men in pending queue for owner prefix (mission / op / patrol / rb).
FADE_vg_pendingMenForOwner = {
    params ["_owner"];
    if (_owner == "") exitWith { 0 };
    private _n = 0;
    {
        private _o = (_x get "settings") getOrDefault ["owner", ""];
        if (_o == _owner) then { _n = _n + count (_x get "positions") };
    } forEach FADE_vg_pending;
    _n
};

// OPFOR men in ellipse including not-yet-spawned virtual garrisons (building anchor in radius).
FADE_vg_pendingMenInEllipse = {
    params ["_center", "_r"];
    if (count _center < 2) exitWith { 0 };
    private _cc = [_center] call FADE_normPos3;
    private _n = 0;
    {
        private _anch = [_x] call FADE_vg_entryAnchor;
        if (count _anch >= 2) then {
            if ((_anch distance2D _cc) <= _r) then {
                private _b = _x get "building";
                if (isNull _b || { [_b] call FADE_vg_buildingValid }) then {
                    _n = _n + count (_x get "positions");
                };
            };
        };
    } forEach FADE_vg_pending;
    _n
};

// Drop deferred garrison slots whose anchor lies in the zone ellipse (Operation capture).
FADE_vg_cancelPendingInEllipse = {
    params ["_center", "_r", ["_ownerMatch", ""]];
    if (count _center < 2) exitWith {};
    private _cc = [_center] call FADE_normPos3;
    FADE_vg_pending = FADE_vg_pending select {
        private _entry = _x;
        private _owner = (_entry get "settings") getOrDefault ["owner", ""];
        if (_ownerMatch != "" && { _owner != _ownerMatch }) exitWith { true };
        private _anch = [_entry] call FADE_vg_entryAnchor;
        if (count _anch >= 2 && { (_anch distance2D _cc) <= _r }) then {
            [_entry] call FADE_vg_dropEntry;
            false
        } else {
            true
        };
    };
};

FADE_vg_cancelPendingByOwner = {
    params ["_owner"];
    if (_owner == "") exitWith {};
    {
        if (((_x get "settings") getOrDefault ["owner", ""]) == _owner) then {
            [_x] call FADE_vg_dropEntry;
        };
    } forEach FADE_vg_pending;
    FADE_vg_pending = FADE_vg_pending select {
        ((_x get "settings") getOrDefault ["owner", ""]) != _owner
    };
};

// Cleanup debug marker + optional register-time outdoor hint on this pending entry.
FADE_vg_dropEntry = {
    params ["_entry"];
    if (!(_entry isEqualType createHashMap)) exitWith {};
    [_entry] call FADE_vg_deleteDebugMarker;
    private _hint = _entry getOrDefault ["outdoorHint", objNull];
    if (!isNull _hint) then { deleteVehicle _hint };
};

// Outdoor fire at FADE_vg_register (before players activate the garrison). Returns objNull if skipped/failed.
FADE_vg_spawnOutdoorHint = {
    params ["_st"];
    if (!(_st getOrDefault ["tryBarrel", false])) exitWith { objNull };
    if (random 1 > (_st getOrDefault ["barrelRoll", 1])) exitWith { objNull };

    private _bc = _st getOrDefault ["barrelCenter", []];
    if (!(_bc isEqualType []) || { count _bc < 2 }) exitWith { objNull };
    if (count _bc < 3) then { _bc = [(_bc select 0), (_bc select 1), 0] };

    private _barrelPos = [_bc] call FADE_findOutdoorHintPos;
    if (!(_barrelPos isEqualType []) || { count _barrelPos < 2 }) exitWith { objNull };
    _barrelPos = [(_barrelPos select 0), (_barrelPos select 1), (_barrelPos param [2, 0])];

    private _minPl = _st getOrDefault ["barrelMinDistPlayersM", -1];
    if (_minPl >= 0) then {
        private _tooClose = false;
        {
            if (alive _x && { isPlayer _x } && { (_x distance2D _barrelPos) < _minPl }) exitWith { _tooClose = true };
        } forEach allPlayers;
        if (_tooClose) exitWith { objNull };
    };

    private _clsList = _st getOrDefault ["barrelClasses", ["MetalBarrel_burning_F"]];
    if (!(_clsList isEqualType []) || { count _clsList == 0 }) then { _clsList = ["MetalBarrel_burning_F"] };
    private _clsPick = _clsList select { typeName _x == "STRING" && { _x != "" } && { isClass (configFile >> "CfgVehicles" >> _x) } };
    if (count _clsPick == 0) then { _clsPick = ["MetalBarrel_burning_F"] };

    private _fire = createVehicle [selectRandom _clsPick, _barrelPos, [], 0, "NONE"];
    if (isNull _fire) exitWith { objNull };
    _fire setPosATL _barrelPos;

    private _bref = _st get "barrelsRef";
    if (!isNil "_bref" && { _bref isEqualType [] }) then { _bref pushBack _fire };

    private _owner = _st getOrDefault ["owner", ""];
    if (_owner find "mis:" == 0) then { [_owner select [4], _fire] call FADE_missionEnt_registerObject };
    if (_owner find "op:" == 0) then { [_owner select [3], _fire] call FADE_missionEnt_registerObject };

    _fire
};

// _building may be objNull if settings "anchorPos" is set.
// _positions: array of ATL positions; _classPool optional (per-slot or random).
FADE_vg_register = {
    params ["_building", "_positions", ["_classPool", []], ["_settings", nil]];
    if (!isServer) exitWith { -1 };
    if (!(_positions isEqualType []) || { count _positions == 0 }) exitWith { -1 };
    private _st = if (!isNil "_settings" && { _settings isEqualType createHashMap }) then { _settings } else { createHashMap };
    if (isNull _building && { count (_st getOrDefault ["anchorPos", []]) < 2 }) exitWith { -1 };

    private _id = missionNamespace getVariable ["FADE_vg_nextId", 1];
    missionNamespace setVariable ["FADE_vg_nextId", _id + 1];

    private _entry = createHashMap;
    _entry set ["id", _id];
    _entry set ["building", _building];
    _entry set ["positions", +_positions];
    _entry set ["classPool", +_classPool];
    _entry set ["settings", _st];
    FADE_vg_pending pushBack _entry;

    if ([] call FADE_vg_debugMarkersEnabled) then {
        private _anch = [_entry] call FADE_vg_entryAnchor;
        if (count _anch >= 2) then {
            private _mn = format ["FADE_vg_dbg_%1_%2", _id, floor (random 1e6)];
            [_mn, [(_anch select 0), (_anch select 1)], ""] call FADE_createRegisteredMarker;
            _mn setMarkerType "mil_dot";
            _mn setMarkerColor "ColorYellow";
            _mn setMarkerAlpha 0.85;
            _entry set ["debugMarker", _mn];
        };
    };

    // Occupancy hint: fire outside the building when registered, not when garrison activates.
    private _hint = [_st] call FADE_vg_spawnOutdoorHint;
    if (!isNull _hint) then { _entry set ["outdoorHint", _hint] };

    _id
};

FADE_vg_spawnOne = {
    params ["_entry"];
    private _b = _entry get "building";
    private _positions = _entry get "positions";
    private _classPool = _entry get "classPool";
    private _st = _entry get "settings";

    private _owner = _st getOrDefault ["owner", ""];
    if (_owner find "op:" == 0) then {
        private _opTid = _owner select [3];
        if (missionNamespace getVariable ["FADE_operationAborted_" + _opTid, false]) exitWith {};
    };
    if (_owner find "mis:" == 0) then {
        private _misTid = _owner select [4];
        if (missionNamespace getVariable [format ["FADE_missionEnt_cleaned_%1", _misTid], false]) exitWith {};
        if (missionNamespace getVariable ["FADE_invasionAborted_" + _misTid, false]) exitWith {};
        if (missionNamespace getVariable ["FADE_raidAborted_" + _misTid, false]) exitWith {};
    };
    if (_owner find "invasion:" == 0) then {
        private _invTid = _owner select [9];
        if (missionNamespace getVariable ["FADE_invasionAborted_" + _invTid, false]) exitWith {};
    };

    if (!(_positions isEqualType []) || { count _positions == 0 }) exitWith {};

    if (!isNull _b && { !([_b] call FADE_vg_buildingValid) }) exitWith {};

    [_entry] call FADE_vg_deleteDebugMarker;

    private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _enemyUnits = missionNamespace getVariable ["FADE_enemyUnits", []];
    if (_enemyUnits isEqualTo []) then {
        _enemyUnits = +(missionNamespace getVariable ["FADE_fallbackEnemyUnits", ["O_Soldier_F"]]);
    };
    private _pool = if (count _classPool > 0) then { +_classPool } else { +_enemyUnits };
    private _clsExact = (count _classPool) == (count _positions) && { count _classPool > 0 };

    private _facApply = missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}];
    if (_st getOrDefault ["facApply", true]) then { } else { _facApply = {} };

    private _grp = createGroup _sideEnemy;
    private _faceToward = _st getOrDefault ["faceToward", []];
    private _hasFace = _faceToward isEqualType [] && { count _faceToward >= 2 };

    {
        private _p = +_x;
        if (count _p < 3) then { _p set [2, 0] };
        private _cls = if (_clsExact && { _forEachIndex < count _classPool }) then {
            _classPool select _forEachIndex
        } else {
            selectRandom _pool
        };
        private _u = _grp createUnit [_cls, _p, [], 0, "NONE"];
        if (!isNull _u) then {
            _u setPosATL _p;
            if (_st getOrDefault ["disablePath", false]) then {
                _u disableAI "PATH";
                _u setUnitPos "MIDDLE";
            } else {
                _u setUnitPos "MIDDLE";
            };
            if (_hasFace) then { _u setDir ([_p, _faceToward] call BIS_fnc_dirTo) };
            if (_st getOrDefault ["ambientCombat", true]) then {
                [_u] call FADE_tryAmbientCombatAnim;
            };
        };
    } forEach _positions;

    if (isNull _grp || { count units _grp == 0 }) exitWith {
        if (!isNull _grp) then { deleteGroup _grp };
    };

    if (!(_facApply isEqualTo {})) then { [_grp] call _facApply };
    private _grpExtra = _st get "groupApply";
    if (!isNil "_grpExtra" && { typeName _grpExtra == "CODE" } && { !(_grpExtra isEqualTo {}) }) then { [_grp] call _grpExtra };

    private _beh = _st getOrDefault ["behaviour", "AWARE"];
    private _cm = _st getOrDefault ["combatMode", "RED"];
    _grp setBehaviour _beh;
    _grp setCombatMode _cm;

    private _gref = _st get "groupsRef";
    if (!isNil "_gref" && { _gref isEqualType [] }) then { _gref pushBack _grp };
    private _owner = _st getOrDefault ["owner", ""];
    if (_owner != "") then { _grp setVariable ["FADE_vgOwner", _owner, false] };
    if (_owner find "mis:" == 0) then {
        [_owner select [4], _grp] call FADE_missionEnt_registerGroup;
    };
    if (_owner find "op:" == 0) then {
        [_owner select [3], _grp] call FADE_missionEnt_registerGroup;
    };

    private _intelHook = missionNamespace getVariable ["FADE_intel_onVgSpawned", {}];
    if (!(_intelHook isEqualTo {})) then {
        [_entry, _grp, _b] call _intelHook;
    };
};

[] spawn {
    scriptName "FADE_vg_loop";
    while { true } do {
        private _pending = missionNamespace getVariable ["FADE_vg_pending", []];
        private _sleepS = if (count _pending == 0) then {
            missionNamespace getVariable ["FADE_vgPollEmptyIntervalS", 30]
        } else {
            missionNamespace getVariable ["FADE_vgPollIntervalS", 10]
        };
        sleep (_sleepS max 2);
        private _rAct = (missionNamespace getVariable ["FADE_vgActivateRadiusM", 100]) max 5;
        private _plPos = [];
        { if (alive _x && { isPlayer _x }) then { _plPos pushBack (getPosATL _x) } } forEach allPlayers;

        private _remain = [];
        {
            private _e = _x;
            private _b = _e get "building";
            private _drop = false;
            private _spawn = false;

            if (!isNull _b && { !([_b] call FADE_vg_buildingValid) }) then {
                _drop = true;
            } else {
                private _anch = [_e] call FADE_vg_entryAnchor;
                if (count _anch < 2) then {
                    _drop = true;
                } else {
                    if (([_anch, _plPos] call FADE_vg_nearestPlayerDist2D) <= _rAct) then {
                        _spawn = true;
                    };
                };
            };

            if (_drop) then {
                [_e] call FADE_vg_dropEntry;
            } else {
                if (_spawn) then {
                    [_e] call FADE_vg_spawnOne;
                } else {
                    _remain pushBack _e;
                };
            };
        } forEach FADE_vg_pending;

        FADE_vg_pending = _remain;
    };
};

// Patch Operation zone tallies: count reserved garrison not yet spawned.
private _rawCnt = missionNamespace getVariable ["FADE_op_countEnemyMenInRadius", {}];
if (!(_rawCnt isEqualTo {})) then {
    missionNamespace setVariable ["FADE_op_countEnemyMenInRadius_raw", _rawCnt];
    FADE_op_countEnemyMenInRadius = {
        params ["_center", "_r"];
        private _base = [_center, _r] call (missionNamespace getVariable "FADE_op_countEnemyMenInRadius_raw");
        _base + ([_center, _r] call FADE_vg_pendingMenInEllipse)
    };
    missionNamespace setVariable ["FADE_op_countEnemyMenInRadius", FADE_op_countEnemyMenInRadius];
};

missionNamespace setVariable ["FADE_vg_register", FADE_vg_register];
missionNamespace setVariable ["FADE_vg_cancelPendingByOwner", FADE_vg_cancelPendingByOwner];
missionNamespace setVariable ["FADE_vg_cancelPendingInEllipse", FADE_vg_cancelPendingInEllipse];
missionNamespace setVariable ["FADE_vg_pendingMenForOwner", FADE_vg_pendingMenForOwner];
missionNamespace setVariable ["FADE_vg_pendingMenInEllipse", FADE_vg_pendingMenInEllipse];
