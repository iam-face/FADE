// =============================================================================
// FADE_Profile.sqf  -  optional mission load / runtime metrics (server + client)
// Enable: FADE_profileMissionLoad = true in rsc\Config.sqf
// RPT tag: [FAC profile]
// =============================================================================

if (isNil "FADE_profileMissionLoad") then {
    FADE_profileMissionLoad = false;
};

FADE_profile_log = {
    params ["_label", ["_t0", -1]];
    if !(missionNamespace getVariable ["FADE_profileMissionLoad", false]) exitWith {};
    private _msg = if (_t0 < 0) then {
        format ["[FAC profile] %1", _label]
    } else {
        format ["[FAC profile] %1: %2 s", _label, diag_tickTime - _t0]
    };
    diag_log _msg;
};

FADE_profile_missionStartMark = {
    if !(missionNamespace getVariable ["FADE_profileMissionLoad", false]) exitWith {};
    missionNamespace setVariable ["FADE_profile_missionStartT", diag_tickTime];
    diag_log "[FAC profile] mission start requested";
};

FADE_profile_missionRunMark = {
    if !(missionNamespace getVariable ["FADE_profileMissionLoad", false]) exitWith {};
    private _t0 = missionNamespace getVariable ["FADE_profile_missionStartT", -1];
    if (_t0 < 0) exitWith {};
    diag_log format ["[FAC profile] mission runner entered: %1 s since start request", diag_tickTime - _t0];
};
