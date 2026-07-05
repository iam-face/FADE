// =============================================================================
// MissionConvoyMapPick.sqf  -  Intercept Convoy: map click start, then end (client)
// Start via execVM rsc\MissionConvoyMapPick_exec.sqf
// =============================================================================
if (!hasInterface) exitWith {};

FAC_convoyMapPick_fnc_buildStartHint = {
    params ["_rem"];
    private _timeout = missionNamespace getVariable ["FADE_missionMapPickTimeoutSec", 20];
    [_rem, [
        "Click the map for convoy START.",
        "Nearest road within 500 m is used."
    ], "", _timeout] call FADE_mapPick_formatCountdownHint
};

FAC_convoyMapPick_fnc_buildEndHint = {
    params ["_rem"];
    private _startPos = missionNamespace getVariable ["FAC_convoyMapPick_start", []];
    private _grid = if (count _startPos >= 2) then { mapGridPosition _startPos } else { "?" };
    private _timeout = missionNamespace getVariable ["FADE_missionMapPickTimeoutSec", 20];
    [_rem, [
        format ["Start: grid %1.", _grid],
        "Click the map for convoy END.",
        "Each point snaps to the nearest road within 500 m."
    ], "", _timeout] call FADE_mapPick_formatCountdownHint
};

FAC_convoyMapPick_fnc_onTimeout = {
    hint "Convoy route pick cancelled - no map location selected.";
    systemChat "Convoy route pick cancelled - no map location selected.";
    missionNamespace setVariable ["FAC_convoyMapPick_start", nil];
};

FAC_convoyMapPick_fnc_onStartClick = {
    params ["_startPos"];
    missionNamespace setVariable ["FAC_convoyMapPick_start", _startPos];
    private _timeout = missionNamespace getVariable ["FADE_missionMapPickTimeoutSec", 20];
    [
        "FAC_convoyMapPick_active",
        "FAC_convoyMapPick_mapEh",
        _timeout,
        FAC_convoyMapPick_fnc_buildEndHint,
        FAC_convoyMapPick_fnc_onEndClick,
        FAC_convoyMapPick_fnc_onTimeout,
        true
    ] call FADE_mapClickPick_start;
};

FAC_convoyMapPick_fnc_onEndClick = {
    params ["_endPos"];
    private _startPos = missionNamespace getVariable ["FAC_convoyMapPick_start", []];
    missionNamespace setVariable ["FAC_convoyMapPick_start", nil];
    if !(count _startPos >= 2) exitWith {
        [] call FAC_convoyMapPick_fnc_onTimeout;
    };
    [_startPos, _endPos, player] spawn {
        params ["_startPos", "_endPos", "_pl"];
        systemChat "INTERCEPT CONVOY: Route submitted — setting up mission, please wait...";
        ["InterceptConvoy", _pl, _startPos, "", "", "", _endPos] remoteExec ["FADE_startMission", 2];
        hint parseText "<t size='1.1' color='#A0D0A0'>Loading mission...</t><br/><t color='#808080'>Details will be provided shortly.</t>";
    };
};

FAC_convoyMapPick_fnc_start = {
    if ("InterceptConvoy" in (missionNamespace getVariable ["FADE_disabledMissionTypes", []])) exitWith {
        systemChat "INTERCEPT CONVOY: temporarily disabled.";
    };
    if (missionNamespace getVariable ["FAC_convoyMapPick_active", false]) exitWith {
        systemChat "MISSION: convoy route pick already in progress.";
    };
    if (missionNamespace getVariable ["FAC_missionMapPick_active", false]) exitWith {
        systemChat "MISSION: map location pick already in progress.";
    };
    missionNamespace setVariable ["FAC_convoyMapPick_start", nil];
    private _timeout = missionNamespace getVariable ["FADE_missionMapPickTimeoutSec", 20];
    [
        "FAC_convoyMapPick_active",
        "FAC_convoyMapPick_mapEh",
        _timeout,
        FAC_convoyMapPick_fnc_buildStartHint,
        FAC_convoyMapPick_fnc_onStartClick,
        FAC_convoyMapPick_fnc_onTimeout,
        true
    ] call FADE_mapClickPick_start;
};

missionNamespace setVariable ["FAC_convoyMapPick_fnc_start", FAC_convoyMapPick_fnc_start];
