// Firing / AT range — terminalRange (60920). Vehicle-GUI style: blue header, full-width panel, 3 tabs + friendly spawn/slots sub-tabs.
class RscDisplayRange: RscDisplayEmpty {
    idd = 60920;
    movingEnable = 1;
    enableSimulation = 1;
    onLoad = "0 spawn { sleep 0.01; ['onLoad', []] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]); };";
    class controlsBackground {
        class Background: RscText { idc = -1; x = 0.02; y = 0.025; w = 0.96; h = 0.855; colorBackground[] = {0.05, 0.06, 0.09, 0.98}; };
        class HeaderBar: RscText { idc = -1; x = 0.02; y = 0.025; w = 0.96; h = 0.065; colorBackground[] = {0.08, 0.14, 0.28, 1}; };
        class MainPanel: RscText { idc = 60981; x = 0.03; y = 0.098; w = 0.94; h = 0.768; colorBackground[] = {0.03, 0.04, 0.07, 0.55}; };
    };
    class controls {
        class TitleText: RscText { idc = -1; text = "FIRING + AT RANGE"; x = 0.035; y = 0.032; w = 0.20; h = 0.048; sizeEx = 0.034; colorText[] = {1, 1, 1, 1}; colorBackground[] = {0, 0, 0, 0}; };
        class TabRange: RscButton { idc = 60960; text = "Range"; x = 0.235; y = 0.036; w = 0.12; h = 0.046; sizeEx = 0.03; colorBackground[] = {0.22, 0.48, 0.78, 1}; colorText[] = {1, 1, 1, 1}; action = "['setTab', ['range']] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class TabOpforAt: RscButton { idc = 60961; text = "OPFOR / AT"; x = 0.362; y = 0.036; w = 0.14; h = 0.046; sizeEx = 0.028; colorBackground[] = {0.07, 0.11, 0.20, 1}; colorText[] = {0.92, 0.92, 0.95, 1}; action = "['setTab', ['opfor']] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class TabFriendly: RscButton { idc = 60978; text = "Friendly"; x = 0.508; y = 0.036; w = 0.12; h = 0.046; sizeEx = 0.03; colorBackground[] = {0.07, 0.11, 0.20, 1}; colorText[] = {0.92, 0.92, 0.95, 1}; action = "['setTab', ['friendly']] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class HeaderRefreshBtn: RscButton { idc = 60921; text = "Refresh"; x = 0.805; y = 0.036; w = 0.092; h = 0.046; sizeEx = 0.028; colorBackground[] = {0.18, 0.19, 0.22, 1}; colorText[] = {0.9, 0.9, 0.92, 1}; action = "['headerRefresh', []] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class CloseHeaderBtn: RscButton { idc = 60922; text = "X"; x = 0.905; y = 0.036; w = 0.048; h = 0.046; sizeEx = 0.034; colorBackground[] = {0.55, 0.12, 0.12, 1}; colorText[] = {1, 1, 1, 1}; action = "closeDialog 0;"; };

        // ----- Range tab -----
        class StatusLabel: RscText { idc = 60962; text = "Range status"; x = 0.04; y = 0.108; w = 0.20; h = 0.022; sizeEx = 0.024; colorText[] = {0.65, 0.68, 0.75, 1}; };
        class StatusValue: RscText { idc = 60923; text = "INACTIVE"; x = 0.20; y = 0.108; w = 0.26; h = 0.022; sizeEx = 0.024; colorText[] = {0.55, 0.95, 0.7, 1}; style = 2; };
        class MySettingsHdr: RscText { idc = 60963; text = "My settings"; x = 0.04; y = 0.138; w = 0.40; h = 0.022; sizeEx = 0.026; colorText[] = {0.85, 0.9, 1, 1}; };
        class TraceLabel: RscText { idc = 60964; text = "Projectile trace"; x = 0.04; y = 0.164; w = 0.38; h = 0.020; sizeEx = 0.022; colorText[] = {0.75, 0.78, 0.82, 1}; };
        class BtnTraceOff: RscButton { idc = 60924; text = "Off"; x = 0.04; y = 0.186; w = 0.195; h = 0.034; sizeEx = 0.026; colorBackground[] = {0.22, 0.48, 0.78, 1}; action = "['setTrace', [false]] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class BtnTraceOn: RscButton { idc = 60925; text = "On"; x = 0.245; y = 0.186; w = 0.195; h = 0.034; sizeEx = 0.026; colorBackground[] = {0.07, 0.11, 0.20, 1}; action = "['setTrace', [true]] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class HitLabel: RscText { idc = 60965; text = "Hit feedback"; x = 0.04; y = 0.226; w = 0.38; h = 0.020; sizeEx = 0.022; colorText[] = {0.75, 0.78, 0.82, 1}; };
        class BtnHitOff: RscButton { idc = 60926; text = "Off"; x = 0.04; y = 0.248; w = 0.195; h = 0.034; sizeEx = 0.026; colorBackground[] = {0.22, 0.48, 0.78, 1}; action = "['setHitTrack', [false]] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class BtnHitOn: RscButton { idc = 60927; text = "On"; x = 0.245; y = 0.248; w = 0.195; h = 0.034; sizeEx = 0.026; colorBackground[] = {0.07, 0.11, 0.20, 1}; action = "['setHitTrack', [true]] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class RangeSettingsHdr: RscText { idc = 60966; text = "Session targets"; x = 0.04; y = 0.288; w = 0.40; h = 0.022; sizeEx = 0.026; colorText[] = {0.85, 0.9, 1, 1}; };
        class ThreatLabel: RscText { idc = 60967; text = "Human target type"; x = 0.04; y = 0.314; w = 0.38; h = 0.020; sizeEx = 0.022; colorText[] = {0.75, 0.78, 0.82, 1}; };
        class BtnThreatTargets: RscButton { idc = 60928; text = "Pop-up targets"; x = 0.04; y = 0.336; w = 0.195; h = 0.036; sizeEx = 0.025; colorBackground[] = {0.22, 0.48, 0.78, 1}; action = "['setThreat', ['targets']] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class BtnThreatLive: RscButton { idc = 60929; text = "Live OPFOR"; x = 0.245; y = 0.336; w = 0.195; h = 0.036; sizeEx = 0.025; colorBackground[] = {0.07, 0.11, 0.20, 1}; action = "['setThreat', ['enemies']] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class HumanCountLabel: RscText { idc = 60968; text = "Human targets"; x = 0.04; y = 0.378; w = 0.22; h = 0.020; sizeEx = 0.022; colorText[] = {0.75, 0.78, 0.82, 1}; };
        class HumanCountValue: RscText { idc = 60930; text = "10"; x = 0.30; y = 0.378; w = 0.14; h = 0.020; sizeEx = 0.022; style = 2; colorText[] = {0.78, 0.95, 0.88, 1}; };
        class HumanCountSlider: RscXSliderH { idc = 60931; x = 0.04; y = 0.400; w = 0.40; h = 0.028; onSliderPosChanged = "['setHumanCount', [_this select 1]] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class VehCountLabel: RscText { idc = 60969; text = "Vehicle targets"; x = 0.04; y = 0.434; w = 0.22; h = 0.020; sizeEx = 0.022; colorText[] = {0.75, 0.78, 0.82, 1}; };
        class VehCountValue: RscText { idc = 60932; text = "0"; x = 0.30; y = 0.434; w = 0.14; h = 0.020; sizeEx = 0.022; style = 2; colorText[] = {0.78, 0.95, 0.88, 1}; };
        class VehCountSlider: RscXSliderH { idc = 60933; x = 0.04; y = 0.456; w = 0.40; h = 0.028; onSliderPosChanged = "['setVehCount', [_this select 1]] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class ModeLabel: RscText { idc = 60970; text = "Mode"; x = 0.04; y = 0.490; w = 0.38; h = 0.020; sizeEx = 0.022; colorText[] = {0.75, 0.78, 0.82, 1}; };
        class BtnModeFiring: RscButton { idc = 60934; text = "Firing range"; x = 0.04; y = 0.512; w = 0.195; h = 0.034; sizeEx = 0.025; colorBackground[] = {0.22, 0.48, 0.78, 1}; action = "['setMode', ['firing']] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class BtnModeTrial: RscButton { idc = 60935; text = "Time trial"; x = 0.245; y = 0.512; w = 0.195; h = 0.034; sizeEx = 0.025; colorBackground[] = {0.07, 0.11, 0.20, 1}; action = "['setMode', ['trial']] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class MaxRangeLabel: RscText { idc = 60971; text = "Max spawn distance (2D, m)"; x = 0.04; y = 0.552; w = 0.26; h = 0.020; sizeEx = 0.021; colorText[] = {0.75, 0.78, 0.82, 1}; };
        class MaxRangeValue: RscText { idc = 60936; text = "200 m"; x = 0.31; y = 0.552; w = 0.13; h = 0.020; sizeEx = 0.022; style = 2; colorText[] = {0.78, 0.95, 0.88, 1}; };
        class MaxRangeSlider: RscXSliderH { idc = 60937; x = 0.04; y = 0.574; w = 0.40; h = 0.028; onSliderPosChanged = "['setMaxRange', [_this select 1]] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class RangeHelpText: RscText { idc = 60988; text = "Lanes within this distance (from you) are used for session spawns and for friendly / AT slot actions."; x = 0.48; y = 0.108; w = 0.48; h = 0.12; sizeEx = 0.022; colorText[] = {0.72, 0.76, 0.82, 1}; style = 16; };

        class SessionBtn: RscButton { idc = 60938; text = "Start session"; x = 0.04; y = 0.818; w = 0.92; h = 0.046; sizeEx = 0.032; colorBackground[] = {0.22, 0.48, 0.78, 1}; colorBackgroundActive[] = {0.28, 0.55, 0.88, 1}; action = "['session', []] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };

        // ----- OPFOR / AT tab -----
        class VehTypeLabel: RscText { idc = 60973; text = "OPFOR vehicle types (session)"; x = 0.04; y = 0.108; w = 0.50; h = 0.024; sizeEx = 0.026; colorText[] = {0.85, 0.9, 1, 1}; };
        class BtnVehCar: RscButton { idc = 60939; text = "Car"; x = 0.04; y = 0.136; w = 0.115; h = 0.036; sizeEx = 0.024; colorBackground[] = {0.22, 0.48, 0.78, 1}; action = "['toggleVehType', ['car']] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class BtnVehTruck: RscButton { idc = 60940; text = "Truck"; x = 0.165; y = 0.136; w = 0.115; h = 0.036; sizeEx = 0.024; colorBackground[] = {0.22, 0.48, 0.78, 1}; action = "['toggleVehType', ['truck']] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class BtnVehApc: RscButton { idc = 60941; text = "APC"; x = 0.29; y = 0.136; w = 0.105; h = 0.036; sizeEx = 0.024; colorBackground[] = {0.22, 0.48, 0.78, 1}; action = "['toggleVehType', ['apc']] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class BtnVehTank: RscButton { idc = 60942; text = "Tank"; x = 0.405; y = 0.136; w = 0.105; h = 0.036; sizeEx = 0.024; colorBackground[] = {0.22, 0.48, 0.78, 1}; action = "['toggleVehType', ['tank']] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class VehClassMapInfo: RscText { idc = 60943; text = "Classes from mission Config / placeholders. Random pick per spawn when type enabled."; x = 0.04; y = 0.178; w = 0.90; h = 0.036; sizeEx = 0.021; colorText[] = {0.72, 0.76, 0.82, 1}; style = 16; };
        class AtHdr: RscText { idc = 60974; text = "AT weapons — rangeGunPos_1..6"; x = 0.04; y = 0.218; w = 0.55; h = 0.024; sizeEx = 0.026; colorText[] = {0.85, 0.9, 1, 1}; };
        class AtWeaponList: RscListBox { idc = 60944; x = 0.04; y = 0.246; w = 0.44; h = 0.36; rowHeight = 0.032; sizeEx = 0.026; colorBackground[] = {0.02, 0.03, 0.05, 0.95}; colorSelectBackground[] = {0.15, 0.35, 0.55, 0.75}; };
        class AtSlotList: RscListBox { idc = 60945; x = 0.50; y = 0.246; w = 0.44; h = 0.36; rowHeight = 0.032; sizeEx = 0.026; colorBackground[] = {0.02, 0.03, 0.05, 0.95}; colorSelectBackground[] = {0.15, 0.35, 0.55, 0.75}; };
        class AtSpawnBtn: RscButton { idc = 60946; text = "Spawn AT at slot"; x = 0.04; y = 0.618; w = 0.44; h = 0.042; sizeEx = 0.028; colorBackground[] = {0.22, 0.48, 0.78, 1}; colorBackgroundActive[] = {0.28, 0.55, 0.88, 1}; action = "['spawnAtWeapon', []] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class AtDespawnBtn: RscButton { idc = 60947; text = "Despawn AT slot"; x = 0.50; y = 0.618; w = 0.44; h = 0.042; sizeEx = 0.028; colorBackground[] = {0.36, 0.22, 0.16, 1}; colorBackgroundActive[] = {0.44, 0.28, 0.20, 1}; action = "['despawnAtWeapon', []] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class InfoPanel: RscStructuredText {
            idc = 60948;
            x = 0.04; y = 0.672; w = 0.90; h = 0.10;
            colorBackground[] = {0.02, 0.03, 0.05, 0.88};
            text = "";
            size = 0.022;
            class Attributes { font = "PuristaMedium"; color = "#c8d8e8"; align = "left"; valign = "top"; shadow = 0; };
        };

        // ----- Friendly tab: sub-tabs (Vehicle GUI pattern) -----
        class FrSubTabSpawn: RscButton { idc = 60979; text = "Spawn..."; x = 0.04; y = 0.108; w = 0.18; h = 0.040; sizeEx = 0.028; colorBackground[] = {0.22, 0.48, 0.78, 1}; colorText[] = {1, 1, 1, 1}; action = "['setFriendlySub', ['spawn']] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class FrSubTabSlots: RscButton { idc = 60980; text = "Slots…"; x = 0.228; y = 0.108; w = 0.18; h = 0.040; sizeEx = 0.028; colorBackground[] = {0.07, 0.11, 0.20, 1}; colorText[] = {0.92, 0.92, 0.95, 1}; action = "['setFriendlySub', ['slots']] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class FrSectionHelp: RscText { idc = 60972; text = "Same land list as main Vehicle Spawner. Use Range tab for max spawn distance (100–300 m)."; x = 0.42; y = 0.108; w = 0.52; h = 0.040; sizeEx = 0.021; colorText[] = {0.72, 0.76, 0.82, 1}; style = 16; };
        class FrSearchLabel: RscText { idc = 60982; text = "Search"; x = 0.04; y = 0.158; w = 0.12; h = 0.020; sizeEx = 0.022; colorText[] = {0.65, 0.68, 0.75, 1}; };
        class FrSearchEdit: RscEdit { idc = 60983; x = 0.04; y = 0.180; w = 0.42; h = 0.034; sizeEx = 0.026; colorBackground[] = {0.02, 0.03, 0.05, 0.95}; colorText[] = {0.95, 0.95, 0.95, 1}; onKeyUp = "['friendlySearchChanged', []] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class FrVehListLabel: RscText { idc = 60989; text = "Select vehicle"; x = 0.04; y = 0.220; w = 0.42; h = 0.020; sizeEx = 0.022; colorText[] = {0.65, 0.68, 0.75, 1}; };
        class FrVehList: RscListBox { idc = 60949; x = 0.04; y = 0.242; w = 0.42; h = 0.38; rowHeight = 0.032; sizeEx = 0.025; colorBackground[] = {0.02, 0.03, 0.05, 0.95}; colorSelectBackground[] = {0.15, 0.35, 0.55, 0.75}; onLBSelChanged = "['friendlyVehSel', []] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class FrSlotListLabel: RscText { idc = 60990; text = "Range slot"; x = 0.48; y = 0.220; w = 0.44; h = 0.020; sizeEx = 0.022; colorText[] = {0.65, 0.68, 0.75, 1}; };
        class FrSlotList: RscListBox { idc = 60950; x = 0.48; y = 0.242; w = 0.44; h = 0.20; rowHeight = 0.030; sizeEx = 0.025; colorBackground[] = {0.02, 0.03, 0.05, 0.95}; colorSelectBackground[] = {0.15, 0.35, 0.55, 0.75}; };
        class FrPreviewPic: RscPicture { idc = 60984; x = 0.48; y = 0.452; w = 0.44; h = 0.22; text = ""; style = 48; colorBackground[] = {0.12, 0.13, 0.16, 1}; };
        class FrSpawnBtn: RscButton { idc = 60951; text = "Spawn"; x = 0.04; y = 0.688; w = 0.42; h = 0.048; sizeEx = 0.032; colorBackground[] = {0.22, 0.48, 0.78, 1}; colorBackgroundActive[] = {0.28, 0.55, 0.88, 1}; action = "['spawnFriendlyVeh', []] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
        class FrManageLabel: RscText { idc = 60991; text = "Occupied slots — select then despawn"; x = 0.04; y = 0.158; w = 0.55; h = 0.022; sizeEx = 0.024; colorText[] = {0.85, 0.9, 1, 1}; };
        class FrManageSlotList: RscListBox { idc = 60987; x = 0.04; y = 0.184; w = 0.55; h = 0.48; rowHeight = 0.034; sizeEx = 0.026; colorBackground[] = {0.02, 0.03, 0.05, 0.95}; colorSelectBackground[] = {0.15, 0.35, 0.55, 0.75}; };
        class FrDespawnBtn: RscButton { idc = 60952; text = "Despawn selected"; x = 0.04; y = 0.688; w = 0.35; h = 0.046; sizeEx = 0.028; colorBackground[] = {0.36, 0.22, 0.16, 1}; colorBackgroundActive[] = {0.44, 0.28, 0.20, 1}; colorText[] = {0.98, 0.97, 0.95, 1}; action = "['despawnFriendlyVeh', []] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]);"; };
    };
};
