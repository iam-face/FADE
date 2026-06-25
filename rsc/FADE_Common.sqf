// =============================================================================
// FADE_Common.sqf  -  shared helpers (server boot; compiled from initServer)
// =============================================================================

FADE_normPos3 = {
    params ["_p"];
    if (!(_p isEqualType []) || { count _p < 2 }) exitWith { [0, 0, 0] };
    if (count _p < 3) then { [(_p select 0), (_p select 1), 0] } else { _p }
};

FADE_surfaceIsDry = {
    params ["_p"];
    if (!(_p isEqualType []) || { count _p < 2 }) exitWith { false };
    !surfaceIsWater [_p select 0, _p select 1]
};

FADE_findSafePosArray = {
    params ["_args", "_fallback"];
    private _r = _args call BIS_fnc_findSafePos;
    if (!(_r isEqualType [])) exitWith { [_fallback] call FADE_normPos3 };
    if (count _r < 2) exitWith { [_fallback] call FADE_normPos3 };
    [_r] call FADE_normPos3
};

FADE_jitterMarkerPos = {
    params [["_pos", [0, 0, 0]], ["_radiusM", 100]];
    private _p = [_pos] call FADE_normPos3;
    if (_radiusM <= 0) exitWith { +_p };
    private _j = [_p, random _radiusM, random 360] call BIS_fnc_relPos;
    [(_j select 0), (_j select 1), (_p select 2)]
};

FADE_missionErrorHint = {
    params ["_player", "_title", "_body"];
    if (isNull _player) exitWith {};
    [format [
        "<t size='1.2' color='#FF6666'>%1</t><br/><br/><t color='#E0E0E0'>%2</t>",
        _title,
        _body
    ]] remoteExec ["FADE_showMissionHint", _player];
};

FADE_missionSlotGateHint = {
    params ["_player", "_reason"];
    if (isNull _player) exitWith {};
    private _html = switch (_reason) do {
        case "active": {
            "<t size='1.2' color='#FFAA00'>MISSION ACTIVE</t><br/><br/><t color='#E0E0E0'>You already have an active mission. Abort it before starting another.</t>"
        };
        case "global": {
            "<t size='1.2' color='#FFAA00'>GLOBAL MISSION ACTIVE</t><br/><br/><t color='#E0E0E0'>Another global mission is in progress. Abort it or wait for completion.</t>"
        };
        case "slotsFull": {
            "<t size='1.2' color='#FFAA00'>SINGLE SLOTS FULL</t><br/><br/><t color='#E0E0E0'>All single-mission slots are in use. Abort a mission or wait.</t>"
        };
        default {
            "<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Cannot start mission.</t>"
        };
    };
    [_html] remoteExec ["FADE_showMissionHint", _player];
};

missionNamespace setVariable ["FADE_normPos3", FADE_normPos3];
missionNamespace setVariable ["FADE_surfaceIsDry", FADE_surfaceIsDry];
missionNamespace setVariable ["FADE_findSafePosArray", FADE_findSafePosArray];
missionNamespace setVariable ["FADE_jitterMarkerPos", FADE_jitterMarkerPos];
missionNamespace setVariable ["FADE_missionErrorHint", FADE_missionErrorHint];
missionNamespace setVariable ["FADE_missionSlotGateHint", FADE_missionSlotGateHint];
