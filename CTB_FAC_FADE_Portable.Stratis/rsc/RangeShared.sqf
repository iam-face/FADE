// =============================================================================
// RangeShared.sqf  -  shared helpers for firing/AT range (server; hit EHs live in SniperRangeServer)
// =============================================================================
if (!isServer) exitWith {};

// Firing range uses its own starter + hit-track flags; do not touch FADE_sniper* session globals.
FADE_rangeShared_setRangeHitTrack = {
    params [["_hitTrack", false]];
    missionNamespace setVariable ["FADE_rangeHitTrack", _hitTrack];
};

FADE_rangeShared_enableStarterFx = {
    params [["_starter", objNull], ["_trace", false]];
    if (isNull _starter) exitWith {};
    private _term = call FADE_rangeTerminalObj;
    private _termPos = if (!isNull _term) then { getPosATL _term } else { [] };
    [_trace, _termPos] remoteExec ["FADE_rangeClient_enableSniperFxForRange", _starter];
};

FADE_rangeShared_disableStarterFx = {
    params [["_starter", objNull]];
    if (isNull _starter) exitWith {};
    if (!isNull _starter) then {
        [false, _starter] remoteExec ["FADE_sniperClient_setProjectileTrace", 0, _starter];
        [] remoteExec ["FADE_sniperClient_stopTraceProximityMonitor", _starter];
    };
    [] remoteExec ["FADE_rangeClient_disableSniperFxForRange", _starter];
};
