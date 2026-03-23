// =============================================================================
// DebugBIScpStub.sqf - Find what calls missing BIS campaign functions
// =============================================================================
// Run from initServer.sqf and initPlayerLocal.sqf at mission start.
// Installs stubs for bis_fnc_cp_getQueueDelay (and optionally bis_fnc_cp_main)
// so when a mod/script calls them we log the call stack to RPT instead of
// erroring. Set FADE_debugBIScp = false before this runs to disable.
// Once you've found the caller in RPT, you can remove this or set false.
// =============================================================================

// Default OFF: stubs replace BIS campaign functions with dummy returns; that breaks callers
// that expect real numbers/structures (RPT: _threat > 0.1 with Type Array). Set true only
// when deliberately tracing who calls bis_fnc_cp_*.
if (missionNamespace getVariable ["FADE_debugBIScp", false] != true) exitWith {};

private _stubGetQueueDelay = {
    diag_log "[FADE BIS CP DEBUG] ========== bis_fnc_cp_getQueueDelay CALLED ==========";
    diag_log format ["[FADE BIS CP DEBUG] _this = %1", _this];
    diag_log format ["[FADE BIS CP DEBUG] time = %1", time];
    private _stack = diag_stacktrace;
    if (!isNil "_stack" && { _stack isEqualType [] }) then {
        diag_log "[FADE BIS CP DEBUG] --- diag_stacktrace (call stack) ---";
        { diag_log format ["[FADE BIS CP DEBUG]   %1: fn=%2 line=%3 scope=%4", _forEachIndex, _x param [0,""], _x param [1,0], _x param [2,""]] } forEach _stack;
    } else {
        diag_log "[FADE BIS CP DEBUG] diag_stacktrace not available or empty";
    };
    diag_log "[FADE BIS CP DEBUG] ========================================";
    0
};

private _stubCpMain = {
    diag_log "[FADE BIS CP DEBUG] ========== bis_fnc_cp_main CALLED ==========";
    diag_log format ["[FADE BIS CP DEBUG] _this = %1", _this];
    private _stack = diag_stacktrace;
    if (!isNil "_stack" && { _stack isEqualType [] }) then {
        diag_log "[FADE BIS CP DEBUG] --- diag_stacktrace ---";
        { diag_log format ["[FADE BIS CP DEBUG]   %1: fn=%2 line=%3 scope=%4", _forEachIndex, _x param [0,""], _x param [1,0], _x param [2,""]] } forEach _stack;
    };
    diag_log "[FADE BIS CP DEBUG] ========================================";
    []
};

missionNamespace setVariable ["bis_fnc_cp_getQueueDelay", _stubGetQueueDelay];
missionNamespace setVariable ["bis_fnc_cp_main", _stubCpMain];
uiNamespace setVariable ["bis_fnc_cp_getQueueDelay", _stubGetQueueDelay];
uiNamespace setVariable ["bis_fnc_cp_main", _stubCpMain];
diag_log "[FADE BIS CP DEBUG] Stubs installed for bis_fnc_cp_getQueueDelay and bis_fnc_cp_main. Check RPT for '[FADE BIS CP DEBUG]' when the error would have occurred.";
