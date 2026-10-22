// =============================================================================
// initServer.sqf - Face's Dynamic Sandbox server init (thin shell)
// =============================================================================

if (!isServer) exitWith {};

call compile preprocessFileLineNumbers "rsc\Config.sqf";

// Non-Altis: publish the join countdown before the rest of server init.
// Clients read FADE_basePick_deadline (serverTime). The map stays closed until this ends.
if (worldName != "Altis") then {
    missionNamespace setVariable ["FADE_basePickPhase", "waiting", true];
    private _joinWait = missionNamespace getVariable ["FADE_basePick_joinWait", 20];
    if (!(_joinWait isEqualType 0) || { _joinWait < 5 }) then { _joinWait = 20 };
    missionNamespace setVariable ["FADE_basePick_deadline", serverTime + _joinWait, true];
    [_joinWait] spawn {
        params ["_joinWait"];
        private _arm = {
            params ["_joinWait"];
            missionNamespace setVariable ["FADE_basePick_deadline", serverTime + _joinWait, true];
        };
        if (fileExists "headless_test.flg") exitWith {
            missionNamespace setVariable ["FADE_basePick_joinDone", true];
        };
        waitUntil {
            sleep 0.5;
            if (missionNamespace getVariable ["FADE_baseDefined", false]) exitWith {
                missionNamespace setVariable ["FADE_basePick_joinDone", true];
                true
            };
            private _ready = missionNamespace getVariable ["FADE_clientInitReady", false] && { count allPlayers > 0 };
            private _deadline = missionNamespace getVariable ["FADE_basePick_deadline", 0];
            if (!_ready && { (serverTime + 1) >= _deadline }) then { [_joinWait] call _arm };
            _ready && { serverTime >= (missionNamespace getVariable ["FADE_basePick_deadline", 0]) }
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
