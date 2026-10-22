// =============================================================================
// FADE_FieldIntelClient.sqf — body search hold action (client)
// =============================================================================

FADE_fieldIntel_clientRegisterBody = {
    params [["_corpse", objNull]];
    if (!hasInterface) exitWith {};
    if (isNull _corpse) exitWith {};
    if (_corpse getVariable ["FADE_fieldIntel_searched", false]) exitWith {};
    if (_corpse getVariable ["FADE_fieldIntel_clientHoldAdded", false]) exitWith {};
    _corpse setVariable ["FADE_fieldIntel_clientHoldAdded", true, false];

    private _dist = missionNamespace getVariable ["FADE_fieldIntelBodySearchDistM", 3];
    private _dur = missionNamespace getVariable ["FADE_fieldIntelBodySearchHoldSec", 6];

    [
        _corpse,
        "Search body for intel",
        "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
        format [
            "!alive _target && {alive player} && {!(_target getVariable ['FADE_fieldIntel_searched', false])} && {player distance _target < %1}",
            _dist + 0.5
        ],
        format ["!alive _target && {alive player} && {player distance _target < %1}", _dist + 0.5],
        {
            private _target = _this select 0;
            private _caller = _this select 1;
            if (!(_caller isEqualTo player)) exitWith {};
            [_target, _caller] remoteExecCall ["FADE_fieldIntel_serverBodySearch", 2];
        },
        _dur
    ] call FADE_client_addHoldAction;
};
