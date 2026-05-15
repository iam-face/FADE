// =============================================================================
// FADE_IntelClient.sqf -- Hold action to read intel (client / initPlayerLocal)
// =============================================================================

// Escape for diary structured text (mirrors rsc/CivTalkGui.sqf; this file loads before CivTalk).
FADE_intel_escapeForDiary = {
    params ["_s"];
    if !(_s isEqualType "") then { _s = str _s };
    private _a = _s splitString "&";
    _s = _a joinString "&amp;";
    _a = _s splitString "<";
    _s = _a joinString "&lt;";
    _a = _s splitString ">";
    _s = _a joinString "&gt;";
    private _nl = toString [10];
    _a = _s splitString _nl;
    _s = _a joinString "<br/>";
    _s
};

// Map → Intel diary (Briefing.sqf subject "FAC_Intel"); server remoteExec when building/asset intel is consumed.
FADE_intel_clientAppendIntelDiary = {
    params [["_headerName", "Intel"], ["_whenStr", ""], ["_bodyRaw", ""], ["_kind", "Report"]];
    if (!hasInterface) exitWith {};
    if (isNull player) exitWith {};
    if !(_bodyRaw isEqualType "") then { _bodyRaw = str _bodyRaw };
    player createDiarySubject ["FAC_Intel", "Intel"];
    private _escBody = [_bodyRaw] call FADE_intel_escapeForDiary;
    private _escHdr = [_headerName] call FADE_intel_escapeForDiary;
    private _escWhen = [_whenStr] call FADE_intel_escapeForDiary;
    private _escKind = [_kind] call FADE_intel_escapeForDiary;
    private _html = (
        "<font color='#87CEEB'>" + _escHdr + "</font><br/><font color='#A0B4C8'>" + _escWhen + " · " + _escKind + "</font><br/><br/>"
        + "<font color='#FFFFFF'>" + _escBody + "</font>"
    );
    private _title = _headerName;
    if ((count _title) > 40) then { _title = (_title select [0, 37]) + "..." };
    player createDiaryRecord ["FAC_Intel", [_title, _html]];
};

FADE_intel_clientRegister = {
    params [["_obj", objNull]];
    if (!hasInterface) exitWith {};
    if (isNull _obj) exitWith {};
    if (_obj getVariable ["FADE_intelConsumed", false]) exitWith {};
    if (_obj getVariable ["FADE_intel_localHoldAdded", false]) exitWith {};
    _obj setVariable ["FADE_intel_localHoldAdded", true, false];

    private _dist = _obj getVariable ["FADE_intelInteractDistM", missionNamespace getVariable ["FADE_intelInteractDistM", 6]];
    private _dur = missionNamespace getVariable ["FADE_intelHoldDurationSec", 5];

    [
        _obj,
        "Read intel",
        "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
        "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
        format [
            "alive player && {!isNull _target} && {player distance _target < %1} && {!(_target getVariable ['FADE_intelConsumed', false])}",
            _dist + 0.25
        ],
        format ["alive player && {!isNull _target} && {player distance _target < %1}", _dist + 0.25],
        {},
        {},
        {
            private _target = _this select 0;
            private _caller = _this select 1;
            if (!(_caller isEqualTo player)) exitWith {};
            [_target, _caller] remoteExec ["FADE_intel_serverTryRead", 2];
        },
        {},
        [],
        _dur,
        0,
        false,
        false
    ] call BIS_fnc_holdActionAdd;
};

FADE_intel_clientEnsureSelfDeliverAction = {
    if (!hasInterface || { isNull player }) exitWith {};
    if (isNil { player getVariable "FADE_intelDeliverActionId_local" }) then {
        private _aid = player addAction [
            "Process carried intel at HQ",
            {
                _this params ["_target", "_caller"];
                if (!(_caller isEqualTo player)) exitWith {};
                [_caller] remoteExec ["FADE_intel_serverDeliverAtBase", 2];
            },
            nil,
            6,
            true,
            true,
            "",
            "(player getVariable ['FADE_intelCarryCount', 0]) > 0 && { (player distance2D (missionNamespace getVariable ['FADE_basePos', [0,0,0]])) <= 50 }",
            5
        ];
        player setVariable ["FADE_intelDeliverActionId_local", _aid, false];
    };
};

FADE_intel_clientEnsureSpecialistHandoffActions = {
    if (!hasInterface) exitWith {};
    {
        if (isPlayer _x && { alive _x } && { isNil { _x getVariable "FADE_intelHandoffActionId_local" } }) then {
            private _aid = _x addAction [
                "Give intel package",
                {
                    _this params ["_target", "_caller"];
                    if (!(_caller isEqualTo player)) exitWith {};
                    [_caller, _target] remoteExec ["FADE_intel_serverTransferToSpecialist", 2];
                },
                nil,
                6,
                true,
                true,
                "",
                "alive _target && {_target getVariable ['FADE_intelSpecialist', false]} && {!(_target isEqualTo player)} && {(player getVariable ['FADE_intelCarryCount', 0]) > 0} && {player distance _target < 4}",
                5
            ];
            _x setVariable ["FADE_intelHandoffActionId_local", _aid, false];
        };
    } forEach allPlayers;
};

[] spawn {
    waitUntil { sleep 1; hasInterface && {!isNull player} };
    while { true } do {
        [] call FADE_intel_clientEnsureSelfDeliverAction;
        [] call FADE_intel_clientEnsureSpecialistHandoffActions;
        sleep 5;
    };
};
