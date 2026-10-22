// =============================================================================
// FADE_HeadlessTest.sqf ? dedicated-server auto-test (no player required).
// Trigger: headless_test.flg in mission root (written by tools/headless runner).
// Modes: boot | compile | testsuite | playthrough | all
// Results: RPT ([FAC Headless], [FAC TestSuite], ?)
// =============================================================================

if (!isServer) exitWith {};

FADE_headlessTest__writeResult = {
    params ["_mode", "_pass", "_fail", ["_skip", 0], ["_note", ""]];
    private _ts = systemTime apply { str _x } joinString "-";
    {
        diag_log format ["[FAC Headless] %1", _x];
    } forEach [
        format ["mode=%1", _mode],
        format ["pass=%1", _pass],
        format ["fail=%1", _fail],
        format ["skip=%1", _skip],
        format ["note=%1", _note],
        format ["finished=%1", _ts]
    ];
    diag_log "[FAC Headless] ========== DONE ==========";
};

FADE_headlessTest__lightenWorld = {
    missionNamespace setVariable ["FADE_headlessTestActive", true];
    missionNamespace setVariable ["FAC_param_civiliansAtStart", 0];
    missionNamespace setVariable ["FAC_param_opforThreat", 0];
    missionNamespace setVariable ["FAC_param_opforPatrols", 0];
    missionNamespace setVariable ["FADE_enemyAAALevel", "Off"];
    missionNamespace setVariable ["FADE_opforDroneSetting", "Off"];
};

FADE_headlessTest__runCompileSuite = {
    if (isNil "FAC_missionTestSuite_runServer") then {
        call compile preprocessFile "rsc\MissionTestSuite.sqf";
    };
    if (isNil "FAC_missionTestSuite_runServer") exitWith {
        [0, 1, "MissionTestSuite failed to load"]
    };
    private _res = [objNull] call FAC_missionTestSuite_runServer;
    if (_res isEqualType [] && { count _res >= 2 }) exitWith { _res + [""] };
    [0, 1, "MissionTestSuite returned invalid result"]
};

FADE_headlessTest__runPlaythroughSuite = {
    if (isNil "FAC_playthroughSuite_runServer") then {
        call compile preprocessFileLineNumbers "rsc\MissionPlaythroughSuite.sqf";
        call compile preprocessFileLineNumbers "rsc\MissionPlaythroughProfiles.sqf";
    };
    if (isNil "FAC_playthroughSuite_runServer") exitWith {
        [0, 1, 0, "PlaythroughSuite failed to load"]
    };
    private _res = [objNull, []] call FAC_playthroughSuite_runServer;
    if (_res isEqualType [] && { count _res >= 3 }) exitWith {
        private _note = "";
        _res + [_note]
    };
    [0, 1, 0, "PlaythroughSuite returned invalid result"]
};

FADE_headlessTest__runMode = {
    params ["_mode"];
    _mode = toLower (trim _mode);
    private _pass = 0;
    private _fail = 0;
    private _skip = 0;
    private _note = "";

    switch (true) do {
        case (_mode in ["boot"]): {
            _pass = 1;
            _note = "boot marker only";
        };
        case (_mode in ["compile", "testsuite", "suite"]): {
            private _compile = [] call FADE_headlessTest__runCompileSuite;
            _compile params ["_cPass", "_cFail", "_cNote"];
            _pass = _cPass;
            _fail = _cFail;
            _note = _cNote;
        };
        case (_mode isEqualTo "playthrough"): {
            private _play = [] call FADE_headlessTest__runPlaythroughSuite;
            _play params ["_pPass", "_pFail", "_pSkip", "_pNote"];
            _pass = _pPass;
            _fail = _pFail;
            _skip = _pSkip;
            _note = _pNote;
        };
        case (_mode isEqualTo "all"): {
            diag_log "[FAC Headless] --- phase 1/2: MissionTestSuite ---";
            private _compile = [] call FADE_headlessTest__runCompileSuite;
            _compile params ["_cPass", "_cFail", "_cNote"];
            _pass = _cPass;
            _fail = _cFail;
            if (_cFail > 0) exitWith {
                _note = format ["compile failed: %1", _cNote];
            };
            diag_log "[FAC Headless] --- phase 2/2: MissionPlaythroughSuite ---";
            private _play = [] call FADE_headlessTest__runPlaythroughSuite;
            _play params ["_pPass", "_pFail", "_pSkip", "_pNote"];
            _pass = _cPass + _pPass;
            _fail = _cFail + _pFail;
            _skip = _pSkip;
            _note = format ["compile %1/%2; playthrough %3/%4 skip %5", _cPass, _cFail, _pPass, _pFail, _pSkip];
            if (_pNote != "") then { _note = _note + "; " + _pNote };
        };
        default {
            _fail = 1;
            _note = format ["unknown mode %1", _mode];
            diag_log format ["[FAC Headless] ERROR: unknown mode '%1' (use boot|compile|playthrough|all)", _mode];
        };
    };

    [_mode, _pass, _fail, _skip, _note] call FADE_headlessTest__writeResult;
    [_pass, _fail, _skip]
};

FADE_headlessTest__shutdown = {
    sleep 2;
    diag_log "[FAC Headless] suite complete - runner will stop dedicated server";
};

FADE_headlessTest__main = {
    params ["_mode"];
    waitUntil { sleep 0.25; missionNamespace getVariable ["FADE_clientInitReady", false] };
    sleep 2;
    diag_log format ["[FAC Headless] ========== START mode=%1 ==========", _mode];
    [] call FADE_headlessTest__lightenWorld;
    private _res = [_mode] call FADE_headlessTest__runMode;
    _res params ["_pass", "_fail"];
    if (_fail > 0) then {
        diag_log format ["[FAC Headless] FAILED (%1 pass / %2 fail)", _pass, _fail];
    } else {
        diag_log format ["[FAC Headless] PASSED (%1 checks)", _pass];
    };
    [] spawn FADE_headlessTest__shutdown;
};

FADE_headlessTest_boot = {
    if (!isServer) exitWith {};
    private _flg = "headless_test.flg";
    if !(fileExists _flg) exitWith {};
    private _mode = toLower (trim (loadFile _flg));
    if (_mode == "") exitWith {
        diag_log "[FAC Headless] ERROR: headless_test.flg is empty";
    };
    [_mode] spawn FADE_headlessTest__main;
};
