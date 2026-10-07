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
        "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_takeOffVest_ca.paa",
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
        _dur
    ] call FADE_client_addHoldAction;
};
