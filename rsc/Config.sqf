// =============================================================================
// Config - Face's Dynamic Sandbox mission configuration
// =============================================================================
// FADE_heliClasses is built dynamically from CfgVehicles (see initServer.sqf)
// Scenario settings (weather, time, factions) are managed via Scenario GUI.
// Unit arrays below are fallbacks when faction has no units (e.g. mod not loaded).

call compile preprocessFileLineNumbers "rsc\ConfigClient.sqf";
call compile preprocessFileLineNumbers "rsc\ConfigDefaults.sqf";

FADE_normalizeOpforLauncherSetting = {
    params ["_setting"];
    switch (toLower (_setting + "")) do {
        case "none": { "None" };
        case "minimal": { "Minimal" };
        case "reduced": { "Reduced" };
        default { "Normal" };
    };
};
FADE_opforAirSetting = "Off";               // Off | Low | Normal | High  -  OPFOR air after AI spots BLUFOR (FADE_opforThreatIntensity)
FADE_opforDroneSetting = "Off";             // Off | Low | Normal | High  -  OPFOR UAV patrol + QRF vectoring (FADE_OpforDrones.sqf)

// Shared Off/Low/Normal/High intensity helpers (legacy "Medium" maps to Normal).
FADE_normalizeOpforThreatSetting = {
    params ["_setting"];
    private _s = _setting;
    if (toLower _s == "medium") then { _s = "Normal" };
    _s
};

FADE_opforThreatIntensity = {
    params ["_setting"];
    private _s = toLower ([_setting] call FADE_normalizeOpforThreatSetting);
    switch (_s) do {
        case "low": { [1, 600] };
        case "normal": { [2, 300] };
        case "high": { [3, 180] };
        default { [0, 999999] };
    };
};

FADE_opforDroneIntensity = {
    params ["_setting"];
    private _s = toLower ([_setting] call FADE_normalizeOpforThreatSetting);
    switch (_s) do {
        case "low": { [1, 480, 720] };
        case "normal": { [2, 300, 480] };
        case "high": { [3, 180, 300] };
        default { [0, 999999, 999999] };
    };
};
// BIS CP stubs: FADE_debugBIScp / fn_bisCpPreInit in ConfigClient.sqf

// -----------------------------------------------------------------------------
// CQB Training Shoothouse - Eden object names for drill positions (triggers/objects)
// Place CQB_POS_1, CQB_POS_2, ... in Eden; direction of object = facing of spawned unit/target
// (Built with a loop - avoid "N to M" ranges; they can fail to compile under call compile in some setups.)
// -----------------------------------------------------------------------------
FADE_cqbPosNames = [];
private _cqbI = 1;
while { _cqbI <= 49 } do {
    FADE_cqbPosNames pushBack format ["CQB_POS_%1", _cqbI];
    _cqbI = _cqbI + 1;
};
// Pop-up target class (vanilla); CQB server logic + noPop + client animateSource keep it down until drill end
FADE_cqbTargetClass = "TargetP_Inf_F";

// Sniper range (terminalSniper + sniperRangeTarget_*); same pop-up class unless overridden
FADE_sniperTargetClass = "TargetP_Inf_F";
// Impact marker at bullet hit (server); falls back if class missing from modset
FADE_sniperImpactMarkerClass = "Sign_sphere25cm_EP1";

// Firing / AT range (terminalRange): session targets use Eden game logics firingRangePos_1 .. firingRangePos_210 (shared pool).
// Vehicle class toggles in GUI map to these keys: car, truck, apc, tank.
FADE_rangeVehicleTypeMap = [
    ["car", "UK3CB_CSAT_B_O_UAZ_Open"],
    ["truck", "UK3CB_CW_SOV_O_EARLY_Ural"],
    ["apc", "rhs_bmp2e_vv"],
    ["tank", "rhsgref_ins_t72bc"]
];
// Extra range equipment (label, CfgVehicles class) merged into the same list + pads as friendly land vehicles (rangeFriendlyVehPos_*).
FADE_rangeAtWeaponDefinitions = [
    ["RPG-42 [AT] (placeholder)", "launch_RPG32_F"],
    ["MRAWS [AT] (placeholder)", "launch_MRAWS_green_F"],
    ["Titan AT [placeholder]", "launch_B_Titan_short_F"]
];
// Legacy separate AT pads (rangeGunPos_*): leave empty  -  equipment uses rangeFriendlyVehPos_* only.
FADE_rangeGunPosNames = [];
// Friendly BLUFOR ground vehicles (same class pool as Vehicle GUI land spawn); logic positions in Eden.
FADE_rangeFriendlyVehPosNames = [
    "rangeFriendlyVehPos_1", "rangeFriendlyVehPos_2", "rangeFriendlyVehPos_3",
    "rangeFriendlyVehPos_4", "rangeFriendlyVehPos_5", "rangeFriendlyVehPos_6"
];
// Range equipment GUI pad labels (same order / length as FADE_rangeFriendlyVehPosNames).
FADE_rangeFriendlyVehPosDisplayNames = [
    "Friendly Equipment Position 1",
    "Friendly Equipment Position 2",
    "Friendly Equipment Position 3",
    "Friendly Equipment Position 4",
    "Friendly Equipment Position 5",
    "Friendly Equipment Position 6"
];

// Locker Room ambient: client tunables in ConfigClient.sqf
