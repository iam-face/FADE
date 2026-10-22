// Join wait (idd 60962), confirm (idd 60960), vote (idd 60961), deploy card (idd 60963).

class RscDisplayBasePickWait: RscDisplayEmpty {
    idd = 60962;
    movingEnable = 0;
    enableSimulation = 1;
    onLoad = "['onLoadWait', _this] call (missionNamespace getVariable ['FAC_basePick_fnc', {}]);";
    onKeyDown = "true";
    onUnload = "if (missionNamespace getVariable ['FAC_basePick_waitOn', false]) then { [] spawn { sleep 0.05; if (missionNamespace getVariable ['FAC_basePick_waitOn', false] && { isNull findDisplay 60962 }) then { createDialog 'RscDisplayBasePickWait' } } };";
    class controlsBackground {
        class Black: RscText {
            idc = -1;
            x = -1;
            y = -1;
            w = 3;
            h = 3;
            text = "";
            colorBackground[] = {0, 0, 0, 1};
        };
    };
    class controls {
        class Line: RscStructuredText {
            idc = 60990;
            x = safezoneX + (safezoneW * 0.15);
            y = safezoneY + (safezoneH * 0.36);
            w = safezoneW * 0.70;
            h = safezoneH * 0.28;
            text = "";
            size = 0.045;
            colorBackground[] = {0, 0, 0, 0};
            class Attributes {
                font = "PuristaMedium";
                color = "#ffffff";
                align = "center";
                shadow = 0;
            };
        };
    };
};


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
    onLoad = "['onLoadVote', _this] call (missionNamespace getVariable ['FAC_basePick_fnc', {}]);";
    onKeyDown = "private _k = _this select 1; _k == 1 || { _k in (actionKeys 'ShowMap') }";
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
            colorText[] = {1, 1, 1, 1};
            colorSelect[] = {1, 1, 1, 1};
            colorSelect2[] = {1, 1, 1, 1};
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

class RscDisplayBasePickDeploy: RscDisplayEmpty {
    idd = 60963;
    movingEnable = 0;
    enableSimulation = 1;
    onKeyDown = "true";
    class controlsBackground {
        class Black: RscText {
            idc = -1;
            x = -1;
            y = -1;
            w = 3;
            h = 3;
            text = "";
            colorBackground[] = {0, 0, 0, 1};
        };
    };
    class controls {
        class Line: RscStructuredText {
            idc = 60991;
            x = safezoneX + (safezoneW * 0.12);
            y = safezoneY + (safezoneH * 0.38);
            w = safezoneW * 0.76;
            h = safezoneH * 0.24;
            text = "";
            size = 0.045;
            colorBackground[] = {0, 0, 0, 0};
            class Attributes {
                font = "PuristaMedium";
                color = "#ffffff";
                align = "center";
                shadow = 0;
            };
        };
    };
};
