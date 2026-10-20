// FADE_FactionScenario.sqf — playable faction sides, opposition map, validation (server + client)

if (isNil "FADE_getFactionSideNum") then {
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
};

FADE_playableFactionSideNums = [0, 1, 2];

// EAST/WEST/GUER oppose each other; CIV is never a playable player faction.
FADE_getOpposedSideNums = {
    params ["_friendlySideNum"];
    switch (_friendlySideNum) do {
        case 0: { [1, 2] };
        case 1: { [0, 2] };
        case 2: { [0, 1] };
        default { [0, 1, 2] };
    };
};

// CfgFactionClasses display names (cached via FADE_collectFactionsForSideNums). Skip unresolved $STR_ keys.
FADE_factionDisplayNameSafe = {
    params ["_faction", ["_cfg", configNull]];
    if (_faction == "") exitWith { "Unknown" };
    if (isNull _cfg) then { _cfg = configFile >> "CfgFactionClasses" >> _faction };
    if (!isClass _cfg) exitWith { (_faction splitString "_") joinString " " };
    private _dn = getText (_cfg >> "displayName");
    if (_dn == "" || { _dn find "STR_" == 0 }) exitWith {
        (_faction splitString "_") joinString " "
    };
    _dn
};

FADE_collectFactionsForSideNums = {
    params [["_sideNums", []]];
    // [3] call unwraps to scalar 3 — normalize so apply always receives an array.
    if (_sideNums isEqualType 0) then { _sideNums = [_sideNums] };
    if (!(_sideNums isEqualType [])) then { _sideNums = [] };
    // #region agent log
    diag_log format ["[FAC DbgBrowser 62d308] H11 collectFactionsForSideNums sideNums=%1", _sideNums];
    // #endregion
    private _key = (_sideNums apply { str _x }) joinString ",";
    private _cache = missionNamespace getVariable ["FADE_factionListCacheV2", createHashMap];
    if (_key in _cache) exitWith { +(_cache get _key) };

    private _result = [];
    {
        private _cfg = _x;
        private _sn = getNumber (_cfg >> "side");
        if (_sn in _sideNums) then {
            private _faction = configName _cfg;
            _result pushBack [_faction, [_faction, _cfg] call FADE_factionDisplayNameSafe];
        };
    } forEach ("true" configClasses (configFile >> "CfgFactionClasses"));
    _result = _result apply { [_x select 1, _x select 0] };
    _result sort true;
    _result = _result apply { [_x select 1, _x select 0] };
    _cache set [_key, +_result];
    missionNamespace setVariable ["FADE_factionListCacheV2", _cache];
    +_result
};

// Prefer the server-published rows (infantry only). Fall back to a local config scan before that list arrives.
FADE_factionRowsForSideNums = {
    params [["_sideNums", []]];
    if (_sideNums isEqualType 0) then { _sideNums = [_sideNums] };
    if (!(_sideNums isEqualType [])) then { _sideNums = [] };
    private _rows = missionNamespace getVariable ["FADE_factionChoiceRows", []];
    if (_rows isEqualTo []) exitWith { [_sideNums] call FADE_collectFactionsForSideNums };
    private _out = [];
    {
        if ((_x select 2) in _sideNums) then {
            _out pushBack [_x select 0, _x select 1];
        };
    } forEach _rows;
    _out
};

FADE_getPlayableFactions = {
    [FADE_playableFactionSideNums] call FADE_factionRowsForSideNums
};

FADE_getEnemyFactionsForFriendlyFaction = {
    params ["_friendlyFaction"];
    private _fsn = [_friendlyFaction, 1] call FADE_getFactionSideNum;
    private _opposed = [_fsn] call FADE_getOpposedSideNums;
    [_opposed] call FADE_factionRowsForSideNums
};

FADE_pickDefaultEnemyFactionForFriendly = {
    params ["_friendlyFaction", ["_prefer", ""]];
    private _enemies = [_friendlyFaction] call FADE_getEnemyFactionsForFriendlyFaction;
    if (_enemies isEqualTo []) exitWith {
        if (_prefer != "") then { _prefer } else { "OPF_F" }
    };
    private _enemyIds = _enemies apply { _x select 0 };
    if (_prefer != "" && { _prefer in _enemyIds }) exitWith { _prefer };
    private _fsn = [_friendlyFaction, 1] call FADE_getFactionSideNum;
    private _defaults = switch (_fsn) do {
        case 0: { ["BLU_F", "NATO_F"] };
        case 1: { ["OPF_F", "OPF_G_F"] };
        case 2: { ["BLU_F", "OPF_F"] };
        default { ["OPF_F", "BLU_F"] };
    };
    private _picked = { if (_x in _enemyIds) exitWith { _x } } forEach _defaults;
    if (_picked isEqualType "" && { _picked != "" }) exitWith { _picked };
    _enemies select 0 select 0
};

FADE_scenarioFactionsDescribeIssue = {
    params ["_friendlyFaction", "_enemyFaction"];
    if (_friendlyFaction == "" || { _enemyFaction == "" }) exitWith { "missing_faction" };
    if (_friendlyFaction == _enemyFaction) exitWith { "same_faction" };
    private _fsn = [_friendlyFaction, 1] call FADE_getFactionSideNum;
    private _esn = [_enemyFaction, 0] call FADE_getFactionSideNum;
    if (_fsn == 3) exitWith { "civ_friendly" };
    if (!(_fsn in FADE_playableFactionSideNums)) exitWith { "friendly_not_playable" };
    if (_fsn == _esn) exitWith { "same_side" };
    private _opposed = [_fsn] call FADE_getOpposedSideNums;
    if (!(_esn in _opposed)) exitWith { "wrong_side" };
    ""
};

FADE_normalizeScenarioFactions = {
    params ["_friendlyFaction", "_enemyFaction"];
    private _issues = [];
    private _ff = _friendlyFaction;
    private _ef = _enemyFaction;
    private _fsn = [_ff, 1] call FADE_getFactionSideNum;
    if (_fsn == 3 || { !(_fsn in FADE_playableFactionSideNums) }) then {
        _issues pushBack "friendly_not_playable";
        _ff = missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"];
        _fsn = [_ff, 1] call FADE_getFactionSideNum;
        if (_fsn == 3 || { !(_fsn in FADE_playableFactionSideNums) }) then { _ff = "BLU_F" };
    };
    private _issue = [_ff, _ef] call FADE_scenarioFactionsDescribeIssue;
    if (_issue != "") then {
        _issues pushBack _issue;
        _ef = [_ff, _ef] call FADE_pickDefaultEnemyFactionForFriendly;
        if ([_ff, _ef] call FADE_scenarioFactionsDescribeIssue != "") then {
            _ef = [_ff, ""] call FADE_pickDefaultEnemyFactionForFriendly;
        };
    };
    [_ff, _ef, _issues]
};

FADE_scenarioFactionsIssueHint = {
    params ["_issues", ["_friendlyFaction", ""], ["_enemyFaction", ""]];
    if (_issues isEqualTo []) exitWith { "" };
    private _getDn = missionNamespace getVariable ["FADE_getFactionDisplayName", { _this select 0 }];
    private _lines = [];
    {
        switch _x do {
            case "same_faction": {
                _lines pushBack "Enemy faction cannot match friendly - enemy adjusted.";
            };
            case "same_side": {
                _lines pushBack "Enemy faction must be on an opposed side - enemy adjusted.";
            };
            case "wrong_side": {
                _lines pushBack format [
                    "Enemy must oppose %1 - set to %2.",
                    [_friendlyFaction] call _getDn,
                    [_enemyFaction] call _getDn
                ];
            };
            case "friendly_not_playable";
            case "civ_friendly": {
                _lines pushBack "Civilian factions cannot be the player faction - friendly reset.";
            };
            case "mission_active_factions_locked": {
                _lines pushBack "Faction changes blocked while a mission is active - abort missions first.";
            };
            case "units_despawned": {
                _lines pushBack "Old faction patrols despawning in background - new spawns use updated factions.";
            };
            default {
                _lines pushBack "Faction pairing corrected for scenario.";
            };
        };
    } forEach _issues;
    _lines joinString "<br/>"
};

FADE_isScenarioFriendlyUnit = {
    params ["_unit"];
    if (isNull _unit) exitWith { false };
    if (isPlayer _unit) exitWith { true };
    side _unit == (missionNamespace getVariable ["FADE_sideFriendly", west])
};

FADE_isScenarioEnemyUnit = {
    params ["_unit"];
    if (isNull _unit) exitWith { false };
    if (isPlayer _unit) exitWith { false };
    side _unit == (missionNamespace getVariable ["FADE_sideEnemy", east])
};

if (isServer) then {
    FADE_syncScenarioSideFriendship = {
        private _fsn = missionNamespace getVariable ["FADE_scenarioFriendlySideNum", 1];
        private _esn = missionNamespace getVariable ["FADE_scenarioEnemySideNum", 0];
        private _sf = missionNamespace getVariable ["FADE_sideFriendly", west];
        private _se = missionNamespace getVariable ["FADE_sideEnemy", east];
        private _combatSides = [east, west, resistance];
        private _opposed = [_fsn] call FADE_getOpposedSideNums;
        {
            private _a = _x;
            private _asn = _a call BIS_fnc_sideID;
            {
                private _b = _x;
                private _bsn = _b call BIS_fnc_sideID;
                private _f = 0.6;
                if (_a isEqualTo _b) then {
                    _f = 1;
                } else {
                    if ((_asn == _fsn && { _bsn == _esn }) || { _asn == _esn && { _bsn == _fsn } }) then {
                        _f = 0;
                    } else {
                        if (_asn == _fsn && { _bsn in _opposed }) then { _f = 0 };
                        if (_bsn == _fsn && { _asn in _opposed }) then { _f = 0 };
                        if (_fsn == 2 && { _asn in [0, 1] && { _bsn in [0, 1] } }) then { _f = 0 };
                    };
                };
                _a setFriend [_b, _f];
            } forEach _combatSides;
        } forEach _combatSides;
    };

    // Join one player onto FADE_sideFriendly when Eden/respawn left them on the slot side (usually WEST).
    FADE_syncPlayerToScenarioFriendlySide = {
        params [["_unit", objNull]];
        if (!isServer) exitWith { false };
        if (isNull _unit || { !isPlayer _unit } || { !alive _unit }) exitWith { false };
        private _sf = missionNamespace getVariable ["FADE_sideFriendly", west];
        if (side _unit == _sf) exitWith { true };
        private _oldGrp = group _unit;
        private _grp = createGroup [_sf, true];
        [_unit] joinSilent _grp;
        if (!isNull _oldGrp && { count units _oldGrp == 0 }) then { deleteGroup _oldGrp };
        true
    };

    FADE_syncPlayersToScenarioFriendlySide = {
        { [_x] call FADE_syncPlayerToScenarioFriendlySide } forEach allPlayers;
    };

    // Client → server (JIP / respawn): ensure this player matches scenario friendly side.
    FADE_requestScenarioFriendlySideSync = {
        params [["_player", objNull]];
        if (!isServer) exitWith {};
        [_player] call FADE_syncPlayerToScenarioFriendlySide;
    };

    FADE_applyScenarioFactionSideSync = {
        call FADE_syncScenarioSideFriendship;
        call FADE_syncPlayersToScenarioFriendlySide;
    };

    // Respawn recreates Eden slot side (WEST); re-apply scenario friendly side after the unit exists.
    if (isNil { missionNamespace getVariable "FADE_scenarioFriendlySide_respawnEhId" }) then {
        private _ehId = addMissionEventHandler ["EntityRespawned", {
            params ["_newEntity", "_oldEntity"];
            if (!isPlayer _newEntity) exitWith {};
            [_newEntity] spawn {
                params ["_u"];
                sleep 0.25;
                if (!isNull _u && { alive _u } && { isPlayer _u }) then {
                    [_u] call FADE_syncPlayerToScenarioFriendlySide;
                };
            };
        }];
        missionNamespace setVariable ["FADE_scenarioFriendlySide_respawnEhId", _ehId];
    };

    // HashMap keys must be string/number — not Object/Group handles (getOrDefault errors at runtime).
    FADE_scenario_despawnProtObjKey = {
        params ["_obj"];
        if (isNull _obj) exitWith { "" };
        private _nid = netId _obj;
        if (_nid isEqualTo "") then { _nid = format ["%1", _obj] };
        _nid
    };

    FADE_scenario_despawnProtGrpKey = {
        params ["_grp"];
        if (isNull _grp) exitWith { "" };
        private _gid = groupId _grp;
        if (_gid isEqualType "") then { _gid } else { str _gid }
    };

    FADE_scenario_buildDespawnProtectionCache = {
        private _objects = createHashMap;
        private _groups = createHashMap;
        {
            private _k = [_x] call FADE_scenario_despawnProtObjKey;
            if (_k != "") then { _objects set [_k, true] };
        } forEach (missionNamespace getVariable ["FADE_rangeSpawned", []]);
        {
            private _k = [_x] call FADE_scenario_despawnProtObjKey;
            if (_k != "") then { _objects set [_k, true] };
        } forEach (missionNamespace getVariable ["FADE_rangeSpawnedMen", []]);
        if (missionNamespace getVariable ["FADE_cqbDrillActive", false]) then {
            {
                private _k = [_x] call FADE_scenario_despawnProtObjKey;
                if (_k != "") then { _objects set [_k, true] };
            } forEach (missionNamespace getVariable ["FADE_cqbSpawned", []]);
        };
        {
            if !(_x find "FADE_missionEnt_" == 0) then { continue };
            if ((_x find "FADE_missionEnt_cleaned_") == 0) then { continue };
            private _ent = missionNamespace getVariable [_x, createHashMap];
            if (!(_ent isEqualType createHashMap)) then { continue };
            {
                private _k = [_x] call FADE_scenario_despawnProtObjKey;
                if (_k != "") then { _objects set [_k, true] };
            } forEach (_ent getOrDefault ["vehicles", []]);
            {
                private _k = [_x] call FADE_scenario_despawnProtObjKey;
                if (_k != "") then { _objects set [_k, true] };
            } forEach (_ent getOrDefault ["objects", []]);
            {
                private _k = [_x] call FADE_scenario_despawnProtGrpKey;
                if (_k != "") then { _groups set [_k, true] };
            } forEach (_ent getOrDefault ["groups", []]);
            {
                if (_x isEqualType grpNull && { !isNull _x }) then {
                    private _k = [_x] call FADE_scenario_despawnProtGrpKey;
                    if (_k != "") then { _groups set [_k, true] };
                };
            } forEach (_ent getOrDefault ["groupRefs", []]);
        } forEach (allVariables missionNamespace);
        [_objects, _groups]
    };

    FADE_scenario_entityProtectedFromDespawnCached = {
        params ["_obj", "_objects", "_groups"];
        // #region agent log
        if (isNil "FADE_scenario_despawnDbgLogged") then {
            FADE_scenario_despawnDbgLogged = true;
            diag_log format ["[FAC DbgBrowser 62d308] H11 despawnProtCached keysAreStringNum objects=%1 groups=%2",
                _objects isEqualType createHashMap, _groups isEqualType createHashMap];
        };
        // #endregion
        if (isNull _obj) exitWith { true };
        if (_obj isKindOf "Man" && { isPlayer _obj }) exitWith { true };
        if (_obj getVariable ["FADE_baseDummy", false]) exitWith { true };
        private _objKey = [_obj] call FADE_scenario_despawnProtObjKey;
        if (_objKey != "" && { _objects getOrDefault [_objKey, false] }) exitWith { true };
        private _grp = grpNull;
        if (_obj isKindOf "Man") then { _grp = group _obj };
        if (_obj isKindOf "AllVehicles" && { count crew _obj > 0 }) then { _grp = group (driver _obj) };
        if (!isNull _grp) then {
            private _grpKey = [_grp] call FADE_scenario_despawnProtGrpKey;
            if (_grpKey != "" && { _groups getOrDefault [_grpKey, false] }) exitWith { true };
        };
        false
    };

    FADE_scenario_groupIsMissionRegistered = {
        params ["_grp", ["_groups", createHashMap]];
        if (isNull _grp) exitWith { false };
        if (_groups isEqualType createHashMap && { count _groups > 0 }) exitWith {
            private _grpKey = [_grp] call FADE_scenario_despawnProtGrpKey;
            _grpKey != "" && { _groups getOrDefault [_grpKey, false] }
        };
        {
            if !(_x find "FADE_missionEnt_" == 0) then { continue };
            if ((_x find "FADE_missionEnt_cleaned_") == 0) then { continue };
            private _ent = missionNamespace getVariable [_x, createHashMap];
            if (!(_ent isEqualType createHashMap)) then { continue };
            if (_grp in (_ent getOrDefault ["groups", []])) exitWith { true };
            {
                if (_grp in _x) exitWith { true };
            } forEach (_ent getOrDefault ["groupRefs", []]);
        } forEach (allVariables missionNamespace);
        false
    };

    FADE_scenario_entityProtectedFromDespawn = {
        params ["_obj"];
        private _cache = call FADE_scenario_buildDespawnProtectionCache;
        _cache params ["_objects", "_groups"];
        [_obj, _objects, _groups] call FADE_scenario_entityProtectedFromDespawnCached
    };

    // Despawn ambient scenario AI when friendly/enemy faction changes (patrols, recruits, orphans).
    // Skips players, active mission entities, and range/CQB training targets.
    // Pass sideEmpty for a side to omit it (e.g. admin enemy-only cleanup).
    FADE_despawnScenarioWorldUnits = {
        params [["_friendlySide", west], ["_enemySide", east]];
        private _sides = [];
        if (_friendlySide != sideEmpty) then { _sides pushBack _friendlySide };
        if (_enemySide != sideEmpty) then { _sides pushBack _enemySide };
        if (_sides isEqualTo []) exitWith {};

        if (!isNil "FADE_enemyPatrol_despawnAll") then { call FADE_enemyPatrol_despawnAll };

        if (!isNil "FADE_vg_pending" && { FADE_vg_pending isEqualType [] }) then {
            if (!isNil "FADE_vg_dropEntry") then {
                { [_x] call FADE_vg_dropEntry } forEach FADE_vg_pending;
            };
            FADE_vg_pending = [];
        };

        if (!isNil "FADE_opforAir_despawnAll") then { call FADE_opforAir_despawnAll };
        if (!isNil "FADE_opforDrone_despawnAll") then { call FADE_opforDrone_despawnAll };
        if (!isNil "FADE_aaa_despawnAll") then { call FADE_aaa_despawnAll };
        if (!isNil "FADE_dynamicRoadblocks_despawnAll") then { [] call FADE_dynamicRoadblocks_despawnAll };

        private _cache = call FADE_scenario_buildDespawnProtectionCache;
        _cache params ["_protectedObjects", "_missionGroups"];
        // #region agent log
        diag_log format ["[FAC DbgBrowser 62d308] H6 despawnScenarioWorldUnits cache objects=%1 groups=%2 sides=%3",
            count _protectedObjects, count _missionGroups, _sides];
        // #endregion

        private _toDelete = [];
        {
            if ([_x, _protectedObjects, _missionGroups] call FADE_scenario_entityProtectedFromDespawnCached) then { continue };
            if (side _x in _sides) then { _toDelete pushBackUnique _x };
        } forEach allUnits;

        {
            if (isNull _x) then { continue };
            if ([_x, _protectedObjects, _missionGroups] call FADE_scenario_entityProtectedFromDespawnCached) then { continue };
            private _crew = crew _x;
            if (({_x in _toDelete} count _crew) > 0 || { side _x in _sides }) then {
                {
                    if (!([_x, _protectedObjects, _missionGroups] call FADE_scenario_entityProtectedFromDespawnCached)) then {
                        _toDelete pushBackUnique _x;
                    };
                } forEach _crew;
                if !([_x, _protectedObjects, _missionGroups] call FADE_scenario_entityProtectedFromDespawnCached) then {
                    _toDelete pushBackUnique _x;
                };
            };
        } forEach vehicles;

        { if (!isNull _x) then { deleteVehicle _x } } forEach _toDelete;

        {
            if (isNull _x) then { continue };
            if ([_x, _missionGroups] call FADE_scenario_groupIsMissionRegistered) then { continue };
            if (count units _x == 0) then { deleteGroup _x; continue };
            if (side _x in _sides) then {
                {
                    if (!([_x, _protectedObjects, _missionGroups] call FADE_scenario_entityProtectedFromDespawnCached)) then {
                        deleteVehicle _x;
                    };
                } forEach units _x;
                if (count units _x == 0) then { deleteGroup _x };
            };
        } forEach allGroups;
    };
};

missionNamespace setVariable ["FADE_playableFactionSideNums", FADE_playableFactionSideNums];
missionNamespace setVariable ["FADE_getOpposedSideNums", FADE_getOpposedSideNums];
missionNamespace setVariable ["FADE_factionDisplayNameSafe", FADE_factionDisplayNameSafe];
missionNamespace setVariable ["FADE_collectFactionsForSideNums", FADE_collectFactionsForSideNums];
missionNamespace setVariable ["FADE_getPlayableFactions", FADE_getPlayableFactions];
missionNamespace setVariable ["FADE_getEnemyFactionsForFriendlyFaction", FADE_getEnemyFactionsForFriendlyFaction];
missionNamespace setVariable ["FADE_pickDefaultEnemyFactionForFriendly", FADE_pickDefaultEnemyFactionForFriendly];
missionNamespace setVariable ["FADE_scenarioFactionsDescribeIssue", FADE_scenarioFactionsDescribeIssue];
missionNamespace setVariable ["FADE_normalizeScenarioFactions", FADE_normalizeScenarioFactions];
missionNamespace setVariable ["FADE_scenarioFactionsIssueHint", FADE_scenarioFactionsIssueHint];
missionNamespace setVariable ["FADE_isScenarioFriendlyUnit", FADE_isScenarioFriendlyUnit];
missionNamespace setVariable ["FADE_isScenarioEnemyUnit", FADE_isScenarioEnemyUnit];
if (isServer) then {
    missionNamespace setVariable ["FADE_syncPlayerToScenarioFriendlySide", FADE_syncPlayerToScenarioFriendlySide];
    missionNamespace setVariable ["FADE_syncPlayersToScenarioFriendlySide", FADE_syncPlayersToScenarioFriendlySide];
    missionNamespace setVariable ["FADE_requestScenarioFriendlySideSync", FADE_requestScenarioFriendlySideSync];
    missionNamespace setVariable ["FADE_applyScenarioFactionSideSync", FADE_applyScenarioFactionSideSync];
    missionNamespace setVariable ["FADE_despawnScenarioWorldUnits", FADE_despawnScenarioWorldUnits];
};
