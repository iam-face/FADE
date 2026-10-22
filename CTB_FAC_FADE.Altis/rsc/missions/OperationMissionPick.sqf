// OperationMissionPick.sqf - hub/spoke zone pick
if (!isServer) exitWith {};
FADE_operation_pickZones = {
    params ["_civCandidates", "_wantN", ["_mapAnchor", []]];
    if (count _civCandidates == 0) exitWith { [] };

    private _fnc_entryPos = {
        params ["_entry"];
        [_entry select 1] call FADE_normPos3
    };

    private _hubZone = [];
    if ([_mapAnchor] call FADE_fnc_isValidMapClickPos) then {
        private _byClick = [_civCandidates, [], { _mapAnchor distance2D ([_x] call _fnc_entryPos) }, "ASCEND"] call BIS_fnc_sortBy;
        if (count _byClick > 0) then { _hubZone = _byClick select 0 };
    } else {
        _hubZone = selectRandom _civCandidates;
    };
    if (count _hubZone == 0) exitWith { [] };

    private _remaining = _civCandidates - [_hubZone];
    if (count _remaining == 0) exitWith { [_hubZone] };

    private _pool = [_remaining, [], { ([_hubZone] call _fnc_entryPos) distance2D ([_x] call _fnc_entryPos) }, "ASCEND"] call BIS_fnc_sortBy;
    private _take = ((_wantN - 1) max 0) min count _pool;
    [_hubZone] + (_pool select [0, _take])
};
