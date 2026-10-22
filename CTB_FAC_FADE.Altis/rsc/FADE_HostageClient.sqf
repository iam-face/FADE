// =============================================================================
// FADE_HostageClient.sqf — hostage free hold action (client)
// =============================================================================

FADE_hostage_clientRegisterHold = {
    params [["_hostage", objNull]];
    if (!hasInterface) exitWith {};
    if (isNull _hostage) exitWith {};
    if (_hostage getVariable ["FADE_hostageFreed", false]) exitWith {};
    if (_hostage getVariable ["FADE_hostage_clientHoldAdded", false]) exitWith {};
    _hostage setVariable ["FADE_hostage_clientHoldAdded", true, false];

    private _dist = missionNamespace getVariable ["FADE_hostageFreeDistM", 3];
    private _dur = missionNamespace getVariable ["FADE_hostageFreeHoldSec", 5];

    [
        _hostage,
        "Free hostage",
        "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_unbind_ca.paa",
        format [
            "alive player && {alive _target} && {!(_target getVariable ['FADE_hostageFreed', false])} && {player distance _target < %1}",
            _dist + 0.5
        ],
        format ["alive player && {alive _target} && {player distance _target < %1}", _dist + 0.5],
        {
            private _target = _this select 0;
            private _caller = _this select 1;
            if (!(_caller isEqualTo player)) exitWith {};
            [_target, _caller] remoteExecCall ["FADE_hostage_serverFree", 2];
        },
        _dur,
        {
            params ["_target", "_caller"];
            if (!(_caller isEqualTo player)) exitWith {};
            if (time < (_target getVariable ["FADE_hostageHelpAt", -10]) + 4) exitWith {};
            _target setVariable ["FADE_hostageHelpAt", time];
            private _file = _target getVariable ["FADE_hostageHelpSound", ""];
            if (_file isEqualTo "") exitWith {};
            private _vol = missionNamespace getVariable ["FADE_hostageCueSpeechVol", 2];
            private _dist = missionNamespace getVariable ["FADE_hostageCueAudibleM", 40];
            playSound3D [_file, _target, true, getPosASL _target, _vol, 1, _dist];
        }
    ] call FADE_client_addHoldAction;
};
