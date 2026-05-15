// =============================================================================
// RangeShared.sqf — shared helpers for firing/AT range (server; hit EHs live in SniperRangeServer)
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
    [_trace] remoteExec ["FADE_rangeClient_enableSniperFxForRange", _starter];
};

FADE_rangeShared_disableStarterFx = {
    params [["_starter", objNull]];
    if (isNull _starter) exitWith {};
    [] remoteExec ["FADE_rangeClient_disableSniperFxForRange", _starter];
};
