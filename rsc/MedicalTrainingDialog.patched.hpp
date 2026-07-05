// Medical training terminal — single view: dummies (left) + injuries (right)
class RscDisplayMedicalTraining: RscDisplayEmpty {
    idd = 60800;
    movingEnable = 1;
    enableSimulation = 1;
    onLoad = "[] spawn { sleep 0.01; ['onLoad', []] call (missionNamespace getVariable ['FAC_medicalTrainingGui_fnc', {}]); };";
    class controlsBackground {
        class Background: FACRscDialogBackground { x = 0.02; y = 0.025; w = 0.96; h = 0.94; };
        class HeaderBar: FACRscHeaderBar { x = 0.02; y = 0.025; w = 0.96; h = 0.065; };
        class MainPanel: FACRscMainPanel { x = 0.03; y = 0.092; w = 0.94; h = 0.858; };
    };
    class controls {
        class TitleText: FACRscDialogTitle { text = "MEDICAL TRAINING"; x = 0.035; y = 0.032; w = 0.24; h = 0.052; sizeEx = 0.034; };
        class HeaderRefreshBtn: FACRscRefreshBtn { idc = 60841; action = "['headerRefresh', []] call (missionNamespace getVariable ['FAC_medicalTrainingGui_fnc', {}]);"; };
        class HeaderCloseBtn: FACRscCloseBtn { idc = 60842; y = 0.036; };
        // --- Left: dummies ---
        class DummyLabel: FACRscSectionHdr { idc = 60880; text = "Training dummies"; x = 0.04; y = 0.105; w = 0.28; h = 0.028; sizeEx = 0.028; };
        class DummyList: FACRscListDark {
            idc = 60801;
            x = 0.04; y = 0.135; w = 0.28; h = 0.52;
            rowHeight = 0.038; sizeEx = 0.028;
            onLBSelChanged = "['dummySelChanged', []] call (missionNamespace getVariable ['FAC_medicalTrainingGui_fnc', {}]);";
        };
        class BtnNew: FACRscPrimaryBtn { idc = 60814; text = "New dummy"; x = 0.04; y = 0.665; w = 0.28; h = 0.036; sizeEx = 0.026; action = "['spawnDummy', []] call (missionNamespace getVariable ['FAC_medicalTrainingGui_fnc', {}]);"; };
        class BtnDelete: RscButton { idc = 60815; text = "Delete"; x = 0.04; y = 0.708; w = 0.28; h = 0.036; sizeEx = 0.026; colorBackground[] = FAC_COLOR_BTN_WARN; colorText[] = FAC_COLOR_TEXT; action = "['deleteDummy', []] call (missionNamespace getVariable ['FAC_medicalTrainingGui_fnc', {}]);"; };
        class BtnDeleteAll: FACRscDangerBtn { idc = 60816; text = "Delete all"; x = 0.04; y = 0.751; w = 0.28; h = 0.036; sizeEx = 0.026; action = "['deleteAll', []] call (missionNamespace getVariable ['FAC_medicalTrainingGui_fnc', {}]);"; };
        class SelectedTargetLabel: RscText { idc = 60893; text = "Target: (none)"; x = 0.04; y = 0.794; w = 0.28; h = 0.048; sizeEx = 0.026; style = 16; colorText[] = {0.72, 0.76, 0.82, 1}; };
        // --- Right: injuries ---
        class PresetLabel: FACRscSectionHdr { idc = 60892; text = "Preset scenario"; x = 0.34; y = 0.105; w = 0.62; h = 0.028; sizeEx = 0.028; };
        class PresetCombo: FACRscCombo { idc = 60802; x = 0.34; y = 0.132; w = 0.62; h = 0.034; wholeHeight = 0.48; sizeEx = 0.026; };
        class BtnApplyPreset: RscButton { idc = 60830; text = "Apply preset"; x = 0.34; y = 0.172; w = 0.30; h = 0.036; sizeEx = 0.026; colorBackground[] = FAC_COLOR_BTN_PRIMARY; action = "['applyPreset', []] call (missionNamespace getVariable ['FAC_medicalTrainingGui_fnc', {}]);"; };
        class BtnApplyRandomPreset: RscButton { idc = 60836; text = "Apply random injury"; x = 0.66; y = 0.172; w = 0.32; h = 0.036; sizeEx = 0.026; colorBackground[] = FAC_COLOR_BTN_PRIMARY; action = "['applyRandomPreset', []] call (missionNamespace getVariable ['FAC_medicalTrainingGui_fnc', {}]);"; };
        class KatAirLabel: RscText { idc = 60894; text = "Airway / chest (Zeus parity)"; x = 0.34; y = 0.216; w = 0.62; h = 0.022; sizeEx = 0.026; colorText[] = FAC_COLOR_TEXT_HDR; };
        class KatObLabel: RscText { idc = 60895; text = "Obstruction"; x = 0.34; y = 0.240; w = 0.30; h = 0.018; sizeEx = 0.022; colorText[] = FAC_COLOR_TEXT_MUTED; };
        class KatObCombo: FACRscCombo { idc = 60860; x = 0.34; y = 0.260; w = 0.30; h = 0.032; wholeHeight = 0.14; sizeEx = 0.024; };
        class KatOcLabel: RscText { idc = 60896; text = "Occluded"; x = 0.66; y = 0.240; w = 0.30; h = 0.018; sizeEx = 0.022; colorText[] = FAC_COLOR_TEXT_MUTED; };
        class KatOcCombo: FACRscCombo { idc = 60861; x = 0.66; y = 0.260; w = 0.30; h = 0.032; wholeHeight = 0.14; sizeEx = 0.024; };
        class KatHemoLabel: RscText { idc = 60897; text = "Hemopneumothorax"; x = 0.34; y = 0.298; w = 0.30; h = 0.018; sizeEx = 0.022; colorText[] = FAC_COLOR_TEXT_MUTED; };
        class KatHemoCombo: FACRscCombo { idc = 60862; x = 0.34; y = 0.318; w = 0.30; h = 0.032; wholeHeight = 0.14; sizeEx = 0.024; };
        class KatTenLabel: RscText { idc = 60898; text = "Tension PTX"; x = 0.66; y = 0.298; w = 0.30; h = 0.018; sizeEx = 0.022; colorText[] = FAC_COLOR_TEXT_MUTED; };
        class KatTenCombo: FACRscCombo { idc = 60863; x = 0.66; y = 0.318; w = 0.30; h = 0.032; wholeHeight = 0.14; sizeEx = 0.024; };
        class KatPtxLabel: RscText { idc = 60871; text = "Pneumothorax 0-4"; x = 0.34; y = 0.356; w = 0.62; h = 0.018; sizeEx = 0.022; colorText[] = FAC_COLOR_TEXT_MUTED; };
        class KatPtxSlider: RscXSliderH { idc = 60864; x = 0.34; y = 0.376; w = 0.62; h = 0.028; onSliderPosChanged = "['ptxSlider', []] call (missionNamespace getVariable ['FAC_medicalTrainingGui_fnc', {}]);"; };
        class KatSpo2Label: RscText { idc = 60872; text = "SpO2 / PaO2 slot (0-100)"; x = 0.34; y = 0.410; w = 0.62; h = 0.018; sizeEx = 0.022; colorText[] = FAC_COLOR_TEXT_MUTED; };
        class KatSpo2Slider: RscXSliderH { idc = 60865; x = 0.34; y = 0.430; w = 0.62; h = 0.028; onSliderPosChanged = "['spo2Slider', []] call (missionNamespace getVariable ['FAC_medicalTrainingGui_fnc', {}]);"; };
        class KatDetLabel: RscText { idc = 60899; text = "PTX deteriorate"; x = 0.34; y = 0.464; w = 0.30; h = 0.018; sizeEx = 0.022; colorText[] = FAC_COLOR_TEXT_MUTED; };
        class KatDetCombo: FACRscCombo { idc = 60866; x = 0.34; y = 0.484; w = 0.30; h = 0.032; wholeHeight = 0.14; sizeEx = 0.024; };
        class KatDeepLabel: RscText { idc = 60900; text = "Deep penetrating"; x = 0.66; y = 0.464; w = 0.30; h = 0.018; sizeEx = 0.022; colorText[] = FAC_COLOR_TEXT_MUTED; };
        class KatDeepCombo: FACRscCombo { idc = 60867; x = 0.66; y = 0.484; w = 0.30; h = 0.032; wholeHeight = 0.14; sizeEx = 0.024; };
        class BtnApplyKATAirway: RscButton { idc = 60868; text = "Apply airway / chest"; x = 0.34; y = 0.524; w = 0.62; h = 0.036; sizeEx = 0.026; colorBackground[] = FAC_COLOR_BTN_PRIMARY; action = "['applyAirwayChest', []] call (missionNamespace getVariable ['FAC_medicalTrainingGui_fnc', {}]);"; };
        class KatCardiacLabel: RscText { idc = 60901; text = "Cardiac rhythm"; x = 0.34; y = 0.568; w = 0.62; h = 0.022; sizeEx = 0.026; colorText[] = FAC_COLOR_TEXT_HDR; };
        class KatCardiacCombo: FACRscCombo { idc = 60869; x = 0.34; y = 0.592; w = 0.44; h = 0.034; wholeHeight = 0.26; sizeEx = 0.024; };
        class BtnApplyKATCardiac: RscButton { idc = 60870; text = "Apply cardiac"; x = 0.80; y = 0.592; w = 0.16; h = 0.034; sizeEx = 0.026; colorBackground[] = FAC_COLOR_BTN_PRIMARY; action = "['applyCardiac', []] call (missionNamespace getVariable ['FAC_medicalTrainingGui_fnc', {}]);"; };
        class AceWoundLabel: RscText { idc = 60902; text = "Bleeding wound / part"; x = 0.34; y = 0.634; w = 0.62; h = 0.022; sizeEx = 0.026; colorText[] = FAC_COLOR_TEXT_HDR; };
        class BodyLabel: RscText { idc = 60903; text = "Body part"; x = 0.34; y = 0.658; w = 0.30; h = 0.018; sizeEx = 0.022; colorText[] = FAC_COLOR_TEXT_MUTED; };
        class BodyCombo: FACRscCombo { idc = 60803; x = 0.34; y = 0.678; w = 0.30; h = 0.032; wholeHeight = 0.32; sizeEx = 0.024; };
        class WoundLabel: RscText { idc = 60904; text = "Wound type"; x = 0.66; y = 0.658; w = 0.30; h = 0.018; sizeEx = 0.022; colorText[] = FAC_COLOR_TEXT_MUTED; };
        class WoundCombo: FACRscCombo { idc = 60804; x = 0.66; y = 0.678; w = 0.30; h = 0.032; wholeHeight = 0.24; sizeEx = 0.024; };
        class BleedLabel: RscText { idc = 60806; text = "Bleed rate: —"; x = 0.34; y = 0.716; w = 0.62; h = 0.018; sizeEx = 0.022; colorText[] = FAC_COLOR_TEXT_MUTED; };
        class BleedSlider: RscXSliderH { idc = 60805; x = 0.34; y = 0.736; w = 0.62; h = 0.028; onSliderPosChanged = "['bleedSlider', []] call (missionNamespace getVariable ['FAC_medicalTrainingGui_fnc', {}]);"; };
        class DepthLabel: RscText { idc = 60905; text = "Depth"; x = 0.34; y = 0.770; w = 0.30; h = 0.018; sizeEx = 0.022; colorText[] = FAC_COLOR_TEXT_MUTED; };
        class DepthCombo: FACRscCombo { idc = 60807; x = 0.34; y = 0.790; w = 0.30; h = 0.032; wholeHeight = 0.18; sizeEx = 0.024; };
        class BtnApplyWound: RscButton { idc = 60831; text = "Apply wound"; x = 0.66; y = 0.770; w = 0.30; h = 0.052; sizeEx = 0.026; colorBackground[] = FAC_COLOR_BTN_PRIMARY; action = "['applyWound', []] call (missionNamespace getVariable ['FAC_medicalTrainingGui_fnc', {}]);"; };
        class BtnHealPart: RscButton { idc = 60832; text = "Heal part"; x = 0.34; y = 0.832; w = 0.30; h = 0.036; sizeEx = 0.026; action = "['healPart', []] call (missionNamespace getVariable ['FAC_medicalTrainingGui_fnc', {}]);"; };
        class BtnHealAll: RscButton { idc = 60833; text = "Heal all"; x = 0.66; y = 0.832; w = 0.30; h = 0.036; sizeEx = 0.026; action = "['healAll', []] call (missionNamespace getVariable ['FAC_medicalTrainingGui_fnc', {}]);"; };
        class BtnUncon: RscButton { idc = 60834; text = "Unconscious"; x = 0.34; y = 0.876; w = 0.30; h = 0.036; sizeEx = 0.026; action = "['unconscious', []] call (missionNamespace getVariable ['FAC_medicalTrainingGui_fnc', {}]);"; };
        class BtnWake: RscButton { idc = 60835; text = "Conscious"; x = 0.66; y = 0.876; w = 0.30; h = 0.036; sizeEx = 0.026; action = "['conscious', []] call (missionNamespace getVariable ['FAC_medicalTrainingGui_fnc', {}]);"; };
        class InfoText: RscStructuredText {
            idc = 60850;
            x = 0.34; y = 0.920; w = 0.62; h = 0.028;
            size = 0.022;
            colorBackground[] = {0, 0, 0, 0};
            text = "";
        };
    };
};
