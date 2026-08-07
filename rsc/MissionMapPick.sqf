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
    private _suffix = [_mt, _rem >= 0, _rem] call FAC_missionMapPick_fnc_missionTypeHintSuffix;
    private _intro = ["Click the map for mission area.", _suffix];
    [_rem, _intro, "", _timeout] call FADE_mapPick_formatCountdownHint
};

FAC_missionMapPick_fnc_onValidClick = {
    params ["_clickPos"];
    private _mt = missionNamespace getVariable ["FAC_missionMapPick_type", ""];
    if (_mt == "") exitWith {};
    missionNamespace setVariable ["FAC_missionMapPick_type", nil];
    // #region agent log
    diag_log format ["#DBGc2f21e {""sessionId"":""c2f21e"",""hypothesisId"":""C"",""location"":""MissionMapPick.sqf:onValidClick"",""message"":""client map click"",""data"":{""missionType"":""%1"",""clickPos"":%2},""timestamp"":%3}", _mt, _clickPos, diag_tickTime];
    // #endregion
    [_mt, player, _clickPos] spawn {
        params ["_mt", "_pl", "_clickPos"];
        if (_mt == "PointDefense") then {
            private _dur = missionNamespace getVariable ["FAC_pdPick_durationSec", uinamespace getVariable ["FAC_pdPick_durationSec", missionNamespace getVariable ["FADE_pointDefenseDurationSec", 1200]]];
            [_pl, _clickPos, _dur] remoteExec ["FADE_startPointDefense", 2];
        } else {
            [_mt, _pl, _clickPos] remoteExec ["FADE_startMission", 2];
        };
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
    if (_missionType == "InterceptConvoy") exitWith {
        systemChat "INTERCEPT CONVOY: use Map click (choose start and end) from the location picker.";
    };
    if (_missionType == "Raid") exitWith {
        systemChat "RAID: use Map click (choose all objective zones) from the location picker.";
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
