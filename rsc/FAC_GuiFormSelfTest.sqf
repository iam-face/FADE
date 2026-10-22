call compile preprocessFileLineNumbers "rsc\FAC_GuiForm.sqf";
call compile preprocessFileLineNumbers "rsc\FAC_GuiSpecs.sqf";

private _ok = [] call FAC_gui_selfTest;
if (_ok) then {
    diag_log "FAC_GUI_SELFTEST_OK";
} else {
    diag_log "FAC_GUI_SELFTEST_FAIL";
};

{
    _x params ["_name", "_spec"];
    private _errs = [_spec] call FAC_gui_auditSpec;
    if (count _errs > 0) then {
        diag_log format ["FAC_GUI_AUDIT_FAIL %1 %2", _name, _errs];
    } else {
        diag_log format ["FAC_GUI_AUDIT_OK %1", _name];
    };
} forEach FAC_gui_allSpecs;
