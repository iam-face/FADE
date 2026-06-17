// =============================================================================
// VehicleGui.sqf - Vehicles: single dialog (60001), header tabs + main content
// =============================================================================
// Spawn: aircraft on HP_* (optional pad index); land vehicles use VEH_* slot selection (auto by default).
// Manage: list at base, repair/refuel/rearm, despawn. Server RPCs in initServer.
// =============================================================================

FAC_vehicleGui_IDD = 60001;
FAC_vehicleGui_spawnContentIdcs = [61101, 61102, 61103, 61104, 61105, 61106, 61107, 61112, 61113, 61114, 61115, 61116, 61117, 61118];
FAC_vehicleGui_manageContentIdcs = [61200, 61201, 61202, 61205, 61206, 61210, 61211, 61220, 61221, 61222, 61223, 61224, 61225, 61226, 61227, 61228, 61229, 61230, 61232, 61240, 61241, 61242];

FAC_vehicleGui_syncHeaderTabs = {
    private _d = findDisplay FAC_vehicleGui_IDD;
    if (isNull _d) exitWith {};
    private _tab = missionNamespace getVariable ["FAC_vehicleGui_tab", "new"];
    private _tNew = _d displayCtrl 61000;
    private _tEx = _d displayCtrl 61001;
    private _act = [0.22, 0.48, 0.78, 1];
    private _inact = [0.07, 0.11, 0.20, 1];
    if (_tab == "new") then {
        _tNew ctrlSetBackgroundColor _act;
        _tEx ctrlSetBackgroundColor _inact;
    } else {
        _tNew ctrlSetBackgroundColor _inact;
        _tEx ctrlSetBackgroundColor _act;
    };
};

FAC_vehicleGui_resetDeleteWreckButton = {
    private _d = findDisplay FAC_vehicleGui_IDD;
    if (isNull _d) exitWith {};
    private _btn = _d displayCtrl 61004;
    if (isNull _btn) exitWith {};
    _btn ctrlSetText "Delete wrecks";
    _btn ctrlSetTextColor [0.98, 0.97, 0.95, 1];
    _btn ctrlSetBackgroundColor [0.36, 0.22, 0.16, 1];
};

FAC_vehicleGui_syncSpawnCategoryButtons = {
    private _d = findDisplay FAC_vehicleGui_IDD;
    if (isNull _d) exitWith {};
    private _cat = missionNamespace getVariable ["FAC_vehicleGui_spawnCategory", "aircraft"];
    private _bAir = _d displayCtrl 61116;
    private _bLand = _d displayCtrl 61117;
    if (isNull _bAir || { isNull _bLand }) exitWith {};
    private _act = [0.22, 0.48, 0.78, 1];
    private _inact = [0.07, 0.11, 0.20, 1];
    if (_cat == "aircraft") then {
        _bAir ctrlSetBackgroundColor _act;
        _bLand ctrlSetBackgroundColor _inact;
    } else {
        _bAir ctrlSetBackgroundColor _inact;
        _bLand ctrlSetBackgroundColor _act;
    };
};

// Aircraft-only: whitelist toggle (61118); hidden on Land Vehicles tab.
FAC_vehicleGui_syncWhitelistSpawnControl = {
    private _d = findDisplay FAC_vehicleGui_IDD;
    if (isNull _d) exitWith {};
    private _b = _d displayCtrl 61118;
    if (isNull _b) exitWith {};
    private _cat = missionNamespace getVariable ["FAC_vehicleGui_spawnCategory", "aircraft"];
    private _show = _cat == "aircraft";
    _b ctrlShow _show;
    if (_show) then {
        private _on = missionNamespace getVariable ["FAC_vehicleGui_whitelistAircraft", true];
        _b ctrlSetText format ["Aircraft whitelist: %1", if (_on) then {"ON"} else {"OFF"}];
    };
};

// Pylon/loadout UI: vanilla player action names (VehicleCustomization, OpenPylonLoadout) are not valid on all clients.
// ACE3 Pylons: ace_pylons_fnc_showDialog — non-curator mode auto-closes the dialog when player is farther than
// ace_pylons_searchDistance (default 15m) from the aircraft (vehicle board vs pad). Curator mode [veh, true] skips
// that check when ace_zeus is loaded (same as Zeus “configure pylons”). See cba_settings.sqf for distance fallback.
FAC_vehicleGui_tryOpenPylonDialog = {
    params ["_veh"];
    if (isNull _veh || {!alive _veh}) exitWith { false };
    if (count getAllPylonsInfo _veh <= 0) exitWith { false };
    if (!isNil "ace_pylons_fnc_showDialog") exitWith {
        private _curator = isClass (configFile >> "CfgPatches" >> "ace_zeus");
        [_veh, _curator] call ace_pylons_fnc_showDialog;
        true
    };
    systemChat "Pylon loadout needs ACE3 with the Pylons component (ace_pylons). Vanilla UI actions are unavailable here.";
    false
};

// RscListBoxVehicleDetails: fill with one lbAdd per line; native scrollbar, not editable
FAC_vehicleGui_setDetailsList = {
    params ["_lb", ["_text", ""]];
    lbClear _lb;
    if (_text isEqualTo "") exitWith { _lb lbSetCurSel -1 };
    private _flat = (_text splitString (toString [13])) joinString "";
    private _lines = _flat splitString (toString [10]);
    { _lb lbAdd _x } forEach _lines;
    _lb lbSetCurSel -1;
};

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

// Tooltip for list rows (short)
FAC_vehicleGui_buildVehicleTooltip = {
    params ["_class"];
    if (isNil "_class" || { _class == "" }) exitWith { "" };
    if (!isClass (configFile >> "CfgVehicles" >> _class)) exitWith { "" };
    private _cfg = configFile >> "CfgVehicles" >> _class;
    private _lines = [];
    private _total = [_class, true] call BIS_fnc_crewCount;
    private _crew = [_class, false] call BIS_fnc_crewCount;
    private _cargo = (_total - _crew) max 0;
    _lines pushBack format ["Transport seats: %1", _cargo];
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

// Plain multiline details (RscEdit — StructuredText often draws nothing in custom dialogs)
FAC_vehicleGui_buildVehicleDetailsPlain = {
    params ["_class"];
    private _nl = toString [10];
    if (isNil "_class" || { _class == "" }) exitWith { "No selection." };
    if (!isClass (configFile >> "CfgVehicles" >> _class)) exitWith { "Invalid class." };
    private _cfg = configFile >> "CfgVehicles" >> _class;
    private _dn = getText (_cfg >> "displayName");
    if (_dn == "") then { _dn = _class };
    private _typeStr = "Vehicle";
    if (_class isKindOf "Helicopter") then { _typeStr = "Helicopter" };
    if (_class isKindOf "Plane") then { _typeStr = "Plane" };
    if (_class isKindOf "Tank") then { _typeStr = "Tank" };
    if (_class isKindOf "Car") then { _typeStr = "Car" };
    if (_class isKindOf "Truck_F") then { _typeStr = "Truck" };
    if (_class isKindOf "Ship") then { _typeStr = "Boat" };
    private _total = [_class, true] call BIS_fnc_crewCount;
    private _crew = [_class, false] call BIS_fnc_crewCount;
    private _cargo = (_total - _crew) max 0;
    private _lines = [];
    _lines pushBack format ["Vehicle Name: %1", _dn];
    _lines pushBack format ["Classname: %1", _class];
    _lines pushBack format ["Type: %1", _typeStr];
    _lines pushBack format ["Crew positions: %1 | Passenger/cargo seats: %2", _crew, _cargo];
    private _stats = [];
    private _fuel = getNumber (_cfg >> "fuelCapacity");
    if (_fuel > 0) then { _stats pushBack format ["Fuel capacity (cfg): %1", _fuel] };
    private _ms = getNumber (_cfg >> "maxSpeed");
    if (_ms > 0) then { _stats pushBack format ["Max speed (cfg): %1", _ms] };
    private _armor = getNumber (_cfg >> "armor");
    if (_armor > 0) then { _stats pushBack format ["Armor (cfg): %1", _armor] };
    private _sling = getNumber (_cfg >> "slingLoadMaxCargoMass");
    if (_sling > 0) then { _stats pushBack format ["Sling load max (kg): %1", _sling] };
    if (count _stats > 0) then { _lines pushBack (_stats joinString ", ") };
    private _weapons = getArray (_cfg >> "weapons");
    _weapons = _weapons select { _x != "" && { _x != "Throw" } && { _x != "Put" } };
    if (count _weapons > 0) then {
        private _wepLine = _weapons apply {
            private _w = configFile >> "CfgWeapons" >> _x;
            if (isClass _w) then { getText (_w >> "displayName") } else { _x }
        };
        _lines pushBack ("Weapons: " + ((_wepLine select [0, 12]) joinString ", "));
    };
    private _mags = getArray (_cfg >> "magazines");
    if (count _mags > 0) then {
        _lines pushBack ("Magazines (vehicle): " + ((_mags select [0, 10]) joinString ", "));
    };
    _lines joinString _nl
};

// Manage tab: mockup "Selected vehicle details" (Cfg only; live fuel/health are on sliders).
FAC_vehicleGui_buildManageConfigDetailsPlain = {
    params ["_class"];
    private _nl = toString [10];
    if (isNil "_class" || { _class == "" }) exitWith { "No selection." };
    if (!isClass (configFile >> "CfgVehicles" >> _class)) exitWith { "Invalid class." };
    private _cfg = configFile >> "CfgVehicles" >> _class;
    private _dn = getText (_cfg >> "displayName");
    if (_dn == "") then { _dn = _class };
    private _typeStr = "Vehicle";
    if (_class isKindOf "Helicopter") then { _typeStr = "Helicopter" };
    if (_class isKindOf "Plane") then { _typeStr = "Plane" };
    if (_class isKindOf "Tank") then { _typeStr = "Tank" };
    if (_class isKindOf "Car") then { _typeStr = "Car" };
    if (_class isKindOf "Truck_F") then { _typeStr = "Truck" };
    if (_class isKindOf "Ship") then { _typeStr = "Boat" };
    private _total = [_class, true] call BIS_fnc_crewCount;
    private _crew = [_class, false] call BIS_fnc_crewCount;
    private _cargo = (_total - _crew) max 0;
    private _lines = [];
    _lines pushBack format ["Name: %1", _dn];
    _lines pushBack format ["Class: %1", _class];
    _lines pushBack format ["Type: %1", _typeStr];
    _lines pushBack format ["Crew positions: %1 | Passenger/cargo seats: %2", _crew, _cargo];
    private _stats = [];
    private _fuel = getNumber (_cfg >> "fuelCapacity");
    if (_fuel > 0) then { _stats pushBack format ["Fuel capacity [cfg]: %1", _fuel] };
    private _ms = getNumber (_cfg >> "maxSpeed");
    if (_ms > 0) then { _stats pushBack format ["Max speed [cfg]: %1", _ms] };
    private _armor = getNumber (_cfg >> "armor");
    if (_armor > 0) then { _stats pushBack format ["Armor [cfg]: %1", _armor] };
    private _sling = getNumber (_cfg >> "slingLoadMaxCargoMass");
    if (_sling > 0) then { _stats pushBack format ["Sling load max [cfg] (kg): %1", _sling] };
    if (count _stats > 0) then { _lines pushBack (_stats joinString ", ") };
    _lines joinString _nl
};

FAC_vehicleGui_manageFillManageDetails = {
    params ["_display", "_cls"];
    private _det = _display displayCtrl 61211;
    if (isNil "_cls" || { _cls == "" }) exitWith { [_det, ""] call FAC_vehicleGui_setDetailsList };
    [_det, [_cls] call FAC_vehicleGui_buildManageConfigDetailsPlain] call FAC_vehicleGui_setDetailsList;
};

FAC_vehicleGui_getManageSelectedVehicle = {
    private _display = findDisplay FAC_vehicleGui_IDD;
    if (isNull _display) exitWith { objNull };
    private _lb = _display displayCtrl 61200;
    private _idx = lbCurSel _lb;
    if (_idx < 0) exitWith { objNull };
    private _varName = _lb lbData _idx;
    if (_varName == "") exitWith { objNull };
    missionNamespace getVariable [_varName, objNull]
};

// Fill ammo list: turret magazines (magazinesAllTurrets) + dynamic pylons (getPylonMagazines / ammoOnPylon).
// lbData: [mag, cur, max] or ["PYLON", pylonIndex, mag, cur, max] for apply/slider logic.
FAC_vehicleGui_rebuildManageAmmoList = {
    params ["_veh", "_ammoLb"];
    lbClear _ammoLb;
    if (isNull _veh || {!alive _veh}) exitWith {};

    private _magState = magazinesAllTurrets _veh;
    {
        private _n = count _x;
        if (_n >= 2) then {
            private _turretPath = _x select 0;
            private _mag = _x select 1;
            private _cur = if (_n > 2) then { _x select 2 } else { 0 };
            if (_mag isEqualType "" && {_mag != ""}) then {
                if (!(_cur isEqualType 0)) then { _cur = 0 };
                _cur = round _cur;
                private _cfgMag = configFile >> "CfgMagazines" >> _mag;
                private _max = if (isClass _cfgMag) then { getNumber (_cfgMag >> "count") } else { 0 };
                if (_max <= 0) then { _max = _cur max 1 };
                if (_cur < 0) then { _cur = 0 };
                if (_cur > _max) then { _cur = _max };
                private _dn = if (isClass _cfgMag) then { getText (_cfgMag >> "displayName") } else { "" };
                if (_dn == "") then { _dn = _mag };
                private _row = _ammoLb lbAdd format ["%1 (%2) — %3/%4", _dn, _mag, _cur, _max];
                _ammoLb lbSetData [_row, str [_mag, _cur, _max]];
            };
        };
    } forEach _magState;

    private _pyMags = getPylonMagazines _veh;
    for "_i" from 0 to ((count _pyMags) - 1) do {
        private _mag = _pyMags select _i;
        if (_mag != "") then {
            private _cur = _veh ammoOnPylon _i;
            if (!(_cur isEqualType 0)) then { _cur = 0 };
            _cur = round _cur;
            private _cfgMag = configFile >> "CfgMagazines" >> _mag;
            private _max = if (isClass _cfgMag) then { getNumber (_cfgMag >> "count") } else { 0 };
            if (_max <= 0) then { _max = _cur max 1 };
            if (_cur < 0) then { _cur = 0 };
            if (_cur > _max) then { _cur = _max };
            private _dn = if (isClass _cfgMag) then { getText (_cfgMag >> "displayName") } else { "" };
            if (_dn == "") then { _dn = _mag };
            private _row = _ammoLb lbAdd format ["Pylon %1: %2 (%3) — %4/%5", _i + 1, _dn, _mag, _cur, _max];
            _ammoLb lbSetData [_row, str ["PYLON", _i, _mag, _cur, _max]];
        };
    };
};

FAC_vehicleGui_isHelipadOccupied = {
    params ["_padObj", ["_r", 10]];
    private _pos = getPosATL _padObj;
    count (nearestObjects [_pos, ["Air", "LandVehicle"], _r] select { alive _x }) > 0
};

// Eden varName (e.g. HP_1) -> UI label (e.g. "Pad 1"). Empty varName uses 1-based pad index when provided.
FAC_vehicleGui_spawnLocationDisplayName = {
    params ["_eden", ["_padIndex", -1]];
    if (_eden == "") exitWith {
        if (_padIndex >= 0) then { format ["Pad %1", _padIndex + 1] } else { "Pad" }
    };
    if ((_eden find "HP_") == 0) then {
        private _s = _eden select [3];
        if (_s != "") then {
            private _n = parseNumber _s;
            if (_s isEqualTo "0" || {_n > 0}) exitWith { format ["Pad %1", _n] };
        };
    };
    if ((_eden find "VEH_") == 0) then {
        private _s = _eden select [4];
        if (_s != "") then {
            private _n = parseNumber _s;
            if (_s isEqualTo "0" || {_n > 0}) exitWith { format ["Vehicle spawn %1", _n] };
        };
    };
    _eden
};

FAC_vehicleGui_fnc = {
    params ["_action", "_params"];

    switch _action do {
        case "open": {
            if !(["FAC_playerCanUseVehicleGui"] call FAC_lobbyParams_callAccess) exitWith {
                systemChat "Vehicle GUI access denied by lobby settings.";
            };
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

        case "onLoadVehicle": {
            uinamespace setVariable ["FAC_vehicleGui_fnc", FAC_vehicleGui_fnc];
            private _display = displayNull;
            if (!isNil "_params" && { count _params > 0 }) then {
                private _p0 = _params select 0;
                if (_p0 isEqualType displayNull) then { _display = _p0 };
            };
            if (isNull _display) then { _display = findDisplay FAC_vehicleGui_IDD };
            if (isNull _display) exitWith {};
            missionNamespace setVariable ["FAC_vehicleGui_deleteWreckPending", -99];
            missionNamespace setVariable ["FAC_vehicleGui_deleteWreckConfirmGen", 0];
            [] call FAC_vehicleGui_resetDeleteWreckButton;
            if (isNil "FAC_vehicleGui_whitelistAircraft") then {
                missionNamespace setVariable ["FAC_vehicleGui_whitelistAircraft", true];
            };
            // Tab visibility first (config has manage controls show=0; setTab enforces spawn vs manage).
            missionNamespace setVariable ["FAC_vehicleGui_spawnCategory", "aircraft"];
            ["setTab", ["new"]] call FAC_vehicleGui_fnc;
            ["spawnCategoryChanged", []] call FAC_vehicleGui_fnc;
            ["refreshSpawned", []] call FAC_vehicleGui_fnc;
        };

        case "deleteWrecks": {
            private _display = findDisplay FAC_vehicleGui_IDD;
            if (isNull _display) exitWith {};
            private _btn = _display displayCtrl 61004;
            if (isNull _btn) exitWith {};
            private _pendingAt = missionNamespace getVariable ["FAC_vehicleGui_deleteWreckPending", -99];
            if (time - _pendingAt > 3) then {
                private _confirmGen = (missionNamespace getVariable ["FAC_vehicleGui_deleteWreckConfirmGen", 0]) + 1;
                missionNamespace setVariable ["FAC_vehicleGui_deleteWreckConfirmGen", _confirmGen];
                missionNamespace setVariable ["FAC_vehicleGui_deleteWreckPending", time];
                _btn ctrlSetText "Are you sure?";
                _btn ctrlSetTextColor [1, 0.35, 0.35, 1];
                _btn ctrlSetBackgroundColor [0.22, 0.10, 0.10, 1];
                [_confirmGen] spawn {
                    params ["_gen"];
                    sleep 3;
                    if ((missionNamespace getVariable ["FAC_vehicleGui_deleteWreckConfirmGen", 0]) != _gen) exitWith {};
                    if ((time - (missionNamespace getVariable ["FAC_vehicleGui_deleteWreckPending", -99])) > 3) then {
                        missionNamespace setVariable ["FAC_vehicleGui_deleteWreckPending", -99];
                        if (!isNull (findDisplay FAC_vehicleGui_IDD)) then {
                            [] call FAC_vehicleGui_resetDeleteWreckButton;
                        };
                    };
                };
            } else {
                missionNamespace setVariable ["FAC_vehicleGui_deleteWreckConfirmGen", (missionNamespace getVariable ["FAC_vehicleGui_deleteWreckConfirmGen", 0]) + 1];
                missionNamespace setVariable ["FAC_vehicleGui_deleteWreckPending", -99];
                [] call FAC_vehicleGui_resetDeleteWreckButton;
                [player] remoteExec ["FADE_deleteWrecksNearVehicleTerminal", 2];
                systemChat "Requesting wreck cleanup...";
                [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
            };
        };

        case "headerRefresh": {
            private _tab = missionNamespace getVariable ["FAC_vehicleGui_tab", "new"];
            if (_tab == "new") then {
                ["spawnRefreshPads", []] call FAC_vehicleGui_fnc;
            } else {
                ["refreshSpawned", []] call FAC_vehicleGui_fnc;
                ["manageVehicleSel", []] call FAC_vehicleGui_fnc;
            };
        };

        case "setTab": {
            _params params [["_tab", "new"]];
            missionNamespace setVariable ["FAC_vehicleGui_tab", _tab];
            private _d = findDisplay FAC_vehicleGui_IDD;
            if (isNull _d) exitWith {};
            private _isNew = (_tab == "new");
            {
                private _c = _d displayCtrl _x;
                if (!isNull _c) then { _c ctrlShow _isNew };
            } forEach FAC_vehicleGui_spawnContentIdcs;
            {
                private _c = _d displayCtrl _x;
                if (!isNull _c) then { _c ctrlShow (!_isNew) };
            } forEach FAC_vehicleGui_manageContentIdcs;
            private _panel = _d displayCtrl 61901;
            if (!isNull _panel) then { _panel ctrlShow true };
            [] call FAC_vehicleGui_syncHeaderTabs;
            if (_isNew) then {
                [] call FAC_vehicleGui_syncSpawnCategoryButtons;
                [] call FAC_vehicleGui_syncWhitelistSpawnControl;
                ["spawnRefreshPads", []] call FAC_vehicleGui_fnc;
            } else {
                ["refreshSpawned", []] call FAC_vehicleGui_fnc;
                ["manageVehicleSel", []] call FAC_vehicleGui_fnc;
            };
        };

        case "spawnCategorySet": {
            _params params [["_cat", "aircraft"]];
            if !(_cat in ["aircraft", "land"]) then { _cat = "aircraft" };
            missionNamespace setVariable ["FAC_vehicleGui_spawnCategory", _cat];
            [] call FAC_vehicleGui_syncSpawnCategoryButtons;
            ["spawnCategoryChanged", []] call FAC_vehicleGui_fnc;
        };

        case "spawnWhitelistClick": {
            private _cur = missionNamespace getVariable ["FAC_vehicleGui_whitelistAircraft", true];
            missionNamespace setVariable ["FAC_vehicleGui_whitelistAircraft", !_cur];
            ["spawnCategoryChanged", []] call FAC_vehicleGui_fnc;
        };

        case "manageRefreshDetailsOnly": {
            private _display = findDisplay FAC_vehicleGui_IDD;
            if (isNull _display) exitWith {};
            private _lb = _display displayCtrl 61200;
            private _idx = lbCurSel _lb;
            if (_idx < 0) exitWith {};
            private _varName = _lb lbData _idx;
            if (_varName == "") exitWith {};
            private _obj = missionNamespace getVariable [_varName, objNull];
            if (isNull _obj || {!alive _obj}) exitWith {};
            [_display, typeOf _obj] call FAC_vehicleGui_manageFillManageDetails;
        };

        case "manageRefreshStatus": {
            ["manageRefreshDetailsOnly", []] call FAC_vehicleGui_fnc;
            ["manageSyncServicePanels", [false]] call FAC_vehicleGui_fnc;
        };

        case "manageVehicleSel": {
            private _display = findDisplay FAC_vehicleGui_IDD;
            if (isNull _display) exitWith {};
            private _lb = _display displayCtrl 61200;
            private _idx = lbCurSel _lb;
            private _pic = _display displayCtrl 61210;
            private _details = _display displayCtrl 61211;
            if (_idx < 0) exitWith {
                _pic ctrlSetText "";
                [_display, ""] call FAC_vehicleGui_manageFillManageDetails;
                ["manageSyncServicePanels", [true]] call FAC_vehicleGui_fnc;
                ["manageUpdateButtons", []] call FAC_vehicleGui_fnc;
            };
            private _varName = _lb lbData _idx;
            private _obj = missionNamespace getVariable [_varName, objNull];
            if (isNull _obj || {!alive _obj}) exitWith {
                _pic ctrlSetText "";
                [_details, "Vehicle no longer exists."] call FAC_vehicleGui_setDetailsList;
                ["manageSyncServicePanels", [true]] call FAC_vehicleGui_fnc;
                ["manageUpdateButtons", []] call FAC_vehicleGui_fnc;
            };
            private _cls = typeOf _obj;
            private _cfgVeh = configFile >> "CfgVehicles" >> _cls;
            private _texture = getText (_cfgVeh >> "editorPreview");
            if (_texture == "") then { _texture = getText (_cfgVeh >> "picture") };
            if (_texture == "") then { _texture = getText (_cfgVeh >> "icon") };
            if (_texture != "") then { _pic ctrlSetText _texture } else { _pic ctrlSetText "" };
            [_display, _cls] call FAC_vehicleGui_manageFillManageDetails;
            ["manageSyncServicePanels", [true]] call FAC_vehicleGui_fnc;
            ["manageUpdateButtons", []] call FAC_vehicleGui_fnc;
        };

        case "manageSyncServicePanels": {
            private _forceAmmoRebuild = _params param [0, false];
            private _display = findDisplay FAC_vehicleGui_IDD;
            if (isNull _display) exitWith {};
            private _veh = call FAC_vehicleGui_getManageSelectedVehicle;
            private _ammoLb = _display displayCtrl 61220;
            private _ammoSlider = _display displayCtrl 61221;
            private _ammoLabel = _display displayCtrl 61222;
            private _ammoApply = _display displayCtrl 61223;
            private _fuelSlider = _display displayCtrl 61224;
            private _fuelLabel = _display displayCtrl 61225;
            private _fuelApply = _display displayCtrl 61226;
            private _healthSlider = _display displayCtrl 61227;
            private _healthLabel = _display displayCtrl 61228;
            private _healthApply = _display displayCtrl 61229;

            if (isNull _veh || {!alive _veh}) exitWith {
                lbClear _ammoLb;
                _ammoSlider ctrlEnable false;
                _ammoApply ctrlEnable false;
                _fuelSlider ctrlEnable false;
                _fuelApply ctrlEnable false;
                _healthSlider ctrlEnable false;
                _healthApply ctrlEnable false;
                _ammoLabel ctrlSetText "Ammo load: 0 / 0";
                _fuelLabel ctrlSetText "Fuel: 0%";
                _healthLabel ctrlSetText "Health: 0%";
            };

            _fuelSlider ctrlEnable true;
            _fuelApply ctrlEnable true;
            _healthSlider ctrlEnable true;
            _healthApply ctrlEnable true;

            private _prevData = "";
            if (lbCurSel _ammoLb >= 0) then { _prevData = _ammoLb lbData (lbCurSel _ammoLb) };
            if (_forceAmmoRebuild) then {
                [_veh, _ammoLb] call FAC_vehicleGui_rebuildManageAmmoList;
                private _sel = 0;
                if (_prevData != "") then {
                    for "_k" from 0 to (lbSize _ammoLb - 1) do {
                        if ((_ammoLb lbData _k) == _prevData) exitWith { _sel = _k };
                    };
                };
                if (lbSize _ammoLb > 0) then { _ammoLb lbSetCurSel _sel };
            };

            private _fuelPct = round ((fuel _veh) * 100);
            _fuelPct = (_fuelPct max 0) min 100;
            _fuelSlider sliderSetRange [0, 100];
            _fuelSlider sliderSetSpeed [1, 5];
            _fuelSlider sliderSetPosition _fuelPct;
            _fuelLabel ctrlSetText format ["Fuel: %1%%", _fuelPct];

            private _healthPct = round ((1 - (damage _veh)) * 100);
            _healthPct = (_healthPct max 0) min 100;
            _healthSlider sliderSetRange [0, 100];
            _healthSlider sliderSetSpeed [1, 5];
            _healthSlider sliderSetPosition _healthPct;
            _healthLabel ctrlSetText format ["Health: %1%%", _healthPct];

            private _ammoRows = lbSize _ammoLb;
            if (_ammoRows <= 0) then {
                _ammoSlider ctrlEnable false;
                _ammoApply ctrlEnable false;
                _ammoSlider sliderSetRange [0, 1];
                _ammoSlider sliderSetPosition 0;
                _ammoLabel ctrlSetText "Ammo: no turret/pylon slots (use Quick rearm or Configure pylons)";
            } else {
                _ammoSlider ctrlEnable true;
                _ammoApply ctrlEnable true;
                ["manageAmmoSelChanged", []] call FAC_vehicleGui_fnc;
            };
        };

        case "manageAmmoSelChanged": {
            private _display = findDisplay FAC_vehicleGui_IDD;
            if (isNull _display) exitWith {};
            private _ammoLb = _display displayCtrl 61220;
            private _ammoSlider = _display displayCtrl 61221;
            private _ammoLabel = _display displayCtrl 61222;
            private _idx = lbCurSel _ammoLb;
            if (_idx < 0) exitWith {
                _ammoSlider sliderSetRange [0, 1];
                _ammoSlider sliderSetPosition 0;
                _ammoLabel ctrlSetText "Ammo load: 0 / 0";
            };
            private _trip = call compile (_ammoLb lbData _idx);
            private _cur = 0;
            private _max = 1;
            if ((_trip select 0) isEqualTo "PYLON") then {
                _trip params ["_tag", "_pIdx", "_mag", "_c", "_m"];
                _cur = _c;
                _max = _m;
            } else {
                _trip params ["_mag", "_c", "_m"];
                _cur = _c;
                _max = _m;
            };
            if (_max <= 0) then { _max = 1 };
            _ammoSlider sliderSetRange [0, _max];
            _ammoSlider sliderSetSpeed [1, 1];
            _ammoSlider sliderSetPosition _cur;
            _ammoLabel ctrlSetText format ["Ammo load: %1 / %2", _cur, _max];
        };

        case "manageAmmoSliderChanged": {
            private _display = findDisplay FAC_vehicleGui_IDD;
            if (isNull _display) exitWith {};
            private _ammoLb = _display displayCtrl 61220;
            private _ammoSlider = _display displayCtrl 61221;
            private _ammoLabel = _display displayCtrl 61222;
            private _idx = lbCurSel _ammoLb;
            if (_idx < 0) exitWith { _ammoLabel ctrlSetText "Ammo load: 0 / 0" };
            private _trip = call compile (_ammoLb lbData _idx);
            private _max = 1;
            if ((_trip select 0) isEqualTo "PYLON") then {
                _max = _trip param [4, 1];
            } else {
                _max = _trip param [2, 1];
            };
            if (_max <= 0) then { _max = 1 };
            private _pos = round (sliderPosition _ammoSlider);
            if (_pos < 0) then { _pos = 0 };
            if (_pos > _max) then {
                _pos = _max;
                _ammoSlider sliderSetPosition _pos;
            };
            _ammoLabel ctrlSetText format ["Ammo load: %1 / %2", _pos, _max];
        };

        case "manageFuelSliderChanged": {
            private _display = findDisplay FAC_vehicleGui_IDD;
            if (isNull _display) exitWith {};
            private _slider = _display displayCtrl 61224;
            private _label = _display displayCtrl 61225;
            private _pct = round (sliderPosition _slider);
            _pct = (_pct max 0) min 100;
            _label ctrlSetText format ["Fuel: %1%%", _pct];
        };

        case "manageHealthSliderChanged": {
            private _display = findDisplay FAC_vehicleGui_IDD;
            if (isNull _display) exitWith {};
            private _slider = _display displayCtrl 61227;
            private _label = _display displayCtrl 61228;
            private _pct = round (sliderPosition _slider);
            _pct = (_pct max 0) min 100;
            _label ctrlSetText format ["Health: %1%%", _pct];
        };

        case "manageApplyAmmo": {
            private _display = findDisplay FAC_vehicleGui_IDD;
            if (isNull _display) exitWith {};
            private _veh = call FAC_vehicleGui_getManageSelectedVehicle;
            if (isNull _veh || {!alive _veh}) exitWith { systemChat "Select a vehicle first."; };
            private _ammoLb = _display displayCtrl 61220;
            private _idx = lbCurSel _ammoLb;
            if (_idx < 0) exitWith { systemChat "Select an ammo type first."; };
            private _trip = call compile (_ammoLb lbData _idx);
            private _mag = "";
            private _max = 1;
            private _pylonIdx = -1;
            if ((_trip select 0) isEqualTo "PYLON") then {
                _trip params ["_tag", "_pIdx", "_m", "_c", "_mx"];
                _mag = _m;
                _max = _mx;
                _pylonIdx = _pIdx;
            } else {
                _trip params ["_m", "_c", "_mx"];
                _mag = _m;
                _max = _mx;
            };
            if (_max <= 0) then { _max = 1 };
            private _slider = _display displayCtrl 61221;
            private _rounds = round (sliderPosition _slider);
            _rounds = (_rounds max 0) min _max;
            private _ratio = _rounds / _max;
            [_veh, player, "rearm", _ratio, _mag, _pylonIdx] remoteExec ["FADE_serviceVehiclePart", 2];
            systemChat "Requesting ammo load update...";
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };

        case "manageApplyFuel": {
            private _display = findDisplay FAC_vehicleGui_IDD;
            if (isNull _display) exitWith {};
            private _veh = call FAC_vehicleGui_getManageSelectedVehicle;
            if (isNull _veh || {!alive _veh}) exitWith { systemChat "Select a vehicle first."; };
            private _slider = _display displayCtrl 61224;
            private _ratio = (sliderPosition _slider) / 100;
            _ratio = (_ratio max 0) min 1;
            [_veh, player, "refuel", _ratio] remoteExec ["FADE_serviceVehiclePart", 2];
            systemChat "Requesting fuel update...";
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };

        case "manageApplyHealth": {
            private _display = findDisplay FAC_vehicleGui_IDD;
            if (isNull _display) exitWith {};
            private _veh = call FAC_vehicleGui_getManageSelectedVehicle;
            if (isNull _veh || {!alive _veh}) exitWith { systemChat "Select a vehicle first."; };
            private _slider = _display displayCtrl 61227;
            private _health = (sliderPosition _slider) / 100;
            _health = (_health max 0) min 1;
            [_veh, player, "repair", _health] remoteExec ["FADE_serviceVehiclePart", 2];
            systemChat "Requesting health update...";
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };

        case "manageOpenPylons": {
            private _veh = call FAC_vehicleGui_getManageSelectedVehicle;
            if (isNull _veh || {!alive _veh}) exitWith { systemChat "Select a vehicle first."; };
            if (count getAllPylonsInfo _veh <= 0) exitWith { systemChat "Selected vehicle does not support dynamic pylons."; };
            // Vanilla pylon UI must run without our dialog on top (same as Zeus-style configure).
            missionNamespace setVariable ["FAC_vehicleGui_pylonTargetVeh", _veh];
            closeDialog 0;
            [] spawn {
                sleep 0.15;
                private _veh = missionNamespace getVariable ["FAC_vehicleGui_pylonTargetVeh", objNull];
                missionNamespace setVariable ["FAC_vehicleGui_pylonTargetVeh", nil];
                if (isNull _veh || {!alive _veh}) exitWith { systemChat "Vehicle no longer available."; };
                [_veh] call FAC_vehicleGui_tryOpenPylonDialog;
            };
        };

        case "spawnCategoryChanged": {
            private _display = findDisplay FAC_vehicleGui_IDD;
            if (isNull _display) exitWith {};
            private _cat = missionNamespace getVariable ["FAC_vehicleGui_spawnCategory", "aircraft"];
            private _classes = if (_cat == "aircraft") then {
                missionNamespace getVariable ["FADE_heliClasses", []]
            } else {
                missionNamespace getVariable ["FADE_landVehicleClasses", []]
            };

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
            if (_cat == "aircraft") then {
                private _wlOn = missionNamespace getVariable ["FAC_vehicleGui_whitelistAircraft", true];
                private _wl = missionNamespace getVariable ["FADE_aircraftSpawnWhitelist", []];
                if (_wlOn && { count _wl > 0 }) then {
                    _fullList = _fullList select { (_x select 0) in _wl };
                };
            };
            missionNamespace setVariable ["FAC_vehicleGui_fullList", _fullList];

            private _factionIds = [];
            { private _f = _x select 2; if (_f != "" && { !(_f in _factionIds) }) then { _factionIds pushBack _f } } forEach _fullList;
            private _factionPairs = _factionIds apply {
                private _dn = getText (configFile >> "CfgFactionClasses" >> _x >> "displayName");
                if (_dn == "") then { _dn = _x };
                [_dn, _x]
            };
            _factionPairs sort true;
            private _factionList = _display displayCtrl 61101;
            lbClear _factionList;
            private _idx = _factionList lbAdd "All factions";
            _factionList lbSetData [_idx, ""];
            { _x params ["_dn", "_id"]; private _i = _factionList lbAdd _dn; _factionList lbSetData [_i, _id] } forEach _factionPairs;
            if (lbSize _factionList > 0) then { _factionList lbSetCurSel 0 };

            private _searchEdit = _display displayCtrl 61102;
            _searchEdit ctrlSetText "";

            [] call FAC_vehicleGui_syncWhitelistSpawnControl;
            ["spawnFilterChanged", []] call FAC_vehicleGui_fnc;
        };

        case "spawnFilterChanged": {
            private _display = findDisplay FAC_vehicleGui_IDD;
            if (isNull _display) exitWith {};
            private _fullList = missionNamespace getVariable ["FAC_vehicleGui_fullList", []];
            private _factionList = _display displayCtrl 61101;
            private _searchEdit = _display displayCtrl 61102;
            private _lb = _display displayCtrl 61103;

            private _factionFilter = "";
            if (lbCurSel _factionList >= 0) then { _factionFilter = _factionList lbData (lbCurSel _factionList) };
            private _searchText = toLower (ctrlText _searchEdit);

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
                private _label = format ["'%1' > %2", _factionDn, _name];
                private _i = _lb lbAdd _label;
                _lb lbSetData [_i, _cls];
                private _tip = [_cls] call FAC_vehicleGui_buildVehicleTooltip;
                _lb lbSetTooltip [_i, if (_tip != "") then { _tip } else { format ["Class: %1", _cls] }];
            } forEach _filtered;
            if (lbSize _lb > 0) then { _lb lbSetCurSel 0 };
            ["spawnVehicleSel", []] call FAC_vehicleGui_fnc;
        };

        case "spawnVehicleSel": {
            private _display = findDisplay FAC_vehicleGui_IDD;
            if (isNull _display) exitWith {};
            private _lb = _display displayCtrl 61103;
            private _idx = lbCurSel _lb;
            private _pic = _display displayCtrl 61104;
            private _details = _display displayCtrl 61105;
            if (_idx < 0) exitWith {
                _pic ctrlSetText "";
                [_details, ""] call FAC_vehicleGui_setDetailsList;
            };
            private _class = _lb lbData _idx;
            private _cfgVeh = configFile >> "CfgVehicles" >> _class;
            private _texture = getText (_cfgVeh >> "editorPreview");
            if (_texture == "") then { _texture = getText (_cfgVeh >> "picture") };
            if (_texture == "") then { _texture = getText (_cfgVeh >> "icon") };
            if (_texture != "") then { _pic ctrlSetText _texture } else { _pic ctrlSetText "" };
            [_details, [_class] call FAC_vehicleGui_buildVehicleDetailsPlain] call FAC_vehicleGui_setDetailsList;
            ["spawnRefreshPads", []] call FAC_vehicleGui_fnc;
        };

        case "spawnPadSel": {
            ["spawnUpdateSpawnButton", []] call FAC_vehicleGui_fnc;
        };

        case "spawnRefreshPads": {
            private _display = findDisplay FAC_vehicleGui_IDD;
            if (isNull _display) exitWith {};
            private _cat = missionNamespace getVariable ["FAC_vehicleGui_spawnCategory", "aircraft"];
            private _lbVeh = _display displayCtrl 61103;
            private _idxV = lbCurSel _lbVeh;
            private _class = if (_idxV >= 0) then { _lbVeh lbData _idxV } else { "" };
            private _isPlane = _class != "" && { _class isKindOf "Plane" };
            private _forbidden = missionNamespace getVariable ["FADE_planeForbiddenPads", []];
            private _padLb = _display displayCtrl 61106;
            private _prevSel = lbCurSel _padLb;
            private _prevData = if (_prevSel >= 0) then { _padLb lbData _prevSel } else { "-1" };
            lbClear _padLb;

            if (_cat == "aircraft") then {
                private _helipads = missionNamespace getVariable ["FADE_helipads", []];
                private _iAuto = _padLb lbAdd "Auto — first available pad";
                _padLb lbSetData [_iAuto, "-1"];
                {
                    private _padObj = _x;
                    private _eden = vehicleVarName _padObj;
                    private _disp = [_eden, _forEachIndex] call FAC_vehicleGui_spawnLocationDisplayName;
                    private _occ = [_padObj, 10] call FAC_vehicleGui_isHelipadOccupied;
                    private _badPlane = _isPlane && { _eden in _forbidden };
                    private _suffix = if (_badPlane) then {
                        " — NO PLANES"
                    } else {
                        if (_occ) then { " — OCCUPIED" } else { " — empty" }
                    };
                    private _row = _padLb lbAdd (_disp + _suffix);
                    _padLb lbSetData [_row, str _forEachIndex];
                } forEach _helipads;
            } else {
                private _iAuto = _padLb lbAdd "Auto — first clear VEH slot";
                _padLb lbSetData [_iAuto, "-1"];
                private _vehPts = missionNamespace getVariable ["FADE_vehiclePoints", []];
                {
                    private _ptObj = _x;
                    private _eden = vehicleVarName _ptObj;
                    private _disp = [_eden, _forEachIndex] call FAC_vehicleGui_spawnLocationDisplayName;
                    private _occ = [_ptObj, 9] call FAC_vehicleGui_isHelipadOccupied;
                    private _suffix = if (_occ) then { " — OCCUPIED" } else { " — empty" };
                    private _row = _padLb lbAdd (_disp + _suffix);
                    _padLb lbSetData [_row, str _forEachIndex];
                } forEach _vehPts;
            };

            private _match = -1;
            if (_prevData != "") then {
                for "_k" from 0 to (lbSize _padLb - 1) do {
                    if ((_padLb lbData _k) == _prevData) exitWith { _match = _k };
                };
            };
            if (_match >= 0) then {
                _padLb lbSetCurSel _match;
            } else {
                if (lbSize _padLb > 0) then { _padLb lbSetCurSel 0 };
            };
            ["spawnUpdateSpawnButton", []] call FAC_vehicleGui_fnc;
        };

        case "spawnUpdateSpawnButton": {
            private _display = findDisplay FAC_vehicleGui_IDD;
            if (isNull _display) exitWith {};
            private _spawnBtn = _display displayCtrl 61107;
            private _lbVeh = _display displayCtrl 61103;
            private _padLb = _display displayCtrl 61106;
            private _okVeh = lbSize _lbVeh > 0 && { lbCurSel _lbVeh >= 0 };
            private _cat = missionNamespace getVariable ["FAC_vehicleGui_spawnCategory", "aircraft"];
            private _block = false;
            if (_okVeh && { _cat == "aircraft" }) then {
                private _cls = _lbVeh lbData (lbCurSel _lbVeh);
                if (_cls isKindOf "Plane" && { lbCurSel _padLb >= 0 }) then {
                    private _pIdx = parseNumber (_padLb lbData (lbCurSel _padLb));
                    private _forbidden = missionNamespace getVariable ["FADE_planeForbiddenPads", []];
                    private _helipads = missionNamespace getVariable ["FADE_helipads", []];
                    if (_pIdx >= 0 && {_pIdx < count _helipads}) then {
                        private _eden = vehicleVarName (_helipads select _pIdx);
                        if (_eden in _forbidden) then { _block = true };
                    };
                };
            };
            _spawnBtn ctrlEnable (_okVeh && { !_block });
        };

        case "spawn": {
            if !(["FAC_playerCanUseVehicleGui"] call FAC_lobbyParams_callAccess) exitWith {
                systemChat "Vehicle GUI access denied by lobby settings.";
            };
            private _display = findDisplay FAC_vehicleGui_IDD;
            if (isNull _display) exitWith {};
            private _cat = missionNamespace getVariable ["FAC_vehicleGui_spawnCategory", "aircraft"];
            private _lb = _display displayCtrl 61103;
            private _idx = lbCurSel _lb;
            if (_idx < 0) exitWith { systemChat "Select a vehicle." };
            private _class = _lb lbData _idx;
            private _padLb = _display displayCtrl 61106;
            private _padSel = lbCurSel _padLb;
            if (_padSel < 0) exitWith { systemChat "Select a spawn location." };
            private _padData = _padLb lbData _padSel;
            private _slotIdx = parseNumber _padData;

            private _displayName = getText (configFile >> "CfgVehicles" >> _class >> "displayName");
            if (_displayName == "") then { _displayName = _class };

            if (_cat == "aircraft") then {
                private _forbidden = missionNamespace getVariable ["FADE_planeForbiddenPads", []];
                if (_class isKindOf "Plane" && {_slotIdx >= 0}) then {
                    private _helipads = missionNamespace getVariable ["FADE_helipads", []];
                    if (_slotIdx < count _helipads) then {
                        private _eden = vehicleVarName (_helipads select _slotIdx);
                        if (_eden in _forbidden) exitWith {
                            systemChat "Planes cannot spawn at this pad. Choose another pad or Auto.";
                        };
                    };
                };
                [_class, player, _slotIdx] remoteExec ["FADE_spawnHeli", 2];
                systemChat format ["Requesting spawn: %1...", _displayName];
            } else {
                [_class, player, _slotIdx] remoteExec ["FADE_spawnLandVehicle", 2];
                systemChat format ["Requesting spawn: %1...", _displayName];
            };
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };

        case "despawn": {
            private _display = findDisplay FAC_vehicleGui_IDD;
            if (isNull _display) exitWith {};
            private _spawnedLb = _display displayCtrl 61200;
            private _idx = lbCurSel _spawnedLb;
            if (_idx < 0) exitWith { systemChat "Select a vehicle to despawn." };
            private _varName = _spawnedLb lbData _idx;
            if (_varName == "") exitWith {};
            private _obj = missionNamespace getVariable [_varName, objNull];
            if (isNull _obj) exitWith { systemChat "VEHICLE NO LONGER EXISTS." };
            [_obj, player] remoteExec ["FADE_despawnVehicle", 2];
            systemChat "Requesting despawn...";
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };

        case "duplicate": {
            private _veh = call FAC_vehicleGui_getManageSelectedVehicle;
            if (isNull _veh || {!alive _veh}) exitWith { systemChat "Select a vehicle to duplicate." };
            [_veh, player] remoteExec ["FADE_duplicateVehicleAtBase", 2];
            systemChat "Requesting duplicate spawn...";
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };

        case "servicePart": {
            _params params [["_part", ""], ["_ratio", -1], ["_mag", ""]];
            private _display = findDisplay FAC_vehicleGui_IDD;
            if (isNull _display) exitWith {};
            private _spawnedLb = _display displayCtrl 61200;
            private _idx = lbCurSel _spawnedLb;
            if (_idx < 0) exitWith { systemChat "Select a vehicle in Vehicles at base." };
            private _varName = _spawnedLb lbData _idx;
            if (_varName == "") exitWith {};
            private _obj = missionNamespace getVariable [_varName, objNull];
            if (isNull _obj) exitWith { systemChat "VEHICLE NO LONGER EXISTS." };
            private _msg = switch (toLower _part) do {
                case "repair": { "Requesting repair..." };
                case "refuel": { "Requesting refuel..." };
                case "rearm": { "Requesting rearm..." };
                default { "Requesting service..." };
            };
            systemChat _msg;
            [_obj, player, toLower _part, _ratio, _mag] remoteExec ["FADE_serviceVehiclePart", 2];
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };

        case "refreshSpawned": {
            private _d = findDisplay FAC_vehicleGui_IDD;
            if (isNull _d) exitWith {};
            [player] remoteExec ["FADE_requestVehiclesAtBase", 2];
        };

        case "receiveSpawned": {
            _params params [["_vehicleData", []]];
            if (isNil "_vehicleData") then { _vehicleData = [] };
            if (_vehicleData isEqualType [] && { count _vehicleData > 0 } && { (_vehicleData select 0) isEqualType objNull }) then {
                _vehicleData = _vehicleData apply { [_x, "Base"] };
            };
            private _disp = findDisplay FAC_vehicleGui_IDD;
            if (isNull _disp) exitWith {};
            private _lb = _disp displayCtrl 61200;
            lbClear _lb;
            {
                _x params ["_veh", "_padName"];
                if (!isNull _veh && { alive _veh }) then {
                    private _cls = typeOf _veh;
                    private _name = getText (configFile >> "CfgVehicles" >> _cls >> "displayName");
                    if (_name == "") then { _name = _cls };
                    private _label = format ["%1 — %2", _name, _padName];
                    private _varName = "FADE_obj_" + (str _veh);
                    missionNamespace setVariable [_varName, _veh];
                    private _idx = _lb lbAdd _label;
                    _lb lbSetData [_idx, _varName];
                    _lb lbSetTooltip [_idx, format ["%1 at %2", _cls, _padName]];
                };
            } forEach _vehicleData;
            if (lbSize _lb > 0) then { _lb lbSetCurSel 0 };
            // Avoid refreshing manage sliders/preview while "New" tab is active (async overlap / flicker).
            if (missionNamespace getVariable ["FAC_vehicleGui_tab", "new"] == "existing") then {
                ["manageVehicleSel", []] call FAC_vehicleGui_fnc;
            };
        };

        case "manageUpdateButtons": {
            private _display = findDisplay FAC_vehicleGui_IDD;
            if (isNull _display) exitWith {};
            private _spawnedLb = _display displayCtrl 61200;
            private _despawnBtn = _display displayCtrl 61202;
            private _dupBtn = _display displayCtrl 61232;
            private _repairBtn = _display displayCtrl 61201;
            private _refuelBtn = _display displayCtrl 61205;
            private _rearmBtn = _display displayCtrl 61206;
            private _pylonsBtn = _display displayCtrl 61230;
            private _ammoApply = _display displayCtrl 61223;
            private _fuelApply = _display displayCtrl 61226;
            private _healthApply = _display displayCtrl 61229;
            private _spawnedSel = lbSize _spawnedLb > 0 && { lbCurSel _spawnedLb >= 0 };
            _despawnBtn ctrlEnable _spawnedSel;
            if (!isNull _dupBtn) then { _dupBtn ctrlEnable _spawnedSel };
            if (!isNull _repairBtn) then { _repairBtn ctrlEnable _spawnedSel };
            if (!isNull _refuelBtn) then { _refuelBtn ctrlEnable _spawnedSel };
            if (!isNull _rearmBtn) then { _rearmBtn ctrlEnable _spawnedSel };
            if (!isNull _ammoApply) then { _ammoApply ctrlEnable _spawnedSel };
            if (!isNull _fuelApply) then { _fuelApply ctrlEnable _spawnedSel };
            if (!isNull _healthApply) then { _healthApply ctrlEnable _spawnedSel };
            if (!isNull _pylonsBtn) then {
                private _pylonOk = false;
                if (_spawnedSel) then {
                    private _varName = _spawnedLb lbData (lbCurSel _spawnedLb);
                    private _obj = missionNamespace getVariable [_varName, objNull];
                    if (!isNull _obj && {alive _obj}) then {
                        _pylonOk = count getAllPylonsInfo _obj > 0;
                    };
                };
                _pylonsBtn ctrlEnable _pylonOk;
                if (_pylonOk) then {
                    _pylonsBtn ctrlSetBackgroundColor [0.52, 0.16, 0.16, 1];
                } else {
                    _pylonsBtn ctrlSetBackgroundColor [0.22, 0.22, 0.26, 1];
                };
            };
        };
    };
};

FADE_receiveVehiclesAtBase = {
    params [["_vehicleData", []]];
    if (isNil "_vehicleData") then { _vehicleData = [] };
    if !(_vehicleData isEqualType []) then { _vehicleData = [] };
    ["receiveSpawned", [_vehicleData]] call FAC_vehicleGui_fnc;
};
