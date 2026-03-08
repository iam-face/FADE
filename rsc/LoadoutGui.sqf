// =============================================================================
// LoadoutGui.sqf — Loadout selection dialog
// =============================================================================
// Allows players to change their loadout by selecting from all infantry units
// of the same side. Supports filtering by faction. CTB presets appear at top when available.
// =============================================================================

// CTB typical loadout presets: [displayName, unitClass]. Same as selecting that unit; class must exist in CfgVehicles and match player side.
FAC_ctbLoadoutPresets = [
    ["Rifleman", "B_Soldier_F"],
    ["Team Leader", "B_Soldier_TL_F"],
    ["Medic", "B_medic_F"],
    ["Auto Rifleman", "B_Soldier_AR_F"],
    ["Grenadier", "B_Soldier_GL_F"],
    ["Marksman", "B_soldier_M_F"],
    ["Engineer", "B_engineer_F"]
];

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

// Build list of infantry unit classes for player's side
// Returns: [[classname, displayName, faction, factionDisplayName, typeDisplayName], ...]
FAC_loadoutGui_getUnitsForSide = {
    params ["_side"];
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
                private _displayName = getText (_cfg >> "displayName");
                if (_displayName == "") then { _displayName = _class };
                private _faction = getText (_cfg >> "faction");
                private _factionDn = if (_faction != "") then { [_faction] call FAC_loadoutGui_getFactionDisplayName } else { "Unknown" };
                private _vc = getText (_cfg >> "vehicleClass");
                private _typeDn = "Infantry";
                { if ((_x select 0) == _vc) exitWith { _typeDn = _x select 1 } } forEach FAC_loadoutGui_vehicleClassToType;
                if (_vc != "" && { _typeDn == "Infantry" } && { _vc != "Men" }) then { _typeDn = _vc };
                _result pushBack [_class, _displayName, _faction, _factionDn, _typeDn];
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
            ("Items: " + (_itemStrs joinString ", ")) call _add;
        };
    };

    if (count _lines == 0) exitWith { "No loadout data." };
    _lines joinString "\n"
};

// Get unit preview picture path from config
FAC_loadoutGui_getUnitPicture = {
    params ["_class"];
    private _cfg = configFile >> "CfgVehicles" >> _class;
    if (!isClass _cfg) exitWith { "" };
    private _pic = getText (_cfg >> "picture");
    if (_pic == "") then { _pic = getText (_cfg >> "icon") };
    if (_pic == "") then { _pic = "\a3\ui_f\data\map\markers\nato\b_inf.paa" };  // Fallback: NATO infantry icon
    _pic
};

FAC_loadoutGui_fnc = {
    params ["_action", "_params"];
    private _display = findDisplay 60200;
    if (isNull _display && { _action != "open" }) exitWith {};

    switch _action do {
        case "open": {
            if (!createDialog "RscDisplayLoadout") then {
                systemChat "LOADOUT GUI: RESOURCE NOT FOUND.";
            };
        };
        case "onLoad": {
            private _display = findDisplay 60200;
            if (isNull _display) exitWith {};
            missionNamespace setVariable ["FAC_loadoutGui_fnc", FAC_loadoutGui_fnc];
            uinamespace setVariable ["FAC_loadoutGui_fnc", FAC_loadoutGui_fnc];

            // Show loading state immediately so dialog doesn't appear blank
            private _unitLb = _display displayCtrl 60201;
            lbClear _unitLb;
            _unitLb lbAdd "Loading...";
            _unitLb lbSetCurSel 0;

            // Defer heavy config scan so UI renders first
            [] spawn {
                private _allUnits = [side player] call FAC_loadoutGui_getUnitsForSide;
                if (missionNamespace getVariable ["FADE_limitGearToFriendlyFaction", false]) then {
                    private _allowed = missionNamespace getVariable ["FADE_friendlyUnits", []];
                    if (count _allowed > 0) then {
                        _allUnits = _allUnits select { (_x select 0) in _allowed };
                    };
                };
                // Prepend CTB presets (same side) so they appear at top
                private _sideNum = (side player) call BIS_fnc_sideID;
                {
                    _x params ["_dn", "_cls"];
                    if (isClass (configFile >> "CfgVehicles" >> _cls) && { getNumber (configFile >> "CfgVehicles" >> _cls >> "side") == _sideNum }) then {
                        _allUnits = [[_cls, _dn + " (CTB)", "", "CTB Preset", "Preset"]] + _allUnits;
                    };
                } forEach (missionNamespace getVariable ["FAC_ctbLoadoutPresets", []]);
                missionNamespace setVariable ["FAC_loadoutGui_allUnits", _allUnits];

                private _display = findDisplay 60200;
                if (isNull _display) exitWith {};

                // Build unique factions for filter
                private _factions = [];
                { if ((_x select 2) != "" && { !((_x select 2) in _factions) }) then { _factions pushBack (_x select 2) } } forEach _allUnits;
                _factions sort true;

                private _factionList = _display displayCtrl 60210;
                lbClear _factionList;
                private _idx = _factionList lbAdd "All factions";
                _factionList lbSetData [_idx, ""];
                _factionList lbSetCurSel 0;
                { private _dn = [_x] call FAC_loadoutGui_getFactionDisplayName; _idx = _factionList lbAdd _dn; _factionList lbSetData [_idx, _x] } forEach _factions;

                ["filterChanged", []] call FAC_loadoutGui_fnc;
                ["updateSaveStatus", []] call FAC_loadoutGui_fnc;
            };
        };
        case "filterChanged": {
            if (isNull _display) exitWith {};
            private _allUnits = missionNamespace getVariable ["FAC_loadoutGui_allUnits", []];
            if (count _allUnits == 0) exitWith {};  // Still loading
            private _factionList = _display displayCtrl 60210;
            private _filterFaction = "";
            private _sel = lbCurSel _factionList;
            if (_sel >= 0) then { _filterFaction = _factionList lbData _sel };

            private _searchBox = _display displayCtrl 60211;
            private _searchText = toLower (ctrlText _searchBox);

            private _filtered = [];
            {
                _x params ["_class", "_displayName", "_faction", "_factionDn", "_typeDn"];
                if (_filterFaction == "" || { _faction == _filterFaction }) then {
                    private _label = _factionDn + " > " + _typeDn + " > " + _displayName;
                    if (_searchText == "" || { (toLower _label) find _searchText >= 0 }) then {
                        _filtered pushBack _x;
                    };
                };
            } forEach _allUnits;

            // Sort by Faction > Type > DisplayName for easier navigation
            _filtered = _filtered apply { [_x select 3, _x select 4, _x select 1, _x] };
            _filtered sort true;
            _filtered = _filtered apply { _x select 3 };

            private _unitLb = _display displayCtrl 60201;
            lbClear _unitLb;
            {
                _x params ["_class", "_displayName", "_faction", "_factionDn", "_typeDn"];
                private _label = _factionDn + " > " + _typeDn + " > " + _displayName;
                private _idx = _unitLb lbAdd _label;
                _unitLb lbSetData [_idx, _class];
                private _pic = getText (configFile >> "CfgVehicles" >> _class >> "picture");
                if (_pic == "") then { _pic = getText (configFile >> "CfgVehicles" >> _class >> "icon") };
                if (_pic == "") then { _pic = "\a3\ui_f\data\map\markers\nato\b_inf.paa" };
                _unitLb lbSetPicture [_idx, _pic];
                private _loadoutTip = [_class] call FAC_loadoutGui_buildLoadoutText;
                _unitLb lbSetTooltip [_idx, _loadoutTip];
            } forEach _filtered;
            if (lbSize _unitLb > 0) then { _unitLb lbSetCurSel 0 };
        };
        case "unitSelChanged": {
            // No-op: loadout info shown via lbSetTooltip on hover
        };
        case "apply": {
            if (isNull _display) exitWith {};
            private _unitLb = _display displayCtrl 60201;
            private _idx = lbCurSel _unitLb;
            if (_idx < 0) exitWith {
                systemChat "Select a loadout to apply to your character.";
            };
            private _class = _unitLb lbData _idx;
            if (_class == "") exitWith {};

            player setUnitLoadout _class;
            systemChat format ["My loadout applied: %1", _unitLb lbText _idx];
        };

        case "saveLoadout": {
            // Capture the player's current full gear array and store it per-UID.
            // onPlayerRespawn.sqf reads this and re-applies it after death.
            private _loadout = getUnitLoadout player;
            missionNamespace setVariable ["FAC_savedLoadout_" + getPlayerUID player, _loadout];
            systemChat "Loadout saved - will be restored on respawn.";
            ["updateSaveStatus", []] call FAC_loadoutGui_fnc;
        };

        case "restoreLoadout": {
            private _saved = missionNamespace getVariable ["FAC_savedLoadout_" + getPlayerUID player, []];
            if (count _saved == 0) exitWith {
                systemChat "No saved loadout - use SAVE LOADOUT first.";
            };
            player setUnitLoadout _saved;
            systemChat "Saved loadout restored.";
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
