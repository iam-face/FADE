// =============================================================================
// RangeServer.sqf — server-only firing/AT range for terminalRange
// =============================================================================
if (!isServer) exitWith {};

FADE_rangeHumanPositions = [];
for "_i" from 1 to 64 do {
    private _o = missionNamespace getVariable [format ["shootPos_%1", _i], objNull];
    if (!isNull _o) then { FADE_rangeHumanPositions pushBack _o };
};
missionNamespace setVariable ["FADE_rangeHumanPosCount", count FADE_rangeHumanPositions, true];

FADE_rangeVehiclePositions = [];
for "_j" from 1 to 64 do {
    private _o = missionNamespace getVariable [format ["shootVehPos_%1", _j], objNull];
    if (!isNull _o) then { FADE_rangeVehiclePositions pushBack _o };
};
missionNamespace setVariable ["FADE_rangeVehPosCount", count FADE_rangeVehiclePositions, true];

private _gunSlots = missionNamespace getVariable ["FADE_rangeGunPosNames", []];
if (_gunSlots isEqualTo []) then {
    _gunSlots = ["rangeGunPos_1","rangeGunPos_2","rangeGunPos_3","rangeGunPos_4","rangeGunPos_5","rangeGunPos_6"];
};
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
missionNamespace setVariable ["FADE_rangeSessionActive", false, true];
missionNamespace setVariable ["FADE_rangeSessionMode", "", true];
missionNamespace setVariable ["FADE_rangeLastResult", "", true];

FADE_rangeCleanupSpawned = {
    // Dead OPFOR are no longer in units grp — remove men/targets (and corpses) by tracked refs first
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
    params ["_player", "_posObj", "_enemyType"];
    private _spawned = missionNamespace getVariable ["FADE_rangeSpawned", []];
    private _enemyGroups = missionNamespace getVariable ["FADE_rangeEnemyGroups", []];
    private _menList = missionNamespace getVariable ["FADE_rangeSpawnedMen", []];
    private _pos = getPosATL _posObj;
    private _dir = [getPosATL _posObj, _player, _enemyType == "enemies"] call FADE_sniperFacingToPlayer;
    if (_enemyType == "targets") then {
        private _cls = missionNamespace getVariable ["FADE_sniperTargetClass", "TargetP_Inf_F"];
        if (!isClass (configFile >> "CfgVehicles" >> _cls)) then { _cls = "Target_F" };
        private _t = createVehicle [_cls, _pos, [], 0, "NONE"];
        _t setPosATL _pos;
        _t setDir _dir;
        [_t] call FADE_sniperRegisterSteelTarget;
        _spawned pushBack _t;
        _menList pushBack _t;
    } else {
        private _enemyUnits = missionNamespace getVariable ["FADE_enemyUnits", missionNamespace getVariable ["FADE_fallbackEnemyUnits", ["O_Soldier_F"]]];
        _enemyUnits = [_enemyUnits] call FADE_filterUnitsArmed;
        if (_enemyUnits isEqualTo []) then { _enemyUnits = +(missionNamespace getVariable ["FADE_fallbackEnemyUnits", ["O_Soldier_F"]]) };
        private _grp = createGroup (missionNamespace getVariable ["FADE_sideEnemy", east]);
        private _u = _grp createUnit [selectRandom _enemyUnits, _pos, [], 0, "NONE"];
        _u setPosATL _pos;
        _u setDir _dir;
        {
            _u disableAI _x;
        } forEach ["MOVE","PATH","TARGET","AUTOTARGET","AUTOCOMBAT","COVER","SUPPRESSION","FSM","WEAPONAIM","AIMINGERROR","CHECKVISIBLE","RADIOPROTOCOL","TEAMSWITCH","NVG","MINEDETECTION"];
        _grp allowFleeing 0;
        _grp setBehaviour "CARELESS";
        _grp setCombatMode "BLUE";
        _u setUnitPos "UP";
        [_u] call FADE_rangeRegisterEntityForHitFeedback;
        _spawned pushBack _grp;
        _enemyGroups pushBack _grp;
        _menList pushBack _u;
    };
    missionNamespace setVariable ["FADE_rangeSpawnedMen", _menList];
    missionNamespace setVariable ["FADE_rangeSpawned", _spawned];
    missionNamespace setVariable ["FADE_rangeEnemyGroups", _enemyGroups];
};

FADE_rangeSpawnVehicleAt = {
    params ["_posObj", "_allowedVehicleClasses"];
    if (_allowedVehicleClasses isEqualTo []) exitWith {};
    private _spawned = missionNamespace getVariable ["FADE_rangeSpawned", []];
    private _cls = selectRandom _allowedVehicleClasses;
    private _pos = getPosATL _posObj;
    private _veh = createVehicle [_cls, _pos, [], 0, "NONE"];
    _veh setPosATL _pos;
    _veh setDir (random 360);
    _veh engineOn true;
    [_veh] call FADE_rangeRegisterEntityForHitFeedback;
    _spawned pushBack _veh;
    missionNamespace setVariable ["FADE_rangeSpawned", _spawned];
};

FADE_rangeEndSession = {
    params [["_player", objNull], ["_msg", "Range session ended."]];
    if (!isServer) exitWith {};
    if (!(missionNamespace getVariable ["FADE_rangeSessionActive", false])) exitWith {};
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
    [false, objNull, "", false, ""] call FADE_rangeShared_setSniperMirrorState;

    if (_msg != "") then {
        if (!isNull _player) then { [_msg] remoteExec ["systemChat", _player] } else { [_msg] remoteExec ["systemChat", 0] };
    };
};

FADE_rangeStartSession = {
    params ["_player", "_enemyType", "_humanCount", "_vehCount", "_vehTypes", "_maxRangeM", "_trace", "_hitTrack", "_mode"];
    if (!isServer) exitWith {};
    if (missionNamespace getVariable ["FADE_rangeSessionActive", false]) exitWith { ["Range already active."] remoteExec ["systemChat", _player] };
    if (missionNamespace getVariable ["FADE_sniperRangeActive", false]) exitWith { ["Sniper range already active. End it first."] remoteExec ["systemChat", _player] };

    private _humanPos = + (missionNamespace getVariable ["FADE_rangeHumanPositions", []]);
    private _vehPos = + (missionNamespace getVariable ["FADE_rangeVehiclePositions", []]);
    if (_humanPos isEqualTo [] && {_vehPos isEqualTo []}) exitWith { ["No range positions found in Eden."] remoteExec ["systemChat", _player] };

    _humanCount = ((round _humanCount) max 0) min 40;
    _vehCount = ((round _vehCount) max 0) min 10;
    _maxRangeM = ((round _maxRangeM) max 100) min 300;
    private _allowedVeh = [_vehTypes] call FADE_rangeSelectVehicleClasses;
    if (_vehCount > 0 && {_allowedVeh isEqualTo []}) then {
        ["No enabled vehicle type class is valid in current modset."] remoteExec ["systemChat", _player];
        _vehCount = 0;
    };

    private _humanPool = _humanPos select { (_player distance2d _x) <= _maxRangeM };
    private _vehPool = _vehPos select { (_player distance2d _x) <= _maxRangeM };
    if ((_humanCount > 0 && {_humanPool isEqualTo []}) && (_vehCount > 0 && {_vehPool isEqualTo []})) exitWith {
        [format ["No lanes within %1m.", _maxRangeM]] remoteExec ["systemChat", _player];
    };

    missionNamespace setVariable ["FADE_rangeSessionActive", true, true];
    missionNamespace setVariable ["FADE_rangeSessionMode", _mode, true];
    missionNamespace setVariable ["FADE_rangeStarterUnit", _player];
    missionNamespace setVariable ["FADE_rangeStarterUid", getPlayerUID _player, true];
    missionNamespace setVariable ["FADE_rangeSpawned", []];
    missionNamespace setVariable ["FADE_rangeSpawnedMen", []];
    missionNamespace setVariable ["FADE_rangeEnemyGroups", []];

    [true, _player, getPlayerUID _player, _hitTrack, _mode] call FADE_rangeShared_setSniperMirrorState;
    [_player, _trace] call FADE_rangeShared_enableStarterFx;

    private _starterKh = _player addEventHandler ["Killed", {
        if (!(missionNamespace getVariable ["FADE_rangeSessionActive", false])) exitWith {};
        [_this select 0, "Range ended: shooter down."] call FADE_rangeEndSession;
    }];
    missionNamespace setVariable ["FADE_rangeStarterKilledEh", [_player, _starterKh]];

    if (_mode == "firing") then {
        private _hp = +_humanPool;
        for "_i" from 1 to (_humanCount min (count _hp)) do {
            if (_hp isEqualTo []) exitWith {};
            private _ix = floor random (count _hp);
            private _pick = _hp deleteAt _ix;
            [_player, _pick, _enemyType] call FADE_rangeSpawnHumanAt;
        };
        private _vp = +_vehPool;
        for "_j" from 1 to (_vehCount min (count _vp)) do {
            if (_vp isEqualTo []) exitWith {};
            private _ix = floor random (count _vp);
            private _pick = _vp deleteAt _ix;
            [_pick, _allowedVeh] call FADE_rangeSpawnVehicleAt;
        };
        [format ["Range started: %1 human, %2 vehicle targets.", _humanCount, _vehCount]] remoteExec ["systemChat", _player];
    } else {
        private _trial = [_player, _enemyType, +_humanPool, +_vehPool, +_allowedVeh, _humanCount, _vehCount] spawn {
            params ["_player", "_enemyType", "_humanPool", "_vehPool", "_allowedVeh", "_humanCount", "_vehCount"];
            private _stages = [75,150,225,300,375,450];
            private _times = [];
            private _notes = [];
            private _t0 = diag_tickTime;
            for "_si" from 0 to 5 do {
                if (!(missionNamespace getVariable ["FADE_rangeSessionActive", false])) exitWith {};
                missionNamespace setVariable ["FADE_sniperLastHitNote", ""];
                private _wantVeh = (_vehCount > 0 && {count _vehPool > 0} && {_si mod 2 == 1});
                private _spawnedRef = objNull;
                private _tickStart = diag_tickTime;
                if (_wantVeh) then {
                    private _p = selectRandom _vehPool;
                    [_p, _allowedVeh] call FADE_rangeSpawnVehicleAt;
                    _spawnedRef = (missionNamespace getVariable ["FADE_rangeSpawned", []]) select -1;
                } else {
                    if (_humanPool isEqualTo []) then { _humanPool = +(missionNamespace getVariable ["FADE_rangeHumanPositions", []]) };
                    if !(_humanPool isEqualTo []) then {
                        private _p = selectRandom _humanPool;
                        [_player, _p, _enemyType] call FADE_rangeSpawnHumanAt;
                        _spawnedRef = (missionNamespace getVariable ["FADE_rangeSpawned", []]) select -1;
                    };
                };
                waitUntil {
                    sleep 0.12;
                    !(missionNamespace getVariable ["FADE_rangeSessionActive", false]) || {
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
            };
            if (!(missionNamespace getVariable ["FADE_rangeSessionActive", false])) exitWith {};
            private _total = diag_tickTime - _t0;
            private _lines = [];
            _lines pushBack "<t size='1.05' color='#a8e6cf'>RANGE TIME TRIAL - complete</t>";
            _lines pushBack format ["<t color='#cccccc'>Total time: <t color='#ffffff'>%1 s</t></t>", str ((round (_total * 100)) / 100)];
            {
                private _idx = _forEachIndex + 1;
                _lines pushBack format ["<t color='#9fb8d4'>Stage %1 (~%2m): <t color='#ffffff'>%3 s</t> - %4</t>", _idx, _stages select _forEachIndex, str ((round ((_x) * 100)) / 100), _notes select _forEachIndex];
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
        ["Range time trial started."] remoteExec ["systemChat", _player];
    };
};

FADE_rangeSlotStatePayload = {
    private _out = [];
    {
        _x params ["_slotName", "_logicObj", "_weaponObj"];
        private _state = "";
        if (!isNull _weaponObj) then {
            _state = getText (configFile >> "CfgVehicles" >> (typeOf _weaponObj) >> "displayName");
            if (_state == "") then { _state = typeOf _weaponObj };
        };
        _out pushBack [_slotName, _state];
    } forEach (missionNamespace getVariable ["FADE_rangeGunSlots", []]);
    _out
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
    _rows
};

FADE_rangePublishAtStateTo = {
    params [["_player", objNull]];
    if (!isServer) exitWith {};
    private _defs = missionNamespace getVariable ["FADE_rangeAtWeaponDefinitions", []];
    private _weaponList = [];
    {
        _x params [["_label", ""], ["_cls", ""]];
        if (_cls != "" && {isClass (configFile >> "CfgVehicles" >> _cls)}) then {
            private _dn = getText (configFile >> "CfgVehicles" >> _cls >> "displayName");
            if (_label == "") then { _label = if (_dn != "") then { _dn } else { _cls } };
            _weaponList pushBack [_label, _cls];
        };
    } forEach _defs;
    [
        _weaponList,
        call FADE_rangeSlotStatePayload,
        call FADE_rangeBuildFriendlyLandListForClient,
        call FADE_rangeFriendlyVehSlotStatePayload
    ] remoteExec ["FADE_rangeClient_setAtWeaponState", _player];
};

FADE_rangeRequestAtWeaponState = {
    params [["_player", objNull]];
    if (!isServer) exitWith {};
    [_player] call FADE_rangePublishAtStateTo;
};

FADE_rangeSpawnAtWeaponAtSlot = {
    params [["_slotName", ""], ["_weaponClass", ""], ["_player", objNull], ["_maxRangeM", 200]];
    if (!isServer) exitWith {};
    if (_slotName == "" || {_weaponClass == ""}) exitWith {};
    _maxRangeM = ((round _maxRangeM) max 100) min 300;
    if (!isClass (configFile >> "CfgVehicles" >> _weaponClass)) exitWith {
        ["AT weapon class is invalid in this modset."] remoteExec ["systemChat", _player];
    };
    private _slots = missionNamespace getVariable ["FADE_rangeGunSlots", []];
    private _i = _slots findIf { (_x select 0) == _slotName };
    if (_i < 0) exitWith {};
    private _entry = _slots select _i;
    _entry params ["_sn", "_logicObj", "_existing"];
    if (isNull _logicObj) exitWith {
        [format ["AT slot %1 has no Eden logic.", _slotName]] remoteExec ["systemChat", _player];
    };
    if ((_player distance2d _logicObj) > _maxRangeM) exitWith {
        [format ["AT slot is beyond your max spawn distance (%1 m). Move closer or increase the slider.", _maxRangeM]] remoteExec ["systemChat", _player];
    };
    if (!isNull _existing) then { deleteVehicle _existing };
    private _w = createVehicle [_weaponClass, getPosATL _logicObj, [], 0, "NONE"];
    _w setPosATL (getPosATL _logicObj);
    _w setDir (getDir _logicObj);
    _slots set [_i, [_sn, _logicObj, _w]];
    missionNamespace setVariable ["FADE_rangeGunSlots", _slots];
    [_player] call FADE_rangePublishAtStateTo;
};

FADE_rangeDespawnAtWeaponSlot = {
    params [["_slotName", ""], ["_player", objNull]];
    if (!isServer) exitWith {};
    if (_slotName == "") exitWith {};
    private _slots = missionNamespace getVariable ["FADE_rangeGunSlots", []];
    private _i = _slots findIf { (_x select 0) == _slotName };
    if (_i < 0) exitWith {};
    private _entry = _slots select _i;
    _entry params ["_sn", "_logicObj", "_existing"];
    if (!isNull _existing) then { deleteVehicle _existing };
    _slots set [_i, [_sn, _logicObj, objNull]];
    missionNamespace setVariable ["FADE_rangeGunSlots", _slots];
    [_player] call FADE_rangePublishAtStateTo;
};

// Spawn friendly land vehicle at rangeFriendlyVehPos_* (same placement rules as FADE_spawnLandVehicle at VEH_*).
FADE_rangeSpawnFriendlyLandAtSlot = {
    params [["_slotName", ""], ["_vehicleClass", ""], ["_player", objNull], ["_maxRangeM", 200]];
    if (!isServer) exitWith {};
    if (_slotName == "" || {_vehicleClass == ""}) exitWith {};
    _maxRangeM = ((round _maxRangeM) max 100) min 300;
    if (!(_vehicleClass in (call FADE_rangeGetSpawnableFriendlyLandClasses))) exitWith {
        ["That vehicle is not in the land spawn list for this scenario."] remoteExec ["systemChat", _player];
    };
    if (!isClass (configFile >> "CfgVehicles" >> _vehicleClass)) exitWith {
        ["Unknown vehicle class."] remoteExec ["systemChat", _player];
    };
    if (_vehicleClass isKindOf "Air" || {!(_vehicleClass isKindOf "LandVehicle")}) exitWith {
        ["Only ground vehicles can spawn at range slots."] remoteExec ["systemChat", _player];
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
    private _center = getPosATL _logicObj;
    private _dir = getDir _logicObj;
    private _blacklist = [];
    { private _p = getPosATL _x; _blacklist pushBack [_p select 0, _p select 1] } forEach (nearestObjects [_center, ["LandVehicle", "Air"], 30]);
    private _pos = [_center, 2, 15, 3, 1, 0.5, 0, _blacklist, _center] call BIS_fnc_findSafePos;
    if (count _pos < 2) exitWith {
        ["No clear spot at this slot. Despawn nearby vehicles."] remoteExec ["systemChat", _player];
    };
    if (count _pos < 3) then { _pos = [_pos select 0, _pos select 1, 0] };
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
    [format ["%1 spawned at %2.", _dn, _slotName]] remoteExec ["systemChat", _player];
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

publicVariable "FADE_rangeStartSession";
publicVariable "FADE_rangeEndSession";
publicVariable "FADE_rangeRequestAtWeaponState";
publicVariable "FADE_rangeSpawnAtWeaponAtSlot";
publicVariable "FADE_rangeDespawnAtWeaponSlot";
publicVariable "FADE_rangeSpawnFriendlyLandAtSlot";
publicVariable "FADE_rangeDespawnFriendlyLandAtSlot";
publicVariable "FADE_rangeSessionActive";
publicVariable "FADE_rangeSessionMode";
publicVariable "FADE_rangeHumanPosCount";
publicVariable "FADE_rangeVehPosCount";
publicVariable "FADE_rangeGunPosCount";
publicVariable "FADE_rangeFriendlyVehPosCount";
