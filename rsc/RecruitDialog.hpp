// RscDisplayRecruit (idd 60940) — HQ recruit board: Recruit | Manage tabs

class RscDisplayRecruit: RscDisplayEmpty {
    idd = 60940;
    movingEnable = 1;
    enableSimulation = 1;
    onLoad = "[] spawn { sleep 0.01; ['onLoad', []] call (missionNamespace getVariable ['FAC_recruitGui_fnc', {}]); };";
    class controlsBackground {
        class Background: FACRscDialogBackground { x = 0.02; y = 0.025; w = 0.96; h = 0.95; };
        class HeaderBar: FACRscHeaderBar { x = 0.02; y = 0.025; w = 0.96; h = 0.065; };
        class MainPanel: FACRscMainPanel { x = 0.03; y = 0.092; w = 0.94; h = 0.868; };
    };
    class controls {
        class TitleText: FACRscDialogTitle { text = "RECRUIT UNITS"; x = 0.035; y = 0.032; w = 0.20; h = 0.052; };
        class TabRecruit: FACRscTabBtnActive { idc = 60941; text = "Recruit..."; x = 0.24; y = 0.036; w = 0.14; h = 0.046; sizeEx = 0.030; action = "['setTab', ['recruit']] call (missionNamespace getVariable ['FAC_recruitGui_fnc', {}]);"; };
        class TabRoster: FACRscTabBtn { idc = 60942; text = "Manage..."; x = 0.385; y = 0.036; w = 0.14; h = 0.046; sizeEx = 0.030; action = "['setTab', ['roster']] call (missionNamespace getVariable ['FAC_recruitGui_fnc', {}]);"; };
        class HeaderRefreshBtn: FACRscRefreshBtn { idc = 60945; action = "['headerRefresh', []] call (missionNamespace getVariable ['FAC_recruitGui_fnc', {}]);"; };
        class HeaderCloseBtn: FACRscCloseBtn { idc = 60946; y = 0.036; };

        // Recruit tab — source sub-tabs (inside main panel, not header)
        class SourceBtnPreset: FACRscTabBtnActive { idc = 60943; text = "Custom loadouts..."; x = 0.04; y = 0.102; w = 0.45; h = 0.042; sizeEx = 0.028; action = "['sourcePick', ['preset']] call (missionNamespace getVariable ['FAC_recruitGui_fnc', {}]);"; };
        class SourceBtnStd: FACRscTabBtn { idc = 60944; text = "Faction units..."; x = 0.51; y = 0.102; w = 0.45; h = 0.042; sizeEx = 0.028; action = "['sourcePick', ['std']] call (missionNamespace getVariable ['FAC_recruitGui_fnc', {}]);"; };

        // Recruit tab — assign + faction filter (same row)
        class AssignLabel: FACRscLabelMuted { idc = 60951; text = "Assign to group"; x = 0.04; y = 0.152; w = 0.44; h = 0.028; sizeEx = 0.028; };
        class FactionLabel: FACRscLabelMuted { idc = 60958; text = "Faction"; x = 0.51; y = 0.152; w = 0.45; h = 0.028; sizeEx = 0.028; };
        class AssignList: FACRscListDark { idc = 60952; x = 0.04; y = 0.182; w = 0.44; h = 0.12; rowHeight = 0.038; sizeEx = 0.030; };
        class FactionList: FACRscListDark { idc = 60949; x = 0.51; y = 0.182; w = 0.45; h = 0.12; rowHeight = 0.038; sizeEx = 0.030; onLBSelChanged = "['factionChanged', []] call (missionNamespace getVariable ['FAC_recruitGui_fnc', {}]);"; };

        // Recruit tab — search directly above unit list
        class SearchLabel: FACRscLabelMuted { idc = 60959; text = "Search"; x = 0.04; y = 0.318; w = 0.08; h = 0.028; sizeEx = 0.028; };
        class SearchEdit: FACRscEditDark { idc = 60950; x = 0.125; y = 0.316; w = 0.835; h = 0.034; sizeEx = 0.028; onKeyUp = "['filterChanged', []] call (missionNamespace getVariable ['FAC_recruitGui_fnc', {}]);"; };
        class UnitListLabel: FACRscLabelMuted { idc = 60947; text = "Choose unit to recruit"; x = 0.04; y = 0.356; w = 0.92; h = 0.028; sizeEx = 0.030; };
        class UnitList: FACRscListDark { idc = 60948; x = 0.04; y = 0.386; w = 0.92; h = 0.46; rowHeight = 0.038; sizeEx = 0.032; onLBSelChanged = "['unitSelChanged', []] call (missionNamespace getVariable ['FAC_recruitGui_fnc', {}]);"; };
        class RecruitBtn: FACRscPrimaryBtn { idc = 60953; text = "Recruit unit"; x = 0.04; y = 0.858; w = 0.92; h = 0.042; sizeEx = 0.030; action = "['recruit', []] call (missionNamespace getVariable ['FAC_recruitGui_fnc', {}]);"; };

        // Manage tab
        class RosterLabel: FACRscLabelMuted { idc = 60954; show = 0; text = "Recruited units (select to dismiss)"; x = 0.04; y = 0.102; w = 0.92; h = 0.028; sizeEx = 0.030; };
        class RosterList: FACRscListDark { idc = 60955; show = 0; x = 0.04; y = 0.132; w = 0.92; h = 0.72; rowHeight = 0.038; sizeEx = 0.032; style = 18; };
        class DismissBtn: RscButton { idc = 60956; show = 0; text = "Dismiss selected"; x = 0.04; y = 0.858; w = 0.92; h = 0.042; sizeEx = 0.030; colorBackground[] = FAC_COLOR_BTN_DANGER; colorText[] = FAC_COLOR_TEXT; action = "['dismiss', []] call (missionNamespace getVariable ['FAC_recruitGui_fnc', {}]);"; };
    };
};
