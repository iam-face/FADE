// Sniper range — terminalSniper (60910): included from description.ext
class RscDisplaySniper: RscDisplayEmpty {
    idd = 60910;
    movingEnable = 1;
    enableSimulation = 1;
    onLoad = "[] spawn { sleep 0.01; ['onLoad', []] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]); };";
    class controlsBackground {
        class Background: RscText { idc = -1; x = 0.02; y = 0.025; w = 0.96; h = 0.94; colorBackground[] = FAC_COLOR_BG_PANEL; };
        class HeaderBar: RscText { idc = -1; x = 0.02; y = 0.025; w = 0.96; h = 0.065; colorBackground[] = FAC_COLOR_BG_HEADER; };
        class LeftPanelBg: RscText { idc = -1; x = 0.03; y = 0.098; w = 0.44; h = 0.64; colorBackground[] = FAC_COLOR_BG_SECTION; };
        class RightPanelBg: RscText { idc = -1; x = 0.48; y = 0.098; w = 0.49; h = 0.64; colorBackground[] = FAC_COLOR_BG_SECTION; };
    };
    class controls {
        class TitleText: RscText { idc = -1; text = "SNIPER RANGE"; x = 0.035; y = 0.032; w = 0.70; h = 0.048; sizeEx = 0.034; colorText[] = {1, 1, 1, 1}; colorBackground[] = {0, 0, 0, 0}; };
        class HeaderRefreshBtn: RscButton { idc = 60911; text = "Refresh"; x = 0.805; y = 0.036; w = 0.092; h = 0.046; sizeEx = 0.028; colorBackground[] = FAC_COLOR_BTN_NEUTRAL; action = "['headerRefresh', []] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]);"; };
        class CloseHeaderBtn: RscButton { idc = 60914; text = "X"; x = 0.905; y = 0.036; w = 0.048; h = 0.046; sizeEx = 0.034; colorBackground[] = FAC_COLOR_BTN_DANGER; action = "closeDialog 0;"; };
        class StatusLabel: RscText { idc = -1; text = "Range status"; x = 0.04; y = 0.108; w = 0.20; h = 0.024; sizeEx = 0.027; colorText[] = FAC_COLOR_TEXT_MUTED; };
        class StatusValue: RscText { idc = 60930; text = "INACTIVE"; x = 0.17; y = 0.108; w = 0.28; h = 0.024; sizeEx = 0.027; colorText[] = FAC_COLOR_TEXT_OK; style = 2; };
        class MySettingsHdr: RscText { idc = -1; text = "My settings"; x = 0.04; y = 0.136; w = 0.40; h = 0.024; sizeEx = 0.028; colorText[] = FAC_COLOR_TEXT_HDR; };
        class TraceLabel: RscText { idc = -1; text = "Projectile trace"; x = 0.04; y = 0.162; w = 0.38; h = 0.022; sizeEx = 0.024; colorText[] = {0.92, 0.92, 0.94, 1}; };
        class BtnTraceOff: RscButton { idc = 60918; text = "Off"; x = 0.04; y = 0.186; w = 0.195; h = 0.034; sizeEx = 0.026; colorBackground[] = FAC_COLOR_BTN_PRIMARY; action = "['setTrace', [false]] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]);"; };
        class BtnTraceOn: RscButton { idc = 60919; text = "On"; x = 0.245; y = 0.186; w = 0.195; h = 0.034; sizeEx = 0.026; colorBackground[] = FAC_COLOR_TAB_IDLE; action = "['setTrace', [true]] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]);"; };
        class HitLabel: RscText { idc = -1; text = "Hit feedback"; x = 0.04; y = 0.226; w = 0.38; h = 0.022; sizeEx = 0.024; colorText[] = {0.92, 0.92, 0.94, 1}; };
        class BtnHitOff: RscButton { idc = 60920; text = "Off"; x = 0.04; y = 0.250; w = 0.195; h = 0.034; sizeEx = 0.026; colorBackground[] = FAC_COLOR_BTN_PRIMARY; action = "['setHitTrack', [false]] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]);"; };
        class BtnHitOn: RscButton { idc = 60921; text = "On"; x = 0.245; y = 0.250; w = 0.195; h = 0.034; sizeEx = 0.026; colorBackground[] = FAC_COLOR_TAB_IDLE; action = "['setHitTrack', [true]] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]);"; };
        class RangeSettingsHdr: RscText { idc = -1; text = "Range settings"; x = 0.04; y = 0.290; w = 0.40; h = 0.024; sizeEx = 0.028; colorText[] = FAC_COLOR_TEXT_HDR; };
        class ThreatLabel: RscText { idc = -1; text = "Target type"; x = 0.04; y = 0.316; w = 0.38; h = 0.022; sizeEx = 0.024; colorText[] = {0.92, 0.92, 0.94, 1}; };
        class BtnThreatTargets: RscButton { idc = 60912; text = "Pop-up targets"; x = 0.04; y = 0.340; w = 0.195; h = 0.036; sizeEx = 0.026; colorBackground[] = FAC_COLOR_BTN_PRIMARY; action = "['setThreat', ['targets']] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]);"; };
        class BtnThreatLive: RscButton { idc = 60913; text = "Live OPFOR"; x = 0.245; y = 0.340; w = 0.195; h = 0.036; sizeEx = 0.026; colorBackground[] = FAC_COLOR_TAB_IDLE; action = "['setThreat', ['enemies']] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]);"; };
        class CountLabel: RscText { idc = -1; text = "Number of targets"; x = 0.04; y = 0.382; w = 0.27; h = 0.022; sizeEx = 0.024; colorText[] = {0.92, 0.92, 0.94, 1}; };
        class CountValue: RscText { idc = 60916; text = "10"; x = 0.325; y = 0.382; w = 0.115; h = 0.022; sizeEx = 0.024; style = 2; colorText[] = FAC_COLOR_TEXT_EMPHASIS; };
        class CountSlider: RscXSliderH { idc = 60915; x = 0.04; y = 0.406; w = 0.40; h = 0.032; onSliderPosChanged = "['setTargetCount', [_this select 1]] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]);"; };
        class MaxRangeLabel: RscText { idc = -1; text = "Max range"; x = 0.04; y = 0.442; w = 0.27; h = 0.022; sizeEx = 0.024; colorText[] = {0.92, 0.92, 0.94, 1}; };
        class MaxRangeValue: RscText { idc = 60932; text = "1000 m"; x = 0.325; y = 0.442; w = 0.115; h = 0.022; sizeEx = 0.024; style = 2; colorText[] = FAC_COLOR_TEXT_EMPHASIS; };
        class MaxRangeSlider: RscXSliderH { idc = 60931; x = 0.04; y = 0.466; w = 0.40; h = 0.032; onSliderPosChanged = "['setMaxRange', [_this select 1]] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]);"; };
        class ModeLabel: RscText { idc = -1; text = "Mode"; x = 0.04; y = 0.504; w = 0.38; h = 0.022; sizeEx = 0.024; colorText[] = {0.92, 0.92, 0.94, 1}; };
        class BtnModeFiring: RscButton { idc = 60922; text = "Firing range"; x = 0.04; y = 0.528; w = 0.195; h = 0.034; sizeEx = 0.026; colorBackground[] = FAC_COLOR_BTN_PRIMARY; action = "['setMode', ['firing']] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]);"; };
        class BtnModeTrial: RscButton { idc = 60923; text = "Time trial"; x = 0.245; y = 0.528; w = 0.195; h = 0.034; sizeEx = 0.026; colorBackground[] = FAC_COLOR_TAB_IDLE; action = "['setMode', ['trial']] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]);"; };
        class InfoHdr: RscText { idc = -1; text = "How it works"; x = 0.49; y = 0.108; w = 0.45; h = 0.026; sizeEx = 0.030; colorText[] = FAC_COLOR_TEXT_HDR; };
        class InfoPanel: RscStructuredText {
            idc = 60925;
            x = 0.49; y = 0.138; w = 0.465; h = 0.590;
            colorBackground[] = FAC_COLOR_BG_SECTION;
            text = "";
            size = 0.024;
            class Attributes { font = "PuristaMedium"; color = "#d8d8dc"; align = "left"; valign = "top"; shadow = 0; };
        };
        class SessionBtn: RscButton { idc = 60924; text = "Start session"; x = 0.04; y = 0.868; w = 0.92; h = 0.052; sizeEx = 0.034; colorBackground[] = FAC_COLOR_BTN_PRIMARY; action = "['session', []] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]);"; };
    };
};
