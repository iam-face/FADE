// RscDisplayCivTalkV — ambient civilian dialogue (idd 60245)
// Vertical stack: slot1 = former UP … slot4 = former DOWN (same IDCs / logic).
// Optional: #include this from description.ext (or another dialog .hpp after RscDisplayEmpty) and use createDialog "RscDisplayCivTalkV".
// Until then, rsc\CivTalkGui.sqf FADE_civTalk_clientApplyVerticalLayout matches these positions at runtime for createDialog "RscDisplayCivTalk".
// Requires RscDisplayEmpty (description.ext / BaseControls.hpp).

class RscDisplayCivTalkV: RscDisplayEmpty {
    idd = 60245;
    movingEnable = 1;
    enableSimulation = 1;
    onLoad = "[] spawn { sleep 0.01; ['onLoad', []] call (missionNamespace getVariable ['FAC_civTalkGui_fnc', {}]); };";
    onUnload = "0 spawn { [] call (missionNamespace getVariable ['FADE_civTalk_clientClearPlayerAnim', {}]); if (!isNull player) then { player remoteExec ['FADE_civTalk_end', 2]; }; };";
    class controlsBackground {};
    class controls {
        class ReplyText: RscStructuredText {
            idc = 60247;
            x = 0.24; y = 0.54; w = 0.52; h = 0.12;
            colorBackground[] = {0.06, 0.07, 0.10, 0.78};
            text = "";
            size = 0.028;
            class Attributes { font = "PuristaMedium"; color = "#ffffff"; align = "left"; valign = "top"; shadow = 2; };
        };
        class LangBarrier: RscText { idc = 60252; text = ""; x = 0.24; y = 0.688; w = 0.52; h = 0.026; sizeEx = 0.022; colorText[] = {0.72, 0.76, 0.82, 1}; colorBackground[] = {0, 0, 0, 0}; style = 528; };
        class BtnUp: RscButton { idc = 60248; text = ""; x = 0.24; y = 0.722; w = 0.52; h = 0.044; sizeEx = 0.026; colorBackground[] = {0.14, 0.38, 0.20, 0.95}; colorText[] = {1, 1, 1, 1}; action = "['radial', ['up']] call (missionNamespace getVariable ['FAC_civTalkGui_fnc', {}]);"; };
        class BtnLeft: RscButton { idc = 60249; text = ""; x = 0.24; y = 0.772; w = 0.52; h = 0.044; sizeEx = 0.026; colorBackground[] = {0.20, 0.16, 0.42, 0.95}; colorText[] = {1, 1, 1, 1}; action = "['radial', ['left']] call (missionNamespace getVariable ['FAC_civTalkGui_fnc', {}]);"; };
        class BtnRight: RscButton { idc = 60250; text = ""; x = 0.24; y = 0.822; w = 0.52; h = 0.044; sizeEx = 0.026; colorBackground[] = {0.45, 0.32, 0.10, 0.95}; colorText[] = {1, 1, 1, 1}; action = "['radial', ['right']] call (missionNamespace getVariable ['FAC_civTalkGui_fnc', {}]);"; };
        class BtnDown: RscButton { idc = 60251; text = ""; x = 0.24; y = 0.872; w = 0.52; h = 0.044; sizeEx = 0.026; colorBackground[] = {0.42, 0.16, 0.16, 0.95}; colorText[] = {1, 1, 1, 1}; action = "['radial', ['down']] call (missionNamespace getVariable ['FAC_civTalkGui_fnc', {}]);"; };
        class Title: RscText { idc = 60246; text = "Talking to civilian"; x = 0.20; y = 0.928; w = 0.60; h = 0.028; sizeEx = 0.030; colorText[] = {1, 1, 1, 1}; colorBackground[] = {0, 0, 0, 0}; style = 2; shadow = 2; };
    };
};
