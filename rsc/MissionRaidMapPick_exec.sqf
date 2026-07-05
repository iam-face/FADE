// Raid multi-zone map pick  -  execVM entry. Do not call compile this file.
if (!hasInterface) exitWith {};
if (isNil "FAC_raidMapPick_fnc_start") then { call FAC_ensureMissionsGui };
[] call FAC_raidMapPick_fnc_start;
