// =============================================================================
// TeleportGui.sqf — Fast Travel GUI (opened from teleportBoard_1..7)
// =============================================================================
// Player selects a destination and is teleported there (client-side setPos).
// Destinations are defined by Eden object names; player is placed 5 m behind the object, facing it.
// =============================================================================

// [displayName, Eden object variable name]
FAC_teleportGui_destinations = [
    ["Base", "BASE_1"],
    ["Medical Area", "MEDICAL_1"],
    ["Pads 3, 4 and 5", "HP_4"],
    ["Firing Range", "firingRangeBoard"],
    ["CQB Killhouse", "cqbBoard"],
    ["Vehicle Pad 2", "VEH_2"],
    ["CTB Locker Room", "LOCKER_1"]
];

FAC_teleportGui_fnc = {
    params ["_action", "_params"];
    private _display = findDisplay 60600;
    if (isNull _display && { _action != "open" }) exitWith {};

    switch _action do {
        case "open": {
            if (!createDialog "RscDisplayTeleport") then {
                systemChat "TELEPORT GUI: RESOURCE NOT FOUND.";
            };
        };
        case "onLoad": {
            private _display = findDisplay 60600;
            if (isNull _display) exitWith {};
            uinamespace setVariable ["FAC_teleportGui_fnc", FAC_teleportGui_fnc];

            private _list = _display displayCtrl 60601;
            lbClear _list;
            {
                _x params ["_name", "_objName"];
                private _idx = _list lbAdd _name;
                _list lbSetData [_idx, _objName];
            } forEach FAC_teleportGui_destinations;
            if (lbSize _list > 0) then { _list lbSetCurSel 0 };
        };
        case "teleport": {
            private _display = findDisplay 60600;
            if (isNull _display) exitWith {};
            private _list = _display displayCtrl 60601;
            private _cur = lbCurSel _list;
            if (_cur < 0) exitWith { systemChat "Select a destination."; };
            private _objName = _list lbData _cur;
            if (_objName == "") exitWith { systemChat "Invalid destination."; };

            private _obj = missionNamespace getVariable [_objName, objNull];
            if (isNull _obj) then {
                systemChat format ["Destination not found: %1", _objName];
            } else {
                private _pos = getPosATL _obj;
                private _dir = getDir _obj;
                // Place player 5 m behind the object (opposite to object's facing), then face the object
                private _dx = sin _dir * 5;
                private _dy = cos _dir * 5;
                private _tpPos = [(_pos select 0) - _dx, (_pos select 1) - _dy, _pos select 2];
                player setPosATL _tpPos;
                player setDir (_tpPos getDir _pos);
                closeDialog 0;
                systemChat "Fast travel complete.";
            };
        };
    };
};
