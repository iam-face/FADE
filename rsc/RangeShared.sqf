// =============================================================================
// RangeShared.sqf — shared helpers for firing/AT range, reusing sniper logic
// =============================================================================
if (!isServer) exitWith {};

FADE_rangeShared_setSniperMirrorState = {
    params [
        ["_active", false],
        ["_starter", objNull],
        ["_starterUid", ""],
        ["_hitTrack", false],
        ["_mode", "firing"]
    ];
    missionNamespace setVariable ["FADE_sniperRangeActive", _active];
    missionNamespace setVariable ["FADE_sniperStarterUnit", _starter];
    missionNamespace setVariable ["FADE_sniperStarterUid", _starterUid, true];
    missionNamespace setVariable ["FADE_sniperHitTrack", _hitTrack];
    missionNamespace setVariable ["FADE_sniperSessionMode", _mode];
};

FADE_rangeShared_enableStarterFx = {
    params [["_starter", objNull], ["_trace", false]];
    if (isNull _starter) exitWith {};
    if (_trace) then { [true] remoteExec ["FADE_sniperClient_setProjectileTrace", _starter] };
    [true] remoteExec ["FADE_sniperClient_setProjectileImpactMarkers", _starter];
};

FADE_rangeShared_disableStarterFx = {
    params [["_starter", objNull]];
    if (isNull _starter) exitWith {};
    [] remoteExec ["FADE_sniperClient_clearRangeFx", _starter];
};
