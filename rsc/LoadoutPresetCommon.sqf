// =============================================================================
// LoadoutPresetCommon.sqf  -  shared preset unwrap/normalize (LoadoutGui + server)
// =============================================================================

FAC_loadoutGui_buildPresetEntries = {
    private _preset = missionNamespace getVariable ["FAC_presetLoadouts", []];
    private _out = [];
    {
        _x params ["_eraKey", "_eraDn", "_roles"];
        {
            _x params ["_roleDn", "_loadout"];
            if (_loadout isEqualType [] && {count _loadout > 0}) then {
                private _entryKey = format ["FAC:%1:%2", _eraKey, _forEachIndex];
                _out pushBack [_entryKey, _roleDn, _eraKey, _eraDn, "Preset"];
            };
        } forEach _roles;
    } forEach _preset;
    _out
};

FAC_loadoutGui_normalizePresetLoadoutArray = {
    params ["_lo"];
    if (!(_lo isEqualType [])) exitWith { [] };
    if ((count _lo) > 10) then {
        _lo = _lo select [0, 10];
    };
    _lo
};

FAC_loadoutGui_unwrapPresetLoadoutArray = {
    params ["_lo"];
    if (!(_lo isEqualType [])) exitWith { [] };
    private _d = 0;
    while {
        _d < 12 &&
        { count _lo == 1 } &&
        { (_lo select 0) isEqualType [] }
    } do {
        _lo = _lo select 0;
        _d = _d + 1;
    };
    _lo
};

FAC_loadoutGui_resolvePresetLoadoutArray = {
    params ["_lo"];
    if (!(_lo isEqualType [])) exitWith { [] };
    _lo = [_lo] call FAC_loadoutGui_unwrapPresetLoadoutArray;
    if ((count _lo) == 2) then {
        private _pick = [];
        {
            if (_x isEqualType [] && { count _pick == 0 }) then {
                private _c = [_x] call FAC_loadoutGui_unwrapPresetLoadoutArray;
                if ((count _c) >= 10) then {
                    _pick = _c;
                };
            };
        } forEach [_lo select 0, _lo select 1];
        if ((count _pick) >= 10) then {
            _lo = _pick;
        };
    };
    _lo = [_lo] call FAC_loadoutGui_unwrapPresetLoadoutArray;
    [_lo] call FAC_loadoutGui_normalizePresetLoadoutArray
};

FAC_loadoutGui_getPresetLoadoutByKey = {
    params ["_key"];
    if ((_key find "FAC:") != 0) exitWith { [] };
    private _parts = _key splitString ":";
    if ((count _parts) < 3) exitWith { [] };
    private _eraKey = _parts select 1;
    private _idx = parseNumber (_parts select 2);
    private _preset = missionNamespace getVariable ["FAC_presetLoadouts", []];
    private _out = [];
    {
        _x params ["_k", "_eraDn", "_roles"];
        if (_k == _eraKey) exitWith {
            if (_idx >= 0 && {_idx < count _roles}) then {
                _out = (_roles select _idx) select 1;
            };
        };
    } forEach _preset;
    [_out] call FAC_loadoutGui_resolvePresetLoadoutArray
};

FAC_loadoutGui_ensurePresetData = {
    if (!((missionNamespace getVariable ["FAC_presetLoadouts", []]) isEqualTo [])) exitWith { true };
    call compile preprocessFileLineNumbers "rsc\PresetLoadouts.sqf";
    !((missionNamespace getVariable ["FAC_presetLoadouts", []]) isEqualTo [])
};

FAC_loadoutGui_getLoadoutFromClass = {
    params ["_class", ["_grpSide", sideUnknown]];
    if (_grpSide isEqualTo sideUnknown) then {
        if (isNull player) exitWith { [] };
        _grpSide = side player;
    };
    if (_class == "" || { !isClass (configFile >> "CfgVehicles" >> _class) }) exitWith { [] };

    private _grp = createGroup [_grpSide, true];
    private _tmp = objNull;
    private _loadout = [];

    _tmp = _grp createUnit [_class, [0,0,0], [], 0, "CAN_COLLIDE"];
    if (!isNull _tmp) then {
        _tmp hideObject true;
        _tmp allowDamage false;
        _tmp enableSimulation false;
        _loadout = getUnitLoadout _tmp;
        deleteVehicle _tmp;
    };
    deleteGroup _grp;

    _loadout
};

FAC_loadoutGui_getCfgRoleTraits = {
    params ["_class"];
    if (_class == "" || { !isClass (configFile >> "CfgVehicles" >> _class) }) exitWith { [0, false, false] };
    private _cfg = configFile >> "CfgVehicles" >> _class;
    [
        getNumber (_cfg >> "attendant"),
        getNumber (_cfg >> "engineer") > 0,
        getNumber (_cfg >> "canDeactivateMines") > 0
    ]
};

FAC_loadoutGui_getPresetRoleTraits = {
    params ["_roleDn"];
    private _medic = 0;
    private _eng = false;
    private _exp = false;
    if (_roleDn == "Medic") then {
        _medic = missionNamespace getVariable ["FAC_loadoutGui_presetMedicTraitLevel", 2];
    };
    if (_roleDn == "Engineer") then {
        _eng = true;
        _exp = true;
    };
    if (_roleDn == "Demolition") then {
        _exp = true;
    };
    [_medic, _eng, _exp]
};
