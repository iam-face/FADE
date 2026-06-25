// =============================================================================
// RangeServer.sqf  -  server-only firing/AT range for terminalRange
// =============================================================================
if (!isServer) exitWith {};

// Session targets + time trial: Eden game logics firingRangePos_1 .. firingRangePos_210 (shared pool for pop-ups, OPFOR, vehicles).
FADE_rangeFiringPositions = [];
for "_i" from 1 to 210 do {
    private _o = missionNamespace getVariable [format ["firingRangePos_%1", _i], objNull];
    if (!isNull _o) then { FADE_rangeFiringPositions pushBack _o };
};
missionNamespace setVariable ["FADE_rangeFiringPositions", FADE_rangeFiringPositions];
missionNamespace setVariable ["FADE_rangeFiringPosCount", count FADE_rangeFiringPositions, true];
missionNamespace setVariable ["FADE_rangeHumanPosCount", count FADE_rangeFiringPositions, true];
missionNamespace setVariable ["FADE_rangeVehPosCount", count FADE_rangeFiringPositions, true];
missionNamespace setVariable ["FADE_rangeHumanUseBounds", false, true];
missionNamespace setVariable ["FADE_rangeHumanSpawnBounds", [], true];

private _gunSlots = missionNamespace getVariable ["FADE_rangeGunPosNames", []];
FADE_rangeGunSlots = [];
{
    FADE_rangeGunSlots pushBack [_x, missionNamespace getVariable [_x, objNull], objNull];
} forEach _gunSlots;
missionNamespace setVariable ["FADE_rangeGunPosCount", count FADE_rangeGunSlots, true];

private _frSlots = missionNamespace getVariable ["FADE_rangeFriendlyVehPosNames", []];
if (_frSlots isEqualTo []) then {
    _frSlots = [
        "rangeFriendlyVehPos_1", "rangeFriendlyVehPos_2", "rangeFriendlyVehPos_3",
        "rangeFriendlyVehPos_4", "rangeFriendlyVehPos_5", "rangeFriendlyVehPos_6"
    ];
};
FADE_rangeFriendlyVehSlots = [];
{
    FADE_rangeFriendlyVehSlots pushBack [_x, missionNamespace getVariable [_x, objNull], objNull];
} forEach _frSlots;
missionNamespace setVariable ["FADE_rangeFriendlyVehPosCount", count FADE_rangeFriendlyVehSlots, true];

missionNamespace setVariable ["FADE_rangeSpawnedMen", []];

FADE_rangeSessionActive = false;
FADE_rangeStarterUnit = objNull;
FADE_rangeStarterUid = "";
FADE_rangeSpawned = [];
FADE_rangeEnemyGroups = [];
FADE_rangeStarterKilledEh = [];
FADE_rangeTrialScript = scriptNull;
missionNamespace setVariable ["FADE_rangeHitTrack", false];
missionNamespace setVariable ["FADE_rangeSessionActive", false, true];
missionNamespace setVariable ["FADE_rangeSessionMode", "", true];
missionNamespace setVariable ["FADE_rangeLastResult", "", true];

FADE_rangeCleanupSpawned = {
    // Dead OPFOR are no longer in units grp  -  remove men/targets (and corpses) by tracked refs first
    private _men = missionNamespace getVariable ["FADE_rangeSpawnedMen", []];
    { if (!isNull _x) then { deleteVehicle _x } } forEach _men;
    missionNamespace setVariable ["FADE_rangeSpawnedMen", []];

    {
        if (isNull _x) then { continue };
        if (_x isEqualType grpNull) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach units _x;
            deleteGroup _x;
        } else {
            if (!isNull _x) then { deleteVehicle _x };
        };
    } forEach (missionNamespace getVariable ["FADE_rangeSpawned", []]);
    missionNamespace setVariable ["FADE_rangeSpawned", []];
    missionNamespace setVariable ["FADE_rangeEnemyGroups", []];
};

FADE_rangeVehicleClassMap = {
    private _pairs = missionNamespace getVariable ["FADE_rangeVehicleTypeMap", []];
    if (_pairs isEqualTo []) then {
        _pairs = [
            ["car", "UK3CB_CSAT_B_O_UAZ_Open"],
            ["truck", "UK3CB_CW_SOV_O_EARLY_Ural"],
            ["apc", "rhs_bmp2e_vv"],
            ["tank", "rhsgref_ins_t72bc"]
        ];
    };
    _pairs
};

FADE_rangeSelectVehicleClasses = {
    params [["_vehTypes", [true, true, true, true]]];
    private _pairs = call FADE_rangeVehicleClassMap;
    private _keys = ["car", "truck", "apc", "tank"];
    private _allowed = [];
    {
        private _idx = _forEachIndex;
        if (_vehTypes param [_idx, false]) then {
            private _key = _x;
            private _row = _pairs select { toLower (_x select 0) == _key };
            if (count _row > 0) then {
                private _cls = (_row select 0) select 1;
                if (isClass (configFile >> "CfgVehicles" >> _cls)) then { _allowed pushBack _cls };
            };
        };
    } forEach _keys;
    _allowed
};

// Logic object for firing-range UI / spawn facing (Eden: terminalRange).
FADE_rangeTerminalObj = {
    private _t = missionNamespace getVariable ["FADE_terminalRange", objNull];
    if (isNull _t) then { _t = missionNamespace getVariable ["terminalRange", objNull] };
    _t
};

FADE_rangeRegisterEntityForHitFeedback = {
    params [["_obj", objNull]];
    if (isNull _obj) exitWith {};
    private _ref = _obj;
    _obj addEventHandler ["Hit", { [_ref, _this] call FADE_sniperEhHit }];
    _obj addEventHandler ["HitPart", { [_ref, _this] call FADE_sniperEhHitPart }];
    if (_obj isKindOf "LandVehicle") then {
        _obj setVariable ["FADE_rangeVehicleDown", false, true];
        // Hit / HitPart pass damage arrays (not the vehicle). Killed passes [killed, killer, instigator, useEffects].
        _obj addEventHandler ["Hit", { _ref setVariable ["FADE_rangeVehicleDown", true, true] }];
        _obj addEventHandler ["HitPart", { _ref setVariable ["FADE_rangeVehicleDown", true, true] }];
        _obj addEventHandler ["Killed", {
            params ["_veh"];
            if (!isNull _veh) then { _veh setVariable ["FADE_rangeVehicleDown", true, true] };
        }];
    };
};

FADE_rangeSpawnHumanAt = {
    params ["_player", "_posOrObj", "_enemyType"];
    private _sessMode = missionNamespace getVariable ["FADE_rangeSessionMode", "firing"];
    private _spawned = missionNamespace getVariable ["FADE_rangeSpawned", []];
    private _enemyGroups = missionNamespace getVariable ["FADE_rangeEnemyGroups", []];
    private _menList = missionNamespace getVariable ["FADE_rangeSpawnedMen", []];
    private _pos = if (_posOrObj isEqualType [] && { count _posOrObj >= 2 }) then {
        private _z = if (count _posOrObj > 2) then { _posOrObj select 2 } else { 0.25 };
        [_posOrObj select 0, _posOrObj select 1, _z]
    } else {
        getPosATL _posOrObj
    };
    private _term = call FADE_rangeTerminalObj;
    private _dir = if (!isNull _term) then {
        _pos getDir (getPosATL _term)
    } else {
        [_pos, _player, _enemyType == "enemies"] call FADE_sniperFacingToPlayer
    };
    if (_enemyType == "targets") then {
        private _cls = missionNamespace getVariable ["FADE_sniperTargetClass", "TargetP_Inf_F"];
        if (!isClass (configFile >> "CfgVehicles" >> _cls)) then { _cls = "Target_F" };
        private _t = createVehicle [_cls, _pos, [], 0, "NONE"];
        if (!isNull _t) then {
            _t setPosATL _pos;
            _t setDir ((_dir + 180) mod 360);
            _t setVariable ["FADE_sniperVictimEnemyType", _enemyType, false];
            _t setVariable ["FADE_sniperVictimSessionKind", "range", false];
            _t setVariable ["FADE_sniperVictimSessionMode", _sessMode, false];
            [_t] call FADE_sniperRegisterSteelTarget;
            _spawned pushBack _t;
            _menList pushBack _t;
        };
    } else {
        private _enemyUnits = missionNamespace getVariable ["FADE_enemyUnits", missionNamespace getVariable ["FADE_fallbackEnemyUnits", ["O_Soldier_F"]]];
        _enemyUnits = [_enemyUnits] call FADE_filterUnitsArmed;
        if (_enemyUnits isEqualTo []) then { _enemyUnits = +(missionNamespace getVariable ["FADE_fallbackEnemyUnits", ["O_Soldier_F"]]) };
        private _grp = createGroup (missionNamespace getVariable ["FADE_sideEnemy", east]);
        private _u = _grp createUnit [selectRandom _enemyUnits, _pos, [], 0, "NONE"];
        if (isNull _u) then {
            deleteGroup _grp;
        } else {
            _u setPosATL _pos;
            _u setDir _dir;
            {
                _u disableAI _x;
            } forEach ["MOVE","PATH","TARGET","AUTOTARGET","AUTOCOMBAT","COVER","SUPPRESSION","FSM","WEAPONAIM","AIMINGERROR","CHECKVISIBLE","RADIOPROTOCOL","TEAMSWITCH","NVG","MINEDETECTION"];
            _grp allowFleeing 0;
            _grp setBehaviour "CARELESS";
            _grp setCombatMode "BLUE";
            _u setUnitPos "UP";
            _u setVariable ["FADE_sniperVictimEnemyType", _enemyType, false];
            _u setVariable ["FADE_sniperVictimSessionKind", "range", false];
            _u setVariable ["FADE_sniperVictimSessionMode", _sessMode, false];
            [_u] call FADE_rangeRegisterEntityForHitFeedback;
            _spawned pushBack _grp;
            _enemyGroups pushBack _grp;
            _menList pushBack _u;
        };
    };
    missionNamespace setVariable ["FADE_rangeSpawnedMen", _menList];
    missionNamespace setVariable ["FADE_rangeSpawned", _spawned];
    missionNamespace setVariable ["FADE_rangeEnemyGroups", _enemyGroups];
};

FADE_rangeSpawnVehicleAt = {
    params ["_posOrObj", "_allowedVehicleClasses"];
    if (_allowedVehicleClasses isEqualTo []) exitWith {};
    private _sessMode = missionNamespace getVariable ["FADE_rangeSessionMode", "firing"];
    private _spawned = missionNamespace getVariable ["FADE_rangeSpawned", []];
    private _cls = selectRandom _allowedVehicleClasses;
    private _pos = if (_posOrObj isEqualType []) then {
        if (count _posOrObj >= 2) then {
            private _z = if (count _posOrObj > 2) then { _posOrObj select 2 } else { 0 };
            [_posOrObj select 0, _posOrObj select 1, _z]
        } else { [0, 0, 0] }
    } else {
        getPosATL _posOrObj
    };
    private _veh = createVehicle [_cls, _pos, [], 0, "NONE"];
    if (isNull _veh) exitWith {};
    _veh setPosATL _pos;
    _veh setDir (random 360);
    _veh engineOn true;
    _veh setVariable ["FADE_sniperVictimEnemyType", "targets", false];
    _veh setVariable ["FADE_sniperVictimSessionKind", "range", false];
    _veh setVariable ["FADE_sniperVictimSessionMode", _sessMode, false];
    [_veh] call FADE_rangeRegisterEntityForHitFeedback;
    _spawned pushBack _veh;
    missionNamespace setVariable ["FADE_rangeSpawned", _spawned];
};

FADE_rangeEndSession = {
    params [["_player", objNull], ["_msg", "Range session ended."]];
    if (!isServer) exitWith {};
    if (!(missionNamespace getVariable ["FADE_rangeSessionActive", false])) exitWith {};
    private _rangeTermHorn = call FADE_rangeTerminalObj;
    if (!isNull _rangeTermHorn) then { ["stop", _rangeTermHorn] call FADE_cqbLoudspeakerBroadcast };
    private _starterPrev = missionNamespace getVariable ["FADE_rangeStarterUnit", objNull];

    private _tw = missionNamespace getVariable ["FADE_rangeTrialScript", scriptNull];
    if (!isNull _tw && {!scriptDone _tw}) then { terminate _tw };
    missionNamespace setVariable ["FADE_rangeTrialScript", scriptNull];

    private _kh = missionNamespace getVariable ["FADE_rangeStarterKilledEh", []];
    if (count _kh >= 2) then {
        _kh params ["_u", "_eh"];
        if (!isNull _u && {_eh >= 0}) then { _u removeEventHandler ["Killed", _eh] };
    };
    missionNamespace setVariable ["FADE_rangeStarterKilledEh", []];

    [] call FADE_rangeCleanupSpawned;
    missionNamespace setVariable ["FADE_rangeSessionActive", false, true];
    missionNamespace setVariable ["FADE_rangeSessionMode", "", true];
    missionNamespace setVariable ["FADE_rangeStarterUnit", objNull];
    missionNamespace setVariable ["FADE_rangeStarterUid", "", true];

    private _starter = if (isNull _player) then { _starterPrev } else { _player };
    [_starter] call FADE_rangeShared_disableStarterFx;
    [false] call FADE_rangeShared_setRangeHitTrack;

    if (_msg != "") then {
        if (!isNull _player) then { [_msg] remoteExec ["systemChat", _player] } else { [_msg] remoteExec ["systemChat", 0] };
    };
};

// Evenly space desired 2D distances between closest and farthest pool logics (<= _maxRangeM), then pick nearest unused firingRangePos for each  -  avoids clustering when many slots sit near the shooter.
FADE_rangePickSlotsEvenAlongRange = {
    params ["_player", "_poolObjs", "_maxRangeM", "_n"];
    if (_n <= 0) exitWith { [] };
    if (_poolObjs isEqualTo []) exitWith { [] };
    private _pairs = _poolObjs apply { [_player distance2d _x, _x] };
    _pairs sort true;
    private _m = count _pairs;
    _n = _n min _m;
    private _dLo = (_pairs select 0) select 0;
    private _dHi = (_pairs select (_m - 1)) select 0;
    _dHi = (_dHi min _maxRangeM) max _dLo;
    private _availIdx = [];
    for "_i" from 0 to (_m - 1) do { _availIdx pushBack _i };
    private _out = [];
    for "_k" from 0 to (_n - 1) do {
        private _want = if (_n == 1) then {
            (_dLo + _dHi) * 0.5
        } else {
            _dLo + ((_dHi - _dLo) * (_k / (_n - 1)))
        };
        private _bestI = -1;
        private _bestErr = 1e15;
        {
            private _idx = _x;
            private _d = (_pairs select _idx) select 0;
            private _err = abs (_d - _want);
            if (_err < _bestErr) then {
                _bestErr = _err;
                _bestI = _idx;
            };
        } forEach _availIdx;
        if (_bestI < 0) exitWith {};
        _out pushBack ((_pairs select _bestI) select 1);
        _availIdx = _availIdx select { _x != _bestI };
    };
    _out
};

FADE_rangeStartSession_impl = {
    params ["_player", "_enemyType", "_humanCount", "_vehCount", "_vehTypes", "_maxRangeM", "_trace", "_hitTrack", "_mode"];
    if (!isServer) exitWith {};
    if (isNull _player) exitWith {};
    if (missionNamespace getVariable ["FADE_rangeSessionActive", false]) exitWith { ["Range already active."] remoteExec ["systemChat", _player] };

    private _firingAll = +(missionNamespace getVariable ["FADE_rangeFiringPositions", []]);

    _humanCount = ((round _humanCount) max 0) min 40;
    _vehCount = ((round _vehCount) max 0) min 10;
    _maxRangeM = ((round _maxRangeM) max 100) min 300;

    private _allowedVeh = [_vehTypes] call FADE_rangeSelectVehicleClasses;
    if (_vehCount > 0 && {_allowedVeh isEqualTo []}) then {
        ["No enabled vehicle type class is valid in current modset."] remoteExec ["systemChat", _player];
        _vehCount = 0;
    };

    if (_humanCount == 0 && {_vehCount == 0}) exitWith {
        ["Set at least one human or vehicle target count."] remoteExec ["systemChat", _player];
    };

    private _poolInRange = _firingAll select { (_player distance2d _x) <= _maxRangeM };
    private _need = _humanCount + _vehCount;
    if (_need > 0 && { count _poolInRange == 0}) exitWith {
        ["No firingRangePos_* within your max range. Move closer or raise the distance slider."] remoteExec ["systemChat", _player];
    };

    private _avail = count _poolInRange;
    private _hCap = _humanCount min _avail;
    private _vCap = _vehCount min ((_avail - _hCap) max 0);
    if (_humanCount > _hCap || {_vehCount > _vCap}) then {
        [format [
            "Only %1 firingRangePos slot(s) within %2 m  -  spawning %3 human(s), %4 vehicle(s).",
            _avail, _maxRangeM, _hCap, _vCap
        ]] remoteExec ["systemChat", _player];
    };
    _humanCount = _hCap;
    _vehCount = _vCap;

    private _needSlots = _humanCount + _vehCount;
    private _planHumanAtl = [];
    private _planVehAtl = [];
    if (_mode == "firing" && {_needSlots > 0}) then {
        private _picked = [_player, _poolInRange, _maxRangeM, _needSlots] call FADE_rangePickSlotsEvenAlongRange;
        private _byD = _picked apply { [_player distance2d _x, _x] };
        _byD sort true;
        private _sortedPick = _byD apply { _x select 1 };
        {
            if (_forEachIndex < _humanCount) then {
                _planHumanAtl pushBack _x;
            } else {
                _planVehAtl pushBack _x;
            };
        } forEach _sortedPick;
    };

    if (_mode == "firing" && {_humanCount > 0} && {_planHumanAtl isEqualTo []}) exitWith {
        ["Could not assign human targets to firingRangePos slots."] remoteExec ["systemChat", _player];
    };
    if (_mode == "firing" && {_vehCount > 0} && {_planVehAtl isEqualTo []}) exitWith {
        ["Could not assign vehicle targets to firingRangePos slots."] remoteExec ["systemChat", _player];
    };

    missionNamespace setVariable ["FADE_rangeSessionActive", true, true];
    // String function name required (code block remoteExec is not supported / errors as "expected String").
    [] remoteExec ["FADE_rangeClient_onSessionStarted", _player];
    missionNamespace setVariable ["FADE_rangeSessionMode", _mode, true];
    missionNamespace setVariable ["FADE_rangeStarterUnit", _player];
    missionNamespace setVariable ["FADE_rangeStarterUid", getPlayerUID _player, true];
    missionNamespace setVariable ["FADE_rangeSpawned", []];
    missionNamespace setVariable ["FADE_rangeSpawnedMen", []];
    missionNamespace setVariable ["FADE_rangeEnemyGroups", []];

    [_hitTrack] call FADE_rangeShared_setRangeHitTrack;
    [_player, _trace] call FADE_rangeShared_enableStarterFx;

    private _starterKh = _player addEventHandler ["Killed", {
        if (!(missionNamespace getVariable ["FADE_rangeSessionActive", false])) exitWith {};
        [_this select 0, "Range ended: shooter down."] call FADE_rangeEndSession;
    }];
    missionNamespace setVariable ["FADE_rangeStarterKilledEh", [_player, _starterKh]];

    private _rangeTermHorn = call FADE_rangeTerminalObj;
    if (!isNull _rangeTermHorn) then { ["start", _rangeTermHorn] call FADE_cqbLoudspeakerBroadcast };

    if (_mode == "firing") then {
        if (_humanCount > 0) then {
            { [_player, _x, _enemyType] call FADE_rangeSpawnHumanAt } forEach _planHumanAtl;
        };
        if (_vehCount > 0) then {
            { [_x, _allowedVeh] call FADE_rangeSpawnVehicleAt } forEach _planVehAtl;
        };
        [format ["Range started: %1 human, %2 vehicle targets.", _humanCount, _vehCount]] remoteExec ["systemChat", _player];
    } else {
        // Time trial: same even spacing along distance band; stages sorted near→far.
        private _nTrial = _humanCount + _vehCount;
        private _trialRaw = [_player, _poolInRange, _maxRangeM, _nTrial] call FADE_rangePickSlotsEvenAlongRange;
        private _trialD = _trialRaw apply { [_player distance2d _x, _x] };
        _trialD sort true;
        private _trialPositions = _trialD apply { _x select 1 };
        private _trial = [_player, _enemyType, +_allowedVeh, _humanCount, _vehCount, _trialPositions] spawn {
            params ["_player", "_enemyType", "_allowedVeh", "_humanCount", "_vehCount", "_trialPositions"];
            private _times = [];
            private _notes = [];
            private _t0 = diag_tickTime;
            {
                if (!(missionNamespace getVariable ["FADE_rangeSessionActive", false])) exitWith {};
                private _si = _forEachIndex;
                missionNamespace setVariable ["FADE_sniperLastHitNote", ""];
                private _wantVeh = _si >= _humanCount;
                private _posObj = _x;
                private _spawnedRef = objNull;
                private _noSpawn = false;
                private _tickStart = diag_tickTime;
                if (_wantVeh) then {
                    if (_allowedVeh isEqualTo []) then {
                        _noSpawn = true;
                    } else {
                        [_posObj, _allowedVeh] call FADE_rangeSpawnVehicleAt;
                        _spawnedRef = (missionNamespace getVariable ["FADE_rangeSpawned", []]) select -1;
                    };
                } else {
                    [_player, _posObj, _enemyType] call FADE_rangeSpawnHumanAt;
                    _spawnedRef = (missionNamespace getVariable ["FADE_rangeSpawned", []]) select -1;
                };
                waitUntil {
                    sleep 0.12;
                    !(missionNamespace getVariable ["FADE_rangeSessionActive", false]) || {
                        if (_noSpawn) exitWith { true };
                        if (_spawnedRef isEqualType grpNull) then {
                            count units _spawnedRef == 0 || {!alive (leader _spawnedRef)}
                        } else {
                            isNull _spawnedRef || {
                                (_spawnedRef getVariable ["FADE_sniperDownHandled", false]) ||
                                (_spawnedRef getVariable ["FADE_rangeVehicleDown", false]) ||
                                {!alive _spawnedRef}
                            }
                        }
                    }
                };
                if (!(missionNamespace getVariable ["FADE_rangeSessionActive", false])) exitWith {};
                _times pushBack (diag_tickTime - _tickStart);
                private _n = missionNamespace getVariable ["FADE_sniperLastHitNote", ""];
                if (_n == "") then { _n = if (_wantVeh) then { "Vehicle hit" } else { "Target down" } };
                _notes pushBack _n;
                [] call FADE_rangeCleanupSpawned;
            } forEach _trialPositions;
            if (!(missionNamespace getVariable ["FADE_rangeSessionActive", false])) exitWith {};
            private _total = diag_tickTime - _t0;
            private _lines = [];
            _lines pushBack "<t size='1.05' color='#a8e6cf'>RANGE TIME TRIAL - complete</t>";
            _lines pushBack format ["<t color='#cccccc'>Total time: <t color='#ffffff'>%1 s</t></t>", str ((round (_total * 100)) / 100)];
            {
                private _idx = _forEachIndex + 1;
                private _pos = _trialPositions select _forEachIndex;
                private _distM = round (_player distance2d _pos);
                _lines pushBack format [
                    "<t color='#9fb8d4'>Target %1 (~%2m): <t color='#ffffff'>%3 s</t> - %4</t>",
                    _idx, _distM, str ((round ((_x) * 100)) / 100), _notes select _forEachIndex
                ];
            } forEach _times;
            [(_lines joinString "<br/><br/>")] remoteExec ["FADE_sniperClient_showTrialHint", _player];
            missionNamespace setVariable ["FADE_rangeLastResult", format ["Range trial done - %1 s total.", str ((round (_total * 100)) / 100)], true];
            [_player, "", false] spawn {
                params ["_p"];
                sleep 0.05;
                [_p, ""] call FADE_rangeEndSession;
            };
        };
        missionNamespace setVariable ["FADE_rangeTrialScript", _trial];
        [
            format [
                "Range time trial: %1 target(s)  -  humans first, then vehicles; distance increases each target (within your max range).",
                _nTrial
            ]
        ] remoteExec ["systemChat", _player];
    };
};

// Land vehicle classes allowed for range friendly spawn (same filter as Vehicle GUI land tab).
FADE_rangeGetSpawnableFriendlyLandClasses = {
    private _classes = +(missionNamespace getVariable ["FADE_landVehicleClasses", []]);
    if (missionNamespace getVariable ["FADE_limitGearToFriendlyFaction", false]) then {
        private _allowed = missionNamespace getVariable ["FADE_friendlyVehicleClasses", []];
        if (count _allowed > 0) then {
            _classes = _classes select { _x in _allowed };
        };
    };
    _classes
};

FADE_rangeFriendlySlotDisplay = {
    params ["_slotName"];
    private _names = missionNamespace getVariable ["FADE_rangeFriendlyVehPosNames", []];
    private _disp = missionNamespace getVariable ["FADE_rangeFriendlyVehPosDisplayNames", []];
    private _i = _names find _slotName;
    if (_i >= 0 && { count _disp > _i }) exitWith { _disp select _i };
    _slotName
};

FADE_rangeFriendlyVehSlotStatePayload = {
    private _out = [];
    {
        _x params ["_slotName", "_logicObj", "_veh"];
        private _state = "";
        if (!isNull _veh) then {
            _state = getText (configFile >> "CfgVehicles" >> (typeOf _veh) >> "displayName");
            if (_state == "") then { _state = typeOf _veh };
        };
        _out pushBack [_slotName, _state];
    } forEach (missionNamespace getVariable ["FADE_rangeFriendlyVehSlots", []]);
    _out
};

FADE_rangeBuildFriendlyLandListForClient = {
    private _rows = [];
    {
        private _cls = _x;
        if (!isClass (configFile >> "CfgVehicles" >> _cls)) then { continue };
        if (_cls isKindOf "Air") then { continue };
        if (!(_cls isKindOf "LandVehicle")) then { continue };
        private _cfg = configFile >> "CfgVehicles" >> _cls;
        private _name = getText (_cfg >> "displayName");
        if (_name == "") then { _name = _cls };
        private _faction = getText (_cfg >> "faction");
        private _factionDn = getText (configFile >> "CfgFactionClasses" >> _faction >> "displayName");
        if (_factionDn == "") then { _factionDn = _faction };
        _rows pushBack [format ["'%1' > %2", _factionDn, _name], _cls];
    } forEach (call FADE_rangeGetSpawnableFriendlyLandClasses);
    _rows sort true;
    private _seen = createHashMap;
    { _seen set [_x select 1, true] } forEach _rows;
    {
        _x params [["_label", ""], ["_cls", ""]];
        if (_cls == "" || {!isClass (configFile >> "CfgVehicles" >> _cls)}) then { continue };
        if (_seen getOrDefault [_cls, false]) then { continue };
        _seen set [_cls, true];
        if (_label == "") then {
            private _dn = getText (configFile >> "CfgVehicles" >> _cls >> "displayName");
            _label = if (_dn != "") then { _dn } else { _cls };
        };
        _rows pushBack [format ["Equipment > %1", _label], _cls];
    } forEach (missionNamespace getVariable ["FADE_rangeAtWeaponDefinitions", []]);
    _rows sort true;
    _rows
};

FADE_rangePublishAtStateTo = {
    params [["_player", objNull]];
    if (!isServer) exitWith {};
    if (isNull _player) exitWith {};
    [
        [],
        [],
        call FADE_rangeBuildFriendlyLandListForClient,
        call FADE_rangeFriendlyVehSlotStatePayload
    ] remoteExec ["FADE_rangeClient_setAtWeaponState", _player];
};

FADE_rangeRequestAtWeaponState = {
    params [["_player", objNull]];
    if (!isServer) exitWith {};
    [_player] call FADE_rangePublishAtStateTo;
};

// Spawn friendly land vehicle / equipment at rangeFriendlyVehPos_* (exact Eden logic position + heading).
FADE_rangeSpawnFriendlyLandAtSlot = {
    params [["_slotName", ""], ["_vehicleClass", ""], ["_player", objNull], ["_maxRangeM", 200]];
    if (!isServer) exitWith {};
    if (_slotName == "" || {_vehicleClass == ""}) exitWith {};
    _maxRangeM = ((round _maxRangeM) max 100) min 300;
    if (!isClass (configFile >> "CfgVehicles" >> _vehicleClass)) exitWith {
        ["Unknown vehicle class."] remoteExec ["systemChat", _player];
    };
    private _landClasses = call FADE_rangeGetSpawnableFriendlyLandClasses;
    private _extraClasses = [];
    {
        _x params ["", "_c"];
        if (_c != "" && {isClass (configFile >> "CfgVehicles" >> _c)} && {!(_c in _extraClasses)}) then { _extraClasses pushBack _c };
    } forEach (missionNamespace getVariable ["FADE_rangeAtWeaponDefinitions", []]);
    private _inLand = _vehicleClass in _landClasses;
    private _inExtra = _vehicleClass in _extraClasses;
    if (!_inLand && {!_inExtra}) exitWith {
        ["That vehicle is not in the spawn list for this scenario."] remoteExec ["systemChat", _player];
    };
    if (_vehicleClass isKindOf "Air") exitWith {
        ["Only ground equipment can spawn at range slots."] remoteExec ["systemChat", _player];
    };
    if (_inLand) then {
        if (!(_vehicleClass isKindOf "LandVehicle")) exitWith {
            ["Only ground vehicles can spawn at range slots."] remoteExec ["systemChat", _player];
        };
    } else {
        if (_vehicleClass isKindOf "Man") exitWith {
            ["Infantry units cannot spawn at equipment slots."] remoteExec ["systemChat", _player];
        };
    };
    private _slots = missionNamespace getVariable ["FADE_rangeFriendlyVehSlots", []];
    private _i = _slots findIf { (_x select 0) == _slotName };
    if (_i < 0) exitWith {};
    private _entry = _slots select _i;
    _entry params ["_sn", "_logicObj", "_existing"];
    if (isNull _logicObj) exitWith {
        [format ["Friendly vehicle slot %1 has no Eden logic.", _slotName]] remoteExec ["systemChat", _player];
    };
    if ((_player distance2d _logicObj) > _maxRangeM) exitWith {
        [format ["Friendly slot is beyond your max spawn distance (%1 m). Move closer or increase the slider.", _maxRangeM]] remoteExec ["systemChat", _player];
    };
    if (!isNull _existing) then {
        private _crew = crew _existing;
        { if (isPlayer _x) then { moveOut _x } else { _existing deleteVehicleCrew _x } } forEach _crew;
        deleteVehicle _existing;
    };
    private _pos = getPosATL _logicObj;
    private _dir = getDir _logicObj;
    private _veh = createVehicle [_vehicleClass, _pos, [], 0, "NONE"];
    if (isNull _veh) exitWith {
        [format ["Spawn failed: %1.", _vehicleClass]] remoteExec ["systemChat", _player];
    };
    _veh setPosATL _pos;
    _veh setDir _dir;
    _veh setVehicleAmmo 1;
    { _veh deleteVehicleCrew _x } forEach crew _veh;
    _slots set [_i, [_sn, _logicObj, _veh]];
    missionNamespace setVariable ["FADE_rangeFriendlyVehSlots", _slots];
    private _dn = getText (configFile >> "CfgVehicles" >> _vehicleClass >> "displayName");
    if (_dn == "") then { _dn = _vehicleClass };
    [format ["%1 spawned at %2.", _dn, [_slotName] call FADE_rangeFriendlySlotDisplay]] remoteExec ["systemChat", _player];
    [_player] call FADE_rangePublishAtStateTo;
};

FADE_rangeDespawnFriendlyLandAtSlot = {
    params [["_slotName", ""], ["_player", objNull]];
    if (!isServer) exitWith {};
    if (_slotName == "") exitWith {};
    private _slots = missionNamespace getVariable ["FADE_rangeFriendlyVehSlots", []];
    private _i = _slots findIf { (_x select 0) == _slotName };
    if (_i < 0) exitWith {};
    private _entry = _slots select _i;
    _entry params ["_sn", "_logicObj", "_veh"];
    if (!isNull _veh) then {
        private _crew = crew _veh;
        { if (isPlayer _x) then { moveOut _x } else { _veh deleteVehicleCrew _x } } forEach _crew;
        deleteVehicle _veh;
    };
    _slots set [_i, [_sn, _logicObj, objNull]];
    missionNamespace setVariable ["FADE_rangeFriendlyVehSlots", _slots];
    ["Range slot vehicle despawned."] remoteExec ["systemChat", _player];
    [_player] call FADE_rangePublishAtStateTo;
};

publicVariable "FADE_rangeEndSession";
publicVariable "FADE_rangeRequestAtWeaponState";
publicVariable "FADE_rangeSpawnFriendlyLandAtSlot";
publicVariable "FADE_rangeDespawnFriendlyLandAtSlot";
publicVariable "FADE_rangeSessionActive";
publicVariable "FADE_rangeSessionMode";
publicVariable "FADE_rangeFiringPosCount";
publicVariable "FADE_rangeHumanPosCount";
publicVariable "FADE_rangeHumanUseBounds";
publicVariable "FADE_rangeHumanSpawnBounds";
publicVariable "FADE_rangeVehPosCount";
publicVariable "FADE_rangeGunPosCount";
publicVariable "FADE_rangeFriendlyVehPosCount";
