// =============================================================================
// FAC_DialogChrome.hpp — reusable FADE dialog chrome (neutral tabbed terminals)
// Requires FAC_Theme.hpp + BaseControls.hpp
// =============================================================================

class FACRscDialogBackground: RscText {
    idc = -1;
    colorBackground[] = FAC_COLOR_BG_PANEL;
};

class FACRscHeaderBar: RscText {
    idc = -1;
    colorBackground[] = FAC_COLOR_BG_HEADER;
    colorText[] = FAC_COLOR_TEXT;
};

class FACRscMainPanel: RscText {
    idc = -1;
    colorBackground[] = FAC_COLOR_BG_MAIN;
};

class FACRscDialogTitle: RscText {
    idc = -1;
    sizeEx = 0.038;
    colorText[] = FAC_COLOR_TEXT;
    colorBackground[] = {0, 0, 0, 0};
};

class FACRscTabBtn: RscButton {
    sizeEx = 0.032;
    colorBackground[] = FAC_COLOR_TAB_IDLE;
    colorText[] = FAC_COLOR_TEXT;
    colorBackgroundActive[] = FAC_COLOR_TAB_ACTIVE;
    colorFocused[] = FAC_COLOR_TAB_ACTIVE;
};

class FACRscTabBtnActive: FACRscTabBtn {
    colorBackground[] = FAC_COLOR_TAB_ACTIVE;
};

class FACRscRefreshBtn: RscButton {
    text = "Refresh";
    x = FAC_CHROME_REFRESH_X;
    y = 0.036;
    w = 0.092;
    h = 0.046;
    sizeEx = 0.028;
    colorBackground[] = FAC_COLOR_BTN_NEUTRAL;
    colorText[] = FAC_COLOR_TEXT;
};

class FACRscCloseBtn: RscButton {
    text = "X";
    x = FAC_CHROME_CLOSE_X;
    y = 0.036;
    w = 0.048;
    h = 0.046;
    sizeEx = 0.034;
    colorBackground[] = FAC_COLOR_BTN_DANGER;
    colorText[] = FAC_COLOR_TEXT;
    action = "closeDialog 0;";
};

class FACRscPrimaryBtn: RscButton {
    colorBackground[] = FAC_COLOR_BTN_PRIMARY;
    colorBackgroundActive[] = FAC_COLOR_BTN_PRIMARY_A;
    colorFocused[] = FAC_COLOR_BTN_PRIMARY_A;
    colorText[] = FAC_COLOR_TEXT;
};

class FACRscDangerBtn: RscButton {
    colorBackground[] = FAC_COLOR_BTN_DANGER;
    colorBackgroundActive[] = {0.62, 0.18, 0.18, 1};
    colorFocused[] = {0.62, 0.18, 0.18, 1};
    colorText[] = FAC_COLOR_TEXT;
};

class FACRscSectionHdr: RscText {
    sizeEx = 0.030;
    colorText[] = FAC_COLOR_TEXT_HDR;
};

class FACRscLabelMuted: RscText {
    sizeEx = 0.024;
    colorText[] = FAC_COLOR_TEXT_MUTED;
};

class FACRscListDark: RscListBox {
    colorBackground[] = FAC_COLOR_BG_LIST;
    colorSelectBackground[] = FAC_COLOR_LIST_SEL;
    colorSelectBackground2[] = FAC_COLOR_LIST_SEL;
};

class FACRscEditDark: RscEdit {
    colorBackground[] = FAC_COLOR_BG_INPUT;
    colorText[] = FAC_COLOR_TEXT;
};
