// Sniper range — terminalSniper (60910): included from description.ext
class RscDisplaySniper: RscDisplayEmpty {
    idd = 60910;
    movingEnable = 1;
    enableSimulation = 1;
    onLoad = "[] spawn { sleep 0.01; ['onLoad', []] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]); };";
    class controlsBackground {
        class Background: RscText { idc = -1; x = 0.02; y = 0.02; w = 0.96; h = 0.96; colorBackground[] = {0.08, 0.08, 0.11, 0.97}; };
        class HeaderBar: RscText { idc = -1; x = 0.02; y = 0.02; w = 0.96; h = 0.056; colorBackground[] = {0.14, 0.18, 0.32, 1}; };
        class LeftPanelBg: RscText { idc = -1; x = 0.03; y = 0.082; w = 0.44; h = 0.64; colorBackground[] = {0.06, 0.06, 0.09, 0.55}; };
        class RightPanelBg: RscText { idc = -1; x = 0.48; y = 0.082; w = 0.49; h = 0.64; colorBackground[] = {0.06, 0.06, 0.09, 0.55}; };
    };
    class controls {
        class TitleText: RscText { idc = -1; text = "SNIPER RANGE"; x = 0.035; y = 0.028; w = 0.70; h = 0.042; sizeEx = 0.038; colorText[] = {1, 1, 1, 1}; colorBackground[] = {0, 0, 0, 0}; };
        class HeaderRefreshBtn: RscButton { idc = 60911; text = "Refresh"; x = 0.84; y = 0.028; w = 0.058; h = 0.042; sizeEx = 0.028; colorBackground[] = {0.18, 0.32, 0.48, 1}; action = "['headerRefresh', []] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]);"; };
        class CloseHeaderBtn: RscButton { idc = 60914; text = "X"; x = 0.905; y = 0.028; w = 0.048; h = 0.042; sizeEx = 0.034; colorBackground[] = {0.35, 0.22, 0.22, 1}; action = "closeDialog 0;"; };
        class StatusLabel: RscText { idc = -1; text = "Range status"; x = 0.04; y = 0.088; w = 0.20; h = 0.024; sizeEx = 0.027; colorText[] = {0.85, 0.9, 1, 1}; };
        class StatusValue: RscText { idc = 60930; text = "INACTIVE"; x = 0.17; y = 0.088; w = 0.28; h = 0.024; sizeEx = 0.027; colorText[] = {0.55, 0.95, 0.7, 1}; style = 2; };
        class MySettingsHdr: RscText { idc = -1; text = "My settings"; x = 0.04; y = 0.120; w = 0.40; h = 0.024; sizeEx = 0.028; colorText[] = {0.85, 0.9, 1, 1}; };
        class TraceLabel: RscText { idc = -1; text = "Projectile trace"; x = 0.04; y = 0.146; w = 0.38; h = 0.022; sizeEx = 0.024; colorText[] = {0.95, 0.95, 0.95, 1}; };
        class BtnTraceOff: RscButton { idc = 60918; text = "Off"; x = 0.04; y = 0.170; w = 0.195; h = 0.034; sizeEx = 0.026; colorBackground[] = {0.2, 0.4, 0.62, 1}; action = "['setTrace', [false]] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]);"; };
        class BtnTraceOn: RscButton { idc = 60919; text = "On"; x = 0.245; y = 0.170; w = 0.195; h = 0.034; sizeEx = 0.026; colorBackground[] = {0.10, 0.12, 0.16, 1}; action = "['setTrace', [true]] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]);"; };
        class HitLabel: RscText { idc = -1; text = "Hit feedback"; x = 0.04; y = 0.210; w = 0.38; h = 0.022; sizeEx = 0.024; colorText[] = {0.95, 0.95, 0.95, 1}; };
        class BtnHitOff: RscButton { idc = 60920; text = "Off"; x = 0.04; y = 0.234; w = 0.195; h = 0.034; sizeEx = 0.026; colorBackground[] = {0.2, 0.4, 0.62, 1}; action = "['setHitTrack', [false]] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]);"; };
        class BtnHitOn: RscButton { idc = 60921; text = "On"; x = 0.245; y = 0.234; w = 0.195; h = 0.034; sizeEx = 0.026; colorBackground[] = {0.10, 0.12, 0.16, 1}; action = "['setHitTrack', [true]] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]);"; };
        class RangeSettingsHdr: RscText { idc = -1; text = "Range settings"; x = 0.04; y = 0.278; w = 0.40; h = 0.024; sizeEx = 0.028; colorText[] = {0.85, 0.9, 1, 1}; };
        class ThreatLabel: RscText { idc = -1; text = "Target type"; x = 0.04; y = 0.304; w = 0.38; h = 0.022; sizeEx = 0.024; colorText[] = {0.95, 0.95, 0.95, 1}; };
        class BtnThreatTargets: RscButton { idc = 60912; text = "Pop-up targets"; x = 0.04; y = 0.328; w = 0.195; h = 0.036; sizeEx = 0.026; colorBackground[] = {0.2, 0.4, 0.62, 1}; action = "['setThreat', ['targets']] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]);"; };
        class BtnThreatLive: RscButton { idc = 60913; text = "Live OPFOR"; x = 0.245; y = 0.328; w = 0.195; h = 0.036; sizeEx = 0.026; colorBackground[] = {0.10, 0.12, 0.16, 1}; action = "['setThreat', ['enemies']] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]);"; };
        class CountLabel: RscText { idc = -1; text = "Number of targets"; x = 0.04; y = 0.370; w = 0.27; h = 0.022; sizeEx = 0.024; colorText[] = {0.95, 0.95, 0.95, 1}; };
        class CountValue: RscText { idc = 60916; text = "10"; x = 0.325; y = 0.370; w = 0.115; h = 0.022; sizeEx = 0.024; style = 2; colorText[] = {0.78, 0.95, 0.88, 1}; };
        class CountSlider: RscXSliderH { idc = 60915; x = 0.04; y = 0.394; w = 0.40; h = 0.032; onSliderPosChanged = "['setTargetCount', [_this select 1]] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]);"; };
        class MaxRangeLabel: RscText { idc = -1; text = "Max range"; x = 0.04; y = 0.430; w = 0.27; h = 0.022; sizeEx = 0.024; colorText[] = {0.95, 0.95, 0.95, 1}; };
        class MaxRangeValue: RscText { idc = 60932; text = "1000 m"; x = 0.325; y = 0.430; w = 0.115; h = 0.022; sizeEx = 0.024; style = 2; colorText[] = {0.78, 0.95, 0.88, 1}; };
        class MaxRangeSlider: RscXSliderH { idc = 60931; x = 0.04; y = 0.454; w = 0.40; h = 0.032; onSliderPosChanged = "['setMaxRange', [_this select 1]] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]);"; };
        class ModeLabel: RscText { idc = -1; text = "Mode"; x = 0.04; y = 0.492; w = 0.38; h = 0.022; sizeEx = 0.024; colorText[] = {0.95, 0.95, 0.95, 1}; };
        class BtnModeFiring: RscButton { idc = 60922; text = "Firing range"; x = 0.04; y = 0.516; w = 0.195; h = 0.034; sizeEx = 0.026; colorBackground[] = {0.2, 0.4, 0.62, 1}; action = "['setMode', ['firing']] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]);"; };
        class BtnModeTrial: RscButton { idc = 60923; text = "Time trial"; x = 0.245; y = 0.516; w = 0.195; h = 0.034; sizeEx = 0.026; colorBackground[] = {0.10, 0.12, 0.16, 1}; action = "['setMode', ['trial']] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]);"; };
        class InfoHdr: RscText { idc = -1; text = "How it works"; x = 0.49; y = 0.088; w = 0.45; h = 0.026; sizeEx = 0.030; colorText[] = {0.85, 0.9, 1, 1}; };
        class InfoPanel: RscStructuredText {
            idc = 60925;
            x = 0.49; y = 0.118; w = 0.465; h = 0.590;
            colorBackground[] = {0.04, 0.05, 0.07, 0.88};
            text = "";
            size = 0.024;
            class Attributes { font = "PuristaMedium"; color = "#d2e8dc"; align = "left"; valign = "top"; shadow = 0; };
        };
        class SessionBtn: RscButton { idc = 60924; text = "Start session"; x = 0.04; y = 0.742; w = 0.92; h = 0.048; sizeEx = 0.034; colorBackground[] = {0.2, 0.4, 0.62, 1}; action = "['session', []] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]);"; };
    };
};
