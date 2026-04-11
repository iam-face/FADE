// =============================================================================
// SniperGui.sqf — sniper range terminal (client); trace via BIS_fnc_traceBullets
// idd 60910. Server: FADE_sniperStartSession / FADE_sniperEndSession
// =============================================================================

// Vanilla ballistics / penetration trace — BIS_fnc_traceBullets (functions_f_mark / engine). Strength 0 = off.
FADE_sniperClient_setProjectileTrace = {
    params [["_enabled", false]];
    if (!hasInterface) exitWith {};
    if (isNil "BIS_fnc_traceBullets") exitWith {
        if (_enabled) then { systemChat "Sniper range: BIS_fnc_traceBullets not loaded (vanilla Functions)."; };
    };
    private _u = player;
    private _col = [1, 0.4, 0.12, 0.85];
    if (_enabled) then {
        [_u, 1, _col] call BIS_fnc_traceBullets;
    } else {
        [_u, 0] call BIS_fnc_traceBullets;
    };
};

FADE_sniperClient_clearRangeFx = {
    [false] call FADE_sniperClient_setProjectileTrace;
    [false] call FADE_sniperClient_setProjectileImpactMarkers;
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
    if (!(missionNamespace getVariable ["FADE_sniperRangeActive", false])) exitWith {};
    if (getPlayerUID player != _uid) exitWith {};
    if !([_last] call FADE_sniperClient_aslIsFinite) exitWith {};
    [_last, _uid] remoteExecCall ["FADE_sniperServer_impactSphereFromClient", 2];
};

FADE_sniperClient_onFiredForImpact = {
    if (!(missionNamespace getVariable ["FADE_sniperRangeActive", false])) exitWith {};
    if (getPlayerUID player != missionNamespace getVariable ["FADE_sniperStarterUid", ""]) exitWith {};
    private _unit = _this param [0, objNull];
    if (_unit != player) exitWith {};
    private _bullet = _this param [6, objNull];
    [_bullet] spawn FADE_sniperClient_trackProjectileImpact;
};

// While sniper session is yours: every Fired → track projectile to impact (terrain or target)
FADE_sniperClient_setProjectileImpactMarkers = {
    params [["_on", false]];
    if (!hasInterface) exitWith {};
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

    private _btnSel = [0.2, 0.4, 0.62, 1];
    private _btnIdle = [0.10, 0.12, 0.16, 1];

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
        _n = (_n max 1) min 40;
        private _slider = _display displayCtrl 60915;
        if (!isNull _slider) then { _slider sliderSetRange [1, 40]; _slider sliderSetSpeed [1, 1]; _slider sliderSetPosition _n; };
        (_display displayCtrl 60916) ctrlSetText str _n;
    };

    private _fncRefreshMaxRange = {
        private _display = findDisplay 60910;
        if (isNull _display) exitWith {};
        private _m = uinamespace getVariable ["FAC_sniperGui_maxRange", 1000];
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
            _status ctrlSetTextColor [0.55, 0.95, 0.7, 1];
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
            format ["Eden: %1 sniperRangeTarget_* logic objects (lanes).", _n],
            "",
            "Pop-up targets face you with board reversed (−180°). Live units face toward you.",
            "",
            "Firing range — spawns exactly your selected target count (clamped to lane count). No time limit; end when finished.",
            "",
            "Max range limits eligible lanes to 100..1000m from shooter (horizontal distance).",
            "",
            "Time trial — uses target count + max range (near→far lanes). Each stage uses a shuffled sniperPos_1..7 logic: within 1m you get “At position N, engage target!” then damage is enabled; hints also guide moves between stages.",
            "",
            "Impact marker (~5 s, everyone sees): starter's machine tracks each projectile to its last ASL, then server spawns Config FADE_sniperImpactMarkerClass (hits, misses, terrain).",
            "",
            "Hit feedback on: structured hint (same fields as end-of-trial summary line) for firing range and time trial. Uses Hit + HitPart (layouts differ by target type).",
            "",
            "Projectile trace (shooter): vanilla BIS_fnc_traceBullets — ballistics / penetration path.",
            "",
            "Only one session can be active on the server at a time."
        ];
        private _body = "";
        { _body = _body + format ["<t color='#d2e8dc'>%1</t><br/>", _x] } forEach _lines;
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
            uinamespace setVariable ["FAC_sniperGui_maxRange", 1000];
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
            _n = (_n max 1) min 40;
            uinamespace setVariable ["FAC_sniperGui_targetCount", _n];
            [] call _fncRefreshTargetCount;
        };
        case "setMaxRange": {
            _params params [["_raw", 1000]];
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
                _btn ctrlSetBackgroundColor [0.2, 0.4, 0.62, 1];
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
                private _maxRange = uinamespace getVariable ["FAC_sniperGui_maxRange", 1000];
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
