// =============================================================================
// ServerGameplayCqb.sqf � extracted from ServerGameplay (compile via ServerGameplay.sqf)
// =============================================================================

// -----------------------------------------------------------------------------
// CQB pop-up targets: stay down on any damage (splash / indirect), sync noPop + animation to clients.
// -----------------------------------------------------------------------------
FADE_cqbBuildElapsedTimeString = {
    if (!isServer) exitWith { "0:00" };
    private _startTick = missionNamespace getVariable ["FADE_cqbDrillStartTick", diag_tickTime];
    private _elapsed = (diag_tickTime - _startTick) max 0;
    private _sec = floor _elapsed;
    private _mm = floor (_sec / 60);
    private _ss = _sec mod 60;
    private _ssStr = if (_ss < 10) then { format ["0%1", _ss] } else { str _ss };
    format ["%1:%2", _mm, _ssStr]
};

FADE_cqbTryCompleteTargetDrill = {
    if (!isServer) exitWith {};
    if (!(missionNamespace getVariable ["FADE_cqbDrillActive", false])) exitWith {};
    private _spawned = missionNamespace getVariable ["FADE_cqbSpawned", []];
    private _objs = _spawned select { !(_x isEqualType grpNull) && {!isNull _x} };
    if (_objs isEqualTo []) exitWith {};
    private _need = count _objs;
    private _got = { _x getVariable ["FADE_cqbDownHandled", false] } count _objs;
    if (_got < _need) exitWith {};
    private _p = missionNamespace getVariable ["FADE_cqbStarterUnit", objNull];
    private _timeStr = call FADE_cqbBuildElapsedTimeString;
    private _msg = format ["CQB: All %1 targets down  -  time %2.", _need, _timeStr];
    missionNamespace setVariable ["FADE_cqbLastResult", _msg, true];
    publicVariable "FADE_cqbLastResult";
    if (!isNull _p) then {
        [_p, _msg] call FADE_cqbEndDrill;
    } else {
        [objNull, _msg, true] call FADE_cqbEndDrill;
    };
};

FADE_cqbMarkTargetDown = {
    params [["_t", objNull]];
    if (!isServer) exitWith {};
    if (isNull _t) exitWith {};
    if (!(_t getVariable ["FADE_cqbIsDrillTarget", false])) exitWith {};
    if (_t getVariable ["FADE_cqbDownHandled", false]) exitWith {};
    _t setVariable ["FADE_cqbDownHandled", true, true];
    _t setVariable ["noPop", true, true];
    [_t] remoteExec ["FADE_cqbClient_forceTargetDown", 0, true];
    [] call FADE_cqbTryCompleteTargetDrill;
};

FADE_cqbRegisterTargetPersistence = {
    params ["_target"];
    if (!isServer) exitWith {};
    if (isNull _target) exitWith {};
    _target setVariable ["FADE_cqbIsDrillTarget", true, true];
    _target setVariable ["FADE_cqbDownHandled", false, true];
    _target setVariable ["noPop", true, true];
    _target addEventHandler ["Hit", { [(_this select 0)] call FADE_cqbMarkTargetDown }];
    _target addEventHandler ["Killed", { [(_this select 0)] call FADE_cqbMarkTargetDown }];
    _target addEventHandler ["HandleDamage", {
        params ["_unit", "_selection", "_damage"];
        if (_damage > 1e-3) then { [_unit] call FADE_cqbMarkTargetDown };
        _damage
    }];
};

// -----------------------------------------------------------------------------
// CQB Training Shoothouse - start/end drill (server). Called via remoteExec from CQB GUI.
// Params: [player, enemyType ("targets"|"enemies"), density ("Low"|"Medium"|"High"), civilians (bool)]
// Density: Low 20%, Medium 33%, High 50% per position. Civilians: 15% chance per spawn when true.
// Target drills: all pop-ups must stay down until reset; completion time from first spawn to last target down.
// -----------------------------------------------------------------------------
FADE_cqbStartDrill = {
    params ["_player", "_enemyType", "_density", "_civilians"];
    if (!isServer) exitWith {};
    if (missionNamespace getVariable ["FADE_cqbDrillActive", false]) exitWith {
        ["CQB drill already active. End it first."] remoteExec ["systemChat", _player];
    };
    private _positions = missionNamespace getVariable ["FADE_cqbPositions", []];
    if (_positions isEqualTo []) exitWith {
        ["No CQB positions found. Place CQB_POS_1, CQB_POS_2, ... in Eden."] remoteExec ["systemChat", _player];
    };
    private _chance = switch (_density) do {
        case "High": { 0.5 };
        case "Medium": { 0.33 };
        default { 0.2 };  // Low
    };
    private _enemyUnits = missionNamespace getVariable ["FADE_enemyUnits", missionNamespace getVariable ["FADE_fallbackEnemyUnits", ["O_Soldier_F"]]];
    _enemyUnits = [_enemyUnits] call FADE_filterUnitsArmed;
    if (_enemyUnits isEqualTo []) then { _enemyUnits = +(missionNamespace getVariable ["FADE_fallbackEnemyUnits", ["O_Soldier_F"]]) };
    private _civUnits = missionNamespace getVariable ["FADE_civUnitClasses", ["C_man_1"]];
    if (_civUnits isEqualTo []) then { _civUnits = ["C_man_1"] };
    private _targetClass = missionNamespace getVariable ["FADE_cqbTargetClass", "TargetP_Inf_F"];
    if (!isClass (configFile >> "CfgVehicles" >> _targetClass)) then { _targetClass = "Target_F" };
    missionNamespace setVariable ["noPop", true, true];
    private _spawned = [];
    private _enemyGroups = [];
    {
        if (random 1 >= _chance) then { continue };
        private _posObj = _x;
        private _pos = getPosATL _posObj;
        if (count _pos < 3) then { _pos = [_pos select 0, _pos select 1, 0] };
        private _dir = getDir _posObj;
        private _isCiv = _civilians && { random 1 < 0.15 };
        if (_enemyType == "targets") then {
            private _target = createVehicle [_targetClass, _pos, [], 0, "NONE"];
            _target setPosATL _pos;
            _target setDir (_dir + 180);
            _spawned pushBack _target;
            [_target] call FADE_cqbRegisterTargetPersistence;
        } else {
            if (_isCiv) then {
                private _civClass = selectRandom _civUnits;
                private _grp = createGroup CIVILIAN;
                private _u = _grp createUnit [_civClass, _pos, [], 0, "NONE"];
                removeAllWeapons _u;
                removeAllItems _u;
                removeHeadgear _u;
                removeGoggles _u;
                _u addGoggles "G_Blindfold_01_black_F";
                _u disableAI "PATH";
                _u setUnitPos "MIDDLE";
                _u setDir _dir;
                _u switchMove "Acts_ExecutionVictim_Loop";
                _spawned pushBack _grp;
            } else {
                private _unitClass = selectRandom _enemyUnits;
                private _grp = createGroup (missionNamespace getVariable ["FADE_sideEnemy", east]);
                private _u = _grp createUnit [_unitClass, _pos, [], 0, "NONE"];
                _u setDir _dir;
                _u disableAI "PATH";
                _u setUnitPos "MIDDLE";
                _spawned pushBack _grp;
                _enemyGroups pushBack _grp;
            };
        };
    } forEach _positions;
    missionNamespace setVariable ["FADE_cqbSpawned", _spawned];
    missionNamespace setVariable ["FADE_cqbEnemyGroups", _enemyGroups];
    missionNamespace setVariable ["FADE_cqbDrillActive", true];
    missionNamespace setVariable ["FADE_cqbDrillStartTick", diag_tickTime];
    publicVariable "FADE_cqbDrillActive";
    missionNamespace setVariable ["FADE_cqbStarterUnit", _player];
    missionNamespace setVariable ["FADE_cqbStarterUid", getPlayerUID _player];
    private _starterKh = _player addEventHandler ["Killed", {
        if (!(missionNamespace getVariable ["FADE_cqbDrillActive", false])) exitWith {};
        private _victim = _this select 0;
        if (_victim != missionNamespace getVariable ["FADE_cqbStarterUnit", objNull]) exitWith {};
        [_victim, "CQB drill ended: trainee down.", true] call FADE_cqbEndDrill;
    }];
    missionNamespace setVariable ["FADE_cqbStarterKilledEh", [_player, _starterKh]];
    ["start"] call FADE_cqbLoudspeakerBroadcast;
    // Auto-complete enemy drills when all enemy units are dead or surrendered/captive.
    private _targetObjs = _spawned select { !(_x isEqualType grpNull) && {!isNull _x} };
    if (_enemyType == "targets" && { count _targetObjs > 0 }) then {
        private _tw = missionNamespace getVariable ["FADE_cqbTargetWatcherHandle", scriptNull];
        if (!isNull _tw) then { terminate _tw };
        private _targetWatch = [_targetObjs] spawn {
            params ["_objs"];
            while { missionNamespace getVariable ["FADE_cqbDrillActive", false] } do {
                sleep 0.5;
                private _need = 0;
                private _got = 0;
                {
                    if (isNull _x) then { continue };
                    _need = _need + 1;
                    if (_x getVariable ["FADE_cqbDownHandled", false]) then { _got = _got + 1 };
                } forEach _objs;
                if (_need > 0 && _got >= _need) exitWith { [] call FADE_cqbTryCompleteTargetDrill };
            };
        };
        missionNamespace setVariable ["FADE_cqbTargetWatcherHandle", _targetWatch];
    };
    if (_enemyType == "enemies") then {
        private _existingWatcher = missionNamespace getVariable ["FADE_cqbWatcherHandle", scriptNull];
        if (!isNull _existingWatcher) then { terminate _existingWatcher };
        private _watcher = [_player] spawn {
            params ["_player"];
            while { missionNamespace getVariable ["FADE_cqbDrillActive", false] } do {
                sleep 1;
                private _groups = missionNamespace getVariable ["FADE_cqbEnemyGroups", []];
                private _remainingHostile = 0;
                {
                    if (isNull _x) then { continue };
                    {
                        if (!alive _x) then { continue };
                        // Surrendered units count as neutralised for drill completion.
                        private _isSurrendered = captive _x
                            || { _x getVariable ["ACE_isSurrendered", false] }
                            || { _x getVariable ["ace_captives_isSurrendering", false] };
                        if (!_isSurrendered) then { _remainingHostile = _remainingHostile + 1 };
                    } forEach units _x;
                } forEach _groups;
                if (_remainingHostile <= 0) exitWith {
                    if (missionNamespace getVariable ["FADE_cqbDrillActive", false]) then {
                        private _timeStr = call FADE_cqbBuildElapsedTimeString;
                        private _msg = format ["CQB: All enemy targets neutralised (dead or captive)  -  time %1.", _timeStr];
                        missionNamespace setVariable ["FADE_cqbLastResult", _msg, true];
                        publicVariable "FADE_cqbLastResult";
                        [_player, _msg] call FADE_cqbEndDrill;
                    };
                };
            };
        };
        missionNamespace setVariable ["FADE_cqbWatcherHandle", _watcher];
    };
    [format ["CQB drill started. %1 spawns.", count _spawned]] remoteExec ["systemChat", _player];
};
FADE_cqbEndDrill = {
    params ["_player", ["_msg", "CQB drill ended."], ["_broadcastAll", false]];
    if (!isServer) exitWith {};
    if (!(missionNamespace getVariable ["FADE_cqbDrillActive", false])) exitWith {};
    private _khPair = missionNamespace getVariable ["FADE_cqbStarterKilledEh", []];
    if (count _khPair >= 2) then {
        _khPair params ["_u", "_eh"];
        if (!isNull _u && {_eh >= 0}) then { _u removeEventHandler ["Killed", _eh] };
    };
    missionNamespace setVariable ["FADE_cqbStarterKilledEh", []];
    missionNamespace setVariable ["FADE_cqbStarterUnit", objNull];
    missionNamespace setVariable ["FADE_cqbStarterUid", ""];
    missionNamespace setVariable ["FADE_cqbDrillStartTick", -1];
    ["stop"] call FADE_cqbLoudspeakerBroadcast;
    private _tw = missionNamespace getVariable ["FADE_cqbTargetWatcherHandle", scriptNull];
    if (!isNull _tw) then { terminate _tw };
    missionNamespace setVariable ["FADE_cqbTargetWatcherHandle", scriptNull];
    missionNamespace setVariable ["noPop", false, true];
    private _spawned = missionNamespace getVariable ["FADE_cqbSpawned", []];
    {
        if (isNull _x) then { continue };
        if (_x isEqualType grpNull) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach units _x;
            deleteGroup _x;
        } else {
            deleteVehicle _x;
        };
    } forEach _spawned;
    missionNamespace setVariable ["FADE_cqbSpawned", []];
    missionNamespace setVariable ["FADE_cqbEnemyGroups", []];
    private _watcher = missionNamespace getVariable ["FADE_cqbWatcherHandle", scriptNull];
    if (!isNull _watcher) then { terminate _watcher };
    missionNamespace setVariable ["FADE_cqbWatcherHandle", scriptNull];
    missionNamespace setVariable ["FADE_cqbDrillActive", false];
    publicVariable "FADE_cqbDrillActive";
    if (_broadcastAll || {isNull _player}) then {
        [_msg] remoteExec ["systemChat", 0];
    } else {
        [_msg] remoteExec ["systemChat", _player];
    };
};