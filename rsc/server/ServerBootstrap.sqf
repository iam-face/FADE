call compile preprocessFileLineNumbers "rsc\OperationNames.sqf";
missionNamespace setVariable ["FADE_convoyMinRouteM", FADE_convoyMinRouteM];
FADE_interceptConvoyRoadRoute = compile preprocessFileLineNumbers "rsc\fn_FADE_interceptConvoyRoadRoute.sqf";
missionNamespace setVariable ["FADE_counterAttackFirstDelayMin", FADE_counterAttackFirstDelayMin];
missionNamespace setVariable ["FADE_counterAttackFirstDelayMax", FADE_counterAttackFirstDelayMax];
missionNamespace setVariable ["FADE_counterAttackMinDistFromBase", FADE_counterAttackMinDistFromBase];
missionNamespace setVariable ["FADE_counterAttackCargoStaggerSec", FADE_counterAttackCargoStaggerSec];

// Preferred startup factions by display name (if present). Falls back to config defaults.
// Second pass: case-insensitive substring match on displayName (exact string in mod configs can drift).
FADE_pickFactionByDisplayName = {
    params ["_sideNum", "_preferredDisplayNames", "_fallbackFaction"];
    private _picked = _fallbackFaction;
    private _allFc = "true" configClasses (configFile >> "CfgFactionClasses");
    {
        private _cfg = _x;
        if (getNumber (_cfg >> "side") != _sideNum) then { continue };
        private _dn = getText (_cfg >> "displayName");
        if (_dn == "") then { continue };
        if (_dn in _preferredDisplayNames) exitWith { _picked = configName _cfg };
    } forEach _allFc;
    if (_picked == _fallbackFaction) then {
        // Prefer earlier entries in _preferredDisplayNames (e.g. "USA (USMC - D)" before bare "Marine").
        {
            private _pref = toLower _x;
            if (_pref == "") then { continue };
            {
                private _cfg = _x;
                if (getNumber (_cfg >> "side") != _sideNum) then { continue };
                private _dn = toLower getText (_cfg >> "displayName");
                if (_dn == "") then { continue };
                if (_dn find _pref >= 0) exitWith { _picked = configName _cfg };
            } forEach _allFc;
            if (_picked != _fallbackFaction) exitWith {};
        } forEach _preferredDisplayNames;
    };
    _picked
};

// Display-name hints (exact match first, then substring). Add aliases if 3CB/RHS renames factions.
private _prefFriendly = ["USA (USMC - D)", "USMC", "Marines", "Marine"];
private _prefEnemy = ["3CB African Desert Extremists", "African Desert Extremists", "ADA", "3CB"];
private _prefCiv = ["3CB African Desert Civilians", "African Desert Civilians", "3CB"];
FADE_scenarioFriendlyFaction = [1, _prefFriendly, FADE_scenarioFriendlyFaction] call FADE_pickFactionByDisplayName;
FADE_scenarioEnemyFaction = [0, _prefEnemy, FADE_scenarioEnemyFaction] call FADE_pickFactionByDisplayName;
FADE_scenarioCivFaction = [3, _prefCiv, FADE_scenarioCivFaction] call FADE_pickFactionByDisplayName;
if (FADE_startupFactionFriendly != "" && { isClass (configFile >> "CfgFactionClasses" >> FADE_startupFactionFriendly) } && { getNumber (configFile >> "CfgFactionClasses" >> FADE_startupFactionFriendly >> "side") == 1 }) then {
    FADE_scenarioFriendlyFaction = FADE_startupFactionFriendly;
};
if (FADE_startupFactionEnemy != "" && { isClass (configFile >> "CfgFactionClasses" >> FADE_startupFactionEnemy) } && { getNumber (configFile >> "CfgFactionClasses" >> FADE_startupFactionEnemy >> "side") == 0 }) then {
    FADE_scenarioEnemyFaction = FADE_startupFactionEnemy;
};
if (FADE_startupFactionCiv != "" && { isClass (configFile >> "CfgFactionClasses" >> FADE_startupFactionCiv) } && { getNumber (configFile >> "CfgFactionClasses" >> FADE_startupFactionCiv >> "side") == 3 }) then {
    FADE_scenarioCivFaction = FADE_startupFactionCiv;
};
missionNamespace setVariable ["FADE_scenarioFriendlyFaction", FADE_scenarioFriendlyFaction, true];
missionNamespace setVariable ["FADE_scenarioEnemyFaction", FADE_scenarioEnemyFaction, true];
missionNamespace setVariable ["FADE_scenarioCivFaction", FADE_scenarioCivFaction, true];

// Lobby params (description.ext class Params): access gates + scenario defaults at start
call compile preprocessFileLineNumbers "rsc\FAC_LobbyParams.sqf";
call FAC_lobbyParams_applyScenarioDefaults;
call FAC_lobbyParams_publishAccessVars;
FADE_playerHasLeaderOverrideAccess = FAC_playerHasLeaderOverrideAccess;
FADE_playerCanUseMissionsGui = FAC_playerCanUseMissionsGui;
FADE_playerCanUseScenarioGui = FAC_playerCanUseScenarioGui;
FADE_playerCanUseVehicleGui = FAC_playerCanUseVehicleGui;
FADE_playerCanUseLoadoutGui = FAC_playerCanUseLoadoutGui;
FADE_playerCanUseScenarioAdmin = FAC_playerCanUseScenarioAdmin;
FADE_playerCanUseJukebox = FAC_playerCanUseJukebox;
FADE_playerCanUseDebugTools = FAC_playerCanUseDebugTools;

// Loadout GUI helpers on server: preset/std resolution for squad-leader apply (full LoadoutGui is client-only  -  initPlayerLocal)
call compile preprocessFileLineNumbers "rsc\LoadoutPresetCommon.sqf";
call compile preprocessFileLineNumbers "rsc\LoadoutGuiServer.sqf";

FAC_loadoutGui_serverRequestApplyToMember = {
    if (!isServer) exitWith {};
    params [["_requester", objNull], ["_targetRef", ""], ["_rowKey", "", [""]]];
    if (isNull _requester || {!isPlayer _requester}) exitWith {};
    if ([_requester, "FAC_playerCanUseLoadoutGui", "Loadout GUI access denied by lobby settings."] call FAC_lobbyParams_serverDenyUnless) exitWith {};
    private _canLead = (leader group _requester == _requester) || { [_requester] call FADE_playerHasLeaderOverrideAccess };
    if (!_canLead) exitWith {
        ["Loadout: only group leaders (or admin/Zeus) can apply loadouts to squadmates."] remoteExec ["systemChat", _requester];
    };
    private _target = objNull;
    if (_targetRef isEqualType objNull) then {
        _target = _targetRef;
    } else {
        if (_targetRef isEqualType "") then {
            if (_targetRef != "") then { _target = objectFromNetId _targetRef };
        };
    };
    if (isNull _target || {_rowKey == ""}) exitWith {
        ["Loadout: invalid request."] remoteExec ["systemChat", _requester];
    };
    if (isNull _target || {!isPlayer _target} || {!alive _target}) exitWith {
        ["Loadout: that player is not available."] remoteExec ["systemChat", _requester];
    };
    if (!(_target in units group _requester)) exitWith {
        ["Loadout: target must be in your group."] remoteExec ["systemChat", _requester];
    };
    if (_target == _requester) exitWith {
        ["Loadout: use Apply to Me on yourself."] remoteExec ["systemChat", _requester];
    };

    private _limitBlu = missionNamespace getVariable ["FADE_limitGearToFriendlyFaction", false];
    private _limitPreset = missionNamespace getVariable ["FADE_limitToPresetLoadouts", false];

    if (_limitPreset && { (_rowKey find "FAC:") != 0 }) exitWith {
        ["Loadout: scenario allows preset loadouts only."] remoteExec ["systemChat", _requester];
    };

    private _loadout = [];
    private _m = 0;
    private _eng = false;
    private _exp = false;

    if ((_rowKey find "FAC:") == 0) then {
        if (!([] call FAC_loadoutGui_ensurePresetData)) exitWith {
            ["Loadout: preset data unavailable on server."] remoteExec ["systemChat", _requester];
        };
        private _raw = [_rowKey] call FAC_loadoutGui_getPresetLoadoutByKey;
        _loadout = [_raw] call FAC_loadoutGui_resolvePresetLoadoutArray;
        if ((count _loadout) < 10) exitWith {
            ["Loadout: could not resolve that preset on the server."] remoteExec ["systemChat", _requester];
        };
        private _roleDn = "";
        { if ((_x select 0) == _rowKey) exitWith { _roleDn = _x select 1 } } forEach ([] call FAC_loadoutGui_buildPresetEntries);
        private _tr = [_roleDn] call FAC_loadoutGui_getPresetRoleTraits;
        _m = _tr select 0;
        _eng = _tr select 1;
        _exp = _tr select 2;
    } else {
        if (_limitBlu) then {
            private _allowed = missionNamespace getVariable ["FADE_friendlyUnits", []];
            if (!(_rowKey in _allowed)) exitWith {
                ["Loadout: that unit class is not allowed by scenario."] remoteExec ["systemChat", _requester];
            };
        };
        if (!isClass (configFile >> "CfgVehicles" >> _rowKey) || {!(_rowKey isKindOf "Man")}) exitWith {
            ["Loadout: invalid infantry class."] remoteExec ["systemChat", _requester];
        };
        private _sideT = side group _target;
        _loadout = [_rowKey, _sideT] call FAC_loadoutGui_getLoadoutFromClass;
        if ((count _loadout) == 0) exitWith {
            ["Loadout: could not build loadout array for that class."] remoteExec ["systemChat", _requester];
        };
        private _cfgTr = [_rowKey] call FAC_loadoutGui_getCfgRoleTraits;
        _m = _cfgTr select 0;
        _eng = _cfgTr select 1;
        _exp = _cfgTr select 2;
    };

    private _fromName = name _requester;
    [_loadout, _m, _eng, _exp, _fromName] remoteExec ["FAC_loadoutGui_clientApplyAuthorizedLoadout", _target];
    [format ["Loadout applied to %1.", name _target]] remoteExec ["systemChat", _requester];
};
publicVariable "FAC_loadoutGui_serverRequestApplyToMember";

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

private _tCfgVeh0 = if (_facProf0 >= 0) then { diag_tickTime } else { -1 };

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
        if (_side == 0 || _side == 2) then {
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
    if (_scope >= 2 && { _class isKindOf "Ship" } && { !(_class isKindOf "Air") } && { _side == 0 || _side == 2 }) then {
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
missionNamespace setVariable ["FADE_filterUnitsForScenarioFaction", FADE_filterUnitsForScenarioFaction];

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
missionNamespace setVariable ["FADE_collectGroupUnitClasses", FADE_collectGroupUnitClasses];

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

        // 1) CfgGroups: iterate side categories, find faction sub-tree, collect Man classnames
        {
            private _grpCfg = configFile >> "CfgGroups" >> _x >> _faction;
            if (isClass _grpCfg) then {
                {
                    { _out append ([_x] call FADE_collectGroupUnitClasses) } forEach ("true" configClasses _x);
                } forEach ("true" configClasses _grpCfg);
            };
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

        _result = _out;
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
    [_units, _ff, _snF, false] call FADE_filterUnitsForScenarioFaction
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

// Operation mission: BLUFOR players / OPFOR men within horizontal radius (distance2D).
// Zone capture state uses 0 OPFOR = captured (latched); player count only for contested vs enemy marker tint when OPFOR present.
FADE_op_countBluforPlayersInRadius = {
    params ["_center", "_r"];
    private _n = 0;
    private _sf = missionNamespace getVariable ["FADE_sideFriendly", west];
    {
        if (isPlayer _x && { alive _x } && { side _x == _sf } && { (_x distance2D _center) <= _r }) then { _n = _n + 1 };
    } forEach allPlayers;
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
missionNamespace setVariable ["FADE_op_countBluforPlayersInRadius", FADE_op_countBluforPlayersInRadius];
missionNamespace setVariable ["FADE_op_countEnemyMenInRadius", FADE_op_countEnemyMenInRadius];

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
    if (_faction == "") exitWith { "Unknown" };
    private _dn = getText (configFile >> "CfgFactionClasses" >> _faction >> "displayName");
    if (_dn == "" || { _dn find "STR_" == 0 }) then {
        (_faction splitString "_") joinString " "
    } else {
        _dn
    };
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

// Resolve OPFOR population setting into a concrete multiplier.
// Auto: 0.5x (1â€“6 players), 1x (7â€“20), 1.5x (21+). Manual modes map to fixed multipliers.
FADE_resolveOpforPopulationScale = {
    params [["_setting", "Auto"]];
    private _set = toLower (_setting + "");
    switch _set do {
        case "verylow": { [0.25, "Manual Very Low (0.25x)"] };
        case "low": { [0.5, "Manual Low (0.5x)"] };
        case "high": { [1.5, "Manual High (1.5x)"] };
        case "veryhigh": { [2, "Manual Very High (2x)"] };
        case "insane": { [4, "Manual Insane (4x)"] };
        case "normal": { [1, "Manual Normal (1x)"] };
        default {
            private _players = count (allPlayers select { !isNull _x });
            private _auto = if (_players <= 6) then { 0.5 } else { if (_players <= 20) then { 1 } else { 1.5 } };
            [_auto, format ["Auto (%1 player%2 -> %3x)", _players, if (_players == 1) then { "" } else { "s" }, _auto]]
        };
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
    if (_weapon == "") exitWith { false };
    private _ln = toLower _weapon;
    if ((_ln find "titan" >= 0) || { _ln find "igla" >= 0 } || { _ln find "stinger" >= 0 } || { (_ln find "launch_" >= 0) && { _ln find "aa" >= 0 } }) exitWith { false };
    private _cfg = configFile >> "CfgWeapons" >> _weapon;
    if (!isClass _cfg) exitWith { false };
    private _t = getNumber (_cfg >> "type");
    if (_t == 4) exitWith { true };
    _weapon isKindOf ["Launcher_Base_F", configFile >> "CfgWeapons"]
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
        sleep 0.2;
        if (isNull _unit || {!alive _unit}) exitWith {};
        private _enemySide2 = missionNamespace getVariable ["FADE_sideEnemy", east];
        if (side _unit != _enemySide2) exitWith {};
        private _setting = missionNamespace getVariable ["FADE_opforLauncherSetting", "Normal"];
        if (_setting == "Normal") exitWith {};
        private _keepChance = switch (_setting) do {
            case "Reduced": { 0.25 };
            case "Minimal": { 0.10 };
            case "None": { 0 };
            default { 1 };
        };
        {
            private _w = _x;
            if ([_w] call FADE_weaponIsOpforAtLauncherPolicyTarget) then {
                if (random 1 > _keepChance) then { _unit removeWeapon _w };
            };
        } forEach (weapons _unit);
    };
};
publicVariable "FADE_applyOpforLauncherPolicyToUnit";

// Enemy group skill/routing/launcher policy from Scenario (Missions / AO / Operation / roadblocks / counter-attack).
FAC_applyEnemyScenarioToGroup = {
    params ["_grp"];
    private _enemySide = missionNamespace getVariable ["FADE_sideEnemy", east];
    if (isNull _grp || { side _grp != _enemySide }) exitWith {};
    private _skill = missionNamespace getVariable ["FADE_enemySkill", 0.2];
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
FADE_opforAir_knowsAboutThreshold = 1.45;
// Random delay (seconds) after detection before spawn: min + random extra (comms + takeoff).
FADE_opforAir_responseDelayMin = 40;
FADE_opforAir_responseDelayExtra = 200;
// While every friendly player is within this distance (2D) of BASE_1: despawn ambient OPFOR air and hold spawns/pending.
FADE_opforAir_hqSafeRadius = 1000;

FADE_opforAir_sideFromFactionCfg = {
    params ["_faction"];
    private _n = getNumber (configFile >> "CfgFactionClasses" >> _faction >> "side");
    switch (_n) do {
        case 0: { east };
        case 1: { west };
        case 2: { resistance };
        case 3: { civilian };
        default { east };
    };
};

// True if any living enemy-faction infantry/crew has sufficient knowsAbout on any BLUFOR player.
FADE_opforAir_opforDetectsBlufor = {
    private _enemyFac = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
    private _friendlyFac = missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"];
    private _enemySide = [_enemyFac] call FADE_opforAir_sideFromFactionCfg;
    private _friendlySide = [_friendlyFac] call FADE_opforAir_sideFromFactionCfg;
    private _players = playableUnits select { side _x == _friendlySide && { alive _x } && { isPlayer _x } };
    if (_players isEqualTo []) exitWith { false };
    private _thr = missionNamespace getVariable ["FADE_opforAir_knowsAboutThreshold", 1.45];
    private _found = false;
    {
        private _pl = _x;
        private _nearEnemy = (_pl nearEntities ["CAManBase", 2500]) select {
            alive _x && { side _x == _enemySide } && { _x isKindOf "CAManBase" }
        };
        {
            if ((_x knowsAbout _pl) >= _thr) exitWith { _found = true };
        } forEach _nearEnemy;
        if (_found) exitWith {};
    } forEach _players;
    _found
};

FADE_opforAir_despawnAll = {
    if (!isServer) exitWith {};
    missionNamespace setVariable ["FADE_opforAir_pendingUntil", -1];
    private _arr = missionNamespace getVariable ["FADE_opforAir_active", []];
    {
        if (!isNull _x && { alive _x }) then {
            private _cargoG = _x getVariable ["FADE_opforAirCargoGrp", grpNull];
            if (!isNull _cargoG) then {
                { deleteVehicle _x } forEach units _cargoG;
                deleteGroup _cargoG;
            };
            private _g = group _x;
            { deleteVehicle _x } forEach (crew _x);
            deleteVehicle _x;
            if (!isNull _g) then { deleteGroup _g };
        };
    } forEach _arr;
    missionNamespace setVariable ["FADE_opforAir_active", []];
};

FADE_opforAir_getTargetASL = {
    private _friendlyFac = missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"];
    private _friendlySide = [_friendlyFac] call FADE_opforAir_sideFromFactionCfg;
    private _acc = [0, 0, 0];
    private _n = 0;
    {
        if (side _x == _friendlySide && { alive _x } && { isPlayer _x }) then {
            _acc = _acc vectorAdd (getPosASL _x);
            _n = _n + 1;
        };
    } forEach playableUnits;
    if (_n > 0) exitWith { _acc vectorMultiply (1 / _n) };
    private _base = missionNamespace getVariable ["BASE_1", objNull];
    if (!isNull _base) exitWith { getPosASL _base };
    private _mapMin = missionNamespace getVariable ["FADE_mapMin", 0];
    private _mapMax = missionNamespace getVariable ["FADE_mapMax", worldSize];
    private _hs = (_mapMin + _mapMax) / 2;
    [_hs, _hs, 100]
};

// FADE_enemyVehicles excludes aircraft (land + ships only); air must be resolved from CfgVehicles like FADE_getFriendlyVehicleClasses.
FADE_getEnemyAirVehicleClasses = {
    private _cached = missionNamespace getVariable ["FADE_enemyAirVehicleClasses_cache", []];
    if (count _cached > 0) exitWith { +_cached };
    private _faction = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
    private _wantSide = missionNamespace getVariable ["FADE_scenarioEnemySideNum", 0];
    if (_faction == "") exitWith { [] };
    private _out = [];
    {
        private _c = _x;
        private _cl = toLower _c;
        if ((_cl find "uav" >= 0) || { _cl find "drone" >= 0 }) then { continue };
        if (!(_c isKindOf "Helicopter") && { !(_c isKindOf "Plane") }) then { continue };
        private _cfg = configFile >> "CfgVehicles" >> _c;
        if (getText (_cfg >> "faction") == _faction && { getNumber (_cfg >> "side") == _wantSide }) then {
            _out pushBack _c;
        };
    } forEach FADE_heliClasses;
    if (count _out > 0) exitWith {
        missionNamespace setVariable ["FADE_enemyAirVehicleClasses_cache", +_out];
        _out
    };
    {
        private _c = _x;
        private _cl = toLower _c;
        if ((_cl find "uav" >= 0) || { _cl find "drone" >= 0 }) then { continue };
        if (!(_c isKindOf "Helicopter") && { !(_c isKindOf "Plane") }) then { continue };
        if (getNumber (configFile >> "CfgVehicles" >> _c >> "side") == _wantSide) then {
            _out pushBack _c;
        };
    } forEach FADE_heliClasses;
    missionNamespace setVariable ["FADE_enemyAirVehicleClasses_cache", +_out];
    _out
};

// Used only when FADE_getEnemyAirVehicleClasses is empty (no faction-matched air in loaded addons).
FADE_opforAir_fallbackHeliClasses = [
    "RHS_Mi8mt_vvs",
    "rhsgref_ins_Mi8amt",
    "UK3CB_TKC_O_Mi8AMT",
    "UK3CB_ADA_O_UH1H_M240",
    "UK3CB_ION_O_Urban_UH1H_M240",
    "UK3CB_MEC_O_UH1H",
    "UK3CB_ADC_I_Mi8AMT",
    "UK3CB_ION_I_Desert_Orca",
    "UK3CB_ION_I_Urban_Merlin",
    "UK3CB_MEC_I_Bell412",
    "I_Heli_light_03_unarmed_F",
    "I_Heli_EC_01A_military_RF",
    "I_C_Heli_Light_01_civil_F",
    "C_IDAP_Heli_EC_01A_civ_RF",
    "C_IDAP_Heli_Transport_02_F",
    "UK3CB_C_Bell412_Civ_IDAP",
    "UK3CB_C_UH1H",
    "C_Heli_Light_01_civil_F",
    "RHS_Mi8t_civilian",
    "rhs_mi8amt_civilian"
];

// If the BLUFOR centroid is within _minDist m of BASE_1 (2D), push SAD/LZ target outward so fixed-wing does not get a point on top of HQ.
FADE_opforAir_adjustTargetAwayFromBase = {
    params ["_target2", ["_minDist", 1000]];
    if (count _target2 < 2) exitWith { _target2 };
    private _base = missionNamespace getVariable ["BASE_1", objNull];
    if (isNull _base) exitWith { _target2 };
    private _bp = getPosATL _base;
    if ((_target2 distance2D _bp) >= _minDist) exitWith { _target2 };
    private _dir = _bp getDir _target2;
    private _p = _bp getPos [_minDist + 150, _dir];
    [_p select 0, _p select 1]
};

FADE_opforAir_pickVehicleClass = {
    private _air = call FADE_getEnemyAirVehicleClasses;
    if (_air isEqualTo []) then {
        _air = FADE_opforAir_fallbackHeliClasses select { isClass (configFile >> "CfgVehicles" >> _x) };
    };
    if (_air isEqualTo []) exitWith { "O_Heli_Light_02_dynamicLoadout_F" };
    selectRandom _air
};

FADE_opforAir_doSpawn = {
    if (!isServer) exitWith {};
    private _arr = missionNamespace getVariable ["FADE_opforAir_active", []];
    private _targetASL = call FADE_opforAir_getTargetASL;
    private _target2 = [_targetASL select 0, _targetASL select 1];
    private _dirFrom = random 360;
    private _dist = 2800 + random 700;
    private _spawn2 = [
        (_target2 select 0) + _dist * (sin _dirFrom),
        (_target2 select 1) + _dist * (cos _dirFrom)
    ];
    private _mapMinA = missionNamespace getVariable ["FADE_mapMin", 0];
    private _mapMaxA = missionNamespace getVariable ["FADE_mapMax", worldSize];
    private _edgePad = 200;
    _spawn2 set [0, (_spawn2 select 0) max (_mapMinA + _edgePad) min (_mapMaxA - _edgePad)];
    _spawn2 set [1, (_spawn2 select 1) max (_mapMinA + _edgePad) min (_mapMaxA - _edgePad)];
    private _alt = (getTerrainHeightASL [_spawn2 select 0, _spawn2 select 1]) + 280 + random 220;
    private _spawnPos = [_spawn2 select 0, _spawn2 select 1, _alt];
    private _class = call FADE_opforAir_pickVehicleClass;
    private _face = ((_target2 select 1) - (_spawn2 select 1)) atan2 ((_target2 select 0) - (_spawn2 select 0));

    private _veh = createVehicle [_class, _spawnPos, [], 0, "FLY"];
    if (isNull _veh) exitWith {};
    _veh setDir _face;
    private _cargoCap0 = _veh emptyPositions "cargo";
    private _crewUnits = missionNamespace getVariable ["FADE_enemyUnits", []];
    if (_crewUnits isEqualTo []) then { _crewUnits = [] call (missionNamespace getVariable ["FADE_resolveScenarioEnemyUnits", { [] }]) };
    if (_crewUnits isEqualTo []) then { _crewUnits = +(missionNamespace getVariable ["FADE_fallbackEnemyUnits", ["O_Soldier_F"]]) };
    { if (!isNull _x) then { deleteVehicle _x } } forEach crew _veh;
    private _sideE = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _grp = createGroup _sideE;
    private _driver = _grp createUnit [selectRandom _crewUnits, _spawnPos, [], 0, "NONE"];
    if (!isNull _driver) then { _driver moveInDriver _veh; _grp selectLeader _driver };
    if (_veh emptyPositions "gunner" > 0) then {
        private _gun = _grp createUnit [selectRandom _crewUnits, _spawnPos, [], 0, "NONE"];
        if (!isNull _gun) then { _gun moveInGunner _veh };
    };
    if (_veh emptyPositions "commander" > 0) then {
        private _cmd = _grp createUnit [selectRandom _crewUnits, _spawnPos, [], 0, "NONE"];
        if (!isNull _cmd) then { _cmd moveInCommander _veh };
    };
    if (isNull driver _veh) exitWith { { if (!isNull _x) then { deleteVehicle _x } } forEach units _grp; deleteGroup _grp; deleteVehicle _veh };
    private _facApply = missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}];
    if (!(_facApply isEqualTo {})) then { [_grp] call _facApply };
    _grp setGroupIdGlobal [format ["OPF-AIR-%1", floor random 999]];
    _grp setBehaviour "COMBAT";
    _grp setCombatMode "RED";
    _veh flyInHeight (180 + random 120);

    private _sadTgt = [_target2, 1000] call FADE_opforAir_adjustTargetAwayFromBase;
    private _isPlane = _veh isKindOf "Plane";
    private _isHeli = _veh isKindOf "Helicopter";
    private _cargoCap = _cargoCap0;

    if (_isPlane) then {
        private _wp = _grp addWaypoint [_sadTgt + [0], 0];
        _wp setWaypointType "SAD";
        _wp setWaypointBehaviour "COMBAT";
        _wp setWaypointCombatMode "RED";
    } else {
        if (_isHeli) then {
            private _grpInf = grpNull;
            if (_cargoCap >= 2) then {
                _grpInf = createGroup _sideE;
                private _maxFill = _cargoCap min 12;
                private _k = 0;
                while { _veh emptyPositions "cargo" > 0 && _k < _maxFill } do {
                    _k = _k + 1;
                    private _u = _grpInf createUnit [selectRandom _crewUnits, _spawnPos, [], 0, "NONE"];
                    if (isNull _u) exitWith {};
                    _u moveInCargo _veh;
                };
                if (count units _grpInf == 0) then {
                    deleteGroup _grpInf;
                    _grpInf = grpNull;
                } else {
                    if (!(_facApply isEqualTo {})) then { [_grpInf] call _facApply };
                    _grpInf setGroupIdGlobal [format ["OPF-AIR-INF-%1", floor random 999]];
                    _grpInf setBehaviour "COMBAT";
                    _grpInf setCombatMode "RED";
                    private _wpMove = _grpInf addWaypoint [_target2 + [0], 0];
                    _wpMove setWaypointType "MOVE";
                    _wpMove setWaypointBehaviour "COMBAT";
                    _wpMove setWaypointCombatMode "RED";
                    private _wpInfSad = _grpInf addWaypoint [_target2 + [0], 0];
                    _wpInfSad setWaypointType "SAD";
                    _wpInfSad setWaypointBehaviour "COMBAT";
                    _wpInfSad setWaypointCombatMode "RED";
                    _veh setVariable ["FADE_opforAirCargoGrp", _grpInf];
                };
            } else {
                if (_cargoCap > 0) then {
                    _grpInf = createGroup _sideE;
                    private _k = 0;
                    while { _veh emptyPositions "cargo" > 0 && _k < _cargoCap } do {
                        _k = _k + 1;
                        private _u = _grpInf createUnit [selectRandom _crewUnits, _spawnPos, [], 0, "NONE"];
                        if (isNull _u) exitWith {};
                        _u moveInCargo _veh;
                    };
                    if (count units _grpInf == 0) then {
                        deleteGroup _grpInf;
                    } else {
                        if (!(_facApply isEqualTo {})) then { [_grpInf] call _facApply };
                        _veh setVariable ["FADE_opforAirCargoGrp", _grpInf];
                    };
                };
                private _wpSad = _grp addWaypoint [_sadTgt + [0], 0];
                _wpSad setWaypointType "SAD";
                _wpSad setWaypointBehaviour "COMBAT";
                _wpSad setWaypointCombatMode "RED";
            };

            if (_cargoCap >= 2 && { !isNull (_veh getVariable ["FADE_opforAirCargoGrp", grpNull]) }) then {
                private _lz = [_target2] call FADE_findSafeLZ;
                if (_lz isEqualTo []) then { _lz = +_target2 };
                private _lz2 = [_lz select 0, _lz select 1];
                private _wpUnload = _grp addWaypoint [_lz2 + [0], 0];
                _wpUnload setWaypointType "TR UNLOAD";
                _wpUnload setWaypointBehaviour "COMBAT";
                _wpUnload setWaypointCombatMode "RED";
                private _wpHeliSad = _grp addWaypoint [_sadTgt + [0], 0];
                _wpHeliSad setWaypointType "SAD";
                _wpHeliSad setWaypointBehaviour "COMBAT";
                _wpHeliSad setWaypointCombatMode "RED";
            };
            if (count waypoints _grp == 0) then {
                private _wpSadOnly = _grp addWaypoint [_sadTgt + [0], 0];
                _wpSadOnly setWaypointType "SAD";
                _wpSadOnly setWaypointBehaviour "COMBAT";
                _wpSadOnly setWaypointCombatMode "RED";
            };
        } else {
            private _wp = _grp addWaypoint [_sadTgt + [0], 0];
            _wp setWaypointType "SAD";
            _wp setWaypointBehaviour "COMBAT";
            _wp setWaypointCombatMode "RED";
        };
    };

    [_veh, _crewUnits] call FADE_ensureEnemyVehicleGunner;
    if (!(_facApply isEqualTo {})) then { [_grp] call _facApply };
    _arr pushBack _veh;
    missionNamespace setVariable ["FADE_opforAir_active", _arr];
    missionNamespace setVariable ["FADE_opforAir_lastSpawnTime", time];
    _veh setVariable ["FADE_opforAirAsset", true, true];
    _grp setVariable ["FADE_opforAirAsset", true, true];
};

FADE_opforAir_trySpawn = {
    if (!isServer) exitWith {};
    private _friendlySide = [missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"]] call FADE_opforAir_sideFromFactionCfg;
    private _players0 = playableUnits select { side _x == _friendlySide && { alive _x } && { isPlayer _x } };
    private _base0 = missionNamespace getVariable ["BASE_1", objNull];
    private _hqR = missionNamespace getVariable ["FADE_opforAir_hqSafeRadius", 1000];
    private _atHqSuppressed = false;
    if (!isNull _base0 && { count _players0 > 0 }) then {
        private _bp0 = getPosATL _base0;
        private _allAtHq = true;
        {
            if ((getPosATL _x) distance2D _bp0 > _hqR) exitWith { _allAtHq = false };
        } forEach _players0;
        if (_allAtHq) then {
            private _arrH = missionNamespace getVariable ["FADE_opforAir_active", []];
            _arrH = _arrH select { !isNull _x && { alive _x } };
            missionNamespace setVariable ["FADE_opforAir_active", _arrH];
            if (count _arrH > 0) then { call FADE_opforAir_despawnAll; };
            missionNamespace setVariable ["FADE_opforAir_pendingUntil", -1];
            _atHqSuppressed = true;
        };
    };
    if (_atHqSuppressed) exitWith {};
    private _setting = missionNamespace getVariable ["FADE_opforAirSetting", "Off"];
    if (_setting == "Off") exitWith {};
    private _maxActive = if (_setting == "Low") then { 1 } else { 2 };
    private _cooldown = if (_setting == "Low") then { 600 } else { 300 };
    private _arr = missionNamespace getVariable ["FADE_opforAir_active", []];
    _arr = _arr select { !isNull _x && { alive _x } };
    missionNamespace setVariable ["FADE_opforAir_active", _arr];
    if (count _arr >= _maxActive) exitWith { missionNamespace setVariable ["FADE_opforAir_pendingUntil", -1]; };
    private _last = missionNamespace getVariable ["FADE_opforAir_lastSpawnTime", -1e9];
    if (time - _last < _cooldown) exitWith {};
    private _hasPl = false;
    { if (side _x == _friendlySide && { alive _x } && { isPlayer _x }) exitWith { _hasPl = true } } forEach playableUnits;
    if (!_hasPl) exitWith { missionNamespace setVariable ["FADE_opforAir_pendingUntil", -1]; };

    if (!(call FADE_opforAir_opforDetectsBlufor)) exitWith { missionNamespace setVariable ["FADE_opforAir_pendingUntil", -1]; };

    private _pending = missionNamespace getVariable ["FADE_opforAir_pendingUntil", -1];
    private _dMin = missionNamespace getVariable ["FADE_opforAir_responseDelayMin", 40];
    private _dExt = missionNamespace getVariable ["FADE_opforAir_responseDelayExtra", 200];
    if (_pending < 0) then {
        missionNamespace setVariable ["FADE_opforAir_pendingUntil", time + _dMin + random _dExt];
    } else {
        if (time >= _pending) then {
            _arr = missionNamespace getVariable ["FADE_opforAir_active", []];
            _arr = _arr select { !isNull _x && { alive _x } };
            missionNamespace setVariable ["FADE_opforAir_active", _arr];
            if (count _arr >= _maxActive) exitWith { missionNamespace setVariable ["FADE_opforAir_pendingUntil", -1]; };
            if (!(call FADE_opforAir_opforDetectsBlufor)) exitWith { missionNamespace setVariable ["FADE_opforAir_pendingUntil", -1]; };
            call FADE_opforAir_doSpawn;
            missionNamespace setVariable ["FADE_opforAir_pendingUntil", -1];
        };
    };
};

// Apply scenario settings from GUI - SERVER-SIDE GLOBAL: all mission spawns use these unit/vehicle lists.
// When a player clicks Apply, this runs on the server and overwrites missionNamespace; Missions.sqf (and other scripts) read from missionNamespace.
FADE_applyScenarioSettings = {
    // Scenario GUI sends one wrapped array so remoteExec always delivers a single _this (reliable with many args on dedicated servers).
    params ["_args"];
    if !(_args isEqualType []) exitWith {};
    _args params ["_hour", "_weather", "_enemyFaction", "_friendlyFaction", "_civFaction", ["_limitGear", false], ["_presetOnly", false], ["_player", objNull], ["_patrolsEnabled", false], ["_enemySkill", 0.2], ["_enemyRouting", 0], ["_enemyAAA", "Off"], ["_civiliansEnabled", true], ["_aoStrength", "Medium"], ["_timeCompressionScale", 1], ["_opforPopulationSetting", "Auto"], ["_teleportToPlayerMode", 0], ["_opforLauncherSetting", "Normal"], ["_opforAirSetting", "Off"], ["_operationZoneCount", 6], ["_weatherParams", []], ["_civGlobalMaxAlive", 55], ["_civDensityScale", 1], ["_civTalkInterpretersOnly", false], ["_intelSpecialistsOnly", false]];
    FADE_getUnitsForFaction_cache = createHashMap;
    FADE_getCivVehiclesForFaction_cache = createHashMap;
    missionNamespace setVariable ["FADE_enemyAirVehicleClasses_cache", []];
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
    missionNamespace setVariable ["FADE_opforPopulationSetting", _opforPopulationSetting, true];
    missionNamespace setVariable ["FADE_opforLauncherSetting", _opforLauncherSetting, true];
    missionNamespace setVariable ["FADE_opforAirSetting", _opforAirSetting, true];
    _operationZoneCount = (round _operationZoneCount) max 2 min 10;
    missionNamespace setVariable ["FADE_operationZoneCount", _operationZoneCount, true];
    if (_opforAirSetting == "Off") then { call FADE_opforAir_despawnAll };
    private _opforResolved = [_opforPopulationSetting] call FADE_resolveOpforPopulationScale;
    private _opforScale = _opforResolved select 0;
    private _opforScaleLabel = _opforResolved select 1;
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
    private _enemyDn = [_enemyFaction] call FADE_getFactionDisplayName;
    private _friendlyDn = [_friendlyFaction] call FADE_getFactionDisplayName;
    private _civDn = [_civFaction] call FADE_getFactionDisplayName;
    private _skillDn = if (_enemySkill <= 0.35) then { "low" } else { if (_enemySkill <= 0.6) then { "medium" } else { if (_enemySkill <= 0.85) then { "high" } else { "very high" } } };
    private _patrolW = if (_patrolsEnabled) then { "on" } else { "off" };
    private _routeW = if (_enemyRouting > 0) then { "on" } else { "off" };
    private _airLc = toLower _opforAirSetting;
    private _atLc = toLower _opforLauncherSetting;
    private _summaryParts = [
        format ["patrols %1", _patrolW],
        format ["%1 AI", _skillDn],
        format ["routing %1", _routeW],
        format ["AAA %1", toLower _enemyAAA],
        format ["%1 towns", str _operationZoneCount],
        format ["OPFOR %1", toLower _opforScaleLabel]
    ];
    if (_opforLauncherSetting != "Normal") then { _summaryParts pushBack format ["AT %1", _atLc] };
    if (_opforAirSetting != "Off") then { _summaryParts pushBack format ["air %1", _airLc] };
    private _summaryLine = _summaryParts joinString " | ";
    private _civBlock = if (_civiliansEnabled) then {
        format ["<t align='left' color='#A8B8C8' size='0.9'>Civilians</t> <t color='#D4C4A8'>%1</t><br/>", _civDn]
    } else {
        "<t align='left' color='#C8A090' size='0.9'>Ambient civilians off</t><br/>"
    };
    private _extras = [];
    if (_limitGear) then { _extras pushBack "BLUFOR gear limited to faction" };
    if (_presetOnly) then { _extras pushBack "Preset loadouts only" };
    if (((round _teleportToPlayerMode) max 0 min 1) > 0) then { _extras pushBack "Redeploy: squad leaders only" };
    if (_civTalkInterpretersOnly) then { _extras pushBack "Civilian talk: interpreters only" };
    if (_intelSpecialistsOnly) then { _extras pushBack "Intel read: specialists only" };
    private _tc = (_timeCompressionScale max 1) min 100;
    if (_tc != 1) then { _extras pushBack format ["Mission time %1x", _tc] };
    private _extraBlock = if (count _extras > 0) then {
        format ["<br/><t align='left' color='#8FA0B0' size='0.85'>%1</t>", _extras joinString "<br/>"]
    } else { "" };
    private _hintText =
        "<t size='1.12' color='#8CB4E8' align='center'>Scenario updated</t>" +
        "<br/><br/>" +
        format [
            "<t align='left' color='#9AAAB8' size='0.9'>Mission clock</t> <t color='#D0E4FF' size='0.95'>%1 ZULU</t><br/>" +
            "<t align='left' color='#9AAAB8' size='0.9'>Weather</t> <t color='#D0E4FF' size='0.95'>%2</t><br/><br/>" +
            "<t align='left' color='#9AAAB8' size='0.9'>Friendly</t> <t color='#A8DDB0' size='0.95'>%3</t><br/>" +
            "<t align='left' color='#9AAAB8' size='0.9'>Enemy</t> <t color='#E0A8A8' size='0.95'>%4</t><br/>" +
            "%5<br/>" +
            "<t align='left' color='#8FA0B0' size='0.88'>%6</t>" +
            "%7",
            _hourStr,
            _weather,
            _friendlyDn,
            _enemyDn,
            _civBlock,
            _summaryLine,
            _extraBlock
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
missionNamespace setVariable ["FADE_opforPopulationSetting", missionNamespace getVariable ["FADE_opforPopulationSetting", "Auto"], true];
missionNamespace setVariable ["FADE_opforLauncherSetting", missionNamespace getVariable ["FADE_opforLauncherSetting", "Normal"], true];
missionNamespace setVariable ["FADE_opforAirSetting", missionNamespace getVariable ["FADE_opforAirSetting", "Off"], true];
private _opforInit = [missionNamespace getVariable ["FADE_opforPopulationSetting", "Auto"]] call FADE_resolveOpforPopulationScale;
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

