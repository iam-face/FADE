// =============================================================================
// ConfigClient.sqf  -  client JIP subset (map picks, debug stubs, locker room)
// Included by Config.sqf on server boot; initPlayerLocal compiles this directly.
// =============================================================================

call compile preprocessFileLineNumbers "rsc\ConfigClientDefaults.sqf";

// Scenario GUI + lobby (Config.sqf on server; clients need this helper for Opfor Air/Drone toggles).
FADE_normalizeOpforThreatSetting = {
    params ["_setting"];
    private _s = _setting;
    if (toLower _s == "medium") then { _s = "Normal" };
    _s
};

call compile preprocessFileLineNumbers "rsc\fn_bisCpPreInit.sqf";
