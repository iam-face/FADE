// =============================================================================
// FiresDrillServer.sqf — FIRES range timed lane drills (server)
// =============================================================================
// One concurrent drill per firesPos_* slot; timer starts at target spawn.
// Spawns: locked car (FADE_firesDrillCarClass) + burning smoke barrel + optional extra marker; completes on car damage.
// Requires: FADE_fires_slots, FADE_basePos (optional), FAC_fires_publishState path, Config FADE_firesDrill*.
// =============================================================================
if (!isServer) exitWith {};

if (isNil "FAC_fires_drill_bySlot") then { FAC_fires_drill_bySlot = createHashMap };

FAC_fires_drill_fnc_slotDisplay = {
    params ["_slotName"];
    private _names = missionNamespace getVariable ["FADE_firesPosNames", []];
    private _disp = missionNamespace getVariable ["FADE_firesPosDisplayNames", []];
    private _i = _names find _slotName;
    if (_i >= 0 && { count _disp > _i }) exitWith { _disp select _i };
    _slotName
};

FAC_fires_drill_fnc_updateSummary = {
    private _keys = keys FAC_fires_drill_bySlot;
    private _txt = if (count _keys == 0) then {
        "Drill: none active."
    } else {
        private _parts = _keys apply { format ["%1 busy", [_x] call FAC_fires_drill_fnc_slotDisplay] };
        "Drill: " + (_parts joinString " | ")
    };
    missionNamespace setVariable ["FAC_fires_drill_activeSummary", _txt, true];
};

FAC_fires_drill_fnc_deleteDrillObjects = {
    params [["_objs", []]];
    private _car0 = _objs param [0, objNull];
    if (!isNull _car0) then { _car0 removeAllEventHandlers "HandleDamage" };
    {
        if (!isNull _x) then { deleteVehicle _x };
    } forEach _objs;
};
FAC_fires_drill_fnc_cleanupSlot = {
    params ["_slotName"];
    if (!(_slotName in FAC_fires_drill_bySlot)) exitWith {};
    private _entry = FAC_fires_drill_bySlot get _slotName;
    if (isNil "_entry" || {_entry isEqualTo []}) exitWith {};
    _entry params ["_handle", "_objs"];
    if (!isNull _handle && {!scriptDone _handle}) then { terminate _handle };
    [_objs] call FAC_fires_drill_fnc_deleteDrillObjects;
    FAC_fires_drill_bySlot deleteAt _slotName;
    [] call FAC_fires_drill_fnc_updateSummary;
};

// Strip characters that break hint parseText (same idea as FADE_sniperHintSafeText; drill loads before sniper server).
FAC_fires_drill_fnc_hintSafeText = {
    params [["_t", ""]];
    if (!(_t isEqualType "")) then { _t = str _t };
    private _amp = toString [38];
    private _lt = toString [60];
    private _gt = toString [62];
    _t = (_t splitString _amp) joinString " and ";
    _t = (_t splitString _lt) joinString " ";
    _t = (_t splitString _gt) joinString " ";
    _t = (_t splitString toString [34]) joinString "'";
    _t
};

FAC_fires_drill_fnc_recipients = {
    params ["_logicObj", "_starter"];
    private _rad = missionNamespace getVariable ["FADE_firesDrillNotifyRadiusM", 100];
    private _p = getPosATL _logicObj;
    private _set = [_starter];
    {
        if (!isNull _x && { alive _x } && { isPlayer _x } && { _x distance2D _p <= _rad }) then {
            _set pushBackUnique _x;
        };
    } forEach allPlayers;
    _set
};

// CQB horn (FAC_cqbLoudspeakerHorn / FADE_cqbLoudspeakerBroadcast) at FIRES terminal — server only at runtime.
FAC_fires_drill_fnc_terminalHorn = {
    params [["_mode", "stop"]];
    private _t = missionNamespace getVariable ["FADE_firesTerminal", objNull];
    if (isNull _t) then { _t = missionNamespace getVariable ["terminalFires", objNull] };
    if (!isNull _t) then { [_mode, _t] call FADE_cqbLoudspeakerBroadcast };
};

FADE_fires_drillStart = {
    params ["_slotName", "_minD", "_maxD", "_tgtIdx", "_bearingMode", "_player"];
    if (!isServer) exitWith {};
    if (isNil "_player" || { isNull _player }) exitWith {};

    private _idx = FADE_fires_slots findIf { (_x select 0) == _slotName };
    if (_idx < 0) exitWith {
        ["FIRES drill: unknown slot."] remoteExec ["systemChat", _player];
    };
    private _entry = FADE_fires_slots select _idx;
    _entry params ["_sn", "_logicObj", "_veh"];
    if (isNull _logicObj) exitWith {
        [format ["FIRES drill: missing Eden logic %1.", _slotName]] remoteExec ["systemChat", _player];
    };

    [_slotName] call FAC_fires_drill_fnc_cleanupSlot;

    private _min = [_minD] call {
        params ["_v"];
        if (_v isEqualType 0) exitWith { _v };
        parseNumber str _v
    };
    private _max = [_maxD] call {
        params ["_v"];
        if (_v isEqualType 0) exitWith { _v };
        parseNumber str _v
    };
    if (!finite _min || {_min < 50}) then { _min = 400 };
    if (!finite _max || {_max < _min + 25}) then { _max = _min + 400 };
    if (_max > 8000) then { _max = 8000 };

    // Drill impact target: always a soft vehicle + smoke barrel (+ optional FADE_firesDrillFireClass marker).
    private _carClass = missionNamespace getVariable ["FADE_firesDrillCarClass", "C_Offroad_01_F"];
    if (!isClass (configFile >> "CfgVehicles" >> _carClass)) then { _carClass = "C_Offroad_01_F" };
    private _barrelClass = missionNamespace getVariable ["FADE_firesDrillBarrelClass", "MetalBarrel_burning_F"];
    if (!isClass (configFile >> "CfgVehicles" >> _barrelClass)) then {
        _barrelClass = if (isClass (configFile >> "CfgVehicles" >> "MetalBarrel_burning_F")) then { "MetalBarrel_burning_F" } else { "Land_MetalBarrel_F" };
    };
    private _fireClass = missionNamespace getVariable ["FADE_firesDrillFireClass", ""];
    private _offRng = missionNamespace getVariable ["FADE_firesDrillBarrelDistanceM", [4, 7]];
    private _offMin = _offRng param [0, 4];
    private _offMax = _offRng param [1, 7];
    if (!finite _offMin) then { _offMin = 4 };
    if (!finite _offMax || {_offMax < _offMin}) then { _offMax = _offMin + 2 };

    private _randBrg = (_bearingMode isEqualType 0 && { round _bearingMode >= 1 });

    private _basePos = missionNamespace getVariable ["FADE_basePos", []];
    private _baseOk = (_basePos isEqualType []) && { count _basePos >= 2 } && { finite (_basePos select 0) } && { finite (_basePos select 1) };
    private _minFromBase = missionNamespace getVariable ["FADE_firesDrillMinDistFromBaseM", 500];
    if (!(_minFromBase isEqualType 0)) then { _minFromBase = parseNumber str _minFromBase };
    if (!finite _minFromBase || {_minFromBase < 0}) then { _minFromBase = 500 };
    private _maxSpawnAttempts = round (missionNamespace getVariable ["FADE_firesDrillSpawnMaxAttempts", 25]);
    if (_maxSpawnAttempts < 1) then { _maxSpawnAttempts = 25 };
    if (_maxSpawnAttempts > 99) then { _maxSpawnAttempts = 99 };

    private _posFlat = [];
    private _distUsed = _min;
    private _brgUsed = getDir _logicObj;
    private _logicAtl = getPosATL _logicObj;
    private _attempts = 0;
    while { _attempts < _maxSpawnAttempts } do {
        _attempts = _attempts + 1;
        _distUsed = _min + random ((_max - _min) max 1);
        _brgUsed = if (_randBrg) then { random 360 } else { getDir _logicObj };
        // Position + getPos [dist, degFromNorth] — anchor from logic ATL (object-form getPos on Logic is unreliable).
        private _p = _logicAtl getPos [_distUsed, _brgUsed];
        private _dry = !surfaceIsWater _p;
        private _farFromBase = if (!_baseOk || {_minFromBase <= 0}) then { true } else { (_p distance2D _basePos) >= _minFromBase };
        if (_dry && {_farFromBase}) then {
            _posFlat = _p;
            break;
        };
    };
    if (_posFlat isEqualTo []) exitWith {
        private _fail = format [
            "FIRES drill: no valid point in %1 tries (dry land, ≥%2 m from main base). Widen min/max range, use random bearing, or move the range pit.",
            _maxSpawnAttempts,
            round _minFromBase
        ];
        [_fail] remoteExec ["systemChat", _player];
    };

    private _car = createVehicle [_carClass, [0, 0, 500 + random 50], [], 0, "NONE"];
    if (isNull _car) exitWith {
        ["FIRES drill: car spawn failed."] remoteExec ["systemChat", _player];
    };
    _car setPosATL _posFlat;
    private _sn = surfaceNormal (getPosASL _car);
    if ((_sn select 0) != 0 || {(_sn select 1) != 0} || {(_sn select 2) != 0}) then {
        _car setVectorUp _sn;
    };
    _car allowDamage true;
    // Splash / part hits often never raise aggregate `damage` enough; complete on first real damage application.
    _car addEventHandler ["HandleDamage", {
        params ["_unit", "_selectionName", "_damage"];
        if (_damage isEqualType 0 && {finite _damage} && {_damage > 0.00001}) then {
            _unit setVariable ["FAC_fires_drill_hit", true, false];
        };
        _damage
    }];
    if (_car isKindOf "AllVehicles" && {!(_car isKindOf "StaticWeapon")}) then {
        { _car deleteVehicleCrew _x } forEach crew _car;
        _car setVehicleLock "LOCKED";
        if (_car isKindOf "Car" || {_car isKindOf "Truck"}) then { clearItemCargoGlobal _car };
    };

    private _markDir = random 360;
    private _markDist = _offMin + random ((_offMax - _offMin) max 0.1);
    private _barrelPos = +_posFlat;
    _barrelPos = _barrelPos getPos [_markDist, _markDir];
    if (surfaceIsWater _barrelPos) then {
        _barrelPos = _posFlat getPos [(_markDist * 0.65) max 2, _markDir + 17];
    };
    private _barrel = objNull;
    if (isClass (configFile >> "CfgVehicles" >> _barrelClass)) then {
        _barrel = createVehicle [_barrelClass, [0, 0, 500 + random 40], [], 0, "NONE"];
        if (!isNull _barrel) then {
            _barrel setPosATL _barrelPos;
            private _snB = surfaceNormal (getPosASL _barrel);
            if ((_snB select 0) != 0 || {(_snB select 1) != 0} || {(_snB select 2) != 0}) then {
                _barrel setVectorUp _snB;
            };
            _barrel allowDamage false;
        };
    };

    private _fire = objNull;
    if (_fireClass != "" && {isClass (configFile >> "CfgVehicles" >> _fireClass)}) then {
        private _fp = if (!isNull _barrel) then {
            (getPosATL _barrel) getPos [1.2, (_markDir + 95) mod 360]
        } else {
            _posFlat getPos [(_markDist * 0.5) max 1.5, (_markDir + 40) mod 360]
        };
        if (surfaceIsWater _fp) then { _fp = _posFlat getPos [2, _markDir] };
        _fire = createVehicle [_fireClass, [0, 0, 500 + random 30], [], 0, "NONE"];
        if (!isNull _fire) then {
            _fire setPosATL _fp;
            private _snF = surfaceNormal (getPosASL _fire);
            if ((_snF select 0) != 0 || {(_snF select 1) != 0} || {(_snF select 2) != 0}) then {
                _fire setVectorUp _snF;
            };
            _fire allowDamage false;
        };
    };

    private _objs = [];
    _objs pushBack _car;
    if (!isNull _barrel) then { _objs pushBack _barrel };
    if (!isNull _fire) then { _objs pushBack _fire };

    private _slotDisp = [_slotName] call FAC_fires_drill_fnc_slotDisplay;
    private _grid = mapGridPosition _car;
    private _elev = round (getPosASL _car select 2);
    private _recips = [_logicObj, _player] call FAC_fires_drill_fnc_recipients;
    private _t0 = diag_tickTime;

    private _title = "FIRES timed drill";
    {
        [_title, _grid, _elev, _slotDisp] remoteExec ["FADE_fires_drill_clientNotify", _x];
    } forEach _recips;

    private _startMsg = format [
        "FIRES drill started (%1): grid %2, ~%3 m, elev ~%4 m ASL — engage the vehicle (smoke/barrel marker nearby).",
        _slotDisp, _grid, round _distUsed, _elev
    ];
    { [_startMsg] remoteExec ["systemChat", _x] } forEach _recips;

    ["start"] call FAC_fires_drill_fnc_terminalHorn;

    private _starterName0 = name _player;

    private _dmg0 = damage _car;
    if (!finite _dmg0) then { _dmg0 = 0 };
    private _hp0 = getAllHitPointsDamage _car;
    private _hitMax0 = _dmg0;
    if (count _hp0 >= 2 && { count (_hp0 select 1) > 0 }) then {
        private _vals = _hp0 select 1;
        private _m = 0;
        { if (_x isEqualType 0 && {finite _x} && {_x > _m}) then { _m = _x } } forEach _vals;
        _hitMax0 = _m;
    };
    // Precompute thresholds so waitUntil does not parse `a > b + c` as `(a > b) + c` (boolean + number = error).
    private _dmgTh = _dmg0 + 0.00001;
    private _hpTh = _hitMax0 + 0.00001;
    if (!finite _dmgTh) then { _dmgTh = 0.00001 };
    if (!finite _hpTh) then { _hpTh = 0.00001 };

    private _h = [_slotName, _objs, _t0, _recips, _slotDisp, _dmgTh, _hpTh, _starterName0, _player] spawn {
        params ["_slotName", "_objs", "_t0", "_recips", "_slotDisp", "_dmgTh", "_hpTh", "_starterName0", "_starter"];
        private _car = _objs param [0, objNull];
        waitUntil {
            sleep 0.25;
            if (isNull _car) exitWith { true };
            if (!alive _car) exitWith { true };
            if (_car getVariable ["FAC_fires_drill_hit", false]) exitWith { true };
            private _d = damage _car;
            if (finite _d && {_d > _dmgTh}) exitWith { true };
            private _hp = getAllHitPointsDamage _car;
            if (count _hp >= 2 && { count (_hp select 1) > 0 }) then {
                private _mx = 0;
                { if (_x isEqualType 0 && {finite _x} && {_x > _mx}) then { _mx = _x } } forEach (_hp select 1);
                if (_mx > _hpTh) exitWith { true };
            };
            false
        };
        if (isNull _car) exitWith {
            ["stop"] call FAC_fires_drill_fnc_terminalHorn;
            [_objs] call FAC_fires_drill_fnc_deleteDrillObjects;
            FAC_fires_drill_bySlot deleteAt _slotName;
            [] call FAC_fires_drill_fnc_updateSummary;
        };
        private _elapsed = diag_tickTime - _t0;
        private _secs = round _elapsed;
        private _nm = [_starterName0] call FAC_fires_drill_fnc_hintSafeText;
        private _gr = if (!isNull _starter && {alive _starter}) then { mapGridPosition _starter } else { "N/A" };
        _gr = [_gr] call FAC_fires_drill_fnc_hintSafeText;
        private _slotSafe = [_slotDisp] call FAC_fires_drill_fnc_hintSafeText;
        private _destroyed = !alive _car;
        private _chat = if (_destroyed) then {
            format ["FIRES: %1 at grid %2 destroyed the timed drill target. Time: %3 s. (%4)", _nm, _gr, _secs, _slotSafe]
        } else {
            format ["FIRES: %1 at grid %2 hit the timed drill target. Time: %3 s. (%4)", _nm, _gr, _secs, _slotSafe]
        };
        [_chat] remoteExec ["systemChat", 0];
        ["stop"] call FAC_fires_drill_fnc_terminalHorn;
        private _lines = [];
        _lines pushBack "<t size='1.05' color='#a8e6cf'>FIRES TIMED DRILL — complete</t>";
        if (_destroyed) then {
            _lines pushBack format ["<t color='#ffcc88'>%1</t> <t color='#cccccc'>at grid</t> <t color='#90EE90'>%2</t> <t color='#cccccc'>destroyed the drill vehicle.</t>", _nm, _gr];
        } else {
            _lines pushBack format ["<t color='#ffcc88'>%1</t> <t color='#cccccc'>at grid</t> <t color='#90EE90'>%2</t> <t color='#cccccc'>hit the drill target (damage registered).</t>", _nm, _gr];
        };
        _lines pushBack format ["<t color='#cccccc'>Elapsed: <t color='#ffffff'>%1 s</t> · Lane: <t color='#9fb8d4'>%2</t></t>", str _secs, _slotSafe];
        if (!isNull _starter && {isPlayer _starter}) then {
            [(_lines joinString "<br/><br/>")] remoteExec ["FADE_fires_drill_clientCompleteHint", _starter];
        };
        [_objs] call FAC_fires_drill_fnc_deleteDrillObjects;
        FAC_fires_drill_bySlot deleteAt _slotName;
        [] call FAC_fires_drill_fnc_updateSummary;
    };

    FAC_fires_drill_bySlot set [_slotName, [_h, _objs]];
    [] call FAC_fires_drill_fnc_updateSummary;
};

FADE_fires_drillCancel = {
    params ["_slotName", "_player"];
    if (!isServer) exitWith {};
    if (!(_slotName in FAC_fires_drill_bySlot)) exitWith {
        if (!isNull _player) then {
            ["FIRES drill: no active drill for that slot."] remoteExec ["systemChat", _player];
        };
    };
    [_slotName] call FAC_fires_drill_fnc_cleanupSlot;
    ["stop"] call FAC_fires_drill_fnc_terminalHorn;
    if (!isNull _player) then {
        [format ["FIRES drill cancelled (%1).", [_slotName] call FAC_fires_drill_fnc_slotDisplay]] remoteExec ["systemChat", _player];
    };
};

FADE_fires_drillRequestSummary = {
    params [["_requester", objNull]];
    if (!isServer) exitWith {};
    [] call FAC_fires_drill_fnc_updateSummary;
};

[] call FAC_fires_drill_fnc_updateSummary;

missionNamespace setVariable ["FADE_fires_drillStart", FADE_fires_drillStart];
missionNamespace setVariable ["FADE_fires_drillCancel", FADE_fires_drillCancel];
missionNamespace setVariable ["FADE_fires_drillRequestSummary", FADE_fires_drillRequestSummary];
