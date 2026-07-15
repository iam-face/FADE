// =============================================================================
// ServerGameplayRecruit.sqf — HQ recruit board: spawn/dismiss friendly AI (server)
// =============================================================================

if (!isServer) exitWith {};

FADE_recruit_maxGroupSize = 12;

FADE_recruit_pickBSpPos = {
    params [["_ref", objNull]];
    private _pool = +(missionNamespace getVariable ["FADE_bSpPoints", []]);
    if (_pool isEqualTo []) exitWith { if (isNull _ref) then { [0, 0, 0] } else { getPosATL _ref } };
    private _refPos = if (isNull _ref) then { getPosATL player } else { getPosATL _ref };
    private _best = _pool select 0;
    private _bestD = 1e9;
    {
        private _d = _refPos distance _x;
        if (_d < _bestD) then {
            _bestD = _d;
            _best = _x;
        };
    } forEach _pool;
    getPosATL _best
};

FADE_recruit_defaultSpawnClass = {
    private _allowed = missionNamespace getVariable ["FADE_friendlyUnits", []];
    if (_allowed isEqualTo []) then {
        _allowed = +(missionNamespace getVariable ["FADE_fallbackFriendlyUnits", ["B_Soldier_F"]]);
    };
    _allowed select 0
};

FADE_recruit_resolveRow = {
    params ["_rowKey"];
    private _limitBlu = missionNamespace getVariable ["FADE_limitGearToFriendlyFaction", false];
    private _limitPreset = missionNamespace getVariable ["FADE_limitToPresetLoadouts", false];
    private _sideFriendly = missionNamespace getVariable ["FADE_sideFriendly", west];

    if (_limitPreset && { (_rowKey find "FAC:") != 0 }) exitWith { [] };

    private _loadout = [];
    private _spawnClass = "";
    private _medic = 0;
    private _eng = false;
    private _exp = false;
    private _label = _rowKey;

    if ((_rowKey find "FAC:") == 0) then {
        if (!([] call FAC_loadoutGui_ensurePresetData)) exitWith { [] };
        private _raw = [_rowKey] call FAC_loadoutGui_getPresetLoadoutByKey;
        _loadout = [_raw] call FAC_loadoutGui_resolvePresetLoadoutArray;
        if ((count _loadout) < 10) exitWith { [] };
        _spawnClass = [] call FADE_recruit_defaultSpawnClass;
        private _roleDn = "";
        { if ((_x select 0) == _rowKey) exitWith { _roleDn = _x select 1; _label = _roleDn } } forEach ([] call FAC_loadoutGui_buildPresetEntries);
        private _tr = [_roleDn] call FAC_loadoutGui_getPresetRoleTraits;
        _medic = _tr select 0;
        _eng = _tr select 1;
        _exp = _tr select 2;
    } else {
        if (_limitPreset) exitWith { [] };
        if (_limitBlu) then {
            private _allowed = missionNamespace getVariable ["FADE_friendlyUnits", []];
            if (!(_rowKey in _allowed)) exitWith { [] };
        };
        if (!isClass (configFile >> "CfgVehicles" >> _rowKey) || {!(_rowKey isKindOf "Man")}) exitWith { [] };
        private _sideNum = getNumber (configFile >> "CfgVehicles" >> _rowKey >> "side");
        private _wantSide = [_sideFriendly] call BIS_fnc_sideID;
        if (_sideNum != _wantSide) exitWith { [] };
        _spawnClass = _rowKey;
        _loadout = [_rowKey, _sideFriendly] call FAC_loadoutGui_getLoadoutFromClass;
        if ((count _loadout) == 0) exitWith { [] };
        _label = getText (configFile >> "CfgVehicles" >> _rowKey >> "displayName");
        if (_label == "") then { _label = _rowKey };
        private _cfgTr = [_rowKey] call FAC_loadoutGui_getCfgRoleTraits;
        _medic = _cfgTr select 0;
        _eng = _cfgTr select 1;
        _exp = _cfgTr select 2;
    };

    [_spawnClass, _loadout, _medic, _eng, _exp, _label]
};

FADE_recruit_canAssignToPlayer = {
    params ["_requester", "_target"];
    if (isNull _requester || { isNull _target } || {!isPlayer _target} || {!alive _target}) exitWith { false };
    private _sideF = missionNamespace getVariable ["FADE_sideFriendly", west];
    if (side _target != _sideF) exitWith { false };
    private _mode = missionNamespace getVariable ["FAC_param_recruitGuiAccess", 0];
    if (_target == _requester) exitWith { true };
    if (_mode <= 0) exitWith { true };
    if ([_requester] call FAC_playerHasLeaderOverrideAccess) exitWith { true };
    if (_mode >= 1) then {
        leader group _target == _requester
    } else {
        false
    };
};

FADE_recruit_canDismissUnit = {
    params ["_requester", "_unit"];
    if (isNull _requester || { isNull _unit } || {!alive _unit}) exitWith { false };
    if !(_unit getVariable ["FADE_recruitOwned", false]) exitWith { false };
    if !([_requester] call FAC_playerCanUseRecruitGui) exitWith { false };
    private _mode = missionNamespace getVariable ["FAC_param_recruitGuiAccess", 0];
    if (_mode <= 0) exitWith { true };
    if ([_requester] call FAC_playerHasLeaderOverrideAccess) exitWith { true };
    leader group _unit == _requester
};

FADE_recruit_buildFactionList = {
    private _sideF = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _sideNum = _sideF call BIS_fnc_sideID;
    private _scenarioFac = missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"];
    private _factions = [];
    private _suffix = "_" + str _sideNum;
    private _map = missionNamespace getVariable ["FADE_unitsByFactionSide", createHashMap];
    if (_map isEqualType createHashMap) then {
        {
            if (_x select [(count _x) - (count _suffix), (count _suffix)] == _suffix) then {
                private _fac = _x select [0, (count _x) - (count _suffix)];
                if (_fac != "" && { !(_fac in _factions) }) then {
                    private _cnt = count (_map getOrDefault [_x, []]);
                    if (_cnt > 0) then { _factions pushBack _fac };
                };
            };
        } forEach (keys _map);
    };
    if !(_scenarioFac in _factions) then { _factions pushBack _scenarioFac };
    private _rows = _factions apply {
        private _dn = getText (configFile >> "CfgFactionClasses" >> _x >> "displayName");
        if (_dn == "") then { _dn = _x };
        [_dn, _x]
    };
    _rows sort true;
    _rows
};

FADE_recruit_buildFactionUnitRows = {
    params ["_faction"];
    if (_faction == "") exitWith { [] };
    private _sideF = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _sideNum = _sideF call BIS_fnc_sideID;
    private _facSide = [_faction, _sideNum] call FADE_getFactionSideNum;
    if (_facSide != _sideNum) exitWith { [] };

    private _units = [_faction, _sideNum] call FADE_getUnitsForFaction;
    _units = [_units] call FADE_filterUnitsArmed;
    _units = [_units, _faction, _sideNum, false] call FADE_filterUnitsForScenarioFaction;
    if (missionNamespace getVariable ["FADE_limitGearToFriendlyFaction", false]) then {
        private _allowed = missionNamespace getVariable ["FADE_friendlyUnits", []];
        if (count _allowed > 0) then {
            _units = _units select { _x in _allowed };
        };
    };

    private _typeMap = [
        ["Men", "Infantry"], ["MenRecon", "Recon"], ["MenSniper", "Sniper"], ["MenSupport", "Support"],
        ["MenMedic", "Medic"], ["MenEngineer", "Engineer"], ["MenExplosive", "Explosive"]
    ];
    private _out = [];
    {
        private _class = _x;
        private _cfg = configFile >> "CfgVehicles" >> _class;
        private _displayName = getText (_cfg >> "displayName");
        if (_displayName == "") then { _displayName = _class };
        private _vc = getText (_cfg >> "vehicleClass");
        private _typeDn = "Infantry";
        { if ((_x select 0) == _vc) exitWith { _typeDn = _x select 1 } } forEach _typeMap;
        _out pushBack [_class, _displayName, _typeDn];
    } forEach _units;
    _out
};

FADE_recruit_requestFactionList = {
    if (!isServer) exitWith {};
    params [["_player", objNull]];
    if (isNull _player) exitWith {};
    if ([_player, "FAC_playerCanUseRecruitGui", "Recruit GUI access denied by lobby settings."] call FAC_lobbyParams_serverDenyUnless) exitWith {};
    private _rows = [] call FADE_recruit_buildFactionList;
    private _defaultFac = missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"];
    [_rows, _defaultFac] remoteExec ["FAC_recruitGui_onFactionList", _player];
};
publicVariable "FADE_recruit_requestFactionList";

FADE_recruit_requestFactionUnits = {
    if (!isServer) exitWith {};
    params [["_player", objNull], ["_faction", "", [""]]];
    if (isNull _player || { _faction == "" }) exitWith {};
    if ([_player, "FAC_playerCanUseRecruitGui", "Recruit GUI access denied by lobby settings."] call FAC_lobbyParams_serverDenyUnless) exitWith {};
    private _rows = [_faction] call FADE_recruit_buildFactionUnitRows;
    [_faction, _rows] remoteExec ["FAC_recruitGui_onFactionUnits", _player];
};
publicVariable "FADE_recruit_requestFactionUnits";

FADE_recruit_requestRoster = {
    if (!isServer) exitWith {};
    params [["_player", objNull]];
    if (isNull _player) exitWith {};
    if ([_player, "FAC_playerCanUseRecruitGui", "Recruit GUI access denied by lobby settings."] call FAC_lobbyParams_serverDenyUnless) exitWith {};

    private _rows = [];
    {
        if (alive _x && { _x getVariable ["FADE_recruitOwned", false] }) then {
            if ([_player, _x] call FADE_recruit_canDismissUnit) then {
                private _role = _x getVariable ["FADE_recruitRoleLabel", typeOf _x];
                private _grpLeader = leader group _x;
                private _ownerName = if (isPlayer _grpLeader) then { name _grpLeader } else { "AI group" };
                private _label = format ["%1 - %2 (%3)", _role, _ownerName, name _x];
                _rows pushBack [netId _x, _label];
            };
        };
    } forEach allUnits;

    _rows sort true;
    [_rows] remoteExec ["FAC_recruitGui_onRoster", _player];
};
publicVariable "FADE_recruit_requestRoster";

FADE_recruit_spawnUnit = {
    if (!isServer) exitWith {};
    params [["_requester", objNull], ["_targetNetId", "", [""]], ["_rowKey", "", [""]]];
    if (isNull _requester || { _rowKey == "" }) exitWith {};
    if ([_requester, "FAC_playerCanUseRecruitGui", "Recruit GUI access denied by lobby settings."] call FAC_lobbyParams_serverDenyUnless) exitWith {};

    private _target = _requester;
    if (_targetNetId != "" && { _targetNetId != netId _requester }) then {
        _target = objectFromNetId _targetNetId;
    };
    if (isNull _target || {!isPlayer _target} || {!alive _target}) exitWith {
        ["Recruit: target player is not available."] remoteExec ["systemChat", _requester];
    };
    if !([_requester, _target] call FADE_recruit_canAssignToPlayer) exitWith {
        ["Recruit: you cannot assign units to that player."] remoteExec ["systemChat", _requester];
    };

    private _grp = group _target;
    if (count units _grp >= FADE_recruit_maxGroupSize) exitWith {
        [format ["Recruit: %1's group is full (%2 units max).", name _target, FADE_recruit_maxGroupSize]] remoteExec ["systemChat", _requester];
    };

    private _resolved = [_rowKey] call FADE_recruit_resolveRow;
    if (_resolved isEqualTo []) exitWith {
        ["Recruit: that unit is not allowed or could not be resolved."] remoteExec ["systemChat", _requester];
    };
    _resolved params ["_spawnClass", "_loadout", "_medic", "_eng", "_exp", "_label"];

    if (!([_spawnClass] call FADE_isInfantryManClass)) exitWith {
        ["Recruit: spawn class is not infantry."] remoteExec ["systemChat", _requester];
    };

    private _spawnPos = [_requester] call FADE_recruit_pickBSpPos;
    private _unit = _grp createUnit [_spawnClass, _spawnPos, [], 0, "NONE"];
    if (isNull _unit) exitWith {
        ["Recruit: spawn failed."] remoteExec ["systemChat", _requester];
    };

    if !([_unit, _loadout, _medic, _eng, _exp] call FAC_loadoutGui_applyLoadoutToUnitServer) then {
        deleteVehicle _unit;
        ["Recruit: failed to apply loadout to spawned unit."] remoteExec ["systemChat", _requester];
    } else {
        _unit setName format ["Recruit %1", (round random 899) + 100];
        _unit setVariable ["FADE_recruitOwned", true, true];
        _unit setVariable ["FADE_recruitSpawnedByUid", getPlayerUID _requester, true];
        _unit setVariable ["FADE_recruitRoleLabel", _label, true];

        if (!isNil "FADE_assignGroupCallsign") then { [group _unit] call FADE_assignGroupCallsign };
        if (!isNil "FADE_attachNightStrobes") then { [group _unit] call FADE_attachNightStrobes };

        [format ["Recruited %1 for %2.", _label, name _target]] remoteExec ["systemChat", _requester];
        if (_target != _requester) then {
            [format ["%1 recruited %2 for your group.", name _requester, _label]] remoteExec ["systemChat", _target];
        };
        [_requester] call FADE_recruit_requestRoster;
    };
};
publicVariable "FADE_recruit_spawnUnit";

FADE_recruit_dismissUnits = {
    if (!isServer) exitWith {};
    params [["_requester", objNull], ["_netIds", [], [[]]]];
    if (isNull _requester || { _netIds isEqualTo [] }) exitWith {};
    if ([_requester, "FAC_playerCanUseRecruitGui", "Recruit GUI access denied by lobby settings."] call FAC_lobbyParams_serverDenyUnless) exitWith {};

    private _removed = 0;
    {
        if (_x isEqualType "") then {
            private _unit = objectFromNetId _x;
            if (!isNull _unit && { [_requester, _unit] call FADE_recruit_canDismissUnit }) then {
                deleteVehicle _unit;
                _removed = _removed + 1;
            };
        };
    } forEach _netIds;

    if (_removed > 0) then {
        [format ["Dismissed %1 recruited unit(s).", _removed]] remoteExec ["systemChat", _requester];
    } else {
        ["Recruit: no units dismissed (invalid selection or permission denied)."] remoteExec ["systemChat", _requester];
    };
    [_requester] call FADE_recruit_requestRoster;
};
publicVariable "FADE_recruit_dismissUnits";
