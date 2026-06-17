// Cutscene server: RTT camera fan-out + simple actor timeline.

// Single loadout array (not [loadout, bool]) — see setUnitLoadout / getUnitLoadout format.
FADE_cutscene_testCam_actorLoadout = [[], [], [], [], [], [], "hendrix_bandana_blk", "UK3CB_G_Gloves_Black", [], ["ItemMap", "", "", "ItemCompass", "ItemWatch", ""]];

FADE_cutscene_testCam_actorAnims0 = [
    "Acts_B_m06_briefing",
    "Acts_B_M02_briefing",
    "Acts_B_M03_briefing",
    "Acts_B_M05_briefing"
];

FADE_cutscene_testCam_actorAnims6 = [
    "AmovPercMstpSnonWnonDnon_idle68boxing",
    "AmovPercMstpSnonWnonDnon_exercisekneeBendA",
    "AmovPercMstpSnonWnonDnon_exercisePushup",
    "AmovPercMstpSnonWnonDnon_exerciseKata"
];

FADE_cutscene_testCam_actorAnims15 = [
    "Acts_CivilTalking_1",
    "Acts_CivilListening_2",
    "Acts_CivilListening_1",
    "Acts_CivilTalking_2"
];

FADE_cutscene_testCam_actorAnimsDance = [
    "ActsPercMstpSnonWnonDnon_DancingDuoIvan",
    "ActsPercMstpSnonWnonDnon_DancingStefan",
    "ActsPercMstpSnonWnonDnon_DancingDuoStefan",
    "ActsPercMstpSnonWnonDnon_DancingZOZO"
];

FADE_cutscene_testCam_serverDeleteActors = {
    if (!isServer) exitWith {};
    private _actors = missionNamespace getVariable ["FADE_cutscene_testCam_actors", []];
    {
        if (!isNull _x) then { deleteVehicle _x };
    } forEach _actors;
    missionNamespace setVariable ["FADE_cutscene_testCam_actors", []];
};

FADE_cutscene_testCam_serverApplyActorAnimSet = {
    params [["_anims", []]];
    if (!isServer) exitWith {};
    if !(_anims isEqualType []) exitWith {};

    private _actors = missionNamespace getVariable ["FADE_cutscene_testCam_actors", []];
    private _n = (count _actors) min (count _anims);
    private _i = 0;
    while { _i < _n } do {
        private _u = _actors # _i;
        if (!isNull _u) then {
            _u switchMove "";
            _u playMoveNow (_anims # _i);
        };
        _i = _i + 1;
    };
};

FADE_cutscene_testCam_serverSpawnActors = {
    if (!isServer) exitWith { false };

    private _spawnNames = ["A1P1", "A2P1", "A3P1", "A4P1"];
    private _spawnObjs = [];
    {
        private _o = missionNamespace getVariable [_x, objNull];
        if (isNull _o) exitWith {
            _spawnObjs = [];
        };
        _spawnObjs pushBack _o;
    } forEach _spawnNames;
    if (count _spawnObjs != 4) exitWith {
        diag_log "[CUTSCENE] start rejected: one or more actor spawn points A1P1..A4P1 are missing.";
        false
    };

    [] call FADE_cutscene_testCam_serverDeleteActors;

    private _grp = createGroup [civilian, true];
    private _actors = [];
    {
        private _pos = getPosATL _x;
        private _u = _grp createUnit ["C_man_1", _pos, [], 0, "NONE"];
        _u setPosATL _pos;
        _u setDir (getDir _x);
        _u setUnitLoadout FADE_cutscene_testCam_actorLoadout;
        _u disableAI "PATH";
        _u disableAI "AUTOTARGET";
        _u disableAI "TARGET";
        _u setCaptive true;
        _actors pushBack _u;
    } forEach _spawnObjs;

    missionNamespace setVariable ["FADE_cutscene_testCam_actors", _actors];
    true
};

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

    if !([] call FADE_cutscene_testCam_serverSpawnActors) exitWith {};

    if !(_stepSeconds isEqualType 0) then { _stepSeconds = 3 };
    if (_stepSeconds <= 0) then { _stepSeconds = 3 };

    missionNamespace setVariable ["FADE_cutscene_testCam_active", true];

    // 00:00 animation set.
    [FADE_cutscene_testCam_actorAnims0] call FADE_cutscene_testCam_serverApplyActorAnimSet;

    // jip=false: do not queue for JIP — clientStart moves the player in front of the laptop; late joiners must not replay it.
    [_screenVarName, _indices, _totalSeconds, _stepSeconds] remoteExec ["FADE_cutscene_testCam_clientStart", 0, false];

    private _safetyCap = 210;
    if ((_totalSeconds isEqualType 0) && { _totalSeconds > 0 }) then {
        _safetyCap = (_totalSeconds + 30) max 210;
    };
    private _timeline = [_safetyCap, _stepSeconds] spawn {
        params ["_safetyCap", "_stepSeconds"];
        private _t0 = time;
        private _did6 = false;
        private _did15 = false;
        private _did36 = false;

        while { missionNamespace getVariable ["FADE_cutscene_testCam_active", false] } do {
            private _elapsed = time - _t0;
            if (_elapsed >= _safetyCap) exitWith {};

            // 00:05 requested; synced to nearest 3s camera change => 00:06.
            if (!_did6 && {_elapsed >= 6}) then {
                [FADE_cutscene_testCam_actorAnims6] call FADE_cutscene_testCam_serverApplyActorAnimSet;
                _did6 = true;
            };

            // 00:15 aligns with a camera step naturally.
            if (!_did15 && {_elapsed >= 15}) then {
                [FADE_cutscene_testCam_actorAnims15] call FADE_cutscene_testCam_serverApplyActorAnimSet;
                _did15 = true;
            };

            // 00:35 requested; synced to nearest 3s camera change => 00:36.
            if (!_did36 && {_elapsed >= 36}) then {
                [FADE_cutscene_testCam_actorAnimsDance] call FADE_cutscene_testCam_serverApplyActorAnimSet;
                _did36 = true;
            };

            sleep 0.1;
        };

        // Safety only — normal end is FADE_cutscene_testCam_serverFinished from the client.
        if (missionNamespace getVariable ["FADE_cutscene_testCam_active", false]) then {
            diag_log "[CUTSCENE] safety cap reached — server abort";
            [] call FADE_cutscene_testCam_serverFinished;
            [] remoteExec ["FADE_cutscene_testCam_clientStop", 0, false];
        };
    };

    missionNamespace setVariable ["FADE_cutscene_testCam_timeline", _timeline];

    diag_log format [
        "[CUTSCENE] Splendid RTT sequence started: screen=%1 safetyCap=%2s step=%3s actors=4",
        _screenVarName, _safetyCap, _stepSeconds
    ];
};

// Normal client completion — delete actors; do not stop music on clients.
FADE_cutscene_testCam_serverFinished = {
    if (!isServer) exitWith {};

    missionNamespace setVariable ["FADE_cutscene_testCam_active", false];

    private _h = missionNamespace getVariable ["FADE_cutscene_testCam_timeline", scriptNull];
    if ((_h isEqualType scriptNull) && {!scriptDone _h}) then {
        terminate _h;
    };
    missionNamespace setVariable ["FADE_cutscene_testCam_timeline", scriptNull];

    [] call FADE_cutscene_testCam_serverDeleteActors;
};

FADE_cutscene_testCam_stop = {
    if (!isServer) exitWith {};

    missionNamespace setVariable ["FADE_cutscene_testCam_active", false];

    private _h = missionNamespace getVariable ["FADE_cutscene_testCam_timeline", scriptNull];
    if ((_h isEqualType scriptNull) && {!scriptDone _h}) then {
        terminate _h;
    };
    missionNamespace setVariable ["FADE_cutscene_testCam_timeline", scriptNull];

    [] call FADE_cutscene_testCam_serverDeleteActors;
    [] remoteExec ["FADE_cutscene_testCam_clientStop", 0, false];
    diag_log "[CUTSCENE] test camera stopped (abort).";
};
