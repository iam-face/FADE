// =============================================================================
// MissionPickOverlay.sqf  -  shared overlay helpers for Manage Missions (60002)
// =============================================================================
if (!hasInterface) exitWith {};

FAC_missionPickOverlay_baseIdcs = [60133, 60110, 60111, 60112, 60113, 60114, 60115, 60120, 60131, 60121, 60130, 60134, 60135, 60136, 60150, 60151, 60152, 60153];

FAC_missionPickOverlay_setBaseVisible = {
    params [["_show", true]];
    private _d = findDisplay 60002;
    if (isNull _d) exitWith {};
    {
        private _c = _d displayCtrl _x;
        if (!isNull _c) then { _c ctrlShow _show };
    } forEach FAC_missionPickOverlay_baseIdcs;
};

FAC_missionPickOverlay_destroy = {
    params [["_nsKey", "FAC_mpick_overlayCtrls"]];
    private _lst = uinamespace getVariable [_nsKey, []];
    { if (!isNull _x) then { ctrlDelete _x } } forEach _lst;
    uinamespace setVariable [_nsKey, nil];
    [true] call FAC_missionPickOverlay_setBaseVisible;
};

// Returns array of created controls. _layout: [bgY, bgH, title, helpH] optional.
FAC_missionPickOverlay_createShell = {
    params [
        "_display",
        "_titleText",
        ["_helpText", ""],
        ["_idcBase", 60340],
        ["_layout", [0.12, 0.58, 0.048, 0.14]]
    ];
    _layout params ["_bgY", "_bgH", "_titleH", "_helpH"];
    private _controls = [];
    private _bg = _display ctrlCreate ["RscText", _idcBase];
    _bg ctrlSetPosition [0.02, _bgY, 0.96, _bgH];
    _bg ctrlSetBackgroundColor [0.06, 0.07, 0.1, 0.96];
    _bg ctrlCommit 0;
    _controls pushBack _bg;
    private _title = _display ctrlCreate ["RscText", _idcBase + 1];
    _title ctrlSetPosition [0.02, _bgY, 0.96, _titleH];
    _title ctrlSetText _titleText;
    _title ctrlSetBackgroundColor [0.15, 0.28, 0.42, 1];
    _title ctrlCommit 0;
    _controls pushBack _title;
    if (_helpText != "") then {
        private _help = _display ctrlCreate ["RscEdit", _idcBase + 2];
        _help ctrlSetPosition [0.06, _bgY + _titleH + 0.02, 0.88, _helpH];
        _help ctrlSetText _helpText;
        _help ctrlEnable false;
        _help ctrlCommit 0;
        _controls pushBack _help;
    };
    _controls
};

missionNamespace setVariable ["FAC_missionPickOverlay_setBaseVisible", FAC_missionPickOverlay_setBaseVisible];
missionNamespace setVariable ["FAC_missionPickOverlay_destroy", FAC_missionPickOverlay_destroy];
missionNamespace setVariable ["FAC_missionPickOverlay_createShell", FAC_missionPickOverlay_createShell];
