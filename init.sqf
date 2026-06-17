// Earliest mission entry without editing description.ext: runs before initServer / initPlayerLocal.
// Installs bis_fnc_cp_* stubs so modules / CPE do not error before Config.sqf (see rsc\fn_bisCpPreInit.sqf).
call compile preprocessFileLineNumbers "rsc\fn_bisCpPreInit.sqf";
// Base NPC (S Wordsman): compile here so postInit + initServer retries can call FADE_baseNpc_spawnAndRegister.
call compile preprocessFileLineNumbers "rsc\BaseNpcTalk.sqf";
