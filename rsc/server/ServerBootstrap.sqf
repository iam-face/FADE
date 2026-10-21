call compile preprocessFileLineNumbers "rsc\OperationNames.sqf";
call compile preprocessFileLineNumbers "rsc\MissionLore.sqf";
missionNamespace setVariable ["FADE_convoyMinRouteM", FADE_convoyMinRouteM];
FADE_interceptConvoyRoadRoute = compile preprocessFileLineNumbers "rsc\fn_FADE_interceptConvoyRoadRoute.sqf";
FADE_interceptConvoyRouteWaypoints = compile preprocessFileLineNumbers "rsc\fn_FADE_interceptConvoyRouteWaypoints.sqf";
missionNamespace setVariable ["FADE_counterAttackFirstDelayMin", FADE_counterAttackFirstDelayMin];
missionNamespace setVariable ["FADE_counterAttackFirstDelayMax", FADE_counterAttackFirstDelayMax];
missionNamespace setVariable ["FADE_counterAttackMinDistFromBase", FADE_counterAttackMinDistFromBase];
missionNamespace setVariable ["FADE_counterAttackCargoStaggerSec", FADE_counterAttackCargoStaggerSec];
missionNamespace setVariable ["FADE_counterAttackFootSquadsMin", FADE_counterAttackFootSquadsMin];
missionNamespace setVariable ["FADE_counterAttackFootSquadsMax", FADE_counterAttackFootSquadsMax];
missionNamespace setVariable ["FADE_counterAttackFootSpawnDistMin", FADE_counterAttackFootSpawnDistMin];
missionNamespace setVariable ["FADE_counterAttackFootSpawnDistMax", FADE_counterAttackFootSpawnDistMax];
missionNamespace setVariable ["FADE_counterAttackFootSquadSizeMin", FADE_counterAttackFootSquadSizeMin];
missionNamespace setVariable ["FADE_counterAttackFootSquadSizeMax", FADE_counterAttackFootSquadSizeMax];

// Preferred startup factions by display name (if present). Falls back to the vanilla class.
// Exact match walks the preferred list in order, then a case-insensitive substring pass.
FADE_pickFactionByDisplayName = {
    params ["_sideNum", "_preferredDisplayNames", "_fallbackFaction"];
    private _picked = _fallbackFaction;
    private _allFc = "true" configClasses (configFile >> "CfgFactionClasses");
    {
        private _prefExact = _x;
        if (_prefExact == "") then { continue };
        {
            private _cfg = _x;
            if (getNumber (_cfg >> "side") != _sideNum) then { continue };
            if (getText (_cfg >> "displayName") == _prefExact) exitWith { _picked = configName _cfg };
        } forEach _allFc;
        if (_picked != _fallbackFaction) exitWith {};
    } forEach _preferredDisplayNames;
    if (_picked == _fallbackFaction) then {
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

// Class names first (ConfigDefaults lists). Display names cover a rename that keeps the label.
FADE_pickStartupFaction = {
    params ["_sideNum", "_classNames", "_displayNames", "_fallbackFaction"];
    private _picked = "";
    {
        private _name = _x;
        if (_name == "") then { continue };
        private _cfg = configFile >> "CfgFactionClasses" >> _name;
        if (isClass _cfg && { getNumber (_cfg >> "side") == _sideNum }) exitWith { _picked = _name };
    } forEach _classNames;
    if (_picked != "") exitWith { _picked };
    [_sideNum, _displayNames, _fallbackFaction] call FADE_pickFactionByDisplayName
};

// RHS 0.5.6 labels. US Army infantry lives on the desert and woodland classes, not the empty parent.
private _namesBlufor = ["USA (Army - D)", "USA (Army - W)", "USA (Army)"];
private _namesRedfor = ["Russia (MSV)", "Russian Armed Forces"];
private _namesIndep = ["CDF (Ground Forces)", "SAF (KOV)"];
FADE_scenarioBluforFaction = [1, FADE_startupFactionBluforClasses, _namesBlufor, "BLU_F"] call FADE_pickStartupFaction;
FADE_scenarioRedforFaction = [0, FADE_startupFactionRedforClasses, _namesRedfor, "OPF_F"] call FADE_pickStartupFaction;
FADE_scenarioIndepFaction = [2, FADE_startupFactionIndepClasses, _namesIndep, "IND_F"] call FADE_pickStartupFaction;
FADE_scenarioFriendlyFaction = FADE_scenarioBluforFaction;
FADE_scenarioEnemyFaction = FADE_scenarioRedforFaction;
FADE_scenarioCivFaction = "CIV_F";
if (FADE_startupFactionFriendly != "" && { isClass (configFile >> "CfgFactionClasses" >> FADE_startupFactionFriendly) } && { getNumber (configFile >> "CfgFactionClasses" >> FADE_startupFactionFriendly >> "side") == 1 }) then {
    FADE_scenarioFriendlyFaction = FADE_startupFactionFriendly;
};
if (FADE_startupFactionEnemy != "" && { isClass (configFile >> "CfgFactionClasses" >> FADE_startupFactionEnemy) } && { getNumber (configFile >> "CfgFactionClasses" >> FADE_startupFactionEnemy >> "side") == 0 }) then {
    FADE_scenarioEnemyFaction = FADE_startupFactionEnemy;
};
if (FADE_startupFactionCiv != "" && { isClass (configFile >> "CfgFactionClasses" >> FADE_startupFactionCiv) } && { getNumber (configFile >> "CfgFactionClasses" >> FADE_startupFactionCiv >> "side") == 3 }) then {
    FADE_scenarioCivFaction = FADE_startupFactionCiv;
};
missionNamespace setVariable ["FADE_scenarioBluforFaction", FADE_scenarioBluforFaction, true];
missionNamespace setVariable ["FADE_scenarioRedforFaction", FADE_scenarioRedforFaction, true];
missionNamespace setVariable ["FADE_scenarioIndepFaction", FADE_scenarioIndepFaction, true];
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
FADE_playerCanUseRecruitGui = FAC_playerCanUseRecruitGui;
FADE_playerCanUseScenarioAdmin = FAC_playerCanUseScenarioAdmin;
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

FADE_serverBootstrapModuleList = [
    "rsc\server\ServerBootstrapFactions.sqf",
    "rsc\server\ServerBootstrapOpforAir.sqf",
    "rsc\server\ServerBootstrapScenario.sqf"
];
missionNamespace setVariable ["FADE_serverBootstrapModuleList", FADE_serverBootstrapModuleList];

{
    call compile preprocessFileLineNumbers _x;
} forEach FADE_serverBootstrapModuleList;
