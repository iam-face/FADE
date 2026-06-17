// Cutscene RTT camera (client): Splendid Camera export tuples -> script camera -> Radio_* screen.
// Keyframes copied from Splendid; positions interpreted as ATL. Total runtime default 100s, 3s per shot, looping.

FADE_cutscene_fnc_resolveEdenObject = {
    params [["_name", ""]];
    if !(_name isEqualType "") exitWith { objNull };
    if (_name == "") exitWith { objNull };
    missionNamespace getVariable [_name, objNull]
};

// playSound3D returns a numeric handle; stopSound from scheduled context (see rsc\JukeboxGui.sqf).
FADE_cutscene_fnc_stopPs3d = {
    params ["_id"];
    if (isNil "_id") exitWith {};
    if (_id isEqualType "") exitWith {};
    if (!(_id isEqualType 0)) exitWith {};
    stopSound _id;
    [_id] spawn {
        params ["_x"];
        sleep 0.05;
        stopSound _x;
    };
};

FADE_cutscene_testCam_clientStopMusic = {
    if (!hasInterface) exitWith {};
    private _id = uiNamespace getVariable ["FADE_cutscene_testCam_snd", nil];
    if (!isNil "_id") then { [_id] call FADE_cutscene_fnc_stopPs3d };
    uiNamespace setVariable ["FADE_cutscene_testCam_snd", nil];
};

// MP: each client plays local 3D sound tied to emitter object (same pattern as jukebox radios).
FADE_cutscene_testCam_clientPlayMusic = {
    params [
        ["_cfgClass", "FAC_cutscene_callonme"],
        ["_emitterVarName", "Radio_1"]
    ];
    if (!hasInterface) exitWith {};

    [] call FADE_cutscene_testCam_clientStopMusic;

    private _emitter = [_emitterVarName] call FADE_cutscene_fnc_resolveEdenObject;
    if (isNull _emitter) exitWith {
        systemChat format ["CUTSCENE: music emitter '%1' not found.", _emitterVarName];
    };

    private _cfg = missionConfigFile >> "CfgSounds" >> _cfgClass;
    if (!isClass _cfg) then { _cfg = configFile >> "CfgSounds" >> _cfgClass };

    private _file = "";
    private _vol = 25;
    private _pitch = 1;
    private _dist = 2500;

    if (isClass _cfg) then {
        private _sa = getArray (_cfg >> "sound");
        if (count _sa < 1) exitWith {
            systemChat format ["CUTSCENE: CfgSounds '%1' has no sound[] path.", _cfgClass];
        };
        _file = _sa # 0;
        if (count _sa >= 2) then { _vol = _sa # 1 };
        if (count _sa >= 3) then { _pitch = _sa # 2 };
        if (count _sa >= 4) then { _dist = _sa # 3 };
    } else {
        // Fallback when description.ext include is not merged yet (mission OGG still packs).
        if (_cfgClass isEqualTo "FAC_cutscene_callonme") then {
            _file = "sounds\callonme.ogg";
        } else {
            systemChat format ["CUTSCENE: CfgSounds '%1' missing.", _cfgClass];
        };
    };
    if (_file == "") exitWith {};

    private _resolvedFile = _file;
    if ((_file find ":") < 0) then {
        private _missionRel = if ((_file select [0, 1]) isEqualTo "\") then { _file select [1] } else { _file };
        _resolvedFile = getMissionPath _missionRel;
    };

    private _pos = getPosASL _emitter;
    private _h = playSound3D [_resolvedFile, _emitter, false, _pos, _vol, _pitch, _dist];
    if (isNil "_h" || {_h isEqualTo ""} || {!(_h isEqualType 0)}) exitWith {
        systemChat format ["CUTSCENE: playSound3D failed for '%1'.", _cfgClass];
    };
    uiNamespace setVariable ["FADE_cutscene_testCam_snd", _h];
};

// Splendid clipboard tuple: [ "world", [x,y,z], yawDeg, fov, [pitchDeg, bankDeg], ... ]
FADE_cutscene_fnc_applySplendidTupleToCam = {
    params [["_cam", objNull], ["_splendid", []]];
    if (isNull _cam) exitWith {};
    if (count _splendid < 5) exitWith {};

    private _pos = _splendid # 1;
    if !(_pos isEqualType []) exitWith {};
    if (count _pos < 3) exitWith {};
    _cam setPosATL _pos;

    private _yawDeg = _splendid # 2;
    private _fov = _splendid # 3;
    private _pb = _splendid # 4;
    private _pitchDeg = if (_pb isEqualType [] && { count _pb > 0 }) then { _pb # 0 } else { 0 };
    private _bankDeg = if (_pb isEqualType [] && { count _pb > 1 }) then { _pb # 1 } else { 0 };

    private _y = _yawDeg;
    private _p = _pitchDeg;
    private _b = _bankDeg;

    // Yaw: Arma compass (clockwise from north). Pitch: nose-up positive on Z component.
    private _cosP = cos _p;
    private _fwd = [
        (sin _y) * _cosP,
        (cos _y) * _cosP,
        sin _p
    ];
    if ((vectorMagnitude _fwd) < 1e-5) then { _fwd = [0, 1, 0] } else { _fwd = vectorNormalized _fwd };

    private _worldUp = [0, 0, 1];
    if ((abs (_fwd vectorDotProduct _worldUp)) > 0.98) then { _worldUp = [0, 1, 0] };
    private _right = vectorNormalized (_worldUp vectorCrossProduct _fwd);
    private _up0 = vectorNormalized (_fwd vectorCrossProduct _right);

    private _up = if ((abs _b) < 1e-6) then {
        _up0
    } else {
        private _c = cos _b;
        private _s = sin _b;
        vectorNormalized ((_up0 vectorMultiply _c) vectorAdd ((_fwd vectorCrossProduct _up0) vectorMultiply _s))
    };

    _cam setVectorDirAndUp [_fwd, _up];
    if ((_fov isEqualType 0) && {_fov > 0.01} && {_fov < 2.5}) then {
        _cam camSetFov _fov;
        _cam camCommit 0;
    };
};

// Splendid export — virtual camera for laptop RTT (shows 4× actor performance + world).
FADE_cutscene_testCam_keyframes = [
    ["altis", [15180.2, 17414.7, 0.133347], 329.158, 0.32, [7.71416, 0], 0, 0, 1082.8, 0, 0, 1, 0, 1],
    ["altis", [15166.5, 17411.8, 0.624363], 42.107, 0.32, [2.78394, 0], 0, 0, 1082.8, 0, 0, 1, 0, 1],
    ["altis", [15179, 17419, 0.300621], 249.506, 0.32, [6.12377, 0], 0, 0, 1082.8, 0, 0, 1, 0, 1],
    ["altis", [15165.2, 17413.7, 1.09417], 353.354, 0.32, [15.189, 0], 0, 0, 1082.8, 0, 0, 1, 0, 1],
    ["altis", [15174.3, 17424.2, 0.774364], 212.528, 0.32, [-0.31732, 0], 0, 0, 1082.8, 0, 0, 1, 0, 1],
    ["altis", [15171.6, 17402, 6.58632], 0.038239, 0.32, [-26.0022, 0], 0, 0, 1082.8, 0, 0, 1, 0, 1],
    ["altis", [15167.3, 17411.8, 1.58136], 41.255, 0.32, [-3.25954, 0], 0, 0, 1082.8, 0, 0, 1, 0, 1],
    ["altis", [15179, 17419.3, 1.43216], 246.051, 0.32, [-6.99695, 0], 0, 0, 1082.8, 0, 0, 1, 0, 1]
];

// Prepared-camera sequence shown to all players (same style as civ interaction cutscenes).
// Format per shot: [target, pos, fov, commitSeconds, sleepSecondsAfterCommit].
FADE_cutscene_testCam_sequenceFixed = [
    [[85045.91, -52243.73, -17599.88], [14743.78, 16655.99, 1.52], 0.052, 0, 0],
    [[85045.91, -52243.73, -17599.88], [14743.74, 16656.03, 1.52], 0.366, 37, 37],
    [[-56416.82, 86836.30, -3225.26], [14745.09, 16654.69, 1.48], 1.773, 0, 5],
    [[-83768.06, 21.17, 4190.42], [14750.20, 16657.34, 1.13], 0.170, 0, 0],
    [[-76356.20, -24003.18, -6808.83], [14748.48, 16657.78, 1.67], 0.264, 10, 10],
    [[49088.17, -73249.22, 27158.33], [14742.44, 16660.63, 0.20], 0.560, 0, 0],
    [[108255.52, -6104.14, 27158.73], [14738.77, 16655.56, 0.20], 0.560, 10, 10],
    [[112500.78, 31601.55, 14881.13], [14746.50, 16660.20, 1.87], 0.444, 0, 0],
    [[102702.05, 63790.80, 6549.56], [14749.32, 16656.00, 2.54], 0.444, 10, 12],
    [[53513.48, -68250.38, -35849.50], [14741.33, 16661.37, 3.47], 0.350, 0, 3],
    [[8895.34, 113145.54, 25582.04], [14742.99, 16644.86, 1.97], 0.419, 0, 0],
    [[-71236.34, 66982.30, 8604.73], [14742.99, 16644.86, 1.97], 0.419, 7, 7],
    [[-26279.19, 103810.46, -26828.44], [14744.71, 16654.08, 1.47], 1.219, 0, 0]
];

FADE_cutscene_fnc_applyPreparedShot = {
    params [["_cam", objNull], ["_shot", []], ["_commitOverride", -1]];
    if (isNull _cam) exitWith {};
    if !(_shot isEqualType []) exitWith {};
    if ((count _shot) < 4) exitWith {};

    _cam camPrepareTarget (_shot # 0);
    _cam camPreparePos (_shot # 1);
    _cam camPrepareFOV (_shot # 2);
    private _commit = if (!(_commitOverride isEqualTo -1)) then { _commitOverride } else { _shot # 3 };
    _cam camCommitPrepared _commit;
};

// Wait for prepared commit to finish; fall back to wall-clock timeout so we never hang.
FADE_cutscene_fnc_waitPreparedCommit = {
    params [["_cam", objNull], ["_commitSeconds", 0]];
    if (isNull _cam) exitWith {};
    if (_commitSeconds <= 0) exitWith {
        sleep 0.05;
    };

    private _deadline = time + _commitSeconds + 0.35;
    waitUntil {
        sleep 0.02;
        isNull _cam
        || { camCommitted _cam }
        || { time >= _deadline }
    };
};

// Apply one prepared shot, wait for commit, then post-commit hold (sleep #4).
// Prefer FADE_cutscene_fnc_holdSeconds from inside a spawn script (see Phase 2).
FADE_cutscene_fnc_runPreparedShot = {
    params [["_cam", objNull], ["_shot", []], ["_commitOverride", -1], ["_sleepOverride", -1]];
    if (isNull _cam) exitWith {};
    if !(_shot isEqualType []) exitWith {};

    private _commit = if (!(_commitOverride isEqualTo -1)) then { _commitOverride } else {
        if ((count _shot) >= 4) then { _shot # 3 } else { 0 }
    };
    private _sleepAfter = if (!(_sleepOverride isEqualTo -1)) then { _sleepOverride } else {
        if ((count _shot) >= 5) then { _shot # 4 } else { 0 }
    };

    [_cam, _shot, _commit] call FADE_cutscene_fnc_applyPreparedShot;
    [_cam, _commit] call FADE_cutscene_fnc_waitPreparedCommit;

    if (_sleepAfter > 0) then {
        sleep _sleepAfter;
    };
};

// Accumulator sleep — must be called from a scheduled context (spawn), not via remoteExec.
FADE_cutscene_fnc_holdSeconds = {
    params [["_seconds", 0], ["_cam", objNull]];
    if (_seconds <= 0) exitWith {};
    private _slept = 0;
    while {
        uiNamespace getVariable ["FADE_cutscene_testCam_active", false]
        && { !isNull _cam }
        && { _slept < _seconds }
    } do {
        private _slice = (_seconds - _slept) min 0.25;
        sleep _slice;
        _slept = _slept + _slice;
    };
};

// T=0 is start of prepared sequence. Per-shot span = commitSeconds + sleepSeconds (same as main loop).
FADE_cutscene_fnc_prepSeekAtTime = {
    params [["_shots", []], ["_tSeek", 0]];
    if !(_shots isEqualType []) exitWith { [0, 0] };
    if ((count _shots) < 1) exitWith { [0, 0] };

    private _cum = 0;
    for "_i" from 0 to ((count _shots) - 1) do {
        private _s = _shots # _i;
        private _c = if ((count _s) >= 4) then { _s # 3 } else { 0 };
        private _sl = if ((count _s) >= 5) then { _s # 4 } else { 0 };
        private _dur = _c + _sl;

        private _match = false;
        if (_dur > 0) then {
            if ((_tSeek >= _cum) && {_tSeek < _cum + _dur}) then { _match = true };
        } else {
            if (_tSeek <= _cum) then { _match = true };
        };

        if (_match) exitWith {
            [_i, (_tSeek - _cum) max 0]
        };

        _cum = _cum + _dur;
    };

    private _last = (count _shots) - 1;
    private _ls = _shots # _last;
    private _lc = if ((count _ls) >= 4) then { _ls # 3 } else { 0 };
    private _lsl = if ((count _ls) >= 5) then { _ls # 4 } else { 0 };
    [_last, _lc + _lsl]
};

// Seconds left in the prepared sequence when global timeline is at _tSeek (handoff uses this).
FADE_cutscene_fnc_prepRemainingDuration = {
    params [["_shots", []], ["_tSeek", 0]];
    if !(_shots isEqualType []) exitWith { 0 };
    if ((count _shots) < 1) exitWith { 0 };

    private _seek = [_shots, _tSeek] call FADE_cutscene_fnc_prepSeekAtTime;
    _seek params ["_si", "_off"];

    private _remain = 0;
    for "_k" from _si to ((count _shots) - 1) do {
        private _s = _shots # _k;
        private _c = if ((count _s) >= 4) then { _s # 3 } else { 0 };
        private _sl = if ((count _s) >= 5) then { _s # 4 } else { 0 };
        if (_k == _si) then {
            _remain = _remain + (((_c + _sl) - _off) max 0);
        } else {
            _remain = _remain + _c + _sl;
        };
    };
    _remain
};

// Move each client to a viewer slot in front of the monitor before the sequence starts.
FADE_cutscene_testCam_clientPlaceViewer = {
    params [["_screenVarName", "Radio_1"]];
    if (!hasInterface) exitWith {};
    if (isNull player) exitWith {};

    private _screen = [_screenVarName] call FADE_cutscene_fnc_resolveEdenObject;
    if (isNull _screen) then { _screen = ["Radio_1"] call FADE_cutscene_fnc_resolveEdenObject };
    if (isNull _screen) exitWith {};

    private _base = getPosATL _screen;
    private _dir = getDir _screen;
    private _fwd = [sin _dir, cos _dir, 0];
    private _right = [cos _dir, -sin _dir, 0];
    private _slot = (clientOwner mod 7) - 3; // spread clients left/right of center
    private _pos = _base vectorAdd ((_fwd vectorMultiply 2.2) vectorAdd (_right vectorMultiply (_slot * 0.7)));
    player setPosATL _pos;
    player setDir (_pos getDir _base);
};

FADE_cutscene_testCam_clientCleanup = {
    if (!hasInterface) exitWith {};

    showCinemaBorder false;

    private _cam = uiNamespace getVariable ["FADE_cutscene_testCam_cam", objNull];
    if (!isNull _cam) then {
        _cam camCommit 0;
        _cam cameraEffect ["terminate", "BACK"];
        camDestroy _cam;
    };
    uiNamespace setVariable ["FADE_cutscene_testCam_cam", nil];

    private _rttCam = uiNamespace getVariable ["FADE_cutscene_testCam_rttCam", objNull];
    if (!isNull _rttCam) then {
        _rttCam camCommit 0;
        _rttCam cameraEffect ["terminate", "BACK"];
        camDestroy _rttCam;
    };
    uiNamespace setVariable ["FADE_cutscene_testCam_rttCam", nil];

    private _screen = uiNamespace getVariable ["FADE_cutscene_testCam_screen", objNull];
    private _indices = uiNamespace getVariable ["FADE_cutscene_testCam_indices", [0]];
    private _restoreTex = "img\laptopJukebox.jpg";
    if (!isNull _screen) then {
        {
            _screen setObjectTextureGlobal [_x, _restoreTex];
            _screen setObjectTexture [_x, _restoreTex];
        } forEach _indices;
    };
    uiNamespace setVariable ["FADE_cutscene_testCam_screen", nil];
    uiNamespace setVariable ["FADE_cutscene_testCam_indices", nil];
};

FADE_cutscene_testCam_clientTeardownLocal = {
    if (!hasInterface) exitWith {};

    private _h = uiNamespace getVariable ["FADE_cutscene_testCam_loopScript", nil];
    if (!isNil "_h") then {
        if (!scriptDone _h) then { terminate _h };
    };
    uiNamespace setVariable ["FADE_cutscene_testCam_loopScript", nil];

    uiNamespace setVariable ["FADE_cutscene_testCam_active", false];
    [] call FADE_cutscene_testCam_clientCleanup;
};

// Normal end from the cutscene spawn — cleanup without terminating the caller script.
FADE_cutscene_testCam_clientFinish = {
    if (!hasInterface) exitWith {};

    uiNamespace setVariable ["FADE_cutscene_testCam_active", false];
    uiNamespace setVariable ["FADE_cutscene_testCam_loopScript", nil];
    [] call FADE_cutscene_testCam_clientCleanup;
    [] remoteExec ["FADE_cutscene_testCam_serverFinished", 2];
};

// Normal end: release camera / bars; music keeps playing (track has its own fade-out).
FADE_cutscene_testCam_clientEnd = {
    if (!hasInterface) exitWith {};
    [] call FADE_cutscene_testCam_clientTeardownLocal;
    [] remoteExec ["FADE_cutscene_testCam_serverFinished", 2];
};

// Abort (server-initiated or explicit stop): silence music and tear down locally.
FADE_cutscene_testCam_clientStop = {
    if (!hasInterface) exitWith {};
    [] call FADE_cutscene_testCam_clientStopMusic;
    [] call FADE_cutscene_testCam_clientTeardownLocal;
};

// Params retained for server API compatibility.
// Phase 1 (laptop RTT) ends at handoff (31s). Phase 2 plays the full remaining prepared-camera sequence.
FADE_cutscene_testCam_clientStart = {
    params [
        ["_screenVarName", "Radio_1"],
        ["_indices", [0]],
        ["_totalSeconds", -1],
        ["_stepSeconds", 3]
    ];

    if (!hasInterface) exitWith {};

    [] call FADE_cutscene_testCam_clientStopMusic;
    [] call FADE_cutscene_testCam_clientTeardownLocal;
    [_screenVarName] call FADE_cutscene_testCam_clientPlaceViewer;

    private _screen = [_screenVarName] call FADE_cutscene_fnc_resolveEdenObject;
    if (isNull _screen) then {
        _screen = ["Radio_1"] call FADE_cutscene_fnc_resolveEdenObject;
    };
    if !(_indices isEqualType []) then { _indices = [0] };
    if (count _indices == 0) then { _indices = [0] };

    if !(_stepSeconds isEqualType 0) then { _stepSeconds = 3 };
    if (_stepSeconds <= 0) then { _stepSeconds = 3 };

    private _fixedShots = missionNamespace getVariable ["FADE_cutscene_testCam_sequenceFixed", FADE_cutscene_testCam_sequenceFixed];
    // Final hold shot (tuned for ~92s total when handoff is at 31s); not scaled to _totalSeconds.
    private _lastShot = [[-43660.63, 91225.61, -32024.27], [14748.16, 16650.30, 3.71], 0.309, 11, 8];
    private _prepShots = +_fixedShots;
    _prepShots pushBack _lastShot;

    private _handoffAt = 31;
    if (!(_totalSeconds isEqualType 0) || { _totalSeconds <= 0 }) then {
        _totalSeconds = _handoffAt + ([_prepShots, _handoffAt] call FADE_cutscene_fnc_prepRemainingDuration);
    };

    private _keyframes = missionNamespace getVariable ["FADE_cutscene_testCam_keyframes", FADE_cutscene_testCam_keyframes];
    if !(_keyframes isEqualType []) then { _keyframes = FADE_cutscene_testCam_keyframes };
    if ((count _keyframes) < 1) exitWith {
        systemChat "CUTSCENE: no Splendid keyframes for laptop feed.";
        showCinemaBorder false;
    };

    [] spawn {
        sleep 0.15;
        waitUntil { !isNull (findDisplay 46) };
        showCinemaBorder true;
    };

    private _rttName = "FADE_cutscene_test_rtt";
    private _rttCam = "camera" camCreate [0, 0, 0];
    if (isNull _rttCam) exitWith {
        systemChat "CUTSCENE: failed to create RTT camera.";
        showCinemaBorder false;
    };
    [_rttCam, _keyframes # 0] call FADE_cutscene_fnc_applySplendidTupleToCam;
    _rttCam cameraEffect ["Internal", "BACK", _rttName];

    if (!isNull _screen) then {
        private _tex = format ["#(argb,%1,%1,1)r2t(%2,%3)", 1024, _rttName, 1.0];
        sleep 0.05;
        {
            _screen setObjectTextureGlobal [_x, _tex];
            _screen setObjectTexture [_x, _tex];
        } forEach _indices;
        [_screen, _indices, _tex] spawn {
            params ["_scr", "_idx", "_tex2"];
            sleep 0.12;
            if (isNull _scr) exitWith {};
            {
                _scr setObjectTextureGlobal [_x, _tex2];
                _scr setObjectTexture [_x, _tex2];
            } forEach _idx;
        };
    } else {
        systemChat format ["CUTSCENE: screen object '%1' and fallback 'Radio_1' not found.", _screenVarName];
    };

    uiNamespace setVariable ["FADE_cutscene_testCam_cam", objNull];
    uiNamespace setVariable ["FADE_cutscene_testCam_rttCam", _rttCam];
    uiNamespace setVariable ["FADE_cutscene_testCam_screen", _screen];
    uiNamespace setVariable ["FADE_cutscene_testCam_indices", _indices];
    uiNamespace setVariable ["FADE_cutscene_testCam_active", true];

    private _t0 = time;
    _handoffAt = _handoffAt min _totalSeconds;

    private _h = [_rttCam, _prepShots, _keyframes, _t0, _stepSeconds, _handoffAt, _screen, _indices] spawn {
        params ["_rttCam", "_prepShots", "_keyframes", "_t0", "_stepSeconds", "_handoffAt", "_screen", "_indices"];
        private _restoreTex = "img\laptopJukebox.jpg";

        // Phase 1 — laptop shows Splendid / actor virtual camera only (player stays in first person).
        private _kfN = count _keyframes;
        private _idxKf = 0;
        while {
            uiNamespace getVariable ["FADE_cutscene_testCam_active", false]
            && { !isNull _rttCam }
            && { (time - _t0) < _handoffAt }
        } do {
            private _slept = 0;
            while {
                uiNamespace getVariable ["FADE_cutscene_testCam_active", false]
                && { !isNull _rttCam }
                && { _slept < _stepSeconds }
                && { (time - _t0) < _handoffAt }
            } do {
                private _slice = (_stepSeconds - _slept) min 0.25;
                sleep _slice;
                _slept = _slept + _slice;
            };
            if (
                !(uiNamespace getVariable ["FADE_cutscene_testCam_active", false])
                || { isNull _rttCam }
                || { (time - _t0) >= _handoffAt }
            ) exitWith {};

            _idxKf = (_idxKf + 1) mod _kfN;
            [_rttCam, _keyframes select _idxKf] call FADE_cutscene_fnc_applySplendidTupleToCam;
        };

        if (!isNull _rttCam) then {
            _rttCam camCommit 0;
            _rttCam cameraEffect ["terminate", "BACK"];
            camDestroy _rttCam;
        };
        uiNamespace setVariable ["FADE_cutscene_testCam_rttCam", nil];
        sleep 0.2;

        if (!isNull _screen) then {
            {
                _screen setObjectTextureGlobal [_x, _restoreTex];
                _screen setObjectTexture [_x, _restoreTex];
            } forEach _indices;
        };

        // Hand off to a dedicated Phase 2 spawn (loopScript handle tracks this script).
        uiNamespace setVariable ["FADE_cutscene_testCam_loopScript", [_prepShots, _handoffAt] spawn {
            params ["_prepShots", "_handoffAt"];

            sleep 0.2;

            private _cam = "camera" camCreate [0, 0, 0];
            if (isNull _cam) exitWith { [] call FADE_cutscene_testCam_clientFinish };

            uiNamespace setVariable ["FADE_cutscene_testCam_cam", _cam];

            private _seek = [_prepShots, _handoffAt] call FADE_cutscene_fnc_prepSeekAtTime;
            _seek params ["_si", "_off"];

            private _hold = {
                params ["_seconds"];
                if (_seconds <= 0) exitWith {};
                private _slept = 0;
                while {
                    !isNull _cam
                    && { _slept < _seconds }
                } do {
                    private _slice = (_seconds - _slept) min 0.25;
                    sleep _slice;
                    _slept = _slept + _slice;
                };
            };

            private _s0 = _prepShots # _si;
            private _c0 = if ((count _s0) >= 4) then { _s0 # 3 } else { 0 };
            private _sl0 = if ((count _s0) >= 5) then { _s0 # 4 } else { 0 };

            if (_off < _c0) then {
                private _remC = (_c0 - _off) max 0;
                if (_remC < 1e-4) then {
                    [_cam, _s0, 0] call FADE_cutscene_fnc_applyPreparedShot;
                } else {
                    [_cam, _s0, _remC] call FADE_cutscene_fnc_applyPreparedShot;
                };
                _cam cameraEffect ["Internal", "BACK"];
                diag_log format ["[CUTSCENE] P2 handoff shot %1 commit=%2 hold=%3", _si, _remC, _sl0];
                systemChat format ["CUTSCENE P2: shot %1/%2, %3s zoom + %4s hold", _si + 1, count _prepShots, _remC, _sl0];
                [_remC] call _hold;
                [_sl0] call _hold;
            } else {
                [_cam, _s0, 0] call FADE_cutscene_fnc_applyPreparedShot;
                _cam cameraEffect ["Internal", "BACK"];
                private _remS = (_sl0 - (_off - _c0)) max 0;
                [_remS] call _hold;
            };

            private _k = _si + 1;
            while {
                _k < (count _prepShots)
                && { !isNull _cam }
            } do {
                private _shot = _prepShots # _k;
                [_cam, _shot] call FADE_cutscene_fnc_applyPreparedShot;
                private _cc = if ((count _shot) >= 4) then { _shot # 3 } else { 0 };
                private _sleepFor = if ((count _shot) >= 5) then { _shot # 4 } else { 0 };
                [_cc] call _hold;
                [_sleepFor] call _hold;
                _k = _k + 1;
            };

            [] call FADE_cutscene_testCam_clientFinish;
        }];
    };

    uiNamespace setVariable ["FADE_cutscene_testCam_loopScript", _h];

    private _emitterVar = if (isNull (["Radio_1"] call FADE_cutscene_fnc_resolveEdenObject)) then { _screenVarName } else { "Radio_1" };
    ["FAC_cutscene_callonme", _emitterVar] call FADE_cutscene_testCam_clientPlayMusic;
};
