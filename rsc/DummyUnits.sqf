// =============================================================================
// DummyUnits.sqf  -  Eden dummyStand_* / dummyMove_* behaviour
// -----------------------------------------------------------------------------
// Server only. IntroCutscene.sqf (FAC_C_M01) has no unit animations; source list
// is IntroCutscene2.sqf switchMove calls.
// =============================================================================

if (!isServer) exitWith {};

// Unique Acts_* / ActsPerc* from IntroCutscene2.sqf (IntroCutscene.sqf has no switchMove).
// Omit Acts_FarmIncident_Lacey1/Lacey2: walking sequences drift static Eden positions.
private _standAnims = [
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

private _standUnits = allUnits select {
    private _vn = vehicleVarName _x;
    _vn != "" && { _vn find "dummyStand_" == 0 }
};

{
    private _unit = _x;
    if (!alive _unit) then { continue };

    _unit disableAI "MOVE";
    _unit disableAI "TARGET";
    _unit disableAI "AUTOTARGET";
    _unit disableAI "AUTOCOMBAT";
    _unit disableAI "COVER";
    _unit disableAI "SUPPRESSION";
    _unit setUnitPos "UP";
    _unit setBehaviour "CARELESS";
    _unit setCombatMode "BLUE";

    [_unit, _standAnims] spawn {
        params ["_unit", "_standAnims"];
        sleep (random 5);
        while { alive _unit } do {
            private _anim = selectRandom _standAnims;
            _unit switchMove _anim;
            sleep (30 + random 30);
        };
    };
} forEach _standUnits;

private _processedMoveGroups = [];
{
    private _unit = _x;
    if (!alive _unit) then { continue };

    private _grp = group _unit;
    if (!(_grp in _processedMoveGroups)) then {
        _processedMoveGroups pushBack _grp;
        _grp setBehaviour "CARELESS";
        _grp setCombatMode "BLUE";
        _grp allowFleeing 0;
    };

    _unit disableAI "TARGET";
    _unit disableAI "AUTOTARGET";
    _unit disableAI "AUTOCOMBAT";
    _unit setUnitPos "UP";
} forEach (allUnits select {
    private _vn = vehicleVarName _x;
    _vn != "" && { _vn find "dummyMove_" == 0 }
});
