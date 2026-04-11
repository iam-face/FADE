// Loaded from initServer and initPlayerLocal (MedicalTrainingKAT.sqf is server-only).
// KAM surgery fracture array on the unit's local machine.
FAC_medKAT_fnc_setFractureAtIndexLocal = {
    params ["_u", "_i", "_s"];
    if (!local _u || { isNull _u } || { !alive _u }) exitWith {};
    private _arr = +(_u getVariable ["kat_surgery_fractures", [0, 0, 0, 0, 0, 0]]);
    if ((count _arr) < 6) then { _arr = [0, 0, 0, 0, 0, 0] };
    _arr set [_i, _s];
    _u setVariable ["kat_surgery_fractures", _arr, true];
};

true
