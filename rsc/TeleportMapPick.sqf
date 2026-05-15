// Map-click teleport (10 s window). Same pattern as PMC Editing Wiki "ArmA 3 Debug Teleport":
// https://pmc.editing.wiki/doku.php?id=arma3:scripting:debug-teleport
//   onMapSingleClick "player setPos _pos; onMapSingleClick ''; true;";
// Run from execVM - not from call compile preprocessFile TeleportGui.sqf - so _pos is not rejected.

if (missionNamespace getVariable ["FAC_teleport_mapPickActive", false]) exitWith {
    systemChat "Map teleport already active.";
};

missionNamespace setVariable ["FAC_teleport_mapPickActive", true];

private _mapClick = "missionNamespace setVariable [""FAC_teleport_mapPickActive"", false]; player setPos _pos; [format [""%1 teleported to map grid %2"", name player, mapGridPosition player]] remoteExec [""systemChat"", 0]; onMapSingleClick ''; openMap false; [] spawn { sleep 0.55; [] call FAC_teleport_fnc_addReturnToBase }; hint 'Teleported successfully.'; true;";
onMapSingleClick _mapClick;

openMap true;

[] spawn {
    private _deadline = time + 10;
    while {
        missionNamespace getVariable ["FAC_teleport_mapPickActive", false]
        && { time < _deadline }
    } do {
        private _rem = (ceil (_deadline - time)) max 1;
        hint format [
            "Click the map to choose where to teleport.\n%1 s remaining - map closes if you don't click.",
            _rem
        ];
        sleep 1;
    };
    if (missionNamespace getVariable ["FAC_teleport_mapPickActive", false]) then {
        missionNamespace setVariable ["FAC_teleport_mapPickActive", false];
        // Any literal assigned to onMapSingleClick is compile-checked; "" / "false" / hint "" can RPT "Reserved variable".
        // Build handler text without map-click string literals: str false -> "false" (valid no-op for the engine).
        private _noMapEh = str false;
        onMapSingleClick _noMapEh;
        if (visibleMap) then { openMap false };
        hint "Teleport timed out, aborted.";
    };
};
