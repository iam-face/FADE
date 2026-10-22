// Install bis_fnc_cp_* stubs in BOTH missionNamespace and uiNamespace. BIS often resolves
// campaign functions from uiNamespace; mission-only globals were not enough (RPT: _threat).
// bis_fnc_cp_main: some callers unpack [queue, threat, ...]; others assign the whole return to _threat.
// Returning [0,0,0,0] made _threat an array in that second case (RPT: _threat > 0.1, Type Array).
// Scalar 0 matches the whole-assignment path; { nil } / [] caused undefined _threat for unpackers.
missionNamespace setVariable ["FADE_fnc_bisCpMainNoop", { 0 }];
missionNamespace setVariable ["FADE_fnc_bisCpDelayZero", { 0 }];
private _m = missionNamespace getVariable "FADE_fnc_bisCpMainNoop";
private _d = missionNamespace getVariable "FADE_fnc_bisCpDelayZero";
missionNamespace setVariable ["bis_fnc_cp_main", _m];
missionNamespace setVariable ["bis_fnc_cp_getQueueDelay", _d];
uiNamespace setVariable ["bis_fnc_cp_main", _m];
uiNamespace setVariable ["bis_fnc_cp_getQueueDelay", _d];
