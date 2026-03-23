// Runs from CfgFunctions preInit, init.sqf, and Config.sqf — first line always reapplies stubs.
// BIS lazy-loads bis_fnc_cp_main into uiNamespace; combat could compile it the same frame as a shot.
call compile preprocessFileLineNumbers "rsc\fn_bisCpStubApply.sqf";

if (missionNamespace getVariable ["FADE_bisCpStubGuardStarted", false]) exitWith {};
missionNamespace setVariable ["FADE_bisCpStubGuardStarted", true];

addMissionEventHandler ["EachFrame", {
    if (missionNamespace getVariable ["FADE_debugBIScp", false]) exitWith {};
    private _m = missionNamespace getVariable "FADE_fnc_bisCpMainNoop";
    private _d = missionNamespace getVariable "FADE_fnc_bisCpDelayZero";
    missionNamespace setVariable ["bis_fnc_cp_main", _m];
    missionNamespace setVariable ["bis_fnc_cp_getQueueDelay", _d];
    uiNamespace setVariable ["bis_fnc_cp_main", _m];
    uiNamespace setVariable ["bis_fnc_cp_getQueueDelay", _d];
}];
