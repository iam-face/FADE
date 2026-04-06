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
call compile preprocessFileLineNumbers "rsc\OperationNames.sqf";
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
        {
            private _cfg = _x;
            if (getNumber (_cfg >> "side") != _sideNum) then { continue };
            private _dn = toLower getText (_cfg >> "displayName");
            if (_dn == "") then { continue };
            {
                private _pref = toLower _x;
                if (_pref != "" && { _dn find _pref >= 0 }) exitWith { _picked = configName _cfg };
            } forEach _preferredDisplayNames;
            if (_picked != _fallbackFaction) exitWith {};
        } forEach _allFc;
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

// Lobby params (description.ext class Params): mission/scenario GUI access + ACE Arsenal action toggle
private _params = if (!isNil "paramsArray" && { paramsArray isEqualType [] }) then { paramsArray } else { [] };
missionNamespace setVariable ["FAC_param_missionsGuiAccess", _params param [0, 0], true];
missionNamespace setVariable ["FAC_param_scenarioGuiAccess", _params param [1, 0], true];
missionNamespace setVariable ["FAC_param_enableAceArsenalActions", _params param [2, 1], true];
publicVariable "FAC_param_missionsGuiAccess";
publicVariable "FAC_param_scenarioGuiAccess";
publicVariable "FAC_param_enableAceArsenalActions";
missionNamespace setVariable ["FADE_teleportToPlayerMode", missionNamespace getVariable ["FADE_teleportToPlayerMode", 0], true];
publicVariable "FADE_teleportToPlayerMode";

// Access helper: admin and Zeus can override leader-only restrictions.
FADE_playerHasLeaderOverrideAccess = {
    params ["_player"];
    if (isNull _player) exitWith { false };
    private _isAdmin = (admin (owner _player)) > 0;
    private _isZeus = !isNull (getAssignedCuratorLogic _player);
    _isAdmin || _isZeus
};
FADE_playerCanUseMissionsGui = {
    params ["_player"];
    if (isNull _player) exitWith { false };
    private _mode = missionNamespace getVariable ["FAC_param_missionsGuiAccess", 0];
    if (_mode <= 0) exitWith { true };
    (leader group _player == _player) || { [_player] call FADE_playerHasLeaderOverrideAccess }
};
FADE_playerCanUseScenarioGui = {
    params ["_player"];
    if (isNull _player) exitWith { false };
    private _mode = missionNamespace getVariable ["FAC_param_scenarioGuiAccess", 0];
    if (_mode <= 0) exitWith { true };
    (leader group _player == _player) || { [_player] call FADE_playerHasLeaderOverrideAccess }
};

// Loadout GUI helpers on server: resolve CTB/std loadouts for squad-leader "apply to squadmate" (no dialog on server)
call compile preprocessFileLineNumbers "rsc\LoadoutGui.sqf";

FAC_loadoutGui_serverRequestApplyToMember = {
    if (!isServer) exitWith {};
    params [["_requester", objNull], ["_targetNetId", "", [""]], ["_rowKey", "", [""]]];
    if (isNull _requester || {!isPlayer _requester}) exitWith {};
    private _canLead = (leader group _requester == _requester) || { [_requester] call FADE_playerHasLeaderOverrideAccess };
    if (!_canLead) exitWith {
        ["Loadout: only group leaders (or admin/Zeus) can apply loadouts to squadmates."] remoteExec ["systemChat", _requester];
    };
    if (_targetNetId == "" || _rowKey == "") exitWith {
        ["Loadout: invalid request."] remoteExec ["systemChat", _requester];
    };
    private _target = objectFromNetId _targetNetId;
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
    private _limitCtb = missionNamespace getVariable ["FADE_limitToCtbLoadouts", false];

    if (_limitCtb && { (_rowKey find "CTB:") != 0 }) exitWith {
        ["Loadout: scenario allows CTB presets only."] remoteExec ["systemChat", _requester];
    };

    private _loadout = [];
    private _m = 0;
    private _eng = false;
    private _exp = false;

    if ((_rowKey find "CTB:") == 0) then {
        if (!([] call FAC_loadoutGui_ensureCtbData)) exitWith {
            ["Loadout: CTB data unavailable on server."] remoteExec ["systemChat", _requester];
        };
        private _raw = [_rowKey] call FAC_loadoutGui_getCtbLoadoutByKey;
        _loadout = [_raw] call FAC_loadoutGui_resolveCtbLoadoutArray;
        if ((count _loadout) < 10) exitWith {
            ["Loadout: could not resolve that CTB preset on the server."] remoteExec ["systemChat", _requester];
        };
        private _roleDn = "";
        { if ((_x select 0) == _rowKey) exitWith { _roleDn = _x select 1 } } forEach ([] call FAC_loadoutGui_buildCtbEntries);
        private _tr = [_roleDn] call FAC_loadoutGui_getCtbRoleTraits;
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

// Resolve scenario unit class arrays: authoritative order is CfgGroups/cache from current scenario faction keys,
// then missionNamespace lists (Apply may have stored vanilla fallbacks when CfgGroups was empty), then hard fallbacks.
// Missions.sqf used to prefer FADE_friendlyUnits first; those arrays can alias getUnitsForFaction cache entries or
// drift from FADE_scenario*Faction if lists were not rebuilt — missions then ignored GUI faction picks.
FADE_resolveScenarioFriendlyUnits = {
    params [["_fallback", []]];
    private _ff = missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"];
    private _snF = missionNamespace getVariable ["FADE_scenarioFriendlySideNum", 1];
    private _units = [_ff, _snF] call FADE_getUnitsForFaction;
    if (_units isEqualTo []) then {
        _units = +(missionNamespace getVariable ["FADE_friendlyUnits", _fallback]);
    };
    if (_units isEqualTo []) then {
        _units = +(missionNamespace getVariable ["FADE_fallbackFriendlyUnits", ["B_Soldier_TL_F", "B_Soldier_F", "B_Soldier_AR_F", "B_medic_F"]]);
    };
    private _filter = missionNamespace getVariable ["FADE_filterUnitsArmed", { _this select 0 }];
    [_units] call _filter
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
        _units = +(missionNamespace getVariable ["FADE_fallbackEnemyUnits", ["O_Soldier_TL_F", "O_Soldier_F", "O_Soldier_AR_F"]]);
    };
    private _filter = missionNamespace getVariable ["FADE_filterEnemyUnitsArmed", { _this select 0 }];
    [_units] call _filter
};
missionNamespace setVariable ["FADE_resolveScenarioFriendlyUnits", FADE_resolveScenarioFriendlyUnits];
missionNamespace setVariable ["FADE_resolveScenarioEnemyUnits", FADE_resolveScenarioEnemyUnits];

// [x,y] or [x,y,z] ATL helper; used with FADE_findSafePosArray when BIS_fnc_findSafePos returns a scalar.
FADE_normPos3 = {
    params ["_p"];
    if (!(_p isEqualType []) || { count _p < 2 }) exitWith { [0, 0, 0] };
    if (count _p < 3) then { [(_p select 0), (_p select 1), 0] } else { _p }
};
// BIS_fnc_findSafePos can return a scalar; normalize to a 3-vector or fallback.
FADE_findSafePosArray = {
    params ["_args", "_fallback"];
    private _r = _args call BIS_fnc_findSafePos;
    if (!(_r isEqualType [])) exitWith { [_fallback] call FADE_normPos3 };
    if (count _r < 2) exitWith { [_fallback] call FADE_normPos3 };
    [_r] call FADE_normPos3
};
missionNamespace setVariable ["FADE_normPos3", FADE_normPos3];
missionNamespace setVariable ["FADE_findSafePosArray", FADE_findSafePosArray];

// Operation mission: BLUFOR players / OPFOR men within horizontal radius (distance2D).
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

// BIS_fnc_taskCreate expects missionNamespace bis_fnc_tasksetparent (lowercase) on some builds.
// Do not assign BIS_fnc_taskSetParent from CfgFunctions here: it can lazy-load fn_taskSetParent.sqf on
// first invoke; if that file is missing (broken/mismatched install), taskCreate errors (see RPT).
FADE_ensureBisTaskSetParent = {
    private _existing = missionNamespace getVariable ["bis_fnc_tasksetparent", {}];
    if (!(_existing isEqualTo {})) exitWith {};
    private _tspParent = compile preprocessFileLineNumbers "A3\functions_f\Tasks\fn_taskSetParent.sqf";
    if (_tspParent isEqualTo {}) then {
        _tspParent = compile preprocessFileLineNumbers "A3\Functions_F\Tasks\fn_taskSetParent.sqf";
    };
    if (_tspParent isEqualTo {}) then {
        _tspParent = {
            params ["_taskID", ["_parentTaskID", "", [""]], ["_parentTaskType", "", [""]]];
            true
        };
    };
    missionNamespace setVariable ["bis_fnc_tasksetparent", _tspParent];
};
call FADE_ensureBisTaskSetParent;

// CfgFactionClasses >> side (0–3) -> Arma side / marker colors — missions must not assume EAST/WEST when factions are Independent etc.
FADE_getFactionSideNum = {
    params ["_faction", "_default"];
    if (_faction == "") exitWith { _default };
    private _cfg = configFile >> "CfgFactionClasses" >> _faction;
    if (!isClass _cfg) exitWith { _default };
    private _n = getNumber (_cfg >> "side");
    if (_n < 0 || _n > 3) exitWith { _default };
    _n
};
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

// Returns array of enemy vehicle classnames for faction; uses cache
FADE_getEnemyVehiclesForFaction = {
    params ["_faction"];
    if (_faction == "") exitWith { [] };
    FADE_enemyVehiclesByFaction getOrDefault [_faction, []]
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

// Resolve OPFOR population setting into a concrete multiplier.
// Auto mode scales by connected human players; manual modes map directly to fixed multipliers.
FADE_resolveOpforPopulationScale = {
    params [["_setting", "Normal"]];
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
            private _auto = if (_players <= 2) then { 0.5 } else { if (_players <= 10) then { 1 } else { if (_players <= 15) then { 1.5 } else { 2 } } };
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

// Enemy group skill/routing/launcher policy from Scenario (Missions / AO / Operation / checkpoints / counter-attack).
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

// OPFOR ambient air threat (P24): optional, hard-capped + cooldown; spawns only after OPFOR AI detects BLUFOR (knowsAbout), after a random delay (vectoring / scramble), flying toward players/base.
missionNamespace setVariable ["FADE_opforAir_active", []];
missionNamespace setVariable ["FADE_opforAir_lastSpawnTime", -1e9];
missionNamespace setVariable ["FADE_opforAir_pendingUntil", -1];

// knowsAbout >= ~1.5: target type known / combat contact (wiki scale 0–4).
FADE_opforAir_knowsAboutThreshold = 1.45;
// Random delay (seconds) after detection before spawn: min + random extra (comms + takeoff).
FADE_opforAir_responseDelayMin = 40;
FADE_opforAir_responseDelayExtra = 200;

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
    private _thr = missionNamespace getVariable ["FADE_opforAir_knowsAboutThreshold", 1.45];
    private _players = playableUnits select { side _x == _friendlySide && { alive _x } && { isPlayer _x } };
    if (_players isEqualTo []) exitWith { false };
    private _found = false;
    {
        if (side _x == _enemySide && { alive _x } && { _x isKindOf "CAManBase" }) then {
            private _op = _x;
            {
                if ((_op knowsAbout _x) >= _thr) exitWith { _found = true };
            } forEach _players;
            if (_found) exitWith {};
        };
    } forEach allUnits;
    _found
};

FADE_opforAir_despawnAll = {
    if (!isServer) exitWith {};
    missionNamespace setVariable ["FADE_opforAir_pendingUntil", -1];
    private _arr = missionNamespace getVariable ["FADE_opforAir_active", []];
    {
        if (!isNull _x && { alive _x }) then {
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
    private _hs = worldSize / 2;
    [_hs, _hs, 100]
};

FADE_opforAir_pickVehicleClass = {
    private _vehicles = missionNamespace getVariable ["FADE_enemyVehicles", []];
    private _air = [];
    {
        private _c = _x;
        private _cl = toLower _c;
        if ((_cl find "uav" < 0) && { _cl find "drone" < 0 }) then {
            if (_c isKindOf "Helicopter" || { _c isKindOf "Plane" }) then { _air pushBack _c };
        };
    } forEach _vehicles;
    if (_air isEqualTo []) then {
        private _sn = missionNamespace getVariable ["FADE_scenarioEnemySideNum", 0];
        _air = switch (_sn) do {
            case 1: { ["B_Heli_Attack_01_dynamicLoadout_F", "B_Heli_Light_01_dynamicLoadout_F", "B_Plane_CAS_01_dynamicLoadout_F"] };
            case 2: { ["I_Heli_light_03_dynamicLoadout_F", "I_Plane_Fighter_03_CAS_F"] };
            default { ["O_Heli_Attack_02_dynamicLoadout_F", "O_Heli_Light_02_dynamicLoadout_F", "O_Plane_CAS_02_F"] };
        };
        _air = _air select { isClass (configFile >> "CfgVehicles" >> _x) };
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
    _spawn2 set [0, (_spawn2 select 0) max 200 min (worldSize - 200)];
    _spawn2 set [1, (_spawn2 select 1) max 200 min (worldSize - 200)];
    private _alt = (getTerrainHeightASL [_spawn2 select 0, _spawn2 select 1]) + 280 + random 220;
    private _spawnPos = [_spawn2 select 0, _spawn2 select 1, _alt];
    private _class = call FADE_opforAir_pickVehicleClass;
    private _face = ((_target2 select 1) - (_spawn2 select 1)) atan2 ((_target2 select 0) - (_spawn2 select 0));

    private _veh = createVehicle [_class, _spawnPos, [], 0, "FLY"];
    if (isNull _veh) exitWith {};
    _veh setDir _face;
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
    private _wp = _grp addWaypoint [_target2 + [0], 0];
    _wp setWaypointType "SAD";
    _wp setWaypointBehaviour "COMBAT";
    _wp setWaypointCombatMode "RED";

    _arr pushBack _veh;
    missionNamespace setVariable ["FADE_opforAir_active", _arr];
    missionNamespace setVariable ["FADE_opforAir_lastSpawnTime", time];
    _veh setVariable ["FADE_opforAirAsset", true, true];
    _grp setVariable ["FADE_opforAirAsset", true, true];
};

FADE_opforAir_trySpawn = {
    if (!isServer) exitWith {};
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
    private _friendlySide = [missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"]] call FADE_opforAir_sideFromFactionCfg;
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
    _args params ["_hour", "_weather", "_enemyFaction", "_friendlyFaction", "_civFaction", ["_limitGear", false], ["_ctbOnly", false], ["_player", objNull], ["_patrolsEnabled", false], ["_enemySkill", 0.2], ["_enemyRouting", 0], ["_enemyAAA", "None"], ["_civiliansEnabled", true], ["_aoStrength", "Medium"], ["_timeCompressionScale", 1], ["_opforPopulationSetting", "Normal"], ["_teleportToPlayerMode", 0], ["_opforLauncherSetting", "Normal"], ["_opforAirSetting", "Off"], ["_operationZoneCount", 6]];
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
    missionNamespace setVariable ["FADE_enemyAAALevel", _enemyAAA];
    missionNamespace setVariable ["FADE_civiliansEnabled", _civiliansEnabled];
    missionNamespace setVariable ["FADE_aoStrength", _aoStrength];
    missionNamespace setVariable ["FADE_timeCompressionScale", (_timeCompressionScale max 1) min 100, true];
    missionNamespace setVariable ["FADE_teleportToPlayerMode", (round _teleportToPlayerMode) max 0 min 1, true];
    missionNamespace setVariable ["FADE_limitToCtbLoadouts", _ctbOnly];
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

    if (_enemyUnits isEqualTo []) then { _enemyUnits = +(missionNamespace getVariable ["FADE_fallbackEnemyUnits", ["O_Soldier_TL_F", "O_Soldier_F", "O_Soldier_AR_F"]]) };
    if (_friendlyUnits isEqualTo []) then { _friendlyUnits = +(missionNamespace getVariable ["FADE_fallbackFriendlyUnits", ["B_Soldier_TL_F", "B_Soldier_F", "B_Soldier_AR_F", "B_medic_F"]]) };
    _enemyUnits = [_enemyUnits] call FADE_filterUnitsArmed;
    _friendlyUnits = [_friendlyUnits] call FADE_filterUnitsArmed;
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
        "<t size='1.0' color='#E8E8E8'>Enemy AI:</t> <t color='#E0E0E0'>%8 skill, routing %9, AAA %10</t><br/>" +
        "<t size='1.0' color='#E8E8E8'>AO mission strength:</t> <t color='#E0E0E0'>%11</t> <t color='#AAAAAA'>(Config / not in Scenario GUI)</t><br/>" +
        "<t size='1.0' color='#E8E8E8'>OPFOR population:</t> <t color='#E0E0E0'>%12</t><br/>" +
        "<t size='1.0' color='#E8E8E8'>OPFOR AT launchers:</t> <t color='#E0E0E0'>%13</t><br/>" +
        "<t size='1.0' color='#E8E8E8'>OPFOR air:</t> <t color='#E0E0E0'>%14</t><br/>" +
        "<t size='1.0' color='#E8E8E8'>Operation towns:</t> <t color='#E0E0E0'>%15</t><br/>" +
        "<t size='1.0' color='#E8E8E8'>Redeploy:</t> <t color='#E0E0E0'>teleport-to-player %16</t><br/>" +
        "<t size='1.0' color='#E8E8E8'>Loadouts:</t> <t color='#E0E0E0'>BLUFOR-limited %17, CTB-only %18</t><br/>" +
        "<t size='1.0' color='#E8E8E8'>Time compression:</t> <t color='#E0E0E0'>%19x</t>",
        _hourStr, _weather, _friendlyDn, _enemyDn, _civDn, if (_civiliansEnabled) then { "enabled" } else { "disabled" },
        if (_patrolsEnabled) then { "ON" } else { "OFF" },
        _skillDn, if (_enemyRouting > 0) then { "ON" } else { "OFF" }, _enemyAAA, _aoStrength,
        _opforScaleLabel,
        _opforLauncherSetting,
        _opforAirSetting,
        str _operationZoneCount,
        if (((round _teleportToPlayerMode) max 0 min 1) > 0) then { "SL only" } else { "all players" },
        if (_limitGear) then { "ON" } else { "OFF" },
        if (_ctbOnly) then { "ON" } else { "OFF" },
        (_timeCompressionScale max 1) min 100
    ];
    [_hintText] remoteExec ["FADE_showMissionHint", 0];
    // Sync scenario config to clients so Loadout/Vehicle GUIs can respect loadout limits
    [_friendlyFaction, _limitGear, _ctbOnly] remoteExec ["FADE_syncScenarioConfig", 0, true];
    publicVariable "FADE_friendlyUnits";
    publicVariable "FADE_enemyUnits";
    publicVariable "FADE_friendlyVehicleClasses";
    publicVariable "FADE_limitToCtbLoadouts";
    publicVariable "FADE_teleportToPlayerMode";
    publicVariable "FADE_sideEnemy";
    publicVariable "FADE_sideFriendly";
    publicVariable "FADE_scenarioEnemySideNum";
    publicVariable "FADE_scenarioFriendlySideNum";
    publicVariable "FADE_markerColorEnemy";
    publicVariable "FADE_markerColorFriendly";

    // Reapply AAA level (despawn existing, spawn new if Light/Medium/Heavy)
    if (!isNil "FADE_aaa_applyLevel") then { call FADE_aaa_applyLevel };
};
FADE_sendScenarioConfigToClient = {
    params ["_player"];
    if (isNull _player) exitWith {};
    private _f = missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"];
    private _l = missionNamespace getVariable ["FADE_limitGearToFriendlyFaction", false];
    private _c = missionNamespace getVariable ["FADE_limitToCtbLoadouts", false];
    [_f, _l, _c] remoteExec ["FADE_syncScenarioConfig", _player];
};
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
publicVariable "FADE_normPos3";
publicVariable "FADE_findSafePosArray";
publicVariable "FADE_op_countBluforPlayersInRadius";
publicVariable "FADE_op_countEnemyMenInRadius";
publicVariable "FADE_ensureBisTaskSetParent";
publicVariable "FAC_applyEnemyScenarioToGroup";

// Initial build: scenario unit/vehicle lists on missionNamespace (server). Scenario GUI Apply overwrites these; all mission spawns read from here.
// Default to globals from FADE_pickFactionByDisplayName (above) + Config — missionNamespace keys are not set until here, so plain "OPF_F"/"BLU_F" defaults ignore startup faction picks.
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
if (_defEnemy isEqualTo []) then { _defEnemy = +(missionNamespace getVariable ["FADE_fallbackEnemyUnits", ["O_Soldier_TL_F", "O_Soldier_F", "O_Soldier_AR_F"]]) };
if (_defFriendly isEqualTo []) then { _defFriendly = +(missionNamespace getVariable ["FADE_fallbackFriendlyUnits", ["B_Soldier_TL_F", "B_Soldier_F", "B_Soldier_AR_F", "B_medic_F"]]) };
if (_defCiv isEqualTo []) then { _defCiv = ["C_man_1", "C_man_1_1_F", "C_man_polo_1_F"] };
if (_defCivVeh isEqualTo []) then { _defCivVeh = ["C_Offroad_01_F", "C_Hatchback_01_F", "C_SUV_01_F", "C_Van_01_transport_F"] };
_defEnemy = [_defEnemy] call FADE_filterUnitsArmed;
_defFriendly = [_defFriendly] call FADE_filterUnitsArmed;
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
missionNamespace setVariable ["FADE_limitToCtbLoadouts", missionNamespace getVariable ["FADE_limitToCtbLoadouts", false], true];
missionNamespace setVariable ["FADE_timeCompressionScale", missionNamespace getVariable ["FADE_timeCompressionScale", 1], true];
missionNamespace setVariable ["FADE_teleportToPlayerMode", missionNamespace getVariable ["FADE_teleportToPlayerMode", 0], true];
missionNamespace setVariable ["FADE_opforPopulationSetting", missionNamespace getVariable ["FADE_opforPopulationSetting", "Normal"], true];
missionNamespace setVariable ["FADE_opforLauncherSetting", missionNamespace getVariable ["FADE_opforLauncherSetting", "Normal"], true];
missionNamespace setVariable ["FADE_opforAirSetting", missionNamespace getVariable ["FADE_opforAirSetting", "Off"], true];
private _opforInit = [missionNamespace getVariable ["FADE_opforPopulationSetting", "Normal"]] call FADE_resolveOpforPopulationScale;
missionNamespace setVariable ["FADE_opforPopulationScale", _opforInit select 0, true];
publicVariable "FADE_currentMissionType";

// OPFOR ambient air (P24): bounded spawns toward BLUFOR players / base.
[] spawn {
    sleep 90;
    while { true } do {
        sleep 45;
        if (!isServer) exitWith {};
        call FADE_opforAir_trySpawn;
    };
};

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

// -----------------------------------------------------------------------------
// Pseudo time compression (server): exact real-time scaling with skipTime.
// IMPORTANT: no 'sleep' here (sleep is simulation-time and can cause runaway).
// Target: 100x means 100 mission-seconds per 1 real second.
// We keep engine 1x and add only extra: (scale - 1) * realDelta.
// -----------------------------------------------------------------------------
FADE_timeCompressionPollSec = 1;
[] spawn {
    private _lastTick = diag_tickTime;
    private _nextTick = _lastTick + FADE_timeCompressionPollSec;
    while { true } do {
        waitUntil { diag_tickTime >= _nextTick };
        private _now = diag_tickTime;
        private _realDelta = _now - _lastTick;
        _lastTick = _now;
        _nextTick = _now + FADE_timeCompressionPollSec;
        if (_realDelta <= 0) then { continue };

        private _scale = missionNamespace getVariable ["FADE_timeCompressionScale", 1];
        _scale = (_scale max 1) min 100;
        if (_scale <= 1) then { continue };

        // skipTime expects hours
        private _extraHours = ((_scale - 1) * _realDelta) / 3600;
        if (_extraHours > 0) then { skipTime _extraHours };
    };
};

// Apply initial time and weather from Config (server; syncs to clients)
private _initHour = missionNamespace getVariable ["FADE_scenarioTime", 18];
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
[] execVM "rsc\DummyUnits.sqf";

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
// Interactive boards: vehicle sign (vehBoard: texture only); terminalVeh = Manage Vehicles action (fallback: vehBoard)
FADE_vehicleBoard = missionNamespace getVariable ["vehBoard", objNull];
FADE_vehicleTerminal = missionNamespace getVariable ["terminalVeh", objNull];
FADE_missionBoard = missionNamespace getVariable ["missionBoard", objNull];
FADE_boards = [FADE_vehicleBoard, FADE_missionBoard] select { !isNull _x };

// FIRES range terminal (terminalFires) + game logic slots firesPos_* — rsc\FiresArtilleryList.sqf, rsc\FiresGui.sqf
call compile preprocessFileLineNumbers "rsc\FiresArtilleryList.sqf";
FAC_fires_approvedClasses = [];
{ FAC_fires_approvedClasses pushBack (_x select 2) } forEach FAC_fires_artilleryDefinitions;
private _firesNames = missionNamespace getVariable ["FADE_firesPosNames", ["firesPos_1", "firesPos_2", "firesPos_3", "firesPos_4", "firesPos_5", "firesPos_6"]];
FADE_fires_slots = [];
{ FADE_fires_slots pushBack [_x, missionNamespace getVariable [_x, objNull], objNull] } forEach _firesNames;
FADE_firesTerminal = missionNamespace getVariable ["terminalFires", objNull];

// magazinesAllTurrets row layout: vanilla is [turretPath, magazineClass, ammo]; some mod assets use [magazineClass, turretPath, ammo].
FAC_fires_parseMagTurretRow = {
    params ["_row"];
    if (!(_row isEqualType []) || {count _row < 3}) exitWith { ["", [], -1] };
    private _a0 = _row select 0;
    private _a1 = _row select 1;
    private _a2 = _row select 2;
    if (_a0 isEqualType [] && {_a1 isEqualType ""} && {_a2 isEqualType 0}) exitWith { [_a1, _a0, _a2] };
    if (_a0 isEqualType "" && {_a1 isEqualType []} && {_a2 isEqualType 0}) exitWith { [_a0, _a1, _a2] };
    ["", [], -1]
};

FAC_fires_publishState = {
    if (!isServer) exitWith {};
    {
        private _entry = _x;
        _entry params ["_slotName", "_logicObj", "_veh"];
        if (!isNull _veh && {!alive _veh}) then {
            private _i = FADE_fires_slots findIf { (_x select 0) == _slotName };
            if (_i >= 0) then {
                FADE_fires_slots set [_i, [_slotName, _logicObj, objNull]];
            };
        };
    } forEach FADE_fires_slots;

    private _out = [];
    {
        _x params ["_slotName", "_logicObj", "_veh"];
        private _cls = if (isNull _veh || {!alive _veh}) then { "" } else { typeOf _veh };
        private _ammo = 0;
        private _magState = [];
        if (_cls != "" && {!isNull _veh} && {alive _veh}) then {
            // Per magazine class: total rounds on piece / total capacity (all slots of that type).
            private _agg = [];

            private _addMagRow = {
                params ["_mag", "_cur", "_cap"];
                if (!(_mag isEqualType "") || {_mag == ""} || {!(_cur isEqualType 0)}) exitWith {};
                if (_cap <= 0) then { _cap = 1 };
                private _mi = _agg findIf { (_x select 0) == _mag };
                if (_mi < 0) then {
                    _agg pushBack [_mag, _cur, _cap];
                } else {
                    private _e = _agg select _mi;
                    _e set [1, (_e select 1) + _cur];
                    _e set [2, (_e select 2) + _cap];
                };
            };

            // Primary: magazinesAllTurrets — one row per loaded magazine slot (layout may vary by asset).
            {
                private _parsed = [_x] call FAC_fires_parseMagTurretRow;
                _parsed params ["_mag", "_turretUnused", "_cur"];
                if (_mag != "" && {_cur >= 0}) then {
                    private _cfgM = configFile >> "CfgMagazines" >> _mag;
                    private _cap = if (isClass _cfgM) then { getNumber (_cfgM >> "count") } else { 0 };
                    if (_cap <= 0) then { _cap = 1 };
                    [_mag, _cur, _cap] call _addMagRow;
                };
            } forEach (magazinesAllTurrets _veh);

            // Fallback: magazinesAmmoFull — one entry per magazine instance.
            if (count _agg == 0) then {
                private _full = magazinesAmmoFull _veh;
                {
                    if (_x isEqualType [] && {count _x > 1}) then {
                        private _mag = _x select 0;
                        private _cur = _x select 1;
                        private _cfgM = configFile >> "CfgMagazines" >> _mag;
                        private _cap = if (isClass _cfgM) then { getNumber (_cfgM >> "count") } else { 0 };
                        if (_cap <= 0) then { _cap = 1 };
                        [_mag, _cur, _cap] call _addMagRow;
                    };
                } forEach _full;
            };

            {
                _ammo = _ammo + (_x select 1);
            } forEach _agg;

            _magState = _agg;
        };
        private _nid = if (!isNull _veh && {alive _veh}) then { netId _veh } else { "" };
        _out pushBack [_slotName, _cls, _ammo, _nid, _magState];
    } forEach FADE_fires_slots;
    missionNamespace setVariable ["FAC_fires_clientState", _out, true];
};

FADE_fires_requestState = {
    params [["_player", objNull]];
    if (!isServer) exitWith {};
    [] call FAC_fires_publishState;
};

FADE_fires_spawnPiece = {
    params ["_slotName", "_class", "_player"];
    if (!isServer) exitWith {};
    if (isNil "_class" || { _class == "" }) exitWith { ["FIRES: invalid class."] remoteExec ["systemChat", _player]; };
    if (!(_class in FAC_fires_approvedClasses)) exitWith { ["FIRES: class not on approved list."] remoteExec ["systemChat", _player]; };
    if (!isClass (configFile >> "CfgVehicles" >> _class)) exitWith {
        [format ["FIRES: %1 not in CfgVehicles (mod missing).", _class]] remoteExec ["systemChat", _player];
    };
    private _idx = FADE_fires_slots findIf { (_x select 0) == _slotName };
    if (_idx < 0) exitWith { ["FIRES: unknown slot."] remoteExec ["systemChat", _player]; };
    private _entry = FADE_fires_slots select _idx;
    _entry params ["_sn", "_logicObj", "_veh"];
    if (isNull _logicObj) exitWith { [format ["FIRES: place game logic %1 in Eden.", _slotName]] remoteExec ["systemChat", _player]; };

    if (!isNull _veh && { alive _veh }) then {
        private _crew = crew _veh;
        { if (isPlayer _x) then { moveOut _x } else { _veh deleteVehicleCrew _x } } forEach _crew;
        deleteVehicle _veh;
    };
    private _pos = getPosATL _logicObj;
    private _dir = getDir _logicObj;
    private _newVeh = createVehicle [_class, _pos, [], 0, "NONE"];
    if (isNull _newVeh) exitWith { ["FIRES: spawn failed."] remoteExec ["systemChat", _player]; };
    _newVeh setPosATL _pos;
    _newVeh setDir _dir;
    _newVeh setVehicleAmmo 1;
    { _newVeh deleteVehicleCrew _x } forEach crew _newVeh;

    FADE_fires_slots set [_idx, [_sn, _logicObj, _newVeh]];
    [] call FAC_fires_publishState;
    private _dn = getText (configFile >> "CfgVehicles" >> _class >> "displayName");
    if (_dn == "") then { _dn = _class };
    [format ["FIRES: %1 spawned at %2.", _dn, _slotName]] remoteExec ["systemChat", _player];
};

FADE_fires_despawnSlot = {
    params ["_slotName", "_player"];
    if (!isServer) exitWith {};
    private _idx = FADE_fires_slots findIf { (_x select 0) == _slotName };
    if (_idx < 0) exitWith { ["FIRES: unknown slot."] remoteExec ["systemChat", _player]; };
    private _entry = FADE_fires_slots select _idx;
    _entry params ["_sn", "_logicObj", "_veh"];
    if (isNull _veh || {!alive _veh}) exitWith {
        FADE_fires_slots set [_idx, [_sn, _logicObj, objNull]];
        [] call FAC_fires_publishState;
        ["FIRES: slot already empty."] remoteExec ["systemChat", _player];
    };
    private _crew = crew _veh;
    { if (isPlayer _x) then { moveOut _x } else { _veh deleteVehicleCrew _x } } forEach _crew;
    deleteVehicle _veh;
    FADE_fires_slots set [_idx, [_sn, _logicObj, objNull]];
    [] call FAC_fires_publishState;
    ["FIRES: piece removed."] remoteExec ["systemChat", _player];
};

FADE_fires_rearmSlot = {
    params ["_slotName", "_player"];
    if (!isServer) exitWith {};
    private _idx = FADE_fires_slots findIf { (_x select 0) == _slotName };
    if (_idx < 0) exitWith { ["FIRES: unknown slot."] remoteExec ["systemChat", _player]; };
    private _veh = (FADE_fires_slots select _idx) select 2;
    if (isNull _veh || {!alive _veh}) exitWith { ["FIRES: nothing to rearm at this slot."] remoteExec ["systemChat", _player]; };
    _veh setVehicleAmmo 1;
    [] call FAC_fires_publishState;
    ["FIRES: ammunition replenished."] remoteExec ["systemChat", _player];
};

FADE_fires_setAmmoAmount = {
    params ["_slotName", "_magClass", "_targetTotal", "_player"];
    if (!isServer) exitWith {};
    private _idx = FADE_fires_slots findIf { (_x select 0) == _slotName };
    if (_idx < 0) exitWith { ["FIRES: unknown slot."] remoteExec ["systemChat", _player]; };
    private _veh = (FADE_fires_slots select _idx) select 2;
    if (isNull _veh || {!alive _veh}) exitWith { ["FIRES: nothing spawned in selected slot."] remoteExec ["systemChat", _player]; };
    if (_magClass == "") exitWith { ["FIRES: select an ammo type first."] remoteExec ["systemChat", _player]; };

    private _rows = [];
    {
        private _parsed = [_x] call FAC_fires_parseMagTurretRow;
        _parsed params ["_mag", "_turretPath", "_cur"];
        if (_mag == _magClass && {_cur >= 0}) then {
            _rows pushBack [_turretPath, _cur];
        };
    } forEach (magazinesAllTurrets _veh);

    if (count _rows == 0) exitWith {
        [format ["FIRES: %1 not found on selected piece.", _magClass]] remoteExec ["systemChat", _player];
    };

    private _cfgMag = configFile >> "CfgMagazines" >> _magClass;
    private _capDefault = if (isClass _cfgMag) then { getNumber (_cfgMag >> "count") } else { 0 };
    if (_capDefault <= 0) then { _capDefault = 1 };

    private _totalMax = 0;
    {
        private _cap = _capDefault;
        _totalMax = _totalMax + _cap;
    } forEach _rows;

    if (isNil "_targetTotal" || {!(_targetTotal isEqualType 0)}) then { _targetTotal = 0 };
    private _target = round ((_targetTotal max 0) min _totalMax);

    private _remaining = _target;
    {
        _x params ["_turretPath", "_curUnused"];
        private _give = _remaining min _capDefault;
        _veh setMagazineTurretAmmo [_magClass, _give, _turretPath];
        _remaining = _remaining - _give;
    } forEach _rows;

    [] call FAC_fires_publishState;
    [format ["FIRES: %1 total set to %2 / %3 rounds.", _magClass, _target, _totalMax]] remoteExec ["systemChat", _player];
};

FADE_fires_spawnAmmoTruck = {
    params [["_player", objNull]];
    if (!isServer) exitWith {};

    private _spawnLogic = missionNamespace getVariable ["firesTruckSpawnPos", objNull];
    if (isNull _spawnLogic) exitWith {
        ["FIRES: place game logic firesTruckSpawnPos in Eden."] remoteExec ["systemChat", _player];
    };

    private _existing = missionNamespace getVariable ["FADE_firesAmmoTruck", objNull];
    if (!isNull _existing && { alive _existing }) then {
        {
            if (isPlayer _x) then { moveOut _x } else { _existing deleteVehicleCrew _x };
        } forEach crew _existing;
        deleteVehicle _existing;
    };

    private _pos = getPosATL _spawnLogic;
    private _dir = getDir _spawnLogic;
    private _truck = createVehicle ["B_Truck_01_ammo_F", _pos, [], 0, "NONE"];
    if (isNull _truck) exitWith {
        ["FIRES: ammo truck spawn failed."] remoteExec ["systemChat", _player];
    };

    _truck setPosATL _pos;
    _truck setDir _dir;
    _truck setVehicleAmmo 1;
    { _truck deleteVehicleCrew _x } forEach crew _truck;
    missionNamespace setVariable ["FADE_firesAmmoTruck", _truck];

    ["FIRES: ammo truck spawned."] remoteExec ["systemChat", _player];
};

[] call FAC_fires_publishState;

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
FADE_cqbTargetWatcherHandle = scriptNull;
FADE_cqbStarterKilledEh = [];  // [unit, eventHandlerId] while drill active
FADE_cqbStarterUnit = objNull;
FADE_cqbStarterUid = "";
missionNamespace setVariable ["FADE_cqbLastResult", "", true];

// Apply board textures (Eden names). Non-interactable: base, loadout, music, firing range, teleport.
private _applyBoardTexture = {
    params ["_obj", "_path"];
    if (!isNull _obj && { count (getObjectTextures _obj) > 0 }) then { _obj setObjectTextureGlobal [0, _path] };
};
// Land_MapBoard_01_Wall_F: getObjectTextures is often [] until a texture is set, so the guard above never runs.
private _applyBoardTextureMapWall = {
    params ["_obj", "_path"];
    if (isNull _obj) exitWith {};
    _obj setObjectTextureGlobal [0, _path];
};
// Resolve Eden object name: missionNamespace first, then scan map boards (covers edge cases where name is not in namespace yet).
private _fnc_resolveLandMapBoardWall = {
    params ["_edenName"];
    private _o = missionNamespace getVariable [_edenName, objNull];
    if (!isNull _o) exitWith { _o };
    private _scan = allMissionObjects "Land_MapBoard_01_Wall_F";
    private _i = _scan findIf { vehicleVarName _x == _edenName };
    if (_i >= 0) then { _o = _scan select _i };
    _o
};
private _applyBoardTextureMapWallByEdenName = {
    params ["_edenName", "_path"];
    private _o = [_edenName] call _fnc_resolveLandMapBoardWall;
    if (isNull _o) exitWith {};
    _o setObjectTextureGlobal [0, _path];
};
// Vehicle and Missions/Config boards (interactive)
[missionNamespace getVariable ["vehBoard", objNull], "img\vehicles2.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["missionBoard", objNull], "img\laptopScenario.jpg"] call _applyBoardTexture;
// CQB (interactive)
[missionNamespace getVariable ["cqbBoard", objNull], "img\laptopCQB.jpg"] call _applyBoardTexture;
// Base billboards (non-interactable). Add img\base.jpg and uncomment to set texture.
[missionNamespace getVariable ["baseBoard_1", objNull], "img\baseBoards.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["baseBoard_2", objNull], "img\baseBoards.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["baseBoard_3", objNull], "img\baseBoards.jpg"] call _applyBoardTexture;
// HQ / canvases / admin / banner (non-interactable; Eden object names)
[missionNamespace getVariable ["hqMainBoard", objNull], "img\hqMainBoard2.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["canvas_1", objNull], "img\flagCTB.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["canvas_2", objNull], "img\flagAustralia.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["canvas_3", objNull], "img\flagCTB.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["canvas_4", objNull], "img\missionsconfig.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["whiteboardAdmin", objNull], "img\whiteboardAdmin.jpg"] call _applyBoardTextureMapWall;
[missionNamespace getVariable ["bannerSDE", objNull], "img\bannerSDE.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["sdeArt_1", objNull], "img\letsgo.jpg"] call _applyBoardTexture;
// Loadout boards above loadout boxes (non-interactable). Names: loadoutboard_1/3/4 in mission.sqm (case-sensitive).
private _loadoutMapTex = "img\whiteboardLoadouts.jpg";
{ [_x, _loadoutMapTex] call _applyBoardTextureMapWallByEdenName } forEach ["loadoutboard_1", "loadoutboard_3", "loadoutboard_4"];
[missionNamespace getVariable ["loadoutBoard_2", objNull], "img\loadouts.jpg"] call _applyBoardTexture;
// Re-apply after init: Eden/custom attributes can run after initServer; inline resolver (spawn cannot see outer private fnc).
[] spawn {
    private _names = ["loadoutboard_1", "loadoutboard_3", "loadoutboard_4"];
    private _p = "img\whiteboardLoadouts.jpg";
    private _apply = {
        params ["_names", "_path"];
        {
            private _en = _x;
            private _o = missionNamespace getVariable [_en, objNull];
            if (isNull _o) then {
                private _scan = allMissionObjects "Land_MapBoard_01_Wall_F";
                private _i = _scan findIf { vehicleVarName _x == _en };
                if (_i >= 0) then { _o = _scan select _i };
            };
            if (!isNull _o) then { _o setObjectTextureGlobal [0, _path]; };
        } forEach _names;
    };
    sleep 0.5;
    [_names, _p] call _apply;
    sleep 2;
    [_names, _p] call _apply;
};
// Music board next to jukebox (non-interactable)
[missionNamespace getVariable ["musicBoard", objNull], "img\music.jpg"] call _applyBoardTexture;
// Jukebox radio props (non-interactable texture; actions on Radio_* in initPlayerLocal)
[missionNamespace getVariable ["Radio_1", objNull], "img\laptopJukebox.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["Radio_2", objNull], "img\laptopJukebox.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["Radio_3", objNull], "img\laptopJukebox.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["Radio_4", objNull], "img\laptopJukebox.jpg"] call _applyBoardTexture;
// Firing range sign (non-interactable)
[missionNamespace getVariable ["firingRangeBoard", objNull], "img\signLiveFire.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["signFire_1", objNull], "img\signLiveFire.jpg"] call _applyBoardTexture;
// Teleport boards (Fast Travel GUI) - same signage texture on all boards
{
    [missionNamespace getVariable [_x, objNull], "img\teleporter.jpg"] call _applyBoardTexture;
} forEach [
    "teleportBoard_1", "teleportBoard_2", "teleportBoard_3", "teleportBoard_4",
    "teleportBoard_5", "teleportBoard_6", "teleportBoard_7", "teleportBoard_8"
];
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
    private _skill = missionNamespace getVariable ["FADE_enemySkill", 0.2];
    private _retreatChance = 1 - (_skill max 0 min 1);
    private _debug = missionNamespace getVariable ["FADE_retreatDebug", false];
    if (_debug) then {
        [format ["Retreat: 50%% threshold reached. Rolling retreat (chance %1%2).", round (_retreatChance * 100), "%"]] remoteExec ["systemChat", 0];
    };
    {
        private _grp = _x;
        if (!isNull _grp && { side _grp == (missionNamespace getVariable ["FADE_sideEnemy", east]) }) then {
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
    if (!(_groups isEqualType [])) exitWith {}; // avoid foreach Type Bool (bad caller / scope collision)
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

// -----------------------------------------------------------------------------
// Counter-attack helpers - cargo capacity (cached per classname), RHS/vanilla fallbacks
// -----------------------------------------------------------------------------
// Returns emptyPositions "cargo" for a classname; caches in missionNamespace (spawn test once per class).
FADE_counterAttack_cargoSeatsForClass = {
    params ["_class"];
    private _key = "FADE_counterAttack_cargo_" + _class;
    private _cached = missionNamespace getVariable [_key, -1];
    if (_cached >= 0) exitWith { _cached };
    if (!(isClass (configFile >> "CfgVehicles" >> _class))) exitWith {
        missionNamespace setVariable [_key, 0];
        0
    };
    private _testPos = [FADE_basePos, 1500, 5000, 15, 0, 0.4, 0, [], FADE_basePos] call BIS_fnc_findSafePos;
    if (count _testPos < 2) then { _testPos = [FADE_basePos select 0, FADE_basePos select 1, 0] };
    private _v = createVehicle [_class, _testPos, [], 0, "NONE"];
    if (isNull _v) exitWith {
        missionNamespace setVariable [_key, 0];
        0
    };
    private _n = _v emptyPositions "cargo";
    deleteVehicle _v;
    missionNamespace setVariable [_key, _n];
    _n
};

// Filter classnames to those with at least _minCargo cargo seats (uses cache above).
FADE_counterAttack_filterClassesByMinCargo = {
    params ["_classes", "_minCargo"];
    private _out = [];
    {
        if (([_x] call FADE_counterAttack_cargoSeatsForClass) >= _minCargo) then {
            _out pushBack _x;
        };
    } forEach _classes;
    _out
};

// -----------------------------------------------------------------------------
// Counter-attack / QRF (HVT, Hostage, Clear Area, Search & Destroy, Troop Extract, CASEVAC, CSAR, Asset Retrieval) - reusable server spawn loop.
// Stages truck-mounted infantry from the second-nearest CIV_T_* zone (by distance
// to the objective); falls back to offset from nearest zone if only one trigger exists.
// Params: [_taskId, _objectivePos, _basePos, _enemyUnits, _allGroups, _detectionRadius]
//   _allGroups - reference array; new enemy groups are pushBack'd for mission cleanup.
//   _detectionRadius - optional; <= 0 uses missionNamespace FADE_counterAttackDetectionRadius (default 450).
// Timing defaults (optional missionNamespace): FADE_counterAttackFirstDelayMin/Max (120–360s),
//   FADE_counterAttackBetweenMin/Max (540–660s), FADE_counterAttackTruckCount (3).
// Vehicle filter: FADE_counterAttackMinCargoSeats (default 4). Fallback trucks if faction has none:
//   FADE_counterAttackRhsFallbacks (RHS GAZ/ZIL/Kamaz/Ural-style), then FADE_counterAttackVanillaFallbacks.
// Poll interval: FADE_counterAttackPollInterval (default 10s) for zone/task checks (not per-frame).
// Wave cap: 1–3 waves per mission instance (chosen at random when the counter-attack thread starts).
// Not registered with FADE_registerEnemyRetreat (QRF keeps pressure); cleaned with mission groups.
// -----------------------------------------------------------------------------
FADE_counterAttackStart = {
    params [
        "_taskId",
        "_objectivePos",
        "_basePos",
        "_enemyUnits",
        "_allGroups",
        ["_detectionRadius", -1]
    ];
    if (!isServer) exitWith {};
    if (count _objectivePos < 2 || { count _enemyUnits == 0 }) exitWith {};
    if (_detectionRadius <= 0) then {
        _detectionRadius = missionNamespace getVariable ["FADE_counterAttackDetectionRadius", 450];
    };
    private _firstMin = missionNamespace getVariable ["FADE_counterAttackFirstDelayMin", 120];
    private _firstMax = missionNamespace getVariable ["FADE_counterAttackFirstDelayMax", 360];
    private _betMin = missionNamespace getVariable ["FADE_counterAttackBetweenMin", 540];
    private _betMax = missionNamespace getVariable ["FADE_counterAttackBetweenMax", 660];
    private _numTrucks = (missionNamespace getVariable ["FADE_counterAttackTruckCount", 3]) max 1;
    private _pollInterval = (missionNamespace getVariable ["FADE_counterAttackPollInterval", 10]) max 1;
    private _applyGrp = missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}];
    if (_applyGrp isEqualTo {}) exitWith {};

    [_taskId, _objectivePos, _basePos, _enemyUnits, _allGroups, _detectionRadius, _firstMin, _firstMax, _betMin, _betMax, _numTrucks, _applyGrp, _pollInterval] spawn {
        params [
            "_taskId", "_objectivePos", "_basePos", "_enemyUnits", "_allGroups", "_detectionRadius",
            "_firstMin", "_firstMax", "_betMin", "_betMax", "_numTrucks", "_applyGrp", "_pollInterval"
        ];
        private _taskDone = { (_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"] };
        private _playersInZone = {
            private _ok = false;
            {
                if (isPlayer _x && { alive _x } && { (_x distance2D _objectivePos) < _detectionRadius }) exitWith { _ok = true };
            } forEach allPlayers;
            _ok
        };
        private _detectionLogged = false;
        // Wait for first contact in zone or mission end (slow poll - not per-frame)
        waitUntil {
            sleep _pollInterval;
            if (call _taskDone) exitWith { true };
            private _in = call _playersInZone;
            if (_in && { !_detectionLogged }) then {
                _detectionLogged = true;
            };
            _in
        };
        if (call _taskDone) exitWith {};
        private _maxWaves = 1 + floor random 3;
        private _firstDelaySec = _firstMin + random (_firstMax - _firstMin);
        sleep _firstDelaySec;

        private _waveFn = {
            params ["_objectivePos", "_enemyUnits", "_allGroups", "_numTrucks", "_applyGrp", "_pollInterval"];
            private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
            private _pairs = [];
            {
                private _trig = missionNamespace getVariable [_x, objNull];
                if (!isNull _trig) then {
                    private _zc = getPosATL _trig;
                    if (count _zc >= 2) then {
                        _pairs pushBack [_zc distance2D _objectivePos, _zc];
                    };
                };
            } forEach (missionNamespace getVariable ["FADE_civTriggerNames", []]);
            if (count _pairs == 0) exitWith {};
            _pairs = [_pairs, [], { _x select 0 }, "ASCEND"] call BIS_fnc_sortBy;
            private _minBase = missionNamespace getVariable ["FADE_counterAttackMinDistFromBase", 1000];
            private _baseQ = FADE_basePos;
            private _roadPos = [];
            private _staging = [];
            private _stagingResolved = false;
            private _stCandidates = [];
            if (count _pairs >= 2) then { _stCandidates pushBack [1, (_pairs select 1) select 1] };
            if (count _pairs >= 3) then { _stCandidates pushBack [2, (_pairs select 2) select 1] };
            _stCandidates pushBack [0, (_pairs select 0) select 1];
            if (count _pairs >= 4) then { _stCandidates pushBack [3, (_pairs select 3) select 1] };
            private _nearOnly = (_pairs select 0) select 1;
            _stCandidates pushBack [-1, _nearOnly getPos [600 min ((_nearOnly distance2D _objectivePos) + 400), (_nearOnly getDir _objectivePos) + 180]];
            private _si = 0;
            while { _si < count _stCandidates && { !_stagingResolved } } do {
                private _st = (_stCandidates select _si) select 1;
                _staging = _st;
                if (count _staging < 3) then { _staging = [(_staging select 0), (_staging select 1), 0] };
                private _roads = _staging nearRoads 450;
                private _okRoads = _roads select { (getPosATL _x) distance2D _baseQ > _minBase };
                if (count _okRoads > 0) then {
                    _roadPos = getPosATL (selectRandom _okRoads);
                    _stagingResolved = true;
                } else {
                    private _cand = [_staging, 0, 400, 12, 0, 0.35, 0, [], _staging] call BIS_fnc_findSafePos;
                    if (count _cand >= 2 && { _cand distance2D _baseQ > _minBase }) then {
                        _roadPos = [(_cand select 0), (_cand select 1), (_cand param [2, 0])];
                        _stagingResolved = true;
                    };
                };
                _si = _si + 1;
            };
            if (!_stagingResolved) then {
                private _dirFromBase = _baseQ getDir _objectivePos;
                private _fallbackPos = _baseQ getPos [(_minBase + 50), _dirFromBase];
                private _r2 = _fallbackPos nearRoads 250;
                _r2 = _r2 select { (getPosATL _x) distance2D _baseQ > _minBase };
                if (count _r2 > 0) then {
                    _roadPos = getPosATL (selectRandom _r2);
                    _staging = _fallbackPos;
                    _stagingResolved = true;
                };
            };
            if (!_stagingResolved) exitWith {};
            if (count _roadPos < 3) then { _roadPos = [(_roadPos select 0), (_roadPos select 1), 0] };
            private _dir = [_roadPos, _objectivePos] call BIS_fnc_dirTo;

            private _vehClasses = missionNamespace getVariable ["FADE_enemyVehicles", []];
            if (_vehClasses isEqualTo []) then {
                private _ef = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
                _vehClasses = [_ef] call FADE_getEnemyVehiclesForFaction;
            };
            private _soft = [];
            {
                if (!(_x isKindOf "Air") && { !(_x isKindOf "Ship") } && { !(_x isKindOf "StaticWeapon") }) then {
                    if (!(_x isKindOf "Tank") && { !(_x isKindOf "Wheeled_APC_F") }) then { _soft pushBack _x };
                };
            } forEach _vehClasses;
            private _minCargo = missionNamespace getVariable ["FADE_counterAttackMinCargoSeats", 4];
            private _vehPick = [];
            private _softOk = [_soft, _minCargo] call FADE_counterAttack_filterClassesByMinCargo;
            if (count _softOk > 0) then {
                _vehPick = _softOk;
            } else {
                private _landAll = _vehClasses select {
                    !(_x isKindOf "Air") && { !(_x isKindOf "Ship") } && { !(_x isKindOf "StaticWeapon") }
                };
                _vehPick = [_landAll, _minCargo] call FADE_counterAttack_filterClassesByMinCargo;
            };
            if (count _vehPick == 0) then {
                private _rhsFb = missionNamespace getVariable ["FADE_counterAttackRhsFallbacks", [
                    "rhs_gaz66_msv",
                    "rhs_zil131_msv",
                    "rhs_kamaz5350_msv",
                    "rhs_kamaz5350_open_msv",
                    "RHS_Ural_Civ_01",
                    "rhsgref_cdf_ural_open"
                ]];
                _vehPick = [_rhsFb, _minCargo] call FADE_counterAttack_filterClassesByMinCargo;
            };
            if (count _vehPick == 0) then {
                private _snCa = missionNamespace getVariable ["FADE_scenarioEnemySideNum", 0];
                private _vanFbDefault = switch (_snCa) do {
                    case 1: { ["B_Truck_01_transport_F", "B_T_Truck_01_transport_F", "I_Truck_02_transport_F", "O_Truck_02_transport_F"] };
                    case 2: { ["I_Truck_02_transport_F", "I_G_Offroad_01_transport_F", "O_Truck_02_transport_F", "B_Truck_01_transport_F"] };
                    default { ["O_Truck_03_transport_F", "O_Truck_02_transport_F", "I_Truck_02_transport_F", "B_Truck_01_transport_F"] };
                };
                private _vanFb = missionNamespace getVariable ["FADE_counterAttackVanillaFallbacks", _vanFbDefault];
                _vehPick = [_vanFb, _minCargo] call FADE_counterAttack_filterClassesByMinCargo;
            };
            if (count _vehPick == 0) exitWith {
                private _sz = 4 + floor random 4;
                private _cls = (_enemyUnits select [0, _sz min count _enemyUnits]);
                for "_k" from (count _cls) to (_sz - 1) do { _cls pushBack (_enemyUnits select 0) };
                private _grp = [_roadPos, _sideEnemy, _cls] call BIS_fnc_spawnGroup;
                if (!isNull _grp && { count units _grp > 0 }) then {
                    [_grp] call _applyGrp;
                    _grp setBehaviour "COMBAT";
                    _grp setCombatMode "RED";
                    private _wp = _grp addWaypoint [_objectivePos, 0];
                    _wp setWaypointType "SAD";
                    _allGroups pushBack _grp;
                };
            };

            private _cargoStagger = missionNamespace getVariable ["FADE_counterAttackCargoStaggerSec", 0.35];
            private _spawnedVehs = [];
            private _findGap = {
                params ["_desired", "_vehs", "_fallback"];
                private _best = [];
                for "_try" from 0 to 8 do {
                    private _cand = [_desired, 0, 18, 8, 0, 0.35, 0, [], _fallback] call BIS_fnc_findSafePos;
                    if (count _cand < 2) then { _cand = _fallback };
                    if (count _cand < 3) then { _cand = [(_cand select 0), (_cand select 1), 0] };
                    private _bad = false;
                    { if (!isNull _x && { alive _x } && { (_x distance2D _cand) < 14 }) exitWith { _bad = true } } forEach _vehs;
                    if (!_bad) exitWith { _best = _cand };
                };
                if (count _best < 2) then { _best = _fallback };
                _best
            };
            for "_vi" from 0 to (_numTrucks - 1) do {
                if (_vi > 0) then { sleep 8 };
                private _vClass = selectRandom _vehPick;
                private _anchor = if (count _spawnedVehs > 0) then {
                    getPosATL (_spawnedVehs select ((count _spawnedVehs) - 1))
                } else {
                    _roadPos
                };
                private _desired = if (_vi == 0) then {
                    _roadPos
                } else {
                    [
                        (_anchor select 0) - (sin _dir) * 12,
                        (_anchor select 1) - (cos _dir) * 12,
                        0
                    ]
                };
                if (count _desired < 3) then { _desired = [(_desired select 0), (_desired select 1), 0] };
                private _spawnPos = [_desired, _spawnedVehs, _roadPos] call _findGap;
                if (_spawnPos distance2D _baseQ <= _minBase) then {
                    _spawnPos = [_roadPos, 0, 35, 10, 0, 0.35, 0, [], _roadPos] call BIS_fnc_findSafePos;
                    if (count _spawnPos < 2 || { _spawnPos distance2D _baseQ <= _minBase }) then { continue };
                };
                private _vehGrp = createGroup _sideEnemy;
                private _veh = createVehicle [_vClass, _spawnPos, [], 0, "NONE"];
                if (isNull _veh) then { deleteGroup _vehGrp; continue };
                _veh setPosATL _spawnPos;
                _veh setDir _dir;
                _veh setVelocity [(sin _dir) * 2, (cos _dir) * 2, 0];
                _veh engineOn true;
                _spawnedVehs pushBack _veh;
                private _driver = _vehGrp createUnit [selectRandom _enemyUnits, _spawnPos, [], 0, "NONE"];
                if (!isNull _driver) then {
                    _driver moveInDriver _veh;
                    _vehGrp selectLeader _driver;
                };
                if (_veh emptyPositions "gunner" > 0) then {
                    private _g = _vehGrp createUnit [selectRandom _enemyUnits, _spawnPos, [], 0, "NONE"];
                    if (!isNull _g) then { _g moveInGunner _veh };
                };
                [_vehGrp] call _applyGrp;
                _vehGrp setBehaviour "AWARE";
                _vehGrp setCombatMode "RED";
                _vehGrp setSpeedMode "NORMAL";
                private _wpM = _vehGrp addWaypoint [_objectivePos, 25];
                _wpM setWaypointType "MOVE";
                _wpM setWaypointSpeed "NORMAL";
                private _wpS = _vehGrp addWaypoint [_objectivePos, 0];
                _wpS setWaypointType "SAD";
                _allGroups pushBack _vehGrp;
                [_veh, _vehGrp, _enemyUnits, _applyGrp, _objectivePos, _pollInterval, _allGroups, _cargoStagger, _sideEnemy] spawn {
                    params ["_veh", "_vehGrp", "_enemyUnits", "_applyGrp", "_objectivePos", "_pollInterval", "_allGroups", "_cargoStagger", "_sideEnemy"];
                    private _seats = (_veh emptyPositions "cargo") max 0;
                    if (_seats <= 0) exitWith {};
                    private _cargoGrp = createGroup _sideEnemy;
                    for "_c" from 0 to (_seats - 1) do {
                        sleep _cargoStagger;
                        private _u = _cargoGrp createUnit [selectRandom _enemyUnits, getPosATL _veh, [], 0, "NONE"];
                        if (!isNull _u) then { _u moveInCargo _veh };
                    };
                    [_cargoGrp] call _applyGrp;
                    _allGroups pushBack _cargoGrp;
                    waitUntil {
                        sleep _pollInterval;
                        !alive _veh || { isNull _veh } || { (_veh distance2D _objectivePos) < 130 }
                    };
                    if (!alive _veh || { isNull _veh }) exitWith {};
                    if (!isNull _cargoGrp && { count units _cargoGrp > 0 }) then {
                        {
                            unassignVehicle _x;
                            _x action ["GetOut", _veh];
                        } forEach units _cargoGrp;
                        sleep 4;
                        _cargoGrp setBehaviour "COMBAT";
                        _cargoGrp setCombatMode "RED";
                        private _wp = _cargoGrp addWaypoint [_objectivePos, 0];
                        _wp setWaypointType "SAD";
                    };
                };
            };
        };

        private _waveNum = 0;
        while { _waveNum < _maxWaves && { !(call _taskDone) } } do {
            _waveNum = _waveNum + 1;
            [_objectivePos, _enemyUnits, _allGroups, _numTrucks, _applyGrp, _pollInterval] call _waveFn;
            if (call _taskDone) exitWith {};
            if (_waveNum >= _maxWaves) exitWith {};
            private _bw = _betMin + random (_betMax - _betMin);
            sleep _bw;
            if (call _taskDone) exitWith {};
            waitUntil {
                sleep _pollInterval;
                call _taskDone || { call _playersInZone }
            };
            if (call _taskDone) exitWith {};
        };
    };
};
missionNamespace setVariable ["FADE_counterAttackStart", FADE_counterAttackStart];

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

// Asset Retrieval: position within _radiusM of a random CIV_T_* center, at least _minDist from base.
// Params: [["_minDistOverride", -1], ["_radiusFromZone", 500]]
FADE_findMissionPosAssetRetrieval = {
    params [["_minDistOverride", -1], ["_radiusFromZone", 500]];
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
            private _candidate = [_zoneCenter, 5, _radiusFromZone, 5, 0, 0.5, 0, [], _zoneCenter] call BIS_fnc_findSafePos;
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
missionNamespace setVariable ["FADE_findMissionPosAssetRetrieval", FADE_findMissionPosAssetRetrieval];

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
// CQB pop-up targets: stay down on any damage (splash / indirect), sync noPop + animation to clients.
// -----------------------------------------------------------------------------
FADE_cqbTryCompleteTargetDrill = {
    if (!isServer) exitWith {};
    if (!(missionNamespace getVariable ["FADE_cqbDrillActive", false])) exitWith {};
    private _spawned = missionNamespace getVariable ["FADE_cqbSpawned", []];
    private _objs = _spawned select { !(_x isEqualType grpNull) && {!isNull _x} };
    if (_objs isEqualTo []) exitWith {};
    private _need = count _objs;
    private _got = { _x getVariable ["FADE_cqbDownHandled", false] } count _objs;
    if (_got < _need) exitWith {};
    private _p = missionNamespace getVariable ["FADE_cqbStarterUnit", objNull];
    private _startTick = missionNamespace getVariable ["FADE_cqbDrillStartTick", diag_tickTime];
    private _elapsed = (diag_tickTime - _startTick) max 0;
    private _sec = floor _elapsed;
    private _mm = floor (_sec / 60);
    private _ss = _sec mod 60;
    private _ssStr = if (_ss < 10) then { format ["0%1", _ss] } else { str _ss };
    private _timeStr = format ["%1:%2", _mm, _ssStr];
    private _msg = format ["CQB: All %1 targets down — time %2.", _need, _timeStr];
    missionNamespace setVariable ["FADE_cqbLastResult", _msg, true];
    publicVariable "FADE_cqbLastResult";
    if (!isNull _p) then {
        [_p, _msg] call FADE_cqbEndDrill;
    } else {
        [objNull, _msg, true] call FADE_cqbEndDrill;
    };
};

FADE_cqbMarkTargetDown = {
    params [["_t", objNull]];
    if (!isServer) exitWith {};
    if (isNull _t) exitWith {};
    if (!(_t getVariable ["FADE_cqbIsDrillTarget", false])) exitWith {};
    if (_t getVariable ["FADE_cqbDownHandled", false]) exitWith {};
    _t setVariable ["FADE_cqbDownHandled", true, true];
    _t setVariable ["noPop", true, true];
    [_t] remoteExec ["FADE_cqbClient_forceTargetDown", 0, true];
    [] call FADE_cqbTryCompleteTargetDrill;
};

FADE_cqbRegisterTargetPersistence = {
    params ["_target"];
    if (!isServer) exitWith {};
    if (isNull _target) exitWith {};
    _target setVariable ["FADE_cqbIsDrillTarget", true, true];
    _target setVariable ["FADE_cqbDownHandled", false, true];
    _target setVariable ["noPop", true, true];
    _target addEventHandler ["Hit", { [(_this select 0)] call FADE_cqbMarkTargetDown }];
    _target addEventHandler ["Killed", { [(_this select 0)] call FADE_cqbMarkTargetDown }];
    _target addEventHandler ["HandleDamage", {
        params ["_unit", "_selection", "_damage"];
        if (_damage > 1e-3) then { [_unit] call FADE_cqbMarkTargetDown };
        _damage
    }];
};

// -----------------------------------------------------------------------------
// CQB Training Shoothouse - start/end drill (server). Called via remoteExec from CQB GUI.
// Params: [player, enemyType ("targets"|"enemies"), density ("Low"|"Medium"|"High"), civilians (bool)]
// Density: Low 20%, Medium 33%, High 50% per position. Civilians: 15% chance per spawn when true.
// Target drills: all pop-ups must stay down until reset; completion time from first spawn to last target down.
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
    private _enemyUnits = missionNamespace getVariable ["FADE_enemyUnits", missionNamespace getVariable ["FADE_fallbackEnemyUnits", ["O_Soldier_F"]]];
    _enemyUnits = [_enemyUnits] call FADE_filterUnitsArmed;
    if (_enemyUnits isEqualTo []) then { _enemyUnits = +(missionNamespace getVariable ["FADE_fallbackEnemyUnits", ["O_Soldier_F"]]) };
    private _civUnits = missionNamespace getVariable ["FADE_civUnitClasses", ["C_man_1"]];
    if (_civUnits isEqualTo []) then { _civUnits = ["C_man_1"] };
    private _targetClass = missionNamespace getVariable ["FADE_cqbTargetClass", "TargetP_Inf_F"];
    if (!isClass (configFile >> "CfgVehicles" >> _targetClass)) then { _targetClass = "Target_F" };
    missionNamespace setVariable ["noPop", true, true];
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
            [_target] call FADE_cqbRegisterTargetPersistence;
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
                private _grp = createGroup (missionNamespace getVariable ["FADE_sideEnemy", east]);
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
    private _targetObjs = _spawned select { !(_x isEqualType grpNull) && {!isNull _x} };
    if (_enemyType == "targets" && { count _targetObjs > 0 }) then {
        missionNamespace setVariable ["FADE_cqbDrillStartTick", diag_tickTime];
        private _tw = missionNamespace getVariable ["FADE_cqbTargetWatcherHandle", scriptNull];
        if (!isNull _tw) then { terminate _tw };
        private _targetWatch = [_targetObjs] spawn {
            params ["_objs"];
            while { missionNamespace getVariable ["FADE_cqbDrillActive", false] } do {
                sleep 0.5;
                private _need = 0;
                private _got = 0;
                {
                    if (isNull _x) then { continue };
                    _need = _need + 1;
                    if (_x getVariable ["FADE_cqbDownHandled", false]) then { _got = _got + 1 };
                } forEach _objs;
                if (_need > 0 && _got >= _need) exitWith { [] call FADE_cqbTryCompleteTargetDrill };
            };
        };
        missionNamespace setVariable ["FADE_cqbTargetWatcherHandle", _targetWatch];
    };
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
                        ["CQB drill complete: all enemy units neutralised (dead or captive)."] remoteExec ["systemChat", _player];
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
    private _tw = missionNamespace getVariable ["FADE_cqbTargetWatcherHandle", scriptNull];
    if (!isNull _tw) then { terminate _tw };
    missionNamespace setVariable ["FADE_cqbTargetWatcherHandle", scriptNull];
    missionNamespace setVariable ["noPop", false, true];
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
publicVariable "FADE_enemyUnits";
publicVariable "FADE_friendlyVehicleClasses";
publicVariable "FADE_vehiclePoints";
publicVariable "FADE_helipads";
publicVariable "FADE_boards";
publicVariable "FADE_vehicleBoard";
publicVariable "FADE_vehicleTerminal";
publicVariable "FADE_firesTerminal";
publicVariable "FADE_missionBoard";
publicVariable "FADE_cqbBoard";
publicVariable "FADE_cqbDrillActive";
publicVariable "FADE_cqbStartDrill";
publicVariable "FADE_cqbEndDrill";
publicVariable "FADE_cqbLastResult";

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
    params ["_heliClass", "_player", ["_padIndex", -1]];
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
    private _fnc_padBlocking = {
        params ["_padObj"];
        private _pos = getPosATL _padObj;
        private _near = nearestObjects [_pos, ["Air", "LandVehicle"], _padRadius];
        _near select { !isNull _x && { alive _x } }
    };

    // Optional: spawn on a specific helipad index (Vehicle GUI); -1 = first free among candidates
    if (_padIndex >= 0 && {_padIndex < count FADE_helipadList}) then {
        private _entry = FADE_helipadList select _padIndex;
        _entry params ["_padObj", "_padName"];
        if (_isPlane && {_padName in _forbidden}) exitWith {
            [format ["PLANES CANNOT SPAWN AT %1.", _padName]] remoteExec ["systemChat", _player];
        };
        if (count ([_padObj] call _fnc_padBlocking) > 0) exitWith {
            ["SELECTED PAD IS OCCUPIED."] remoteExec ["systemChat", _player];
        };
        _pad = _padObj;
    } else {
        {
            _x params ["_padObj", "_padName"];
            if (count ([_padObj] call _fnc_padBlocking) == 0) exitWith { _pad = _padObj };
        } forEach _candidatePads;
    };
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
// Full repair / refuel / rearm for a vehicle at base (server). Vehicle GUI.
// Same effect order as rsc\PadVehicleService.sqf; distance rule matches despawn.
// -----------------------------------------------------------------------------
FADE_serviceVehicle = {
    params ["_veh", "_player"];
    if (isNull _veh) exitWith { ["INVALID VEHICLE."] remoteExec ["systemChat", _player] };
    if (!alive _veh) exitWith { ["VEHICLE DESTROYED."] remoteExec ["systemChat", _player] };
    if (
        _veh isKindOf "Man"
        || { _veh isKindOf "StaticWeapon" }
        || { _veh isKindOf "ParachuteBase" }
    ) exitWith {
        ["SELECT AN AIRCRAFT OR LAND VEHICLE."] remoteExec ["systemChat", _player];
    };
    if (!(_veh isKindOf "Air" || _veh isKindOf "LandVehicle")) exitWith {
        ["SELECT AN AIRCRAFT OR LAND VEHICLE."] remoteExec ["systemChat", _player];
    };
    private _dist = (getPosATL _veh) distance FADE_basePos;
    if (_dist > 1000) exitWith {
        ["VEHICLE MUST BE WITHIN 1000M OF BASE TO SERVICE."] remoteExec ["systemChat", _player];
    };
    _veh setFuel 1;
    _veh setDamage 0;
    _veh setVehicleAmmo 1;
    ["VEHICLE REPAIRED, REFUELLED, AND REARMED."] remoteExec ["systemChat", _player];
    if (_veh isKindOf "Air") then { call FADE_updateHelipadMarkers };
};

// Vehicle GUI: repair only, refuel only, or rearm only (same distance rules as FADE_serviceVehicle)
FADE_serviceVehiclePart = {
    params ["_veh", "_player", ["_part", ""], ["_ratio", -1], ["_magClass", ""], ["_pylonIdx", -1]];
    if (isNull _veh) exitWith { ["INVALID VEHICLE."] remoteExec ["systemChat", _player] };
    if (!alive _veh) exitWith { ["VEHICLE DESTROYED."] remoteExec ["systemChat", _player] };
    if (
        _veh isKindOf "Man"
        || { _veh isKindOf "StaticWeapon" }
        || { _veh isKindOf "ParachuteBase" }
    ) exitWith {
        ["SELECT AN AIRCRAFT OR LAND VEHICLE."] remoteExec ["systemChat", _player];
    };
    if (!(_veh isKindOf "Air" || _veh isKindOf "LandVehicle")) exitWith {
        ["SELECT AN AIRCRAFT OR LAND VEHICLE."] remoteExec ["systemChat", _player];
    };
    private _dist = (getPosATL _veh) distance FADE_basePos;
    if (_dist > 1000) exitWith {
        ["VEHICLE MUST BE WITHIN 1000M OF BASE TO SERVICE."] remoteExec ["systemChat", _player];
    };
    if !(_ratio isEqualType 0) then { _ratio = -1 };
    if (_ratio >= 0) then { _ratio = (_ratio max 0) min 1 };
    if (isNil "_pylonIdx" || {!(_pylonIdx isEqualType 0)}) then { _pylonIdx = -1 };
    _pylonIdx = round _pylonIdx;

    switch (toLower _part) do {
        case "repair": {
            if (_ratio >= 0) then {
                _veh setDamage (1 - _ratio);
                [format ["VEHICLE HEALTH SET TO %1%%.", round (_ratio * 100)]] remoteExec ["systemChat", _player];
            } else {
                _veh setDamage 0;
                ["VEHICLE REPAIRED."] remoteExec ["systemChat", _player];
            };
        };
        case "refuel": {
            if (_ratio >= 0) then {
                _veh setFuel _ratio;
                [format ["VEHICLE FUEL SET TO %1%%.", round (_ratio * 100)]] remoteExec ["systemChat", _player];
            } else {
                _veh setFuel 1;
                ["VEHICLE REFUELLED."] remoteExec ["systemChat", _player];
            };
        };
        case "rearm": {
            if (_ratio >= 0 && {_pylonIdx >= 0}) then {
                if (_magClass == "") then {
                    private _pm = getPylonMagazines _veh;
                    if (_pylonIdx < count _pm) then { _magClass = _pm select _pylonIdx };
                };
                private _cfgMag = configFile >> "CfgMagazines" >> _magClass;
                private _max = if (isClass _cfgMag) then { getNumber (_cfgMag >> "count") } else { 0 };
                if (_max <= 0) then { _max = _veh ammoOnPylon _pylonIdx };
                if (_max <= 0) then { _max = 1 };
                private _rounds = round (_max * _ratio);
                _rounds = (_rounds max 0) min _max;
                _veh setAmmoOnPylon [_pylonIdx, _rounds];
                [format ["PYLON %1 AMMO SET (%2 / %3).", _pylonIdx + 1, _rounds, _max]] remoteExec ["systemChat", _player];
            } else {
                if (_ratio >= 0 && {_magClass isEqualType ""} && {_magClass != ""}) then {
                    private _didAny = false;
                    private _mags = magazinesAllTurrets _veh;
                    {
                        private _parsed = [_x] call FAC_fires_parseMagTurretRow;
                        _parsed params ["_mag", "_turretPath", "_cur"];
                        if (_mag == _magClass && {_cur >= 0}) then {
                            private _cfgMag = configFile >> "CfgMagazines" >> _mag;
                            private _max = if (isClass _cfgMag) then { getNumber (_cfgMag >> "count") } else { 0 };
                            if (_max <= 0) then { _max = _cur max 1 };
                            if (_max <= 0) then { _max = 1 };
                            private _rounds = round (_max * _ratio);
                            _rounds = (_rounds max 0) min _max;
                            _veh setMagazineTurretAmmo [_mag, _rounds, _turretPath];
                            _didAny = true;
                        };
                    } forEach _mags;
                    if (_didAny) then {
                        [format ["AMMO LOAD SET FOR %1 (%2%%).", _magClass, round (_ratio * 100)]] remoteExec ["systemChat", _player];
                    } else {
                        ["AMMO TYPE NOT FOUND ON VEHICLE."] remoteExec ["systemChat", _player];
                    };
                } else {
                    _veh setVehicleAmmo 1;
                    ["VEHICLE REARMED."] remoteExec ["systemChat", _player];
                };
            };
        };
        default {
            ["INVALID SERVICE REQUEST."] remoteExec ["systemChat", _player];
        };
    };
    if (_veh isKindOf "Air") then { call FADE_updateHelipadMarkers };
};

// -----------------------------------------------------------------------------
// Spawn land vehicle at VEH_1 or VEH_2 using BIS_fnc_findSafePosition
// -----------------------------------------------------------------------------
FADE_spawnLandVehicle = {
    params ["_vehicleClass", "_player", ["_vehPointIndex", -1]];
    if (isNil "_vehicleClass" || { _vehicleClass == "" }) exitWith {
        ["INVALID VEHICLE CLASS."] remoteExec ["systemChat", _player];
    };
    if (!isClass (configFile >> "CfgVehicles" >> _vehicleClass)) exitWith {
        [format ["UNKNOWN VEHICLE CLASS: %1", _vehicleClass]] remoteExec ["systemChat", _player];
    };
    if (count FADE_vehiclePoints == 0) exitWith {
        ["NO VEH SPAWN POINTS. CONFIGURE VEH_1/2 IN EDEN."] remoteExec ["systemChat", _player];
    };

    // Pick a spawn point: optional index from Vehicle GUI, else random
    private _centerObj = if (_vehPointIndex >= 0 && {_vehPointIndex < count FADE_vehiclePoints}) then {
        FADE_vehiclePoints select _vehPointIndex
    } else {
        selectRandom FADE_vehiclePoints
    };
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
// Duplicate a vehicle at base: fresh spawn (full fuel/damage default) via same rules as Vehicle GUI spawn.
// -----------------------------------------------------------------------------
FADE_duplicateVehicleAtBase = {
    params ["_src", "_player"];
    if (isNull _src) exitWith { ["INVALID VEHICLE."] remoteExec ["systemChat", _player] };
    if (!alive _src) exitWith { ["CANNOT DUPLICATE A DESTROYED VEHICLE."] remoteExec ["systemChat", _player] };
    if (
        _src isKindOf "Man"
        || { _src isKindOf "StaticWeapon" }
        || { _src isKindOf "ParachuteBase" }
    ) exitWith {
        ["SELECT AN AIRCRAFT OR LAND VEHICLE."] remoteExec ["systemChat", _player];
    };
    if (!(_src isKindOf "Air" || _src isKindOf "LandVehicle")) exitWith {
        ["SELECT AN AIRCRAFT OR LAND VEHICLE."] remoteExec ["systemChat", _player];
    };
    private _dist = (getPosATL _src) distance FADE_basePos;
    if (_dist > 1000) exitWith {
        ["VEHICLE MUST BE WITHIN 1000M OF BASE TO DUPLICATE."] remoteExec ["systemChat", _player];
    };
    private _cls = typeOf _src;
    if (_src isKindOf "Air") then {
        [_cls, _player, -1] call FADE_spawnHeli;
    } else {
        [_cls, _player, -1] call FADE_spawnLandVehicle;
    };
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

    [_cp, "This is your copilot. Ready at base and awaiting tasking. Over."] call FADE_aiSideChat;
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
FADE_globalMissionTypes = ["AreaOfOperations", "Hostage", "HVT", "ClearArea", "CAS", "InterceptConvoy", "SearchDestroy", "Operation"];
FADE_singleMissionTypes = ["TroopInsert", "TroopExtract", "Cargo", "MineClearing", "FindClearIEDs", "Medical", "MedicalKAT", "MASCAS", "MASCASKAT", "CASEVAC", "CSAR", "AssetRetrieval"];
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

FADE_generateOperationName = {
    private _partA = missionNamespace getVariable ["FADE_operationNamePartA", []];
    private _partB = missionNamespace getVariable ["FADE_operationNamePartB", []];
    if (_partA isEqualTo [] || { _partB isEqualTo [] }) exitWith { "Operation Iron Resolve" };
    format ["Operation %1 %2", selectRandom _partA, selectRandom _partB]
};

// Notify all other players (systemChat) when a mission starts; requester gets detailed hint only
FADE_notifyOthersMissionStarted = {
    params ["_player", "_missionDisplayName"];
    private _others = allPlayers select { !isNull _x && { _x != _player } };
    { [format ["%1 started %2 (mission task is for them only).", name _player, _missionDisplayName]] remoteExec ["systemChat", _x] } forEach _others;
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
    if (!([_player] call FADE_playerCanUseMissionsGui)) exitWith {
        ["<t size='1.2' color='#FF6666'>ACCESS DENIED</t><br/><br/><t color='#E0E0E0'>Missions GUI is restricted to group leaders by lobby settings.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
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
    private _needsLZ = _missionType in ["TroopInsert", "TroopExtract", "Cargo", "CASEVAC", "CSAR"];
    private _spawnsEnemies = _missionType in ["TroopExtract", "CAS", "HVT", "Hostage", "ClearArea", "InterceptConvoy", "AreaOfOperations", "CASEVAC", "CSAR", "AssetRetrieval", "SearchDestroy", "Operation"];
    private _minDistForPos = if (_spawnsEnemies) then { 1000 } else { FADE_minDistFromBase };
    private _destPos = [];
    private _attempt = 0;
    private _maxAttempts = 25;
    while { _attempt < _maxAttempts } do {
        _attempt = _attempt + 1;
        if (_missionType == "InterceptConvoy") then {
            _destPos = [0, 0, 0];
        } else {
            if (_missionType == "HVT" || { _missionType == "Hostage" } || { _missionType == "SearchDestroy" }) then {
                _destPos = [_minDistForPos] call FADE_findMissionPosUrban;
            } else {
                if (_missionType == "Operation") then {
                    _destPos = +FADE_basePos;
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
                                if (_missionType == "AssetRetrieval") then {
                                    _destPos = [_minDistForPos, 500] call FADE_findMissionPosAssetRetrieval;
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
            };
        };
        if (count _destPos >= 2 && { _missionType == "InterceptConvoy" || { _missionType == "Operation" } || { [_destPos] call FADE_missionPosClear } }) exitWith {};
    };
    if (count _destPos < 2 && { _missionType != "InterceptConvoy" } && { _missionType != "AreaOfOperations" }) exitWith {
        private _msg = if (_missionType == "HVT" || { _missionType == "Hostage" } || { _missionType == "SearchDestroy" }) then {
            "NO VALID URBAN AREA. PLACE CIV_T_* TRIGGERS IN TOWNS."
        } else {
            if (_missionType in ["Medical", "MedicalKAT", "MASCAS", "MASCASKAT"]) then {
                "MEDICAL_1 NOT FOUND IN EDEN."
            } else {
                if (_missionType == "AssetRetrieval") then {
                    "NO SPOT NEAR CIV ZONES (CIV_T_*) WITHIN 500 M, OR ZONES TOO CLOSE TO BASE."
                } else {
                    if (_needsLZ) then { "NO VALID LZ. CLEAR OF OBSTACLES REQUIRED. TRY AGAIN." } else { "NO VALID POSITION (or too close to other missions). TRY AGAIN." }
                }
            }
        };
        [format ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>%1</t>", _msg]] remoteExec ["FADE_showMissionHint", _player];
    };
    if (count _destPos >= 2 && { !([_destPos] call FADE_missionPosClear) } && { _missionType != "InterceptConvoy" } && { _missionType != "Operation" }) exitWith {
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No position at least 2 km from other missions. Try again.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    if (_isGlobal) then {
        private _operationName = [] call FADE_generateOperationName;
        missionNamespace setVariable ["FADE_globalMission", [_missionType, _player, _destPos, _playerUid, _operationName]];
        missionNamespace setVariable ["FADE_currentMissionType", _missionType];
        missionNamespace setVariable ["FADE_currentMissionPlayer", _player];
        publicVariable "FADE_globalMission";
        publicVariable "FADE_currentMissionType";
    } else {
        private _operationName = [] call FADE_generateOperationName;
        _singleList pushBack [_missionType, _player, _destPos, _playerUid, _operationName];
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
publicVariable "FADE_duplicateVehicleAtBase";
publicVariable "FADE_despawnVehicle";
publicVariable "FADE_serviceVehicle";
publicVariable "FADE_serviceVehiclePart";
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
publicVariable "FADE_fires_spawnPiece";
publicVariable "FADE_fires_despawnSlot";
publicVariable "FADE_fires_rearmSlot";
publicVariable "FADE_fires_requestState";
publicVariable "FADE_fires_setAmmoAmount";
publicVariable "FADE_fires_spawnAmmoTruck";

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
            {
                private _g = _x;
                if (!isNull _g) then {
                    { private _u = _x; if (!isNull _u) then { deleteVehicle _u } } forEach units _g;
                    deleteGroup _g;
                };
            } forEach _aoGroups;
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
    if (_missionType == "Operation" && { _taskId != "" }) then {
        missionNamespace setVariable ["FADE_operationAborted_" + _taskId, true];
        private _ent = missionNamespace getVariable ["FADE_operationEntities_" + _taskId, []];
        if (count _ent >= 2) then {
            private _grps = _ent select 0;
            private _marks = _ent select 1;
            {
                private _g = _x;
                if (!isNull _g) then {
                    { private _u = _x; if (!isNull _u) then { deleteVehicle _u } } forEach units _g;
                    deleteGroup _g;
                };
            } forEach _grps;
            { [_x] call FADE_deleteMarkerSafe } forEach _marks;
            if (count _ent >= 6) then {
                private _vehs = _ent select 4;
                private _barrels = _ent select 5;
                { if (!isNull _x) then { deleteVehicle _x } } forEach _vehs;
                { if (!isNull _x) then { deleteVehicle _x } } forEach _barrels;
            };
        };
        missionNamespace setVariable ["FADE_operationEntities_" + _taskId, nil];
        missionNamespace setVariable ["FADE_operationCapState_" + _taskId, nil];
        missionNamespace setVariable ["FADE_operationZoneCenters_" + _taskId, nil];
        missionNamespace setVariable ["FADE_operationMakeVehFn_" + _taskId, nil];
    };
    if (_missionType == "SearchDestroy" && { _taskId != "" }) then {
        missionNamespace setVariable ["FADE_sdAborted_" + _taskId, true];
        private _ent = missionNamespace getVariable ["FADE_searchDestroyEntities_" + _taskId, []];
        if (count _ent >= 1) then {
            private _slot0 = _ent select 0;
            if (typeName _slot0 == "ARRAY") then {
                {
                    private _g = _x;
                    if (!isNull _g) then {
                        { private _u = _x; if (!isNull _u) then { deleteVehicle _u } } forEach units _g;
                        deleteGroup _g;
                    };
                } forEach _slot0;
                if (count _ent >= 2) then {
                    private _sdObjs = _ent select 1;
                    if (_sdObjs isEqualType []) then {
                        { if (!isNull _x) then { deleteVehicle _x } } forEach _sdObjs;
                    };
                };
            } else {
                {
                    private _g = _x;
                    if (!isNull _g) then {
                        { private _u = _x; if (!isNull _u) then { deleteVehicle _u } } forEach units _g;
                        deleteGroup _g;
                    };
                } forEach _ent;
            };
        };
        private _m = missionNamespace getVariable ["FADE_searchDestroyMarker_" + _taskId, ""];
        if (_m != "") then { [_m] call FADE_deleteMarkerSafe };
        missionNamespace setVariable ["FADE_searchDestroyEntities_" + _taskId, nil];
        missionNamespace setVariable ["FADE_searchDestroyMarker_" + _taskId, nil];
    };
    if (_missionType == "AssetRetrieval" && { _taskId != "" }) then {
        missionNamespace setVariable ["FADE_assetAborted_" + _taskId, true];
        private _ent = missionNamespace getVariable ["FADE_assetEntities_" + _taskId, []];
        if (count _ent >= 1) then {
            private _grps = _ent select 0;
            {
                private _g = _x;
                if (!isNull _g) then {
                    { private _u = _x; if (!isNull _u) then { deleteVehicle _u } } forEach units _g;
                    deleteGroup _g;
                };
            } forEach _grps;
        };
        private _objs = missionNamespace getVariable ["FADE_assetObjects_" + _taskId, []];
        { if (!isNull _x) then { deleteVehicle _x } } forEach _objs;
        missionNamespace setVariable ["FADE_assetEntities_" + _taskId, nil];
        missionNamespace setVariable ["FADE_assetObjects_" + _taskId, nil];
    };
    if (_missionType == "CSAR" && { _taskId != "" }) then {
        private _w = missionNamespace getVariable ["FADE_csarWreck_" + _taskId, objNull];
        if (!isNull _w) then { deleteVehicle _w };
        missionNamespace setVariable ["FADE_csarWreck_" + _taskId, nil];
    };
    [_player] call FADE_clearActiveMission;
    ["<t size='1.2' color='#B0B0B0'>MISSION ABORTED</t><br/><br/><t color='#E0E0E0'>Mission cancelled.</t>"] remoteExec ["FADE_showMissionHint", _player];
};

// Asset Retrieval: secure intel from addAction (server).
FADE_assetIntelTakeServer = {
    params ["_taskId", "_intelObj"];
    if (!isServer) exitWith {};
    missionNamespace setVariable ["FADE_assetIntelTaken_" + _taskId, true];
    if (!isNull _intelObj) then { deleteVehicle _intelObj };
};
publicVariable "FADE_assetIntelTakeServer";

// Abort by mission slot (G1, S1, S2, S3). If owner object no longer exists, clear slot directly.
FADE_abortMissionSlot = {
    params ["_slotKey", "_requester"];
    if (isNull _requester) exitWith {};
    private _slot = toUpper _slotKey;
    switch _slot do {
        case "G1": {
            private _global = missionNamespace getVariable ["FADE_globalMission", []];
            if (count _global < 2) exitWith { ["G1 has no active mission."] remoteExec ["systemChat", _requester] };
            private _owner = _global param [1, objNull];
            if (isNull _owner) then {
                missionNamespace setVariable ["FADE_globalMission", []];
                missionNamespace setVariable ["FADE_currentMissionType", ""];
                missionNamespace setVariable ["FADE_currentMissionPlayer", objNull];
                publicVariable "FADE_globalMission";
                publicVariable "FADE_currentMissionType";
                ["G1 slot was stale and is now cleared."] remoteExec ["systemChat", _requester];
            } else {
                [_owner] call FADE_abortMission;
                [format ["Aborted G1 mission started by %1.", name _owner]] remoteExec ["systemChat", _requester];
            };
        };
        case "S1";
        case "S2";
        case "S3": {
            private _idx = switch _slot do { case "S1": {0}; case "S2": {1}; default {2}; };
            private _single = missionNamespace getVariable ["FADE_singleMissions", []];
            private _entry = _single param [_idx, []];
            if (count _entry < 2) exitWith { [format ["%1 has no active mission.", _slot]] remoteExec ["systemChat", _requester] };
            private _owner = _entry param [1, objNull];
            if (isNull _owner) then {
                _single deleteAt _idx;
                missionNamespace setVariable ["FADE_singleMissions", _single];
                publicVariable "FADE_singleMissions";
                [format ["%1 slot was stale and is now cleared.", _slot]] remoteExec ["systemChat", _requester];
            } else {
                [_owner] call FADE_abortMission;
                [format ["Aborted %1 mission started by %2.", _slot, name _owner]] remoteExec ["systemChat", _requester];
            };
        };
        default {
            ["Unknown mission slot key."] remoteExec ["systemChat", _requester];
        };
    };
};
publicVariable "FADE_abortMissionSlot";

// Jukebox: stop-all (also Scenario Admin); must be defined before FADE_adminCleanupAction references it.
FAC_jukebox_stopAllMusic = {
    if (!isServer) exitWith {};
    params [["_requester", objNull]];
    missionNamespace setVariable ["FAC_jukebox_activeSources", [], true];
    [] remoteExec ["FAC_jukebox_clientStopAll", 0];
    if (!isNull _requester) then {
        ["All jukebox music stopped (every source)."] remoteExec ["systemChat", _requester];
    };
};
publicVariable "FAC_jukebox_stopAllMusic";

// Admin cleanup actions from Scenario GUI.
FADE_adminCleanupAction = {
    params ["_action", "_requester"];
    if (isNull _requester) exitWith {};
    switch (_action) do {
        case "abortAllMissions": {
            private _global = missionNamespace getVariable ["FADE_globalMission", []];
            if (count _global >= 2) then {
                private _gOwner = _global param [1, objNull];
                if (!isNull _gOwner) then { [_gOwner] call FADE_abortMission };
            };
            private _single = + (missionNamespace getVariable ["FADE_singleMissions", []]);
            {
                private _sOwner = _x param [1, objNull];
                if (!isNull _sOwner) then { [_sOwner] call FADE_abortMission };
            } forEach _single;
            missionNamespace setVariable ["FADE_globalMission", []];
            missionNamespace setVariable ["FADE_singleMissions", []];
            missionNamespace setVariable ["FADE_currentMissionType", ""];
            missionNamespace setVariable ["FADE_currentMissionPlayer", objNull];
            publicVariable "FADE_globalMission";
            publicVariable "FADE_singleMissions";
            publicVariable "FADE_currentMissionType";
            ["Admin cleanup complete: all mission slots aborted/cleared."] remoteExec ["systemChat", _requester];
        };
        case "despawnCivilians": {
            if (!isNil "FADE_civZoneState" && { FADE_civZoneState isEqualType createHashMap }) then {
                { [_x] call FADE_civ_despawnZone } forEach (keys FADE_civZoneState);
            };
            if (!isNil "FADE_roadVehicles") then {
                { if (!isNull _x) then { { deleteVehicle _x } forEach crew _x; deleteVehicle _x } } forEach FADE_roadVehicles;
                FADE_roadVehicles = [];
            };
            ["Admin cleanup complete: civilians despawned."] remoteExec ["systemChat", _requester];
        };
        case "despawnOpfor": {
            {
                if (!isNull _x && { side _x == east }) then { deleteVehicle _x };
            } forEach allUnits;
            {
                if (!isNull _x && { side _x == east }) then {
                    { deleteVehicle _x } forEach crew _x;
                    deleteVehicle _x;
                };
            } forEach vehicles;
            ["Admin cleanup complete: OPFOR despawned."] remoteExec ["systemChat", _requester];
        };
        case "makeZeus": {
            private _oldScript = _requester getVariable ["FAC_scriptGrantedCurator", objNull];
            if (!isNull _oldScript) then {
                if (getAssignedCuratorLogic _requester == _oldScript) then { unassignCurator _oldScript };
                if (!isNull _oldScript) then { deleteVehicle _oldScript };
                _requester setVariable ["FAC_scriptGrantedCurator", nil, true];
            };
            private _existing = getAssignedCuratorLogic _requester;
            if (!isNull _existing) then { unassignCurator _existing };
            private _grp = createGroup [sideLogic, true];
            private _spawnPos = if (!isNull _requester) then { getPosATL _requester } else { [0, 0, 0] };
            private _curator = _grp createUnit ["ModuleCurator_F", _spawnPos, [], 0, "NONE"];
            if (isNull _curator) exitWith {
                ["Could not create Zeus module."] remoteExec ["systemChat", _requester];
            };
            _curator setVariable ["owner", getPlayerUID _requester, true];
            _requester assignCurator _curator;
            _requester setVariable ["FAC_scriptGrantedCurator", _curator, true];
            private _objs = [];
            _objs append vehicles;
            { if (!isNull _x && { alive _x }) then { _objs pushBackUnique _x } } forEach allUnits;
            _curator addCuratorEditableObjects [_objs, true];
            [format ["%1 is now Zeus.", name _requester]] remoteExec ["systemChat", 0];
        };
        case "removeMyZeus": {
            private _mine = _requester getVariable ["FAC_scriptGrantedCurator", objNull];
            private _assigned = getAssignedCuratorLogic _requester;
            if (isNull _mine || { isNull _assigned } || { _assigned != _mine }) exitWith {
                ["No script-granted Zeus to remove (or you are using a different Zeus module)."] remoteExec ["systemChat", _requester];
            };
            unassignCurator _mine;
            deleteVehicle _mine;
            _requester setVariable ["FAC_scriptGrantedCurator", nil, true];
            [format ["%1 is no longer Zeus (script module removed).", name _requester]] remoteExec ["systemChat", 0];
        };
        case "teleportAllToBase": {
            // Same anchor as Fast Travel HQ (rsc/TeleportGui.sqf FAC_teleportGui_destBaseKey)
            private _baseObj = missionNamespace getVariable ["teleportBase", objNull];
            if (isNull _baseObj) exitWith {
                ["Teleport-all failed: Eden object 'teleportBase' not found (place logic/object for HQ)."] remoteExec ["systemChat", _requester];
            };
            private _center = getPosATL _baseObj;
            private _face = getDir _baseObj;
            private _movedVehs = [];
            private _idx = 0;
            {
                if (isNull _x) then { continue };
                private _veh = vehicle _x;
                if (_veh in _movedVehs) then { continue };
                _movedVehs pushBack _veh;
                private _ring = 2 + (_idx mod 4) * 1.2;
                private _bear = _face + (_idx * 37);
                private _flat = _center getPos [_ring, _bear];
                // setPosATL Z is ATL (above terrain), not ASL — do not use getTerrainHeightASL here.
                private _atl = [_flat select 0, _flat select 1, 0.25];
                _veh setPosATL _atl;
                if (_veh isKindOf "Man") then {
                    _veh setDir ((getPosATL _veh) getDir _center);
                } else {
                    _veh setDir _face;
                };
                _idx = _idx + 1;
            } forEach allPlayers;
            [format ["Admin: all players teleported to HQ / teleportBase (by %1).", name _requester]] remoteExec ["systemChat", 0];
        };
        case "stopAllMusic": {
            [_requester] call FAC_jukebox_stopAllMusic;
        };
        default {
            ["Admin cleanup failed: unknown action."] remoteExec ["systemChat", _requester];
        };
    };
};
publicVariable "FADE_adminCleanupAction";

// Surrender Challenge: false = no player hotkey/GUI; server ignores remoteExec (rsc/SurrenderChallenge.sqf unchanged).
FAC_surrenderChallenge_playerEnabled = false;
publicVariable "FAC_surrenderChallenge_playerEnabled";

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
    if (!(missionNamespace getVariable ["FAC_surrenderChallenge_playerEnabled", false])) exitWith {};
    params ["_player", "_targetUnit", ["_playerDir", -1]];
    if (_playerDir < 0) then { _playerDir = getDir _player };
    diag_log format ["[FAC SurrenderChallenge] Server received request from %1 for target %2", name _player, if (isNull _targetUnit) then {"null"} else {name _targetUnit}];
    [_player, _targetUnit, _playerDir] execVM "rsc\SurrenderChallenge.sqf";
};
publicVariable "FAC_surrenderChallenge_start";

// -----------------------------------------------------------------------------
// Jukebox -- per-source playback: Radio_1..4 (Eden) and vehicle:<netId> (in-vehicle loudspeaker action).
// Clients run playSound3D on the resolved emitter; FAC_jukebox_activeSources = [[key,song,vol,dist],...] (public).
// No client-side JIP replay of activeSources (avoids duplicate playSound3D / random restarts on dedicated).
// remoteExec: [_song, _sourceKey, _requester, _vol, _dist] remoteExec ["FAC_jukebox_serverPlay", 2]
// Stop:        ["", _sourceKey, _requester] remoteExec ["FAC_jukebox_serverPlay", 2]
// Stop all:    [_requester] remoteExec ["FAC_jukebox_stopAllMusic", 2]  →  [] remoteExec ["FAC_jukebox_clientStopAll", 0]
// Debug: FAC_jukebox_debug - systemChat to requester + diag_log on server. true = verbose chat (dev only).
// -----------------------------------------------------------------------------
FAC_jukebox_debug = false;
publicVariable "FAC_jukebox_debug";

missionNamespace setVariable ["FAC_jukebox_activeSources", [], true];

FAC_jukebox_serverDbg = {
    params ["_msg", ["_to", objNull]];
    if (!isServer) exitWith {};
    diag_log format ["[FAC Jukebox] %1", _msg];
    if (!(missionNamespace getVariable ["FAC_jukebox_debug", false])) exitWith {};
    if (isNull _to) exitWith {};
    [_msg] remoteExec ["FAC_jukebox_serverDbgChat", _to];
};

// Resolve emitter: radio:Radio_1 -> missionNamespace object; vehicle:<netId> -> objectFromNetId
FAC_jukebox_fnc_resolveSourceObject = {
    params ["_sourceKey"];
    if (_sourceKey find "radio:" == 0) exitWith {
        private _eden = _sourceKey select [6];
        missionNamespace getVariable [_eden, objNull]
    };
    if (_sourceKey find "vehicle:" == 0) exitWith {
        private _nid = _sourceKey select [8];
        if (_nid == "") exitWith {objNull};
        objectFromNetId _nid
    };
    objNull
};

FAC_jukebox_fnc_requesterMayControlVehicleSource = {
    params [["_requester", objNull], ["_veh", objNull]];
    if (isNull _requester || {!isPlayer _requester} || {isNull _veh}) exitWith {false};
    _requester in crew _veh && { vehicle _requester == _veh }
};

FAC_jukebox_fnc_setActiveSourceSong = {
    params ["_key", "_song", ["_vol", 4], ["_dist", 400]];
    private _arr = missionNamespace getVariable ["FAC_jukebox_activeSources", []];
    private _filt = _arr select { (_x select 0) != _key };
    if (_song != "") then {
        _vol = ((round _vol) max 1) min 25;
        _dist = ((round _dist) max 50) min 2500;
        _filt pushBack [_key, _song, _vol, _dist];
    };
    missionNamespace setVariable ["FAC_jukebox_activeSources", _filt, true];
};


FAC_jukebox_serverPlay = {
    if (!isServer) exitWith {};
    params [["_song", ""], ["_sourceKey", ""], ["_requester", objNull], ["_vol", 4], ["_dist", 400]];

    if (_sourceKey == "") exitWith {
        diag_log "FAC_jukebox_serverPlay: empty _sourceKey";
    };

    if (_song == "") exitWith {
        [format ["Stopped source %1 (from %2)", _sourceKey, if (isNull _requester) then {"?"} else { name _requester }], _requester] call FAC_jukebox_serverDbg;
        [_sourceKey, ""] call FAC_jukebox_fnc_setActiveSourceSong;
        ["", _sourceKey] remoteExec ["FAC_jukebox_clientPlay", 0];
    };

    private _emitter = [_sourceKey] call FAC_jukebox_fnc_resolveSourceObject;
    if (isNull _emitter) exitWith {
        diag_log format ["FAC_jukebox_serverPlay: no emitter for %1", _sourceKey];
        [format ["FAIL: jukebox source not available (%1).", _sourceKey], _requester] call FAC_jukebox_serverDbg;
    };

    if (_sourceKey find "vehicle:" == 0) then {
        if (
            isNull _requester
            || {!([_requester, _emitter] call FAC_jukebox_fnc_requesterMayControlVehicleSource)}
        ) exitWith {
            diag_log "FAC_jukebox_serverPlay: vehicle source — requester not crew";
            ["FAIL: jukebox — you must be in that vehicle to use its loudspeaker.", _requester] call FAC_jukebox_serverDbg;
        };
    };

    private _sndCfg = missionConfigFile >> "CfgSounds" >> _song;
    if (!isClass _sndCfg) then { _sndCfg = configFile >> "CfgSounds" >> _song };
    if (!isClass _sndCfg) exitWith {
        diag_log format ["FAC_jukebox_serverPlay: CfgSounds %1 not found (missionConfigFile/configFile)", _song];
        [format ["FAIL: CfgSounds %1 missing (description.ext / mod).", _song], _requester] call FAC_jukebox_serverDbg;
    };

    _vol = ((round _vol) max 1) min 25;
    _dist = ((round _dist) max 50) min 2500;

    [_sourceKey, _song, _vol, _dist] call FAC_jukebox_fnc_setActiveSourceSong;
    [format ["OK: %1 @ %2 (vol=%3 dist=%4)", _song, _sourceKey, _vol, _dist], _requester] call FAC_jukebox_serverDbg;
    [_song, _sourceKey, _vol, _dist] remoteExec ["FAC_jukebox_clientPlay", 0];

    if (_sourceKey find "vehicle:" == 0) then {
        [_emitter, _sourceKey] spawn {
            params ["_veh", "_key"];
            waitUntil { sleep 1; isNull _veh || {!alive _veh} };
            if (isNull _veh || {!alive _veh}) then {
                private _arr = missionNamespace getVariable ["FAC_jukebox_activeSources", []];
                private _hit = _arr select { (_x select 0) == _key && { (_x select 1) != "" } };
                if (!(_hit isEqualTo [])) then {
                    [_key, ""] call FAC_jukebox_fnc_setActiveSourceSong;
                    ["", _key] remoteExec ["FAC_jukebox_clientPlay", 0];
                };
            };
        };
    };
};
publicVariable "FAC_jukebox_serverPlay";

// FAC_jukebox_stopAllMusic: defined above (before FADE_adminCleanupAction).

// Mission test suite — manual only. Debug console: [player] remoteExec ["FAC_missionTestSuite_execServer", 2]  (systemChat to that player; use [] to broadcast)
FAC_missionTestSuite_execServer = {
    if (!isServer) exitWith {};
    private _to = _this param [0, objNull];
    private _startMsg = "[FAC TestSuite] Server: starting...";
    if (!isNull _to && { isPlayer _to }) then {
        [_startMsg] remoteExec ["systemChat", _to];
    } else {
        [_startMsg] remoteExec ["systemChat", 0];
    };
    if (isNil "FAC_missionTestSuite_runServer") then {
        call compile preprocessFileLineNumbers "rsc\MissionTestSuite.sqf";
    };
    private _res = [_to] call FAC_missionTestSuite_runServer;
    if (isNil "_res" || { count _res < 2 }) then {
        private _err = "[FAC TestSuite] Server: aborted (script error — check RPT).";
        if (!isNull _to && { isPlayer _to }) then { [_err] remoteExec ["systemChat", _to]; } else { [_err] remoteExec ["systemChat", 0]; };
    } else {
        _res params ["_p", "_f"];
        private _end = format ["[FAC TestSuite] Server finished: %1 pass, %2 fail — see RPT for [FAC TestSuite].", _p, _f];
        if (!isNull _to && { isPlayer _to }) then { [_end] remoteExec ["systemChat", _to]; } else { [_end] remoteExec ["systemChat", 0]; };
    };
};
publicVariable "FAC_missionTestSuite_execServer";
