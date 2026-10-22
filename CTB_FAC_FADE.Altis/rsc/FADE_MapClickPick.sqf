// =============================================================================
// FADE_MapClickPick.sqf  -  shared client map-click picker (missions, etc.)
// Uses onMapSingleClick (same reliable pattern as TeleportMapPick.sqf).
// =============================================================================
if (!hasInterface) exitWith {};

FADE_mapClickPick_parsePos = {
    params ["_units", "_pos", "_alt", "_shift"];
    if (!(_pos isEqualType []) || { count _pos < 2 }) exitWith { [] };
    private _x = _pos select 0;
    private _y = _pos select 1;
    if (!(_x isEqualType 0) || {!(_y isEqualType 0)}) exitWith { [] };
    private _z = if ((count _pos >= 3) && { (_pos select 2) isEqualType 0 }) then { _pos select 2 } else { 0 };
    [_x, _y, _z]
};

// Shared countdown hint for map-pick overlays (_rem < 0 = initial message with timeoutSec).
FADE_mapPick_formatCountdownHint = {
    params ["_rem", "_introLines", "_remainingSuffix", "_timeoutSec"];
    private _nl = toString [10, 10];
    if (_rem < 0) then {
        format [
            "%1%2You have %3 seconds - mission aborts if you do not click.",
            _introLines joinString _nl,
            _nl,
            _timeoutSec
        ]
    } else {
        format [
            "%1%2%3 s remaining - mission aborts if you do not click.",
            _introLines joinString _nl,
            _nl,
            _rem
        ]
    }
};

FADE_mapClickPick_clearHandler = {
    onMapSingleClick (str false);
};

FADE_mapClickPick_finish = {
    params ["_activeVar", "_onTimeout", ["_timedOut", false]];
    missionNamespace setVariable [_activeVar, false];
    missionNamespace setVariable ["FADE_mapClickPick_context", nil];
    missionNamespace setVariable ["FADE_mapClickPick_clickPos", nil];
    [] call FADE_mapClickPick_clearHandler;
    if (visibleMap) then { openMap false };
    if (_timedOut) then { call _onTimeout };
};

FADE_mapClickPick_onMapClick = {
    private _pos = missionNamespace getVariable ["FADE_mapClickPick_clickPos", []];
    private _ctx = missionNamespace getVariable ["FADE_mapClickPick_context", []];
    if (count _ctx < 5) exitWith { [] call FADE_mapClickPick_clearHandler };
    _ctx params ["_activeVar", "_ehVar", "_onClick", "_onTimeout", "_rejectWater"];
    if (!(missionNamespace getVariable [_activeVar, false])) exitWith { [] call FADE_mapClickPick_clearHandler };

    missionNamespace setVariable [_activeVar, false];
    missionNamespace setVariable ["FADE_mapClickPick_context", nil];
    missionNamespace setVariable ["FADE_mapClickPick_clickPos", nil];
    [] call FADE_mapClickPick_clearHandler;
    if (visibleMap) then { openMap false };

    private _clickPos = [[], _pos, false, false] call FADE_mapClickPick_parsePos;
    if (count _clickPos < 2) exitWith { call _onTimeout };
    if (_rejectWater && { surfaceIsWater _clickPos }) exitWith {
        hint "Cancelled  -  cannot select water.";
        systemChat "Cancelled  -  cannot select water.";
    };
    [_clickPos] call _onClick;
    true
};

// Args: [activeVar, ehVar (unused legacy slot), timeoutSec, hintBuilderCode, onValidClickCode, onTimeoutCode, rejectWater, openMap]
FADE_mapClickPick_start = {
    params [
        "_activeVar",
        "_ehVar",
        "_timeoutSec",
        "_hintBuilder",
        "_onClick",
        "_onTimeout",
        ["_rejectWater", true],
        ["_openMap", true]
    ];
    if (missionNamespace getVariable [_activeVar, false]) exitWith { false };

    [] call FADE_mapClickPick_clearHandler;
    missionNamespace setVariable [_activeVar, true];
    missionNamespace setVariable ["FADE_mapClickPick_context", [_activeVar, _ehVar, _onClick, _onTimeout, _rejectWater]];
    onMapSingleClick "missionNamespace setVariable ['FADE_mapClickPick_clickPos', _pos]; call FADE_mapClickPick_onMapClick;";
    if (_openMap) then { openMap true };
    hint ([-1] call _hintBuilder);

    [_timeoutSec, _activeVar, _hintBuilder, _onTimeout] spawn {
        params ["_timeout", "_activeVar", "_hintBuilder", "_onTimeout"];
        private _deadline = time + _timeout;
        while {
            (missionNamespace getVariable [_activeVar, false])
            && { time < _deadline }
        } do {
            private _rem = (ceil (_deadline - time)) max 0;
            hint ([_rem] call _hintBuilder);
            sleep 1;
        };
        if (!(missionNamespace getVariable [_activeVar, false])) exitWith {};
        [_activeVar, _onTimeout, true] call FADE_mapClickPick_finish;
    };
    true
};

missionNamespace setVariable ["FADE_mapClickPick_parsePos", FADE_mapClickPick_parsePos];
missionNamespace setVariable ["FADE_mapClickPick_start", FADE_mapClickPick_start];
missionNamespace setVariable ["FADE_mapClickPick_onMapClick", FADE_mapClickPick_onMapClick];
missionNamespace setVariable ["FADE_mapClickPick_clearHandler", FADE_mapClickPick_clearHandler];
missionNamespace setVariable ["FADE_mapClickPick_finish", FADE_mapClickPick_finish];
