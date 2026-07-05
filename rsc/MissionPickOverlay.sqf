// =============================================================================
// MissionPickOverlay.sqf  -  shared overlay helpers for Manage Missions (60002)
// =============================================================================
if (!hasInterface) exitWith {};

FAC_missionPickOverlay_baseIdcs = [60133, 60110, 60111, 60112, 60113, 60114, 60115, 60120, 60131, 60121, 60130, 60134, 60135, 60136, 60150, 60151, 60152, 60153, 60160, 60161, 60101];

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
    [] call FAC_missionPickOverlay_restoreMissionsBase;
};

FAC_missionPickOverlay_restoreMissionsBase = {
    if (isNull (findDisplay 60002)) exitWith {};
    private _sync = missionNamespace getVariable ["FAC_missionsGui_syncTabs", {}];
    if (_sync isEqualType {}) then {
        [] call _sync;
    } else {
        [true] call FAC_missionPickOverlay_setBaseVisible;
    };
};

// Returns array of created controls.
// _layout: [bgX, bgY, bgW, bgH, titleH, helpH] — defaults to full-width panel.
FAC_missionPickOverlay_createShell = {
    params [
        "_display",
        "_titleText",
        ["_helpText", ""],
        ["_idcBase", 60340],
        ["_layout", [0.18, 0.16, 0.64, 0.50, 0.046, 0.14]]
    ];
    _layout params ["_bgX", "_bgY", "_bgW", "_bgH", "_titleH", "_helpH"];
    private _controls = [];
    private _padX = 0.04;
    private _innerX = _bgX + _padX;
    private _innerW = _bgW - (_padX * 2);
    private _bg = _display ctrlCreate ["RscText", _idcBase];
    _bg ctrlSetPosition [_bgX, _bgY, _bgW, _bgH];
    _bg ctrlSetBackgroundColor FAC_theme_bgOverlay;
    _bg ctrlCommit 0;
    _controls pushBack _bg;
    private _title = _display ctrlCreate ["RscText", _idcBase + 1];
    _title ctrlSetPosition [_bgX, _bgY, _bgW, _titleH];
    _title ctrlSetText _titleText;
    _title ctrlSetBackgroundColor FAC_theme_bgOverlayTitle;
    _title ctrlCommit 0;
    _controls pushBack _title;
    if (_helpText != "") then {
        private _help = _display ctrlCreate ["RscStructuredText", _idcBase + 2];
        _help ctrlSetPosition [_innerX, _bgY + _titleH + 0.012, _innerW, _helpH];
        private _body = (_helpText splitString (toString [10, 10])) joinString "<br/>";
        _help ctrlSetStructuredText parseText format ["<t size='0.85' color='%1'>%2</t>", FAC_theme_htmlBody, _body];
        _help ctrlCommit 0;
        _controls pushBack _help;
    };
    _controls
};

// Style helpers for overlay buttons (call after ctrlCreate).
FAC_missionPick_stylePrimary = {
    params ["_ctrl"];
    if (!isNull _ctrl) then { _ctrl ctrlSetBackgroundColor FAC_theme_btnPrimary };
};

FAC_missionPick_styleNeutral = {
    params ["_ctrl"];
    if (!isNull _ctrl) then { _ctrl ctrlSetBackgroundColor FAC_theme_btnNeutral };
};

FAC_missionPick_styleDanger = {
    params ["_ctrl"];
    if (!isNull _ctrl) then { _ctrl ctrlSetBackgroundColor FAC_theme_btnDanger };
};

FAC_missionPick_styleStart = {
    params ["_ctrl"];
    if (!isNull _ctrl) then { _ctrl ctrlSetBackgroundColor FAC_theme_btnStart };
};

// Standard participant-pick footer: Add → | ← Remove | Start | Cancel
FAC_missionPick_createParticipantFooter = {
    params ["_display", "_idcBase", "_y", "_nsPickFn"];
    private _pickFn = missionNamespace getVariable [_nsPickFn, {}];
    private _controls = [];
    private _ba = _display ctrlCreate ["RscButton", _idcBase];
    _ba ctrlSetPosition [0.04, _y, 0.20, 0.045];
    _ba ctrlSetText "Add →";
    [_ba] call FAC_missionPick_styleNeutral;
    _ba ctrlAddEventHandler ["ButtonClick", { ["add", []] call _pickFn }];
    _ba ctrlCommit 0;
    _controls pushBack _ba;
    private _br = _display ctrlCreate ["RscButton", _idcBase + 1];
    _br ctrlSetPosition [0.26, _y, 0.20, 0.045];
    _br ctrlSetText "← Remove";
    [_br] call FAC_missionPick_styleNeutral;
    _br ctrlAddEventHandler ["ButtonClick", { ["remove", []] call _pickFn }];
    _br ctrlCommit 0;
    _controls pushBack _br;
    private _bs = _display ctrlCreate ["RscButton", _idcBase + 2];
    _bs ctrlSetPosition [0.52, _y, 0.22, 0.045];
    _bs ctrlSetText "Start";
    [_bs] call FAC_missionPick_styleStart;
    _bs ctrlAddEventHandler ["ButtonClick", { ["confirm", []] call _pickFn }];
    _bs ctrlCommit 0;
    _controls pushBack _bs;
    private _bc = _display ctrlCreate ["RscButton", _idcBase + 3];
    _bc ctrlSetPosition [0.76, _y, 0.20, 0.045];
    _bc ctrlSetText "Cancel";
    [_bc] call FAC_missionPick_styleDanger;
    _bc ctrlAddEventHandler ["ButtonClick", { ["close", []] call _pickFn }];
    _bc ctrlCommit 0;
    _controls pushBack _bc;
    _controls
};

missionNamespace setVariable ["FAC_missionPickOverlay_restoreMissionsBase", FAC_missionPickOverlay_restoreMissionsBase];
missionNamespace setVariable ["FAC_missionPickOverlay_setBaseVisible", FAC_missionPickOverlay_setBaseVisible];
missionNamespace setVariable ["FAC_missionPickOverlay_destroy", FAC_missionPickOverlay_destroy];
missionNamespace setVariable ["FAC_missionPickOverlay_createShell", FAC_missionPickOverlay_createShell];
missionNamespace setVariable ["FAC_missionPick_stylePrimary", FAC_missionPick_stylePrimary];
missionNamespace setVariable ["FAC_missionPick_styleNeutral", FAC_missionPick_styleNeutral];
missionNamespace setVariable ["FAC_missionPick_styleDanger", FAC_missionPick_styleDanger];
missionNamespace setVariable ["FAC_missionPick_styleStart", FAC_missionPick_styleStart];
missionNamespace setVariable ["FAC_missionPick_createParticipantFooter", FAC_missionPick_createParticipantFooter];
