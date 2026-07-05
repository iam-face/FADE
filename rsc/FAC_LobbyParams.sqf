// =============================================================================
// FAC_LobbyParams.sqf  -  lobby parameter indices, access helpers, scenario defaults
// Loaded via FAC_ensureLobbyParams (initServer, initPlayerLocal, client GUI ensure).
// description.ext class Params order must match FAC_LOBBY_IDX_* below.
// =============================================================================

if (missionNamespace getVariable ["FAC_lobbyParams_installed", false]) exitWith {};

// --- Param indices (paramsArray) — order matches description.ext Params (grouped A→Z) ---
// ACCESS
FAC_LOBBY_IDX_ACE_ARSENAL        = 0;
FAC_LOBBY_IDX_FAST_TRAVEL_TP     = 1;
FAC_LOBBY_IDX_JUKEBOX            = 2;
FAC_LOBBY_IDX_LOADOUT_GUI        = 3;
FAC_LOBBY_IDX_MISSIONS_GUI       = 4;
FAC_LOBBY_IDX_RECRUIT_GUI        = 5;
FAC_LOBBY_IDX_SCENARIO_ADMIN     = 6;
FAC_LOBBY_IDX_SCENARIO_GUI       = 7;
FAC_LOBBY_IDX_VEHICLE_GUI        = 8;
// CIVILIANS
FAC_LOBBY_IDX_CIVILIANS          = 9;
FAC_LOBBY_IDX_CIV_TALK           = 10;
FAC_LOBBY_IDX_INTEL_READ         = 11;
// DEBUG
FAC_LOBBY_IDX_DEBUG_PRINT_SPAWNS = 12;
FAC_LOBBY_IDX_DEBUG_TOOLS        = 13;
FAC_LOBBY_IDX_DEBUG_CIV_TOWNS    = 14;
FAC_LOBBY_IDX_DEBUG_VG_MARKERS   = 15;
// GAMEPLAY
FAC_LOBBY_IDX_GEAR_POLICY        = 16;
FAC_LOBBY_IDX_HQ_AUTO_HEAL       = 17;
// MISSIONS
FAC_LOBBY_IDX_AO_STRENGTH        = 18;
// OPFOR
FAC_LOBBY_IDX_OPFOR_PATROLS      = 19;
FAC_LOBBY_IDX_OPFOR_THREAT       = 20;
// WORLD
FAC_LOBBY_IDX_STARTING_TIME      = 21;
FAC_LOBBY_IDX_STARTING_WEATHER   = 22;

FAC_lobbyParams_getArray = {
    if (!isNil "paramsArray" && { paramsArray isEqualType [] }) then { paramsArray } else { [] }
};

FAC_lobbyParams_read = {
    private _p = call FAC_lobbyParams_getArray;
    missionNamespace setVariable ["FAC_param_missionsGuiAccess", _p param [FAC_LOBBY_IDX_MISSIONS_GUI, 0]];
    missionNamespace setVariable ["FAC_param_scenarioGuiAccess", _p param [FAC_LOBBY_IDX_SCENARIO_GUI, 0]];
    missionNamespace setVariable ["FAC_param_enableAceArsenalActions", _p param [FAC_LOBBY_IDX_ACE_ARSENAL, 1]];
    missionNamespace setVariable ["FAC_param_vehicleGuiAccess", _p param [FAC_LOBBY_IDX_VEHICLE_GUI, 0]];
    missionNamespace setVariable ["FAC_param_fastTravelToPlayer", _p param [FAC_LOBBY_IDX_FAST_TRAVEL_TP, 0]];
    missionNamespace setVariable ["FAC_param_scenarioAdminAccess", _p param [FAC_LOBBY_IDX_SCENARIO_ADMIN, 0]];
    missionNamespace setVariable ["FAC_param_loadoutGuiAccess", _p param [FAC_LOBBY_IDX_LOADOUT_GUI, 0]];
    missionNamespace setVariable ["FAC_param_recruitGuiAccess", _p param [FAC_LOBBY_IDX_RECRUIT_GUI, 0]];
    missionNamespace setVariable ["FAC_param_civiliansAtStart", _p param [FAC_LOBBY_IDX_CIVILIANS, 1]];
    missionNamespace setVariable ["FAC_param_opforThreat", _p param [FAC_LOBBY_IDX_OPFOR_THREAT, 1]];
    missionNamespace setVariable ["FAC_param_gearPolicy", _p param [FAC_LOBBY_IDX_GEAR_POLICY, 0]];
    missionNamespace setVariable ["FAC_param_startingTime", _p param [FAC_LOBBY_IDX_STARTING_TIME, 0]];
    missionNamespace setVariable ["FAC_param_startingWeather", _p param [FAC_LOBBY_IDX_STARTING_WEATHER, 0]];
    missionNamespace setVariable ["FAC_param_civTalkPolicy", _p param [FAC_LOBBY_IDX_CIV_TALK, 0]];
    missionNamespace setVariable ["FAC_param_intelReadPolicy", _p param [FAC_LOBBY_IDX_INTEL_READ, 0]];
    missionNamespace setVariable ["FAC_param_aoStrength", _p param [FAC_LOBBY_IDX_AO_STRENGTH, 1]];
    missionNamespace setVariable ["FAC_param_debugTools", _p param [FAC_LOBBY_IDX_DEBUG_TOOLS, 2]];
    missionNamespace setVariable ["FAC_param_jukeboxAccess", _p param [FAC_LOBBY_IDX_JUKEBOX, 0]];
    missionNamespace setVariable ["FAC_param_hqAutoHeal", _p param [FAC_LOBBY_IDX_HQ_AUTO_HEAL, 1]];
    missionNamespace setVariable ["FAC_param_opforPatrols", _p param [FAC_LOBBY_IDX_OPFOR_PATROLS, 1]];
};

// Population labels match Scenario GUI (Very Low … Insane). Other fields scale with threat tier.
FAC_lobbyParams_mapOpforThreat = {
    params ["_level"];
    _level = (round _level) max 0 min 5;
    switch _level do {
        case 0: { ["VeryLow", "Off", "Off", false, 0, "Minimal", 0.0, "Off"] };
        case 1: { ["Low", "Off", "Off", false, 0, "Reduced", 0.0, "Off"] };
        case 3: { ["High", "Off", "Off", true, 0, "Normal", 0.25, "Off"] };
        case 4: { ["VeryHigh", "AAA", "Low", true, 0, "Normal", 0.35, "Low"] };
        case 5: { ["Insane", "AAA+MANPADS", "High", true, 1, "Normal", 0.5, "Normal"] };
        default { ["Normal", "Off", "Off", true, 0, "Normal", 0.0, "Off"] };
    };
};

// mission.sqm sets a fixed randomSeed; use seed random (not selectRandom) for lobby rolls.
FAC_lobbyParams_entropySeed = {
    private _t = systemTime;
    (_t select 0)
        + (_t select 1) * 32
        + (_t select 2) * 1024
        + (_t select 3) * 32768
        + (_t select 4) * 1048576
        + (_t select 5) * 33554432
        + round (diag_tickTime * 1000)
};

FAC_lobbyParams_randomStartingHour = {
    private _hours = [0, 4, 6, 12, 15, 19];
    private _seed = call FAC_lobbyParams_entropySeed;
    _hours select (floor (_seed random (count _hours)));
};

FAC_lobbyParams_randomStartingWeatherName = {
    private _options = ["Clear", "Overcast", "Foggy", "Rain", "Storm", "FaceMission"];
    private _seed = (call FAC_lobbyParams_entropySeed) + 7919;
    _options select (floor (_seed random (count _options)));
};

FAC_lobbyParams_mapStartingHour = {
    params ["_choice"];
    switch (round _choice) do {
        case 1: { 0 };
        case 2: { 4 };
        case 3: { 6 };
        case 4: { 12 };
        case 5: { 15 };
        case 6: { 19 };
        default { [] call FAC_lobbyParams_randomStartingHour };
    };
};

FAC_lobbyParams_mapStartingWeatherName = {
    params ["_choice"];
    switch (round _choice) do {
        case 1: { "Clear" };
        case 2: { "Overcast" };
        case 3: { "Foggy" };
        case 4: { "Rain" };
        case 5: { "Storm" };
        case 6: { "FaceMission" };
        default { [] call FAC_lobbyParams_randomStartingWeatherName };
    };
};

FAC_lobbyParams_mapAoStrength = {
    params ["_choice"];
    switch ((round _choice) max 0 min 2) do {
        case 0: { "Low" };
        case 2: { "High" };
        default { "Mid" };
    };
};

FAC_lobbyParams_applyScenarioDefaults = {
    if (!isServer) exitWith {};
    call FAC_lobbyParams_read;

    private _civOn = (missionNamespace getVariable ["FAC_param_civiliansAtStart", 1]) > 0;
    missionNamespace setVariable ["FADE_civiliansEnabled", _civOn, true];

    private _threat = missionNamespace getVariable ["FAC_param_opforThreat", 1];
    private _threatMap = [_threat] call FAC_lobbyParams_mapOpforThreat;
    _threatMap params ["_pop", "_aaa", "_air", "_patrolsUnused", "_routing", "_launcher", "_skill", "_drone"];
    missionNamespace setVariable ["FADE_opforPopulationSetting", _pop, true];
    missionNamespace setVariable ["FADE_enemyAAALevel", _aaa, true];
    missionNamespace setVariable ["FADE_opforAirSetting", [_air] call FADE_normalizeOpforThreatSetting, true];
    missionNamespace setVariable ["FADE_opforDroneSetting", [_drone] call FADE_normalizeOpforThreatSetting, true];
    missionNamespace setVariable ["FADE_scenarioPatrols", (missionNamespace getVariable ["FAC_param_opforPatrols", 1]) > 0, true];
    missionNamespace setVariable ["FADE_enemyRouting", _routing, true];
    missionNamespace setVariable ["FADE_opforLauncherSetting", _launcher, true];
    missionNamespace setVariable ["FADE_enemySkill", (_skill max 0) min 1, true];

    private _gearPol = missionNamespace getVariable ["FAC_param_gearPolicy", 0];
    missionNamespace setVariable ["FADE_limitGearToFriendlyFaction", _gearPol >= 1, true];
    missionNamespace setVariable ["FADE_limitToPresetLoadouts", _gearPol >= 2, true];

    private _hour = [missionNamespace getVariable ["FAC_param_startingTime", 0]] call FAC_lobbyParams_mapStartingHour;
    missionNamespace setVariable ["FADE_scenarioTime", (_hour max 0) min 23, true];
    private _weather = [missionNamespace getVariable ["FAC_param_startingWeather", 0]] call FAC_lobbyParams_mapStartingWeatherName;
    missionNamespace setVariable ["FADE_scenarioWeather", _weather, true];
    missionNamespace setVariable ["FADE_scenarioWeatherParams", [], true];

    missionNamespace setVariable ["FADE_civTalkInterpretersOnly", (missionNamespace getVariable ["FAC_param_civTalkPolicy", 0]) > 0, true];
    missionNamespace setVariable ["FADE_intelSpecialistsOnly", (missionNamespace getVariable ["FAC_param_intelReadPolicy", 0]) > 0, true];

    private _ao = [missionNamespace getVariable ["FAC_param_aoStrength", 1]] call FAC_lobbyParams_mapAoStrength;
    missionNamespace setVariable ["FADE_aoStrength", _ao, true];

    private _tpMode = (missionNamespace getVariable ["FAC_param_fastTravelToPlayer", 0]) max 0 min 1;
    missionNamespace setVariable ["FADE_teleportToPlayerMode", _tpMode, true];

    if ((missionNamespace getVariable ["FAC_param_hqAutoHeal", 1]) <= 0) then {
        missionNamespace setVariable ["FADE_hqHealIntervalSec", 0, true];
    };
};

FAC_lobbyParams_publishAccessVars = {
    if (!isServer) exitWith {};
    {
        publicVariable _x;
    } forEach [
        "FAC_param_missionsGuiAccess",
        "FAC_param_scenarioGuiAccess",
        "FAC_param_enableAceArsenalActions",
        "FAC_param_vehicleGuiAccess",
        "FAC_param_fastTravelToPlayer",
        "FAC_param_scenarioAdminAccess",
        "FAC_param_loadoutGuiAccess",
        "FAC_param_recruitGuiAccess",
        "FAC_param_debugTools",
        "FAC_param_jukeboxAccess",
        "FAC_param_hqAutoHeal",
        "FADE_teleportToPlayerMode",
        "FADE_civiliansEnabled",
        "FADE_limitGearToFriendlyFaction",
        "FADE_limitToPresetLoadouts",
        "FADE_civTalkInterpretersOnly",
        "FADE_intelSpecialistsOnly",
        "FADE_aoStrength",
        "FADE_hqHealIntervalSec",
        "FADE_scenarioPatrols",
        "FADE_enemyAAALevel",
        "FADE_opforAirSetting",
        "FADE_opforDroneSetting",
        "FADE_opforLauncherSetting",
        "FADE_opforPopulationSetting",
        "FADE_enemySkill",
        "FADE_enemyRouting",
        "FADE_scenarioTime",
        "FADE_scenarioWeather"
    ];
};

// --- Access helpers (server + client) -------------------------------------------
FAC_playerHasLeaderOverrideAccess = {
    params [["_player", objNull]];
    if !(_player isEqualType objNull) then { _player = player };
    if (isNull _player) then { _player = player };
    if (isNull _player) exitWith { false };
    if (isServer) then {
        ((admin (owner _player)) > 0) || { !isNull (getAssignedCuratorLogic _player) }
    } else {
        (serverCommandAvailable "#kick") || { !isNull (getAssignedCuratorLogic _player) }
    };
};

FAC_playerCanUseLeaderGatedGui = {
    params ["_modeVar", ["_player", objNull]];
    if !(_player isEqualType objNull) then { _player = player };
    if (isNull _player) then { _player = player };
    if (isNull _player) exitWith { false };
    private _mode = missionNamespace getVariable [_modeVar, 0];
    if (_mode <= 0) exitWith { true };
    (leader group _player == _player) || { [_player] call FAC_playerHasLeaderOverrideAccess }
};

FAC_playerCanUseMissionsGui = {
    params [["_player", objNull]];
    if !(_player isEqualType objNull) then { _player = player };
    ["FAC_param_missionsGuiAccess", _player] call FAC_playerCanUseLeaderGatedGui
};

FAC_playerCanUseScenarioGui = {
    params [["_player", objNull]];
    if !(_player isEqualType objNull) then { _player = player };
    ["FAC_param_scenarioGuiAccess", _player] call FAC_playerCanUseLeaderGatedGui
};

FAC_playerCanUseVehicleGui = {
    params [["_player", objNull]];
    if !(_player isEqualType objNull) then { _player = player };
    ["FAC_param_vehicleGuiAccess", _player] call FAC_playerCanUseLeaderGatedGui
};

FAC_playerCanUseLoadoutGui = {
    params [["_player", objNull]];
    if !(_player isEqualType objNull) then { _player = player };
    ["FAC_param_loadoutGuiAccess", _player] call FAC_playerCanUseLeaderGatedGui
};

FAC_playerCanUseRecruitGui = {
    params [["_player", objNull]];
    if !(_player isEqualType objNull) then { _player = player };
    if (isNull _player) then { _player = player };
    if (isNull _player) exitWith { false };
    private _mode = missionNamespace getVariable ["FAC_param_recruitGuiAccess", 0];
    switch (_mode max 0 min 2) do {
        case 0: { true };
        case 1: {
            (leader group _player == _player) || { [_player] call FAC_playerHasLeaderOverrideAccess }
        };
        default { [_player] call FAC_playerHasLeaderOverrideAccess };
    };
};

FAC_playerCanTeleportToPlayers = {
    params [["_player", objNull]];
    if !(_player isEqualType objNull) then { _player = player };
    if (isNull _player) then { _player = player };
    if (isNull _player) exitWith { false };
    private _mode = missionNamespace getVariable ["FADE_teleportToPlayerMode", 0];
    if (_mode <= 0) exitWith { true };
    (leader group _player == _player) || { [_player] call FAC_playerHasLeaderOverrideAccess }
};

FAC_playerCanUseScenarioAdmin = {
    params [["_player", objNull]];
    if !(_player isEqualType objNull) then { _player = player };
    if (isNull _player) then { _player = player };
    if (isNull _player) exitWith { false };
    private _mode = missionNamespace getVariable ["FAC_param_scenarioAdminAccess", 0];
    if (_mode >= 2) exitWith { [_player] call FAC_playerHasLeaderOverrideAccess };
    if (_mode <= 0) exitWith { [_player] call FAC_playerCanUseScenarioGui };
    (leader group _player == _player) || { [_player] call FAC_playerHasLeaderOverrideAccess }
};

FAC_playerCanUseJukebox = {
    params [["_player", objNull]];
    if !(_player isEqualType objNull) then { _player = player };
    ["FAC_param_jukeboxAccess", _player] call FAC_playerCanUseLeaderGatedGui
};

FAC_playerCanUseDebugTools = {
    params [["_player", objNull]];
    if !(_player isEqualType objNull) then { _player = player };
    if (isNull _player) then { _player = player };
    if (isNull _player) exitWith { false };
    private _mode = missionNamespace getVariable ["FAC_param_debugTools", 2];
    switch (_mode max 0 min 2) do {
        case 0: { false };
        case 1: {
            if (isServer) then {
                (admin (owner _player)) == 2
            } else {
                serverCommandAvailable "#kick"
            };
        };
        default {
            if (isServer) then {
                (admin (owner _player)) > 0
            } else {
                serverCommandAvailable "#kick" || { !isNull (getAssignedCuratorLogic _player) }
            };
        };
    };
};

// Resolve access fn from missionNamespace (safe for lazy-loaded GUIs / description.ext callbacks).
FAC_lobbyParams_callAccess = {
    params ["_fnName", ["_player", objNull]];
    private _fn = missionNamespace getVariable [_fnName, {}];
    if !(_fn isEqualType {}) exitWith {
        diag_log format ["[FAC LobbyParams] Missing access function %1  -  denying.", _fnName];
        false
    };
    // [] call  -  bare `call _fn` inherits caller _this (e.g. fn name string from callAccess args).
    if (isNull _player) then { [] call _fn } else { [_player] call _fn }
};

// Server: true when access denied (caller should exitWith).
FAC_lobbyParams_serverDenyUnless = {
    params ["_player", "_fnName", ["_msg", "Access denied by lobby settings."]];
    if ([_fnName, _player] call FAC_lobbyParams_callAccess) exitWith { false };
    if (!isNull _player) then { [_msg] remoteExec ["systemChat", _player] };
    true
};

FAC_lobbyParams_install = {
    private _names = [
        "FAC_lobbyParams_getArray",
        "FAC_lobbyParams_read",
        "FAC_lobbyParams_mapOpforThreat",
        "FAC_lobbyParams_entropySeed",
        "FAC_lobbyParams_randomStartingHour",
        "FAC_lobbyParams_randomStartingWeatherName",
        "FAC_lobbyParams_mapStartingHour",
        "FAC_lobbyParams_mapStartingWeatherName",
        "FAC_lobbyParams_mapAoStrength",
        "FAC_lobbyParams_applyScenarioDefaults",
        "FAC_lobbyParams_publishAccessVars",
        "FAC_playerHasLeaderOverrideAccess",
        "FAC_playerCanUseLeaderGatedGui",
        "FAC_playerCanUseMissionsGui",
        "FAC_playerCanUseScenarioGui",
        "FAC_playerCanUseVehicleGui",
        "FAC_playerCanUseLoadoutGui",
        "FAC_playerCanUseRecruitGui",
        "FAC_playerCanTeleportToPlayers",
        "FAC_playerCanUseScenarioAdmin",
        "FAC_playerCanUseJukebox",
        "FAC_playerCanUseDebugTools",
        "FAC_lobbyParams_callAccess",
        "FAC_lobbyParams_serverDenyUnless"
    ];
    {
        private _val = missionNamespace getVariable [_x, {}];
        if (_val isEqualType {}) then {
            missionNamespace setVariable [_x, _val];
        };
    } forEach _names;
    missionNamespace setVariable ["FAC_lobbyParams_installed", true];
};

FAC_ensureLobbyParams = {
    if !(missionNamespace getVariable ["FAC_lobbyParams_installed", false]) then {
        call compile preprocessFileLineNumbers "rsc\FAC_LobbyParams.sqf";
    } else {
        call FAC_lobbyParams_read;
    };
};

call FAC_lobbyParams_install;
if (!isServer) then { call FAC_lobbyParams_read; };
