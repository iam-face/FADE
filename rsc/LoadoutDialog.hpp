// RscDisplayLoadout (idd 60200) — single definition for createDialog "RscDisplayLoadout".
// Requires RscDisplayEmpty (defined in description.ext before this include).

class RscDisplayLoadout: RscDisplayEmpty {
    idd = 60200;
    movingEnable = 1;
    enableSimulation = 1;
    onLoad = "[] spawn { sleep 0.01; ['onLoad', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]); };";
    class controlsBackground {
        class Background: RscText { idc = -1; x = 0.005; y = 0.02; w = 0.99; h = 0.96; colorBackground[] = {0.1, 0.1, 0.15, 0.95}; };
        class Title: RscText { idc = -1; text = "MANAGE MY LOADOUT"; x = 0.005; y = 0.02; w = 0.99; h = 0.05; colorBackground[] = {0.2, 0.4, 0.6, 1}; colorText[] = {1, 1, 1, 1}; sizeEx = 0.05; };
    };
    class controls {
        class HeaderRefreshBtn: RscButton { idc = 60230; text = "Refresh"; x = 0.84; y = 0.028; w = 0.058; h = 0.042; sizeEx = 0.028; colorBackground[] = {0.18, 0.32, 0.48, 1}; action = "['headerRefresh', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class HeaderCloseBtn: RscButton { idc = 60231; text = "X"; x = 0.905; y = 0.028; w = 0.048; h = 0.042; sizeEx = 0.034; colorBackground[] = {0.35, 0.22, 0.22, 1}; action = "closeDialog 0;"; };
        class SourceLabel: RscText { idc = -1; text = "Loadout source:"; x = 0.02; y = 0.088; w = 0.16; h = 0.032; sizeEx = 0.032; };
        class SourceBtnCtb: RscButton { idc = 60213; text = "CTB Loadouts"; x = 0.18; y = 0.082; w = 0.40; h = 0.042; sizeEx = 0.034; action = "['sourcePick', ['ctb']] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class SourceBtnStd: RscButton { idc = 60214; text = "Faction Units"; x = 0.59; y = 0.082; w = 0.39; h = 0.042; sizeEx = 0.034; action = "['sourcePick', ['std']] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class UnitListLabel: RscText { idc = -1; text = "Choose my loadout:"; x = 0.02; y = 0.125; w = 0.96; h = 0.03; sizeEx = 0.032; };
        class UnitList: RscListBox { idc = 60201; x = 0.02; y = 0.16; w = 0.96; h = 0.49; rowHeight = 0.038; sizeEx = 0.035; onLBSelChanged = "['unitSelChanged', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class FactionList: RscListBox { idc = 60210; x = 0.02; y = 0.66; w = 0.384; h = 0.17; rowHeight = 0.042; sizeEx = 0.038; onLBSelChanged = "['filterChanged', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class SearchLabel: RscText { idc = -1; text = "Search:"; x = 0.414; y = 0.66; w = 0.08; h = 0.04; sizeEx = 0.032; };
        class SearchEdit: RscEdit { idc = 60211; x = 0.504; y = 0.66; w = 0.476; h = 0.04; onKeyUp = "['filterChanged', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class AddZiptiesBtn: RscButton { idc = 60215; text = "ZIP TIES x2"; x = 0.415; y = 0.714; w = 0.182; h = 0.036; sizeEx = 0.028; action = "['addZipties', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class AddIrStrobeBtn: RscButton { idc = 60216; text = "IR STROBE"; x = 0.603; y = 0.714; w = 0.182; h = 0.036; sizeEx = 0.028; action = "['addIrStrobe', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class AddIfakBtn: RscButton { idc = 60217; text = "IFAK"; x = 0.791; y = 0.714; w = 0.182; h = 0.036; sizeEx = 0.028; action = "['addIfak', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class AddBandagesBtn: RscButton { idc = 60218; text = "BANDAGES"; x = 0.415; y = 0.756; w = 0.182; h = 0.036; sizeEx = 0.028; action = "['addBandages', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class Add343Btn: RscButton { idc = 60207; text = "ADD 343"; x = 0.603; y = 0.756; w = 0.182; h = 0.036; sizeEx = 0.028; action = "['addRadio343', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class Add152Btn: RscButton { idc = 60208; text = "ADD 152"; x = 0.791; y = 0.756; w = 0.182; h = 0.036; sizeEx = 0.028; action = "['addRadio152', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class ApplyBtn: RscButton { idc = 60202; text = "APPLY TO ME"; x = 0.02; y = 0.926; w = 0.22; h = 0.036; sizeEx = 0.028; action = "['apply', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class ApplyToSquadBtn: RscButton { idc = 60219; text = "APPLY TO..."; x = 0.248; y = 0.926; w = 0.17; h = 0.036; sizeEx = 0.028; show = 0; action = "['applyToToggle', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class SaveBtn: RscButton { idc = 60204; text = "SAVE LOADOUT"; x = 0.426; y = 0.926; w = 0.27; h = 0.036; sizeEx = 0.028; action = "['saveLoadout', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class RestoreBtn: RscButton { idc = 60206; text = "RESTORE SAVED"; x = 0.704; y = 0.926; w = 0.276; h = 0.036; sizeEx = 0.028; action = "['restoreLoadout', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class SavedStatusLabel: RscText { idc = 60205; text = ""; x = 0.02; y = 0.882; w = 0.96; h = 0.026; sizeEx = 0.026; };
        class ApplyToPanelBg: RscText { idc = 60222; x = 0.22; y = 0.455; w = 0.56; h = 0.30; colorBackground[] = {0.05, 0.05, 0.08, 0.92}; show = 0; };
        class ApplyToTitle: RscText { idc = 60224; text = "Apply selected loadout to squad member:"; x = 0.24; y = 0.465; w = 0.52; h = 0.034; sizeEx = 0.03; colorText[] = {1, 1, 1, 1}; show = 0; };
        class ApplyToMemberList: RscListBox { idc = 60220; x = 0.24; y = 0.505; w = 0.52; h = 0.18; rowHeight = 0.038; sizeEx = 0.032; show = 0; };
        class ApplyToConfirmBtn: RscButton { idc = 60221; text = "APPLY TO SELECTED"; x = 0.24; y = 0.695; w = 0.25; h = 0.04; sizeEx = 0.03; show = 0; action = "['applyToConfirm', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
        class ApplyToCancelBtn: RscButton { idc = 60223; text = "CANCEL"; x = 0.51; y = 0.695; w = 0.25; h = 0.04; sizeEx = 0.03; show = 0; action = "['applyToCancel', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]);"; };
    };
};
