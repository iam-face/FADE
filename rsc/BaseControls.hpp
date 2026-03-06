// =============================================================================
// BaseControls.hpp -- Minimal base UI classes (fallback when import fails)
// =============================================================================
// Arma 3 GUI control types: 0=CT_STATIC, 1=CT_BUTTON, 4=CT_COMBO, 5=CT_LISTBOX
// =============================================================================

class RscText {
    type = 0;
    idc = -1;
    style = 0;
    x = 0; y = 0; w = 0.1; h = 0.05;
    colorBackground[] = {0, 0, 0, 0};
    colorText[] = {1, 1, 1, 1};
    text = "";
    font = "PuristaMedium";
    sizeEx = 0.04;
};

class RscButton {
    type = 1;
    idc = -1;
    style = 2;
    x = 0; y = 0; w = 0.1; h = 0.05;
    colorBackground[] = {0.2, 0.2, 0.2, 1};
    colorText[] = {1, 1, 1, 1};
    colorDisabled[] = {1, 1, 1, 0.25};
    colorBackgroundActive[] = {0.3, 0.3, 0.3, 1};
    colorBackgroundDisabled[] = {0.2, 0.2, 0.2, 0.5};
    colorFocused[] = {0.3, 0.3, 0.3, 1};
    colorShadow[] = {0, 0, 0, 0.5};
    colorBorder[] = {0, 0, 0, 1};
    soundEnter[] = {"", 0, 0};
    soundPush[] = {"", 0, 0};
    soundClick[] = {"", 0, 0};
    soundEscape[] = {"", 0, 0};
    offsetX = 0; offsetY = 0;
    offsetPressedX = 0; offsetPressedY = 0;
    borderSize = 0;
    text = "";
    font = "PuristaMedium";
    sizeEx = 0.04;
};

class RscListBox {
    type = 5;
    idc = -1;
    style = 0;
    x = 0; y = 0; w = 0.1; h = 0.1;
    colorBackground[] = {0, 0, 0, 0.8};
    colorText[] = {1, 1, 1, 1};
    colorDisabled[] = {1, 1, 1, 0.25};
    colorSelect[] = {1, 1, 1, 1};
    colorSelect2[] = {1, 1, 1, 1};
    colorSelectBackground[] = {0.95, 0.95, 0.95, 0.3};
    colorSelectBackground2[] = {1, 1, 1, 0.5};
    font = "PuristaMedium";
    sizeEx = 0.04;
    rowHeight = 0.04;
    maxHistoryDelay = 1;
    soundSelect[] = {"", 0, 0};
    class ListScrollBar {
        color[] = {1, 1, 1, 0.6};
        colorActive[] = {1, 1, 1, 1};
        colorDisabled[] = {1, 1, 1, 0.3};
        thumb = "\a3\ui_f\data\gui\cfg\scrollbar\thumb_ca.paa";
        arrowFull = "\a3\ui_f\data\gui\cfg\scrollbar\arrowfull_ca.paa";
        arrowEmpty = "\a3\ui_f\data\gui\cfg\scrollbar\arrowempty_ca.paa";
        border = 0;
        size = 0;
    };
};

class RscPicture {
    type = 0;
    idc = -1;
    style = 48;
    x = 0; y = 0; w = 0.1; h = 0.1;
    colorBackground[] = {0, 0, 0, 0};
    colorText[] = {1, 1, 1, 1};
    text = "";
    font = "PuristaMedium";
    sizeEx = 0.04;
};

class RscStructuredText {
    type = 13;
    idc = -1;
    style = 0;
    x = 0; y = 0; w = 0.1; h = 0.05;
    colorBackground[] = {0, 0, 0, 0};
    colorText[] = {1, 1, 1, 1};
    text = "";
    font = "PuristaMedium";
    sizeEx = 0.04;
    class Attributes {
        font = "PuristaMedium";
        color = "#ffffff";
        align = "left";
        valign = "top";
        shadow = 0;
    };
};

class RscEdit {
    type = 2;
    idc = -1;
    style = 0;
    x = 0; y = 0; w = 0.1; h = 0.04;
    colorBackground[] = {0, 0, 0, 0.8};
    colorText[] = {1, 1, 1, 1};
    colorDisabled[] = {1, 1, 1, 0.25};
    colorSelection[] = {0.2, 0.4, 0.6, 0.8};
    font = "PuristaMedium";
    sizeEx = 0.04;
    text = "";
    autocomplete = "";
};

class RscCombo {
    type = 4;
    idc = -1;
    style = 0;
    x = 0; y = 0; w = 0.1; h = 0.04;
    colorBackground[] = {0, 0, 0, 0.8};
    colorText[] = {1, 1, 1, 1};
    colorDisabled[] = {1, 1, 1, 0.25};
    colorSelect[] = {1, 1, 1, 1};
    colorSelect2[] = {1, 1, 1, 1};
    colorSelectBackground[] = {0.95, 0.95, 0.95, 0.3};
    colorSelectBackground2[] = {1, 1, 1, 0.5};
    font = "PuristaMedium";
    sizeEx = 0.04;
};

// Map control (CT_MAP_MAIN = 101) -- fallback when game config not available
class RscMapControl {
    type = 101;
    idc = -1;
    x = 0; y = 0; w = 0.5; h = 0.5;
    colorBackground[] = {0.1, 0.1, 0.1, 1};
    colorText[] = {1, 1, 1, 1};
    scaleMin = 0.001;
    scaleMax = 1.0;
    scaleDefault = 0.16;
    maxSatelliteAlpha = 0.85;
    alphaFadeStartScale = 2.0;
    alphaFadeEndScale = 2.0;
    font = "EtelkaMonospacePro";
    sizeEx = 0.04;
};
