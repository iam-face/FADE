// =============================================================================
// initServer.sqf - Face's Dynamic Sandbox server init (thin shell)
// =============================================================================

if (!isServer) exitWith {};

call compile preprocessFileLineNumbers "rsc\Config.sqf";

// Non-Altis: the join countdown is FADE_basePick_deadline (serverTime).
// It stays unset while players are still on the pre-mission map. A client sets
// FAC_basePick_inScenario on their unit once that map closes. The 20 s then starts.
if (worldName != "Altis") then {
    missionNamespace setVariable ["FADE_basePickPhase", "waiting", true];
    missionNamespace setVariable ["FADE_basePick_deadline", -1, true];
    private _joinWait = missionNamespace getVariable ["FADE_basePick_joinWait", 20];
    if (!(_joinWait isEqualType 0) || { _joinWait < 5 }) then { _joinWait = 20 };
    [_joinWait] spawn {
        params ["_joinWait"];
        if (fileExists "headless_test.flg") exitWith {
            missionNamespace setVariable ["FADE_basePick_joinDone", true];
        };
        private _playing = {
            private _found = false;
            {
                if (!isNull _x && { _x getVariable ["FAC_basePick_inScenario", false] }) exitWith { _found = true };
            } forEach allPlayers;
            _found
        };
        waitUntil {
            sleep 0.5;
            if (missionNamespace getVariable ["FADE_baseDefined", false]) exitWith {
                missionNamespace setVariable ["FADE_basePick_joinDone", true];
                true
            };
            missionNamespace getVariable ["FADE_clientInitReady", false]
            && { count allPlayers > 0 }
            && { [] call _playing }
        };
        if (missionNamespace getVariable ["FADE_basePick_joinDone", false]) exitWith {};
        missionNamespace setVariable ["FADE_basePick_deadline", serverTime + _joinWait, true];
        waitUntil {
            sleep 0.5;
            missionNamespace getVariable ["FADE_baseDefined", false]
            || { serverTime >= (missionNamespace getVariable ["FADE_basePick_deadline", 0]) }
        };
        missionNamespace setVariable ["FADE_basePick_joinDone", true];
        diag_log format ["[FADE] Base pick join wait finished at serverTime %1.", serverTime];
    };
};

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
call compile preprocessFileLineNumbers "rsc\server\ServerBootstrapOpforDrones.sqf";
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
