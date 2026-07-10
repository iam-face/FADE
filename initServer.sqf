// =============================================================================
// initServer.sqf - Face's Dynamic Sandbox server init (thin shell)
// =============================================================================

if (!isServer) exitWith {};

call compile preprocessFileLineNumbers "rsc\Config.sqf";
call compile preprocessFileLineNumbers "rsc\FADE_Profile.sqf";
call compile preprocessFileLineNumbers "rsc\FADE_Common.sqf";
call compile preprocessFileLineNumbers "rsc\FADE_MissionSlots.sqf";
call compile preprocessFileLineNumbers "rsc\FAC_MissionTypeLabels.sqf";
call compile preprocessFileLineNumbers "rsc\ServerEntityRegistry.sqf";
call compile preprocessFileLineNumbers "rsc\BaseNpcTalk.sqf";

private _facProf0 = if (missionNamespace getVariable ["FADE_profileMissionLoad", false]) then { diag_tickTime } else { -1 };

call compile preprocessFileLineNumbers "rsc\server\ServerBootstrap.sqf";
call compile preprocessFileLineNumbers "rsc\FAC_DebugLobbyServerApply.sqf";
call compile preprocessFileLineNumbers "rsc\server\ServerWorld.sqf";
call compile preprocessFileLineNumbers "rsc\FADE_OpforDrones.sqf";
call compile preprocessFileLineNumbers "rsc\FADE_MOTDBoard.sqf";
[] call FADE_motdBoard_start;
call compile preprocessFileLineNumbers "rsc\FAC_DebugCivTownMarkers.sqf";
call compile preprocessFileLineNumbers "rsc\server\ServerGameplay.sqf";

if (isNil "FADE_missions_installed") then {
    call compile preprocessFileLineNumbers "rsc\FADE_MissionCompile.sqf";
    [] call FADE_installMissionModules;
};

call compile preprocessFileLineNumbers "rsc\server\ServerServices.sqf";

missionNamespace setVariable ["FADE_clientInitReady", true, true];
publicVariable "FADE_clientInitReady";
diag_log "[FAC profile] FADE_serverInitReady";

if (_facProf0 >= 0) then {
    diag_log format ["[FAC profile] initServer total (thin shell + modules): %1 s", diag_tickTime - _facProf0];
};

// Headless dedicated-server auto-test (tools/headless — headless_test.flg in mission root).
if (fileExists "headless_test.flg") then {
    [] spawn {
        call compile preprocessFile "rsc\FADE_HeadlessTest.sqf";
        [] call FADE_headlessTest_boot;
    };
};
