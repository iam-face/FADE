// =============================================================================
// ServerGameplay.sqf  -  thin compile shell (CQB, vehicles, missions, med, admin)
// =============================================================================

call compile preprocessFileLineNumbers "rsc\server\ServerGameplayCqb.sqf";
call compile preprocessFileLineNumbers "rsc\server\ServerGameplayCore.sqf";
call compile preprocessFileLineNumbers "rsc\server\ServerGameplayVehicles.sqf";
call compile preprocessFileLineNumbers "rsc\server\ServerGameplayMissions.sqf";
call compile preprocessFileLineNumbers "rsc\server\ServerGameplayMedTrain.sqf";
call compile preprocessFileLineNumbers "rsc\server\ServerGameplayMissionAdmin.sqf";
call compile preprocessFileLineNumbers "rsc\server\ServerGameplayRecruit.sqf";
