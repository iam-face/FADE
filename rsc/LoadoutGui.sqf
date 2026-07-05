// =============================================================================
// LoadoutGui.sqf - Loadout selection dialog
// =============================================================================
// Preset loadout helpers: rsc\LoadoutPresetCommon.sqf (compiled via FAC_ensureLoadoutGui).
// =============================================================================

// Join strings without joinString (engine compatibility).
FAC_loadoutGui_linesJoin = {
    params [["_parts", []], ["_sep", ""]];
    if (count _parts == 0) exitWith { "" };
    private _s = _parts select 0;
    for "_i" from 1 to ((count _parts) - 1) do {
        _s = _s + _sep + (_parts select _i);
    };
    _s
};

// Build preset tooltip text (LoadoutGui-only).
FAC_loadoutGui_buildLoadoutTextFromArray = {
    params ["_loadout"];
    if (!(_loadout isEqualType [])) exitWith { "Preset loadout (invalid format)." };
    if ((count _loadout) < 10) exitWith { "Preset loadout (invalid length)." };
    private _primarySlot = [_loadout select 0] call FAC_loadoutGui_flattenPresetWeaponSlot;
    private _launcherSlot = [_loadout select 1] call FAC_loadoutGui_flattenPresetWeaponSlot;
    private _handgunSlot = [_loadout select 2] call FAC_loadoutGui_flattenPresetWeaponSlot;
    private _primary = ((_primarySlot param [0, ""]) call FAC_loadoutGui_getItemDisplayName);
    private _launcher = ((_launcherSlot param [0, ""]) call FAC_loadoutGui_getItemDisplayName);
    private _handgun = ((_handgunSlot param [0, ""]) call FAC_loadoutGui_getItemDisplayName);
    private _uniform = ((_loadout select 3) param [0, ""]);
    private _vest = (_loadout select 4);
    private _backpack = (_loadout select 5);
    private _headgear = (_loadout select 6);
    private _goggles = (_loadout select 7);
    private _lines = [];
    if (_primary != "") then { _lines pushBack ("Primary: " + _primary) };
    if (_launcher != "") then { _lines pushBack ("Launcher: " + _launcher) };
    if (_handgun != "") then { _lines pushBack ("Handgun: " + _handgun) };
    if (_uniform != "") then { _lines pushBack ("Uniform: " + ([_uniform] call FAC_loadoutGui_getItemDisplayName)) };
    if (_vest isEqualType [] && {count _vest > 0}) then { _lines pushBack ("Vest: " + ([_vest select 0] call FAC_loadoutGui_getItemDisplayName)) };
    if (_backpack isEqualType [] && {count _backpack > 0}) then { _lines pushBack ("Backpack: " + ([_backpack select 0] call FAC_loadoutGui_getItemDisplayName)) };
    if (_headgear != "") then { _lines pushBack ("Headgear: " + ([_headgear] call FAC_loadoutGui_getItemDisplayName)) };
    if (_goggles != "") then { _lines pushBack ("Eyewear: " + ([_goggles] call FAC_loadoutGui_getItemDisplayName)) };
    if (count _lines == 0) exitWith { "Preset loadout (array)." };
    [_lines, toString [10]] call FAC_loadoutGui_linesJoin
};

// Map vehicleClass to readable type (for display prefix)
FAC_loadoutGui_vehicleClassToType = [
    ["Men", "Infantry"],
    ["MenRecon", "Recon"],
    ["MenSniper", "Sniper"],
    ["MenSupport", "Support"],
    ["MenMedic", "Medic"],
    ["MenEngineer", "Engineer"],
    ["MenExplosive", "Explosive"],
    ["MenDiver", "Diver"],
    ["MenDemo", "Demo"],
    ["MenGuerilla", "Guerilla"],
    ["MenViper", "Viper"],
    ["MenStory", "Story"]
];

// Player's config faction (unit faction, then scenario friendly fallback).
FAC_loadoutGui_getPlayerFaction = {
    private _f = faction player;
    if (_f != "") exitWith { _f };
    missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"]
};

// Build one unit row from classname.
FAC_loadoutGui_classToUnitRow = {
    params ["_class"];
    private _cfg = configFile >> "CfgVehicles" >> _class;
    if (!isClass _cfg) exitWith { [] };
    private _displayName = getText (_cfg >> "displayName");
    if (_displayName == "") then { _displayName = _class };
    private _faction = getText (_cfg >> "faction");
    private _factionDn = if (_faction != "") then { [_faction] call FAC_loadoutGui_getFactionDisplayName } else { "Unknown" };
    private _vc = getText (_cfg >> "vehicleClass");
    private _typeDn = "Infantry";
    { if ((_x select 0) == _vc) exitWith { _typeDn = _x select 1 } } forEach FAC_loadoutGui_vehicleClassToType;
    if (_vc != "" && { _typeDn == "Infantry" } && { _vc != "Men" }) then { _typeDn = _vc };
    [_class, _displayName, _faction, _factionDn, _typeDn]
};

// Build list of infantry unit classes for player's side (full scan — use only for "All factions").
// Returns: [[classname, displayName, faction, factionDisplayName, typeDisplayName], ...]
FAC_loadoutGui_getUnitsForSide = {
    params ["_side", ["_factionFilter", ""]];
    private _sideNum = _side call BIS_fnc_sideID;
    private _result = [];
    {
        private _cfg = _x;
        private _class = configName _cfg;
        private _isMan = false;
        private _check = _cfg;
        while {configName _check != ""} do {
            if (configName _check == "Man") exitWith { _isMan = true };
            _check = inheritsFrom _check;
        };
        if (_isMan && { getNumber (_cfg >> "side") == _sideNum }) then {
            private _scope = getNumber (_cfg >> "scope");
            if (_scope >= 1) then {  // Exclude scope 0 (private)
                private _faction = getText (_cfg >> "faction");
                if (_factionFilter == "" || { _faction == _factionFilter }) then {
                    private _row = [_class] call FAC_loadoutGui_classToUnitRow;
                    if (count _row > 0) then { _result pushBack _row };
                };
            };
        };
    } forEach ("true" configClasses (configFile >> "CfgVehicles"));
    _result
};

// Get display name for faction (same as Vehicle GUI: CfgFactionClasses displayName)
FAC_loadoutGui_getFactionDisplayName = {
    params ["_faction"];
    if (_faction == "") exitWith { "Unknown" };
    private _dn = getText (configFile >> "CfgFactionClasses" >> _faction >> "displayName");
    if (_dn != "") exitWith { _dn };
    _faction
};

// Config-based unit rows; optional faction scope ("" = all factions on player side — slow).
FAC_loadoutGui_buildStdUnits = {
    params [["_factionScope", ""]];
    private _allUnits = [];
    if (_factionScope == "") then {
        _allUnits = [side player] call FAC_loadoutGui_getUnitsForSide;
    } else {
        if (!isNil "FADE_getUnitsForFaction") then {
            private _sideNum = side player call BIS_fnc_sideID;
            private _classes = [_factionScope, _sideNum] call FADE_getUnitsForFaction;
            {
                private _row = [_x] call FAC_loadoutGui_classToUnitRow;
                if (count _row > 0) then { _allUnits pushBack _row };
            } forEach _classes;
        } else {
            _allUnits = [side player, _factionScope] call FAC_loadoutGui_getUnitsForSide;
        };
    };
    if (missionNamespace getVariable ["FADE_limitGearToFriendlyFaction", false]) then {
        private _allowed = missionNamespace getVariable ["FADE_friendlyUnits", []];
        if (count _allowed > 0) then {
            _allUnits = _allUnits select { (_x select 0) in _allowed };
        };
    };
    _allUnits
};

FAC_loadoutGui_selectStdFaction = {
    params ["_display", "_faction"];
    private _factionList = _display displayCtrl 60210;
    private _idx = -1;
    for "_i" from 0 to (lbSize _factionList - 1) do {
        if ((_factionList lbData _i) == _faction) exitWith { _idx = _i };
    };
    if (_idx < 0) then { _idx = if (lbSize _factionList > 1) then { 1 } else { 0 } };
    _factionList lbSetCurSel _idx;
};

// Faction keys for std-mode filter (CfgFactionClasses on player side — no unit scan).
FAC_loadoutGui_collectStdFactionKeys = {
    private _sideNum = side player call BIS_fnc_sideID;
    private _keys = [];
    {
        if (getNumber (_x >> "side") == _sideNum) then {
            _keys pushBack (configName _x);
        };
    } forEach ("true" configClasses (configFile >> "CfgFactionClasses"));
    _keys
};

FAC_loadoutGui_populateStdFactionList = {
    params ["_display", ["_selectFaction", ""]];
    if (_selectFaction == "") then { _selectFaction = [] call FAC_loadoutGui_getPlayerFaction };
    private _factions = [] call FAC_loadoutGui_collectStdFactionKeys;
    private _factionRows = _factions apply { [[_x] call FAC_loadoutGui_getFactionDisplayName, _x] };
    _factionRows sort true;
    private _factionList = _display displayCtrl 60210;
    lbClear _factionList;
    private _idx = _factionList lbAdd "All factions";
    _factionList lbSetData [_idx, ""];
    { _x params ["_dn", "_key"]; _idx = _factionList lbAdd _dn; _factionList lbSetData [_idx, _key] } forEach _factionRows;
    [_display, _selectFaction] call FAC_loadoutGui_selectStdFaction;
};

FAC_loadoutGui_loadStdMode = {
    params ["_display", ["_factionScope", ""]];
    if (_factionScope == "") then { _factionScope = [] call FAC_loadoutGui_getPlayerFaction };
    missionNamespace setVariable ["FAC_loadoutGui_stdLoadedScope", _factionScope];
    missionNamespace setVariable ["FAC_loadoutGui_allUnits", [_factionScope] call FAC_loadoutGui_buildStdUnits];
    [_display, _factionScope] call FAC_loadoutGui_populateStdFactionList;
};

FAC_loadoutGui_populatePresetFactionList = {
    params ["_display"];
    private _factionList = _display displayCtrl 60210;
    lbClear _factionList;
    private _idx = _factionList lbAdd "All eras";
    _factionList lbSetData [_idx, ""];
    _factionList lbSetCurSel 0;
    private _preset = missionNamespace getVariable ["FAC_presetLoadouts", []];
    {
        _x params ["_eraKey", "_eraDn", "_roles"];
        if (_eraKey != "" && { count _roles > 0 }) then {
            _idx = _factionList lbAdd _eraDn;
            _factionList lbSetData [_idx, _eraKey];
        };
    } forEach _preset;
};

// Get display name for config class (CfgWeapons or CfgVehicles)
FAC_loadoutGui_getItemDisplayName = {
    params ["_class"];
    if (_class == "" || { _class == "None" }) exitWith { "" };
    private _dn = getText (configFile >> "CfgWeapons" >> _class >> "displayName");
    if (_dn != "") exitWith { _dn };
    _dn = getText (configFile >> "CfgVehicles" >> _class >> "displayName");
    if (_dn != "") exitWith { _dn };
    _class
};

// Build loadout text from unit class config
FAC_loadoutGui_buildLoadoutText = {
    params ["_class"];
    private _cfg = configFile >> "CfgVehicles" >> _class;
    if (!isClass _cfg) exitWith { "Unknown unit." };

    private _lines = [];
    private _add = { _lines pushBack _this };

    // Primary weapon
    private _weapons = getArray (_cfg >> "weapons");
    if (count _weapons > 0) then {
        private _prim = _weapons select 0;
        if (_prim != "" && { _prim != "Throw" } && { _prim != "Put" }) then {
            ("Primary: " + ([_prim] call FAC_loadoutGui_getItemDisplayName)) call _add;
        };
    };
    // Secondary (launcher)
    if (count _weapons > 1) then {
        private _sec = _weapons select 1;
        if (_sec != "" && { _sec != "Throw" } && { _sec != "Put" }) then {
            ("Secondary: " + ([_sec] call FAC_loadoutGui_getItemDisplayName)) call _add;
        };
    };
    // Handgun
    if (count _weapons > 2) then {
        private _hg = _weapons select 2;
        if (_hg != "" && { _hg != "Throw" } && { _hg != "Put" }) then {
            ("Handgun: " + ([_hg] call FAC_loadoutGui_getItemDisplayName)) call _add;
        };
    };

    // Uniform
    private _uniform = getText (_cfg >> "uniformClass");
    if (_uniform != "") then {
        ("Uniform: " + ([_uniform] call FAC_loadoutGui_getItemDisplayName)) call _add;
    };

    // Vest & headgear from linkedItems (order varies by mod)
    private _linked = getArray (_cfg >> "linkedItems");
    {
        if (_x != "") then {
            private _dn = [_x] call FAC_loadoutGui_getItemDisplayName;
            if (_dn != "") then {
                private _lower = toLower _x;
                if (_lower find "vest" >= 0 || { _lower find "carrier" >= 0 }) then {
                    ("Vest: " + _dn) call _add;
                };
                if (_lower find "helmet" >= 0 || { _lower find "hat" >= 0 } || { _lower find "cap" >= 0 } || { _lower find "headgear" >= 0 }) then {
                    ("Headgear: " + _dn) call _add;
                };
                if (_lower find "nvg" >= 0) then {
                    ("NVG: " + _dn) call _add;
                };
            };
        };
    } forEach _linked;

    // Backpack
    private _backpack = getText (_cfg >> "backpack");
    if (_backpack != "") then {
        ("Backpack: " + ([_backpack] call FAC_loadoutGui_getItemDisplayName)) call _add;
    };

    // Items
    private _items = getArray (_cfg >> "items");
    if (count _items > 0) then {
        private _itemStrs = [];
        { if (_x != "") then { _itemStrs pushBack ([_x] call FAC_loadoutGui_getItemDisplayName) } } forEach _items;
        if (count _itemStrs > 0) then {
            ("Items: " + ([_itemStrs, ", "] call FAC_loadoutGui_linesJoin)) call _add;
        };
    };

    if (count _lines == 0) exitWith { "No loadout data." };
    [_lines, toString [10]] call FAC_loadoutGui_linesJoin
};

// Get unit preview picture path from config
FAC_loadoutGui_getUnitPicture = {
    params ["_class"];
    private _cfg = configFile >> "CfgVehicles" >> _class;
    if (!isClass _cfg) exitWith { "\a3\ui_f\data\map\markers\nato\b_inf.paa" };
    private _pic = getText (_cfg >> "picture");
    if (_pic == "") then { _pic = getText (_cfg >> "icon") };
    private _fallback = "\a3\ui_f\data\map\markers\nato\b_inf.paa";
    if (_pic == "" || { (toLower _pic find ".paa") < 0 && { (toLower _pic find ".pac") < 0 } && { _pic find "\" < 0 } }) then {
        _pic = _fallback;
    };
    _pic
};

FAC_loadoutGui_tryAddRadio = {
    params ["_class", "_label"];
    if (!isClass (configFile >> "CfgWeapons" >> _class)) exitWith {
        systemChat format ["%1 is not available (class missing): %2", _label, _class];
    };
    if (player canAdd _class) then {
        player addItem _class;
        systemChat format ["Added %1.", _label];
    } else {
        systemChat format ["Cannot add %1: no inventory space.", _label];
    };
};

// True if class exists as weapon or magazine (ACE items / KAT kits live in CfgWeapons).
FAC_loadoutGui_itemClassExists = {
    params ["_class"];
    isClass (configFile >> "CfgWeapons" >> _class) || { isClass (configFile >> "CfgMagazines" >> _class) }
};

// Add N copies of an item to the player (inventory GUI). _label is user-facing name.
FAC_loadoutGui_tryAddItemCount = {
    params ["_class", "_label", ["_count", 1]];
    if (!([_class] call FAC_loadoutGui_itemClassExists)) exitWith {
        systemChat format ["%1 is not available (class missing): %2", _label, _class];
    };
    private _added = 0;
    for "_i" from 1 to _count do {
        if (player canAdd _class) then {
            player addItem _class;
            _added = _added + 1;
        };
    };
    if (_added == _count) exitWith {
        systemChat format ["Added %1 (%2x).", _label, _count];
    };
    if (_added > 0) exitWith {
        systemChat format ["Added %1 x%2 of %3 (inventory full).", _label, _added, _count];
    };
    systemChat format ["Cannot add %1: no inventory space.", _label];
};

// Same IR strobe inventory item as FADE_attachNightStrobes / preset vests (ACE_IR_Strobe_Item).
FAC_loadoutGui_tryAddBandageBundle = {
    private _pairs = [
        ["ACE_elasticBandage", 2],
        ["ACE_packingBandage", 2],
        ["ACE_quikclot", 2]
    ];
    private _missing = [];
    { if (!([_x select 0] call FAC_loadoutGui_itemClassExists)) then { _missing pushBack (_x select 0) } } forEach _pairs;
    if (count _missing > 0) exitWith {
        systemChat format ["Bandage bundle: missing class(es): %1", ([_missing, ", "] call FAC_loadoutGui_linesJoin)];
    };
    private _total = 0;
    private _fail = 0;
    {
        _x params ["_cls", "_n"];
        for "_i" from 1 to _n do {
            if (player canAdd _cls) then {
                player addItem _cls;
                _total = _total + 1;
            } else {
                _fail = _fail + 1;
            };
        };
    } forEach _pairs;
    if (_fail == 0) exitWith {
        systemChat "Added bandages (elastic x2, packing x2, quikclot x2).";
    };
    if (_total > 0) exitWith {
        systemChat format ["Added %1 bandage item(s); %2 could not fit (full).", _total, _fail];
    };
    systemChat "Cannot add bandages: no inventory space.";
};

// Clear weapons/containers so setUnitLoadout can replace gear reliably (same idea as
// FAC_Tequila.Stratis\rsc\Loadout.sqf: strip mags/weapons before re-arm).
FAC_loadoutGui_stripUnitForLoadout = {
    params [["_u", player]];
    if (isNull _u || {!alive _u} || {!local _u}) exitWith {};
    { _u removeMagazine _x } forEach (magazines _u);
    removeAllWeapons _u;
    removeAllAssignedItems _u;
    removeUniform _u;
    removeVest _u;
    removeBackpack _u;
    removeHeadgear _u;
    removeGoggles _u;
};

// Server-authorized apply on the target's machine (remoteExec from server only).
FAC_loadoutGui_clientApplyAuthorizedLoadout = {
    params [["_loadout", []], ["_medic", 0], ["_engineer", false], ["_explosive", false], ["_fromName", "", [""]]];
    if (!hasInterface) exitWith {};
    private _u = player;
    if (isNull _u || {!alive _u} || {!local _u}) exitWith {};
    if (!(_loadout isEqualType []) || { (count _loadout) < 10 }) exitWith {};
    private _norm = [_loadout] call FAC_loadoutGui_resolvePresetLoadoutArray;
    if ((count _norm) < 10) exitWith {};
    [_u] call FAC_loadoutGui_stripUnitForLoadout;
    _u setUnitLoadout _norm;
    [_u, _medic, _engineer, _explosive] call FAC_loadoutGui_syncRoleTraitsLocal;
    if (_fromName != "") then {
        systemChat format ["%1 applied a loadout to you.", _fromName];
    } else {
        systemChat "Your squad leader applied a loadout to you.";
    };
};

// Apply getUnitLoadout-shaped array to local player (same as Tequila initPlayerLocal: setUnitLoadout).
FAC_loadoutGui_applyLoadoutArrayLocal = {
    params [["_loadout", []]];
    if (!hasInterface) exitWith { false };
    private _u = player;
    if (isNull _u || {!alive _u} || {!local _u}) exitWith { false };
    if (!(_loadout isEqualType []) || { _loadout isEqualTo [] }) exitWith { false };
    private _norm = [_loadout] call FAC_loadoutGui_resolvePresetLoadoutArray;
    if ((count _norm) < 10) exitWith { false };
    [_u] call FAC_loadoutGui_stripUnitForLoadout;
    _u setUnitLoadout _norm;
    true
};

// Vanilla traits  -  https://community.bohemia.net/wiki/setUnitTrait
// Medic: false/0 off; true -> 1; 1/2 = CfgVehicles attendant (trained / doctor). getUnitTrait may return bool or Number.
// Engineer / explosiveSpecialist: boolean (CfgVehicles engineer / canDeactivateMines).
FAC_loadoutGui_syncRoleTraitsLocal = {
    params ["_u", "_medic", "_engineer", "_explosive"];
    if (isNull _u || {!alive _u} || {!local _u}) exitWith {};
    if (_medic isEqualTo false || {_medic isEqualTo 0}) then {
        _u setUnitTrait ["Medic", false];
    } else {
        private _mv = _medic;
        if (_medic isEqualTo true) then { _mv = 1 };
        _u setUnitTrait ["Medic", _mv];
    };
    private _engOn = _engineer isEqualTo true || { (typeName _engineer == "SCALAR") && { _engineer > 0 } };
    _u setUnitTrait ["Engineer", _engOn];
    private _expOn = _explosive isEqualTo true || { (typeName _explosive == "SCALAR") && { _explosive > 0 } };
    _u setUnitTrait ["explosiveSpecialist", _expOn];
};

// Respawn snapshot: gear + Medic / Engineer / explosiveSpecialist (setUnitLoadout does not store traits).
FAC_loadoutGui_saveRespawnLoadoutSnapshot = {
    params [["_u", player]];
    if (isNull _u || {!local _u}) exitWith {};
    private _uid = getPlayerUID _u;
    missionNamespace setVariable ["FAC_savedLoadout_" + _uid, getUnitLoadout _u];
    missionNamespace setVariable [
        "FAC_savedLoadoutTraits_" + _uid,
        [_u getUnitTrait "Medic", _u getUnitTrait "Engineer", _u getUnitTrait "explosiveSpecialist"]
    ];
};

// Capture mission slot / JIP spawn gear once; skipped if player already saved (loadout box)  -  same keys as saveRespawnLoadoutSnapshot.
FAC_loadoutGui_trySaveInitialRespawnLoadoutIfMissing = {
    params [["_u", player]];
    if (!hasInterface) exitWith {};
    if (isNull _u || {!alive _u} || {!local _u}) exitWith {};
    private _uid = getPlayerUID _u;
    if (count (missionNamespace getVariable ["FAC_savedLoadout_" + _uid, []]) > 0) exitWith {};
    [_u] call FAC_loadoutGui_saveRespawnLoadoutSnapshot;
};

FAC_loadoutGui_restoreRespawnLoadoutSnapshot = {
    params [["_u", player]];
    if (isNull _u || {!local _u}) exitWith {};
    private _uid = getPlayerUID _u;
    private _saved = missionNamespace getVariable ["FAC_savedLoadout_" + _uid, []];
    private _traits = missionNamespace getVariable ["FAC_savedLoadoutTraits_" + _uid, nil];
    if (count _saved > 0) then { _u setUnitLoadout _saved };
    if (!isNil "_traits" && { count _traits >= 2 }) then {
        private _exp = if ((count _traits) > 2) then { _traits select 2 } else { false };
        [_u, _traits select 0, _traits select 1, _exp] call FAC_loadoutGui_syncRoleTraitsLocal;
    };
};

// Leader or Scenario-style admin/Zeus override (matches FADE_playerHasLeaderOverrideAccess on server).
FAC_loadoutGui_canApplyLoadoutToGroup = {
    if (isNull player) exitWith { false };
    if (leader group player == player) exitWith { true };
    if ((admin (owner player)) > 0) exitWith { true };
    if (!isNull (getAssignedCuratorLogic player)) exitWith { true };
    false
};

FAC_loadoutGui_updateApplyToSquadControls = {
    params ["_display"];
    if (isNull _display) exitWith {};
    private _can = [] call FAC_loadoutGui_canApplyLoadoutToGroup;
    private _panelOpen = missionNamespace getVariable ["FAC_loadoutGui_applyToPanelOpen", false];
    (_display displayCtrl 60219) ctrlShow _can;
    (_display displayCtrl 60222) ctrlShow (_can && _panelOpen);
    (_display displayCtrl 60224) ctrlShow (_can && _panelOpen);
    (_display displayCtrl 60220) ctrlShow (_can && _panelOpen);
    (_display displayCtrl 60221) ctrlShow (_can && _panelOpen);
    (_display displayCtrl 60223) ctrlShow (_can && _panelOpen);
};

FAC_loadoutGui_fillSquadMemberList = {
    params ["_display"];
    private _lb = _display displayCtrl 60220;
    lbClear _lb;
    private _g = group player;
    {
        if (isPlayer _x && { alive _x } && { _x != player }) then {
            private _idx = _lb lbAdd format ["%1 (%2)", name _x, if (_x == leader _g) then { "L" } else { "M" }];
            _lb lbSetData [_idx, netId _x];
        };
    } forEach (units _g);
    if (lbSize _lb > 0) then { _lb lbSetCurSel 0 };
};

// Highlight active loadout source (60213 = Presets, 60214 = Faction Units).
FAC_loadoutGui_updateSourceButtons = {
    params ["_display"];
    private _mode = missionNamespace getVariable ["FAC_loadoutGui_listMode", "preset"];
    private _active = FAC_theme_tabActive;
    private _idle = FAC_theme_tabIdle;
    private _bPreset = _display displayCtrl 60213;
    private _bStd = _display displayCtrl 60214;
    if (_mode == "preset") then {
        _bPreset ctrlSetBackgroundColor _active;
        _bStd ctrlSetBackgroundColor _idle;
    } else {
        _bPreset ctrlSetBackgroundColor _idle;
        _bStd ctrlSetBackgroundColor _active;
    };
};

// Rebuild lists from current scenario limits (onLoad + header Refresh).
FAC_loadoutGui_populateWorker = {
    params ["_display"];
    if (isNull _display) exitWith {};
    private _btnPreset = _display displayCtrl 60213;
    private _btnStd = _display displayCtrl 60214;
    _btnPreset ctrlShow true;
    _btnStd ctrlShow true;
    [_display] call FAC_loadoutGui_updateSourceButtons;
    _btnPreset ctrlCommit 0;
    _btnStd ctrlCommit 0;

    private _limitToBlu = missionNamespace getVariable ["FADE_limitGearToFriendlyFaction", false];
    private _limitToPreset = missionNamespace getVariable ["FADE_limitToPresetLoadouts", false];
    private _forceStd = _limitToBlu;
    private _forcePreset = (!_forceStd) && { _limitToPreset };

    if (_forceStd) then {
        _btnPreset ctrlShow false;
        _btnStd ctrlSetPosition [0.24, 0.036, 0.40, 0.046];
        _btnStd ctrlCommit 0;
        missionNamespace setVariable ["FAC_loadoutGui_listMode", "std"];
        [_display] call FAC_loadoutGui_loadStdMode;
    } else {
        if (_forcePreset) then {
            _btnStd ctrlShow false;
            _btnPreset ctrlSetPosition [0.24, 0.036, 0.40, 0.046];
            _btnPreset ctrlCommit 0;
        };
        missionNamespace setVariable ["FAC_loadoutGui_listMode", "preset"];
        if (!([] call FAC_loadoutGui_ensurePresetData)) then {
            systemChat "[Loadout] Presets failed to load  -  check RPT and rsc\\PresetLoadouts.sqf.";
            missionNamespace setVariable ["FAC_loadoutGui_allUnits", []];
        } else {
            missionNamespace setVariable ["FAC_loadoutGui_allUnits", [] call FAC_loadoutGui_buildPresetEntries];
        };
        [_display] call FAC_loadoutGui_populatePresetFactionList;
    };
    [_display] call FAC_loadoutGui_updateSourceButtons;

    ["filterChanged", []] call FAC_loadoutGui_fnc;
    ["updateSaveStatus", []] call FAC_loadoutGui_fnc;
    missionNamespace setVariable ["FAC_loadoutGui_applyToPanelOpen", false];
    [_display] call FAC_loadoutGui_updateApplyToSquadControls;
};

FAC_loadoutGui_fnc = {
    params ["_action", "_params"];
    private _display = findDisplay 60200;
    if (isNull _display && { _action != "open" }) exitWith {};

    switch _action do {
        case "open": {
            if !(["FAC_playerCanUseLoadoutGui"] call FAC_lobbyParams_callAccess) exitWith {
                systemChat "Loadout GUI access denied by lobby settings.";
            };
            if (!createDialog "RscDisplayLoadout") then {
                systemChat "LOADOUT GUI: RESOURCE NOT FOUND.";
            };
        };
        case "onLoad": {
            _display = findDisplay 60200;
            if (isNull _display) exitWith {};
            missionNamespace setVariable ["FAC_loadoutGui_fnc", FAC_loadoutGui_fnc];
            uinamespace setVariable ["FAC_loadoutGui_fnc", FAC_loadoutGui_fnc];

            private _unitLb = _display displayCtrl 60201;
            lbClear _unitLb;
            _unitLb lbAdd "Loading...";
            _unitLb lbSetCurSel 0;

            [] spawn {
                private _display = findDisplay 60200;
                if (isNull _display) exitWith {};
                [_display] call FAC_loadoutGui_populateWorker;
            };
        };
        case "headerRefresh": {
            _display = findDisplay 60200;
            if (isNull _display) exitWith {};
            private _unitLb = _display displayCtrl 60201;
            lbClear _unitLb;
            _unitLb lbAdd "Loading...";
            _unitLb lbSetCurSel 0;
            [] spawn {
                private _display = findDisplay 60200;
                if (isNull _display) exitWith {};
                [_display] call FAC_loadoutGui_populateWorker;
            };
        };
        case "applyToToggle": {
            _display = findDisplay 60200;
            if (isNull _display) exitWith {};
            if (!([] call FAC_loadoutGui_canApplyLoadoutToGroup)) exitWith {
                systemChat "Only group leaders (or admin/Zeus) can apply loadouts to squadmates.";
            };
            private _open = !(missionNamespace getVariable ["FAC_loadoutGui_applyToPanelOpen", false]);
            missionNamespace setVariable ["FAC_loadoutGui_applyToPanelOpen", _open];
            if (_open) then {
                [_display] call FAC_loadoutGui_fillSquadMemberList;
                if (lbSize (_display displayCtrl 60220) == 0) then {
                    systemChat "No other players in your group.";
                };
            };
            [_display] call FAC_loadoutGui_updateApplyToSquadControls;
        };
        case "applyToConfirm": {
            _display = findDisplay 60200;
            if (isNull _display) exitWith {};
            if (!([] call FAC_loadoutGui_canApplyLoadoutToGroup)) exitWith {};
            private _unitLb = _display displayCtrl 60201;
            private _idx = lbCurSel _unitLb;
            if (_idx < 0) exitWith { systemChat "Select a loadout first." };
            private _rowKey = _unitLb lbData _idx;
            if (_rowKey == "") exitWith { systemChat "Loadout GUI: no row data  -  re-open the dialog." };

            private _mbLb = _display displayCtrl 60220;
            private _mSel = lbCurSel _mbLb;
            if (_mSel < 0) exitWith { systemChat "Select a squad member." };
            private _nid = _mbLb lbData _mSel;
            if (_nid == "") exitWith { systemChat "Invalid squad selection." };

            [player, _nid, _rowKey] remoteExec ["FAC_loadoutGui_serverRequestApplyToMember", 2];
            missionNamespace setVariable ["FAC_loadoutGui_applyToPanelOpen", false];
            [_display] call FAC_loadoutGui_updateApplyToSquadControls;
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };
        case "applyToCancel": {
            _display = findDisplay 60200;
            if (isNull _display) exitWith {};
            missionNamespace setVariable ["FAC_loadoutGui_applyToPanelOpen", false];
            [_display] call FAC_loadoutGui_updateApplyToSquadControls;
        };
        case "sourcePick": {
            _params params [["_mode", "preset", [""]]];
            if (!(_mode in ["preset", "std"])) exitWith {};
            _display = findDisplay 60200;
            if (isNull _display) exitWith {};
            private _limitToBlu = missionNamespace getVariable ["FADE_limitGearToFriendlyFaction", false];
            private _limitToPreset = missionNamespace getVariable ["FADE_limitToPresetLoadouts", false];
            if (_limitToBlu && { _mode != "std" }) exitWith { systemChat "Loadouts are limited to chosen BLUFOR faction."; };
            if (!_limitToBlu && { _limitToPreset } && { _mode != "preset" }) exitWith { systemChat "Loadouts are limited to preset loadouts."; };
            missionNamespace setVariable ["FAC_loadoutGui_listMode", _mode];

            private _unitLb = _display displayCtrl 60201;
            lbClear _unitLb;
            _unitLb lbAdd "Loading...";
            _unitLb lbSetCurSel 0;

            if (_mode == "std") then {
                [_display] call FAC_loadoutGui_updateSourceButtons;
                [] spawn {
                    private _display = findDisplay 60200;
                    if (isNull _display) exitWith {};
                    [_display] call FAC_loadoutGui_loadStdMode;
                    ["filterChanged", []] call FAC_loadoutGui_fnc;
                };
            } else {
                if (!([] call FAC_loadoutGui_ensurePresetData)) then {
                    systemChat "[Loadout] Presets failed to load  -  check RPT and rsc\\PresetLoadouts.sqf.";
                    missionNamespace setVariable ["FAC_loadoutGui_allUnits", []];
                } else {
                    missionNamespace setVariable ["FAC_loadoutGui_allUnits", [] call FAC_loadoutGui_buildPresetEntries];
                };
                [_display] call FAC_loadoutGui_populatePresetFactionList;
                [_display] call FAC_loadoutGui_updateSourceButtons;
                ["filterChanged", []] call FAC_loadoutGui_fnc;
            };
        };
        case "filterChanged": {
            if (isNull _display) exitWith {};
            private _listMode = missionNamespace getVariable ["FAC_loadoutGui_listMode", "preset"];
            private _factionList = _display displayCtrl 60210;
            private _filterFaction = "";
            private _sel = lbCurSel _factionList;
            if (_sel >= 0) then { _filterFaction = _factionList lbData _sel };

            private _deferFilterPopulate = false;
            if (_listMode == "std") then {
                private _loadedScope = missionNamespace getVariable ["FAC_loadoutGui_stdLoadedScope", ""];
                private _needScope = if (_filterFaction == "") then { "__ALL__" } else { _filterFaction };
                if (_needScope != _loadedScope) then {
                    private _unitLb = _display displayCtrl 60201;
                    lbClear _unitLb;
                    _unitLb lbAdd (if (_filterFaction == "") then { "Loading all factions..." } else { "Loading..." });
                    _unitLb lbSetCurSel 0;
                    private _asyncFaction = _filterFaction;
                    [_asyncFaction] spawn {
                        params ["_asyncFaction"];
                        private _display = findDisplay 60200;
                        if (isNull _display) exitWith {};
                        if (_asyncFaction == "") then {
                            missionNamespace setVariable ["FAC_loadoutGui_stdLoadedScope", "__ALL__"];
                            missionNamespace setVariable ["FAC_loadoutGui_allUnits", [""] call FAC_loadoutGui_buildStdUnits];
                        } else {
                            missionNamespace setVariable ["FAC_loadoutGui_stdLoadedScope", _asyncFaction];
                            missionNamespace setVariable ["FAC_loadoutGui_allUnits", [_asyncFaction] call FAC_loadoutGui_buildStdUnits];
                        };
                        ["filterChanged", []] call FAC_loadoutGui_fnc;
                    };
                    _deferFilterPopulate = true;
                };
            };

            if (!_deferFilterPopulate) then {
            private _allUnits = missionNamespace getVariable ["FAC_loadoutGui_allUnits", []];

            private _searchBox = _display displayCtrl 60211;
            private _searchText = toLower (ctrlText _searchBox);

            private _filtered = [];
            {
                _x params ["_class", "_displayName", "_faction", "_factionDn", "_typeDn"];
                if (_filterFaction == "" || { _faction == _filterFaction }) then {
                    private _label = if (_listMode == "preset" && ((_class find "FAC:") == 0)) then {
                        _factionDn + " > " + _displayName
                    } else {
                        _factionDn + " > " + _typeDn + " > " + _displayName
                    };
                    if (_searchText == "" || { (toLower _label) find _searchText >= 0 }) then {
                        _filtered pushBack _x;
                    };
                };
            } forEach _allUnits;

            if (_listMode == "preset") then {
                _filtered = _filtered apply { [_x select 3, _x select 1, _x] };
            } else {
                _filtered = _filtered apply { [_x select 3, _x select 4, _x select 1, _x] };
            };
            _filtered sort true;
            _filtered = _filtered apply { _x select ((count _x) - 1) };

            private _unitLb = _display displayCtrl 60201;
            lbClear _unitLb;
            {
                _x params ["_class", "_displayName", "_faction", "_factionDn", "_typeDn"];
                private _label = if (_listMode == "preset" && ((_class find "FAC:") == 0)) then {
                    _factionDn + " > " + _displayName
                } else {
                    _factionDn + " > " + _typeDn + " > " + _displayName
                };
                private _idx = _unitLb lbAdd _label;
                _unitLb lbSetData [_idx, _class];
                private _pic = "\a3\ui_f\data\map\markers\nato\b_inf.paa";
                if ((_class find "FAC:") != 0) then {
                    _pic = getText (configFile >> "CfgVehicles" >> _class >> "picture");
                    if (_pic == "") then { _pic = getText (configFile >> "CfgVehicles" >> _class >> "icon") };
                    if (_pic == "") then { _pic = "\a3\ui_f\data\map\markers\nato\b_inf.paa" };
                };
                _unitLb lbSetPicture [_idx, _pic];
                private _loadoutTip = if ((_class find "FAC:") == 0) then {
                    private _arr = [_class] call FAC_loadoutGui_getPresetLoadoutByKey;
                    [_arr] call FAC_loadoutGui_buildLoadoutTextFromArray
                } else {
                    [_class] call FAC_loadoutGui_buildLoadoutText
                };
                _unitLb lbSetTooltip [_idx, _loadoutTip];
            } forEach _filtered;
            if (lbSize _unitLb > 0) then { _unitLb lbSetCurSel 0 };
            };
        };
        case "unitSelChanged": {
            // No-op: loadout info shown via lbSetTooltip on hover
        };
        case "apply": {
            _display = findDisplay 60200;
            if (isNull _display) exitWith {
                systemChat "Loadout GUI: dialog not found.";
            };
            private _unitLb = _display displayCtrl 60201;
            private _idx = lbCurSel _unitLb;
            if (_idx < 0) exitWith {
                systemChat "Select a loadout to apply to your character.";
            };
            private _class = _unitLb lbData _idx;
            if (_class == "") exitWith {
                systemChat "Loadout GUI: no row data  -  re-open the dialog.";
            };

            if ((_class find "FAC:") == 0) then {
                private _presetLoadout = [_class] call FAC_loadoutGui_getPresetLoadoutByKey;
                if (_presetLoadout isEqualType [] && { count _presetLoadout > 0 }) then {
                    private _line = _unitLb lbText _idx;
                    [_presetLoadout, _line, _class] spawn {
                        params ["_load", "_msgLine", "_rowKey"];
                        uiSleep 0.01;
                        if (isNull player || {!alive player} || {!local player}) exitWith {
                            systemChat "Preset apply: no local player.";
                        };
                        // Close loadout dialog  -  some setups block inventory writes while it is open.
                        if (!isNull (findDisplay 60200)) then { closeDialog 0; };
                        uiSleep 0.05;
                        if ([_load] call FAC_loadoutGui_applyLoadoutArrayLocal) then {
                            private _roleDn = "";
                            {
                                if ((_x select 0) == _rowKey) exitWith { _roleDn = _x select 1 };
                            } forEach (missionNamespace getVariable ["FAC_loadoutGui_allUnits", []]);
                            private _tr = [_roleDn] call FAC_loadoutGui_getPresetRoleTraits;
                            [player, _tr select 0, _tr select 1, _tr select 2] call FAC_loadoutGui_syncRoleTraitsLocal;
                            systemChat format ["My preset loadout applied: %1", _msgLine];
                        } else {
                            private _n = [_load] call FAC_loadoutGui_resolvePresetLoadoutArray;
                            systemChat format [
                                "Preset apply failed: resolved loadout length %1 (need 10). Check PresetLoadouts.sqf / ACE export shape.",
                                count _n
                            ];
                        };
                    };
                } else {
                    systemChat "Preset loadout is missing or invalid.";
                };
            } else {
                private _resolvedLoadout = [_class] call FAC_loadoutGui_getLoadoutFromClass;
                if (_resolvedLoadout isEqualType [] && { count _resolvedLoadout > 0 }) then {
                    player setUnitLoadout _resolvedLoadout;
                } else {
                    // Fallback for unusual class configs where template unit creation failed.
                    player setUnitLoadout _class;
                };
                private _cfgTr = [_class] call FAC_loadoutGui_getCfgRoleTraits;
                [player, _cfgTr select 0, _cfgTr select 1, _cfgTr select 2] call FAC_loadoutGui_syncRoleTraitsLocal;
                systemChat format ["My loadout applied: %1", _unitLb lbText _idx];
            };
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };

        case "saveLoadout": {
            // Capture gear + Medic/Engineer traits per UID (onPlayerRespawn restores both).
            [player] call FAC_loadoutGui_saveRespawnLoadoutSnapshot;
            systemChat "Loadout saved - will be restored on respawn.";
            ["updateSaveStatus", []] call FAC_loadoutGui_fnc;
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };

        case "restoreLoadout": {
            private _saved = missionNamespace getVariable ["FAC_savedLoadout_" + getPlayerUID player, []];
            if (count _saved == 0) exitWith {
                systemChat "No saved loadout - use SAVE LOADOUT first.";
            };
            [player] call FAC_loadoutGui_restoreRespawnLoadoutSnapshot;
            systemChat "Saved loadout restored.";
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };

        case "addRadio343": {
            ["ACRE_PRC343", "ACRE 343"] call FAC_loadoutGui_tryAddRadio;
        };

        case "addRadio152": {
            ["ACRE_PRC152", "ACRE 152"] call FAC_loadoutGui_tryAddRadio;
        };

        case "addZipties": {
            ["ACE_CableTie", "Zipties", 2] call FAC_loadoutGui_tryAddItemCount;
        };

        case "addIrStrobe": {
            ["ACE_IR_Strobe_Item", "IR strobe", 1] call FAC_loadoutGui_tryAddItemCount;
        };

        case "addIfak": {
            ["kat_IFAK", "IFAK", 1] call FAC_loadoutGui_tryAddItemCount;
        };

        case "addBandages": {
            [] call FAC_loadoutGui_tryAddBandageBundle;
        };

        case "setCivInterpreter": {
            if (isNull player || {!alive player}) exitWith {};
            player setVariable ["FADE_civInterpreter", true, true];
            systemChat "Marked as interpreter  -  you can talk to civilians when the scenario requires it.";
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };

        case "clearCivInterpreter": {
            if (isNull player) exitWith {};
            player setVariable ["FADE_civInterpreter", false, true];
            systemChat "Interpreter flag removed.";
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };

        case "setIntelSpecialist": {
            if (isNull player || {!alive player}) exitWith {};
            player setVariable ["FADE_intelSpecialist", true, true];
            systemChat "Marked as Intel specialist.";
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };

        case "clearIntelSpecialist": {
            if (isNull player) exitWith {};
            player setVariable ["FADE_intelSpecialist", false, true];
            systemChat "Intel specialist flag removed.";
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };

        case "updateSaveStatus": {
            if (isNull _display) exitWith {};
            private _saved = missionNamespace getVariable ["FAC_savedLoadout_" + getPlayerUID player, []];
            private _hasSave = count _saved > 0;
            (_display displayCtrl 60205) ctrlSetText (if (_hasSave) then { "Respawn loadout: saved" } else { "Respawn loadout: not saved (will use default on respawn)" });
            (_display displayCtrl 60206) ctrlEnable _hasSave;
        };
    };
};

// Register so description.ext onLoad finds the function (missionNamespace used by config).
// onLoad also sets uinamespace for consistency with other GUIs.
missionNamespace setVariable ["FAC_loadoutGui_fnc", FAC_loadoutGui_fnc];
