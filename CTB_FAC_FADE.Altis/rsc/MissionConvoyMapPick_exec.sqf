// Convoy route map pick  -  execVM entry (see rsc\MissionMapPick_exec.sqf). Do not compile this file.
if (!hasInterface) exitWith {};

if (isNil "FAC_convoyMapPick_fnc_start") then { call FAC_ensureMissionsGui };
[] call FAC_convoyMapPick_fnc_start;
