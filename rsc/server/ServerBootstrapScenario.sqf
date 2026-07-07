// ServerBootstrapScenario.sqf - FADE_applyScenarioSettings and client sync
// Apply scenario settings from GUI - SERVER-SIDE GLOBAL: all mission spawns use these unit/vehicle lists.
// When a player clicks Apply, this runs on the server and overwrites missionNamespace; Missions.sqf (and other scripts) read from missionNamespace.
FADE_applyScenarioSettings = {
    // Scenario GUI sends one wrapped array so remoteExec always delivers a single _this (reliable with many args on dedicated servers).
    params ["_args"];
    if !(_args isEqualType []) exitWith {};
    _args params ["_hour", "_weather", "_enemyFaction", "_friendlyFaction", "_civFaction", ["_limitGear", false], ["_presetOnly", false], ["_player", objNull], ["_patrolsEnabled", true], ["_enemySkill", 0.0], ["_enemyRouting", 0], ["_enemyAAA", "Off"], ["_civiliansEnabled", true], ["_aoStrength", "Medium"], ["_timeCompressionScale", 1], ["_opforPopulationSetting", "Low"], ["_teleportToPlayerMode", 0], ["_opforLauncherSetting", "Normal"], ["_opforAirSetting", "Off"], ["_operationZoneCount", 6], ["_weatherParams", []], ["_civGlobalMaxAlive", 55], ["_civDensityScale", 1], ["_civTalkInterpretersOnly", false], ["_intelSpecialistsOnly", false], ["_opforDroneSetting", "Off"]];
    FADE_getUnitsForFaction_cache = createHashMap;
    FADE_getCivVehiclesForFaction_cache = createHashMap;
    missionNamespace setVariable ["FADE_enemyAirVehicleClasses_cache", []];
    missionNamespace setVariable ["FADE_enemyDroneVehicleClasses_cache", []];
    if (!([_player] call FADE_playerCanUseScenarioGui)) exitWith {
        if (!isNull _player) then {
            ["Scenario access denied by lobby settings."] remoteExec ["systemChat", _player];
        };
    };
    _hour = (_hour max 0) min 23;
    missionNamespace setVariable ["FADE_scenarioTime", _hour];
    missionNamespace setVariable ["FADE_scenarioWeather", _weather];
    missionNamespace setVariable ["FADE_scenarioEnemyFaction", _enemyFaction, true];
    missionNamespace setVariable ["FADE_scenarioFriendlyFaction", _friendlyFaction, true];
    missionNamespace setVariable ["FADE_scenarioCivFaction", _civFaction, true];
    missionNamespace setVariable ["FADE_limitGearToFriendlyFaction", _limitGear];
    missionNamespace setVariable ["FADE_scenarioPatrols", _patrolsEnabled];
    missionNamespace setVariable ["FADE_enemySkill", (_enemySkill max 0) min 1];
    missionNamespace setVariable ["FADE_enemyRouting", (_enemyRouting max 0) min 1];
    _enemyAAA = switch (toUpper _enemyAAA) do {
        case "NONE": { "Off" };
        case "LIGHT";
        case "MEDIUM";
        case "HEAVY": { "AAA" };
        case "MANPADS";
        case "AAA+MANPADS": { "AAA+MANPADS" };
        case "AAA": { "AAA" };
        default { "Off" };
    };
    missionNamespace setVariable ["FADE_enemyAAALevel", _enemyAAA];
    missionNamespace setVariable ["FADE_civiliansEnabled", _civiliansEnabled];
    _civGlobalMaxAlive = (round _civGlobalMaxAlive) max 0 min 300;
    _civDensityScale = (_civDensityScale max 0.25) min 2.5;
    missionNamespace setVariable ["FADE_civGlobalMaxAlive", _civGlobalMaxAlive];
    missionNamespace setVariable ["FADE_civDensityScale", _civDensityScale];
    missionNamespace setVariable ["FADE_aoStrength", _aoStrength];
    missionNamespace setVariable ["FADE_timeCompressionScale", (_timeCompressionScale max 1) min 100, true];
    missionNamespace setVariable ["FADE_teleportToPlayerMode", (round _teleportToPlayerMode) max 0 min 1, true];
    missionNamespace setVariable ["FADE_civTalkInterpretersOnly", _civTalkInterpretersOnly, true];
    missionNamespace setVariable ["FADE_intelSpecialistsOnly", _intelSpecialistsOnly, true];
    missionNamespace setVariable ["FADE_limitToPresetLoadouts", _presetOnly];
    _opforAirSetting = [_opforAirSetting] call FADE_normalizeOpforThreatSetting;
    _opforDroneSetting = [_opforDroneSetting] call FADE_normalizeOpforThreatSetting;
    _opforLauncherSetting = [_opforLauncherSetting] call FADE_normalizeOpforLauncherSetting;
    missionNamespace setVariable ["FADE_opforPopulationSetting", _opforPopulationSetting, true];
    missionNamespace setVariable ["FADE_opforLauncherSetting", _opforLauncherSetting, true];
    missionNamespace setVariable ["FADE_opforAirSetting", _opforAirSetting, true];
    missionNamespace setVariable ["FADE_opforDroneSetting", _opforDroneSetting, true];
    if (_opforLauncherSetting != "Normal") then { [] call FADE_reapplyOpforLauncherPolicyToAliveEnemy };
    _operationZoneCount = (round _operationZoneCount) max 2 min 10;
    missionNamespace setVariable ["FADE_operationZoneCount", _operationZoneCount, true];
    if (_opforAirSetting == "Off") then { call FADE_opforAir_despawnAll };
    if (_opforDroneSetting == "Off" && {!isNil "FADE_opforDrone_despawnAll"}) then { call FADE_opforDrone_despawnAll };
    private _opforResolved = [_opforPopulationSetting] call FADE_resolveOpforPopulationScale;
    private _opforScale = _opforResolved select 0;
    missionNamespace setVariable ["FADE_opforPopulationScale", _opforScale, true];

    private _enemySideNum = [_enemyFaction, 0] call FADE_getFactionSideNum;
    private _friendlySideNum = [_friendlyFaction, 1] call FADE_getFactionSideNum;
    missionNamespace setVariable ["FADE_scenarioEnemySideNum", _enemySideNum, true];
    missionNamespace setVariable ["FADE_scenarioFriendlySideNum", _friendlySideNum, true];
    missionNamespace setVariable ["FADE_sideEnemy", [_enemySideNum] call FADE_sideNumToSide, true];
    missionNamespace setVariable ["FADE_sideFriendly", [_friendlySideNum] call FADE_sideNumToSide, true];
    missionNamespace setVariable ["FADE_markerColorEnemy", ([_enemySideNum] call FADE_markerColorForSideNum), true];
    missionNamespace setVariable ["FADE_markerColorFriendly", ([_friendlySideNum] call FADE_markerColorForSideNum), true];

    // Build unit/vehicle arrays from chosen factions - these are the single source for all mission spawns
    private _enemyUnits = [_enemyFaction, _enemySideNum] call FADE_getUnitsForFaction;
    private _friendlyUnits = [_friendlyFaction, _friendlySideNum] call FADE_getUnitsForFaction;
    private _civUnits = [_civFaction, 3] call FADE_getUnitsForFaction;
    private _civVehicles = [_civFaction] call FADE_getCivVehiclesForFaction;

    if (_enemyUnits isEqualTo [] && { _enemyFaction isEqualTo "OPF_F" }) then {
        _enemyUnits = +(missionNamespace getVariable ["FADE_fallbackEnemyUnits", ["O_Soldier_TL_F", "O_Soldier_F", "O_Soldier_AR_F"]]);
    };
    if (_friendlyUnits isEqualTo [] && { _friendlyFaction isEqualTo "BLU_F" }) then {
        _friendlyUnits = +(missionNamespace getVariable ["FADE_fallbackFriendlyUnits", ["B_Soldier_TL_F", "B_Soldier_F", "B_Soldier_AR_F", "B_medic_F"]]);
    };
    _enemyUnits = [_enemyUnits] call FADE_filterUnitsArmed;
    _friendlyUnits = [_friendlyUnits] call FADE_filterUnitsArmed;
    _enemyUnits = [_enemyUnits] call FADE_filterEnemyUnitsByLauncherPolicy;
    _enemyUnits = [_enemyUnits, _enemyFaction, _enemySideNum, false] call FADE_filterUnitsForScenarioFaction;
    _friendlyUnits = [_friendlyUnits, _friendlyFaction, _friendlySideNum, false] call FADE_filterUnitsForScenarioFaction;
    // Shallow copy so we never store the same array reference as FADE_unitsByFactionSide cache (avoids accidental mutation).
    // Civs: NO fallbacks - AmbientCivilians uses GUI faction only; if empty, shows hint

    private _enemyVehicles = [_enemyFaction] call FADE_getEnemyVehiclesForFaction;
    private _friendlyVehicleClasses = [_friendlyFaction] call FADE_getFriendlyVehicleClasses;
    missionNamespace setVariable ["FADE_enemyUnits", +_enemyUnits];
    missionNamespace setVariable ["FADE_enemyVehicles", +_enemyVehicles];
    missionNamespace setVariable ["FADE_friendlyUnits", +_friendlyUnits];
    missionNamespace setVariable ["FADE_friendlyVehicleClasses", _friendlyVehicleClasses];
    missionNamespace setVariable ["FADE_civUnitClasses", _civUnits];
    missionNamespace setVariable ["FADE_civRoadVehicleClasses", _civVehicles];
    missionNamespace setVariable ["FADE_civParkedVehicleClasses", _civVehicles];

    // Despawn all active civilian zones when faction changes or civilians disabled
    if (!isNil "FADE_civZoneState" && { FADE_civZoneState isEqualType createHashMap }) then {
        { [_x] call FADE_civ_despawnZone } forEach (keys FADE_civZoneState);
    };
    // Reset hint flags so user can see "no civs" hint again if new faction has none
    if (!isNil "FADE_civ_resetHintFlags") then { call FADE_civ_resetHintFlags };
    // Remove road vehicles (they use old driver classes, or when civilians disabled)
    if (!isNil "FADE_roadVehicles") then {
        { if (!isNull _x) then { { deleteVehicle _x } forEach (crew _x); deleteVehicle _x } } forEach FADE_roadVehicles;
        FADE_roadVehicles = [];
    };
    if (!isNil "FADE_civAmbientAircraft") then {
        { if (!isNull _x) then { { deleteVehicle _x } forEach (crew _x); deleteVehicle _x } } forEach FADE_civAmbientAircraft;
        FADE_civAmbientAircraft = [];
    };

    // Apply time and weather (server authority; syncs to all clients)
    private _date = date;
    setDate [_date select 0, _date select 1, _date select 2, _hour, _date select 4];
    if ((count _weatherParams) >= 9) then {
        missionNamespace setVariable ["FADE_scenarioWeatherParams", _weatherParams, true];
        [_weatherParams] call FADE_applyWeatherFromParams;
    } else {
        missionNamespace setVariable ["FADE_scenarioWeatherParams", [], true];
        [_weather] call FADE_applyWeatherPreset;
    };

    private _hourStr = (if (_hour < 10) then { "0" } else { "" }) + str _hour + "00";
    private _hintText = format [
        "<t size='1.2' color='#87CEEB'>SCENARIO UPDATE</t><br/><br/>" +
        "<t color='#A0B4C8'>DTG</t> <t color='#E0E0E0'>%1 ZULU</t><br/>" +
        "<t color='#A0B4C8'>WX</t> <t color='#E0E0E0'>%2</t>",
        _hourStr,
        _weather
    ];
    [_hintText] remoteExec ["FADE_showMissionHint", 0];
    // Single packed client sync (JIP + apply)  -  replaces per-field PV burst for GUI state.
    FADE_scenarioClientSync = [
        "v1",
        _friendlyFaction,
        _limitGear,
        _presetOnly,
        _enemyFaction,
        _civFaction,
        _civTalkInterpretersOnly,
        _intelSpecialistsOnly,
        +(missionNamespace getVariable ["FADE_friendlyUnits", []]),
        +(missionNamespace getVariable ["FADE_enemyUnits", []]),
        +(missionNamespace getVariable ["FADE_friendlyVehicleClasses", []]),
        missionNamespace getVariable ["FADE_limitToPresetLoadouts", false],
        missionNamespace getVariable ["FADE_teleportToPlayerMode", 0],
        missionNamespace getVariable ["FADE_sideEnemy", east],
        missionNamespace getVariable ["FADE_sideFriendly", west],
        missionNamespace getVariable ["FADE_scenarioEnemySideNum", 0],
        missionNamespace getVariable ["FADE_scenarioFriendlySideNum", 1],
        missionNamespace getVariable ["FADE_markerColorEnemy", "ColorEAST"],
        missionNamespace getVariable ["FADE_markerColorFriendly", "ColorWEST"]
    ];
    publicVariable "FADE_scenarioClientSync";

    // Reapply AAA level (dynamic airborne AAA manager)
    if (!isNil "FADE_aaa_applyLevel") then { call FADE_aaa_applyLevel };
};
FADE_sendScenarioConfigToClient = {
    params ["_player"];
    if (isNull _player) exitWith {};
    private _pack = missionNamespace getVariable ["FADE_scenarioClientSync", []];
    if (count _pack > 0) then {
        [_pack] remoteExec ["FADE_applyScenarioClientSync", _player];
    };
};
call compile preprocessFileLineNumbers "rsc\CivTalkServer.sqf";

publicVariable "FADE_applyScenarioSettings";
publicVariable "FADE_sendScenarioConfigToClient";
publicVariable "FADE_getUnitsForFaction";
publicVariable "FADE_getEnemyVehiclesForFaction";
publicVariable "FADE_getCivVehiclesForFaction";
publicVariable "FADE_getFactionSideNum";
publicVariable "FADE_sideNumToSide";
publicVariable "FADE_markerColorForSideNum";
publicVariable "FADE_resolveScenarioFriendlyUnits";
publicVariable "FADE_resolveScenarioEnemyUnits";
publicVariable "FAC_applyEnemyScenarioToGroup";

// Initial build: scenario unit/vehicle lists on missionNamespace (server). Scenario GUI Apply overwrites these; all mission spawns read from here.
// Default to globals from FADE_pickFactionByDisplayName (above) + Config  -  missionNamespace keys are not set until here, so plain "OPF_F"/"BLU_F" defaults ignore startup faction picks.
private _enemyF = missionNamespace getVariable ["FADE_scenarioEnemyFaction", FADE_scenarioEnemyFaction];
private _friendlyF = missionNamespace getVariable ["FADE_scenarioFriendlyFaction", FADE_scenarioFriendlyFaction];
private _civF = missionNamespace getVariable ["FADE_scenarioCivFaction", FADE_scenarioCivFaction];
missionNamespace setVariable ["FADE_scenarioEnemyFaction", _enemyF, true];
missionNamespace setVariable ["FADE_scenarioFriendlyFaction", _friendlyF, true];
missionNamespace setVariable ["FADE_scenarioCivFaction", _civF, true];
private _enemySideNum0 = [_enemyF, 0] call FADE_getFactionSideNum;
private _friendlySideNum0 = [_friendlyF, 1] call FADE_getFactionSideNum;
missionNamespace setVariable ["FADE_scenarioEnemySideNum", _enemySideNum0, true];
missionNamespace setVariable ["FADE_scenarioFriendlySideNum", _friendlySideNum0, true];
missionNamespace setVariable ["FADE_sideEnemy", [_enemySideNum0] call FADE_sideNumToSide, true];
missionNamespace setVariable ["FADE_sideFriendly", [_friendlySideNum0] call FADE_sideNumToSide, true];
missionNamespace setVariable ["FADE_markerColorEnemy", ([_enemySideNum0] call FADE_markerColorForSideNum), true];
missionNamespace setVariable ["FADE_markerColorFriendly", ([_friendlySideNum0] call FADE_markerColorForSideNum), true];
private _defEnemy = [_enemyF, _enemySideNum0] call FADE_getUnitsForFaction;
private _defFriendly = [_friendlyF, _friendlySideNum0] call FADE_getUnitsForFaction;
private _defCiv = [_civF, 3] call FADE_getUnitsForFaction;
private _defCivVeh = [_civF] call FADE_getCivVehiclesForFaction;
if (_defEnemy isEqualTo [] && { _enemyF isEqualTo "OPF_F" }) then {
    _defEnemy = +(missionNamespace getVariable ["FADE_fallbackEnemyUnits", ["O_Soldier_TL_F", "O_Soldier_F", "O_Soldier_AR_F"]]);
};
if (_defFriendly isEqualTo [] && { _friendlyF isEqualTo "BLU_F" }) then {
    _defFriendly = +(missionNamespace getVariable ["FADE_fallbackFriendlyUnits", ["B_Soldier_TL_F", "B_Soldier_F", "B_Soldier_AR_F", "B_medic_F"]]);
};
if (_defCiv isEqualTo []) then { _defCiv = ["C_man_1", "C_man_1_1_F", "C_man_polo_1_F"] };
if (_defCivVeh isEqualTo []) then { _defCivVeh = ["C_Offroad_01_F", "C_Hatchback_01_F", "C_SUV_01_F", "C_Van_01_transport_F"] };
_defEnemy = [_defEnemy] call FADE_filterUnitsArmed;
_defFriendly = [_defFriendly] call FADE_filterUnitsArmed;
_defEnemy = [_defEnemy] call FADE_filterEnemyUnitsByLauncherPolicy;
_defEnemy = [_defEnemy, _enemyF, _enemySideNum0, false] call FADE_filterUnitsForScenarioFaction;
_defFriendly = [_defFriendly, _friendlyF, _friendlySideNum0, false] call FADE_filterUnitsForScenarioFaction;
private _defFriendlyVeh = [_friendlyF] call FADE_getFriendlyVehicleClasses;
missionNamespace setVariable ["FADE_enemyUnits", +_defEnemy];
missionNamespace setVariable ["FADE_friendlyUnits", +_defFriendly];
missionNamespace setVariable ["FADE_friendlyVehicleClasses", _defFriendlyVeh];
missionNamespace setVariable ["FADE_civUnitClasses", _defCiv];
private _defEnemyVeh = [_enemyF] call FADE_getEnemyVehiclesForFaction;
missionNamespace setVariable ["FADE_enemyVehicles", +_defEnemyVeh];
missionNamespace setVariable ["FADE_civRoadVehicleClasses", _defCivVeh];
missionNamespace setVariable ["FADE_civParkedVehicleClasses", _defCivVeh];
missionNamespace setVariable ["FADE_currentMissionType", ""];
missionNamespace setVariable ["FADE_currentMissionPlayer", objNull];
missionNamespace setVariable ["FADE_limitToPresetLoadouts", missionNamespace getVariable ["FADE_limitToPresetLoadouts", false], true];
missionNamespace setVariable ["FADE_timeCompressionScale", missionNamespace getVariable ["FADE_timeCompressionScale", 1], true];
missionNamespace setVariable ["FADE_teleportToPlayerMode", missionNamespace getVariable ["FADE_teleportToPlayerMode", 0], true];
missionNamespace setVariable ["FADE_civTalkInterpretersOnly", missionNamespace getVariable ["FADE_civTalkInterpretersOnly", false], true];
missionNamespace setVariable ["FADE_intelSpecialistsOnly", missionNamespace getVariable ["FADE_intelSpecialistsOnly", false], true];
missionNamespace setVariable ["FADE_opforPopulationSetting", missionNamespace getVariable ["FADE_opforPopulationSetting", "Low"], true];
missionNamespace setVariable ["FADE_opforLauncherSetting", missionNamespace getVariable ["FADE_opforLauncherSetting", "Normal"], true];
missionNamespace setVariable ["FADE_opforAirSetting", missionNamespace getVariable ["FADE_opforAirSetting", "Off"], true];
missionNamespace setVariable ["FADE_opforDroneSetting", missionNamespace getVariable ["FADE_opforDroneSetting", "Off"], true];
missionNamespace setVariable ["FADE_scenarioPatrols", missionNamespace getVariable ["FADE_scenarioPatrols", true], true];
missionNamespace setVariable ["FADE_enemySkill", missionNamespace getVariable ["FADE_enemySkill", 0.0], true];
private _opforInit = [missionNamespace getVariable ["FADE_opforPopulationSetting", "Low"]] call FADE_resolveOpforPopulationScale;
missionNamespace setVariable ["FADE_opforPopulationScale", _opforInit select 0, true];
FADE_scenarioClientSync = [
    "v1",
    _friendlyF,
    missionNamespace getVariable ["FADE_limitGearToFriendlyFaction", false],
    missionNamespace getVariable ["FADE_limitToPresetLoadouts", false],
    _enemyF,
    _civF,
    missionNamespace getVariable ["FADE_civTalkInterpretersOnly", false],
    missionNamespace getVariable ["FADE_intelSpecialistsOnly", false],
    +_defFriendly,
    +_defEnemy,
    _defFriendlyVeh,
    missionNamespace getVariable ["FADE_limitToPresetLoadouts", false],
    missionNamespace getVariable ["FADE_teleportToPlayerMode", 0],
    missionNamespace getVariable ["FADE_sideEnemy", east],
    missionNamespace getVariable ["FADE_sideFriendly", west],
    _enemySideNum0,
    _friendlySideNum0,
    missionNamespace getVariable ["FADE_markerColorEnemy", "ColorEAST"],
    missionNamespace getVariable ["FADE_markerColorFriendly", "ColorWEST"]
];
publicVariable "FADE_scenarioClientSync";
diag_log format [
    "[FAC] Startup factions: friendly=%1 (%2 units), enemy=%3 (%4 units), civ=%5",
    _friendlyF, count _defFriendly, _enemyF, count _defEnemy, _civF
];
[] call FADE_missionSlots_publish;

// OPFOR ambient air (P24): bounded spawns toward BLUFOR players / base.
[] spawn {
    sleep 90;
    while { true } do {
        sleep 45;
        if (!isServer) exitWith {};
        call FADE_opforAir_trySpawn;
    };
};

