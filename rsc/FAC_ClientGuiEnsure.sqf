// =============================================================================
// FAC_ClientGuiEnsure.sqf  -  lazy compile for client GUIs (initPlayerLocal)
// =============================================================================
// Call FAC_ensure* before using missionNamespace FAC_*Gui_fnc / jukebox helpers.
// Idempotent: safe to call multiple times.
// =============================================================================

FAC_ensureLobbyParams = {
    if !(missionNamespace getVariable ["FAC_lobbyParams_installed", false]) then {
        call compile preprocessFileLineNumbers "rsc\FAC_LobbyParams.sqf";
    } else {
        call FAC_lobbyParams_read;
    };
};

FAC_guiOpenDeferred = {
    params ["_ensureFn", "_guiFnName", ["_openParams", []]];
    private _ensure = missionNamespace getVariable [_ensureFn, {}];
    private _gui = missionNamespace getVariable [_guiFnName, {}];
    if (!(_ensure isEqualType {}) || { !(_gui isEqualType {}) }) exitWith {};
    [] spawn {
        params ["_ensure", "_gui", "_openParams"];
        call _ensure;
        sleep 0.2;
        if (_openParams isEqualTo []) then {
            ["open", []] call _gui;
        } else {
            ["open", _openParams] call _gui;
        };
    };
};

FAC_ensureLoadoutGui = {
    call FAC_ensureLobbyParams;
    if (missionNamespace getVariable ["FAC_clientGui_loadout", false]) exitWith {};
    if (isNil "FAC_loadoutGui_buildPresetEntries") then {
        call compile preprocessFileLineNumbers "rsc\LoadoutPresetCommon.sqf";
    };
    call compile preprocessFileLineNumbers "rsc\LoadoutGui.sqf";
    missionNamespace setVariable ["FAC_clientGui_loadout", true];
};

FAC_ensureVehicleGui = {
    call FAC_ensureLobbyParams;
    if (missionNamespace getVariable ["FAC_clientGui_vehicle", false]) exitWith {};
    call compile preprocessFileLineNumbers "rsc\VehicleGui.sqf";
    missionNamespace setVariable ["FAC_vehicleGui_fnc", FAC_vehicleGui_fnc];
    missionNamespace setVariable ["FAC_clientGui_vehicle", true];
};

FAC_ensureFiresGui = {
    // Always run first: if fires was already compiled this session, early-exit below must not skip VehicleGui (piece tooltips call into VehicleGui).
    call FAC_ensureVehicleGui;
    if (missionNamespace getVariable ["FAC_clientGui_fires", false]) exitWith {};
    call compile preprocessFileLineNumbers "rsc\FiresArtilleryList.sqf";
    call compile preprocessFileLineNumbers "rsc\FiresFallOfShot.sqf";
    call compile preprocessFileLineNumbers "rsc\FiresGui.sqf";
    missionNamespace setVariable ["FAC_firesGui_fnc", FAC_firesGui_fnc];
    missionNamespace setVariable ["FAC_clientGui_fires", true];
};

FAC_ensureMedicalTrainingGui = {
    if (missionNamespace getVariable ["FAC_clientGui_medical", false]) exitWith {};
    call compile preprocessFileLineNumbers "rsc\MedicalTrainingKAT_fractureLocal.sqf";
    call compile preprocessFileLineNumbers "rsc\MedicalTrainingGui.sqf";
    missionNamespace setVariable ["FAC_medicalTrainingGui_fnc", FAC_medicalTrainingGui_fnc];
    missionNamespace setVariable ["FAC_clientGui_medical", true];
};

FAC_ensureMissionsGui = {
    call FAC_ensureLobbyParams;
    if (missionNamespace getVariable ["FAC_clientGui_missions", false]) exitWith {};
    call compile preprocessFileLineNumbers "rsc\MissionPickOverlay.sqf";
    call compile preprocessFileLineNumbers "rsc\MissionsGui.sqf";
    call compile preprocessFileLineNumbers "rsc\EscapeEvasionPickGui.sqf";
    call compile preprocessFileLineNumbers "rsc\TroopInsertPickGui.sqf";
    call compile preprocessFileLineNumbers "rsc\MissionLocationPickGui.sqf";
    call compile preprocessFileLineNumbers "rsc\FADE_MapClickPick.sqf";
    call compile preprocessFileLineNumbers "rsc\MissionMapPick.sqf";
    missionNamespace setVariable ["FAC_missionsGui_fnc", FAC_missionsGui_fnc];
    missionNamespace setVariable ["FAC_clientGui_missions", true];
};

FAC_ensureScenarioGui = {
    call FAC_ensureLobbyParams;
    if (missionNamespace getVariable ["FAC_clientGui_scenario", false]) exitWith {};
    call compile preprocessFileLineNumbers "rsc\ScenarioGui.sqf";
    missionNamespace setVariable ["FAC_scenarioGui_fnc", FAC_scenarioGui_fnc];
    missionNamespace setVariable ["FAC_clientGui_scenario", true];
};

FAC_ensureCivTalkGui = {
    if (missionNamespace getVariable ["FAC_clientGui_civtalk", false]) exitWith {};
    if (isNil "FADE_client_escapeForDiary") then {
        call compile preprocessFileLineNumbers "rsc\FADE_ClientCommon.sqf";
    };
    call compile preprocessFileLineNumbers "rsc\CivTalkGui.sqf";
    missionNamespace setVariable ["FAC_clientGui_civtalk", true];
    private _refresh = missionNamespace getVariable ["FADE_civTalk_refreshBaseNpcAction", {}];
    if (_refresh isEqualType {}) then { [] call _refresh };
};

FAC_ensureJukeboxGui = {
    call FAC_ensureLobbyParams;
    if (missionNamespace getVariable ["FAC_clientGui_jukebox", false]) exitWith {};
    call compile preprocessFileLineNumbers "rsc\JukeboxGui.sqf";
    missionNamespace setVariable ["FAC_jukeboxGui_fnc", FAC_jukeboxGui_fnc];
    missionNamespace setVariable ["FAC_jukebox_clientPlay", FAC_jukebox_clientPlay];
    missionNamespace setVariable ["FAC_jukebox_clientStopAll", FAC_jukebox_clientStopAll];
    missionNamespace setVariable ["FAC_jukebox_serverDbgChat", FAC_jukebox_serverDbgChat];
    missionNamespace setVariable ["FAC_jukebox_fnc_addVehicleLoudspeakerAction", FAC_jukebox_fnc_addVehicleLoudspeakerAction];
    missionNamespace setVariable ["FAC_jukebox_fnc_installVehicleLoudspeakerHandlers", FAC_jukebox_fnc_installVehicleLoudspeakerHandlers];
    missionNamespace setVariable ["FAC_clientGui_jukebox", true];
};

FAC_ensureCQBGui = {
    if (missionNamespace getVariable ["FAC_clientGui_cqb", false]) exitWith {};
    call compile preprocessFileLineNumbers "rsc\CQBGui.sqf";
    missionNamespace setVariable ["FAC_cqbGui_fnc", FAC_cqbGui_fnc];
    missionNamespace setVariable ["FAC_clientGui_cqb", true];
};

FAC_ensureSniperGui = {
    // Re-run SniperGui if helpers are missing (e.g. prior compile failed mid-mission) even when FAC_clientGui_sniper is true.
    if (
        isNil "FADE_sniperClient_clearRangeFx" ||
        { !(missionNamespace getVariable ["FAC_clientGui_sniper", false]) }
    ) then {
        call compile preprocessFileLineNumbers "rsc\SniperGui.sqf";
    };
    if (isNil "FADE_sniperClient_clearRangeFx") exitWith {
        diag_log "[FAC] SniperGui.sqf did not define FADE_sniperClient_clearRangeFx (syntax/compile error). Sniper/range ballistics UI helpers unavailable.";
    };
    missionNamespace setVariable ["FAC_sniperGui_fnc", FAC_sniperGui_fnc];
    missionNamespace setVariable ["FAC_clientGui_sniper", true];
};

FAC_ensureRangeGui = {
    if (missionNamespace getVariable ["FAC_clientGui_range", false]) exitWith {};
    call compile preprocessFileLineNumbers "rsc\RangeGui.sqf";
    missionNamespace setVariable ["FAC_rangeGui_fnc", FAC_rangeGui_fnc];
    missionNamespace setVariable ["FAC_clientGui_range", true];
    // FAC_ensureSniperGui is CODE (lazy compile); isNull does not apply  -  call it so range FX helpers exist.
    call FAC_ensureSniperGui;
};

// Client: trace + impact markers reuse SniperGui.sqf (compile before remoteExec from server).
FADE_rangeClient_enableSniperFxForRange = {
    params [["_trace", false], ["_termPos", []]];
    if (!hasInterface) exitWith {};
    call FAC_ensureSniperGui;
    if (_trace) then {
        [true, player] remoteExec ["FADE_sniperClient_setProjectileTrace", 0, player];
        if (_termPos isEqualType [] && { count _termPos >= 2 }) then {
            [_termPos, player] call FADE_sniperClient_startTraceProximityMonitor;
        };
    };
    [true] call FADE_sniperClient_setProjectileImpactMarkers;
};

FADE_rangeClient_disableSniperFxForRange = {
    if (!hasInterface) exitWith {};
    call FAC_ensureSniperGui;
    [] call FADE_sniperClient_clearRangeFx;
};

// Server: [] remoteExec ["FADE_rangeClient_onSessionStarted", _player]; (code-block remoteExec is invalid in A3)
FADE_rangeClient_onSessionStarted = {
    if (!hasInterface) exitWith {};
    call FAC_ensureSniperGui;
    if !(missionNamespace getVariable ["FAC_clientGui_range", false]) then {
        private _eg = missionNamespace getVariable ["FAC_ensureRangeGui", {}];
        if (_eg isEqualType {}) then { [] call _eg };
    };
    if (!isNull (findDisplay 60920)) then {
        private _gf = missionNamespace getVariable ["FAC_rangeGui_fnc", {}];
        if (_gf isEqualType {}) then { ["headerRefresh", []] call _gf };
    };
};

FAC_ensureTeleportGui = {
    call FAC_ensureLobbyParams;
    if (missionNamespace getVariable ["FAC_clientGui_teleport", false]) exitWith {};
    call compile preprocessFileLineNumbers "rsc\TeleportGui.sqf";
    missionNamespace setVariable ["FAC_clientGui_teleport", true];
};

missionNamespace setVariable ["FAC_ensureLoadoutGui", FAC_ensureLoadoutGui];
missionNamespace setVariable ["FAC_ensureVehicleGui", FAC_ensureVehicleGui];
missionNamespace setVariable ["FAC_ensureFiresGui", FAC_ensureFiresGui];
missionNamespace setVariable ["FAC_ensureMedicalTrainingGui", FAC_ensureMedicalTrainingGui];
missionNamespace setVariable ["FAC_ensureMissionsGui", FAC_ensureMissionsGui];
missionNamespace setVariable ["FAC_ensureScenarioGui", FAC_ensureScenarioGui];
missionNamespace setVariable ["FAC_ensureCivTalkGui", FAC_ensureCivTalkGui];
missionNamespace setVariable ["FAC_ensureJukeboxGui", FAC_ensureJukeboxGui];
missionNamespace setVariable ["FAC_ensureCQBGui", FAC_ensureCQBGui];
missionNamespace setVariable ["FAC_ensureSniperGui", FAC_ensureSniperGui];
missionNamespace setVariable ["FAC_ensureRangeGui", FAC_ensureRangeGui];
missionNamespace setVariable ["FAC_ensureTeleportGui", FAC_ensureTeleportGui];
