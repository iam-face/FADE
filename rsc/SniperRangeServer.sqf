// =============================================================================
// SniperRangeServer.sqf — server-only (included from initServer via compile)
// terminalSniper + sniperRangeTarget_* logic objects; one active session (MP).
// =============================================================================

if (!isServer) exitWith {};

// -----------------------------------------------------------------------------
// Eden: collect sniperRangeTarget_1 .. _N (scan 1–64)
// -----------------------------------------------------------------------------
FADE_sniperPositions = [];
private _si = 1;
while { _si <= 64 } do {
    private _o = missionNamespace getVariable [format ["sniperRangeTarget_%1", _si], objNull];
    if (!isNull _o) then { FADE_sniperPositions pushBack _o };
    _si = _si + 1;
};
missionNamespace setVariable ["FADE_sniperPosCount", count FADE_sniperPositions, true];

// Time trial firing positions: sniperPos_1 .. sniperPos_7 (game logics). Each entry [label 1..7, object].
FADE_sniperTrialPosLogics = [];
private _sp = 1;
while { _sp <= 7 } do {
    private _po = missionNamespace getVariable [format ["sniperPos_%1", _sp], objNull];
    if (!isNull _po) then { FADE_sniperTrialPosLogics pushBack [_sp, _po] };
    _sp = _sp + 1;
};
missionNamespace setVariable ["FADE_sniperTrialPosCount", count FADE_sniperTrialPosLogics, true];

FADE_sniperRangeActive = false;
FADE_sniperSpawned = [];
FADE_sniperEnemyGroups = [];
FADE_sniperStarterUnit = objNull;
FADE_sniperStarterUid = "";
FADE_sniperStarterKilledEh = [];
FADE_sniperTrialScript = scriptNull;
FADE_sniperHitTrack = false;
missionNamespace setVariable ["FADE_sniperTrialRequiredPos", -1];
missionNamespace setVariable ["FADE_sniperLastResult", "", true];

FADE_sniperFacingToPlayer = {
    params ["_posATL", "_player", "_isHuman"];
    private _from = if (_posATL isEqualType []) then { _posATL } else { getPosATL _posATL };
    private _to = getPosATL _player;
    private _d = [_from, _to] call BIS_fnc_dirTo;
    if (_isHuman) then { _d } else { _d - 180 };
};

FADE_sniperFriendlyHitPart = {
    params [["_sel", ""]];
    private _s = if (_sel isEqualType "") then { toLower _sel } else { toLower str _sel };
    if (_s find "head" >= 0) exitWith { "Head" };
    if (_s find "face" >= 0 || {_s find "neck" >= 0}) exitWith { "Head/face" };
    if (_s find "pelvis" >= 0 || {_s find "abdomen" >= 0}) exitWith { "Torso (pelvis/abdomen)" };
    if (_s find "chest" >= 0 || {_s find "spine" >= 0 || {_s find "body" >= 0}}) exitWith { "Torso" };
    if (_s find "arm" >= 0 || {_s find "hand" >= 0}) exitWith { "Arms/hands" };
    if (_s find "leg" >= 0 || {_s find "foot" >= 0 || {_s find "thigh" >= 0}}) exitWith { "Legs/feet" };
    if (_s find "glass" >= 0 || {_s find "view" >= 0}) exitWith { "Glass / optics" };
    if (_s find "turret" >= 0 || {_s find "gun" >= 0 || {_s find "basket" >= 0}}) exitWith { "Turret / weapon" };
    if (_s find "engine" >= 0 || {_s find "motor" >= 0 || {_s find "hull" >= 0}}) exitWith { "Hull / engine area" };
    if (_s find "wheel" >= 0 || {_s find "track" >= 0}) exitWith { "Wheels / tracks" };
    if (_s find "fuel" >= 0) exitWith { "Fuel / stowage" };
    if (_s == "") exitWith { "Impact (unknown part)" };
    _s
};

// joinString requires all strings; HitPart rows sometimes mix scalars (hit index, etc.) — e.g. leg selections on pop-up targets.
FADE_sniperJoinHitPartCells = {
    params [["_arr", []]];
    if (!(_arr isEqualType []) || {_arr isEqualTo []}) exitWith { "" };
    (_arr apply { if (_x isEqualType "") then { _x } else { str _x } }) joinString ","
};

// Index 3 in a HitPart row should be model-space or ASL position as three finite scalars. Leg (and some mod) hits can pass other types — do not call finite() / vectorMagnitude on those.
FADE_sniperHitPartPosIsValidNumericTriplet = {
    params [["_p", []]];
    if (!(_p isEqualType []) || { count _p < 3 }) exitWith { false };
    private _x = _p select 0;
    private _y = _p select 1;
    private _z = _p select 2;
    (typeName _x == "SCALAR" && typeName _y == "SCALAR" && typeName _z == "SCALAR") && { finite _x } && { finite _y } && { finite _z }
};

// HitPart: _this is often [[victim, shooter, projectile, pos, vel, selection, ...], ...] — unwrap first row.
FADE_sniperNormalizeHitPartArgs = {
    private "_hp";
    _hp = _this select 0;
    if (!(_hp isEqualType []) || { count _hp < 1 }) exitWith { [] };
    if ((_hp select 0) isEqualType []) exitWith { _hp select 0 };
    _hp
};

// Meters; -1 if invalid (avoid NaN in hints)
FADE_sniperSafeDistanceM = {
    if (!(_this isEqualType []) || { count _this < 2 }) exitWith { -1 };
    private ["_a", "_b"];
    _a = _this select 0;
    _b = _this select 1;
    if (isNull _a || { isNull _b }) exitWith { -1 };
    private _d = _a distance _b;
    if (finite _d) exitWith { _d };
    private _pa = getPosASL _a;
    private _pb = getPosASL _b;
    if ((count _pa != 3) || { count _pb != 3 }) exitWith { -1 };
    private _v = _pa vectorDistance _pb;
    if (finite _v) exitWith { _v };
    -1
};

FADE_sniperTargetDisplayName = {
    if (!(_this isEqualType []) || { count _this < 1 }) exitWith { "Target" };
    private "_victim";
    _victim = _this select 0;
    if (isNull _victim) exitWith { "Target" };
    private _dn = getText (configFile >> "CfgVehicles" >> (typeOf _victim) >> "displayName");
    if (_dn != "") exitWith { _dn };
    if (_victim isKindOf "CAManBase") then {
        private _nm = name _victim;
        if (_nm != "") exitWith { _nm };
    };
    private _t = typeOf _victim;
    if (_t != "") exitWith { _t };
    "Target"
};

// HitPart row: selection index varies by game version / mods — try common slots (skip pure 3-vectors = velocity).
FADE_sniperPickHitPartSelection = {
    private "_row";
    _row = _this select 0;
    if (!(_row isEqualType []) || { count _row < 1 }) exitWith { "" };
    // Must not call finite() on strings — HitPart can pass 3-element selection arrays (e.g. pelvis/legs).
    private _isVel3 = {
        private "_v";
        _v = _this select 0;
        if (!(_v isEqualType []) || { count _v != 3 }) exitWith { false };
        private _x = _v select 0;
        private _y = _v select 1;
        private _z = _v select 2;
        (_x isEqualType 0) && (_y isEqualType 0) && (_z isEqualType 0) && { finite _x } && { finite _y } && { finite _z }
    };
    private _order = [5, 6, 7, 8, 4];
    private _out = "";
    private _oi = 0;
    while { _oi < count _order && { _out == "" } } do {
        private _i = _order select _oi;
        private _v = _row param [_i, nil];
        if (!isNil "_v") then {
            if (_v isEqualType "" && { _v != "" }) then { _out = _v };
            if (_out == "" && { _v isEqualType [] } && { count _v > 0 }) then {
                if !([_v] call _isVel3) then {
                    private _parts = [];
                    private _pj = 0;
                    while { _pj < count _v } do {
                        private _pce = _v select _pj;
                        if (_pce isEqualType "" && { _pce != "" }) then { _parts pushBack _pce };
                        _pj = _pj + 1;
                    };
                    _out = if (count _parts > 0) then { _parts joinString ", " } else { [_v] call FADE_sniperJoinHitPartCells };
                };
            };
        };
        _oi = _oi + 1;
    };
    _out
};

// Strip characters that break hint parseText / structured text
FADE_sniperHintSafeText = {
    private "_t";
    _t = _this select 0;
    if !(_t isEqualType "") then { _t = str _t };
    private _amp = toString [38];
    private _lt = toString [60];
    private _gt = toString [62];
    _t = (_t splitString _amp) joinString " and ";
    _t = (_t splitString _lt) joinString " ";
    _t = (_t splitString _gt) joinString " ";
    _t = (_t splitString toString [34]) joinString "'";
    _t
};

// true if _p is 3 finite numbers (usable ASL)
FADE_sniperAslIsFinite = {
    private ["_p", "_x", "_y", "_z"];
    _p = _this select 0;
    if (isNil "_p" || {!(_p isEqualType [])} || { count _p < 3 }) exitWith { false };
    _x = _p select 0;
    _y = _p select 1;
    _z = _p select 2;
    (finite _x) && { finite _y } && { finite _z }
};

// ASL impact from HitPart row (index 3: model space or ASL depending on build); empty if missing / invalid
FADE_sniperHitPosFromHitPartArgs = {
    if (!(_this isEqualType []) || { count _this < 2 }) exitWith { [] };
    private ["_args", "_victim", "_p", "_out", "_mag", "_asl"];
    _args = _this select 0;
    _victim = _this select 1;
    if (!(_args isEqualType [])) exitWith { [] };
    _p = _args param [3, []];
    if (!([_p] call FADE_sniperHitPartPosIsValidNumericTriplet)) exitWith { [] };
    _out = [_p select 0, _p select 1, _p select 2];
    if (_out isEqualTo [0, 0, 0]) exitWith { [] };
    _mag = vectorMagnitude _out;
    _asl = if (!isNull _victim && { _mag < 120 }) then {
        AGLtoASL (_victim modelToWorld _out)
    } else {
        _out
    };
    if !([_asl] call FADE_sniperAslIsFinite) exitWith { [] };
    _asl
};

// Firer = starter or crew on starter's vehicle (Hit / HitPart argument layouts vary by entity type)
FADE_sniperResolveFirerFromDamageArray = {
    if (!(_this isEqualType []) || { count _this < 3 }) exitWith { objNull };
    private ["_args", "_starter", "_victim"];
    _args = _this select 0;
    _starter = _this select 1;
    _victim = _this select 2;
    if (isNull _starter || {!(_args isEqualType [])}) exitWith { objNull };
    private _by = _args param [1, objNull];
    if (!isNull _by) then {
        if (_by == _starter) exitWith { _starter };
        if (_by isKindOf "AllVehicles") then {
            if (
                effectiveCommander _by == _starter ||
                { gunner _by == _starter } ||
                { driver _by == _starter } ||
                { commander _by == _starter }
            ) exitWith { _starter };
        };
    };
    private _found = objNull;
    { if (_x isEqualType objNull && {!isNull _x && {_x == _starter}}) exitWith { _found = _x } } forEach _args;
    if (!isNull _found) exitWith { _found };
    private _n = (count _args) min 9;
    private _i = 0;
    while { _i < _n && { isNull _found } } do {
        private _c = _args select _i;
        if (_c isEqualType objNull && {!isNull _c}) then {
            if (_c == _starter) then { _found = _starter };
            if (isNull _found && {_c isKindOf "AllVehicles"}) then {
                if (
                    effectiveCommander _c == _starter ||
                    { gunner _c == _starter } ||
                    { driver _c == _starter } ||
                    { commander _c == _starter }
                ) then { _found = _starter };
            };
        };
        _i = _i + 1;
    };
    _found
};

FADE_sniperSpawnImpactSphere = {
    if (!(_this isEqualType []) || { count _this < 1 }) exitWith {};
    private ["_posASL", "_fallbackVictim", "_p", "_cls", "_s"];
    _posASL = _this select 0;
    _fallbackVictim = if ((count _this) > 1) then { _this select 1 } else { objNull };
    if (!isServer) exitWith {};
    _p = +_posASL;
    if ((count _p < 3) || {!([_p] call FADE_sniperAslIsFinite)}) then {
        _p = if (!isNull _fallbackVictim) then { getPosASL _fallbackVictim vectorAdd [0, 0, 0.45] } else { [] };
    };
    if ((count _p < 3) || {!([_p] call FADE_sniperAslIsFinite)}) exitWith {};
    _cls = missionNamespace getVariable ["FADE_sniperImpactMarkerClass", "Sign_sphere25cm_EP1"];
    if (!isClass (configFile >> "CfgVehicles" >> _cls)) then { _cls = "Sign_Sphere100cm_F" };
    if (!isClass (configFile >> "CfgVehicles" >> _cls)) then { _cls = "Land_HelipadEmpty_F" };
    // Spawn at origin then setPosASL — avoids createVehicle rejecting odd ASL/AGL at placement time (MP).
    _s = createVehicle [_cls, [0, 0, 0], [], 0, "NONE"];
    if (isNull _s) exitWith {};
    _s enableSimulationGlobal false;
    _s allowDamage false;
    _s setPosASL _p;
    [_s] spawn {
        private "_obj";
        _obj = _this select 0;
        sleep 5;
        if (!isNull _obj) then { deleteVehicle _obj };
    };
};

// Impact marker always (all players see server object). Hint/chat only if hit feedback enabled in GUI.
// _this: [victim, shooter, posASL, selRaw, ammoClass (optional)]
FADE_sniperProcessImpact = {
    if (!(_this isEqualType []) || { count _this < 4 }) exitWith {};
    private _victimObj = _this param [0, objNull, [objNull]];
    private _shooterObj = _this param [1, objNull, [objNull]];
    private _posASL = _this param [2, []];
    private _selRaw = _this param [3, ""];
    private _ammoCls = if ((count _this) > 4) then { _this select 4 } else { "" };
    if (_ammoCls isEqualType []) then {
        private _picked = "";
        {
            if (_x isEqualType "" && { _x != "" }) then { _picked = _x };
        } forEach _ammoCls;
        _ammoCls = _picked;
    };
    if !(_ammoCls isEqualType "") then { _ammoCls = "" };
    if (!isServer) exitWith {};
    if (!(missionNamespace getVariable ["FADE_sniperRangeActive", false])) exitWith {};
    if (isNull _victimObj || { isNull _shooterObj }) exitWith {};
    if (_victimObj getVariable ["FADE_sniperTrialNodeLock", false]) exitWith {};

    // Live OPFOR mode: any valid hit from the session shooter should be lethal (no unconscious survivors).
    if (
        (missionNamespace getVariable ["FADE_sniperSessionEnemyType", "targets"]) == "enemies" &&
        { _victimObj isKindOf "CAManBase" } &&
        { alive _victimObj }
    ) then {
        _victimObj setDamage 1;
    };

    if (!(missionNamespace getVariable ["FADE_sniperHitTrack", false])) exitWith {};
    private _now = diag_tickTime;
    private _last = _victimObj getVariable ["FADE_sniperImpactDebounce", -100];
    if (_now - _last < 0.15) exitWith {};
    _victimObj setVariable ["FADE_sniperImpactDebounce", _now, false];
    // Impact sphere: starter's client tracks every projectile (hits + misses); see SniperGui + FADE_sniperServer_impactSphereFromClient
    private _sel = _selRaw;
    if (_sel isEqualType []) then { _sel = [_sel] call FADE_sniperJoinHitPartCells };
    if !(_sel isEqualType "") then { _sel = str _sel };
    private _part = if (_sel == "") then { "Impact (unknown part)" } else { _sel };
    private _distImpact = -1;
    if ([_posASL] call FADE_sniperAslIsFinite) then {
        private _di = (getPosASL _shooterObj) vectorDistance _posASL;
        if (finite _di) then { _distImpact = _di };
    };
    private _distImpStr = if (_distImpact >= 0 && { finite _distImpact }) then { str (round _distImpact) + " m" } else { "—" };
    // Keep immediate and summary note minimal during stabilization: distance + body part only.
    private _lastHit = format ["%1 — %2", _distImpStr, _part];
    missionNamespace setVariable ["FADE_sniperLastHitNote", _lastHit];
    private _sess = missionNamespace getVariable ["FADE_sniperSessionMode", ""];
    private _lastHitSafe = [_lastHit] call FADE_sniperHintSafeText;
    if (_sess == "firing" || { _sess == "trial" }) then {
        private _title = if (_sess == "trial") then { "SNIPER TIME TRIAL — hit" } else { "SNIPER RANGE — hit" };
        private _hintHtml =
            "<t size='1.05' color='#a8e6cf'>" + _title + "</t><br/><br/>" +
            "<t color='#ffffff'>" + _lastHitSafe + "</t>";
        [_hintHtml] remoteExec ["FADE_sniperClient_showTrialHint", _shooterObj];
    } else {
        [_lastHitSafe] remoteExec ["systemChat", _shooterObj];
    };
};

// Time trial: hit while target still locked (shooter not at node). Throttled hint to avoid spam.
FADE_sniperTrialWrongPosFeedback = {
    private _p = missionNamespace getVariable ["FADE_sniperStarterUnit", objNull];
    if (isNull _p) exitWith {};
    if (diag_tickTime - (missionNamespace getVariable ["FADE_sniperTrialPosWarnT", -100]) <= 2) exitWith {};
    missionNamespace setVariable ["FADE_sniperTrialPosWarnT", diag_tickTime];
    private _need = missionNamespace getVariable ["FADE_sniperTrialRequiredPos", -1];
    private _body = if (_need >= 0) then {
        "Hit not counted, you are at the wrong position!<br/>Move to position " + str _need + " (within 1 m)."
    } else {
        "Hit not counted, you are at the wrong position!<br/>Move to the correct firing position (within 1 m)."
    };
    private _html = "<t size='1.05' color='#ffb3b3'>SNIPER TIME TRIAL</t><br/><br/><t color='#ffffff'>" + _body + "</t>";
    [_html] remoteExec ["FADE_sniperClient_showTrialHint", _p];
};

FADE_sniperEhHit = {
    if (!(_this isEqualType []) || { count _this < 2 }) exitWith {};
    private ["_victim", "_hitThis"];
    _victim = _this select 0;
    _hitThis = _this select 1;
    if (isNull _victim || {!(_hitThis isEqualType [])}) exitWith {};
    if (!(missionNamespace getVariable ["FADE_sniperRangeActive", false])) exitWith {};
    private _starter = missionNamespace getVariable ["FADE_sniperStarterUnit", objNull];
    private _firer = objNull;
    if (count _hitThis > 0) then {
        private _a0 = _hitThis select 0;
        if (_a0 isEqualType objNull && {!isNull _a0 && {_a0 != _victim}}) then { _firer = _a0 };
    };
    if (isNull _firer && { count _hitThis > 1 }) then {
        private _a1 = _hitThis select 1;
        if (_a1 isEqualType objNull && {!isNull _a1}) then { _firer = _a1 };
    };
    if (isNull _firer) then { _firer = [_hitThis, _starter, _victim] call FADE_sniperResolveFirerFromDamageArray };
    if (isNull _firer || { _firer != _starter }) exitWith {};
    if (_victim getVariable ["FADE_sniperTrialNodeLock", false]) exitWith { [] call FADE_sniperTrialWrongPosFeedback };
    private _pos = getPosASL _victim vectorAdd [0, 0, 0.45];
    // Hit almost always fires before HitPart; defer so HitPart can place the marker at the real impact.
    // Unpack _this before sleep — scheduled scripts + params can leave locals undefined after sleep (RPT).
    [_victim, _firer, _pos, ""] spawn {
        private _victim = _this param [0, objNull, [objNull]];
        private _firer = _this param [1, objNull, [objNull]];
        private _pos = _this param [2, []];
        private _sel = _this param [3, ""];
        sleep 0.22;
        if (!(missionNamespace getVariable ["FADE_sniperRangeActive", false])) exitWith {};
        if (isNull _victim || { isNull _firer }) exitWith {};
        if (_victim getVariable ["FADE_sniperHitPartRecent", false]) exitWith {};
        [_victim, _firer, _pos, _sel, ""] call FADE_sniperProcessImpact;
    };
};

FADE_sniperEhHitPart = {
    if (!(_this isEqualType []) || { count _this < 2 }) exitWith {};
    private ["_victimEnt", "_hpRaw"];
    _victimEnt = _this select 0;
    _hpRaw = _this select 1;
    if (isNull _victimEnt) exitWith {};
    if (!(missionNamespace getVariable ["FADE_sniperRangeActive", false])) exitWith {};
    private _starter = missionNamespace getVariable ["FADE_sniperStarterUnit", objNull];
    private _hp = [_hpRaw] call FADE_sniperNormalizeHitPartArgs;
    if (count _hp < 1) exitWith {};
    private _p0 = _hp param [0, false];
    private _victim = if ((_p0 isEqualType objNull) && {!isNull _p0}) then { _p0 } else { _victimEnt };
    if (isNull _victim) exitWith {};
    private _shooter = [_hp, _starter, _victim] call FADE_sniperResolveFirerFromDamageArray;
    if (isNull _shooter || { _shooter != _starter }) exitWith {};
    if (_victim getVariable ["FADE_sniperTrialNodeLock", false]) exitWith { [] call FADE_sniperTrialWrongPosFeedback };
    private _pos = [_hp, _victim] call FADE_sniperHitPosFromHitPartArgs;
    if ((count _pos < 3) || {!([_pos] call FADE_sniperAslIsFinite)}) then {
        _pos = getPosASL _victim vectorAdd [0, 0, 0.45];
    };
    private _sel = [_hp] call FADE_sniperPickHitPartSelection;
    private _ammo = _hp param [6, ""];
    if !(_ammo isEqualType "") then { _ammo = str _ammo };
    _victim setVariable ["FADE_sniperHitPartRecent", true, false];
    [_victim] spawn {
        private _t = _this select 0;
        sleep 0.45;
        if (!isNull _t) then { _t setVariable ["FADE_sniperHitPartRecent", false, false] };
    };
    [_victim, _shooter, _pos, _sel, _ammo] call FADE_sniperProcessImpact;
};

FADE_sniperEhSteelHit = {
    params ["_victim", "_hitThis"];
    if (_victim getVariable ["FADE_sniperTrialNodeLock", false]) exitWith { [] call FADE_sniperTrialWrongPosFeedback };
    [_victim] call FADE_sniperMarkTargetDown;
    [_victim, _hitThis] call FADE_sniperEhHit;
};

FADE_sniperMarkTargetDown = {
    params [["_t", objNull]];
    if (isNull _t) exitWith {};
    if (!(_t getVariable ["FADE_sniperIsRangeTarget", false])) exitWith {};
    if (_t getVariable ["FADE_sniperDownHandled", false]) exitWith {};
    _t setVariable ["FADE_sniperDownHandled", true, true];
    [_t] remoteExec ["FADE_cqbClient_forceTargetDown", 0, true];
};

FADE_sniperRegisterSteelTarget = {
    params ["_target"];
    _target setVariable ["FADE_sniperIsRangeTarget", true, true];
    _target setVariable ["FADE_sniperDownHandled", false, true];
    private _tgt = _target;
    _target addEventHandler ["Hit", { [_tgt, _this] call FADE_sniperEhSteelHit }];
    _target addEventHandler ["HitPart", { [_tgt, _this] call FADE_sniperEhHitPart }];
    _target addEventHandler ["Killed", { [(_this select 0)] call FADE_sniperMarkTargetDown }];
    _target addEventHandler ["HandleDamage", {
        params ["_unit", "_selection", "_damage", "_source", "_projectile", "_hitIndex", "_instigator", "_hitPoint"];
        if (_unit getVariable ["FADE_sniperTrialNodeLock", false]) exitWith { 0 };
        if (_damage > 1e-3) then { [_unit] call FADE_sniperMarkTargetDown };
        _damage
    }];
};

FADE_sniperCleanupSpawned = {
    private _spawned = missionNamespace getVariable ["FADE_sniperSpawned", []];
    {
        if (isNull _x) then { continue };
        if (_x isEqualType grpNull) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach units _x;
            deleteGroup _x;
        } else {
            deleteVehicle _x;
        };
    } forEach _spawned;
    missionNamespace setVariable ["FADE_sniperSpawned", []];
    missionNamespace setVariable ["FADE_sniperEnemyGroups", []];
};

FADE_sniper_trialRemoveLastSpawn = {
    if (!isServer) exitWith {};
    private _spawned = missionNamespace getVariable ["FADE_sniperSpawned", []];
    if (_spawned isEqualTo []) exitWith {};
    private _idx = (count _spawned) - 1;
    private _xrem = _spawned select _idx;
    if (_xrem isEqualType grpNull) then {
        { if (!isNull _x) then { deleteVehicle _x } } forEach units _xrem;
        deleteGroup _xrem;
        private _eg = missionNamespace getVariable ["FADE_sniperEnemyGroups", []];
        if (_idx < count _eg) then {
            _eg deleteAt _idx;
            missionNamespace setVariable ["FADE_sniperEnemyGroups", _eg];
        };
    } else {
        if (!isNull _xrem) then { deleteVehicle _xrem };
    };
    _spawned deleteAt _idx;
    missionNamespace setVariable ["FADE_sniperSpawned", _spawned];
};

FADE_sniperEndSession = {
    params [["_player", objNull], ["_msg", "Sniper range ended."], ["_broadcastAll", false]];
    if (!isServer) exitWith {};
    if (!(missionNamespace getVariable ["FADE_sniperRangeActive", false])) exitWith {};

    private _tw = missionNamespace getVariable ["FADE_sniperTrialScript", scriptNull];
    if (!isNull _tw && {!scriptDone _tw}) then { terminate _tw };
    missionNamespace setVariable ["FADE_sniperTrialScript", scriptNull];

    private _khPair = missionNamespace getVariable ["FADE_sniperStarterKilledEh", []];
    if (count _khPair >= 2) then {
        _khPair params ["_u", "_eh"];
        if (!isNull _u && {_eh >= 0}) then { _u removeEventHandler ["Killed", _eh] };
    };
    missionNamespace setVariable ["FADE_sniperStarterKilledEh", []];
    missionNamespace setVariable ["FADE_sniperStarterUnit", objNull];
    missionNamespace setVariable ["FADE_sniperStarterUid", "", true];

    missionNamespace setVariable ["noPop", false, true];
    [] call FADE_sniperCleanupSpawned;

    missionNamespace setVariable ["FADE_sniperRangeActive", false];
    publicVariable "FADE_sniperRangeActive";
    missionNamespace setVariable ["FADE_sniperHitTrack", false];
    missionNamespace setVariable ["FADE_sniperSessionEnemyType", nil];
    missionNamespace setVariable ["FADE_sniperSessionTargetClass", nil];
    missionNamespace setVariable ["FADE_sniperSessionEnemyUnits", nil];
    missionNamespace setVariable ["FADE_sniperSessionMode", ""];
    missionNamespace setVariable ["FADE_sniperTrialRequiredPos", -1];

    private _starter = _player;
    if (isNull _starter) then { _starter = missionNamespace getVariable ["FADE_sniperLastStarterForFx", objNull] };
    if (!isNull _starter) then {
        [] remoteExec ["FADE_sniperClient_clearRangeFx", _starter];
    };
    missionNamespace setVariable ["FADE_sniperLastStarterForFx", objNull];

    if (_msg != "") then {
        if (_broadcastAll || {isNull _player}) then {
            [_msg] remoteExec ["systemChat", 0];
        } else {
            [_msg] remoteExec ["systemChat", _player];
        };
    };
};

// Params: _player, _enemyType ("targets"|"enemies"), _targetCount (1..40), _maxRangeM (100..1000), _trace (bool), _hitTrack (bool), _mode ("firing"|"trial")
// Session-scoped spawn (trial script runs async; must not rely on StartSession locals).
FADE_sniper_spawnAtPos = {
    params ["_player", "_posObj", "_isHuman", ["_trialLocked", false]];
    if (!isServer) exitWith {};
    private _enemyType = missionNamespace getVariable ["FADE_sniperSessionEnemyType", "targets"];
    private _targetClass = missionNamespace getVariable ["FADE_sniperSessionTargetClass", "TargetP_Inf_F"];
    private _enemyUnits = missionNamespace getVariable ["FADE_sniperSessionEnemyUnits", []];
    private _spawned = missionNamespace getVariable ["FADE_sniperSpawned", []];
    private _enemyGroups = missionNamespace getVariable ["FADE_sniperEnemyGroups", []];
    private _pos = getPosATL _posObj;
    if (count _pos < 3) then { _pos = [_pos select 0, _pos select 1, 0] };
    private _dir = [getPosATL _posObj, _player, _isHuman] call FADE_sniperFacingToPlayer;
    if (_enemyType == "targets") then {
        private _target = createVehicle [_targetClass, _pos, [], 0, "NONE"];
        _target setPosATL _pos;
        _target setDir _dir;
        _spawned pushBack _target;
        missionNamespace setVariable ["FADE_sniperSpawned", _spawned];
        [_target] call FADE_sniperRegisterSteelTarget;
        if (_trialLocked) then {
            _target allowDamage false;
            _target setVariable ["FADE_sniperTrialNodeLock", true, true];
        };
    } else {
        private _unitClass = selectRandom _enemyUnits;
        private _grp = createGroup (missionNamespace getVariable ["FADE_sideEnemy", east]);
        private _u = _grp createUnit [_unitClass, _pos, [], 0, "NONE"];
        _u setPosATL _pos;
        _u setDir _dir;
        {
            _u disableAI _x;
        } forEach [
            "MOVE", "PATH", "TARGET", "AUTOTARGET", "AUTOCOMBAT",
            "COVER", "SUPPRESSION", "FSM", "WEAPONAIM", "AIMINGERROR",
            "CHECKVISIBLE", "RADIOPROTOCOL", "TEAMSWITCH", "NVG", "MINEDETECTION"
        ];
        _grp allowFleeing 0;
        _grp setBehaviour "CARELESS";
        _grp setCombatMode "BLUE";
        _u setUnitPos "UP";
        private _ux = _u;
        _u addEventHandler ["Hit", { [_ux, _this] call FADE_sniperEhHit }];
        _u addEventHandler ["HitPart", { [_ux, _this] call FADE_sniperEhHitPart }];
        if (_trialLocked) then {
            _u allowDamage false;
            _u setVariable ["FADE_sniperTrialNodeLock", true, true];
        };
        _spawned pushBack _grp;
        _enemyGroups pushBack _grp;
        missionNamespace setVariable ["FADE_sniperSpawned", _spawned];
        missionNamespace setVariable ["FADE_sniperEnemyGroups", _enemyGroups];
    };
};

FADE_sniperStartSession = {
    params ["_player", "_enemyType", "_targetCount", "_maxRangeM", "_trace", "_hitTrack", "_mode"];
    if (!isServer) exitWith {};
    if (missionNamespace getVariable ["FADE_sniperRangeActive", false]) exitWith {
        ["Sniper range already active. End it first."] remoteExec ["systemChat", _player];
    };
    private _positions = missionNamespace getVariable ["FADE_sniperPositions", []];
    if (_positions isEqualTo []) exitWith {
        ["No sniper lanes found. Place sniperRangeTarget_* logic objects in Eden."] remoteExec ["systemChat", _player];
    };
    _targetCount = round _targetCount;
    _targetCount = (_targetCount max 1) min 40;
    _maxRangeM = round _maxRangeM;
    _maxRangeM = (_maxRangeM max 100) min 1000;

    private _enemyUnits = missionNamespace getVariable ["FADE_enemyUnits", missionNamespace getVariable ["FADE_fallbackEnemyUnits", ["O_Soldier_F"]]];
    _enemyUnits = [_enemyUnits] call FADE_filterUnitsArmed;
    if (_enemyUnits isEqualTo []) then { _enemyUnits = +(missionNamespace getVariable ["FADE_fallbackEnemyUnits", ["O_Soldier_F"]]) };

    private _targetClass = missionNamespace getVariable ["FADE_sniperTargetClass", missionNamespace getVariable ["FADE_cqbTargetClass", "TargetP_Inf_F"]];
    if (!isClass (configFile >> "CfgVehicles" >> _targetClass)) then { _targetClass = "Target_F" };

    missionNamespace setVariable ["FADE_sniperHitTrack", _hitTrack];
    missionNamespace setVariable ["FADE_sniperLastStarterForFx", _player];
    missionNamespace setVariable ["FADE_sniperSessionEnemyType", _enemyType];
    missionNamespace setVariable ["FADE_sniperSessionTargetClass", _targetClass];
    missionNamespace setVariable ["FADE_sniperSessionEnemyUnits", _enemyUnits];
    missionNamespace setVariable ["FADE_sniperSessionMaxRange", _maxRangeM];
    missionNamespace setVariable ["noPop", true, true];

    private _rangePool = [];
    {
        if ((_player distance2d _x) <= _maxRangeM) then { _rangePool pushBack _x };
    } forEach _positions;
    if (_rangePool isEqualTo []) exitWith {
        missionNamespace setVariable ["noPop", false, true];
        missionNamespace setVariable ["FADE_sniperHitTrack", false];
        [format ["No lanes found within %1 m. Increase max range.", _maxRangeM]] remoteExec ["systemChat", _player];
    };

    if (_mode == "trial") then {
        private _trialNodes = missionNamespace getVariable ["FADE_sniperTrialPosLogics", []];
        if (_trialNodes isEqualTo []) exitWith {
            missionNamespace setVariable ["noPop", false, true];
            missionNamespace setVariable ["FADE_sniperHitTrack", false];
            ["Time trial requires sniperPos_1..sniperPos_7 game logics in Eden."] remoteExec ["systemChat", _player];
        };
    };

    missionNamespace setVariable ["FADE_sniperSpawned", []];
    missionNamespace setVariable ["FADE_sniperEnemyGroups", []];

    if (_mode == "firing") then {
        private _pool = +_rangePool;
        private _spawnCount = _targetCount min (count _pool);
        for "_i" from 1 to _spawnCount do {
            if (_pool isEqualTo []) exitWith {};
            private _idx = floor (random (count _pool));
            private _pick = _pool deleteAt _idx;
            [_player, _pick, _enemyType == "enemies"] call FADE_sniper_spawnAtPos;
        };
        if ((missionNamespace getVariable ["FADE_sniperSpawned", []]) isEqualTo []) exitWith {
            missionNamespace setVariable ["noPop", false, true];
            missionNamespace setVariable ["FADE_sniperHitTrack", false];
            ["No targets spawned. Check lanes and try again."] remoteExec ["systemChat", _player];
        };
    };
    missionNamespace setVariable ["FADE_sniperRangeActive", true];
    publicVariable "FADE_sniperRangeActive";
    missionNamespace setVariable ["FADE_sniperSessionMode", _mode];
    missionNamespace setVariable ["FADE_sniperStarterUnit", _player];
    missionNamespace setVariable ["FADE_sniperStarterUid", getPlayerUID _player, true];

    private _starterKh = _player addEventHandler ["Killed", {
        if (!(missionNamespace getVariable ["FADE_sniperRangeActive", false])) exitWith {};
        private _victim = _this select 0;
        if (_victim != missionNamespace getVariable ["FADE_sniperStarterUnit", objNull]) exitWith {};
        [_victim, "Sniper range ended: shooter down.", false] call FADE_sniperEndSession;
    }];
    missionNamespace setVariable ["FADE_sniperStarterKilledEh", [_player, _starterKh]];

    if (_trace) then {
        [true] remoteExec ["FADE_sniperClient_setProjectileTrace", _player];
    };
    [true] remoteExec ["FADE_sniperClient_setProjectileImpactMarkers", _player];

    if (_mode == "firing") then {
        private _nSp = count (missionNamespace getVariable ["FADE_sniperSpawned", []]);
        [format ["Sniper range (firing): %1 targets spawned.", _nSp]] remoteExec ["systemChat", _player];
    } else {
        private _trial = [_player, _enemyType, +_rangePool, _targetCount, _maxRangeM, +(missionNamespace getVariable ["FADE_sniperTrialPosLogics", []])] spawn {
            params ["_player", "_enemyType", "_eligibleLanes", "_nTargets", "_maxRangeM", "_allNodes"];
            _nTargets = (_nTargets max 1) min 40;
            _maxRangeM = (_maxRangeM max 100) min 1000;
            private _distances = [];
            private _step = _maxRangeM / _nTargets;
            for "_iStep" from 1 to _nTargets do {
                _distances pushBack (round (_step * _iStep));
            };
            private _times = [];
            private _notes = [];
            private _t0 = diag_tickTime;
            missionNamespace setVariable ["FADE_sniperLastHitNote", ""];
            private _pool = +_eligibleLanes;
            if (_pool isEqualTo []) then { _pool = +(missionNamespace getVariable ["FADE_sniperPositions", []]) };
            private _remaining = +_pool;

            private _nodesShuffled = +_allNodes;
            private _nNode = count _nodesShuffled;
            if (_nNode > 1) then {
                for "_k" from _nNode - 1 to 1 step -1 do {
                    private _r = floor random (_k + 1);
                    private _tmp = _nodesShuffled select _k;
                    _nodesShuffled set [_k, _nodesShuffled select _r];
                    _nodesShuffled set [_r, _tmp];
                };
            };

            for "_i" from 0 to ((count _distances) - 1) do {
                if (!(missionNamespace getVariable ["FADE_sniperRangeActive", false])) exitWith {};
                private _nodeEntry = if (_i < count _nodesShuffled) then {
                    _nodesShuffled select _i
                } else {
                    selectRandom _allNodes
                };
                private _nodeLabel = _nodeEntry select 0;
                private _nodeObj = _nodeEntry select 1;
                missionNamespace setVariable ["FADE_sniperTrialRequiredPos", _nodeLabel];

                private _want = _distances select _i;
                if (_remaining isEqualTo []) then { _remaining = +_pool };
                private _bestIdx = -1;
                private _bestDelta = 1e9;
                for "_ix" from 0 to ((count _remaining) - 1) do {
                    private _lane = _remaining select _ix;
                    private _delta = abs ((_player distance2d _lane) - _want);
                    if (_delta < _bestDelta) then {
                        _bestDelta = _delta;
                        _bestIdx = _ix;
                    };
                };
                private _posObj = if (_bestIdx >= 0) then { _remaining deleteAt _bestIdx } else { selectRandom _pool };
                missionNamespace setVariable ["FADE_sniperLastHitNote", ""];
                private _tickStart = diag_tickTime;
                [_player, _posObj, _enemyType == "enemies", true] call FADE_sniper_spawnAtPos;
                private _last = (missionNamespace getVariable ["FADE_sniperSpawned", []]) select -1;
                private _waitObj = objNull;
                if (_enemyType == "targets") then {
                    _waitObj = _last;
                } else {
                    if (_last isEqualType grpNull && { count units _last > 0 }) then {
                        _waitObj = leader _last;
                    };
                };

                if (_i == 0) then {
                    private _hMove = "<t size='1.05' color='#a8e6cf'>SNIPER TIME TRIAL</t><br/><br/><t color='#ffffff'>Move to position " + str _nodeLabel + "!</t>";
                    [_hMove] remoteExec ["FADE_sniperClient_showTrialHint", _player];
                };

                waitUntil {
                    sleep 0.12;
                    !(missionNamespace getVariable ["FADE_sniperRangeActive", false]) ||
                    { (_player distance2d _nodeObj) <= 1 }
                };
                if (!(missionNamespace getVariable ["FADE_sniperRangeActive", false])) exitWith {};

                private _hAtNode = "<t size='1.05' color='#a8e6cf'>SNIPER TIME TRIAL</t><br/><br/><t color='#ffffff'>At position " + str _nodeLabel + ", engage target!</t>";
                [_hAtNode] remoteExec ["FADE_sniperClient_showTrialHint", _player];

                if (!isNull _waitObj) then {
                    _waitObj allowDamage true;
                    _waitObj setVariable ["FADE_sniperTrialNodeLock", false, true];
                };

                waitUntil {
                    sleep 0.12;
                    !(missionNamespace getVariable ["FADE_sniperRangeActive", false]) || {
                        if (_enemyType == "targets") then {
                            if (isNull _waitObj) then { true } else { _waitObj getVariable ["FADE_sniperDownHandled", false] }
                        } else {
                            isNull _waitObj || {!alive _waitObj}
                        };
                    };
                };
                if (!(missionNamespace getVariable ["FADE_sniperRangeActive", false])) exitWith {};
                private _elapsed = diag_tickTime - _tickStart;
                _times pushBack _elapsed;
                private _note = missionNamespace getVariable ["FADE_sniperLastHitNote", ""];
                if (_note == "") then { _note = if (_enemyType == "targets") then { "Target down" } else { "Neutralised" } };
                _notes pushBack _note;
                private _targetNum = _i + 1;
                if (_targetNum < _nTargets) then {
                    private _nextEntry = if ((_i + 1) < count _nodesShuffled) then {
                        _nodesShuffled select (_i + 1)
                    } else {
                        selectRandom _allNodes
                    };
                    private _nextLabel = _nextEntry select 0;
                    private _hHit = "<t size='1.05' color='#a8e6cf'>SNIPER TIME TRIAL</t><br/><br/><t color='#ffffff'>Hit — move to position " + str _nextLabel + "!</t>";
                    [_hHit] remoteExec ["FADE_sniperClient_showTrialHint", _player];
                    [format ["Time trial: Target %1 hit — move to position %2 for the next target.", _targetNum, _nextLabel]] remoteExec ["systemChat", _player];
                } else {
                    [format ["Time trial: Target %1 hit — trial complete.", _targetNum]] remoteExec ["systemChat", _player];
                };
                [] call FADE_sniper_trialRemoveLastSpawn;
            };

            if (!(missionNamespace getVariable ["FADE_sniperRangeActive", false])) exitWith {};

            private _total = diag_tickTime - _t0;
            private _totalStr = str ((round (_total * 100)) / 100);
            private _lines = [];
            _lines pushBack "<t size='1.05' color='#a8e6cf'>SNIPER TIME TRIAL — complete</t>";
            _lines pushBack format ["<t color='#cccccc'>Total time: <t color='#ffffff'>%1 s</t></t>", _totalStr];
            {
                private _idx = _forEachIndex + 1;
                private _d = _distances select _forEachIndex;
                private _ti = _times select _forEachIndex;
                private _tStr = str ((round (_ti * 100)) / 100);
                _lines pushBack format [
                    "<t color='#9fb8d4'>Stage %1 (~%2m): <t color='#ffffff'>%3 s</t> — %4</t>",
                    _idx, _d, _tStr, _notes select _forEachIndex
                ];
            } forEach _times;

            private _body = _lines joinString "<br/><br/>";
            [_body] remoteExec ["FADE_sniperClient_showTrialHint", _player];

            private _summary = format ["Time trial done — %1 s total.", _totalStr];
            missionNamespace setVariable ["FADE_sniperLastResult", _summary, true];
            publicVariable "FADE_sniperLastResult";

            missionNamespace setVariable ["FADE_sniperTrialScript", scriptNull];
            [_player] spawn {
                private _pEnd = _this select 0;
                sleep 0.05;
                [_pEnd, "", false] call FADE_sniperEndSession;
            };
        };
        missionNamespace setVariable ["FADE_sniperTrialScript", _trial];
        [format ["Sniper time trial started — %1 targets, max %2m. Use shuffled sniperPos_1..7 (1m).", _targetCount, _maxRangeM]] remoteExec ["systemChat", _player];
    };
};

// Client → server: last known ASL of local projectile (dedicated MP bullets are not on server)
FADE_sniperServer_impactSphereFromClient = {
    if (!(_this isEqualType []) || { count _this < 2 }) exitWith {};
    private ["_pos", "_uid"];
    _pos = _this select 0;
    _uid = _this select 1;
    if (!isServer) exitWith {};
    if (!(missionNamespace getVariable ["FADE_sniperRangeActive", false])) exitWith {};
    if (_uid != missionNamespace getVariable ["FADE_sniperStarterUid", ""]) exitWith {};
    if !([_pos] call FADE_sniperAslIsFinite) exitWith {};
    [_pos, objNull] call FADE_sniperSpawnImpactSphere;
};

publicVariable "FADE_sniperRangeActive";
publicVariable "FADE_sniperStartSession";
publicVariable "FADE_sniperEndSession";
publicVariable "FADE_sniperServer_impactSphereFromClient";
publicVariable "FADE_sniperLastResult";
publicVariable "FADE_sniperPosCount";
