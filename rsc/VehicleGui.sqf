// =============================================================================
// VehicleGui.sqf - Manage vehicles (aircraft + land vehicles)
// =============================================================================
// Aircraft: spawn at helipads (existing logic). Land vehicles: spawn at VEH_1/VEH_2.
// Name format: [Faction] > [Vehicle] (matches Loadout GUI). Shows vehicle stats on select.
// =============================================================================

// Get faction display name (reuse LoadoutGui helper if available)
FAC_vehicleGui_getFactionDisplayName = {
    params ["_faction"];
    if (_faction == "") exitWith { "Unknown" };
    if (!isNil "FAC_loadoutGui_getFactionDisplayName") exitWith { [_faction] call FAC_loadoutGui_getFactionDisplayName };
    private _cfg = configFile >> "CfgFactionClasses" >> _faction;
    if (isClass _cfg) then {
        private _dn = getText (_cfg >> "displayName");
        if (_dn != "") exitWith { _dn };
    };
    (_faction splitString "_") joinString " "
};

// Build vehicle tooltip text (cargo seats, weapons) - like Loadout GUI lbSetTooltip
FAC_vehicleGui_buildVehicleTooltip = {
    params ["_class"];
    if (isNil "_class" || { _class == "" }) exitWith { "" };
    if (!isClass (configFile >> "CfgVehicles" >> _class)) exitWith { "" };
    private _cfg = configFile >> "CfgVehicles" >> _class;
    private _lines = [];
    // Transport seats (cargo/passenger)
    private _total = [_class, true] call BIS_fnc_crewCount;
    private _crew = [_class, false] call BIS_fnc_crewCount;
    private _cargo = (_total - _crew) max 0;
    _lines pushBack format ["Transport seats: %1", _cargo];
    // Weapons
    private _weapons = getArray (_cfg >> "weapons");
    if (count _weapons > 0) then {
        private _wepNames = _weapons apply {
            private _w = configFile >> "CfgWeapons" >> _x;
            if (isClass _w) then { getText (_w >> "displayName") } else { _x }
        };
        _wepNames = _wepNames select { _x != "" && { _x != "Throw" } && { _x != "Put" } };
        if (count _wepNames > 0) then {
            _lines pushBack ("Weapons: " + ((_wepNames select [0, 8]) joinString ", "));
        };
    };
    if (count _lines == 0) exitWith { format ["Class: %1", _class] };
    _lines joinString "\n"
};

FAC_vehicleGui_fnc = {
    params ["_action", "_params"];
    private _display = findDisplay 60001;
    if (isNull _display && { _action != "open" }) exitWith {};

    switch _action do {
        case "open": {
            private _hasAircraft = !(isNil "FADE_heliClasses") && { count FADE_heliClasses > 0 };
            private _hasLand = !(isNil "FADE_landVehicleClasses") && { count FADE_landVehicleClasses > 0 };
            if (!_hasAircraft && !_hasLand) then {
                systemChat "VEHICLE CONFIG NOT READY.";
            } else {
                if (!createDialog "RscDisplayVehicle") then {
                    systemChat "VEHICLE GUI: RESOURCE NOT FOUND.";
                };
            };
        };
        case "onLoad": {
            private _display = findDisplay 60001;
            if (isNull _display) exitWith {};
            uinamespace setVariable ["FAC_vehicleGui_fnc", FAC_vehicleGui_fnc];

            // Category: Aircraft | Land vehicles
            private _catCombo = _display displayCtrl 60170;
            lbClear _catCombo;
            _catCombo lbAdd "Aircraft";
            _catCombo lbSetData [0, "aircraft"];
            _catCombo lbAdd "Land vehicles";
            _catCombo lbSetData [1, "land"];
            _catCombo lbSetCurSel 0;

            ["categoryChanged", []] call FAC_vehicleGui_fnc;
            ["refreshSpawned", []] call FAC_vehicleGui_fnc;
            ["updateButtons", []] call FAC_vehicleGui_fnc;
        };
        case "categoryChanged": {
            if (isNull _display) exitWith {};
            private _catList = _display displayCtrl 60170;
            private _cat = _catList lbData (lbCurSel _catList);
            private _classes = if (_cat == "aircraft") then { missionNamespace getVariable ["FADE_heliClasses", []] } else { missionNamespace getVariable ["FADE_landVehicleClasses", []] };

            // Build full list: use CfgFactionClasses displayName (same as filter) for consistency
            private _fullList = [];
            {
                private _cfg = configFile >> "CfgVehicles" >> _x;
                private _name = getText (_cfg >> "displayName");
                if (_name == "") then { _name = _x };
                private _faction = getText (_cfg >> "faction");
                private _factionDn = getText (configFile >> "CfgFactionClasses" >> _faction >> "displayName");
                if (_factionDn == "") then { _factionDn = _faction };
                _fullList pushBack [_x, _name, _faction, _factionDn];
            } forEach _classes;
            if (missionNamespace getVariable ["FADE_limitGearToFriendlyFaction", false]) then {
                private _allowed = missionNamespace getVariable ["FADE_friendlyVehicleClasses", []];
                if (count _allowed > 0) then {
                    _fullList = _fullList select { (_x select 0) in _allowed };
                };
            };
            missionNamespace setVariable ["FAC_vehicleGui_fullList", _fullList];

            // Build faction filter: unique class ids, ordered by CfgFactionClasses displayName (ascending)
            private _factionIds = [];
            { private _f = _x select 2; if (_f != "" && { !(_f in _factionIds) }) then { _factionIds pushBack _f } } forEach _fullList;
            private _factionPairs = _factionIds apply {
                private _dn = getText (configFile >> "CfgFactionClasses" >> _x >> "displayName");
                if (_dn == "") then { _dn = _x };
                [_dn, _x]
            };
            _factionPairs sort true;
            private _factionList = _display displayCtrl 60181;
            lbClear _factionList;
            private _idx = _factionList lbAdd "All factions";
            _factionList lbSetData [_idx, ""];
            { _x params ["_dn", "_id"]; private _i = _factionList lbAdd _dn; _factionList lbSetData [_i, _id] } forEach _factionPairs;
            if (lbSize _factionList > 0) then { _factionList lbSetCurSel 0 };

            private _searchEdit = _display displayCtrl 60180;
            _searchEdit ctrlSetText "";

            ["filterChanged", []] call FAC_vehicleGui_fnc;
        };
        case "filterChanged": {
            if (isNull _display) exitWith {};
            private _fullList = missionNamespace getVariable ["FAC_vehicleGui_fullList", []];
            private _factionList = _display displayCtrl 60181;
            private _searchEdit = _display displayCtrl 60180;
            private _lb = _display displayCtrl 60100;

            private _factionFilter = "";
            if (lbCurSel _factionList >= 0) then { _factionFilter = _factionList lbData (lbCurSel _factionList) };
            if (_factionFilter == "All factions") then { _factionFilter = "" };
            private _searchText = toLower (ctrlText _searchEdit);

            // Filter and sort by [Faction] > [Vehicle] (matches Loadout GUI)
            private _filtered = [];
            {
                _x params ["_cls", "_name", "_faction", "_factionDn"];
                if (_factionFilter == "" || { _faction == _factionFilter }) then {
                    if (_searchText == "" || { (toLower _name) find _searchText >= 0 } || { (toLower _cls) find _searchText >= 0 } || { (toLower _factionDn) find _searchText >= 0 }) then {
                        _filtered pushBack _x;
                    };
                };
            } forEach _fullList;
            _filtered = _filtered apply { [_x select 3, _x select 1, _x] };
            _filtered sort true;
            _filtered = _filtered apply { _x select 2 };
            lbClear _lb;
            {
                _x params ["_cls", "_name", "_faction", "_factionDn"];
                private _label = _factionDn + " > " + _name;
                private _idx = _lb lbAdd _label;
                _lb lbSetData [_idx, _cls];
                private _tip = [_cls] call FAC_vehicleGui_buildVehicleTooltip;
                _lb lbSetTooltip [_idx, if (_tip != "") then { _tip } else { format ["Class: %1", _cls] }];
            } forEach _filtered;
            if (lbSize _lb > 0) then { _lb lbSetCurSel 0 };
            ["heliSel", []] call FAC_vehicleGui_fnc;
            ["updateButtons", []] call FAC_vehicleGui_fnc;
        };
        case "heliSel": {
            if (isNull _display) exitWith {};
            private _lb = _display displayCtrl 60100;
            private _idx = lbCurSel _lb;
            if (_idx < 0) exitWith {};
            private _class = _lb lbData _idx;
            private _pic = _display displayCtrl 60101;
            // Prefer Zeus-style preview image first, then legacy picture/icon fallbacks.
            private _cfgVeh = configFile >> "CfgVehicles" >> _class;
            private _texture = getText (_cfgVeh >> "editorPreview");
            if (_texture == "") then { _texture = getText (_cfgVeh >> "picture") };
            if (_texture == "") then { _texture = getText (_cfgVeh >> "icon") };
            if (_texture != "") then { _pic ctrlSetText _texture } else { _pic ctrlSetText "" };
        };
        case "spawn": {
            if (isNull _display) exitWith {};
            private _catCombo = _display displayCtrl 60170;
            private _cat = _catCombo lbData (lbCurSel _catCombo);
            private _lb = _display displayCtrl 60100;
            private _idx = lbCurSel _lb;
            if (_idx < 0) then { systemChat "Select a vehicle."; return };
            private _class = _lb lbData _idx;
            private _displayName = getText (configFile >> "CfgVehicles" >> _class >> "displayName");
            if (_displayName == "") then { _displayName = _class };

            if (_cat == "aircraft") then {
                [_class, player] remoteExec ["FADE_spawnHeli", 2];
                systemChat format ["SPAWNING %1...", _displayName];
            } else {
                [_class, player] remoteExec ["FADE_spawnLandVehicle", 2];
                systemChat format ["SPAWNING %1...", _displayName];
            };
            [] spawn { sleep 2; if (!isNull (findDisplay 60001)) then { ["refreshSpawned", []] call FAC_vehicleGui_fnc } };
        };
        case "despawn": {
            if (isNull _display) exitWith {};
            private _spawnedLb = _display displayCtrl 60110;
            private _idx = lbCurSel _spawnedLb;
            if (_idx < 0) then { systemChat "Select a vehicle to despawn."; return };
            private _varName = _spawnedLb lbData _idx;
            if (_varName == "") exitWith {};
            private _obj = missionNamespace getVariable [_varName, objNull];
            if (isNull _obj) exitWith { systemChat "VEHICLE NO LONGER EXISTS." };
            [_obj, player] remoteExec ["FADE_despawnVehicle", 2];
            systemChat "DESPAWNING...";
            [] spawn { sleep 1; if (!isNull (findDisplay 60001)) then { ["refreshSpawned", []] call FAC_vehicleGui_fnc } };
        };
        case "serviceVehicle": {
            if (isNull _display) exitWith {};
            private _spawnedLb = _display displayCtrl 60110;
            private _idx = lbCurSel _spawnedLb;
            if (_idx < 0) then { systemChat "Select a vehicle in Vehicles at base."; return };
            private _varName = _spawnedLb lbData _idx;
            if (_varName == "") exitWith {};
            private _obj = missionNamespace getVariable [_varName, objNull];
            if (isNull _obj) exitWith { systemChat "VEHICLE NO LONGER EXISTS." };
            [_obj, player] remoteExec ["FADE_serviceVehicle", 2];
        };
        case "refreshSpawned": {
            if (isNull _display) exitWith {};
            [player] remoteExec ["FADE_requestVehiclesAtBase", 2];
        };
        case "receiveSpawned": {
            _params params [["_vehicleData", []]];
            if (isNil "_vehicleData") then { _vehicleData = [] };
            if (_vehicleData isEqualType [] && { count _vehicleData > 0 } && { (_vehicleData select 0) isEqualType objNull }) then {
                _vehicleData = _vehicleData apply { [_x, "Base"] };
            };
            private _disp = findDisplay 60001;
            if (isNull _disp) exitWith {};
            private _basePos = missionNamespace getVariable ["FADE_basePos", [0,0,0]];
            private _lb = _disp displayCtrl 60110;
            lbClear _lb;
            { _x params ["_veh", "_padName"]; if (!isNull _veh && { alive _veh }) then { private _cls = typeOf _veh; private _name = getText (configFile >> "CfgVehicles" >> _cls >> "displayName"); if (_name == "") then { _name = _cls }; private _faction = getText (configFile >> "CfgVehicles" >> _cls >> "faction"); private _factionDn = getText (configFile >> "CfgFactionClasses" >> _faction >> "displayName"); if (_factionDn == "") then { _factionDn = _faction }; private _label = _factionDn + " > " + _name + " - " + _padName; private _varName = "FADE_obj_" + (str _veh); missionNamespace setVariable [_varName, _veh]; private _idx = _lb lbAdd _label; _lb lbSetData [_idx, _varName]; _lb lbSetTooltip [_idx, format ["%1 at %2", _cls, _padName]] } } forEach _vehicleData;
            ["updateButtons", []] call FAC_vehicleGui_fnc;
        };
        case "updateButtons": {
            if (isNull _display) exitWith {};
            private _heliLb = _display displayCtrl 60100;
            private _spawnedLb = _display displayCtrl 60110;
            private _spawnBtn = _display displayCtrl 60102;
            private _despawnBtn = _display displayCtrl 60111;
            private _serviceBtn = _display displayCtrl 60112;
            private _spawnedSel = lbSize _spawnedLb > 0 && { lbCurSel _spawnedLb >= 0 };
            _spawnBtn ctrlEnable (lbSize _heliLb > 0 && { lbCurSel _heliLb >= 0 });
            _despawnBtn ctrlEnable _spawnedSel;
            if (!isNull _serviceBtn) then { _serviceBtn ctrlEnable _spawnedSel };
        };
    };
};

FADE_receiveVehiclesAtBase = {
    params [["_vehicleData", []]];
    if (isNil "_vehicleData") then { _vehicleData = [] };
    if !(_vehicleData isEqualType []) then { _vehicleData = [] };
    ["receiveSpawned", [_vehicleData]] call FAC_vehicleGui_fnc;
};
