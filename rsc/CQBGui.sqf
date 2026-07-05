// =============================================================================
// CQBGui.sqf - CQB Training Shoothouse GUI (client)
// =============================================================================
// Opens from cqbBoard. Threat type = toggles; spawn chance = Low/Med/High buttons;
// civilian mix = toggle (live OPFOR only). Start/end drill remoteExecs server.
// FADE_cqbDrillActive + FADE_cqbLastResult are publicVariable'd from server.
// =============================================================================

FAC_cqbGui_tabSetupIdcs = [60522, 60523, 60524, 60525, 60526, 60510, 60511, 60515, 60516, 60517, 60512, 60513, 60508, 60504];
FAC_cqbGui_tabInfoIdcs = [60507];

FAC_cqbGui_syncTabs = {
    private _d = findDisplay 60500;
    if (isNull _d) exitWith {};
    private _tab = missionNamespace getVariable ["FAC_cqbGui_tab", "setup"];
    { private _c = _d displayCtrl _x; if (!isNull _c) then { _c ctrlShow (_tab == "setup") } } forEach FAC_cqbGui_tabSetupIdcs;
    { private _c = _d displayCtrl _x; if (!isNull _c) then { _c ctrlShow (_tab == "info") } } forEach FAC_cqbGui_tabInfoIdcs;
    [_d displayCtrl 60520, _tab == "setup"] call FAC_theme_applyTab;
    [_d displayCtrl 60521, _tab == "info"] call FAC_theme_applyTab;
};

FAC_cqbGui_fnc = {
    params ["_action", "_params"];

    private _btnSel = FAC_theme_tabActive;
    private _btnIdle = FAC_theme_tabIdle;

    private _fncRefreshThreat = {
        private _display = findDisplay 60500;
        if (isNull _display) exitWith {};
        private _mode = uinamespace getVariable ["FAC_cqbGui_enemyType", "targets"];
        (_display displayCtrl 60510) ctrlSetBackgroundColor (if (_mode == "targets") then { _btnSel } else { _btnIdle });
        (_display displayCtrl 60511) ctrlSetBackgroundColor (if (_mode == "enemies") then { _btnSel } else { _btnIdle });
    };

    private _fncRefreshCiv = {
        private _display = findDisplay 60500;
        if (isNull _display) exitWith {};
        private _on = uinamespace getVariable ["FAC_cqbGui_civilians", false];
        (_display displayCtrl 60512) ctrlSetBackgroundColor (if (!_on) then { _btnSel } else { _btnIdle });
        (_display displayCtrl 60513) ctrlSetBackgroundColor (if (_on) then { _btnSel } else { _btnIdle });
    };

    private _fncRefreshDensity = {
        private _display = findDisplay 60500;
        if (isNull _display) exitWith {};
        private _d = uinamespace getVariable ["FAC_cqbGui_density", "Medium"];
        (_display displayCtrl 60515) ctrlSetBackgroundColor (if (_d == "Low") then { _btnSel } else { _btnIdle });
        (_display displayCtrl 60516) ctrlSetBackgroundColor (if (_d == "Medium") then { _btnSel } else { _btnIdle });
        (_display displayCtrl 60517) ctrlSetBackgroundColor (if (_d == "High") then { _btnSel } else { _btnIdle });
    };

    private _fncSetInfoStructured = {
        params ["_display"];
        private _ctrl = _display displayCtrl 60507;
        if (isNull _ctrl) exitWith {};
        private _n = missionNamespace getVariable ["FADE_cqbPosCount", 0];
        private _lines = [
            format ["Eden: %1 CQB_POS_* triggers (direction = spawn facing).", _n],
            "",
            "Pop-up targets  -  steel targets; any hit or splash knocks them down until you end the drill. Time is recorded when the last target drops.",
            "",
            "Live OPFOR  -  stationary hostiles (optional civilian decoys). Drill ends when all hostiles are dead or surrendered.",
            "",
            "Spawn chance  -  each position rolls independently (Low / Medium / High).",
            "",
            "Anyone can end an active drill from this board."
        ];
        private _body = "";
        { _body = _body + format ["<t color='%1'>%2</t><br/>", FAC_theme_htmlBody, _x] } forEach _lines;
        _ctrl ctrlSetStructuredText parseText _body;
    };

    private _display = findDisplay 60500;
    if (isNull _display && { _action != "open" }) exitWith {};

    switch _action do {
        case "open": {
            if (!createDialog "RscDisplayCQB") then {
                systemChat "CQB GUI: RESOURCE NOT FOUND.";
            };
        };
        case "onLoad": {
            _display = findDisplay 60500;
            if (isNull _display) exitWith {};
            uinamespace setVariable ["FAC_cqbGui_fnc", FAC_cqbGui_fnc];

            uinamespace setVariable ["FAC_cqbGui_enemyType", "targets"];
            uinamespace setVariable ["FAC_cqbGui_civilians", false];
            uinamespace setVariable ["FAC_cqbGui_density", "Medium"];

            private _last = missionNamespace getVariable ["FADE_cqbLastResult", ""];
            (_display displayCtrl 60508) ctrlSetText (if (_last == "") then { " - " } else { _last });

            [_display] call _fncSetInfoStructured;

            [] call _fncRefreshThreat;
            [] call _fncRefreshCiv;
            [] call _fncRefreshDensity;
            missionNamespace setVariable ["FAC_cqbGui_tab", "setup"];
            [] call FAC_cqbGui_syncTabs;
            ["updateDrillButton", []] call FAC_cqbGui_fnc;
        };
        case "setTab": {
            _params params [["_tab", "setup"]];
            if !(_tab in ["setup", "info"]) exitWith {};
            missionNamespace setVariable ["FAC_cqbGui_tab", _tab];
            [] call FAC_cqbGui_syncTabs;
            if (_tab == "info") then {
                private _d = findDisplay 60500;
                if (!isNull _d) then { [_d] call _fncSetInfoStructured };
            };
        };
        case "headerRefresh": {
            _display = findDisplay 60500;
            if (isNull _display) exitWith {};
            private _last = missionNamespace getVariable ["FADE_cqbLastResult", ""];
            (_display displayCtrl 60508) ctrlSetText (if (_last == "") then { " - " } else { _last });
            [_display] call _fncSetInfoStructured;
            ["updateDrillButton", []] call FAC_cqbGui_fnc;
        };
        case "setDensity": {
            _params params [["_d", "Medium"]];
            if !(_d in ["Low", "Medium", "High"]) exitWith {};
            uinamespace setVariable ["FAC_cqbGui_density", _d];
            [] call _fncRefreshDensity;
        };
        case "setThreat": {
            _params params [["_mode", "targets"]];
            if !(_mode in ["targets", "enemies"]) exitWith {};
            uinamespace setVariable ["FAC_cqbGui_enemyType", _mode];
            [] call _fncRefreshThreat;
        };
        case "setCiv": {
            _params params [["_on", false]];
            uinamespace setVariable ["FAC_cqbGui_civilians", _on];
            [] call _fncRefreshCiv;
        };
        case "updateDrillButton": {
            _display = findDisplay 60500;
            if (isNull _display) exitWith {};
            private _active = missionNamespace getVariable ["FADE_cqbDrillActive", false];
            private _btn = _display displayCtrl 60504;
            if (_active) then {
                _btn ctrlSetText "End drill";
            } else {
                _btn ctrlSetText "Start drill";
            };
        };
        case "drill": {
            _display = findDisplay 60500;
            if (isNull _display) exitWith {};
            private _active = missionNamespace getVariable ["FADE_cqbDrillActive", false];
            if (_active) then {
                [player] remoteExec ["FADE_cqbEndDrill", 2];
                closeDialog 0;
            } else {
                private _density = uinamespace getVariable ["FAC_cqbGui_density", "Medium"];
                private _enemyType = uinamespace getVariable ["FAC_cqbGui_enemyType", "targets"];
                private _civilians = uinamespace getVariable ["FAC_cqbGui_civilians", false];
                [player, _enemyType, _density, _civilians] remoteExec ["FADE_cqbStartDrill", 2];
                closeDialog 0;
            };
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };
    };
};
