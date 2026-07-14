// ServerBootstrapFactions.sqf - CfgVehicles scan, faction caches, launcher policy
FADE_unitsByFactionSide = createHashMap;   // key "faction_sideNum" -> array of Man classnames
FADE_enemyVehiclesByFaction = createHashMap; // key faction -> array of vehicle classnames
FADE_civVehiclesByFaction = createHashMap;   // key faction -> array; "" = generic civ vehicles
private _heliPairs = [];  // [displayName, class] for sort
private _landPairs = [];

private _tCfgVeh0 = if (missionNamespace getVariable ["FADE_profileMissionLoad", false]) then { diag_tickTime } else { -1 };

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

    // LandVehicle (excl. Air): for FADE_landVehicleClasses and vehicle faction caches.
    // Cache "enemy" (side 0 EAST + side 2 INDEPENDENT) so mod factions presented as OPFOR via CfgFactionClasses
    // are indexed too  -  FADE_getEnemyVehiclesForFaction reads this map.
    if (_scope >= 2 && { _class isKindOf "LandVehicle" } && { !(_class isKindOf "Air") }) then {
        private _name = getText (_cfg >> "displayName");
        if (_name == "") then { _name = _class };
        _landPairs pushBack [_name, _class];
        if (_side == 0 || _side == 1 || _side == 2) then {
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

    // Ship (enemy only): for CAS vehicle spawns. Same side widening as land vehicles above.
    if (_scope >= 2 && { _class isKindOf "Ship" } && { !(_class isKindOf "Air") } && { _side == 0 || _side == 1 || _side == 2 }) then {
        private _arr = FADE_enemyVehiclesByFaction getOrDefault [_faction, []];
        _arr pushBack _class;
        FADE_enemyVehiclesByFaction set [_faction, _arr];
    };
} forEach ("true" configClasses (configFile >> "CfgVehicles"));

if (_tCfgVeh0 >= 0) then {
    diag_log format ["[FAC profile] CfgVehicles scan+sort (server): %1 s", diag_tickTime - _tCfgVeh0];
};

// Sorted aircraft and land vehicle lists (classnames only)
_heliPairs sort true;
FADE_heliClasses = _heliPairs apply { _x select 1 };
_landPairs sort true;
FADE_landVehicleClasses = _landPairs apply { _x select 1 };

// Civilian addon filter: only keep classes from same addon(s) as faction. Avoids mods polluting CIV_F.
// When faction has addons but no unit matches, return [] (not the full input) so strict scenario filters
// do not treat the whole side pool as faction-valid.
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
    _out
};

// True when _class is a spawnable human infantry unit (never vehicles / static / ships / aircraft).
FADE_isInfantryManClass = {
    params ["_class"];
    if (!(_class isEqualType "") || { _class == "" }) exitWith { false };
    if (!isClass (configFile >> "CfgVehicles" >> _class)) exitWith { false };
    if (!(_class isKindOf "Man")) exitWith { false };
    if (_class isKindOf "LandVehicle" || { _class isKindOf "Air" } || { _class isKindOf "Ship" } || { _class isKindOf "StaticWeapon" }) exitWith { false };
    true
};

FADE_filterInfantryManClasses = {
    params ["_classes"];
    if (!(_classes isEqualType []) || { _classes isEqualTo [] }) exitWith { [] };
    _classes select { [_x] call FADE_isInfantryManClass }
};

// Filter unit classnames to those that spawn with a primary weapon or sidearm.
// We only accept CfgWeapons entries with type 1 (PrimaryWeapon) or 2 (Handgun).
// When armed filter empties, fall back to unarmed infantry only (never return vehicles).
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
    if (_out isEqualTo []) then { [_classes] call FADE_filterInfantryManClasses } else { _out };
};
// Backward-compatible alias used by existing mission scripts.
FADE_filterEnemyUnitsArmed = FADE_filterUnitsArmed;
FADE_filterFriendlyUnitsArmed = FADE_filterUnitsArmed;
missionNamespace setVariable ["FADE_isInfantryManClass", FADE_isInfantryManClass];
missionNamespace setVariable ["FADE_filterInfantryManClasses", FADE_filterInfantryManClasses];
missionNamespace setVariable ["FADE_filterUnitsArmed", FADE_filterUnitsArmed];
missionNamespace setVariable ["FADE_filterEnemyUnitsArmed", FADE_filterEnemyUnitsArmed];
missionNamespace setVariable ["FADE_filterFriendlyUnitsArmed", FADE_filterFriendlyUnitsArmed];

// Drop unit classes that do not match scenario faction side + CfgFactionClasses (addon fallback for mod units with empty faction).
FADE_filterUnitsForScenarioFaction = {
    params ["_classes", ["_faction", ""], ["_sideNum", -1], ["_strict", false]];
    if (_faction == "") then { _faction = missionNamespace getVariable ["FADE_scenarioFriendlyFaction", ""] };
    if (_sideNum < 0) then { _sideNum = missionNamespace getVariable ["FADE_scenarioFriendlySideNum", 1] };
    if (_classes isEqualTo [] || { _faction == "" }) exitWith { _classes };
    private _cfgRoot = configFile >> "CfgVehicles";
    private _out = [];
    {
        if (!(_x isEqualType "") || { !isClass (_cfgRoot >> _x) }) then { continue };
        private _cfg = _cfgRoot >> _x;
        if (getNumber (_cfg >> "side") != _sideNum) then { continue };
        if (getText (_cfg >> "faction") == _faction) then { _out pushBack _x };
    } forEach _classes;
    if (_out isEqualTo []) then {
        _out = [_classes, _faction, true] call FADE_civ_filterByFactionAddon;
    };
    if (_out isEqualTo []) then { if (_strict) then { [] } else { _classes } } else { _out }
};

// Strict CfgVehicles faction filter with fallback when CfgGroups/addon resolution already produced units.
FADE_filterUnitsForScenarioFactionSafe = {
    params ["_classes", ["_faction", ""], ["_sideNum", -1], ["_strict", false]];
    private _pre = +_classes;
    private _scoped = [_pre, _faction, _sideNum, _strict] call FADE_filterUnitsForScenarioFaction;
    if (_scoped isEqualTo [] && { count _pre > 0 }) then { _pre } else { _scoped }
};
missionNamespace setVariable ["FADE_filterUnitsForScenarioFaction", FADE_filterUnitsForScenarioFaction];
missionNamespace setVariable ["FADE_filterUnitsForScenarioFactionSafe", FADE_filterUnitsForScenarioFactionSafe];

// Cache for FADE_getUnitsForFaction / FADE_getCivVehiclesForFaction (invalidated on Scenario Apply)
FADE_getUnitsForFaction_cache = createHashMap;
FADE_getCivVehiclesForFaction_cache = createHashMap;

FADE_collectGroupUnitClasses = {
    params ["_groupCfg"];
    private _out = [];
    private _units = getArray (_groupCfg >> "units");
    {
        private _cls = "";
        if (_x isEqualType [] && { count _x >= 1 }) then {
            _cls = _x select 0;
        } else {
            if (_x isEqualType "") then { _cls = _x };
        };
        if (_cls isEqualType "" && { isClass (configFile >> "CfgVehicles" >> _cls) } && { _cls isKindOf "Man" }) then {
            _out pushBackUnique _cls;
        };
    } forEach _units;
    {
        private _cls = getText (_x >> "vehicle");
        if (_cls != "" && { isClass (configFile >> "CfgVehicles" >> _cls) } && { _cls isKindOf "Man" }) then {
            _out pushBackUnique _cls;
        };
    } forEach ("true" configClasses _groupCfg);
    _out
};

// RHS/mod CfgGroups often nest categories 3+ deep (faction >> category >> squad >> units).
FADE_collectCfgGroupUnitsDeep = {
    params ["_groupCfg"];
    private _out = [];
    if (!isClass _groupCfg) exitWith { _out };
    _out append ([_groupCfg] call FADE_collectGroupUnitClasses);
    { _out append ([_x] call FADE_collectCfgGroupUnitsDeep) } forEach ("true" configClasses _groupCfg);
    _out
};

// Mod fallback token: rhs_faction_socom -> "socom"; BLU_F -> "blu".
FADE_factionUnitSearchToken = {
    params ["_faction"];
    if (!(_faction isEqualType "") || { _faction == "" }) exitWith { "" };
    private _parts = _faction splitString "_";
    _parts = _parts select {
        private _p = toLower _x;
        !(_p in ["rhs", "faction", "f", "opf", "blu", "ind", "civ", "guer", "g"])
    };
    if (_parts isEqualTo []) then { toLower _faction } else { toLower (_parts joinString "_") }
};

FADE_collectUnitsByFactionTokenFromSidePool = {
    params ["_faction", "_sideNum", ["_token", ""]];
    if (_token == "") then { _token = [_faction] call FADE_factionUnitSearchToken };
    if (_token == "" || { count _token < 3 }) exitWith { [] };
    private _cfgRoot = configFile >> "CfgVehicles";
    private _pool = [];
    {
        if (_x select [count _x - 2, 2] != ("_" + str _sideNum)) then { continue };
        _pool append (FADE_unitsByFactionSide getOrDefault [_x, []]);
    } forEach (keys FADE_unitsByFactionSide);
    private _out = [];
    {
        if (!(_x isEqualType "") || { !isClass (_cfgRoot >> _x) }) then { continue };
        private _cfg = _cfgRoot >> _x;
        if (getNumber (_cfg >> "side") != _sideNum) then { continue };
        if (toLower _x find _token < 0) then { continue };
        _out pushBackUnique _x;
    } forEach _pool;
    [_out, _faction, true] call FADE_civ_filterByFactionAddon
};
missionNamespace setVariable ["FADE_collectGroupUnitClasses", FADE_collectGroupUnitClasses];
missionNamespace setVariable ["FADE_collectCfgGroupUnitsDeep", FADE_collectCfgGroupUnitsDeep];

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
// missionNamespace FADE_getUnitsForFaction_cache: keyed "faction|sideNum" (invalidated on Scenario Apply).
FADE_getUnitsForFaction = {
    params ["_faction", ["_sideNum", -1]];
    if (_faction == "") exitWith { [] };
    private _factionCfg = configFile >> "CfgFactionClasses" >> _faction;
    if (!isClass _factionCfg) exitWith { [] };
    if (_sideNum < 0) then { _sideNum = getNumber (_factionCfg >> "side") };
    private _cacheKey = _faction + "|" + str _sideNum;
    if (FADE_getUnitsForFaction_cache isEqualType createHashMap) then {
        private _hit = FADE_getUnitsForFaction_cache getOrDefault [_cacheKey, nil];
        if (!isNil "_hit") exitWith { +_hit };
    };

    private _result = [];
    if (_sideNum == 3) then {
        private _out = [];
        // 1) Try CfgGroups (faction-specific groups)
        {
            private _grpCfg = configFile >> "CfgGroups" >> _x >> _faction;
            if (isClass _grpCfg) then {
                {
                    { _out append ([_x] call FADE_collectGroupUnitClasses) } forEach ("true" configClasses _x);
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
        _result = _out;
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

        // 1) CfgGroups: deep walk (RHS/mod nested categories); match faction name or token in sibling faction keys.
        private _token = [_faction] call FADE_factionUnitSearchToken;
        {
            private _sideRoot = configFile >> "CfgGroups" >> _x;
            if (!isClass _sideRoot) then { continue };
            {
                private _facCfg = _x;
                private _facName = configName _facCfg;
                private _nameMatch = (_facName == _faction) || { count _token >= 3 && { toLower _facName find _token >= 0 } };
                if (!_nameMatch) then { continue };
                _out append ([_facCfg] call FADE_collectCfgGroupUnitsDeep);
            } forEach ("true" configClasses _sideRoot);
        } forEach _sideCategories;

        // 2) Fallback: cache keyed by faction+sideNum, then addon-filtered side pool (mod units often use parent faction in CfgVehicles)
        if (_out isEqualTo []) then {
            private _cached = FADE_unitsByFactionSide getOrDefault [_faction + "_" + str _sideNum, []];
            if (_cached isEqualTo []) then {
                private _pool = [];
                {
                    if (_x select [count _x - 2, 2] == ("_" + str _sideNum)) then {
                        _pool append (FADE_unitsByFactionSide getOrDefault [_x, []]);
                    };
                } forEach (keys FADE_unitsByFactionSide);
                _cached = _pool;
            };
            _out = [_cached, _faction, true] call FADE_civ_filterByFactionAddon;
        };

        // 3) For enemy factions (side 0), also check side 2 (Resistance) - some mod OPFOR factions
        //    configure their units as Independent in CfgVehicles but are presented as OPFOR in game
        if (_out isEqualTo [] && { _sideNum == 0 }) then {
            _out = FADE_unitsByFactionSide getOrDefault [_faction + "_2", []];
        };

        // 4) Mod fallback: classname token on side pool (e.g. rhs_faction_socom -> rhsusf_socom_* when CfgGroups faction key mismatches).
        if (_out isEqualTo []) then {
            _out = [_faction, _sideNum, _token] call FADE_collectUnitsByFactionTokenFromSidePool;
        };

        _result = _out;
        // #region agent log
        if (_faction find "socom" >= 0 || { count _result == 0 }) then {
            diag_log format ["[FAC DbgBrowser 62d308] H13 getUnitsForFaction faction=%1 side=%2 raw=%3 token=%4 sample=%5",
                _faction, _sideNum, count _result, _token, if (count _result > 0) then { _result select 0 } else { "" }];
        };
        // #endregion
    };
    if (FADE_getUnitsForFaction_cache isEqualType createHashMap) then {
        FADE_getUnitsForFaction_cache set [_cacheKey, +_result];
    };
    _result
};

// Resolve scenario unit class arrays for mission spawns (live faction lookup first — cached lists can drift).
FADE_resolveScenarioFriendlyUnits = {
    params [["_fallback", []]];
    private _ff = missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"];
    private _snF = missionNamespace getVariable ["FADE_scenarioFriendlySideNum", 1];
    private _units = [_ff, _snF] call FADE_getUnitsForFaction;
    if (_units isEqualTo []) then {
        _units = +(missionNamespace getVariable ["FADE_friendlyUnits", _fallback]);
    };
    if (_units isEqualTo []) then {
        _units = +_fallback;
    };
    if (_units isEqualTo [] && { _ff isEqualTo "BLU_F" }) then {
        _units = +(missionNamespace getVariable ["FADE_fallbackFriendlyUnits", ["B_Soldier_TL_F", "B_Soldier_F", "B_Soldier_AR_F", "B_medic_F"]]);
    };
    private _filter = missionNamespace getVariable ["FADE_filterUnitsArmed", { _this select 0 }];
    _units = [_units] call _filter;
    private _scoped = [_units, _ff, _snF, true] call FADE_filterUnitsForScenarioFactionSafe;
    _scoped = [_scoped] call FADE_filterInfantryManClasses;
    if (_scoped isEqualTo [] && { _ff isEqualTo "BLU_F" }) then {
        _scoped = [+(missionNamespace getVariable ["FADE_fallbackFriendlyUnits", ["B_Soldier_F"]])] call FADE_filterInfantryManClasses;
    };
    _scoped
};
FADE_resolveScenarioEnemyUnits = {
    params [["_fallback", []]];
    private _ef = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
    private _snE = missionNamespace getVariable ["FADE_scenarioEnemySideNum", 0];
    private _units = [_ef, _snE] call FADE_getUnitsForFaction;
    if (_units isEqualTo []) then {
        _units = +(missionNamespace getVariable ["FADE_enemyUnits", _fallback]);
    };
    if (_units isEqualTo []) then {
        _units = +_fallback;
    };
    if (_units isEqualTo [] && { _ef isEqualTo "OPF_F" }) then {
        _units = +(missionNamespace getVariable ["FADE_fallbackEnemyUnits", ["O_Soldier_TL_F", "O_Soldier_F", "O_Soldier_AR_F"]]);
    };
    private _filter = missionNamespace getVariable ["FADE_filterEnemyUnitsArmed", { _this select 0 }];
    _units = [_units] call _filter;
    private _launcherFilter = missionNamespace getVariable ["FADE_filterEnemyUnitsByLauncherPolicy", { _this select 0 }];
    _units = [_units] call _launcherFilter;
    [_units, _ef, _snE, false] call FADE_filterUnitsForScenarioFaction
};
missionNamespace setVariable ["FADE_resolveScenarioFriendlyUnits", FADE_resolveScenarioFriendlyUnits];
missionNamespace setVariable ["FADE_resolveScenarioEnemyUnits", FADE_resolveScenarioEnemyUnits];

// IR strobes on friendly groups at night (ACE). Used by Missions.sqf, AOMission, TroopInsertMission.
FADE_attachNightStrobes = {
    params ["_grp"];
    if (isNull _grp) exitWith {};
    private _timeMin = (date select 3) * 60 + (date select 4);
    if !(_timeMin >= 1170 || { _timeMin <= 270 }) exitWith {};
    if !(isClass (configFile >> "CfgPatches" >> "ace_attach")) exitWith {};
    private _irVehClass = getText (configFile >> "CfgWeapons" >> "ACE_IR_Strobe_Item" >> "ACE_Attachable");
    if (_irVehClass == "") then { _irVehClass = getText (configFile >> "CfgMagazines" >> "ACE_IR_Strobe_Item" >> "ACE_Attachable") };
    if (_irVehClass == "") exitWith {};
    private _strobes = [];
    {
        if (alive _x) then {
            private _s = _irVehClass createVehicle [0, 0, 0];
            _s attachTo [_x, [0.07, -0.06, 0.085], "leftshoulder"];
            _strobes pushBack _s;
        };
    } forEach units _grp;
    _grp setVariable ["FADE_irStrobes", _strobes];
};
missionNamespace setVariable ["FADE_attachNightStrobes", FADE_attachNightStrobes];

call compile preprocessFileLineNumbers "rsc\FADE_FactionScenario.sqf";

// Operation mission: BLUFOR / OPFOR within horizontal radius (distance2D).
// Capture uses spawned OPFOR only; full count (incl. virtual garrison pending) for contested/QRF.
FADE_op_countBluforPlayersInRadius = {
    params ["_center", "_r"];
    private _n = 0;
    {
        if ([_x] call FADE_isScenarioFriendlyUnit && { isPlayer _x } && { alive _x } && { (_x distance2D _center) <= _r }) then { _n = _n + 1 };
    } forEach allPlayers;
    _n
};
FADE_op_countBluforInRadius = {
    params ["_center", "_r"];
    private _n = 0;
    {
        if ([_x] call FADE_isScenarioFriendlyUnit && { alive _x } && { _x isKindOf "Man" } && { (_x distance2D _center) <= _r }) then { _n = _n + 1 };
    } forEach allUnits;
    _n
};
FADE_op_countEnemyMenInRadius = {
    params ["_center", "_r"];
    private _n = 0;
    private _se = missionNamespace getVariable ["FADE_sideEnemy", east];
    {
        if (!alive _x) then {} else {
            if (side _x == _se && { _x isKindOf "Man" } && { (_x distance2D _center) <= _r }) then { _n = _n + 1 };
        };
    } forEach allUnits;
    _n
};
FADE_op_countEnemyMenSpawnedInRadius = {
    params ["_center", "_r"];
    private _raw = missionNamespace getVariable ["FADE_op_countEnemyMenInRadius_raw", nil];
    if (!isNil "_raw" && { _raw isEqualType {} }) then {
        [_center, _r] call _raw
    } else {
        [_center, _r] call FADE_op_countEnemyMenInRadius
    }
};
missionNamespace setVariable ["FADE_op_countBluforPlayersInRadius", FADE_op_countBluforPlayersInRadius];
missionNamespace setVariable ["FADE_op_countBluforInRadius", FADE_op_countBluforInRadius];
missionNamespace setVariable ["FADE_op_countEnemyMenInRadius", FADE_op_countEnemyMenInRadius];
missionNamespace setVariable ["FADE_op_countEnemyMenSpawnedInRadius", FADE_op_countEnemyMenSpawnedInRadius];

call compile preprocessFileLineNumbers "rsc\FADE_VirtualGarrison.sqf";
call compile preprocessFileLineNumbers "rsc\FADE_IntelServer.sqf";

// BIS_fnc_taskCreate expects missionNamespace bis_fnc_tasksetparent (lowercase) on some builds.
// Do not preprocessFile vanilla addon sqf from the mission: that often errors ("script not found")
// even with a leading \; use the already-compiled CfgFunctions entry instead.
FADE_ensureBisTaskSetParent = {
    private _existing = missionNamespace getVariable ["bis_fnc_tasksetparent", {}];
    if (!(_existing isEqualTo {})) exitWith {};
    private _tspParent = missionNamespace getVariable ["BIS_fnc_taskSetParent", nil];
    if (isNil "_tspParent") then { _tspParent = uiNamespace getVariable ["BIS_fnc_taskSetParent", nil]; };
    if (isNil "_tspParent") then {
        _tspParent = {
            params ["_taskID", ["_parentTaskID", "", [""]], ["_parentTaskType", "", [""]]];
            true
        };
    };
    missionNamespace setVariable ["bis_fnc_tasksetparent", _tspParent];
};
call FADE_ensureBisTaskSetParent;

// CfgFactionClasses >> side (0â€“3) -> Arma side / marker colors  -  missions must not assume EAST/WEST when factions are Independent etc.
FADE_getFactionSideNum = {
    params ["_faction", "_default"];
    if (_faction == "") exitWith { _default };
    private _cfg = configFile >> "CfgFactionClasses" >> _faction;
    if (!isClass _cfg) exitWith { _default };
    private _n = getNumber (_cfg >> "side");
    if (_n < 0 || _n > 3) exitWith { _default };
    _n
};
FADE_getFactionDisplayName = {
    params ["_faction"];
    [_faction] call FADE_factionDisplayNameSafe
};
missionNamespace setVariable ["FADE_getFactionDisplayName", FADE_getFactionDisplayName];
publicVariable "FADE_getFactionDisplayName";
FADE_sideNumToSide = {
    params ["_n"];
    switch (_n) do {
        case 0: { east };
        case 1: { west };
        case 2: { resistance };
        case 3: { civilian };
        default { west };
    };
};
FADE_markerColorForSideNum = {
    params ["_n"];
    switch (_n) do {
        case 0: { "ColorEAST" };
        case 1: { "ColorWEST" };
        case 2: { "ColorGUER" };
        case 3: { "ColorCIV" };
        default { "ColorEAST" };
    };
};
missionNamespace setVariable ["FADE_getFactionSideNum", FADE_getFactionSideNum];
missionNamespace setVariable ["FADE_sideNumToSide", FADE_sideNumToSide];
missionNamespace setVariable ["FADE_markerColorForSideNum", FADE_markerColorForSideNum];

// Returns array of enemy land/ship vehicle classnames for faction. Cache first; if the
// CfgVehicles scan missed the faction (some mods register sub-classes under the parent
// faction or use scope 1), do a live filter against the loaded land vehicle list using
// the faction's own CfgFactionClasses side. Air is excluded by convention  -  see
// FADE_getEnemyAirVehicleClasses for that.
FADE_getEnemyVehiclesForFaction = {
    params ["_faction"];
    if (_faction == "") exitWith { [] };
    private _cached = FADE_enemyVehiclesByFaction getOrDefault [_faction, []];
    if (count _cached > 0) exitWith { _cached };
    private _wantSide = [_faction, 0] call FADE_getFactionSideNum;
    private _live = FADE_landVehicleClasses select {
        private _cfg = configFile >> "CfgVehicles" >> _x;
        getText (_cfg >> "faction") == _faction && { getNumber (_cfg >> "side") == _wantSide }
    };
    _live
};

// Returns array of friendly vehicle classnames for faction; aircraft + land. Uses CfgFactionClasses side (not hardcoded WEST).
FADE_getFriendlyVehicleClasses = {
    params ["_faction"];
    if (_faction == "") exitWith { [] };
    private _wantSide = [_faction, 1] call FADE_getFactionSideNum;
    private _all = (FADE_heliClasses + FADE_landVehicleClasses);
    private _byFaction = [];
    {
        private _cfg = configFile >> "CfgVehicles" >> _x;
        if (getText (_cfg >> "faction") == _faction && { getNumber (_cfg >> "side") == _wantSide }) then {
            _byFaction pushBack _x;
        };
    } forEach _all;
    if (count _byFaction > 0) exitWith { _byFaction };
    _all select { getNumber (configFile >> "CfgVehicles" >> _x >> "side") == _wantSide }
};

// Returns array of civilian vehicle classnames for faction.
// CfgGroups first, then cache - BOTH filtered by faction addon.
// FADE_getCivVehiclesForFaction_cache: keyed by faction (invalidated on Scenario Apply).
FADE_getCivVehiclesForFaction = {
    params ["_faction"];
    if (_faction == "") exitWith { [] };
    if (FADE_getCivVehiclesForFaction_cache isEqualType createHashMap) then {
        private _hit = FADE_getCivVehiclesForFaction_cache getOrDefault [_faction, nil];
        if (!isNil "_hit") exitWith { +_hit };
    };
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
    private _final = keys _seen;
    if (FADE_getCivVehiclesForFaction_cache isEqualType createHashMap) then {
        FADE_getCivVehiclesForFaction_cache set [_faction, +_final];
    };
    _final
};

// Resolve OPFOR population setting into a concrete multiplier (fixed stepped levels only).
// VeryLow 0.25x | Low 0.5x | Normal 1x | High 1.5x | VeryHigh 2x | Insane 4x
FADE_resolveOpforPopulationScale = {
    params [["_setting", "Normal"]];
    private _set = toLower (_setting + "");
    switch _set do {
        case "verylow": { [0.25, "Very Low (0.25x)"] };
        case "low": { [0.5, "Low (0.5x)"] };
        case "high": { [1.5, "High (1.5x)"] };
        case "veryhigh": { [2, "Very High (2x)"] };
        case "insane": { [4, "Insane (4x)"] };
        default { [1, "Normal (1x)"] };
    }
};

// Scale an OPFOR count with current scenario multiplier.
FADE_scaleOpforCount = {
    params ["_baseCount", ["_minCount", 1], ["_maxCount", -1]];
    private _base = floor (_baseCount max 0);
    if (_base <= 0) exitWith { 0 };
    private _scale = missionNamespace getVariable ["FADE_opforPopulationScale", 1];
    private _scaled = ceil (_base * _scale);
    if (_scaled < _minCount) then { _scaled = _minCount };
    if (_maxCount >= 0 && { _scaled > _maxCount }) then { _scaled = _maxCount };
    _scaled
};
publicVariable "FADE_scaleOpforCount";

// AI radio lines: replicate to clients so dedicated players see BLUFOR/OPFOR lines (P15).
FADE_aiSideChat = {
    params ["_unit", "_message"];
    if (isNull _unit || {!alive _unit}) exitWith {};
    [_unit, _message] remoteExec ["FADE_aiSideChat_exec", 0];
};
publicVariable "FADE_aiSideChat";

// Same logic as initPlayerLocal (required on dedicated server for remoteExec target 0).
FADE_aiSideChat_exec = {
    params ["_unit", "_message"];
    if (isNull _unit || {!alive _unit}) exitWith {};
    if (local _unit) then {
        _unit sideChat _message;
    };
    if (hasInterface && {side player == side _unit}) then {
        if (!local _unit) then {
            systemChat _message;
        };
    };
};
publicVariable "FADE_aiSideChat_exec";

// OPFOR AT launchers (RPG/MAAWS etc.): strip probability by scenario setting (P21). Skips MANPADS (AA) weapons.
// Detection: CfgWeapons type 4 (launcher) and/or inheritance from Launcher_Base_F (Bohemia wiki / config tree); some mods omit type.
FADE_weaponIsOpforAtLauncherPolicyTarget = {
    params ["_weapon"];
    if (_weapon == "" || { _weapon in ["Throw", "Put"] }) exitWith { false };
    private _ln = toLower _weapon;
    if ((_ln find "stinger" >= 0) || { _ln find "igla" >= 0 }) exitWith { false };
    if ((_ln find "launch_" >= 0) && { _ln find "aa" >= 0 }) exitWith { false };
    if ((_ln find "titan" >= 0) && { _ln find "aa" >= 0 }) exitWith { false };
    private _cfg = configFile >> "CfgWeapons" >> _weapon;
    if (isClass _cfg) then {
        private _t = getNumber (_cfg >> "type");
        if (_t == 4) exitWith { true };
        if (_weapon isKindOf ["Launcher_Base_F", configFile >> "CfgWeapons"]) exitWith { true };
    };
    (_ln find "launch_" == 0)
        || { _ln find "rpg" >= 0 }
        || { _ln find "nlaw" >= 0 }
        || { _ln find "mraws" >= 0 }
        || { _ln find "maaws" >= 0 }
        || { (_ln find "titan" >= 0) && { (_ln find "short" >= 0) || { _ln find "at" >= 0 } || { _ln find "ap" >= 0 } } }
};

FADE_unitClassCarriesOpforAtLauncher = {
    params ["_class"];
    if (!(_class isEqualType "") || { !isClass (configFile >> "CfgVehicles" >> _class) }) exitWith { false };
    private _hit = false;
    {
        if ([_x] call FADE_weaponIsOpforAtLauncherPolicyTarget) exitWith { _hit = true };
    } forEach (getArray (configFile >> "CfgVehicles" >> _class >> "weapons"));
    _hit
};

FADE_filterEnemyUnitsByLauncherPolicy = {
    params ["_classes"];
    if (_classes isEqualTo [] || { !(_classes isEqualType []) }) exitWith { _classes };
    private _setting = [missionNamespace getVariable ["FADE_opforLauncherSetting", "Normal"]] call FADE_normalizeOpforLauncherSetting;
    if (_setting == "Normal") exitWith { _classes };
    private _plain = [];
    private _at = [];
    {
        if ([_x] call FADE_unitClassCarriesOpforAtLauncher) then { _at pushBack _x } else { _plain pushBack _x };
    } forEach _classes;
    if (_at isEqualTo [] || { _plain isEqualTo [] }) exitWith { _classes };
    private _keepShare = switch (_setting) do {
        case "Reduced": { 0.25 };
        case "Minimal": { 0.10 };
        case "None": { 0 };
        default { 1 };
    };
    private _keepN = (round (count _at * _keepShare)) max 0;
    private _atShuffled = +_at;
    _atShuffled = _atShuffled call BIS_fnc_arrayShuffle;
    +_plain + (_atShuffled select [0, _keepN min count _atShuffled])
};
missionNamespace setVariable ["FADE_filterEnemyUnitsByLauncherPolicy", FADE_filterEnemyUnitsByLauncherPolicy];

FADE_reapplyOpforLauncherPolicyToAliveEnemy = {
    if (!isServer) exitWith {};
    private _enemySide = missionNamespace getVariable ["FADE_sideEnemy", east];
    {
        if (alive _x && { side _x == _enemySide }) then { [_x] call FADE_applyOpforLauncherPolicyToUnit };
    } forEach allUnits;
};

FADE_applyOpforLauncherPolicyToUnit = {
    params ["_unit"];
    if (!isServer) exitWith {};
    if (isNull _unit || {!alive _unit}) exitWith {};
    private _enemySide = missionNamespace getVariable ["FADE_sideEnemy", east];
    if (side _unit != _enemySide) exitWith {};
    // Deferred: loadouts can finish after spawn; scan all weapon slots (not only secondaryWeapon).
    [_unit] spawn {
        params ["_unit"];
        private _enemySide2 = missionNamespace getVariable ["FADE_sideEnemy", east];
        {
            sleep _x;
            if (isNull _unit || {!alive _unit}) exitWith {};
            if (side _unit != _enemySide2) exitWith {};
            private _setting = [missionNamespace getVariable ["FADE_opforLauncherSetting", "Normal"]] call FADE_normalizeOpforLauncherSetting;
            if (_setting == "Normal") exitWith {};
            private _keepChance = switch (_setting) do {
                case "Reduced": { 0.25 };
                case "Minimal": { 0.10 };
                case "None": { 0 };
                default { 1 };
            };
            private _strip = [];
            {
                if ([_x] call FADE_weaponIsOpforAtLauncherPolicyTarget) then {
                    if (random 1 > _keepChance) then {
                        if !(_x in _strip) then { _strip pushBack _x };
                    };
                };
            } forEach (weapons _unit);
            { _unit removeWeapon _x } forEach _strip;
        } forEach [0.15, 0.6, 1.5];
    };
};
publicVariable "FADE_applyOpforLauncherPolicyToUnit";

// Enemy group skill/routing/launcher policy from Scenario (Missions / AO / Operation / roadblocks / counter-attack).
FAC_applyEnemyScenarioToGroup = {
    params ["_grp"];
    private _enemySide = missionNamespace getVariable ["FADE_sideEnemy", east];
    if (isNull _grp || { side _grp != _enemySide }) exitWith {};
    private _ensureDry = missionNamespace getVariable ["FADE_ensureDryLandPos", {}];
    private _dryFn = missionNamespace getVariable ["FADE_surfaceIsDry", { params ["_p"]; count _p >= 2 && { !surfaceIsWater [_p select 0, _p select 1] } }];
    {
        if (alive _x) then {
            private _p = getPosATL _x;
            if !([_p] call _dryFn) then {
                if (!(_ensureDry isEqualTo {})) then {
                    private _dry = [_p, _p] call _ensureDry;
                    if ([_dry] call _dryFn) then { _x setPosATL _dry };
                };
            };
        };
    } forEach units _grp;
    private _skill = missionNamespace getVariable ["FADE_enemySkill", 0.0];
    private _routing = missionNamespace getVariable ["FADE_enemyRouting", 0];
    { _x setSkill _skill } forEach units _grp;
    _grp allowFleeing _routing;
    if (!isNil "FADE_applyOpforLauncherPolicyToUnit") then {
        { [_x] call FADE_applyOpforLauncherPolicyToUnit } forEach units _grp;
    };
};
missionNamespace setVariable ["FAC_applyEnemyScenarioToGroup", FAC_applyEnemyScenarioToGroup];

// OPFOR ambient air threat (P24): optional, hard-capped + cooldown; spawns only after OPFOR AI detects BLUFOR (knowsAbout), after a random delay (vectoring / scramble), flying toward players/base. While all friendly players are within FADE_opforAir_hqSafeRadius of BASE_1, active assets despawn and new spawns / pending timers are suppressed.
missionNamespace setVariable ["FADE_opforAir_active", []];
missionNamespace setVariable ["FADE_opforAir_lastSpawnTime", -1e9];
missionNamespace setVariable ["FADE_opforAir_pendingUntil", -1];

// knowsAbout >= ~1.5: target type known / combat contact (wiki scale 0â€“4).
