// RscDisplayLoadout (idd 60200) — tabbed header: Preset loadouts | Faction units
// Requires RscDisplayEmpty + FAC_DialogChrome (description.ext).

class RscDisplayLoadout: RscDisplayEmpty {
    idd = 60200;
    movingEnable = 1;
    enableSimulation = 1;
    onLoad = "[] spawn { sleep 0.01; ['onLoad', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]); };";
    class controlsBackground {
        class Background: FACRscDialogBackground { x = 0.02; y = 0.025; w = 0.96; h = 0.95; };
        class HeaderBar: FACRscHeaderBar { x = 0.02; y = 0.025; w = 0.96; h = 0.065; };
        class MainPanel: FACRscMainPanel { x = 0.03; y = 0.092; w = 0.94; h = 0.868; };
    };
    class controls {
        class TitleText: FACRscDialogTitle { text = "MANAGE LOADOUT"; x = 0.035; y = 0.032; w = 0.20; h = 0.052; };
        class SourceBtnPreset: FACRscTabBtnActive { idc = 60213; text = "Preset loadouts..."; x = 0.24; y = 0.036; w = 0.20; h = 0.046; sizeEx = 0.030; action = "['sourcePick', ['preset']] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class SourceBtnStd: FACRscTabBtn { idc = 60214; text = "Faction units..."; x = 0.445; y = 0.036; w = 0.20; h = 0.046; sizeEx = 0.030; action = "['sourcePick', ['std']] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class HeaderRefreshBtn: FACRscRefreshBtn { idc = 60230; action = "['headerRefresh', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class HeaderCloseBtn: FACRscCloseBtn { idc = 60231; y = 0.036; };
        class FactionList: FACRscListDark { idc = 60210; x = 0.04; y = 0.102; w = 0.38; h = 0.10; rowHeight = 0.038; sizeEx = 0.030; onLBSelChanged = "['filterChanged', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class SearchLabel: FACRscLabelMuted { idc = -1; text = "Search"; x = 0.435; y = 0.102; w = 0.08; h = 0.032; sizeEx = 0.028; };
        class SearchEdit: FACRscEditDark { idc = 60211; x = 0.515; y = 0.100; w = 0.445; h = 0.036; sizeEx = 0.028; onKeyUp = "['filterChanged', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class UnitListLabel: FACRscLabelMuted { idc = -1; text = "Choose loadout"; x = 0.04; y = 0.208; w = 0.92; h = 0.028; sizeEx = 0.030; };
        class UnitList: FACRscListDark { idc = 60201; x = 0.04; y = 0.238; w = 0.92; h = 0.36; rowHeight = 0.038; sizeEx = 0.032; onLBSelChanged = "['unitSelChanged', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class QuickAddHdr: FACRscSectionHdr { idc = -1; text = "Quick add items"; x = 0.04; y = 0.608; w = 0.92; h = 0.028; };
        class AddZiptiesBtn: FACRscPrimaryBtn { idc = 60215; text = "Zip ties x2"; x = 0.04; y = 0.642; w = 0.295; h = 0.034; sizeEx = 0.024; action = "['addZipties', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class AddIrStrobeBtn: FACRscPrimaryBtn { idc = 60216; text = "IR strobe"; x = 0.345; y = 0.642; w = 0.295; h = 0.034; sizeEx = 0.024; action = "['addIrStrobe', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class AddIfakBtn: FACRscPrimaryBtn { idc = 60217; text = "IFAK"; x = 0.65; y = 0.642; w = 0.31; h = 0.034; sizeEx = 0.024; action = "['addIfak', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class AddBandagesBtn: FACRscPrimaryBtn { idc = 60218; text = "Bandages"; x = 0.04; y = 0.682; w = 0.295; h = 0.034; sizeEx = 0.024; action = "['addBandages', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class Add343Btn: FACRscPrimaryBtn { idc = 60207; text = "Add 343"; x = 0.345; y = 0.682; w = 0.295; h = 0.034; sizeEx = 0.024; action = "['addRadio343', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class Add152Btn: FACRscPrimaryBtn { idc = 60208; text = "Add 152"; x = 0.65; y = 0.682; w = 0.31; h = 0.034; sizeEx = 0.024; action = "['addRadio152', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class ManageRolesHdr: FACRscSectionHdr { idc = -1; text = "Manage roles"; x = 0.04; y = 0.726; w = 0.92; h = 0.028; };
        class InterpreterMakeBtn: FACRscPrimaryBtn { idc = 60232; text = "Make me interpreter"; x = 0.04; y = 0.760; w = 0.45; h = 0.032; sizeEx = 0.022; action = "['setCivInterpreter', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class InterpreterRemoveBtn: RscButton { idc = 60233; text = "Remove interpreter"; x = 0.51; y = 0.760; w = 0.45; h = 0.032; sizeEx = 0.022; colorBackground[] = FAC_COLOR_BTN_NEUTRAL; colorText[] = FAC_COLOR_TEXT; action = "['clearCivInterpreter', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class IntelSpecMakeBtn: FACRscPrimaryBtn { idc = 60234; text = "Make me Intel specialist"; x = 0.04; y = 0.800; w = 0.45; h = 0.032; sizeEx = 0.022; action = "['setIntelSpecialist', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class IntelSpecRemoveBtn: RscButton { idc = 60235; text = "Remove Intel specialist"; x = 0.51; y = 0.800; w = 0.45; h = 0.032; sizeEx = 0.022; colorBackground[] = FAC_COLOR_BTN_NEUTRAL; colorText[] = FAC_COLOR_TEXT; action = "['clearIntelSpecialist', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class SavedStatusLabel: RscText { idc = 60205; text = ""; x = 0.04; y = 0.878; w = 0.92; h = 0.026; sizeEx = 0.024; colorText[] = FAC_COLOR_TEXT_MUTED; };
        class ApplyBtn: FACRscPrimaryBtn { idc = 60202; text = "Apply to me"; x = 0.04; y = 0.910; w = 0.22; h = 0.038; sizeEx = 0.028; action = "['apply', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class ApplyToSquadBtn: FACRscPrimaryBtn { idc = 60219; text = "Apply to..."; x = 0.27; y = 0.910; w = 0.18; h = 0.038; sizeEx = 0.028; show = 0; action = "['applyToToggle', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class SaveBtn: FACRscPrimaryBtn { idc = 60204; text = "Save loadout"; x = 0.46; y = 0.910; w = 0.26; h = 0.038; sizeEx = 0.028; action = "['saveLoadout', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class RestoreBtn: FACRscPrimaryBtn { idc = 60206; text = "Restore saved"; x = 0.73; y = 0.910; w = 0.23; h = 0.038; sizeEx = 0.028; action = "['restoreLoadout', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class ApplyToPanelBg: RscText { idc = 60222; x = 0.22; y = 0.455; w = 0.56; h = 0.30; colorBackground[] = FAC_COLOR_BG_PANEL; show = 0; };
        class ApplyToTitle: RscText { idc = 60224; text = "Apply selected loadout to squad member:"; x = 0.24; y = 0.465; w = 0.52; h = 0.034; sizeEx = 0.03; colorText[] = FAC_COLOR_TEXT; show = 0; };
        class ApplyToMemberList: FACRscListDark { idc = 60220; x = 0.24; y = 0.505; w = 0.52; h = 0.18; rowHeight = 0.038; sizeEx = 0.030; show = 0; };
        class ApplyToConfirmBtn: FACRscPrimaryBtn { idc = 60221; text = "Apply to selected"; x = 0.24; y = 0.695; w = 0.25; h = 0.04; sizeEx = 0.028; show = 0; action = "['applyToConfirm', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class ApplyToCancelBtn: RscButton { idc = 60223; text = "Cancel"; x = 0.51; y = 0.695; w = 0.25; h = 0.04; sizeEx = 0.028; show = 0; colorBackground[] = FAC_COLOR_BTN_NEUTRAL; colorText[] = FAC_COLOR_TEXT; action = "['applyToCancel', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
    };
};
