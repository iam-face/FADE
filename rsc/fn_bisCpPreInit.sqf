// Runs from CfgFunctions preInit, init.sqf, and Config.sqf - idempotent per machine.
// Never stub bis_fnc_cp_getQueueDelay with { 0 } alone while real bis_fnc_cp_main still runs: the main
// loop can hit "count _queue > 0 || _threat > 0.1" with _threat undefined (RPT).
// This mission is not a Tac-Ops campaign: real bis_fnc_cp_main must never run — internal _threat is only
// set by full CP init, but CP/CPE can still spawn it during play (e.g. combat), so we always no-op below.
private _mainOk = !isNil "bis_fnc_cp_main" && { typeName bis_fnc_cp_main == "CODE" };
private _delayOk = !isNil "bis_fnc_cp_getQueueDelay" && { typeName bis_fnc_cp_getQueueDelay == "CODE" };

if (_mainOk) then {
    if (!_delayOk) then {
        private _u = uiNamespace getVariable ["bis_fnc_cp_getQueueDelay", nil];
        if (!isNil "_u" && { typeName _u == "CODE" }) then {
            bis_fnc_cp_getQueueDelay = _u;
        } else {
            0 spawn {
                uiSleep 0;
                private _m = missionNamespace getVariable ["bis_fnc_cp_getQueueDelay", nil];
                if (!isNil "_m" && { typeName _m == "CODE" }) exitWith {};
                _m = uiNamespace getVariable ["bis_fnc_cp_getQueueDelay", nil];
                if (!isNil "_m" && { typeName _m == "CODE" }) then {
                    bis_fnc_cp_getQueueDelay = _m;
                };
            };
        };
    };
} else {
    if (!_delayOk) then {
        bis_fnc_cp_getQueueDelay = { 0 };
    };
};

bis_fnc_cp_main = { nil };
