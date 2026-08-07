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

// Eden Inventory exports use [[weapon]] per slot; ACE/Crusty presets use flat ["class",...].
// Flatten single-weapon wrappers so setUnitLoadout matches working preset shape.
FAC_loadoutGui_flattenPresetWeaponSlot = {
    params ["_slot"];
    if (!(_slot isEqualType [])) exitWith { [] };
    if ((count _slot) == 0) exitWith { [] };
    if ((_slot select 0) isEqualType "") exitWith { _slot };
    if (
        { (count _slot) == 1 } &&
        { (_slot select 0) isEqualType [] } &&
        { count (_slot select 0) > 0 } &&
        { ((_slot select 0) select 0) isEqualType "" }
    ) exitWith {
        _slot select 0
    };
    _slot
};

// Crusty/ACE presets use [class, [cargo]]; Eden import uses [class, [items], [mags]].
FAC_loadoutGui_flattenPresetContainerSlot = {
    params ["_slot"];
    if (!(_slot isEqualType []) || { count _slot < 2 }) exitWith { _slot };
    if ((count _slot) == 2) exitWith { _slot };
    if ((count _slot) >= 3 && { (_slot select 0) isEqualType "" }) exitWith {
        private _items = _slot select 1;
        private _mags = _slot select 2;
        if (!(_items isEqualType [])) then { _items = [] };
        if (!(_mags isEqualType [])) then { _mags = [] };
        [_slot select 0, _items + _mags]
    };
    _slot
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
    _lo = [_lo] call FAC_loadoutGui_normalizePresetLoadoutArray;
    {
        _lo set [_x, [_lo select _x] call FAC_loadoutGui_flattenPresetWeaponSlot];
    } forEach [0, 1, 2, 8];
    {
        _lo set [_x, [_lo select _x] call FAC_loadoutGui_flattenPresetContainerSlot];
    } forEach [3, 4, 5];
    _lo
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
    if (!((missionNamespace getVariable ["FAC_presetLoadouts", []]) isEqualTo [])) exitWith {
        // #region agent log
        diag_log format ["[FAC DBG 6df0b3] H-A ensurePresetData alreadyLoaded eras=%1", count (missionNamespace getVariable ["FAC_presetLoadouts", []])];
        // #endregion
        true
    };
    // #region agent log
    diag_log "[FAC DBG 6df0b3] H-A ensurePresetData compiling PresetLoadouts.sqf";
    // #endregion
    private _pre = preprocessFileLineNumbers "rsc\PresetLoadouts.sqf";
    // #region agent log
    diag_log format ["[FAC DBG 6df0b3] H-B ensurePresetData preprocess len=%1 empty=%2", count _pre, (_pre isEqualTo "")];
    // #endregion
    call compile _pre;
    private _eras = missionNamespace getVariable ["FAC_presetLoadouts", []];
    private _ok = !(_eras isEqualTo []);
    // #region agent log
    private _eraKeys = [];
    { if (_x isEqualType [] && { count _x > 0 }) then { _eraKeys pushBack (_x select 0) }; } forEach _eras;
    diag_log format ["[FAC DBG 6df0b3] H-A/C ensurePresetData done ok=%1 eras=%2 keys=%3", _ok, count _eras, _eraKeys];
    // #endregion
    _ok
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
    if (_roleDn == "Medic" || { _roleDn find "Medic" >= 0 }) then {
        _medic = missionNamespace getVariable ["FAC_loadoutGui_presetMedicTraitLevel", 2];
    };
    if (_roleDn == "Engineer" || { _roleDn find "Engineer" >= 0 }) then {
        _eng = true;
        _exp = true;
    };
    if (_roleDn == "Demolition" || { _roleDn find "Breacher" >= 0 }) then {
        _exp = true;
        if (_roleDn find "Breacher" >= 0) then { _eng = true };
    };
    [_medic, _eng, _exp]
};

// Server-side strip + apply (recruited AI, med training dummies, etc.).
FAC_loadoutGui_stripUnitForLoadoutServer = {
    params [["_u", objNull]];
    if (isNull _u || {!alive _u}) exitWith {};
    { _u removeMagazine _x } forEach (magazines _u);
    removeAllWeapons _u;
    removeAllAssignedItems _u;
    removeUniform _u;
    removeVest _u;
    removeBackpack _u;
    removeHeadgear _u;
    removeGoggles _u;
};

FAC_loadoutGui_syncRoleTraitsServer = {
    params ["_u", "_medic", "_engineer", "_explosive"];
    if (isNull _u || {!alive _u}) exitWith {};
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

FAC_loadoutGui_applyLoadoutToUnitServer = {
    params [["_u", objNull], ["_loadout", []], ["_medic", 0], ["_engineer", false], ["_explosive", false]];
    if (isNull _u || {!alive _u}) exitWith { false };
    if (!(_loadout isEqualType []) || { (count _loadout) < 10 }) exitWith { false };
    private _norm = [_loadout] call FAC_loadoutGui_resolvePresetLoadoutArray;
    if ((count _norm) < 10) exitWith { false };
    [_u] call FAC_loadoutGui_stripUnitForLoadoutServer;
    _u setUnitLoadout _norm;
    [_u, _medic, _engineer, _explosive] call FAC_loadoutGui_syncRoleTraitsServer;
    true
};
