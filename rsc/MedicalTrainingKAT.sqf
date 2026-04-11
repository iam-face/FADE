// =============================================================================
// MedicalTrainingKAT.sqf — medical training injury application (ACE Medical + KAM / KAT)
// Server-only (compile from initServer). Mission assumes both stacks are loaded.
// =============================================================================

if (!isServer) exitWith {};

// Preset keys + display labels (GUI + mission)
FAC_medKAT_scenarioList = [
    ["minor_bleed", "Minor bleed"],
    ["moderate_bleed", "Moderate bleed"],
    ["massive_bleed", "Massive bleed"],
    ["catastrophic_bleed", "Catastrophic bleed"],
    ["airway_obstruction", "Airway obstruction"],
    ["airway_occlusion", "Airway occlusion"],
    ["airway_vomit", "Airway (vomit / occlusion)"],
    ["bloodloss", "Hypovolemia (blood loss)"],
    ["deep_penetrating", "Deep penetrating chest"],
    ["cardiac_vt", "Cardiac — VT"],
    ["cardiac_vf", "Cardiac — VF"],
    ["cardiac_pea", "Cardiac — PEA"],
    ["cardiac_asystole", "Cardiac — Asystole"],
    ["fracture_simple", "Fracture — simple (random part)"],
    ["fracture_compound", "Fracture — compound (random part)"],
    ["fracture_comminuted", "Fracture — comminuted (random part)"]
];

// ACE/KAT surgery fracture array order (matches ALL_BODY_PARTS).
FAC_medKAT_fracturePartOrder = ["head", "body", "leftarm", "rightarm", "leftleg", "rightleg"];

FAC_medKAT_bodyPartsLower = ["head", "body", "leftarm", "rightarm", "leftleg", "rightleg"];
FAC_medKAT_woundTypes = ["Laceration", "VelocityWound", "Avulsion"];

// Medical training terminal: inert AI, no weapons / headgear / facewear (ANIM left enabled for injury/unconscious anims).
FAC_medKAT_fnc_configureTrainingDummy = {
    params ["_u"];
    if (isNull _u) exitWith {};
    {
        _u disableAI _x;
    } forEach [
        "MOVE", "PATH", "TARGET", "AUTOTARGET", "AUTOCOMBAT",
        "COVER", "SUPPRESSION", "FSM", "WEAPONAIM", "AIMINGERROR",
        "CHECKVISIBLE", "RADIOPROTOCOL", "TEAMSWITCH", "NVG", "MINEDETECTION"
    ];
    private _g = group _u;
    if (!isNull _g) then {
        _g allowFleeing 0;
        _g setCombatMode "BLUE";
    };
    _u setCombatMode "BLUE";
    removeAllWeapons _u;
    removeHeadgear _u;
    removeGoggles _u;
};

// Uniform-only strip for training dummies: no vest/backpack/assigned gear (NVG, etc.).
FAC_medKAT_fnc_stripToUniformOnly = {
    params ["_u"];
    if (isNull _u) exitWith {};
    removeVest _u;
    removeBackpack _u;
    removeAllAssignedItems _u;
    removeAllItems _u;
};

// KAM surgery: 1 = simple, 2 = compound, 3 = comminuted (see KAM fnc_fullHealLocal header).
FAC_medKAT_fnc_applyFractureSeverity = {
    params ["_unit", "_partLower", "_severity"];
    if (isNull _unit || {!alive _unit}) exitWith {};
    private _order = missionNamespace getVariable ["FAC_medKAT_fracturePartOrder", ["head", "body", "leftarm", "rightarm", "leftleg", "rightleg"]];
    private _idx = _order find (toLower _partLower);
    if (_idx < 0) exitWith {};
    private _sev = ((round _severity) max 1) min 3;
    if (!isClass (configFile >> "CfgPatches" >> "kat_surgery")) exitWith {};
    if (local _unit) then {
        [_unit, _idx, _sev] call FAC_medKAT_fnc_setFractureAtIndexLocal;
    } else {
        [_unit, _idx, _sev] remoteExecCall ["FAC_medKAT_fnc_setFractureAtIndexLocal", _unit];
    };
};

FAC_medKAT_fnc_addBleedWounds = {
    params ["_unit", "_nW", "_bleedLo", "_bleedHi", "_parts", "_wtypes"];
    if (isNull _unit || {!alive _unit}) exitWith {};
    for "_k" from 1 to _nW do {
        private _part = selectRandom _parts;
        private _wt = selectRandom _wtypes;
        private _bl = _bleedLo + random (_bleedHi - _bleedLo);
        private _depth = (floor random 3) max 1;
        private _wArr = [_wt, 1, _depth, _bl];
        if (local _unit) then {
            [_unit, _part, _wArr] call ace_medical_fnc_addWound;
        } else {
            [_unit, _part, _wArr] remoteExecCall ["ace_medical_fnc_addWound", _unit];
        };
    };
};

FAC_medKAT_fnc_setBodyFluidLiters = {
    params ["_unit", "_liters"];
    private _bf = +(_unit getVariable ["kat_circulation_bodyFluid", [2700, 3300, 500, 10000, 6000]]);
    _bf set [4, (_liters * 1000) max 800];
    _unit setVariable ["kat_circulation_bodyFluid", _bf, true];
    _unit setVariable ["ace_medical_bloodVolume", _liters, true];
};

// KAM Zeus "Change Cardiac State" parity (CBA targetEvent on patient machine).
FAC_medKAT_applyCardiacRhythm = {
    params ["_unit", "_state"];
    if (isNull _unit || {!alive _unit}) exitWith {};
    _state = (round _state) max 0 min 4;
    private _cur = _unit getVariable ["kat_circulation_cardiacArrestType", 0];
    _unit setVariable ["kat_circulation_cardiacArrestType", _state, true];
    if (_state isEqualTo 0) then {
        ["ace_medical_CPRSucceeded", [_unit], _unit] call CBA_fnc_targetEvent;
    } else {
        if (_state > 0 && {_cur isEqualTo 0}) then {
            ["ace_medical_fatalVitals", [_unit], _unit] call CBA_fnc_targetEvent;
        };
    };
};

FAC_medKAT_fnc_cardiacArrest = {
    params ["_unit", "_rhythm", "_hasUncon"];
    [_unit, _rhythm] call FAC_medKAT_applyCardiacRhythm;
    if (_hasUncon && { alive _unit && !(_unit getVariable ["ACE_isUnconscious", false]) }) then {
        [_unit, true, 1800, false] call ace_medical_fnc_setUnconscious;
    };
};

// KAM Zeus "Manage Airways" confirm parity: variables + BP/pain/PTX deterioration/internal bleed.
FAC_medKAT_applyAirwayChestZeus = {
    params ["_unit", "_obstruction", "_occluded", "_hemo", "_tension", "_ptxIn", "_paO2Slider", "_runDeterioration", "_deepPen"];
    if (isNull _unit || {!alive _unit}) exitWith {};
    private _valueArr = [_obstruction, _occluded, _hemo, _tension];
    private _keys = [
        "kat_airway_obstruction",
        "kat_airway_occluded",
        "kat_breathing_hemopneumothorax",
        "kat_breathing_tensionpneumothorax"
    ];
    { _unit setVariable [_x, _valueArr select _forEachIndex, true] } forEach _keys;

    private _pneumothorax = round ((_ptxIn max 0) min 4);
    private _o2Sat = round ((_paO2Slider max 0) min 100);
    private _bloodGas = +(_unit getVariable ["kat_circulation_bloodGas", [40, 90, 0.96, 24, 7.4, 37]]);
    if (count _bloodGas < 5) then { _bloodGas = [40, 90, 0.96, 24, 7.4, 37] };

    _unit setVariable ["kat_breathing_pneumothorax", _pneumothorax, true];
    _unit setVariable ["kat_circulation_bloodGas", [
        _bloodGas select 0,
        _o2Sat,
        _bloodGas select 2,
        _bloodGas select 3,
        _bloodGas select 4
    ], true];

    if (_pneumothorax isEqualTo 0 && {!(_valueArr select 2)} && {!(_valueArr select 3)}) then {
        [_unit, 0, 0, "ptx_tension", true] call kat_circulation_fnc_updateBloodPressureChange;
    } else {
        [_unit, -12 * _pneumothorax, -12 * _pneumothorax, "ptx_tension", true] call kat_circulation_fnc_updateBloodPressureChange;
        [_unit, 0.5 * (_pneumothorax / 4)] call ace_medical_status_fnc_adjustPainLevel;
    };
    if ((_valueArr select 2) || (_valueArr select 3)) then {
        _unit setVariable ["kat_breathing_pneumothorax", 4, true];
        [_unit, -48, -48, "ptx_tension", true] call kat_circulation_fnc_updateBloodPressureChange;
        [_unit, 0.5] call ace_medical_status_fnc_adjustPainLevel;
    };
    if (_runDeterioration && {_pneumothorax > 0} && {!(_valueArr select 2)} && {!(_valueArr select 3)}) then {
        [_unit] call kat_breathing_fnc_handlePneumothoraxDeterioration;
    };
    [_unit] call kat_circulation_fnc_updateInternalBleeding;
    _unit setVariable ["kat_breathing_deepPenetratingInjury", _deepPen, true];
};

FAC_medKAT_fnc_cardiacThenBleed_spawn = {
    params ["_unit", "_rhythm", "_parts", "_wtypes"];
    [_unit, _rhythm, true] call FAC_medKAT_fnc_cardiacArrest;
    sleep 0.35;
    if (!alive _unit) exitWith {};
    [_unit, 2, 0.08, 0.2, _parts, _wtypes] call FAC_medKAT_fnc_addBleedWounds;
};

// Immediate apply (no leading sleep). Caller supplies scenario string.
FAC_medKAT_fnc_applyScenarioImmediate = {
    params ["_u", "_scenario"];
    if (isNull _u || {!alive _u}) exitWith {};
    private _bodyPartsLower = missionNamespace getVariable ["FAC_medKAT_bodyPartsLower", ["head", "body", "leftarm", "rightarm", "leftleg", "rightleg"]];
    private _woundTypes = missionNamespace getVariable ["FAC_medKAT_woundTypes", ["Laceration", "VelocityWound", "Avulsion"]];
    switch (_scenario) do {
        case "minor_bleed": {
            [ _u, 1 + (floor random 2), 0.12, 0.28, _bodyPartsLower, _woundTypes ] call FAC_medKAT_fnc_addBleedWounds;
        };
        case "moderate_bleed": {
            [ _u, 3 + (floor random 3), 0.32, 0.52, _bodyPartsLower, _woundTypes ] call FAC_medKAT_fnc_addBleedWounds;
            [_u, true, 600, false] call ace_medical_fnc_setUnconscious;
        };
        case "massive_bleed": {
            [ _u, 7 + (floor random 4), 0.58, 0.82, _bodyPartsLower, _woundTypes ] call FAC_medKAT_fnc_addBleedWounds;
            [_u, true, 600, false] call ace_medical_fnc_setUnconscious;
        };
        case "catastrophic_bleed": {
            [ _u, 12 + (floor random 4), 0.85, 1.12, _bodyPartsLower, _woundTypes ] call FAC_medKAT_fnc_addBleedWounds;
            [_u, true, 600, false] call ace_medical_fnc_setUnconscious;
        };
        case "airway_obstruction": {
            _u setVariable ["kat_airway_obstruction", true, true];
            [ _u, 1 + (floor random 2), 0.1, 0.22, _bodyPartsLower, _woundTypes ] call FAC_medKAT_fnc_addBleedWounds;
        };
        case "airway_occlusion": {
            _u setVariable ["kat_airway_occluded", true, true];
            [ _u, 1, 0.1, 0.18, _bodyPartsLower, _woundTypes ] call FAC_medKAT_fnc_addBleedWounds;
        };
        case "airway_vomit": {
            [_u, true, 600, false] call ace_medical_fnc_setUnconscious;
            [_u] call kat_airway_fnc_handlePuking;
            _u setVariable ["kat_airway_occluded", true, true];
            [ _u, 1 + (floor random 2), 0.1, 0.22, _bodyPartsLower, _woundTypes ] call FAC_medKAT_fnc_addBleedWounds;
        };
        case "bloodloss": {
            private _litPick = selectRandom [5.35, 4.85, 4.2, 3.6, 3.05];
            [_u, _litPick] call FAC_medKAT_fnc_setBodyFluidLiters;
            [ _u, 1 + (floor random 2), 0.08, 0.2, _bodyPartsLower, _woundTypes ] call FAC_medKAT_fnc_addBleedWounds;
        };
        case "deep_penetrating": {
            _u setVariable ["kat_breathing_deepPenetratingInjury", true, true];
            [_u, 0.25 + random 0.15, "Body", "bullet", objNull] call ace_medical_fnc_addDamageToUnit;
            if (local _u) then { [_u, "body", ["VelocityWound", 1, 2, 0.45]] call ace_medical_fnc_addWound } else { [_u, "body", ["VelocityWound", 1, 2, 0.45]] remoteExecCall ["ace_medical_fnc_addWound", _u] };
            if (random 1 < 0.5) then { [_u, true, 400, false] call ace_medical_fnc_setUnconscious };
        };
        case "cardiac_vt": { [_u, 4, _bodyPartsLower, _woundTypes] spawn FAC_medKAT_fnc_cardiacThenBleed_spawn };
        case "cardiac_vf": { [_u, 3, _bodyPartsLower, _woundTypes] spawn FAC_medKAT_fnc_cardiacThenBleed_spawn };
        case "cardiac_pea": { [_u, 2, _bodyPartsLower, _woundTypes] spawn FAC_medKAT_fnc_cardiacThenBleed_spawn };
        case "cardiac_asystole": { [_u, 1, _bodyPartsLower, _woundTypes] spawn FAC_medKAT_fnc_cardiacThenBleed_spawn };
        case "fracture_simple": {
            [_u, selectRandom _bodyPartsLower, 1] call FAC_medKAT_fnc_applyFractureSeverity;
        };
        case "fracture_compound": {
            [_u, selectRandom _bodyPartsLower, 2] call FAC_medKAT_fnc_applyFractureSeverity;
        };
        case "fracture_comminuted": {
            [_u, selectRandom _bodyPartsLower, 3] call FAC_medKAT_fnc_applyFractureSeverity;
        };
        default { [ _u, 2, 0.15, 0.3, _bodyPartsLower, _woundTypes ] call FAC_medKAT_fnc_addBleedWounds };
    };
};

// Same as legacy mission: sleep 0.4 then apply (stagger ACE init on fresh unit).
FAC_medKAT_applyScenario = {
    params ["_u", "_scenario"];
    [_u, _scenario] spawn {
        params ["_u", "_scenario"];
        sleep 0.4;
        if (isNull _u || {!alive _u}) exitWith {};
        [_u, _scenario] call FAC_medKAT_fnc_applyScenarioImmediate;
    };
};

// Terminal / explicit apply without delay (unit already settled).
FAC_medKAT_applyScenarioNow = {
    params ["_u", "_scenario"];
    if (isNull _u || {!alive _u}) exitWith {};
    [_u, _scenario] call FAC_medKAT_fnc_applyScenarioImmediate;
};

// Single wound for GUI (fixed depth 2, user bleed 0.1–1.2 scaled).
FAC_medKAT_applyCustomWound = {
    params ["_u", "_part", "_woundType", "_bleed", "_depth"];
    if (isNull _u || {!alive _u}) exitWith {};
    private _p = toLower _part;
    private _d = _depth max 1 min 3;
    private _b = (_bleed max 0.05 min 1.5);
    private _wArr = [_woundType, 1, _d, _b];
    if (local _u) then {
        [_u, _p, _wArr] call ace_medical_fnc_addWound;
    } else {
        [_u, _p, _wArr] remoteExecCall ["ace_medical_fnc_addWound", _u];
    };
};

// KAM vitals + ACE blood baseline after full heal
FAC_medKAT_resetKATVariables = {
    params ["_u"];
    if (isNull _u) exitWith {};
    _u setVariable ["kat_airway_obstruction", false, true];
    _u setVariable ["kat_airway_occluded", false, true];
    _u setVariable ["kat_breathing_hemopneumothorax", false, true];
    _u setVariable ["kat_breathing_tensionpneumothorax", false, true];
    _u setVariable ["kat_breathing_pneumothorax", 0, true];
    _u setVariable ["kat_breathing_deepPenetratingInjury", false, true];
    _u setVariable ["kat_circulation_cardiacArrestType", 0, true];
    _u setVariable ["kat_circulation_bodyFluid", [2700, 3300, 500, 10000, 6000], true];
    _u setVariable ["kat_circulation_bloodGas", [40, 90, 0.96, 24, 7.4, 37], true];
    _u setVariable ["ace_medical_bloodVolume", 6, true];
    if (isClass (configFile >> "CfgPatches" >> "kat_surgery")) then {
        _u setVariable ["kat_surgery_fractures", [0, 0, 0, 0, 0, 0], true];
    };
};

FAC_medKAT_fullHealTrainingUnit = {
    params ["_u"];
    if (isNull _u || {!alive _u}) exitWith {};
    [_u] call FAC_medKAT_resetKATVariables;
    [_u, false, 1, false] call ace_medical_fnc_setUnconscious;
    private _kamHeal = {
        params ["_p"];
        if (!local _p) exitWith {};
        [_p] call kat_breathing_fnc_fullHealLocal;
        [_p] call kat_circulation_fnc_fullHealLocal;
        [_p] call kat_vitals_fnc_fullHealLocal;
    };
    if (local _u) then {
        [_u] call _kamHeal;
    } else {
        [_u] remoteExecCall [_kamHeal, _u];
    };
    if (local _u) then {
        _u call ace_medical_fnc_fullHeal;
    } else {
        [_u] remoteExecCall [{
            (_this select 0) call ace_medical_fnc_fullHeal;
        }, _u];
    };
};

// Best-effort: remove open wounds whose body part matches (ACE Medical openWounds format varies by version).
FAC_medKAT_fnc_tryHealBodyPartLocal = {
    params ["_u", "_part"];
    if (!local _u || {isNull _u} || {!alive _u}) exitWith {};
    private _want = toLower _part;
    private _fIdx = (missionNamespace getVariable ["FAC_medKAT_fracturePartOrder", ["head", "body", "leftarm", "rightarm", "leftleg", "rightleg"]]) find _want;
    if (_fIdx >= 0 && { isClass (configFile >> "CfgPatches" >> "kat_surgery") }) then {
        private _fa = +(_u getVariable ["kat_surgery_fractures", [0, 0, 0, 0, 0, 0]]);
        if ((count _fa) >= 6 && { (_fa select _fIdx) != 0 }) then {
            _fa set [_fIdx, 0];
            _u setVariable ["kat_surgery_fractures", _fa, true];
        };
    };
    private _ow = _u getVariable ["ace_medical_openWounds", []];
    if (_ow isEqualType [] && {count _ow > 0}) then {
        private _kept = [];
        {
            if (!(_x isEqualType [])) then { _kept pushBack _x; continue };
            private _sel = "";
            if (count _x > 0) then {
                _sel = if ((_x select 0) isEqualType "") then { toLower (_x select 0) } else { "" };
            };
            if (_sel != _want) then { _kept pushBack _x };
        } forEach _ow;
        if ((count _kept) < (count _ow)) then {
            _u setVariable ["ace_medical_openWounds", _kept, true];
        };
    };
};

FAC_medKAT_healBodyPart = {
    params ["_u", "_part"];
    if (isNull _u || {!alive _u}) exitWith {};
    private _healCode = {
        params ["_u", "_p"];
        if (!local _u || {isNull _u} || {!alive _u}) exitWith {};
        private _want = toLower _p;
        private _fIdx = (missionNamespace getVariable ["FAC_medKAT_fracturePartOrder", ["head", "body", "leftarm", "rightarm", "leftleg", "rightleg"]]) find _want;
        if (_fIdx >= 0 && { isClass (configFile >> "CfgPatches" >> "kat_surgery") }) then {
            private _fa = +(_u getVariable ["kat_surgery_fractures", [0, 0, 0, 0, 0, 0]]);
            if ((count _fa) >= 6 && { (_fa select _fIdx) != 0 }) then {
                _fa set [_fIdx, 0];
                _u setVariable ["kat_surgery_fractures", _fa, true];
            };
        };
        private _ow = _u getVariable ["ace_medical_openWounds", []];
        if (_ow isEqualType [] && {count _ow > 0}) then {
            private _kept = [];
            {
                if (!(_x isEqualType [])) then { _kept pushBack _x; continue };
                private _sel = "";
                if (count _x > 0) then {
                    _sel = if ((_x select 0) isEqualType "") then { toLower (_x select 0) } else { "" };
                };
                if (_sel != _want) then { _kept pushBack _x };
            } forEach _ow;
            if ((count _kept) < (count _ow)) then {
                _u setVariable ["ace_medical_openWounds", _kept, true];
            };
        };
    };
    if (local _u) then {
        [_u, _part] call _healCode;
    } else {
        [_u, _part] remoteExecCall [_healCode, _u];
    };
};

FAC_medKAT_setUnconscious = {
    params ["_u", "_uncon"];
    if (isNull _u || {!alive _u}) exitWith {};
    if (_uncon) then {
        [_u, true, 3600, false] call ace_medical_fnc_setUnconscious;
    } else {
        [_u, false, 1, false] call ace_medical_fnc_setUnconscious;
    };
};

missionNamespace setVariable ["FAC_medKAT_scenarioList", FAC_medKAT_scenarioList, true];
missionNamespace setVariable ["FAC_medKAT_fracturePartOrder", FAC_medKAT_fracturePartOrder, true];
missionNamespace setVariable ["FAC_medKAT_scenarioKeys", FAC_medKAT_scenarioList apply { _x select 0 }, true];

true
