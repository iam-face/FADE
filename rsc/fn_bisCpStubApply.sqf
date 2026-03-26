// Install bis_fnc_cp_* stubs in BOTH missionNamespace and uiNamespace. BIS often resolves
// campaign functions from uiNamespace; mission-only globals were not enough (RPT: _threat).
// bis_fnc_cp_main must return a small array of scalars — CP/CPE unpack into _threat etc.; { nil }
// or [] caused "undefined variable in expression: _threat" when callers params/select without defaults.
if (isNil { missionNamespace getVariable "FADE_fnc_bisCpMainNoop" }) then {
    missionNamespace setVariable ["FADE_fnc_bisCpMainNoop", { [0, 0, 0, 0] }];
    missionNamespace setVariable ["FADE_fnc_bisCpDelayZero", { 0 }];
};
private _m = missionNamespace getVariable "FADE_fnc_bisCpMainNoop";
private _d = missionNamespace getVariable "FADE_fnc_bisCpDelayZero";
missionNamespace setVariable ["bis_fnc_cp_main", _m];
missionNamespace setVariable ["bis_fnc_cp_getQueueDelay", _d];
uiNamespace setVariable ["bis_fnc_cp_main", _m];
uiNamespace setVariable ["bis_fnc_cp_getQueueDelay", _d];
