// =============================================================================
// SurrenderChallenge.sqf -- Surrender challenge system (server-side logic)
// =============================================================================
// Runs on server. Params: [_player, _targetUnit]
// Validates conditions, runs challenge sequence, AI decides surrender or not.
//
// DEDICATED SERVER CONSIDERATIONS:
// - This script MUST run on the server (isServer check). AI units are server-owned
//   in dedicated server setups; disableAI, setBehaviour, doTarget, etc. only work
//   where the unit is local. On a dedicated server, all AI are local to server.
// - remoteExec ["systemChat", _player] sends feedback to the requesting client;
//   the server has no player to display chat, so we always target _player.
// - sleep blocks the server scheduler; keep challenge duration reasonable (3-5s).
// - setVariable with true (3rd param) broadcasts to all machines for JIP/sync.
//
// ACE3 INTEGRATION (optional):
// If ace_captives is loaded, surrendered units use ace_captives_fnc_setSurrendered.
// This enables ACE interactions: Escort prisoner, Load/unload captive, Frisk.
// We also reject targets that are ACE-surrendered or ACE-handcuffed.
//
// CHANCE MODIFIERS (applied to primary and secondaries):
// + Distance bonus    closer to target = higher chance (stepped, 0-25m)
// + Player bonus      more nearby players = higher chance (capped at +0.30)
// + Angle bonus       flanking/behind target = higher chance (+0.15/+0.25)
// + Captive bonus     surrendered comrades nearby = higher chance (+0.05 each, cap +0.20)
// - Ratio malus       enemy outnumbers players nearby = lower chance (-0.08 per extra, cap -0.30)
//
// IMMEDIATE REFUSE (primary only):
// Before the animation starts, high-skill units may flatly refuse without hesitating.
// Chance = skill * 0.30 (e.g. skill 0.5 => 15%, skill 1.0 => 30%).
// Secondaries are NOT collected/frozen when an immediate refuse triggers.
//
// SECONDARY TARGETS (within 5m of primary, non-civilian challenges only):
// Nearby enemies also freeze and play shocked animations during the challenge.
// They roll independently after the same wait with a lower base chance (0.15 vs 0.25).
// A cascade bonus (+0.15) applies if the primary surrendered.
// =============================================================================

params ["_player", "_targetUnit", ["_playerDir", -1]];
if (!isServer) exitWith {
    diag_log "[FAC SurrenderChallenge] ERROR: Script ran on non-server. Exiting.";
};

["SURRENDER CHALLENGE -- PROCESSING."] remoteExec ["systemChat", _player];

if (isNull _player) exitWith {
    diag_log "[FAC SurrenderChallenge] ERROR: _player is null, cannot send feedback.";
};

// -----------------------------------------------------------------------------
// Debug: FAC_surrenderChallenge_debug = true in initServer.sqf for verbose chat.
// diag_log always writes to RPT regardless.
// -----------------------------------------------------------------------------
private _debug = missionNamespace getVariable ["FAC_surrenderChallenge_debug", false];
private _dbg = {
    params ["_msg"];
    diag_log ("[FAC SurrenderChallenge] " + _msg);
    if (_debug) then { [_msg] remoteExec ["systemChat", _player] };
};

["Started. Player: " + (name _player) + " | Target: " + (if (isNull _targetUnit) then {"null"} else {name _targetUnit})] call _dbg;

// -----------------------------------------------------------------------------
// Validation guards
// -----------------------------------------------------------------------------
if (_targetUnit getVariable ["surrenderChallenge_active", false]) exitWith {
    ["TARGET ALREADY IN CHALLENGE."] remoteExec ["systemChat", _player];
    ["Rejected: target already in challenge"] call _dbg;
};

if (isNull _targetUnit || {!alive _targetUnit}) exitWith {
    ["INVALID TARGET."] remoteExec ["systemChat", _player];
    ["Rejected: null or dead target"] call _dbg;
};

if (!(_targetUnit isKindOf "Man")) exitWith {
    ["TARGET MUST BE PERSONNEL."] remoteExec ["systemChat", _player];
    ["Rejected: target not Man (isKindOf)"] call _dbg;
};

if (_targetUnit == _player) exitWith {
    ["Rejected: player targeted self"] call _dbg;
};

if (side _targetUnit == side _player) exitWith {
    ["CANNOT CHALLENGE ALLIES."] remoteExec ["systemChat", _player];
    ["Rejected: same side (ally)"] call _dbg;
};

private _isCivilian = (side _targetUnit == CIVILIAN);
private _isACE = isClass (configFile >> "CfgPatches" >> "ace_captives");

private _alreadySurrendered = captive _targetUnit
    || { _isACE && { _targetUnit getVariable ["ace_captives_isSurrendering", false] } }
    || { _isACE && { _targetUnit getVariable ["ace_captives_isHandcuffed", false] } };
if (_alreadySurrendered) exitWith {
    ["TARGET ALREADY SURRENDERED."] remoteExec ["systemChat", _player];
    ["Rejected: target already surrendered"] call _dbg;
};

private _dist = _player distance _targetUnit;
if (_dist > 25) exitWith {
    ["TARGET OUT OF RANGE. MAX 25M."] remoteExec ["systemChat", _player];
    ["Rejected: distance " + (str (round _dist)) + "m > 25m"] call _dbg;
};

// 30° cone in front of player: target must be within ±15° of player's facing direction
private _coneOk = true;
if (_playerDir >= 0) then {
    private _dirToTarget = _player getDir _targetUnit;
    private _diff = abs (_dirToTarget - _playerDir);
    if (_diff > 180) then { _diff = 360 - _diff };
    if (_diff > 15) then {
        ["TARGET NOT IN FRONT OF YOU. USE 30 DEGREE CONE, 25M."] remoteExec ["systemChat", _player];
        ["Rejected: target outside 30° cone (diff " + (str (round _diff)) + "°)"] call _dbg;
        _coneOk = false;
    };
};
if (!_coneOk) exitWith {};

["Validation passed. Distance: " + (str (round _dist)) + "m"] call _dbg;

// =============================================================================
// Helper closures
// =============================================================================

// Apply surrender outcome to a unit.
private _fnc_doSurrender = {
    params ["_unit", "_ace"];
    // Drop primary weapon to the ground. WeaponHolder preserves weapon + attachments.
    private _primaryWeapon = primaryWeapon _unit;
    if (_primaryWeapon != "") then {
        private _holder = createVehicle ["WeaponHolder", getPosATL _unit, [], 0, "NONE"];
        _holder addWeaponCargoGlobal [_primaryWeapon, 1];
        _unit removeWeapon _primaryWeapon;
    };
    _unit setBehaviour "SAFE";
    (group _unit) setCombatMode "BLUE";
    if (_ace) then {
        _unit switchMove "";  // Break shocked loop; ACE applies its own hands-up animation.
        [_unit, true] call ace_captives_fnc_setSurrendered;
    } else {
        _unit switchMove "AmovPercMstpSsurWnonDnon";
        _unit playMoveNow "AmovPercMstpSsurWnonDnon";
        _unit setCaptive true;
        _unit setUnitPos "MIDDLE";
        _unit disableAI "PATH";
    };
};

// Spawn a server-side escape monitor for a surrendered unit.
// Checks every 20s whether the unit should attempt to escape.
// Immune while: ACE zip-tied (ace_captives_isHandcuffed) or loaded in a vehicle.
// On escape: armed units go hostile; unarmed units flee.
private _fnc_spawnEscapeMonitor = {
    params ["_unit", "_ace"];
    [_unit, _ace, _player] spawn {
        params ["_unit", "_ace", "_notifyPlayer"];

        sleep 15;  // Brief settle time before first check.

        while { alive _unit && captive _unit } do {
            sleep 20;

            if (!alive _unit || !captive _unit) exitWith {};

            // Immune if zip-tied (ACE handcuffed) or physically inside a vehicle.
            if (_ace && { _unit getVariable ["ace_captives_isHandcuffed", false] }) then { continue };
            if (vehicle _unit != _unit) then { continue };

            // Base escape chance. Large boost when no players are watching.
            private _chance = 0.05;
            private _watchers = { isPlayer _x && alive _x && (_x distance _unit < 30) } count allUnits;
            if (_watchers == 0) then { _chance = _chance + 0.30 };

            if (random 1 < _chance) then {
                // Clear surrender state.
                if (_ace) then {
                    [_unit, false] call ace_captives_fnc_setSurrendered;
                };
                _unit setCaptive false;
                _unit enableAI "PATH";

                // Armed (has secondary/handgun since primary was dropped) → go hostile.
                // Unarmed → flee.
                private _hasWeapon = handgunWeapon _unit != "";
                if (_hasWeapon) then {
                    _unit enableAI "AUTOTARGET";
                    _unit enableAI "TARGET";
                    _unit setBehaviour "COMBAT";
                    (group _unit) setCombatMode "RED";
                    private _nearestEnemy = _unit findNearestEnemy _unit;
                    if (!isNull _nearestEnemy) then { _unit doTarget _nearestEnemy };
                    ["PRISONER ESCAPED -- NOW HOSTILE!"] remoteExec ["systemChat", _notifyPlayer];
                } else {
                    _unit disableAI "AUTOTARGET";
                    _unit disableAI "TARGET";
                    _unit setBehaviour "SAFE";
                    (group _unit) setCombatMode "BLUE";
                    _unit doMove (_unit getPos [200 + random 200, random 360]);
                    ["PRISONER ESCAPED -- FLEEING!"] remoteExec ["systemChat", _notifyPlayer];
                };

                diag_log format ["[FAC SurrenderChallenge] %1 escaped. Armed: %2.", name _unit, _hasWeapon];
            };
        };
    };
};

// Apply refuse outcome to a unit (enableAI must be called before this).
private _fnc_doRefuse = {
    params ["_unit", "_prevBehav", "_prevCombat"];
    _unit setBehaviour _prevBehav;
    (group _unit) setCombatMode _prevCombat;
    _unit switchMove "AmovPercMstpSnonWnonDnon";
    _unit doTarget _player;
    _unit doFire _player;
};

// Compute shocked animation name for a unit based on weapon type.
private _fnc_shockedAnim = {
    params ["_unit"];
    private _isPistol = (currentWeapon _unit) == (handgunWeapon _unit) && { handgunWeapon _unit != "" };
    if (_isPistol) then {
        "Acts_ShockedUnarmed_2_Loop"
    } else {
        selectRandom ["Acts_Shocked_1_Loop", "Acts_Shocked_3", "Acts_Shocked_4_Loop"]
    }
};

// =============================================================================
// Simplified decision: (1) refuse immediately, (2) consider -> refuse, (3) consider -> surrender
// LAMBS AI: when lambs_danger is loaded, AI may still use LAMBS behaviours; we only set captive/surrendered state.
// =============================================================================

// Mark primary active and freeze AI.
_targetUnit setVariable ["surrenderChallenge_active", true, true];
private _prevBehaviour = behaviour _targetUnit;
private _prevCombatMode = combatMode (group _targetUnit);
_targetUnit disableAI "AUTOTARGET";
_targetUnit disableAI "TARGET";
_targetUnit setBehaviour "SAFE";
(group _targetUnit) setCombatMode "BLUE";

// =============================================================================
// Main challenge
// =============================================================================
private _surrenders = false;
private _secondaries = [];  // [[unit, prevBehav, prevCombat], ...]

if (_isCivilian) then {
    ["CIV -- SURRENDERS IMMEDIATELY."] remoteExec ["systemChat", _player];
    ["Civilian: 100% surrender, no wait"] call _dbg;
    _surrenders = true;
} else {
    // (1) Refuse immediately: skill-based chance; no animation.
    private _unitSkill = skill _targetUnit;
    if (random 1 < (_unitSkill * 0.35)) then {
        [format ["IMMEDIATE REFUSE (skill %1%%)", round (_unitSkill * 100)]] call _dbg;
        // _surrenders stays false; no secondaries.
    } else {
        // (2) Consider: freeze secondaries within 5m, primary shocked anim, wait.
        {
            private _u = _x;
            if (
                _u != _targetUnit
                && { alive _u }
                && { !isPlayer _u }
                && { !captive _u }
                && { side _u == side _targetUnit }
                && { !(_u getVariable ["surrenderChallenge_active", false]) }
                && { !(_isACE && { _u getVariable ["ace_captives_isSurrendering", false] }) }
                && { !(_isACE && { _u getVariable ["ace_captives_isHandcuffed", false] }) }
            ) then {
                _secondaries pushBack [_u, behaviour _u, combatMode (group _u)];
                _u setVariable ["surrenderChallenge_active", true, true];
                _u disableAI "AUTOTARGET";
                _u disableAI "TARGET";
                _u setBehaviour "SAFE";
                (group _u) setCombatMode "BLUE";
                _u switchMove ([_u] call _fnc_shockedAnim);
            };
        } forEach (nearestObjects [_targetUnit, ["Man"], 5]);
        [format ["%1 secondary(ies) within 5m frozen", count _secondaries]] call _dbg;

        _targetUnit switchMove ([_targetUnit] call _fnc_shockedAnim);
        private _challengeDuration = 3.5;
        [format ["CHALLENGE INITIATED. %1 SECONDS.", round _challengeDuration]] remoteExec ["systemChat", _player];
        sleep _challengeDuration;

        _dist = _player distance _targetUnit;
        // (3) Consider -> surrender or refuse: single roll. Base 0.45, +0.15 if within 10m.
        private _surrenderChance = 0.45;
        if (_dist < 10) then { _surrenderChance = 0.60 };
        private _roll = random 1;
        _surrenders = _roll < _surrenderChance;
        [format ["Consider roll: chance=%1%% roll=%2 => %3", round (_surrenderChance * 100), round (_roll * 100), if (_surrenders) then {"SURRENDER"} else {"REFUSE"}]] call _dbg;
    };
};

// =============================================================================
// Apply primary outcome
// =============================================================================
_targetUnit enableAI "AUTOTARGET";
_targetUnit enableAI "TARGET";
_targetUnit setVariable ["surrenderChallenge_active", false, true];

if (_surrenders) then {
    [_targetUnit, ["FAC_surrenderAffirmative", 80, 1]] remoteExec ["say3D", 0];
    [_targetUnit, _isACE] call _fnc_doSurrender;
    [_targetUnit, _isACE] call _fnc_spawnEscapeMonitor;
    ["TARGET SURRENDERED."] remoteExec ["systemChat", _player];
    ["Outcome: SURRENDER"] call _dbg;
} else {
    [_targetUnit, ["FAC_surrenderNegative", 80, 1]] remoteExec ["say3D", 0];
    [_targetUnit, _prevBehaviour, _prevCombatMode] call _fnc_doRefuse;
    ["TARGET REFUSED. ENGAGING."] remoteExec ["systemChat", _player];
    ["Outcome: REFUSE"] call _dbg;
};

// =============================================================================
// Apply secondary outcomes
// =============================================================================
if (count _secondaries > 0) then {
    private _secSurrendered = 0;
    private _secRefused = 0;

    {
        _x params ["_unit", "_prevBehav", "_prevCombat"];
        _unit enableAI "AUTOTARGET";
        _unit enableAI "TARGET";
        _unit setVariable ["surrenderChallenge_active", false, true];

        if (!alive _unit) then {
            [format ["Secondary %1 dead during challenge, skipping", name _unit]] call _dbg;
        } else {
            // Simplified: single roll 0.35 for secondaries.
            private _secChance = 0.35;
            private _secRoll = random 1;
            private _secSurrenders = _secRoll < _secChance;
            [format ["Secondary %1: chance=35%% roll=%2 => %3", name _unit, round (_secRoll * 100), if (_secSurrenders) then {"SURRENDER"} else {"REFUSE"}]] call _dbg;

            if (_secSurrenders) then {
                [_unit, ["FAC_surrenderAffirmative", 80, 1]] remoteExec ["say3D", 0];
                [_unit, _isACE] call _fnc_doSurrender;
                [_unit, _isACE] call _fnc_spawnEscapeMonitor;
                _secSurrendered = _secSurrendered + 1;
            } else {
                [_unit, _prevBehav, _prevCombat] call _fnc_doRefuse;
                _secRefused = _secRefused + 1;
            };
        };
    } forEach _secondaries;

    [format ["%1 NEARBY: %2 SURRENDERED, %3 REFUSED.", count _secondaries, _secSurrendered, _secRefused]] remoteExec ["systemChat", _player];
    [format ["Secondaries: %1/%2 surrendered", _secSurrendered, count _secondaries]] call _dbg;
};
