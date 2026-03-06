// =============================================================================
// initServer.sqf — Face's Dynamic Sandbox server init
// =============================================================================
//
// DEDICATED SERVER / LOCality:
// - This file runs ONLY on the server (or host in listen server). if (!isServer) exitWith {}
//   ensures no execution on clients or headless. All spawning, markers, tasks, and
//   scenario state are server-authoritative; weather/time/date sync to clients automatically.
// - remoteExec target 2 = server; _player = requesting client; 0 = all clients.
// - Server-called functions (heliOps_spawnHeli, heliOps_startMission, etc.) must be
//   publicVariable'd so clients (and JIP) can invoke them. Variables clients need
//   (heliOps_heliClasses, heliOps_boards, etc.) are also publicVariable'd for JIP.
// - createMarker/deleteMarker: must run on the machine that created the marker (server).
// =============================================================================

if (!isServer) exitWith {};

// Config — single source of truth (rsc\Config.sqf)
call compile preprocessFileLineNumbers "rsc\Config.sqf";

// -----------------------------------------------------------------------------
// Scenario settings: single-pass CfgVehicles scan (load-time optimisation)
// One iteration builds: heliClasses, landVehicleClasses, and caches for faction
// lookups. getUnitsForFaction / getEnemyVehicles / getCivVehicles use cache.
// -----------------------------------------------------------------------------
heliOps_unitsByFactionSide = createHashMap;   // key "faction_sideNum" -> array of Man classnames
heliOps_enemyVehiclesByFaction = createHashMap; // key faction -> array of vehicle classnames
heliOps_civVehiclesByFaction = createHashMap;   // key faction -> array; "" = generic civ vehicles
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
        private _arr = heliOps_unitsByFactionSide getOrDefault [_key, []];
        _arr pushBack _class;
        heliOps_unitsByFactionSide set [_key, _arr];
    };

    // Helicopter / Plane: for heliOps_heliClasses
    if (_scope >= 2 && { (_class isKindOf "Helicopter") || (_class isKindOf "Plane") }) then {
        private _name = getText (_cfg >> "displayName");
        if (_name == "") then { _name = _class };
        _heliPairs pushBack [_name, _class];
    };

    // LandVehicle (excl. Air): for heliOps_landVehicleClasses and vehicle faction caches
    if (_scope >= 2 && { _class isKindOf "LandVehicle" } && { !(_class isKindOf "Air") }) then {
        private _name = getText (_cfg >> "displayName");
        if (_name == "") then { _name = _class };
        _landPairs pushBack [_name, _class];
        if (_side == 0) then {
            private _arr = heliOps_enemyVehiclesByFaction getOrDefault [_faction, []];
            _arr pushBack _class;
            heliOps_enemyVehiclesByFaction set [_faction, _arr];
        };
        if (_side == 3) then {
            private _arr = heliOps_civVehiclesByFaction getOrDefault [_faction, []];
            _arr pushBack _class;
            heliOps_civVehiclesByFaction set [_faction, _arr];
        };
    };
    // Civilian vehicles scope 0/1: same as above, add by faction
    if (_side == 3 && { _scope < 2 } && { _class isKindOf "LandVehicle" } && { !(_class isKindOf "Air") }) then {
        private _arr = heliOps_civVehiclesByFaction getOrDefault [_faction, []];
        _arr pushBack _class;
        heliOps_civVehiclesByFaction set [_faction, _arr];
    };

    // Ship (enemy only): for CAS vehicle spawns
    if (_scope >= 2 && { _class isKindOf "Ship" } && { !(_class isKindOf "Air") } && { _side == 0 }) then {
        private _arr = heliOps_enemyVehiclesByFaction getOrDefault [_faction, []];
        _arr pushBack _class;
        heliOps_enemyVehiclesByFaction set [_faction, _arr];
    };
} forEach ("true" configClasses (configFile >> "CfgVehicles"));

// Sorted aircraft and land vehicle lists (classnames only)
_heliPairs sort true;
heliOps_heliClasses = _heliPairs apply { _x select 1 };
_landPairs sort true;
heliOps_landVehicleClasses = _landPairs apply { _x select 1 };

// Civilian addon filter: only keep classes from same addon(s) as faction. Avoids mods polluting CIV_F.
// If filter returns empty (e.g. CIV_F vanilla has no addon match), fall back to unfiltered or CIV_F defaults.
heliOps_civ_filterByFactionAddon = {
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
            missionNamespace getVariable ["heliOps_civUnitClasses", ["C_man_1","C_man_1_1_F","C_man_polo_1_F","C_man_polo_2_F","C_man_polo_3_F"]]
        } else {
            missionNamespace getVariable ["heliOps_civRoadVehicleClasses", ["C_Offroad_01_F","C_Hatchback_01_F","C_SUV_01_F","C_Van_01_transport_F"]]
        };
    };
    if (_out isEqualTo []) exitWith { _classes };
    _out
};

// Filter enemy unit classnames to only those that spawn with at least one weapon (avoids unarmed units being confused with civilians).
// HVT is excepted in mission code by stripping weapons after spawn. Returns original list if filter would leave it empty.
heliOps_filterEnemyUnitsArmed = {
    params ["_classes"];
    if (_classes isEqualTo [] || { !(_classes isEqualType []) }) exitWith { _classes };
    private _out = [];
    {
        if (_x isEqualType "" && { isClass (configFile >> "CfgVehicles" >> _x) } && { _x isKindOf "Man" }) then {
            private _weapons = getArray (configFile >> "CfgVehicles" >> _x >> "weapons");
            if (count _weapons > 0) then { _out pushBack _x };
        };
    } forEach _classes;
    if (_out isEqualTo []) then { _classes } else { _out };
};
missionNamespace setVariable ["heliOps_filterEnemyUnitsArmed", heliOps_filterEnemyUnitsArmed];

// Friendly group callsigns for RATEL-style sideChat (e.g. "Bravo 1-2")
heliOps_friendlyCallsignPhonetics = ["Alpha","Bravo","Charlie","Delta","Echo","Foxtrot","Golf","Hotel"];
heliOps_assignGroupCallsign = {
    params ["_group"];
    if (isNull _group) exitWith { "Alpha 1-1" };
    private _cs = _group getVariable ["heliOps_callsign", ""];
    if (_cs != "") exitWith { _cs };
    private _p = selectRandom heliOps_friendlyCallsignPhonetics;
    private _team = 1 + floor random 3;
    private _unit = 1 + floor random 4;
    _cs = format ["%1 %2-%3", _p, _team, _unit];
    _group setVariable ["heliOps_callsign", _cs, true];
    _cs
};
missionNamespace setVariable ["heliOps_assignGroupCallsign", heliOps_assignGroupCallsign];

// Returns array of unit classnames for given faction (Man only).
// East/West/Independent: cache lookup (faction_side).
// Civilian (side 3): CfgGroups + cache fallback, BOTH filtered by faction addon — avoids mod pollution.
heliOps_getUnitsForFaction = {
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
        _out = [_out, _faction, true] call heliOps_civ_filterByFactionAddon;

        // 2) Fallback: cache (units with faction_side), filtered by addon
        if (_out isEqualTo []) then {
            private _key = _faction + "_3";
            private _cached = heliOps_unitsByFactionSide getOrDefault [_key, []];
            if (_cached isEqualTo []) then {
                // Mod faction may use CIV_F in CfgVehicles — scan all civ caches for same-addon units
                { _cached = _cached + (heliOps_unitsByFactionSide getOrDefault [_x, []]) } forEach (keys heliOps_unitsByFactionSide select { count _x >= 2 && { _x select [count _x - 2, 2] == "_3" } });
            };
            _out = [_cached, _faction, true] call heliOps_civ_filterByFactionAddon;
        };
        _out
    } else {
        // For OPFOR/BLUFOR/INDFOR: try CfgGroups first (most reliable for modded factions),
        // then fall back to the CfgVehicles cache. Many modded units have a mismatched or empty
        // `faction` property in CfgVehicles, causing the cache lookup to fail — but CfgGroups
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
            _out = heliOps_unitsByFactionSide getOrDefault [_faction + "_" + str _sideNum, []];
        };

        // 3) For enemy factions (side 0), also check side 2 (Resistance) — some mod OPFOR factions
        //    configure their units as Independent in CfgVehicles but are presented as OPFOR in game
        if (_out isEqualTo [] && { _sideNum == 0 }) then {
            _out = heliOps_unitsByFactionSide getOrDefault [_faction + "_2", []];
        };

        _out
    };
};

// Returns array of enemy vehicle classnames for faction; uses cache
heliOps_getEnemyVehiclesForFaction = {
    params ["_faction"];
    if (_faction == "") exitWith { [] };
    heliOps_enemyVehiclesByFaction getOrDefault [_faction, []]
};

// Returns array of friendly (BLUFOR) vehicle classnames for faction; aircraft + land. Same logic as enemy — faction from config.
heliOps_getFriendlyVehicleClasses = {
    params ["_faction"];
    if (_faction == "") exitWith { [] };
    private _all = (heliOps_heliClasses + heliOps_landVehicleClasses);
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
// CfgGroups first, then cache — BOTH filtered by faction addon.
heliOps_getCivVehiclesForFaction = {
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
    _out = [_out, _faction, false] call heliOps_civ_filterByFactionAddon;
    if (_out isEqualTo []) then {
        private _byFaction = heliOps_civVehiclesByFaction getOrDefault [_faction, []];
        private _cached = if (count _byFaction > 0) then { _byFaction } else {
            private _all = [];
            { _all = _all + (heliOps_civVehiclesByFaction getOrDefault [_x, []]) } forEach (keys heliOps_civVehiclesByFaction);
            _all
        };
        _out = [_cached, _faction, false] call heliOps_civ_filterByFactionAddon;
    };
    private _seen = createHashMap;
    { _seen set [_x, true] } forEach _out;
    keys _seen
};

// Apply scenario settings from GUI — SERVER-SIDE GLOBAL: all mission spawns use these unit/vehicle lists.
// When a player clicks Apply, this runs on the server and overwrites missionNamespace; Missions.sqf (and other scripts) read from missionNamespace.
heliOps_applyScenarioSettings = {
    params ["_hour", "_weather", "_enemyFaction", "_friendlyFaction", "_civFaction", ["_limitGear", false], ["_player", objNull], ["_patrolsEnabled", false]];
    _hour = (_hour max 0) min 23;
    missionNamespace setVariable ["heliOps_scenarioTime", _hour];
    missionNamespace setVariable ["heliOps_scenarioWeather", _weather];
    missionNamespace setVariable ["heliOps_scenarioEnemyFaction", _enemyFaction, true];
    missionNamespace setVariable ["heliOps_scenarioFriendlyFaction", _friendlyFaction, true];
    missionNamespace setVariable ["heliOps_scenarioCivFaction", _civFaction, true];
    missionNamespace setVariable ["heliOps_limitGearToFriendlyFaction", _limitGear];
    missionNamespace setVariable ["heliOps_scenarioPatrols", _patrolsEnabled];

    // Build unit/vehicle arrays from chosen factions — these are the single source for all mission spawns
    private _enemyUnits = [_enemyFaction, 0] call heliOps_getUnitsForFaction;
    private _friendlyUnits = [_friendlyFaction, 1] call heliOps_getUnitsForFaction;
    private _civUnits = [_civFaction, 3] call heliOps_getUnitsForFaction;
    private _civVehicles = [_civFaction] call heliOps_getCivVehiclesForFaction;

    if (_enemyUnits isEqualTo []) then { _enemyUnits = ["O_Soldier_TL_F", "O_Soldier_F", "O_Soldier_AR_F"] };
    if (_friendlyUnits isEqualTo []) then { _friendlyUnits = ["B_Soldier_TL_F", "B_Soldier_F", "B_Soldier_AR_F", "B_medic_F"] };
    _enemyUnits = [_enemyUnits] call heliOps_filterEnemyUnitsArmed;
    // Civs: NO fallbacks — AmbientCivilians uses GUI faction only; if empty, shows hint

    private _enemyVehicles = [_enemyFaction] call heliOps_getEnemyVehiclesForFaction;
    private _friendlyVehicleClasses = [_friendlyFaction] call heliOps_getFriendlyVehicleClasses;
    missionNamespace setVariable ["heliOps_enemyUnits", _enemyUnits];
    missionNamespace setVariable ["heliOps_enemyVehicles", _enemyVehicles];
    missionNamespace setVariable ["heliOps_friendlyUnits", _friendlyUnits];
    missionNamespace setVariable ["heliOps_friendlyVehicleClasses", _friendlyVehicleClasses];
    missionNamespace setVariable ["heliOps_civUnitClasses", _civUnits];
    missionNamespace setVariable ["heliOps_civRoadVehicleClasses", _civVehicles];
    missionNamespace setVariable ["heliOps_civParkedVehicleClasses", _civVehicles];

    // Despawn all active civilian zones so next spawn uses new faction
    if (!isNil "heliOps_civZoneState" && { heliOps_civZoneState isEqualType createHashMap }) then {
        { [_x] call heliOps_civ_despawnZone } forEach (keys heliOps_civZoneState);
    };
    // Reset hint flags so user can see "no civs" hint again if new faction has none
    if (!isNil "heliOps_civ_resetHintFlags") then { call heliOps_civ_resetHintFlags };
    // Remove road vehicles (they use old driver classes)
    if (!isNil "heliOps_roadVehicles") then {
        { if (!isNull _x) then { { deleteVehicle _x } forEach (crew _x); deleteVehicle _x } } forEach heliOps_roadVehicles;
        heliOps_roadVehicles = [];
    };

    // Apply time and weather (server authority; syncs to all clients)
    private _date = date;
    setDate [_date select 0, _date select 1, _date select 2, _hour, _date select 4];
    [_weather] call heliOps_applyWeatherPreset;

    private _hourStr = (if (_hour < 10) then { "0" } else { "" }) + str _hour + "00";
    private _enemyDn = getText (configFile >> "CfgFactionClasses" >> _enemyFaction >> "displayName");
    if (_enemyDn == "") then { _enemyDn = _enemyFaction };
    private _friendlyDn = getText (configFile >> "CfgFactionClasses" >> _friendlyFaction >> "displayName");
    if (_friendlyDn == "") then { _friendlyDn = _friendlyFaction };
    private _civDn = getText (configFile >> "CfgFactionClasses" >> _civFaction >> "displayName");
    if (_civDn == "") then { _civDn = _civFaction };
    private _hintText = format [
        "<t size='1.3' color='#4A90D9' align='center'>SCENARIO UPDATED</t><br/><br/>" +
        "<t size='1.0' color='#E8E8E8'>Time:</t> <t color='#B0D0FF'>%1 ZULU</t><br/>" +
        "<t size='1.0' color='#E8E8E8'>Weather:</t> <t color='#B0D0FF'>%2</t><br/><br/>" +
        "<t size='1.0' color='#E8E8E8'>Enemy:</t> <t color='#FFB0B0'>%3</t><br/>" +
        "<t size='1.0' color='#E8E8E8'>Friendly:</t> <t color='#B0FFB0'>%4</t><br/>" +
        "<t size='1.0' color='#E8E8E8'>Civilian:</t> <t color='#FFE0B0'>%5</t><br/>" +
        "<t size='1.0' color='#E8E8E8'>Patrols:</t> <t color='#E0E0E0'>%6</t>",
        _hourStr, _weather, _enemyDn, _friendlyDn, _civDn, if (_patrolsEnabled) then { "ON" } else { "OFF" }
    ];
    [_hintText] remoteExec ["FAC_heliOps_showMissionHint", 0];
    // Sync scenario config to clients so Loadout/Vehicle GUIs can respect limit gear
    [_friendlyFaction, _limitGear] remoteExec ["FAC_heliOps_syncScenarioConfig", 0, true];
    publicVariable "heliOps_friendlyUnits";
    publicVariable "heliOps_friendlyVehicleClasses";
};
heliOps_sendScenarioConfigToClient = {
    params ["_player"];
    if (isNull _player) exitWith {};
    private _f = missionNamespace getVariable ["heliOps_scenarioFriendlyFaction", "BLU_F"];
    private _l = missionNamespace getVariable ["heliOps_limitGearToFriendlyFaction", false];
    [_f, _l] remoteExec ["FAC_heliOps_syncScenarioConfig", _player];
};
publicVariable "heliOps_applyScenarioSettings";
publicVariable "heliOps_sendScenarioConfigToClient";
publicVariable "heliOps_getUnitsForFaction";
publicVariable "heliOps_getEnemyVehiclesForFaction";
publicVariable "heliOps_getCivVehiclesForFaction";

// Initial build: scenario unit/vehicle lists on missionNamespace (server). Scenario GUI Apply overwrites these; all mission spawns read from here.
private _enemyF = missionNamespace getVariable ["heliOps_scenarioEnemyFaction", "OPF_F"];
private _friendlyF = missionNamespace getVariable ["heliOps_scenarioFriendlyFaction", "BLU_F"];
private _civF = missionNamespace getVariable ["heliOps_scenarioCivFaction", "CIV_F"];
missionNamespace setVariable ["heliOps_scenarioEnemyFaction", _enemyF, true];
missionNamespace setVariable ["heliOps_scenarioFriendlyFaction", _friendlyF, true];
missionNamespace setVariable ["heliOps_scenarioCivFaction", _civF, true];
private _defEnemy = [_enemyF, 0] call heliOps_getUnitsForFaction;
private _defFriendly = [_friendlyF, 1] call heliOps_getUnitsForFaction;
private _defCiv = [_civF, 3] call heliOps_getUnitsForFaction;
private _defCivVeh = [_civF] call heliOps_getCivVehiclesForFaction;
if (_defEnemy isEqualTo []) then { _defEnemy = ["O_Soldier_TL_F", "O_Soldier_F", "O_Soldier_AR_F"] };
if (_defFriendly isEqualTo []) then { _defFriendly = ["B_Soldier_TL_F", "B_Soldier_F", "B_Soldier_AR_F", "B_medic_F"] };
if (_defCiv isEqualTo []) then { _defCiv = ["C_man_1", "C_man_1_1_F", "C_man_polo_1_F"] };
if (_defCivVeh isEqualTo []) then { _defCivVeh = ["C_Offroad_01_F", "C_Hatchback_01_F", "C_SUV_01_F", "C_Van_01_transport_F"] };
_defEnemy = [_defEnemy] call heliOps_filterEnemyUnitsArmed;
private _defFriendlyVeh = [_friendlyF] call heliOps_getFriendlyVehicleClasses;
missionNamespace setVariable ["heliOps_enemyUnits", _defEnemy];
missionNamespace setVariable ["heliOps_friendlyUnits", _defFriendly];
missionNamespace setVariable ["heliOps_friendlyVehicleClasses", _defFriendlyVeh];
missionNamespace setVariable ["heliOps_civUnitClasses", _defCiv];
private _defEnemyVeh = [_enemyF] call heliOps_getEnemyVehiclesForFaction;
missionNamespace setVariable ["heliOps_enemyVehicles", _defEnemyVeh];
missionNamespace setVariable ["heliOps_civRoadVehicleClasses", _defCivVeh];
missionNamespace setVariable ["heliOps_civParkedVehicleClasses", _defCivVeh];

// -----------------------------------------------------------------------------
// Reusable: apply weather preset by name. Syncs to all clients (server authority).
// Call only on server. forceWeatherChange applies immediately; rain needs overcast >= 0.7.
// -----------------------------------------------------------------------------
heliOps_applyWeatherPreset = {
    params ["_preset"];
    switch _preset do {
        case "Clear": { 0 setOvercast 0; 0 setRain 0; 0 setFog [0, 0, 0]; forceWeatherChange; };
        case "Overcast": { 0 setOvercast 0.5; 0 setRain 0; 0 setFog [0, 0, 0]; forceWeatherChange; };
        case "Foggy": { 0 setOvercast 0.3; 0 setRain 0; 0 setFog [0.5, 0.01, 0]; forceWeatherChange; };
        case "Rain": { 0 setOvercast 0.8; 0 setRain 0.5; 0 setFog [0.1, 0.01, 0]; forceWeatherChange; };
        case "Storm": { 0 setOvercast 1; 0 setRain 1; 0 setFog [0.2, 0.01, 0]; forceWeatherChange; };
        default {};
    };
};

// Apply initial time and weather from Config (server; syncs to clients)
private _initHour = missionNamespace getVariable ["heliOps_scenarioTime", 12];
private _initWeather = missionNamespace getVariable ["heliOps_scenarioWeather", "Clear"];
private _date = date;
setDate [_date select 0, _date select 1, _date select 2, _initHour, _date select 4];
[_initWeather] call heliOps_applyWeatherPreset;

// Ambient civilians (CIV_T_*, ROAD_SP_*)
[] execVM "rsc\AmbientCivilians.sqf";

// Helper: collect Eden objects by variable name
heliOps_collectEdenNames = {
    params ["_names"];
    _names apply { missionNamespace getVariable [_x, objNull] } select { !isNull _x }
};

// Pads: array of [object, padName] for spawn logic (planes excluded from HP_1, HP_2)
heliOps_helipadList = [];
{
    private _obj = missionNamespace getVariable [_x, objNull];
    if (!isNull _obj) then { heliOps_helipadList pushBack [_obj, _x] };
} forEach (missionNamespace getVariable ["heliOps_padNames", ["HP_1","HP_2","HP_3"]]);
heliOps_helipads = heliOps_helipadList apply { _x select 0 };  // objects only (for base pos, etc.)
heliOps_boards = [["BOARD_1","BOARD_2","BOARD_3"]] call heliOps_collectEdenNames;
// Apply custom image to main board (BOARD_1 — Land_MapBoard_01_Wall_F) so all clients see it
private _mainBoard = heliOps_boards param [0, objNull];
if (!isNull _mainBoard && { count (getObjectTextures _mainBoard) > 0 }) then {
    _mainBoard setObjectTextureGlobal [0, "img\board1b.jpg"];
};
if (!isNull BOARD_2 && { count (getObjectTextures BOARD_2) > 0 }) then {
    BOARD_2 setObjectTextureGlobal [0, "img\board2.jpg"];
};
if (!isNull BOARD_2b && { count (getObjectTextures BOARD_2b) > 0 }) then {
    BOARD_2b setObjectTextureGlobal [0, "img\board2.jpg"];
};
if (!isNull BOARD_3 && { count (getObjectTextures BOARD_3) > 0 }) then {
    BOARD_3 setObjectTextureGlobal [0, "img\loadingb.jpg"];
};
heliOps_loadoutBox = missionNamespace getVariable ["LOADOUTBOX", objNull];
heliOps_loadoutBox2 = missionNamespace getVariable ["LOADOUTBOX_2", objNull];
heliOps_bSpPoints = [["B_SP_1","B_SP_2","B_SP_3"]] call heliOps_collectEdenNames;

// ACE Arsenal: init LOADOUTBOX / LOADOUTBOX_2 if ACE is loaded
if (!isNull heliOps_loadoutBox && { isClass (configFile >> "CfgPatches" >> "ace_arsenal") }) then {
    [heliOps_loadoutBox, true, true] call ace_arsenal_fnc_initBox;  // true = full arsenal, true = global
};
if (!isNull heliOps_loadoutBox2 && { isClass (configFile >> "CfgPatches" >> "ace_arsenal") }) then {
    [heliOps_loadoutBox2, true, true] call ace_arsenal_fnc_initBox;
};

// heliOps_heliClasses and heliOps_landVehicleClasses already built in single-pass scan above

// Vehicle spawn points (VEH_1, VEH_2) for land vehicles
heliOps_vehiclePoints = [["VEH_1", "VEH_2"]] call heliOps_collectEdenNames;

// Store original helipad marker text (for restore when pad emptied)
heliOps_padMarkerOriginalText = [];
{
    private _mrkName = (missionNamespace getVariable ["heliOps_helipadMarkers", []]) param [_forEachIndex, ""];
    if (_mrkName != "" && { getMarkerColor _mrkName != "" }) then {
        private _txt = markerText _mrkName;
        heliOps_padMarkerOriginalText set [_forEachIndex, if (_txt != "") then { _txt } else { format ["Pad %1", _forEachIndex + 1] }];
    };
} forEach heliOps_helipadList;

// Base position — from BASE_1 (centre of map), fallback to helipad or B_SP
private _baseObj = missionNamespace getVariable ["BASE_1", objNull];
if (!isNull _baseObj) then {
    heliOps_basePos = getPosATL _baseObj;
} else {
    if (count heliOps_helipads > 0) then {
        heliOps_basePos = getPosATL (heliOps_helipads select 0);
    } else {
        if (count heliOps_bSpPoints > 0) then {
            heliOps_basePos = position (heliOps_bSpPoints select 0);
        } else {
            heliOps_basePos = [5000, 5000, 0];
        };
    };
};

// Map bounds for mission spawns (min/max X and Y)
heliOps_mapMin = 500;
heliOps_mapMax = 9500;
heliOps_minDistFromBase = 700;

// -----------------------------------------------------------------------------
// Reusable: delete marker only if it exists (avoids "marker not found" in RPT).
// Markers are global; must be deleted on the same machine that created them (server).
// -----------------------------------------------------------------------------
heliOps_deleteMarkerSafe = {
    params ["_markerName"];
    if (_markerName != "" && { getMarkerColor _markerName != "" }) then { deleteMarker _markerName };
};

// Find mission position in urban areas only (civ zones). Returns [] if no civ zones.
// Params: [["_minDistOverride", -1]]
heliOps_findMissionPosUrban = {
    params [["_minDistOverride", -1]];
    private _base = heliOps_basePos;
    private _minDist = if (_minDistOverride > 0) then { _minDistOverride } else { heliOps_minDistFromBase };
    private _minXY = heliOps_mapMin;
    private _maxXY = heliOps_mapMax;
    private _civZoneRadius = 2500;
    private _civZones = missionNamespace getVariable ["heliOps_civTriggerNames", []];
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
heliOps_findMissionPosUrbanNearCenter = {
    params [["_minDistOverride", -1]];
    private _base = heliOps_basePos;
    private _minDist = if (_minDistOverride > 0) then { _minDistOverride } else { heliOps_minDistFromBase };
    private _minXY = heliOps_mapMin;
    private _maxXY = heliOps_mapMax;
    private _civZones = missionNamespace getVariable ["heliOps_civTriggerNames", []];
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

// Find a valid mission position: near a civ zone (CIV_T_*), within 2.5km of zone center,
// at least _minDistOverride (or heliOps_minDistFromBase) from base, clear ground, not on water.
// Params: [["_minDistOverride", -1]] — if > 0, use instead of heliOps_minDistFromBase (e.g. 1000 for enemy missions)
heliOps_findMissionPos = {
    params [["_minDistOverride", -1]];
    private _base = heliOps_basePos;
    private _minDist = if (_minDistOverride > 0) then { _minDistOverride } else { heliOps_minDistFromBase };
    private _minXY = heliOps_mapMin;
    private _maxXY = heliOps_mapMax;
    private _civZoneRadius = 2500;
    private _result = [];
    private _attempt = 0;
    private _civZones = missionNamespace getVariable ["heliOps_civTriggerNames", []];

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
// Params: [_center] — center position to search around
// Returns: position array or [] if none found
heliOps_findSafeLZ = {
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

// Base respawn marker (required by respawn template "Base" for BLUFOR)
private _baseMrk = createMarker ["respawn_west", heliOps_basePos];
_baseMrk setMarkerType "mil_flag";
_baseMrk setMarkerColor "ColorBLUFOR";
_baseMrk setMarkerText "Base";

publicVariable "heliOps_heliClasses";
publicVariable "heliOps_landVehicleClasses";
publicVariable "heliOps_friendlyUnits";
publicVariable "heliOps_friendlyVehicleClasses";
publicVariable "heliOps_vehiclePoints";
publicVariable "heliOps_helipads";
publicVariable "heliOps_boards";
publicVariable "heliOps_loadoutBox";
publicVariable "heliOps_loadoutBox2";
publicVariable "heliOps_basePos";
publicVariable "heliOps_bSpPoints";
publicVariable "heliOps_mapMin";
publicVariable "heliOps_mapMax";

// -----------------------------------------------------------------------------
// Update helipad markers to show vehicle on pad (aircraft only, not ground vehicles).
// heliOps_padMarkerOriginalText is populated above; do not reset it here.
// -----------------------------------------------------------------------------
heliOps_updateHelipadMarkers = {
    private _markers = missionNamespace getVariable ["heliOps_helipadMarkers", []];
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
            private _orig = heliOps_padMarkerOriginalText param [_padIdx, ""];
            if (_orig == "") then { _orig = format ["Pad %1", _padIdx + 1] };
            _mrkName setMarkerText _orig;
        };
    } forEach heliOps_helipadList;
};

// Periodic pad marker update — detects when aircraft leave pads (e.g. take off)
[] spawn {
    while { true } do {
        sleep 4;
        if (count (missionNamespace getVariable ["heliOps_helipadMarkers", []]) > 0) then {
            call heliOps_updateHelipadMarkers;
        };
    };
};

// -----------------------------------------------------------------------------
// Spawn helicopter (server). Called via remoteExec from client Vehicle GUI.
// Validates class and pad availability; creates vehicle on server; feedback via remoteExec to _player.
// -----------------------------------------------------------------------------
heliOps_spawnHeli = {
    params ["_heliClass", "_player"];
    if (isNil "_heliClass" || { _heliClass == "" }) exitWith {
        ["INVALID AIRCRAFT CLASS."] remoteExec ["systemChat", _player];
    };
    if (count heliOps_helipadList == 0) exitWith {
        ["NO PADS AVAILABLE."] remoteExec ["systemChat", _player];
    };

    // Planes cannot spawn at HP_1, HP_2; helicopters can use any pad
    private _isPlane = _heliClass isKindOf "Plane";
    private _forbidden = missionNamespace getVariable ["heliOps_planeForbiddenPads", []];
    private _candidatePads = heliOps_helipadList select {
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
    private _padNum = (heliOps_helipadList findIf { (_x select 0) == _pad }) + 1;
    private _padDisplay = format ["Pad %1", _padNum];
    [format ["%1 SPAWNED AT %2.", _displayName, _padDisplay]] remoteExec ["systemChat", _player];
    call heliOps_updateHelipadMarkers;
};

// -----------------------------------------------------------------------------
// Despawn any vehicle (server)
// -----------------------------------------------------------------------------
heliOps_despawnVehicle = {
    params ["_veh", "_player"];
    if (isNull _veh) exitWith { ["INVALID VEHICLE."] remoteExec ["systemChat", _player] };
    private _dist = (getPosATL _veh) distance heliOps_basePos;
    if (_dist > 1000) exitWith { ["VEHICLE MUST BE WITHIN 1000M OF BASE TO DESPAWN."] remoteExec ["systemChat", _player] };
    // Eject all crew (players and AI) before despawning
    private _crew = crew _veh;
    { if (isPlayer _x) then { moveOut _x } else { _veh deleteVehicleCrew _x } } forEach _crew;
    deleteVehicle _veh;
    ["VEHICLE DESPAWNED."] remoteExec ["systemChat", _player];
    if (_veh isKindOf "Air") then { call heliOps_updateHelipadMarkers };
};

// -----------------------------------------------------------------------------
// Spawn land vehicle at VEH_1 or VEH_2 using BIS_fnc_findSafePosition
// -----------------------------------------------------------------------------
heliOps_spawnLandVehicle = {
    params ["_vehicleClass", "_player"];
    if (isNil "_vehicleClass" || { _vehicleClass == "" }) exitWith {
        ["INVALID VEHICLE CLASS."] remoteExec ["systemChat", _player];
    };
    if (!isClass (configFile >> "CfgVehicles" >> _vehicleClass)) exitWith {
        [format ["UNKNOWN VEHICLE CLASS: %1", _vehicleClass]] remoteExec ["systemChat", _player];
    };
    if (count heliOps_vehiclePoints == 0) exitWith {
        ["NO VEH SPAWN POINTS. CONFIGURE VEH_1/2 IN EDEN."] remoteExec ["systemChat", _player];
    };

    // Pick a spawn point (alternate or random)
    private _centerObj = selectRandom heliOps_vehiclePoints;
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
    private _vehIdx = heliOps_vehiclePoints find _centerObj;
    private _padDisplay = if (_vehIdx >= 0) then { format ["VEH %1", _vehIdx + 1] } else { "vehicle spawn" };
    [format ["%1 SPAWNED AT %2.", _displayName, _padDisplay]] remoteExec ["systemChat", _player];
};

// -----------------------------------------------------------------------------
// Return list of all vehicles at base with pad/location info [[vehicle, padDisplayName], ...]
// -----------------------------------------------------------------------------
heliOps_requestVehiclesAtBase = {
    params ["_player"];
    if (isNull _player) exitWith {};
    private _pos = heliOps_basePos;
    if (_pos isEqualType objNull) then { _pos = getPosATL _pos };
    private _near = nearestObjects [_pos, ["Air", "LandVehicle"], 1000];
    private _result = [];
    {
        if (!isNull _x && { alive _x }) then {
            private _vPos = getPosATL _x;
            private _padName = "";
            if (_x isKindOf "Air") then {
                { _x params ["_padObj", "_padId"]; if ((getPosATL _padObj) distance _vPos <= 10) exitWith { _padName = format ["Pad %1", (_forEachIndex + 1)] } } forEach heliOps_helipadList;
            } else {
                { private _p = getPosATL _x; if (_vPos distance _p <= 15) exitWith { _padName = format ["VEH %1", (_forEachIndex + 1)] } } forEach heliOps_vehiclePoints;
            };
            if (_padName == "") then { _padName = "Base" };
            _result pushBack [_x, _padName];
        };
    } forEach _near;
    [_result] remoteExec ["heliOps_receiveVehiclesAtBase", _player];
};

// -----------------------------------------------------------------------------
// Get cargo (passenger) seat count for a vehicle class
// -----------------------------------------------------------------------------
heliOps_getCargoSeats = {
    params ["_vehicleClass"];
    if (_vehicleClass isEqualType objNull) then { _vehicleClass = typeOf _vehicleClass };
    if (isNil "_vehicleClass" || { _vehicleClass == "" }) exitWith { 6 };
    if (!isClass (configFile >> "CfgVehicles" >> _vehicleClass)) exitWith { 6 };
    private _total = [_vehicleClass, true] call BIS_fnc_crewCount;
    private _crew = [_vehicleClass, false] call BIS_fnc_crewCount;
    ((_total - _crew) max 1) min 24
};

// -----------------------------------------------------------------------------
// Time & weather (server) — syncs to all clients in MP
// -----------------------------------------------------------------------------
heliOps_setTime = {
    params ["_hour", "_player"];
    _hour = (_hour max 0) min 23;
    private _date = date;
    setDate [_date select 0, _date select 1, _date select 2, _hour, _date select 4];
    [format ["TIME SET %1:00 ZULU.", _hour]] remoteExec ["systemChat", _player];
};

heliOps_setWeather = {
    params ["_preset", "_player"];
    if !(_preset in ["Clear", "Overcast", "Foggy", "Rain", "Storm"]) exitWith {
        ["UNKNOWN WEATHER PRESET."] remoteExec ["systemChat", _player];
    };
    [_preset] call heliOps_applyWeatherPreset;
    [format ["WEATHER SET: %1.", _preset]] remoteExec ["systemChat", _player];
};

// -----------------------------------------------------------------------------
// Start mission (server) — one mission per player at a time. Called via remoteExec from Missions GUI.
// Uses server's scenario config (unit/vehicle lists from Scenario Apply); does not trust client-passed factions.
// Sets heliOps_missionParams and execVMs Missions.sqf; Missions.sqf runs on server and spawns all entities.
// -----------------------------------------------------------------------------
heliOps_startMission = {
    params ["_missionType", "_player", ["_friendlyFaction", ""], ["_enemyFaction", ""], ["_civFaction", ""]];
    if (isNull _player) exitWith {};
    // Use server's scenario config (set by Scenario GUI apply). Do NOT overwrite with client-passed
    // values — client missionNamespace is not synced, so it would have stale/defaults.
    private _needsLZ = _missionType in ["TroopInsert", "TroopExtract", "Cargo"];
    private _spawnsEnemies = _missionType in ["TroopExtract", "CAS", "HVT", "Hostage", "ClearArea", "InterceptConvoy"];
    private _minDistForPos = if (_spawnsEnemies) then { 1000 } else { heliOps_minDistFromBase };
    private _destPos = [];
    private _attempt = 0;
    if (_missionType == "InterceptConvoy") then {
        _destPos = [0, 0, 0];
    } else {
    if (_missionType == "HVT" || { _missionType == "Hostage" }) then {
        while { _attempt < 20 } do {
            _attempt = _attempt + 1;
            _destPos = [_minDistForPos] call heliOps_findMissionPosUrban;
            if (count _destPos >= 2) exitWith {};
        };
    } else {
        if (_missionType == "ClearArea") then {
            while { _attempt < 20 } do {
                _attempt = _attempt + 1;
                private _candidate = [_minDistForPos] call heliOps_findMissionPos;
                if (count _candidate >= 2) then { _destPos = _candidate };
                if (count _destPos >= 2) exitWith {};
            };
        } else {
        while { _attempt < 20 } do {
            _attempt = _attempt + 1;
            private _candidate = [_minDistForPos] call heliOps_findMissionPos;
            if (count _candidate == 0) exitWith {};
            if (_needsLZ) then {
                _destPos = [_candidate] call heliOps_findSafeLZ;
            } else {
                _destPos = _candidate;
            };
            if (count _destPos >= 2) exitWith {};
        };
        };
    };
    };
    if (count _destPos < 2 && { _missionType != "InterceptConvoy" }) exitWith {
        private _msg = if (_missionType == "HVT" || { _missionType == "Hostage" }) then {
            "NO VALID URBAN AREA. PLACE CIV_T_* TRIGGERS IN TOWNS."
        } else {
            if (_needsLZ) then {
                "NO VALID LZ. CLEAR OF OBSTACLES REQUIRED. TRY AGAIN."
            } else {
                "NO VALID AO WITHIN MAP BOUNDS."
            }
        };
        [format ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>%1</t>", _msg]] remoteExec ["FAC_heliOps_showMissionHint", _player];
    };

    private _current = _player getVariable ["heliOps_myMission", ""];
    if (_current != "") exitWith {
        [format ["<t size='1.2' color='#FFAA00'>ACTIVE MISSION</t><br/><br/><t color='#E0E0E0'>%1 in progress. Complete or abort first.</t>", _current]] remoteExec ["FAC_heliOps_showMissionHint", _player];
    };

    heliOps_missionParams = [_missionType, _destPos, _player];
    execVM "rsc\Missions.sqf";
};

publicVariable "heliOps_spawnHeli";
publicVariable "heliOps_despawnVehicle";
publicVariable "heliOps_spawnLandVehicle";
publicVariable "heliOps_requestVehiclesAtBase";
publicVariable "heliOps_setTime";
publicVariable "heliOps_setWeather";
publicVariable "heliOps_startMission";
publicVariable "heliOps_abortMission";
publicVariable "heliOps_getCargoSeats";

// Helper: clear active mission for a player (used by Missions.sqf and TroopTransport.sqf)
heliOps_clearActiveMission = {
    params ["_player"];
    if (!isNull _player) then {
        _player setVariable ["heliOps_myMission", "", true];
        _player setVariable ["heliOps_myMissionTaskId", nil, true];
        _player setVariable ["heliOps_myMissionMarker", nil, true];
        _player setVariable ["heliOps_myMissionMarkerEnd", nil, true];
        _player setVariable ["heliOps_myMissionBrief", nil, true];
    };
};

// Abort active mission (called from GUI via remoteExec)
heliOps_abortMission = {
    params ["_player"];
    if (isNull _player) exitWith {};
    private _taskId = _player getVariable ["heliOps_myMissionTaskId", ""];
    private _markerName = _player getVariable ["heliOps_myMissionMarker", ""];
    private _markerNameEnd = _player getVariable ["heliOps_myMissionMarkerEnd", ""];
    if (_taskId != "") then {
        [_taskId, "CANCELED"] call BIS_fnc_taskSetState;
    };
    [_markerName] call heliOps_deleteMarkerSafe;
    [_markerNameEnd] call heliOps_deleteMarkerSafe;
    [_player] call heliOps_clearActiveMission;
    ["<t size='1.2' color='#B0B0B0'>MISSION ABORTED</t><br/><br/><t color='#E0E0E0'>Mission cancelled.</t>"] remoteExec ["FAC_heliOps_showMissionHint", _player];
};

// Surrender Challenge debug: set true to show verbose server messages in chat (diag_log always in RPT)
FAC_surrenderChallenge_debug = false;
publicVariable "FAC_surrenderChallenge_debug";

// -----------------------------------------------------------------------------
// Surrender Challenge — server entry point
// -----------------------------------------------------------------------------
// Called via remoteExec from client. MUST be publicVariable so clients can
// invoke it. On dedicated server: clients send [player, target]; server runs
// SurrenderChallenge.sqf. execVM spawns script in new scope; server owns AI
// so disableAI/setBehaviour/doTarget work here. Path uses backslash for
// Windows mission folders; Arma accepts both.
// -----------------------------------------------------------------------------
FAC_surrenderChallenge_start = {
    params ["_player", "_targetUnit"];
    diag_log format ["[FAC SurrenderChallenge] Server received request from %1 for target %2", name _player, if (isNull _targetUnit) then {"null"} else {name _targetUnit}];
    [_player, _targetUnit] execVM "rsc\SurrenderChallenge.sqf";
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
