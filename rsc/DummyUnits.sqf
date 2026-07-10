// =============================================================================
// DummyUnits.sqf  -  Eden dummyStand_* / dummyMove_* behaviour + scenario faction sync
// -----------------------------------------------------------------------------
// Server only. IntroCutscene.sqf (FAC_C_M01) has no unit animations; source list
// is IntroCutscene2.sqf switchMove calls.
// =============================================================================

if (!isServer) exitWith {};

// Unique Acts_* / ActsPerc* from IntroCutscene2.sqf (IntroCutscene.sqf has no switchMove).
// Omit Acts_FarmIncident_Lacey1/Lacey2: walking sequences drift static Eden positions.
FADE_dummyUnits_standAnims = [
    "Acts_CivilTalking_1",
    "Acts_CivilListening_1",
    "Acts_CivilListening_2",
    "Acts_CivilIdle_1",
    "Acts_CivilIdle_2",
    "Acts_Commenting_On_Fight_action",
    "Acts_Explaining_EW_Loop01",
    "Acts_FarmIncident_Commander",
    "Acts_Kore_IdleNoWeapon_loop",
    "ActsPercMstpSnonWnonDnon_talking01",
    "ActsPercSnonWnonDnon_tableSupport_TalkTransAB",
    "Acts_A_M02_briefing",
    "Acts_B_M03_briefing"
];

FADE_dummyUnits_slotName = {
    params ["_unit"];
    if (isNull _unit) exitWith { "" };
    private _vn = vehicleVarName _unit;
    if (_vn == "") then { _vn = _unit getVariable ["FADE_dummyVarName", ""] };
    _vn
};

FADE_dummyUnits_isDummy = {
    params ["_unit"];
    if (isNull _unit || {!alive _unit}) exitWith { false };
    if (_unit getVariable ["FADE_baseDummy", false]) exitWith { true };
    private _vn = [_unit] call FADE_dummyUnits_slotName;
    _vn != "" && { (_vn find "dummyStand_") == 0 || { _vn find "dummyMove_" == 0 } }
};

FADE_dummyUnits_captureSlots = {
    private _slots = missionNamespace getVariable ["FADE_dummyUnits_slots", createHashMap];
    if (!(_slots isEqualType createHashMap)) then { _slots = createHashMap };
    {
        private _vn = [_x] call FADE_dummyUnits_slotName;
        if (_vn == "") then { continue };
        if (!((_vn find "dummyStand_") == 0 || { _vn find "dummyMove_" == 0 })) then { continue };
        _slots set [_vn, [getPosATL _x, getDir _x, _vn find "dummyStand_" == 0]];
    } forEach (allUnits select { [_x] call FADE_dummyUnits_isDummy });
    missionNamespace setVariable ["FADE_dummyUnits_slots", _slots];
    _slots
};

FADE_dummyUnits_findBySlot = {
    params ["_slotName"];
    if (_slotName == "") exitWith { objNull };
    private _hit = objNull;
    {
        if ([_x] call FADE_dummyUnits_slotName == _slotName) exitWith { _hit = _x };
    } forEach (allUnits select { [_x] call FADE_dummyUnits_isDummy });
    _hit
};

FADE_dummyUnits_pickRandomFriendlyClass = {
    private _ff = missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"];
    private _sn = missionNamespace getVariable ["FADE_scenarioFriendlySideNum", 1];
    // Use scenario apply output — already faction-filtered (not the whole side pool).
    private _pool = +(missionNamespace getVariable ["FADE_friendlyUnits", []]);
    if (_pool isEqualTo [] && { !isNil "FADE_resolveScenarioFriendlyUnits" }) then {
        _pool = [[]] call FADE_resolveScenarioFriendlyUnits;
    };
    if (_pool isEqualTo []) then {
        private _raw = [_ff, _sn] call FADE_getUnitsForFaction;
        if (!isNil "FADE_filterUnitsArmed") then {
            _raw = [_raw] call FADE_filterUnitsArmed;
        };
        if (!isNil "FADE_filterUnitsForScenarioFaction") then {
            _raw = [_raw, _ff, _sn, true] call FADE_filterUnitsForScenarioFaction;
        };
        _pool = _raw;
    };
    if (_pool isEqualTo [] && { _ff isEqualTo "BLU_F" }) then {
        _pool = +(missionNamespace getVariable ["FADE_fallbackFriendlyUnits", ["B_Soldier_F"]]);
    };
    if (_pool isEqualTo []) exitWith { "B_Soldier_F" };
    selectRandom _pool
};

FADE_dummyUnits_setupStand = {
    params ["_unit"];
    if (isNull _unit || {!alive _unit}) exitWith {};

    _unit disableAI "MOVE";
    _unit disableAI "TARGET";
    _unit disableAI "AUTOTARGET";
    _unit disableAI "AUTOCOMBAT";
    _unit disableAI "COVER";
    _unit disableAI "SUPPRESSION";
    _unit setUnitPos "UP";
    _unit setBehaviour "CARELESS";
    _unit setCombatMode "BLUE";
    _unit allowDamage false;

    [_unit, +FADE_dummyUnits_standAnims] spawn {
        params ["_unit", "_standAnims"];
        sleep (random 5);
        while { alive _unit } do {
            private _anim = selectRandom _standAnims;
            _unit switchMove _anim;
            sleep (30 + random 30);
        };
    };
};

FADE_dummyUnits_setupMove = {
    params ["_unit"];
    if (isNull _unit || {!alive _unit}) exitWith {};

    private _grp = group _unit;
    _grp setBehaviour "CARELESS";
    _grp setCombatMode "BLUE";
    _grp allowFleeing 0;

    _unit disableAI "TARGET";
    _unit disableAI "AUTOTARGET";
    _unit disableAI "AUTOCOMBAT";
    _unit setUnitPos "UP";
    _unit allowDamage false;
};

FADE_dummyUnits_spawnAtSlot = {
    params ["_slotName", "_pos", "_dir", "_isStand"];
    if (_slotName == "") exitWith { objNull };

    private _existing = [_slotName] call FADE_dummyUnits_findBySlot;
    if (!isNull _existing) then { deleteVehicle _existing };

    private _sideF = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _class = call FADE_dummyUnits_pickRandomFriendlyClass;
    if (_class == "" || { !isClass (configFile >> "CfgVehicles" >> _class) }) exitWith { objNull };

    private _grp = createGroup [_sideF, true];
    private _new = _grp createUnit [_class, _pos, [], 0, "NONE"];
    if (isNull _new) exitWith { objNull };

    _new setPosATL _pos;
    _new setDir _dir;
    _new setVehicleVarName _slotName;
    _new setVariable ["FADE_baseDummy", true, true];
    _new setVariable ["FADE_dummyVarName", _slotName, true];

    private _loadout = [_class, _sideF] call FAC_loadoutGui_getLoadoutFromClass;
    private _traits = [_class] call FAC_loadoutGui_getCfgRoleTraits;
    _traits params ["_medic", "_eng", "_exp"];
    if ((count _loadout) >= 10) then {
        [_new, _loadout, _medic, _eng, _exp] call FAC_loadoutGui_applyLoadoutToUnitServer;
    };

    if (_isStand) then {
        [_new] call FADE_dummyUnits_setupStand;
    } else {
        [_new] call FADE_dummyUnits_setupMove;
    };

    _new
};

// Apply scenario friendly faction: random class/loadout + correct side for all Eden dummies.
FADE_dummyUnits_refreshForScenarioFaction = {
    if (!isServer) exitWith { 0 };
    private _slots = call FADE_dummyUnits_captureSlots;
    private _refreshed = 0;
    {
        _y params ["_pos", "_dir", "_isStand"];
        if (!isNull ([_x, _pos, _dir, _isStand] call FADE_dummyUnits_spawnAtSlot)) then {
            _refreshed = _refreshed + 1;
        };
    } forEach _slots;
    _refreshed
};

FADE_dummyUnits_init = {
    if (!isServer) exitWith {};
    call FADE_dummyUnits_captureSlots;
    [] call FADE_dummyUnits_refreshForScenarioFaction;
};

missionNamespace setVariable ["FADE_dummyUnits_isDummy", FADE_dummyUnits_isDummy];
missionNamespace setVariable ["FADE_dummyUnits_refreshForScenarioFaction", FADE_dummyUnits_refreshForScenarioFaction];
publicVariable "FADE_dummyUnits_refreshForScenarioFaction";

[] call FADE_dummyUnits_init;
