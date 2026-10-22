// Player-base confirm (idd 60960) and vote (idd 60961). Shown over the map.

class RscDisplayBasePickConfirm: RscDisplayEmpty {
    idd = 60960;
    movingEnable = 1;
    enableSimulation = 1;
    onLoad = "['onLoadConfirm', []] call (missionNamespace getVariable ['FAC_basePick_fnc', {}]);";
    class controlsBackground {
        class Background: FACRscDialogBackground { x = 0.32; y = 0.36; w = 0.36; h = 0.24; };
        class HeaderBar: FACRscHeaderBar { x = 0.32; y = 0.36; w = 0.36; h = 0.055; };
        class MainPanel: FACRscMainPanel { x = 0.33; y = 0.42; w = 0.34; h = 0.17; };
    };
    class controls {
        class TitleText: FACRscDialogTitle { text = "PLAYER BASE"; x = 0.335; y = 0.366; w = 0.24; h = 0.044; };
        class GridText: FACRscLabelMuted { idc = 60971; text = ""; x = 0.35; y = 0.44; w = 0.30; h = 0.04; sizeEx = 0.032; };
        class ConfirmBtn: FACRscPrimaryBtn {
            idc = 60972;
            text = "Confirm";
            x = 0.35;
            y = 0.51;
            w = 0.14;
            h = 0.05;
            sizeEx = 0.032;
            action = "['confirmYes', []] call (missionNamespace getVariable ['FAC_basePick_fnc', {}]);";
        };
        class CancelBtn: FACRscPrimaryBtn {
            idc = 60973;
            text = "Cancel";
            x = 0.51;
            y = 0.51;
            w = 0.14;
            h = 0.05;
            sizeEx = 0.032;
            action = "['confirmNo', []] call (missionNamespace getVariable ['FAC_basePick_fnc', {}]);";
        };
    };
};

class RscDisplayBasePickVote: RscDisplayEmpty {
    idd = 60961;
    movingEnable = 1;
    enableSimulation = 1;
    onLoad = "['onLoadVote', []] call (missionNamespace getVariable ['FAC_basePick_fnc', {}]);";
    class controlsBackground {
        class Background: FACRscDialogBackground { x = 0.30; y = 0.28; w = 0.40; h = 0.42; };
        class HeaderBar: FACRscHeaderBar { x = 0.30; y = 0.28; w = 0.40; h = 0.055; };
        class MainPanel: FACRscMainPanel { x = 0.31; y = 0.34; w = 0.38; h = 0.35; };
    };
    class controls {
        class TitleText: FACRscDialogTitle { text = "VOTE"; x = 0.315; y = 0.286; w = 0.20; h = 0.044; };
        class CountdownText: FACRscLabelMuted { idc = 60981; text = ""; x = 0.33; y = 0.36; w = 0.34; h = 0.035; sizeEx = 0.028; };
        class ChoiceList: FACRscListDark {
            idc = 60980;
            x = 0.33;
            y = 0.40;
            w = 0.34;
            h = 0.18;
            rowHeight = 0.036;
            sizeEx = 0.030;
        };
        class VoteBtn: FACRscPrimaryBtn {
            idc = 60982;
            text = "Vote";
            x = 0.33;
            y = 0.60;
            w = 0.34;
            h = 0.05;
            sizeEx = 0.032;
            action = "['vote', []] call (missionNamespace getVariable ['FAC_basePick_fnc', {}]);";
        };
    };
};
