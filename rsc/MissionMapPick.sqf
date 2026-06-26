// =============================================================================
// MissionMapPick.sqf  -  map click for mission AO (client). Uses FADE_MapClickPick.
// Start via execVM rsc\MissionMapPick_exec.sqf (onMapSingleClick _pos reliability).
// =============================================================================
if (!hasInterface) exitWith {};

FAC_missionMapPick_fnc_missionTypeHintSuffix = {
    params ["_missionType", ["_withRemaining", false], ["_rem", 0]];
    private _snapTypes = missionNamespace getVariable ["FADE_missionMapClickSnapCivZoneTypes", []];
    if (_missionType in _snapTypes) then {
        if (_withRemaining) then {
            "Snaps to nearest civ settlement zone."
        } else {
            "Settlement missions snap to the nearest civ zone to your click."
        }
    } else {
        if (_withRemaining) then {
            "Search: 250 m -> 5 km -> whole map (closest valid site)."
        } else {
            "Search expands: 250 m, 500 m, 1 km, 2.5 km, 5 km, then whole map  -  as close as possible to your click."
        }
    }
};

FAC_missionMapPick_fnc_buildHint = {
    params ["_rem"];
    private _mt = missionNamespace getVariable ["FAC_missionMapPick_type", ""];
    private _timeout = missionNamespace getVariable ["FADE_missionMapPickTimeoutSec", 20];
    if (_rem < 0) then {
        format [
            "Click the map for mission area.%1%2You have %3 seconds - mission aborts if you do not click.",
            toString [10, 10],
            [_mt, false] call FAC_missionMapPick_fnc_missionTypeHintSuffix,
            _timeout
        ]
    } else {
        format [
            "Click the map for mission area.%1%2%3 s remaining - mission aborts if you do not click.",
            toString [10, 10],
            [_mt, true, _rem] call FAC_missionMapPick_fnc_missionTypeHintSuffix,
            _rem
        ]
    }
};

FAC_missionMapPick_fnc_onValidClick = {
    params ["_clickPos"];
    private _mt = missionNamespace getVariable ["FAC_missionMapPick_type", ""];
    if (_mt == "") exitWith {};
    missionNamespace setVariable ["FAC_missionMapPick_type", nil];
    [_mt, player, _clickPos] spawn {
        params ["_mt", "_pl", "_clickPos"];
        [_mt, _pl, _clickPos] remoteExec ["FADE_startMission", 2];
        hint parseText "<t size='1.1' color='#A0D0A0'>Loading mission...</t><br/><t color='#808080'>Details will be provided shortly.</t>";
    };
};

FAC_missionMapPick_fnc_onTimeout = {
    hint "Mission start cancelled - no map location selected.";
    systemChat "Mission start cancelled - no map location selected.";
    missionNamespace setVariable ["FAC_missionMapPick_type", nil];
};

FAC_missionMapPick_fnc_start = {
    params ["_missionType"];
    if (_missionType isEqualType []) then { _missionType = _missionType param [0, ""] };
    if (_missionType == "") exitWith {
        systemChat "MISSION: map pick aborted (no mission type).";
    };
    if (_missionType in ["TroopInsert", "TroopExtract"]) exitWith {
        systemChat "TROOP INSERT / EXTRACT: random location only — map click is not supported.";
    };
    if (missionNamespace getVariable ["FAC_missionMapPick_active", false]) exitWith {
        systemChat "MISSION: map location pick already in progress.";
    };
    missionNamespace setVariable ["FAC_missionMapPick_type", _missionType];
    private _timeout = missionNamespace getVariable ["FADE_missionMapPickTimeoutSec", 20];
    [
        "FAC_missionMapPick_active",
        "FAC_missionMapPick_mapEh",
        _timeout,
        FAC_missionMapPick_fnc_buildHint,
        FAC_missionMapPick_fnc_onValidClick,
        FAC_missionMapPick_fnc_onTimeout,
        true
    ] call FADE_mapClickPick_start;
};

missionNamespace setVariable ["FAC_missionMapPick_fnc_start", FAC_missionMapPick_fnc_start];
