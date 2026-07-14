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
FADE_normalizeOpforPatrolTownChanceSetting = {
    params [["_setting", "Low"]];
    switch (toLower (_setting + "")) do {
        case "medium": { "Medium" };
        case "high": { "High" };
        case "every";
        case "all";
        case "100": { "Every" };
        default { "Low" };
    };
};
FADE_resolveOpforPatrolTownChance = {
    params [["_setting", "Low"]];
    private _set = [_setting] call FADE_normalizeOpforPatrolTownChanceSetting;
    switch _set do {
        case "Medium": { 0.5 };
        case "High": { 0.75 };
        case "Every": { 1 };
        default { 0.25 };
    };
};

call compile preprocessFileLineNumbers "rsc\fn_bisCpPreInit.sqf";
