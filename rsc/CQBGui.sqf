// =============================================================================
// CQBGui.sqf - CQB Training Shoothouse GUI (client)
// =============================================================================
// Opens from cqbBoard. Threat type = toggles; spawn chance = Low/Med/High buttons;
// civilian mix = toggle (live OPFOR only). Start/end drill remoteExecs server.
// FADE_cqbDrillActive + FADE_cqbLastResult are publicVariable'd from server.
// =============================================================================

FAC_cqbGui_fnc = {
    params ["_action", "_params"];

    private _btnSel = [0.2, 0.4, 0.62, 1];
    private _btnIdle = [0.10, 0.12, 0.16, 1];

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
            "Pop-up targets — steel targets; any hit or splash knocks them down until you end the drill. Time is recorded when the last target drops.",
            "",
            "Live OPFOR — stationary hostiles (optional civilian decoys). Drill ends when all hostiles are dead or surrendered.",
            "",
            "Spawn chance — each position rolls independently (Low / Medium / High).",
            "",
            "Anyone can end an active drill from this board."
        ];
        private _body = "";
        { _body = _body + format ["<t color='#d2e8dc'>%1</t><br/>", _x] } forEach _lines;
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
            (_display displayCtrl 60508) ctrlSetText (if (_last == "") then { "—" } else { _last });

            [_display] call _fncSetInfoStructured;

            [] call _fncRefreshThreat;
            [] call _fncRefreshCiv;
            [] call _fncRefreshDensity;
            ["updateDrillButton", []] call FAC_cqbGui_fnc;
        };
        case "headerRefresh": {
            _display = findDisplay 60500;
            if (isNull _display) exitWith {};
            private _last = missionNamespace getVariable ["FADE_cqbLastResult", ""];
            (_display displayCtrl 60508) ctrlSetText (if (_last == "") then { "—" } else { _last });
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
