// =============================================================================
// FAC_Theme.sqf — runtime theme palette + helpers (sync with FAC_Theme.hpp)
// =============================================================================
if (!hasInterface) exitWith {};

// Backgrounds
FAC_theme_bgPanel   = [0.09, 0.09, 0.11, 0.98];
FAC_theme_bgHeader  = [0.14, 0.14, 0.16, 1];
FAC_theme_bgMain    = [0.06, 0.06, 0.08, 0.72];
FAC_theme_bgSection = [0.08, 0.08, 0.10, 0.55];
FAC_theme_bgList    = [0.05, 0.05, 0.07, 0.95];
FAC_theme_bgInput   = [0.08, 0.08, 0.10, 0.95];
FAC_theme_bgOverlay = [0.06, 0.06, 0.08, 0.96];
FAC_theme_bgOverlayTitle = [0.20, 0.20, 0.22, 1];
FAC_theme_textHdr = [0.88, 0.88, 0.90, 1];
FAC_theme_textMuted = [0.62, 0.64, 0.68, 1];
FAC_theme_textOk    = [0.78, 0.82, 0.78, 1];
FAC_theme_textEmphasis = [0.92, 0.92, 0.94, 1];

// Structured-text HTML (neutral; use instead of gold/teal in GUIs)
FAC_theme_htmlBody = "#d8d8dc";
FAC_theme_htmlEmphasis = "#e8e8ec";
FAC_theme_htmlMuted = "#9a9aa0";

// Tabs / toggles
FAC_theme_tabActive = [0.40, 0.40, 0.44, 1];
FAC_theme_tabIdle   = [0.18, 0.18, 0.20, 1];

// Buttons
FAC_theme_btnPrimary   = [0.32, 0.32, 0.36, 1];
FAC_theme_btnPrimaryA  = [0.42, 0.42, 0.46, 1];
FAC_theme_btnNeutral   = [0.22, 0.22, 0.24, 1];
FAC_theme_btnDanger    = [0.55, 0.12, 0.12, 1];
FAC_theme_btnWarn      = [0.42, 0.22, 0.20, 1];
FAC_theme_btnStart     = [0.36, 0.36, 0.40, 1];

FAC_theme_applyTab = {
    params ["_ctrl", "_active"];
    if (isNull _ctrl) exitWith {};
    _ctrl ctrlSetBackgroundColor (if (_active) then { FAC_theme_tabActive } else { FAC_theme_tabIdle });
};

FAC_theme_applyTogglePair = {
    params ["_ctrlA", "_ctrlB", "_firstActive"];
    [_ctrlA, _firstActive] call FAC_theme_applyTab;
    [_ctrlB, !_firstActive] call FAC_theme_applyTab;
};

FAC_theme_applyToggleGroup = {
    params ["_ctrls", "_activeCtrl"];
    {
        [_x, _x isEqualTo _activeCtrl] call FAC_theme_applyTab;
    } forEach _ctrls;
};

FAC_theme_guiResourceMissing = {
    params ["_guiName"];
    systemChat format ["%1 GUI: RESOURCE NOT FOUND.", toUpper _guiName];
};

missionNamespace setVariable ["FAC_theme_applyTab", FAC_theme_applyTab];
missionNamespace setVariable ["FAC_theme_applyTogglePair", FAC_theme_applyTogglePair];
missionNamespace setVariable ["FAC_theme_applyToggleGroup", FAC_theme_applyToggleGroup];
missionNamespace setVariable ["FAC_theme_guiResourceMissing", FAC_theme_guiResourceMissing];
