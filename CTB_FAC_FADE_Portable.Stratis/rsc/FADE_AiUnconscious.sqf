// FADE_AiUnconscious.sqf
// When FADE_prohibitAiUnconscious is on, a knocked-out AI soldier dies.
// Compiled from init.sqf on every machine: AI in a player group is local to that client.
// Players, civilians, medical dummies, and CASEVAC / CSAR casualties are left down.

if (missionNamespace getVariable ["FADE_prohibitAiUnconscious_installed", false]) exitWith {};

FADE_prohibitAiUnconscious_shouldKill = {
    params ["_unit"];
    if (isNull _unit || {!alive _unit}) exitWith { false };
    if (!local _unit) exitWith { false };
    if (isPlayer _unit) exitWith { false };
    if !(_unit isKindOf "CAManBase") exitWith { false };
    if !(missionNamespace getVariable ["FADE_prohibitAiUnconscious", true]) exitWith { false };
    if (_unit getVariable ["FADE_medTrainingDummy", false]) exitWith { false };
    if (_unit getVariable ["FADE_keepUnconscious", false]) exitWith { false };
    if (side _unit == civilian) exitWith { false };
    true
};

// ACE medical_engine HandleDamage swallows setDamage unless the unit was undamaged.
// setDead is the medical kill (local unit). It moves the state machine to Dead.
FADE_prohibitAiUnconscious_kill = {
    params ["_unit"];
    if !([_unit] call FADE_prohibitAiUnconscious_shouldKill) exitWith {};
    if (!isNil "ace_medical_status_fnc_setDead") then {
        [_unit, "FADE_prohibitAiUnconscious"] call ace_medical_status_fnc_setDead;
    } else {
        _unit setDamage 1;
    };
};

FADE_prohibitAiUnconscious_sweepLocal = {
    {
        if (_x getVariable ["ACE_isUnconscious", false]) then {
            [_x] call FADE_prohibitAiUnconscious_kill;
        };
    } forEach allUnits;
};

FADE_prohibitAiUnconscious_applyLocal = {
    params ["_on"];
    if !(_on isEqualType true) then { _on = _on > 0 };
    missionNamespace setVariable ["FADE_prohibitAiUnconscious", _on];
    if (!isNil "FAC_scenarioGui_syncProhibitAiUnconscious") then {
        [] call FAC_scenarioGui_syncProhibitAiUnconscious;
    };
};

FADE_prohibitAiUnconscious_set = {
    if (!isServer) exitWith {};
    params [["_player", objNull], ["_on", true]];
    if !(_on isEqualType true) then { _on = _on > 0 };
    if (isNull _player || { !([_player] call FAC_playerCanUseScenarioAdmin) }) exitWith {
        if (!isNull _player) then {
            ["Scenario Admin access denied by lobby settings."] remoteExec ["systemChat", _player];
            [missionNamespace getVariable ["FADE_prohibitAiUnconscious", true]] remoteExec ["FADE_prohibitAiUnconscious_applyLocal", _player];
        };
    };
    missionNamespace setVariable ["FADE_prohibitAiUnconscious", _on, true];
    if (_on) then { [] call FADE_prohibitAiUnconscious_sweepLocal };
};

FADE_prohibitAiUnconscious_install = {
    if (missionNamespace getVariable ["FADE_prohibitAiUnconscious_installed", false]) exitWith {};
    if (isNil "CBA_fnc_addEventHandler" || { isNil "CBA_fnc_execNextFrame" }) exitWith {};

    ["ace_unconscious", {
        params ["_unit", "_active"];
        if (!_active) exitWith {};
        if !([_unit] call FADE_prohibitAiUnconscious_shouldKill) exitWith {};
        // Next frame: this event is raised from inside the unconscious transition.
        [{
            params ["_unit"];
            if !(_unit getVariable ["ACE_isUnconscious", false]) exitWith {};
            [_unit] call FADE_prohibitAiUnconscious_kill;
        }, [_unit]] call CBA_fnc_execNextFrame;
    }] call CBA_fnc_addEventHandler;

    "FADE_prohibitAiUnconscious" addPublicVariableEventHandler {
        params ["", "_on"];
        if (!isNil "FAC_scenarioGui_syncProhibitAiUnconscious") then {
            [] call FAC_scenarioGui_syncProhibitAiUnconscious;
        };
        if (_on) then { [] call FADE_prohibitAiUnconscious_sweepLocal };
    };

    if (isServer) then {
        publicVariable "FADE_prohibitAiUnconscious_set";
    };
    if (missionNamespace getVariable ["FADE_prohibitAiUnconscious", true]) then {
        [] call FADE_prohibitAiUnconscious_sweepLocal;
    };
    missionNamespace setVariable ["FADE_prohibitAiUnconscious_installed", true];
};

if (!isNil "CBA_fnc_addEventHandler" && { !isNil "CBA_fnc_execNextFrame" }) then {
    [] call FADE_prohibitAiUnconscious_install;
} else {
    [] spawn {
        waitUntil { sleep 0.1; !isNil "CBA_fnc_addEventHandler" && { !isNil "CBA_fnc_execNextFrame" } };
        [] call FADE_prohibitAiUnconscious_install;
    };
};
