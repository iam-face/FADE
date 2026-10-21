// Shared terminal. Each dialog inherits this and keeps its own idd.
// FAC_gui_build fills the body from a spec. Chrome IDCs are 59900-59906.
class FAC_Terminal: RscDisplayEmpty {
    idd = -1;
    movingEnable = 1;
    enableSimulation = 1;
    class controlsBackground {
        class FAC_GuiBg: FACRscDialogBackground { idc = 59900; x = 0.02; y = 0.02; w = 0.96; h = 0.96; };
    };
    class controls {
        class FAC_GuiMain: FACRscMainPanel { idc = 59905; x = 0.03; y = 0.092; w = 0.94; h = 0.86; };
        class FAC_GuiHeader: FACRscHeaderBar { idc = 59904; x = 0.02; y = 0.02; w = 0.96; h = 0.065; };
        class FAC_GuiTitle: FACRscDialogTitle { idc = 59901; text = ""; x = 0.035; y = 0.028; w = 0.24; h = 0.052; };
        class FAC_GuiRefresh: FACRscRefreshBtn { idc = 59902; action = ""; };
        class FAC_GuiClose: FACRscCloseBtn { idc = 59903; };
    };
};
