// Earliest mission entry without editing description.ext: runs before initServer / initPlayerLocal.
// Installs bis_fnc_cp_* stubs so modules / CPE do not error before Config.sqf (see rsc\fn_bisCpPreInit.sqf).
call compile preprocessFileLineNumbers "rsc\fn_bisCpPreInit.sqf";
