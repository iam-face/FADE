// =============================================================================
// SniperGui.sqf  -  sniper range terminal (client); trace via BIS_fnc_traceBullets
// idd 60910. Server: FADE_sniperStartSession / FADE_sniperEndSession
// =============================================================================

// Vanilla ballistics / penetration trace  -  BIS_fnc_traceBullets (functions_f_mark / engine). Strength 0 = off.
// [_enabled, _unit]: server broadcasts to all clients (0, _unit) so observers see the same shooter trace.
FADE_sniperClient_setProjectileTrace = {
    params [["_enabled", false], ["_unit", objNull]];
    if (!hasInterface) exitWith {};
    if (isNil "BIS_fnc_traceBullets") exitWith {
        if (_enabled) then { systemChat "Sniper range: BIS_fnc_traceBullets not loaded (vanilla Functions)."; };
    };
    private _u = _unit;
    if (isNull _u) then { _u = player };
    private _col = [1, 0.4, 0.12, 0.85];
    if (_enabled) then {
        [_u, 1, _col] call BIS_fnc_traceBullets;
    } else {
        [_u, 0] call BIS_fnc_traceBullets;
    };
};

// Auto-disable trace + impact marker tracking when session starter moves >100 m from the range terminal.
FADE_sniperClient_stopTraceProximityMonitor = {
    if (!hasInterface) exitWith {};
    missionNamespace setVariable ["FADE_sniperTraceProxActive", false];
};

FADE_sniperClient_startTraceProximityMonitor = {
    params [["_termPos", []], ["_shooter", objNull]];
    if (!hasInterface) exitWith {};
    if (isNull _shooter || { _shooter != player }) exitWith {};
    if (!(_termPos isEqualType []) || { count _termPos < 2 }) exitWith {};
    missionNamespace setVariable ["FADE_sniperTraceProxActive", false];
    [] call FADE_sniperClient_stopTraceProximityMonitor;
    missionNamespace setVariable ["FADE_sniperTraceProxActive", true];
    missionNamespace setVariable ["FADE_sniperTraceProxWarned", false];
    [_termPos, _shooter] spawn {
        params ["_termPos", "_shooter"];
        private _term2d = [_termPos select 0, _termPos select 1];
        while { missionNamespace getVariable ["FADE_sniperTraceProxActive", false] } do {
            if (isNull _shooter || { !alive _shooter } || { _shooter != player }) exitWith {
                missionNamespace setVariable ["FADE_sniperTraceProxActive", false];
            };
            if ((_shooter distance2D _term2d) > 100) then {
                [false, _shooter] remoteExec ["FADE_sniperClient_setProjectileTrace", 0, _shooter];
                [false] call FADE_sniperClient_setProjectileImpactMarkers;
                missionNamespace setVariable ["FADE_sniperTraceProxActive", false];
                if !(missionNamespace getVariable ["FADE_sniperTraceProxWarned", false]) then {
                    missionNamespace setVariable ["FADE_sniperTraceProxWarned", true];
                    systemChat "Range ballistics FX disabled (trace and impact markers)  -  you left the terminal area (>100 m).";
                };
            };
            sleep 2;
        };
    };
};

FADE_sniperClient_clearRangeFx = {
    params [["_unit", objNull]];
    [false, _unit] call FADE_sniperClient_setProjectileTrace;
    [false] call FADE_sniperClient_setProjectileImpactMarkers;
    [] call FADE_sniperClient_stopTraceProximityMonitor;
};

// Client-only finite ASL check (mirror server helper; SniperRangeServer is not compiled on clients)
FADE_sniperClient_aslIsFinite = {
    private "_p";
    _p = _this select 0;
    if (isNil "_p" || {!(_p isEqualType [])} || { count _p < 3 }) exitWith { false };
    finite (_p select 0) && { finite (_p select 1) } && { finite (_p select 2) }
};

// Poll local projectile until gone; report last ASL to server for global impact marker (misses + hits)
FADE_sniperClient_trackProjectileImpact = {
    private ["_projectile", "_uid", "_last", "_t0"];
    _projectile = _this select 0;
    if (!hasInterface) exitWith {};
    _uid = getPlayerUID player;
    _last = [];
    if (!isNull _projectile) then { _last = getPosASL _projectile };
    _t0 = diag_tickTime;
    while {!isNull _projectile && { diag_tickTime - _t0 < 60 }} do {
        _last = getPosASL _projectile;
        sleep 0.003;
    };
    private _snA = missionNamespace getVariable ["FADE_sniperRangeActive", false];
    private _rgA = missionNamespace getVariable ["FADE_rangeSessionActive", false];
    private _stillMine = (_snA && {_uid == missionNamespace getVariable ["FADE_sniperStarterUid", ""]}) ||
        {_rgA && {_uid == missionNamespace getVariable ["FADE_rangeStarterUid", ""]}};
    if (!_stillMine) exitWith {};
    if !(missionNamespace getVariable ["FADE_sniperImpactMarkersClientEnabled", false]) exitWith {};
    if (getPlayerUID player != _uid) exitWith {};
    if !([_last] call FADE_sniperClient_aslIsFinite) exitWith {};
    [_last, _uid] remoteExecCall ["FADE_sniperServer_impactSphereFromClient", 2];
};

FADE_sniperClient_onFiredForImpact = {
    if !(missionNamespace getVariable ["FADE_sniperImpactMarkersClientEnabled", false]) exitWith {};
    private _uid = getPlayerUID player;
    private _snA = missionNamespace getVariable ["FADE_sniperRangeActive", false];
    private _rgA = missionNamespace getVariable ["FADE_rangeSessionActive", false];
    if (!((_snA && {_uid == missionNamespace getVariable ["FADE_sniperStarterUid", ""]}) ||
        {_rgA && {_uid == missionNamespace getVariable ["FADE_rangeStarterUid", ""]}})) exitWith {};
    private _unit = _this param [0, objNull];
    if (_unit != player) exitWith {};
    private _bullet = _this param [6, objNull];
    [_bullet] spawn FADE_sniperClient_trackProjectileImpact;
};

// While you are the sniper or range starter: every Fired → track projectile to impact (terrain or target)
FADE_sniperClient_setProjectileImpactMarkers = {
    params [["_on", false]];
    if (!hasInterface) exitWith {};
    missionNamespace setVariable ["FADE_sniperImpactMarkersClientEnabled", _on];
    private _u = player;
    private _eh = _u getVariable ["FADE_sniperFiredImpactEh", -1];
    if (_eh >= 0) then {
        _u removeEventHandler ["Fired", _eh];
        _u setVariable ["FADE_sniperFiredImpactEh", -1];
    };
    if (!_on) exitWith {};
    private _id = _u addEventHandler ["Fired", { _this call FADE_sniperClient_onFiredForImpact }];
    _u setVariable ["FADE_sniperFiredImpactEh", _id];
};

// Structured hint (time-trial summary + per-hit detail in firing range)
FADE_sniperClient_showTrialHint = {
    params [["_html", ""]];
    if (!hasInterface) exitWith {};
    hint parseText _html;
};

FAC_sniperGui_fnc = {
    params ["_action", "_params"];

    private _btnSel = FAC_theme_tabActive;
    private _btnIdle = FAC_theme_tabIdle;

    private _fncRefreshThreat = {
        private _display = findDisplay 60910;
        if (isNull _display) exitWith {};
        private _mode = uinamespace getVariable ["FAC_sniperGui_enemyType", "targets"];
        (_display displayCtrl 60912) ctrlSetBackgroundColor (if (_mode == "targets") then { _btnSel } else { _btnIdle });
        (_display displayCtrl 60913) ctrlSetBackgroundColor (if (_mode == "enemies") then { _btnSel } else { _btnIdle });
    };

    private _fncRefreshTargetCount = {
        private _display = findDisplay 60910;
        if (isNull _display) exitWith {};
        private _n = uinamespace getVariable ["FAC_sniperGui_targetCount", 10];
        _n = (_n max 1) min 72;
        private _slider = _display displayCtrl 60915;
        if (!isNull _slider) then { _slider sliderSetRange [1, 72]; _slider sliderSetSpeed [1, 1]; _slider sliderSetPosition _n; };
        (_display displayCtrl 60916) ctrlSetText str _n;
    };

    private _fncRefreshMaxRange = {
        private _display = findDisplay 60910;
        if (isNull _display) exitWith {};
        private _m = uinamespace getVariable ["FAC_sniperGui_maxRange", 600];
        _m = (_m max 100) min 1000;
        private _slider = _display displayCtrl 60931;
        if (!isNull _slider) then { _slider sliderSetRange [100, 1000]; _slider sliderSetSpeed [25, 100]; _slider sliderSetPosition _m; };
        (_display displayCtrl 60932) ctrlSetText (format ["%1 m", _m]);
    };

    private _fncRefreshTrace = {
        private _display = findDisplay 60910;
        if (isNull _display) exitWith {};
        private _on = uinamespace getVariable ["FAC_sniperGui_trace", false];
        (_display displayCtrl 60918) ctrlSetBackgroundColor (if (!_on) then { _btnSel } else { _btnIdle });
        (_display displayCtrl 60919) ctrlSetBackgroundColor (if (_on) then { _btnSel } else { _btnIdle });
    };

    private _fncRefreshHit = {
        private _display = findDisplay 60910;
        if (isNull _display) exitWith {};
        private _on = uinamespace getVariable ["FAC_sniperGui_hitTrack", true];
        (_display displayCtrl 60920) ctrlSetBackgroundColor (if (!_on) then { _btnSel } else { _btnIdle });
        (_display displayCtrl 60921) ctrlSetBackgroundColor (if (_on) then { _btnSel } else { _btnIdle });
    };

    private _fncRefreshMode = {
        private _display = findDisplay 60910;
        if (isNull _display) exitWith {};
        private _m = uinamespace getVariable ["FAC_sniperGui_mode", "firing"];
        (_display displayCtrl 60922) ctrlSetBackgroundColor (if (_m == "firing") then { _btnSel } else { _btnIdle });
        (_display displayCtrl 60923) ctrlSetBackgroundColor (if (_m == "trial") then { _btnSel } else { _btnIdle });
    };

    private _fncRefreshStatus = {
        private _display = findDisplay 60910;
        if (isNull _display) exitWith {};
        private _active = missionNamespace getVariable ["FADE_sniperRangeActive", false];
        private _status = _display displayCtrl 60930;
        if (_active) then {
            private _mode = missionNamespace getVariable ["FADE_sniperSessionMode", "firing"];
            private _modeText = if (_mode == "trial") then { "TIME TRIAL" } else { "FIRING RANGE" };
            _status ctrlSetText format ["ACTIVE - %1", _modeText];
            _status ctrlSetTextColor [1, 0.75, 0.5, 1];
        } else {
            _status ctrlSetText "INACTIVE";
            _status ctrlSetTextColor FAC_theme_textOk;
        };
    };

    private _fncRefreshInteractivity = {
        private _display = findDisplay 60910;
        if (isNull _display) exitWith {};
        private _active = missionNamespace getVariable ["FADE_sniperRangeActive", false];
        private _canEdit = !_active;
        {
            (_display displayCtrl _x) ctrlEnable _canEdit;
        } forEach [60912, 60913, 60915, 60918, 60919, 60920, 60921, 60922, 60923, 60931];
    };

    private _fncSetInfoStructured = {
        params ["_display"];
        private _ctrl = _display displayCtrl 60925;
        if (isNull _ctrl) exitWith {};
        private _n = missionNamespace getVariable ["FADE_sniperPosCount", 0];
        private _lines = [
            format ["%1 target lanes placed in Eden (sniperRangeTarget_*).", _n],
            "",
            "Pop-up targets face you with the board reversed. Live units face toward you.",
            "",
            "Firing range  -  spawns your selected target count (capped by lane count). No timer; end when finished.",
            "",
            "Max range keeps lanes between 100 m and 1000 m from the shooter (horizontal).",
            "",
            "Time trial  -  uses target count + max range (near to far). Each stage picks a lane with clear LOS from the required sniperPos; if none, falls back and chats a note. Walk the shuffled sniperPos_1..7: within 2.5 m you get 'At position N, engage target!' then damage turns on.",
            "",
            "Impact marker (~5 s, everyone): while within 100 m of the terminal, your shots are tracked to last ASL and a marker appears (hits, misses, terrain).",
            "",
            "Hit feedback on: structured hint with the same fields as the end-of-trial summary (firing range and time trial).",
            "",
            "Projectile trace: all clients see the session shooter's path. Trace and impact tracking stop if you move more than 100 m from the terminal.",
            "",
            "Sniper range and firing / AT range can run at the same time (separate shooters and targets)."
        ];
        private _body = "";
        { _body = _body + format ["<t color='%1'>%2</t><br/>", FAC_theme_htmlBody, _x] } forEach _lines;
        _ctrl ctrlSetStructuredText parseText _body;
    };

    private _display = findDisplay 60910;
    if (isNull _display && { _action != "open" }) exitWith {};

    switch _action do {
        case "open": {
            if (!createDialog "RscDisplaySniper") then {
                systemChat "Sniper range GUI: RESOURCE NOT FOUND.";
            };
        };
        case "onLoad": {
            _display = findDisplay 60910;
            if (isNull _display) exitWith {};
            uinamespace setVariable ["FAC_sniperGui_fnc", FAC_sniperGui_fnc];

            uinamespace setVariable ["FAC_sniperGui_enemyType", "targets"];
            uinamespace setVariable ["FAC_sniperGui_targetCount", 10];
            uinamespace setVariable ["FAC_sniperGui_maxRange", 600];
            uinamespace setVariable ["FAC_sniperGui_trace", false];
            uinamespace setVariable ["FAC_sniperGui_hitTrack", true];
            uinamespace setVariable ["FAC_sniperGui_mode", "firing"];

            [_display] call _fncSetInfoStructured;

            [] call _fncRefreshThreat;
            [] call _fncRefreshTargetCount;
            [] call _fncRefreshMaxRange;
            [] call _fncRefreshTrace;
            [] call _fncRefreshHit;
            [] call _fncRefreshMode;
            [] call _fncRefreshStatus;
            [] call _fncRefreshInteractivity;
            ["updateSessionButton", []] call FAC_sniperGui_fnc;
        };
        case "headerRefresh": {
            _display = findDisplay 60910;
            if (isNull _display) exitWith {};
            [_display] call _fncSetInfoStructured;
            [] call _fncRefreshTargetCount;
            [] call _fncRefreshMaxRange;
            [] call _fncRefreshStatus;
            [] call _fncRefreshInteractivity;
            ["updateSessionButton", []] call FAC_sniperGui_fnc;
        };
        case "setTargetCount": {
            _params params [["_raw", 10]];
            private _n = round _raw;
            _n = (_n max 1) min 72;
            uinamespace setVariable ["FAC_sniperGui_targetCount", _n];
            [] call _fncRefreshTargetCount;
        };
        case "setMaxRange": {
            _params params [["_raw", 600]];
            private _m = round _raw;
            _m = (_m max 100) min 1000;
            uinamespace setVariable ["FAC_sniperGui_maxRange", _m];
            [] call _fncRefreshMaxRange;
        };
        case "setThreat": {
            _params params [["_mode", "targets"]];
            if !(_mode in ["targets", "enemies"]) exitWith {};
            uinamespace setVariable ["FAC_sniperGui_enemyType", _mode];
            [] call _fncRefreshThreat;
        };
        case "setTrace": {
            _params params [["_on", false]];
            uinamespace setVariable ["FAC_sniperGui_trace", _on];
            [] call _fncRefreshTrace;
        };
        case "setHitTrack": {
            _params params [["_on", true]];
            uinamespace setVariable ["FAC_sniperGui_hitTrack", _on];
            [] call _fncRefreshHit;
        };
        case "setMode": {
            _params params [["_m", "firing"]];
            if !(_m in ["firing", "trial"]) exitWith {};
            uinamespace setVariable ["FAC_sniperGui_mode", _m];
            [] call _fncRefreshMode;
        };
        case "updateSessionButton": {
            _display = findDisplay 60910;
            if (isNull _display) exitWith {};
            private _active = missionNamespace getVariable ["FADE_sniperRangeActive", false];
            private _btn = _display displayCtrl 60924;
            if (_active) then {
                _btn ctrlSetText "End session";
                _btn ctrlSetBackgroundColor [0.65, 0.36, 0.16, 1];
            } else {
                _btn ctrlSetText "Start session";
                _btn ctrlSetBackgroundColor FAC_theme_tabActive;
            };
            [] call _fncRefreshStatus;
            [] call _fncRefreshInteractivity;
        };
        case "session": {
            _display = findDisplay 60910;
            if (isNull _display) exitWith {};
            private _active = missionNamespace getVariable ["FADE_sniperRangeActive", false];
            if (_active) then {
                [player] remoteExec ["FADE_sniperEndSession", 2];
                closeDialog 0;
            } else {
                private _enemyType = uinamespace getVariable ["FAC_sniperGui_enemyType", "targets"];
                private _targetCount = uinamespace getVariable ["FAC_sniperGui_targetCount", 10];
                private _maxRange = uinamespace getVariable ["FAC_sniperGui_maxRange", 600];
                private _trace = uinamespace getVariable ["FAC_sniperGui_trace", false];
                private _hit = uinamespace getVariable ["FAC_sniperGui_hitTrack", true];
                private _mode = uinamespace getVariable ["FAC_sniperGui_mode", "firing"];
                [player, _enemyType, _targetCount, _maxRange, _trace, _hit, _mode] remoteExec ["FADE_sniperStartSession", 2];
                closeDialog 0;
            };
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };
    };
};
