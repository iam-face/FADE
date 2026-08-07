// =============================================================================
// FADE_RecoverObjectClient.sqf — recover-object Pick up hold action (client)
// =============================================================================
// Server registers via FADE_objective_addRecoverHoldAction → remoteExec JIP.
// Completion: remoteExec FADE_assetIntelTakeServer (ServerGameplayMissionAdmin).

FADE_recover_clientRegisterHold = {
    params [["_objCase", objNull]];
    if (!hasInterface) exitWith {};
    if (isNull _objCase) exitWith {};
    if (_objCase getVariable ["FADE_recover_clientHoldAdded", false]) exitWith {};
    private _taskId = _objCase getVariable ["FADE_recoverTaskId", ""];
    if (_taskId == "") exitWith {};
    _objCase setVariable ["FADE_recover_clientHoldAdded", true, false];

    private _dist = missionNamespace getVariable ["FADE_recoverHoldDistM", 3];
    private _dur = missionNamespace getVariable ["FADE_recoverHoldSec", 2];
    private _label = _objCase getVariable ["FADE_recoverObjectDisplayName", ""];
    if (!(_label isEqualType "") || { _label == "" }) then { _label = "package" };
    private _title = format ["Pick up %1", _label];

    [
        _objCase,
        _title,
        "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
        "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
        format [
            "alive player && {!isNull _target} && {player distance _target < %1} && {!((_target getVariable ['FADE_recoverTaskId', '']) isEqualTo '')}",
            _dist + 0.5
        ],
        format ["alive player && {!isNull _target} && {player distance _target < %1}", _dist + 0.5],
        {},
        {},
        {
            private _target = _this select 0;
            private _caller = _this select 1;
            if (!(_caller isEqualTo player)) exitWith {};
            private _cTaskId = _target getVariable ["FADE_recoverTaskId", ""];
            if (_cTaskId == "") exitWith {};
            [_cTaskId, _target, _caller] remoteExec ["FADE_assetIntelTakeServer", 2];
        },
        {},
        [],
        _dur,
        0,
        false,
        false
    ] call BIS_fnc_holdActionAdd;
};
