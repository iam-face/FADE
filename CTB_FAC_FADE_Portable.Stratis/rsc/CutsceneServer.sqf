// Cutscene server: RTT camera fan-out (client drives Splendid / prepared-camera sequence).

// Params: screen Eden var, texture indices, total runtime (s, -1 = auto), hold per Splendid shot (s).
// Client drives end time from the prepared-camera sequence; server waits for clientFinished (safety cap below).
FADE_cutscene_testCam_start = {
    params [
        ["_screenVarName", "Radio_1"],
        ["_indices", [0]],
        ["_totalSeconds", -1],
        ["_stepSeconds", 3]
    ];
    if (!isServer) exitWith {};

    private _screen = missionNamespace getVariable [_screenVarName, objNull];
    if (isNull _screen) exitWith {
        diag_log format ["[CUTSCENE] start rejected: screen '%1' not found.", _screenVarName];
    };

    // Restart if already active.
    if (missionNamespace getVariable ["FADE_cutscene_testCam_active", false]) then {
        [] call FADE_cutscene_testCam_stop;
    };

    private _oldTimeline = missionNamespace getVariable ["FADE_cutscene_testCam_timeline", scriptNull];
    if ((_oldTimeline isEqualType scriptNull) && {!scriptDone _oldTimeline}) then {
        terminate _oldTimeline;
    };
    missionNamespace setVariable ["FADE_cutscene_testCam_timeline", scriptNull];

    if !(_stepSeconds isEqualType 0) then { _stepSeconds = 3 };
    if (_stepSeconds <= 0) then { _stepSeconds = 3 };

    missionNamespace setVariable ["FADE_cutscene_testCam_active", true];

    // jip=false: do not queue for JIP  -  clientStart moves the player in front of the laptop; late joiners must not replay it.
    [_screenVarName, _indices, _totalSeconds, _stepSeconds] remoteExec ["FADE_cutscene_testCam_clientStart", 0, false];

    private _safetyCap = 210;
    if ((_totalSeconds isEqualType 0) && { _totalSeconds > 0 }) then {
        _safetyCap = (_totalSeconds + 30) max 210;
    };
    private _timeline = [_safetyCap] spawn {
        params ["_safetyCap"];
        private _t0 = time;

        while { missionNamespace getVariable ["FADE_cutscene_testCam_active", false] } do {
            if ((time - _t0) >= _safetyCap) exitWith {};
            sleep 0.25;
        };

        // Safety only  -  normal end is FADE_cutscene_testCam_serverFinished from the client.
        if (missionNamespace getVariable ["FADE_cutscene_testCam_active", false]) then {
            diag_log "[CUTSCENE] safety cap reached  -  server abort";
            [] call FADE_cutscene_testCam_serverFinished;
            [] remoteExec ["FADE_cutscene_testCam_clientStop", 0, false];
        };
    };

    missionNamespace setVariable ["FADE_cutscene_testCam_timeline", _timeline];

    diag_log format [
        "[CUTSCENE] Splendid RTT sequence started: screen=%1 safetyCap=%2s step=%3s",
        _screenVarName, _safetyCap, _stepSeconds
    ];
};

// Normal client completion.
FADE_cutscene_testCam_serverFinished = {
    if (!isServer) exitWith {};

    missionNamespace setVariable ["FADE_cutscene_testCam_active", false];

    private _h = missionNamespace getVariable ["FADE_cutscene_testCam_timeline", scriptNull];
    if ((_h isEqualType scriptNull) && {!scriptDone _h}) then {
        terminate _h;
    };
    missionNamespace setVariable ["FADE_cutscene_testCam_timeline", scriptNull];
};

FADE_cutscene_testCam_stop = {
    if (!isServer) exitWith {};

    missionNamespace setVariable ["FADE_cutscene_testCam_active", false];

    private _h = missionNamespace getVariable ["FADE_cutscene_testCam_timeline", scriptNull];
    if ((_h isEqualType scriptNull) && {!scriptDone _h}) then {
        terminate _h;
    };
    missionNamespace setVariable ["FADE_cutscene_testCam_timeline", scriptNull];

    [] remoteExec ["FADE_cutscene_testCam_clientStop", 0, false];
    diag_log "[CUTSCENE] test camera stopped (abort).";
};
