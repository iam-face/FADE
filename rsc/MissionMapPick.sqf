// =============================================================================
// MissionMapPick.sqf — map click for mission AO (client). Compiled via FAC_ensureMissionsGui.
// =============================================================================
if (!hasInterface) exitWith {};

FAC_missionMapPick_fnc_parseClickPos = {
    params ["_units", "_pos", "_alt", "_shift"];
    if (!(_pos isEqualType []) || { count _pos < 2 }) exitWith { [] };
    private _x = _pos select 0;
    private _y = _pos select 1;
    if (!(_x isEqualType 0) || {!(_y isEqualType 0)}) exitWith { [] };
    private _z = if ((count _pos >= 3) && { (_pos select 2) isEqualType 0 }) then { _pos select 2 } else { 0 };
    [_x, _y, _z]
};

FAC_missionMapPick_fnc_start = {
    params ["_missionType"];
    if (_missionType isEqualType []) then { _missionType = _missionType param [0, ""] };
    if (_missionType == "") exitWith {
        systemChat "MISSION: map pick aborted (no mission type).";
    };
    if (missionNamespace getVariable ["FAC_missionMapPick_active", false]) exitWith {
        systemChat "MISSION: map location pick already in progress.";
    };

    missionNamespace setVariable ["FAC_missionMapPick_active", true];
    missionNamespace setVariable ["FAC_missionMapPick_type", _missionType];

    private _timeout = missionNamespace getVariable ["FADE_missionMapPickTimeoutSec", 20];

    openMap true;
    hint format [
        "Click the map for mission area.%1%2You have %3 seconds — mission aborts if you do not click.",
        toString [10, 10],
        if (_missionType in (missionNamespace getVariable ["FADE_missionMapClickSnapCivZoneTypes", []])) then {
            "Settlement missions snap to the nearest civ zone to your click."
        } else {
            "Search expands: 250 m, 500 m, 1 km, 2.5 km, 5 km, then whole map — as close as possible to your click."
        },
        _timeout
    ];

    private _eh = addMissionEventHandler ["MapSingleClick", {
        params ["_units", "_pos", "_alt", "_shift"];
        private _ehId = _thisEventHandler;
        removeMissionEventHandler ["MapSingleClick", _ehId];
        missionNamespace setVariable ["FAC_missionMapPick_mapEh", -1];
        missionNamespace setVariable ["FAC_missionMapPick_active", false];
        if (visibleMap) then { openMap false };
        private _clickPos = [_units, _pos, _alt, _shift] call FAC_missionMapPick_fnc_parseClickPos;
        if (count _clickPos < 2) exitWith {
            hint "Mission start cancelled — invalid map click.";
            systemChat "Mission start cancelled — invalid map click.";
        };
        if (surfaceIsWater _clickPos) exitWith {
            hint "Mission start cancelled — cannot select water.";
            systemChat "Mission start cancelled — cannot select water.";
        };
        private _mt = missionNamespace getVariable ["FAC_missionMapPick_type", ""];
        if (_mt == "") exitWith {};
        if (_mt == "TroopInsert") then {
            uinamespace setVariable ["FAC_troopInsert_lzAnchor", _clickPos];
            if (isNil "FAC_troopInsertPickGui_fnc") exitWith {
                systemChat "TROOP INSERT UI not loaded.";
            };
            ["open", []] call FAC_troopInsertPickGui_fnc;
            hint parseText "<t size='1.1' color='#A0D0A0'>LZ area selected.</t><br/><t color='#808080'>Choose participants and mode. Later recurring waves use random positions.</t>";
        } else {
            [_mt, player, _clickPos] spawn {
                params ["_mt", "_pl", "_clickPos"];
                [_mt, _pl, _clickPos] remoteExec ["FADE_startMission", 2];
                hint parseText "<t size='1.1' color='#A0D0A0'>Loading mission...</t><br/><t color='#808080'>Details will be provided shortly.</t>";
            };
        };
    }];
    missionNamespace setVariable ["FAC_missionMapPick_mapEh", _eh];

    [_timeout] spawn {
        params ["_timeout"];
        private _deadline = time + _timeout;
        while {
            (missionNamespace getVariable ["FAC_missionMapPick_active", false])
            && { time < _deadline }
        } do {
            private _rem = (ceil (_deadline - time)) max 0;
            hint format [
                "Click the map for mission area.%1%2%3 s remaining — mission aborts if you do not click.",
                toString [10, 10],
                if (missionNamespace getVariable ["FAC_missionMapPick_type", ""] in (missionNamespace getVariable ["FADE_missionMapClickSnapCivZoneTypes", []])) then {
                    "Snaps to nearest civ settlement zone."
                } else {
                    "Search: 250 m → 5 km → whole map (closest valid site)."
                },
                _rem
            ];
            sleep 1;
        };
        if (!(missionNamespace getVariable ["FAC_missionMapPick_active", false])) exitWith {};
        private _ehId = missionNamespace getVariable ["FAC_missionMapPick_mapEh", -1];
        if (_ehId >= 0) then { removeMissionEventHandler ["MapSingleClick", _ehId] };
        missionNamespace setVariable ["FAC_missionMapPick_mapEh", -1];
        missionNamespace setVariable ["FAC_missionMapPick_active", false];
        if (visibleMap) then { openMap false };
        hint "Mission start cancelled — no map location selected.";
        systemChat "Mission start cancelled — no map location selected.";
    };
};

missionNamespace setVariable ["FAC_missionMapPick_fnc_parseClickPos", FAC_missionMapPick_fnc_parseClickPos];
missionNamespace setVariable ["FAC_missionMapPick_fnc_start", FAC_missionMapPick_fnc_start];
