// Map-click mission start  -  execVM entry (see rsc\TeleportMapPick.sqf). Do not call compile this file.
if (!hasInterface) exitWith {};

private _mt = missionNamespace getVariable ["FAC_missionMapPick_execType", ""];
if (_mt == "") exitWith {
    systemChat "MISSION: map pick aborted (no mission type).";
};
missionNamespace setVariable ["FAC_missionMapPick_execType", nil];

if (isNil "FAC_missionMapPick_fnc_start") then { call FAC_ensureMissionsGui };
[_mt] call FAC_missionMapPick_fnc_start;
