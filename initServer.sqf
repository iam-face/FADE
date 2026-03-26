// =============================================================================
// initServer.sqf - Face's Dynamic Sandbox server init
// =============================================================================
//
// DEDICATED SERVER / LOCality:
// - This file runs ONLY on the server (or host in listen server). if (!isServer) exitWith {}
//   ensures no execution on clients or headless. All spawning, markers, tasks, and
//   scenario state are server-authoritative; weather/time/date sync to clients automatically.
// - remoteExec target 2 = server; _player = requesting client; 0 = all clients.
// - Server-called functions (FADE_spawnHeli, FADE_startMission, etc.) must be
//   publicVariable'd so clients (and JIP) can invoke them. Variables clients need
//   (FADE_heliClasses, FADE_boards, etc.) are also publicVariable'd for JIP.
// - createMarker/deleteMarker: must run on the machine that created the marker (server).
// =============================================================================

if (!isServer) exitWith {};

// Config - single source of truth (rsc\Config.sqf); load before DebugBIScpStub so FADE_debugBIScp applies
call compile preprocessFileLineNumbers "rsc\Config.sqf";

// Debug: optional stub for missing BIS campaign functions (default off in Config - see rsc\DebugBIScpStub.sqf)
call compile preprocessFileLineNumbers "rsc\DebugBIScpStub.sqf";

// -----------------------------------------------------------------------------
// Scenario settings: single-pass CfgVehicles scan (load-time optimisation)
// One iteration builds: heliClasses, landVehicleClasses, and caches for faction
// lookups. getUnitsForFaction / getEnemyVehicles / getCivVehicles use cache.
// -----------------------------------------------------------------------------
FADE_unitsByFactionSide = createHashMap;   // key "faction_sideNum" -> array of Man classnames
FADE_enemyVehiclesByFaction = createHashMap; // key faction -> array of vehicle classnames
FADE_civVehiclesByFaction = createHashMap;   // key faction -> array; "" = generic civ vehicles
private _heliPairs = [];  // [displayName, class] for sort
private _landPairs = [];

{
    private _cfg = _x;
    private _class = configName _cfg;
    private _scope = getNumber (_cfg >> "scope");
    private _side = getNumber (_cfg >> "side");
    private _faction = getText (_cfg >> "faction");

    // Man: cache by faction_side for getUnitsForFaction
    // Civilian (side 3): include scope 0 so mod civ factions with hidden units are available
    private _isMan = _class isKindOf "Man";
    if (_isMan && { (_scope >= 1) || (_side == 3) }) then {
        private _key = _faction + "_" + str _side;
        private _arr = FADE_unitsByFactionSide getOrDefault [_key, []];
        _arr pushBack _class;
        FADE_unitsByFactionSide set [_key, _arr];
    };

    // Helicopter / Plane: for FADE_heliClasses
    if (_scope >= 2 && { (_class isKindOf "Helicopter") || (_class isKindOf "Plane") }) then {
        private _name = getText (_cfg >> "displayName");
        if (_name == "") then { _name = _class };
        _heliPairs pushBack [_name, _class];
    };

    // LandVehicle (excl. Air): for FADE_landVehicleClasses and vehicle faction caches
    if (_scope >= 2 && { _class isKindOf "LandVehicle" } && { !(_class isKindOf "Air") }) then {
        private _name = getText (_cfg >> "displayName");
        if (_name == "") then { _name = _class };
        _landPairs pushBack [_name, _class];
        if (_side == 0) then {
            private _arr = FADE_enemyVehiclesByFaction getOrDefault [_faction, []];
            _arr pushBack _class;
            FADE_enemyVehiclesByFaction set [_faction, _arr];
        };
        if (_side == 3) then {
            private _arr = FADE_civVehiclesByFaction getOrDefault [_faction, []];
            _arr pushBack _class;
            FADE_civVehiclesByFaction set [_faction, _arr];
        };
    };
    // Civilian vehicles scope 0/1: same as above, add by faction
    if (_side == 3 && { _scope < 2 } && { _class isKindOf "LandVehicle" } && { !(_class isKindOf "Air") }) then {
        private _arr = FADE_civVehiclesByFaction getOrDefault [_faction, []];
        _arr pushBack _class;
        FADE_civVehiclesByFaction set [_faction, _arr];
    };

    // Ship (enemy only): for CAS vehicle spawns
    if (_scope >= 2 && { _class isKindOf "Ship" } && { !(_class isKindOf "Air") } && { _side == 0 }) then {
        private _arr = FADE_enemyVehiclesByFaction getOrDefault [_faction, []];
        _arr pushBack _class;
        FADE_enemyVehiclesByFaction set [_faction, _arr];
    };
} forEach ("true" configClasses (configFile >> "CfgVehicles"));

// Sorted aircraft and land vehicle lists (classnames only)
_heliPairs sort true;
FADE_heliClasses = _heliPairs apply { _x select 1 };
_landPairs sort true;
FADE_landVehicleClasses = _landPairs apply { _x select 1 };

// Civilian addon filter: only keep classes from same addon(s) as faction. Avoids mods polluting CIV_F.
// If filter returns empty (e.g. CIV_F vanilla has no addon match), fall back to unfiltered or CIV_F defaults.
FADE_civ_filterByFactionAddon = {
    params ["_classes", "_faction", ["_isMan", true]];
    if (_classes isEqualTo [] || { _faction == "" }) exitWith { [] };
    private _factionCfg = configFile >> "CfgFactionClasses" >> _faction;
    if (!isClass _factionCfg) exitWith { [] };
    private _factionAddons = configSourceAddonList _factionCfg;
    if (_factionAddons isEqualTo []) exitWith { _classes };
    private _out = [];
    private _cfgRoot = configFile >> "CfgVehicles";
    {
        if (!(_x isEqualType "") || { !isClass (_cfgRoot >> _x) }) then { continue };
        private _unitAddons = configSourceAddonList (_cfgRoot >> _x);
        private _match = false;
        { if (_x in _factionAddons) exitWith { _match = true } } forEach _unitAddons;
        if (_match) then {
            if (_isMan && { !(_x isKindOf "Man") }) then { continue };
            if (!_isMan && { !(_x isKindOf "LandVehicle") || { _x isKindOf "Air" } }) then { continue };
            _out pushBackUnique _x;
        };
    } forEach _classes;
    if (_out isEqualTo [] && { _faction == "CIV_F" }) then {
        _out = if (_isMan) then {
            missionNamespace getVariable ["FADE_civUnitClasses", ["C_man_1","C_man_1_1_F","C_man_polo_1_F","C_man_polo_2_F","C_man_polo_3_F"]]
        } else {
            missionNamespace getVariable ["FADE_civRoadVehicleClasses", ["C_Offroad_01_F","C_Hatchback_01_F","C_SUV_01_F","C_Van_01_transport_F"]]
        };
    };
    if (_out isEqualTo []) exitWith { _classes };
    _out
};

// Filter unit classnames to those that spawn with a primary weapon or sidearm.
// We only accept CfgWeapons entries with type 1 (PrimaryWeapon) or 2 (Handgun).
// Returns original list if filtering would empty the list, so missions still have spawn options.
FADE_filterUnitsArmed = {
    params ["_classes"];
    if (_classes isEqualTo [] || { !(_classes isEqualType []) }) exitWith { _classes };
    private _out = [];
    {
        if (_x isEqualType "" && { isClass (configFile >> "CfgVehicles" >> _x) } && { _x isKindOf "Man" }) then {
            private _weapons = getArray (configFile >> "CfgVehicles" >> _x >> "weapons");
            private _hasPrimaryOrSidearm = false;
            {
                if (_x in ["Throw", "Put"]) then { continue };
                if (isClass (configFile >> "CfgWeapons" >> _x)) then {
                    private _wType = getNumber (configFile >> "CfgWeapons" >> _x >> "type");
                    if (_wType in [1, 2]) exitWith { _hasPrimaryOrSidearm = true };
                };
            } forEach _weapons;
            if (_hasPrimaryOrSidearm) then { _out pushBack _x };
        };
    } forEach _classes;
    if (_out isEqualTo []) then { _classes } else { _out };
};
// Backward-compatible alias used by existing mission scripts.
FADE_filterEnemyUnitsArmed = FADE_filterUnitsArmed;
FADE_filterFriendlyUnitsArmed = FADE_filterUnitsArmed;
missionNamespace setVariable ["FADE_filterUnitsArmed", FADE_filterUnitsArmed];
missionNamespace setVariable ["FADE_filterEnemyUnitsArmed", FADE_filterEnemyUnitsArmed];
missionNamespace setVariable ["FADE_filterFriendlyUnitsArmed", FADE_filterFriendlyUnitsArmed];

// Friendly group callsigns for RATEL-style sideChat (e.g. "Bravo 1-2")
FADE_friendlyCallsignPhonetics = ["Alpha","Bravo","Charlie","Delta","Echo","Foxtrot","Golf","Hotel"];
FADE_assignGroupCallsign = {
    params ["_group"];
    if (isNull _group) exitWith { "Alpha 1-1" };
    private _cs = _group getVariable ["FADE_callsign", ""];
    if (_cs != "") exitWith { _cs };
    private _p = selectRandom FADE_friendlyCallsignPhonetics;
    private _team = 1 + floor random 3;
    private _unit = 1 + floor random 4;
    _cs = format ["%1 %2-%3", _p, _team, _unit];
    _group setVariable ["FADE_callsign", _cs, true];
    _cs
};
missionNamespace setVariable ["FADE_assignGroupCallsign", FADE_assignGroupCallsign];

// Returns array of unit classnames for given faction (Man only).
// East/West/Independent: cache lookup (faction_side).
// Civilian (side 3): CfgGroups + cache fallback, BOTH filtered by faction addon - avoids mod pollution.
FADE_getUnitsForFaction = {
    params ["_faction", ["_sideNum", -1]];
    if (_faction == "") exitWith { [] };
    private _factionCfg = configFile >> "CfgFactionClasses" >> _faction;
    if (!isClass _factionCfg) exitWith { [] };
    if (_sideNum < 0) then { _sideNum = getNumber (_factionCfg >> "side") };

    if (_sideNum == 3) then {
        private _out = [];
        // 1) Try CfgGroups (faction-specific groups)
        {
            private _grpCfg = configFile >> "CfgGroups" >> _x >> _faction;
            if (isClass _grpCfg) then {
                {
                    {
                        private _units = getArray (_x >> "units");
                        {
                            if (_x isEqualType [] && { count _x >= 1 }) then {
                                private _cls = _x select 0;
                                if (_cls isEqualType "" && { isClass (configFile >> "CfgVehicles" >> _cls) } && { _cls isKindOf "Man" }) then {
                                    _out pushBackUnique _cls;
                                };
                            };
                        } forEach _units;
                    } forEach ("true" configClasses _x);
                } forEach ("true" configClasses _grpCfg);
            };
        } forEach ["Civilian", "Civilian_F", "CIV"];
        _out = [_out, _faction, true] call FADE_civ_filterByFactionAddon;

        // 2) Fallback: cache (units with faction_side), filtered by addon
        if (_out isEqualTo []) then {
            private _key = _faction + "_3";
            private _cached = FADE_unitsByFactionSide getOrDefault [_key, []];
            if (_cached isEqualTo []) then {
                // Mod faction may use CIV_F in CfgVehicles - scan all civ caches for same-addon units
                { _cached = _cached + (FADE_unitsByFactionSide getOrDefault [_x, []]) } forEach (keys FADE_unitsByFactionSide select { count _x >= 2 && { _x select [count _x - 2, 2] == "_3" } });
            };
            _out = [_cached, _faction, true] call FADE_civ_filterByFactionAddon;
        };
        _out
    } else {
        // For OPFOR/BLUFOR/INDFOR: try CfgGroups first (most reliable for modded factions),
        // then fall back to the CfgVehicles cache. Many modded units have a mismatched or empty
        // `faction` property in CfgVehicles, causing the cache lookup to fail - but CfgGroups
        // is explicitly authored per faction and is much more reliable.
        private _out = [];

        // CfgGroups side category names for each numeric side
        private _sideCategories = switch (_sideNum) do {
            case 0: { ["East", "Opfor"] };
            case 1: { ["West", "Blufor"] };
            case 2: { ["Guerrilla", "Independent", "Resistance", "Indfor"] };
            default { ["East", "West", "Guerrilla"] };
        };

        // 1) CfgGroups: iterate side categories, find faction sub-tree, collect Man classnames
        {
            private _grpCfg = configFile >> "CfgGroups" >> _x >> _faction;
            if (isClass _grpCfg) then {
                {
                    {
                        private _units = getArray (_x >> "units");
                        {
                            if (_x isEqualType [] && { count _x >= 1 }) then {
                                private _cls = _x select 0;
                                if (_cls isEqualType "" && { isClass (configFile >> "CfgVehicles" >> _cls) } && { _cls isKindOf "Man" }) then {
                                    _out pushBackUnique _cls;
                                };
                            };
                        } forEach _units;
                    } forEach ("true" configClasses _x);
                } forEach ("true" configClasses _grpCfg);
            };
        } forEach _sideCategories;

        // 2) Fallback: cache keyed by faction+sideNum (exact match)
        if (_out isEqualTo []) then {
            _out = FADE_unitsByFactionSide getOrDefault [_faction + "_" + str _sideNum, []];
        };

        // 3) For enemy factions (side 0), also check side 2 (Resistance) - some mod OPFOR factions
        //    configure their units as Independent in CfgVehicles but are presented as OPFOR in game
        if (_out isEqualTo [] && { _sideNum == 0 }) then {
            _out = FADE_unitsByFactionSide getOrDefault [_faction + "_2", []];
        };

        _out
    };
};

// Returns array of enemy vehicle classnames for faction; uses cache
FADE_getEnemyVehiclesForFaction = {
    params ["_faction"];
    if (_faction == "") exitWith { [] };
    FADE_enemyVehiclesByFaction getOrDefault [_faction, []]
};

// Returns array of friendly (BLUFOR) vehicle classnames for faction; aircraft + land. Same logic as enemy - faction from config.
FADE_getFriendlyVehicleClasses = {
    params ["_faction"];
    if (_faction == "") exitWith { [] };
    private _all = (FADE_heliClasses + FADE_landVehicleClasses);
    private _byFaction = [];
    {
        private _cfg = configFile >> "CfgVehicles" >> _x;
        if (getText (_cfg >> "faction") == _faction && { getNumber (_cfg >> "side") == 1 }) then {
            _byFaction pushBack _x;
        };
    } forEach _all;
    if (count _byFaction > 0) exitWith { _byFaction };
    private _blufor = _all select { getNumber (configFile >> "CfgVehicles" >> _x >> "side") == 1 };
    _blufor
};

// Returns array of civilian vehicle classnames for faction.
// CfgGroups first, then cache - BOTH filtered by faction addon.
FADE_getCivVehiclesForFaction = {
    params ["_faction"];
    if (_faction == "") exitWith { [] };
    private _out = [];
    {
        private _grpCfg = configFile >> "CfgGroups" >> _x >> _faction;
        if (isClass _grpCfg) then {
            {
                {
                    private _units = getArray (_x >> "units");
                    {
                        if (_x isEqualType [] && { count _x >= 1 }) then {
                            private _cls = _x select 0;
                            if (_cls isEqualType "" && { isClass (configFile >> "CfgVehicles" >> _cls) } && { _cls isKindOf "LandVehicle" } && { !(_cls isKindOf "Air") }) then {
                                _out pushBackUnique _cls;
                            };
                        };
                    } forEach _units;
                } forEach ("true" configClasses _x);
            } forEach ("true" configClasses _grpCfg);
        };
    } forEach ["Civilian", "Civilian_F", "CIV"];
    _out = [_out, _faction, false] call FADE_civ_filterByFactionAddon;
    if (_out isEqualTo []) then {
        private _byFaction = FADE_civVehiclesByFaction getOrDefault [_faction, []];
        private _cached = if (count _byFaction > 0) then { _byFaction } else {
            private _all = [];
            { _all = _all + (FADE_civVehiclesByFaction getOrDefault [_x, []]) } forEach (keys FADE_civVehiclesByFaction);
            _all
        };
        _out = [_cached, _faction, false] call FADE_civ_filterByFactionAddon;
    };
    private _seen = createHashMap;
    { _seen set [_x, true] } forEach _out;
    keys _seen
};

// Apply scenario settings from GUI - SERVER-SIDE GLOBAL: all mission spawns use these unit/vehicle lists.
// When a player clicks Apply, this runs on the server and overwrites missionNamespace; Missions.sqf (and other scripts) read from missionNamespace.
FADE_applyScenarioSettings = {
    params ["_hour", "_weather", "_enemyFaction", "_friendlyFaction", "_civFaction", ["_limitGear", false], ["_player", objNull], ["_patrolsEnabled", false], ["_enemySkill", 0.5], ["_enemyRouting", 0], ["_enemyAAA", "None"], ["_civiliansEnabled", true], ["_aoJtacEnabled", true], ["_aoStrength", "Medium"]];
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
    missionNamespace setVariable ["FADE_enemyAAALevel", _enemyAAA];
    missionNamespace setVariable ["FADE_civiliansEnabled", _civiliansEnabled];
    missionNamespace setVariable ["FADE_aoJtacEnabled", _aoJtacEnabled];
    missionNamespace setVariable ["FADE_aoStrength", _aoStrength];

    // Build unit/vehicle arrays from chosen factions - these are the single source for all mission spawns
    private _enemyUnits = [_enemyFaction, 0] call FADE_getUnitsForFaction;
    private _friendlyUnits = [_friendlyFaction, 1] call FADE_getUnitsForFaction;
    private _civUnits = [_civFaction, 3] call FADE_getUnitsForFaction;
    private _civVehicles = [_civFaction] call FADE_getCivVehiclesForFaction;

    if (_enemyUnits isEqualTo []) then { _enemyUnits = ["O_Soldier_TL_F", "O_Soldier_F", "O_Soldier_AR_F"] };
    if (_friendlyUnits isEqualTo []) then { _friendlyUnits = ["B_Soldier_TL_F", "B_Soldier_F", "B_Soldier_AR_F", "B_medic_F"] };
    _enemyUnits = [_enemyUnits] call FADE_filterUnitsArmed;
    _friendlyUnits = [_friendlyUnits] call FADE_filterUnitsArmed;
    // Civs: NO fallbacks - AmbientCivilians uses GUI faction only; if empty, shows hint

    private _enemyVehicles = [_enemyFaction] call FADE_getEnemyVehiclesForFaction;
    private _friendlyVehicleClasses = [_friendlyFaction] call FADE_getFriendlyVehicleClasses;
    missionNamespace setVariable ["FADE_enemyUnits", _enemyUnits];
    missionNamespace setVariable ["FADE_enemyVehicles", _enemyVehicles];
    missionNamespace setVariable ["FADE_friendlyUnits", _friendlyUnits];
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

    // Apply time and weather (server authority; syncs to all clients)
    private _date = date;
    setDate [_date select 0, _date select 1, _date select 2, _hour, _date select 4];
    [_weather] call FADE_applyWeatherPreset;

    private _hourStr = (if (_hour < 10) then { "0" } else { "" }) + str _hour + "00";
    private _enemyDn = getText (configFile >> "CfgFactionClasses" >> _enemyFaction >> "displayName");
    if (_enemyDn == "") then { _enemyDn = _enemyFaction };
    private _friendlyDn = getText (configFile >> "CfgFactionClasses" >> _friendlyFaction >> "displayName");
    if (_friendlyDn == "") then { _friendlyDn = _friendlyFaction };
    private _civDn = getText (configFile >> "CfgFactionClasses" >> _civFaction >> "displayName");
    if (_civDn == "") then { _civDn = _civFaction };
    private _skillDn = if (_enemySkill <= 0.35) then { "Low" } else { if (_enemySkill <= 0.6) then { "Medium" } else { if (_enemySkill <= 0.85) then { "High" } else { "Very High" } } };
    private _hintText = format [
        "<t size='1.3' color='#4A90D9' align='center'>SCENARIO UPDATED</t><br/><br/>" +
        "<t size='1.0' color='#E8E8E8'>Time:</t> <t color='#B0D0FF'>%1 ZULU</t><br/>" +
        "<t size='1.0' color='#E8E8E8'>Weather:</t> <t color='#B0D0FF'>%2</t><br/><br/>" +
        "<t size='1.0' color='#E8E8E8'>Friendly:</t> <t color='#B0FFB0'>%3</t><br/>" +
        "<t size='1.0' color='#E8E8E8'>Enemy:</t> <t color='#FFB0B0'>%4</t><br/>" +
        "<t size='1.0' color='#E8E8E8'>Civilian:</t> <t color='#FFE0B0'>%5</t> <t color='#E0E0E0'>(%6)</t><br/>" +
        "<t size='1.0' color='#E8E8E8'>Patrols:</t> <t color='#E0E0E0'>%7</t><br/>" +
        "<t size='1.0' color='#E8E8E8'>Enemy AI:</t> <t color='#E0E0E0'>%8 skill, routing %9, AAA %10, AO strength %11</t>",
        _hourStr, _weather, _friendlyDn, _enemyDn, _civDn, if (_civiliansEnabled) then { "enabled" } else { "disabled" },
        if (_patrolsEnabled) then { "ON" } else { "OFF" },
        _skillDn, if (_enemyRouting > 0) then { "ON" } else { "OFF" }, _enemyAAA, _aoStrength
    ];
    [_hintText] remoteExec ["FADE_showMissionHint", 0];
    // Sync scenario config to clients so Loadout/Vehicle GUIs can respect limit gear
    [_friendlyFaction, _limitGear] remoteExec ["FADE_syncScenarioConfig", 0, true];
    publicVariable "FADE_friendlyUnits";
    publicVariable "FADE_friendlyVehicleClasses";
    publicVariable "FADE_aoJtacEnabled";

    // Reapply AAA level (despawn existing, spawn new if Light/Medium/Heavy)
    if (!isNil "FADE_aaa_applyLevel") then { call FADE_aaa_applyLevel };
};
FADE_sendScenarioConfigToClient = {
    params ["_player"];
    if (isNull _player) exitWith {};
    private _f = missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"];
    private _l = missionNamespace getVariable ["FADE_limitGearToFriendlyFaction", false];
    [_f, _l] remoteExec ["FADE_syncScenarioConfig", _player];
};
publicVariable "FADE_applyScenarioSettings";
publicVariable "FADE_sendScenarioConfigToClient";
publicVariable "FADE_getUnitsForFaction";
publicVariable "FADE_getEnemyVehiclesForFaction";
publicVariable "FADE_getCivVehiclesForFaction";

// Initial build: scenario unit/vehicle lists on missionNamespace (server). Scenario GUI Apply overwrites these; all mission spawns read from here.
private _enemyF = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
private _friendlyF = missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"];
private _civF = missionNamespace getVariable ["FADE_scenarioCivFaction", "CIV_F"];
missionNamespace setVariable ["FADE_scenarioEnemyFaction", _enemyF, true];
missionNamespace setVariable ["FADE_scenarioFriendlyFaction", _friendlyF, true];
missionNamespace setVariable ["FADE_scenarioCivFaction", _civF, true];
private _defEnemy = [_enemyF, 0] call FADE_getUnitsForFaction;
private _defFriendly = [_friendlyF, 1] call FADE_getUnitsForFaction;
private _defCiv = [_civF, 3] call FADE_getUnitsForFaction;
private _defCivVeh = [_civF] call FADE_getCivVehiclesForFaction;
if (_defEnemy isEqualTo []) then { _defEnemy = ["O_Soldier_TL_F", "O_Soldier_F", "O_Soldier_AR_F"] };
if (_defFriendly isEqualTo []) then { _defFriendly = ["B_Soldier_TL_F", "B_Soldier_F", "B_Soldier_AR_F", "B_medic_F"] };
if (_defCiv isEqualTo []) then { _defCiv = ["C_man_1", "C_man_1_1_F", "C_man_polo_1_F"] };
if (_defCivVeh isEqualTo []) then { _defCivVeh = ["C_Offroad_01_F", "C_Hatchback_01_F", "C_SUV_01_F", "C_Van_01_transport_F"] };
_defEnemy = [_defEnemy] call FADE_filterUnitsArmed;
_defFriendly = [_defFriendly] call FADE_filterUnitsArmed;
private _defFriendlyVeh = [_friendlyF] call FADE_getFriendlyVehicleClasses;
missionNamespace setVariable ["FADE_enemyUnits", _defEnemy];
missionNamespace setVariable ["FADE_friendlyUnits", _defFriendly];
missionNamespace setVariable ["FADE_friendlyVehicleClasses", _defFriendlyVeh];
missionNamespace setVariable ["FADE_civUnitClasses", _defCiv];
private _defEnemyVeh = [_enemyF] call FADE_getEnemyVehiclesForFaction;
missionNamespace setVariable ["FADE_enemyVehicles", _defEnemyVeh];
missionNamespace setVariable ["FADE_civRoadVehicleClasses", _defCivVeh];
missionNamespace setVariable ["FADE_civParkedVehicleClasses", _defCivVeh];
missionNamespace setVariable ["FADE_currentMissionType", ""];
missionNamespace setVariable ["FADE_currentMissionPlayer", objNull];
missionNamespace setVariable ["FADE_aoJtacEnabled", missionNamespace getVariable ["FADE_aoJtacEnabled", true]];
publicVariable "FADE_currentMissionType";

// -----------------------------------------------------------------------------
// Reusable: apply weather preset by name. Syncs to all clients (server authority).
// Call only on server. forceWeatherChange applies immediately; rain needs overcast >= 0.7.
// -----------------------------------------------------------------------------
FADE_applyWeatherPreset = {
    params ["_preset"];
    switch _preset do {
        case "Clear": { 0 setOvercast 0; 0 setRain 0; 0 setFog [0, 0, 0]; forceWeatherChange; };
        case "Overcast": { 0 setOvercast 0.5; 0 setRain 0; 0 setFog [0, 0, 0]; forceWeatherChange; };
        case "Foggy": { 0 setOvercast 0.3; 0 setRain 0; 0 setFog [0.5, 0.01, 0]; forceWeatherChange; };
        case "Rain": { 0 setOvercast 0.8; 0 setRain 0.5; 0 setFog [0.1, 0.01, 0]; forceWeatherChange; };
        case "Storm": { 0 setOvercast 1; 0 setRain 1; 0 setFog [0.2, 0.01, 0]; forceWeatherChange; };
        case "FaceMission": { 0 setOvercast 1; 0 setRain 1; 0 setFog [0.5, 0.01, 0]; forceWeatherChange; };
        default {};
    };
};

// Apply initial time and weather from Config (server; syncs to clients)
private _initHour = missionNamespace getVariable ["FADE_scenarioTime", 12];
private _initWeather = missionNamespace getVariable ["FADE_scenarioWeather", "Clear"];
private _date = date;
setDate [_date select 0, _date select 1, _date select 2, _initHour, _date select 4];
[_initWeather] call FADE_applyWeatherPreset;

// Ambient civilians (CIV_T_*, ROAD_SP_*)
[] execVM "rsc\AmbientCivilians.sqf";

// Enemy AAA (Light/Medium/Heavy at high ground near civ zones; MANPADS in active civ zones)
[] execVM "rsc\EnemyAAA.sqf";
// Enemy checkpoints at checkPointPos_* (gated by Scenario Enemy Patrols ON/OFF)
[] execVM "rsc\EnemyCheckpoints.sqf";

// Helper: collect Eden objects by variable name
FADE_collectEdenNames = {
    params ["_names"];
    _names apply { missionNamespace getVariable [_x, objNull] } select { !isNull _x }
};

// Pads: array of [object, padName] for spawn logic (planes excluded from HP_1, HP_2)
FADE_helipadList = [];
{
    private _obj = missionNamespace getVariable [_x, objNull];
    if (!isNull _obj) then { FADE_helipadList pushBack [_obj, _x] };
} forEach (missionNamespace getVariable ["FADE_padNames", ["HP_1","HP_2","HP_3"]]);
FADE_helipads = FADE_helipadList apply { _x select 0 };  // objects only (for base pos, etc.)
// Interactive boards: vehicle (Manage Vehicles), mission (Manage Missions + Manage Scenario)
FADE_vehicleBoard = missionNamespace getVariable ["vehBoard", objNull];
FADE_missionBoard = missionNamespace getVariable ["missionBoard", objNull];
FADE_boards = [FADE_vehicleBoard, FADE_missionBoard] select { !isNull _x };
// CQB Training Shoothouse - single board (cqbBoard) and position triggers (CQB_POS_*)
FADE_cqbBoard = missionNamespace getVariable ["cqbBoard", objNull];
// CQB loudspeaker (Eden object name cqbLoudspeaker) - 3D SFX via remoteExec to clients (FAC_cqbLoudspeaker_clientPlay)
FADE_cqbLoudspeakerBroadcast = {
    params [["_mode", ""]];
    if (!isServer) exitWith {};
    if (_mode == "") exitWith {};
    [_mode] remoteExec ["FAC_cqbLoudspeaker_clientPlay", 0];
};

FADE_cqbPositions = (missionNamespace getVariable ["FADE_cqbPosNames", call {
    private _a = [];
    private _i = 1;
    while { _i <= 49 } do {
        _a pushBack format ["CQB_POS_%1", _i];
        _i = _i + 1;
    };
    _a
}]) apply { missionNamespace getVariable [_x, objNull] } select { !isNull _x };
missionNamespace setVariable ["FADE_cqbPosCount", count FADE_cqbPositions, true];
FADE_cqbDrillActive = false;
FADE_cqbSpawned = [];  // objects and groups to delete on end drill
FADE_cqbEnemyGroups = [];
FADE_cqbWatcherHandle = scriptNull;
FADE_cqbStarterKilledEh = [];  // [unit, eventHandlerId] while drill active
FADE_cqbStarterUnit = objNull;
FADE_cqbStarterUid = "";

// Apply board textures (Eden names). Non-interactable: base, loadout, music, firing range, teleport.
private _applyBoardTexture = {
    params ["_obj", "_path"];
    if (!isNull _obj && { count (getObjectTextures _obj) > 0 }) then { _obj setObjectTextureGlobal [0, _path] };
};
// Vehicle and Missions/Config boards (interactive)
[missionNamespace getVariable ["vehBoard", objNull], "img\vehicles.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["missionBoard", objNull], "img\missionsconfig.jpg"] call _applyBoardTexture;
// CQB (interactive)
[missionNamespace getVariable ["cqbBoard", objNull], "img\cqb.jpg"] call _applyBoardTexture;
// Base billboards (non-interactable). Add img\base.jpg and uncomment to set texture.
[missionNamespace getVariable ["baseBoard_1", objNull], "img\baseBoards.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["baseBoard_2", objNull], "img\baseBoards.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["baseBoard_3", objNull], "img\baseBoards.jpg"] call _applyBoardTexture;
// Loadout boards above loadout boxes (non-interactable)
[missionNamespace getVariable ["loadoutBoard_1", objNull], "img\loadouts.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["loadoutBoard_2", objNull], "img\loadouts.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["loadoutBoard_3", objNull], "img\loadouts.jpg"] call _applyBoardTexture;
// Music board next to jukebox (non-interactable)
[missionNamespace getVariable ["musicBoard", objNull], "img\music.jpg"] call _applyBoardTexture;
// Firing range sign (non-interactable)
[missionNamespace getVariable ["firingRangeBoard", objNull], "img\firingRange.jpg"] call _applyBoardTexture;
// Teleport boards (Fast Travel GUI)
[missionNamespace getVariable ["teleportBoard_1", objNull], "img\teleporter.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["teleportBoard_2", objNull], "img\teleporter.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["teleportBoard_3", objNull], "img\teleporter.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["teleportBoard_4", objNull], "img\teleporter.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["teleportBoard_5", objNull], "img\teleporter.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["teleportBoard_6", objNull], "img\teleporter.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["teleportBoard_7", objNull], "img\teleporter.jpg"] call _applyBoardTexture;
// All loadout boxes (from Config FADE_loadoutBoxNames); each gets loadout actions + ACE init
FADE_loadoutBoxes = (missionNamespace getVariable ["FADE_loadoutBoxNames", ["LOADOUTBOX", "LOADOUTBOX_2"]]) apply { missionNamespace getVariable [_x, objNull] } select { !isNull _x };
FADE_loadoutBox = FADE_loadoutBoxes param [0, objNull];
FADE_loadoutBox2 = FADE_loadoutBoxes param [1, objNull];
FADE_bSpPoints = [["B_SP_1","B_SP_2","B_SP_3"]] call FADE_collectEdenNames;

// ACE Arsenal: init each loadout box if ACE is loaded
if (isClass (configFile >> "CfgPatches" >> "ace_arsenal")) then {
    { if (!isNull _x) then { [_x, true, true] call ace_arsenal_fnc_initBox } } forEach FADE_loadoutBoxes;
};

// FADE_heliClasses and FADE_landVehicleClasses already built in single-pass scan above

// Vehicle spawn points (VEH_1, VEH_2) for land vehicles
FADE_vehiclePoints = [["VEH_1", "VEH_2"]] call FADE_collectEdenNames;

// Store original helipad marker text (for restore when pad emptied)
FADE_padMarkerOriginalText = [];
{
    private _mrkName = (missionNamespace getVariable ["FADE_helipadMarkers", []]) param [_forEachIndex, ""];
    if (_mrkName != "" && { getMarkerColor _mrkName != "" }) then {
        private _txt = markerText _mrkName;
        FADE_padMarkerOriginalText set [_forEachIndex, if (_txt != "") then { _txt } else { format ["Pad %1", _forEachIndex + 1] }];
    };
} forEach FADE_helipadList;

// Base position - from BASE_1 (centre of map), fallback to helipad or B_SP
private _baseObj = missionNamespace getVariable ["BASE_1", objNull];
if (!isNull _baseObj) then {
    FADE_basePos = getPosATL _baseObj;
} else {
    if (count FADE_helipads > 0) then {
        FADE_basePos = getPosATL (FADE_helipads select 0);
    } else {
        if (count FADE_bSpPoints > 0) then {
            FADE_basePos = position (FADE_bSpPoints select 0);
        } else {
            FADE_basePos = [5000, 5000, 0];
        };
    };
};

[] execVM "rsc\PadVehicleService.sqf";

// Map bounds for mission spawns (min/max X and Y)
FADE_mapMin = 500;
FADE_mapMax = 9500;
FADE_minDistFromBase = 700;

// -----------------------------------------------------------------------------
// Reusable: delete marker only if it exists (avoids "marker not found" in RPT).
// Markers are global; must be deleted on the same machine that created them (server).
// -----------------------------------------------------------------------------
FADE_deleteMarkerSafe = {
    params ["_markerName"];
    if (_markerName != "" && { getMarkerColor _markerName != "" }) then { deleteMarker _markerName };
};

// Enemy retreat: when 50% of mission enemies are dead, each remaining unit gets a skill-based chance to retreat (move 2 km away from base). Skill 0 = 100% retreat, skill 1 = 0%, linear in between. Call FADE_registerEnemyRetreat once per mission with enemy groups. Runs on server only (initServer / Missions.sqf).
FADE_retreatCheckInterval = 10;  // seconds between 50% checks
FADE_retreatDebug = false;  // set true for systemChat messages (retreat trigger, per-unit decisions)
FADE_doEnemyRetreat = {
    params ["_groups", "_basePos"];
    if (_groups isEqualTo [] || { _basePos isEqualTo [] }) exitWith {};
    private _skill = missionNamespace getVariable ["FADE_enemySkill", 0.5];
    private _retreatChance = 1 - (_skill max 0 min 1);
    private _debug = missionNamespace getVariable ["FADE_retreatDebug", false];
    if (_debug) then {
        [format ["Retreat: 50%% threshold reached. Rolling retreat (chance %1%2).", round (_retreatChance * 100), "%"]] remoteExec ["systemChat", 0];
    };
    {
        private _grp = _x;
        if (!isNull _grp && { side _grp == EAST }) then {
            private _toRetreat = [];
            private _staying = [];
            {
                if (alive _x) then {
                    private _roll = random 1;
                    private _retreat = _roll < _retreatChance;
                    if (_debug) then {
                        [format ["Retreat: unit %1 → %2 (roll %3 vs %4)", _x, if (_retreat) then { "RETREAT" } else { "STAY" }, round (_roll * 100) / 100, round (_retreatChance * 100) / 100]] remoteExec ["systemChat", 0];
                    };
                    if (_retreat) then { _toRetreat pushBack _x } else { _staying pushBack _x };
                };
            } forEach units _grp;
            if (count _toRetreat > 0) then {
                if (_debug) then {
                    [format ["Retreat: group %1 → %2 retreating, %3 staying. Clearing waypoints.", _grp, count _toRetreat, count _staying]] remoteExec ["systemChat", 0];
                };
                // Clear all current waypoints so retreat replaces orders, not appends
                private _wps = waypoints _grp;
                for "_i" from (count _wps - 1) to 0 step -1 do {
                    deleteWaypoint [_grp, _i];
                };
                _grp setSpeedMode "FULL";
                {
                    private _unitPos = getPos _x;
                    if (count _unitPos >= 2) then {
                        private _dirToBase = _x getDir _basePos;
                        private _dest = _unitPos getPos [2000, _dirToBase + 180];
                        _x doMove _dest;
                        _x setUnitPos "AUTO";
                    };
                } forEach _toRetreat;
            };
        };
    } forEach _groups;
    if (_debug) then {
        [format ["Retreat: done. Orders sent (doMove 2km away from base)."]] remoteExec ["systemChat", 0];
    };
};
FADE_registerEnemyRetreat = {
    params ["_groups", "_basePos"];
    if (_groups isEqualTo [] || { _basePos isEqualTo [] }) exitWith {};
    private _initialTotal = 0;
    { _initialTotal = _initialTotal + count units _x } forEach _groups;
    if (_initialTotal <= 1) exitWith {};  // 50% of 0 or 1 is pointless; avoid spawning check thread
    private _interval = missionNamespace getVariable ["FADE_retreatCheckInterval", 10];
    private _debug = missionNamespace getVariable ["FADE_retreatDebug", false];
    if (_debug) then {
        [format ["Retreat: registered %1 groups, %2 total enemies. Checking every %3s.", count _groups, _initialTotal, _interval]] remoteExec ["systemChat", 0];
    };
    [_groups, _basePos, _initialTotal, _interval, _debug] spawn {
        params ["_groups", "_basePos", "_initialTotal", "_interval", "_debug"];
        waitUntil {
            sleep _interval;
            private _alive = 0;
            { _alive = _alive + ({ alive _x } count units _x) } forEach _groups;
            _alive <= _initialTotal * 0.5
        };
        private _aliveNow = 0;
        { _aliveNow = _aliveNow + ({ alive _x } count units _x) } forEach _groups;
        if (_debug) then {
            [format ["Retreat: 50%% condition met (%1 alive / %2 initial). Applying retreat roll.", _aliveNow, _initialTotal]] remoteExec ["systemChat", 0];
        };
        [_groups, _basePos] call FADE_doEnemyRetreat;
    };
};

// Find mission position in urban areas only (civ zones). Returns [] if no civ zones.
// Params: [["_minDistOverride", -1]]
FADE_findMissionPosUrban = {
    params [["_minDistOverride", -1]];
    private _base = FADE_basePos;
    private _minDist = if (_minDistOverride > 0) then { _minDistOverride } else { FADE_minDistFromBase };
    private _minXY = FADE_mapMin;
    private _maxXY = FADE_mapMax;
    private _civZoneRadius = 2500;
    private _civZones = missionNamespace getVariable ["FADE_civTriggerNames", []];
    if (count _civZones == 0) exitWith { [] };
    private _result = [];
    private _attempt = 0;
    while { _attempt < 25 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        private _zoneName = selectRandom _civZones;
        private _trig = missionNamespace getVariable [_zoneName, objNull];
        if (!isNull _trig) then {
            private _zoneCenter = getPosATL _trig;
            private _candidate = [_zoneCenter, 100, _civZoneRadius, 5, 0.5, 0.5, 0, [], _zoneCenter] call BIS_fnc_findSafePos;
            if (count _candidate >= 2 && { !(surfaceIsWater _candidate) } && { (_candidate distance _base) >= _minDist }) then {
                private _sx = _candidate select 0;
                private _sy = _candidate select 1;
                if (_sx >= _minXY && { _sx <= _maxXY } && { _sy >= _minXY } && { _sy <= _maxXY }) then {
                    _result = _candidate;
                };
            };
        };
    };
    _result
};

// Like findMissionPosUrban but keeps position near zone center (50–400 m) so we're in the built-up area.
// Use for mission types that need buildings (e.g. Hostage). Params: [["_minDistOverride", -1]]
FADE_findMissionPosUrbanNearCenter = {
    params [["_minDistOverride", -1]];
    private _base = FADE_basePos;
    private _minDist = if (_minDistOverride > 0) then { _minDistOverride } else { FADE_minDistFromBase };
    private _minXY = FADE_mapMin;
    private _maxXY = FADE_mapMax;
    private _civZones = missionNamespace getVariable ["FADE_civTriggerNames", []];
    if (count _civZones == 0) exitWith { [] };
    private _result = [];
    private _attempt = 0;
    while { _attempt < 25 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        private _zoneName = selectRandom _civZones;
        private _trig = missionNamespace getVariable [_zoneName, objNull];
        if (!isNull _trig) then {
            private _zoneCenter = getPosATL _trig;
            private _candidate = [_zoneCenter, 50, 400, 5, 0.5, 0.5, 0, [], _zoneCenter] call BIS_fnc_findSafePos;
            if (count _candidate >= 2 && { !(surfaceIsWater _candidate) } && { (_candidate distance _base) >= _minDist }) then {
                private _sx = _candidate select 0;
                private _sy = _candidate select 1;
                if (_sx >= _minXY && { _sx <= _maxXY } && { _sy >= _minXY } && { _sy <= _maxXY }) then {
                    _result = _candidate;
                };
            };
        };
    };
    _result
};

// Find a road position within 200 m of a random civ zone (for Find and Clear IEDs). Returns [] if none.
FADE_findMissionPosIED = {
    private _civZones = missionNamespace getVariable ["FADE_civTriggerNames", []];
    if (_civZones isEqualTo []) exitWith { [] };
    private _base = FADE_basePos;
    private _minDist = FADE_minDistFromBase;
    private _result = [];
    for "_a" from 0 to 14 do {
        private _trig = missionNamespace getVariable [selectRandom _civZones, objNull];
        if (!isNull _trig) then {
            private _center = getPosATL _trig;
            if (count _center < 2) then { _center = [0,0,0] };
            if (_center distance _base < _minDist) then { continue };
            private _roads = _center nearRoads 200;
            if (_roads isEqualTo []) then { continue };
            private _road = selectRandom _roads;
            private _pos = getPosATL _road;
            if (count _pos >= 2 && { !(surfaceIsWater _pos) } && { _pos distance _base >= _minDist }) then {
                _result = [(_pos select 0), (_pos select 1), (_pos param [2, 0])];
            };
        };
        if (count _result >= 2) exitWith {};
    };
    _result
};
missionNamespace setVariable ["FADE_findMissionPosIED", FADE_findMissionPosIED];

// Find a valid mission position: near a civ zone (CIV_T_*), within 2.5km of zone center,
// at least _minDistOverride (or FADE_minDistFromBase) from base, clear ground, not on water.
// Params: [["_minDistOverride", -1]] - if > 0, use instead of FADE_minDistFromBase (e.g. 1000 for enemy missions)
FADE_findMissionPos = {
    params [["_minDistOverride", -1]];
    private _base = FADE_basePos;
    private _minDist = if (_minDistOverride > 0) then { _minDistOverride } else { FADE_minDistFromBase };
    private _minXY = FADE_mapMin;
    private _maxXY = FADE_mapMax;
    private _civZoneRadius = 2500;
    private _result = [];
    private _attempt = 0;
    private _civZones = missionNamespace getVariable ["FADE_civTriggerNames", []];

    while { _attempt < 25 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        private _candidate = [];
        if (count _civZones > 0) then {
            private _zoneName = selectRandom _civZones;
            private _trig = missionNamespace getVariable [_zoneName, objNull];
            if (!isNull _trig) then {
                private _zoneCenter = getPosATL _trig;
                _candidate = [_zoneCenter, 100, _civZoneRadius, 5, 0.5, 0.5, 0, [], _zoneCenter] call BIS_fnc_findSafePos;
            };
        };
        if (count _candidate < 2) then {
            private _x = _minXY + random (_maxXY - _minXY);
            private _y = _minXY + random (_maxXY - _minXY);
            _candidate = [_x, _y, 0];
            _candidate = [_candidate, 0, 80, 5, 0.5, 0.5, 0, [], _candidate] call BIS_fnc_findSafePos;
        };
        if (count _candidate >= 2 && { !(surfaceIsWater _candidate) } && { (_candidate distance _base) >= _minDist }) then {
            private _sx = _candidate select 0;
            private _sy = _candidate select 1;
            if (_sx >= _minXY && { _sx <= _maxXY } && { _sy >= _minXY } && { _sy <= _maxXY }) then {
                _result = _candidate;
            };
        };
    };
    _result
};

// Find a safe LZ for helicopter landing: no water, no buildings, no trees within radius
// Params: [_center] - center position to search around
// Returns: position array or [] if none found
FADE_findSafeLZ = {
    params ["_center"];
    if (count _center < 2) exitWith { [] };
    private _lzRadius = 25;   // min distance from objects (trees, buildings)
    private _maxGrad = 0.3;   // flatter terrain for landing
    private _attempt = 0;
    private _result = [];
    while { _attempt < 15 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        private _safe = [_center, 0, 120, _lzRadius, 0, _maxGrad, 0, [], []] call BIS_fnc_findSafePos;
        if (count _safe >= 2) then {
            if (!(surfaceIsWater _safe)) then {
                private _terrainObstacles = nearestTerrainObjects [_safe, ["TREE", "SMALL TREE", "BUSH", "BUILDING", "HOUSE", "WALL"], _lzRadius, false];
                private _vehObstacles = nearestObjects [_safe, ["Building", "House", "Wall"], _lzRadius];
                private _blocking = (_terrainObstacles + _vehObstacles) select { !isNull _x };
                if (count _blocking == 0) then {
                    _result = _safe;
                };
            };
        };
    };
    _result
};

// -----------------------------------------------------------------------------
// CQB Training Shoothouse - start/end drill (server). Called via remoteExec from CQB GUI.
// Params: [player, enemyType ("targets"|"enemies"), density ("Low"|"Medium"|"High"), civilians (bool)]
// Density: Low 20%, Medium 33%, High 50% per position. Civilians: 15% chance per spawn when true.
// -----------------------------------------------------------------------------
FADE_cqbStartDrill = {
    params ["_player", "_enemyType", "_density", "_civilians"];
    if (!isServer) exitWith {};
    if (missionNamespace getVariable ["FADE_cqbDrillActive", false]) exitWith {
        ["CQB drill already active. End it first."] remoteExec ["systemChat", _player];
    };
    private _positions = missionNamespace getVariable ["FADE_cqbPositions", []];
    if (_positions isEqualTo []) exitWith {
        ["No CQB positions found. Place CQB_POS_1, CQB_POS_2, ... in Eden."] remoteExec ["systemChat", _player];
    };
    private _chance = switch (_density) do {
        case "High": { 0.5 };
        case "Medium": { 0.33 };
        default { 0.2 };  // Low
    };
    private _enemyUnits = missionNamespace getVariable ["FADE_enemyUnits", ["O_Soldier_F"]];
    _enemyUnits = [_enemyUnits] call FADE_filterUnitsArmed;
    if (_enemyUnits isEqualTo []) then { _enemyUnits = ["O_Soldier_F"] };
    private _civUnits = missionNamespace getVariable ["FADE_civUnitClasses", ["C_man_1"]];
    if (_civUnits isEqualTo []) then { _civUnits = ["C_man_1"] };
    private _targetClass = missionNamespace getVariable ["FADE_cqbTargetClass", "TargetP_Inf_F"];
    if (!isClass (configFile >> "CfgVehicles" >> _targetClass)) then { _targetClass = "Target_F" };
    missionNamespace setVariable ["noPop", true];  // pop-up targets stay down when shot
    private _spawned = [];
    private _enemyGroups = [];
    {
        if (random 1 >= _chance) then { continue };
        private _posObj = _x;
        private _pos = getPosATL _posObj;
        if (count _pos < 3) then { _pos = [_pos select 0, _pos select 1, 0] };
        private _dir = getDir _posObj;
        private _isCiv = _civilians && { random 1 < 0.15 };
        if (_enemyType == "targets") then {
            private _target = createVehicle [_targetClass, _pos, [], 0, "NONE"];
            _target setPosATL _pos;
            _target setDir (_dir + 180);
            _spawned pushBack _target;
        } else {
            if (_isCiv) then {
                private _civClass = selectRandom _civUnits;
                private _grp = createGroup CIVILIAN;
                private _u = _grp createUnit [_civClass, _pos, [], 0, "NONE"];
                removeAllWeapons _u;
                removeAllItems _u;
                removeHeadgear _u;
                removeGoggles _u;
                _u addGoggles "G_Blindfold_01_black_F";
                _u disableAI "PATH";
                _u setUnitPos "MIDDLE";
                _u setDir _dir;
                _u switchMove "Acts_ExecutionVictim_Loop";
                _spawned pushBack _grp;
            } else {
                private _unitClass = selectRandom _enemyUnits;
                private _grp = createGroup EAST;
                private _u = _grp createUnit [_unitClass, _pos, [], 0, "NONE"];
                _u setDir _dir;
                _u disableAI "PATH";
                _u setUnitPos "MIDDLE";
                _spawned pushBack _grp;
                _enemyGroups pushBack _grp;
            };
        };
    } forEach _positions;
    missionNamespace setVariable ["FADE_cqbSpawned", _spawned];
    missionNamespace setVariable ["FADE_cqbEnemyGroups", _enemyGroups];
    missionNamespace setVariable ["FADE_cqbDrillActive", true];
    publicVariable "FADE_cqbDrillActive";
    missionNamespace setVariable ["FADE_cqbStarterUnit", _player];
    missionNamespace setVariable ["FADE_cqbStarterUid", getPlayerUID _player];
    private _starterKh = _player addEventHandler ["Killed", {
        if (!(missionNamespace getVariable ["FADE_cqbDrillActive", false])) exitWith {};
        private _victim = _this select 0;
        if (_victim != missionNamespace getVariable ["FADE_cqbStarterUnit", objNull]) exitWith {};
        [_victim, "CQB drill ended: trainee down.", true] call FADE_cqbEndDrill;
    }];
    missionNamespace setVariable ["FADE_cqbStarterKilledEh", [_player, _starterKh]];
    ["start"] call FADE_cqbLoudspeakerBroadcast;
    // Auto-complete enemy drills when all enemy units are dead or surrendered/captive.
    if (_enemyType == "enemies") then {
        private _existingWatcher = missionNamespace getVariable ["FADE_cqbWatcherHandle", scriptNull];
        if (!isNull _existingWatcher) then { terminate _existingWatcher };
        private _watcher = [_player] spawn {
            params ["_player"];
            while { missionNamespace getVariable ["FADE_cqbDrillActive", false] } do {
                sleep 1;
                private _groups = missionNamespace getVariable ["FADE_cqbEnemyGroups", []];
                private _remainingHostile = 0;
                {
                    if (isNull _x) then { continue };
                    {
                        if (!alive _x) then { continue };
                        // Surrendered units count as neutralised for drill completion.
                        private _isSurrendered = captive _x
                            || { _x getVariable ["ACE_isSurrendered", false] }
                            || { _x getVariable ["ace_captives_isSurrendering", false] };
                        if (!_isSurrendered) then { _remainingHostile = _remainingHostile + 1 };
                    } forEach units _x;
                } forEach _groups;
                if (_remainingHostile <= 0) exitWith {
                    if (missionNamespace getVariable ["FADE_cqbDrillActive", false]) then {
                        [_player] call FADE_cqbEndDrill;
                        ["CQB drill complete: all enemy units neutralised (dead or surrendered)."] remoteExec ["systemChat", _player];
                    };
                };
            };
        };
        missionNamespace setVariable ["FADE_cqbWatcherHandle", _watcher];
    };
    [format ["CQB drill started. %1 spawns.", count _spawned]] remoteExec ["systemChat", _player];
};
FADE_cqbEndDrill = {
    params ["_player", ["_msg", "CQB drill ended."], ["_broadcastAll", false]];
    if (!isServer) exitWith {};
    if (!(missionNamespace getVariable ["FADE_cqbDrillActive", false])) exitWith {};
    private _khPair = missionNamespace getVariable ["FADE_cqbStarterKilledEh", []];
    if (count _khPair >= 2) then {
        _khPair params ["_u", "_eh"];
        if (!isNull _u && {_eh >= 0}) then { _u removeEventHandler ["Killed", _eh] };
    };
    missionNamespace setVariable ["FADE_cqbStarterKilledEh", []];
    missionNamespace setVariable ["FADE_cqbStarterUnit", objNull];
    missionNamespace setVariable ["FADE_cqbStarterUid", ""];
    ["stop"] call FADE_cqbLoudspeakerBroadcast;
    private _spawned = missionNamespace getVariable ["FADE_cqbSpawned", []];
    {
        if (isNull _x) then { continue };
        if (_x isEqualType grpNull) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach units _x;
            deleteGroup _x;
        } else {
            deleteVehicle _x;
        };
    } forEach _spawned;
    missionNamespace setVariable ["FADE_cqbSpawned", []];
    missionNamespace setVariable ["FADE_cqbEnemyGroups", []];
    private _watcher = missionNamespace getVariable ["FADE_cqbWatcherHandle", scriptNull];
    if (!isNull _watcher) then { terminate _watcher };
    missionNamespace setVariable ["FADE_cqbWatcherHandle", scriptNull];
    missionNamespace setVariable ["FADE_cqbDrillActive", false];
    publicVariable "FADE_cqbDrillActive";
    if (_broadcastAll || {isNull _player}) then {
        [_msg] remoteExec ["systemChat", 0];
    } else {
        [_msg] remoteExec ["systemChat", _player];
    };
};

publicVariable "FADE_heliClasses";
publicVariable "FADE_landVehicleClasses";
publicVariable "FADE_friendlyUnits";
publicVariable "FADE_friendlyVehicleClasses";
publicVariable "FADE_vehiclePoints";
publicVariable "FADE_helipads";
publicVariable "FADE_boards";
publicVariable "FADE_vehicleBoard";
publicVariable "FADE_missionBoard";
publicVariable "FADE_cqbBoard";
publicVariable "FADE_cqbDrillActive";
publicVariable "FADE_cqbStartDrill";
publicVariable "FADE_cqbEndDrill";

addMissionEventHandler ["HandleDisconnect", {
    params ["_id", "_uid", "_name", "_jip", "_owner", "_idstr"];
    if (!(missionNamespace getVariable ["FADE_cqbDrillActive", false])) exitWith {};
    private _suid = missionNamespace getVariable ["FADE_cqbStarterUid", ""];
    if (_suid == "" || {_uid != _suid}) exitWith {};
    [objNull, "CQB drill ended: trainee disconnected.", true] call FADE_cqbEndDrill;
}];

publicVariable "FADE_loadoutBoxes";
publicVariable "FADE_loadoutBox";
publicVariable "FADE_loadoutBox2";
publicVariable "FADE_basePos";
publicVariable "FADE_bSpPoints";
publicVariable "FADE_mapMin";
publicVariable "FADE_mapMax";

// -----------------------------------------------------------------------------
// Update helipad markers to show vehicle on pad (aircraft only, not ground vehicles).
// FADE_padMarkerOriginalText is populated above; do not reset it here.
// -----------------------------------------------------------------------------
FADE_updateHelipadMarkers = {
    private _markers = missionNamespace getVariable ["FADE_helipadMarkers", []];
    if (count _markers == 0) exitWith {};
    {
        private _padIdx = _forEachIndex;
        private _mrkName = if (_padIdx < count _markers) then { _markers select _padIdx } else { "" };
        if (_mrkName == "" || { getMarkerColor _mrkName == "" }) then { continue };
        _x params ["_padObj", "_padName"];
        private _pos = getPosATL _padObj;
        private _near = nearestObjects [_pos, ["Air"], 10];
        private _veh = (_near select { !isNull _x && { alive _x } }) param [0, objNull];
        if (!isNull _veh) then {
            private _displayName = getText (configFile >> "CfgVehicles" >> (typeOf _veh) >> "displayName");
            if (_displayName == "") then { _displayName = typeOf _veh };
            _mrkName setMarkerText _displayName;
        } else {
            private _orig = FADE_padMarkerOriginalText param [_padIdx, ""];
            if (_orig == "") then { _orig = format ["Pad %1", _padIdx + 1] };
            _mrkName setMarkerText _orig;
        };
    } forEach FADE_helipadList;
};

// Periodic pad marker update - detects when aircraft leave pads (e.g. take off)
[] spawn {
    while { true } do {
        sleep 4;
        if (count (missionNamespace getVariable ["FADE_helipadMarkers", []]) > 0) then {
            call FADE_updateHelipadMarkers;
        };
    };
};

// -----------------------------------------------------------------------------
// Spawn helicopter (server). Called via remoteExec from client Vehicle GUI.
// Validates class and pad availability; creates vehicle on server; feedback via remoteExec to _player.
// -----------------------------------------------------------------------------
FADE_spawnHeli = {
    params ["_heliClass", "_player"];
    if (isNil "_heliClass" || { _heliClass == "" }) exitWith {
        ["INVALID AIRCRAFT CLASS."] remoteExec ["systemChat", _player];
    };
    if (count FADE_helipadList == 0) exitWith {
        ["NO PADS AVAILABLE."] remoteExec ["systemChat", _player];
    };

    // Planes cannot spawn at HP_1, HP_2; helicopters can use any pad
    private _isPlane = _heliClass isKindOf "Plane";
    private _forbidden = missionNamespace getVariable ["FADE_planeForbiddenPads", []];
    private _candidatePads = FADE_helipadList select {
        if (_isPlane) then { !((_x select 1) in _forbidden) } else { true }
    };

    private _pad = objNull;
    private _padRadius = 10;
    {
        _x params ["_padObj", "_padName"];
        private _pos = getPosATL _padObj;
        private _near = nearestObjects [_pos, ["Air", "LandVehicle"], _padRadius];
        private _blocking = _near select { !isNull _x && { alive _x } };
        if (count _blocking == 0) exitWith { _pad = _padObj };
    } forEach _candidatePads;
    if (isNull _pad) exitWith {
        ["ALL PADS OCCUPIED. DESPAWN OR MOVE AIRCRAFT 10M+ FROM PAD."] remoteExec ["systemChat", _player];
    };
    private _pos = getPosATL _pad;
    private _dir = getDir _pad;

    private _heli = createVehicle [_heliClass, _pos, [], 0, "NONE"];
    if (isNull _heli) exitWith {
        [format ["SPAWN FAILED. %1 INVALID OR MOD NOT LOADED.", _heliClass]] remoteExec ["systemChat", _player];
    };
    _heli setPosATL _pos;
    _heli setDir _dir;
    _heli setVehicleAmmo 1;

    // Clear any existing crew (unmanned spawn)
    { _heli deleteVehicleCrew _x } forEach crew _heli;

    private _displayName = getText (configFile >> "CfgVehicles" >> _heliClass >> "displayName");
    if (_displayName == "") then { _displayName = _heliClass };
    private _padNum = (FADE_helipadList findIf { (_x select 0) == _pad }) + 1;
    private _padDisplay = format ["Pad %1", _padNum];
    [format ["%1 SPAWNED AT %2.", _displayName, _padDisplay]] remoteExec ["systemChat", _player];
    call FADE_updateHelipadMarkers;
};

// -----------------------------------------------------------------------------
// Despawn any vehicle (server)
// -----------------------------------------------------------------------------
FADE_despawnVehicle = {
    params ["_veh", "_player"];
    if (isNull _veh) exitWith { ["INVALID VEHICLE."] remoteExec ["systemChat", _player] };
    private _dist = (getPosATL _veh) distance FADE_basePos;
    if (_dist > 1000) exitWith { ["VEHICLE MUST BE WITHIN 1000M OF BASE TO DESPAWN."] remoteExec ["systemChat", _player] };
    // Eject all crew (players and AI) before despawning
    private _crew = crew _veh;
    { if (isPlayer _x) then { moveOut _x } else { _veh deleteVehicleCrew _x } } forEach _crew;
    deleteVehicle _veh;
    ["VEHICLE DESPAWNED."] remoteExec ["systemChat", _player];
    if (_veh isKindOf "Air") then { call FADE_updateHelipadMarkers };
};

// -----------------------------------------------------------------------------
// Spawn land vehicle at VEH_1 or VEH_2 using BIS_fnc_findSafePosition
// -----------------------------------------------------------------------------
FADE_spawnLandVehicle = {
    params ["_vehicleClass", "_player"];
    if (isNil "_vehicleClass" || { _vehicleClass == "" }) exitWith {
        ["INVALID VEHICLE CLASS."] remoteExec ["systemChat", _player];
    };
    if (!isClass (configFile >> "CfgVehicles" >> _vehicleClass)) exitWith {
        [format ["UNKNOWN VEHICLE CLASS: %1", _vehicleClass]] remoteExec ["systemChat", _player];
    };
    if (count FADE_vehiclePoints == 0) exitWith {
        ["NO VEH SPAWN POINTS. CONFIGURE VEH_1/2 IN EDEN."] remoteExec ["systemChat", _player];
    };

    // Pick a spawn point (alternate or random)
    private _centerObj = selectRandom FADE_vehiclePoints;
    private _center = getPosATL _centerObj;
    private _dir = getDir _centerObj;

    // Collect positions of existing vehicles near VEH_1/VEH_2 for blacklist
    private _blacklist = [];
    { private _p = getPosATL _x; _blacklist pushBack [_p select 0, _p select 1] } forEach (nearestObjects [_center, ["LandVehicle", "Air"], 30]);

    // Find safe position: 2–15m from center, min 3m from objects
    private _pos = [_center, 2, 15, 3, 0, 0.5, 0, _blacklist, _center] call BIS_fnc_findSafePos;
    if (count _pos < 2) exitWith {
        ["NO CLEAR SPOT. DESPAWN NEARBY VEHICLES."] remoteExec ["systemChat", _player];
    };
    if (count _pos < 3) then { _pos = [_pos select 0, _pos select 1, 0] };

    private _veh = createVehicle [_vehicleClass, _pos, [], 0, "NONE"];
    if (isNull _veh) exitWith {
        [format ["SPAWN FAILED: %1.", _vehicleClass]] remoteExec ["systemChat", _player];
    };
    _veh setPosATL _pos;
    _veh setDir _dir;
    _veh setVehicleAmmo 1;
    { _veh deleteVehicleCrew _x } forEach crew _veh;

    private _displayName = getText (configFile >> "CfgVehicles" >> _vehicleClass >> "displayName");
    if (_displayName == "") then { _displayName = _vehicleClass };
    private _vehIdx = FADE_vehiclePoints find _centerObj;
    private _padDisplay = if (_vehIdx >= 0) then { format ["VEH %1", _vehIdx + 1] } else { "vehicle spawn" };
    [format ["%1 SPAWNED AT %2.", _displayName, _padDisplay]] remoteExec ["systemChat", _player];
};

// -----------------------------------------------------------------------------
// Return list of all vehicles at base with pad/location info [[vehicle, padDisplayName], ...]
// -----------------------------------------------------------------------------
FADE_requestVehiclesAtBase = {
    params ["_player"];
    if (isNull _player) exitWith {};
    private _pos = FADE_basePos;
    if (_pos isEqualType objNull) then { _pos = getPosATL _pos };
    private _near = nearestObjects [_pos, ["Air", "LandVehicle"], 1000];
    private _result = [];
    {
        if (!isNull _x && { alive _x }) then {
            private _vPos = getPosATL _x;
            private _padName = "";
            if (_x isKindOf "Air") then {
                { _x params ["_padObj", "_padId"]; if ((getPosATL _padObj) distance _vPos <= 10) exitWith { _padName = format ["Pad %1", (_forEachIndex + 1)] } } forEach FADE_helipadList;
            } else {
                { private _p = getPosATL _x; if (_vPos distance _p <= 15) exitWith { _padName = format ["VEH %1", (_forEachIndex + 1)] } } forEach FADE_vehiclePoints;
            };
            if (_padName == "") then { _padName = "Base" };
            _result pushBack [_x, _padName];
        };
    } forEach _near;
    [_result] remoteExec ["FADE_receiveVehiclesAtBase", _player];
};

// -----------------------------------------------------------------------------
// Get cargo (passenger) seat count for a vehicle class
// -----------------------------------------------------------------------------
FADE_getCargoSeats = {
    params ["_vehicleClass"];
    if (_vehicleClass isEqualType objNull) then { _vehicleClass = typeOf _vehicleClass };
    if (isNil "_vehicleClass" || { _vehicleClass == "" }) exitWith { 6 };
    if (!isClass (configFile >> "CfgVehicles" >> _vehicleClass)) exitWith { 6 };
    private _total = [_vehicleClass, true] call BIS_fnc_crewCount;
    private _crew = [_vehicleClass, false] call BIS_fnc_crewCount;
    ((_total - _crew) max 1) min 24
};

// -----------------------------------------------------------------------------
// Time & weather (server) - syncs to all clients in MP
// -----------------------------------------------------------------------------
FADE_setTime = {
    params ["_hour", "_player"];
    _hour = (_hour max 0) min 23;
    private _date = date;
    setDate [_date select 0, _date select 1, _date select 2, _hour, _date select 4];
    [format ["TIME SET %1:00 ZULU.", _hour]] remoteExec ["systemChat", _player];
};

FADE_setWeather = {
    params ["_preset", "_player"];
    if !(_preset in ["Clear", "Overcast", "Foggy", "Rain", "Storm", "FaceMission"]) exitWith {
        ["UNKNOWN WEATHER PRESET."] remoteExec ["systemChat", _player];
    };
    [_preset] call FADE_applyWeatherPreset;
    [format ["WEATHER SET: %1.", _preset]] remoteExec ["systemChat", _player];
};

// -----------------------------------------------------------------------------
// Optional player copilot helper (one AI per player, keyed by UID)
// -----------------------------------------------------------------------------
FADE_copilotByUid = createHashMap;

FADE_getCopilotForPlayer = {
    params ["_player"];
    if (isNull _player) exitWith { objNull };
    private _uid = getPlayerUID _player;
    if (_uid == "") exitWith { objNull };
    private _copilot = FADE_copilotByUid getOrDefault [_uid, objNull];
    if (isNull _copilot || { !alive _copilot }) then {
        FADE_copilotByUid deleteAt _uid;
        _copilot = objNull;
    };
    _copilot
};

FADE_requestCopilotState = {
    params ["_player"];
    if (isNull _player) exitWith {};
    private _cp = [_player] call FADE_getCopilotForPlayer;
    [!isNull _cp] remoteExec ["FADE_receiveCopilotState", _player];
};

FADE_spawnCopilot = {
    params ["_player"];
    if (isNull _player) exitWith {};
    private _existing = [_player] call FADE_getCopilotForPlayer;
    if (!isNull _existing) exitWith {
        ["You already have a copilot."] remoteExec ["systemChat", _player];
        [true] remoteExec ["FADE_receiveCopilotState", _player];
    };

    private _spawnPos = +FADE_basePos;
    if (count _spawnPos < 3) then { _spawnPos = [_spawnPos select 0, _spawnPos select 1, 0] };
    _spawnPos = [_spawnPos, 8, 20, 2, 0, 0.3, 0, [], _spawnPos] call BIS_fnc_findSafePos;
    if (count _spawnPos < 3) then { _spawnPos = [(_spawnPos select 0), (_spawnPos select 1), 0] };

    private _grp = group _player;
    if (isNull _grp) then { _grp = createGroup [side _player, true] };
    private _unitClass = "B_Helipilot_F";
    if (side _player == EAST) then { _unitClass = "O_helipilot_F" };
    if (side _player == RESISTANCE) then { _unitClass = "I_helipilot_F" };
    if (side _player == CIVILIAN) then { _unitClass = "C_man_1" };

    private _cp = _grp createUnit [_unitClass, _spawnPos, [], 0, "NONE"];
    if (isNull _cp) exitWith {
        ["Could not spawn copilot at base."] remoteExec ["systemChat", _player];
        [false] remoteExec ["FADE_receiveCopilotState", _player];
    };

    _cp setPosATL _spawnPos;
    _cp setDir random 360;
    _cp setSkill 0.6;
    private _loadout = getUnitLoadout _player;
    if (_loadout isEqualType [] && { count _loadout > 0 }) then { _cp setUnitLoadout _loadout };
    _cp setVariable ["FADE_isPlayerCopilot", true, true];
    _cp setVariable ["FADE_copilotOwnerUID", getPlayerUID _player, true];

    FADE_copilotByUid set [getPlayerUID _player, _cp];

    _cp sideChat "This is your copilot. Ready at base and awaiting tasking. Over.";
    ["Copilot spawned at base and added to your group."] remoteExec ["systemChat", _player];
    [true] remoteExec ["FADE_receiveCopilotState", _player];
};

FADE_removeCopilot = {
    params ["_player"];
    if (isNull _player) exitWith {};
    private _cp = [_player] call FADE_getCopilotForPlayer;
    if (isNull _cp) exitWith {
        ["No active copilot to remove."] remoteExec ["systemChat", _player];
        [false] remoteExec ["FADE_receiveCopilotState", _player];
    };
    deleteVehicle _cp;
    FADE_copilotByUid deleteAt (getPlayerUID _player);
    ["Copilot removed."] remoteExec ["systemChat", _player];
    [false] remoteExec ["FADE_receiveCopilotState", _player];
};

// -----------------------------------------------------------------------------
// Mission streams: Global (1 at a time, heavy) vs Single (up to 3, lighter). All locations >= 2 km apart.
// -----------------------------------------------------------------------------
FADE_globalMissionTypes = ["AreaOfOperations", "Hostage", "HVT", "ClearArea", "CAS", "InterceptConvoy"];
FADE_singleMissionTypes = ["TroopInsert", "TroopExtract", "Cargo", "MineClearing", "FindClearIEDs", "Medical", "MedicalKAT", "MASCAS", "MASCASKAT"];
FADE_minDistBetweenMissions = 2000;
missionNamespace setVariable ["FADE_globalMission", []];
missionNamespace setVariable ["FADE_singleMissions", []];
publicVariable "FADE_globalMission";
publicVariable "FADE_singleMissions";
publicVariable "FADE_globalMissionTypes";
publicVariable "FADE_singleMissionTypes";
publicVariable "FADE_minDistBetweenMissions";

// Mission owner check supports respawned player objects via UID fallback.
FADE_isMissionEntryOwnedByPlayer = {
    params ["_entry", "_player"];
    if (isNull _player || { !(_entry isEqualType []) }) exitWith { false };
    private _entryOwnerObj = _entry param [1, objNull];
    private _entryOwnerUid = _entry param [3, ""];
    private _playerUid = getPlayerUID _player;
    (_entryOwnerObj == _player) || { _entryOwnerUid != "" && { _entryOwnerUid == _playerUid } }
};

// Notify all other players (systemChat) when a mission starts; requester gets detailed hint only
FADE_notifyOthersMissionStarted = {
    params ["_player", "_missionDisplayName"];
    private _others = allPlayers select { !isNull _x && { _x != _player } };
    { [format ["%1 spawned %2 - see your task list for details.", name _player, _missionDisplayName]] remoteExec ["systemChat", _x] } forEach _others;
};

// Returns true if _pos is at least FADE_minDistBetweenMissions from global and all single mission positions
FADE_missionPosClear = {
    params ["_pos"];
    if (count _pos < 2) exitWith { false };
    private _minDist = missionNamespace getVariable ["FADE_minDistBetweenMissions", 2000];
    private _global = missionNamespace getVariable ["FADE_globalMission", []];
    if (count _global >= 3) then {
        if ((_global select 2) distance _pos < _minDist) exitWith { false };
    };
    private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
    {
        if (count (_x select 2) >= 2 && { ((_x select 2) distance _pos) < _minDist }) exitWith { false };
    } forEach _singleList;
    true;
};

// -----------------------------------------------------------------------------
// Start mission (server). Global: 1 at a time. Single: up to 3. Locations >= 2 km apart.
// -----------------------------------------------------------------------------
FADE_startMission = {
    params ["_missionType", "_player", ["_friendlyFaction", ""], ["_enemyFaction", ""], ["_civFaction", ""]];
    if (isNull _player) exitWith {};
    private _playerUid = getPlayerUID _player;
    private _isGlobal = _missionType in (missionNamespace getVariable ["FADE_globalMissionTypes", []]);
    private _isSingle = _missionType in (missionNamespace getVariable ["FADE_singleMissionTypes", []]);
    if (!_isGlobal && { !_isSingle }) exitWith {
        [format ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Unknown mission type.</t>"] ] remoteExec ["FADE_showMissionHint", _player];
    };
    // Player may only have one mission (global or one single)
    private _global = missionNamespace getVariable ["FADE_globalMission", []];
    private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
    if ((count _global >= 1 && { [_global, _player] call FADE_isMissionEntryOwnedByPlayer }) || { { [_x, _player] call FADE_isMissionEntryOwnedByPlayer } count _singleList > 0 }) exitWith {
        ["<t size='1.2' color='#FFAA00'>MISSION ACTIVE</t><br/><br/><t color='#E0E0E0'>You already have a mission. Abort it first to start another.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    if (_isGlobal && { count _global >= 1 }) exitWith {
        [format ["<t size='1.2' color='#FFAA00'>GLOBAL MISSION ACTIVE</t><br/><br/><t color='#E0E0E0'>A global mission is in progress. Abort it first to start another.</t>"] ] remoteExec ["FADE_showMissionHint", _player];
    };
    if (_isSingle && { count _singleList >= 3 }) exitWith {
        ["<t size='1.2' color='#FFAA00'>SINGLE SLOTS FULL</t><br/><br/><t color='#E0E0E0'>Three single missions are active. Wait for one to finish.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _needsLZ = _missionType in ["TroopInsert", "TroopExtract", "Cargo"];
    private _spawnsEnemies = _missionType in ["TroopExtract", "CAS", "HVT", "Hostage", "ClearArea", "InterceptConvoy", "AreaOfOperations"];
    private _minDistForPos = if (_spawnsEnemies) then { 1000 } else { FADE_minDistFromBase };
    private _destPos = [];
    private _attempt = 0;
    private _maxAttempts = 25;
    while { _attempt < _maxAttempts } do {
        _attempt = _attempt + 1;
        if (_missionType == "InterceptConvoy") then {
            _destPos = [0, 0, 0];
        } else {
            if (_missionType == "HVT" || { _missionType == "Hostage" }) then {
                _destPos = [_minDistForPos] call FADE_findMissionPosUrban;
            } else {
                if (_missionType == "ClearArea" || { _missionType == "AreaOfOperations" }) then {
                    private _candidate = [_minDistForPos] call FADE_findMissionPos;
                    if (count _candidate >= 2) then { _destPos = _candidate };
                } else {
                    if (_missionType == "FindClearIEDs") then {
                        _destPos = [] call (missionNamespace getVariable ["FADE_findMissionPosIED", { [0,0,0] }]);
                    } else {
                        if (_missionType in ["Medical", "MedicalKAT", "MASCAS", "MASCASKAT"]) then {
                            private _medObj = missionNamespace getVariable ["MEDICAL_1", objNull];
                            if (!isNull _medObj) then { _destPos = getPosATL _medObj };
                            if (count _destPos < 2) then { _destPos = [] };
                        } else {
                            private _candidate = [_minDistForPos] call FADE_findMissionPos;
                            if (count _candidate >= 2) then {
                                if (_needsLZ) then { _destPos = [_candidate] call FADE_findSafeLZ } else { _destPos = _candidate };
                            };
                        };
                    };
                };
            };
        };
        if (count _destPos >= 2 && { _missionType == "InterceptConvoy" || { [_destPos] call FADE_missionPosClear } }) exitWith {};
    };
    if (count _destPos < 2 && { _missionType != "InterceptConvoy" } && { _missionType != "AreaOfOperations" }) exitWith {
        private _msg = if (_missionType == "HVT" || { _missionType == "Hostage" }) then {
            "NO VALID URBAN AREA. PLACE CIV_T_* TRIGGERS IN TOWNS."
        } else {
            if (_missionType in ["Medical", "MedicalKAT", "MASCAS", "MASCASKAT"]) then {
                "MEDICAL_1 NOT FOUND IN EDEN."
            } else {
                if (_needsLZ) then { "NO VALID LZ. CLEAR OF OBSTACLES REQUIRED. TRY AGAIN." } else { "NO VALID POSITION (or too close to other missions). TRY AGAIN." }
            }
        };
        [format ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>%1</t>", _msg]] remoteExec ["FADE_showMissionHint", _player];
    };
    if (count _destPos >= 2 && { !([_destPos] call FADE_missionPosClear) } && { _missionType != "InterceptConvoy" }) exitWith {
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No position at least 2 km from other missions. Try again.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    if (_isGlobal) then {
        missionNamespace setVariable ["FADE_globalMission", [_missionType, _player, _destPos, _playerUid]];
        missionNamespace setVariable ["FADE_currentMissionType", _missionType];
        missionNamespace setVariable ["FADE_currentMissionPlayer", _player];
        publicVariable "FADE_globalMission";
        publicVariable "FADE_currentMissionType";
    } else {
        _singleList pushBack [_missionType, _player, _destPos, _playerUid];
        missionNamespace setVariable ["FADE_singleMissions", _singleList];
        publicVariable "FADE_singleMissions";
    };
    // Spawn + compile (not execVM): avoids FADE_missionParams being overwritten by another
    // player's FADE_startMission before this Missions.sqf run reads line 1.
    [_missionType, _destPos, _player] spawn {
        params ["_missionType", "_destPos", "_player"];
        FADE_missionParams = [_missionType, _destPos, _player];
        call compile preprocessFileLineNumbers "rsc\Missions.sqf";
    };
};

publicVariable "FADE_spawnHeli";
publicVariable "FADE_despawnVehicle";
publicVariable "FADE_spawnLandVehicle";
publicVariable "FADE_requestVehiclesAtBase";
publicVariable "FADE_setTime";
publicVariable "FADE_setWeather";
publicVariable "FADE_requestCopilotState";
publicVariable "FADE_spawnCopilot";
publicVariable "FADE_removeCopilot";
publicVariable "FADE_startMission";
publicVariable "FADE_abortMission";
publicVariable "FADE_getCargoSeats";

// Helper: clear active mission for a player (removes from Global or Single list).
// Optional _taskIdGuard prevents stale mission threads from clearing a newer mission.
FADE_clearActiveMission = {
    params ["_player", ["_taskIdGuard", ""]];
    if (isNull _player) exitWith {};
    if (_taskIdGuard != "" && { (_player getVariable ["FADE_myMissionTaskId", ""]) != _taskIdGuard }) exitWith {};
    private _playerUid = getPlayerUID _player;
    if (!isNull _player) then {
        _player setVariable ["FADE_myMission", "", true];
        _player setVariable ["FADE_myMissionTaskId", nil, true];
        _player setVariable ["FADE_myMissionMarker", nil, true];
        _player setVariable ["FADE_myMissionMarkerEnd", nil, true];
        _player setVariable ["FADE_myMissionBrief", nil, true];
    };
    private _global = missionNamespace getVariable ["FADE_globalMission", []];
    if (count _global >= 2 && { [_global, _player] call FADE_isMissionEntryOwnedByPlayer }) then {
        missionNamespace setVariable ["FADE_globalMission", []];
        missionNamespace setVariable ["FADE_currentMissionType", ""];
        missionNamespace setVariable ["FADE_currentMissionPlayer", objNull];
        publicVariable "FADE_globalMission";
        publicVariable "FADE_currentMissionType";
    } else {
        private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
        _singleList = _singleList select {
            private _ownerObj = _x param [1, objNull];
            private _ownerUid = _x param [3, ""];
            !((_ownerObj == _player) || { _ownerUid != "" && { _ownerUid == _playerUid } })
        };
        missionNamespace setVariable ["FADE_singleMissions", _singleList];
        publicVariable "FADE_singleMissions";
    };
};

// Abort mission owned by _player (Global or Single)
FADE_abortMission = {
    params ["_player"];
    if (isNull _player) exitWith {};
    private _taskId = _player getVariable ["FADE_myMissionTaskId", ""];
    private _markerName = _player getVariable ["FADE_myMissionMarker", ""];
    private _markerNameEnd = _player getVariable ["FADE_myMissionMarkerEnd", ""];
    private _global = missionNamespace getVariable ["FADE_globalMission", []];
    private _isGlobalOwner = count _global >= 2 && { [_global, _player] call FADE_isMissionEntryOwnedByPlayer };
    private _missionType = if (_isGlobalOwner) then { _global select 0 } else { _player getVariable ["FADE_myMission", ""] };
    if (_taskId != "") then { [_taskId, "CANCELED"] call BIS_fnc_taskSetState };
    [_markerName] call FADE_deleteMarkerSafe;
    [_markerNameEnd] call FADE_deleteMarkerSafe;
    private _aoMarkers = missionNamespace getVariable ["FADE_aoMarkers_" + _taskId, []];
    { [_x] call FADE_deleteMarkerSafe } forEach _aoMarkers;
    missionNamespace setVariable ["FADE_aoMarkers_" + _taskId, nil];
    if (_missionType == "AreaOfOperations" && { _taskId != "" }) then {
        private _aoEntities = missionNamespace getVariable ["FADE_aoEntities_" + _taskId, []];
        if (count _aoEntities >= 2) then {
            _aoEntities params ["_aoGroups", "_aoComposition"];
            { if (!isNull _x) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } } forEach _aoGroups;
            { if (!isNull _x) then { deleteVehicle _x } } forEach _aoComposition;
        };
        missionNamespace setVariable ["FADE_aoEntities_" + _taskId, nil];
        missionNamespace setVariable ["FADE_aoAborted_" + _taskId, true];
    };
    if (_missionType in ["Medical", "MedicalKAT", "MASCAS", "MASCASKAT"] && { _taskId != "" }) then {
        private _medUnits = missionNamespace getVariable ["FADE_medUnits_" + _taskId, []];
        { if (!isNull _x) then { deleteVehicle _x } } forEach _medUnits;
        missionNamespace setVariable ["FADE_medUnits_" + _taskId, nil];
    };
    [_player] call FADE_clearActiveMission;
    ["<t size='1.2' color='#B0B0B0'>MISSION ABORTED</t><br/><br/><t color='#E0E0E0'>Mission cancelled.</t>"] remoteExec ["FADE_showMissionHint", _player];
};

// Surrender Challenge debug: set true to show verbose server messages in chat (diag_log always in RPT)
FAC_surrenderChallenge_debug = false;
publicVariable "FAC_surrenderChallenge_debug";

// -----------------------------------------------------------------------------
// Surrender Challenge - server entry point
// -----------------------------------------------------------------------------
// Called via remoteExec from client. MUST be publicVariable so clients can
// invoke it. On dedicated server: clients send [player, target]; server runs
// SurrenderChallenge.sqf. execVM spawns script in new scope; server owns AI
// so disableAI/setBehaviour/doTarget work here. Path uses backslash for
// Windows mission folders; Arma accepts both.
// -----------------------------------------------------------------------------
FAC_surrenderChallenge_start = {
    params ["_player", "_targetUnit", ["_playerDir", -1]];
    if (_playerDir < 0) then { _playerDir = getDir _player };
    diag_log format ["[FAC SurrenderChallenge] Server received request from %1 for target %2", name _player, if (isNull _targetUnit) then {"null"} else {name _targetUnit}];
    [_player, _targetUnit, _playerDir] execVM "rsc\SurrenderChallenge.sqf";
};
publicVariable "FAC_surrenderChallenge_start";

// -----------------------------------------------------------------------------
// Jukebox -- server-side sound source management
// -----------------------------------------------------------------------------
// Mirrors Tequila's serverMode pattern:
//   Hosted (listen server): serverMode = 0  -> say3D runs on ALL machines
//                           (host is also a client with audio context)
//   Dedicated:              serverMode = -2 -> say3D runs on dedicated server
//                           (server owns the locality of the Radio_1 object)
// Called via remoteExec from any client: [_class] remoteExec ["FAC_jukebox_serverPlay", 2]
// Stop:                                  [""]      remoteExec ["FAC_jukebox_serverPlay", 2]
// -----------------------------------------------------------------------------
FAC_jukebox_serverPlay = {
    if (!isServer) exitWith {};
    params [["_song", ""]];

    // Store global now-playing state
    missionNamespace setVariable ["FAC_jukebox_nowPlaying", _song, true];

    // Each client plays its own local playSound3D from Radio_1 position
    [_song] remoteExec ["FAC_jukebox_clientPlay", 0, "FAC_jukebox_JIP"];
};
publicVariable "FAC_jukebox_serverPlay";
