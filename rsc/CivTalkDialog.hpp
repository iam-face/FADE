// RscDisplayCivTalk — ambient civilian dialogue (idd 60245)
// Radial-style 4-way menu (Up / Left / Right / Down); reply text above hub.
// Requires RscDisplayEmpty + RscStructuredText (description.ext / BaseControls.hpp).

class RscDisplayCivTalk: RscDisplayEmpty {
    idd = 60245;
    movingEnable = 1;
    enableSimulation = 1;
    onLoad = "[] spawn { sleep 0.01; ['onLoad', []] call (missionNamespace getVariable ['FAC_civTalkGui_fnc', {}]); };";
    onUnload = "0 spawn { [] call (missionNamespace getVariable ['FADE_civTalk_clientClearPlayerAnim', {}]); if (!isNull player) then { player remoteExec ['FADE_civTalk_end', 2]; }; };";
    class controlsBackground {};
    class controls {
        class Title: RscText { idc = 60246; text = "Talking to civilian"; x = 0.20; y = 0.926; w = 0.60; h = 0.030; sizeEx = 0.032; colorText[] = {1, 1, 1, 1}; colorBackground[] = {0, 0, 0, 0}; style = 2; shadow = 2; };
        class LangBarrier: RscText { idc = 60252; text = ""; x = 0.14; y = 0.638; w = 0.72; h = 0.026; sizeEx = 0.022; colorText[] = {0.72, 0.76, 0.82, 1}; colorBackground[] = {0, 0, 0, 0}; style = 528; };
        class ReplyText: RscStructuredText {
            idc = 60247;
            x = 0.22; y = 0.52; w = 0.56; h = 0.14;
            colorBackground[] = {0.06, 0.07, 0.10, 0.78};
            text = "";
            size = 0.034;
            class Attributes { font = "PuristaMedium"; color = "#ffffff"; align = "center"; valign = "middle"; shadow = 2; };
        };
        class RadialCenter: RscText { idc = 60253; text = ""; x = 0.455; y = 0.798; w = 0.09; h = 0.055; colorBackground[] = {0, 0, 0, 0}; colorText[] = {0.55, 0.58, 0.65, 1}; sizeEx = 0.038; style = 2; };
        class BtnUp: RscButton { idc = 60248; text = ""; x = 0.375; y = 0.728; w = 0.25; h = 0.048; sizeEx = 0.026; colorBackground[] = {0.14, 0.38, 0.20, 0.95}; colorText[] = {1, 1, 1, 1}; action = "['radial', ['up']] call (missionNamespace getVariable ['FAC_civTalkGui_fnc', {}]);"; };
        class BtnLeft: RscButton { idc = 60249; text = ""; x = 0.14; y = 0.792; w = 0.25; h = 0.048; sizeEx = 0.026; colorBackground[] = {0.20, 0.16, 0.42, 0.95}; colorText[] = {1, 1, 1, 1}; action = "['radial', ['left']] call (missionNamespace getVariable ['FAC_civTalkGui_fnc', {}]);"; };
        class BtnRight: RscButton { idc = 60250; text = ""; x = 0.61; y = 0.792; w = 0.25; h = 0.048; sizeEx = 0.026; colorBackground[] = {0.45, 0.32, 0.10, 0.95}; colorText[] = {1, 1, 1, 1}; action = "['radial', ['right']] call (missionNamespace getVariable ['FAC_civTalkGui_fnc', {}]);"; };
        class BtnDown: RscButton { idc = 60251; text = ""; x = 0.375; y = 0.856; w = 0.25; h = 0.048; sizeEx = 0.026; colorBackground[] = {0.42, 0.16, 0.16, 0.95}; colorText[] = {1, 1, 1, 1}; action = "['radial', ['down']] call (missionNamespace getVariable ['FAC_civTalkGui_fnc', {}]);"; };
    };
};
